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
seal fact record: valid flag set, base `$7000`, exclusive end `$7014`, and
length `$0014`. This proves source name -> FNV hash -> resident EXEC join ->
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
asm-directives-smoke-3000.a
                         hardware-proven EQU/DB/DW/DS and small fixup smoke
pack40-roundtrip-2000.a self-contained PACK40 pack/unpack oracle
pack40-interactive-2000.a
                         hardware-proven interactive PACK40 pack/unpack
                         exerciser
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
resident-lookup eligible. Current ASM uses `ASM_FIX_MAX=$60` and allows direct
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
for the current ASM v1 ceiling. It starts at `$6800`, uses RJOIN for
`BIO_FTDI_WRITE_BYTE_BLOCK` and `PIN_FTDI_READ_BYTE_NONBLOCK`, keeps its
visible board at `$7800`, its next board at `$7840`, neighbor tables at
`$7000-$71FF`, seed/character tables at `$7200/$7240`, and a random density
map at `$7242`. Controls are `N` or space for next, `R` for random, and `Q` to
return. The random seed in `$D4` stirs while waiting for a key, then an 8-bit
LFSR fills the board on `R`.

The source stayed inside the paste constraints used by that proof after the
table-open slice:
24 session symbols, 13 forward fixup rows, about 24 local report references,
no operand-tail arithmetic, no local labels, no DB/DS expression math, and max
source line length 55. Static layout check places the interactive code below
the table block (`DONE` at `$6978`, tables still start at `$7000`, max emitted
address `$7246`). The earlier hardware transcripts
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
ASM_SYM_MAX=$28
ASM_FIX_MAX=$60
ASM_REF_MAX=$A0
ASM_LOCAL_MAX=$10
ASM_LOCAL_NAME_MAX=$10
```

The 2026-06-15 hardware run in `DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md` proves
`pack40-interactive-2000.a` with those limits. It accepted 30 globals and 74
resolved fixup rows through `END`, then verified `P HELLO -> D432584D`,
`U D432584D -> HELLO`, `_`, `HELLO_`, and `HELLO_GOODBYE` round trips. The
negative paths rejected bare menu text, empty pack/hex input, and invalid `:`.

The first `asm-directives-smoke-3000.a` board paste exposed that
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

Current seed-only ASM supersedes the ASM 2.57 fallback policy for the `$8000`
ASM/no-header direction. `ASM_RJOIN_INIT` now requires `$7E00/$7E01` to hold a
ROM-space `HASH ACQUIRE` seed and no longer carries the local scanner bootstrap.
HIMON publishes the current `THE_JOIN_EXEC_XY` addr16 there during common init,
so the seed follows the resident joiner if HIMON moves it.

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
current flash ASM image uses `ASM_REF_MAX=$A0`.

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
$D6 DW emit failed
$D7 emitted DW bytes were wrong
$D8 DW PC/high-water was wrong
$D9 empty DW did not fail BAD OPER
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
for reserved/parked words:

| Slot | Slot | Slot | Slot |
| --- | --- | --- | --- |
| $00 A REG | $15 CMP MNEM | $2A LDX MNEM | $3F SED MNEM |
| $01 ADC MNEM | $16 CPX MNEM | $2B LDY MNEM | $40 SEI MNEM |
| $02 AND MNEM | $17 CPY MNEM | $2C LSR MNEM | $41 SMB MNEM |
| $03 ASL MNEM | $18 DB DIR | $2D NOP MNEM | $42 STA MNEM |
| $04 BBR MNEM | $19 DC RES | $2E ORA MNEM | $43 START RES |
| $05 BBS MNEM | $1A DEC MNEM | $2F ORG DIR | $44 STP MNEM |
| $06 BCC MNEM | $1B DEX MNEM | $30 PHA MNEM | $45 STX MNEM |
| $07 BCS MNEM | $1C DEY MNEM | $31 PHP MNEM | $46 STY MNEM |
| $08 BEQ MNEM | $1D DS DIR | $32 PHX MNEM | $47 STZ MNEM |
| $09 BIT MNEM | $1E DW DIR | $33 PHY MNEM | $48 TAX MNEM |
| $0A BMI MNEM | $1F END DIR | $34 PLA MNEM | $49 TAY MNEM |
| $0B BNE MNEM | $20 ENTRY RES | $35 PLP MNEM | $4A TRB MNEM |
| $0C BPL MNEM | $21 EOR MNEM | $36 PLX MNEM | $4B TSB MNEM |
| $0D BRA MNEM | $22 EQU DIR | $37 PLY MNEM | $4C TSX MNEM |
| $0E BRK MNEM | $23 EXTRN RES | $38 RMB MNEM | $4D TXA MNEM |
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
DOC/GUIDES/ASM/SAMPLES/expr-math-7010.a
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

Current DB/DW/ORG/DS acceptance:

```text
DB emits byte/word by source/symbol width
unknown bare DB ADDR is BAD WIDTH
empty DB is BAD OPER
DB emits FF 0A 41 34 12 34 12 for the current fixture
DW emits each expression as a little-endian word
DW emits 34 12 12 00 0B 00 41 00 for the current fixture
empty DW is BAD OPER
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
ASM 2.48 captures clean-END seal span facts in RAM:
         base, exclusive end, and length = end - base.
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
clean END leaves a valid RAM fact record matching START/HIGH/BYTES
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
