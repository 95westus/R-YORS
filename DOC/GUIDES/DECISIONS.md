# R-YORS Decisions

This file records settled calls. Use it to avoid reopening decisions by
accident. If a decision needs to change, change it here first, then update the
dependent docs.

## Use This File

- Check this file before proposing alternatives to naming, hash policy,
  doc structure, STR8/HIMON ownership, or assembler syntax.
- Do not treat an open design note in another guide as stronger than a decision
  here.
- Mark a decision as `reopened` only when the user explicitly asks to revisit
  it.

## Naming And Roles

```text
R-YORS boots through STR8.
STR8 keeps recovery/update safe.
STR8 hands normal operation to HIMON.
HIMON provides the monitor, command dispatch, assembler, catalog lookup,
and debug tools.
```

- `ror` is the working repo/copy.
- `R-YORS` is the overall project/system name.
- `STR8` means Subroutine To Return. It is pronounced `S-T-R-8`, can also be
  read as `Straight 8`, and deliberately echoes `RTS` / Return from Subroutine.
- Himonia-F is the current implementation path that will become `HIMON`.
- `HIMON` is the final monitor/debug/catalog/assembler environment name.
- Do not treat Himonia-F and HIMON as permanently separate products.

## STR8 Ownership

- Future STR8 owns the hardware vector bytes at `$FFFA-$FFFF`.
- V0 HIMON controls IRQ/vector behavior. STR8 IRQ/vector ownership is a future
  direction, not the first recovery test.
- STR8 lives in bank 3's physical top erase sector (`$F000-$FFFF`), but the
  policy-protected STR8 window starts at the highest fitting boundary:
  `$FC00`, `$FA00`, `$F800`, `$F600`, `$F400`, `$F200`, or `$F000`.
- Protected-window bytes are flashed through a separate STR8 install/update path.
  That path still stages the full top sector and preserves non-target bytes.
  Non-STR8 bytes in the same 4K sector may be used, but changing them requires
  the same read, stage, erase, full-sector-write, and verify transaction.
- V0 STR8 uses whole 32K ROM bank images (`$8000-$FFFF`) as recovery sources.
  Restore writes ordinary bank 3 image bytes from selected bank 0, 1, or 2 and
  skips the selected STR8 protected window unless explicit STR8 install/update
  is requested.
- Bank 3 is the live boot image. Bank 2 is the newest backup. Bank 1 is the
  previous backup. Bank 0 starts as the platinum R-YORS/HIMON/STR8 image and is
  also the oldest slot in the current backup rotation.
- A backup request copies bank 1 to bank 0, bank 2 to bank 1, and bank 3 to
  bank 2.
- STR8 V0 is W65C02-specific. NMOS 6502 portability is not a V0 goal.
- Minimal recovery is a small load/verify/flash/identity surface, not full
  HIMON.
- STR8 should prefer `BIO_*` helpers for reusable low-level I/O. If a needed
  reusable helper does not exist in `BIO_*`, STR8 may call `PIN_*` directly for
  the first bring-up path, then promote the helper into `BIO_*` when it becomes
  a shared recovery primitive.
- STR8 should avoid `COR_*`/`SYS_*` as hot-path dependencies unless the entry is
  intentionally tiny, stable, and recovery-safe. `SYS_*` remains the public
  monitor/application layer, not the recovery anchor's default substrate.

## Stack And Trap Policy

- Himonia-F/HIMON owns the hardware stack on monitor entry.
- NMI, BRK, IRQ, reset, and recovery paths must assume monitor ownership of the
  real 6502 stack.
- Userland stack behavior belongs behind explicit routines, software stacks,
  conventions, or per-app reservations, not casual ownership of the hardware
  stack.
- Resume is explicit: rebuild context and `RTI`; do not imply stale automatic
  continuation.

## Dynamic Memory Layer

- If HIMON eventually uses dynamic memory, allocation belongs behind a `MEM_*`
  memory-management layer.
- `MEM_*` owns RAM range policy, zero-page pointer lanes, bump allocation,
  mark/release allocation, fixed pools, and any later free-list heap.
- `MEM_*` is hardware-constrained because it touches raw W65C02 RAM and zero
  page, but it is not `PIN_*`/`BIO_*` hardware access.
- STR8 should not depend on general dynamic memory. STR8 remains fixed-buffer
  and fixed-workspace oriented.
- Public monitor or app-facing allocation calls should be `SYS_*` wrappers over
  `MEM_*`, not direct hidden heap calls from unrelated monitor code.

## Hash And Catalog Policy

- FNV-1a is the one and only runtime/catalog/symbol hash.
- FNV-1a belongs to HIMON, catalog, assembler, and docs/build tooling today.
- STR8 V0 does not use FNV: not for verification, image selection, version
  selection, command dispatch, catalog lookup, or recovery decisions.
