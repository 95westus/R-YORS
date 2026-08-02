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
  initialize IVI and private console I/O without changing the selected bank
  wait silently about 4 seconds
  drain queued RX with the existing bounded flush
  print STR8-N V 00.mmdd(hhmm)
  open the approximately 6-second selector

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

The current attach and selector-prompt delays are each approximately 5.991
seconds at 8 MHz. The separate selected-bank `BOOT IN 3S` delay remains
approximately 3.010 seconds. Any future timing change creates a changed
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

The 2026-08-01 diagnosis supersedes the interpretation above: the copied
image's unconditional Bank-3 selection was a startup regression, not required
handoff behavior. Current source preserves the bank selected by `1`, `2`, or
`J0`-`J2`; see `STR8_J012_BOARD_TEST.md` for the focused repair gate.

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

## 2026-08-02 Four-Dot Attach Follow-Up

Status: partial board pass; exact power-cycle count and dot-time RX flush open.

Current source replaces the first silent attach interval with four visible dot
ticks. Each tick is approximately 0.994 seconds at 8 MHz, for approximately
3.975 seconds total before the identity. The terminal result must be:

```text
....
STR8-N V 00.mmdd(hhmm)
```

The dots are progress only; they do not arm selector input. The bounded RX
flush still occurs after the fourth dot and before the identity and selector.
For focused board acceptance:

1. Reset with no input and require exactly four dots, about one second apart,
   followed by the identity and normal selector.
2. Type `2` during the dot interval and require it to be discarded. The normal
   selector must time out to Bank-3 HIMON cold.
3. Reset, wait until the identity/selector appears, then enter `S`; require
   immediate STR8 takeover.
4. Reconfirm selector timeout and one known Bank-0/1/2 route. The later
   three-second `BOOT IN 3S` delay is unchanged.

This source change adds 23 resident bytes. It moves the STR8 code/data end to
`$F9C5` and leaves the normal resident/worker gap at `$F9C6-$FD92`, `$03CD`
bytes. The previous silent-delay acceptance remains valid only for its recorded
candidate; it does not accept this visible-dot revision.

### 2026-08-02 Board Result

The current `$F8AC/$F8E3` TopWriter assembled and passed stage, verify, and
confirmed program. A power-off reset reached no-hash STR8 `00.0802(1404)`, but
the first captured line was `>...`, not a separate four-dot line. Later live
Bank-3 and copied Bank-0 STR8 entries repeatedly produced exactly:

```text
....
STR8-N V 00.0802(1404)
```

This accepts the four-dot routine and line formatting on hardware. It does not
close step 1 for a power cycle because that capture contains only three visible
dots, and it does not close step 2 because no byte was injected during the dot
interval. Repeat those two focused checks with the terminal already attached
and a hardware reset that does not disconnect the serial adapter.

Normal `S`, timeout/cold entry, selector Bank 0/1/2 routes, and prompt
`J0`/`J1`/`J2` continued to work in the same session. The later `BOOT IN 3S`
delay was unchanged.

## 2026-08-02 Sixteen-Dot / Six-Second Follow-Up

Status: host and board pass; all attach-display gates complete.

The current candidate supersedes the four-dot timing with 16 emitted dots over
approximately 5.991 seconds:

```text
................
STR8-N V 00.mmdd(hhmm)
```

The first three ticks are approximately 0.398 seconds each; the remaining
thirteen are approximately 0.369 seconds each. Selector input remains disabled
through the sequence, and the bounded RX flush occurs after dot 16.

A true power cycle also resets the FTDI bridge and forces USB enumeration and
terminal reconnection. The CPU can transmit early dots before the host has
reopened the serial path, so a power-cycle transcript may legitimately omit
leading dots. The superseded candidate's repeated four-dot output with an
already-live connection is evidence that its loop was correct. Use a hardware
reset that leaves the FTDI/USB connection enumerated when proving the exact
16-dot count.

Board acceptance requires:

1. With the terminal already connected, hardware-reset the CPU and require all
   16 dots followed by the no-hash identity.
2. On another reset, send `2` during the dots. Require it to be discarded and
   require selector timeout to local HIMON unless a new post-flush key is sent.
3. Reconfirm `S` after the banner and one `0`/`1`/`2` selector route. The later
   `BOOT IN 3S` delay is unchanged.

The 16-dot scheduler adds 8 bytes over the four-dot version, 31 bytes total
over the no-progress baseline. The later `J3` help addition adds 3 more bytes.
Current STR8 code/data ends at `$F9D0`; the normal gap is `$F9D1-$FD92`,
`$03C2` bytes, and the V1 preflight reserve is `$F9D1-$FD52`, `$0382` bytes.
The generated TopWriter checks the current face at `$F8B4` and prompt at
`$F8EE`.

### 2026-08-02 Board Result

The `$F8B4/$F8EB` TopWriter assembled, staged, verified, and programmed the
no-hash STR8 `00.0802(1420)` candidate. Already-live STR8 entries repeatedly
printed exactly 16 dots on their own line before the identity. The power-off
capture began with only 14 visible dots:

```text
>..............
STR8-N V 00.0802(1420)
```

The same installed image printed all 16 dots on every later entry. That
contrast accepts the 16-dot emitter and supports the expected explanation:
the CPU emitted the first two characters before the power-cycled FTDI/host
serial path was ready. A true power-cycle transcript is therefore not an
exact-count gate; use an already-enumerated reset when an exact reset capture
is wanted.

