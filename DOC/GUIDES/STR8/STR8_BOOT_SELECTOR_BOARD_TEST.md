# STR8 Boot Selector Board Test

This is the staged hardware-proof rail for the reset-time `0`/`1`/`2`/`3`/`S`
selector. It does not replace the accepted interactive `J0`-`J2` proof.

```text
status:       ACCEPTED
candidate:    himon-str8-rom.bin
SHA-256:      A8ED60EF826D0931B09CF8EA52AB8A1B5299B0488C324044DBE0B626712FBF46
source date:  2026-07-30
```

This file preserves the accepted boot-selector image and its historical map.
The later Bank Jump Record candidate changes both HIMON and the packed worker;
use [`STR8_BANK_JUMP_RECORD_BOARD_TEST.md`](STR8_BANK_JUMP_RECORD_BOARD_TEST.md)
for its current addresses and proof gates.

The candidate changes Bank 3 `$F000-$FFFF`. Keep an external programmer and a
known-good Bank 3 image available before installation. Do not treat a successful
host build as board acceptance.

## Contract Under Test

```text
physical reset
  initialize IVI, private console I/O, and explicit Bank 3 selection
  wait silently about 4 seconds
  drain queued RX with the existing bounded flush
  print STR8-N V 00.mmdd(hhmm) #5F6A0F7A
  open the existing 3-second selector

selector timeout  -> Bank 3 HIMON cold
3                 -> Bank 3 HIMON warm immediately, preserving RAM
S or s            -> STR8 prompt immediately
0, 1, or 2        -> print J Bn
                     drain trailing RX
                     print BOOT IN 3S
                     wait about 3 more seconds
                     run the existing non-destructive Jn RAM handoff
```

Bare `0`, `1`, and `2` at the STR8 prompt remain destructive restore commands.
Prompt `J0`, `J1`, and `J2` remain immediate and must not print `BOOT IN 3S`.

The software delays are approximately 4.003 seconds and 3.010 seconds at
8 MHz and are accepted for this candidate. The established selector countdown
remains approximately 3 seconds. Any future timing change creates a changed
candidate and reopens the corresponding hardware timing observation. One
combined host build gives STR8-N, HIMON, and ASM-F2 the same local stamp. A
top-sector-only install must match STR8-N against its staged top-sector
candidate; record the independently installed HIMON and ASM-F2 identities,
which may be older.

## Host Gates

From the repository root:

```text
make -C SRC str8
make -C SRC himon-str8-rom-bin
git diff --check
```

Required combined-build report:

```text
STR8 START/NMI/IRQ/END  = F000/F0BD/F0D1/FAC0
WORKER RUN/STORE/SIZE   = 0200/FD16-FFEF/2DA
STR8 RES/WORKER GAP     = FAC0-FD15/256 (min 200)
Vectors NMI/RESET/IRQ   = F0BD/F000/F0D1
```

Required direct bytes:

```text
F000: 4C 10 F0 4C 63 F3 4C 6A F3 4C 72 F3 53 52 01 07
F91E: 7A 0F 6A 5F
FD16: 08 78 AD F0 1F C9 05 F0 11 C9 06 F0 12 C9 07 F0
FFFA: BD F0 00 F0 D1 F0
```

The worker bytes and `$FD16-$FFEF` placement must remain unchanged from the
accepted `J0`-`J2` image.

## Pre-Install Record

Before changing Bank 3:

1. Record the visible HIMON, ASM-F2, and STR8 identities.
2. Run the accepted four-bank inventory and save every bank CRC and vector.
3. Record the expected identity and reset vector for Banks 0, 1, and 2.
4. Confirm physical reset returns to the currently installed Bank 3 image.
5. Archive the current complete Bank 3 image.

Do not infer a bank's identity from its number. Use only guests already
qualified by
[STR8_GUEST_IMAGE_QUALIFICATION.md](STR8_GUEST_IMAGE_QUALIFICATION.md).

## Install

