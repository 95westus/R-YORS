# STR8 0805 Board Test

This card starts from the reported board state:

```text
Bank 0 reset vector = FFFF
Bank 1 reset vector = FFFF
Bank 2 = STR8/HIMON 00.0802(1823)
Bank 3 = STR8/HIMON 00.0802(1823)
```

The required path installs only the new Bank-3 `$F000-$FFFF` STR8 sector and
then performs non-destructive tests. The optional sections overwrite or erase
Banks 0/1, and the final expert section erases Bank-3 `$8000-$EFFF`.

| Run | Scope | Stop point |
| --- | --- | --- |
| Required | Sections 1-6 | New STR8, selector, help, CRC, J2/J3 |
| Optional destructive | Section 7 | Deferred Bank-0/1 maintenance and J0/J1 |
| Expert destructive | Section 8 | Bank-3 ALL erase and full recovery |

## Files

Send a file only where a step explicitly says **Send file**.

All command blocks below are ordered input, not bulk-paste scripts. Enter one
line only after its prompt appears. During erase/program and S19 receive, wait
for the next prompt before sending anything else. Use Tera Term **Send File**
only for the named `.a` or `.s19` file.

| Use | Complete file name |
| --- | --- |
| Install historical STR8 top sector | `DOC/GUIDES/ASM/SAMPLES/OLD/str8n-topwrite-transient-3000.a` |
| Test `$F010/$0203` | `DOC/GUIDES/ASM/SAMPLES/OLD/str8-bank-select-service-proof-2000.a` |
| Historical read-only four-bank CRC | `DOC/GUIDES/ASM/SAMPLES/OLD/str8-bank-crc-all-3000.a` |
| Optional copy/erase tests | `DOC/GUIDES/ASM/SAMPLES/str8-bank-maint-2000.a` |
| Bank-3 payload recovery | `SRC/BUILD/s19/himon-str8-himon-update.s19` |
| Bank-3 ASM recovery | `SRC/BUILD/s19/asm-v1-flash-8000.s19` |
| External-programmer recovery | `SRC/BUILD/bin/himon-str8-rom.bin` |

Do not send `himon-str8-rom.bin` through HIMON or STR8. It is the external-
programmer recovery image.

## 1. Record the Starting State

At HIMON, paste:

```text
D F000 F013
D FFFA FFFF
D 1FFD 1FFF
```

Save all three dumps. Before installation, `$F000` is expected to begin
`4C 10 F0`, `$F00C-$F00F` should be `53 52 01 07`, and vectors must be
readable. The Bank Jump Record may contain the last valid bank; record it,
but do not require a particular value.

## 2. Install the New STR8 Top Sector

At HIMON:

```text
ASM NEW
```

**Send file:**

```text
DOC/GUIDES/ASM/SAMPLES/OLD/str8n-topwrite-transient-3000.a
```

Require:

```text
ASM OK
SEAL>
```

Paste:

```text
.
G 3000
```

Require the `TOPWRITER` menu. Paste:

```text
S
Q
```

Require:

```text
TW STG
TW OK
```

At HIMON, paste:

```text
D 0A00 0A13
D 140C 1443
```

Require the staged header:

```text
0A00: 4C 13 F0 4C 42 F3 4C 5E F3 4C 9C F4 53 52 01 07
0A10: 4C 49 F3 78
```

Require the staged banner/help bytes:

```text
140C: 0D 0A 53 54 52 38 2D 4E
1414: 20 56 20 30 30 2E 30 38
141C: 30 35 28 31 32 30 33 29
1424: 20 24 46 0D 8A 55 20 4A
142C: 30 20 4A 31 20 4A 32 20
1434: 4A 33 20 47 20 52 0D 8A
143C: 53 54 52 38 2D 4E BE 0D
```

These decode to `STR8-N V 00.0805(1203) $F`, help
`U J0 J1 J2 J3 G R`, and prompt `STR8-N>`.

