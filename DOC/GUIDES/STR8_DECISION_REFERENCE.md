# STR8 Development Decision Reference

STR8 means **Subroutine To Return**. It is pronounced **S-T-R-8**, may be read
as **Straight 8**, and deliberately echoes `RTS` / Return from Subroutine.

STR8 is the reset-time recovery root for R-YORS. It must stay small, compact, and
W65C02S-only.

This document records the current design decisions for the first working STR8
test. It is a development reference, not a full implementation spec.

## Source Placement

The first STR8 implementation is a testing/userland app, not a production ROM
layout yet.

Expected source placement:

```text
SRC/TEST/apps/str8/
```

STR8 can still model reset/recovery behavior, flash bank operations, and
protected-sector policy while living in the test app lane.

## Hardware Facts

Reset maps flash bank 3 into `$8000-$FFFF`.

There is no hardware override. If bank 3's reset vector or enough STR8 code is
corrupted, recovery requires external reprogramming.

Flash erase sector size is 4K.

Flash write and erase routines always run from RAM.

STR8 may use all RAM and zero page during recovery.

## Flash Endurance

The design assumes flash sectors have a finite erase endurance, roughly 100,000
erase cycles per sector depending on the specific flash device.

STR8 should not treat flash as endlessly rewritable storage. Future STR8 or
HIMON layers should provide either built-in wear leveling, a small flash
file-system style allocator, erase counters, or some combination of those tools.

The purpose is to know when a sector or chip is approaching its practical write
life before it becomes a recovery problem.

Longer term, R-YORS should have a way to export flash contents to a host as an
S19-like serial stream, or move flash contents between two connected boards,
without depending on an external programmer for ordinary maintenance.

## Protected Region

Bank 3 `$F000-$FFFF` is the physical top 4K erase sector. The protected STR8
window is smaller when the code fits. Choose the highest start address that can
hold STR8, the one-time config bytes, and the vector tail:

```text
$FC00-$FFFF  1K protected STR8 window
$FA00-$FFFF  1.5K protected STR8 window
$F800-$FFFF  2K protected STR8 window
$F600-$FFFF  2.5K protected STR8 window
$F400-$FFFF  3K protected STR8 window
$F200-$FFFF  3.5K protected STR8 window
$F000-$FFFF  4K protected STR8 window, only if needed

$FFF0-$FFF8  one-time flash board/version/config bytes, inside the window
$FFF9-$FFFF  vector tail; W65C02 hardware vectors are $FFFA-$FFFF
```

Protected-window bytes are flashed through a separate STR8 install/update path.
That path still stages the full top sector and preserves non-target bytes,
because hardware erase granularity is 4K. Bytes below the chosen protected
start may contain layered common routines or HIMON-adjacent code. Updating those
lower bytes uses the same top-sector transaction: read `$F000-$FFFF`, update the
staged sector image, erase the sector, write the full staged sector, and verify
it.

V0 restore uses whole 32K ROM bank images as sources, but the bank 3 write path
skips the selected STR8 protected window unless the operator explicitly requests
a STR8 install/update.

## Bank Roles

```text
bank 3 = live executable system ROM / reset boot image
bank 2 = most recent backup image
bank 1 = previous backup image
bank 0 = platinum R-YORS/HIMON/STR8 image and oldest backup slot for now
```

Banks 0-2 are storage banks for now. STR8 reads, copies, verifies, and writes
them, but does not execute from them.

## First Recovery Target

```text
corrupt bank 3
reset
STR8 prompt appears with timeout
choose image 0, 1, or 2
restore ordinary bytes from selected bank image $8000-$FFFF -> bank 3
skip selected STR8 protected window unless explicit STR8 install/update is requested
verify by read-back/byte compare, not FNV
jump to HIMON
R-YORS runs
```

Stored images are whole 32K ROM images:

```text
$8000-$FFFF = complete ROM bank image
```

## First Backup Target

`B` backs up the active bank 3 image while preserving the previous backup:

```text
copy bank 1 -> bank 0
copy bank 2 -> bank 1
copy bank 3 -> bank 2
verify copied bytes by read-back/byte compare
```

This keeps bank 2 as the most recent recovery image, bank 1 as the previous
recovery image, and bank 0 as the oldest/platinum slot.

## Boot Target

Today:

```text
STR8 timeout or G -> HIMON
```

Future:

```text
STR8 -> trampoline
STR8 -> burned command text buffer
HIMON -> hashed launch/command record after handoff
STR8/HIMON -> L F style flash loader
```

## First Prompt

```text
STR8 - Subroutine To Return
B = backup image
0 = recover from platinum image
2 = recover from image 2
1 = recover from image 1
G = go HIMON / timeout default
```

`GO addr` and `L F` style loading are later features.

## Vectors

V0 HIMON controls IRQ/vector behavior.

Direction update: earlier notes allowed future STR8 ownership of the hardware
vector stubs because the vectors live in protected flash. After reconsideration,
the current direction is opt-in integration. STR8-N/STRAIGHTEN may provide
recovery-safe vector hooks, while user systems can keep their own interrupt
policy.

Reference vector integration can still use STR8 stubs:

```text
NMI   -> STR8_NMI_STUB
RESET -> STR8_RESET_STUB
IRQ   -> STR8_IRQBRK_STUB
```

The IRQ/BRK stub splits BRK from non-BRK IRQ using the stacked status `B` flag,
then dispatches through RAM vectors.

```text
RAM_NMI_VEC
RAM_IRQ_VEC
RAM_BRK_VEC
```

In V0, HIMON installs and patches the active vector targets.

## Layering

```text
STR8_ = reset, prompt, recovery decision, vector stubs
FLSH_ = flash and bank operations
BIO_  = console/board I/O behavior
PIN_  = raw hardware access hidden under BIO_ or FLSH_
```

Bank pin control used for flash bank selection should be exposed as `FLSH_`,
not as raw `PIN_` behavior.

## RAM Flash Worker

Flash write and erase routines always run from RAM.

STR8 copies the flash worker into RAM before erase, write, or bank-copy
operations. The RAM worker owns flash mutation and bank switching while the
operation is active.

## Verification

FNV is not used by STR8 V0.

First STR8 verifies restored ordinary image bytes with range checks, flash
status, and read-back comparison. Protected-window install/update gets its own
read-back verification. Future STR8-N/STRAIGHTEN may participate in catalog/FNV
paths after the image-recovery path is stable, without requiring ownership of a
user system's catalog or resolver.

## Deferred

```text
full S19 L F support
GO addr
HIMON hashed command dispatch after handoff
future STR8-N catalog/FNV participation
future STR8-N vector integration hooks
metadata layout
bank 0 platinum image maintenance
wear leveling or erase counters
flash export/migration over serial or board-to-board link
special full-image export/import and self-update safety policy
special STR8 self-update/install path
WDCMONv2 transition documentation/tool
```

## Core Rule

Bank 3 boots. Bank 0 starts as platinum/oldest. Bank 2 is latest backup. Bank 1
is previous backup.

STR8 restores bank 3 from whole 32K ROM bank images, skipping the selected STR8
protected window unless an explicit STR8 install/update is requested. Then HIMON
takes over.
