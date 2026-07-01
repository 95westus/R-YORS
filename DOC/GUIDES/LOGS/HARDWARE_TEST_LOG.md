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

## 2026-06-08 ASM 2.87 INC/DEC/CMP Paste Proof

Purpose: prove the ASM v1 runtime paste image at `$2000` emits the new
`INC`, `DEC`, and `CMP` opcode rows.

```text
1
BOOT COLD
RAM ZERO OK

HIMON V 00.0607(2103)
>L G
L S19
L @2000
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

#LOADGO# ENTRY=2000
RET A=0F X=72 Y=0F P=75 S=FD NV-BdIzC
>D 72A0 72C1
72A0: 1A E6 12 EE 12 00 F6 12 | FE 12 00 3A C6 12 CE 12 | ...........:....
72B0: 00 D6 12 DE 12 00 C9 12 | C5 12 CD 12 00 D5 12 DD | ................
72C0: 12 00 | ..
>
```

Interpretation: the dump matches the expected W65C02 opcodes:
`1A/E6/EE/F6/FE`, `3A/C6/CE/D6/DE`, and `C9/C5/CD/D5/DD`.

## 2026-06-08 ASM 2.88 ADC/SBC/AND/ORA Paste Proof

Purpose: prove the ASM v1 runtime paste image at `$2000` emits the new
`ADC`, `SBC`, `AND`, and `ORA` opcode rows.

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

Interpretation: the dump matches the expected W65C02 opcodes:
`69/65/6D/75/7D`, `E9/E5/ED/F5/FD`, `29/25/2D/35/3D`, and
`09/05/0D/15/1D`.

## 2026-06-08 ASM 2.89 Source-Width Address Proof

Purpose: prove that source width, not numeric value, controls zero-page versus
absolute address emission for `EQU` symbols.

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

Interpretation: `ZP_OFFSET0` stores width `$03` and emits `A5 00`;
`ABS_OFFSET0` stores width `$04` and emits `AD 00 00` despite having the
same numeric value.

## 2026-06-08 ASM 2.90 LDX/LDY/CPX Paste Proof

Purpose: prove the ASM v1 runtime paste image at `$2000` emits the completed
`LDX`, `LDY`, and `CPX` direct address rows.

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

Interpretation: the dump matches the expected W65C02 opcodes:
`A2/A6/AE/B6/BE`, `A0/A4/AC/B4/BC`, and `E0/E4/EC`.

## 2026-06-08 ASM 2.91 BRK Lookup Freeze

Purpose: record the failed ASM 2.91 board proof for absolute `JMP` and
ABI-style `BRK #imm8`.

```text
>L G
L S19
L @2000
L OK=2FFA GO=2000
ASM RT PASTE
ASM> ORG $7340
OK PC=$7340
ASM> JMP $0012
OK PC=$7343
ASM> BRK #$12
 frozen, board locked, nmi to reset.
NMI PC=29A7
A=2D X=51 Y=00 P=24 S=F1 Nv-bdIzc
>
>G 2000
GO 2000
ASM RT PASTE
ASM> BRK
```

Interpretation: the lockup happened while ASM was looking up `BRK #$12`,
before it accepted the line and before the emitted test program could run. The
NMI PC mapped into the old opcode mode-row scanner in the `$2FFA` image. The
mode-row table had crossed the single 8-bit `X` scan limit, so the scanner
wrapped instead of reaching the late `BRK` row.

## 2026-06-08 ASM 2.92 JMP/BRK Retest Proof

Purpose: prove the split mode-row scanner fixes the ASM 2.91 `BRK #$12`
lookup freeze and emits absolute `JMP` plus ABI-style `BRK #imm8`.

```text
>L G
L S19
L @2000
L OK=303D GO=2000
ASM RT PASTE
ASM> ORG $7340
OK PC=$7340
ASM> JMP $0012
OK PC=$7343
ASM> BRK #$12
OK PC=$7345
ASM> END
OK PC=$7345
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
>D 7340 7344
7340: 4C 12 00 00 12 | L....
>
```

Interpretation: the `$303D` paste image reaches `END` normally. The dump
matches `JMP $0012` as `4C 12 00` and `BRK #$12` as `00 12`.

## 2026-06-08 ASM 2.93 BRK Byte Alias Proof

Purpose: prove ASM accepts both HIMON/WDC byte trap spellings, `BRK $xx` and
`BRK #$xx`, with the same two-byte emission shape.

```text
>L G
L S19
L @2000
L OK=3040 GO=2000
ASM RT PASTE
ASM> ORG $7500
OK PC=$7500
ASM> BRK $12
OK PC=$7502
ASM> BRK #$13
OK PC=$7504
ASM> END
OK PC=$7504
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
>D 7500 750F
7500: 00 12 00 13 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>
```

Interpretation: `BRK $12` emits `00 12` and `BRK #$13` emits `00 13`.
The final PC `$7504` and dump prove both source forms are accepted by the
runtime paste image.

## 2026-06-08 ASM 2.94 JMP Indirect Proof

Purpose: prove ASM emits absolute indirect `JMP ($addr)` and W65C02 absolute
indexed indirect `JMP ($addr,X)`.

```text
>L G
L S19
L @2000
L OK=31B6 GO=2000
ASM RT PASTE
ASM> ORG $7510
OK PC=$7510
ASM> JMP ($0012)
OK PC=$7513
ASM> JMP ($0012,X)
OK PC=$7516
ASM> END
OK PC=$7516
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
>D 7510 7515
7510: 6C 12 00 7C 12 00 | l..|..
>
```

Interpretation: `JMP ($0012)` emits `6C 12 00`, and `JMP ($0012,X)` emits
`7C 12 00`. The final PC `$7516` proves both three-byte forms were accepted.

## 2026-06-08 ASM 2.95 Indirect Matrix Proof

Purpose: prove the W65C02 zero-page indirect opcode matrix for `ADC`, `SBC`,
`AND`, `ORA`, `EOR`, `CMP`, `LDA`, and `STA`.

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
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK

#GO# ENTRY=2000
RET A=0F X=F3 Y=0F P=75 S=FD NV-BdIzC
>D 7530 755F
7530: 61 12 71 12 E1 12 F2 12 | F1 12 21 12 32 12 31 12 | a.q.......!.2.1.
7540: 01 12 12 12 11 12 41 12 | 52 12 51 12 C1 12 D2 12 | ......A.R.Q.....
7550: D1 12 A1 12 B2 12 B1 12 | 81 12 92 12 91 12 00 00 | ................
```

The blank prompt after `ADC ($12,X)` means `ADC ($12)` was omitted from that
paste. A focused follow-up proved the missing row:

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
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK

#GO# ENTRY=2000
RET A=0F X=F3 Y=0F P=75 S=FD NV-BdIzC
>D 7555 7557
7555: 72 12 12 | r..
>
```

Interpretation: the first run proves the 23 emitted rows in the dump; the
second run proves `ADC ($12)` emits `72 12`. In the focused dump, only
`$7555-$7556` are part of the emitted instruction. `$7557` is beyond the
post-emission PC and retains prior memory.

## 2026-06-08 ASM 2.96 STA Absolute Y Proof

Purpose: prove the remaining legal `STA` addressing row, absolute indexed Y.

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
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
>D 7560 7562
7560: 99 12 00 | ...
>
```

Interpretation: `STA $0012,Y` emits `99 12 00`, and the final PC `$7563`
proves the three-byte absolute indexed Y form was accepted.

## 2026-06-08 ASM 2.97 Accumulator Absolute Y Proof

Purpose: prove the absolute indexed Y rows for `ORA`, `AND`, `EOR`, `ADC`,
`LDA`, `CMP`, and `SBC`.

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
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
>D 7570 7584
7570: 19 12 00 39 12 00 59 12 | 00 79 12 00 B9 12 00 D9 | ...9..Y..y......
7580: 12 00 F9 12 00 | .....
```

Interpretation: the PC advances from `$7570` to `$7585`, and the dump proves
all seven three-byte absolute indexed Y rows in order.

## 2026-06-08 ASM 2.98 WAI/STP Proof

Purpose: prove ASM emits the W65C02 implied low-power opcodes `WAI` and `STP`
without executing the generated bytes.

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
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
>D 7591 7592
7591: DB 00 | ..
>
>D 7590 7591
7590: CB DB | ..
>
```

Interpretation: `WAI` emits `CB` at `$7590`, `STP` emits `DB` at `$7591`,
and final PC `$7592` proves both one-byte implied forms were accepted. The
first dump started at `$7591`, proving `STP`; the follow-up dump included both
bytes.

## 2026-06-08 ASM 2.99 RMB/SMB Proof

Purpose: prove ASM emits W65C02 `RMB` and `SMB` bit-memory opcodes with the
new `bit,zp` operand classifier.

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
75A0: 37 12 B7 12 | 7...
>
```

Interpretation: `RMB 3,$12` emits `37 12`, `SMB 3,$12` emits `B7 12`, and
final PC `$75A4` proves both two-byte bit-memory forms were accepted. The
first line also proves optional whitespace after the comma is accepted.

## 2026-06-08 ASM 3.00 BBR/BBS Proof

Purpose: prove ASM emits W65C02 `BBR` and `BBS` bit-memory branch opcodes,
including forward-label relative fixups.

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
75B0: 3F 12 03 BF 12 01 EA EA | ?.......
```

Interpretation: `BBR 3,$12,T0` emits `3F 12 03`, `BBS 3,$12,T1` emits
`BF 12 01`, and final PC `$75B8` proves both three-byte bit-branch forms were
accepted. The resolved fixup rows show mode `$10`, sites `$75B2/$75B5`, and
bases `$75B3/$75B6`, matching `BIT_ZP_REL` relative-byte placement.

## 2026-06-08 ASM 3.01 Transactional Error Recovery Proof

Purpose: prove recoverable ASM line errors roll back PC/high-PC, leave the
session active, and let the paste wrapper reprompt instead of returning to
HIMON.

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

Interpretation: the out-of-range `BBR 3,$12,$9000` partially exercises the
bit-branch emit path, but the reported PC remains `$75C0` and the wrapper
immediately accepts another `ASM>` line. The accepted `NOP` advances to
`$75C1`, `END` finalizes cleanly with empty tables, and the dump proves the
accepted byte at `$75C0` is `EA`.

## 2026-06-08 ASM 3.02 Transactional Fixup Rollback Proof

Purpose: prove a failed labeled line that temporarily resolves an earlier
pending fixup restores both the fixup row state and the already-patched target
byte before returning to `ASM>`.

```text
>L G
L S19
L @2000
L OK=34F0 GO=2000
ASM RT PASTE
ASM> BNE FOO
OK PC=$7002
ASM> FOO STA #$12   ; FAILS AFTER RESOLVING FOO
ERR=$04 BAD MODE PC=$7002
ASM> FOO NOP        ; PROVES FIXUP WAS RESTORED AND CAN RESOLVE CLEANLY
OK PC=$7003
ASM>


>L G
L S19
L @2000
L OK=34F0 GO=2000
ASM RT PASTE
ASM> BNE FOO
OK PC=$7002
ASM> FOO STA #$12   ; FAILS AFTER RESOLVING FOO
ERR=$04 BAD MODE PC=$7002
ASM> FOO NOP        ; PROVES FIXUP WAS RESTORED AND CAN RESOLVE CLEANLY
OK PC=$7003
ASM> ORG 75DD0
ERR=$03 BAD OPER PC=$7003
ASM> END
OK PC=$7003
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7002  01 04 0E 0003 00  0000  FOO
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 07   00  7001 7002 FOO
ASM RT PASTE OK

#LOADGO# ENTRY=2000
RET A=0F X=C2 Y=0F P=75 S=FD NV-BdIzC
>G 2000
GO 2000
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

#GO# ENTRY=2000
RET A=0F X=C2 Y=0F P=75 S=FD NV-BdIzC
>D 75D0 75D2
75D0: D0 00 EA | ...
>
```

Interpretation: `FOO STA #$12` fails after the `FOO` label would resolve the
pending `BNE FOO`, but the next `FOO NOP` is accepted at the restored PC and
the final dump shows `D0 00 EA`. The resolved fixup row reports mode `$07`,
site `$75D1`, and base `$75D2`, proving the branch operand was restored and
then resolved cleanly. The intervening `ORG 75DD0` typo also proves a normal
non-`END` parser error continues to reprompt inside the same session.