Generate the candidate top-sector stage and the guarded TopWriter:

```text
make -C SRC str8-top-stage-s19
make -C SRC str8-topwrite-a
```

Use the established TopWriter `S`, `V`, and confirmed `P` sequence in the
operator guide. Require the stage check, pre-program verification, program,
and post-program verification to pass. Stop on any mismatch.

## 2026-07-30 Partial Hardware Result

The 2,815-line, 115,732-byte transcript has SHA-256
`14C5354474081424AC4689F264103992754B409B4356BDFAEAC7AE29316018F5`.
It contains two complete guarded TopWriter assemblies and installations.
Both runs completed:

```text
TW> S
TW STG
TW OK
TW> V
TW OK
TW> P
TW OK
TYPE WRITE TO PROGRAM B3> WRITE
TW PRG
TW OK
```

The first embedded `$F000-$FFFF` sector reports STR8-N
`00.0730(2331)` and has SHA-256
`6F5504BFCB63452F439895F0DBDDFF422E1330BE70C04A1491DB6686D5ACDB4F`.
The final installed sector reports `00.0730(2338)`, has SHA-256
`39D1797DBB301C771FE91A68AB5634AF9E45398AAB89135C1254A05FB705A615`,
and matches the current host BIN's top-sector bytes exactly.

The transcript proves:

- the protected-sector `S`/`V`/confirmed-`P` path and `RET A=AC`;
- the visible stamped STR8-N reset and `?` identity;
- selector timeout through `BOOT COLD`, `RAM ZERO OK`, and HIMON `2121`;
- takeover into the STR8 screen during the selector;
- existing `G HIMON` warm entry;
- successful verified `B3->B0` and final `B3->B2` backups;
- abort and accepted HIMON `U` paths, plus the established confirmed restore
  path used during the session.

The final visible Bank-3 component identities are STR8-N `00.0730(2338)`,
HIMON `00.0730(2338)`, and ASM-F2 `00.0728(2113)`. That mixed set is expected
after a top-sector install and HIMON-only `U`; the low ASM sector was not
updated. The final `B3->B2` operation intentionally changes Bank 2, so this
capture is not a non-destructive pre/post inventory proof.

Gates left open after this initial capture:

- settle the delay values and record the resulting attach and selected-bank
  timing observations;
- uppercase and lowercase `S` differentiation if both are required as
  separately visible cases;
- invalid-input continuation, interactive `J0` regression, and a fresh
  post-install four-bank inventory from the new baseline.

### Warm-3 And Flush Follow-Up

The 1,039-line, 42,742-byte continuation transcript has SHA-256
`AAECA204DA54B3C8E85580F7F2DAFD574FDD846F568B6BEB8C020D0F95B2C174`.

It passes selector `3` warm entry with an executable RAM sentinel. TopWriter
was assembled and run at `$3000`, the board was reset, selector `3` printed
`BOOT WARM`, and `G 3000` launched the intact TopWriter again. This proves RAM
retention across the warm path. The follow-up TopWriter session used only `Q`
and did not program flash.

The operator also verified that input queued during the silent attach period
is discarded before the selector opens. This passes the bounded RX-flush
behavior; the chosen attach-delay duration was still provisional at this
stage.

Prompt `J1` and `J2` both hand off immediately without `BOOT IN 3S`. Bank 1's
older unstamped STR8/HIMON `00.0728(2113)` identity and Bank 2's copied current
STR8-N/HIMON `00.0730(2338)` identity visibly distinguish the destinations.
Interactive `J0` remains to be repeated with the final inventory.

### Reset-Time Bank 1 And Bank 2 Follow-Up

The operator's next capture passes the delayed reset-time Bank 1 route:

```text
J B1
BOOT IN 3S

STR8-N
HIMON IN 3S. S=STR8-N  3 2 1
BOOT COLD
RAM ZERO OK
HIMON V 00.0728(2113)
```

