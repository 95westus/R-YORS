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

## Word Find: THE

Bucket: `word find`

`THE` means `The Hash Engine`.

Possible R-YORS use:

```text
THE
  the conceptual hash path for canonical names, tokens, records, lookups,
  symbol resolution, fixups, catalog discovery, and proof metadata
```

Working distinction:

```text
THE makes named things findable.
THE does not make raw addresses meaningful.
```

## Bad Far Out: Hashing ASM Addresses

Bucket: `bad far out`

Question:

```text
Would hashing the actual address, either as binary bytes or as hex ASCII,
benefit, aid, or accomplish anything for ASM?
```

Short answer:

```text
Not for ASM resolution.
```

For assembler work, an address is already the useful payload. A 16-bit address
is smaller than a 32-bit FNV-1a hash, can be emitted directly, can be
range-checked, can be tested for zero-page use, and can participate in relative
branch math. Hashing it turns useful structure into an opaque value that cannot
be reversed back into the address and can still collide.

Hex ASCII is especially weak for this use because spelling choices can change
the hash while naming the same address:

```text
$2000
2000
$02000
```

Binary address hashing is less ambiguous than hex ASCII, but still does not
help the assembler emit bytes. If an address-related hash is ever useful, it
belongs only as proof metadata or a cache/fingerprint over a complete typed
record:

```text
hash(name + kind + bank + address + size + record-format)
```

That could help detect stale catalog records or changed exports. It does not
replace the stored fields the assembler needs:

```text
value_lo
value_hi
bank
kind
site_lo/site_hi
origin_lo/origin_hi
```

Rule that survived the musing:

```text
THE hashes canonical names/tokens.
ASM stores and patches exact addresses.
Record hashes may prove records, but do not stand in for addresses.
```

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
