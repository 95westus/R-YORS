# QCC Hash

This page keeps hash questions in QCC form. These notes are for compact lookup,
hash-width records, and folded FNV-1a behavior.

## Q: Can HIMON use 1, 2, and 4 byte hashes?

Comment: Yes. The clean idea is:

```text
1 byte  very narrow folded hash
2 bytes narrow folded hash
4 bytes full FNV-1a hash
```

Use the short form only where collisions are controlled by table scope,
fallback, or name verification. Escalate to a wider hash when a collision is
known.

Concern: A 1-byte hash is not magic. With many records, collisions arrive fast.
For arbitrary ROM scanning, a short hash must be paired with a real record
signature, bounds, length, and validation rules.

## Q: Should F/N/V bytes mark hash width?

Comment: As a human shorthand, `F/N/V` can still mean:

```text
F = full, 4-byte hash records
N = narrow, 2-byte folded hash records
V = very narrow, 1-byte folded hash records
```

Concern: Spending a literal byte on `F`, `N`, or `V` just to mark width wastes
space in compact RCAT/RREC records. The better compact direction is to store
width in `ww` control bits:

```text
ww=01  folded hash8
ww=10  folded hash16
ww=11  full hash32
```

The letters remain useful documentation shorthand, not necessarily bytes in the
record.

## Q: Can FNV-1a derive 8-bit and 16-bit results?

Comment: Yes. Keep the 32-bit FNV-1a routine canonical, then fold the 32-bit
result into 16 or 8 bits with helper routines.

```text
FNV1A32(text) -> fold16 -> fold8
```

Concern: The folded helpers should call the 32-bit routine instead of becoming
new independent hash algorithms. That keeps all runtime and documentation
language anchored to one hash family.

## Q: When does a 1-byte hash stop helping?

Comment: It depends on table size and collision policy.

Rough intuition:

```text
small named tables       useful
known command families   useful with collision escalation
large arbitrary scans    weak without a stronger signature
```

Concern: For a 256-slot hash space, collision odds become noticeable after only
a small number of records. A 1-byte hash is a compact discriminator, not a
unique identity.

## Q: Can hash width hide things?

Comment: It can obscure casual reading. A mixed 1/2/4-byte table forces the
reader to understand the table layout before names make sense.

Concern: It is not security. Anyone who knows the record format can scan and
decode it. Treat it as compactness and light obscurity only.

## Q: How does compact signature work with FSB?

Comment: The compact signature can keep the first two bytes literal and pack
the third:

```text
'F' 'N' %FSB10110
```

The low five bits are packed uppercase `V`. The high three bits belong to
flash lifecycle state and are discussed in `QCC_FLASH.md`.

Concern: Keep hash width and lifecycle bits separate in the spec. Width belongs
in control bits such as `ww`; FSB belongs to a future signature/lifecycle idea.

## Q: Is `FN(V|$80)` too wasteful as a marker?

Comment: Yes, for compact catalog records. No, for bring-up and arbitrary ROM
scanning.

The current HIMON record spends three visible bytes before the hash:

```text
'F','N',('V'|$80),hash0,hash1,hash2,hash3,kind
```

That is expensive if every compact record pays it. It is also useful right now:
it is easy to spot in a hex dump, easy to scan with tiny code, and strong enough
for a proving record in arbitrary ROM/code space.

The compact direction should separate three questions:

```text
where do I scan?       declared window or catalog block
what am I reading?     block/table marker and record control byte
which name is this?    FNV-1a hash bytes, width chosen by context
```

Good progression:

```text
current proof
  per-record FN(V|$80), full hash, kind

near compact
  block marker such as RCAT/RREC once, then small record controls

managed catalog
  declared window + sealed block header + compact records, no per-record FNV text
```

A marker hash is possible, but it should usually identify a block/table format,
not every record. For example, a block header could carry a 16-bit or 32-bit
FNV-1a hash of a format name such as `RYORS RCAT V1`. That makes the marker
namespaced and versionable, but once stored it is still just marker bytes. It
does not remove the need for length, bounds, lifecycle, and checksum/proof
rules.

Marker options:

```text
3 text bytes per record      readable, good for current arbitrary scans
2 text bytes per block       smaller, still readable: RC/RR/RT/etc.
1 control byte per record    good only inside a proven block/window
hash marker in block header  versionable, less readable, useful for formats
no marker per record         best once the enclosing table proves context
```

Concern: A marker answers "are these bytes probably a record?" It is not the
record identity. The identity still comes from hash/name/kind plus contract
metadata. One byte by itself is not enough for arbitrary scanning; it becomes
safe only inside a declared and validated block/table.

## Q: Should hash records link to parents and children?

