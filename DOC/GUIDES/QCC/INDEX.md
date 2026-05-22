# QCC Notes

`QCC` means:

```text
Question
Comment
Concern
```

A QCC page is for design thinking that is important enough to keep, but not
settled enough to become a decision yet.

When a QCC page is added, split, promoted, deprecated, or made the new
canonical home for an idea, add a short alert to [DOC_FLASH.md](../DOC_FLASH.md)
so readers know their mental map changed.

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

## Q: Is R-YORS trying to emulate IBM midrange systems?

Comment: No. R-YORS is not an emulator, simulator, clone, or compatibility
target for System/34, System/36, System/38, AS/400, or IBM i. The project
author has System/36 experience and System/34 simulation/emulation interest, so
some vocabulary and instincts may show through. R-YORS itself is a W65C02
project growing from board constraints, flash banks, HIMON, STR8, hash catalogs,
and routines-of-routines.

Some ideas may rhyme with IBM midrange systems: named things, catalogs, stable
callable services, recoverable storage, and machine-level policy. Those rhymes
are useful comparisons, not product goals.

Concern: Do not import unwanted midrange complexity, opacity, job-control
assumptions, database worldview, or compatibility promises. If an idea does not
fit a small inspectable 6502 runtime, it does not belong in the first path.

## Current QCC Topics

- [QCC_HASH.md](HASH.md) - hash widths, folded FNV-1a, F/N/V layouts,
  compact signatures, and collision questions.
- [QCC_FLASH.md](FLASH.md) - flash-native record lifecycle, FSB bits,
  buried records, and condense/compress policy.
- [QCC_ASM.md](ASM.md) - hashed assembler symbols, fixups, labels,
  mnemonic dispatch, self-modifying-code (SMC) boundaries, and the VM boundary.
- [QCC_CATALOG_LINKING.md](CATALOG_LINKING.md) - catalog-linking
  bootstrap, seed-layer joins, storage-bank metadata, and payload-baggage
  questions.
- [QCC_STR8.md](STR8.md) - STR8/STRAIGHTEN scope, ownership boundaries,
  scanning, and recovery/update responsibilities.
- [QCC_MEMORY.md](MEMORY.md) - RAM/IO/flash ranges, 4K selectors,
  allocation questions, and bit-helper direction.
