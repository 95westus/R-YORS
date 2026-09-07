# R-YORS Future Notes

> [!IMPORTANT]
> **Capability status: superseded/mixed historical record.** Retained commands
> and examples describe the dated image under discussion, not the current
> board. Current HIMON accepts bare `L` only and calls STR8-N `$F009` `SR/02`;
> `L G` and `L F` are invalid. Use STR8-N `I` for persistent flash installation.
> See [the current capability matrix](../CAPABILITIES.md).

The formal R-YORS II self-building proposal now lives in the sibling
`R-YORS-II` repository. It collects the host-terminal/file-device boundary,
onboard `#ISH`/ASM-F2 build loop, routine-family path, FSEDIT editor, optional
Debug/SPI RAM, image construction, and eventual RPG II direction. It proposes
an evolutionary R-YORS II architecture, not a clean-sheet rewrite.

## Architecture Direction

- Follow the accepted `J0`-`J2` direction in
  [STR8_J012_OPAQUE_BANK_PLAN.md](STR8_J012_OPAQUE_BANK_PLAN.md): keep Bank 3
  STR8 as the physical-reset and timeout root, and treat every Bank 0-2 target
  as an opaque 32K system owning `$8000-$FFFF`. Do not require a target BPB,
  STR8 top sector, or common payload layout.
- Finish the current-image missing-import atomicity and banked-source RJOIN
  proofs before implementing the RAM bank-handoff prototype. Those AP/OIL
  gates are complete; preserve their transcripts while beginning the handoff
  work.
- Consolidate S19 decoding/checksum work as a callable STR8 mechanism while
  HIMON retains RAM-load policy and STR8 owns flash mutation. Validate each
  complete record into RAM before applying destination policy. Reuse that
  descriptor service for minimal Intel HEX16 `00`/`01`, then explicit counted
  BIN with CRC16; do not auto-detect raw binary. Treat the first managed bank
  format as an append-only record log; defer balancing, directories, VTOCs,
  caches, and compaction.
- Park S2/S8 (`.s28`) as a possible `V2.xxx`/`V3` physical-flash transport.
  Interpret its 24-bit field as linear device address `$00000-$1FFFF`, keep
  ordinary updates in Banks 0-2, cross-check an explicit target bank, and
  commit boot validity only after staged write/read-back and whole-image
  validation. Do not spread 24-bit pointers into the 16-bit runtime.
- Keep HIMON hash dispatch small and inspectable.
- Make STR8 the flash recovery/update boundary instead of scattering flash
  mutation policy across normal monitor commands.
- Treat active host-side code/data as bootstrap material for current onboard
  images, not as the long-term place for samples and proofs. New code/data
  should be processed on board where practical, and retired bench artifacts
  should follow [HISTORICAL_CODE_MIGRATION_PLAN.md](HISTORICAL_CODE_MIGRATION_PLAN.md).
- Treat bank 3 `$F000-$FFFF` as the physical top erase sector, but protect only
  the selected STR8 protected window (`$FC00`, `$FA00`, `$F800`, `$F600`,
  `$F400`, `$F200`, or `$F000` through `$FFFF`) from ordinary writes.
- Flash protected-window bytes through a separate install/update path. Reuse
  lower bytes in the same 4K sector when possible. Both STR8 updates and lower
  top-sector changes must stage the full sector, erase, rewrite the full staged
  sector, and verify.
- Preserve `PIN`, `BIO`, `COR`, `SYS`, and `APP` as ownership/contract levels,
  not a mandatory five-layer call path. A future `#MAKE`/SYSGEN recipe should
  select the shortest dependency closure that fits the configured system;
  diagnostics may use `PIN -> APP`, while richer systems may select the full
  ladder. Keep `MEM` as a future core memory-ownership layer beneath public
  `SYS` calls when that layer is present.
- Keep CSTR, HBSTR, and packed command-text forms explicit at API boundaries.
- Keep the common STR8 HB/NUL printer and product-prefix experiment deferred.
  The pushed `4b73509` planning pass measured too little return--about 25-32
  bytes after complete migration--for its fixed-entry, zero-page, NMI,
  compatibility, and hardware-proof cost. The hardware-proven `ae60409`
  string/service layout remains the baseline. Revisit only when measured size
  pressure or a genuine cross-product service requirement justifies the full
  proof.
- Treat future dynamic memory as `MEM_*`: hardware-constrained RAM and
  zero-page ownership policy, not `PIN_*`/`BIO_*` device access.