Program only after every byte above matches. Paste:

```text
G 3000
P
WRITE
I
Q
D 1A00 1A03
D F000 F013
D FFFA FFFF
```

Require:

```text
TW PRG
TW OK
TW MODE=$01 RES=$AC @=$0000
1A00: 01 AC 00 00
F000: 4C 13 F0 4C 42 F3 4C 5E F3 4C 9C F4 53 52 01 07
F010: 4C 49 F3 78
FFFA: BD F0 00 F0 D1 F0
```

Stop on any other result. Do not retry `P` before recording `$1A00-$1A03`.

## 3. Banner and Implicit-Help Test

Press physical RESET. At the selector press `S`.

Require:

```text
STR8-N V 00.0805(1203) $F
U J0 J1 J2 J3 G R
STR8-N>
```

There must be no `ROM $F000` line and no `?` in the help line.

At `STR8-N>`, enter these separately:

```text
?
x
```

Each must print:

```text
U J0 J1 J2 J3 G R
STR8-N>
```

The lowercase `x` must echo as uppercase `X`. `?` is now an unmatched input,
not an identity command.

Return to HIMON:

```text
G
```

Require `G HIMON`, `BOOT WARM`, and a HIMON prompt.

## 4. Published Bank-Selector Test

At HIMON:

```text
ASM NEW
```

**Send file:**

```text
DOC/GUIDES/ASM/SAMPLES/OLD/str8-bank-select-service-proof-2000.a
```

Require no `ERR=` anywhere in the assembly transcript, followed by `ASM OK`.
An ending `ASM OK` does not clear an earlier line error. Then enter:

```text
.
G 2000
D 1A20 1A47
D 0200 0211
```

Require `RET A=AC` with carry set. Require:

```text
physical-reset path:
1A20: 42 53 AC 00 00 01 04 00

or after an explicit software selection of Bank 3:
1A20: 42 53 AC 00 EE 01 04 00

1A28: 00 CC -- -- -- -- -- --
1A30: 01 CE -- -- -- -- -- --
1A38: 02 EC 4C 53 52 01 07 78
1A40: 03 EE 4C 53 52 01 07 4C

0200: 4C 12 02 08 78 C9 04 B0 06 20 7C 04 28 38 60 28
0210: 18 60
```

`--` means informational bank content; do not require it. `$1A24` is also
informational: it is normally `$00` after hardware reset forced Bank 3 and may
be `$EE` after an explicit software selection of Bank 3. The exact row PCR
bytes `CC/CE/EC/EE`, status `$AC`, Bank-2 old `$F010=$78`, and Bank-3 new
`$F010=$4C` are required. This proves:

```text
JSR $F010  rejects Bank 4 without changing Bank 3
JSR $F010  selects Bank 0 and installs the RAM trampoline
JSR $0203  selects Banks 1, 2, and 3 without target-bank STR8 code
```

No flash byte is written by this test.

## 5. Read-Only CRC Baseline

Dump Section 4 before this step because the CRC fixture reuses `$1A20`.

At HIMON:

```text
ASM NEW
```

**Send file:**

```text
DOC/GUIDES/ASM/SAMPLES/OLD/str8-bank-crc-all-3000.a
```

Stop on any `ERR=` line and do not run the partial image. Require `ASM OK`,
then paste:

```text
.
G 3000
D 1A00 1A0B
D 1A10 1A4F
```

Require `$1A00=$AC`. Save all CRC rows. This test is read-only.

## 6. Current-Bank J and Bank Jump Record

### 6.1 Invalid J0/J1 must not change the record

At HIMON:

```text
D 1FFD 1FFF
STR8
y
```

At the selector press `S`. At STR8 paste:

```text
J0
J1
G
```

Require both failures:

```text
JERR B0 V=$FFFF
JERR B1 V=$FFFF
```

At HIMON:

```text
D 1FFD 1FFF
```

