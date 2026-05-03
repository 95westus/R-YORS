# Historical Documents

This guide traces the practical path from the WDCMON/WDC board-monitor starting
point, through BSO2 and the Himonia experiments, to the current HIMON path. It
is a source map, not mythology: where a point is based on visible source, it
names that evidence; where it is an architectural reading, it says so.

For a compact reconstruction of the Himon/Himonia/Himonia-F stages and
routine-class families, see [HIMON_STAGES_CLASSES.md](./HIMON_STAGES_CLASSES.md).

## Short Version

BSO2 proved the board-facing monitor idea in one large, practical program:
command parsing, memory tools, S-record loading, mini assembly/disassembly,
debug stops, vector trampolines, warmstart hints, and userland demos.

R-YORS kept the useful BSO2 shape but rejected the monolith. The work moved into
layered routines (`PIN`, `BIO`, `COR`, `SYS`), test lanes, exported symbols, and
small monitors that could be recomposed.

HIMON is the current compact recomposition: a small supervisory monitor with
FNV-1a command dispatch, NMI/BRK trap capture, S-record load/go, assembler and
disassembler helpers, flash command discovery, and fixed ROM ABI jump points.

## Short Weave

The through-line is:

```text
WDCMON/WDC monitor base
  -> BSO2 board monitor
  -> R-YORS routine layers
  -> Himon/Himonia compact monitors
  -> Himonia-F hash-dispatched monitor experiment
  -> HIMON behind STR8
```

WDCMON/WDC sample material is the ground floor: a board boots, talks serial,
loads bytes, and gives the user enough monitor to recover. BSO2 takes that
practical board-monitor posture and expands it hard: command table, memory
tools, S-record load/go, vector hooks, warmstart hints, debug stops,
mini-assembler, mini-disassembler, and demos.

R-YORS changes direction from "one capable monitor" to "routines on routines."
The useful BSO2 behaviors are split into `PIN`, `BIO`, `COR`, `SYS`, app/test
lanes, and reusable exports. Himonia then pulls the monitor back down into a
small supervisor: reset signature, hardware-stack ownership, NMI/BRK context,
load/go, register edit/resume, assembly, disassembly, and compact command
handling.

Himonia-F was the sharp turn: text command dispatch becomes FNV-1a record scan.
That changes the design from "commands are parsed by this monitor" to
"commands/routines can be discovered in flash." The `#` command makes the
catalog visible, `L F` starts making flash-resident command images practical,
and the current HIMON compatibility trampolines give external code a stable way
back into the monitor. Those trampolines are historical HIMON behavior, not a
STR8 design requirement.

The naming trail reflects that exploration. `Himon` was the monitor root.
`Himonia` marked a turn toward a more assisted, more intelligent monitor shape.
`Himonia-F` marked the FNV and Forth-like direction: compact records,
discoverable commands, and flash-resident extension. A short Himon4 variation
also tested the shape of that idea. These names are not competing products or
claims of superiority; they are mile markers from a period of active design.
The current source promotes the useful Himonia-F line back into HIMON.

## Working Context

GitHub is used here first as backup and continuity: a place to keep the work
from disappearing, to make it visible across machines, and to preserve enough
history that the design path can be reconstructed later. The repository should
not be read as proof of a polished git workflow. Renames, transitional files,
and design mile markers may remain visible because they helped the system move
forward.

The project is also intentionally collaborative. The owner can read and reason
about 6502/W65C02 code, hardware behavior, memory maps, and test results, but
does not claim fluent hand-written W65C02 assembly as the main method of
development. R-YORS grows from design intent, board testing, readable source,
and assisted refactoring/code generation working together.

The current direction is STR8 plus HIMON: STR8 keeps recovery/update safe;
HIMON is the normal monitor/debug/catalog/assembler environment. The old thread
is still visible, but the center of gravity moved from firmware monitor to
recoverable, inspectable, self-extending runtime.

## Evidence Map

- WDCMON/WDC monitor material is the launch/reference context for the board
  monitor lineage. Keep local WDCMONv2 source or binaries in `LOCAL/wdcmonv2/`
  when available; they are intentionally not tracked in `ror`.
- `bso2/README.md` describes BSO2 as serial monitor firmware and a proof of
  concept with table-driven dispatch, S19 support, vector chains, debug stops,
  mini assembly/disassembly, and monitor commands.
- `bso2/SRC/bso2.asm` states direct provenance from WDC EDU sample sources, then
  builds a large original monitor around that base.
- `bso2/SRC/bso2.asm` carries the core BSO2 ideas in one file: `WDC_RST`,
  `WDC_NMI`, `WDC_IRQ`, `NMI_HOOK`, `IRQ_HOOK`, `BRK_HOOK`, `RESET_COOKIE`,
  `CMD_DISPATCH`, `CMD_TABLE`, `CMD_DO_LOAD_SREC`, `CMD_DO_UNASM`,
  `CMD_DO_ASM`, `CMD_DO_RESUME`, `CMD_DO_NEXT`, and `DBG_STACK_IMAGE`.
