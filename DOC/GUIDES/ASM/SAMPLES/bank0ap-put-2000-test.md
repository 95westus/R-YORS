# Bank 0 AP Put Board Test

Purpose: prove the Bank 0 AP installer both as a direct-run bootstrap tool and
as a fixed-load resident AP.
This is a destructive Bank 0 flash write. Use it only for an intentionally
reserved AP sector and with a known recovery path.

Status: the earlier split stage/commit path is hardware-proven. This card is
the board-proof procedure for the new `bank0ap-put-transient-2000.a` combined transient.
Record its result in `DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md` and
`DOC/GUIDES/ASM/TEST_PLAN.md`; do not replace the earlier split transcript.

The fixed roles are:

```text
$0200-$09FF  LRS Symbol Name Lane, then STR8 Worker Code Tray
$0A00-$19FF  LRS Fixup Name Lane, then 4K Sector Staging Deck
$2000-$2FFF  AIR Build Bay: RAM transient code and ordinary AP BODY source
$3000-$3FFF  AIR Envelope Bay: AP Capsule, then normal load/run space
```

Use `PACKAGE $3000` for this procedure. Never package the target at `$2000`:
the installer itself emits there. Every pasted source below already ends with
`END`; do not type another `END` after the paste.

This card uses archived `OLD CODE/bank0ap-print-smoke.a`, which prints from the loaded AP body
and leaves `$5848=$AC`, `$5850=$5A`, and the imported
`BIO_FTDI_PUT_CSTR` address at `$584A/$584B`.

## Precondition: Erase The Destination

This explicit proof uses Bank 0 `$8000-$8FFF`. Stop if that sector is not
intentionally available. If it is not erased, run the flash erase transient:

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/flash-erase-bank-transient-2000.a
ASM OK
SEAL> .
ASM BYE
>G 2000
BANK 0-3> 0
SECTOR 8-F OR ALL> 8
TYPE YES TO ERASE> YES
```

Expected:

```text
OK
BANK 0 ERASE COMPLETE
RET A=AC ... C
```

Do not use `G 3000` for the current erase sample; `$3000` is the normal AP
load/run island.

## 1. Build The AP Envelope

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/OLD CODE/bank0ap-print-smoke.a
ASM OK
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$007F
SEAL> .
ASM BYE
>D 3000 F
```

Expected header shape:

```text
3000: 41 50 01 7F 00 ...
```

The first bytes are `41 50 01`, followed by little-endian package length. The
current print-smoke package is `$007F`; record the actual length if the source
changes. Do not run `LOAD`, `AP`, or another `PACKAGE` until the installer has
returned.

Do not run `G 2000` while the package source BODY is still present there.
`PACKAGE` serializes imports but does not turn that source BODY into a linked
direct-run image. Re-paste `bank0ap-put-transient-2000.a`, exit with `.`, and only then
use `G 2000`.

## 2. Store The AP In Bank 0

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/bank0ap-put-transient-2000.a
ASM OK
SEAL> .
ASM BYE
>G 2000
```

Do not change the installer's `ORG $2000` to `$3000`. `$3000` contains the AP
envelope being consumed; assembling the transient there destroys its own input
and correctly ends with `$1A00=$E1`.

No `ERR=` row may appear during the paste. A rejected line is rolled back, so
a later `END` can still print `ASM OK`; that does not make the skipped opcodes
runnable. Stop and restart with the current source after any error row.

Expected interaction. At the destination prompt, type `$8000`; at the write
prompt, type exact upper-case `YES`:

```text
B0 AP PUT
PKG L=$007F
DST $8000-$FFFF OR ENTER=AUTO> $8000
STAGE OK
B0 AP @$8000 L=$007F
TYPE YES TO WRITE> YES
PROGRAM OK
B0 AP @$8000 L=$007F

