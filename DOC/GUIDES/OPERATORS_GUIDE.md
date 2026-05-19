# R-YORS Operator Guide

This is the board-in-front-of-you guide. It says what R-YORS does today, which
prompt owns which job, and which commands are safe to use for ordinary bench
work.

For implementation details, read [TECHNICAL_GUIDE.md](./TECHNICAL_GUIDE.md).
For project narrative, read [BOOK.md](STORY/BOOK.md),
[HISTORICAL_DOCUMENTS.md](STORY/HISTORICAL_DOCUMENTS.md), and
[../IDEAS.md](../IDEAS.md). The story lane is useful, but it is not required
for operating the board.

## Current Status

As of 2026-05-18, STR8 is hardware-proven rotating three bootable images
through the fixed `$C000-$EFFF` update gate:

```text
HIMON      recovery, inspection, loading, debug
OSI BASIC  interactive BASIC payload
fig-FORTH  threaded language payload
```

The proven STR8 path includes flash map reporting, backup rotation, Bank 0
enrollment, `U` / `UPDATE HIMON`, HIMON U1-to-U2 update, temporary BASIC and
Forth payloads, and recovery back to known-good HIMON from backup flash.

Treat this as a bench-proven recovery/update guard, not a finished field
updater. Keep a known-good image and an external programmer path nearby.

HIMON has hardware proof for RAM-only debug behavior: `B`, `B C`, `B L`, `N`,
and `X`. Breakpoints are one-shot, synthetic debug stops print as `@hhhh`, and
debug patching is limited to RAM.

## Mental Model

```text
reset -> STR8 -> HIMON -> user work
```

```text
R-YORS  whole project and runtime direction
STR8    recovery/update guard that runs before the payload
HIMON   default monitor payload for inspection, loading, debug, catalog work
```

Use STR8 when the job changes boot images, backup banks, or protected flash
policy. Use HIMON when the job is normal monitor work.

## Safety Rules

Some commands and host tools can erase or program flash. Use this project only
with a recovery path.

```text
STR8 destructive flash commands ask for confirmation before erase/write.
HIMON future destructive commands must use 4+ character command words.
Do not press NMI while STR8 is mapping, erasing, programming, or restoring.
```

Current short mutators are transition debt from the existing ROM/proof surface.
Do not add new short destructive commands.

## Current Image

The primary burnable image is:

```text
SRC/BUILD/bin/himon-str8-rom.bin
```

Current live-bank layout:

```text
$8000-$BFFF   16K user code/data
$C000-$EFFF   12K payload gate, currently HIMON
$F000-$FFFF    4K STR8 recovery sector
```

Current combined-image facts:

```text
HIMON:           $C000-$E75B
STR8 image:      $F000-$FA83
IVI entries:     NMI $F089, IRQ/BRK $F09D
STR8 identity:   #5F6A0F7A
marker bytes:    $F770 = 7A 0F 6A 5F
worker source:   $FC00-$FEBE, copied to RAM when needed
config pocket:   $FFF0-$FFF9
vectors:         $FFFA-$FFFF = 89 F0 00 F0 9D F0
```

After burning, quick monitor checks should look like:

```text
D C000 +10   78 D8 A2 FF 9A AD E6 7E ...
D F000 +10   78 D8 A2 FF 9A 20 36 F0 ...
D FC00 +10   08 78 AD 07 0A C9 04 F0 ...
D FFFA FFFF  89 F0 00 F0 9D F0
```

## First Boot

On reset, STR8 initializes IVI vector cells and FTDI console I/O, prints the
R-YORS banner, then prints:

```text
HIMON IN 3S. S=STR8
```

Press `S` during the countdown to enter the STR8 prompt. If the countdown
expires, STR8 jumps to HIMON at `$C000`.

## Flash Banks

```text
Bank 3  live reset/boot image
Bank 2  newest backup image
Bank 1  older backup image
Bank 0  base/factory hold until enrolled
```

Bank 0 is not ordinary rotation space until `E` is confirmed in STR8. After
enrollment, Bank 0 may be erased by future backups.

## STR8 Commands

```text
?       print STR8 ID/state, including #5F6A0F7A
B       backup rotation, destructive, confirmed
E       enroll Bank 0 into backup rotation, destructive, confirmed
M       map banks/sectors as used + or erased -
U       update $C000-$EFFF from S19, destructive, confirmed
0       restore Bank 0 -> Bank 3, destructive, confirmed
1       restore Bank 1 -> Bank 3, destructive, confirmed
2       restore Bank 2 -> Bank 3, destructive, confirmed
G       go to HIMON at $C000
R       reset through the live reset vector
```

`M` is read-only, but it still switches flash banks through the RAM worker.
Let it finish. The map prints eight sector characters per bank, corresponding
to `$8000,$9000,$A000,$B000,$C000,$D000,$E000,$F000`.

## STR8 Workflows

Check identity and bank state:

```text
STR8>?
STR8>M
```

Back up the live image:

```text
STR8>B
... confirm with Y only if the rotation is intended ...
```

Before Bank 0 enrollment, backup rotates:

```text
Bank 2 -> Bank 1
Bank 3 -> Bank 2
```

After Bank 0 enrollment, backup rotates:

```text
Bank 1 -> Bank 0
Bank 2 -> Bank 1
Bank 3 -> Bank 2
```

Enroll Bank 0 only when losing its current contents is acceptable:

```text
STR8>E
... confirm with Y ...
```

Restore an older image:

```text
STR8>2
... confirm with Y ...
STR8>G
```

Ordinary restore preserves the high protected region. Recovery over a bad
`$C000` payload uses the separately confirmed high-flash path.

