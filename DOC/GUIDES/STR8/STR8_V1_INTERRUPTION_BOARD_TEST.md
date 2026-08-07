# STR8 V1 Negative and Interrupted Transaction Board Test

Status: host-accepted and hardware-accepted.

This card uses Bank 2 to prove two different failure boundaries. The first
stream has a deliberately wrong mutation-worker identity and must fail before
START. The second stream is valid through the first payload record, causing
START, and then deliberately ends without S9 so physical reset interrupts the
transaction before any 4K sector is programmed.

Keep an external programmer and known-good full-bank recovery image available.
Bank 3 must already contain the hardware-accepted directory launch gate. Back
up anything in Bank 2 that is not represented by the normal recovery stream.

## 1. Build and Freeze the Three Streams

From the repository root:

```text
make -C SRC str8-v1-negative-streams
```

Record the SHA-256 values and do not rebuild between the test phases:

```text
SRC/BUILD/s19/str8-v1-i-bad-worker-id.s19
SRC/BUILD/s19/str8-v1-i-interrupt-after-start.s19
SRC/BUILD/s19/str8-v1-i-bank012.s19
```

The bad-worker file must report 35 records and no S9. The interruption file
must report 36 records, end with one `$8000+$20` S1 record, and contain no S9.
The normal stream is used only for the final retry.

The current host-accepted checkpoint produced:

```text
EACE5C608BA9C0DF3DCB094322E3A81BDBEF767D861D55256DC78544554E5EBD  str8-v1-i-bad-worker-id.s19
C92F3C81310D39EB0E21EE44F5979A71719C24EAF0769B358077301C5497EC55  str8-v1-i-interrupt-after-start.s19
A8CA2F2035A1F6324EB1ABA60B9FFFCA3001B3E33046D85980B855BBE5539042  str8-v1-i-bank012.s19
```

## 2. Starting State

Physical RESET to Bank 3, press `S` during the live dots, and enter warm HIMON
with bare `3`. Require:

```text
D FFD0 FFDF
FFD0: A5 FF FF FF 52 59 4F 52 53 FE FF FF FC FF FF FF
```

This is Bank 2 COMPLETE at pair `$01`. Return to Bank-3 STR8.

## 3. Bad Worker Must Fail Before START

At `STR8-N>` enter:

```text
I
2
Y
```

The immutable summary must show `T=A5 D=RYORS COMPLETE P=01`. At `SEND S19`,
send only:

```text
SRC/BUILD/s19/str8-v1-i-bad-worker-id.s19
```

Require:

```text
I FAIL $15
STR8-N>
```

Enter Bank-3 HIMON with bare `3` and dump `$FFD0-$FFDF`. It must still end in
`FC FF FF FF`. Return to STR8 and issue `J2`; the COMPLETE record must still
launch the existing Bank-2 image. Physical RESET back to Bank 3 before the
interruption phase.

## 4. Interrupt Immediately After START

Press `S` during the Bank-3 live dots. At `STR8-N>` enter:

```text
I
2
Y
```

Again require `T=A5 D=RYORS COMPLETE P=01`. At `SEND S19`, send only:

```text
SRC/BUILD/s19/str8-v1-i-interrupt-after-start.s19
```

The transfer ends after the first payload S1. STR8 intentionally remains
silent and blocked waiting for the next record. Wait at least three seconds
after the terminal's file send finishes, send no additional characters, and
press physical RESET.

During the new Bank-3 live dots press `S`, then immediately enter:

```text
J2
```

Require the fail-closed result:

```text
J B2
JERR B2 V=$0000
STR8-N>
```

Do not retry until this rejection is captured. Enter Bank-3 HIMON with bare
`3` and require:

```text
D FFD0 FFDF
FFD0: A5 FF FF FF 52 59 4F 52 53 FE FF FF F8 FF FF FF
```

`F8 FF FF FF` is pair 1 STARTED/INCOMPLETE. If the journal is still `FC`, the
reset happened before START and the interruption proof is invalid. Stop on any
other value.

## Hardware Checkpoint: Bad Worker Accepted

On 2026-08-06, refreshed Bank 3 `STR8-N V 00.0806(1900)` began with the
Bank-2 record COMPLETE at pair `$01`. Sending the frozen bad-worker stream
returned:

```text
I FAIL $15
STR8-N>
```

The Bank-2 journal remained exactly `FC FF FF FF`, proving the identity failure
did not write START. `J2` then printed `J B2` and launched the distinct Bank-2
`STR8-N V 00.0806(1707)` image.

## Hardware Checkpoint: Interruption Accepted

The subsequent 2026-08-06 capture closes Section 4. After physical reset,
Bank-3 `J2` printed `JERR B2 V=$0000`; `I2` described the record as
`INCOMPLETE P=01`; and Bank-3 HIMON read the exact journal tail
`F8 FF FF FF`. The operator also repeated the deliberately unterminated stream
and physical-reset recovery, with `J2` again failing closed. This proves START
survives reset and prevents launch before completion. Section 5 was completed
by the later retry checkpoint below.

## 5. Retry the Same Pair to Completion

Return to Bank-3 STR8 and enter:

```text
I
2
Y
```

The summary must reuse the immutable metadata and show
`T=A5 D=RYORS INCOMPLETE P=01`. At `SEND S19`, send the normal file:

```text
SRC/BUILD/s19/str8-v1-i-bank012.s19
```

Require eight sector dots, `I OK`, and a prompt. Enter Bank-3 HIMON and require:

```text
D FFD0 FFDF
FFD0: A5 FF FF FF 52 59 4F 52 53 FE FF FF F0 FF FF FF
```

Pair 1 is now COMPLETE and the next pair is `$02`. Return to STR8 and issue
`J2`; the updated Bank-2 image must boot. Physical RESET and one final Bank-3
directory dump should retain `F0 FF FF FF`.

## Hardware Checkpoint: Retry and Relaunch Accepted

On 2026-08-06, the normal combined stream was sent against
`T=A5 D=RYORS INCOMPLETE P=01`. Eight sector dots completed, STR8 returned
`I OK`, and Bank-3 HIMON read the exact journal tail `F0 FF FF FF`. `J2` then
launched the newly written Bank-2 `STR8-N V 00.0806(1927)`, which completed
its cold path through `RAM ZERO OK` into `HIMON V 00.0806(1927)`.

The final all-`FF` directory dump in that capture is Bank 2's local directory,
not Bank 3's preserved directory. A final physical reset returned to Bank-3
`STR8-N V 00.0806(1900)`, and Bank-3 HIMON read the exact persistent record:

```text
FFD0: A5 FF FF FF 52 59 4F 52 53 FE FF FF F0 FF FF FF
```

This closes the bad-worker, post-START interruption, fail-closed launch,
same-pair retry, restored launch, and reset-persistence board test.
