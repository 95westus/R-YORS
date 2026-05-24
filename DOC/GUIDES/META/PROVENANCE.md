# Idea Provenance

This guide keeps the book, story, docs, and code honest about where ideas came
from. It is a truth marker, not a legal ownership system.

R-YORS should not pretend old public ideas are new. It also should not blur
Walter's original project vocabulary and design calls into anonymous outside
help. When origin matters, mark it plainly.

## Tags

Use one or more of these tags when a section, decision, routine, or example
needs provenance:

```text
ORIG-WLP2      Walter/WLP2 original project idea, name, edict, or design call
BENCH-WLP2     observed on the real board, transcript, hardware proof, or test
COLLAB-AI      shaped with AI/Codex assistance; accepted by Walter if kept
EXT-PRIOR      outside prior art, convention, datasheet, manual, or publication
DERIVED-SRC    generated or inferred from current repository source/build data
UNKNOWN        origin not yet known; do not claim originality
```

Use multiple tags when that is the truth:

```text
provenance: ORIG-WLP2, COLLAB-AI
prior art:  W65C02S opcode map, IBM assembler directive vocabulary
evidence:   BENCH-WLP2
```

## Meaning

`ORIG-WLP2` means the idea, name, boundary, or edict came from Walter in this
project context. It does not claim no one in history ever had a related idea.

`BENCH-WLP2` means the statement is grounded in hardware behavior, transcript
work, or a direct local proof.

`COLLAB-AI` means AI helped with wording, organization, comparison, code shape,
or implementation. If the idea becomes a settled project decision, the tag
should still say that the shaping help existed.

`EXT-PRIOR` means the idea is known outside R-YORS. Name the source or family
when possible: WDC/65C02 behavior, IBM assembler practice, FNV-1a, FIG-Forth,
MS BASIC, ELF relocation, Open Firmware/FCode, or another cited source.

`DERIVED-SRC` means the statement came from scanning current source, generated
maps, build artifacts, symbols, or routine headers.

`UNKNOWN` is the honest holding pen. Use it when a claim feels important but
origin is fuzzy.

## Starter Q&A

These are first-pass provenance answers for recurring R-YORS ideas. Correct
them when memory, transcripts, source history, or bench notes say better.

### Q: Is R-YORS itself original?

A: Mark the personal project, vocabulary, constraints, and implementation as
`ORIG-WLP2`. Mark monitor/runtime/catalog/assembler traditions as `EXT-PRIOR`.
Use `COLLAB-AI` only for wording, organization, implementation assistance, or
design synthesis that came through Codex sessions.

```text
provenance: ORIG-WLP2
prior art:  EXT-PRIOR monitors, runtimes, assemblers, catalogs
```

### Q: Is STR8 original?

A: Mark the STR8 project name, recovery role, board-specific policy, and bench
path as `ORIG-WLP2`. Mark boot/recovery loaders, banked images, vector stubs,
and flash copy/verify patterns as `EXT-PRIOR`. Mark hardware-proven behavior as
`BENCH-WLP2`.

```text
provenance: ORIG-WLP2
evidence:   BENCH-WLP2
prior art:  EXT-PRIOR boot recovery, flash update, bank copy
```

### Q: Is HIMON original?

A: Mark the HIMON name, current command set choices, prompt behavior, hash
catalog use, and board-specific monitor shape as `ORIG-WLP2` unless a specific
piece came from outside source. Mark monitor/debugger/loader/assembler concepts
as `EXT-PRIOR`. Mark generated maps and routine trees as `DERIVED-SRC`.

```text
provenance: ORIG-WLP2
prior art:  EXT-PRIOR machine monitors, debuggers, loaders
evidence:   DERIVED-SRC generated HIMON maps
```

### Q: Is THE original?

A: Mark `THE` as a project-local name and boundary when Walter set it. Mark hash
lookup, catalogs, symbol tables, relocation, and linking as `EXT-PRIOR`.

```text
provenance: ORIG-WLP2
prior art:  EXT-PRIOR hash tables, catalogs, linkers, relocations
```

### Q: Is FNV-1a original here?

A: No. FNV-1a is `EXT-PRIOR`. R-YORS use of FNV-1a for command/routine/symbol
identity is project implementation and policy; mark that `ORIG-WLP2` when it is
Walter's design call, and `COLLAB-AI` where Codex helped shape the docs or
tradeoff language.

```text
provenance: ORIG-WLP2, COLLAB-AI
prior art:  EXT-PRIOR FNV-1a
```

### Q: Are RCAT/RREC/RBODY/RF/RD original?

A: The general ideas are not new: catalogs, records, executable bodies,
dependency tables, and relocation/fixup tables are `EXT-PRIOR`. The exact
R-YORS vocabulary and byte contracts should be tagged by origin as remembered:
`ORIG-WLP2` when Walter named or settled them, `COLLAB-AI` when Codex coined or
shaped them, and `UNKNOWN` until checked.

```text
provenance: ORIG-WLP2, COLLAB-AI, UNKNOWN
prior art:  EXT-PRIOR catalogs, object records, relocations, linkers
```

### Q: Is RPKG:ASM original?

A: Mark `RPKG:ASM` as `ORIG-WLP2` for the goal/name when Walter set it. Mark
the suggested executable-package field layout as `COLLAB-AI` until revised by
Walter. Mark executable packages and catalog-visible payloads as `EXT-PRIOR`.

