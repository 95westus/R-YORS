# STR8 Development Decision Reference

STR8 means **Subroutine To Return**. It is pronounced **S-T-R-8**, may be read
as **Straight 8**, and deliberately echoes `RTS` / Return from Subroutine.

STR8 is the reset-time recovery root for R-YORS. It must stay small, compact, and
W65C02S-only.

Current STR8 identity marker:

```text
private phrase -> FNV-1a32 -> #5F6A0F7A
```

The marker is displayed in the STR8 ID line. It is an identity tag, not the V0
bank-restore verifier. The source phrase is deliberately not recorded in public
source or documentation.

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
HIMON layers should provide wear awareness through explicit hash-shaped
metadata records, not by silently stealing bytes from ordinary image sectors or
from the STR8 top-sector slack.

Exact counts to 100,000 erase cycles need 17 bits. If the system records only
each 128th erase event, the persistent bucket count needs 10 bits. Those small
counts should still be written append-only as `WMAP` or similar wear-map
records, verified and sealed before they are used.

The purpose is to know when a sector or chip is approaching its practical write
life before it becomes a recovery problem.

Scratch flash is a future managed lease, not a filesystem and not an only-copy
home. A future TMP/STAGE sector may be chosen from the lowest-wear reclaimable
sector, but reclaim still erases a full 4K sector and must preserve, copy, or
discard the rest of that sector by explicit transaction policy.

Longer term, R-YORS should have a way to export flash contents to a host as an
S19-like serial stream, or move flash contents between two connected boards,
without depending on an external programmer for ordinary maintenance.

## Protected Region

Bank 3 `$F000-$FFFF` is the physical top 4K erase sector. The protected STR8
window is smaller when the code fits. The current command proof uses
`$FA00-$FFFF`, leaving room for the resident shell plus RAM-worker handoff:

```text
$FC00-$FFFF  1K protected STR8 window
$FA00-$FFFF  1.5K protected STR8 window
$F800-$FFFF  2K protected STR8 window
$F600-$FFFF  2.5K protected STR8 window
$F400-$FFFF  3K protected STR8 window
$F200-$FFFF  3.5K protected STR8 window
$F000-$FFFF  4K protected STR8 window, only if needed

$FFF0-$FFF9  one-time flash board/version/config bytes, inside the window
$FFFA-$FFFF  W65C02 hardware vector block
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
a STR8 install/update. The `$FFF0-$FFF9` pocket is reserved for board id,
version, and config bytes that may be patched by clearing bits until the top
sector is erased/rebuilt.

## Bank Roles

```text
bank 3 = live executable system ROM / reset boot image
bank 2 = most recent backup image
bank 1 = previous backup image
bank 0 = optional WDCMONv2/base hold, unless enrolled into rotation
```

Banks 0-2 are storage banks for now. STR8 reads, copies, verifies, and writes
them, but does not execute from them.

Bank 0 may eventually hold the board's original live WDCMONv2/base image, but
saving that image is a TODO for the future WDCMONv2-to-R-YORS bridge and is not
part of today's STR8 RAM proof. Until the operator runs `E`, bank 0 is held out
of automatic backup rotation. After `E` confirms the destructive policy change
and clears the in-flash enrollment bit, bank 0 joins the rotation permanently
until erase/reflash or a deliberate STR8 config rebuild. The current proof uses
bit 0 of `$FFF0`: erased/set means `B0 HOLD`, cleared means `B0 ROT`.

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

`B` backs up the active bank 3 image while preserving earlier backups. Before
Bank 0 enrollment:

```text
copy bank 2 -> bank 1
copy bank 3 -> bank 2
verify copied bytes by read-back/byte compare
```

After Bank 0 enrollment:

```text
copy bank 1 -> bank 0
copy bank 2 -> bank 1
copy bank 3 -> bank 2
verify copied bytes by read-back/byte compare
```

This keeps bank 2 as the most recent recovery image, bank 1 as the previous
recovery image, and enrolled bank 0 as the oldest automatic recovery image.

Base-image preservation remains separate future bridge work:

```text
TODO bridge/install path = offer to save original WDCMONv2/base image
```

Restoring bank 0 means restoring whatever bank 0 currently holds. Before
enrollment it may be a WDCMONv2/base image and may remove R-YORS from the live
boot bank. After enrollment it is just the oldest rotating backup.

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
STR8 V0 #5F6A0F7A
? = print tiny STR8 ID/state
B = backup automatic image rotation, with verify
E = enroll bank 0 into rotation, destructive, confirmed
0 = restore bank 0 -> bank 3, with verify
1 = restore bank 1 -> bank 3, with verify
2 = restore bank 2 -> bank 3, with verify
G = go HIMON
R = reset
```

`GO addr`, `L F`, standalone verify, and rich loading are later features.

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

This opt-in stub family is the start of `IVI`: Interrupt Vector Indirection,
pronounced `IVY`. If STR8 is installed as the board's boot/recovery product,
IVI lets hardware vectors stay stable while payloads patch indirect targets. In
V0, HIMON installs and patches the active vector targets. Future payloads can
use the same mechanism without inheriting HIMON's interrupt meanings.

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

