# R-YORS Hardware Test Log

This file records bench transcripts that prove behavior on real hardware. Keep
entries short enough to scan, but include enough serial output to reconstruct
what was actually tested.

## 2026-06-08 ASM 2.85 Implied Opcode Batch Board Proof

### Summary

Operator transcript pasted into Codex session. The board loaded
`asm-v1-runtime-paste-2000.s19` at `$2000` with size `$2FC9` after ASM 2.85
added implied-only opcode rows for CPU/register/stack mnemonics.

Validated:

- The runtime paste wrapper starts normally with the expanded implied-opcode
  table active.
- `NOP`, `DEX`, `DEY`, `INY`, `TAX`, `TAY`, `TSX`, `TXA`, `TXS`, `TYA`,
  `PHA`, `PHP`, `PHX`, `PHY`, `PLA`, `PLP`, `PLX`, `PLY`, and `RTI` assemble
  as one-byte implied opcodes.
- The final PC after all 19 rows is `$7273`.
- The emitted `$7260-$7272` bytes match the W65C02 opcode table.

### Transcript

```text
>L G
L S19
L @2000
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
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK

#LOADGO# ENTRY=2000
RET A=0F X=BE Y=0F P=75 S=FD NV-BdIzC
>D 7260 7272
7260: EA CA 88 C8 AA A8 BA 8A | 9A 98 48 08 DA 5A 68 28 | ..........H..Zh(
7270: FA 7A 40 | .z@
```

## 2026-06-08 ASM 2.83 Implied Flag Opcode Board Proof

### Summary

Operator transcript pasted into Codex session. The board loaded
`asm-v1-runtime-paste-2000.s19` at `$2000` with size `$2FE0` after ASM 2.83
added implied-only opcode rows for `CLC`, `CLD`, `CLI`, `CLV`, `SEC`, `SED`,
and `SEI`.

Validated:

- The runtime paste wrapper starts normally with the implied-opcode table active.
- `CLC`, `CLD`, `CLI`, `CLV`, `SEC`, `SED`, and `SEI` assemble as one-byte
  implied opcodes.
- The final PC after all seven rows is `$7257`.
- The emitted `$7250-$7256` bytes match the W65C02 opcode table.

### Transcript

```text
>L G
L S19

L @2000
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
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
>D 7250 7256
7250: 18 D8 58 B8 38 F8 78 | ..X.8.x
```

## 2026-06-08 ASM 2.82 BIT Opcode Board Proof

### Summary

Operator transcript pasted into Codex session. The board loaded
`asm-v1-runtime-paste-2000.s19` at `$2000` with size `$2FBB` after ASM 2.82
added opcode lookup rows for `BIT`.

Validated:

- The runtime paste wrapper starts normally with `BIT` active.
- `BIT` assembles in immediate, zero-page, absolute, zero-page X, and absolute
  X forms.
- The final PC after all five rows is `$724C`.
- The emitted `$7240-$724B` bytes match the W65C02 opcode table, including
  `BIT #imm` as `$89`.

### Transcript

```text
L @2000
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
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
>

7240: 89 12 24 12 2C 12 00 34 | 12 3C 12 00 | ..$.,..4.<..
```

## 2026-06-07 ASM 2.81 LSR/ROL/ROR Opcode Board Proof

### Summary

Operator transcript pasted into Codex session. The board loaded
`asm-v1-runtime-paste-2000.s19` at `$2000` with size `$2F82` after ASM 2.81
added opcode lookup rows for `LSR`, `ROL`, and `ROR`.

Validated:

- The runtime paste wrapper starts normally with the expanded opcode table.
- `LSR`, `ROL`, and `ROR` assemble in implied, accumulator, zero-page,
  absolute, zero-page X, and absolute X forms.
- The final PC after all 18 rows is `$7224`.
- The emitted `$7200-$7223` bytes match the W65C02 opcode table.

### Transcript

```text
>L G
L S19
L @2000
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
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK

#LOADGO# ENTRY=2000
RET A=0F X=77 Y=0F P=75 S=FD NV-BdIzC
>

>D 7200 7223
7200: 4A 4A 46 12 4E 12 00 56 | 12 5E 12 00 2A 2A 26 12 | JJF.N..V.^..**&.
7210: 2E 12 00 36 12 3E 12 00 | 6A 6A 66 12 6E 12 00 76 | ...6.>..jjf.n..v
7220: 12 7E 12 00 | .~..
>
```

## 2026-06-07 ASM 2.79 Edit-Line Paste Wrapper Board Smoke

### Summary

Operator transcript pasted into Codex session. The board loaded
`asm-v1-runtime-paste-2000.s19` at `$2000` with size `$2ECB` after the paste
wrapper switched from `SYS_READ_CSTRING_ECHO_UPPER` to
`SYS_READ_CSTRING_EDIT_ECHO_UPPER`.

Validated:

- The edit-line paste wrapper starts normally and accepts source lines.
- `.T` still prints live symbol/fixup tables mid-session.
- `END` still prints the final table block before `ASM RT PASTE OK`.
- The emitted `$7000` program runs and fills `$7100-$71FF` with `$4D`.

