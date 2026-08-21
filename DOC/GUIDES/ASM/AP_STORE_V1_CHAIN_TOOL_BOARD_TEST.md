# AP Store V1 Arbitrary-Sector Chain Board Test

Status: host-accepted candidate; board proof pending.

This card qualifies Slice 5 by storing one exact `$1000`-byte AP v2 envelope
as a two-chunk object in nonadjacent managed sectors B1:9 and B1:B. B1:9
retains its accepted Slice 4 object and contributes its remaining append tail;
B1:B is CLAIMed first and supplies the final extent. B1:A is not selected or
written. The user-approved writable range is B1:8-E; B1:F remains excluded.

Do not run the mutation half unless the initial `APS` and CRC checks agree
with the expected media. If B1:B is already anything other than `HEADER-FF`
or the known freshly CLAIMed empty `ACTIVE G=0001`, stop and review it.

## Exact transports

Build the generated transports with:

```text
make -C SRC ap-store-sector-tool ap-store-chain-tools
```

Every `L` or `ASM` operation below names its exact input:

```text
Purpose                       Exact file sent after HIMON L / ASM
Four-bank CRC ASM source      DOC/GUIDES/ASM/SAMPLES/str8n-v1.2-bank-crc-all-3000.a
Slice 3 raw CLAIM tool        SRC/BUILD/s19/ap-store-v1-sector-tool-7000.s19
CLAIM B1:B request            DOC/GUIDES/ASM/SAMPLES/ap-store-v1-claim-b1sb-1a00.s19
CLAIM confirmation            DOC/GUIDES/ASM/SAMPLES/ap-store-v1-claim-confirm-1a20.s19
Exact 4K APBIG envelope       SRC/BUILD/s19/ap-store-v1-chain-marker-package-3000.s19
Slice 5 installer envelope    SRC/BUILD/s19/ap-store-v1-chain-install-tool-package-4000.s19
Chain B1 O2/G1 request        DOC/GUIDES/ASM/SAMPLES/ap-store-v1-chain-b1-o2g1-1a00.s19
Chain confirmation            DOC/GUIDES/ASM/SAMPLES/ap-store-v1-chain-confirm-1a40.s19
Slice 5 reader envelope       SRC/BUILD/s19/ap-store-v1-chain-reader-tool-package-4000.s19
```

The generated installer AP is `$092F` bytes at `$4000`; `AP 4000 7000`
loads its `$0901`-byte BODY at `$7000-$7900` and immediately enters PLAN.
The reader AP is `$0854` bytes at `$4000`; it loads its `$0826`-byte BODY at
`$7000-$7825` and immediately enters LIST. Both remain below HIMON's `$7A00`
input buffer. APBIG is exactly `$1000` bytes at `$3000-$3FFF`; its BODY is
4050 bytes linked for `$4000`.

The tiny helpers are reproduced in full so the operator never has to infer
bytes or reuse a similarly named card:

```text
; ap-store-v1-claim-b1sb-1a00.s19
S1141A00A9018D007C8D017CA90B8D027C9C037C60DA
S9031A00E2

; ap-store-v1-claim-confirm-1a20.s19
S1091A20A9A58D037C6002
S9031A20C2

; ap-store-v1-chain-b1-o2g1-1a00.s19
S11F1A00A9008D807CA9308D817CA9008D827CA9408D837CA9018D847CA90A8D11
S1191A1C857CA9028D867C9C877CA9018D887C9C897C9C8A7C60F8
S9031A00E2

; ap-store-v1-chain-confirm-1a40.s19
S1091A40A9A58D8A7C605B
S9031A40A2
```

Expected loader reports are `$0011/$1A00`, `$0006/$1A20`,
`$0032/$1A00`, and `$0006/$1A40`, respectively.

## Frozen request and result card

The chain helper writes source `$3000`, destination `$4000`, bank `$01`,
allowed-sector mask `$0A` (B1:9 and B1:B), object `$0002`, generation
`$0001`, and zero confirmation:

```text
$7C80-$7C81 source AP envelope
$7C82-$7C83 fixed BODY destination
$7C84       bank
$7C85       allowed sector mask; bit 0 is sector 8
$7C86-$7C87 object
$7C88-$7C89 generation
$7C8A       confirmation; $A5 only after PLAN review
$7C8B       status
$7C8C-$7C8D package length
$7C8E-$7C91 package FNV-1a
$7C92       chunk count
$7C93       used-sector mask
$7C94-$7C95 total selected append capacity
$7C96       failure phase
$7C97       failure sector
$7C98-$7C99 loaded entry
$7CA0-$7CAB prepared request/source snapshot
$7CB0-$7CFF eight ten-byte plan rows
$7D00-$7D3F transient header/hash workspace
```

Each plan row is sector, flags, record offset, logical offset, payload length,
and prepared full-sector CRC, with every word little-endian.

## Gate sequence

1. Cold reset. Run `APS`. Require B1:8 `ACTIVE G=0002`, B1:9
   `ACTIVE G=0001`, B1:B `HEADER-FF`, and no unexpected change elsewhere.
   Assemble the exact CRC source named above, load its resulting S19 at
   `$3000`, run `G 3000`, and save `$7C10-$7C4F` as the baseline.

