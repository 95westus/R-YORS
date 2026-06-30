# QCC ASM

This page keeps onboard assembler questions in QCC form. These are working
notes for the hash-first assembler path. Public/exported symbols should use
FNV32 identity; CRC16 or short IDs are for local/scoped assembler tables where
context can handle collisions.

## Settled Shape

Settled enough to implement against:

```text
source line         [label[:]] operation [operand]
line limit          63 visible chars, tabs are whitespace
parser              ASM hash-first vocabulary, pending definition names
RJOIN               works with, uses, respects hash joins to proved records
v1 directives       EQU, DB, DW, DS, ORG, END
width rule          source spelling controls ZP/absolute, no silent conversion
storage             RAM-session emitted bytes plus RAM sym/fix/ref tables
zero page           active ASM scratch grows downward from $AF
calling             all callable routines follow HIMON/THE routine style
fixups              emitted-byte patch records, $FF placeholders
reports             basic session report required in v1
input driver        one current path for typed/pasted lines
large symbols       layered lookup, future HIMON-scale resident table
SYM3                base-40 3-char prefix filter, not identity
locals              16 label-only locals per active global scope, 15 visible chars
legacy A            removed from HIMON after flash ASM proof
```

Still QCC/open:

```text
expression grouping parentheses and richer expression features
explicit SET/REDEF syntax, if ever needed
HBSTR/CSTR/PSTR as DC forms versus directives
local-label report/export polish
resident HIMON-scale symbol table record/index format
rich report/export formats
production RAM workspace addresses and capacities
```

## Q: What are the ASM course numbers?

Comment: The `ASM n.nn` numbers are a course-catalog map for the work. Gaps
are intentional. Nested detail uses `ASM n.nn.m`.

```text
ASM 1.10     source rules
ASM 1.10.1   line shape and statement grammar
ASM 1.10.2   labels and optional colon

ASM 1.30     session spine
ASM 1.30.1   ASM_BEGIN
ASM 1.30.2   ASM_ASSEMBLE_LINE
ASM 1.30.3   ASM_END
```

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
ASM 2.30   DC/DS/ORG/END directive handlers
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

Future operator diagnostics use `ASM-xxxx`, not the course numbers. That keeps
later S/36-style message IDs and WTOR/reply policy separate from design
chapters. V1 still stops on the first error.

## Q: What calling convention does ASM use?

Comment: ASM follows HIMON/THE routine style. Do not invent a private assembler
ABI.

Every callable ASM routine card must document:

```text
inputs
outputs
carry/status meaning
preserves
clobbers
ASM zero-page frame bytes used
RAM tables touched
stack behavior
calls
error returns
```

Default return shape:

```text
C=1  success, true, found, accepted, or completed
C=0  failure, false, not found, invalid, timeout, or rejected
A    natural byte/status/result when the routine owns A as output
X/Y  natural pointer or word result, low/high, when the routine owns X/Y
```

When a routine returns an ASM status code, `A` carries `OK`, `BAD MNEM`,
`BAD OPER`, and the other ASM status names. When a routine naturally returns a
byte, pointer, hash fold, or character result, that routine's card must say so.

Concern: Preserves and clobbers must be explicit. Shared HIMON/SYS/BIO/PIN/
flash zero-page bytes are volatile across helper calls unless the helper's own
contract says otherwise.

## Q: What is the ASM 1.30 session spine?

Comment: Start with three callable routines. They are the outer shell that a
pasted-line monitor driver, a future file/stream driver, or a test harness can
all use.

```text
ASM_BEGIN          open/reset one RAM ASM session
ASM_ASSEMBLE_LINE  assemble one physical source line
ASM_END            resolve final fixups, report, close
```

Shared return rule:

```text
C=1  accepted/completed
C=0  failed/rejected
A    ASM status code
X/Y  current ASM PC low/high
```

`ASM 1.30.1 ASM_BEGIN`:

```text
IN   A bit0 set means X/Y is explicit start PC
     A bit0 clear means use configured default scratch origin
OUT  C=1,A=OK,X/Y=current PC
ERR  C=0,A=BAD RANGE or BAD FIX
DOES clear session state and tables; does not erase target code range
```

`ASM 1.30.2 ASM_ASSEMBLE_LINE`:

```text
IN   X/Y = NUL/CR/LF-terminated source line
OUT  C=1,A=OK,X/Y=current PC
ERR  C=0,A=status,X/Y=current PC; error token stored if available
DOES increments physical line count; accepts blank/comment lines
     prepares the line, parses the head into STMT, then dispatches STMT
     handles `END` by calling `ASM_END`
     copies needed symbol/fixup text before return
```

`ASM 1.30.3 ASM_END`:

```text
IN   none
OUT  C=1,A=OK,X/Y=current PC when fixups resolve
ERR  C=0,A=BAD FIX/BAD RANGE/BAD WIDTH
DOES resolves final fixups, prints compact report, marks ended/failed
```

Concern: `ASM_END` should be idempotent after a clean end. A second direct call
returns `OK` and does not print a second report. After a failed session, later
calls return the stored failure status.

## Q: How does ASM treat typed versus pasted input today?

Comment: Today they are the same input path. The runtime console reads one
physical source line, feeds it through `ASM_ASSEMBLE_LINE`, prints the same
prompt/status feedback, and uses `END` as the final fixup/report boundary.
Typing and pasting do not select different assembler modes.

Concern: Do not put quiet/verbose controls into ASM source as `.Q`, `.V`, or
similar directives. A future `ASM I`/`ASM B` command split is only a parked
presentation idea, and must still feed the same `ASM_BEGIN`,
`ASM_ASSEMBLE_LINE`, and `ASM_END` spine if it is added later. See
[../ASM/INTERACTIVE_BATCH.md](../ASM/INTERACTIVE_BATCH.md).

## Q: What is the v1 statement grammar?

Comment: One source line is one statement. ASM v1 has no multiple statements per
line and no trailing `.` terminator.

Accepted statement shapes:

```text
blank/comment line
LABEL
LABEL:
CMD [operand]
LABEL CMD [operand]
LABEL: CMD [operand]
```

Binding rule:

```text
LABEL mnemonic operand      LABEL = current PC before emitting
LABEL DC ...                LABEL = current PC before data
LABEL DS ...                LABEL = current PC before storage
LABEL EQU expr              LABEL = expression value
LABEL alone                 LABEL = current PC
LABEL: alone                LABEL = current PC
```

Directive shapes:

```text
NAME EQU expr
[NAME] DC item[,item...]
[NAME] DS count[,init...]
ORG expr
END
```

Reject in v1:

```asm
LABEL ORG $2000     ; BAD SYM
LABEL END           ; BAD SYM
EQU $12             ; BAD SYM
ORG                 ; BAD OPER
END anything        ; BAD OPER
LDA #1 extra        ; BAD OPER
```

Concern: `ORG` and `END` are session/control statements, not label-binding
statements. `LABEL END` is `BAD SYM`, not "define the label, then end."
Trailing non-comment junk after a complete statement is `BAD OPER`.

## Q: What is the ASM 1.60 statement parser contract?

Comment: ASM 1.60 turns the prepared line head into a statement record and a
dispatch decision. It uses ASM 1.40 scanning and ASM 1.50 vocabulary lookup.

Statement record:

```text
STMT_KIND     EMPTY, LABEL_ONLY, MNEM, DIR, ERROR
STMT_FLAGS    HAS_NAME, HAS_COLON, HAS_TAIL, BINDS_PC, BINDS_EQU, CONTROL
STMT_NAMEPTR  pending definition name pointer
STMT_NAMELEN  pending definition name length, colon excluded
STMT_NAMEHASH FNV32 for pending definition name
STMT_VOCSLOT  vocabulary slot for operation
STMT_OPKIND   VOC_MNEM or VOC_DIR
STMT_OPID     mnemonic/directive id
STMT_TAILPTR  operand/directive tail pointer
STMT_STATUS   OK or BAD xxx
```

Callable parser routines:

```text
ASM_PARSE_HEAD
IN   prepared line / ASM_PARSE_PTR
OUT  C=1,A=OK with STMT record filled
ERR  C=0,A=BAD SYM/BAD MNEM/BAD DIR/BAD OPER

ASM_DISPATCH_STATEMENT
IN   current STMT record
OUT  C=1,A=OK,X/Y=current PC if accepted
ERR  C=0,A=status,X/Y=current PC
```

Dispatch policy:

```text
EMPTY          accept, emit nothing
LABEL_ONLY     bind pending name to current PC, try fixups
MNEM no name   classify operand tail, emit instruction
MNEM with name bind name to current PC, try fixups, then emit instruction
DC/DS with name bind name to current PC, try fixups, then handle directive
EQU with name  parse expression and define symbol value
EQU no name    BAD SYM
ORG with name  BAD SYM
END with name  BAD SYM
ORG no tail    BAD OPER
END with tail  BAD OPER
END clean      call ASM_END
```

Concern: ASM 1.60 may check whether a tail exists, but it should not validate
the detailed operand tail. That belongs to directives, expressions, and operand
classification.

## Q: What is the ASM 1.70 symbol table contract?

Comment: ASM 1.70 owns the RAM-session symbol table, not the later resident
HIMON-scale table. The v1 table stores definitions made during the current ASM
session and proves lookup by hash plus canonical text.

Future ASM/HIMON-scale assembly may need temporary storage, flash workspace,
compression, or both. That is later resident-scale machinery, not v1 row cost.

Session symbol row:

```text
SYM_STATE    EMPTY, DEFINED
SYM_FLAGS    USED, HAS_TEXT, HAS_CARE, FROM_LABEL, FROM_EQU
SYM_KIND     VALUE, ADDR, MASK
SYM_WIDTH    NONE, BYTE, WORD, ZP, ABS, MASK8, MASK16
SYM_VALUE    16-bit value/address
SYM_CARE     16-bit mask care bits
SYM_HASH32   FNV32 canonical symbol hash
SYM_NAMELEN  canonical name length, 1..31
SYM_NAMEPTR  session name-pool pointer/offset
SYM_DEF_LINE defining physical source line
SYM_USECNT   references seen this session
SYM_FIRSTREF first reference line, 0 if unused
```

Kind/width examples:

```asm
LABEL                 ; ADDR, ABS
FOO EQU $12           ; ADDR, ZP
FOO EQU $0012         ; ADDR, ABS
COUNT EQU 10          ; VALUE, NONE
CH EQU 'A'            ; VALUE, BYTE
ERR EQU %XXXXXXX1     ; MASK, MASK8
```

Callable symbol routines:

```text
ASM_LOOKUP_SYMBOL
IN   canonical name pointer/length/hash and allowed lookup layers
OUT  C=1,A=OK,X=slot,Y=layer if found
     C=0,A=OK,X=$FF,Y=0 if not found
NOTE not-found is normal; caller chooses BAD SYM, fixup, or unresolved EQU

ASM_BIND_LABEL
IN   pending statement name and current PC
OUT  C=1,A=OK,X=slot when label defined
ERR  C=0,A=BAD SYM/BAD FIX
DOES stores KIND=ADDR, WIDTH=ABS, VALUE=current PC, then tries fixups

ASM_DEFINE_EQU
IN   pending statement name and resolved expression result
OUT  C=1,A=OK,X=slot when EQU symbol defined
ERR  C=0,A=BAD SYM/BAD WIDTH
DOES stores VALUE/ADDR/MASK according to expression result
```

Duplicate policy:

```text
first definition wins
second definition is BAD SYM
same value redefinition is still BAD SYM
label/EQU name collisions are BAD SYM
```

Concern: Hash is a candidate finder, not truth. Session symbols store canonical
text, so lookup compares hash first and length/text second. Resident tables may
be compressed later, but they still need a proof path before ASM trusts the
value. Do not store `SYM3` in v1 RAM rows; compute it later when
resident-scale lookup needs it.

## Q: What is the ASM 1.80 expression evaluator contract?

Comment: ASM 1.80 parses one small v1 expression and returns an expression
result. Source syntax is readable infix. Internal RPN is allowed only if it
keeps the W65C02S code smaller.

V1 grammar:

```text
expr      term { op term }*
term      [selector] atom
selector  < | >
atom      decimal | hex | binary/mask | char | symbol | *
op        one of + - | & ^
```

Important rule:

```text
evaluation is strictly left-to-right
there is no operator precedence
parentheses are not expression grouping in v1
```

Expression result:

```text
EXPR_STATE   KNOWN, UNRESOLVED, ERROR
EXPR_KIND    VALUE, ADDR, MASK
EXPR_WIDTH   NONE, BYTE, WORD, ZP, ABS, MASK8, MASK16
EXPR_FLAGS   FORCE_LO, FORCE_HI, HAS_CARE, HAS_OP, HAS_SYMBOL
EXPR_VALUE   16-bit value/address
EXPR_CARE    16-bit care mask
EXPR_HASH32  unresolved symbol hash when unresolved
EXPR_NAMELEN unresolved name length
EXPR_NAMEPTR unresolved name text pointer/offset
```

Callable evaluator:

```text
ASM_PARSE_EXPR
IN   ASM_PARSE_PTR at first expression token
     A bit0 allow one unresolved symbol result
     A bit1 mark symbol use/reference
     A bit2 comma may terminate expression
     A bit3 right paren may terminate expression
OUT  C=1,A=OK with expression result filled
ERR  C=0,A=BAD OPER/BAD SYM/BAD WIDTH/BAD RANGE/BAD FIX
```

Operator policy:

```text
+ -     known concrete values/addresses only; no masks
| & ^   known same-width values/masks only
```

Deferred implementation slice:

```text
goal       add OR, AND, and EOR to ASM_PARSE_EXPR
symbols    | = bitwise OR, & = bitwise AND, ^ = bitwise EOR/XOR
scope      current expression callers first: EQU, ORG, and DW
not scope  DB/DS list expression math, raw operand-tail math, forward addends
order      strict left-to-right, still no precedence or grouping parentheses
state      resolved-now only; no forward EQU dependency solver
```

Do not treat this as the next ASM implementation step. The practical first test
when this slice is reopened should stage byte values through `EQU`, then prove
the results with `DW` or with `DB` reading the already-resolved symbol atom:

```asm
A       EQU $12
B       EQU $34
ORV     EQU A|B        ; $36
ANDV    EQU $F0&$3C    ; $30
EORV    EQU $55^$0F    ; $5A
WORDS   DW ORV,ANDV,EORV
BYTES   DB ORV,ANDV,EORV
```

`BYTES` works only because each `DB` item is now a single resolved symbol atom.
`DB A|B` remains a later DB-list expression feature until `DB` is deliberately
rewired to call the expression evaluator for each comma-separated item.

Arithmetic keeps the left operand's address-width intent. It does not promote
or demote:

```asm
ADDR EQU * - $20     ; ABS result if in range
NEXT EQU $12 + 1     ; ZP result if still in $00-$FF
```

