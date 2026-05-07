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

## Good Far Out: STR8 Future Flash Services

Bucket: `good far out`

Today STR8 should stay focused on bank select, clear check, erase, copy,
restore, and read-back verify. These related ideas are worth saving without
pulling them into the first RAM-resident S19 implementation:

```text
catalog-linked transients
copying routine packs from ROM/flash to RAM before dangerous operations
FLSH_IS_BANK_WRITEABLE
FLSH_CYCLE_COUNT
FLSH_SWAP
FLSH_WEAR_LEVEL_FIND_NEXT_ELIGIBLE
FLSH_BANK_NEEDS_LEVELING
flash options/config/identity storage
STR8-managed flash allocator or filesystem-like layer
EDU board LED alerts for erase/write/do-not-interrupt states
```

## Good Far Out: STR8 C Report Labels

Bucket: `good far out`

The condensed STR8 flash-sector report should be a two-line display with bank
labels separated from sector status:

```text
BANK0     BANK1     BANK2     BOOT
++--++--  --++--++  --------  ++++++++
```

The status grammar is stable: each eight-character group maps to 4K sectors
`8 9 A B C D E F`, meaning `$8000` through `$F000`; `-` means erased/unused
and all `$FF`, while `+` means used/not fully erased.

In time, another command or detail mode could reuse the same sector positions
for derived meaning:

```text
BOOT
----+HHS
```

Where `+` is used-but-unclassified, `H` is HIMON-like, and `S` is
STR8/top-sector boot material. The physical `+/-` report should remain the
cheap primitive; semantic labels can come from later recognizers.

The musing: the label line should not be conceptually tied only to bank
numbers. Bank 3 should indicate `BOOT`, because that is where reset boots from.
In the future, those labels could become role names or RCAT/catalog names:

```text
BASE      RECOV     HIMON     DATA
++--++--  --++--++  --------  ++++++++
```

That preserves the compact bench display while letting STR8/STRAIGHTEN grow
toward named banks or images later.

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
