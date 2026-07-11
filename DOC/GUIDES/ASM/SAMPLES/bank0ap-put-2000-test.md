# Bank 0 AP Put Board Test

Purpose: prove the split bank 0 AP installer from an ASM prompt. This is a
destructive bank 0 flash write. Use it only when bank 0 is intentionally
available for AP package storage and you have accepted the recovery path.

The flow is deliberately split:

```text
bank0ap-stage-2000.a     stages the bank 0 sector and overlays the AP
bank0ap-commit-2000.a    confirms YES and programs the staged sector
```

The flash ASM user/package RAM is split into three 4K roles:

```text
$2000-$2FFF  ASM body/helper emission island
$3000-$3FFF  AP overlay/load/run destination
$4000-$4FFF  AP envelope buffer, max package length $1000
```

For this flow, always use `PACKAGE $4000`. Do not use `PACKAGE $2000`: the
stage and commit helpers emit at `$2000`, so they overwrite anything packaged
there, and the stage helper only reads an AP envelope from `$4000`.

If a source body or AP envelope grows toward the edge of its 4K island, split
it instead of letting it cross into the next role.

This script uses `bank0ap-print-smoke.a` because it prints from the AP body
itself, then leaves stable proof bytes: `$5848=$AC` and `$5850=$5A`.
`$584A/$584B` records the resolved resident `BIO_FTDI_PUT_CSTR` address.

## Precondition

Start at a fresh ASM-F2 prompt:

```text
ASM-F2
ASM>$2000:
```

Bank 0 must contain an erased destination range. The explicit-address path
below uses bank 0 `$8000`; stop if you have not intentionally erased or
reserved that range.

If bank 0 `$8000-$8FFF` is not already erased, erase bank 0 sector 8 first:

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/flash-erase-bank.a
SEAL> .
>G 3000
BANK 0-3> 0
SECTOR 8-F OR ALL> 8
TYPE YES TO ERASE> YES
```

Expected:

```text
OK
BANK 0 ERASE COMPLETE
RET A=AC ...
```

## 1. Build The AP Envelope

Paste:

```text
DOC/GUIDES/ASM/SAMPLES/bank0ap-print-smoke.a
```

Expected:

```text
ASM>$2032:         END
ASM OK
SEAL>
```

Package it in RAM:

```text
SEAL> PACKAGE $4000
```

Expected:

```text
PKG OK @=$4000 L=$007F
```

Verify the AP envelope header:

```text
SEAL> .
ASM BYE
>D 4000 F
```

Expected:

```text
4000: 41 50 01 7F 00 53 0B 01 | 00 20 32 20 32 00 ...
```

The first five bytes are signature `41 50`, AP version `01`, and package
length `7F 00` for printed length `$007F`. Keep `$4000` untouched until the
stage piece finishes. Do not run `LOAD`, `AP`, or another `PACKAGE` yet.

Do not paste the stage source while the prompt still says `SEAL>`. Exit with
`.` first. If `ASM NEW` is typed at `SEAL>`, the board reports `ERR=$03 BO`;
restart the stage paste from a normal HIMON `>` prompt.

## 2. Stage The Bank 0 Sector

```text
>ASM NEW
```

Paste:

```text
DOC/GUIDES/ASM/SAMPLES/bank0ap-stage-2000.a
```

Expected assembly shape:

```text
ASM>$2000: RUN     STZ STAT
ASM>$2003:         STZ DSTLO
...
ASM OK
SEAL>
```

No `ERR=` rows should appear during the paste. If any line reports an error,
stop and restart this piece with the current source.

Current static sizing puts the stage helper end around `$2355`, leaving roughly
`$0CAB` bytes before the `$3000` overlay boundary.

Exit to HIMON. Do not package the stage tool:

```text
SEAL> .
ASM BYE
```

Run the stage piece and choose bank 0 `$8000`:

```text
>G 2000
```

Expected interaction:

```text
B0 AP STAGE
PKG L=$007F
DST $8000-$FFFF OR ENTER=AUTO> $8000
STAGE OK
STAGED B0 AP @$8000 L=$007F

#GO# ENTRY=2000
RET A=AC ...
```

Verify stage status:

```text
>D 1A00 1A06
```

Expected:

```text
1A00: AC 00 80 7F 00 80 5A
```

Meaning:

```text
$1A00 = AC       stage ready
$1A01/$1A02      selected package address = $8000
$1A03/$1A04      AP package length = $007F
$1A05            selected sector high byte = $80
$1A06 = 5A       commit-ready mark
```

For explicit `$8000`, the AP overlay starts at staged sector offset zero:

```text
>D A00 F
```

Expected:

```text
0A00: 41 50 01 7F 00 53 0B 01 | 00 20 32 20 32 00 ...
```

## 3. Commit The Staged Sector

Do not cold boot, run STR8, or run banked `AP` between the stage and commit
pieces; `$0A00-$19FF` must remain the staged sector.

```text
>ASM NEW
```

Paste:

```text
DOC/GUIDES/ASM/SAMPLES/bank0ap-commit-2000.a
```

Expected:

```text
ASM OK
SEAL>
```

No `ERR=` rows should appear during the paste. If any line reports an error,
stop and restart this piece with the current source.

Exit to HIMON. Do not package the commit tool:

```text
SEAL> .
ASM BYE
```

Run the commit piece:

```text
>G 2000
```

Expected interaction:

```text
B0 AP COMMIT
B0 AP @$8000 L=$007F
TYPE YES TO WRITE> YES
PROGRAM OK
B0 AP @$8000 L=$007F