- Keep STR8 fixed-buffer-only. HIMON can adopt `MEM_*` later, starting with
  app/session-owned bump allocation and pools before any general free-list heap.

## Future RAM Ownership Direction

- Preserve the current hardware-proven STR8/HIMON RAM map. Do not relocate its
  published cards, vectors, worker entry, or Bank Jump Record merely to enlarge
  today's contiguous user area.
- Design the next STR8 made from scratch around explicit operating profiles,
  not one permanent worst-case RAM reservation. Each profile should publish
  its owned ranges, the largest available contiguous range, transition rules,
  and what state the transition may clobber.
- Keep permanent RAM ABI state extremely small. Separate persistent handoff and
  vector state from scratch that STR8 can rebuild from ROM whenever it enters.
- Use these initial ownership profiles:
  - STR8 handoff uses the smallest practical RAM worker and releases its
    transient RAM after the no-return transfer.
  - STR8 recovery/install claims fixed bounded work decks and explicitly does
    not promise to preserve payload RAM.
  - HIMON reserves only its active service, parser, console, and vector state
    and publishes the remaining contiguous application range.
  - ASM acquires symbol, fixup, package, and output arenas only for the active
    assembly session, then releases them according to an explicit session-end
    contract.
  - An exclusive opaque guest may own the full ordinary main-RAM span
    `$0200-$7EFF`; zero page, the hardware stack, and I/O retain their separate
    hardware-defined roles.
- Prefer deterministic fixed arenas, overlays, and acquire/release ownership
  over a general STR8 heap. Allocation policy belongs in the future `MEM_*`
  layer; recovery behavior must remain bounded and inspectable.
- Make every ownership transition testable. A caller must be able to determine
  whether entry preserves RAM, borrows it temporarily, or revokes it for
  recovery before making the transition.

## BIO RX Lookahead Direction

- Treat the current FTDI input path as stable until a deliberate BIO lookahead
  design is ready. `PIN_FTDI_READ_BYTE_NONBLOCK` consumes the hardware FIFO
  byte, so a true non-destructive hardware peek is not available at the PIN
  layer.
- A future general peek must be a BIO-owned logical peek: cache one byte, or a
  small ring of bytes, above the PIN layer and make ordinary BIO reads consume
  cached bytes before touching hardware.
- Once BIO lookahead exists, all FTDI RX consumers must go through BIO. Direct
  calls to `PIN_FTDI_READ_BYTE_NONBLOCK` would bypass the cache and can reorder
  or discard the logical input stream.
- Keep `BIO_FTDI_GET_CTRL_C` as a consuming abort poll for long-running code
  that owns input, such as memory search. A non-destructive Ctrl-C service
  should be a separate BIO routine and probably needs a ring buffer if it must
  preserve ordinary typed input while still finding Ctrl-C behind it.
- Keep block-vs-timeout contracts separate. `BIO_FTDI_READ_BYTE_BLOCK` and
  `BIO_FTDI_WRITE_BYTE_BLOCK` mean wait until completion; timeout variants or
  explicit wait-long wrappers should return `C=0` on bounded failure. A later
  timer can replace loop-delay internals without changing those caller
  contracts.

## Optional Debug Module Direction

- Current debug stays a compact HIMON include because that is the smallest
  present shape.
- Treat plug-and-play debug as a far-future build mechanism, not a current
  implementation promise.
- The future shape should keep HIMON core in charge of the command resolver,
  trap entry, and build profile, while an optional debug module exports `B`,
  `N`, synthetic-BRK handling, and debug-context helpers.
- The debug module should import only narrow system services: output text/hex,
  trapped-context access, resume support, and the address patch policy.
- A build profile that omits debug must also omit the matching command records,
  help text, BRK debug hook behavior, and generated docs that claim debugger
  support.
- Do not promote this into a framework just to make debug prettier. Promote the
  mechanism only after two or more optional subsystems need the same command,
  hook, profile, and documentation machinery.

## Selectable ROM Composition Direction

- Explore a future ROM-recipe compositor in which STR8-N is the mandatory
  reset/recovery root and the operator or host selects the higher system
  packages to include: HIMON core/shell, Debug, OIL/AP integration, ASM, and
  later applications. This is a possible direction, not a current build or
  onboard-command commitment.
