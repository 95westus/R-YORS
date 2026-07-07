# ASM Decisions

This file holds detailed settled decisions for ASM. It was split out from [DECISIONS.md](../DECISIONS.md) so the project-wide decision ledger stays readable.

The broader design narrative remains in [HASHED_ASM.md](HASHED_ASM.md), the
flash-resident `$8000` path is planned in
[FLASH_8000_GAME_PLAN.md](FLASH_8000_GAME_PLAN.md), the future
interactive/batch command-surface idea is parked in
[INTERACTIVE_BATCH.md](INTERACTIVE_BATCH.md), and open questions/working notes
remain in [../QCC/ASM.md](../QCC/ASM.md).

## Hashed ASM Direction

Settled v1 overview:

- ASM v1 is a RAM-session W65C02S assembler: native emitted bytes, explicit
  symbol/fixup/reference tables, and no public flash/catalog visibility until a
  later seal/export path.
- ASM proper reads full source lines, suitable for pasted input in the current
  test. Its source-line shape is `[label[:]] operation [operand]`. HIMON's
  old `A [addr] ... .` form was legacy mini-assembler syntax, not an ASM input
  path, and has been removed from HIMON. ASM parsing is hash-first, with
  non-vocabulary first tokens held as pending definition names.
- From this point forward, ASM-native source files use `.a`; WDC source files
  use `.asm`. Older paste samples may keep their legacy names until migrated.
- Width is source intent. `$hh` means zero page, `$hhhh` means absolute, and no
  numeric-range promotion/demotion is allowed.
- `EQU`, `DB`, `DW`, `DS`, `ORG`, and `END` are v1 directives. `EQU` must resolve
  immediately; forward references use emitted-byte fixups only.
- `DC` is parked for now because WDC source format wins. V1 vocabulary keeps
  `DC` reserved so using it as an operation returns `BAD DIR`, not a user
  symbol.
- V1 reports the current session: address range, bytes, counts, unresolved
  fixups, used symbols with line numbers, unused session symbols, and resident
  symbols referenced.
- Current ASM uses one operator-facing session input path for typed and pasted
  source. Pasting is not a separate batch mode today. The future `ASM I`/`ASM B`
  split is only a parked command-surface idea, and it must not change parser,
  fixup, emitter, or `END` behavior if added later.
- ASM is designed to grow to HIMON-scale symbol tables. The RAM session table is
  the workbench; resident/packed symbol tables are the scalable library side.
- ASM works with, uses, and respects the hashing/RJOIN split. Hashing finds
  candidate records; RJOIN or the current HREC join proof validates the intended
  record and returns the exact value, kind, bank, or callable entry. The hash
  itself is never the emitted address.
- ASM uses a working `ASM n.nn` course-catalog map for design and implementation
  passes. The numbers are labels for discussion, not mandatory build stages,
  and the holes are intentional. Nested detail uses `ASM n.nn.m`; for example,
  `ASM 1.10.2` is a stable subsection under `ASM 1.10`, and `ASM 1.30.1`
  names `ASM_BEGIN` under the session-spine course.

```text
ASM 1.00   V1 overview
ASM 1.10   source rules
ASM 1.20   calling contracts
ASM 1.30   session spine
ASM 1.40   lexer/tokenizer
ASM 1.50   vocabulary hash lookup
ASM 1.60   statement parser
ASM 1.70   symbol table basics
ASM 1.80   expression evaluator
ASM 1.90   operand classifier

ASM 2.00   emission overview
ASM 2.10   opcode emitter
ASM 2.20   fixups / patch records
ASM 2.30   DB/DW/DS/ORG/END directive handlers
ASM 2.40   report/listing basics
ASM 2.50   status/error model
ASM 2.60   source input driver / pasted-line handling

ASM 3.00   memory overview
ASM 3.10   RAM workspace map and table layouts
ASM 3.20   zero-page frame layout
ASM 3.30   memory policy validator
ASM 3.40   output target validation

ASM 4.00   test overview
ASM 4.10   test samples / acceptance tests
ASM 4.20   bad-input / error acceptance tests

ASM 5.00   optimization overview
ASM 5.10   optimization pass for W65C02S size
ASM 5.20   routine factoring / code-size style
ASM 5.30   opcode table compression / aaa-bbb-cc helpers
ASM 5.40   full opcode coverage audit

ASM 6.00   future language
ASM 6.10   local labels / scopes
ASM 6.20   resident symbol table / HIMON-scale lookup
ASM 6.30   richer reports / ref/xref
ASM 6.40   flash/catalog seal/export later
ASM 6.50   RPKG/RREC export shape
ASM 6.90   provenance / original-design notes

ASM 8.00   implementation plan for first ASM build
ASM 8.10   implement session spine
ASM 8.20   implement lexer
ASM 8.30   implement vocabulary lookup
ASM 8.40   implement symbol table
ASM 8.50   implement expression evaluator
ASM 8.60   implement operand classifier
ASM 8.70   implement emitter
ASM 8.80   implement fixups
ASM 8.90   implement directives

ASM 9.00   integration
ASM 9.10   integrate report
ASM 9.20   integrate status/error handling
ASM 9.30   integrate input driver
ASM 9.40   assemble ASMTEST_3000
ASM 9.50   assemble larger proof
ASM 9.90   ASM assembles ASM milestone
ASM 9.99   legacy A removed from HIMON
```

- Future operator diagnostics use `ASM-xxxx`, not the course numbers. That
  keeps later S/36-style message IDs and WTOR/reply policy separate from design
  chapters. V1 still stops on the first error.

- Removed legacy HIMON mini-assembler command, outside ASM:

```text
A [addr] [label[:]] MMM [operand] .
```

- In the removed legacy `A` command, address came before optional label. Do not
  route ASM through `A`; ASM proper uses source lines and `ORG`/session PC state
  rather than a leading `A`.
- ASM hashes canonical names and tokens, not raw numeric addresses, for
  resolution. Store exact addresses, banks, patch sites, and origins as fields.
  Address-containing record hashes are proof/check metadata only, not emitted
  operand values.
- ASM source spelling controls operand address width. `$00` through `$FF` is a
  zero-page operand. `$0000` through `$FFFF` is an absolute operand. These may
  name the same numeric CPU address, but they assemble to different instruction
  forms.
- ASM must not silently promote zero-page operands to absolute by prepending
  `$00`, and must not silently demote absolute operands to zero page by omitting
  the high byte. Numeric value range alone is not an addressing-mode decision.
