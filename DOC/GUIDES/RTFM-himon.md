# RTFM HIMON

HIMON is the normal R-YORS monitor. STR8 gets the machine through reset and
recovery; HIMON is where ordinary inspection, loading, debugging, assembling,
and program launch happen.

## Entry

Normal path:

```text
reset -> STR8 -> G -> HIMON
```

Current HIMON starts at `$C000`. In the combined STR8/HIMON image, STR8 jumps
there for `G`.

Standalone HIMON images also start at `$C000`. The old fixed HIMONIA novelty
entries at `$F00D`, `$FADE`, and `$FEED` are gone. Use the current map file for
build-specific addresses.

## Command Safety Mandate

```text
DESTRUCTIVE COMMANDS MUST BE 4+ CHARACTERS.
```

This is the new command-language rule. Any command whose ordinary purpose is to
overwrite, copy, fill, move, erase, program, patch, restore, back up, or change
boot/storage policy must use a full word of at least four characters.

Examples of future destructive spellings:

```text
COPY start end|+count dest
FILL start end|+count byte
MOVE start end|+count dest
FLASH ...
BANK ...
RESTORE ...
BACKUP ...
ERASE ...
```

Current short mutators, such as `M`, `A`, breakpoint patching through `B`, and
`L F`, are current-ROM behavior and transition debt. Do not add new short
destructive commands.

## Current Commands

```text
?              help
# [token]      list records, or resolve token without executing it
"text"         print FNV-1a32 for quoted text; reports STR8 match on #5F6A0F7A
D start +count dump memory
D start end    dump memory range
M addr         modify memory
U start +count disassemble
A addr         assemble
G addr         go to address
L              load S-records to RAM
L G            load S-records and go
L F            flash-load S-records under the current guard
R [regs]       display/edit trapped context registers
B start        set breakpoint
B C start      clear breakpoint
B L            list breakpoints
N              single-step trapped context
X              resume trapped context when one exists
Q              quiesce with WAI, then re-enter on wake
```

Use HIMON for normal work. Use STR8 for boot-image recovery and backup policy.

The quoted-hash command uppercases input through HIMON's normal reader. A
leading space after the opening quote is ignored, trailing spaces before the
closing quote are trimmed, and text is hashed through the closing quote or end
of line. It is an identity-marker Easter egg, not a security boundary.

`B L` currently reports active breakpoint slots in table order. A future
sorted-list helper should print breakpoint tables in address order, but that is
polish after the trap/restore behavior is stable.

`B` reports `BP FULL` when all four slots are active. `B C hhhh` reports
`BP NF` when that address is not currently active. Breakpoints outside
`$2000-$77FF` report `DBG RAM`.

`Q` is a true quiesce command now. It masks IRQ, enters `WAI`, and resumes by
re-entering HIMON when the CPU wakes. NMI remains the trap/debug path.

`M` is currently byte-by-byte memory modify. Under the new command safety
mandate, bulk fill should not become an `M` subform. It should be a full-word
command:

```text
FILL start end|+count bb
```

That future fill should start as RAM-only. Flash fill belongs behind a
full-word flash/update command and guarded RAM-updater policy.

## Range Syntax

The shared range parser uses:

```text
start end       end is inclusive
start +count    count is the number of bytes
```

Short typing stays useful for display/search/disassembly:

```text
D 0 FF       dump $0000-$00FF
D 100 3      dump $0100-$0103
D 3000 FF    dump $3000-$30FF
D 3000 +100  dump $3000-$30FF
D            repeat previous dump length at next address
```

A 1- or 2-hex-digit end token inherits the high byte from `start`. If that
would land before `start`, use a full end address or `+count`; for example,
prefer `D 30F0 3110` or `D 30F0 +21` over `D 30F0 10`.

A 3- or 4-hex-digit end token is a full address. `D 1000 FFF` is rejected
because `$0FFF` is before `$1000`; use `D 1000 1FFF` or `D 1000 +1000`.

The `+` is not meant to be the normal typing path for page-local end-byte
dumps. `D 100 3` means `$0100-$0103`; `D 3000 FF` means `$3000-$30FF`.
Use `+count` when the operator means a byte count, not an end byte. See
`page-local` in `GLOSSARY.md`.

