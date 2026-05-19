# QCC Flash

This page keeps flash-record questions in QCC form. These are working design
notes, not final wire format.

Glossary decision: `formed`, `sealed`, `buried`, and `gone` are the preferred
flash lifecycle words. `Condense` is the official sector rebuild term;
collapse/compress may appear as informal synonyms.

## Q: Is writing `$FF` to erased flash the same as an erase?

Comment: No. Erased flash normally reads as all `1` bits, so an erased byte
will read `$FF` / `%11111111`. Programming `$FF` into a location that is already
erased leaves the visible user byte unchanged, but it is still a program
operation, not an erase operation.

Flash programming is one-way at the bit level:

```text
1 -> 0  program can do this
0 -> 1  erase must do this
```

So writing `$FF` cannot restore a programmed `0` bit back to `1`. Only erase can
do that, and erase happens at sector/block scale rather than as a byte update.

Concern: Treat `$FF` writes as redundant writes, not as harmless erases. On a
simple raw cell the user bits do not change, and the stress is usually much
less significant than a sector erase. But real flash parts and controllers may
still apply program pulses, update hidden ECC/status bits, restrict repeated
programming of the same word/page, or make a location no longer blank in a
device-specific sense. Writers should skip `$FF` bytes/words when possible, and
blanking logic must use real erase.

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

## Q: Are duplicate ROM/flash records a bug or a feature?

Comment: They are a bug in the current first-match scanner, and a feature in a
future governed catalog.

The `calc-9a00-fnv-proof` and `rom-append-calc` example shows the difference.
Both records publish the same `CALC` command hash. They both fit physically:

```text
calc-9a00-fnv-proof   starts $9A00, ends $9C9F
rom-append-calc       starts $B804, ends $BADA
```

The room is not the issue. The issue is that both are visible in the same
scanner world. Current HIMON command dispatch scans upward and stops on the
first matching executable FNV record. That means the lower-address proof record
would win before the newer ROM-append payload. In that mode, duplicate command
records are accidental shadowing.

Future catalog lookup should treat this as candidate selection:

```text
scan declared windows
collect matching hash/name/kind candidates
discard erased, unformed, unsealed, buried, invalid, or wrong-contract records
choose by explicit winner rule
```

Useful winner rules depend on the mode:

```text
boot/recovery     prefer known ROM/fixed records first
normal command    prefer newest sealed compatible flash/catalog record
test/staging      prefer RAM or explicit staging window first
diagnostic #      list every visible candidate, including losers
condense          keep winners, copy/verify them, bury or drop losers
```

That is exploitable in the good sense. Duplicate identity lets a new record be
written and proven before the old one is erased or buried:

```text
old CALC remains visible
new CALC is written elsewhere
new CALC is verified and sealed
lookup policy starts choosing new CALC
old CALC becomes rollback/debug material
later condense removes or buries the loser
```

Concern: Do not let raw address order become the hidden contract. If address
order is used, name it as a temporary proof rule. Once staging, update, rollback,
and garbage collection matter, lookup must collect candidates and apply a
policy that operators and tools can inspect.

## Q: Can "generation wins" work with only the current kind byte?

Comment: No. The current HIMON proving record is too small for that policy:

```text
'F','N',('V'|$80),hash0,hash1,hash2,hash3,kind,inline-code...
```

That shape proves:

```text
hash       what command/name was requested
kind       what coarse thing follows, such as executable code
entry      current rule says executable code begins at record+8
```

It does not carry:

```text
generation
contract version
provider/source
record length
formed/sealed/buried state
priority or scan-window policy
checksum/proof
explicit entry pointer
```

So current HIMON can only use simple proof-era rules such as first-match or
hardcoded scan-window order. That is not generation wins; it is address order
being used as a temporary resolver.

Real generation wins needs either an extended record or an enclosing catalog
block/table that supplies metadata:

```text
collect candidates
reject invalid/unsealed/buried/wrong-contract candidates
choose highest compatible generation, or another named policy
```

Concern: Do not overload the `kind` byte. `kind` says what class of thing the
record points at. It should not also mean lifecycle, generation, ABI contract,
and provider priority. Those belong in RCAT/RREC metadata or a transitional
extended record.

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
