# R-YORS Bibliography

This guide set uses the current `ror` workspace as its source corpus.

## Primary Internal Sources

```text
README.md
SRC/Makefile
SRC/TEST/apps/himon/*.asm
SRC/TEST/apps/calc-flash.asm
SRC/TEST/test-flash.asm
SRC/TEST/dev/*.asm
SRC/TEST/ftdi/*.asm
SRC/TEST/util/*.asm
SRC/STASH/**/*.asm
SRC/SESH/**/*.asm
```

## Guide Sources

```text
DOC/INDEX.md
DOC/IDEAS.md
DOC/GUIDES/INDEX.md
DOC/GUIDES/TOC.md
DOC/GUIDES/MAP.md
DOC/GUIDES/DECISIONS.md
DOC/GUIDES/REF.md
DOC/GUIDES/XREF.md
DOC/GUIDES/CATALOG.md
DOC/GUIDES/MEMORY_MAP.md
DOC/GUIDES/SYMBOL_XREF.md
DOC/GUIDES/HIMONIA_F_MAP.md
DOC/GUIDES/HIMONIA_F_EDGE_DUMP.md
DOC/GUIDES/HISTORICAL_DOCUMENTS.md
DOC/GUIDES/STR8.md
DOC/GUIDES/HASH.md
DOC/GUIDES/HASH_MAP.md
DOC/GUIDES/HASHED_ASM.md
DOC/GUIDES/GLOSSARY.md
DOC/GUIDES/TODO.md
DOC/GUIDES/FUTURE.md
```

## Reference Notes

- Symbol relationships are derived from WDC-style `XDEF` and `XREF`
  declarations.
- Symbol contract examples are seeded from `SRC/STASH/ftdi/ftdi-drv.asm`,
  `SRC/TEST/dev/*.asm`, and `SRC/TEST/apps/himon/himonia-f.asm`.
- Routine inventory is derived from `; ROUTINE:` comment blocks.
- `CATALOG.md` is a programmer-facing selection view over that
  routine inventory.
- `MEMORY_MAP.md` records current Himonia-F ROM/RAM ownership, fixed ABI
  entries, vectors, and future STR8 placement direction.
- Routine `[HASH:XXXXXXXX]` IDs are FNV-1a over canonical routine text.
- Runtime command lookup in Himonia-F uses FNV-1a hashes over command text.
- `HIMONIA_F_MAP.md` is the readable map; `HIMONIA_F_EDGE_DUMP.md` is the raw
  direct-edge listing.
- STR8, hashed assembler, and banked catalog behavior are design notes until
  implemented.
- External links may appear as background precedent notes, but the guide spine
  is built from the local `ror` workspace.
