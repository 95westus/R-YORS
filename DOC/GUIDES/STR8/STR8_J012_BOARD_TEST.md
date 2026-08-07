# STR8 J0-J2 First Board Test

This is the guarded first-board rail for the host-built opaque-bank `J0`-`J2`
candidate. It assumes the 2026-07-28 operator-reported layout:

This document preserves the accepted pre-selector image and transcript. The
later reset-time `0`/`1`/`2`/`3`/`S` follow-up has its own accepted record in
[STR8_BOOT_SELECTOR_BOARD_TEST.md](STR8_BOOT_SELECTOR_BOARD_TEST.md); do not
rewrite the historical addresses, CRCs, or boot text below.

```text
Bank 0  R-YORS without ASM
Bank 1  different R-YORS build without ASM
Bank 2  R-YORS with ASM
Bank 3  R-YORS with ASM and the newest installed STR8
```

The bank roles are observations, not command semantics. Do not run `B`, bare
`0`/`1`/`2`, `U`, TopWriter `P`, or any other flash mutation during the first
two phases.

```text
candidate status: Phase A, direct-RAM Phase B, and resident V1 accepted
resident status:  visible J0/J1/J2 handoff and reset recovery accepted
echo status:      RAM J2 and resident J0/J1/J2 echo accepted
installed CRCs:   B0 $4B59, B1 $2A3D, B2 $04EF, B3 $4663
remaining gate:   none for J0-J2 V1
recovery:         physical reset must return to installed Bank 3 STR8
```

## Host Artifacts

Build:

```text
make -C SRC str8 firmware
```

Required artifacts:

```text
SRC/BUILD/s19/str8-ram-3000.s19
SRC/BUILD/s19/str8-f000.s19
SRC/BUILD/bin/himon-str8-rom.bin
DOC/GUIDES/ASM/SAMPLES/OLD/str8-jump-inventory-3000.a
DOC/GUIDES/ASM/SAMPLES/OLD/str8n-topwrite-transient-3000.a
```

Current host map:

```text
resident STR8           $F000-$FA68
identity bytes          $F8DA = 7A 0F 6A 5F
resident/worker gap     $FA69-$FD15 = $02AD
stored worker           $FD16-$FFEF, size $02DA
hardware vectors        $FFFA-$FFFF = 9A F0 00 F0 AE F0
```

## Phase A: Read-Only Live-Bank Inventory

This phase runs under the currently installed Bank 3 STR8. The fixture calls
the existing `$F003` service in stage-only mode `$06`. It reads all banks,
overwrites RAM `$4000-$4FFF`, and does not erase or program flash.

At HIMON:

```text
>ASM NEW
```

Paste the complete
[str8-jump-inventory-3000.a](../ASM/SAMPLES/OLD/str8-jump-inventory-3000.a),
finish the ASM session with `.`, leave ASM, and run:

```text
>G 3000
>D 1A00 1A06
>D 1A10 1A4F
```

Required status:

```text
$1A00 = AC   complete
$1A05 = EE   explicit Bank 3 PCR pattern after final stage
$1A06 = 03   decoded current bank
```

Each record is 16 bytes:

```text
$1A10 Bank 0: CRClo CRChi NMIlo NMIhi RESETlo RESEThi IRQlo IRQhi
              F000 F001 F002 F003 F00C F00D F00E F00F
$1A20 Bank 1: same
$1A30 Bank 2: same
$1A40 Bank 3: same
```

The fixture stages Bank `$F000-$FFFF` at RAM `$4000-$4FFF`; therefore the
face fields must be read from `$4000-$4003` and `$400C-$400F`. An earlier
fixture revision incorrectly used `$4F00-$4F03` and `$4F0C-$4F0F`, which
captured Bank `$FF00-$FF03` and `$FF0C-$FF0F`. Historical CRC and vector
results remain valid, but their trailing eight bytes are not `$F000` service
face evidence.

Stop on any status other than `$AC`, PCR other than `$EE`, decoded bank other
than `$03`, reset vector below `$8000`, or reset vector `$FFFF`. Preserve the
two dumps as the before-state transcript.

