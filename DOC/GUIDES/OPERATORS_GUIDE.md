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

The accepted V1.02 line provides a small Bank-3 recovery supervisor with this
resident command surface:

```text
I           journaled 4K-sector-range install to Bank 0-3
H           local warm HIMON handoff, only when its fixed marker matches
J0-J3       immediate non-destructive reset-vector handoff
```

The default combined image, range receiver, local `H`, Bank Jump Record,
read-only banked AP staging, and valid Bank-0 AP execution are hardware-
accepted. Banks 0-2 accept 4K through 32K ranges; Bank 3 accepts 4K through
28K and rejects its live sector F.

The exact `$0E5F` compact rebuild is board-accepted through its
[directory-preserving refresh proof](STR8/STR8_V1_02_COMPACT_REFRESH_BOARD_TEST.md),
including live readback, reset, local warm HIMON, NMI, and final cold boot.

The hardware log also preserves the earlier V0 backup/restore and fixed
`$C000-$EFFF` payload proofs with HIMON, OSI BASIC, and fig-FORTH. Those are
historical command evidence, not the current resident interface and not
qualification of either language as an unrelated opaque 32K `Jn` guest.

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

Use STR8 when the job installs a selected flash range, hands control to another
bank, or enters local HIMON. Use HIMON for normal monitor, debug, load, ASM,
and AP work.

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

## First Install Vs Normal Update

Use an external flash programmer for the first R-YORS install on a blank board.
Burn the combined image:

```text
SRC/BUILD/bin/himon-str8-rom.bin
```

That first burn installs the reset-owned STR8 recovery sector and the initial
HIMON payload. Once the board boots STR8/HIMON, normal updates move onboard:

```text
STR8 I                  install a selected 4K-sector range with journaling
HIMON L F               flash-load fixed-address low-flash tools, including ASM
ASM PACKAGE/INSTALL     package and store AP envelopes for HIMON/AP to load
```

