# R-YORS TODO

## ASM Feature Queue

Review this checklist before starting any ASM feature implementation. An item
stays unchecked until its source, regression tests, documentation, resident
size measurement, and required hardware proof are complete.

### Candidate: APMAN bank/sector LED activity

- [ ] Accept APMAN's banked-media activity display on hardware. The common
  `APMAN_STAGE_RAW` path publishes `SECTOR|BANK` to PIA Port A before its
  checked bank selection, so `AP`, `AP L`, `AP D`, and `APS` expose each
  staged sector without delays or changes to the bank-selector ABI. The
  focused linked-byte check and `make -C SRC apman` pass with BODY `$0BFC`,
  end `$7BFC` exclusive, package `$0C2A`, and four bytes remaining below the
  `$7C00` overlay limit. COM4 accepted the guarded B2:8 erase/install, exact
  `$0C2A` discovery and inspection, full `APS`, `AP L`, named BANKAUDIT
  execution, CRC report, Bank-3 restoration, and return to HIMON on 2026-09-10.
  Remaining board proof: operator-observed Bank 0-2/sector LED changes and a
  physical-reset recovery.

### Candidate: Peter Jennings Microchess AP

- [ ] Accept the fixed-load `$2000` Microchess AP on hardware. The port retains
  Peter Jennings' copyright, redistribution conditions, disclaimer, Daryl
  Rictor serial adaptation credit, and Bill Forster OCR-correction credit. The
  WDC source and onboard `.a`, `$0625`-byte BODY, `$06A6` AP-v2 envelope,
  package FNV32 `$011A81B8`, three published HIMON console imports, complete
  routine guide, exact host/onboard package comparison, structural checks, and
  py65 opening/human/off-book-search runtime smoke agree. COM4 proof now covers
  the preceding `$05E6` build's exact onboard assembly and package load at
  `$3000`, complete board rendering, opening and human moves, searched reply,
  and `Q` return with `A=$AC/C=1`. The help-enabled build now has exact onboard
  assembly, `$06A6` packaging, RAM load/link/entry, board rendering, and exact
  `H` command/copyright/AI text proof. Remaining proof: install this build in a
  carrier, physically reset, then confirm named discovery and execution
  through STR8-N/HIMON. See
  [MICROCHESS_AP.md](../ASM/MICROCHESS_AP.md).

### Accepted: live HIMON USB indication

- [x] Replace HIMON's private blocking input call with cooperative nonblocking
  polling so PWE# changes update `$21`/`$43` during an existing wait. Preserve
  latched `$07` while the host remains present, cover single-character waits,
  retain raw FTDI LED neutrality, and let ASM-F2 inherit the behavior through
  HIMON's line-input service. Source, focused linked-byte checks, documentation,
  size measurement, and the full host suite agree. COM4 accepted live HIMON
  `$43/$21/$43`, latched-RX `$07/$21/$43`, ASM-F2 `$43/$21/$43`, confirmation
  `$0B/$21/$43`, guarded C-E install, and physical-reset recovery on 2026-09-10.

### Accepted: ASM-F2 text diagnostics

- [x] Replace interactive numeric errors with compact words, preserving the
  numeric return ABI. Test all status bytes, context-specific SEAL errors,
  source rollback, command failures, message addressing, and ROM headroom.
  Exhaustive native/seal/AP/unknown-status host checks and real-source
  rollback/exhaustion/workflow checks pass. ROM grows 106 bytes to `$BD95`,
  with no RAM growth. Full regression and payload identity checks pass with
  the exact STR8-N 1.30 lock. COM4 diagnostics, exact flash readback, physical
  RESET through STR8-N/HIMON, and post-reset ASM smoke all pass (2026-09-05).
  Evidence is tracked in
  [TEST_PLAN.md](../ASM/TEST_PLAN.md).

### Accepted: STR8-N-owned HIMON S19 parsing

- [x] Route HIMON's bare `L` command through the published STR8-N `SR/02`
  buffer parser at `$F009`. HIMON retains its `$7A00` destination ceiling,
  validate-before-copy application, poisoned-session drain, byte accounting,
  S9 entry report, and no-auto-execute policy. The source, generated public
  ABI, structural host check, documentation, and resident size measurement are
  complete. The boundary/error/poison/Ctrl-C card and physical-reset ownership
  gate passed on COM4 on 2026-09-02; retained evidence is in
  `DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`.

### Next session: AP storage across Banks 0-2

Implementation authority: [AP_STORAGE_BANKS_0_2_PLAN.md](AP_STORAGE_BANKS_0_2_PLAN.md).
The plan freezes the settled direction: sector-granular coexistence, Bank-3
discovery plus per-sector identity, complete AP v2 envelopes, arbitrary
same-bank sector chains, managed-only format, separate explicit conversion,
append-only delete, and deferred compaction.

- [ ] Specify AP storage for selectable Banks 0, 1, and 2. A bank may instead
  contain a foreign/opaque image; AP discovery and mutation must identify the
  bank role and refuse to treat a foreign image as an AP store.
- [ ] Define the AP-store identity, catalog/allocation records, integrity and
  commit-last rules, and the explicit destructive operation that converts an
  opaque bank or region into managed AP storage.
