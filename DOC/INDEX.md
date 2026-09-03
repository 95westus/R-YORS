# R-YORS Documentation

This is the single documentation front door. Current authorities come first;
dated plans, cards, and transcripts are supporting evidence rather than an
alternate description of the live board.

## Start Here

1. [Current Capability Matrix](GUIDES/CAPABILITIES.md) — what STR8-N, HIMON,
   ASM-F2, APMAN, and AP Store can do now, what is possible next, what is not
   supported, and the evidence boundary between those states.
2. [Installation Flow](GUIDES/INSTALLATION_FLOW.md) — ordered factory
   WDCMONv2 preservation, STR8-N migration, Bank Maintenance adoption, and
   optional HIMON/ASM-F2 installation.
3. [Operator's Guide](GUIDES/OPERATORS_GUIDE.md) — current board workflows,
   safety, recovery, and HIMON use.
4. [Technical Guide](GUIDES/TECHNICAL_GUIDE.md) — component boundaries,
   build products, memory, and runtime architecture.
5. [ASM User Guide](GUIDES/ASM/ASM_USER_GUIDE.md) — source entry, assembly,
   SEAL, PACKAGE, INSTALL, and AP operation.
6. [AP And OIL Guide](GUIDES/AP/AP_OIL_GUIDE.md) — AP/APC, OIL, APMAN,
   carrier storage, linking, and AP Store boundaries.

The capability matrix wins when a dated plan, card, transcript, or story page
shows an older command or image.

## Compact Authorities

- [Quick Reference](GUIDES/REF.md)
- [Memory Map](GUIDES/MEMORY/MEMORY_MAP.md)
- [Decisions](GUIDES/DECISIONS.md)
- [Glossary](GUIDES/GLOSSARY.md)
- [ASM ABI v1](GUIDES/ASM/ASM_ABI_V1.md)
- [ASM Current Test Plan](GUIDES/ASM/TEST_PLAN.md)
- [STR8/R-YORS Product Boundaries](GUIDES/STR8/PRODUCT_BOUNDARIES.md)

## Current Deep References

- [HIMON Map](GUIDES/HIMON/HIMON_MAP.md) — readable command, lifecycle, and
  routine map.
- [HIMON Debug Testing](GUIDES/HIMON/HIMON_DEBUG_TESTING.md) — RAM debug proof
  process.
- [ASM Call Map](GUIDES/ASM/ASM_CALL_MAP.md) — assembler routine and phase
  flow.
- [ASM Address Practices](GUIDES/ASM/ADDRESS_PRACTICES.md) — address roles and
  safe placement.
- [APMAN/APC Dissection](GUIDES/ASM/APMAN_APC_DISSECTION.md) — exact carrier,
  envelope, RAM overlay, and service maps.
- [Carrier Versus AP Store](GUIDES/ASM/BANKED_AP_CARRIER_VS_AP_STORE.md) —
  storage-model comparison.
- [Catalog](GUIDES/CATALOG/CATALOG.md) and
  [Hash Map](GUIDES/HASH/HASH_MAP.md) — callable-routine and hash references.

## Evidence And History

- [History And Evidence Index](GUIDES/HISTORY.md) — status classes and routing
  for retained material.
- [Hardware Test Log](GUIDES/LOGS/HARDWARE_TEST_LOG.md) — executed board
  transcripts and observed results.
- [ASM Test History](GUIDES/ASM/TEST_HISTORY.md) — completed cumulative test
  and development chronology.
- [STR8 Integration Index](GUIDES/STR8/STR8.md) — R-YORS consumer boundary and
  retained STR8 proof cards.
- [Story](GUIDES/STORY/BOOK.md) and
  [Historical Documents](GUIDES/STORY/HISTORICAL_DOCUMENTS.md) — narrative and
  lineage, outside the operating path.

Historical filenames and paths are generally retained because board evidence
refers to them. A historical card proves its named image; it is not a current
instruction merely because the underlying mechanism survived.

## Planning

- [TODO And ASM Feature Queue](GUIDES/PLANNING/TODO.md)
- [Future Direction](GUIDES/PLANNING/FUTURE.md)
- [QCC Incubator](GUIDES/QCC/INDEX.md) — unsettled questions, comments, and
  concerns.

R-YORS II architecture, language, and release planning live in the sibling
`R-YORS-II` repository. Current STR8-N implementation and source-derived maps
live in the adjacent standalone STR8-N repository; this repository retains its
consumer contract and R-YORS hardware proof.

## Generated Source Analysis

[Generated maps](GENERATED/MAP_OF_MAPS.md) are source-derived supporting
views, not hand-maintained authorities. This shelf includes routine, command,
interrupt, stack, control-deck, and raw HIMON edge maps.

## Maintenance Rule

Add each new document to exactly one authority/status class in
[History And Evidence](GUIDES/HISTORY.md). Update this front door only when the
main reading path changes; do not recreate separate full indexes, reading-order
files, or documentation maps.
