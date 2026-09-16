# Scoped policy provisioning and paired recovery preparation

Scope: next-slice **step 1 only**, offline preparation. The operator selected
`$A6` as the intended final policy. No serial port was opened and no board
installation, policy write, or new board qualification was performed.

Subsequent status: the separately authorized [step-2 board smoke](../LOGS/SCOPED_SMOKE_BOARD_2026-09-16.md)
installed this pair and `$A6`, with reset and isolation passing. This preparation
record and its frozen baseline still describe the starting state; use the new
board archive for live-state checks and the `after-a6` B2 recovery generation.

## Prepared artifacts

The [bundle](../LOGS/SCOPED_RECOVERY_PREP_2026-09-16/manifest.json) freezes the
accepted four-bank baseline, candidate HIMON/AM02, old HIMON/AM01, narrow
install/rollback streams, full interrupted-install recovery streams, and two
guarded RAM policy updaters. See its [focused check report](../LOGS/SCOPED_RECOVERY_PREP_2026-09-16/host-check.json).

Reproduce into a new directory:

```text
python -B SRC/tools/prepare_scoped_recovery.py --output LOCAL/scoped-recovery-new
python -B SRC/tools/check_scoped_recovery.py --bundle LOCAL/scoped-recovery-new
```

The builder refuses an existing output directory. It invokes the installed WDC
assembler/linker on isolated copies of the current STR8 updater source, leaving
canonical firmware and default `$FFF2=$FF` unchanged. Its manifest records the
source/input hashes. These are task-specific recovery artifacts, not a new
release or general RAM-transient export.

| Artifact | Purpose / prerequisites |
| --- | --- |
| `policy-a6/policy.s19` | STR8 `L`, entry `$2000`; require live roles `$FF/$2F` and policy `$FF`; provision `$A6` |
| `policy-ff/policy.s19` | STR8 `L`, entry `$2000`; require live roles `$FF/$2F` and policy `$A6`; disable discovery |
| `candidate-am02-b2-8.s19` | STR8 `I`, B2, range `8`; dense 4 KiB |
| `candidate-himon-b3-c-e.s19` | STR8 `I`, B3, range `C-E`; dense 12 KiB |
| `rollback-am01-b2-8.s19` | Original accepted AM01 sector, narrow complete-bank rollback |
| `rollback-himon-b3-c-e.s19` | Original accepted HIMON sectors, narrow complete-bank rollback |
| `recovery-{old,new}-b3-8-e.s19` | Interrupted B3 recovery, complete writable 28 KiB; preserves original ASM bytes |
| `recovery-{old,new}-b2-8-f.s19` | Interrupted B2 recovery before policy provisioning; complete 32 KiB |
| `recovery-{old,new}-b2-8-f-after-a6.s19` | B2 full recovery after successful `$A6` provisioning; carries the paired pre-policy top backup |
| `recovery-{old,new}-b2-8-f-after-ff.s19` | B2 full recovery after policy rollback to `$FF`, before further pair transactions; carries the `$A6` top backup |

All B2 full streams use the RESET vector from their exact archived B2:F as S9,
as required by STR8's full-bank receiver. This is a framing requirement, not
an instruction to boot B2. Stay in STR8 throughout pair installation/recovery.

## Guarded policy behavior

The RAM derivative checks the live WORK, backup, and expected old policy before
the first mutation. The existing candidate checksum check remains. The prompts
are `BACKUP B2F`, followed by `POLICY A6` or `POLICY FF`. Blank confirmation
cancels; cancellation at the second prompt leaves the verified backup written
but leaves live B3:F unchanged.

The updater copies and verifies the immediate live top to B2:F, then preserves
the live directory while writing the policy candidate to B3:F. On a failed
target write it remains in RAM: `R` retries the candidate, `O` restores the exact
verified pre-update top. A successful update or restore resets through STR8.
Do not reset or remove power while the updater is in active-write recovery.
These RAM recovery branches are not power-loss recovery guarantees.