The same run selected Banks 2, 1, and 0 in sequence. Bank 2 was independently
distinguished by HIMON `1404`, and Bank 0 by its older four-dot STR8 `1404`
image. Bank 1 and Bank 3 were exact `1420/1425` copies, so the Bank-1 trace is
not an independent persistence observation in this session; the earlier
distinct-payload Bank-1 proof remains authoritative. `S` and the later
`BOOT IN 3S` handoff remained correct. No byte was injected during the 16-dot
interval in that capture, so the post-dot RX-flush behavior remained the only
focused gate until the later operator acceptance below.

## 2026-08-02 Six-Second Prompting Delay

Status: host and board pass.

This change does not alter the 16-dot attach sequence. After dot 16, the RX
flush, and the STR8-N identity, the boot selector now displays:

```text
0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3 2 1
```

One approximately 1.022-second tick followed by five approximately
0.994-second ticks gives a modeled selector-prompt interval of approximately
5.991 seconds at 8 MHz. The later `BOOT IN 3S` pause after choosing Bank 0, 1,
or 2 is unchanged at approximately 3.010 seconds. The constant-only change has
no resident code-size or address effect.

Board acceptance requires one no-input timeout showing `6 5 4 3 2 1`, plus
one valid selector key accepted during the extended prompt. The already-proven
16-dot count does not need to be repeated unless its output changes.

### Board Result

The `$F8B4/$F8EB` TopWriter assembled through `ASM OK` and `SEAL`, then passed
stage, verify, confirmed Bank-3 program, and return. The installed candidate
identified as STR8/HIMON `00.0802(1440)`. With no selector input it displayed
the full prompting countdown and cold-entered local HIMON:

```text
STR8-N V 00.0802(1440)
0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3 2 1
BOOT COLD
RAM ZERO OK
HIMON V 00.0802(1440)
```

On the next live entry, `0` was accepted during the first count:

```text
STR8-N V 00.0802(1440)
0/1/2=BOOT 3=HIMON S=STR8  6 0
J B0
BOOT IN 3S
```

This closes the no-input timeout and extended-prompt key gates. Bank 0 then
ran its older four-dot/three-count `1404` image, confirming that only Bank 3
received the new top sector. The separate three-second selected-bank pause
remained present. Exact wall-clock measurement was not supplied; acceptance
is based on all six modeled ticks executing on hardware.

### Distinct Bank-1 Follow-Up

After copying Bank-3 `1440` to Bank 1, the operator advanced only Bank 3 to
STR8/HIMON `1452`. From that distinct Bank-3 image, reset selector `1` printed
`J B1`, retained the separate `BOOT IN 3S` pause, and reached Bank-1 STR8
`1440`. This independently reconfirms the reset-time Bank-1 route and proves
the selected bank remained active after startup.

### Operator Acceptance: Dot-Time Input Rejection

The operator explicitly verified that input sent during the 16-dot attach
interval is discarded by the post-dot RX flush and is not consumed as a boot
selector response. Discarded input intentionally leaves no printable terminal
token, so this is operator-observed hardware proof. This closes the last
attach-display gate.

## 2026-08-02 Unavailable Local-App Fallback

Status: host and board pass.

STR8 now checks the first 16 bytes at the selected bank's local `$C000` before
the timeout/cold handoff and before the `3` or `G` warm handoff. An all-`$FF`
entry face prints `NO BOOT @C000` and enters the STR8 menu. This is the small
safe response to an erased HIMON or user-app window; it does not claim that a
non-erased target is complete or valid.

Keep the current HIMON update S19 available before the destructive check.
Using the direct-run maintenance utility, select `E`, Bank 3, and range `8-E`,
then enter the exact confirmation `ERASE 38-E`. Sector F and STR8 remain
installed. At the next STR8 selector, provide no input and require:

```text
0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3 2 1

NO BOOT @C000
STR8-N V ...
ROM $F000
? U J0 J1 J2 J3 G R
STR8-N>
```

There must be no second attach-dot sequence and no reset loop. Issue `G` and
require `G HIMON`, followed by `NO BOOT @C000` and the same resident prompt.
Then use `U` to reinstall HIMON and verify both no-input cold entry and `G`
warm entry normally reach the restored image.

An empty Bank 0-3 selected with `Jn` remains covered by the separate reset-
vector gate: it must print `JERR Bn V=FFFF` and return to the menu without
jumping. Append the raw board transcript after the new local-`$C000` behavior
is observed; the earlier erased-Bank-3 capture documents the failure that this
gate is intended to close, not acceptance of the fix.

### Board Result

STR8 `00.0802(1709)` and the direct-run maintenance utility assembled and ran
on the board. The operator selected `E`, Bank 3, sector C, and entered the
exact `ERASE 3C` confirmation. The utility made no post-erase HIMON call and
returned through the still-resident Bank-3 STR8 sector F.

No selector input was supplied. After the complete six-count timeout, the
candidate detected the erased `$C000-$C00F` entry face and entered its menu:

```text
................
STR8-N V 00.0802(1709)

0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3 2 1

NO BOOT @C000

STR8-N V 00.0802(1709)
ROM $F000
? U J0 J1 J2 J3 G R
STR8-N>
```

There was no second attach sequence or reset loop. `U` then reprogrammed and
verified `$C000-$EFFF`; the following `G` printed `BOOT WARM` and entered
HIMON `00.0802(1657)`. This hardware-accepts the requested no-input fallback
and recovery path.

The focused follow-up erased Bank-3 range `9-D`, allowed the no-input timeout
to return to the menu, and then issued `G` while `$C000` was still erased:

```text
STR8-N>G
G HIMON

NO BOOT @C000

STR8-N V 00.0802(1709)
ROM $F000
? U J0 J1 J2 J3 G R
STR8-N>
```

A new STR8 entry then selected `3` during count `6` and produced the same
`NO BOOT @C000` menu fallback. The no-input/cold, `G` warm, and selector-`3`
warm paths are now all directly hardware-accepted.