- Treat the selection as a dependency graph, not as binary concatenation or a
  set of unrelated yes/no switches. For example, Debug may require HIMON core
  and its trap dispatcher; ASM may require HIMON plus the minimal OIL loader;
  selecting either should add those requirements visibly or reject the recipe.
- Consider splitting the permanent substrate into these conceptual packages:

  ```text
  STR8-N          mandatory reset, recovery, bank, and flash boundary
  HIMON core      console/service anchors, vectors, records, minimal loader
  HIMON shell     normal interactive monitor commands and help
  OIL0            smallest validator, relocator, and import resolver
  OIL extensions  banked storage, catalog, placement, and richer integration
  Debug           optional commands, trap behavior, and context helpers
  ASM             optional onboard assembler and package producer
  ```

  The exact split is deliberately unsettled. At least one non-loadable nucleus
  must always be able to validate and load the next layer without depending on
  the layer it is loading.
- Give each selectable package an inspectable manifest containing its name and
  version, ROM size/alignment, dependencies, provided capabilities, imports,
  exports, relocation rows, entry/init routine, command/help contributions,
  RAM ownership, vector/hook requirements, and body hash or CRC.
- The compositor should compute dependency closure, reject incompatible RAM or
  vector claims, allocate ROM, resolve imports and relocations, synthesize the
  selected command/help/record surfaces, verify final vectors, and emit the
  complete recipe, layout map, and image identity. Omitting Debug must continue
  to omit its commands, help, BRK behavior, records, and documentation claims.
- Make the first implementation, if pursued, a host-side fixed-slot composer.
  R-YORS may emit the selectable `$8000-$EFFF` package artifacts and manifests;
  STR8-N remains the owner of `$F000-$FFFF`, the final 32K composition, reset
  vectors, and release identity. Move to tightly packed relocatable modules only
  after the sealed-module and relocation contracts have hardware proof.
- A later onboard `ROM BUILD` or equivalent could present a custom recipe,
  stage and verify it sector by sector in an inactive Bank 0-2 target, and
  publish the directory/boot-valid record last. It must not grow or rewrite the
  executing Bank 3 image one package at a time. Package sources must remain
  available outside any sector being replaced, and power loss before final
  commit must leave the current recovery root usable.
- A configured Bank 0-2 result is one legitimate opaque 32K guest; it does not
  impose STR8, HIMON, a package format, or a common layout on other `J0`-`J2`
  targets. The current opaque-bank handoff contract remains unchanged.
- Keep static ROM composition distinct from runtime overlays. A package may be
  baked into the composed ROM, stored as a sealed object for later RAM loading,
  or omitted. The recipe and package metadata should make that lifecycle
  explicit rather than treating all three states as equivalent.
- Let SYSGEN reduce installed metadata when it binds an AP into a fixed image:
  keep full AP, strip optional text/debug only, or bake a resolved body plus the
  required HREC/entry/ABI runtime records. A baked result is an image component,
  not AP v2. Preserve the canonical AP and build/provenance/strip manifest
  outside the reduced nucleus.

## Long-Term RPG II Direction

- RPG II is the long-term language goal, not a near-term monitor feature.
- R-YORS should still be shaped around that future while it grows: records,
  catalogs, fixed entry points, stable callable routines, flash-resident
  programs, and an onboard assembly/link path should all make a later RPG II
  environment feel native instead of grafted on.
- The target is true RPG II lineage and behavior, guided by original IBM
  documentation, not a modern language wearing an RPG name.
- Near-term work should keep producing useful standalone runtime pieces even
  before an RPG II compiler exists.
- Avoid adding RPG-specific complexity to STR8 V0 or the current HIMON
  monitor unless that same work also improves recovery, cataloging, assembly,
  loading, or routine reuse.

## System Messaging Service Direction

- Add a way-future system messaging service, currently nicknamed `SMS`.
  The name is provisional and may change before implementation.
- Model it after console/subconsole and operator-message systems from older
  midrange/mainframe/supercomputer environments: a task or person can send a
  message, a console/subconsole can receive it, and some messages can require
  a reply before the sender continues.
- Keep the early concept queue-shaped rather than screen-shaped:
  informational messages, action/attention messages, inquiry messages that
  require a reply, replies correlated to message IDs, and cancellation of
  outstanding inquiries.
- Keep hash-joint/chaining ideas nearby for later SMS/WTOR provenance:
  message identity, sender routine/task identity, and reply-required wait
  points may become compact hash-linked records.
