# R-YORS Bringup

This is the practical bringup rail for moving from the current HIMON image to
R-YORS booting through STR8.

Rule zero: prove one dangerous thing at a time. No erase/write step should be
added until the read-only version of the same path has passed.

Current bench status: STR8 is reset-entered and hardware-proven as a small
boot-image manager. The current proof set rotates three bootable `$C000-$EFFF`
payloads: HIMON, OSI BASIC, and fig-FORTH. Keep the programmer and a
known-good image available as last-resort brick recovery while STR8's broader
field-update and self-update paths are still being proved.

## Bootstrap Boundary

At this stage the external programmer is the first-install tool. Use it to burn
the initial combined STR8/HIMON image onto a blank or fully erased part. After
that image boots, routine work should stay onboard:

```text
STR8 U / UPDATE HIMON   replaces the $C000-$EFFF payload gate
HIMON L F               writes fixed-address low-flash tools such as ASM
```

So the normal lifecycle is one programmer-assisted install, then STR8/HIMON
self-maintenance. The programmer remains the recovery path if STR8 itself is
unbootable or if the protected `$F000-$FFFF` recovery sector must be replaced.

## Current Target

```text
STR8 V0
current ROM proof:  $F000-$FFFF
future shrink goal: highest fitting protected window
role:               image-oriented recovery guard
copy buffer:        4K RAM buffer, one erase sector at a time
I/O layer:          private STR8_CON_* FTDI/VIA path
catalog/hash path:   not used by STR8 V0 recovery decisions
HIMON vectors:      HIMON controls IRQ/vector behavior in V0
```

STR8 started as a RAM-launched test app. The current ROM proof is reset-entered
and resident at `$F000`, with guarded `B`, `E`, `U`, `0`, `1`, and `2`
paths. New destructive behavior should still begin as a read-only or RAM-safe
proof before it becomes part of the reset-owned recovery path.

## Escape Path

If the board is bricked badly enough that STR8 cannot run, the external recovery
path is:

```text
T48 programmer image restore
```

Required before real STR8 flash writes and for the initial R-YORS install, even
though it is not the normal update path after STR8/HIMON boots:

```text
known-good ROM image archived
current HIMON image documented
T48 programmer ready to rewrite the flash/ROM
```

A future WDCMON bridge may become another path, but the first STR8 bringup
keeps the T48 as the final escape hatch.

## Bringup Order And Remaining Rail

The early bringup order below is mostly historical now. Bank 0 enrollment,
backup rotation, the fixed `$C000-$EFFF` `U` gate, HIMON U1->U2 update, OSI
BASIC and fig-FORTH payload update, and high-flash recovery back to HIMON have
all passed on hardware. STR8 self-update and broader field-update policy remain
future work.

```text
0. Build RAM-resident STR8 S19 launched under HIMON.
1. Prove BIO read/write only.
2. Prove bank select only.
3. Prove 4K buffer read/write/verify across windows $8-$F.
4. Prove automatic backup rotation: 2->1, 3->2.
5. Prove bank 0 enrollment flag: `E` clears one in-flash bit after confirmation.
6. Prove enrolled backup rotation: 1->0, 2->1, 3->2.
7. Prove restore of ordinary bank 3 bytes while preserving the STR8 window.
8. Prove top-sector read/stage/erase/full-sector-write/verify.
9. Prove explicit STR8 install/update path.
10. Let reset enter STR8 first.
```

## V0 Bank Policy

```text
bank 3  live reset/boot image
bank 2  most recent backup image
bank 1  previous backup image
bank 0  optional WDCMONv2/base hold, unless enrolled into rotation
```

Automatic backup request before bank 0 enrollment:

```text
copy bank 2 -> bank 1
copy bank 3 -> bank 2
verify copied bytes by read-back
```

After `E` enrolls bank 0:

```text
copy bank 1 -> bank 0
copy bank 2 -> bank 1
copy bank 3 -> bank 2
verify copied bytes by read-back
```

