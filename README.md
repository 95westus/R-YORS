![R-YORS logo](DOC/branding/logo-r-yors.svg)

# R-YORS

```text
ROLL YA OWN RUNTIME SYSTEM              W65C02
NOTES / SOURCE / ROMS / MANUALS         READ ME FIRST
```

Not eRRORS, but expect fewer.

Pronounced **are-yors**.

## Pasteable ASM Is Alive

On 2026-06-06, the ASM v1 runtime crossed an important line: a program typed as
ASM source on the board called a ROM-resident routine by name and ran.

Original source listing:

```asm
ORG $7000
MAIN: LDX #0
LOOP LDA #$4D
JSR BIO_FTDI_WRITE_BYTE_BLOCK
INX
BNE LOOP
RTS
END
```

Board paste/run transcript:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7000
OK PC=$7000
ASM> MAIN: LDX #0
OK PC=$7002
ASM> LOOP LDA #$4D
OK PC=$7004
ASM> JSR BIO_FTDI_WRITE_BYTE_BLOCK
OK PC=$7007
ASM> INX
OK PC=$7008
ASM> BNE LOOP
OK PC=$700A
ASM> RTS
OK PC=$700B
ASM> END
OK PC=$700B
ASM RT PASTE OK
>G 7000
GO 7000
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
... 256 total M characters ...
>
```

That proves the paste driver can feed source lines into the stripped callable
ASM runtime, resolve `BIO_FTDI_WRITE_BYTE_BLOCK` through HIMON/THE's resident
hash catalog, emit a real `JSR`, and execute the generated program.

The same runtime paste driver also produced a byte-level ASMTEST proof. Source
was pasted into ASM, finalized with `END`, and the resulting RAM was dumped:

```text
ASM> ORG $7000
...
ASM> END
OK PC=$7027
ASM RT PASTE OK

>D 7000 701F
7000: A2 00 9C 10 71 BD 17 70 | 9D 00 71 4D 10 71 8D 10 | ....q..p..qM.q..
7010: 71 E8 E0 10 D0 EF 60 52 | 2D 59 4F 52 53 20 41 53 | q.....`R-YORS AS
>D 7100 711F
7100: 52 2D 59 4F 52 53 20 41 | 53 4D 20 54 45 53 54 2E | R-YORS ASM TEST.
7110: 0F 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>G 7000
GO 7000

#GO# ENTRY=7000
RET A=0F X=10 Y=30 P=77 S=FD NV-BdIZC
>
```

Full hardware transcripts are in
[HARDWARE_TEST_LOG.md](DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md), with the ASM gate
tracked in [ASM TEST_PLAN.md](DOC/GUIDES/ASM/TEST_PLAN.md).

## Current Spark

Search just made the full ladder: standalone RAM proof, joined RAM proof, and
a flash-resident FNV command that HIMON can discover and run. Along the way a
sneaky FTDI carry bug was caught and fixed, explaining the occasional extra
hex digit in dumps.

Details and transcripts live in
[HARDWARE_TEST_LOG.md](DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md) and
[HIMON_SEARCH_IMPLEMENTATION_GUIDE.md](DOC/GUIDES/HIMON/HIMON_SEARCH_IMPLEMENTATION_GUIDE.md).

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