The four complete-image CRCs and vectors become the provisional manual
inventory. They are not yet the required persistent Bank 3 validation
manifest.

### 2026-07-28 Result

Phase A passed twice with the same records:

```text
status/PCR/bank   AC / EE / 03
Bank 0 CRC        $4B59
Bank 1 CRC        $2A3D
Bank 2 CRC        $04EF
Bank 3 CRC        $4F80
all reset vectors $F000
```

All four banks currently share the older top-sector vector and face bytes.
Their different full-image CRCs prove that the complete images are not
identical.

## Phase B: RAM-Only J Proof

Do not install the new top sector yet.

From Bank 3 HIMON, load and start:

```text
SRC/BUILD/s19/str8-ram-3000.s19
```

Use HIMON `L G`, which follows the S9 start at `$3000`. The RAM proof should
show the STR8 screen and `B3` identity. Run only:

```text
STR8-N>?
STR8-N>J2
```

Expected:

```text
STR8-N V0 #5F6A0F7A B3
J B2
... Bank 2 R-YORS starts through Bank 2 $FFFC ...
```

Press physical reset. Required result:

```text
installed Bank 3 STR8 starts
timeout still enters Bank 3 HIMON
```

Repeat the load/start/reset cycle for `J1`, then `J0`. Use the inventory
vectors and each R-YORS build's own banner/timestamp to distinguish the banks.
Do not infer identity from the bank number alone.

Stop if:

- the RAM proof prints `JERR`;
- a selected image does not show the expected distinct R-YORS identity;
- physical reset does not return to Bank 3;
- any NMI source is active or unexplained; or
- a peripheral remains in a state the target reset routine cannot recover.

### 2026-07-28 Result

The candidate loaded as `L OK=0B4C GO=3000`. `J2`, `J1`, and `J0` all entered
a target without `JERR`, and physical reset returned to installed Bank 3
HIMON `V 00.0728(2121)` after every handoff:

```text
J2 target banner  HIMON V 00.0728(2113)
J1 target banner  HIMON V 00.0728(2113)
J0 target banner  HIMON V 00.0728(2042)
```

The mechanics and recovery portion of Phase B passes. Before Phase C:

1. Distinguish Banks 1 and 2 with a read-only target behavior; their HIMON
   banners alone are identical.
2. Re-run Phase A after the final `J0` cycle and require the same four CRCs,
   `$EE` PCR, and decoded Bank 3 without an intervening flash mutation.

### 2026-07-28 Follow-Up

The identity distinction passed:

```text
J2 $8000-$800F  46 4E D6 00 74 AD 56 05 0C 80 87 B9 20 7B 85 B0
J1 $8000-$800F  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
J0 $8000-$800F  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
J0 ASM NEW       #56AD7400# HSH_NF!
```

Bank 2 contains ASM-F2; Banks 0 and 1 do not. The final CRC run cannot close
the non-destructive comparison because an `L F` attempt and confirmed full
`B2->B3` restore intervened. Banks 0-2 remained
`$4B59/$2A3D/$04EF`, while Bank 3 intentionally changed from `$4F80` to
`$04EF` and now mirrors Bank 2.

Before Phase C, restore or explicitly accept the intended Bank-3 payload and
take a new clean inventory. To recover the reported newer-Bank-3 layout,
repeat the already-proven `$C000-$EFFF` `U` update and require
`$4B59/$2A3D/$04EF/$4F80`, PCR `$EE`, and decoded Bank 3.

### 2026-07-28 Recovery Result

The repeated `U` update returned Bank 3 to HIMON `2121` and CRC `$4F80`. A
clean baseline inventory, an inventory immediately after a new `J2`/reset
cycle, and the final inventory after a new `J0`/reset cycle were byte-for-byte
identical:

```text
status/PCR/bank   AC / EE / 03
Bank 0 CRC        $4B59
Bank 1 CRC        $2A3D
Bank 2 CRC        $04EF
Bank 3 CRC        $4F80
```

