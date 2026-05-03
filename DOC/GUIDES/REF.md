# R-YORS Reference

This reference is scoped to the current `ror` workspace.

## Source Lanes

```text
SRC/STASH   stable or promoted code lane
SRC/TEST    active build/test lane, including HIMON work
SRC/SESH    session/WIP lane
SRC/BUILD   build output
SRC/tools   host-side build/support scripts
```

Current ASM file count:

```text
SRC/STASH: 1
SRC/TEST:  35
SRC/SESH:  1
```

## Monitor Lineage

```text
himon-parent.asm parent/reference monitor shell
himonia.asm      compact supervisory monitor
fnv1a-hbstr.asm  FNV-1a/HBSTR proving app
himon.asm        current FNV-driven HIMON app
```

Primary path:

```text
SRC/TEST/apps/himon/
```

## Current Design Names

```text
R-YORS       whole project/system
STR8         Subroutine To Return boot/recovery/update layer
HIMON        current FNV-driven monitor app
Himonia-F    historical name for the codebase now promoted to HIMON
HASHED_ASM   onboard assembler design using hash symbols and fixups
```

Boot relationship:

```text
R-YORS boots through STR8.
STR8 keeps recovery/update safe.
STR8 hands normal operation to HIMON.
HIMON provides the monitor, command dispatch, assembler, catalog lookup,
and debug tools.
```

## Flash And Bank Policy

```text
bank 3:
  live reset/boot image

bank 2:
  most recent backup image

bank 1:
  previous backup image

bank 0:
  platinum R-YORS/HIMON/STR8 image and oldest backup slot for now
```

STR8 V0 restores ordinary bank 3 bytes from a whole 32K ROM bank image in bank
0, 1, or 2. It skips the selected STR8 protected window unless explicit STR8
install/update is requested. Backup rotates bank 1 to bank 0, bank 2 to bank 1,
and bank 3 to bank 2.

HIMON controls IRQ/vector behavior in V0. Future STR8-N/STRAIGHTEN may offer
recovery-safe vector hooks, but the current direction is opt-in integration
rather than STR8 ownership of user interrupt policy.

STR8 top-sector policy:

```text
$F000-$FFFF  physical 4K top erase sector in bank 3
$FC00-$FFFF  1K protected STR8 window, if STR8 fits
$FA00-$FFFF  1.5K protected STR8 window
$F800-$FFFF  2K protected STR8 window
$F600-$FFFF  2.5K protected STR8 window
$F400-$FFFF  3K protected STR8 window
$F200-$FFFF  3.5K protected STR8 window
$F000-$FFFF  4K protected STR8 window, only if needed
$FFF0-$FFF8  one-time flash board/version/config bytes, inside the window
$FFF9-$FFFF  vector tail; W65C02 hardware vectors are $FFFA-$FFFF
```

Protected-window bytes are flashed separately, still by staging and preserving the
full top sector. Lower bytes in the same sector may be used, but partial
top-sector changes require read/stage/erase/full-sector-write/verify.

## Hash Policy

```text
routine header HASH   32-bit FNV-1a over canonical routine text
runtime/catalog hash  32-bit FNV-1a lookup used by Himonia-F/HIMON
symbol hash           32-bit FNV-1a assembler/catalog lookup key
name text             optional proof/listing/collision data
```

Hash is a lookup key, not identity by itself. When identity matters, compare the
stored canonical name text after the hash narrows the candidate set.

FNV-1a is the only runtime/catalog symbol hash. Catalog records do not need a
per-record algorithm tag.

STR8 V0 does not use FNV for verification, image selection, command dispatch,
catalog lookup, or recovery decisions. Future STR8-N/STRAIGHTEN may participate
in catalog/FNV paths without requiring ownership of a user system's catalog.

Compact signature policy:

```text
'F'  full FNV-1a records: entries store hash0..3
'N'  narrow FNV-1a records: entries store folded hash16
'V'  very narrow records: entries store folded hash8
```

All layouts still use FNV-1a. Replacing a 3-byte `FNV` text signature with an
`F`/`N`/`V` layout marker or table header saves record bytes without adding a
second hash algorithm.

## Record Byte Order

```text
word      low byte, then high byte
long      byte0..3, least significant to most significant
hash0..3  FNV-1a low byte through high byte
```

Example:

```text
.word $1234      -> $34,$12
.long $89ABCDEF  -> $EF,$CD,$AB,$89
```

## Tiny ASM Command Surface

```text
A [addr] [label:] MMM [operand] .
                            assemble one statement
DEF name addr kind         define a symbol manually
SYM [name]                 list symbol(s)
FIX                        list unresolved fixups
RESOLVE                    attempt to apply all pending fixups
FORGET name                remove or mark a symbol dead
EXPORT name                mark symbol visible for command/routine lookup
```

`A [addr]` without a complete one-shot statement enters the interactive side of
the assembler.

## Useful Make Targets

```text
make -C SRC help
make -C SRC help Q=flash
make -C SRC himonia
make -C SRC himon
make -C SRC basic-himon-rom-bin
make -C SRC basic-forth-himon-rom-bin
make -C SRC fnv1a-hbstr
make -C SRC test-mon
make -C SRC test-flash
make -C SRC rom-append-calc
make -C SRC routine-hash-comments
```

`make -C SRC docs` currently targets source-generated docs in `DOC/GENERATED`.
The guide set under `DOC/GUIDES` is hand-maintained design/reference material
unless a future generator is added.
