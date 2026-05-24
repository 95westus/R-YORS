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
DC seed bytes are valid
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
ASMTEST_MIN.asm       ORG/EQU/DC/RTS only
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
BAD_WIDTH      LDA 12, $123, unknown bare DC ADDR
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
ASM_ASSEMBLE_LINE later
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

The standalone `START` smoke path now checks `LDA`, `DC`, `A`, `START`, and
`FOO`. V1 stores the vocabulary row slot as the compact id until the emitter
needs a separate opcode-family id.

Required fixtures:

```text
LDA -> VOC_MNEM
DC  -> VOC_DIR
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
attached colon, mnemonic with tail, label-plus-mnemonic, active directives, and
the top-level errors `LABEL ORG`, `END X`, and `START`.

Required fixtures:

```text
blank/comment         -> EMPTY
LABEL                 -> LABEL_ONLY
LABEL:                -> LABEL_ONLY HAS_COLON
LDA #1                -> MNEM no name
LABEL LDA #1          -> MNEM with name
LABEL: LDA #1         -> MNEM with name/HAS_COLON
NAME EQU $12          -> DIR/EQU with name
ORG $3000             -> DIR/ORG no name
END                   -> DIR/END no tail
LABEL ORG $3000       -> BAD SYM
END X                 -> BAD OPER
START                 -> BAD DIR
```

Acceptance:

```text
tail pointer is exact
label binding is delayed until dispatch
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
not-found lookup, and a visible pass line:

```text
ASM 1.70 RJOIN OK W=$.... SYM=$06 PC=$....
```

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

Required fixtures:

```text
10                    -> VALUE/NONE
$12                   -> ADDR/ZP
$0012                 -> ADDR/ABS
'A'                   -> VALUE/BYTE
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

Required fixtures:

```text
ASL        -> NONE accepted by ASL emitter as accumulator
ASL A      -> ACC
LDA #10    -> IMM8
LDA $12    -> ZP8
LDA $0012  -> ABS16
LDA FOO unresolved -> ABS16 fixup
LDA <FOO   -> ZP8/lo8
LDA #<FOO  -> IMM_LO8
BRA FOO    -> REL8 fixup
JSR FOO    -> ABS16 fixup
RMB 3,$12  -> BIT_ZP
BBR 3,$12,TARGET -> BIT_ZP_REL
LDA A      -> BAD MODE
LDA 12     -> BAD WIDTH
```

Acceptance:

```text
mnemonic-aware forced modes are honored
fixups are planned only when emitted width is known
bit number resolves now and is 0..7
no ZP/ABS promotion or demotion after classification
```

### ASM 2.10 Opcode Emitter

Routines under test:

```text
ASM_FIND_OPCODE
ASM_EMIT
```

Required fixtures:

```text
RTS          -> 60
LDX #0       -> A2 00
STZ $3110    -> 9C 10 31
LDA $1234,X  -> BD 34 12
BNE LOOP     -> D0 rr
JSR FOO      -> 20 FF FF if unresolved
```

Acceptance:

```text
known emitted bytes match W65C02S table
irregular opcodes are explicit
aaa-bbb-cc helpers are used only where regular
placeholder bytes are $FF for unresolved fixups
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
DC $FF,10,'A',$1234,<ADDR,>ADDR
DS 2,$0D,$0A
END
```

Acceptance:

```text
ORG forward/current only
backward ORG is error
DC emits byte/word by source/symbol width
unknown bare DC ADDR is BAD WIDTH
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
