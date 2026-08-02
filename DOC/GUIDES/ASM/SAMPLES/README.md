# Maintained ASM Samples

This directory is the current board-facing ASM source surface. Keep maintained
operator tools here. Historical implementations, smoke programs, negative
fixtures, proof-only sources, and completed board-test cards belong in
[`OLD`](OLD/README.md).

## AP Build, Install, And Reporting

- `asm-session-report-ap-2000.a` - current movable, Bank-0-storable ASM
  session reporter.
- `bank0ap-put-transient-2000.a` - current direct-run and resident Bank-0 AP
  installer.
- `bank0-ap-entry-points.md` - current Bank-0 package/load-address ledger and
  resident-installer workflow.
- `bank2put-8000-transient-3000.a` - fixed Bank-2 `$8000` AP installer.
- `bankput-transient-3000.a` - configurable Bank 0-2 AP installer.

## Flash Tools

- `bank3-erase-8000-bfff-transient-3000.a` - Bank-3 low-flash erase tool.
- `flash-bank-dump-ap-2000.a` - fixed-load, read-only sector dump AP.
- `flash-bank-read-ap-2000.a` - movable sector-read and CRC AP.
- `flash-bank-erase-write-ap-2000.a` - movable sector erase/write/verify AP.
- `flash-erase-bank-ap-2000.a` - fixed-load interactive bank erase AP.

## STR8 Tools

- `str8-bank-copy-2000.a` - maintained full-bank copy tool.
- `str8-bank-crc-all-3000.a` - read-only all-bank CRC inventory.
- `str8-bank-maint-2000.a` - maintained bank copy/erase utility.
- `str8-jump-inventory-3000.a` - read-only pre-handoff bank inventory.
- `topwr-transient-3000.a` - maintained staged top-sector shop tool.
- `str8n-topwrite-transient-3000.a` - generated current top-sector writer.

Generated maintained sources must continue to target this directory. Generated
legacy reporter forms target `OLD` so regeneration does not repopulate the
active sample surface.
