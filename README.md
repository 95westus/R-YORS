# RЯORS (Coming Soon(ish))

`RЯORS` = **Roll Ya Own Runtime System**

No E, expect fewer errors.

Pronunciation: **"are-yors"** (`R + ya + ors`).

RЯORS is an in-progress 65C02 runtime project.
A full public project write-up is coming soon.
Once the test harness runs as a program under a monitor built from these routines, I’ll release additional project details.

For now, this repository contains active source, contracts, and internal working docs while the project is being shaped. The code is being intentionally thought through for both form and function, with a long-term goal of building a massive set of libraries that contains the "kitchen sink." Testing is part of the current workflow, and edge-case handling is documented in the project docs.

Current routine counts:
- Total routines written: `122` (from the generated routine contracts).
- Backend routines exercised repeatedly by the backend harness: `19` (`COR_*` routines directly called in the interactive backend harness).
- Direct lower-layer calls in the interactive backend harness: `9` (`UTL_*`).
- Lower-layer routines reached transitively through those backend calls: `11` total (`BIO=4`, `PIN=4`, `UTL=3`).

The current codebase already exercises live console and utility behavior through interactive loops and across core layers, including PIN, BIO, and UTL integrations.
