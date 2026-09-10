# HIMON Live USB LED Board Card

Status: accepted on COM4, 2026-09-10.

This HIMON-only candidate replaces the private blocking receive call with a
cooperative nonblocking loop. While HIMON or its ASM-F2 line service waits for
input, PWE# changes must update the LED display without a byte arriving. Raw
FTDI records remain LED-neutral, STR8-N is unchanged, and `$07` receive
activity remains latched until host presence actually changes.

## Reviewed Candidate

| Item | Value |
| --- | --- |
| Bank/range | Bank 3, sectors C-E |
| Transfer | `SRC/BUILD/s19/himon-apv2-bank3-c-e.s19` |
| Transfer S19 SHA-256 | `ED749822BAA6174AD67190B5F661C5A9BC5BA0E234FDC5C84292CE791A8F17A4` |
| HIMON ROM S19 SHA-256 | `134CCF194AC695CBA0A2ABE719C599422BB1756C694ADFFC3A7D7D04E1DD65DA` |
| HIMON 32K ROM BIN SHA-256 | `D1FBA7549B358BC52C25F4D366DDCDEDF002FFE64F317CC70C1F58900CB5D6BD` |
| Visible identity | `HIMON V 00.0910(1202)` |
| Resident end | `$EE95` |
| Margin below STR8-N | `$016B` (363 bytes) |

The transfer must be a dense `$C000-$EFFF` image with S9 `$C000` and must not
write Bank-3 sector F.

## Install

1. Begin at the STR8-N prompt and select `I`.
2. Select Bank `3`, range `C-E`, and confirm the displayed range.
3. At `S19`, send only `SRC/BUILD/s19/himon-apv2-bank3-c-e.s19` at 115200
   baud.
4. Require normal install completion and return to the STR8-N selector.
5. Enter HIMON and require the exact reviewed identity above.

## Live Transition Proof

The board is USB-powered. Keep VBUS present by using Windows Device Manager
with **View -> Devices by connection** and disable the FTDI **USB Serial
Converter** parent, not merely the COM child or USB hub.

1. At a settled HIMON prompt require `$43`. Without typing a character,
   disable the FTDI converter and require `$21`; re-enable it and require
   `$43`. No new prompt or received byte may be needed for either transition.
2. Type one printable character without Enter and require `$07`. Disable the
   converter and require `$21`; re-enable it and require `$43`. This proves
   that `$07` stays latched while the host remains present but yields to an
   actual PWE# transition.
3. Enter `ASM`. At a settled `ASM>` line wait repeat `$43 -> $21 -> $43`
   without sending source input. This proves inheritance through HIMON's line
   service without an ASM flash change.
4. Reach a harmless HIMON single-character confirmation. Its preceding output
   may leave the host-bearing `$0B` TX state visible; require `$0B -> $21 ->
   $43`, answer negatively, and require normal return to the prompt.

## Regression And Recovery

Run or reuse an application that owns the LED byte and calls the raw FTDI
services. Require its chosen LED value to remain unchanged, proving that the
public raw records are still neutral.

Finish with physical RESET. Require the STR8-N v1.32 selector, enter HIMON,
require the reviewed identity, and require `$43` at the prompt. Append the
exact terminal transcript, Device Manager actions, and observed LED values to
`../LOGS/HARDWARE_TEST_LOG.md`. Keep this card and the feature-queue checkbox
pending if any identity, transition, ownership, or recovery result differs.

## Accepted Observations

COM4 identified the installed owner as STR8-N 1.32. An initial `I` sent at the
reset selector rather than the shell was rejected before any bank/range or S19
phase. Re-entry waited through reset quarantine, selected `S`, and reached the
maintenance shell. The guarded install then displayed exact target `B3 C-E`,
accepted the reviewed stream, printed two staging dots, requested the separate
commit, and returned:

```text
STR8-N>I
B0-3: 3
RANGE: C-E
I B3 C-E WRITE? Y: Y
S19
..COMMIT? Y: Y.
OK
STR8-N>C
BOOT COLD

HIMON V 00.0910(1202)
>
```

At that existing HIMON prompt, disabling the FTDI USB Serial Converter parent
changed `$43` to `$21`; re-enabling it changed `$21` back to `$43`, with no
input byte or new prompt. A partial `X` latched `$07`; the same operation then
produced `$07 -> $21 -> $43`. ASM-F2 `00.0907(0959)` inherited
`$43 -> $21 -> $43` at its existing source wait. The harmless `RUN STR8 ... ?`
single-character confirmation displayed `$0B -> $21 -> $43` and was declined.

The focused linked-byte gate proves that both public raw BIO blocking records
still target their unchanged LED-neutral entries. This reuses the accepted
2026-09-06 application-ownership board proof because the current slice changes
only the private HIMON caller.

Physical RESET was captured from before reset through the recovered prompt:

```text
RST H

STR8-N 1.32
0-2 C W S:
BOOT WARM

HIMON V 00.0910(1202)
>
```

The final prompt displayed `$43`. All required install, transition, ownership,
and recovery gates pass.