- [x] Allow an AP Capsule to span sectors inside one bank, but initially forbid
  one capsule from crossing a bank boundary. Do not implement this by merely
  raising the current `$1000` package check: define multi-sector reading,
  staging/streaming, flash programming, validation, and recovery behavior.
- [x] Keep compression/decompression out of the required design. It is a
  possible long-term stored encoding only, and may never be implemented.
- [x] Decide whether the stored unit is (a) the complete AP envelope or (b) an
  installed/split form whose AP metadata names a separately placed BODY.
  For a split form, specify BODY bank/address/length, bind it to its metadata
  with an integrity value, and distinguish storage placement from load/run
  relocation.

Current evidence (2026-08-21): format-oracle and read-only-inventory host
slices pass. The HIMON `APS` path scans exactly 24 headers without
flash mutation and measures its resident/RAM cost. Its functional board scan
and matching before/after four-bank CRC tables pass, completing Slice 2. These
queue items remain open. Slice 3 now has a 1832-byte transient inventory plus
CLAIM/CONVERT/FORMAT host candidate, packaged as fixed AP v2 `APSTORE` at
`$7000`, with 24-row inventory, 24-location mutation, and 50-cut commit-last
coverage. Resident `AP` accepts the dedicated `$7000-$7BFF` tool tray as a
BODY destination. Its board AP-bootstrap, sacrificial B1:8 CLAIM, generation-1
persistence, empty-managed FORMAT, generation-2 persistence, one-shot
confirmation, and whole-bank CRC isolation proofs pass. Occupied-sector
CONVERT remains pending. Slice 4 now has a separate 2544-byte `APOBJ` host
candidate at `$7000-$79EF`, 16 bytes below HIMON's command buffer: it parses
before write, appends one complete AP v2
package as a commit-last record, lists, reconstructs, validates, and loads/runs
it through the frozen AP service. The host model covers a valid-log no-space
case and all 76 write interruption points. The operator approved B1:8-E test
media. B1:9 CLAIM, append, LIST, reconstruction, validation, and LOAD/RUN pass;
the corrected `$D7` failure-status return and cold persistence also pass. The
final CRC table changed only B1:9 (`3E 40` to `15 69`, CRC `$403E` to `$6915`)
and preserved all other 31 sectors, completing Slice 4 board acceptance.
Slice 5 arbitrary-sector chaining, Slice 6 delete/exhaustion, and the final V1
Slice 7 operator hardening are host- and board-accepted. Slice 7 freezes `APS`
as AP Status, protects B1:E/B1:F, and removes `Q`.

Slice 5 is host- and board-accepted with no on-media format or ASM ABI
change. A single-bank sector mask names the allowed arbitrary sectors;
deterministic allocation emits at most one logical extent per sector. PLAN
snapshots every used tail and sector CRC, partial committed prefixes remain
non-live, and a retry must use a new generation. Separate `$7000` installer
and reader APs
share card `$7C80-$7D3F` to remain below HIMON's `$7A00` command buffer. The
golden model fills B1:9 with `$0F8F` bytes and continues `$0071` bytes in
nonadjacent B1:B, covering all 4,138 interrupted byte-write boundaries. The
separate installer and reader link at `$7000-$7900` and `$7000-$7825`; their
AP envelopes, `$4000` carriers, exact `$1000` fixture, static mutation split,
and self-contained named-file/full-helper-S19 board card pass host checks.
On board, PLAN produced exact nonadjacent B1:9/B1:B rows, confirmed EXECUTE
returned `$AC`, replay returned `$D7`, and LIST/VALIDATE/LOAD/RUN passed both
live and after `HCOLD`. Only B1:9/B1:B changed across the complete CRC table,
to `$65C3/$60E7`; all other 30 sectors remained exact. Slice 6 delete and
exhaustion is next.

Slice 6 contract review is complete. DELETE targets one exact nonzero
generation and appends one 21-byte commit-last tombstone in the first fitting
sector of an explicit same-bank mask. Reader generation `$0000` selects the
newest visible generation; deleting it exposes the next older valid generation.
The object/mask report separates LIVE, STALE, FREE, and BLOCKED physical bytes,
and only FREE is reusable. Incomplete newer generations do not hide an older
live generation, while a complete AP-invalid newer generation is an integrity
error rather than an implicit rollback. Implementation should favor separate
fixed transient AP variants and shared primitives to minimize each loaded
image; no resident RAM or ABI allocation is authorized.

The regenerated host candidate follows that split: APNEW is 2485 bytes,
read-only APPLAN is 2418 bytes, and APDEL is 1856 bytes. All end below
`$7A00`; only APDEL
contains byte-program code, and both APPLAN/APDEL enter safely through an inert
`$7000` stub before their `$7003` operation. The host model covers all 21
tombstone interruption cuts, newest/exact visibility, older-generation
fallback, AP-invalid rollback refusal, exact LIVE/STALE/FREE/BLOCKED counts,
repeat-delete `$E1`, and no-space without reuse. The first board attempt found
that PLAN cleared its live exact generation before snapshotting; APDEL rejected
the resulting zero-generation request with `$D0` before flash. The revised
planner restores the resolved generation and clears success diagnostics.
Confirmed board execution returned `$AC`, replay returned `$D7`, exact lookup
returned `$E1`, and newest LIST/VALIDATE returned `$DB/$DB` before and after
`HCOLD`. Only B1:B changed CRC, from `$60E7` to `$37A8`; a read-only stage
showed the exact tombstone at offset `$0096`.

