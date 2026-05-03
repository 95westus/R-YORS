# R-YORS Hash Map

This file separates the different hash ideas so they do not collapse into one
muddy concept.

## Hash Families

```text
ROUTINE HASH
  size: 32 bit
  form: [HASH:XXXXXXXX]
  algorithm: FNV-1a
  owner: docs/build tooling
  purpose: routine block identity and future symbol lookup
  guide: HASH.md

Runtime FNV-1a
  size: 32 bit
  form: four stored bytes
  owner: Himonia-F command dispatch
  purpose: command token lookup
  source: SRC/TEST/apps/himon/himon.asm
  symbol guide: SYMBOL_XREF.md

Assembler symbol hash
  size: 32 bit
  algorithm: FNV-1a
  owner: hashed assembler/catalog
  purpose: label, routine, command, and fixup lookup
  guide: HASHED_ASM.md

Catalog text proof
  size: variable text, raw or compressed
  owner: catalog/HIMON/hashed assembler
  purpose: collision proof, listings, onboard linking
  guide: HASHED_ASM.md, SYMBOL_XREF.md

Variable-width stored hash
  size: 1, 2, or 4 stored bytes
  algorithm: folded FNV-1a from the canonical 32-bit value
  owner: compact HIMON/catalog tables
  purpose: save ROM space in lookup contexts where the builder can prove
           the narrower key is unambiguous
  guide: HASH.md
```

## Rule

```text
FNV-1a is the one catalog/runtime symbol hash for HIMON, the catalog, and the
assembler path. STR8 V0 does not use FNV; future STR8-N/STRAIGHTEN may
participate in the same hash path without requiring catalog ownership.
records do not carry a hash-algorithm tag.
hash narrows candidates
stored text proves identity
record kind/bank/address tells how to use the match
```

Do not treat a hash as the whole identity once the catalog becomes writable or
loadable from user-built modules.

## Variable-Width Hash Storage

This is a compact storage proposal layered on top of the one FNV-1a policy.
The canonical name hash remains 32-bit FNV-1a. A table may store a folded
1-byte, 2-byte, or full 4-byte key when that width is enough for its own lookup
context.

```text
hash8   folded from hash0..3
hash16  folded from hash0..3
hash32  stored hash0..3, low byte first
```

F/N/V identifies the hash-width table layout:

```text
'F'  full FNV-1a      entries store hash0..3
'N'  narrow FNV-1a    entries store folded hash16
'V'  very narrow      entries store folded hash8
```

The safe rule is builder-selected width:

```text
small/private table       may use 1 byte
medium shared table       may use 2 bytes
global/exported catalog   usually keeps 4 bytes
```

The builder must reject or widen a table when a selected width collides. Runtime
lookup can then stay simple: load the table width, compare that many hash bytes,
and use the payload. Runtime collision management is not part of the proposal.

This is separate from short local handles. A folded hash still discovers a name
inside a lookup context. A local handle or index reuses something already found.

## FNV Layout Marker Policy

FNV-1a is the only runtime/catalog symbol hash, so the record does not need to
store the text `FNV` or an algorithm id once the scanner is already inside a
known FNV catalog/table region.

The current compact proposal uses `F/N/V` as hash-width table layouts, not as
record-format generation markers:

```text
'F'  4-byte full FNV-1a records
'N'  2-byte narrow folded FNV-1a records
'V'  1-byte very narrow folded FNV-1a records
```

`FNV` names the Fowler/Noll/Vo hash family. RFC 9923 is the outside reference
for the FNV-1a algorithm. R-YORS `F/N/V` table bytes are storage-layout markers
layered on top of that one hash, not alternate algorithms.

Current Himonia-F still uses the older proving-record shape:

```text
'F','N',('V'|$80),hash0,hash1,hash2,hash3,kind,entry...
```

In that current shape, `('V'|$80)` is the high-bit-terminated third byte of the
literal `FNV` signature. The `kind` byte follows the four hash bytes:

```text
$00  executable entry follows immediately after kind
```

The future compact record should collapse the old per-record signature into one
layout byte, or move that byte into a table/block header:

```text
'F',hash0,hash1,hash2,hash3,value_lo,value_hi,bank,kind,flags,...
'N',hash16_lo,hash16_hi,value_lo,value_hi,bank,kind,flags,...
'V',hash8,value_lo,value_hi,bank,kind,flags,...
```

