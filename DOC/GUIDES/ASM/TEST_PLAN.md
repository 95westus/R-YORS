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
make -C SRC asmtest-6800-check
```

Current WDC proof/check build for the same sample:

```text
make -C SRC asmtest-6800-wdc-check
```

This builds and checks the independent WDC proof artifacts:

```text
SRC/BUILD/lst/asmtest-6800-wdc.lst
SRC/BUILD/map/asmtest-6800-wdc.map
SRC/BUILD/s19/asmtest-6800-wdc.s19
```

For this proof, `ORG $6800` in the source sample owns placement. The WDC linker
is run without a `-c` origin override so later dynamic linking policy can remain
separate.

Current ASM core build:

```text
make -C SRC asm-v1-core
```

Current ASM core proof artifact:

```text
SRC/BUILD/s19/asm-v1-core-2000.s19
```

Current ASM runtime build:

```text
make -C SRC asm-v1-runtime
```

Current ASM runtime artifact:

```text
SRC/BUILD/s19/asm-v1-runtime-2000.s19
```

Current ASM runtime smoke-wrapper build:

```text
make -C SRC asm-v1-runtime-smoke
```

Current ASM runtime smoke-wrapper artifact:

```text
SRC/BUILD/s19/asm-v1-runtime-smoke-2000.s19
```

Current ASM runtime ASMTEST-wrapper build:

```text
make -C SRC asm-v1-runtime-asmtest
```

Current ASM runtime ASMTEST-wrapper artifact:

```text
SRC/BUILD/s19/asm-v1-runtime-asmtest-2000.s19
```

Current ASM runtime paste-driver build:

```text
make -C SRC asm-v1-runtime-paste
```

Current ASM runtime paste-driver artifact:

```text
SRC/BUILD/s19/asm-v1-runtime-paste-2000.s19
```

The ASM core RAM proof links and loads at `$2000`. Its smoke assembly target is
`$7000`, with data targets at `$7100/$7110`, so emitted self-test bytes stay out
of the resident proof image as the core grows. ASM 2.65 adds an onboard
ASMTEST mirror at those non-destructive smoke addresses. `ASMTEST_3000.asm`
remains the independent WDC sample and owns its own pasted-test `ORG $6800`.
The ASM runtime build uses the same source with `ASM_RUNTIME_ONLY` set. It keeps
the callable assembler spine, RJOIN glue, report printer, session tables, and
vocabulary tables, while omitting the standalone smoke ladder, ICO/legacy-REPL
driver, smoke test bodies, and their source/expected-byte strings.
The smoke-wrapper image links a tiny `START` before the runtime, so `G 2000`
is valid for that wrapper image. It assembles `ORG $7000`, `LDA #$0A`,
`LABEL: JSR UTL_HEX_NIBBLE_TO_ASCII`, `STA $7101`, `RTS`, and `END` through
the stripped runtime. It verifies `$7000-$7008` equals
`A9 0A 20 lo hi 8D 01 71 60` with a non-`FFFF` resident call target, then
executes `JSR $7000` and requires `$7101='A'`. This proves source name ->
FNV hash -> resident EXEC join -> emitted operand -> live call return. It
prints `ASM RT OK` on success or `ASM RT FAIL $xx` on failure.

Initial hardware-proven ASM runtime smoke-wrapper on 2026-06-05:

```text
>L G
L S19
L @2000
L OK=2868 GO=2000
ASM RT SMOKE
ASM RT OK

#LOADGO# ENTRY=2000
RET A=09 X=33 Y=09 P=75 S=FD NV-BdIzC
>
```

The pass/fail contract is the printed `ASM RT OK` line. The final `RET`
registers are the monitor's post-return state after the wrapper's print path.

ASM runtime readless trim on 2026-06-05:

```text
make -C SRC asm-test
```

The runtime-only build now omits the ICO-only readline resolver, read pointer
cache, indirect read shim, and `SYS_READ_CSTRING_ECHO_UPPER` hash. The host
gate passes with `asm-v1-runtime-2000.s19` at `$2676` bytes and
`asm-v1-runtime-smoke-2000.s19` at `$283D` bytes.

Hardware-proven readless ASM runtime smoke-wrapper on 2026-06-05:

```text
>L
L S19
L @2000
L OK=283D GO=2000
>G 2000
GO 2000
ASM RT SMOKE
ASM RT OK

#GO# ENTRY=2000
RET A=09 X=0E Y=09 P=75 S=FD NV-BdIzC
>
```

ASM runtime default-buffer trim on 2026-06-05:

```text
make -C SRC asm-test
```

The full ASM core keeps the `$0200` default `ASM_CODE_BUF` used by its smoke
ladder. The runtime-only build now keeps a `$0100` default buffer instead,
saving `$0100` loaded DATA bytes while preserving explicit-PC callers. The host
gate passes with `asm-v1-runtime-2000.s19` at `$2576` bytes and
`asm-v1-runtime-smoke-2000.s19` at `$273D` bytes.

Hardware-proven default-buffer-trim ASM runtime smoke-wrapper on 2026-06-05:

```text
>L G
L S19
L @2000
L OK=273D GO=2000
ASM RT SMOKE
ASM RT OK

#LOADGO# ENTRY=2000
RET A=09 X=0E Y=09 P=75 S=FD NV-BdIzC
>
```

ASM runtime resident-JSR host gate on 2026-06-05:

```text
make -C SRC asm-test
```

Unknown `JSR` operands now try the resident EXEC join after local session
symbol lookup misses. Local labels and EQU names still win first; non-`JSR`
unknowns remain ordinary forward fixups. The smoke-wrapper now assembles
`LABEL: JSR PIN_FTDI_READ_BYTE_NONBLOCK` and checks that the emitted bytes
start with `20` and no longer contain the unresolved `FFFF` operand. The host
gate passes with `asm-v1-runtime-2000.s19` at `$25A2` bytes and
`asm-v1-runtime-smoke-2000.s19` at `$27BF` bytes.

Hardware-proven resident-JSR ASM runtime smoke-wrapper on 2026-06-05:

```text
>L
L S19
L @2000
L OK=27BF GO=2000
>G 2000
GO 2000
ASM RT SMOKE
ASM RT OK

#GO# ENTRY=2000
RET A=09 X=69 Y=09 P=75 S=FD NV-BdIzC
>
```

ASM runtime resident-call execution host gate on 2026-06-05:

```text
make -C SRC asm-test
```

The smoke-wrapper now executes the emitted resident `JSR`, instead of only
checking that the operand is no longer `FFFF`. The host gate passes with
`asm-v1-runtime-2000.s19` at `$25A2` bytes and
`asm-v1-runtime-smoke-2000.s19` at `$27E7` bytes.

Hardware-proven resident-call execution ASM runtime smoke-wrapper on
2026-06-05:

```text
>L G
L S19
L @2000
L OK=27E7 GO=2000
ASM RT SMOKE
ASM RT OK

#LOADGO# ENTRY=2000
RET A=09 X=91 Y=09 P=75 S=FD NV-BdIzC
>
```

Post-run board dump excerpt for the same proof:

```text
>D 7000 71FF
7000: A9 0A 20 B8 E7 8D 01 71 | 60 00 71 4D 10 71 8D 10 | .. ....q`.qM.q..
7100: FF 41 FA 7A EB FC 54 F5 | FF E8 EF 77 6E F7 F8 F3 | .A.z..T....wn...
>
```

Here `$7000-$7008` is the emitted `LDA #$0A`, resident `JSR`, `STA $7101`,
`RTS` program, and `$7101=$41` is the executed resident utility result.

ASM runtime ASMTEST execution host gate on 2026-06-05:

```text
make -C SRC asm-test
```

The stripped ASM runtime now has a separate ASMTEST wrapper. It drives
`ASM_BEGIN`, `ASM_ASSEMBLE_LINE`, and `ASM_END` with the same `$7000` mirror of
`ASMTEST_3000.asm` used by the full-core smoke, compares the emitted
`$7000-$7026` image against the known oracle, executes `JSR $7000`, and verifies
`$7100-$710F` is `R-YORS ASM TEST.` with `$7110=$0F`. The host gate passes with
`asm-v1-runtime-asmtest-2000.s19` at `$28AA` bytes.

Hardware-proven ASM runtime ASMTEST wrapper on 2026-06-05:

```text
BOOT COLD
RAM ZERO OK

HIMON V 00.0605(1413)
>L G
L S19
L @2000
L OK=28AA GO=2000
ASM RT ASMTEST
ASM RT ASMTEST OK

#LOADGO# ENTRY=2000
RET A=11 X=52 Y=11 P=75 S=FD NV-BdIzC
>
```

ASM 2.66 runtime paste-driver host gate on 2026-06-05:

```text
make -C SRC asm-test
```

