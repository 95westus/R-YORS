# R-YORS Guide TOC

## Reading Order

1. [INDEX.md](./INDEX.md) - top-level guide index and current source snapshot.
2. [MAP.md](./MAP.md) - where each document fits.
3. [PRODUCT_BOUNDARIES.md](./PRODUCT_BOUNDARIES.md) - R-YORS, STR8, IVI/LEAF,
   HIMON, and payload ownership lanes.
4. [BOOK.md](./BOOK.md) - narrative spine for the hashed runtime system book.
5. [HASH_FLASH.md](./HASH_FLASH.md) - command-surface alerts and recent rehashes.
6. [DOC_FLASH.md](./DOC_FLASH.md) - doc/edict alerts and recent REDOC notes.
7. [GLOSSARY.md](./GLOSSARY.md) - shared vocabulary.
8. [DECISIONS.md](./DECISIONS.md) - settled calls to avoid reopening by accident.
9. [QCC.md](./QCC.md) - Questions, Comments, Concerns style and topic index.
10. [HISTORICAL_DOCUMENTS.md](./HISTORICAL_DOCUMENTS.md) - how the current monitor direction emerged.
11. [HIMON_STAGES_CLASSES.md](./HIMON_STAGES_CLASSES.md) - reconstructed HIMON
   stages and routine-class families.
12. [STR8.md](./STR8.md) - Subroutine To Return recovery/update monitor.
13. [STR8_WORK_PROCESS.md](./STR8_WORK_PROCESS.md) - current STR8 work rail.
14. [RTFM-str8.md](./RTFM-str8.md) - compact STR8 operating instructions and
    current three-image milestone.
15. [RTFM-himon.md](./RTFM-himon.md) - compact HIMON/STR8 boundary instructions.
16. [HIMON_DEBUG_TESTING.md](./HIMON_DEBUG_TESTING.md) - bench process for HIMON debug testing.
17. [HARDWARE_TEST_LOG.md](./HARDWARE_TEST_LOG.md) - board transcript validations and bench findings.
18. [HIMON_SEARCH_IMPLEMENTATION_GUIDE.md](./HIMON_SEARCH_IMPLEMENTATION_GUIDE.md) - RAM-to-flash guide for HIMON memory search.
19. [HREC_JOIN_PROOF.md](./HREC_JOIN_PROOF.md) - RAM proof and vocabulary for joining current HREC records to callable entries.
20. [BRINGUP.md](./BRINGUP.md) - practical STR8/R-YORS bringup rail.
21. [HASH_MAP.md](./HASH_MAP.md) - hash systems and where they live.
22. [QCC_HASH.md](./QCC_HASH.md) - compact-hash and signature QCC.
23. [QCC_FLASH.md](./QCC_FLASH.md) - FSB lifecycle and condense/compress QCC.
24. [HASHED_ASM.md](./HASHED_ASM.md) - detailed assembler hypothesis.
25. [QCC_ASM.md](./QCC_ASM.md) - hashed assembler symbol/fixup QCC.
26. [QCC_CATALOG_LINKING.md](./QCC_CATALOG_LINKING.md) - catalog-linking bootstrap QCC.
27. [QCC_STR8.md](./QCC_STR8.md) - STR8 ownership and recovery/update QCC.
28. [CATALOG.md](./CATALOG.md) - programmer-facing routine catalog by
   read/write/string/hex/hash/flash need.
29. [LIFE_RCAT_MEMBER.md](./LIFE_RCAT_MEMBER.md) - worked example for moving
   standalone LIFE into an RBODY/RREC/RCAT member.
30. [MEMORY_MAP.md](./MEMORY_MAP.md) - current HIMON ROM/RAM memory map,
    compatibility entries, vectors, and STR8/HIMON integration direction.