As a per-table header:

```text
'F'  entries store hash0..3
'N'  entries store folded hash16
'V'  entries store folded hash8
```

Storage savings:

```text
3-byte "FNV" per record -> 1-byte table layout saves almost 3 bytes per record
'F' table                  keeps 4 hash bytes per entry
'N' table                  saves 2 hash bytes per entry
'V' table                  saves 3 hash bytes per entry
```

Scale examples:

```text
100 records  in an 'N' table = about 200 hash bytes saved
256 records  in a 'V' table  = about 768 hash bytes saved
1000 records in an 'N' table = about 2000 hash bytes saved
```

Tradeoff: a single-byte layout marker is weaker when scanning arbitrary flash
for records. The HIMON/catalog scanner can handle that by only scanning known
catalog regions, requiring a valid kind/flags/check byte nearby, or using a
larger catalog block header while keeping each record tiny. STR8 V0 does not
scan FNV catalog records.

## Catalog Version Selection

Do not let one byte mean every kind of version. The catalog needs separate
version ideas:

```text
record format version   how to parse this RREC layout
catalog block version   how to parse/discover the enclosing RCAT block
routine ABI version     what contract the routine/data/provider offers
record generation       which live record supersedes another record
```

The compact layout byte belongs to record parsing and hash-width selection. It
should not decide whether `ROUTINE` v1 or `ROUTINE` v2 is the better callable
provider.

Catalog lookup should become candidate selection, not first-match:

```text
lookup(name, kind, version policy)
  scan valid catalog regions
  collect matching hash/name/kind records
  discard stale/dead/invalid records
  apply version policy
  choose the best live candidate
```

Useful version policies:

```text
exact v1       accept only ABI v1
v1+            accept the newest compatible ABI at least v1
latest         accept the newest live compatible provider
```

So if ROM contains both `ROUTINE` v1 and `ROUTINE` v2, v1 does not need to be
physically erased or marked dead. Normal HIMON lookup can choose v2 under
`latest` or `v1+` policy. STR8 V0 stays out of this FNV/version-selection path
and uses fixed whole-image recovery choices instead.

Append-only flash update should work even when old records cannot be changed:

```text
old v1 record remains live
new v2 record is appended with same hash/name/kind and higher ABI/generation
resolver chooses v2 for compatible lookup
later condense may drop v1 if policy allows
```

If a stale bit can be programmed safely, it is a useful hint. The resolver must
not depend on it, because ROM bytes may be immutable and a failed update may
leave both records visible.

## Flash-Monotonic Versions

A record or block state byte can move through a 1-to-0 chain without erase:

```text
$FF -> $FE -> $FC -> $F8 -> $F0 -> $E0 -> $C0 -> $80 -> $00
```

That gives nine readable states and eight updates after erase. It works for
lifecycle state, transaction progress, or a tiny local generation marker. It is
not arbitrary rewritable versioning because the byte can only move downward.

Use this for questions like:

```text
erased?
written?
verified?
committed?
superseded?
dead?
```

When the chain is exhausted or the block has too much dead material, HIMON or a
non-STR8 maintenance tool can condense: copy live records to RAM or another
block, erase the old sector, then rewrite a compact block with fresh `$FF` state
bytes.

## Catalog Blocks

Catalog records do not all have to live in one address range. The system can
use multiple catalog blocks, for example one near the selected STR8 protected
window and another in a growth bank:

```text
$F000-$FFFF  physical top erase sector; selected STR8 protected window lives here
$B0xx block  growth/user/module catalog, more writable and replaceable
```

A block header gives the scanner a stronger proof than a one-byte record
signature on every arbitrary flash address:

```text
block_sig
block_state
block_base_or_bank
block_seq_or_generation
record_count_or_scan_limit
string_pool_offset
checksum_or_commit
```

The scan target itself can be variable and declared. A scanner may receive an
explicit range:

```text
start,end
start,+length
bank,start,end
bank,start,+length
```

Or a compact high-window selector when the unit is a full 4K memory window:

```text
$0  scan $0000-$0FFF
$1  scan $1000-$1FFF
$2  scan $2000-$2FFF
...
$6  scan $6000-$6FFF
$7  scan $7000-$7FFF
$8  scan $8000-$8FFF
$F  scan $F000-$FFFF
```

