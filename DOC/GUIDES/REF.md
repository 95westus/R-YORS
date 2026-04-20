# R-YORS Reference

Generated from current source scan on 2026-04-13 22:06:00 -05:00.

## Library Source Files (rom.lib inputs)
- SRC/APP/STASH/LIB/dev/dev-adapter-core.asm
- SRC/APP/STASH/LIB/dev/dev-adapter-debug.asm
- SRC/APP/STASH/LIB/dev/dev-adapter-readline.asm
- SRC/APP/STASH/LIB/dev/dev-adapter-write.asm
- SRC/APP/STASH/LIB/ftdi/ftdi-backend-core.asm
- SRC/APP/STASH/LIB/ftdi/ftdi-backend-debug.asm
- SRC/APP/STASH/LIB/ftdi/ftdi-backend-editline.asm
- SRC/APP/STASH/LIB/ftdi/ftdi-backend-readline.asm
- SRC/APP/STASH/LIB/ftdi/ftdi-backend-write.asm
- SRC/APP/STASH/LIB/ftdi/ftdi-drv.asm
- SRC/APP/STASH/LIB/ftdi/ftdi-hal.asm
- SRC/APP/STASH/LIB/ftdi/ftdi-test-helpers.asm
- SRC/APP/STASH/LIB/util/util-addr.asm
- SRC/APP/STASH/LIB/util/util-char.asm
- SRC/APP/STASH/LIB/util/util-delay.asm
- SRC/APP/STASH/LIB/util/util-hex.asm
- SRC/APP/STASH/LIB/util/util-string.asm
- SRC/APP/STASH/LIB/util/util-test.asm
- SRC/APP/STASH/LIB/util/util-zp.asm

## WIP Library Files (SESH, not rom.lib inputs)
- SRC/APP/SESH/LIB/acia/acia-drv.asm
- SRC/APP/SESH/LIB/pia/pia-drv.asm
- SRC/APP/SESH/LIB/pia/pia-hal.asm

## Export/Import Summary
- Library exports (XDEF, unique): 114
- Library imports (XREF, unique): 56
- Library routine headers: 104

## Prefix Distribution (LIB ROUTINE blocks)
- COR=38, SYS=31, UTL=21, PIN=5, TST=5, BIO=4

## App Entrypoints (STASH)
- SRC/APP/STASH/cmd.asm
- SRC/APP/STASH/dump.asm
- SRC/APP/STASH/himon.asm
- SRC/APP/STASH/himonv.asm
- SRC/APP/STASH/life.asm
- SRC/APP/STASH/monitor.asm

## Most Referenced Symbols (All Consumers)
- COR_FTDI_WRITE_CHAR: used by 11 file(s); provider(s): SRC/APP/STASH/LIB/ftdi/ftdi-backend-core.asm
- COR_FTDI_WRITE_CRLF: used by 9 file(s); provider(s): SRC/APP/STASH/LIB/ftdi/ftdi-backend-core.asm
- COR_FTDI_FLUSH_RX: used by 8 file(s); provider(s): SRC/APP/STASH/LIB/ftdi/ftdi-backend-core.asm
- COR_FTDI_INIT: used by 8 file(s); provider(s): SRC/APP/STASH/LIB/ftdi/ftdi-backend-core.asm
- COR_FTDI_WRITE_CSTRING: used by 8 file(s); provider(s): SRC/APP/STASH/LIB/ftdi/ftdi-backend-write.asm
- COR_FTDI_WRITE_HEX_BYTE: used by 8 file(s); provider(s): SRC/APP/STASH/LIB/ftdi/ftdi-backend-core.asm
- SYS_WRITE_CRLF: used by 8 file(s); provider(s): SRC/APP/STASH/LIB/dev/dev-adapter-write.asm
- SYS_FLUSH_RX: used by 7 file(s); provider(s): SRC/APP/STASH/LIB/dev/dev-adapter-core.asm
- SYS_INIT: used by 7 file(s); provider(s): SRC/APP/STASH/LIB/dev/dev-adapter-core.asm
- SYS_WRITE_HEX_BYTE: used by 7 file(s); provider(s): SRC/APP/STASH/LIB/dev/dev-adapter-write.asm
- COR_FTDI_POLL_CHAR: used by 6 file(s); provider(s): SRC/APP/STASH/LIB/ftdi/ftdi-backend-core.asm
- COR_FTDI_READ_CHAR: used by 6 file(s); provider(s): SRC/APP/STASH/LIB/ftdi/ftdi-backend-core.asm
- SYS_WRITE_CHAR: used by 6 file(s); provider(s): SRC/APP/STASH/LIB/dev/dev-adapter-core.asm
- SYS_WRITE_CSTRING: used by 6 file(s); provider(s): SRC/APP/STASH/LIB/dev/dev-adapter-write.asm
- BIO_FTDI_READ_BYTE_BLOCK: used by 5 file(s); provider(s): SRC/APP/STASH/LIB/ftdi/ftdi-hal.asm