- `EQU` symbols carry the address width implied by the defining source spelling.
  `FOO EQU $12` defines a zero-page symbol. `FOO EQU $0012` or
  `FOO EQU $1234` defines an absolute symbol. Later uses of `FOO` use that
  recorded width; no promotion or demotion is allowed.
- Decimal `EQU` definitions such as `COUNT EQU 10` create concrete value
  symbols without memory-address width. `LDA #COUNT` is valid if the value fits
  the immediate field; `LDA COUNT` is `BAD WIDTH` unless `COUNT` was defined
  with zero-page/absolute width or selected with `<`/`>`.
- `<` selects the low byte and `>` selects the high byte, following conventional
  WDC-style low/high byte behavior. V1 applies them as prefix selectors on one
  atom. These are byte selectors, not silent addressing-mode conversion rules.
- Global, session, imported, exported, and local symbol policy is separate from
  address-width policy. Future scope rules must not introduce silent
  zero-page/absolute promotion or demotion.
- Labels may use an optional trailing `:` for readability, but the hash-first
  parser does not require it. After session-PC handling, the parser strips an
  optional trailing colon for the vocabulary check, then hashes the first source
  token against the ASM vocabulary table. If it is a mnemonic or directive, it
  is the operation. If it is not, it is a pending definition name and the next
  token must be a mnemonic or directive.
  Binding waits until the operation is known: mnemonic/`DB`/`DW`/`DS` bind the
  name to the current PC, while `EQU` binds the name to the expression value. A
  leading definition name before `ORG` or `END` is an error in v1. If the
  statement ends after one pending definition name, it is a label-only line:
  bind the name to the current PC and emit nothing. Bare `EQU` without a
  pending definition name is `BAD SYM`.
- Leading spaces are not required and have no label meaning in v1. Legal source
  shapes include `LABEL CMD OP`, `LABEL: CMD OP`, `LABEL`, and `LABEL:`. Column
  position is not part of symbol recognition.
- One source line is one statement. ASM v1 has no multiple statements per line
  and no trailing `.` terminator. Blank/comment lines are OK. `CMD [operand]`,
  `LABEL CMD [operand]`, and `LABEL: CMD [operand]` are the normal operation
  forms.
- `ORG` and `END` are session/control statements, not label-binding statements.
  `LABEL ORG $2000` and `LABEL END` are `BAD SYM`. Bare `ORG` is `BAD OPER`;
  `END anything` is `BAD OPER`; trailing non-comment junk after a complete
  statement is `BAD OPER`.
- Labels cannot be opcode mnemonic or directive keyword names. Mnemonics and
  directives reserve their canonical token text, so hash-first parsing can
  check "is this token assembler vocabulary?" before treating it as a label.
  `LABEL:` remains the explicit visual form, while `LABEL` is legal when the
  next token is the operation. This keeps `JSR JSR` unambiguously "mnemonic plus
  operand."
- `A`, `X`, and `Y` are reserved v1 register words, not legal user symbols.
- V1 symbols are define-once. Any second definition of the same canonical symbol
  is `BAD SYM`, whether it is a PC label, colon label, or `EQU`. Later
  `SET`/`REDEF` machinery can be explicit if the assembler needs mutable names.
- Dot and question mark are local-label prefixes. They are prefix-only, not
  free-floating global symbol characters. In v1, `.NAME`, `.NAME:`, `?NAME`,
  and `?NAME:` bind/reference local PC labels inside the most recent nonlocal
  label scope. `.` alone is a legacy `A`/input-driver sentinel if used, not ASM
  source syntax. No v1 dot-directive aliases.
- Minimal v1 ASM directives follow WDC shape: `EQU`, `DB`, `DW`, `DS`, `ORG`,
  `END`, `EXPORT`, and `IMPORT`. `DC` and `START` remain parked later
  directives. The module-boundary spelling is `EXPORT NAME` for a public
  global label offset and `IMPORT NAME` for an intended external/imported
  symbol; `ENTRY`/`EXTRN` are not the planned spellings.
- V1 directive shapes are:
  `NAME EQU expr` with name required;
  `[NAME] DB item[,item...]` with optional current-PC label;
  `[NAME] DW expr[,expr...]` with optional current-PC label;
  `[NAME] DS count[,init...]` with optional current-PC label;
  `ORG expr` with no leading name;
  `END` with no leading name and no operand;
  `EXPORT NAME` with no leading name and exactly one defined global label name;
  `IMPORT NAME` with no leading name and exactly one global intended external
  name.
  `EXPORT` rejects unknown names, local names, `EQU` symbols, duplicates, and
  table overflow as `BAD SYM`; extra operands are `BAD OPER`.
  `IMPORT` records compact PACK40 metadata and tags matching unresolved global
  operands as imports. It rejects local names, reserved words, duplicates,
  table overflow, and leading labels as `BAD SYM`; extra operands are `BAD
  OPER`. At `END`, eligible import fixups become import relocation rows instead
  of failing as unresolved `BAD FIX`: `$04` ABS16_IMPORT for full two-byte
  operands, `$05` LO8_IMPORT for `#<NAME`, and `$06` HI8_IMPORT for `#>NAME`.
  After the session/local symbol tables miss, declared imports are checked
  before resident RJOIN. This makes explicit `IMPORT NAME` a force-deferred
  spelling even when `NAME` is resident today; plain undeclared `JSR`/`JMP`
  operands still RJOIN and bind to today's resident address.
- The next ASM incarnation must make data directives first-class fixup and
  relocation clients. `DW TARGET` should accept known and forward PC labels,
  emit or later patch a little-endian word, and record an `$01`
  `ABS16_INTERNAL` relocation row when the target is a session label.
  `DB <TARGET` and `DB >TARGET` should do the same for `$02` `LO8_INTERNAL`
  and `$03` `HI8_INTERNAL`. The dry-run/count pass must not reject forward
  labels that have an unambiguous selected width. Later import-capable `LINK`
  can extend the same path to `$04-$06` import rows.
- Parked vocabulary must not permanently steal common user labels. In the next
  ASM incarnation, either implement an actual `START` directive in the same
  slice or release `START`/`START:` as an ordinary user label. Leaving `START`
  reserved while it is not usable as syntax is too sharp for board-facing
  source.
- ASM reads one full source line in v1, capped at 63 visible characters. Spaces
  and tabs are whitespace; tabs have no column meaning. Empty and comment-only
  lines are OK. An overlong line is `BAD LINE`.
- ASM canonicalizes source tokens outside quotes to uppercase before hashing and
  masks bit 7 on input bytes before hash update, matching HIMON's current
  high-bit string/FNV habit. Text inside quotes preserves exact character case.
