# Special Moments

This is the scratchpad for far-out ideas, surprising terms, possible tricks, and
ideas that are not ready to become direction.

Use this file when an idea is worth saving, but not yet strong enough for
`DOC/GUIDES/FUTURE.md`, `TODO.md`, or a focused design guide.

## Buckets

```text
good far out
  strange but promising; may become a design note later

risky far out
  interesting but likely to cause complexity, size, or recovery problems

bad far out
  probably wrong, but worth recording so we remember why

word find
  a term or phrase that may become useful later
```

## Promotion Rule

An item can move out of this file when it has:

```text
clear owner
clear benefit
known cost
first implementation shape
reason it belongs in R-YORS / STR8 / HIMON
```

Until then, it stays here as a special moment.

## Word Find: Device Quench

Bucket: `word find`

- Is it a thing: Yes. In engineering, "quench" usually means a fast suppression
  action to stop a harmful or unstable condition.
- Why use it: To protect hardware, data integrity, and people by forcing a
  rapid safe state, for example disabling output, cutting drive current, or
  resetting a path.
- Where it is used: Common in power electronics, motor control, RF/transmit
  paths, high-voltage systems, and low-level device drivers where faults or
  runaway behavior can happen.
- Layer: Mostly hardware plus firmware/driver boundary, with policy or trigger
  logic sometimes coming from higher-level application code.

Possible R-YORS use:

```text
STR8_QUENCH
  emergency transition to a minimal safe state during flash/update danger
```

## Good Far Out: UTL_PACK_3X5 / UTL_UNPACK_3X5

Bucket: `good far out`

Pack three already-normalized 5-bit character codes into two bytes.

Bit layout:

```text
X:Y = 0aaaaabb bbbccccc
```

```text
bits 14..10 = char 1
bits  9..5  = char 2
bits  4..0  = char 3
bit 15      = 0
```

`UTL_PACK_3X5`:

```text
IN:
  A = char 1 code, already normalized to 0..31
  X = char 2 code, already normalized to 0..31
  Y = char 3 code, already normalized to 0..31

OUT:
  X = packed high byte
  Y = packed low byte
  C = clear on success, set on invalid input
```

`UTL_UNPACK_3X5`:

```text
IN:
  X = packed high byte
  Y = packed low byte

OUT:
  A = char 1 code, 0..31
  X = char 2 code, 0..31
  Y = char 3 code, 0..31
  C = clear on success, set if packed bit 15 is invalid/set
```

Callers choose the alphabet. For example, uppercase mnemonics can subtract
`'A'` before packing and add `'A'` after unpacking; lowercase can do the same
with `'a'`.
