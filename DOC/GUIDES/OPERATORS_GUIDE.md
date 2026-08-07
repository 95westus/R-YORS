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

That historical proof covers the fixed `$C000-$EFFF` payload gate in a
compatible bank layout. It does not qualify OSI BASIC or fig-FORTH as an
unrelated opaque 32K `Jn` guest. Full-bank guest qualification is a separate
procedure.

The hardware log preserves proof of the earlier backup rotation and Bank 0
enrollment policy, plus `U` / `UPDATE HIMON`, HIMON U1-to-U2 update, temporary
BASIC and Forth payloads, and recovery back to known-good HIMON from backup
flash. The current image replaces rotation/enrollment with an explicit
single-bank backup destination. Its reset selector, uppercase interactive echo,
and `J0`-`J3` handoff are hardware-accepted. The follow-up Bank Jump Record is
host-accepted and still requires its separate persistence transcript.

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

## First Install Vs Normal Update

Use an external flash programmer for the first R-YORS install on a blank board.
Burn the combined image:

```text
SRC/BUILD/bin/himon-str8-rom.bin
```

That first burn installs the reset-owned STR8 recovery sector and the initial
HIMON payload. Once the board boots STR8/HIMON, normal updates move onboard:

```text
STR8 U / UPDATE HIMON   update HIMON or another $C000-$EFFF payload stream
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
HIMON:           $C000-$EECB
STR8 image:      $F000-$F9D0
IVI entries:     NMI $F0BA, IRQ/BRK $F0CE
STR8 ROM marker: $F8B0 = 7A 0F 6A 5F (not displayed in banner)
worker source:   $FD93-$FFEF, copied to RAM when needed
config pocket:   $FFF0-$FFF9
vectors:         $FFFA-$FFFF = BA F0 00 F0 CE F0
bank jump record:$1FFD-$1FFF = 42 4A bank/FF
```

The displayed Bank Jump Record bytes describe the host-accepted follow-up ABI.
Do not treat them as board-proven persistence until the dedicated
[Bank Jump Record board test](STR8/STR8_BANK_JUMP_RECORD_BOARD_TEST.md) is
completed and appended to the hardware log.

After burning, quick monitor checks should look like:

```text
D C000 C00F  78 D8 A2 FF 9A AD E6 7E ...
D F000 F00F  4C 10 F0 4C 9C F3 4C A3 F3 4C AB F3 53 52 01 07
D FD03 FD12  08 78 AD F0 1F C9 05 F0 11 C9 06 F0 12 C9 07 F0
D FFFA FFFF  C0 F0 00 F0 D4 F0
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

If the selector expires, STR8 cold-starts the local HIMON at `$C000`. `H`
immediately warm-starts that local HIMON without changing banks so RAM is
preserved, and `S` or `s` enters the
STR8 prompt. `0`, `1`, or `2` prints the selected bank, drains trailing input,
prints `BOOT IN 3S`, waits approximately three more seconds, then uses the same
non-destructive reset-vector handoff as `J0`, `J1`, or `J2`. Interactive
`J0`-`J3` remain immediate. Bare digits at the STR8 prompt are not commands.

The boot-selector protected install, visible build identity, cold timeout,
STR8 takeover, queued-input flush, and warm-`3` RAM retention have hardware
proof. Reset-time Bank 1 and Bank 2 delayed handoffs pass by capture, and
Bank 0 is operator-accepted. The operator accepted the earlier selector delay
profile and all remaining selector and inventory gates. The superseded
four-dot display and current 16-dot/six-second emitter both run correctly on
hardware. A power cycle captured 14 of the 16 dots because the serial path was
not yet ready for the first two characters; already-live entries repeatedly
captured all 16. The six-second `6 5 4 3 2 1` prompting delay has hardware
proof for both a complete no-input timeout and a key accepted at count 6.
The operator also verified that input sent during the dots is discarded before
the selector opens. The attach-display and prompting-delay gates are complete. See
[STR8_BOOT_SELECTOR_BOARD_TEST.md](STR8/STR8_BOOT_SELECTOR_BOARD_TEST.md).
Any future delay change requires the affected timing checks to be repeated.
The warm-`3` statement above describes the accepted V1.01 transcript. V1.02
changes that spelling to `H`; that nomenclature change is host-verified only
until its focused board proof is appended.

## Flash Banks

```text
Bank 3  R-YORS with ASM and newest/timestamped STR8; reset/default
Bank 2  R-YORS with ASM
Bank 1  different R-YORS build without ASM
Bank 0  R-YORS without ASM
```

These are the operator-reported 2026-07-28 live roles, not meanings encoded in
the bank numbers. `B` may still target Bank 0, 1, or 2. None has special
protection; the selected destination is erased after the target is shown and
`Y` is confirmed. On this mixed-version board, do not use `B` unless replacing
that exact target is intended.

## STR8 Commands

```text
B       back up Bank 3 to selected Bank 0/1/2, destructive, confirmed
U       update $C000-$EFFF from S19, destructive, confirmed
0       restore Bank 0 -> Bank 3, destructive, confirmed
1       restore Bank 1 -> Bank 3, destructive, confirmed
2       restore Bank 2 -> Bank 3, destructive, confirmed
J0      non-destructive RAM handoff through Bank 0 reset vector
J1      non-destructive RAM handoff through Bank 1 reset vector
J2      non-destructive RAM handoff through Bank 2 reset vector
J3      non-destructive RAM handoff through Bank 3 reset vector
G       go to HIMON at $C000
R       reset through the live reset vector
other   print the active command help line
```

STR8 echoes printable command and response letters in uppercase. Backspace,
Delete, or an empty Enter cancels the current command or confirmation; a
terminal CRLF pair is treated as one cancel response.

`J0`-`J2` are installed in the current Bank-3 STR8. Their direct-RAM and
resident target/reset matrix passes on hardware, as do the corrected inventory
and direct installed-image checks. The six-byte echo follow-up passed its RAM
`J2` preflight, guarded TopWriter `S`/`V`/`P` sequence, and resident visible
`J0`/`J1`/`J2` smoke. The accepted installed CRCs are
`$4B59/$2A3D/$04EF/$4663`. A jump accepts only reset vectors
`$8000-$FFFE`, writes no flash, and prints `J Bn` before handoff. After a
successful jump, physical reset is the universal return to Bank 3.
Use [STR8_J012_BOARD_TEST.md](STR8/STR8_J012_BOARD_TEST.md) for the guarded
read-only inventory, RAM handoff, and resident-install sequence.

The current host candidate adds `J3` as an explicit software return to Bank 3
for a copied STR8 running in Bank 0-2. It reuses the same RAM worker and vector
gate; `G`, `R`, and reset-selector `3` retain their local-bank meanings. An
unrelated guest that does not contain STR8 cannot issue `J3`, so physical reset
remains the universal recovery path. The installed parser and a Bank-0
functional handoff smoke pass. A later distinguishable run entered Bank-0
STR8 `1509`, issued `J3`, and reached Bank-3 STR8/HIMON `1518`; J3 is
board-accepted.

The former read-only `M` physical map was retired in the 2026-07-18 resident
size pass. Its hardware transcript remains historical evidence; use host/image
maps until a catalog-aware inventory view is implemented.

## STR8 Workflows

Check identity:

```text
STR8>?
```

After the candidate is installed and its read-only gates pass, launch a known
bank without changing it:

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

Back up the live image:

```text
STR8>B
BACKUP B3 TO B0/1/2: 2
 ERASE? Y:y
