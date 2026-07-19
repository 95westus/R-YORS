# ASM Test Plan

This is the test plan for ASM proper, the hash-based source-line assembler. It
does not test HIMON's legacy `A` mini-assembler except where a comparison is
explicitly useful.

The plan follows the ASM course map. Early tests prove the source contract and
routine contracts before ASM can assemble real code. Later tests compare emitted
bytes and fixup behavior.

In this plan, OIL means **Overlay Integration Layer**. Historical gate headings
retain the acronym used in their board transcripts.

## Test Rule

Test the test before trusting the assembler.

For every sample source file:

```text
first prove the sample follows ASM v1 source rules
then prove the sample's expected result by an independent checker
then feed it to the onboard ASM layer as that layer becomes available
```

New ASM-native sample source files use `.a`. WDC source files use `.asm`.
Legacy ASM paste samples with `.asm` names remain until they are migrated.

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

Current opcode/addressing coverage audit:

```text
make -C SRC asm-opcode-coverage
```

This is a host-side source audit of `ASM_FIND_OPCODE`. It verifies the active
v1 mnemonic/addressing rows and opcode bytes, and fails if a row is added,
removed, or silently changes without updating the audit.

Current ASM core build:

```text
make -C SRC asm-v1-core
```

Current ASM core proof artifact:

```text
SRC/BUILD/s19/asm-v1-core-2000.s19
```

The standalone core image is now a host/simulator smoke artifact, not the
preferred RAM-load board proof. Its full smoke ladder plus DATA image can grow
past the safe HIMON RAM-load window. Use the runtime smoke wrapper below for
current board proof. It is intentionally not part of `make -C SRC all`; build
it explicitly with `make -C SRC asm-v1-core` only when the standalone smoke
ladder is needed.

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

Current ASM flash `$8000` build:

```text
make -C SRC asm-v1-flash
```

Current ASM flash artifact:

```text
SRC/BUILD/s19/asm-v1-flash-8000.s19
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
executes `JSR $7000` and requires `$7101='A'`. It also checks the clean-`END`
seal fact record: flags exactly valid, base `$7000`, exclusive end `$7014`,
and length `$0014`. This proves source name -> FNV hash -> resident EXEC join ->
emitted operand -> live call return, plus the RAM-only `END` span facts needed
by a later explicit `SEAL`. It prints `ASM RT OK` on success or
`ASM RT FAIL $xx` on failure; `$E7` means the seal fact record did not match.

Current board-facing seal-span smoke:

```text
make -C SRC asm-v1-runtime-smoke
SRC/BUILD/s19/asm-v1-runtime-smoke-2000.s19
```

The current image spans `$2000-$6BDB`, below the protected `$7E00` boundary.
Board pass shape:

```text
>L G
L S19
L @2000
L OK=4BDC GO=2000
ASM RT SMOKE
ASM RT OK
```

Hardware-proven on 2026-07-01 with HIMON `V 00.0630(2121)`:

```text
>L
L S19
L @2000
L OK=4BDC GO=2000
>G 2000
GO 2000
ASM RT SMOKE
ASM RT OK

#GO# ENTRY=2000
RET A=09 X=3B Y=09 P=75 S=FD NV-BdIzC
>
```

Companion runtime-paste proof on 2026-07-01 used
`asm-v1-runtime-paste-2000.s19` at `L OK=502B GO=2000`. The pasted source
defined `START_ADDR=$7000`, `END_ADDR=$701F`, and
`SIZE=END_ADDR-START_ADDR`, then ran the emitted program. The table showed
`SIZE=$001F`, and the runtime output at `$7100` was:

```text
7100: 00 70 1F 70 1F 00 ...
```

That paste-driver proof is an external span oracle for the same
`base=$7000`, `end=$701F`, `len=$001F` facts; the direct internal
`ASM_SEAL_*` check remains the smoke wrapper above.

Seal eligibility flags were hardware-proven on 2026-07-01 with HIMON
`V 00.0630(2121)` and `asm-v1-runtime-paste-2000.s19` loaded as
`L OK=506F GO=2000`. The board first filled `$7200-$721F` using
`DS $20,$EE`, then assembled a second source that jumped across a forward
`ORG` hole, used plain `DS 2`, and used initialized `DS 3,$5A`.
The emitted span proved ordinary ASM still accepts both ineligible shapes:

```text
7200: 4C 10 72 EE EE EE EE EE | EE EE EE EE EE EE EE EE | L.r.............
7210: A9 5A 8D 00 71 A9 A5 8D | 01 71 60 00 00 5A 5A 5A | .Z..q....q`..ZZZ
```

Running `G 7210` wrote `$7100-$7101 = 5A A5`. The internal RAM fact record
dumped as:

```text
5189: 07 00 72 20 72 20 00 | ..r r .
```

This decodes to flags `$07` (valid + forward-ORG hole + plain-DS unowned),
base `$7200`, exclusive end `$7220`, and length `$0020`. The same source also
proves initialized `DS count,$xx` stays owned: `$721D-$721F = 5A 5A 5A`.

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
`BVF $4FRE` line and an immediate return to `ASM> `. ASM 2.72 supersedes this
reopen-on-error recovery policy for the runtime paste wrapper.

ASM 2.70 keeps the 2.69 paste-driver behavior but trims the status-name printer
from a compare/jump chain into low/high message pointer tables. The host gate
passes with `asm-v1-runtime-paste-2000.s19` at `$2AF6` bytes, down from the
2.69 `$2B53` proof image while preserving named errors and recovery. The
hardware proof loads `L OK=2AF6 GO=2000`, accepts the line-echo sample through
`END`, and echoes `HELLO WORLD!` from the emitted `$7000` program.
A follow-up board run started the already-loaded paste wrapper with `G 2000`,
accepted the same sample through `END`, returned `A=$0F/X=$4C/Y=$0F`, and ran
`G 7000` to echo `HHHH HHH LJK.J.JLJKJ`. Embedded dots in the line body echoed
normally; only a leading `.` remains the exit command.

ASM 2.71 adds a second resident-output RJOIN target to the runtime asmtest
wrapper. HIMON now publishes `BIO_FTDI_PUT_CSTR` as executable FNV alias
`$AEFA0F42`, pointing at the existing `SYS_WRITE_CSTRING` implementation. The
asmtest source stream now assembles `LDX #<TEXT`, `LDY #>TEXT`, and
`JSR BIO_FTDI_PUT_CSTR`; its byte oracle patches the expected operand from the
emitted resident target while rejecting unresolved `$FFFF` and high-zero
targets. The host `asm-test` gate passes with this resident-call extension.
Board proof requires a HIMON image that includes `BIO_FTDI_PUT_CSTR_FNV`; that
proof landed as ASM 2.73 after the HIMON update.

ASM 2.72 changes the runtime paste wrapper's first-error policy from recover
and reprompt to abort-to-HIMON. All failure exits now pass through the same
quench path: `ASM_BEGIN` failure, line-read failure, and
`ASM_ASSEMBLE_LINE` failure. The wrapper prints the failure line, drains RX with
`SYS_FLUSH_RX`, then uses `SYS_READ_CHAR_TIMEOUT_SPINDOWN` to keep consuming
bytes until the sender has been quiet for the local idle window. It then returns
to its caller with `C=0`, `A=status`, and `X/Y=current PC`. The current idle
window is two `SYS_READ_CHAR_TIMEOUT_SPINDOWN` slices, roughly 57 ms at 8 MHz.
It does not call `ASM_BEGIN` and does not emit another `ASM> ` prompt. This
avoids treating the tail of a still-streaming host paste as a fresh `$7000` ASM
session. The host `asm-test` gate passes with `asm-v1-runtime-paste-2000.s19`
at `$2B56` bytes.

Hardware-proven ASM 2.72 runtime paste quench-to-HIMON on 2026-06-07:

```text
L OK=2B56 GO=2000
ASM RT PASTE
ASM>                         MODULE          HIMON_APP
ERR=$01 BAD MNEM PC=$7000
#LOADGO# ENTRY=2000
RET A=01 X=00 Y=70 P=74 S=FD NV-BdIzc
>G 2000
GO 2000
ASM RT PASTE
ASM>         ORGY $7000
ERR=$01 BAD MNEM PC=$7000
>G 2000
GO 2000
ASM RT PASTE
... BRA MAINX leaves an unresolved fixup ...
ASM>         END
ERR=$09 BAD FIX PC=$704E
>
```

In that transcript, only the first failure prints an explicit `RET` block
because it was launched by `L G` before any trap context was active. The later
manual `G 2000` failures still return with `A=status`, `X/Y=current PC`, and
`C=0`, but a separate top-level `BRK 03 PC=C0D1` left that ROM's HIMON trap
context valid; its `CMD_EXEC_ADDR` preserved the context and suppressed
ordinary return telemetry while `NMI_CTX_FLAG` was set. Later HIMON work changes
`G` to start a fresh run by clearing the saved trap context before transfer.

The same transcript later shows `ERR=$06 BAD RANGE PC=$7403` after a second
`ORG`. That is expected single-session fixup behavior, not stale state after a
quench abort: a `BRA MAINX` emitted near `$7000` remained pending and was later
resolved by `MAINX` at `$7403`, beyond relative branch range.

ASM 2.73 records the hardware proof for the 2.71 resident-output RJOIN target.
After updating HIMON to `V 00.0606(2141)`, the runtime asmtest wrapper loaded
as `L OK=292C GO=2000`, assembled `JSR BIO_FTDI_PUT_CSTR`, and ran the emitted
program. The visible `RJOIN` text proves the emitted program called the resident
PUT-CSTR alias, while the wrapper still verified the complete ASMTEST output.
The board dump shows the emitted call as `20 58 E5` at `$701D`; the current
HIMON map identifies `$E558` as `SYS_WRITE_CSTRING`, which is the payload of
the `BIO_FTDI_PUT_CSTR_FNV` record.

Hardware-proven ASM 2.73 `BIO_FTDI_PUT_CSTR` RJOIN on 2026-06-07:

```text
L OK=292C GO=2000
ASM RT ASMTEST
RJOINASM RT ASMTEST OK
>D 7000 703F
7000: A2 00 9C 10 71 BD 1E 70 | 9D 00 71 4D 10 71 8D 10 | ....q..p..qM.q..
7010: 71 E8 E0 10 D0 EF A2 2E | A0 70 20 58 E5 60 52 2D | q........p X.`R-
7020: 59 4F 52 53 20 41 53 4D | 20 54 45 53 54 2E 52 4A | YORS ASM TEST.RJ
7030: 4F 49 4E 00 00 A2 00 BD | 00 71 D0 0C A9 0D 20 DF | OIN......q.... .
>D 7100 FF
7100: 52 2D 59 4F 52 53 20 41 | 53 4D 20 54 45 53 54 2E | R-YORS ASM TEST.
7110: 0F 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>
```

ASM 2.76 is intentionally deferred. The quench behavior proven in 2.72 should
be promoted later into a shared input-drain contract, probably named
`SYS_QUENCH_RX` or concrete `BIO_FTDI_QUENCH_RX`, after the paste/load/monitor
call sites settle enough to share the same idle-window policy.

ASM 2.77 adds `ASM_PRINT_TABLES`, an exported ASM v1 runtime routine that
prints the current RAM session symbol and fixup rows. The runtime asmtest
wrapper calls it immediately after `ASM_END`, before patching the resident
`BIO_FTDI_PUT_CSTR` expected operand and running the emitted `$7000` program.
The printer uses the same resident output path as the compact report and emits
serial-friendly rows:

```text
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
...
FIXUPS
SL ST MODE SEL SITE BASE NAME
...
```

How to read the ASMTEST symbol/fixup data:

- All numeric fields are hexadecimal.
- `SYMBOLS` rows are RAM session symbol rows. `SL` is the table slot, `ST` is
  symbol state (`01` = defined), `VALUE` is the current value, `K` is symbol
  kind (`00` = scalar value, `01` = address, `02` = mask), `W` is width
  (`00` = none/untyped, `01` = byte, `02` = word, `03` = zero page,
  `04` = absolute, `05` = mask8, `06` = mask16), `FL` is the symbol flag byte,
  `DEF` is the physical source/session line that defined the symbol, `USE` is
  the resolved use count, `FIRST` is the first source/session line that used
  it, and `NAME` is canonical text.
- Symbol flag bits are `01` used, `02` has text, `04` has care mask,
  `08` came from a label, and `10` came from `EQU`. For example `OUT` has
  `FL=17`, meaning used + text + care + `EQU`; `SEED` has `FL=0E`, meaning
  text + care + label, but not used through symbol lookup.
- `FIXUPS` rows are patch records that were created for forward or
  resident-catalog operands. `SL` is the fixup slot, `ST` is fixup state
  (`01` = pending, `02` = resolved, `80` = failed), `MODE` is operand mode
  (`02` = immediate byte, `03` = zero page, `04` = absolute word,
  `05` = zero page indexed by X, `06` = absolute indexed by X,
  `07` = relative branch), `SEL` selects the full value or a byte
  (`00` = full, `01` = low byte, `02` = high byte), `SITE` is the address
  patched, `BASE` is the address after the placeholder operand and is used for
  relative branch math, and `NAME` is the target text.
- In the ASMTEST proof, `SEED` resolves an absolute-X fixup at `$7006` and the
  two `TEXT` rows patch `#<TEXT` at `$7017` and `#>TEXT` at `$7019`.

The initial host gate passed with `make -C SRC asm-test`. Built sizes from
that gate were `asm-v1-core-2000.s19` total `$4BBE`,
`asm-v1-runtime-2000.s19` total `$2722`,
`asm-v1-runtime-asmtest-2000.s19` total `$2AB2`, and
`asm-v1-runtime-paste-2000.s19` total `$2CD6`.

Hardware-proven ASM 2.77 table printer on 2026-06-07:

```text
L OK=2AB2 GO=2000
ASM RT ASMTEST
ASM TABLES
SYMBOLS
SL ST VALUE K W FL DEF USE FIRST NAME
00 01 7100 01 04 17 0002 01 0008 OUT
01 01 7110 01 04 17 0003 03 0006 SUM
02 01 0010 00 00 17 0004 01 000C COUNT
03 01 7000 01 04 0E 0005 00 0000 ASMTEST
04 01 7005 01 04 0F 0007 01 000D LOOP
05 01 701E 01 04 0E 0012 00 0000 SEED
06 01 702E 01 04 0E 0014 00 0000 TEXT
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 06 00 7006 7008 SEED
01 02 02 01 7017 7018 TEXT
02 02 02 02 7019 701A TEXT
RJOINASM RT ASMTEST OK

#LOADGO# ENTRY=2000
RET A=11 X=9D Y=11 P=75 S=FD NV-BdIzC
>
```

The final return has carry set. `A/X/Y` are last-print-path residues from the
wrapper after a successful `ASM RT ASMTEST OK`, not table-printer statuses.

Follow-up ASM 2.77 column cleanup pads short row fields so headings stay lined
up past `W` in `SYMBOLS` and past `MODE` in `FIXUPS`. The updated host gate
passes with `make -C SRC asm-test`. Built sizes from that gate:
`asm-v1-core-2000.s19` total `$4BD3`, `asm-v1-runtime-2000.s19` total `$2737`,
`asm-v1-runtime-asmtest-2000.s19` total `$2AC7`, and
`asm-v1-runtime-paste-2000.s19` total `$2CEB`.

Hardware-proven ASM 2.77 column cleanup on 2026-06-07:

```text
L OK=2AC7 GO=2000
ASM RT ASMTEST
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7100  01 04 17 0002 01  0008  OUT
01 01 7110  01 04 17 0003 03  0006  SUM
02 01 0010  00 00 17 0004 01  000C  COUNT
03 01 7000  01 04 0E 0005 00  0000  ASMTEST
04 01 7005  01 04 0F 0007 01  000D  LOOP
05 01 701E  01 04 0E 0012 00  0000  SEED
06 01 702E  01 04 0E 0014 00  0000  TEXT
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 06   00  7006 7008 SEED
01 02 02   01  7017 7018 TEXT
02 02 02   02  7019 701A TEXT
RJOINASM RT ASMTEST OK
>
```

ASM 2.78 brings the same table printer into the runtime paste wrapper. The
wrapper now recognizes a paste-driver command line `.T` (with optional trailing
space, tab, or comment) and prints `ASM TABLES` without feeding that line to
the assembler. An accepted `END` prints the tables before `ASM RT PASTE OK`.
If `END` itself fails, for example because unresolved or out-of-range fixups
remain, the wrapper first prints the existing `ERR=$xx ... PC=$hhhh` line,
quenches RX, prints the tables, and then returns to HIMON with the original
assembly failure status in `A` and current PC in `X/Y`. Non-`END` assembly
errors stay compact and only quench/return. ASM 3.01 later supersedes that
non-`END` policy with transactional rollback and reprompt.

The plain `.` line still exits without finalizing the session or printing
tables. Table-print failure is non-fatal to the paste wrapper and prints
`TABLE=$xx`; normal assembler failure returns keep their original status. The
host gate passes with `make -C SRC asm-test`; the updated
`asm-v1-runtime-paste-2000.s19` total is `$2D55`.

Hardware-proven ASM 2.78 paste table printer on 2026-06-07:

```text
ASM RT PASTE
ASM> .T
ASM TABLES
SYMBOLS
FIXUPS
ASM> STA TABLE,X
OK PC=$7007
ASM> .T
ASM TABLES
SYMBOLS
00 01 7000  01 04 0E 0002 00  0000  MAIN
FIXUPS
00 01 06   00  7005 7007 TABLE
ASM> END
ERR=$09 BAD FIX PC=$7100
ASM TABLES
SYMBOLS
00 01 7000  01 04 0F 0002 01  0007  MAIN
01 01 700C  01 04 0E 0008 00  0000  FORWARD
02 01 7100  01 04 0E 000A 00  0000  TABLE
FIXUPS
00 02 06   00  7005 7007 TABLE
01 01 07   00  7009 700A FORWARD
```

The same board session then resolved both pending fixups and showed accepted
`END` printing the final table block before the success banner:

```text
ASM> FORWARD: RTS
OK PC=$700D
ASM> ORG $7100
OK PC=$7100
ASM> TABLE:
OK PC=$7100
ASM> END
OK PC=$7100
ASM TABLES
SYMBOLS
00 01 7000  01 04 0F 0002 01  0007  MAIN
01 01 700C  01 04 0E 0008 00  0000  FORWARD
02 01 7100  01 04 0E 000A 00  0000  TABLE
FIXUPS
00 02 06   00  7005 7007 TABLE
01 02 07   00  7009 700A FORWARD
ASM RT PASTE OK
>
```

ASM 2.79 switches the runtime paste wrapper's input call from
`SYS_READ_CSTRING_ECHO_UPPER` to `SYS_READ_CSTRING_EDIT_ECHO_UPPER`. This uses
the existing editable echoed uppercase line input path, which handles
Backspace as `$08` or `$7F`, ANSI Delete (`ESC[3~`), and left/right cursor
editing. The host gate passes with `make -C SRC asm-test`; the updated
`asm-v1-runtime-paste-2000.s19` total is `$2ECB`.

Hardware-smoke ASM 2.79 edit-line paste wrapper on 2026-06-07:

```text
L OK=2ECB GO=2000
ASM RT PASTE
ASM> ORG $7000
OK PC=$7000
ASM> LDA #$4D
OK PC=$7002
ASM> LDX #$00
OK PC=$7004
ASM> LOOP: STA TABLE,X
OK PC=$7007
ASM> .T
ASM TABLES
SYMBOLS
00 01 7004  01 04 0E 0004 00  0000  LOOP
FIXUPS
00 01 06   00  7005 7007 TABLE
ASM> INX
OK PC=$7008
ASM> BEQ FORWARD
OK PC=$700A
ASM> .T
ASM TABLES
SYMBOLS
00 01 7004  01 04 0E 0004 00  0000  LOOP
FIXUPS
00 01 06   00  7005 7007 TABLE
01 01 07   00  7009 700A FORWARD
ASM> BRA LOOP
OK PC=$700C
ASM> FORWARD:
OK PC=$700C
ASM> RTS
OK PC=$700D
ASM> ORG $7100
OK PC=$7100
ASM> TABLE:
OK PC=$7100
ASM> END
OK PC=$7100
ASM TABLES
SYMBOLS
00 01 7004  01 04 0F 0004 01  0007  LOOP
01 01 700C  01 04 0E 0008 00  0000  FORWARD
02 01 7100  01 04 0E 000B 00  0000  TABLE
FIXUPS
00 02 06   00  7005 7007 TABLE
01 02 07   00  7009 700A FORWARD
ASM RT PASTE OK

#LOADGO# ENTRY=2000
RET A=0F X=C0 Y=0F P=75 S=FD NV-BdIzC
>G 7000
GO 7000

#GO# ENTRY=7000
RET A=4D X=00 Y=30 P=77 S=FD NV-BdIZC
```

The preceding `$2D55` board run captured the old reader returning `READ=$08`
when Backspace was sent. The `$2ECB` run proves the paste wrapper can use the
editable line reader on board while preserving `.T`, final table printing,
fixup resolution, and emitted-code execution.

Follow-up operator-confirmed edit-key proof on the same board:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> OR G
... Backspace was used ...
ASM> ORG $7600
OK PC=$7600

>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7600
... Backspace, then Delete, then 55 ...
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7655
OK PC=$7655
ASM>
```

ASM 2.80 opcode/addressing coverage audit on 2026-06-07:

```text
make -C SRC asm-test
```

ASM 2.80 adds a host-side opcode coverage audit before the build smoke gates.
The audit reads `SRC/ASM/asm-v1-core.asm`, extracts `ASM_FIND_OPCODE`, and
verifies the current v1 active surface: `RTS`, `INX`, immediate `LDX/LDY/CPX`,
`LDA/EOR` immediate/zero-page/absolute/indexed-X rows, `STA/STZ`
zero-page/absolute/indexed-X rows, `ASL` implied/accumulator/zero-page/
absolute/indexed-X rows, `JSR` absolute, and the `BCC/BCS/BEQ/BMI/BNE/BPL/BRA/
BVC/BVS` relative rows. This is an audit gate only; it does not add new
addressing modes or change paste behavior. The host gate passes; the audit
reports `rows=39` and `mnemonics=20`.

ASM 2.81 `LSR/ROL/ROR` opcode rows on 2026-06-07:

```text
make -C SRC asm-test
```

ASM 2.81 adds opcode lookup rows for `LSR`, `ROL`, and `ROR`. Each mirrors the
existing `ASL` surface: implied/accumulator, zero-page, absolute, zero-page X,
and absolute X. The full-core opcode smoke emits all 18 new rows into
`ASM_CODE_BUF` after the existing ASMTEST-shaped stream, and the host opcode
audit now reports `rows=57` and `mnemonics=23`. The host gate passes with
`asm-v1-runtime-paste-2000.s19` total `$2F82`.

Hardware-proven ASM 2.81 `LSR/ROL/ROR` paste emission on 2026-06-07:

```text
L OK=2F82 GO=2000
ASM RT PASTE
ASM> ORG $7200
OK PC=$7200
ASM> LSR
OK PC=$7201
ASM> LSR A
OK PC=$7202
ASM> LSR $12
OK PC=$7204
ASM> LSR $0012
OK PC=$7207
ASM> LSR $12,X
OK PC=$7209
ASM> LSR $0012,X
OK PC=$720C
ASM> ROL
OK PC=$720D
ASM> ROL A
OK PC=$720E
ASM> ROL $12
OK PC=$7210
ASM> ROL $0012
OK PC=$7213
ASM> ROL $12,X
OK PC=$7215
ASM> ROL $0012,X
OK PC=$7218
ASM> ROR
OK PC=$7219
ASM> ROR A
OK PC=$721A
ASM> ROR $12
OK PC=$721C
ASM> ROR $0012
OK PC=$721F
ASM> ROR $12,X
OK PC=$7221
ASM> ROR $0012,X
OK PC=$7224
ASM> END
OK PC=$7224
ASM RT PASTE OK

>D 7200 7223
7200: 4A 4A 46 12 4E 12 00 56 | 12 5E 12 00 2A 2A 26 12 | JJF.N..V.^..**&.
7210: 2E 12 00 36 12 3E 12 00 | 6A 6A 66 12 6E 12 00 76 | ...6.>..jjf.n..v
7220: 12 7E 12 00 | .~..
```

ASM 2.82 `BIT` opcode rows on 2026-06-07:

```text
make -C SRC asm-test
```

ASM 2.82 adds `BIT` opcode lookup rows for immediate, zero-page, absolute,
zero-page X, and absolute X forms. The immediate row is the W65C02-specific
`BIT #imm` opcode `$89`, making this slice the first non-shift 65C02-only
opcode form in ASM v1. The full-core opcode smoke emits all five rows into
`ASM_CODE_BUF`, and the host opcode audit now reports `rows=62` and
`mnemonics=24`. The host gate passes with `asm-v1-runtime-paste-2000.s19`
total `$2FBB`.

Hardware-proven ASM 2.82 `BIT` paste emission on 2026-06-08:

```text
L OK=2FBB GO=2000
ASM RT PASTE
ASM> ORG $7240
OK PC=$7240
ASM> BIT #$12
OK PC=$7242
ASM> BIT $12
OK PC=$7244
ASM> BIT $0012
OK PC=$7247
ASM> BIT $12,X
OK PC=$7249
ASM> BIT $0012,X
OK PC=$724C
ASM> END
OK PC=$724C
ASM RT PASTE OK

7240: 89 12 24 12 2C 12 00 34 | 12 3C 12 00 | ..$.,..4.<..
```

ASM 2.83 implied flag opcode rows on 2026-06-08:

```text
make -C SRC asm-test
```

ASM 2.83 adds the implied-only flag opcodes `CLC`, `CLD`, `CLI`, `CLV`,
`SEC`, `SED`, and `SEI`. To keep the runtime paste image below the `$3000`
size line, `RTS`, `INX`, and these flag mnemonics now share a compact
implied-opcode table. This changes opcode lookup shape only; runtime paste
prompting, status names, and table printing remain unchanged. The full-core
opcode smoke emits all seven new rows into `ASM_CODE_BUF`, and the host opcode
audit now reports `rows=69` and `mnemonics=31`. The host gate passes with
`asm-v1-runtime-paste-2000.s19` total `$2FE0`.

Hardware-proven ASM 2.83 implied flag opcode paste emission on 2026-06-08:

```text
L OK=2FE0 GO=2000
ASM RT PASTE
ASM> ORG $7250
OK PC=$7250
ASM> CLC
OK PC=$7251
ASM> CLD
OK PC=$7252
ASM> CLI
OK PC=$7253
ASM> CLV
OK PC=$7254
ASM> SEC
OK PC=$7255
ASM> SED
OK PC=$7256
ASM> SEI
OK PC=$7257
ASM> END
OK PC=$7257
ASM RT PASTE OK

>D 7250 7256
7250: 18 D8 58 B8 38 F8 78 | ..X.8.x
```

ASM 2.84 runtime paste END-only table printing on 2026-06-08:

```text
make -C SRC asm-test
```

ASM 2.84 removes the runtime paste wrapper's mid-session `.T` command path.
The table printer remains in the paste wrapper and still runs after accepted
`END`, and after failed `END` once RX has been quenched. This keeps symbol,
fixup, and status evidence tied to the assembler's finalization/resolve point
instead of a live mid-session prompt command. A plain `.` line still exits the
paste wrapper without finalizing the ASM session. The host gate passes with
`asm-v1-runtime-paste-2000.s19` total `$2FA3`.

ASM 2.85 implied CPU/register/stack opcode rows on 2026-06-08:

```text
make -C SRC asm-test
```

ASM 2.85 adds implied-only opcode rows for `NOP`, `DEX`, `DEY`, `INY`, `TAX`,
`TAY`, `TSX`, `TXA`, `TXS`, `TYA`, `PHA`, `PHP`, `PHX`, `PHY`, `PLA`, `PLP`,
`PLX`, `PLY`, and `RTI`. These join the existing implied-opcode table, so
runtime growth is only the opcode rows. The full-core opcode smoke now emits
`$60` bytes, and the host opcode audit reports `rows=88` and `mnemonics=50`.
The host gate passes with `asm-v1-runtime-paste-2000.s19` total `$2FC9`.

Hardware-proven ASM 2.85 implied CPU/register/stack opcode paste emission on
2026-06-08:

```text
L OK=2FC9 GO=2000
ASM RT PASTE
ASM> ORG $7260
OK PC=$7260
ASM> NOP
OK PC=$7261
ASM> DEX
OK PC=$7262
ASM> DEY
OK PC=$7263
ASM> INY
OK PC=$7264
ASM> TAX
OK PC=$7265
ASM> TAY
OK PC=$7266
ASM> TSX
OK PC=$7267
ASM> TXA
OK PC=$7268
ASM> TXS
OK PC=$7269
ASM> TYA
OK PC=$726A
ASM> PHA
OK PC=$726B
ASM> PHP
OK PC=$726C
ASM> PHX
OK PC=$726D
ASM> PHY
OK PC=$726E
ASM> PLA
OK PC=$726F
ASM> PLP
OK PC=$7270
ASM> PLX
OK PC=$7271
ASM> PLY
OK PC=$7272
ASM> RTI
OK PC=$7273
ASM> END
OK PC=$7273
ASM RT PASTE OK

>D 7260 7272
7260: EA CA 88 C8 AA A8 BA 8A | 9A 98 48 08 DA 5A 68 28 | ..........H..Zh(
7270: FA 7A 40 | .z@
```

ASM 2.86 STX/STY/TRB/TSB/CPY opcode rows on 2026-06-08:

```text
make -C SRC asm-test
```

ASM 2.86 adds active rows for `STX`, `STY`, `TRB`, `TSB`, and `CPY`.
`STX $12,Y` introduces the current zero-page `,Y` operand mode; absolute `,Y`
remains rejected until a mnemonic that needs it is added. The simple opcode
families now share a compact `VID,MODE,OPCODE` table, covering the existing
`LDX`, `LDY`, `CPX`, `STZ`, `EOR`, `STA`, `LDA`, `BIT`, and `JSR` rows plus
the new rows. The full-core opcode smoke now emits `$7F` bytes, and the host
opcode audit reports `rows=101` and `mnemonics=55`. The host gate passes with
`asm-v1-runtime-paste-2000.s19` total `$2F48`.

Hardware-proven ASM 2.86 `STX/STY/TRB/TSB/CPY` paste emission on
2026-06-08:

```text
L OK=2F48 GO=2000
ASM RT PASTE
ASM> ORG $7280
OK PC=$7280
ASM> STX $12
OK PC=$7282
ASM> STX $0012
OK PC=$7285
ASM> STX $12,Y
OK PC=$7287
ASM> STY $12
OK PC=$7289
ASM> STY $0012
OK PC=$728C
ASM> STY $12,X
OK PC=$728E
ASM> TRB $12
OK PC=$7290
ASM> TRB $0012
OK PC=$7293
ASM> TSB $12
OK PC=$7295
ASM> TSB $0012
OK PC=$7298
ASM> CPY #$12
OK PC=$729A
ASM> CPY $12
OK PC=$729C
ASM> CPY $0012
OK PC=$729F
ASM> END
OK PC=$729F
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK

>D 7280 729E
7280: 86 12 8E 12 00 96 12 84 | 12 8C 12 00 94 12 14 12 | ................
7290: 1C 12 00 04 12 0C 12 00 | C0 12 C4 12 CC 12 00 | ...............
```

ASM 2.87 `INC/DEC/CMP` opcode rows on 2026-06-08:

```text
make -C SRC asm-test
```

ASM 2.87 adds active rows for `INC`, `DEC`, and `CMP`. `INC` and `DEC`
accept the W65C02 accumulator spelling `INC A`/`DEC A`, plus zero-page,
absolute, zero-page indexed-X, and absolute indexed-X address forms; the
operandless forms remain unsupported. `CMP` adds immediate and the same
non-indirect address forms. The full-core opcode smoke now emits `$A1` bytes,
and the host opcode audit reports `rows=116` and `mnemonics=58`. The host gate
passes with `asm-v1-runtime-paste-2000.s19` total `$2F7D`.

Hardware-proven ASM 2.87 `INC/DEC/CMP` paste emission on 2026-06-08:

```text
HIMON V 00.0607(2103)
L OK=2F7D GO=2000
ASM RT PASTE
ASM> ORG $72A0
OK PC=$72A0
ASM> INC A
OK PC=$72A1
ASM> INC $12
OK PC=$72A3
ASM> INC $0012
OK PC=$72A6
ASM> INC $12,X
OK PC=$72A8
ASM> INC $0012,X
OK PC=$72AB
ASM> DEC A
OK PC=$72AC
ASM> DEC $12
OK PC=$72AE
ASM> DEC $0012
OK PC=$72B1
ASM> DEC $12,X
OK PC=$72B3
ASM> DEC $0012,X
OK PC=$72B6
ASM> CMP #$12
OK PC=$72B8
ASM> CMP $12
OK PC=$72BA
ASM> CMP $0012
OK PC=$72BD
ASM> CMP $12,X
OK PC=$72BF
ASM> CMP $0012,X
OK PC=$72C2
ASM> END
OK PC=$72C2
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK

>D 72A0 72C1
72A0: 1A E6 12 EE 12 00 F6 12 | FE 12 00 3A C6 12 CE 12 | ...........:....
72B0: 00 D6 12 DE 12 00 C9 12 | C5 12 CD 12 00 D5 12 DD | ................
72C0: 12 00 | ..
```

ASM 2.88 `ADC/SBC/AND/ORA` opcode rows on 2026-06-08:

```text
make -C SRC asm-test
```

ASM 2.88 adds active rows for `ADC`, `SBC`, `AND`, and `ORA`, each with
immediate, zero-page, absolute, zero-page indexed-X, and absolute indexed-X
forms. Indirect and indexed-Y forms remain outside this slice. The full-core
opcode smoke now emits `$D1` bytes, and the host opcode audit reports
`rows=136` and `mnemonics=62`. The host gate passes with
`asm-v1-runtime-paste-2000.s19` total `$2FB9`.

Hardware-proven ASM 2.88 `ADC/SBC/AND/ORA` paste emission on 2026-06-08:

```text
>L G
L S19
L @2000
L OK=2FB9 GO=2000
ASM RT PASTE
ASM> ORG $72D0
OK PC=$72D0
ASM> ADC #$12
OK PC=$72D2
ASM> ADC $12
OK PC=$72D4
ASM> ADC $0012
OK PC=$72D7
ASM> ADC $12,X
OK PC=$72D9
ASM> ADC $0012,X
OK PC=$72DC
ASM> SBC #$12
OK PC=$72DE
ASM> SBC $12
OK PC=$72E0
ASM> SBC $0012
OK PC=$72E3
ASM> SBC $12,X
OK PC=$72E5
ASM> SBC $0012,X
OK PC=$72E8
ASM> AND #$12
OK PC=$72EA
ASM> AND $12
OK PC=$72EC
ASM> AND $0012
OK PC=$72EF
ASM> AND $12,X
OK PC=$72F1
ASM> AND $0012,X
OK PC=$72F4
ASM> ORA #$12
OK PC=$72F6
ASM> ORA $12
OK PC=$72F8
ASM> ORA $0012
OK PC=$72FB
ASM> ORA $12,X
OK PC=$72FD
ASM> ORA $0012,X
OK PC=$7300
ASM> END
OK PC=$7300
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
>D 72D0 72FF
72D0: 69 12 65 12 6D 12 00 75 | 12 7D 12 00 E9 12 E5 12 | i.e.m..u.}......
72E0: ED 12 00 F5 12 FD 12 00 | 29 12 25 12 2D 12 00 35 | ........).%.-..5
72F0: 12 3D 12 00 09 12 05 12 | 0D 12 00 15 12 1D 12 00 | .=..............
>
```

ASM 2.89 source-width address contract on 2026-06-08:

```text
make -C SRC asm-test
```

ASM 2.89 makes the zero-page/absolute-width mandate executable in the
full-line smoke. Source spelling is the addressing contract: one-byte hex
addresses are zero-page and four-byte hex addresses are absolute, even when
the numeric value is `$0000`.

```text
ZP_OFFSET0 EQU $00
ABS_OFFSET0 EQU $0000
LDA ZP_OFFSET0   -> A5 00
LDA ABS_OFFSET0  -> AD 00 00
```

The host gate passes with `asm-v1-runtime-paste-2000.s19` total `$2FB9`.
No opcode rows changed; the opcode audit remains `rows=136` and
`mnemonics=62`.

Hardware-proven ASM 2.89 source-width address contract on 2026-06-08:

```text
>L G
L S19
L @2000
L OK=2FB9 GO=2000
ASM RT PASTE
ASM> ORG $7300
OK PC=$7300
ASM> ZP_OFFSET0 EQU $00
OK PC=$7300
ASM> ABS_OFFSET0 EQU $0000
OK PC=$7300
ASM> LDA ZP_OFFSET0
OK PC=$7302
ASM> LDA ABS_OFFSET0
OK PC=$7305
ASM> END
OK PC=$7305
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 0000  01 03 17 0002 01  0004  ZP_OFFSET0
01 01 0000  01 04 17 0003 01  0005  ABS_OFFSET0
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK

#LOADGO# ENTRY=2000
RET A=0F X=AE Y=0F P=75 S=FD NV-BdIzC
>D 7300 7304
7300: A5 00 AD 00 00 | .....
>
```

ASM 2.90 `LDX/LDY/CPX` opcode rows on 2026-06-08:

```text
make -C SRC asm-test
```

ASM 2.90 completes the direct address rows for `LDX`, `LDY`, and `CPX`.
`LDX` now accepts zero-page, absolute, zero-page indexed-Y, and absolute
indexed-Y forms; `LDY` now accepts zero-page, absolute, zero-page indexed-X,
and absolute indexed-X forms; `CPX` now accepts zero-page and absolute forms.
This slice also adds the first `ABS_Y` operand mode so `LDX $0012,Y` remains
source-width exact. The full-core opcode smoke now emits `$EA` bytes, and the
host opcode audit reports `rows=146` and `mnemonics=62`. The host gate passes
with `asm-v1-runtime-paste-2000.s19` total `$2FF4`.

Hardware-proven ASM 2.90 `LDX/LDY/CPX` paste emission on 2026-06-08:

```text
>L G
L S19
L @2000
L OK=2FF4 GO=2000
ASM RT PASTE
ASM> ORG $7320
OK PC=$7320
ASM> LDX #$12
OK PC=$7322
ASM> LDX $12
OK PC=$7324
ASM> LDX $0012
OK PC=$7327
ASM> LDX $12,Y
OK PC=$7329
ASM> LDX $0012,Y
OK PC=$732C
ASM> LDY #$12
OK PC=$732E
ASM> LDY $12
OK PC=$7330
ASM> LDY $0012
OK PC=$7333
ASM> LDY $12,X
OK PC=$7335
ASM> LDY $0012,X
OK PC=$7338
ASM> CPX #$12
OK PC=$733A
ASM> CPX $12
OK PC=$733C
ASM> CPX $0012
OK PC=$733F
ASM> END
OK PC=$733F
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
>D 7320 733E
7320: A2 12 A6 12 AE 12 00 B6 | 12 BE 12 00 A0 12 A4 12 | ................
7330: AC 12 00 B4 12 BC 12 00 | E0 12 E4 12 EC 12 00 | ...............
>
```

ASM 2.91 `JMP` and ABI-style `BRK` opcode rows on 2026-06-08:

```text
make -C SRC asm-test
```

ASM 2.91 adds absolute `JMP` and the HIMON ABI/API trap form `BRK #imm8`.
`BRK` is deliberately not implied in ASM v1: it always emits the trap number
byte after opcode `$00`, making `BRK #$12` emit `00 12`. The full-core opcode
smoke now emits `$EF` bytes, and the host opcode audit reports `rows=148` and
`mnemonics=64`. The host gate passes with `asm-v1-runtime-paste-2000.s19`
total `$2FFA`.

ASM 2.92 mode-row table split on 2026-06-08:

```text
make -C SRC asm-test
```

The first ASM 2.91 board test loaded the `$2FFA` paste image and froze while
assembling `BRK #$12`. NMI reported `PC=29A7`, which mapped into the opcode
mode-row scanner, not the emitted test program. The mode rows had grown past a
single 8-bit `X` scan: after the first 255 data bytes, adding three wrapped the
index and the scanner looped.

ASM 2.92 keeps the same 148 opcode rows but splits the mode-row data into A/B
shards. Rows for one mnemonic must stay in one shard because `BAD_MODE` remains
authoritative once a mnemonic is found. The opcode coverage audit now also
fails if any mode-row shard exceeds the 255-byte scanner limit. The host gate
passes with `asm-v1-runtime-paste-2000.s19` total `$303D`.

Hardware retest target:

```text
ASM> ORG $7340
ASM> JMP $0012
ASM> BRK #$12
ASM> END
>D 7340 7344
7340: 4C 12 00 00 12
```

Hardware-proven ASM 2.92 `JMP/BRK #imm8` paste emission on 2026-06-08:
the board loaded the `$303D` paste image, accepted `JMP $0012` and
`BRK #$12`, finalized through `END`, and dumped `4C 12 00 00 12` at
`$7340-$7344`.

ASM 2.93 bare byte `BRK` alias on 2026-06-08:

```text
make -C SRC asm-test
```

ASM 2.93 accepts both HIMON/WDC trap spellings:

```text
BRK #$12
BRK $12
```

Both forms emit opcode `$00` followed by byte `$12`. This is an opcode-table
alias: `BRK #$12` classifies as `IMM8`, `BRK $12` classifies as `ZP8`, and
both rows map to opcode `$00`. The source-width rule still applies, so
`BRK $0012` is not accepted as this byte trap form. The full-core opcode smoke
now emits `$F1` bytes, and the host opcode audit reports `rows=149` and
`mnemonics=64`. The host gate passes with `asm-v1-runtime-paste-2000.s19`
total `$3040`.

Hardware-proven ASM 2.93 bare byte `BRK` alias on 2026-06-08: the board
loaded the `$3040` paste image, accepted `BRK $12` and `BRK #$13`, finalized
through `END`, and dumped `00 12 00 13` at `$7500-$7503`.

```text
ASM> ORG $7500
ASM> BRK $12
ASM> BRK #$13
ASM> END
>D 7500 750F
7500: 00 12 00 13 00 00 00 00
```

ASM 2.94 `JMP` indirect opcode rows on 2026-06-08:

```text
make -C SRC asm-test
```

ASM 2.94 adds the parenthesized operand classifier modes needed by W65C02
indirect addressing and enables the two remaining `JMP` rows:

```text
JMP ($0012)    -> 6C 12 00
JMP ($0012,X)  -> 7C 12 00
```

The classifier now has distinct modes for zero-page indirect, zero-page
indexed indirect, zero-page indirect indexed, absolute indirect, and absolute
indexed indirect. This slice only adds opcode rows for the absolute `JMP`
forms; zero-page indirect modes are parser groundwork for the later
load/store/ALU indirect slice. The source-width rule still applies: `JMP
($12)` classifies as zero-page indirect and remains unsupported by `JMP`. The
full-core opcode smoke now emits `$F7` bytes, and the host opcode audit reports
`rows=151` and `mnemonics=64`. The host gate passes with
`asm-v1-runtime-paste-2000.s19` total `$31B6`.

Hardware-proven ASM 2.94 `JMP` indirect paste emission on 2026-06-08: the
board loaded the `$31B6` paste image, accepted both indirect `JMP` forms,
finalized through `END`, and dumped `6C 12 00 7C 12 00` at `$7510-$7515`.

```text
ASM> ORG $7510
ASM> JMP ($0012)
ASM> JMP ($0012,X)
ASM> END
>D 7510 7515
7510: 6C 12 00 7C 12 00
```

ASM 2.95 ALU/load/store indirect opcode matrix on 2026-06-08:

```text
make -C SRC asm-test
```

ASM 2.95 enables the compact W65C02 indirect matrix for `ADC`, `SBC`, `AND`,
`ORA`, `EOR`, `CMP`, `LDA`, and `STA`. Each mnemonic now has zero-page
indexed-indirect `($12,X)`, zero-page indirect `($12)`, and zero-page
indirect-indexed `($12),Y` rows. The row set follows the `aaa bbb cc` opcode
shape:

```text
ADC ($12,X) -> 61 12    ADC ($12) -> 72 12    ADC ($12),Y -> 71 12
SBC ($12,X) -> E1 12    SBC ($12) -> F2 12    SBC ($12),Y -> F1 12
AND ($12,X) -> 21 12    AND ($12) -> 32 12    AND ($12),Y -> 31 12
ORA ($12,X) -> 01 12    ORA ($12) -> 12 12    ORA ($12),Y -> 11 12
EOR ($12,X) -> 41 12    EOR ($12) -> 52 12    EOR ($12),Y -> 51 12
CMP ($12,X) -> C1 12    CMP ($12) -> D2 12    CMP ($12),Y -> D1 12
LDA ($12,X) -> A1 12    LDA ($12) -> B2 12    LDA ($12),Y -> B1 12
STA ($12,X) -> 81 12    STA ($12) -> 92 12    STA ($12),Y -> 91 12
```

`STA #imm` still does not exist and is intentionally not added. The full-core
opcode smoke now emits `$0127` bytes, and the host opcode audit reports
`rows=175` and `mnemonics=64`. The host gate passes with
`asm-v1-runtime-paste-2000.s19` total `$31FE`.

Hardware-proven ASM 2.95 indirect matrix paste emission on 2026-06-08: the
board loaded the `$31FE` paste image and proved all 24 indirect rows. The first
paste accidentally omitted `ADC ($12)` at the blank prompt and proved the other
23 rows; the focused follow-up proved `ADC ($12)` as `72 12`.

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7530
OK PC=$7530
ASM> ADC ($12,X)
OK PC=$7532
ASM>
ASM> ADC ($12),Y
OK PC=$7534
ASM> SBC ($12,X)
OK PC=$7536
ASM> SBC ($12)
OK PC=$7538
ASM> SBC ($12),Y
OK PC=$753A
ASM> AND ($12,X)
OK PC=$753C
ASM> AND ($12)
OK PC=$753E
ASM> AND ($12),Y
OK PC=$7540
ASM> ORA ($12,X)
OK PC=$7542
ASM> ORA ($12)
OK PC=$7544
ASM> ORA ($12),Y
OK PC=$7546
ASM> EOR ($12,X)
OK PC=$7548
ASM> EOR ($12)
OK PC=$754A
ASM> EOR ($12),Y
OK PC=$754C
ASM> CMP ($12,X)
OK PC=$754E
ASM> CMP ($12)
OK PC=$7550
ASM> CMP ($12),Y
OK PC=$7552
ASM> LDA ($12,X)
OK PC=$7554
ASM> LDA ($12)
OK PC=$7556
ASM> LDA ($12),Y
OK PC=$7558
ASM> STA ($12,X)
OK PC=$755A
ASM> STA ($12)
OK PC=$755C
ASM> STA ($12),Y
OK PC=$755E
ASM> END
OK PC=$755E
>D 7530 755F
7530: 61 12 71 12 E1 12 F2 12 | F1 12 21 12 32 12 31 12
7540: 01 12 12 12 11 12 41 12 | 52 12 51 12 C1 12 D2 12
7550: D1 12 A1 12 B2 12 B1 12 | 81 12 92 12 91 12 00 00
```

The omitted row was then proved directly:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7555
OK PC=$7555
ASM> ADC ($12)
OK PC=$7557
ASM> END
OK PC=$7557
>D 7555 7557
7555: 72 12 12
```

Only `$7555-$7556` belong to the emitted `ADC ($12)` instruction; `$7557` is
outside the emitted two-byte row and retains prior memory.

ASM 2.96 `STA abs,Y` opcode row on 2026-06-08:

```text
make -C SRC asm-test
```

ASM 2.96 completes the legal W65C02 `STA` row set by adding absolute indexed Y:

```text
STA $0012,Y -> 99 12 00
```

`STA #imm` still does not exist, and `STA $12,Y` is still intentionally not
added because there is no zero-page Y `STA` opcode. The full-core opcode smoke
now emits `$012A` bytes, and the host opcode audit reports `rows=176` and
`mnemonics=64`. The host gate passes with `asm-v1-runtime-paste-2000.s19`
total `$3201`.

Hardware-proven ASM 2.96 `STA abs,Y` paste emission on 2026-06-08: the board
loaded the `$3201` paste image, accepted `STA $0012,Y`, finalized through
`END`, and dumped `99 12 00` at `$7560-$7562`.

```text
>L G
L S19
L @2000
L OK=3201 GO=2000
ASM RT PASTE
ASM> ORG $7560
OK PC=$7560
ASM> STA $0012,Y
OK PC=$7563
ASM> END
OK PC=$7563
>D 7560 7562
7560: 99 12 00
```

ASM 2.97 accumulator/load/compare `abs,Y` opcode rows on 2026-06-08:

```text
make -C SRC asm-test
```

ASM 2.97 completes the absolute indexed Y rows for the accumulator ALU,
`LDA`, and `CMP` mnemonics:

```text
ORA $0012,Y -> 19 12 00
AND $0012,Y -> 39 12 00
EOR $0012,Y -> 59 12 00
ADC $0012,Y -> 79 12 00
LDA $0012,Y -> B9 12 00
CMP $0012,Y -> D9 12 00
SBC $0012,Y -> F9 12 00
```

These pair with the already-proven `STA $0012,Y -> 99 12 00` row. There are
no zero-page Y forms for these mnemonics. The full-core opcode smoke now emits
`$013F` bytes, and the host opcode audit reports `rows=183` and
`mnemonics=64`. The host gate passes with `asm-v1-runtime-paste-2000.s19`
total `$3216`.

Hardware-proven ASM 2.97 `abs,Y` paste emission on 2026-06-08: the board
loaded the `$3216` paste image, accepted all seven rows, finalized through
`END`, and dumped the expected byte stream at `$7570-$7584`.

```text
>L G
L S19
L @2000
L OK=3216 GO=2000
ASM RT PASTE
ASM> ORG $7570
OK PC=$7570
ASM> ORA $0012,Y
OK PC=$7573
ASM> AND $0012,Y
OK PC=$7576
ASM> EOR $0012,Y
OK PC=$7579
ASM> ADC $0012,Y
OK PC=$757C
ASM> LDA $0012,Y
OK PC=$757F
ASM> CMP $0012,Y
OK PC=$7582
ASM> SBC $0012,Y
OK PC=$7585
ASM> END
OK PC=$7585
>D 7570 7584
7570: 19 12 00 39 12 00 59 12 | 00 79 12 00 B9 12 00 D9
7580: 12 00 F9 12 00
```

ASM 2.98 `WAI/STP` opcode rows on 2026-06-08:

```text
make -C SRC asm-test
```

ASM 2.98 enables the two W65C02 implied low-power opcodes:

```text
WAI -> CB
STP -> DB
```

These rows are assembly/emission coverage only. Board proof must assemble and
dump the bytes; do not execute the emitted test program, because `WAI` waits
for interrupt state and `STP` is reset-land. The full-core opcode smoke now
emits `$0141` bytes, and the host opcode audit reports `rows=185` and
`mnemonics=66`. The host gate passes with `asm-v1-runtime-paste-2000.s19`
total `$321A`.

Hardware-proven ASM 2.98 `WAI/STP` paste emission on 2026-06-08: the board
loaded the `$321A` paste image, accepted both implied opcodes, finalized
through `END`, and dumped `CB DB` at `$7590-$7591`.

```text
>L G
L S19
L @2000
L OK=321A GO=2000
ASM RT PASTE
ASM> ORG $7590
OK PC=$7590
ASM> WAI
OK PC=$7591
ASM> STP
OK PC=$7592
ASM> END
OK PC=$7592
>D 7590 7591
7590: CB DB
```

ASM 2.99 `RMB/SMB bit,zp` opcode rows on 2026-06-08:

```text
make -C SRC asm-test
```

ASM 2.99 adds the W65C02 reset/set memory bit syntax accepted by this
assembler:

```text
RMB n,$12 -> (07 + n*10) 12
SMB n,$12 -> (87 + n*10) 12
```

`n` is a resolved bit number from `0` through `7`. The zero-page operand must
still be source-width zero-page: `$12`, a zero-page `EQU`, or a selected
`<SYMBOL` fixup. The full-core opcode smoke now emits `$0145` bytes, and the
host opcode audit reports `rows=201` and `mnemonics=68`. The host gate passes
with `asm-v1-runtime-paste-2000.s19` total `$32F3`.

Hardware-proven ASM 2.99 `RMB/SMB bit,zp` paste emission on 2026-06-08: the
board loaded the `$32F3` paste image, accepted both comma forms, finalized
through `END`, and dumped `37 12 B7 12` at `$75A0-$75A3`.

```text
>L G
L S19
L @2000
L OK=32F3 GO=2000
ASM RT PASTE
ASM> ORG $75A0
OK PC=$75A0
ASM> RMB 3, $12
OK PC=$75A2
ASM> SMB 3,$12
OK PC=$75A4
ASM> END
OK PC=$75A4
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
>D 75A0 75A3
75A0: 37 12 B7 12
```

Minimal retest form:

```text
ASM> ORG $75A0
ASM> RMB 3,$12
ASM> SMB 3,$12
ASM> END
>D 75A0 75A3
75A0: 37 12 B7 12
```

ASM 3.00 `BBR/BBS bit,zp,target` opcode rows on 2026-06-08:

```text
make -C SRC asm-test
```

ASM 3.00 completes the W65C02 bit-memory branch syntax:

```text
BBR n,$12,TARGET -> (0F + n*10) 12 rel8
BBS n,$12,TARGET -> (8F + n*10) 12 rel8
```

`n` is a resolved bit number from `0` through `7`. The zero-page operand must
be resolved source-width zero-page in this slice; the branch target may be
resolved immediately or fixed up from a later label. The full-core opcode smoke
now emits `$014B` bytes, and the host opcode audit reports `rows=217` and
`mnemonics=70`. The host gate passes with `asm-v1-runtime-paste-2000.s19`
total `$33D5`; the standalone smoke also proves an unresolved
`BBR 3,$12,FOO` relative fixup.

Hardware-proven ASM 3.00 `BBR/BBS bit,zp,target` paste emission on
2026-06-08: the board loaded the `$33D5` paste image, accepted both
forward-label bit branches, resolved both fixups as mode `$10`, and dumped
`3F 12 03 BF 12 01 EA EA` at `$75B0-$75B7`.

```text
>L G
L S19
L @2000
L OK=33D5 GO=2000
ASM RT PASTE
ASM> ORG $75B0
OK PC=$75B0
ASM> BBR 3,$12,T0
OK PC=$75B3
ASM> BBS 3,$12,T1
OK PC=$75B6
ASM> T0 NOP
OK PC=$75B7
ASM> T1 NOP
OK PC=$75B8
ASM> END
OK PC=$75B8
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 75B6  01 04 0E 0004 00  0000  T0
01 01 75B7  01 04 0E 0005 00  0000  T1
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 10   00  75B2 75B3 T0
01 02 10   00  75B5 75B6 T1
ASM RT PASTE OK
>D 75B0 75B7
#6999B497# HSH_NF!
>D 75B0 75B7
75B0: 3F 12 03 BF 12 01 EA EA
```

ASM 3.01 transactional line errors on 2026-06-08:

```text
make -C SRC asm-test
```

`ASM_ASSEMBLE_LINE` now checkpoints the active line's PC, high-PC, and table
cursors before lex/parse/dispatch. Recoverable line errors restore that
checkpoint, leave the ASM session active, and return the original status with
the restored PC. Bytes already written to RAM by a failed line are not erased;
they are outside the accepted image after high-PC rollback and the corrected
line overwrites from the restored PC.

The runtime paste wrapper now reprompts after non-`END` assembly errors instead
of quenching RX and returning to HIMON. `END` failure remains finalization
failure: the wrapper still prints tables and returns with the failing status.
The host smoke includes a partial `BBR 3,$12,$9000` range failure followed by a
successful `NOP` at the same start PC. The host gate passes with
`asm-v1-runtime-paste-2000.s19` total `$347E`.

Hardware-proven ASM 3.01 transactional line error recovery on 2026-06-08:
the board loaded the `$347E` paste image, rejected an out-of-range bit branch
at restored PC `$75C0`, stayed at the `ASM>` prompt, accepted `NOP` at the same
PC, finalized cleanly through `END`, and dumped `EA` at `$75C0`.

```text
>L G
L S19
L @2000
L OK=347E GO=2000
ASM RT PASTE
ASM> ORG $75C0
OK PC=$75C0
ASM> BBR 3,$12,$9000
ERR=$06 BAD RANGE PC=$75C0
ASM> NOP
OK PC=$75C1
ASM> END
OK PC=$75C1
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
>D 75C0
75C0: EA | .
>
```

ASM 3.02 transactional fixup-patch rollback on 2026-06-08:

```text
make -C SRC asm-test
```

The line transaction now snapshots pre-existing fixup row states and the two
bytes at each fixup patch site. If a failed line defines a label and resolves
an earlier pending fixup before the later operand/mode check fails, rollback
restores the fixup row to its prior state and restores the patched target
bytes. New fixup rows from the failed line are still removed by restoring
`ASM_FIX_COUNT`.

The host smoke now assembles `BNE FOO`, rejects `FOO STA #$12` as `BAD MODE`
after the label would have resolved the branch, verifies the branch operand is
back to `$FF` and the fixup is pending again, then accepts `FOO NOP` and
verifies the same fixup resolves to offset `$00`. The host gate passes with
`asm-v1-runtime-paste-2000.s19` total `$34F0`.

Hardware-proven ASM 3.02 transactional fixup-patch rollback on 2026-06-08:
the board loaded the `$34F0` paste image, rejected `FOO STA #$12` after the
line had resolved an earlier `BNE FOO`, stayed in ASM at restored PC `$75D2`,
then accepted `FOO NOP`, finalized cleanly, and dumped `D0 00 EA`.

```text
>L G
L S19
L @2000
L OK=34F0 GO=2000
ASM RT PASTE
ASM> ORG $75D0
OK PC=$75D0
ASM> BNE FOO
OK PC=$75D2
ASM> FOO STA #$12
ERR=$04 BAD MODE PC=$75D2
ASM> FOO NOP
OK PC=$75D3
ASM> END
OK PC=$75D3
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 75D2  01 04 0E 0004 00  0000  FOO
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 07   00  75D1 75D2 FOO
ASM RT PASTE OK
>D 75D0 75D2
75D0: D0 00 EA | ...
>
```

Historical retest on 2026-06-09 with HIMON `V 00.0608(1850)`: the board loaded
`asm-v1-runtime-paste-2000.s19` as `L OK=36B8 GO=2000`, repeated the same
rollback sequence, finalized through `END`, printed the `FOO` symbol and mode
`$07` fixup row, and dumped `D0 00 EA` at `$75D0-$75D2`. This is the
transactional rollback proof for that runtime generation.

Historical ASMTEST_3000 proof on 2026-06-09 with the same `$36B8` paste image:
the board accepted the full sample through `END` at `PC=$6827`, ran `G 6800`
to `RET A=0F X=10`, and dumped `$6900-$6910` as
`52 2D 59 4F 52 53 20 41 53 4D 20 54 45 53 54 2E 0F`. This is the minimum
ASMTEST_3000 bench gate proof for that runtime generation.

Historical line-echo proof on 2026-06-09 with the same `$36B8` paste image:
the board accepted `DOC/GUIDES/ASM/SAMPLES/ASM_LINE_ECHO_7000.asm` through
`END` at `PC=$704E`, ran `G 7000`, echoed `?` and `ASM IS COOL` after `=> `,
and returned to HIMON on `.` with `RET A=00 X=00 Y=00`.

Historical bad-input proof on 2026-06-09 with the same `$36B8` paste image:
the board reported `BAD SYM`, `BAD DIR`, `BAD WIDTH`, `BAD RANGE`, `BAD MODE`,
`LOCAL NYI`, and `BAD FIX` for the requested duplicate-symbol, parked-directive,
width/range/mode, local-label, and unresolved-fixup cases.

ASM 3.03 protected output-target guard on 2026-06-09:

```text
make -C SRC asm-test
```

ASM now rejects explicit high output targets at `$7E00+`, protecting the
monitor/debugger/vector/I/O window from runtime-pasted source. The host smoke
checks both direct `ASM_BEGIN $7E00` and source-level `ORG $7E00`; both must
return `BAD RANGE`. At this proof step, the runtime paste image was
`asm-v1-runtime-paste-2000.s19` total `$36FD`.

Hardware-proven ASM 3.03 protected output-target guard on 2026-06-09:
the board loaded the `$36FD` paste image, entered the paste wrapper, rejected
`ORG $7E00` with `ERR=$06 BAD RANGE PC=$7000`, and exited normally on `.`. The
operator also typed `G 2000` while already at `ASM>`, which correctly reported
`BAD MNEM`; that prompt-mismatch artifact is not part of the guard proof.

```text
>L G
L S19
L @2000
L OK=36FD GO=2000
ASM RT PASTE
ASM> G 2000
ERR=$01 BAD MNEM PC=$7000
ASM> ORG $7E00
ERR=$06 BAD RANGE PC=$7000
ASM> .
ASM RT PASTE BYE
>
```

ASM 3.04 mnemonic boundary preflight on 2026-06-09:

```text
make -C SRC asm-test
```

Mnemonic emission now preflights the total opcode+operand byte count before
writing the opcode. A two- or three-byte instruction at `$7DFF` fails with
`BAD RANGE` before any byte is stored, so the line transaction has no partial
opcode to clean up. The host smoke sets `$7DFF` to `$5A`, tries `LDA #$12`, and
verifies `BAD RANGE`, active session state, restored PC/high-water `$7DFF`, and
unchanged `$7DFF`. At this proof step, the runtime paste image was
`asm-v1-runtime-paste-2000.s19` total `$377C`.

Hardware-proven ASM 3.04 mnemonic boundary preflight on 2026-06-09:
the board loaded the `$377C` paste image, planted `NOP` at `$7DFF`, rejected a
later `LDA #$12` at `$7DFF` with `ERR=$06 BAD RANGE PC=$7DFF`, and a manual
HIMON dump confirmed `$7DFF` was still `EA`. A fast pasted dump command lost
its leading `D` during the prompt transition and a later accidental `DORG`
session assembled at the default `$7000`; neither artifact changes the
`$7DFF` proof.

```text
>L G
L S19
L @2000
L OK=377C GO=2000
ASM RT PASTE
ASM> ORG $7DFF
OK PC=$7DFF
ASM> NOP
OK PC=$7E00
ASM> .
ASM RT PASTE BYE
>

>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7DFF
OK PC=$7DFF
ASM> LDA #$12
ERR=$06 BAD RANGE PC=$7DFF
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=57 Y=10 P=75 S=FD NV-BdIzC
>D 7DFF 7DFF
7DFF: EA | .
>
```

ASM 3.05 directive boundary preflight on 2026-06-09:

```text
make -C SRC asm-test
```

`DB` now makes a measuring pass before emission and rejects a whole data row if
its total byte count would cross into `$7E00+`; the measuring pass does not
double-count symbol uses. `DS` now checks the parsed reserve count against the
remaining target room before any initializer bytes or fill bytes are written.
The host smoke extends the `$7DFF` boundary transaction proof to `DB $12,$34`
and `DS 2,$00`, verifying both fail with `BAD RANGE`, preserve active session
state and PC/high-water `$7DFF`, and leave the sentinel byte unchanged. At this
proof step, the runtime paste image was `asm-v1-runtime-paste-2000.s19` total
`$3813`.

Hardware-proven ASM 3.05 directive boundary preflight on 2026-06-09:
the board loaded the `$3813` paste image, planted `NOP` at `$7DFF`, rejected
both `DB $12,$34` and `DS 2,$00` at `$7DFF` with `ERR=$06 BAD RANGE PC=$7DFF`,
and dumped `$7DFF` as the original `EA`.

```text
>L G
L S19
L @2000
L OK=3813 GO=2000
ASM RT PASTE
ASM> ORG $7DFF
OK PC=$7DFF
ASM> NOP
OK PC=$7E00
ASM> .
ASM RT PASTE BYE
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7DFF
OK PC=$7DFF
ASM> DB $12,$34
ERR=$06 BAD RANGE PC=$7DFF
ASM> DS 2,$00
ERR=$06 BAD RANGE PC=$7DFF
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=EA Y=10 P=75 S=FD NV-BdIzC
>D 7DFF 7DFF
7DFF: EA | .
>
```

ASM 3.06 exact-boundary directive positive proof on 2026-06-09:

```text
make -C SRC asm-test
```

The boundary transaction smoke now also proves the legal exact-fit directive
case: `DB $A5` and `DS 1,$5C` at `$7DFF` both succeed, leave the active session
PC/high-water at `$7E00`, and write only the final legal target byte. This keeps
the `$7E00+` guard from accidentally rejecting the last byte of application RAM.
At this proof step, the runtime paste image remained
`asm-v1-runtime-paste-2000.s19` total
`$3813`.

Hardware-proven ASM 3.06 exact-boundary directive positive proof on
2026-06-09: the board reused the `$3813` paste image, accepted both one-byte
`DB $A5` and `DS 1,$5C` at `$7DFF`, reported `OK PC=$7E00` for each, and dumped
the emitted bytes at the final legal target address.

```text
>D 7DFF 7DFF
7DFF: A5 | .
>G 2000
GO 2000
ASM RT PASTE
ASM>
ASM> ORG $7DFF
OK PC=$7DFF
ASM> DB $A5
OK PC=$7E00
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=EA Y=10 P=75 S=FD NV-BdIzC
>D 7DFF 7DFF
7DFF: A5 | .
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7DFF
OK PC=$7DFF
ASM> DS 1,$5C
OK PC=$7E00
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=EA Y=10 P=75 S=FD NV-BdIzC
>D 7DFF 7DFF
7DFF: 5C | \
>
```

ASM 3.07 two-byte exact-fill boundary proof on 2026-06-09:

```text
make -C SRC asm-test
```

The boundary transaction smoke now proves multi-byte exact fills at the top of
the protected target window. Starting at `$7DFE`, `LDA #$12`, `DB $12,$34`, and
`DS 2,$00` all succeed, finish at PC/high-water `$7E00`, and write exactly the
two final legal target bytes. At this proof step, the runtime paste image
remained
`asm-v1-runtime-paste-2000.s19` total `$3813`.

Hardware-proven ASM 3.07 two-byte exact-fill boundary proof on 2026-06-09:
the board loaded the `$3813` paste image, accepted exact-fill two-byte
`LDA #$12`, `DB $12,$34`, and `DS 2,$00` rows at `$7DFE`, reported
`OK PC=$7E00` for each, and dumped the expected bytes at `$7DFE-$7DFF`.
The transcript includes harmless prompt-state artifacts where commands were
typed at HIMON instead of `ASM>`.

```text
>L G
L S19
L @2000
L OK=3813 GO=2000
ASM RT PASTE
ASM> G 2000
ERR=$01 BAD MNEM PC=$7000
ASM> ORG $7DFE
OK PC=$7DFE
ASM> LDA #$12
OK PC=$7E00
ASM> .
ASM RT PASTE BYE
>D 7DFE 7DFF
7DFE: A9 12 | ..
>2000
#D22EA097# HSH_NF!
>ORG $7DFE
#DEF80779# HSH_NF!
>DB $12,$34
#36CE7583# HSH_NF!
>.
#2B0C98F1# HSH_NF!
>G 2000
#6A99B62A# HSH_NF!
>ORG $7DFE
#DEF80779# HSH_NF!
>DB $12,$34
#36CE7583# HSH_NF!
>.
#2B0C98F1# HSH_NF!
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7DFE
OK PC=$7DFE
ASM> LDA #$12
OK PC=$7E00
ASM> .
ASM RT PASTE BYE
>D 7DFE 7DFF
7DFE: A9 12 | ..
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7DFE
OK PC=$7DFE
ASM> DB $12,$34
OK PC=$7E00
ASM> .
ASM RT PASTE BYE
>D 7DFE 7DFF
7DFE: 12 34 | .4
>2000
#D22EA097# HSH_NF!
>ORG $7DFE
#DEF80779# HSH_NF!
>DS 2,$00
#25CE5AC0# HSH_NF!
>.
#2B0C98F1# HSH_NF!
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7DFE
OK PC=$7DFE
ASM> DS 2,$00
OK PC=$7E00
ASM> .
ASM RT PASTE BYE
>D 7DFE 7DFF
7DFE: 00 00 | ..
>
```

ASM 3.08 three-byte exact-fill boundary proof on 2026-06-09:

```text
make -C SRC asm-test
```

The boundary transaction smoke now also proves three-byte exact fills at the top
of the protected target window. Starting at `$7DFD`, `LDA $0012`,
`DB $12,$34,$56`, and `DS 3,$00` all succeed, finish at PC/high-water `$7E00`,
and write exactly `$7DFD-$7DFF`. At this proof step, the runtime paste image
remained
`asm-v1-runtime-paste-2000.s19` total `$3813`.

Hardware-proven ASM 3.08 three-byte exact-fill boundary proof on 2026-06-09:
the board warm-booted HIMON, loaded the `$3813` paste image, accepted exact-fill
three-byte `LDA $0012`, `DB $12,$34,$56`, and `DS 3,$00` rows at `$7DFD`,
reported `OK PC=$7E00` for each, and dumped the expected bytes at
`$7DFD-$7DFF`.

