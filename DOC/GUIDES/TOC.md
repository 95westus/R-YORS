# R-YORS Guide TOC

## Reading Order

1. [INDEX.md](./INDEX.md) - top-level guide index and current source snapshot.
2. [MAP.md](./MAP.md) - where each document fits.
3. [GLOSSARY.md](./GLOSSARY.md) - shared vocabulary.
4. [DECISIONS.md](./DECISIONS.md) - settled calls to avoid reopening by accident.
5. [HISTORICAL_DOCUMENTS.md](./HISTORICAL_DOCUMENTS.md) - how the current monitor direction emerged.
6. [STR8.md](./STR8.md) - Straight 8 recovery/update monitor.
7. [HASH_MAP.md](./HASH_MAP.md) - hash systems and where they live.
8. [HASHED_ASM.md](./HASHED_ASM.md) - detailed assembler hypothesis.
9. [CATALOG.md](./CATALOG.md) - programmer-facing routine catalog by
   read/write/string/hex/hash/flash need.
10. [MEMORY_MAP.md](./MEMORY_MAP.md) - current Himonia-F ROM/RAM memory map,
    ABI slots, vectors, and STR8 ownership direction.
11. [SYMBOL_XREF.md](./SYMBOL_XREF.md) - symbol contracts, source cross-reference,
   semantic tags, and Himonia-F call tree.
12. [HIMONIA_F_MAP.md](./HIMONIA_F_MAP.md) - readable Himonia-F edge and
    capability maps.
13. [HIMONIA_F_EDGE_DUMP.md](./HIMONIA_F_EDGE_DUMP.md) - direct Himonia-F
    `JSR`/`JMP` edge dump.
14. [REF.md](./REF.md) - current reference sheet.
15. [XREF.md](./XREF.md) - document/source cross-reference.
16. [HASH.md](./HASH.md) - routine header IDs and FNV-1a relationship.
17. [TODO.md](./TODO.md) - next work.
18. [FUTURE.md](./FUTURE.md) - direction.
19. [BIB.md](./BIB.md) - internal source list.

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
REF.md         quick operational reference
XREF.md        relationships between docs, sources, and symbols
CATALOG.md     programmer-facing callable routine catalog
MEMORY_MAP.md  current Himonia-F ROM/RAM ranges, ABI entries, and vectors
SYMBOL_XREF.md symbol contracts and semantic classification
HIMONIA_F_MAP.md readable edge and capability maps for Himonia-F
HIMONIA_F_EDGE_DUMP.md full direct edge dump for Himonia-F
BIB.md         internal references
HASH_MAP.md    map of hash concepts
STR8.md        recovery/update monitor design
HASHED_ASM.md  assembler thesis
```
