# STR8 Size-Pass On-Board Acceptance Card

Status: **ACCEPTED on hardware 2026-07-28**. The frozen HIMON, ASM-F2, and
STR8 candidate passed all resident, worker, record-service, loader, restore,
legacy-compatibility, reset, and four-bank convergence gates in sections
4-13. The final state has the exact candidate in all four banks, `$FFF0=$FF`
in every bank, and the pinned cold-boot vectors. No bench action remains for
this pass.

The latest run positively copied Bank 3 to Bank 0, making Bank 0 exact, then
performed a normal Bank-0 restore with high flash declined. Both operations
returned `OK`. Because the source and destination were identical by then,
this was not the planned differential high-flash proof. The post-operation CRC
then showed Banks 0, 2, and 3 exact and Bank 1 unchanged. This closes the
positive `B0` selected-destination/no-cascade gate and confirms the same-image
restore ended canonical.

A later run typed main-menu `1`, which performed a full Bank-1-to-Bank-3
restore rather than a backup. Bank 1 still had erased lower sectors, so ASM
temporarily disappeared; `L F` restored the current ASM. Subsequent Bank-0
normal and high restores used exact images. The final CRC again showed Banks
0, 2, and 3 exact and Bank 1 distinctive. The board is recovered, but no
positive Bank-1 backup has occurred.

The positive Bank-1 backup then printed only `COPY B3->B1`, returned `OK`, and
the complete CRC table converged to the pinned row in all four banks. The
backup destination/copy paths for Banks 0, 1, and 2 now pass. The operator
confirms the final bare `B` response was destination `3`, not empty input.
STR8 intentionally echoes a destination only after it passes the `0`-through-
`2` range check, so the unechoed `3` followed by `ABORT` is the expected
invalid-destination result.

The section-8 worker-tail fixture then assembled cleanly and returned
`AC 05 46 46`: all five cases passed and Bank-3 `$8000` remained `$46`.
That intermediate run ended at HIMON before the section-9 continuation.

## Accepted Final State

The final continuation completed sections 9-13:

```text
record service  L OK=07BB GO=3000
                A/X/Y = AC/0F/01, AC/06/02, AC/01/03, AC/01/04
L G transport   L OK=0080 GO=3000; $4900=A5
L F             matching, erased-byte, repeated-byte, and NEED_ERASE paths pass
U negatives     empty and out-of-range inputs fail before PROGRAM
legacy $FE      accepted as unprotected; B3->B0 succeeds
normal restore  B0 $FFF0=FE remains distinct from B3 $FFF0=FF
cleanup         all four CRC rows converge to the pinned candidate
final reset     BOOT COLD; FFF0=FF ... vectors 98 F0 00 F0 AC F0
```

The differential normal-restore proof is decisive: before and after
`RESTORE B0->B3` with the high-flash answer `n`, Bank 0 retained the `$FE`
F-sector row ending `4A B0`, while Bank 3 retained the canonical `$FF` row
ending `6E 18`. A final `B3->B0` copy restored the canonical four-bank state.

### Earlier Resume History

The 2026-07-28 continuation captured this useful differential state:

```text
Bank 0  unchanged from the first PRE capture
Bank 1  erased lower half plus current C-F
Bank 2  exact candidate
Bank 3  exact candidate after the final U plus L F
```

The accepted `RUN2-PRE` capture is:

```text
RET A=AC ... C
1A00: AC 00 00 00 00
1A08: FF FF FF FF
1A10: 3A FC 4E 26 D9 A8 E1 0F E1 0F E1 0F E1 0F E1 0F
1A20: E1 0F E1 0F E1 0F E1 0F C6 84 1A F2 47 98 6E 18
1A30: EC B7 36 70 CE 76 34 9B C6 84 1A F2 47 98 6E 18
1A40: EC B7 36 70 CE 76 34 9B C6 84 1A F2 47 98 6E 18
```

The accepted positive Bank-2 transcript was:

```text
BACKUP B3 TO B0/1/2:  2 ERASE? Y: y
COPY B3->B2

OK
```