The Slice 7 role policy is host- and board-accepted. Bank 3 publishes `$FFF0=$1E`
(B1:E WORK) and `$FFF1=$1F` (B1:F protected Bank-3:F backup); `$FFF2-$FFF9`
remain erased. Resident `APS` and transient `APSTORE` report `= WORK` and
`= BKUP B3F`, and every AP mutation or explicit sector mask rejects both. The
22 remaining Bank-0/1/2 mutation
locations pass; Slice 5/6 mask `$0A` remains valid because it selects only
B1:9 and B1:B. The 2026-08-25 board transcript confirms `$FFF0=$1E`, B1:E
`WORK`, successful Slice 6 operation on only B1:9/B1:B, and cold persistence.
The 2026-08-26 Slice 7 transcript confirms `$FFF0-$FFF9 = 1E 1F FF FF FF FF
FF FF FF FF`, the complete compact 24-row `APS` display, warm reset, retained
B1:F backup, and `Q` rejection through `HSH_NF!`.

### Next major pass: consolidated AP tooling

- [ ] Modularize STR8-N / AP handling / HIMON / ASM using
  [FOUR_MODULE_PLAN.md](FOUR_MODULE_PLAN.md). Start with a reproducible byte
  and interface baseline, then extract resident AP routines in place. Preserve
  the current ABI and memory layout; count flash savings only after linked
  measurements. Banked relocation and independent installation are separate
  later decisions. This item does not mark the AP Store consolidation or
  scoped FNV-search gates complete.

- [x] Add the simple carrier path `SEAL> INSTALL package Bn` for Banks 0-2.
  The proven implementation finds the first completely erased and unreserved 4K
  sector, keeps exactly one complete AP v2 envelope there, treats `Bn` as the
  in-command confirmation, runs bank selection/program/verify entirely from
  RAM, restores Bank 3, and prints the exact selected location. `AP Bn name`
  and `AP Bn address` execute after reset; `AP L` loads/fixes without running.
  It does not require transient helpers, request cards, generations, or a
  separate PREPARE/EXECUTE program. The B1:C `$0299` BANKAUDIT install,
  reset, named load/link/execute, repeated 32-sector CRC report, and B3
  restoration completed the board proof on 2026-08-26.
- [ ] Design one persistent AP Store operator menu/dispatcher that replaces
  the overlapping `$7000` transit images without changing V1 media bytes. It
  may be another APC loaded into RAM through the carrier path.
- [x] After the current APMAN/APC/APS board cycle passes, publish a complete
  inspection/dissection package for the proven image: physical Bank 0-3 and
  sector-role maps; the B2:8 carrier-sector byte map; AP v2 envelope/header,
  section, BODY, entry, relocation, export/import, FNV, and erased-tail maps;
  APMAN's resident-flash, staging-RAM, overlay, command-card, worker, and HIMON
  service ranges; and install/list/load/fixup/execute flow diagrams. Include
  exact addresses, lengths, hashes, ownership, overwrite hazards, and captured
  board output rather than schematic-only descriptions. Published as
  `ASM/APMAN_APC_DISSECTION.md`; BANKDUMP provides the accepted read-only
  inspection/dump path for APMAN itself.
- [x] Add a read-only APMAN carrier inspection command after that baseline is
  hardware-proven. Preferred command shape is `AP D Bn name|s000`: validate
  the selected carrier exactly as `AP` does, print its parsed AP v2 metadata
  and section boundaries, then produce a bounded hexadecimal dump of the
  envelope. `AP D B2 APMAN` must therefore inspect and dump APMAN itself.
  The command must never load, execute, erase, program, or alter directory/AP
  Store state. Decide separately whether an optional raw whole-sector dump is
  useful; do not make 4K of `$FF` the default output.
  APMAN accepts both named and sector-address `AP D`
  selectors through its existing stage/validate path, reports the five AP-v2
  section offset ranges, and dumps exactly envelope offsets `$0000-$003F`.
  The `$0BF5` body ends at `$7BF5`; the `$0C23` package fits one carrier sector.
  The dedicated host check proves HIMON front-door routing, the `APMAN`
  self-export, bounded output, and return before load/execute paths. COM4 board
  proof on 2026-09-10 exercised both selectors, all four rejection rails,
  `APS`, `AP L`, named `AP`, physical reset, and identical complete post-install
  and post-test CRC tables. See
  [the accepted transcript](../LOGS/APMAN_INSPECT_2026-09-10.md).
- [ ] Implement the accepted
  [scoped HIMON FNV/AP bank search](HIMON_SCOPED_FNV_BANK_SEARCH.md) only after
  the consolidated RAM/overlay map is frozen. The settled design keeps resident
  Bank-3 HREC authoritative, makes RAM windows explicit, then searches eligible
  AP carriers in B2/B1/B0 order and rejects duplicates. Bank-3 `$FFF2=$A6`
  enrolls B1+B2 while excluding the present WDCMONv2 Bank 0; `$FF` or an invalid
  policy disables automatic external search. Required gates include config
  decode, request/allow intersection, proof that `$06` never selects B0,
  format-specific HREC/AP validation, BANKDUMP B2:9 unique resolution, malformed
  and duplicate rejection, size measurement, docs, and board proof.
