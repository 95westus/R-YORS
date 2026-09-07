# STR8-N / AP / HIMON / ASM Modularization Plan

Status: proposed implementation sequence, 2026-09-06. No implementation or new
board acceptance is claimed by this plan.

The goal is four clear owners, a small resident system, and measured flash
costs. Start by separating source and interfaces while preserving the current
image layout. Optimize only after establishing a reproducible baseline.
Independent installation is a later decision, not a prerequisite.

## 1. Scope and expected result

| Module | Owns | Placement for the first release |
| --- | --- | --- |
| STR8-N | Reset, recovery, console primitives, bank selection, checked flash mechanisms, vectors and top-sector composition | Existing independent repository; protected Bank-3 sector F |
| AP handling | AP-v2 validation, loading, relocation, typed import linking, entry derivation, manager bootstrap, carrier discovery/storage policy | Resident core linked into the HIMON region; existing APMAN carrier remains external |
| HIMON | Monitor UI, command parsing/dispatch, debugger, resident catalog and resolver, cold/warm initialization, S19 load-only adapter | Existing Bank-3 C-E region |
| ASM | Source parsing, code emission, symbols/fixups, session sealing/relocation, AP package production and assembler UI | Existing Bank-3 8-B region |

AP handling is one logical module with two implementation parts: the resident
loader/linker and the external storage manager. Its basic API should return
status and a loaded entry/result; command adapters decide whether to run it.
Keep current command behavior during extraction, including APMAN's existing
dispatch behavior, before attempting that UI separation.

ASM continues to own relocation of its live assembly session. AP owns relocation
of a serialized package during loading. Similar arithmetic does not establish
that those routines can safely share an implementation.

The first milestone provides source ownership and documented calls with no
required ROM/RAM growth. The next milestone seeks net byte savings. Neither
milestone promises a particular reduction before the code audit.

## 2. Evidence and starting budget

Reference points examined for this plan:

- [Current capabilities](../CAPABILITIES.md): accepted STR8-N 1.31,
  HIMON `00.0906(1935)`, ASM-F2 `00.0905(2321)`.
- [Product boundary](../STR8/PRODUCT_BOUNDARIES.md) and
  [exact STR8-N lock](../../../SRC/INTEGRATION/str8n.lock.json).
- Existing linked maps in `SRC/BUILD/s19/himon-rom-c000.map` and
  `SRC/BUILD/s19/asm-v1-flash-8000.map`.
- [AP/OIL ownership](../AP/AP_OIL_GUIDE.md),
  [APMAN dissection](../ASM/APMAN_APC_DISSECTION.md), and
  [memory map](../MEMORY/MEMORY_MAP.md).

These are starting observations, not a fresh build or flash readback. Phase 0
must associate measurements with exact source and artifact hashes. The memory
map's combined-image section still contains ASM/STR8-N figures from an older
image; do not use those figures as the current size baseline. The APMAN
dissection likewise identifies the older board image behind its measurements.

| Region/component | Observed extent or size | Available space / meaning |
| --- | --- | --- |
| ASM-F2, `$8000-$BFFF` | `_END_DATA=$BD95` exclusive; occupied span 15,765 bytes | 619 bytes to `$C000` |
| ASM build reserve | Makefile requires at least `$0200` bytes to `$C000` | Only 107 bytes of additional growth before the existing guard fails |
| HIMON including resident AP, `$C000-$EFFF` | `_END_DATA=$EE72` exclusive; occupied span 11,890 bytes | 398 bytes to `$F000` |
| STR8-N, `$F000-$FFFF` | Lock pins resident end `$FD27` and 40-byte margin | Whole 4K sector remains recovery-owned; not an AP expansion area |
| Existing APMAN package | `$0B40` = 2,880 bytes; BODY `$0B12` = 2,834 bytes | One full 4K carrier sector; RAM BODY `$7000-$7B11` in the accepted dissection |
| R-YORS distribution payload | Dense `$8000-$EFFF`, 28K | Padding means this file span need not shrink when code shrinks |

ASM and HIMON have 1,017 bytes of combined headroom, but it is split across
their link regions. Do not treat it as one freely allocatable area.

Two important savings opportunities are already partly realized:

1. ASM's `ASM_PACKAGE_LOAD` and parsing adapters already call the published
   HIMON AP service. There are not two complete resident loaders to remove.
2. APMAN already runs as a banked carrier copied to RAM. Moving it out of HIMON
   cannot be counted again as a new saving.

The default resident ASM also excludes the optional full package-check path.
Removing that diagnostic path from another configuration is not a saving in
the default resident image.

## 3. Interfaces and dependency rules

```text
HIMON command adapters -----> AP core -----> STR8-N public services
ASM LOAD / INSTALL --------> AP core
APMAN ---------------------> AP core + approved STR8-N integration
AP core import linking ----> HIMON resident resolver
ASM assembly / package ----> ASM-owned routines
```

There is a controlled two-way relationship: HIMON invokes AP, and AP asks the
HIMON resolver for resident symbols. This is acceptable for the initial static
image if that resolver boundary is explicit. It does not make AP independently
usable without a resolver provider. Do not add a generic service registry or
allocate new callback RAM just to remove that diagram edge.

Preserve these contracts in the first release:

- AP service pointer `$7E2D-$7E2E`, request/result card `$7E2F-$7E40`, and
  operations PARSE `$00`, LOAD `$01`, SUGGEST `$02`, LINK `$03`, MANAGER `$04`.
- Existing status bytes, per-operation carry/register results, validation
  behavior, command syntax, AP-v2 serialized bytes, and APMAN `AM01` identity.
- HIMON entry `$C000`, warm identity marker, resident FNV records, public
  service-vector initialization, and current cold/warm return behavior.
- Exact STR8-N 1.31 lock and generated public contract. `$F006` is the current
  version/capability query; old source comments about an AP-link doorway are
  historical, not authority for a new call.

Write an interface ledger before changing any calls. For every entry list:
inputs, outputs, A/X/Y and flag clobbers, stack use, zero-page and RAM writes,
required bank, return bank, initialization, failure side effects, and whether
the operation may overwrite the command or assembly session.

Define the resolver boundary around the current typed lookup behavior, not
only `THE_JOIN_EXEC_XY`: AP imports include data as well as executable records.
Keep Bank-3 catalog authority and type rejection intact. Prefer a static
adapter with existing workspace for the first implementation.

The AP service remains a foreground, non-reentrant facility. Do not introduce
AP calls from interrupt handlers or promise nested parent/child execution.
On a failed load, the destination may already contain copied or modified bytes;
document actual behavior and never execute a failed result. Atomic rollback
would be a separate feature.

## 4. RAM and banking constraints

Freeze a phase-by-phase ownership table using the current build before moving
any code. At minimum cover:

| Range | Existing role or collision to preserve |
| --- | --- |
| Zero page | ASM and AP/manager scratch overlap; enumerate live callers and save/restore requirements |
| `$0200` worker lane | RAM bank-select/flash workers; size depends on the selected worker artifact |
| `$0300` staging routine | Resident AP copies its bank-read code here; establish lifetime relative to other workers |
| `$0A00-$19FF` | Banked sector staging, overlapping other session workspaces |
| `$1A00-$1AFF` | APMAN command shadow |
| `$2000-$6FFF` | Managed application destination envelope; direct AP uses narrower rules |
| `$7000-$7B11` | Accepted APMAN overlay, overwriting HIMON's `$7A00` command buffer |
| `$7C60-$7C73` | APMAN request/result card |
| `$7DC0-$7DC7` | Locked HIMON AP-link workspace |
| `$7E2D-$7E40` | Published AP service pointer and card |

This table is a hazard checklist, not permission to use gaps. Check all other
allocations in the authoritative map. Preserve the command shadow before
APMAN loads, distinguish manager and child lifetimes, and check arithmetic
overflow and source/destination overlap using the existing per-path rules.

Changing banks replaces the entire `$8000-$FFFF` window. A routine in Bank-3
ROM cannot continue executing there while another bank is selected. Bank
access must run through RAM code and restore Bank 3 before ordinary resident
calls, output, or return. Debug/NMI/IRQ behavior must be included in board
qualification if those paths or their RAM lifetimes change.

## 5. Implementation phases

### Phase 0: reproducible baseline and byte ownership

