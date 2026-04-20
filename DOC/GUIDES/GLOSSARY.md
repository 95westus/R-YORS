# R-YORS Glossary

Generated from current source scan on 2026-04-13 22:06:00 -05:00.

## Core Terms
- rom.lib: static library assembled from SRC/APP/STASH/LIB/**/*.asm and linked into app/test images.
- MODULE: assembler module boundary used for symbol packaging and export visibility.
- XDEF: symbol exported by a module for external link use.
- XREF: symbol imported from another module.
- ROUTINE block: structured comment header used for docs and traceability.

## Layer Prefix Families (Observed)
- PIN_*: low-level pin/driver routines at hardware/register boundaries.
- BIO_*: HAL routines above PIN_*.
- COR_*: backend/core integration routines.
- SYS_*: adapter/system-facing wrappers for app-level use.
- UTL_*: shared utility routines.
- TST_*: test helper routines in library space.
- TEST_*: test app routines in SRC/APP/TEST.
- CMD_*, MON_*, LIFE_*, HIMV_*: app-level command/monitor/application routines.

## Lane Terms
- STASH: top-shelf app lane (SRC/APP/STASH).
- TEST: validation lane (SRC/APP/TEST).
- SESH: session WIP lane (SRC/APP/SESH).
- Top-shelf libs: SRC/APP/STASH/LIB/{dev,ftdi,util}.
- WIP libs: SRC/APP/SESH/LIB/{acia,pia}.
