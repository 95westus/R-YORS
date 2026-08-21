# AP Store V1 Single-Sector Object Tool Board Test

Status: host-accepted; board proof pending.

This procedure qualifies implementation Slice 4: append one complete AP v2
package to one already-managed sector, list its record, reconstruct and
validate it, then load and run it. The tool does not erase sectors and does not
claim unmanaged media.

The fixed AP v2 tool is
`SRC/BUILD/bin/ap-store-v1-object-tool-7000.ap.bin`, export `APOBJ`. Load its
AP envelope with `SRC/BUILD/s19/ap-store-v1-object-tool-package-3000.s19`;
do not send the raw binary to the S19 loader. Its BODY is `$7000-$79EF` (2544
bytes), ending 16 bytes below HIMON's `$7A00` command buffer. Its five entries
are LIST `$7000`, INSTALL PREPARE `$7003`,
INSTALL EXECUTE `$7006`, VALIDATE `$7009`, and LOAD/RUN `$700C`. It uses the
sector mirror `$2000-$2FFF`, reconstructed-package buffer `$0A00-$19FF`, and
cards `$7C00-$7C73`. Loading or running it is terminal for an ASM session.

The first approved media is Bank 1 sectors `$8-$E`. Keep B1:F untouched. Use
B1:9 for this proof so the accepted generation-2 B1:8 header remains separate.
B1:9 must first be CLAIMed with the accepted Slice 3 `APSTORE` tool and must
show `ACTIVE G=0001` before any object operation.

## Object Card

The bank and sector remain at `$7C01/$7C02`. The Slice 4 card is:

```text
$7C30 source package address      low, high
$7C32 fixed BODY destination      low, high
$7C34 object id                   low, high; explicit and nonzero
$7C36 object generation           low, high; nonzero
$7C38 confirmation                A5 only after PREPARE review
$7C39 status                      A0 prepared, AC success, D0-DC failure
$7C3A append record offset        low, high
$7C3C package length              low, high
$7C3E whole-package FNV-1a        four little-endian bytes
$7C42 staged-sector CRC16         low, high
$7C44 failure phase
$7C45 valid record count
$7C46 loaded entry                low, high
$7C48-$7C57 PREPARE snapshot
$7C58 found offset / scan state
$7C60-$7C73 built or found AR header
```

HIMON protects `$7C00`, so write requests only with an inspected helper in
`$1A00-$1FFF`. For the golden B1:9 request, set bank `$01`, sector `$09`,
source `$3000`, destination `$3000`, object `$0001`, generation `$0001`, and
clear `$7C38`. Use a separate helper to write only `$A5` to `$7C38` after
PREPARE. Do not reuse Slice 3's `$7C03` confirmation address.

## Golden Package

`SRC/BUILD/bin/ap-store-v1-marker-3000.ap.bin` is a 55-byte fixed AP v2
package named `APMARK`. Load it through
`SRC/BUILD/s19/ap-store-v1-marker-package-3000.s19`. Its nine-byte BODY loads
at `$3000`, writes `$A4` to
`$1A00`, returns with `A=$AC` and carry set, and has no imports or relocations.
The whole-package FNV stored in the AR header is `$708711B6`, little-endian
`B6 11 87 70`.

## Transport Manifest

Every loadable helper used by this card has an exact filename. Build the three
generated tool/package transports with:

```text
make -C SRC ap-store-sector-tool ap-store-object-tool ap-store-marker
```

```text
Purpose                  File loaded through HIMON L
Slice 3 APSTORE          SRC/BUILD/s19/ap-store-v1-sector-tool-7000.s19
CLAIM B1:9 request       DOC/GUIDES/ASM/SAMPLES/ap-store-v1-claim-b1s9-1a00.s19
CLAIM confirmation       DOC/GUIDES/ASM/SAMPLES/ap-store-v1-claim-confirm-1a20.s19
Slice 4 APOBJ envelope   SRC/BUILD/s19/ap-store-v1-object-tool-package-3000.s19
Object B1:9 O1/G1 card   DOC/GUIDES/ASM/SAMPLES/ap-store-v1-object-b1s9-o1g1-1a00.s19
APMARK envelope          SRC/BUILD/s19/ap-store-v1-marker-package-3000.s19
Object confirmation      DOC/GUIDES/ASM/SAMPLES/ap-store-v1-object-confirm-1a40.s19
Four-bank CRC source     DOC/GUIDES/ASM/SAMPLES/str8n-v1.2-bank-crc-all-3000.a
```

The four static helper transports are deliberately tiny and inspectable:

```text
; ap-store-v1-claim-b1s9-1a00.s19
S1141A00A9018D007C8D017CA9098D027C9C037C60DC
S9031A00E2

; ap-store-v1-claim-confirm-1a20.s19
S1091A20A9A58D037C6002
S9031A20C2

; ap-store-v1-object-b1s9-o1g1-1a00.s19
S1231A00A9018D017CA9098D027C9C307CA9308D317C9C327C8D337CA9018D347C9C357C3C
S10D1A208D367C9C377C9C387C607A
S9031A00E2

; ap-store-v1-object-confirm-1a40.s19
S1091A40A9A58D387C60AD
S9031A40A2
```

Expected loader reports are `$0011/$1A00`, `$0006/$1A20`, `$002A/$1A00`,
and `$0006/$1A40`, respectively. The CRC item is ASM source: paste it into
`ASM NEW`, terminate with `.`, then `ASM BYE`; its resulting S19 is loaded at
`$3000` exactly as in the captured board procedure.

## Gate Sequence

1. Capture the complete four-bank CRC table and run `APS`. Require B1:8
   `ACTIVE G=0002`, B1:9 `HEADER-FF`, and the operator-approved B1:8-E range.
2. Load `ap-store-v1-sector-tool-7000.s19`, run `G 7000`, load
   `ap-store-v1-claim-b1s9-1a00.s19`, and run `G 1A00`. Run PREPARE `$7003`,
   review the card, load `ap-store-v1-claim-confirm-1a20.s19`, run `G 1A20`,
   and run EXECUTE `$7006`. Require `$AC` and
   `APS B/S=19 ACTIVE G=0001`.
3. Load `ap-store-v1-object-tool-package-3000.s19`, which places the `$0A1E`
   AP envelope at `$3000`, then run `AP 3000 7000`. It enters LIST; set B1:9
   before calling LIST again if the initial request bytes are not already valid.
4. Load `ap-store-v1-marker-package-3000.s19` at `$3000`. Load
   `ap-store-v1-object-b1s9-o1g1-1a00.s19`, run `G 1A00`, and inspect
   `$7C01-$7C02` plus `$7C30-$7C38`.
5. Call INSTALL PREPARE with `G 7003`. This is read-only. Require status `$A0`,
   phase `$00`, record offset `$0010`, package length `$0037`, package FNV
   `B6 11 87 70`, record count zero, and equal live/prepared media CRCs. The
   built header must be:

   ```text
   41 52 01 01 03 FF 01 00 01 00 00 00 37 00
   B6 11 87 70 3F 42
   ```

6. Load `ap-store-v1-object-confirm-1a40.s19`, run `G 1A40`, and verify that
   it wrote only `$A5` to `$7C38`. Then call INSTALL EXECUTE with `G 7006`.
   Require status/return `$AC`, confirmation consumed to `$00`, and phase
   `$00`. A second `G 7006` must return `$D7` and must not mutate media.
7. Call LIST with `G 7000`. Require exactly:

   ```text
   APOBJ O=0001 G=0001 L=0037
   APOBJ OK
   ```

8. Restore the B1:9/object request if necessary and call VALIDATE with
   `G 7009`. Require `$AC`; `$0A00-$0A04` must begin `41 50 02 37 00`.
9. Call LOAD/RUN with `G 700C`. Require return `A=$AC` with carry set,
   `$7C46-$7C47=00 30`, and `$1A00=A4`.
10. Re-run the four-bank CRC table. Only B1:9 may differ from the post-CLAIM
    table. The committed record occupies sector offsets `$0010-$005B`; its
    commit byte at `$005B` is `$A5`, and `$005C-$0FFF` remains erased.
11. Cold-reset; load `ap-store-v1-object-tool-package-3000.s19`, then load
    `ap-store-v1-object-b1s9-o1g1-1a00.s19` and run `G 1A00`. Run
    `AP 3000 7000`, then repeat the unconfirmed `G 7006`, VALIDATE, and
    LOAD/RUN checks. This closes corrected `$D7` return, flash persistence,
    and reconstruction independent of prior RAM.

Append the raw transcript and all CRC tables to
`DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`. Do not mark Slice 4 accepted until the
cold path passes.

## Failure Statuses

```text
D0 bad request       D1 invalid AP       D2 not managed
D3 corrupt log       D4 duplicate id/gen D5 no space
D6 media changed     D7 not confirmed    D8 program failed
D9 verify failed     DA restore failed   DB not found
DC service/select failure
```

PREPARE parses the AP source before any flash write and snapshots the request,
package length/FNV, append offset, and full-sector CRC. EXECUTE revalidates all
of them. It programs the 20-byte header, then package bytes, then `$A5` as the
only activation step. Any earlier interruption leaves no live object.

The first B1:9 board pass proved CLAIM, append, one-record LIST, exact package
reconstruction, validation, and LOAD/RUN. It also exposed that four direct
EXECUTE rejection exits returned the failure phase in `A` even though the card
held the correct status. After correction, a cold run returned `$D7` with
carry clear, listed exactly one persistent object, reconstructed and validated
it, and loaded/ran the `$A4` marker. Only final CRC isolation remains required
before board acceptance.