Current CPU-visible map:

```text
$0-$6  RAM
$7     mixed: $7000-$7EFF RAM, $7F00-$7FFF I/O
$8-$F  flash
```

If the selector grows to a byte, keep the low nibble as the 4K window and use
the high nibble for address-space/source selection:

```text
%sssswwww
```

The selector is not the record proof. It only limits where to search. A live
catalog block still needs its `RC`-style signature, bounds, layout/control byte,
and commit state.

The target window may be RAM, ROM, flash, or a banked view. RAM scans are valid,
but they are noisy unless the object in RAM carries the same catalog proof
fields as a persistent block. Scanners should avoid touching `$7F00-$7FFF`
unless the selected policy is I/O-aware.

The practical rule is:

```text
scan known blocks first
trust committed blocks
prefer newest live record when duplicate hashes/names exist
condense stale blocks later
```

## Runtime Command Hash

Himonia-F command lookup is:

```text
input token -> canonical/HBSTR-aware FNV-1a -> record scan -> entry address
```

The `#` command belongs in this world. It can show the hash path and eventually
show collision candidates from the master catalog.

## Assembler Symbol Hash

Hashed ASM uses the same mental shape:

```text
label text -> canonical text -> hash -> symbol record -> value
```

For a forward label:

```text
operand text -> hash -> no current symbol -> create fixup
later label -> same hash -> patch recorded site
```

## Catalog Hash Record

Mini theory:

```text
canonical name/text -> FNV-1a hash -> typed catalog record -> value/payload
```

The hash is only the compact lookup key. The surrounding record gives the match
meaning. A future R-YORS catalog can use the same hash path for several kinds of
things:

```text
command       hash -> executable entry point
routine       hash -> callable service address plus ABI notes
symbol        hash -> address/value/bank
data element  hash -> address, length, and data type
constant      hash -> byte, word, long, or flag value
memory range  hash -> base, size, bank, and access flags
packet        hash -> parser, handler, or schema record
module        hash -> flash block plus entry/export table
fixup         hash -> unresolved reference waiting for definition
string        hash -> CSTR, HBSTR, raw, or packed-text address
device        hash -> driver vector table or capability record
alias         hash -> typed redirect to another hash plus adapter/policy
```

This keeps the catalog closer to a small typed name/value system than to a
command table. Early builds can keep the record scanner simple and hash-only
where space is tight; later writable catalogs should carry proof text, type
flags, and collision handling.

An `RCAT` is a runtime catalog dataset, not just a table. It may hold `RREC`
records, string pools, indexes, and links to `RBODY` payloads spread across RAM
or flash. An `RREC` is a typed runtime record: it names, classifies, and points
to an `RBODY`, or carries a small inline value itself. An `RBODY` is the actual
runtime body: executable code, data bytes, string text, packet shape, module
image, or another payload.

R-YORS names the dynamic path **catalog linking**. A catalog-linked body is not
a DLL and not a `.so`; it is an `RBODY` plus one or more `RREC` exports visible
through an `RCAT`. The assembler can emit unresolved references as `RFIX`
records, then later resolve those fixups when a matching live `RREC` appears.

Possible path:

```text
assemble RBODY -> create RFIX -> verify body -> export RREC into RCAT
later code -> import by hash/name -> resolve RFIX/RLNK -> call entry or use value
```

Working record shape:

```text
record kind/signature
hash0..3
value_lo/value_hi
bank
kind
flags
size_or_extra
optional name length
optional raw or compressed name text
optional payload
```

`bank` matters because the record may live in a clean catalog area while the
routine/data body lives in a future growth/storage bank.

There is no per-record algorithm byte. The catalog format itself defines
`hash0..3` as FNV-1a.

## Hash-To-Hash Alias Records

An FNV lookup may resolve to a typed alias record that names another FNV hash.
This is allowed only when the record kind defines what the redirect means:

```text
hash("DB") -> directive_alias -> target hash("DC")
```

The alias is not a raw pointer from one hash to another. It must carry enough
policy to keep lookup inspectable:

```text
record kind     directive_alias, command_alias, symbol_alias, ...
target_hash0..3 FNV-1a of the real target name
adapter/id      optional parser or calling adapter
flags           exported, local, deprecated, compatibility, ...
```