- ASM v1 token classes are `WORD`, `NUMBER`, `CHAR`, later `STRING`, `PUNCT`,
  `COMMENT`, and `EOL`.
- ASM 1.40 is a streaming lexer/tokenizer. It prepares one line, returns one
  current token record at a time, and does not decide labels, mnemonics,
  address modes, or expression values beyond a character literal byte.
- The statement head can use a lighter word scan than the operand tail: scan
  first word, maybe scan second word, then hand the remaining operand/directive
  tail to the real tokenizer when needed.
- ASM 1.40 exposes `ASM_LEX_LINE` and `ASM_NEXT_TOKEN`. `ASM_LEX_LINE` prepares
  the source line and checks the 63-visible-character limit. `ASM_NEXT_TOKEN`
  skips whitespace and returns `EOL`, `WORD`, `NUMBER`, `CHAR`, or `PUNCT` in
  the current token record.
- The current token record carries kind, subkind, flags, source pointer, token
  length, delimiter, optional FNV32 hash for `WORD`, optional character byte for
  `CHAR`, and status. Useful flags include `HAS_COLON`, `HAS_XMASK`, `QUOTED`,
  `LOCAL_PREFIX`, and `ERROR`.
- `COMMENT` is recognized but not normally returned. A `;` outside quotes makes
  the next token `EOL`.
- V1 punctuation tokens are `#`, `,`, `(`, `)`, `<`, `>`, `+`, `-`, `*`, `|`,
  `&`, `^`, `:`, and `.`. A dot alone is not ASM source syntax; it is a
  legacy `A`/input-driver sentinel if used. Dot-prefixed names are returned as
  `WORD` with `LOCAL_PREFIX` so v1 can route them to the local table.
- ASM 1.50 vocabulary lookup answers whether a canonical word is assembler
  vocabulary and what kind it is. Result kinds are `VOC_NONE`, `VOC_MNEM`,
  `VOC_DIR`, `VOC_REG`, `VOC_RESERVED`, and later `VOC_ALIAS`.
- `ASM_LOOKUP_WORD` takes the current `WORD` token/head-word hash and returns
  `C=1,A=OK,X=slot,Y=VOC_KIND` when found or `C=0,A=OK,X=$FF,Y=VOC_NONE` when
  not found. Not-found is not an error by itself; the parser decides whether
  the position required vocabulary.
- Statement-head policy: first word `VOC_MNEM`/`VOC_DIR` is the operation;
  first word `VOC_NONE` is a pending definition name; first word `VOC_REG` or
  `VOC_RESERVED` is `BAD SYM` if used as a definition name. After a pending
  name, the second word must be `VOC_MNEM` or `VOC_DIR`; otherwise it is
  `BAD MNEM`. A parked directive used as an operation is `BAD DIR`.
- ASM 1.50 vocabulary rows carry canonical text for build/listing/proof, FNV32
  hash, kind, id, flags, dispatch/family id, and aux data such as mode mask or
  opcode family. A W65C02S implementation may store these as parallel arrays.
- Fixed vocabulary hash is an accelerator, not truth. The vocabulary build must
  verify no duplicate canonical text and no duplicate active FNV32 unless
  runtime text compare is present. Do not silently accept the first matching
  hash if a collision exists.
- ASM 1.60 statement parsing turns the prepared line head into a statement
  record and dispatch decision. It owns blank/comment line acceptance,
  operation-only versus pending definition name, label-only detection, and
  top-level directive shape checks.
- ASM 1.60 statement records carry kind, flags, pending-name pointer/length/hash,
  operation vocabulary slot/kind/id, operand/directive tail pointer, and status.
  Kinds are `EMPTY`, `LABEL_ONLY`, `MNEM`, `DIR`, and `ERROR`.
- `ASM_PARSE_HEAD` fills the statement record from the prepared line. It uses a
  light head-word scan plus `ASM_LOOKUP_WORD`. It returns `BAD SYM`, `BAD MNEM`,
  `BAD DIR`, or `BAD OPER` for top-level statement errors.
- `ASM_DISPATCH_STATEMENT` applies the top-level policy: label-only binds the
  pending name to current PC; mnemonic/DB/DW/DS with a name bind current PC
  before emission/data handling; `EQU` requires a name and binds expression
  value; `ORG` and `END` reject leading names; clean `END` calls `ASM_END`.
- ASM 1.60 may check whether an operand/directive tail exists or is absent, but
  detailed tail validity belongs to directive handlers, expression parsing, and
  operand classification.
- ASM 1.70 owns the RAM-session symbol table contract. The v1 table is the
  mutable workbench for current-session definitions; resident HIMON/catalog
  symbols are a later read-only lookup layer.
- ASM 1.70 session symbol rows carry state, flags, kind, width, value, care
  mask, FNV32 hash, canonical name length/text pointer, defining line, use
  count, and first reference line. Rows are logical; W65C02S code may store them
  as parallel arrays by slot.
- Do not store `SYM3` in v1 RAM symbol/fixup/reference rows. Compute `SYM3`
  later when resident-scale lookup needs the first-three-character filter.
  Future ASM/HIMON-scale assembly may need temporary storage, flash workspace,
  compression, or both; that belongs to later workspace/resident-symbol design,
  not the first RAM-session symbol row.
- ASM 1.70 symbol kinds are `VALUE`, `ADDR`, and `MASK`. Widths include
  `NONE`, `BYTE`, `WORD`, `ZP`, `ABS`, `MASK8`, and `MASK16`. PC labels bind as
  `ADDR/ABS`; use `EQU $12` for a zero-page variable name. Do not infer ZP from
  a label value below `$0100`.
- `ASM_LOOKUP_SYMBOL` searches allowed layers and returns found/not-found, with
  not-found carrying `C=0,A=OK` rather than an error. The caller decides whether
  not-found becomes `BAD SYM`, an allowed forward fixup, or an unresolved `EQU`
  error.
- `ASM_BIND_LABEL` defines the pending statement name as current PC, stores
  `ADDR/ABS`, rejects duplicates, copies canonical name text, and then tries
  fixups. `ASM_DEFINE_EQU` defines the pending name from a resolved expression
  result and rejects unresolved expressions in v1.
- Duplicate symbol policy is define-once. A second definition is `BAD SYM`, even
  if the value is the same. Label/EQU collisions are also `BAD SYM`.
- Hash collision policy is hash-first, text-proved. Compare hash first, then
  canonical length/text. V1 RAM session symbols store text so `SYM`, reports,
  and fixups can tell the truth.
