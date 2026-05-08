![R-YORS logo](DOC/branding/logo-r-yors.svg)

# R-YORS

```text
ROLL YA OWN RUNTIME SYSTEM              W65C02
NOTES / SOURCE / ROMS / MANUALS         READ ME FIRST
```

Not eRRORS, but expect fewer.

Pronounced **are-yors**.

## System Card

R-YORS is a retro-computing documentation and source project for specifying,
building, and documenting a small WDC W65C02SXB/W65C02EDU runtime environment.

Current spine:

```text
R-YORS -> STR8 -> HIMON -> THE -> onboard ASM/catalog linking
```

- `STR8` is the recovery/update guard.
- `HIMON` is the monitor/debug/catalog environment.
- `THE` is The Hash Environment: FNV-1a hash-first lookup, catalog records,
  resolver policy, and typed display. It is not the whole runtime.
- `ASM` is the planned onboard assembler path.

This repo is meant to feel like a machine binder: source, generated listings,
design notes, decisions, maps, and scratchpad material all live together.

## Current Hardware Status

A rudimentary STR8 flash-recovery path has been lightly tested on hardware and
is functioning nominally. Treat it as an early recovery tool, not a finished
field-updater: keep a programmer recovery path and known-good image nearby.
So far, STR8 is doing what it is intended to do; testing continues.

## Project Posture

R-YORS does not claim that every idea here is new to computing history. Many
ideas are known patterns being rediscovered, renamed, tested, and made personal
through this board, this vocabulary, and this build.

This project is AI-assisted. I am better at reading 6502 code than writing it,
so AI is used as a working companion for assembly, documentation, design
review, and turning rough intent into testable source.

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

## FNV-1a Hash Spine

R-YORS uses **32-bit FNV-1a** as the common lookup key for the runtime system:
commands, routines, symbols, catalog records, data elements, constants, fixups,
modules, strings, and future assembler names all follow the same hash-first
path.

```text
canonical text -> FNV-1a -> hash0,hash1,hash2,hash3 -> typed record/payload
```

- Hash constants: offset basis `$811C9DC5`, prime `$01000193`.
- Persistent storage is little-endian: displayed `$89ABCDEF` is stored as
  `EF,CD,AB,89`.
- Folded 8-bit and 16-bit FNV-1a helper results will be available for compact
  tables; 32-bit FNV-1a remains the canonical hash.
- Current HIMON command records use:
  `'F','N',('V'|$80),hash0,hash1,hash2,hash3,kind,inline-code...`
  where `kind=$00` enters code at record offset `+8`.
- Routine comments carry stable IDs like `[HASH:49023C1B]`, generated from the
  canonical uppercase routine name.
- Future catalog records keep the same `hash0..3` field for commands,
  routines, data, symbols, packets, modules, aliases, and unresolved fixups.

The hash narrows the search; the surrounding typed record gives the match its
meaning, and stored/proof text can disambiguate collisions when records become
writable or user-created. Start with [DOC/GUIDES/HASH.md](DOC/GUIDES/HASH.md)
and [DOC/GUIDES/HASH_MAP.md](DOC/GUIDES/HASH_MAP.md) for the full schema.
Terminology such as FNV-1a, hash32/hash16/hash8, signature, control byte,
kind, Record, RREC, contract, bank, sector, and condense is defined in
[DOC/GUIDES/GLOSSARY.md](DOC/GUIDES/GLOSSARY.md).

## Safety

Some code here can write or erase flash memory. Running loaders, tests, monitor
commands, ROM images, or flash utilities can overwrite firmware, programs,
user data, or board configuration.

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
- [DOC/GUIDES/RTFM-himon.md](DOC/GUIDES/RTFM-himon.md) - HIMON operations.

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

```text
make release-local
```

Adds ignored/private local composites when `LOCAL/` is populated.

## Lineage

R-YORS grows from the BSO2/WDC monitor line into a smaller, more disciplined
set of reusable routines, flash-safe recovery, hash-dispatched monitor
commands, and eventually onboard assembly/catalog linking.

The long north star is still true RPG II, but shaped from below: stable callable
routines, discoverable catalogs, flash-resident programs, fixed entry points,
simple text encodings, and a runtime that can explain itself.

## Notice

R-YORS is independent and is not affiliated with or endorsed by The Western
Design Center, Inc. Product names are used only to identify compatible hardware.
