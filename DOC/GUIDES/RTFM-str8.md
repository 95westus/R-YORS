# RTFM STR8

STR8 is the small recovery/update monitor that runs before HIMON. It owns the
dangerous flash decisions: backup rotation, restore, Bank 0 enrollment, and
protected-window preservation.

Read this before pressing a destructive key.

## Command Safety Mandate

```text
DESTRUCTIVE FLASH MUST CONFIRM BEFORE ERASE/WRITE.
```

Short selectors are allowed when STR8 owns the range. `U` is acceptable because
it is a fixed HIMON updater, not a raw address prompt. The safe rule is:

```text
selection can be short
target/range is fixed by STR8
S19 is checked before erase
erase/write asks for Y
```

The current one-key recovery commands are still a proof surface with
confirmation. Future raw-range or advanced tools should use louder words or a
separate guided menu.

## Current Layout

```text
combined image:  SRC/BUILD/bin/himon-str8-rom.bin
identity marker: STR8 V0 #5F6A0F7A
HIMON:           $C000-$E75B
STR8 image:      $F000-$FA83
IVI entries:     NMI $F089, IRQ/BRK $F09D
marker bytes:    $F770 = 7A 0F 6A 5F
worker source:   $FC00-$FEBE, copied to RAM when needed
STR8 window:     $F000-$FFFF
config pocket:   $FFF0-$FFF9
vectors:         $FFFA-$FFFF = 89 F0 00 F0 9D F0
```

Target live-bank budget:

```text
$8000-$BFFF   16K user code/data
$C000-$EFFF   12K HIMON budget
$F000-$FFFF    4K STR8 recovery sector
```

STR8 may use less than 4K, but the whole top sector is recovery-owned.

On reset, STR8 initializes the IVI RAM vector cells, initializes the FTDI path,
waits briefly, prints the R-YORS banner, then prints `HIMON IN 3S. S=STR8` and
counts down `3 2 1`. Press `S` during that countdown to enter STR8.

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

The live hardware vectors enter STR8 first:

```text
NMI      -> STR8 IVI entry at $F089 -> RAM vector $7EFA-$7EFB
RESET    -> STR8 START at $F000
IRQ/BRK  -> STR8 IVI entry at $F09D -> RAM vectors $7EFC-$7EFF
```

STR8 seeds those RAM vectors with `RTI` defaults before the countdown. HIMON
then installs its active NMI, BRK, and IRQ targets after handoff.

## Commands

```text
?       print `STR8 V0 #5F6A0F7A` and Bank 0 state
B       run backup rotation, with verify
E       enroll Bank 0 into backup rotation, destructive, confirmed
M       map banks/sectors as used `+` or erased `-`
U       update HIMON from S19, fixed gate $C000-$EFFF, confirmed before write
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

The 2026-05-17 hardware pass proved both modes: the initial `B0 HOLD` rotation
copied `B2->B1` and `B3->B2`, then `E` enrolled Bank 0 and the next `B` copied
`B1->B0`, `B2->B1`, and `B3->B2`.

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

Hardware note: Bank 0 enrollment is now proven on the bench. After `E`, STR8
prints `B0 ROT`, and payloads rotate through Bank 0 exactly like HIMON images.

## Restore

`0`, `1`, and `2` copy the selected bank into live Bank 3. Restore preserves:

```text
$C000-$FFFF   HIMON/STR8 protected region unless high flash is confirmed
$FC00-$FEBE   STR8 RAM-worker source inside the protected top sector
$FFF0-$FFFF   config pocket and hardware vectors
```

That means restore updates the ordinary live image but keeps STR8 alive.
Restoring Bank 0 before enrollment may restore a WDCMONv2/base image and may
remove R-YORS from the ordinary Bank 3 body.

## RAM Worker

STR8 copies one compact worker into RAM for flash mutation:

```text
$0200-$04D1   current worker code
$0200-$05FF   STR8 RAM tray copied from $FC00
$0A00-$0A16   STR8 worker/update state board and map bytes
$4000-$4FFF   4K sector buffer for bank copy
$4000-$6FFF   staged C/D/E sector buffers during U
```

The worker runs silently, switches banks, erases, writes, verifies, restores
Bank 3, and returns status to the resident STR8 shell. The `M` command also
uses the worker, but only to scan and store map status bytes. `U` receives S19
in resident STR8, stages a blank HIMON C/D/E image in RAM, overlays the S19
bytes, then uses the worker to erase/write/verify all three sectors. Do not
press NMI during `B`, `E`, `M`, `U`,
`0`, `1`, or `2`.

## Burn Checks

After burning `himon-str8-rom.bin`, these monitor checks should match the
current image:

```text
D C000 +10   78 D8 A2 FF 9A AD E6 7E ...
D F000 +10   78 D8 A2 FF 9A 20 36 F0 ...
D FC00 +10   08 78 AD 07 0A C9 04 F0 ...
D FFFA FFFF  89 F0 00 F0 9D F0
```

## Updating HIMON Or STR8

`U` is the current HIMON updater. It is intentionally narrow:

```text
STR8>U
UPDATE HIMON C000-EFFF? Y:
SEND S19 C000-EFFF
...
PROGRAM C000-EFFF? Y:
```

Only S1 data records in `$C000-$EFFF` are accepted. S0 is skipped, S9 ends the
transfer, and any other type or outside address aborts before erase. STR8 first
fills C/D/E staging RAM with `$FF`, merges the S19 bytes, then asks before
programming `$C000-$EFFF`.

The companion host target is:

```text
make -C SRC himon-str8-himon-update-s19
```

It emits `SRC/BUILD/s19/himon-str8-himon-update.s19`, a compact `$C000-$EFFF`
stream suitable for `U`; all-`$FF` S1 data records are omitted because STR8
starts from a blank staged image. Do not send the full `$8000-$FFFF`
`himon-str8-rom-install.s19` stream to `U`; STR8 should reject it before erase.

There is also an experimental payload target for the same fixed gate:

```text
make -C SRC fig-forth-str8-update-s19
```

It emits `SRC/BUILD/s19/fig-forth-str8-update.s19`, a `$C000-$EFFF` stream
that puts a bootable fig-Forth image where HIMON normally lives. The image has a
real entry at `$C000` (`JMP FORTH_ORIG`), keeps the fig-Forth FNV header after
that entry, and makes Forth `MON` jump back to STR8 at `$F000`. Treat this as a
bench payload test: run `B` first if Bank 2 should keep known-good HIMON, and
use the high-flash restore path to put HIMON back into Bank 3.

After a payload boots, `B` promotes that payload into the backup chain. That is
useful only when the payload should become recoverable. If you want to keep the
previous HIMON as the recovery image, do not run `B` again until HIMON has been
restored or until an older backup bank is intentionally kept untouched.

The same bench shape exists for OSI MS BASIC:

```text
make -C SRC msbasic-osi-str8-update-s19
```

It emits `SRC/BUILD/s19/msbasic-osi-str8-update.s19`, a `$C000-$EFFF` stream
that puts bootable BASIC where HIMON normally lives. BASIC enters at `$C000`,
keeps its FNV record after that entry, and uses STR8's resident console calls in
the top sector. This payload disables BASIC's background Ctrl-C poll for now so
it does not consume pending input through STR8's simple console primitive.

The 2026-05-17 hardware pass proved this payload through `U` and ran:

```text
10 PRINT "HELLO"
RUN
HELLO
```

STR8 self-update is still future work. The sane shape remains a RAM-resident
top-sector transaction:

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
