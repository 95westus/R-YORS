# DC/FWD/Import Data Board Test

Purpose: one combined ASM-F2 board proof for `DC C/HB/P`, forward `DB/DW`,
and imported `DB/DW` data constants through the AP package/link path.

The default flow stores an AP package in bank 2 at `$9000` using the existing
`bankput-transient-3000.a` helper. A bank 0 variant follows for a persistent flash proof;
use it only when the selected bank 0 sector is intentionally erased or reserved.

## 1. Build The AP Package

At the HIMON prompt:

```text
ASM NEW
```

Paste:

```text
DOC/GUIDES/ASM/SAMPLES/dc-forward-import-data-2000.a
```

Expected:

```text
ASM OK
SEAL>
```

Package it in RAM:

```text
PACKAGE $3200
.
D 3200 323F
```

Expected:

```text
PKG OK @=$3200 L=$hhhh
ASM BYE
3200: 41 50 01 ...
```

Record the printed package length. The exact length may move as metadata grows.

## 2. Store The Package In Bank 2

At the HIMON prompt:

```text
ASM NEW
```

Paste:

```text
DOC/GUIDES/ASM/SAMPLES/bankput-transient-3000.a
```

Expected:

```text
ASM OK
SEAL>
```

Run the helper:

```text
.
G 3000
D 1A00 1A02
```

Expected:

```text
ASM BYE
RET A=AC ...
1A00: AC ll hh
```

`ll hh` is the package length copied from `$3200`.

## 3. Run The Banked AP Package

```text
AP B2 $9000 $3000
D 5848 5850
D 3000 3020
D 7E2D 40
```

Expected result bytes:

```text
5848: AC 00 ii jj 16 30 00 00 | 5A
```

Meaning:

```text
$5848 = AC       all runtime checks passed
$584A/$584B      resolved BIO_FTDI_PUT_CSTR import address = jjii
$584C/$584D      relocated FWD label address = $3016
$5850 = 5A       DC C/HB/P byte check passed
```

Expected loaded body head at `$3000`:

```text
3000: 80 15 16 30 16 30 16 30 | 4F 4B 00 4F CB 02 4F 4B
3010: ii jj ii jj ii jj 60 ...
```

The `$3002-$3007` bytes prove forward `DB FWD,<FWD,>FWD` and `DW FWD` patched
to relocated label `$3016`. The `$3008-$300F` bytes prove `DC C`, `DC HB`, and
`DC P`. The `$3010-$3015` bytes must mirror `$584A/$584B`, proving imported
`DB` and `DW` data constants were linked through relocation rows `$04/$05/$06`.

The `$7E2D` dump is the AP service/result block. Keep it in the transcript when
capturing the proof.

## Bank 0 Variant

Bank 0 is OK for this combined proof when the target sector is intentionally
available. This path writes persistent bank 0 flash, so do not use it for a
quick smoke unless that sector has been reserved for AP package storage.

For bank 0, package the AP envelope at `$3000`; the one-run installer then
replaces the BODY source at `$2000` and preserves the envelope.

Build the same AP package at `$3000`:

```text
ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/dc-forward-import-data-2000.a
PACKAGE $3000
.
D 3000 303F
```

Expected:

```text
PKG OK @=$3000 L=$hhhh
ASM BYE
3000: 41 50 01 ...
```

Record the package length. Keep `$3000-$3FFF` untouched until the one-run
installer has returned.

Store the bank 0 sector, using explicit `$9000` here:

```text
ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/bank0ap-put-transient-2000.a
.
G 2000
DST $8000-$FFFF OR ENTER=AUTO> $9000
TYPE YES TO WRITE> YES
D 1A00 1A06
```

Expected:

```text
B0 AP PUT
PKG L=$hhhh
STAGE OK
B0 AP @$9000 L=$hhhh
PROGRAM OK
B0 AP @$9000 L=$hhhh
RET A=AC ...
1A00: AC 00 90 ll hh 90 00
```

`$1A06` is cleared after the installer returns, preventing an accidental
repeat write.

Run the bank 0 package:

```text
AP B0 $9000 $3000
D 5848 5850
D 3000 3020
D 7E2D 40
```

The expected result bytes are the same as the bank 2 run:

```text
5848: AC 00 ii jj 16 30 00 00 | 5A
3000: 80 15 16 30 16 30 16 30 | 4F 4B 00 4F CB 02 4F 4B
3010: ii jj ii jj ii jj 60 ...
```

## Current Board Diagnostic

Observed attached transcript:

```text
B0 AP STAGE
PKG L=$00F6
DST $8000-$FFFF OR ENTER=AUTO>
STAGE OK
STAGED B0 AP @$86D7 L=$00F6
...
B0 AP COMMIT
B0 AP @$86D7 L=$00F6
PROGRAM OK
B0 AP @$86D7 L=$00F6
...
>AP B0 $86D7 $3000
APERR=$09
```