The three bytes must equal the dump taken immediately before `J0`.

### 6.2 Positive J2 and cold preservation

Enter STR8, press `S`, and paste:

```text
J2
```

Let Bank 2 time out into HIMON. Paste:

```text
D 1FFD 1FFF
HCOLD
y
D 1FFD 1FFF
```

Both dumps must be:

```text
1FFD: 42 4A 02
```

Press physical RESET to return to Bank 3.

### 6.3 Positive J3 from Bank 2

Enter Bank-3 STR8, press `S`, and enter `J2`. During the Bank-2 selector press
`S`; at the Bank-2 STR8 prompt paste:

```text
J3
```

Let Bank 3 time out into HIMON. Paste:

```text
D 1FFD 1FFF
HCOLD
y
D 1FFD 1FFF
```

Both dumps must be:

```text
1FFD: 42 4A 03
```

### 6.4 CRC no-write proof

`HCOLD` cleared RAM, including `$3000`; reassemble the CRC fixture. At HIMON:

```text
ASM NEW
```

**Send file:**

```text
DOC/GUIDES/ASM/SAMPLES/OLD/str8-bank-crc-all-3000.a
```

Require `ASM OK`, then enter:

```text
.
G 3000
D 1A00 1A0B
D 1A10 1A4F
```

All CRC bytes must exactly match the Section-5 baseline.

## 7. Optional Destructive Completion: Banks 0 and 1

Run this section only if Banks 0 and 1 may be overwritten. It closes the
previously deferred maintenance inputs and positive J0/J1 record cases.

At HIMON:

```text
ASM NEW
```

**Send file:**

```text
DOC/GUIDES/ASM/SAMPLES/str8-bank-maint-2000.a
```

Require zero `ERR=` lines anywhere in the assembly transcript and a final
`ASM OK`. An ending prompt or partial menu is not acceptance. Then paste:

```text
.
G 2000
M
```

Require a blank line after the bank heading, four complete map rows, then the
`E/U/P` legend. Require `P` at Bank-3 sector F and directory rows `D0-D3`
under `DIR B T DESC ENTRY JOURNAL`.

Test every empty-input position without writing. Each blank reply below means
press Enter at that named prompt and require `ABORT` followed by the menu:

| Path | Ordered input |
| --- | --- |
| Empty operation | blank at `>` |
| Empty copy source | `C`, blank at `SOURCE BANK 0-3>` |
| Empty copy destination | `C`, `3`, blank at `DEST BANK 0-2>` |
| Empty copy confirmation | `C`, `3`, `0`, blank at `TYPE COPY 30>` |
| Empty erase bank | `E`, blank at `BANK 0-3>` |
| Empty erase sector | `E`, `0`, blank at `SECTOR...>` |
| Empty erase confirmation | `E`, `0`, `8`, blank at `TYPE ERASE 08>` |

Test a wrong exact confirmation. Enter one line after each prompt:

```text
E
0
8
NO
```

Require `ABORT`, no erase dots, and the menu. Test protected Bank-3 sector F:

```text
E
3
F
```

Require another `SECTOR...` prompt because `F` is invalid for Bank 3. Press
Enter there; require `ABORT`, no erase dots, and the menu.

Test the ordinary failure/menu path while Bank 0 still has reset vector
`$FFFF`:

```text
C
0
1
```

Require `!` and the menu without a `TYPE COPY 01>` prompt, copy dots, or flash
write. This is the safe `$E6` bad-source-vector failure. Worker `$E1/$E2`
failures require an injected hardware fault and are not forced on a healthy
board.

Create a used Bank 0, then test single, repeated-erased, range, and ALL:

```text
C
3
0
COPY 30
E
0
8
ERASE 08
E
0
8
ERASE 08
E
0
9-B
ERASE 09-B
E
0
ALL
ERASE 0ALL
M
```

Require `OK` for each accepted operation and `B0 E E E E E E E E` afterward.