The older unstamped STR8 and HIMON `00.0728(2113)` identities authenticate
Bank 1. The following current stamped Bank 3 face demonstrates recovery.
`G 3000` then reaches `BRK 00 PC=3002`, which is expected after that guest's
`BOOT COLD` and `RAM ZERO OK`.

The same capture passes the delayed reset-time Bank 2 route:

```text
J B2
BOOT IN 3S

STR8-N V 00.0730(2338) #5F6A0F7A B3
B3 0/1/2=BOOT 3=HIMON S=STR8  3 2 1
BOOT COLD
RAM ZERO OK
HIMON V 00.0730(2338)
```

Bank 2 is the verified copy of the current Bank 3 image, so the matching
`00.0730(2338)` identities are expected. The copied STR8 reset path explicitly
reselects Bank 3 before continuing. These captures prove that `1` and `2`
invoke the additional-delay route and reach their expected guests; they do
not constitute an elapsed-time measurement.

### Reset-Time Bank 0 Operator Acceptance

The operator explicitly accepts the reset-time Bank 0 selector. No additional
terminal capture was supplied for this case, so the result is
operator-declared. With the captured Bank 1 and Bank 2 results, the functional
reset-time `0`/`1`/`2` selector set is accepted. Delay timing and the final
non-destructive inventory were still separate gates at this stage.

## Non-Destructive Selector Matrix

Run each case from physical reset. Do not combine it with a flash write.

### Attach Delay And Pre-Flush

1. Reset and verify no STR8 output appears for about four seconds.
2. During that silent interval, type `2`.
3. Record the banner's `00.mmdd(hhmm)` stamp and require it to match the staged
   STR8 top sector. For a full combined-image install, also require the HIMON
   and ASM-F2 stamps to match. Then type nothing.
4. Require the queued `2` to have been discarded.
5. Require the selector to count down and enter Bank 3 HIMON cold.

This proves the input window opens after the attach delay and bounded flush,
not at reset.

### Timeout And Local Choices

1. Reset, type nothing, and require timeout to Bank 3 HIMON cold.
2. At HIMON, use `M 3000` to store `$A5`, then confirm it with `D 3000 3000`.
3. Press physical reset, press `3`, and require immediate Bank 3 HIMON warm
   without another three-second bank delay.
4. Require `D 3000 3000` to still report `$A5`. This is the required RAM
   preservation proof for selector `3`.
5. Reset, press `S`, and require the STR8 prompt.
6. Repeat with lowercase `s`.
7. Reset, enter one invalid byte, and require the selector to continue rather
   than treating it as a destination.

### Bank 0-2 Choices

For each known Bank 0, Bank 1, and Bank 2 guest:

1. Reset and press the matching digit during the selector.
2. Require `J Bn`.
3. Require `BOOT IN 3S`.
4. Require no guest output for approximately three seconds.
5. Require the expected guest identity after its own `$FFFC` reset-vector
   entry.
6. Press physical reset and require Bank 3 again.

An invalid or erased vector must restore Bank 3 and print the existing
`JERR Bn V=$hhhh` result before entering the STR8 prompt.

### Interactive J Regression

Enter STR8 with `S`, then run `J0`, `J1`, and `J2`, returning by physical reset
between runs. Each command must print `J Bn` and hand off immediately. Seeing
`BOOT IN 3S` on an interactive `Jn` command is a regression.

## Accepted Result

On 2026-07-30 the operator accepted every remaining gate for the installed
STR8-N `00.0730(2338)` candidate. This explicitly includes the current delay
profile, invalid-input continuation, distinct `S`/`s`, interactive `J0`, and
the final non-destructive inventory.

No additional terminal capture, elapsed-time measurement, or CRC table was
supplied for those final items, so they are recorded as operator-declared
acceptance. The earlier protected-install, warm-`3`, flush, and Bank 1/2
captures remain the source for capture-backed evidence.

This candidate has no remaining selector gates. A future delay adjustment
changes the candidate and requires the affected timing and selector
observations to be repeated.