ASM 2.66 adds a separate paste driver wrapper for the stripped runtime. It
starts an ASM session at `$7000`, reads echoed uppercase lines through the ROM
`SYS_READ_CSTRING_ECHO_UPPER` service, feeds each non-empty line to
`ASM_ASSEMBLE_LINE`, prints `OK PC=$hhhh` after accepted lines, and stops after
an accepted `END` with `ASM RT PASTE OK`. A single `.` line exits without
finalizing; 2.66 hex-only errors print `ERR=$xx PC=$hhhh` and return to HIMON.
This keeps the ASM runtime readless while giving the board a pasteable
front-end again. The host gate passes with
`asm-v1-runtime-paste-2000.s19` at `$2A0A` bytes. The hardware retest should
load as `L OK=2A0A GO=2000`, start with `ASM RT PASTE`, accept pasted ASM
source lines at `ASM> ` prompts, and return after `END`.

Hardware-proven ASM 2.66 runtime paste driver on 2026-06-06:

```text
>L G
L S19
L @2000
L OK=2A0A GO=2000
ASM RT PASTE
ASM> ORG $7000
OK PC=$7000
ASM> OUT EQU $7100
OK PC=$7000
ASM> SUM EQU $7110
OK PC=$7000
ASM> COUNT EQU 16
OK PC=$7000
ASM> ASMTEST LDX #0
OK PC=$7002
ASM> STZ SUM
OK PC=$7005
ASM> LOOP LDA SEED,X
OK PC=$7008
ASM> STA OUT,X
OK PC=$700B
ASM> EOR SUM
OK PC=$700E
ASM> STA SUM
OK PC=$7011
ASM> INX
OK PC=$7012
ASM> CPX #COUNT
OK PC=$7014
ASM> BNE LOOP
OK PC=$7016
ASM> RTS
OK PC=$7017
ASM> SEED DB $52,$2D,$59,$4F,$52,$53,$20,$41
OK PC=$701F
ASM> DB $53,$4D,$20,$54,$45,$53,$54,$2E
OK PC=$7027
ASM> END
OK PC=$7027
ASM RT PASTE OK

#LOADGO# ENTRY=2000
RET A=0F X=F1 Y=0F P=75 S=FD NV-BdIzC
>D 7000 701F
7000: A2 00 9C 10 71 BD 17 70 | 9D 00 71 4D 10 71 8D 10 | ....q..p..qM.q..
7010: 71 E8 E0 10 D0 EF 60 52 | 2D 59 4F 52 53 20 41 53 | q.....`R-YORS AS
>G 7000
GO 7000

#GO# ENTRY=7000
RET A=0F X=10 Y=30 P=77 S=FD NV-BdIZC
>
```

Hardware-proven ASM 2.66 runtime paste resident-write program on 2026-06-06:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7000
OK PC=$7000
ASM> MAIN: LDX #0
OK PC=$7002
ASM> LOOP LDA #$4D
OK PC=$7004
ASM> JSR BIO_FTDI_WRITE_BYTE_BLOCK
OK PC=$7007
ASM> INX
OK PC=$7008
ASM> BNE LOOP
OK PC=$700A
ASM> RTS
OK PC=$700B
ASM> END
OK PC=$700B
ASM RT PASTE OK
>G 7000
GO 7000
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
... 256 total M characters ...
>
```

Hardware-proven ASM 2.67 runtime paste local-precedence program on 2026-06-06:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7000
OK PC=$7000
ASM> BIO_FTDI_WRITE_BYTE_BLOCK: RTS
OK PC=$7001
ASM> JSR BIO_FTDI_WRITE_BYTE_BLOCK
OK PC=$7004
ASM> RTS
OK PC=$7005
ASM> END
OK PC=$7005
ASM RT PASTE OK
>G 7000
GO 7000
>D 7000 FF
7000: 60 20 00 70 60 DF E2 E8 | D0 F8 60 4D 10 71 8D 10 | ` .p`.....`M.q..
7010: 71 E8 E0 10 D0 EF 60 52 | 2D 59 4F 52 53 20 41 53 | q.....`R-YORS AS
7020: 4D 20 54 45 53 54 2E 00 | 00 00 00 00 00 00 00 00 | M TEST..........
... remaining displayed $7030-$70F0 bytes were $00 ...
>
```

Hardware-proven ASM 2.68 runtime paste line-echo sample on 2026-06-06:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM>         ORG $7000
OK PC=$7000
ASM> LINE    EQU $7100
OK PC=$7000
ASM>         BRA MAIN
OK PC=$7002
ASM> DONE    RTS
OK PC=$7003
ASM> MAIN    LDA #$3F
OK PC=$7005
... sample accepted through END ...
ASM>         END
OK PC=$704E
ASM RT PASTE OK
>G 7000
GO 7000
? ?
=> ?
? H
=> H
? HELLO WORLD
=> HELLO WORLD
? .
>
```

Hardware-proven ASM 2.69 runtime paste named-error recovery on 2026-06-06:

```text
ASM>         BRA ECHO
OK PC=$704E
ASM>
ASM> BVF $4FRE
ERR=$03 BAD OPER PC=$704E
ASM>
```

Hardware-proven ASM 2.70 status-table trim on 2026-06-06:

```text
>L G
L S19
L @2000
L OK=2AF6 GO=2000
ASM RT PASTE
... ASM_LINE_ECHO_7000.asm accepted through END ...
ASM RT PASTE OK
>G 7000
GO 7000
? HELLO WORLD!
=> HELLO WORLD!
?
```

## Current Acceptance

`ASMTEST_3000.asm` is now both the source-language acceptance sample and the
first full-source onboard paste proof. ASM 2.62 records a hardware transcript
where the 2.61 resident REPL accepts the sample source, emits the expected
native image at `$6800-$6826`, resolves the forward `SEED` fixup, accepts
`END`, returns `A=$0F/X=$10` after `G 6800`, and captures the post-run
`$6900-$6910` output bytes. This completes the first `ASMTEST_3000` hardware
bench gate.

ASM 2.63 adds the host-side oracle for that proof. The checker now emits the
fixed `ASMTEST_3000` sample image independently, resolves the forward `SEED`
fixup, verifies the exact `$6800-$6826` byte stream and `$6827` end PC, and
checks the expected `$6900-$6910` runtime output bytes.

ASM 2.64 wires the independent WDC proof image into the normal ASM regression
gate. `asmtest-6800-wdc-check` builds `asmtest-6800-wdc.s19` and calls the same
checker with `-S19Path`; the checker validates S-record checksums, the S9 start
address, and the exact `$6800-$6826` payload against the ASMTEST oracle. The
regular `asm-test` target now runs this stronger host gate before building the
ASM core.

ASM 2.65 returns to onboard code work. The standalone ASM core smoke ladder now
has a `$70 ASMTEST` stage that assembles the full `ASMTEST_3000` program shape
through `ASM_ASSEMBLE_LINE`, including the forward `SEED` fixup and the full
16-byte seed. To avoid overwriting the resident `$2000` proof image, this smoke
uses the established non-destructive mirror addresses: `ORG $7000`,
`OUT=$7100`, and `SUM=$7110`. It compares the emitted `$7000-$7026` image and
the `$7027` PC/high-water result on-board before the final long-line and `END`
checks run.

ASM 2.66 moves from wrapper-driven proof to pasteable board workflow. The
runtime paste driver is not part of the stripped ASM runtime body; it is a small
RAM-loaded front-end that owns ROM line input, prompt/output text, and failure
return policy while calling the same `ASM_BEGIN` / `ASM_ASSEMBLE_LINE` spine.
The hardware proof loads `asm-v1-runtime-paste-2000.s19`, accepts the ASMTEST
mirror source through `ASM> ` prompts, finalizes with `ASM RT PASTE OK`, shows
the emitted `$7000` image with the forward `SEED` operand patched to `$7017`,
and runs `G 7000` to `RET A=$0F/X=$10`.
A follow-up hardware proof pastes a smaller live program that calls resident
`BIO_FTDI_WRITE_BYTE_BLOCK`, emits `LDX/LDA/JSR/INX/BNE/RTS` at `$7000`, and
runs it to print 256 `M` characters. That proves the paste path can assemble
and execute a useful resident-call program, not only the ASMTEST oracle.
From this point forward, the line-at-a-time interactive assembler path is
operator-facing `ICO` (Input-Calc-Output). Older proof notes and hardware
transcripts may still say `REPL`; those are left intact as evidence. The
full-core interactive banner now says `ASM 2.65 ICO`; the current host build
marker is `L OK=4A3E GO=2000`.

