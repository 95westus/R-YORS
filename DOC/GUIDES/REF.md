# R-YORS Reference

This reference is scoped to the current `ror` workspace.

Terms in this reference follow [GLOSSARY.md](./GLOSSARY.md). In particular,
THE means The Hash Environment for lookup/catalog records, `contract` is the
preferred call-interface word, and `bank`, `sector`, `signature`,
`control byte`, `kind`, `Record`, `RREC`, `buried`, `gone`, and `condense`
keep their glossary meanings.

## Source Lanes

```text
SRC/HIMON   current monitor payload source
SRC/STR8    current recovery/update source
SRC/LIB     shared ROM support source
SRC/PROOFS  board proofs and promotion scaffolds
SRC/APPS    standalone applications
SRC/TESTS   test harnesses
SRC/BUILD   build output
SRC/tools   host-side build/support scripts
```

Current ASM file count:

```text
SRC/APPS:   2
SRC/HIMON:  4
SRC/STR8:   2
SRC/LIB:   24
SRC/PROOFS: 7
SRC/TESTS:  6
```

## Monitor Lineage

```text
himon-parent.asm parent/reference monitor shell
himonia.asm      historical compact supervisory monitor
himon.asm        current HIMON app with FNV-era command records
```

Primary path:

```text
SRC/HIMON/
```

The source-generated routine docs are narrower than the whole source tree. They
track current HIMON/STR8 operational source and ROM support code; legacy demos,
harnesses, games, ACIA/PIA, and historical monitor variants are kept out of
those generated maps.

## Current Design Names

```text
R-YORS       whole project/system
STR8         Subroutine To Return boot/recovery/update layer
HIMON        current monitor/catalog app
THE          The Hash Environment: lookup/catalog records and resolver policy
Himonia-F    historical name for the codebase now promoted to HIMON
HASHED_ASM   onboard assembler design using hashed symbols and fixups
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
routine header HASH      existing 32-bit FNV-1a routine comment ID
current HIMON hash       FNV-era command record lookup
public catalog hash      32-bit FNV-1a for names crossing boundaries
compact local hash       CRC16 or short IDs inside validated local contexts
record/body check        optional CRC32/checksum when worth the bytes
name text                optional proof/listing/collision data
```

The hash is a lookup hint, not identity by itself. When identity matters, compare
the stored canonical name text after the hash narrows the candidate set.

FNV-1a32 is the settled public routine/command/symbol identity hash. Catalog
records should not need a per-record algorithm tag unless multi-algorithm
catalogs become a deliberate future design.

STR8 V0 does not use FNV, CRC16, or CRC32 for verification, image selection,
command dispatch, catalog lookup, or recovery decisions. Future
STR8-N/STRAIGHTEN may participate in catalog paths without requiring ownership
of a user system's catalog.

Current HIMON FNV command record:

```text
+0  'F'        $46
+1  'N'        $4E
+2  'V'|$80    $D6
+3  hash0      FNV-1a low byte
+4  hash1
+5  hash2
+6  hash3      FNV-1a high byte
+7  kind       bit 0 executable/callable, bit 1 confirm
+8  payload    inline code or pointer payload, according to kind
```

Current K values:

```text
K=$00  described/known, not directly executable
K=$01  executable/callable; legacy inline entry is record+8
K=$03  executable/callable with confirmation:
       +8  entry_lo
       +9  entry_hi
       +10 extra_lo
       +11 extra_hi
```

`ENTRY` is the callable address. `EXTRA` is side information; current `#` and
confirm prompts treat nonzero `EXTRA` as an HBSTR pointer. `EXTRA` is not an
alias or parameter pointer. Future records that need `PARMS` or `RESULTS`
should use a documented call convention.

Legacy FNV stored-width direction:

```text
ww=00  no hash / local id / direct record
ww=01  folded hash8
ww=10  folded hash16
ww=11  full hash32, stored hash0..3
```

These widths describe the older folded-FNV proposal and current helper
vocabulary. Future public records should keep FNV32 at public boundaries; use
CRC16/short IDs only inside local contexts with fallback/collision handling.

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

## ASM Command Surface

```text
ASM                         enter flash-resident assembler when present
[label[:]] operation [operand]
                            source-line shape inside ASM
ORG EQU DB DS END           current v1 directives
```

HIMON's old `A` mini-assembler command has been removed. ASM owns assembly
through a full source-line session, with `ORG`/session PC state and `END`.

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
`$7000`, RESET points to STR8 at `$F000`, and NMI/IRQ point to STR8 IVI entries
at `$F089`/`$F09D`. Hardware vectors at CPU `$FFFA-$FFFF` live at the tail of
the file, `$7FFA-$7FFF`.

Current STR8 payload update images are fixed `$C000-$EFFF` S19 streams:
`msbasic-osi-str8-update.s19` and `fig-forth-str8-update.s19`. They place OSI
BASIC or fig-FORTH where HIMON normally lives so STR8 can prove backup,
rotation, and recovery with real bootable payloads. Older below-HIMON language
layout proofs may still exist as build artifacts, but the proven STR8 image
manager path is the fixed update gate.

For STR8 bench work, fig-Forth can also be generated as a temporary `$C000`
payload with `make -C SRC fig-forth-str8-update-s19`. That stream is for the
already-proven STR8 `U` gate: it replaces the normal HIMON `$C000-$EFFF` payload
in Bank 3, enters at `$C000`, and returns to STR8 with `MON` at `$F000`.

OSI MS BASIC has the same temporary-payload path:
`make -C SRC msbasic-osi-str8-update-s19`. The C000 BASIC image uses STR8's
resident console calls and disables its background Ctrl-C poll for the first
bench pass.

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
