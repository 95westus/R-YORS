# Release applications

Use explicit application lists when preparing the separate STR8-N v1.34,
HIMON, and ASM-F2 releases. Copy current source files and matching build
products, with their notices and instructions. The active release archives
are STR8-N 1.34 and HIMON/ASM-F2 `00.0915(2324)`. Their manifests and
qualification records identify the delivered bytes; legacy unversioned
`RELEASE/ARTIFACTS/` copies are not the current distribution.

The HIMON/ASM release stamp differs from installed board HIMON
`00.0915(2233)` and ASM-F2 `00.0915(2243)`. Exact timestamp-only firmware
equivalence is recorded in `QUALIFICATION.json`; packaging did not reflash
the board or repeat individual application carrier tests.

Unless a different repository is named, `.a` files below are in
`DOC/GUIDES/ASM/SAMPLES/`. They are source text for the onboard assembler:
enter `ASM NEW`, send the complete file, require successful `END`, and follow
its commands at `SEAL>` and HIMON `>`. Assembly requires ASM-F2 even when the
application is distributed with STR8-N or HIMON. Direct-load S19 products can
be supplied alongside the source when a matching image is available.

| Release | Application | Addresses and dependencies |
| --- | --- | --- |
| STR8-N | `str8n-v1.34-bank-maint-menu-2000.a` from `STR8-N/tools/bank-maint/` | Generated carrier; entry `$2000`, embedded top image `$4000`, AP input `$7000`. Use its matching v1.34 S19 and operator guide. Copy, erase, AP put, directory changes, and top update can write flash. |
| ASM-F2 | `str8n-v1.2-bank-crc-all-3000.a` | Direct run `$3000`; stages sectors at `$4000-$4FFF` through `$F010/$0203`; CRC results `$7C10-$7C4F`. Read-only flash inventory using STR8. The v1.2 filename identifies its source lineage. |
| ASM-F2 | `terminal-answerback-vt100-3000.a` | Direct run `$3000`; uses the STR8 raw console ABI and requires Bank 3 visible. |
| ASM-F2 | `vt102-exerciser-7000.a`, `vt525-exerciser-7000.a` | Direct run `$7000`, one at a time; raw STR8 console ABI. Images end at `$79CD` and `$79B2`, respectively. These exercise terminal behavior interactively. |
| HIMON | `bank-audit-2000.a` | Movable `BANKAUDIT` AP, assembled at `$2000`; package `$3000`; sector staging `$4000-$4FFF`. Imports HIMON output and uses the STR8 bank selector. Read-only flash audit; distribute the `.a` AP-build workflow, not the old direct host image. |
| HIMON | `bank-dump-2000.a` | Fixed `$2000` `BANKDUMP` AP; package `$3000`; stages sectors at `$4000-$4FFF`. Imports HIMON input/output and uses the STR8 bank selector. Read-only inspection; distribute the `.a` AP-build workflow, not the old direct host image. |
| HIMON | `pia-led-show-2000.a` | Movable `PIALED` AP, assembled at `$2000`; package `$3000`. Requires EDU LEDs on PIA port A and restores prior port state. |
| HIMON | `edu-rtc-read-7000.a` | Direct run `$7000`; requires W65C02EDU MCP79411 RTC and compatible HIMON ABI. Reads date/time and restores VIA state. |
| HIMON | Life: `SRC/APPS/life.asm` and matching `life-2000.s19` / `life-2000-load.bin` | Standalone program loaded and called at `$2000`; private linked project I/O routines, scratch `$D0-$DB`, board state `$1000-$12F5`, and NMI-vector ownership. Include `SRC/APPS/LIFE-NOTICE.txt` and the repository `LICENSE`. |
| HIMON | `microchess-2000.a`, `SRC/APPS/microchess-2000.asm`, matching MicroChess AP products | Fixed `$2000` AP, package normally at `$3000`; imports HIMON blocking input/output and hex output. Preserve inline credits and distribute `SRC/APPS/MICROCHESS-LICENSE.txt` with every source or binary bundle. |
| ASM-F2 | `asm-session-report-v1.2-ap-2000.a` | Map-matched `ASMREPORT` AP, assembled at `$2000`, package `$3000`, recommended run address `$4000`. Regenerate for the released ASM map. Complete LOAD/AP before the session being inspected, then use `G 4000` after that session. |
| ASM-F2 | `seal-workflow-2000.a`, `expr-operators-ap-2000.a`, `unresolved-addends-2000.a` | Small `$2000` assembly/package examples. Follow their entry and relocation requirements. These are examples, not independent firmware images. |

