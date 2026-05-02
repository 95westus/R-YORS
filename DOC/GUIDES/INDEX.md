# R-YORS Guide Index

This is the top index for the `ror` documentation set.

## Start Here

- [TOC.md](./TOC.md) - recommended reading order.
- [MAP.md](./MAP.md) - documentation map and system map.
- [DECISIONS.md](./DECISIONS.md) - settled calls to avoid reopening by accident.
- [REF.md](./REF.md) - quick operational reference.
- [XREF.md](./XREF.md) - document and source cross-reference.
- [SYMBOL_XREF.md](./SYMBOL_XREF.md) - symbol ref/xref/semantic classification.
- [CATALOG.md](./CATALOG.md) - programmer-facing routine catalog by need.
- [MEMORY_MAP.md](./MEMORY_MAP.md) - current Himonia-F ROM and RAM memory map.
- [BIB.md](./BIB.md) - internal corpus used by these notes.

## Core Design Guides

- [HISTORICAL_DOCUMENTS.md](./HISTORICAL_DOCUMENTS.md) - path from BSO2 ideas to Himonia-F.
- [DECISIONS.md](./DECISIONS.md) - naming, hash, STR8, ASM, ABI, local-home,
  and doc-shape decisions.
- [HIMON_STAGES_CLASSES.md](./HIMON_STAGES_CLASSES.md) - reconstruction of
  HIMON stages and routine-class families.
- [STR8.md](./STR8.md) - Straight 8 recovery/update monitor.
- [STR8_DECISION_REFERENCE.md](./STR8_DECISION_REFERENCE.md) - current STR8
  first-test design decisions.
- [HASHED_ASM.md](./HASHED_ASM.md) - onboard hashed assembler, symbols, and fixups.
- [HASH_MAP.md](./HASH_MAP.md) - hash uses across docs, runtime dispatch, and assembler records.
- [MEMORY_MAP.md](./MEMORY_MAP.md) - current Himonia-F ROM image, RAM workspace,
  fixed ABI entries, vectors, and STR8 ownership direction.
- [DYNAMIC_MEMORY_FIRST_STEPS.md](./DYNAMIC_MEMORY_FIRST_STEPS.md) - first
  steps for byte, word, pointer, bump, pool, and free-list allocation thinking.
- [HIMON_MAP.md](./HIMON_MAP.md) - readable HIMON edge and capability maps.

## Reference Guides

- [HASH.md](./HASH.md) - routine header `[HASH:XXXXXXXX]` FNV-1a IDs.
- [CATALOG.md](./CATALOG.md) - compact callable routine catalog by read/write/string/hex/hash/flash need.
- [MEMORY_MAP.md](./MEMORY_MAP.md) - address ranges and ownership for current
  Himonia-F ROM/RAM.
- [DYNAMIC_MEMORY_FIRST_STEPS.md](./DYNAMIC_MEMORY_FIRST_STEPS.md) - scoped
  dynamic memory allocation direction for future user/app/session work.
- [SYMBOL_XREF.md](./SYMBOL_XREF.md) - STASH/Himonia-F symbol cards, ABI fields,
  classification tokens, and Himonia-F call tree.
- [HIMON_MAP.md](./HIMON_MAP.md) - grouped HIMON edge maps and
  full capability map.
- [HIMON_STAGES_CLASSES.md](./HIMON_STAGES_CLASSES.md) - human stage/class
  reconstruction for HIMON and the Himonia-F promotion path.
- [HIMON_EDGE_DUMP.md](./HIMON_EDGE_DUMP.md) - generated-style direct
  `JSR`/`JMP` edge dump for HIMON.
- [GLOSSARY.md](./GLOSSARY.md) - vocabulary for layers, monitors, hashes, and STR8.

## Planning

- [TODO.md](./TODO.md) - near-term doc and implementation work.
- [FUTURE.md](./FUTURE.md) - direction notes.

## Current Source Snapshot

Quick scan of `ror/SRC`:

```text
ASM files:             37
XDEF declarations:     339 total, 328 unique names
XREF declarations:     354 total, 200 unique names
ROUTINE headers:       228 total, 226 unique first names
JSR/JMP call sites:    2259 total, 450 unique targets
```

Lane count:

```text
SRC/STASH: 1 ASM file
SRC/TEST:  35 ASM files
SRC/SESH:  1 ASM file
```

This index intentionally points only inside `ror`. Historical notes may mention
earlier BSO2 material when explaining lineage, but this guide set is maintained
from the current `ror` workspace.