Saving the board's original WDCMONv2/base flash image is still desired, but it
belongs to the future bridge/install path. It is not part of today's STR8 RAM
proof.

Restore request:

```text
use selected whole 32K image from bank 0, 1, or 2 as source
write ordinary bank 3 image bytes
skip selected STR8 protected window
verify restored bytes by read-back
```

Restoring bank 0 restores whatever bank 0 currently holds. Before enrollment it
may be a saved WDCMONv2/base image. After enrollment it is the oldest rotating
backup.

## Protected Window

The physical top erase sector is always:

```text
$F000-$FFFF
```

The selected STR8 protected window should use the highest fitting start:

```text
$FC00-$FFFF  1K
$FA00-$FFFF  1.5K
$F800-$FFFF  2K
$F600-$FFFF  2.5K
$F400-$FFFF  3K
$F200-$FFFF  3.5K
$F000-$FFFF  4K only if needed
```

For the current ROM proof, assume:

```text
STR8 protected window = $F000-$FFFF
$FFF0-$FFF9           = one-time board/version/config bytes
$FFFA-$FFFF           = W65C02 hardware vector block
```

Ordinary restore preserves `$C000-$FFFF` unless the operator explicitly confirms
high flash. Explicit STR8 install/update owns the selected protected window. The
`$FFF0-$FFF9` bytes can be patched only while flash programming can still clear
needed bits; changing cleared bits back to `1` waits for a top-sector
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

This rule applies even when only bytes below `$FC00` are changing, because flash
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
bank 0 enrollment requested without confirmation
bank 0 enrollment flag write fails or verifies wrong
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
STR8_CMD_BACKUP        RAM proof: real backup cascade with verify
STR8_CMD_ENROLL_B0     RAM proof: clear one-way bank 0 rotation flag
STR8_CMD_RESTORE_0     RAM proof: restore bank 0 -> bank 3, preserve STR8 bytes
STR8_CMD_RESTORE_1     RAM proof: restore bank 1 -> bank 3, preserve STR8 bytes
STR8_CMD_RESTORE_2     RAM proof: restore bank 2 -> bank 3, preserve STR8 bytes
FLSH_BANK_SELECT_A     first real hardware hinge
FLSH_BANK_CLEAR_CHECK_A
FLSH_BANK_ERASE_A
FLSH_COPY_BANK_AX
FLSH_VERIFY_BANK_AX
STR8_TOP_SECTOR_STAGE
STR8_INSTALL_SELF
```

## Current STR8 Images

```text
source:  SRC/STR8/str8.asm
build:   make -C SRC str8
output:  SRC/BUILD/s19/str8-f000.s19
         SRC/BUILD/s19/str8-ram-3000.s19
         SRC/BUILD/s19/str8-worker-0200.s19
```

The current ROM proof links the resident shell at `$F000`. The worker image
links for `$0200`, is stored in the combined ROM at `$FD26-$FFEF`, and is
copied into the `$0200-$09FF` STR8 RAM tray before destructive flash work. The
RAM proof image is linked at `$3000`, is launched under HIMON, and reserves
`$4000-$4FFF` as copy-buffer RAM. The current copy worker stages one 4K erase
sector at a time through that buffer. The ROM `U` updater uses `$4000-$6FFF`
to stage HIMON C/D/E sectors before erase/write.

RAM proof command `B` is the destructive backup cascade. Before Bank 0
enrollment it copies `2->1` and `3->2`. After `E` enrollment it copies `1->0`,
`2->1`, and `3->2`. Each copy stages one 4K sector through `$4000-$4FFF`,
erases the destination sector, writes it, and verifies by read-back compare.

RAM proof command `E` clears bit 0 of `$FFF0` after confirmation. Erased/set
means `B0 HOLD`; cleared means `B0 ROT`.

RAM proof commands `0`, `1`, and `2` restore the selected source bank to live
bank 3. The normal restore path preserves `$C000-$FFFF` from bank 3 unless the
operator explicitly confirms high flash, then verifies the destination against
the staged image.