- ASM 1.80 owns the v1 expression evaluator. Source expressions are readable
  infix; internal RPN is allowed only as an implementation form when it saves
  W65C02S code.
- Current `ASM_PARSE_EXPR` parses one expression from X/Y through
  NUL/CR/LF/comment and returns a resolved result with kind, width, value, and
  care mask. It resolves known RAM-session symbols and rejects unknown symbols
  as `BAD SYM`. Unresolved expression results, caller terminator flags, and
  fixup addends are later work.
- ASM 1.80 current grammar is `term {op term}*`, where a term is decimal, hex,
  binary/mask, character literal, known symbol, or `*`. Current executable
  operators are `+` and `-`; `<`/`>` selectors and `|`, `&`, `^` remain v1
  design targets until the operand/DB expression boundary is unified.
- ASM 1.80 preserves the standout rule: expressions evaluate strictly
  left-to-right, with no operator precedence and no grouping parentheses.
- `+` and `-` require known concrete values/addresses, not masks. Arithmetic
  keeps the left operand's address-width intent and range-checks the result; it
  does not promote or demote.
- Future `|`, `&`, and `^` require known same-width values or masks. Mask
  results carry value/care/width and may normalize to `VALUE` only when the care
  mask becomes all ones.
- V1 unresolved expression results are limited to `SYMBOL`, `<SYMBOL`, and
  `>SYMBOL`. Compound unresolved expressions such as `FOO+1`, `>FOO+1`, and
  forward `NEXT EQU BASE+1` are not v1 until addend fixups or an `EQU`
  dependency solver exist.
- ASM 1.90 owns mnemonic operand classification. `ASM_CLASS_OPERAND` takes the
  mnemonic row/id and operand tail pointer, consumes the whole operand tail, and
  returns an operand result with state, mode, flags, width, value/care, resolved
  symbol slot, aux byte, planned fixup count, and status.
- ASM 1.90 result modes include `NONE`, `ACC`, `IMM8`, `IMM_LO8`, `IMM_HI8`,
  `ZP8`, `ABS16`, `REL8`, `ZPX`, `ZPY`, `ABSX`, `ABSY`, `ZP_IND_X`,
  `ZP_IND_Y`, `ZP_IND`, `ABS_IND`, `ABS_IND_X`, `BIT_ZP`, and `BIT_ZP_REL`.
- ASM 1.90 is mnemonic-aware where syntax alone is insufficient: branches force
  `REL8`, `JSR` forces `ABS16`, `RMB`/`SMB` use `BIT_ZP`, `BBR`/`BBS` use
  `BIT_ZP_REL`, accumulator-capable operations accept blank or `A`, and
  ordinary unresolved memory operands default to `ABS16` only where the mnemonic
  permits that path.
- ASM 1.90 treats `<` and `>` differently from `#`: `LDA <FOO` reads memory at
  zero-page address `low(FOO)`, while `LDA #<FOO` loads the literal low byte.
  `LDA >FOO` similarly selects the high byte as a zero-page address operand.
- ASM 1.90 plans fixups only when emitted width is already known:
  immediate/selected byte/zp/rel fields are one-byte fixups; absolute fields are
  two-byte fixups; `BIT_ZP_REL` may plan two fixups. Bit numbers must resolve
  now and be `0..7`.
- ASM v1 symbol text is capped at 31 visible characters, matching the current
  ASM/RJOIN proof's `$20`-byte stored fixup-name slot including terminator.
  HIMON command input can carry longer text, but v1 ASM symbols should fail
  clearly above this cap.
- ASM v1 symbol characters are uppercase letters, digits, underscore, and dot
  or question mark for local labels, but a global symbol must not begin with a
  digit. Dot and question mark are local-prefix characters and are prefix-only.
  A trailing colon is optional label punctuation, not part of the symbol. Comma
  is operand punctuation/separator, not a symbol character.
- ASM v1 comments start with `;` and run to end of line.
- ASM v1 numeric/data literals include decimal with no prefix, hex `$`, binary
  `%`, and character literals.
  Decimal literals are concrete numbers; they do not by themselves select
  zero-page or absolute memory addressing.
- Hex width is source-significant. `$0` through `$FF` with one or two hex
  digits is a byte/zero-page-sized literal. `$0000` through `$FFFF` with four
  hex digits is a word/absolute-sized literal. Three hex digits are `BAD WIDTH`
  in v1.
- Decimal memory operands such as `LDA 12` are `BAD WIDTH` in v1 because decimal
  spelling does not select zero page or absolute. Decimal remains valid where
  the context supplies width, such as `#10`, bit numbers, counts, and data
  initializers.
- In byte-data context, decimal emits the byte if it fits. `DB 10` is `DB $0A`.
  Decimal `DB` values outside `$00-$FF` are `BAD RANGE` unless a later word-data
  form is added.
- ASM v1 character literals preserve exact character value inside quotes:
  `'A'` emits uppercase `A`, `'a'` emits lowercase `a`, and `'''` emits a
  single quote character. No C-style escapes in v1.
- ASM source expressions use readable infix syntax. RPN is the preferred compact
  backend/evaluator form, but it is not source syntax. Simple examples:
  `COUNT EQU 10`, `BASE EQU $7000`, `NEXT EQU BASE + 1`, and
  `SIZE EQU END_ADDR - START_ADDR` after both labels are known.
- `*` is the current assembly PC/location counter when used as an expression
  term. `ADDR EQU * - 32` is not a forward `EQU`; it resolves immediately from
  the current PC and a known value. Because `*` is an address, `ADDR - VALUE`
  keeps address width if it remains in range. `ADDR - ADDR` produces a scalar
  `VALUE` delta.
- Current executable ASM v1 expression operators are `+` and `-`. The `|`,
  `&`, and `^` logical/mask operators are deferred for later implementation,
  not the next ASM slice. When reopened, evaluate them strictly left-to-right
  with no operator precedence; `A | B & C` will mean `(A | B) & C`. Use a
  separate `EQU` if a staged result is needed.
- When the deferred logical/mask slice is reopened, implement `|` OR, `&` AND,
  and `^` EOR in `ASM_PARSE_EXPR`, not as special cases in directive emitters.
  That will make them available first to the current expression callers: `EQU`,
  `ORG`, and `DW`. `DB`/`DS` list expression math remains separate because
  those directives still use their byte/list atom parser, not the general
  expression-list path. In short: keep `|`, `&`, and `^` as an
  `ASM_PARSE_EXPR` upgrade when they return, with `DB` expression-list
  unification as a later, cleaner refactor.
