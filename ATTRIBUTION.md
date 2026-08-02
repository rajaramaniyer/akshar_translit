# Attribution

The per-script character tables in `lib/src/scripts/*.dart` are a Dart port of
the Aksharamukha script maps:

- **Project:** Aksharamukha (Python)
- **Repository:** https://github.com/virtualvinodh/aksharamukha-python
- **Author:** Vinodh Rajan
- **License:** MIT

Only the subset of script maps needed for this package (Devanagari, Tamil,
Kannada, Telugu, Malayalam, ITRANS) plus the small set of default
post-processing rules (`NasalToAnusvara`, `MToAnusvara`,
`MalayalamAnusvaraNasal`, `MalayalamremoveHistorical`, `TeluguRemoveAeAo`) has
been ported. The upstream project supports many more scripts and options.
