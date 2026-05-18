# R-YORS Bibliography

This guide set uses the current `ror` workspace as its source corpus, but this
bibliography lists only the operational source set.

## Operational Internal Sources

```text
README.md
SRC/Makefile
HIMON/himon.asm
HIMON/*.inc
HIMON/fnv1a-fold.asm
STR8/str8.asm
ROM/ftdi-backend-debug.asm
ROM/ftdi/*.asm
ROM/dev/*.asm
ROM/util/*.asm
SRC/STASH/ftdi/*.asm
SRC/SESH/ftdi/*.asm
```

The generated source-derived docs use this operational set. Legacy demos,
harnesses, games, ACIA/PIA, and historical monitor experiments stay out of the
bibliography/navigation layer.

## Guide Sources

```text
DOC/INDEX.md
DOC/IDEAS.md
DOC/GUIDES/INDEX.md
DOC/GUIDES/TOC.md
DOC/GUIDES/MAP.md
DOC/GUIDES/DOC_FLASH.md
DOC/GUIDES/DECISIONS.md
DOC/GUIDES/QCC.md
DOC/GUIDES/QCC_HASH.md
DOC/GUIDES/QCC_FLASH.md
DOC/GUIDES/QCC_ASM.md
DOC/GUIDES/QCC_CATALOG_LINKING.md
DOC/GUIDES/QCC_STR8.md
DOC/GUIDES/QCC_MEMORY.md
DOC/GUIDES/REF.md
DOC/GUIDES/XREF.md
DOC/GUIDES/CATALOG.md
DOC/GUIDES/LIFE_RCAT_MEMBER.md
DOC/GUIDES/MEMORY_MAP.md
DOC/GUIDES/DYNAMIC_MEMORY_FIRST_STEPS.md
DOC/GUIDES/SYMBOL_XREF.md
DOC/GUIDES/HIMON_MAP.md
DOC/GUIDES/HIMON_STAGES_CLASSES.md
DOC/GUIDES/HIMON_EDGE_DUMP.md
DOC/GUIDES/HISTORICAL_DOCUMENTS.md
DOC/GUIDES/STR8.md
DOC/GUIDES/STR8_WORK_PROCESS.md
DOC/GUIDES/HASH.md
DOC/GUIDES/HASH_MAP.md
DOC/GUIDES/HASHED_ASM.md
DOC/GUIDES/GLOSSARY.md
DOC/GUIDES/TODO.md
DOC/GUIDES/FUTURE.md
```

## Generated Source-Derived Docs

```text
DOC/GENERATED/MAP_OF_MAPS.md
DOC/GENERATED/CALL_ORDER.md
DOC/GENERATED/ROUTINE_CONTRACTS.md
DOC/GENERATED/HIMON_ROUTINE_TREE.md
DOC/GENERATED/ROUTINE_CLASS_DIAGRAM.md
DOC/GENERATED/ROUTINE_PREFIX_MAP.md
DOC/GENERATED/HIMON_SUPPORT_MAP.md
DOC/GENERATED/HIMON_COMMAND_MAP.md
DOC/GENERATED/HASH_ROUTINE_MAP.md
DOC/GENERATED/CMD_FLOW_MAP.md
DOC/GENERATED/INTERRUPT_VECTOR_MAP.md
DOC/GENERATED/ROUTINE_GRAPH_INSIGHTS.md
DOC/GENERATED/ROUTINE_COMPONENTS.md
```

## Reference Notes

- Symbol relationships are derived from WDC-style `XDEF` and `XREF`
  declarations.
- Symbol contract examples are seeded from `SRC/STASH/ftdi/ftdi-drv.asm`,
  `ROM/dev/*.asm`, and `HIMON/himon.asm`.
- Routine inventory is derived from `; ROUTINE:` comment blocks.
- `CATALOG.md` is a programmer-facing selection view over that
  routine inventory.
- `LIFE_RCAT_MEMBER.md` uses `SRC/TEST/apps/life.asm` and
  `SRC/BUILD/map/life.map` as a worked RCAT/RREC member example. LIFE remains
  outside the operational generated call trees unless promoted later.
- `MEMORY_MAP.md` records current HIMON ROM/RAM ownership, compatibility
  entries, vectors, and future STR8 placement direction.
- `DYNAMIC_MEMORY_FIRST_STEPS.md` synthesizes the W65C02 allocation discussion
  with the current R-YORS memory map and zero-page rules.
- Routine `[HASH:XXXXXXXX]` IDs are FNV-1a over canonical routine text.
- Runtime command lookup in HIMON uses FNV-1a hashes over command text.
- `HIMON_MAP.md` is the readable HIMON map; `HIMON_EDGE_DUMP.md` is the raw
  direct-edge listing.
- `HIMON_STAGES_CLASSES.md` reconstructs the Himon/Himonia/Himonia-F stage
  ladder and subsystem class families from current source plus guide evidence.
- `STR8_WORK_PROCESS.md` records the current review, proof, implementation,
  and documentation loop for STR8 work.
- `QCC.md` defines Questions, Comments, Concerns as the working-note format for
  unsettled design topics; `QCC_*.md` pages keep topic-specific what-ifs before
  they graduate into `DECISIONS.md`.
- STR8, hashed assembler, and banked catalog behavior are design notes until
  implemented.
- External links may appear as background precedent notes, but the guide spine
  is built from the local `ror` workspace.

## External References

- RFC 9923, "Fowler/Noll/Vo (FNV) Non-Cryptographic Hash Algorithm":
  <https://www.rfc-editor.org/rfc/rfc9923.html>. R-YORS uses 32-bit FNV-1a
  from this family for routine headers, runtime command lookup, catalog records,
  symbols, and fixups.
- Forth Interest Group home page: <https://www.forth.org/>. FIG describes
  itself as having promoted the Forth computer language and hosts public-domain
  and experimental Forth implementations.
- FIG-Forth Implementations index:
  <https://www.forth.org/fig-forth/contents.html>. The local fig-Forth path is
  based on the 6502 FIG-Forth implementation; the local generator preserves the
  source notice required by that publication.