The earlier `$2D55` run in the same operator transcript captured the old reader
returning `READ=$08` after Backspace. This `$2ECB` run proves the paste wrapper
can use the editable reader on board without breaking the table/fixup workflow.
The operator then confirmed Backspace and Delete on the same board with the
short edit-key proof below.

### Transcript Extract

```text
>L G
L S19
L @2000
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
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7004  01 04 0E 0004 00  0000  LOOP
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 01 06   00  7005 7007 TABLE
ASM> INX
OK PC=$7008
ASM> BEQ FORWARD
OK PC=$700A
ASM> .T
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7004  01 04 0E 0004 00  0000  LOOP
FIXUPS
SL ST MODE SEL SITE BASE NAME
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
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7004  01 04 0F 0004 01  0007  LOOP
01 01 700C  01 04 0E 0008 00  0000  FORWARD
02 01 7100  01 04 0E 000B 00  0000  TABLE
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 06   00  7005 7007 TABLE
01 02 07   00  7009 700A FORWARD
ASM RT PASTE OK

#LOADGO# ENTRY=2000
RET A=0F X=C0 Y=0F P=75 S=FD NV-BdIzC
```

The emitted program was then executed:

```text
>G 7000
GO 7000

#GO# ENTRY=7000
RET A=4D X=00 Y=30 P=77 S=FD NV-BdIZC
>D 7000 71FF
7100: 4D 4D 4D 4D 4D 4D 4D 4D | 4D 4D 4D 4D 4D 4D 4D 4D | MMMMMMMMMMMMMMMM
7110: 4D 4D 4D 4D 4D 4D 4D 4D | 4D 4D 4D 4D 4D 4D 4D 4D | MMMMMMMMMMMMMMMM
... $7120-$71FF also filled with $4D ...
>
```

Edit-key confirmation:

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

## 2026-06-07 ASM 2.78 Paste Table Printer Board Proof

### Summary

Operator transcript pasted into Codex session. The board ran the ASM runtime
paste wrapper from `$2000` after adding `ASM_PRINT_TABLES` to the paste path.
The wrapper printed tables for `.T`, printed tables after failed `END`, and
printed tables after successful `END` before `ASM RT PASTE OK`.

Validated:

- `.T` is a paste-driver command, not ASM source, and prints empty or populated
  symbol/fixup rows mid-session.
- Pending fixups are visible while source is still being entered.
- Failed `END` keeps the original `BAD FIX` return status but prints the table
  block after quenching RX.
- Successful `END` prints the final table block before `ASM RT PASTE OK`.

The same transcript also captured the old line reader returning `READ=$08`
after Backspace, which led to the follow-up 2.79 switch to the existing editable
line reader.

### Transcript Extract

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> .T
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM> ORG $7000
OK PC=$7000
ASM> MAIN LDA #$4D
OK PC=$7002
ASM> STA TABLE,X
OK PC=$7007
ASM> .T
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7000  01 04 0E 0002 00  0000  MAIN
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 01 06   00  7005 7007 TABLE
...
ASM> END
ERR=$09 BAD FIX PC=$7100
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7000  01 04 0F 0002 01  0008  MAIN
01 01 7002  01 04 0E 0003 00  0000  INIT
02 01 7100  01 04 0E 000A 00  0000  TABLE
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 06   00  7005 7007 TABLE
01 01 07   00  7009 700A FORWARD

#GO# ENTRY=2000
RET A=09 X=00 Y=71 P=74 S=FD NV-BdIzc
```

Successful finalization in the same operator session:

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
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7000  01 04 0F 0002 01  0007  MAIN
01 01 700C  01 04 0E 0008 00  0000  FORWARD
02 01 7100  01 04 0E 000A 00  0000  TABLE
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 06   00  7005 7007 TABLE
01 02 07   00  7009 700A FORWARD
ASM RT PASTE OK

#GO# ENTRY=2000
RET A=0F X=4A Y=0F P=75 S=FD NV-BdIzC
>
```

## 2026-06-07 ASM 2.77 Table Printer Board Proof

### Summary

Operator transcript pasted into Codex session. The board loaded
`asm-v1-runtime-asmtest-2000.s19` at `$2000` with size `$2AB2`, ran the
runtime asmtest wrapper, printed the new `ASM TABLES` block, emitted and ran
the `$7000` ASMTEST program, and finished with `ASM RT ASMTEST OK`.

Validated:

- `ASM_PRINT_TABLES` prints symbol rows after `ASM_END`.
- Symbol rows expose slot, state, value, kind, width, flags, defining line,
  use count, first-reference line, and name.
- Fixup rows expose slot, state, mode, selector, site, base, and target name.
- The three expected ASMTEST fixups resolve before table printing:
  `SEED` absolute indexed at `$7006`, and `<TEXT`/`>TEXT` at `$7017/$7019`.
- The emitted program still calls the resident `BIO_FTDI_PUT_CSTR` target and
  prints `RJOIN`, then the wrapper reports `ASM RT ASMTEST OK`.