ASM 2.67 locks down defined session-name precedence over resident EXEC fallback.
The hardware proof pastes a label named `BIO_FTDI_WRITE_BYTE_BLOCK` at `$7000`
before assembling `JSR BIO_FTDI_WRITE_BYTE_BLOCK`; the memory dump shows
`60 20 00 70 60`, so the `JSR` operand points at the session-defined `RTS`.
That proves lookup order is session symbols first and ROM-resident hashed EXEC
catalog only after a local miss. Forward same-name locals remain a separate
ASM v1 policy question.

ASM 2.68 records the first hardware-proven pasteable interactive sample:
`ASM_LINE_ECHO_7000.asm`. It assembles at `$7000`, uses `LINE EQU $7100` for
its input buffer, calls resident `SYS_READ_CSTRING_ECHO_UPPER` for line input,
and writes prompts/echo text through resident `BIO_FTDI_WRITE_BYTE_BLOCK`.
The transcript proves the sample accepts single characters and a longer
`HELLO WORLD` line, echoes each after `=> `, and returns to HIMON on `.`.
This also captures the practical ASM v1 fixup-table lesson: keep pasted bench
toys below the current eight outstanding forward-fixup proof limit.

ASM 2.69 makes paste-driver failures self-describing and recoverable without
changing ASM core status codes. The wrapper still prints the stable hex byte,
but assembly errors now include the mnemonic status name before the PC:
`ERR=$09 BAD FIX PC=$hhhh`, `ERR=$08 BAD SYM PC=$hhhh`, and so on. After the
first ASM error, the wrapper calls `SYS_FLUSH_RX`, opens a fresh `$7000`
session with `ASM_BEGIN`, and drops back to `ASM> ` instead of returning the
rest of a pasted source burst to HIMON. This keeps board transcripts compact
while making table-limit and parser failures readable at the paste prompt. The
host gate passes with `asm-v1-runtime-paste-2000.s19` at `$2B53` bytes. The
hardware transcript proves `ERR=$03 BAD OPER PC=$704E` for an invalid
`BVF $4FRE` line and an immediate return to `ASM> `.

ASM 2.70 keeps the 2.69 paste-driver behavior but trims the status-name printer
from a compare/jump chain into low/high message pointer tables. The host gate
passes with `asm-v1-runtime-paste-2000.s19` at `$2AF6` bytes, down from the
2.69 `$2B53` proof image while preserving named errors and recovery. The
hardware proof loads `L OK=2AF6 GO=2000`, accepts the line-echo sample through
`END`, and echoes `HELLO WORLD!` from the emitted `$7000` program.

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
expected image starts at $6800 and ends at PC $6827
emitted image bytes match the hardware-proven $6800-$6826 stream
runtime output oracle matches $6900-$6910 seed/checksum bytes
optional WDC S19 payload matches the $6800-$6826 image oracle
optional WDC S19 start record is $6800
```

Current passing output:

```text
ASMTEST_3000 OK org=$6800 lines=24 max=49 seed=16 checksum=$0F
defs=ASMTEST,COUNT,LOOP,OUT,SEED,SUM
refs=COUNT,LOOP,OUT,SEED,SUM
image=$6800-$6826 bytes=39 output=$6900-$6910
```

Current WDC-backed passing output adds:

```text
wdc-s19=$6800-$6826 bytes=39 start=$6800
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

`ASMTEST_3000.asm` must eventually assemble to code at `$6800` that:

```text
writes 16 seed bytes to $6900-$690F
writes XOR checksum $0F to $6910
returns with RTS
```

Future good samples:

```text
ASMTEST_MIN.asm       ORG/EQU/DB/RTS only
ASMTEST_BRANCH.asm    forward/backward branch range proof
ASMTEST_FIXUP.asm     forward abs16/rel8/lo8/hi8 fixups
ASMTEST_BITS.asm      RMB/SMB/BBR/BBS operand forms
```

Current pasteable bench toys:

```text
ASM_LINE_ECHO_7000.asm  hardware-proven resident line read/echo sample
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
ORG $7000             -> DIR/ORG no name
END                   -> DIR/END no tail
LABEL ORG $7000       -> BAD SYM
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

Smoke parser-head fixtures adapted from `ASMTEST_3000`:

```text
        ORG $7000
OUT EQU $7100
SUM EQU $7110
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
ASM_ASSEMBLE_LINE is the parser/session spine; dispatch binds labels and emits
mnemonics/data
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
not-found lookup, emitted opcodes, ABS16/REL8 fixup records, DB directive
emission, ORG placement policy, DS reservation/fill/list behavior, compact
report-state facts, and the later parser/expression/line/operand smoke slices.
On success it prints an onboard test report:

```text
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$7000
PC=$700C
HIGH=$700C
BYTES=$000C
LINES=$0006
SYMS=$03/$10
FIXUPS=$00/$08
REFS=$02/$10
TRUNC=NO
USED
ADDR DEF=$0002 REFS=$02 FIRST=$0003
UNUSED
SEED DEF=$0003
BUF DEF=$0004
ASM REPORT
STATUS=$03
ERRLINE=$0001
START=$7000
PC=$7000
HIGH=$7000
BYTES=$0000
LINES=$0001
SYMS=$00/$10
FIXUPS=$00/$08
REFS=$00/$10
TRUNC=NO
ASM REPORT
STATUS=$09
ERRLINE=$0001
START=$7000
PC=$7000
HIGH=$7000
BYTES=$0000
LINES=$0001
SYMS=$00/$10
FIXUPS=$00/$08
REFS=$10/$10
TRUNC=YES
ASM 2.50 TESTS OK
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
 5C FIXUPS
 5D DIRECT
 5E REPORT
 60 SYMBOLS
 80 LONG LINE
 90 END
WARN WARN_DS_WRAP
W=$.... SYM=$06 PC=$7000
```

ASM 2.51 keeps the same smoke ladder and target addresses, but removes ASM's
local FNV multiply body. `ASM_BEGIN` now resolves resident `FNV1A_INIT` and
`FNV1A_UPDATE_A_FAST` through RJOIN, and ASM word hashes use the shared FNV
zero-page contract at `$B0-$B3/$C7-$CA`. The host-built S19 marker is:

```text
L OK=4715 GO=2000
```

This is a significant size and architecture win. ASM 2.50 built at `$4761`;
ASM 2.51 builds at `$4715`, reclaiming `$4C` bytes, 76 bytes net, after paying
for the RJOIN resolution slots, hash constants, and jump shims. More important,
ASM no longer carries a private FNV multiply body for the project-wide hash
path.

Expected onboard success banner after loading a HIMON image with the resident
FNV records is:

```text
ASM 2.51 TESTS OK
```

Hardware proof for 2.51 is still pending.

Hardware result for 2.51 on 2026-05-26: HIMON refreshed correctly and ASM loaded
as `L OK=4715 GO=2000`, but `GO 2000` was operator-interrupted with NMI at
`PC=$264E` after an unexpected delay. That address maps to `ASM_RJ_FIND_ADV`,
the local bootstrap scanner used while finding the first resident joiner, so the
NMI was not conclusive proof of a crash. The 2.52 mitigation caches RJOIN/FNV
resolution and starts the local bootstrap scan at `$C000` instead of `$8000`.
This keeps the resident FNV win while removing repeated full-ROM scans from the
smoke ladder and REPL loop.

ASM 2.52 expected host-built S19 marker:

```text
L OK=472D GO=2000
```

Expected onboard success banner:

```text
ASM 2.52 TESTS OK
```

ASM 2.53 keeps the 2.52 cached resident-FNV bootstrap, but adds bench-visible
progress output to the standalone smoke ladder. The first successful write-side
checkpoint is printed as soon as the resident BIO writer is known, then each
smoke stage is printed before it runs. The final pass printer no longer repeats
the whole ladder, so the serial output is both live and still compact.

ASM 2.53 expected host-built S19 marker:

```text
L OK=474E GO=2000
```

Expected onboard progress shape:

```text
 00 RJOIN
ASM 2.53 RUN
 10 BEGIN
 20 LEX LINE
...
 90 END
ASM 2.53 TESTS OK
```

The live progress pass builds at `$474E`, a `$21` byte increase over 2.52's
`$472D`, keeping most of the resident FNV size recovery while making a stuck
board show the last completed checkpoint.

Hardware result for 2.53 on 2026-05-26: progress reached `30 TOKENS`, then the
board reported `BRK 00 PC=0002`. The first suspicion was that
`ASM_SMOKE_TOKENS` depended on lexer state from the previous `20 LEX LINE`
stage, because the new live progress print between stages uses scratch ZP
before tokenization begins.

ASM 2.54 makes `ASM_SMOKE_TOKENS` re-lex its own `ORG $7000` input before
reading tokens, removing that cross-stage state dependency while keeping live
progress enabled.

ASM 2.54 expected host-built S19 marker:

```text
L OK=4757 GO=2000
```

Expected onboard progress shape:

```text
 00 RJOIN
ASM 2.54 RUN
 10 BEGIN
 20 LEX LINE
 30 TOKENS
 40 VOCAB
...
ASM 2.54 TESTS OK
```

Hardware result for 2.54 on 2026-05-26: progress again reached `30 TOKENS`,
then reported `BRK 00 PC=0002`. That disproves the lexer-state theory. The
better explanation is that `ASM_SMOKE_TOKENS` did pass far enough to parse
decimal `#1`; decimal parsing uses `ASM_TMP1`, but the RJOIN BIO-write entry
was cached in `ASM_TMP1` as well. The next progress print, `40 VOCAB`, then
jumped through a clobbered writer pointer and landed at `$0000`.

ASM 2.55 moves the resident joiner and BIO writer entries out of scratch ZP
and into persistent ASM data, matching the already-persistent resident FNV
entries. `ASM_RJOIN_INIT` also validates that cached high bytes are nonzero
before accepting `ASM_RJ_READY`.

ASM 2.55 expected host-built S19 marker:

```text
L OK=4775 GO=2000
```

Expected onboard progress shape:

```text
 00 RJOIN
ASM 2.55 RUN
 10 BEGIN
 20 LEX LINE
 30 TOKENS
 40 VOCAB
...
ASM 2.55 TESTS OK
```

Hardware-proven `ASM 2.55` persistent-RJOIN smoke on 2026-05-26:

```text
L OK=4775 GO=2000
ASM 2.55 RUN
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
 5C FIXUPS
 5D DIRECT
 5E REPORT
ASM REPORT
STATUS=OK
START=$7000
PC=$700C
BYTES=$000C
REFS=$02/$10
TRUNC=NO
 60 SYMBOLS
 80 LONG LINE
 90 END
ASM 2.55 TESTS OK
WARN WARN_DS_WRAP
W=$E2DF SYM=$06 PC=$7000
```

`G 2184` against HIMON `00.0525(2256)` returned immediately because the REPL
asked RJOIN for `SYS_READ_CSTRING_EDIT_ECHO_UPPER`, but that editable readline
service was not resident in HIMON. ASM 2.56 switches the REPL to
`SYS_READ_CSTRING_ECHO_UPPER` (`$E2DD10AF`), which HIMON now publishes as a
compact EXEC+TEXT row named `READ LINE` pointing at `HIM_READ_LINE_ECHO_UPPER`.
If the read service is still missing, ASM prints `READ=$0B` instead of silently
returning.

ASM 2.56 expected host-built S19 marker:

```text
L OK=4784 GO=2000
```

Expected onboard progress shape:

```text
 00 RJOIN
ASM 2.56 RUN
 10 BEGIN
 20 LEX LINE
 30 TOKENS
 40 VOCAB
...
ASM 2.56 TESTS OK
```

Hardware-proven `ASM 2.56` resident-readline smoke on 2026-05-26:

```text
HIMON V 00.0525(2347)
>#
HASH     ENTRY K TEXT
...
A9AF15F7 DE77 05 HASH ACQUIRE
4B9AEE1E E0FC 05 HASH OPEN
A8802314 E176 05 HASH MIX
...
E2DD10AF D4C1 05 READ LINE
B0051A80 C000 03 HIMON: V 00.0525(2347)
A2AD0E18 F000 03 STR8: BOOTLOADER
>L G
L S19
L @2000
L OK=4784 GO=2000
 00 RJOIN
ASM 2.56 RUN
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
 5C FIXUPS
 5D DIRECT
 5E REPORT
ASM REPORT
STATUS=OK
START=$7000
PC=$700C
BYTES=$000C
REFS=$02/$10
TRUNC=NO
 60 SYMBOLS
 80 LONG LINE
 90 END
ASM 2.56 TESTS OK
WARN WARN_DS_WRAP
W=$E2DF SYM=$06 PC=$7000
```

The 2.56 REPL entry/readline proof also reached the prompt and accepted typed
lines through resident `READ LINE`:

```text
>G 2184
GO 2184
ASM 2.56 REPL
ASM> LDA #$FF
OK PC=$7000
ASM> LABEL:
OK PC=$7000
ASM> LDA LABEL
OK PC=$7000
ASM> ?
ERR=$03 PC=$7000
ASM> TXZ
OK PC=$7000
```

This proves REPL entry, prompt output, resident line input, and error feedback.
It is not yet an emission proof: `LDA #$FF` did not advance PC or print bytes in
this run. That gap is fixed in ASM 2.58.

ASM 2.57 adds ASM-side support for the future seed vector pocket. During
`ASM_RJOIN_INIT`, ASM first checks `$FFF8/$FFF9` for a `HASH ACQUIRE` pointer.
It accepts the seed only when the high byte is ROM-ish (`>= $C0`) and the
pointer is not `$FFFF`, then verifies it by resolving `THE_JOIN_EXEC_XY` through
that seeded joiner. If the seed is absent, blank, non-ROM-ish, or cannot resolve
the joiner hash, ASM falls back to the existing local scanner. HIMON does not
stamp the seed pocket yet; this is ASM-only readiness for the later HIMON/STR8
upgrade. The guarded seed path costs `$29` bytes over ASM 2.56 while the scanner
fallback remains present.

ASM 2.57 expected host-built S19 marker:

```text
L OK=47AD GO=2000
```

Expected onboard progress shape:

```text
 00 RJOIN
ASM 2.57 RUN
 10 BEGIN
 20 LEX LINE
 30 TOKENS
 40 VOCAB
...
ASM 2.57 TESTS OK
```

Hardware-proven `ASM 2.57` seed-pocket guard/fallback smoke on 2026-05-26:

```text
HIMON V 00.0526(0002)
>L G
L S19
L @2000
L OK=47AD GO=2000
 00 RJOIN
ASM 2.57 RUN
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
 5C FIXUPS
 5D DIRECT
 5E REPORT
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$7000
PC=$700C
HIGH=$700C
BYTES=$000C
LINES=$0006
SYMS=$03/$10
FIXUPS=$00/$08
REFS=$02/$10
TRUNC=NO
USED
ADDR DEF=$0002 REFS=$02 FIRST=$0003
UNUSED
SEED DEF=$0003
BUF DEF=$0004
ASM REPORT
STATUS=$03
ERRLINE=$0001
START=$7000
PC=$7000
HIGH=$7000
BYTES=$0000
LINES=$0001
SYMS=$00/$10
FIXUPS=$00/$08
REFS=$00/$10
TRUNC=NO
ASM REPORT
STATUS=$09
ERRLINE=$0001
START=$7000
PC=$7000
HIGH=$7000
BYTES=$0000
LINES=$0001
SYMS=$00/$10
FIXUPS=$00/$08
REFS=$10/$10
TRUNC=YES
 60 SYMBOLS
 80 LONG LINE
 90 END
ASM 2.57 TESTS OK
WARN WARN_DS_WRAP
W=$E2DF SYM=$06 PC=$7000

#LOADGO# ENTRY=2000
RET A=00 X=00 Y=70 P=77 S=FD NV-BdIZC
```

ASM 2.58 completes the single-line REPL path by letting
`ASM_DISPATCH_STATEMENT` bind label-only statements, bind label+mnemonic
statements before emission, and call `ASM_EMIT` for mnemonic statements. The
line smoke now proves `LABEL LDA #1` emits `$A9 $01` and advances PC to
`$7002`, so the onboard REPL should report emitted bytes for typed instructions.
This costs `$38` bytes over ASM 2.57.

ASM 2.58 expected host-built S19 marker:

```text
L OK=47E5 GO=2000
```

Expected REPL shape:

```text
>G 2184
GO 2184
ASM 2.58 REPL
ASM> LDA #$FF
OK PC=$7002 BYTES= A9 FF
ASM> ORG $7002
OK PC=$7002
ASM> LDA #$FF
OK PC=$7004 BYTES= A9 FF
```

Hardware-proven `ASM 2.58` dispatch-emission smoke on 2026-05-26:

```text
HIMON V 00.0526(0002)
>L G
L S19
L @2000
L OK=47E5 GO=2000
 00 RJOIN
ASM 2.58 RUN
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
 5C FIXUPS
 5D DIRECT
 5E REPORT
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$7000
PC=$700C
HIGH=$700C
BYTES=$000C
LINES=$0006
SYMS=$03/$10
FIXUPS=$00/$08
REFS=$02/$10
TRUNC=NO
USED
ADDR DEF=$0002 REFS=$02 FIRST=$0003
UNUSED
SEED DEF=$0003
BUF DEF=$0004
ASM REPORT
STATUS=$03
ERRLINE=$0001
START=$7000
PC=$7000
HIGH=$7000
BYTES=$0000
LINES=$0001
SYMS=$00/$10
FIXUPS=$00/$08
REFS=$00/$10
TRUNC=NO
ASM REPORT
STATUS=$09
ERRLINE=$0001
START=$7000
PC=$7000
HIGH=$7000
BYTES=$0000
LINES=$0001
SYMS=$00/$10
FIXUPS=$00/$08
REFS=$10/$10
TRUNC=YES
 60 SYMBOLS
 80 LONG LINE
 90 END
ASM 2.58 TESTS OK
WARN WARN_DS_WRAP
W=$E2DF SYM=$06 PC=$7000

#LOADGO# ENTRY=2000
RET A=00 X=00 Y=70 P=77 S=FD NV-BdIZC
```

