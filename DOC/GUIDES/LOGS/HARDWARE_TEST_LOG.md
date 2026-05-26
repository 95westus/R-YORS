# R-YORS Hardware Test Log

This file records bench transcripts that prove behavior on real hardware. Keep
entries short enough to scan, but include enough serial output to reconstruct
what was actually tested.

## 2026-05-26 ASM 2.51 Resident FNV Bootstrap NMI On HIMON

### Summary

Result: not green. STR8 successfully updated HIMON to `HIMON V 00.0525(2150)`,
and ASM loaded as `L OK=4715 GO=2000`, but `GO 2000` entered the local RJOIN
bootstrap scanner and was interrupted at `PC=$264E`.

Map interpretation: `$264E` is inside `ASM_RJ_FIND_ADV`, before the smoke
ladder starts. The follow-up 2.52 slice caches RJOIN/FNV resolution and starts
the local bootstrap scan at `$C000` to avoid repeated long ROM scans. The 2.53
follow-up adds live smoke progress lines, beginning with `00 RJOIN` once the
resident writer is known, so a paused board exposes the last checkpoint reached.

### Transcript Extract

```text
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

STR8 V0 #5F6A0F7A
ROM $F000
? B E M U 0 1 2 G R
B0 HOLD
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
...
PROGRAM C000-EFFF? Y: y...
OK
STR8>
G HIMON
BOOT WARM

HIMON V 00.0525(2150)
>L G
L S19
L @2000
L OK=4715 GO=2000

NMI PC=264E
A=3C X=57 Y=00 P=A4 S=EF Nv-bdIzc
>
```

## 2026-05-26 ASM 2.50 Relocated Smoke Target Proof On HIMON

### Summary

`asm-v1-core-2000.s19` passed the onboard ASM 2.50 smoke ladder on hardware.
This proves the paired 2.48/2.49/2.50 slice for the deterministic smoke path:
the resident proof image loads as `L OK=4761 GO=2000`, the standalone assembly
target moved from `$6800` to `$7000`, data targets moved to `$7100/$7110`, and
the report/status smoke still reaches `ASM 2.50 TESTS OK`. The separate
`ASM_REPL=$2123` entry remains to be hardware-proven interactively.

### Transcript Extract

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

## 2026-05-26 ASM 2.47 Def-Line And Unused Report Proof On HIMON

### Summary

`asm-v1-core-2000.s19` passed the onboard ASM 2.47 smoke ladder on hardware.
This proves the paired 2.46/2.47 report slice: session symbols now store
definition lines, the `USED` row includes `DEF=$0002`, and the first compact
`UNUSED` section prints `SEED DEF=$0003` and `BUF DEF=$0004`. This transcript
ran the already-loaded image with `GO 2000`.

### Transcript Extract

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

## 2026-05-26 ASM 2.45 Used-Symbol Report Proof On HIMON

### Summary

`asm-v1-core-2000.s19` passed the onboard ASM 2.45 smoke ladder on hardware.
This proves the paired 2.44/2.45 report slice: mark-use symbol lookups now
consume the report reference budget, the clean report shows `REFS=$02/$10`, and
the first compact `USED` row prints `ADDR REFS=$02 FIRST=$0003`. The later
overflow proof still reaches `REFS=$10/$10`, fails with `BAD_FIX`, and prints
`TRUNC=YES`.

### Transcript Extract

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

## 2026-05-26 ASM 2.43 Report Overflow Proof On HIMON

### Summary

`asm-v1-core-2000.s19` passed the onboard ASM 2.43 smoke ladder on hardware.
This proves the report reference-counter overflow trigger: after the clean and
first-failure report proofs, the `$5E REPORT` slice fills `REFS` to `$10/$10`,
then the next report reference fails with `BAD_FIX`, sets `TRUNC=YES`, and
prints the third compact report with `STATUS=$09`.

### Transcript Extract

```text
>L G
L S19
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

#LOADGO# ENTRY=2000
RET A=00 X=00 Y=68 P=77 S=FD NV-BdIZC
>
```

## 2026-05-26 ASM 2.42 Report Truncation Proof On HIMON

### Summary

`asm-v1-core-2000.s19` passed the onboard ASM 2.42 smoke ladder on hardware.
This proves the compact report truncation flag printer: after the clean and
first-failure report proofs, the `$5E REPORT` slice sets the report truncation
flag and prints a third report with `TRUNC=YES`, then still completes the final
warning/report smoke ladder.

### Transcript Extract

```text
>L G
L S19
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

#LOADGO# ENTRY=2000
RET A=00 X=00 Y=68 P=77 S=FD NV-BdIZC
>
```

## 2026-05-26 ASM 2.41 Failure Report Proof On HIMON

### Summary

