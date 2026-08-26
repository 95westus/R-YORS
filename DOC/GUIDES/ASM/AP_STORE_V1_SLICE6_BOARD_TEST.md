# AP Store V1 Delete And Exhaustion Board Test

Status: host- and board-accepted 2026-08-25. The frozen firmware
identity remains HIMON/ASM-F2 `00.0825(2135)`.

This is a frozen Slice 6 evidence card. Its hashes and verbose `APS` spellings
belong to the tested 2026-08-25 binaries; do not use them as current Slice 7
file identity. The current configuration bytes are
`1E 1F FF FF FF FF FF FF FF FF`, and current `APS` labels B1:E/B1:F as
`= WORK`/`= BKUP B3F`.

This card tests Slice 6 against the accepted Slice 5 object `$0002`, generation
`$0001`, split across B1:9 and B1:B. The current AP-eligible writable range is
B1:8-D; B1:E is WORK and B1:F is the protected Bank-3:F backup. DELETE appends only a 21-byte
tombstone to the first fitting sector in mask `$0A`. With the accepted media,
B1:9 is full and B1:B is selected at offset `$0096`.

Do not confirm DELETE unless `APS`, the complete CRC table, PLAN counters,
target, and both prepared chain rows match this card.

This is a destructive append-only test. It requires the accepted Slice 5
object on B1:9/B1:B and consumes 21 bytes at B1:B+$0096. Bank 1 sector F must
also be sacrificial if the top-sector updater is needed. Stop rather than
trying to manufacture or repair either prerequisite during this run.

## Frozen firmware and configuration

Install the current Bank-3 `$8000-$EFFF` payload before this test. If Bank 3
does not already contain this exact build, use STR8-N `I`, Bank `3`, range
`8-E`, and send:

```text
C:/SRC/R-YORS/RELEASE/ryors-v1.2-himon-asm-bank3-8-e.s19
SHA-256 491AF17E56E049C2F0A5FB8D0962756A8C6BF6F069D01E5FA10DFE616125E38F
range $8000-$EFFF; S9 $C000; 28672 payload bytes
```

The WORK locator is in Bank 3 sector F, so installing only `8-E` does not set
it. If Bank 3 `$FFF0-$FFF9` is not already
`1E FF FF FF FF FF FF FF FF FF`, return to `STR8-N>`, type `L`, and send:

```text
C:/SRC/STR8-N/BUILD/v1.22/s19/str8n-v1.22-top-update-2000.s19
SHA-256 BD21DAD3D42004718AD753743ED202408CB5B2CF86EF59DCAD7611BCA9E37C86
```

Require `BACKUP B1:F; TARGET B3:F`, confirm `BACKUP B1F` only after verifying
B1:F may be replaced by the protected backup, require `BACKUP VERIFIED`, and then confirm
`STR8-N 1.22`. Do not reset, press NMI, or interrupt power while sector F is
active. Use the normal top updater, not Directory Refresh; the normal updater
preserves the live directory while installing `$FFF0=$1E`.

After reset, require HIMON/ASM-F2 `00.0825(2135)`, dump Bank 3
`$FFF0-$FFF9`, and require the exact ten bytes above. Then run `APS` and
require B1:E `WORK` before proceeding. This firmware/configuration gate is
setup only; it is not Slice 6 acceptance.

## Exact transports

Build all generated transports with:

```text
make -C SRC ap-store-slice6-tool-check
```

Every load below names its exact file:

```text
Purpose                         Exact file sent after HIMON L / ASM
Four-bank CRC ASM source        DOC/GUIDES/ASM/SAMPLES/str8n-v1.2-bank-crc-all-3000.a
Read-only B1:B stage diagnostic DOC/GUIDES/ASM/SAMPLES/ap-store-v1-slice6-stage-b1sb-1a00.s19
Newest-generation request       DOC/GUIDES/ASM/SAMPLES/ap-store-v1-slice6-newest-b1-o2-1a00.s19
Exact O2/G1 DELETE request      DOC/GUIDES/ASM/SAMPLES/ap-store-v1-slice6-delete-b1-o2g1-1a00.s19
DELETE confirmation             DOC/GUIDES/ASM/SAMPLES/ap-store-v1-chain-confirm-1a40.s19
Slice 6 APNEW reader envelope   SRC/BUILD/s19/ap-store-v1-slice6-catalog-tool-package-4000.s19
Slice 6 APPLAN envelope         SRC/BUILD/s19/ap-store-v1-slice6-plan-tool-package-4000.s19
Slice 6 APDEL envelope          SRC/BUILD/s19/ap-store-v1-slice6-delete-tool-package-4000.s19
```

Freeze the transports by hash before connecting to the board:

```text
CRC source       E3E34437E5326187E52242AF328241E009DEB89E1A9B87FCFC2D77DBFBF89748
stage diagnostic 42765B1C0383463B6AEF3BDE3577C7C8CD6CCA4E171B87B7279C22898B024AB8
newest helper    B9A3D9A3C9C60349E05F25450594CA104782D85F9700BC8115141644B07D9360
DELETE helper    ECBDCEC74ACA24E7BD2EB6B8ED4C5151E51F15C6250448820FA90EFFF9496FA0
confirmation     BBA7853CD6E0CFEEF720383C0B44551EF512BBA127551C21A07E2D726B14ECA6
APNEW envelope   D3E1265ED760E75ACE0426A8789DEF76C3A58CE581135E35B9D97BB6F6871C81
APPLAN envelope  9A681EC9C5D55A5661ED34EA36339BA78B2DC02B4AE1E6855D6B7D0C4511A4D5
APDEL envelope   28A1B9FAA3C2B0732167B7D5A2598A7AA4C74B828B47C11097079261A042DE80
```

