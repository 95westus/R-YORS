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
- `THE` is The Hash Engine: FNV-1a hash-first lookup for names and records.
- `ASM` is the planned onboard assembler path.

This repo is meant to feel like a machine binder: source, generated listings,
design notes, decisions, maps, and scratchpad material all live together.

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
- Current Himonia-F command records use:
  `'F','N',('V'|$80),hash0,hash1,hash2,hash3,kind,entry...`
- Routine comments carry stable IDs like `[HASH:49023C1B]`, generated from the
  canonical uppercase routine name.
- Future catalog records keep the same `hash0..3` field for commands,
  routines, data, symbols, packets, modules, aliases, and unresolved fixups.

The hash narrows the search; the surrounding typed record gives the match its
meaning, and stored/proof text can disambiguate collisions when records become
writable or user-created. Start with [DOC/GUIDES/HASH.md](DOC/GUIDES/HASH.md)
and [DOC/GUIDES/HASH_MAP.md](DOC/GUIDES/HASH_MAP.md) for the full schema.

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
SRC/TEST    current bring-up, monitor, apps, device tests
SRC/STASH   parked or earlier source lines
SRC/SESH    session/experiment lane
SRC/tools   doc, ROM, and build helpers
DOC/        manuals, maps, design notes, generated reports
LOCAL/      ignored local source homes, when present
```

## Build

```text
make release
```

Regenerates source-derived docs, builds the tracked release set, and stamps the
HIMON ROM binary.

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