Repopulate Banks 0 and 1 for positive J tests:

```text
C
3
0
COPY 30
C
3
1
COPY 31
M
Q
```

Require eight dots plus `OK` for each copy. The map should show all sectors
used in Banks 0 and 1 and `P` at B3F. At HIMON:

```text
D 1B00 1B0C
```

Require `$1B00=$AC`, `$1B01=$51` (`Q`), and `$1B0C=$EE` when the utility was
entered from Bank 3.

Now perform the Section-6.2 procedure with `J0` and then `J1`, requiring:

```text
after J0 and HCOLD: 1FFD: 42 4A 00
after J1 and HCOLD: 1FFD: 42 4A 01
```

Use physical RESET between banks. This completes the positive J0-J3 record
matrix. CRC changes are expected because Banks 0 and 1 were intentionally
written.

## 8. Expert-Only Bank-3 ALL Test

This closes the deferred `ALL` spelling for Bank 3, but deliberately erases
ASM and HIMON in `$8000-$EFFF`. Do not run it merely to test `$F010` or help.

Before proceeding, require these files to exist and retain the external BIN:

```text
SRC/BUILD/s19/himon-str8-himon-update.s19
SRC/BUILD/s19/asm-v1-flash-8000.s19
SRC/BUILD/bin/himon-str8-rom.bin
```

The cold-boot tests cleared the old RAM utility. At HIMON enter:

```text
ASM NEW
```

**Send file:**

```text
DOC/GUIDES/ASM/SAMPLES/str8-bank-maint-2000.a
```

Require zero `ERR=` lines anywhere in the assembly transcript and a final
`ASM OK`. Do not run a partial image. Then enter:

```text
.
G 2000
```

At the maintenance prompts enter:

```text
E
3
ALL
ERASE 3ALL
```

It must return directly to STR8. Press `S`, then at STR8 enter:

```text
U
Y
```

At `SEND S19 C000-EFFF`, **send file**:

```text
SRC/BUILD/s19/himon-str8-himon-update.s19
```

At `PROGRAM C000-EFFF? Y:`, enter:

```text
Y
G
```

At HIMON enter:

```text
L F
```

**Send file:**

```text
SRC/BUILD/s19/asm-v1-flash-8000.s19
```

Require `LF OK` and `GO=800C`. Finally paste:

```text
D F000 F013
D FFFA FFFF
```

The header and vectors must still match Section 2; Bank-3 sector F was
protected. Re-run the maintenance `M` command and require B3 sectors 8-E used
and B3F protected.

## Deferred V1 Tests That Must Not Be Run Yet

The following have host proofs but no flashable V1 migration artifact:

```text
I metadata/directory preview
$FFB0-$FFEF one-to-zero directory writer
V1 buffered Backspace/Delete/CR/LF command editor
dense I S19 receive/staging
I erase/program/journal transaction
```

Do not install `BUILD/bin/himon-str8-v1-layout-preview.bin`. It is explicitly
non-flashable. These tests resume only after the migration artifact and its
separate board card exist.

## Recorded 2026-08-05 Result

Sections 1-6 passed the installed selector, implicit help, exact RAM worker,
J2/J3 handoff, and unchanged four-bank CRC gates. The follow-up captured J3
and J2 across `HCOLD`. Section 7 passed every empty-input and confirmation
abort, protected B3F rejection, safe bad-vector failure, Bank-0 single,
repeated-erased, range, and ALL erase, Bank-3 copies to Banks 0/1, final map,
and `Q`. J0/J1 launched and published banks 0/1, but their post-`HCOLD` dumps
were omitted; J0 still needs one repeat, while the current retained record can
close J1.

Section 8 passed Bank-3 ALL twice, direct protected-STR8 return, two `U`
recoveries, `L F`, exact top-sector/vector retention, and a final all-used map
with B3F protected. V1-only tests below this boundary remain deferred by
design, not failed.
