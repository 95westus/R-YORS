# The Rolling Of My Own Hashed Runtime System

This is the book spine for R-YORS as a designed, built, and argued system. It
does not replace the reference docs. It gives the story a table of contents:
what each chapter should answer, what questions remain alive, and where the
technical proof already lives.

Working title:

```text
The Rolling Of My Own Hashed Runtime System
```

Possible subtitle:

```text
R-YORS, HIMON, STR8, and the path from monitor commands to catalog-linked code
```

Product subtitle:

```text
STR8 keeps the board alive. LEAF opens the interrupt front door. HIMON is the
default workbench payload.
```

## Book Promise

The book is about building a small hashed runtime system from the bench up. It
is not a claim that hash lookups, catalogs, flash records, monitors, loaders, or
linkers are new ideas. It is the record of making them personal, concrete, and
operational on this board, with this vocabulary, and under these constraints.

The central claim:

```text
A tiny monitor can become more than a command loop when names, commands,
routines, records, and future fixups all share one compact hash lookup path.
```

The second claim:

```text
Recovery must be designed before cleverness. STR8 protects the system that
HIMON and THE want to grow.
```

The third claim:

```text
Routines made from routines are the real unit of growth. Hash records and
catalogs matter because they let useful behavior keep being found, reused, and
relinked.
```

## Truth And Provenance

The book should mark idea origin when it matters. Walter's original names,
edicts, bench observations, and design calls should stay visible as Walter's.
Old public machinery should be named as old public machinery. AI/Codex help
should be marked where it shaped wording, organization, comparisons, code, or
design synthesis.

Use [PROVENANCE.md](../META/PROVENANCE.md) for the tag set:

```text
ORIG-WLP2
BENCH-WLP2
COLLAB-AI
EXT-PRIOR
DERIVED-SRC
UNKNOWN
```

The book voice may still say "my" for Walter's board, vocabulary, constraints,
and design journey. The provenance tags keep that personal story from claiming
that old assembler, linker, catalog, Forth, FNV, or CPU ideas were invented here.

## Reader Path

The book should read in three layers:

1. The story: why this exists, what changed, and what each piece is for.
2. The machine: actual HIMON, STR8, ASM v1, FNV-era records, flash, and
   catalog behavior.
3. The questions: what is settled, what is only proved, and what remains open.

## How The Work Moves

The book should not pretend R-YORS knew the answer before the board, code, and
operator did. The honest rhythm is:

```text
Want       what the system is trying to become
Need       what the board, flash, RAM, or operator safety requires
Answer     the current design call
Question   what still feels uncertain
Change     the place where an older answer stops fitting
Do         the proof, command, loader, transcript, or ROM image
Question   what the proof exposed
Keep       the answer that survived contact with the machine
Do more    the next behavior made possible by the kept answer
No more    the retired path, boundary, or edict that should not be reopened casually
```

That motion matters. A chapter may begin with a want, discover a need, answer
it badly, change its mind, do a smaller proof, keep the part that worked, and
say no more to the part that became too expensive or unsafe. This is not
indecision. It is the real build record of a system small enough that every
byte, bank, vector, and operator prompt can change the answer.

Personal bench note, 2026-07-02 (COLLAB-AI):

> Bad moods are weather, not character. Good work still gets done under cloudy weather.

Proof lives in the guide set:

- [PRODUCT_BOUNDARIES.md](../STR8/PRODUCT_BOUNDARIES.md) - R-YORS, STR8, IVI/LEAF,
  HIMON, and payload ownership lanes.
- [DECISIONS.md](../DECISIONS.md) - settled calls.
- [HASH.md](../HASH/HASH.md) and [HASH_MAP.md](../HASH/HASH_MAP.md) - hash lookup and catalog model.
- [HIMON_MAP.md](../HIMON/HIMON_MAP.md) - monitor capability map.
- [STR8.md](../STR8/STR8.md) - recovery/update anchor.
- [CATALOG.md](../CATALOG/CATALOG.md) - callable routine surface and RREC seeds.
- [HREC_JOIN_PROOF.md](../CATALOG/HREC_JOIN_PROOF.md) - hash record to callable entry proof.
- [ASM/ASM_USER_GUIDE.md](../ASM/ASM_USER_GUIDE.md) - current ASM operator guide.
- [ASM/MOVABLE_MODULES.md](../ASM/MOVABLE_MODULES.md) - sealed body, package, and overlay planning.
- [ASM/TEST_PLAN.md](../ASM/TEST_PLAN.md) - ASM v1 host and board proof gate.
- [HARDWARE_TEST_LOG.md](../LOGS/HARDWARE_TEST_LOG.md) - board evidence.
- [QCC.md](../QCC/INDEX.md) and topic QCC files - live questions.

## Recent Book Delta: 2026-07-01 Through 2026-07-05

