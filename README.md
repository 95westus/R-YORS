# R-YORS (Coming Soon(ish))

`R-YORS` = **Roll Ya Own Runtime System**

No E, expect fewer errors. LOL

Pronunciation: **"are-yors"** (`R + ya + ors`).

R-YORS is an in-progress 65C02 runtime project.
A full public project write-up is coming soon.
Once I have a flashable command-processor image with a working `DUMP` command that accepts at least one parameter (start address) and defaults to a `$100`-byte length, I'll release additional project details.

Naming guide and alias normalization:
- See [R-YORS_GUIDE.md](./R-YORS_GUIDE.md).
- `R-YORS` is the preferred primary name; legacy aliases include `RYORS`, `RORS`, and `RЯORS` (stylized/logo form).

For now, this repository contains active source, contracts, and internal working docs while the project is being shaped. The code is being intentionally thought through for both form and function, with a long-term goal of building a massive set of libraries that contains the "kitchen sink." Testing is part of the current workflow, and edge-case handling is documented in the project docs.

Current routine counts:
- Total routines written: `138` (from the generated routine contracts).
- Backend routines exercised repeatedly by the backend harness: `19` (`COR_*` routines directly called in the interactive backend harness).
- Direct lower-layer calls in the interactive backend harness: `10` (`UTL_*`).
- Lower-layer routines reached transitively through those backend calls: `11` total (`BIO=4`, `PIN=4`, `UTL=3`).

The current codebase already exercises live console and utility behavior through interactive loops and across core layers, including PIN, BIO, and UTL integrations.





