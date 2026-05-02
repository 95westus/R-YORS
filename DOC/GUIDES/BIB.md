# R-YORS Bibliography

This guide set uses the current `ror` workspace as its source corpus.

## Primary Internal Sources

```text
README.md
SRC/Makefile
SRC/TEST/apps/himon/*.asm
SRC/TEST/apps/rom-append-calc.asm
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
DOC/GUIDES/DYNAMIC_MEMORY_FIRST_STEPS.md
DOC/GUIDES/SYMBOL_XREF.md
DOC/GUIDES/HIMON_MAP.md
DOC/GUIDES/HIMON_STAGES_CLASSES.md
DOC/GUIDES/HIMON_EDGE_DUMP.md
DOC/GUIDES/HISTORICAL_DOCUMENTS.md
DOC/GUIDES/STR8.md
DOC/GUIDES/HASH.md
DOC/GUIDES/HASH_MAP.md
DOC/GUIDES/HASHED_ASM.md
DOC/GUIDES/GLOSSARY.md
DOC/GUIDES/TODO.md
DOC/GUIDES/FUTURE.md
```

## Generated Source-Derived Docs

```text
DOC/GENERATED/CALL_ORDER.md
DOC/GENERATED/ROUTINE_CONTRACTS.md
DOC/GENERATED/ROUTINE_TREE.md
DOC/GENERATED/ROUTINE_CLASS_DIAGRAM.md
DOC/GENERATED/ROUTINE_GRAPH_INSIGHTS.md
DOC/GENERATED/ROUTINE_COMPONENTS.md
```

## Reference Notes

- Symbol relationships are derived from WDC-style `XDEF` and `XREF`
  declarations.
- Symbol contract examples are seeded from `SRC/STASH/ftdi/ftdi-drv.asm`,
  `SRC/TEST/dev/*.asm`, and `SRC/TEST/apps/himon/himon.asm`.
- Routine inventory is derived from `; ROUTINE:` comment blocks.
- `CATALOG.md` is a programmer-facing selection view over that
  routine inventory.
- `MEMORY_MAP.md` records current Himonia-F ROM/RAM ownership, fixed ABI
  entries, vectors, and future STR8 placement direction.
- `DYNAMIC_MEMORY_FIRST_STEPS.md` synthesizes the W65C02 allocation discussion
  with the current R-YORS memory map and zero-page rules.
- Routine `[HASH:XXXXXXXX]` IDs are FNV-1a over canonical routine text.
- Runtime command lookup in Himonia-F uses FNV-1a hashes over command text.
- `HIMON_MAP.md` is the readable HIMON map; `HIMON_EDGE_DUMP.md` is the raw
  direct-edge listing.
- `HIMON_STAGES_CLASSES.md` reconstructs the Himon/Himonia/Himonia-F stage
  ladder and subsystem class families from current source plus guide evidence.
- STR8, hashed assembler, and banked catalog behavior are design notes until
  implemented.
- External links may appear as background precedent notes, but the guide spine
  is built from the local `ror` workspace.

## External References

- RFC 9923, "Fowler/Noll/Vo (FNV) Non-Cryptographic Hash Algorithm":
  <https://www.rfc-editor.org/rfc/rfc9923.html>. R-YORS uses 32-bit FNV-1a
  from this family for routine headers, runtime command lookup, catalog records,
  symbols, and fixups.