This section is a dated catch-up list for the book spine. It is not a full
commit changelog. It names the features, removals, changed behavior, proofs,
and design ideas that should be reflected when chapters are drafted.

2026-07-01:

- ASM runtime-paste state moved into UDATA, the runtime workspace shrank, and
  output-overlap guards became explicit. This changed paste ASM from "emit into
  a handy high-RAM spot" toward "protect the live assembler while emitting."
- ASM gained sealed export records. `EXPORT name` became concrete metadata,
  not only future catalog language.
- HIMON RX lookahead behavior was documented so the operator-facing line input
  story does not hide a bench-discovered edge.

2026-07-02:

- HIMON workspace moved above UPA and `M` writes into monitor workspace became
  protected. This tightened the RAM ownership story around `$7A00-$7EFF`.
- ASM `IMPORT name` became intentional metadata. Declared imports defer resident
  binding instead of silently becoming today-address calls.
- ASM seal records learned import fixups, selected-byte import fixups, and
  relocation rows for internal and imported operands.
- `SEAL> RESOLVE` became the proof command for resolving import rows through
  current RJOIN and patching the RAM body in place.
- `SEAL> RELOCATE address` became the RAM overlay proof: copy the sealed body
  to a new base and patch internal relocation rows there.
- `SEAL> PACKAGE address` became AP v1: a RAM envelope with tagged `S`, `R`,
  `E`, `I`, and `B` sections. `CHECK` was proved as a diagnostic reader, then
  kept out of the default flash image for space.

2026-07-03:

- HIMON service vectors became useful to ASM as a shared helper surface. ASM can
  call resident output/string/hash-style helpers without carrying every copy
  locally.
- HIMON added an HB string service for ASM, and ASM's repeated hex-word output
  paths were factored down for space.
- Focused firmware builds and service diagnostics made the vector block easier
  to inspect on the board.

2026-07-04:

- HIMON removed the user-facing `U` unassemble command. `B`, `N`, NMI-to-debug,
  and the register dump remain; the debug opcode display was trimmed instead of
  deleted.
- HIMON loader behavior was hardened around the RAM/I/O boundary: `$7F00-$7FFF`
  is not ordinary RAM, normal `L` reports compact `LERR=$ee`, and `L F` keeps
  richer flash diagnostics.
- ASM source success output became quiet, then the prompt gained the current PC
  as `ASM>$hhhh:`. `.P` remains the explicit source-mode PC query.
- ASM `.`/`ASM FLASH BYE` now returns status to HIMON with `A=rc` and
  carry clear/set, so a caller can tell clean exit from failed `END`.
- `PACKAGE` now recomputes the written BODY FNV before returning success.
- The computed-neighbor Life sample proved that a larger interactive source can
  still be assembled and run on the board under the tighter flash ASM rules.

2026-07-05:

- The current ASM user guide was added to pull operator behavior, syntax,
  local labels, directives, `END`, `SEAL`, `RESOLVE`, `RELOCATE`, `PACKAGE`,
  memory limits, and examples into one manual.
- The HIMON loader RAM/I/O boundary proof was recorded: `D` skips I/O rows,
  `M` protects monitor/I/O addresses, normal `L` rejects `$7F00` with
  `LERR=$02`, and `L F` preserves address-rich protected-write diagnostics.
- AP package/load/install planning advanced: moving the AP envelope inside
  flash does not require relocation, but executing its BODY at a different base
  does. Future install can search for a flash hole, store the envelope, then
  later load/relocate the BODY into RAM or an overlay tray.
- Banked overlay-call planning settled on a likely first profile: a one-sector
  BODY such as `$2000-$2FFF`, with `$3000-$6FFF` available for thunks,
  dependency bodies, UDATA, and scratch after ASM has returned to HIMON.
- ASM-as-chunks planning was documented: flash ASM may eventually split into
  several 4K bodies with stable entries, while the current flash command still
  runs as one resident image.
- The afternoon ASM RAM split plan was documented for future slices:
  `$2000-$4FFF` as source output/package scratch while ASM is active,
  `$5000-$79FF` as ASM private workspace, `$7A00-$7EFF` protected for HIMON,
  and `$7F00-$7FFF` forbidden I/O.
- `RESIB` was named as a candidate human nickname for the AP v1 package section
  family. It does not change the current wire order.

## Part I: Why Hash-First?

### Chapter 1: Why Hash-First?

Answer:

Hash-first lookup turns command names, routine names, symbols, aliases, fixups,
and future catalog entries into variations of one problem: compute a compact
lookup hash, scan records, classify the match, and act. The hash is not the whole
object. It lets a small system find the object without carrying full text in
every hot path.

This chapter should explain why a monitor command table wants to become a
record scanner, and why that matters later when the same scanner idea grows
into RCAT/RREC/RBODY/RF/RLNK.

Questions:

- What does hash-first lookup buy on a W65C02 system where every byte matters?
- When is a compact hash enough, and when must the record carry proof text?
- How should collisions be found, displayed, and resolved?
- What belongs in the scanner, and what belongs in the surrounding record?

Proof and notes:

- [HASH.md](../HASH/HASH.md)
- [HASH_MAP.md](../HASH/HASH_MAP.md)
- [HREC_JOIN_PROOF.md](../CATALOG/HREC_JOIN_PROOF.md)
- [DECISIONS.md](../DECISIONS.md)

### Chapter 2: Hash Identity And Compact Records

Answer:

FNV-1a was the first working runtime/catalog/symbol hash path. It is not treated
as a secret or security feature, but FNV-1a32 is now the settled public identity
hash for names that cross boundaries. CRC16 remains a compact local/scoped
hash/check where record context handles collisions. CRC32 is a possible stronger
integrity check for blocks or bodies, not ordinary lookup identity.

The chapter should keep the distinction sharp:

```text
FNV-1a32    public command/export/symbol identity
CRC16       compact local/scoped hash or check
CRC32       optional stronger block/body integrity check
signature   record proof or table proof
kind        record/payload classification
flags       lifecycle or policy metadata
```

Questions:

- Where can CRC16 safely replace a full public FNV32?
- Which current `FN(V|$80)` marker bytes are proof/debug overhead rather than
  final record structure?
- Why avoid per-record algorithm tags unless multi-algorithm catalogs become real?
- How does a system avoid treating a guessed hash as authority?

Proof and notes:

- [HASH.md](../HASH/HASH.md)
- [HASH_MAP.md](../HASH/HASH_MAP.md)
- [QCC_HASH.md](../QCC/HASH.md)

### Chapter 3: From Monitor Commands To Callable Records

Answer:

Current HIMON command records already show the transition:

```text
'F','N',('V'|$80),hash0,hash1,hash2,hash3,kind,inline-code...
```

For `kind=$00`, code begins immediately after the kind byte. That is a proving
shape, not the final catalog shape. The important move is that a command is no
longer merely an entry in a hand-written dispatch table. It is a typed record
that the monitor can find by hash and call.

Questions:

- What makes a command record different from a future routine export record?
- When does a record need an explicit `entry_lo,entry_hi` pointer?
- Should commands, routines, aliases, symbols, constants, and ranges share one
  scanner or only one hash convention?
- What should `# token` show when records become richer?

Proof and notes:

- [HIMON_MAP.md](../HIMON/HIMON_MAP.md)
- [HASH_MAP.md](../HASH/HASH_MAP.md)
- [HREC_JOIN_PROOF.md](../CATALOG/HREC_JOIN_PROOF.md)

### Chapter 4: The Record Is The Meaning

Answer:

The hash narrows the search. The record gives the match meaning. A future
catalog can use the same compact hash path for commands, routines, symbols, data,
constants, memory ranges, modules, packets, fixups, aliases, and strings.

This chapter should argue against letting one byte do too much. `kind`,
`flags`, `bank`, size fields, text proof, and payload shape all exist so the
hash does not become overloaded.

Questions:

- What are the minimum fields for a useful RREC?
- Which fields are parsing layout, and which are lifecycle policy?
- How much text proof should writable catalogs carry?
- Can small ROM tables stay hash-only while writable records carry more proof?

Proof and notes:

- [HASH_MAP.md](../HASH/HASH_MAP.md)
- [CATALOG.md](../CATALOG/CATALOG.md)
- [QCC_CATALOG_LINKING.md](../QCC/CATALOG_LINKING.md)

## Part II: HIMON As The Working Bench

### Chapter 5: HIMON As The Working Bench

Answer:

HIMON is where the system can be touched: command input, current FNV-era
dispatch, memory dump/modify, guarded S-record loading, guarded flash loading,
break, step, resume, catalog inspection, and entry into the flash-resident ASM
workbench. It is the bench monitor, not the recovery anchor.

The old resident mini-assembler and the user-facing `U` unassemble command are
gone. That removal is part of the story: HIMON kept the debug features that the
board needs now, and made room for ASM and loader hardening instead of carrying
two assembler stories at once.

Questions:

- What work belongs in HIMON instead of STR8?
- How does the monitor stay useful while the catalog system is incomplete?
- What should be debug UI, and what should be catalog/linking infrastructure?
- How do command records, generated docs, and hardware transcripts reinforce
  each other?
- Which old monitor conveniences should be removed once ASM or STR8 owns the
  better version?

Proof and notes:

- [HIMON_MAP.md](../HIMON/HIMON_MAP.md)
- [OPERATORS_GUIDE.md](../OPERATORS_GUIDE.md)
- [HIMON_DEBUG_TESTING.md](../HIMON/HIMON_DEBUG_TESTING.md)
- [HARDWARE_TEST_LOG.md](../LOGS/HARDWARE_TEST_LOG.md)

