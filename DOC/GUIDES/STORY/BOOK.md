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

## Reader Path

The book should read in three layers:

1. The story: why this exists, what changed, and what each piece is for.
2. The machine: actual HIMON, STR8, FNV-era command records, flash, and catalog behavior.
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

Proof lives in the guide set:

- [PRODUCT_BOUNDARIES.md](../STR8/PRODUCT_BOUNDARIES.md) - R-YORS, STR8, IVI/LEAF,
  HIMON, and payload ownership lanes.
- [DECISIONS.md](../DECISIONS.md) - settled calls.
- [HASH.md](../HASH/HASH.md) and [HASH_MAP.md](../HASH/HASH_MAP.md) - hash lookup and catalog model.
- [HIMON_MAP.md](../HIMON/HIMON_MAP.md) - monitor capability map.
- [STR8.md](../STR8/STR8.md) - recovery/update anchor.
- [CATALOG.md](../CATALOG/CATALOG.md) - callable routine surface and RREC seeds.
- [HREC_JOIN_PROOF.md](../CATALOG/HREC_JOIN_PROOF.md) - hash record to callable entry proof.
- [HARDWARE_TEST_LOG.md](../LOGS/HARDWARE_TEST_LOG.md) - board evidence.
- [QCC.md](../QCC/INDEX.md) and topic QCC files - live questions.

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

HIMON is where the system can be touched: command input, current FNV-era dispatch, memory
dump/modify, loading, flashing under guard, disassembly, mini assembly, break,
step, resume, and catalog inspection. It is the bench monitor, not the recovery
anchor.

Questions:

- What work belongs in HIMON instead of STR8?
- How does the monitor stay useful while the catalog system is incomplete?
- What should be debug UI, and what should be catalog/linking infrastructure?
- How do command records, generated docs, and hardware transcripts reinforce
  each other?

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

Questions:

- Which short commands are worth keeping?
- Which destructive operations must be full-word commands?
- How should help text teach the safe mental model without becoming verbose?
- When should the parser accept tight operator forms such as `1234+1`?

Proof and notes:

- [OPERATORS_GUIDE.md](../OPERATORS_GUIDE.md)
- [DECISIONS.md](../DECISIONS.md)
- [HIMON_SEARCH_IMPLEMENTATION_GUIDE.md](../HIMON/HIMON_SEARCH_IMPLEMENTATION_GUIDE.md)

### Chapter 7: Debugging As A Runtime Contract

Answer:

Break, step, resume, register editing, and trap context are not just monitor
features. They define who owns the hardware stack, how context is saved, and
what it means to continue after a trap.

Questions:

- Why does HIMON own the hardware stack on monitor entry?
- What is the difference between `BRK`, NMI, a breakpoint, and a resume?
- When should debugger state become command output, record output, or both?
- Which debug features are proof obligations before user convenience?

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

Questions:

- What must be true before reset enters STR8 first?
- Why should STR8 stay useful without HIMON?
- Why should STR8 stay smaller than any one payload?
- What does LEAF provide without owning payload interrupt policy forever?
- When does S1/S9 stay enough, and when does bank-aware S2/S8 transport help?
- When should STR8 call shared services, and when should it carry private code?
- How does future STR8-N participate in catalogs without owning all catalogs?

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

Questions:

- Which operations are safe in HIMON, and which belong to STR8 or STR8-N?
- What does it mean to restore an image while preserving the protected window?
- How should bank 0 enrollment change backup semantics?
- When do append-only records need condense or compress?

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
dispatch. It can emit bodies, unresolved references, symbol records, aliases,
and fixups that a later resolver can join.

Questions:

- Which assembler syntax is human enough for onboard work?
- What records should assembly emit before the full catalog exists?
- How does a fixup remain safe in RAM versus flash?
- When should labels be text, hashes, or both?

Proof and notes:

- [HASHED_ASM.md](../ASM/HASHED_ASM.md)
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
- What range syntax should search share with D/M/U/COPY/FILL?
- What should be in the proof app, and what should be promoted into HIMON?

