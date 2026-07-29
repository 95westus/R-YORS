# STR8 J0-J2 First Board Test

This is the guarded first-board rail for the host-built opaque-bank `J0`-`J2`
candidate. It assumes the 2026-07-28 operator-reported layout:

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
DOC/GUIDES/ASM/SAMPLES/str8-jump-inventory-3000.a
DOC/GUIDES/ASM/SAMPLES/str8n-topwrite-transient-3000.a
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
[str8-jump-inventory-3000.a](../ASM/SAMPLES/str8-jump-inventory-3000.a),
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