### Chapter 6: The Command Language As Human Interface

Answer:

The command language is part of the machine. It is not just syntax. It encodes
bench habits, danger boundaries, and the difference between quick inspection
and destructive action.

Range syntax is a good example:

```text
start end       inclusive end
start +count    count bytes
```

Short end tokens are page-local, so `D 3000 FF` means `$3000-$30FF`. Three- or
four-digit ends are full addresses, so `D 1000 FFF` is not shorthand for
`$1FFF`; use `D 1000 1FFF` or `D 1000 +1000`.

The loader language now also shows the difference between compact routine
status and rich destructive diagnostics. Normal `L` failures can report
`LERR=$ee`, including the hard RAM/I/O ceiling at `$7F00`; `L F` keeps
address-rich diagnostics such as protected flash writes because the operator
needs to know what range was refused.

Questions:

- Which short commands are worth keeping?
- Which destructive operations must be full-word commands?
- How should help text teach the safe mental model without becoming verbose?
- When should the parser accept tight operator forms such as `1234+1`?
- When should an error be only `ERR=$ee`, and when should it carry address and
  count evidence?

Proof and notes:

- [OPERATORS_GUIDE.md](../OPERATORS_GUIDE.md)
- [DECISIONS.md](../DECISIONS.md)
- [HIMON_SEARCH_IMPLEMENTATION_GUIDE.md](../HIMON/HIMON_SEARCH_IMPLEMENTATION_GUIDE.md)

### Chapter 7: Debugging As A Runtime Contract

Answer:

Break, step, resume, register editing, and trap context are not just monitor
features. They define who owns the hardware stack, how context is saved, and
what it means to continue after a trap.

The current design keeps the hardware-useful parts: `B`, `B C`, `B L`, `N`,
`X`, NMI-to-debug, one-shot breakpoint restoration, and the register dump. The
old unassemble command was removed, but `N` still prints compact opcode/length
metadata before resuming. This is the debug contract trimmed to what the board
still proves.

Questions:

- Why does HIMON own the hardware stack on monitor entry?
- What is the difference between `BRK`, NMI, a breakpoint, and a resume?
- When should debugger state become command output, record output, or both?
- Which debug features are proof obligations before user convenience?
- How much disassembly belongs in live debug output before it becomes a ROM
  cost instead of a bench tool?

Proof and notes:

- [HIMON_DEBUG_TESTING.md](../HIMON/HIMON_DEBUG_TESTING.md)
- [HIMON_MAP.md](../HIMON/HIMON_MAP.md)
- [DECISIONS.md](../DECISIONS.md)

## Part III: STR8 And Recovery

### Chapter 8: STR8 As Board Management Product

Answer:

STR8 exists so recovery does not depend on the thing being recovered. It is the
board management product: safe boot, flash map, backup, restore, target install,
verify, protected-window policy, and handoff.

HIMON is the default workbench payload, not the reason STR8 exists. STR8 should
be useful to someone who wants to install WDCMONv2, BETTERMON, BASIC, FORTH, a
game, or a personal monitor without buying into the whole R-YORS runtime stack.

The product boundary makes the book readable:

```text
R-YORS  the project/system direction
STR8    board management and survival
IVI     Interrupt Vector Indirection from BSO2, pronounced IVY
LEAF    newer product-shaped front door built on IVI
HIMON   default monitor payload and workbench
THE     future lookup/catalog environment
```

IVI is the interrupt-vector indirection pattern. IVY is only how IVI is spoken
out loud. LEAF is the Latched Entry Address Frontdoor: the newer name for making
that mechanism feel like a board feature instead of a register spreadsheet.

Later, STR8 can learn a bigger transport language without changing that story.
S1/S9 is enough for V0 install packages. A future S2/S8 `.s28` path can use
24-bit addresses as physical SST39SF010A flash-chip addresses: bank 3, the
reset/default boot bank, starts at physical flash `$18000`, so the boot bank can
be named directly for bulk storage, retrieval, restore, and transport.

STR8 V0 intentionally keeps console byte I/O private as `STR8_CON_*` rather
than publishing duplicate `BIO_*` or `PIN_*` catalog providers.

The July 2026 package work adds a future STR8-facing distinction: installing an
AP envelope into flash is storage and catalog work, not the same as relocating
and running the BODY. An envelope can move within flash unchanged. A BODY that
executes at a new base needs relocation, import resolution, or both.

Questions:

- What must be true before reset enters STR8 first?
- Why should STR8 stay useful without HIMON?
- Why should STR8 stay smaller than any one payload?
- What does LEAF provide without owning payload interrupt policy forever?
- When does S1/S9 stay enough, and when does bank-aware S2/S8 transport help?
- When should STR8 call shared services, and when should it carry private code?
- How does future STR8-N participate in catalogs without owning all catalogs?
- When should STR8 merely store a package, and when should it load, relocate,
  resolve, or install executable bytes?