Its complete post-copy table matched `RUN2-PRE`; in particular, Bank 1 kept
all four `E1 0F` lower-sector pairs. The old `B2->B1` cascade did not occur.

The latest run changed the setup before the planned differential restore:

```text
BACKUP B3 TO B0/1/2:  0 ERASE? Y: y
COPY B3->B0

OK
RESTORE B0->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: n
COPY B0->B3

OK
```

The positive Bank-0 backup made Bank 0 exact before the restore. Therefore
the normal restore exercised the correct lower-only prompt and return path,
but it was a same-image restore rather than the planned differential proof.
Bank 3 should already be exact; do not perform a Bank-2 recovery.

The accepted post-operation capture was:

```text
1A08: FF FF FF FF
1A10: EC B7 36 70 CE 76 34 9B C6 84 1A F2 47 98 6E 18
1A20: E1 0F E1 0F E1 0F E1 0F C6 84 1A F2 47 98 6E 18
1A30: EC B7 36 70 CE 76 34 9B C6 84 1A F2 47 98 6E 18
1A40: EC B7 36 70 CE 76 34 9B C6 84 1A F2 47 98 6E 18
```

This proves the positive `B0` copy changed only its selected distinctive
destination, Bank 1 remained untouched, and the same-image normal restore
ended on the exact candidate. The stronger high-flash differential proof is
deferred to section 12, where Bank 0's deliberate `$FFF0=FE` image provides a
detectably different high sector.

The accepted positive Bank-1 result is:

```text
BACKUP B3 TO B0/1/2:  1 ERASE? Y: y
COPY B3->B1
OK
```

`$1A08-$1A0B` was `FF FF FF FF`, and all four rows were:

```text
EC B7 36 70 CE 76 34 9B C6 84 1A F2 47 98 6E 18
```

The operator confirms destination `3` was entered in the final check:

```text
STR8-N>B
BACKUP B3 TO B0/1/2:
ABORT
```

This output is correct. In `STR8_CMD_BACKUP`, invalid values branch to
`ABORT` before the console-write call that republishes valid `0`, `1`, or `2`
destinations. There was no `ERASE?`, `COPY`, or reset. Sections 6 and 7 are
complete.

The accepted worker-tail result is:

```text
RET A=AC X=03 Y=00 ... C
1A00: AC 05 46 46
8000: 46
```

This closed section 8 in the intermediate run. Sections 9-13 were subsequently
completed as recorded above and in the hardware log.

This is the bench card for the resident and worker size pass, the explicit
`B` destination, and removal of `E`/Bank-0 enrollment. It gives the exact
candidate, files, paste blocks, expected bytes, destructive boundaries, and
stop conditions. Run it in order. Do not rebuild or substitute an artifact
during the board session.

## 1. Frozen Candidate

The candidate uses:

```text
HIMON V 00.0728(1751)
ASM-F2 00.0728(1751)
STR8-N V0 #5F6A0F7A
```

Reproduce it on the host with:

```text
make -C SRC all str8-topwrite-a str8-top-stage-s19 himon-str8-himon-update-s19 str8-record-phase1-proof str8-l-transport-phase5-proof bank3-erase "HIMON_VISIBLE_STAMP=0728(1751)" "ROM_BIN_STAMP=2026-07-28T17:51-05:00"
```

PowerShell can verify each file with:

```text
Get-FileHash -Algorithm SHA256 -LiteralPath <path>
```

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `SRC/BUILD/bin/himon-str8-rom.bin` | 32768 | `F0CBE556036E1DCBC027982A83ADDCCE8E3E26C3FD1A4ADD7D62DD0D65AA1DA5` |
| `SRC/ROM_IMAGES/himon-str8-rom-2026-07-28T17-51-05-00.bin` | 32768 | `F0CBE556036E1DCBC027982A83ADDCCE8E3E26C3FD1A4ADD7D62DD0D65AA1DA5` |
| `SRC/BUILD/s19/himon-str8-rom-install.s19` | 77836 | `EDCE38145D73A4EDB41474C3DF8061E963FC0E13BA8B9739C06EAF8325406E55` |
| `SRC/BUILD/s19/himon-str8-himon-update.s19` | 28436 | `3DD9BBE29C59B54784BA50280C033080FEDED779C125CF267FB2D53B92258B94` |
| `SRC/BUILD/s19/asm-v1-flash-8000.s19` | 42554 | `12D17636D9DF75B4F63CF98BAF64B726AB9CA2C82C5ABF2DF86B2163898ED139` |
| `SRC/BUILD/s19/str8-top-stage-0a00.s19` | 9740 | `EA52FC51B4D4B2655950687E5C09115146B3A4957671CDF682813E61DE6745A2` |
| `DOC/GUIDES/ASM/SAMPLES/str8n-topwrite-transient-3000.a` | 28234 | `37CF44D797788C32C291BC4FF255BF87F98A004E66AC5AC62C6D7B5A6AD4B366` |
| `DOC/GUIDES/ASM/SAMPLES/bank3-erase-8000-bfff-transient-3000.a` | 2049 | `0139D3A991A1A050956361E8C34EDE3E87B0A501B6D29B780F7CACCD346ABCEA` |
| `DOC/GUIDES/ASM/SAMPLES/str8-bank-crc-all-3000.a` | 3092 | `D92C504C1501241F3FC791C11F081178E4B053211C3D9F7B15B5F1A5F7891326` |
| `DOC/GUIDES/ASM/SAMPLES/str8-worker-tail-proof-3000.a` | 3515 | `4CC88D6A66120357B0364CBF52A755AFE03EC7FDC7B5729E3B06F3658303A620` |
| `SRC/BUILD/s19/str8-record-phase1-proof-3000.s19` | 5458 | `CAC1B8F3C955898F112DBC68F8E2E490068098265C3765BD047CFD5041947006` |
| `SRC/BUILD/s19/str8-l-transport-phase5-proof-3000.s19` | 364 | `BB9D30C483A114502AE021A64961F1FE1D4C8E8895AD0A08E0781476C45C7002` |
| `DOC/GUIDES/ASM/SAMPLES/str8-record-phase1-max252.s19` | 515 | `1398593029F74A78FD6843E3F80D499F9ACDC224559780E1C269F973D1D380EC` |

The full binary maps to physical Bank 3 `$8000-$FFFF`. Keep it ready for an
external programmer before the first flash write. The full install S19 is also
a recovery artifact; it is not input to HIMON `L`, `L F`, or `STR8 U`.

## 2. Which File Goes Where

| File | Board receiver | Purpose |
| --- | --- | --- |
| `himon-str8-rom.bin` | external programmer | Complete Bank-3 recovery/image install |
| `himon-str8-rom-install.s19` | external programmer or full-ROM installer | Complete `$8000-$FFFF` image |
| `himon-str8-himon-update.s19` | STR8 `U`, after `SEND S19 C000-EFFF` | Current HIMON `$C000-$EFFF` |
| `asm-v1-flash-8000.s19` | HIMON `L F` | Current ASM-F2 `$8000-$BC6C` |
| `str8n-topwrite-transient-3000.a` | complete source paste after `ASM NEW` | Self-contained STR8 `$F000-$FFFF` writer |
| `bank3-erase-8000-bfff-transient-3000.a` | complete source paste after `ASM NEW` | Erase Bank 3 low flash before exact ASM install |
| `str8-bank-crc-all-3000.a` | complete source paste after `ASM NEW` | Read-only CRC of all 32 flash sectors |
| `str8-worker-tail-proof-3000.a` | complete source paste after `ASM NEW` | RAM-only shared worker-tail proof |
| `str8-record-phase1-proof-3000.s19` | HIMON `L` | STR8 record-service regression suite |
| `str8-record-phase1-max252.s19` | raw line while `G 3006` waits | One maximum-length console record |
| `str8-l-transport-phase5-proof-3000.s19` | HIMON `L G` | Short serial transport/read-thunk proof |

The topwriter already embeds the complete top sector. Do not also load
`str8-top-stage-0a00.s19` when using the one-file topwriter route.

## 3. Global Safety And Stop Rules

Before starting:

1. Confirm stable power and serial flow control.
2. Keep the frozen full binary available to an external programmer.
3. Treat Bank 3 as the live bank and Banks 0-2 as sacrificial only when their
   individual `B` test begins.
4. Save any Bank 0-2 content that must survive. The backup tests intentionally
   replace all three backup banks, one at a time.
5. End every ASM session with `.` before using a HIMON command.
6. Do not type `G 3003` unless the immediately preceding topwriter stage and
   byte dumps match this card.

Stop immediately on:

- any unexpected reset during erase/program;
- `COPY FAIL`, `LF FAIL` outside the deliberate needs-erase case, `TW ERR`,
  `$1A00/$1A01` other than the expected value, or clear carry on a positive
  proof;
- a candidate byte, version, hash, CRC, or vector mismatch;
- output naming an unselected backup bank;
- loss of the HIMON or STR8 prompt after the documented wait.

Preserve the terminal transcript and do not retry a destructive command until
the failure address/status has been captured.

## 4. Install The Exact Bank-3 Candidate On Board

Skip a subsection only when its exact pinned version is already installed.

### 4.1 Require a compatible starting STR8 provider

From HIMON:

```text
>D F00C F00F
```

Require:

```text
F00C: 53 52 01 07
```

If this V1 record-service face is absent, stop and use the external programmer
with the frozen full binary. Do not install the new HIMON client in front of an
unknown STR8 provider.

### 4.2 Install the pinned HIMON C/D/E image

Enter STR8 and press `S` during the countdown:

```text
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

HIMON IN 3S. S=STR8-N  3
```

At `STR8-N>`:

```text
U
UPDATE HIMON C000-EFFF? Y:y
SEND S19 C000-EFFF
```

Send exactly:

```text
SRC/BUILD/s19/himon-str8-himon-update.s19
```

It has 374 S1 records, begins:

```text
S123C00078D8A2FF9AADE67EC9A5D024ADE77EC95AD01DADE87EC9C3D016ADE97EC93CD08E
```

and ends:

```text
S123EEA06AAA59FF6AAA5DFF5AAA59FF6AA95DFD5AAA59FF6AA95DFDFFFFFFFFFFFFFFFFE8
S903C0003C
```

Require one progress dot per accepted S1, then:

```text
PROGRAM C000-EFFF? Y:y
OK
STR8-N>G
G HIMON
BOOT WARM

HIMON V 00.0728(1751)
```

Do not assemble the topwriter before `U`; `U` owns `$4000-$4FFF` and would
overwrite the embedded image.

### 4.3 Install the pinned ASM-F2 low image

First try:

```text
>ASM NEW
```

If the banner is already `ASM-F2 00.0728(1751)`, enter `.` and continue to
4.4. Otherwise, while the old ASM is still present, paste the complete text of:

```text
DOC/GUIDES/ASM/SAMPLES/bank3-erase-8000-bfff-transient-3000.a
```

End the ASM session with `.`, then:

```text
>G 3000
>D 1A00 1A03
>D 8000 800F
```

Require:

```text
RET A=AC ... C
1A00: AC 00 00 00
8000: FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
```

ASM has now erased itself. Do not invoke `ASM`. Load the exact new image:

```text
>L F
L F S19
```

Send:

```text
SRC/BUILD/s19/asm-v1-flash-8000.s19
```

Require:

```text
L @8000
LF OK WR=3C6D GO=800C
>D 8000 800F
8000: 46 4E D6 00 74 AD 56 05 0C 80 87 B9 20 7B 85 B0
>ASM NEW
ASM-F2 00.0728(1751)
ASM>$2000: .
ASM BYE
```

### 4.4 Stage the new STR8 top sector

At HIMON:

```text
>ASM NEW
```

Paste the complete text of:

```text
DOC/GUIDES/ASM/SAMPLES/str8n-topwrite-transient-3000.a
```

The file ends with `END`. Enter `.` at `SEAL>` and require `ASM BYE` with no
`ERR=`. Then:

```text
>G 3000
GO 3000
TW STG
TW OK

#GO# ENTRY=3000
RET A=AC ... C
>D 1A00 1A03
>D 0A00 0A0F
>D 1244 1247
>D 1760 176F
>D 19E0 19EF
>D 19F0 19FF
```

