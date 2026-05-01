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