Proof and notes:

- [PRODUCT_BOUNDARIES.md](../STR8/PRODUCT_BOUNDARIES.md)
- [STR8.md](../STR8/STR8.md)
- [OPERATORS_GUIDE.md](../OPERATORS_GUIDE.md)
- [TECHNICAL_GUIDE.md](../TECHNICAL_GUIDE.md)
- [BRINGUP.md](../STR8/BRINGUP.md)
- [QCC_STR8.md](../QCC/STR8.md)

### Chapter 9: Flash, Purge, And REQUIRED_FOR_RECOVERY

Answer:

Purge policy is lifecycle metadata, not record kind. `kind` says what a record
is. Flags say what can happen to it. The active recovery dependency chain should
use a flag such as `REQUIRED_FOR_RECOVERY`, which means ordinary purge,
movement, or superseding must not touch it outside an explicit recovery update
transaction.

Important distinction:

```text
BIO_* or PIN_* does not automatically mean REQUIRED_FOR_RECOVERY.
Only the active recovery dependency chain gets that flag.
```

Questions:

- What exactly counts as the active recovery dependency chain?
- How does a future condense operation prove it did not bury recovery?
- What transaction can replace a recovery-required provider?
- How should catalogs show pinned, buried, gone, and replaceable records?

Proof and notes:

- [STR8.md](../STR8/STR8.md)
- [HASH_MAP.md](../HASH/HASH_MAP.md)
- [QCC_FLASH.md](../QCC/FLASH.md)
- [DECISIONS.md](../DECISIONS.md)

### Chapter 10: Banked Flash As A Living Medium

Answer:

Flash is not just storage. It is a medium with erase sectors, one-way bit
transitions, bank selection, protected ranges, source/destination policy, and
recovery failure modes.

The near-term AP package idea treats banked flash first as object storage.
`INSTALL` can later search for an appropriately sized erased hole, write the
package envelope, and mark progress by clearing bits in an initially erased
status byte. Loading, relocating, resolving imports, and running the BODY are
separate steps.

A useful first overlay profile is a one-sector executable BODY loaded to
`$2000-$2FFF`, with `$3000-$6FFF` available for thunks, dependencies, UDATA, and
scratch after ASM has returned to HIMON. Moving the package envelope inside
flash does not require relocation; executing the body somewhere else does.

Questions:

- Which operations are safe in HIMON, and which belong to STR8 or STR8-N?
- What does it mean to restore an image while preserving the protected window?
- How should bank 0 enrollment change backup semantics?
- When do append-only records need condense or compress?
- What is the first safe flash-hole allocator for AP package storage?
- Which status bits should a flash install transaction clear as proof of
  progress?

Proof and notes:

- [STR8.md](../STR8/STR8.md)
- [STR8_FLASH_UPDATE_PROPOSAL.md](../STR8/STR8_FLASH_UPDATE_PROPOSAL.md)
- [QCC_FLASH.md](../QCC/FLASH.md)
- [MEMORY_MAP.md](../MEMORY/MEMORY_MAP.md)

## Part IV: Catalog Linking

### Chapter 11: RCAT, RREC, RBODY, RF, RLNK

Answer:

The catalog-linked system is made of named, typed records and bodies:

```text
RCAT   runtime catalog dataset
RREC   typed runtime record/export
RBODY  executable/data/string/module body
RF     unresolved reference/fixup record
RLNK   resolved link/fixup result
```

The path is:

```text
assemble RBODY -> create RF -> verify body -> export RREC into RCAT
later code -> import by hash/name -> resolve RF/RLNK -> call entry or use value
```

Questions:

- What is the smallest useful RREC?
- When does an RREC point to an RBODY, and when does it carry inline value?
- Where do aliases live?
- How does onboard linking avoid making flash updates unsafe?

Proof and notes:

- [HASH_MAP.md](../HASH/HASH_MAP.md)
- [HASHED_ASM.md](../ASM/HASHED_ASM.md)
- [QCC_CATALOG_LINKING.md](../QCC/CATALOG_LINKING.md)

### Chapter 12: Routines Made From Routines

Answer:

The rule is not "copy code less." The rule is "promote useful behavior into a
callable contract." First static-link the contract with ordinary labels and
libraries. Later export the same contract as an RREC and let RF/RLNK resolve
callers.

The range parser is the model. HIMON and search both need `start end|+count`,
but each has its own workspace. The reusable behavior is range arithmetic and
semantics. The caller-specific part is the adapter around `CMD_*` or
`SEARCH_*` state.

Questions:

- What is the boundary between reusable behavior and caller workspace?
- When should a helper become `UTL_*`, `COR_*`, `CAT_*`, or something else?
- Which duplicated routines should be promoted first?
- How does the catalog keep a contract stable while implementation changes?