Unresolved policy:

```text
allowed unresolved forms: SYMBOL, <SYMBOL, >SYMBOL
compound unresolved forms: BAD SYM or BAD FIX in v1
```

Examples:

```asm
LDA FOO       ; caller may choose abs16 fixup
LDA <FOO      ; caller may choose zp/lo8 fixup
LDA #<FOO     ; caller may choose imm8 low-byte fixup
DC <FOO,>FOO  ; caller may create two byte fixups
LDA FOO+1     ; not v1 while FOO is unresolved
NEXT EQU BASE+1 ; not v1 as forward EQU
```

Concern: The expression evaluator does not create fixup rows directly and does
not choose opcodes. It reports a known or allowed-unresolved expression; the
operand classifier/directive handler decides whether that result is legal.

## Q: Can assembler symbols be hash-first?

Comment: Yes. A proof-sized onboard assembler can compute compact hashes for
labels and mnemonics, then resolve names through catalog records. The same
lookup shape must grow to HIMON-scale symbol tables later.

For resident/public symbols, hash lookup is only the front half. ASM works with,
uses, and respects the RJOIN/HREC discipline: join the candidate before trusting
the address, kind, bank, or callable entry.

Concern: Hash-only symbol records are not enough for every case. User-created
symbols need enough name text, length, scope, or collision data to prove which
symbol was intended.

## Q: What happens with forward labels?

Comment: Emit a fixup record when a label is used before it is known. Later,
when the label is sealed into the symbol table, resolve the fixup.

Concern: Fixups must record enough context to patch safely: address, width,
relative/absolute mode, symbol hash/hash, and any text or scope needed to
survive a collision.

## Q: Should ASM infer zero page from a symbol value?

Comment: No. Address width is a source spelling decision, not an optimization
based on the final numeric value. `$F0` is a zero-page operand. `$00F0` is an
absolute operand. An `EQU` symbol records the width implied by its defining
source spelling.

Examples:

```asm
ZPFOO   EQU     $12
ABSFOO  EQU     $0012
COUNT   EQU     10

        LDA     ZPFOO   ; zero page
        LDA     ABSFOO  ; absolute
        LDA     #COUNT  ; immediate ok if value fits
        LDA     COUNT   ; BAD WIDTH, no memory-address width
        LDA     $F0     ; zero page
        LDA     $00F0   ; absolute
```

Concern: Auto-promotion or auto-demotion would make listings, fixups, flash
patches, and disassembly harder to trust. Scope rules for local/global symbols
can grow later, but scope lookup must not silently change operand width.

## Q: How should RMB/SMB/BBR/BBS spell the bit number?

Comment: Use the three-letter base mnemonic plus an explicit bit operand:

```asm
RMB     3,$12
SMB     7,$12
BBR     3,$12,TARGET
BBS     7,$12,TARGET
```

The bit number is part of operand classification, not part of the mnemonic
token. The mnemonic hash table keeps the base `RMB`, `SMB`, `BBR`, and `BBS`
entries. The bit operand must resolve to `0..7` before opcode selection.

Concern: Supporting `RMB3` or `BBS7` as first-class tokens would expand the
reserved vocabulary and weaken the "hash each three-letter mnemonic" rule.
Keep those compatibility spellings out of v1.

## Q: Which IBM-ish directives belong in ASM v1?

Comment: Keep v1 small:

```text
EQU
DC
DS
ORG
END
```

`START`, `ENTRY`, and `EXTRN` are useful later, but they imply module/member
boundaries, exports, and imports. Park them until the assembler has stable
symbol records and fixups.

V1 directive shapes:

```text
NAME EQU expr
[NAME] DC item[,item...]
[NAME] DS count[,init...]
ORG expr
END
```

Concern: These directive names must still be reserved ASM vocabulary once they
are scheduled. A source label should not be allowed to collide with a future
directive that is already named as parked design.

## Q: What are v1 token and literal rules?

Comment: ASM reads one full source line. V1 keeps the proof-sized input limit:
63 visible characters. Spaces and tabs are whitespace; tabs have no column
meaning in v1. Empty and comment-only lines are OK. A too-long line is
`BAD LINE`.

Canonical token identity is uppercase FNV text with bit 7 masked from input
bytes before hashing. A trailing colon is allowed on labels but is not part of
the symbol. `;` begins a comment through end of line.

V1 token classes:

```text
WORD       symbol, mnemonic, directive
NUMBER     decimal, $hex, %binary, %mask
CHAR       'A', 'a', '''
STRING     later, for HBSTR/CSTR/PSTR
PUNCT      # , ( ) < > + - * | & ^ : .
COMMENT    ; through end of line
EOL        end of source line
```

## Q: What is the ASM 1.40 lexer/tokenizer contract?

Comment: ASM 1.40 is a streaming lexer. It prepares one line and returns one
current token record at a time. It does not decide labels, mnemonics, address
modes, or expression values beyond a character literal byte.

The statement head can stay lighter than the operand tail: scan first word,
maybe scan second word, then hand the remaining operand/directive tail to the
real tokenizer when needed.

Lexer routines:

```text
ASM_LEX_LINE     prepare one source line; check 63 visible chars
ASM_NEXT_TOKEN   return next token into the current token record
```

Current token record, logical fields:

```text
TOK_KIND     EOL, WORD, NUMBER, CHAR, PUNCT
TOK_SUB      DEC, HEX, BIN, MASK, or punctuation byte
TOK_FLAGS    HAS_COLON, HAS_XMASK, QUOTED, LOCAL_PREFIX, ERROR
TOK_PTR      source pointer
TOK_LEN      visible token length, excluding optional attached colon
TOK_DELIM    delimiter that stopped the token
TOK_HASH32   canonical FNV32 for WORD tokens
TOK_VALUE    character byte for CHAR
TOK_STATUS   OK, BAD LINE, or BAD OPER
```

Concern: `COMMENT` is recognized but not returned. A `;` outside quotes makes
the next token `EOL`.

`ASM_NEXT_TOKEN` rules:

```text
space/tab       skipped
NUL/CR/LF       EOL
; outside quote EOL
# , ( ) < > + - * | & ^ :   PUNCT
. alone         PUNCT '.', later BAD OPER unless input driver consumed it
.NAME/?NAME     WORD with LOCAL_PREFIX
'A'/'a'/'''     CHAR
123             NUMBER DEC
$FF             NUMBER HEX
%10101010       NUMBER BIN
%XXXXXXX1       NUMBER MASK
```

For `%`, the lexer accepts only `0`, `1`, `X`, and `x` until the token
delimiter, and requires exactly 8 or 16 digits. `X`/`x` sets `HAS_XMASK`.

## Q: What is the ASM 1.50 vocabulary hash lookup contract?

Comment: ASM 1.50 answers one question: is this canonical word assembler
vocabulary, and what kind?

Vocabulary result kinds:

```text
VOC_NONE       not vocabulary; caller may treat as pending name/symbol
VOC_MNEM       instruction mnemonic
VOC_DIR        active v1 directive
VOC_REG        reserved register word A/X/Y
VOC_RESERVED   parked/future word that cannot be a label in v1
VOC_ALIAS      future compatibility alias, not v1
```

Statement-head policy:

```text
first word VOC_MNEM/VOC_DIR      operation
first word VOC_NONE              pending definition name
first word VOC_REG/VOC_RESERVED  BAD SYM if used as a definition name
second word must be VOC_MNEM or VOC_DIR when a pending name exists
second word VOC_NONE/VOC_REG     BAD MNEM
parked directive used as op      BAD DIR
```

