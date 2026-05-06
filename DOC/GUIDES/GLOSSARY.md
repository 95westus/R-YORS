# R-YORS Glossary

## Terminology Contract

Use these words precisely. When a word can mean more than one technical thing,
prefer the specific form listed here instead of the bare word.

- R-YORS: the whole project/system/runtime direction.
- HIMON: the current monitor/debug/catalog environment.
- STR8: the current recovery/update guard.
- STR8-N / STRAIGHTEN: future expanded STR8 direction.
- THE: The Hash Environment. THE is the hash-first lookup/catalog environment:
  canonical names, FNV-1a, hash8/hash16/hash32 storage, RCAT/RREC records,
  resolver policy, aliases, and typed display. THE is not the whole runtime.
  A dispatcher may use THE; HIMON's current command dispatcher is the first
  concrete user.
- ASM: the planned onboard assembler path.

## Normative Words

R-YORS uses RFC 2119/8174-style words only when they are uppercase in a spec or
contract block.

- MUST / SHALL: required.
- MUST NOT / SHALL NOT: forbidden.
- SHOULD: recommended unless there is a clear reason not to.
- SHOULD NOT: discouraged unless there is a clear reason.
- MAY / OPTIONAL: allowed.
- WILL: descriptive future tense, not a requirement.

Lowercase words such as "should" and "may" are ordinary English.

## Contract Terms

Use `contract` as the normal word. Avoid `API` and `ABI` unless the sharper
meaning is required.

- routine contract: what a callable routine expects and returns.
- entry contract: what is true when code starts at an entry.
- fixed-entry contract: a callable address or label promised to stay stable.
- vector contract: what an indirect vector slot points to and when it is valid.
- call shape: the registers, flags, memory, stack, and side effects used by a
  call.
- entry: the address or label where a routine/body starts.
- fixed entry: an entry kept stable for external callers.
- trampoline: a tiny stable entry that jumps or calls into the current
  implementation.
- vector: an address slot used by CPU/system dispatch.
- ABI: binary/register/address-level contract; use only when that precision is
  needed.
- API: named software interface; usually `routine contract` is clearer here.

## Ownership Terms

- owns: responsible for policy, mutation, and final safety.
- uses: may read, call, or consume without controlling policy.
- requests: asks the owner to perform an action.

Example: HIMON uses catalog lookup and may request condense. STR8 or catalog
maintenance owns dangerous sector rebuilds.

## Source Aliases

Generated docs and guide navigation use operational aliases so old source lanes
do not leak into current terminology.

- HIMON/: current monitor source alias.
- STR8/: current recovery/update source alias.
- ROM/dev/: current ROM support adapter source alias.
- ROM/ftdi/: current ROM FTDI backend source alias.
- ROM/util/: current ROM utility source alias.
- SRC/STASH: stable or promoted code lane.
- SRC/SESH: session/WIP lane.
- SRC/BUILD: generated build output.
- SRC/tools: host-side scripts for build and generated artifacts.

Physical source locations can move. The aliases describe the role in current
docs.

## Project Terms

- Himonia-F: historical FNV-driven implementation branch now folded into HIMON
  and archived under `SRC/ARCHIVE/himon`.
- Straight 8: alternate reading of `STR8`; useful as flavor, not the formal
  project name.
- QCC: Questions, Comments, Concerns. Borrowed from call-center training as a
  pause after each thought block; in R-YORS it is the guide style for important
  design thinking that is not settled enough for `DECISIONS.md`.
- BSO2: predecessor board-monitor project and lineage evidence.

## Source Terms

- `MODULE` / `ENDMOD`: WDC assembler module boundary.
- `XDEF`: symbol exported by a module.
- `XREF`: symbol imported from another module.
- `ROUTINE` block: structured routine comment header with optional
  `[HASH:XXXXXXXX]`.
- `rom.lib`: linked library artifact produced by the source build.
- REF: a symbol/routine contract card: name, kind, contract, hash, source, and
  notes.
