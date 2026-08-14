# R-YORS Documentation Map

This map explains how the hand-written docs fit together. Markdown is
canonical; `DOC/HTML` and the root `index.html` redirect are generated,
ignored, untracked presentation and are only rebuilt on explicit request.
The HTML snapshot covers all Markdown under `DOC`, the root README, and every
repository `README.md` under `SRC`.

## Main Spine

```text
README.md
  -> DOC/INDEX.md
     -> GUIDES/OPERATORS_GUIDE.md
     -> GUIDES/TECHNICAL_GUIDE.md
     -> GUIDES/REF.md
     -> GUIDES/GLOSSARY.md
     -> GUIDES/DECISIONS.md
```

## Product Map

```text
R-YORS
  whole project/system direction
  keeps source, ROMs, maps, decisions, reports, and manuals together

STR8
  reset-time recovery/update guard
  installs dense sector ranges transactionally and runs recovery RAM tools
  maintains directory journals, guarded top-sector backup/rewrite, and recovery
  validates enrolled-bank handoffs and publishes the accepted Bank Jump Record
  owns protected top-sector policy while STR8 is active

IVI / LEAF
  IVI is the interrupt-vector indirection mechanism
  LEAF is the future friendly front door over that mechanism

HIMON
  default monitor payload
  owns ordinary inspection, loading, debug, disassembly, assembler direction,
  and current hash/catalog workbench behavior

ASM
  onboard assembler and AP v2 object producer
  supports binary/mask literals, expressions, local/global names, typed public
  metadata, compact raw/CSTR/HBSTR/PSTR data, and the
  SEAL/RELOCATE/PACKAGE/INSTALL/LOAD lifecycle

OIL
  Overlay Integration Layer
  carries AP objects from storage through load, relocation, resident-import
  integration, and execution

Deck Plan
  bench-facing names for the control blocks and phase-owned work areas:
  APC, LRS, AIR, FTC, RFD/RTC/RPT, RSC, the Bank Jump Record, and a future external bank inventory

THE
  future hash/catalog resolver environment
  not the boot safety layer and not arbitrary command execution

Payload targets
  BASIC, Forth, apps, tools, and user monitors that can stand beside HIMON
```

Short form:

```text
R-YORS boots through STR8.
STR8 keeps recovery/update safe.
STR8 hands normal operation to HIMON or another payload.
HIMON provides the default monitor/debug/catalog workbench.
ASM creates AP objects; OIL integrates and runs them.
```

## Reader Paths

```text
Operator
  OPERATORS_GUIDE.md
  REF.md
  LOGS/HARDWARE_TEST_LOG.md
  HIMON/HIMON_DEBUG_TESTING.md

Technical
  TECHNICAL_GUIDE.md
  PLANNING/STR8_MULTIBOOT_BANK_VOLUMES.md
  STR8/PRODUCT_BOUNDARIES.md
  STR8/STR8.md
  MEMORY/MEMORY_MAP.md
  HIMON/HIMON_MAP.md
  CATALOG/CATALOG.md
  DOC/GENERATED/*

Policy
  DECISIONS.md
  DOC_FLASH.md
  HASH_FLASH.md
  QCC/*

Story
  STORY/BOOK.md
  STORY/HISTORICAL_DOCUMENTS.md
  DOC/IDEAS.md
```

The story path is intentionally outside the main operator/technical path.

## Source Map

```text
Current R-YORS operational source used by generated routine docs:

HIMON/
  SRC/HIMON/himon.asm
  SRC/HIMON/*.inc
  SRC/HIMON/fnv1a-fold.asm

Support/
  SRC/LIB/ftdi/*.asm
  SRC/LIB/dev/*.asm
  SRC/LIB/util/*.asm

```

Legacy demos, harnesses, games, ACIA/PIA, and historical monitor experiments
remain documented where useful, but they are outside the generated operational
maps unless promoted. Current `SRC/ASM` remains active build source, but it is
documented through the ASM-specific hand-maintained maps rather than the
operational HIMON routine generator. STR8-N source is external and is mapped
in the standalone repository.

Active source lanes are reserved for code/data used to create current onboard
R-YORS images or board-ingested data. Retired samples, tests, proofs, demos,
and one-off data belong under `SRC/ARCHIVE/`; the migration plan is
[PLANNING/HISTORICAL_CODE_MIGRATION_PLAN.md](PLANNING/HISTORICAL_CODE_MIGRATION_PLAN.md).

`LOCAL/` is ignored and may contain private source homes:

```text
LOCAL/basic-programs/
LOCAL/fig-forth/
LOCAL/msbasic/
LOCAL/wdcmonv2/
LOCAL/s3x/
```