The external programmer stays as the last-resort recovery path if STR8 cannot
run, the `$F000-$FFFF` recovery sector is damaged, or a full-chip replacement is
intentional. Do not treat the programmer as the normal update path after the
first successful STR8/HIMON boot.

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
HIMON:           $C000-$EEFF
STR8 resident:   $F000-$FE5E
IVI entries:     NMI $F09C, IRQ/BRK $F0B0
free/reserve:    $FE5F-$FF1E, $00C0 bytes
jump worker:     $FF1F-$FFAF, copied to $0200-$0290
V1 directory:    $FFB0-$FFEF
config pocket:   $FFF0-$FFF9
vectors:         $FFFA-$FFFF = 9C F0 00 F0 B0 F0
bank jump record:$1FFD-$1FFF = 42 4A bank/FF
```

The Bank Jump Record preservation matrix is host- and hardware-accepted; its
dedicated record remains in
[Bank Jump Record board test](STR8/STR8_BANK_JUMP_RECORD_BOARD_TEST.md).

After burning, quick monitor checks should look like:

```text
D C000 C00F  4C 07 C0 A5 5A C3 3C 78 D8 A2 FF 9A AD E6 7E C9
D F000 F00F  4C 13 F0 4C 3E F7 18 60 EA 4C F5 F8 53 52 01 07
D F010 F013  4C 44 F7 78
D FF1F FF2E  4C 12 02 08 78 C9 04 B0 06 20 7C 02 28 38 60 28
D FFFA FFFF  9C F0 00 F0 B0 F0
D 1FFD 1FFF  42 4A FF
```

## First Boot

On reset, STR8 initializes IVI vector cells and FTDI console I/O and prints 16
progress dots across an approximately 5.991-second attach interval. It then
drains queued input, prints its make-time identity, and opens the existing
approximately six-second selector:

```text
................
STR8-N V 00.mmdd(hhmm) $F
0/1/2=BOOT H=HIMON S=STR8 ................
```

STR8-N, HIMON, and ASM-F2 receive the same local `00.mmdd(hhmm)` stamp during
one build.

If the selector expires, STR8 cold-starts the local target at `$C000`. `H`
immediately warm-starts that local HIMON without changing banks so RAM is
preserved, but only when its fixed identity is present at `$C003-$C006`. If the
local image is erased, is not HIMON, or has a damaged identity, STR8 prints
`NO HIMON` and remains at its prompt. `S` or `s` enters the
STR8 prompt. `0`, `1`, or `2` prints the selected bank, drains trailing input,
prints `BOOT IN 3S`, waits approximately three more seconds, then uses the same
non-destructive reset-vector handoff as `J0`, `J1`, or `J2`. Interactive
`J0`-`J3` remain immediate. Bare digits at the STR8 prompt are not commands.

The boot selector, cold timeout, STR8 takeover, queued-input flush, reset-time
Bank 0-2 handoffs, and local `H` marker gate are hardware-accepted. Input sent
during the dots is discarded before the selector opens. See
[STR8_BOOT_SELECTOR_BOARD_TEST.md](STR8/STR8_BOOT_SELECTOR_BOARD_TEST.md) and
the later V1.02 captures in the hardware log. Any delay or command-language
change requires the affected checks to be repeated.

## Flash Banks

```text
Bank 3  R-YORS with ASM and newest/timestamped STR8; reset/default
Bank 2  R-YORS with ASM
Bank 1  different R-YORS build without ASM
Bank 0  R-YORS without ASM
```

These are operator-reported live roles, not meanings encoded in the bank
numbers. `I` can replace only the selected range after the destination and
range are shown and `Y` is confirmed.

## STR8 Commands

```text
I       selected-bank/range S19 install, destructive, journaled, confirmed
H       warm-enter identified HIMON in the current bank; no bank change
J0      non-destructive RAM handoff through Bank 0 reset vector
J1      non-destructive RAM handoff through Bank 1 reset vector
J2      non-destructive RAM handoff through Bank 2 reset vector
J3      non-destructive RAM handoff through Bank 3 reset vector
other   print the active command help line
```

STR8 echoes printable command and response letters in uppercase. Backspace,
Delete, or an empty Enter cancels the current command or confirmation; a
terminal CRLF pair is treated as one cancel response.

`J0`-`J3` accept only reset vectors `$8000-$FFFE`, write no flash, and print
`J Bn` before handoff. A successful jump commits the Bank Jump Record and does
not return. An unrelated guest without STR8 cannot issue `J3`, so physical
reset remains the universal return to Bank 3.

`H` never selects a bank. It requires `A5 5A C3 3C` at `$C003-$C006`, writes
the matching warm signature in RAM, and enters local `$C000`. Otherwise it
prints `NO HIMON` and leaves STR8 active.

The former read-only `M` physical map was retired in the 2026-07-18 resident
size pass. Its hardware transcript remains historical evidence; use host/image
maps or the maintained read-only bank tools. Arbitrary destructive work belongs
to `str8-bank-maint`, not to extra resident commands.

## STR8 Workflows

Check identity:

```text
STR8>?
```

Enter local HIMON without changing banks:

```text
STR8-N>H
BOOT WARM
HIMON V 00.mmdd(hhmm)
```

If the current bank does not contain the fixed HIMON marker, `H` prints
`NO HIMON` and returns to STR8.

Launch a qualified bank without changing it:

```text
STR8-N>J2
J B2
... Bank 2 starts through its own $FFFC vector ...
```

Use only a bank whose complete-image CRC and vectors were inventoried first.
The vector gate detects obvious erased/data images; it does not prove identity
or integrity. Bank-3-owned identity and CRC metadata is a future requirement
before managed or unattended alternate-bank launch.

> **IMPORTANT: AN UNRELATED SYSTEM NEEDS ITS OWN QUALIFICATION**
>
> Passing `J0`-`J2` with the current R-YORS banks does not approve OSI BASIC,
> FORTH, WOZMON, or another image. Qualify the exact image and destination
> bank for warm handoff, surviving peripheral state, all three vectors,
> pre/post full-bank CRCs, and physical-reset recovery before routine use.

Follow
[STR8_GUEST_IMAGE_QUALIFICATION.md](STR8/STR8_GUEST_IMAGE_QUALIFICATION.md)
for the generic H/P/V/C record and step-by-step procedure.

Install a selected range with `I`:

```text
STR8-N>I
I B0-3: 2
RANGE: 8-B
TYPE: A5
DESC: RYORS
I B2 8-B
T=A5 D=RYORS NEW P=00 WRITE? Y: Y
SEND S19
....
I OK
```

`RANGE:` is one sector digit (`C`) or an inclusive span (`C-E`). Each sector is
4K. Banks 0-2 allow `8` through `F`, including a full `8-F` 32K image. Bank 3
allows `8` through `E`; sector F is the executing STR8 recovery sector and is
rejected. Existing directory records supply their stored type/description;
`NEW` records ask for a two-hex-digit type and a one-to-five-character
description.

Send the combined stream only after `SEND S19`. It must contain the exact
555-byte mutation worker first and then dense, in-order S1 data for the selected
range. Do not send the payload-only S19 at this prompt. STR8 stages and verifies
one sector at a time, restores Bank 3, and prints `I OK` only after the
directory journal reaches COMPLETE.

The normal primary-image build and compatibility/proof streams are:

```text
make -C SRC all
make -C SRC str8-v1-artifact
```

The focused generated streams include:

```text
SRC/BUILD/s19/str8-v1-i-bank012.s19       full 32K 8-F, Banks 0-2 only
SRC/BUILD/s19/str8-v1-i-asm-8-b.s19      16K ASM range
SRC/BUILD/s19/str8-v1-i-himon-c-e.s19    12K HIMON range
```

Refreshing the active Bank-3 top sector is separate from `I`; `I` cannot select
Bank-3 sector F. Use only the directory-preserving V1 refresh procedure:

```text
make -C SRC str8-v1-refresh-a
```

That writer copies the live `$FFB0-$FFEF` directory before staging the new top
sector. The legacy replacement and one-time migration writers under `OLD` erase
or replace the directory and are not normal V1 refresh tools. For arbitrary
bank/sector maintenance, build and use `str8-bank-maint` with its exact carried
worker; keep its board card and recovery image beside the operation.

## STR8 V1.02 Install Streams

At `SEND S19`, `I` expects one combined stream. It is not enough to send an
ordinary payload S19: the exact mutation worker must precede it in the same
transfer. The checked composer is:

```text
powershell -NoProfile -ExecutionPolicy Bypass `
  -File SRC/tools/build_str8_v1_install_stream.ps1 `
  -MutationWorkerS19Path SRC/BUILD/s19/str8-mutation-worker-0200.s19 `
  -PayloadS19Path LOCAL/my-range.s19 `
  -WorkerEqPath SRC/STR8/str8-worker-eq.inc `
  -S19Path SRC/BUILD/s19/my-range-for-str8-i.s19 `
  -PayloadStart 32768 `
  -PayloadEndExclusive 57344
```