COPY B3->B2
... one verified Bank 3 -> Bank 2 copy ...
```

Choose `0`, `1`, or `2`. Only the selected bank is replaced; the other two
backup banks are not cascaded or changed. `E` is no longer a command, and an
old `$FFF0` enrollment bit has no effect.

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

Run `B` before `U` when the current live image should be preserved in a chosen
backup bank. Do not run `B` after a temporary payload boots unless that payload
should become recoverable.

Updating the active STR8 top sector is a separate, dangerous operation. Build
the current self-contained writer and matching HIMON stream together:

```text
make -C SRC str8-topwrite-a himon-str8-himon-update-s19
```

For the 2026-07-18 linker-ownership migration, update HIMON first through the
old STR8 `U` gate, verify HIMON, and only then assemble and run
`DOC/GUIDES/ASM/SAMPLES/OLD/str8n-topwrite-transient-3000.a`. New HIMON calls its
resident linker directly and remains usable with the old STR8 doorway. The
reverse order temporarily puts the new `$F006` AP-operation adapter in front
of an old HIMON service that does not implement that operation.

Assemble the top writer after the HIMON update: STR8 `U` uses `$4000-$4FFF` as
its sector buffer, which overwrites the writer's embedded top-sector image.
`G 3000` opens TopWriter's text-operation menu. Use `S` to stage and verify,
`V` to recheck the stage, `I` to print the saved mode/result/failure address,
and `Q` to return to HIMON. `P` first rechecks the complete stage, then requires
the exact confirmation word `WRITE` before it erases/programs/verifies bank 3
`$F000-$FFFF`. `G 3003` remains the raw, unconfirmed compatibility entry for
scripted or deliberately modified-stage tests. The generated sector
deliberately restores `$FFF0-$FFF9` to erased bytes; those bytes no longer
control Bank 0 backup access.

For the current code-size/explicit-backup candidate, use the complete
paste-ready board card:
[`STR8_SIZE_PASS_BOARD_TEST.md`](STR8/STR8_SIZE_PASS_BOARD_TEST.md). It pins
the exact files and hashes, installs HIMON/ASM/STR8 in the safe order, records
all four bank CRCs around each `B`, and includes the RAM-only worker timeout
and failure-tail proof.

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

Use HIMON for ordinary monitor work. Use STR8 for backup, restore, image
rotation, and protected flash policy.

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
Bank 0 rotation policy
whole-bank backup/restore images
```

Those jobs belong to STR8 or a future confirmed RAM updater.

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
make -C SRC life
```

`make all` builds the current onboard 32K image and install S19. `make release`
adds docs and release side artifacts. `make life` still builds a standalone
loadable app S19/BIN without changing the onboard image. `make docs-html` is an
explicit/manual presentation rebuild only; `DOC/HTML` is ignored and untracked,
and Markdown remains canonical.

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
