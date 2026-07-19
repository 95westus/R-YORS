# R-YORS Guide TOC

This is the short reading path. Use [INDEX.md](./INDEX.md) when you want the
full shelf list, and [MAP.md](./MAP.md) when you want to see how the pieces
connect.

## Read First

1. [OPERATORS_GUIDE.md](./OPERATORS_GUIDE.md) - use the board: STR8, HIMON, payload updates, recovery, and current status.
2. [TECHNICAL_GUIDE.md](./TECHNICAL_GUIDE.md) - understand the system: product roles, memory, flash, IVI, source layout, and build artifacts.
3. [REF.md](./REF.md) - compact reference sheet.
4. [GLOSSARY.md](./GLOSSARY.md) - shared vocabulary.
5. [DECISIONS.md](./DECISIONS.md) - settled calls to avoid reopening by accident.

## Status And Proof

- [HASH_FLASH.md](./HASH_FLASH.md) - command-surface and milestone alerts.
- [DOC_FLASH.md](./DOC_FLASH.md) - documentation-shape alerts.
- [LOGS/HARDWARE_TEST_LOG.md](LOGS/HARDWARE_TEST_LOG.md) - board transcript proof.

## Detail Shelves

- [STR8](STR8/STR8.md) - recovery, update, product boundaries, bringup,
  work process, and [edge evidence](STR8/STR8_EDGE_DUMP.md).
- [HIMON](HIMON/HIMON_MAP.md) - monitor maps, stage notes, debug, search, and edge evidence.
- [MEMORY](MEMORY/MEMORY_MAP.md) - address ownership and allocation direction.
- [CATALOG](CATALOG/CATALOG.md) - callable routine catalog and catalog proof examples.
- [HASH](HASH/HASH_MAP.md) - hash policy, FNV-era notes, CRC16 direction, and parked ideas.
- [ASM](ASM/ASM_USER_GUIDE.md) - onboard assembler operator guide, with
  [ADDRESS_PRACTICES.md](ASM/ADDRESS_PRACTICES.md) as the quick address-role
  operator guide,
  [LIFE16_QUICK_CARD.md](ASM/LIFE16_QUICK_CARD.md) as the exact Life bench
  sequence,
  [LIFE16_BANK2_EXAMPLE.md](ASM/LIFE16_BANK2_EXAMPLE.md) as the full bank-2 AP
  example,
  [HASHED_ASM.md](ASM/HASHED_ASM.md) as the source/parser reference,
  including the [ASM call map](ASM/ASM_CALL_MAP.md),
  [shared-routine audit](ASM/ASM_SHARED_ROUTINES_AUDIT.md), and parked future
  [ASM I/B idea](ASM/INTERACTIVE_BATCH.md).
- [QCC](QCC/INDEX.md) - active Questions, Comments, Concerns working notes.
- [PLANNING](PLANNING/TODO.md) - near-term work and future direction.
- [META](META/XREF.md) - bibliography and cross-reference.

## Story Lane

Read these when writing or filling the narrative, not when trying to operate the
board:

1. [BOOK.md](STORY/BOOK.md) - manuscript spine.
2. [HISTORICAL_DOCUMENTS.md](STORY/HISTORICAL_DOCUMENTS.md) - lineage and evidence.
3. [../IDEAS.md](../IDEAS.md) - scratchpad and special moments.

## Planning

- [TODO.md](PLANNING/TODO.md) - near-term work.
- [OIL_710_TEST_PLAN.md](PLANNING/OIL_710_TEST_PLAN.md) - `.710` Overlay
  Integration Layer board-test rail and size-review recommendations.
- [STR8_MULTIBOOT_BANK_VOLUMES.md](PLANNING/STR8_MULTIBOOT_BANK_VOLUMES.md) -
  accepted multiboot, S19 ownership, and append-only bank-volume direction.
- [HISTORICAL_CODE_MIGRATION_PLAN.md](PLANNING/HISTORICAL_CODE_MIGRATION_PLAN.md) - plan for moving retired samples,
  tests, proofs, apps, and data into `SRC/ARCHIVE/`.
- [FUTURE.md](PLANNING/FUTURE.md) - direction notes.

## Core Thread

```text
R-YORS
  -> STR8 board management and recovery
  -> IVI mechanism and future LEAF front door
  -> HIMON default monitor payload
  -> other payload targets
  -> compact-hash command and symbol lookup
  -> onboard assembler with fixups
  -> banked flash growth and catalog maintenance
```
