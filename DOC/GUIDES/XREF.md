# R-YORS Cross-Reference

Generated from current source scan on 2026-04-13 22:06:00 -05:00.

## App/Test to Prefix Usage by File
- SRC/APP/STASH/cmd.asm: COR=6, SYS=3, UTL=1
- SRC/APP/STASH/dump.asm: COR=6, UTL=2
- SRC/APP/STASH/himon.asm: SYS=9
- SRC/APP/STASH/himonv.asm: SYS=9
- SRC/APP/STASH/life.asm: SYS=8
- SRC/APP/STASH/monitor.asm: SYS=10, UTL=1
- SRC/APP/TEST/lowlevel-test.asm: PIN=5, BIO=4, COR=2, UTL=1
- SRC/APP/TEST/test.asm: PIN=5, BIO=4, COR=2, UTL=1
- SRC/APP/TEST/test-cor-iso.asm: COR=9
- SRC/APP/TEST/test-l0l2-units.asm: COR=38, PIN=5, SYS=5, BIO=4
- SRC/APP/TEST/test-mon.asm: SYS=8, UTL=1

## Symbol Provider/Consumer Hotspots
- COR_FTDI_WRITE_CHAR: provider(s) = SRC/APP/STASH/LIB/ftdi/ftdi-backend-core.asm; consumer file count = 11
- COR_FTDI_WRITE_CRLF: provider(s) = SRC/APP/STASH/LIB/ftdi/ftdi-backend-core.asm; consumer file count = 9
- COR_FTDI_FLUSH_RX: provider(s) = SRC/APP/STASH/LIB/ftdi/ftdi-backend-core.asm; consumer file count = 8
- COR_FTDI_INIT: provider(s) = SRC/APP/STASH/LIB/ftdi/ftdi-backend-core.asm; consumer file count = 8
- COR_FTDI_WRITE_CSTRING: provider(s) = SRC/APP/STASH/LIB/ftdi/ftdi-backend-write.asm; consumer file count = 8
- COR_FTDI_WRITE_HEX_BYTE: provider(s) = SRC/APP/STASH/LIB/ftdi/ftdi-backend-core.asm; consumer file count = 8
- SYS_WRITE_CRLF: provider(s) = SRC/APP/STASH/LIB/dev/dev-adapter-write.asm; consumer file count = 8
- SYS_FLUSH_RX: provider(s) = SRC/APP/STASH/LIB/dev/dev-adapter-core.asm; consumer file count = 7
- SYS_INIT: provider(s) = SRC/APP/STASH/LIB/dev/dev-adapter-core.asm; consumer file count = 7
- SYS_WRITE_HEX_BYTE: provider(s) = SRC/APP/STASH/LIB/dev/dev-adapter-write.asm; consumer file count = 7
- COR_FTDI_POLL_CHAR: provider(s) = SRC/APP/STASH/LIB/ftdi/ftdi-backend-core.asm; consumer file count = 6
- COR_FTDI_READ_CHAR: provider(s) = SRC/APP/STASH/LIB/ftdi/ftdi-backend-core.asm; consumer file count = 6
- SYS_WRITE_CHAR: provider(s) = SRC/APP/STASH/LIB/dev/dev-adapter-core.asm; consumer file count = 6
- SYS_WRITE_CSTRING: provider(s) = SRC/APP/STASH/LIB/dev/dev-adapter-write.asm; consumer file count = 6
- BIO_FTDI_READ_BYTE_BLOCK: provider(s) = SRC/APP/STASH/LIB/ftdi/ftdi-hal.asm; consumer file count = 5
- COR_FTDI_READ_CSTRING_ECHO: provider(s) = SRC/APP/STASH/LIB/ftdi/ftdi-backend-readline.asm; consumer file count = 5
- SYS_READ_CSTRING_EDIT_ECHO_UPPER: provider(s) = SRC/APP/STASH/LIB/dev/dev-adapter-readline.asm; consumer file count = 5
- BIO_FTDI_FLUSH_RX: provider(s) = SRC/APP/STASH/LIB/ftdi/ftdi-hal.asm; consumer file count = 4
- BIO_FTDI_POLL_RX_READY: provider(s) = SRC/APP/STASH/LIB/ftdi/ftdi-hal.asm; consumer file count = 4
- BIO_FTDI_WRITE_BYTE_BLOCK: provider(s) = SRC/APP/STASH/LIB/ftdi/ftdi-hal.asm; consumer file count = 4