The same run proves that `START` is still a parked/reserved directive name in
v1 grammar, not a free label:

```text
>G 2184
GO 2184
ASM 2.58 REPL
ASM> ORG $7000
OK PC=$7000
ASM> LABEL:
OK PC=$7000
ASM> START
ERR=$02 PC=$7000
ASM> START LDA #$4D
ERR=$02 PC=$7000
```

ASM 2.59 fixes the REPL byte display and adds `LDY #imm8` emission. The byte
display bug was not in the emitter: `ASM_REPL_PRINT_BYTES` kept its display
pointer in normal DATA and then used 65C02 `(ptr),Y`, which only reads a
zero-page pointer. It now copies the old PC into the ASM zero-page emit pointer
before reading emitted bytes. The opcode smoke now includes `LDY #$4D` and
expects `$A0 $4D`. This costs `$2D` bytes over ASM 2.58.

ASM 2.59 expected host-built S19 marker:

```text
L OK=4812 GO=2000
```

Expected REPL shape:

```text
>G 2184
GO 2184
ASM 2.59 REPL
ASM> MAIN1: LDA #$FF
OK PC=$7002 BYTES= A9 FF
ASM> MAIN2 LDY #$4D
OK PC=$7004 BYTES= A0 4D
```

Hardware-proven `ASM 2.59` REPL byte-display, LDY, and forward-fixup proof on
2026-05-26:

```text
>L
L S19
L @2000
L OK=4812 GO=2000
>G 2184
GO 2184
ASM 2.59 REPL
ASM> ORG $7000
OK PC=$7000
ASM> LDA W3
OK PC=$7003 BYTES= AD FF FF
ASM> W3: DB $4D
OK PC=$7004 BYTES= 4D
```

ASM 2.60 makes resolved fixups visible in the REPL. When a line defines a
symbol and wakes pending fixups, the resolver records the number of patches and
the last patched site. The REPL prints the last site as `FIX=$hhhh` on the same
OK line. The ABS16 fixup smoke now also asserts that a bind recorded one
resolved fixup and the expected patch site. This costs `$5E` bytes over ASM
2.59.

ASM 2.60 expected host-built S19 marker:

```text
L OK=4870 GO=2000
```

Expected REPL shape:

```text
>G 2184
GO 2184
ASM 2.60 REPL
ASM> ORG $7000
OK PC=$7000
ASM> LDA W3
OK PC=$7003 BYTES= AD FF FF
ASM> W3: DB $4D
OK PC=$7004 BYTES= 4D FIX=$7001
```

Hardware-proven `ASM 2.60` fixup-site REPL proof on 2026-05-26:

```text
L S19
L @2000
L OK=4870 GO=2000
>G 2184
GO 2184
ASM 2.60 REPL
ASM> ORG $7000
OK PC=$7000
ASM> LDA W3
OK PC=$7003 BYTES= AD FF FF
ASM> LDY #$0E
OK PC=$7005 BYTES= A0 0E
ASM> W3 DB $4D
OK PC=$7006 BYTES= 4D FIX=$7001
```

ASM 2.61 makes PC-bound label definitions explicit in the REPL. When an
accepted line binds a label to the current PC, the OK line now prints
`DEF=$hhhh` using the statement's pre-assembly PC, before any resolved fixup
site. This makes `W3 DB $4D` report both the byte written and the address bound
to `W3`, instead of requiring the operator to infer it from the previous prompt.
The display reuses the existing `DEF=$` report string and costs `$20` bytes
over ASM 2.60.

ASM 2.61 expected host-built S19 marker:

```text
L OK=4890 GO=2000
```

Expected REPL shape:

```text
>G 2184
GO 2184
ASM 2.61 REPL
ASM> ORG $7000
OK PC=$7000
ASM> LDA W3
OK PC=$7003 BYTES= AD FF FF
ASM> LDY #$0E
OK PC=$7005 BYTES= A0 0E
ASM> W3 DB $4D
OK PC=$7006 BYTES= 4D DEF=$7005 FIX=$7001
```

Hardware-proven `ASM 2.61` PC-definition REPL proof on 2026-05-26:

```text
L S19
L @2000
L OK=4890 GO=2000
>G 2184
GO 2184
ASM 2.61 REPL
ASM> ORG $7000
OK PC=$7000
ASM> LDA #$4D
OK PC=$7002 BYTES= A9 4D
ASM> LDY FOO
ERR=$04 PC=$7002
ASM> FOO: DB $7E
OK PC=$7003 BYTES= 7E DEF=$7002
ASM> LDA FOO
OK PC=$7006 BYTES= AD 02 70
ASM> LDA POO
OK PC=$7009 BYTES= AD FF FF
ASM> POO LDA QQQ
OK PC=$700C BYTES= AD FF FF DEF=$7009 FIX=$7007
```

Resident-image hardware proof for `asm-v1-resident-2000.s19` on 2026-06-01:

```text
HIMON V 00.0601(1253)
>L G
L S19
L @2000
L OK=2B82 GO=2000
ASM 2.61 REPL
ASM> ORG $7000
OK PC=$7000
ASM> LDA #$4D
OK PC=$7002 BYTES= A9 4D
ASM> FOO: DB $7E
OK PC=$7003 BYTES= 7E DEF=$7002
ASM> LDA FOO
OK PC=$7006 BYTES= AD 02 70
ASM>
```

This proves the lean resident wrapper, without the standalone smoke ladder,
enters the same REPL path at `$2000` and keeps the 2.61 emission/definition/
symbol-resolution behavior.

`LDY FOO` is expected to report bad mode in ASM 2.61 because the current `LDY`
opcode path only accepts immediate mode. The proof of this slice is the
following `FOO: DB $7E` line, which makes the PC-bound definition explicit as
`DEF=$7002`.

The same session also proves that a no-colon `label mnemonic` line binds the
label before emitting the instruction. `POO LDA QQQ` binds `POO` at `$7009`,
resolves the earlier `LDA POO` operand at patch site `$7007`, and still emits a
new unresolved absolute `LDA QQQ` as `AD FF FF`.

ASM 2.62 is a bench-proof slice on the existing 2.61 resident REPL path, not a
new code banner. On 2026-06-05, the operator pasted the full
`ASMTEST_3000.asm` source into `ASM 2.61 REPL`; comments and blank lines were
accepted, first pristine `ORG $6800` established the sample origin, and the
complete sample assembled through `END` with final `PC=$6827`. The emitted code
dump at `$6800-$683F` shows the expected bytes:

```text
6800: A2 00 9C 10 69 BD 17 68 | 9D 00 69 4D 10 69 8D 10
6810: 69 E8 E0 10 D0 EF 60 52 | 2D 59 4F 52 53 20 41 53
6820: 4D 20 54 45 53 54 2E 00 | ...
```

The forward `SEED` fixup first emitted `BD FF FF`, then `SEED DB ...` reported
`DEF=$6817 FIX=$6806`; the final dump confirms the operand was patched to
`17 68`. `G 6800` returned `A=0F X=10`, matching the expected checksum and seed
byte count. The transcript is recorded in `DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`.
A follow-up `$6800-$6FFF` display captures `$6900-$690F` as the 16 expected seed
bytes and `$6910=$0F`, completing the `ASMTEST_3000` hardware bench gate.

ASM 2.65 is the next code-bearing slice after that proof. It bumps the visible
standalone and interactive banners to `ASM 2.65`, adds a `$70 ASMTEST` smoke checkpoint,
and assembles the ASMTEST program shape on-board at `$7000` with output targets
at `$7100/$7110`. This keeps the smoke non-destructive while proving the same
line-by-line assembler path, forward `SEED` fixup, 16-byte seed payload, emitted
image comparison, and `$7027` end PC inside the ASM core.

ASM 2.65 expected host-built S19 marker:

```text
L OK=4A13 GO=2000
```

Hardware note for 2026-06-05: an earlier `L OK=49FB GO=2000` 2.65 image
reached `$70 ASMTEST` and failed with `S=$70 X=$00 Y=$02`; that failed bench
attempt is logged in `DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`. The corrected
stage-70 tail flow rebuilds as the `L OK=4A13` image above.

