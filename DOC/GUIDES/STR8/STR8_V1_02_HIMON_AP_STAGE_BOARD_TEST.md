# STR8 V1.02 Bank-3 HIMON And AP-Stage Board Test

Status: hardware-accepted on 2026-08-08 as HIMON `00.0807(2141)` with the
preserved STR8-N `00.0807(2000)` sector F.

This focused follow-up uses the hardware-accepted STR8-N
`00.0807(2000)` range receiver to replace only Bank 3 `$C000-$EFFF` with
HIMON `00.0807(2141)`. It leaves the proven Bank-3 sector F resident, reset
vectors, and STR8 identity in place. The new HIMON removes its live `$F003`
dependency: banked AP staging now selects through `$F010`, copies one sector
from RAM, and restores Bank 3 through `$0203`.

The rail closes three focused gates:

1. a first Bank-3 directory record and three-sector `C-E` install;
2. positive shell and startup-selector `H` warm entry;
3. non-executing Bank-0 AP staging plus Bank-3 restoration.

The last gate intentionally uses source `$8001`, not a historical package
address. The staged bytes must fail the AP signature check with `$07` before
any body is copied or run. This proves the changed stage/restore path, but it
does **not** replace the later positive proof with a freshly installed, known
AP package.

Keep an external programmer and a known-good full-bank recovery image
available. Use only the already-qualified FTDI/Tera Term Send File path.

## 1. Frozen Candidate

Build from the repository root with the explicit visible stamp:

```text
make -C SRC str8-v1-range-proof-streams "HIMON_VISIBLE_STAMP=0807(2141)"
```

Use only this file on the board:

```text
SRC/BUILD/s19/str8-v1-i-himon-c-e.s19
```

Do not send the simultaneously built ASM `8-B` stream or a mutation-worker
file separately. The `I` stream already contains the complete `$0200-$042A`
mutation worker, followed by the dense `$C000-$EFFF` payload and its unique
S9 at `$C000`.

Pinned facts:

```text
HIMON visible identity                   00.0807(2141)
himon-str8-v1.bin SHA-256                4E3D15146158C67395856A26CBA70D43FD3255B258A3F5F209A607AB12634F68
str8-v1-payload-himon-c-e.s19 SHA-256    F214C06C473B1A7D160CD7B89EC213EEB596CEEF49315A86F22F2EE68245D4AF
str8-v1-i-himon-c-e.s19 SHA-256          1179AB7359969A8E8763CF6E551292429FB17750C53A868604DC32AD5AE54FB1
str8-mutation-worker-0200.s19 SHA-256     98ADC7FC5AF5E295FD88DDAD2FF2AC87E4A87ED0B6F1A246A183F6985E4FCE9C
mutation worker extent / identity        $0200-$042A / 49 57 01 FE
HIMON sector CRC low/high                 C:00 EA  D:5C 68  E:26 A0
HIMON fixed image marker at $C003         A5 5A C3 3C
```

Between the installed `00.0807(2000)` source and this follow-up, only HIMON
source changed; the STR8 and mutation-worker sources are unchanged. The range
build restamps unsent ASM/STR8 images, but this rail sends only HIMON `C-E`.

Host gates accepted for this candidate:

```text
HIMON banked AP check                     PASS; 11 cases; max 16486 steps
STR8 installer transaction check          PASS; max 542349 steps
STR8 split-worker size/identity check      PASS
```

## 2. Required Starting State

Start at Bank-3 STR8-N `00.0807(2000)`. Do not proceed if the banner or live
directory differs. At Bank-3 HIMON, require:

```text
>D FFB0 FFEF
FFB0: 53 FF FF FF 57 4C 50 49 | 49 FE FF FF F0 FF FF FF
FFC0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF
FFD0: A5 FF FF FF 52 59 4F 52 | 53 FE FF FF 00 FF FF FF
FFE0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF
```

Assemble and run the maintained read-only CRC fixture if its `$3000` image is
not already intact:

```text
ASM NEW
```

Send:

```text
DOC/GUIDES/ASM/SAMPLES/str8-bank-crc-all-3000.a
```

Exit ASM with `.`, then run and inspect:

```text
G 3000
D 1A00 1A04
D 1A10 1A4F
```

Require `$1A00=$AC` and this exact baseline:

```text
B0  EC B7 36 70 CE 76 3A CB  A7 71 06 AD 5E 44 62 60
B1  EC B7 36 70 CE 76 A5 FC  A7 71 06 AD 39 AE 9B 41
B2  EC B7 36 70 CE 76 63 D9  F2 56 F1 61 74 08 09 D7
B3  EC B7 36 70 CE 76 A5 FC  A7 71 06 AD 39 AE 0D 67
```

Return to Bank-3 STR8 with the confirmed `STR8` command. Stop if any starting
byte or CRC differs; do not reinterpret a different board state.

## 3. Install Bank-3 HIMON `C-E`

Enter one response at a time:

```text
STR8-N>I
I B0-3: 3
RANGE: C-E
TYPE: A5
DESC: RYORS
```

Require the complete summary before confirming:

```text
I B3 C-E
T=A5 D=RYORS NEW P=00 WRITE? Y:
```

Enter `Y`. At `SEND S19`, send exactly:

```text
SRC/BUILD/s19/str8-v1-i-himon-c-e.s19
```

Require exactly:

```text
...
I OK
STR8-N>
```

Stop immediately on a missing/extra sector dot, `I FAIL`, `DIR FAIL`, silence
after the file ends, or any reset. Preserve the complete serial transcript.

## 4. Prove The New HIMON And Directory

At the still-running Bank-3 STR8 prompt:

```text
H
```

Require the positive local warm path:

```text
BOOT WARM

HIMON V 00.0807(2141)
>
```

Read back the fixed marker and the newly sealed Bank-3 directory record:

```text
D C000 C00F
D FFE0 FFEF
```

Require:

```text
C000: 4C 07 C0 A5 5A C3 3C 78 | D8 A2 FF 9A AD E6 7E C9
FFE0: A5 FF FF FF 52 59 4F 52 | 53 FE 00 C0 FC FF FF FF
```

The directory publishes local entry `$C000`, seal `$FE`, and COMPLETE pair 0
`FC FF FF FF`. Re-run the CRC fixture:

```text
G 3000
D 1A00 1A04
D 1A10 1A4F
```

Banks 0-2 must remain exactly at baseline. Bank 3 must be:

```text
B3  EC B7 36 70 CE 76 A5 FC  00 EA 5C 68 26 A0 04 4A
```

`04 4A` is the predicted sector-F CRC after changing only the previously
erased Bank-3 directory row to the bytes above. The same CRC-delta calculation
reproduces the already observed Bank-2 journal transition from `32 64` to
`0D 67`.

## 5. Non-Executing Bank-0 Stage/Restore Smoke

This step is read-only. `$8001` deliberately points one byte into the known
Bank-0 ASM image rather than at an AP envelope:

```text
AP B0 $8001 $3000
```

Require:

```text
APERR=$07
>
```

There must be no `GO 3000`, `#GO#`, body output, reset, or loss of the prompt.
Immediately inspect the staged sector and the Bank-3 directory:

```text
D 0A00 0A0F
D FFE0 FFEF
```

Require:

```text
0A00: 46 4E D6 00 74 AD 56 05 | 0C 80 87 B9 20 7B 85 B0
FFE0: A5 FF FF FF 52 59 4F 52 | 53 FE 00 C0 FC FF FF FF
```

The first row proves that the containing Bank-0 sector was copied to the AP
tray. The second proves that the RAM body restored Bank 3 before returning to
flash-resident HIMON.

Run the still-intact CRC fixture once more:

```text
G 3000
D 1A00 1A04
D 1A10 1A4F
```

Require the exact post-install table from section 4. In particular, every
Bank-0 pair must remain at baseline.

## 6. Prove Startup `H` And Reset Recovery

From HIMON, enter the confirmed STR8 command:

```text
STR8
```

Answer `y` to its normal `RUN STR8` confirmation. During the startup dots,
press `H`. Require STR8-N `00.0807(2000)` followed by the same positive warm
entry into HIMON `00.0807(2141)`.

Finally perform a physical RESET, provide no selector input, and require the
preserved STR8 sector F to time out through the local cold path:

```text
STR8-N V 00.0807(2000) $F
...
BOOT COLD
RAM ZERO OK

HIMON V 00.0807(2141)
>
```

This final reset must not display STR8-N `00.0807(2141)`: only HIMON `C-E`
was installed.

## Accepted `00.0807(2141)` Run

The 2026-08-08 FTDI/Tera Term run began with the accepted Bank-3 STR8-N
`00.0807(2000)`, an empty Bank-3 directory row, and the previously captured
four-bank CRC baseline. The operator selected Bank 3 range `C-E`, entered
`A5/RYORS`, received the required `NEW P=00` summary, and sent the frozen
combined stream. STR8 printed three dots and `I OK`.

Shell `H` immediately printed `BOOT WARM` and entered
`HIMON V 00.0807(2141)`. Readback matched the fixed marker and completed
directory record exactly:

```text
C000: 4C 07 C0 A5 5A C3 3C 78 | D8 A2 FF 9A AD E6 7E C9
FFE0: A5 FF FF FF 52 59 4F 52 | 53 FE 00 C0 FC FF FF FF
```

The first post-install CRC fixture returned `$AC`. Banks 0-2 remained at
baseline; Bank 3 matched the three candidate sector CRCs and predicted
directory-adjusted sector-F CRC:

```text
B0  EC B7 36 70 CE 76 3A CB  A7 71 06 AD 5E 44 62 60
B1  EC B7 36 70 CE 76 A5 FC  A7 71 06 AD 39 AE 9B 41
B2  EC B7 36 70 CE 76 63 D9  F2 56 F1 61 74 08 09 D7
B3  EC B7 36 70 CE 76 A5 FC  00 EA 5C 68 26 A0 04 4A
```

The deliberately unaligned `AP B0 $8001 $3000` returned only `APERR=$07`.
There was no `GO`, body output, reset, or loss of the prompt. The tray held
the exact Bank-0 sector head, while the Bank-3 directory remained visible:

```text
0A00: 46 4E D6 00 74 AD 56 05 | 0C 80 87 B9 20 7B 85 B0
FFE0: A5 FF FF FF 52 59 4F 52 | 53 FE 00 C0 FC FF FF FF
```

Returning through the confirmed `STR8` command and pressing `H` during the
startup dots again produced `BOOT WARM` and HIMON `00.0807(2141)`. A physical
reset with no selector input retained STR8-N `00.0807(2000)`, then printed
`BOOT COLD`, `RAM ZERO OK`, and HIMON `00.0807(2141)`. Because that reset
correctly cleared RAM, the CRC fixture was assembled fresh and run one final
time. It returned `$AC` and reproduced all four rows above exactly.

This hardware-accepts the focused card: three-sector Bank-3 range install,
first local directory record, shell and startup positive `H`, preserved
sector-F reset/cold recovery, read-only Bank-0 staging, Bank-3 restoration,
and unchanged source-bank CRCs. A valid Bank-0 package load/run remains a
separate promotion gate.

## Stop Conditions And Evidence Boundary

Stop and preserve the full transcript if:

- the starting directory, identities, or CRC table differs;
- STR8 asks to use any pair other than `P=00` for the empty Bank-3 record;
- the install does not print exactly three dots and `I OK`;
- the directory is not exactly sealed with entry `$C000` and journal `FC`;
- any unselected sector changes, or Bank-3 F is not `04 4A`;
- either `H` route reports `NO HIMON` or enters an unexpected identity;
- `AP B0 $8001 $3000` returns anything except `$07`, executes a body, or
  fails to restore the exact Bank-3 directory view;
- the final physical reset does not retain STR8-N `00.0807(2000)` and cold
  enter HIMON `00.0807(2141)`.

Passing this card proves the new Bank-3 HIMON, both local `H` routes, and the
read-only banked AP stage/restore mechanism on hardware. It does not prove a
valid Bank-0 package load/run. The separate reviewed continuation is
[`STR8_V1_02_HIMON_AP_RUN_BOARD_TEST.md`](STR8_V1_02_HIMON_AP_RUN_BOARD_TEST.md);
do not promote V1 until that card is accepted.