## Duplicate Routine Names Across Files
- CMD_PARSE_AND_EXECUTE appears in 4 files: SRC/APP/STASH/cmd.asm, SRC/APP/STASH/himon.asm, SRC/APP/STASH/himonv.asm, SRC/APP/STASH/monitor.asm
- CMD_PARSE_AND_EXECUTE_ROUTER appears in 3 files: SRC/APP/STASH/himon.asm, SRC/APP/STASH/himonv.asm, SRC/APP/STASH/monitor.asm
- MON_LOAD_ACCUM_RECORD_ONLY appears in 3 files: SRC/APP/STASH/himon.asm, SRC/APP/STASH/himonv.asm, SRC/APP/STASH/monitor.asm
- MON_LOAD_CAPTURE_GO appears in 3 files: SRC/APP/STASH/himon.asm, SRC/APP/STASH/himonv.asm, SRC/APP/STASH/monitor.asm
- MON_LOAD_CLASSIFY_TYPE appears in 3 files: SRC/APP/STASH/himon.asm, SRC/APP/STASH/himonv.asm, SRC/APP/STASH/monitor.asm
- MON_LOAD_INIT appears in 3 files: SRC/APP/STASH/himon.asm, SRC/APP/STASH/himonv.asm, SRC/APP/STASH/monitor.asm
- MON_LOAD_PARSE_RECORD appears in 3 files: SRC/APP/STASH/himon.asm, SRC/APP/STASH/himonv.asm, SRC/APP/STASH/monitor.asm
- MON_LOAD_PRINT_SUMMARY appears in 3 files: SRC/APP/STASH/himon.asm, SRC/APP/STASH/himonv.asm, SRC/APP/STASH/monitor.asm
- MON_LOAD_READ_LINE appears in 3 files: SRC/APP/STASH/himon.asm, SRC/APP/STASH/himonv.asm, SRC/APP/STASH/monitor.asm
- MON_LOAD_RESOLVE_ADDR16 appears in 3 files: SRC/APP/STASH/himon.asm, SRC/APP/STASH/himonv.asm, SRC/APP/STASH/monitor.asm
- MON_LOAD_VALIDATE_ARGS appears in 3 files: SRC/APP/STASH/himon.asm, SRC/APP/STASH/himonv.asm, SRC/APP/STASH/monitor.asm
- MON_LOAD_WRITE_RECORD_DATA appears in 3 files: SRC/APP/STASH/himon.asm, SRC/APP/STASH/himonv.asm, SRC/APP/STASH/monitor.asm
- MON_LOAD_COMMIT_CURRENT_RANGE appears in 2 files: SRC/APP/STASH/himon.asm, SRC/APP/STASH/himonv.asm
- MON_LOAD_FINALIZE_RANGES appears in 2 files: SRC/APP/STASH/himon.asm, SRC/APP/STASH/himonv.asm
- MON_LOAD_MAYBE_GO appears in 2 files: SRC/APP/STASH/himon.asm, SRC/APP/STASH/himonv.asm
- MON_LOAD_PRINT_ONE_RANGE appears in 2 files: SRC/APP/STASH/himon.asm, SRC/APP/STASH/himonv.asm
- MON_LOAD_TRACK_DATA_RANGE appears in 2 files: SRC/APP/STASH/himon.asm, SRC/APP/STASH/himonv.asm

## Unresolved Imports (XREF without local XDEF provider)
- COR_FTDI_DEBUG_WRITE_FLAGS_A
- COR_FTDI_DEBUG_WRITE_STR
