# ASM Test Plan

This is the test plan for ASM proper, the hash-based source-line assembler. It
does not test HIMON's legacy `A` mini-assembler except where a comparison is
explicitly useful.

The plan follows the ASM course map. Early tests prove the source contract and
routine contracts before ASM can assemble real code. Later tests compare emitted
bytes and fixup behavior.

## Test Rule

Test the test before trusting the assembler.

For every sample source file:

```text
first prove the sample follows ASM v1 source rules
then prove the sample's expected result by an independent checker
then feed it to the onboard ASM layer as that layer becomes available
```

The first active sample is:

```text
DOC/GUIDES/ASM/SAMPLES/ASMTEST_3000.asm
```

Current host-side checker:

```text
make -C SRC asmtest-3000-check
```

Current WDC proof build for the same sample:

```text
make -C SRC asmtest-3000-wdc
```

This emits the independent WDC proof artifacts:

```text
SRC/BUILD/lst/asmtest-3000-wdc.lst
SRC/BUILD/map/asmtest-3000-wdc.map
SRC/BUILD/s19/asmtest-3000-wdc.s19
```

For this proof, `ORG $3000` in the source sample owns placement. The WDC linker
is run without a `-c` origin override so later dynamic linking policy can remain
separate.

Current ASM core build:

```text
make -C SRC asm-v1-core
```

## Current Acceptance

Today, before the full assembler exists, `ASMTEST_3000.asm` is a source-language
acceptance sample. It is not yet expected to assemble onboard.

Current checker requirements:

```text
line length <= 63 visible characters
comments stripped outside quotes
statement heads are v1-shaped
labels are legal and unique
operation words are known v1 mnemonics/directives
no local labels
references resolve within the sample
DB seed bytes are valid
seed byte count is 16
seed XOR checksum is $0F
```

Current passing output:

```text
ASMTEST_3000 OK lines=24 max=49 seed=16 checksum=$0F
defs=ASMTEST,COUNT,LOOP,OUT,SEED,SUM
refs=COUNT,LOOP,OUT,SEED,SUM
```

## Test Levels

### ASM 4.00 Test Overview

ASM tests are layered. A lower layer must stay boring while the next layer is
being written.

```text
host sample checks
ASM core build
lexer/token tests
vocabulary lookup tests
statement parser tests
symbol/expression tests
operand classifier tests
emitter/fixup tests
directive tests
report tests
hardware/bench tests
```

### ASM 4.10 Good Samples

Good samples are source files expected to assemble eventually.

Required v1 good sample:

```text
ASMTEST_3000.asm
```

`ASMTEST_3000.asm` must eventually assemble to code at `$3000` that:

```text
writes 16 seed bytes to $3100-$310F
writes XOR checksum $0F to $3110
returns with RTS
```

Future good samples:

```text
ASMTEST_MIN.asm       ORG/EQU/DB/RTS only
ASMTEST_BRANCH.asm    forward/backward branch range proof
ASMTEST_FIXUP.asm     forward abs16/rel8/lo8/hi8 fixups
ASMTEST_BITS.asm      RMB/SMB/BBR/BBS operand forms
```

### ASM 4.20 Bad Samples

Bad samples prove error handling and stop-on-first-error behavior.

Required bad cases:

```text
BAD_LINE       source line longer than 63 visible chars
BAD_SYM        duplicate symbol, reserved word as label, EQU without name
BAD_MNEM       pending label followed by non-vocabulary operation
BAD_DIR        parked directive used in v1
BAD_OPER       missing operand, extra operand, grouping parentheses
BAD_WIDTH      LDA 12, $123, unknown bare DB ADDR
BAD_RANGE      LDA #$1234, branch out of range, bit number 8
BAD_MODE       LDA A, LDA ($1234),Y
BAD_FIX        unresolved required fixup at END
LOCAL_NYI      .LOOP or ?LOOP
```

Each bad sample must document:

```text
expected status
expected error line
whether any bytes were emitted before the error
whether END/report is expected
```

## Layer Gates

### ASM 1.30 Session Spine

Routines under test:

```text
ASM_BEGIN
ASM_ASSEMBLE_LINE
ASM_END
```

Current executable proof:

```text
make -C SRC asm-v1-core
```

Required checks:

```text
ASM_BEGIN opens active session and sets PC
ASM_BEGIN clears counts and status
ASM_ASSEMBLE_LINE counts physical lines
ASM_ASSEMBLE_LINE runs lex, parse, and dispatch for one line
ASM_ASSEMBLE_LINE applies resolved ORG to the ASM PC
ASM_ASSEMBLE_LINE defines resolved EQU symbols
ASM_ASSEMBLE_LINE calls ASM_END for an accepted END statement
line after clean END returns BAD OPER and marks the session failed
ASM_END succeeds with no fixups
ASM_END fails with required unresolved fixups
second ASM_END after clean end is OK
second ASM_END after failure returns stored failure
```

