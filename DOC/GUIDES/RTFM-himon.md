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

## Common Commands

```text
?              help
D start +n     dump memory
D start end    dump memory range
M addr         modify memory
U start +n     disassemble
A addr         assemble
G addr         go to address
L              load S-records to RAM
L G            load S-records and go
L F            flash-load S-records under the current guard
R              reset/re-enter monitor path
X              resume trapped context when one exists
Q              quiesce with WAI, then re-enter on wake
```

Use HIMON for normal work. Use STR8 for boot-image recovery and backup policy.

`Q` is a true quiesce command now. It masks IRQ, enters `WAI`, and resumes by
re-entering HIMON when the CPU wakes. NMI remains the trap/debug path.

`M` is currently byte-by-byte memory modify. A future HIMON fill operation fits
best as an explicit `M` subform, not a replacement for modify. Candidate shape:

```text
M start [end|+n] =bb    fill range with byte bb
```

That future fill should start as RAM-only. Flash fill belongs behind the same
guarded/RAM-updater policy as other flash writes.

## Short Typing

HIMON accepts terse forms when they are unambiguous. This is good at the bench:
fewer keystrokes, fewer chances to mistype, and faster inspection while the
machine is already in a weird state.

For `D`, remember the difference between an end address and a count:

```text
D 0 +f       dump from $0000 for $0F bytes
D 0 f        dump from $0000 through $000F
D 8000 +f    dump from $8000 for $0F bytes
D 8000 f     dump from $8000 through $000F, not the same thing
```

Short typing is worth keeping, but `+n` is the safer habit when you mean
"show me this many bytes."

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