- Unary minus is not v1 syntax. Use `0-1` if needed, then let the target context
  range-check the result. `DB -1` is `BAD OPER`.
- Parentheses are not expression grouping in v1. `(` and `)` remain operand
  addressing punctuation, such as `LDA ($12),Y`; expression grouping
  parentheses are `BAD OPER`.
- Binary `%` literals require 8 or 16 digits. After `%`, the lexer is in
  binary/mask mode and accepts only `0`, `1`, `X`, and `x` until the token
  delimiter. `X`/`x` is treated as an unknown/don't-care bit for mask
  construction. Outside a `%` token, `X` and `Y` are register/index tokens only
  where operand syntax expects them.
- `EQU` may define a concrete value symbol or a mask-type symbol. A mask symbol
  carries value, care mask, and width. `%XXXXXXX1` records value `$01`, care
  mask `$01`, width 8. `%XXXXXX1X` records value `$02`, care mask `$02`, width
  8. Concrete values carry an all-ones care mask.
- Future v1 mask/logical expressions `|`, `&`, and `^` require known same-width
  operands. Result kind is `MASK` if either input is `MASK`. Care-mask rules:
  OR is known if both inputs are known or either input is known 1; AND is known
  if both inputs are known or either input is known 0; XOR is known only if both
  inputs are known. If the result care mask is all ones, the result may
  normalize to `VALUE`. Mask values with don't-care bits are for `EQU` mask
  constants and `|`, `&`, `^` composition, not concrete emitted bytes,
  addresses, counts, or immediates. `+` and `-` are for concrete
  values/addresses only in v1.
- `EQU` expressions must resolve when the `EQU` line is assembled in v1. Do not
  create forward `EQU` dependency chains yet. Forward fixups are for emitted
  operands/data bytes, not for unresolved symbol equations. Hashes can identify
  the names in a forward `EQU`, but they do not evaluate the equation, wake
  dependent symbols, detect dependency cycles, or decide final width/kind.
- `*` carries current-PC absolute/word width. `DB *` emits the current PC as a
  little-endian word; use `DB <*` or `DB >*` for one-byte low/high PC data.
- `ORG` sets the assembly PC/location counter. It may move forward or stay at
  the current PC. It emits no bytes and does not fill the gap. It must not move
  backward in v1 or later; use explicit data emission or a monitor memory edit
  for intentional patches.
- `DS count, init-list` is legal and emits/fills initialized storage by
  repeating/truncating the initializer list to `count` bytes. `DS count` must
  be a concrete, resolved value in v1 because it advances the assembly PC.
  Initializer elements are byte-sized in v1. If the final repeat stops partway
  through the initializer list, ASM sets `WARN_DS_WRAP`; this is not
  `BAD_RANGE`, and the line still succeeds. Reports print this as
  `WARN WARN_DS_WRAP`.
- `DB` v1 emits simple byte/word/address data: `DB $FF`, `DB 10` as byte
  `$0A`, `DB $1234`, `DB 'A'`, `DB <ADDR`, `DB >ADDR`, and `DB ADDR` when
  `ADDR` has known width. Unknown bare `DB ADDR` is `BAD WIDTH`; use
  `DB <ADDR,>ADDR` for a v1 address-word workaround with byte fixups.
  Typed data forms such as `X'...'`, `B'...'`, `HBSTR'...'`, `CSTR'...'`, and
  `PSTR'...'` are parked later.
- `DW expr[,expr...]` emits each resolved expression as one little-endian
  16-bit word. `DW $1234,$12,10+1,'A'` emits `34 12 12 00 0B 00 41 00`.
  Empty `DW`, leading/trailing commas, masks, and unresolved expressions fail
  clearly.
- Unknown ordinary symbol operands default to absolute fixups when the mnemonic
  does not force another mode. For example, `LDA FOO` emits the absolute form
  and creates an `abs16` fixup if `FOO` is unresolved.
- Unresolved fixup placeholder operand bytes should be emitted as `$FF`, not
  `$00`, so flash targets can later program 1-to-0 bits when the fixup resolves.
- `END` fails if required fixups remain unresolved.
- First implementation storage plan: emitted bytes live at the selected target
  RAM address/chosen assembly address; the symbol table lives in a RAM session
  table; the fixup table lives in a RAM session table. `END` attempts final
  fixup resolution and fails if required fixups remain. Flash/catalog visibility
  comes later and only after an explicit seal/export step.
- ASM v1 RAM session state tracks current PC, start/origin PC, high-water PC,
  line count, symbol count/limit, fixup count/limit, reference count/limit,
  report flags, and session status. Emitted code, symbol table, fixup table,
  reference/report table, line buffer, and parser scratch must be separate
  non-overlapping ranges; overlap is an assembly-context/range error.
- ASM active zero-page scratch uses HIMON's currently free user ZP window and
  grows downward from `$AF`. The shared FNV32 contract owns `$B0-$B3` for hash
  state and `$C7-$CA` for the multiply term. Persistent ASM state stays in RAM
  tables. Other HIMON shared ZP may be borrowed only as volatile scratch under
  the called routine's contract; ASM must not depend on shared bytes surviving
  SYS/BIO/COR/PIN/flash/FNV/HIMON helper calls.
- Hash stays on the fast shared-state path. Pointer-based FNV helpers may be
  added later for generic or nested hash work, but they should not replace the
  hot `FNV1A_INIT` / `FNV1A_UPDATE_A_FAST` shared-ZP contract used by HIMON and
  ASM.
- All ASM callable routine interfaces follow HIMON/THE routine style. ASM does
  not invent a private ABI. Each routine card must document inputs, outputs,
  carry/status meaning, preserves, clobbers, ASM zero-page frame bytes used, RAM
  tables touched, stack behavior, calls, and error returns.
- Default HIMON-style status is `C=1` for success/true/found/accepted/completed
  and `C=0` for failure/false/not found/invalid/timeout/rejected. `A` carries a
  natural byte/status/result when the routine owns `A`; `X/Y` carry natural
  pointer or word results low/high when the routine owns `X/Y`.
- ASM 1.30 starts with three public spine routines: `ASM_BEGIN`,
  `ASM_ASSEMBLE_LINE`, and `ASM_END`. They all return `C=1` for
  accepted/completed or `C=0` for failed/rejected, `A` as the ASM status code,
  and `X/Y` as the current ASM PC low/high.
- `ASM 1.30.1 ASM_BEGIN` opens or resets one RAM session. `A` bit 0 means
  `X/Y` carries an explicit start PC; clear bit 0 means use the configured
  default scratch origin. It clears ASM session tables and state but does not
  erase the target code range.