- XREF: where a symbol is defined, imported, called, or exported.
- XXREF: semantic classification tags that apply even before code exists.

## Layer Prefix Families

- `PIN_*`: low-level pin/driver routines at hardware/register boundaries.
- `BIO_*`: HAL routines above `PIN_*`.
- `MEM_*`: memory ownership/allocation routines for RAM ranges, zero-page
  lanes, heaps, marks, and pools. Hardware-constrained, but not device access.
- `COR_*`: backend/core integration routines.
- `SYS_*`: adapter/system-facing wrappers for app-level use.
- `UTL_*`: shared utility routines.
- `CMD_*`, `CMDP_*`, `MON_*`, `HIM_*`: monitor/command parser routines.

## Hash Terms

- FNV-1a: the hash algorithm/family.
- hash32: full 32-bit FNV-1a result, stored as hash0..3 low byte first.
- hash16: folded 16-bit result derived from hash32.
- hash8: folded 8-bit result derived from hash32.
- hash width: how many hash bytes are stored: 1, 2, or 4.
- fold: derive hash16 or hash8 from hash32.
- HASH: routine header ID formatted `[HASH:XXXXXXXX]`; this is hash32.
- symbol hash: assembler/catalog lookup key for labels, routines, and commands.
- hash collision: two names produce the same stored hash; name text or a wider
  stored hash must prove identity.
- hash map: the design map of where hashes are used and what each hash means.

## Record Terms

- generic record: any structured chunk made of fields.
- Record: the specific record format currently defined by a section. A section
  should say, "In this section, Record means ...".
- R-YORS record: a R-YORS structured runtime/catalog record.
- RREC: R-YORS runtime record; one typed catalog entry for a command, routine,
  symbol, data item, module, inline value, or similar runtime thing.
- RCAT: R-YORS runtime catalog dataset; may hold records, string pools, indexes,
  and links to runtime bodies spread across RAM or flash.
- member: informal package view of a catalog-visible thing, usually an `RBODY`
  plus one or more `RREC` exports under an `RCAT`. Do not use member as the
  byte-layout name.
- command record: record that names a command and resolves to executable
  behavior.
- catalog record: metadata that maps hash/name to value, kind, bank, flags, and
  optional name text.
- fixup record: pending patch site for a symbol not known when an instruction
  is emitted.
- RPG record: business/data record in RPG terminology; do not confuse this with
  an RREC.
- current HIMON FNV command record: the current inline HIMON command shape:
  `'F','N',('V'|$80),hash0,hash1,hash2,hash3,kind,inline-code...`.

## Signature, Control, And Kind

- signature: bytes that help find or identify a container or record family.
- control byte: packed layout, lifecycle, and hash-width byte.
- kind: semantic type, such as command, routine, symbol, fixup, string, or
  module.

Current HIMON uses `FNV|$80` as a readable command-record signature. Future
compact catalog records should put layout and hash width in a control byte.

## Runtime Catalog Terms

- RBODY: runtime body; the code, data, string, packet, module image, or payload
  described by one or more runtime records.
- RBODY compression: storage codec for runtime body payloads; first direction
  is byte-aligned RLE with raw storage as fallback.
- RFMT: runtime format; record/catalog layout version.
- RBLK: runtime block; physical flash/RAM block containing records, bodies, or
  both.
- RIDX: runtime index; optional accelerator that maps resolved records to short
  local handles or speeds catalog lookup.
- RSTR: runtime string pool; shared/proof/display text storage.
- RFIX: runtime fixup; unresolved patch/reference site.
- RLNK: runtime link; reference from one runtime record/body to another.
- RBND: runtime bind; process of resolving links/fixups through an RCAT.
- RRES: runtime resolve; lookup operation by hash/name/type.
- CLINK: catalog link; shorthand for the future catalog-linking operation that
  places, relocates, binds, and exposes an `RBODY` through `RREC`/`RCAT`
  records. `CLINK` is proposed vocabulary, not live code today.