31. [QCC_MEMORY.md](./QCC_MEMORY.md) - memory ranges, 4K selectors, and bit-helper QCC.
32. [DYNAMIC_MEMORY_FIRST_STEPS.md](./DYNAMIC_MEMORY_FIRST_STEPS.md) - first
    dynamic allocation notes for bytes, words, pointers, pools, and heap scope.
33. [SYMBOL_XREF.md](./SYMBOL_XREF.md) - symbol contracts, source cross-reference,
   semantic tags, and HIMON call tree.
34. [HIMON_MAP.md](./HIMON_MAP.md) - readable HIMON edge and
    capability maps.
35. [HIMON_EDGE_DUMP.md](./HIMON_EDGE_DUMP.md) - direct HIMON
    `JSR`/`JMP` edge dump.
36. [REF.md](./REF.md) - current reference sheet.
37. [XREF.md](./XREF.md) - document/source cross-reference.
38. [HASH.md](./HASH.md) - current FNV-era IDs and the CRC16 hash pivot.
39. [TODO.md](./TODO.md) - next work.
40. [FUTURE.md](./FUTURE.md) - direction.
41. [BIB.md](./BIB.md) - internal source list.

## Core Thread

The current conceptual path is:

```text
R-YORS
  -> STR8 board management product
  -> IVI mechanism and LEAF front door
  -> HIMON default monitor payload
  -> other payload targets
  -> compact-hash command and symbol lookup
  -> onboard assembler with fixups
  -> banked flash growth and catalog maintenance
```

## File Roles

```text
INDEX.md       navigation and source snapshot
MAP.md         document/system map
PRODUCT_BOUNDARIES.md R-YORS, STR8, IVI/LEAF, HIMON, and payload ownership lanes
BOOK.md        narrative spine for the hashed runtime system book
HASH_FLASH.md  command-surface alerts and recent rehashes
DOC_FLASH.md   doc/edict alerts and recent REDOC notes
DECISIONS.md   settled calls
QCC.md         Questions, Comments, Concerns style and topic index
HIMON_STAGES_CLASSES.md reconstructed HIMON stages and class families
REF.md         quick operational reference
XREF.md        relationships between docs, sources, and symbols
CATALOG.md     programmer-facing callable routine catalog
LIFE_RCAT_MEMBER.md worked example for promoting standalone LIFE to RCAT member
MEMORY_MAP.md  current HIMON ROM/RAM ranges, compatibility entries, and vectors
DYNAMIC_MEMORY_FIRST_STEPS.md first dynamic allocation scope and mechanics
SYMBOL_XREF.md symbol contracts and semantic classification
HIMON_MAP.md readable edge and capability maps for HIMON
HIMON_EDGE_DUMP.md full direct edge dump for HIMON
BIB.md         internal references
HASH_MAP.md    map of hash concepts
QCC_HASH.md    compact-hash and signature questions
QCC_FLASH.md   FSB lifecycle and condense/compress questions
STR8.md        recovery/update monitor design and current hardware milestone
STR8_WORK_PROCESS.md current review/proof/implementation rail for STR8
RTFM-str8.md   compact STR8 operating instructions and proven-image notes
RTFM-himon.md  compact HIMON/STR8 boundary instructions
HIMON_DEBUG_TESTING.md bench process for HIMON debug testing
HARDWARE_TEST_LOG.md board transcript validations and bench findings
HIMON_SEARCH_IMPLEMENTATION_GUIDE.md RAM proof, flash S19 delivery, and integration guide for search
HREC_JOIN_PROOF.md RAM proof and terminology for joining HREC records to entries
BRINGUP.md     practical STR8/R-YORS bringup rail
HASHED_ASM.md  assembler thesis
QCC_ASM.md     assembler symbol/fixup questions
QCC_CATALOG_LINKING.md catalog-linking bootstrap and payload-baggage questions
QCC_STR8.md    STR8 ownership and recovery/update questions
QCC_MEMORY.md  memory selectors, allocation, and bit-helper questions
```
