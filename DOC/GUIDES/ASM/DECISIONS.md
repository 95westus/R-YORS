# ASM Decisions

This file holds detailed settled decisions for ASM. It was split out from [DECISIONS.md](../DECISIONS.md) so the project-wide decision ledger stays readable.

The broader design narrative remains in [HASHED_ASM.md](HASHED_ASM.md), and open questions/working notes remain in [../QCC/ASM.md](../QCC/ASM.md).

## Hashed ASM Direction

Settled v1 overview:

- ASM v1 is a RAM-session W65C02S assembler: native emitted bytes, explicit
  symbol/fixup/reference tables, and no public flash/catalog visibility until a
  later seal/export path.
- ASM proper reads full source lines, suitable for pasted input in the current
  test. Its source-line shape is `[label[:]] operation [operand]`. HIMON's
  `A [addr] ... .` form is legacy mini-assembler syntax, not an ASM input path.
  ASM was going to use `A`, but that plan is canceled. When ASM compiles ASM
  successfully, remove `A` from HIMON. ASM parsing is hash-first, with
  non-vocabulary first tokens held as pending definition names.
- Width is source intent. `$hh` means zero page, `$hhhh` means absolute, and no
  numeric-range promotion/demotion is allowed.
- `EQU`, `DB`, `DS`, `ORG`, and `END` are v1 directives. `EQU` must resolve
  immediately; forward references use emitted-byte fixups only.
- `DC` is parked for now because WDC source format wins. V1 vocabulary keeps
  `DC` reserved so using it as an operation returns `BAD DIR`, not a user
  symbol.