With the checked baseline code/configuration, the resulting live top changes
only `$FFF2`. The runtime guard is not a full firmware hash check. Before future
use, compare fresh top bytes against the frozen baseline/expected checkpoint,
allowing only the explicitly predicted install journals. Stop on any other
drift; do not reuse an old policy artifact over different resident firmware.

## Paired installation command card — prepared, not executed

1. Complete the later slice's host/deployment gates before board execution.
   Capture fresh banks, require the accepted baseline hash, and retain both
   B1:F and B2:F externally. Verify artifact hashes and available journal pairs.
2. Enter STR8 and remain there. Use `I`, bank `2`, range `8`, check the summary,
   answer `Y`, send `candidate-am02-b2-8.s19`, then confirm final commit. Require
   `OK` and exact readback. No `TYPE`/`DESC` change is expected for this existing row.
3. Use `I`, bank `3`, range `C-E`, confirm and send
   `candidate-himon-b3-c-e.s19`, then commit. Require `OK` and exact readback.
   Do not enter HIMON between these transactions; mixed pairs are not accepted.
4. Compare live B3:F to `expected-paired-policy-ff-top.bin`. The STR8 installer
   consumes one START/COMPLETE pair in each of the B2 and B3 directory rows;
   this is an expected B3:F mutation, not directory corruption.
5. The later board slice must prove disabled-policy behavior before provisioning.
   Only then use STR8 `L` with `policy-a6/policy.s19` and the two named prompts.
   Preserve the pre-policy top and backup receipt. Compare live B3:F to
   `expected-paired-policy-a6-top.bin`; compare B2:F to the immediate pre-policy
   top. This step remains future board work.

The complete accepted baseline SHA-256 is
`3266041931068fd5a03db030eaef902be61bf2678fa75f1c559cee6df70741dc`.
Expected checkpoint files assume exactly the two successful pair transactions
above and no intervening journal-consuming installs. Fresh readbacks must
confirm the checkpoint; reprepare the bundle if the actual sequence differs.

## Rollback and interruption card

- For a completed pair with `$A6` enabled, first use the guarded `policy-ff`
  artifact from STR8 and verify disabled policy and its backup. If a policy
  write is currently in RAM recovery, finish `R`/`O` there instead of restarting.
- While both directory rows are COMPLETE, restore old HIMON C-E and old AM01
  B2:8 through STR8 `I`, staying in STR8 until both exact readbacks pass. These
  are two transactions, not atomic activation. Do not use named AP commands.
- If either transaction was interrupted, a narrow retry is refused by STR8.
  For B3 use full `8-E`; for B2 use full `8-F`. Select the old/new pair and the
  B2 backup generation deliberately. Full B2 recovery rewrites B2:F as well as
  APTEST and other B2 sectors, so verify every byte against its stage-specific
  archive afterward. These broader writes are contingency recovery only.
- A new or unexpected directory prompt, invalid/exhausted journal, different
  backup generation, or baseline drift is a stop condition. Do not refresh the
  directory or silently broaden the write range. Reprepare from actual state.
- Restoration of payloads does not rewind monotonic directory journals.
  Verify immutable directory metadata, COMPLETE state, expected journal bits,
  policy/roles, preserved sectors, and the final full archive.

## Focused host evidence and limits

All **33 focused checks pass**. Artifact hashes are retained with the exact
builder/checker sources and build logs in the evidence bundle.

The check executes linked RAM updater instructions against modeled banked flash:
backup, candidate write, live-directory preservation, both confirmations,
unexpected-role/policy refusal, retry and old-top recovery. Only B2:F/B3:F may
mutate. The borrowed model's red LED latch is a test precondition, not visual
or electrical evidence.

It also executes the linked STR8 dense receiver on every paired/recovery stream
and the full `I` command path for install, rollback, incomplete-journal narrow
refusal, and full-range recovery. Console, physical worker dispatch, and
directory byte writes are intercepted in those pair tests; real journal
classification, framing, staging, and START/COMPLETE logic execute. This is
preparation evidence, not board acceptance or a replacement for the next
slice's full host regression and deployment gates.