Hardware-proven `ASM 2.65` onboard ASMTEST smoke on 2026-06-05:

```text
L OK=4A13 GO=2000
ASM 2.65 RUN
 60 SYMBOLS
 70 ASMTEST
 80 LONG LINE
 90 END
ASM 2.65 TESTS OK
W=$E2DF SYM=$00 PC=$6813
RET A=00 X=13 Y=68
```

Expected onboard progress shape:

```text
ASM 2.65 RUN
 10 BEGIN
 ...
 60 SYMBOLS
 70 ASMTEST
 80 LONG LINE
 90 END
ASM 2.65 TESTS OK
```

Hardware-proven `ASM 2.50` relocated-target smoke on 2026-05-26:

```text
L G
L S19
L @2000
L OK=4761 GO=2000
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$7000
PC=$700C
HIGH=$700C
BYTES=$000C
LINES=$0006
SYMS=$03/$10
FIXUPS=$00/$08
REFS=$02/$10
TRUNC=NO
USED
ADDR DEF=$0002 REFS=$02 FIRST=$0003
UNUSED
SEED DEF=$0003
BUF DEF=$0004
ASM REPORT
STATUS=$03
ERRLINE=$0001
START=$7000
PC=$7000
HIGH=$7000
BYTES=$0000
LINES=$0001
SYMS=$00/$10
FIXUPS=$00/$08
REFS=$00/$10
TRUNC=NO
ASM REPORT
STATUS=$09
ERRLINE=$0001
START=$7000
PC=$7000
HIGH=$7000
BYTES=$0000
LINES=$0001
SYMS=$00/$10
FIXUPS=$00/$08
REFS=$10/$10
TRUNC=YES
ASM 2.50 TESTS OK
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
 5C FIXUPS
 5D DIRECT
 5E REPORT
 60 SYMBOLS
 80 LONG LINE
 90 END
WARN WARN_DS_WRAP
W=$E2F4 SYM=$06 PC=$7000
>
```

The standalone `START` path remains the deterministic smoke ladder. The
separate `ASM_REPL` entry is the ICO path and uses resident
`SYS_READ_CSTRING_ECHO_UPPER` through RJOIN, so pasted lines, backspace,
Ctrl-C, CR/LF, and uppercase handling come from the ROM readline service.
`ASM_REPL=$2184` is the remaining interactive bench proof.
A minimal sequence for one-line feedback is:

```text
G 2184
ASM 2.56 REPL
ASM> LDA #1
OK PC=$7002 BYTES= A9 01
ASM> STA $7100
OK PC=$7005 BYTES= 8D 00 71
ASM> .
BYE
```

Hardware-proven `ASM 2.47` def-line/UNUSED-row smoke on 2026-05-26:

The software-built S19 marker for this image is `L OK=4499 GO=2000`. The board
proof below ran the already-loaded image with `GO 2000`.

```text
GO 2000
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$6800
PC=$680C
HIGH=$680C
BYTES=$000C
LINES=$0006
SYMS=$03/$10
FIXUPS=$00/$08
REFS=$02/$10
TRUNC=NO
USED
ADDR DEF=$0002 REFS=$02 FIRST=$0003
UNUSED
SEED DEF=$0003
BUF DEF=$0004
ASM REPORT
STATUS=$03
ERRLINE=$0001
START=$6800
PC=$6800
HIGH=$6800
BYTES=$0000
LINES=$0001
SYMS=$00/$10
FIXUPS=$00/$08
REFS=$00/$10
TRUNC=NO
ASM REPORT
STATUS=$09
ERRLINE=$0001
START=$6800
PC=$6800
HIGH=$6800
BYTES=$0000
LINES=$0001
SYMS=$00/$10
FIXUPS=$00/$08
REFS=$10/$10
TRUNC=YES
ASM 2.47 TESTS OK
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
 5C FIXUPS
 5D DIRECT
 5E REPORT
 60 SYMBOLS
 80 LONG LINE
 90 END
WARN WARN_DS_WRAP
W=$E2F4 SYM=$06 PC=$6800

#GO# ENTRY=2000
RET A=00 X=00 Y=68 P=77 S=FD NV-BdIZC
>
```

`ASM 2.46/2.47` records the definition line for each session symbol, enriches
`USED` rows with `DEF=$....`, and prints the first compact `UNUSED` section.
The report fixture now proves `ADDR` was defined on line 2 and used on line 3,
while `SEED` and `BUF` are session symbols defined on lines 3 and 4 but not
referenced later.

Hardware-proven `ASM 2.45` report-reference/USED-row smoke on 2026-05-26:

```text
>L G
L S19
L @2000
L OK=43B4 GO=2000
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$6800
PC=$680C
HIGH=$680C
BYTES=$000C
LINES=$0006
SYMS=$03/$10
FIXUPS=$00/$08
REFS=$02/$10
TRUNC=NO
USED
ADDR REFS=$02 FIRST=$0003
ASM REPORT
STATUS=$03
ERRLINE=$0001
START=$6800
PC=$6800
HIGH=$6800
BYTES=$0000
LINES=$0001
SYMS=$00/$10
FIXUPS=$00/$08
REFS=$00/$10
TRUNC=NO
ASM REPORT
STATUS=$09
ERRLINE=$0001
START=$6800
PC=$6800
HIGH=$6800
BYTES=$0000
LINES=$0001
SYMS=$00/$10
FIXUPS=$00/$08
REFS=$10/$10
TRUNC=YES
ASM 2.45 TESTS OK
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
 5C FIXUPS
 5D DIRECT
 5E REPORT
 60 SYMBOLS
 80 LONG LINE
 90 END
WARN WARN_DS_WRAP
W=$E2F4 SYM=$06 PC=$6800

#LOADGO# ENTRY=2000
RET A=00 X=00 Y=68 P=77 S=FD NV-BdIZC
>
```

`ASM 2.44/2.45` wires symbol mark-use lookup into the report reference budget
and prints the first compact `USED` section. The clean report fixture references
`ADDR` twice from source line 3, so the report now prints `REFS=$02/$10` and
`ADDR REFS=$02 FIRST=$0003`. The later overflow proof still uses the report
reference counter to prove `TRUNC=YES`/`BAD_FIX`.

Hardware-proven `ASM 2.43` report overflow smoke on 2026-05-26:

```text
L @2000
L OK=42F8 GO=2000
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$6800
PC=$680C
HIGH=$680C
BYTES=$000C
LINES=$0006
SYMS=$03/$10
FIXUPS=$00/$08
REFS=$00/$10
TRUNC=NO
ASM REPORT
STATUS=$03
ERRLINE=$0001
START=$6800
PC=$6800
HIGH=$6800
BYTES=$0000
LINES=$0001
SYMS=$00/$10
FIXUPS=$00/$08
REFS=$00/$10
TRUNC=NO
ASM REPORT
STATUS=$09
ERRLINE=$0001
START=$6800
PC=$6800
HIGH=$6800
BYTES=$0000
LINES=$0001
SYMS=$00/$10
FIXUPS=$00/$08
REFS=$10/$10
TRUNC=YES
ASM 2.43 TESTS OK
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
 5C FIXUPS
 5D DIRECT
 5E REPORT
 60 SYMBOLS
 80 LONG LINE
 90 END
WARN WARN_DS_WRAP
W=$E2F4 SYM=$06 PC=$6800
RET A=00 X=00 Y=68 P=77 S=FD NV-BdIZC
```

`ASM 2.43` replaces the manual trunc-flag report with a real report-reference
counter overflow trigger. `ASM_REPORT_NOTE_REF` records report references until
`REFS=$10/$10`, then the next reference sets `TRUNC`, fails with `BAD_FIX`, and
prints the third compact report with `STATUS=$09` and `TRUNC=YES`. This is still
a report-counter foothold; full reference rows and rich xref output remain later
work.

Earlier hardware-proven `ASM 2.42` report truncation smoke on 2026-05-26:

```text
L @2000
L OK=42AD GO=2000
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$6800
PC=$680C
HIGH=$680C
BYTES=$000C
LINES=$0006
SYMS=$03/$10
FIXUPS=$00/$08
REFS=$00/$10
TRUNC=NO
ASM REPORT
STATUS=$03
ERRLINE=$0001
START=$6800
PC=$6800
HIGH=$6800
BYTES=$0000
LINES=$0001
SYMS=$00/$10
FIXUPS=$00/$08
REFS=$00/$10
TRUNC=NO
ASM REPORT
STATUS=$03
ERRLINE=$0001
START=$6800
PC=$6800
HIGH=$6800
BYTES=$0000
LINES=$0001
SYMS=$00/$10
FIXUPS=$00/$08
REFS=$00/$10
TRUNC=YES
ASM 2.42 TESTS OK
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
 5C FIXUPS
 5D DIRECT
 5E REPORT
 60 SYMBOLS
 80 LONG LINE
 90 END
WARN WARN_DS_WRAP
W=$E2F4 SYM=$06 PC=$6800
RET A=00 X=00 Y=68 P=77 S=FD NV-BdIZC
```