`asm-v1-core-2000.s19` passed the onboard ASM 2.41 smoke ladder on hardware.
This proves the first-failure compact report path: the `$5E REPORT` slice prints
the clean `ASM_END` report, then enables report-on-failure, rejects a bad `ORG`
line with `BAD_OPER`, prints the failure report, preserves the failed-session
stored status, and still completes the final warning/report smoke ladder.

### Transcript Extract

```text
>L G
L S19
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

#LOADGO# ENTRY=2000
RET A=00 X=00 Y=68 P=77 S=FD NV-BdIZC
>
```

## 2026-05-26 ASM 2.40 ASM_END Report Proof On HIMON 00.0524(2131)

### Summary

`asm-v1-core-2000.s19` passed the onboard ASM 2.40 smoke ladder on hardware.
This proves compact report printing through the `ASM_END` path: the `$5E REPORT`
slice enables report-on-END, assembles through a real `END`, prints the compact
report, keeps the clean second-`ASM_END` path idempotent, and still preserves
the final `WARN_DS_WRAP` smoke report.

### Transcript Extract

```text
____      ____    ____   ____      ____
|   \    /   |   /    \  |   \    /
|___/    |___|  |      | |___/    \___
|   \    /   |  |      | |   \        \
|    \  /    |   \____/  |    \   ____/

HIMON IN 3S. S=STR8  3 2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0524(2131)
>L G
L S19
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

#LOADGO# ENTRY=2000
RET A=00 X=00 Y=68 P=77 S=FD NV-BdIZC
>
```

## 2026-05-26 ASM 2.39 Compact Report Proof On HIMON

### Summary

`asm-v1-core-2000.s19` passed the onboard ASM 2.39 smoke ladder on hardware.
This proves the compact report printer in the `$5E REPORT` slice: the report
prints status, error line, start/current/high PCs, byte count, line count,
table counts/limits, and truncation state before the final smoke ladder.

### Transcript Extract

```text
>L G
L S19
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

#LOADGO# ENTRY=2000
RET A=00 X=00 Y=68 P=77 S=FD NV-BdIZC
>
```

## 2026-05-25 ASM 2.38 Report-Fact Proof On HIMON

### Summary

`asm-v1-core-2000.s19` passed the onboard ASM 2.38 smoke ladder on hardware.
This proves the new `$5E REPORT` slice on the post-reorg RAM layout: the proof
loads and runs at `$2000`, the standalone smoke assembly target remains `$6800`,
and `WARN_DS_WRAP` still prints in the final report.

### Transcript Extract

```text
>L G
L S19
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

#LOADGO# ENTRY=2000
RET A=00 X=00 Y=68 P=77 S=FD NV-BdIZC
>
```

## 2026-05-25 ASM 2.37 RAM Reorg Proof On HIMON 00.0524(2131)

### Summary

`asm-v1-core-2000.s19` passed the onboard ASM 2.37 smoke ladder on hardware.
This proves the post-reorg RAM layout: the resident ASM proof loads and runs at
`$2000`, the standalone smoke assembly target is `$6800`, and
`WARN_DS_WRAP` still prints in the final report.

### Transcript Extract

```text
HIMON V 00.0524(2131)
>L G
L S19
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

#LOADGO# ENTRY=2000
RET A=00 X=00 Y=68 P=77 S=FD NV-BdIZC
>
```

## 2026-05-25 ASM 2.36 Visible WARN_DS_WRAP Proof On HIMON

### Summary

`asm-v1-core-3000.s19` passed the onboard ASM 2.36 smoke ladder on hardware.
This proves the corrected visible warning path: `WARN_DS_WRAP` survives later
smoke sessions and prints `WARN WARN_DS_WRAP` in the final pass report.

### Transcript Extract

```text
>L G
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
>
```

## 2026-05-25 ASM 2.35 Warning Visibility Gap On HIMON

### Summary

`asm-v1-core-3000.s19` passed the onboard ASM 2.35 smoke ladder on hardware,
but did not print the expected `WARN WARN_DS_WRAP` report line. This showed
that the directive smoke set `WARN_DS_WRAP`, but a later smoke session cleared
session-local `ASM_REPORT_FLAGS` before the final report. This is not a
functional assembler failure, but it means ASM 2.35 did not prove visible
warning reporting.

### Transcript Extract

```text
>L G
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
>
```

## 2026-05-25 ASM 2.34 WARN_DS_WRAP Proof On HIMON

### Summary

`asm-v1-core-3000.s19` passed the onboard ASM 2.34 smoke ladder on hardware.
This proves the `$5D DIRECT` slice after naming and asserting
`WARN_DS_WRAP`: a `DS` initializer list whose final repeat stops partway through
the list still succeeds, sets the warning report flag, and is not `BAD_RANGE`.

### Transcript Extract