- [ ] After the scoped-search proof, implement only a separately frozen bridge
  to the R-YORS II Dynamic FNV Provider Registry. Its proposal lives in the
  sibling `R-YORS-II` repository at
  `DOC/DYNAMIC_FNV_PROVIDER_REGISTRY_PROPOSAL.md`. Keep B0-B2 symmetric under
  operator enrollment and per-sector managed/opaque validation; treat B3 as the
  resident/recovery baseline. Before generation-aware behavior is coded, freeze
  a host oracle for typed identity, global provider generation, inactive
  candidate install, exact stored-generation test, commit-last activation,
  rollback, logical retirement, equal-generation ambiguity, and corrupt-newest
  refusal. Command providers precede AP-import binding; live routine
  slots/quiescence and physical compaction are later independent gates.
- [ ] Freeze the new RAM/overlay map, shared-core boundaries, staging ownership,
  return-to-menu contract, and interrupted-operation recovery before coding.
- [ ] Decide whether compaction, harder confirmation/recovery rails, and a
  larger directory locator are part of that version or separately gated work.

The read-only `BANKAUDIT` carrier application completed that simple lifecycle.
Its onboard `.a` and host `.asm` share a checked
`$0202`-byte body; the S19 FNV32 is `$0EFD2A83`. It CRCs all 32 flash sectors,
records role bytes, restores Bank 3, and has no mutation doorway. The board
installed it at B1:C, discovered it by name, ran it twice with identical 32
sector CRCs, returned `A=$AC/C=1`, and printed `B3 RESTORED`.

APMAN V1 is the implemented host candidate for this pass. It is a named APC
installed initially at B2:8, with a `$0B12` body and `$0B40` AP envelope. Its
STR8-N bootstrap is a checked dense `$8000-$8FFF` image, including the erased
tail required by `I`; the earlier short S19 is superseded. HIMON
keeps the direct `AP package destination` recovery form and discovers APMAN in
B2/B1/B0 for bank/name commands and `APS`. Flash ASM accepts exactly
`INSTALL source B0`, `B1`, or `B2`. APMAN validates one carrier per sector,
rejects duplicate names, protects `$FFF0/$FFF1` roles, lists APC/AP Store/media
states, and rejects application BODY ranges that would overwrite its live
`$7000` overlay. STR8-N 1.29 and AP Store V1 media bytes are unchanged.

The proven manager command card currently requires `AP`/`AP L` at column zero,
although HIMON's command dispatcher accepts leading blanks. Keep the baseline
carrier unchanged for the current proof; make leading-whitespace normalization
part of the next APMAN revision.

The first board attempt proved B2:8 installation and APMAN discovery, but the
valid AP-v2 carrier was misclassified as `U` by Bank
Maintenance and direct selection of APMAN recursively executed the manager.
The host correction parses the AP-v2 16-bit section headers and rejects the
manager's `AM01` body identity with `APMAN ERR=$DB` before load or execution.
Both corrections and the subsequent BANKAUDIT lifecycle are now board-proven.

`BANKDUMP` is the next read-only inspection APC candidate. Its generated
onboard `.a` is fixed at `$2000` to keep the AP-v2 table to three import
relocations; the host counterpart emits the same `$0516` bytes with FNV32
`$2CB2A3ED`, and the predicted package is `$0597`. It stages a selected 4K
sector, restores B3, reports CRC16, decodes a sector-base AP-v2 seal, and can
dump the first page, any 256-byte page, or all pages with safe quit. The first
board run proved B0:8 staging, CRC `$5579`, and the complete 4K dump, but three
quoted semicolons caused `ERR=$03 BO` and a shortened `$0564` carrier. The
corrected card uses `$3B`. The corrected `$0597` B2:9 install, reset, named
load, and APMAN `H` inspection are board-proven, including CRC `$60CF` and B3
restoration. B1:C `P` mode subsequently matched CRC `$FA1C`, and B2:F `A`
mode matched erased CRC `$0FE1` and quit safely at the first page boundary.
The BANKDUMP carrier gate is complete.

The accepted BANKDUMP extension adds a read-only `M` bank map at the initial
bank prompt. It mirrors Bank Maintenance's full-sector erased check, complete
AP-v2/body-FNV scan, and `E/U/A/W/B/P` roles without importing a mutation
path. Host body `$092C`, FNV32 `$CEF1F837`, and package `$09AD` pass. The
corrected carrier replaced the `$0597` B2:9 build and passed the named map run.
The first map-card paste exceeded ASM-F2's global symbol budget before
packaging. The corrected generated `.a` retains only the entry/export and
three imports, with host-verified fixed branches/constants. The retry
assembled, installed, survived reset, and returned `BANKDUMP MAP OK; B3
RESTORED`; the map extension gate is complete.

### Near term: Bank 1 application work sector

- [x] Reserve Bank 1 sector E (`B1:E`, `$E000-$EFFF` while Bank 1 is selected)
  as the application **Work** sector and display it as `W` in bank maps. `W`
  means application-owned transient workspace: it is not free AP allocation,
  persistent object storage, or the only authoritative copy of data. The first
  intended owner is ASM-F2, for temporary fixup, symbol, and related assembly
  work. Keep the role application-neutral so later applications may reuse it.
- [x] Remove `B1:E` from AP-store allocation/test masks before relying on the
  `W` designation. Earlier accepted `B1:8-E` AP test-media evidence remains
  historical; the new reservation changes future allocation policy rather than
  retroactively changing those transcripts.
