# ASM FNV Module Proposal

Status: idea recorded for consideration on 2026-08-21. This is not an active
ASM feature, AP replacement, frozen format, command, ABI, or implementation
authority.

## The Idea

ASM could build a small callable module/subroutine artifact instead of an AP
Capsule. The artifact would wrap assembled code in enough FNV-1a identity and
entry metadata for HIMON/RJOIN-compatible tooling to find the routine by hash.
It could be placed in executable RAM or in executable visible flash and called
at that address.

The important distinction is that this output would be a **module in place**,
not an AP envelope:

```text
AP Capsule          metadata + BODY data; load/relocate/link into RAM, then run
FNV module          callable code at its installed address; find, then JSR/JMP
```

This could give ASM a smaller product for one routine or a tight family of
routines when AP relocation, loading, and application-style entry are not
needed. RAM and flash would be placement choices for the same concept, subject
to their different write and lifetime rules.

## Why It Could Be Cheaper Than An AP

The proposed module enhances ASM with a middle output class rather than merely
renaming an AP:

```text
raw BODY    smallest, but manually addressed and not safely discoverable
FNV module  small named routine, validated and called where it already lives
AP Capsule  larger movable object, loaded, relocated, linked, and then run
```

For a fixed-address or genuinely position-independent routine, the module can
avoid the AP v2 five-section envelope, BODY copy to a second RAM location,
relocation pass, and AP loader invocation. A flash-resident module can also
leave its code in visible flash instead of consuming BODY-sized run RAM. Its
wrapper may therefore be smaller than AP v2's current minimum `$0022` envelope
overhead, but no byte target is promised until a candidate header includes all
required bounds, integrity, entry, kind, version, and commit information.

The savings are conditional. Fixed-address code loses AP's selectable load
address. Imports, relocations, multiple exports, bank switching, or a rich
lifecycle can make the small wrapper grow toward an AP while reproducing AP
machinery badly. The decision rule should be: use an FNV module when a bounded,
validated routine can execute in place; use an AP when the BODY must move,
relocate, link substantial dependencies, or behave like a loadable application.

## Relationship To Resident FNV Records

HIMON's current resident executable record begins with the compact identity
shape:

```text
'F' 'N' (V|$80) hash0 hash1 hash2 hash3 K
```

and an EXEC record identifies a callable entry. A future ASM module should
reuse that vocabulary and `THE_JOIN_EXEC_XY` calling convention where it can,
rather than introduce a second name-hash universe. Exact byte reuse is not yet
promised: current resident scanning knows bounded ROM regions and record kinds,
whereas a separately installed RAM/flash object also needs a safe discovery
and validation boundary.

The name's FNV-1a hash is identity, not proof that the module bytes are intact.
If the wrapper authenticates the body, it needs a separately specified body
length and integrity value. That value may also be FNV-1a, but its purpose and
coverage must not be confused with the routine-name hash.

## Candidate Shape, Not A Frozen Format

A first paper format could contain:

```text
signature/version
total length
kind and flags
routine-name FNV-1a hash
entry offset or entry address
body length and body integrity
optional human-readable name pointer/offset
assembled body
```

The wrapper should be compact, forward-skippable, and commit-friendly in flash.
The callable entry need not be the first byte after the wrapper. A one-routine
first slice is preferable; multi-export modules, imports, constructors, and
catalogs should not be assumed merely because AP already supports some of
them.

## Placement Contract

RAM placement is the simplest experiment. ASM can emit the module at a chosen
RAM address, validate its wrapper and body, register or scan that bounded
region, resolve the name hash, and call the entry in place. The module remains
valid only while those RAM bytes are owned and unchanged.

Visible-flash placement is a separate lifecycle around the same executable
shape. ASM may produce the bytes, but STR8 remains the flash mutation boundary.
An installer must use explicit destination/range checks, erased-space or
sector-rewrite policy, read-back validation, and a commit-last rule. A module
must never call through a bank switch that makes its own code disappear. Code
in a non-visible bank is stored, not callable in place; using it would require
a banked-call contract or a copy to RAM, either of which is a later design.

The module must declare or inherit a fixed link address unless its body is
genuinely position-independent. Moving fixed-address bytes from RAM to a
different flash address does not relocate them. This proposal does not smuggle
AP relocation metadata into the small format; if relocation/import machinery
becomes necessary, an AP Capsule may remain the right product.

## Discovery And Call Direction

Do not make RJOIN scan arbitrary RAM or all flash for an `FN` byte pattern.
Candidate discovery should begin with explicit, bounded module regions or a
small validated catalog supplied by the owner of those regions. Every object
must be length-checked before its entry is published.

A useful eventual flow could be:

```text
ASM source -> MODULE/WRAP -> bounded RAM or flash region
caller hash -> validated module discovery -> executable-kind check -> entry
caller -> JSR entry using the ordinary routine contract
```

The existing resident resolver may be extended to consult one validated
module source, or a separate resolver may return an entry using the same
`X/Y` and carry convention. That choice should follow a size and failure-mode
comparison. Hash collisions must be detected or disambiguated; first-match
execution is not an acceptable installation policy.

## Suggested First Slice

If promoted later, start with one RAM-only, fixed-address routine:

- one ASM `ENTRY`/executable export and no imports or relocations;
- a compact wrapper with explicit total/body lengths, name hash, entry, and
  body integrity;
- an explicit bounded resolver input rather than global memory scanning;
- validation before publication and call;
- exact host-format tests plus one board call returning the normal `A/C`
  routine result;
- measured ASM/HIMON ROM and RAM cost.

Only after that slice is useful should a flash installer and durable discovery
catalog be designed. Flash proof must include reset persistence, read-back
identity, range isolation, incomplete-write rejection, and execution from the
visible installed address.

## Proof Questions

Before this becomes an ASM Feature Queue item, answer:

- Is the artifact materially smaller or simpler than the minimum AP v2
  envelope plus loader path for the intended routine?
- What exact bytes are covered by the body-integrity value?
- How is a hash collision rejected or resolved without requiring full names in
  every minimal object?
- Who owns each discoverable RAM/flash region, and when is its index invalidated?
- Are fixed-address references, position-independent code, and forbidden
  relocation/import forms diagnosed at build time?
- Can a RAM and a visible-flash instance use the same format without pretending
  they have the same lifetime or mutation policy?
- Does resolver failure leave the caller state and existing published records
  unchanged?
- Can an interrupted flash install remain undiscoverable until its final
  commit byte is valid?
- Can HIMON reject malformed length, entry, kind, version, integrity, and
  out-of-region values before transferring control?

## Decisions Deliberately Left Open

- The artifact name and command spelling (`MODULE`, `WRAP`, or something else).
- Whether its leading bytes exactly match a current resident FNV record or use
  an outer module header containing one.
- Whether the body-integrity algorithm is FNV-1a or a stronger/checkable CRC.
- Whether a text name is mandatory, optional, or catalog-owned.
- Whether one module may export several callable routines.
- Whether validated modules join the existing RJOIN scan or use an explicitly
  supplied resolver/context.
- Whether later flash modules may call only resident services, other same-bank
  modules, or neither until a dependency contract exists.

The proposal is worth keeping precisely because it is smaller than "build an
AP": ASM could produce a hash-addressable routine that is already where it
runs. It should stay parked until that smaller contract is demonstrably useful
and safe in both memory classes.