The final `#LOADGO#` return has `P=75`, so carry is set. `A=11 X=9D Y=11` are
the wrapper's last print-path register residues, not an ASM failure status.
This transcript is the initial table-printer proof before the later
column-padding cleanup. A follow-up `$2AC7` board run proved the padded row
shape.

### Transcript Extract

```text
L S19
L @2000
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

### Column Padding Transcript Extract

```text
>L G
L S19
L @2000
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

## 2026-06-07 HIMON 00.0606(2155) G Fresh-Run Telemetry Proof

### Summary

Operator transcript pasted into Codex session. The board first showed
`HIMON V 00.0606(2141)` and a catalog record for
`BIO_FTDI_PUT_CSTR_FNV` resolving `AEFA0F42` to `$E558`. The operator then
entered STR8, updated the HIMON `$C000-$EFFF` range, and warm-booted
`HIMON V 00.0606(2155)`.

The updated ROM then loaded `asm-v1-runtime-paste-2000.s19` with
`L OK=2B56 GO=2000`. Pasting `himon.asm` fails at unsupported `MODULE`, as
expected. The first failure returns through `#LOADGO#`; repeating the same
paste with manual `G 2000` now returns through a visible fresh `#GO# ... RET`
block. A later run in the same operator transcript created a live NMI context
inside the ASM paste prompt, then used `G 2000`; the returning ASM failure
still printed fresh `#GO# ... RET`, proving `G` cleared the saved trap marker
well enough for ordinary return telemetry.

Follow-up `R` reported `BRK 03 PC=C0D1`, not `NOCTX`. That context is the
top-level HIMON input abort path, and it is distinct from the earlier
`NMI PC=40D2`; the proven contract for this slice is fresh `#GO#` return
telemetry, not an empty debug context forever after the run.

Validated:

- STR8 `UPDATE HIMON C000-EFFF` programmed the 2155 HIMON update and warm boot
  reported `HIMON V 00.0606(2155)`.
- Manual `G 2000` into the ASM paste wrapper prints fresh `#GO#` return
  telemetry after the first ASM error.
- Manual `G 2000` also prints fresh `#GO#` return telemetry after a live
  `NMI PC=40D2` context.
- The ASM paste wrapper still reports `ERR=$01 BAD MNEM PC=$7000` with
  `A=01 X=00 Y=70` on return.
- `R` after the proof may report a later/top-level `BRK 03 PC=C0D1` context;
  that does not invalidate the fresh `#GO#` return proof.

### Transcript Extract

```text
HIMON V 00.0606(2141)
>#
HASH     ENTRY K TEXT
...
AEFA0F42 E558 05 PUT CSTR
B0051A80 C000 03 HIMON: V 00.0606(2141)
A2AD0E18 F000 03 STR8: BOOTLOADER
>G F000
GO F000
...
STR8 V0 #5F6A0F7A
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
...
PROGRAM C000-EFFF? Y: y...
OK
STR8>
G HIMON
BOOT WARM

HIMON V 00.0606(2155)
>L G
L S19
L @2000
L OK=2B56 GO=2000
ASM RT PASTE
... comments accepted at $7000 ...
ASM>                         MODULE          HIMON_APP
ERR=$01 BAD MNEM PC=$7000

#LOADGO# ENTRY=2000
RET A=01 X=00 Y=70 P=74 S=FD NV-BdIzc
>G 2000
GO 2000
ASM RT PASTE
... comments accepted at $7000 ...
ASM>                         MODULE          HIMON_APP
ERR=$01 BAD MNEM PC=$7000

#GO# ENTRY=2000
RET A=01 X=00 Y=70 P=74 S=FD NV-BdIzc
>

BRK 03 PC=C0D1
A=04 X=00 Y=7B P=77 S=FF NV-BdIZC
>#
...
B0051A80 C000 03 HIMON: V 00.0606(2155)
A2AD0E18 F000 03 STR8: BOOTLOADER
>
... cold boot path omitted; reload asm-v1-runtime-paste-2000.s19 ...
L OK=2B56 GO=2000
ASM RT PASTE
ASM>
NMI PC=40D2
A=02 X=60 Y=42 P=E4 S=F1 NV-bdIzc
>G 2000
GO 2000
ASM RT PASTE
... comments accepted at $7000 ...
ASM>                         MODULE          HIMON_APP
ERR=$01 BAD MNEM PC=$7000

#GO# ENTRY=2000
RET A=01 X=00 Y=70 P=74 S=FD NV-BdIzc
>
>R

BRK 03 PC=C0D1
A=04 X=00 Y=7B P=77 S=FF NV-BdIZC
>
```

## 2026-06-07 ASM 2.73 BIO_FTDI_PUT_CSTR RJOIN Board Proof

### Summary

Operator updated HIMON through STR8 and warm-booted `HIMON V 00.0606(2141)`.
The `asm-v1-runtime-asmtest-2000.s19` image then loaded with
`L OK=292C GO=2000` and ran the runtime ASMTEST wrapper against the updated
resident catalog.

Validated:

- Runtime ASM can assemble `JSR BIO_FTDI_PUT_CSTR` as a resident-catalog
  executable operand.
- The emitted `$7000` program prints `RJOIN` through that assembled call before
  the wrapper prints `ASM RT ASMTEST OK`.