- [x] Add only the sector-level `W` map classification in the near-term slice.
  Defer 256-byte page-level submaps and allocations within the 4K sector until
  an application demonstrates a need for them.
- [ ] Treat wear leveling as a later design, not part of the first `W` slice.
  The likely first wear metric is a persistent per-sector erase count; define
  its storage, update/recovery rules, counter lifetime/overflow behavior, and
  allocation policy before using it to rotate work or AP sectors.
- [ ] Add a Bank Maintenance first-role transaction for the unconfigured
  stock-migration profile. It must leave `$FFF0/$FFF1=$FF/$FF` until the
  operator selects media, establish and verify an explicit old-B3:F recovery
  copy before rewriting B3:F, keep WORK and backup distinct, and leave
  directory/VTOC/catalog/rotation initialization as separate choices. Do not
  change the canonical STR8-N release image's accepted B1:E/B1:F defaults.
- [ ] Specify the `F` / provisional `FL#` flash service with `$100` logical
  pages and `$1000` physical erase sectors. Require a read-only plan showing
  OLD/NEW, `1->0`, `0->1`, and direct-program versus whole-sector erase-cycle;
  limit the initial direct path to changed bytes still `$FF`, and preserve
  protected-role and RAM-worker gates. Do not implement until the command
  grammar, staging ownership, recovery copy, and hardware test matrix are
  accepted.

- [x] **Compact `DC` text family.** `DC 'text'`
  emits raw bytes, while `DC C'text'`, `DC H'text'`, and `DC P'text'` emit
  CSTR, HBSTR, and PSTR data. Existing `DC C,"text"`, `DC HB,"text"`, and
  `DC P,"text"` source remains accepted. The implementation reuses the one
  count/emit path and `ASM_DELIM`, adds no vocabulary or UDATA, and costs
  `$0008` resident CODE bytes (`_END_DATA $BAF6 -> $BAFE`). Host/core coverage
  includes exact bytes, all empty forms, 254/255/256 boundaries, unterminated
  and embedded quotes, comments, labels, PC/high-water, rollback, and
  preservation of `DB 'A'`/`LDA #'A'`. Candidate `1502` was board-rejected
  because the general word lexer rejected the typed apostrophe boundary; the
  DC-local replacement parser and a structural regression guard are frozen in
  `1524`. Board acceptance proves every encoding and empty form at the expected
  PCs, `SEAL`, zero-relocation package/load, identical relocated/loaded bytes,
  execution with `$7906=$D7`, and atomic malformed-input rollback to
  `A5 4F 4B`. The exact transcript is appended to the hardware log.

- [x] **Case-preserving ASM-F2 source input.** HIMON now provides
  `HIM_READ_LINE_ECHO`, publishes it as `SYS_READ_CSTRING` (`$EFF54394`), and
  places it in the existing ASM-facing service-vector slot. HIMON command and
  loader callers retain the direct uppercase entries. ASM folds syntax and
  symbol comparisons itself while preserving exact bytes inside apostrophe
  and double-quote delimiters. The independent DC oracle and core smoke cover
  mixed/lowercase legacy and compact strings plus lowercase character atoms.
  The HIMON candidate grows by `$001F` resident bytes (`_END_DATA $EDB4 ->
  $EDD3`: CODE `+$0008`, DATA `+$0017`); ASM size is unchanged. The `1123`
  board run accepts mixed-case input/echo and exact bytes
  `61 5A 48 69 00 68 C9 02 6D 58 A9 71` for raw, CSTR, HBSTR, PSTR, and
  lowercase character-atom forms. A lowercase `d 3000 300c` HIMON command
  echoed as `D 3000 300C` and reproduced the same dump, accepting the unchanged
  uppercase command-input path.

- [x] **Unresolved compound fixups.** Add a compact representation and
  resolver for a single unresolved symbol plus a constant addend, including
  forward internal uses such as `LDA FOO+1`, `BNE TARGET-2`, and `DW TABLE+2`.
  Define and test selector forms such as `#<FOO+1` and `#>FOO+1` rather than
  accepting an ambiguous interpretation. Preserve fixup/import atomicity,
  correct range/width errors, AP relocation after packaging, and the current
  strict left-to-right expression contract. Measure resident ROM/RAM cost and
  look for an offset/addend encoding that reuses existing fixup storage before
  allocating another table. Do not mark complete until forward internal and
  declared-import cases have positive and negative smoke coverage and board
  evidence.
  Host implementation now reuses the fixup `BASE_LO/HI` columns as a 16-bit
  internal addend and derives relative bases from `SITE + patch width`; UDATA
  is unchanged. AP v2 import rows carry a signed-byte addend in the previously
  zero `TARGET_HI`, so row and package sizes are unchanged. The runtime smoke
  covers forward absolute, relative, `DW`, low/high selector, `+128`, and
  two-symbol rollback cases; compiled fixup smoke covers positive and negative
  declared-import selector addends. Board `00.0820(1504)` exposed classifier
  scratch corruption after literal-tail parsing (`DW` became mask-width and a
  branch lost its unresolved flag). Board `00.0820(1518)` accepted, sealed,
  packaged, and loaded all forms, but exposed later reuse of the addend scratch
  in the low-selector fixup (`$12` instead of `$0F`). Board `00.0820(1531)`
  confirmed that carrying the value through ordinary classifier cells was not
  sufficient; `1541` and `1559` reproduced `$12`. The final root cause is
  cumulative multi-row resolution: each matching row added into the shared
  symbol value, so the earlier `+1` and `+2` changed the input to the selector
  row. The resolver now applies each row in `ASM_BASE_LO/HI` scratch and keeps
  `ASM_VALUE` immutable. Board `1623` exposed an independent startup regression:
  the new uppercase-reader pointer shifted the contiguous HIMON service-vector
  destinations, leaving the ASM title's `HBSTR` target zero and producing
  `BRK 00 PC=0002`. Candidate `1628` moves the extension outside that copied
  block and pins its layout in the host contract. `asm-test` passes. Current
  flash sizes remain CODE `$39F7`, DATA `$0293`, UDATA `$1D6E`; fixup and AP
  row sizes remain unchanged. ASM-F2 `1629` is the clean corrected board proof:
  source bytes are `AD 0F 20 10 20 A9 0F A2 20 D0 00 FF FF EA 11 22 33`, and
  the `$3000` load is `AD 0F 30 10 30 A9 0F A2 30 D0 00 B5 E8 EA 11 22 33`.
  This proves independent internal addends, selector semantics, relative
  patching, relocation, and declared-import `+1` resolution. The operator also
  accepted the independent lowercase-to-uppercase seal-shell echo sweep on
  2026-08-20; no UI gate remains.

