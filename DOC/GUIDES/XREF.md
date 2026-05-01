# R-YORS Cross-Reference

This file connects the guide set to the current `ror` source tree.

## Document Cross-Reference

```text
STR8.md
  used by HASHED_ASM.md for flash commit/condense policy
  used by MAP.md for recovery/update ownership
  used by HISTORICAL_DOCUMENTS.md as the recovery-layer name

DECISIONS.md
  records settled naming, hash, STR8, ASM, ABI, local-home, and doc-shape calls
  should be checked before reopening design alternatives
  overrides looser exploratory notes unless explicitly reopened

HASH_MAP.md
  points to HASH.md for ROUTINE header IDs
  points to HASHED_ASM.md for symbol/fixup hashes
  points to Himonia-F sources for runtime FNV

HASHED_ASM.md
  depends on STR8.md for flash safety
  depends on HASH_MAP.md for hash vocabulary
  feeds FUTURE.md and TODO.md implementation direction

SYMBOL_XREF.md
  combines REF-style routine contracts with XREF-style source edges
  adds XXREF semantic tokens for code that exists now and code still planned
  includes a hand-sized Himonia-F Mermaid call tree

CATALOG.md
  programmer-facing callable routine catalog
  groups routines by need rather than source order: read, write, strings, hex,
  hash, flash, vectors, and BIO recovery helpers
  keeps routine name, hash, entry/exit registers, carry flags, notes, and tags

MEMORY_MAP.md
  current Himonia-F ROM and RAM address ownership
  records user flash, monitor code/data, ABI slots, vectors, and high-RAM workspaces
  separates the current Himonia-F build map from future STR8/HIMON ownership

HIMONIA_F_MAP.md
  readable map over Himonia-F direct edges and capability surfaces
  groups startup, dispatch, loader/flash, debug, disasm, ASM, and ABI maps
  uses HIMONIA_F_EDGE_DUMP.md as raw evidence

HIMONIA_F_EDGE_DUMP.md
  direct `JSR`/`JMP` edge dump for `SRC/TEST/apps/himon/himon.asm`
  keeps raw edge sites separate from the compact SYMBOL_XREF call tree and
  readable HIMONIA_F_MAP.md diagrams
```

## Source Cross-Reference

Current source scan:

```text
ASM files:             37
XDEF declarations:     339 total, 328 unique names
XREF declarations:     354 total, 200 unique names
ROUTINE headers:       228 total, 226 unique first names
JSR/JMP call sites:    2259 total, 450 unique targets
```

Primary Himonia/Himon files:

```text
SRC/TEST/apps/himon/himon-parent.asm
SRC/TEST/apps/himon/himonia.asm
SRC/TEST/apps/himon/fnv1a-hbstr.asm
SRC/TEST/apps/himon/himon.asm
```

Primary Himonia-F edge guide:

```text
DOC/GUIDES/HIMONIA_F_MAP.md
DOC/GUIDES/HIMONIA_F_EDGE_DUMP.md
DOC/GUIDES/MEMORY_MAP.md
```

Primary flash/recovery proving file:

```text
SRC/TEST/test-flash.asm
```

Primary app using flash command record ideas:

```text
SRC/TEST/apps/rom-append-calc.asm
```

## Cross-Reference Rules

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
- Symbol ref/xref records should preserve source line, ABI contract,
  classification tokens, and FNV-1a lookup bytes when available.
- Catalog entries should preserve name, hash, entry registers, exit registers,
  carry/flag contract, proof status, notes, and tags.
- Memory-map entries should distinguish generated current addresses from future
  STR8/HIMON placement goals.
- `make rom` rebuilds `rom.lib`; test/app links consume that library rather
  than duplicating shared module code.

## Known Drift

The older generated source-wide graph has been removed because it was noisy and
stale. Use `HIMONIA_F_MAP.md` for the readable current map and
`HIMONIA_F_EDGE_DUMP.md` for raw Himonia-F direct-edge evidence.
