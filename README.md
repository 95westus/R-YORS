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

STR8-N is the reset, recovery, and installation component of R-YORS, but its
boundary is deliberately payload-agnostic: it does not depend on HIMON,
ASM-F2, OIL, or AP, and can supervise compatible non-R-YORS guest systems.

## System

```text
physical RESET -> Bank 3 STR8-N 1.21 -- timeout --> Bank 3 HIMON 1303
                       |                              |
                       |                              +--> ASM-F2 -> SEAL/AP
                       |                                           |
                       |                                   OIL <---+
                       |                                    |
                       |                                running body
                       |
                       +-- J0/J1/J2 --> enrolled guest RESET vector
                       +-- J3 -------> Bank 3 RESET vector
                       +-- I / L ----> flash install / RAM recovery tool
```

| Part | Role |
| --- | --- |
| **STR8-N** | Bank-3 reset supervisor, recovery, journaled range installation, protected-top maintenance, and `J0`-`J3` handoff |
| **HIMON** | Monitor, loader, debugger, catalog/RJOIN services, and command host |
| **ASM-F2** | Flash-resident onboard W65C02 assembler and AP object producer |
| **OIL** | **Overlay Integration Layer**: AP storage, load, relocation, resident imports, and execution |
| **AP** | Packaged application body, metadata, relocations, exports, and imports |

ASM creates AP objects. OIL integrates them and runs their bodies. HIMON
orchestrates the path, STR8 supplies bank-safe flash/link services, and RJOIN
resolves resident imports. Physical reset selects Bank 3. If the STR8 takeover
key is not pressed, its countdown stays in Bank 3 and enters the Bank-3
default payload, currently HIMON.

## Current Capability Snapshot

- STR8-N `1.21` installs dense S19 ranges transactionally, runs recovery tools
  from RAM, maintains bank-directory journals, updates its protected top
  sector through a verified backup, and launches enrolled Banks 0-3.
- HIMON/ASM-F2 `00.0814(1303)` provides RAM loading, memory/debug commands,
  resident FNV/RJOIN lookup, AP v2 validation/linking, and onboard assembly.
- ASM source supports hexadecimal, decimal, character, and `%` binary/mask
  literals; local/global symbols; expressions; initialized data; and AP v2
  entry, export, import, and relocation metadata.
- The post-`END` `SEAL>` workflow uses HIMON-style bare hexadecimal addresses
  for `RELOCATE`, `PACKAGE`, `INSTALL`, and `LOAD`. Standalone and combined
  ROM S19s are generated from the same final HIMON/ASM bytes.

The current `1.21`/`1303` installation, physical-reset persistence, fixed ROM
head, Bank Maintenance smoke, and synthetic `J3` return are board-accepted.
Compact `DC 'text'` syntax and AIM self-identifying image metadata remain
explicit future goals, not current features.

## Current Board

The accepted split-V1 board line through 2026-08-14 is hardware-proven for:

- Bank-3 reset, the visible three-second countdown, and timeout into the
  Bank-3 HIMON default;
- visible `J0`-`J3` commands, directory-gated handoff, and synthetic RESET-
  vector return through Bank 3;
- uppercase single echo for reset-time and resident interactive input, with
  Backspace and empty Enter taking the cancel path;
- non-destructive RAM-resident bank selection, target reset-vector validation,
  and handoff into Banks 0-2;
- physical-reset recovery to Bank 3 after every accepted `Jn` handoff;
- unchanged pre/post-handoff bank inventories, with accepted full-image CRCs
  `$4B59/$2A3D/$04EF/$4663` for Banks 0-3;
- boot, backup rotation, restore, and guarded payload updates;
- RAM inspection, S19 loading, one-shot breakpoints, and single-step debugging;
- onboard W65C02 assembly, `%` binary literals, expression/data directives,
  local symbols, `SEAL`, `RELOCATE`, `PACKAGE`, `LOAD`, `INSTALL`, and `AP`;
- internal AP relocation and resident RJOIN import resolution;
- AP objects loaded from RAM, visible flash, and banked flash;
- missing-import rejection, overlap protection, and banked-input validation;
- the external ASM session reporter AP, kept in Bank 0 and run with
  `AP B0 hhhh 4800` from its selected store address;
- interactive bank/sector flash erase with explicit confirmation and recovery;
- standalone examples including the 16x16 column Life program.