```text
>L G
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
>
```

## 2026-05-25 ASM 2.33 DS Initializer-List Proof On HIMON

### Summary

`asm-v1-core-3000.s19` passed the onboard ASM 2.33 smoke ladder on hardware.
This proves the `$5D DIRECT` slice after adding `DS` initializer lists:
initializer bytes repeat to fill the requested count, truncate after the count,
and advance PC/high-water correctly. This run predates the later
`WARN_DS_WRAP` 2.34 change.

### Transcript Extract

```text
>L G
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

#LOADGO# ENTRY=3000
RET A=00 X=00 Y=30 P=77 S=FD NV-BdIZC
>
```

## 2026-05-25 ASM 2.32 DS Directive Proof On HIMON

### Summary

`asm-v1-core-3000.s19` passed the onboard ASM 2.32 smoke ladder on hardware.
This proves the `$5D DIRECT` slice after adding `DS`: count/fill reservation,
low-byte fill truncation, PC/high-water advance, empty-operand rejection, and
count-over-255 rejection.

### Transcript Extract

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

#LOADGO# ENTRY=3000
RET A=00 X=00 Y=30 P=77 S=FD NV-BdIZC
>
```

## 2026-05-24 ASM 2.31 ORG Policy Proof On HIMON 00.0524(2131)

### Summary

`asm-v1-core-3000.s19` passed the onboard ASM 2.31 smoke ladder under HIMON
`00.0524(2131)`. This proves the `$5D DIRECT` slice after adding ORG placement
policy: first pristine ORG may establish source origin, current/forward ORG is
allowed, and later backward ORG fails `BAD_RANGE`.

### Transcript Extract

```text
>L G
L S19
L @3000
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

#LOADGO# ENTRY=3000
RET A=00 X=00 Y=30 P=77 S=FD NV-BdIZC
```

## 2026-05-24 ASM 2.30 DB Directive Proof On HIMON 00.0524(2131)

### Summary

`asm-v1-core-3000.s19` passed the onboard ASM 2.30 smoke ladder under HIMON
`00.0524(2131)`. This proves the `$5D DIRECT` slice on hardware for `DB`
directive emission. `DC` remains parked for a later directive slice.

### Transcript Extract

```text
L S19
L @3000
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

#LOADGO# ENTRY=3000
RET A=00 X=00 Y=30 P=77 S=FD NV-BdIZC
```

## 2026-05-24 ASM 2.20 Fixup Proof On HIMON 00.0524(2131)

### Summary

`asm-v1-core-3000.s19` passed the onboard ASM 2.20 smoke ladder under HIMON
`00.0524(2131)`. This proves the `$5C FIXUPS` slice on hardware: ABS16 and
REL8 forward fixup records, selected `<`/`>` byte fixups, range failure, and
pending-fixup rejection at `END`.

### Transcript Extract

```text
>L G
L S19
L @3000
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

#LOADGO# ENTRY=3000
RET A=00 X=00 Y=30 P=77 S=FD NV-BdIZC
```

## 2026-05-24 ASM 2.10 Re-Proof On HIMON 00.0524(2131)

### Summary

`asm-v1-core-3000.s19` still passed the onboard ASM 2.10 smoke ladder under
HIMON `00.0524(2131)`. This re-proofs the ASMTEST path after the low-RAM
worker/mirror/state layout work.

### Transcript Extract

```text
HIMON V 00.0524(2131)
>L G
L S19
L @3000
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
W=$E2F4 SYM=$06 PC=$3000

#LOADGO# ENTRY=3000
RET A=00 X=00 Y=30 P=77 S=FD NV-BdIZC
```

## 2026-05-24 ASM 2.10 Opcode Emitter Proof

### Summary

`asm-v1-core-3000.s19` passed the onboard ASM 2.10 smoke ladder, including the
explicit opcode lookup/emission stage. The `$5B OPCODE` stage emits and checks
the resolved ASMTEST-path instruction byte stream while leaving forward fixups
for ASM 2.20.

### Transcript Extract

```text
>L G
L S19
L @3000
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
W=$E2F4 SYM=$06 PC=$3000

#LOADGO# ENTRY=3000
RET A=00 X=00 Y=30 P=77 S=FD NV-BdIZC
```

## 2026-05-24 ASM 2.00 Emission Foundation Proof

### Summary

`asm-v1-core-3000.s19` passed the onboard ASM 2.00 smoke ladder, including the
raw emit stage. The new `$59 EMIT` stage proves `ASM_EMIT_BYTE` and
`ASM_EMIT_WORD_LE` write through the live ASM PC, advance PC/high-water, and
return the expected failure statuses for inactive-session and wrap cases.

### Transcript Extract

```text
>L G
L S19
L @3000
L OK=25E8 GO=3000
ASM 2.00 TESTS OK
 10 BEGIN
 20 LEX LINE
 30 TOKENS
 40 VOCAB
 50 PARSER
 56 EXPR
 58 LINE
 59 EMIT
 5A OPERAND
 60 SYMBOLS
 80 LONG LINE
 90 END