- The emitted operand at `$701D` is `20 58 E5`, a real `JSR $E558`, not the old
  unresolved `20 FF FF` placeholder and not a high-zero target.
- The current HIMON map identifies `$E558` as `SYS_WRITE_CSTRING`, matching
  the `BIO_FTDI_PUT_CSTR_FNV` record payload.
- The normal ASMTEST runtime result remains intact:
  `$7100-$710F = "R-YORS ASM TEST."` and `$7110=$0F`.

### Transcript Extract

```text
>L G
L S19
L @2000
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
... remaining displayed $7120-$71F0 bytes were $00 ...
>
```

## 2026-06-07 ASM 2.72 Runtime Paste Quench-To-HIMON Proof

### Summary

Operator transcript pasted into Codex session. The
`asm-v1-runtime-paste-2000.s19` image loaded with `L OK=2B56 GO=2000`.
Runtime paste failures now print the named ASM error, quench RX using the
failure funnel, and return to HIMON with failure registers instead of reopening
`ASM> `.

Validated:

- Unsupported source such as `MODULE HIMON_APP` fails as
  `ERR=$01 BAD MNEM PC=$7000`, then returns to HIMON as
  `RET A=01 X=00 Y=70`.
- A bad directive spelling such as `ORGY $7000` fails as
  `ERR=$01 BAD MNEM PC=$7000` and returns directly to the HIMON prompt.
- A pending unresolved fixup at `END` fails as `ERR=$09 BAD FIX PC=$704E` and
  returns directly to the HIMON prompt.
- No pasted source tail is accepted as a fresh `$7000` ASM session after these
  failures.

Observed separately: after the large `himon.asm` paste abort, HIMON reported
`BRK 03 PC=C0D1`. In the current listing this maps to the top-level HIMON input
abort path after `HIM_READ_LINE_ECHO_UPPER` returns `CMD_ABORT_TOP`, not to the
ASM paste wrapper itself. In the ROM under test, that BRK left `NMI_CTX_FLAG`
set, so later manual `G 2000` runs in the same monitor session could return
without printing a fresh `#GO# ... RET` block; `CMD_EXEC_ADDR` preserved the
active trap context instead of overwriting it with ordinary return telemetry.

The later `ERR=$06 BAD RANGE PC=$7403` in the same operator transcript is also
separate from paste-abort quenching. It came from one still-open ASM session:
`BRA MAINX` at `$7000` left a pending relative fixup, and a later `MAINX` label
at `$7403` resolved that fixup out of branch range.

### Transcript Extract

```text
>L G
L S19
L @2000
L OK=2B56 GO=2000
ASM RT PASTE
ASM> ; ----------------------------------------------------------------------------
OK PC=$7000
... comments accepted at $7000 ...
ASM>                         MODULE          HIMON_APP
ERR=$01 BAD MNEM PC=$7000

#LOADGO# ENTRY=2000
RET A=01 X=00 Y=70 P=74 S=FD NV-BdIzc
>

BRK 03 PC=C0D1
A=04 X=00 Y=7B P=77 S=FF NV-BdIZC
>G 2000
GO 2000
ASM RT PASTE
ASM>         ORGY $7000
ERR=$01 BAD MNEM PC=$7000
>G 2000
GO 2000
ASM RT PASTE
... ASM_LINE_ECHO_7000.asm with BRA MAINX accepted through code body ...
ASM>         END
ERR=$09 BAD FIX PC=$704E
>

BRK 03 PC=C0D1
A=04 X=00 Y=7B P=77 S=FF NV-BdIZC
>G 2000
GO 2000
ASM RT PASTE
... one session has BRA MAINX pending at $7000 ...
ASM>         ORG $7400
OK PC=$7400
ASM> LINEX    EQU $7500
OK PC=$7400
ASM>         BRA MAINX
OK PC=$7402
ASM> DONEX    RTS
OK PC=$7403
ASM> MAINX    LDA #$3F
ERR=$06 BAD RANGE PC=$7403
>
```

## 2026-06-06 ASM 2.70 Runtime Paste Status-Table Trim Proof

### Summary

Operator transcript pasted into Codex session. The table-trimmed
`asm-v1-runtime-paste-2000.s19` image loaded with `L OK=2AF6 GO=2000`,
accepted the `ASM_LINE_ECHO_7000.asm` sample through the paste driver,
finalized with `ASM RT PASTE OK`, and ran the emitted `$7000` program.

Validated:

- The 2.70 low/high status-name pointer table build produces the expected
  `$2AF6` paste image.
- The smaller paste driver still accepts the line-echo sample through `END`.
- The emitted `$7000` program still calls the resident read/write services and
  echoes an interactive `HELLO WORLD!` line.
- This preserves the 2.68 line-echo behavior after the 2.70 status-printer
  size trim.

### Transcript Extract