No flash command occurred between that baseline and final dump. Together with
the already-recorded `J1` target/reset and identity proof, Phase A and the
direct-RAM Phase B are accepted for all three banks. Proceeding to Phase C is
now a deliberate destructive installation decision, not an unresolved
read-only prerequisite.

## Phase C: Resident Installation

This phase is destructive and is deliberately not authorized by completion of
the host build alone. The required Bank-3 payload, clean inventory, all three
RAM handoffs, and physical-reset recovery passed before the operator
deliberately rewrote Bank 3 `$F000-$FFFF`. The steps below remain the
authoritative installation and proof sequence; the 2026-07-28 installation
transcript captured the installed result but not the TopWriter programming
exchange.

Regenerate the self-contained top writer from the exact candidate:

```text
make -C SRC str8-topwrite-a
```

Use the established TopWriter `S`, `V`, then confirmed `P` procedure from the
operator guide. It rewrites only Bank 3 `$F000-$FFFF`; nevertheless, have an
external programmer or known Bank 3 recovery image ready.

After programming:

1. Physical reset.
2. Confirm `B3 HIMON IN 3S. S=STR8-N`.
3. Let one countdown expire and confirm Bank 3 HIMON.
4. Reset, take over with `S`, and run `?`.
5. Confirm the new Bank 3 identity line ends in `B3`.
6. Run `J2`, reset, `J1`, reset, then `J0`, reset.
7. Re-run the read-only inventory fixture.

Banks 0-2 must retain their exact before CRCs. Bank 3 must match the newly
built combined image rather than its before CRC.

### 2026-07-28 Partial Result

The resident candidate is installed. Cold boot prints the Bank-3 countdown,
times out to HIMON `2121`, and resident `?` identifies
`STR8-N V0 #5F6A0F7A B3` at ROM `$F000` with `J0 J1 J2` in help.

The only post-install table reports `$AC`, PCR `$EE`, decoded Bank 3, CRCs
`$4B59/$2A3D/$04EF/$0D8A`, and new Bank-3 vectors NMI `$F09A`, RESET `$F000`,
and IRQ `$F0AE`. Treat this as provisional: the old fixture was started while
Bank 2 was visible, produced anomalous boot output, and its retained table was
dumped after a later `U` warm boot rather than recomputed. Banks 0-2 appear
unchanged and `$0D8A` is the expected Bank-3 result, but the corrected
Bank-3-started run is the final proof.

Resident `J1` entered its HIMON `2113` target without ASM, then physical reset
returned to the installed Bank-3 prompt. Resident `J0` entered HIMON `2042`
without `JERR`, but the transcript ends before reset recovery. The earlier
`J2` in this capture ran from the loaded RAM candidate, not resident ROM.

Finish Phase C from the current Bank-0 target:

1. Press physical reset and require the Bank-3 countdown plus HIMON `2121`.
2. Reset again, take over with `S`, run `?`, then run resident `J2`.
3. Require target HIMON `2113`; press physical reset and require Bank 3 again.
4. From Bank-3 HIMON only, assemble and run the corrected inventory fixture.
5. Require `$AC/$EE/03` and CRCs
   `$4B59/$2A3D/$04EF/$E4DB`.
6. Require the Bank-3 record face
   `4C 10 F0 4C | 53 52 01 07`.
7. Capture these direct installed-image checks:

```text
>D F000 F00F
4C 10 F0 4C 19 F3 4C 20 F3 4C 28 F3 53 52 01 07

>D F8D4 F8D7
7A 0F 6A 5F

>D FD16 FD25
08 78 AD F0 1F C9 05 F0 11 C9 06 F0 12 C9 07 F0

>D FFFA FFFF
9A F0 00 F0 AE F0
```

Run the corrected fixture only while Bank 3 is selected: `$F003` must be the
installed STR8 service. Re-paste it from the updated source before assembling;
an already assembled older copy still contains the bad face-field addresses.

### 2026-07-28 Final Functional Result