```text
OK
STR8>
G HIMON
BOOT WARM

HIMON V 00.0608(1850)
>L G
L S19
L @2000
L OK=3813 GO=2000
ASM RT PASTE
ASM> ORG $7DFD
OK PC=$7DFD
ASM> LDA $0012
OK PC=$7E00
ASM> .
ASM RT PASTE BYE

#LOADGO# ENTRY=2000
RET A=10 X=EA Y=10 P=75 S=FD NV-BdIzC
>D 7DFD 7DFF
7DFD: AD 12 00 | ...
>G 2000
GO 2000
ASM RT PASTE
ASM>
ASM> ORG $7DFD
OK PC=$7DFD
ASM> DB $12,$34,$56
OK PC=$7E00
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=EA Y=10 P=75 S=FD NV-BdIzC
>D 7DFD 7DFF
7DFD: 12 34 56 | .4V
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7DFD
OK PC=$7DFD
ASM> DS 3,$00
OK PC=$7E00
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=EA Y=10 P=75 S=FD NV-BdIzC
>D 7DFD 7DFF
7DFD: 00 00 00 | ...
>
```

ASM 3.09 three-byte boundary-cross preflight on 2026-06-09:

```text
make -C SRC asm-test
```

The boundary transaction smoke now proves the crossing-by-one negative twin for
three-byte rows. Starting at `$7DFE`, `LDA $0012`, `DB $12,$34,$56`, and
`DS 3,$00` all fail with `BAD RANGE`, preserve active session state and
PC/high-water `$7DFE`, and leave the two legal bytes at `$7DFE-$7DFF`
unchanged. At this proof step, the runtime paste image remained
`asm-v1-runtime-paste-2000.s19` total `$3813`.

Hardware-proven ASM 3.09 three-byte boundary-cross preflight on 2026-06-09:
the board reused the `$3813` paste image, planted sentinel `6D 7E` at
`$7DFE-$7DFF`, rejected crossing three-byte `LDA $0012`, `DB $12,$34,$56`, and
`DS 3,$00` rows at `$7DFE` with `ERR=$06 BAD RANGE PC=$7DFE`, and dumped the
unchanged sentinel after each failure. The transcript includes one malformed
manual dump command, corrected on the following line.

```text
>G 2000
GO 2000
ASM RT PASTE
ASM>
ASM> ORG $7DFE
OK PC=$7DFE
ASM> DB $6D,$7E
OK PC=$7E00
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=EA Y=10 P=75 S=FD NV-BdIzC
>D 7DFE 7DFF
7DFE: 6D 7E | m~
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7DFE
OK PC=$7DFE
ASM> LDA $0012
ERR=$06 BAD RANGE PC=$7DFE
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=EA Y=10 P=75 S=FD NV-BdIzC
>D 7DFEN7DFF
D start [end|+cnt]
>D 7DFE 7DFF
7DFE: 6D 7E | m~
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7DFE
OK PC=$7DFE
ASM> DB $12,$34,$56
ERR=$06 BAD RANGE PC=$7DFE
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=EA Y=10 P=75 S=FD NV-BdIzC
>D 7DFE 7DFF
7DFE: 6D 7E | m~
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7DFE
OK PC=$7DFE
ASM> DS 3,$00
ERR=$06 BAD RANGE PC=$7DFE
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=EA Y=10 P=75 S=FD NV-BdIzC
>D 7DFE 7DFF
7DFE: 6D 7E | m~
>
```

ASM 3.10 boundary range-error same-session recovery on 2026-06-09:

```text
make -C SRC asm-test
```

The boundary transaction smoke now proves that a crossing three-byte
`LDA $0012` failure at `$7DFE` leaves the paste session active and able to
assemble the next legal line at the restored PC. After the `BAD RANGE`, a
same-session `NOP` succeeds at `$7DFE`, advances PC/high-water to `$7DFF`,
writes `EA`, and leaves the sentinel byte at `$7DFF` unchanged. At this proof
step, the runtime paste image remained `asm-v1-runtime-paste-2000.s19` total
`$3813`.

Hardware-proven ASM 3.10 boundary range-error same-session recovery on
2026-06-09: the board reused the `$3813` paste image, planted sentinel `6D 7E`
at `$7DFE-$7DFF`, rejected crossing `LDA $0012` with
`ERR=$06 BAD RANGE PC=$7DFE`, then accepted a same-session `NOP` at the restored
PC and dumped `EA 7E`.

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7DFE
OK PC=$7DFE
ASM> DB $6D,$7E
OK PC=$7E00
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=EA Y=10 P=75 S=FD NV-BdIzC
>D 7DFE 7DFF
7DFE: 6D 7E | m~
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7DFE
OK PC=$7DFE
ASM> LDA $0012
ERR=$06 BAD RANGE PC=$7DFE
ASM> NOP
OK PC=$7DFF
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=EA Y=10 P=75 S=FD NV-BdIzC
>D 7DFE 7DFF
7DFE: EA 7E | .~
>
```

ASM 3.11 directive range-error same-session recovery on 2026-06-09:

```text
make -C SRC asm-test
```

The boundary transaction smoke now proves that crossing three-byte directive
failures at `$7DFE` leave the paste session active and able to assemble the
next legal line at the restored PC. After `DB $12,$34,$56` fails with
`BAD RANGE`, a same-session `NOP` succeeds at `$7DFE`, advances PC/high-water
to `$7DFF`, writes `EA`, and leaves the `$7DFF` sentinel unchanged. The same
recovery path is also checked after `DS 3,$00`. At this proof step, the runtime
paste image remained `asm-v1-runtime-paste-2000.s19` total `$3813`.

Hardware-proven ASM 3.11 directive range-error same-session recovery on
2026-06-09: the board loaded the `$3813` paste image, proved a crossing `DB`
directive can fail with `BAD RANGE` and then accept `NOP` in the same session,
and repeated the same recovery proof for crossing `DS`. The board input used
comma-space directive operands (`DB $12, $23, $34` and `DS 3, $00`), also
exercising that accepted whitespace form.

```text
L G
L S19
L @2000
L OK=3813 GO=2000
ASM RT PASTE
ASM> ORG $7DFE
OK PC=$7DFE
ASM> DB $6E,$7F
OK PC=$7E00
ASM> .
ASM RT PASTE BYE
>D 7DFE 7DFF
7DFE: 6E 7F | n.
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7DFE
OK PC=$7DFE
ASM> DB $12, $23, $34
ERR=$06 BAD RANGE PC=$7DFE
ASM> NOP
OK PC=$7DFF
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=EA Y=10 P=75 S=FD NV-BdIzC
>D 7DFE 7DFF
7DFE: EA 7F | ..
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7DFE
OK PC=$7DFE
ASM> DB $70,$81
OK PC=$7E00
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=EA Y=10 P=75 S=FD NV-BdIzC
>D 7DFE 7DFF
7DFE: 70 81 | p.
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7DFE
OK PC=$7DFE
ASM> DS 3, $00
ERR=$06 BAD RANGE PC=$7DFE
ASM> NOP
OK PC=$7DFF
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=EA Y=10 P=75 S=FD NV-BdIzC
>D 7DFE 7DFF
7DFE: EA 81 | ..
>
```

ASM 3.12 post-exact-fill boundary hard stop on 2026-06-09:

```text
make -C SRC asm-test
```

The boundary transaction smoke now proves that after exact-fill emission reaches
`PC=$7E00`, the active session rejects any further mnemonic or directive
emission. `NOP` at `$7DFF` succeeds and writes `EA`; following `LDA #$12`,
`DB $A5`, and `DS 1,$5C` lines all fail with `BAD RANGE PC=$7E00`, preserve
PC/high-water `$7E00`, and leave `$7DFF` unchanged. At this proof step, the
runtime paste image remained `asm-v1-runtime-paste-2000.s19` total `$3813`.

Hardware-proven ASM 3.12 post-exact-fill boundary hard stop on 2026-06-09:
the board loaded the `$3813` paste image, accepted `NOP` at `$7DFF`, then
rejected subsequent mnemonic and directive emission at `PC=$7E00` with
`ERR=$06 BAD RANGE` while leaving `$7DFF` unchanged.

```text
>L G
L S19
L @2000
L OK=3813 GO=2000
ASM RT PASTE
ASM> ORG $7DFF
OK PC=$7DFF
ASM> NOP
OK PC=$7E00
ASM> LDA #$12
ERR=$06 BAD RANGE PC=$7E00
ASM> DB $A5
ERR=$06 BAD RANGE PC=$7E00
ASM> DS 1,$5C
ERR=$06 BAD RANGE PC=$7E00
ASM> .
ASM RT PASTE BYE

#LOADGO# ENTRY=2000
RET A=10 X=EA Y=10 P=75 S=FD NV-BdIzC
>D 7DFF 7DFF
7DFF: EA | .
>
```

ASM 3.13 post-boundary `END` finalization on 2026-06-09:

```text
make -C SRC asm-test
```

The boundary transaction smoke now proves that the protected-limit hard stop
does not poison finalization. After `NOP` exactly fills `$7DFF` and advances
to `PC=$7E00`, further `LDA #$12`, `DB $A5`, and `DS 1,$5C` emissions fail
with `BAD RANGE PC=$7E00`; a following `END` still succeeds, leaves the session
ended at `PC=$7E00`, and leaves `$7DFF` as `EA`. At this proof step, the
runtime paste image remained `asm-v1-runtime-paste-2000.s19` total `$3813`.

Hardware-proven ASM 3.13 post-boundary `END` finalization on 2026-06-09:
the board loaded the `$3813` paste image, reached `PC=$7E00` with an exact-fill
`NOP`, rejected further mnemonic and directive emission at the protected limit,
then accepted `END`, printed empty tables, returned `ASM RT PASTE OK`, and
left `$7DFF` as `EA`. The board input used the comma-space directive spelling
`DS 1, $5C`.

```text
>L G
L S19
L @2000
L OK=3813 GO=2000
ASM RT PASTE
ASM> ORG $7DFF
OK PC=$7DFF
ASM> NOP
OK PC=$7E00
ASM> LDA #$12
ERR=$06 BAD RANGE PC=$7E00
ASM> DB $A5
ERR=$06 BAD RANGE PC=$7E00
ASM> DS 1, $5C
ERR=$06 BAD RANGE PC=$7E00
ASM> END
OK PC=$7E00
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
>D 7DFF 7DFF
7DFF: EA | .
>
```

ASM 3.14 post-boundary non-emitting `EQU *` on 2026-06-09:

```text
make -C SRC asm-test
```

The boundary transaction smoke now proves that non-emitting symbol definition
remains legal after exact-fill emission reaches `PC=$7E00`. After `NOP`
exactly fills `$7DFF`, the active session rejects further emit attempts with
`BAD RANGE PC=$7E00`, then accepts `LIMIT EQU *`, records `LIMIT=$7E00` as an
absolute address symbol, and finalizes with `END` without changing `$7DFF`. At
this proof step, the runtime paste image remained
`asm-v1-runtime-paste-2000.s19` total
`$3813`.

Hardware-proven ASM 3.14 post-boundary non-emitting `EQU *` on 2026-06-09:
the board loaded the `$3813` paste image, reached `PC=$7E00` with exact-fill
`NOP`, rejected further emit attempts, accepted `LIMIT EQU *`, printed the
`LIMIT` symbol row at value `7E00`, and left `$7DFF` as `EA`.

```text
>L G
L S19
L @2000
L OK=3813 GO=2000
ASM RT PASTE
ASM> ORG $7DFF
OK PC=$7DFF
ASM> NOP
OK PC=$7E00
ASM> LDA #$12
ERR=$06 BAD RANGE PC=$7E00
ASM> DB $A5
ERR=$06 BAD RANGE PC=$7E00
ASM> DS 1,$5C
ERR=$06 BAD RANGE PC=$7E00
ASM> LIMIT EQU *
OK PC=$7E00
ASM> END
OK PC=$7E00
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7E00  01 04 16 0006 00  0000  LIMIT
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
>D 7DFF 7DFF
7DFF: EA | .
>
```

ASM 3.15 post-boundary label-only binding on 2026-06-09:

```text
make -C SRC asm-test
```

The boundary transaction smoke now proves the label-only twin of the
post-boundary `EQU *` case. After exact-fill emission reaches `PC=$7E00` and
further emit attempts fail with `BAD RANGE`, `LIMIT EQU *` and a following
label-only `AFTER` line both succeed without writing memory. Both symbols are
recorded as absolute address symbols at `7E00`, and `END` finalizes without
changing `$7DFF`. At this proof step, the runtime paste image remained
`asm-v1-runtime-paste-2000.s19` total `$3813`.

Hardware-proven ASM 3.15 post-boundary label-only binding on 2026-06-09:
the board loaded the `$3813` paste image, reached `PC=$7E00`, accepted both
`LIMIT EQU *` and label-only `AFTER`, printed both symbols at value `7E00`, and
left `$7DFF` as `EA`.

```text
>L G
L S19
L @2000
L OK=3813 GO=2000
ASM RT PASTE
ASM> ORG $7DFF
OK PC=$7DFF
ASM> NOP
OK PC=$7E00
ASM> LDA #$12
ERR=$06 BAD RANGE PC=$7E00
ASM> DB $A5
ERR=$06 BAD RANGE PC=$7E00
ASM> DS 1,$5C
ERR=$06 BAD RANGE PC=$7E00
ASM> LIMIT EQU *
OK PC=$7E00
ASM> AFTER
OK PC=$7E00
ASM> END
OK PC=$7E00
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7E00  01 04 16 0006 00  0000  LIMIT
01 01 7E00  01 04 0E 0007 00  0000  AFTER
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
>D 7DFF 7DFF
7DFF: EA | .
>
```

ASM 3.16 post-boundary duplicate-label recovery:

```text
make -C SRC asm-test
```

The boundary transaction smoke now repeats the label-only `AFTER` line after
`LIMIT EQU *` and the first `AFTER` have both bound at `PC=$7E00`. The second
`AFTER` must fail with `BAD SYM`, leave the active session at `PC=$7E00`, keep
the symbol count at two, preserve the exact-fill byte at `$7DFF`, and allow a
following `END` to finalize with the original `LIMIT` and `AFTER` symbols.

Hardware-proven ASM 3.16 post-boundary duplicate-label recovery on 2026-06-09:
the board loaded the `$3813` paste image, reached `PC=$7E00`, accepted
`LIMIT EQU *` and the first label-only `AFTER`, rejected the duplicate `AFTER`
with `BAD SYM PC=$7E00`, then finalized with one `LIMIT` row and one `AFTER`
row at `7E00`. `$7DFF` remained the exact-fill `EA`.

```text
>L G
L S19
L @2000
L OK=3813 GO=2000
ASM RT PASTE
ASM> ORG $7DFF
OK PC=$7DFF
ASM> NOP
OK PC=$7E00
ASM> LIMIT EQU *
OK PC=$7E00
ASM> AFTER
OK PC=$7E00
ASM> AFTER
ERR=$08 BAD SYM PC=$7E00
ASM> END
OK PC=$7E00
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7E00  01 04 16 0003 00  0000  LIMIT
01 01 7E00  01 04 0E 0004 00  0000  AFTER
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
>D 7DFF 7DFF
7DFF: EA | .
```

ASM 3.17 post-boundary duplicate-`EQU` recovery:

```text
make -C SRC asm-test
```

The boundary transaction smoke now repeats `LIMIT EQU *` after the first
post-boundary `EQU *` succeeds at `PC=$7E00`. The second `LIMIT EQU *` must
fail with `BAD SYM`, leave the active session at `PC=$7E00`, keep the symbol
count at one, preserve `$7DFF=EA`, and allow the remaining non-emitting symbol
checks plus `END` to recover.

Hardware-proven ASM 3.17 post-boundary duplicate-`EQU` recovery on
2026-06-09: the board loaded the `$3813` paste image, accepted the first
post-boundary `LIMIT EQU *`, rejected the duplicate `LIMIT EQU *` with
`BAD SYM PC=$7E00`, then finalized with one `LIMIT` row at `7E00` and left
`$7DFF` as `EA`. The extra `ASM> L G` line was a prompt-mismatch artifact
typed while already inside ASM; it failed as `BAD MNEM PC=$7000` before the
proof sequence began.

```text
>L G
L S19
L @2000
L OK=3813 GO=2000
ASM RT PASTE
ASM> L G
ERR=$01 BAD MNEM PC=$7000
ASM> ORG $7DFF
OK PC=$7DFF
ASM> NOP
OK PC=$7E00
ASM> LIMIT EQU *
OK PC=$7E00
ASM> LIMIT EQU *
ERR=$08 BAD SYM PC=$7E00
ASM> END
OK PC=$7E00
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7E00  01 04 16 0004 00  0000  LIMIT
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
>D 7DFF 7DFF
7DFF: EA | .
>
```

Hardware-proven ASM 3.02 long RAM `$7800` paste/run proof on 2026-06-08:
the already-loaded `$34F0` paste image accepted a longer practical program at
`ORG $6600`, reserved/used data at `ORG $7800`, finalized at `PC=$7905`, and
then ran from `$6600`. The program fills `$7800-$78FF` with `X EOR #$A5`,
verifies the bytes, computes an 8-bit sum, and prints a hex/ascii dump through
resident `BIO_FTDI_WRITE_BYTE_BLOCK`. The accepted version keeps output helper
routines local and calls them by absolute address, avoiding the current small
local-reference and fixup-table limits hit by earlier exploratory versions.

Key board output:

```text
ASM> ORG $6600
OK PC=$6600
... long program accepted ...
ASM> ORG $7800
OK PC=$7800
ASM> DS $FF,$00
OK PC=$78FF
ASM> DB $00
OK PC=$7900
ASM> DS 5,$00
OK PC=$7905
ASM> END
OK PC=$7905
ASM TABLES
SYMBOLS
... 12 symbols, including MAIN/FILL/VER/DUMP/HLOOP/ALOOP ...
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 07   00  6601 6602 MAIN
01 02 07   00  6692 6693 VOK
02 02 07   00  6730 6731 ADOT
03 02 07   00  6734 6735 ADOT
04 02 07   00  6739 673A ANEXT
ASM RT PASTE OK
>G 6600
GO 6600

RAM7800 TEST
SUM=80 FAIL=00
... 16 lines of $7800-$78FF hex/ascii dump ...
DONE

#GO# ENTRY=6600
RET A=0A X=00 Y=30 P=77 S=FD NV-BdIZC
>
```

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
asm-directives-smoke-transient-3000.a
                         hardware-proven EQU/DB/DW/DS and small fixup smoke
pack40-roundtrip-transient-2000.a self-contained PACK40 pack/unpack oracle
pack40-interactive-transient-2000.a
                         hardware-proven interactive PACK40 pack/unpack
                         exerciser
bank3-erase-8000-bfff-transient-3000.a
                         bank 3 $8000-$BFFF erase tool using STR8 service;
                         S19 target: make -C SRC bank3-erase
life-rjoined-6800.asm   8x8 interactive Life through ASM/RJOIN
local-label-stress-7400.asm
                         exact 8-local scope/reuse/?prefix stress sample
local-label-stress-7400-test.md
                         board script for the local-label stress slice
rjoin-hash-stats-7200.asm
                         line length/XOR/FNV stats through ASM/RJOIN
rjoin-hash-stats-7200-test.md
                         board script for the hash-stats slice
biorhythm-2000.asm
                         biorhythm-style phase chart through flash ASM/RJOIN
biorhythm-2000-test.md
                         board script for the biorhythm slice
```

Hardware-proven RJOIN hex-nibble conversion target:

```text
fresh HIMON build should expose UTL_HEX_ASCII_TO_NIBBLE_FNV
current map proof: UTL_HEX_ASCII_TO_NIBBLE_FNV=$E5B7, entry=$E5C3, text=$E5EC
current S19 proof: ADD714B1 is K05 (`46 4E D6 B1 14 D7 AD 05`)
fresh ASM build resolves hash $ADD714B1 during ASM_RJOIN_INIT
fresh ASM runtime-paste image should load as `L OK=3F1F GO=2000`

G 2000
ASM RT PASTE
        ORG $7600
OUT0    EQU $7100
OUT1    EQU $7101
OUT2    EQU $7102
        LDA #$0f
        STA OUT0
        LDA #$A5
        STA OUT1
        LDX #$09
        STX OUT2
        RTS
DATA    DB $00,$09,$0a,$0F,$a5
        END
G 7600
D 7100 7102
expect 0F A5 09
D 7610 7614
expect 00 09 0A 0F A5

negative check:
G 2000
ASM RT PASTE
        ORG $7620
        LDA #$1234
expect ERR=$06 BAD RANGE
```

The 2026-06-10 board proof updated HIMON, booted `HIMON V 00.0610(1937)`,
loaded the current ASM paste image with `L OK=3EED GO=2000`, assembled the
sample through `ASM RT PASTE OK`, ran `G 7600`, and confirmed the runtime
oracle. `$7100-$7102` contained `0F A5 09`, and `$7610-$7614` contained
`00 09 0A 0F A5`. This proves the resident
`UTL_HEX_ASCII_TO_NIBBLE` path for `$` hex operands and `DB $xx` data on
hardware. A follow-up board check showed `LDA #$1234` reports
`ERR=$06 BAD RANGE PC=$7620`, matching the current immediate overflow policy.

Current K05 service-record smoke target:

```text
flash/load HIMON V 00.0610(2012) or newer
enter # to list resident records

expect these active K05 rows:
20285B85 ... 05 READ BYTE
379FE930 ... 05 WRITE BYTE
43621C9C ... 05 READ CH
F91947F8 ... 05 READ ECHO
B85E3F10 ... 05 READ COOK
ADD714B1 ... 05 HEX NIB
7142DD21 ... 05 BYTE HEX
D4C88B87 ... 05 NIB HEX

UTL_HEX_ASCII_YX_TO_BYTE_FNV is K05 in source with text HEX BYTE, but is not
currently forced resident in the active HIMON image.
```

The 2026-06-10 board proof ran `# K=5` and confirmed the active service rows:
`READ BYTE`, `WRITE BYTE`, `READ CH`, `READ ECHO`, `READ COOK`, `HEX NIB`,
`BYTE HEX`, and `NIB HEX`. It also confirmed existing K05 rows `HASH ACQUIRE`,
`HASH OPEN`, `HASH MIX`, `READ LINE`, and `PUT CSTR` remained visible.

`local-label-stress-7400.asm` is the current hardware-proven local-label board
proof. It starts at `$7400` and writes its oracle to `$7100-$710C`; no resident
calls are needed. The `MAIN` scope deliberately consumes exactly eight local
rows with `.A` through `.G` plus `.ABCDEFGHIJKLMN`, where the long local name is
15 visible characters including the prefix. `ONE` and `TWO` both reuse `.LOOP`
and `.DONE`, proving that the local table is scoped and reopened at each
nonlocal label. `ALT` uses the alternate `?NAME` local prefix with both forward
and backward references.

Hardware-proven local-label stress target:

```text
follow local-label-stress-7400-test.md
paste local-label-stress-7400.asm through ASM RT PASTE
expect MAIN=$7400 ONE=$744D TWO=$7462 ALT=$7477 PC=$7489
G 7400
D 7100 710C
expect A1 B2 C3 D4 E5 F6 07 8F 03 00 2A 03 5C
```

The 2026-06-10 board proof assembled the sample through `ASM RT PASTE OK`,
reported only four global symbols (`MAIN`, `ONE`, `TWO`, and `ALT`), and kept
fixups to rows `00-0D` under the `$18` ceiling. Runtime returned from `G 7400`
with `RET A=5C X=03 Y=00`, and `D 7100 710C` produced
`A1 B2 C3 D4 E5 F6 07 8F 03 00 2A 03 5C`.

`rjoin-hash-stats-7200.asm` is the next small real-work board proof. It starts
at `$7200`, predefines the data addresses with `EQU`, emits code first, then
moves forward to `$7500` for strings and `$7600` for the `$40` byte input
buffer. It exits on `Q` or `.`. All external calls are resident executable
names resolved through ASM/RJOIN:
`BIO_FTDI_PUT_CSTR`,
`SYS_READ_CSTRING_ECHO_UPPER`, `FNV1A_INIT`, `FNV1A_UPDATE_A_FAST`, and
`BIO_FTDI_WRITE_BYTE_BLOCK`. The program deliberately uses local labels in
three scopes (`HASH`, `NIB`, and `MAIN`) plus forward and backward local
branches. Predefining data addresses keeps the fixup table focused on
code/control flow instead of string and buffer addresses, while keeping `ORG`
monotonic.

Hardware-proven RJOIN hash-stats target:

```text
follow rjoin-hash-stats-7200-test.md
paste rjoin-hash-stats-7200.asm through ASM RT PASTE
expect END OK with only internal control-flow fixups
G 7200
enter HELLO
expect LEN=05 XOR=42 FNV=32543B0B
enter R-YORS
expect LEN=06 XOR=68 FNV=E48E4383
enter Q or .
expect BYE and return to HIMON
```

The accepted 2026-06-10 board proof re-entered the current `$3EF4`
`ASM RT PASTE` image with `G 2000`, assembled the final source shape through
`END`, and printed the expected table sanity:
`MAIN=$7200`, `DONE=$722E`, `HASH=$7236`, `NIB=$725A`, `HEX=$726A`,
`SHOW=$7278`, final `PC=$7640`, and eight internal control-flow fixups. Runtime
checks matched the expected outputs for `HELLO` and `R-YORS`, then `Q` printed
`BYE` and returned to HIMON.

A later 2026-06-10 cold-boot board proof started from `G F000`, reached
`BOOT COLD` / `RAM ZERO OK`, reloaded the same `$3EF4` paste image with
`L S19` / `L @2000`, assembled the committed sample with the same symbol/fixup
table sanity, reached the live `TEXT>` prompt after `G 7200`, produced the
expected `HELLO` and `R-YORS` hashes, and returned to HIMON on `Q`. That proves
the clean boot/load/assemble/full-runtime path for the committed sample.

`biorhythm-2000.asm` is the current flash-ASM interactive real-work sample. It
starts at `$2000`, reads a day number with `SYS_READ_CSTRING_ECHO_UPPER`, prints
with `BIO_FTDI_PUT_CSTR` and `BIO_FTDI_WRITE_BYTE_BLOCK`, and draws physical,
emotional, and intellectual phase lines for periods 23, 28, and 33. The sample
uses helper-first source order so most internal `JSR/JMP` targets are already
bound before use. The first board attempt used main-first source order and
filled all 24 fixup rows before `JSR OUTA`, failing clearly as
`ERR=$09 BAD FIX PC=$2126`. A later helper-first attempt on the JSR-only
resident resolver still failed at `END` with 19/24 fixups because
`JMP BIO_FTDI_WRITE_BYTE_BLOCK` and `JMP BIO_FTDI_PUT_CSTR` were not yet
resident-lookup eligible. Current ASM uses `ASM_FIX_MAX=$80` and allows direct
resident `JMP name` as well as `JSR name`.

Hardware-proven biorhythm target:

```text
flash current asm-v1-flash-8000.s19 with L F
expect LF OK WR=2D6B GO=800C
enter >ASM
paste biorhythm-2000.asm
expect ASM FLASH OK
expect SYMBOL rows 00-16 and FIXUP rows 00-10, all resolved
G 2000
enter 172, 173, 174, 175, Q
expect DAY $AC, $AD, $AE, $AF charts, then BYE and HIMON return
```

This proof confirms the current resident `JMP name` lookup path because the
accepted image contains the tail wrappers `OUTA JMP BIO_FTDI_WRITE_BYTE_BLOCK`
and `CRLF ... JMP BIO_FTDI_PUT_CSTR` with no pending resident fixups at `END`.
The `0`, `11`, `23`, and `256` cases remain good deterministic follow-up checks
for the low-day chart and overflow rejection.

The first hardware attempt on `HIMON V 00.0610(1344)` usefully failed the
earlier sample shape: forward string/buffer references filled all 24 fixup rows
before `MAIN`, and double-quoted `DB` strings returned `BAD OPER`. The current
sample uses byte/character-list `DB`.

The second board attempt showed the other side of the same shaping rule:
emitting data first and then issuing `ORG $7200` returned `BAD RANGE`, because
ASM v1 requires monotonic `ORG`. The code therefore assembled at `$7640`, and
`G 7200` executed data bytes. The current sample fixes that by defining data
addresses as `EQU`, assembling executable code at `$7200`, then moving forward
to emit the `$7500/$7600` data.

`life-rjoined-6800.asm` is a deliberately table-budgeted full-program sample
for the current ASM v1 ceiling. The current flash-safe source starts at
`$2000`, uses RJOIN for `BIO_FTDI_WRITE_BYTE_BLOCK` and
`PIN_FTDI_READ_BYTE_NONBLOCK`, keeps its visible board at `$7800`, its next
board at `$7840`, and uses user zero page `$30-$3B`. The current version has no
neighbor, seed, glyph, or random-density tables; it computes the 8x8 torus
neighbors in code and initializes the glider in code. Controls are `N` or space
for next, `R` for random, and `Q` to return. The random seed in `$34` stirs
while waiting for a key, then an 8-bit LFSR fills the board on `R`.

The 2026-07-04 flash-ASM board attempt with the earlier fixed-address table
shape usefully failed: `ORG $7000`, `ORG $7200`, and `ORG $7240` all returned
`ERR=$06 BAD RANGE` because current flash ASM protects `$6000-$7EFF` from
assembly output. The current sample fixes that by replacing those fixed table
addresses with computed-neighbor code and code-initialized seed/glyph/random
logic. A follow-up inline-table attempt assembled and ran into
`SEAL ERR=$02 FLAGS=$09`, proving the 16-row relocation metadata table can
truncate even when the fixup table has plenty of room. The current table-free
shape seals below that relocation cap. Its first board run then found the
computed-neighbor loop's `BNE SLOOP` was out of rel8 range from `$213B` to
`$2085`; the source now uses `BEQ SDONE` plus absolute `JMP SLOOP`. It still
uses `$7800/$7840` only at runtime after leaving ASM. The fixed-branch version
is board-proven on 2026-07-04: `SEAL OK FLAGS=$01 BASE=$2000 END=$21D1`,
`SEAL REL @=$611C COUNT=$0F`, initial glider, deterministic `N` stepping,
random `R`, and `Q` return.

The earlier hardware transcripts
`2026-06-09 ASM Current $3813 Life Sample Paste Assembly` and
`2026-06-09 ASM Current $3813 Life Sample Runtime` prove the prior
non-interactive revision; `2026-06-09 ASM Current $3CB1 Interactive Life Paste
and Random Run` proves that interactive/random revision on hardware.
The first interactive attempt used reserved word `START` as an entry label and
correctly failed `BAD DIR`; the source now uses `MAIN`.
The next `$3CAB` board attempt accepted `MAIN` but failed `END` because fixup
name slot 8 aliased slot 0 text, changing the first unresolved `MAIN` fixup
name to `R8S`; the core now carries `slot >> 3` into
`ASM_SET_FIX_NAME_PTR_X`.

The interactive/random slice originally opened the ASM table ceilings to:

```text
ASM_SYM_MAX=$20
ASM_FIX_MAX=$20
ASM_REF_MAX=$40
ASM_LOCAL_MAX=$08
ASM_LOCAL_NAME_MAX=$10
```

The current flash ASM image uses the larger interactive-sample ceilings:

```text
ASM_SYM_MAX=$40
ASM_FIX_MAX=$80
ASM_REF_MAX=$C0
ASM_LOCAL_MAX=$10
ASM_LOCAL_NAME_MAX=$10
```

The 2026-06-15 hardware run in `DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md` proves
`pack40-interactive-transient-2000.a` with those limits. It accepted 30 globals and 74
resolved fixup rows through `END`, then verified `P HELLO -> D432584D`,
`U D432584D -> HELLO`, `_`, `HELLO_`, and `HELLO_GOODBYE` round trips. The
negative paths rejected bare menu text, empty pack/hex input, and invalid `:`.

The first `asm-directives-smoke-transient-3000.a` board paste exposed that
`DB <DATA,>DATA,<ENDD,>ENDD` with PC labels still fails as `BAD WIDTH` in the
current flash ASM image. The sample now uses `DW DATA,ENDD` after both labels
are known for its address-word check, while forward operand/local fixups still
come from the executable code.

The revised board run proves the corrected sample: 14 globals, 3 resolved
fixups, 2 locals, `ASM FLASH OK`, `G 3000` returning `A=AC`, and copied bytes
at `$3100` through `$3118` matching the sample's expected directive image.

The standalone smoke path now includes a fixup-name slot-8 pointer check so
the expanded fixup table cannot silently wrap row 8 onto row 0 again. The same
host smoke now proves local labels by assembling a forward `BRA .SKIP`, binding
`.SKIP` inside `MAIN`, opening `NEXT` after resolution, and rejecting a second
sample where unresolved `.MISS` would cross into `NEXT`.

### ASM 4.20 Bad Samples

Bad samples prove error handling and stop-on-first-error behavior.

Required bad cases:

```text
BAD_LINE       source line longer than 63 visible chars
BAD_SYM        duplicate symbol, reserved word as label, EQU without name,
               local label/reference before a global scope, or local EQU
BAD_MNEM       pending label followed by non-vocabulary operation
BAD_DIR        parked directive used in v1
BAD_OPER       missing operand, extra operand, malformed parentheses
BAD_WIDTH      LDA 12, $123, unknown bare DB ADDR
BAD_RANGE      LDA #$1234, branch out of range, bit number 8
BAD_MODE       LDA A, unsupported classified operand mode
BAD_FIX        unresolved required fixup at END, unresolved local at scope close
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
.LOOP ?LOOP        -> WORD LOCAL_PREFIX
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

The standalone `START` smoke path now checks `LDA`, active `DB`, active `DC`,
`A`, active `ENTRY`, ordinary-label `START`, and `FOO`. V1 stores the
vocabulary row slot as the compact id until the emitter needs a separate
opcode-family id.

Required fixtures:

```text
LDA -> VOC_MNEM
DB  -> VOC_DIR
DC  -> VOC_DIR
A   -> VOC_REG
ENTRY -> VOC_DIR
START -> VOC_NONE with C=0,A=OK
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
DC C,"OK"             -> DIR/DC, PC-binding string directive
START                 -> LABEL_ONLY
A LDA #1              -> BAD SYM
.LOOP                 -> LABEL_ONLY with LOCAL_NAME flag
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

Current seed/service-vector ASM supersedes the ASM 2.57 fallback policy for the
`$8000` ASM/no-header direction. Non-flash runtime still requires `$7E00/$7E01`
to hold a ROM-space `HASH ACQUIRE` seed and no longer carries the local scanner
bootstrap. HIMON publishes the current `THE_JOIN_EXEC_XY` addr16 there during
common init, so the seed follows the resident joiner if HIMON moves it.