`ASM 2.42` proves the compact report `TRUNC=YES` printer path. It sets the
report truncation flag after the first-failure report proof and prints a third
compact report with the same stored `BAD_OPER` status and `ERRLINE=$0001`, but
with `TRUNC=YES`. This is a trunc-flag printer foothold; the later
table-overflow path still needs to set the flag from real overflow.

Earlier hardware-proven `ASM 2.41` first-failure report smoke on 2026-05-26:

```text
L @2000
L OK=4279 GO=2000
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$6800
PC=$680C
HIGH=$680C
BYTES=$000C
LINES=$0006
SYMS=$03/$10
FIXUPS=$00/$08
REFS=$00/$10
TRUNC=NO
ASM REPORT
STATUS=$03
ERRLINE=$0001
START=$6800
PC=$6800
HIGH=$6800
BYTES=$0000
LINES=$0001
SYMS=$00/$10
FIXUPS=$00/$08
REFS=$00/$10
TRUNC=NO
ASM 2.41 TESTS OK
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
 5C FIXUPS
 5D DIRECT
 5E REPORT
 60 SYMBOLS
 80 LONG LINE
 90 END
WARN WARN_DS_WRAP
W=$E2F4 SYM=$06 PC=$6800
RET A=00 X=00 Y=68 P=77 S=FD NV-BdIZC
```

`ASM 2.41` adds the first-failure report path. The report smoke fixture enables
report-on-failure, assembles a bad `ORG` line, proves the failure report printed
with `STATUS=$03` and `ERRLINE=$0001`, then verifies a later `ASM_END` on the
failed session returns the stored `BAD_OPER` status.

Earlier hardware-proven `ASM 2.40` `ASM_END` report smoke on 2026-05-26:

```text
L @2000
L OK=41AF GO=2000
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$6800
PC=$680C
HIGH=$680C
BYTES=$000C
LINES=$0006
SYMS=$03/$10
FIXUPS=$00/$08
REFS=$00/$10
TRUNC=NO
ASM 2.40 TESTS OK
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
 5C FIXUPS
 5D DIRECT
 5E REPORT
 60 SYMBOLS
 80 LONG LINE
 90 END
WARN WARN_DS_WRAP
W=$E2F4 SYM=$06 PC=$6800
RET A=00 X=00 Y=68 P=77 S=FD NV-BdIZC
```

`ASM 2.40` moves compact report printing into the `ASM_END` path. The report
smoke fixture enables report-on-END, assembles through a real `END` line,
asserts that the report was printed, then calls `ASM_END` a second time to prove
the clean idempotent path does not lose the printed-report state.

Earlier hardware-proven `ASM 2.39` compact-report smoke on 2026-05-26:

```text
L @2000
L OK=416E GO=2000
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$6800
PC=$680C
HIGH=$680C
BYTES=$000C
LINES=$0006
SYMS=$03/$10
FIXUPS=$00/$08
REFS=$00/$10
TRUNC=NO
ASM 2.39 TESTS OK
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
 5C FIXUPS
 5D DIRECT
 5E REPORT
 60 SYMBOLS
 80 LONG LINE
 90 END
WARN WARN_DS_WRAP
W=$E2F4 SYM=$06 PC=$6800
RET A=00 X=00 Y=68 P=77 S=FD NV-BdIZC
```

`ASM 2.39` prints the compact report block from the `$5E REPORT` fixture before
the final smoke ladder. It uses hex fields for the first W65C02S foothold and
proves the field printer for `STATUS`, `ERRLINE`, start/current/high PCs,
emitted/reserved bytes, line count, table counts/limits, and `TRUNC`.

Earlier hardware-proven `ASM 2.38` report-fact smoke on 2026-05-25:

```text
L @2000
L OK=3F9B GO=2000
ASM 2.38 TESTS OK
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
 5C FIXUPS
 5D DIRECT
 5E REPORT
 60 SYMBOLS
 80 LONG LINE
 90 END
WARN WARN_DS_WRAP
W=$E2F4 SYM=$06 PC=$6800
RET A=00 X=00 Y=68 P=77 S=FD NV-BdIZC
```

`ASM 2.38` added a pre-2.40 report-fact smoke slice. It assembles `ORG`, `EQU`,
`DB`, `DS`, and `END` through `ASM_ASSEMBLE_LINE`, then asserts ended/OK
session state, start/current/high-water PCs, physical line count,
symbol/fixup/reference counts, and report flags before restoring the `$6800`
symbol-smoke session.

Earlier hardware-proven `ASM 2.37` RAM-reorg smoke on 2026-05-25:

```text
L @2000
L OK=3E74 GO=2000
ASM 2.37 TESTS OK
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
 5C FIXUPS
 5D DIRECT
 60 SYMBOLS
 80 LONG LINE
 90 END
WARN WARN_DS_WRAP
W=$E2F4 SYM=$06 PC=$6800
RET A=00 X=00 Y=68 P=77 S=FD NV-BdIZC
```

Earlier hardware-proven `ASM 2.00` smoke on 2026-05-24:

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

Hardware-proven `ASM 2.20` smoke on 2026-05-24:

```text
L OK=3455 GO=3000
ASM 2.20 TESTS OK
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
 5C FIXUPS
 60 SYMBOLS
 80 LONG LINE
 90 END
W=$E2F4 SYM=$06 PC=$3000
RET A=00 X=00 Y=30 P=77 S=FD NV-BdIZC
```

Hardware-proven `ASM 2.30` DB smoke on 2026-05-24:

```text
L OK=381B GO=3000
ASM 2.30 TESTS OK
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
 5C FIXUPS
 5D DIRECT
 60 SYMBOLS
 80 LONG LINE
 90 END
W=$E2F4 SYM=$06 PC=$3000
RET A=00 X=00 Y=30 P=77 S=FD NV-BdIZC
```

Hardware-proven `ASM 2.31` ORG-policy smoke on 2026-05-24:

```text
L OK=398C GO=3000
ASM 2.31 TESTS OK
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
 5C FIXUPS
 5D DIRECT
 60 SYMBOLS
 80 LONG LINE
 90 END
W=$E2F4 SYM=$06 PC=$3000
RET A=00 X=00 Y=30 P=77 S=FD NV-BdIZC
```

Hardware-proven `ASM 2.32` DS smoke on 2026-05-25:

```text
L S19
L @3000
L OK=3C40 GO=3000
ASM 2.32 TESTS OK
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
 5C FIXUPS
 5D DIRECT
 60 SYMBOLS
 80 LONG LINE
 90 END
W=$E2F4 SYM=$06 PC=$3000
RET A=00 X=00 Y=30 P=77 S=FD NV-BdIZC
```

Hardware-proven `ASM 2.33` DS initializer-list smoke on 2026-05-25:

```text
L S19
L @3000
L OK=3DF8 GO=3000
ASM 2.33 TESTS OK
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
 5C FIXUPS
 5D DIRECT
 60 SYMBOLS
 80 LONG LINE
 90 END
W=$E2F4 SYM=$06 PC=$3000
RET A=00 X=00 Y=30 P=77 S=FD NV-BdIZC
```

Hardware-proven `ASM 2.34` `WARN_DS_WRAP` smoke on 2026-05-25:

```text
L S19
L @3000
L OK=3E43 GO=3000
ASM 2.34 TESTS OK
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
 5C FIXUPS
 5D DIRECT
 60 SYMBOLS
 80 LONG LINE
 90 END
W=$E2F4 SYM=$06 PC=$3000
```

Hardware-observed `ASM 2.35` warning visibility gap on 2026-05-25:

```text
L S19
L @3000
L OK=3E67 GO=3000
ASM 2.35 TESTS OK
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
 5C FIXUPS
 5D DIRECT
 60 SYMBOLS
 80 LONG LINE
 90 END
W=$E2F4 SYM=$06 PC=$3000
```

2.35 set and asserted the directive warning internally, but the final pass
report did not print `WARN WARN_DS_WRAP` because a later smoke session cleared
session-local report flags before printing.

Hardware-proven `ASM 2.36` visible warning smoke on 2026-05-25:

```text
L S19
L @3000
L OK=3E74 GO=3000
ASM 2.36 TESTS OK
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
 5C FIXUPS
 5D DIRECT
 60 SYMBOLS
 80 LONG LINE
 90 END
WARN WARN_DS_WRAP
W=$E2F4 SYM=$06 PC=$3000
```

`PC=$3000` is expected here. This is the pre-reorg 2.36 baseline: the
operand-classifier setup exercised `ORG $3000`, and the later symbol smoke
bound against that live assembler PC.