W=$E2F4 SYM=$06 PC=$3000

#LOADGO# ENTRY=3000
RET A=00 X=00 Y=30 P=77 S=FD NV-BdIZC
```

## 2026-05-24 ASM Core Informative Test Report

### Summary

`asm-v1-core-3000.s19` passed the onboard ASM 1.90 smoke ladder and printed
the individual test stages. The final `PC=$3000` is expected because the
operand-classifier setup exercises `ORG $3000`, and the later symbol smoke
uses that live assembler PC.

### Transcript Extract

```text
>L G
L S19
L @3000
L OK=244F GO=3000
ASM 1.90 TESTS OK
 10 BEGIN
 20 LEX LINE
 30 TOKENS
 40 VOCAB
 50 PARSER
 56 EXPR
 58 LINE
 5A OPERAND
 60 SYMBOLS
 80 LONG LINE
 90 END
 W=$E2F4 SYM=$06 PC=$3000

#LOADGO# ENTRY=3000
RET A=00 X=00 Y=30 P=77 S=FD NV-BdIZC
```

## 2026-05-24 ASM Core Smoke And WDC ASMTEST_3000 Proof

### Summary

`asm-v1-core-3000.s19` passed the onboard lexer/vocabulary/parser/expression/
line-assembly/symbol/RJOIN smoke path and printed the ASM 1.70 pass banner.
This run includes the tightened parser smoke for colon/no-colon labels, exact
tail starts, missing directive operands, reserved/register label rejection,
local-label rejection, the statement heads used by `ASMTEST_3000`, the
resolved-atom `ASM_PARSE_EXPR` smoke, and the `ASM_ASSEMBLE_LINE` session spine.
The independent WDC-built
`ASMTEST_3000` proof also loaded and returned the expected checksum/registers.

### Transcript Extract

ASM core:

```text
>L G
L S19
L @3000
L OK=1E65 GO=3000
ASM 1.70 RJOIN OK W=$E2F4 SYM=$06 PC=$4C65

#LOADGO# ENTRY=3000
RET A=00 X=65 Y=4C P=75 S=FD NV-BdIzC
```

WDC `ASMTEST_3000` proof:

```text
>L G
L S19
L @3000
L OK=0027 GO=3000