Require:

```text
1A00: 00 AC 00 00
0A00: 4C 10 F0 4C CB F2 4C D2 F2 4C DA F2 53 52 01 07
1244: 7A 0F 6A 5F
1760: 08 78 AD F0 1F C9 05 F0 0D C9 06 F0 0E C9 07 F0
19E0: 04 48 A9 EE 1C EC 7F 68 0C EC 7F 60 CC CE EC EE
19F0: FF FF FF FF FF FF FF FF FF FF 98 F0 00 F0 AC F0
```

`$19F0-$19F9` being erased is intentional. If one byte differs, stop. Do not
run `G 3003`.

### 4.5 Program and verify the top sector

With programmer recovery still ready:

```text
>G 3003
GO 3003
TW PRG
TW OK

#GO# ENTRY=3003
RET A=AC ... C
>D 1A00 1A03
```

Require:

```text
1A00: 01 AC 00 00
```

Cold boot, then:

```text
>D F000 F00F
>D F844 F847
>D FD60 FD6F
>D FFE0 FFEF
>D FFF0 FFFF
```

Require:

```text
F000: 4C 10 F0 4C CB F2 4C D2 F2 4C DA F2 53 52 01 07
F844: 7A 0F 6A 5F
FD60: 08 78 AD F0 1F C9 05 F0 0D C9 06 F0 0E C9 07 F0
FFE0: 04 48 A9 EE 1C EC 7F 68 0C EC 7F 60 CC CE EC EE
FFF0: FF FF FF FF FF FF FF FF FF FF 98 F0 00 F0 AC F0
```

Also require:

```text
HIMON V 00.0728(1751)
ASM-F2 00.0728(1751)
```

## 5. Install And Run The Read-Only Bank Fingerprint Fixture

At HIMON:

```text
>ASM NEW
```

Paste the complete text of:

```text
DOC/GUIDES/ASM/SAMPLES/str8-bank-crc-all-3000.a
```

End with `.`, then:

```text
>G 3000
>D 1A00 1A04
>D 1A08 1A0B
>D 1A10 1A4F
```

Allow the fixture to read all 32 sectors. It never erases or programs flash.
Require `RET A=AC` with carry set and:

```text
1A00: AC 00 00 00 00
```

Result layout:

```text
1A08-1A0B  byte $FFF0 from Banks 0, 1, 2, 3
1A10-1A1F  Bank 0 CRCs, sectors 8-F, low byte then high byte
1A20-1A2F  Bank 1 CRCs
1A30-1A3F  Bank 2 CRCs
1A40-1A4F  Bank 3 CRCs
```

The exact pinned Bank-3 row is:

```text
1A40: EC B7 36 70 CE 76 34 9B C6 84 1A F2 47 98 6E 18
```

Those pairs represent:

```text
$8000 B7EC  $9000 7036  $A000 76CE  $B000 9B34
$C000 84C6  $D000 F21A  $E000 9847  $F000 186E
```

Require `$1A0B=FF`. Save the complete result as `PRE`. Do not rely on visual
similarity: compare all 16 bytes of every affected row.

## 6. Command-Surface Gate

Enter STR8 and press `S` during the countdown. Run:

```text
STR8-N>?
STR8-N V0 #5F6A0F7A

STR8-N>E
?

STR8-N>3
?
```

`?` must print only the identity; there must be no `B0 HOLD`, `B0 ROT`, or
enrollment state. `E` and `3` must use the unknown-command path.

Decline each restore before any write:

```text
STR8-N>0
RESTORE B0->B3? Y:n
ABORT

STR8-N>1
RESTORE B1->B3? Y:n
ABORT

STR8-N>2
RESTORE B2->B3? Y:n
ABORT
```

Reject invalid backup destinations:

```text
STR8-N>B
BACKUP B3 TO B0/1/2: 3
ABORT
```

Repeat with `E`, `/`, and Enter if desired. There must be no `ERASE?`, `COPY`,
or reset for invalid input.

## 7. `B` No-Cascade And Restore Regression