Logical row:

```text
VOC_TEXT      canonical spelling, build/list/proof text
VOC_HASH32    FNV32 of canonical spelling
VOC_KIND      MNEM, DIR, REG, RESERVED, ALIAS
VOC_ID        mnemonic/directive/register/reserved id
VOC_FLAGS     active, parked, operand-only, needs-handler
VOC_DISP      handler/family id or compact dispatch byte
VOC_AUX       mode mask, opcode family, or helper index
```

Callable contract:

```text
ASM_LOOKUP_WORD
IN   current WORD token/head-word hash and pointer
OUT  C=1,A=OK,X=slot,Y=VOC_KIND if found
     C=0,A=OK,X=$FF,Y=VOC_NONE if not found
ERR  none for not-found
```

Concern: Vocabulary hash is an accelerator, not truth. The fixed vocabulary
build must verify no duplicate canonical text and no duplicate active FNV32
unless runtime text compare is present.

V1 active directives:

```text
DB DW DS END EQU ORG
```

Parked reserved directives:

```text
ENTRY EXTRN START
```

Reserved register words:

```text
A X Y
```

V1 symbols are capped at 31 visible characters. That follows the current
ASM/RJOIN proof, where `ASM_FIX_NAME_MAX` is `$20` and one byte is needed for
termination. HIMON input buffers can hold more, but the first assembler should
prefer a clear small symbol contract.

V1 symbol characters:

```text
A-Z 0-9 _ plus . or ? as local prefix
```

A global symbol must not begin with `0-9`. Dot and question mark are
local-prefix characters and are prefix-only. Local labels are scoped under the
most recent nonlocal PC label and are capped at 15 visible characters. Comma is
not a symbol character; it is operand punctuation for indexes and multi-part
operands such as `BBR 3,$12,TARGET`.

`A`, `X`, and `Y` are reserved v1 register words and are not legal user symbols.

Symbol recognition:

```text
LABEL CMD OP
LABEL: CMD OP
LABEL
LABEL:
```

Leading spaces are not required. V1 does not use column position to decide
whether a token is a label. The first token is hashed against the ASM vocabulary
after stripping an optional trailing colon for the vocabulary check. If it is a
mnemonic or directive, it is the operation. If it is not vocabulary, it is a
pending definition name. The next token, if present, must be a mnemonic or
directive. A line containing only `LABEL` or `LABEL:` defines a label at the
current PC and emits no bytes.

Labels cannot be mnemonic, directive, or register names. `LDA`, `LDA:`, `EQU`,
`EQU:`, `A`, `X`, and `Y` are reserved vocabulary, not legal labels.

V1 duplicate definition policy:

```text
define a canonical symbol once
second definition of the same canonical symbol -> BAD SYM
```

This applies to PC labels and `EQU` names. Later explicit `SET`/`REDEF`
machinery can loosen that rule if it is needed.

Literals:

```text
123          decimal
$FF          hex
%10101010    binary
%XXXXXXX1    binary pattern/mask
'A'          character byte
```

Binary `%` literals are 8 or 16 bits. After `%`, the lexer is in binary/mask
mode and accepts only `0`, `1`, `X`, and `x` until the token delimiter. `X` or
`x` marks a don't-care bit in a pattern/mask literal. Outside a `%` token, `X`
and `Y` are index-register tokens only where operand syntax expects them.

Decimal literals are plain concrete numbers. They are useful for immediates,
bit numbers, counts, data bytes, and ordinary expressions, but decimal spelling
does not select zero-page or absolute memory addressing.

In byte-data context, decimal emits the byte if it fits. `DC 10` is `DC $0A`.

Hex spelling carries width:

```text
$0-$FF        byte / zero page
$0000-$FFFF   word / absolute
$123          BAD WIDTH in v1
```

So `LDA 13` is `BAD WIDTH`, while `LDA #13`, `RMB 3,$12`, and `DS 2,13,10`
are valid because the surrounding syntax supplies the width/use.

Character literals preserve exact character value inside quotes:

```asm
'A'       ; uppercase A
'a'       ; lowercase a
'''       ; single quote character
```

No C-style escapes in v1.

Concern: V1 source expressions stay small and readable infix, not source RPN.
Accepted source terms include symbols, numbers, mask patterns, `*`, and optional
`<` or `>` byte selection.

Important v1 rule:

```text
operators accepted: + - | & ^
evaluation: strictly left-to-right
operator precedence: none
expression grouping parentheses: rejected, BAD OPER
```

Unary minus is not v1 syntax. Write `0-1` if needed, then let the target context
range-check the result. `DC -1` is `BAD OPER`.

`(` and `)` remain valid operand-addressing punctuation, as in `LDA ($12),Y`.
They are not expression grouping in v1.

Example:

```asm
ERR_1   EQU     %XXXXXXX1
ERR_2   EQU     %XXXXXX1X
COUNT   EQU     10
ADDR    EQU     * - $20
FLAGS   EQU     ERR_1 | ERR_2
```

`EQU` may create a concrete value symbol or a mask-type symbol. A mask-type
symbol carries:

```text
value
care_mask    1 = bit matters, 0 = x/don't-care
width
```

For example, `%XXXXXXX1` is `value=$01`, `care_mask=$01`, `width=8`.
`%XXXXXX1X` is `value=$02`, `care_mask=$02`, `width=8`.
`%11111111` is `value=$FF`, `care_mask=$FF`, `width=8`, kind `VALUE`.

V1 `EQU` expressions should resolve immediately. Do not add forward `EQU`
dependency records until emitted-byte fixups and symbol records are boring.

Hashing can find the names in a forward `EQU`, but it does not finish the job.
`NEXT EQU BASE+1` needs a dependency record, later re-evaluation when `BASE`
appears, wakeups for anything using `NEXT`, cycle detection, and final
width/kind decisions. That is a small dependency solver, not just a fixup hash
lookup.

The implementation should stay W65C02S-sized. An internal RPN backend is
preferred if it keeps the evaluator small, but the source line remains infix.

For v1 mask/logical expressions, `|`, `&`, and `^` require known same-width
operands. A concrete byte or word has a full care mask for its width. A mask has
its recorded care mask. Result kind is `MASK` if either input is `MASK`. When
the result care mask is all ones, the result may normalize to `VALUE`.

Mask care rules:

```text
OR   known if both inputs are known, or either input is known 1
AND  known if both inputs are known, or either input is known 0
XOR  known only if both inputs are known
```

`+` and `-` are for concrete values/addresses in v1. Do not add mask arithmetic.
Mask values are mainly for `EQU` mask constants and `|`, `&`, `^` composition.
A mask-type symbol with don't-care bits used where a concrete byte/address/count
is required should fail clearly.

## Q: Is `ADDR EQU * - $20` a forward `EQU`?

Comment: No. `*` is the current assembly PC/location counter at the point the
expression is evaluated. If the other term is already known, this resolves
immediately:

```asm
ADDR    EQU     * - $20
```

Because `*` is an address, the result is an absolute/word-width value if it
stays in `$0000-$FFFF`. Underflow or overflow is `BAD RANGE`.
Because `*` carries absolute/word width, `DC *` emits a little-endian word for
the current PC. Use `DC <*` or `DC >*` for one-byte low/high PC data.

Concern: This does require the evaluator to support the special `*` term and
simple subtraction. That is still much smaller than forward `EQU` dependency
solving because no later wakeup is needed.