## Guide Roles

```text
OPERATORS_GUIDE.md              current board-facing guide
ASM/ASM_USER_GUIDE.md           ASM operator guide
ASM/ADDRESS_PRACTICES.md        ASM address-role operator guide
ASM/AP_LINKER_CURRENT_IMAGE_GATES.md frozen moved-linker board gates
ASM/LIFE16_QUICK_CARD.md        exact ASM-F2 Life bank-2 bench sequence
ASM/LIFE16_BANK2_EXAMPLE.md     ASM-F2 16x16 Life AP bank-2 walkthrough
TECHNICAL_GUIDE.md              current architecture guide
REF.md                          compact reference
GLOSSARY.md                     vocabulary only
DECISIONS.md                    settled calls
QCC/                            active design questions
HASH_FLASH.md                   command-surface and milestone alerts
DOC_FLASH.md                    documentation-shape alerts
STR8/PRODUCT_BOUNDARIES.md      product ownership lanes
STR8/STR8.md                    standalone STR8-N integration index
STR8/STR8_BANK_JUMP_RECORD_BOARD_TEST.md retained historical proof rail
STR8/STR8_WORK_PROCESS.md       STR8 proof/work rail
STR8/STR8_V0_RESTORE_FAILURE_GATES.md guarded restore/failure gate card
LOGS/HARDWARE_TEST_LOG.md       board transcript validations
HIMON/HIMON_DEBUG_TESTING.md    RAM debug proof process
MEMORY/MEMORY_MAP.md            address ownership
../GENERATED/CONTROL_DECK_MAP.md layered Deck Plan/control-block atlas
CATALOG/CATALOG.md              callable routine selection view
HIMON/HIMON_MAP.md              readable HIMON top-level routine and capability map
HIMON/HIMON_EDGE_DUMP.md        raw direct-edge evidence
ASM/SYMBOL_XREF.md              symbol/routine cards and tags
HASH/HASH_MAP.md                hash meanings and connections
HASH/HASH.md                    FNV-era details and CRC16 pivot
ASM/HASHED_ASM.md               assembler thesis and fixups
ASM/ASM_CALL_MAP.md             renderable ASM top-level routine-purpose and flow map
ASM/ASM_SHARED_ROUTINES_AUDIT.md ASM/HIMON shared-helper audit
PLANNING/OIL_710_TEST_PLAN.md .710 Overlay Integration Layer board-test rail
PLANNING/STR8_MULTIBOOT_BANK_VOLUMES.md multiboot/S19/bank-volume direction
PLANNING/HISTORICAL_CODE_MIGRATION_PLAN.md retired code/data archive plan
STORY/BOOK.md                   narrative manuscript spine
STORY/HISTORICAL_DOCUMENTS.md   lineage and evidence map
```

## Mermaid View

```mermaid
flowchart TD
    README[README] --> INDEX[DOC/INDEX]
    INDEX --> OP[Operator Lane]
    INDEX --> TECH[Technical Lane]
    INDEX --> POLICY[Policy Lane]
    INDEX --> STORY[Story Lane]

    OP --> PROOF[Hardware Proof]
    TECH --> STR8[STR8]
    TECH --> HIMON[HIMON]
    TECH --> ASM[ASM]
    TECH --> OIL[OIL: Overlay Integration Layer]
    TECH --> DATA[Memory / Catalog / Hash]
    TECH --> DECKS[Control Deck Atlas]

    ASM --> SEAL[SEAL / RELOCATE / PACKAGE]
    SEAL --> OIL
    HIMON --> OIL
    STR8 --> OIL
    OIL --> PROOF
    DECKS --> OIL
    POLICY --> DEC[Decisions / QCC]
    STORY --> HIST[Book / History]
```

## Consistency Rules

- `OPERATORS_GUIDE.md` is the canonical board-facing guide.
- `TECHNICAL_GUIDE.md` is the canonical architecture guide.
- `BOOK.md`, `HISTORICAL_DOCUMENTS.md`, and `DOC/IDEAS.md` are story and
  narrative support, not required main-path docs.
- `DECISIONS.md` is the settled-call list. Check it before reopening design
  alternatives.
- `QCC/` preserves active design thinking without making it
  settled spec.
- Settled QCC answers should move into `DECISIONS.md`.
- Each concept should have one canonical home. Other documents may summarize
  and link, but should not restate the full explanation.
- Generated docs should remain evidence or views, not the primary hand-written
  explanation.
- New guide files should be added to `INDEX.md`, `TOC.md`, `MAP.md`,
  `META/XREF.md`, and `META/BIB.md` together.