The banked-AP bullets also apply to the split V1 line. Current HIMON stages
`AP Bn` input with a RAM-resident `$F010/$0203` select/copy/restore routine;
its host matrix, invalid-package stage/restore rail, and valid Bank-0 package
execution are hardware-accepted. The historical V1.02 combined-image proofs
remain in this repository. Current STR8-N v1.21 is built and released from the
adjacent standalone STR8-N repository; R-YORS imports its checked public ABI
and builds only the `$8000-$EFFF` ASM/HIMON payload.

The current Bank Jump Record publishes `$7DFD-$7DFF = 42 4A nn` after a validated
handoff, preserves a valid record through HIMON cold clear, and uses
`42 4A FF` when no validated target is known. Its full `J0`-`J3` preservation
matrix is host- and hardware-accepted. See the
[Bank Jump Record board test](DOC/GUIDES/STR8/STR8_BANK_JUMP_RECORD_BOARD_TEST.md).

The current bank contents are:

| Bank | Installed system | STR8 role |
| --- | --- | --- |
| 0 | R-YORS without ASM | `J0` target |
| 1 | A different R-YORS build without ASM | `J1` target |
| 2 | R-YORS with ASM | `J2` target |
| 3 | R-YORS with ASM and the newest STR8-N | Reset/default supervisor |

Banks 0-2 are opaque 32K systems. They may later contain OSI BASIC,
fig-FORTH, WOZMON, data, or another unrelated system; `Jn` names a bank, not a
system type. After handoff, the selected guest owns `$8000-$FFFF`, its vectors,
peripherals, and execution. Bank-3 STR8 is unmapped and cannot enforce a
timeout or recover control until physical reset.

**Important:** V1 validates only that the selected reset vector is plausible.
Bank identity and whole-image CRC authentication require future Bank-3-owned
metadata. Every unrelated guest system still needs its own warm-handoff,
peripheral, vector, and CRC qualification before it is treated as supported.
The qualification record has four independent gates:

| Gate | Required proof |
| --- | --- |
| **H** | Warm handoff and recovery |
| **P** | Peripherals and surviving machine state |
| **V** | RESET, NMI, and IRQ/BRK vectors |
| **C** | Exact image identity and non-destructive proof |

See the
[STR8 Guest Image Qualification Guide](DOC/GUIDES/STR8/STR8_GUEST_IMAGE_QUALIFICATION.md).

This is the threshold worth noticing: after the initial image is installed,
the board can create, inspect, store, integrate, and run native code using its
own monitor and assembler. It remains a bench system, but it is doing real work
on its own.

Treat it as bench-proven rather than a finished field updater. Keep an external
programmer and a known-good image nearby.

The current line retains the 2026-07-18 size-pass proof: its fixed-width `D`
path, positive RAM AP/RJOIN import path, missing-import atomicity, and
banked-source RJOIN path are hardware-proven. It retires the STR8 `M` map and
the richer resident HIMON `D`/quoted-hash forms, and keeps AP import linking in
HIMON. Standalone STR8-N v1.21 publishes `$F006` as its resident ABI query;
R-YORS verifies that service and its capabilities through the external public
contract.

## Start Here