- Future STR8 may own catalogs and use FNV after the V0 image-recovery path
  is stable.
- Do not propose per-record hash algorithm tags.
- Routine header `[HASH:XXXXXXXX]` values are also 32-bit FNV-1a. The old
  16-bit routine comment ID path is retired.
- `hash0..3` stores FNV-1a low byte through high byte.
- Words and longs are little-endian: low byte first.
- Current Himonia-F proving record shape is:

```text
'F','N',('V'|$80),hash0,hash1,hash2,hash3,kind,entry...
```

- Future compact signatures identify record layout/classification, not a hash
  algorithm.
- One thing may have multiple classification flags; use bit flags/tokens rather
  than forcing one exclusive kind when that loses truth.
- Command text is for discoverability, collision confirmation, and future
  tooling. It is not required for basic FNV lookup.
- Text compression must be optional. If compressed text is not smaller, store
  raw text or omit text.

## ABI Slots

- `$F00D` is the current write-byte ABI slot.
- `$FEED` is the current read-byte ABI slot.
- `$FADE` is the current exit-to-monitor ABI slot.
- `$FACE` is desired as board/version/identity output.
- Stable ABI slots should behave like trampolines or service entries so the
  implementation can move.

## STR8 Imports And Onboard Resolution

- Host-built Himonia-F/HIMON images should import resident STR8 `BIO_*`
  services from an explicit STR8 API/import file or service table. That keeps
  the release reproducible and prevents the linker from pulling a second copy
  of `BIO_*` out of `rom.lib`.
- `# label` is a HIMON command. It may eventually resolve HIMON catalog entries
  that point at fixed STR8 service-table entries, but STR8 V0 does not perform
  catalog lookup.
- RAM targets can patch resolved addresses directly. Flash targets must either
  stage in RAM before the first write or restrict patching to legal flash
  1-to-0 transitions.

## Hashed ASM Direction

- Preferred command shape:

```text
A [addr] [label:] MMM [operand] .
```

- Address comes before optional label.
- ASM hashes canonical names and tokens, not raw numeric addresses, for
  resolution. Store exact addresses, banks, patch sites, and origins as fields.
  Address-containing record hashes are proof/check metadata only, not emitted
  operand values.
- Labels require `:`.
- Labels cannot be mnemonic names; mnemonics cannot be labels.
- Local ASM labels use dot syntax: `.` alone ends a one-shot statement,
  `.NAME:` defines a local label, and `.NAME` uses a local label. No v1
  dot-directive aliases. Local labels are scoped under the current nonlocal
  label and cannot be exported.
- Minimal v1 ASM directives are IBM-ish: `DC`, `DS`, and `EQU`. Compatibility
  aliases such as `DB` may later be typed directive-alias records that resolve
  by hash to a real directive handler, but they are not part of v1.
- V1 must support forward references through fixups. A forward-reference ban is
  rejected.
- A fixup is a hash lookup plus patch-site record, not magic. It must preserve
  enough information to patch the correct byte(s) later.
- Flash destinations may use byte patching only where flash 1-to-0 write rules
  allow it. RAM destinations can patch freely.
- Onboard assembly should tolerate flash clutter at first; later HIMON or
  maintenance condense can reclaim dead or superseded records.

## Local Source Homes

- MS BASIC, `.BAS` programs, fig-Forth, WDCMONv2, and s3x live under `LOCAL/`.
- `LOCAL/` is intentionally ignored.
- Provenance belongs in local `PROVENANCE.txt` files: timestamps, sizes,
  mtimes, paths, hashes, and notes; no source-content leakage into tracked docs.
- Builds may consume ignored local source/generated files when present.

## Documentation Shape

- `INDEX.md` answers: what exists?
- `TOC.md` answers: what order should I read it in?
- `MAP.md` answers: how do docs and systems relate?
- `REF.md` is the quick operational reference.
- `XREF.md` is wiring: docs, source, symbols, module/export rules.
- `SYMBOL_XREF.md` is symbol/routine cards, ABI contracts, hashes, and tags.
- `GLOSSARY.md` defines vocabulary only.
- `BIB.md` records source corpus/provenance only.
- `HIMON_MAP.md` is the readable HIMON edge/capability map.
- `HIMON_EDGE_DUMP.md` is the raw direct-edge evidence.

## Historical Spine

```text
WDCMON/WDC monitor base
  -> BSO2 board monitor
  -> R-YORS routine layers
  -> Himon/Himonia compact monitors
  -> Himonia-F hash-dispatched monitor
  -> planned HIMON behind STR8
```

- BSO2 proves the big board-monitor feature set.
- R-YORS splits that into reusable routines/layers.
- Himonia-F is the current compact, hash-driven monitor path toward HIMON.
