# R-YORS Bringup

This is the practical bringup rail for moving from the current HIMON image to
R-YORS booting through STR8.

Rule zero: prove one dangerous thing at a time. No erase/write step should be
added until the read-only version of the same path has passed.

## Current Target

```text
STR8 V0
link target:        $F800-$FFFF
role:               image-oriented recovery guard
I/O layer:          BIO_*
catalog/FNV:        not used by STR8 V0
HIMON vectors:      HIMON controls IRQ/vector behavior in V0
```

STR8 starts as a simulation/test app. It should grow into reset-owned recovery
only after bank select, verify, backup, restore, and top-sector staging have all
been proven.

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
0. Build STR8 simulation stub at $F800.
1. Prove BIO read/write only.
2. Prove bank select only.
3. Prove read-only bank identity checks.
4. Prove read-only backup and restore plans.
5. Prove bank 0-2 erase/write/verify on scratch images.
6. Prove real backup rotation: 1->0, 2->1, 3->2.
7. Prove restore of ordinary bank 3 bytes, skipping STR8 window.
8. Prove top-sector read/stage/erase/full-sector-write/verify.
9. Prove explicit STR8 install/update path.
10. Only then let reset enter STR8 first.
```

## V0 Bank Policy

```text
bank 3  live reset/boot image
bank 2  most recent backup image
bank 1  previous backup image
bank 0  platinum image at first, oldest backup slot during current rotation
```

Backup request:

```text
copy bank 1 -> bank 0
copy bank 2 -> bank 1
copy bank 3 -> bank 2
verify copied bytes by read-back
```

Restore request:

```text
use selected whole 32K image from bank 0, 1, or 2 as source
write ordinary bank 3 image bytes
skip selected STR8 protected window
verify restored bytes by read-back
```

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
$FFF0-$FFF8           = one-time board/version/config bytes
$FFF9-$FFFF           = vector tail
```

Ordinary restore skips `$F800-$FFFF`. Explicit STR8 install/update owns that
window.

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
bank role:   live/latest/previous/platinum
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
STR8_CMD_BACKUP        simulated first, real later
STR8_CMD_RESTORE_0     simulated first, real later
STR8_CMD_RESTORE_1     simulated first, real later
STR8_CMD_RESTORE_2     simulated first, real later
STR8_CMD_VERIFY        read-only first
STR8_BANK_SELECT_A     first real hardware hinge
STR8_VERIFY_BANK_IMAGE
STR8_COPY_BANK_ORDINARY_BYTES
STR8_TOP_SECTOR_STAGE
STR8_INSTALL_SELF
```

## Current Stub

```text
source:  SRC/TEST/apps/str8/str8.asm
build:   make -C SRC str8
output:  SRC/BUILD/s19/str8-f800.s19
```

The current stub is allowed to print plans only. It must not erase or write
flash.