#GO# ENTRY=2000
RET A=AC ...
```

Verify final status:

```text
>D 1A00 1A06
```

Expected:

```text
1A00: AC 00 80 7F 00 80 00
```

`$1A06` is cleared after a successful program to prevent an accidental repeat
commit.

## 4. Run The Stored AP Package

```text
>AP B0 $8000 $3000
```

Expected:

```text
GO 3000

B0 AP RUN

#GO# ENTRY=3000
RET A=AC ...
```

Verify the runtime oracle:

```text
>D 5848 5850
```

Expected:

```text
5848: AC xx ll hh xx xx xx xx | 5A
```

Pass if the AP prints `B0 AP RUN`, `$5848=$AC`, `$5850=$5A`, and
`$584A/$584B` is the resolved resident `BIO_FTDI_PUT_CSTR` address. The bytes
shown as `xx` are not owned by this smoke program and may preserve prior RAM
contents.

If bank 0 is erased after this install, `AP B0 $8000 $3000` must fail with
`APERR=$07` until the AP package is staged and committed again.

## Optional Destination Checks

After the main `$3000` run passes, the same installed package can also be run
at nearby RAM destinations:

```text
>AP B0 $8000 $3200
expect GO 3200, B0 AP RUN, then RET A=AC

>AP B0 $8000 $3400
expect GO 3400, B0 AP RUN, then RET A=AC
```

Hardware also passed with destination `$2000`, but that overwrites the
helper/source island. Use it only as a final proof after you are done staging
and committing:

```text
>AP B0 $8000 $2000
expect GO 2000, B0 AP RUN, then RET A=AC
```

## Auto Address Variant

Use this only on a separate run where bank 0 still has an erased hole large
enough for the package. Rebuild the AP envelope at `$4000`, paste the stage
piece, and run `G 2000` as above. At the destination prompt, press Enter:

```text
DST $8000-$FFFF OR ENTER=AUTO>
```

Expected stage result:

```text
STAGE OK
STAGED B0 AP @$hhhh L=$007F
RET A=AC ...
```

Then paste and run the commit piece:

```text
B0 AP COMMIT
B0 AP @$hhhh L=$007F
TYPE YES TO WRITE> YES
PROGRAM OK
B0 AP @$hhhh L=$007F
RET A=AC ...
```

Use the printed address:

```text
>AP B0 $hhhh $3000
expect B0 AP RUN, then RET A=AC

>D 5848 5850
expect 5848: AC ... ll hh ... | 5A
```

If no erased bank 0 hole fits, expected stage status is `$1A00=$E3`.

## ASM Session Reporter Auto-Hole Variant

Use this when the goal is specifically to store
`asm-session-report-4800.a` in the first available bank 0 hole. The AP
envelope still belongs at `$4000` while staging; bank 0 storage is selected
later by pressing Enter at the stage prompt.

Build the reporter AP envelope:

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/asm-session-report-4800.a
END
SEAL> PACKAGE $4000
PKG OK @=$4000 L=$0658
SEAL> .
ASM BYE
```

Stage to the first erased bank 0 hole:

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/bank0ap-stage-2000.a
END
SEAL> .
ASM BYE
>G 2000
B0 AP STAGE
PKG L=$0658
DST $8000-$FFFF OR ENTER=AUTO>
```

At `ENTER=AUTO>`, press Enter. Expected:

```text
STAGE OK
STAGED B0 AP @$hhhh L=$0658
RET A=AC ...
```

If bank 0 is fully erased, `$hhhh` should be `$8000`. If an earlier AP package
already occupies the start of bank 0, `$hhhh` should be the first later erased
run large enough for `$0658` bytes.

Commit the staged sector:

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/bank0ap-commit-2000.a
END
SEAL> .
ASM BYE
>G 2000
B0 AP COMMIT
B0 AP @$hhhh L=$0658
TYPE YES TO WRITE> YES
PROGRAM OK
B0 AP @$hhhh L=$0658
RET A=AC ...
```

Run the stored reporter from bank 0:

```text
>AP B0 $hhhh $4800
```

Expected:

```text
GO 4800
ASM REPORT
...
ASM REPORT OK
RET ...
```

The reporter inspects the current ASM session tables. Immediately after the
commit step, that usually means it reports the commit helper session. To report
a later ASM session, leave that later session with `.`, then run the same
`AP B0 $hhhh $4800` command.

Hardware proof: with the `$8000-$807E` print-smoke package still present, this
variant selected `$807F`, committed `L=$0658`, and `AP B0 $807F $4800` printed
`ASM REPORT OK`. In a fully erased bank 0, expect `$8000` instead.

## Negative Checks

Commit abort path:

```text
TYPE YES TO WRITE>
```

Expected:

```text
ABORT - NO FLASH WRITE
RET A=E0 ...
```

After abort, `$1A06` remains `$5A`, so the same staged sector can still be
committed by rerunning the commit piece and typing `YES`.

Occupied destination path during stage:

```text
DST $8000-$FFFF OR ENTER=AUTO> $8000
```

Expected after `$8000` already contains the package:

```text
FAIL $1A00=$E5
RET A=E5 ...
```

Bad package path during stage:

```text
>ASM NEW
paste bank0ap-stage-2000.a without rebuilding PACKAGE $4000 first
>G 2000
```

Expected if `$4000` no longer starts with a valid `AP` envelope:

```text
FAIL $1A00=$E1
RET A=E1 ...
```

The same `$E1` is expected if the AP was packaged at `$2000` instead of
`$4000`. In that case the stage source also overwrites the `$2000` package
body while assembling.

No staged write path during commit:

```text
>ASM NEW
paste bank0ap-commit-2000.a without running the stage piece first
>G 2000
```

Expected:

```text
FAIL $1A00=$E7
RET A=E7 ...
```
