# R-YORS Guide Index

This is the full guide index for the current R-YORS documentation set.

## Start Here

- [OPERATORS_GUIDE.md](./OPERATORS_GUIDE.md) - canonical board-facing guide for R-YORS, STR8, and HIMON operation.
- [TECHNICAL_GUIDE.md](./TECHNICAL_GUIDE.md) - canonical architecture guide for R-YORS, STR8, HIMON, memory, flash, source layout, and build outputs.
- [REF.md](./REF.md) - compact reference sheet.
- [GLOSSARY.md](./GLOSSARY.md) - vocabulary contract.
- [DECISIONS.md](./DECISIONS.md) - settled calls.

## Current Milestone

STR8 is hardware-proven rotating three bootable live-bank images: HIMON, OSI
BASIC, and fig-FORTH. HIMON RAM-only debug is hardware-proven for current
one-shot breakpoint and single-step behavior.

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

- [STR8](STR8/STR8.md) - recovery, updates, product boundaries, bringup, work process.
- [HIMON](HIMON/HIMON_MAP.md) - monitor maps, stage notes, debug, search, edge evidence.
- [MEMORY](MEMORY/MEMORY_MAP.md) - address ownership and allocation direction.
- [CATALOG](CATALOG/CATALOG.md) - callable routine catalog and catalog proof examples.
- [HASH](HASH/HASH_MAP.md) - hash policy, FNV-era notes, CRC16 direction, and [Hash Trash](HASH/HASH_TRASH.md).
- [ASM](ASM/HASHED_ASM.md) - onboard assembler and symbol reference material; see [TEST_PLAN.md](ASM/TEST_PLAN.md) for ASM test gates.
- [QCC](QCC/INDEX.md) - Questions, Comments, Concerns working notes.
- [LOGS](LOGS/HARDWARE_TEST_LOG.md) - hardware transcript proof.
- [STORY](STORY/BOOK.md) - book spine and historical narrative.
- [PLANNING](PLANNING/TODO.md) - TODO and future direction.
- [META](META/XREF.md) - bibliography and cross-reference.

## Story And Planning

These are useful for the human arc and future direction, but not required for
the main operator/technical path.

- [STORY/BOOK.md](STORY/BOOK.md) - manuscript spine.
- [STORY/HISTORICAL_DOCUMENTS.md](STORY/HISTORICAL_DOCUMENTS.md) - lineage.
- [TODO.md](PLANNING/TODO.md) - near-term work.
- [FUTURE.md](PLANNING/FUTURE.md) - direction notes.

## Current Generated Source Snapshot

Quick scan of the operational HIMON/STR8 source set used by `DOC/GENERATED`:

```text
Source files scanned:  27
XDEF declarations:     179
XREF declarations:     143
ROUTINE headers:       130
JSR/JMP call sites:    989
Unique direct edges:   779
```

Generated reports live in [../GENERATED](../GENERATED).
