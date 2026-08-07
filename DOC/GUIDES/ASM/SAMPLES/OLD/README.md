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
