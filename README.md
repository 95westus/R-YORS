![R-YORS logo](DOC/branding/logo-r-yors.svg)

# R-YORS

```text
ROLL YA OWN RUNTIME SYSTEM              W65C02
NOTES / SOURCE / ROMS / MANUALS         READ ME FIRST
```

Not eRRORS, but expect fewer.

Pronounced **are-yors**.

## Current Milestone

As of 2026-07-10, the board has the OIL `.710` path on hardware: HIMON can
load, link, and run AP packages from banked flash, and the STR8 top sector can
identify itself as `STR8-N V0 #5F6A0F7A` at `$FACE`.

Flash ASM is now `ASM-F2`, built into the primary image at `$8000`. Narrow
development updates can still load it with `L F` as `LF OK WR=3969 GO=800C`.
It enters through HIMON's FNV/RJOIN catalog as `ASM`, uses the PC-bearing
prompt `ASM>$hhhh:`, assembles W65C02 source into RAM, seals contiguous bodies,
packages AP v1 envelopes, loads packages into RAM, and can install AP envelopes
to visible or banked flash by using the current helper sources.

The current AP path can:

```text
PACKAGE $3200             write an AP envelope in RAM
LOAD $3200 $3000          relocate/run a RAM package body
INSTALL $3200 $hhhh       store an envelope in visible low flash
AP $hhhh $3000            load/run an installed visible-flash package
AP $B969 $4800            run the built-in fixed-address ASM session reporter
AP B2 $9000 $3000         load/link/run a package stored in bank 2
AP B2 $8000 $4800         run the stored fixed-address ASM session reporter
```

HIMON now exposes the resident services this path needs, including the AP
service, PACK40 helper service, flash-install service, and STR8-backed resident
import linker. `AP B2` is board-proven with no-import packages, resident RJOIN
imports, missing-import failure, bad-input rejection, and overlap protection.

Treat ASM as a young onboard workbench, not a finished hosted toolchain. Its
current limits, package/install direction, address practices, and hardware
transcripts live in the ASM/HIMON docs and proof logs:

```text
DOC/GUIDES/ASM/ASM_USER_GUIDE.md
DOC/GUIDES/ASM/ADDRESS_PRACTICES.md
DOC/GUIDES/ASM/HASHED_ASM.md
DOC/GUIDES/ASM/DECISIONS.md
DOC/GUIDES/ASM/FLASH_8000_GAME_PLAN.md
DOC/GUIDES/ASM/TEST_PLAN.md
DOC/GUIDES/HIMON/HIMON_DEBUG_TESTING.md
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
STR8-N  maps flash, backs up/restores images, installs $C000 payloads, serves bank flash work
HIMON   dumps/modifies memory, loads S19/flash S19, debugs RAM, dispatches FNV/RJOIN/AP services
ASM-F2  assembles W65C02 source, seals/relocates/packages/loads AP bodies
```

Current boot shape:

```text
reset -> STR8-N -> HIMON -> user work
```

STR8-N is useful even if the payload is not HIMON. The same proven `$C000-$EFFF`
update gate has booted HIMON, OSI BASIC, and fig-FORTH as live images.

## Install And Update Boundary

Today, an external flash programmer is required to put R-YORS on a blank board:
burn the combined STR8/HIMON ROM image once, then boot the board into STR8 and
HIMON. STR8-N also provides the current `$F003` bank/flash worker service and
`$F006` AP import-link service used by HIMON/AP.

After that first install, ordinary bench updates should not need the external
programmer:

```text
STR8 U / UPDATE HIMON   updates the $C000-$EFFF HIMON/payload image
HIMON L F               installs fixed-address low-flash tools such as ASM
ASM PACKAGE/INSTALL     stores AP envelopes for later HIMON/AP loading
```

Keep the programmer as the final recovery path for a bricked board, a damaged
STR8/recovery sector, or deliberate whole-chip replacement. It is not the
normal day-to-day update path once STR8/HIMON is alive.

## What We Can Do Today

On a board with the current HIMON/STR8-N/ASM-F2 image, the proven working set
is:

```text
boot through STR8-N into HIMON
update the $C000-$EFFF HIMON/payload image through STR8
run built-in flash ASM-F2, or update it with L F during narrow development
assemble RAM programs from ASM NEW
SEAL, PACKAGE, LOAD, INSTALL, and run AP envelopes
store AP envelopes in bank 2 and run them with AP B2
resolve resident RJOIN imports during AP load/run
run the built-in ASM session reporter with AP $B969 $4800
run the bank-2 ASM session reporter with AP B2 $8000 $4800 when using that proof image
rewrite the STR8-N top sector with str8n-topwrite-3000.a when recovery is ready
```

