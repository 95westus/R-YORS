# R-YORS Glossary

## Project Terms

- HIMON: final monitor/debug environment name that Himonia-F will become.
- Himonia-F: current FNV-driven implementation path toward HIMON.
- STR8: Straight 8 recovery/update monitor for protected flash mutation.
- Straight 8: expanded human name for `STR8`; clean, known-good 8-bit path.
- R-YORS: the broader repo/project context around routines on routines.

## Source Terms

- `MODULE` / `ENDMOD`: WDC assembler module boundary.
- `XDEF`: symbol exported by a module.
- `XREF`: symbol imported from another module.
- `ROUTINE` block: structured routine comment header with optional
  `[HASH:XXXXXXXX]`.
- `rom.lib`: linked library artifact produced by the source build.
- REF: a symbol's contract card: name, kind, ABI, hash, source, and notes.
- XREF: where a symbol is defined, imported, called, or exported.
- XXREF: semantic classification tags that apply even before code exists.

## Lane Terms

- `SRC/STASH`: stable or promoted code lane.
- `SRC/TEST`: active build/test lane.
- `SRC/SESH`: session/WIP lane.
- `SRC/BUILD`: generated build output.
- `SRC/tools`: host-side scripts for build and generated artifacts.

## Layer Prefix Families

- `PIN_*`: low-level pin/driver routines at hardware/register boundaries.
- `BIO_*`: HAL routines above `PIN_*`.
- `MEM_*`: memory ownership/allocation routines for RAM ranges, zero-page
  lanes, heaps, marks, and pools. Hardware-constrained, but not device access.
- `COR_*`: backend/core integration routines.
- `SYS_*`: adapter/system-facing wrappers for app-level use.
- `UTL_*`: shared utility routines.
- `TST_*`: test helper routines.
- `CMD_*`, `CMDP_*`, `MON_*`, `HIM_*`: monitor/command parser routines.

## Hash Terms

- HASH: 32-bit FNV-1a routine/header/catalog ID, formatted
  `[HASH:XXXXXXXX]`.
- FNV-1a: the single runtime/catalog symbol hash used by Himonia-F/HIMON.
- HBSTR: high-bit-terminated string; final byte has bit 7 set.
- C_STR: compact semantic token for NUL-terminated string routines/records.
- symbol hash: assembler/catalog lookup key for labels, routines, and commands.
- hash collision: two names produce the same hash; name text must prove identity.
- hash map: the design map of where hashes are used and what each hash means.
- RCAT: runtime catalog dataset; may hold records, string pools, indexes, and
  links to runtime bodies spread across RAM or flash.
- RREC: runtime record; one typed catalog entry for a command, routine, symbol,
  data item, module, inline value, or similar runtime thing.
- RBODY: runtime body; the code, data, string, packet, module image, or payload
  described by one or more runtime records.
- RBODY compression: storage codec for runtime body payloads; first direction
  is byte-aligned RLE with raw storage as fallback.
- RFMT: runtime format; record/catalog layout version.
- RBLK: runtime block; physical flash/RAM block containing records, bodies, or
  both.
- RIDX: runtime index; optional accelerator that maps resolved records to short
  local handles or speeds catalog lookup.
- RSTR: runtime string pool; shared/proof/display text storage.
- RFIX: runtime fixup; unresolved patch/reference site.
- RLNK: runtime link; reference from one runtime record/body to another.
- RBND: runtime bind; process of resolving links/fixups through an RCAT.
- RRES: runtime resolve; lookup operation by hash/name/type.
- catalog linking: R-YORS dynamic linking path where assembler imports,
  exports, and fixups resolve through typed hash catalog records.
- hash-linked module: loadable or flash-resident body whose public commands,
  routines, data, or symbols are exposed through catalog records.

## Flash Terms

- catalog record: flash/RAM metadata that maps hash/name to value, kind, bank,
  flags, and optional name text.
- fixup record: pending patch site for a symbol not known when an instruction is
  emitted.
- word: 16-bit little-endian value, stored low byte then high byte.
- long: 32-bit little-endian value, stored least significant byte first.
- commit byte: final marker written after a record/body is verified.
- condense: copy live records, erase stale flash, and rewrite compacted state.
- bank 3: preferred cleaner boot/current-monitor/catalog bank.
- banks 0-2: preferred growth banks for packs, text, exports, and stale records.
