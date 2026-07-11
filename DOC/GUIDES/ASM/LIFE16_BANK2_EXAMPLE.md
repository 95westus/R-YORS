# ASM-F2 16x16 Life Bank 2 Example

Status: partial board evidence captured 2026-07-10. ASM-F2 assembled the Life
source, `PACKAGE $3200` produced `L=$01DE`, and the bank-sector writer returned
`$1A00=$AC`. The final AP run still needs a corrected-address retry.

This example assembles a small Conway Life program with ASM-F2, packages it as
an AP envelope, stores that envelope in flash bank 2 at `$9000`, then runs it
from HIMON with `AP B2 $9000 $3000`.

For the short bench procedure with only the commands and checkpoints, use
[LIFE16_QUICK_CARD.md](LIFE16_QUICK_CARD.md). This page explains why each step
exists and preserves the board-test evidence.

Source:

```text
DOC/GUIDES/ASM/SAMPLES/life16-column-2000.a
```

Helper:

```text
DOC/GUIDES/ASM/SAMPLES/bankput-3000.a
```

## What It Does

`life16-column-2000.a` uses a 16x16 toroidal board. The seed is a vertical
three-cell column centered in the board. Under Life rules, that seed alternates
between a vertical column and a horizontal row, so the result is easy to inspect
on a serial console.

The program prints generations `G0` through `G6`, then writes `$AC` to `$5848`
and returns to HIMON. `$5849` holds the last generation number.

## Why These Addresses

```text
$2000  source/body origin while assembling
$3000  RAM destination used by AP when running the body
$3200  RAM AP envelope buffer written by PACKAGE
$9000  bank 2 flash address where the AP envelope is stored
$1100  current 16x16 board buffer
$1200  next 16x16 board buffer
$5848  run-complete status byte
$5849  last generation byte
```

The body origin and the run destination are intentionally different. `PACKAGE`
records the body and its relocation facts; `AP B2 $9000 $3000` later copies the
BODY from the banked AP envelope into RAM at `$3000`, applies relocation/import
fixups, and runs it there. The program never executes from bank 2 flash.

Bank 2 is used because it is the preferred test bank for banked AP storage.
The `bankput-3000.a` helper preserves the rest of the target 4K sector by
copying the bank sector into the `$0A00-$19FF` staging buffer, overlaying the
AP envelope, then programming the staged sector back.

## Board-Test Need

A final board test is still needed before calling this procedure proven. Host
builds can prove the source files exist and the ROM image layout is sane, but
this flow touches real flash through STR8's bank service and then exercises
HIMON's banked `AP` loader/linker.

The 2026-07-10 transcript proved the assemble/package/write portions:

```text
HIMON V 00.0710(1553)
ASM-F2
...
ASM>$215E:         END
ASM OK
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$01DE
...
>G 3000
RET A=AC X=03 Y=00 P=B5 S=FD Nv-BdIzC
>D 1A00 4
1A00: AC 00 00 00 00 | .....
```

That same transcript used `bank2put-8000-3000.a`, which stores the envelope at
bank 2 `$8000`, then tried to run from `$9000` and `$A000`:

```text
>AP B2 $9000 $3000
APERR=$07
>AP B2 $A000 $3000
APERR=$07
```

`APERR=$07` is HIMON AP `BAD_LINE`, which is expected when the selected source
address does not begin with an AP envelope. To complete that exact test state,
run `AP B2 $8000 $3000`; to follow this guide exactly, use `bankput-3000.a`,
which defaults to `DST=$9000`, then run `AP B2 $9000 $3000`.

Have a known-good programmer image ready before writing banked flash.

## Build Current Firmware

On the host:

```text
make -C SRC all
```

Reason: this produces the current onboard image with STR8-N, HIMON V, ASM-F2,
and the AP service path expected by the banked example.

Install or boot that image, then get to the HIMON `>` prompt. If the board is
already on the current image, this step is only a freshness check.

The Life procedure starts at HIMON, not STR8. If the board displays `STR8-N>`,
finish or abort the current STR8 operation and enter HIMON before pasting any
ASM source. Treat destructive STR8 confirmation prompts as a separate board
maintenance step.

## Assemble And Package Life

At HIMON:

```text
>ASM NEW
```

Reason: `ASM NEW` starts a clean ASM-F2 source session. The source itself uses
`ORG $2000`, so the emitted BODY origin is explicit.

Paste:

```text
DOC/GUIDES/ASM/SAMPLES/life16-column-2000.a
```

End of source should return to `SEAL>` after `END`:

```text
ASM OK
SEAL>
```

Seal and package:

```text
SEAL> SEAL
SEAL OK
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$llll
```

Reason: `SEAL` freezes the body facts from the last clean `END`. `PACKAGE
$3200` writes the AP envelope into RAM at `$3200`; `$3200` is data, not code.
Keep the printed package length for the transcript.

Exit to HIMON:

```text
SEAL> .
ASM BYE
>
```

Reason: HIMON commands such as `G` and `AP` run at the `>` prompt, not at
`SEAL>`.

Check the package before starting the writer session:

```text
>D 3200 5
3200: 41 50 01 DE 01
```

Reason: `41 50` is the AP signature, `01` is the AP version, and `DE 01` is the
current Life package length for printed length `$01DE`. Stop if any of those
bytes differ. Do not run `AP`, `LOAD`, or another `PACKAGE` between this check
and `G 3000`; `$3200` must remain the unchanged package buffer for
`bankput-3000.a`. A damaged or replaced buffer makes the writer return `$E2`.

## Store The AP Envelope In Bank 2

Start a second ASM session:

```text
>ASM NEW
```

Paste:

```text
DOC/GUIDES/ASM/SAMPLES/bankput-3000.a
```

Do not paste `bank2put-8000-3000.a`. It belongs to the fixed session reporter
workflow and uses different store and run addresses. This Life procedure uses
only `bankput-3000.a` and bank 2 `$9000`.

Use the helper defaults:

```text
BANK = $02
PKG  = $3200
DST  = $9000
```

Reason: the first session left the AP envelope in RAM at `$3200`. The helper
copies that envelope into bank 2's `$9000` window address while preserving the
rest of the bank sector.

After `END`, exit and run the helper:

```text
SEAL> .
ASM BYE
>G 3000
```

Check helper status:

```text
>D 1A00 1A04
```

Expected:

```text
1A00: AC ...
```

Reason: `$AC` means the helper staged, overlaid, programmed, and verified the
bank 2 sector. Do not run the banked package if `$1A00` is not `$AC`.

Common helper failures:

```text
$E0  bad bank or destination
$E1  stage-copy failed
$E2  AP header/length was not valid at $3200
$E3  AP would cross the 4K sector
$E4  program/verify failed
```

## Run Life From Bank 2

At HIMON:

```text
>AP B2 $9000 $3000
```

Reason: `B2 $9000` names the AP envelope stored in flash bank 2. `$3000` is the
RAM destination where HIMON loads, links, and runs the BODY.

Expected console shape:

```text
G0
................
................
...
........#.......
........#.......
........#.......
...

G1
................
...
.......###......
...
```

The oscillator alternates between the vertical column and horizontal row
through `G6`.

Verify completion:

```text
>D 5848 5849
```

Expected:

```text
5848: AC 06
```

Reason: `$5848=$AC` is the program's run-complete marker; `$5849=$06` shows it
printed through generation 6.

## Re-Run Later

Once bank 2 has the AP envelope, a later session only needs:

```text
>AP B2 $9000 $3000
```

Do not re-run `bankput-3000.a` unless you intentionally want to replace the
stored AP envelope.
