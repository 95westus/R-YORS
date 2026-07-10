# R-YORS Guide Index

This is the full guide index for the current R-YORS documentation set.

## Start Here

- [OPERATORS_GUIDE.md](./OPERATORS_GUIDE.md) - canonical board-facing guide for R-YORS, STR8, and HIMON operation.
- [ASM/ASM_USER_GUIDE.md](ASM/ASM_USER_GUIDE.md) - operator guide for ASM source, prompts, END/SEAL, relocation, and packages.
- [TECHNICAL_GUIDE.md](./TECHNICAL_GUIDE.md) - canonical architecture guide for R-YORS, STR8, HIMON, memory, flash, source layout, and build outputs.
- [REF.md](./REF.md) - compact reference sheet.
- [GLOSSARY.md](./GLOSSARY.md) - vocabulary contract.
- [DECISIONS.md](./DECISIONS.md) - settled calls.

## Current Milestone

STR8 is hardware-proven rotating three bootable live-bank images: HIMON, OSI
BASIC, and fig-FORTH. HIMON RAM-only debug is hardware-proven for current
one-shot breakpoint and single-step behavior, with the resident unassembler
removed and the `$7F00-$7FFF` I/O page protected by dump/load/debug paths. ASM
is flash-resident as a HIMON command and now has board-proven SEAL, RESOLVE,
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

- [STR8](STR8/STR8.md) - recovery, updates, product boundaries, bringup, work process, and [edge evidence](STR8/STR8_EDGE_DUMP.md).
- [HIMON](HIMON/HIMON_MAP.md) - monitor maps, stage notes, debug, search, edge evidence.
- [MEMORY](MEMORY/MEMORY_MAP.md) - address ownership and allocation direction.
- [CATALOG](CATALOG/CATALOG.md) - callable routine catalog and catalog proof examples.
- [HASH](HASH/HASH_MAP.md) - hash policy, FNV-era notes, CRC16 direction, and [Hash Trash](HASH/HASH_TRASH.md).
- [ASM](ASM/ASM_USER_GUIDE.md) - onboard assembler operator guide;
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
- [PLANNING](PLANNING/TODO.md) - TODO, future direction, and
  [OIL .710 test plan](PLANNING/OIL_710_TEST_PLAN.md).
- [META](META/XREF.md) - bibliography and cross-reference.

## Story And Planning

These are useful for the human arc and future direction, but not required for
the main operator/technical path.

- [STORY/BOOK.md](STORY/BOOK.md) - manuscript spine.
- [STORY/HISTORICAL_DOCUMENTS.md](STORY/HISTORICAL_DOCUMENTS.md) - lineage.
- [TODO.md](PLANNING/TODO.md) - near-term work.
- [OIL_710_TEST_PLAN.md](PLANNING/OIL_710_TEST_PLAN.md) - `.710` OIL
  on-board intensive test plan and size review.
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