2. CLAIM only B1:B. Load
   `SRC/BUILD/s19/ap-store-v1-sector-tool-7000.s19`. Load
   `DOC/GUIDES/ASM/SAMPLES/ap-store-v1-claim-b1sb-1a00.s19`, run `G 1A00`,
   then run read-only PREPARE with `G 7003`. Inspect `$7C00-$7C1F`; require
   request `01 01 0B 00`, status `$A0`, class `HEADER-FF`, and no flash CRC
   change.

3. Load
   `DOC/GUIDES/ASM/SAMPLES/ap-store-v1-claim-confirm-1a20.s19`, run
   `G 1A20`, verify `$7C03=A5`, then run `G 7006`. Require `$AC` and
   `APS B/S=1B ACTIVE G=0001`. Re-run the exact CRC source; only B1:B may
   differ from the baseline. Its empty managed-sector header and CRC are:

   ```text
   41 53 31 1B 01 00 5C 8D D7 59 FF FF FF FF FF FE
   CRC16 $5877, stored by the CRC tool as bytes 77 58
   ```

4. Load APBIG with
   `SRC/BUILD/s19/ap-store-v1-chain-marker-package-3000.s19`. Require
   `L OK=1000 ENTRY=3000` and `D 3000 3004` = `41 50 02 00 10`.

5. Load
   `DOC/GUIDES/ASM/SAMPLES/ap-store-v1-chain-b1-o2g1-1a00.s19`, run
   `G 1A00`, and inspect `$7C80-$7C8A`. Then load
   `SRC/BUILD/s19/ap-store-v1-chain-install-tool-package-4000.s19` and run
   `AP 4000 7000`. The AP bootstrap enters PLAN `$7000`; PLAN is read-only.

6. Require PLAN return/status `$A0`, confirmation `$00`, package length
   `$1000`, package FNV bytes `1D 0A A6 85`, two chunks, used mask `$0A`,
   capacity `$1F6A`, and zero failure phase/sector. With the accepted B1:9
   CRC `$6915`, the card must contain:

   ```text
   D 7C80 7C99
   7C80: 00 30 00 40 01 0A 02 00 01 00 00 A0 00 10 1D 0A
   7C90: A6 85 02 0A 6A 1F 00 00 00 00

   D 7CB0 7CC3
   7CB0: 09 01 5C 00 00 00 8F 0F 15 69
   7CBA: 0B 02 10 00 8F 0F 71 00 77 58
   ```

   If the saved post-CLAIM B1:9 CRC is not `$6915`, stop; do not substitute
   another value merely to make EXECUTE pass.

7. The two record headers PLAN will produce are:

   ```text
   B1:9+$005C
   41 52 01 01 01 FF 02 00 01 00 00 00 8F 0F A5 9C 8C 10 59 6B

   B1:B+$0010
   41 52 01 01 02 FF 02 00 01 00 8F 0F 71 00 BD 12 DA 66 C1 38
   ```

8. Load
   `DOC/GUIDES/ASM/SAMPLES/ap-store-v1-chain-confirm-1a40.s19`, run
   `G 1A40`, and verify only `$7C8A=A5`. Run EXECUTE with `G 7003`.
   Require return/status `$AC`, confirmation consumed to `$00`, and failure
   phase/sector zero. A second `G 7003` must return `$D7` without mutation.

9. Run `APS`; B1:9 and B1:B remain `ACTIVE G=0001` because appending records
   does not change their 16-byte sector headers. The first new record fills
   B1:9 offsets `$005C-$0FFF`, with commit at `$0FFF`. The second occupies
   B1:B offsets `$0010-$0095`, with commit at `$0095`; `$0096-$0FFF` remains
   erased.

10. Load the same chain request helper and run `G 1A00`. Load
    `SRC/BUILD/s19/ap-store-v1-chain-reader-tool-package-4000.s19`, then run
    `AP 4000 7000`. LIST must print exactly:

    ```text
    APCHAIN O=0002 G=0001 L=1000
    APCHAIN OK
    ```

11. Run VALIDATE with `G 7003`; require `$AC`. Verify
    `$0A00-$0A04 = 41 50 02 00 10`. Run LOAD/RUN with `G 7006`; require
    `A=$AC` with carry set, `$7C98-$7C99=00 40`, and `$1A01=C5`.

12. Re-run the exact four-bank CRC source. Relative to the post-CLAIM table,
    only B1:9 and B1:B may differ; all other 30 sector CRCs must be exact.
    Save the table.

13. Cold reset. Load the chain request helper, run `G 1A00`, load the reader
    envelope at `$4000`, and run `AP 4000 7000`. Repeat LIST, VALIDATE, the
    `$0A00` signature check, and LOAD/RUN. Re-run `APS` and the exact CRC
    source. This proves discovery and reconstruction do not depend on the
    prior installer RAM image.

Append the raw terminal transcript and all three CRC tables (baseline,
post-CLAIM, post-chain/cold) to `DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`.

## Status values

```text
A0 prepared          AC success
D0 bad request       D1 invalid AP       D2 not managed
D3 corrupt log       D4 duplicate key    D5 no space
D6 media changed     D7 not confirmed    D8 program failed
D9 verify failed     DA restore failed   DB not found
DC service failure   DD incomplete       DE conflict
DF too many chunks   E0 cross-bank
```

PLAN never selects flash for writing. EXECUTE consumes confirmation before
bank selection, revalidates the source and every planned sector snapshot, and
programs each chunk header, payload, then `$A5` commit. A power interruption
may leave a committed prefix, but the reader cannot make that generation live
without its unique LAST chunk and exact gap-free AP envelope.
