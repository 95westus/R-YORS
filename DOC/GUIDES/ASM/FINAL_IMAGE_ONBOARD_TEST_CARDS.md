# ASM-F2 Final-Image Onboard Test Cards

The board-accepted `00.0814(1524)` compact-string image has its own focused,
paste-ready card: [`COMPACT_DC_BOARD_TEST_CARD.md`](COMPACT_DC_BOARD_TEST_CARD.md).
The material below remains exact evidence for the earlier final-image phases.

These three RAM-only cards close the negative-expression, compact opcode-table,
and post-`END` workflow gaps. Installed image `00.0814(0654)` failed Card A and
must not be used for acceptance. The corrected `00.0814(0805)` replacement is
accepted by Cards A-C. The cards do not write flash. The one-argument
`INSTALL 3200` command in Card 3 only suggests an erased visible-flash
address.

Current candidate `00.0814(0945)` must repeat Cards A-C. Its result is not
implied by the accepted `0805` transcript.

Use the regenerated map-matched reporter at `$7000`. It occupies
`$7000-$771A`; these cards use `$7903-$7905`. Prompt characters shown in prose
are context, not text to paste:

```text
ASM>   source lines or . only
SEAL>  SEAL, RELOCATE, PACKAGE, LOAD, INSTALL, NEW, or .
>      HIMON commands such as ASM, L, D, M, AP, or G
```

Stop at the first unexpected status and retain the entire transcript.

Hardware status: Cards A-C accepted on HIMON/ASM-F2 `00.0814(0805)`.

## Card A: Expression Rejection And Transaction Rollback

Board status: accepted on `00.0814(0805)`.

At bare HIMON `>`, enter `ASM NEW`. At `ASM>`, send
[`expr-negative-rollback-2000.a`](SAMPLES/expr-negative-rollback-2000.a).

Require the following six failures. Every line must retain `PC=$2001`:

```text
LDA #1<<16       ERR=$06 BAD RANGE
LDA #1<2         ERR=$03 BAD OPER
LDA #2/1         ERR=$03 BAD OPER
LDA #2*3         ERR=$03 BAD OPER
LDA #$F0&$1234   ERR=$05 BAD WIDTH
LDA MISSING+1    ERR=$03 BAD OPER
```

`*` remains legal only as the complete current-PC atom; it is not an infix
multiply operator. The unresolved compound case is deliberately rejected
until addend fixups are implemented.

After the accepted `END` changes the prompt to `SEAL>`, enter only `.`. Wait
for `ASM BYE` and bare HIMON `>`, then enter:

```text
D 2000 2001
G 7000
```

HIMON may print `#56AD7400# EXEC ERR=$03` after `ASM BYE`; this is the wrapper's
retained last rejected-line result from `MISSING+1`, not a failed `END` or
reporter status.

Require bytes `$A5 $5A`, `PC/HIGH=$2002`, `BYTES=$0002`, `SYMS=$02/$80`,
`FIXUPS=$00/$80`, `REFS=$00/$C0`, and `ASM REPORT OK`. Only `BASE` and `TAIL`
may appear in the symbol table; `MISSING` must not survive the rejected line.
This proves byte, PC, symbol, reference, and fixup rollback.

## Card B: Compact ALU And Shift/Rotate Tables

Board status: accepted on `00.0814(0805)`.

At bare HIMON `>`, enter `ASM NEW`. At `ASM>`, send
[`opcode-reduction-runtime-2000.a`](SAMPLES/opcode-reduction-runtime-2000.a).
The first source instruction must report:

```text
ERR=$04 BAD MODE PC=$2000
```

The following `START JMP RUN` must therefore assemble at `$2000`. After
`END`, at `SEAL>` enter:

```text
PACKAGE START 3200
.
```

Wait for bare HIMON `>`, then enter:

```text
G 2000
D 7904
AP 3200 3000
D 7904
G 7000
```

Both executions must return A=`$AC` with carry set; both dumps must show
`$7904=$AC`. A return/write of `$EE`, carry clear, `BRK`, or `APERR` fails the
card. The reporter must end with `ASM REPORT OK`.

The card distributes all nine compact ALU modes across
`ADC/SBC/AND/ORA/EOR/CMP/LDA/STA`, and all six shared mode rows across
`ASL/LSR/ROL/ROR`. It also proves that the virtual immediate base does not
accidentally make `STA #immediate` legal.

## Card C: Final Post-`END` Workflow

Board status: accepted on `00.0814(0805)`.

At bare HIMON `>`, seed the package destination:

```text
M 3200
```

Enter replacement byte `$5A`. Then enter `ASM NEW`; at `ASM>`, send
[`seal-workflow-2000.a`](SAMPLES/seal-workflow-2000.a). At `SEAL>`, enter:

```text
SEAL
RELOCATE 3000
PACKAGE WRONG 3200
.
```

Require `SEAL OK`, `RELOC OK @=$3000`, and `PKG ERR=$08`. After `ASM BYE` and
bare HIMON `>`, enter:

```text
G 3000
D 7905
D 3200
ASM SEAL
```

The relocated body must return A=`$C3` with carry set and `$7905=$C3`.
`$3200` must still contain `$5A`, proving that wrong identity was rejected
before any package write. `ASM SEAL` must reopen the preserved `SEAL>` session.

At that `SEAL>` prompt enter:

```text
PACKAGE START 3200
INSTALL 3200
LOAD 3200 3000
.
```

Require `PKG OK`, `INST OK`, and `LOAD OK @=$3000`. The one-argument
`INSTALL` result is advisory and must not produce sector progress dots or a
write confirmation. After `ASM BYE` and bare HIMON `>`, enter:

```text
G 3000
D 7905
ASM SEAL
```

Require A=`$C3`, carry set, `$7905=$C3`, and a resumed `SEAL>` prompt. Enter
the final `.` and wait for `ASM BYE` plus bare HIMON `>`.

## Acceptance

Cards A-C are independent. Record the STR8-N, HIMON, and ASM-F2 banners once,
then append the exact terminal transcript to
[`../LOGS/HARDWARE_TEST_LOG.md`](../LOGS/HARDWARE_TEST_LOG.md). Do not record
acceptance for a command entered at the wrong prompt.