In the extracted HIMON archive, utility files are under
`APPLICATIONS/UTILITIES/`, games under `APPLICATIONS/LIFE/` and
`APPLICATIONS/MICROCHESS/`, and the optional manager under
`APPLICATIONS/APMAN/`. The ASM archive puts maintained examples directly
under `APPLICATIONS/` and rejection/limit tests under `VALIDATION/`.
Both preserve guide paths under `DOC/GUIDES/`. Firmware payloads are under
`FIRMWARE/`; the archive root README gives the exact installer range and S9.

The checked standalone PIA LED image has no HIMON routine-address dependency.
In contrast, the older BANKAUDIT and BANKDUMP host sources/images pin obsolete
HIMON addresses; they are excluded. Their released `.a` sources use named
imports and must be packaged and loaded through HIMON before execution.

For a release that repeats an application as an ASM example, use the same
source bytes and notices as its primary release. Do not silently copy an
older carrier from the existing release directory.

## Installation and qualification

Persistent `INSTALL 3000 B1` examples require a compatible APMAN installation
and a suitable destination sector. A packaged application can also be tested
from RAM through HIMON `AP`; flash installation is not required merely to
run an example. Keep fixed-load applications at their documented run address.

The movable session reporter must be resident at `$4000` before the target assembly
session. For a RAM workflow, assemble and package the reporter, issue
`LOAD 3000 4000` at `SEAL>`, exit, then start the target session. With a
previously installed reporter, issue `AP B1 ASMREPORT 4000` before starting
that session. After the target session, exit and run `G 4000`. Loading or
calling `AP` afterward would replace session data needed by the report.

Packaging an application does not qualify it against a newly built firmware
stamp. Preserve the scope and date of existing board evidence, and identify
newly rebuilt products separately from installed board images. The current
firmware status is in the repository's `DOC/GUIDES/CAPABILITIES.md`;
application and firmware evidence is retained under `DOC/GUIDES/LOGS/`.
Each release also carries its own qualification summary. Do not describe the full
application set as tested on a new release unless those runs were performed.

## Validation fixtures and exclusions

Keep `opcode-reduction-runtime-2000.a`, `expr-negative-rollback-2000.a`,
symbol/relocation limit fixtures, and canary programs in a separate optional
validation directory. Some deliberately reject source lines. The current
expression rollback fixture has five rejected expressions; forward addends
are accepted and covered separately by `unresolved-addends-2000.a`.
Historical final-image cards retain their dated expectations and are not
current instructions for the revised fixture.

There is no maintained Life `.a` corresponding to the standalone Life
application. Do not relabel its host assembler `.asm` as onboard source.
`SAMPLES/OLD/life16-column-2000.a` uses obsolete installation instructions
and writes status at `$5848/$5849`, inside current ASM workspace; it needs
adaptation and testing before promotion. Other `OLD/` tools and AP-store
proof carriers are not normal release applications.

Exclude WDCMON firmware, WDC toolchain binaries/libraries, Microsoft BASIC,
FIG-Forth, and other third-party products from these bundles. Life and
MicroChess are the explicitly permitted application exceptions with their
notices. The repository MIT license accompanies project code; it does not
replace MicroChess's own redistribution terms and credits.
