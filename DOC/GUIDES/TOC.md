# R-YORS Guide TOC

## Reading Order

1. [INDEX.md](./INDEX.md) - top-level guide index and current source snapshot.
2. [MAP.md](./MAP.md) - where each document fits.
3. [HASH_FLASH.md](./HASH_FLASH.md) - command-surface alerts and recent rehashes.
4. [GLOSSARY.md](./GLOSSARY.md) - shared vocabulary.
5. [DECISIONS.md](./DECISIONS.md) - settled calls to avoid reopening by accident.
6. [QCC.md](./QCC.md) - Questions, Comments, Concerns style and topic index.
7. [HISTORICAL_DOCUMENTS.md](./HISTORICAL_DOCUMENTS.md) - how the current monitor direction emerged.
8. [HIMON_STAGES_CLASSES.md](./HIMON_STAGES_CLASSES.md) - reconstructed HIMON
   stages and routine-class families.
9. [STR8.md](./STR8.md) - Subroutine To Return recovery/update monitor.
10. [RTFM-str8.md](./RTFM-str8.md) - compact STR8 operating instructions.
11. [RTFM-himon.md](./RTFM-himon.md) - compact HIMON/STR8 boundary instructions.
12. [BRINGUP.md](./BRINGUP.md) - practical STR8/R-YORS bringup rail.
13. [HASH_MAP.md](./HASH_MAP.md) - hash systems and where they live.
14. [QCC_HASH.md](./QCC_HASH.md) - hash-width and compact signature QCC.
15. [QCC_FLASH.md](./QCC_FLASH.md) - FSB lifecycle and condense/compress QCC.
16. [HASHED_ASM.md](./HASHED_ASM.md) - detailed assembler hypothesis.
17. [QCC_ASM.md](./QCC_ASM.md) - hashed assembler symbol/fixup QCC.
18. [QCC_STR8.md](./QCC_STR8.md) - STR8 ownership and recovery/update QCC.
19. [CATALOG.md](./CATALOG.md) - programmer-facing routine catalog by
   read/write/string/hex/hash/flash need.
20. [LIFE_RCAT_MEMBER.md](./LIFE_RCAT_MEMBER.md) - worked example for moving
   standalone LIFE into an RBODY/RREC/RCAT member.
21. [MEMORY_MAP.md](./MEMORY_MAP.md) - current HIMON ROM/RAM memory map,
    compatibility entries, vectors, and STR8/HIMON integration direction.
22. [QCC_MEMORY.md](./QCC_MEMORY.md) - memory ranges, 4K selectors, and bit-helper QCC.
23. [DYNAMIC_MEMORY_FIRST_STEPS.md](./DYNAMIC_MEMORY_FIRST_STEPS.md) - first
    dynamic allocation notes for bytes, words, pointers, pools, and heap scope.
24. [SYMBOL_XREF.md](./SYMBOL_XREF.md) - symbol contracts, source cross-reference,
   semantic tags, and HIMON call tree.
25. [HIMON_MAP.md](./HIMON_MAP.md) - readable HIMON edge and
    capability maps.
26. [HIMON_EDGE_DUMP.md](./HIMON_EDGE_DUMP.md) - direct HIMON
    `JSR`/`JMP` edge dump.
27. [REF.md](./REF.md) - current reference sheet.
28. [XREF.md](./XREF.md) - document/source cross-reference.
29. [HASH.md](./HASH.md) - routine header IDs and FNV-1a relationship.
30. [TODO.md](./TODO.md) - next work.
31. [FUTURE.md](./FUTURE.md) - direction.
32. [BIB.md](./BIB.md) - internal source list.

## Core Thread

The current conceptual path is:

```text
R-YORS
  -> STR8 boot/recovery/update guard
  -> HIMON monitor/debug environment
  -> hash-first command and symbol lookup
  -> onboard assembler with fixups
  -> banked flash growth and catalog maintenance
```

## File Roles

```text
INDEX.md       navigation and source snapshot
MAP.md         document/system map
HASH_FLASH.md  command-surface alerts and recent rehashes
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
QCC_HASH.md    hash-width and compact signature questions
QCC_FLASH.md   FSB lifecycle and condense/compress questions
STR8.md        recovery/update monitor design
RTFM-str8.md   compact STR8 operating instructions
RTFM-himon.md  compact HIMON/STR8 boundary instructions
BRINGUP.md     practical STR8/R-YORS bringup rail
HASHED_ASM.md  assembler thesis
QCC_ASM.md     assembler symbol/fixup questions
QCC_STR8.md    STR8 ownership and recovery/update questions
QCC_MEMORY.md  memory selectors, allocation, and bit-helper questions
```