- `ASM 1.30.2 ASM_ASSEMBLE_LINE` takes `X/Y` as a NUL/CR/LF-terminated source
  line pointer, increments the physical session line count, accepts
  blank/comment lines, prepares the line, parses the head into the current
  statement record, dispatches that record, and copies any symbol/fixup text
  needed before return. If the line is `END`, it calls `ASM_END`.
- `ASM 1.30.3 ASM_END` resolves final fixups, prints the compact v1 report, and
  marks the session ended or failed. It is idempotent after a clean end: a
  second direct call returns `OK` without printing a second report. Required
  unresolved fixups still fail with `BAD FIX`.
- A new RAM ASM session starts at a configured scratch code origin unless the
  user supplies an address. Session start and `ORG expr` both set the same
  assembly PC after range validation. `*` reads that current PC.
- The active ASM core RAM proof loads at `$2000`. Its standalone smoke target is
  `$7000` and its data targets are `$7100/$7110`, keeping emitted proof bytes out
  of the resident proof image while ASM remains RAM-hosted.
- ASM v1 RAM symbol rows carry canonical name text/length for user symbols,
  FNV32 hash, value, kind, width, flags, and optional scope/session id. Hash is
  the lookup accelerator; text proves collision identity and supports `SYM`.
- ASM v1 RAM fixup rows carry canonical target text/length, target FNV32 hash,
  patch site, operand mode/width, origin or branch-base address when needed,
  placeholder byte count, and state. Fixup tables use explicit state; never
  infer pending/resolved from `$FF` placeholder bytes.
- ASM v1 RAM relocation rows are separate from fixups. Fixups record unresolved
  assembly-time references; relocation rows record resolved references that
  depend on the sealed module's future base or a later import provider. The
  RAM table records internal label rows as `$01` ABS16_INTERNAL, `$02`
  LO8_INTERNAL, and `$03` HI8_INTERNAL, with site and target stored as offsets
  from the seal base. `$04` ABS16_IMPORT, `$05` LO8_IMPORT, and `$06`
  HI8_IMPORT record imported values: site is still a seal-base offset, while
  target low carries the import slot index and target high is zero.
- The default flash image omits interactive `RESOLVE` in the first
  `LOAD`/`INSTALL` slice. Import metadata remains packageable, but runnable
  `LOAD` rejects imports with `BAD FIX`.
- `SEAL> RELOCATE address` is the first RAM-overlay move proof. It is
  available only after clean `END`, copies the frozen body to the requested RAM
  base, applies `$01/$02/$03` internal relocation rows against that base, and
  leaves `$04/$05/$06` import rows for a later installer.
- `SEAL> PACKAGE address` is the first stable sealed-object envelope proof. It
  is enabled in full core smoke and flash-resident ASM, while the stripped RAM
  paste wrapper omits it to preserve board workspace. The AP v1 envelope stores
  a header plus tagged SEAL, REL, EXP, IMP, and BODY sections; it packages
  metadata for later `LOAD`/`INSTALL` work, then self-verifies the written BODY
  FNV against the seal record. It does not resolve, relocate, or run the body.
- `SEAL> CHECK address` is the first AP v1 package reader proof. It remains
  enabled in full-core smoke and optional diagnostic builds, but the default
  flash-resident ASM image omits the interactive `CHECK` command after the
  board proof because the `$8000-$BFFF` flash window was only `$24` bytes below
  `$C000`. This slice checks header, range, section order, section length
  accounting, relocation count shape, EXP/IMP record length fields, and body
  length versus the seal record.
- AP package addresses and execution addresses are separate. An AP envelope can
  be copied from RAM to flash, from one flash hole to another, or back to RAM
  as opaque bytes without relocation. Relocation is required only when the BODY
  bytes are loaded or installed to execute at a base different from the sealed
  base.
- `SEAL> LOAD pkg dest` is the first runnable AP path. It performs a minimal AP
  parse, copies BODY to a destination that fits wholly in `$2000-$4FFF`, applies
  internal `$01-$03` relocation rows, and rejects declared imports/import
  relocation rows with `BAD FIX`. Full AP validation, BODY FNV verification,
  import resolution, RJOIN publication, and banked execution are deferred. For
  RAM package sources in this slice, the destination BODY must end before the AP
  envelope begins; this conservative rule avoids self-overwriting copies while
  keeping the resident loader small.
- HIMON `AP pkg dest` is the first resident run command for installed AP
  packages. It calls the same resident AP `LOAD` service and then runs `dest`
  through the existing monitor return-report path. To keep ROM growth small,
  v0 requires the package entry to be BODY offset zero and does not create
  per-package command-name records yet.
- `SEAL> INSTALL pkg` finds the first erased contiguous visible flash hole in
  `$8000-$FEFF` large enough for the unchanged AP envelope and prints the
  suggestion. `SEAL> INSTALL pkg flash_addr` is the first low-flash write
  slice: it copies the AP envelope unchanged through HIMON's flash-install
  service. Banked banks 0-2 install/runability remains deferred.
- The movable package lifecycle is named `SPILL`: `SEAL` freezes/checks facts,
  `PACK` emits the AP envelope, `INSTALL` stores the AP envelope, `LOAD` reads
  AP and relocates BODY into RAM, and future `LINK` binds imports in that loaded
  overlay/temp-RAM image. Current command spelling for the `PACK` step remains
  `PACKAGE`; the default flash image implements `SPIL` and defers `LINK`.
- The HREC/RJOIN `K` byte is kind metadata, not install lifecycle state. Current
  resident records define `K` in source with bits for executable, confirmation,
  and text/metadata. Future AP package/catalog kind should come from explicit
  package metadata, with the spelling still unsettled. Until that exists,
  installed AP packages should default to opaque non-executable objects.
- ASM v1 RAM reference rows carry line number, referenced symbol hash/text, use
  mode, emitted site/current PC, resolution result, and local symbol slot when
  applicable. They drive the basic session report and xref view.
- Default flash ASM keeps table printing out of the resident command surface.
  `asm-session-report-7000.s19` is the host-built external table reporter, and
  `asm-session-report-4800.a` is the flash ASM-native source snapshot for
  preloading before the session being inspected. `asm-session-report-7000.a`
  is retained for non-flash/runtime-paste ASM builds that still allow `$7000`
  output.
- RAM "rows" are conceptual records. A W65C02 implementation may store fields
  as parallel arrays indexed by slot, matching the current proof style, when
  that saves code or cycles.
