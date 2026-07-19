# AP Linker Current-Image Gates

This is the pasteable board procedure that closes the two remaining regression
gates after moving AP import linking from STR8 into HIMON. It applies to the
current map in which resident `BIO_FTDI_PUT_CSTR` resolves to `$E705`.

```text
Gate 1 missing-import atomicity  PASS 2026-07-19
Gate 2 banked-source RJOIN       PASS 2026-07-19
```

Do not change the linker, AP package format, fixture bodies, import order, or
resident catalog during this proof. If a gate exposes an implementation fault,
stop and preserve the transcript before beginning a separate fix.

## Frozen Fixtures

The reviewed `banked-rjoin-smoke.a` and `bankput-transient-3000.a` sources were
promoted byte-for-byte from `SAMPLES/OLD CODE` into the active samples
directory. The three proof inputs are frozen as these Git blobs:

```text
3522dd3bbfa2f4adaa9fc7bb4babf4b981f5f534  banked-rjoin-smoke.a
aae0f1ebcc3d9cd82b16e1da828e3c055a7223a1  bankput-transient-3000.a
58f106005e0c6db5493d0e39eddfeaccd4dc0d21  missing-import-atomicity-2000.a
```

Active paths:

- [banked-rjoin-smoke.a](SAMPLES/banked-rjoin-smoke.a)
- [bankput-transient-3000.a](SAMPLES/bankput-transient-3000.a)
- [missing-import-atomicity-2000.a](SAMPLES/missing-import-atomicity-2000.a)

The current `bankput` fixture is already pinned to:

```text
BANK = $02
PKG  = $3200
DST  = $9000
```

The expected resident target is pinned for this proof to:

```text
BIO_FTDI_PUT_CSTR = $E705
patched operand   = 05 E7
```

Keep the source import symbolic. `$E705` is the expected resolver result, not a
literal replacement for `BIO_FTDI_PUT_CSTR` in either fixture.

## Gate 1: Missing-Import Atomicity

The negative fixture declares two imports in deliberate order: valid
`BIO_FTDI_PUT_CSTR` first and missing `OIL_MISSING_SYMBOL` second. Its two JSR
operands must both remain unresolved when validation encounters the missing
symbol.

Board sequence:

```text
ASM NEW
  paste SAMPLES/missing-import-atomicity-2000.a
PACKAGE $3200
.
M 5848
  enter 00
AP $3200 $3000
D 5848
D 3007 300C
D 7E2D 7E40
```

Required proof:

```text
APERR=$09
$5848             = 00
$3007-$300C       = 20 FF FF 20 FF FF
HIM_AP_STATUS     = 09 at $7E30
```

Interpretation:

- `$5848=00` proves AP did not enter the body. Entry would first write `$E4`.
- `$3007-$3009 = 20 FF FF` proves the valid first import was not partially
  patched before the later missing import failed validation.
- `$300A-$300C = 20 FF FF` is the still-unresolved missing import.
- `$7E30=09` agrees with the visible `APERR=$09` bad-fix result.

Stop before touching banked flash if any byte differs. In particular, `20 05
E7` at `$3007` is a failure here: it proves validation partially patched the
body before discovering the missing second import.

Hardware result 2026-07-19: pass. The board returned `APERR=$09`, left
`$5848=$00`, preserved `$3007-$300C = 20 FF FF 20 FF FF`, and reported
`HIM_AP_STATUS=$09`. The full transcript is in
[HARDWARE_TEST_LOG.md](../LOGS/HARDWARE_TEST_LOG.md).

## Gate 2: Banked-Source RJOIN

This gate overwrites Bank 2 sector `$9000-$9FFF`. The installer first stages
the existing sector at `$0A00-$19FF`, overlays the AP envelope at `$9000`, then
programs and verifies the complete staged sector. Confirm that the Bank 2
sector is disposable before continuing.

Build and install the frozen package:

```text
ASM NEW
  paste SAMPLES/banked-rjoin-smoke.a
PACKAGE $3200
.
ASM NEW
  paste SAMPLES/bankput-transient-3000.a
  verify BANK=$02, PKG=$3200, DST=$9000
.
G 3000
D 1A00 1A03
```

Continue only when:

```text
$1A00-$1A03 = AC 00 00 00
```

Then run from the banked source:

```text
M 5848
  enter 00
AP B2 $9000 $3000
D 5848 5850
D 3006 3008
D 1A10 1A17
D 7E2D 7E40
D 0A00 0A08
```

Required proof:

```text
prints BANK RJOIN
RET A=AC with carry set
$5848             = AC
$584A/$584B       = 05 E7
$3006-$3008       = 20 05 E7
$1A10-$1A17       = 06 0F 30 05 E7 04 05 01
staged package     begins 41 50 01 76 00 at $0A00
HIM_AP_STATUS      = 00 at $7E30
HIM_AP source      = $0A00 at $7E31-$7E32
HIM_AP destination = $3000 at $7E33-$7E34
```

The debug row means final patch kind `$06`, patch site `$300F`, resolved target
`$E705`, relocation index `$04`, five relocation rows, and one import. The
source cells prove `AP B2` used the staged RAM copy rather than attempting to
execute or link while Bank 2 was visible.

Hardware result 2026-07-19: pass. The sector installer returned
`$1A00-$1A03 = AC 00 00 00`. `AP B2 $9000 $3000` printed `BANK RJOIN` and
returned `A=$AC/C=1`; `$584A/$584B` and the loaded JSR operand both recorded
`$E705`. The debug row was `06 0F 30 05 E7 04 05 01`, the staged package began
`41 50 01 76 00`, and the HIMON request cells reported status `$00`, staged
source `$0A00`, and destination `$3000`. Three consecutive AP executions
produced the same successful result. The complete transcript is in
[HARDWARE_TEST_LOG.md](../LOGS/HARDWARE_TEST_LOG.md).

## Close The Gates

Both current-image gates closed on hardware on 2026-07-19. The tested image
identifiers recorded by the installation and proof sessions are STR8
`V0 #5F6A0F7A`, HIMON `00.0718(2041)`, and ASM-F2 `00.0718(2045)`; the pinned
resident target remains `BIO_FTDI_PUT_CSTR=$E705`.

When both gates pass:

1. Append the complete board transcripts to
   [HARDWARE_TEST_LOG.md](../LOGS/HARDWARE_TEST_LOG.md); do not rewrite the old
   STR8-resident-linker or `.710` evidence.
2. Record the exact HIMON, ASM-F2, and STR8 banners and confirm the resident map
   still resolves `BIO_FTDI_PUT_CSTR=$E705`.
3. Mark the two current-image gates complete in
   [TEST_PLAN.md](TEST_PLAN.md), [TODO.md](../PLANNING/TODO.md), and the README
   status only after the transcript is present.
4. Commit the hardware evidence separately from any later linker, package, or
   multiboot implementation work.

If either gate fails, keep it open and stop. A fix starts a new implementation
and proof cycle with newly reviewed fixture expectations.
