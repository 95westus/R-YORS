# HIMON I/O LED Board Card

Status: accepted on COM4, 2026-09-06. The installed image is
`HIMON V 00.0906(1935)`. It adds HIMON-owned wait, receive, and transmit LED
status for HIMON and ASM-F2 while leaving the raw FTDI service records
LED-neutral for applications that own Port A. The focused host checks, guarded
Bank-3 C-E install, live LED checks, ASM-F2 inheritance probe, and physical
RESET recovery all passed.

## Reviewed Candidate

| Item | Value |
| --- | --- |
| Bank/range | Bank 3, sectors C-E |
| Transfer | `SRC/BUILD/s19/himon-apv2-bank3-c-e.s19` |
| Transfer SHA-256 | `EA4F6153332710E571A2A9385DC2C8B9BD08E5D7952F6049CA7BBB8E309B9537` |
| HIMON ROM SHA-256 | `122063BCD91B9E84CEE8509FF026396312EE7E9B656DCBC1256649BAD37F0A05` |
| Resident end | `$EE72` |
| Margin below STR8-N | `$018E` (398 bytes) |

The transfer is a dense `$C000-$EFFF` image with S9 `$C000`. It deliberately
does not write sector F, which contains STR8-N 1.31.

## Install

The board must be at the STR8-N prompt before beginning. If a RAM test program
is looping, use physical RESET to regain the selector.

1. Select `I` at the STR8-N prompt.
2. Select Bank `3`.
3. Select range `C-E` and confirm the displayed range.
4. Wait for STR8-N to print `S19`, then send only
   `SRC/BUILD/s19/himon-apv2-bank3-c-e.s19` at 115200 baud.
5. Require the normal install completion and return to the selector. During
   flash mutation `$F0` may be brief; its absence by eye is not a failure when
   the install completes normally.
6. Enter HIMON and require the banner `HIMON V 00.0906(1935)`.

## Focused LED Proof

With the FTDI host connected, require `$43` while HIMON waits for a command.
Type one character without Enter and require `$07`; finish or cancel the line
and require `$43` again at the next prompt.

Enter `ASM`. At the `ASM>` prompt, type one source character without Enter and
require `$07`. Finish or cancel that line, then assemble this transmit probe in
a fresh session:

```text
ORG $3000
MAIN: LDA #'T'
      JSR OUT
LOOP: BRA LOOP
OUT:  JMP ($7E08)
END
.
```

From HIMON, run `G 3000`. Require `T` on the terminal and `$0B` latched on the
LEDs while the program loops. This proves ASM-F2 output inherits the HIMON
service-vector policy without an ASM flash update.

Finish with physical RESET. Require the STR8-N 1.31 selector, enter HIMON, and
require `HIMON V 00.0906(1935)` with `$43` at the prompt.

Record the exact terminal output and observed LED values in
`../LOGS/HARDWARE_TEST_LOG.md`. Leave this card pending if any identity differs
from the reviewed candidate.

## Accepted Observations

The guarded install returned to `STR8-N>` after two visible `$F0` mutation
periods before the held final sector was committed. `$07` appeared during S19
receive, and the installed STR8-N prompt settled at `$43`.

Cold entry printed `HIMON V 00.0906(1935)` and settled at `$43`. One partial
HIMON character and one partial ASM-F2 character each latched `$07`; Ctrl+C
returned to a `$43` wait after brief `$0B` output activity. ASM-F2 remained
`00.0905(2321)` and assembled the probe at `$3000-$3009` without error. `G
3000` printed `T` and left `$0B` visible while looping.

A complete HIMON `D 0 FFFF` dump held `$0B` during output and restored `$43`
when the command completed, directly proving the monitor's bulk-output path.

Physical RESET produced `$01`, `$0B`, then `$43`, booted the same HIMON image,
and left `$43` at its prompt. The operator corrected a few initially reported
`$0B`/`$83` readings to `$43` after checking the display; the values above are
the final observations.
