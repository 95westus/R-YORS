# R-YORS Future Notes

## Architecture Direction

- Keep Himonia-F hash dispatch small and inspectable.
- Make STR8 the flash recovery/update boundary instead of scattering flash
  mutation policy across normal monitor commands.
- Treat bank 3 `$F000-$FFFF` as the physical top erase sector, but protect only
  the selected STR8 protected window (`$FC00`, `$FA00`, `$F800`, `$F600`,
  `$F400`, `$F200`, or `$F000` through `$FFFF`) from ordinary writes.
- Flash protected-window bytes through a separate install/update path. Reuse
  lower bytes in the same 4K sector when possible. Both STR8 updates and lower
  top-sector changes must stage the full sector, erase, rewrite the full staged
  sector, and verify.
- Preserve the layer ladder (`PIN -> BIO -> COR -> SYS -> APP`) where it still
  fits, with `MEM` as a future core memory-ownership layer beneath public
  `SYS` calls.
- Keep CSTR, HBSTR, and packed command-text forms explicit at API boundaries.
- Treat future dynamic memory as `MEM_*`: hardware-constrained RAM and
  zero-page ownership policy, not `PIN_*`/`BIO_*` device access.
- Keep STR8 fixed-buffer-only. HIMON can adopt `MEM_*` later, starting with
  app/session-owned bump allocation and pools before any general free-list heap.

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
- Treat short IDs/indexes as optional post-resolution handles. Hashes remain
  the catalog discovery key; future RIDX tables can speed hot paths later.
- Treat versioned catalog lookup as candidate selection, not first-match:
  exact ABI version, minimum-compatible version, and latest-compatible lookup
  are different policies. HIMON and ASM can use compatible latest records when
  the caller allows it. STR8 V0 does not use FNV/catalog lookup; future STR8 may
  own catalogs after the image-recovery path is stable.
- Keep PACK5/3x5 as a candidate for compact 3-letter mnemonic tables, because
  three 5-bit characters fit in two bytes.

## Flash Direction

- Keep bank 3 cleaner for boot/current-monitor/catalog/trampoline material. The
  physical `$F000-$FFFF` sector contains STR8 and vectors, but only the chosen
  STR8 window is reserved from ordinary writes.
- For the first STR8 recovery model, restore uses a whole 32K bank 0, 1, or 2
  image as the source for bank 3, writes ordinary bank 3 image bytes, and skips
  the selected STR8 protected window unless explicit STR8 install/update is
  requested. Backup rotates bank 1 to bank 0, bank 2 to bank 1, and bank 3 to
  bank 2.
- Let R-YORS define scan, verify, write, commit, and later condense policy,
  with shared flash primitives where that makes sense. HIMON/maintenance owns
  catalog condense first; future STR8 may take catalog ownership later.
- Treat future flash GC as append/invalidate/reclaim instead of in-place edits:
  mark records or sections stale, prepare a compacted sector image in RAM,
  relink copied records when needed, erase the old 4K sector, then write and
  verify the prepared image.
- Explore LOC, "link on copy", for flash compaction: copied catalog records or
  modules are relinked to their new addresses before the rewritten sector
  becomes live.
- Store compressed command text only when it is smaller than raw text after
  flags/headers.
- Use byte-aligned RLE as the first binary `RBODY` compression direction, with
  special run forms for `$00`, `$20`, and `$FF` under consideration. Do not
  commit opcode ranges until the decoder shape is proven small.

## Documentation Direction

- Keep `DOC/GUIDES/INDEX.md`, `TOC.md`, `MAP.md`, `REF.md`, `XREF.md`,
  `BIB.md`, and `HASH_MAP.md` consistent as the stable guide spine.
- Keep `HIMON_MAP.md` plus `HIMON_EDGE_DUMP.md` as the current HIMON
  map/evidence pair.
- Add a future generator only if the guide set starts drifting again.