- Do not make `SMS` a current HIMON or STR8 feature yet. It belongs after the
  monitor, catalog, memory, and app/session boundaries are strong enough to
  host a real service.

## Board Onboarding Direction

- Possible future enhancement (idea only): give the RAM-based STR8-iN/65
  WDC-to-STR8-N tool one entry point that detects the environment and selects
  the appropriate migration or update routines. The host loader would identify
  the active monitor to choose WDC binary RAM loading or STR8-N `L`/S19 loading;
  the RAM tool would independently identify the installed Bank-3 image before
  choosing a flash procedure. Running preserved WDC from B0 must not be
  mistaken for a factory WDC installation in B3.
  Recognized WDC in B3 would use the guarded factory preservation/migration
  path; supported STR8-N in B3 would use the guarded top-update path, backing
  up B3:F and preserving the live directory and factory B0 copy. Unknown,
  damaged, or unsupported images would report findings and stop before
  erase/program operations. Require positive identity and compatibility
  checks, retain separate write confirmations, and compose the paths from
  small shared routines. This is not an implemented or board-proven feature;
  any implementation belongs in the standalone STR8-N repository.
- The first standalone bridge artifacts now live in the adjacent STR8-N
  repository and are host-qualified, with stock-board proof still pending:
  `str8n-v1.23-wdcmonv2-archive-2000.s19` inventories/exports banks without
  flash mutation, and `str8n-v1.23-wdcmonv2-install-2000.s19` preserves an
  erased-or-identical B0, installs only STR8-N in B3:F, and leaves B1/B2
  untouched. R-YORS continues to consume this path rather than forking it.
- `make wdcmonv2-package` now produces the explicit STR8-N/R-YORS publication
  ZIP. Its checked allowlist excludes WDCMONv2 firmware and owner bank
  archives; the ZIP carries the bootstrap artifacts, R-YORS payload, source,
  binary-monitor/terminal host bridge, procedures, license, manifest, and
  self-verifier.
- Keep the migration candidate `$FFF0/$FFF1=$FF/$FF`; assigning B1:E/B1:F in
  that image would contradict the promise that onboarding leaves B1/B2
  untouched. Add a post-migration Bank Maintenance transaction that inventories
  the device, qualifies and writes an explicit B3:F backup, then assigns WORK
  and top-backup roles. Directory/VTOC initialization, catalog enrollment, and
  backup rotation remain separate opt-in operations.
- Treat `$100` as the future logical allocation/transfer/display page while
  retaining the SST39's `$1000` physical erase transaction. A proposed `F` /
  `FL#` service first displays `1->0` and forbidden `0->1` masks. Direct byte
  program initially targets only bytes still `$FF`; any changed non-`$FF` byte
  uses guarded whole-sector stage/erase/rewrite/verify, even if its bit delta is
  only `1->0`. Exact command spelling remains open.

- Treat a WDCMONv2-to-standalone-STR8-N converter as a useful publishable
  intermediate product, not merely a private ramp into HIMON. A candidate
  `wdcmonv2ryors.asm`/`wdcmonv2str8n.asm` runs from RAM under stock WDCMONv2,
  preserves and verifies the WDCMONv2/SPI Bank-3 image in Bank 0, then installs
  STR8-N as the Bank-3 reset, multiboot, flash, and recovery supervisor.
- The resulting board may stop there. Bank 1 or Bank 2 can hold an independently
  adapted opaque guest without HIMON, ASM-F2, AP, or `#ISH`. This makes STR8-N
  independently useful to SXB/EDU owners and keeps R-YORS II an optional later
  development-system profile.
- Keep the converter's authoritative source and release kit in the standalone
  STR8-N repository. R-YORS records the integration and optional payload path;
  it must not fork a second live copy of STR8-N implementation source.
- Permit an explicit later release of the retained Bank-0 WDCMONv2 role only
  after an exact 32K BIN/check manifest is exported and round-trip compared.
  S19 and a GibberLink-style channel may be additional transports. Export,
  erase, backup enrollment, and `$FFF2=$A7` catalog enrollment remain separate
  confirmations; no successful transfer silently authorizes the next step.
- Do not require a new owner to arrive with a finished Bank-0/1/2 guest image.
  Add a later guided `#MAKE GUEST`/SYSGEN path that can compose a minimal image
  from reset/vector, console, safe IRQ/NMI, PIA, VIA, SPI, and monitor pieces,
  emit its map/checks/recipe, build it in an inactive bank, and qualify it with
  `Jn`.