Bare `D` is target behavior for a later parser revision. It should continue
from the byte after the previous dump and reuse the previous dump length:

```text
D 3000 FF    dump $3000-$30FF and remember length $0100
D            dump $3100-$31FF
D            dump $3200-$32FF
```

## Search And Step Direction

`N` is the resident single-step command. `S` is freed for memory search and is
expected to resolve through the FNV command catalog when the search record is
present. `NEXT` is not a command alias. RAM-only `N` is non-destructive because
it plants only a temporary debugger trap in RAM and restores the original
opcode. The first patchable range is user program RAM `$2000-$77FF`; system
RAM, I/O, and ROM/flash are not debug patch targets:

```text
S addr end|+count b0 [b1 ...]
S addr end|+count b0 [b1 ...] 'TEXT
S addr end|+count 'TEXT
N
```

Hex byte tokens are the default pattern. After the range, parse one or more
pattern atoms. A hex byte token appends one byte. A pattern atom starting with
`'` appends text and consumes the rest of the command line:

```text
S 0 FFFF 4D 4D 'M
```

That searches for three `M` bytes. For V0, apostrophe text is a final tail:
there is no closing-quote parser and no return to hex parsing after text.
Current HIMON command input uppercases
printable letters before dispatch; use hex bytes for exact lowercase or
mixed-case data until that input policy changes.

Search hits should use the same visual language as `D`, but with exact hit
address first and aligned dump row second. This follows the useful BSO2 monitor
search-display convention:

```text
B88F B880: ...
022B*0220: ...
```

`*` marks a match that crosses the 16-byte display row boundary.

## Debug Transcript Legend

`STEP PC=hhhh ... NEXT=nnnn` is the pre-execution decode printed by `N`/`S`.
`RESUME hhhh` means HIMON returned to the trapped context. `@hhhh A=...` is a
debugger-owned stop from a temporary step trap or user breakpoint; the planted
`BRK 00` has been classified and the original opcode restored. Real program
stops remain `BRK xx PC=hhhh`.

Plain monitor commands print their own result and return to the prompt without
the old `RET ...` register trailer. `RET ...` is reserved for user execution
that returns through HIMON, such as a `G`/`L G` target that reaches `RTS`.

For real `BRK xx`, the printed PC is the resume address after the two-byte BRK.
For example, `BRK 42 PC=304C` means the `BRK $42` at `$304A` ran and `$304C`
has not executed yet. If `B L` shows a pending breakpoint at that resume PC,
use `X` to enter it. `N` at a PC that is already patched by a pending
breakpoint is an edge case.

`B L` prints active breakpoint slots as `address original-opcode`. Breakpoints
are one-shot in the current build, so an `@hhhh` hit consumes that slot.
Persistent breakpoints are future work because they need a step-over/replant
state to avoid immediately trapping again at the same PC.

## BRK Signature Direction

On W65C02S, `BRK xx` gives HIMON a one-byte signature after the opcode. Current
debug uses `BRK 00` as the synthetic temporary step/breakpoint trap, but reports
debugger-owned stops as compact `@hhhh A=...` state lines. RAM proof programs
can use fixed nonzero signatures as intent markers:

```text
@hhhh   debugger temporary step/breakpoint stop, backed by BRK 00
BRK 41  proof start stop
BRK 42  proof pass stop
BRK 50  generic assert failed
BRK 59  unhandled exception / impossible path
BRK E1-E9  proof bad-path stops
```

A future dedicated `BRK xx` handler should classify fixed signatures before the
generic monitor report. That gives HIMON a clean way to say "known proof stop",
"known failure stop", or "unexpected BRK signature; you may be leaving code or
stepping through data".

`$50-$5F` is the lightweight assert/exception range. Do not fill the whole range
until repeated use proves the names. Start with only `$50 ASSERT` and
`$59 UNHANDLED`.

Proposed full signature range, subject to change:

```text
00       HIMON synthetic debug trap
01-1F    monitor/debug/internal stops
20-3F    user/program intentional stops
40-4F    proof/test lifecycle
50-5F    assert/exception
60-7F    subsystem/runtime
80-BF    app-defined
C0-DF    system/recovery danger
E0-EF    proof/test failure
F0-FF    fatal/unknown/reserved
```

