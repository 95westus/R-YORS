# R-YORS Cross-Reference

This file connects the guide set to the current `ror` source tree.

Cross-reference wording follows [GLOSSARY.md](../GLOSSARY.md), especially for
THE, hash terms, Record/RREC, contract, source aliases, and
formed/sealed/buried/gone lifecycle terms.

## Document Cross-Reference

```text
OPERATORS_GUIDE.md
  canonical board-facing guide for current R-YORS, STR8, and HIMON operation
  absorbs the old RTFM-R-YORS.md, RTFM-str8.md, and RTFM-himon.md details
  points to HARDWARE_TEST_LOG.md and HIMON_DEBUG_TESTING.md for proof process

TECHNICAL_GUIDE.md
  canonical architecture guide for product roles, source layout, build
  artifacts, memory, flash, IVI, STR8, HIMON, and payload contracts
  summarizes STR8.md, MEMORY_MAP.md, PRODUCT_BOUNDARIES.md, HIMON_MAP.md, and
  DECISIONS.md without carrying the story lane

STR8.md
  used by HASHED_ASM.md for flash commit/condense policy
  used by MAP.md for recovery/update ownership
  used by HISTORICAL_DOCUMENTS.md as the recovery-layer name
  uses STR8_EDGE_DUMP.md as raw direct-edge evidence

STR8_WORK_PROCESS.md
  records the current process for returning to STR8 work
  starts with a V0 acceptance pass before new update commands or self-update
  relates to OPERATORS_GUIDE.md, TECHNICAL_GUIDE.md, STR8.md,
  STR8_DECISION_REFERENCE.md, STR8_FLASH_UPDATE_PROPOSAL.md, BRINGUP.md,
  TODO.md, and HARDWARE_TEST_LOG.md

DECISIONS.md
  records settled naming, hash, STR8, ASM, contract, local-home, and doc-shape calls
  should be checked before reopening design alternatives
  overrides looser exploratory notes unless explicitly reopened

DOC_FLASH.md
  records short alerts when doc shape, edicts, canonical homes, QCC pages, or
  remembered artifact names change enough to make yesterday's binder stale
  points to DECISIONS.md for settled edict changes and QCC_*.md pages for
  unsettled design movement

PROVENANCE.md
  records the tag set for idea origin and outside help
  separates Walter-originated project ideas, hardware proof, AI/Codex-assisted
  shaping, outside prior art, generated/source-derived evidence, and unknown
  origin without turning the docs into legal boilerplate

QCC.md
  defines Questions, Comments, Concerns as the working-note style for active
  design questions
  indexes QCC_HASH, QCC_FLASH, QCC_ASM, QCC_CATALOG_LINKING, QCC_STR8, and
  QCC_MEMORY
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
  relates to HASHED_ASM.md, QCC_CATALOG_LINKING.md, and QCC_FLASH.md

QCC_CATALOG_LINKING.md
  keeps the bootstrap question for catalog-linked bodies and catalog-aware ASM:
  what creates the first records before catalog joins are strong enough to own
  themselves
  names LIFE-2000 static-link support code as useful payload baggage, not the
  final catalog contract
  relates to HREC_JOIN_PROOF.md, LIFE_RCAT_MEMBER.md, HASHED_ASM.md,
  CATALOG.md, and QCC_ASM.md

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
  worked example for turning `SRC/APPS/life.asm` into an RCAT-visible
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

STR8_EDGE_DUMP.md
  direct `JSR`/`JMP` edge dump for `STR8/str8.asm`
  keeps raw recovery-monitor edge sites separate from STR8.md's readable
  product and proof narrative

HARDWARE_TEST_LOG.md
  records board transcript validation after tests are run
  references BRINGUP.md, HIMON_DEBUG_TESTING.md, HREC_JOIN_PROOF.md, and
  HIMON_SEARCH_IMPLEMENTATION_GUIDE.md for the test intent behind each pass

OIL_710_TEST_PLAN.md
  records the `.710` OIL release test rail for Online Interactive Linker board
  proof
  depends on ASM sample AP packages, current HIMON/STR8 maps, and
  HARDWARE_TEST_LOG.md append-only transcript evidence
  keeps size recommendations for STR8, HIMON, ASM, and R-YORS namespace moves
  separate from the release board transcript

HISTORICAL_CODE_MIGRATION_PLAN.md
  records the active-source boundary and the migration path for retired
  samples, tests, proofs, demo apps, helper scripts, and one-off data
  uses SRC/ARCHIVE/ as the historical source home
  keeps current STR8-N, HIMON V, and ASM-F2 paths in place until a deliberate
  replacement exists
  relates to TECHNICAL_GUIDE.md, MAP.md, REF.md, TODO.md,
  HISTORICAL_DOCUMENTS.md, and SRC/ARCHIVE/README.md
```

## Source Cross-Reference

Current generated operational source scan:

```text
Source files scanned:  30
XDEF declarations:     222
XREF declarations:     152
ROUTINE headers:       144
JSR/JMP call sites:    1363
Unique direct edges:   1103
```

Current HIMON/STR8 operational files:

```text
HIMON/himon.asm
HIMON/*.inc
HIMON/fnv1a-fold.asm
STR8/str8.asm
SRC/LIB/ftdi/*.asm
SRC/LIB/ftdi/*.asm
ROM/ftdi-backend-debug.asm
ROM/ftdi/*.asm
ROM/dev/*.asm
ROM/util/*.asm
```

Legacy demos, harnesses, games, ACIA/PIA, and historical monitor experiments
are kept out of generated operational maps.

The historical code migration plan narrows this boundary further: active
source lanes should contain only code/data used to create current onboard
R-YORS images or board-ingested data. Retired code/data belongs under
`SRC/ARCHIVE/`.

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