Flash ASM extends the seed with a versioned HIMON service vector block at
`$7E02-$7E1C`: signature `R Y`, version `$01`, count `$0B`, then resident
vectors for join, byte output, C-string output, hex-byte output, CRLF, line
input, hex-nibble conversion, FNV init, FNV update, character uppercase, and
HB-string output. `$7E1C` holds an XOR checksum over `$7E02-$7E1B`; XOR over
`$7E02-$7E1C` must be `$00`. `ASM_RJOIN_INIT` in the flash profile validates
the block and copies the contiguous vector bytes into its local cache instead
of resolving those services by FNV on every startup.

Current HIMON also publishes a compatibility extension outside that checked
block at `$7E25-$7E2C`: `$7E25/$7E26` hold the flash-install copy service, and
`$7E27-$7E2C` are its source, destination, and length request cells. Keeping
this outside the `$7E02-$7E1C` checksum preserves the original count `$0B`
service block while allowing `INSTALL pkg flash_addr` to call back into HIMON's
proven flash byte writer.

The 2026-07-04 HB-string host proof ran `make -C SRC asm-test`,
`make -C SRC himon-rom-bin`, and the focused `make -C SRC all`; the maps showed
`asm-v1-flash-8000` ending at `_END_DATA=$BC72` with `$038E` below `$C000`,
and `himon-rom-c000` ending at `_END_DATA=$EB83` with `$047D` below `$F000`.

The current HB-string service build shifts the HIMON service routine targets.
A fresh `D 7E00 7E1C` after boot should show:

```text
7E00: 62 DA 52 59 01 0B 62 DA | 02 DF AA E1 AE E1 A6 E1 | b.RY..b.........
7E10: 86 D0 BE E1 0E DD 88 DD | 15 D1 21 D1 9C | ..........!..
```

Hardware-proven current HB-string vector block on 2026-07-04 with HIMON
`V 00.0703(2255)` after STR8 `UPDATE HIMON C000-EFFF`: the board dump matched
the current host map, including count `$0B`, HB-string vector `$D121`, and
checksum `$9C`. The initial `ASM` command before loading the `$8000` image
correctly returned `HSH_NF!` because the ASM FNV record was not resident yet.
After `L F`, the image loaded as `$3C72` and `ASM` entered the flash wrapper.

```text
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
.............................................................................................................................................................................................................................................................................................................................................................
PROGRAM C000-EFFF? Y: y...
OK
STR8>
G HIMON
BOOT WARM

HIMON V 00.0703(2255)
>D 7E00 FF
7E00: 62 DA 52 59 01 0B 62 DA | 02 DF AA E1 AE E1 A6 E1 | b.RY..b.........
7E10: 86 D0 BE E1 0E DD 88 DD | 15 D1 21 D1 9C 00 00 00 | ..........!.....
>ASM
#56AD7400# HSH_NF!
>L F
L F S19
L @8000
LF OK WR=3C72 GO=800C
>D 7E00 FF
7E00: 62 DA 52 59 01 0B 62 DA | 02 DF AA E1 AE E1 A6 E1 | b.RY..b.........
7E10: 86 D0 BE E1 0E DD 88 DD | 15 D1 21 D1 9C 00 00 00 | ..........!.....
>ASM
ASM FLASH
ASM>
```

The same board then changed `$7E05` from `$0B` to `$0C`. Since `$0C` is still
above the required vector count, the following `EXEC ERR=$0B` proves the XOR
checksum path for the current HB-string service block rather than only the
count-minimum guard.

```text
ASM> LDA #$0C
OK PC=$2002
ASM> STA $7E05
OK PC=$2005
ASM> RTS
OK PC=$2006
ASM> .
ASM FLASH BYE
>G 2000
GO 2000

#GO# ENTRY=2000
RET A=0C X=30 Y=30 P=75 S=FD NV-BdIzC
>D 7E00 FF
7E00: 62 DA 52 59 01 0C 62 DA | 02 DF AA E1 AE E1 A6 E1 | b.RY..b.........
7E10: 86 D0 BE E1 0E DD 88 DD | 15 D1 21 D1 9C 00 00 00 | ..........!.....
>ASM
#56AD7400# EXEC ERR=$0B
>
```

A companion board proof on the same HIMON build verifies the HB-string output
path used by the flash wrapper, table headers, and seal reporter. After `END`,
ASM printed `ASM TABLES`; `SEAL` printed the seal summary and record lines; and
the wrapper returned cleanly on `.`.

```text
HIMON V 00.0703(2255)
>
>ASM
ASM FLASH
ASM> LDA #$44
OK PC=$2002
ASM> STA $7E05
OK PC=$2005
ASM> RTS
OK PC=$2006
ASM> END
OK PC=$2006
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM FLASH OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$2000 END=$2006
SEAL REC @=$6111 LEN=$0006 FNV=$A293B7A8
SEAL REL @=$611C COUNT=$00
SEAL> .
ASM FLASH BYE
>
```

The matching board proof on `HIMON V 00.0703(2026)` warm-booted from STR8,
dumped the service vector block, loaded `asm-v1-flash-8000.s19`, accepted
lowercase `org`, assembled a tiny program, and ran it from RAM. This vector
dump matched the pre-reporter host map byte-for-byte:

```text
STR8>
G HIMON
BOOT WARM

HIMON V 00.0703(2026)
>D 7E00 7E19
7E00: 53 DA 52 59 01 0A 53 DA | CC DE 74 E1 78 E1 70 E1 | S.RY..S...t.x.p.
7E10: 77 D0 88 E1 D8 DC 52 DD | 06 D1 | w.....R...
>L F
L F S19
L @8000
LF OK WR=3C94 GO=800C
>ASM
ASM FLASH
ASM> ORG $2000
OK PC=$2000
ASM> LDA #$5A
OK PC=$2002
ASM> STA $7100
OK PC=$2005
ASM> RTS
OK PC=$2006
ASM> END
OK PC=$2006
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM FLASH OK
SEAL> G 2000
ERR=$03 BAD OPER PC=$2006
SEAL> .
ASM FLASH BYE
>G 2000
GO 2000

#GO# ENTRY=2000
RET A=5A X=30 Y=30 P=75 S=FD NV-BdIzC
>D 7100
7100: 5A | Z
>M 7E05
M PROT=$7E05
```

This proves the service-vector ABI, the appended uppercase vector, flash ASM
startup through the copied vectors, the post-`END` command boundary, and the
protected `$7E05` service-count cell.

The same board then ran a deliberate service-count corruption proof. ASM
rejected `STA 7E05` without `$` as a bad operand, accepted `STA $7E05`, emitted
a RAM program that writes `$09` to the service-count byte, and returned from
that program with `A=$09`. A following `ASM` command did not enter `ASM FLASH`,
proving flash ASM rejects a service block whose count is below the required
`$0B` in the current HB-string service build. The first proof was captured
before HIMON reported failed external hash command returns. With the follow-up
diagnostic, the expected failed ASM command
prints `#56AD7400# EXEC ERR=$0B` before returning to the HIMON prompt. This is
expected: the monitor memory editor protects `$7E05`, but a running RAM program
can still modify RAM. A warm/cold HIMON init restores the service vector block.

```text
ASM
ASM FLASH
ASM> LDA #$09
OK PC=$2002
ASM> STA 7E05
ERR=$03 BAD OPER PC=$2002
ASM> STA $7E05
OK PC=$2005
ASM> RTS
OK PC=$2006
ASM> .
ASM FLASH BYE
>G 2000
GO 2000

#GO# ENTRY=2000
RET A=09 X=30 Y=30 P=75 S=FD NV-BdIzC
>ASM
>ASM
>
```

Expected with the external hash-command failure reporter:

```text
>ASM
#56AD7400# EXEC ERR=$0B
>
```

The same diagnostic is expected after any single-byte corruption in
`$7E02-$7E1C`, including a vector byte or the checksum byte, because flash ASM
verifies the XOR checksum before copying the service vectors.

Hardware-proven reporter/checksum proof on `HIMON V 00.0703(2230)` after STR8
`UPDATE HIMON C000-EFFF`: that update stream booted, `$7E1A` held the
then-current checksum `$65`, `asm-v1-flash-8000.s19` loaded as `$3CA2`, flash
ASM entered normally, then a RAM program changed `$7E05` from `$0A` to `$FF`.
Because `$FF` is still greater than the required vector count, this specifically
proves the checksum path rather than only the count-minimum path. The next
`ASM` command printed the external hash-command failure report with ASM's
service/RJOIN status `$0B`.

```text
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
.............................................................................................................................................................................................................................................................................................................................................................
PROGRAM C000-EFFF? Y: y...
OK
STR8>
G HIMON
BOOT WARM

HIMON V 00.0703(2230)
>D 7E00 7EFF
7E00: 60 DA 52 59 01 0A 60 DA | 00 DF A8 E1 AC E1 A4 E1 | `.RY..`.........
7E10: 84 D0 BC E1 0C DD 86 DD | 13 D1 65 00 00 00 00 00 | ..........e.....
>L F
L F S19
L @8000
LF OK WR=3CA2 GO=800C
>ASM
ASM FLASH
ASM> .
ASM FLASH BYE
>ASM
ASM FLASH
ASM> LDA #$FF
OK PC=$2002
ASM> STA $7E05
OK PC=$2005
ASM> RTS
OK PC=$2006
ASM> .
ASM FLASH BYE
>G 2000
GO 2000

#GO# ENTRY=2000
RET A=FF X=30 Y=30 P=F5 S=FD NV-BdIzC
>D 7E00 7EFF
7E00: 60 DA 52 59 01 FF 60 DA | 00 DF A8 E1 AC E1 A4 E1 | `.RY..`.........
7E10: 84 D0 BC E1 0C DD 86 DD | 13 D1 65 00 00 00 00 00 | ..........e.....
>ASM
#56AD7400# EXEC ERR=$0B
>
```

After the deliberate corruption, running HIMON from STR8 restored the service
vector block and flash ASM entered normally again:

```text
>HIMON
RUN HIMON: V 00.0703(2026) @C000 K=03 ? y
BOOT WARM

HIMON V 00.0703(2026)
>ASM
ASM FLASH
ASM>
```

On 2026-06-09, the earlier `$FFF8/$FFF9` flash-pocket policy failed after a
board was updated with STR8 `UPDATE HIMON C000-EFFF`. The board booted
`HIMON V 00.0609(1739)`, loaded `ASM RT PASTE` at `$2000`, and failed before
`BEGIN` because STR8 `U` does not touch the top sector:

```text
L OK=3EF4 GO=2000
ASM RT PASTE
BEGIN=$0B

#LOADGO# ENTRY=2000
RET A=0B X=FF Y=FF P=F4 S=FD NV-BdIzc
```

Current host proof must include `make -C SRC asm-test` plus a HIMON build whose
map shows both the RAM-published seed cell and `THE_JOIN_EXEC_XY`. Current board
proof should check the RAM cell, then load ASM:

```text
>D 7E00 7E01
expect low/high bytes of THE_JOIN_EXEC_XY, currently 8E DE
>L G
L S19
send BUILD/s19/asm-v1-runtime-paste-2000.s19
expect ASM RT PASTE to reach BEGIN and accept source
```

Hardware on `HIMON V 00.0609(1904)` reached `ASM RT PASTE`, accepted `.`, and
dumped `$7E00: 8E DE`, proving the RAM seed path after a STR8 HIMON-only update.
A later broad opcode/addressing paste failed at the 33rd named operand reference
with `ERR=$09 BAD FIX`; that was the report-reference ceiling, not the seed.
That slice raised `ASM_REF_MAX` to `$40` without adding table storage; the
current flash ASM image uses `ASM_REF_MAX=$C0`.

The lower-reference board opcode/addressing smoke then assembled at `$7200`,
resolved seven fixups, ran from `$7200`, and dumped the expected oracle:

```text
7100: 80 33 22 33 44 55 81 99 | 4F | .3"3DU..O
```

This proves the RAM-seeded ASM path can assemble and run bit branches,
selected-byte immediates, absolute indexed, zero-page indexed, zero-page
indirect, accumulator shift/rotate, forward `JSR`, absolute indirect `JMP`, and
absolute-X indirect `JMP` emission in one board paste.

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
$5D DB/DW/ORG/DS directive smoke
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
$AD imported DB/DW data relocation rows were wrong
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
$C7 forward DB/DW label fixup or relocation row was wrong
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
$D6 DW emit failed
$D7 emitted DW bytes were wrong
$D8 DW PC/high-water was wrong
$D9 empty DW did not fail BAD OPER
$DD DC C/HB/P string emit failed
$DE empty HB string did not fail BAD OPER
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
```

`Y` is `ASM_SLOT`, the last fixed-vocabulary slot touched by lookup. `$FF`
means no vocabulary match. Slot kinds are `MNEM`, `DIR`, `REG`, and `RES`
for reserved/parked words. `IMPORT` reuses the old `$20 ENTRY` slot and
`ENTRY` reuses the old `$43 START` slot so opcode ids remain stable:

| Slot | Slot | Slot | Slot |
| --- | --- | --- | --- |
| $00 A REG | $15 CMP MNEM | $2A LDX MNEM | $3F SED MNEM |
| $01 ADC MNEM | $16 CPX MNEM | $2B LDY MNEM | $40 SEI MNEM |
| $02 AND MNEM | $17 CPY MNEM | $2C LSR MNEM | $41 SMB MNEM |
| $03 ASL MNEM | $18 DB DIR | $2D NOP MNEM | $42 STA MNEM |
| $04 BBR MNEM | $19 DC DIR | $2E ORA MNEM | $43 ENTRY DIR |
| $05 BBS MNEM | $1A DEC MNEM | $2F ORG DIR | $44 STP MNEM |
| $06 BCC MNEM | $1B DEX MNEM | $30 PHA MNEM | $45 STX MNEM |
| $07 BCS MNEM | $1C DEY MNEM | $31 PHP MNEM | $46 STY MNEM |
| $08 BEQ MNEM | $1D DS DIR | $32 PHX MNEM | $47 STZ MNEM |
| $09 BIT MNEM | $1E DW DIR | $33 PHY MNEM | $48 TAX MNEM |
| $0A BMI MNEM | $1F END DIR | $34 PLA MNEM | $49 TAY MNEM |
| $0B BNE MNEM | $20 IMPORT DIR | $35 PLP MNEM | $4A TRB MNEM |
| $0C BPL MNEM | $21 EOR MNEM | $36 PLX MNEM | $4B TSB MNEM |
| $0D BRA MNEM | $22 EQU DIR | $37 PLY MNEM | $4C TSX MNEM |
| $0E BRK MNEM | $23 EXPORT DIR | $38 RMB MNEM | $4D TXA MNEM |
| $0F BVC MNEM | $24 INC MNEM | $39 ROL MNEM | $4E TXS MNEM |
| $10 BVS MNEM | $25 INX MNEM | $3A ROR MNEM | $4F TYA MNEM |
| $11 CLC MNEM | $26 INY MNEM | $3B RTI MNEM | $50 WAI MNEM |
| $12 CLD MNEM | $27 JMP MNEM | $3C RTS MNEM | $51 X REG |
| $13 CLI MNEM | $28 JSR MNEM | $3D SBC MNEM | $52 Y REG |
| $14 CLV MNEM | $29 LDA MNEM | $3E SEC MNEM | |

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

The standalone `START` smoke path now checks resolved expression math used by
`ORG` and `EQU`: one-atom values, current-PC `*`, known session symbols, and
strict left-to-right `+`/`-` over concrete values/addresses. This is the
current executable expression boundary:

```text
WORKS
ORG and EQU expression tails
DW expression lists
single atoms: decimal, hex, char, binary/mask, known symbol, *
binary + and - between concrete VALUE and ADDR terms
left-to-right evaluation only
ADDR + VALUE, VALUE + ADDR, and ADDR - VALUE
ADDR - ADDR returning a VALUE/NONE delta
VALUE + VALUE and VALUE - VALUE
ZP/ABS address width is retained and range-checked
bad concrete arithmetic reports BAD RANGE or BAD WIDTH

DOES NOT WORK YET
mnemonic operand-tail math such as LDA $12+1 or BNE TARGET-2
DB/DS list expression math such as DB BASE+1
forward or unresolved addends such as FOO+1
forward EQU dependency chains
logical/mask operators |, &, ^
selector-plus-addend combinations such as <FOO+1 or >FOO+1
unary minus such as -1
grouping parentheses or precedence
```

Raw operand-tail math, DB/DS list expressions, selectors combined with
addends, logical/mask operators, forward `EQU` chains, and fixup addends remain
future expression work.

Current smoke fixtures:

```text
10                    -> VALUE/NONE
$12                   -> ADDR/ZP
$0012                 -> ADDR/ABS
'A'                   -> VALUE/BYTE
%XXXXXXX1             -> MASK/MASK8
*                     -> ADDR/ABS current PC
$0012+1               -> ADDR/ABS $0013
$12+1                 -> ADDR/ZP $13
$0012-$0011           -> VALUE/NONE $0001
$FF+1                 -> BAD RANGE
$12 $34               -> BAD OPER
```

Additional same-rule examples that the current concrete `+`/`-` evaluator
handles:

```text
* - 32                -> ADDR/ABS if in range
BASE+1                -> works after BASE is already defined
END_ADDR-START_ADDR   -> VALUE/NONE delta after both labels are defined
10+1                  -> VALUE/NONE $000B
```

Hardware-proven board proof:

```text
DOC/GUIDES/ASM/SAMPLES/expr-math-transient-7010.a
DOC/GUIDES/ASM/SAMPLES/expr-math-7010-test.md
```

The accepted HIMON `V 00.0615(2131)` / `ASM FLASH` transcript proves
`ORG $7000+16`, `OUT+1`/`OUT+2`/`OUT+3`, `BASE+1`,
`END_ADDR-START_ADDR = $000F`, immediate `#<NEXT`/`#>NEXT`, and
`DB <NEXT,>NEXT,SIZE`. The table report shows `SIZE=$000F`, `DATA=$7025`,
and no fixups. The dump shows the emitted `$7010-$7027` code/data oracle:
`A9 5A 8D 00 71 A9 02 8D 01 71 A9 00 8D 02 71 A9 0F 8D 03 71 60 02 00 0F`,
and `G 7010` returned normally with `A=$0F`. A follow-up `D 7100 FF` dump
showed the direct runtime oracle at `$7100-$7103`: `5A 02 00 0F`. The
same proof was retested on HIMON `V 00.0630(2008)` with `G 7010` followed by
`D 7000 71FF`, again showing the emitted bytes and `$7100-$7103 = 5A 02 00 0F`.
The same HIMON `V 00.0630(2008)` cold-boot proof also verified the
backward-`ORG` negative path: after `ORG $7000+16` reached `PC=$7010`,
`ORG $7000` reported `ERR=$06 BAD RANGE PC=$7010`. A top-level `>ASM NEW`
entry reached the same flash wrapper behavior and repeated the same result.

This sample deliberately avoids `A`, `X`, and `Y` as user symbols because they
are reserved v1 register words. It stages address math through `EQU` names
instead of unsupported operand-tail math such as `STA OUT+1`.

Future fixtures:

```text
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
ADDR - ADDR returns a VALUE delta
ADDR +/- VALUE keeps ADDR width and range-checks it
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
RMB 3,$12  -> BIT_ZP
BBR 3,$12,TARGET -> BIT_ZP_REL
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
LDY #$4D     -> A0 4D
STZ $7110    -> 9C 10 71
STA $7100,X  -> 9D 00 71
EOR $7110    -> 4D 10 71
STA $7110    -> 8D 10 71
INX          -> E8
CPX #COUNT   -> E0 10
BNE LOOP     -> D0 EB when LOOP is a resolved backward label
RTS          -> 60
LSR / LSR A  -> 4A
LSR $12      -> 46 12
LSR $0012    -> 4E 12 00
LSR $12,X    -> 56 12
LSR $0012,X  -> 5E 12 00
ROL / ROL A  -> 2A
ROL $12      -> 26 12
ROL $0012    -> 2E 12 00
ROL $12,X    -> 36 12
ROL $0012,X  -> 3E 12 00
ROR / ROR A  -> 6A
ROR $12      -> 66 12
ROR $0012    -> 6E 12 00
ROR $12,X    -> 76 12
ROR $0012,X  -> 7E 12 00
BIT #$12     -> 89 12
BIT $12      -> 24 12
BIT $0012    -> 2C 12 00
BIT $12,X    -> 34 12
BIT $0012,X  -> 3C 12 00
CLC          -> 18
CLD          -> D8
CLI          -> 58
CLV          -> B8
SEC          -> 38
SED          -> F8
SEI          -> 78
NOP          -> EA
DEX          -> CA
DEY          -> 88
INY          -> C8
TAX          -> AA
TAY          -> A8
TSX          -> BA
TXA          -> 8A
TXS          -> 9A
TYA          -> 98
PHA          -> 48
PHP          -> 08
PHX          -> DA
PHY          -> 5A
PLA          -> 68
PLP          -> 28
PLX          -> FA
PLY          -> 7A
RTI          -> 40
STZ #0       -> BAD MODE at opcode lookup
```

The standalone `START` smoke emits this resolved byte stream into
`ASM_CODE_BUF` and compares every byte:

```text
A2 00 A0 4D 9C 10 71 9D 00 71 4D 10 71 8D 10 71
E8 E0 10 D0 EB 60 4A 4A 46 12 4E 12 00 56 12 5E 12 00
2A 2A 26 12 2E 12 00 36 12 3E 12 00
6A 6A 66 12 6E 12 00 76 12 7E 12 00
89 12 24 12 2C 12 00 34 12 3C 12 00
18 D8 58 B8 38 F8 78
EA CA 88 C8 AA A8 BA 8A 9A 98 48 08 DA 5A 68 28
FA 7A 40
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

### ASM 2.30-2.35 Directives

Current DB fixture:

```text
ADDR EQU $1234
SEED DB $FF,10,'A',$1234,<ADDR,>ADDR
```

Current DW fixture:

```text
WORD DW $1234,$12,10+1,'A'
```

Current forward data fixture:

```text
DB FWD,<FWD,>FWD
DW FWD
FWD RTS
```

Current DC fixture:

```text
CSTR DC C,"OK"
HBSTR DC HB,"OK"
PSTR DC P,"OK"
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

Current DB/DC/DW/ORG/DS acceptance:

```text
DB emits byte/word by source/symbol width
bare DB/DW forward symbols emit fixups and patch when the label is bound
empty DB is BAD OPER
DB emits FF 0A 41 34 12 34 12 for the current fixture
DW emits each expression as a little-endian word
DW emits 34 12 12 00 0B 00 41 00 for the current fixture
empty DW is BAD OPER
DC C emits bytes plus trailing 00
DC HB emits bytes with bit 7 set on the final byte
DC P emits count byte then bytes
empty DC HB string is BAD OPER
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
ASM 2.48 captures clean-END seal span facts in RAM:
         base, exclusive end, and length = end - base.
ASM 2.49 tracks seal ineligibility bits without rejecting ordinary ASM:
         forward ORG hole and plain DS count/unowned bytes.
ASM 2.50 adds the first post-session SEAL dry-run:
         accepts only FLAGS=$01; ERR=$01 means no clean END/valid bit clear;
         ERR=$02 means valid but not seal-eligible because FLAGS != $01.
         Runtime paste/flash wrappers switch to SEAL> after clean END until ".".
SEAL.NEW adds validated SEAL> NEW:
         accepts only NEW or NEW ; comment, asks no Y/N question, and reopens
         ASM at the frozen END PC.
SEAL.REC adds a RAM-only record after successful SEAL validation:
         first line prints FLAGS/BASE/END, second line prints REC @, LEN, FNV32.
         FNV32 hashes exactly the emitted bytes from BASE through END-1.
SEAL.REC.RAM gives the contiguous record bytes an exported ASM_SEAL_REC label:
         flags, base lo/hi, end lo/hi, len lo/hi, fnv0..fnv3.
SEAL.REC.PRINT factors the success printer into ASM_SEAL_PRINT_RECORD so
         runtime paste and flash wrappers share the same SEAL OK/REC output.
ASMRP.UDATA moves runtime-paste PC/post cells out of DATA into UDATA. It also
         replaces the fixed ASMRP_RESULT scratch cell with UDATA. This removes
         loaded bytes from the SEAL.REC image and avoids a fixed scratch
         address such as $6800, which remains used by older documented ASMTEST
         paths.
SEAL.RELOC adds a separate RAM relocation record:
         ASM_RELOC_REC starts with COUNT, then parallel arrays for kind,
         site offset, and target offset. The base internal kinds are $01
         ABS16_INTERNAL, $02 LO8_INTERNAL, and $03 HI8_INTERNAL; import
         slices extend the same table with $04/$05/$06. Runtime paste/flash
         SEAL success prints SEAL REL @=$hhhh COUNT=$nn after SEAL REC.
SEAL.EXPORT adds EXPORT NAME for defined global labels and emits a compact
         PACK40 sealed export record. Runtime paste/flash SEAL success prints
         SEAL EXP @=$hhhh COUNT=$nn LEN=$00nn only when exports exist.
SEAL.IMPORT adds IMPORT NAME as compact PACK40 metadata for intended external
         symbols. Runtime paste/flash SEAL success prints
         SEAL IMP @=$hhhh COUNT=$nn LEN=$00nn only when imports exist.
SEAL.IMPORT.FIXUP tags matching unresolved global operands and converts
         eligible full-width two-byte import fixups into `$04` ABS16_IMPORT
         relocation rows at END. The emitted operand remains `$FF/$FF`; the
         relocation target low byte carries the import slot index.
SEAL.IMPORT.BYTESEL accepts selected-byte declared imports: `#<NAME` records
         `$05` LO8_IMPORT and `#>NAME` records `$06` HI8_IMPORT. The emitted
         placeholder byte remains `$FF`; target low still carries the import
         slot index.
SEAL.IMPORT.FORCE.DEFER makes explicit `IMPORT NAME` win over resident RJOIN
         after the session table misses. Plain undeclared resident `JSR`/`JMP`
         still RJOINs and binds now; declared uses of that same resident name
         emit placeholders and import relocation rows.
SEAL.IMPORT.RESOLVE adds post-END `SEAL> RESOLVE` as a RAM-body proof command.
         It resolves `$04/$05/$06` import relocation rows through current
         resident RJOIN, patches the emitted body in place, and reports
         `RESOLVE OK COUNT=$nn` for patched rows.
SEAL.RAM.RELOCATE adds post-END `SEAL> RELOCATE address` as the first RAM
         overlay move proof. It copies the frozen sealed body to the requested
         RAM base, applies only `$01/$02/$03` internal relocation rows there,
         and reports `RELOCATE OK BASE=$hhhh COUNT=$nn`. Imports remain
         separate and can still be handled by `RESOLVE`.
ASMRT.REPORT.TRIM keeps the older compact-report printer in the core/smoke
         build but compiles it out of ASM_RUNTIME_ONLY images. Runtime paste
         and flash use wrapper error lines, ASM TABLES, and SEAL REC/REL as
         the board-facing report surface.
ASMRP.TARGET.7600 moves the runtime-paste default emit target from $7000 to
         $7600. The report trim reduced the paste load image by $0308 bytes,
         but explicit ORG $7000 could still overlap live runtime data until
         ASMRT.OVERLAP_GUARD made that a BAD RANGE error.
ASMRT.SIZE.UDATA_BUF moves ASM_RUNTIME_ONLY ASM_CODE_BUF from loaded DATA to
         UDATA. Full core/smoke builds keep the $0200 loaded smoke buffer;
         runtime-paste keeps a $0100 RAM-only default buffer. Flash ASM uses
         an explicit $2000 start and only keeps an 8-byte guard fence below
         the $7F00 I/O page.
ASMRT.SIZE.SEAL_CLEAR replaces the manual ASM_SEAL_REC/ASM_RELOC_COUNT clear
         list with an indexed clear over the same bytes.
ASMRT.SIZE.CMD_MATCH factors paste/flash SEAL, END, and NEW recognizers around
         shared leading-whitespace and tail validators. SEAL/NEW keep strict
         no-operand behavior; END keeps the existing wrapper detection rule.
ASMRT.OVERLAP_GUARD rejects output target spans that overlap the live ASM
         runtime workspace before any byte is written. RAM-loaded runtime/core
         images guard $2000..ASM_CODE_BUF-1; the flash wrapper guards
         $6000..ASM_CODE_BUF-1. Runtime-paste ASM_CODE_BUF remains a valid
         fallback output buffer; flash ASM_CODE_BUF is only a guard fence
         because flash ASM begins at explicit $2000.
ASMRP.TARGET.DEFAULT makes runtime-paste start with ASM_BEGIN's default
         ASM_CODE_BUF instead of a fixed high-RAM target. The IMPORT metadata
         slice grew runtime workspace past $7600, so the old fixed target
         failed as BEGIN=$06 with X/Y reporting $7600. Do not replace it with
         another fixed high-RAM target: $7800-$79FF is now user/patchable RAM,
         while $7A00-$7EFF is monitor workspace. Let ASM choose ASM_CODE_BUF
         and enforce overlap guards.
ASMRP.SIZE.CMD_BUF reuses HIMON CMD_BUF at $7A00 as the runtime-paste input
         line buffer instead of reserving a private $0100 UDATA page. This is
         valid for L G / G 2000 because HIMON has yielded the console while ASM
         runs, and HIMON overwrites CMD_BUF with the next monitor command after
         the wrapper returns.
SEAL.WRAP is requirements-only for now:
         a future WRAP batch command must hard-stop or quench on validation,
         record, export, or install failure before it can be used as a
         multi-chunk paste primitive.
Numeric report fields are hex in this first W65C02S printer.
Second clean ASM_END returns OK without duplicating report state.
```

Required report facts:

```text
status
error line/status/token when failed
start/current/high-water PC
bytes emitted/reserved
clean-END seal span facts
seal ineligibility flags
relocation row count and RAM table address
symbol/fixup/ref counts and limits
unresolved fixups
used symbols with lines
unused session symbols
resident symbols referenced later
```

Acceptance:

```text
core/smoke compact-report build: first clean END can print compact report
core/smoke compact-report build: first failure can print error and compact report
core/smoke compact-report build: report overflow sets TRUNC=YES
core/smoke compact-report build: used symbol report prints count and first reference line
core/smoke compact-report build: unused symbol report prints definition lines
clean END leaves a valid RAM fact record matching START/HIGH/BYTES
forward ORG and plain DS count set seal flags but remain valid ASM
initialized DS count,$xx remains seal-owned
post-session SEAL reports FLAGS/BASE/END and rejects every FLAGS value except $01
eligible post-session SEAL reports SEAL REC @/LEN/FNV after validation
eligible post-session SEAL fills ASM_SEAL_REC with flags/base/end/len/FNV bytes
eligible post-session SEAL reports SEAL REL @/COUNT after validation
eligible post-session SEAL reports SEAL EXP @/COUNT/LEN when exports exist
eligible post-session SEAL reports SEAL IMP @/COUNT/LEN when imports exist
EXPORT accepts exactly one defined global PC label operand
EXPORT rejects unknown names, local names, EQU symbols, duplicates, leading
labels, and table overflow as BAD SYM
EXPORT rejects extra operands as BAD OPER
IMPORT accepts exactly one global word operand and records PACK40 metadata
IMPORT rejects local names, reserved words, duplicates, leading labels, and
table overflow as BAD SYM
IMPORT rejects extra operands as BAD OPER
declared IMPORT ABS16 fixups succeed at END as imported relocation rows
declared IMPORT selected-byte fixups succeed at END as imported relocation rows
declared IMPORT operands keep `$FF` or `$FF/$FF` placeholders until a later
linker fills them
relative, undeclared, and local unresolved fixups still fail END as BAD FIX
ASM TABLES prints a RELOCS section with SL/K/SITE/TARG rows
internal label ABS16 references produce $01 relocation rows with site/target
offsets from BASE
internal label #< and #> references produce $02/$03 relocation rows
declared import ABS16 references produce $04 relocation rows with SITE as a
BASE-relative offset and TARG low as the import slot
declared import #< and #> references produce $05/$06 relocation rows with SITE
as a BASE-relative offset and TARG low as the import slot
explicit IMPORT of a resident RJOIN name still produces $04/$05/$06 import
relocation rows instead of freezing today's resident address
plain undeclared resident JSR/JMP operands still RJOIN and produce no import
relocation rows
SEAL> RESOLVE resolves declared import relocation rows through current resident
RJOIN and patches the current RAM body in place
SEAL> RESOLVE operands are rejected as BAD OPER without clearing frozen seal
facts
SEAL> RELOCATE address copies the frozen RAM body to the requested destination
and patches internal `$01/$02/$03` rows against that destination base
SEAL> RELOCATE reports RELOCATE OK BASE=$hhhh COUNT=$nn on success or
RELOCATE ERR=$ee on failure and stays at SEAL>
SEAL> RELOCATE rejects missing or extra operands as BAD OPER without clearing
frozen seal facts
SEAL> RELOCATE does not resolve `$04/$05/$06` import rows
SEAL> PACKAGE address writes an AP v1 package envelope in full-core/flash ASM
builds, self-verifies the written BODY FNV, and reports PACKAGE OK @=$hhhh
LEN=$hhhh
SEAL> PACKAGE rejects missing or extra operands as BAD OPER without clearing
frozen seal facts
SEAL> CHECK address validates an AP v1 package envelope in full-core or
package-check diagnostic builds and reports CHECK OK @=$hhhh LEN=$hhhh
SEAL> CHECK rejects missing or extra operands as BAD OPER without clearing
frozen seal facts
runtime paste deliberately omits PACKAGE until the package/load/install path
has a smaller board-resident command shape
runtime paste and default flash ASM deliberately omit CHECK after the board
proof so package/load/install work has room below `$C000`
relative branches, EQU constants, and fixed external addresses produce no
relocation rows
relocation table overflow keeps ordinary ASM valid but sets a seal-ineligible
FLAGS bit
ineligible post-session SEAL reports no SEAL REC line
clean END switches runtime paste/flash wrappers to the SEAL> prompt
SEAL> NEW prints OK PC=$end and returns to ASM> at the frozen END PC
SEAL> NEW operands are rejected as BAD OPER without clearing frozen seal facts
SEAL> RESOLVE prints RESOLVE OK COUNT=$nn on success or RESOLVE ERR=$ee on
failure and stays at SEAL>
ASM> SEAL remains ordinary ASM source, not a wrapper command
ASM> NEW remains ordinary ASM source, not a wrapper command
ASM> RESOLVE remains ordinary ASM source, not a wrapper command
ASM> RELOCATE remains ordinary ASM source, not a wrapper command
ASM> PACKAGE remains ordinary ASM source, not a wrapper command
ASM> CHECK remains ordinary ASM source, not a wrapper command
post-END commands outside the wrapper command set are rejected without clearing
frozen seal facts
runtime paste wrapper keeps the same prompts and SEAL behavior with mutable
state/result cells in UDATA and the input line borrowed from HIMON CMD_BUF
runtime paste wrapper default session starts at ASM_CODE_BUF, not a fixed $7600
runtime-only ASM_CODE_BUF is UDATA and no longer contributes loaded S19 bytes
SEAL> NEW after a prior SEAL clears stale record/FNV/reloc-count state
SEAL/NEW post-session commands accept leading whitespace and trailing comments
SEAL/NEW post-session commands reject operands as BAD OPER
explicit ORG $7000 is not a safe current runtime-paste board-test target
future WRAP failure prints one compact error and stops or quenches input before
later source can be read as SEAL> commands
```

Expected `SEAL.REC.RAM` tiny-span record bytes after sealing `ORG $7000`,
`LDA #$5A`, `RTS`, `END`:

```text
ASM_SEAL_REC: 01 00 70 03 70 03 00 6E 14 5B 69
```

Expected first-pass relocation table for a clean span at `$7000` with:

```text
START JMP TARGET
      LDA #<TARGET
      LDA #>TARGET
TARGET RTS
END
```

The emitted body is `4C 07 70 A9 07 A9 70 60`, and the reloc rows are:

```text
COUNT=$03
row 0: kind=$01 site=$0001 target=$0007
row 1: kind=$02 site=$0004 target=$0007
row 2: kind=$03 site=$0006 target=$0007
```

Hardware-proven `SEAL.RELOC` internal relocation rows on 2026-07-01 with
`asm-v1-runtime-paste-2000.s19`. The test assembled this source at `$7000`:

```text
ORG $7000
MAIN JMP TARGET
LDA #<TARGET
LDA #>TARGET
TARGET RTS
END
```

The session resolved all three forward fixups and printed the expected
relocation rows:

```text
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 04   00  7001 7003 TARGET
01 02 02   01  7004 7005 TARGET
02 02 02   02  7006 7007 TARGET
RELOCS
SL K  SITE TARG
00 01 0001 0007
01 02 0004 0007
02 03 0006 0007
```

The successful post-session `SEAL` reported the body facts and relocation-table
address:

```text
SEAL OK FLAGS=$01 BASE=$7000 END=$7008
SEAL REC @=$549D LEN=$0008 FNV=$1013A74B
SEAL REL @=$54A8 COUNT=$03
```

The emitted body and first record bytes matched expectations:

```text
549D: 01 00 70 08 70 08 00 4B | A7 13 10 03 01 02 03 00 | ..p.p..K........
54AD: 00 00 00 | ...
54A8: 03 01 02 03 00 00 00 00 | ........
7000: 4C 07 70 A9 07 A9 70 60 | 00 00 | L.p...p`..
```

Here `$549D-$54A7` is the `$0B`-byte `ASM_SEAL_REC`, `$54A8` is
`ASM_RELOC_REC`, byte `$54A8=$03` is the relocation count, and
`$54A9-$54AB = 01 02 03` are the first three kind entries.
Follow-up dumps proved the remaining parallel arrays:

```text
54B9: 01 04 06 | ...    site_lo
54C9: 00 00 00 | ...    site_hi
54D9: 07 07 07 | ...    target_lo
54E9: 00 00 00 | ...    target_hi
```

Hardware-proven relocation classifier shrink on 2026-07-01 with HIMON
V 00.0630(2121) and `asm-v1-runtime-paste-2000.s19`
`L OK=543B GO=2000`. This build derives `ABS16_INTERNAL` relocation kind from
the mode patch-width table instead of a handwritten absolute-mode list. The
board proof assembled all five full-width absolute operand forms without
changing the relocation rows:

```text
ORG $7000
JMP TARGET
LDA TARGET,X
LDA TARGET,Y
JMP (TARGET)
JMP (TARGET,X)
TARGET RTS
END
```

The resolved fixups and relocation rows were:

```text
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 04   00  7001 7003 TARGET
01 02 06   00  7004 7006 TARGET
02 02 09   00  7007 7009 TARGET
03 02 0D   00  700A 700C TARGET
04 02 0E   00  700D 700F TARGET
RELOCS
SL K  SITE TARG
00 01 0001 000F
01 01 0004 000F
02 01 0007 000F
03 01 000A 000F
04 01 000D 000F
```

The successful post-session `SEAL` and dumps were:

```text
SEAL OK FLAGS=$01 BASE=$7000 END=$7010
SEAL REC @=$5495 LEN=$0010 FNV=$C3D3B3AE
SEAL REL @=$54A0 COUNT=$05

7000: 4C 0F 70 BD 0F 70 B9 0F | 70 6C 0F 70 7C 0F 70 60 | L.p..p..pl.p|.p`
5495: 01 00 70 10 70 10 00 AE | B3 D3 C3 05 01 01 01 01 | ..p.p...........
54A5: 01 | .
54A0: 05 01 01 01 01 01 | ......
```

The same run exposed a runtime-paste overlap hazard for future board tests:
after this shrink, `ASM_OPM_PATCH_BYTES` is at `$7021` in the paste image.
A negative test that used `ORG $7020` overwrote that live metadata while the
session was still assembling, so its `LDA $00` PC advance/checksum are not a
valid classifier proof. Near-miss relocation tests should assemble above the
runtime image and wrapper UDATA, for example at `$7600`.

Freshly reloading the same `L OK=543B` image, then assembling the near-miss
test at `$7600`, proved that `IMM8` selectors still produce only `$02/$03`
relocation rows and that `ZP8`, `REL8`, and `BIT_ZP_REL` do not produce
`ABS16_INTERNAL` relocation rows:

```text
ORG $7600
LDA #<TARGET
LDA #>TARGET
LDA $00
BNE TARGET
BBR 3,$12,TARGET
TARGET RTS
END
```

The resolved fixups and relocation rows were:

```text
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 02   01  7601 7602 TARGET
01 02 02   02  7603 7604 TARGET
02 02 07   00  7607 7608 TARGET
03 02 10   00  760A 760B TARGET
RELOCS
SL K  SITE TARG
00 02 0001 000B
01 03 0003 000B
```

The successful post-session `SEAL` and dumps were:

```text
SEAL OK FLAGS=$01 BASE=$7600 END=$760C
SEAL REC @=$5495 LEN=$000C FNV=$90D5C31B
SEAL REL @=$54A0 COUNT=$02

7600: A9 0B A9 76 A5 00 D0 03 | 3F 12 00 60 | ...v....?..`
5495: 01 00 76 0C 76 0C 00 1B | C3 D5 90 02 02 | ..v.v........
54A0: 02 02 03 | ...
```

The `$7020` metadata overwrite survives `G 2000` because the paste runtime's
loaded DATA constants are not restored by starting a new ASM session. A reload
or cold boot is required after such an overlap test.

Hardware feedback after `ASMRT.REPORT.TRIM` on 2026-07-01 loaded the trimmed
runtime paste image as `L OK=5133 GO=2000`, exactly `$0308` smaller than the
previous `L OK=543B` relocation-classifier image. The first explicit
`ORG $7000` test still overlapped live runtime data: `JMP (TARGET)` and
`JMP (TARGET,X)` failed with `ERR=$08 BAD SYM PC=$7009` after earlier emitted
bytes had overwritten part of the image. A following `G 2000` did not restore
those loaded constants. Treat `$7000` as unsafe for current runtime-paste board
tests in pre-`ASMRT.OVERLAP_GUARD` images; newer images should reject that
target with `BAD RANGE` before writing.

Hardware-proven `ASMRT.REPORT.TRIM` plus `$7600` relocation classifier retest
on 2026-07-01 with HIMON V 00.0630(2121) and the trimmed
`asm-v1-runtime-paste-2000.s19` image loaded as `L OK=5133 GO=2000`. The
operator first typed ASM source at the HIMON prompt and saw `HSH_NF`, which
confirms source must be entered only after `G 2000` reaches `ASM>`. The clean
`L G` run then proved the same absolute-mode classifier facts at `$7600`:

```text
ASM> ORG $7600
OK PC=$7600
ASM> JMP TARGET
OK PC=$7603
ASM> LDA TARGET,X
OK PC=$7606
ASM> LDA TARGET,Y
OK PC=$7609
ASM> JMP (TARGET)
OK PC=$760C
ASM> JMP (TARGET,X)
OK PC=$760F
ASM> TARGET RTS
OK PC=$7610
ASM> END
OK PC=$7610
RELOCS
SL K  SITE TARG
00 01 0001 000F
01 01 0004 000F
02 01 0007 000F
03 01 000A 000F
04 01 000D 000F
SEAL OK FLAGS=$01 BASE=$7600 END=$7610
SEAL REC @=$521F LEN=$0010 FNV=$A2335158
SEAL REL @=$522A COUNT=$05
SEAL> D 7600 1F
ERR=$03 BAD OPER PC=$7610
```

The post-session `SEAL> D` rejection is expected: `SEAL> ` accepts only
`SEAL`, `NEW`, and `.`. The HIMON dumps after exiting the wrapper were:

```text
7600: 4C 0F 76 BD 0F 76 B9 0F | 76 6C 0F 76 7C 0F 76 60 | L.v..v..vl.v|.v`
7610: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
521F: 01 00 76 10 76 10 00 58 | 51 33 A2 05 01 01 01 01 | ..v.v..XQ3......
522F: 01 | .
522A: 05 01 01 01 01 01 | ......
```

Hardware-proven `ASM 2.50` post-session `SEAL` dry-run on 2026-07-01 with
HIMON V 00.0630(2121) and `asm-v1-runtime-paste-2000.s19`
`L OK=51C7 GO=2000`. This proof used the pre-FNV output shape:

```text
$7000 clean tiny span        -> SEAL OK FLAGS=$01 BASE=$7000 END=$7003 LEN=$0003
$7200 forward ORG hole       -> SEAL ERR=$02 FLAGS=$03
$7300 plain DS count         -> SEAL ERR=$02 FLAGS=$05
$7400 initialized DS count   -> SEAL OK FLAGS=$01 BASE=$7400 END=$7405 LEN=$0005
$7500 hole plus plain DS     -> SEAL ERR=$02 FLAGS=$07
```

The same proof shows clean `END` changing the wrapper prompt to `SEAL> ` and
`.` exiting the post-session prompt through `ASM RT PASTE BYE`.

Hardware-proven `SEAL.REC` clean tiny span on 2026-07-01 with
HIMON V 00.0630(2121) and `asm-v1-runtime-paste-2000.s19`
`L OK=52E6 GO=2000`:

```text
$7600 clean tiny span        -> SEAL OK FLAGS=$01 BASE=$7600 END=$7603
                                SEAL REC LEN=$0003 FNV=$695B146E
```

Hardware-proven `SEAL.REC` initialized-DS and plain-DS follow-up on
2026-07-01 with the already-loaded `asm-v1-runtime-paste-2000.s19`
`L OK=52E6 GO=2000` image:

```text
$7400 initialized DS count   -> SEAL OK FLAGS=$01 BASE=$7400 END=$7405
                                SEAL REC LEN=$0005 FNV=$C2D38700
$7300 plain DS count         -> SEAL ERR=$02 FLAGS=$05, no SEAL REC line
```

Hardware-proven `ASMRP.UDATA` runtime-paste trim on 2026-07-01 with
HIMON V 00.0630(2121) and `asm-v1-runtime-paste-2000.s19`
`L OK=51E3 GO=2000`. Compared with the prior `SEAL.REC` image at
`L OK=52E6 GO=2000`, this proves the expected `$0103` loaded-byte savings
while preserving the tiny-span SEAL/FNV result:

```text
$7000 clean tiny span        -> SEAL OK FLAGS=$01 BASE=$7000 END=$7003
                                SEAL REC LEN=$0003 FNV=$695B146E
SEAL> .                      -> ASM RT PASTE BYE
```

Hardware-proven `SEAL.REC.RAM` record bytes on 2026-07-01 with
HIMON V 00.0630(2121) and `asm-v1-runtime-paste-2000.s19`
`L OK=51E3 GO=2000`. After the same `$7000` tiny span and successful `SEAL`,
`ASM_SEAL_REC` was at `$52F9` in this image. Dumping through `$5304` includes
one byte past the `$0B`-byte record; the record itself is `$52F9-$5303`:

```text
52F9: 01 00 70 03 70 03 00 6E | 14 5B 69 03 | ..p.p..n.[i.
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
      ASM_SEAL_REC bytes
```

Hardware-proven `SEAL.REC.PRINT` factored success printer on 2026-07-01 with
HIMON V 00.0630(2121) and `asm-v1-runtime-paste-2000.s19`
`L OK=51F4 GO=2000`. This proves the shared `ASM_SEAL_PRINT_RECORD` output
prints the current `ASM_SEAL_REC` address and keeps the same tiny-span facts:

```text
$7000 clean tiny span        -> SEAL OK FLAGS=$01 BASE=$7000 END=$7003
                                SEAL REC @=$52D0 LEN=$0003 FNV=$695B146E
ASM_SEAL_REC $52D0-$52DA     -> 01 00 70 03 70 03 00 6E 14 5B 69
```

The observed dump continued past the `$0B`-byte record with the next RAM cells:

```text
52D0: 01 00 70 03 70 03 00 6E | 14 5B 69 03 70 03 70 | ..p.p..n.[i.p.p
```

Hardware-proven `SEAL> NEW` restart on 2026-07-01 with
HIMON V 00.0630(2121) and `asm-v1-runtime-paste-2000.s19`
`L OK=5247 GO=2000`. This proof also used the pre-FNV output shape:

```text
SEAL> NEW X  -> ERR=$03 BAD OPER PC=$7603
SEAL> SEAL   -> SEAL OK FLAGS=$01 BASE=$7600 END=$7603 LEN=$0003
SEAL> NEW    -> OK PC=$7603, then ASM>
second END   -> SEAL OK FLAGS=$01 BASE=$7603 END=$7606 LEN=$0003
SEAL> .      -> ASM RT PASTE BYE
```

Hardware-proven `ASMRT.SIZE.UDATA_BUF`, `ASMRT.SIZE.SEAL_CLEAR`, and
`ASMRT.SIZE.CMD_MATCH` on 2026-07-01 with HIMON V 00.0630(2121) and
`asm-v1-runtime-paste-2000.s19` loaded as `L OK=4FCF GO=2000`. Compared with
the previous `L OK=5133 GO=2000` image, this shrank the loaded image by
`$0164` bytes.

The positive no-`ORG` test proves the runtime default PC still starts at
`$7600`, the moved runtime-only `ASM_CODE_BUF` does not break ordinary paste
assembly, and trailing `END`/`SEAL` comments are accepted:

```text
ASM> LDA #$5A
OK PC=$7602
ASM> RTS
OK PC=$7603
ASM> END ;COMMENT
OK PC=$7603
SEAL> SEAL ;COMMENT
SEAL OK FLAGS=$01 BASE=$7600 END=$7603
SEAL REC @=$51BB LEN=$0003 FNV=$695B146E
SEAL REL @=$51C6 COUNT=$00
SEAL> .
ASM RT PASTE BYE
>D 7600 7603
7600: A9 5A 60 00 | .Z`.
>D 51BB +04
51BB: 01 00 76 03 | ..v.
>D 51C6 +01
51C6: 00 | .
```

The strict `SEAL` tail test proves `SEAL X` rejects as `BAD OPER` without
clearing frozen seal facts:

```text
SEAL> SEAL X
ERR=$03 BAD OPER PC=$7603
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7603
SEAL REC @=$51BB LEN=$0003 FNV=$695B146E
SEAL REL @=$51C6 COUNT=$00
```

The `NEW ; COMMENT` plus empty-span test proves the loop clear resets stale
FNV and relocation-count facts. The first span has one relocation row; after
`NEW`, an immediate `END` seals a zero-length span with FNV basis and
`COUNT=$00`:

```text
ASM> JMP TARGET
OK PC=$7603
ASM> TARGET RTS
OK PC=$7604
ASM> END
OK PC=$7604
RELOCS
SL K  SITE TARG
00 01 0001 0003
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7604
SEAL REC @=$51BB LEN=$0004 FNV=$677CFADE
SEAL REL @=$51C6 COUNT=$01
SEAL> NEW ; COMMENT
OK PC=$7604
ASM> END
OK PC=$7604
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7604 END=$7604
SEAL REC @=$51BB LEN=$0000 FNV=$811C9DC5
SEAL REL @=$51C6 COUNT=$00
```

The strict `NEW` tail test proves `NEW X` rejects without clearing the frozen
tiny-span facts:

```text
SEAL> NEW X
ERR=$03 BAD OPER PC=$7603
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7603
SEAL REC @=$51BB LEN=$0003 FNV=$695B146E
SEAL REL @=$51C6 COUNT=$00
```

Leading whitespace before post-`END` commands still needs a visible board
transcript if that detail matters; the recognizer code accepts it, but this
hardware capture shows trailing comments and operand rejection.

Hardware-proven `ASMRT.SIZE.SESSION_UDATA` on 2026-07-01 with HIMON
V 00.0701(1134) and `asm-v1-runtime-paste-2000.s19` loaded as
`L OK=343B GO=2000`. Compared with the previous `L OK=4FCF GO=2000` image,
this shrank the loaded image by `$1B94` bytes. This proves runtime-only session
state, seal records, relocation records, symbol tables, and fixup tables can
live in UDATA while loaded DATA keeps only code and constants.

The clean tiny-span proof still emits the same body and seal facts. The moved
records now print at `$554A/$5555`, so dumps must follow the printed addresses:

```text
ASM> LDA #$5A
OK PC=$7602
ASM> RTS
OK PC=$7603
ASM> END
OK PC=$7603
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7603
SEAL REC @=$554A LEN=$0003 FNV=$695B146E
SEAL REL @=$5555 COUNT=$00
SEAL> .
ASM RT PASTE BYE
>D 7600 7603
7600: A9 5A 60 00 | .Z`.
>D 554A +3
554A: 01 00 76 | ..v
>D 5555 +1
5555: 00 | .
```

The stale-state proof reran the already-loaded wrapper with prior runtime UDATA
dirtied by the first session. It assembled a reloc-bearing span, then `NEW`
and immediate `END` proved that stale relocation and seal facts are cleared:

```text
ASM> JMP TARGET
OK PC=$7603
ASM> TARGET RTS
OK PC=$7604
ASM> END
OK PC=$7604
RELOCS
SL K  SITE TARG
00 01 0001 0003
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7604
SEAL REC @=$554A LEN=$0004 FNV=$677CFADE
SEAL REL @=$5555 COUNT=$01
SEAL> NEW
OK PC=$7604
ASM> END
OK PC=$7604
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7604 END=$7604
SEAL REC @=$554A LEN=$0000 FNV=$811C9DC5
SEAL REL @=$5555 COUNT=$00
```

Follow-up board proof with the same `L OK=343B GO=2000` image confirmed the
runtime-only UDATA move across reload, seal-negative, and relocation-classifier
cases:

- Reloading the image without another `STR8`/cold RAM zero still accepted the
  tiny span and produced `LEN=$0003 FNV=$695B146E COUNT=$00`. The dump showed
  `7600: A9 5A 60 60`; the final `$60` is outside the sealed 3-byte span and
  is stale RAM from the prior program, not part of the seal body.
- A non-initial forward `ORG` hole sealed as `SEAL ERR=$02 FLAGS=$03`.
- Plain `DS 2` sealed as `SEAL ERR=$02 FLAGS=$05`.
- Initialized `DS 2,$FF` stayed sealable as `FLAGS=$01 LEN=$0005
  FNV=$C2D38700 COUNT=$00`.
- The relocation classifier still emitted five rows for
  `JMP TARGET`, `LDA TARGET,X`, `LDA TARGET,Y`, `LDA #<TARGET`,
  `LDA #>TARGET`: three `$01` ABS16 rows, then `$02` LO8 and `$03` HI8, with
  `SEAL REL @=$5555 COUNT=$05`.
- Strict post-`END` commands still reject operands without clearing frozen
  facts: `SEAL X` and `NEW X` both reported `ERR=$03 BAD OPER PC=$7603`, and
  the later `SEAL` still reported `LEN=$0003 FNV=$695B146E COUNT=$00`.
- `BOGUS` at statement head is accepted as a label-only statement at the
  current PC, not as a bad mnemonic; after exiting with `.`, a fresh `G 2000`
  still sealed the tiny span cleanly.
- Immediate `END` after fresh entry sealed a zero-length span:
  `BASE=$7600 END=$7600 LEN=$0000 FNV=$811C9DC5 COUNT=$00`.

Hardware-proven `ASMRT.OVERLAP_GUARD` on 2026-07-01 with HIMON
V 00.0701(1134) and `asm-v1-runtime-paste-2000.s19` loaded as
`L OK=3469 GO=2000`. Compared with the previous `L OK=343B GO=2000` image,
the guard costs `$002E` loaded bytes in the runtime-paste proof image.

```text
; old unsafe runtime-paste target now rejects before writing
ASM> ORG $7000
ERR=$06 BAD RANGE PC=$7600
ASM> LDA #$5A
OK PC=$7602
ASM> RTS
OK PC=$7603
ASM> END
OK PC=$7603
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7603
SEAL REC @=$hhhh LEN=$0003 FNV=$695B146E
SEAL REL @=$hhhh COUNT=$00
SEAL> .
>D 7600 +3
7600: A9 5A 60 | .Z`

; nearby safe range above the current workspace must still assemble
ASM> ORG $7200
OK PC=$7200
ASM> LDA #$5A
OK PC=$7202
ASM> RTS
OK PC=$7203
ASM> END
OK PC=$7203
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7200 END=$7203
SEAL REC @=$hhhh LEN=$0003 FNV=$695B146E
SEAL REL @=$hhhh COUNT=$00
SEAL> .
>D 7200 7202
7200: A9 5A 60 | .Z`
```

Follow-up map-edge proof on the same `L OK=3469 GO=2000` image showed
`ASM_CODE_BUF=$7105`: `ORG $7104` rejects as `BAD RANGE`, while a fresh
session can `ORG $7105`, emit `DB $AA`, and seal `BASE=$7105 END=$7106
LEN=$0001 FNV=$AF0BD5BD COUNT=$00`. In the first session, a later
`ORG $7105` after emitting one byte at `$7600` also rejects as `BAD RANGE`
because it is backward from `PC=$7601`, not because `$7105` itself is
protected. The same edge proof re-confirmed that `NEW` before `END` is source
text and can define a label, and that monitor `D` dumps must be issued after
exiting `SEAL>`.

`SEAL.EXPORT` board proof observed. Positive proof:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7600
OK PC=$7600
ASM> MAIN JMP TARGET
OK PC=$7603
ASM> TARGET RTS
OK PC=$7604
ASM> EXPORT MAIN
OK PC=$7604
ASM> EXPORT TARGET
OK PC=$7604
ASM> END
OK PC=$7604
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7600  01 04 0E 0002 00  0000  MAIN
01 01 7603  01 04 0E 0003 00  0000  TARGET
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 04   00  7601 7603 TARGET
RELOCS
SL K  SITE TARG
00 01 0001 0003
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7604
SEAL REC @=$57EC LEN=$0004 FNV=$677CFADE
SEAL REL @=$57F7 COUNT=$01
SEAL EXP @=$5848 COUNT=$02 LEN=$0010
SEAL> .
>D 7600 7603
7600: 4C 03 76 60 | L.v`
>D 5848 +10
5848: 02 10 00 00 04 71 51 80 | 57 03 00 06 3A 7D 9C 2C | .....qQ.W...:}.,
```

Negative proof:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7600
OK PC=$7600
ASM> MAIN RTS
OK PC=$7601
ASM> SIZE EQU $1234
OK PC=$7601
ASM> EXPORT MISSING
ERR=$08 BAD SYM PC=$7601
ASM> EXPORT .LOCAL
ERR=$08 BAD SYM PC=$7601
ASM> EXPORT SIZE
ERR=$08 BAD SYM PC=$7601
ASM> EXPORT MAIN X
ERR=$03 BAD OPER PC=$7601
ASM> LABEL EXPORT MAIN
ERR=$08 BAD SYM PC=$7601
ASM> EXPORT MAIN
OK PC=$7601
ASM> EXPORT MAIN
ERR=$08 BAD SYM PC=$7601
ASM> END
OK PC=$7601
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7600  01 04 0E 0002 00  0000  MAIN
01 01 1234  01 04 16 0003 00  0000  SIZE
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7601
SEAL REC @=$57EC LEN=$0001 FNV=$E50C2ABF
SEAL REL @=$57F7 COUNT=$00
SEAL EXP @=$5848 COUNT=$01 LEN=$0009
SEAL> .
>D 5848 +9
5848: 01 09 00 00 04 71 51 80 | 57 | .....qQ.W
```

`SEAL.IMPORT` hardware-proven on 2026-07-02 with `asm-v1-runtime-paste-2000.s19`
loaded as `L OK=3904 GO=2000`. The final board pass proved metadata-only
`IMPORT` dispatch, negative parser/status handling, the then-current unresolved
imported-reference fixup behavior, eight-entry table limit handling, and `SEAL
IMP` named-record printing. In that image `ASM_CODE_BUF=$76EF` and
`ASM_IMPORT_REC=$5A39`; the
positive `EXT`/`IO2` record dumped as `02 08 03 14 23 03 B5 3A`, the single
`EXT` record dumped as `01 05 03 14 23`, and the eight-entry `I0`..`I7` record
dumped as `08 1A 02 78 3C 02 A0 3C 02 C8 3C 02 F0 3C 02 18 3D 02 40 3D 02 68
3D 02 90 3D`.

The 2026-07-02 host `asm-test` slice after that board proof advances declared
imports: `IMPORT EXT` plus `JSR EXT` now succeeds at `END`, marks the fixup
state as imported, leaves the operand placeholder bytes `$FF/$FF`, and records
a `$04` ABS16_IMPORT relocation row with `SITE=$0001` and import slot
`TARG=$0000`.

The same behavior is hardware-proven on 2026-07-02 with HIMON
`V 00.0702(0707)` and `asm-v1-runtime-paste-2000.s19` loaded as
`L OK=3A3C GO=2000`. The positive board pass assembled `IMPORT EXT` then
`JSR EXT` at `ASM_CODE_BUF=$7827`; `END` succeeded, the table printer showed
fixup state `$04` with selector `$40`, and the relocation table showed
`00 04 0001 0000`. `SEAL` preserved the same proof with base `$7827`,
`SEAL REL @=$5A56 COUNT=$01`, and `SEAL IMP @=$5B71 COUNT=$01 LEN=$0005`;
the import dump began `01 05 03 14 23`. A follow-up `JSR MISS` without
`IMPORT MISS` still failed `END` as `ERR=$09 BAD FIX`, with a pending
non-import fixup and no relocation rows.

The follow-up 2026-07-02 host `asm-test` slice extends declared imports to
selected-byte operands. `IMPORT EXT`, `LDA #<EXT`, and `LDX #>EXT` now leave
`A9 FF A2 FF` placeholders, accept `END`, mark both fixups imported, and record
`$05` LO8_IMPORT and `$06` HI8_IMPORT rows at site offsets `$0001` and `$0003`,
both targeting import slot `$0000`. Host build passed with
`asm-v1-runtime-paste-2000.s19` load count `L OK=3A75 GO=2000`. Board proof on
HIMON `V 00.0702(0707)` loaded the same image, assembled at
`ASM_CODE_BUF=$7860`, printed fixup selectors `$41/$42`, relocation rows
`00 05 0001 0000` and `01 06 0003 0000`, sealed with
`SEAL REL @=$5A8F COUNT=$02` and `SEAL IMP @=$5BAA COUNT=$01 LEN=$0005`, and
dumped `A9 FF A2 FF` at `$7860-$7863`.

The follow-up 2026-07-02 host `asm-test` slice adds forced-deferred import
precedence over resident RJOIN. A plain undeclared `JSR BIO_FTDI_PUT_CSTR`
still resolves through RJOIN, stores no fixup, accepts `END`, and records no
relocation rows. With `IMPORT BIO_FTDI_PUT_CSTR` declared first, the same
resident name now emits `20 FF FF A9 FF A2 FF` for `JSR`, `#<`, and `#>`
uses, marks three fixups imported, and records `$04/$05/$06` import relocation
rows at site offsets `$0001/$0004/$0006`, all targeting import slot `$0000`.
The matching board proof loaded `asm-v1-runtime-paste-2000.s19` as
`L OK=3A78 GO=2000`. The plain resident pass assembled at
`ASM_CODE_BUF=$7863`, ended at `$7866`, sealed with
`SEAL REC @=$5A87 LEN=$0003 FNV=$69B61E6D` and
`SEAL REL @=$5A92 COUNT=$00`, printed no `SEAL IMP`, and dumped
`20 55 E1` at `$7863-$7865`. The forced-deferred pass used the same base,
ended at `$786A`, printed fixup selectors `$40/$41/$42` and relocation rows
`00 04 0001 0000`, `01 05 0004 0000`, and `02 06 0006 0000`, sealed with
`SEAL REC @=$5A87 LEN=$0007 FNV=$039163CA`,
`SEAL REL @=$5A92 COUNT=$03`, and
`SEAL IMP @=$5BAD COUNT=$01 LEN=$000F`, and dumped
`20 FF FF A9 FF A2 FF` at `$7863-$7869`.

The next 2026-07-02 host `asm-test` slice adds `SEAL> RESOLVE` for current
RAM-body import resolution. The resolver reconstructs each imported name hash
from existing PACK40 metadata, resolves referenced import slots through
resident RJOIN, and patches `$04/$05/$06` rows in place only after a validation
scan succeeds. Host smoke extends the forced-deferred `BIO_FTDI_PUT_CSTR`
case: after `END`, `ASM_SEAL_RESOLVE_IMPORTS` patches the `JSR`, `#<`, and
`#>` bytes to a consistent resident address and reports
`ASM_IMPORT_RESOLVE_COUNT=$03`. Runtime paste/flash wrappers now accept
post-END `RESOLVE`, printing `RESOLVE OK COUNT=$nn` or `RESOLVE ERR=$ee`. The
matching board proof loaded `asm-v1-runtime-paste-2000.s19` as
`L OK=3C81 GO=2000`. The proof assembled at `ASM_CODE_BUF=$7A6D`, printed
relocation rows `00 04 0001 0000`, `01 05 0004 0000`, and `02 06 0006 0000`,
then `RESOLVE` reported `RESOLVE OK COUNT=$03`. A second run showed `SEAL`
before `RESOLVE` with `SEAL REC @=$5C90 LEN=$0007 FNV=$039163CA`,
`SEAL REL @=$5C9B COUNT=$03`, and
`SEAL IMP @=$5DB6 COUNT=$01 LEN=$000F`; after `RESOLVE`, `SEAL` preserved the
same REL/IMP metadata but recomputed body FNV as `$5DCABFAE`. The patched body
dump at `$7A6D-$7A73` was `20 55 E1 A9 55 A2 E1`, proving ABS16, LO8, and HI8
import rows all resolved to the resident `BIO_FTDI_PUT_CSTR` address.

The follow-up host `asm-test` slice adds `SEAL> RELOCATE address` for RAM
overlay movement. The exported core routine `ASM_SEAL_RELOCATE` takes `X/Y` as
the destination base, validates the frozen seal, copies `[BASE,END)` to that
new RAM base, and applies only internal relocation rows: `$01` ABS16_INTERNAL,
`$02` LO8_INTERNAL, and `$03` HI8_INTERNAL. It leaves import rows and import
metadata untouched; `SEAL> RESOLVE` remains the separate proof for `$04/$05/$06`
rows. Host smoke assembles:

```text
JSR TARGET
LDA #<TARGET
LDX #>TARGET
TARGET RTS
END
```

It then relocates the sealed body upward from the frozen end, expects three
patched rows, and verifies the moved copy is `20 ll hh A9 ll A2 hh 60`, where
`hhll` is the relocated `TARGET` address. Runtime paste/flash wrappers now
accept post-END `RELOCATE address`, parse the address through the existing ASM
expression parser, and print `RELOCATE OK BASE=$hhhh COUNT=$nn` or
`RELOCATE ERR=$ee`. The matching host build produced
`asm-v1-runtime-paste-2000.s19` with loaded CODE+DATA `$3EAC`. The matching
board proof loaded it as `L OK=3EAC GO=2000`, assembled at
`ASM_CODE_BUF=$7C9D`, and ended with `BASE=$7C9D END=$7CA5`. The table printer
showed relocation rows `00 01 0001 0007`, `01 02 0004 0007`, and
`02 03 0006 0007`; `SEAL` reported
`SEAL REC @=$5EBD LEN=$0008 FNV=$E1048C04` and
`SEAL REL @=$5EC8 COUNT=$03`. `RELOCATE $7D00` reported
`RELOCATE OK BASE=$7D00 COUNT=$03`, and `D 7D00 +8` showed
`20 07 7D A9 07 A2 7D 60`, proving the copied body now points at relocated
`TARGET=$7D07`. The original body remained at `$7C9D` with operands still
pointing at original `TARGET=$7CA4`.

A same-day wrapper parser compaction replaced duplicate strict/argument command
matching and the hand-coded END recognizer with a shared matcher in both
runtime paste and flash. Behavior is unchanged; the host gate now produces
`asm-v1-runtime-paste-2000.s19` with loaded CODE+DATA `$3E91` and
`ASM_CODE_BUF=$7C82`, shrinking the board-load image by `$001B` from the
`L OK=3EAC` RELOCATE proof above. The matching board proof on the compacted
image assembled the same body at `BASE=$7C82 END=$7C8A`; `SEAL` reported
`SEAL REC @=$5EA2 LEN=$0008 FNV=$6786A5EA` and
`SEAL REL @=$5EAD COUNT=$03`. `RELOCATE $7D00` reported
`RELOCATE OK BASE=$7D00 COUNT=$03`; `D 7C82 7C8A` showed
`20 89 7C A9 89 A2 7C 60 00`, and `D 7D00 +8` showed
`20 07 7D A9 07 A2 7D 60`.

A follow-up board proof on the same `L OK=3E91 GO=2000` image ran the
relocated RAM body. The source added fixed external result stores after the
internal target address was loaded:

```text
JSR TARGET
LDA #<TARGET
LDX #>TARGET
STA $7900
STX $7901
RTS
TARGET RTS
```

It assembled at `BASE=$7C82 END=$7C91`, sealed as
`SEAL REC @=$5EA2 LEN=$000F FNV=$EFFFDB38`, and kept the same three relocation
rows with targets `000E`. After `RELOCATE $7D00`, `G 7D00` returned with
`A=0E X=7D`, and `D 7900 +2` showed `0E 7D`. This proves the copied body runs
from its relocated RAM base, internal `TARGET` was relinked to `$7D0E`, and the
fixed external RAM stores at `$7900/$7901` were not relocated.

