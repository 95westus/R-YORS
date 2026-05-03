# R-YORS Hash Reference

R-YORS uses FNV-1a as the one hash algorithm for HIMON runtime/catalog/symbol
lookup. STR8 V0 does not use FNV; future catalog-owning STR8 may use the same
hash path.
and routine block identity.

FNV means Fowler/Noll/Vo. The external algorithm reference for the constants,
update order, and little-endian persistent storage convention is RFC 9923:
<https://www.rfc-editor.org/rfc/rfc9923.html>.

```text
[HASH:XXXXXXXX]  32-bit FNV-1a routine/catalog/symbol hash
```

FNV-1a is current, not future-only. It is already used by Himonia-F command
dispatch and is the intended lookup hash for catalogs, symbols, commands,
routines, fixups, and routine block comments.

`[HASH:XXXXXXXX]` is the 8-hex-digit routine header hash written in `; ROUTINE:`
lines:

` ; ROUTINE: SOME_ROUTINE  [HASH:12345678] `

That value is FNV-1a over the canonical uppercase routine name.

## FNV-1a Catalog Hash

FNV-1a is:

```text
size:       32 bit
algorithm:  FNV-1a
storage:    hash0,hash1,hash2,hash3 low byte through high byte
owner:      Himonia-F/HIMON command, catalog, symbol, and fixup lookup
```

Example:

```text
SYS_WRITE_CHAR -> $49023C1B -> stored 1B,3C,02,49
```

Current Himonia-F command records use this proving shape:

```text
'F','N',('V'|$80),hash0,hash1,hash2,hash3,kind,entry...
```

A compact future catalog table keeps FNV-1a but can replace the 3-byte
signature with one `F`/`N`/`V` width-layout byte when the table format already
implies FNV-1a. See [HASH_MAP.md](./HASH_MAP.md).

Routine block comments may include both fields:

```text
; ROUTINE: SYS_WRITE_CHAR  [HASH:49023C1B]
; FNV1A_LE: 1B,3C,02,49
```

The first line carries the canonical hash. A following `FNV1A_LE` line is only
an optional storage reminder for catalog records.

## Variable-Width Stored Hash Proposal

HIMON can keep 32-bit FNV-1a as the canonical name hash while allowing compact
tables to store only 1, 2, or 4 bytes of lookup key. This is a storage-width
choice, not a second hash algorithm.

Derive narrower keys by folding the 32-bit FNV-1a value:

```text
hash8  = (h32 xor (h32 >> 8) xor (h32 >> 16) xor (h32 >> 24)) & $FF
hash16 = (h32 xor (h32 >> 16)) & $FFFF
hash32 = h32
```

Preferred first shape:

```text
table header:
  'F'  entries store hash0..3
  'N'  entries store folded hash16
  'V'  entries store folded hash8

entries:
  hash bytes
  routine address or payload pointer
```

The table builder should choose the smallest width that is unambiguous for that
lookup context:

```text
try 'V'  1-byte folded hashes
if any collision exists, try 'N'  2-byte folded hashes
if any collision exists, use 'F'  4-byte FNV-1a
```

Small private tables may use 1-byte hashes. Larger shared tables may start at
2 bytes. Public, cross-bank, writable, or exported catalog boundaries should
keep 4 bytes unless the record also carries enough text or metadata to prove
identity.

Per-entry or per-bucket widening is possible later:

```text
1-byte normal entry
escape/flag + 'N' + 2-byte hash when the 8-bit key collides
escape/flag + 'F' + 4-byte hash when the 16-bit key collides
```

That form should be accepted only when the saved bytes beat the cost of the
escape markers and extra scanner code. Per-table width is the smaller first
implementation.

Collision handling belongs at build/record-generation time. HIMON should not
guess between ambiguous hash-only records at runtime. If two records with the
same stored hash can be live in one lookup context, either widen the table or
carry proof text.

Variable-width hashes also hide symbol names from casual ROM inspection, but
they are not security. FNV-1a is public and unsalted, so a guessed name can be
hashed and compared.

## Catalog Scan Field Notes

This section captures working subsystem notes for compact catalog discovery,
scan-window selectors, variable-width hash storage, and flash-safe commit
markers.

The core question is not "can a signature be one byte?" The core question is
"what is the scanner allowed to assume before it reads that byte?"

Smallest reasonable signature size depends on scan scope:

```text
known table/block       0 bytes per entry, 1 byte per table
known catalog region    1 byte per record can be okay
arbitrary ROM scan      2-3 byte signature minimum
```

