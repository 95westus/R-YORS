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
  owner: catalog/STR8/Himon
  purpose: collision proof, listings, onboard linking
  guide: HASHED_ASM.md, SYMBOL_XREF.md
```

## Rule

```text
FNV-1a is the one catalog/runtime symbol hash.
records do not carry a hash-algorithm tag.
hash narrows candidates
stored text proves identity
record kind/bank/address tells how to use the match
```

Do not treat a hash as the whole identity once the catalog becomes writable or
loadable from user-built modules.

## FNV Signature Policy

FNV-1a is the only runtime/catalog symbol hash, so the record does not need to
store the text `FNV` or an algorithm id. The leading signature byte can be a
record-format generation instead:

```text
'F'  format v1
'N'  format v2
'V'  format v3
```

`FNV` names the Fowler/Noll/Vo hash family. RFC 9923 is the outside reference
for the FNV-1a algorithm; R-YORS `F/N/V` signature bytes are catalog record
format markers layered on top of that one hash, not alternate algorithms.

Those letters are a compact version ladder, not alternate hash algorithms. Every
one still means the `hash0..3` field is FNV-1a.

Current Himonia-F still uses the older proving-record shape:

```text
'F','N',('V'|$80),hash0,hash1,hash2,hash3,kind,entry...
```

In that current shape, `('V'|$80)` is the high-bit-terminated third byte of the
literal `FNV` signature. The `kind` byte follows the four hash bytes:

```text
$00  executable entry follows immediately after kind
```

The future compact record should collapse signature and record version into one
byte:

```text
sigver,hash0,hash1,hash2,hash3,value_lo,value_hi,bank,kind,flags,...
```

This lets the first byte answer two questions at once:

```text
is this a catalog hash record?
which record layout should the scanner use?
```

Storage savings:

```text
3-byte "FNV" signature -> 1-byte 'F' signature saves 2 bytes per record
signature + version byte -> versioned signature saves 1 byte per record
5-byte "FNV1A" text -> 1-byte signature saves 4 bytes per record
```

Scale examples:

```text
100 records  * 2 bytes saved = 200 bytes
256 records  * 2 bytes saved = 512 bytes
1000 records * 2 bytes saved = 2000 bytes
```

Tradeoff: a single-byte signature is weaker when scanning arbitrary flash for
records. STR8 can handle that by only scanning known catalog regions, requiring
a valid kind/flags/check byte nearby, or using a larger catalog block header
while keeping each record tiny.

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

When the chain is exhausted or the block has too much dead material, STR8/HIMON
can condense: copy live records to RAM or another block, erase the old sector,
then rewrite a compact block with fresh `$FF` state bytes.

## Catalog Blocks

Catalog records do not all have to live in one address range. The system can
use multiple catalog blocks, for example one near the protected monitor and
another in a growth bank:

```text
$Fxyy block  boot/current monitor catalog, small and protected
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

Working record shape:

```text
record kind/signature
hash0..3
value_lo/value_hi
bank
kind
flags
optional name length
optional raw or compressed name text
```

`bank` matters because the record may live in a clean catalog area while the
routine/data body lives in banks 0-2.

There is no per-record algorithm byte. The catalog format itself defines
`hash0..3` as FNV-1a.

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

## Text Storage

Possible text encodings:

```text
raw_hb       high-bit-terminated string
raw_z        ASCIIZ string
pack_lo_5    5-bit restricted alphabet
dict_small   later optional dictionary
pool_hb      offset to high-bit-terminated text in a block string pool
pool_z       offset to ASCIIZ text in a block string pool
pool_len     offset plus length in a block string pool
```

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