### ASM 1.40 Lexer

Next routine under test:

```text
ASM_NEXT_TOKEN
```

Current executable proof:

```text
make -C SRC asm-v1-core
```

The standalone `START` smoke path now exercises WORD hashing, HEX and DEC
numbers, attached label colon, punctuation, CHAR, and MASK tokens.

Required token fixtures:

```text
blank/comment line -> EOL
LABEL: LDA #1     -> WORD/HAS_COLON, WORD, PUNCT #, NUMBER
%10101010         -> NUMBER BIN width 8
%XXXXXXX1         -> NUMBER MASK width 8, HAS_XMASK
'A' 'a' '''       -> CHAR values $41, $61, $27
; outside quote    -> EOL
; inside quote      -> char/string content later
.LOOP ?LOOP        -> WORD LOCAL_PREFIX, later LOCAL NYI
```

Acceptance:

```text
token kind, subkind, flags, pointer, length, delimiter, and value match fixture
bit 7 is masked before hash
case folds outside quotes only
```

### ASM 1.50 Vocabulary Lookup

Routine under test:

```text
ASM_LOOKUP_WORD
```

Current executable proof:

```text
make -C SRC asm-v1-core
```

The standalone `START` smoke path now checks `LDA`, active `DB`, parked `DC`,
`A`, `START`, and `FOO`. V1 stores the vocabulary row slot as the compact id
until the emitter needs a separate opcode-family id.

Required fixtures:

```text
LDA -> VOC_MNEM
DB  -> VOC_DIR
DC  -> VOC_RESERVED parked
A   -> VOC_REG
START -> VOC_RESERVED parked
FOO -> VOC_NONE with C=0,A=OK
```

Acceptance:

```text
not-found is not an error
reserved/register words cannot become labels
hash collision policy is text-proved when needed
```

### ASM 1.60 Statement Parser

Routines under test:

```text
ASM_PARSE_HEAD
ASM_DISPATCH_STATEMENT
```

Current executable proof:

```text
make -C SRC asm-v1-core
```

The standalone `START` smoke path now checks empty/comment, label-only,
attached colon, mnemonic with tail, colon and no-colon label-plus-mnemonic,
active directives, exact tail starts, the top-level policy errors below, and
the statement heads used by `ASMTEST_3000`.

Required fixtures:

```text
blank/comment         -> EMPTY
LABEL                 -> LABEL_ONLY
LABEL:                -> LABEL_ONLY HAS_COLON
LDA #1                -> MNEM no name
LABEL LDA #1          -> MNEM with name
LABEL: LDA #1         -> MNEM with name/HAS_COLON
NAME EQU $12          -> DIR/EQU with name
SEED DB $52           -> DIR/DB with name
ORG $3000             -> DIR/ORG no name
END                   -> DIR/END no tail
LABEL ORG $3000       -> BAD SYM
LABEL END             -> BAD SYM
END X                 -> BAD OPER
ORG                   -> BAD OPER
NAME EQU              -> BAD OPER
SEED DB               -> BAD OPER
DC $52                -> BAD DIR
START                 -> BAD DIR
A LDA #1              -> BAD SYM
.LOOP                 -> LOCAL NYI
```

`ASMTEST_3000` parser-head fixtures:

```text
        ORG $3000
OUT EQU $3100
SUM EQU $3110
COUNT EQU 16
ASMTEST LDX #0
        STZ SUM
LOOP    LDA SEED,X
        STA OUT,X
        EOR SUM
        STA SUM
        INX
        CPX #COUNT
        BNE LOOP
        RTS
SEED    DB $52,...
        DB $53,...
        END
```

Acceptance:

```text
tail pointer is exact for operand/directive tails
label binding is delayed until dispatch
ASM_ASSEMBLE_LINE is parser/session spine only; no emission yet
one source line is one statement
trailing non-comment junk is BAD OPER
```

### ASM 1.70 Symbol Table

Routines under test:

```text
ASM_LOOKUP_SYMBOL
ASM_BIND_LABEL
ASM_DEFINE_EQU
```

Current executable proof:

```text
make -C SRC asm-v1-core
```

The standalone `START` smoke path now checks label binding, duplicate
rejection, hash-match/text-mismatch continuation, ZP/ABS/VALUE/MASK `EQU` rows,
not-found lookup, and the later parser/expression/line/operand smoke slices.
On success it prints an onboard test report:

```text
ASM 2.10 TESTS OK
 10 BEGIN
 20 LEX LINE
 30 TOKENS
 40 VOCAB
 50 PARSER
 56 EXPR
 58 LINE
 59 EMIT
 5A OPERAND
 5B OPCODE
 60 SYMBOLS
 80 LONG LINE
 90 END
W=$.... SYM=$06 PC=$....
```

Last hardware-proven `ASM 2.00` smoke on 2026-05-24:

```text
L OK=25E8 GO=3000
ASM 2.00 TESTS OK
 ...
 59 EMIT
 5A OPERAND
 ...
W=$E2F4 SYM=$06 PC=$3000
RET A=00 X=00 Y=30 P=77 S=FD NV-BdIZC
```

Current local `ASM 2.10` build expects:

```text
L OK=2A97 GO=3000
ASM 2.10 TESTS OK
 10 BEGIN
 20 LEX LINE
 30 TOKENS
 40 VOCAB
 50 PARSER
 56 EXPR
 58 LINE
 59 EMIT
 5A OPERAND
 5B OPCODE
 60 SYMBOLS
 80 LONG LINE
 90 END
W=$.... SYM=$06 PC=$3000
RET A=00 X=00 Y=30 ... C
```

`PC=$3000` is expected here. The operand-classifier setup exercises
`ORG $3000`, and the later symbol smoke binds against that live assembler PC.

If the board returns before that line, the standalone entry now returns
diagnostic registers:

```text
A = smoke stage
X = ASM_STATUS
Y = ASM_SLOT
```

`A` is the checkpoint that was about to run or was running when the failure
returned:

```text
$10 ASM_BEGIN
$20 first ORG lex
$30 token smoke
$40 vocabulary smoke
$50 parser smoke
$56 ASM_PARSE_EXPR smoke
$58 ASM_ASSEMBLE_LINE smoke
$59 ASM_EMIT_BYTE/ASM_EMIT_WORD_LE smoke
$5A ASM_CLASS_OPERAND smoke
$5B ASM_FIND_OPCODE/ASM_EMIT smoke
$60 symbol smoke
$71 RJOIN joiner lookup
$72 RJOIN BIO write lookup
$80 long-line rejection
$90 ASM_END
```

`X` is `ASM_STATUS`:

```text
$00 OK
$01 BAD_MNEM
$02 BAD_DIR
$03 BAD_OPER
$04 BAD_MODE
$05 BAD_WIDTH
$06 BAD_RANGE
$07 BAD_LINE
$08 BAD_SYM
$09 BAD_FIX
$0A LOCAL_NYI
```

`Y` is `ASM_SLOT`, the last fixed-vocabulary slot touched by lookup. `$FF`
means no vocabulary match. Slot kinds are `MNEM`, `DIR`, `REG`, and `RES`
for reserved/parked words:

| Slot | Slot | Slot | Slot |
| --- | --- | --- | --- |
| $00 A REG | $15 CMP MNEM | $2A LDY MNEM | $3F SEI MNEM |
| $01 ADC MNEM | $16 CPX MNEM | $2B LSR MNEM | $40 SMB MNEM |
| $02 AND MNEM | $17 CPY MNEM | $2C NOP MNEM | $41 STA MNEM |
| $03 ASL MNEM | $18 DB DIR | $2D ORA MNEM | $42 START RES |
| $04 BBR MNEM | $19 DC RES | $2E ORG DIR | $43 STP MNEM |
| $05 BBS MNEM | $1A DEC MNEM | $2F PHA MNEM | $44 STX MNEM |
| $06 BCC MNEM | $1B DEX MNEM | $30 PHP MNEM | $45 STY MNEM |
| $07 BCS MNEM | $1C DEY MNEM | $31 PHX MNEM | $46 STZ MNEM |
| $08 BEQ MNEM | $1D DS DIR | $32 PHY MNEM | $47 TAX MNEM |
| $09 BIT MNEM | $1E END DIR | $33 PLA MNEM | $48 TAY MNEM |
| $0A BMI MNEM | $1F ENTRY RES | $34 PLP MNEM | $49 TRB MNEM |
| $0B BNE MNEM | $20 EOR MNEM | $35 PLX MNEM | $4A TSB MNEM |
| $0C BPL MNEM | $21 EQU DIR | $36 PLY MNEM | $4B TSX MNEM |
| $0D BRA MNEM | $22 EXTRN RES | $37 RMB MNEM | $4C TXA MNEM |
| $0E BRK MNEM | $23 INC MNEM | $38 ROL MNEM | $4D TXS MNEM |
| $0F BVC MNEM | $24 INX MNEM | $39 ROR MNEM | $4E TYA MNEM |
| $10 BVS MNEM | $25 INY MNEM | $3A RTI MNEM | $4F WAI MNEM |
| $11 CLC MNEM | $26 JMP MNEM | $3B RTS MNEM | $50 X REG |
| $12 CLD MNEM | $27 JSR MNEM | $3C SBC MNEM | $51 Y REG |
| $13 CLI MNEM | $28 LDA MNEM | $3D SEC MNEM | |
| $14 CLV MNEM | $29 LDX MNEM | $3E SED MNEM | |

