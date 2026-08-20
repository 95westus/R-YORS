# AP Storage Across Banks 0-2

Status: planned; no implementation or flash-format ABI exists yet.

This plan introduces managed AP storage in selected 4K sectors of Banks 0-2
without treating any whole bank as an AP volume. A bank may remain bootable or
otherwise opaque in every sector not explicitly registered as AP storage.

## Settled Scope

- Management is sector-based. Any eligible sector in Bank 0, 1, or 2 may be
  managed; managed sectors need not be adjacent.
- Bank 3 owns the discovery catalog. Each managed target sector also carries
  its own identity, bank/sector claim, format version, generation, integrity,
  and commit-last state so catalog claims can be cross-checked against media.
- Stored objects are complete, byte-for-byte AP v2 envelopes. Storage metadata
  wraps an envelope but does not split its AP metadata from its BODY.
- One AP envelope may occupy an ordered chain of arbitrary managed sectors in
  one bank. A chain may not cross a bank boundary.
- Formatting applies only to a sector already recognized as managed AP
  storage. Converting an opaque sector is a separate, explicit destructive
  operation.
- Initial mutation is append-only. Delete records a tombstone; it does not
  erase or reclaim payload bytes. Compaction is deferred.
- Compression is not required and is outside the initial design.

## Safety Invariants

1. An unregistered or invalidly identified sector is opaque. AP discovery,
   allocation, format, delete, and validation must not write it.
2. No operation infers that a neighboring sector is free or managed.
3. Every mutation names an explicit bank and sector set and executes through a
   RAM-resident bank worker. Code never changes banks while executing from the
   flash window.
4. Bank-3 recovery code, vectors, directory, and catalog storage are never
   eligible target sectors.
5. A catalog entry is live only when its commit marker, generation, chain,
   envelope length, and integrity checks agree with all referenced sectors.
6. Payload/chunk bytes are written and verified before their catalog record is
   committed. Interrupted work remains unreachable garbage.
7. An AP chain stays within one bank, contains no repeated sector/extent, and
   has exactly the bytes declared by the complete AP v2 envelope.
8. Loading reconstructs or streams the complete envelope through a bounded RAM
   path and runs the frozen ASM ABI v1/AP v2 validator before BODY copy,
   import linking, relocation, or execution.

## Format Design Phase

Do not allocate fixed addresses or write firmware until this phase is reviewed.

### Bank-3 Discovery Catalog

Specify an append-only catalog held in Bank 3 with records for:

- managed-sector claim: target bank, sector, sector-format version, generation,
  and expected sector-header integrity;
- AP object: stable object id, generation, AP-envelope length and FNV, ordered
  extent list, and live commit marker;
- tombstone: object id and superseded generation;
- sector retirement: a managed sector that must no longer receive allocations.

The address survey must choose catalog storage that does not overlap STR8,
HIMON, ASM-F2, vectors, directory, or recovery state. Define exhaustion and
recovery behavior before selecting the address.

### Managed-Sector Header And Log

Define a compact header at the beginning of each claimed 4K sector. It must
include a distinct signature, format version, claimed bank and sector, sector
generation, header integrity, and a commit-last byte. The remainder is an
append-only chunk log.

Each chunk record must identify its object/generation, logical envelope offset,
payload length, payload integrity, and record commit. Multiple objects may use
one sector. A large envelope may continue in any other managed sector in the
same bank; the Bank-3 object record supplies canonical ordering, while chunk
offsets independently detect missing, repeated, or reordered data.

Freeze exact byte layouts only after calculating worst-case catalog size,
per-sector overhead, maximum chain length, parser RAM, and resident code cost.

## Operation Model

### Inventory And Validation

`LIST` reads the Bank-3 catalog, then cross-checks each claimed sector header.
It reports managed, missing, corrupt, retired, opaque, and contradictory states
without mutation. `VALIDATE` additionally walks an object's chain, verifies
chunk coverage and hashes, reconstructs the AP envelope, and invokes AP v2
validation.

### Claim/Convert

Conversion is deliberately not `FORMAT`. It names one opaque `bank:sector`,
shows its current classification and CRC, rejects protected ranges, requires
explicit destructive confirmation, erases and verifies the sector, writes and
verifies its managed header, commits the header last, and only then appends the
Bank-3 claim. Failure before both commits leaves the sector unavailable.