#LOADGO# ENTRY=3000
RET A=0F X=10 Y=30 P=77 S=FD NV-BdIZC
```

Interpretation:

- ASM core success returned `A=00`, `X/Y=$4C65`, carry set. The pass banner
  proves RJOIN found the resident FTDI write routine and printed through it.
- `ASMTEST_3000` returned checksum `A=$0F`, byte count `X=$10`, and page
  `Y=$30`, matching the WDC reference proof.

## 2026-05-21 Search Ladder And FTDI TX Carry Bug

### Summary

The `S` search command reached the three-step proof ladder:

```text
S static RAM   standalone parser/scanner proof at $3000
S joined RAM   same behavior with runtime FNV helper discovery
S flash        discoverable low-flash FNV command record, run from ROM window
```

During the flash proof, occasional impossible three-digit byte displays were
observed:

```text
expected: D0 06      observed: D00 06
expected: 0D 0A      observed: 0D 00A
expected: 00 00      observed: 00 000
```

Root cause: `PIN_FTDI_WRITE_BYTE_NONBLOCK` could accept a byte after one or more
TX-ready spin iterations, but return with carry clear because `CPX` in the spin
loop had changed carry. Blocking callers interpreted `C=0` as "not accepted"
and resent the byte. The fix is to force `SEC` on the successful write-strobe
path while preserving `CLC` on timeout.

Follow-up audit: `STR8_CON_WRITE_BYTE_NONBLOCK` has the same TX-spin shape, but
already forces `SEC` on success before deassert/return. FTDI poll/read routines
explicitly return carry status, and timeout wrappers branch on the callee's
carry before issuing their own `CLC` timeout return. No second active
resend-after-success bug was found.

### Search Proof Extracts

RAM static:

```text
>L
L @3000
L OK=0520 GO=3000
>G 3000
HIMON SEARCH STATIC $3000
S> S 34AF +20 48 'IMON'
34AF*34A0: ... 48 | ...
S> S 7EF0 8010 00
S IO
S> Q
S DONE
```

RAM joined:

```text
>L
L @3000
L OK=0589 GO=3000
>G 3000
HIMON SEARCH PROOF $3000
S> S 0 FFFF FF 00
7900 7900: ...
S IO
># S
D60C1322 HSH_NF!
```

Flash command, hardware-proven K=`$03` transcript:

```text
>L F
L @BA67
LF OK WR=045C GO=BA73
># S
D60C1322 ENTRY=BA73 K=03  S(earch)
>S B000 C000 'TEXT'
RUN S(earch) @BA73 K=03 ? y
BE87 BE80: ... 45 58 54 ...
>S 0 FFFF 'HIMON'
RUN S(earch) @BA73 K=03 ? y
S ABORT
```

Current source advances the flash command record to K=`$05` and relocates it to
`$BBA2-$BFF5`, with `$FF,$FF` guard bytes before the record and spare `$FF`
padding before `$C000`. That shape keeps `S(earch)` display text while removing
the `RUN ... ?` confirmation prompt under a new HIMON build.

The current flash `S` also shares HIMON's named I/O slot printer
(`SYS_PRINT_IO_SLOT_SKIP`, hash `$C2A5A6CE`) with `D`. A range that reaches the
`$7F00-$7FFF` I/O page prints rows such as `7F80: ACIA IO SKIP` instead of
reading device registers or reporting only `S IO`.

Aligned I/O slot proof from PuTTY log, after the padded resident HIMON strings:

```text
S 0 FFFF FF
...
7900 7900: FF 49 4D 4F 4E 00 00 00 | 00 00 00 00 00 00 00 00 | .IMON...........
7E78 7E70: 0C D6 AE BB 00 00 0B 00 | FF FF 00 00 00 00 00 00 | ................
7F00: CS0      IO SKIP
7F20: CS1      IO SKIP
7F40: CS2      IO SKIP
7F60: CS3      IO SKIP
7F80: ACIA     IO SKIP
7FA0: PIA      IO SKIP
7FC0: VIA      IO SKIP
7FE0: FTDI VIA IO SKIP
8000 8000: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
```

Searching for `FF` across all memory is intentionally noisy because erased RAM
and flash areas produce many hits. The useful proof here is that the search
prints named skip rows and resumes at `$8000` without reading the I/O page.

Full notes:

```text
DOC/GUIDES/HIMON/HIMON_SEARCH_IMPLEMENTATION_GUIDE.md
```

## 2026-05-17 STR8 U OSI BASIC Payload And B0 Rotation Proof

Source transcript:

```text
operator transcript pasted into Codex session
```

Build artifacts under test:

```text
Payload S19:       SRC/BUILD/s19/msbasic-osi-str8-update.s19
S1 records:        495
S19 gate:          $C000-$EFFF only
Entry:             START $C000 -> COLD_START $DD1F
FNV header:        $C003
MSBASIC entry:     $C00B
Code end:          $DEEE
Console read/write: $F6BD / $F6E4
```

### Result

Pass.

Validated:

- `E` enrolled Bank 0 into backup rotation and changed the STR8 state from
  `B0 HOLD` to `B0 ROT`.
- After enrollment, `B` erased Bank 0/1/2 and rotated `B1->B0`, `B2->B1`,
  and `B3->B2`.
- STR8 `U` accepted the OSI BASIC `$C000-$EFFF` payload stream and printed
  `OK` after confirmed erase/write/verify.
- `G HIMON` entered the new `$C000` payload and booted OSI BASIC.
- OSI BASIC printed its memory and terminal prompts, banner, and `OK` prompt.
- A simple BASIC program entered and ran: `10 PRINT "HELLO"` / `RUN` /
  `HELLO`.
- Restore from the rotated backup chain brought back the expected images:
  HIMON U2 from Bank 0, fig-Forth from Bank 1, and OSI BASIC from Bank 2 at
  the final rotation stage.

Important backup-chain lesson:

- Bank 0 enrollment makes Bank 0 a normal rotating backup slot.
- Once enrolled, `B` no longer preserves Bank 0 as a factory/base image.
- Payloads rotate exactly like HIMON. Running `B` after BASIC or Forth is an
  intentional promotion of that payload into the backup chain.

Not tested in this pass:

- STR8 self-update.
- Restore over non-erased ordinary sectors below `$C000`.
- Deliberate high-flash failure behavior with a sacrificial image.

### Transcript Extract

Bank 0 was enrolled:

```text
STR8>
B0 ROT ON. NEXT B ERASES B0. Y: y
OK
STR8>
```

The next backup included Bank 0:

```text
STR8>
BACKUP ERASE B0/B1/B2. Y: y
COPY B1->B0

COPY B2->B1

COPY B3->B2

OK
```

The BASIC payload was installed through the same fixed `U` gate:

```text
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
...............................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................
PROGRAM C000-EFFF? Y: y...
OK
STR8>
G HIMON
```

The payload booted OSI BASIC and ran a small program:

```text
MEMORY SIZE?
TERMINAL WIDTH?

 29950 BYTES FREE

