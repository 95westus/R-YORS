# AP Store V1 Single-Sector Tool Board Test

Status: host-accepted; board-accepted for AP bootstrap, CLAIM, and FORMAT.
Occupied-sector CONVERT remains pending separate operator approval and proof.

This procedure qualifies implementation Slice 3. The S19 image is
`SRC/BUILD/s19/ap-store-v1-sector-tool-7000.s19`; the fixed AP v2 package is
`SRC/BUILD/bin/ap-store-v1-sector-tool-7000.ap.bin`. The BODY owns
`$7000-$7727` plus transient card `$7C00-$7C2F`. It is mutually exclusive with
the `$7000` ASM reporter and is terminal for an ASM session. Resident `AP` has
a narrow `$7000-$7BFF` BODY-destination exception so it can remain the
bootstrap; resident `APS` and `Q` are unchanged in this slice.

Do not execute `$7006` against a sector until its bank, sector, current CRC,
classification, and intended loss have been reviewed. Inventory at `$7000` and
PREPARE at `$7003` are read-only. EXECUTE at `$7006` may erase an entire
4096-byte sector.

## Read-Only Inventory And AP Bootstrap

Raw-S19 entry `$7000` and AP export `APSTORE` both run the inventory. The AP
package BODY and export are fixed at `$7000`, so use destination `$7000`:

```text
>AP $hhhh $7000
GO 7000
APSTORE B/S=08 ...
...
APSTORE B/S=2F ...
APSTORE OK
```

Here `$hhhh` is a visible RAM or flash address containing the package. If the
package begins at a Bank 0-2 sector boundary, use `AP Bn $s000 $7000`; resident
`AP` first stages that 4K sector through `$0A00-$19FF`. Require exactly 24 rows
from `08` through `2F`, no Bank-3 row, and a final `APSTORE OK`. The inventory
is read-only, but it copies the STR8 selector/worker into low RAM and therefore
still terminates any prior ASM session.

## Request And Result Card

```text
$7C00  operation       01 CLAIM, 02 CONVERT, 03 FORMAT
$7C01  bank            00-02
$7C02  sector          08-0F
$7C03  confirmation    tool clears it; operator sets A5 only after PREPARE
$7C04  prepared CRC16  low, high
$7C06  status          A0 prepared, AC success, E0-EE failure
$7C07  class           00 header-FF, 01 opaque, 02 corrupt, 03 staged,
                       04 active, 05 retired, 06 bad, 07 retired+bad
$7C08  flags           bit 0 full-sector erased, bit 1 tail erased
$7C09  next generation low, high
$7C0B  failure phase   00 none, 01 scan, 02 policy, 03 erase,
                       04 erase verify, 05 header write, 06 header verify,
                       07 commit, 08 restore
$7C0C  failure address low, high
$7C0E  current CRC16   low, high
$7C10  copied/built 16-byte sector header
```

Any failed EXECUTE invalidates the prepared state. Run PREPARE again before a
later attempt.

## Read-Only PREPARE Gate

1. Build with `make -C SRC ap-store-sector-tool-check`.
2. Capture the four-bank CRC table with the maintained
   `str8n-v1.2-bank-crc-all-3000.a` fixture.
3. Load `ap-store-v1-sector-tool-7000.s19` through HIMON's RAM S19 loader, or
   load its AP package through resident `AP` and let inventory finish first.
4. Set only the operation, bank, and sector. HIMON deliberately protects the
   High Tool Overlay: `M 7C00 7C03` returns `M PROT=$7C00`. Use a short,
   inspected RAM helper in the user-free `$1A00-$1FFF` range instead. The
   generic helper is:

```asm
        ORG $1A00
        LDA #operation
        STA $7C00
        LDA #bank
        STA $7C01
        LDA #sector
        STA $7C02
        STZ $7C03
        RTS
```

   Load the helper through `L`, inspect its bytes with `D`, run it, and verify
   the request before PREPARE:

```text
>G 1A00
>D 7C00 7C03
>G 7003
>D 7C00 7C1F
```

