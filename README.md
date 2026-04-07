# RЯORS (Coming Soon)

`RЯORS` = **Roll Ya Own Runtime System**

No E, expect fewer errors.

Pronunciation: **"are-yors"** (`R + ya + ors`).

RЯORS is an in-progress 65C02 runtime project.
A full public project write-up is coming soon.
Once the test harness runs as a program under a monitor built from these routines, I’ll release additional project details.

For now, this repository contains active source, contracts, and internal working docs while the project is being shaped. The code is being intentionally thought through for both form and function, with a long-term goal of building a massive set of libraries that contains the "kitchen sink." Testing is part of the current workflow, and edge-case handling is documented for selected paths (see `SRC/EDGE_CASES.md` and `SRC/ROUTINE_CONTRACTS.md`).

Current routine counts:
- Total routines written: `122` (from the generated routine contracts).
- Backend-path routines exercised repeatedly by the backend harness: `19` (`COR_*` routines directly called in the interactive backend harness).
- Direct lower-layer calls in the interactive backend harness: `9` (`UTL_*`).
- Lower-layer routines reached transitively through those backend-path calls: `11` total (`BIO=4`, `PIN=4`, `UTL=3`).

The current codebase already exercises live console and utility paths through interactive loops (`TEST_W12_CHAR_ECHO_NOECHO`, `TEST_W14_TIMED_W_CHALLENGE`, `TEST_W18_CHAR_LOOP`, `TEST_W19_STRING_LOOP`, `TEST_W21_SPINCOUNT_SPINDOWN_LOOP`, `TEST_W20_DELAY_FLUSH_LOOP` in `SRC/backend-test.asm`) and across core layers: `PIN_FTDI_POLL_RX_READY`/`PIN_FTDI_READ_BYTE_NONBLOCK`, `BIO_FTDI_READ_BYTE_BLOCK`/`BIO_FTDI_POLL_RX_READY`, and `UTL_HEX_BYTE_TO_ASCII_YX`/`UTL_CHAR_IS_PRINTABLE`.