Comment: A HIMON userland explorer could take a command/string, compute its
FNV-1a hash, find the matching executable FNV record, scan the associated code
for `JSR abs` opcodes, and follow each target. In the current HIMON executable
record shape, backing up 8 bytes from a code address can detect whether the
target has its own FNV header:

```text
'F','N',('V'|$80),hash0,hash1,hash2,hash3,kind
```

For `kind=$00`, executable code begins immediately after the kind byte. If
`target-8` has that header, the explorer can report:

```text
parent_hash parent_addr -> child_hash child_addr
```

This should not use CPU-stack recursion on 6502. Use a RAM worklist instead:

```text
push starting address
while worklist not empty and depth/edge budget remains
  pop address
  skip if already visited
  scan bounded code bytes for JSR
  for each target
    test target-8 for FNV executable header
    report edge when found
    push child target if not visited
```

Concern: Automatic stored parent/child links cost ROM/flash space and can go
stale when code changes. They also risk turning a compact record into a small
database too early. The first implementation should probably derive links by
scanning code, either in a host-side tool or a HIMON userland program.

Possible later promotion path:

```text
derived scan only          cheapest, no stored links
builder-emitted edge table automatic but rebuilt with image/catalog
cached edge records        useful after load, must be invalidated by hash/version
stored parent/child fields fastest lookup, highest space/staleness cost
```

Question to keep open: should RCAT/RREC eventually store explicit dependency
edges, or should the assembler/catalog builder derive them automatically from
code and emit a separate edge table?

## Q: Can hash joints help SMS/WTOR-style operator messages?

Comment: Yes, this may be one of the cleaner early uses for hash joints.
Operator messages want provenance and reply routing more than they want a
general code graph. A future system messaging service could attach a compact
hash joint to a message so the operator and the waiting task can agree on:

```text
message text/hash -> sender task/routine -> reply handler or wait point
```

That gives each message a small identity trail without forcing the visible
operator text to carry all of the machinery. A WTOR-like inquiry could carry:

```text
MSG_HASH     identifies the message template or text
FROM_HASH    identifies the task/routine that raised it
WAIT_HASH    identifies the reply-required wait point
REPLY_HASH   optional expected reply class or handler
```

The human view can stay terse:

```text
STR8 RESTORE NEEDS REPLY
```

while a diagnostic view can show the chain:

```text
MSG 8A3C -> STR8_RESTORE A91233F0 -> FLASH_ERASE_WAIT 41B8207D
```

Concern: The hash joint should not become a hard dependency on exact text.
Operator wording changes often; the durable identity should probably be the
message template, issuing routine, or wait point, not the printable sentence
alone. The first SMS/WTOR version should also avoid recursive chain walking.
Use bounded lookup: message record, sender record, optional wait/reply record.

Possible promotion path:

```text
message ID only             simplest queue and reply correlation
message + sender hash       provenance without much space cost
message + sender + wait     WTOR-style reply routing
full chain/audit records     useful later for diagnostics and catalogs
```

Question to keep open: should SMS records store these joints directly, or
should SMS store only a message ID while RCAT/RREC/catalog metadata resolves
the hash chain on demand?

## Q: Can memory search accept HBSTR literals?

Comment: Yes, but the printable spelling should probably be the canonical one.
A future HIMON memory search could accept a backtick HBSTR literal:

```text
S 0 FFFF `HIMON
```

That would search for bytes `H I M O (N|$80)`, matching a high-bit-terminated
string without requiring the operator to type or see a raw high-bit byte.

Concern: A Ctrl-letter tail is technically possible because current HIMON top
input stores many control bytes in `CMD_BUF`, but it is not a good primary
syntax. Ctrl-C aborts, CR/LF ends the line, BS/DEL edit the line, and terminals
may intercept flow-control keys such as Ctrl-S and Ctrl-Q. Invisible bytes also
make command history and documentation harder to reason about. If a Ctrl-letter
tail is ever supported, treat it as an optional shortcut, not the spec.

Current caveat: HIMON command input uppercases printable letters before
dispatch. Exact lowercase or mixed-case HBSTR searches need hex-byte spelling
or a future search input path that preserves case.

## Q: Can memory search mix hex bytes and text?

Comment: Yes, with a small parser rule. After the range, treat the pattern as
one or more atoms:

```text
hex-byte      append one byte
'text-tail   append text through end-of-line, then stop parsing pattern
```

That keeps the normal cases terse:

```text
S addr end|+count b0 [b1 ...]
S addr end|+count 'TEXT
```

and allows the small operator convenience:

```text
S 0 FFFF 4D 4D 'M
```

which searches for three `M` bytes.

Concern: Keep apostrophe text as a final tail for the first implementation.
There is no closing-quote parser and no return to hex parsing after text.
Supporting text in the middle of the pattern would require quotes or escaping;
that is not worth the parser cost for V0.