1. Record repository revision and dirty state, build configuration, tool
   versions, STR8-N lock, and hashes of the input/output artifacts. Preserve
   existing user files and hardware transcripts.
2. Build the current resident image and run the existing checks listed below.
   Preserve its map, S19, BIN, AP packages, and build output as the baseline.
   Keep any old accepted board artifact separate from the new host build.
3. Produce a size ledger from linked sections and emitted bytes: ASM, HIMON
   excluding AP, AP parser/load/relocation/linker, manager bootstrap/staging,
   shared primitives, tables/strings, and external packages. Attribute shared
   routines once. Do not infer exact sizes from assembly source line counts.
4. Record occupied spans, holes, contiguous headroom, padding, AP envelope
   bytes, allocated sectors, RAM high-water marks, and stack bounds separately.
   For unusual linker symbols, reconcile the map with emitted S19 and package
   lengths instead of blindly subtracting `_END_CODE`.
5. Add a repeatable report under `SRC/tools/` if the existing reporting cannot
   express that ledger. Any output under `DOC/GENERATED/` must come from its
   generator. Reconcile the stale current-image figures in the memory map.
6. Audit actual call sites and source-reading checks. In particular,
   `check_himon_banked_ap.ps1` and `check_asm_abi_v1.ps1` need review before
   declarations/routines move out of `himon.asm`.

Deliverable: reproducible baseline, byte ownership table, interface ledger,
and an ordered list of candidate savings with caller dependencies.

Gate: existing tests pass and every claimed size has an identified artifact.
If the baseline fails, resolve or document that failure before comparing a
refactor; never claim a pre-existing failure was introduced or fixed without
evidence.

### Phase 1: extract AP source in place

Proposed layout, subject to the routine audit:

```text
SRC/AP/ap-contract.inc          shared AP constants, if a safe split is useful
SRC/AP/ap-core.inc              parse/load/relocate and result handling
SRC/AP/ap-link.inc              typed import linking
SRC/AP/ap-manager.inc           resident bootstrap and staging
SRC/HIMON/himon-ap-adapter.inc  monitor-facing glue and resolver adapter
SRC/ASM/...                    assembler and package producer
SRC/APPS/apman-7000.asm         existing manager entry/build path retained
```

1. Extract existing blocks through INCLUDEs at their original assembly
   positions. Preserve labels, instruction ordering, data ordering and local
   label scopes. Move scattered constants/data only when that remains safe.
2. Keep the existing public ABI include path. If AP constants gain their own
   file, preserve compatibility through the old include and unchanged values.
   Do not do a global symbol rename in the extraction commit.
3. Add explicit Makefile prerequisites for every new include so editing one
   reliably rebuilds its consumers.
4. Adapt structural checks to read the actual source set or expanded source;
   retain the assertions. A moved implementation must not silently escape
   verification because a checker still reads only `himon.asm`.
5. Compare emitted images. Control build stamps using supported mechanisms or
   account for each known stamp/derived identity difference. Investigate all
   other changed bytes rather than applying a broad comparison exclusion.

Deliverable: AP code has a clear source owner but the same physical placement.

Gate: no unexplained executable/data changes, no required ROM/RAM growth,
unchanged public addresses and behavior, passing regression. An exact image
match can retain the old behavioral evidence; a changed image must be assessed
for the hardware gates below.

### Phase 2: make the call boundaries explicit

1. Route AP's monitor-specific interactions through small named adapters.
   Keep the current resolver and shared primitive implementations in place.
2. Keep HIMON's AP command grammar and execution policy in the monitor adapter.
   Keep ASM's package construction and session state in ASM. Preserve APMAN's
   existing private command-card behavior until separately redesigned.
3. Reduce accidental private-label dependencies one at a time. Use ordinary
   direct calls within the static image where appropriate; use the existing
   published pointer for external clients. Avoid adding a JMP wrapper to every
   small routine merely to make it public.
4. Document which primitives are shared but physically linked with HIMON.
   Shared ownership does not require a fifth resident image or a new registry.
5. Check cold/warm initialization and absent-manager errors. AP core loading
   from directly reachable packages must not require loading APMAN first.

Deliverable: documented AP provider/client contract with bounded dependencies.