That example composes a 24K `$8000-$DFFF` install. Change the two decimal
bounds to the exact selected 4K-aligned range. The payload must be dense and
in order across the entire range, including bytes that are `$FF`; gaps,
overlaps, mismatched start/end, bad checksums, and bad S9 are rejected before a
successful commit.

Supported sizes are any whole-sector count permitted by the bank: 4K, 8K,
12K, 16K, 20K, 24K, 28K, and 32K on Banks 0-2; up to 28K on Bank 3 because
sector F is protected. The `RANGE:` answer and composer bounds must describe
the same addresses.

The older `himon-str8-himon-update.s19`, fig-Forth update, and OSI BASIC update
streams are payload-only artifacts for the historical V0 `U` gate. Do not send
them directly to V1.02 `I`; first produce a dense range payload and wrap it
with the checked composer above.

## HIMON Commands

```text
?              help
# [token]      list records, or resolve token without executing it
D start        dump one byte
D start end    dump memory through inclusive absolute end
M addr         modify memory byte by byte below $7A00
G addr         go to address
STR8           enter STR8 at $F000
L              load S-records to RAM
L G            load S-records and go to S9 start
L F            flash-load under the current guard
ASM            enter flash-resident ASM when present
R [regs]       display/edit trapped context registers
B start        set one-shot breakpoint
B C start      clear breakpoint
B L            list breakpoints
N              single-step trapped context
X              resume trapped context
Q              quiesce with WAI, then re-enter on wake
```

