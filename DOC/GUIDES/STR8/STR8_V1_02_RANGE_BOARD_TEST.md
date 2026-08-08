# STR8 V1.02 Range Installer Board Test

Status: parameterized range installer hardware-accepted as `00.0807(2000)`.

This is the first destructive board rail for the V1.02 parameterized dense
receiver. It refreshes only Bank 3 sector F, preserving the live V1 directory,
then updates the documented disposable Bank 2 in two independently verifiable
operations:

```text
Bank 2 $8000-$BFFF  ASM-F2 component, 16K, range 8-B
Bank 2 $C000-$EFFF  HIMON component, 12K, range C-E
Bank 2 $F000-$FFFF  preserved old STR8/reset sector
```

The latest hardware record has Bank 3 at `00.0806(2135)` and Bank 2 COMPLETE
with metadata `A5/RYORS` and journal `F0 FF FF FF`. Stop if the live board does
not match that state, or if Bank 2 is no longer sacrificial. Keep an external
programmer and a known-good full-bank recovery image available. Use only the
already-qualified FTDI/Tera Term Send File path; this test does not qualify an
ACIA.

## 1. Build and Record

From the repository root:

```text
make -C SRC str8-v1-artifact "HIMON_VISIBLE_STAMP=0807(2000)"
```

Use the explicit stamp above to reproduce this exact candidate. An unstamped
artifact build creates a new minute-stamped identity and is a different board
candidate.

Record the visible STR8/HIMON/ASM-F2 identity and SHA-256 for:

```text
SRC/BUILD/bin/himon-str8-v1.bin
DOC/GUIDES/ASM/SAMPLES/str8n-v1-refresh-transient-3000.a
SRC/BUILD/s19/str8-v1-i-asm-8-b.s19
SRC/BUILD/s19/str8-v1-i-himon-c-e.s19
DOC/GUIDES/ASM/SAMPLES/str8-bank-crc-all-3000.a
```

Each `I` stream already contains the exact mutation worker followed by its
dense payload and unique S9. Do not send the mutation-worker S19 separately.
The build prints the expected CRC-16/CCITT-FALSE bytes in the same low/high
order used by the onboard CRC fixture.

The prepared candidate for this rail is:

```text
HIMON/ASM-F2/STR8-N identity         00.0807(2000)
himon-str8-v1.bin SHA-256            D8659B7024439F815245D7B6458AC7C7D0CE66E1DB56253CEEF0C987E9776E16
str8n-v1-refresh-transient SHA-256    AAC9E07C27BE2734029EFB2AE3C6CBABDABB60968EF2B8B718D48D1C57B92C63
str8-v1-i-asm-8-b.s19 SHA-256        4D4234A2281CC739AFF5D76BEC3FB8842B1BC8C7F518BF3281871A48B81B6A1D
str8-v1-i-himon-c-e.s19 SHA-256      10B65837A8B0CA94BFFB65DC46B41C0F3BB2FA732416D9619253107AB47772AB
str8-bank-crc-all-3000.a SHA-256     CF38A8CF76DB20FC83A2A71499E28F218F9D7EAA45D128FEE237DD8F4C877640
ASM sectors 8 9 A B CRClo/hi         EC B7  36 70  CE 76  63 D9
HIMON sectors C D E CRClo/hi         F2 56  F1 61  74 08
```

Stop if a local rebuild does not reproduce the identity, hashes, and CRCs
above; do not mix an old refresh source with newly generated range streams.

## 2. Capture the Starting State

At Bank-3 HIMON, save the live directory:

```text
D FFB0 FFEF
```

The Bank-2 row must be:

```text
FFD0: A5 FF FF FF 52 59 4F 52 53 FE FF FF F0 FF FF FF
```

Assemble and run the maintained read-only CRC fixture:

```text
ASM NEW
```

Send:

```text
DOC/GUIDES/ASM/SAMPLES/str8-bank-crc-all-3000.a
```

Require `ASM OK`, finish with `.` / `ASM BYE`, then:

```text
G 3000
D 1A00 1A0B
D 1A10 1A4F
```