The next host `asm-test` slice adds `SEAL> PACKAGE address` as the first stable
object-envelope proof. `ASM_SEAL_PACKAGE` is built only when
`ASM_PACKAGE_ENABLED` is set; the full core smoke and flash-resident ASM image
include it, while the stripped runtime-paste image leaves it out. Host smoke
packages the same internal relocation body, checks total length `$0037`, and
verifies the AP v1 sequential envelope: header `A P 01 len_lo len_hi`, tagged
seal section `S`, tagged relocation section `R`, tagged export section `E`,
tagged import section `I`, and tagged body section `B`. The host gate passed
with runtime paste back at `ASM_CODE_BUF=$7C82`, `_END_UDATA=$7D82`, and flash
ASM carrying the package command with `ASM_CODE_BUF=$7EF8`,
`_END_UDATA=$7F00`.

A runtime-paste negative board proof loaded the compact paste image as
`L OK=3E91 GO=2000`, assembled the same body at `BASE=$7C82 END=$7C8A`, and
sealed it with `SEAL REC @=$5EA2 LEN=$0008 FNV=$6786A5EA` and
`SEAL REL @=$5EAD COUNT=$03`. At `SEAL>`, `PACKAGE $3000` returned
`ERR=$03 BAD OPER PC=$7C8A`, proving the RAM paste wrapper rejects PACKAGE as
an unsupported post-END command and leaves RAM at `$3000` untouched by this
slice.

Flash-board PACKAGE probe after installing `asm-v1-flash-8000.s19` and
starting flash ASM with `>ASM`:

```text
JSR TARGET
LDA #<TARGET
LDX #>TARGET
TARGET RTS
END
SEAL
PACKAGE $3000
.
D 3000 3036
```

Expected structure is an AP v1 envelope at `$3000`. The FNV bytes in the seal
section depend on the assembled body address, but the structural bytes should
show `41 50 01 37 00` at the start, `53 0B` for the seal section, `52 10 03`
for the three-row relocation section, `45 02 00 02` for the empty export
record, `49 02 00 02` for the empty import record, and a final body section
tagged `42 08 00`.

The matching flash-board proof loaded the package-enabled flash image with
`L F`, reporting `LF OK WR=3D49 GO=800C`, then started `ASM FLASH` with
`>ASM`. The same body assembled at `BASE=$2000 END=$2008`, sealed as
`SEAL REC @=$6111 LEN=$0008 FNV=$FFC39D9A`, and kept the three internal
relocation rows. `PACKAGE $3000` reported
`PACKAGE OK @=$3000 LEN=$0037`. `D 3000 3036` showed:

```text
3000: 41 50 01 37 00 53 0B 01 | 00 20 08 20 08 00 9A 9D
3010: C3 FF 52 10 03 01 02 03 | 01 04 06 00 00 00 07 07
3020: 07 00 00 00 45 02 00 02 | 49 02 00 02 42 08 00 20
3030: 07 20 A9 07 A2 20 60
```

This proves the flash-resident wrapper accepts `PACKAGE`, writes the AP v1
envelope to caller-chosen RAM, preserves internal relocation metadata as
offset rows, carries empty EXP/IMP records, copies the sealed body bytes
unchanged, and self-verifies the written BODY FNV before returning success.
Host `asm-test` also corrupts the first BODY byte and requires the same package
verifier to reject it with `BAD LINE` before restoring the byte.

The BODY-FNV self-verify follow-up board proof ran on HIMON
`V 00.0704(2011)`. The default flash ASM image loaded with
`LF OK WR=3C68 GO=800C`, assembled the same body at
`BASE=$2000 END=$2008`, sealed it as
`SEAL REC @=$6111 LEN=$0008 FNV=$FFC39D9A`, and `PACKAGE $3200` returned
`PACKAGE OK @=$3200 LEN=$0037`. The `$3200 +37` dump began
`41 50 01 37 00` and ended with the original packaged body
`20 07 20 A9 07 A2 20 60`; running `G 2000` returned `A=07 X=20`.

The next host `asm-test` slice adds `SEAL> CHECK address` as the first AP v1
package reader proof. `ASM_SEAL_CHECK_PACKAGE` is built when
`ASM_PACKAGE_CHECK_ENABLED` is set, so full core smoke packages the internal
relocation body and immediately validates the generated envelope. Runtime paste
omits the package/check pair. A flash diagnostic proof carried `CHECK` once for
board validation with `ASM_CODE_BUF=$7EF8` and `_END_UDATA=$7F00`; the default
flash-resident image later compiled the interactive `CHECK` command back out to
recover headroom below `$C000`.

Flash-board CHECK probe after the PACKAGE proof above:

```text
CHECK $3000
.
D 3000 3036
```

Expected success is `CHECK OK @=$3000 LEN=$0037`. The command validates the AP
v1 header, guarded total range, section order, section length accounting,
relocation count shape, EXP/IMP internal length fields, and final body length
against the seal record.

The matching flash-board proof loaded the fixed package/check flash image with
`L F`, reporting `LF OK WR=3FDC GO=800C`. `ASM FLASH` assembled the same
body at `BASE=$2000 END=$2008`, sealed as
`SEAL REC @=$6111 LEN=$0008 FNV=$FFC39D9A`, and wrote
`PACKAGE OK @=$3000 LEN=$0037`. `CHECK $3000` then reported
`CHECK OK @=$3000 LEN=$0037`, and the final `D 3000 3036` dump matched the AP
v1 envelope from the earlier package proof. This proves the flash-resident
reader accepted the package it just wrote while the flash runtime UDATA ended
at `$7F00`, outside the `$7F00-$7FFF` I/O page. After this proof, the default
flash image omitted `CHECK` again; the package/check image reported
`LF OK WR=3FDC GO=800C`, leaving only `$24` bytes below `$C000`, while the
package-only flash image returned to about `WR=3D49`. The follow-up default
flash proof on HIMON `V 00.0703(1903)` loaded as `LF OK WR=3D49 GO=800C`,
assembled the same body at `BASE=$2000 END=$2008`, wrote
`PACKAGE OK @=$3000 LEN=$0037`, rejected `CHECK $3000` as
`ERR=$03 BAD OPER PC=$2008`, and dumped the matching AP v1 envelope at `$3000`.

The first 2026-07-02 board attempt with
`asm-v1-runtime-paste-2000.s19` loaded as `L OK=38FC GO=2000` failed before
this proof: `IMPORT EXT` behaved like an emitting unresolved ABS16 instruction,
advanced PC by three, and produced a fixup. The cause was a vocabulary-table
hash alignment bug: slot `$20` still held the old `ENTRY` hash while the
`IMPORT` hash had displaced `INC` at slot `$24`. The source restored `IMPORT`
to slot `$20`, restored `INC` to slot `$24`, and added host smoke coverage that
`IMPORT EXT` is metadata-only.

The second 2026-07-02 board attempt with the corrected vocabulary table proved
metadata-only dispatch and negative parsing, but `SEAL IMP` printed a message
string address (`$56DB`) with `COUNT=$00 LEN=$0020` instead of the import
record. The cause was `ASM_SEAL_PRINT_NAMED_REC` saving the record pointer in
`ASM_TMP0`, the same zero-page pair used by `ASM_RJ_WRITE_CSTRING` as its
string cursor. Source now copies the named-record pointer to `ASM_TMP1` before
printing label/count/len text.

Positive metadata proof:
In these snippets, `bbbb` is the `BASE` printed by `SEAL OK` and `eeee` is the
exclusive `END` printed on the same line.

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> RTS
OK PC=$eeee
ASM> IMPORT EXT
OK PC=$eeee
ASM> IMPORT IO2
OK PC=$eeee
ASM> END
OK PC=$eeee
...
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$bbbb END=$eeee
SEAL REC @=$hhhh LEN=$0001 FNV=$E50C2ABF
SEAL REL @=$hhhh COUNT=$00
SEAL IMP @=$iiii COUNT=$02 LEN=$0008
SEAL> .
>D bbbb bbbb
bbbb: 60 | `
>D iiii +08
iiii: 02 08 03 14 23 03 B5 3A | ....#..:
```

Negative and metadata-only proof:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> RTS
OK PC=$eeee
ASM> IMPORT .LOCAL
ERR=$08 BAD SYM PC=$eeee
ASM> IMPORT ?LOCAL
ERR=$08 BAD SYM PC=$eeee
ASM> IMPORT LDA
ERR=$08 BAD SYM PC=$eeee
ASM> IMPORT EXT X
ERR=$03 BAD OPER PC=$eeee
ASM> LABEL IMPORT EXT
ERR=$08 BAD SYM PC=$eeee
ASM> IMPORT EXT
OK PC=$eeee
ASM> IMPORT EXT
ERR=$08 BAD SYM PC=$eeee
ASM> END
OK PC=$eeee
...
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$bbbb END=$eeee
SEAL REC @=$hhhh LEN=$0001 FNV=$E50C2ABF
SEAL REL @=$hhhh COUNT=$00
SEAL IMP @=$iiii COUNT=$01 LEN=$0005
SEAL> .
>D iiii +05
iiii: 01 05 03 14 23 | ....#
>G 2000
GO 2000
ASM RT PASTE
ASM> IMPORT MISS
OK PC=$bbbb
ASM> JSR MISS
OK PC=$eeee
ASM> END
ERR=$09 BAD FIX PC=$eeee
ASM> .
ASM RT PASTE BYE
```

Table-limit proof:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> RTS
OK PC=$eeee
ASM> IMPORT I0
OK PC=$eeee
ASM> IMPORT I1
OK PC=$eeee
ASM> IMPORT I2
OK PC=$eeee
ASM> IMPORT I3
OK PC=$eeee
ASM> IMPORT I4
OK PC=$eeee
ASM> IMPORT I5
OK PC=$eeee
ASM> IMPORT I6
OK PC=$eeee
ASM> IMPORT I7
OK PC=$eeee
ASM> IMPORT I8
ERR=$08 BAD SYM PC=$eeee
ASM> END
OK PC=$eeee
...
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$bbbb END=$eeee
SEAL REC @=$hhhh LEN=$0001 FNV=$E50C2ABF
SEAL REL @=$hhhh COUNT=$00
SEAL IMP @=$iiii COUNT=$08 LEN=$001A
SEAL> .
>D iiii +1A
iiii: 08 1A 02 78 3C 02 A0 3C | ...x<..<
iiii: 02 C8 3C 02 F0 3C 02 18 | ..<..<..
iiii: 3D 02 40 3D 02 68 3D 02 | =.@=.h=.
iiii: 90 3D | .=
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

## Hardware Proof: Directive/DS Shrink

The directive dispatcher, `DS`, and expression-failure shrink was hardware
proven on 2026-06-09 with HIMON V 00.0608(1850). Positive proof:

```text
ASM>         ORG $7200
OK PC=$7200
ASM> OUT     EQU $7100
OK PC=$7200
ASM> BASE    EQU $7200
OK PC=$7200
ASM> COUNT   EQU 3+2
OK PC=$7200
ASM> BUF     DS COUNT,$AA,$55
OK PC=$7205
ASM>         ORG BASE+16
OK PC=$7210
ASM> MARK    EQU *
OK PC=$7210
ASM>         DB <MARK,>MARK,COUNT
OK PC=$7213
ASM>         END
OK PC=$7213
ASM RT PASTE OK
>D 7200 7204
7200: AA 55 AA 55 AA | .U.U.
>D 7210 7212
7210: 10 72 05 | .r.
```

Negative proof keeps rejected `DS` lines from advancing PC and still accepts the
following `DB`:

```text
ASM>         ORG $7220
OK PC=$7220
ASM>         DS %XXXXXXX1
ERR=$05 BAD WIDTH PC=$7220
ASM>         DS $0100
ERR=$06 BAD RANGE PC=$7220
ASM>         DS 1,%XXXXXXX1
ERR=$05 BAD WIDTH PC=$7220
ASM>         DB $5A
OK PC=$7221
ASM>         END
OK PC=$7221
ASM RT PASTE OK
>D 7220
7220: 5A | Z
```

## Flash $8000 Slice

Host proof for the first flash-resident ASM slice:

```text
make -C SRC asm-v1-flash
make -C SRC asm-test
```

The `asm-v1-flash-8000.s19` image is fixed-address for current `L F`:

```text
FNV record:  $8000, ASM hash $56AD7400
S9 entry:    START from the link map, currently $800C
S1 range:    $8000-$AD6A
UDATA:       $6000-$6F32, omitted from S19
default PC:  emitted opcodes start at $2000
```

Board proof script:

```text
; on host
make -C SRC asm-v1-flash

; on board, with the $8000 flash window erased/blank
>L F
send SRC/BUILD/s19/asm-v1-flash-8000.s19

># K=5
; expect an ASM V1 K05 row with hash 56AD7400 and entry near $800C

>ASM
; expect ASM FLASH and ASM> prompt

ASM>         ORG $2000
ASM>         LDA #$5A
ASM>         STA $7100
ASM>         RTS
ASM>         END
; expect ASM TABLES then ASM FLASH OK

>G 2000
>D 7100
; expect 5A

>D 7E00 7E01
; expect the HIMON RJOIN seed still present and unchanged for the session
```

The fixed-image hash-command path is hardware-proven once a cold-boot board
reaches HIMON, accepts `ASM`, enters the flash wrapper, assembles a RAM program,
and runs the emitted code. The current proof uses the Life sample at `$2000`.

First board smoke on HIMON V 00.0610(2014) loaded the image:

```text
L F S19
L @8000
LF OK WR=2D67 GO=800C
>G 800C
ASM FLASH
ASM>
BRK 00 PC=0002
A=00 X=03 Y=60 P=75 S=F9 NV-BdIzC
```

`X=03 Y=60` is the flash wrapper line buffer at `$6003`. The likely failure
was an indirect call through a cleared read vector after `ASM_BEGIN` called the
shared RJOIN init. The fix keeps flash UDATA read-vector clearing in
`ASM_RJOIN_INIT_IO` only, so generic `ASM_RJOIN_INIT` cannot clear the input
routine after it has been resolved.

Fixed-image fingerprint:

```text
>D 8173 8182
8173: 9C 82 61 AD 82 61 F0 1B | AD 85 61 F0 16 AD 87 61

>D 8218 8227
8218: 9C 8A 61 9C 8B 61 20 73 | 81 90 1B AD 8B 61 D0 14
```

If `$8173` still clears `$6172/$6173`, or `$8218` begins directly with
`20 73 81`, the board is still executing the earlier stale flash image.

Accepted direct-entry board proof on HIMON V 00.0610(2014): after erasing/blanking the
`$8000` window, the board loaded `asm-v1-flash-8000.s19` with current `L F`,
reported `LF OK WR=2D67 GO=800C`, entered with `G 800C`, accepted the
interactive Life source relocated to `ORG $2000`, printed `ASM FLASH OK`, then
ran the emitted program with `G 2000`. The runtime printed Life boards and
accepted `N/R/Q` input. This proves the fixed-address `L F` flash image and
substantial flash-runtime assembly path.

Accepted hash-command board proof on the same HIMON V 00.0610(2014): after a
cold boot, HIMON accepted `>ASM`, printed `ASM FLASH`, accepted the same
interactive Life source relocated to `ORG $2000`, printed `ASM FLASH OK`, then
ran the emitted program with `G 2000` and showed the initial Life board. This
closes the HIMON `ASM` hash-command proof for the fixed `$8000` image.

Flash-wrapper size trim after this proof first changed accepted source lines and
`SEAL> NEW` to print only `OK`, while rejected lines continued to print
`ERR=$ee NAME PC=$hhhh`.
Board proof on 2026-07-04 showed accepted `ORG`, `LDA`, `STA`, `RTS`, `END`,
`SEAL> NEW`, `NOP`, and the second `END` all printing plain `OK`. The same run
proved source rejection still prints `ERR=$03 BAD OPER PC=$2205`, post-END
command rejection still prints `ERR=$03 BAD OPER PC=$2206`, the final bytes at
`$2200` are `A9 5A 8D 04 71 60 EA`, and `G 2200` stores `$5A` at `$7104`.
The follow-up quiet-success slice removes even that success `OK` from accepted
source lines and `SEAL> NEW`. Because the line-by-line PC echo is gone, source
mode now accepts `.P` to print `PC=$hhhh` without assembling a line. `END` still
prints tables and `ASM FLASH OK`, and rejected lines still print
`ERR=$ee NAME PC=$hhhh`. This slice is host-gated by `make -C SRC asm-test`.
Board proof on 2026-07-04 with HIMON `V 00.0704(1808)` loaded the flash image
as `LF OK WR=3C38 GO=800C` and proved quiet accepted lines, explicit `.P`
reporting, comment-tolerant `.P`, unchanged rejected-line PC reporting,
source-mode-only `.P`, quiet `SEAL> NEW`, emitted bytes, execution, and direct
return status.

The next flash-wrapper presentation slice keeps accepted source lines quiet but
prints the current source PC in the prompt as `ASM>$hhhh: `. `SEAL> ` remains
unchanged, `.P` remains available in source mode, and rejected lines keep the
same `ERR=$ee NAME PC=$hhhh` diagnostic. This change is host-gated by
`make -C SRC asm-test` and still needs board capture.

Quiet-success board proof excerpt:

```text
>ASM
ASM FLASH
ASM> .P
PC=$2000
ASM> ORG $2200
ASM> .P
PC=$2200
ASM> LDA #$5A
ASM> .P ; COMMENT OK
PC=$2202
ASM> STA $7104
ASM> .P
PC=$2205
ASM> BVF $4FRE
ERR=$03 BAD OPER PC=$2205
ASM> .P
PC=$2205
ASM> RTS
ASM> .P
PC=$2206
ASM> END
ASM TABLES
...
ASM FLASH OK
SEAL> .P
ERR=$03 BAD OPER PC=$2206
SEAL> NEW
ASM> .P
PC=$2206
ASM> NOP
ASM> .P
PC=$2207
ASM> END
ASM TABLES
...
ASM FLASH OK
SEAL> .
ASM FLASH BYE
>D 2200 +7
2200: A9 5A 8D 04 71 60 EA | .Z..q`.
>G 2200
RET A=5A X=30 Y=30 P=75 S=FD NV-BdIzC
>D 7104
7104: 5A | Z
```

The same flash-wrapper return-status slice makes `.`/`ASM FLASH BYE` return to
HIMON with `A=$00`, `X/Y=current PC`, and `C=1`; existing fatal exits return
`A=status`, `X/Y=current PC`, and `C=0`. Board proof on 2026-07-04 entered the
flash image directly with `G 800C`; after silent `ORG $2300` and `.`, HIMON
printed `RET A=00 X=00 Y=23 P=75 ... C`. A second direct-entry run assembled
silent `ORG $2400` and `JSR MISS`, failed `END` with
`ERR=$09 BAD FIX PC=$2403`, and HIMON printed
`RET A=09 X=03 Y=24 P=74 ... c`. Entering through the resident `ASM` hash
command and typing `.` returned cleanly to the HIMON prompt with no `EXEC ERR`.

Hardware proof on HIMON `V 00.0704(1632)` with flash ASM loaded as
`LF OK WR=3C35 GO=800C` proved the ASM-local 16-bit hex word printer after the
2026-07-03 `Shrink ASM hex word output` size trim. The board rejected
`BVF $4FRE` as `ERR=$03 BAD OPER PC=$2000`, then assembled an internal-reloc
body at `$2000` with accepted lines printing plain `OK`. The table printer kept
the expected symbol values `MAIN=$2000` and `TARGET=$2007`, fixup rows
`SITE/BASE` of `2001/2003`, `2004/2005`, and `2006/2007`, and relocation rows
`0001/0007`, `0004/0007`, and `0006/0007`.

The same proof showed `SEAL` printing
`SEAL OK FLAGS=$01 BASE=$2000 END=$2008`,
`SEAL REC @=$6111 LEN=$0008 FNV=$FFC39D9A`, and
`SEAL REL @=$611C COUNT=$03`. `RELOCATE $3000` printed
`RELOCATE OK BASE=$3000 COUNT=$03`; the HIMON dump after leaving `SEAL>` showed
`3000: 20 07 30 A9 07 A2 30 60`, and `G 3000` returned with `A=07 X=30`.
`PACKAGE $3200` from the `SEAL>` prompt printed
`PACKAGE OK @=$3200 LEN=$0037`; the `$3200 +37` dump began
`41 50 01 37 00` and ended with the packaged original body
`20 07 20 A9 07 A2 20 60`. This closes the board proof for the shared
`ASM_RJ_WRITE_HEX_WORD_AX` output paths exercised by PC/error, table, SEAL,
RELOCATE, and PACKAGE printing. `D` remains a HIMON command and is intentionally
rejected at `SEAL>`; `PACKAGE` remains a post-END `SEAL>` command, not an
`ASM>` source command.

## Regression Protocol

Before committing ASM code:

```text
make -C SRC asm-test
```

Current `asm-test` expands to:

```text
make -C SRC asm-opcode-coverage
make -C SRC asmtest-6800-wdc-check
make -C SRC asm-v1-core
make -C SRC asm-v1-runtime
make -C SRC asm-v1-runtime-smoke
make -C SRC asm-v1-runtime-asmtest
make -C SRC asm-v1-runtime-paste
make -C SRC asm-v1-flash
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

## 2026-07-05 Afternoon RAM Split Gate

Planned flash ASM memory split:

```text
$2000-$4FFF  ASM user output/package scratch while ASM is active
$5000-$79FF  ASM private tables/work RAM
$7A00-$7EFF  HIMON/service/debug RAM, protected
$7F00-$7FFF  I/O, hard forbidden
```

Do this as two separate implementation slices. Slice one only changes the
source/output boundary. Slice two moves flash ASM UDATA from `$6000` to `$5000`
without growing tables. Table growth comes only after both slices are
host-tested and board-proven.

Host proof for the boundary slice:

```text
make -C SRC asm-test
make -C SRC asm-v1-flash
```

Inspect the flash map after the boundary slice. ASM flash `_END_DATA` must stay
below `$C000`, and the boundary code must still reject high RAM before any
partial write. No UDATA growth is expected in this slice.

Board proof for the boundary slice:

```text
ASM NEW
ORG $2000
LDA #$5A
STA $7104
RTS
END
.
G 2000
D 7104

ASM NEW
ORG $4FFF
NOP
END
.
D 4FFF

ASM NEW
ORG $4FFE
LDA #$11
END
.
D 4FFE 4FFF

ASM NEW
ORG $4FFF
LDA #$11
.

ASM NEW
ORG $5000
.

ASM NEW
ORG $7A00
.

ASM NEW
ORG $7F00
.
```

Expected board behavior:

```text
$2000 program assembles, runs, and writes $5A to $7104
$4FFF single-byte emit succeeds
$4FFE LDA #$11 exact-fit emit succeeds and writes A9 11 at $4FFE-$4FFF
$4FFF LDA #$11 rejects as ERR=$06 BAD RANGE before partial write
ORG $5000 rejects as ERR=$06 BAD RANGE
ORG $7A00 rejects as ERR=$06 BAD RANGE
ORG $7F00 rejects as ERR=$06 BAD RANGE
```

Host proof for the UDATA-move slice:

```text
make -C SRC asm-test
make -C SRC asm-v1-flash
```

Inspect the flash map after the UDATA move:

```text
_BEG_UDATA = $5000
_END_UDATA < $7A00
_END_DATA  < $C000
```

With unchanged table sizes, the projected UDATA end should be about `$6F0A`.
Keep at least `$0100-$0200` reserved before `$7A00`; do not grow symbol,
fixup, local, import, or export tables in the same slice as the move.

Board proof for the UDATA-move slice should repeat the boundary proof and then
exercise ordinary post-`END` records:

```text
ASM NEW
ORG $2000
MAIN JSR TARGET
LDA #<TARGET
LDX #>TARGET
TARGET RTS
END
SEAL
RELOCATE $3000
PACKAGE $3200
.
D 3000 3007
D 3200 3236
G 3000
```

A larger paste, such as the computed-neighbor Life sample, should still
assemble and run after the UDATA move. Record the transcript in the hardware
log before marking the slice board-proven.

## 2026-07-06 LOAD/INSTALL Host Gate

Implemented host slice:

```text
make -C SRC himon-rom
make -C SRC asm-v1-flash
make -C SRC asm-session-report
make -C SRC asm-test
```

Expected map facts for the default flash image:

```text
_BEG_UDATA = $5000
_END_DATA  <= $BB00
headroom to $C000 >= $0500
himon-rom-c000 _END_DATA < $F000
```

Current host proof produced:

```text
asm-v1-flash headroom to C000 = 0697 (_END_DATA=B969)
UDATA starts at $5000, ends at $79A6
asm-session-report end = 76D5 (limit 7A00)
asm-session-report AP bin len=$0610, run=$4800, stored outside Bank 3
Bank 3 low-flash hole after ASM-F2 = $B969-$BFFF, len=$0697
himon-rom-c000 _END_DATA=$EFE4
CMD_AP=$C687
HIM_AP_SERVICE=$D88E
HIM AP request/result cells = $7E2D-$7E40
```

Default flash `SEAL>` command surface for this slice:

```text
SEAL
RELOCATE addr
PACKAGE addr
LOAD pkg dest
INSTALL pkg
INSTALL pkg flash_addr
NEW
.
```

The old interactive `RESOLVE` command is compiled out of the default flash
image to make room for `LOAD`/`INSTALL`. Import metadata can still be packaged,
but `LOAD` rejects declared imports and `$04-$06` import relocation rows with
`BAD FIX`.

As of the 2026-07-07 resident-service split, the default flash image no longer
carries its private AP package parser/loader. `LOAD`, `INSTALL pkg`, and
`INSTALL pkg flash_addr` package parsing call HIMON's optional AP service at
`$7E2D-$7E40`. `SEAL` and `PACKAGE` remain ASM-owned because they consume the
current assembler session tables; package consumption is now a resident system
service callable by future HIMON/STR8 surfaces after ASM exits.

Default flash `SEAL` is now compact in this size slice: it computes the seal
facts and prints `SEAL OK`, while detailed seal/export/import rows remain
available through the external session reporter and non-flash proof builds.
`INSTALL pkg` remains read-only advisory. `INSTALL pkg flash_addr` asks HIMON's
optional `$7E25-$7E2C` flash-install service to copy the AP envelope unchanged
from RAM to an already erased visible `$8000-$BFFF` hole, byte-verifying through
the existing `L F` flash writer. Banked `$C000+` install remains future work.

Board proof checklist:

```text
ASM NEW
ORG $4FFF
NOP
END
.
D 4FFF
```

Expected: single-byte emit at `$4FFF` succeeds.

```text
ASM NEW
ORG $4FFF
LDA #$11
.
```

Expected: crossing `$5000` fails with `ERR=$06 BAD RANGE` before partial write.

Internal package load/run proof:

```text
ASM NEW
ORG $2000
MAIN JSR TARGET
LDA #<TARGET
LDX #>TARGET
TARGET RTS
END
PACKAGE $3200
LOAD $3200 $3000
.
D 3000 3007
G 3000
```

Expected `LOAD OK=$3000 L=$0008 C=$03`, bytes
`20 07 30 A9 07 A2 30 60`, and a clean `G 3000` return.

RAM package overlap proof:

```text
ASM NEW
ORG $2000
NOP
RTS
END
PACKAGE $3000
LOAD $3000 $3000
.
```

Expected: `LOAD ERR=$06 BAD RANGE`. The first loader slice requires RAM package
loads to copy downward, so the destination BODY must end before the AP envelope.

Import rejection proof:

```text
ASM NEW
ORG $2200
IMPORT EXT
MAIN JSR EXT
END
PACKAGE $3200
LOAD $3200 $3000
.
```

Expected: `LOAD ERR=$09 BAD FIX`.

Install advisory proof:

```text
ASM NEW
ORG $2000
LDA #$5A
RTS
END
PACKAGE $3200
INSTALL $3200
.
```

Expected: `INST @=$hhhh L=$hhhh`, where `$hhhh` is the first erased visible
flash hole in `$8000-$FEFF`. The command must not write flash.

Install write proof:

```text
ASM NEW
ORG $2000
LDA #$5A
RTS
END
PACKAGE $3200
INSTALL $3200
INSTALL $3200 $hhhh
LOAD $hhhh $3000
.
G 3000
```

Use the advisory address from the preceding `INSTALL $3200` as `$hhhh`.
Expected: `INSTALL $3200 $hhhh` reports `INST @=$hhhh L=$0023`, then
`LOAD $hhhh $3000` reports `LOAD OK=$3000 L=$0003 C=$00`, and `G 3000` returns
with `A=5A`. Negative checks: `INSTALL $3200 $C000` reports
`INST ERR=$06 BAD RANGE`, and re-running `INSTALL $3200 $hhhh` against the
now-written hole reports `INST ERR=$06 BAD RANGE`.

External report proof:

```text
L              send SRC/BUILD/s19/asm-session-report-7000.s19 before ASM work
ASM NEW
ORG $2000
MAIN JSR TARGET
TARGET RTS
END
.
G 7000
```

Expected: `END` prints no automatic `ASM TABLES`; `G 7000` prints the
external compact report header followed by the raw table sections:

```text
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$2000
PC=$2004
HIGH=$2004
BYTES=$0004
LINES=$0004
SYMS=$02/$40
FIXUPS=$01/$80
REFS=$hh/$C0
TRUNC=NO
MAP END=$.... UDATA=$5000-....
SESSION
SYMBOLS
FIXUPS
RELOCS
ASM REPORT OK
```

Flash ASM-native source form:

```text
ASM NEW        paste DOC/GUIDES/ASM/SAMPLES/asm-session-report-4800.a
.
ASM NEW        run the session to inspect
...
END
.
G 4800
```

Expected: the preloaded `$4800` reporter prints the same table sections.
`asm-session-report-transient-7000.a` is only for non-flash/runtime-paste ASM builds that
still permit `$7000` output.
The flash-native `$4800` source is generated as a compact ASM-F2 program. The
generator uses literal message addresses and single-character `DB` atoms, so it
keeps the live program at 59 labels and avoids ASM-F2's double-quoted string
gap while fitting under the current `$40` symbol limit. For AP storage, the
generated source also resolves its internal `JSR`/`JMP` targets to fixed
literal addresses and emits `ENTRY START`; load/run the package only at the
same `$4800` origin.

Bank 0 reporter AP proof:

```text
make -C SRC himon-str8-rom-bin
make -C SRC himon-str8-himon-update-s19
make -C SRC asm-session-report-ap-bin
```

Expected host build facts:

```text
HIMON START/NMI/IRQ/END = C000/E70D/E710/EFE4
ASM-F2 BASE/START/END  = 8000/800C/B969
Bank 3 low-flash hole   = B969-BFFF, len=0697
ASM report AP bin len   = 0610
```

Board script after updating HIMON and storing the reporter AP in Bank 0:

```text
ASM NEW
ORG $2000
MAIN JSR TARGET
TARGET RTS
END
.
AP B0 $hhhh $4800
```

Expected: `AP B0 $hhhh $4800` prints `GO 4800`, runs the Bank 0 AP package at
`$4800`, prints the same `ASM REPORT ... ASM REPORT OK` table output, and then
returns through HIMON's normal command-return path for entry `$4800`.

Older Bank 2 `$8000` AP storage path for the same reporter, retained as an
alternate storage proof and not the current Bank 0 reporter placement:

```text
ASM NEW        paste DOC/GUIDES/ASM/SAMPLES/asm-session-report-4800.a
SEAL           at SEAL>, expect SEAL OK
PACKAGE $3200  at SEAL>, expect PKG OK @=$3200
.
D 3200 3208    expect AP header: 41 50 ...
ASM NEW        paste DOC/GUIDES/ASM/SAMPLES/bank2put-8000-transient-3000.a
.
G 3000         expect $1A00=$AC
ASM NEW        run the session to inspect
...
END
.
AP B2 $8000 $4800
```

If `PACKAGE $3200` reports `PKG ERR=$02` after the reporter itself assembled
with `ASM OK`, the generated reporter is not package-clean. The 2026-07-10
board run found this in an older generated `$4800` source whose internal label
calls exceeded the AP relocation table (`ASM_RELOC_MAX=$10`) and left bad seal
flags. Regenerate with `make -C SRC asm-session-report`; the fixed source uses
literal internal call targets and should package for fixed-address `$4800` use.

Board result captured 2026-07-10 in
`DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`: the regenerated fixed-address
`asm-session-report-4800.a` assembled under ASM-F2, `SEAL` succeeded, and
`PACKAGE $3200` returned `PKG OK @=$3200 L=$0658`. The AP header dump started
`41 50 01 58 06 53 0B 01 00`. The board-buildable
`bank2put-8000-transient-3000.a` installer then ran with `RET A=AC` and left
`$1A00=AC`. Finally, `AP B2 $8000 $4800` ran the stored reporter from bank 2
and printed `ASM REPORT OK`, proving the fixed-address package/install/run
path while preserving the current relocation-row-cap TODO.

Board result captured 2026-07-06:

```text
HIMON V 00.0706(1619)
L F
L @8000
LF OK WR=3DEC GO=800C
```

The first board pass against the previous `$3DF2` flash image exposed
`LOAD $3200 $3000 -> LOAD ERR=$03 BO`; the two-argument parser was using a
UDATA pointer with `(ptr),Y`, so it read the wrong operand text. The fixed
`$3DEC` image reuses the existing zero-page command pointer and produced:

```text
ORG $4FFF / NOP / END       -> ASM OK, D 4FFF = EA
ORG $4FFF / LDA #$11        -> ERR=$06 BAD RANGE PC=$4FFF
PACKAGE $3200               -> PKG OK @=$3200 L=$0037
LOAD $3200 $3000            -> LOAD OK=$3000 L=$0008 C=$03
D 3000 3007                 -> 20 07 30 A9 07 A2 30 60
G 3000                      -> clean return, A=07 X=30 Y=30
import package LOAD         -> LOAD ERR=$09 BAD FIX
INSTALL $3200               -> INST @=$BDEC L=$0023
D BDEC FF                   -> all $FF over suggested hole
```

The follow-up RAM overlap fix stores the computed load-end high byte before the
overlap check. Current host image for that retest is:

```text
LF OK WR=3DEE GO=800C
_END_DATA=$BDEE
PACKAGE $3000               -> PKG OK @=$3000 L=$0022
LOAD $3000 $3000            -> LOAD ERR=$06 BAD RANGE
```

Combined package/load/run board proof captured 2026-07-06:

```text
ORG $2000
MAIN JSR FORWARD
BRA AFTER_BACK
BACK RTS
AFTER_BACK LDX #$03
LOOP DEX
BNE LOOP
JSR BACK
LDA #<FORWARD
LDY #>FORWARD
RTS
FORWARD LDA #$5A
RTS
EXPORT MAIN
EXPORT FORWARD
EXPORT BACK
END
SEAL
PACKAGE $3200
INSTALL $3200
LOAD $3200 $3000
```

The board produced:

```text
SEAL OK FLAGS=$01 BASE=$2000 END=$2016
SEAL REL @=$5122 COUNT=$04
SEAL EXP @=$5173 COUNT=$03 LEN=$0019
PKG OK @=$3200 L=$0061
INST @=$BDEE L=$0061
LOAD OK=$3000 L=$0016 C=$04
D 3000 3015 -> 20 13 30 80 01 60 A2 03 CA D0 FD 20 05 30 A9 13 A0 30 60 A9 5A 60
G 3000      -> clean return, A=13 X=00 Y=30
D BDEE BEED -> all $FF over the suggested install hole
```

Follow-up board attempt on the write slice exposed two practical details:
the one-argument advisory path was restored after the two-argument parser
clobbered `Y`, and `SEAL>` operands are ASM expressions, so a flash address
must be entered with a `$` prefix (the attempted bare `BD0B` was parsed as a
symbol and reported `BS`).

The next board run reached the service with the fixed wrapper:

```text
LF OK WR=3D0F GO=800C
PACKAGE $3200           -> PKG OK @=$3200 L=$0023
INSTALL $3200           -> INST @=$BD0F L=$0023
INSTALL $3200 $BD0F     -> INST @=$BD0F L=$0023
LOAD $BD0F $3000        -> LOAD ERR=$07 BL
D BD0F BD31             -> all $FF
```

That proved the wrapper parser and `$` expression issue were fixed, but the
HIMON install service falsely returned success without committing bytes. The
follow-up host patch makes the two-argument wrapper set `ASM_PACKAGE_BASE`
explicitly and makes `HIM_FLASH_INSTALL_COPY` write/verify each byte directly
through `FLASH_WRITE_BYTE_AXY` instead of sharing the S19 loader write helper.

The same pass proved the current import-package rejection path:

```text
ORG $2200
IMPORT BIO_FTDI_PUT_CSTR
MAIN JSR BIO_FTDI_PUT_CSTR
LDA #<BIO_FTDI_PUT_CSTR
LDX #>BIO_FTDI_PUT_CSTR
END
SEAL
PACKAGE $3400
LOAD $3400 $3000
```

Expected/current result:

```text
SEAL REL @=$5122 COUNT=$03
SEAL IMP @=$523D COUNT=$01 LEN=$000F
PKG OK @=$3400 L=$0043
LOAD ERR=$09 BAD FIX
```

Host-built reporter board proof captured 2026-07-06 against the then-current
compact format:

```text
L @7000                     -> L OK=06D5 GO=7000
ASM NEW / ORG $2000 / ...
END                         -> ASM OK, no automatic ASM TABLES
G 7000                      -> ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$2000
PC=$2004
HIGH=$2004
BYTES=$0004
LINES=$0004
SYMS=$02/$28
FIXUPS=$01/$60
REFS=$00/$A0
TRUNC=NO
MAP END=$BDEE UDATA=$5000-6F16
COUNTS SYM FIX REL EXP IMP IMPRES RELCNT 02 01 01 00 00 00 00
UNUSED                      -> MAIN, TARGET
SYMBOLS                     -> MAIN, TARGET
FIXUPS                      -> TARGET row at SITE 2001 BASE 2003
RELOCS                      -> 00 01 0001 0003
ASM REPORT OK
```

The first flash-write board rerun showed why the write failed before calling
the service: `D 7E1D 24` reported `01 3B 00 32 0F BD 23 00`, proving the
temporary flash-install vector overlapped HIMON's `$7E1D/$7E1E` RX lookahead
cells. The service block moved to `$7E25-$7E2C`.

The repaired LOAD/INSTALL/report extraction slice is board-proven on the
`$3D1B` flash ASM image with HIMON `V 00.0706(1928)`:

```text
D 7E25 2C                  -> DD D5 00 00 00 00 00 00
L F                         -> LF OK WR=3D1B GO=800C
PACKAGE $3200               -> PKG OK @=$3200 L=$0023
INSTALL $3200               -> INST @=$BD1B L=$0023
INSTALL $3200 $BD1B         -> INST @=$BD1B L=$0023
LOAD $BD1B $3000            -> LOAD OK=$3000 L=$0003 C=$00
D BD1B BD3D                 -> AP envelope ending in A9 5A 60
D 3000 3002                 -> A9 5A 60
G 3000                      -> RET A=5A
G 7000                      -> ASM REPORT OK, PKG @ LEN BODY INST BD1B 0023 0003 BD1B
```

Follow-up operator proof confirmed the command-mode rule for loading an
installed AP envelope. Typing `LOAD $BD1B $3800` at the `ASM>$2000:` source
prompt returns `ERR=$01 BM`; entering an empty `ASM NEW` / `END` session reaches
`SEAL>`, where the same load succeeds:

```text
ASM NEW / END
SEAL> LOAD $BD1B $3800     -> LOAD OK=$3800 L=$0003 C=$00
SEAL> D 3800 FF            -> ERR=$03 BO
D 3800 FF                  -> A9 5A 60 ...
G 3800                     -> RET A=5A
```

The same board run confirmed occupied-hole and explicit-address behavior after
the first package was installed at `$BD1B`:

```text
INSTALL $3200              -> INST @=$BD3E L=$0023
INSTALL $3200 $BD1B        -> INST ERR=$06 BAD RANGE
INSTALL $3200 $BDE0        -> INST @=$BDE0 L=$0023
LOAD $BDE0 $3A12           -> LOAD OK=$3A12 L=$0003 C=$00
G 7000                     -> ASM REPORT OK, PKG @ LEN BODY INST BDE0 0023 0003 BDE0
D BD00 FF                  -> second AP envelope starts at BDE0 and continues past BDFF
```

The first paste of the SPIL roundtrip sample, then misleadingly named
`life.a`, against HIMON `V 00.0706(2013)` / flash ASM `LF OK WR=3D1B GO=800C`
exposed two next-incarnation ASM requirements rather than a LOAD/INSTALL
failure:

```text
START   BRA RUN       -> ERR=$02 BAD DIR
EXPORT START          -> ERR=$08 BAD SYM
FWDVEC  DW TARGET     -> ERR=$08 BAD SYM
FWDLO   DB <TARGET    -> ERR=$05 BAD WIDTH
END                   -> ERR=$09 BAD FIX
```

Current acceptance has moved: `START` is now a legal label, and `ENTRY MAIN`
is the preferred source spelling for the package entry/public export row.
The 2026-07-11 host slice accepts forward-label `DW TARGET`, `DB <TARGET`,
and `DB >TARGET`, patches them when the label binds, and emits the
corresponding internal relocation rows. The board SPIL sample still awaits a
focused retest with those source forms restored.

Corrected `spill-roundtrip-2000.a` board proof followed on the same
HIMON/flash ASM generation. The transcript includes an installed AP envelope
at `$BD1B` with length `$00FD`, a `LOAD` to non-page-aligned `$3123`, and the
corrected source paste reaches clean `END`:

```text
MAIN    BRA RUN
EXPORT MAIN
...
END                         -> ASM OK
PACKAGE $3200               -> PKG OK @=$3200 L=$00FD
INSTALL $3200               -> INST @=$BD1B L=$00FD
INSTALL $3200 $BD1B         -> INST @=$BD1B L=$00FD
LOAD $BD1B $3123            -> LOAD OK=$3123 L=$00B3 C=$07
G 3123                      -> RET A=AC X=00 Y=32
G 2000                      -> RET A=E3 X=00 Y=30
```

`G 3123` returning `A=AC` proves the corrected non-page-aligned relocated body
success path. The current source sample now uses `ENTRY MAIN` in place of the
board-proven `EXPORT MAIN` line, producing the same export metadata row while
making the entry intent explicit. `G 2000` returning `A=E3` is expected for this
sample: the original unrelocated body deliberately checks for `$3123`-based
relocated addresses and fails its target-address check at the original `$2000`
base.

## 2026-07-07 ENTRY + Resident AP Service Board Gate

This is the combined bench proof for commit `fbf04bc`: `ENTRY` is now an ASM
directive, `START` is an ordinary label again, and flash ASM package
load/install paths call HIMON's resident AP service.

Host prep:

```text
make -C SRC himon-rom
make -C SRC asm-session-report
make -C SRC asm-v1-flash
make -C SRC asm-test
```

Board prep:

```text
update the board to the current HIMON image using the normal STR8/HIMON flow
boot HIMON and record the visible version
D 7E25 40
L                       send SRC/BUILD/s19/asm-session-report-7000.s19
L F                     send SRC/BUILD/s19/asm-v1-flash-8000.s19
ASM
```

Expected service-cell proof before AP use:

```text
D 7E25 40    -> F1 D5 00 00 00 00 00 00 B2 D6 00 ... 00
L            -> L OK=06D5 GO=7000
L F          -> LF OK WR=3A08 GO=800C
ASM          -> ASM FLASH
```

The exact HIMON version string should match the newly installed image. The
`D 7E25 40` bytes prove the flash-install service vector at `$D5F1` and the AP
service vector at `$D6B2` are resident before flash ASM starts.

Pasteable ENTRY positive proof:

```text
ASM NEW
ORG $2400
START LDA #$5A
RTS
ENTRY START
END
SEAL
PACKAGE $3200
LOAD $3200 $3000
INSTALL $3200
INSTALL $3200 $hhhh
LOAD $hhhh $3100
.
D 3215 321B
D 3000 3002
D 3100 3102
G 3000
G 3100
G 7000
```

Use the address printed by `INSTALL $3200` as `$hhhh`. Expected results:

```text
END                         -> ASM OK
SEAL                        -> SEAL OK
PACKAGE $3200               -> PKG OK @=$3200 L=$002A
D 3215 321B                 -> 45 09 01 09 00 00 05
LOAD $3200 $3000            -> LOAD OK=$3000 L=$0003 C=$00
INSTALL $3200               -> INST @=$hhhh L=$002A
INSTALL $3200 $hhhh         -> INST @=$hhhh L=$002A
LOAD $hhhh $3100            -> LOAD OK=$3100 L=$0003 C=$00
D 3000 3002                 -> A9 5A 60
D 3100 3102                 -> A9 5A 60
G 3000                      -> RET A=5A
G 3100                      -> RET A=5A
G 7000                      -> COUNTS ... EXP ... shows EXP=$01,
                                PKG @ LEN BODY INST $hhhh 002A 0003 $hhhh
