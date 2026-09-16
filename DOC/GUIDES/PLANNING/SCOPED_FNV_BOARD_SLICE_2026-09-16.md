# Next slice: qualify scoped banked AP discovery

Current status: the authorized banked AP slice is complete. See the
[qualification record](../LOGS/SCOPED_QUALIFICATION_2026-09-16.md) for fixture, paced LED/PCR, reset
and final isolation evidence. BANKDUMP remains at B2:A with policy `$A6`.
RAM-provider/HREC search and SPI SRAM WORK are separate future work.
The plan and step-by-step status below retain their historical context.

Step-1 follow-up: the operator selected the `$A6` end state and authorized only
guarded policy/pair recovery preparation. See the
[prepared artifacts and recovery card](../AP/SCOPED_POLICY_AND_PAIR_RECOVERY_2026-09-16.md).
No board work or later full-regression/qualification step was performed.

Step-2 follow-up: the operator subsequently authorized host revalidation with
on-board smoke, including flashing where needed. The [host gates](../LOGS/SCOPED_HOST_GATES_2026-09-16.md)
and [board smoke](../LOGS/SCOPED_SMOKE_BOARD_2026-09-16.md) pass. HIMON/AM02
and `$A6` are installed, with physical reset and final isolation verified.
This completes step 2 of the conversational outline (host revalidation plus
the authorized smoke extension); the detailed board matrix below remains
partially open. No BANKDUMP/malformed/duplicate carrier was installed.

## Starting point and outcome

The [role migration](../LOGS/SECTOR_ROLES_BOARD_2026-09-16.md) is complete:
WORK is unassigned, backup is B2:F, and FNV policy is `$FF` (disabled).
Physical reset and final four-bank isolation pass. Installed HIMON and AM01
remain the previous accepted pair; APTEST remains at B2:9.

Qualify the existing [HIMON/AM02 candidate](../AP/HIMON_SCOPED_FNV_IMPLEMENTATION_2026-09-16.md)
for resident-first, unique banked AP lookup in B2/B1, with B0 excluded.
The intended successful demonstration is bare `BANKDUMP`, including actual
load, import linking, menu operation, and clean return to HIMON.

RAM-provider/HREC discovery, SPI SRAM WORK, generation precedence, and space
recovery are subsequent slices. Do not expand this candidate's feature scope.

## 1. Freeze inputs and prepare recovery

- Use the accepted post-reset archive as the baseline; take fresh readbacks
  before mutation and reconcile any drift. Preserve both old B1:F and current
  B2:F backups on the host, with exact hashes.
- Freeze candidate HIMON, AM02, installer, BANKDUMP envelope, and source/build
  identities. Do not use the raw BANKDUMP fixture with historical imports:
  use its named-import AP envelope and validate links against this HIMON.
- Record the sector inventory and select erased eligible fixture locations.
  Preserve B2:9 APTEST, B2:F backup, all existing B1 contents, and B0. Record
  exact addresses before constructing the flash write allowlist.
- Specify and host-rehearse the coordinated installation order and rollback
  of both HIMON and AM02. Verify a STR8/RAM maintenance route that does not
  require named APMAN bootstrap or the new resident AP ABI. Neither a mixed
  AM01/new-HIMON pair nor `$FFF2=$FF` may strand the installation procedure.
- Freeze expected bytes after each stage. Expected mutations are B3:C-E,
  B2:8, selected fixture sectors, and B3:F/B2:F during policy updates. STR8 `I`
  also advances B2/B3 journal bits in B3:F; predict those exact changes.
  ASM at B3:8-B and immutable directory metadata must remain exact.

## 2. Prepare a guarded policy update

The stock top updater embeds `$FFF2=$FF`; it does not provision `$A6`.
Prepare a separately identified full-sector policy-update artifact using the
existing guarded RAM update/recovery mechanism. Retain canonical defaults.

- Preserve the live directory, vectors, code, WORK=`$FF`, backup=`$2F`, and
  reserved bytes. Against the accepted live top, only `$FFF2` may change.
- Prove backup-to-B2:F, erase/program/readback, retry, and restore-old behavior
  in the flash model. Prove the physical write set and exact final 4 KiB image.