Each full-bank copy can take tens of seconds. Do not reset while it is active.

### 7.1 Back up only to Bank 0

At STR8:

```text
STR8-N>B
BACKUP B3 TO B0/1/2: 0
0 ERASE? Y:y

COPY B3->B0
OK
```

There must be no `B2->B1`, `B1->B0`, or second copy line. Return to HIMON:

```text
STR8-N>G
G HIMON
BOOT WARM
>G 3000
>D 1A08 1A0B
>D 1A10 1A4F
```

Call this `POST-B0`. Require:

- Bank 0 `$1A10-$1A1F` equals pinned Bank 3 `$1A40-$1A4F`;
- Bank 1 `$1A20-$1A2F` equals its `PRE` row;
- Bank 2 `$1A30-$1A3F` equals its `PRE` row;
- Bank 3 remains the pinned row.

### 7.2 Prove ordinary restore preserves high flash

This exact block assumes the `PRE` Bank-2 lower row differs from Bank 3. If it
does not, use Bank 1 instead and substitute `1` for `2`. Do not proceed unless
the chosen source has at least one different CRC in sectors 8-B.

```text
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y
press S during countdown

STR8-N>2
RESTORE B2->B3? Y:y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y:n

COPY B2->B3
OK
STR8-N>G
```

The CRC fixture is still in RAM:

```text
>G 3000
>D 1A30 1A4F
```

Require Bank 3 sectors 8-B to equal the selected source's `PRE` sectors 8-B,
and Bank 3 sectors C-F to remain:

```text
C6 84 1A F2 47 98 6E 18
```

This is the normal-restore high-protection proof.

### 7.3 Restore the exact candidate through the high-flash path

Bank 0 now contains the exact candidate. At STR8:

```text
STR8-N>0
RESTORE B0->B3? Y:y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y:y

COPY B0->B3
```

The high restore resets instead of returning through replaced ROM. Require a
new STR8/HIMON boot through vectors `98 F0 00 F0 AC F0`. Reassemble the CRC
fixture from section 5 because a reset may clear RAM, then require the pinned
Bank-3 row again.

### 7.4 Back up only to Banks 1 and 2

For Bank 1:

```text
STR8-N>B
BACKUP B3 TO B0/1/2: 1
1 ERASE? Y:y

COPY B3->B1
OK
```

Return to HIMON and rerun the CRC fixture. Require Bank 1 to equal Bank 3,
Bank 0 to remain equal to Bank 3, and Bank 2 to retain its immediately previous
row.

For Bank 2:

```text
STR8-N>B
BACKUP B3 TO B0/1/2: 2
2 ERASE? Y:y

COPY B3->B2
OK
```

Return to HIMON and rerun the CRC fixture. Require all four 16-byte rows to be:

```text
EC B7 36 70 CE 76 34 9B C6 84 1A F2 47 98 6E 18
```

This closes the selected-destination and no-cascade gate.

## 8. Shared Worker Tail And Failure Gate

At HIMON:

```text
>ASM NEW
```

Paste the complete text of:

```text
DOC/GUIDES/ASM/SAMPLES/str8-worker-tail-proof-3000.a
```

End with `.`, then:

```text
>G 3000
>D 1A00 1A03
>D 8000 8000
```

Require:

```text
RET A=AC ... C
1A00: AC 05 46 46
8000: 46
```

The five cases prove the current stored worker bounds, shared poll success,
forced shared-poll timeout/reset, impossible 0→1 write rejection, and the
factored unlock/reset tail. The fixture does not issue erase or program
commands. `$E1` identifies the failing case in `$1A01`; stop and retain the
row.

## 9. STR8 Record-Service Regression

### 9.1 Load the current-face proof

At HIMON:

```text
>L
L S19
```

Send:

```text
SRC/BUILD/s19/str8-record-phase1-proof-3000.s19
```

Require:

```text
L @3000
L OK=07BB GO=3000
```

Do not use `L G`; the four entries are separate.

```text
>G 3000
>D 1A00 1A17
>D 6000 6003
```

Require `RET A=AC X=0F Y=01` with carry set, `$1A00=AC`, and:

```text
6000: 11 22 33 44
```

Then:

```text
>G 3003
>D 1A00 1A17
```

Require `RET A=AC X=06 Y=02` with carry set and `$1A00=AC`. This covers
zero-length, protected range, crossing range, need-erase, and matching-record
publication without programming a differing byte.

### 9.2 Maximum console record and Ctrl-C

Run:

```text
>G 3006
```

Send the single complete CR-terminated line in:

```text
DOC/GUIDES/ASM/SAMPLES/str8-record-phase1-max252.s19
```

Do not insert CR or LF inside the 514 printable characters. Require
`RET A=AC X=01 Y=03`, carry set, and `$1A00=AC`.

Then:

```text
>G 3009
```

Send one Ctrl-C byte (`$03`). Require `RET A=AC X=01 Y=04`, carry set, and
`$1A00=AC`.

### 9.3 Short `L G` transport paste

At HIMON:

```text
>L G
L S19
```

Paste exactly:

```text
S1133000A9A58D004960EAEAEAEAEAEAEAEAEAEA14
S1133010EAEAEAEAEAEAEAEAEAEAEAEAEAEAEAEA0C
S1133020EAEAEAEAEAEAEAEAEAEAEAEAEAEAEAEAFC
S1133030EAEAEAEAEAEAEAEAEAEAEAEAEAEAEAEAEC
S1133040EAEAEAEAEAEAEAEAEAEAEAEAEAEAEAEADC
S1133050EAEAEAEAEAEAEAEAEAEAEAEAEAEAEAEACC
S1133060EAEAEAEAEAEAEAEAEAEAEAEAEAEAEAEABC
S1133070EAEAEAEAEAEAEAEAEAEAEAEAEAEAEAEAAC
S9033000CC
```

Require all eight `L @30x0` progress reports, then:

```text
L OK=0080 GO=3000
#LOADGO# ENTRY=3000
RET A=A5
>D 4900 4900
4900: A5
```

## 10. `L F` Equal, Erased, And Needs-Erase Cases

The pinned ASM ends at `$BC6C`, so `$BFE0-$BFE3` must begin erased:

```text
>D BFE0 BFE3
```

Require `FF FF FF FF`. Then run the following exact records.

Already matching:

```text
>L F
S1078000464ED6000E
S90380007C
```

Require:

```text
LF OK WR=0004 GO=8000
```

Program one erased byte, then accept it as matching:

```text
>L F
S104BFE25A00
S903BFE25B

LF OK WR=0001 GO=BFE2
>D BFE0 BFE3
BFE0: FF FF 5A FF

>L F
S104BFE25A00
S903BFE25B

LF OK WR=0001 GO=BFE2
```

Require complete-record preflight and no partial write:

```text
>L F
S106BFE0A1A20017
S104BFE3A3B6
S903BFE05D
```

Require:

```text
LF ERASE=BFE2 OLD=5A NEW=00
LF FAIL=03 WR=0000 SKIP=0004 GO=BFE0
>D BFE0 BFE3
BFE0: FF FF 5A FF
```

The expected `LF FAIL=03` is the needs-erase policy result, not a hardware
write failure.

The positive erased-byte case deliberately left `$BFE2=5A`. Banks 0-2 now
contain the exact candidate, so clean up with an ordinary lower restore before
continuing:

```text
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y
press S during countdown

STR8-N>2
RESTORE B2->B3? Y:y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y:n

COPY B2->B3
OK
STR8-N>G
```

Reassemble and rerun the CRC fixture from section 5, then require the exact
pinned Bank-3 row. This proves the scratch byte is back to `$FF` and keeps the
final candidate identity unambiguous.

## 11. `U` Negative Cases

The successful C/D/E `U` transaction in 4.2 is the positive gate. These two
cases must stop before the second confirmation and before erase.

Empty stream:

```text
STR8-N>U
UPDATE HIMON C000-EFFF? Y:y
SEND S19 C000-EFFF
S903C0003C

NO S19 DATA
```

Out-of-range S1:

```text
STR8-N>U
UPDATE HIMON C000-EFFF? Y:y
SEND S19 C000-EFFF
S104BFFF003D

S19 FAIL
```

There must be no `PROGRAM C000-EFFF?` prompt in either case. Return to HIMON
and rerun the CRC fixture; Bank 3 sectors C-F must remain:

```text
C6 84 1A F2 47 98 6E 18
```

## 12. Legacy `$FFF0` Active-Low Bit Compatibility Gate

This final gate deliberately programs a noncanonical top sector twice. Run it
only with the external programmer connected and after all other acceptance
work. It proves that clearing the retired active-low enrollment bit no longer
changes `B 0`.

Reassemble the exact topwriter, run its safe stage, and inspect:

```text
>G 3000
>D 19F0 19F0
19F0: FF
>M 19F0
19F0: FF FE
>D 19F0 19F0
19F0: FE
```

Program the deliberately modified stage:

```text
>G 3003
```

Require `TW OK`, `$1A00-$1A03 = 01 AC 00 00`, then cold boot and:

```text
>D FFF0 FFF0
FFF0: FE
```

Enter STR8:

```text
STR8-N>E
?

STR8-N>B
BACKUP B3 TO B0/1/2: 0
0 ERASE? Y:y

COPY B3->B0
OK
```

Acceptance of `B 0`, with no enrollment text or cascade, proves the old bit is
ignored. Reassemble the exact topwriter one last time and restore the canonical
sector without the RAM patch:

```text
>G 3000
>D 19F0 19F0
19F0: FF
>G 3003
```

Require `TW OK`, cold boot, `$FFF0=FF`, and the pinned vectors. Bank 0 still
contains the deliberate `FE` image while Bank 3 is canonical. Use that
one-byte high-sector difference to close the deferred normal-restore
high-preservation proof.

Reassemble the section-5 CRC fixture after the reset and require:

```text
1A08: FE FF FF FF
1A10: EC B7 36 70 CE 76 34 9B C6 84 1A F2 47 98 4A B0
1A40: EC B7 36 70 CE 76 34 9B C6 84 1A F2 47 98 6E 18
```

The Bank-0 F-sector CRC changes from `$186E` to `$B04A` when only `$FFF0`
changes from `$FF` to `$FE`. Now perform a lower-only restore from the
high-different Bank 0:

```text
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y
press S during countdown

STR8-N>0
RESTORE B0->B3? Y:y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y:n

COPY B0->B3
OK
STR8-N>G
G HIMON
BOOT WARM

>G 3000
>D 1A08 1A0B
>D 1A10 1A4F
```

Require the same differential rows: Bank 0 must remain `FE`/`$B04A`, while
Bank 3 must remain `FF`/`$186E`. This proves that declining high flash
preserves Bank-3 `$C000-$FFFF` even when the selected source differs.

Finally make Bank 0 canonical again:

```text
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y
press S during countdown

STR8-N>B
BACKUP B3 TO B0/1/2: 0
0 ERASE? Y:y

COPY B3->B0
OK
STR8-N>G
```

The CRC fixture is still resident. Run it again and require `$1A08-$1A0B =
FF FF FF FF` and all four rows to equal the exact pinned row. Do not leave the
board or a backup bank on the `FE` test image.

## 13. Final Reset And Transcript Record

At STR8:

```text
STR8-N>R
```

Require a normal reset through:

```text
FFFA: 98 F0 00 F0 AC F0
```

The final transcript must contain:

- all artifact SHA-256 values used;
- external-programmer recovery filename;
- HIMON/ASM/STR8 visible identities;
- staged and resident checkpoint dumps;
- `PRE`, `POST-B0`, post-restore, post-`B1`, and post-`B2` CRC rows;
- every selected destination and every printed `COPY` line;
- record-service result rows and `L F` summaries;
- worker-tail result row;
- both negative `U` results;
- legacy-bit modified and canonical-restored `$FFF0` values;
- final cold/reset boot evidence.

Append the unedited transcript under a new dated heading in
`DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`. Do not alter prior hardware evidence.

The pass is accepted only after the transcript shows all required gates and
the board ends on the canonical pinned image.