- Treat hardware selections as claims until bounded diagnostics observe them.
  Interrupt, PIA, VIA, FTDI, SPI SRAM, and SPI SD checks must report the exact
  test performed and what pins/storage they may alter. Do not drive unknown
  external circuits or write a storage device merely to make a friendly
  automatic probe.
- Optimize starter profiles for time-to-use across laboratory, education,
  control, art, data, storage, and retrocomputing work. Share small proven
  services across disciplines; do not create one all-features image or one
  framework per discipline.

- Retain the standalone WDCMONv2 S19 archive utility. The host bridge validates
  its S19, uses binary WDCMONv2 commands `$02/$03/$06` to load, read back, and
  execute it, then stays on the same COM handle as the ASCII terminal. This is
  not an extension of the HIMON/STR8 loader contract.
- Its implemented first deliverable is read-only and does not erase or program
  flash. It inventories all four 32K banks and emits a selected complete bank
  as dense checksum-valid `S1` records followed by `S9`; the host extractor
  creates the exact local BIN/S19/receipt set.
- A general `WRITE` remains deferred. The narrow seed installer carries its
  checked STR8-N top candidate in RAM, requires the local archive hash token,
  refuses a used/different B0, and uses separate copy and final-install
  confirmations. A later arbitrary `WRITE` must receive and validate complete
  input before any destructive operation.

- Retain the implemented WDCMONv2-to-R-YORS installation bridge for boards that
  already boot the current WDC monitor. It remains a release candidate until
  the stock-board test card and readbacks pass.
- This is mainly for a new WDC board owner, not for a board that already has
  R-YORS/HIMON flashed and running.
- The bridge uses WDCMONv2 only to load and start a self-contained RAM program
  at `$2000`. It then owns direct FTDI/VIA I/O and bank selection; it does not
  depend on private WDCMONv2 entry points or return through an unmapped caller.
  A binary signature block or fixed public bridge API is an optional later
  refinement, not a first-migration dependency.
- The runtime path can perform installation without an external programmer:
  start from WDCMONv2, archive B0/B3 through the host terminal, run the guarded
  seed, and let STR8-N install R-YORS. Until hardware acceptance is complete,
  and whenever recovery from power loss during B3:F matters, keep a programmer
  and complete 128K image available.
- WDCMONv2 is the entry ramp, not the final runtime owner. After installation,
  R-YORS boots through STR8 and normal operation belongs to HIMON.
- Author preference: when available, the cleanest installation path is still to
  program the flash/ROM directly with a T48 programmer. The WDCMONv2 bridge is
  for new users who have the stock board and want to reach R-YORS without first
  adopting extra programmer hardware or WDC's full toolchain.
- The host-qualified bridge is implemented. What remains is physical acceptance,
  not a design decision: prove read-only B0/B3 export, refusal gates, exact B3
  preservation in B0, B3:F seed/recovery, STR8-N `I`, R-YORS `C`, and stock
  guest `J0` using the published board-test card. Because WDCMONv2 is binary,
  the `J0` proof is a `$0C` board-info reply, not an assumed ASCII banner.
- Original-image preservation is implemented as local exact B0/B3
  BIN/S19/receipt sets plus byte-exact B3-to-B0 proof where B0 is erased. A
  used/different B0 is archived and then refused by this first installer.
- The future movable-module/object-store plan must treat that preserved
  WDCMONv2/base image as a protected object or explicit bank role, not as
  scratch flash. See [MOVABLE_MODULES.md](../ASM/MOVABLE_MODULES.md).
- Bank 0 starts as the retained base-image hold slot for the publishable stock-
  board conversion path. Keep it out of automatic backup rotation and catalog
  search while that role is configured. Repurposing it requires an explicit
  policy/configuration change plus ordinary destructive confirmation; it must
  not happen as a side effect of installing or booting another guest.

## Assembler Direction

- Treat `ASM` as the assembly entry, with full source lines inside the session.
- Support forward labels in v1 through fixup records.
- Prefer RAM staging for flash targets when source may fail or generate fixups.
- Export only after bytes and fixups are verified.
- Keep `DEF`, `SYM`, `FIX`, `RESOLVE`, `FORGET`, and `EXPORT` in the design
  surface even if early UI hides some of them.
- Treat short IDs/indexes as optional post-resolution handles. Hashes remain
  the catalog discovery key; future RIDX tables can speed hot paths later.