Proof and notes:

- [CATALOG.md](../CATALOG/CATALOG.md)
- [DECISIONS.md](../DECISIONS.md)
- [HIMON_SEARCH_IMPLEMENTATION_GUIDE.md](../HIMON/HIMON_SEARCH_IMPLEMENTATION_GUIDE.md)

### Chapter 13: Static Linking Before Catalog Magic

Answer:

Static linking is the first proof. Catalog linking should not hide an unclear
contract. A routine should become a normal callable module with documented ABI,
scratch use, proof state, and tests before it becomes a dynamic RREC export.

Questions:

- What ABI fields belong in a routine contract?
- How does `rom.lib` promotion prepare a routine for RCAT promotion?
- Which routines are too board-specific for public catalog export?
- How can a future resolver choose between multiple providers?

Proof and notes:

- [CATALOG.md](../CATALOG/CATALOG.md)
- [SYMBOL_XREF.md](../ASM/SYMBOL_XREF.md)
- [QCC_CATALOG_LINKING.md](../QCC/CATALOG_LINKING.md)

### Chapter 14: Hashed ASM And Self-Hosted Growth

Answer:

The assembler is where hash-first lookup becomes construction, not just
dispatch. ASM v1 is now a flash-resident HIMON command loaded at `$8000` and
entered as `ASM` through the current FNV/RJOIN catalog. Its source prompt shows
the current PC as `ASM>$hhhh:`; accepted lines are quiet; `.P` is the explicit
source-mode PC query; rejected lines still report `ERR=$ee NAME PC=$hhhh`.

ASM assembles W65C02 source into bare RAM programs, normally starting at
`$2000`. It supports the working v1 syntax surface: labels, local labels,
expressions, `ORG`, `EQU`, `DB`, `DW`, `DS`, `EXPORT`, `IMPORT`, and `END`.
It tracks symbols, references, local scopes, fixups, relocation rows, export
records, and import records. Direct resident calls can still resolve through
RJOIN/K05 records, while declared imports deliberately defer binding for later
package/load/install work.

The post-`END` `SEAL>` window is the current bridge from bench assembly to
movable module. `SEAL` freezes body facts. `RESOLVE` can patch declared imports
through the current resident catalog. `RELOCATE address` copies the body to a
new RAM base and applies internal relocation rows. `PACKAGE address` writes an
AP v1 envelope with tagged seal, relocation, export, import, and body sections,
then recomputes the written BODY FNV before returning success. `CHECK` exists
as a diagnostic/full-core reader proof, but is not part of the default flash
image.

This is not self-hosting yet, and it is not the final flash catalog format yet.
The book should show the real middle state: a board can now receive source,
assemble code, fix forward references, print session tables, recover from
failed lines transactionally, export and import names, seal a body, relocate it,
package it, and run both tiny proofs and larger interactive examples. Later
RREC/RBODY/RF/RLNK records have to grow from that visible behavior instead of
replacing it with hand-waving.

Questions:

- Which assembler syntax is human enough for onboard work?
- What records should assembly emit before the full catalog exists?
- How does a fixup remain safe in RAM versus flash?
- When should labels be text, hashes, or both?
- What session evidence must survive when a RAM body becomes a sealed catalog
  export?
- Which opcode and addressing-mode rows are proof enough for ASM v1, and which
  belong to later coverage work?
- When should AP v1 become the package spine for future RREC/RBODY work?
- How should the `$2000-$4FFF` source-output arena and `$5000-$79FF` ASM
  workspace split change table limits without making ASM less safe?

Proof and notes:

- [HASHED_ASM.md](../ASM/HASHED_ASM.md)
- [ASM/DECISIONS.md](../ASM/DECISIONS.md)
- [ASM/TEST_PLAN.md](../ASM/TEST_PLAN.md)
- [QCC_ASM.md](../QCC/ASM.md)
- [HASH_MAP.md](../HASH/HASH_MAP.md)

## Part V: Worked Examples

### Chapter 15: HREC Join Proof

Answer:

The HREC proof shows the smallest meaningful bridge: find a hash record, derive
the callable entry, and execute or inspect it. It is the seed of catalog linking
before the full catalog exists.

Questions:

- What does a proof record prove?
- What does it deliberately not prove?
- How does the join proof differ from a final RREC resolver?

Proof and notes:

- [HREC_JOIN_PROOF.md](../CATALOG/HREC_JOIN_PROOF.md)

### Chapter 16: LIFE As An RCAT Member

Answer:

The standalone LIFE program can be reimagined as an RBODY with RREC exports and
catalog-visible metadata. This makes the book concrete: a real body migrates
from "load this program" toward "link this member."

Questions:

- What does a game/app export?
- Which data is code, which is state, and which is catalog metadata?
- What does it mean for a program to be discoverable on board?

Proof and notes:

- [LIFE_RCAT_MEMBER.md](../CATALOG/LIFE_RCAT_MEMBER.md)

### Chapter 17: Search As A Promotion Story

Answer:

Search begins as a proof app, then becomes a HIMON command, then becomes a
consumer of shared parser and output conventions. It demonstrates the path from
one useful proof to a resident tool.

Questions:

- How should hits be printed?
- What range syntax should search share with `D`, `M`, `L`, and future
  copy/fill tools?
- What should be in the proof app, and what should be promoted into HIMON?

Proof and notes:

- [HIMON_SEARCH_IMPLEMENTATION_GUIDE.md](../HIMON/HIMON_SEARCH_IMPLEMENTATION_GUIDE.md)
- [QCC_HASH.md](../QCC/HASH.md)

### Chapter 18: Pasteable And Flash ASM On The Board

Answer:

Pasteable ASM is the worked proof that the runtime can build useful code on
the machine itself. The earlier board path loaded the ASM runtime/paste image
at `$2000`, started it with `G 2000`, assembled source into RAM, finalized with
`END`, and ran the emitted program with an ordinary HIMON `G` command.

The current board path is stronger: HIMON loads the flash-resident ASM image at
`$8000` with `L F`, enters it as the `ASM` command, shows the PC-bearing
`ASM>$hhhh:` prompt, assembles source at `$2000+`, and returns to HIMON with an
explicit status. `SEAL>` then gives the operator module actions before leaving
ASM: `SEAL`, `RESOLVE`, `RELOCATE`, `PACKAGE`, `NEW`, and `.`.

The important proof is not only that opcodes appear in RAM. ASM has assembled
programs that call resident HIMON/THE services by name, patch forward-reference
fixups, print symbol/fixup/relocation tables, recover from bad non-`END` lines
without poisoning the session, package AP v1 envelopes, relocate sealed bodies,
and run larger interactive examples. The computed-neighbor Life source is a
good book example because it ran under the tighter flash ASM guard without
needing the old `$7000` output habit.

The proof path keeps source-width address policy honest: `$12` and `$0012` may
name the same numeric address, but they are not the same instruction contract.
It also keeps memory ownership honest: current flash ASM protects high RAM
while it is active, and the next planned split narrows source output toward
`$2000-$4FFF` so `$5000-$79FF` can relieve ASM table pressure.

Questions:

- What makes an onboard assembly proof more convincing than a host-side smoke?
- How much table/report output is enough for an operator to trust a session?
- Which resident names should ASM be allowed to join before catalogs are rich?
- When should a pasted RAM body become an exportable RBODY instead of a bench
  scratch image?
- What board transcript proves a package envelope, a relocated body, and the
  original body are three different things?
- Which large interactive source should become the canonical "ASM builds
  something real" example?

Proof and notes:

- [ASM/TEST_PLAN.md](../ASM/TEST_PLAN.md)
- [ASM/SAMPLES/ASMTEST_3000.asm](../ASM/SAMPLES/ASMTEST_3000.asm)
- [ASM/SAMPLES/ASM_LINE_ECHO_7000.asm](../ASM/SAMPLES/ASM_LINE_ECHO_7000.asm)
- [ASM/ASM_USER_GUIDE.md](../ASM/ASM_USER_GUIDE.md)
- [HARDWARE_TEST_LOG.md](../LOGS/HARDWARE_TEST_LOG.md)

## Part VI: What Stayed Simple On Purpose

### Chapter 19: What Stayed Simple On Purpose

Answer:

R-YORS keeps some choices small because the hardware, flash risks, and human
operator matter. STR8 V0 does not use FNV or CRC16 for recovery decisions.
Current HIMON records use a readable proving signature. Destructive commands
should be full words. Text compression is optional. Dynamic memory waits behind
fixed workspaces and explicit policy.

The same restraint now applies inside ASM. `CHECK` was proved and then removed
from the default flash image because package/load/install needs the bytes.
Accepted source lines went quiet, but rejected lines kept useful diagnostics.
HIMON's unassemble command was removed, but debug stepping kept compact opcode
evidence. The next RAM split should grow table room only after the new boundary
is proven, not in the same slice that moves the workspace.

Questions:

- Which simplicity is permanent design?
- Which simplicity is scaffolding?
- How do you tell the difference?
- When is cleverness worth its recovery cost?
- Which diagnostic proofs should remain host/full-core only once the flash
  image is tight?

Proof and notes:

- [DECISIONS.md](../DECISIONS.md)
- [DYNAMIC_MEMORY_FIRST_STEPS.md](../MEMORY/DYNAMIC_MEMORY_FIRST_STEPS.md)
- [QCC_MEMORY.md](../QCC/MEMORY.md)

### Chapter 20: Naming, Vocabulary, And The Shape Of Thought

Answer:

The vocabulary is part of the system. STR8, HIMON, THE, RCAT, RREC, RBODY,
RF, RLNK, AP v1, BIO, PIN, COR, SYS, and REQUIRED_FOR_RECOVERY are not
decoration. They mark ownership and prevent confused code.

`RESIB` is a candidate human nickname for the AP v1 section family:
relocation, export, seal, import, body. It is useful only if it helps people
remember the package shape. It must not blur the current AP v1 wire order or
pretend the nickname is a loader contract.

Questions:

- Which names reduce confusion?
- Which names are too cute to carry a contract?
- When should a new prefix exist?
- How can glossary and code keep each other honest?
- When is a nickname helpful, and when should it stay out of command syntax?

Proof and notes:

- [GLOSSARY.md](../GLOSSARY.md)
- [DECISIONS.md](../DECISIONS.md)
- [CATALOG.md](../CATALOG/CATALOG.md)

### Chapter 21: Questions The Book Should Keep Alive

These are book-grade questions, not blockers:

- What is the first compact RCAT format that is worth burning into ROM?
- How much name text should writable records carry?
- How should collision candidates be shown on board?
- What is the first safe catalog condense transaction?
- How does STR8-N replace a recovery-required provider?
- Which routine contracts become universal, and which stay board-local?
- When does HIMON stop being a monitor and become THE?
- When does pasteable ASM stop being a RAM proof and become an export path?
- What is the smallest self-hosted build loop that still feels honest?
- What is the first safe `LOAD`/`INSTALL` path for AP v1 packages?
- How much validation belongs in `PACKAGE`, and how much belongs in the future
  loader/installer?
- Does the `$2000-$4FFF` output and `$5000-$79FF` ASM workspace split become a
  permanent ASM contract or only the next pressure-relief step?
- When should ASM move from one flash image to chunked 4K bodies with stable
  entries?

## Drafting Order

Do not write the book in chapter order. Write from proof outward:

1. Write the HIMON command/catalog dispatch chapter from current code and
   [HIMON_MAP.md](../HIMON/HIMON_MAP.md).
2. Write STR8 recovery from [STR8.md](../STR8/STR8.md),
   [BRINGUP.md](../STR8/BRINGUP.md), and
   [HARDWARE_TEST_LOG.md](../LOGS/HARDWARE_TEST_LOG.md).
3. Write the FNV-to-CRC16 hash transition and records from
   [HASH.md](../HASH/HASH.md), [HASH_MAP.md](../HASH/HASH_MAP.md), and
   [HREC_JOIN_PROOF.md](../CATALOG/HREC_JOIN_PROOF.md).
4. Write routines-made-from-routines from [CATALOG.md](../CATALOG/CATALOG.md),
   promoted helpers, and the range-parser/search path.
5. Write catalog linking from [HASHED_ASM.md](../ASM/HASHED_ASM.md),
   [ASM/TEST_PLAN.md](../ASM/TEST_PLAN.md), [QCC_ASM.md](../QCC/ASM.md),
   [ASM/MOVABLE_MODULES.md](../ASM/MOVABLE_MODULES.md), and
   [QCC_CATALOG_LINKING.md](../QCC/CATALOG_LINKING.md).
6. Write pasteable and flash ASM as a worked example from the 2026-06-06
   through 2026-07-05 board proofs before claiming any self-hosted arc.
   Include the shift from runtime paste, to flash `ASM`, to `SEAL>`, to AP v1
   packages and relocation.
7. Finish with the reflective chapters: what stayed simple, what remains open,
   and how the vocabulary shaped the system.

## Chapter Template

Each finished chapter should keep this shape:

```text
Want
  What did the system or operator want at this point?

Need
  What did the hardware, ROM/RAM layout, recovery rule, or human workflow require?

Question
  What problem did this chapter start with?

Answer
  What is the current R-YORS answer?

Machine
  What code, records, command behavior, or memory layout proves it?

Change of mind
  What old answer was corrected, narrowed, or retired?

Tradeoff
  What did this answer reject?

Open questions
  What should not be silently settled yet?

Pointers
  Which guide files and source files hold the proof?
```

## Possible Back-Cover Copy

R-YORS is a small W65C02 system that grows from a monitor into a hashed runtime
environment. HIMON provides the bench: commands, debugging, loading, flash
guards, and current FNV-era dispatch. STR8 protects recovery. THE names the
future lookup environment where records, bodies, fixups, and catalogs make code
discoverable and linkable on the machine itself. ASM v1 proves the construction
side: pasted and flash-resident source sessions become native code, resident
joins become real calls, local labels and fixups become visible session
evidence, and sealed bodies can be resolved, relocated, and packaged as AP v1
envelopes.

This book follows that path without pretending the destination arrived first.
It keeps the false starts, proof apps, hardware transcripts, command grammar
debates, and naming decisions close to the metal, because that is where the
runtime became real.
