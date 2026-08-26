# Banked AP Carrier Versus AP Store

Both paths persist the same AP v2 envelope in flash and eventually feed that
envelope to the same AP loader. They differ in how the envelope is stored,
found, updated, and recovered.

## Short distinction

```text
Banked AP carrier = one raw AP envelope at a known bank/sector address
AP Store          = managed objects inside append-only sector records
```

Use a carrier when a small program needs one stable, explicitly assigned
address and direct execution is desirable. Use AP Store when programs need
object identity, generations, catalog lookup, chaining, deletion history, and
managed capacity.

## Comparison

| Property | Banked AP carrier | AP Store V1 |
|---|---|---|
| Stored bytes | AP v2 envelope begins directly at the sector base | AP envelope is payload reconstructed from store records/chunks |
| Addressing | Physical bank plus address, such as `B2:$8000` | Object number plus generation, with newest-generation lookup |
| Run path | `AP B2 $8000 $4000` | Run APNEW, select/reconstruct object, validate it, then load/run it |
| Current package size | `$0005-$00FF` through Bank Maintenance `P` | Up to `$1000`, including a multi-sector chain |
| Sector use | One assigned package at the base; remaining bytes are preserved but unmanaged | Multiple append-only records share managed sectors |
| Metadata | Only the AP envelope's own header, seal, exports/imports, and entry identity | Store sector header, object/generation records, chunk metadata, CRCs, lifecycle state, and AP envelope data |
| Updates | Erase/rebuild the carrier sector, then put the replacement | Append a newer object generation; older records become stale |
| Delete | Erase/reclaim the carrier sector | Append a tombstone; replay is rejected and history remains inspectable |
| Discovery | Operator must know `bank:address` | LIST/VALIDATE and newest/exact-generation lookup |
| `APS` view | `UNMANAGED`, because there is no AP Store sector header | `+ G=nnnn`, WORK, or another managed role |
| Failure model | Small exact-address operation; no catalog transaction | Read-only plan, explicit confirmation, commit-last append, CRC/request recheck, and replay rejection |

## Banked AP carrier

Bank Maintenance `P` is the current carrier writer. In the combined menu it
reads one AP v2 envelope from RAM `$7000`; the standalone tool reads `$4000`.
The operator supplies a Bank 0-2 sector-base destination by typing the exact
target, for example:

```text
TYPE PUT BnS000 (n=0-2,S=8-F)> PUT B28000
```

Before programming, `P` verifies the AP signature/version and current
`$0005-$00FF` length policy, rejects configured WORK/BKUP sectors, stages the
target sector, and requires every byte occupied by the envelope to be erased.
It overlays only the envelope and preserves the rest of the 4K sector.

After a cold boot, HIMON can address that envelope directly:

```text
AP B2 $8000 $4000
```

HIMON stages the banked source, validates the AP envelope, loads its body into
RAM, applies relocations/imports, and runs its entry. The body never executes
in place from banked flash. `AP` also performs the run; no following `G` is
needed.

`PACKAGE MAIN $7000` gives the AP an entry identity, but the current carrier
run command is still address-based. There is no carrier catalog, allocator,
generation selection, tombstone, or automatic relocation to another flash
hole. Bank Maintenance `P` also does not modify the STR8 whole-bank directory.

The complete LED carrier example is
[PIA_LED_BANKED_AP_CARD.md](PIA_LED_BANKED_AP_CARD.md).

## AP Store V1

AP Store manages TWS sectors rather than reserving one raw address per AP.
Sector headers establish managed/active generations. Append-only records name
an object and object generation; larger packages are divided into ordered
chunks and may span selected sectors. Readers find the newest or an exact
generation, reconstruct the original AP envelope, validate it, and load/run
it from RAM.

Installation and deletion are deliberately multi-step. A read-only planner
checks the request, current media, capacity, chain layout, and CRCs. A separate
confirmation authorizes the executor. The executor rechecks the snapshot and
commits last; immediate replay fails closed. Deletion appends a tombstone
instead of erasing the old bytes. This costs code, RAM staging, records, and
operator steps, but provides the lifecycle machinery absent from a carrier.

The same LED body has a complete AP Store path in
[AP_STORE_V1_FULL_CYCLE_BOARD_TEST.md](AP_STORE_V1_FULL_CYCLE_BOARD_TEST.md).
That card installs it as object `$0003`, generation `$0001`, cold-boots,
performs newest-generation lookup, reconstructs the `$00A3` envelope, and
runs it.

## Choosing between them

Choose a banked carrier when all of these are true:

- the AP is at most `$00FF` bytes under the current `P` policy;
- a fixed physical address is acceptable;
- one explicit erase/update operation is acceptable;
- direct `AP Bn pkg dst` execution is useful;
- catalog, generations, and delete history are unnecessary.

Choose AP Store when any of these are needed:

- packages larger than the carrier limit or packages that require chaining;
- multiple objects sharing managed flash capacity;
- newest/exact-generation selection;
- append-only replacement and tombstone deletion;
- inventory, validation, recovery planning, or replay protection.

A carrier is therefore a deployment slot. AP Store is a storage system. The
carrier is the right small example and recovery-friendly bootstrap; AP Store
is the path for a growing managed application collection.
