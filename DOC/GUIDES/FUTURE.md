# R-YORS Future Notes

## Architecture Direction

- Keep Himonia-F hash dispatch small and inspectable.
- Make STR8 the flash recovery/update boundary instead of scattering flash
  mutation policy across normal monitor commands.
- Preserve the layer ladder (`PIN -> BIO -> COR -> SYS -> APP`) where it still
  fits, but allow Himonia-F command records to become their own catalog surface.
- Keep CSTR, HBSTR, and packed command-text forms explicit at API boundaries.

## Long-Term RPG II Direction

- RPG II is the long-term language goal, not a near-term monitor feature.
- R-YORS should still be shaped around that future while it grows: records,
  catalogs, fixed entry points, stable callable routines, flash-resident
  programs, and an onboard assembly/link path should all make a later RPG II
  environment feel native instead of grafted on.
- The target is true RPG II lineage and behavior, guided by original IBM
  documentation, not a modern language wearing an RPG name.
- Near-term work should keep producing useful standalone runtime pieces even
  before an RPG II compiler exists.
- Avoid adding RPG-specific complexity to STR8 V0 or the current Himonia-F
  monitor unless that same work also improves recovery, cataloging, assembly,
  loading, or routine reuse.

## Board Onboarding Direction

- Support a WDCMONv2-to-R-YORS installation bridge for boards that already boot
  the current WDC monitor.
- This is mainly for a new WDC board owner, not for a board that already has
  Himonia-F/R-YORS flashed and running.
- The bridge should use the WDCMONv2 style of loading and starting code because
  that is what a fresh board already has. After it starts, the bridge converts
  the flash layout to R-YORS/STR8/HIMON.
- The bridge should use the same kind of simple program structure that BSO2
  used around the WDC monitor style: a code region, a visible `WDC`-style
  signature, fixed reset/NMI/IRQ jump trampolines, a documented cold-start
  routine, and a tiny board I/O/FTDI API linked at a known load address.
- That structure is the style to preserve, not literal BSO2 code. The new
  bridge's job is to identify the board, verify assumptions, and reflash the
  board into STR8/HIMON.
- Preserve useful WDC-style ideas such as a board/firmware signature block and
  fixed jump-vector/service entries. Those make the bridge self-identifying and
  give the installer stable places to call without needing a full symbolic
  linker on the board.
- The goal is field installation without an external ROM/flash programmer:
  start from WDCMONv2, load the bridge, verify the board, flash STR8/HIMON, and
  reboot into R-YORS.
- WDCMONv2 is the entry ramp, not the final runtime owner. After installation,
  R-YORS boots through STR8 and normal operation belongs to HIMON.
- Author preference: when available, the cleanest installation path is still to
  program the flash/ROM directly with a T48 programmer. The WDCMONv2 bridge is
  for new users who have the stock board and want to reach R-YORS without first
  adopting extra programmer hardware or WDC's full toolchain.
- The migration bridge is a future option, not a committed V0 feature. It may
  never be implemented, or it may ship with more or fewer features depending on
  what STR8, the board, and new-user installation actually require.
- Later, STR8 may offer to preserve the original WDCMONv2 image, bridge image,
  or provenance notes before conversion. That is a future convenience, not a
  requirement for the first installer.

## Assembler Direction

- Treat `A [addr] [label:] MMM [operand] .` as the one-shot assembler shape.
- Support forward labels in v1 through fixup records.
- Prefer RAM staging for flash targets when source may fail or generate fixups.
- Export only after bytes and fixups are verified.
- Keep `DEF`, `SYM`, `FIX`, `RESOLVE`, `FORGET`, and `EXPORT` in the design
  surface even if early UI hides some of them.

## Flash Direction

- Keep bank 3 cleaner for boot/current-monitor/catalog/trampoline material.
- Prefer banks 0-2 for growth packs, expanded command text, onboard exports,
  and stale records.
- Let R-YORS define scan, verify, write, commit, and later condense policy,
  with STR8/HIMON sharing code where that makes sense.
- Treat future flash GC as append/invalidate/reclaim instead of in-place edits:
  mark records or sections stale, prepare a compacted sector image in RAM,
  relink copied records when needed, erase the old 4K sector, then write and
  verify the prepared image.
- Explore LOC, "link on copy", for flash compaction: copied catalog records or
  modules are relinked to their new addresses before the rewritten sector
  becomes live.
- Store compressed command text only when it is smaller than raw text after
  flags/headers.

## Documentation Direction

- Keep `DOC/GUIDES/INDEX.md`, `TOC.md`, `MAP.md`, `REF.md`, `XREF.md`,
  `BIB.md`, and `HASH_MAP.md` consistent as the stable guide spine.
- Keep `HIMONIA_F_MAP.md` plus `HIMONIA_F_EDGE_DUMP.md` as the current
  Himonia-F map/evidence pair.
- Add a future generator only if the guide set starts drifting again.