5. Require status `$A0`, failure phase `$00`, and equal prepared/current CRCs.
6. Confirm that the returned class and flags satisfy the requested policy:

   - CLAIM: flags `$03`; the complete sector is erased.
   - CONVERT: full-erased bit clear and class `$00-$03`; the current sector
     will be destroyed.
   - FORMAT: class `$04-$07`, tail-erased bit set, and next generation exactly
     one greater than bytes 4-5 of the copied header.

Stop after this gate until the operator has explicitly named a sacrificial
sector. A PREPARE transcript alone makes no flash-mutation claim.

## Explicit EXECUTE Gate

After reviewing the PREPARE card, set only the confirmation byte with a
separate inspected helper. The exact accepted helper at `$1A20` is:

```text
>L
L S19
S1091A20A9A58D037C6002
S9031A20C2
L OK=0006 ENTRY=1A20
>D 1A20 1A25
1A20: A9 A5 8D 03 7C 60
>G 1A20
>D 7C03
7C03: A5
>G 7006
>D 7C00 7C1F
>APS
```

Require `$7C03=00`, `$7C06=AC`, `$7C0B=00`, and an `APS` row of `ACTIVE` with
the prepared generation. Re-run the four-bank CRC fixture. Every CRC except
the selected sector must match the pre-operation table exactly.

The first hardware sequence is:

1. CLAIM one already erased sacrificial sector;
2. cold reset and confirm that `APS` still reports it ACTIVE generation 1;
3. FORMAT that same empty managed sector;
4. cold reset and confirm ACTIVE generation 2;
5. only after separate operator approval, CONVERT one occupied opaque
   sacrificial sector.

For CLAIM, bytes `$0010-$0FFF` must remain `$FF`. For FORMAT and CONVERT, the
worker must erase and verify all 4096 bytes before writing the new header.
Header bytes `$00-$0E` are written and verified first; state `$FE` is the final
program operation.

## Accepted CLAIM And FORMAT Proof

On 2026-08-21, HIMON/ASM-F2 `00.0821(0132)` loaded the fixed `APSTORE` package
at `$3000` and its BODY at `$7000`. Inventory returned all 24 rows and
`APSTORE OK`. The operator named Bank 1 sector 8 sacrificial.

CLAIM PREPARE classified B1:8 as header-FF with flags `$03`, generation 1, and
matching CRC bytes `E1 0F`. EXECUTE returned `$AC`; the built header was
`41 53 31 18 01 00 4D 68 28 E9 FF FF FF FF FF FF`, and resident `APS`
reported `B/S=18 ACTIVE G=0001`. The four-bank CRC table changed only B1:8,
from `E1 0F` to `56 F1`. `HCOLD` then preserved ACTIVE generation 1.

FORMAT PREPARE classified the same sector ACTIVE with an erased record tail,
flags `$02`, next generation 2, and matching CRC bytes `56 F1`. EXECUTE erased,
verified, rebuilt, and committed the sector, returning `$AC`. A second
unconfirmed `G 7006` immediately returned `$E7`; it did not select or mutate
flash. The generation-2 header card was
`41 53 31 18 02 00 B6 E2 2A 0F FF FF FF FF FF FF`, and `APS` reported
`B/S=18 ACTIVE G=0002`. The next full CRC table changed only B1:8, from
`56 F1` to `48 F2`. A final `HCOLD` preserved ACTIVE generation 2.

This accepts AP bootstrap into the dedicated `$7000` tray, read-only PREPARE,
CLAIM, FORMAT, commit-last activation, consumed confirmation, whole-bank
isolation, and cold persistence. CONVERT is not accepted by this proof.

## Failure Expectations

- CLAIM on occupied media returns `$E2` without mutation.
- FORMAT on opaque/corrupt/staged media returns `$E3`.
- FORMAT on a managed sector with any programmed log byte returns `$E4`.
- FORMAT generation `$FFFF` returns `$E5`.
- Any request/class/flags/CRC change after PREPARE returns `$E6`.
- Missing confirmation returns `$E7`.
- CONVERT on managed media returns `$EC`; on erased media it returns `$ED`.

Append the raw terminal transcript and both CRC tables to
`DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`. Do not rewrite the Slice 2 evidence.
