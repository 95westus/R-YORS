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

## Far-Out Rating Note: Compact Debug Stops

Bucket: `good far out`

Idea: report HIMON-owned synthetic step/breakpoint traps as compact `@hhhh`
state lines instead of ordinary-looking `BRK 00 PC=hhhh` stops.

Far-out rating: `1/10`.

Why: this only classifies a trap HIMON already knows it planted. It reduces
terminal noise and keeps real program `BRK xx` signatures visually distinct.
Because the benefit, owner, cost, and implementation shape are clear, the
settled decision lives in `DOC/GUIDES/DECISIONS.md` and the operating behavior
lives in `DOC/GUIDES/RTFM-himon.md`.

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

## Good Far Out: STR8 Semantic Flash Map Overlay

Bucket: `good far out`

The first `M` command should stay physical and terse, but the same display
shape can become a future semantic overlay once STR8 has catalog/hash
recognizers.

Current conservative shape:

```text
FLASH MAP
BANK_0   ++--++--
BANK_1   --------
BANK_2   --------
BOOT     ----+HH8
```

The left label should probably be fixed width, likely eight characters. That
keeps the output cheap now while allowing future labels to come from role names
or RCAT/catalog names:

```text
DATA     ++--++--
TOOLS    --------
SCRATCH  --------
BOOT     R-Z+HH-8
```

The eight status positions still mean sectors `8 9 A B C D E F`. The semantic
letters are only an overlay:

```text
-  erased/free
+  used, not yet classified
R  R-YORS system area
Z  RCAT/RREC/hash metadata zone
H  HIMON
8  STR8
```

A later detail display could attach CBI-style provenance to the classified
map:

```text
BOOT     R-Z+HH-8
2026
         05
                13
                   17:43Z WLP2 HIMON debounce vector install.
                   16:20Z WLP2 BOOT recovered from bank 0 image.
```

This is where hash-joint can go deeper. The visible map remains a tiny
sector-screen, while RCAT/RREC records underneath can explain who owns each
sector, what hash named it, what installed it, and which update/recovery event
last touched it.

## Good Far Out: Uncataloged Code Placement

Bucket: `good far out`

Code that has no live `RREC` needs a deliberate home. It should not be scattered
through general growth flash just because the bytes assemble and run.

There are at least three different states:

```text
headered source code      has ROUTINE/metadata comments in source
uncataloged runtime code  has no live RREC describing it
cataloged runtime code    has one or more RREC exports in an RCAT
```

Headered source code can be readable to humans and generators, but that is not
the same as a runtime catalog contract. If bytes have no `RREC`, normal catalog
lookup, bury, supersede, and condense logic cannot prove what they are or where
they are safe to move. That makes them sticky: the system must treat their
placement as intentional until a real descriptor exists.

Possible placement rule:

```text
No RREC -> place only in explicit static lanes:
  high ROM/flash
  protected/system flash
  fixed proof RAM
  a documented staging range
```

Do not let uncataloged code become anonymous filler inside future RCAT/RBODY
storage. Once the code gains an `RREC`, its record can say whether it is core
system, debug, user-loaded, app/session body, hybrid RAM overlay, or another
typed runtime thing. Before that, placement policy has to carry the safety
burden.

The debug case is a good example. Debug may be optional and not yet burned into
the permanent ROM image. If a user loads a RAM debug body and HIMON installs or
advertises an `RREC` for it, then the loaded body becomes part of the active
system surface for that session or provider policy. Without the `RREC`, it is
only a loaded proof/tool at a known address.

## Good Far Out: STR8 RAM-Mediated Sector Pairing

Bucket: `good far out`

A future STR8 restore/update tool may want to compare a live boot-bank sector
with a matching sector from another bank without treating both flash sectors as
live mapped memory. The safer model is RAM-mediated sector pairing:

```text
B3:D  live boot-bank sector
B1:D  recovery/source sector
RAM   compare buffer / planned result
```

This is not for ordinary execution. It is for restore, compare, merge,
recovery, and operator-visible update planning:

```text
select bank 3
copy sector D -> RAM_LIVE

select bank 1
copy sector D -> RAM_SRC

compare RAM_LIVE/RAM_SRC
build RAM_PLAN
show operator result
erase/program only after confirmation
```

Possible display language:

```text
PAIR B3:D B1:D
LIVE +
SRC  +
DIFF *
PLAN =
```

or tighter:

```text
D B3:+ B1:+ DIFF:* PLAN:=
```

This should use RAM aggressively. Flash should stay boring until the final
committed write. Later hash records could make the comparison richer:

```text
B3:D  HASH 12345678  HIMON-live
B1:D  HASH 9ABCDEF0  HIMON-backup
PLAN  KEEP vectors, KEEP STR8 cfg, WRITE HIMON body
```

The open question is whether this becomes a STR8 command, an update-planner
subroutine, or only a diagnostic/detail view behind the normal restore flow.

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

## Word Find: ROR-bar

Bucket: `word find`

`ROR-bar` is the plain-text spelling for `ROR` with a repeating bar over it.
The bar means "repeating", so the phrase can mean a recurring odd research
idea, a repeated rotate, or a not-yet-serious thought that keeps coming back.

Markdown can carry the mark a few ways:

```text
 ___
ROR
```

Portable source spelling:

```text
ROR-bar
```

Math-capable Markdown spelling:

```text
$\overline{\mathrm{ROR}}$
```

HTML entity spelling, if a renderer handles combining marks:

```text
R&#772;O&#772;R&#772;
```

Avoid relying on inline HTML style attributes for this. Some Markdown renderers
strip `style=...`, and this mark should survive as plain text anyway.

Working meaning:

```text
ROR-bar
  recurring odd research
  repeated rotate
  wild/crazy idea that has returned often enough to name
```

## Good Far Out: BRK xx Internal Assertions

Bucket: `good far out`

HIMON already captures BRK context. That makes signed `BRK xx` opcodes a good
future debug language for conditions that should be impossible if routine
contracts are being honored.

Do not use this for normal operator mistakes. Bad input should print a normal
message and return to the prompt. Use `BRK xx` for internal contract failures:

```text
caller ignored required carry/status result
parser success left an impossible pointer or range
hash dispatch matched a command record with an invalid kind
context resume is about to build an invalid RTI frame
flash or bank code returned with bank 3 not restored
```

Possible signature families:

```text
BRK $2x   parser/range invariant
BRK $3x   command dispatch invariant
BRK $4x   trap/context invariant
BRK $5x   flash/bank invariant
```

This remains a wild/crazy debugging note until there is a small, documented
signature table and an agreed rule for where assertions are allowed.

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
