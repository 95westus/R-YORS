# R-YORS Bringup

This is the practical bringup rail for moving from the current HIMON image to
R-YORS booting through STR8.

Rule zero: prove one dangerous thing at a time. No erase/write step should be
added until the read-only version of the same path has passed.

## Current Target

```text
STR8 V0
first proof image:  RAM-resident S19 launched under HIMON
later ROM target:   $F800-$FFFF
role:               image-oriented recovery guard
copy buffer:        8K RAM buffer, four windows per 32K bank
I/O layer:          BIO_*
catalog/FNV:        not used by STR8 V0
HIMON vectors:      HIMON controls IRQ/vector behavior in V0
```

STR8 starts as a RAM-launched test app. It should grow into reset-owned
recovery only after bank select, clear check, erase, 8K-buffered copy, verify,
backup, restore, and top-sector staging have all been proven.

## Escape Path

Before any live bank 3 rewrite, the external recovery path is:

```text
T48 programmer image restore
```

Required before real STR8 flash writes:

```text
known-good ROM image archived
current HIMON image documented
T48 programmer ready to rewrite the flash/ROM
```

A future WDCMON bridge may become another path, but the first STR8 bringup
assumes the T48 is the trusted recovery tool.

## Bringup Order

```text
0. Build RAM-resident STR8 S19 launched under HIMON.
1. Prove BIO read/write only.
2. Prove bank select only.
3. Prove read-only bank/window blank checks.
4. Prove destructive backup copy stages: erase/copy bank 2 -> bank 1, then bank 3 -> bank 2.
5. Prove read-only backup and restore plans.
6. Prove explicit selected-bank marker/fill writes on banks 0-2.
7. Prove bank clear checks.
8. Prove bank 1-2 erase/write/verify on scratch images.
9. Prove bank 0 factory snapshot capture: 3->0 only while bank 0 is clear.
10. Prove 8K buffer read/write/verify across windows $8-$F.
11. Prove full automatic backup rotation: 2->1, 3->2.
12. Prove restore of ordinary bank 3 bytes, skipping STR8 window.
13. Prove top-sector read/stage/erase/full-sector-write/verify.
14. Prove explicit STR8 install/update path.
15. Prove destructive bank 0 erase/reuse only with external recovery ready.
16. Only then let reset enter STR8 first.
```

## V0 Bank Policy

```text
bank 3  live reset/boot image
bank 2  most recent backup image
bank 1  previous backup image
bank 0  WDCMONv2/factory snapshot slot
```

Automatic backup request:

```text
copy bank 2 -> bank 1
copy bank 3 -> bank 2
verify copied bytes by read-back
```

The earlier automatic `1 -> 0` copy is deprecated. Bank 0 is written only by
explicit factory-snapshot request after a clear check.

Restore request:

```text
use selected whole 32K image from bank 0, 1, or 2 as source
write ordinary bank 3 image bytes
skip selected STR8 protected window
verify restored bytes by read-back
```

Restoring bank 0 may uninstall R-YORS from the live boot bank and return the
board to the captured WDCMONv2/factory image. If bank 0 is erased or reused,
onboard WDCMONv2 factory recovery is no longer available.

Erasing or reusing bank 0 is not ordinary backup behavior. Treat it as a
separate destructive factory-slot action that requires another saved factory
image or an external programmer for recovery.

## Protected Window

The physical top erase sector is always:

```text
$F000-$FFFF
```

The selected STR8 protected window should use the highest fitting start:

```text
$FC00-$FFFF  1K
$FA00-$FFFF  1.5K
$F800-$FFFF  2K first target
$F600-$FFFF  2.5K
$F400-$FFFF  3K
$F200-$FFFF  3.5K
$F000-$FFFF  4K only if needed
```

For the first bringup, assume:

```text
STR8 protected window = $F800-$FFFF
$FFF0-$FFF9           = one-time board/version/config bytes
$FFFA-$FFFF           = W65C02 hardware vector block
```

Ordinary restore skips `$F800-$FFFF`. Explicit STR8 install/update owns that
window. The `$FFF0-$FFF9` bytes can be patched only while flash programming can
still clear needed bits; changing cleared bits back to `1` waits for a top-sector
erase/rewrite.

## Top-Sector Rule

Any change inside `$F000-$FFFF` uses the full-sector transaction:

```text
read full $F000-$FFFF sector into RAM
update staged bytes only
erase $F000-$FFFF
write full staged sector back
verify full staged sector by read-back
```

This rule applies even when only bytes below `$F800` are changing, because flash
erase granularity is still 4K.

## Image Marker

STR8 V0 should not use FNV for image selection or verification. The first image
marker should be boring and directly readable:

```text
magic:       RYORS or STR8 image text
bank role:   live/latest/previous/factory-wdcmon
layout:      selected STR8 window start
version:     small build/version byte or word
status:      valid/incomplete/recovery marker
```

Do not make the marker a catalog. It is only a V0 recovery sanity check.

