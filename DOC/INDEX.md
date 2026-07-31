# R-YORS Documentation

This is the documentation front desk. Start with the small main path, then open
supporting references only when you need detail.

## Main Path

```text
README.md
DOC/GUIDES/OPERATORS_GUIDE.md
DOC/GUIDES/TECHNICAL_GUIDE.md
```

- [GUIDES/OPERATORS_GUIDE.md](./GUIDES/OPERATORS_GUIDE.md) - board operation: current status, STR8 workflows, HIMON commands, payload updates, recovery.
- [GUIDES/TECHNICAL_GUIDE.md](./GUIDES/TECHNICAL_GUIDE.md) - architecture: product roles, source layout, memory, flash, IVI, build artifacts.
- [GUIDES/REF.md](./GUIDES/REF.md) - compact reference sheet.
- [GUIDES/GLOSSARY.md](./GUIDES/GLOSSARY.md) - vocabulary contract.
- [GUIDES/DECISIONS.md](./GUIDES/DECISIONS.md) - settled policy.
- [GUIDES/PLANNING/STR8_J012_OPAQUE_BANK_PLAN.md](./GUIDES/PLANNING/STR8_J012_OPAQUE_BANK_PLAN.md) - accepted `J0`-`J2` opaque-bank implementation and hardware-proof plan.
- [GUIDES/STR8/STR8_BOOT_SELECTOR_BOARD_TEST.md](./GUIDES/STR8/STR8_BOOT_SELECTOR_BOARD_TEST.md) - pending board-proof rail for the reset-time `0`/`1`/`2`/`3`/`S` selector.
- [GUIDES/STR8/STR8_GUEST_IMAGE_QUALIFICATION.md](./GUIDES/STR8/STR8_GUEST_IMAGE_QUALIFICATION.md) - required per-image handoff, peripheral, vector, CRC, and recovery procedure for unrelated 32K guests.
- [GUIDES/PLANNING/STR8_MULTIBOOT_BANK_VOLUMES.md](./GUIDES/PLANNING/STR8_MULTIBOOT_BANK_VOLUMES.md) - retained S19/bank-volume direction and superseded compatible-bank design history.

## Current Status

The compatible fixed `$C000-$EFFF` payload path has hardware proof for HIMON,
OSI BASIC, and fig-FORTH. That is not opaque 32K `Jn` qualification.
`J0`-`J2` is hardware-proven on the recorded R-YORS bank images; every
unrelated guest requires its own H/P/V/CRC record. HIMON RAM-only debug is
hardware-proven for the current one-shot breakpoint and single-step surface.
The reset-time `0`/`1`/`2`/`3`/`S` selector follow-up is host-built and awaits
its separate board transcript.

- [GUIDES/HASH_FLASH.md](./GUIDES/HASH_FLASH.md) - milestone and command alerts.
- [GUIDES/DOC_FLASH.md](./GUIDES/DOC_FLASH.md) - documentation-shape alerts.
- [GUIDES/LOGS/HARDWARE_TEST_LOG.md](GUIDES/LOGS/HARDWARE_TEST_LOG.md) - board proof.
- [GUIDES/STORY/HIMON_STR8_LIVE_UPDATE_LOG.md](GUIDES/STORY/HIMON_STR8_LIVE_UPDATE_LOG.md) - live HIMON update and rollback proof, tracked by `(2312) -> (2317) -> (2312)`.

## Guide Indexes

- [GUIDES/INDEX.md](./GUIDES/INDEX.md) - full guide index.
- [GUIDES/TOC.md](./GUIDES/TOC.md) - recommended reading order.
- [GUIDES/MAP.md](./GUIDES/MAP.md) - documentation and system map.
- [GUIDES/META/XREF.md](GUIDES/META/XREF.md) - document/source cross-reference.
- [GUIDES/META/PROVENANCE.md](GUIDES/META/PROVENANCE.md) - idea-origin and outside-help marking rules.

## Story Lane

The story is intentionally outside the main operator/technical path:

- [GUIDES/STORY/BOOK.md](GUIDES/STORY/BOOK.md) - manuscript spine.
- [GUIDES/STORY/HISTORICAL_DOCUMENTS.md](GUIDES/STORY/HISTORICAL_DOCUMENTS.md) - lineage.
- [IDEAS.md](./IDEAS.md) - scratchpad and special moments.

## Guide Shelves

- [GUIDES/STR8](GUIDES/STR8/STR8.md) - recovery, update, product boundaries, bringup.
- [GUIDES/HIMON](GUIDES/HIMON/HIMON_MAP.md) - monitor maps, debug, search, stage notes.
- [GUIDES/MEMORY](GUIDES/MEMORY/MEMORY_MAP.md) - address ownership and allocation direction.
- [GUIDES/CATALOG](GUIDES/CATALOG/CATALOG.md) - routine catalog and catalog proof notes.
- [GUIDES/HASH](GUIDES/HASH/HASH_MAP.md) - hash references and map.
- [GUIDES/ASM](GUIDES/ASM/HASHED_ASM.md) - assembler and symbol references; includes the [ASM test plan](GUIDES/ASM/TEST_PLAN.md).
- [GUIDES/QCC](GUIDES/QCC/INDEX.md) - active design questions.
- [GUIDES/LOGS](GUIDES/LOGS/HARDWARE_TEST_LOG.md) - hardware proof logs.
- [GUIDES/PLANNING](GUIDES/PLANNING/TODO.md) - TODO and future notes.
- [GUIDES/PLANNING/HISTORICAL_CODE_MIGRATION_PLAN.md](GUIDES/PLANNING/HISTORICAL_CODE_MIGRATION_PLAN.md) - plan for moving retired samples, tests, proofs, and demos into
  `SRC/ARCHIVE/`.
- [GUIDES/META](GUIDES/META/XREF.md) - bibliography and cross-reference.

Generated source analysis lives in [GENERATED](./GENERATED).
