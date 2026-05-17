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

Command safety:

```text
DESTRUCTIVE COMMANDS MUST BE 4+ CHARACTERS.
```

New destructive commands use full words: `COPY`, `FILL`, `MOVE`, `FLASH`,
`BANK`, `ERASE`, `BACKUP`, `RESTORE`. Current short mutators are transition
debt.

## Flash And Bank Policy

```text
bank 3:
  live reset/boot image

bank 2:
  most recent backup image

bank 1:
  previous backup image

bank 0:
  optional WDCMONv2/base hold, unless enrolled into rotation
```

Flash-bank and flash-window vocabulary:

```text
$0000-$7FFF  same RAM/IO decode regardless of flash bank
$8000-$FFFF  selected 32K flash window

bank 0       SST39SF010A physical flash $00000-$07FFF, visible at $8000-$FFFF when selected
bank 1       SST39SF010A physical flash $08000-$0FFFF, visible at $8000-$FFFF when selected
bank 2       SST39SF010A physical flash $10000-$17FFF, visible at $8000-$FFFF when selected
bank 3       SST39SF010A physical flash $18000-$1FFFF, visible at $8000-$FFFF at reset/default boot
```

Routine naming rule:

```text
FLSH_*   selects or queries which physical flash bank is visible in $8000-$FFFF
FLASH_*  erases/programs/checks the currently selected $8000-$FFFF flash window
```

`FLASH_*` routines do not choose a bank. The caller must already have selected
the intended window, and ROM-resident callers must not select away from the bank
that contains their executing code unless the worker is running from RAM or
another bank-stable region.

STR8 V0 restores ordinary bank 3 bytes from a whole 32K ROM bank image in bank
0, 1, or 2. It skips the selected STR8 protected window unless explicit STR8
install/update is requested. Automatic backup rotates bank 2 to bank 1 and bank
3 to bank 2 until `E` enrolls bank 0. After enrollment, backup rotates bank 1
to bank 0, bank 2 to bank 1, and bank 3 to bank 2. Saving the original
WDCMONv2/base flash image is future bridge/install work, not today's STR8 RAM
proof. Restoring bank 0 restores whatever bank 0 currently holds.

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
make -C SRC himon-str8-rom-bin
make -C SRC str8-ram
make -C SRC basic-himon-rom-bin
make -C SRC basic-forth-himon-rom-bin
make -C SRC docs
make -C SRC routine-hash-comments
```

`make -C SRC docs` currently targets source-generated docs in `DOC/GENERATED`.
The guide set under `DOC/GUIDES` is hand-maintained design/reference material
unless a future generator is added.

## BIN Flash Image Policy

Generated burnable ROM `.bin` files are exactly one 32K `$8000-$FFFF` bank
image for the programmer workflow. The file does not encode a bank number;
bank 0-3 placement is managed through the T48 programmer or through
R-YORS/STR8.

`BUILD/bin/himon-str8-rom.bin` is the primary combined image: HIMON starts at
CPU `$C000` / file offset `$4000`, STR8 starts at CPU `$F000` / file offset
`$7000`, and RESET points to STR8 at `$F000`. Hardware vectors at CPU
`$FFFA-$FFFF` live at the tail of the file, `$7FFA-$7FFF`.

Local language images are linked below HIMON: OSI MS BASIC starts at `$8000`
and fig-Forth starts at `$A000`. They are proof/load artifacts for now, not
full safe `L F` updater packages.

Forth as a language/concept is not treated as a copied source artifact. The
local fig-Forth build is different: it is derived from FIG-Forth 6502 Release
1.1, whose source identifies itself as a public-domain publication from the
Forth Interest Group and requires the notice to remain with further
distribution. `tools/emit_fig_forth_wdc.ps1` preserves that notice in the
generated source under `LOCAL/fig-forth/generated/fig-forth.asm`.

The current standalone `himon-rom` image no longer contains the legacy HIMONIA
fixed entries at `$F00D`, `$FADE`, or `$FEED`. Loaded-language bridge builds
must patch call addresses from the current HIMON map or wait for a deliberate
future ABI.

The build check verifies the reset vector and confirms that the reset target in
the selected 32K bank image contains real code.
