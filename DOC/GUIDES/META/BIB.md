# R-YORS Bibliography

This guide set uses the current `ror` workspace as its source corpus, but this
bibliography lists only the operational source set.

## Operational Internal Sources

```text
README.md
SRC/Makefile
SRC/HIMON/himon.asm
SRC/HIMON/*.inc
SRC/HIMON/fnv1a-fold.asm
SRC/TESTS/ftdi-backend-debug.asm
SRC/LIB/ftdi/*.asm
SRC/LIB/dev/*.asm
SRC/LIB/util/*.asm
```

The generated source-derived docs use this R-YORS operational set. STR8-N is
an external artifact dependency and documents its source in its own repository. Legacy demos,
harnesses, games, ACIA/PIA, and historical monitor experiments stay out of the
bibliography/navigation layer.

## Guide Sources

```text
DOC/INDEX.md
DOC/IDEAS.md
DOC/GUIDES/ASM/ADDRESS_PRACTICES.md
DOC/GUIDES/ASM/AP_LINKER_CURRENT_IMAGE_GATES.md
DOC/GUIDES/ASM/ASM_CALL_MAP.md
DOC/GUIDES/ASM/ASM_SHARED_ROUTINES_AUDIT.md
DOC/GUIDES/ASM/ASM_USER_GUIDE.md
DOC/GUIDES/ASM/DECISIONS.md
DOC/GUIDES/ASM/FLASH_8000_GAME_PLAN.md
DOC/GUIDES/ASM/HASHED_ASM.md
DOC/GUIDES/ASM/INTERACTIVE_BATCH.md
DOC/GUIDES/ASM/LIFE16_BANK2_EXAMPLE.md
DOC/GUIDES/ASM/LIFE16_QUICK_CARD.md
DOC/GUIDES/ASM/MOVABLE_MODULES.md
DOC/GUIDES/ASM/SYMBOL_XREF.md
DOC/GUIDES/ASM/TEST_PLAN.md
DOC/GUIDES/CATALOG/CATALOG.md
DOC/GUIDES/CATALOG/HREC_JOIN_PROOF.md
DOC/GUIDES/CATALOG/LIFE_RCAT_MEMBER.md
DOC/GUIDES/DECISIONS.md
DOC/GUIDES/DOC_FLASH.md
DOC/GUIDES/GLOSSARY.md
DOC/GUIDES/HASH/HASH.md
DOC/GUIDES/HASH/HASH_MAP.md
DOC/GUIDES/HASH/HASH_TRASH.md
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
DOC/GUIDES/META/PROVENANCE.md
DOC/GUIDES/META/XREF.md
DOC/GUIDES/OPERATORS_GUIDE.md
DOC/GUIDES/PLANNING/DATA_STRUCTURE_OPPORTUNITIES.md
DOC/GUIDES/PLANNING/OIL_710_TEST_PLAN.md
DOC/GUIDES/PLANNING/HISTORICAL_CODE_MIGRATION_PLAN.md
DOC/GUIDES/PLANNING/FUTURE.md
DOC/GUIDES/PLANNING/STR8_J012_OPAQUE_BANK_PLAN.md
DOC/GUIDES/PLANNING/STR8_MULTIBOOT_BANK_VOLUMES.md
DOC/GUIDES/PLANNING/TODO.md
DOC/GUIDES/QCC/ASM.md
DOC/GUIDES/QCC/CATALOG_LINKING.md
DOC/GUIDES/QCC/FLASH.md
DOC/GUIDES/QCC/HARDWARE.md
DOC/GUIDES/QCC/HASH.md
DOC/GUIDES/QCC/INDEX.md
DOC/GUIDES/QCC/MEMORY.md
DOC/GUIDES/QCC/STR8.md
DOC/GUIDES/REF.md
DOC/GUIDES/RELEASES.md
DOC/GUIDES/STORY/BOOK.md
DOC/GUIDES/STORY/HISTORICAL_DOCUMENTS.md
DOC/GUIDES/STORY/HIMON_STR8_LIVE_UPDATE_LOG.md
DOC/GUIDES/STORY/ID10Toms.txt
DOC/GUIDES/STR8/BRINGUP.md
DOC/GUIDES/STR8/PRODUCT_BOUNDARIES.md
DOC/GUIDES/STR8/STR8.md
DOC/GUIDES/STR8/STR8_BANK_JUMP_RECORD_BOARD_TEST.md
DOC/GUIDES/STR8/STR8_BOOT_SELECTOR_BOARD_TEST.md
DOC/GUIDES/STR8/STR8_DECISION_REFERENCE.md
DOC/GUIDES/STR8/STR8_FLASH_UPDATE_PROPOSAL.md
DOC/GUIDES/STR8/STR8_GUEST_IMAGE_QUALIFICATION.md
DOC/GUIDES/STR8/STR8_J012_BOARD_TEST.md
DOC/GUIDES/STR8/STR8_SIZE_PASS_BOARD_TEST.md
DOC/GUIDES/STR8/STR8_V0_RESTORE_FAILURE_GATES.md
DOC/GUIDES/STR8/STR8_WORK_PROCESS.md
DOC/GUIDES/TECHNICAL_GUIDE.md
DOC/GUIDES/TOC.md
```

## Generated Source-Derived Docs

```text
DOC/GENERATED/CALL_ORDER.md
DOC/GENERATED/CMD_FLOW_MAP.md
DOC/GENERATED/CONTROL_DECK_MAP.md
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
DOC/GENERATED/ROUTINE_WORD_TREE.md
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
- Symbol contract examples are seeded from `SRC/LIB/ftdi/ftdi-drv.asm`,
  `ROM/dev/*.asm`, and `HIMON/himon.asm`.
- Routine inventory is derived from `; ROUTINE:` comment blocks.
- `CATALOG.md` is a programmer-facing selection view over that
  routine inventory.
- `LIFE_RCAT_MEMBER.md` uses `SRC/APPS/life.asm` and
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
- STR8-N source-derived maps and raw edges are owned by the standalone
  STR8-N repository.
- `HIMON_STAGES_CLASSES.md` reconstructs the Himon/Himonia/Himonia-F stage
  ladder and subsystem class families from current source plus guide evidence.
- `STR8_WORK_PROCESS.md` records the current review, proof, implementation,
  and documentation loop for STR8 work.
- `HISTORICAL_CODE_MIGRATION_PLAN.md` records the plan for moving retired
  sample, test, proof, app, tool, and one-off data sources under
  `SRC/ARCHIVE/` while keeping current STR8-N, HIMON V, and ASM-F2 paths
  stable.
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
