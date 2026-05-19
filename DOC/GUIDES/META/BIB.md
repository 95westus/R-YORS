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
DOC/GUIDES/ASM/HASHED_ASM.md
DOC/GUIDES/ASM/SYMBOL_XREF.md
DOC/GUIDES/CATALOG/CATALOG.md
DOC/GUIDES/CATALOG/HREC_JOIN_PROOF.md
DOC/GUIDES/CATALOG/LIFE_RCAT_MEMBER.md
DOC/GUIDES/DECISIONS.md
DOC/GUIDES/DOC_FLASH.md
DOC/GUIDES/GLOSSARY.md
DOC/GUIDES/HASH/HASH.md
DOC/GUIDES/HASH/HASH_MAP.md
DOC/GUIDES/HASH_FLASH.md
DOC/GUIDES/HIMON/HIMON_DEBUG_TESTING.md
DOC/GUIDES/HIMON/HIMON_EDGE_DUMP.md
DOC/GUIDES/HIMON/HIMON_MAP.md
DOC/GUIDES/HIMON/HIMON_SEARCH_IMPLEMENTATION_GUIDE.md
DOC/GUIDES/HIMON/HIMON_STAGES_CLASSES.md
DOC/GUIDES/INDEX.md
DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md
DOC/GUIDES/MAP.md
DOC/GUIDES/MEMORY/DYNAMIC_MEMORY_FIRST_STEPS.md
DOC/GUIDES/MEMORY/MEMORY_MAP.md
DOC/GUIDES/META/BIB.md
DOC/GUIDES/META/COMPAT/RTFM-himon.md
DOC/GUIDES/META/COMPAT/RTFM-R-YORS.md
DOC/GUIDES/META/COMPAT/RTFM-str8.md
DOC/GUIDES/META/XREF.md
DOC/GUIDES/OPERATORS_GUIDE.md
DOC/GUIDES/PLANNING/FUTURE.md
DOC/GUIDES/PLANNING/TODO.md
DOC/GUIDES/QCC/ASM.md
DOC/GUIDES/QCC/CATALOG_LINKING.md
DOC/GUIDES/QCC/FLASH.md
DOC/GUIDES/QCC/HASH.md
DOC/GUIDES/QCC/INDEX.md
DOC/GUIDES/QCC/MEMORY.md
DOC/GUIDES/QCC/STR8.md
DOC/GUIDES/REF.md
DOC/GUIDES/STORY/BOOK.md
DOC/GUIDES/STORY/HISTORICAL_DOCUMENTS.md
DOC/GUIDES/STORY/ID10Toms.txt
DOC/GUIDES/STR8/BRINGUP.md
DOC/GUIDES/STR8/PRODUCT_BOUNDARIES.md
DOC/GUIDES/STR8/STR8.md
DOC/GUIDES/STR8/STR8_DECISION_REFERENCE.md
DOC/GUIDES/STR8/STR8_FLASH_UPDATE_PROPOSAL.md
DOC/GUIDES/STR8/STR8_WORK_PROCESS.md
DOC/GUIDES/TECHNICAL_GUIDE.md
DOC/GUIDES/TOC.md
```

## Generated Source-Derived Docs

```text
DOC/GENERATED/CALL_ORDER.md
DOC/GENERATED/CMD_FLOW_MAP.md
DOC/GENERATED/HASH_ROUTINE_MAP.md
DOC/GENERATED/HIMON_COMMAND_MAP.md
DOC/GENERATED/HIMON_ROUTINE_TREE.md
DOC/GENERATED/HIMON_SUPPORT_MAP.md
DOC/GENERATED/INTERRUPT_VECTOR_MAP.md
DOC/GENERATED/MAP_OF_MAPS.md
DOC/GENERATED/ROUTINE_CLASS_DIAGRAM.md
DOC/GENERATED/ROUTINE_COMPONENTS.md
DOC/GENERATED/ROUTINE_CONTRACTS.md
DOC/GENERATED/ROUTINE_GRAPH_INSIGHTS.md
DOC/GENERATED/ROUTINE_PREFIX_MAP.md
DOC/GENERATED/STACK_DEPTH_MAP.md
```

## Reference Notes

- `OPERATORS_GUIDE.md` is the consolidated board-facing guide and canonical
  home for current STR8/HIMON operation.
- `TECHNICAL_GUIDE.md` is the consolidated architecture guide and canonical
  home for current system layout, flash policy, and payload contracts.
- `RTFM-R-YORS.md`, `RTFM-str8.md`, and `RTFM-himon.md` are compatibility entry
  points that redirect to the operator guide.
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