For ASM directives, `DB $FF` cannot be treated as the same text as `DC X'FF'`.
The alias record can point `DB` to the `DC` handler, but an adapter still has to
parse the `DB` operand and emit the same bytes as the corresponding `DC` form.

Alias resolution must have a small depth limit and cycle detection:

```text
DB -> DC           ok
BYTE -> DB -> DC   ok if the limit allows it
DB -> BYTE -> DB   fail cycle
```

This keeps THE capable of compatibility names without turning the catalog into
an invisible chain of hash-only guesses.

Catalog records use 65C02 little-endian byte order:

```text
word      low byte, then high byte
long      byte0..3, least significant to most significant
hash0..3  FNV-1a low byte through high byte
```

So a displayed hash such as `$89ABCDEF` is stored as:

```text
hash0=$EF hash1=$CD hash2=$AB hash3=$89
```

## Hashes And Short Handles

Four-byte FNV hashes are worth their cost at catalog boundaries, where a name
must be found across modules, banks, sessions, or flash blocks. They are too
expensive to require for every small field, flag, short data element, or local
packet member.

Rule:

```text
hashes discover named things
short IDs, offsets, and indexes reuse known things
```

Use full FNV-1a records for public or cross-boundary names:

```text
commands
exported routines
symbols
modules
packet types
public data elements
cross-bank references
fixup targets
```

Use smaller local handles inside an already-known `RREC`, `RBODY`, or `RCAT`:

```text
1-byte kind/type       record class, scalar type, encoding family
1-byte local id        field or item inside one body/catalog scope
2-byte local index     string pool offset, record index, block-relative handle
direct offset/address  payload layout when relocation is not needed
```

A future `RIDX` can cache resolved records as short handles:

```text
first use:   name/hash -> RCAT scan -> RREC pointer
later use:   short id/index -> RREC pointer, entry, or value
```

That makes `RIDX` an accelerator, not the source of identity. Hashes remain the
stable discovery key; short handles are local conveniences for hot paths,
bytecode, packet fields, local imports, or RAM session symbol tables.

## Text Storage

Possible text encodings:

```text
raw_hb       high-bit-terminated string
raw_z        ASCIIZ string
pack_lo_5    5-bit restricted alphabet; candidate for 3-letter mnemonics
dict_small   later optional dictionary
pool_hb      offset to high-bit-terminated text in a block string pool
pool_z       offset to ASCIIZ text in a block string pool
pool_len     offset plus length in a block string pool
```

`pack_lo_5` is especially plausible for 3-letter assembler mnemonics:

```text
3 chars * 5 bits = 15 bits
one mnemonic fits in two bytes
```

That can reduce mnemonic table storage and may allow direct packed comparisons.
It is a candidate encoding, not a required general-purpose text format.

Compression rule:

```text
if compressed_size < raw_size:
  store compressed
else:
  store raw
```

Small strings are allowed to refuse compression. That keeps the decoder simple
and prevents the catalog from growing because of a clever format header.

An offset-only string reference can work if the target text is self-terminated
with high-bit or zero termination. That gives no true length in the record; the
decoder walks until the terminator. If speed matters later, a block-level string
index can cache offsets or lengths without changing the basic record.

## RBODY Compression

R-YORS should not use one compression format for every payload. Text names can
use PACK5/PACK6-style encodings or string pools. Binary `RBODY` payloads need a
different first codec.

The first binary-body codec direction is byte-aligned RLE:

```text
host compressor may be slow
65C02 decompressor must be small
decompression should be simple and streaming
raw storage remains the fallback
```

Runs of common fill bytes are important enough to reserve design space for
special cases:

```text
$00  zero-filled data/work areas
$20  spaces in text-like binary buffers
$FF  erased flash / blank image regions
```

Exact opcode ranges and run lengths are not committed yet. The format should
prefer a tiny decoder and good behavior for flash images over maximum
compression ratio.

## Collision Policy

Early built-ins can be hash-only when space is tight. Self-hosted exports should
carry enough text to prove identity on board.

Lookup policy:

```text
1. Scan by hash.
2. If one candidate and no proof required, accept.
3. If proof is required, compare stored text.
4. If multiple candidates match the same hash, list them.
5. If text is absent and collision exists, require qualified/manual choice.
```

This keeps the system usable before the catalog is fancy, but does not trap it
in unsafe hash-only linking forever.
