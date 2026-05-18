![R-YORS logo](DOC/branding/logo-r-yors.svg)

# R-YORS

```text
ROLL YA OWN RUNTIME SYSTEM              W65C02
NOTES / SOURCE / ROMS / MANUALS         READ ME FIRST
```

Not eRRORS, but expect fewer.

Pronounced **are-yors**.

## ### #HASH# FLASH ###

Newest alerts appear first.

```text
########################################################################
##                          #HASH# FLASH                              ##
##        REHASH / FLASHBACK / COMMAND-SURFACE ALERT                  ##
########################################################################
2026
         05
                18
                   15:10Z WLP2 STR8 crossed the three-image milestone:
                               HIMON, OSI BASIC, and fig-FORTH have all
                               booted through the fixed C000-EFFF update gate
                               and can be managed as recoverable flash images.
                   02:35Z WLP2 STR8 U / UPDATE HIMON is hardware-proven
                               for the fixed C000-EFFF gate: U1 backed up
                               to Bank 2, Bank 3 updated to U2, then
                               high-flash restore brought U1 back.
                13
                   21:30Z WLP2 HIMON RAM-only debug N/B/X behavior is
                               hardware-tested. Debug patching still does
                               not target ROM/flash.
                12
                   02:33Z WLP2 Command rules changed: destructive
                               commands now need 4+ characters, HIMON
                               range/search syntax is being revised, and
                               STR8 keeps R as reset.
```

Details live in [DOC/GUIDES/HASH_FLASH.md](DOC/GUIDES/HASH_FLASH.md).
Doc/edict movement lives in [DOC/GUIDES/DOC_FLASH.md](DOC/GUIDES/DOC_FLASH.md).

## ### DOC FLASH ###

Use DOC FLASH when a doc, edict, QCC home, or artifact name changes enough
that yesterday's notes could mislead you. Latest doc alerts live in
[DOC/GUIDES/DOC_FLASH.md](DOC/GUIDES/DOC_FLASH.md).

## System Card

R-YORS exists to make a WDC W65C02SXB/W65C02EDU single-board computer feel like
a standalone, recoverable machine: power on, recover safely, inspect memory and
routines, load vetted S19 images, rotate flash backups, and grow the system in
flash without needing a full host toolchain every time.

Current spine:

```text
R-YORS -> STR8 -> HIMON -> THE -> onboard ASM/catalog linking
```

- `STR8` is the recovery/update guard.
- `HIMON` is the monitor/debug/catalog environment.
- `THE` is The Hash Environment: lookup/catalog records, resolver policy, and
  typed display. It is not the whole runtime. Current HIMON pieces still carry
  FNV-1a history, but the intended compact runtime hash is tableless CRC16.
- `ASM` is the planned onboard assembler path.

This repo is meant to feel like a machine binder: source, generated listings,
design notes, decisions, maps, and scratchpad material all live together.

## Current Hardware Status

STR8 is currently hardware-proven rotating three bootable images: HIMON for
recovery/inspection, OSI BASIC for interactive programming, and fig-FORTH for a
threaded language environment. It also has proof for map, backup, fixed-gate
`U` / `UPDATE HIMON` from U1 to U2, high-flash Bank 2 recovery back to U1, and
Bank 0 enrollment/rotation. Treat it as a bench-proven recovery/update guard,
not a finished field-updater: keep a programmer recovery path and known-good
image nearby.

HIMON's RAM-only debug path has a current hardware proof for `B`, `B C`,
`B L`, `N`, and `X`: one-shot breakpoints restore their original opcodes,
compact debugger stops print as `@hhhh`, and invalid debug patch targets
report `DBG RAM`. See [DOC/GUIDES/HIMON_DEBUG_TESTING.md](DOC/GUIDES/HIMON_DEBUG_TESTING.md).

## Project Posture

R-YORS does not claim that every idea here is new to computing history. Many
ideas are known patterns being rediscovered, renamed, tested, and made personal
through this board, this vocabulary, and this build.

This project is AI-assisted. I am better at reading 6502 code than writing it,
so AI is used as a working companion for assembly, documentation, design
review, and turning rough intent into testable source.

For documentation work, keep one canonical home for each idea. Use
[DOC/GUIDES/GLOSSARY.md](DOC/GUIDES/GLOSSARY.md) for terminology and
[DOC/GUIDES/DECISIONS.md](DOC/GUIDES/DECISIONS.md) for documentation-shape
edicts before spreading wording into indexes, maps, or generated views.

## Carry Convention

R-YORS generally treats the 6502 carry flag as an affirmative status bit:

```text
C=1  yes / ready / valid / success
C=0  no / not ready / invalid / failure
```

The convention is deliberately plain: `1` means on, lit, present, or completed;
`0` means off, dark, absent, or not completed. Individual routines may document
a different carry contract when compatibility or a lower-level device path
requires it, but the preferred R-YORS style is `C=1` for success.

## Hash Status

R-YORS still contains FNV-1a work, and current HIMON command/routine notes may
still mention FNV-1a records or `[HASH:XXXXXXXX]` IDs. Treat that as
implementation history and transition debt, not the final lookup decision.

The intended compact runtime/catalog hash is now **tableless CRC16**. The reason
is practical 65C02 time and space: CRC16 can be computed without a table and
without dragging the 32-bit FNV-1a path into every small command/catalog scan.

```text
canonical text -> tableless CRC16 -> typed record/payload
```

The hash narrows the search; the surrounding typed record gives the match its
meaning, and stored/proof text can disambiguate collisions when records become
writable or user-created. The older FNV-1a schema lives in
[DOC/GUIDES/HASH.md](DOC/GUIDES/HASH.md) and
[DOC/GUIDES/HASH_MAP.md](DOC/GUIDES/HASH_MAP.md) until the CRC16 record shape is
fully written through. Terminology lives in
[DOC/GUIDES/GLOSSARY.md](DOC/GUIDES/GLOSSARY.md).