The follow-up closes every step above. Physical reset from the resident `J0`
target returned to Bank-3 HIMON `2121`. Resident `J2` entered HIMON `2113`,
and physical reset again returned to Bank 3.

The corrected fixture ran from Bank-3 HIMON and returned `$AC/$EE/03`:

```text
Bank 0  $4B59  98 F0 00 F0 AC F0 | 4C 10 F0 4C 53 52 01 07
Bank 1  $2A3D  98 F0 00 F0 AC F0 | 4C 10 F0 4C 53 52 01 07
Bank 2  $04EF  98 F0 00 F0 AC F0 | 4C 10 F0 4C 53 52 01 07
Bank 3  $E4DB  9A F0 00 F0 AE F0 | 4C 10 F0 4C 53 52 01 07
```

Direct dumps matched the installed header, marker, worker head, config pocket,
and vectors. `$E4DB` supersedes the earlier provisional `$0D8A`. The installed
resident handoff is functionally hardware-proven for all three targets.

### Echo Follow-Up

The accepted installed image consumes `J0`, `J1`, and `J2` without displaying
the typed bytes. It still prints `J Bn`, and the successful target entries
prove dispatch is correct. The host follow-up echoes only the two-byte `J`
grammar, preserving the traditional immediate behavior of other STR8 keys.
The regenerated 31,052-byte top writer has SHA-256
`974B8B1F68A62B378BE3E18E4439692CA178D7F6CC14FCBEA69B4DB240DA8F64`.

Before another protected-sector write, prove the echo from RAM. From Bank-3
HIMON, load current `SRC/BUILD/s19/str8-ram-3000.s19` with `L G`. Require
`L OK=0B52 GO=3000`, the RAM candidate screen, and:

```text
STR8-N>J2
J B2
```

Physical reset must return to the installed Bank 3. Repeat the load and visible
command check for `J1` and `J0`. Do not install the echo follow-up if any typed
`Jn` is absent or any handoff/reset behavior differs.

After that RAM echo gate passes, install the regenerated top writer. The new
host map is shown above. Require:

```text
STR8-N>J0
J B0

STR8-N>J1
J B1

STR8-N>J2
J B2
```

Reset back to Bank 3 after each handoff. The new direct top-sector checks are:

```text
>D F000 F00F
4C 10 F0 4C 1F F3 4C 26 F3 4C 2E F3 53 52 01 07

>D F8DA F8DD
7A 0F 6A 5F

>D FD16 FD25
08 78 AD F0 1F C9 05 F0 11 C9 06 F0 12 C9 07 F0

>D FFFA FFFF
9A F0 00 F0 AE F0
```

Because the echo patch changes six bytes in Bank 3, `$E4DB` will no longer be
its full-image CRC after installation. Run the corrected inventory immediately
after installing, record the new Bank-3 CRC, require unchanged Bank 0-2 CRCs
`$4B59/$2A3D/$04EF`, and require the same four CRCs again after the three
visible-command handoffs.

### 2026-07-28 Echo Install Partial Result

The `$0B52` RAM candidate visibly printed `STR8-N>J2`, then `J B2`, selected
Bank 2, and reset-recovered to Bank 3. The transcript did not reload the RAM
candidate for `J1` or `J0`.

The exact regenerated TopWriter assembled through `$5000`. Its `S`, `V`, and
confirmed `P` path returned `TW OK` at every gate, and physical reset
cold-booted Bank 3 into HIMON `2121`. Thus the echo follow-up is installed and
bootable. The capture ends before entering resident STR8, so none of the three
resident visible-command checks or the new direct/CRC checks is yet recorded.

### 2026-07-28 Echo Final Result

The resident follow-up closes the remaining V1 gate. Direct dumps match the
echo-build image exactly:

```text
F000: 4C 10 F0 4C 1F F3 4C 26 F3 4C 2E F3 53 52 01 07
F8DA: 7A 0F 6A 5F
FD16: 08 78 AD F0 1F C9 05 F0 11 C9 06 F0 12 C9 07 F0
FFFA: 9A F0 00 F0 AE F0
```

