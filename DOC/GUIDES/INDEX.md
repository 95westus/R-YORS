# R-YORS Guide Index

This is the full guide index for the current R-YORS documentation set.

## Start Here

- [OPERATORS_GUIDE.md](./OPERATORS_GUIDE.md) - canonical board-facing guide for R-YORS, STR8, and HIMON operation.
- [ASM/ASM_USER_GUIDE.md](ASM/ASM_USER_GUIDE.md) - operator guide for ASM source, prompts, END/SEAL, relocation, and packages.
- [ASM/ADDRESS_PRACTICES.md](ASM/ADDRESS_PRACTICES.md) - practical address-role guide for ASM, SEAL, PACKAGE, INSTALL, LOAD, and AP.
- [ASM/LIFE16_QUICK_CARD.md](ASM/LIFE16_QUICK_CARD.md) - exact board commands and checkpoints for the ASM-F2 Life bank-2 procedure.
- [ASM/LIFE16_BANK2_EXAMPLE.md](ASM/LIFE16_BANK2_EXAMPLE.md) - complete ASM-F2 16x16 Life AP package, bank 2 storage, and run walkthrough.
- [TECHNICAL_GUIDE.md](./TECHNICAL_GUIDE.md) - canonical architecture guide for R-YORS, STR8, HIMON, memory, flash, source layout, and build outputs.
- [PLANNING/STR8_J012_OPAQUE_BANK_PLAN.md](PLANNING/STR8_J012_OPAQUE_BANK_PLAN.md) - accepted `J0`-`J2` implementation, size, recovery, and hardware-proof plan for opaque 32K banks.
- [STR8/STR8_BOOT_SELECTOR_BOARD_TEST.md](STR8/STR8_BOOT_SELECTOR_BOARD_TEST.md) - pending reset-time `0`/`1`/`2`/`3`/`S` selector board-proof rail.
- [STR8/STR8_GUEST_IMAGE_QUALIFICATION.md](STR8/STR8_GUEST_IMAGE_QUALIFICATION.md) -
  important per-image warm-handoff, peripheral, vector, CRC, and recovery
  qualification procedure for unrelated 32K systems.
- [PLANNING/STR8_MULTIBOOT_BANK_VOLUMES.md](PLANNING/STR8_MULTIBOOT_BANK_VOLUMES.md) - retained shared-S19/bank-volume direction and superseded compatible-bank design history.
- [REF.md](./REF.md) - compact reference sheet.
- [GLOSSARY.md](./GLOSSARY.md) - vocabulary contract.
- [DECISIONS.md](./DECISIONS.md) - settled calls.

## Current Milestone

The compatible fixed `$C000-$EFFF` payload path has hardware proof for HIMON,
OSI BASIC, and fig-FORTH. That historical proof is not qualification of those
systems as unrelated opaque 32K `Jn` guests. `J0`-`J2` is hardware-proven on
the recorded R-YORS bank images; each future unrelated guest requires its own
H/P/V/C record. HIMON RAM-only debug is hardware-proven for current one-shot
breakpoint and single-step behavior, with the resident unassembler removed and
the `$7F00-$7FFF` I/O page protected by dump/load/debug paths. ASM is
flash-resident as a HIMON command and now has board-proven SEAL, RESOLVE,
RELOCATE, and AP v1 PACKAGE flows.

- [HASH_FLASH.md](./HASH_FLASH.md) - command-surface and milestone alerts.
- [DOC_FLASH.md](./DOC_FLASH.md) - documentation-shape alerts.
- [HARDWARE_TEST_LOG.md](LOGS/HARDWARE_TEST_LOG.md) - board transcript evidence.

## Navigation

- [TOC.md](./TOC.md) - recommended reading order.
- [MAP.md](./MAP.md) - documentation map and system map.
- [XREF.md](META/XREF.md) - document/source cross-reference.
- [PROVENANCE.md](META/PROVENANCE.md) - idea-origin and outside-help marking rules.
- [BIB.md](META/BIB.md) - source corpus and guide bibliography.

## Guide Shelves

- [STR8](STR8/STR8.md) - recovery, updates, product boundaries, bringup, work
  process, the [boot-selector board test](STR8/STR8_BOOT_SELECTOR_BOARD_TEST.md),
  the [J0-J2 first board test](STR8/STR8_J012_BOARD_TEST.md), the
  [V0 restore/failure gates](STR8/STR8_V0_RESTORE_FAILURE_GATES.md), and
  [edge evidence](STR8/STR8_EDGE_DUMP.md).