Proposed assert/exception names, also subject to change:

```text
50  ASSERT
51  PRECONDITION
52  POSTCONDITION
53  INVARIANT
54  RANGE/BOUNDS
55  ILLEGAL_STATE
56  MISSING_HANDLE
57  BAD_RECORD
58  VERIFY_FAILED
59  UNHANDLED
5A  UNIMPLEMENTED
5B  IMPOSSIBLE_DEFAULT
5C  FLOW/STACK
5D  MEMORY_OWNERSHIP
5E  UNSUPPORTED
5F  FATAL_ASSERT
```

## RAM Proof To Image

New monitor/debug code should prove itself as RAM-loaded S19 before it becomes
part of a burnable image. The working loop is:

```text
write a small standalone RAM proof
link it inside UPA, usually $2000-$77FF
build an S19
load it with HIMON L or L G
debug it with B, N, R, X, D, and U
promote clean code into HIMON or a ROM/flash image
build the final .bin
```

For the next search command, `S` should start this way: a RAM proof S19 running
under HIMON, not a permanent HIMON command record on the first pass. Link it in
user RAM and keep the code away from HIMON's workspace, page buffers, I/O, and
ROM/flash. Debug patches only belong in `$2000-$77FF`; if step or breakpoint
tries to plant a synthetic `BRK` elsewhere, HIMON reports `DBG RAM`.

Build examples already in this tree:

```text
make -C SRC life       -> SRC/BUILD/s19/life-2000.s19 + SRC/BUILD/bin/life-2000-load.bin
make -C SRC str8-ram   -> SRC/BUILD/s19/str8-ram-3000.s19
```

On the board:

```text
>L              load S-records into RAM, then G start manually
>L G            load S-records and use the S9 start address
>B 3000         optional breakpoint in the RAM proof
>G 3000         run the proof when not using L G
```

`L` clears active debug patches before accepting new S-records. Set breakpoints
after loading the program image they belong to.

When the RAM proof is clean, promote it in one of two ways:

```text
HIMON feature: fold the routine/command into SRC/TEST/apps/himon and rebuild.
flash member: link at its intended flash address and make it catalog/record visible.
```

S19 is the transfer/proof format. A `.bin` is not "the same file without text";
it is a placed raw image. For the current main image, use:

```text
make -C SRC himon
make -C SRC himon-str8-rom-bin
```

The important output is:

```text
SRC/BUILD/bin/himon-str8-rom.bin
```

That `.bin` is the 32K `$8000-$FFFF` bank image for the programmer/STR8 image
workflow. For any new standalone ROM member, add an explicit build target or
script that places the linked S19 bytes at the correct ROM offset and verifies
the image before calling it burnable.

## Flash Loading

`L F` is conservative. It writes only where the current guard allows and expects
blank flash bytes. It is not a sector erase/update tool.

Do not use HIMON to casually rewrite:

```text
STR8 protected window
hardware vectors
Bank 0 rotation policy
whole-bank backup/restore images
```

Those belong to STR8 or a future confirmed RAM updater.

## Debug And Recovery

NMI enters HIMON's trap/debug path when the current vectors are installed. From
there, use memory dump/disassembly/register context tools to inspect the
machine.

The active NMI vector is a proof-of-concept debounce handler. It captures the
first NMI context, waits briefly in a software debounce loop, and ignores NMI
edges that arrive during that window. The baseline non-debounced NMI trap
routine remains in the image for comparison.

Do not press NMI while STR8 is erasing or programming flash. NMI cannot be
masked, and a flash operation should be allowed to finish and restore Bank 3.

## Updating HIMON

The current safe update direction is not "let HIMON erase itself." The right
shape is:

```text
STR8 or a RAM updater stages a sector
the operator confirms if erase is required
the RAM updater erases/writes/verifies
Bank 3 is restored before monitor output resumes
```

For HIMON body sectors, this can update ordinary HIMON bytes. For the top flash
sector, the updater must preserve STR8's protected window unless the operator
explicitly requested a STR8 update.

## WDCMONv2 Bridge

Saving the board's original WDCMONv2/base flash image is future bridge work.
HIMON does not do that today.
