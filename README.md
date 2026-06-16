![R-YORS logo](DOC/branding/logo-r-yors.svg)

# R-YORS

```text
ROLL YA OWN RUNTIME SYSTEM              W65C02
NOTES / SOURCE / ROMS / MANUALS         READ ME FIRST
```

Not eRRORS, but expect fewer.

Pronounced **are-yors**.

## Current Milestone

As of 2026-06-15, ASM v1 is a flash-resident HIMON command. `L F` loads
`SRC/BUILD/s19/asm-v1-flash-8000.s19` at `$8000`, reports
`WR=2D6B GO=800C`, and `ASM` enters the assembler through HIMON's FNV catalog.

ASM assembles pasted W65C02 source into bare RAM programs at `$2000+`, supports
`EQU`/`DB`/`DW`/`DS`, local labels, forward fixups, and direct resident
`JSR`/`JMP` targets through RJOIN/K05 records. It has run interactive Life,
the biorhythm-style chart, PACK40 round trips, and directive smoke programs on
the real board.

Treat ASM as a young onboard workbench, not a finished hosted toolchain. Its
current limits and hardware transcripts live in the ASM docs and proof logs:

```text
DOC/GUIDES/ASM/HASHED_ASM.md
DOC/GUIDES/ASM/FLASH_8000_GAME_PLAN.md
DOC/GUIDES/ASM/TEST_PLAN.md
DOC/GUIDES/HASH_FLASH.md
DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md
```

## What This Is

R-YORS is a small recoverable runtime system for the WDC W65C02SXB/W65C02EDU
board. It is meant to make the board feel like a standalone machine: reset into
a recovery guard, boot a monitor or payload, inspect memory, load S-records,
debug RAM programs, rotate flash backups, and recover when an image goes bad.

The current product spine is:

```text
R-YORS
  STR8
  HIMON
  ASM
```

`R-YORS` is the whole project and runtime direction. `STR8` is the reset-time
recovery/update guard. `HIMON` is the default monitor/debug/catalog workbench
that STR8 boots into for ordinary use. `ASM` is the emerging onboard assembler:
flash-resident as a HIMON command, currently emitting user opcodes into RAM.

## What It Does

```text
R-YORS  keeps source, ROMs, maps, manuals, decisions, and generated reports together
STR8    maps flash, backs up images, restores images, installs $C000 payloads
HIMON   dumps/modifies memory, loads S19, disassembles, assembles, debugs RAM
ASM     assembles W65C02 source on the board and emits bare RAM programs
```

Current boot shape:

```text
reset -> STR8 -> HIMON -> user work
```

STR8 is useful even if the payload is not HIMON. The same proven `$C000-$EFFF`
update gate has booted HIMON, OSI BASIC, and fig-FORTH as live images.

## Current Status

Updated 2026-06-10.

STR8 is hardware-proven rotating three bootable images through the same guarded
path:

```text
HIMON      recovery, inspection, loading, debug
OSI BASIC  interactive BASIC payload
fig-FORTH  threaded language payload
```

The proven path includes flash map reporting, backup rotation, Bank 0
enrollment, fixed `$C000-$EFFF` `U` / `UPDATE HIMON`, HIMON U1-to-U2 update,
temporary BASIC and Forth payloads, and recovery from backup flash back to
known-good HIMON.

HIMON's RAM-only debug path is hardware-proven for `B`, `B C`, `B L`, `N`, and
`X`. One-shot breakpoints restore their original opcodes, debugger stops print
as `@hhhh`, and invalid debug patch targets report `DBG RAM`.

ASM is hardware-proven as both a RAM-loaded paste runtime and a flash-resident
HIMON command. The current flash image loads at `$8000` through `L F`, enters as
`ASM`, assembles source to `$2000+`, resolves resident routines through RJOIN,
and has run the biorhythm-style chart and interactive Life samples on the
board.

Treat the system as bench-proven, not as a finished field updater. Keep an
external programmer path and known-good image nearby.

