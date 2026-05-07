# RTFM STR8

STR8 is the small recovery/update monitor that runs before HIMON. It owns the
dangerous flash decisions: backup rotation, restore, Bank 0 enrollment, and
protected-window preservation.

Read this before pressing a destructive key.

## Current Layout

```text
combined image:  SRC/BUILD/bin/himon-str8-rom.bin
worker source:   $C000-$C1FF, copied to RAM when needed
HIMON:           $D600-$F9DA
STR8:            $FA00-$FE02
config pocket:   $FFF0-$FFF9
vectors:         $FFFA-$FFFF
```

On reset, STR8 initializes the FTDI path, prints six progress dots during the
startup delay, then prints its banner and prompt.

## Commands

```text
?       print STR8 ID and Bank 0 state
B       run backup rotation, with verify
E       enroll Bank 0 into backup rotation, destructive, confirmed
0       restore Bank 0 -> Bank 3, with verify
1       restore Bank 1 -> Bank 3, with verify
2       restore Bank 2 -> Bank 3, with verify
G       go to HIMON at $D600
R       reset through the live reset vector
```

The destructive commands ask for `Y`. Anything else aborts.

## Bank Roles

```text
Bank 3  live reset/boot image
Bank 2  newest backup image
Bank 1  older backup image
Bank 0  held base/factory slot until enrolled
```

Saving the board's original WDCMONv2/base flash image is still TODO bridge work.
It is not part of the current STR8 command set.

## Backup

Before Bank 0 enrollment, `B` does this:

```text
Bank 2 -> Bank 1
Bank 3 -> Bank 2
```

After Bank 0 enrollment, `B` does this:

```text
Bank 1 -> Bank 0
Bank 2 -> Bank 1
Bank 3 -> Bank 2
```

Each copy is erased, written, and verified by read-back compare.

## Enroll Bank 0

`E` makes Bank 0 part of automatic backup rotation. This is a one-way normal
operation. STR8 clears bit 0 at `$FFF0`:

```text
bit set/erased  = B0 HOLD
bit cleared     = B0 ROT
```

Once Bank 0 is enrolled, ordinary backup rotation may erase whatever image was
there. Leaving rotation requires erase/reflash or a deliberate STR8 config
rebuild.

## Restore

`0`, `1`, and `2` copy the selected bank into live Bank 3. Restore preserves:

```text
$C000-$CFFF   STR8 RAM-worker source sector
$FA00-$FFFF   STR8 protected window, config pocket, and vectors
```

That means restore updates the ordinary live image but keeps STR8 alive.
Restoring Bank 0 before enrollment may restore a WDCMONv2/base image and may
remove R-YORS from the ordinary Bank 3 body.

## RAM Worker

STR8 copies one compact worker into RAM for flash mutation:

```text
$3000-$31FF   current worker code
$4000-$4FFF   4K sector buffer
```

The worker runs silently, switches banks, erases, writes, verifies, restores
Bank 3, and returns status to the resident STR8 shell. Do not press NMI during
`B`, `E`, `0`, `1`, or `2`.

## Burn Checks

After burning `himon-str8-rom.bin`, these monitor checks should match the
current image:

```text
D C000 +F    08 78 AD 17 03 C9 02 F0 ...
D D600 +F    78 D8 A2 FF 9A AD E6 7E ...
D FA00 +F    78 D8 A2 FF 9A 20 11 FA ...
D FFFA FFFF  E4 F1 00 FA E7 F1
```

## Updating HIMON Or STR8

There is no casual protected-sector updater yet. The sane future command is a
RAM-resident sector transaction:

```text
read live destination sector into RAM
apply staged update bytes in RAM
if only 1->0 bit changes are needed, program and verify
if erase is needed, confirm, erase, write full staged sector, verify
preserve STR8 protected bytes unless this is an explicit STR8 update
restore Bank 3 before printing the result
```

This is the right shape for updating HIMON sectors too, including the shared
top sector below STR8. The guard stays in place; the updater becomes a confirmed
RAM operation that knows exactly which sector it is allowed to rebuild.

## Not Today

These are not part of the small rescue prompt:

```text
advanced sector editor
catalog repair
flash wear counters
STR8 self-update UI
WDCMONv2/base-image preservation
```