## 2026-06-08 ASM 3.02 Long RAM7800 Paste/Run Proof

Purpose: prove the current runtime paste assembler can accept and run a useful
multi-section program, not only short opcode/proof snippets. The program
starts at `$6600`, uses resident `BIO_FTDI_WRITE_BYTE_BLOCK` for output,
reserves data/work bytes at `$7800-$7904`, fills `$7800-$78FF`, verifies the
pattern, prints a checksum/fail count, and emits a hex/ascii dump.

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $6600
OK PC=$6600
ASM> BRA MAIN
OK PC=$6602
ASM> HEX DB '0','1','2','3','4','5','6','7'
OK PC=$660A
ASM> DB '8','9','A','B','C','D','E','F'
OK PC=$6612
ASM> PHEX PHX
OK PC=$6613
... local hex/crlf helpers and main program accepted ...
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
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 6602  01 04 0E 0003 00  0000  HEX
01 01 6612  01 04 0E 0005 00  0000  PHEX
02 01 662B  01 04 0E 0015 00  0000  PCRLF
03 01 6636  01 04 0E 001A 00  0000  MAIN
04 01 667A  01 04 0F 0035 01  0039  FILL
05 01 668B  01 04 0F 003D 01  0047  VER
06 01 6696  01 04 0E 0042 00  0000  VOK
07 01 66EC  01 04 0F 0064 01  008D  DUMP
08 01 6707  01 04 0F 006E 01  0074  HLOOP
09 01 672A  01 04 0F 007C 01  0087  ALOOP
0A 01 673A  01 04 0E 0083 00  0000  ADOT
0B 01 673F  01 04 0E 0085 00  0000  ANEXT
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 07   00  6601 6602 MAIN
01 02 07   00  6692 6693 VOK
02 02 07   00  6730 6731 ADOT
03 02 07   00  6734 6735 ADOT
04 02 07   00  6739 673A ANEXT
ASM RT PASTE OK

#GO# ENTRY=2000
RET A=0F X=C2 Y=0F P=75 S=FD NV-BdIzC
>G 6600
GO 6600

RAM7800 TEST
SUM=80 FAIL=00

7800: A5 A4 A7 A6 A1 A0 A3 A2 AD AC AF AE A9 A8 AB AA |................
7810: B5 B4 B7 B6 B1 B0 B3 B2 BD BC BF BE B9 B8 BB BA |................
7820: 85 84 87 86 81 80 83 82 8D 8C 8F 8E 89 88 8B 8A |................
7830: 95 94 97 96 91 90 93 92 9D 9C 9F 9E 99 98 9B 9A |................
7840: E5 E4 E7 E6 E1 E0 E3 E2 ED EC EF EE E9 E8 EB EA |................
7850: F5 F4 F7 F6 F1 F0 F3 F2 FD FC FF FE F9 F8 FB FA |................
7860: C5 C4 C7 C6 C1 C0 C3 C2 CD CC CF CE C9 C8 CB CA |................
7870: D5 D4 D7 D6 D1 D0 D3 D2 DD DC DF DE D9 D8 DB DA |................
7880: 25 24 27 26 21 20 23 22 2D 2C 2F 2E 29 28 2B 2A |%$'&! #"-,/.)(+*
7890: 35 34 37 36 31 30 33 32 3D 3C 3F 3E 39 38 3B 3A |54761032=<?>98;:
78A0: 05 04 07 06 01 00 03 02 0D 0C 0F 0E 09 08 0B 0A |................
78B0: 15 14 17 16 11 10 13 12 1D 1C 1F 1E 19 18 1B 1A |................
78C0: 65 64 67 66 61 60 63 62 6D 6C 6F 6E 69 68 6B 6A |edgfa`cbmlonihkj
78D0: 75 74 77 76 71 70 73 72 7D 7C 7F 7E 79 78 7B 7A |utwvqpsr}|.~yx{z
78E0: 45 44 47 46 41 40 43 42 4D 4C 4F 4E 49 48 4B 4A |EDGFA@CBMLONIHKJ
78F0: 55 54 57 56 51 50 53 52 5D 5C 5F 5E 59 58 5B 5A |UTWVQPSR]\_^YX[Z
DONE

#GO# ENTRY=6600
RET A=0A X=00 Y=30 P=77 S=FD NV-BdIZC
>
```

Interpretation: `END` succeeded at `$7905`, all five remaining relative fixups
were resolved, and the emitted program returned normally after printing
`SUM=80 FAIL=00`. This is a hardware proof that the paste path can carry a
larger useful program when it avoids unresolved resident helpers and stays
within the current session table limits.

## 2026-06-09 ASM Current `$36B8` Fixup Rollback Retest

Purpose: retest the transactional fixup-patch rollback proof against the
current `asm-v1-runtime-paste-2000.s19` image. This verifies that the larger
paste runtime still restores the pending branch fixup after a failed defining
line, then resolves it cleanly when the corrected line is accepted.

```text
HIMON V 00.0608(1850)
>L G
L S19
L @2000
L OK=36B8 GO=2000
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

#LOADGO# ENTRY=2000
RET A=0F X=83 Y=0F P=75 S=FD NV-BdIzC
>D 75D0 75D2
75D0: D0 00 EA | ...
>
```

Interpretation: the current `$36B8` paste image matches the expected rollback
behavior. `FOO STA #$12` fails with `BAD MODE` at the restored `$75D2`, the
session remains active, `FOO NOP` is accepted at `$75D2`, and the final dump
shows the resolved branch plus `NOP` as `D0 00 EA`.

## 2026-06-09 ASM Current `$36B8` ASMTEST_3000 Paste/Run Proof

Purpose: prove the current `asm-v1-runtime-paste-2000.s19` image can still
paste, assemble, finalize, run, and verify the full `ASMTEST_3000` acceptance
sample. The source assembles at `$6800`, copies the 16-byte seed to
`$6900-$690F`, stores the XOR checksum at `$6910`, and returns by `RTS`.

```text
>G 2000
GO 2000
ASM RT PASTE
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
OK PC=$6802
ASM>         STZ SUM
OK PC=$6805
ASM> LOOP    LDA SEED,X
OK PC=$6808
ASM>         STA OUT,X
OK PC=$680B
ASM>         EOR SUM
OK PC=$680E
ASM>         STA SUM
OK PC=$6811
ASM>         INX
OK PC=$6812
ASM>         CPX #COUNT
OK PC=$6814
ASM>         BNE LOOP
OK PC=$6816
ASM>         RTS
OK PC=$6817
ASM>
ASM> SEED    DB $52,$2D,$59,$4F,$52,$53,$20,$41
OK PC=$681F
ASM>         DB $53,$4D,$20,$54,$45,$53,$54,$2E
OK PC=$6827
ASM>         END
OK PC=$6827
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 6900  01 04 17 0005 01  000B  OUT
01 01 6910  01 04 17 0006 03  0009  SUM
02 01 0010  00 00 17 0007 01  000F  COUNT
03 01 6800  01 04 0E 0008 00  0000  ASMTEST
04 01 6805  01 04 0F 000A 01  0010  LOOP
05 01 6817  01 04 0E 0012 00  0000  SEED
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 06   00  6806 6808 SEED
ASM RT PASTE OK

#GO# ENTRY=2000
RET A=0F X=83 Y=0F P=75 S=FD NV-BdIzC
>G 6800
GO 6800

#GO# ENTRY=6800
RET A=0F X=10 Y=30 P=77 S=FD NV-BdIZC
>D 6900 6910
6900: 52 2D 59 4F 52 53 20 41 | 53 4D 20 54 45 53 54 2E | R-YORS ASM TEST.
6910: 0F | .
>
```

Interpretation: `END` completed at `$6827`, the emitted program returned with
`A=$0F` and `X=$10`, and the post-run dump matches the 16-byte seed plus
checksum oracle. This completes the current `$36B8` full ASMTEST_3000 board
proof.

## 2026-06-09 ASM Current `$36B8` ASM_LINE_ECHO_7000 Paste/Run Proof

Purpose: prove the current `asm-v1-runtime-paste-2000.s19` image still accepts
and runs the saved `DOC/GUIDES/ASM/SAMPLES/ASM_LINE_ECHO_7000.asm` sample. The
sample assembles at `$7000`, uses `LINE EQU $7100`, calls resident input/output
helpers, echoes input after `=> `, and returns to HIMON when the operator types
`.` or `Q`.

```text
>G 2000
GO 2000
ASM RT PASTE
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
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7100  01 04 17 0005 05  000C  LINE
01 01 7002  01 04 0F 0007 02  0013  DONE
02 01 7003  01 04 0F 0008 03  000F  MAIN
03 01 7037  01 04 0F 001E 01  0027  ECHO
04 01 7048  01 04 0E 0025 00  0000  OUT
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 07   00  7001 7002 MAIN
01 02 07   00  703B 703C OUT
ASM RT PASTE OK

#GO# ENTRY=2000
RET A=0F X=83 Y=0F P=75 S=FD NV-BdIzC
>G 7000
GO 7000
? ?
=> ?
? ASM IS COOL
=> ASM IS COOL
? .

#GO# ENTRY=7000
RET A=00 X=00 Y=00 P=77 S=FD NV-BdIZC
>
```

Interpretation: the current `$36B8` paste runtime accepted the saved line-echo
sample through `END` at `$704E`, resolved the `MAIN` and `OUT` branch fixups,
and the emitted program echoed both `?` and `ASM IS COOL` before returning to
HIMON on `.`.

## 2026-06-09 ASM Current `$36B8` Bad-Input Status Proof

Purpose: prove the current `asm-v1-runtime-paste-2000.s19` image reports the
requested bad-input statuses at the paste prompt. The operator ran the cases in
fresh paste sessions. Earlier combined-paste attempts produced `GORG` and
HIMON `HSH_NF` boundary artifacts; those artifacts are not part of this proof.

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7000
OK PC=$7000
ASM> FOO NOP
OK PC=$7001
ASM> FOO NOP
ERR=$08 BAD SYM PC=$7001
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=93 Y=10 P=75 S=FD NV-BdIzC
```

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7000
OK PC=$7000
ASM> DC $12
ERR=$02 BAD DIR PC=$7000
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=93 Y=10 P=75 S=FD NV-BdIzC
```

```text
ASM> LDA 12
ERR=$05 BAD WIDTH PC=$7000
```

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7000
OK PC=$7000
ASM> LDA #$1234
ERR=$06 BAD RANGE PC=$7000
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=93 Y=10 P=75 S=FD NV-BdIzC
```

```text
ASM> STA #$12
ERR=$04 BAD MODE PC=$7000
```

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7000
OK PC=$7000
ASM> .LOOP NOP
ERR=$0A LOCAL NYI PC=$7000
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=93 Y=10 P=75 S=FD NV-BdIzC
```

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> BNE MISSING
OK PC=$7002
ASM> END
ERR=$09 BAD FIX PC=$7002
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 01 07   00  7001 7002 MISSING