```text
>L G
L S19
L @2000
L OK=2AF6 GO=2000
ASM RT PASTE
ASM>
ASM> ; ASM V1 PASTE SAMPLE FOR ASM RT PASTE.
OK PC=$7000
ASM> ; RUN WITH G 7000. LINES ECHO BACK AFTER "=> ".
OK PC=$7000
ASM> ; TYPE Q OR . TO RETURN TO HIMON.
OK PC=$7000
ASM>
ASM>         ORG $7000
OK PC=$7000
ASM> LINE    EQU $7100
OK PC=$7000
ASM>
ASM>         BRA MAIN
OK PC=$7002
ASM> DONE    RTS
OK PC=$7003
ASM>
ASM> MAIN    LDA #$3F
OK PC=$7005
... sample accepted through BRA ECHO ...
ASM>         BRA ECHO
OK PC=$704E
ASM>
ASM>         END
OK PC=$704E
ASM RT PASTE OK

#LOADGO# ENTRY=2000
RET A=0F X=4C Y=0F P=75 S=FD NV-BdIzC
>G 7000
GO 7000
? HELLO WORLD!
=> HELLO WORLD!
?
```

### Additional Transcript Extract

The same line-echo sample was rerun from an already-loaded paste wrapper. This
run proves the emitted program still echoes longer mixed text and that embedded
`.` characters are ordinary payload unless the line begins with `.`.

```text
>G 2000
GO 2000
ASM RT PASTE
ASM>         ORG $7000
OK PC=$7000
ASM> LINE    EQU $7100
OK PC=$7000
... ASM_LINE_ECHO_7000.asm accepted through END ...
ASM>         END
OK PC=$704E
ASM RT PASTE OK

#GO# ENTRY=2000
RET A=0F X=4C Y=0F P=75 S=FD NV-BdIzC
>G 7000
GO 7000
? HHHH HHH LJK.J.JLJKJ
=> HHHH HHH LJK.J.JLJKJ
?
```

## 2026-06-06 ASM 2.69 Runtime Paste Named-Error Recovery Proof

### Summary

Operator transcript pasted into Codex session. The updated
`asm-v1-runtime-paste-2000.s19` image had accepted the line-echo sample through
`BRA ECHO`, then received an intentionally bad ASM line.

Validated:

- Paste-driver ASM errors now print both the stable status byte and the
  mnemonic status name.
- The invalid `BVF $4FRE` line reports `ERR=$03 BAD OPER PC=$704E`.
- The paste driver returns to `ASM> ` instead of dropping back to HIMON.
- This transcript proves the hardware-visible reprompt path. A longer pasted
  burst can separately prove how much pending RX data was drained.

### Transcript Extract

```text
ASM>         BRA ECHO
OK PC=$704E
ASM>
ASM> BVF $4FRE
ERR=$03 BAD OPER PC=$704E
ASM>
```

## 2026-06-06 ASM 2.68 Runtime Paste Line Echo Proof

### Summary

Operator transcript pasted into Codex session. The already-loaded
`asm-v1-runtime-paste-2000.s19` image was entered with `G 2000`, accepted the
`ASM_LINE_ECHO_7000.asm` sample through the paste driver, finalized with
`ASM RT PASTE OK`, and ran the emitted `$7000` program interactively.

Validated:

- A pasteable sample can use resident `SYS_READ_CSTRING_ECHO_UPPER` and
  `BIO_FTDI_WRITE_BYTE_BLOCK` together.
- The sample stays within ASM v1 proof limits after the earlier `BAD_FIX=$09`
  failure: only a small number of forward fixups are outstanding at once.
- The emitted program prompts with `? `, echoes typed lines after `=> `, and
  returns to HIMON when the operator enters `.`.
- `LINE EQU $7100` keeps the input buffer on the established scratch data page
  while code emits from `$7000` through `$704D`.

### Transcript Extract

