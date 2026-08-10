# STR8 V1.02 Valid Bank-0 AP Run Board Test

Status: hardware-accepted on 2026-08-08. This closes the final split-V1 HIMON
banked-AP promotion gate after the accepted read-only stage/restore rail.

The test builds a new 15-byte marker body with the board's ASM-F2, packages it
at RAM `$4000`, proves the same envelope from RAM, and only then uses the exact
worker carried by `str8-bank-maint` to overlay it into erased Bank 0 `$BF00`.
No archived `$F003` installer is used.

Pinned source identities:

```text
D3E50F9A2F005C437D9692ABA5F31D6B928C1CCB207CC2B3BEB602D50438E029  str8-bank-maint-2000.a
8B14202A376D3CD8484A0D39C7858A38206A226DA6F2503FCC418E922331439F  str8-bank0-ap-smoke.a
```

## Frozen Preconditions

Require STR8-N `00.0807(2000)` and marked Bank-3 HIMON `00.0807(2141)`. Before
building the package, rerun `str8-bank-crc-all-3000.a` and require `$1A00=$AC`
plus this accepted baseline:

```text
B0  EC B7 36 70 CE 76 3A CB  A7 71 06 AD 5E 44 62 60
B1  EC B7 36 70 CE 76 A5 FC  A7 71 06 AD 39 AE 9B 41
B2  EC B7 36 70 CE 76 63 D9  F2 56 F1 61 74 08 09 D7
B3  EC B7 36 70 CE 76 A5 FC  00 EA 5C 68 26 A0 04 4A
```

Stop if any pair differs. The only permitted flash change in this card is
Bank-0 sector B, and only the AP envelope beginning at `$BF00`.

## Build And Prove The RAM Envelope

Under Bank-3 HIMON, use a compatible local ASM-F2:

```text
ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/OLD/str8-bank0-ap-smoke.a
SEAL> PACKAGE $4000
SEAL> .
AP $4000 $3000
D 4000 4035
D 5848 5850
```

Require `PKG OK @=$4000 L=$0036` and this exact envelope:

```text
4000: 41 50 01 36 00 53 0B 01 | 00 20 0F 20 0F 00 09 F5
4010: 68 9F 52 01 00 45 09 01 | 09 00 00 04 71 51 80 57
4020: 49 02 00 02 42 0F 00 9C | 48 58 A9 5A 8D 50 58 A9
4030: AC 8D 48 58 38 60
```

The seal FNV is `$9F68F509`. The RAM AP must print `GO 3000`, return with
`A=AC` and carry set, and leave `$5848=$AC` and `$5850=$5A`. Stop before flash
mutation if any check fails.

Hardware result: accepted on 2026-08-08 with ASM-F2 `00.0805(1312)`. Assembly
ended at `$200F`; `PACKAGE $4000` reported `L=$0036`; all 54 envelope bytes
matched the rows above. RAM `AP $4000 $3000` printed `GO 3000`, returned
`A=AC` with `P=F5` (carry set), and left `$5848=$AC` / `$5850=$5A`. This
authorizes the fixed carrier step below; it does not itself authorize V1
promotion.

## Install The Fixed Carrier

The envelope at `$4000` survives the next ASM session. Assemble the maintained
utility and run only its fixed `P` path:

```text
ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/str8-bank-maint-2000.a
SEAL> .
G 2000
P
```

The tool stages Bank-0 sector B through the carried mode-`$06` worker. It must
print the following prompt only if every destination byte through the package
end is `$FF`:

```text
PUT AP B0 $BF00
TYPE PUT B0BF00>
```

Type exactly:

```text
PUT B0BF00
```

Require ` OK` and the next maintenance prompt. Any `ABORT`, `!`, missing
prompt, reset, or worker failure is a stop. Enter `Q` to return to HIMON.

## Run From Bank 0

Clear the two result markers, then exercise the migrated banked loader:

```text
M 5848
5848: AC 00
M 5850
5850: 5A 00
AP B0 $BF00 $3000
D 5848 5850
D 1900 193F
D FFE0 FFEF
```

Require `GO 3000`, return `A=AC` with carry set, `$5848=$AC`, and `$5850=$5A`.
The `$1900` dump must begin with the same envelope shown at RAM `$4000`; it is
the `$BF00` offset in the staged Bank-0 sector. `$FFE0-$FFEF` must still be the
accepted Bank-3 directory tail:

```text
FFE0: A5 FF FF FF 52 59 4F 52 | 53 FE 00 C0 FC FF FF FF
```

There must be no `APERR`, cold boot, or loss of the HIMON prompt.

## Final Isolation Check

Replacing 54 erased bytes at sector offset `$0F00` with the exact envelope has
CRC delta `$0D33`. Therefore Bank-0 sector B must move from `$CB3A` to `$C609`
and display as `09 C6`. Reassemble and run the read-only all-bank CRC fixture;
require `$1A00=$AC` and this exact table:

```text
B0  EC B7 36 70 CE 76 09 C6  A7 71 06 AD 5E 44 62 60
B1  EC B7 36 70 CE 76 A5 FC  A7 71 06 AD 39 AE 9B 41
B2  EC B7 36 70 CE 76 63 D9  F2 56 F1 61 74 08 09 D7
B3  EC B7 36 70 CE 76 A5 FC  00 EA 5C 68 26 A0 04 4A
```

Run the fixture a second time and require the same table. Preserve the package
dump and both CRC runs in the transcript.

## Accepted Hardware Result

ASM-F2 `00.0805(1312)` assembled the pinned maintenance source through worker
end `$322B` with `ASM OK`. The RAM envelope still began `41 50 01 36 00`.
Command `P` reached the erased-range prompt, accepted exact `PUT B0BF00`, and
returned `OK`; its following read-only `M` showed every ordinary sector used,
Bank-3 F protected, and the accepted Bank-3 directory.

After `Q`, HIMON cleared `$5848` and `$5850`. `AP B0 $BF00 $3000` printed
`GO 3000`, returned `A=AC` with `P=F5` and carry set, and left `$5848=$AC` /
`$5850=$5A`. The staged `$1900-$1935` bytes matched the entire `$0036`
envelope, and `$FFE0-$FFEF` remained:

```text
FFE0: A5 FF FF FF 52 59 4F 52 | 53 FE 00 C0 FC FF FF FF
```

Two actual `G 3000` CRC runs returned `$1A00=$AC` and reproduced the exact
post-write table above, including Bank-0 sector B `09 C6`. A dump taken after
assembling the CRC fixture but before its first `G 3000` contained stale
`00 00` in that pair and is not test evidence.

This accepted card proves a freshly built valid AP envelope was stored in Bank
0, staged through `$F010/$0203`, loaded to RAM, executed, returned with its
normal result, and restored Bank 3. Split V1 is now eligible to become the
default combined-image/documentation baseline.
