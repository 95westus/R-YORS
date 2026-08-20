# AP Storage Across Banks 0-2

Status: planned; no implementation or flash-format ABI exists yet.

This plan introduces managed AP storage in selected 4K sectors of Banks 0-2
without treating any whole bank as an AP volume. A bank may remain bootable or
otherwise opaque in every sector not explicitly registered as AP storage.

## Settled Scope

- Management is sector-based. Any eligible sector in Bank 0, 1, or 2 may be
  managed; managed sectors need not be adjacent.
- Bank 3 owns the discovery logic and reconstructs its volatile catalog by
  scanning self-identifying managed-sector headers in Banks 0-2. No persistent
  Bank-3 catalog or Bank-3 flash allocation is required.
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
4. Bank-3 recovery code, vectors, and directory are never
   eligible target sectors.
5. An object generation is live only when its committed chunk set has exactly
   one first and last record, contiguous logical coverage, and a complete AP v2
   envelope that passes length and integrity checks.
6. Payload/chunk bytes are written and verified before each chunk record is
   committed. Interrupted work remains unreachable garbage.
7. An AP chain stays within one bank, contains no repeated sector/extent, and
   has exactly the bytes declared by the complete AP v2 envelope.
8. Loading reconstructs or streams the complete envelope through a bounded RAM
   path and runs the frozen ASM ABI v1/AP v2 validator before BODY copy,
   import linking, relocation, or execution.

## Format Design Phase

Do not allocate fixed addresses or write firmware until this phase is reviewed.

### Scan-Reconstructed Discovery Catalog

Bank 3 scans only the eight sector boundaries in each of Banks 0-2. A sector is
managed only when its fixed header signature, bank/sector claim, version,
integrity, and commit byte all validate. Records inside valid managed sectors
provide:

- AP chunks: object id, generation, logical envelope offset, payload length,
  flags, integrity, and commit;
- tombstone: object id and superseded generation;
- sector retirement state in the sector header or a later committed record.

The volatile index groups chunks by bank/object/generation and sorts by logical
offset. It never follows unchecked pointers from flash. This avoids a physical
conflict: Bank 3 has no spare erase sector, and its frozen `$FFB0-$FFEF`
directory has no unallocated persistent catalog space.

Discovery does not search opaque or managed sectors for HIMON resident
`F N (V|$80)` signatures. Banks 0-2 do not host the active HIMON/STR8 routine
catalog. FNV-1a remains part of AP v2 BODY integrity, export-name hashes, and
storage-record integrity; AP exports become discoverable only after their
complete envelope validates.

### Managed-Sector Header And Log

Define a compact header at the beginning of each claimed 4K sector. It must
include a distinct signature, format version, claimed bank and sector, sector
generation, header integrity, and a commit-last byte. The remainder is an
append-only chunk log.

Each chunk record must identify its object/generation, logical envelope offset,
payload length, payload integrity, and record commit. Multiple objects may use
one sector. A large envelope may continue in any other managed sector in the
same bank; logical chunk offsets supply canonical ordering and detect missing,
repeated, or conflicting data.

Freeze exact byte layouts only after calculating worst-case catalog size,
per-sector overhead, maximum chain length, parser RAM, and resident code cost.

### 2026-08-20 Host Format Oracle

The first read-only slice freezes a candidate format in
`SRC/ASM/ap-store-v1.inc`. A managed sector starts with a 16-byte `AS1`
header containing packed bank/sector, generation, full FNV-1a over the six
identity bytes, five reserved `$FF` bytes, and an active-low state byte. Its
append-only `AR` records use a 20-byte
header, payload, and commit-last `$A5`. The header carries type, flags,
object/generation, logical offset, length, payload FNV-1a, and header CRC16.
Record types are CHUNK and TOMBSTONE; chunk flags identify the unique first and
last records.

Sector state starts erased/staged at `$FF`; commit clears bit 0 to make `$FE`.
Later one-way transitions may clear bit 1 for RETIRED (`$FC`) and bit 2 for BAD
(`$FA`), or both (`$F8`). Bits 3-7 must remain set. State is excluded from the
identity FNV so these legal flash transitions preserve sector identity.

An empty managed sector can hold 4059 payload bytes in one record. The frozen
AP v2 maximum remains 4096 bytes, so a maximum-size envelope necessarily uses
at least two managed sectors; this is container overhead, not an AP v2 format
change. One object may use at most eight chunks, matching the eight physical
sectors in one bank.

`make -C SRC ap-store-v1-check` encodes and decodes a golden object split
across nonadjacent Bank-2 sectors `$8` and `$F`, covers a tombstone, rejects a
wrong-bank header, uncommitted header, and corrupt committed record, and pins
the capacity calculation. It performs no firmware build or flash mutation.

## Operation Model

### Inventory And Validation

`LIST` scans and validates managed-sector headers, then builds the volatile
catalog from committed records.
It reports managed, missing, corrupt, retired, opaque, and contradictory states
without mutation. `VALIDATE` additionally walks an object's chain, verifies
chunk coverage and hashes, reconstructs the AP envelope, and invokes AP v2
validation.

### Claim/Convert

Conversion is deliberately not `FORMAT`. It names one opaque `bank:sector`,
shows its current classification and CRC, rejects protected ranges, requires
explicit destructive confirmation, erases and verifies the sector, writes and
verifies its managed header, and commits the header last. Failure before that
commit leaves the sector unavailable.

The command name and confirmation syntax are decided during the operator-UI
slice; the semantic distinction from reformat is mandatory.

An opaque sector is inventoried across all 4096 bytes before mutation. If all
bytes are `$FF`, CLAIM skips erase, writes and verifies bytes `$00-$0E`, then
commits state `$FF->$FE`. If any byte is occupied, ordinary CLAIM returns
`SECTOR OCCUPIED`; only the separate confirmed conversion path may erase it,
after displaying its bank, sector, and full-sector CRC.

### Format

`FORMAT bank:sector` accepts only a sector whose on-sector identity validates.
The reconstructed index must also prove that no live object references the
sector; otherwise it returns `SECTOR IN USE`. It confirms, erases all 4096
bytes, verifies `$FF`, writes a new generation header, and commits state last.
It never adopts an opaque sector.

### Install

`INSTALL` validates the complete source AP v2 envelope before mutation, chooses
appendable extents only from explicitly managed sectors in the requested bank,
writes only into a fully `$FF` append range without erasing, verifies chunks,
validates the reconstructed stored envelope, and
commits each chunk last. The object becomes live only when a subsequent scan
finds a complete valid generation. Allocation may cross sectors but not banks.
Insufficient append-only space leaves no new live generation.

### Delete

`DELETE` appends a tombstone for the named object generation. Old chunks remain
programmed and are not allocation candidates. Listing and loading ignore a
generation only after its valid tombstone is committed.

### Load

`LOAD` resolves the newest live generation from the reconstructed index, validates every sector
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

1. **Read-only format oracle.** Host-accepted candidate: layouts, encoder,
   decoder, initial corruption cases, capacity calculations, and golden
   nonadjacent-chain/tombstone fixtures are frozen. Expand the fault matrix as
   the read-only firmware parser is introduced.
2. **Read-only inventory.** Add a Bank-3-resident discovery routine that uses
   the RAM bank worker to read the 24 candidate sector headers in Banks 0-2
   (three banks times sectors `$8-$F`). It does not scan Bank 3. Prove that
   arbitrary opaque Banks 0-2 remain unchanged.
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