- First implementation uses fixed table limits. If symbol or fixup space fills,
  fail with `BAD SYM` or `BAD FIX`; do not spill silently or start writing into
  flash. The current proof sizes are 40 global symbols, 96 fixups, 16 internal
  relocation rows, 160 report references, 31 visible global-name characters, 16
  local labels per active global scope, 15 visible local-name characters, 63
  input characters, and a 512-byte code buffer; treat those as proof defaults,
  not permanent language limits.
- ASM lookup is layered so it can grow to HIMON-scale symbol counts. V1 checks
  RAM session symbols first, then resident HIMON/catalog symbols, then creates a
  fixup if the operand mode allows a forward reference. The RAM session table is
  only the current workbench; a large resident/packed symbol table is a design
  goal, and assembling ASM/HIMON under ASM is a future acceptance test.
- Future ASM may expose that lookup order as an explicit policy, either through
  a HIMON command or an ASM directive. The default should remain local-first:
  current session symbols, resident executable/catalog records, then forward
  fixup. A later directive could name the search path in plain order, for
  example `RESOLVE LOCAL,RCAT,RREC,FIXUP` or `SEARCH LOCAL,ROM,FIXUP`.
  First implementation should be session-wide; block-scoped or per-reference
  overrides are parked until there is real source pressure for them.
- Large resident symbol tables may use a compact two-byte `SYM3` prefix key
  before full FNV/name comparison. `SYM3` packs the first three canonical
  characters using a base-40 alphabet: pad/end, `A-Z`, `0-9`, `_`, and two
  local-prefix reserve codes. `40^3 = 64000`, so the key fits in 16 bits.
  Code 38 is reserved for future `?`; code 39 is reserved for future `.`. Base-64
  would need 18 bits for three characters, so it is not better for this specific
  3-in-2 key. `SYM3` is only a filter/index key; FNV32 plus canonical text
  remains the identity proof.
- Text compression for names is optional. `pack_lo_5`, base-40 prefix keys,
  PackBits/RLE for streams where it actually wins, or later dictionaries are
  allowed only when they save space and remain W65C02-small. Store raw
  canonical text when compression is not smaller or would make lookup/reporting
  harder.
- ASM v1 must produce a basic session report. The report includes assembly
  start/current/high-water PCs, emitted/reserved byte counts,
  symbol/fixup/reference counts and limits, `STATUS`, `ERRLINE`, `TRUNC`, any
  unresolved fixups, used symbols with session line numbers, unused symbols
  defined in the current session, and resident symbols referenced. Rich
  whole-image reports, memory policy reports, and full ref/xref exports are
  later tools.
- V1 report timing is split by build. The core/smoke compact-report build can
  print the compact report at `END` or first failure. `ASM_RUNTIME_ONLY`
  omits that printer and its strings; runtime paste/flash wrappers use compact
  error lines and post-END `SEAL` facts as the operator-visible report path.
  The external `asm-session-report-7000` proof carries detailed table output.
- ASM report line numbers are physical source/session input lines counted from
  the start of the assembly session, including blank/comment lines. References
  are only recorded for lines that define or use a symbol.
- Do not add `BAD TABLE` in v1. Table-full behavior maps to existing codes:
  symbol table or name pool full is `BAD SYM`; fixup table full is `BAD FIX`;
  reference table full is `BAD FIX` with `TRUNC=YES`; line too long is
  `BAD LINE`; code target overflow is `BAD RANGE`.
- `BAD FIX` at `END` can also mean "required fixup still unresolved", not only
  "fixup table full." The 2026-06-10 biorhythm attempt showed this clearly:
  the table held 19/24 rows, but `JMP BIO_FTDI_WRITE_BYTE_BLOCK` and
  `JMP BIO_FTDI_PUT_CSTR` remained pending because that image only tried
  resident lookup for direct `JSR name`. Current ASM allows direct resident
  `JSR name` and `JMP name`; session-defined names still win first.
- Future ASM must validate memory/access policy for the assembly context: HIMON
  builds may use system-owned zero page, I/O, and protected ranges; user
  assembly must be rejected or warned when it targets ranges outside its allowed
  memory policy.
- Bit-manipulation opcodes use the three-letter base mnemonic plus an explicit
  bit operand: `RMB 3,$12`, `SMB 7,$12`, `BBR 3,$12,TARGET`, and
  `BBS 7,$12,TARGET`. Do not create `RMB3`/`BBS7` as first-class mnemonic
  tokens in v1.
- ASM opcode selection uses a mnemonic row table keyed by canonical FNV-1a hash,
  plus an operand classifier. Rows may generate opcodes from W65C02S
  `aaa bbb cc` bit-pattern families where the family is regular, but fixed and
  special opcodes remain explicit table/special-handler cases. The bit-pattern
  scheme is a compact emitter aid, not the sole correctness model.
- The operand classifier is mnemonic-aware: `ASM_CLASS_OPERAND(mnemonic,
  operand_text)`. It returns mode, flags, width, value/care, unresolved hash,
  symbol slot, aux byte, fixup count, and status. The classifier rejects
  impossible mnemonic/operand shapes early; the emitter still verifies that the
  final mnemonic row plus mode maps to a real opcode.
- Accumulator-capable mnemonics accept both operandless and explicit `A` forms:
  `ASL`/`ASL A`, `ROL`/`ROL A`, `LSR`/`LSR A`, `ROR`/`ROR A`, `INC A`, and
  `DEC A`. The classifier returns `none` for operandless forms and `acc` for
  explicit `A`; only mnemonics with accumulator forms may map those classes to
  accumulator opcodes. `LDA A` and `STA A` are `BAD MODE`.
- Single-letter `A` is reserved as the accumulator token in operand context, not
  treated as a user symbol operand.
- `<` selects a byte; `#` selects immediate addressing. `LDA <FOO` reads memory
  at zero-page address `low(FOO)`, while `LDA #<FOO` loads the literal
  `low(FOO)` value into A.
- If the operand syntax and mnemonic supply exact width, an unresolved symbol
  may create a fixup. `LDA #FOO` is an `imm8` fixup: emit `A9 FF`, then patch
  the byte when `FOO` resolves. If `FOO` resolves outside `$00-$FF`, the fixup
  fails with `BAD RANGE`.
- Fixup-eligible classes are `imm8`, `zp8`, `abs16`, `rel8`, indexed zp/abs
  forms, zp/abs indirect forms, and bit zp/rel forms. `bit_zp_rel` may need two
  patch records; the bit number itself must resolve now.
