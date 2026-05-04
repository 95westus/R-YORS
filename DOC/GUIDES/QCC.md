# QCC Notes

`QCC` means:

```text
Question
Comment
Concern
```

A QCC page is for design thinking that is important enough to keep, but not
settled enough to become a decision yet.

The style comes from call-center training: after each section or block, the
trainer would pause for QCC, meaning questions, comments, and concerns. R-YORS
uses it the same way: stop at the end of a thought block, catch what is unclear,
record what seems useful, and name what could still go wrong before pretending
the topic is settled.

Use this shape:

```text
Q: What are we asking?

Comment: What seems true, useful, or likely right now?

Concern: What could go wrong, what must not be assumed, or what still needs
proof?
```

QCC notes are allowed to contain what-ifs, partial schemes, warnings, and
working vocabulary. When a QCC answer becomes firm, copy the settled part into
`DECISIONS.md` and leave the QCC note as background.

## Current QCC Topics

- [QCC_HASH.md](./QCC_HASH.md) - hash widths, folded FNV-1a, F/N/V layouts,
  compact signatures, and collision questions.
- [QCC_FLASH.md](./QCC_FLASH.md) - flash-native record lifecycle, FSB bits,
  buried records, and condense/compress policy.
- [QCC_ASM.md](./QCC_ASM.md) - hashed assembler symbols, fixups, labels, and
  when hash-only records are not enough.
- [QCC_STR8.md](./QCC_STR8.md) - STR8/STRAIGHTEN scope, ownership boundaries,
  scanning, and recovery/update responsibilities.
- [QCC_MEMORY.md](./QCC_MEMORY.md) - RAM/IO/flash ranges, 4K selectors,
  allocation questions, and bit-helper direction.
