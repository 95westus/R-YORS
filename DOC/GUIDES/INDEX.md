# R-YORS Guide Index

This is the top index for the `ror` documentation set.

## Start Here

- [TOC.md](./TOC.md) - recommended reading order.
- [MAP.md](./MAP.md) - documentation map and system map.
- [HASH_FLASH.md](./HASH_FLASH.md) - short alert stream for command-surface changes.
- [DECISIONS.md](./DECISIONS.md) - settled calls to avoid reopening by accident.
- [RTFM-str8.md](./RTFM-str8.md) - compact STR8 operating instructions.
- [RTFM-himon.md](./RTFM-himon.md) - compact HIMON/STR8 boundary instructions.
- [QCC.md](./QCC.md) - Questions, Comments, Concerns for active design work.
- [REF.md](./REF.md) - quick operational reference.
- [XREF.md](./XREF.md) - document and source cross-reference.
- [SYMBOL_XREF.md](./SYMBOL_XREF.md) - symbol ref/xref/semantic classification.
- [CATALOG.md](./CATALOG.md) - programmer-facing routine catalog by need.
- [MEMORY_MAP.md](./MEMORY_MAP.md) - current HIMON ROM and RAM memory map.
- [BIB.md](./BIB.md) - internal corpus used by these notes.

## Core Design Guides

- [HISTORICAL_DOCUMENTS.md](./HISTORICAL_DOCUMENTS.md) - path from BSO2 ideas toward current HIMON.
- [HASH_FLASH.md](./HASH_FLASH.md) - REHASH/FLASHBACK notes for command syntax changes.
- [DECISIONS.md](./DECISIONS.md) - naming, hash, STR8, ASM, local-home,
  and doc-shape decisions.
- [BRINGUP.md](./BRINGUP.md) - practical STR8/R-YORS bringup rail.
- [HIMON_STAGES_CLASSES.md](./HIMON_STAGES_CLASSES.md) - reconstruction of
  HIMON stages and routine-class families.
- [STR8.md](./STR8.md) - Subroutine To Return recovery/update monitor.
- [STR8_DECISION_REFERENCE.md](./STR8_DECISION_REFERENCE.md) - current STR8
  first-run design decisions.
- [STR8_FLASH_UPDATE_PROPOSAL.md](./STR8_FLASH_UPDATE_PROPOSAL.md) - proposed
  STR8 scan, erase, HIMON update, and STR8 self-update flow.
- [RTFM-str8.md](./RTFM-str8.md) - small-command STR8 instructions.
- [RTFM-himon.md](./RTFM-himon.md) - normal monitor boundary instructions.
- [HASHED_ASM.md](./HASHED_ASM.md) - onboard hashed assembler, symbols, and fixups.
- [HASH_MAP.md](./HASH_MAP.md) - hash uses across docs, runtime dispatch, and assembler records.
- [LIFE_RCAT_MEMBER.md](./LIFE_RCAT_MEMBER.md) - worked example for
  turning standalone LIFE into an RBODY/RREC/RCAT member.
- [QCC.md](./QCC.md) - QCC style and topic index for unresolved design work.
- [QCC_HASH.md](./QCC_HASH.md) - hash-width, folded-hash, and compact
  signature questions.
- [QCC_FLASH.md](./QCC_FLASH.md) - FSB lifecycle, buried records, and
  condense/compress questions.
- [QCC_ASM.md](./QCC_ASM.md) - hashed assembler symbols, fixups, and record
  safety questions.
- [QCC_STR8.md](./QCC_STR8.md) - STR8 ownership, scanning, and recovery/update
  boundary questions.
- [QCC_MEMORY.md](./QCC_MEMORY.md) - memory ranges, 4K selectors, allocation,
  and bit-helper questions.
- [MEMORY_MAP.md](./MEMORY_MAP.md) - current HIMON ROM image, RAM workspace,
  compatibility entries, vectors, and STR8/HIMON integration direction.
- [DYNAMIC_MEMORY_FIRST_STEPS.md](./DYNAMIC_MEMORY_FIRST_STEPS.md) - first
  steps for byte, word, pointer, bump, pool, and free-list allocation thinking.
- [HIMON_MAP.md](./HIMON_MAP.md) - readable HIMON edge and capability maps.

## Reference Guides

- [HASH.md](./HASH.md) - routine header `[HASH:XXXXXXXX]` FNV-1a IDs.
- [CATALOG.md](./CATALOG.md) - compact callable routine catalog by read/write/string/hex/hash/flash need.
- [LIFE_RCAT_MEMBER.md](./LIFE_RCAT_MEMBER.md) - RCAT/RREC member
  migration worked example for the standalone LIFE app.
- [MEMORY_MAP.md](./MEMORY_MAP.md) - address ranges and ownership for current
  HIMON ROM/RAM.
- [DYNAMIC_MEMORY_FIRST_STEPS.md](./DYNAMIC_MEMORY_FIRST_STEPS.md) - scoped
  dynamic memory allocation direction for future user/app/session work.
- [SYMBOL_XREF.md](./SYMBOL_XREF.md) - STASH/HIMON symbol cards, ABI fields,
  classification tokens, and HIMON call tree.
- [HIMON_MAP.md](./HIMON_MAP.md) - grouped HIMON edge maps and
  full capability map.
- [HIMON_STAGES_CLASSES.md](./HIMON_STAGES_CLASSES.md) - human stage/class
  reconstruction for HIMON and its historical promotion path.
- [HIMON_EDGE_DUMP.md](./HIMON_EDGE_DUMP.md) - generated-style direct
  `JSR`/`JMP` edge dump for HIMON.
- [GLOSSARY.md](./GLOSSARY.md) - vocabulary for layers, monitors, hashes, and STR8.

## Planning

- [TODO.md](./TODO.md) - near-term doc and implementation work.
- [FUTURE.md](./FUTURE.md) - direction notes.

## Current Generated Source Snapshot

Quick scan of the operational HIMON/STR8 source set used by `DOC/GENERATED`:

```text
Source files scanned:  27
XDEF declarations:     179
XREF declarations:     143
ROUTINE headers:       130
JSR/JMP call sites:    989
Unique direct edges:   779
```

Operational lane count:

```text
SRC/STASH: 1 source file
ROM/HIMON/STR8: 25 source files
SRC/SESH:  1 source file
```

Legacy demos, harnesses, games, ACIA/PIA, and historical experiments remain
documented where useful, but they are not part of the generated operational
routine maps.

This index intentionally points only inside `ror`. Historical notes may mention
earlier BSO2 material when explaining lineage, but this guide set is maintained
from the current `ror` workspace.
