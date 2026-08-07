# Archived ASM Samples

This directory preserves superseded implementations, smoke programs, negative
fixtures, proof-only sources, and completed board-test cards. They remain
available because the hardware transcripts and test plans refer to the exact
sources that produced their evidence.

Files here are not the default operator path. Promote a source back to the
parent `SAMPLES` directory only when it again becomes a maintained board tool,
and update its generator or build target at the same time.

Historical hardware transcripts may show the source's former top-level path.
Those transcripts are intentionally left intact.

## Current-Board Destructive Archives

- `str8n-topwrite-transient-3000.a` embeds the legacy replacement top sector
  and overwrites the installed V1 directory.
- `str8n-v1-topwrite-transient-3000.a` is the historical one-time V1 migration
  writer; it replaces the live directory with embedded empty bytes.
- `bank3-erase-8000-bfff-transient-3000.a` erases the installed Bank-3 ASM
  sectors `$8000-$BFFF`.

Do not use these on the accepted current board state. The maintained V1 update
path is `../str8n-v1-refresh-transient-3000.a`.

## Split-V1 `$F003` Compatibility Archives

The following sources were maintained before the split worker made `$F003` a
jump-only mode-`$08` doorway. On unguarded split images `1900/2033`, a legacy
mode request can consume a stale jump target. Image `2135` rejects it safely,
but the old operation still cannot run. Each source now carries the warning at
its top so copying it away from this directory does not lose the reason for
archival.

Read-only mode-`$06` history:

- `str8-bank-crc-all-3000.a` and `str8-jump-inventory-3000.a`; maintained
  `$F010/$0203` replacements exist in the parent directory.
- `flash-bank-read-ap-2000.a` and `flash-bank-dump-ap-2000.a`; maintained
  `$F010/$0203` bodies exist in the parent directory. Bank-0 AP loading still
  waits for the HIMON banked-AP staging cutover.

Destructive mode-`$05/$06` history:

- `str8-bank-copy-2000.a` and `flash-erase-bank-ap-2000.a`; current copy and
  erase use the carried-worker `../str8-bank-maint-2000.a` utility.
- `bank0ap-put-transient-2000.a`, `bank2put-8000-transient-3000.a`,
  `bankput-transient-3000.a`, and `flash-bank-erase-write-ap-2000.a`; these
  are retired in favor of the supported carried-worker bank-maintenance path.

`bank0-ap-entry-points.md` moved with this surface. Its addresses remain
hardware provenance, not current split-V1 instructions.