#GO# ENTRY=2000
RET A=AC ... C
```

Dump the installer result:

```text
>D 1A00 1A06
```

Expected for this package and destination:

```text
1A00: AC 00 80 7F 00 80 00
```

Meaning:

```text
$1A00       AC: program and verify succeeded
$1A01/$1A02 selected package address: $8000
$1A03/$1A04 package length: $007F
$1A05       selected sector: $80
$1A06       00: no staged write remains armed
```

`$1A03/$1A04` will differ if the AP package length differs. The installer
clears `$1A06` on success, abort, and every reported failure.

## 3. Load And Run The Stored AP

```text
>AP B0 $8000 $3000
```

Expected:

```text
GO 3000

B0 AP RUN

#GO# ENTRY=3000
RET A=AC ... C
```

Then:

```text
>D 5848 5850
```

Pass shape:

```text
5848: AC xx ll hh xx xx xx xx | 5A
```

Pass when the AP prints `B0 AP RUN`, `$5848=$AC`, `$5850=$5A`, and
`$584A/$584B` is the resolved resident `BIO_FTDI_PUT_CSTR` address. Bytes
shown as `xx` are not owned by this smoke program.

The same stored ordinary AP can be tried at `$3200` or `$3400` after the
`$3000` proof. Do not use `$2000` until all transient work is complete, since
it overwrites the transient/source island.

## 4. Auto Append Variant

Rebuild the AP envelope at `$3000`, paste `bank0ap-put-transient-2000.a`, and run
`G 2000` again. At the address prompt, press Enter:

```text
DST $8000-$FFFF OR ENTER=AUTO>
```

Expected interaction:

```text
AUTO B0:$807F APPEND
STAGE OK
B0 AP @$807F L=$007F
TYPE YES TO WRITE> YES
PROGRAM OK
B0 AP @$807F L=$007F
RET A=AC ... C
```

`AUTO` is append-only, not a raw first-$FF-hole search. It walks complete
`AP/01` envelopes from the beginning of each sector and can append only into
the remaining clean erased tail. A malformed prefix or non-erased bytes after
the tail closes that sector; it is never filled around. If the first sector's
tail is too small, the trace must make the reason visible before the next
sector is considered, for example:

```text
AUTO B0:$9486 TAIL=$0B7A SHORT; NEED=$0C8B
AUTO B0:$A000 APPEND
```

Use the printed append address in the subsequent run:

```text
>AP B0 $807F $3000
```

If every sector is closed or its clean tail is too short, expect
`FAIL $1A00=$E3` and `RET A=E3 ... c`. An AP envelope never crosses a 4K
sector boundary.

## 4A. Bootstrap And Reuse The Resident Installer

To store the installer itself, assemble its current `.a`, package it at
`$3000`, and use the still-present direct-run body for the first install:

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/bank0ap-put-transient-2000.a
ASM OK
SEAL OK FLAGS=$01 BASE=$2000 END=$hhhh
SEAL REL @=$hhhh COUNT=$00
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$hhhh
SEAL> .
ASM BYE
>G 2000
```

Use an erased destination, type exact `YES`, and record the printed Bank-0
address as `PUTPKG`. For later target envelopes already built at `$3000`, do
not paste the installer again:

```text
>AP B0 PUTPKG $2000
```

HIMON loads the installer BODY into the AIR Build Bay at its required `$2000`
origin. The installer then prompts for the target Capsule's Bank-0 flash
destination. The `$2000` AP operand is a RAM run address, not that flash
destination. Require the source's `SEAL REL ... COUNT=$00` before `PACKAGE`.
The appendable revision is deliberately fixed-load and table-free; a nonzero
count means its literal map is stale. Expected first-board proof: clean
`SEAL`, `PROGRAM OK`, and `RET A=AC`.

## 5. ASM Session Reporter

The reporter has a preferred movable form and a retained fixed form.

For the movable form, paste
`DOC/GUIDES/ASM/SAMPLES/asm-session-report-ap-2000.a`, then:

```text
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$0C8B
SEAL> .
ASM BYE
>AP B0 PUTPKG $2000
```