- Preserve the current B2:F archive before replacing it with the immediate
  pre-policy top. Label both backup generations explicitly. Restoring the
  earlier role-migration backup would also restore the old B1:E/B1:F roles.
- Prepare rollback to policy `$FF` through the same full-sector discipline;
  never rely on an in-place byte write or named discovery for recovery.

## 3. Host gates and deployment bundle

Run `make -C SRC asm-test`, `board-s19-check`, and the relevant STR8
`bank-maint-role-check` / `top-backup-role-check`, with a recorded build stamp.
Recheck the 65,536 policy/request combinations, 59 linked scoped cases, exact
name and carrier validation, AM01 rejection, Bank-3 restoration, and new roles.
Add focused tests for the policy artifact and actual deployment/recovery path.

Record linked sizes: candidate HIMON currently ends at `$EFF8` (8 bytes free),
AM02 BODY at `$7BF3` (13 bytes free). Any overflow or new required firmware
behavior stops deployment and becomes a separately measured space-recovery fix.
Regenerate and verify `RAM-TRANSIENTS` after artifact changes. Produce an
ordered command card, expected results, hashes, write allowlist, and rollback
card before board execution.

## 4. Board sequence and acceptance matrix

1. Capture baseline and install/read back the coordinated HIMON/AM02 pair
   using the rehearsed recovery-independent route. Keep policy `$FF` initially.
2. Prove `$FF` disables manager discovery and external named/bare lookup while
   resident commands, STR8 recovery, and the direct visible-RAM AP path work.
3. Apply the guarded `$A6` policy image. Read back all of B3:F and its B2:F
   backup, then verify roles and policy exactly.
4. Install host-validated fixtures only in the recorded erased locations.
   Prove one unique BANKDUMP provider in B2 and then B1, successful named and
   bare lookup, correct import linking, interactive read-only operation,
   return, and restored Bank 3. Never leave two valid copies for success tests.
5. Prove resident precedence, missing-name refusal, duplicate `$D2` without
   child entry, and malformed-carrier rejection. Precompute malformed fixtures
   and expected outcomes on the host; do not improvise executable corruption.
6. Prove named B0 requests reject before selection and automatic discovery
   excludes B0. Retain host selector-trace proof; unchanged B0 bytes alone do
   not prove it was never selected. Capture board-observable selection evidence
   with a rehearsed RAM diagnostic/observation procedure, without adding code
   to the nearly full resident image. If this cannot establish the exclusion,
   keep that board gate open rather than infer it from serial output.
7. Exercise the current role guards: B2:F excluded/protected; B1:E/F no longer
   reserved. Use read-only or pre-write refusal paths for occupied B1 sectors;
   host tests supply destructive guard coverage without erasing their contents.
8. Restore temporary fixture sectors to their initial bytes, retain only the
   chosen final BANKDUMP carrier if requested, and verify the write allowlist.
   Capture physical RESET, repeat policy/launch checks, and take a final complete
   four-bank archive. Check every unchanged sector and every expected change.

For the existing LED gate, use individually announced bank/sector observations
with pauses and an explicit expected-display card. Ask the operator to identify
each display; merely observing changing lights does not close this gate.
Schedule that observation during the board pass; retain a separate result if
the exact sequence still cannot be distinguished.

## Completion and decisions

Append new hashed evidence and update capabilities, operator instructions,
test plan, and queue status only for the behavior actually proven. Mark the
banked AP portion accepted when its gates pass; leave the broader RAM-provider
and HREC work unchecked. Do not rewrite earlier hardware evidence.

Recommended end state: leave `$A6` enabled and one verified BANKDUMP carrier
installed; restore duplicate/malformed test sectors. The operator confirmed
`$A6`, and the later authorized step-2 smoke installed that policy. A persistent
BANKDUMP carrier remains future work. Exact fixture sectors can be
chosen from fresh erased-sector inventory without a separate design decision.

No unresolved architecture question blocks preparing this slice. Remaining
engineering questions are how to carry the policy image through the guarded
updater, the exact recovery-independent installation order, and how to capture
board selection evidence. Resolve these through host inspection/rehearsal
before proposing the concrete board command card. Physical RESET and visual
LED observation require operator availability during board qualification.
