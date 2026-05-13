# R-YORS Cross-Reference

This file connects the guide set to the current `ror` source tree.

Cross-reference wording follows [GLOSSARY.md](./GLOSSARY.md), especially for
THE, hash32/hash16/hash8, Record/RREC, contract, source aliases, and
formed/sealed/buried/gone lifecycle terms.

## Document Cross-Reference

```text
STR8.md
  used by HASHED_ASM.md for flash commit/condense policy
  used by MAP.md for recovery/update ownership
  used by HISTORICAL_DOCUMENTS.md as the recovery-layer name

DECISIONS.md
  records settled naming, hash, STR8, ASM, contract, local-home, and doc-shape calls
  should be checked before reopening design alternatives
  overrides looser exploratory notes unless explicitly reopened

QCC.md
  defines Questions, Comments, Concerns as the working-note style for active
  design questions
  indexes QCC_HASH, QCC_FLASH, QCC_ASM, QCC_STR8, and QCC_MEMORY
  feeds DECISIONS.md when a working answer becomes settled

HASH_MAP.md
  points to HASH.md for ROUTINE header IDs
  points to HASHED_ASM.md for symbol/fixup hashes
  points to current HIMON sources for runtime FNV

QCC_HASH.md
  keeps 1/2/4 byte hash-width questions, folded FNV-1a helper questions, F/N/V
  table layout questions, and compact signature concerns
  relates to HASH_MAP.md, HASH.md, and QCC_FLASH.md

QCC_FLASH.md
  keeps FSB lifecycle questions for formed, sealed, and buried flash records
  records condense triggers, purge classes, and ownership concerns
  relates to STR8.md, MEMORY_MAP.md, and QCC_HASH.md

HASHED_ASM.md
  depends on STR8.md for flash safety
  depends on HASH_MAP.md for hash vocabulary
  feeds FUTURE.md and TODO.md implementation direction

QCC_ASM.md
  keeps hash-first assembler questions about labels, symbol text, fixups, and
  sealed record output
  relates to HASHED_ASM.md and QCC_FLASH.md

QCC_STR8.md
  keeps STR8/STRAIGHTEN questions about ownership, scan ranges, recovery/update
  boundaries, and catalog maintenance
  relates to STR8.md, BRINGUP.md, MEMORY_MAP.md, and QCC_FLASH.md

QCC_MEMORY.md
  keeps RAM/IO/flash range questions, 4K selector questions, allocation scope,
  and TBE bit-helper direction
  relates to MEMORY_MAP.md and DYNAMIC_MEMORY_FIRST_STEPS.md

HIMON_STAGES_CLASSES.md
  reconstructs the Himon parent, split Himon, Himonia, FNV tool, Himonia-F, and
  current HIMON stage ladder
  explains subsystem classes/prefixes before the detailed HIMON edge map
  depends on HISTORICAL_DOCUMENTS.md, HIMON_MAP.md, and current Himon source

SYMBOL_XREF.md
  combines REF-style routine contracts with XREF-style source edges
  adds XXREF semantic tokens for code that exists now and code still planned
  includes a hand-sized HIMON Mermaid call tree

CATALOG.md
  programmer-facing callable routine catalog
  groups routines by need rather than source order: read, write, strings, hex,
  hash, flash, vectors, and BIO recovery helpers
  keeps routine name, hash, entry/exit registers, carry flags, notes, and tags

LIFE_RCAT_MEMBER.md
  worked example for turning `SRC/TEST/apps/life.asm` into an RCAT-visible
  member without treating LIFE as operational HIMON source
  depends on GLOSSARY.md, HASH_MAP.md, HASHED_ASM.md, CATALOG.md, and
  MEMORY_MAP.md vocabulary
  records the promotion path from standalone RAM image to RBODY plus RREC
  exports, including imports, resources, NMI vector use, and FSB lifecycle

MEMORY_MAP.md
  current HIMON ROM and RAM address ownership
  records user flash, monitor code/data, fixed entries, vectors, and high-RAM workspaces
  separates the current HIMON build map from future STR8/HIMON integration

DYNAMIC_MEMORY_FIRST_STEPS.md
  conceptual W65C02 dynamic allocation guide for R-YORS
  depends on MEMORY_MAP.md for current RAM and zero-page ownership
  keeps STR8 fixed-buffer-only and marks HIMON dynamic allocation as not yet

HIMON_MAP.md
  readable map over HIMON direct edges and capability surfaces
  groups startup, dispatch, loader/flash, debug, disasm, ASM, and contract maps
  uses HIMON_EDGE_DUMP.md as raw evidence
  keeps current command meanings separate from future subforms, such as HIMON
  `M` being current modify and a future fill candidate

HIMON_EDGE_DUMP.md
  direct `JSR`/`JMP` edge dump for `HIMON/himon.asm`
  keeps raw edge sites separate from the compact SYMBOL_XREF call tree and
  readable HIMON_MAP.md diagrams
```

## Source Cross-Reference

Current generated operational source scan:

```text
Source files scanned:  27
XDEF declarations:     179
XREF declarations:     143
ROUTINE headers:       130
JSR/JMP call sites:    989
Unique direct edges:   779
```

Current HIMON/STR8 operational files:

```text
HIMON/himon.asm
HIMON/*.inc
HIMON/fnv1a-fold.asm
STR8/str8.asm
SRC/STASH/ftdi/*.asm
SRC/SESH/ftdi/*.asm
ROM/ftdi-backend-debug.asm
ROM/ftdi/*.asm
ROM/dev/*.asm
ROM/util/*.asm
```

Legacy demos, harnesses, games, ACIA/PIA, and historical monitor experiments
are kept out of generated operational maps.

## Cross-Reference Rules

- Cross-references should name the canonical home for an idea, not create a
  loop of required reading.
- A related document may summarize an idea in one or two lines, then point to
  the canonical home. Do not copy the full explanation into multiple guides.
- Back-links are allowed as navigation, but not as a prerequisite to understand
  the current section.
- Use `MODULE`/`ENDMOD` around each logical unit that should export symbols.
- `XDEF` names a symbol provided by a source module.
- `XREF` names a symbol required from another source module.
- Hardware registers and constants can stay as local `EQU`s inside a module.
- Avoid repeating the same global symbol name in multiple modules unless the
  names are intentionally unique; `wdclib` tracks symbols in a global module
  dictionary.
- `ROUTINE` headers document callable blocks and carry `[HASH:XXXXXXXX]`
  FNV-1a IDs.
- `JSR` and `JMP` call sites are useful for call maps, but indirect calls and
  jump tables need separate reasoning.
- FNV command records are runtime-discovered records, not WDC linker exports.
- Symbol ref/xref records should preserve source line, routine contract,
  classification tokens, and FNV-1a lookup bytes when available.
- Catalog entries should preserve name, hash, entry registers, exit registers,
  carry/flag contract, proof status, notes, and tags.
- Stage/class reconstruction should distinguish historical source stages from
  current HIMON product direction.
- Memory-map entries should distinguish generated current addresses from future
  STR8/HIMON placement goals.
- Dynamic allocation notes should distinguish app/session-owned heap experiments
  from monitor-owned services that require memory-map reservations.
- `make rom` rebuilds `rom.lib`; application links consume that library rather
  than duplicating shared module code.

## Known Drift

The older generated source-wide graph has been narrowed because broad scans made
harnesses and proof apps look like the current subsystem graph. Use
`HIMON_MAP.md` for the readable current map and `HIMON_EDGE_DUMP.md` for raw
HIMON direct-edge evidence.