## Failure Cases To Prove

```text
wrong bank selected
source image marker missing
verify mismatch after copy
backup rotation interrupted after first copy
explicit bank 0 factory snapshot requested when bank 0 is not clear
bank 0 erase/reuse requested without external recovery path
restore interrupted before bank 3 is valid
top-sector erase succeeds but rewrite fails
protected-window write requested without explicit STR8 install/update
```

Each failure should leave a short serial message and return to `STR8>` whenever
that is still possible.

## First Code Milestones

```text
STR8_INIT
STR8_PRINT_SCREEN
STR8_CMD_LOOP
STR8_CMD_BACKUP        RAM proof: real erase bank 1 and copy bank 2 -> bank 1
STR8_CMD_COPY_B3_TO_B2 RAM proof: real erase bank 2 and copy bank 3 -> bank 2
STR8_CMD_BACKUP_0      explicit factory snapshot 3->0 after clear-check
STR8_CMD_RESTORE_0     simulated first, real later
STR8_CMD_RESTORE_1     simulated first, real later
STR8_CMD_RESTORE_2     simulated first, real later
STR8_CMD_VERIFY        read-only first
STR8_CMD_WINDOW_CHECK   read-only selected-bank 4K window blank check
STR8_CMD_MARK_BANKS    explicit RAM-only selected-bank sector-head/full-sector marker
FLSH_BANK_SELECT_A     first real hardware hinge
FLSH_WINDOW_ERASED_AX  first reusable bank/window read query
FLSH_BANK_CLEAR_CHECK_A
FLSH_BANK_ERASE_A
FLSH_COPY_BANK_AX
FLSH_VERIFY_BANK_AX
STR8_TOP_SECTOR_STAGE
STR8_INSTALL_SELF
```

## Current Stub And Next Image

```text
source:  SRC/TEST/apps/str8/str8.asm
build:   make -C SRC str8
output:  SRC/BUILD/s19/str8-f800.s19
         SRC/BUILD/s19/str8-ram-3000.s19
```

The current `$F800` stub is allowed to print plans only. It must not erase or
write flash. The RAM proof image is linked at `$3000`, is launched under HIMON,
and reserves `$4000-$5FFF` as copy-buffer RAM. The current copy worker stages
one 4K window at a time through `$4000-$4FFF`.

RAM proof command `B` is the first real destructive backup stage. It prompts
`COPY B2->B1 ERASE B1. TYPE Y:`, then stages each 4K window from bank 2 through
RAM `$4000-$4FFF`, blindly erases the matching bank 1 window, writes bank 1, and
verifies bank 1 against the staged image. It prints one `.` per verified 4K
window. It never selects, erases, or writes bank 3.

RAM proof command `L` is the live-image backup stage. It prompts
`COPY B3->B2 ERASE B2. TYPE Y:`, then stages each 4K window from bank 3 through
RAM `$4000-$4FFF`, blindly erases the matching bank 2 window, writes bank 2, and
verifies bank 2 against the staged image. Bank 3 is source-only: selected for
reads, never erased or programmed.

RAM proof command `S` selects a bank. Bank 3 is the pull-up/default boot ROM
bank, mapped from physical flash `$18000-$1FFFF`; STR8 must not offer destructive
erase/fill/write actions for it. RAM proof command `C` is read-only: it checks
whether a selected-bank 4K window is blank `$FF`, then returns hardware and STR8
state to bank 3. Windows are numbered:

```text
0=$8000-$8FFF  1=$9000-$9FFF  2=$A000-$AFFF  3=$B000-$BFFF
4=$C000-$CFFF  5=$D000-$DFFF  6=$E000-$EFFF  7=$F000-$FFFF
```

The reusable routine behind that command is `FLSH_WINDOW_ERASED_AX`:

```text
IN:  A = bank 0-3, X = window 0-7
OUT: C = 1 if the whole 4K window is $FF, C = 0 otherwise
SIDE EFFECT: bank 3 selected before return
```

This query is safe in the RAM proof because STR8 executes from `$3000`. A
future ROM-resident caller must stage the worker in RAM or another bank-stable
execution region before selecting away from the bank that contains the code.

RAM proof command `M` is explicit and destructive. It operates only on currently
selected bank 0-2 and refuses bank 3. It first asks for mode:

```text
1 = write one byte at each sector head
4 = write all 4K bytes in each sector
```

After `TYPE Y`, it writes the selected bank number as the marker/fill byte.
Mode `1` writes only the first byte of each 4K sector:

```text
$8000 $9000 $A000 $B000 $C000 $D000 $E000 $F000
```

Mode `4` writes every byte from `$8000-$FFFF` in the selected bank and prints
one `.` after each 4K sector completes. `M` does not erase. It depends on
normal flash `1 -> 0` programming rules and fails if a byte cannot be programmed
to the selected bank value. STR8 selects bank 3 again before reporting success,
abort, or failure, so another `S` command is required before another `M`.