## Q: Where does first ASM output live?

Comment: First implementation should be RAM-session assembly:

```text
emitted bytes: selected target RAM/chosen assembly address
symbol table: RAM session table
fixup table: RAM session table
END: attempts final fixup resolution
END: fails if required fixups remain unresolved
flash/catalog visibility: later, only after explicit seal/export
```

Concern: This keeps v1 as a one-pass emitter plus patch records. Persistent
flash records, public catalog exports, and reset-surviving symbols can be the
next layer after emitted bytes and fixups are boring.

## Q: What RAM records does v1 need?

Comment: Keep the first session tables fixed-size and explicit.

Session state:

```text
asm_pc
start_pc
high_water_pc
line_count
status
sym_count / sym_limit
fix_count / fix_limit
ref_count / ref_limit
report_flags
```

A new RAM ASM session starts at a configured scratch code origin unless the user
supplies an address. Session start and `ORG expr` use the same
PC-setting/range-check path. `*` reads the current `asm_pc`.

Symbol row:

```text
state
hash32
name_len
name_text
value
kind
width
flags
scope_id
def_line
ref_count
first_ref
last_ref
```

Fixup row:

```text
state
target_hash32
target_len
target_text
patch_site
mode
origin / base_after
placeholder_len
flags
line
```

Reference/report row:

```text
state
line
hash32
name_len
name_text
site
mode
result
sym_slot
```

Concern: Hashes find candidates; name text proves identity for user symbols and
fixups. If the fixed tables fill, fail with `BAD SYM` or `BAD FIX`. Do not spill
into flash and do not overwrite neighboring RAM.

The rows are conceptual. Actual W65C02 RAM can be parallel arrays indexed by
slot, as in the current proof, if that keeps the code smaller.

Reference rows are for reports. If the reference table fills in v1, stop with
`BAD FIX` and `TRUNC=YES`.

## Q: How can ASM handle HIMON-scale symbol tables?

Comment: ASM must eventually handle a huge HIMON-scale symbol universe. The RAM
session table is only the current workbench; resident/packed symbol tables are
the scalable library side. A future acceptance test is ASM assembling ASM/HIMON.
That future may need temporary RAM tables, flash workspace, compressed resident
tables, or a mix. V1 does not spend RAM row bytes on that future pressure.
Use layered lookup:

```text
RAM session symbols
resident HIMON/catalog/export symbols
forward fixup if operand mode allows it
```

For a large resident table, use a two-byte `SYM3` prefix key before full
FNV/name proof. `SYM3` packs the first three canonical characters with a base-40
alphabet:

```text
pad/end, A-Z, 0-9, _, ? reserved, . reserved
40^3 = 64000, fits in 16 bits
```

Concern: `SYM3` is not identity. It is only a filter/index. FNV32 plus canonical
text remains the proof. Base-64 needs 18 bits for three characters, so it is not
better for the 3-character/2-byte key. A 5-bit pack is still useful for some
compressed text, but base-40 keeps digits and underscore in the three-character
key. The `?` and `.` codes are used by ASM-local labels, not by global/export
symbol identities.

## Q: What report is required in v1?

Comment: V1 prints a basic report at `END`. On the first error, ASM prints an
error line, prints the compact report, and stops the session. A separate
`REPORT` command can be added later.

Error line:

```text
ASM ERR line status [token/name]
ASM ERR 12 BAD WIDTH $123
ASM ERR 18 BAD MODE ($1234),Y
ASM ERR 21 BAD SYM FOO
ASM ERR 34 BAD FIX TARGET
```

Compact report:

```text
ASM REPORT
STATUS=OK
ERRLINE=0
START=$2000
PC=$2017
HIGH=$2017
BYTES=$0017
LINES=12
SYMS=4/16
FIXUPS=0/8
REFS=9/32
TRUNC=NO
```

Optional sections print only when present:

```text
UNRESOLVED
12 $2001 ABS16 TARGET
18 $2004 REL8 DONE

USED
START $2000 DEF=1 REFS=0
TARGET $2010 DEF=7 REFS=2,5,9

UNUSED
TEMP $2030 DEF=10

RESIDENT
BIO_FTDI_WRITE_BYTE_BLOCK REFS=4
SYS_WRITE_CHAR REFS=8,11
```

Required report facts:

```text
assembly start/high-water PC
current PC
bytes emitted/reserved
line count
symbol/fixup/reference counts and limits
report truncated flag
unresolved fixups
used symbols with line numbers
unused symbols defined in the current session
resident/HIMON symbols referenced by this session
```

Concern: "Unused" in v1 means unused inside this assembly session. Whole-HIMON
unused-symbol analysis, memory policy reports, and exported ref/xref files are
later librarian/report tools.

Line numbers are physical source/session input lines counted from the start of
the assembly session, including blank/comment lines. Only lines that define or
use symbols create reference rows.

Table-full behavior keeps the compact error vocabulary. Do not add `BAD TABLE`
in v1:

```text
symbol table full      BAD SYM
name pool full         BAD SYM
fixup table full       BAD FIX
reference table full   BAD FIX, TRUNC=YES
line too long          BAD LINE
code target overflow   BAD RANGE
```

## Q: What is ASM 2.50 error behavior?

Comment: ASM 2.50 stops on the first error. Interactive/output mode policy can be
decided later; v1 does not keep parsing after an error.

Error vocabulary:

```text
OK
BAD LINE     line too long / unreadable source line
BAD MNEM     unknown operation token where mnemonic expected
BAD DIR      unsupported or bad directive
BAD OPER     malformed operand, extra junk, bad punctuation
BAD MODE     mnemonic does not support that operand class
BAD WIDTH    source spelling or symbol width does not supply required width
BAD RANGE    value known but outside allowed range
BAD SYM      bad name, duplicate definition, missing required name, or local
             label/reference before a global scope
BAD FIX      unresolved or failed fixup at END
```

Trigger examples:

```asm
FOO BAR                 ; BAD MNEM if BAR is not vocabulary
LDA $123                ; BAD WIDTH
LDA 10                  ; BAD WIDTH
LDA ($1234),Y           ; BAD MODE
BRA FAR                 ; BAD RANGE if known and out of rel8
RMB 8,$12               ; BAD RANGE
RMB 3,$1234             ; BAD WIDTH
LDA #$1234              ; BAD RANGE
EQU $12                 ; BAD SYM
FOO EQU BAR             ; BAD SYM if BAR unresolved
FOO EQU $12 / FOO:      ; BAD SYM duplicate
LABEL END               ; BAD SYM
END X                   ; BAD OPER
.LOOP                   ; BAD SYM until a nonlocal label opens local scope
```

## Q: What proof sizes should seed v1?

Comment: The current `asm-v1-core.asm` RAM-session defaults are proof-sized
starting points:

```text
ASM_SYM_MAX         40 symbol rows
ASM_FIX_MAX         96 fixup rows
ASM_REF_MAX         160 report-reference rows
ASM_FIX_NAME_MAX    32 bytes, 31 visible chars plus terminator
ASM_LOCAL_MAX       16 local label rows per active global scope
ASM_LOCAL_NAME_MAX  16 bytes, 15 visible chars plus terminator
ASM_LINE_MAX        63 visible input chars
ASM_CODE_BUF       512 bytes
```

Concern: Treat these as implementation defaults, not permanent language limits.
The language contract is fixed-size session tables that fail clearly when full.

## Q: What remains open after this ASM pass?

Comment: These are deliberately not final v1 decisions yet:

```text
expression grouping parentheses and richer expression features
HBSTR/CSTR/PSTR as DC forms versus standalone directives
local-label report/export polish if needed
rich listing/output/report export format for staged assembly
exact production RAM workspace addresses and table capacities
resident HIMON-scale symbol table record/index format and capacity
```

Concern: Keep these out of `DECISIONS.md` until the rule is boring enough to
implement. The assembler can still move forward with the settled parser,
width, directive, and fixup contracts.

## Q: Should DS allow initialized storage?

Comment: Yes. `DS count` reserves/advances. `DS count, init-list` emits/fills
initialized storage by repeating or truncating the initializer list to exactly
`count` bytes.

The count must be concrete and resolved in v1 because it moves the assembly PC.
Initializer elements are byte-sized in v1.

Examples:

```asm
DS 2,$0D,$0A
DS 4,$00
DS 5,$AA,$55
```

Concern: This is slightly more than "reserve storage", but it is useful for
small monitor data and avoids a second directive just to fill a short pattern.

## Q: How should DC decide byte versus word?

Comment: Use source width and symbol width:

```asm
DC $FF      ; one byte
DC 10       ; one byte, decimal $0A
DC $1234    ; one word, little endian
DC 'A'      ; one byte
DC <ADDR    ; low byte
DC >ADDR    ; high byte
DC ADDR     ; width from ADDR symbol record
DC <ADDR,>ADDR ; two bytes, v1 address-word workaround
```

Decimal `DC` items are byte data in v1. Values outside `$00-$FF` are
`BAD RANGE` unless a later word-data form is added.

Concern: `DC ADDR` is legal only when `ADDR` is known or has a recorded symbol
width. Unknown bare `DC ADDR` is `BAD WIDTH` in v1. Use `DC <ADDR,>ADDR` for an
address word with byte fixups. Do not infer width later from the numeric value.

## Q: What is the ASM 1.90 operand classifier contract?

Comment: ASM 1.90 classifies a mnemonic operand tail into the mode facts the
emitter needs. It is mnemonic-aware, but it does not emit bytes or silently
change source width.

```text
ASM_CLASS_OPERAND
IN   mnemonic row/id and operand tail pointer
OUT  C=1,A=OK with OP result filled
ERR  C=0,A=BAD OPER/BAD MODE/BAD WIDTH/BAD RANGE/BAD FIX/BAD SYM
```

Operand result:

```text
OP_STATE     OK, NEEDS_FIXUP, ERROR
OP_MODE      NONE, ACC, IMM8, IMM_LO8, IMM_HI8, ZP8, ABS16, REL8,
             ZPX, ZPY, ABSX, ABSY, ZP_IND_X, ZP_IND_Y, ZP_IND,
             ABS_IND, ABS_IND_X, BIT_ZP, BIT_ZP_REL
OP_FLAGS     KNOWN, NEEDS_FIXUP, WIDTH_KNOWN, FORCED, FORCE_LO, FORCE_HI
OP_WIDTH     NONE, BYTE, WORD, ZP, ABS, REL8, MASK8, MASK16
OP_VALUE     known value/address
OP_CARE      mask care bits when present
OP_SYM       resolved symbol slot or $FF
OP_AUX       bit number, index register, or small mode detail
OP_NFIX      0, 1, or 2 planned patch records
OP_STATUS    OK or BAD xxx
```

Syntax classes:

```text
blank                         NONE
A                             ACC
#expr                         IMM8
#<symbol or #<atom            IMM_LO8
#>symbol or #>atom            IMM_HI8
expr                          ZP8, ABS16, or REL8 by mnemonic/width
<symbol or <atom              ZP8, low byte selected
>symbol or >atom              ZP8, high byte selected
expr,X                        ZPX or ABSX
expr,Y                        ZPY or ABSY
(expr,X)                      ZP_IND_X
(expr),Y                      ZP_IND_Y
(expr)                        ZP_IND or ABS_IND, mnemonic-dependent
(expr,X) with JMP             ABS_IND_X
bit,expr                      BIT_ZP
bit,expr,target               BIT_ZP_REL
```

Mnemonic-aware rules:

```text
branches force REL8
JSR forces ABS16
RMB/SMB use BIT_ZP
BBR/BBS use BIT_ZP_REL
ordinary unresolved memory operands default to ABS16 only where allowed
```

Accumulator-capable mnemonics accept operandless or explicit `A` forms:

```asm
ASL
ASL A
ROL
ROL A
LSR
LSR A
ROR
ROR A
INC A
DEC A
```

The classifier returns `NONE` for the operandless form and `ACC` for explicit
`A`; the emitter maps both to the accumulator opcode only for mnemonics that
have that form. `LDA A` or `STA A` remain `BAD MODE`.

Single-letter `A` is reserved as the accumulator token in operand context. It is
not treated as a user symbol operand. If a mnemonic does not accept accumulator
mode, `A` is rejected as `BAD MODE`.

`<` selects a byte. `#` selects immediate addressing:

```asm
LDA <FOO      ; read memory at zero-page address low(FOO)
LDA #<FOO     ; load the number low(FOO) into A
```

If `FOO EQU $1234`:

```text
LDA <FOO      -> A5 34
LDA #<FOO     -> A9 34
```

Fixup planning is allowed only when emitted width is already known:

```text
IMM8/IMM_LO8/IMM_HI8              1 byte
ZP8/ZPX/ZPY/ZP_IND_X/ZP_IND_Y/ZP_IND 1 byte
ABS16/ABSX/ABSY/ABS_IND/ABS_IND_X 2 bytes
REL8                              1 byte, range checked when resolved
BIT_ZP                            zp byte may fix up; bit resolves now
BIT_ZP_REL                        zp and/or rel target may fix up; bit resolves now
```

`LDA #FOO` is accepted as an `imm8` fixup because the emitted operand byte has
known width. It emits `A9 FF` and later patches the byte; if `FOO` resolves
outside `$00-$FF`, the fixup fails with `BAD RANGE`.

Concern: A text-only classifier cannot be correct. `BRA FOO` forces relative,
`JMP (FOO)` allows absolute indirect, and ordinary unknown symbol operands may
default to absolute fixups only where the mnemonic allows that path.

## Q: Should HBSTR/CSTR/PSTR be DC forms or directives?

Comment: Open. The first thought was `DC HBSTR'HELLO'`, `DC CSTR'HELLO'`, and
`DC PSTR'HELLO'`. They may instead become directive words:

```asm
HBSTR 'HELLO'
CSTR  'HELLO'
PSTR  'HELLO'
```

Concern: As directives, they join the reserved ASM vocabulary table and make
the line easier to dispatch. As `DC` forms, they keep data definition grouped
under one directive. Park the final choice until the `DC` parser shape is being
implemented.

## Q: What should unresolved operand placeholders be?

Comment: Emit `$FF` placeholder operand bytes for unresolved fixups, not `$00`.
That keeps flash patching friendlier because resolved bytes can be programmed by
clearing `1` bits to `0` bits.

Examples:

```text
JSR FOO -> 20 FF FF
BRA FOO -> 80 FF
```

Concern: `$FF` can be a valid final operand byte. Fixup state must live in an
explicit fixup record; it must not be inferred from the placeholder bytes.

## Q: What happens to unknown symbol operands?

Comment: If the mnemonic does not force another mode, unresolved ordinary
symbols default to absolute fixups:

```asm
LDA FOO      ; unresolved FOO -> absolute opcode plus abs16 fixup
LDA #FOO     ; unresolved FOO -> immediate opcode plus imm8 fixup
JSR FOO      ; forced abs16 fixup
BRA FOO      ; forced rel8 fixup
LDA <FOO     ; explicit low-byte/zp fixup
LDA #<FOO    ; explicit low-byte immediate fixup
```

Concern: If `FOO` later resolves to a zero-page symbol, the earlier `LDA FOO`
must remain absolute. No silent demotion.

## Q: Should ASM validate memory policy?

Comment: Eventually yes. The assembler should know the assembly context. HIMON
builds may use HIMON/system zero page, I/O, and protected regions. User assembly
must not silently claim those same ranges.

Concern: This is future validation machinery, not a v1 blocker. The v1 records
should still preserve enough address/mode/kind information for a later validator
to reject bad targets.

## Q: Can ORG move backward?

Comment: No. `ORG` sets the assembly PC/location counter, but only to the
current PC or forward. It emits no bytes and does not fill skipped addresses.
Moving backward would make the assembler overwrite or reinterpret bytes already
emitted in the current assembly session.

Concern: Do not add a "scratch RAM overwrite" exception. Intentional patching
belongs in explicit data emission or monitor memory-edit behavior, not hidden
inside ordinary `ORG` semantics.

## Q: Should opcode lookup be a flat opcode table or generated from bit patterns?

Comment: Use a mnemonic row table keyed by canonical FNV-1a hash, then let each
row name an emitter family. The operand classifier chooses a mode; the row plus
mode chooses the opcode.

The table is built in alphabetical canonical-token order. Each row stores the
token's FNV-1a hash and dispatch information. V1 may scan that row table
linearly by hash; the sorted order keeps the table reproducible and leaves room
for later faster search.

Conceptual row:

```text
MNEM HASH32 FAMILY     AAA/BASE MODEMASK
LDA  hash  CC01_ZPIND 101      imm,zp,abs,zpx,absx,zpy,absy,zpind...
JSR  hash  FIXED      $20      abs
BBR  hash  BIT_ZP_REL $0F      bit,zp,rel
```

For regular families, generate opcodes from `aaa bbb cc`:

```text
cc=01 opcode = (aaa << 5) | (bbb << 2) | %01
```

For W65C02S `(zp)` additions in that family:

```text
opcode = (aaa << 5) | $12
```

For bit operations:

```text
RMB = $07 + bit*$10
SMB = $87 + bit*$10
BBR = $0F + bit*$10
BBS = $8F + bit*$10
```

Concern: Do not make `aaa bbb cc` the only correctness model. Irregular and
special opcodes stay explicit rows or handlers. The pattern generator is a size
and clarity tool where the silicon encoding is regular.

## Q: Should assembler records use FSB?

Comment: FSB fits assembler-generated flash records well:

```text
formed   record shape is present
sealed   checks passed
buried   old version is obsolete
```

Concern: Do not mark assembler output sealed until its bytes, fixups, pointer
ranges, and collision rules have been checked.

## Q: Should the assembler support BRA islands?

Comment: `BRA islands` are generated branch trampolines for reaching beyond
the signed 8-bit relative branch range. Instead of hand-maintaining a chain like
`$4000 -> $407X -> $40XX -> $41YY -> target`, the assembler or linker would
place small nearby `BRA` hops in safe island slots.

Example shape:

```text
$4000: BRA island_0
...
island_0: BRA island_1
...
island_1: BRA target
```

The useful cases are:

```text
position-ish code that wants to avoid absolute JMP operands
generated long branch support
flash/patch layouts where a nearby two-byte branch is easier to place
controlled filler/alignment zones that can hold trampoline hops
poor-man overlay/linker connection between separately placed code blocks
```

Position-ish code is not fully position-independent 6502 code. It just means a
block can keep more of its internal control flow relative. If the block moves
but its internal layout stays the same, `BRA` hops still mean "go this many
bytes from here", while `JMP $addr` has to be relocated.

Avoiding an absolute operand at the original site can matter when the original
site is early, fixed, or hard to patch. A `JMP $4200` embeds `00 42` in that
instruction. A `BRA island` embeds only a signed nearby offset and lets later
layout machinery decide how the islands reach the true destination.

Flash patching is a special case of this. Flash can usually clear `1 -> 0`
bits, but cannot freely set `0 -> 1` bits without erasing a sector. Rewriting a
16-bit absolute address may require illegal bit transitions. Pre-planned branch
slots can sometimes give the system more legal patch points.

Alignment and filler zones are the cleanest island homes. If the assembler or
linker knows a region is padding, reserved space, or a generated branch-pad
area, it can place `BRA` hops there without hiding control flow inside normal
code.

As a poor-man overlay/linker trick, one module can exit through a known island
slot and another module can be reached by generated hops. That is not a full
relocator, but it is a small native mechanism for connecting separately placed
code blocks.

For conditional far branches, the assembler can use an inverted short branch
over an unconditional island hop:

```text
BNE skip
BRA far_target_island
skip:
```

Concern: Humans should not maintain branch islands by hand. Island placement
needs assembler/linker help, range checking, and a rule for where islands are
legal. The first assembler does not need this; record it as future machinery for
when labels, fixups, and generated code layout are strong enough.

## Q: Should R-YORS use self-modifying code?

Comment: The current preference is no. Self-modifying code is not a general
style goal for R-YORS. It makes dumps harder to trust, hides state inside
instruction bytes, complicates listings and disassembly, and is especially
awkward anywhere flash is involved. Prefer ordinary W65C02S code, zero-page
indirect pointers, tables, small helpers, and explicit record/fixup metadata.

There are still a few places where the idea is worth naming so it does not
keep sneaking back under new names:

```text
load-time fixups      patch a RAM image before it is sealed and run
RAM worker tuning     patch once, then run a tight RAM-only flash worker loop
RAM trampolines       patch a JMP/JSR target after a hash/catalog lookup
ASM scratch pocket    emit a tiny native test sequence in RAM, run it, discard it
```

The clean version of this is usually not "runtime self-modifying code" at all.
It is linking or loading. A relocatable body is copied to RAM, dependency hashes
are resolved, fixup records patch the operand bytes, and only then does the code
become callable. That keeps mutation in the loader/fixup phase instead of
hiding it inside normal execution.

If a future STR8 RAM worker becomes desperate for bytes, a narrowly scoped RAM
specialization may still be reasonable: patch a source pointer, destination
pointer, or branch target once, then run the small loop many times. That is a
size-pressure exception, not a pattern to spread through HIMON.

Concern: Do not use self-modifying code as a shortcut around unclear records,
dependencies, or allocator policy. Do not patch flash-resident code except
through an explicit erase/write/verify path. Do not leave long-lived hidden
patched code without a map/listing/debug story. If mutation is needed, prefer
to make it visible as a fixup table, loader action, or generated RAM body.

## Q: Is hashed `LABEL: MNEMONIC OPERAND` a virtual machine?

Comment: Not for the first path. Treat it as a hash-first assembler question,
not a VM commitment.

The useful near-term shape is:

```text
LABEL:      hash symbol, record current address/value/scope
MNEMONIC    hash word, dispatch to emitter or directive handler
OPERAND     parse literal, address, text, label reference, or fixup
```

For example, `EQU` dispatches to equate handling, while `LDA`, `LDX`, `LDY`,
`JSR`, and friends dispatch to W65C02S emitters. If an operand is not absolute
yet, the assembler records a fixup with enough context to patch it later.

A later proof could reserve a small RAM pocket, emit one assembled instruction
or short sequence there, `JSR` into it, and return to HIMON. That would be a
proof-sized onboard assembler or execution scratchpad. It is still native W65C02S
code, not a virtual machine.