```text
>G 2000
GO 2000
ASM RT PASTE
ASM>  ; ASM V1 PASTE SAMPLE FOR ASM RT PASTE.
OK PC=$7000
ASM> ; RUN WITH G 7000. LINES ECHO BACK AFTER "=> ".
OK PC=$7000
ASM> ; TYPE Q OR . TO RETURN TO HIMON.
OK PC=$7000
ASM>
ASM>         ORG $7000
OK PC=$7000
ASM> LINE    EQU $7100
OK PC=$7000
ASM>
ASM>         BRA MAIN
OK PC=$7002
ASM> DONE    RTS
OK PC=$7003
ASM>
ASM> MAIN    LDA #$3F
OK PC=$7005
ASM>         JSR BIO_FTDI_WRITE_BYTE_BLOCK
OK PC=$7008
ASM>         LDA #$20
OK PC=$700A
ASM>         JSR BIO_FTDI_WRITE_BYTE_BLOCK
OK PC=$700D
ASM>         LDX #<LINE
OK PC=$700F
ASM>         LDY #>LINE
OK PC=$7011
ASM>         JSR SYS_READ_CSTRING_ECHO_UPPER
OK PC=$7014
ASM>         BCC MAIN
OK PC=$7016
ASM>         BEQ MAIN
OK PC=$7018
ASM>         LDA LINE
OK PC=$701B
ASM>         EOR #'Q'
OK PC=$701D
ASM>         BEQ DONE
OK PC=$701F
ASM>         LDA LINE
OK PC=$7022
ASM>         EOR #'.'
OK PC=$7024
ASM>         BEQ DONE
OK PC=$7026
ASM>         LDA #$3D
OK PC=$7028
ASM>         JSR BIO_FTDI_WRITE_BYTE_BLOCK
OK PC=$702B
ASM>         LDA #$3E
OK PC=$702D
ASM>         JSR BIO_FTDI_WRITE_BYTE_BLOCK
OK PC=$7030
ASM>         LDA #$20
OK PC=$7032
ASM>         JSR BIO_FTDI_WRITE_BYTE_BLOCK
OK PC=$7035
ASM>         LDX #0
OK PC=$7037
ASM> ECHO    LDA LINE,X
OK PC=$703A
ASM>         BNE OUT
OK PC=$703C
ASM>         LDA #$0D
OK PC=$703E
ASM>         JSR BIO_FTDI_WRITE_BYTE_BLOCK
OK PC=$7041
ASM>         LDA #$0A
OK PC=$7043
ASM>         JSR BIO_FTDI_WRITE_BYTE_BLOCK
OK PC=$7046
ASM>         BRA MAIN
OK PC=$7048
ASM> OUT     JSR BIO_FTDI_WRITE_BYTE_BLOCK
OK PC=$704B
ASM>         INX
OK PC=$704C
ASM>         BRA ECHO
OK PC=$704E
ASM>
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

## 2026-06-06 ASM 2.67 Runtime Paste Local-Precedence Proof

### Summary

Operator transcript pasted into Codex session. The already-loaded
`asm-v1-runtime-paste-2000.s19` image was entered with `G 2000`, accepted a
short source program that deliberately defined a session symbol named
`BIO_FTDI_WRITE_BYTE_BLOCK`, then assembled `JSR BIO_FTDI_WRITE_BYTE_BLOCK`.

Validated:

- A defined session symbol wins before the resident EXEC catalog fallback for
  the same source name.
- The emitted call operand is the local `$7000` target (`20 00 70`), not the
  old unresolved `20 FF FF` placeholder and not the ROM resident routine.
- Running `$7000` returns immediately through the locally defined `RTS`.
- This proof covers defined-name precedence only; forward same-name policy is
  still a separate ASM v1 decision.

### Transcript Extract

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

## 2026-06-06 ASM 2.66 Runtime Paste Resident Write Proof

### Summary

Operator transcript pasted into Codex session. The already-loaded
`asm-v1-runtime-paste-2000.s19` image was entered with `G 2000`, accepted a
small source program through the paste driver, resolved
`JSR BIO_FTDI_WRITE_BYTE_BLOCK` through the resident EXEC join path, finalized
with `ASM RT PASTE OK`, and ran the emitted `$7000` program.

Validated:

- The paste driver accepts a useful hand-written program, not only the ASMTEST
  oracle.
- `BIO_FTDI_WRITE_BYTE_BLOCK` is the correct resident blocking FTDI write
  routine name for pasted ASM source.
- The emitted program uses only currently-supported ASM v1 opcodes:
  `LDX #imm8`, `LDA #imm8`, `JSR abs16`, `INX`, `BNE`, and `RTS`.
- Running `$7000` prints 256 `M` characters, proving the resident call operand
  resolved, emitted, and executed.

### Transcript Extract

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

## 2026-06-06 ASM 2.66 Runtime Paste Driver Hardware Proof

### Summary

Operator transcript pasted into Codex session. The runtime paste-driver image
loaded at `$2000` with `L OK=2A0A GO=2000`, started as `ASM RT PASTE`, accepted
the `$7000/$7100/$7110` ASMTEST mirror source line by line, and finalized with
`ASM RT PASTE OK` after `END`.

Validated:

- The RAM-loaded paste driver can call the stripped ASM runtime through
  `ASM_BEGIN` and `ASM_ASSEMBLE_LINE`.
- `ORG`, `EQU`, labels, mnemonic emission, forward `SEED` fixup resolution,
  `DB`, and `END` all accept through the pasted source path.
- Each accepted line reports the expected next PC, ending at `$7027`.
- The emitted image at `$7000` matches the ASMTEST mirror, including
  `LDA SEED,X` patched to `BD 17 70`.
- The final `G 7000` runs the emitted program and returns `A=$0F/X=$10`,
  matching the expected checksum and seed byte count.

The `$7100-$7110` display in this transcript appears before the final `G 7000`
and already contains the expected output bytes. The final run register proof is
the run-after-paste evidence in this entry.

### Transcript Extract

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
>D 7100 711F
7100: 52 2D 59 4F 52 53 20 41 | 53 4D 20 54 45 53 54 2E | R-YORS ASM TEST.
7110: 0F 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>
>G 7000
GO 7000

