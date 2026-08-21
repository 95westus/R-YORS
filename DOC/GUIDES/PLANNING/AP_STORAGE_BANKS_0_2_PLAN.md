# AP Storage Across Banks 0-2

Status: implementation in progress. Host format oracle and read-only inventory
firmware are host- and board-accepted through implementation Slice 2. The
transient single-sector mutation worker is a host-accepted Slice 3 candidate;
destructive board proof is pending.

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
9. AP Store V1 allocates no new permanent RAM ABI cells. It reuses declared
   foreground overlays and existing bank-worker/staging areas under explicit
   ownership rules.

## RAM Ownership And ASM Lifecycle

Read-only inventory does not retain a 24-sector catalog in RAM. The Bank-3
routine scans one sector header or record header at a time, reports rows as it
goes, and uses repeated bounded passes when it must select the newest complete
object generation. Its transient header, record, and best-candidate state fit
in the existing High Tool Overlay `$7C00-$7DBF`.

The RAM bank worker continues to own `$0200-$09FF` while it is active. Loading
or validating a chained package reconstructs at most the frozen 4096-byte AP v2
envelope in the existing `$0A00-$19FF` staging area. No second 4K buffer is
reserved: the worker copies individual flash chunk ranges directly into their
logical offsets in that staging area, restores Bank 3, and the existing AP v2
validator consumes the completed envelope.

Those low ranges overlap ASM's session-owned name tables. Any AP Store operation
that starts the bank selector/worker is therefore terminal for that session;
this includes read-only `APS` inventory even though it does not claim the 4K
staging area. Success or failure requires `ASM NEW` before further assembly or
session reporting. Preflight and operator cancellation occur before claiming
the low-RAM worker/staging lifecycle. This rule avoids hidden permanent RAM and
prevents a destroyed symbol table from appearing resumable.

The supported evidence order is report before store. A session reporter AP is
loaded at `$7000` before `ASM NEW`; after the target reaches END
and SEAL, the reporter runs while `$0200-$19FF` still contains that session's
tables. Control then resumes the post-END shell, PACKAGE writes the target AP v2
envelope into caller-selected RAM, and STORE is the final session operation.
The reporter itself may be an AP and may live in AP Store; it simply must not be
loaded through the table-clobbering low staging path after the target session
has begun.

```text
load reporter AP before ASM NEW
ASM NEW -> assemble -> END -> SEAL
run reporter against intact session tables
resume post-END shell -> PACKAGE -> STORE
ASM NEW before any later assembly/report
```

A later optional ASM entry may automate the first step. Conceptually,
`ASM NEW REPORT` would use AP Store while no ASM session owns the low tables,
load the `ASMREPORT` export at `$7000`, reserve `$7000-$771A` from that
session's output policy, and only then call `ASM_BEGIN`. The exact spelling is
not frozen. It must fail before beginning the session if the reporter is
absent, invalid, or does not fit; it must not silently start without a
requested reporter.

The former fixed `$4800` reporter is historical. Its source and hardware
transcripts remain under `SAMPLES/OLD` and the hardware log, but current builds
do not regenerate a `$4800` S19 or AP package. The current host proof package
is fixed at `$7000`; the separately generated movable ASM-native reporter
remains available for the existing `$4000` load workflow.

LIST may stream output without the 4K staging area, but its selector and reader
still overwrite part of `$0200-$09FF`; it cannot preserve a resumable ASM
session. VALIDATE/LOAD additionally claim the 4K staging area. Resident
request/result cells remain the frozen ASM ABI v1 cells; new AP-store state
stays private to the foreground overlay.

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

The read-only firmware reports an all-`$FF` 16-byte identity area as
`HEADER-FF`, not as an erased sector. Bytes `$0010-$0FFF` are intentionally not
read by inventory, so only CLAIM's later full-sector pass may conclude that a
sector is empty.

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

### Slice 3 Transient Worker Boundary

Single-sector mutation does not consume the remaining 39-byte HIMON resident
margin. A standalone foreground tool is linked at `$7000`, below the `$7C00`
High Tool Overlay, and uses the existing STR8 selector bootstrap at `$F010`.
After bootstrap, all bank changes use the copied `$0203` selector. The tool's
scan, erase, program, polling, and restore control flow executes from RAM; it
never calls Bank-3 flash while Bank 0, 1, or 2 is selected.

