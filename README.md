# RЯORS (R-YORS) #

`R-YORS` = **Roll Ya Own Runtime System**

Not eRRORS, but expect fewer.

Pronunciation: **"are-yors"** (`R + ya + ors`).

R-YORS is an in-progress 65C02 runtime project.
A full public project write-up is coming soon.
Once I have a flashable command-processor image with a working suite of utilities like the `DISPLAY` command and have tested the digital pin routines and the layers based on them, I'll release additional project details.

Naming guide and alias normalization:
- See [DOC/GUIDES/INDEX.md](./DOC/GUIDES/INDEX.md).
- `R-YORS` is the preferred primary name; legacy aliases include `RYORS`, `RORS`, and `RЯORS` (stylized/logo form).

Repository layout:
- `DOC/branding/`: visual identity assets.
- `DOC/GUIDES/`: index, glossary, references, and cross-reference notes.
- `SRC/APP/`: runnable command/monitor assembly programs and app workflow lanes.
- `SRC/APP/STASH/`: proven, tested app-level code.
- `SRC/APP/STASH/LIB/`: shared runtime/library assembly modules currently promoted to STASH.
- `SRC/APP/TEST/`: test harnesses and test entry points.
- `SRC/APP/TEST/LIB/`: test-only library modules/helpers.
- `SRC/APP/SESH/`: session-in-progress code and experiments.
- `SRC/APP/SESH/LIB/`: in-progress/experimental library modules.
- `SRC/APP/STATUS.md`: quick status board for app maturity flow.
- `SRC/Makefile`: source-level build orchestration.
- `Makefile`: top-level pass-through wrapper for `SRC/Makefile`.

For now, this repository contains active source, contracts, and internal working docs while the project is being shaped. The code is being intentionally thought through for both form and function, with a long-term goal of building a massive set of libraries that contains the "kitchen sink." Testing is part of the current workflow, and edge-case handling is documented in the project docs.

Current `rom.lib` routine scan (`SRC/APP/STASH/LIB/**/*.asm`, `; ROUTINE:` blocks):
- Library modules included in `rom.lib`: `19`.
- Routine blocks found: `104` (`104` unique routine names).
- Prefix breakdown: `COR=38`, `SYS=31`, `UTL=21`, `PIN=5`, `TST=5`, `BIO=4`.
- Subsystem file breakdown: `ftdi=8`, `util=7`, `dev=4`.

The current codebase already exercises live console and utility behavior through interactive loops and across core layers, including PIN, BIO, COR, and SYS integrations.
