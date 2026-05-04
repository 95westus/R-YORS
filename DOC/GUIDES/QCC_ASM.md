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

## Q: When does ASM graduate from QCC to decision?

Comment: When the record bytes, fixup lifecycle, collision rule, and flash
ownership are clear enough to implement without guessing.

Concern: A half-decided assembler format can trap the system into supporting
bad records forever. Keep exploratory formats QCC until the write/verify path
is boring.