## Near Term

- STR8-N V1.02 functionality is host- and hardware-complete at frozen compact
  resident size `$0E5F`. The range receiver, local `H`, `J0`-`J3`, Bank Jump
  Record, split-worker callers, valid banked AP path, and frozen
  [compact-image refresh proof](../STR8/STR8_V1_02_COMPACT_REFRESH_BOARD_TEST.md)
  are accepted. The current `$0E5D` presentation successor has exact refresh,
  live selector, cold timeout, warm `H`, and `C-E` board proof. The final key
  discard during `WAIT` was operator-accepted on 2026-08-18; no V1.02 hardware
  gate remains. Do not reopen V1.02 for deferred self-update, sparse S19, ACIA,
  catalog,
  managed-backup, or export features.
- The standalone STR8-N `1.21` successor is board-accepted through its combined
  Bank Maintenance `U`, full-bank copy/enrollment, separate metadata-only `D2`
  adoption, successful directory-gated `J2` launch of the factory onboard
  firmware, and physical-reset recovery. The retained B1:F backup remains an
  intentional recovery object; B1 sectors `8-E` are erased, `R D1` refuses
  `BANK NOT ERASED`, and `J1` is not a valid guest edge in that state.
- 2026-07-19 hardware pass: both current-image HIMON AP-linker gates are
  closed. Missing-import validation returned `$09` without body entry or a
  partial patch; banked-source RJOIN returned `A=$AC/C=1` with status `$00`
  and resolved `BIO_FTDI_PUT_CSTR=$E705`. See
  [AP_LINKER_CURRENT_IMAGE_GATES.md](../ASM/AP_LINKER_CURRENT_IMAGE_GATES.md)
  and `LOGS/HARDWARE_TEST_LOG.md`.
- The
  [STR8_J012_OPAQUE_BANK_PLAN.md](STR8_J012_OPAQUE_BANK_PLAN.md) board rails
  now pass through resident V1 acceptance: the read-only inventory recorded
  distinct full-image CRCs, and the
  `$3000` candidate handed off through `J2`, `J1`, and `J0` with physical-reset
  recovery to Bank 3 every time. The follow-up distinguished Bank 2's ASM-F2
  face from erased Bank 1 low flash. A later confirmed full `B2->B3` restore
  intentionally changed Bank 3 from CRC `$4F80`/HIMON `2121` to
  `$04EF`/HIMON `2113`. The repeated `U` recovery restored `$4F80`/HIMON
  `2121`, and clean inventories before/after new handoffs matched
  `$4B59/$2A3D/$04EF/$4F80` with PCR `$EE` and decoded Bank 3. Phase A and
  direct-RAM Phase B are accepted. Phase C resident `J0`/`J1`/`J2`, reset
  recovery, corrected inventory, and direct faces now pass. The authoritative
  pre-echo CRCs were `$4B59/$2A3D/$04EF/$E4DB`. That functionally accepted
  pre-echo image did not display typed `Jn`; the host source added a six-byte
  resident-only echo fix.
  Its `$0B52` RAM `J2` echo passes, and the regenerated top sector is installed
  through `S`/`V`/confirmed `P`; Bank 3 cold-boots afterward. Resident visible
  `J0`, `J1`, and `J2`, exact direct faces, reset recovery, and matching
  pre/post CRC inventories now pass. The accepted installed CRCs are
  `$4B59/$2A3D/$04EF/$4663`. No J0-J2 V1 hardware gate remains. Treat Banks
  0-2 as unrelated 32K systems; do not reserve a shared top sector or BPB.
  Future managed or unattended launches require Bank-3-owned identity and CRC
  metadata; V1 validates reset-vector plausibility only.