- Treat versioned catalog lookup as candidate selection, not first-match:
  exact ABI version, minimum-compatible version, and latest-compatible lookup
  are different policies. HIMON and ASM can use compatible latest records when
  the caller allows it. STR8 V0 does not use FNV/catalog lookup; future
  STR8-N/STRAIGHTEN may participate in catalog scan/repair after the
  image-recovery path is stable.
- Keep PACK5/3x5 as a candidate for compact 3-letter mnemonic tables, because
  three 5-bit characters fit in two bytes.

## FSEDIT Direction

- Add FSEDIT as the intended simple onboard full-screen source editor, in the
  operator style of the System/34 POP utility. Its first slice loads one small
  host file into ordinary RAM, edits it, and saves it through the terminal
  responder with explicit length/CRC/commit behavior.
- Keep display and file windows independent. Display size follows negotiated or
  configured terminal rows/columns; file-window size follows acquired ordinary
  RAM and optional external-memory capability.
- Treat paging as explicit range I/O and overlay loading, not virtual memory.
  A small nucleus owns cursor, dirty state, backend calls, and overlay return;
  search/help/block operations may be pageable AP components later.
- Let FSEDIT itself be an AP that may be stored in RAM, visible/banked flash,
  host storage, SPI SD, or SPI SRAM. Non-visible and serial storage is not
  executable memory; required code must be copied/relocated into executable RAM.
- Use one bounded OPEN/READ/WRITE/COMMIT/CLOSE-style backend contract. Begin
  with the host responder, then add SPI SRAM and SPI SD without rewriting the
  editor core. Treat flash/AP Store editing as copy-on-write object generation,
  not mutable in-place text.
- Preserve dirty text on failed window motion or save. Variable window sizes,
  multiple buffers, undo, syntax assistance, and richer overlays follow
  measured need; they do not block the first source-to-RAM build loop.

## RJOIN Debug Hash Stack Direction

- Reserve the idea of a small RAM hash/RJOIN debug stack for post-crash
  diagnosis. This is not the CPU hardware stack and not a current ABI; it is a
  breadcrumb trace area for dynamic join/load/fixup work.
- The current low-RAM map leaves `$1A00-$1FE8` as RJOIN/debug trace and
  reserved scratch. A future hash stack can live there while UPA remains at
  `$2000`.
- Early entries should be compact and boring: hash or routine ID, stage byte,
  operation kind, worker mode, fixup site or target address, and an optional
  PC/error/register snapshot when a failure path has those values cheaply.
- Use it to answer crash questions such as "which hash was being joined?",
  "which fixup was being applied?", "which flash worker mode was active?", and
  "what was the last resolved dependency before the fault?"
- Keep it append/ring-shaped at first. Do not make success paths depend on it;
  losing trace data should never change loader, assembler, STR8, or flash
  mutation behavior.

## Flash Direction

- Keep bank 3 cleaner for boot/current-monitor/catalog/trampoline material. The
  physical `$F000-$FFFF` sector contains STR8 and vectors, but only the chosen
  STR8 window is reserved from ordinary writes.
- The planned direction after the required ASM board proofs is sealed movable
  ASM modules plus a managed flash object store. The focused plan lives in
  [MOVABLE_MODULES.md](../ASM/MOVABLE_MODULES.md).
- Keep two related long-range operator goals open: `L F` may eventually accept
  a sealed package and relocate it while choosing a legal destination, and a
  catalog/menu may let the user select a named package for guarded on-the-fly
  flash installation. Both should consume the same package metadata,
  relocation rows, placement policy, and write/verify/commit-last machinery;
  neither changes the current conservative `L F` contract.
- Build the first managed store as an append-only typed object arena, not a
  general hierarchical filesystem. Committed `RCAT`/`RREC` descriptors and
  their `RBODY` payloads are authoritative. `RDICT`, `RTEXT`, and `RDATA` should
  begin as record/body kinds or views, not independent allocation engines.
- Treat directory, menu, and VTOC displays as projections over the catalog.
  Keep `RIDX`/hash indexes and address caches rebuildable from committed
  records; a damaged or stale cache must never make live objects disappear.
- Use 4K erase sectors as the first allocation/reclaim unit. Give each managed
  sector a small header with arena/version, generation, state, used boundary,
  and checksum. Append new objects, commit them with a final one-way bit change,
  invalidate old generations, and reclaim only through an explicit staged
  `CONDENSE` operation with read-back verification.