#GO# ENTRY=2000
RET A=09 X=02 Y=70 P=74 S=FD NV-BdIzc
```

Interpretation: the current paste runtime reports all requested bad-input
classes by stable status byte and name: duplicate definition `BAD SYM`,
reserved directive `BAD DIR`, decimal memory operand `BAD WIDTH`, oversized
immediate `BAD RANGE`, unsupported mode `BAD MODE`, local label `LOCAL NYI`,
and unresolved final fixup `BAD FIX`.

## 2026-06-09 ASM Current `$36FD` Protected Output-Target Proof

Purpose: prove the new high output-target guard in
`asm-v1-runtime-paste-2000.s19`. ASM must reject source-level targets at
`$7E00+`, protecting the monitor/debugger/vector/I/O window from pasted source.

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

Interpretation: the board loaded the `$36FD` paste image and rejected
`ORG $7E00` with the expected stable status byte/name, `ERR=$06 BAD RANGE`, at
the unchanged paste-wrapper PC `$7000`. The initial `ASM> G 2000` was typed
after `L G` had already entered the paste wrapper, so it is a harmless prompt
mismatch and not part of the guard behavior under test. The session remained
usable and returned to HIMON on `.`.

## 2026-06-09 ASM Current `$377C` Mnemonic Boundary Preflight Proof

Purpose: prove the mnemonic emission boundary preflight in
`asm-v1-runtime-paste-2000.s19`. A multi-byte mnemonic beginning at the last
safe target byte `$7DFF` must fail before writing its opcode, leaving the
existing byte at `$7DFF` unchanged.

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

BRK 03 PC=C0D1
A=04 X=00 Y=7B P=77 S=FF NV-BdIZC
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
> 7DFF 7DFF
#10A4CBA2# HSH_NF!
>G 2000
GO 2000
ASM RT PASTE
ASM> DORG $7DFF
ERR=$01 BAD MNEM PC=$7000
ASM> LDA #$12
OK PC=$7002
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=57 Y=10 P=75 S=FD NV-BdIzC
> 7DFF 7DFF
#10A4CBA2# HSH_NF!
>
>
```

The final manual dump was typed after a stable HIMON prompt:

```text
>D 7DFF 7DFF
7DFF: EA | .
>
```

Interpretation: the first session planted `EA` at `$7DFF`. The second session
accepted `ORG $7DFF`, rejected `LDA #$12` with `ERR=$06 BAD RANGE PC=$7DFF`,
and stayed recoverable enough to exit on `.`. The final dump proves the failed
two-byte mnemonic did not overwrite the existing `EA` opcode. The dropped
leading `D` in the first dump attempts and the accidental `DORG` session are
prompt/paste-timing artifacts; the `DORG` session assembled `LDA #$12` at the
default `$7000`, unrelated to the `$7DFF` boundary proof.

## 2026-06-09 ASM Current `$3813` Directive Boundary Preflight Proof

Purpose: prove the directive emission boundary preflight in
`asm-v1-runtime-paste-2000.s19`. A multi-byte `DB` row or multi-byte `DS`
reservation beginning at the last safe target byte `$7DFF` must fail before
writing any bytes, leaving the existing byte at `$7DFF` unchanged.

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

Interpretation: the first session planted `EA` at `$7DFF`. The second session
accepted `ORG $7DFF`, then rejected both `DB $12,$34` and `DS 2,$00` with the
expected stable status byte/name, `ERR=$06 BAD RANGE`, at unchanged PC
`$7DFF`. The final dump proves neither directive overwrote the existing byte at
the boundary.

## 2026-06-09 ASM Current `$3813` Exact-Boundary Directive Positive Proof

Purpose: prove the companion positive edge for the directive boundary guard.
One-byte `DB` and one-byte `DS` beginning at the last safe target byte `$7DFF`
must succeed, write that byte, and advance PC/high-water to `$7E00`.

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

Interpretation: the already-loaded `$3813` paste image accepted exact-fit
one-byte directive emissions at `$7DFF`. Both `DB $A5` and `DS 1,$5C` advanced
to `PC=$7E00`, and the dumps prove each directive wrote the final legal target
byte without tripping the `$7E00+` guard.

## 2026-06-09 ASM Current `$3813` Two-Byte Exact-Fill Boundary Proof

Purpose: prove the two-byte exact-fill edge at the top of the protected target
window. `LDA #$12`, `DB $12,$34`, and `DS 2,$00` beginning at `$7DFE` must all
succeed, write `$7DFE-$7DFF`, and advance PC/high-water to `$7E00`.

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
ASM> DB $12,$34
OK PC=$7E00
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=EA Y=10 P=75 S=FD NV-BdIzC
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

#GO# ENTRY=2000
RET A=10 X=EA Y=10 P=75 S=FD NV-BdIzC
>D 7DFE 7DFF
7DFE: 00 00 | ..
>
```

Interpretation: the current `$3813` paste image accepted all three two-byte
exact-fill rows at `$7DFE` and advanced to `PC=$7E00`. The dumps prove the
expected bytes were written. The `HSH_NF` lines are HIMON prompt artifacts from
commands pasted while outside ASM; the later `G 2000` sessions contain the valid
assembler proof.

## 2026-06-09 ASM Current `$3813` Three-Byte Exact-Fill Boundary Proof

Purpose: prove the three-byte exact-fill edge at the top of the protected
target window. `LDA $0012`, `DB $12,$34,$56`, and `DS 3,$00` beginning at
`$7DFD` must all succeed, write `$7DFD-$7DFF`, and advance PC/high-water to
`$7E00`.

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

Interpretation: after a warm HIMON boot and reload of the `$3813` paste image,
all three three-byte exact-fill rows at `$7DFD` succeeded and advanced to
`PC=$7E00`. The dumps prove the expected bytes were written through the last
legal target address without tripping the `$7E00+` guard.

## 2026-06-09 ASM Current `$3813` Three-Byte Boundary-Cross Preflight Proof

Purpose: prove the crossing-by-one negative twin for three-byte rows at the top
of the protected target window. `LDA $0012`, `DB $12,$34,$56`, and `DS 3,$00`
beginning at `$7DFE` must all fail with `BAD RANGE`, leave PC/high-water at
`$7DFE`, and preserve the legal bytes at `$7DFE-$7DFF`.

```text
BRK 03 PC=C0D1
A=04 X=00 Y=7B P=77 S=FF NV-BdIZC
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

Interpretation: the `$3813` paste image accepted the two-byte sentinel at
`$7DFE`, then rejected all three crossing three-byte rows with
`ERR=$06 BAD RANGE PC=$7DFE`. Each corrected dump shows `6D 7E`, proving the
preflight rejected the whole row before overwriting the remaining legal target
bytes. The malformed `D 7DFEN7DFF` line is a manual dump typo, corrected by the
next command.

## 2026-06-09 ASM Current `$3813` Boundary Range-Error Recovery Proof

Purpose: prove that a boundary `BAD RANGE` leaves the same ASM paste session
recoverable at the restored PC. After a crossing `LDA $0012` fails at `$7DFE`,
a following legal `NOP` in the same session must assemble at `$7DFE`, advance
to `$7DFF`, and leave the `$7DFF` sentinel untouched.

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

Interpretation: after the crossing `LDA $0012` failed with
`ERR=$06 BAD RANGE PC=$7DFE`, the same ASM session accepted `NOP` at the
restored PC. The final dump proves only `$7DFE` changed to `EA`; `$7DFF`
remained the sentinel `7E`.

## 2026-06-09 ASM Current `$3813` Directive Range-Error Recovery Proof

Purpose: prove that directive boundary `BAD RANGE` failures leave the same ASM
paste session recoverable at the restored PC. After crossing `DB` and `DS`
rows fail at `$7DFE`, a following legal `NOP` in the same session must assemble
at `$7DFE`, advance to `$7DFF`, and leave the `$7DFF` sentinel untouched.

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

Interpretation: both directive failures reported `ERR=$06 BAD RANGE PC=$7DFE`
and left the same ASM session usable. The following `NOP` assembled at the
restored PC and changed only `$7DFE` to `EA`; the final-byte sentinels `$7F`
and `$81` remained unchanged. This board proof also covers comma-space
directive operands in the runtime paste path.

## 2026-06-09 ASM Current `$3813` Post-Exact-Fill Boundary Hard Stop

Purpose: prove that once exact-fill emission advances the active paste session
to `PC=$7E00`, further mnemonic and directive emission is rejected without
touching the final legal target byte.

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

Interpretation: `NOP` wrote the final legal byte and advanced to `PC=$7E00`.
The following `LDA #$12`, `DB $A5`, and `DS 1,$5C` attempts all failed with
`ERR=$06 BAD RANGE PC=$7E00`. The final dump proves `$7DFF` remained the
original `EA`.

## 2026-06-09 ASM Current `$3813` Post-Boundary `END` Finalization

Purpose: prove that the protected-limit hard stop does not poison finalization.
After exact-fill emission reaches `PC=$7E00` and further emits fail with
`BAD RANGE`, `END` must still succeed, print tables, and return
`ASM RT PASTE OK`.

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

Interpretation: `END` finalized cleanly from `PC=$7E00` after the preceding
hard-stop errors. Empty symbol/fixup tables printed normally, and the final
dump proves `$7DFF` remained the exact-fill `EA`.

## 2026-06-09 ASM Current `$3813` Post-Boundary Non-Emitting `EQU *`

Purpose: prove that non-emitting symbol definition remains legal after
exact-fill emission reaches `PC=$7E00`, while further emitting lines are still
blocked by the protected target guard.

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

Interpretation: after the session reached `PC=$7E00`, emitting lines still
failed with `BAD RANGE`, but `LIMIT EQU *` succeeded without writing memory.
The symbol table records `LIMIT=$7E00`, and the dump proves `$7DFF` remained
the exact-fill `EA`.

## 2026-06-09 ASM Current `$3813` Post-Boundary Label-Only Binding

Purpose: prove that label-only binding remains legal after exact-fill emission
reaches `PC=$7E00`, while further emitting lines remain blocked by the
protected target guard.

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

Interpretation: after reaching `PC=$7E00`, emitting lines still failed with
`BAD RANGE`, but `LIMIT EQU *` and label-only `AFTER` both succeeded without
writing memory. The symbol table records both at `7E00`, and the dump proves
`$7DFF` remained `EA`.

## 2026-06-09 ASM Current `$3813` Post-Boundary Duplicate-Label Recovery

Purpose: prove that duplicate label-only binding fails cleanly at the protected
limit while the original symbols, PC, and exact-fill byte remain intact enough
for `END` finalization.

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

Interpretation: the duplicate `AFTER` line failed with `BAD SYM` at
`PC=$7E00`, but the session still finalized. The symbol table contains the
original `LIMIT` and `AFTER` rows only, both at `7E00`, and `$7DFF` remained
`EA`.

## 2026-06-09 ASM Current `$3813` Post-Boundary Duplicate-`EQU` Recovery

Purpose: prove that duplicate `EQU` definition fails cleanly at the protected
limit while the original symbol, PC, and exact-fill byte remain intact enough
for `END` finalization.

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

Interpretation: the duplicate `LIMIT EQU *` line failed with `BAD SYM` at
`PC=$7E00`, but the session still finalized. The symbol table contains the
original `LIMIT` row only at `7E00`, and `$7DFF` remained `EA`. The initial
`ASM> L G` line was a prompt-mismatch artifact while already inside ASM and is
not part of the duplicate-`EQU` proof.

## 2026-06-09 ASM Current `$3813` Life Sample Paste Assembly

Purpose: prove that `DOC/GUIDES/ASM/SAMPLES/life-rjoined-6800.asm` assembles
end-to-end through the current ASM runtime paste path after replacing the
driver's repeated local routine references with fixed routine addresses.