Interpretation: bank 0 stage/commit passed, but the combined package did not
load. `APERR=$09` is HIMON AP `BAD_FIX`, so this is currently an import-link or
relocation-table diagnostic, not a bank 0 flash-write failure. Do not count this
as the imported `DB/DW` data proof yet.

Before running another stage/load command, capture the failed package state:

```text
D 7E2D 40
D 10D7 FF
```

For the `$86D7` source address, `$10D7` is the staged-sector copy address used
by `AP B0 $86D7 $3000`. The first dump should show AP status `$09`; the second
captures the AP envelope header, relocation table, import record, and body head.

## Split Isolation Fixture

Use this RAM-only AP run to prove `DC C/HB/P` plus forward `DB/DW` without any
import relocation rows:

```text
ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/dc-forward-2000.a
PACKAGE $3200
.
AP $3200 $3000
D 5848 5850
D 3000 3020
D 7E2D 40
```

Expected:

```text
GO 3000
RET A=AC ...
5848: AC 00 00 00 10 30 00 00 | 5A
3000: 80 0F 10 30 10 30 10 30 | 4F 4B 00 4F CB 02 4F 4B
3010: 60 ...
```

If this passes while the combined fixture still returns `APERR=$09`, the
remaining board work is narrowed to imported data relocation/link handling.

## Import Linker Isolation Fixtures

The current STR8-N top sector should begin:

```text
F000: 4C 09 F0 4C 93 F3 4C 9A | F3
```

If that matches, isolate the import linker with the already-proven code-import
fixture:

```text
ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/OLD CODE/banked-rjoin-smoke.a
PACKAGE $3200
.
AP $3200 $3000
D 5848 5850
D 3000 3020
D 7E2D 40
```

If that passes, isolate imported data constants without `DC` or forward labels:

```text
ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/import-data-2000.a
PACKAGE $3200
.
AP $3200 $3000
D 5848 5850
D 3000 3020
D 7E2D 40
```

This fixture is intentionally fixed to the `$3000` AP load destination: its
runtime checker reads `$3002-$3007` literally so the AP package isolates the
imported data relocation rows without adding internal label relocations.

Expected pass shape:

```text
GO 3000
RET A=AC ...
5848: AC 00 ii jj ...
3000: 80 nn ii jj ii jj ii jj ...
7E2D: ... status 00 ... RELOCS=04 IMPORTS=01 ...
```

Here `ii jj` is the resolved `BIO_FTDI_PUT_CSTR` address in little-endian
order. A fresh `APERR=$09` on this fixed-destination fixture means the
remaining bug is specific to imported `DB/DW` data relocation/link handling.

Current board result: pass with `RET A=AC`, `$5848=$AC`, `$3002-$3007 =
79 E7 79 E7 79 E7`, and AP service `status=$00`, `RELOCS=$04`, `IMPORTS=$01`.
Imported `DB/DW` data constants are hardware-proven by this split fixture.

If this fixture passes, rerun the full combined fixture directly from RAM before
returning to bank 0 storage:

```text
ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/dc-forward-import-data-2000.a
PACKAGE $3200
.
AP $3200 $3000
D 5848 5850
D 3000 3020
D 7E2D 40
```

If the RAM combined run fails with `APERR=$09`, capture the relocation tail
before repackaging anything else:

```text
D 3030 3078
D 3214 3268
```

The first dump shows how far the loaded body was internally relocated. The
second captures the combined package relocation record at the current RAM
package address. A RAM combined failure means the open case is the larger mixed
relocation table rather than banked/bank 0 source storage.

Current board result on the unpatched HIMON loader: combined RAM fails with
`APERR=$09`. Rows 0-7 of the internal table patch, imports patch, but row 8
(`CMP DCEXP,X`, site `$005B`, target `$006F`) remains `DD 6F 20` instead of
`DD 6F 30`. The scratch dump showed `HIM_AP_TMP2_LO=$1E`, proving
`HIM_AP_RELOC_SITE_OK_X` was using the helper-clobbered `RELOC_COUNT*2` offset
as the abs16 width addend. Retest this combined fixture after updating to a
HIMON image that preserves the 0/1 addend across the row-access helpers.

Current board result on the fixed HIMON loader: pass. `HIMON V 00.0711(2117)`
with ASM-F2 reloaded by `L F` ran this package through AP with `RET A=AC`,
`$5848=$AC`, `$584A/$584B=$E775`, `$584C/$584D=$3016`, `$5850=$5A`,
`AP status=$00`, and row 8 relocated as `DD 6F 30`.

After pasting the source, do not use plain `G 3000` as the retest. A stale body
at `$3000` can appear to pass after the source has been assembled at `$2000`,
because the failed row-8 operand still points at source-side `DCEXP` near
`$206F`. The proof must be:

```text
PACKAGE $3200
.
AP $3200 $3000
```