The current combined ROM stores the worker source at bank 3 `$F800-$FA92`.
Before `B`, `E`, `M`, `0`, `1`, or `2`, resident STR8 at `$F000` copies that
worker into the `$0200-$09FF` STR8 RAM tray and then calls `$0200`. The worker
uses `$0A00-$0A0C` as its state board, uses `$4000-$4FFF` as the 4K sector
buffer, and restores bank 3 before returning.

The current RAM worker copies full 32K banks with a 4K buffer:

```text
copy window $8
copy window $9
copy window $A
copy window $B
copy window $C
copy window $D
copy window $E
copy window $F
```

Each chunk reads the source bank into RAM, selects the destination bank, erases
the destination windows if needed, writes the buffer, and verifies by read-back
comparison.

Restore into bank 3 preserves `$C000-$FFFF` unless the operator explicitly
confirms high flash. That means a normal restored bank image does not replace
HIMON, STR8, the worker source, or the vector pocket unless a future explicit
STR8 install/update path is selected.

## Sector Update Policy

The answer to "how do we update payload targets or STR8 when the guard is in
place?" is: keep the guard, and make update an explicit RAM operation.

V0 target replacement should be sector-shaped and erase/rebuild oriented. Do
not present monitor/app or STR8 replacement as a byte-level flash write:

```text
read selected 4K destination sector into RAM
receive S19 update bytes, if S19 is the transport
merge incoming bytes into the staged 4K sector image
compare staged sector against live flash
if identical: do not erase
if different: confirm, erase the selected sector
write the full staged sector
verify by complete read-back compare
return to bank 3 before reporting status
```

The direct 1->0 programming shortcut is a later optimization for ordinary data
or append-only records, not a V0 monitor replacement rule. Tiny one-way config
flags may still use 1->0 programming when deliberate.

S19 is a transport, not the flash operation unit. STR8 should stage a complete
4K sector image in RAM before erasing or programming the destination sector.

HIMON body updates are the default proof target for the V0 sector rebuild
primitive, but the primitive itself should be target/range-shaped. A different
monitor or app can use the same flow if its destination range is legal. These
ordinary target updates leave the top recovery sector intact, so a bad payload
update should still reset into STR8.

Top-sector updates are not ordinary. The top sector contains:

```text
$F000-$F9FF   top-sector bytes below current STR8
$FA00-$FFEF   current STR8 code/data protected window
$FFF0-$FFF9   config/version/flag pocket
$FFFA-$FFFF   vectors
```

For a HIMON-adjacent update in the top sector, STR8 must preserve
`$FA00-$FFFF`. For an explicit STR8 update, the staged sector may replace
`$FA00-$FFEF`, but `$FFF0-$FFF9` and vectors still need deliberate policy:
preserve, rebuild, or explicitly change. No implicit overwrite.

STR8 self-update should end in reset, not a casual return into possibly changed
code. The RAM worker can erase, write, verify, restore bank 3, and then jump
through reset or return to a tiny RAM reset stub. The important rule is that
ROM code from the erased/replaced sector is not executed mid-transaction.

Pack current STR8 routines and data back-to-back. Do not reserve accidental ABI
holes in `$FE03-$FFEF` for speculative counters or future structures. Keep
`$FFF0-$FFF9` as the deliberate fixed pocket; put repeated-write metadata such
as counters in a different flash sector if it becomes real.

## Verification

FNV is not used by STR8 V0 for recovery verification. The displayed
`#5F6A0F7A` marker is only STR8's identity tag.

First STR8 verifies restored ordinary image bytes with range checks, flash
status, and read-back comparison. Protected-window install/update gets its own
read-back verification. Future STR8-N/STRAIGHTEN may participate in catalog/FNV
paths after the image-recovery path is stable, without requiring ownership of a
user system's catalog or resolver.

## Deferred

```text
full S19 L F support
GO addr
advanced sector maintenance mode
HIMON hashed command dispatch after handoff
future STR8-N catalog/FNV participation
future STR8-N vector integration hooks
metadata layout
bank 0 WDCMONv2/base-image preservation bridge
wear leveling or erase counters
flash export/migration over serial or board-to-board link
special full-image export/import and self-update safety policy
special STR8 self-update/install path
WDCMONv2 transition documentation/tool
```

Advanced sector maintenance means a confirmed mode that can select source and
destination banks/sectors, erase a selected destination sector, copy one sector
to another, and verify by read-back compare. It is useful for rescue and lab
work, but it is not part of the small V0 `? B E M 0 1 2 G R` command surface
and must not alter Bank 0 rotation policy except through the normal `E`
enrollment command.

## Core Rule

Bank 3 boots. Bank 2 is latest backup. Bank 1 is previous backup. Bank 0 is
held unless the one-way enrollment flag makes it the oldest rotating backup.

STR8 restores bank 3 from whole 32K ROM bank images, skipping the selected STR8
protected window unless an explicit STR8 install/update is requested. Then HIMON
takes over.