Update the current `$C000-$EFFF` payload:

```text
STR8>U
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
... send the S19 stream ...
PROGRAM C000-EFFF? Y: y
OK
STR8>G
```

Run `B` before `U` when the current live image should be preserved in the
backup chain. Do not run `B` after a temporary payload boots unless that
payload should become recoverable.

## STR8 Payload Streams

Build the current HIMON update stream:

```text
make -C SRC himon-str8-himon-update-s19
```

It emits:

```text
SRC/BUILD/s19/himon-str8-himon-update.s19
```

Build the proven temporary payload streams:

```text
make -C SRC fig-forth-str8-update-s19
make -C SRC msbasic-osi-str8-update-s19
```

They emit `$C000-$EFFF` S19 streams for the same STR8 `U` gate. These are bench
payloads used to prove image rotation and recovery.

For your own `$C000` payload, STR8 expects this contract:

```text
$C000        executable entry or jump stub
$C000-$EFFF  S1 data accepted by STR8 U
$F000-$FFFF  STR8-owned recovery sector, not part of the payload
```

For a 12K binary already based at `$C000`:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File SRC/tools/build_rom_install_s19.ps1 `
  -BinPath LOCAL/mymon-c000.bin `
  -S19Path SRC/BUILD/s19/mymon-str8-update.s19 `
  -BaseAddress 49152 `
  -StartAddress 49152 `
  -OmitAllFFDataRecords
```

For a full 32K `$8000-$FFFF` bank image, crop the STR8 gate:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File SRC/tools/build_rom_install_s19.ps1 `
  -BinPath LOCAL/mymon-bank.bin `
  -S19Path SRC/BUILD/s19/mymon-str8-update.s19 `
  -BaseAddress 32768 `
  -RangeStart 49152 `
  -RangeEnd 61439 `
  -StartAddress 49152 `
  -OmitAllFFDataRecords
```

STR8 rejects records outside `$C000-$EFFF` before erase.

## HIMON Commands

```text
?              help
# [token]      list records, or resolve token without executing it
"text"         print legacy FNV-1a32; reports STR8 match on #5F6A0F7A
D start +count dump memory by byte count
D start end    dump memory through inclusive end
M addr         modify memory byte by byte
U start +count disassemble
A addr         assemble
G addr         go to address
L              load S-records to RAM
L G            load S-records and go to S9 start
L F            flash-load under the current guard
R [regs]       display/edit trapped context registers
B start        set one-shot breakpoint
B C start      clear breakpoint
B L            list breakpoints
N              single-step trapped context
X              resume trapped context
Q              quiesce with WAI, then re-enter on wake
```

Use HIMON for ordinary monitor work. Use STR8 for backup, restore, image
rotation, and protected flash policy.

## HIMON Range Syntax

```text
start end       end is inclusive
start +count    count is the number of bytes
```

Short end tokens inherit the start high byte:

```text
D 100 3       dumps $0100-$0103
D 3000 FF     dumps $3000-$30FF
D 3000 +100   dumps $3000-$30FF
```

A 3- or 4-hex-digit end token is a full address. `D 1000 FFF` resolves as
`$0FFF` and is rejected because it lands before `$1000`; use `D 1000 1FFF` or
`D 1000 +1000`.

Target behavior for bare `D` is continuation from the previous dump:

```text
D 3000 FF
D
D
```

## HIMON RAM Proof Loop

New monitor/debug code should prove itself as RAM-loaded S19 before becoming
part of a burnable image.

```text
write a standalone RAM proof
link it inside user program RAM, usually $2000-$77FF
build an S19
load it with HIMON L or L G
debug with B, N, R, X, D, and U
promote clean code into HIMON or a payload image
```

Useful examples:

```text
make -C SRC life
make -C SRC str8-ram
make -C SRC himon-debug-proof
make -C SRC himon-search-proof
```

On the board:

```text
>L
>L G
>B 3000
>G 3000
```

`L` clears active debug patches before accepting new S-records. Set
breakpoints after loading the image they belong to.

## HIMON Debug Notes

RAM debug patching is limited to `$2000-$77FF`. If a breakpoint or step tries
to patch system RAM, I/O, or ROM/flash, HIMON reports:

```text
DBG RAM
```

Debugger-owned stops print as compact `@hhhh` lines. Real program `BRK xx`
stops remain loud and keep their signature.

Breakpoints are one-shot in the current build. An `@hhhh` hit consumes the
slot. Persistent breakpoints are future work.

## Loading And Flashing

`L` and `L G` are the normal RAM proof path. `L F` is conservative: it writes
only where the current guard allows and expects blank flash bytes. It is not a
sector erase/update tool.

Do not use HIMON to casually rewrite:

```text
STR8 protected window
hardware vectors
Bank 0 rotation policy
whole-bank backup/restore images
```

Those jobs belong to STR8 or a future confirmed RAM updater.

## Build Commands

```text
make release
make release-local
make docs-html
make -C SRC help
make -C SRC himon
make -C SRC str8
make -C SRC himon-str8-rom-bin
```

`make release` regenerates source-derived docs, builds the tracked release set,
and stamps the HIMON/STR8 ROM binary. `make docs-html` regenerates the
presentation copy under `DOC/HTML`; Markdown remains canonical.

## Where To Go Next

```text
TECHNICAL_GUIDE.md       architecture, memory, flash policy, source/build map
HARDWARE_TEST_LOG.md     board transcript proof
HIMON_DEBUG_TESTING.md   RAM debug bench process
MEMORY_MAP.md            address ownership
REF.md                   compact reference sheet
GLOSSARY.md              vocabulary contract
DECISIONS.md             settled policy
```