Use HIMON for ordinary monitor work. Use STR8 for selected-range installs,
bank handoff, local warm-HIMON entry, and protected flash policy.

## HIMON Range Syntax

```text
D start            one byte
D start end        inclusive end
```

The second hex token is an absolute end address and must be greater than start:

```text
D 0000 000F  dumps $0000-$000F
D 3000 30FF  dumps $3000-$30FF
```

`D 30F0 0010` and an equal start/end are rejected. Bare continuation, short
end completion, quoted hashing, and resident byte/text search were removed in
the 2026-07-18 size pass.

## HIMON RAM Proof Loop

New monitor/debug code should prove itself as RAM-loaded S19 before becoming
part of a burnable image.

```text
write a standalone RAM proof
link it inside user program RAM, usually $2000-$77FF
build an S19
load it with HIMON L or L G
debug with B, N, R, X, and D
promote clean code into HIMON or a payload image
```

Useful examples:

```text
make -C SRC life
make -C SRC str8-ram
make -C SRC himon-debug-proof
make -C SRC himon-search-proof   optional legacy search package proof
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

## Flash ASM Package Loop

The current flash-resident ASM workflow uses three command layers:

```text
>            HIMON monitor commands
ASM>$hhhh:   ASM source lines
SEAL>        post-END package/load/install commands
```

Typical setup:

```text
>ASM            current make all image: ASM-F2 is already at $8000
```

After an ASM session, exit with `.` and run the fixed-address reporter from its
Bank 0 AP store address if table detail is needed:

```text
>AP B0 $hhhh $4800
```

The current composite image does not carry the reporter package in Bank 3.
Build it with `make -C SRC asm-session-report` and install/store the package in
Bank 0.

Older board images and narrow development passes can still load the reporter
and ASM-F2 explicitly:

```text
>L              send SRC/BUILD/s19/asm-session-report-7000.s19 if reports are needed
>L F            send SRC/BUILD/s19/asm-v1-flash-8000.s19
>ASM
```

Typical package/install/load proof:

```text
ASM>$2000: ORG $2000
ASM>$2000: LDA #$5A
ASM>$2002: RTS
ASM>$2003: END
SEAL> PACKAGE $3200
SEAL> INSTALL $3200
SEAL> INSTALL $3200 $BD1B
SEAL> LOAD $BD1B $3000
SEAL> .
>D 3000 3002
>G 3000
```

Use the address printed by `INSTALL $3200`; `$BD1B` is the current
board-proven hole for the present `$3D1B` flash ASM image. `INSTALL pkg` only
suggests a hole. `INSTALL pkg flash_addr` writes the AP envelope to erased
visible low flash. If that hole is occupied, `INSTALL pkg` suggests the next
hole, and explicit overwrite attempts report `INST ERR=$06 BAD RANGE`. To load
an installed package in a later session, enter `ASM NEW`, type `END`, run
`LOAD $addr $dest` at `SEAL>`, exit with `.`, then run the destination from
HIMON with `G`.

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
selected-bank sectors that require erase/rewrite
```

Those jobs belong to STR8 `I`, the directory-preserving V1 refresh, or the
explicit `str8-bank-maint` procedure.

## Build Commands

```text
make all
make release
make release-local
make docs-html
make -C SRC help
make -C SRC himon
make -C SRC str8
make -C SRC himon-str8-rom-bin
make -C SRC str8-v1-artifact
make -C SRC life
```

`make all` builds the current onboard 32K image and install S19. `make release`
adds docs and release side artifacts. `str8-v1-artifact` retains compatibility
filenames plus focused `I` proof streams. `make life` still builds a standalone
loadable app S19/BIN without changing the onboard image. `make docs-html` is
an explicit/manual presentation rebuild only; `DOC/HTML` is ignored and
untracked, and Markdown remains canonical.

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