- ASM vocabulary rows are sorted alphabetically by canonical token text when
  built. Each row stores the canonical token's FNV-1a hash and dispatch data.
  V1 lookup may scan the sorted hash table linearly; later code can add faster
  search without changing source syntax. Mnemonics remain three-letter base
  tokens; directives share the vocabulary rule but may be longer.
- ASM v1 error vocabulary should stay compact and boring:
  `BAD MNEM`, `BAD DIR`, `BAD OPER`, `BAD MODE`, `BAD WIDTH`, `BAD RANGE`,
  `BAD LINE`, `BAD SYM`, and `BAD FIX`.
- ASM 2.50 stops on the first error. The first interactive path is a
  line-at-a-time ICO, historically called the ASM REPL. As of ASM 2.56 it calls
  resident
  `SYS_READ_CSTRING_ECHO_UPPER`, prints compact `OK`/`ERR` feedback, and
  reopens at the pre-error PC after a rejected line; v1 does not keep parsing
  after an error.
- The current runtime console treats human typing and pasted source as the same
  line input stream. It calls the same `ASM_BEGIN` / `ASM_ASSEMBLE_LINE` /
  `ASM_END` spine, allows fixups to span input lines until `END`, and uses the
  same prompt/status/error/quench behavior for both typed and pasted lines. A
  future `ASM I`/`ASM B` command split is parked as a later presentation idea,
  not current behavior. Do not add `.Q`/`.V` source directives for this.
- The flash-resident wrapper keeps accepted source lines quiet but prints the
  current PC in its source prompt as `ASM>$hhhh: `. `SEAL> ` remains the
  post-`END` command prompt, `.P` remains source-mode-only, and rejected source
  lines still carry `ERR=$ee NAME PC=$hhhh`.
- ASM 2.72 keeps the runtime paste wrapper stricter than the line-at-a-time
  ICO: all failure exits funnel through a quench path. It prints the failure,
  drains RX with `SYS_FLUSH_RX`, then consumes timed input with
  `SYS_READ_CHAR_TIMEOUT_SPINDOWN` until the sender is quiet for the local idle
  window. It returns to HIMON with `C=0`, `A=status`, and `X/Y=current PC`;
  it does not call `ASM_BEGIN` or show another `ASM> ` prompt.
- The runtime paste wrapper's default emitted-code target is `$7600`, leaving
  room below it for the loaded runtime body, DATA constants, and UDATA/line
  buffer. ASM rejects output targets that overlap the live ASM workspace:
  RAM-loaded runtime/core images protect `$2000..ASM_CODE_BUF-1`, and the
  flash wrapper protects `$5000..ASM_CODE_BUF-1`. Runtime-paste `ASM_CODE_BUF`
  remains a valid fallback emission buffer; flash ASM starts at explicit
  `$2000`, and its high-RAM `ASM_CODE_BUF` is only an 8-byte guard fence ending
  at the `$7F00` I/O page. The guard is applied at explicit `ASM_BEGIN`, `ORG`,
  and before emitting byte spans, so failures return `BAD RANGE` before writing
  into the protected area.
- `ASM_RUNTIME_ONLY` keeps the default `ASM_CODE_BUF` as UDATA, not loaded
  DATA. The callable runtime wrappers normally enter with explicit PCs, and the
  default buffer remains a RAM fallback without costing S19 bytes.
- `ASM_RUNTIME_ONLY` also keeps ASM session state, seal records, relocation
  records, symbol tables, and fixup tables in UDATA. Runtime entry reseeds
  RJOIN before consulting the RAM-ready flag, so stale RAM cannot skip pointer
  setup. The loaded image carries code and constant tables; `ASM_BEGIN` owns
  clearing per-session counters before source lines are accepted.
- Paste and flash post-`END` recognizers share the same leading-whitespace and
  tail-validation shape. `SEAL` and `NEW` stay strict wrapper commands: comments
  are allowed, operands are rejected. `END` keeps the existing wrapper detection
  rule so this refactor is size/presentation work, not a language change.
- Current seed-only ASM requires the `HASH ACQUIRE` seed at the fixed RAM cell
  `$7E00/$7E01`. HIMON publishes the current `THE_JOIN_EXEC_XY` addr16 there
  during common init, so the value follows HIMON if the resident join routine
  moves. ASM rejects `$FFFF` and high bytes below `$C0`, then uses the pointer as
  the resident joiner. The local scanner bootstrap is no longer carried in the
  `$8000` ASM/no-header direction.
- STR8 `U` / `UPDATE HIMON` programs only `$C000-$EFFF`, but that is enough for
  the RAM seed contract: after HIMON starts, it publishes the new joiner address
  without needing a top-sector `$FFF8/$FFF9` flash patch.
- The first ASM flash slice is a fixed-address `L F` image, not an auto-placed
  image. `asm-v1-flash` links the FNV record at `$8000`, uses `START` from the
  map for the S9 entry, keeps emitted opcodes in `$2000-$4FFF`, and places ASM
  runtime UDATA at `$5000+`. `$5000` is the mutable table arena, not the base
  RAM emission address.
- For the future "ASM assembles ASM" milestone, table-limit bumps are only a
  measurement step. The current practical mix is `ASM_SYM_MAX=$28`,
  `ASM_FIX_MAX=$60`, `ASM_REF_MAX=$A0`, and `ASM_LOCAL_MAX=$10`, while keeping
  the 32-byte global/fixup and 16-byte local name slots. It favors fixup-heavy
  interactive samples; the flash map currently places `_END_UDATA` at `$7D3B`,
  below the `$7E00/$7E01` RJOIN seed. Check `_END_UDATA` after every bump.
  Self-hosting ASM must be chunked by routine pack/slice with export/seal
  between sessions; a one-session assembly of `asm-v1-core.asm` would need far
  more symbol storage than RAM can provide.
- The intended layering is STR8 for boot/flash policy, T.H.E. for the hash/join
  contract, HIMON for resident service publication, and ASM as a client of
  those resident services.
- `LDA #$1234` is `BAD RANGE` because immediate byte width is known but the
  value is too large. `LDA ($1234),Y` is `BAD MODE` because that data addressing
  form is zero-page-only. `LABEL END` is `BAD SYM`; `END X` is `BAD OPER`.
- V1 must support forward references through fixups. A forward-reference ban is
  rejected.
- A fixup is a hash lookup plus patch-site record, not magic. It must preserve
  enough information to patch the correct byte(s) later.
- Flash destinations may use byte patching only where flash 1-to-0 write rules
  allow it. RAM destinations can patch freely.
- Onboard assembly should tolerate flash clutter at first; later HIMON or
  maintenance condense can reclaim buried or superseded records.