- [HIMON](HIMON/HIMON_MAP.md) - monitor maps, stage notes, debug, search, edge evidence.
- [MEMORY](MEMORY/MEMORY_MAP.md) - address ownership and allocation direction;
  see the generated [Control Deck Map](../GENERATED/CONTROL_DECK_MAP.md) for
  the LRS/AIR/FTC/RFD-RTC-RPT/RSC bench view.
- [CATALOG](CATALOG/CATALOG.md) - callable routine catalog and catalog proof examples.
- [HASH](HASH/HASH_MAP.md) - hash policy, FNV-era notes, CRC16 direction, and [Hash Trash](HASH/HASH_TRASH.md).
- [ASM](ASM/ASM_USER_GUIDE.md) - onboard assembler operator guide;
  see [ADDRESS_PRACTICES.md](ASM/ADDRESS_PRACTICES.md) for practical address
  choices and command address roles,
  see [AP_LINKER_CURRENT_IMAGE_GATES.md](ASM/AP_LINKER_CURRENT_IMAGE_GATES.md)
  for the frozen missing-import and banked-source current-image proof,
  see [HASHED_ASM.md](ASM/HASHED_ASM.md) for source/parser/reference material,
  see [DECISIONS.md](ASM/DECISIONS.md) for AP package/envelope/install
  boundaries,
  see [INTERACTIVE_BATCH.md](ASM/INTERACTIVE_BATCH.md) for the parked future
  `ASM I/B` idea, [ASM_CALL_MAP.md](ASM/ASM_CALL_MAP.md) for the routine-flow
  map, [ASM_SHARED_ROUTINES_AUDIT.md](ASM/ASM_SHARED_ROUTINES_AUDIT.md) for
  RJOIN/shared-helper candidates, and [TEST_PLAN.md](ASM/TEST_PLAN.md) for ASM
  test gates.
- [QCC](QCC/INDEX.md) - Questions, Comments, Concerns working notes.
- [LOGS](LOGS/HARDWARE_TEST_LOG.md) - hardware transcript proof.
- [STORY](STORY/BOOK.md) - book spine and historical narrative.
- [PLANNING](PLANNING/TODO.md) - TODO, future direction, and the
  [Overlay Integration Layer .710 test plan](PLANNING/OIL_710_TEST_PLAN.md), plus the
  [historical code migration plan](PLANNING/HISTORICAL_CODE_MIGRATION_PLAN.md)
  and [data-structure opportunities audit](PLANNING/DATA_STRUCTURE_OPPORTUNITIES.md).
- [META](META/XREF.md) - bibliography and cross-reference.

## Story And Planning

These are useful for the human arc and future direction, but not required for
the main operator/technical path.

- [STORY/BOOK.md](STORY/BOOK.md) - manuscript spine.
- [STORY/HISTORICAL_DOCUMENTS.md](STORY/HISTORICAL_DOCUMENTS.md) - lineage.
- [TODO.md](PLANNING/TODO.md) - near-term work.
- [OIL_710_TEST_PLAN.md](PLANNING/OIL_710_TEST_PLAN.md) - `.710` Overlay
  Integration Layer board-test plan and size review.
- [STR8_J012_OPAQUE_BANK_PLAN.md](PLANNING/STR8_J012_OPAQUE_BANK_PLAN.md) -
  accepted STR8 `J0`-`J2` opaque-bank implementation and board-proof plan.
- [STR8_MULTIBOOT_BANK_VOLUMES.md](PLANNING/STR8_MULTIBOOT_BANK_VOLUMES.md) -
  retained S19 ownership/bank-volume architecture plus superseded J/BPB
  design history.
- [HISTORICAL_CODE_MIGRATION_PLAN.md](PLANNING/HISTORICAL_CODE_MIGRATION_PLAN.md) - archive plan for retired sample,
  test, proof, demo, and one-off code/data.
- [DATA_STRUCTURE_OPPORTUNITIES.md](PLANNING/DATA_STRUCTURE_OPPORTUNITIES.md) -
  shared schema, fixed-ABI, table-generation, and structure-of-arrays audit.
- [FUTURE.md](PLANNING/FUTURE.md) - direction notes.

## Current Generated Source Snapshot

Quick scan of the operational HIMON/STR8 source set used by `DOC/GENERATED`:

```text
Source files scanned:  30
XDEF declarations:     222
XREF declarations:     152
ROUTINE headers:       144
JSR/JMP call sites:    1363
Unique direct edges:   1103
```

Generated reports live in [../GENERATED](../GENERATED).
