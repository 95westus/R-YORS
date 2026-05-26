# QCC Catalog Linking

This page keeps the catalog-linking bootstrap problem in QCC form. The short
version in project terms:

```text
we want catalog joins
but the first catalog-aware ASM/body wants to use those joins
so the first thing cannot require the thing it is proving
```

That is the chicken-and-egg problem. It is real, and the answer is a seed
layer, not pretending the full catalog already exists.

The working name for the first runtime operation is `RJOIN`: runtime join.
It means hash/name reference -> resolved runtime entry/value. Fixup records
should use the compact `RF` signature. From the current codebase, the proof
lane is still:

```text
make -C SRC hrec-join-proof asm-rjoin-proof himon-search-proof
```

Those targets prove the present join/search mechanics while the fuller
RJOIN/RR/RB/RF/RD record family is still being shaped.

## Q: What minimum metadata makes flash banks usable as storage?

Comment: A bank becomes useful storage when its records say what they provide,
what they depend on, and how their bytes can be placed safely. Without that,
the bank is only a byte pile: searchable, dumpable, maybe copyable, but not a
trustworthy routine shelf.

The small record set we keep circling is:

```text
provides       public hash/name/kind/entry exported by this record
depends        required hashes/contracts before this body can run
fixups         patch sites, widths, modes, and targets
payload length exact body size, not "until the next thing maybe"
link address   address the body was assembled for
load address   address chosen by loader, if different
checksum       body/record check before trusting the bytes
```

That is still not a VM. It is a tiny loader/linker contract. The storage bank
can hold `RR/RB/RF/RD` pieces; HIMON or a future tool can copy the body to RAM,
resolve dependencies, apply fixups, and then run native W65C02S code.

The bootstrap remains seed-first:

```text
build/map truth emits first provides/depends/fixups
HIMON scans those records
S proves join/load/use behavior
later ASM learns to emit the same record facts
```

Concern: Do not infer dependency closure from names alone. `SYS_`, `BIO_`, and
`PIN_` are useful human layers, but storage records need declared imports and
exports. The resolver should know why a body can run, not merely hope because a
hash was found somewhere in a bank.

## Plain-English Models

These are deliberately informal. They are here because the catalog-linking
idea is easy to over-formalize before the first proof is boring.

### If You Are 12

ASM linking is like building a model at your desk before you bring it to the
table. You already know where every piece goes, so the finished model carries
everything it needs.

Catalog linking is like using a shared workshop. Instead of bringing every
tool in your box, the job asks the workshop:

```text
who has WRITE?
who has HEX?
who has CTRL-C?
```

The workshop catalog points at the shared tool. The program uses that tool
instead of carrying its own copy.

### If You Are 17

ASM linking is compile-time certainty. The linker resolves names into fixed
addresses before the program runs:

```text
JSR SYS_WRITE_CHAR -> JSR $2700
```

That is simple and reliable, but it couples the program to the exact image it
was linked with. If a helper is not already resident, the linker may pull in a
private copy. That is payload baggage.

Catalog linking is runtime resolution. The program says, "I need the routine
whose record/hash means WRITE," and HIMON/THE finds the resident provider:

```text
hash("BIO_FTDI_WRITE_BYTE_BLOCK") -> record -> entry address -> call it
```

That is smaller and more flexible for shared services, but only after the
catalog and join rules are trustworthy.

### If You Are 30-40

ASM linking is like shipping an app with its dependencies bundled into the
package. The build is predictable because every referenced routine is either
at a fixed address or copied into the output. That is good for a proof, but it
can make every package carry the same utility code.

Catalog linking is closer to service discovery inside a small operating
environment. The app says:

```text
I need WRITE-BLOCK with this contract.
I need HEX-PARSE with this proof level.
```

The catalog resolves those needs to resident routines. The app can be smaller,
and the system can replace or promote a shared service without rebuilding
every caller. The tradeoff is trust: the catalog must be versioned, verified,
and honest about the contract it returns.

This is why `S` is a better first target than LIFE. Search is a real command
with real dependencies, but it is still small enough to prove:

```text
same behavior
less bundled baggage
joined resident helpers
```

### If You Are 62

ASM linking is like a printed service manual with every referenced appendix
photocopied into the back. Everything is present, and the page references are
fixed, but ten manuals that need the same appendix now carry ten copies.