## Safety

Some code here can write or erase flash memory. Running loaders, tests, monitor
commands, ROM images, or flash utilities can overwrite firmware, programs,
user data, or board configuration.

Command-safety mandate:

```text
DESTRUCTIVE COMMANDS MUST BE 4+ CHARACTERS.
```

Current short destructive/proof commands are transition debt. New destructive
commands must use full words and confirmation where appropriate.

Use this project only with a recovery path: known-good ROM image, external
programmer, or another way back. No warranty is provided.

## Manual Set

Start here:

- [DOC/INDEX.md](DOC/INDEX.md) - documentation front desk.
- [DOC/GUIDES/TOC.md](DOC/GUIDES/TOC.md) - recommended reading order.
- [DOC/GUIDES/DECISIONS.md](DOC/GUIDES/DECISIONS.md) - settled calls.
- [DOC/GUIDES/REF.md](DOC/GUIDES/REF.md) - quick reference.
- [DOC/GUIDES/GLOSSARY.md](DOC/GUIDES/GLOSSARY.md) - terminology contract.
- [DOC/GUIDES/RTFM-R-YORS.md](DOC/GUIDES/RTFM-R-YORS.md) - operator highlights.
- [DOC/GUIDES/RTFM-str8.md](DOC/GUIDES/RTFM-str8.md) - STR8 operations.
- [DOC/GUIDES/STR8_WORK_PROCESS.md](DOC/GUIDES/STR8_WORK_PROCESS.md) - STR8 work/process rail.
- [DOC/GUIDES/RTFM-himon.md](DOC/GUIDES/RTFM-himon.md) - HIMON operations.
- [DOC/GUIDES/HIMON_DEBUG_TESTING.md](DOC/GUIDES/HIMON_DEBUG_TESTING.md) - RAM debug bench process.

Core binders:

- [DOC/GUIDES/STR8.md](DOC/GUIDES/STR8.md)
- [DOC/GUIDES/HIMON_STAGES_CLASSES.md](DOC/GUIDES/HIMON_STAGES_CLASSES.md)
- [DOC/GUIDES/HASH_MAP.md](DOC/GUIDES/HASH_MAP.md)
- [DOC/GUIDES/HASHED_ASM.md](DOC/GUIDES/HASHED_ASM.md)
- [DOC/GUIDES/CATALOG.md](DOC/GUIDES/CATALOG.md)
- [DOC/GUIDES/MEMORY_MAP.md](DOC/GUIDES/MEMORY_MAP.md)

Generated reports: [DOC/GENERATED](DOC/GENERATED)
Scratchpad: [DOC/IDEAS.md](DOC/IDEAS.md)

## Deck Map

```text
HIMON/      current monitor source alias
STR8/       current recovery/update source alias
ROM/        current ROM support source alias
SRC/STASH   parked or earlier source lines
SRC/SESH    session/experiment lane
SRC/tools   doc, ROM, and build helpers
DOC/        manuals, maps, design notes, generated reports
LOCAL/      ignored local source homes, when present
```

The aliases above are the documentation roles; physical source paths are tracked
in [DOC/GUIDES/GLOSSARY.md](DOC/GUIDES/GLOSSARY.md) and generated docs.

## Build

```text
make release
```

Regenerates source-derived docs, builds the tracked release set, and stamps the
HIMON ROM binary.

Generated burnable ROM `.bin` files are exactly one 32K `$8000-$FFFF` bank
image for the programmer workflow. The file does not encode a bank number;
bank 0-3 placement is managed through the T48 programmer or through
R-YORS/STR8. The combined `himon-str8-rom.bin` image currently carries HIMON at
CPU `$C000`, STR8 at CPU `$F000`, and the reset vector at file offset `$7FFC`.
The build check verifies that vector and reset-target code before release.
Local language images are linked under the live monitor/boot region: OSI MS
BASIC at `$8000` and fig-Forth at `$A000`. They remain blank-write/proof
artifacts rather than full `L F` update packages.

For STR8 bench work, `make -C SRC fig-forth-str8-update-s19` builds
`SRC/BUILD/s19/fig-forth-str8-update.s19`: a bootable fig-Forth payload for the
fixed `$C000-$EFFF` `U` gate. It replaces HIMON in Bank 3 until Bank 2 is
restored back over it.

`make -C SRC msbasic-osi-str8-update-s19` does the same for OSI MS BASIC as a
temporary `$C000` payload using STR8's resident console.

Forth as a language/concept is not treated here as a copyright problem. The
specific fig-Forth source is different: R-YORS uses a local FIG-Forth 6502
Release 1.1 source that identifies itself as a public-domain publication from
the Forth Interest Group and requires that its notice be included in further
distribution. The generator preserves that notice in the generated local
source.

```text
make release-local
```

Adds ignored/private local composites when `LOCAL/` is populated.

```text
make docs-html
```

Generates `DOC/HTML` static pages from the current Markdown docs snapshot.
HTML is a presentation view; Markdown remains the canonical documentation.

## Lineage

R-YORS grows from the BSO2/WDC monitor line into a smaller, more disciplined
set of reusable routines, flash-safe recovery, compact-hash monitor/catalog
lookup, and eventually onboard assembly/catalog linking.

The long north star is still true RPG II, but shaped from below: stable callable
routines, discoverable catalogs, flash-resident programs, fixed entry points,
simple text encodings, and a runtime that can explain itself.

## Notice

R-YORS is independent and is not affiliated with or endorsed by The Western
Design Center, Inc. Product names are used only to identify compatible hardware.