- `bso2/DOCS/reference/warmstart-test-plan.md` records the reset/warmstart
  recovery rule: reset plus warm entry should return to a clean monitor and may
  print restart hints, but should not implicitly resume old state.
- `ror/README.md` explicitly names BSO2 as the predecessor project, says it
  proved the concept, and says R-YORS adopts layered reusable building blocks.
- `ror/SRC/TEST/apps/himon/himon-parent.asm` is the first smaller monitor shell shape:
  line input, HBSTR command table dispatch, reset signature, NMI hook, and
  command routines factored into callable pieces.
- `ror/SRC/TEST/apps/himon/himonia.asm` is the compact supervisory monitor
  before FNV dispatch: direct command comparisons, NMI/BRK trap capture, context
  resume, loader, assembler, disassembler, and debug helpers.
- `ror/SRC/TEST/apps/himon/fnv1a-hbstr.asm` is the visible FNV/HBSTR proving
  app: hash a high-bit-terminated string and print the 32-bit FNV-1a result.
- `ror/SRC/TEST/apps/himon/himon.asm` is HIMON, descended from Himonia-F: the compact monitor
  whose command dispatch scans FNV records and executes matching entries. This
  is the current path toward the final HIMON monitor name.
## Timeline

### WDCMON/WDC Monitor Context: Board First

WDCMON and WDC sample monitor material are the practical starting point:
initialize the board, provide serial monitor access, and keep a recovery path
available. In the current repo this is treated as historical/local source
material, not tracked project source.

Design result: the first requirement is not elegance. It is a board that can
talk, load, inspect, and recover.

### 2026-02-17 to 2026-03-06: BSO2 Proves The Monitor

BSO2 begins as a board monitor descended from WDC EDU sample material and
quickly becomes a hands-on proof of concept. The early commit trail shows rapid
addition of search, boot menus, vector routing, S-record load/go, debug stops,
heartbeat, ACIA experiments, userland demos, and S19-only simplification.

Important BSO2 milestones:

- `2026-02-17`: table-driven monitor work already exists; search is added as a
  real command path.
- `2026-02-18`: boot flow and IRQ routing split into clearer trees; patchable
  hook addresses and vector display become central ideas.
- `2026-02-18`: `L G S` is implemented, making S-record load-and-go a proven
  workflow.
- `2026-02-20`: `R0M0V0I00` marks an early named release point.
- `2026-02-23`: `R0M0V2I05` records heartbeat, banner, checksum, NMI/debug, and
  runtime hardening work.
- `2026-03-05`: debug NMI resume and next/step behavior are tightened.
- `2026-03-06`: S19 becomes the official userland load format; S28/S37 support
  is removed.

Design result: BSO2 is very capable, but capability is concentrated in a large
single monitor. That made it a good proving ground and a poor long-term shape.

### 2026-04-12 to 2026-04-20: R-YORS Splits The Ideas Into Layers

R-YORS starts with the same board and monitor needs, but the repo direction is
different. Instead of growing one monitor, it creates reusable strata:

- `PIN`: direct hardware/register boundary
- `BIO`: hardware abstraction above pins and chips
- `COR`: reusable core services and backend glue
- `SYS`: monitor-facing system services, vectors, I/O, and debug adapters
- `APP`/`TEST`/`SESH` lanes: practical proving grounds

The lineage from BSO2 is architectural rather than a straight copy. BSO2's
command table, loader, debug, vector, and userland ideas become smaller exports
and testable monitor-facing pieces.

### 2026-04-25: Himonia Arrives

Commit `a7756d4` adds `himonia.asm` as a compact supervisory monitor. Compared
with BSO2, it is much smaller and more direct:

- cold/warm reset signature handling
- explicit stack reset on monitor entry
- NMI and BRK trap capture into monitor context bytes
- concise command loop
- memory display/modify
- load/go
- register display/edit/resume
- disassembly and assembly includes

This is the point where BSO2's "monitor as full environment" becomes Himonia's
"monitor as compact supervisor."

### 2026-04-26: FNV And HBSTR Become Runtime Tools

Commit `f12b7a8` adds `fnv1a-hbstr.asm` and factors the assembler/debug/disasm
pieces. This matters because FNV is no longer just documentation hash thinking.
It becomes executable 65C02 code that hashes high-bit-terminated strings.

That same commit is also important because the `A` assembler path gets factored
into `himonia-asm.inc`. In other words, the assembler existed as a practical
monitor feature before the later hashed-symbol assembler design.

### 2026-04-27: Himonia-F Becomes Hash Driven

Commit `53bce09` adds `himonia-f.asm`, now promoted to `himon.asm`, with FNV command dispatch. This is the big
turn:

```text
input token -> FNV-1a hash -> scan FNV records -> entry address -> call
```

Current `himon.asm` shows the model clearly:

- `CMD_HASH_TOKEN` hashes the current command token.
- `CMD_DISPATCH_HASH` scans records.
- `CMD_HASH_RECORD_MATCH` compares the stored hash bytes.
- `CMD_HASH_RECORD_ENTRY` turns a record location into an executable entry.
- `CMD_EXEC_ADDR` calls the entry and captures return registers/flags.
- `# [token]` exposes the FNV lookup/discovery path without executing the
  command.