- Before placing an unrelated OSI BASIC, FORTH, WOZMON, or other system into
  routine `Jn` use, complete
  [STR8 guest qualification](../STR8/STR8_GUEST_IMAGE_QUALIFICATION.md) for
  that exact 32K build and destination bank. Warm handoff, surviving
  peripheral state, reset/NMI/IRQ vectors, full-image CRC, and physical-reset
  recovery are per-image gates even though the V1 bank-switch mechanism is
  already accepted.
- Defer the common STR8 HB/NUL printer and product-prefix optimization proposed
  in pushed planning commit `4b73509`. Its isolated proof costs about 51-55
  bytes; complete retirement saves only about 25-32 bytes and requires broad
  STR8/HIMON/ASM/C-string/NMI/hardware regression work. The current compact
  pass does not adopt it. The standalone STR8-N repository now owns the
  published `$F00C-$F00F = 53 52 02 03` record-service face, string ABI, and
  zero-page allocation; reopen them there only for demonstrated size pressure
  or a separate functional need.
- The standalone STR8-N validated S19 record service is published at stable
  entry `$F009` as `SR/02`, capabilities `$03`. STR8-N is the primary board
  owner and owns S0/S1/S9 syntax validation for its RAM-load, flash-staging,
  and HIMON `L` clients. HIMON verifies the `SR/02` buffer capability before
  receiving a stream, then applies the validated descriptor under its narrower
  RAM-only policy; it carries no private S19 parser. STR8-N absence or damage
  is a board fault, not a mode HIMON recovers from: the integration lock pins
  the complete top-image hash, while the runtime gate checks the published
  signature/version/capability face before calling it.
  If another format is scheduled after V1.02, add minimal Intel HEX16 types
  `00`/`01`, then an explicit
  counted binary receiver with expected CRC16. Do not auto-detect raw binary or
  feed it through the line reader; defer extended Intel HEX and XMODEM-style
  protocols.
- Do not schedule S2/S8 (`.s28`) before the bank ABI and ordinary format proofs.
  Keep it as a possible `V2.xxx`/`V3` physical-flash transport using linear
  `$00000-$1FFFF` addresses, an explicit target-bank cross-check, staged sector
  writes, whole-image validation, and a commit-last bootable marker.
- Execute the historical code migration plan in small batches after current
  STR8-N, HIMON V, and ASM-F2 paths are stable:
  [HISTORICAL_CODE_MIGRATION_PLAN.md](HISTORICAL_CODE_MIGRATION_PLAN.md).
  Do not move current board-ingested sample/generated files such as
  `OLD/str8n-topwrite-transient-3000.a`, `asm-session-report-4800.a`, or `ASMTEST_3000.asm`
  until their Makefile targets and operator docs have a replacement path.
- Keep `MEMORY_MAP.md` and `TECHNICAL_GUIDE.md` aligned with the current STR8
  RAM tray: worker-code tray at `$0200-$09FF`, 4K flash sector mirror at
  `$0A00-$19FF`, RJOIN/debug scratch at `$1A00-$1FE8`, STR8 state at
  `$1FE9-$1FFF`, bank-copy sector buffer at
  `$4000-$4FFF`, and `U` update staging at `$4000-$6FFF`.
- Define `FLSH_` suffix conventions for register-carried arguments, including
  `_A` and `_AX`.
- Treat the current combined ROM protected-window start as `$F000`. The V1.02
  size pass now enforces `$0080` growth room beyond its `$0040` reserve; further
  shrink is optional, not a release gate.
- Keep the first `U` / `UPDATE HIMON` target path boring after the 2026-05-17
  hardware pass: compact S19, `$C000-$EFFF` gate, blank C/D/E staging,
  confirmed erase/write/verify, and no `$F000-$FFFF` update authority.
- Keep the `$C000-$EFFF` payload gate boring. HIMON U1->U2, fig-Forth, and OSI
  BASIC have all passed through STR8 `U`; future payloads should use the same
  compact S19 gate, transcript proof, and backup-promotion warning.
- Define the later STR8 self-update gate: `UPDATE STR8` accepts only
  `$F000-$FFFF`, requires stronger confirmation, and resets after verify.
- Decide when to promote a visibly updated HIMON from candidate to baseline:
  after a good `U`, run `B` only when Bank 2 should become the new recovery
  image.
- Sketch LEAF atomic vector routines only after STR8 V0 acceptance:
  install NMI target, install IRQ target, install BRK target, and leave either
  the old target or new target valid.
- Define STR8 V0's image read-back/check flow, including which bytes ordinary
  restore writes, which selected STR8 protected-window bytes it skips, how STR8
  install/update verifies those bytes separately, and any fixed image marker.
- Define the first catalog record header that can represent hash, kind, bank,
  address, flags, and optional name text.
- Define the first explicit STR8 import labels HIMON will use after the
  simulation stub grows into resident recovery code.
- Revise HIMON command strings and range syntax under the command safety
  mandate: destructive commands require 4+ characters. Candidate bulk commands
  are `COPY start end|+count dest`, `FILL start end|+count bb`, and later
  `MOVE start end|+count dest`; flash/bank mutation stays behind full-word
  confirmed commands.
- 2026-07-06 board proof recorded for resident `D` dump/search grammar after
  the `S` removal: `D start`, suffix-completed `D start end`, explicit-range
  byte search `D start end bb...`, text search `D start end 'TEXT'`, normal
  HIMON `S` not found, `+count` rejected by `D`, `$7F00-$7FFF` skip reporting,
  and dump continuation.