The corrected inventory ran from Bank 3 before the handoffs and returned
`$AC/$EE/03`:

```text
Bank 0  $4B59  98 F0 00 F0 AC F0 | 4C 10 F0 4C 53 52 01 07
Bank 1  $2A3D  98 F0 00 F0 AC F0 | 4C 10 F0 4C 53 52 01 07
Bank 2  $04EF  98 F0 00 F0 AC F0 | 4C 10 F0 4C 53 52 01 07
Bank 3  $4663  9A F0 00 F0 AE F0 | 4C 10 F0 4C 53 52 01 07
```

Resident STR8 then visibly accepted all three commands:

```text
STR8-N>J0
J B0
... HIMON 2042 ...

STR8-N>J1
J B1
... HIMON 2113 ...

STR8-N>J2
J B2
... HIMON 2113 ...
```

Physical reset returned to Bank 3 between the target runs. An inventory
fixture assembled while Bank 2 was visible was invalid because its `$F003`
service call did not name the installed Bank-3 STR8 service; `G 3000`
cold-booted Bank 3 instead of returning `$AC`. That run is diagnostic only.
After the fixture was reassembled and run from Bank 3, it returned
`$AC/$EE/03` and the same `$4B59/$2A3D/$04EF/$4663` CRCs. Final direct dumps
also matched the image above.

The opening all-zero `$1A00-$1A4F` dump followed `RAM ZERO OK` and is not an
inventory. The earlier `L G` stream of `LERR=$01` had no S19 input and issued
no flash operation. Neither is a `J` or installation failure.

## Evidence To Append

Append, do not rewrite, the hardware log with:

```text
host commit or dirty-tree description
candidate ROM filename/timestamp
Phase A status/PCR/bank dump
all four CRC/vector/face records
RAM J2/J1/J0 pre-jump lines and target identities
physical-reset recovery after every handoff
resident header, marker, worker head, and vectors after install
post-install CRC inventory
explicit statement that Banks 0-2 were unchanged
```

The installed echo-build `J0`-`J2` V1 handoff is fully hardware-proven on this
board. Identity and CRC authentication remain a future Bank-3-owned metadata
requirement; V1 checks reset-vector plausibility only.

> **IMPORTANT: THIS ACCEPTANCE IS NOT TRANSFERABLE TO ANOTHER SYSTEM**
>
> Each unrelated system still needs its own warm-handoff, peripheral, vector,
> and CRC qualification. Use
> [STR8_GUEST_IMAGE_QUALIFICATION.md](STR8_GUEST_IMAGE_QUALIFICATION.md) for
> the generic procedure before approving an exact OSI BASIC, FORTH, WOZMON, or
> other guest image.

## 2026-08-01 Selected-Bank Startup Repair Gate

This focused gate supersedes the requirement that generic `STR8_INIT` write
PCR `$EE`. That write was intended only to make the hardware-reset/pull-up
Bank-3 state explicit to a software decoder. It causes a copied STR8 image in
Bank 0-2 to remap Bank 3 as soon as its reset entry runs.

Install the corrected top sector in Bank 3, then prove these cases in order:

1. Physical reset starts the corrected Bank-3 STR8 image through the board
   pull-ups. Enter STR8 and record its identity.
2. Copy that complete corrected Bank-3 image to a disposable Bank 0, 1, or 2.
   An older destination containing the retired startup write is not a valid
   repair candidate until overwritten.
3. From Bank 3 issue the matching `J0`, `J1`, or `J2`. Do not press physical
   reset before collecting the selected-bank evidence.
4. Require the copied STR8 identity and the bank-neutral selector text. Because
   source and copy have the same identity, also run a RAM-resident bank probe
   or inspect a bank-distinguishing byte while the selected image is live.
   Require the PCR pattern and decoded bank to match the `J` destination; for
   Bank 2 the expected output pattern is `$EC` and the decoded bank is `$02`.
   For the copied current image, the smallest direct check is to choose `3`
   from that selected STR8 selector, enter its local HIMON warm, and dump
   `$7FEC` with `D 7FEC 7FEC`; Bank 2 must show `$EC`. This path changes only
   the HIMON warm signature, not the bank.