The trap line matters. Once the assembler emits raw native code like
`LDA $7F80`, the CPU will touch `$7F80`; HIMON does not get asked first. Address
trapping only becomes possible if the emitter deliberately outputs watched
forms:

```text
call HIMON memory service
call catalog service by hash
emit BRK token for the monitor to decode
emit bytecode/threaded tokens instead of raw machine instructions
```

Concern: Do not make the first assembler carry VM promises. Keep VM, BRK-token,
or bytecode ideas parked until labels, fixups, body records, and load/run
proofs are already boring. The first useful assembler can be plain native code
plus explicit fixup/dependency records.

## Q: Should labels be allowed to match opcodes?

Comment: No. Treat opcode mnemonics and assembler directives as reserved
assembler vocabulary. A source label should not be able to use the same
canonical text as `JSR`, `LDA`, `DC`, `EQU`, or any other active mnemonic or
directive keyword.

That makes the hash-first parser easier to reason about:

```text
hash first token
if token is mnemonic/directive: parse instruction or directive
else token is a pending definition name; the next token or statement end
     decides whether it is a code/data label, an EQU symbol, or a label-only line
```

`LABEL:` remains the explicit, easy-to-read label definition form. The proof
also accepts the colon-light form `FORWARD JSR STR8`, because `FORWARD` cannot
secretly become an opcode and `JSR JSR` stays unambiguously "mnemonic plus
operand."

Concern: The assembler vocabulary becomes part of source compatibility. If a
future mnemonic, pseudo-op, or directive name is added, any old label with that
canonical text becomes illegal. Keep the keyword set explicit and versioned
when ASM source starts being sealed or stored as records.

## Q: What is the first RAM RJOIN ASM proof?

Comment: The first proof is now a RAM-loaded scripted proof, not a replacement
for the current `A` command:

```text
source: SRC/PROOFS/asm-rjoin-proof-3000.asm
target: make -C SRC asm-rjoin-proof
S19:    SRC/BUILD/s19/asm-rjoin-proof-3000.s19
start:  $3000
```

Make this proof intentionally narrow and verbose:

```text
[LABEL[:]] JSR OPERAND
```

If a leading label is present, with or without the visual `:`, the proof hashes
the label, stores the current PC as the symbol value, and records enough local
metadata to list it again:

```text
hash(LABEL) -> value=current PC, kind=local code label
```

Then `JSR OPERAND` hashes the operand name. Resolution order is local symbols
first, then resident runtime records through `RJOIN`. The output is still
native W65C02S code:

```text
JSR resolved_entry -> 20 lo hi
```

Use an existing resident executable record for the positive test, such as
`BIO_FTDI_WRITE_BYTE_BLOCK`. A future friendlier name such as `BIO_WRITE_CHAR`
should be an alias/export record, not a special parser case.

Verbose transcript target:

```text
ASM RJOIN PROOF $3000
A=MINI ASM; ASM=HASH/RJOIN PROOF
PC=$....

-- SOURCE: START: JSR BIO_FTDI_WRITE_BYTE_BLOCK
  LABEL   START
    H(START)=....
    V=$.... STORE=LOCAL SYMBOL
  OP      JSR
    MODE=ABS OPCODE=$20
  OPERAND BIO_FTDI_WRITE_BYTE_BLOCK
    H(BIO_FTDI_WRITE_BYTE_BLOCK)=$379FE930
    LOCAL=NO RJOIN=FOUND K=$01 EXEC
    E=$.... OK
  EMIT
    SITE=$.... BYTES=20 .. ..
    PC=$....
  HARNESS
    RTS=$....
  RUN
    SEND=!
    OK
```

Failure cases should be different and boring:

```text
-- SOURCE: JSR NO_SUCH_LABEL
  OPERAND NO_SUCH_LABEL
    H(NO_SUCH_LABEL)=....
    LOCAL=NO RJOIN=NO
    ERROR=UNRESOLVED
    EMIT=NO
    PC=$....

-- SOURCE: JSR NON_EXEC_RECORD
  OPERAND NON_EXEC_RECORD
    H(NON_EXEC_RECORD)=....
    LOCAL=FOUND K=$00 NOTEXEC
    ERROR=NOT EXEC
    EMIT=NO
    PC=$....
```

The strict failure tests still do not create `RF` fixups: no placeholder
`JSR $0000`, no partial PC advance, and no half-built code for
`NO_SUCH_LABEL` or `NON_EXEC_RECORD`.

After those tests, the proof deliberately enters an `RF SIM` lane for forward
references:

```text
-- SOURCE: JSR LATER_LABEL
  OPERAND LATER_LABEL
    H(LATER_LABEL)=....
    LOCAL=NO RF=PENDING
  EMIT   PENDING
    NAME=LATER_LABEL
    SITE=$.... BYTES=20 00 00
    PC=$....

-- SOURCE: LATER_LABEL: JSR BIO_FTDI_WRITE_BYTE_BLOCK
  LABEL   LATER_LABEL
    H(LATER_LABEL)=....
    V=$.... STORE=LOCAL SYMBOL
  RF      RESOLVE
    NAME=LATER_LABEL
    SITE=$....
    T=$.... PATCH=OK

RESOLVED RF
  NAME=LATER_LABEL
  H(LATER_LABEL)=....
  SITE=$....
  T=$....
  WIDTH=ABS16

UNRESOLVED RF
  NAME=LABEL2
  H(LABEL2)=$6AC8FC3D
  SITE=$....
  WIDTH=ABS16
```

This is a simulation of the later fixup lifecycle, not yet the final `RF`
record format. It proves the behavior pressure: an unresolved operand can own a
patch site, the PC can keep moving by the instruction width, and a later label
definition can patch the saved site when its hash matches.

The current implementation bootstraps through the same resident joiner path as
`hrec-join-proof`: it finds `THE_JOIN_EXEC_XY`, uses that resident resolver to
join `BIO_FTDI_WRITE_BYTE_BLOCK` and `BIO_FTDI_READ_BYTE_BLOCK`, hashes the
scripted operand text onboard, and emits normal native `JSR` only after the
operand resolves to an executable entry. `NO_SUCH_LABEL` must leave the proof
PC unchanged. `NON_EXEC_RECORD` is a local proof record with the executable bit
clear, so it proves "found but not executable" without requiring the resident
catalog to already contain that exact test record.

After the scripted tests, the proof enters a line loop:

```text
PC=$.... ASM> [LABEL[:]] JSR OPERAND
```

Input is CR/LF terminated. Ctrl-C exits the loop. The parser is intentionally
small: uppercase text, optional leading label with or without `:`, `JSR`, then
one operand token. A first token of `JSR` is treated as the opcode; any other
first token is treated as a label candidate and the next token must be `JSR`.
Label-only lines define a symbol and do not advance PC. Accepted `JSR` lines
advance PC by three bytes whether they resolve immediately or become an `RF
SIM` pending patch. The first table sizes are intentionally proof-sized: 16
proof-local symbols and 8 pending fixups. Ctrl-C exit reports any still-pending
fixups by stored name, hash, patch site, and assumed absolute-16 width.

## Q: When does ASM graduate from QCC to decision?

Comment: When the record bytes, fixup lifecycle, collision rule, and flash
ownership are clear enough to implement without guessing.

Concern: A half-decided assembler format can trap the system into supporting
bad records forever. Keep exploratory formats QCC until the write/verify path
is boring.
