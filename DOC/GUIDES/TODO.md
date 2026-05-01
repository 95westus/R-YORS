# R-YORS TODO

## Near Term

- Prove whether STR8 V0 fits in the preferred `$F800-$FFFF` protected anchor
  with code/data through `$FFF9`; fall back to `$F000-$FFFF` only if the first
  recovery/update authority needs it.
- Define the first catalog record header that can represent hash, kind, bank,
  address, flags, and optional name text.
- Decide whether `$FACE`, `$FADE`, `$FEED`, and `$F00D` are direct stubs,
  trampolines, or STR8/Himon service table entries.
- Sketch the first W65C02-small `pack_lo_5` decoder and the rule for falling
  back to raw text when compression loses.
- Define the exact `FIX` record bytes for RAM staging and direct flash patching.
- Add a current guide generator only after the hand-maintained map stabilizes.

## Source Follow-Ups

- Re-run routine hash comments after any routine-header reshuffle.
- Check unresolved `XREF` names before using source cross-reference counts as a
  release-quality metric.
- Keep `SRC/TEST/apps/himon/himon.asm` as the current reference point for
  hash-driven command dispatch.