The command name and confirmation syntax are decided during the operator-UI
slice; the semantic distinction from reformat is mandatory.

### Format

`FORMAT bank:sector` accepts only a sector whose Bank-3 claim and on-sector
identity already agree. It confirms, erases, verifies, writes a new generation
header, commits it last, and appends the matching catalog generation. It never
adopts an opaque sector.

### Install

`INSTALL` validates the complete source AP v2 envelope before mutation, chooses
appendable extents only from explicitly managed sectors in the requested bank,
writes and verifies chunks, validates the reconstructed stored envelope, and
commits the Bank-3 object record last. Allocation may cross sectors but not
banks. Insufficient append-only space fails without changing the live catalog.

### Delete

`DELETE` appends a tombstone for the named object generation. Old chunks remain
programmed and are not allocation candidates. Listing and loading ignore a
generation only after its valid tombstone is committed.

### Load

`LOAD` resolves the newest live generation from Bank 3, validates every sector
and chunk, reconstructs or streams the exact AP v2 envelope through bounded
RAM, then calls the existing HIMON AP service. No partial BODY is made
executable on validation or import failure.

## Why Compaction Is Deferred

Flash erase affects a whole 4K sector. Reclaiming deleted chunks therefore
requires copying every still-live byte elsewhere, committing replacement
chains, erasing old sectors, and retiring old generations while remaining
recoverable after power loss at each boundary. That is a separate transactional
feature, not a small extension of delete.

V1 consequently never reuses tombstoned or interrupted extents. Space is
recovered only by explicitly formatting an already managed sector after the
operator has removed or relocated every live object that references it. A
later compactor must use copy-verify-commit-retire ordering and needs its own
host fault matrix and board proof.

## Implementation Slices

1. **Read-only format oracle.** Finalize layouts and build a host encoder,
   decoder, corruption matrix, capacity calculations, and golden fixtures.
2. **Read-only inventory.** Add Bank-3 catalog scanning plus bank-worker sector
   header reads. Prove that arbitrary opaque Banks 0-2 remain unchanged.
3. **Single-sector claim and format.** Implement the separate destructive
   conversion and managed-only reformat paths with commit-last fault tests.
4. **Single-sector install/list/validate/load.** Store complete small AP v2
   envelopes and reuse the frozen ABI validator/loader.
5. **Arbitrary-sector chaining.** Add ordered extent records, multi-sector
   reconstruction/streaming, duplicate/gap/cycle rejection, and same-bank
   enforcement.
6. **Delete and exhaustion.** Add tombstones, generation selection, stale-space
   reporting, and deterministic no-space behavior without reuse.
7. **Operator hardening.** Freeze command syntax, confirmations, diagnostics,
   cancellation behavior, and recovery instructions.

Each slice must measure STR8/HIMON/ASM resident CODE, DATA, UDATA, worker size,
catalog capacity, and maximum RAM staging. A slice does not advance if it moves
an ASM ABI v1 address or changes AP v2 bytes.

## Acceptance Gates

Host tests must cover all Banks 0-2 and sectors `$8-$F`, nonadjacent chains,
coexistence with opaque sectors, catalog/header disagreement, wrong-bank and
wrong-sector headers, stale generations, interrupted writes at every commit,
duplicate/missing/reordered extents, corrupt hashes, AP errors, full catalog,
full sector, and no-space rollback. They must prove byte-for-byte preservation
outside the selected managed sectors and Bank-3 catalog cells.

Board proof starts with sacrificial Bank 2 sectors chosen from a recorded CRC
inventory. It proceeds read-only first, then one explicit claim, format,
single-sector install/load, nonadjacent multi-sector install/load, delete, cold
reset, and recovery inventory. Every destructive step records before/after
CRCs and preserves a known Bank-3 recovery image. Raw transcripts are appended
to `DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`; earlier evidence is not rewritten.

## Explicitly Deferred

- compaction or garbage collection;
- cross-bank AP chains;
- automatic conversion of opaque sectors;
- compression;
- unattended allocation or boot policy;
- changing the ASM ABI v1 service card or AP v2 envelope format.
