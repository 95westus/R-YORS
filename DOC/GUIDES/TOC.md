# R-YORS Guide TOC

## Reading Order

1. [INDEX.md](./INDEX.md) - top-level guide index and current source snapshot.
2. [MAP.md](./MAP.md) - where each document fits.
3. [GLOSSARY.md](./GLOSSARY.md) - shared vocabulary.
4. [DECISIONS.md](./DECISIONS.md) - settled calls to avoid reopening by accident.
5. [HISTORICAL_DOCUMENTS.md](./HISTORICAL_DOCUMENTS.md) - how the current monitor direction emerged.
6. [HIMON_STAGES_CLASSES.md](./HIMON_STAGES_CLASSES.md) - reconstructed HIMON
   stages and routine-class families.
7. [STR8.md](./STR8.md) - Subroutine To Return recovery/update monitor.
8. [BRINGUP.md](./BRINGUP.md) - practical STR8/R-YORS bringup rail.
9. [HASH_MAP.md](./HASH_MAP.md) - hash systems and where they live.
10. [HASHED_ASM.md](./HASHED_ASM.md) - detailed assembler hypothesis.
11. [CATALOG.md](./CATALOG.md) - programmer-facing routine catalog by
   read/write/string/hex/hash/flash need.
12. [MEMORY_MAP.md](./MEMORY_MAP.md) - current Himonia-F ROM/RAM memory map,
    compatibility entries, vectors, and STR8/HIMON integration direction.
13. [DYNAMIC_MEMORY_FIRST_STEPS.md](./DYNAMIC_MEMORY_FIRST_STEPS.md) - first
    dynamic allocation notes for bytes, words, pointers, pools, and heap scope.
14. [SYMBOL_XREF.md](./SYMBOL_XREF.md) - symbol contracts, source cross-reference,
   semantic tags, and Himonia-F call tree.
15. [HIMON_MAP.md](./HIMON_MAP.md) - readable HIMON edge and
    capability maps.
16. [HIMON_EDGE_DUMP.md](./HIMON_EDGE_DUMP.md) - direct HIMON
    `JSR`/`JMP` edge dump.
17. [REF.md](./REF.md) - current reference sheet.
18. [XREF.md](./XREF.md) - document/source cross-reference.
19. [HASH.md](./HASH.md) - routine header IDs and FNV-1a relationship.
20. [TODO.md](./TODO.md) - next work.
21. [FUTURE.md](./FUTURE.md) - direction.
22. [BIB.md](./BIB.md) - internal source list.

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
DECISIONS.md   settled calls
HIMON_STAGES_CLASSES.md reconstructed HIMON stages and class families
REF.md         quick operational reference
XREF.md        relationships between docs, sources, and symbols
CATALOG.md     programmer-facing callable routine catalog
MEMORY_MAP.md  current Himonia-F ROM/RAM ranges, compatibility entries, and vectors
DYNAMIC_MEMORY_FIRST_STEPS.md first dynamic allocation scope and mechanics
SYMBOL_XREF.md symbol contracts and semantic classification
HIMON_MAP.md readable edge and capability maps for HIMON
HIMON_EDGE_DUMP.md full direct edge dump for HIMON
BIB.md         internal references
HASH_MAP.md    map of hash concepts
STR8.md        recovery/update monitor design
BRINGUP.md     practical STR8/R-YORS bringup rail
HASHED_ASM.md  assembler thesis
```