At the installer's `DST` prompt, choose or accept a verified erased Bank-0
hole, type exact `YES`, and record the new address as `REPORTPKG`. Its later
inspection sequence is:

```text
>AP B0 REPORTPKG $4000
>ASM NEW
...target source...
SEAL> .
ASM BYE
>G 4000
```

The body is `$0C5F`, and legal AP load addresses are `$2000-$43A1`;
`$4000-$4C5E` is the recommended placement. The first `AP` command runs one
preliminary report as well as leaving the self-relocated body in RAM. Do not
issue that `AP` command after the target session: banked staging reuses the
session's low name tables.

Expected movable-reporter board gate: one ordinary AP relocation, package
`$0C8B`, successful load/run at `$4000`, then a second byte-identical `G 4000`
after the target session. The report must include these current regions:

```text
SYM   $0200-$09FF     FIX   $0A00-$19FF
TOOL  $1A00-$1FE8     STR8  $1FE9-$1FFF
ISLANDS $2000/$3000/$4000, 4K each
UDATA $5000-$61A9     SAFE  $61AA-$79FF
VOL   $7A00-$7DFF
```

The complete reporter body is load-address relocatable, but it remains
ASM-map-matched. Rebuild/reinstall after ASM-F2 code or map changes.

The older fixed form remains useful for a board that already stores it.

To prove the reporter against its own just-assembled session, build it at its
fixed origin, make the envelope needed for later storage, and run the assembled
body already present at `$4800`:

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/asm-session-report-4800.a
ASM OK
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$hhhh
SEAL> .
ASM BYE
>G 4800
```

Expected:

```text
GO 4800
ASM REPORT
...
ASM REPORT OK
RET ...
```

The updated overlap check also permits the non-overlapping RAM proof
`AP $3000 $4800`. Record that result separately from the banked proof.

To persist the fixed reporter, keep the same `$3000` envelope and store it with
the installer from section 2. Record its printed Bank 0 address. The fixed
reporter must always run at `$4800`:

```text
>AP B0 $hhhh $4800
```

After the reporter is stored, load it at `$4800` before the later ASM session.
Finish that target session with `.`, then use `G 4800`. Do not use banked `AP`
after the target session: staging the package reuses `$0200-$19FF` and destroys
the symbol/fixup names the reporter needs.

Historical proof before the low-table relocation, 2026-07-12: the reordered
installer assembled through `$2458`
with zero errors, auto-selected Bank 0 `$8000`, programmed reporter package
`L=$0658`, and left `AC 00 80 58 06 80 00` at `$1A00-$1A06`.
`AP B0 $8000 $4800` then printed `ASM REPORT OK`; its report measured the
installer at `FIXUPS=$62/$80` with `TRUNC=NO`.

## Negative Checks

Abort before any write:

```text
TYPE YES TO WRITE>
```

Expected:

```text
ABORT - NO FLASH WRITE
RET A=E0 ... c
>D 1A00 1A06
1A00: E0 ... 00
```

Occupied explicit destination:

```text
DST $8000-$FFFF OR ENTER=AUTO> $8000
```

Expected after `$8000` already holds the package:

```text
FAIL $1A00=$E5
RET A=E5 ... c
```

Bad or missing RAM envelope:

```text
>ASM NEW
paste bank0ap-put-transient-2000.a without rebuilding PACKAGE $3000 first
SEAL> .
>G 2000
```

Expected when `$3000` does not start with a valid AP envelope:

```text
FAIL $1A00=$E1
RET A=E1 ... c
```

The same `$E1` is expected after `PACKAGE $2000`: the installer emits over
that location and only reads the Bank 0 input envelope from `$3000`.

## Diagnostic Split Helpers

`bank0ap-stage-transient-2000.a` and `bank0ap-commit-transient-2000.a` remain for investigation of
the sector image between staging and programming. The stage helper leaves
`$1A06=$5A`; the commit helper consumes that state. Do not boot, run `AP`, or
assemble another source between those two diagnostic helpers. They are not the
normal installation path and their existing board transcript remains valid
historical evidence.