The practical address guide for these flows is:

```text
DOC/GUIDES/ASM/ADDRESS_PRACTICES.md
```

## Current Status

Updated 2026-07-10.

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
as `@hhhh`, invalid debug patch targets report `DBG RAM`, and the debug opcode
display keeps the register dump while using compact opcode metadata. The
resident unassemble command was removed; NMI-to-debug remains.

HIMON loader and memory-boundary behavior is hardware-proven for the current
RAM/I/O split: `$7F00-$7FFF` is skipped as I/O by `D`, protected by `M`, and
rejected by normal `L` with `LERR=$02`; `L F` keeps address-rich failure
diagnostics for protected flash writes.

ASM is hardware-proven as both a RAM-loaded paste runtime and flash-resident
`ASM-F2`. The current `make all` image carries ASM-F2 at `$8000`; narrow
development passes can still refresh it through `L F`. It enters as `ASM-F2`,
assembles source to `$2000+`, resolves resident routines through RJOIN, and has
run the biorhythm-style chart and interactive Life samples on the board. The
SEAL/AP path is hardware-proven for internal relocation,
resident import resolution, AP v1 package creation, visible-flash install/load,
banked `AP B2` load/run, and the package/body distinction: envelopes can be
copied as data, while BODY execution at a different base requires relocation.

The generated fixed-address session reporter is now also built into the primary
image as an AP package at `$B969` and runs at `$4800`, so table/report detail is
available after an ASM session without reloading a RAM reporter. The bank 2
storage proof remains available with `AP B2 $8000 $4800`.

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
DOC/GUIDES/ASM/ASM_USER_GUIDE.md use ASM: source, prompts, END/SEAL/PACKAGE
DOC/GUIDES/ASM/ADDRESS_PRACTICES.md choose addresses for ASM/AP workflows
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

A small bench note in the book spine, dated 2026-07-02:

> Bad moods are weather, not character. Good work still gets done under cloudy weather.

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
make all
```

Builds the current onboard firmware image and install stream. The primary 32K
bank image includes ASM-F2 in low flash, the built-in fixed-address ASM session
reporter AP package, HIMON V at `$C000`, and STR8-N at `$F000`.

Primary outputs:

```text
SRC/BUILD/bin/himon-str8-rom.bin
SRC/BUILD/s19/himon-str8-rom-install.s19
```

Useful targets:

```text
make all
make release
make docs-html
make -C SRC help
make -C SRC himon
make -C SRC str8
make -C SRC himon-str8-rom-bin
make -C SRC life
make -C SRC himon-str8-himon-update-s19
make -C SRC fig-forth-str8-update-s19
make -C SRC msbasic-osi-str8-update-s19
```

`make release` adds docs and the current release side artifacts. `make life`
still builds a standalone loadable S19/BIN app without changing the onboard
image. `make release-local` adds ignored/private local composites when `LOCAL/`
is populated. `make docs-html` is an explicit/manual presentation rebuild only;
`DOC/HTML` is ignored and untracked, and Markdown remains canonical.

## Repository Map

```text
SRC/HIMON/      HIMON monitor payload source
SRC/STR8/       STR8 recovery/update source
SRC/LIB/        shared ROM support libraries
SRC/PROOFS/     transition lane for current proof scaffolds
SRC/APPS/       transition lane for current standalone applications
SRC/TESTS/      transition lane for current test harnesses
SRC/ARCHIVE/    retired source and historical code/data
SRC/tools/      host-side build and support scripts
DOC/GUIDES/     hand-written guides
DOC/GENERATED/  source-derived reports
DOC/HTML/       generated, ignored static presentation view
LOCAL/          ignored local source homes, when present
```

Active source lanes should hold only code/data used to create current onboard
R-YORS images or board-ingested data. Current in-use STR8-N, HIMON V, and
ASM-F2 files keep their structure; retired samples, tests, proofs, demos, and
one-off data should move to `SRC/ARCHIVE/` in the batches described by
`DOC/GUIDES/PLANNING/HISTORICAL_CODE_MIGRATION_PLAN.md`.

From here on out, new code/data should be processed on board where practical:
through HIMON, flash ASM-F2, AP packages, STR8 update/install flows, or later
managed onboard records. Host-side generators remain only where they still
bootstrap or regenerate current onboard artifacts.

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
