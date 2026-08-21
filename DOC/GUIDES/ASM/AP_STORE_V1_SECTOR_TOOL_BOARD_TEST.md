# AP Store V1 Single-Sector Tool Board Test

Status: host-accepted candidate; destructive board proof pending.

This procedure qualifies implementation Slice 3 without adding resident HIMON
code. The S19 image is `SRC/BUILD/s19/ap-store-v1-sector-tool-7000.s19` and
owns `$7000-$757F` plus transient card `$7C00-$7C2F`. It is mutually exclusive
with the `$7000` ASM reporter and is terminal for an ASM session.

Do not execute `$7003` against a sector until its bank, sector, current CRC,
classification, and intended loss have been reviewed. PREPARE at `$7000` is
read-only. EXECUTE at `$7003` may erase an entire 4096-byte sector.

## Request And Result Card

```text
$7C00  operation       01 CLAIM, 02 CONVERT, 03 FORMAT
$7C01  bank            00-02
$7C02  sector          08-0F
$7C03  confirmation    tool clears it; operator sets A5 only after PREPARE
$7C04  prepared CRC16  low, high
$7C06  status          A0 prepared, AC success, E0-ED failure
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
3. Load `ap-store-v1-sector-tool-7000.s19` through HIMON's RAM S19 loader.
4. Set only the operation, bank, and sector. Example syntax for operation 01,
   Bank 2, sector A:

```text
>M 7C00 7C03
7C00: xx 01
7C01: xx 02
7C02: xx 0A
7C03: xx
>G 7000
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

After reviewing the PREPARE card, set only the confirmation byte and execute:

```text
>M 7C03
7C03: 00 A5
>G 7003
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