```

The `D 3215 321B` row proves `ENTRY START` emitted an AP export section:
`E`, section length `$09`, export count `$01`, export record length `$09`,
entry offset `$0000`, and name length `$05`. The two `LOAD` commands prove both
RAM-source AP loading and installed-flash AP loading through the same resident
HIMON AP service.

Pasteable ENTRY negative proof:

```text
ASM NEW
ORG $2500
ENTRY
ENTRY MISSING
START RTS
ENTRY START
ENTRY START
.
```

Expected:

```text
ENTRY                       -> ERR=$03 BO
ENTRY MISSING               -> ERR=$08 BS
START RTS                   -> OK
ENTRY START                 -> OK
second ENTRY START          -> ERR=$08 BS
.                           -> return to HIMON
```

Pasteable HIMON/AP positive proof, including resident service cells:

```text
ASM NEW
ORG $2400
START LDA #$5A
RTS
ENTRY START
END
PACKAGE $3200
LOAD $3200 $3000
INSTALL $3200
INSTALL $3200 $hhhh
LOAD $hhhh $3100
.
D 3000 3002
D 3100 3102
G 3000
G 3100
D 7E2D 40
G 7000
```

Use the advisory address from `INSTALL $3200` as `$hhhh`. Expected:

```text
PACKAGE $3200               -> PKG OK @=$3200 L=$002A
LOAD $3200 $3000            -> LOAD OK=$3000 L=$0003 C=$00
INSTALL $3200               -> INST @=$hhhh L=$002A
INSTALL $3200 $hhhh         -> INST @=$hhhh L=$002A
LOAD $hhhh $3100            -> LOAD OK=$3100 L=$0003 C=$00
D 3000 3002                 -> A9 5A 60
D 3100 3102                 -> A9 5A 60
G 3000                      -> RET A=5A
G 3100                      -> RET A=5A
D 7E2D 40                   -> AP vector B2 D6, OP=01, STATUS=00,
                                SRC=$hhhh, DST=$3100, PKGLEN=$002A,
                                BODYLEN=$0003, RELOCS=$00, IMPORTS=$00
G 7000                      -> ASM REPORT OK, EXP=$01,
                                PKG @ LEN BODY INST $hhhh 002A 0003 $hhhh
```

Pasteable HIMON/AP negative proof:

```text
ASM NEW
ORG $2400
START LDA #$5A
RTS
ENTRY START
END
PACKAGE $3200
LOAD $3201 $3000
LOAD $3200 $3200
INSTALL $3200 $C000
INSTALL $3200
INSTALL $3200 $hhhh
INSTALL $3200 $hhhh
NEW
ORG $2200
IMPORT BIO_FTDI_PUT_CSTR
MAIN JSR BIO_FTDI_PUT_CSTR
END
PACKAGE $3400
LOAD $3400 $3000
.
```

Use the advisory address from `INSTALL $3200` as `$hhhh`. Expected:

```text
PACKAGE $3200               -> PKG OK @=$3200 L=$002A
LOAD $3201 $3000            -> LOAD ERR=$07 BL
LOAD $3200 $3200            -> LOAD ERR=$06 BAD RANGE
INSTALL $3200 $C000         -> INST ERR=$06 BAD RANGE
INSTALL $3200               -> INST @=$hhhh L=$002A
INSTALL $3200 $hhhh         -> INST @=$hhhh L=$002A
second INSTALL $3200 $hhhh  -> INST ERR=$06 BAD RANGE
IMPORT ... / MAIN JSR ...   -> accepted source
PACKAGE $3400               -> PKG OK @=$3400 L=$0035
LOAD $3400 $3000            -> LOAD ERR=$09 BAD FIX
.                           -> return to HIMON
```

These negatives cover malformed AP source, RAM overlap, protected flash target,
occupied flash target, and the current import boundary. The import case is
important: AP can store import metadata today, but HIMON/AP `LOAD` rejects
packages that need resident import binding until a later `LINK`/run slice.

Extended SPIL proof:

```text
ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/spill-roundtrip-2000.a
PACKAGE $3200
INSTALL $3200
INSTALL $3200 $hhhh
LOAD $hhhh $3123
.
D 5848 5850
G 3123
D 5848 5850
G 7000
```

Do not exit `SEAL>` before `LOAD $hhhh $3123`; `INSTALL` stores the AP envelope
only. If `LOAD` is skipped, `G 3123` is expected to trap or run stale bytes
because no relocated body has been copied to `$3123`.

Expected:

```text
END                         -> ASM OK
PACKAGE $3200               -> PKG OK @=$3200 L=$00FD
INSTALL $3200               -> INST @=$hhhh L=$00FD
INSTALL $3200 $hhhh         -> INST @=$hhhh L=$00FD
LOAD $hhhh $3123            -> LOAD OK=$3123 L=$00B3 C=$07
G 3123                      -> RET A=AC X=00 Y=32
D 5848 5850                 -> AC 00 6E 31 6E 31 44 31 5A
G 7000                      -> ASM REPORT OK, EXP=$01, PKG/INST use $hhhh
```

This extended pass is the real package lifecycle proof: `ENTRY MAIN` marks the
entry/export metadata, the AP envelope installs to visible flash, HIMON's AP
service loads the installed envelope to non-page-aligned `$3123`, and the
relocated code self-checks the patched internal addresses.

Board result captured 2026-07-07 in `DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`:
the service-cell prep, compact ENTRY positive, ENTRY negative, HIMON/AP
positive, and HIMON/AP negative blocks passed on HIMON `V 00.0707(1532)` with
flash ASM `LF OK WR=3A08 GO=800C`. The extended SPIL paste assembled,
packaged, and installed at `$BAB0`. The first attempt skipped
`LOAD $BAB0 $3123` before leaving `SEAL>`, so `G 3123` trapped on
unloaded/stale memory. A follow-up tail run then passed:
`LOAD $BAB0 $3123 -> LOAD OK=$3123 L=$00B3 C=$07`,
`G 3123 -> RET A=AC X=00 Y=32`, and
`D 5848 5850 -> AC 00 6E 31 6E 31 44 31 5A`.

The tail-only reporter was run from a fresh empty ASM session, so it showed
empty live-session symbols/exports and `PKG @ LEN BODY INST BAB0 00FD 00B3
0000`. That is expected for this recovery run; the pass criteria are the
resident HIMON/AP `LOAD`, successful relocated execution, patched data bytes,
and the retained seven AP relocation rows.

## 2026-07-07 HIMON AP Command Board Gate

This is the board gate for the resident hashed HIMON `AP pkg dst` command. The
command is intentionally small: it calls the resident AP `LOAD` service, then
runs `dst` through the existing monitor return-report path. V0 requires the AP
package entry to be BODY offset zero; it does not yet parse ENTRY exports or
install per-package command-name records.

Host prep:

```text
make -C SRC himon-rom
```

Current host build facts:

```text
himon-rom-c000 _END_DATA=$EE47
CMD_AP=$C66D
HIM_AP_SERVICE=$D735
AP command hash=$3AD53794
HIM AP request/result cells=$7E2D-$7E40
```

Board prep:

```text
update the board to the current HIMON image using the normal STR8/HIMON flow
boot HIMON and record the visible version
D 7E2D 40
```

If the previous SPIL package at `$BAB0` is still installed in visible flash,
use it directly. Otherwise rebuild/install the SPIL AP package with flash ASM,
record the installed address as `$hhhh`, exit ASM, and run the command from the
plain HIMON prompt.

Pasteable erased-board quick positive proof:

```text
ASM NEW
ORG $2400
MAIN LDX #<TARGET
LDY #>TARGET
LDA #$A7
RTS
TARGET DB $00
ENTRY MAIN
END
SEAL
PACKAGE $3200
LOAD $3200 $3000
INSTALL $3200
INSTALL $3200 $hhhh
LOAD $hhhh $3123
.
G 3000
G 3123
AP
AP $hhhh $2800
D 2800 FF
```

Use the advisory address from `INSTALL $3200` as `$hhhh`. Expected:

```text
PACKAGE $3200               -> PKG OK @=$3200 L=$0039
LOAD $3200 $3000            -> LOAD OK=$3000 L=$0008 C=$02
INSTALL $3200               -> INST @=$hhhh L=$0039
INSTALL $3200 $hhhh         -> INST @=$hhhh L=$0039
LOAD $hhhh $3123            -> LOAD OK=$3123 L=$0008 C=$02
G 3000                      -> RET A=A7 X=07 Y=30
G 3123                      -> RET A=A7 X=2A Y=31
AP                           -> AP pkg dst
AP $hhhh $2800              -> GO 2800, RET A=A7 X=07 Y=28
D 2800 FF                   -> A2 07 A0 28 A9 A7 60 00 ...
```

Pasteable positive proof using the existing `$BAB0` SPIL package:

```text
AP $BAB0 $3123
D 5848 5850
D 7E2D 40
```

Expected:

```text
AP $BAB0 $3123             -> GO 3123
                              #GO# ENTRY=3123
                              RET A=AC X=00 Y=32
D 5848 5850                -> AC 00 6E 31 6E 31 44 31 5A
D 7E2D 40                  -> AP vector $D735, OP=01, STATUS=00,
                              SRC=$BAB0, DST=$3123, PKGLEN=$00FD,
                              BODYLEN=$00B3, RELOCS=$07, IMPORTS=$00
```

Pasteable negative proof:

```text
AP $3201 $3000
AP $hhhh $hhhh
AP
```

Expected:

```text
AP $3201 $3000             -> APERR=$07
AP $hhhh $hhhh             -> APERR=$06
AP                          -> AP pkg dst
```

Pasteable RAM-window edge proof:

```text
AP $7000 $hhhh
AP $6000 $hhhh
AP $hhhh $7000
AP $hhhh $6000
AP $hhhh $4000
AP $hhhh $5000
```

Expected:

```text
AP $7000 $hhhh             -> APERR=$06
AP $6000 $hhhh             -> APERR=$06
AP $hhhh $7000             -> APERR=$06
AP $hhhh $6000             -> APERR=$06
AP $hhhh $4000             -> GO 4000, RET A=A7 X=07 Y=40
AP $hhhh $5000             -> APERR=$06
```

Board result captured 2026-07-07 in `DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`:
the erased-board quick positive proof passed on HIMON `V 00.0707(1652)` after
STR8 updated HIMON and `L F` reloaded flash ASM. The installed package landed
at `$BA08`, `LOAD $BA08 $3123` returned `LOAD OK=$3123 L=$0008 C=$02`, `AP`
printed `AP pkg dst`, and `AP $BA08 $2800` ran through the monitor return path
with `RET A=A7 X=07 Y=28`. The first dump line at `$2800` was
`A2 07 A0 28 A9 A7 60 00`, proving the resident command copied and relocated
the BODY bytes. An earlier unsupported stress package propagated the shared AP
service error as `APERR=$09`. The command negatives also passed:
`AP $3201 $3000 -> APERR=$07`, `AP $BA08 $BA08 -> APERR=$06`, and bare `AP`
printed `AP pkg dst`. The RAM-window edge proof passed too: destinations
`$6000`, `$7000`, and `$5000` returned `APERR=$06`, while `AP $BA08 $4000`
ran with `RET A=A7 X=07 Y=40`.

## 2026-07-07 Resident PACK40 Service Gate

Flash ASM now calls HIMON's resident PACK40 encode service for the pure
`ASCII_TO_CODE` and `PACK3` primitives used by IMPORT/EXPORT metadata. The
ASM-specific symbol/name walking stays in ASM, and non-flash ASM builds keep
their local PACK40 implementation.

Host prep:

```text
make -C SRC himon-rom
make -C SRC asm-v1-flash
make -C SRC asm-test
```

Current host build facts:

```text
himon-rom-c000 _END_DATA=$EEFE
HIM_PACK40_ASCII_TO_CODE=$D749
HIM_PACK40_PACK3=$D789
HIM_AP_SERVICE=$D7EC
PACK40 service cells=$7E1F-$7E22
asm-v1-flash _END_DATA=$B966
asm-v1-flash headroom to $C000=$069A
ASM_PACK40_ASCII_TO_CODE=$B525
ASM_PACK40_PACK3=$B528
```

Pasteable board proof after updating HIMON and reloading flash ASM:

```text
D 7E1F 22
ASM NEW
ORG $2400
MAIN RTS
EXPORT MAIN
IMPORT BIO_FTDI_PUT_CSTR
END
SEAL
PACKAGE $3200
.
D 3215 3230
```

Expected:

```text
D 7E1F 22                  -> 49 D7 89 D7
END                         -> ASM OK
SEAL                        -> SEAL OK
PACKAGE $3200               -> PKG OK @=$3200 L=$0035
D 3215 3230                 -> 45 09 01 09 00 00 04 71
                                51 80 57 49 0F 01 0F 11
                                F7 0D 44 E8 8D 1A 5C 67
                                CB E7 D0 7F
```

The dump starts at the AP export tag. It proves `MAIN` packs as
`71 51 80 57` and `BIO_FTDI_PUT_CSTR` packs as
`F7 0D 44 E8 8D 1A 5C 67 CB E7 D0 7F` through the resident service.

Pasteable direct service positive/negative proof:

```text
ASM NEW
ORG $2400
P40A JMP ($7E1F)
P403 JMP ($7E21)
MAIN LDA #'A'
JSR P40A
BCC FAIL
CMP #$01
BNE FAIL
LDA #'@'
JSR P40A
BCS FAIL
LDA #$01
LDX #$02
LDY #$03
JSR P403
BCC FAIL
CPX #$93
BNE FAIL
CPY #$06
BNE FAIL
LDA #$28
LDX #$00
LDY #$00
JSR P403
BCS FAIL
LDA #$A7
BRA DONE
FAIL LDA #$E1
DONE STA $4900
RTS
ENTRY MAIN
END
.
G 2406
D 4900 4900
```

Expected:

```text
END                         -> ASM OK
G 2406                      -> RET A=A7 ...
D 4900 4900                 -> A7
```

Failure code in `$4900`: `$E1` means the accepted ASCII path, invalid ASCII
rejection, PACK3 positive path, or invalid PACK3 rejection failed.

Board result captured 2026-07-07 in `DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`:
after STR8 updated HIMON to `V 00.0707(1822)` and `L F` reloaded flash ASM,
`D 7E1F 22` returned `49 D7 89 D7`. The flash ASM package proof passed:
`PACKAGE $3200 -> PKG OK @=$3200 L=$0035`, and the HIMON dump at `$3215`
matched the expected `MAIN` and `BIO_FTDI_PUT_CSTR` PACK40 bytes. The direct
resident-service positive/negative proof also passed: `G 2406` returned
`A=A7`, and `$4900` contained `$A7`, proving the `'A'` ASCII positive, `'@'`
ASCII negative, `PACK3(1,2,3)` positive, and `$28` PACK3 negative cases. An
attempted pre-`L F` run showed `HSH_NF`, confirming ASM must be resident before
using `ASM NEW`.

## 2026-07-09 OIL .710 Gate 3 Import Linker Proof

Board result captured 2026-07-09 in
`DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`: after the corrected
`topwr-transient-3000.a` pass, the rebuilt STR8 top-stage image showed the expected
`B7 F6` staging and flash signatures at `$0D94/$F394`. The
`banked-rjoin-smoke.a` AP package then loaded to `$3000` with
`LOAD OK=$3000 L=$0028 C=$05`.

Gate 3 passes on this image. The linker debug row was
`06 0F 30 79 E7 04 05 01`, proving the final HI8 import row patched site
`$300F` with resolved resident address `$E779`; `$3006-$3008` dumped as
`20 79 E7` instead of the old `20 FF FF`. Running `G 3000` printed
`BANK RJOIN`, returned `A=$AC`, and left `$5848=$AC` plus
`$584A/$584B=$79/$E7`. Banked AP gates may proceed after this proof.

## 2026-07-09 OIL .710 Gate 4 Missing Import Proof

Board result captured 2026-07-09 in
`DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`: a package that declared
`IMPORT OIL_MISSING_SYMBOL` and emitted `JSR OIL_MISSING_SYMBOL` assembled and
packaged at `$3200`, then failed `LOAD $3200 $3000` with
`LOAD ERR=$09 BAD FIX`. The pre-cleared success byte stayed `$5848=00`,
proving the body did not run. The reporter showed one `$04` import relocation
row at site `$0001`, import count `$01`, import-resolved count `$00`, and
body installed length `$0000`.

## 2026-07-09 OIL .710 Gate 5 Banked AP No-Import Proof

Board result captured 2026-07-09 in
`DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`: `banked-ap-smoke.a` packaged at
`$3200` with three internal relocation rows, and the corrected
`bankput-transient-3000.a` installed that AP envelope into bank 2 `$9000` with
`$1A00=AC`. `AP B2 $9000 $3000` then loaded and ran the package from RAM.
The result dump was `$5848=$AC`, `$584A/$584B=$2E/$30`, and `$5850=$5A`,
proving the banked source path and internal AP relocations without imports.

## 2026-07-09 OIL .710 Gate 6 Banked RJOIN Import Proof

Board result captured 2026-07-09 in
`DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`: the corrected `bankput-transient-3000.a`
installed the `banked-rjoin-smoke.a` AP envelope into bank 2 `$9000`, then
`AP B2 $9000 $3000` loaded, linked, and ran it. The AP printed
`BANK RJOIN`, `$3006-$3008` dumped as `20 79 E7`, and the linker debug row
was `06 0F 30 79 E7 04 05 01`. The result bytes were `$5848=$AC` and
`$584A/$584B=$79/$E7`, proving the banked source path plus resident RJOIN
import resolution and patching.

## 2026-07-09 OIL .710 Gate 7 Banked AP Error Proof

Board result captured 2026-07-09 in
`DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`: invalid banked AP forms were rejected
without running the package body. `AP B3 $9000 $3000` and
`AP B2 $9000 $3000 X` printed usage, while protected/invalid ranges and
overlap returned `APERR=$06` or `APERR=$07` as expected. `$5848` was cleared
before each case and remained `$00` after every rejected command.

## 2026-07-09 OIL .710 Gate 8 Overlap/Staging Proof

Board result captured 2026-07-09 in
`DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`: a tiny RAM AP package at `$3200`
rejected `LOAD $3200 $3200` with `LOAD ERR=$06 BAD RANGE`, proving the
visible-RAM overlap guard still fires. The already installed bank 2 RJOIN
package then ran again with `AP B2 $9000 $3000`, printed `BANK RJOIN`, and
left `$5848=$AC`, `$584A/$584B=$79/$E7`, and `$5850=$5A`, proving the banked
source path still works after the overlap negative.

## 2026-07-09 OIL .710 Gate 9 Regression Shortlist Proof

Board result captured 2026-07-09 in
`DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`: bare `M` printed usage, `STR8`
entered the bootloader and returned through cold boot with `RAM ZERO OK`,
flash `ASM` entered and exited cleanly, the bank 2 RJOIN AP package still ran
after reboot, and the reporter printed `ASM REPORT OK` after being reloaded at
`$7000`. The first post-cold-boot `G 7000` trapped at zeroed RAM; this is
expected because the reporter is RAM-loaded and must be reloaded after
`RAM ZERO OK`.

## 2026-07-10 ASM-F2 STR8-N Topwriter Proof

Board result captured 2026-07-10 in
`DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`: `L F` loaded the current flash ASM
with `LF OK WR=3969 GO=800C`, and entering `ASM` printed `ASM-F2`.

The generated `DOC/GUIDES/ASM/SAMPLES/str8n-topwrite-transient-3000.a` source then
assembled cleanly under ASM-F2. This is the one-file top-sector writer with an
embedded `$4000-$4FFF` image, so it exercises the enlarged table budget and a
large literal `DB` paste without the earlier `BAD FIX` failure pattern.

Running `G 3000` printed `TW STG` then `TW OK`, left `$1A00-$1A03` as
`00 AC 00 00`, and staged bytes at `$0A00/$14A4/$14CE/$16E3/$19FA` matched
the expected STR8-N jump table, prompt, `$FACE` identity, worker head, and
vectors. Running `G 3003` printed `TW PRG` then `TW OK`, left
`$1A00-$1A03` as `01 AC 00 00`, and the ROM dumps at
`$F000/$FAA4/$FACE/$FCE3/$FFFA` matched the same image.

## 2026-07-10 ASM-F2 Life16 Bank 2 Partial Proof

Board result captured 2026-07-10 in
`DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`: flash HIMON reported
`HIMON V 00.0710(1553)` and flash ASM reported `ASM-F2`. The
`life16-column-2000.a` source assembled cleanly, and `PACKAGE $3200` produced
`PKG OK @=$3200 L=$01DE`.

The follow-on bank write used `bank2put-8000-transient-3000.a`, not the `$9000`
`bankput-transient-3000.a` helper used by the full Life walkthrough. The helper returned
`A=$AC` and `$1A00=AC`, so the write path is partially proven, but the run
commands tried `AP B2 $9000 $3000` and `AP B2 $A000 $3000`; both returned
`APERR=$07` because neither source address matched the helper's `$8000`
storage address. The next retry for that exact board state is
`AP B2 $8000 $3000`. To follow the Life guide exactly, rerun
`bankput-transient-3000.a` and then use `AP B2 $9000 $3000`.

## 2026-07-10 ASM-F2 Interactive Banked Flash Erase Proof

Board result captured 2026-07-10 in
`DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`: `flash-erase-bank-transient-2000.a` assembled with
`ASM OK`, rejected invalid sectors, and aborted an empty confirmation with
`A=$E0` and no flash write. A single B1 sector erase and two B1 `ALL` passes
returned `A=$AC`; STR8 maps verified the selected erased sectors. STR8 backup
rotation then repopulated B1 from B2 and B2 from B3.

The B3 guard rejected `ALL` and sectors `C-F`, while individual B3 sectors
`8-B` erased and verified with `A=$AC`. The map showed only B3 `8-B` erased.
Restoring B2 to B3 recovered the complete map, HIMON warm-booted, and ASM-F2
remained enterable. The interactive erase tool is hardware-proven except for
an optional forced worker-failure negative.

A later 2026-07-10 transcript on `HIMON V 00.0710(2024)` reassembled the same
sample cleanly, then proved the expected package negative: `SEAL` returned
`SEAL ERR=$02 FLAGS=$09`, and a fresh paste followed by `PACKAGE $3200`
returned `PKG ERR=$02`. This is not an assembly failure; `FLAGS=$09` means the
seal is valid but relocation metadata truncated. The tool is intentionally
run-in-place from `$3000` after leaving `SEAL>` with `.`.

A follow-up paste on `HIMON V 00.0710(1553)` included the new warning comments
and still assembled cleanly. `PACKAGE $3800` returned `PKG ERR=$02`, followed
by the same `SEAL ERR=$02 FLAGS=$09`, so the negative is not tied to `$3200`.

Current-source note, 2026-07-12: `flash-erase-bank-transient-2000.a` now emits at `$2000`
and runs with `G 2000`, reserving `$3000-$3FFF` as the normal AP load/run
island. The preceding `$3000` transcript is retained as historical proof of
the erase logic; repeat the short single-sector erase/verify proof at `$2000`
before treating the address-normalized sample as board-proven.

The address-normalized proof passed on 2026-07-15 under
`HIMON/ASM-F2 00.0715(1804)`. The current source assembled through `$23A5`,
ran with `G 2000`, erased and verified every Bank 0 sector from `$8000-$FFFF`,
printed `BANK 0 ERASE COMPLETE`, and returned `A=$AC` with carry set. This
full-bank run supersedes the requested short single-sector address proof.

## ASM-F2 Bank 0 AP Install Helper

`DOC/GUIDES/ASM/SAMPLES/bank0ap-stage-transient-2000.a` and
`DOC/GUIDES/ASM/SAMPLES/bank0ap-commit-transient-2000.a` are the planned
board-buildable bank 0 AP envelope installer. The stage piece consumes the RAM
AP envelope at `$4000`, asks for a bank 0 destination or Enter for
auto-selection, stages the selected sector at `$0A00-$19FF`, overlays the AP
envelope in the staged copy, and leaves `$1A06=$5A`. The commit piece requires
exact `YES`, programs/verifies the staged sector, and clears `$1A06` after
success.

The 2026-07-11 board transcripts proved the setup AP package path with
`banked-ap-smoke.a`: the first run packaged at `$3200`, and the 4K-island run
packaged at `$4000`; both returned `PKG OK @=$hhhh L=$006A`, and the AP header
dump began `41 50 01 6A 00 ...`. The first monolithic writer layout proved a
placement negative: it emitted through the live package buffer, exceeded the
global symbol budget, hit long `DB` source lines, and ended with
`ERR=$09 BAD FIX`. The split `bank0ap-stage-transient-2000.a` /
`bank0ap-commit-transient-2000.a` flow below keeps each source inside its 4K island and
under ASM-F2's symbol and source-line limits.

A follow-up stage paste reached `ASM OK`, but ASM-F2 rejected operand
expressions `PKG+1`, `PKG+3`, and `PKG+4` with `ERR=$03 BO`; those lines did
not emit, so `G 2000` returned the false package-header failure
`FAIL $1A00=$E1` even though `$4000` contained a valid AP envelope. The stage
source now uses named absolute constants `PKG1`, `PKG3`, and `PKG4` instead.
The commit source likewise avoids `INBUF+n` operands for the `YES` check.

ASM-F2 soon-update note: the `ERR=$07 BL` rows in that transcript are not just
a sample cleanup issue. DB-heavy prompt/string sources need a less fragile
source-line path, such as a longer paste buffer, explicit continuation, or the
first-class `DC` string directives added in the 2026-07-11 host slice. Board
samples must still keep individual source lines under the 63-visible-character
line cap.

Follow-up source direction: the bank 0 installer is split into stage and commit
pieces instead of growing a single interactive helper. Static checks show
`bank0ap-stage-transient-2000.a` and `bank0ap-commit-transient-2000.a` remain under the symbol
budget and under the 63-visible-character source-line cap. The current map uses
three 4K islands: helper/body emission `$2000-$2FFF`, AP overlay/load/run
`$3000-$3FFF`, and RAM AP envelope buffer `$4000-$4FFF`. `$5xxx` is not
scratch space for source-mode output; split again if any piece grows toward the
edge of its island.

Explicit-address board proof passed for bank 0 `$9000`: the patched commit
piece assembled with no `ERR=` rows, `G 2000` printed `PROGRAM OK`, and
`D 1A00 F` showed `AC 00 90 6A 00 90 00`. The first AP command used `#3000`
and correctly printed usage; the corrected `AP B0 $9000 $3000` loaded and ran
with `RET A=AC`. Runtime proof bytes were `$5848=$AC`, `$584A/$584B=$2E/$30`,
and `$5850=$5A`; the intervening bytes are not owned by this smoke body.

