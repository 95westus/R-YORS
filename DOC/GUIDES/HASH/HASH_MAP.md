# R-YORS Hash Map

This file separates the different hash ideas so they do not collapse into
one muddy concept.

Status: this map still documents the current FNV-1a implementation and older
compact-hash proposals. The intended compact runtime/catalog hash has shifted to
tableless CRC16 because it better fits the W65C02 time/space budget.

Use [GLOSSARY.md](../GLOSSARY.md) for the terminology contract. In this file,
FNV-1a is the current implemented hash algorithm, hash32/hash16/hash8 are older
stored result widths, `Record` means only the record format defined in the local
section, and THE means The Hash Environment.

Terminology note: `hash map` here means a guide map of hash concepts and
ownership. It does not mean a hash table implementation, and it does not promise
that every section is a renderable flowchart. When visual precision matters,
use `graph`, `flowchart`, or `chart` according to [GLOSSARY.md](../GLOSSARY.md).

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
  owner: HIMON command dispatch
  purpose: command token lookup
  source: HIMON/himon.asm
  symbol guide: SYMBOL_XREF.md

Compact CRC16 hash
  size: 16 bit
  algorithm: tableless CRC16, exact polynomial/record shape still to settle
  owner: future HIMON/catalog/hashed assembler
  purpose: compact runtime/catalog/symbol lookup
  guide: HASH.md, QCC_HASH.md

Assembler symbol hash
  size: compact hash, current notes may still show 32-bit FNV examples
  algorithm: intended tableless CRC16
  owner: hashed assembler/catalog
  purpose: label, routine, command, and fixup lookup
  guide: HASHED_ASM.md

Catalog text proof
  size: variable text, raw or compressed
  owner: catalog/HIMON/hashed assembler
  purpose: collision proof, listings, onboard linking
  guide: HASHED_ASM.md, SYMBOL_XREF.md

Legacy variable-width FNV
  size: 1, 2, or 4 stored bytes
  algorithm: folded FNV-1a from the canonical 32-bit value
  owner: compact HIMON/catalog tables
  purpose: save ROM space in lookup contexts where the builder can prove
           the narrower hash is unambiguous
  guide: HASH.md
```

## Rule

```text
FNV-1a is current implementation/history, not the final universal hash.
tableless CRC16 is the intended compact runtime/catalog hash.
STR8 V0 does not use either hash for recovery decisions.
records should not carry a hash-algorithm tag unless multi-algorithm catalogs
are explicitly adopted.
hash narrows candidates
stored text proves identity
record kind/bank/address tells how to use the match
```

Do not treat a hash as the whole identity once the catalog becomes writable or
loadable from user-built modules.

## Legacy Variable-Width FNV Storage

This is an older compact storage proposal layered on top of the FNV-1a policy.
It remains useful for understanding current helper code and generated maps. The
current preferred compact hash direction is tableless CRC16.

```text
hash8   folded from hash0..3
hash16  folded from hash0..3
hash32  stored hash0..3, low byte first
```

The folded widths are produced by reusable helper routines that accept a
pointer to a completed 32-bit FNV-1a result. They are not tied to HBSTR, CSTR,
PSTR, or any other source text format:

```text
FNV1A_FOLD8_XY_A       X/Y=hash0..3 ptr -> A=hash8, C=1
FNV1A_FOLD16_XY_A8     X/Y=hash0..3 ptr -> X=hash16_lo, Y=hash16_hi, A=hash8, C=1
FNV1A_FOLD32_XY        X/Y=hash0..3 ptr -> X/Y unchanged, C=1
```

These are routines-of-routines helpers. They do not replace or modify the
normal 32-bit FNV-1a engine. A caller first computes the canonical hash through
the right source-specific path, then calls the fold helper needed by the table
width.

Hash width should be a compact control field, not literal `FNV` bytes:

```text
ww=01  very narrow: entries store folded hash8
ww=10  narrow:      entries store folded hash16
ww=11  full:        entries store hash0..3
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

## Legacy Hash Width Control Policy

When a scanner is already inside a known catalog/table region, the record should
not spend bytes naming its hash algorithm. The older text below explains how the
FNV proving records tried to reduce per-record marker cost.

An older shorthand used `F/N/V` as human-readable width markers:

```text
'F'  4-byte full FNV-1a records
'N'  2-byte narrow folded FNV-1a records
'V'  1-byte very narrow folded FNV-1a records
```

That is readable, but it still spends a byte on width. In compact RCAT/RREC
records, width belongs in the `ww` bits of the layout/control byte. `FNV` names
the Fowler/Noll/Vo hash family. RFC 9923 is the outside reference for the
FNV-1a algorithm.