The transient request/result card is frozen in
`SRC/ASM/ap-store-v1-worker.inc`. `PREPARE` at `$7000` accepts an operation,
bank, and sector in the `$7C00` card, scans all 4096 bytes, copies the 16-byte
header, classifies it, and records its CRC16. It performs no mutation.
`EXECUTE` at `$7003` requires the operator to set confirmation byte `$A5`,
consumes that byte before selecting the target bank, and repeats the complete
scan. Any classification, policy, or CRC change returns `MEDIA CHANGED`
without mutation.

The provisional operations are deliberately narrower than the eventual
operator UI:

- CLAIM accepts only a completely erased eligible sector and never erases it;
- CONVERT accepts only an occupied sector that is not valid managed storage,
  then erases it explicitly;
- FORMAT accepts only a committed managed header whose bytes `$0010-$0FFF`
  are all `$FF`, then increments its sector generation and erases it. This
  empty-log restriction is the Slice 3 proof that no live object references
  the sector. A later catalog-aware slice may widen FORMAT safely.

CLAIM and CONVERT begin at generation 1. FORMAT rejects generation `$FFFF`
rather than wrapping. After any required erase and full-sector `$FF` verify,
the worker writes and verifies header bytes `$00-$0E`, then programs state
`$FE` last. A failure or power interruption before the state commit leaves an
unavailable erased, partial, corrupt, or staged sector; only the final verified
state transition makes it active. The tool and the `$7000` reporter are
mutually exclusive foreground loads, and every worker invocation remains
terminal for an ASM session.

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

Slices 1 and 2 are host-accepted as of 2026-08-20, and Slice 2 is board-
accepted. Slice 3 CLAIM/FORMAT is board-accepted as of 2026-08-21; explicit
occupied-sector CONVERT remains a separate destructive proof. HIMON's
provisional `APS` command copies one 16-byte header at a time
through a 48-byte RAM reader at `$0300`, classifies it after restoring Bank 3,
and streams all 24 rows. It uses 20 bytes at `$7C00-$7C13`, no 4K staging, and
never writes the bank window. The linked HIMON candidate measures CODE 10819,
DATA 1430, resident 12249 bytes, ending at `$EFD9` with 39 bytes before STR8.
The `APS` spelling is deliberately not frozen until Slice 7.

Board acceptance captured all 24 rows and identical four-bank CRC tables
immediately before and after `APS`; both CRC runs returned `$AC` with zero
failure cells. This proves byte preservation across Banks 0-3 while discovery
continues to inspect headers only in Banks 0-2.

Slice 3 has a host- and board-accepted transient tool. It links 1832 bytes at
`$7000-$7727`, owns card `$7C00-$7C2F`, reuses only the `$0200-$0453` copied
STR8 worker/selector range, and uses no permanent RAM. Entry `$7000` performs
the full-sector 24-row read-only inventory; `$7003/$7006` retain the guarded
PREPARE/EXECUTE mutation lifecycle. The fixed AP v2 artifact exports `APSTORE`
at BODY offset zero with no relocations or imports. Resident `AP` remains the
bootstrap and now admits only `$7000-$7BFF` in addition to its general
`$2000-$4FFF` BODY window. HIMON therefore measures CODE 10844, DATA 1430,
resident 12274 bytes, ending at `$EFF2` with 14 bytes before STR8; resident
`APS` and `Q` remain pending the later size pass. The host oracle passes all 24
inventory rows, all 24 mutation locations, and 50 commit-last interruption
points. On HIMON/ASM-F2 `00.0821(0132)`, sacrificial B1:8 advanced from erased
to persistent ACTIVE generation 1 through CLAIM, then to persistent ACTIVE
generation 2 through managed-empty FORMAT. Complete before/after CRC tables
changed only B1:8, and an immediate unconfirmed second EXECUTE returned `$E7`
without another mutation. The accepted transcript and remaining CONVERT gate
are under `../ASM/AP_STORE_V1_SECTOR_TOOL_BOARD_TEST.md`.

The next implementation target is Slice 4 single-sector
install/list/validate/load. It can use empty managed B1:8 without first
destroying an opaque sector; CONVERT may remain deferred until the operator
names a separately disposable occupied target.

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
