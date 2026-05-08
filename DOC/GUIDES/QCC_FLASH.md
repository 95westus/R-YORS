# QCC Flash

This page keeps flash-record questions in QCC form. These are working design
notes, not final wire format.

Glossary decision: `formed`, `sealed`, `buried`, and `gone` are the preferred
flash lifecycle words. `Condense` is the official sector rebuild term;
collapse/compress may appear as informal synonyms.

## Q: How can the compact signature carry lifecycle state?

Comment: Use the third signature byte as packed `V` plus three active-low
lifecycle bits:

```text
'F' 'N' %FSB10110
```

Low five bits:

```text
10110 = packed uppercase V
```

High three bits:

```text
F = formed
S = sealed
B = buried
```

Concern: These bits are flash-native state bits. They are not runtime toggles.
They can safely move `1 -> 0`, but they cannot move back to `1` without sector
erase.

## Q: What does FSB mean like I am five?

Comment: FSB is three tiny stickers on a ROM record:

```text
F = formed
S = sealed
B = buried
```

The record starts as erased flash, full of `1` bits. STR8/HIMON can only peel
stickers off by clearing bits.

```text
11110110  not ready; pretend it is not there
01110110  formed; the bytes look like a real record, but do not trust it yet
00110110  formed + sealed; checked and good enough to use
00010110  buried; old record, skip it during normal lookup
```

Concern: Buried records are still physically present in ROM. "Not findable"
means normal catalog lookup skips them, not that a raw ROM scanner cannot see
the bytes.

## Q: What code should do with each state?

Comment:

```text
11110110
  Ignore. This may be erased flash, an interrupted write, or provisional bytes.

01110110
  List or inspect in diagnostics. Do not dispatch to it.

00110110
  Treat as eligible. If several sealed records match, use the winner rule.

00010110
  Skip during normal lookup. Keep only for diagnostics, recovery, or condense.
```

Concern: A sealed old record cannot be made "not sealed" again. Superseding and
burying must be handled by rules that only clear more bits.

## Q: How does the old king get replaced?

Comment: Do not make "active" a reversible bit. Let sealed records compete by
generation, sequence, address order, or another explicit rule.

```text
old king:  formed + sealed, generation 4
new king:  formed + sealed, generation 5
lookup:    chooses generation 5
later:     old king gets buried
```

Concern: The winner rule must be written down before multiple sealed records
are allowed in the same managed region.

## Q: What does condense purge?

Comment: The strongest purge signal is `B=0`.

```text
purge B=0 buried records
purge F=1 junk/provisional records inside managed table ranges
optionally purge stale F=0,S=1 formed-but-unsealed records
keep F=0,S=0,B=1 winner records
```

Concern: Formed-but-unsealed records may be useful for recovery or debugging.
Purge them by policy: user command, age, failed verification count, free-space
pressure, or explicit recovery mode.

## Q: When should condense run?

Comment: Good triggers:

```text
buried bytes exceed a threshold
free bytes fall below a threshold
too many records share one hash/name chain
scan cost becomes annoying
user explicitly runs CONDENSE
a new write needs room
STR8 recovery sees a messy but recoverable table
```

Concern: Normal lookup should not erase flash. Lookup skips. STR8/STRAIGHTEN,
or a catalog maintenance subsystem called by STR8, should own sector rebuilds.

## Q: Where does condense live?

Comment: It belongs with STR8/STRAIGHTEN or a dedicated catalog maintenance
subsystem behind STR8.

Concern: Condense means sector-level danger:

```text
scan old flash
choose winners
stage records in RAM or another safe flash region
erase target sector
write compacted table
verify
mark records formed -> sealed
```

HIMON can scan, use, and request cleanup. The erase/rebuild operation should
stay with the recovery/update layer.

## Q: Is PACK/compact managed flash space future direction or crazy talk?

Comment: It is future direction. The official low-level word remains
`Condense`: rebuild a sector or managed region so live records are packed
together and stale/buried/provisional material stops consuming lookup space.
`PACK` may become the operator-facing word if it proves clearer:

```text
CONDENSE RCAT
PACK HASH
PACK BANK1
```

The important model is not compression in the ZIP/RLE sense. It is flash-space
compaction:

```text
scan managed region
choose live winner records
copy winners into a clean layout
verify copied records by hash/length/state
bury or supersede old records when possible
erase sectors only when no live records remain
```

Concern: This must not become automatic background magic. Early versions should
be explicit, slow, verbose, and operator-confirmed. Lookup can skip stale
records, but erase/rebuild belongs to maintenance or STR8/STRAIGHTEN policy.

## Q: Can different datasets have different condense rules?

Comment: Yes. Hash identity lets address become "where this record currently
lives" instead of "what this record is." That means different managed datasets
can eventually have different movement policies:

```text
RCAT/RREC  catalog records; compactable if sealed and hash-verified
HASH/NAME  symbol/name/signature records; compactable, possibly rebuildable
MSG/SMS    message templates and WTOR metadata; compactable by message ID/hash
CODE       movable only after catalog, ABI, and call/link rules are strong
DATA       compactable only with length, hash, state, and ownership metadata
STAGE      disposable after update/verify succeeds
BOOT       protected/fixed except through explicit install/update policy
```

Concern: Moving code is much harder than moving records. RCAT/HASH/MSG/DATA
can probably condense earlier because their identity is naturally record-shaped.
CODE should wait until catalog lookup, call boundaries, and link-on-copy rules
are proven.

## Q: What makes a sector safe to erase after condense?

Comment: A sector is eraseable only after the maintenance code can prove every
record in it is either copied and verified elsewhere, buried/stale by the
winner rule, provisional junk, or outside the managed region's live set.

```text
all live records copied
copies verified
catalog/winner rule points to copies
old records are buried or no longer winners
then sector may be erased
```

Concern: Power loss halfway through must leave at least one valid winner. That
means the new copy should be written and sealed before the old copy is buried,
and erase should be the final cleanup step, not the commit step.