Gate: same supported workflow and RAM allocation. Account for every wrapper
byte. Preserve ASM's 512-byte minimum reserve and never grow into sector F.
If an adapter costs space without a concrete compatibility benefit, retain a
documented static call instead.

### Phase 3: measured size reductions

Audit these candidates in order; retain only demonstrated improvements:

| Candidate | Investigation | Reject when |
| --- | --- | --- |
| Repeated local helpers and strings | Equivalent range, length, copy, FNV, or status paths within an image | Entry/exit conversion, clobber preservation or extra calls consume the saving |
| ASM/AP metadata handling | Remaining duplicate resident validation with the same semantics | One routine handles live session structures or an optional diagnostic configuration |
| Manager/monitor glue | Duplicate formatting, parsing or selection helpers | Sharing creates unsafe overlay lifetimes or fragile private external calls |
| Obsolete compatibility code | Complete caller and supported-artifact audit | A supported package or recovery path still needs the entry |
| Embedded worker bytes | Separate recoverable worker mechanism from duplicate stored representation | The locked provider lacks the needed published interface or the proposed RAM execution is unsafe |

The embedded manager worker is a candidate for investigation, not an automatic
deletion. Respect the current integration generator and STR8-N ownership;
using private STR8-N ROM offsets would trade bytes for a broken product
boundary. A new provider service requires its own STR8-N review and lock update.

For each candidate record removed bytes, added code/tables/wrappers, changes
in each link region, external package growth, RAM/stack changes, and execution
cost on frequently used paths. Verify against the linked image, not estimates.
Shared source assembled into two images still occupies flash twice.

Deliverable: small independently reviewable optimizations and a before/after
ledger. Target positive net savings with unchanged capability; do not set an
unsupported kilobyte promise. If no candidate pays for itself, finish with a
size-neutral modular architecture and report that result honestly.

### Phase 4: optional resident-space or product variants

Proceed only after Phases 0-3 have a stable result and there is a concrete space
requirement. Evaluate one option at a time:

| Option | Potential gain | Additional work |
| --- | --- | --- |
| Runtime build: HIMON + AP, ASM omitted | Removes the ASM occupied span from that installed configuration | Remove stale ASM command/catalog entries, test absent-provider behavior, define low-region image/padding and installation rules |
| Move additional infrequent AP tooling into packages | Frees measured Bank-3 bytes | Available carrier sectors, package overhead, staging/overlay map, missing-tool recovery and load latency |
| Consolidated AP Store manager | May reduce duplication among installed tools | Existing queue item; all overlay, media, interruption and return contracts still required; no assumed byte saving |
| Independently installable resident AP image | May simplify replacement | Dedicated flash allocation, stable ABI, mixed-version matrix, interrupted multi-sector update/recovery plan |

Omitting ASM preserves runtime capability but changes the product feature set.
Moving it into a package is a separate and substantially harder project: the
current roughly 15.4 KiB resident span exceeds the simple 4K carrier limit,
and its RAM placement would collide with existing source/session/overlay
allocations unless redesigned. Do not promise drop-in banked ASM.

Four logical modules do not imply four erase-sector allocations. Reserving an
extra sector or adding one small carrier can increase allocated flash even if
useful code bytes fall. Preserve the direct resident AP bootstrap; an AP loader
stored only in a package that requires that loader creates a circular startup
dependency.

Gate: an explicit placement proposal with measured sector costs, a complete
RAM lifetime map, supported missing-component behavior, and installation and
recovery cards. Do not execute a placement change as part of source extraction.

## 6. Validation and acceptance

Use the existing targets as the starting set:

```text
make -C SRC asm-test
make -C SRC himon-banked-ap-check
make -C SRC himon-str8-record-check
make -C SRC board-s19-check
git diff --check
```

Run focused checks after each relevant change and the full suite at each
integration milestone. Regenerate `routine-word-tree` when source ownership
changes affect that hierarchy. Extend existing behavior checks only where a
changed boundary introduces uncovered failure modes; a docs-only plan does
not require assembly regression.