### Design Questions And Working Answers

Q: What is the smallest reasonable signature?

A: It depends on scan scope. If the scanner is already inside a known table,
the table header can carry the proof and entries can have no signature at all.
If the scanner is searching a known catalog region, one binary control byte may
be enough per record. If the scanner is searching arbitrary memory, use a
stronger block proof such as `RC`, and keep `FNV` as a readable bring-up/proving
form when the extra byte is worth it.

Q: What does "known" mean if STR8 or HIMON can scan different places?

A: Known can mean "declared scan window" rather than "one hard-coded address."
The caller can give an explicit `start,end` or `start,+length`, or use a compact
4K selector. The selector says where to look. It does not prove that a record is
there.

Q: Can RAM be scanned too?

A: Yes. The `$0` through `$F` selectors name full 4K CPU-visible windows, not
just ROM windows. On the current map, `$0-$6` are RAM, `$7` is mixed RAM/I/O,
and `$8-$F` are flash. RAM scans are useful for session catalogs, staged
records, and typed dump descriptors, but they are noisy and must still require
record proof.

Q: What is special about selector `$7`?

A: `$7` spans `$7000-$7FFF`, but only `$7000-$7EFF` is RAM. `$7F00-$7FFF` is
I/O. A scanner should not casually read that I/O range as if it were ordinary
memory. Split the range at `$7F00`, or use an I/O-aware scan policy.

Q: If the selector becomes a byte, can the high nibble do work?

A: Yes. Keep the low nibble as the 4K window selector and use the high nibble
for address-space/source selection:

```text
%sssswwww

ssss  address space, source bank, RAM/flash view, or extended selector
wwww  4K window selector, $0-$F
```

Do not use this selector byte for record kind, hash width, or commit state.
Those belong to the `RCAT`/`RREC` layout/control byte. The selector answers
"where"; the record control byte answers "what and how."

Q: Why is the commit bit active low?

A: Erased flash is `$FF`, so erased bytes must not look live. Clearing bit 7
from `1` to `0` after the payload verifies gives an append-only commit latch
that works with flash's normal `1 -> 0` programming rule.

Q: Can a flash catalog record supersede a ROM command?

A: Yes. The ROM command remains physically present. Lookup collects matching
ROM and flash candidates, discards invalid/draft/dead records, then applies a
generation/version/provider policy. The newer committed flash `RREC` can win
without mutating ROM.

Q: Can THE make memory display itself readably?

A: Yes. A THE/catalog descriptor can say that a memory range is an `RCAT`,
`RREC`, string, word table, vector table, fixup table, routine table, or typed
dump region. HIMON can render that range semantically and fall back to raw
hex/ASCII when no descriptor exists.

If HIMON is already inside a known table, entries do not need to say `FNV` over
and over. The table header can say what the entries are. In that case a single
layout byte, or no per-entry signature at all, is reasonable.

If HIMON is scanning a known catalog region, a one-byte record control field can
work because the address range itself is part of the proof. A false positive is
still possible, but the scanner can require sane length, kind, bounds, and
commit fields nearby.

If HIMON is scanning arbitrary ROM, one byte is too weak. Normal code and data
will eventually contain every possible byte value. A two-byte block signature is
the smallest comfortable proof, and a three-byte text signature such as `FNV`
is still useful during bring-up because it is easy to spot in a hex dump.

The scan address does not have to be fixed forever. "Known" can mean a declared
window, not a hard-coded address. STR8 or HIMON may be told to scan one or more
memory/catalog windows. The target may be RAM, ROM, flash, or a banked view,
depending on the active address space.

Current CPU-visible memory map:

```text
$0000-$7EFF   RAM
$7F00-$7FFF   I/O
$8000-$FFFF   flash
```

Examples:

```text
$0000-$0FFF   low 4K RAM/zero-page/stack-visible window
$F000-$FFFF   physical top erase sector
$F800-$FFFF   selected/proposed STR8 protected window
$8000-$FFFF   whole 32K flash/ROM bank image
$C000-$CFFF   one high-nibble 4K window
```

Those windows can be represented explicitly:

```text
start,end
start,+length
bank,start,end
bank,start,+length
```

Or compactly when the unit is one full 4K high-nibble window:

```text
$0  means $0000-$0FFF
$1  means $1000-$1FFF
$2  means $2000-$2FFF
...
$6  means $6000-$6FFF
$7  means $7000-$7FFF
$8  means $8000-$8FFF
$F  means $F000-$FFFF
```

On the current map:

```text
$0-$6  clean RAM windows
$7     mixed window: $7000-$7EFF RAM, $7F00-$7FFF I/O
$8-$F  flash windows
```

That means `$7` is valid to scan, but it is a special case. Catalog scanners
should not casually probe I/O registers as if they were normal memory. If a scan
window touches `$7F00-$7FFF`, the caller should either split the range at
`$7F00` or use an I/O-aware scan policy.

If the selector becomes a full byte later, keep the low nibble as the 4K window
selector and use the high nibble for the memory view/source:

```text
%sssswwww

ssss  address space, source bank, RAM/flash view, or extended selector
wwww  4K window selector, $0-$F
```

That compact form is a scan-window selector, not a record signature. It tells
the scanner where to look. The record or block found there still needs its own
proof, such as `RC` plus a valid layout/control byte, bounds, and commit state.

Scanning RAM is valid, but it should be treated like any other noisy memory
scan. A `$0` scan is especially broad because it includes zero page, stack, and
whatever temporary data is live. A catalog-aware RAM object should still carry
the same kind of signature, bounds, layout/control byte, and commit state as a
ROM or flash object.

This keeps the distinction clean:

```text
scan window        where to search
RC signature       this looks like an R-YORS catalog container
control byte       this container/record is committed and how to parse it
hash bytes         this entry names the candidate
name/proof text    this candidate is exactly the intended name, if needed
```

Long term, `FNV` should be treated as a proving/debug signature, not the compact
record shape. FNV-1a is the only runtime/catalog hash algorithm, so catalog
records do not need to spend bytes naming the algorithm again.

The compact project-owned signature should describe the container, not the
algorithm. Preferred two-byte block/table signature:

```text
'R','C'   R-YORS Catalog
```

Why `RC`:

```text
project/system related, not author related
readable in hex dumps
not tied only to FNV
usable for commands, routines, symbols, strings, modules, and fixups
does not steal F/N/V from the hash-width layout idea
```

Other readable candidates remain possible:

```text
'R','H'   R-YORS Hash
'R','R'   R-YORS Record / runtime record
'H','M'   HIMON
'C','T'   catalog table
```

But `RC` is the clean first choice because the catalog is the larger container.
Hash tables are one thing an `RCAT` can contain; they are not the whole system.

### Binary Layout Control Byte

After the `RC` signature, use a binary layout/control byte. It can carry more
meaning than a text marker:

```text
%0wwkkkvv  committed compact record/table
%11111111  erased flash
```

Suggested fields:

```text
bit 7     committed/live flag, active low
bits 6-5  hash width
bits 4-2  record/table kind
bits 1-0  layout version
```

Hash width:

```text
00  no hash / local id / direct record
01  V layout: 1-byte folded hash8
10  N layout: 2-byte folded hash16
11  F layout: 4-byte full FNV-1a
```

Kind values are intentionally local to the layout version. A first useful set
could be:

```text
000  command table or command record
001  routine table or routine record
010  symbol table or symbol record
011  fixup table or fixup record
100  string/text table or string record
101  module/export table or module/export record
110  memory range / typed dump descriptor
111  reserved or extended kind
```

The `vv` bits are for parsing the record or table layout. They are not routine
ABI version, catalog block generation, or "newest provider" selection. Those
are separate fields or policies.

### Why Bit 7 Is Active Low

Flash normally erases to:

```text
$FF = %11111111
```

Programming flash can usually change bits only from `1` to `0` until the sector
is erased again. Therefore erased flash must not look live. If bit 7 means
"committed" when it is `1`, then `$FF` looks committed by default, which is
the wrong failure mode.

So the commit bit should be active low:

```text
bit 7 = 1   erased, draft, ignored, or not yet committed
bit 7 = 0   committed enough to parse
```

Safe write flow:

```text
1. Write payload/body bytes first.
2. Write metadata and control fields with bit 7 still set.
3. Verify the payload and metadata.
4. Clear bit 7 in the control byte last.
```

That final `1 -> 0` write is the commit latch. If power fails before the latch,
the scanner ignores the record or block. If power fails after the latch, the
scanner should have enough length, bounds, kind, and optional check fields to
decide whether the committed object is usable.

Do not design the control byte as a normal rewritable status field. It is a
flash latch. Every state transition must be possible by clearing bits only.

### RCAT And RREC Shape

An `RCAT` block can use the two-byte signature plus one layout/control byte:

```text
RCAT block:
  'R','C'
  control byte: %0wwkkkvv when committed
  block length, count, or scan limit
  optional generation/check fields
  RREC records and optional pools
```

