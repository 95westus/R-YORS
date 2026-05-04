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