| Path | Required evidence for changed executable behavior |
| --- | --- |
| AP parsing | Valid packages, malformed lengths/tags/version, bad FNV, invalid entry/type and boundary arithmetic; preserve current rejection behavior |
| AP loading/linking | Internal ABS16/LO8/HI8 relocation, typed imports, missing/wrong-kind resident symbol, overlap/protected-range rejection, no execution after failure |
| ASM client | Assemble, END/SEAL, PACKAGE, LOAD; session state and command return survive allowed operations; diagnostics and numeric status ABI remain correct |
| Manager bootstrap | Manager found/absent/corrupt, command shadow, overlay collision, bank restoration; preserve accepted discovery rules |
| Carrier operations | APS, named and address selection, AP L, AP run, install and persistence after reset; protected/opaque media behavior retained |
| Monitor/recovery | Cold and warm start, physical RESET through STR8-N, debugger smoke, bare L then explicit G, return to monitor after AP success/failure |
| Packaging | Exact payload range/identity, reserved sector/config preservation, map guards, old AP-v2 fixtures still load |

For board changes, prepare an exact-image card after host gates pass. Record
identities/readback, reset and representative ASM/AP/debug behavior. If flash
mutation or bank workers change, additionally use identified eligible test
media, before/after sector CRCs, error-path Bank-3 restoration and the relevant
existing interruption/recovery tests. Do not erase arbitrary sectors to make
room. Existing transcripts remain intact; append evidence for the candidate.

Maintain a recoverable previous payload and matching manager artifacts. An
initial static extraction uses the existing coordinated R-YORS payload update
path. Do not claim arbitrary mixed HIMON/AP versions are supported just
because their sources now live in different directories.

Before acceptance, update [ASM TEST_PLAN](../ASM/TEST_PLAN.md) for changed
phases, contracts or required board proof, plus current AP/OIL ownership,
HIMON map and memory documentation. Update feature checkboxes only when source,
measured size, host checks, documentation and applicable board proof agree.

## 7. How savings will be reported

Keep three separate comparisons for identical feature sets:

1. **Bank-3 saving:** old occupied bytes minus new occupied bytes, with each
   region and its contiguous headroom listed separately.
2. **Total stored-byte saving:** old resident and required external payload
   bytes minus new resident and required external payload bytes, including
   metadata, adapters, duplicated helpers and worker storage.
3. **Allocated-sector saving:** old required sectors minus new required
   sectors, accounting for carrier granularity, reservations and packing.

Also report ROM address span, dense distribution size, required RAM, and any
removed features. Never equate a smaller S19 text file with reduced hardware
flash requirements. A byte optimization can increase headroom while releasing
zero sectors; that is still useful, but it is a different result.

Example only: removing 300 resident bytes and adding 340 packaged bytes frees
300 bytes in Bank 3 but increases total stored bytes by 40. If that package
needs a new carrier, it also consumes a 4K sector. These are illustrative
numbers, not a forecast for this refactor.

## 8. Work packages and stop points

Suggested small commits: baseline reporting; interface/ownership ledger;
in-place AP core extraction; manager/linker extraction; adapter cleanup; one
measured optimization per commit; final documentation and acceptance evidence.
Keep a source move separate from a functional rewrite.

Planning estimates for one developer familiar with the workbench, assuming a
working toolchain and prompt access to the board:

| Work | Active effort estimate |
| --- | --- |
| Phase 0 baseline and interface audit | 1-2 working days |
| Phase 1 source extraction and checker/build updates | 1-3 days |
| Phase 2 explicit boundaries and compatibility checks | 2-4 days |
| Phase 3 one bounded optimization pass | 2-5 days |
| Integration documentation and board qualification | 1-3 days plus bench availability |

That is approximately 7-17 active working days for the recommended scope,
with Phase 3 bounded to worthwhile candidates. It is an estimate, not a
delivery commitment. Phase 4 needs its own estimate after placement and ABI
decisions; do not bundle it into this range.

Stop or narrow the affected change if the baseline is not reproducible, a
public contract would change without a compatibility plan, a scratch lifetime
cannot be made safe within the existing map, or measured wrappers outweigh the
proposed saving. Retain completed, verified source separation even if further
size optimization is not worthwhile.

The recommended implementation starts with Phase 0, then a size-neutral AP
extraction. Its completion report must distinguish four outcomes: cleaner
ownership, bytes saved, sectors released, and any feature/configuration change.