- Do not implement tree balancing, online wear leveling, or automatic garbage
  collection in the first store. A bounded linear scan plus optional rebuilt
  hash index is easier to recover and prove on W65C02. Add balancing only after
  measurements show lookup or erase distribution is a real problem.
- Keep one small root/VTOC locator redundant and boring: two generation-tagged
  copies or a fixed root sector plus a fallback full-arena scan. The root names
  catalog arenas; it does not duplicate every object entry.
- For the first STR8 recovery model, restore uses a whole 32K bank 0, 1, or 2
  image as the source for bank 3, writes ordinary bank 3 image bytes, and skips
  the selected STR8 protected window unless explicit STR8 install/update is
  requested. Automatic backup rotates bank 2 to bank 1 and bank 3 to bank 2
  until `E` enrolls bank 0. After enrollment, backup rotates bank 1 to bank 0,
  bank 2 to bank 1, and bank 3 to bank 2.
- Let R-YORS define scan, verify, write, commit, and later condense policy,
  with shared flash primitives where that makes sense. HIMON/maintenance owns
  catalog condense first; future STR8-N/STRAIGHTEN may participate in catalog
  scan/repair later without requiring ownership of a user system's catalog.
- Split future flash protection into operation-context guards rather than one
  global writable range. Keep `FLASH_ADDR_ALLOWED_XY` as the conservative HIMON
  `L F` guard, keep raw erase/program routines as mechanism, and let STR8 define
  separate backup, restore, install/update, and bank-0-enrollment policies.
- Consider a future HIMON `L F` auto-place mode for relocatable S19 payloads:
  the operator types `L F`, sends S19, HIMON measures the incoming image span,
  finds an erased flash block under the HIMON flash-load guard, rebases the S19
  record addresses to that block, writes only blank bytes, verifies readback,
  and reports the chosen base plus relocated go address. This is convenience
  loading for applications or flash-resident ASM slices, not backup, restore, or
  protected-window update.
- Keep the relocation promise precise. Plain S19 carries load addresses and
  bytes, not relocation records. HIMON can rebase S-record addresses, but it
  cannot repair absolute addresses already encoded inside 65C02 instructions
  unless the payload is position-safe or ASM/host tooling supplies relocation
  metadata. Early eligible payloads should use RJOIN/resident calls, relative
  branches, fixed external data addresses by contract, or a declared relocation
  table.
- Design `L F` auto-place as a staged/two-pass operation. It must validate
  checksums and collect `min`, `max`, byte count, sparsity, and S9 start before
  programming flash. If the whole stream cannot fit in RAM staging, the command
  should do an analyze pass and ask the host to resend after reporting the
  selected destination. Do not stream-write unknown-size data and then discover
  the block was too small.
- Treat the chosen flash block as a lease even when the payload itself has no
  FNV header. The no-header ASM direction can keep payload bytes bare, but HIMON
  still needs enough external fact to avoid overwriting occupied flash and to
  report where the relocated entry landed. The first proof can use "bytes are
  not `$FF`" as the occupancy rule; later managed flash should record name,
  span, origin, hash/checksum, and entry in a small catalog or lease table.
- Explore the next STR8 backup layout as a managed 64K arena across banks 0
  and 1: five 12K backup slots plus one 4K metadata sector for names, labels,
  origin records, checks, and roles. This would leave bank 2 for SYS/USR use
  and bank 3 as the default boot bank, with `$8000-$BFFF` remaining 16K of
  user-available live-bank space.
- Treat STR8-N/STRAIGHTEN `PACK` as a way-future range manager: copy or move
  named regions into safe flash homes, remember where they came from, and
  optionally compress backed-up regions only when the metadata is strong enough
  to verify and restore them.
- Consider a future advanced STR8 or HIMON maintenance mode for sector-level
  work: select source bank/sector, select destination bank/sector, erase the
  selected destination sector with confirmation, copy one sector to another,
  and verify by read-back compare. This is good for rescue/lab work, bad for
  the tiny V0 rescue prompt, and must not change Bank 0 rotation policy except
  through the normal `E` enrollment command.
- Keep the recent Bank Maintenance copy/adopt sequence as a usability case:
  full-bank `C`, declining enrollment, and a separate `D` worked, but was
  convoluted. Consider an explicit copy-only path with source/destination
  sector ranges and an optional compare-first mode that writes only differing
  sectors. Partial or differential copies must not auto-enroll a bank or claim
  a complete guest.