Require `$1A00=$AC`. Save all four sector-CRC rows, especially Bank 2 at
`$1A30-$1A3F`. Each sector occupies `CRClo CRChi` in order 8 through F. This
is the preservation oracle for every later step.

## 3. Refresh Bank 3 to V1.02

Follow the directory-preserving path only. At HIMON enter `ASM NEW`, then send:

```text
DOC/GUIDES/ASM/SAMPLES/str8n-v1-refresh-transient-3000.a
```

Require `ASM OK` and `SEAL>`, enter `.`, then stage and quit before programming:

```text
G 3000
S
Q
D 0A00 0A13
D 191F 1937
D 19B0 19EF
D 19FA 19FF
```

Require `TW STG` / `TW OK`. The staged `$19B0-$19EF` directory must match the
saved live `$FFB0-$FFEF` byte for byte. Stop on any mismatch.

Program only after that comparison passes:

```text
G 3000
P
WRITE
I
Q
D 1A00 1A03
D FFB0 FFEF
```

Require `TW PRG`, `TW OK`, status `01 AC 00 00`, and the unchanged directory.
Physical RESET, press `S` during the live dots, and require the new identity,
startup selector `0/1/2=BOOT H=HIMON S=STR8`, and command help:

```text
I H J0-3
```

Try `H`. An identified current HIMON must warm-enter; an older local HIMON
without the fixed `$C003-$C006` marker must print `NO HIMON` and remain in
STR8. In that case, use `J3` and let its reset path time out into the generic
local cold entry. Re-run the CRC fixture. Banks 0-2 and Bank-3 sectors 8-E must
match the starting table exactly. With the preserved starting directory from
this rail, Bank-3 sector F must change from `C9 3F` to `E5 A8`.

## 4. Install ASM-F2 into Bank 2 Range 8-B

At the new Bank-3 STR8 prompt enter one response at a time:

```text
I
2
8-B
Y
```

Because Bank 2 already has immutable metadata, STR8 must not ask for TYPE or
DESC. Require:

```text
I B2 8-B
T=A5 D=RYORS OK P=02 WRITE? Y: Y
SEND S19
```

Send exactly:

```text
SRC/BUILD/s19/str8-v1-i-asm-8-b.s19
```

Require four dots, `I OK`, and the STR8 prompt. Stop and record the complete
output and Bank-2 directory row on any other result.

At Bank-3 HIMON, require:

```text
FFD0: A5 FF FF FF 52 59 4F 52 53 FE FF FF C0 FF FF FF
```

Re-run the CRC fixture. Bank-2 sectors 8-B must equal the four CRC pairs printed
by the host build. Bank-2 sectors C-F, Banks 0-1, and Bank-3 sectors 8-E must
exactly match the starting table. Bank-3 sector F owns the directory and must
change to `32 64` when the Bank-2 journal advances from `F0` to `C0`.

Return to Bank-3 STR8 and issue `J2`. The preserved Bank-2 sector-F reset path
must still boot. Enter Bank-2 HIMON and run `ASM NEW`; the ASM-F2 identity must
match the candidate build. Exit without assembling, then physical RESET back
to Bank 3.

## 5. Install HIMON into Bank 2 Range C-E

At Bank-3 STR8:

```text
I
2
C-E
Y
```

Require:

```text
I B2 C-E
T=A5 D=RYORS OK P=03 WRITE? Y: Y
SEND S19
```

Send exactly:

```text
SRC/BUILD/s19/str8-v1-i-himon-c-e.s19
```

Require three dots, `I OK`, and the prompt. The final Bank-2 directory row must
be:

```text
FFD0: A5 FF FF FF 52 59 4F 52 53 FE FF FF 00 FF FF FF
```

Re-run the CRC fixture. Bank-2 sectors 8-B must retain the ASM CRCs, sectors
C-E must equal the three HIMON CRC pairs printed by the host build, and sector
F must exactly match the original starting CRC. Banks 0-1 and Bank-3 sectors
8-E must remain unchanged. Bank-3 sector F must change to `0D 67` when the
Bank-2 journal advances from `C0` to `00`.