Required fixtures:

```text
LABEL       -> ADDR/ABS current PC
FOO EQU $12 -> ADDR/ZP
FOO EQU $0012 -> ADDR/ABS
COUNT EQU 10 -> VALUE/NONE
ERR EQU %XXXXXXX1 -> MASK/MASK8
duplicate definition -> BAD SYM
hash match but text mismatch -> continue scan
```

Acceptance:

```text
hash finds candidates, text proves identity
not-found is C=0,A=OK
SYM3 is not stored in v1 RAM rows
use counts and first reference lines are recorded when requested
```

### ASM 1.80 Expression Evaluator

Routine under test:

```text
ASM_PARSE_EXPR
```

Current executable proof:

```text
make -C SRC asm-v1-core
```

The standalone `START` smoke path now checks the resolved one-atom foothold
used by `ORG` and `EQU`. Operators, symbols, selectors, and fixups remain
future expression work.

Current fixtures:

```text
10                    -> VALUE/NONE
$12                   -> ADDR/ZP
$0012                 -> ADDR/ABS
'A'                   -> VALUE/BYTE
%XXXXXXX1             -> MASK/MASK8
*                     -> ADDR/ABS current PC
$12 $34               -> BAD OPER
```

Future fixtures:

```text
* - $20               -> ADDR/ABS if in range
ERR_1 | ERR_2         -> MASK or VALUE by care result
FOO unresolved allowed -> UNRESOLVED
<FOO unresolved allowed -> UNRESOLVED FORCE_LO
FOO+1 unresolved      -> BAD SYM or BAD FIX
(1+2)                 -> BAD OPER
```

Acceptance:

```text
evaluation is strictly left-to-right
no precedence
no grouping parentheses
selectors apply to one atom in v1
EQU unresolved is rejected
```

### ASM 1.90 Operand Classifier

Routine under test:

```text
ASM_CLASS_OPERAND
```

Current executable proof:

```text
make -C SRC asm-v1-core
```

The standalone `START` smoke path now classifies the operand forms needed by
the `ASMTEST_3000` statement heads. It records unresolved references as planned
state only; no fixup rows or emitted bytes are created yet.

Current fixtures:

```text
ASL        -> NONE accepted by ASL emitter as accumulator
ASL A      -> ACC
LDA #10    -> IMM8
LDA $12    -> ZP8
LDA $0012  -> ABS16
LDX #0     -> IMM8
CPX #COUNT -> IMM8 from resolved EQU
STZ SUM    -> ABS16 from resolved EQU
EOR SUM    -> ABS16 from resolved EQU
STA SUM    -> ABS16 from resolved EQU
STA OUT,X  -> ABS_X from resolved EQU
LDA SEED,X -> ABS_X unresolved planned
BNE LOOP   -> REL8 unresolved planned
LDA A      -> BAD MODE
LDA 12     -> BAD WIDTH
```

Future fixtures:

```text
LDA FOO unresolved -> ABS16 fixup
LDA <FOO   -> ZP8/lo8
LDA #<FOO  -> IMM_LO8
BRA FOO    -> REL8 fixup
JSR FOO    -> ABS16 fixup
RMB 3,$12  -> BIT_ZP
BBR 3,$12,TARGET -> BIT_ZP_REL
```

Acceptance:

```text
mnemonic-aware forced modes are honored
fixups are planned only when emitted width is known
bit number resolves now and is 0..7
no ZP/ABS promotion or demotion after classification
```

### ASM 2.00 Emission Foundation

Routines under test:

```text
ASM_EMIT_BYTE
ASM_EMIT_WORD_LE
```

Current executable proof:

```text
make -C SRC asm-v1-core
```

The standalone `START` smoke path emits `A2 34 12` into `ASM_CODE_BUF` using
one raw byte emit and one little-endian word emit. It then verifies the stored
bytes, current PC, and high-water PC. This is raw emission only; opcode
selection and fixups begin in later slices.

Acceptance:

```text
emit writes through the current ASM PC
emit advances PC by the byte count written
high-water PC follows the furthest emitted next-PC
word emission is little endian
emit outside an active session is BAD OPER
16-bit PC wrap is BAD RANGE
```

### ASM 2.10 Opcode Emitter

Routines under test:

```text
ASM_FIND_OPCODE
ASM_EMIT
```

Current fixtures:

```text
LDX #0       -> A2 00
STZ $3110    -> 9C 10 31
STA $3100,X  -> 9D 00 31
EOR $3110    -> 4D 10 31
STA $3110    -> 8D 10 31
INX          -> E8
CPX #COUNT   -> E0 10
BNE LOOP     -> D0 ED when LOOP is a resolved backward label
RTS          -> 60
STZ #0       -> BAD MODE at opcode lookup
JSR FOO      -> BAD FIX while fixup rows are not implemented
```

The standalone `START` smoke emits this resolved byte stream into
`ASM_CODE_BUF` and compares every byte:

```text
A2 00 9C 10 31 9D 00 31 4D 10 31 8D 10 31 E8 E0 10 D0 ED 60
```

Future fixtures:

```text
LDA SEED,X   -> BD lo hi after SEED resolves
JSR FOO      -> 20 FF FF with abs16 fixup
```

Acceptance:

```text
known emitted bytes match W65C02S table
irregular opcodes are explicit
aaa-bbb-cc helpers are used only where regular
unresolved operands fail BAD FIX until ASM 2.20 owns fixup rows
```

### ASM 2.20 Fixups

Required fixtures:

```text
abs16 forward label resolves little endian
rel8 forward label resolves with range check
rel8 out of range fails BAD RANGE or BAD FIX
lo8/hi8 selected fixups patch one byte
END fails if required unresolved fixups remain
```

Acceptance:

```text
fixup record state, not placeholder byte, is truth
patch site is exact
branch base is address after branch operand
```

### ASM 2.30 Directives

Required fixtures:

```text
ORG $3000
NAME EQU expr
DB $FF,10,'A',$1234,<ADDR,>ADDR
DS 2,$0D,$0A
END
```

Acceptance:

```text
ORG forward/current only
backward ORG is error
DB emits byte/word by source/symbol width
unknown bare DB ADDR is BAD WIDTH
DS count is resolved and byte-sized initializer repeats/truncates
```

### ASM 2.40 Report

Required report facts:

```text
status
error line/status/token when failed
start/current/high-water PC
bytes emitted/reserved
symbol/fixup/ref counts and limits
unresolved fixups
used symbols with lines
unused session symbols
resident symbols referenced later
```

Acceptance:

```text
first clean END prints compact report
first failure prints error and compact report
report overflow sets TRUNC=YES
```

## ASMTEST_3000 Final Acceptance

When ASM has parser, symbols, expressions, classifier, emitter, directives, and
fixups, `ASMTEST_3000.asm` becomes a full assembly acceptance test.

Expected source:

```text
ORG $3000
OUT EQU $3100
SUM EQU $3110
COUNT EQU 16
...
END
```

Expected behavior after running at `$3000`:

```text
$3100-$310F = 52 2D 59 4F 52 53 20 41 53 4D 20 54 45 53 54 2E
$3110       = 0F
```

Host-side expected image comparison should be added before trusting onboard
emission. The checker should compare emitted bytes, not just behavior, once the
emitter is implemented.

## Regression Protocol

Before committing ASM code:

```text
make -C SRC asm-test
```

Current `asm-test` expands to:

```text
make -C SRC asmtest-3000-check
make -C SRC asm-v1-core
```

As layers are added, extend this list rather than replacing it:

```text
make -C SRC asm-lexer-test
make -C SRC asm-vocab-test
make -C SRC asm-parser-test
make -C SRC asm-symbol-test
make -C SRC asm-expr-test
make -C SRC asm-classifier-test
make -C SRC asm-emitter-test
make -C SRC asm-fixup-test
make -C SRC asm-directive-test
make -C SRC asmtest-3000-assemble
```

Every new test target must be small enough to diagnose without a full symbolic
debugger. Print or record:

```text
test name
line number or fixture id
expected status
actual status
expected bytes or record fields
actual bytes or record fields
```

## Hardware Bench Gate

Do not call ASM hardware-proven until the board has run the emitted code and the
result is captured in the hardware log.

Minimum bench proof for `ASMTEST_3000`:

```text
load ASM
paste/load ASMTEST_3000
END succeeds
RUN $3000
display $3100-$3110
verify seed and checksum
record transcript in HARDWARE_TEST_LOG
```

Until then, mark ASM tests as host-proven or build-proven, not hardware-proven.
