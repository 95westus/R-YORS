# R-YORS Reference

This reference is scoped to the current `ror` workspace.

Terms in this reference follow [GLOSSARY.md](./GLOSSARY.md). In particular,
THE means The Hash Environment, `contract` is the preferred call-interface word,
and `bank`, `sector`, `signature`, `control byte`, `kind`, `Record`, `RREC`,
`buried`, `gone`, and `condense` keep their glossary meanings.

## Source Lanes

```text
SRC/STASH   stable or promoted code lane
HIMON       current monitor source alias
STR8        current recovery/update source alias
ROM         current ROM support source alias
SRC/SESH    session/WIP lane
SRC/BUILD   build output
SRC/tools   host-side build/support scripts
```

Current ASM file count:

```text
SRC/STASH: 1
ROM/HIMON/STR8: 25
SRC/SESH:  1
```

## Monitor Lineage

```text
himon-parent.asm parent/reference monitor shell
himonia.asm      historical compact supervisory monitor
himon.asm        current FNV-driven HIMON app
```

Primary path:

```text
HIMON/
```

The source-generated routine docs are narrower than the whole source tree. They
track current HIMON/STR8 operational source and ROM support code; legacy demos,
harnesses, games, ACIA/PIA, and historical monitor variants are kept out of
those generated maps.

## Current Design Names

```text
R-YORS       whole project/system
STR8         Subroutine To Return boot/recovery/update layer
HIMON        current FNV-driven monitor app
THE          The Hash Environment: hash/catalog lookup and resolver policy
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
  WDCMONv2/factory snapshot slot
```

STR8 V0 restores ordinary bank 3 bytes from a whole 32K ROM bank image in bank
0, 1, or 2. It skips the selected STR8 protected window unless explicit STR8
install/update is requested. Automatic backup rotates bank 2 to bank 1 and bank
3 to bank 2. The earlier automatic `1 -> 0` copy is deprecated; bank 0 is
written only by explicit factory-snapshot request after clear-check. Copying
bank 0 to bank 3 is the normal factory restore path. Erasing or reusing bank 0
is a separate destructive factory-slot action; if it happens, onboard WDCMONv2
factory recovery is no longer available without another saved factory image or
an external programmer.

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
$FFF0-$FFF9  one-time flash board/version/config bytes, inside the window
$FFFA-$FFFF  W65C02 hardware vector block
```

Protected-window bytes are flashed separately, still by staging and preserving the
full top sector. Lower bytes in the same sector may be used, but partial
top-sector changes require read/stage/erase/full-sector-write/verify.
The `$FFF0-$FFF9` pocket is one-time patch space between top-sector erases:
flash programming can clear bits from `1` to `0`, but cannot set them back to
`1` until the sector is erased.

## Hash Policy

```text
routine header HASH   32-bit FNV-1a over canonical routine text
runtime/catalog hash  32-bit FNV-1a lookup used by HIMON
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

Current HIMON FNV command record:

```text
+0  'F'        $46
+1  'N'        $4E
+2  'V'|$80    $D6
+3  hash0      FNV-1a low byte
+4  hash1
+5  hash2
+6  hash3      FNV-1a high byte
+7  kind       current $00 means executable code follows
+8  code       inline executable entry for kind=$00
```

Current HIMON records do not store `entry_lo,entry_hi`; the entry is `record+8`
when `kind=$00`. Explicit pointer records with `entry_lo,entry_hi` are a future
catalog/RREC direction, not the current inline-code command record.

Stored hash width direction:

```text
ww=00  no hash / local id / direct record
ww=01  folded hash8
ww=10  folded hash16
ww=11  full hash32, stored hash0..3
```

All widths still use FNV-1a as the canonical hash. Do not spend literal `FNV`
bytes to mark hash width in compact RCAT/RREC records; put width in control
bits when the record/table format already implies FNV-1a.

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
FORGET name                remove or mark a symbol unavailable
EXPORT name                mark symbol visible for command/routine lookup
```

`A [addr]` without a complete one-shot statement enters the interactive side of
the assembler.

## Useful Make Targets

```text
make -C SRC help
make -C SRC help Q=flash
make -C SRC himon
make -C SRC str8
make -C SRC basic-himon-rom-bin
make -C SRC basic-forth-himon-rom-bin
make -C SRC docs
make -C SRC routine-hash-comments
```

`make -C SRC docs` currently targets source-generated docs in `DOC/GENERATED`.
The guide set under `DOC/GUIDES` is hand-maintained design/reference material
unless a future generator is added.

## BIN Flash Image Policy

Generated burnable ROM `.bin` files are full 128K flash images. The current
bootable HIMON bank is bank 3, so CPU `$8000-$FFFF` in bank 3 lives at file
offset `$18000-$1FFFF`.

HIMON `START` is currently CPU `$D000`, which is file offset `$1D000` in the
full image. Hardware vectors at CPU `$FFFA-$FFFF` live at the tail of the file,
`$1FFFA-$1FFFF`.

The beginning of a valid full flash image may be erased `$FF` because bank 0 can
be blank. Do not add a fake first-byte prefix just to make offset 0 non-blank.
The build check verifies the reset vector and confirms that the reset target in
bank 3 contains real code.