#GO# ENTRY=7000
RET A=0F X=10 Y=30 P=77 S=FD NV-BdIZC
>
```

## 2026-06-05 ASM 2.65 ASMTEST Smoke Hardware Proof

### Summary

Operator transcript pasted into Codex session. The corrected standalone ASM
core image loaded at `$2000` with `L OK=4A13 GO=2000`, ran the new `ASM 2.65`
smoke ladder, reached the `$70 ASMTEST` onboard checkpoint, and continued
through `$80 LONG LINE` and `$90 END` to the pass banner.

Validated:

- The corrected stage-70 tail flow no longer falls into the failure path.
- The onboard ASMTEST mirror assembles through the standalone smoke ladder.
- The pass banner proves the `$70 ASMTEST` emitted-image/PC assertions passed.
- The final reported `PC=$6813` is the restored ASM scratch buffer PC after the
  non-destructive `$7000` ASMTEST mirror smoke.

### Transcript Extract

```text
>L G
L S19
L @2000
L OK=4A13 GO=2000
 00 RJOIN
ASM 2.65 RUN
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
 70 ASMTEST
 80 LONG LINE
 90 END
ASM 2.65 TESTS OK
WARN WARN_DS_WRAP
W=$E2DF SYM=$00 PC=$6813

#LOADGO# ENTRY=2000
RET A=00 X=13 Y=68 P=77 S=FD NV-BdIZC
```

## 2026-06-05 ASM 2.65 ASMTEST Smoke Failed Bench Attempt

### Summary

Operator transcript pasted into Codex session. The standalone ASM core image
loaded at `$2000`, printed the new `ASM 2.65 RUN` banner, and reached the new
`$70 ASMTEST` onboard smoke checkpoint. The run failed inside that checkpoint
with public `ASM_STATUS=OK`, so this is an internal smoke assertion failure,
not a source-line API error.

This run used load marker `L OK=49FB GO=2000`, which predates the corrected
stage-70 tail flow. The local follow-up fix rebuilds as `L OK=4A13 GO=2000`;
that corrected image still needs a bench rerun.

### Transcript Extract

```text
>L G
L S19
L @2000
L OK=49FB GO=2000
 00 RJOIN
ASM 2.65 RUN
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
 70 ASMTEST
ASM 2.65 TESTS FAIL
 70 ASMTEST
S=$70 X=$00 Y=$02

#LOADGO# ENTRY=2000
RET A=70 X=00 Y=02 P=74 S=FD NV-BdIzc
```

## 2026-06-05 ASM 2.62 ASMTEST_3000 REPL Paste/Run Proof

### Summary

Operator transcript pasted into Codex session. The already-loaded ASM resident
REPL was entered with `G 2184` and identified itself as `ASM 2.61 REPL`; this
2.62 proof slice records the first full `ASMTEST_3000` source paste through the
resident line-at-a-time assembler path.

Validated:

- Comment and blank source lines are accepted without advancing PC.
- First pristine `ORG $6800` establishes the sample origin from the REPL's
  initial `$7000` target.
- `EQU`, label binding, mnemonic emission, `DB`, forward absolute fixup
  resolution, and `END` all accept the sample.
- The emitted image at `$6800-$6826` matches the expected W65C02 bytes,
  including `LDA SEED,X` patched from `BD FF FF` to `BD 17 68`.
- Running `$6800` returns `A=$0F` and `X=$10`, matching the sample checksum and
  byte count.
- A follow-up post-run display captures `$6900-$690F` as the expected seed
  bytes and `$6910=$0F`, completing the `ASMTEST_3000` bench gate.

### Transcript Extract

```text
>G 2184
GO 2184
ASM 2.61 REPL
ASM> ; ASM V1 SMOKE TEST. PASTE/LOAD AS ASM SOURCE.
OK PC=$7000
ASM> ; RUN AT $6800, THEN DISPLAY $6900-$6910.
OK PC=$7000
ASM> ; EXPECTED: $6900-$690F SEED, $6910 CHECKSUM $0F.
OK PC=$7000
ASM>
ASM>         ORG $6800
OK PC=$6800
ASM>
ASM> OUT EQU $6900
OK PC=$6800
ASM> SUM EQU $6910
OK PC=$6800
ASM> COUNT EQU 16
OK PC=$6800
ASM>
ASM> ASMTEST LDX #0
OK PC=$6802 BYTES= A2 00 DEF=$6800
ASM>         STZ SUM
OK PC=$6805 BYTES= 9C 10 69
ASM> LOOP    LDA SEED,X
OK PC=$6808 BYTES= BD FF FF DEF=$6805
ASM>         STA OUT,X
OK PC=$680B BYTES= 9D 00 69
ASM>         EOR SUM
OK PC=$680E BYTES= 4D 10 69
ASM>         STA SUM
OK PC=$6811 BYTES= 8D 10 69
ASM>         INX
OK PC=$6812 BYTES= E8
ASM>         CPX #COUNT
OK PC=$6814 BYTES= E0 10
ASM>         BNE LOOP
OK PC=$6816 BYTES= D0 EF
ASM>         RTS
OK PC=$6817 BYTES= 60
ASM>
ASM> SEED    DB $52,$2D,$59,$4F,$52,$53,$20,$41
OK PC=$681F BYTES= 52 2D 59 4F 52 53 20 41 DEF=$6817 FIX=$6806
ASM>         DB $53,$4D,$20,$54,$45,$53,$54,$2E
OK PC=$6827 BYTES= 53 4D 20 54 45 53 54 2E
ASM>         END
OK PC=$6827
ASM>