Status streams:

```text
DOC/GUIDES/STORY/HIMON_STR8_LIVE_UPDATE_LOG.md  live update and rollback proof
DOC/GUIDES/HASH_FLASH.md      command-surface and milestone alerts
DOC/GUIDES/DOC_FLASH.md       documentation-shape alerts
DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md  board transcript proof
```

## Start Here

```text
DOC/GUIDES/OPERATORS_GUIDE.md   use the board: STR8, HIMON, workflows
DOC/GUIDES/TECHNICAL_GUIDE.md   understand the system: memory, flash, source
DOC/GUIDES/REF.md               compact reference
DOC/GUIDES/GLOSSARY.md          vocabulary contract
DOC/GUIDES/DECISIONS.md         settled policy
```

## Story Lane

The project also has a story, but the main docs should not require it. Narrative
and "how we got here" material lives here:

```text
DOC/GUIDES/STORY/BOOK.md
DOC/GUIDES/STORY/HISTORICAL_DOCUMENTS.md
DOC/IDEAS.md
```

Use those when writing the human arc. Use the operator and technical guides
when trying to run or understand the machine.

## Safety

Some code here can erase or program flash memory. Running loaders, tests,
monitor commands, ROM images, or flash utilities can overwrite firmware,
programs, user data, or board configuration.

Current safety rules:

```text
STR8 destructive flash commands confirm before erase/write.
HIMON future destructive commands must use 4+ character command words.
Do not press NMI while STR8 is mapping, erasing, programming, or restoring.
```

No warranty is provided.

## Build

```text
make release
```

Regenerates source-derived docs, builds the tracked release set, and stamps the
primary HIMON/STR8 ROM binary.

Primary image:

```text
SRC/BUILD/bin/himon-str8-rom.bin
```

Useful targets:

```text
make docs-html
make -C SRC help
make -C SRC himon
make -C SRC str8
make -C SRC himon-str8-rom-bin
make -C SRC himon-str8-himon-update-s19
make -C SRC fig-forth-str8-update-s19
make -C SRC msbasic-osi-str8-update-s19
```

`make release-local` adds ignored/private local composites when `LOCAL/` is
populated. `make docs-html` is an explicit/manual presentation rebuild only;
`DOC/HTML` is ignored and untracked, and Markdown remains canonical.

## Repository Map

```text
SRC/HIMON/      HIMON monitor payload source
SRC/STR8/       STR8 recovery/update source
SRC/LIB/        shared ROM support libraries
SRC/PROOFS/     board proofs and promotion scaffolds
SRC/APPS/       standalone applications
SRC/TESTS/      test harnesses
SRC/tools/      host-side build and support scripts
DOC/GUIDES/     hand-written guides
DOC/GENERATED/  source-derived reports
DOC/HTML/       generated, ignored static presentation view
LOCAL/          ignored local source homes, when present
```

## Hash Direction

R-YORS still contains FNV-1a work. Current HIMON command/routine notes may
mention FNV-1a records or `[HASH:XXXXXXXX]` IDs. That is now the settled public
name hash for commands, exported routines, symbols, and cross-bank imports.

Compact records can still use smaller checks and local IDs:

```text
public name -> FNV-1a32 -> typed record/payload
local table/scope -> CRC16 or short ID -> verified by record context
record/body integrity -> optional CRC32/checksum
```

STR8 V0 does not use FNV, CRC16, or CRC32 for recovery decisions.

## Lineage

R-YORS grows from the BSO2/WDC monitor line into a smaller set of reusable
routines, flash-safe recovery, compact-hash monitor/catalog lookup, and
eventually onboard assembly/catalog linking.

The long north star is still true RPG II, shaped from below: stable callable
routines, discoverable catalogs, flash-resident programs, fixed entry points,
simple text encodings, and a runtime that can explain itself.

## Notice

R-YORS is independent and is not affiliated with or endorsed by The Western
Design Center, Inc. Product names are used only to identify compatible hardware.