Printed AP board proof passed for bank 0 `$8000`: `bank0ap-print-smoke.a`
assembled at `$2000`, `PACKAGE $4000` returned `PKG OK @=$4000 L=$007F`, the
stage piece selected `$8000`, the commit piece printed `PROGRAM OK`, and
`AP B0 $8000 $3000` printed `B0 AP RUN` before returning `A=AC`. The stable
proof bytes are `$5848=$AC` and `$5850=$5A`; `$584A/$584B` records the
resolved resident `BIO_FTDI_PUT_CSTR` address.

A later follow-up ran the same committed bank 0 `$8000` package at AP RAM
destinations `$2000`, `$3200`, and `$3400`; each printed `B0 AP RUN` and
returned `A=AC`. Keep `$3000` as the default run destination. `$3200/$3400`
are useful overlay-island variants, while `$2000` should be a final
post-install proof only because it overwrites the helper/source island.

The same transcript also caught an operator-mode negative: after running
`PACKAGE $4000`, pasting `ASM NEW` and the stage source at the `SEAL>` prompt
produced repeated `ERR=$03 BO`. The correct transition is `SEAL> .`, then
`>ASM NEW`.
The follow-up `PACKAGE $2000` attempt is the same class of placement error:
`bank0ap-stage-transient-2000.a` reads the AP envelope only from `$4000` and emits over
`$2000`, so `G 2000` correctly reported `FAIL $1A00=$E1`.
After a later bank 0 erase, `AP B0 $8000 $3000` correctly returned
`APERR=$07` because the package had been erased.

Reporter auto-hole board proof passed: `asm-session-report-4800.a` packaged
at `$4000`, the stage helper selected the first available bank 0 hole at
`$807F` because `$8000-$807E` already held the print-smoke AP, the commit
helper programmed `$807F L=$0658`, and `AP B0 $807F $4800` printed
`ASM REPORT OK`. This proves `$4000` is only the temporary RAM envelope buffer,
bank 0 `$hhhh` is the persistent storage address, and `$4800` is the fixed
reporter runtime address.

### 2026-07-12 One-Run Bank 0 Installer Board Proof

`DOC/GUIDES/ASM/SAMPLES/bank0ap-put-transient-2000.a` is the intended standard operator
path. It combines the proven stage and commit logic into one `$2000` RAM
transient: validate the `$4000` AP envelope, select/stage a Bank 0 sector,
validate its staged copy, require exact `YES`, then program/verify. It clears
`$1A06` on success, abort, and failure, so no commit-ready state survives its
return.

The complete hand-held procedure remains in
`DOC/GUIDES/ASM/SAMPLES/bank0ap-put-2000-test.md`. Preserve the split-helper
evidence above; the one-run result is additional proof, not a replacement.

The first 2026-07-12 combined-source paste exposed a fixture-capacity negative.
At `PRINTDST`, `JSR HEX` at `$2355` attempted forward-fixup row 129 and returned
`ERR=$09 BAD FIX`; later forward branches/calls failed similarly. `END` still
printed `ASM OK` because rejected lines are transactionally rolled back, but
that incomplete image must not run.

The current source keeps message data and the small I/O/hex helpers before
`RUN`, reached through the fixed `$2000` entry jump. Their references are now
backward-resolved instead of consuming persistent fixup rows. A conservative
static scan counts at most 111 forward references, leaving at least 17 rows
under `ASM_FIX_MAX=$80`. Repeat the paste and require zero `ERR=` rows before
running `G 2000`.

The reordered retry passed on board with no `ERR=` rows and ended at `$2458`.
`G 2000` selected the first erased Bank 0 hole at `$8000`, staged the reporter
package `L=$0658`, accepted exact `YES`, printed `PROGRAM OK`, and returned
`A=$AC`. The status dump was exactly:

```text
1A00: AC 00 80 58 06 80 00
```

`AP B0 $8000 $4800` then loaded and ran the stored reporter, which printed
`STATUS=OK`, `PC/HIGH=$2458`, `BYTES=$0458`, `FIXUPS=$62/$80`,
`REFS=$B0/$C0`, `TRUNC=NO`, and `ASM REPORT OK`. The reported `$62` fixups
confirm the reordered source uses 98 rows and leaves 30 free.

The transient's detailed seal row reports `FL=09` and `REL=10`: its 16-row
relocation metadata filled and truncated. That does not affect its intended
fixed-address `G 2000` execution and is why this utility must not be packaged.
Remaining optional negatives are non-`YES` abort, occupied-address `$E5`, bad
package `$E1`, no-hole `$E3`, and forced worker failure.

### 2026-07-12 ASM-F2 Visible Version Board Proof

ASM-F2 now uses the same generated `MMdd(HHmm)` stamp invocation as HIMON.
Entering ASM should print this shape before the source prompt:

```text
>ASM
ASM-F2 00.xxxx(tttt)
ASM>$2000:
```

The ASM-F2 stamp identifies the loaded low-flash assembler image; it does not
replace the independent HIMON version shown at boot.

Host gate: the stamped build prints `ASM-F2 00.0712(1723)`, ends at `$BC29`,
and retains `$03D7` bytes below `$C000`. This is a `$000E`-byte increase over
the unstamped `$BC1B` image. The session reporter was regenerated from the new
map and remains a `$0610` AP package for fixed load/run at `$4800`.

Board proof passed on `HIMON V 00.0712(1728)`. `L F` loaded the stamped image
with `LF OK WR=3C29 GO=800C`; after a cold boot, `ASM` printed
`ASM-F2 00.0712(1728)` before `ASM>$2000:`. This proves the HIMON and ASM-F2
components carry independently visible matching stamps in the composite
build.

The same transcript assembled the regenerated reporter through `$4E31`,
returned `ASM OK`, and produced `PKG OK @=$4000 L=$0658`. Direct
`AP $4000 $4800` then returned `APERR=$06`. This is the existing one-sided RAM
overlap guard: package `$4000-$4657` and body `$4800-$4E30` are disjoint, but
the loader currently accepts RAM-package layouts only when the destination is
below the package. The `$4800` dump was the body already emitted by assembly,
not evidence that AP copied it.

Use `G 4800` to report the reporter's own just-finished session. Keep
`AP B0 $hhhh $4800` as the persistent-package proof after Bank 0 storage; the
banked path stages the source outside `$2000-$4FFF` and does not hit this RAM
source/destination policy.

The immediate retry proved the self-report workaround. `G 4800` printed
`STATUS=OK`, `START=$4800`, `PC/HIGH=$4E31`, `BYTES=$0631`,
`SYMS=$3C/$40`, `FIXUPS=$0E/$80`, `TRUNC=NO`, and `ASM REPORT OK`, then
returned through HIMON with entry `$4800`.

Remaining optional board proof: the print-smoke auto-address variant should
confirm the printed `$hhhh` with `AP B0 $hhhh $3000`. Remaining negatives are
bad AP header, non-erased destination bytes, no staged write, over-sector
package placement, and abort without write. The full prompt-by-prompt script
lives in `DOC/GUIDES/ASM/SAMPLES/bank0ap-put-2000-test.md`.

## 2026-07-11 ASM-F2 Forward/Imported Data and DC Host Gate

Host gate:

```text
make -C SRC asm-test
```

The host gate passes with forward-label data fixups, imported-data relocation
rows, and first-class string constants enabled. The flash link reports
`_END_DATA=$BC1B`, so the ASM-F2 image remains inside the approved
`$B969-$BFFF` low-flash hole and leaves `$03E5` bytes of headroom below
`$C000`.

New directive smoke coverage:

```text
DB FWD,<FWD,>FWD
DW FWD
FWD RTS
```

Assembled at `$7000`, this must patch to `06 70 06 70 06 70 60`, leave four
fixup rows, and record four internal relocation rows. This proves forward
`DB`, selected-byte `DB`, and forward `DW` reuse the existing fixup and
relocation machinery.

Imported-data smoke coverage:

```text
IMPORT EXT
DB EXT,<EXT,>EXT
DW EXT
END
```

Before `END`, this emits six placeholder bytes: `FF FF FF FF FF FF`. `END`
must convert the four data fixups into import relocation rows `$04,$05,$06,$04`
at sites `$00,$02,$03,$04`, all targeting import slot `$00`.

String directive smoke coverage:

```text
DC C,"OK"       -> 4F 4B 00
DC HB,"OK"      -> 4F CB
DC P,"OK"       -> 02 4F 4B
DC HB,""        -> BAD OPER
```

`C` is NUL-terminated/ASCIIZ. `HB` is the HIMON-style high-bit-final string.
`P` is length-prefixed. This slice does not add escapes, embedded quotes,
continuation strings, or a longer line buffer.

Board follow-up: the split `dc-forward-2000.a` AP package passed from RAM with
`RET A=AC`, `$5848=$AC`, `$5850=$5A`, and the loaded body head
`80 0F 10 30 10 30 10 30 4F 4B 00 4F CB 02 4F 4B 60`. This hardware-proves
`DC C/HB/P`, forward `DB`, forward selected-byte `DB`, forward `DW`, and
internal AP relocation rows.

Import/export follow-up: imported data constants are hardware-proven in the
split fixed-destination RAM fixture. The combined bank 0 package staged and
committed successfully at
`$86D7 L=$00F6`, but `AP B0 $86D7 $3000` returned `APERR=$09` (`BAD_FIX`)
before the AP body ran. The captured package table is well-formed:
`BODY=$1156 LEN=$0077`, `RELOCS=$0F`, `IMPORTS=$01`, `REL=$10EB`; the import
record decodes to `BIO_FTDI_PUT_CSTR` and hashes to `$AEFA0F42`, matching the
resident HIMON row. Treat the remaining failure as HIMON AP mixed-table
internal relocation behavior after STR8 import patching, not assembler package
shape, imported data emission, DC, forward data, or bank 0 flash-write failure.
`EXPORT`/`ENTRY` metadata is unchanged by this slice.

Pasteable combined board kit:

```text
DOC/GUIDES/ASM/SAMPLES/dc-forward-import-data-2000.a
DOC/GUIDES/ASM/SAMPLES/dc-forward-import-data-2000-test.md
DOC/GUIDES/ASM/SAMPLES/dc-forward-2000.a
```

The live top sector dump matched the current STR8-N jump table:
`F000: 4C 09 F0 4C 93 F3 4C 9A F3`. This rules out the older mixed
HIMON/STR8 image as the cause of the current `$09`.

The RAM `banked-rjoin-smoke.a` rerun passed, printed `BANK RJOIN`, returned
`A=AC`, and patched `BIO_FTDI_PUT_CSTR` to `$E779`, proving the current STR8
`$F006` import-link path still handles the known code-import case. The first
RAM `import-data-2000.a` run loaded with status `$00` and patched body bytes
`$3002-$3007` to `79 E7 79 E7 79 E7`, proving imported `DB name`,
`DB <name`, `DB >name`, and `DW name` data constants are linked through the
AP package path. Its runtime returned `A=E1` only because the checker used
unsupported `LABEL+1` expressions (`ERR=$03 BO` at `IMPW+1` and `IMPD+1`).

The follow-up `import-data-2000.a` version that used indexed high-byte reads
added two internal absolute relocation rows (`RELOCS=$0A`) and reproduced
`APERR=$09` even though `$3002-$3007` were already patched to
`79 E7 79 E7 79 E7`. The RAM combined fixture also reproduced `APERR=$09`
with `RELOCS=$0F`, and its body head showed both internal forward data and
imported data bytes patched. The combined tail/table capture showed rows 0-7
of the internal relocation table patched successfully, while row 8
(`CMP DCEXP,X` at body site `$005B`, target `$006F`) stayed `DD 6F 20` instead
of relocating to `DD 6F 30`. This rules out bank 0 source storage; the open
case is AP load's larger mixed relocation table path, after import patching and
before `GO`.

The fixed-destination `import-data-2000.a` fixture then passed with
`RET A=AC`, `$5848=$AC`, body bytes `$3002-$3007 = 79 E7 79 E7 79 E7`, and
service block `status=$00`, `RELOCS=$04`, `IMPORTS=$01`. This hardware-proves
imported `DB name`, `DB <name`, `DB >name`, and `DW name` data constants through
AP import relocation rows `$04/$05/$06`.

First host-side mitigation: `SRC/HIMON/himon.asm` reloaded `HIM_AP_REL_LO/HI`
into `CMDP_PTR_LO/HI` on each HIMON AP internal relocation-loop row, matching
STR8's import-link defensive pattern. `make -C SRC himon-str8-rom-bin` passed
with HIMON end `$EFEE`, still below STR8 at `$F000`.
After the updated HIMON image was installed and reported `HIMON V 00.0711(2100)`,
an immediate `G 3000` run returned `A=AC`, but it is not the AP-loader proof:
the source had been assembled at `$2000` and no `PACKAGE`/`AP` command was run.
Because the stale `$3000` body's failed row-8 operand still points at
source-side `DCEXP` near `$206F`, this direct run can false-pass. The board
proof must use `PACKAGE $3200`, `.`, then `AP $3200 $3000`.
The required AP retest on the same updated image still returned `APERR=$09`.
The import rows patched to the new resident address `$E783`, proving the new
image is active and STR8 import linking still works, but row 8 remained
`DD 6F 20` instead of `DD 6F 30`. The first HIMON mitigation is therefore not
sufficient; the remaining failure is still the mixed-table internal relocation
path at row 8.

The follow-up scratch dump identified the root cause:
`HIM_AP_TMP2_LO=$1E` (`RELOC_COUNT*2`) and `HIM_AP_TMP_LO=$79`
(`site $5B + $1E`). `HIM_AP_RELOC_SITE_OK_X` stored the 0/1 abs16 width addend
in `HIM_AP_TMP2_LO`, but the row-access helpers reuse that byte for table
offset math. Row 7 survived by accident because `$58+$1E=$76` was still less
than body length `$77`; row 8 failed because `$5B+$1E=$79`.

Root-cause host fix: `HIM_AP_RELOC_SITE_OK_X` now keeps the 0/1 addend on the
stack with `PHA`/`PLA` while calling `HIM_AP_RELOC_SITE_LO_X` and
`HIM_AP_RELOC_SITE_HI_X`. The earlier pointer-reload mitigation was removed to
keep the ROM smaller. `make -C SRC himon-str8-rom-bin` passes with
`HIMON V 00.0711(2113)` and HIMON end `$EFE0`, still below STR8 at `$F000`.
The fixed image was then installed as `HIMON V 00.0711(2117)`, ASM-F2 was
reloaded with `L F` (`WR=3C1B GO=800C`), and the combined fixture passed through
`PACKAGE $3200` and `AP $3200 $3000`: `RET A=AC`, `$5848=$AC`,
`$584A/$584B=$E775`, `$584C/$584D=$3016`, `$5850=$5A`, AP service
`status=$00`, and row 8 correctly relocated to `DD 6F 30`.

This closes the combined board proof for `DC C/HB/P`, forward `DB`, forward
selected-byte `DB`, forward `DW`, imported `DB/DW` data constants, STR8 import
patching, and HIMON mixed internal/import relocation-table loading.

## 2026-07-12 Compact AP RAM Layout Slice

Large-program and multi-sector image support are explicitly deferred. This
slice only changes the one-sector AP workflow and flash ASM workspace layout.

Implemented host facts:

```text
symbol-name pool       $0200-$09FF  ($0800)
fixup-name pool        $0A00-$19FF  ($1000)
flash ASM UDATA        $5000-$61A9  (_END_UDATA=$61AA)
upper ASM arena        $61AA-$7DFF
Bank 0 PACKAGE base    $3000
AP envelope maximum    $1000 bytes, including all metadata
```

`PACKAGE` now rejects an actual envelope length above `$1000`. The full-core
smoke checks both `$1000` accepted and `$1001` rejected as `BAD RANGE`.
`bank0ap-put-transient-2000.a` derives all package offsets from `PKG_BASE=$3000`.
HIMON keeps its proven `$2000-$4FFF` AP destination range but now accepts a
RAM package either below or above the BODY when the complete ranges do not
overlap. HIMON links through `$EFF8`, leaving eight bytes below STR8.

The low tables are phase-owned. `PACKAGE` serializes AP metadata first; the
next STR8 worker invocation reloads code at `$0200` and reuses
`$0A00-$19FF` for sector staging. A Bank 0 reporter must therefore be loaded
to `$4800` before the ASM session it will inspect, then run afterward with
`G 4800`. Loading it with banked `AP` after the target session would destroy
the names before the report begins.

Host gates completed:

```text
make -C SRC asm-test
make -C SRC asm-v1-flash
make -C SRC himon
make -C SRC asm-session-report
```

Focused board proof, partial:

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/asm-session-report-4800.a
ASM OK
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$hhhh
SEAL> .
ASM BYE
>G 4800
expect MAP END=$BC5F UDATA=$5000-$61AA
expect LOW=$0200-$1A00 UPPER=$61AA-$7E00
expect ASM REPORT OK

>AP $3000 $4800
expect no APERR and ASM REPORT OK

>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/bank0ap-put-transient-2000.a
ASM OK
SEAL> .
ASM BYE
>G 2000
press Enter for AUTO, then type YES
>D 1A00 1A06
expect AC ll hh lenlo lenhi sector 00

>AP B0 $hhhh $4800
expect ASM REPORT OK; this preload intentionally retires the old ASM names
>ASM NEW
paste a focused target fixture
ASM OK
SEAL> .
ASM BYE
>G 4800
expect the focused target session and ASM REPORT OK
```

The first board pass on `HIMON/ASM-F2 00.0712(2010)` completed the first two
blocks: the reporter produced `PACKAGE $3000 L=$069E`, direct
`AP $3000 $4800` ran, and the report printed the expected `$BC5F`, `$61AA`,
and `$0200-$1A00` map. The install block must be repeated because that paste
changed the transient to `ORG $3000`, overwriting its own package input. Use
the repository source unchanged at `ORG $2000` and run it with `G 2000`.

The corrected retry passed. AUTO installed the reporter at `$8658 L=$069E`
immediately after the existing `$8000 L=$0658` package, then installed
`bank0ap-print-smoke` at `$8CF6 L=$007F`. The three envelopes are contiguous
through `$8D74` in the same `$8000-$8FFF` sector. This closes `$3000` package
generation, upward RAM load, combined install, AUTO append, and same-sector
packing. Still pending: run `AP B0 $8CF6 $3000`, preload the reporter from
`B0:$8658` before a target session and use `G 4800` after it, and prove the
exact `$1000/$1001` package boundary.

The stored print-smoke execution follow-up passed three times with
`AP B0 $8CF6 $3000`, `B0 AP RUN`, and `RET A=AC`. The reporter was then loaded
from `B0:$8658` to `$4800`; its immediate report showed the expected destroyed
low-table names after bank staging and left the reporter resident. Remaining:
assemble a fresh target and use `G 4800` with no intervening banked operation,
then run the `$1000/$1001` boundary fixture.

The maintained closure procedure is
`DOC/GUIDES/ASM/SAMPLES/asm-session-carry-boundary-test.md`. It rebuilds and
installs a map-matched reporter, proves failed and clean reporter carry returns,
then packages `ap-envelope-1000-fixture-2000.a` and rejects
`ap-envelope-1001-fixture-2000.a`. The package-only fixtures use empty metadata:
`$0020` envelope overhead plus BODY lengths `$0FE0/$0FE1` yields exact totals
`$1000/$1001` without a placement-overlap confounder.

The 2026-07-15 pass on `HIMON/ASM-F2 00.0715(1804)` rebuilt the current
reporter through `$4E7F`, produced `PACKAGE $3000 L=$06A6`, installed it at
`B0:$8100`, and loaded it at its fixed `$4800` origin. The install returned
`A=$AC/C=1`; the immediate report printed the current `$BC6D` flash end and
`$5000-$61AA` UDATA map, ended with `ASM REPORT OK`, and returned `A=$00/C=1`.
This proves the current package/install/load image, but the immediate report
still describes the installer session after bank staging. A fresh target
session followed by `G 4800` remains the lifecycle proof.

The same pass completed the direct carry-display test: `G 2000` returned
`A=$AC/C=1`, and `G 2004` returned `A=$E1/C=0`. The attempted failed-session
probe used bare `NOPE`; ASM-F2 accepted it as a pending label and exited
cleanly. The maintained card now uses `FOO BAR` to force the intended bad
mnemonic. Failed and clean reporter sessions and both envelope boundaries
remain pending.

The next `00.0715(1804)` pass closed the reporter lifecycle. Both
`NOPE #$01` and `FOO BAR` produced `ERR=$01 BM`, and the latter left sticky
`EXEC ERR=$01`. Direct `G 4800` reported `STATUS=$01`, `ERRLINE=$0001`, no
emitted bytes, and returned `A=$01/C=0`. A following three-byte
`LDA #$AC`/`RTS` session reported `STATUS=OK`, `PC/HIGH=$2003`, and returned
`A=$00/C=1` from the same preloaded reporter.

The first boundary attempt did not exercise `PACKAGE` length rejection.
Single `DS $0FE0,$A5` and `DS $0FE1,$A5` lines both produced
`ERR=$06 BAD RANGE` because ASM-F2 intentionally limits each `DS` count to
`$FF`. `END` therefore sealed an empty body and `PACKAGE $3000` correctly
produced `L=$0020`. The corrected fixtures use fifteen initialized `$FF`
chunks plus `$EF/$F0`, preserving BODY lengths `$0FE0/$0FE1`.

The corrected boundary proof then passed on the same `00.0715(1804)` image.
The `$0FE0` BODY ended at `$2FE0`; `PACKAGE $3000` returned `L=$1000`, its
header was `41 50 01 00 10`, and `$3FF8-$3FFF` contained eight `$A5` BODY
bytes. The `$0FE1` BODY ended at `$2FE1`; `PACKAGE $3000` returned
`PKG ERR=$06` and HIMON reported `EXEC ERR=$06`. Status `$06` is the intended
`BAD RANGE` result from `ASM_PACKAGE_LENGTH_OK`, not seal-policy status `$02`.

This compact AP RAM-layout slice is fully board-proven: `$3000` package
generation and Bank 0 install, upward RAM load, same-sector AUTO append and
execution, reporter preload lifecycle and carry returns, exact `$1000`
acceptance, and `$1001` `BAD RANGE` rejection.

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

## Carry Return ABI Proof

The maintained runnable ASM sources use `C=1` for success and `C=0` for
failure or abort, with A carrying the documented status. HIMON's `G`/`AP`
wrapper saves P with `PHP` immediately after the target returns.

After loading the current ASM-F2 image, paste
`DOC/GUIDES/ASM/SAMPLES/return-carry-proof-transient-2000.a`, end the session, and run:

```text
>G 2000
#GO# ENTRY=2000
RET A=AC ... C
>G 2004
#GO# ENTRY=2004
RET A=E1 ... c
```

Hardware pass, 2026-07-15: on `HIMON/ASM-F2 00.0715(1804)`, `G 2000`
reported `RET A=AC ... P=F5 ... C`, and `G 2004` reported
`RET A=E1 ... P=F4 ... c`. This closes the direct HIMON `G` carry-display ABI
proof for the current image.

Then prove ASM-F2's sticky session failure:

```text
>ASM NEW
ASM>$2000: FOO BAR
ERR=$01 BM PC=$2000
ASM>$2000: .
ASM BYE
#56AD7400# EXEC ERR=$01
```

Do not replace this with bare `NOPE`. The 2026-07-15 board attempt showed that
an unknown word on its own is accepted as a pending label, so it does not set
sticky failure status. `FOO BAR` is the documented unknown-label plus
unknown-operation `BAD MNEM` case.

Hardware pass on `HIMON/ASM-F2 00.0715(1804)`: both `NOPE #$01` and
`FOO BAR` printed `ERR=$01 BM PC=$2000` and exited with
`#56AD7400# EXEC ERR=$01`. The preloaded reporter then returned the sticky
status as `A=$01/C=0`. A following clean session returned `A=$00/C=1`.

A following clean `ASM NEW`, `.` must return directly to the HIMON prompt
without `EXEC ERR`. A successful in-session `NEW` also clears an earlier
failure.

The ordered board sequence, including reporter reinstall and the exact AP
envelope boundary fixtures, is in
`DOC/GUIDES/ASM/SAMPLES/asm-session-carry-boundary-test.md`.

For the reporter, preload the Bank 0 AP at `$4800` before the target session.
After a failed target session, `G 4800` must finish with `RET A=hh ... c`, where
`hh` is the reported `ASM_LAST_STATUS`; after a clean target session it must
finish with `RET A=00 ... C`.

### Reporter Build-Coupling Negative Proof

Hardware on `HIMON/ASM-F2 00.0712(2115)` rejected the reporter AP previously
built under `00.0712(2010)`. The old source recorded flash end `$BC5F` and
called ASM helpers at `$8584/$858A/$8590/$8593/$859B`; the new image ended at
`$BC6D` and moved those helpers to `$8592/$8598/$859E/$85A1/$85A9`.

`AP B0 $8000 $3000` trapped at `BRK 00 PC=485F`, correctly proving that the
reporter cannot be relocated away from its fixed `$4800` origin. Loading the
same stale package with `AP B0 $8000 $4800` reached `ASM REPORT` but produced
concatenated/corrupt output because its helper calls were fourteen bytes
stale. That banked load also occurred after the target session and therefore
reused the low name tables.

This is a negative lifecycle/version proof, not a reporter or carry-ABI pass.
Rebuild and install `asm-session-report-4800.a` from the current map, preload
the new Bank 0 package at `$4800`, assemble the target, and then use `G 4800`
without another `AP` operation.

That rebuild/install prerequisite passed on 2026-07-15: the map-matched
`00.0715(1804)` reporter package is `L=$06A6`, was installed at `B0:$8100`,
and was loaded successfully at `$4800`. The fresh failed and clean target
sessions followed by direct `G 4800` both passed later that day.

## 2026-07-18 Resident AP Linker Ownership And Size Pass

Status: host-build pass; fixed-surface board pass; AP-import regression pending.

The resident-size pass removes quoted hashing and the HIMON `D` continuation,
short-end, and embedded search forms. STR8-N removes its physical `M` map and
moves AP import linking into HIMON. `$F006` remains the stable compatibility
entry; its body selects AP operation `$03` and jumps through the existing HIMON
AP vector at `$7E2D-$7E2E`.

Host map result:

```text
HIMON CODE/DATA/END       = $2997/$0596/$EF2D
HIM_AP_SERVICE            = $D5BF
HIM_AP_IMPORT_LINK        = $DAEF
HIMON gap before STR8     = $00D3
STR8 CODE/DATA/END        = $06C2/$01EB/$F8AD
STR8 $F006 adapter body   = $F383
STR8 worker store/size    = $FD26-$FFEF/$02CA
STR8 free contiguous hole = $F8AD-$FD25/$0479
vectors                   = 92 F0 00 F0 A6 F0
```

`make -C SRC all` passes. The composite-ROM builder now asserts `$F003` and
`$F006`, verifies the `$F006` absolute jump, verifies the exact adapter bytes
`A9 03 8D 2F 7E 6C 2D 7E`, and requires `HIM_AP_IMPORT_LINK` to reside inside
HIMON. `make -C SRC asm-test` also passes after correcting its stale Makefile
path to the preserved `SAMPLES/OLD CODE/ASMTEST_3000.asm` fixture; the fixture
itself and its hardware transcript were not moved or rewritten.

Required board regression before hardware proof:

```text
D F000 F008
  expect three stable JMP entries at F000/F003/F006
D F383 F38A
  expect A9 03 8D 2F 7E 6C 2D 7E
D 3000
  expect one-byte dump
D
  expect D usage
enter STR8 and run ?
  expect no M command in the prompt surface
run the known RAM AP RJOIN import package
  expect BANK RJOIN, A=$AC, and AP status $00
run the missing-import package
  expect BAD FIX/AP status $09 and no partial import patch
run the known banked AP RJOIN package through AP Bn
  expect the same resolved entry and return result as before the move
```

Do not rewrite earlier STR8 `M` or AP-link hardware transcripts. They remain
the proof for the old image; append the new regression evidence when captured.

The 2026-07-18 board transcript closes the onboard installation and fixed-
surface portion. Old STR8 successfully updated HIMON to `00.0718(2041)`;
`L F` then installed ASM-F2 `00.0718(2045)` as `LF OK WR=3C6D GO=800C`.
The map-generated top writer assembled, staged, programmed, and verified the
new bank 3 `$F000-$FFFF` sector:

```text
$1A00-$1A03 = 01 AC 00 00
$F000-$F008 = 4C 09 F0 4C 7C F3 4C 83 F3
$F383-$F38A = A9 03 8D 2F 7E 6C 2D 7E
$F6C2-$F6C5 = 7A 0F 6A 5F
$FD26-$FD35 = 08 78 AD F0 1F C9 02 F0 0D C9 05 F0 0E C9 06 F0
$FFFA-$FFFF = 92 F0 00 F0 A6 F0
```

The new STR8 screen showed `? B E U 0 1 2 G R`, `B0 HOLD`, and returned to
the current HIMON. This passes the fixed entries, adapter bytes, identity,
worker position, vectors, retired-`M` command surface, and combined-image boot.

A follow-up transcript closes the simplified resident `D` contract:

```text
D                     -> D [a [b]]
D 1A00                -> one byte at $1A00
D 1A03 04             -> D [a [b]]
D 1A00 1A01           -> exactly two bytes
D 0 FF                -> inclusive $0000-$00FF dump
D 0 FFFF              -> inclusive full-address-space dump through $FFFF
D FFFA FFFF           -> 92 F0 00 F0 A6 F0
```

`D 1A03 04` proves the second token is now an absolute address rather than a
short-end completion: `$0004` is not greater than `$1A03`, so usage is the
correct result. The full `$0000-$FFFF` dump reached the vector tail and
returned to the prompt, proving the range loop handles the complete inclusive
16-bit address space without falling into continuation semantics.

The same transcript does not yet prove the moved import linker. The imported
`banked-rjoin-smoke.a` body was entered with direct `G 2000`, before
`PACKAGE`/`LOAD`; its unresolved import correctly ran into the placeholder and
trapped at `BRK F0 PC=FFFE`. The no-import body then passed direct execution,
which proves ordinary assembly/execution but not AP import binding. A later
`G 7000` cold-booted the machine and printed `RAM ZERO OK`, so the subsequent
`G 7200` trap was also expected: the just-assembled `$7200` program had been
cleared.

Resume the RAM import proof without a cold boot:

```text
ASM NEW
  paste banked-rjoin-smoke.a
PACKAGE $3200
LOAD $3200 $3000
.
G 3000
D 5848 5850
D 7E2D 7E40
```

Expect `BANK RJOIN`, carry set with `A=$AC`, `$5848=$AC`, resolved resident
address `$584A/$584B=$05/$E7`, and AP status `$00`. Only after this passes run
the missing-import/no-partial-patch and banked-source variants.

The follow-up 2026-07-18 board transcript closes this positive RAM import
gate on HIMON `00.0718(2041)` and ASM-F2 `00.0718(2045)`:

```text
PKG OK @=$3200 L=$0076
LOAD OK=$3000 L=$0029 C=$05
...
>G 3000
BANK RJOIN
RET A=AC X=1A Y=0E P=F5 S=FD NV-BdIzC
>D 5848 5850
5848: AC 00 05 E7 00 00 00 00 | 00
>D 1A10 1A17
1A10: 06 0F 30 05 E7 04 05 01
>D 7E2D 7E40
7E2D: BF D5 01 00 00 32 00 30 | 76 00 4D 32 29 00 05 01
7E3D: 00 00 14 32
```

Result: pass. The resident AP request records operation `$01` (`LOAD`), status
`$00`, source `$3200`, destination `$3000`, package length `$0076`, body
`$324D`, body length `$0029`, five relocation rows, and one import. The linker
debug row records final patch kind `$06` (HI8 import), patch site `$300F`,
resolved address `$E705`, relocation index `$04`, relocation count `$05`, and
import count `$01`. The printed string, `A=$AC/C=1`, and `$584A/$584B=$05/$E7`
prove that the copy at `$3000` called the current resident string routine.
This closes the positive regression for moving the AP linker from STR8 into
HIMON. The missing-import/no-partial-patch and banked-source variants remain
separate open gates.

The same capture also exercised two AP range negatives after packaging the
no-import smoke at `$3200`:

```text
>AP B0 $3200 $9000
APERR=$06
>AP $3200 $8000
APERR=$06
```

Both are correct `BAD RANGE` results. `AP B0` requires a bank-visible package
address at `$8000` or above, so `$3200` is not a banked source; AP execution
destinations are limited to RAM `$2000-$4FFF`, so `$9000` and `$8000` are not
valid destinations. The direct-RAM positive retry is `AP $3200 $3000`.

That retry subsequently passed:

```text
>AP $3200 $3000
GO 3000
#GO# ENTRY=3000
RET A=AC X=30 Y=30 P=F5 S=FD NV-BdIzC
>D 5848 5850
5848: AC 00 30 30 00 00 00 00 | 5A
```

Result: the no-import package loaded and applied its internal relocations at
`$3000`, called relocated `TARGET=$3030`, set `$5850=$5A`, and returned with
`A=$AC/C=1`. Together with the two `$06` cases, this passes the current
direct-RAM AP positive/range-negative group.