- Improve future Bank Maintenance maps without conflating protection, role,
  and detected content. Preserve `P` for the live protected B3:F sector;
  consider `B` for a verified retained backup such as B1:F, or `S` only for a
  positively identified STR8-N/system image. Keep the legend explicit.
- Consider `W` for positively recognized factory onboard firmware in Banks
  0-2 only after a stable, low-false-positive signature is defined and proven.
  A banner or a board-local `WDC*` directory label is not enough by itself;
  unknown used content should continue to display as `U`.
- Treat future flash GC as append/invalidate/reclaim instead of in-place edits:
  mark records or sections stale, prepare a compacted sector image in RAM,
  relink copied records when needed, erase the old 4K sector, then write and
  verify the prepared image.
- Treat future `CONDENSE`, possibly exposed as an operator-friendly `PACK`
  command, as explicit maintenance for managed flash datasets: RCAT/RREC,
  hash/name records, message templates, movable code records, persistent data,
  and staging areas. It is a long-term direction, not a current STR8 V0 or
  HIMON command.
- Explore LOC, "link on copy", for flash compaction: copied catalog records or
  modules are relinked to their new addresses before the rewritten sector
  becomes live.
- Store compressed command text only when it is smaller than raw text after
  flags/headers.
- Use byte-aligned RLE as the first binary `RBODY` compression direction, with
  special run forms for `$00`, `$20`, and `$FF` under consideration. Do not
  commit opcode ranges until the decoder shape is proven small.
- Do not use a board LED as proof of flash correctness. A flash chip-select LED
  may be tied to a narrower decode than the banked ROM window, may see only very
  short command/read pulses, or may be invisible without pulse stretching. Flash
  software must report success from readback verification, not from LED state.
- A configured EDU/SXB LED may still flash as an operator `DO NOT POWER OFF`
  warning from erase entry through program, verify, and safe-bank restore. Put
  the LED control in the RAM worker so no call crosses into an unmapped bank.
  Declare LED port, polarity, preserved bits, and fixture ownership; the
  warning must not commandeer guest PIA/VIA outputs. Text status and readback
  remain authoritative.
- Keep separate flash result facts:
  - command accepted/completed without timeout
  - byte readback equals the requested programmed value
  - whole 4K window/sector readback equals the staged image
  - current byte/window still contains `1` bits that can be flipped to `0`
- A successful byte program does not mean the byte is no longer writable. Flash
  can only change `1` bits to `0` bits until erase. If the verified byte is not
  `$00`, its remaining `1` bits are still flippable. For example, `$FE` verifies
  as a successful program but still has seven flippable bits.
- Future flash query/status routines should distinguish:
  - window is fully erased: every byte is `$FF`
  - byte/window has at least one flippable bit: at least one bit is still `1`
  - byte/window has no flippable bits: every checked bit is already `0`
  - desired byte can be programmed without erase: `(current & desired) == desired`
- A future RAM-staged flash worker can return a compact kind/status byte rather
  than carry alone. Carry should remain the quick success/fail signal; a kind byte
  can describe timeout, illegal `0 -> 1`, verified, erased, partially flippable,
  or exhausted/no-flippable-bits state for diagnostics and STR8 planning.

## Small Monitor Direction

- Do not shrink current HIMON in place into LOMON. Keep hardware-proven HIMON
  as the full monitor/service host and build a separate size profile from shared
  console, hex, load, dump/modify, go, vector, and service-vector routines.
- A Wozmon-style prompt can fit below 1K, but the useful R-YORS base is larger:
  AP parsing/loading, resident import linking, RJOIN/FNV resolution, safe bank
  staging, and error reporting must be budgeted separately. Treat `<1K` as the
  LOMON shell target, not as a promise for the complete AP/RJOIN substrate.
- LOMON becomes a candidate base image only after it can load a full HIMON or
  ASM AP from visible/banked storage, reject corrupt packages, and recover to a
  prompt without depending on the module it is loading. Until then, current
  HIMON remains the base and ASM-F2 remains an optional low-flash resident.

## Documentation Direction

- Keep `DOC/GUIDES/INDEX.md`, `TOC.md`, `MAP.md`, `REF.md`, `XREF.md`,
  `BIB.md`, and `HASH_MAP.md` consistent as the stable guide spine.
- Keep `HIMON_MAP.md` plus `HIMON_EDGE_DUMP.md` as the current HIMON
  map/evidence pair.
- Add a future generator only if the guide set starts drifting again.
