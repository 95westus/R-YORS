# ASM Current Test Plan

This is the current, compact acceptance plan for ASM-F2 and its AP/OIL
boundary. Completed chronological gates were moved intact to
[TEST_HISTORY.md](TEST_HISTORY.md). Board transcripts remain in the
[hardware test log](../LOGS/HARDWARE_TEST_LOG.md).

For live commands and ownership, the
[capability matrix](../CAPABILITIES.md) is authoritative.

## Acceptance Rule

An ASM feature is complete only when all applicable gates agree:

1. source and generated contracts are current;
2. focused host regression tests pass;
3. the full ASM regression target passes;
4. resident size and memory ownership remain within their frozen bounds;
5. operator and technical documentation describe the resulting behavior;
6. destructive, banked, or board-specific behavior has recorded hardware
   proof.

The feature queue in [TODO.md](../PLANNING/TODO.md) remains unchecked until
those gates agree.

## Host Gate

Run the complete supported suite:

```text
make -C SRC asm-test
```

That target includes the ASM ABI, AP Store, APMAN, opcode, compact-data,
terminal, STR8 read-only bank-tool, WDC comparison, runtime, paste, flash,
session-report, AP-v2, BANKAUDIT, BANKDUMP, and PIA carrier checks declared by
`SRC/Makefile`.

Useful focused gates are:

```text
make -C SRC asm-abi-check
make -C SRC asm-opcode-coverage
make -C SRC asm-dc-check
make -C SRC asm-ap-v2-check
make -C SRC ap-store-v1-check
make -C SRC ap-store-inventory-check
make -C SRC ap-store-sector-tool-check
make -C SRC ap-store-chain-tool-check
make -C SRC ap-store-slice6-tool-check
make -C SRC himon-banked-ap-check
make -C SRC himon-str8-record-check
make -C SRC str8-readonly-bank-tools-check
```

Run `git diff --check` before accepting documentation or source changes.

## Current Board Gate

For changes that touch the onboard path, prove only the affected rows plus the
short regression rail:

- boot through STR8-N into the expected HIMON/ASM-F2 identity;
- assemble a known-good source and confirm emitted bytes and status;
- `SEAL`, `PACKAGE`, and direct AP load/link where applicable;
- `INSTALL package Bn`, reset-time rediscovery, `APS`, named `AP`, and `AP L`
  for carrier or manager changes;
- missing-import, overlap, malformed-envelope, and bank-restore rejection for
  AP/OIL changes;
- before/after sector or bank CRCs for every flash mutation;
- physical reset recovery to Bank 3 after banked work.

Record the exact image identity, commands, output, CRC evidence, and result in
the hardware log. Do not copy the whole procedure into the log; link this plan
or a focused board card and retain only evidence needed to distinguish the
run.

## Current Accepted Baseline

The capability matrix identifies the live release and board-accepted surface.
Baseline changes belong there first; this plan deliberately does not duplicate
the version and status narrative.

## Evidence Placement

| Information | Canonical home |
| --- | --- |
| Live commands, versions, and ABI ownership | `CAPABILITIES.md` |
| Current acceptance requirements | this file |
| Exact focused procedure | a narrowly scoped board card |
| Executed transcript and observed result | `LOGS/HARDWARE_TEST_LOG.md` |
| Completed development chronology | `TEST_HISTORY.md` |

Distinct failures, retries, corrections, and final acceptance runs are not
duplicates. Keep them when they explain why the accepted result is trustworthy.