Catalog linking is like a well-run shop index. The job card says:

```text
Use procedure WRITE-BLOCK, revision/proof X.
```

You go to the catalog, verify the entry, and use the shop's master copy. Less
duplication, easier replacement, but only if the index is trustworthy and the
procedure name points to the right drawer.

This shop-index model is the preferred public analogy for now. It matched the
project author's own working picture best.

## Q: Does Choosing SYS Pull BIO And PIN?

Comment: Yes, if the selected record declares imports and the resolver follows
them.

The catalog should let the user choose the abstraction level they actually want:

```text
PIN_READ_BYTE_NB
BIO_READ_CHAR_NB
SYS_READ_CHAR_NB
```

Choosing the PIN-level provider should flash the smallest body: the driver-level
routine and any truly local support it needs. Choosing the BIO-level service
should flash the BIO wrapper plus the PIN routine it imports. Choosing the
SYS-level service should flash the SYS policy wrapper plus the declared chain
below it.

The rule is recursive and boring by design:

```text
select service
find export by hash/name/contract
read imports
for each import, find provider
install missing bodies
apply fixups
test selected entry
```

This is the point where catalog linking starts to feel like a small resident
linker instead of a command shortcut. The hash identifies the requested
contract. The import/export/fixup records explain how to assemble a working
body at the chosen layer.

Concern: The resolver must not infer dependencies only from names like `SYS_`,
`BIO_`, or `PIN_`. Prefixes are useful human tiers, but the executable rule is
the declared import list. If a service does not describe its imports, the first
catalog linker should refuse to pretend it can safely install it.

## Q: Should The First Target Be S, LIFE, Or S Plus Join?

Comment: Prefer `S` plus join.

`S` is the better first catalog-linking pressure test. LIFE is useful because
it is visible and human, but it is also big: board RAM, NMI cleanup, display,
input loop, and app state. `S` is smaller and closer to the real HIMON command
surface. It has the exact pain we want to solve:

```text
S body       real command work
S imports    write/read/flush/ctrl/hex helpers
S baggage    helper payload that should be joined, not carried
```

So the target should be:

```text
S(earch) as the body
HREC_JOIN_EXEC as the first join mechanism
build/map truth as the seed record source
```

That makes `S` the practical bridge:

```text
hrec-join-proof      proves FIND/JOIN/EXEC mechanics
asm-rjoin-proof      proves ASM name hash -> RJOIN/RF sim -> native JSR emit
himon-search-proof   proves S parser/matcher with joined helpers
future S command     proves command-surface use of joined resident support
future RCAT/RREC     generalizes the same idea beyond tiny HREC records
```

Concern: Do not make `S` wait for full RCAT/RREC. That recreates the egg
problem. `S` should consume the current small HREC join path first. Once `S`
can run while joining resident helper routines instead of linking private
copies, it becomes evidence for the fuller catalog record shape.

LIFE remains a later worked example for an interactive member. It is better as
the second or third catalog member, after `S` has made the join path boring.

## Q: Can We Build The Catalog Dynamically Later?

Comment: Yes, but not first.

The future shape can be dynamic: HIMON, onboard ASM, or a catalog maintenance
tool can append or update catalog records as code is built, loaded, promoted,
or retired. That is the desired direction.

The first shape should be seeded instead:

```text
build emits records from map/symbol truth
HIMON scans records
S joins resident helpers
tests prove the joins and behavior
later ASM learns to emit records itself
```

That keeps the first catalog from depending on itself. A dynamic catalog is
the destination; generated seed records are the first road.

Concern: Dynamic catalog writes must eventually obey flash lifecycle rules:
formed, sealed, buried, gone, and later condense/repair. Do not make early
catalog records look casually rewritable if they will live in flash.

## Q: Is RAM Proof Plus L F Proof Enough?

Comment: It is enough for behavior and residency, but not by itself enough for
catalog-linking proof.

For `S`, there are three levels:

```text
RAM proof passes       S parser/matcher behavior works while loaded in RAM
L F proof passes       delivered flash bytes behave the same when resident
join proof passes      S uses joined resident helpers, not private baggage
```

RAM pass plus `L F` pass proves the command body and delivery path. Catalog
linking also needs evidence that the support routines were found through
records and joined correctly.

Good first proof bundle:

```text
same S tests pass in RAM and flash
map/listing shows private helper baggage removed or named
positive joins find WRITE/READ/FLUSH/CTRL/HEX helpers
negative joins reject missing hashes and wrong kind bytes
transcript records the same behavior before and after L F
```

After that, the claim becomes stronger:

```text
S is not just resident
S is resident and joined
```

## Q: Is LIFE-2000 A Kludge Around Linking And Payload Baggage?

Comment: Yes. `LIFE-2000` is a useful kludge. The WDC link path proves the
app body, entry, return behavior, display, input loop, and NMI cleanup. But it
also drags support payload into the standalone image: `SYS_*`, `BIO_*`,
`COR_*`, `PIN_*`, and utility code that a catalog member should normally join
to rather than carry privately.

In your terms:

```text
life body              good proof payload
private support copies baggage from static linking
life-2000-load.bin     useful package, not the final catalog shape
```

Concern: Do not let the loadable BIN become the contract. The BIN proves
"these bytes run at `$2000`." It does not prove "this is a clean catalog
member." A catalog member must say what it imports, what RAM and zero-page it
touches, what entry is public, and what support code is joined instead of
duplicated.

## Q: How do catalog joins start if catalog-linked ASM needs the catalog?

Comment: Start below the catalog, then climb into it. The first working path
is seeded by tools and fixed contracts, not by a fully self-hosted catalog:

```text
fixed boot ABI / WDC link / HREC join proof
  -> build tool emits first records from map/symbol truth
  -> HIMON scans and joins those records
  -> app bodies join resident support instead of carrying it
  -> later onboard ASM emits/updates catalog records itself
```

That makes the catalog a product of proof before it becomes an input to proof.
Early ASM can still assemble code. Early HREC can still join fixed resident
records. Early docs/build scripts can describe records. Once those pieces are
boring, ASM can be trusted to write records.

Concern: If catalog-linked ASM is required on day one, it cannot boot itself.
If static WDC linking is treated as the final answer, the payload baggage
never goes away. Keep both lanes visible:

```text
seed lane     fixed addresses, WDC link, HREC proof, generated descriptors
catalog lane  RCAT/RREC/RBODY imports, joins, fixups, resource records
```

## Q: Where should the first catalog records be created?

Comment: Not inside the first catalog-dependent ASM. Create the first records
outside the target runtime from evidence the build already has:

```text
map file       entry addresses and ranges
symbol file    names and exported labels
source header  purpose, credit, resource claims
QCC/docs       unsettled contract questions
```

Then use a small resident scanner/joiner to consume them on target. That
keeps the first catalog publishable because there is an audit trail:
source -> map -> record -> join proof.

Concern: A record emitted only because the assembler said so is too trusting
for the first pass. The first pass should be boring and inspectable.
Build-side records are allowed to be ugly if they are explicit and checked.

## Q: What Should RYORS Do With A Text-Bearing Executable Record?

Comment: Text is metadata, not a prompt by itself. Current HIMON uses the extra
word on pointer records as human display text for catalog rows and confirmation
messages. A non-human caller such as RYORS should not parse that text, wait on
that text, or treat it as part of the routine ABI.

Current behavior:

```text
K=$03  executable pointer with confirmation path and display text
K=$05  executable pointer with display text and no confirmation prompt
```

Policy direction: automated joins may execute a text-bearing routine only when
the executable contract permits it. `K=$05` is suitable for subroutine services
such as FNV helpers: the text helps `#` and logs, while RJOIN/RYORS ignores it
and calls the entry. `K=$03` is different because it means human confirmation is
part of HIMON's command path; an automated caller should either reject that
record by default or use a separate trusted/privileged path.

Concern: If TEXT ever starts implying interactivity, automated callers will
deadlock or make display strings part of the ABI. Keep confirmation, text, and
call permission as separate contract facts.

## Q: When does this leave QCC?

Comment: Move the settled answer to `DECISIONS.md` when a proof can show:

```text
S/search body runs as the target proof
one caller finds the needed resident helper records
one join validates kind/entry
S uses joined resident support instead of private helper payload
payload baggage is measurably removed or named
```

Until then, this remains QCC. `LIFE_RCAT_MEMBER.md` can keep LIFE-specific
member details; this page keeps the general bootstrap rule.
