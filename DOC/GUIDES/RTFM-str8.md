# RTFM STR8

STR8 is the small recovery/update monitor that runs before HIMON. It owns the
dangerous flash decisions: backup rotation, restore, Bank 0 enrollment, and
protected-window preservation.

Read this before pressing a destructive key.

## Command Safety Mandate

```text
DESTRUCTIVE COMMANDS MUST BE 4+ CHARACTERS.
```

Future STR8 destructive commands must use full words such as `BACKUP`,
`RESTORE`, `ENROLL`, `ERASE`, `FLASH`, or `BANK`. STR8 keeps `R` as reset. The
current one-key recovery commands are an early proof surface with confirmation,
not a pattern for adding more destructive short commands.

## Current Layout

```text
combined image:  SRC/BUILD/bin/himon-str8-rom.bin
identity marker: STR8 V0 #5F6A0F7A
HIMON:           $C000-$E72D
STR8 image:      $F000-$F71E
marker bytes:    $F481 = 7A 0F 6A 5F
worker source:   $F800-$FA92, copied to RAM when needed
STR8 window:     $F000-$FFFF
config pocket:   $FFF0-$FFF9
vectors:         $FFFA-$FFFF
```

Target live-bank budget:

```text
$8000-$BFFF   16K user code/data
$C000-$EFFF   12K HIMON budget
$F000-$FFFF    4K STR8 recovery sector
```

STR8 may use less than 4K, but the whole top sector is recovery-owned.

On reset, STR8 initializes the FTDI path, waits briefly, prints the R-YORS
banner, then prints `HIMON IN 3S. S=STR8` and counts down `3 2 1`. Press `S`
during that countdown to enter STR8.

Current banner:

```text
____      ____    ____   ____      ____
|   \    /   |   /    \  |   \    /
|___/    |___|  |      | |___/    \___
|   \    /   |  |      | |   \        \
|    \  /    |   \____/  |    \   ____/
```

If the countdown expires, STR8 clears HIMON's warm-reset signature before
jumping to `$C000`, so HIMON takes its cold path. STR8's explicit `G` command
still uses the warm handoff.

## Commands

```text
?       print `STR8 V0 #5F6A0F7A` and Bank 0 state
B       run backup rotation, with verify
E       enroll Bank 0 into backup rotation, destructive, confirmed
M       map banks/sectors as used `+` or erased `-`
0       restore Bank 0 -> Bank 3, with verify
1       restore Bank 1 -> Bank 3, with verify
2       restore Bank 2 -> Bank 3, with verify
G       go to HIMON at $C000
R       reset through the live reset vector
```

The destructive commands ask for `Y`. Anything else aborts.
`R` is retained as STR8 reset.

`M` is read-only. It scans all banks by 4K sector, restores Bank 3, and prints:

```text
BANK0     BANK1     BANK2     BOOT
+--++--  --++--++  --------  ++++++++
```

Each character maps to `$8000,$9000,$A000,$B000,$C000,$D000,$E000,$F000`.
`-` means the whole sector is `$FF`; `+` means at least one byte is used.

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
$C000-$FFFF   HIMON/STR8 protected region unless high flash is confirmed
$F800-$FA92   STR8 RAM-worker source inside the protected top sector
$FFF0-$FFFF   config pocket and hardware vectors
```

That means restore updates the ordinary live image but keeps STR8 alive.
Restoring Bank 0 before enrollment may restore a WDCMONv2/base image and may
remove R-YORS from the ordinary Bank 3 body.

## RAM Worker

STR8 copies one compact worker into RAM for flash mutation:

```text
$0200-$0492   current worker code
$0200-$09FF   STR8 RAM tray copied from $F800
$0A00-$0A0C   STR8 worker state board and map bytes
$4000-$4FFF   4K sector buffer
```

The worker runs silently, switches banks, erases, writes, verifies, restores
Bank 3, and returns status to the resident STR8 shell. The `M` command also
uses the worker, but only to scan and store map status bytes. Do not press NMI
during `B`, `E`, `M`, `0`, `1`, or `2`.

## Burn Checks

After burning `himon-str8-rom.bin`, these monitor checks should match the
current image:

```text
D C000 +10   78 D8 A2 FF 9A AD E6 7E ...
D F000 +10   78 D8 A2 FF 9A 20 23 F0 ...
D F800 +10   08 78 AD 07 0A C9 04 F0 ...
D FFFA FFFF  0B DF 00 F0 0E DF
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
