![R-YORS logo](DOC/branding/logo-r-yors.svg)

# R-YORS

```text
ROLL YA OWN RUNTIME SYSTEM              W65C02
NOTES / SOURCE / ROMS / MANUALS         READ ME FIRST
```

Not eRRORS, but expect fewer.

Pronounced **are-yors**.

## 2026-05-21 Alert

An FTDI transmit bug was found and fixed in
`PIN_FTDI_WRITE_BYTE_NONBLOCK`. When TX was not ready immediately, the spin
loop's `CPX` could leave carry clear even after the byte was accepted. The
blocking writer saw `C=0` and resent the same byte, producing display artifacts
such as:

```text
expected: D0 06      observed: D00 06
expected: 0D 0A      observed: 0D 00A
expected: 00 00      observed: 00 000
```

Fix: the successful write-strobe path now forces `SEC` before returning, while
the timeout path still returns `CLC`.

Search command proofs also reached the promotion milestone:

```text
S static RAM   standalone parser/scanner proof at $3000
S joined RAM   same command behavior with runtime FNV helper discovery
S flash        discoverable low-flash FNV command record, run from ROM window
```

Summary transcripts:

```text
RAM static:
>L
L @3000
L OK=0520 GO=3000
>G 3000
HIMON SEARCH STATIC $3000
S> S 34AF +20 48 'IMON'
34AF*34A0: ... 48 | ...
S> S 7EF0 8010 00
S IO
S> Q
S DONE

RAM joined:
>L
L @3000
L OK=0589 GO=3000
>G 3000
HIMON SEARCH PROOF $3000
S> S 0 FFFF FF 00
7900 7900: ...
S IO
># S
D60C1322 HSH_NF!

Flash command, hardware-proven K=$03 transcript:
>L F
L @BA67
LF OK WR=045C GO=BA73
># S
D60C1322 ENTRY=BA73 K=03  S(earch)
>S B000 C000 'TEXT'
RUN S(earch) @BA73 K=03 ? y
BE87 BE80: ... 45 58 54 ...
>S 0 FFFF 'HIMON'
RUN S(earch) @BA73 K=03 ? y
S ABORT
```

Current source advances the flash command record to K=`$05` and relocates it to
`$BBA2-$BFFD`, with `$FF,$FF` guard pockets at `$BBA0-$BBA1` and `$BFFE-$BFFF`.
That K=`$05` shape is intended to keep `S(earch)` display text while removing
the `RUN ... ?` confirmation prompt under a new HIMON build.

## Live Proof

The clearest current transcript is
[HIMON/STR8 Live Update Proof](DOC/GUIDES/STORY/HIMON_STR8_LIVE_UPDATE_LOG.md).
It shows bank 3 moving from HIMON `(2312)` to `(2317)` and back to `(2312)`:
STR8 updates HIMON, HIMON proves the hash catalog filters and confirmed
`BOOT_COLD_RESET`, then STR8 restores the earlier image.

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
```

`R-YORS` is the whole project and runtime direction. `STR8` is the reset-time
recovery/update guard. `HIMON` is the default monitor/debug/catalog workbench
that STR8 boots into for ordinary use.

## What It Does

```text
R-YORS  keeps source, ROMs, maps, manuals, decisions, and generated reports together
STR8    maps flash, backs up images, restores images, installs $C000 payloads
HIMON   dumps/modifies memory, loads S19, disassembles, assembles, debugs RAM
```

Current boot shape:

```text
reset -> STR8 -> HIMON -> user work
```

STR8 is useful even if the payload is not HIMON. The same proven `$C000-$EFFF`
update gate has booted HIMON, OSI BASIC, and fig-FORTH as live images.

## Current Status

Updated 2026-05-21.

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
populated. `make docs-html` regenerates `DOC/HTML`; Markdown remains canonical.

## Repository Map

```text
SRC/TEST/apps/himon/   HIMON monitor payload source
SRC/TEST/apps/str8/    STR8 recovery/update source
SRC/STASH              parked or promoted source lane
SRC/SESH               session/experiment lane
SRC/tools              host-side build and support scripts
DOC/GUIDES             hand-written guides
DOC/GENERATED          source-derived reports
DOC/HTML               generated static presentation view
LOCAL                  ignored local source homes, when present
```

## Hash Direction

R-YORS still contains FNV-1a work. Current HIMON command/routine notes may
still mention FNV-1a records or `[HASH:XXXXXXXX]` IDs. Treat that as
implementation history and transition debt.

The intended compact runtime/catalog hash is tableless CRC16:

```text
canonical text -> tableless CRC16 -> typed record/payload
```

STR8 V0 does not use FNV or CRC16 for recovery decisions.

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