- 2026-07-18 size pass retired resident `D` search, short-end completion, and
  dump continuation. Preserve the 2026-07-06 transcript as old-image evidence;
  require a fresh board pass for current `D start [end]` behavior.
- Document and design BIO-level FTDI RX lookahead before changing the stable
  input path. A true hardware peek is not available once
  `PIN_FTDI_READ_BYTE_NONBLOCK` reads the FIFO, so any general peek must cache
  bytes at the BIO layer and require all RX consumers to read through BIO.
  Keep `BIO_FTDI_GET_CTRL_C` as a consuming long-scan abort poll for now; do
  not use it as a general non-destructive keyboard peek.
- 2026-07-06 board proof recorded: HIMON-local RX lookahead used by
  long-output abort polling preserves the leading byte of pasted follow-up
  commands. This fixes resident HIMON without changing the stable consuming
  `BIO_FTDI_GET_CTRL_C` contract; a BIO-owned one-byte or small-ring lookahead
  remains the future shared-layer design if other RX consumers need
  non-destructive peeking.
- Keep the `BIO_FTDI_*_BYTE_BLOCK` routines as unbounded blocking APIs unless
  every caller is audited. Bounded waits should use the existing timeout-shaped
  routines or small wrappers with an explicit loop-delay contract, leaving room
  for a timer backend later.
- ASM 2.76 deferred: promote the runtime paste `ASMRP_QUENCH_RX` idea into
  a real shared input-drain contract after the board proof settles. The
  reusable behavior is
  "drain current RX, then keep consuming until the sender has been quiet for an
  explicit idle window." A directly callable routine probably belongs at
  `SYS_QUENCH_RX` or concrete `BIO_FTDI_QUENCH_RX`, because it performs I/O.
  Use a pure `UTL_` name only if the loop is parameterized over caller-supplied
  flush/read-timeout callbacks. First users: ASM paste abort, load abort,
  monitor command parse failure after pasted bursts, and future host-transfer
  recovery.
- After the required ASM board tests, the next ASM direction is sealed movable
  modules and the managed flash object-store plan in
  [MOVABLE_MODULES.md](../ASM/MOVABLE_MODULES.md): seal RAM-emitted ASM output
  with body length, entry offset, exports/imports, and relocation rows, then
  prove install/move/run from bank 3 flash and RAM overlays.
- AP v2 is implemented and hardware-accepted. ASM, packaging, and HIMON share
  64-row relocation/export/import limits and 16-bit section lengths; AP v1's
  50-relocation boundary is historical evidence only. Do not reopen the wire
  format without a demonstrated capacity or lifecycle requirement.
- Add **AIM (AP Image Metadata)** as a future self-identifying-image goal.
  Define a compact **IMD (Image Metadata Descriptor)** in the image body and
  publish it as a typed DATA export or resident data record. At minimum carry
  a schema version, product/ABI identity, **BID (Build ID)**, HIMON base/end,
  and an explicitly non-self-referential content digest contract. Pair it with
  an **ICG (Image Coherence Gate)** in the host build: derive standalone RAM,
  ROM, install, and combined Bank-3 outputs from one canonical HIMON artifact,
  emit an external provenance manifest, and byte-compare every `$C000-$EFFF`
  HIMON slice. Prefer the existing AP v2 DATA-export mechanism; change the AP
  wire format only if the body-export design proves insufficient.
- Add a tiny sorted-list helper for monitor tables such as breakpoint listing.
  `B L` may print slot order for now, but sorted address order will be easier
  to read once multiple breakpoints are active. For the current four breakpoint
  slots, prefer a repeated min-scan printer over a general sort routine.
- Add persistent breakpoint support only after `N`, `@hhhh`, real `BRK xx`, and
  one-shot breakpoint behavior are boring on hardware. Persistent breakpoints
  need a step-over/replant state so HIMON can restore the original opcode,
  execute it once, then replant the `BRK 00` without recursively trapping at
  the same PC.
- Sketch the first W65C02-small `pack_lo_5` decoder and the rule for falling
  back to raw text when compression loses.
- Define the exact `FIX` record bytes for RAM staging and direct flash patching.
- Add a current guide generator only after the hand-maintained map stabilizes.

## Very Possible

- Consider an ASM-produced, FNV-1a-addressable module/subroutine artifact that
  is callable in place from owned RAM or visible flash, without making it an AP
  Capsule. Keep this parked as a proposal until its wrapper, bounded discovery,
  fixed-address/position-independent rules, collision behavior, integrity,
  and STR8-owned flash lifecycle are settled. See
  [ASM_FNV_MODULE_PROPOSAL.md](ASM_FNV_MODULE_PROPOSAL.md).
- Add `TBE`, The Bit Engine, as a small W65C02S convenience/helper routine
  family for setting, resetting, testing, and branching on bits. Keep RAM
  helpers based on `TSB`/`TRB`/`SMB`/`RMB`/`BBS`/`BBR` separate from flash-safe
  helpers, where clearing `1 -> 0` bits may be the only legal commit action
  without erase.

## Source Follow-Ups

- Re-run routine hash comments after any routine-header reshuffle.
- Check unresolved `XREF` names before using source cross-reference counts as a
  release-quality metric.
- Keep `SRC/HIMON/himon.asm` as the current reference point for
  hash-driven command dispatch.