The three fixed BODY images are deliberately separate so all stay below
HIMON's `$7A00` command buffer:

```text
APNEW   $7000-$79B4   2485 bytes   LIST/VALIDATE/LOAD at $7000/$7003/$7006
APPLAN  $7000-$7971   2418 bytes   inert $7000; read-only PLAN at $7003
APDEL   $7000-$773F   1856 bytes   inert $7000; confirmed EXECUTE at $7003
```

The envelope loader reports are APNEW `$09E3/$4000`, APPLAN `$09A0/$4000`,
and APDEL `$076E/$4000`. Always send the named `package-4000.s19` envelope;
do not send a `*-7000.s19` BODY through HIMON `L`.

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

1. Start a complete terminal capture, cold reset, and run `APS`. Require B1:E
   `WORK` and B1:9/B1:B `ACTIVE G=0001`. Assemble the exact CRC source named
   above, load its resulting S19 at `$3000`, run `G 3000`, and save
   `$7C10-$7C4F`. Require the accepted pre-delete CRCs B1:9 `$65C3` and B1:B
   `$60E7`; stop on any other table.

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

   Before confirmation, capture and require these exact card bytes:

   ```text
   D 7C8A 7C9D
   00 A0 00 10 2A 10 00 00 6A 0F 00 00 00 00 0B 96 00 E7 60 02

   D 7CA1 7CAA
   01 00 01 0A 02 00 01 00 00 10
   ```

   In particular, failure phase/sector must be `00 00` and the prepared
   generation at `$7CA7-$7CA8` must be `01 00`.

4. The exact tombstone PLAN will append at B1:B+$0096 is:

   ```text
   41 52 01 02 00 FF 02 00 01 00 00 00 00 00 C5 9D 1C 81 56 62 A5
   ```

   The 20-byte header ends in CRC16 `$6256`, stored low byte first as `56 62`;
   `$A5` is the separately written
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
   Only B1:B changes, from `$60E7` to `$37A8` (stored `A8 37`), because the
   21-byte tombstone replaces its erased tail at offset `$0096`. Require:

   ```text
   7C10: 79 55 07 D5 D0 AC DF EF | DF EF DF EF DF EF 07 D0
   7C20: 48 F2 C3 65 E1 0F A8 37 | E1 0F E1 0F E1 0F 99 34
   7C30: E1 0F E1 0F E1 0F E1 0F | E1 0F E1 0F E1 0F E1 0F
   7C40: 83 61 92 C8 30 A1 AC F7 | 49 1C 95 FE BE 2C F3 7C
   ```

   The read-only stage diagnostic may be loaded at `$1A00` (`L OK=000E`) and
   run while the CRC fixture remains at `$3000`; `D 4090 40AF` must show the
   exact record above at `$4096-$40AA`.

8. Cold reset. Repeat exact `$E1`, newest `$DB`, `APS`, and the complete CRC
   table using the same named files. Append the terminal transcript and both
   complete CRC tables to `DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`.

## 2026-08-25 board acceptance

HIMON/ASM-F2 `00.0825(2135)` reported B1:E `WORK` and retained the accepted
B1:9/B1:B generation-1 chain. Revised PLAN returned `$A0` with the exact two
rows, target B1:B+$0096, prepared CRC `$60E7`, generation `$0001`, and zero
failure fields. Confirmed APDEL returned `$AC`; replay returned `$D7`.

Warm and post-`HCOLD` exact lookup returned `$E1`, while newest LIST and
VALIDATE both returned `$DB`. The complete post-delete and cold CRC tables
matched byte for byte. Only B1:B changed, from `$60E7` to `$37A8`. The
read-only stage diagnostic showed the exact 21-byte tombstone at `$4096`,
including header CRC bytes `56 62` and commit `$A5`. This accepts mutation
isolation, exact/newest visibility, repeat-delete rejection, and cold
persistence.

## 2026-08-25 fail-closed diagnostic

The first board attempt passed firmware/configuration, `APS`, the complete
pre-delete CRC table, APNEW LIST/VALIDATE/LOAD, and read-only PLAN. The old
APPLAN envelope SHA-256
`3465F3D65E75017CB3E37B04AE2A6E6684FC1EE8D75B8782140A061DF44CE541`
returned `$A0`, but exposed `$7CA7-$7CA8=00 00` instead of the exact generation
and left the last-scanned sector in `$7C97`. APDEL then rejected generation
zero with `$D0` before selector boot or any flash-program call. No DELETE was
performed.

The revised planner restores `$7C88-$7C89` from resolved generation
`$7CA1-$7CA2` before saving the executor snapshot and clears both diagnostic
bytes on successful PLAN. Resume with the exact DELETE helper and revised
APPLAN envelope at Gate 3; the firmware, top sector, accepted Slice 5 media,
APNEW envelope, APDEL envelope, and helper files are unchanged.

## Stop conditions

Stop without confirmation on any unexpected sector class, CRC, plan row,
counter, target, offset, nonzero failure field, or status. Do not widen the
mask, substitute B1:F, reformat a sector, or attempt compaction. Slice 6 is
append-only and reclaim remains deferred.