This transcript proves paste/assembly only. Runtime output is proven by the
follow-on `G 6800` entry below.

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ; ASM V1 TINY LIFE. PASTE/LOAD THROUGH ASM RT PASTE.
OK PC=$7000
ASM>         ORG $6800
OK PC=$6800
ASM>         JMP $68E9
OK PC=$6803
ASM> CRLF    LDA #$0D
OK PC=$6805
ASM> INIT    LDX #$00
OK PC=$6810
ASM> COPY    LDX #$00
OK PC=$6823
ASM> REND    JSR CRLF
OK PC=$6837
ASM> STEP    LDX #$00
OK PC=$686E
ASM> STORE   STA $7840,X
OK PC=$68E3
ASM>         RTS
OK PC=$68E9
ASM>         JSR $680E
OK PC=$68EC
ASM>         JSR $6834
OK PC=$68EF
ASM>         JSR $686C
OK PC=$68F2
ASM>         JSR $6821
OK PC=$68F5
ASM>         JSR $6834
OK PC=$68F8
ASM>         JSR $686C
OK PC=$68FB
ASM>         JSR $6821
OK PC=$68FE
ASM>         JSR $6834
OK PC=$6901
ASM>         JSR $686C
OK PC=$6904
ASM>         JSR $6821
OK PC=$6907
ASM>         JSR $6834
OK PC=$690A
ASM>         RTS
OK PC=$690B
ASM>         ORG $7000
OK PC=$7000
...
ASM>         DB $01,$02,$03,$04,$05,$06,$07,$00
OK PC=$7200
ASM>         ORG $7200
OK PC=$7200
...
ASM>         DB $00,$00,$00,$00,$00,$00,$00,$00
OK PC=$7240
ASM>         ORG $7240
OK PC=$7240
ASM>         DB $2E,$23
OK PC=$7242
ASM>         END
OK PC=$7242
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 6803  01 04 0F 0006 03  001D  CRLF
01 01 680E  01 04 0E 000B 00  0000  INIT
02 01 6810  01 04 0F 000C 01  0011  ILOOP
03 01 6821  01 04 0E 0014 00  0000  COPY
04 01 6823  01 04 0F 0015 01  001A  CLOOP
05 01 6834  01 04 0E 001D 00  0000  REND
06 01 684F  01 04 0F 0029 01  0034  RROW
07 01 6853  01 04 0F 002B 01  0031  RCOL
08 01 686C  01 04 0E 0036 00  0000  STEP
09 01 686E  01 04 0F 0037 01  006B  SLOOP
0A 01 68D4  01 04 0E 0062 00  0000  BORN
0B 01 68DE  01 04 0E 0067 00  0000  LIVE
0C 01 68E0  01 04 0E 0068 00  0000  STORE
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 07   00  68C5 68C6 BORN
01 02 07   00  68CB 68CC LIVE
02 02 07   00  68CF 68D0 LIVE
03 02 07   00  68D3 68D4 STORE
04 02 07   00  68D9 68DA LIVE
05 02 07   00  68DD 68DE STORE
ASM RT PASTE OK

#GO# ENTRY=2000
RET A=0F X=DA Y=0F P=75 S=FD NV-BdIzC
>
```

Interpretation: the table-budgeted Life source now survives the full paste
assembly path. The final PC is `$7242`, the symbol table contains 13 rows, and
the fixup table contains the six expected resolved branch fixups. The earlier
`BAD_FIX` at the third named `JSR STEP` is avoided by the fixed-address driver.

## 2026-06-09 ASM Current `$3813` Life Sample Runtime

Purpose: prove that the ASM-built `life-rjoined-6800.asm` image runs from
`$6800`, prints the expected four 8x8 torus Life generations, and returns.

```text
>G 6800
GO 6800

G0
.#......
..#.....
###.....
........
........
........
........
........

G1
........
#.#.....
.##.....
.#......
........
........
........
........

G2
........
..#.....
#.#.....
.##.....
........
........
........
........

G3
........
.#......
..##....
.##.....
........
........
........
........

#GO# ENTRY=6800
RET A=0A X=3F Y=00 P=77 S=FD NV-BdIZC
>
```

Interpretation: the emitted program ran after the successful paste assembly,
rendered `G0` through `G3` exactly as expected for the seeded glider, and
returned through `RTS`.

## 2026-06-09 ASM Current `$3CAB` Interactive Life Reserved-`START` Attempt

Purpose: capture the first interactive/random `life-rjoined-6800.asm` board
attempt. The runtime paste image loaded correctly at `$2000` with size `$3CAB`,
but the sample used `START` as a label. `START` is a parked/reserved directive
word in ASM v1, so the line was rejected with `BAD DIR`.

```text
>L G
L S19
L @2000
L OK=3CAB GO=2000
ASM RT PASTE
ASM>         ORG $6800
OK PC=$6800
ASM>         JMP START
OK PC=$6803
...
ASM> RAND8   LDA $D4
OK PC=$692F
ASM>         ASL A
OK PC=$6930
ASM>         BCC R8S
OK PC=$6932
ASM>         EOR #$1D
OK PC=$6934
ASM> R8S     STA $D4
OK PC=$6936
ASM>         RTS
OK PC=$6937
ASM> START   JSR INIT
ERR=$02 BAD DIR PC=$6937
ASM>         JSR REND
OK PC=$693A
...
ASM>         END
ERR=$09 BAD FIX PC=$7246
ASM TABLES
SYMBOLS
...
12 01 693A  01 04 0F 0094 03  00A6  LOOP
13 01 693D  01 04 0F 0095 03  0097  GETKEY
...
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 01 04   00  6801 6803 R8S
...
>G 6800
GO 6800

BRK 00 PC=0003
A=01 X=30 Y=30 P=75 S=FB NV-BdIzC
>
```

Interpretation: the source after the rejected `START` line kept assembling,
but the top entry jump remained unresolved and `END` correctly failed with
`BAD FIX`. The follow-on `G 6800` ran an incomplete image. The sample now uses
`MAIN` for the entry label instead of the reserved word `START`.

## 2026-06-09 ASM Current `$3CAB` Interactive Life Fixup Slot-8 Wrap

Purpose: capture the second interactive/random `life-rjoined-6800.asm` board
attempt. This run proves that the `MAIN` entry-label rename cleared the parked
`START` directive collision, and exposes a separate fixup-name table bug when
the 16-row fixup ceiling is used.

```text
>L G
L S19
L @2000
L OK=3CAB GO=2000
ASM RT PASTE
ASM>         ORG $6800
OK PC=$6800
ASM>         JMP MAIN
OK PC=$6803
...
ASM> RAND8   LDA $D4
OK PC=$692F
ASM>         ASL A
OK PC=$6930
ASM>         BCC R8S
OK PC=$6932
ASM>         EOR #$1D
OK PC=$6934
ASM> R8S     STA $D4
OK PC=$6936
ASM>         RTS
OK PC=$6937
ASM> MAIN    JSR INIT
OK PC=$693A
...
ASM> DONE    RTS
OK PC=$6979
...
ASM>         ORG $7240
OK PC=$7240
ASM>         DB $2E,$23
OK PC=$7242
ASM>         DB $01,$00,$00,$00
OK PC=$7246
ASM>         END
ERR=$09 BAD FIX PC=$7246
ASM TABLES
SYMBOLS
...
11 01 6934  01 04 0E 0090 00  0000  R8S
12 01 6937  01 04 0E 0092 00  0000  MAIN
13 01 693D  01 04 0F 0094 03  00A6  LOOP
...
17 01 6978  01 04 0E 00AE 00  0000  DONE
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 01 04   00  6801 6803 R8S
...
08 02 07   00  6931 6932 R8S
...
0C 02 07   00  6962 6963 NEXTC
>G 6800
GO 6800

BRK 00 PC=0003
A=01 X=30 Y=30 P=75 S=FB NV-BdIzC
>
```

Interpretation: symbol row 12 correctly defines `MAIN=$6937`, so the source
syntax is no longer the blocker. Fixup row 0 should still name `MAIN`, but it
prints `R8S`, matching row 8. With `ASM_FIX_MAX=$10` and 32-byte fixup names,
row 8 starts exactly `$0100` bytes after row 0; the old fixup-name pointer math
kept only the low byte of `slot * $20`, so slot 8 overwrote slot 0 text. The
core now mirrors symbol-name pointer math by adding `slot >> 3` into the high
byte, and the runtime built after this fix is `$3CB1`.

## 2026-06-09 ASM Current `$3CB1` Interactive Life Paste and Random Run

Purpose: prove that the fixed ASM runtime paste image assembles the
interactive/random `life-rjoined-6800.asm` source end-to-end on hardware, keeps
fixup slot 0 and slot 8 names distinct, and runs the resulting program from
`$6800`.

```text
>L G
L S19
L @2000
L OK=3CB1 GO=2000
ASM RT PASTE
ASM>         ORG $6800
OK PC=$6800
ASM>         JMP MAIN
OK PC=$6803
...
ASM> MAIN    JSR INIT
OK PC=$693A
...
ASM> DONE    RTS
OK PC=$6979
...
ASM>         ORG $7240
OK PC=$7240
ASM>         DB $2E,$23
OK PC=$7242
ASM>         DB $01,$00,$00,$00
OK PC=$7246
ASM>         END
OK PC=$7246
ASM TABLES
SYMBOLS
...
11 01 6934  01 04 0E 0090 00  0000  R8S
12 01 6937  01 04 0E 0092 00  0000  MAIN
13 01 693D  01 04 0F 0094 03  00A6  LOOP
...
17 01 6978  01 04 0E 00AE 00  0000  DONE
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 04   00  6801 6803 MAIN
01 02 07   00  68C9 68CA BORN
02 02 07   00  68CF 68D0 LIVE
03 02 07   00  68D3 68D4 LIVE
04 02 07   00  68D7 68D8 STORE
05 02 07   00  68DD 68DE LIVE
06 02 07   00  68E1 68E2 STORE
07 02 04   00  6917 6919 RAND8
08 02 07   00  6931 6932 R8S
09 02 07   00  6954 6955 NEXTC
0A 02 07   00  695A 695B DONE
0B 02 07   00  695E 695F RANDC
0C 02 07   00  6962 6963 NEXTC
ASM RT PASTE OK
>G 6800
GO 6800

G0
.#......
..#.....
###.....
........
........
........
........
........

N/R/Q>
G0
.###....
........
........
..##..##
#......#
#.....#.
...#...#
#.......

N/R/Q>
G1
.##.....
..#.....
........
#.....##
##......
#.....#.
#......#
##.#....

N/R/Q>
G2
#..#....
.##.....
.......#
##.....#
.#....#.
........
........
.......#

N/R/Q>
G3
###.....
###.....
..#....#
.#....##
.#.....#
........
........
........

N/R/Q>
#GO# ENTRY=6800
RET A=51 X=3F Y=00 P=77 S=FD NV-BdIZC
>
```

Interpretation: `END` succeeds with fixup row 0 still naming `MAIN` and row 8
still naming `R8S`, proving the slot-8 fixup-name pointer carry on the board.
The program starts from `$6800`, renders the seeded `G0`, accepts `R` to fill a
random board, advances through `G1` to `G3`, and exits through `Q`/`RTS`.

## 2026-06-09 ASM Seed-Only Failure After STR8 HIMON-Only Update

This transcript proves that STR8 `U` / `UPDATE HIMON C000-EFFF` does not patch
the top-sector `$FFF8/$FFF9` join seed pocket. Seed-only ASM loads, but RJOIN
initialization fails before `BEGIN` because the seed bytes are still `FF FF`.

```text
HIMON IN 3S. S=STR8  3
STR8 V0 #5F6A0F7A
ROM $F000
? B E M U 0 1 2 G R
B0 HOLD
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
.........................................................................................................................................................................................................................................................................................................................................................................................
PROGRAM C000-EFFF? Y: y...
OK
STR8>
G HIMON
BOOT WARM

HIMON V 00.0609(1739)
>L G
L S19
L @2000
L OK=3ACA GO=2000
ASM RT PASTE
BEGIN=$0B

#LOADGO# ENTRY=2000
RET A=0B X=FF Y=FF P=F4 S=FD NV-BdIzc
>
```

Interpretation: the `$FFF8/$FFF9` flash-pocket seed policy is wrong for the
fixed `C000-EFFF` update path. Current seed-only ASM uses the RAM-published
joiner addr16 at `$7E00/$7E01`, which HIMON refreshes during common init.

## 2026-06-09 HIMON-Published RAM RJOIN Seed Proof

After moving the seed from the top flash pocket to HIMON-published RAM, the same
STR8 HIMON-only update path boots `HIMON V 00.0609(1904)`, loads ASM at `$2000`,
and reaches the paste prompt. Exiting with `.` returns cleanly, proving the
seed-only ASM can initialize RJOIN from RAM:

```text
HIMON V 00.0609(1904)
>L G
L S19
L @2000
L OK=3ACA GO=2000
ASM RT PASTE
ASM> .
ASM RT PASTE BYE