5. Press physical reset and require recovery to the Bank-3 image.

Repeat for the other disposable banks when practical. A same-version banner
alone is insufficient because it cannot distinguish the selected copy from
Bank 3. Acceptance requires both sustained execution and independent bank
evidence before physical reset. Existing Bank-0/1/2 images assembled with the
retired PCR `$EE` write will continue to return to Bank 3 and must not be used
as evidence for this repair.

### 2026-08-02 Partial Result

Corrected TopWriter installation passed and physical reset reached Bank-3
STR8 `00.0802(1323)` with the bank-neutral selector. The subsequent `J2`
banner is not accepted as Bank-2 proof because Bank 2 still contains the old
startup and could remap the newly repaired Bank 3. The bank-copy utility then
assembled through `ASM OK`, but its direct package import jumped to `$0000`
before any prompt or worker call. No copy occurred. Current utility source uses
the published HIMON service vectors directly; steps 2-5 remain open.

### 2026-08-02 Full-Copy and Bank-2 Persistence Result

The corrected direct-run bank-copy utility assembled through `ASM OK` and
`SEAL`. Its Bank-3-to-Bank-2 and Bank-3-to-Bank-1 operations each completed all
eight 4K sectors, printed `OK`, and returned `A=$AC` with carry set in worker
mode `$05`.

Bank 2 was copied while it contained HIMON `00.0731(1515)`. Bank 3 was then
updated to HIMON `00.0802(1334)`, and that newer image was copied to Bank 1.
Later the reset selector's `2` path cold-entered HIMON `00.0731(1515)`. This
distinct payload identity proves that the repaired STR8 startup preserved Bank
2; a remap to Bank 3 would have reached `00.0802(1334)`. Choosing `3` from the
Bank-2 STR8 selector also warm-entered the same local `0731` HIMON.

`J1` reached HIMON `00.0802(1334)`, but Banks 1 and 3 shared that identity, so
independent Bank-1 persistence remains open. A direct resident `J2` run with
the distinguishing Bank-2 payload and physical-reset recovery after this exact
copy/selector sequence are not included. The transcript was captured just
before removal of the visible `#5F6A0F7A` banner hash, so the hash-bearing
`00.0802(1323)` banners are expected and do not test that later change.

### 2026-08-02 Direct J1/J2 and Bank-0 Copy Follow-Up

No-hash STR8/HIMON `00.0802(1404)` was installed in Bank 3. The direct-run
copy utility then completed a verified Bank-3-to-Bank-0 copy with eight sector
dots, `OK`, and `A=$AC` with carry set.

Banks 1 and 2 remained deliberately distinguishable from Bank 3. Selector `1`
and resident `J1` both reached hash-bearing STR8 `00.0802(1323)` and HIMON
`00.0802(1334)`. Selector `2` and resident `J2` both reached hash-bearing STR8
`00.0802(1323)` and HIMON `00.0731(1515)`. The selector routes close
independent sustained Bank-1 and Bank-2 execution. Resident `J1` was issued
from Bank 1 and resident `J2` from Bank 2, so these are self-target command
smokes rather than cross-bank direct-J proof.

Selector `0` and resident `J0` reached copied `1404`, but Banks 0 and 3 were
byte-identical, so those traces do not independently prove sustained Bank 0.
Cross-bank resident `J1`/`J2` and physical-reset recovery after this exact
matrix are not present. Those gates remain open.

### Operator Continuation: Cross-Bank J0/J2

A later continuation directly crossed from a current `1404` image through
`J2` into Bank-2 STR8 `1323`, accepting cross-bank resident `J2`. It also
crossed from an old `1323` image through `J0` into Bank-0 STR8/HIMON `1404`,
accepting cross-bank resident `J0` and independently distinguishing sustained
Bank 0.