This is the first monitor shape where "dynamic linking by discoverable command
record" is visibly close.

### 2026-04-28 to 2026-04-29: Flash, Compatibility, And Language Images

The short-lived Forth-like Himonia and Himon4 variants tested command metadata
and contract ideas. The retired variants still matter as design evidence:
command records can carry more than an entry address.

Commit `32c1143` proves flash command installation with `test-flash.s19` and a
runnable `Z` command in flash. The current monitor also exposes historical
compatibility jump points for loaded language images. STR8 should not inherit
that fixed-address ABI idea.

Commits on 2026-04-29 add OSI BASIC, fig-Forth, and Microchess images. That
pushes Himonia from "monitor" toward "small ROM-resident supervisor for loaded
systems."

## Design Lineage

### Command Dispatch

BSO2 used a table-driven command dispatcher. That proved commands should be
routines and that the monitor should route through a compact command surface.

Himon used HBSTR table entries for command names and routine pointers.

Himonia first used direct command comparisons for compactness.

Himonia-F replaced textual dispatch with FNV records, which gives a stable path
for flash-resident commands and future dynamic lookup.

### Vectors And Traps

BSO2's vector model used trampolines and hook bytes in zero page:

```text
hardware vector -> ROM stub -> RAM hook/trampoline -> handler
```

HIMON keeps the key lesson but simplifies the implementation. On monitor
entry it installs RAM vector cells through `SYS_VEC_SET_NMI_XY`,
`SYS_VEC_SET_IRQ_BRK_XY`, and `SYS_VEC_SET_IRQ_NONBRK_XY`. NMI and BRK capture
the interrupted register/stack context, then re-enter the monitor with a clean
hardware stack.

This is the root of the STR8/recovery design: the monitor owns the real
6502 stack and vectors; userland gets explicit context and recovery services.

### Recovery

BSO2's recovery idea was warmstart hints after reset, with no implicit stale
resume. That is still the right principle.

HIMON currently chooses a stricter posture:

- cold reset clears RAM
- monitor entry resets `S` to `$FF`
- NMI/BRK captures context before re-entering
- resume rebuilds an RTI frame from saved context

STR8 should combine the two:

- BSO2's advisory recovery hints
- HIMON's hard monitor-owned stack and explicit trap context
- flash-aware guardrails for erase/write/update windows

### Loader And Userland

BSO2 proved S-record loading and load/go as the normal path for board work.

HIMON keeps S-record loading, adds flash mode, and begins treating appended ROM
command images as discoverable routines. `rom-append-calc.asm` is a clear
example: an FNV record lives at the front of a flash-resident command image,
followed by the callable command entry.

### Assembly

BSO2's `A` command was a practical one-line mini assembler.

Himonia keeps that feature and factors it into `himonia-asm.inc`.

The hashed assembler design is the next step: keep the small onboard assembler,
but let operands resolve through symbol records instead of only numeric text.

## What This Means For STR8

STR8 should be named and designed as the recovery layer, not as another
ordinary monitor command. It should sit at the boundary between supervisor,
flash, and userland.

Recommended meaning:

```text
STR8 = Subroutine To Return, the monitor-owned recovery and mutation guard system
```

Core responsibilities:

- protect flash erase/write/update sequences
- define what NMI, BRK, IRQ, and reset mean during dangerous windows
- preserve enough context to explain what happened
- avoid automatic resume unless the state is explicitly known safe
- expose small routines that userland can call for checkpoint, abort, and exit
- keep the hardware stack under monitor ownership

The old BSO2 lesson is that recovery hints are useful. The Himonia-F/HIMON lesson is
that implicit continuation is dangerous unless the monitor can rebuild the exact
machine context.

## Historical Reading Order

For future archaeology, read in this order:

1. `bso2/README.md`
2. `bso2/SRC/bso2.asm`
3. `bso2/DOCS/reference/warmstart-test-plan.md`
4. `bso2/DOCS/reference/zero-page-usage.md`
5. `ror/README.md`
6. `ror/SRC/TEST/apps/himon/himon-parent.asm`
7. `ror/SRC/TEST/apps/himon/himonia.asm`
8. `ror/SRC/TEST/apps/himon/fnv1a-hbstr.asm`
9. `ror/SRC/TEST/apps/himon/himon.asm`
10. `ror/DOC/GUIDES/STR8.md`
11. `ror/DOC/GUIDES/HASHED_ASM.md`

## Open Historical Questions

- How much of BSO2's warmstart hint state should return in STR8, and how
  much should stay retired?
- The old fixed cute-address entry idea is retired for STR8; future STR8 work
  should use explicit routine labels/imports and `BIO_*` boundaries.
- Should flash command records remain hash-only by default, or carry optional
  text names for collision handling and discoverability?
- Should userland get a monitor-managed software stack API, or only a calling
  convention plus per-app RAM reservations?
