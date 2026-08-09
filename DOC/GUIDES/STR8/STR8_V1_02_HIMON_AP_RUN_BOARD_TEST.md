# STR8 V1.02 Valid Bank-0 AP Run Board Test

Status: host-prepared; board pending. This is the final split-V1 HIMON banked-
AP promotion gate after the accepted read-only stage/restore rail.

The test builds a new 15-byte marker body with the board's ASM-F2, packages it
at RAM `$4000`, proves the same envelope from RAM, and only then uses the exact
worker carried by `str8-bank-maint` to overlay it into erased Bank 0 `$BF00`.
No archived `$F003` installer is used.

Pinned source identities:

```text
25DA127E49EB515D7651223D3E7E90D36A5C14F0E2A65093F473D3DCBF90F2AB  str8-bank-maint-2000.a
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
paste DOC/GUIDES/ASM/SAMPLES/str8-bank0-ap-smoke.a
SEAL> PACKAGE $4000
SEAL> .
AP $4000 $3000
D 4000 403F
D 5848 5850
```

Require `PKG OK @=$4000` with a high length byte of `$00` and a low length byte
from `$05` through `$FF`. The RAM AP must print `GO 3000`, return with `A=AC`
and carry set, leave `$5848=$AC` and `$5850=$5A`, and leave an `AP 01` envelope
at `$4000`. Stop before flash mutation if any check fails.

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

Reassemble and run the read-only all-bank CRC fixture. Require every pair to
match the frozen baseline except Bank-0 sector B. That one pair must change and
must repeat exactly on a second fresh CRC run. Preserve the package dump and
both CRC rows in the transcript so the new sector-B value can be pinned in the
acceptance commit.

Passing this card proves a freshly built valid AP envelope was stored in Bank
0, staged through `$F010/$0203`, loaded to RAM, executed, returned with its
normal result, and restored Bank 3. Only then may split V1 become the default
combined-image/documentation baseline.
