# AP Store V1 Delete And Exhaustion Board Test

Status: host-accepted candidate; board proof pending on B1:9/B1:B.

This card tests Slice 6 against the accepted Slice 5 object `$0002`, generation
`$0001`, split across B1:9 and B1:B. The user-approved writable range is
B1:8-E; B1:F remains excluded. DELETE appends only a 21-byte tombstone to the
first fitting sector in mask `$0A`. With the accepted media, B1:9 is full and
B1:B is selected at offset `$0096`.

Do not confirm DELETE unless `APS`, the complete CRC table, PLAN counters,
target, and both prepared chain rows match this card.

## Exact transports

Build all generated transports with:

```text
make -C SRC ap-store-slice6-tool-check
```

Every load below names its exact file:

```text
Purpose                         Exact file sent after HIMON L / ASM
Four-bank CRC ASM source        DOC/GUIDES/ASM/SAMPLES/str8n-v1.2-bank-crc-all-3000.a
Newest-generation request       DOC/GUIDES/ASM/SAMPLES/ap-store-v1-slice6-newest-b1-o2-1a00.s19
Exact O2/G1 DELETE request      DOC/GUIDES/ASM/SAMPLES/ap-store-v1-slice6-delete-b1-o2g1-1a00.s19
DELETE confirmation             DOC/GUIDES/ASM/SAMPLES/ap-store-v1-chain-confirm-1a40.s19
Slice 6 APNEW reader envelope   SRC/BUILD/s19/ap-store-v1-slice6-catalog-tool-package-4000.s19
Slice 6 APPLAN envelope         SRC/BUILD/s19/ap-store-v1-slice6-plan-tool-package-4000.s19
Slice 6 APDEL envelope          SRC/BUILD/s19/ap-store-v1-slice6-delete-tool-package-4000.s19
```

The three fixed BODY images are deliberately separate so all stay below
HIMON's `$7A00` command buffer:

```text
APNEW   $7000-$797F   2432 bytes   LIST/VALIDATE/LOAD at $7000/$7003/$7006
APPLAN  $7000-$7927   2344 bytes   inert $7000; read-only PLAN at $7003
APDEL   $7000-$770A   1803 bytes   inert $7000; confirmed EXECUTE at $7003
```

The two request helpers are reproduced in full:

```text
; ap-store-v1-slice6-newest-b1-o2-1a00.s19
S12D1A009C807C9C817C9C827CA9408D837CA9018D847CA90A8D857CA9028D867C9C877C9C887C9C897C9C8A7C60E4
S9031A00E2

; ap-store-v1-slice6-delete-b1-o2g1-1a00.s19
S12F1A009C807C9C817C9C827CA9408D837CA9018D847CA90A8D857CA9028D867C9C877CA9018D887C9C897C9C8A7C6047
S9031A00E2

; ap-store-v1-chain-confirm-1a40.s19
S1091A40A9A58D8A7C605B
S9031A40A2
```

Expected loader reports are `$002A/$1A00`, `$002C/$1A00`, and `$0006/$1A40`.

## Slice 6 card

```text
$7C80-$7C83 source/destination; reader destination is $4000
$7C84       bank
$7C85       selected-sector mask; bit 0 is sector 8
$7C86-$7C87 object
$7C88-$7C89 requested generation; $0000 means newest for APNEW only
$7C8A       confirmation
$7C8B       status
$7C8C-$7C8D reconstructed package length
$7C8E-$7C8F LIVE physical bytes
$7C90-$7C91 STALE physical bytes
$7C92-$7C93 FREE physical bytes
$7C94-$7C95 BLOCKED physical bytes
$7C96-$7C97 failure phase/sector
$7C98       selected tombstone sector
$7C99-$7C9A selected append offset
$7C9B-$7C9C selected-sector CRC16
$7C9D       prepared chunk count
$7CA1-$7CA2 resolved generation
$7CA3-$7CAA prepared request and package-length snapshot
$7CB0-$7CFF eight ten-byte chain/CRC rows
```

All words are little-endian in memory.

## Gate sequence

1. Cold reset and run `APS`. Require B1:9 and B1:B `ACTIVE G=0001`. Assemble
   the exact CRC source named above, load its resulting S19 at `$3000`, run
   `G 3000`, and save `$7C10-$7C4F`. Require the accepted pre-delete CRCs
   B1:9 `$65C3` and B1:B `$60E7`; stop on any other table.

2. Load the newest-generation helper, run `G 1A00`, load the APNEW envelope at
   `$4000`, then run `AP 4000 7000`. It must print:

   ```text
   APNEW O=0002 G=0001 L=1000
   APNEW OK
   ```

   Require status `$AC`, resolved generation `$0001` at `$7CA1-$7CA2`, and
   `D 0A00 0A04 = 41 50 02 00 10`. `G 7003` must validate again; `G 7006`
   must load/run at `$4000` and leave `$1A01=C5`.

3. Load the exact DELETE helper and run `G 1A00`. Load APPLAN at `$4000` and
   run `AP 4000 7000`; its `$7000` entry only returns. Run read-only PLAN with
   `G 7003`. Require status/return `$A0`, confirmation `$00`, package length
   `$1000`, resolved generation `$0001`, two chunks, and these counters:

   ```text
   LIVE=$102A  STALE=$0000  FREE=$0F6A  BLOCKED=$0000
   ```

   Require target B1:B, offset `$0096`, prepared CRC `$60E7`, and exact rows:

   ```text
   09 01 5C 00 00 00 8F 0F C3 65
   0B 02 10 00 8F 0F 71 00 E7 60
   ```

4. The exact tombstone PLAN will append at B1:B+$0096 is:

   ```text
   41 52 01 02 00 FF 02 00 01 00 00 00 00 00 C5 9D 1C 81 AB 45 A5
   ```

   The 20-byte header ends in CRC16 `$45AB`; `$A5` is the separately written
   commit byte. No payload exists.

5. Load the confirmation helper, run `G 1A40`, and verify only `$7C8A=A5`.
   Load APDEL at `$4000`, run `AP 4000 7000`, then run `G 7003`. Require
   return/status `$AC`, confirmation consumed to `$00`, and failure
   phase/sector zero. An immediate second `G 7003` must return `$D7` without
   selecting or changing flash.

6. Reload the exact DELETE helper and APPLAN. A new `G 7003` must return
   `ALREADY DELETED` `$E1`; it must not prepare or append another record.
   Reload APNEW with the exact-generation helper: LIST/VALIDATE must also
   return `$E1`. Reload APNEW with the newest helper: LIST/VALIDATE must return
   `NOT FOUND` `$DB`, because this board currently has no older generation of
   object `$0002`.

7. Run `APS`; sector headers remain unchanged. Re-run the complete CRC table.
   A zero-payload tombstone header plus commit is CRC-neutral relative to the
   erased 21-byte tail under this CRC16, so the expected complete table is
   byte-for-byte identical, including B1:B `$60E7`. Persistence is therefore
   proved by the cold `$E1/$DB` catalog results, not by claiming a CRC delta.

8. Cold reset. Repeat exact `$E1`, newest `$DB`, `APS`, and the complete CRC
   table using the same named files. Append the terminal transcript and both
   complete CRC tables to `DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`.

## Stop conditions

Stop without confirmation on any unexpected sector class, CRC, plan row,
counter, target, offset, nonzero failure field, or status. Do not widen the
mask, substitute B1:F, reformat a sector, or attempt compaction. Slice 6 is
append-only and reclaim remains deferred.