OSI 6502 BASIC VERSION 1.0 REV 3.2
COPYRIGHT 1977 BY MICROSOFT CO.

OK
10 PRINT "HELLO"
RUN
HELLO

OK
```

The rotated chain restored the expected payloads:

```text
RESTORE B0->B3 ... HIMON U2
RESTORE B1->B3 ... fig-FORTH  1.0
RESTORE B2->B3 ... OSI 6502 BASIC VERSION 1.0 REV 3.2
```

## 2026-05-17 STR8 U fig-Forth Payload Proof

Source transcript:

```text
operator transcript pasted into Codex session
```

Build artifacts under test:

```text
Payload S19: SRC/BUILD/s19/fig-forth-str8-update.s19
S1 records: 397
S19 gate:   $C000-$EFFF only
Entry:      START $C000 -> FORTH_ORIG $C00B
FNV header: $C003
Code end:   $D8C9
MON exit:   $F000
```

### Result

Pass.

Validated:

- STR8 `B` first made HIMON U1/U2 recoverable in the backup chain.
- STR8 `U` accepted a non-HIMON `$C000-$EFFF` payload stream and printed `OK`
  after confirmed erase/write/verify.
- `G HIMON` entered the new `$C000` payload and booted `fig-FORTH  1.0`.
- Simple stack words and numeric output worked from the Forth prompt.
- STR8 remained reachable after the payload boot.
- High-flash restore from a backup bank put HIMON back into Bank 3.

Important backup-chain lesson:

- `B` always means "rotate the current Bank 3 into the backup chain."
- Running `B` while Bank 3 contains fig-Forth promotes fig-Forth into Bank 2.
- After that, `2` with high flash restores fig-Forth, not old HIMON.
- To preserve old HIMON, keep at least one backup bank untouched, or restore
  from the older bank such as Bank 1.

Not tested in this pass:

- OSI MS BASIC as a `$C000` STR8 `U` payload.
- STR8 self-update.
- Deliberate failed high-flash restore behavior.

### Transcript Extract

The known-good monitor was first backed up:

```text
STR8>
BACKUP ERASE B1/B2. Y: y
COPY B2->B1

COPY B3->B2

OK
```

The Forth payload was installed through the same fixed `U` gate:

```text
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
.............................................................................................................................................................................................................................................................................................................................................................................................................
PROGRAM C000-EFFF? Y: y...
OK
STR8>
G HIMON

fig-FORTH  1.0
```

Basic stack checks ran from the Forth prompt:

```text
1 2 4 8 OK
dup OK
. 8 OK
. 8 OK
. 4 OK
. 2 OK
. 1 OK
```

Restoring an older backup brought HIMON back:

```text
STR8>
RESTORE B1->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: y
COPY B1->B3

BOOT COLD
RAM ZERO OK

HIMON U2
>
```

A later restore from Bank 2 booted Forth again because a backup had been run
after Forth was installed:

```text
STR8>
RESTORE B2->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: y
COPY B2->B3

fig-FORTH  1.0
```

## 2026-05-17 STR8 UPDATE HIMON U1->U2 And Recovery Proof

Source transcript:

```text
operator transcript pasted into Codex session
```

Build artifacts under test:

```text
ROM candidate: SRC/BUILD/bin/himon-str8-rom.bin
SHA256:        7176A1E7450A6EDF5D3102CFFDAD000325715576C8A3159E3977DBCEE439F7D5
Update S19:    SRC/BUILD/s19/himon-str8-himon-update.s19
S1 records:    315
S19 gate:      $C000-$EFFF only
Visible bytes: $E220 = 0D 0A 48 49 4D 4F 4E 20 55 B2
```

### Result

Pass.

Validated:

- STR8 `M` showed Bank 3 as the boot image before backup.
- STR8 `B` copied Bank 3 to Bank 2, making U1 the known-good recovery image.
- HIMON booted visibly as `HIMON U1` before the update.
- STR8 `U` accepted the compact `$C000-$EFFF` S19 stream, asked before
  programming, erased/wrote/verified C/D/E, and printed `OK`.
- Reboot after `U` showed `HIMON U2`, proving the visible HIMON update.
- STR8 remained reachable after the update through `G F000`.
- High-flash restore Bank 2 -> Bank 3 with `FLASH C000-FFFF? Y` restored the
  known-good U1 image.
- Reboot after restore showed `HIMON U1`.

Not tested in this pass:

- Bank 0 enrollment with `E`.
- Restore over non-erased ordinary sectors below `$C000`.
- Deliberate high-flash failure behavior with a sacrificial image.
- STR8 self-update; this pass intentionally touched HIMON `$C000-$EFFF` only.

### Transcript Extract

Backup made Bank 2 match live Bank 3:

```text
STR8>
BANK0     BANK1     BANK2     BOOT
--------  --------  --------  ----++++
...
B3 | . . . . * * * * |
STR8>
BACKUP ERASE B1/B2. Y: y
COPY B2->B1

