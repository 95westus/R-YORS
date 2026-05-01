# STR8 Development Decision Reference

STR8 means **Subroutine To Reset**. It is pronounced **S-T-R-8**.

STR8 is the reset-time recovery root for ROR. It must stay small, compact, and
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

Longer term, ROR should have a way to export flash contents to a host as an
S19-like serial stream, or move flash contents between two connected boards,
without depending on an external programmer for ordinary maintenance.

## Protected Region

Bank 3 `$F000-$FFFF` is the protected STR8 boot sector.

`$FFFA-$FFFF` contains the hardware vectors.

Normal recovery must not overwrite bank 3 `$F000-$FFFF`.

## Bank Roles

```text
bank 3 = only live executable system ROM / reset boot image
bank 2 = most recent recovery image
bank 1 = previous recovery image
bank 0 = reserved bulk/archive/staging space, not used by first recovery test
```

Banks 0-2 are storage banks for now. STR8 reads, copies, verifies, and writes
them, but does not execute from them.

## First Recovery Target

```text
corrupt bank 3 payload only
reset
STR8 prompt appears with timeout
choose image 2
copy bank 2 $8000-$EFFF -> bank 3 $8000-$EFFF
verify with FNV
jump to HIMON
ROR runs
```

Banks 1 and 2 have reserved 4K top holes:

```text
$8000-$EFFF = payload image
$F000-$FFFF = reserved / ignored by first STR8
```

## First Backup Target

`B` backs up the active bank 3 payload while preserving the previous backup:

```text
copy bank 2 $8000-$EFFF -> bank 1 $8000-$EFFF
copy bank 3 $8000-$EFFF -> bank 2 $8000-$EFFF
verify copied payloads
```

This keeps bank 2 as the most recent recovery image and bank 1 as the previous
recovery image.

## Boot Target

Today:

```text
STR8 timeout or G -> HIMON
```

Future:

```text
STR8 -> trampoline
STR8 -> burned command text buffer
STR8 -> hashed launch/command record
STR8/HIMON -> L F style flash loader
```

## First Prompt

```text
STR8 - Subroutine To Reset
B = backup image
2 = recover from image 2
1 = recover from image 1
G = go HIMON / timeout default
```

`GO addr` and `L F` style loading are later features.

## Vectors

STR8 owns the hardware vector stubs because the vectors live in protected flash.

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

STR8 installs safe defaults. HIMON, BASIC, FORTH, or user code may patch
the RAM vectors later.

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

FNV is the primary verification method.

The exact FNV record format and placement are still open, but first STR8
verifies the recoverable payload range.

## Deferred

```text
full S19 L F support
GO addr
hashed command dispatch
metadata layout
bank 0 bulk/archive commands
wear leveling or erase counters
flash export/migration over serial or board-to-board link
full $8000-$FFFF image handling
special STR8 self-update/install path
WDCMONv2 transition documentation/tool
```

## Core Rule

Bank 3 boots. Banks 0-2 store.

STR8 restores bank 3, then HIMON takes over.
