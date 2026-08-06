# Sanskrit Heritage Platform — Local macOS Install (Reference)

Working local install, confirmed via `heritage.py` `method="shell"` returning real
segmentation results for a compound Devanagari string.

## Machine
macOS (Apple Silicon Mac mini), OCaml 5.4.1 (system), separate opam switch for the build.

## Directory layout
```
~/sanskrit_heritage/
├── Zen/                  # Zen computational linguistics library (OCaml)
├── Heritage_Resources/   # linguistic data (DICO, MW, DATA/*.rem) — ~1.9 GB
├── Heritage_Platform/    # the engine + build system (this is base_dir for heritage.py)
│   ├── ZEN -> ../Zen/ML/           # symlink, NOT created automatically
│   ├── DICO/, MW/                  # local copies from Heritage_Resources
│   └── ML/                         # compiled binaries live here: reader, parser,
│                                    # indexer, indexerd, declension, conjugation,
│                                    # lemmatizer, sandhier, user_aid, interface, etc.
├── webdir/               # SERVERPUBLICDIR — public data dir, incl. webdir/DATA
│                          # (this is what naming.ml actually reads at runtime)
└── cgidir/                # CGIDIR — unused since we never run a real web server
```

## Prerequisites installed
- Xcode Command Line Tools (`xcode-select --install`)
- Homebrew
- `opam` (via `brew install opam`), then a **dedicated switch**:
  ```
  opam switch create heritage 4.14.2
  eval $(opam env --switch=heritage)
  opam install ocamlfind ocamlbuild camlp4 camlp-streams
  ```
  (OCaml 5.x on the system `ocaml` is fine for other things, but `camlp4` — a
  deprecated preprocessor this codebase depends on — needed an older switch.)
- `pyenv` + Python 2.7.18, only to run the top-level `configure` script, which is
  Python 2 (`#!/usr/bin/python`, uses `print` statements). macOS ships no Python 2
  at all, so this had to be installed separately and invoked explicitly:
  ```
  $(pyenv root)/versions/2.7.18/bin/python2 configure
  ```

## Repos cloned
```
git clone https://gitlab.inria.fr/huet/Zen.git
git clone https://gitlab.inria.fr/huet/Heritage_Resources.git
git clone https://gitlab.inria.fr/huet/Heritage_Platform.git
```
(`Zen` is listed in Heritage's own `INSTALLATION` file but easy to miss on a first read.)

## Config file
Created `SETUP/CONFIGS/raj_config.txt` (based on Huet's own `amrita_config.txt`,
the only example already written for macOS), then symlinked:
```
ln -sf CONFIGS/raj_config.txt SETUP/config
```
Key choices:
- `PLATFORM='Computer'` — we never run a real Apache/CGI server; `heritage.py`'s
  shell mode calls the compiled binaries directly via subprocess.
- `TRANSLIT='VH'` — kept even though input is Devanagari, because `heritage.py`
  transliterates to Velthuis before querying the backend.
- `SERVERPUBLICDIR` / `CGIDIR` point into `~/sanskrit_heritage/webdir` and
  `~/sanskrit_heritage/cgidir` instead of system paths — so nothing needs `sudo`.

## Build — what actually worked (deviates from the documented `make all`)
The top-level `Makefile`'s `all:` target has an ordering bug: it calls `make cold`
(which needs `ML/reset_caches`, a compiled binary) *before* it compiles `ML/`. On a
fresh checkout this fails immediately. Steps that worked, run in this order:

```bash
# 1. configure
$(pyenv root)/versions/2.7.18/bin/python2 configure

# 2. steps from `all:` that must happen before compiling ML/, done manually
ln -sf ~/sanskrit_heritage/Zen/ML/ ZEN
cp -Rp ~/sanskrit_heritage/Heritage_Resources/DICO .
cp -Rp ~/sanskrit_heritage/Heritage_Resources/MW .
test -e ML/SCLpaths.ml || cp SETUP/dummy_SCLpaths.ml ML/SCLpaths.ml
cd ML && make test_version && ./test_stamp && cd ..

# 3. transducers (data-heavy, takes a while)
mkdir -p DATA
cd ML && make make_transducers && cd ..
make transducers

# 4. compile the actual engine (reader, parser, etc.)
cd ML && make engine && cd ..

# 5. cache scaffolding (now that ML/reset_caches exists)
make cold

# 6. copy linguistic data (nouns/roots/sandhi/KRIDS/etc.) into webdir/DATA —
#    this is the step that was actually missing and caused the runtime crash
#    `Fatal error: exception Failure("unique_kridantas")`. It normally only
#    runs inside `make install`, which we skipped (see below).
make releasedata
```

### Why we skipped `make install`
`install:` calls `SETUP/issudo.sh`, which hard-exits unless `whoami == root`. It's
just a root gate — no other side effects — but real installs write to system paths
like `/var/www`, which don't apply here. `install:` also calls `make release`, a
much bigger target (docs, book PDFs, corpus, CGI install for a real web server) that
we don't need. `releasedata` is the one sub-target that actually matters for
runtime: it copies `AUTOMATA`/`KRIDS`/MW-link `.rem` files from
`Heritage_Resources/DATA` into `webdir/DATA`, which is what `naming.ml` reads at
runtime (`Data.public_unique_kridantas_file`, i.e. a *public/webdir* copy, not the
source copy in `Heritage_Resources`).

### Known-harmless warnings
- `Heritage_Resources` reports version `3.33 experimental` vs. this platform
  release's expected `3.32` — build and current test both succeeded anyway. Worth
  revisiting only if segmentation results look wrong later.
- Hundreds of `Alert deprecated: module Stdlib.Stream` warnings during `make engine`
  — cosmetic, from the old camlp4-based parser code; not build failures.
- `ls: MW/*.html: No such file or directory` during `make releasedata` — harmless;
  that step only matters for a real web deployment.

## Confirmed working test
```python
from pathlib import Path
from heritage import HeritagePlatform

platform = HeritagePlatform(
    base_dir=Path("/Users/rajaramaniyer/sanskrit_heritage/Heritage_Platform"),
    method="shell",
)
result = platform.get_analysis("राधाकृष्णपदाम्बुजभृङ्गम्", sentence=True, unsandhied=True)
```
Returns multiple ranked `SolutionAnalysis` objects; solution `1` (top-ranked) splits
the compound as: राधा / कृष्ण / पद / अम्बुज / भृङ्गम् — matches expectations.

## Does this survive a new terminal session?
Yes, for running the segmenter — **the `opam switch`/`eval $(opam env)` step was
only needed to *build* the binaries** (`ocamlfind`, `camlp4` etc. are build-time
tools). The compiled binaries in `ML/` (`reader`, `parser`, ...) are native
executables with no runtime dependency on OCaml/opam being on `PATH`. As long as:
- the `heritage` pip package is installed in whatever Python you invoke, and
- `base_dir` points at the fixed path `~/sanskrit_heritage/Heritage_Platform`,

...it should work from a fresh terminal with no `eval $(opam env)` needed. Worth a
one-time sanity check by opening a new terminal tab and re-running the test above.