```text
provenance: ORIG-WLP2, COLLAB-AI
prior art:  EXT-PRIOR executable packages, catalogs
```

### Q: Is ASM's source-width doctrine original?

A: The strict edict for this assembler is `ORIG-WLP2`: `$hh` is zero page,
`$hhhh` is absolute, no quiet promotion/demotion, `<` low byte, `>` high byte,
and `LDA FOO` does not silently become ZP later. Mark WDC low/high-byte
convention and CPU addressing modes as `EXT-PRIOR`. Mark Codex wording and
table organization as `COLLAB-AI`.

```text
provenance: ORIG-WLP2, COLLAB-AI
prior art:  EXT-PRIOR W65C02S addressing, WDC low/high byte convention
```

### Q: Is dropping ASM's use of `A` original?

A: Yes, for this project decision. Mark "ASM was going to use `A`, but no
longer; remove `A` from HIMON after ASM compiles ASM" as `ORIG-WLP2`. Mark
Codex correction/editing of the docs as `COLLAB-AI`.

```text
provenance: ORIG-WLP2, COLLAB-AI
```

### Q: Is ASM zero page growing downward from `$AF` original?

A: Mark the decision as `ORIG-WLP2`. Mark the exact frame proposal and
documentation layout as `COLLAB-AI` until Walter revises it. Mark the current
free-ZP fact as `DERIVED-SRC` because it comes from `himon-shared-eq.inc`.

```text
provenance: ORIG-WLP2, COLLAB-AI
evidence:   DERIVED-SRC himon-shared-eq.inc
```

### Q: Are EQU/DC/DS/ORG/END original?

A: No. They are `EXT-PRIOR`, especially IBM-ish assembler practice. The choice
to use this exact v1 subset in ASM is `ORIG-WLP2`, with `COLLAB-AI` for any
comparisons or doc shaping done in session.

```text
provenance: ORIG-WLP2, COLLAB-AI
prior art:  EXT-PRIOR IBM-ish assembler directives
```

### Q: Is the W65C02S opcode pattern work original?

A: The CPU encoding is `EXT-PRIOR`. The decision to use `aaa bbb cc` only where
it keeps ASM smaller, while leaving irregular opcodes explicit, is a project
design call; tag it `ORIG-WLP2` if Walter owns the edict and `COLLAB-AI` if the
table/wording came through Codex.

```text
provenance: ORIG-WLP2, COLLAB-AI
prior art:  EXT-PRIOR W65C02S opcode encoding
```

### Q: Is SYM3/base-40 original?

A: The need for a huge future HIMON-scale symbol table is `ORIG-WLP2`. The
base-40 `SYM3` proposal is `COLLAB-AI` unless Walter later claims or revises
it. Compact prefix indexes and text packing are `EXT-PRIOR`.

```text
provenance: ORIG-WLP2, COLLAB-AI
prior art:  EXT-PRIOR compact indexes, packed symbol tables
```

### Q: Is "routines of routines" original?

A: Mark the phrase and R-YORS design emphasis as `ORIG-WLP2` if Walter coined
or adopted it. Mark modular programming, libraries, callable contracts, and
reuse as `EXT-PRIOR`. Mark Codex shaping of routine tables or interfaces as
`COLLAB-AI`.

```text
provenance: ORIG-WLP2, COLLAB-AI
prior art:  EXT-PRIOR modular programming, libraries, callable contracts
```

### Q: Are the provenance tags original?

A: The request for truth in the book/story/code is `ORIG-WLP2`. The first tag
set and guide wording are `COLLAB-AI`, accepted only if Walter keeps them.
Provenance and attribution practices are `EXT-PRIOR`.

```text
provenance: ORIG-WLP2, COLLAB-AI
prior art:  EXT-PRIOR provenance and attribution practice
```

## Where To Mark

Do not tag every sentence. Tag the places where a future reader might otherwise
misread ownership or novelty:

```text
book chapter notes
QCC questions that cite outside tradition
DECISIONS entries that settle an original edict
routine headers when a routine embodies a borrowed convention
generated/source-derived maps
external-source transforms under LOCAL provenance
```

## Doc Form

Preferred short form:

```text
provenance: ORIG-WLP2, COLLAB-AI
prior art:  EXT-PRIOR WDC W65C02S opcode encoding
evidence:   BENCH-WLP2 hardware transcript 2026-05-xx
```

For CBI-style entries:

```text
2026
         05
                23
                   21:26Z WLP2 PROV ORIG-WLP2, COLLAB-AI
                               Settled ASM zero-page frame grows down from $AF.
```

## Source Comments

Keep source comments compact:

```asm
; PROV: ORIG-WLP2 design, COLLAB-AI implementation assist
; PRIOR: WDC W65C02S opcode encoding
; EVID:  BENCH-WLP2 hardware proof YYYY-MM-DD
```

Use `PRIOR` for outside material and `EVID` for proof. Keep source lines within
the normal comment width rules.

## Book Voice

The book may say "my" for Walter's bench, vocabulary, constraints, and design
journey. It should say "old idea" or cite prior art for established machinery:
assemblers, linkers, relocation/fixups, FNV, public CPU encodings, Forth-like
wordlists, catalog concepts, and vendor monitor behavior.

The honest sentence shape is:

```text
The old idea is X. My version makes it do Y on this board, with these names and
these constraints. Codex helped shape Z, and the bench proved or rejected it.
```