Inside a committed `RCAT`, an `RREC` can use the same active-low commit idea:

```text
RREC record:
  control byte: %0wwkkkvv when committed
  hash bytes selected by ww
  value/address/bank/kind/flags
  optional name proof, payload pointer, or inline payload
```

This gives two levels of safety:

```text
RCAT committed?   Is this catalog block valid to scan?
RREC committed?   Is this individual record valid to use?
```

A scanner can then be simple:

```text
1. Find 'R','C' in a catalog-capable region.
2. Read the control byte.
3. If bit 7 is 1, ignore the block.
4. If bit 7 is 0, decode ww/kkk/vv and scan records.
5. For each RREC, ignore records whose bit 7 is still 1.
```

This is also the path for superseding ROM commands without rewriting ROM. ROM
bytes remain physically present, but a newer flash `RREC` can export the same
command name/hash/kind with a newer generation, ABI, or provider policy.

Lookup should therefore collect candidates, not stop at the first match:

```text
lookup command token
  compute canonical 32-bit FNV-1a
  scan ROM catalog records
  scan committed flash RCAT blocks
  discard erased, draft, dead, or invalid records
  collect matching hash/name/kind candidates
  apply generation/version/provider policy
  choose the best live candidate
```

This does not delete or mutate the old ROM command. It supersedes it by lookup
policy. If a stale/dead bit can be safely programmed in flash, it is a hint. It
must not be required for correctness because ROM records may be immutable and a
failed update may leave multiple candidates visible.

### THE Display Payoff

Once a memory range can be represented by THE/catalog records, HIMON does not
have to display it as anonymous bytes. A dump can check whether an `RCAT`,
`RREC`, string table, vector table, fixup table, or typed memory descriptor
covers the address.

Raw memory:

```text
2000: 48 45 4C 4C CF 34 12
```

THE-described memory:

```text
$2000  HBSTR  "HELLO"
$2005  WORD   $1234
```

An `RCAT` descriptor can make a table readable:

```text
$F800  RCAT layout=N kind=routine count=...
$F804  hash16=$42C1 -> STR8_INIT
$F808  hash16=$8910 -> SYS_WRITE_CHAR
```

If no descriptor exists, HIMON falls back to ordinary hex/ASCII dump. That keeps
the monitor useful before the catalog is complete and richer once records exist.

### How Not To Use This

Do not use a one-byte signature for arbitrary ROM discovery. It will false
match normal code and data.

Do not store `FNV` in every compact entry once the enclosing table already
defines the hash family. Spend the bytes on payload, proof text, or checks.

Do not make `F`, `N`, and `V` mean both "hash width" and "format generation."
They are layout-width names in this proposal:

```text
F  full 4-byte FNV-1a
N  narrow 2-byte folded FNV-1a
V  very narrow 1-byte folded FNV-1a
```

Do not treat hash width as security. Narrower hashes can obscure names from
casual ROM browsing, but guessed names can still be hashed and compared.

Do not let runtime code guess between ambiguous hash-only records. The builder
must widen the table, or the record must carry proof text.

Do not make erased `$FF` look live. Active-low commit bits are not decoration;
they are how append-only flash records avoid half-written objects becoming
visible.

## How HASH Is Generated

For each routine header, the generator builds a canonical payload:

1. Routine name from the header
2. Uppercase ASCII
3. If a legacy header lists multiple names with `/`, the first name is the
   primary hash identity

Payload example:

`SYS_WRITE_CHAR`

Then it computes 32-bit FNV-1a:

```text
offset basis: $811C9DC5
prime:        $01000193
step:         hash = (hash xor byte) * prime mod 2^32
```

The result is formatted as uppercase 8-digit hex and written as
`[HASH:XXXXXXXX]`.

## Refresh HASH Across The Repo

From `SRC/`:

`make routine-hash-comments`

or directly:

`powershell -NoProfile -ExecutionPolicy Bypass -File tools/gen_routine_hash_comments.ps1 -Src .`

The generator updates every `; ROUTINE:` header under:

- `SRC/STASH`
- `SRC/TEST`
- `SRC/SESH`

## Collision Check

The generator detects duplicate `HASH` values across all scanned routine headers.

- It reports each collision group with file path, line, and routine name.
- By default it exits non-zero when any collision is found (`-FailOnCollision $true`).
- To report-only (no fail), run with:

`powershell -NoProfile -ExecutionPolicy Bypass -File tools/gen_routine_hash_comments.ps1 -Src . -FailOnCollision $false`
