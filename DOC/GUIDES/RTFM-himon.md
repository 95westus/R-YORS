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
D start +n     dump memory
D start end    dump memory range
M addr         modify memory
U start +n     disassemble
A addr         assemble
G addr         go to address
L              load S-records to RAM
L G            load S-records and go
L F            flash-load S-records under the current guard
R [regs]       display/edit trapped context registers
B start        set breakpoint
B C start      clear breakpoint
B L            list breakpoints
S              single-step trapped context; target moves to N/NEXT
X              resume trapped context when one exists
Q              quiesce with WAI, then re-enter on wake
```

Use HIMON for normal work. Use STR8 for boot-image recovery and backup policy.

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

## Range Syntax Target

The current ROM parser still uses the older range behavior. The target syntax
for the next range-parser revision is:

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

The `+` is not meant to be the normal typing path for page-local end-byte
dumps. `D 100 3` means `$0100-$0103`; `D 3000 FF` means `$3000-$30FF`.
Use `+count` when the operator means a byte count, not an end byte. See
`page-local` in `GLOSSARY.md`.

Bare `D` is target behavior for the next parser revision. It should continue
from the byte after the previous dump and reuse the previous dump length:

```text
D 3000 FF    dump $3000-$30FF and remember length $0100
D            dump $3100-$31FF
D            dump $3200-$32FF
```

## Search And Step Direction

`S` is currently single-step. The preferred direction is to move step/next to
`N` or `NEXT`, freeing `S` for memory search:

```text
S addr end|+count b0 [b1 ...]
S addr end|+count b0 [b1 ...] 'TEXT
S addr end|+count 'TEXT
N
NEXT
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