- [Operator's Guide](DOC/GUIDES/OPERATORS_GUIDE.md) - STR8, HIMON, and board workflows
- [ASM User Guide](DOC/GUIDES/ASM/ASM_USER_GUIDE.md) - source entry, assembly, and AP commands
- [Address Practices](DOC/GUIDES/ASM/ADDRESS_PRACTICES.md) - safe address choices for ASM and AP work
- [OIL .710 Test Plan](DOC/GUIDES/PLANNING/OIL_710_TEST_PLAN.md) - Overlay Integration Layer board gates
- [STR8 J0-J2 Opaque-Bank Plan](DOC/GUIDES/PLANNING/STR8_J012_OPAQUE_BANK_PLAN.md) - accepted implementation, size, recovery, and proof record
- [STR8 J0-J2 Board Test](DOC/GUIDES/STR8/STR8_J012_BOARD_TEST.md) - exact inventory, handoff, reset, and CRC acceptance rail
- [STR8 Bank Jump Record Board Test](DOC/GUIDES/STR8/STR8_BANK_JUMP_RECORD_BOARD_TEST.md) - accepted full `J0`-`J3` persistence matrix
- [STR8 V1.02 Compact Refresh Board Test](DOC/GUIDES/STR8/STR8_V1_02_COMPACT_REFRESH_BOARD_TEST.md) - final exact-image refresh rail for the `$0E5F` resident
- [STR8 V1.02 Presentation Board Test](DOC/GUIDES/STR8/STR8_V1_02_PRESENTATION_BOARD_TEST.md) - `$0E5D` successor evidence and final no-flash WAIT-discard gate
- [STR8-N V1.02 Release Record](DOC/GUIDES/STR8/STR8_V1_02_RELEASE.md) - frozen identities, host matrix, board closure, and deferred scope
- [STR8 V1 Migration Board Test](DOC/GUIDES/STR8/STR8_V1_MIGRATION_BOARD_TEST.md) - accepted flashable V1 migration and first journaled Bank-2 install proof
- [STR8 Guest Image Qualification](DOC/GUIDES/STR8/STR8_GUEST_IMAGE_QUALIFICATION.md) - mandatory handoff, peripheral, vector, and CRC procedure for unrelated systems
- [STR8 S19 And Bank Volumes](DOC/GUIDES/PLANNING/STR8_MULTIBOOT_BANK_VOLUMES.md) - loader/volume direction and superseded compatible-bank design history
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

The primary R-YORS output is a dense 28K `$8000-$EFFF` payload:

```text
SRC/BUILD/s19/ryors-v1.2-asm-himon-bank3-8-e.s19

$8000-$BAF5  ASM-F2, entry $800C
$BAF6-$BFFF  low-flash growth/AP-store hole ($050A bytes)
$C000-$EDB3  current HIMON image
$EDB4-$EFFF  HIMON growth hole ($024C bytes)
```

The build first verifies the adjacent STR8-N manifest, locked top-sector hash,
and public ABI artifact. R-YORS does not assemble or copy STR8-N source.

To compose a complete 32K Bank-0/1/2 payload, run the standalone owner:

```text
make -C ../STR8-N ryors-full-bank

../STR8-N/BUILD/v1.21/s19/ryors-v1.2-asm-himon-str8n-bank0-2-8-f.s19
```

STR8-N supplies `$F000-$FFFF`, validates the 28K R-YORS input, and verifies
the final RESET vector. Bank-3 sector F remains protected and is installed
with the standalone programmer BIN or guarded STR8-N updater.

Useful targets:

```text
make all                       verify STR8-N and build R-YORS 28K payload
make life                      standalone loadable Life S19/BIN
make -C SRC help Q=<term>      find related targets
make release                   clean locked integration plus release artifacts
make docs-html                 HTML rebuild for docs and repository READMEs
```

`make life` does not change the onboard image. It preserves the simple
standalone S19 workflow for programs that should be loaded independently.

## Repository

```text
SRC/ASM/        current ASM-F2 source
SRC/HIMON/      current HIMON source
SRC/INTEGRATION/ locked external STR8-N contract
SRC/LIB/        shared board and ROM support
SRC/APPS/       current standalone applications
SRC/PROOFS/     current proof scaffolds still used by onboard work
SRC/TESTS/      current test harnesses
SRC/ARCHIVE/    retired sample, test, proof, demo, and one-off code/data
SRC/tools/      host bootstrap and build tools
DOC/GUIDES/     hand-written guides and hardware logs
DOC/GENERATED/  source-derived reports
```

Active source lanes hold only code or data used to create current R-YORS
payloads or data intentionally ingested by the board. STR8-N has its own
adjacent repository; HIMON and ASM-F2 remain here. Retired material belongs in
`SRC/ARCHIVE/` under the
[historical code migration plan](DOC/GUIDES/PLANNING/HISTORICAL_CODE_MIGRATION_PLAN.md).

New code and data should be processed onboard where practical through HIMON,
ASM-F2, AP packages, OIL, and STR8 install/update services. Host tools remain
where they bootstrap or regenerate current onboard artifacts.

## Safety

Flash operations can overwrite firmware, programs, data, and board
configuration. Destructive STR8 and flash-utility paths require confirmation.
Do not press NMI during erase, program, or restore operations.

`J0`-`J3` do not write flash, but they deliberately transfer through the
selected bank's RESET vector. Use physical reset as the universal return path,
and qualify each unrelated guest before relying on its startup or interrupt
behavior.

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