#LOADGO# ENTRY=2000
RET A=10 X=FC Y=10 P=75 S=FD NV-BdIzC
>D 7E00 7E01
7E00: 8E DE | ..
>
```

The first broad opcode/addressing paste after this proof failed at `STA OUT6`
with `ERR=$09 BAD FIX PC=$727B`. The symbol table already showed 32 named
operand references, so the failure was the ASM report-reference ceiling, not a
RJOIN seed failure. Current source raises that ceiling from `$20` to `$40`
without allocating new table storage.

## 2026-06-09 ASM RAM-Seed Opcode Addressing Smoke

This follow-on board run uses the same `HIMON V 00.0609(1904)` /
`ASM RT PASTE` image and a lower-reference opcode/addressing source. The source
assembles cleanly through `END`, resolves selected-byte fixups, bit-branch
fixups, absolute fixups, and a forward `JSR`, then executes from `$7200`.

```text
>G 2000
GO 2000
ASM RT PASTE
ASM>         ORG $7200
OK PC=$7200
ASM>         CLD
OK PC=$7201
ASM>         LDA #$00
OK PC=$7203
...
ASM>         JSR SUB
OK PC=$7281
ASM>         JMP ($7330)
OK PC=$7284
ASM>
ASM> JUMPED LDA #$4F
OK PC=$7286
ASM>         STA $7108
OK PC=$7289
ASM>         RTS
OK PC=$728A
ASM>
ASM>         JMP ($7330,X)
OK PC=$728D
ASM>
ASM> SUB     LDA #$99
OK PC=$728F
ASM>         STA $7107
OK PC=$7292
ASM>         RTS
OK PC=$7293
ASM>
ASM> FAIL    STA $7100
OK PC=$7296
ASM>         RTS
OK PC=$7297
ASM>         END
OK PC=$7297
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7223  01 04 0E 0012 00  0000  BIT1
01 01 722B  01 04 0E 0015 00  0000  BIT2
02 01 7284  01 04 0E 003E 00  0000  JUMPED
03 01 728D  01 04 0E 0042 00  0000  SUB
04 01 7293  01 04 0E 0045 00  0000  FAIL
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 02   01  720A 720B JUMPED
01 02 02   02  720F 7210 JUMPED
02 02 10   00  721D 721E BIT1
03 02 04   00  7221 7223 FAIL
04 02 10   00  7225 7226 BIT2
05 02 04   00  7229 722B FAIL
06 02 04   00  727F 7281 SUB
ASM RT PASTE OK

#GO# ENTRY=2000
RET A=0F X=EC Y=0F P=75 S=FD NV-BdIzC
>G 7200
GO 7200

#GO# ENTRY=7200
RET A=4F X=01 Y=44 P=74 S=FD NV-BdIzc
>D 7100 7108
7100: 80 33 22 33 44 55 81 99 | 4F | .3"3DU..O
```

Interpretation: the result matches the expected oracle. `$7100=$80` proves the
`SMB/RMB/BBS/BBR/TSB/TRB` path, `$7101-$7105` prove absolute indexed,
zero-page indexed, and zero-page indirect forms, `$7106=$81` proves accumulator
shift/rotate emission, `$7107=$99` proves the forward `JSR SUB`, and
`$7108=$4F` proves the absolute indirect jump through `$7330`.

## 2026-06-10 ASM RJOIN Hash Stats First Board Attempt

This board run used `HIMON V 00.0610(1344)` and the current `$3EF4`
`ASM RT PASTE` image. It usefully failed the first
`rjoin-hash-stats-7200.asm` sample shape. The source assembled code before
defining string/buffer labels and used double-quoted `DB` strings. That filled
all 24 fixup rows before `MAIN`, then hit `BAD OPER` on the unsupported string
literal form.

Relevant transcript excerpt:

```text
HIMON V 00.0610(1344)
>L G
L S19
L @2000
L OK=3EF4 GO=2000
ASM RT PASTE
ASM>         ORG $7200
OK PC=$7200
...
ASM> NIB     CMP #$0A
OK PC=$7279
ASM>         BCC .DIG
OK PC=$727B
ASM>         CLC
OK PC=$727C
ASM>         ADC #$37
OK PC=$727E
ASM>         BRA .OUT
OK PC=$7280
ASM> .DIG    CLC
OK PC=$7281
ASM>         ADC #'0'
OK PC=$7283
ASM> .OUT    JSR BIO_FTDI_WRITE_BYTE_BLOCK
OK PC=$7286
ASM>         RTS
OK PC=$7287

ASM> MAIN    LDX #<MTIT
ERR=$06 BAD RANGE PC=$7287
ASM>         LDY #>MTIT
ERR=$09 BAD FIX PC=$7287
...
ASM> MTIT    DB $0D,$0A,"RJOIN HASH STATS",$0D,$0A,0
ERR=$03 BAD OPER PC=$7500
ASM> MP      DB "TEXT> ",0
ERR=$03 BAD OPER PC=$7500
...
ASM>         END
ERR=$09 BAD FIX PC=$7640
```

The final table shows the fixup table was full at 24 rows (`00` through `17`)
before `MAIN` could add any string/buffer fixups:

```text
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 01 07   00  7201 7202 MAIN
01 01 02   01  7203 7204 MBYE
02 01 02   02  7205 7206 MBYE
03 02 06   00  7214 7216 BUF
04 02 07   00  7217 7218 .DONE
05 02 06   00  7220 7222 BUF
06 01 02   01  722F 7230 MSGL
07 01 02   02  7231 7232 MSGL
08 02 04   00  7238 723A HEX
09 01 02   01  723B 723C MSGX
0A 01 02   02  723D 723E MSGX
0B 02 04   00  7244 7246 HEX
0C 01 02   01  7247 7248 MSGH
0D 01 02   02  7249 724A MSGH
0E 02 04   00  7250 7252 HEX
0F 02 04   00  7255 7257 HEX
10 02 04   00  725A 725C HEX
11 02 04   00  725F 7261 HEX
12 02 02   01  7262 7263 MCR
13 02 02   02  7264 7265 MCR
14 02 04   00  726F 7271 NIB
15 02 04   00  7275 7277 NIB
16 02 07   00  727A 727B .DIG
17 02 07   00  727F 7280 .OUT

#LOADGO# ENTRY=2000
RET A=09 X=40 Y=76 P=74 S=FD NV-BdIzc
```

First fix applied: spell C strings as v1-safe byte/character-list `DB` rows
and move string/buffer definitions out of the forward-fixup path. The rerun
target is documented in
`DOC/GUIDES/ASM/SAMPLES/rjoin-hash-stats-7200-test.md`.

## 2026-06-10 ASM RJOIN Hash Stats Backward ORG Board Attempt

This board run used the byte/character-list `DB` spelling, but shaped the
source as data first at `$7500/$7600`, then `ORG $7200` for code. That exposed
the next assembler rule: `ORG` is monotonic in ASM v1. Moving backward from
`$7640` to `$7200` returns `BAD RANGE` and leaves `PC` at `$7640`, so the
program body assembled at `$7640`. Running `G 7200` then executed data bytes
instead of code.

Relevant transcript excerpt:

```text
ASM>         ORG $7500
OK PC=$7500
...
ASM>         ORG $7600
OK PC=$7600
ASM> BUF     DS $40
OK PC=$7640

ASM>         ORG $7200
ERR=$06 BAD RANGE PC=$7640
ASM> LEN     EQU $30
OK PC=$7640
...
ASM> MAIN    LDX #<MTIT
OK PC=$7642
...
ASM>         END
OK PC=$76F3
ASM RT PASTE OK

>G 7200
GO 7200
`......P`..i..`...U.....U.....U....0.
#GO# ENTRY=7200
RET A=36 X=30 Y=36 P=75 S=FD NV-BdIzC
```

The final source shape keeps the `$7200` entry first, defines data addresses
with `EQU` constants, emits the executable code, then moves forward to emit
the `$7500` strings and `$7600` buffer. That avoids both the fixup flood and
the backward `ORG`.

## 2026-06-10 ASM RJOIN Hash Stats Successful Board Proof

This board run re-entered the already-loaded current `$3EF4`
`ASM RT PASTE` image with `G 2000`, pasted the final
`rjoin-hash-stats-7200.asm` shape, assembled through `END`, then ran `G 7200`.
It proves the monotonic-`ORG`/`EQU` data-address shape, local labels, internal
fixups, and resident RJOIN calls used by the sample.

Table sanity from the accepted assembly:

```text
ASM>         ORG $7200
OK PC=$7200
...
ASM>         ORG $7500
OK PC=$7500
...
ASM>         ORG $7600
OK PC=$7600
ASM>         DS $40
OK PC=$7640
ASM>         END
OK PC=$7640
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7500  01 04 17 0004 02  000F  MTIT
01 01 7515  01 04 17 0005 02  0012  MP
02 01 751C  01 04 17 0006 02  004A  MSGL
03 01 7523  01 04 17 0007 02  004F  MSGX
04 01 7529  01 04 17 0008 02  0054  MSGH
05 01 752F  01 04 17 0009 02  005F  MCR
06 01 7532  01 04 17 000A 02  0023  MBYE
07 01 7600  01 04 17 000B 05  0015  BUF
08 01 0030  01 03 17 000C 03  0027  LEN
09 01 0031  01 03 17 000D 04  0028  XSUM
0A 01 0032  01 03 17 000E 02  002D  IDX
0B 01 7200  01 04 0E 000F 00  0000  MAIN
0C 01 722E  01 04 0E 0023 00  0000  DONE
0D 01 7236  01 04 0E 0027 00  0000  HASH
0E 01 725A  01 04 0F 0038 02  0046  NIB
0F 01 726A  01 04 0F 0041 06  004E  HEX
10 01 7278  01 04 0E 004A 00  0000  SHOW
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 07   00  721B 721C .BLANK
01 02 07   00  721F 7220 DONE
02 02 07   00  7223 7224 DONE
03 02 04   00  7225 7227 HASH
04 02 04   00  7228 722A SHOW
05 02 07   00  7243 7244 .DONE
06 02 07   00  725D 725E .DIG
07 02 07   00  7262 7263 .OUT
ASM RT PASTE OK
```

Runtime proof:

```text
>G 7200
GO 7200

RJOIN HASH STATS
TEXT> MAIN

LEN=04 XOR=0B FNV=96272888
TEXT> DONE

LEN=04 XOR=00 FNV=100E2FB1
TEXT> HASH

LEN=04 XOR=12 FNV=CC18DB11
TEXT> NIB

LEN=03 XOR=45 FNV=55DEB5BE
TEXT> HEX

LEN=03 XOR=55 FNV=818F192A
TEXT> SHOW

LEN=04 XOR=03 FNV=A699B27C
TEXT> HELLO

LEN=05 XOR=42 FNV=32543B0B
TEXT> R-YORS

LEN=06 XOR=68 FNV=E48E4383
TEXT> Q

BYE

#GO# ENTRY=7200
RET A=07 X=32 Y=07 P=75 S=FD NV-BdIzC
```

## 2026-06-10 ASM RJOIN Hash Stats Fresh Cold Full Runtime Proof

This board run started from the resident ROM entry with `G F000`, cold-booted
HIMON, reloaded the current `$3EF4` `ASM RT PASTE` image at `$2000`, pasted the
committed `rjoin-hash-stats-7200.asm` source, reached the live program prompt
after `G 7200`, produced the expected deterministic `HELLO` and `R-YORS`
hashes, then returned to HIMON on `Q`. This proves the clean
boot/load/assemble/full-runtime path for the committed sample shape.

Relevant transcript excerpt:

```text
HIMON V 00.0610(1344)
>G F000

GO F000
...
BOOT COLD
RAM ZERO OK

HIMON V 00.0610(1344)
>L G
L S19
L @2000
L OK=3EF4 GO=2000
ASM RT PASTE
...
ASM>         ORG $7200
OK PC=$7200
...
ASM>         END
OK PC=$7640
ASM TABLES
SYMBOLS
...
0B 01 7200  01 04 0E 000F 00  0000  MAIN
0C 01 722E  01 04 0E 0023 00  0000  DONE
0D 01 7236  01 04 0E 0027 00  0000  HASH
0E 01 725A  01 04 0F 0038 02  0046  NIB
0F 01 726A  01 04 0F 0041 06  004E  HEX
10 01 7278  01 04 0E 004A 00  0000  SHOW
FIXUPS
...
00 02 07   00  721B 721C .BLANK
01 02 07   00  721F 7220 DONE
02 02 07   00  7223 7224 DONE
03 02 04   00  7225 7227 HASH
04 02 04   00  7228 722A SHOW
05 02 07   00  7243 7244 .DONE
06 02 07   00  725D 725E .DIG
07 02 07   00  7262 7263 .OUT
ASM RT PASTE OK

#LOADGO# ENTRY=2000
RET A=0F X=E2 Y=0F P=75 S=FD NV-BdIzC
>G 7200
GO 7200

RJOIN HASH STATS
TEXT>
HELLO

LEN=05 XOR=42 FNV=32543B0B
TEXT> R-YORS

LEN=06 XOR=68 FNV=E48E4383
TEXT> Q

BYE

#GO# ENTRY=7200
RET A=07 X=32 Y=07 P=75 S=FD NV-BdIzC
>
```

## 2026-06-10 ASM Local Label Stress Hardware Proof

This board run re-entered the current `$3EF4` `ASM RT PASTE` image with
`G 2000`, pasted `local-label-stress-7400.asm`, assembled through `END`, ran
`G 7400`, and dumped the expected runtime oracle at `$7100-$710C`. It proves
the current local-label ceiling and scoping behavior on hardware: eight local
rows under `MAIN`, `.LOOP`/`.DONE` name reuse under separate global scopes, the
alternate `?NAME` prefix, and forward/backward local branches. No resident calls
are used by this sample.

Accepted table excerpt:

```text
ASM>         ORG $7400
OK PC=$7400
...
ASM> .ABCDEFGHIJKLMN
OK PC=$7439
...
ASM> ?FWD    BRA ?LOOP
OK PC=$7489
ASM>         END
OK PC=$7489
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7400  01 04 0E 0004 00  0000  MAIN
01 01 744D  01 04 0E 0026 00  0000  ONE
02 01 7462  01 04 0E 0030 00  0000  TWO
03 01 7477  01 04 0E 003A 00  0000  ALT
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 07   00  7401 7402 .A
01 02 07   00  740E 740F .B
02 02 07   00  7415 7416 .C
03 02 07   00  741C 741D .D
04 02 07   00  7423 7424 .E
05 02 07   00  742A 742B .F
06 02 07   00  7431 7432 .G
07 02 07   00  7438 7439 .ABCDEFGHIJKLMN
08 02 04   00  743F 7441 ONE
09 02 04   00  7442 7444 TWO
0A 02 04   00  7445 7447 ALT
0B 02 07   00  745B 745C .DONE
0C 02 07   00  746B 746C .DONE
0D 02 07   00  747B 747C ?FWD
ASM RT PASTE OK
```

Runtime oracle:

```text
#GO# ENTRY=2000
RET A=0F X=E2 Y=0F P=75 S=FD NV-BdIzC
>G 7400
GO 7400

#GO# ENTRY=7400
RET A=5C X=03 Y=00 P=75 S=FD NV-BdIzC
>D 7100 710C
#6999B497# HSH_NF!
>D 7100 710C
7100: A1 B2 C3 D4 E5 F6 07 8F | 03 00 2A 03 5C | ..........*.\
>
```

## 2026-06-10 ASM RJOIN Hex-Nibble Hardware Proof

This board run flashed the current HIMON update, booted `HIMON V
00.0610(1937)`, loaded the current `$3EED` `ASM RT PASTE` image, and assembled
a small hex-heavy sample at `$7600`. It proves the `ASM_HEX_TO_NIBBLE ->
UTL_HEX_ASCII_TO_NIBBLE` conversion on hardware: ASM now resolves hash
`$ADD714B1` through RJOIN at startup, then uses the resident utility for `$`
hex operands and `DB $xx` data.

Accepted assembly excerpt:

```text
HIMON V 00.0610(1937)
>L G
L S19
L @2000
L OK=3EED GO=2000
ASM RT PASTE
ASM>         ORG $7600
OK PC=$7600
ASM> OUT0    EQU $7100
OK PC=$7600
ASM> OUT1    EQU $7101
OK PC=$7600
ASM> OUT2    EQU $7102
OK PC=$7600
ASM>         LDA #$0F
OK PC=$7602
ASM>         STA OUT0
OK PC=$7605
ASM>         LDA #$A5
OK PC=$7607
ASM>         STA OUT1
OK PC=$760A
ASM>         LDX #$09
OK PC=$760C
ASM>         STX OUT2
OK PC=$760F
ASM>         RTS
OK PC=$7610
ASM> DATA    DB $00,$09,$0A,$0F,$A5
OK PC=$7615
ASM>         END
OK PC=$7615
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7100  01 04 17 0002 01  0006  OUT0
01 01 7101  01 04 17 0003 01  0008  OUT1
02 01 7102  01 04 17 0004 01  000A  OUT2
03 01 7610  01 04 0E 000C 00  0000  DATA
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
```

Runtime oracle:

```text
#LOADGO# ENTRY=2000
RET A=0F X=D5 Y=0F P=75 S=FD NV-BdIzC
>G 7600
GO 7600

#GO# ENTRY=7600
RET A=A5 X=09 Y=30 P=75 S=FD NV-BdIzC
>D 7100 FF
7100: 0F A5 09 D4 E5 F6 07 8F | 03 00 2A 03 5C 00 00 00 | ..........*.\...
...
>D 7610 761F
7610: 00 09 0A 0F A5 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>
```

## 2026-06-10 ASM RJOIN Hex-Nibble Negative Range Check

This follow-up used the same current `$3EED` `ASM RT PASTE` image and verified
the oversized immediate failure path after the resident hex-nibble conversion.
`LDA #$1234` reports `BAD RANGE`, not `BAD WIDTH`, because the immediate byte
mode is known and the parsed value is outside the allowed range.

Transcript:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM>         ORG $7620
OK PC=$7620
ASM>         LDA #$1234
ERR=$06 BAD RANGE PC=$7620
ASM> END
OK PC=$7620
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK

#GO# ENTRY=2000
RET A=0F X=D5 Y=0F P=75 S=FD NV-BdIzC
>
```

## 2026-06-10 HIMON K05 Service Record Listing

After the selected K01-to-K05 promotion, the board `# K=5` listing confirmed
the active HIMON resident records expose the intended short text names.

Transcript:

```text
># K=5
HASH     ENTRY K TEXT
270C92A5 C1E0 05 "[TEXT]" -> #5F6A0F7A# STR8 MATCH!
D60C1322 C31F 05 S: SEARCH FROM RAM TO HASHED HIMON CMD
A9AF15F7 DE8E 05 HASH ACQUIRE
4B9AEE1E E113 05 HASH OPEN
A8802314 E18D 05 HASH MIX
20285B85 E2E8 05 READ BYTE
379FE930 E307 05 WRITE BYTE
43621C9C E4C1 05 READ CH
F91947F8 E4D8 05 READ ECHO
B85E3F10 E4E8 05 READ COOK
ADD714B1 E5C3 05 HEX NIB
7142DD21 E808 05 BYTE HEX
D4C88B87 E82E 05 NIB HEX
E2DD10AF D4D8 05 READ LINE
AEFA0F42 E5AF 05 PUT CSTR
>
```

## 2026-06-10 ASM Flash `$8000` Life Paste/Run Proof

This board run proves the first flash-resident ASM image loaded by current
HIMON `L F`, entered at its S9/GO address `$800C`, accepted a large pasted
program, resolved resident RJOIN names, emitted code/data into RAM, and ran a
real interactive program from `$2000`.

Scope of proof:

```text
HIMON:       V 00.0610(2014)
flash load:  L F at $8000
write size:  WR=2D67
entry:       GO=800C, run by G 800C
ASM image:   flash wrapper prints ASM FLASH / ASM>
program:     tiny interactive Life, relocated to ORG $2000
data:        neighbor tables at $7000-$71FF, seed/tile data at $7200-$7245
runtime:     G 2000 prints boards and accepts N/R/Q input
```

This proves the `L F` fixed-address flash runtime path and the flash/RAM split
for substantial work. This first direct-entry transcript does not by itself
prove the HIMON `ASM` hash command; the follow-up proof below closes that path.

Flash load and flash-wrapper entry:

```text
HIMON V 00.0610(2014)
>D 8000 FF
8000: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
...
80F0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
>L F
L F S19
L @8000
LF OK WR=2D67 GO=800C
>G 800C
GO 800C
ASM FLASH
ASM>
```

The pasted program started at `$2000` and used resident names for output and
input:

```text
ASM> ; ASM V1 TINY INTERACTIVE LIFE. PASTE VIA ASM RT PASTE.
OK PC=$2000
ASM> ; RUN G 6800. N OR SPACE=NEXT, R=RANDOM, Q=QUIT.
OK PC=$2000
ASM> ; RANDOM SEED STIRS WHILE WAITING FOR A KEY.
OK PC=$2000
ASM> ; USES RJOIN PIN READ AND BIO WRITE BYTE ROUTINES.
OK PC=$2000
ASM>
ASM>         ORG $2000
OK PC=$2000
ASM>         JMP MAIN
OK PC=$2003
...
ASM> GETKEY  INC $D4
OK PC=$2142
ASM>         JSR PIN_FTDI_READ_BYTE_NONBLOCK
OK PC=$2145
...
ASM> DONE    RTS
OK PC=$2179
ASM>
ASM>         ORG $7000
OK PC=$7000
...
ASM>         ORG $7240
OK PC=$7240
ASM>         DB $2E,$23
OK PC=$7242
ASM>         DB $01,$00,$00,$00
OK PC=$7246
ASM>
ASM>         END
OK PC=$7246
ASM TABLES
```

The final table shows 24 globals and 13 internal fixups; external resident
calls did not create unresolved fixups:

```text
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 2003  01 04 0F 0007 04  0020  CRLF
01 01 200E  01 04 0F 000C 01  0092  INIT
02 01 2010  01 04 0F 000D 01  0012  ILOOP
03 01 2025  01 04 0F 0017 01  00AB  COPY
04 01 2027  01 04 0F 0018 01  001D  CLOOP
05 01 2038  01 04 0F 0020 03  0093  REND
06 01 2053  01 04 0F 002C 01  0037  RROW
07 01 2057  01 04 0F 002E 01  0034  RCOL
08 01 2070  01 04 0F 0039 01  00AA  STEP
09 01 2072  01 04 0F 003A 01  006E  SLOOP
0A 01 20D8  01 04 0E 0065 00  0000  BORN
0B 01 20E2  01 04 0E 006A 00  0000  LIVE
0C 01 20E4  01 04 0E 006B 00  0000  STORE
0D 01 20ED  01 04 0F 0070 01  0094  PROMPT
0E 01 2114  01 04 0F 0080 01  00A7  RAND
0F 01 2116  01 04 0F 0081 01  0089  RLOOP
10 01 212D  01 04 0E 008C 00  0000  RAND8
11 01 2134  01 04 0E 0090 00  0000  R8S
12 01 2137  01 04 0E 0092 00  0000  MAIN
13 01 213D  01 04 0F 0094 03  00A6  LOOP
14 01 2140  01 04 0F 0095 03  0097  GETKEY
15 01 2165  01 04 0E 00A7 00  0000  RANDC
16 01 216D  01 04 0E 00AA 00  0000  NEXTC
17 01 2178  01 04 0E 00AE 00  0000  DONE
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 04   00  2001 2003 MAIN
01 02 07   00  20C9 20CA BORN
02 02 07   00  20CF 20D0 LIVE
03 02 07   00  20D3 20D4 LIVE
04 02 07   00  20D7 20D8 STORE
05 02 07   00  20DD 20DE LIVE
06 02 07   00  20E1 20E2 STORE
07 02 04   00  2117 2119 RAND8
08 02 07   00  2131 2132 R8S
09 02 07   00  2154 2155 NEXTC
0A 02 07   00  215A 215B DONE
0B 02 07   00  215E 215F RANDC
0C 02 07   00  2162 2163 NEXTC
ASM FLASH OK

#GO# ENTRY=800C
RET A=0A X=09 Y=00 P=75 S=FD NV-BdIzC
```