Issue `J2`. The preserved old Bank-2 STR8 sector must boot, its timeout must
enter the newly installed HIMON identity, and `ASM NEW` must enter the newly
installed ASM-F2 identity. Exit without assembling and physical RESET. Bank 3
must return to the V1.02 identity and retain the final directory bytes above.

## Stop Conditions

Stop immediately and preserve the full serial transcript if:

- the initial directory or disposable-bank assumption differs;
- refresh staging does not preserve all 64 directory bytes;
- output reports `DIR BAD`, `I FAIL`, `DIR FAIL`, or lacks the exact dot count;
- a journal is STARTED rather than COMPLETE after an install;
- an unselected Bank-2 sector, Bank 0/1, or Bank-3 sector 8-E changes CRC;
- Bank-3 sector F does not match the directory-adjusted CRC at a checkpoint;
- `J2` fails, the preserved sector-F identity changes, or physical RESET does
  not return to Bank 3.

## Accepted `00.0807(2000)` Run

The 2026-08-07 FTDI/Tera Term run completed the full rail. Initial state was
Bank-3 STR8 `00.0806(2135)`, HIMON/ASM-F2 `00.0805(1312)`, and a COMPLETE
Bank-2 `A5/RYORS` record with journal `F0 FF FF FF`. The read-only fixture
returned `$1A00=$AC` and captured this baseline:

```text
B0  EC B7 36 70 CE 76 3A CB  A7 71 06 AD 5E 44 62 60
B1  EC B7 36 70 CE 76 A5 FC  A7 71 06 AD 39 AE 9B 41
B2  EC B7 36 70 CE 76 E3 4F  A7 71 06 AD 3C BA 09 D7
B3  EC B7 36 70 CE 76 A5 FC  A7 71 06 AD 39 AE C9 3F
```

The refresh source assembled through `$5000`, staged with `TW STG` / `TW OK`,
and preserved all 64 live directory bytes at `$19B0-$19EF`. Confirmed program
returned `TW PRG`, `TW OK`, and `01 AC 00 00`; installed face, vectors, and
directory matched the stage. Physical reset booted STR8 `00.0807(2000)`.
Local `H` rejected the older unmarked HIMON with `NO HIMON`; `J3` plus timeout
then cold-entered HIMON `00.0805(1312)`. The post-refresh CRC changed only
Bank-3 F, exactly to `E5 A8`.

The Bank-2 `8-B` transaction displayed existing `A5/RYORS`, pair `02`, printed
four dots and `I OK`, and completed its journal at `C0 FF FF FF`. Its CRC row
became:

```text
B2  EC B7 36 70 CE 76 63 D9  A7 71 06 AD 3C BA 09 D7
```

All unselected payload sectors matched baseline; Bank-3 F became the predicted
directory-adjusted `32 64`. `J2` booted preserved Bank-2 STR8 `00.0806(1927)`,
timed out into preserved HIMON `00.0806(1927)`, and `ASM NEW` entered newly
installed ASM-F2 `00.0807(2000)`.

The Bank-2 `C-E` transaction displayed pair `03`, printed three dots and
`I OK`, and completed the journal at `00 FF FF FF`. Final CRCs were:

```text
B2  EC B7 36 70 CE 76 63 D9  F2 56 F1 61 74 08 09 D7
B3  EC B7 36 70 CE 76 A5 FC  A7 71 06 AD 39 AE 0D 67
```

Banks 0-1, Bank-3 sectors 8-E, and Bank-2 sector F remained byte-identical.
`J2` again booted preserved STR8 `00.0806(1927)`, then timed out into newly
installed HIMON `00.0807(2000)`; `ASM NEW` entered ASM-F2 `00.0807(2000)`.
A final physical reset returned Bank-3 STR8 `00.0807(2000)`, cold-entered its
preserved HIMON `00.0805(1312)`, and retained the final directory.

This hardware-accepts the V1.02 parameterized dense receiver for independent
16K `8-B` and 12K `C-E` component transactions, exact dot counts, journal
progression, selected-sector contents, neighboring-sector preservation,
launch through a preserved sector F, and physical-reset recovery. Positive
local-`H` entry remains a separate proof because the installed Bank-3 HIMON
does not carry the required identity marker. Default combined-image promotion
also remains blocked on the HIMON AP-loader contract.