The direct `J1` trace moved between Banks 2 and 1, which both display STR8
`1323`, and selected `S` before their distinct HIMON identities could be
observed. Cross-bank resident `J1` and physical-reset recovery after the exact
matrix remain open. `D 7FEC` returned `FTDI VIA IO SKIP`, so no PCR byte was
observed or claimed.

### 2026-08-02 Sixteen-Dot Cross-Bank Follow-Up

The current direct-run copy utility verified Bank 3 to Bank 2 before the HIMON
update, then verified Bank 3 to Bank 1 after it. This left Bank 2 and Bank 0
distinguishable, but made Banks 1 and 3 identical:

```text
Bank 3  STR8 1420 / HIMON 1425
Bank 2  STR8 1420 / HIMON 1404
Bank 1  STR8 1420 / HIMON 1425
Bank 0  STR8 1404 / HIMON 1404, four-dot attach
```

A power-off reset recovered to Bank-3 STR8/HIMON `1420/1425`. The reset
selector then traversed Bank 2, Bank 1, and Bank 0. Bank 2 is distinguished by
HIMON `1404`, and Bank 0 by its older four-dot STR8 `1404`; Bank 1 and Bank 3
are exact `1420/1425` copies and cannot be distinguished by this trace.

From Bank 0, resident `J1` crossed from four-dot STR8 `1404` into sixteen-dot
STR8 `1420`. That target could be either Bank 1 or an accidental Bank-3 remap
because both contain the exact same image, so direct-J1 remains open. The
following direct `J2` entered STR8 `1420`; `G` then reached HIMON `1404`,
independently distinguishing Bank 2 and reconfirming cross-bank direct-J2.

The power-off proves recovery to Bank 3 after this install/maintenance session.
It does not claim a separate physical reset after every individual direct
handoff. To close direct-J1, make Bank 1 and Bank 3 observably different before
the run, or use a bank-state probe that works with this console configuration.

### 2026-08-02 Distinct Bank-1 Closure

The operator followed the prescribed distinguishing sequence. The bank-copy
utility first rejected the wrong confirmation `WRITE 31` without writing
flash, then accepted `COPY 31` and verified all eight sectors from Bank 3 to
Bank 1. Bank 1 therefore retained STR8/HIMON `1440` while a later TopWriter and
`U` update advanced only Bank 3 to STR8/HIMON `1452`.

The resulting four-bank identities were independently distinguishable:

```text
Bank 3  STR8 1452 / HIMON 1452
Bank 1  STR8 1440 / HIMON 1440
Bank 2  STR8 1420 / HIMON 1404
Bank 0  STR8 1404 / HIMON 1404, four-dot attach
```

Bank-3 selector `1` first reached Bank-1 STR8 `1440`, accepting sustained
Bank-1 selection against a distinct `1452` Bank 3. The direct-command chain
then moved Bank 1 through `J2` into distinct Bank-2 STR8 `1420`. From Bank 2,
resident `J1` reached Bank-1 STR8 `1440`; `G` warm-entered local HIMON `1440`:

```text
STR8-N V 00.0802(1420)
STR8-N>J1
J B1
................
STR8-N V 00.0802(1440)
STR8-N>G
G HIMON
BOOT WARM
HIMON V 00.0802(1440)
```

An accidental Bank-3 remap would have displayed `1452`, while a wrong Bank-0
or Bank-2 selection would have displayed `1404` or `1420`. This independently
accepts cross-bank resident `J1`. Together with the prior distinguishable
`J0` and `J2` results, the complete resident `J0/J1/J2` surface is now
hardware-accepted.

## 2026-08-02 J3 Bank-3 Software Return Candidate

Status: host and board pass.

The current source extends the same non-destructive RAM handoff from `J0-J2`
to `J0-J3`. `J3` is an explicit software return to Bank 3 for a copied STR8
running in Bank 0-2. Reset-selector `3`, prompt `G`, and prompt `R` remain local
to the currently selected bank; physical reset remains the universal recovery
path for a guest that does not contain STR8.