Runtime proof from `$2000`:

```text
>G 2000
GO 2000

G0
.#......
..#.....
###.....
........
........
........
........
........

N/R/Q>
G0
.......#
....###.
.#......
...###..
.....##.
....####
##..##..
..##..#.

N/R/Q>
G1
...##..#
.....##.
...#..#.
....###.
...#...#
#......#
###.....
########

...

N/R/Q>
G>
.#......
#.....##
#....#..
#.......
.#....#.
.##.....
..#....#
..#....#

N/R/Q>
#GO# ENTRY=2000
RET A=51 X=3F Y=01 P=77 S=FD NV-BdIZC
>
```

## 2026-06-10 ASM Flash `$8000` Hash-Command Life Proof

This follow-up cold-boot proof closes the remaining command-dispatch gap from
the first flash `$8000` Life proof. HIMON found the flash ASM FNV command record
and entered the same flash-resident ASM image through the `ASM` command rather
than by `G 800C`.

Scope of proof:

```text
HIMON:       V 00.0610(2014), cold boot after STR8 countdown
entry:       HIMON command `ASM`
ASM image:   flash wrapper prints ASM FLASH / ASM>
program:     same tiny interactive Life source, relocated to ORG $2000
result:      ASM FLASH OK, then G 2000 prints the initial Life board
```

Cold boot and command entry:

```text
HIMON IN 3S. S=STR8  3 2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0610(2014)
>
>ASM
ASM FLASH
ASM>
```

The flash ASM session accepted the Life source at `$2000`:

```text
ASM> ; ASM V1 TINY INTERACTIVE LIFE. PASTE VIA ASM RT PASTE.
OK PC=$2000
ASM> ; RUN G 6800. N OR SPACE=NEXT, R=RANDOM, Q=QUIT.
OK PC=$2000
ASM> ; RANDOM SEED STIRS WHILE WAITING FOR A KEY.
OK PC=$2000
ASM> ; USES RJOIN PIN READ AND BIO WRITE BYTE ROUTINES.
OK PC=$2000
ASM>
ASM>         ORG $2000
OK PC=$2000
...
ASM> GETKEY  INC $D4
OK PC=$2142
ASM>         JSR PIN_FTDI_READ_BYTE_NONBLOCK
OK PC=$2145
...
ASM> DONE    RTS
OK PC=$2179
ASM>
ASM>         ORG $7000
OK PC=$7000
...
ASM>         ORG $7240
OK PC=$7240
ASM>         DB $2E,$23
OK PC=$7242
ASM>         DB $01,$00,$00,$00
OK PC=$7246
ASM>
ASM>         END
OK PC=$7246
ASM TABLES
```

Final tables again showed 24 globals and 13 internal fixups, ending with a
clean flash-wrapper success:

```text
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 2003  01 04 0F 0007 04  0020  CRLF
01 01 200E  01 04 0F 000C 01  0092  INIT
...
17 01 2178  01 04 0E 00AE 00  0000  DONE
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 04   00  2001 2003 MAIN
01 02 07   00  20C9 20CA BORN
...
0C 02 07   00  2162 2163 NEXTC
ASM FLASH OK
>
```

Runtime start from `$2000`:

```text
>G 2000
GO 2000

G0
.#......
..#.....
###.....
........
........
........
........
........

N/R/Q>
```

## 2026-06-10 ASM Flash Biorhythm Resident-JMP Fixup Lesson

This failed board attempt is important because it separated two different
causes of `BAD FIX`. The first biorhythm source shape really did fill the
fixup table. The later helper-first source did not: it reached `END` with only
19 of 24 fixup rows in use, but still failed because the flashed ASM image only
tried resident EXEC lookup for direct `JSR name`, not direct `JMP name`.

Observed setup:

```text
entry:     >ASM
image:     flash ASM prints ASM FLASH / ASM>
program:   DOC/GUIDES/ASM/SAMPLES/biorhythm-2000.asm helper-first shape
result:    END returned ERR=$09 BAD FIX PC=$2640
fixups:    rows 00-12 only, so not table-full
```

The unresolved rows included resident tail-call wrappers:

```text
01 01 04   00  2045 2047 BIO_FTDI_WRITE_BYTE_BLOCK
02 01 04   00  204C 204E BIO_FTDI_PUT_CSTR
```

Those came from:

```asm
OUTA    JMP BIO_FTDI_WRITE_BYTE_BLOCK
CRLF    ...
        JMP BIO_FTDI_PUT_CSTR
```

The fix is twofold in the next host image:

```text
ASM_FIX_MAX grows from $18 to $20, raising fixups from 24 to 32 rows.
Direct resident JMP name now uses the same RJOIN lookup path as direct JSR name.
```

Diagnostic rule captured from this failure:

```text
BAD FIX with FIXUPS at max      likely table full
BAD FIX with FIXUPS below max   inspect pending rows; unresolved resident
                                operands may be ineligible in that image
```

The updated host gate `make -C SRC asm-test` proves both direct resident `JSR`
and resident tail `JMP` through the runtime smoke wrapper. The current
`asm-v1-flash-8000.s19` image is expected to load as `WR=2D6B GO=800C`.

## 2026-06-10 ASM Flash Biorhythm Resident-JMP Success

This follow-up proves the fixup lesson above on hardware. The board flashed the
current `$8000` ASM image, entered it through the HIMON `ASM` command, accepted
the helper-first biorhythm source, and ran the emitted `$2000` program.

Scope of proof:

```text
loader:    L F fixed-address flash load
ASM image: asm-v1-flash-8000.s19, WR=2D6B GO=800C
entry:     HIMON command `ASM`
program:   DOC/GUIDES/ASM/SAMPLES/biorhythm-2000.asm
result:    ASM FLASH OK, then G 2000 prints biorhythm-style charts
inputs:    172, 173, 174, 175, Q
```

Flash load and ASM command entry:

```text
>L F
L F S19
L @8000
LF OK WR=2D6B GO=800C
>ASM
ASM FLASH
ASM>
```

The flash ASM session accepted the program through `END`:

```text
ASM>         END
OK PC=$2640
ASM TABLES
...
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 04   00  2001 2003 MAIN
01 02 07   00  2051 2052 .HEX
...
10 02 07   00  2183 2184 .BAD
ASM FLASH OK
```

The important resident-tail-call evidence is that the previous pending rows for
`BIO_FTDI_WRITE_BYTE_BLOCK` and `BIO_FTDI_PUT_CSTR` are gone. The wrappers:

```asm
OUTA    JMP BIO_FTDI_WRITE_BYTE_BLOCK
CRLF    ...
        JMP BIO_FTDI_PUT_CSTR
```

resolved at parse time through the new direct resident `JMP name` path, so no
resident fixup remained at `END`.

Runtime proof:

```text
>G 2000
GO 2000

BIORHYTHM
DAY 0-255 OR Q> 172

DAY $AC
P 0 ...........*...........
E + ....*.........|.............
I + .......*........|................
DAY 0-255 OR Q> 173

DAY $AD
P - ...........|*..........
E + .....*........|.............
I + ........*.......|................
DAY 0-255 OR Q> 174

DAY $AE
P - ...........|.*.........
E + ......*.......|.............
I + .........*......|................
DAY 0-255 OR Q> 175

DAY $AF
P - ...........|..*........
E + .......*......|.............
I + ..........*.....|................
DAY 0-255 OR Q> Q

BYE

#GO# ENTRY=2000
RET A=07 X=28 Y=07 P=75 S=FD NV-BdIzC
>
```

## 2026-06-11 HIMON Legacy A Removed

After removing the legacy HIMON `A` mini-assembler command from the command
catalog, the board now reports the expected hash-not-found result:

```text
>A
#C40BF6CC# HSH_NF!
>
```

This proves `A` is no longer a built-in HIMON executable record. Assembly now
belongs to the flash-resident `ASM` command path.

## 2026-06-15 ASM Flash PACK40 Interactive Success

This proves the ASM-native interactive PACK40 sample on hardware after retuning
the flash ASM tables toward fixup-heavy paste sources.

Scope of proof:

```text
STR8 update: UPDATE HIMON C000-EFFF, OK
HIMON:       V 00.0615(2131)
ASM image:   asm-v1-flash-8000.s19, WR=2E92 GO=800C
program:     DOC/GUIDES/ASM/SAMPLES/pack40-interactive-2000.a
tables:      ASM_SYM_MAX=$28 ASM_FIX_MAX=$60 ASM_REF_MAX=$A0
result:      ASM FLASH OK, then G 2000 interactive pack/unpack success
```

The ASM paste accepted the whole source through `END`:

```text
ASM> ; NEEDS ASM TABLES SYM/FIX/REF/LOCAL $28/$60/$A0/$10.
OK PC=$2000
...
ASM> RUN     LDX #<MTIT
OK PC=$238B
...
ASM> .DONE   RTS
OK PC=$23C9
ASM>
ASM>         END
OK PC=$23C9
ASM TABLES
SYMBOLS
...
1D 01 2389  01 04 0E 01D2 00  0000  RUN
FIXUPS
...
49 02 07   00  23B9 23BA .BAD
ASM FLASH OK
```

The important table evidence is 30 global symbols and 74 resolved fixup rows,
with no `ERR=` and no unresolved resident calls left at `END`.

Runtime proof:

```text
>G 2000
GO 2000

PACK40 INT
P PACK U UNPACK Q> P
TEXT> HELLO

PACKED=D432584D
P PACK U UNPACK Q> U
HEX> D432584D

TEXT=HELLO
P PACK U UNPACK Q> P
TEXT> _

PACKED=40E7
P PACK U UNPACK Q> U
HEX> 40E7

TEXT=_
P PACK U UNPACK Q> P
TEXT> HELLO_

PACKED=D4327D4D
P PACK U UNPACK Q> U
HEX> D4327D4D

TEXT=HELLO_
P PACK U UNPACK Q> P
TEXT> HELLO_GOODBYE

PACKED=D4327D4D272E6919401F
P PACK U UNPACK Q> U
HEX> D4327D4D272E6919401F

TEXT=HELLO_GOODBYE
P PACK U UNPACK Q> Q

#GO# ENTRY=2000
RET A=51 X=00 Y=00 P=77 S=FD NV-BdIZC
>
```

Negative-path observations in the same run:

```text
menu input HELLO        -> ?
empty pack input        -> ?
invalid ':' in HELLO:   -> ?
empty unpack hex input  -> ?
```

The `U` menu path now prompts `HEX>` and reaches `UNPIT`, proving the prior bad
fall-through into `PACKIT` was table/fixup pressure from the earlier image.

Post-return observation from the same board session: after `Q` inside the
PACK40 app returned cleanly through `#GO# ENTRY=2000`, a later top-level
`BRK 03 PC=C0DB` appeared:

```text
#GO# ENTRY=2000
RET A=51 X=00 Y=00 P=77 S=FD NV-BdIZC
>

BRK 03 PC=C0DB
A=04 X=00 Y=7B P=77 S=FF NV-BdIZC
>
```

In the current `himon-c000.map`, `MAIN_LOOP=$C0BF` and
`MAIN_HAVE_LINE=$C0DE`; `$C0DB` is the saved PC after the intentional `BRK $03`
in the top-level HIMON input-abort path. This is a HIMON prompt/abort context,
not PACK40 code running after return. At the HIMON `>` prompt, `Q` is the
quiesce command (`SEI`/`WAI`/re-enter), not an application quit command; without
a waking interrupt it can look like a hang and require reset.

## 2026-06-15 ASM Directive Smoke First Board Run

The first `DOC/GUIDES/ASM/SAMPLES/asm-directives-smoke-3000.a` board paste
proved the basic `EQU`, `DB`, `DW`, `DS`, forward operand fixup, and runtime
copy path, but also exposed one current DB selector gap.

The failing line:

```text
ASM>         DB <DATA,>DATA,<ENDD,>ENDD
ERR=$05 BAD WIDTH PC=$3023
```