- V1 reports the current session: address range, bytes, counts, unresolved
  fixups, used symbols with line numbers, unused session symbols, and resident
  symbols referenced.
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
ASM 2.30   DB/DS/ORG/END directive handlers
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
ASM 6.10   local labels / scopes later
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
ASM 9.99   remove legacy A from HIMON
```

- Future operator diagnostics use `ASM-xxxx`, not the course numbers. That
  keeps later S/36-style message IDs and WTOR/reply policy separate from design
  chapters. V1 still stops on the first error.

- Legacy HIMON mini-assembler command, outside ASM:

```text
A [addr] [label[:]] MMM [operand] .
```

- In the legacy `A` command, address comes before optional label. Do not route
  ASM through `A`; ASM proper uses source lines and `ORG`/session PC state
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
  Binding waits until the operation is known: mnemonic/`DB`/`DS` bind the name
  to the current PC, while `EQU` binds the name to the expression value. A
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
- Dot and question mark are reserved for future local-label syntax. They are
  prefix-only, not free-floating global symbol characters. In v1, `.NAME`,
  `.NAME:`, `?NAME`, and `?NAME:` should fail with `LOCAL NYI`. `.` alone is a
  legacy `A`/input-driver sentinel if used, not ASM source syntax. No v1
  dot-directive aliases.
- Minimal v1 ASM directives follow WDC shape: `EQU`, `DB`, `DS`, `ORG`, and
  `END`. `DC`, `START`, `ENTRY`, and `EXTRN` are parked later directives, not
  v1.
- V1 directive shapes are:
  `NAME EQU expr` with name required;
  `[NAME] DB item[,item...]` with optional current-PC label;
  `[NAME] DS count[,init...]` with optional current-PC label;
  `ORG expr` with no leading name;
  `END` with no leading name and no operand.
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
  `WORD` with `LOCAL_PREFIX` so v1 can return `LOCAL NYI`.
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
  `BAD DIR`, `BAD OPER`, or `LOCAL NYI` for top-level statement errors.
- `ASM_DISPATCH_STATEMENT` applies the top-level policy: label-only binds the
  pending name to current PC; mnemonic/DB/DS with a name bind current PC before
  emission/data handling; `EQU` requires a name and binds expression value;
  `ORG` and `END` reject leading names; clean `END` calls `ASM_END`.
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
- `ASM_PARSE_EXPR` parses one expression from `ASM_PARSE_PTR` and returns
  `KNOWN`, allowed `UNRESOLVED`, or `ERROR` with kind, width, value, care mask,
  selector flags, and unresolved symbol name/hash when applicable. Caller flags
  control whether one unresolved symbol is allowed and whether comma/right-paren
  may terminate the expression.
- ASM 1.80 grammar is `term {op term}*`, where a term is optional `<`/`>`
  selector plus decimal, hex, binary/mask, character literal, symbol, or `*`.
  Operators are `+`, `-`, `|`, `&`, and `^`.
- ASM 1.80 preserves the standout rule: expressions evaluate strictly
  left-to-right, with no operator precedence and no grouping parentheses.
- `+` and `-` require known concrete values/addresses, not masks. Arithmetic
  keeps the left operand's address-width intent and range-checks the result; it
  does not promote or demote.
- `|`, `&`, and `^` require known same-width values or masks. Mask results carry
  value/care/width and may normalize to `VALUE` only when the care mask becomes
  all ones.
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
  for local labels, but a global symbol must not begin with a digit. Dot and
  question mark are reserved local-prefix characters and are prefix-only.
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
  `COUNT EQU 10`, `ERR_1 EQU %XXXXXXX1`, `ERR_2 EQU %XXXXXX1X`, and
  `FLAGS EQU ERR_1 | ERR_2`.
- `*` is the current assembly PC/location counter when used as an expression
  term. `ADDR EQU * - $20` is not a forward `EQU`; it resolves immediately from
  the current PC and a known literal. Because `*` is an address, the result is
  an absolute/word-width value if it remains in `$0000-$FFFF`; underflow or
  overflow is `BAD RANGE`.
- ASM v1 expression operators are `+`, `-`, `|`, `&`, and `^`. Evaluation is
  strictly left-to-right with no operator precedence. `A | B & C` means
  `(A | B) & C`. Use a separate `EQU` if a staged result is needed.
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
- For v1 mask/logical expressions, `|`, `&`, and `^` require known same-width
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
  grows downward from `$AF`. Persistent ASM state stays in RAM tables. HIMON
  shared ZP may be borrowed only as volatile scratch under the called routine's
  contract; ASM must not depend on shared bytes surviving SYS/BIO/COR/PIN/flash/
  FNV/HIMON helper calls.
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
- ASM v1 RAM reference rows carry line number, referenced symbol hash/text, use
  mode, emitted site/current PC, resolution result, and local symbol slot when
  applicable. They drive the basic session report and xref view.
- RAM "rows" are conceptual records. A W65C02 implementation may store fields
  as parallel arrays indexed by slot, matching the current proof style, when
  that saves code or cycles.
- First implementation uses fixed table limits. If symbol or fixup space fills,
  fail with `BAD SYM` or `BAD FIX`; do not spill silently or start writing into
  flash. The current proof sizes are 16 symbols, 8 fixups, 31 visible name
  characters, 63 input characters, and a 512-byte code buffer; treat those as
  proof defaults, not permanent language limits.
- ASM lookup is layered so it can grow to HIMON-scale symbol counts. V1 checks
  RAM session symbols first, then resident HIMON/catalog symbols, then creates a
  fixup if the operand mode allows a forward reference. The RAM session table is
  only the current workbench; a large resident/packed symbol table is a design
  goal, and assembling ASM/HIMON under ASM is a future acceptance test.
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
- V1 report timing is simple: `END` prints the report; the first error prints
  `ASM ERR line status [token/name]`, then the compact report, then stops the
  session. A separate `REPORT` command can be added later.
- ASM report line numbers are physical source/session input lines counted from
  the start of the assembly session, including blank/comment lines. References
  are only recorded for lines that define or use a symbol.
- Do not add `BAD TABLE` in v1. Table-full behavior maps to existing codes:
  symbol table or name pool full is `BAD SYM`; fixup table full is `BAD FIX`;
  reference table full is `BAD FIX` with `TRUNC=YES`; line too long is
  `BAD LINE`; code target overflow is `BAD RANGE`.
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
  `BAD LINE`, `BAD SYM`, `BAD FIX`, and `LOCAL NYI`.
- ASM 2.50 stops on the first error. The first interactive path is a
  line-at-a-time REPL that calls resident `SYS_READ_CSTRING_EDIT_ECHO_UPPER`,
  prints compact `OK`/`ERR` feedback, and reopens at the pre-error PC after a
  rejected line; v1 does not keep parsing after an error.
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