The resident parser, RAM-proof handoff, and stored worker now accept bank bytes
`$00-$03` and reject `$04-$FF`. The worker bank-select table was already the
complete `$CC,$CE,$EC,$EE` table. The release check executes the dispatcher for
all 256 mode bytes, checks the J range and table, and reports:

```text
ACTIVE MODES            = 05 06 07 08
JUMP BANK RANGE         = 00-03
REJECTED MODE BYTES     = 252
STR8 WORKER MODE CHECK  = PASS
```

Only the help text grows. Code and worker remain `$08B0` and `$025D` bytes;
resident data becomes `$0121` bytes, the normal image ends at `$F9D0`, and the
V1 reserve is `$F9D1-$FD52`, `$0382` bytes. The generated TopWriter retains
the face check at `$F8B4` and moves the prompt check to `$F8EE`.

### Board Gate

The source bank must itself contain this J3-capable STR8. An unrelated guest
cannot acquire `J3` merely because Bank 3 has it. Use one disposable copied
STR8 bank for the smallest proof:

1. Install the candidate in Bank 3 and confirm help contains `J3`.
2. Copy that complete image to one disposable Bank 0, 1, or 2 and verify all
   eight sectors.
3. Advance only the Bank-3 STR8 identity, leaving the copied source bank on the
   previous identity. This makes a return to Bank 3 independently visible.
4. Enter the copied bank, choose `S`, issue `J3`, and require:

```text
STR8-N>J3
J B3
................
STR8-N V 00.mmdd(newer)
```

5. Choose `S`, then `G`, and require the newer Bank-3 HIMON identity. If the
   Bank Jump Record is inspected, `$1FFD-$1FFF` must be `42 4A 03`.
6. Confirm `J4` prints `?`. Reconfirm that `G`, `R`, and reset-selector `3`
   retain their documented local-bank behavior.

One independently distinguished copied-bank run is sufficient for the shared
worker path. Repeating from Banks 0, 1, and 2 is useful regression coverage but
is not required to establish the bank-byte-3 mechanism.

### Partial Board Result

The first J3-capable candidate assembled, staged, verified, and programmed
Bank 3 successfully. Installed STR8 `00.0802(1509)` advertised
`? U J0 J1 J2 J3 G R`, and the matching HIMON update advanced Bank 3 to
`00.0802(1514)`. The direct-run bank-copy utility then copied and verified all
eight sectors from Bank 3 to Bank 0.

Selector `0` entered the Bank-0 copy. From that copy, `J3` printed `J B3`,
re-entered STR8, and subsequently reached HIMON. This accepts the installed
parser and a functional Bank-3 handoff smoke. It does not independently prove
the selected destination because Banks 0 and 3 were exact
STR8/HIMON `1509/1514` copies during the run.

The same transcript then advanced only Bank 3 to STR8/HIMON
`00.0802(1518)`. Bank 0 remains the verified `1509/1514` copy, so no more copy
or flash preparation is required. Close the gate with this short sequence:

```text
from Bank-3 STR8 1518, choose selector 0
require Bank-0 STR8 1509
choose S
issue J3
require J B3, then Bank-3 STR8 1518
choose S, then G
require Bank-3 HIMON 1518
```

That distinguishable return has now been captured. From Bank-3 STR8 `1518`,
selector `0` entered Bank-0 STR8 `1509`. The operator selected `S` and issued
`J3`; STR8 printed `J B3` and re-entered distinct STR8 `1518`. Its normal
timeout then cold-entered distinct HIMON `1518`. An accidental stay in Bank 0
would have displayed STR8 `1509` and HIMON `1514`, so the destination is
independently identified. J3 is hardware-accepted.

The later HIMON `00.0802(1536)` run also proves the Bank Jump Record side
effect: after the distinct Bank-0-to-Bank-3 `J3`, cold entry reported
`42 4A 03`; a confirmed `HCOLD` preserved the same bytes. `J4` rejection
remains a useful regression check, not an acceptance gate.