The session continued, accepted `END`, and ran:

```text
ASM FLASH OK
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=19 Y=30 P=F5 S=FD NV-BdIzC
>D 3100 3121
3100: A5 5A 52 59 34 12 12 00 | 0B 00 41 00 EE FF EE FF
3110: 44 42 44 57 00 00 00 00 | 00 00 00 00 00 00 00 00
3120: AC 00
```

This proves the code path and status byte, plus the stable directive bytes up
through `DS` and trailing `DB`. It does not prove `DB <pc_label`, because that
line failed and emitted nothing. The sample source was revised to use
`DW DATA,ENDD` after both labels are known for the address-word check.

## 2026-06-16 ASM Directive Smoke Revised Board Success

The corrected `DOC/GUIDES/ASM/SAMPLES/asm-directives-smoke-3000.a` board paste
proves the intended compact directive smoke:

```text
ASM> ; TABLE BUDGET: 14 GLOBALS, 3 FIXUPS, 2 LOCALS.
...
ASM> RUN     BRA .COPY
OK PC=$3002
ASM>         DB $EA
OK PC=$3003
ASM> .COPY   LDX #$00
OK PC=$3005
...
ASM> ADDRS   DW DATA,ENDD
OK PC=$3033
ASM>
ASM>         END
OK PC=$3033
ASM TABLES
SYMBOLS
...
0D 01 302F  01 04 0E 0022 00  0000  ADDRS
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 07   00  3001 3002 .COPY
01 02 06   00  3006 3008 DATA
02 02 04   00  3011 3013 MARK
ASM FLASH OK
```

Runtime proof:

```text
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=19 Y=30 P=F5 S=FD NV-BdIzC
>D 3100 31FF
3100: A5 5A 52 59 34 12 12 00 | 0B 00 41 00 EE FF EE FF
3110: 44 42 44 57 00 1A 30 2E | 30 00 00 00 00 00 00 00
3120: AC 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00
```

This proves current ASM support for `EQU`, `DB`, `DW`, `DS`, local branch
fixup, forward absolute operand fixups, known-label `DW DATA,ENDD`, and a
small runtime copy oracle under the active table limits.

## 2026-06-30 ASM Flash Expression Math Board Proof

### Summary

Operator transcript pasted into Codex session. The board was running
`HIMON V 00.0615(2131)` and entered the flash-resident `ASM` command.

Validated:

- `ORG $7000+16` starts assembly at `$7010`.
- Known-symbol expression math resolves `OUT+1`, `OUT+2`, `OUT+3`, and
  `BASE+1`.
- Address-delta math resolves `SIZE EQU END_ADDR-START_ADDR` to `$000F`.
- Selector atoms emit `#<NEXT = $02`, `#>NEXT = $00`, and
  `DB <NEXT,>NEXT,SIZE = 02 00 0F`.
- The final table has no fixups, `DATA=$7025`, and final `PC=$7028`.
- `G 7010` returns normally with `A=$0F`; the dump of `$7010-$7027` matches
  the emitted-code oracle.
- A follow-up `D 7100 FF` dump shows the direct runtime oracle
  `$7100-$7103 = 5A 02 00 0F`.

### Transcript

```text
HIMON V 00.0615(2131)
>ASM
ASM FLASH
ASM> ; ASM V1 EXPRESSION MATH PROOF.
OK PC=$2000
ASM> ; ASSEMBLE WITH ASM. RUN G 7010.
OK PC=$2000
ASM> ; PASS: $7100-$7103 = 5A 02 00 0F.
OK PC=$2000
ASM>
ASM>         ORG $7000+16
OK PC=$7010
ASM>
ASM> OUT     EQU $7100
OK PC=$7010
ASM> OUT1    EQU OUT+1
OK PC=$7010
ASM> OUT2    EQU OUT+2
OK PC=$7010
ASM> OUT3    EQU OUT+3
OK PC=$7010
ASM> BASE    EQU $0001
OK PC=$7010
ASM> NEXT    EQU BASE+1
OK PC=$7010
ASM>
ASM> START_ADDR
OK PC=$7010
ASM>         LDA #$5A
OK PC=$7012
ASM>         STA OUT
OK PC=$7015
ASM>         LDA #<NEXT
OK PC=$7017
ASM>         STA OUT1
OK PC=$701A
ASM>         LDA #>NEXT
OK PC=$701C
ASM>         STA OUT2
OK PC=$701F
ASM> END_ADDR
OK PC=$701F
ASM> SIZE    EQU END_ADDR-START_ADDR
OK PC=$701F
ASM>         LDA #SIZE
OK PC=$7021
ASM>         STA OUT3
OK PC=$7024
ASM>         RTS
OK PC=$7025
ASM>
ASM> DATA    DB <NEXT,>NEXT,SIZE
OK PC=$7028
ASM>
ASM>         END
OK PC=$7028
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7100  01 04 17 0005 04  0006  OUT
01 01 7101  01 04 17 0006 01  000F  OUT1
02 01 7102  01 04 17 0007 01  0011  OUT2
03 01 7103  01 04 17 0008 01  0015  OUT3
04 01 0001  01 04 17 0009 01  000A  BASE
05 01 0002  01 04 17 000A 04  000E  NEXT
06 01 7010  01 04 0F 000B 01  0013  START_ADDR
07 01 701F  01 04 0F 0012 01  0013  END_ADDR
08 01 000F  00 00 17 0013 02  0014  SIZE
09 01 7025  01 04 0E 0017 00  0000  DATA
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM FLASH OK
>G 7010
GO 7010

#GO# ENTRY=7010
RET A=0F X=30 Y=31 P=75 S=FD NV-BdIzC
>D 7000 FF
7000: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7010: A9 5A 8D 00 71 A9 02 8D | 01 71 A9 00 8D 02 71 A9 | .Z..q....q....q.
7020: 0F 8D 03 71 60 02 00 0F | 00 00 00 00 00 00 00 00 | ...q`...........
7030: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7040: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7050: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7060: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7070: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7080: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7090: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
70A0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
70B0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
70C0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
70D0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
70E0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
70F0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>D 7100 FF
7100: 5A 02 00 0F 00 00 00 00 | 00 00 00 00 00 00 00 00 | Z...............
7110: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7120: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7130: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7140: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7150: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7160: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7170: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7180: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7190: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
71A0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
71B0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
71C0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
71D0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
71E0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
71F0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>
```

### 00.0630 Retest

Operator follow-up on `HIMON V 00.0630(2008)` repeated the same
`expr-math-7010.a` paste through `ASM FLASH OK`. The table values matched the
00.0615 proof (`SIZE=$000F`, `DATA=$7025`, no fixups). The board then ran the
emitted program and dumped the combined code/runtime range:

```text
>G 7010
GO 7010

#GO# ENTRY=7010
RET A=0F X=30 Y=31 P=75 S=FD NV-BdIzC
>D 7000 71FF
7000: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7010: A9 5A 8D 00 71 A9 02 8D | 01 71 A9 00 8D 02 71 A9 | .Z..q....q....q.
7020: 0F 8D 03 71 60 02 00 0F | 00 00 00 00 00 00 00 00 | ...q`...........
7100: 5A 02 00 0F 00 00 00 00 | 00 00 00 00 00 00 00 00 | Z...............
>
```

### Backward ORG Negative Check

The same HIMON `V 00.0630(2008)` board was cold-booted through STR8 before the
negative check. The flash ASM wrapper rejected a backward `ORG` exactly at the
current expression-math boundary:

```text
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y
...
BOOT COLD
RAM ZERO OK

HIMON V 00.0630(2008)
>ASM
ASM FLASH
ASM> ORG $7000+16
OK PC=$7010
ASM> ORG $7000
ERR=$06 BAD RANGE PC=$7010
ASM> NEW
OK PC=$7010
ASM> .
ASM FLASH BYE
>ASM NEW
ASM FLASH
ASM> ORG $7000+16
OK PC=$7010
ASM> ORG $7000
ERR=$06 BAD RANGE PC=$7010
ASM>
```

This completes the optional negative path for `expr-math-7010.a`. It also shows
that, after a clean STR8/HIMON boot, top-level `ASM NEW` enters the same flash
ASM wrapper and does not prevent the `ORG $7000+16` expression from assembling.

## 2026-07-01 ASM Seal-Span Standalone Core Load Rejection

The first attempted board proof for the clean-`END` seal-span facts tried to
load the standalone `asm-v1-core-2000.s19` smoke image. The board rejected
several records:

```text
>L
L S19
L @2000
LERR
L @7B20
LERR
L @7B30
LERR
L @7EA0
L @7EB0
```

Interpretation: this is not a seal-span logic failure. The current standalone
core smoke image is too large for the simple RAM-load board proof path; its
linked image crosses the old safe HIMON RAM-load window. The board-facing proof
for the clean-`END` fact record is now the smaller
`asm-v1-runtime-smoke-2000.s19`, which links below `$7E00` and explicitly
checks `base=$7000`, `end=$7014`, and `len=$0014` before printing
`ASM RT OK`.

## 2026-07-01 ASM Seal-Span Runtime Smoke Hardware Proof

Operator transcript pasted into Codex session. The corrected board-facing
runtime smoke image loaded at `$2000` with `L OK=4BDC GO=2000`, ran from
`G 2000`, and printed `ASM RT OK`.

Validated:

- `asm-v1-runtime-smoke-2000.s19` fits the board RAM-load proof path.
- The runtime wrapper assembled the `$7000` smoke body and ran it.
- The wrapper checked the clean-`END` RAM fact record before the pass banner:
  base `$7000`, exclusive end `$7014`, and length `$0014`.

Transcript:

```text
HIMON V 00.0630(2121)
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

## 2026-07-01 ASM Seal-Span Runtime Paste Companion Proof

Operator transcript pasted into Codex session. The runtime paste image loaded
at `$2000` with `L OK=502B GO=2000`. The pasted source defined start/end labels
around an emitted `$7000` program, defined `SIZE EQU END_ADDR-START_ADDR`, and
then ran the emitted program. This is an external span oracle for the same
`base/end/length` shape that clean `END` captures internally.

Validated:

- `START_ADDR=$7000`, `END_ADDR=$701F`, and `SIZE=$001F` appeared in the final
  symbol table.
- The emitted program ran from `$7000`.
- Runtime output at `$7100` recorded base low/high, end low/high, and length
  low/high as `00 70 1F 70 1F 00`.

Transcript extract:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7000
OK PC=$7000
ASM> OUT EQU $7100
OK PC=$7000
ASM> OUT1 EQU OUT+1
OK PC=$7000
ASM> OUT2 EQU OUT+2
OK PC=$7000
ASM> OUT3 EQU OUT+3
OK PC=$7000
ASM> OUT4 EQU OUT+4
OK PC=$7000
ASM> OUT5 EQU OUT+5
OK PC=$7000
ASM> START_ADDR
OK PC=$7000
...
ASM> RTS
OK PC=$701F
ASM> END_ADDR
OK PC=$701F
ASM> SIZE EQU END_ADDR-START_ADDR
OK PC=$701F
ASM> END
OK PC=$701F
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7100  01 04 17 0002 06  0003  OUT
01 01 7101  01 04 17 0003 01  000C  OUT1
02 01 7102  01 04 17 0004 01  000E  OUT2
03 01 7103  01 04 17 0005 01  0010  OUT3
04 01 7104  01 04 17 0006 01  0012  OUT4
05 01 7105  01 04 17 0007 01  0014  OUT5
06 01 7000  01 04 0F 0008 01  0017  START_ADDR
07 01 701F  01 04 0F 0016 01  0017  END_ADDR
08 01 001F  00 00 16 0017 00  0000  SIZE
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK

#GO# ENTRY=2000
RET A=0F X=87 Y=0F P=75 S=FD NV-BdIzC
>
```

Runtime proof:

```text
>G 7000
GO 7000

#GO# ENTRY=7000
RET A=00 X=30 Y=30 P=77 S=FD NV-BdIZC
>D 7100 710F
7100: 00 70 1F 70 1F 00 00 00 | 00 00 00 00 00 00 00 00 | .p.p............
>
```