If the board returns before that line, the standalone entry now returns
diagnostic registers:

```text
A = smoke stage
X = ASM_STATUS
Y = ASM_SLOT
```

The failure path also tries to print one compact line before returning:

```text
ASM 2.47 TESTS FAIL
 5D DIRECT
 D3 WARN_DS_WRAP
S=$5D X=$00 Y=$D3
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
$5C fixup record/patch smoke
$5D DB/ORG/DS directive smoke
$5E report-fact smoke
$60 symbol smoke
$70 ASMTEST_3000 onboard mirror smoke
$71 RJOIN joiner lookup
$72 RJOIN BIO write lookup
$80 long-line rejection
$90 ASM_END
```

For `$5C` fixup smoke, `Y` identifies the subtest when the failure is an
internal assertion rather than an API status:

```text
$A1 abs16 forward label
$A2 rel8 forward label
$A3 rel8 out-of-range
$A4 selected fixup group
$A5 selected lo8 immediate
$A6 selected hi8 immediate
$A7 pending fixup at END
$AF shared fixup site/base check
$B1 abs16 BEGIN failed
$B2 abs16 `JSR FOO` emit failed
$B3 abs16 emitted bytes were not `20 FF FF`
$B4 abs16 fixup row metadata failed
$B5 abs16 patch site was wrong
$B6 abs16 `FOO` label parse/bind failed
$B7 abs16 row did not resolve
$B8 abs16 low patch byte was wrong
$B9 abs16 high patch byte was wrong
$BA abs16 END failed after patch
```

For `$5D` directive smoke, `Y` identifies the directive subtest:

```text
$C1 DB begin failed
$C2 `ADDR EQU $1234` setup failed
$C3 mixed DB line failed
$C4 emitted DB bytes were wrong
$C5 DB PC/high-water was wrong
$C6 empty DB did not fail BAD OPER
$C7 unknown bare DB symbol did not fail BAD WIDTH
$C8 ORG current did not preserve PC/high-water
$C9 ORG forward did not advance PC/high-water
$CA ORG backward did not fail BAD RANGE
$CB DS emit failed
$CC emitted DS bytes were wrong
$CD DS PC/high-water was wrong
$CE empty DS did not fail BAD OPER
$CF DS count over 255 did not fail BAD RANGE
$D0 DS initializer-list emit failed
$D1 emitted DS initializer-list bytes were wrong
$D2 DS initializer-list PC/high-water was wrong
$D3 DS partial initializer-list repeat did not set WARN_DS_WRAP
```

For `$5E` report-fact smoke, `Y` identifies the report-state subtest:

```text
$E1 report BEGIN failed
$E2 report ORG failed
$E3 report EQU failed
$E4 report DB failed
$E5 report DS fill failed
$E6 report DS truncating fill failed
$E7 report END failed
$E8 ended/OK/printed session state was wrong
$E9 start/current/high-water PC facts were wrong
$EA line/symbol/fixup/reference/use counts were wrong
$EB report flags were wrong
$EC second clean ASM_END failed or lost report-printed state
$ED report-failure BEGIN failed
$EE report-failure bad line did not fail BAD_OPER
$EF report-failure state/report facts were wrong
$F0 failed-session ASM_END did not return stored BAD_OPER
$F1 report reference counter fill failed
$F2 report reference overflow did not fail BAD_FIX/set TRUNC
$F3 report smoke restore failed
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
STZ $7110    -> 9C 10 71
STA $7100,X  -> 9D 00 71
EOR $7110    -> 4D 10 71
STA $7110    -> 8D 10 71
INX          -> E8
CPX #COUNT   -> E0 10
BNE LOOP     -> D0 ED when LOOP is a resolved backward label
RTS          -> 60
STZ #0       -> BAD MODE at opcode lookup
```

The standalone `START` smoke emits this resolved byte stream into
`ASM_CODE_BUF` and compares every byte:

```text
A2 00 9C 10 69 9D 00 69 4D 10 69 8D 10 69 E8 E0 10 D0 ED 60
```

Fixup fixtures:

```text
JSR FOO      -> 20 FF FF with abs16 fixup
JSR PIN_FTDI_READ_BYTE_NONBLOCK -> 20 lo hi from resident EXEC join
JSR UTL_HEX_NIBBLE_TO_ASCII -> 20 lo hi from resident EXEC join, executed
BNE FOO      -> D0 FF with rel8 fixup
END          -> BAD FIX when a required fixup is still pending
```

Acceptance:

```text
known emitted bytes match W65C02S table
irregular opcodes are explicit
aaa-bbb-cc helpers are used only where regular
unresolved operands create explicit fixup rows when the emitted mode is known
unknown JSR operands prefer resident EXEC joins after local symbols miss
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

Current foothold:

```text
abs16 forward label resolves little endian
rel8 forward label resolves with branch base after operand
rel8 out-of-range forward label fails BAD RANGE
selected lo8/hi8 immediate fixups patch one byte
END fails BAD FIX if a required fixup remains pending
unresolved symbol hash/name is snapshotted before suffix/EOL token scans
```

Acceptance:

```text
fixup record state, not placeholder byte, is truth
patch site is exact
branch base is address after branch operand
```

### ASM 2.30-2.34 Directives

Current DB fixture:

```text
ADDR EQU $1234
SEED DB $FF,10,'A',$1234,<ADDR,>ADDR
```

Current ORG fixtures:

```text
ORG *
ORG $3010
ORG $300F
```

Current DS fixtures:

```text
BUF DS 3,$AA
DS 2,$1234
BUF DS
DS $0100
PAT DS 6,$AA,$55,'A','5'
DS 3,$11,$22,$33,$44
```

Current DB/ORG/DS acceptance:

```text
DB emits byte/word by source/symbol width
unknown bare DB ADDR is BAD WIDTH
empty DB is BAD OPER
DB emits FF 0A 41 34 12 34 12 for the current fixture
first pristine ORG may establish source origin from scratch PC
ORG current is allowed
ORG forward is allowed and updates high-water PC
ORG backward is BAD RANGE
DS repeats the fill byte
DS fill value truncates to the low byte
DS initializer lists repeat to fill the requested count
DS initializer lists truncate after the requested count
DS partial initializer-list repeats set WARN_DS_WRAP, not BAD RANGE
reports print WARN WARN_DS_WRAP when WARN_DS_WRAP is set
DS advances PC/high-water by count
empty DS is BAD OPER
DS count >255 is BAD RANGE
```

Parked for later directive slices:

```text
DC constants
```

### ASM 2.40 Report

Current foothold:

```text
ASM 2.40 prints a compact report block from ASM_END when report-on-END is set.
ASM 2.41 prints a compact report block on first failure when report-on-failure
is set.
ASM 2.42 prints TRUNC=YES when the report truncation flag is set.
ASM 2.43 sets TRUNC=YES from report-reference counter overflow.
ASM 2.44 counts mark-use symbol references in REFS.
ASM 2.45 prints the first compact USED row with count and first-ref line.
ASM 2.46 stores session symbol definition lines.
ASM 2.47 prints compact UNUSED rows with definition lines.
Numeric report fields are hex in this first W65C02S printer.
Second clean ASM_END returns OK without duplicating report state.
```

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
used symbol report prints count and first reference line
unused symbol report prints definition lines
```

## ASMTEST_3000 Final Acceptance

When ASM has parser, symbols, expressions, classifier, emitter, directives, and
fixups, `ASMTEST_3000.asm` becomes a full assembly acceptance test.

Expected source:

```text
ORG $6800
OUT EQU $6900
SUM EQU $6910
COUNT EQU 16
...
END
```

Expected behavior after running at `$6800`:

```text
$6900-$690F = 52 2D 59 4F 52 53 20 41 53 4D 20 54 45 53 54 2E
$6910       = 0F
```

ASM 2.63 adds host-side expected image comparison before trusting the full
sample assembly path. The checker compares emitted bytes and the runtime output
oracle, not just source shape, as more source-file assembly plumbing lands.

## Regression Protocol

Before committing ASM code:

```text
make -C SRC asm-test
```

Current `asm-test` expands to:

```text
make -C SRC asmtest-6800-wdc-check
make -C SRC asm-v1-core
make -C SRC asm-v1-runtime
make -C SRC asm-v1-runtime-smoke
make -C SRC asm-v1-runtime-asmtest
make -C SRC asm-v1-runtime-paste
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
make -C SRC asmtest-6800-assemble
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
RUN $6800
display $6900-$6910
verify seed and checksum
record transcript in HARDWARE_TEST_LOG
```

ASM 2.62 captures the paste/load, `END`, emitted image, `G 6800` return
registers, and post-run `$6900-$6910` output bytes on hardware. This is the
first hardware-proven full `ASMTEST_3000` assembly path.