Current HIMON still uses the older proving-record shape:

```text
'F','N',('V'|$80),hash0,hash1,hash2,hash3,kind,inline-code...
```

In that current shape, `('V'|$80)` is the high-bit-terminated third byte of the
literal `FNV` signature. The `kind` byte follows the four hash bytes:

```text
$00  executable code begins immediately after kind, at record+8
```

Current HIMON does not store `entry_lo,entry_hi`. Explicit pointer records are
a future RREC payload direction.

The future compact record should use a layout/control byte instead of spending
literal width marker bytes:

```text
control: ww=11, hash0,hash1,hash2,hash3, value/payload...
control: ww=10, hash16_lo,hash16_hi,    value/payload...
control: ww=01, hash8,                  value/payload...
```

Storage savings:

```text
3-byte "FNV" per record -> compact control saves almost 3 bytes per record
ww=11                     keeps 4 hash bytes per entry
ww=10                     saves 2 hash bytes per entry
ww=01                     saves 3 hash bytes per entry
```

Scale examples:

```text
100 records  at ww=10 = about 200 hash bytes saved
256 records  at ww=01 = about 768 hash bytes saved
1000 records at ww=10 = about 2000 hash bytes saved
```

Tradeoff: a single-byte control field is weak when scanning arbitrary flash
for records. The HIMON/catalog scanner can handle that by only scanning known
catalog regions, requiring a valid kind/flags/check byte nearby, or using a
larger catalog block header while keeping each record tiny. STR8 V0 does not
scan FNV catalog records.

## Catalog Version Selection

Do not let one byte mean every kind of version. The catalog needs separate
version ideas:

```text
record format version     how to parse this RREC layout
catalog block version     how to parse/discover the enclosing RCAT block
routine contract version  what contract the routine/data/provider offers
record generation         which live record supersedes another record
```

The compact layout byte belongs to record parsing and hash-width selection. It
should not decide whether `ROUTINE` v1 or `ROUTINE` v2 is the better callable
provider.

Catalog lookup should become candidate selection, not first-match:

```text
lookup(name, kind, version policy)
  scan valid catalog regions
  collect matching hash/name/kind records
  discard stale/buried/invalid records
  apply version policy
  choose the best live candidate
```

Useful version policies:

```text
exact v1       accept only contract v1
v1+            accept the newest compatible contract at least v1
latest         accept the newest live compatible provider
```

So if ROM contains both `ROUTINE` v1 and `ROUTINE` v2, v1 does not need to be
physically erased or marked buried. Normal HIMON lookup can choose v2 under
`latest` or `v1+` policy. STR8 V0 stays out of this FNV/version-selection path
and uses fixed whole-image recovery choices instead.

Append-only flash update should work even when old records cannot be changed:

```text
old v1 record remains live
new v2 record is appended with same hash/name/kind and higher contract/generation
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
buried?
```

When the chain is exhausted or the block has too much buried material, HIMON or a
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

HIMON command lookup is:

```text
input token -> canonical/HBSTR-aware FNV-1a -> record scan -> entry address
```

The `#` command belongs in this world. It can show the hash path and eventually
show collision candidates from the master catalog.

## Assembler Symbol Hash

Hashed ASM uses the same mental shape:

```text
label text -> canonical text -> compact hash -> symbol record -> value
```

For a forward label:

```text
operand text -> hash -> no current symbol -> create fixup
later label -> same hash -> patch recorded site
```

## Catalog Hash Record

Mini theory:

```text
canonical name/text -> compact hash -> typed catalog record -> value/payload
```

The hash is only the compact lookup hint. The surrounding record gives the match
meaning. A future R-YORS catalog can use the same hash path for several kinds of
things:

```text
command       hash -> executable entry point
routine       hash -> callable service address plus contract notes
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

`kind` classifies the record or payload. It should not carry lifecycle policy.
Lifecycle flags can include `REQUIRED_FOR_RECOVERY`, `BOOT_REQUIRED`, or
`REPLACEABLE`. `REQUIRED_FOR_RECOVERY` is the future no-ordinary-purge rule for
the active recovery dependency chain; it is not implied merely by a `BIO_*` or
`PIN_*` routine name.

There is no per-record algorithm byte. The catalog format itself defines
`hash0..3` as FNV-1a.

When a useful behavior is duplicated in proof code, promote it in two stages:
first static-link a documented routine contract through labels/library records;
later export the same contract as an `RREC` and let `RFIX`/`RLNK` resolve it.
The HIMON/search range parser is the model: share the range arithmetic and
count/end semantics, while keeping thin adapters for each caller's workspace.

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
stable discovery hash; short handles are local conveniences for hot paths,
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
