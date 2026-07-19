![R-YORS logo](DOC/branding/logo-r-yors.svg)

# R-YORS

```text
ROLL YA OWN RUNTIME SYSTEM              W65C02
NOTES / SOURCE / ROMS / MANUALS         READ ME FIRST
```

Not eRRORS, but expect fewer. Pronounced **are-yors**.

R-YORS is a recoverable runtime and onboard workbench for the WDC
W65C02SXB/W65C02EDU board. It boots through a flash-safe recovery guard into a
monitor, assembler, and AP object runtime.

## System

```text
RESET -> STR8-N -> HIMON -> ASM-F2 -> AP object
                    |                    |
                    +------ OIL <--------+
                             |
                         running body
```

| Part | Role |
| --- | --- |
| **STR8-N** | Reset-time recovery, backup rotation, restore, payload updates, and bank-safe flash services |
| **HIMON** | Monitor, loader, debugger, catalog/RJOIN services, and command host |
| **ASM-F2** | Flash-resident onboard W65C02 assembler and AP object producer |
| **OIL** | **Overlay Integration Layer**: AP storage, load, relocation, resident imports, and execution |
| **AP** | Packaged application body, metadata, relocations, exports, and imports |

ASM creates AP objects. OIL integrates them and runs their bodies. HIMON
orchestrates the path, STR8 supplies bank-safe flash/link services, and RJOIN
resolves resident imports.

## Current Board

The 2026-07-10 STR8-N/HIMON/ASM-F2 image is hardware-proven for:

- boot, backup rotation, restore, and guarded payload updates;
- RAM inspection, S19 loading, one-shot breakpoints, and single-step debugging;
- onboard W65C02 assembly, `SEAL`, `PACKAGE`, `LOAD`, `INSTALL`, and `AP`;
- internal AP relocation and resident RJOIN import resolution;
- AP objects loaded from RAM, visible flash, and banked flash;
- missing-import rejection, overlap protection, and banked-input validation;
- the external ASM session reporter AP, kept in Bank 0 and run with
  `AP B0 $hhhh $4800` from its selected store address;
- interactive bank/sector flash erase with explicit confirmation and recovery;
- standalone examples including the 16x16 column Life program.

This is the threshold worth noticing: after the initial image is installed,
the board can create, inspect, store, integrate, and run native code using its
own monitor and assembler. It remains a bench system, but it is doing real work
on its own.

Treat it as bench-proven rather than a finished field updater. Keep an external
programmer and a known-good image nearby.

The 2026-07-18 size-pass image has been installed on the board. Its fixed-width
`D` path, positive RAM AP/RJOIN import path, missing-import atomicity, and
banked-source RJOIN path are hardware-proven. The image retires the STR8 `M`
map and the richer resident HIMON `D`/quoted-hash forms, and moves AP import
linking from STR8 into HIMON while preserving `$F006` as a compatibility
entry.

## Start Here

- [Operator's Guide](DOC/GUIDES/OPERATORS_GUIDE.md) - STR8, HIMON, and board workflows
- [ASM User Guide](DOC/GUIDES/ASM/ASM_USER_GUIDE.md) - source entry, assembly, and AP commands
- [Address Practices](DOC/GUIDES/ASM/ADDRESS_PRACTICES.md) - safe address choices for ASM and AP work
- [OIL .710 Test Plan](DOC/GUIDES/PLANNING/OIL_710_TEST_PLAN.md) - Overlay Integration Layer board gates
- [STR8 Multiboot, S19, And Bank Volumes](DOC/GUIDES/PLANNING/STR8_MULTIBOOT_BANK_VOLUMES.md) - accepted next architecture and proof order
- [Life Quick Card](DOC/GUIDES/ASM/LIFE16_QUICK_CARD.md) - exact ASM-F2 bank-2 procedure
- [Technical Guide](DOC/GUIDES/TECHNICAL_GUIDE.md) - architecture, flash policy, and build products
- [Release Guide](DOC/GUIDES/RELEASES.md) - GitHub release assets, tag naming, and proof notes
- [Memory Map](DOC/GUIDES/MEMORY/MEMORY_MAP.md) - current ROM, RAM, and OIL address boundaries
- [Reference](DOC/GUIDES/REF.md) and [Glossary](DOC/GUIDES/GLOSSARY.md) - compact commands and vocabulary
- [Hardware Test Log](DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md) - board transcript evidence
- [Full Guide Index](DOC/GUIDES/INDEX.md) - every documentation lane

## Build

From the repository root:

```text
make all
```

The primary output is a complete 32K `$8000-$FFFF` bank image:

```text
SRC/BUILD/bin/himon-str8-rom.bin

$8000-$BC6C  ASM-F2, entry $800C
$BC6D-$BFFF  low-flash growth/AP-store hole
$C000-$EF2C  HIMON, including the resident AP import linker
$EF2D-$EFFF  HIMON/STR8 growth hole
$F000-$F8AC  STR8-N shell and service adapters
$F8AD-$FD25  top-sector growth hole
$FD26-$FFFF  worker, configuration, and vectors
```

The matching first-install stream is:

```text
SRC/BUILD/s19/himon-str8-rom-install.s19
```

Useful targets:

```text
make all                       complete current onboard image
make life                      standalone loadable Life S19/BIN
make -C SRC help Q=<term>      find related targets
make release                   image plus release-side artifacts
make docs-html                 explicit generated HTML rebuild
```

`make life` does not change the onboard image. It preserves the simple
standalone S19 workflow for programs that should be loaded independently.

## Repository

```text
SRC/ASM/        current ASM-F2 source
SRC/HIMON/      current HIMON source
SRC/STR8/       current STR8-N source
SRC/LIB/        shared board and ROM support
SRC/APPS/       current standalone applications
SRC/PROOFS/     current proof scaffolds still used by onboard work
SRC/TESTS/      current test harnesses
SRC/ARCHIVE/    retired sample, test, proof, demo, and one-off code/data
SRC/tools/      host bootstrap and build tools
DOC/GUIDES/     hand-written guides and hardware logs
DOC/GENERATED/  source-derived reports
```

Active source lanes hold only code or data used to create current onboard
R-YORS images or data intentionally ingested by the board. STR8-N, HIMON V,
and ASM-F2 retain their current structure. Retired material belongs in
`SRC/ARCHIVE/` under the
[historical code migration plan](DOC/GUIDES/PLANNING/HISTORICAL_CODE_MIGRATION_PLAN.md).

New code and data should be processed onboard where practical through HIMON,
ASM-F2, AP packages, OIL, and STR8 install/update services. Host tools remain
where they bootstrap or regenerate current onboard artifacts.

## Safety

Flash operations can overwrite firmware, programs, data, and board
configuration. Destructive STR8 and flash-utility paths require confirmation.
Do not press NMI during erase, program, or restore operations.

## Direction

R-YORS grows from the BSO2/WDC monitor line toward a machine with recoverable
flash, discoverable resident routines, onboard assembly, relocatable AP
objects, and a runtime that can explain what it knows.

The long north star remains true RPG II, built from below: stable callable
routines, catalogs, flash-resident programs, fixed entry points, simple text
encodings, and increasingly self-hosted work.

## Notice

R-YORS is independent and is not affiliated with or endorsed by The Western
Design Center, Inc. Product names identify compatible hardware only. No
warranty is provided.