>D 6800 683F
6800: A2 00 9C 10 69 BD 17 68 | 9D 00 69 4D 10 69 8D 10 | ....i..h..iM.i..
6810: 69 E8 E0 10 D0 EF 60 52 | 2D 59 4F 52 53 20 41 53 | i.....`R-YORS AS
6820: 4D 20 54 45 53 54 2E 00 | 00 00 00 00 00 00 00 00 | M TEST..........
6830: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>

>G 6800
GO 6800

#GO# ENTRY=6800
RET A=0F X=10 Y=30 P=77 S=FD NV-BdIZC
>
```

### Follow-Up Output Display

The operator then displayed the wider `$6800-$6FFF` range. The relevant
post-run output rows are:

```text
>D 6800 6FFF
...
6900: 52 2D 59 4F 52 53 20 41 | 53 4D 20 54 45 53 54 2E | R-YORS ASM TEST.
6910: 0F 20 20 49 4F 20 53 4B | 49 D0 41 43 49 41 20 20 | .  IO SKI.ACIA
...
>
```

Interpretation: `$6900-$690F` contains the 16 expected seed bytes, and `$6910`
contains the expected checksum byte `$0F`. Bytes after `$6910` are preexisting
RAM contents outside the sample's output contract.

## 2026-06-01 ASM 2.61 Resident REPL Proof On HIMON

### Summary

`asm-v1-resident-2000.s19` loaded and entered the resident ASM REPL on hardware
under `HIMON V 00.0601(1253)`. The run proves the lean resident image starts at
`$2000`, accepts `ORG`, emits immediate and DB bytes at `$7000`, records a
PC-bound label definition, and resolves that label in a later absolute `LDA`.

Validated:

- Resident S19 load marker: `L OK=2B82 GO=2000`.
- Resident REPL entry at `$2000`: `ASM 2.61 REPL`.
- Immediate emission: `LDA #$4D` -> `A9 4D`, PC `$7002`.
- Label/data emission: `FOO: DB $7E` -> `7E`, `DEF=$7002`, PC `$7003`.
- Symbol resolution: `LDA FOO` -> `AD 02 70`, PC `$7006`.

### Transcript Extract

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

## 2026-05-26 ASM 2.53 Progress Reaches Tokens Then BRK

### Summary

Result: not green, but the progress output did its job. ASM loaded as
`L OK=474E GO=2000`, printed through `30 TOKENS`, then reported
`BRK 00 PC=0002`.

Working interpretation: `ASM_SMOKE_TOKENS` depended on lexer state from the
prior `20 LEX LINE` stage. ASM 2.53 inserted progress output between those
stages, and the printer uses scratch ZP before `ASM_SMOKE_TOKENS` reads the
first token. ASM 2.54 makes the token smoke re-lex its own input before reading
tokens.

### Transcript Extract

```text
>L G
L S19
L @2000
L OK=474E GO=2000
 00 RJOIN
ASM 2.53 RUN
 10 BEGIN
 20 LEX LINE
 30 TOKENS

BRK 00 PC=0002
A=20 X=46 Y=00 P=35 S=F5 Nv-BdIzC
>
```

## 2026-05-26 ASM 2.51 Resident FNV Bootstrap NMI On HIMON

### Summary

Result: inconclusive. STR8 successfully updated HIMON to
`HIMON V 00.0525(2150)`, and ASM loaded as `L OK=4715 GO=2000`, but `GO 2000`
entered the local RJOIN bootstrap scanner and was operator-interrupted at
`PC=$264E` after an unexpected delay.

Map interpretation: `$264E` is inside `ASM_RJ_FIND_ADV`, before the smoke
ladder starts, so this NMI does not prove a crash. The follow-up 2.52 slice
caches RJOIN/FNV resolution and starts the local bootstrap scan at `$C000` to
avoid repeated long ROM scans. The 2.53 follow-up adds live smoke progress
lines, beginning with `00 RJOIN` once the resident writer is known, so a paused
board exposes the last checkpoint reached.

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

## 2026-06-08 ASM 2.86 STX/STY/TRB/TSB/CPY Paste Proof

Purpose: prove the ASM v1 runtime paste image at `$2000` emits the new
`STX`, `STY`, `TRB`, `TSB`, and `CPY` opcode rows, including zero-page `,Y`
for `STX`.

```text
>L G
L S19
L @2000
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
>
```

Interpretation: the dump matches the expected W65C02 opcodes:
`86/8E/96`, `84/8C/94`, `14/1C`, `04/0C`, and `C0/C4/CC`.

## 2026-06-08 HIMON Quote Catalog K=05 Proof

Purpose: prove the quote-command FNV catalog entry now reports kind `$05` and
prints the STR8 easter-egg text through the `#` catalog view.

```text
270C92A5 C1D6 05 "[TEXT]" -> #5F6A0F7A# STR8 MATCH!
```

Interpretation: hash `$270C92A5` resolves to entry `$C1D6`, kind `$05`
(`EXEC+TEXT`), and its extra text advertises the quoted-text hash easter egg.