COPY B3->B2

OK
STR8>
BANK0     BANK1     BANK2     BOOT
--------  --------  ----++++  ----++++
...
B2 | . . . . * * * * |
B3 | . . . . * * * * |
```

The baseline monitor was visibly U1:

```text
BOOT COLD
RAM ZERO OK

HIMON U1
>G F000
GO F000
```

The update stream programmed successfully:

```text
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
...........................................................................................................................................................................................................................................................................................................................
PROGRAM C000-EFFF? Y: y...
OK
```

The updated monitor booted visibly as U2:

```text
BOOT COLD
RAM ZERO OK

HIMON U2
>G F000
GO F000
```

The high-flash restore recovered the previous U1 image from Bank 2:

```text
STR8>
RESTORE B2->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: y
COPY B2->B3

BOOT COLD
RAM ZERO OK

HIMON U1
>
```

## 2026-05-15 STR8/HIMON/HREC/Search/Debug Smoke

Source transcript:

```text
C:\Users\Walter\Desktop\putty.log
PuTTY log 2026-05-15 21:38 local
follow-on operator transcript pasted into Codex session
```

Build artifacts under test:

```text
ROM:    SRC/BUILD/bin/himon-str8-rom.bin
SHA256: 614800F0AEB1865EBAE6F67EF604999768036F0A257A8804B9FFAD4C7EFA2011
HREC:   SRC/BUILD/s19/hrec-join-proof-4000.s19
Search: SRC/BUILD/s19/himon-search-proof-3000.s19
Debug:  SRC/BUILD/s19/himon-debug-proof-3000.s19
```

### Result

Pass with one resident HIMON finding.

Validated:

- STR8 prompt, map, `G` handoff, and Bank 2 to Bank 3 restore path.
- Current ROM burn-check bytes at `$C000`, `$F000`, `$F800`, and vectors.
- HREC join proof at `$4000`, including positive joins and negative probes.
- Search RAM proof at `$3000`, including mixed-case apostrophe text, I/O skip,
  no-found, and `+0` rejection.
- Debug RAM proof at `$3000`, `BRK 41`, breakpoints, resume, `N` decode,
  `JSR` step-over, branch next-PC handling, and HREC execution through debug.
- `#` catalog listing and lookup for `BIO_FTDI_WRITE_BYTE_BLOCK`.

Finding:

- Resident HIMON shared range parsing currently treats `+n` as an inclusive
  offset rather than a byte count. Example: `D C000 +10` printed `$C000-$C010`.
  The search proof already implements the target `+count` behavior by using
  `count - 1` and rejecting `+0`.

Not tested in this pass:

- STR8 `B` backup rotation.
- STR8 `E` Bank 0 enrollment.
- Restore that programs non-erased ordinary bytes below `$C000`; the map showed
  Bank 2 and Bank 3 lower sectors erased in this session.
- High-flash restore failure/RAM-only halt behavior.

### STR8 And Burn Check

STR8 reported the expected resident shell and bank map. The restore path was
exercised from Bank 2 to Bank 3 while declining high flash.

```text
STR8 V0
ROM $F000
? B E M 0 1 2 G R
B0 HOLD
STR8>
BANK0     BANK1     BANK2     BOOT
--------  --------  ----++++  ----++++
     8 9 A B C D E F
   +---------------+
B0 | . . . . . . . . |
B1 | . . . . . . . . |
B2 | . . . . * * * * |
B3 | . . . . * * * * |
   +---------------+
STR8>
RESTORE B2->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: n
COPY B2->B3

OK
STR8>
G HIMON
BOOT WARM

HIMON
```

Burn-check dumps matched the current ROM image:

```text
>D C000 +10
C000: 78 D8 A2 FF 9A AD E6 7E | C9 A5 D0 34 AD E7 7E C9 | x......~...4..~.
C010: 5A | Z
>D F000 +10
F000: 78 D8 A2 FF 9A 20 1D F0 | 20 53 F0 B0 0A A2 66 A0 | x.... .. S....f.
F010: F6 | .
>D F800 +10
F800: 08 78 AD 07 0A C9 04 F0 | 09 C9 02 F0 0A 20 78 02 | .x........... x.
F810: 80 | .
>D FFFA FFFF
FFFA: 1C DE 00 F0 1F DE | ......
```

The extra `$C010`/`F010`/`F810` byte is the `+n` finding, not a burn mismatch.

### HREC Join

The HREC join proof loaded and passed all expected probes:

```text
>L G
L S19
L @4000
L OK=0248 GO=4000
HREC JOIN PROOF $4000
WRITE OK
READ OK
FLUSH OK
CTRL OK
HEX OK
MISSING OK
KIND OK
HEXINV OK
DONE

#LOADGO# ENTRY=4000
RET A=0A X=43 Y=00 P=75 S=FD NV-BdIzC
```

Catalog lookup also proved the named routine hash, while showing that `_FNV`
labels are assembler labels for record headers and are not advertised catalog
names:

```text
># BIO_FTDI_WRITE_BYTE_BLOCK_FNV
7CB4E965 HSH_NF!
># BIO_FTDI_WRITE_BYTE_BLOCK
379FE930 ENTRY=DC26 K=00
```

The full `#` listing showed duplicate helper records in HIMON and STR8 ranges.
Current lookup scans upward and first match wins, so the HIMON/BIO entry at
`$DC26` wins over the later STR8-linked duplicate at `$F3F5`.

### Search Proof

The search RAM proof loaded at `$3000` and preserved lowercase/mixed-case
apostrophe text:

```text
>L G
L S19
L @3000
L OK=0565 GO=3000
HIMON SEARCH PROOF $3000
S START END|+COUNT BB [BB...] ['TEXT], ? HELP, Q QUIT
S> s 0 ffff 'aBc
780A 7800: 73 20 30 20 66 66 66 66 | 20 27 61 42 63 00 00 00 | s 0 ffff 'aBc...
7900 7900: 61 42 63 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | aBc.............
S IO
S> s 3000 30ff 4d
S NF
S> s 7f00 7fff 00
S IO
S NF
S> s 3000 +0 20
S START END|+COUNT BB [BB...] ['TEXT], ? HELP, Q QUIT
S> q
S DONE
```

This validates the current RAM-proof behavior: command letters can be lowercase,
apostrophe text is exact, I/O page `$7F00-$7FFF` is skipped, no-found is loud,
and `+0` is rejected before scanning.

### Debug And Step

The debug proof loaded at `$3000`, stopped at the intentional start BRK, and
then debug was used against the already-loaded HREC proof at `$4000`.

```text
>L G
L S19
L @3000
L OK=0163 GO=3000
HIMON DEBUG PROOF $3000
BRK $41: USE N TO STEP

BRK 41 PC=3013
A=16 X=3B Y=16 P=75 S=FB NV-BdIzC
```

Breakpoints and resume through HREC:

```text
>B 4004
BP $4004
>B 4007
BP $4007
>B L
4004 20
4007 B0
>G 4000
GO 4000

@4004 A=01 X=D5 Y=41 P=75 S=FB NV-BdIzC
>X
RESUME 4004

@4007 A=00 X=26 Y=DC P=B5 S=FB Nv-BdIzC
>X
RESUME 4007
HREC JOIN PROOF $4000
WRITE OK
READ OK
FLUSH OK
CTRL OK
HEX OK
MISSING OK
KIND OK
HEXINV OK
DONE
```

Single-step `N` transcript:

```text
>B L
>B 4000
BP $4000
>G 4000
GO 4000

@4000 A=01 X=30 Y=30 P=75 S=FB NV-BdIzC
>N
STEP PC=4000 OP=A2 LDX #$D5 LEN=02 NEXT=4002
RESUME 4000

@4002 A=01 X=D5 Y=30 P=F5 S=FB NV-BdIzC
>N
STEP PC=4002 OP=A0 LDY #$41 LEN=02 NEXT=4004
RESUME 4002

@4004 A=01 X=D5 Y=41 P=75 S=FB NV-BdIzC
>N
STEP PC=4004 OP=20 JSR $40F5 LEN=03 NEXT=4007
RESUME 4004

@4007 A=00 X=26 Y=DC P=B5 S=FB Nv-BdIzC
>N
STEP PC=4007 OP=B0 BCS $01 LEN=02 NEXT=400A
RESUME 4007

@400A A=00 X=26 Y=DC P=B5 S=FB Nv-BdIzC
```

Interpretation:

- `N` decoded immediate loads at `$4000` and `$4002`.
- `N` stepped over `JSR $40F5`, proving the join routine returned to `$4007`.
- `X/Y=26/DC` after the join is callable entry `$DC26`, matching
  `BIO_FTDI_WRITE_BYTE_BLOCK`.
- `N` computed the taken branch target `$400A` for `BCS $01`.

### Follow-Up

- Fix resident HIMON `CMD_PARSE_RANGE_PLUS` so `+count` means byte count:
  reject `+0`, compute `end = start + count - 1`, and reject wrap.
- Re-run `D C000 +10`, `U 4000 +10`, and a search proof `+count` smoke after
  the parser fix.
- Run a later STR8 destructive pass for `B` backup rotation and, separately,
  high-flash failure behavior.
