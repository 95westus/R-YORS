# History And Evidence Index

This index separates current documentation from retained design and hardware
evidence. Historical does not mean disposable: dated cards and transcripts
often describe the only reproducible proof for their image. They do not,
however, define the current command surface.

## Status Classes

| Class | Meaning |
| --- | --- |
| Current authority | Defines the live system and should be maintained in place. |
| Current deep reference | Accurate detail supporting an authority without restating all current status. |
| Evidence | A dated plan, card, result, or transcript for a particular image. |
| Historical design | Useful reasoning or lineage that no longer defines current operation. |
| Generated | Rebuilt from source; never hand-maintained as authority. |
| Incubator | Unsettled QCC, planning, or future work. |

## Current Authority

- [Capabilities](CAPABILITIES.md)
- [Operator's Guide](OPERATORS_GUIDE.md)
- [Technical Guide](TECHNICAL_GUIDE.md)
- [Quick Reference](REF.md)
- [Decisions](DECISIONS.md)
- [Glossary](GLOSSARY.md)
- [Memory Map](MEMORY/MEMORY_MAP.md)
- [ASM User Guide](ASM/ASM_USER_GUIDE.md)
- [ASM Current Test Plan](ASM/TEST_PLAN.md)
- [AP And OIL Guide](AP/AP_OIL_GUIDE.md)

## Current Deep References

- `HIMON/HIMON_MAP.md`
- `HIMON/HIMON_DEBUG_TESTING.md`
- `ASM/ASM_ABI_V1.md`
- `ASM/ASM_CALL_MAP.md`
- `ASM/ADDRESS_PRACTICES.md`
- `ASM/APMAN_APC_DISSECTION.md`
- `ASM/BANKED_AP_CARRIER_VS_AP_STORE.md`
- `STR8/PRODUCT_BOUNDARIES.md`
- `STR8/STR8_GUEST_IMAGE_QUALIFICATION.md`

## Evidence

- `LOGS/HARDWARE_TEST_LOG.md` is the hardware transcript ledger.
- `ASM/TEST_HISTORY.md` is the completed cumulative ASM development and test
  chronology formerly stored in `ASM/TEST_PLAN.md`.
- Files named `*_BOARD_TEST.md`, `*_BOARD_CARD.md`, or similar are scoped
  evidence for the image stated in the file, even when the proved mechanism
  remains current.
- `ASM/SAMPLES/OLD/` preserves source and cards referenced by historical
  evidence.
- `STORY/HIMON_STR8_LIVE_UPDATE_LOG.md` preserves its named update/rollback
  proof.

## Historical Design

- `ASM/HASHED_ASM.md` is the assembler design notebook and implementation
  lineage. Use the ASM User Guide and ABI for current behavior.
- `HIMON/HIMON_SEARCH_IMPLEMENTATION_GUIDE.md` records the retired resident
  search experiment.
- `STR8/BRINGUP.md`, `STR8/STR8_WORK_PROCESS.md`,
  `STR8/STR8_DECISION_REFERENCE.md`, and `STR8/STR8_FLASH_UPDATE_PROPOSAL.md`
  retain development reasoning. Current STR8-N implementation belongs to the
  adjacent STR8-N repository.
- `PLANNING/OIL_710_TEST_PLAN.md` is the `.710` OIL release rail, not the
  current AP/OIL guide.
- Completed STR8 V0/V1/V1.02 plans and cards retain their original names and
  paths so hardware-log references remain valid.

## Generated Material

Everything under `DOC/GENERATED/` is source-derived. The generated HIMON edge
dump lives there with the other raw maps. Regenerate these documents through
the make targets; edit their generators rather than their output.

## Incubator And Planning

- `QCC/` contains unsettled questions, comments, and concerns.
- `PLANNING/TODO.md` contains the active feature queue.
- Other `PLANNING/` documents are accepted proposals, future work, or dated
  implementation plans as stated by their front matter.
- Settled QCC answers belong in `DECISIONS.md`.

## Retention Rules

- Current authorities summarize and link; they do not carry hardware
  chronology.
- Evidence records exact identity, observations, and outcome; it does not
  redefine current commands.
- Repeated output in different runs is retained when it proves regression or
  recovery. Exact duplicate blocks from the same test should be removed.
- Do not rewrite a historical command into current syntax.
- Prefer status banners and this index over moving files whose paths occur in
  hardware transcripts.