- catalog linking: R-YORS dynamic linking path where assembler imports,
  exports, and fixups resolve through typed hash catalog records.
- hash-linked module: loadable or flash-resident body whose public commands,
  routines, data, or symbols are exposed through catalog records.

## Flash Lifecycle Terms

FSB is the preferred flash lifecycle vocabulary for append-only records.

- formed: bytes look like a real record.
- sealed: record passed checks and normal lookup may use it.
- buried: normal lookup skips it, but raw scan can still see it.
- gone: no longer physically present after erase/rewrite.
- condense: copy live records elsewhere, erase the sector, and rewrite compacted
  state. Collapse and compress may appear as informal synonyms, but condense is
  the official term.

Buried does not mean physically gone. Condense is the operation that can make
buried records gone.

## Flash And Address Terms

- ROM image: built binary intended to occupy ROM/flash.
- flash: erasable writable nonvolatile hardware.
- ROM-resident: stored in flash/ROM and treated as firmware.
- burned ROM: current physical contents after programming.
- bank: one selectable 32K flash view, visible at `$8000-$FFFF`.
- bank 0-3: four different physical 32K images mapped into the same
  `$8000-$FFFF` view.
- `$WLPB`: mnemonic for reading the four hex nibbles of a 16-bit CPU address:
  `W` = 4K window (`$W000-$WFFF`), `L` = 256-byte line
  (`$WL00-$WLFF`), `P` = 16-byte paragraph (`$WLP0-$WLPF`), and `B` =
  byte inside that paragraph.
- window: 4K CPU address range selected by the high hex nibble. Window `$8`
  is `$8000-$8FFF`; window `$F` is `$F000-$FFFF`.
- sector: 4K erase unit inside a bank; in banked flash, one 4K window is one
  erase sector of the currently selected flash bank.
- page: 256-byte CPU page.
- segment: logical software range, not necessarily erasable by itself.
- zero page: `$0000-$00FF`.
- user zero page: `$0000-$00AF`, user/free while running in the current policy.
- reserved ZP expansion: `$00B0-$00CC`, held for future R-YORS/HIMON/THE/ASM
  pointer lanes and addressing-mode workspace.
- service ZP: `$00CD-$00EF`, shared low-level service scratch.
- HIMON parser ZP: `$00F0-$00FF`, current monitor command/parser scratch.
- hardware stack page: `$0100-$01FF`.
- RAM workspace/user RAM: `$0200-$7EFF`.
- I/O: `$7F00-$7FFF`.
- flash/ROM address space: `$8000-$FFFF`, the currently selected bank view.
- top sector: `$F000-$FFFF`, the high 4K sector of the selected bank.
- board/config patch pocket: `$FFF0-$FFF9`, one-time-ish flash bytes reserved
  for board id, version, and config until the top sector is erased/rebuilt.
- hardware vector block: `$FFFA-$FFFF`, the W65C02 NMI, RESET, and IRQ/BRK
  vectors.
- protected STR8 window: the chosen policy-protected range ending at `$FFFF`,
  starting at `$FC00`, `$FA00`, `$F800`, `$F600`, `$F400`, `$F200`, or `$F000`
  according to final STR8 size.
- partial top-sector update: read the full top sector, update a staged image,
  erase the sector, write the full staged sector, and verify it so non-STR8
  bytes can be reused without enlarging the protected STR8 window.
- selected flash placement policy: future loader rule for choosing a flash
  address when none is forced; examples include high-to-low, low-to-high, best
  fit, closest-to-top, and first fit in a selected bank or sector range.

Example: `$E000-$EFFF` is window/sector `$E` of whichever bank is currently
selected. Sector `$0` is `$0000-$0FFF`; `$0000-$FFFF` is the full 64K CPU
address space, not sector `$0`.