Proof and notes:

- [HIMON_SEARCH_IMPLEMENTATION_GUIDE.md](../HIMON/HIMON_SEARCH_IMPLEMENTATION_GUIDE.md)
- [QCC_HASH.md](../QCC/HASH.md)

## Part VI: What Stayed Simple On Purpose

### Chapter 18: What Stayed Simple On Purpose

Answer:

R-YORS keeps some choices small because the hardware, flash risks, and human
operator matter. STR8 V0 does not use FNV or CRC16 for recovery decisions.
Current HIMON records use a readable proving signature. Destructive commands
should be full words. Text compression is optional. Dynamic memory waits behind
fixed workspaces and explicit policy.

Questions:

- Which simplicity is permanent design?
- Which simplicity is scaffolding?
- How do you tell the difference?
- When is cleverness worth its recovery cost?

Proof and notes:

- [DECISIONS.md](../DECISIONS.md)
- [DYNAMIC_MEMORY_FIRST_STEPS.md](../MEMORY/DYNAMIC_MEMORY_FIRST_STEPS.md)
- [QCC_MEMORY.md](../QCC/MEMORY.md)

### Chapter 19: Naming, Vocabulary, And The Shape Of Thought

Answer:

The vocabulary is part of the system. STR8, HIMON, THE, RCAT, RREC, RBODY,
RF, RLNK, BIO, PIN, COR, SYS, and REQUIRED_FOR_RECOVERY are not decoration.
They mark ownership and prevent confused code.

Questions:

- Which names reduce confusion?
- Which names are too cute to carry a contract?
- When should a new prefix exist?
- How can glossary and code keep each other honest?

Proof and notes:

- [GLOSSARY.md](../GLOSSARY.md)
- [DECISIONS.md](../DECISIONS.md)
- [CATALOG.md](../CATALOG/CATALOG.md)

### Chapter 20: Questions The Book Should Keep Alive

These are book-grade questions, not blockers:

- What is the first compact RCAT format that is worth burning into ROM?
- How much name text should writable records carry?
- How should collision candidates be shown on board?
- What is the first safe catalog condense transaction?
- How does STR8-N replace a recovery-required provider?
- Which routine contracts become universal, and which stay board-local?
- When does HIMON stop being a monitor and become THE?
- What is the smallest self-hosted build loop that still feels honest?

## Drafting Order

Do not write the book in chapter order. Write from proof outward:

1. Write the HIMON command/catalog dispatch chapter from current code and
   [HIMON_MAP.md](../HIMON/HIMON_MAP.md).
2. Write STR8 recovery from [STR8.md](../STR8/STR8.md), [BRINGUP.md](../STR8/BRINGUP.md),
   and [HARDWARE_TEST_LOG.md](../LOGS/HARDWARE_TEST_LOG.md).
3. Write the FNV-to-CRC16 hash transition and records from
   [HASH.md](../HASH/HASH.md), [HASH_MAP.md](../HASH/HASH_MAP.md), and
   [HREC_JOIN_PROOF.md](../CATALOG/HREC_JOIN_PROOF.md).
4. Write routines-made-from-routines from [CATALOG.md](../CATALOG/CATALOG.md),
   promoted helpers, and the range-parser/search path.
5. Write catalog linking from [HASHED_ASM.md](../ASM/HASHED_ASM.md),
   [QCC_ASM.md](../QCC/ASM.md), and
   [QCC_CATALOG_LINKING.md](../QCC/CATALOG_LINKING.md).
6. Finish with the reflective chapters: what stayed simple, what remains open,
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
guards, and current FNV-era dispatch. STR8 protects recovery. THE names the future lookup
environment where records, bodies, fixups, and catalogs make code discoverable
and linkable on the machine itself.

This book follows that path without pretending the destination arrived first.
It keeps the false starts, proof apps, hardware transcripts, command grammar
debates, and naming decisions close to the metal, because that is where the
runtime became real.
