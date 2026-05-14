# QCC ASM

This page keeps onboard assembler questions in QCC form. These are working
notes for the hash-first assembler path.

## Q: Can assembler symbols be hash-first?

Comment: Yes. A tiny onboard assembler can hash labels and mnemonics, then
resolve names through catalog records.

Concern: Hash-only symbol records are not enough for every case. User-created
symbols need enough name text, length, scope, or collision data to prove which
symbol was intended.

## Q: What happens with forward labels?

Comment: Emit a fixup record when a label is used before it is known. Later,
when the label is sealed into the symbol table, resolve the fixup.

Concern: Fixups must record enough context to patch safely: address, width,
relative/absolute mode, symbol hash, and any text or scope needed to survive a
collision.

## Q: Should assembler records use FSB?

Comment: FSB fits assembler-generated flash records well:

```text
formed   record shape is present
sealed   checks passed
buried   old version is obsolete
```

Concern: Do not mark assembler output sealed until its bytes, fixups, pointer
ranges, and collision rules have been checked.

## Q: Should the assembler support BRA islands?

Comment: `BRA islands` are generated branch trampolines for reaching beyond
the signed 8-bit relative branch range. Instead of hand-maintaining a chain like
`$4000 -> $407X -> $40XX -> $41YY -> target`, the assembler or linker would
place small nearby `BRA` hops in safe island slots.

Example shape:

```text
$4000: BRA island_0
...
island_0: BRA island_1
...
island_1: BRA target
```

The useful cases are:

```text
position-ish code that wants to avoid absolute JMP operands
generated long branch support
flash/patch layouts where a nearby two-byte branch is easier to place
controlled filler/alignment zones that can hold trampoline hops
poor-man overlay/linker connection between separately placed code blocks
```

Position-ish code is not fully position-independent 6502 code. It just means a
block can keep more of its internal control flow relative. If the block moves
but its internal layout stays the same, `BRA` hops still mean "go this many
bytes from here", while `JMP $addr` has to be relocated.

Avoiding an absolute operand at the original site can matter when the original
site is early, fixed, or hard to patch. A `JMP $4200` embeds `00 42` in that
instruction. A `BRA island` embeds only a signed nearby offset and lets later
layout machinery decide how the islands reach the true destination.

Flash patching is a special case of this. Flash can usually clear `1 -> 0`
bits, but cannot freely set `0 -> 1` bits without erasing a sector. Rewriting a
16-bit absolute address may require illegal bit transitions. Pre-planned branch
slots can sometimes give the system more legal patch points.

Alignment and filler zones are the cleanest island homes. If the assembler or
linker knows a region is padding, reserved space, or a generated branch-pad
area, it can place `BRA` hops there without hiding control flow inside normal
code.

As a poor-man overlay/linker trick, one module can exit through a known island
slot and another module can be reached by generated hops. That is not a full
relocator, but it is a small native mechanism for connecting separately placed
code blocks.

For conditional far branches, the assembler can use an inverted short branch
over an unconditional island hop:

```text
BNE skip
BRA far_target_island
skip:
```

Concern: Humans should not maintain branch islands by hand. Island placement
needs assembler/linker help, range checking, and a rule for where islands are
legal. The first assembler does not need this; record it as future machinery for
when labels, fixups, and generated code layout are strong enough.

## Q: When does ASM graduate from QCC to decision?

Comment: When the record bytes, fixup lifecycle, collision rule, and flash
ownership are clear enough to implement without guessing.

Concern: A half-decided assembler format can trap the system into supporting
bad records forever. Keep exploratory formats QCC until the write/verify path
is boring.
