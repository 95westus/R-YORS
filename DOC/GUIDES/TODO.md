# R-YORS TODO

## Near Term

- Prove the RAM-resident STR8 S19 command text for automatic backup, Bank 0
  enrollment, restore, reset, and HIMON handoff operations.
- Choose the first 4K STR8 copy buffer address/range and then update
  `MEMORY_MAP.md`.
- Define `FLSH_` suffix conventions for register-carried arguments, including
  `_A` and `_AX`.
- Define the first STR8 V0 protected-window start inside bank 3's `$F000-$FFFF`
  top erase sector: `$FC00`, `$FA00`, `$F800`, `$F600`, `$F400`, `$F200`, or
  `$F000`.
- Define the top-sector partial-update transaction for bytes below STR8:
  read/stage/erase/full-sector-write/verify.
- Define STR8 V0's image read-back/check flow, including which bytes ordinary
  restore writes, which selected STR8 protected-window bytes it skips, how STR8
  install/update verifies those bytes separately, and any fixed image marker.
- Define the first catalog record header that can represent hash, kind, bank,
  address, flags, and optional name text.
- Define the first explicit STR8 import labels HIMON will use after the
  simulation stub grows into resident recovery code.
- Revise HIMON command strings and range syntax under the command safety
  mandate: destructive commands require 4+ characters. Candidate bulk commands
  are `COPY start end|+count dest`, `FILL start end|+count bb`, and later
  `MOVE start end|+count dest`; flash/bank mutation stays behind full-word
  confirmed commands.
- Revise the shared range parser so `start +count` means byte count, while a
  1- or 2-hex-digit inclusive `end` inherits the start high byte when safe.
- Add `D` continuation state: bare `D` repeats the previous dump length from
  the byte after the previous dump, e.g. `D 3000 FF` then `D` displays
  `$3100-$31FF`.
- Define and implement HIMON memory search after the range parser settles:
  target `S addr end|+count b0 [b1 ...]` for hex-byte search,
  `S addr end|+count 'TEXT` for text search, and the simple mixed tail
  `S addr end|+count b0 [b1 ...] 'TEXT`. Treat apostrophe text as a final V0
  tail, not a quoted atom that resumes parsing. Print hits as D-style context
  rows: exact hit address, aligned row address, and `*` when the match crosses
  a 16-byte display row. Current step/next moves to `N` or `NEXT`.
- Sketch the first W65C02-small `pack_lo_5` decoder and the rule for falling
  back to raw text when compression loses.
- Define the exact `FIX` record bytes for RAM staging and direct flash patching.
- Add a current guide generator only after the hand-maintained map stabilizes.

## Very Possible

- Add `TBE`, The Bit Engine, as a small W65C02S convenience/helper routine
  family for setting, resetting, testing, and branching on bits. Keep RAM
  helpers based on `TSB`/`TRB`/`SMB`/`RMB`/`BBS`/`BBR` separate from flash-safe
  helpers, where clearing `1 -> 0` bits may be the only legal commit action
  without erase.

## Source Follow-Ups

- Re-run routine hash comments after any routine-header reshuffle.
- Check unresolved `XREF` names before using source cross-reference counts as a
  release-quality metric.
- Keep `SRC/TEST/apps/himon/himon.asm` as the current reference point for
  hash-driven command dispatch.
