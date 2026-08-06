# R-YORS Hardware Test Log

This file records bench transcripts that prove behavior on real hardware. Keep
entries short enough to scan, but include enough serial output to reconstruct
what was actually tested.

## 2026-07-01 ASM SEAL NEW Board Proof

### Summary

Operator transcript pasted into Codex session. The board loaded
`asm-v1-runtime-paste-2000.s19` at `$2000` with `L OK=5247 GO=2000` after
adding the validated `SEAL> NEW` restart command.

Validated:

- `SEAL> NEW X` rejects as `ERR=$03 BAD OPER PC=$7603`.
- Invalid `NEW` leaves the frozen seal facts intact.
- `SEAL> SEAL` still reports the first frozen span as
  `BASE=$7600 END=$7603 LEN=$0003`.
- Bare `SEAL> NEW` reopens ASM at the frozen exclusive end PC and prints
  `OK PC=$7603`.
- The second session starts at `$7603`, ends at `$7606`, and seals as
  `BASE=$7603 END=$7606 LEN=$0003`.
- `.` exits cleanly from the final `SEAL> ` prompt.

### Transcript

```text
HIMON V 00.0630(2121)
>L G
L S19
L @2000
L OK=5247 GO=2000
ASM RT PASTE
ASM> ORG $7600
OK PC=$7600
ASM> LDA #$5A
OK PC=$7602
ASM> RTS
OK PC=$7603
ASM> END
OK PC=$7603
ASM RT PASTE OK
SEAL> NEW X
ERR=$03 BAD OPER PC=$7603
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7603 LEN=$0003
SEAL> NEW
OK PC=$7603
ASM> LDA #$A5
OK PC=$7605
ASM> RTS
OK PC=$7606
ASM> END
OK PC=$7606
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7603 END=$7606 LEN=$0003
SEAL> .
ASM RT PASTE BYE

#LOADGO# ENTRY=2000
RET A=10 X=B1 Y=10 P=75 S=FD NV-BdIzC
>
```

## 2026-07-01 ASM SEAL Dry-Run Board Proof

### Summary

Operator transcript pasted into Codex session. The board loaded
`asm-v1-runtime-paste-2000.s19` at `$2000` with `L OK=51C7 GO=2000` after the
first post-`END` `SEAL` dry-run command was added.

Validated:

- Clean `END` switches the runtime paste wrapper from `ASM> ` to `SEAL> `.
- `SEAL` accepts only `FLAGS=$01` and prints exact frozen base/end/length
  facts on success.
- A forward `ORG` after the initial `ORG` rejects with `ERR=$02 FLAGS=$03`.
- Plain `DS count` rejects with `ERR=$02 FLAGS=$05`.
- Initialized `DS count,$xx` stays seal-owned and remains accepted.
- Combining forward `ORG` and plain `DS` rejects with `ERR=$02 FLAGS=$07`.
- `.` exits cleanly from the post-session `SEAL> ` prompt.

### Transcript Extracts

```text
HIMON V 00.0630(2121)
>L G
L S19
L @2000
L OK=51C7 GO=2000
ASM RT PASTE
ASM> ORG $7000
OK PC=$7000
ASM> LDA #$5A
OK PC=$7002
ASM> RTS
OK PC=$7003
ASM> END
OK PC=$7003
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7000 END=$7003 LEN=$0003
SEAL> .
ASM RT PASTE BYE

#LOADGO# ENTRY=2000
RET A=10 X=31 Y=10 P=75 S=FD NV-BdIzC
```

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7200
OK PC=$7200
ASM> JMP $7210
OK PC=$7203
ASM> ORG $7210
OK PC=$7210
ASM> LDA #$5A
OK PC=$7212
ASM> RTS
OK PC=$7213
ASM> END
OK PC=$7213
ASM RT PASTE OK
SEAL> SEAL
SEAL ERR=$02 FLAGS=$03
SEAL> .
ASM RT PASTE BYE
```

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7300
OK PC=$7300
ASM> LDA #$5A
OK PC=$7302
ASM> DS 2
OK PC=$7304
ASM> RTS
OK PC=$7305
ASM> END
OK PC=$7305
ASM RT PASTE OK
SEAL> SEAL
SEAL ERR=$02 FLAGS=$05
SEAL> .
ASM RT PASTE BYE
```

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7400
OK PC=$7400
ASM> LDA #$5A
OK PC=$7402
ASM> DS 2,$FF
OK PC=$7404
ASM> RTS
OK PC=$7405
ASM> END
OK PC=$7405
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7400 END=$7405 LEN=$0005
SEAL> .
ASM RT PASTE BYE
```

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7500
OK PC=$7500
ASM> JMP $7510
OK PC=$7503
ASM> ORG $7510
OK PC=$7510
ASM> LDA #$5A
OK PC=$7512
ASM> DS 2
OK PC=$7514
ASM> RTS
OK PC=$7515
ASM> END
OK PC=$7515
ASM RT PASTE OK
SEAL> SEAL
SEAL ERR=$02 FLAGS=$07
SEAL> .
ASM RT PASTE BYE
```

## 2026-07-01 ASM Seal Eligibility Flags Board Proof

### Summary

Operator transcript pasted into Codex session. The board loaded
`asm-v1-runtime-paste-2000.s19` at `$2000` with size `$506F` after adding
RAM-only seal eligibility flags for later explicit `SEAL` rejection.

Validated:

- Initialized `DS $20,$EE` owns and fills bytes in the preparation pass.
- A later non-initial forward `ORG $7210` leaves the `$7203-$720F` hole
  untouched as `$EE`.
- Plain `DS 2` remains accepted by ordinary ASM and emits the current zero-fill
  bytes at `$721B-$721C`.
- Initialized `DS 3,$5A` remains accepted and emits owned bytes at
  `$721D-$721F`.
- The emitted code at `$7210` runs and writes `$7100-$7101 = 5A A5`.
- The internal seal fact record at `$5189-$518F` is
  `07 00 72 20 72 20 00`: flags `$07` means valid + hole + unowned, base
  `$7200`, exclusive end `$7220`, length `$0020`.

### Transcript

```text
HIMON V 00.0630(2121)
>L G
L S19
L @2000
L OK=506F GO=2000
ASM RT PASTE
ASM> ORG $7200
OK PC=$7200
ASM>  DS $20,$EE
OK PC=$7220
ASM> END
OK PC=$7220
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK

#LOADGO# ENTRY=2000
RET A=0F X=CA Y=0F P=75 S=FD NV-BdIzC
>D 7200 721F
7200: EE EE EE EE EE EE EE EE | EE EE EE EE EE EE EE EE | ................
7210: EE EE EE EE EE EE EE EE | EE EE EE EE EE EE EE EE | ................
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG 7200
ERR=$05 BAD WIDTH PC=$7000
ASM> ORG $7200
OK PC=$7200
ASM> OUT EQU $7100
OK PC=$7200
ASM> OUT1 EQU $7101
OK PC=$7200
ASM> JMP $7210
OK PC=$7203
ASM> ORG $7210
OK PC=$7210
ASM> LDA #$5A
OK PC=$7212
ASM> STA OUT
OK PC=$7215
ASM> LDA #$A5
OK PC=$7217
ASM> STA OUT1
OK PC=$721A
ASM> RTS
OK PC=$721B
ASM> DS 2
OK PC=$721D
ASM> DS 3, $5A
OK PC=$7220
ASM> END
OK PC=$7220
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7100  01 04 17 0003 01  0008  OUT
01 01 7101  01 04 17 0004 01  000A  OUT1
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK

#GO# ENTRY=2000
RET A=0F X=CA Y=0F P=75 S=FD NV-BdIzC
>G 7210
GO 7210

#GO# ENTRY=7210
RET A=A5 X=30 Y=31 P=F5 S=FD NV-BdIzC
>D 7100 710F
7100: 5A A5 1F 70 1F 00 00 00 | 00 00 00 00 00 00 00 00 | Z..p............
>D 7200 721F
7200: 4C 10 72 EE EE EE EE EE | EE EE EE EE EE EE EE EE | L.r.............
7210: A9 5A 8D 00 71 A9 A5 8D | 01 71 60 00 00 5A 5A 5A | .Z..q....q`..ZZZ
>D 5189 518F
5189: 07 00 72 20 72 20 00 | ..r r .
>
```

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

## 2026-07-01 ASM SEAL.REC FNV32 Runtime Paste Proof

Operator transcript pasted into Codex session. The runtime paste image loaded
at `$2000` with `L OK=52E6 GO=2000`. This proves the RAM-only `SEAL.REC`
preview for an eligible clean-ended span: `BASE=$7600`, exclusive
`END=$7603`, `LEN=$0003`, and FNV32 `$695B146E` over emitted bytes
`A9 5A 60`.

Transcript:

```text
>L G
L S19
L @2000
L OK=52E6 GO=2000
ASM RT PASTE
ASM> ORG $7600
OK PC=$7600
ASM> LDA #$5A
OK PC=$7602
ASM> RTS
OK PC=$7603
ASM> END
OK PC=$7603
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7603
SEAL REC LEN=$0003 FNV=$695B146E
SEAL>
```

## 2026-07-01 ASM SEAL.REC DS Eligibility Runtime Paste Proof

Operator transcript pasted into Codex session. The board reused the already
loaded `asm-v1-runtime-paste-2000.s19` image at `$2000`, previously proven as
`L OK=52E6 GO=2000`. This proves initialized `DS count,$xx` bytes are owned and
included in the FNV32 body, while plain `DS count` marks the span ineligible
and emits no `SEAL REC` line.

Transcript:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7400
OK PC=$7400
ASM> LDA #$5A
OK PC=$7402
ASM> DS 2,$FF
OK PC=$7404
ASM> RTS
OK PC=$7405
ASM> END
OK PC=$7405
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7400 END=$7405
SEAL REC LEN=$0005 FNV=$C2D38700
SEAL> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=4C Y=10 P=75 S=FD NV-BdIzC
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7300
OK PC=$7300
ASM> LDA #$5A
OK PC=$7302
ASM> DS 2
OK PC=$7304
ASM> RTS
OK PC=$7305
ASM> END
OK PC=$7305
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
ASM RT PASTE OK
SEAL> SEAL
SEAL ERR=$02 FLAGS=$05
SEAL>
```

## 2026-07-01 ASMRT.REPORT.TRIM $7600 Relocation Classifier Proof

Operator transcript pasted into Codex session. The board loaded the trimmed
`asm-v1-runtime-paste-2000.s19` image as `L OK=5133 GO=2000`, proving the
`ASMRT.REPORT.TRIM` image was `$0308` smaller than the previous `L OK=543B`
relocation-classifier image. An earlier explicit `ORG $7000` attempt in the
same transcript overlapped live runtime data and caused `JMP (TARGET)` and
`JMP (TARGET,X)` to fail with `ERR=$08 BAD SYM PC=$7009`; the clean proof below
uses `$7600`.

Transcript excerpt:

```text
>L G
L S19
L @2000
L OK=5133 GO=2000
ASM RT PASTE
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
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 760F  01 04 0E 0007 00  0000  TARGET
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 04   00  7601 7603 TARGET
01 02 06   00  7604 7606 TARGET
02 02 09   00  7607 7609 TARGET
03 02 0D   00  760A 760C TARGET
04 02 0E   00  760D 760F TARGET
RELOCS
SL K  SITE TARG
00 01 0001 000F
01 01 0004 000F
02 01 0007 000F
03 01 000A 000F
04 01 000D 000F
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7610
SEAL REC @=$521F LEN=$0010 FNV=$A2335158
SEAL REL @=$522A COUNT=$05
SEAL> D 7600 1F
ERR=$03 BAD OPER PC=$7610
SEAL> .
ASM RT PASTE BYE

#LOADGO# ENTRY=2000
RET A=10 X=72 Y=10 P=75 S=FD NV-BdIzC
>D 7600 1F
7600: 4C 0F 76 BD 0F 76 B9 0F | 76 6C 0F 76 7C 0F 76 60 | L.v..v..vl.v|.v`
7610: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>D 521F +11
521F: 01 00 76 10 76 10 00 58 | 51 33 A2 05 01 01 01 01 | ..v.v..XQ3......
522F: 01 | .
>D 522A +06
522A: 05 01 01 01 01 01 | ......
```

The `SEAL> D` rejection is expected because the post-`END` wrapper prompt
accepts only `SEAL`, `NEW`, and `.`; HIMON `D` is available again after leaving
the wrapper.

## 2026-07-01 ASMRT.SIZE Runtime Buffer/Clear/Command Matcher Proof

Operator transcript pasted into Codex session. The board loaded
`asm-v1-runtime-paste-2000.s19` as `L OK=4FCF GO=2000`, proving the combined
`ASMRT.SIZE.UDATA_BUF`, `ASMRT.SIZE.SEAL_CLEAR`, and `ASMRT.SIZE.CMD_MATCH`
image was `$0164` smaller than the previous `L OK=5133 GO=2000` runtime-paste
image.

The first run proves that the runtime-only `ASM_CODE_BUF` move to UDATA did not
break the paste wrapper's default `$7600` assembly target, and that trailing
comments on `END` and `SEAL` remain accepted:

```text
>L G
L S19
L @2000
L OK=4FCF GO=2000
ASM RT PASTE
ASM> LDA #$5A
OK PC=$7602
ASM> RTS
OK PC=$7603
ASM> END ;COMMENT
OK PC=$7603
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL ;COMMENT
SEAL OK FLAGS=$01 BASE=$7600 END=$7603
SEAL REC @=$51BB LEN=$0003 FNV=$695B146E
SEAL REL @=$51C6 COUNT=$00
SEAL> .
ASM RT PASTE BYE

#LOADGO# ENTRY=2000
RET A=10 X=0E Y=10 P=75 S=FD NV-BdIzC
>D 7600 7603
7600: A9 5A 60 00 | .Z`.
>D 51BB +04
51BB: 01 00 76 03 | ..v.
>D 51C6 +01
51C6: 00 | .
```

The strict `SEAL` tail test proves `SEAL X` is rejected without clearing the
frozen seal facts:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> LDA #$5A
OK PC=$7602
ASM> RTS
OK PC=$7603
ASM> END
OK PC=$7603
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL X
ERR=$03 BAD OPER PC=$7603
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7603
SEAL REC @=$51BB LEN=$0003 FNV=$695B146E
SEAL REL @=$51C6 COUNT=$00
SEAL> .
ASM RT PASTE BYE
```

The `NEW ; COMMENT` test proves the loop clear resets stale seal/FNV and
relocation-count state. The first span produces one relocation row; after
`NEW`, an immediate `END` seals a zero-length span with FNV basis and
`COUNT=$00`:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> JMP TARGET
OK PC=$7603
ASM> TARGET RTS
OK PC=$7604
ASM> END
OK PC=$7604
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7603  01 04 0E 0002 00  0000  TARGET
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 04   00  7601 7603 TARGET
RELOCS
SL K  SITE TARG
00 01 0001 0003
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7604
SEAL REC @=$51BB LEN=$0004 FNV=$677CFADE
SEAL REL @=$51C6 COUNT=$01
SEAL> NEW ; COMMENT
OK PC=$7604
ASM> END
OK PC=$7604
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7604 END=$7604
SEAL REC @=$51BB LEN=$0000 FNV=$811C9DC5
SEAL REL @=$51C6 COUNT=$00
SEAL> .
ASM RT PASTE BYE
```

The strict `NEW` tail test proves `NEW X` is rejected without clearing the
frozen tiny-span facts:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> LDA #$5A
OK PC=$7602
ASM> RTS
OK PC=$7603
ASM> END
OK PC=$7603
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> NEW X
ERR=$03 BAD OPER PC=$7603
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7603
SEAL REC @=$51BB LEN=$0003 FNV=$695B146E
SEAL REL @=$51C6 COUNT=$00
SEAL> .
ASM RT PASTE BYE
```

Leading whitespace before post-`END` commands was not visibly captured in this
transcript. The refactored recognizer accepts it in code, but this hardware
proof covers trailing comments and strict operand rejection.

## 2026-07-01 ASMRT.SIZE Session UDATA Proof

Operator transcript pasted into Codex session. The board cold-booted through
STR8 to HIMON V 00.0701(1134), then loaded `asm-v1-runtime-paste-2000.s19`
as `L OK=343B GO=2000`. Compared with the previous `L OK=4FCF GO=2000`
runtime-paste image, this proves the `ASMRT.SIZE.SESSION_UDATA` refactor saved
`$1B94` loaded bytes while keeping runtime-paste behavior intact.

The first run proves that moving runtime-only session state, seal records,
relocation records, symbols, and fixups to UDATA still leaves the wrapper able
to seed RJOIN, assemble at the default `$7600` target, and report the expected
tiny-span seal facts:

```text
>L G
L S19
L @2000
L OK=343B GO=2000
ASM RT PASTE
ASM> LDA #$5A
OK PC=$7602
ASM> RTS
OK PC=$7603
ASM> END
OK PC=$7603
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7603
SEAL REC @=$554A LEN=$0003 FNV=$695B146E
SEAL REL @=$5555 COUNT=$00
SEAL> .
ASM RT PASTE BYE

#LOADGO# ENTRY=2000
RET A=10 X=11 Y=10 P=75 S=FD NV-BdIzC
>D 7600 7603
7600: A9 5A 60 00 | .Z`.
>D 554A +3
554A: 01 00 76 | ..v
>D 5555 +1
5555: 00 | .
```

The second run reused the already-loaded wrapper and dirtied runtime UDATA. It
assembled a span with one relocation row, then `NEW` plus immediate `END`
proved stale relocation and seal state are cleared before the next post-session
seal:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> JMP TARGET
OK PC=$7603
ASM> TARGET RTS
OK PC=$7604
ASM> END
OK PC=$7604
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 7603  01 04 0E 0002 00  0000  TARGET
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 04   00  7601 7603 TARGET
RELOCS
SL K  SITE TARG
00 01 0001 0003
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7604
SEAL REC @=$554A LEN=$0004 FNV=$677CFADE
SEAL REL @=$5555 COUNT=$01
SEAL> NEW
OK PC=$7604
ASM> END
OK PC=$7604
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7604 END=$7604
SEAL REC @=$554A LEN=$0000 FNV=$811C9DC5
SEAL REL @=$5555 COUNT=$00
SEAL> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=11 Y=10 P=75 S=FD NV-BdIzC
>D 7600 7604
7600: 4C 03 76 60 00 | L.v`.
>D 554A +1
554A: 01 | .
>D 5555 +1
5555: 00 | .
```

## 2026-07-01 ASMRT.SIZE Session UDATA Follow-up Proof

Operator transcript pasted into Codex session. The same HIMON V 00.0701(1134)
board session reloaded `asm-v1-runtime-paste-2000.s19` as
`L OK=343B GO=2000` without another STR8/cold RAM-zero path, then exercised
reload behavior, seal-negative flags, initialized `DS`, and relocation
classification after the runtime-only session tables moved to UDATA.

The reload proof still accepts the tiny span and reports the same seal/FNV
facts. The fourth byte in the dump is outside the sealed 3-byte span and is
stale RAM from an earlier program:

```text
>L G
L S19
L @2000
L OK=343B GO=2000
ASM RT PASTE
ASM> LDA #$5A
OK PC=$7602
ASM> RTS
OK PC=$7603
ASM> END
OK PC=$7603
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7603
SEAL REC @=$554A LEN=$0003 FNV=$695B146E
SEAL REL @=$5555 COUNT=$00
SEAL> .
ASM RT PASTE BYE

#LOADGO# ENTRY=2000
RET A=10 X=11 Y=10 P=75 S=FD NV-BdIzC
>D 7600 7603
7600: A9 5A 60 60 | .Z``
>D 554A +3
554A: 01 00 76 | ..v
>D 5555 +1
5555: 00 | .
```

Seal eligibility negative and initialized-`DS` cases:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> JMP $7610
OK PC=$7603
ASM> ORG $7610
OK PC=$7610
ASM> RTS
OK PC=$7611
ASM> END
OK PC=$7611
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL ERR=$02 FLAGS=$03
SEAL> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=11 Y=10 P=75 S=FD NV-BdIzC
>G 2000
GO 2000
ASM RT PASTE
ASM> LDA #$5A
OK PC=$7602
ASM> DS 2
OK PC=$7604
ASM> RTS
OK PC=$7605
ASM> END
OK PC=$7605
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL ERR=$02 FLAGS=$05
SEAL> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=11 Y=10 P=75 S=FD NV-BdIzC
>G 2000
GO 2000
ASM RT PASTE
ASM> LDA #$5A
OK PC=$7602
ASM> DS 2,$FF
OK PC=$7604
ASM> RTS
OK PC=$7605
ASM> END
OK PC=$7605
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7605
SEAL REC @=$554A LEN=$0005 FNV=$C2D38700
SEAL REL @=$5555 COUNT=$00
SEAL> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=11 Y=10 P=75 S=FD NV-BdIzC
```

## 2026-07-01 ASMRT.OVERLAP_GUARD Proof

Operator transcript pasted into Codex session. The board loaded
`asm-v1-runtime-paste-2000.s19` as `L OK=3469 GO=2000` on HIMON
V 00.0701(1134). Compared with the previous `L OK=343B GO=2000` image, this
puts the runtime-paste cost of the overlap guard at `$002E` loaded bytes.

The first run proves the old unsafe `$7000` target now rejects with `BAD RANGE`
before writing, and that the session remains usable at the default `$7600`
target:

```text
>L G
L S19
L @2000
L OK=3469 GO=2000
ASM RT PASTE
ASM> ORG $7000
ERR=$06 BAD RANGE PC=$7600
ASM> LDA #$5A
OK PC=$7602
ASM> RTS
OK PC=$7603
ASM> END
OK PC=$7603
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7603
SEAL REC @=$5578 LEN=$0003 FNV=$695B146E
SEAL REL @=$5583 COUNT=$00
SEAL> .
ASM RT PASTE BYE

#LOADGO# ENTRY=2000
RET A=10 X=3F Y=10 P=75 S=FD NV-BdIzC
>D 7600 +3
7600: A9 5A 60 | .Z`
>D 5578 +3
5578: 01 00 76 | ..v
>D 5583 +1
5583: 00 | .
```

The second run proves a nearby safe range above the current workspace still
assembles and seals normally:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7200
OK PC=$7200
ASM> LDA #$5A
OK PC=$7202
ASM> RTS
OK PC=$7203
ASM> END
OK PC=$7203
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7200 END=$7203
SEAL REC @=$5578 LEN=$0003 FNV=$695B146E
SEAL REL @=$5583 COUNT=$00
SEAL> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=3F Y=10 P=75 S=FD NV-BdIzC
>D 7200 7202
7200: A9 5A 60 | .Z`
```

## 2026-07-01 ASMRT.OVERLAP_GUARD Map-Edge Proof

Operator transcript pasted into Codex session. This follow-up uses the same
`L OK=3469 GO=2000` runtime-paste image. It proves the current map edge:
`ASM_CODE_BUF=$7105`, so `$7104` is guarded but `$7105` is a valid fallback
output address. It also records two command-surface edges: `NEW` before `END`
is parsed as source text, and monitor `D` is not accepted from the `SEAL>`
prompt.

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> >
ERR=$03 BAD OPER PC=$7600
ASM> ORG $7104
ERR=$06 BAD RANGE PC=$7600
ASM> DB $AA
OK PC=$7601
ASM> NEW
OK PC=$7601
ASM> ORG 7105
ERR=$05 BAD WIDTH PC=$7601
ASM> ORG $7105
ERR=$06 BAD RANGE PC=$7601
ASM> NEW
ERR=$08 BAD SYM PC=$7601
ASM> NEW
ERR=$08 BAD SYM PC=$7601
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=3F Y=10 P=75 S=FD NV-BdIzC
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7105
OK PC=$7105
ASM> DB $AA
OK PC=$7106
ASM> END
OK PC=$7106
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7105 END=$7106
SEAL REC @=$5578 LEN=$0001 FNV=$AF0BD5BD
SEAL REL @=$5583 COUNT=$00
SEAL> D 7104 71FF
ERR=$03 BAD OPER PC=$7106
SEAL> D 5578 +1
ERR=$03 BAD OPER PC=$7106
SEAL> D 5583 +1
ERR=$03 BAD OPER PC=$7106
SEAL>
```

## 2026-07-01 ASMRT.SIZE Session UDATA Optional Post-END Proof

Operator transcript pasted into Codex session. The already-loaded
`L OK=343B GO=2000` runtime-paste image was entered repeatedly with `G 2000`
to prove strict post-`END` command operands, label-only source behavior, and
zero-length sealing after the runtime-only session tables moved to UDATA.

Strict post-`END` operands are rejected without clearing frozen seal facts:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> LDA #$5A
OK PC=$7602
ASM> RTS
OK PC=$7603
ASM> END
OK PC=$7603
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL X
ERR=$03 BAD OPER PC=$7603
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7603
SEAL REC @=$554A LEN=$0003 FNV=$695B146E
SEAL REL @=$5555 COUNT=$00
SEAL> NEW X
ERR=$03 BAD OPER PC=$7603
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7603
SEAL REC @=$554A LEN=$0003 FNV=$695B146E
SEAL REL @=$5555 COUNT=$00
SEAL> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=11 Y=10 P=75 S=FD NV-BdIzC
```

`BOGUS` is accepted as a label-only statement at the current PC, not rejected
as a bad mnemonic. Exiting that session with `.` did not poison the next fresh
entry:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> ORG $7600
OK PC=$7600
ASM> BOGUS
OK PC=$7600
ASM> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=11 Y=10 P=75 S=FD NV-BdIzC
>G 2000
GO 2000
ASM RT PASTE
ASM> LDA #$5A
OK PC=$7602
ASM> RTS
OK PC=$7603
ASM> END
OK PC=$7603
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7603
SEAL REC @=$554A LEN=$0003 FNV=$695B146E
SEAL REL @=$5555 COUNT=$00
SEAL> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=11 Y=10 P=75 S=FD NV-BdIzC
```

Immediate `END` after fresh entry seals a zero-length span:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> END
OK PC=$7600
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$7600
SEAL REC @=$554A LEN=$0000 FNV=$811C9DC5
SEAL REL @=$5555 COUNT=$00
SEAL> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=11 Y=10 P=75 S=FD NV-BdIzC
```

Relocation classifier follow-up after the UDATA move:

```text
>G 2000
GO 2000
ASM RT PASTE
ASM> JMP TARGET
OK PC=$7603
ASM> LDA TARGET,X
OK PC=$7606
ASM> LDA TARGET,Y
OK PC=$7609
ASM> LDA #<TARGET
OK PC=$760B
ASM> LDA #>TARGET
OK PC=$760D
ASM> TARGET RTS
OK PC=$760E
ASM> END
OK PC=$760E
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 760D  01 04 0E 0006 00  0000  TARGET
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 04   00  7601 7603 TARGET
01 02 06   00  7604 7606 TARGET
02 02 09   00  7607 7609 TARGET
03 02 02   01  760A 760B TARGET
04 02 02   02  760C 760D TARGET
RELOCS
SL K  SITE TARG
00 01 0001 000D
01 01 0004 000D
02 01 0007 000D
03 02 000A 000D
04 03 000C 000D
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7600 END=$760E
SEAL REC @=$554A LEN=$000E FNV=$4C4AFAD7
SEAL REL @=$5555 COUNT=$05
SEAL> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=11 Y=10 P=75 S=FD NV-BdIzC
```

## 2026-07-02 HIMON Native Search Self-Pattern And I/O Skip

Transcript:

```text
>S 0 FFFF 'S 0 FFFF'
7A00 7A00: 53 20 30 20 46 46 46 46 | 20 27 53 20 30 20 46 46 | S 0 FFFF 'S 0 FF
7A0A*7A00: 53 20 30 20 46 46 46 46 | 20 27 53 20 30 20 46 46 | S 0 FFFF 'S 0 FF
7DC0 7DC0: 53 20 30 20 46 46 46 46 | 00 00 00 00 00 00 00 00 | S 0 FFFF........
7F00: CS0      IO SKIP
7F20: CS1      IO SKIP
7F40: CS2      IO SKIP
7F60: CS3      IO SKIP
7F80: ACIA     IO SKIP
7FA0: PIA      IO SKIP
7FC0: VIA      IO SKIP
7FE0: FTDI VIA IO SKIP
>
```

Result: pass. The native `S` command parsed apostrophe text, found the live
command buffer at `$7A00`, found the quoted copy at `$7A0A`, found the active
pattern buffer at `$7DC0`, skipped all `$7F00-$7FFF` I/O decode slots with
named rows, and returned to the prompt. No `S NF` is expected because hits were
found.

## 2026-07-02 HIMON Native Search Pattern Atom Sweep

Transcript:

```text
S 0 FFFF 20 30 20
7A01 7A00: 53 20 30 20 46 46 46 46 | 20 32 30 20 33 30 20 32 | S 0 FFFF 20 30 2
7DC0 7DC0: 20 30 20 20 46 46 46 46 | 00 00 00 00 00 00 00 00 |  0  FFFF........
7F00: CS0      IO SKIP
7F20: CS1      IO SKIP
7F40: CS2      IO SKIP
7F60: CS3      IO SKIP
7F80: ACIA     IO SKIP
7FA0: PIA      IO SKIP
7FC0: VIA      IO SKIP
7FE0: FTDI VIA IO SKIP
F79C F790: 30 0D 0A 3F 20 42 20 45 | 20 4D 20 55 20 30 20 31 | 0..? B E M U 0 1
>S 0 FFFF 'HIMON'
6400 6400: 48 49 4D 4F 4E 20 56 20 | 30 30 2E 30 37 30 31 28 | HIMON V 00.0701(
6415 6410: 31 38 34 38 A9 48 49 4D | 4F 4E 3A 20 56 20 30 30 | 1848.HIMON: V 00
65CD*65C0: 41 4D 20 54 4F 20 48 41 | 53 48 45 44 20 48 49 4D | AM TO HASHED HIM
7A0A 7A00: 53 20 30 20 46 46 46 46 | 20 27 48 49 4D 4F 4E 27 | S 0 FFFF 'HIMON'
7DC0 7DC0: 48 49 4D 4F 4E 46 46 46 | 00 00 00 00 00 00 00 00 | HIMONFFF........
7F00: CS0      IO SKIP
7F20: CS1      IO SKIP
7F40: CS2      IO SKIP
7F60: CS3      IO SKIP
7F80: ACIA     IO SKIP
7FA0: PIA      IO SKIP
7FC0: VIA      IO SKIP
7FE0: FTDI VIA IO SKIP
E400 E400: 48 49 4D 4F 4E 20 56 20 | 30 30 2E 30 37 30 31 28 | HIMON V 00.0701(
E415 E410: 31 38 34 38 A9 48 49 4D | 4F 4E 3A 20 56 20 30 30 | 1848.HIMON: V 00
E5CD*E5C0: 41 4D 20 54 4F 20 48 41 | 53 48 45 44 20 48 49 4D | AM TO HASHED HIM
F879 F870: 5F 5F 5F 5F 2F 0D 8A 0D | 0A 48 49 4D 4F 4E 20 49 | ____/....HIMON I
F8F8 F8F0: 0A 55 50 44 41 54 45 20 | 48 49 4D 4F 4E 20 43 30 | .UPDATE HIMON C0
F959 F950: 41 54 41 0D 8A 0D 0A 47 | 20 48 49 4D 4F 4E 0D 8A | ATA....G HIMON..
>S 0 FFFF 'NOTTHERE'
7A0A*7A00: 53 20 30 20 46 46 46 46 | 20 27 4E 4F 54 54 48 45 | S 0 FFFF 'NOTTHE
7DC0 7DC0: 4E 4F 54 54 48 45 52 45 | 00 00 00 00 00 00 00 00 | NOTTHERE........
7F00: CS0      IO SKIP
7F20: CS1      IO SKIP
7F40: CS2      IO SKIP
7F60: CS3      IO SKIP
7F80: ACIA     IO SKIP
7FA0: PIA      IO SKIP
7FC0: VIA      IO SKIP
7FE0: FTDI VIA IO SKIP
>S 0 7EFF 'HI' 4D
6400 6400: 48 49 4D 4F 4E 20 56 20 | 30 30 2E 30 37 30 31 28 | HIMON V 00.0701(
6415 6410: 31 38 34 38 A9 48 49 4D | 4F 4E 3A 20 56 20 30 30 | 1848.HIMON: V 00
65CD 65C0: 41 4D 20 54 4F 20 48 41 | 53 48 45 44 20 48 49 4D | AM TO HASHED HIM
7DC0 7DC0: 48 49 4D 54 48 45 52 45 | 00 00 00 00 00 00 00 00 | HIMTHERE........
>S 0 FFFF 4D 'O'
6402 6400: 48 49 4D 4F 4E 20 56 20 | 30 30 2E 30 37 30 31 28 | HIMON V 00.0701(
6417 6410: 31 38 34 38 A9 48 49 4D | 4F 4E 3A 20 56 20 30 30 | 1848.HIMON: V 00
65CF*65C0: 41 4D 20 54 4F 20 48 41 | 53 48 45 44 20 48 49 4D | AM TO HASHED HIM
7DC0 7DC0: 4D 4F 4D 54 48 45 52 45 | 00 00 00 00 00 00 00 00 | MOMTHERE........
7F00: CS0      IO SKIP
7F20: CS1      IO SKIP
7F40: CS2      IO SKIP
7F60: CS3      IO SKIP
7F80: ACIA     IO SKIP
7FA0: PIA      IO SKIP
7FC0: VIA      IO SKIP
7FE0: FTDI VIA IO SKIP
E402 E400: 48 49 4D 4F 4E 20 56 20 | 30 30 2E 30 37 30 31 28 | HIMON V 00.0701(
E417 E410: 31 38 34 38 A9 48 49 4D | 4F 4E 3A 20 56 20 30 30 | 1848.HIMON: V 00
E5CF*E5C0: 41 4D 20 54 4F 20 48 41 | 53 48 45 44 20 48 49 4D | AM TO HASHED HIM
F87B F870: 5F 5F 5F 5F 2F 0D 8A 0D | 0A 48 49 4D 4F 4E 20 49 | ____/....HIMON I
F8FA F8F0: 0A 55 50 44 41 54 45 20 | 48 49 4D 4F 4E 20 43 30 | .UPDATE HIMON C0
F95B F950: 41 54 41 0D 8A 0D 0A 47 | 20 48 49 4D 4F 4E 0D 8A | ATA....G HIMON..
>
```

Result: pass. This sweep proves hex-byte atoms (`20 30 20`), apostrophe text
(`'HIMON'`, `'NOTTHERE'`), text-plus-hex (`'HI' 4D`), and hex-plus-text
(`4D 'O'`) patterns. Whole-memory searches intentionally find the live command
line and `$7DC0` pattern buffer; the `$7DC0` display rows also show stale bytes
past the active pattern length, which is acceptable because matching uses
`SEARCH_PAT_LEN`. The `$7F00-$7FFF` I/O page is still skipped by named decode
slot, and the restricted `$0000-$7EFF` range stops before I/O as expected.

## 2026-07-02 Native Search Negative Edges, Debug Boundary, IMPORT Failure

Transcript:

```text
S 3000 +100 'NOTTHERE'
S NF
>
S 3000 +0 20
S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUIT
>S 3000 +10
S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUIT
>S 3000 +10 GG
S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUIT
>

B C 79FF
B C $79FF
>B
B start]
>B 7A00
DBG RAM
>B 7EFF
DBG RAM
>B 7800
BP $7800
>B
B start]
>B L
7800 00
>B C 7800
B C $7800
>B L
>D 7EF0 800F
7EF0: 00 06 00 76 74 00 20 FD | 08 E1 6C CF C5 CF 13 D0 | ...vt. ...l.....
7F00: CS0      IO SKIP
7F20: CS1      IO SKIP
7F40: CS2      IO SKIP
7F60: CS3      IO SKIP
7F80: ACIA     IO SKIP
7FA0: PIA      IO SKIP
7FC0: VIA      IO SKIP
7FE0: FTDI VIA IO SKIP
8000: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
>L G
L S19
L @2000
L OK=38FC GO=2000
ASM RT PASTE
ASM> RTS
OK PC=$76E8
ASM> IMPORT EXT
OK PC=$76EB
ASM> IMPORT IO2
OK PC=$76EE
ASM> END
ERR=$09 BAD FIX PC=$76EE
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 01 04   00  76E9 76EB EXT
01 01 04   00  76EC 76EE IO2
RELOCS
SL K  SITE TARG

#LOADGO# ENTRY=2000
RET A=09 X=EE Y=76 P=74 S=FD NV-BdIzc
>G 2000
GO 2000
ASM RT PASTE
ASM> IMPORT .LOCAL
ERR=$08 BAD SYM PC=$76E7
ASM> IMPORT ?LOCAL
ERR=$08 BAD SYM PC=$76E7
ASM> IMPORT LDA
OK PC=$76EA
ASM> IMPORT EXT X
ERR=$03 BAD OPER PC=$76EA
ASM> LABEL IMPORT EXT
OK PC=$76ED
ASM> IMPORT EXT
OK PC=$76F0
ASM> IMPORT EXT
OK PC=$76F3
ASM>
GO 2000
ASM RT PASTE
ASM> IMPORT .LOCAL
ERR=$08 BAD SYM PC=$76E7
ASM> IMPORT ?LOCAL
ERR=$08 BAD SYM PC=$76E7
ASM> IMPORT LDA
OK PC=$76EA
ASM> IMPORT EXT X
ERR=$03 BAD OPER PC=$76EA
ASM> LABEL IMPORT EXT
OK PC=$76ED
ASM> IMPORT EXT
OK PC=$76F0
ASM> IMPORT EXT
OK PC=$76F3
ASM> IMPORT MISS
OK PC=$76F6
ASM> JSR MISS
OK PC=$76F9
ASM> END
ERR=$09 BAD FIX PC=$76F9
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 76EA  01 04 0E 0005 00  0000  LABEL
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 01 04   00  76E8 76EA LDA
01 01 04   00  76EB 76ED EXT
02 01 04   00  76EE 76F0 EXT
03 01 04   00  76F1 76F3 EXT
04 01 04   00  76F4 76F6 MISS
05 01 04   00  76F7 76F9 MISS
RELOCS
SL K  SITE TARG

#GO# ENTRY=2000
RET A=09 X=F9 Y=76 P=74 S=FD NV-BdIzc
>
```

Result: mixed. Native search negative edges passed: excluded-range no-found
reported `S NF`, zero count and missing/bad pattern routed to usage, and `D`
still printed named `$7F00-$7FFF` I/O skip rows. Debug boundary behavior also
matched the new workspace split for the exercised cases: `$7800` accepted as
UPA/debug-patchable RAM and `$7A00/$7EFF` rejected as monitor workspace.

The `SEAL.IMPORT` attempt failed on the `L OK=38FC GO=2000` runtime-paste
image. `IMPORT EXT`, `IMPORT IO2`, `IMPORT LDA`, and duplicate `IMPORT EXT`
advanced PC by three and created unresolved ABS16 fixups, matching accidental
mnemonic/emitter behavior rather than metadata-only directive behavior. Host
inspection after this transcript found the vocabulary hash table still had the
old `ENTRY` hash at slot `$20`, while the `IMPORT` hash had displaced `INC` at
slot `$24`. Source was patched to put `IMPORT` at slot `$20`, restore `INC` at
slot `$24`, and add host smoke coverage for metadata-only `IMPORT` dispatch.
Retest the board with the rebuilt runtime-paste image.

## 2026-07-02 SEAL.IMPORT Dispatch Pass And Print Pointer Failure

Transcript:

```text
HIMON V 00.0702(0447)
>L G
L S19
L @2000
L OK=38FC GO=2000
ASM RT PASTE
ASM> RTS
OK PC=$76E8
ASM> IMPORT EXT
OK PC=$76E8
ASM> IMPORT IO2
OK PC=$76E8
ASM> END
OK PC=$76E8
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$76E7 END=$76E8
SEAL REC @=$590B LEN=$0001 FNV=$E50C2ABF
SEAL REL @=$5916 COUNT=$00
SEAL IMP @=$56DB COUNT=$00 LEN=$0020
SEAL> .
ASM RT PASTE BYE

#LOADGO# ENTRY=2000
RET A=10 X=B8 Y=10 P=75 S=FD NV-BdIzC
>D 76E7 76E8
76E7: 60 00 | `.
>D 590B +1
590B: 01 | .
>D 5916 +1
5916: 00 | .
>D 56DB +21
56DB: 00 20 43 4F 55 4E 54 3D | 24 00 41 53 4D 20 54 41 | . COUNT=$.ASM TA
56EB: 42 4C 45 53 00 53 59 4D | 42 4F 4C 53 00 53 4C 20 | BLES.SYMBOLS.SL
56FB: 53 | S
>

>G 2000
GO 2000
ASM RT PASTE
ASM> RTS
OK PC=$76E8
ASM> IMPORT .LOCAL
ERR=$08 BAD SYM PC=$76E8
ASM> IMPORT ?LOCAL
ERR=$08 BAD SYM PC=$76E8
ASM> IMPORT LDA
ERR=$08 BAD SYM PC=$76E8
ASM> IMPORT EXT X
ERR=$03 BAD OPER PC=$76E8
ASM> LABEL IMPORT EXT
ERR=$08 BAD SYM PC=$76E8
ASM> IMPORT EXT
OK PC=$76E8
ASM> IMPORT EXT
ERR=$08 BAD SYM PC=$76E8
ASM> END
OK PC=$76E8
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$76E7 END=$76E8
SEAL REC @=$590B LEN=$0001 FNV=$E50C2ABF
SEAL REL @=$5916 COUNT=$00
SEAL IMP @=$56DB COUNT=$00 LEN=$0020
SEAL> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=B8 Y=10 P=75 S=FD NV-BdIzC
>D 76E7 76E8
76E7: 60 00 | `.
>D 590B +1
590B: 01 | .
>D 5916 +1
5916: 00 | .
>D 56DB +21
56DB: 00 20 43 4F 55 4E 54 3D | 24 00 41 53 4D 20 54 41 | . COUNT=$.ASM TA
56EB: 42 4C 45 53 00 53 59 4D | 42 4F 4C 53 00 53 4C 20 | BLES.SYMBOLS.SL
56FB: 53 | S
>

>G 2000
GO 2000
ASM RT PASTE
ASM> IMPORT MISS
OK PC=$76E7
ASM> JSR MISS
OK PC=$76EA
ASM> END
ERR=$09 BAD FIX PC=$76EA
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 01 04   00  76E8 76EA MISS
RELOCS
SL K  SITE TARG

#GO# ENTRY=2000
RET A=09 X=EA Y=76 P=74 S=FD NV-BdIzc
>

>G 2000
GO 2000
ASM RT PASTE
ASM> RTS
OK PC=$76E8
ASM> IMPORT I0
OK PC=$76E8
ASM> IMPORT I1
OK PC=$76E8
ASM> IMPORT I2
OK PC=$76E8
ASM> IMPORT I3
OK PC=$76E8
ASM> IMPORT I4
OK PC=$76E8
ASM> IMPORT I5
OK PC=$76E8
ASM> IMPORT I6
OK PC=$76E8
ASM> IMPORT I7
OK PC=$76E8
ASM> IMPORT I8
ERR=$08 BAD SYM PC=$76E8
ASM> END
OK PC=$76E8
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$76E7 END=$76E8
SEAL REC @=$590B LEN=$0001 FNV=$E50C2ABF
SEAL REL @=$5916 COUNT=$00
SEAL IMP @=$56DB COUNT=$00 LEN=$0020
SEAL> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=B8 Y=10 P=75 S=FD NV-BdIzC
>D 76E7 76E8
76E7: 60 FF | `.
>D 590B +1
590B: 01 | .
>D 5916 +1
5916: 00 | .
>D 56DB +20
56DB: 00 20 43 4F 55 4E 54 3D | 24 00 41 53 4D 20 54 41 | . COUNT=$.ASM TA
56EB: 42 4C 45 53 00 53 59 4D | 42 4F 4C 53 00 53 4C 20 | BLES.SYMBOLS.SL
>
```

Result: mixed. The corrected vocabulary table fixed IMPORT dispatch on board:
`IMPORT EXT`, `IMPORT IO2`, accepted duplicate setup, parser rejections, table
overflow, and the `IMPORT MISS` metadata case all behaved as expected without
advancing PC except for the real emitted `RTS`/`JSR` bytes. The default
runtime-paste session began at `ASM_CODE_BUF=$76E7`, so the first `RTS`
reported post-emit `PC=$76E8`.

`SEAL IMP` still failed in this image. The printed address `$56DB` was inside
the seal/table message strings, and the dump showed `COUNT=$` text rather than
the import record. Host inspection found `ASM_SEAL_PRINT_NAMED_REC` saved its
record pointer in `ASM_TMP0`, but `ASM_RJ_WRITE_CSTRING` also uses `ASM_TMP0`
as its string cursor. Source was patched to preserve the named-record pointer
in `ASM_TMP1` before printing label/count/len text. Retest with the rebuilt
runtime-paste image.

## 2026-07-02 SEAL.IMPORT Hardware Proof

Transcript:

```text
>L
L S19
L @2000
L OK=3904 GO=2000
>G 2000
GO 2000
ASM RT PASTE
ASM> RTS
OK PC=$76F0
ASM> IMPORT EXT
OK PC=$76F0
ASM> IMPORT IO2
OK PC=$76F0
ASM> END
OK PC=$76F0
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$76EF END=$76F0
SEAL REC @=$5913 LEN=$0001 FNV=$E50C2ABF
SEAL REL @=$591E COUNT=$00
SEAL IMP @=$5A39 COUNT=$02 LEN=$0008
SEAL> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=C0 Y=10 P=75 S=FD NV-BdIzC
>D 76EF 76F0
76EF: 60 00 | `.
>D 5913 +1
5913: 01 | .
>D 591E +1
591E: 00 | .
>D 5A39 +8
5A39: 02 08 03 14 23 03 B5 3A | ....#..:
>

>G 2000
GO 2000
ASM RT PASTE
ASM> RTS
OK PC=$76F0
ASM> IMPORT .LOCAL
ERR=$08 BAD SYM PC=$76F0
ASM> IMPORT ?LOCAL
ERR=$08 BAD SYM PC=$76F0
ASM> IMPORT LDA
ERR=$08 BAD SYM PC=$76F0
ASM> IMPORT EXT X
ERR=$03 BAD OPER PC=$76F0
ASM> LABEL IMPORT EXT
ERR=$08 BAD SYM PC=$76F0
ASM> IMPORT EXT
OK PC=$76F0
ASM> IMPORT EXT
ERR=$08 BAD SYM PC=$76F0
ASM> END
OK PC=$76F0
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$76EF END=$76F0
SEAL REC @=$5913 LEN=$0001 FNV=$E50C2ABF
SEAL REL @=$591E COUNT=$00
SEAL IMP @=$5A39 COUNT=$01 LEN=$0005
SEAL> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=C0 Y=10 P=75 S=FD NV-BdIzC
>D 76EF 76F0
76EF: 60 00 | `.
>D 5913 +1
5913: 01 | .
>D 591E +1
591E: 00 | .
>D 5A39 +5
5A39: 01 05 03 14 23 | ....#
>

>
>G 2000
GO 2000
ASM RT PASTE
ASM> IMPORT MISS
OK PC=$76EF
ASM> JSR MISS
OK PC=$76F2
ASM> END
ERR=$09 BAD FIX PC=$76F2
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 01 04   00  76F0 76F2 MISS
RELOCS
SL K  SITE TARG

#GO# ENTRY=2000
RET A=09 X=F2 Y=76 P=74 S=FD NV-BdIzc
>D 76F0 76F2
76F0: FF FF 00 | ...
>D 76EF
76EF: 20 |
>

>G 2000
GO 2000
ASM RT PASTE
ASM> RTS
OK PC=$76F0
ASM> IMPORT I0
OK PC=$76F0
ASM> IMPORT I1
OK PC=$76F0
ASM> IMPORT I2
OK PC=$76F0
ASM> IMPORT I3
OK PC=$76F0
ASM> IMPORT I4
OK PC=$76F0
ASM> IMPORT I5
OK PC=$76F0
ASM> IMPORT I6
OK PC=$76F0
ASM> IMPORT I7
OK PC=$76F0
ASM> IMPORT I8
ERR=$08 BAD SYM PC=$76F0
ASM> END
OK PC=$76F0
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$76EF END=$76F0
SEAL REC @=$5913 LEN=$0001 FNV=$E50C2ABF
SEAL REL @=$591E COUNT=$00
SEAL IMP @=$5A39 COUNT=$08 LEN=$001A
SEAL> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=C0 Y=10 P=75 S=FD NV-BdIzC
>D 76EF 76F0
76EF: 60 FF | `.
>D 5913 +1
5913: 01 | .
>D 591E +1
591E: 00 | .
>D 5A39 +1A
5A39: 08 1A 02 78 3C 02 A0 3C | 02 C8 3C 02 F0 3C 02 18 | ...x<..<..<..<..
5A49: 3D 02 40 3D 02 68 3D 02 | 90 3D | =.@=.h=..=
>
```

Result: pass. This run loaded the rebuilt runtime-paste image as
`L OK=3904 GO=2000`, with `ASM_CODE_BUF=$76EF` and `ASM_IMPORT_REC=$5A39`.
`IMPORT EXT`, `IMPORT IO2`, and `IMPORT I0`..`I7` stayed metadata-only at
post-`RTS` `PC=$76F0`; local/reserved/extra-operand/leading-label/duplicate and
overflow cases returned the expected `BAD SYM` or `BAD OPER` status; and
`IMPORT MISS` remained metadata-only while `JSR MISS` still failed `END` with
the expected unresolved fixup. `SEAL IMP` printed the real import record address
and the positive, single-import, and table-limit dumps matched the expected
PACK40 records.

## 2026-07-02 HIMON High-RAM Workspace Boundary Proof

Purpose: prove the updated HIMON high-RAM split on real hardware after STR8
updated HIMON to `HIMON V 00.0702(0524)`: UPA/debug patchable RAM extends
through `$79FF`, monitor workspace begins at `$7A00`, native `S` uses
`SEARCH_PAT_BUF=$7DC0`, the I/O window remains skipped, and the runtime-paste
wrapper still starts ASM at the default code buffer instead of a fixed `$7600`.

```text
RUN STR8: BOOTLOADER @F000 K=03 ? y
STR8 V0 #5F6A0F7A
ROM $F000
? B E M U 0 1 2 G R
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
...
PROGRAM C000-EFFF? Y: y...
OK
STR8>
G HIMON
BOOT WARM

HIMON V 00.0702(0524)
>

>D 79F0 7A10
79F0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7A00: 44 20 37 39 46 30 20 37 | 41 31 30 00 4D 4F 4E 27 | D 79F0 7A10.MON'
7A10: 00 | .
>D 7DB0 7DD0
7DB0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7DC0: 48 49 4D 4F 4E 00 00 00 | 00 00 00 00 00 00 00 00 | HIMON...........
7DD0: 00 | .
>D 7EF0 800F
7EF0: 00 10 C0 10 75 00 20 FD | 08 E1 6C CF C5 CF 13 D0 | ....u. ...l.....
7F00: CS0      IO SKIP
7F20: CS1      IO SKIP
7F40: CS2      IO SKIP
7F60: CS3      IO SKIP
7F80: ACIA     IO SKIP
7FA0: PIA      IO SKIP
7FC0: VIA      IO SKIP
7FE0: FTDI VIA IO SKIP
8000: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................

>B C 79FF
BP NF
>B 79FF
BP $79FF
>B L
79FF 00
>B C 79FF
B C $79FF
>B L
>B 7A00
DBG RAM
>B 7EFF
DBG RAM
>B 7800
BP $7800
>B L
7800 00
>B C 7800
B C $7800
>B L

>S 3000 +100 'NOTTHERE'
S NF
>S 0 FFFF 'HIMON'
6400 6400: 48 49 4D 4F 4E 20 56 20 | 30 30 2E 30 37 30 32 28 | HIMON V 00.0702(
6415 6410: 30 35 32 34 A9 48 49 4D | 4F 4E 3A 20 56 20 30 30 | 0524.HIMON: V 00
65CD*65C0: 41 4D 20 54 4F 20 48 41 | 53 48 45 44 20 48 49 4D | AM TO HASHED HIM
7A0A 7A00: 53 20 30 20 46 46 46 46 | 20 27 48 49 4D 4F 4E 27 | S 0 FFFF 'HIMON'
7DC0 7DC0: 48 49 4D 4F 4E 45 52 45 | 00 00 00 00 00 00 00 00 | HIMONERE........
7F00: CS0      IO SKIP
7F20: CS1      IO SKIP
7F40: CS2      IO SKIP
7F60: CS3      IO SKIP
7F80: ACIA     IO SKIP
7FA0: PIA      IO SKIP
7FC0: VIA      IO SKIP
7FE0: FTDI VIA IO SKIP
E400 E400: 48 49 4D 4F 4E 20 56 20 | 30 30 2E 30 37 30 32 28 | HIMON V 00.0702(
E415 E410: 30 35 32 34 A9 48 49 4D | 4F 4E 3A 20 56 20 30 30 | 0524.HIMON: V 00
E5CD*E5C0: 41 4D 20 54 4F 20 48 41 | 53 48 45 44 20 48 49 4D | AM TO HASHED HIM
F879 F870: 5F 5F 5F 5F 2F 0D 8A 0D | 0A 48 49 4D 4F 4E 20 49 | ____/....HIMON I
F8F8 F8F0: 0A 55 50 44 41 54 45 20 | 48 49 4D 4F 4E 20 43 30 | .UPDATE HIMON C0
F959 F950: 41 54 41 0D 8A 0D 0A 47 | 20 48 49 4D 4F 4E 0D 8A | ATA....G HIMON..
>D 7DC0 +10
7DC0: 48 49 4D 4F 4E 45 52 45 | 00 00 00 00 00 00 00 00 | HIMONERE........
>S 0 7EFF 'HI' 4D
6400 6400: 48 49 4D 4F 4E 20 56 20 | 30 30 2E 30 37 30 32 28 | HIMON V 00.0702(
6415 6410: 30 35 32 34 A9 48 49 4D | 4F 4E 3A 20 56 20 30 30 | 0524.HIMON: V 00
65CD 65C0: 41 4D 20 54 4F 20 48 41 | 53 48 45 44 20 48 49 4D | AM TO HASHED HIM
7DC0 7DC0: 48 49 4D 4F 4E 45 52 45 | 00 00 00 00 00 00 00 00 | HIMONERE........
>S 0 FFFF 4D 'O'
6402 6400: 48 49 4D 4F 4E 20 56 20 | 30 30 2E 30 37 30 32 28 | HIMON V 00.0702(
6417 6410: 30 35 32 34 A9 48 49 4D | 4F 4E 3A 20 56 20 30 30 | 0524.HIMON: V 00
65CF*65C0: 41 4D 20 54 4F 20 48 41 | 53 48 45 44 20 48 49 4D | AM TO HASHED HIM
7DC0 7DC0: 4D 4F 4D 4F 4E 45 52 45 | 00 00 00 00 00 00 00 00 | MOMONERE........
7DC2 7DC0: 4D 4F 4D 4F 4E 45 52 45 | 00 00 00 00 00 00 00 00 | MOMONERE........
7F00: CS0      IO SKIP
7F20: CS1      IO SKIP
7F40: CS2      IO SKIP
7F60: CS3      IO SKIP
7F80: ACIA     IO SKIP
7FA0: PIA      IO SKIP
7FC0: VIA      IO SKIP
7FE0: FTDI VIA IO SKIP
E402 E400: 48 49 4D 4F 4E 20 56 20 | 30 30 2E 30 37 30 32 28 | HIMON V 00.0702(
E417 E410: 30 35 32 34 A9 48 49 4D | 4F 4E 3A 20 56 20 30 30 | 0524.HIMON: V 00
E5CF*E5C0: 41 4D 20 54 4F 20 48 41 | 53 48 45 44 20 48 49 4D | AM TO HASHED HIM
F87B F870: 5F 5F 5F 5F 2F 0D 8A 0D | 0A 48 49 4D 4F 4E 20 49 | ____/....HIMON I
F8FA F8F0: 0A 55 50 44 41 54 45 20 | 48 49 4D 4F 4E 20 43 30 | .UPDATE HIMON C0
F95B F950: 41 54 41 0D 8A 0D 0A 47 | 20 48 49 4D 4F 4E 0D 8A | ATA....G HIMON..
>S 3000 +0 20
S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUIT
>S 3000 +10
S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUIT
>S 3000 +10 GG
S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUIT

>L G
L S19
L @2000
L OK=3904 GO=2000
ASM RT PASTE
ASM> RTS
OK PC=$76F0
ASM> IMPORT EXT
OK PC=$76F0
ASM> IMPORT IO2
OK PC=$76F0
ASM> END
OK PC=$76F0
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$76EF END=$76F0
SEAL REC @=$5913 LEN=$0001 FNV=$E50C2ABF
SEAL REL @=$591E COUNT=$00
SEAL IMP @=$5A39 COUNT=$02 LEN=$0008
SEAL> .
ASM RT PASTE BYE

#LOADGO# ENTRY=2000
RET A=10 X=C0 Y=10 P=75 S=FD NV-BdIzC
>D 76EF 76F0
76EF: 60 FF | `.
>
```

Result: pass. The dump across `$79F0-$7A10` shows `$7A00` as HIMON command
workspace, `$7DC0` as the native search pattern buffer, and the `$7F00-$7FFF`
I/O window still skipped during dumps/search. Breakpoint tests prove `$79FF`
and `$7800` are now debug-patchable, while `$7A00` and `$7EFF` are rejected as
monitor/debug RAM. Native `S` accepts quoted/hex pattern atoms, preserves usage
errors for missing/invalid pattern input, and still skips I/O. The visible
suffix bytes after `HIMON`/`MO` are stale bytes beyond the active pattern length;
the self-hits at `$7DC0`/`$7DC2` are expected when the search range includes
`SEARCH_PAT_BUF`. Runtime paste still loads as `L OK=3904 GO=2000`, emits only
the `RTS` byte at `ASM_CODE_BUF=$76EF`, and seals two metadata-only imports at
`ASM_IMPORT_REC=$5A39`.

## 2026-07-02 HIMON M High-UPA Modify Proof

Purpose: prove HIMON `M start [end|+cnt]` can modify the new high-UPA boundary
through `$79FF`, leaves `$7A00` as monitor command workspace, handles bad byte
input by printing usage and reprompting the same address, and aborts cleanly on
`.` without writing the prompted byte.

```text
>D 79F0 7A00
79F0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7A00: 44 | D
>M 79FE +2
79FE: 00 A5
79FF: 00 5A
>D 79F0 7A00
79F0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 A5 5A | ...............Z
7A00: 44 | D
>M 79FE +2
79FE: A5 00
79FF: 5A 00
>D 79F0 7A00
79F0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7A00: 44 | D

>D 7B20 +10
7B20: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>M 7B20 +4
7B20: 00 11
7B21: 00 22
7B22: 00 33
7B23: 00 44
>D 7B20 +10
7B20: 11 22 33 44 00 00 00 00 | 00 00 00 00 00 00 00 00 | ."3D............
>M 7B24 +2
7B24: 00 GG
M start [end|+cnt].
7B24: 00 33
7B25: 00 .
>D 7B20 +10
7B20: 11 22 33 44 33 00 00 00 | 00 00 00 00 00 00 00 00 | ."3D3...........
>M 7B20 +5
7B20: 11 00
7B21: 22 00
7B22: 33 00
7B23: 44 00
7B24: 33 00
>D 7B20 +10
7B20: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>
```

Result: pass. `M 79FE +2` wrote and restored `$79FE-$79FF`, proving the end of
UPA remains writable while the following `$7A00` byte remained the monitor
command buffer (`'D'`). The `$7B20` scratch run proved multi-byte writes, usage
on invalid input (`GG`) with same-address reprompt, abort on `.`, and final
cleanup to zero.

## 2026-07-02 HIMON M Protected Range Proof

Purpose: prove the tightened `M` write policy on real hardware after the
`HIMON V 00.0702(0549)` build: `$79FF` remains writable, but a range crossing
into monitor workspace and any start address at `$7A00` or higher is refused
before the byte prompt/write path.

```text
>M 79FF
79FF: 5A 5A
>D 79F0 7A00
79F0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 5A | ...............Z
7A00: 44 | D
>M 79FF
79FF: 5A 00
>D 79F0 7A00
79F0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7A00: 44 | D
>M 79FF +2
M PROT=$7A00
>M 7A00
M PROT=$7A00
>M 7EFF
M PROT=$7EFF
>M 7F00
M PROT=$7F00
>M 8000
M PROT=$8000
>D 79F0 7A00
79F0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
7A00: 44 | D
>
```

Result: pass. `M 79FF` still prompts and writes at the final UPA byte, and the
restore returned `$79FF` to zero. `M 79FF +2` reports `M PROT=$7A00` without
prompting because the requested range crosses into monitor workspace. Direct
protected starts at `$7A00`, `$7EFF`, `$7F00`, and `$8000` report their exact
protected address, and the final dump confirms `$7A00` remains HIMON command
buffer state rather than a modified byte.

## 2026-07-02 ASM IMPORT ABS16 Relocation Proof

Purpose: prove the ASM `IMPORT` fixup slice on real hardware after updating to
HIMON `V 00.0702(0707)`: a declared external ABS16 reference seals as an
import relocation row, keeps `$FF/$FF` operand placeholders, emits import
metadata, and leaves undeclared unresolved references as `BAD FIX`.

```text
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

____      ____    ____   ____      ____
|   \    /   |   /    \  |   \    /
|___/    |___|  |      | |___/    \___
|   \    /   |  |      | |   \        \
|    \  /    |   \____/  |    \   ____/

HIMON IN 3S. S=STR8  3
STR8 V0 #5F6A0F7A
ROM $F000
? B E M U 0 1 2 G R
B0 HOLD
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
..........................................................................................................................................................................................................................................................................................................................................................
PROGRAM C000-EFFF? Y: y...
OK
STR8>
G HIMON
BOOT WARM

HIMON V 00.0702(0707)
>L
L S19
L @2000
L OK=3A3C GO=2000
>G 2000
GO 2000
ASM RT PASTE
ASM> IMPORT EXT
OK PC=$7827
ASM> JSR EXT
OK PC=$782A
ASM> END
OK PC=$782A
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 04 04   40  7828 782A EXT
RELOCS
SL K  SITE TARG
00 04 0001 0000
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7827 END=$782A
SEAL REC @=$5A4B LEN=$0003 FNV=$4C89D9ED
SEAL REL @=$5A56 COUNT=$01
SEAL IMP @=$5B71 COUNT=$01 LEN=$0005
SEAL> .
ASM RT PASTE BYE

#GO# ENTRY=2000
RET A=10 X=F8 Y=10 P=75 S=FD NV-BdIzC
      8 782A
D start [end|+cnt]
>D 7827 782A
7827: 20 FF FF 00 |  ...
>D 5A4B +3
5A4B: 01 27 78 | .'x
>D 5A56 +1
5A56: 01 | .
>D 5B71 +6
5B71: 01 05 03 14 23 60 | ....#`
>G 2000
GO 2000
ASM RT PASTE
ASM> JSR MISS
OK PC=$782A
ASM> END
ERR=$09 BAD FIX PC=$782A
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 01 04   00  7828 782A MISS
RELOCS
SL K  SITE TARG

#GO# ENTRY=2000
RET A=09 X=2A Y=78 P=74 S=FD NV-BdIzc
>D 7828 782A
7828: FF FF 00 | ...
>
```

Result: pass. The positive run loaded `asm-v1-runtime-paste-2000.s19` as
`L OK=3A3C GO=2000`, assembled at `ASM_CODE_BUF=$7827`, accepted `IMPORT EXT`
without advancing PC, emitted `JSR EXT` as `20 FF FF`, and accepted `END`.
The fixup table row changed to state `$04` with selector `$40`, proving it was
recognized as an import fixup. The relocation table printed
`00 04 0001 0000`, proving ABS16 import relocation kind `$04`, site offset
`$0001`, and import slot `$0000`. `SEAL IMP @=$5B71 COUNT=$01 LEN=$0005`
matched the first five dumped import bytes `01 05 03 14 23`. The negative
follow-up `JSR MISS` still failed `END` with `ERR=$09 BAD FIX`, left a pending
non-import ABS16 fixup, and emitted no relocation row.

## 2026-07-02 ASM IMPORT Selected-Byte Relocation Proof

Purpose: prove the ASM `SEAL.IMPORT.BYTESEL` slice on real hardware: declared
external `#<NAME` and `#>NAME` operands seal as `$05` LO8_IMPORT and `$06`
HI8_IMPORT relocation rows, keep `$FF` byte placeholders, and preserve the
single import metadata record.

```text
>L G
L S19
L @2000
L OK=3A75 GO=2000
ASM RT PASTE
ASM> IMPORT EXT
OK PC=$7860
ASM> LDA #<EXT
OK PC=$7862
ASM> LDX #>EXT
OK PC=$7864
ASM> END
OK PC=$7864
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 04 02   41  7861 7862 EXT
01 04 02   42  7863 7864 EXT
RELOCS
SL K  SITE TARG
00 05 0001 0000
01 06 0003 0000
ASM RT PASTE OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$7860 END=$7864
SEAL REC @=$5A84 LEN=$0004 FNV=$36BEBFB2
SEAL REL @=$5A8F COUNT=$02
SEAL IMP @=$5BAA COUNT=$01 LEN=$0005
SEAL> .
ASM RT PASTE BYE

#LOADGO# ENTRY=2000
RET A=10 X=31 Y=10 P=75 S=FD NV-BdIzC
>D 7860 7865
7860: A9 FF A2 FF 00 00 | ......
>D 5A84 +4
5A84: 01 60 78 64 | .`xd
>D 5A8F +2
5A8F: 02 05 | ..
>D 5BAA +5
5BAA: 01 05 03 14 23 | ....#
>
```

Result: pass. The board loaded `asm-v1-runtime-paste-2000.s19` as
`L OK=3A75 GO=2000`, assembled at `ASM_CODE_BUF=$7860`, accepted
`IMPORT EXT`, and emitted `LDA #<EXT` / `LDX #>EXT` as `A9 FF A2 FF`.
`END` marked both fixups imported: selector `$41` is import plus low-byte
selection, and selector `$42` is import plus high-byte selection. The relocation
table printed `$05` LO8_IMPORT at site offset `$0001` and `$06` HI8_IMPORT at
site offset `$0003`, both targeting import slot `$0000`. `SEAL REL` reported
two rows and `SEAL IMP` reported the single `EXT` record whose dumped bytes
began `01 05 03 14 23`.

## 2026-07-04 ASM Flash PACKAGE-Only CHECK-Omitted Proof

Purpose: prove the default flash-resident ASM image after the package-check
diagnostic split. The image must still accept `PACKAGE`, write the AP v1
envelope at caller-chosen RAM, and omit interactive `CHECK` so the flash image
recovers headroom below `$C000`.

```text
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

____      ____    ____   ____      ____
|   \    /   |   /    \  |   \    /
|___/    |___|  |      | |___/    \___
|   \    /   |  |      | |   \        \
|    \  /    |   \____/  |    \   ____/

HIMON IN 3S. S=STR8  3
STR8 V0 #5F6A0F7A
ROM $F000
? B E M U 0 1 2 G R
B0 HOLD
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
......................................................................................................................................................................................................................................................................................................................
PROGRAM C000-EFFF? Y: y...
OK
STR8>
G HIMON
BOOT WARM

HIMON V 00.0703(1903)
>L F
L F S19
L @8000
LF OK WR=3D49 GO=800C
>ASM
ASM FLASH
ASM> JSR TARGET
OK PC=$2003
ASM> LDA #<TARGET
OK PC=$2005
ASM> LDX #>TARGET
OK PC=$2007
ASM> TARGET RTS
OK PC=$2008
ASM> END
OK PC=$2008
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 2007  01 04 0E 0004 00  0000  TARGET
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 04   00  2001 2003 TARGET
01 02 02   01  2004 2005 TARGET
02 02 02   02  2006 2007 TARGET
RELOCS
SL K  SITE TARG
00 01 0001 0007
01 02 0004 0007
02 03 0006 0007
ASM FLASH OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$2000 END=$2008
SEAL REC @=$6111 LEN=$0008 FNV=$FFC39D9A
SEAL REL @=$611C COUNT=$03
SEAL> D 3000 FF
ERR=$03 BAD OPER PC=$2008
SEAL> PACKAGE $3000
PACKAGE OK @=$3000 LEN=$0037
SEAL> CHECK $3000
ERR=$03 BAD OPER PC=$2008
SEAL> .
ASM FLASH BYE
>D 3000 +7
3000: 41 50 01 37 00 53 0B | AP.7.S.
>D 3000 +37
3000: 41 50 01 37 00 53 0B 01 | 00 20 08 20 08 00 9A 9D | AP.7.S... . ....
3010: C3 FF 52 10 03 01 02 03 | 01 04 06 00 00 00 07 07 | ..R.............
3020: 07 00 00 00 45 02 00 02 | 49 02 00 02 42 08 00 20 | ....E...I...B..
3030: 07 20 A9 07 A2 20 60 | . ... `
>
```

Result: pass. The default flash image loaded as `LF OK WR=3D49 GO=800C`,
matching the package-only size after compiling out the interactive `CHECK`
command. The flash wrapper assembled the internal-relocation body at
`BASE=$2000 END=$2008`, sealed it with FNV `$FFC39D9A`, and wrote
`PACKAGE OK @=$3000 LEN=$0037`. `CHECK $3000` returned
`ERR=$03 BAD OPER PC=$2008`, proving `CHECK` is not present in the default
post-`END` command set. The dump at `$3000` matches the AP v1 envelope shape:
header `41 50 01 37 00`, seal section `53 0B`, three-row relocation section
`52 10 03`, empty export/import records `45 02 00 02` and `49 02 00 02`, and
body section `42 08 00`.

## 2026-07-04 HIMON U Removal And Debug B/N Board Proof

Purpose: prove commit `8f3a0d3` removed the resident `U` unassemble command
without breaking HIMON debug entry, breakpoints, or single-step opcode display.

Result: pass. HIMON `V 00.0704(1654)` help omitted `U`; both `U 2000` and bare
`U` returned the normal hash-not-found path for hash `$D00C09B0`; protected
memory still rejected `M 7E05`; `B 2002` listed original opcode `8D`; running
the RAM body stopped at `@2002`; `N` printed `STEP PC=2002 OP=8D STA LEN=03
NEXT=2005` and executed the store to `$7102`; an NMI during a `$2010` loop
still produced debug context and `N` stepped the `JMP` with `NEXT=2010`.

Transcript:

```text
B0 HOLD
STR8>
RESTORE B0->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: y
COPY B0->B3

____      ____    ____   ____      ____
|   \    /   |   /    \  |   \    /
|___/    |___|  |      | |___/    \___
|   \    /   |  |      | |   \        \
|    \  /    |   \____/  |    \   ____/

HIMON IN 3S. S=STR8  3 2
STR8 V0 #5F6A0F7A
ROM $F000
? B E M U 0 1 2 G R
B0 HOLD
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
......................................................................................................................................................................................................................................................................................................................................
PROGRAM C000-EFFF? Y: y...
OK
STR8>
?
STR8>
G HIMON
BOOT WARM

HIMON V 00.0704(1654)
>
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

____      ____    ____   ____      ____
|   \    /   |   /    \  |   \    /
|___/    |___|  |      | |___/    \___
|   \    /   |  |      | |   \        \
|    \  /    |   \____/  |    \   ____/

HIMON IN 3S. S=STR8  3 2 1
STR8 V0 #5F6A0F7A
ROM $F000
? B E M U 0 1 2 G R
B0 HOLD
STR8>
G HIMON
BOOT WARM

HIMON V 00.0704(1654)
>D 7E00 7E1C
7E00: 63 D8 52 59 01 0B 63 D8 | 03 DD AB DF AF DF A7 DF | c.RY..c.........
7E10: 87 CE BF DF 0F DB 89 DB | 16 CF 22 CF 83 | .........."..
>?
# ? S D M R X G L B N Q " STR8
>U 2000
#D00C09B0# HSH_NF!
>U
#D00C09B0# HSH_NF!
>D 2000 +8
2000: 20 07 20 A9 07 A2 20 60 |  . ... `
>M 7E05
M PROT=$7E05
>ASM
#56AD7400# HSH_NF!
>L F
L F S19
L @8000
LF OK WR=3C35 GO=800C
>D 2000 +8
2000: 20 07 20 A9 07 A2 20 60 |  . ... `
>D 7E00 7E1C
7E00: 63 D8 52 59 01 0B 63 D8 | 03 DD AB DF AF DF A7 DF | c.RY..c.........
7E10: 87 CE BF DF 0F DB 89 DB | 16 CF 22 CF 83 | .........."..
>ASM NEW
ASM FLASH
ASM> ORG $2000
OK
ASM> LDA #$5A
OK
ASM> STA $7102
OK
ASM> RTS
OK
ASM> END
OK
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM FLASH OK
SEAL> .
ASM FLASH BYE
>B 2002
BP $2002
>B L
2002 8D
>G 2000
GO 2000

@2002 A=5A X=30 Y=30 P=75 S=FB NV-BdIzC
>D 7102
7102: 00 | .
>N
STEP PC=2002 OP=8D STA LEN=03 NEXT=2005
RESUME 2002

@2005 A=5A X=30 Y=30 P=75 S=FB NV-BdIzC
>D 7102
7102: 5A | Z
>B C 2002
BP NF
>B L
>B C $2002
BP NF
>ASM NEW
ASM FLASH
ASM> ORG $2010
OK
ASM> NOP
OK
ASM> JMP $2010
OK
ASM> END
OK
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM FLASH OK
SEAL> .
ASM FLASH BYE
>G 2010
GO 2010

NMI PC=2011
A=01 X=30 Y=31 P=65 S=FB NV-bdIzC
>N
STEP PC=2011 OP=4C JMP LEN=03 NEXT=2010
RESUME 2011

@2010 A=01 X=30 Y=31 P=75 S=FB NV-BdIzC
>
```

## 2026-07-04 HIMON Packed Debug Opcode Length Board Proof

Purpose: prove commit `8208f96` after trimming HIMON debug opcode display. The
board must keep `N` single-step usable while replacing the full opcode mode
table with packed opcode lengths and printing mnemonic-only step diagnostics.

Result: pass. The board assembled a `$2020` RAM body whose bytes were
`EA A9 12 8D 03 71 80 02 A9 EE 4C 2A 20`. `N` reported `LEN=01` for `NOP`,
`LEN=02` for `LDA #imm`, `LEN=03` for `STA abs`, `LEN=02` plus taken target
`NEXT=202A` for `BRA`, and `LEN=03` plus absolute target `NEXT=202A` for
`JMP abs`. The step output stayed mnemonic-only: no immediate operand,
absolute operand, branch displacement, or resolved operand text was printed.
The `STA $7103` side effect stored `$12`, and the taken branch skipped
`LDA #$EE`.

Transcript:

```text
>ASM NEW
ASM FLASH
ASM> ORG $2020
OK
ASM> NOP
OK
ASM> LDA #$12
OK
ASM> STA $7103
OK
ASM> BRA SKIP
OK
ASM> LDA #$EE
OK
ASM> SKIP JMP SKIP
OK
ASM> END
OK
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 202A  01 04 0F 0007 01  0007  SKIP
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 07   00  2027 2028 SKIP
RELOCS
SL K  SITE TARG
00 01 000B 000A
ASM FLASH OK
SEAL> .
ASM FLASH BYE
>D 2020 202C
2020: EA A9 12 8D 03 71 80 02 | A9 EE 4C 2A 20 | .....q....L*
>B 2020
BP $2020
>B L
2020 EA
>G 2020
GO 2020

@2020 A=01 X=30 Y=32 P=75 S=FB NV-BdIzC
>N
STEP PC=2020 OP=EA NOP LEN=01 NEXT=2021
RESUME 2020

@2021 A=01 X=30 Y=32 P=75 S=FB NV-BdIzC
>N
STEP PC=2021 OP=A9 LDA LEN=02 NEXT=2023
RESUME 2021

@2023 A=12 X=30 Y=32 P=75 S=FB NV-BdIzC
>N
STEP PC=2023 OP=8D STA LEN=03 NEXT=2026
RESUME 2023

@2026 A=12 X=30 Y=32 P=75 S=FB NV-BdIzC
>D 7103
7103: 12 | .
>N
STEP PC=2026 OP=80 BRA LEN=02 NEXT=202A
RESUME 2026

@202A A=12 X=30 Y=32 P=75 S=FB NV-BdIzC
>N
STEP PC=202A OP=4C JMP LEN=03 NEXT=202A
RESUME 202A

@202A A=12 X=30 Y=32 P=75 S=FB NV-BdIzC
>
```

## 2026-07-04 ASM Flash Plain OK Output Board Proof

Purpose: prove commit `aa7ef42` after trimming accepted ASM flash output.
Accepted source lines and `SEAL> NEW` should print plain `OK`, while rejected
source and post-END commands should keep status name and PC context.

Result: pass. Accepted `ASM>` source lines printed plain `OK`, accepted `END`
printed plain `OK` before tables, and `SEAL> NEW` printed plain `OK` before
returning to source mode. The bad source line `BVF $4FRE` preserved
`ERR=$03 BAD OPER PC=$2205`, and the invalid post-END `D 3200 +1` preserved
`ERR=$03 BAD OPER PC=$2206`. The generated body dumped as
`A9 5A 8D 04 71 60 EA`, and running `$2200` stored `$5A` at `$7104`.

Transcript:

```text
>ASM NEW
ASM FLASH
ASM> ORG $2200
OK
ASM> LDA #$5A
OK
ASM> STA $7104
OK
ASM> BVF $4FRE
ERR=$03 BAD OPER PC=$2205
ASM> RTS
OK
ASM> END
OK
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM FLASH OK
SEAL> D 3200 +1
ERR=$03 BAD OPER PC=$2206
SEAL> NEW
OK
ASM> NOP
OK
ASM> END
OK
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM FLASH OK
SEAL> .
ASM FLASH BYE
>D 2200 +7
2200: A9 5A 8D 04 71 60 EA | .Z..q`.
>G 2200
GO 2200

#GO# ENTRY=2200
RET A=5A X=30 Y=30 P=75 S=FD NV-BdIzC
>D 7104
7104: 5A | Z
>
```

## 2026-07-04 ASM Flash BYE Return Status Board Proof

Purpose: prove commit `d83212a` after changing ASM flash wrapper return
status. A clean `.`/`ASM FLASH BYE` should return `A=$00` with carry set, while
fatal exits should keep `A=status` with carry clear. Both paths should return
`X/Y=current PC`.

Result: pass. Direct entry with `G 800C`, `ORG $2300`, and `.` returned through
HIMON as `RET A=00 X=00 Y=23 P=75 ... C`. Direct entry with `ORG $2400`,
`JSR MISS`, and failing `END` printed `ERR=$09 BAD FIX PC=$2403`, then returned
as `RET A=09 X=03 Y=24 P=74 ... c`. Entering through the resident `ASM` hash
command and typing `.` returned to the prompt without `EXEC ERR`.

Transcript:

```text
>G 800C
GO 800C
ASM FLASH
ASM> ORG $2300
OK
ASM> .
ASM FLASH BYE

#GO# ENTRY=800C
RET A=00 X=00 Y=23 P=75 S=FD NV-BdIzC
>G 800C
GO 800C
ASM FLASH
ASM> ORG $2400
OK
ASM> JSR MISS
OK
ASM> END
ERR=$09 BAD FIX PC=$2403
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 01 04   00  2401 2403 MISS
RELOCS
SL K  SITE TARG

#GO# ENTRY=800C
RET A=09 X=03 Y=24 P=74 S=FD NV-BdIzc
>ASM
ASM FLASH
ASM> .
ASM FLASH BYE
>
```

## 2026-07-04 ASM PACKAGE BODY FNV Self-Verify Board Proof

Purpose: prove the default flash ASM image now runs `PACKAGE` with written BODY
FNV self-verification while keeping `CHECK` out of the default command surface.

Result: pass. HIMON `V 00.0704(2011)` loaded the flash ASM image as
`LF OK WR=3C68 GO=800C`. `PACKAGE $3200` returned
`PACKAGE OK @=$3200 LEN=$0037`, proving the verifier did not false-fail on
board. The dumped AP v1 envelope at `$3200` matched the expected structure and
ended with the original sealed body `20 07 20 A9 07 A2 20 60`. Running the
original RAM body at `$2000` returned `A=07 X=20`, confirming the assembled
body still behaved as expected after packaging.

Transcript:

```text
STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

____      ____    ____   ____      ____
|   \    /   |   /    \  |   \    /
|___/    |___|  |      | |___/    \___
|   \    /   |  |      | |   \        \
|    \  /    |   \____/  |    \   ____/

HIMON IN 3S. S=STR8  3 2
STR8 V0 #5F6A0F7A
ROM $F000
? B E M U 0 1 2 G R
B0 HOLD
STR8>
RESTORE B0->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: y
COPY B0->B3

____      ____    ____   ____      ____
|   \    /   |   /    \  |   \    /
|___/    |___|  |      | |___/    \___
|   \    /   |  |      | |   \        \
|    \  /    |   \____/  |    \   ____/

HIMON IN 3S. S=STR8  3 2
STR8 V0 #5F6A0F7A
ROM $F000
? B E M U 0 1 2 G R
B0 HOLD
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
......................................................................................................................................................................................................................................................................................................................................
PROGRAM C000-EFFF? Y: y...
OK
STR8>
G HIMON
BOOT WARM

HIMON V 00.0704(2011)
>L F
L F S19
L @8000
LF OK WR=3C68 GO=800C
>ASM
ASM FLASH
ASM> ORG $2000
ASM> MAIN JSR TARGET
ASM> LDA #<TARGET
ASM> LDX #>TARGET
ASM> TARGET RTS
ASM> END
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
00 01 2000  01 04 0E 0002 00  0000  MAIN
01 01 2007  01 04 0E 0005 00  0000  TARGET
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 02 04   00  2001 2003 TARGET
01 02 02   01  2004 2005 TARGET
02 02 02   02  2006 2007 TARGET
RELOCS
SL K  SITE TARG
00 01 0001 0007
01 02 0004 0007
02 03 0006 0007
ASM FLASH OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$2000 END=$2008
SEAL REC @=$6111 LEN=$0008 FNV=$FFC39D9A
SEAL REL @=$611C COUNT=$03
SEAL> PACKAGE $3200
PACKAGE OK @=$3200 LEN=$0037
SEAL>
SEAL> .
ASM FLASH BYE
>D 3200 +37
3200: 41 50 01 37 00 53 0B 01 | 00 20 08 20 08 00 9A 9D | AP.7.S... . ....
3210: C3 FF 52 10 03 01 02 03 | 01 04 06 00 00 00 07 07 | ..R.............
3220: 07 00 00 00 45 02 00 02 | 49 02 00 02 42 08 00 20 | ....E...I...B..
3230: 07 20 A9 07 A2 20 60 | . ... `
>G 2000
GO 2000

#GO# ENTRY=2000
RET A=07 X=20 Y=30 P=75 S=FD NV-BdIzC
>
```

## 2026-07-04 ASM Flash Quiet Success And .P Board Proof

Purpose: prove the follow-up flash wrapper trim that removes `OK` from
successful accepted source lines and from `SEAL> NEW`, while adding source-mode
`.P` as the explicit current-PC display command.

Result: pass. With HIMON `V 00.0704(1808)` and flash ASM loaded as
`LF OK WR=3C38 GO=800C`, accepted `ORG`, `LDA`, `STA`, `RTS`, `NOP`, `END`,
and `SEAL> NEW` printed no `OK`. `.P` printed `PC=$hhhh` in source mode,
including after trailing comment text; `.P` at `SEAL>` was rejected as
`ERR=$03 BAD OPER PC=$2206`. The rejected `BVF $4FRE` line preserved
`PC=$2205`. The emitted bytes at `$2200` were
`A9 5A 8D 04 71 60 EA`, and `G 2200` stored `$5A` at `$7104`. Direct-entry
return-status paths still returned `A=$00/C=1/X/Y=$2300` for clean `.` and
`A=$09/C=0/X/Y=$2403` for unresolved-fixup `END`.

Transcript:

```text
HIMON V 00.0704(1808)
>L F
L F S19
L @8000
LF OK WR=3C38 GO=800C
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
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
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
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
ASM FLASH OK
SEAL> .
ASM FLASH BYE
>D 2200 +7
2200: A9 5A 8D 04 71 60 EA | .Z..q`.
>G 2200
GO 2200

#GO# ENTRY=2200
RET A=5A X=30 Y=30 P=75 S=FD NV-BdIzC
>D 7104
7104: 5A | Z
>G 800C
GO 800C
ASM FLASH
ASM> ORG $2300
ASM> .
ASM FLASH BYE

#GO# ENTRY=800C
RET A=00 X=00 Y=23 P=75 S=FD NV-BdIzC
>G 800C
GO 800C
ASM FLASH
ASM> ORG $2400
ASM> JSR MISS
ASM> END
ERR=$09 BAD FIX PC=$2403
ASM TABLES
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 01 04   00  2401 2403 MISS
RELOCS
SL K  SITE TARG

#GO# ENTRY=800C
RET A=09 X=03 Y=24 P=74 S=FD NV-BdIzc
>
```

## 2026-07-04 ASM Life Sample Fixed-Address Table Negative Attempt

Purpose: capture the first board attempt to paste the tiny interactive Life
sample through the flash ASM image after package BODY-FNV self-verification.
This was a useful negative sample-layout test, not a proof of the later
`ASM>$hhhh: ` prompt slice. The loaded image reported
`LF OK WR=3C68 GO=800C`, which is the pre-PC-prompt build.

Result: expected failure for the old sample shape. The source assembled code at
`$2000`, but then attempted to place neighbor and seed tables at
`$7000/$7200/$7240`. Current flash ASM protects `$6000-$7EFF` from assembly
output because that range holds the live wrapper workspace, so each fixed table
`ORG` returned `ERR=$06 BAD RANGE`. The following `DB` rows continued at the
current PC and the program reached `ASM FLASH OK`, but runtime used the old
hardcoded table addresses and rendered blank Life boards. The sample was then
changed to emit those tables inline behind labels `N0..N7`, `SEED`, `CHARS`,
and `RANDS`.

Transcript excerpt:

```text
HIMON V 00.0704(2011)
>L F
L F S19
L @8000
LF OK WR=3C68 GO=800C
>G 800C
GO 800C
ASM FLASH
ASM> ; ASM V1 TINY INTERACTIVE LIFE. PASTE VIA ASM RT PASTE.
ASM>         ORG $2000
ASM>         JMP MAIN
...
ASM> DONE    RTS
ASM>
ASM>         ORG $7000
ERR=$06 BAD RANGE PC=$2179
ASM>         DB $3F,$38,$39,$3A,$3B,$3C,$3D,$3E
...
ASM>         ORG $7200
ERR=$06 BAD RANGE PC=$2379
ASM>         DB $00,$01,$00,$00,$00,$00,$00,$00
...
ASM>         ORG $7240
ERR=$06 BAD RANGE PC=$23B9
ASM>         DB $2E,$23
ASM>         DB $01,$00,$00,$00
ASM>
ASM>         END
ASM TABLES
...
ASM FLASH OK
SEAL> .
ASM FLASH BYE
>G 2000
GO 2000

G0








N/R/Q>
G0








N/R/Q>
#GO# ENTRY=2000
RET A=51 X=3F Y=45 P=77 S=FD NV-BdIZC
>
```

## 2026-07-04 ASM PC Prompt And Life Inline-Table Seal Negative

Purpose: prove the flash source prompt presentation change on hardware, then
capture the follow-up Life sample result after moving its old `$7000/$7200`
tables inline.

Result: mixed. HIMON `V 00.0704(2039)` published the new `ASM V1` hash entry
at `$800C`, and `ASM NEW` displayed source prompts in the new `ASM>$hhhh: `
form. The Life source no longer hit `BAD RANGE`; it assembled through `END`
with final PC `$23BF` and printed `ASM FLASH OK`. However, `SEAL` returned
`SEAL ERR=$02 FLAGS=$09`. `FLAGS=$09` is `VALID|RELOC_TRUNC`, so this was not
an assembly failure: the sample produced more internal relocation rows than the
current 16-row relocation metadata record can hold. The source was then revised
again to compute neighbors, seed, glyphs, and random density in code instead
of using inline data labels.

Transcript excerpt:

```text
HIMON V 00.0704(2039)
>#
HASH     ENTRY K TEXT
56AD7400 800C 05 ASM V1
...
>ASM NEW
ASM FLASH
ASM>$2000: ; ASM V1 TINY INTERACTIVE LIFE. PASTE VIA ASM RT PASTE.
ASM>$2000:         ORG $2000
ASM>$2000:         JMP MAIN
ASM>$2003:
...
ASM>$2179: N0      DB $3F,$38,$39,$3A,$3B,$3C,$3D,$3E
...
ASM>$2379: SEED    DB $00,$01,$00,$00,$00,$00,$00,$00
...
ASM>$23B9: CHARS   DB $2E,$23
ASM>$23BB: RANDS   DB $01,$00,$00,$00
ASM>$23BF:
ASM>$23BF:         END
ASM TABLES
SYMBOLS
...
22 01 23BB  01 04 0E 00FB 00  0000  RANDS
FIXUPS
...
17 02 07   00  2162 2163 NEXTC
RELOCS
SL K  SITE TARG
00 01 0039 0003
01 01 0049 0003
02 01 0069 0003
03 01 00EE 0003
04 01 0117 012D
05 01 0001 0137
06 01 0138 000E
07 01 013B 0038
08 01 013E 00ED
09 01 0166 0114
0A 01 0169 0038
0B 01 016E 0070
0C 01 0171 0025
0D 01 0174 0038
0E 01 0076 0179
0F 01 0080 01B9
ASM FLASH OK
SEAL> SEAL
SEAL ERR=$02 FLAGS=$09
SEAL>
```

## 2026-07-04 ASM Life Computed-Neighbor Seal Pass, Branch Negative

Purpose: prove the computed-neighbor Life sample shape after removing fixed
table ORGs and inline table data, then capture the remaining source-level
runtime issue.

Result: mixed. HIMON `V 00.0704(2055)` loaded the new PC-prompt flash ASM
image as `LF OK WR=3C7B GO=800C`. The computed-neighbor Life source assembled
without table ORGs, sealed cleanly with `SEAL OK FLAGS=$01 BASE=$2000
END=$21CC`, and recorded `SEAL REL @=$611C COUNT=$0E`. The initial run printed
the correct glider at `G0`, proving initialization and rendering. However, ASM
correctly rejected `BNE SLOOP` as `ERR=$06 BAD RANGE PC=$213B`; the branch from
`$213B` back to `$2085` is outside rel8 range. Because the rejected line emitted
no loop branch, stepping only processed one cell and later generations went
blank. The source was then changed to use `BEQ SDONE` followed by absolute
`JMP SLOOP`.

Transcript excerpt:

```text
HIMON V 00.0704(2055)
>L F
L F S19
L @8000
LF OK WR=3C7B GO=800C
>ASM NEW
ASM FLASH
ASM>$2000: ; ASM V1 TINY INTERACTIVE LIFE. PASTE VIA ASM RT PASTE.
...
ASM>$2135: STORE   STA $7840,X
ASM>$2138:         INX
ASM>$2139:         CPX #$40
ASM>$213B:         BNE SLOOP
ERR=$06 BAD RANGE PC=$213B
ASM>$213B:         RTS
...
ASM>$21CC:         END
ASM TABLES
...
RELOCS
SL K  SITE TARG
00 01 0047 0003
01 01 0057 0003
02 01 007C 0003
03 01 013D 0003
04 01 0166 0180
05 01 0001 018A
06 01 018B 000E
07 01 018E 0046
08 01 0191 013C
09 01 01B9 0163
0A 01 01BC 0046
0B 01 01C1 0083
0C 01 01C4 0033
0D 01 01C7 0046
ASM FLASH OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$2000 END=$21CC
SEAL REC @=$6111 LEN=$01CC FNV=$44B0FF57
SEAL REL @=$611C COUNT=$0E
SEAL> .
ASM FLASH BYE
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
G1
........
........
........
........
........
........
........
........
```

## 2026-07-04 ASM Life Computed-Neighbor Fixed-Branch Board Proof

Purpose: close the current `life-rjoined-6800.asm` board proof after replacing
the out-of-range `BNE SLOOP` with `BEQ SDONE` plus absolute `JMP SLOOP`.

Result: pass. The source assembled with no `BAD RANGE`, finalized at
`END=$21D1`, and sealed with `SEAL OK FLAGS=$01 BASE=$2000 END=$21D1`.
Relocation metadata used all but one row of the current 16-row record:
`SEAL REL @=$611C COUNT=$0F`. Running `G 2000` printed the seeded glider at
`G0`; repeated `N`/space steps showed the expected glider progression across
the toroidal 8x8 board. `R` reset the generation display to `G0` with random
boards, and `Q` returned to HIMON with `RET A=51`.

Transcript excerpt:

```text
>ASM NEW
ASM FLASH
ASM>$2000: ; ASM V1 TINY INTERACTIVE LIFE. PASTE VIA ASM RT PASTE.
...
ASM>$2135: STORE   STA $7840,X
ASM>$2138:         INX
ASM>$2139:         CPX #$40
ASM>$213B:         BEQ SDONE
ASM>$213D:         JMP SLOOP
ASM>$2140: SDONE   RTS
...
ASM>$21D1:         END
ASM TABLES
...
RELOCS
SL K  SITE TARG
00 01 0047 0003
01 01 0057 0003
02 01 007C 0003
03 01 013E 0085
04 01 0142 0003
05 01 016B 0185
06 01 0001 018F
07 01 0190 000E
08 01 0193 0046
09 01 0196 0141
0A 01 01BE 0168
0B 01 01C1 0046
0C 01 01C6 0083
0D 01 01C9 0033
0E 01 01CC 0046
ASM FLASH OK
SEAL> SEAL
SEAL OK FLAGS=$01 BASE=$2000 END=$21D1
SEAL REC @=$6111 LEN=$01D1 FNV=$442D7231
SEAL REL @=$611C COUNT=$0F
SEAL> .
ASM FLASH BYE
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
G1
........
#.#.....
.##.....
.#......
........
........
........
........

N/R/Q>
G2
........
..#.....
#.#.....
.##.....
........
........
........
........

N/R/Q>
GP
.#......
..#.....
###.....
........
........
........
........
........

N/R/Q>
GQ
........
#.#.....
.##.....
.#......
........
........
........
........

N/R/Q>
G0
........
........
......##
..###...
...##...
..#....#
...##...
....#..#

N/R/Q>
#GO# ENTRY=2000
RET A=51 X=3F Y=00 P=77 S=FD NV-BdIZC
>
```

## 2026-07-05 HIMON RAM/IO Boundary And Loader Error Board Proof

### Summary

HIMON `V 00.0705(0416)` proves:

- `4e446cf` hard RAM/I/O boundary naming and cold-clear ceiling.
- `1ced9a7` normal `L` rejects `$7F00-$7FFF` before I/O writes.
- `60f5abc` compact loader error output preserves `LERR=$05` need-flash.
- `e4592bc` normal `L` reports `LERR=$02` while `L F` keeps rich protect/fail diagnostics.
- `D` skips named `$7F00-$7FFF` I/O rows; `M` and `B` reject monitor/I/O/flash patch targets; breakpoint set/clear at `$79FF` works and leaves an empty table.

### Transcript

```text
>#
HASH     ENTRY K TEXT
56AD7400 800C 05 ASM V1
EC7A30F0 C030 03 BOOT_COLD_RESET
5333AEAB C044 03 BOOT_WARM_RESET
3A0CB08E C13A 01
260C9112 C14D 01
270C92A5 C20E 05 "[TEXT]" -> #5F6A0F7A# STR8 MATCH!
C10BF213 C2B5 01
D60C1322 C34D 05 S: SEARCH FROM RAM TO HASHED HIMON CMD
C80BFD18 C5F6 01
D70C14B5 C62F 01
DD0C1E27 C654 01
C20BF3A6 C68E 01
C90BFEAB C6D6 01
D40C0FFC C8CC 01
C70BFB85 C8D9 01
CB0C01D1 C984 01
C2A5A6CE D2A8 01
A9AF15F7 D863 05 HASH ACQUIRE
4B9AEE1E DB0F 05 HASH OPEN
A8802314 DB89 05 HASH MIX
20285B85 DCE4 05 READ BYTE
379FE930 DD03 05 WRITE BYTE
483BB2DD DE3F 01
D55FC6FC DE68 01
BEB18931 DEA6 01
43621C9C DEBD 05 READ CH
F91947F8 DED4 05 READ ECHO
B85E3F10 DEE4 05 READ COOK
ADD714B1 DFBF 05 HEX NIB
2F6622B9 E067 01
426150D2 E083 01
30A462F2 E09A 01
226EDE8F E1E8 01
7142DD21 E204 05 BYTE HEX
D4C88B87 E22A 05 NIB HEX
E2DD10AF CE87 05 READ LINE
AEFA0F42 DFAB 05 PUT CSTR
B0051A80 C000 03 HIMON: V 00.0705(0416)
A2AD0E18 F000 03 STR8: BOOTLOADER
>D 7EF0 8010
7EF0: 00 00 00 00 00 00 00 00 | 9E DF B5 CD 0E CE 5C CE | ..............\.
7F00: CS0      IO SKIP
7F20: CS1      IO SKIP
7F40: CS2      IO SKIP
7F60: CS3      IO SKIP
7F80: ACIA     IO SKIP
7FA0: PIA      IO SKIP
7FC0: VIA      IO SKIP
7FE0: FTDI VIA IO SKIP
8000: 46 4E D6 00 74 AD 56 05 | 0C 80 80 B8 20 EF 83 B0 | FN..t.V..... ...
8010: 08 | .
>M 7A00
M PROT=$7A00
>M 7EFF
M PROT=$7EFF
>M 7F00
M PROT=$7F00
>B 79FF
BP $79FF
>B L
79FF 00
>B C 79FF
B C $79FF
>B L
>
>B 7A00
DBG RAM
>B 7EFF
DBG RAM
>B 7F00
DBG RAM
>B 8000
DBG RAM
>L
L S19
L @7F00
LERR=$02
>L
L S19
L @7F00
LERR=$02
>L
L S19
L @8000
LERR=$05
>
>L
L S19
L @7F00
LERR=$02
>
>L F
L F S19
L @C000
LF PROT=C000
LF FAIL=02 WR=0000 SKIP=0001 GO=0000
>
```

## 2026-07-06 HIMON Resident S Removal And D Search Board Proof

### Summary

HIMON `V 00.0706(0157)` proves:

- Normal HIMON no longer exposes resident `S`: help omits it, `S` and `# S` report hash-not-found, and the post-update catalog has no `D60C1322 ... S` row.
- `D` keeps suffix-completed dump ranges and bare-`D` continuation.
- `D` rejects the old `+count` form.
- `D` search reports `D NF`, prints hit address plus D-style context row, accepts short end tokens, accepts apostrophe text, and skips `$7F00-$7FFF` with compact I/O slot names.
- A follow-up ROM-only `D 8000 FFFF 'HIMO'` search finds the five ROM `HIMON` text sites without RAM command-buffer or pattern-buffer hits.
- Follow-up paste proof shows a queued `D 7F00 FF` command survived a long
  `D 0 FFFF` dump; the leading `D` was preserved instead of being consumed by
  long-output Ctrl-C polling.
- Follow-up loader proof shows positive `L`, manual `G`, breakpoint/single-step,
  `L G` auto-go, normal `L` guard failures, and `L F` protected-write reporting.
- Follow-up positive `L F` proof shows `$8000-$BFFF` blank, writes ASM to low
  flash, exposes the `ASM` catalog row, enters via command lookup, enters via
  direct `G 800C`, and rechecks D range/search continuation edges.

### Transcript

```text
STR8 V0 #5F6A0F7A
ROM $F000
? B E M U 0 1 2 G R
B0 HOLD
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
...........................................................................                  ...........................................................................                  ...........................................................................                  ...........................................................................                  ...............
PROGRAM C000-EFFF? Y: y...
OK
STR8>
G HIMON
BOOT WARM

HIMON V 00.0706(0157)
>D 0 FF
0000: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
...
00F0: 10 01 01 00 00 06 0F 46 | 00 02 FA 00 FF 00 F0 00 | .......F........
>D 8 F
0008: 00 00 00 00 00 00 00 00 | ........
>D 88 F
0088: 00 00 00 00 00 00 00 00 | ........
>D
0090: 00 00 00 00 00 00 00 00 | ........
>D
0098: 00 00 00 00 00 00 00 00 | ........
>D
00A0: 00 00 00 00 00 00 00 00 | ........
>D
00A8: 00 00 00 00 00 00 00 00 | ........
>D C000 1
C000: 78 D8 | x.
>D
C002: A2 FF | ..
>D
C004: 9A AD | ..
>D
C006: E6 7E | .~
>D
C008: C9 A5 | ..
>S
#D60C1322# HSH_NF!
>#
HASH     ENTRY K TEXT
EC7A30F0 C030 03 BOOT_COLD_RESET
5333AEAB C044 03 BOOT_WARM_RESET
3A0CB08E C13D 01
260C9112 C150 01
270C92A5 C211 05 "[TEXT]" -> #5F6A0F7A# STR8 MATCH!
C10BF213 C2B8 01
C80BFD18 C55D 01
D70C14B5 C596 01
DD0C1E27 C5BB 01
C20BF3A6 C5F5 01
C90BFEAB C63D 01
D40C0FFC C833 01
C70BFB85 C840 01
CB0C01D1 C8EB 01
C2A5A6CE D220 01
A9AF15F7 D7B5 05 HASH ACQUIRE
4B9AEE1E DA64 05 HASH OPEN
A8802314 DADE 05 HASH MIX
20285B85 DC39 05 READ BYTE
379FE930 DC58 05 WRITE BYTE
483BB2DD DD94 01
D55FC6FC DDBD 01
BEB18931 DDFB 01
43621C9C DE12 05 READ CH
F91947F8 DE29 05 READ ECHO
B85E3F10 DE39 05 READ COOK
ADD714B1 DF14 05 HEX NIB
2F6622B9 DFBC 01
426150D2 DFD8 01
30A462F2 DFEF 01
226EDE8F E13D 01
7142DD21 E159 05 BYTE HEX
D4C88B87 E17F 05 NIB HEX
E2DD10AF CDEE 05 READ LINE
AEFA0F42 DF00 05 PUT CSTR
B0051A80 C000 03 HIMON: V 00.0706(0157)
A2AD0E18 F000 03 STR8: BOOTLOADER
>?
# ? D M R X G L B N Q " STR8
># S
D60C1322 HSH_NF!
>D 0 +F
D [a [b [bb|'t']]]
>D C000 C0FF
C000: 78 D8 A2 FF 9A AD E6 7E | C9 A5 D0 24 AD E7 7E C9 | x......~...$..~.
...
C0F0: A2 94 A0 E2 20 9A CE A9 | 01 85 F3 A2 00 A0 7A 20 | .... .........z
>D C000 C0FF 78 DB
D NF
>D C000 C0FF 78
C000 C000: 78 D8 A2 FF 9A AD E6 7E | C9 A5 D0 24 AD E7 7E C9 | x......~...$                  ..~.
C030 C030: 78 D8 A2 FF 9A 4C C4 CD | 46 4E D6 AB AE 33 53 03 | x....L..FN..                  .3S.
C044 C040: 44 C0 25 E2 78 D8 A2 FF | 9A A9 02 8D 75 7E 20 3A | D.%.x.......                  u~ :
C060 C060: 78 D8 A2 FF 9A 20 6B C0 | 4C E6 C0 A9 A5 8D E6 7E | x.... k.L...                  ...~
>D C000 FF 78 D8
C000 C000: 78 D8 A2 FF 9A AD E6 7E | C9 A5 D0 24 AD E7 7E C9 | x......~...$                  ..~.
C030 C030: 78 D8 A2 FF 9A 4C C4 CD | 46 4E D6 AB AE 33 53 03 | x....L..FN..                  .3S.
C044 C040: 44 C0 25 E2 78 D8 A2 FF | 9A A9 02 8D 75 7E 20 3A | D.%.x.......                  u~ :
C060 C060: 78 D8 A2 FF 9A 20 6B C0 | 4C E6 C0 A9 A5 8D E6 7E | x.... k.L...                  ...~
>D C000 FFFF A2 FF 9A
C002 C000: 78 D8 A2 FF 9A AD E6 7E | C9 A5 D0 24 AD E7 7E C9 | x......~...$                  ..~.
C032 C030: 78 D8 A2 FF 9A 4C C4 CD | 46 4E D6 AB AE 33 53 03 | x....L..FN..                  .3S.
C046 C040: 44 C0 25 E2 78 D8 A2 FF | 9A A9 02 8D 75 7E 20 3A | D.%.x.......                  u~ :
C062 C060: 78 D8 A2 FF 9A 20 6B C0 | 4C E6 C0 A9 A5 8D E6 7E | x.... k.L...                  ...~
F002 F000: 78 D8 A2 FF 9A 20 36 F0 | 20 26 F0 20 F7 F0 20 00 | x.... 6. &.                   .. .
>D 0 FFFF 'HIMO'
61EB 61E0: 18 0E AD A2 03 00 F0 84 | E2 0D 0A 48 49 4D 4F 4E | ...........H                  IMON
6200 6200: 48 49 4D 4F 4E 3A 20 56 | 20 30 30 2E 30 37 30 36 | HIMON: V 00.                  0706
7A0A 7A00: 44 20 30 20 46 46 46 46 | 20 27 48 49 4D 4F 27 00 | D 0 FFFF 'HI                  MO'.
7DC0 7DC0: 48 49 4D 4F 00 00 00 00 | 00 00 00 00 00 00 00 00 | HIMO........                  ....
7F00: CS0 IO SKIP
7F20: CS1 IO SKIP
7F40: CS2 IO SKIP
7F60: CS3 IO SKIP
7F80: ACIA IO SKIP
7FA0: PIA IO SKIP
7FC0: VIA IO SKIP
7FE0: FTDI VIA IO SKIP
E1EB E1E0: 18 0E AD A2 03 00 F0 84 | E2 0D 0A 48 49 4D 4F 4E | ...........H                  IMON
E200 E200: 48 49 4D 4F 4E 3A 20 56 | 20 30 30 2E 30 37 30 36 | HIMON: V 00.                  0706
F879 F870: 5F 5F 5F 5F 2F 0D 8A 0D | 0A 48 49 4D 4F 4E 20 49 | ____/....HIM                  ON I
F8F8 F8F0: 0A 55 50 44 41 54 45 20 | 48 49 4D 4F 4E 20 43 30 | .UPDATE HIMO                  N C0
F959 F950: 41 54 41 0D 8A 0D 0A 47 | 20 48 49 4D 4F 4E 0D 8A | ATA....G HIM                  ON..
>
```

### Follow-up

```text
>D 8000 FFFF 'HIMO'
E1EB E1E0: 18 0E AD A2 03 00 F0 84 | E2 0D 0A 48 49 4D 4F 4E | ...........HIMON
E200 E200: 48 49 4D 4F 4E 3A 20 56 | 20 30 30 2E 30 37 30 36 | HIMON: V 00.0706
F879 F870: 5F 5F 5F 5F 2F 0D 8A 0D | 0A 48 49 4D 4F 4E 20 49 | ____/....HIMON I
F8F8 F8F0: 0A 55 50 44 41 54 45 20 | 48 49 4D 4F 4E 20 43 30 | .UPDATE HIMON C0
F959 F950: 41 54 41 0D 8A 0D 0A 47 | 20 48 49 4D 4F 4E 0D 8A | ATA....G HIMON..
```

### Paste Preservation Follow-up

This excerpt proves the HIMON-local RX lookahead fix. The operator queued a
follow-up `D 7F00 FF` behind a long `D 0 FFFF`; after the long dump completed,
HIMON read and executed the queued command with its leading `D` intact.

```text
>D 0 FFFF
0000: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
0010: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
...
F8F0: 0A 55 50 44 41 54 45 20 | 48 49 4D 4F 4E 20 43 30 | .UPDATE HIMON C0
F900: 30 30 2D 45 46 46 46 3F | 20 59 3A A0 0D 0A 53 45 | 00-EFFF? Y:...SE
F910: 4E 44 20 53 31 39 20 43 | 30 30 30 2D 45 46 46 46 | ND S19 C000-EFFF
F920: 0D 8A 0D 0A 50 52 4F 47 | 52 41 4D 20 43 30 30 30 | ....PROGRAM C000
F930: 2D 45 46 46 46 3F 20 59 | 3A A0 0D 0A 53 31 39 20 | -EFFF? Y:...S19
F940: 46 41 49 4C 0D 8A 0D 0A | 4E 4F 20 53 31 39 20 44 | FAIL....NO S19 D
F950: 41 54 41 0D 8A 0D 0A 47 | 20 48 49 4D 4F 4E 0D 8A | ATA....G HIMON..
...
FFF0: FF FF FF FF FF FF FF FF | FF FF 89 F0 00 F0 9D F0 | ................
>D 7F00 FF
7F00: CS0 IO SKIP
7F20: CS1 IO SKIP
7F40: CS2 IO SKIP
7F60: CS3 IO SKIP
7F80: ACIA IO SKIP
7FA0: PIA IO SKIP
7FC0: VIA IO SKIP
7FE0: FTDI VIA IO SKIP
>
```

### Loader And Guard Follow-up

S19 records used for the current positive loader proof:

```text
S10E3000A9008D4858A95A8D4858605B
S1045848005B
S9033000CC
```

The `$3000` program zeros `$5848`, writes `$5A` to `$5848`, then returns. The
separate `$5848` data record also preloads the proof byte to `$00` during load.

S19 records used for negative guard proofs:

```text
; normal L into $7F00 I/O page, expect LERR=$02
S1047F00AAD2

; normal L into $8000 flash window, expect LERR=$05
S1048000AAD1

; L F into protected $C000+ region, expect LF PROT / LF FAIL
S104C000AA91
S9030000FC
```

Transcript excerpts:

```text
>L
L S19
L @3000
L @5848
L OK=0007 GO=3000
>D 5848
5848: 00 | .
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=5A X=30 Y=30 P=75 S=FD NV-BdIzC
>D 5848
5848: 5A | Z
>B 3000
BP $3000
>G 3000
GO 3000

@3000 A=01 X=30 Y=30 P=75 S=FB NV-BdIzC
>N
STEP PC=3000 OP=A9 LDA LEN=02 NEXT=3002
RESUME 3000

@3002 A=5A X=30 Y=30 P=75 S=FB NV-BdIzC
>D 3000 FF
3000: A9 5A 8D 48 58 60 00 00 | 00 00 00 00 00 00 00 00 | .Z.HX`..........
...
30F0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>L
L S19
L @3000
L @5848
L OK=000C GO=3000
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=5A X=30 Y=30 P=75 S=FD NV-BdIzC
>D 5848
5848: 5A | Z
>D 3000 FF
3000: A9 00 8D 48 58 A9 5A 8D | 48 58 60 00 00 00 00 00 | ...HX.Z.HX`.....
...
30F0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>L G
L S19
L @3000
L @5848
L OK=000C GO=3000

#LOADGO# ENTRY=3000
RET A=5A X=30 Y=30 P=75 S=FD NV-BdIzC
>D 5848
5848: 5A | Z
```

Malformed loader scratch during the same session is preserved below as an
observed operator artifact. After the loader returned to the prompt, a pasted
terminator was treated as an ordinary command and correctly reported
hash-not-found.

```text
>L
L S19
LERR=$01

LS03
LERR=$01
LERR=$01
LERR=$01
LERR=$01

LS03

LS03
LERR=$00
```

Guard transcript:

```text
>L
L S19
L @7F00
LERR=$02
>L
L S19
L @7F00
LERR=$02
>L
L S19
L @8000
LERR=$05
>L
L S19
L @C000
LERR=$05
>S9030000FC
#5C56ABD3# HSH_NF!
>L F
L F S19
L @C000
LF PROT=C000
LF FAIL=02 WR=0000 SKIP=0001 GO=0000
>
```

### Positive `L F` ASM Follow-up

The board first proved the current low-flash window blank before flashing ASM:

```text
D 8000 BFFF
8000: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
...
BFF0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
```

The positive `L F` load wrote the ASM flash image and exposed the command
record:

```text
>L F
L F S19
L @8000
LF OK WR=3C7B GO=800C
># ASM
56AD7400 ENTRY=800C K=05  ASM V1
>D 8000 BFFF
8000: 46 4E D6 00 74 AD 56 05 | 0C 80 80 B8 20 EF 83 B0 | FN..t.V..... ...
8010: 08 A9 0B A2 00 A0 00 18 | 60 A2 AF A0 B8 20 52 82 | ........`.... R.
8020: A9 01 A2 00 A0 20 20 88 | 85 8E 01 60 8C 02 60 9C | .....  ....`..`.
...
BC70: 01 01 01 01 01 01 01 01 | 01 03 03 FF FF FF FF FF | ................
BC80: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
...
BFF0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
```

ASM entered both through the command scanner and direct entry:

```text
>ASM
ASM FLASH
ASM>$2000: .
ASM FLASH BYE
>G 800C
GO 800C
ASM FLASH
ASM>$2000: .
ASM FLASH BYE

#GO# ENTRY=800C
RET A=00 X=00 Y=20 P=75 S=FD NV-BdIzC
```

The same session rechecked D range and search edges:

```text
>D 30F0 10
D [a [b [bb|'t']]]
>D 30F0 F
30F0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>D 3000 30FF 4D
D NF
D
#5E614B7E# HSH_NF!
>D
3100: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>D
3110: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>
```

## 2026-07-07 ENTRY And Resident AP Service Board Proof

Board transcript from HIMON `V 00.0707(1532)` proves the `fbf04bc` ENTRY/AP
slice on hardware. STR8 restored B0 to B3, updated HIMON `$C000-$EFFF`, and
booted the new monitor. The resident service cells were visible before loading
flash ASM:

```text
>D 7E25 40
7E25: F1 D5 00 00 00 00 00 00 | B2 D6 00 00 00 00 00 00 | ................
7E35: 00 00 00 00 00 00 00 00 | 00 00 00 00 | ............
>L
L @7000
L OK=06D5 GO=7000
>L F
L @8000
LF OK WR=3A08 GO=800C
```

Compact ENTRY positive proof passed. `START` was accepted as a label,
`ENTRY START` produced one export row, the AP envelope loaded from RAM and
from installed flash, and both relocated bodies returned `A=5A`:

```text
ASM>$2400: START LDA #$5A
ASM>$2402: RTS
ASM>$2403: ENTRY START
ASM>$2403: END
ASM OK
SEAL> SEAL
SEAL OK
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$002A
SEAL> LOAD $3200 $3000
LOAD OK=$3000 L=$0003 C=$00
SEAL> INSTALL $3200
INST @=$BA08 L=$002A
SEAL> INSTALL $3200 $BA08
INST @=$BA08 L=$002A
SEAL> LOAD $BA08 $3100
LOAD OK=$3100 L=$0003 C=$00
>D 3000 3002
3000: A9 5A 60 | .Z`
>D 3100 3102
3100: A9 5A 60 | .Z`
>G 3000
RET A=5A X=30 Y=30 P=75 S=FD NV-BdIzC
>G 3100
RET A=5A X=30 Y=30 P=75 S=FD NV-BdIzC
```

The reporter confirmed `EXP=$01`, map end `$BA08`, and the installed package
as the final AP source:

```text
COUNTS SYM FIX REL EXP IMP IMPRES RELCNT 01 00 00 01 00 00 00
PKG @ LEN BODY INST BA08 002A 0003 BA08
START DEF=$0002
ASM REPORT OK
```

ENTRY negative proof also passed:

```text
ASM>$2500: ENTRY
ERR=$03 BO PC=$2500
ASM>$2500: ENTRY MISSING
ERR=$08 BS PC=$2500
ASM>$2500: START RTS
ASM>$2501: ENTRY START
ASM>$2501: ENTRY START
ERR=$08 BS PC=$2501
```

The dedicated resident AP service proof passed with a later installed package
at `$BA32`. The service request/result cells after `LOAD $BA32 $3100` show
AP vector `$D6B2`, op `$01`, status `$00`, source `$BA32`, destination `$3100`,
package length `$002A`, body length `$0003`, and zero reloc/import counts:

```text
>D 7E2D 40
7E2D: B2 D6 01 00 32 BA 00 31 | 2A 00 59 BA 03 00 00 00 | ....2..1*.Y.....
7E3D: 32 BA 46 BA | 2.F.
```

AP negative proof passed:

```text
SEAL> LOAD $3201 $3000
LOAD ERR=$07 BL
SEAL> LOAD $3200 $3200
LOAD ERR=$06 BAD RANGE
SEAL> INSTALL $3200 $C000
INST ERR=$06 BAD RANGE
SEAL> INSTALL $3200 $BA86
INST @=$BA86 L=$002A
SEAL> INSTALL $3200 $BA86
INST ERR=$06 BAD RANGE
SEAL> PACKAGE $3400
PKG OK @=$3400 L=$0035
SEAL> LOAD $3400 $3000
LOAD ERR=$09 BAD FIX
```

The final SPIL paste assembled, packaged, and installed successfully, but the
operator exited `SEAL>` before running `LOAD $BAB0 $3123`. The subsequent
`G 3123` trapped on stale/unloaded memory, so the extended SPIL run remains
incomplete rather than failed:

```text
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$00FD
SEAL> INSTALL $3200
INST @=$BAB0 L=$00FD
SEAL> INSTALL $3200 $BAB0
INST @=$BAB0 L=$00FD
SEAL> .
ASM BYE
>G 3123
BRK 00 PC=3125
```

Follow-up SPIL tail proof closed the incomplete run by loading the installed
AP envelope at `$BAB0` into `$3123` from a fresh empty ASM session:

```text
>ASM NEW
ASM
ASM>$2000: END
ASM OK
SEAL> LOAD $BAB0 $3123
LOAD OK=$3123 L=$00B3 C=$07
SEAL> .
ASM BYE
>G 3123
GO 3123

#GO# ENTRY=3123
RET A=AC X=00 Y=32 P=F5 S=FD NV-BdIzC
>D 5848 5850
5848: AC 00 6E 31 6E 31 44 31 | 5A | ..n1n1D1Z
```

The reporter after the tail run came from the fresh empty session, so
live-session symbols/exports were empty and `INST=0000`; the installed AP
source, body size, and seven relocation rows remained visible:

```text
>G 7000
GO 7000
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$2000
PC=$2000
HIGH=$2000
BYTES=$0000
LINES=$0001
SYMS=$00/$28
FIXUPS=$00/$60
REFS=$00/$A0
TRUNC=NO
MAP END=$BA08 UDATA=$5000-6F16
SEAL FL BASE END LEN FNV 01 2000 2000 0000 00000000
COUNTS SYM FIX REL EXP IMP IMPRES RELCNT 00 00 07 00 00 00 07
PKG @ LEN BODY INST BAB0 00FD 00B3 0000
SYMBOLS
SL ST VALUE K  W  FL DEF  USE FIRST NAME
FIXUPS
SL ST MODE SEL SITE BASE NAME
RELOCS
SL K  SITE TARG
00 02 003B 0021
01 03 0040 0021
02 01 0028 0048
03 02 002B 004B
04 03 0033 004B
05 01 0049 004B
06 01 0045 0051
ASM REPORT OK
```

## 2026-07-07 HIMON AP Command Board Proof

Board transcript from HIMON `V 00.0707(1652)` proves the new resident hashed
`AP pkg dst` command can load and run an installed AP envelope after a flash
erase/reload cycle. An earlier stress package that used unsupported relocation
shape failed through the resident command with `APERR=$09`, which proves error
propagation from the shared AP service but is not the clean positive gate:

```text
SEAL> LOAD $BAD8 $3123
LOAD ERR=$09 BAD FIX
...
># AP
3AD53794 ENTRY=C66D K=01
>AP $BA08 $3133
APERR=$09
>D 7E2D 40
7E2D: 35 D7 01 09 08 BA 33 31 | 45 00 3E BA 0F 00 03 00 | 5.....31E.>.....
7E3D: 08 BA 1C BA | ....
```

After erasing/restoring flash, the board was updated through STR8/HIMON and
flash ASM was reloaded:

```text
STR8 V0 #5F6A0F7A
ROM $F000
...
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
...
PROGRAM C000-EFFF? Y: y...
OK
STR8>
G HIMON
BOOT WARM

HIMON V 00.0707(1652)
>L F
L F S19
L @8000
LF OK WR=3A08 GO=800C
```

The clean AP package uses only two internal low/high relocations and keeps the
entry at BODY offset zero, matching the current V0 `AP pkg dst` command
contract:

```text
>ASM NEW
ASM
ASM>$2000: ORG $2400
ASM>$2400: MAIN LDX #<TARGET
ASM>$2402: LDY #>TARGET
ASM>$2404: LDA #$A7
ASM>$2406: RTS
ASM>$2407: TARGET DB $00
ASM>$2408: ENTRY MAIN
ASM>$2408: END
ASM OK
SEAL> SEAL
SEAL OK
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$0039
SEAL> LOAD $3200 $3000
LOAD OK=$3000 L=$0008 C=$02
SEAL> INSTALL $3200
INST @=$BA08 L=$0039
SEAL> INSTALL $3200 $BA08
INST @=$BA08 L=$0039
SEAL> LOAD $BA08 $3123
LOAD OK=$3123 L=$0008 C=$02
SEAL> .
ASM BYE
```

Both ASM-driven loads ran correctly, then plain HIMON showed the `AP` usage and
loaded/ran the installed envelope at a fresh RAM destination:

```text
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=A7 X=07 Y=30 P=F5 S=FD NV-BdIzC
>G 3123
GO 3123

#GO# ENTRY=3123
RET A=A7 X=2A Y=31 P=F5 S=FD NV-BdIzC
>AP
AP pkg dst
>AP $BA08 $2800
GO 2800

#GO# ENTRY=2800
RET A=A7 X=07 Y=28 P=F5 S=FD NV-BdIzC
>D 2800 FF
2800: A2 07 A0 28 A9 A7 60 00 | 00 00 00 00 00 00 00 00 | ...(..`.........
2810: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
2820: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
2830: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
2840: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
2850: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
2860: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
2870: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
2880: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
2890: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
28A0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
28B0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
28C0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
28D0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
28E0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
28F0: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>
```

The command negatives then passed from the plain HIMON prompt: malformed AP
source returned `$07`, destination overlap returned `$06`, and missing operands
printed usage.

```text
>AP $3201 $3000
APERR=$07
>AP $BA08 $BA08
APERR=$06
>AP
AP pkg dst
>
```

The RAM load-window edge proof also passed. Flash destinations and destinations
above the AP load window return `$06`; the same installed package runs at
`$4000`, and `$5000` is rejected:

```text
>AP $7000 $BA08
APERR=$06
>AP $6000 $BA08
APERR=$06
>AP $BA08 $7000
APERR=$06
>AP $BA08 $6000
APERR=$06
>AP $BA08 $4000
GO 4000

#GO# ENTRY=4000
RET A=A7 X=07 Y=40 P=F5 S=FD NV-BdIzC
>AP $BA08 $5000
APERR=$06
>
```

Result: resident HIMON `AP pkg dst` help, positive run, command negatives, and
RAM window edges passed with package `$BA08`, destination `$2800`, command hash
`$3AD53794`, entry `$C66D`, and AP service vector `$D735`. For this package,
`$4000` is a valid AP load/run destination and `$5000+` is outside the resident
AP BODY load window.

## 2026-07-07 Resident PACK40 Service Board Proof

After restoring the boot sector and updating HIMON through STR8, HIMON reported
`V 00.0707(1822)`. A first attempt to run `ASM NEW` before reloading flash ASM
correctly showed hash misses (`HSH_NF`). After `L F` reloaded flash ASM, the
resident PACK40 service vectors were present and flash ASM used them to emit AP
metadata.

```text
>D 7E1F 22
7E1F: 49 D7 89 D7 | I...
>ASM NEW
#56AD7400# HSH_NF!
>ORG $2400
#DEF80779# HSH_NF!
...
>L F
L F S19
L @8000
LF OK WR=3966 GO=800C
>D 7E1F 22
7E1F: 49 D7 89 D7 | I...
>ASM NEW
ASM
ASM>$2000: ORG $2400
ASM>$2400: MAIN RTS
ASM>$2401: EXPORT MAIN
ASM>$2401: IMPORT BIO_FTDI_PUT_CSTR
ASM>$2401: END
ASM OK
SEAL> SEAL
SEAL OK
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$0035
SEAL> D 3215 3230
ERR=$03 BO PC=$2401
SEAL> .
ASM BYE
>D 3215 3230
3215: 45 09 01 09 00 00 04 71 | 51 80 57 49 0F 01 0F 11 | E......qQ.WI....
3225: F7 0D 44 E8 8D 1A 5C 67 | CB E7 D0 7F | ..D...\g....
```

The dump at `$3215` starts at the AP export tag. It proves the resident PACK40
service emitted `MAIN` as `71 51 80 57` and `BIO_FTDI_PUT_CSTR` as
`F7 0D 44 E8 8D 1A 5C 67 CB E7 D0 7F`. The `SEAL> D` error is expected because
`D` is a HIMON command; the dump passes after exiting SEAL with `.`.

The direct resident service positive/negative board program also passed. It
calls the two service vectors through `$7E1F` and `$7E21`, verifies accepted
ASCII `'A'`, verifies `PACK3(1,2,3) = $0693`, then verifies invalid ASCII `'@'`
and invalid PACK3 code `$28` are rejected.

```text
>ASM NEW
ASM
ASM>$2000: ORG $2400
ASM>$2400: P40A JMP ($7E1F)
ASM>$2403: P403 JMP ($7E21)
ASM>$2406: MAIN LDA #'A'
ASM>$2408: JSR P40A
ASM>$240B: BCC FAIL
ASM>$240D: CMP #$01
ASM>$240F: BNE FAIL
ASM>$2411: LDA #'@'
ASM>$2413: JSR P40A
ASM>$2416: BCS FAIL
ASM>$2418: LDA #$01
ASM>$241A: LDX #$02
ASM>$241C: LDY #$03
ASM>$241E: JSR P403
ASM>$2421: BCC FAIL
ASM>$2423: CPX #$93
ASM>$2425: BNE FAIL
ASM>$2427: CPY #$06
ASM>$2429: BNE FAIL
ASM>$242B: LDA #$28
ASM>$242D: LDX #$00
ASM>$242F: LDY #$00
ASM>$2431: JSR P403
ASM>$2434: BCS FAIL
ASM>$2436: LDA #$A7
ASM>$2438: BRA DONE
ASM>$243A: FAIL LDA #$E1
ASM>$243C: DONE STA $4900
ASM>$243F: RTS
ASM>$2440: ENTRY MAIN
ASM>$2440: END
ASM OK
SEAL> .
ASM BYE
>G 2406
GO 2406

#GO# ENTRY=2406
RET A=A7 X=00 Y=00 P=B4 S=FD Nv-BdIzc
>D 4900 4900
4900: A7 | .
```

Result: resident PACK40 service vector publication, flash ASM AP metadata use,
and direct positive/negative service behavior all passed on hardware.

## 2026-07-09 OIL .710 Preflight: STR8 Top-Sector Mismatch

The attached board transcript is a preflight finding for `.710` OIL. It proves
that the board can restore bank 0 to bank 3, update HIMON `$C000-$EFFF`, load
the reporter, and load flash ASM. It does not prove the OIL STR8 top-sector
changes. The board is running current HIMON over an older STR8 top sector.

Transcript excerpts:

```text
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y
...
STR8 V0 #5F6A0F7A
ROM $F000
? B E M U 0 1 2 G R
B0 HOLD
STR8>
RESTORE B0->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: y
COPY B0->B3
...
STR8>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
...
PROGRAM C000-EFFF? Y: y...
OK
STR8>
G HIMON
BOOT WARM

HIMON V 00.0709(1413)
>L
L S19
L @7000
L OK=06D5 GO=7000
>L F
L F S19
L @8000
LF OK WR=3966 GO=800C
```

The OIL identity gate fails because `$F000` is still old STR8 boot code, not
the current stable jump table:

```text
>D F000 F008
F000: 78 D8 A2 FF 9A 20 36 F0 | 20 | x.... 6.
```

Current OIL expects:

```text
F000: 4C 09 F0 4C 93 F3 4C 9A F3
```

The vectors also match the older layout rather than the current OIL map:

```text
FFF0: FF FF FF FF FF FF FF FF | FF FF 89 F0 00 F0 9D F0 | ................
```

Current OIL expects `$FFFA-$FFFF = 92 F0 00 F0 A6 F0`.

The dump also shows the older full ASCII STR8 banner and a stored worker in the
older `$FDxx` region. Current OIL expects the shortened banner layout and the
worker stored at `$FCE3-$FFEF`.

Result: OIL full-board testing is blocked until the current STR8 top sector is
loaded and Gate 0 is rerun. Do not run AP load/import or banked AP tests from
this mixed image, because current HIMON calls STR8 service `$F006` after AP body
copy and calls `$F003` for `AP Bn`, while the attached board image does not have
those stable service entries.

## 2026-07-09 OIL .710 Top Writer Assembly Failure

The follow-up board transcript tried to prepare the `topwr-3000.a` top-sector
writer after restoring bank 0 to bank 3, updating HIMON, loading the reporter,
and loading flash ASM.

Observed setup:

```text
HIMON V 00.0709(1446)
>L
L S19
L @7000
L OK=06D5 GO=7000
>L F
L F S19
L @8000
LF OK WR=3966 GO=800C
>ASM
ASM
```

The paste reached the erase/program worker body, then failed before `ASM OK`:

```text
ASM>$315F: WRESET  LDA #$F0
ERR=$06 BAD RANGE PC=$315F
...
ASM>$316E:         END
ERR=$09 BAD FIX PC=$316E
#56AD7400# EXEC ERR=$09
>
```

Result: no top-sector stage or program action was proved, and the active STR8
top sector was not updated by this attempt. The failure was an ASM rel8 fixup
range problem in the sample tool: the erase-timeout path used `BRA WRESET`,
but `WRESET` was too far away after the rest of the worker body assembled. The
sample has been corrected by keeping that erase-timeout reset sequence inline.

Next action: paste the corrected `DOC/GUIDES/ASM/SAMPLES/topwr-3000.a` through
`ASM NEW`, require `ASM OK`, then resume the OIL STR8 top-sector update
procedure from `G 3000`.

## 2026-07-09 OIL .710 STR8 Top-Sector And Gate 3 Import Linker Pass

The follow-up board transcript proved the corrected top-sector writer, the
current STR8 top-stage image, and the Gate 3 import linker patch path. The
top writer assembled cleanly, staged live top-sector flash to `$0A00-$19FF`,
loaded the rebuilt `str8-top-stage-0a00.s19`, and programmed bank 3
`$F000-$FFFF`.

Top-stage staging and flash signatures matched the rebuilt image. The `B7 F6`
call site distinguishes this image from the earlier stale `AF F6` build:

```text
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=00 Y=00 P=77 S=FD NV-BdIZC
>D 1A00 1A03
1A00: 00 AC 00 00 | ....
>L
L S19
L @0A00
L OK=1000 GO=0A00
>D 0D90 0DAF
0D90: 00 02 60 20 B7 F6 20 00 | 02 60 9C 30 7E 20 24 F4 | ..` .. ..`.0~ $.
0DA0: A0 00 B1 CD 8D 16 1A AD | 3C 7E 8D 17 1A A2 00 EC | ........<~......
>G 3003
GO 3003

#GO# ENTRY=3003
RET A=F0 X=00 Y=00 P=77 S=FD NV-BdIZC
>D 1A00 1A03
1A00: 01 AC 00 00 | ....
>D F390 F3AF
F390: 00 02 60 20 B7 F6 20 00 | 02 60 9C 30 7E 20 24 F4 | ..` .. ..`.0~ $.
F3A0: A0 00 B1 CD 8D 16 1A AD | 3C 7E 8D 17 1A A2 00 EC | ........<~......
```

A mistyped `ASMM NEW` produced expected hash-miss noise, then the operator
entered `ASM` and replayed the `banked-rjoin-smoke.a` source. The AP package
loaded to `$3000`, resolved declared import `BIO_FTDI_PUT_CSTR` through
resident RJOIN, and patched all three import relocation rows. The final
debug row shows kind `$06`, patch site `$300F`, resolved target `$E779`,
relocation index `$04`, relocation count `$05`, and import count `$01`:

```text
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$0075
SEAL> LOAD $3200 $3000
LOAD OK=$3000 L=$0028 C=$05
SEAL> .
ASM BYE
>D 1A10 1A17
1A10: 06 0F 30 79 E7 04 05 01 | ..0y....
>D 3006 3008
3006: 20 79 E7 |  y.
>D 3000 3018
3000: 80 00 A2 19 A0 30 20 79 | E7 A9 79 8D 4A 58 A9 E7 | .....0 y..y.JX..
3010: 8D 4B 58 A9 AC 8D 48 58 | 60 | .KX...HX`
>G 3000
GO 3000

BANK RJOIN

#GO# ENTRY=3000
RET A=AC X=19 Y=0E P=F5 S=FD NV-BdIzC
>D 5848 5848
5848: AC | .
>D 584A 584B
584A: 79 E7 | y.
```

The reporter confirmed the assembled source and relocation table:

```text
>G 7000
GO 7000
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$2000
PC=$2028
HIGH=$2028
BYTES=$0028
LINES=$0022
SYMS=$03/$28
FIXUPS=$06/$60
REFS=$00/$A0
TRUNC=NO
MAP END=$B966 UDATA=$5000-6F16
SEAL FL BASE END LEN FNV 01 2000 2028 0028 412277B7
COUNTS SYM FIX REL EXP IMP IMPRES RELCNT 03 06 05 01 01 01 05
PKG @ LEN BODY INST 3200 0075 0028 0000
RELOCS
SL K  SITE TARG
00 02 0003 0019
01 03 0005 0019
02 04 0007 0000
03 05 000A 0000
04 06 000F 0000
ASM REPORT OK
```

Result: pass. The old Gate 3 failure mode (`20 FF FF` at `$3006` and debug
patch site `$300A`) is gone. The import resolver returned `$E779`, the linker
patched the ABS16/LO8/HI8 import sites at `$3007/$300A/$300F`, the loaded
program printed `BANK RJOIN`, and the sample recorded `$5848=$AC` plus
`$584A/$584B=$79/$E7`. Banked AP gates may now proceed from this STR8 top
sector image.

## 2026-07-09 OIL .710 Gate 4 Missing Import Negative Pass

The next board transcript proved that unresolved declared imports fail during
AP load without running the body. The operator first cleared the success byte:

```text
>M 5848
5848: AC 00
>D 5848
5848: 00 | .
```

The package declared `OIL_MISSING_SYMBOL`, referenced it with `JSR`, and would
have written `$AC` to `$5848` only if the body ran:

```text
>ASM NEW
ASM
ASM>$2000: ORG $2000
ASM>$2000: IMPORT OIL_MISSING_SYMBOL
ASM>$2000: MAIN JSR OIL_MISSING_SYMBOL
ASM>$2003: LDA #$AC
ASM>$2005: STA $5848
ASM>$2008: RTS
ASM>$2009: ENTRY MAIN
ASM>$2009: END
ASM OK
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$0042
SEAL> LOAD $3200 $3000
LOAD ERR=$09 BAD FIX
SEAL> .
ASM BYE
>D 5848 5848
5848: 00 | .
```

The reporter confirmed a single unresolved import relocation row and no import
resolution:

```text
>G 7000
GO 7000
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$2000
PC=$2009
HIGH=$2009
BYTES=$0009
LINES=$0008
SYMS=$01/$28
FIXUPS=$01/$60
REFS=$00/$A0
TRUNC=NO
MAP END=$B966 UDATA=$5000-6F16
SEAL FL BASE END LEN FNV 01 2000 2009 0009 9CB2BF7D
COUNTS SYM FIX REL EXP IMP IMPRES RELCNT 01 01 01 01 01 00 00
PKG @ LEN BODY INST 3200 0042 0000 0000
FIXUPS
SL ST MODE SEL SITE BASE NAME
00 04 04   40  2001 2003 OIL_MISSING_SYMBOL
RELOCS
SL K  SITE TARG
00 04 0001 0000
ASM REPORT OK
```

Result: pass. Gate 4 proved the missing-import path returns `LOAD ERR=$09 BAD
FIX`, does not jump into the AP body, and leaves the cleared success byte at
`$5848=00`.

## 2026-07-09 OIL .710 Gate 5 Bankput Rel8 Setup Failure

The first Gate 5 board attempt assembled and packaged the no-import AP body
cleanly:

```text
ASM>$2034:         END
ASM OK
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$006A
SEAL> .
ASM BYE
>G 7000
GO 7000
ASM REPORT
STATUS=OK
START=$2000
PC=$2034
BYTES=$0034
COUNTS SYM FIX REL EXP IMP IMPRES RELCNT 04 05 03 01 00 00 00
RELOCS
SL K  SITE TARG
00 01 000F 002E
01 02 0012 002E
02 03 0017 002E
ASM REPORT OK
```

The subsequent `bankput-3000.a` paste failed before it could stage or program
bank 2. Both attempts in that transcript hit the same assembler rel8 range
issue: early conditional branches targeted the error tails too far below the
main copy body.

```text
ASM>$30BA: BADCFG  LDA #$E0
ERR=$06 BAD RANGE PC=$30BA
ASM>$30BE: STAGEFAIL LDA #$E1
ERR=$06 BAD RANGE PC=$30BE
ASM>$30C2: BADAP   LDA #$E2
ERR=$06 BAD RANGE PC=$30C2
ASM>$30CC:         END
ERR=$09 BAD FIX PC=$30CC
#56AD7400# EXEC ERR=$09
```

Result: no banked AP execution was attempted and Gate 5 remains open. The
failure is in the board-buildable installer sample, not in AP packaging or
STR8. `DOC/GUIDES/ASM/SAMPLES/bankput-3000.a` has been corrected by moving the
small `$E0/$E1/$E2` error exits next to the branches that target them, leaving
only the nearby `$E4` program-failure tail at the end.

## 2026-07-09 OIL .710 Gate 5 Bank Selection Mismatch

The corrected `bankput-3000.a` assembled successfully and ran to `$1A00=$AC`,
proving the rel8 sample fix and STR8 staged-sector/program path for the
selected bank. The paste still had `BANK EQU $00`, so it programmed bank 0
instead of the intended bank 2:

```text
ASM>$3000: BANK    EQU $00
...
ASM>$30D4:         END
ASM OK
SEAL> .
ASM BYE
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=03 Y=00 P=B5 S=FD Nv-BdIzC
>D 1A00 3
1A00: AC 00 00 00 | ....
```

The following `AP B2 $9000 $3000` correctly failed because bank 2 did not
contain the newly written AP envelope:

```text
>AP B2 $9000 $3000
APERR=$07
>D 5848 50
5848: 00 E9 79 E7 85 E9 A5 EA | 65 | ..y.....e
```

The reporter showed this run was the installer source, not the AP body:

```text
ASM REPORT
STATUS=OK
START=$3000
PC=$30D4
BYTES=$00D4
COUNTS SYM FIX REL EXP IMP IMPRES RELCNT 24 0A 00 00 00 00 00
PKG @ LEN BODY INST 0000 0000 0000 0000
ASM REPORT OK
```

Result: Gate 5 remains open. This is an operator/sample-default mismatch, not
an AP loader defect. The installer sample now defaults to `BANK EQU $02`, and
the banked AP/RJOIN smoke sample comments now show `AP B2 $9000 $3000`.

## 2026-07-09 OIL .710 Gate 5 SEAL Prompt Ordering Note

The next retry pasted the corrected `bankput-3000.a` with `BANK EQU $02` and
assembled cleanly:

```text
ASM>$3000: BANK    EQU $02
...
ASM>$30D4:         END
ASM OK
```

The operator then typed `G 3000` at the `SEAL>` prompt, where `G` is not a
SEAL command:

```text
SEAL> G 3000
ERR=$03 BO PC=$30D4
SEAL>
```

Result: Gate 5 remains open, but the bankput code itself is assembled at
`$3000`. Exit SEAL with `.`, then run `G 3000` from HIMON before `AP B2`.
The OIL plan and installer sample comments now spell out this prompt ordering.

## 2026-07-09 OIL .710 Gate 5 Banked AP Without Imports Pass

The next transcript repeated the corrected `bankput-3000.a` paste with
`BANK EQU $02`. The operator again tried `G 3000` once from `SEAL>`, got the
expected `BAD OPER`, then exited to HIMON and ran the assembled installer from
the correct prompt:

```text
ASM>$3000: BANK    EQU $02
...
ASM>$30D4:         END
ASM OK
SEAL> G 3000
ERR=$03 BO PC=$30D4
SEAL> .
ASM BYE
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=03 Y=00 P=B5 S=FD Nv-BdIzC
>D 1A00 3
1A00: AC 00 00 00 | ....
```

The banked AP command then loaded the AP envelope from bank 2 `$9000`, applied
the internal relocation rows, and ran the no-import body from `$3000`:

```text
>AP B2 $9000 $3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=30 Y=30 P=F5 S=FD NV-BdIzC
>D 5848 50
5848: AC E9 2E 30 85 E9 A5 EA | 5A | ...0....Z
```

Result: pass. Gate 5 proved `AP B2 pkg dst`, STR8 staged-sector bank source
copy/program via `$F003`, HIMON AP load from a banked source window, and
internal AP relocations without imports. `$5848=$AC`, `$584A/$584B=$2E/$30`
record the relocated `TARGET` address `$302E`, and `$5850=$5A` proves the
relocated target subroutine executed.

## 2026-07-09 OIL .710 Gate 6 Banked AP With RJOIN Import Pass

The Gate 6 transcript used the corrected bank installer with `BANK EQU $02`,
then installed the already packaged `banked-rjoin-smoke.a` AP envelope into
bank 2 `$9000`:

```text
ASM>$3000: BANK    EQU $02
...
ASM>$30D4:         END
ASM OK
SEAL> .
ASM BYE
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=03 Y=00 P=B5 S=FD Nv-BdIzC
>D 1A00 1A03
1A00: AC 00 00 00 | ....
```

`AP B2 $9000 $3000` then loaded the banked AP source, resolved the declared
resident RJOIN import, patched the import relocation rows, and ran the AP body:

```text
>AP B2 $9000 $3000
GO 3000

BANK RJOIN

#GO# ENTRY=3000
RET A=AC X=19 Y=0E P=F5 S=FD NV-BdIzC
>D 1A10 1A17
1A10: 06 0F 30 79 E7 04 05 01 | ..0y....
>D 3006 8
3006: 20 79 E7 |  y.
>D 5848 5850
5848: AC E9 79 E7 85 E9 A5 EA | 5A | ..y.....Z
```

Result: pass. Gate 6 proves the full OIL path: banked source sector staging,
AP body copy, STR8 resident import linker, HIMON internal relocation handling,
and AP execution. `$3006-$3008 = 20 79 E7` proves the JSR import was patched,
`$1A10-$1A17` shows the final HI8 import row at `$300F` resolved to `$E779`,
`BANK RJOIN` proves the resident string writer ran, `$5848=$AC` is the sample
success byte, and `$584A/$584B=$79/$E7` records the resolved resident target.

## 2026-07-09 OIL .710 Gate 7 Banked AP Error Surface Pass

The Gate 7 transcript reused the good bank 2 `$9000` AP package and cleared
`$5848` before each bad-input command. Each invalid banked AP form either
printed usage or returned an AP error, and every follow-up dump kept the
success byte clear:

```text
>M 5848
5848: AC 00
>AP B3 $9000 $3000
AP [Bn] pkg dst
>D 5848
5848: 00 | .
>M 5848
5848: 00 00
>AP B2 $7000 $3000
APERR=$06
>D 5848 5848
5848: 00 | .
>M 5848
5848: 00 00
>AP B2 $9000 $5000
APERR=$06
>D 5848 5848
5848: 00 | .
>M 5848
5848: 00 00
>AP B2 $9001 $3000
APERR=$07
>D 5848 5848
5848: 00 | .
>M 5848
5848: 00 00
>AP B2 $9000 $9000
APERR=$06
>D 5848 5848
5848: 00 | .
>M 5848
5848: 00 00
>AP B2 $9000 $3000 X
AP [Bn] pkg dst
>D 5848 5848
5848: 00 | .
```

Result: pass. Gate 7 proves bad bank syntax, protected/invalid source or
destination ranges, malformed AP source address, source/destination overlap,
and extra operands fail safely. None of the bad-input paths ran the AP body or
left a false success byte in `$5848`.

## 2026-07-09 OIL .710 Gate 8 Overlap And Staging Regression Pass

The Gate 8 transcript first built a tiny RAM AP package at `$3200` and proved
the old visible-RAM overlap guard still rejects loading it onto itself:

```text
>ASM NEW
ASM
ASM>$2000: ORG $2000
ASM>$2000: MAIN RTS
ASM>$2001: ENTRY MAIN
ASM>$2001: END
ASM OK
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$0028
SEAL> LOAD $3200 $3200
LOAD ERR=$06 BAD RANGE
SEAL> .
ASM BYE
```

The same transcript then cleared `$5848` and reran the banked AP source path
from the already installed bank 2 `$9000` RJOIN package:

```text
>M 5848
5848: 00 00
>AP B2 $9000 $3000
GO 3000

BANK RJOIN

#GO# ENTRY=3000
RET A=AC X=19 Y=0E P=F5 S=FD NV-BdIzC
>D 5848 5850
5848: AC E9 79 E7 85 E9 A5 EA | 5A | ..y.....Z
```

Result: pass. Gate 8 proves the RAM overlap protection remains intact while
the staged bank 2 AP source path still loads, links, and runs after the
negative overlap case.

## 2026-07-09 OIL .710 Gate 9 Existing Regression Shortlist Pass

The Gate 9 transcript exercised the short non-destructive regression list after
the banked AP gates. Bare `M` still prints usage:

```text
>M
M start [end|+cnt].
```

Entering STR8 and letting the countdown finish returned through a cold boot and
RAM clear to the expected HIMON image:

```text
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

STR8

HIMON IN 3S. S=STR8  3 2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0709(1850)
```

Flash ASM still entered and exited cleanly:

```text
>ASM
ASM
ASM>$2000: .
ASM BYE
```

The first `G 7000` after cold boot trapped because `$7000` RAM had been zeroed
by `RAM ZERO OK`; this is expected for a RAM-loaded reporter:

```text
>G 7000
GO 7000

BRK 00 PC=7002
A=01 X=30 Y=30 P=75 S=FB NV-BdIzC
```

The banked RJOIN AP package still ran from bank 2 after the cold boot:

```text
>M 5848
5848: 00 00
>AP B2 $9000 $3000
GO 3000

BANK RJOIN

#GO# ENTRY=3000
RET A=AC X=19 Y=0E P=F5 S=FD NV-BdIzC
>D 5848 5850
5848: AC 00 79 E7 00 00 00 00 | 00 | ..y......
```

For this RJOIN sample only `$5848` and `$584A/$584B` are pass bytes; `$5850`
is not written by the sample and was zero after the cold boot. The transcript
then reacquired the reporter by hash command, warm-booted HIMON, reloaded the
reporter S19 at `$7000`, and `G 7000` printed `ASM REPORT OK`:

```text
>#
HASH     ENTRY K TEXT
...
56AD7400 800C 05 ASM V1
...
5333AEAB C044 03 BOOT_WARM_RESET
...
>BOOT_WARM_RESET
RUN BOOT_WARM_RESET @C044 K=03 ? y
BOOT WARM

HIMON V 00.0709(1850)
>L
L S19
L @7000
L OK=06D5 GO=7000
>G 7000
GO 7000
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$2000
PC=$2001
HIGH=$2001
BYTES=$0001
LINES=$0004
SYMS=$01/$28
FIXUPS=$00/$60
REFS=$00/$A0
TRUNC=NO
MAP END=$B966 UDATA=$5000-6F16
SEAL FL BASE END LEN FNV 01 2000 2001 0001 E50C2ABF
COUNTS SYM FIX REL EXP IMP IMPRES RELCNT 01 00 00 01 00 00 00
PKG @ LEN BODY INST 3200 0028 0000 0000
ASM REPORT OK
```

Result: pass. Gate 9 proves the monitor usage path, STR8 entry/cold boot,
flash ASM entry/exit, banked AP execution after reboot, hash-command lookup,
warm boot, and reloaded reporter all still behave as expected. The transient
`BRK 00 PC=7002` is explained by cold-boot RAM clearing before the reporter was
reloaded.

## 2026-07-09 OIL .710 Gate 0 Identity And Fixed Entries Pass

The final identity capture proves the board is running the current OIL layout
after the STR8 top-sector update. The fixed STR8 entry jump table and CPU
vectors match the release map:

```text
>D F000 F008
F000: 4C 09 F0 4C 93 F3 4C 9A | F3 | L..L..L..
>D FFFA FFFF
FFFA: 92 F0 00 F0 A6 F0 | ......
```

The stored worker head is at the expected `$FCE3` location:

```text
>D FCE3 FCF2
FCE3: 08 78 AD F0 1F C9 04 F0 | 11 C9 02 F0 12 C9 05 F0 | .x..............
```

The resident service cells show PACK40 vectors at `$7E1F-$7E22`, clear import
pointer bytes at `$7E23-$7E24`, the flash service vector at `$7E25`, and the AP
service vector at `$7E2D`, with request/result cells clear:

```text
>D 7E1F 7E24
7E1F: B2 D7 F2 D7 00 00 | ......
>D 7E25 7E40
7E25: F1 D6 00 00 00 00 00 00 | 8E D8 00 00 00 00 00 00 | ................
7E35: 00 00 00 00 00 00 00 00 | 00 00 00 00 | ............
```

The hash command and AP usage text also match the OIL command contract:

```text
># AP
3AD53794 ENTRY=C687 K=01
>AP
AP [Bn] pkg dst
```

Result: pass. Gate 0 proves the board identity and stable service entries for
the same image that passed Gates 3 through 9.

## 2026-07-10 ASM-F2 And Self-Contained STR8-N Topwriter Pass

The attached board transcript first showed that restoring bank 0 to bank 3 had
put the older top sector back in place, then reloaded the current flash ASM:

```text
>L F
L F S19
L @8000
LF OK WR=3969 GO=800C
>ASM
ASM-F2
```

The operator pasted `DOC/GUIDES/ASM/SAMPLES/str8n-topwrite-3000.a` through
`ASM NEW`. The source assembled cleanly under ASM-F2, including the embedded
4K top-sector image:

```text
ASM OK
SEAL> .
ASM BYE
```

The stage half copied the embedded image into `$0A00-$19FF`, verified it, and
left success status in `$1A00-$1A03`:

```text
>G 3000
TW STG
TW OK
>D 1A00 1A03
1A00: 00 AC 00 00
>D 0A00 8
0A00: 4C 09 F0 4C 93 F3 4C 9A | F3 | L..L..L..
>D 14A4 A
14A4: 53 54 52 38 2D 4E BE | STR8-N.
>D 14CE F2
14CE: 0D 0A 53 54 52 38 2D 4E | 20 56 30 20 23 35 46 36 | ..STR8-N V0 #5F6
>D 16E3 F2
16E3: 08 78 AD F0 1F C9 04 F0 | 11 C9 02 F0 12 C9 05 F0 | .x..............
>D 19FA FF
19FA: 92 F0 00 F0 A6 F0 | ......
```

The program half erased/programmed/verified bank 3 `$F000-$FFFF` and left
program success status:

```text
>G 3003
TW PRG
TW OK
>D 1A00 3
1A00: 01 AC 00 00
>D F000 8
F000: 4C 09 F0 4C 93 F3 4C 9A | F3 | L..L..L..
>D FAA4 FAAA
FAA4: 53 54 52 38 2D 4E BE | STR8-N.
>D FACE FAE4
FACE: 0D 0A 53 54 52 38 2D 4E | 20 56 30 20 23 35 46 36 | ..STR8-N V0 #5F6
>D FCE3 F2
FCE3: 08 78 AD F0 1F C9 04 F0 | 11 C9 02 F0 12 C9 05 F0 | .x..............
>D FFFA F
FFFA: 92 F0 00 F0 A6 F0 | ......
```

Result: pass. This proves the visible ASM rename to `ASM-F2` on the board and
proves the one-file `str8n-topwrite-3000.a` path can stage and program the
current STR8-N top sector without a separate top-stage S19 load. The `$FACE`
identity now reads `STR8-N V0 #5F6A0F7A`, with the fixed jump table, worker
head, and vector tail matching the current OIL map.

## 2026-07-10 ASM-F2 Session Reporter Package Failure

The same board transcript then pasted the generated
`DOC/GUIDES/ASM/SAMPLES/asm-session-report-4800.a` under flash ASM-F2. The
reporter source assembled cleanly through `END`, proving the earlier forward
fixup overflow was fixed:

```text
>ASM NEW
ASM-F2
ASM>$2000: ; ASM-NATIVE SESSION REPORTER SNAPSHOT FOR FLASH ASM.
...
ASM>$4E31:         END
ASM OK
```

Packaging that generated reporter failed:

```text
SEAL> PACKAGE $3200
PKG ERR=$02
```

Result: partial pass. The `.a` reporter itself is now ASM-F2-buildable, but
the generated package form was not yet AP-package-clean. Host code inspection
diagnosed `PKG ERR=$02` here as seal bad-flags caused by internal relocation
pressure: the source used many internal `JSR`/`JMP` label operands while the
AP relocation table holds only `ASM_RELOC_MAX=$10` rows. The generator has
been updated to emit fixed literal internal call targets plus `ENTRY START`;
the next board retry should rerun `SEAL`, then `PACKAGE $3200`, then install
with `bank2put-8000-3000.a` and run only as `AP B2 $8000 $4800`.

## 2026-07-10 ASM-F2 Fixed-Address Session Reporter Bank 2 Pass

The follow-up board retry used the regenerated fixed-address reporter source.
The source now emits literal internal `JSR`/`JMP` targets and a fixed
`ENTRY START`, so the AP package has no oversized internal relocation burden:

```text
ASM>$4E31: ; FIXED-ADDRESS AP ENTRY; LOAD/RUN AT THE SAME ORG.
ASM>$4E31:         ENTRY START
ASM>$4E31:         END
ASM OK
SEAL> SEAL
SEAL OK
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$0658
SEAL> .
ASM BYE
>D 3200 8
3200: 41 50 01 58 06 53 0B 01 | 00 | AP.X.S...
```

The board then assembled `bank2put-8000-3000.a`, copied the AP envelope from
`$3200` into the staged bank 2 `$8000` sector, programmed it through STR8, and
left the expected success byte:

```text
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=03 Y=00 P=B5 S=FD Nv-BdIzC
>D 1A00 8
1A00: AC 00 00 00 00 00 00 00 | 00 | .........
```

Running the stored package from bank 2 loaded and executed the reporter at its
fixed `$4800` origin:

```text
>AP B2 $8000 $4800
GO 4800
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$3000
PC=$30D4
HIGH=$30D4
BYTES=$00D4
LINES=$008C
SYMS=$24/$40
FIXUPS=$0A/$80
REFS=$3E/$C0
TRUNC=NO
MAP END=$B969 UDATA=$5000-79A6
COUNTS SYM FIX REL EXP IMP IMPRES RELCNT 24 0A 00 00 00 00 00
PKG @ LEN BODY INST 0000 0000 0000 0000
RELOCS
SL K  SITE TARG
ASM REPORT OK

#GO# ENTRY=4800
RET A=0D X=9D Y=0D P=75 S=FD NV-BdIzC
```

Result: pass. The fixed-address `asm-session-report-4800.a` can now be
assembled by ASM-F2, packaged at `$3200`, installed into bank 2 `$8000`, and
run with `AP B2 $8000 $4800`. The report shown above inspects the
`bank2put-8000-3000.a` installer session, so its counts and empty `RELOCS`
section belong to the installer, not the reporter package itself.

## 2026-07-10 ASM-F2 Life16 Column Bank 2 Partial Pass

The next attached board transcript updated HIMON, entered flash ASM-F2, and
pasted `DOC/GUIDES/ASM/SAMPLES/life16-column-2000.a`. The source assembled
cleanly and packaged at `$3200`:

```text
UPDATE HIMON C000-EFFF? Y: y
...
HIMON V 00.0710(1553)
>ASM
ASM-F2
...
ASM>$215E:         END
ASM OK
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$01DE
```

The session then assembled and ran `bank2put-8000-3000.a`. That helper stores
the package in bank 2 at `$8000`; it returned success and left the expected
status byte:

```text
>G 3000
RET A=AC X=03 Y=00 P=B5 S=FD Nv-BdIzC
>D 1A00 4
1A00: AC 00 00 00 00
```

The final run attempts used `$9000` and `$A000` as the banked AP source
addresses:

```text
>AP B2 $9000 $3000
APERR=$07
>AP B2 $A000 $3000
APERR=$07
```

Result: partial pass. Assembly, `PACKAGE`, and the bank 2 write helper passed,
but the Life AP body has not yet been run from bank 2. The `APERR=$07` results
match a source-address mismatch: the transcript used `bank2put-8000-3000.a`,
so the matching retry is `AP B2 $8000 $3000`. To follow
`DOC/GUIDES/ASM/LIFE16_BANK2_EXAMPLE.md` exactly, rerun the `$9000`
`bankput-3000.a` helper and then run `AP B2 $9000 $3000`.

## 2026-07-10 ASM-F2 Interactive Banked Flash Erase Pass

The attached board runs assembled
`DOC/GUIDES/ASM/SAMPLES/flash-erase-bank.a` cleanly under ASM-F2:

```text
ASM>$33A2:         END
ASM OK
SEAL> .
ASM BYE
```

Input validation rejected sector `1`, and an empty confirmation aborted with
`A=$E0` and `ABORT - NO FLASH WRITE`. A confirmed single-sector run erased and
verified bank 1 `$8000-$8FFF`, returned `A=$AC`, and changed only B1 sector 8
from occupied to erased in the STR8 map.

The `ALL` path then erased and verified all eight bank 1 sectors:

```text
ERASE B1:$8000-$8FFF ... OK
ERASE B1:$9000-$9FFF ... OK
ERASE B1:$A000-$AFFF ... OK
ERASE B1:$B000-$BFFF ... OK
ERASE B1:$C000-$CFFF ... OK
ERASE B1:$D000-$DFFF ... OK
ERASE B1:$E000-$EFFF ... OK
ERASE B1:$F000-$FFFF ... OK
BANK 1 ERASE COMPLETE
RET A=AC
```

STR8 `B` subsequently copied B2 to B1 and B3 to B2, repopulating both backup
banks. A later cancelled `ALL` request again returned `A=$E0` without writing,
and a second confirmed bank 1 `ALL` run passed.

For bank 3, the tool rejected `ALL` and sectors `C-F` with
`? B3 ALLOWS ONLY 8-B`. Confirmed individual erases of B3 sectors `8`, `9`,
`A`, and `B` each returned `A=$AC`; the STR8 map showed exactly those four
sectors erased while `C-F` remained occupied. Finally, STR8 restored B2 to B3
including high flash, the map returned B3 to fully occupied, and HIMON warm
booted as `HIMON V 00.0710(1553)` with ASM-F2 still enterable.

Result: pass. Interactive bank selection, sector validation, exact-`YES`
confirmation, cancellation, B1 single-sector and `ALL` erase, B3 `8-B`
protection, worker erase/verify, map reporting, backup rotation, and B3
recovery are hardware-proven. B0/B2 erase selection and a forced worker
failure remain optional negative/coverage tests.

## 2026-07-10 OIL Terminology Note

OIL now expands to **Overlay Integration Layer**. Earlier `.710` transcript
headings and evidence retain their original acronym wording; they describe the
same AP storage/load/relocation/import/run path under the settled name.

## 2026-07-10 ASM-F2 Flash Erase Package Negative

The attached board transcript started from STR8-N and
`HIMON V 00.0710(1951)`, updated the active HIMON image through the STR8
`UPDATE HIMON C000-EFFF` gate, and warm-booted `HIMON V 00.0710(2024)`.
`L F` then loaded flash ASM-F2:

```text
LF OK WR=3969 GO=800C
>ASM
ASM-F2
```

The transcript reassembled `DOC/GUIDES/ASM/SAMPLES/flash-erase-bank.a`
cleanly, but then tried post-assembly packaging operations that are not the
intended path for this fixed `$3000` RAM tool:

```text
ASM>$33A2:         END
ASM OK
SEAL> SEAL
SEAL ERR=$02 FLAGS=$09
...
ASM>$33A2:         END
ASM OK
SEAL> PACKAGE $3200
PKG ERR=$02
```

Result: negative proof. The source still assembles, and the earlier direct-run
erase proof remains valid. `FLAGS=$09` is `VALID|RELOC_TRUNC`, so `SEAL` and
`PACKAGE` reject this sample because its relocation metadata exceeds the
current ASM-F2 relocation table. The operator path is to leave `SEAL>` with
`.` and run `G 3000`; do not package this erase tool.

A follow-up `HIMON V 00.0710(1553)` transcript pasted the updated source
comments warning not to package the tool. The source still assembled cleanly,
then `PACKAGE $3800` returned `PKG ERR=$02` and `SEAL` returned
`SEAL ERR=$02 FLAGS=$09`, proving the package failure is independent of the
chosen RAM package buffer.

## 2026-07-11 ASM-F2 Bank 0 AP Install Placement Negative

The attached board transcript started from an ASM prompt and assembled
`DOC/GUIDES/ASM/SAMPLES/banked-ap-smoke.a` successfully:

```text
ASM>$2034:         END
ASM OK
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$006A
SEAL> .
ASM BYE
>D 3200 F
3200: 41 50 01 6A 00 53 0B 01 | 00 20 34 20 34 00 5A 9D
```

The follow-on paste of the first `bank0ap-put-3000.a` layout then exceeded
the global symbol budget, kept emitting source bytes from `$3000` toward
`$3200`, and also contained prompt `DB` lines over ASM-F2's source line limit.
The board reported many `ERR=$08 BS`, `ERR=$07 BL`, and `ERR=$09 BAD FIX`
failures, ending with:

```text
ASM>$330B:         END
ERR=$09 BAD FIX PC=$330B
#56AD7400# EXEC ERR=$09
```

Result: negative proof. The AP body/package step is good, but the initial bank
0 writer layout was invalid because it was too symbol-heavy, would clobber the
RAM package buffer while assembling, and had overlong prompt source lines.

Follow-up source direction: break the bank 0 installer into two smaller pieces.
`bank0ap-stage-2000.a` stages the selected bank 0 sector, verifies an erased
hole, and overlays the AP envelope in the staged copy without programming
flash. `bank0ap-commit-2000.a` verifies the staged marker, requires exact
`YES`, and programs the staged sector. The forward test flow uses three 4K
islands: helper/body emission `$2000-$2FFF`, AP overlay/load/run
`$3000-$3FFF`, and RAM AP envelope buffer `$4000-$4FFF`. This keeps the
destructive action separate and leaves both source files comfortably under
ASM-F2 table/line limits.

## 2026-07-11 ASM-F2 Bank 0 AP Stage Operand Negative

The 4K-island retry proved the RAM package address change was good:

```text
ASM>$2034:         END
ASM OK
SEAL> PACKAGE $4000
PKG OK @=$4000 L=$006A
SEAL> .
ASM BYE
>D 4000 F
4000: 41 50 01 6A 00 53 0B 01 | 00 20 34 20 34 00 5A 9D
```

The first split stage source then assembled far enough to print `ASM OK`, but
ASM-F2 rejected the package-header operands that used `label+offset` syntax:

```text
ASM>$20B8:         LDA PKG+1
ERR=$03 BO PC=$20B8
ASM>$20BC:         LDA PKG+3
ERR=$03 BO PC=$20BC
ASM>$20BF:         LDA PKG+4
ERR=$03 BO PC=$20BF
...
>G 2000
B0 AP STAGE
FAIL $1A00=$E1
RET A=E1 ...
```

Result: negative proof of an ASM-F2 operand-expression limit, not a bad AP
envelope. Because the rejected lines did not emit, `READPKG` compared the
`$4000` signature byte `'A'` against `'P'` and returned the false `$E1`
package-header error. `bank0ap-stage-2000.a` now uses named absolute constants
`PKG1`, `PKG3`, and `PKG4`; `bank0ap-commit-2000.a` similarly avoids
`INBUF+n` operands in the confirmation parser.

## 2026-07-11 ASM-F2 Bank 0 AP Explicit $9000 Pass

The patched commit piece assembled cleanly after the stage piece left a valid
staged write for bank 0 `$9000`:

```text
ASM>$21C5:         END
ASM OK
SEAL> .
ASM BYE
>G 2000
GO 2000

B0 AP COMMIT
B0 AP @$9000 L=$006A
TYPE YES TO WRITE> YES
PROGRAM OK
B0 AP @$9000 L=$006A

#GO# ENTRY=2000
RET A=AC X=79 Y=04 P=F5 S=FD NV-BdIzC
>D 1A00 F
1A00: AC 00 90 6A 00 90 00 00 | 00 00 00 00 00 00 00 00
```

The first AP run attempt used `#3000` and correctly printed usage. The
corrected command loaded and ran the bank 0 AP package:

```text
>AP B0 $9000 #3000
AP [Bn] pkg dst
>AP B0 $9000 $3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=30 Y=30 P=F5 S=FD NV-BdIzC
>D 5848 50
5848: AC C3 2E 30 C8 C9 58 5E | 5A
```

Result: pass for the explicit-address bank 0 install path. The proof bytes are
`$5848=$AC`, `$584A/$584B=$2E/$30`, and `$5850=$5A`; the intervening bytes are
not controlled by `banked-ap-smoke.a` and may contain prior RAM contents.

## 2026-07-11 ASM-F2 Bank 0 Printed AP $8000 Pass

After updating HIMON to `V 00.0710(2024)`, the printed AP smoke assembled and
packaged at the 4K RAM envelope address:

```text
ASM>$2032:         END
ASM OK
SEAL> PACKAGE $4000
PKG OK @=$4000 L=$007F
```

The first follow-up paste accidentally stayed in `SEAL>` mode:

```text
SEAL> ASM NEW
ERR=$03 BO PC=$2032
SEAL> ; BANK0AP-STAGE-2000.A
ERR=$03 BO PC=$2032
```

Result: operator-mode negative. The package at `$4000` was good, but stage
source must be pasted only after `SEAL> .` returns to the normal HIMON `>`
prompt.

The corrected stage/commit/run path then passed:

```text
>G 2000
GO 2000

B0 AP STAGE
PKG L=$007F
DST $8000-$FFFF OR ENTER=AUTO>
STAGE OK
STAGED B0 AP @$8000 L=$007F

#GO# ENTRY=2000
RET A=AC X=3A Y=04 P=F5 S=FD NV-BdIzC
...
>G 2000
GO 2000

B0 AP COMMIT
B0 AP @$8000 L=$007F
TYPE YES TO WRITE> YES
PROGRAM OK
B0 AP @$8000 L=$007F

#GO# ENTRY=2000
RET A=AC X=79 Y=04 P=F5 S=FD NV-BdIzC
>AP B0 $8000 $3000
GO 3000

B0 AP RUN

#GO# ENTRY=3000
RET A=AC X=24 Y=0D P=F5 S=FD NV-BdIzC
```

A follow-up reused the same committed bank 0 `$8000` printed AP and changed
only the AP RAM destination:

```text
>AP B0 $8000 $2000
GO 2000

B0 AP RUN

#GO# ENTRY=2000
RET A=AC X=24 Y=0D P=F5 S=FD NV-BdIzC
>AP B0 $8000 $3200
GO 3200

B0 AP RUN

#GO# ENTRY=3200
RET A=AC X=24 Y=0D P=F5 S=FD NV-BdIzC
>AP B0 $8000 $3400
GO 3400

B0 AP RUN

#GO# ENTRY=3400
RET A=AC X=24 Y=0D P=F5 S=FD NV-BdIzC
```

Result: pass. This proves the bank 0 `$8000` install path with an AP body that
visibly prints from resident `BIO_FTDI_PUT_CSTR`. The follow-up also proves
the same banked package relocates and runs at `$2000`, `$3200`, and `$3400`;
`$3000` remains the normal destination, `$3200/$3400` are overlay-island
variants, and `$2000` is a final RAM proof because it overwrites the
helper/source island. A later auto-stage pass, run while the `$8000` package
was still present, selected `$807F` and committed it successfully. That
transcript did not run the `$807F` package before erase; the reporter-specific
follow-up below reran the first-hole path and did run from `$807F`. Finally,
erasing bank 0 `ALL` removed the installed AP packages, and
`AP B0 $8000 $3000` correctly returned `APERR=$07`.

## 2026-07-11 ASM-F2 Bank 0 AP Package Buffer Negative

The same attached transcript later packaged the fixed-address session reporter
at `$2000`:

```text
SEAL> PACKAGE $2000
PKG OK @=$2000 L=$0658
```

The subsequent `bank0ap-stage-2000.a` paste assembled and ran, but reported
the expected bad-package status:

```text
>G 2000
GO 2000

B0 AP STAGE
FAIL $1A00=$E1

#GO# ENTRY=2000
RET A=E1 X=4A Y=0C P=F5 S=FD NV-BdIzC
```

Result: expected negative. The stage helper is deliberately hardwired to read
the AP envelope from `$4000`, while `$2000` is the helper/source emission
island. A package placed at `$2000` is both invisible to the stage helper and
overwritten by the next helper paste. The hand-held bank 0 AP flow must keep
`PACKAGE $4000` as the AP envelope buffer.

## 2026-07-11 ASM-F2 Bank 0 Session Reporter Auto-Hole Pass

The follow-up board transcript used the intended reporter flow: build the
fixed-address session reporter AP envelope at `$4000`, press Enter at the
stage prompt to choose the first bank 0 hole, commit the staged sector, and
run the stored AP at its fixed `$4800` runtime address.

With the earlier `$8000-$807E` print-smoke package still present, auto-hole
selected `$807F` for the `$0658` reporter package:

```text
>G 2000
GO 2000

B0 AP STAGE
PKG L=$0658
DST $8000-$FFFF OR ENTER=AUTO>
STAGE OK
STAGED B0 AP @$807F L=$0658

#GO# ENTRY=2000
RET A=AC X=3A Y=04 P=F5 S=FD NV-BdIzC
```

The commit helper then programmed that staged sector:

```text
>G 2000
GO 2000

B0 AP COMMIT
B0 AP @$807F L=$0658
TYPE YES TO WRITE> YES
PROGRAM OK
B0 AP @$807F L=$0658

#GO# ENTRY=2000
RET A=AC X=79 Y=04 P=F5 S=FD NV-BdIzC
```

Finally, HIMON loaded and ran the stored reporter from bank 0:

```text
>AP B0 $807F $4800
GO 4800
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$2000
PC=$21C5
HIGH=$21C5
BYTES=$01C5
LINES=$00CC
SYMS=$22/$40
FIXUPS=$3B/$80
REFS=$25/$C0
TRUNC=NO
MAP END=$B969 UDATA=$5000-79A6
...
ASM REPORT OK

#GO# ENTRY=4800
RET A=0D X=9D Y=0D P=75 S=FD NV-BdIzC
```

Result: pass. This proves the auto-selected bank 0 storage path for
`asm-session-report-4800.a`: `$4000` is only the temporary RAM envelope
buffer, `$807F` was the first available bank 0 flash hole in this board state,
and `$4800` remains the fixed AP runtime address.

## 2026-07-11 ASM-F2 DC/FWD/Import Data Bank 0 Diagnostic

The attached board transcript next used the combined `DC`, forward data, and
imported-data package. Bank 0 staging and commit both succeeded:

```text
B0 AP STAGE
PKG L=$00F6
DST $8000-$FFFF OR ENTER=AUTO>
STAGE OK
STAGED B0 AP @$86D7 L=$00F6
...
B0 AP COMMIT
B0 AP @$86D7 L=$00F6
TYPE YES TO WRITE> YES
PROGRAM OK
B0 AP @$86D7 L=$00F6
```

The load/run command then failed before the AP body executed:

```text
>AP B0 $86D7 $3000
APERR=$09
```

Result: diagnostic failure for the combined imported-data package, not a bank 0
installer failure. `APERR=$09` is HIMON AP `BAD_FIX`; the next capture should
dump `$7E2D-$7E40` and the staged package at `$10D7` before another AP command
overwrites the stage buffer.

The follow-up AP/result dump showed the combined package parsed cleanly:

```text
>D 7E2D 40
7E2D: 8E D8 01 09 D7 10 00 40 | F6 00 56 11 77 00 0F 01
7E3D: 00 00 EB 10
```

Meaning: AP status `$09`, source `$10D7`, destination `$4000` from the later
retry, package length `$00F6`, body `$1156`, body length `$0077`,
relocation count `$0F`, import count `$01`, and relocation record `$10EB`.

The AP package bytes also showed the expected relocation/import table:

```text
10EB: 0F
10EC: 01 02 03 01 02 03 01 01 01 04 05 06 04 05 06
10FB: 02 04 05 06 42 47 33 58 5B 10 12 13 14 38 3D
1119: 16 16 16 16 16 16 55 08 6F 00 00 00 00 00 00
1137: 45 09 ...
1142: 49 0F 01 0F 11 F7 0D 44 E8 8D 1A 5C 67 CB E7 D0 7F
1153: 42 77 00
```

The import record decodes to `BIO_FTDI_PUT_CSTR` and hashes to `$AEFA0F42`,
matching the resident HIMON FNV row. The remaining failure is therefore live
STR8 `$F006` import-link behavior, not malformed AP package metadata.

The split no-import fixture passed from RAM:

```text
>AP $3200 $3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=08 Y=30 P=F5 S=FD NV-BdIzC
>D 5848 50
5848: AC 00 00 00 10 30 00 00 | 5A
>D 3000 20
3000: 80 0F 10 30 10 30 10 30 | 4F 4B 00 4F CB 02 4F 4B
3010: 60 ...
>D 7E2D 40
7E2D: 8E D8 01 00 00 32 00 30 | BB 00 54 32 67 00 09 00
7E3D: 00 00 14 32
```

Result: pass for `DC C/HB/P`, forward `DB`, forward selected-byte `DB`,
forward `DW`, and internal AP relocation rows. Imported `DB/DW` data remains
open until the live STR8 `$F006` linker behavior is resolved.

The live top-sector head was then checked:

```text
F000: 4C 09 F0 4C 93 F3 4C 9A | F3
```

This matches the current STR8-N jump table, so the combined package failure is
not explained by the older mixed HIMON/current-STR8 image. The next split is
to rerun `banked-rjoin-smoke.a` from RAM for the known import-code `$04/$05/$06`
case, then run `import-data-2000.a` for imported `DB/DW` data only.

The RAM `banked-rjoin-smoke.a` rerun passed on the same board state:

```text
BANK RJOIN
RET A=AC X=19 Y=0E P=F5 S=FD NV-BdIzC
5848: AC 00 79 E7 10 30 00 00 | 5A
3000: 80 00 A2 19 A0 30 20 79 | E7 A9 79 8D 4A 58 A9 E7
7E2D: 8E D8 01 00 00 32 00 30 | 75 00 4D 32 28 00 05 01
```

That proves the current STR8 `$F006` import-link service still handles the
known code-import `$04/$05/$06` package path.

The first RAM `import-data-2000.a` run also loaded and linked successfully, but
the runtime checker source used unsupported `LABEL+1` expressions:

```text
ASM>$201A:         LDA IMPW+1
ERR=$03 BO PC=$201A
ASM>$2035:         LDA IMPD+1
ERR=$03 BO PC=$2035
...
RET A=E1 X=30 Y=30 P=F5 S=FD NV-BdIzC
5848: E1 00 79 79 10 30 00 00 | 5A
3000: 80 06 79 E7 79 E7 79 E7 | 9C 48 58 9C 49 58 9C 4A
7E2D: 8E D8 01 00 00 32 00 30 | A2 00 5C 32 46 00 08 01
```

The `$3002-$3007` body bytes prove imported `DB name`, `DB <name`,
`DB >name`, and `DW name` data constants were patched to `$E779` in RAM.
The `A=E1` runtime failure is from the invalid high-byte checker reusing the
low byte, not from AP import linking. The fixture was revised to use indexed
high-byte reads (`IMPW,Y` and `IMPD,Y`); rerun it for a clean runtime `A=AC`
before returning to the combined bank 0 case.

The indexed-read revision added two more internal absolute relocation rows and
reproduced the AP loader failure:

```text
>AP $3200 $3000
APERR=$09
>D 3000 3020
3000: 80 06 79 E7 79 E7 79 E7 | 9C 48 58 9C 49 58 9C 4A
3010: 58 9C 4B 58 AD 02 30 8D | 4A 58 A0 01 B9 02 30 8D
>D 7E2D 40
7E2D: 8E D8 01 09 00 32 00 30 | B4 00 66 32 4E 00 0A 01
7E3D: 00 00 14 32
```

The service block shows status `$09`, source `$3200`, destination `$3000`,
package length `$00B4`, body `$3266`, body length `$004E`, reloc count `$0A`,
import count `$01`, and relocation record `$3214`. Because there was no `GO`,
the `$5848` result bytes after this command were stale from the earlier failed
runtime checker. The loaded body still proves the imported data bytes were
patched before the loader failed.

The full combined fixture was then rerun directly from RAM and reproduced the
same AP loader failure, so the open case is not bank 0 source storage:

```text
>AP $3200 $3000
APERR=$09
>D 3000 3020
3000: 80 15 16 30 16 30 16 30 | 4F 4B 00 4F CB 02 4F 4B
3010: 79 E7 79 E7 79 E7 60 9C | 48 58 9C 49 58 9C 4A 58
>D 7E2D 40
7E2D: 8E D8 01 09 00 32 00 30 | F6 00 7F 32 77 00 0F 01
7E3D: 00 00 14 32
```

The body head shows forward/internal data and imported data already patched.
This narrows the remaining failure to HIMON AP's larger mixed relocation-table
load path after STR8 import patching and before `GO`. The next capture should
dump the combined loaded-body tail and relocation record with:

```text
D 3030 3078
D 3214 3268
```

The `import-data-2000.a` proof fixture was revised again to keep the runtime
checker fixed to AP destination `$3000`, reading `$3002-$3007` literally. That
keeps the pure import-data proof to the four `$04/$05/$06` relocation rows and
leaves the mixed-relocation failure as its own diagnostic.

The requested combined-package tail and relocation-record dumps show the
remaining mixed-table failure precisely:

```text
>D 3030 3078
3030: 50 58 20 55 30 90 1A A9 | 79 8D 4A 58 A9 E7 8D 4B
3040: 58 A9 16 8D 4C 58 A9 30 | 8D 4D 58 A9 AC 8D 48 58
3050: 60 8D 48 58 60 A2 00 BD | 08 30 DD 6F 20 D0 0C E8
3060: E0 08 D0 F3 A9 5A 8D 50 | 58 38 60 A9 E1 18 60 4F
3070: 4B 00 4F CB 02 4F 4B 32 | A2
>D 3214 3268
3214: 0F 01 02 03 01 02 03 01 | 01 01 04 05 06 04 05 06
3224: 02 04 05 06 42 47 33 58 | 5B 10 12 13 14 38 3D 00
3234: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 16 16
3244: 16 16 16 16 55 08 6F 00 | 00 00 00 00 00 00 00 00
3254: 00 00 00 00 00 00 00 00 | 00 00 00 00 45 09 01 09
3264: 00 00 04 71 51
```

Rows 0-7 of the internal relocation table patched successfully. Row 8 is the
`CMP DCEXP,X` operand at body site `$005B`, target `$006F`; the loaded bytes
at `$305A` remain `DD 6F 20` and should have become `DD 6F 30`. The import
rows after it were already patched by STR8. This places the remaining failure
in HIMON AP's internal relocation pass with a mixed relocation table, after
STR8 import linking and before `GO`.

The fixed-destination `import-data-2000.a` fixture then passed:

```text
>AP $3200 $3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=30 Y=30 P=F5 S=FD NV-BdIzC
>D 5848 5850
5848: AC 00 79 E7 10 30 00 00 | 5A
>D 3000 3020
3000: 80 06 79 E7 79 E7 79 E7 | 9C 48 58 9C 49 58 9C 4A
3010: 58 9C 4B 58 AD 02 30 8D | 4A 58 AD 03 30 8D 4B 58
>D 7E2D 40
7E2D: 8E D8 01 00 00 32 00 30 | 94 00 48 32 4C 00 04 01
7E3D: 00 00 14 32
```

Result: hardware proof for imported `DB name`, `DB <name`, `DB >name`, and
`DW name` data constants through AP import relocation rows `$04/$05/$06`.

Host-side mitigation: `SRC/HIMON/himon.asm` now reloads `HIM_AP_REL_LO/HI`
into `CMDP_PTR_LO/HI` on each HIMON AP internal relocation-loop row, matching
the defensive pattern used by STR8's import linker. Host build
`make -C SRC himon-str8-rom-bin` passes with HIMON end `$EFEE`, still below
STR8 at `$F000`. This HIMON loader fix is not hardware-proven until the updated
image is flashed and the combined RAM fixture runs to `A=AC`.

The updated HIMON image was then installed through STR8:

```text
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
...
PROGRAM C000-EFFF? Y: y...
OK
G HIMON
BOOT WARM

HIMON V 00.0711(2100)
```

The combined fixture was pasted after the update, but the session exited with
`.` and ran `G 3000` directly instead of packaging and loading through AP:

```text
SEAL> .
ASM BYE
>G 3000
GO 3000
RET A=AC X=30 Y=30 P=F5 S=FD NV-BdIzC
>D 5848 F
5848: AC 00 79 E7 85 E9 A5 EA
```

Do not count this as the patched AP-loader proof. It ran whatever stale body
was already at `$3000`, and that stale body can pass after the source has been
freshly assembled at `$2000` because the previously unrelocated row-8 operand
still points at source-side `DCEXP` near `$206F`. The required proof remains
`PACKAGE $3200`, `.`, then `AP $3200 $3000` on the updated HIMON image.

The required AP retest was then run on the updated `HIMON V 00.0711(2100)`
image:

```text
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$00F6
SEAL> .
ASM BYE
>AP $3200 $3000
APERR=$09
>D 3000 3020
3000: 80 15 16 30 16 30 16 30 | 4F 4B 00 4F CB 02 4F 4B
3010: 83 E7 83 E7 83 E7 60 9C | 48 58 9C 49 58 9C 4A 58
>D 3058 3060
3058: 08 30 DD 6F 20 D0 0C E8 | E0
>D 7E2D 40
7E2D: 8E D8 01 09 00 32 00 30 | F6 00 7F 32 77 00 0F 01
7E3D: 00 00 14 32
```

Result: the first HIMON mitigation is not sufficient. The updated image is
active because the resident import address moved to `$E783`, and STR8 still
patches the import data rows. The HIMON internal relocation failure remains the
same: row 8 still leaves the `CMP DCEXP,X` operand as `DD 6F 20` instead of
`DD 6F 30`, and AP returns `$09` before `GO`.

The follow-up scratch dump explains the failure:

```text
>D D8EE D91A
D8EE: EC 3B 7E B0 26 AD 3F 7E | 85 FE AD 40 7E 85 FF 20
D8FE: 7A DC 20 D2 DC B0 08 20 | E2 DC B0 0C 4C 35 DE 20
D90E: F2 DC B0 01 60 20 43 DD | E8 80 D5 A9 00
>D 7E41 7E45
7E41: 79 00 1E 01 4C
>D 00FC 00FF
00FC: FF 00 FC 00
```

The first dump confirms the pointer-reload mitigation was installed. The
scratch bytes identify the real bug: `HIM_AP_TMP2_LO=$1E`, which is
`RELOC_COUNT*2`, and `HIM_AP_TMP_LO=$79`, which is row-8 site `$5B` plus
`$1E`. `HIM_AP_RELOC_SITE_OK_X` was storing the 0/1 abs16 width addend in
`HIM_AP_TMP2_LO`, then calling row-access helpers that reuse that same scratch
byte for table offset math. Row 7 survived because `$58+$1E=$76` was still less
than body length `$77`; row 8 failed because `$5B+$1E=$79`.

Root-cause host fix: `HIM_AP_RELOC_SITE_OK_X` now preserves the 0/1 addend on
the stack with `PHA`/`PLA` across `HIM_AP_RELOC_SITE_LO_X` and
`HIM_AP_RELOC_SITE_HI_X`. The earlier pointer-reload mitigation was removed to
keep the ROM smaller. Host build `make -C SRC himon-str8-rom-bin` now reports
`HIMON V 00.0711(2113)` and HIMON end `$EFE0`, still below STR8 at `$F000`.
This root-cause fix is not hardware-proven until the updated image is flashed
and the combined RAM fixture runs through `PACKAGE $3200` and
`AP $3200 $3000`.

The root-cause fix was then installed and hardware-proven on the board:

```text
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
...
PROGRAM C000-EFFF? Y: y...
OK
G HIMON
BOOT WARM

HIMON V 00.0711(2117)
>L F
L F S19
L @8000
LF OK WR=3C1B GO=800C
```

The combined fixture was pasted, packaged, loaded, and run through AP:

```text
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$00F6
SEAL> .
ASM BYE
>AP $3200 $3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=08 Y=30 P=F5 S=FD NV-BdIzC
>D 5848 5850
5848: AC 00 75 E7 16 30 00 00 | 5A
>D 3000 3020
3000: 80 15 16 30 16 30 16 30 | 4F 4B 00 4F CB 02 4F 4B
3010: 75 E7 75 E7 75 E7 60 9C | 48 58 9C 49 58 9C 4A 58
>D 3058 3060
3058: 08 30 DD 6F 30 D0 0C E8 | E0
>D 7E2D 40
7E2D: 8E D8 01 00 00 32 00 30 | F6 00 7F 32 77 00 0F 01
7E3D: 00 00 14 32
```

Result: pass. The combined AP package proves `DC C/HB/P`, forward `DB`,
forward selected-byte `DB`, forward `DW`, imported `DB/DW` data constants, STR8
import patching, and HIMON mixed internal/import relocation-table loading in one
fresh RAM AP run. The row-8 operand is now correctly relocated as `DD 6F 30`,
AP service status is `$00`, `$5848=$AC`, and `$5850=$5A`.

## 2026-07-12 ASM-F2 Visible Version Pass And Reporter RAM-AP Negative

The board backed up Bank 2 to Bank 1 and Bank 3 to Bank 2, updated HIMON, and
loaded the current low-flash ASM image:

```text
HIMON V 00.0712(1728)
>L F
L F S19
L @8000
LF OK WR=3C29 GO=800C
```

After a STR8 cold boot and RAM clear, the independently stamped components
reported matching versions:

```text
HIMON V 00.0712(1728)
>ASM
ASM-F2 00.0712(1728)
ASM>$2000:
```

Result: pass. This proves the ASM-F2 visible `MMdd(HHmm)` stamp on board and
confirms the `$BC29` low-flash image is active.

The regenerated `asm-session-report-4800.a` then assembled cleanly through
`END` and packaged at `$4000`:

```text
ASM>$4E31:         END
ASM OK
SEAL> PACKAGE $4000
PKG OK @=$4000 L=$0658
SEAL> .
ASM BYE
>D 4000 1F
4000: 41 50 01 58 06 53 0B 01 | 00 48 31 4E 31 06 2B 9B
4010: AE 30 52 01 00 45 09 01 | 09 00 00 05 E1 79 A0 73
```

Result: pass for reporter assembly and AP packaging under the stamped ASM-F2
map. The board-built package remains `$0658`; the separate host-built fixed AP
artifact is `$0610`.

The attempted direct RAM-envelope self-run returned a range error:

```text
>AP $4000 $4800
APERR=$06
>D 4800 1F
4800: 4C 5D 48 4C 8A 85 20 03 | 48 4C 9B 85 20 90 85 A9
4810: 20 4C 84 85 20 93 85 80 | F6 4C 93 85 A9 2F 20 84
```

This is a loader-policy negative, not a reporter failure. The package occupies
`$4000-$4657`; its `$0631` body would occupy `$4800-$4E30`. Those ranges are
disjoint, but HIMON's current RAM-package overlap guard only accepts the
destination-below-source layout. The `$4800` bytes were already present from
assembling at `ORG $4800`, so they do not prove an AP copy occurred.

The size-preserving workaround is `G 4800` for reporting the reporter's own
live assembly session. The persistent proof remains
`AP B0 $hhhh $4800` after storing the `$4000` envelope with the Bank 0
installer; that path does not use the rejected RAM source layout.

## 2026-07-12 Reporter Self-Report Pass And Combined Installer Fixup Negative

The immediate reporter retry used the assembled body already resident at its
fixed origin:

```text
>G 4800
GO 4800
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$4800
PC=$4E31
HIGH=$4E31
BYTES=$0631
LINES=$022F
SYMS=$3C/$40
FIXUPS=$0E/$80
REFS=$0B/$C0
TRUNC=NO
MAP END=$BC29 UDATA=$5000-79AA
...
PKG @ LEN BODY INST 4000 0658 0000 0000
...
ASM REPORT OK

#GO# ENTRY=4800
RET A=0D X=9D Y=0D P=75 S=FD NV-BdIzC
```

Result: pass. ASMREPORT can report its own just-completed ASM-F2 assembly by
running `G 4800`; the report confirms clean session, seal, package, symbol,
fixup, reference, and truncation state.

The subsequent paste of the first combined `bank0ap-put-2000.a` layout reached
the 128-row fixup limit:

```text
ASM>$2352:         LDA DSTHI
ASM>$2355:         JSR HEX
ERR=$09 BAD FIX PC=$2355
...
ASM>$2430:         END
ASM OK
SEAL>
```

The first rejected `JSR HEX` is forward-fixup row 129. Further forward calls,
branches, and message addresses were rejected. The final `ASM OK` only means
`END` accepted the transactionally retained lines; it does not repair skipped
opcodes, so this image was correctly not run.

The source fix keeps the one-run behavior but reorders static data and helpers:
`$2000` jumps over all message text and the I/O/hex helpers to `RUN`. The 20
message-address uses and repeated helper calls now resolve backward and do not
consume fixup rows. A conservative source scan estimates no more than 111
forward references, leaving at least 17 rows under `ASM_FIX_MAX=$80`. This
reordered source awaits a clean zero-`ERR` board paste and `G 2000` proof.

## 2026-07-12 One-Run Bank 0 Installer And Stored Reporter Pass

The reordered `bank0ap-put-2000.a` retry assembled without any `ERR=` rows:

```text
ASM>$2458:         END
ASM OK
SEAL> .
ASM BYE
>G 2000
GO 2000

B0 AP PUT
PKG L=$0658
DST $8000-$FFFF OR ENTER=AUTO>
STAGE OK
B0 AP @$8000 L=$0658
TYPE YES TO WRITE> YES
PROGRAM OK
B0 AP @$8000 L=$0658

#GO# ENTRY=2000
RET A=AC X=42 Y=04 P=F5 S=FD NV-BdIzC
>D 1A00 6
1A00: AC 00 80 58 06 80 00
```

Result: pass. The combined transient validated the `$4000` reporter envelope,
auto-selected the first erased Bank 0 hole at `$8000`, staged the sector,
required exact `YES`, programmed and verified the sector, cleared the ready
marker, and returned `$AC` in one run.

HIMON then loaded and ran the persistent reporter package from Bank 0:

```text
>AP B0 $8000 $4800
GO 4800
ASM REPORT
STATUS=OK
ERRLINE=$0000
START=$2000
PC=$2458
HIGH=$2458
BYTES=$0458
LINES=$020A
SYMS=$3C/$40
FIXUPS=$62/$80
REFS=$B0/$C0
TRUNC=NO
MAP END=$BC29 UDATA=$5000-79AA
...
SEAL FL BASE END LEN FNV 09 2000 2458 0458 00000000
COUNTS SYM FIX REL EXP IMP IMPRES RELCNT 3C 62 10 00 00 00 00
...
ASM REPORT OK

#GO# ENTRY=4800
RET A=0D X=9D Y=0D P=75 S=FD NV-BdIzC
```

Result: pass. This completes the combined assemble/stage/confirm/program/verify
and Bank 0 AP load/run proof. The report confirms the source used `$62` (98)
of `$80` fixup rows, exactly matching the static correction, and the report
itself was not truncated.

The transient's seal row has `FL=09` and relocation count `$10`, meaning its
package relocation metadata reached the 16-row limit and truncated. This is
expected for a fixed `$2000` direct-run transient and does not affect `G 2000`.
Do not package this installer. The persistent reporter package at
`B0:$8000`, loaded at `$4800`, is now board-proven.

## 2026-07-12 Compact `$3000` Package Partial Pass

The updated board image reported `HIMON V 00.0712(2010)` and
`ASM-F2 00.0712(2010)`. The generated fixed-address reporter assembled at
`$4800-$4E77`, then packaged successfully at the new compact address:

```text
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$069E
>AP $3000 $4800
GO 4800
...
MAP END=$BC5F UDATA=$5000-61AA
LOW=$0200-1A00 UPPER=$61AA-7E00
...
ASM REPORT OK
```

Result: pass for `PACKAGE $3000`, the relocated low/high RAM map, and the
corrected upward non-overlapping RAM load. Entering `AP $3000 $4800` at the
`SEAL>` prompt first produced `ERR=$03 BO`, correctly proving prompt ownership;
the same command succeeded from HIMON.

The subsequent Bank 0 install attempt used a modified paste with
`ORG $3000`. The repository source is `bank0ap-put-2000.a` with `ORG $2000`.
The modified transient therefore emitted through `$3000-$3458` and overwrote
the reporter envelope before it ran. Its final result was the expected header
failure for that corrupted input:

```text
>G 3000
B0 AP PUT
FAIL $1A00=$E1
```

This is not a `PKG_BASE=$3000` installer failure. It is a test-source address
collision. The intervening `AP B0 $8000 $4000` was also intentionally too late
to report names from the installer session: bank staging had already reused
`$0200-$19FF`, and the resulting report showed valid high-table counts with
corrupted symbol/fixup text. That negative capture confirms the documented
reporter rule: preload the reporter before the target ASM session and use
`G 4800` afterward.

Still pending: rerun the unmodified installer at `G 2000`, auto placement,
two packages in one sector, the preload-then-report lifecycle, and the `$1000`
hardware envelope boundary.

## 2026-07-12 Compact `$3000` Installer And Same-Sector Packing Pass

The retry used the repository installer unchanged at `ORG $2000`. The reporter
again packaged at `$3000` with `L=$069E`; direct `AP $3000 $4800` printed the
new map and `ASM REPORT OK`. Re-pasting `bank0ap-put-2000.a`, exiting, and
running `G 2000` then completed the compact install path:

```text
B0 AP PUT
PKG L=$069E
STAGE OK
B0 AP @$8658 L=$069E
PROGRAM OK
B0 AP @$8658 L=$069E
RET A=AC ...
```

Result: pass for `PKG_BASE=$3000`, the `ORG $2000` transient, AUTO placement,
stage/program/verify, and placement immediately after an existing package.
The existing Bank 0 package occupied `$8000-$8657`; AUTO selected `$8658`,
the exact next byte.

The print-smoke AP then packaged at `$3000` with `L=$007F`. An accidental
`G 2000` before re-pasting the installer reached unresolved import placeholder
code and trapped with `BRK 00 PC=0007`; a package BODY with resident imports is
not a direct-run image. After the installer was correctly re-pasted at `$2000`,
AUTO produced:

```text
B0 AP PUT
PKG L=$007F
STAGE OK
B0 AP @$8CF6 L=$007F
PROGRAM OK
B0 AP @$8CF6 L=$007F
RET A=AC ...
```

The layouts are exactly contiguous inside `$8000-$8FFF`:

```text
$8000-$8657  existing package, $0658 bytes
$8658-$8CF5  new reporter,      $069E bytes
$8CF6-$8D74  print smoke,       $007F bytes
```

This hardware-proves AUTO append and multiple independent AP envelopes sharing
one flash sector. Pending checks are execution of `B0:$8CF6`, the reporter
preload-then-`G 4800` lifecycle, and the exact `$1000/$1001` envelope boundary.

## 2026-07-12 Stored Same-Sector AP Execution Pass

The newly appended print-smoke package was loaded and run three consecutive
times from its unaligned same-sector address:

```text
>AP B0 $8CF6 $3000
GO 3000

B0 AP RUN

#GO# ENTRY=3000
RET A=AC ...
```

All three runs printed `B0 AP RUN` and returned `$AC`. This closes execution,
resident import linking, and repeatability for an AP appended after two other
packages in the same `$8000-$8FFF` sector.

The reporter was then preloaded from `B0:$8658` to `$4800`. Its automatic
first execution printed valid high-table counts and `ASM REPORT OK`, while the
symbol/fixup names were corrupted as expected because the banked load itself
had just reused `$0200-$19FF`. The reporter code is now resident at `$4800`;
assemble a fresh target session next and invoke `G 4800` without another
banked `AP` to complete the lifecycle proof.

## 2026-07-12 Reporter Version/Origin Negative Proof

The board was updated to `HIMON/ASM-F2 00.0712(2115)` and flash ASM loaded as
`LF OK WR=3C6D GO=800C`. Bank 0 `$8000` still held the reporter package built
under ASM-F2 `00.0712(2010)`. That source identified flash end `$BC5F` and used
the old ASM output helpers `$8584/$858A/$8590/$8593/$859B`; the `2115` map ends
at `$BC6D` and places the corresponding helpers at
`$8592/$8598/$859E/$85A1/$85A9`.

The wrong-destination check behaved decisively:

```text
>AP B0 $8000 $3000
GO 3000

BRK 00 PC=485F
A=01 X=30 Y=30 P=75 S=FB NV-BdIzC
```

The reporter is fixed at `$4800`; loading its body at `$3000` leaves literal
`$48xx` calls pointing outside the relocated body. Loading the same stale
package at its correct origin reached the reporter but its old helper calls
produced concatenated and corrupt output:

```text
>AP B0 $8000 $4800
GO 4800
ASM REPORTMAP END=$ UDATA=$SESSION...
```

This second load was also after the target ASM session, so bank staging had
already reused `$0200-$19FF`. Result: expected negative proof for both reporter
image coupling and lifecycle ordering. It is not a pass for the reporter
lifecycle or the new carry-return ABI. The next run must rebuild/reinstall the
reporter from the current ASM map, preload it at `$4800` before the target
session, and invoke only `G 4800` afterward.

## 2026-07-15 Deferred ASM-F2 Proof Progress

The board ran matching `HIMON/ASM-F2 00.0715(1804)` with the flash ASM image
loaded as `LF OK WR=3C6D GO=800C`.

The address-normalized `flash-erase-bank-transient-2000.a` assembled through
`$23A5` and ran at its maintained `$2000` address. The destructive Bank 0
`ALL` case erased and verified all eight sectors:

```text
>G 2000
BANKED FLASH ERASE
BANK 0-3> 0
SECTOR 8-F OR ALL> ALL
TYPE YES TO ERASE> YES
...
ERASE B0:$8000-$8FFF ... OK
...
ERASE B0:$F000-$FFFF ... OK
BANK 0 ERASE COMPLETE
RET A=AC X=3B Y=11 P=F5 ... C
```

Result: pass for the `$2000` transient address, full-bank erase/verify path,
success status, and carry-set return. This closes the deferred normalized
flash-erase proof.

The current map-generated session reporter assembled at `$4800-$4E7F` and
packaged at the compact RAM base:

```text
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$06A6
```

After Bank 0 was erased, `bank0ap-put-transient-2000.a` installed that package
at the explicit unaligned address `$8100`:

```text
B0 AP PUT
PKG L=$06A6
DST $8000-$FFFF OR ENTER=AUTO> $8100
STAGE OK
B0 AP @$8100 L=$06A6
TYPE YES TO WRITE> YES
PROGRAM OK
B0 AP @$8100 L=$06A6
RET A=AC X=42 Y=04 P=F5 ... C
```

`AP B0 $8100 $4800` then loaded the fixed-origin reporter. It printed the
current map (`END=$BC6D`, `UDATA=$5000-$61AA`), ended with `ASM REPORT OK`,
and returned `A=$00` with carry set. Result: pass for current reporter rebuild,
`PACKAGE $3000`, Bank 0 install, fixed-origin load, and clean reporter return.
Because that immediate report followed the bank staging operation, the fresh
target preload lifecycle remains open.

The direct return-wrapper fixture passed both branches:

```text
>G 2000
RET A=AC X=30 Y=30 P=F5 ... C
>G 2004
RET A=E1 X=34 Y=30 P=F4 ... c
```

Result: pass for HIMON preserving and displaying target carry on direct `G`.

The failed-session test then entered bare `NOPE`. ASM-F2 emitted no error and
exited normally because a lone unknown word is accepted as a pending label.
This was an invalid negative fixture, not a sticky-status failure. The test
card now uses the documented `FOO BAR` case to force `ERR=$01 BAD MNEM`.

Still pending: preload the resident reporter, run `FOO BAR`, then use
`G 4800`; repeat with a clean target session; package the exact `$1000`
fixture; and reject the `$1001` fixture. Neither boundary fixture appears in
this transcript.

## 2026-07-15 Reporter Lifecycle Pass And Boundary-Fixture Negative

The resident map-matched reporter at `$4800` captured an unambiguous failed
ASM session. Both tested bad-mnemonic forms behaved correctly:

```text
ASM>$2000: NOPE #$01
ERR=$01 BM PC=$2000
...
#56AD7400# EXEC ERR=$01

ASM>$2000: FOO BAR
ERR=$01 BM PC=$2000
...
#56AD7400# EXEC ERR=$01
```

After a fresh `FOO BAR` failure, direct `G 4800` printed `STATUS=$01`,
`ERRLINE=$0001`, `PC/HIGH=$2000`, and zero bytes/symbols/fixups/references.
It ended with `ASM REPORT OK` and preserved failure in its return ABI:

```text
#GO# ENTRY=4800
RET A=01 X=DC Y=0D P=74 S=FD NV-BdIzc
```

A following clean session assembled `LDA #$AC` and `RTS` through `$2003`.
Without reloading the reporter, `G 4800` printed `STATUS=OK`,
`PC/HIGH=$2003`, `BYTES=$0003`, and returned:

```text
#GO# ENTRY=4800
RET A=00 X=DC Y=0D P=77 S=FD NV-BdIZC
```

Result: pass for sticky ASM command failure, reporter failure status
`A=$01/C=0`, clean-session reset, reporter success status `A=$00/C=1`, and the
required preload-then-direct-`G 4800` lifecycle.

The two package-boundary attempts exposed an error in the fixtures. ASM-F2
rejected each oversized single `DS` count before emitting bytes:

```text
DS $0FE0,$A5
ERR=$06 BAD RANGE PC=$2000
...
PKG OK @=$3000 L=$0020

DS $0FE1,$A5
ERR=$06 BAD RANGE PC=$2000
...
PKG OK @=$3000 L=$0020
```

This is the documented `DS count > $FF` negative. Because no BODY bytes were
emitted, `$0020` is the correct empty-metadata package length; it proves
neither the `$1000` acceptance nor `$1001` rejection boundary. The corrected
fixtures use fifteen initialized `DS $FF,$A5` chunks plus `DS $EF,$A5` or
`DS $F0,$A5`. Those two corrected package runs remain pending.

## 2026-07-15 Exact AP Envelope Boundary Pass

The corrected package-only fixtures used legal byte-sized initialized `DS`
chunks. The exact fixture emitted BODY `$2000-$2FDF` and reached the expected
exclusive end before sealing:

```text
ASM>$2EF1:         DS $EF,$A5
ASM>$2FE0:         END
ASM OK
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$1000
>D 3000 4
3000: 41 50 01 00 10
>D 3FF8 FFF
3FF8: A5 A5 A5 A5 A5 A5 A5 A5
```

Result: pass. The maximum accepted envelope is exactly `$1000` bytes,
including `$0020` metadata and `$0FE0` BODY bytes. Its header carries
little-endian length `00 10`, and the BODY reaches the final byte at `$3FFF`.

The oversize fixture added one BODY byte and reached `$2FE1` before sealing:

```text
ASM>$2EF1:         DS $F0,$A5
ASM>$2FE1:         END
ASM OK
SEAL> PACKAGE $3000
PKG ERR=$06
SEAL> .
ASM BYE
#56AD7400# EXEC ERR=$06
```

Result: pass. The `$1001` envelope is rejected as assembler status `$06`
(`BAD RANGE`) before a package is produced. The earlier expected `$02` was a
test-card error: `$02` is used for seal-policy failures, while the explicit
package-length guard returns `$06`.

Together with the reporter lifecycle and direct carry proofs, this closes the
deferred compact AP RAM-layout board slice on `HIMON/ASM-F2 00.0715(1804)`.

## 2026-07-18 HIMON/STR8 Size-Pass Onboard Installation And Fixed-Surface Pass

The board began on the older STR8 surface with `M` still present and completed
the confirmed backup rotation. The old STR8 `U` gate then installed the new
HIMON payload before the recovery-sector change:

```text
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
...
PROGRAM C000-EFFF? Y: y...
OK
STR8-N>
G HIMON
BOOT WARM

HIMON V 00.0718(2041)
```

The board erased bank 3 `$8000-$BFFF` with the RAM-resident erase transient,
then loaded the matching current ASM-F2 image:

```text
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=03 Y=00 P=B5 S=FD Nv-BdIzC
>L F
L F S19
L @8000
LF OK WR=3C6D GO=800C
>ASM NEW
ASM-F2 00.0718(2045)
```

The regenerated `str8n-topwrite-transient-3000.a` assembled through `END` and
staged its embedded sector without changing flash:

```text
>G 3000
GO 3000
TW STG
TW OK

#GO# ENTRY=3000
RET A=AC X=20 Y=05 P=F5 S=FD NV-BdIzC
>D 1A00 1A03
1A00: 00 AC 00 00 | ....
>D 0A00 0A08
0A00: 4C 09 F0 4C 7C F3 4C 83 | F3 | L..L|.L..
>D 0D83 0D8A
0D83: A9 03 8D 2F 7E 6C 2D 7E | .../~l-~
>D 10C2 10C5
10C2: 7A 0F 6A 5F | z.j_
>D 1726 1735
1726: 08 78 AD F0 1F C9 02 F0 | 0D C9 05 F0 0E C9 06 F0 | .x..............
>D 19FA 19FF
19FA: 92 F0 00 F0 A6 F0 | ......
```

The destructive half then erased, programmed, and verified bank 3
`$F000-$FFFF`. The live ROM dumps matched every staged checkpoint:

```text
>G 3003
GO 3003
TW PRG
TW OK

#GO# ENTRY=3003
RET A=AC X=20 Y=05 P=F5 S=FD NV-BdIzC
>D 1A00 1A03
1A00: 01 AC 00 00 | ....
>D F000 F008
F000: 4C 09 F0 4C 7C F3 4C 83 | F3 | L..L|.L..
>D F383 F38A
F383: A9 03 8D 2F 7E 6C 2D 7E | .../~l-~
>D F6C2 F6C5
F6C2: 7A 0F 6A 5F | z.j_
>D FD26 FD35
FD26: 08 78 AD F0 1F C9 02 F0 | 0D C9 05 F0 0E C9 06 F0 | .x..............
>D FFFA FFFF
FFFA: 92 F0 00 F0 A6 F0 | ......
```

The newly installed recovery monitor entered with the retired `M` command
absent and the deliberately rebuilt config pocket back at `B0 HOLD`:

```text
STR8-N V0 #5F6A0F7A
ROM $F000
? B E U 0 1 2 G R
B0 HOLD
STR8-N>
G HIMON
BOOT WARM

HIMON V 00.0718(2041)
```

Result: hardware pass for the HIMON-first/STR8-second update order, current
low-flash ASM reload, top-writer stage/program/verify, `$F006->$F383` adapter,
STR8 identity, worker relocation to `$FD26`, hardware vectors, new command
surface, and warm entry to the current HIMON.

The AP import-link regression remains open. The transcript assembled
`banked-rjoin-smoke.a` but ran its body directly with `G 2000`, without first
issuing `PACKAGE` and `LOAD`. The unresolved import trapped at
`BRK F0 PC=FFFE`; that is an invalid lifecycle invocation, not evidence of a
resident-linker failure. Direct `G 2000` on the no-import smoke returned
`A=$AC/C=1`. Finally, `G 7000` cold-booted and printed `RAM ZERO OK`, so the
following `G 7200` trapped on cleared RAM. Rerun the imported fixture through
`PACKAGE $3200`, `LOAD $3200 $3000`, and `G 3000` without an intervening cold
boot.

## 2026-07-18 Simplified HIMON D Absolute-Range Pass

The follow-up board transcript exercised the size-pass `D` command without
the retired continuation, short-end, or search forms:

```text
>D
D [a [b]]
>D 1A00
1A00: 00 | .
>D 1A03 04
D [a [b]]
>D 1A00 1A01
1A00: 00 00 | ..
```

Result: bare `D` reports usage, one address displays one byte, and the second
address is absolute. `D 1A03 04` is therefore invalid because `$0004` is not
strictly greater than `$1A03`; there is no legacy short-end completion.

The board then proved inclusive page and full-address-space ranges:

```text
>D 0 FF
0000: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
...
00F0: 10 01 01 00 00 06 0F 46 | 00 02 FA 00 FF 00 F0 00 | .......F........
>D 0 FFFF
0000: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
...
FFF0: FF FF FF FF FF FF FF FF | FF FF 92 F0 00 F0 A6 F0 | ................
>D FFFA FFFF
FFFA: 92 F0 00 F0 A6 F0 | ......
>
```

Result: pass. `D 0 FF` displays `$0000-$00FF`; `D 0 FFFF` traverses the
complete inclusive 16-bit address space, reaches `$FFFF`, and returns to the
prompt. The final focused vector dump matches the installed STR8 image. This
closes the simplified resident dump/range board regression. It does not add AP
import-link evidence; that package/load/run proof remains pending.

## 2026-07-18 HIMON-Resident AP Linker RAM Import Pass

The follow-up board transcript used the required package/load/run lifecycle on
HIMON `00.0718(2041)` and ASM-F2 `00.0718(2045)`. The imported RJOIN smoke
packaged at `$3200`, loaded its `$0029`-byte body at `$3000`, printed through
the resolved resident routine, and returned success:

```text
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$0076
SEAL> LOAD $3200 $3000
LOAD OK=$3000 L=$0029 C=$05
...
>G 3000
GO 3000

BANK RJOIN

#GO# ENTRY=3000
RET A=AC X=1A Y=0E P=F5 S=FD NV-BdIzC
>D 5848 5850
5848: AC 00 05 E7 00 00 00 00 | 00 | .........
```

The linker debug row records a final HI8 import patch at `$300F`, resolved to
the current `BIO_FTDI_PUT_CSTR` address `$E705`, with five relocation rows and
one import:

```text
>D 1A10 1A17
1A10: 06 0F 30 05 E7 04 05 01 | ..0.....
```

The HIMON AP request/result cells independently show service vector `$D5BF`,
operation `$01` (`LOAD`), status `$00`, source `$3200`, destination `$3000`,
package length `$0076`, body pointer `$324D`, body length `$0029`, relocation
count `$05`, and import count `$01`:

```text
>D 7E2D 7E40
7E2D: BF D5 01 00 00 32 00 30 | 76 00 4D 32 29 00 05 01 | .....2.0v.M2)...
7E3D: 00 00 14 32 | ...2
```

Result: pass. `BANK RJOIN`, `A=$AC/C=1`, the recorded `$E705` address, linker
debug row, and AP status `$00` close the positive RAM import regression for
the linker moved from STR8 into HIMON. The missing-import/no-partial-patch and
banked-source regressions remain separate open gates.

The capture also ran the resident FNV helper interactively. In particular,
`STAY HIGHDRATED` produced `$5F6A0F7A`, matching the installed STR8 identity:

```text
RJOIN HASH STATS
TEXT> #
LEN=01 XOR=23 FNV=260C9112
TEXT> STAY HIGHDRATED
LEN=0F XOR=33 FNV=5F6A0F7A
TEXT> ZZX
LEN=03 XOR=58 FNV=27ECE097
```

Finally, a no-import package at `$3200` produced two expected range errors:

```text
>AP B0 $3200 $9000
APERR=$06
>AP $3200 $8000
APERR=$06
```

`AP B0` selects a banked flash source and therefore rejects source `$3200`;
resident AP execution accepts destinations only in `$2000-$4FFF`, so `$9000`
and `$8000` are invalid destinations. These are `BAD RANGE` negatives, not an
AP-loader regression. While that RAM package remains intact, its matching
positive command is `AP $3200 $3000`.

The matching direct-RAM positive then loaded and ran the same package:

```text
>AP $3200 $3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=30 Y=30 P=F5 S=FD NV-BdIzC
>D 5848 5850
5848: AC 00 30 30 00 00 00 00 | 5A | ..00....Z
```

Result: pass. `$5848=$AC` and carry set are the fixture success result,
`$584A/$584B=$30/$30` record relocated `TARGET=$3030`, and `$5850=$5A`
proves that target executed. This closes the direct-RAM no-import AP positive
and pairs it with the preceding source/destination range negatives.

## 2026-07-19 HIMON AP Linker Missing-Import Atomicity Pass

The current-image negative used the frozen
`ASM/SAMPLES/missing-import-atomicity-2000.a` fixture. It declares valid
`BIO_FTDI_PUT_CSTR` first and missing `OIL_MISSING_SYMBOL` second, then emits
the corresponding JSRs at body offsets `$0007` and `$000A`. The visible
assembler was `ASM-F2 00.0718(2045)`.

Board transcript:

```text
ASM NEW
ASM-F2 00.0718(2045)
ASM>$2000: ; MISSING-IMPORT-ATOMICITY-2000.A
ASM>$2000: ; CURRENT-IMAGE AP LINKER NEGATIVE FIXTURE.
ASM>$2000: ;
ASM>$2000: ; IMPORT ORDER IS DELIBERATE: VALID FIRST, MISSING SECOND.
ASM>$2000: ; AFTER AP $3200 $3000 FAILS WITH $09, BOTH JSR OPERANDS AT
ASM>$2000: ; $3007-$300C MUST STILL BE $FFFF. DO NOT REORDER THE IMPORTS OR CALLS.
ASM>$2000:
ASM>$2000:         ORG $2000
ASM>$2000:
ASM>$2000:         IMPORT BIO_FTDI_PUT_CSTR
ASM>$2000:         IMPORT OIL_MISSING_SYMBOL
ASM>$2000:
ASM>$2000: MAIN    BRA RUN
ASM>$2002:         ENTRY MAIN
ASM>$2002:
ASM>$2002: RUN     LDA #$E4
ASM>$2004:         STA $5848
ASM>$2007:         JSR BIO_FTDI_PUT_CSTR
ASM>$200A:         JSR OIL_MISSING_SYMBOL
ASM>$200D:         LDA #$AC
ASM>$200F:         STA $5848
ASM>$2012:         SEC
ASM>$2013:         RTS
ASM>$2014:         END
ASM OK
SEAL> PACKAGE $3200
PKG OK @=$3200 L=$005F
SEAL> .
ASM BYE
>M 5848 00
M start [end|+cnt]
>M 5848
5848: E4 00
>AP $3200 $3000
APERR=$09
>D 5848
5848: 00 | .
>D 3007 300C
3007: 20 FF FF 20 FF FF |  .. ..
>D 7E2D 7E40
7E2D: BF D5 01 09 00 32 00 30 | 5F 00 4B 32 14 00 02 02 | .....2.0_.K2....
7E3D: 00 00 14 32 | ...2
>
```

The tight `M 5848 00` form correctly produced usage under the current modify
grammar. Interactive `M 5848` then changed the previous direct-run marker from
`$E4` to `$00` before the AP attempt.

Result: pass. Visible `APERR=$09` agrees with `HIM_AP_STATUS=$09` at `$7E30`.
The request cells record source `$3200`, destination `$3000`, package length
`$005F`, body pointer `$324B`, body length `$0014`, two relocation rows, and
two imports. `$5848` remained `$00`, proving the body was not entered. Most
importantly, `$3007-$300C = 20 FF FF 20 FF FF`: the valid first import was not
patched before validation discovered the missing second import. This closes
the HIMON-resident linker's missing-import/no-partial-patch gate. The
banked-source RJOIN regression remains open.

## 2026-07-19 HIMON AP Linker Banked-Source RJOIN Pass

The current-image positive used the frozen `ASM/SAMPLES/banked-rjoin-smoke.a`
package and `ASM/SAMPLES/bankput-transient-3000.a` installer. The AP envelope
was already present at `$3200` with length `$0076`. The installer was visibly
pinned to Bank 2, package `$3200`, and destination `$9000`; the visible
assembler was `ASM-F2 00.0718(2045)`.

Board transcript:

```text
D 3200 3204
3200: 41 50 01 76 00 | AP.v.
>ASM NEW
ASM-F2 00.0718(2045)
ASM>$2000: ; BANKPUT-TRANSIENT-3000.A
ASM>$2000: ; BOARD-BUILDABLE AP ENVELOPE INSTALLER FOR FLASH BANKS 0-2.
ASM>$2000: ;
ASM>$2000: ; DEFAULTS TARGET BANK 2 FOR OVERLAY INTEGRATION LAYER (OIL) GATE TESTING.
ASM>$2000: ; EDIT BANK, PKG, AND DST ONLY WHEN YOU INTEND A DIFFERENT TARGET, THEN
ASM>$2000: ; ASSEMBLE WITH FLASH ASM, EXIT SEAL WITH '.', THEN RUN G 3000.
ASM>$2000: ; BANK 0-2 IS THE PHYSICAL FLASH BANK. PKG IS A RAM AP ENVELOPE, USUALLY
ASM>$2000: ; WRITTEN BY PACKAGE $3200. DST IS THE BANK-WINDOW ADDRESS WHERE THE AP
ASM>$2000: ; ENVELOPE SHOULD LIVE, FOR EXAMPLE $9000.
ASM>$2000: ;
ASM>$2000: ; THIS PRESERVES THE REST OF THE 4K SECTOR:
ASM>$2000: ;   BANK SECTOR -> $0A00 SECTOR STAGING BUFFER
ASM>$2000: ;   OVERLAY AP ENVELOPE AT DST OFFSET
ASM>$2000: ;   PROGRAM STAGED SECTOR BACK TO BANK
ASM>$2000: ;
ASM>$2000: ; STATUS:
ASM>$2000: ;   $1A00 = $AC OK
ASM>$2000: ;   $1A00 = $E0 BAD BANK OR DST
ASM>$2000: ;   $1A00 = $E1 STAGE-COPY FAILED
ASM>$2000: ;   $1A00 = $E2 BAD AP HEADER/LENGTH
ASM>$2000: ;   $1A00 = $E3 AP CROSSES 4K SECTOR
ASM>$2000: ;   $1A00 = $E4 PROGRAM/VERIFY FAILED
ASM>$2000:
ASM>$2000:         ORG $3000
ASM>$3000:
ASM>$3000: BANK    EQU $02
ASM>$3000: PKG     EQU $3200
ASM>$3000: DST     EQU $9000
ASM>$3000:
ASM>$3000: PKGSIG0 EQU PKG
ASM>$3000: PKGSIG1 EQU PKG+1
ASM>$3000: PKGLENL EQU PKG+3
ASM>$3000: PKGLENH EQU PKG+4
ASM>$3000:
ASM>$3000: STAT    EQU $1A00
ASM>$3000: LENLO   EQU $1A01
ASM>$3000: LENHI   EQU $1A02
ASM>$3000: SPLO    EQU $C8
ASM>$3000: SPHI    EQU $C9
ASM>$3000: DPLO    EQU $CA
ASM>$3000: DPHI    EQU $CB
ASM>$3000:
ASM>$3000: STR8_SERVICE EQU $F003
ASM>$3000: STR8_MARK_SECTOR_HI EQU $1FE9
ASM>$3000: STR8_COPY_SRC_BANK EQU $1FEE
ASM>$3000: STR8_COPY_DST_BANK EQU $1FEF
ASM>$3000: STR8_COPY_MODE EQU $1FF0
ASM>$3000: STR8_STAGE_BUF_HI EQU $1FF6
ASM>$3000: MODE_PROGRAM_STAGED EQU $05
ASM>$3000: MODE_STAGE_BANK_SECTOR EQU $06
ASM>$3000:
ASM>$3000: RUN     STZ STAT
ASM>$3003:         LDA #BANK
ASM>$3005:         CMP #$03
ASM>$3007:         BCC CFGDST
ASM>$3009: BADCFG  LDA #$E0
ASM>$300B:         STA STAT
ASM>$300E:         CLC
ASM>$300F:         RTS
ASM>$3010:
ASM>$3010: CFGDST  LDA #>DST
ASM>$3012:         CMP #$80
ASM>$3014:         BCS CFGOK
ASM>$3016:         BRA BADCFG
ASM>$3018:
ASM>$3018: CFGOK   LDA #BANK
ASM>$301A:         STA STR8_COPY_SRC_BANK
ASM>$301D:         LDA #>DST
ASM>$301F:         AND #$F0
ASM>$3021:         STA STR8_MARK_SECTOR_HI
ASM>$3024:         LDA #$0A
ASM>$3026:         STA STR8_STAGE_BUF_HI
ASM>$3029:         LDA #MODE_STAGE_BANK_SECTOR
ASM>$302B:         STA STR8_COPY_MODE
ASM>$302E:         JSR STR8_SERVICE
ASM>$3031:         BCS STAGED
ASM>$3033: STAGEFAIL LDA #$E1
ASM>$3035:         STA STAT
ASM>$3038:         CLC
ASM>$3039:         RTS
ASM>$303A:
ASM>$303A: STAGED  LDA PKGSIG0
ASM>$303D:         CMP #'A'
ASM>$303F:         BEQ SIG0OK
ASM>$3041: BADAP   LDA #$E2
ASM>$3043:         STA STAT
ASM>$3046:         CLC
ASM>$3047:         RTS
ASM>$3048:
ASM>$3048: SIG0OK  LDA PKGSIG1
ASM>$304B:         CMP #'P'
ASM>$304D:         BNE BADAP
ASM>$304F:         LDA PKGLENL
ASM>$3052:         STA LENLO
ASM>$3055:         LDA PKGLENH
ASM>$3058:         STA LENHI
ASM>$305B:         ORA LENLO
ASM>$305E:         BEQ BADAP
ASM>$3060:
ASM>$3060:         LDA #<PKG
ASM>$3062:         STA SPLO
ASM>$3064:         LDA #>PKG
ASM>$3066:         STA SPHI
ASM>$3068:         LDA #<DST
ASM>$306A:         STA DPLO
ASM>$306C:         LDA #>DST
ASM>$306E:         AND #$0F
ASM>$3070:         CLC
ASM>$3071:         ADC #$0A
ASM>$3073:         STA DPHI
ASM>$3075:
ASM>$3075: COPY    LDA LENLO
ASM>$3078:         ORA LENHI
ASM>$307B:         BEQ COPIED
ASM>$307D:         LDY #$00
ASM>$307F:         LDA (SPLO),Y
ASM>$3081:         STA (DPLO),Y
ASM>$3083:         INC SPLO
ASM>$3085:         BNE CDST
ASM>$3087:         INC SPHI
ASM>$3089: CDST    INC DPLO
ASM>$308B:         BNE CCOUNT
ASM>$308D:         INC DPHI
ASM>$308F: CCOUNT  DEC LENLO
ASM>$3092:         LDA LENLO
ASM>$3095:         CMP #$FF
ASM>$3097:         BNE CCHK
ASM>$3099:         DEC LENHI
ASM>$309C: CCHK    LDA LENLO
ASM>$309F:         ORA LENHI
ASM>$30A2:         BEQ COPIED
ASM>$30A4:         LDA DPHI
ASM>$30A6:         CMP #$1A
ASM>$30A8:         BCC COPY
ASM>$30AA:         LDA #$E3
ASM>$30AC:         STA STAT
ASM>$30AF:         CLC
ASM>$30B0:         RTS
ASM>$30B1:
ASM>$30B1: COPIED  LDA #BANK
ASM>$30B3:         STA STR8_COPY_DST_BANK
ASM>$30B6:         LDA #>DST
ASM>$30B8:         AND #$F0
ASM>$30BA:         STA STR8_MARK_SECTOR_HI
ASM>$30BD:         LDA #$0A
ASM>$30BF:         STA STR8_STAGE_BUF_HI
ASM>$30C2:         LDA #MODE_PROGRAM_STAGED
ASM>$30C4:         STA STR8_COPY_MODE
ASM>$30C7:         JSR STR8_SERVICE
ASM>$30CA:         BCC PROGFAIL
ASM>$30CC:         LDA #$AC
ASM>$30CE:         STA STAT
ASM>$30D1:         SEC
ASM>$30D2:         RTS
ASM>$30D3:
ASM>$30D3: PROGFAIL LDA #$E4
ASM>$30D5:         STA STAT
ASM>$30D8:         CLC
ASM>$30D9:         RTS
ASM>$30DA:
ASM>$30DA:         END
ASM OK
SEAL> .
ASM BYE
>D 3200 3204
3200: 41 50 01 76 00 | AP.v.
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=03 Y=00 P=B5 S=FD Nv-BdIzC
>D 1A00 1A03
1A00: AC 00 00 00 | ....
>M 5848
5848: 36 00
>AP B2 $9000 $3000
GO 3000

BANK RJOIN

#GO# ENTRY=3000
RET A=AC X=1A Y=0E P=F5 S=FD NV-BdIzC
>AP B2 $9000 $3000
GO 3000

BANK RJOIN

#GO# ENTRY=3000
RET A=AC X=1A Y=0E P=F5 S=FD NV-BdIzC
>D 5848 5850
5848: AC 3A 05 E7 4C 50 64 6D | 70 | .:..LPdmp
>D 3006 3008
3006: 20 05 E7 |  ..
>D 1A10 1A17
1A10: 06 0F 30 05 E7 04 05 01 | ..0.....
>D 7E2D 7E40
7E2D: BF D5 01 00 00 0A 00 30 | 76 00 4D 0A 29 00 05 01 | .......0v.M.)...
7E3D: 00 00 14 0A | ....
>D 0A00 0A08
0A00: 41 50 01 76 00 53 0B 01 | 00 | AP.v.S...
>AP B2 $9000 $3000
GO 3000

BANK RJOIN

#GO# ENTRY=3000
RET A=AC X=1A Y=0E P=F5 S=FD NV-BdIzC
>D 5848 5850
5848: AC 3A 05 E7 4C 50 64 6D | 70 | .:..LPdmp
>D 3006 3008
3006: 20 05 E7 |  ..
>D 1A10 1A17
1A10: 06 0F 30 05 E7 04 05 01 | ..0.....
>D 7E2D 7E40
7E2D: BF D5 01 00 00 0A 00 30 | 76 00 4D 0A 29 00 05 01 | .......0v.M.)...
7E3D: 00 00 14 0A | ....
>D 0A00 0A08
0A00: 41 50 01 76 00 53 0B 01 | 00 | AP.v.S...
>
```

Result: pass. The installer returned `$AC` with carry set and status bytes
`AC 00 00 00`, proving the Bank 2 sector was staged, overlaid, programmed,
and verified. Each `AP B2 $9000 $3000` invocation printed `BANK RJOIN` and
returned `A=$AC/C=1`. `$584A/$584B = 05 E7` and `$3006-$3008 = 20 05 E7`
prove the imported call resolved and was patched to current resident target
`BIO_FTDI_PUT_CSTR=$E705`.

The RJOIN debug row `06 0F 30 05 E7 04 05 01` records final patch kind `$06`,
patch site `$300F`, target `$E705`, relocation index `$04`, five relocation
rows, and one import. The HIMON request cells report status `$00`, source
`$0A00`, destination `$3000`, package length `$0076`, body pointer `$0A4D`,
and body length `$0029`; the staged header at `$0A00` begins
`41 50 01 76 00`. This closes the banked-source RJOIN gate and, together with
the preceding atomicity pass, closes both current-image AP-linker gates.

## 2026-07-19 STR8 V0 Gate 1: Nonerased Lower-Sector Restore Pass

Fixture: `ASM/SAMPLES/str8-restore-nonerased-3000.a`, frozen source hash
`bd7f4cae699619e3154d7080c521b2f55bfb67d4`. Installed identities were
STR8-N V0 `#5F6A0F7A`, HIMON `00.0718(2041)`, and ASM-F2 `00.0718(2045)`.

The unchanged dry fixture assembled cleanly and left the expected harmless
row. The captured execution proof follows.

```text
>D 1A00 1A07
1A00: E0 00 00 00 00 00 02 90 | ........

>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=03 Y=00 P=F5 S=FD NV-BdIzC
>D 1A00 1A07
1A00: AC 50 BC 43 00 00 02 90 | .P.C....
>D 9FF0
9FF0: 43 | C

>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

STR8-N

HIMON IN 3S. S=STR8-N  3
STR8-N V0 #5F6A0F7A
ROM $F000
? B E U 0 1 2 G R
B0 HOLD
STR8-N>
RESTORE B2->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: n
COPY B2->B3

OK
STR8-N>
G HIMON
BOOT WARM

HIMON V 00.0718(2041)
>G 3003
GO 3003

#GO# ENTRY=3003
RET A=AC X=03 Y=00 P=F5 S=FD NV-BdIzC
>D 1A00 1A07
1A00: AC 56 BC 43 00 00 02 90 | .V.C....
>D 9FF0
9FF0: BC | .
```

Result: pass. The armed preparation deliberately changed Bank 3 `$9FF0` from
the staged Bank-2 source byte `$BC` to `$43`, then the normal B2-to-B3 restore
with high flash declined restored `$BC`. `AC 56` and carry set prove the
fixture compared all 4096 bytes of the restored `$9000-$9FFF` sector.

The subsequent ASM-F2 S19 reload attempt did not complete:

```text
>L F
L F S19
L @8000
LF ERASE=B9C8 OLD=38 NEW=39
L @B9D0
LF FAIL=03 WR=39C8 SKIP=029E GO=800C
```

ASM-F2 still opened and exited afterward. This reload failure is recorded as a
separate recovery issue; it does not alter the completed Gate 1 proof.

## 2026-07-19 STR8 V0 Gate 2: Parser-Safe Fixture Revision Required

The original high-failure fixture was not armed. Board ASM-F2 rejected each
`PATCH+offset` absolute operand with `ERR=$03`; after that tainted assembly,
the unarmed check returned `A=E0/C=0` and the malformed armed copy returned
`A=E2/C=0`. No high restore was started. The fixture was revised to use the
equivalent explicit constants `$0275` through `$0279`; its new frozen hash is
`11664524085cad0a74859c0b03a0a812ff27b860`. Gate 2 remains open pending a
clean unchanged-board assembly and dry latch on that revision.

## 2026-07-19 STR8 V0 Gate 2: Parser-Safe Latch Pass And Source-Match Stop

The corrected frozen fixture
`11664524085cad0a74859c0b03a0a812ff27b860` assembled cleanly on board, with
no `ERR=$03`. Its unchanged latch was then proven:

```text
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=E0 X=30 Y=30 P=F4 S=FD NV-BdIzc
>D 1A00 1A07
1A00: E0 00 00 00 00 00 02 03 | ........
```

The same parser-safe source was reassembled with `ARM EQU $A5`. It returned
before the worker patch and before any high-flash copy:

```text
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=E5 X=03 Y=FE P=B4 S=FD Nv-BdIzc
```

`$E5/C=0` is the intended Bank-2/Bank-3 `$C000-$FFFF` mismatch stop. `Y=$FE`
is the first unequal byte offset in the current sector comparison. The board
had updated Bank 3 to HIMON/ASM-F2 `00.0719(1841)` while Bank 2 still held the
older source, so the source guard correctly prevented the terminal proof.

The transcript also recorded a successful current ASM-F2 install before the
lower restore:

```text
>L F
L F S19
L @8000
LF OK WR=3C6D GO=800C
>ASM NEW
ASM-F2 00.0719(1841)
```

The later `LF FAIL=03` followed the ordinary B2-to-B3 lower restore, which
replaces Bank 3 `$8000-$BFFF` from Bank 2. This correlation is recorded for
the separate loader diagnosis; it is not a demonstrated causal mechanism.

## 2026-07-19 STR8 V0 Gate 2: Post-Verify Failure Pass

Before the terminal run, the RAM-resident
`bank3-erase-8000-bfff-transient-3000.a` utility
(`29fa3b26047a6a4b45e023322ecd62354f9a8573`) erased and verified Bank 3
`$8000-$BFFF` (`RET A=AC/C=1`), after which the current ASM-F2 S19 installed
successfully as `00.0719(1841)`:

```text
>L F
L F S19
L @8000
LF OK WR=3C6D GO=800C
```

The lower-sector Gate 1 sequence subsequently restored the older Bank-2 ASM
slice as expected. Gate 2 initially stopped at its nonwriting `$E5` source
guard. STR8 then completed the intended `B0 HOLD` backup rotation, producing
`COPY B2->B1`, `COPY B3->B2`, and `OK` (repeated once while keeping the same
Bank 3 image), so Bank 2 became the current complete source.

The parser-safe high fixture again passed its unchanged latch. Its `ARM=$A5`
run made no normal GO return; after the reset sequence resumed at STR8 and
warm HIMON entry, the retained verifier produced the required proof:

```text
>G 3003
GO 3003

#GO# ENTRY=3003
RET A=AC X=33 Y=00 P=F5 S=FD NV-BdIzC
>D 1A00 1A07
1A00: AC 00 5A 00 00 F0 02 03 | ..Z.....
>D FFFA FFFF
FFFA: 92 F0 00 F0 A6 F0 | ......
>D 9FF0
9FF0: BC | .
```

Result: pass. The terminal failure path was reached only after the F-sector
transaction completed (`$1A01=$00`), the guarded RAM hook was installed
(`$1A02=$5A`), the retained Bank-2 and visible Bank-3 top sectors compared
equal, and the expected STR8 vector tail remained executable. This closes the
deterministic injected high-restore failure gate. It does not claim a physical
failure during top-sector erase or programming.

The following post-proof reload still stopped at:

```text
LF FAIL=03 WR=39C8 SKIP=029E GO=800C
```

That ASM-F2 reload behavior is retained as a separate regression.

### Operator Correction: `LF FAIL=03` Was Prior Test State, Not A Regression

The operator confirmed that the displayed `LF FAIL=03` belonged to the prior
`$9000` test state. It is not an ASM-F2 loader regression. The valid recovery
sequence erased Bank 3 `$8000-$EFFF`, then used `L F` with
`asm-v1-flash-8000.s19`; the captured result was:

```text
L F S19
L @8000
LF OK WR=3C6D GO=800C
ASM-F2 00.0719(1841)
```

Accordingly, the closed STR8 V0 gates have no outstanding loader/recovery
failure. The earlier failing line remains above as a transcript of its prior
test state, not as a defect claim.

## 2026-07-20 STR8 S19 Migration Phase 1 Installation Gate: Blocked

The board accepted a HIMON `$C000-$EFFF` update through `U` and warm-booted
`HIMON V 00.0719(1916)`.  The Phase-1 record proof S19 then loaded normally at
`$3000` (`L OK=07C9 GO=3000`), but the mandatory resident-STR8 installation
gate failed before any `$F009` test was run:

```text
>D F000 F01F
F000: 4C 09 F0 4C 7C F3 4C 83 | F3 78 D8 A2 FF 9A 20 3F
>D F975 F97F
F975: FF FF FF FF FF FF FF FF | FF FF FF
>D FCC9 FCCF
FCC9: FF FF FF FF FF FF FF
>D FFEF FFF1
FFEF: EE FF FF
>D FFFA FFFF
FFFA: 92 F0 00 F0 A6 F0
```

This is the earlier STR8 V0 face: `$F009` is body code, not the required
`4C 92 F3 53 52 01 07` record doorway/header; the expected worker head is not
at `$FCC9`; and the vector tail is the V0 `92 F0 00 F0 A6 F0`, not the Phase-1
`99 F0 00 F0 AD F0`.  Therefore this transcript is an installation-gate block,
not a parser or `APPLY_LF` failure.

The initial attempt to paste the generated proof's S19 records into `ASM NEW`
produced `ERR=$08`; that is expected because ASM consumes assembly source, not
Motorola S records.  The subsequent normal HIMON `L` correctly loaded the
proof.  Next action: assemble the generated
`str8n-topwrite-transient-3000.a` source under ASM-F2, require `G 3000` to
leave `$1A00-$1A03 = 00 AC 00 00`, then require `G 3003` to leave
`01 AC 00 00`.  Cold-boot and repeat the Phase-1 installation dumps before
running the four proof entries.

### Recovery and Phase-1 STR8 installation continuation

The current HIMON had already become a Phase-2 client, so its `L`, `L G`, and
`L F` forms all correctly returned `LERR=$06` against the old provider.  The
operator had also erased Bank 3 `$8000-$BFFF`, removing flash ASM.  Recovery
used the old STR8 `2` restore with confirmation to restore `B2->B3` and a
negative answer to `FLASH C000-FFFF? Y:`.  It returned `OK`, preserved
`HIMON V 00.0720(1143)`, and restored `ASM-F2 00.0718(2045)` plus the expected
low-flash head:

```text
>D 8000 800F
8000: 46 4E D6 00 74 AD 56 05 | 0C 80 87 B9 20 7B 85 B0
```

The generated topwriter then assembled under that recovered ASM.  Its stage
and program calls both returned `$AC`, with the required rows:

```text
G 3000 -> TW STG / TW OK -> 1A00: 00 AC 00 00
G 3003 -> TW PRG / TW OK -> 1A00: 01 AC 00 00
```

After cold boot, resident checks passed exactly:

```text
F000: 4C 10 F0 4C 83 F3 4C 8A F3 4C 92 F3 53 52 01 07
F975: 7A 0F 6A 5F
FCC9: 08 78 AD F0 1F C9 02 F0 11 C9 05 F0 12 C9 06 F0
FFFA: 99 F0 00 F0 AD F0
```

The first execution of the original record proof then reached a successful S0
service result (`A=$00`, carry set, status `$00`, kind `$01`) and preserved the
`$6000-$6003 = 11 22 33 44` guard.  The fixture itself failed case 2, field
`$10`, because it used an `$1Axx` descriptor pointer as a 65C02 zero-page
indirect pointer; the observed expected byte was therefore unrelated (`$66`).
The proof was corrected to keep that pointer at `$0B/$0C`, rebuilt, and now
has `L OK=07BB GO=3000`.  No board recovery is needed; reload this revised S19
and restart at `G 3000`.

### Corrected Phase-1 proof: buffered parser/ABI and `APPLY_LF` pass

The corrected `str8-record-phase1-proof-3000.s19` loaded at `$3000` as
`L OK=07BB GO=3000`.  The buffered parser/ABI entry passed all 15 cases:

```text
>G 3000
RET A=AC X=0F Y=01 P=35 S=FD Nv-BdIzC
>D 1A00 1A17
1A00: AC 01 0F 00 44 44 03 00 | 03 00 00 00 00 00 00 00
1A10: 00 00 00 00 00 00 44 44
>D 6000 6003
6000: 11 22 33 44
```

`A=$AC`, `X=$0F`, `Y=$01`, and carry set in `P=$35` are the pass contract.
The final `$44/$44` actual/expected pair is the successful last guard-byte
comparison, not an error.  The guard remained intact.

The non-erasing `APPLY_LF` entry also passed all six cases:

```text
>G 3003
RET A=AC X=06 Y=02 P=35 S=FD Nv-BdIzC
>D 1A00 1A17
1A00: AC 02 06 00 46 46 00 01 | 00 02 00 00 80 01 00 00
1A10: 00 00 00 00 00 80 46 46
```

This records the dynamically selected occupied byte at `$8000` (`$46`), its
unchanged before/after value, and the matching resident-worker outcome.
The remaining Phase-1 board gates are the console maximum-length and Ctrl-C
entries, followed by the `U` decline/accepted-candidate gate.

### Console-input limit characterization; abort and declined-update passes

The first maximum-record attempt reached the console parser but failed as
expected for a truncated input stream, not as a resident service failure:

```text
>G 3006
RET A=E1 X=01 Y=01 P=74 S=FD NV-BdIzc
>D 1A00 1A17
1A00: E1 03 01 01 06 00 06 00 | 06 00 00 00 20 FC 00 00
```

`$06` is `BAD_HEX`; the captured terminal text ended at payload byte `$7B`.
That is exactly 256 ASCII characters including the initial `S`, whereas the
required maximum record is 514 characters.  The current serial-entry path
therefore needs raw no-CR chunks of at most 200 characters, with the one CR
sent only after the last chunk.  This is an input-tool limit; it does not
invalidate the resident console parser.

The independent console-abort entry passed:

```text
>G 3009
RET A=AC X=01 Y=04 P=75 S=FD NV-BdIzC
>D 1A00 1A17
1A00: AC 04 01 00 0E 0E 0E 00 | 0E 00 00 00 00 00 00 00
```

The safe `U` decline gate also passed.  The `$C000-$C01F` dump before `U`,
the `N` response to `UPDATE HIMON C000-EFFF? Y:`, and the post-warm-boot dump
were byte-for-byte identical.  The accepted, pinned-Phase-1 `U` gate remains
intentionally unrun.

### Console maximum-record pass with raw no-CR chunks

The 514-character record was retransmitted as 200/200/114-character raw
chunks, with no CR between chunks and one CR after the final checksum.  The
console maximum-record suite passed:

```text
>G 3006
RET A=AC X=01 Y=03 P=35 S=FD Nv-BdIzC
>D 1A00 1A17
1A00: AC 03 01 00 FB FB 00 01 | 00 02 00 00 20 FC 00 00
```

`A=$AC`, `X=$01`, `Y=$03`, and carry set in `P=$35` close the console
maximum-record gate.  `$FB/$FB` is the final decoded payload-byte comparison;
the descriptor is `DATA/$2000/$FC`.  All four executable record-service
proof entries and the safe `U` decline gate now pass.  Only the separately
authorized accepted-update gate, with the pinned Phase-1 `f138d78` candidate,
remains.

### Accepted Phase-1-pinned `U` update: pass

With explicit authorization, the board was cold-started and preflighted before
the destructive gate.  The resident provider remained the installed Phase-1
face and the pre-update HIMON was `00.0720(1143)`:

```text
>D F000 F00F
F000: 4C 10 F0 4C 83 F3 4C 8A | F3 4C 92 F3 53 52 01 07
>D C000 C00F
C000: 78 D8 A2 FF 9A AD E6 7E | C9 A5 D0 24 AD E7 7E C9
```

The exact candidate was the clean-commit `f138d7839ea7a94638bd8203aeb0f5550f2138dd`
C/D/E stream (`himon-phase1-f138d78-update.s19`, SHA-256
`0C578349E76FAF4CCE3F6B392C0D06B971027E953137EF1468C2BA143CECFA1F`).
STR8 accepted the S1 stream, reached the existing second confirmation, and
completed the program/verify step:

```text
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
................................................................
PROGRAM C000-EFFF? Y: y...
OK
```

The warm handoff then reported the expected pinned image and its installed
identity bytes:

```text
G HIMON -> BOOT WARM
HIMON V 00.0720(1227)

E9E8: A2 03 00 F0 67 EA 0D 0A | 48 49 4D 4F 4E 20 56 20
E9F8: 30 30 2E 30 37 32 30 28 | 31 32 32 37 A9 48 49 4D
F000: 4C 10 F0 4C 83 F3 4C 8A | F3 4C 92 F3 53 52 01 07
```

Finally, a cold boot returned `HIMON V 00.0720(1227)` and retained the same
resident STR8 Phase-1 header through `$F01F`.  This closes the accepted `U`
gate and completes all required Phase-1 board gates.

## 2026-07-20 STR8 S19 Migration Phase 2: HIMON Client Board Pass

The Phase-2 C/D/E candidate was built from the working tree as
`himon-phase2-str8-client-0720-1307.s19` (SHA-256
`574DAFFECEB70B82C94C0BA73CD237F28CDAE7DEACB06E8AA4142CD43AD84B51`).
From the cold Phase-1 baseline (`HIMON V 00.0720(1227)`), the resident
provider doorway preflight was exact:

```text
F009: 4C 92 F3 53 52 01 07
```

STR8 accepted the complete C/D/E stream and returned `OK`; warm boot then
reported the expected Phase-2 client:

```text
HIMON V 00.0720(1307)
F009: 4C 92 F3 53 52 01 07
E993: A2 03 00 F0 12 EA 0D 0A | 48 49 4D 4F 4E 20 56 20
E9A3: 30 30 2E 30 37 32 30 28 | 31 33 30 37 A9 48 49 4D
```

The loader gates passed:

```text
>L
L @3000
L OK=0004 GO=3000
>D 3000 3003
3000: A9 11 60 EA

>L G
L @3000
L OK=0004 GO=3000
#LOADGO# ENTRY=3000
RET A=11 ... C

>L
S10460005A40                  ; deliberately bad checksum
LERR=$01
L OK=0000 GO=0000

>L                                ; direct I/O range
S1047F005A22
LERR=$02
>L                                ; normal mode must not write flash
S10480005A21
LERR=$05

>L                                ; zero-length $FFFF data record
S103FFFFFE
S9030000FC
L OK=0000 GO=0000

>L                                ; overlapping STR8 decode buffer copy
S1077B0111223344D2
S9030000FC
>D 7B00 7B04
7B00: 11 11 22 33 44

>L F                              ; already-matching visible flash
S1078000464ED6000E
S90380007C
LF OK WR=0004 GO=8000
>D 8000 8003
8000: 46 4E D6 00
```

The bad-checksum guard byte at `$6000` was identical before and after the
test.  A large runtime-smoke transport also completed all records and handed
off correctly (`L OK=3A1A GO=2000`), but its own wrapper printed
`ASM RT FAIL $06`.  Its current link map explains the result:
`ASM_WORKSPACE_END=$8399`, while the wrapper's assembly target is `$7000`;
ASM therefore correctly reports `BAD_RANGE=$06` before assembling.  This is a
pre-existing runtime-image layout defect, independent of the Phase-2 loader.

The completed record service is now the only S19 syntax/type/count/hex/checksum
authority for HIMON `L`, `L G`, and the parsing half of `L F`; HIMON retained
the observed policy, copy, accounting, GO, and transitional matching-flash
behavior.  Phase 2 is hardware-complete.

## 2026-07-20 STR8 S19 Migration Phase 3: HIMON `L F` APPLY_LF Board Pass

The frozen C/D/E update candidate was
`SRC/BUILD/s19/himon-str8-himon-update.s19`, SHA-256
`2459583A4E97E8F895C10BBAFC741A1E5ECE4BAC392036B5048CAB4683CCB1C5`.
Its S1 records spanned `$C000-$EF20`, it terminated with `S903C0003C`, and it
installed through the already-proven STR8 `UPDATE HIMON C000-EFFF` path.  Warm
boot reported `HIMON V 00.0720(1339)` and the fixed resident record doorway
remained `4C 92 F3 53 52 01 07` at `$F009`.

The unedited Phase-3 terminal transcript follows.  `$BFE0-$BFE3` was verified
blank before the controlled one-byte worker write.  The later `$8FE0` dump was
an operator address typo outside the test scratch range; the immediately
following `$BFE0` dump is the authoritative gate observation.

```text
STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

STR8-N

HIMON IN 3S. S=STR8-N  3
STR8-N V0 #5F6A0F7A
ROM $F000
? B E U 0 1 2 G R
B0 HOLD
STR8-N>
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
..........................................................................................................................................................................................................................................................................................................................................................................................
PROGRAM C000-EFFF? Y: y...
OK
STR8-N>
G HIMON
BOOT WARM

HIMON V 00.0720(1339)
>D F009 F00F
F009: 4C 92 F3 53 52 01 07 | L..SR..
>D 8000 800F
8000: 46 4E D6 00 74 AD 56 05 | 0C 80 87 B9 20 7B 85 B0 | FN..t.V..... {..
>D BFE0 BFEF
BFE0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
>D BD80 BFFF
BD80: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BD90: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BDA0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BDB0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BDC0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BDD0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BDE0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BDF0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BE00: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BE10: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BE20: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BE30: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BE40: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BE50: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BE60: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BE70: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BE80: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BE90: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BEA0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BEB0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BEC0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BED0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BEE0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BEF0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BF00: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BF10: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BF20: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BF30: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BF40: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BF50: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BF60: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BF70: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BF80: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BF90: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BFA0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BFB0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BFC0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BFD0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BFE0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
BFF0: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
>L F
L F S19
L @8000
LF OK WR=0004 GO=8000
>D 8000 8003
8000: 46 4E D6 00 | FN..
>L F
L F S19
L @BFE2
LF OK WR=0001 GO=BFE2
>D 8000 8003
8000: 46 4E D6 00 | FN..
>D BFE0 BFE3
BFE0: FF FF 5A FF | ..Z.
>L F
L F S19
L @BFE2
LF OK WR=0001 GO=BFE2
>D BFE0 BFE3
BFE0: FF FF 5A FF | ..Z.
>D 8000 8003
8000: 46 4E D6 00 | FN..
>L F
L F S19
L @BFE0
LF ERASE=BFE2 OLD=5A NEW=00
LF FAIL=03 WR=0000 SKIP=0004 GO=BFE0
>D BFE0 BFE3
BFE0: FF FF 5A FF | ..Z.
>D C000 C003
C000: 78 D8 A2 FF | x...
>L F
L F S19
L @C000
LF PROT=C000
LF FAIL=02 WR=0000 SKIP=0001 GO=C000
>D C000 C003
C000: 78 D8 A2 FF | x...
>L F
L F S19
LF OK WR=0000 GO=BFE0
>D 8FE0 8FE3
8FE0: 29 80 D0 03 | )...
>D BFE0 BFE3
BFE0: FF FF 5A FF | ..Z.
>
```

All Phase-3 acceptance gates passed: the matching active ASM record was
accepted; `$BFE2` was programmed and re-accepted as matching; the mixed record
failed at `$BFE2` before `$BFE0/$BFE1` changed and drained the later S1 through
S9 with `SKIP=0004`; `$C000` was protected without mutation; and the
zero-length S1 completed without mutation.  Phase 3 is hardware-complete.

## 2026-07-20 STR8 S19 Migration Phase 4: Sink Removal And ASM-F2 Board Pass

The Phase-4 C/D/E update candidate was
`himon-str8-himon-update.s19` (SHA-256
`2E1EBEA35F18750FC0B65FE31D1F6B14CDBF9867C7B4C9234DA33B0BE161CEA8`), and
the ASM-F2 reload candidate was `asm-v1-flash-8000.s19` (SHA-256
`612EE452AEAD3B05EABE8530CE4B991F211F1471108C0CB4737E3D5E5A0314DC`).
STR8 programmed the C/D/E candidate and warm booted the expected sink-free
client:

```text
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
...
PROGRAM C000-EFFF? Y: y...
OK
G HIMON
BOOT WARM

HIMON V 00.0720(1625)
>D F009 F00F
F009: 4C 92 F3 53 52 01 07 | L..SR..
```

An attempted direct serial load of the separately built RAM erase fixture
reported repeated `LERR=$01`, intermittent `LS03`, and was stopped at
`NMI PC=E544`; it did not become the erase route. This is recorded as a
serial-transport/framing observation, not a loader or flash result. After the
cold recovery boot, the established board-buildable erase source was assembled
with the still-resident earlier ASM-F2 and ran successfully:

```text
HIMON V 00.0720(1625)
>ASM NEW
ASM-F2 00.0720(1143)
; pasted bank3-erase-8000-bfff-transient-3000.a
ASM OK
SEAL> .
ASM BYE
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=03 Y=00 P=B5 S=FD Nv-BdIzC
>D 1A00 1A03
1A00: AC 00 00 00 | ....
>D 8000 800F
8000: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
>ASM
#56AD7400# HSH_NF!
```

`A=$AC` with carry set and `$1A00=$AC` prove that the RAM utility erased and
verified all Bank-3 low-flash sectors. The `HSH_NF` result is expected after it
erases the old ASM-F2 image. The Phase-4 `L F` path then programmed the whole
fresh ASM-F2 image, entered it, assembled a minimal RAM routine, and returned
its value:

```text
>L F
L F S19
L @8000
LF OK WR=3C6D GO=800C
>D 8000 800F
8000: 46 4E D6 00 74 AD 56 05 | 0C 80 87 B9 20 7B 85 B0 | FN..t.V..... {..
>ASM NEW
ASM-F2 00.0720(1625)
ASM>$2000: ORG $3000
ASM>$3000: LDA #$5A
ASM>$3002: RTS
ASM>$3003: .
ASM BYE
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=5A X=30 Y=30 P=75 S=FD NV-BdIzC
```

A final cold boot preserved the Phase-4 HIMON and started the newly reloaded
ASM-F2 normally:

```text
>2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0720(1625)
>ASM NEW
ASM-F2 00.0720(1625)
ASM>$2000: .
ASM BYE
```

This closes Phase 4: HIMON contains no remaining per-byte `L F` sink, the
shared STR8 APPLY_LF path reloaded a fully erased low-flash ASM-F2 image, and
the final HIMON/ASM-F2 pair survives a cold boot.

## 2026-07-20 STR8 S19 Migration Phase 5: Non-Destructive Serial Transport Pass

The frozen RAM-only fixture
`str8-l-transport-phase5-proof-3000.s19` (SHA-256
`BB9D30C483A114502AE021A64961F1FE1D4C8E8895AD0A08E0781476C45C7002`) has eight
42-character S1 records from `$3000-$307F`, followed by `S9033000CC`. It
contains no flash service call. The following unedited board transcript proves
that the direct file-send route accepted every record and executed only the
RAM proof:

```text
>2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0720(1625)
>D F000 F01F
F000: 4C 10 F0 4C 83 F3 4C 8A | F3 4C 92 F3 53 52 01 07 | L..L..L..L..SR..
F010: 78 D8 A2 FF 9A 20 46 F0 | 20 36 F0 20 07 F1 20 10 | x.... F. 6. .. .
>D 4900 491F
4900: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
4910: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>L G
L S19
L @3000
L @3010
L @3020
L @3030
L @3040
L @3050
L @3060
L @3070
L OK=0080 GO=3000

#LOADGO# ENTRY=3000
RET A=A5 X=30 Y=30 P=F5 S=FD NV-BdIzC
>D 4900 491F
4900: A5 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
4910: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>D 3000 301F
3000: A9 A5 8D 00 49 60 EA EA | EA EA EA EA EA EA EA EA | ....I`..........
3010: EA EA EA EA EA EA EA EA | EA EA EA EA EA EA EA EA | ................
>
```

All eight S1 records were accepted, the entry returned `A=$A5`, and only the
RAM sentinel changed. This closes Phase 5: the prior rejected erase-fixture
transfer is not evidence of a HIMON line-length or STR8 parser defect. The
separate destructive erase route remains subject to its own approval and
preflight.

## 2026-07-20 STR8 S19 Migration Phase 6: Erase Fixture Direct-Load Pass

The frozen host artifact remains
`bank3-erase-8000-bfff-3000.s19` (SHA-256
`AC5FDE6C91DA7E5823A10033085F146601DE06EFC50D241608C7AFA7BCCFA7F6`), with
eight S1 records `$3000-$3070` and `S9033000CC`. The following unedited final
cold-boot-to-cold-boot transcript is the Phase-6 portion of the supplied board
session. It loads the fixture through plain `L`; it does not execute `$3000`.

```text
>2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0720(1625)
>D F000 F00F
F000: 4C 10 F0 4C 83 F3 4C 8A | F3 4C 92 F3 53 52 01 07 | L..L..L..L..SR..
>D 8000 800F
8000: 46 4E D6 00 74 AD 56 05 | 0C 80 87 B9 20 7B 85 B0 | FN..t.V..... {..
>D 3000 3070
3000: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
3010: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
3020: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
3030: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
3040: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
3050: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
3060: 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
3070: 00 | .
>L
L S19
L @3000
L @3010
L @3020
L @3030
L @3040
L @3050
L @3060
L @3070
L OK=0071 GO=3000
>D 3000 300F
3000: 9C 00 1A 9C 01 1A 9C 02 | 1A 9C 03 1A 20 59 30 A9 | ............ Y0.
>D 3070 3070
D [a [b]]
>D 3070
3070: 60 | `
>D 8000 800F
8000: 46 4E D6 00 74 AD 56 05 | 0C 80 87 B9 20 7B 85 B0 | FN..t.V..... {..
>2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0720(1625)
>D F000 F00F
F000: 4C 10 F0 4C 83 F3 4C 8A | F3 4C 92 F3 53 52 01 07 | L..L..L..L..SR..
>
```

The RAM image began at the expected bytes and ended in the expected RTS;
every S1 address was accepted, the low-flash head was unchanged, and the final
cold boot cleared the RAM program. The `D 3070 3070` usage response is a
monitor syntax observation, not a loader fault; the subsequent `D 3070` dump
is the accepted one-byte verification. Phase 6 passes. It does not authorize
the destructive Bank-3 erase execution.

## 2026-07-20 STR8 S19 Migration Phase 7: Bank-3 Erase And ASM-F2 Recovery Pass

The direct RAM erase fixture was the Phase-6-verified
`bank3-erase-8000-bfff-3000.s19` (SHA-256
`AC5FDE6C91DA7E5823A10033085F146601DE06EFC50D241608C7AFA7BCCFA7F6`). The
accepted reload candidate as sent to the board was
`asm-v1-flash-8000.s19`, visible as `ASM-F2 00.0720(1719)`, SHA-256
`18D81FFD7A4AF30A9077C7367FE20CFF972C80F1239A550ACF830A0945AF163D`.

```text
>2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0720(1625)
>D F000 F00F
F000: 4C 10 F0 4C 83 F3 4C 8A | F3 4C 92 F3 53 52 01 07 | L..L..L..L..SR..
>D 8000 800F
8000: 46 4E D6 00 74 AD 56 05 | 0C 80 87 B9 20 7B 85 B0 | FN..t.V..... {..
>ASM NEW
ASM-F2 00.0720(1625)
ASM>$2000: .
ASM BYE
>L G
L S19
L @3000
L @3010
L @3020
L @3030
L @3040
L @3050
L @3060
L @3070
L OK=0071 GO=3000

#LOADGO# ENTRY=3000
RET A=AC X=03 Y=00 P=B5 S=FD Nv-BdIzC
>D 1A00 1A03
1A00: AC 00 00 00 | ....
>D 8000 800F
8000: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
>L F
L F S19
L @8000
LF OK WR=3C6D GO=800C
>D 8000 800F
8000: 46 4E D6 00 74 AD 56 05 | 0C 80 87 B9 20 7B 85 B0 | FN..t.V..... {..
>ASM NEW
ASM-F2 00.0720(1719)
ASM>$2000: ORG $3000
ASM>$3000: LDA #$5A
ASM>$3002: RTS
ASM>$3003: .
ASM BYE
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=5A X=30 Y=30 P=75 S=FD NV-BdIzC
>2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0720(1625)
>D F000 F00F
F000: 4C 10 F0 4C 83 F3 4C 8A | F3 4C 92 F3 53 52 01 07 | L..L..L..L..SR..
>ASM NEW
ASM-F2 00.0720(1719)
ASM>$2000: .
ASM BYE
>
```

The erase fixture returned `$AC` with carry set, its status row was clean, the
low-flash head was all `$FF` after erase and restored after `L F`, and both the
live `$5A` proof and final cold boot passed. Phase 7 is hardware-complete.

The version stamp is generated from the current time. A later host build
reported `ASM-F2 00.0720(1726)` and passed `asm-test`; it is a separate
post-install smoke artifact, not a change to the accepted board candidate
recorded above.

## 2026-07-20 Bank-0 Flash-Bank AP Package And Install Pass

The supplied board session began with the requested STR8 backup cycle and then
entered the established monitor and assembler pair:

```text
COPY B2->B1

COPY B3->B2

OK
STR8-N>
G HIMON
BOOT WARM

HIMON V 00.0720(1625)
>ASM NEW
ASM-F2 00.0720(1719)
```

It assembled, packaged, and installed the original non-interactive read AP:

```text
ASM>$20BF:         END
ASM OK
SEAL>
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$0100
...
>G 2000
GO 2000

B0 AP PUT
PKG L=$0100
DST $8000-$FFFF OR ENTER=AUTO>
STAGE OK
B0 AP @$86A6 L=$0100
TYPE YES TO WRITE> YES
PROGRAM OK
B0 AP @$86A6 L=$0100

#GO# ENTRY=2000
RET A=AC X=42 Y=04 P=F5 S=FD NV-BdIzC
```

It then assembled, packaged, and installed the original non-interactive
erase/write AP:

```text
ASM>$214F:         END
ASM OK
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$01B4
...
>G 2000
GO 2000

B0 AP PUT
PKG L=$01B4
DST $8000-$FFFF OR ENTER=AUTO>
STAGE OK
B0 AP @$87A6 L=$01B4
TYPE YES TO WRITE> YES
PROGRAM OK
B0 AP @$87A6 L=$01B4

#GO# ENTRY=2000
RET A=AC X=42 Y=04 P=F5 S=FD NV-BdIzC
```

The recorded package and entry contract is:

| AP | Bank-0 envelope | Envelope length | Exported body offset | Intended RAM entry |
|---|---:|---:|---:|---:|
| `FLASH_BANK_READ` | `$86A6` | `$0100` | `$0000` | `$3000` |
| `FLASH_BANK_ERASE_WRITE` | `$87A6` | `$01B4` | `$0000` | `$3000` |

The installer entry was `$2000`. The read AP stages one selected 4K bank
sector at `$4000-$4FFF` and calculates its CRC without mutating flash. The
write AP preflights a complete sector image already in that RAM tray, then can
erase, program, and fully verify one permitted sector.

Evidence boundary: this transcript proves the two old source bodies assembled,
their exact envelopes were produced, and the installer successfully wrote
those envelopes into Bank 0. It contains no `AP B0` invocation, so it is not a
runtime read or erase/write proof. The `$3000` RAM entry follows the recorded
package/load contract and offset-zero exports; it was not exercised here.

The source files were subsequently changed to make both AP front doors
interactive. The read successor asks for `B/S` and prints status and CRC. The
write successor asks for `B/S`, prints the preflight CRC, and requires exact
`YES` before committing. Host W65C02 assembly passes; new package and Bank-0
installation addresses remain open board gates. The expected new envelopes
are `$0289` for read and `$0387` for erase/write. The existing `$86A6` and
`$87A6` packages remain the earlier non-interactive builds.

## 2026-07-21 Fixed-Load Banked Erase AP Package/Abort Proof

Board HIMON/ASM-F2 was `00.0721(1742)`. The legacy direct-run
`flash-erase-bank-transient-2000.a` retained its expected `PKG ERR=$02`
negative. The separate fixed-load `flash-erase-bank-ap-2000.a` assembled,
then `PACKAGE $3000` returned `PKG OK @=$3000 L=$03D6`.

The resident Bank-0 PUT AP at `$9000` staged and programmed that envelope at
`$9486`, returning `PROGRAM OK` and `A=$AC/C=1`. `AP B0 $9486 $2000` loaded
the AP into RAM and displayed `BANKED FLASH ERASE`. An empty response at
`BANK 0-3>` returned `ABORT - NO FLASH WRITE` with `A=$E0` and carry clear.
This is a non-destructive proof of the fixed-load package, Bank-0 storage, AP
load, interactive entry, and abort behavior. It is not an erase/verify proof.

## 2026-07-21 Flash Dump AP Rejected Paste (Not A Board Proof)

The first board paste of `flash-bank-dump-ap-2000.a` was not a valid build.
ASM-F2 reported repeated `ERR=$07 BL` errors on overlong `DB` source lines and
`ERR=$03 BO` errors where a standalone label had been pasted before its
instruction. ASM-F2 continues after such a source-line rejection, so the
later `ASM OK` did not mean every intended byte had been emitted.

The resulting `PACKAGE $3000` envelope was `L=$0231`, and the resident PUT AP
stored it at `$8C8B`. `AP B0 $8C8B $2000` then stopped at `BRK 00 PC=2292`.
That package is invalid test debris: do not run or rely on `$8C8B`. This is a
source-paste rejection, not a runtime result for the dump AP. The corrected
source splits its data records into short rows and puts each control-flow label
on the same source line as its first instruction; its board gate remains open.

## 2026-07-28 STR8 Size-Pass Installation Pass, CRC Fixture Paste Stop

This is an incomplete acceptance run. It proves the frozen HIMON, ASM-F2, and
STR8 installation/readback path, but it stopped before bank fingerprints,
selected-destination backup, restore, record-service, worker-tail, and legacy
`$FFF0` gates.

The board began on the previous `00.0721(1742)` HIMON/ASM image and the old
cascading STR8 command surface. The old image's `B` printed:

```text
BACKUP ERASE B1/B2. Y: y
COPY B2->B1

COPY B3->B2

OK
```

That is pre-candidate behavior and is not evidence for the new explicit
destination command.

The old STR8 provider accepted the pinned C/D/E stream and the board entered
the new HIMON:

```text
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
...................................................................
PROGRAM C000-EFFF? Y: y...
OK

HIMON V 00.0728(1751)
```

The board-built Bank-3 low-flash erase fixture succeeded:

```text
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=03 Y=00 P=B5 S=FD Nv-BdIzC
>D 1A00 1A03
1A00: AC 00 00 00 | ....
>D 8000 800F
8000: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF | ................
```

`L F` then installed the pinned ASM image:

```text
>L F
L F S19
L @8000
LF OK WR=3C6D GO=800C
>D 8000 800F
8000: 46 4E D6 00 74 AD 56 05 | 0C 80 87 B9 20 7B 85 B0 | FN..t.V..... {..
>ASM NEW
ASM-F2 00.0728(1751)
```

The self-contained topwriter assembled cleanly. Its nonwriting stage matched
every frozen checkpoint:

```text
>G 3000
GO 3000
TW STG
TW OK

#GO# ENTRY=3000
RET A=AC X=20 Y=05 P=F5 S=FD NV-BdIzC
>D 1A00 1A0F
1A00: 00 AC 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
>D 0A00 0A0F
0A00: 4C 10 F0 4C CB F2 4C D2 | F2 4C DA F2 53 52 01 07 | L..L..L..L..SR..
>D 1244 1247
1244: 7A 0F 6A 5F | z.j_
>D 1760 176F
1760: 08 78 AD F0 1F C9 05 F0 | 0D C9 06 F0 0E C9 07 F0 | .x..............
>D 19E0 19EF
19E0: 04 48 A9 EE 1C EC 7F 68 | 0C EC 7F 60 CC CE EC EE | .H.....h...`....
>D 19F0 19FF
19F0: FF FF FF FF FF FF FF FF | FF FF 98 F0 00 F0 AC F0 | ................
```

The destructive top-sector half completed and returned success:

```text
>G 3003
GO 3003
TW PRG
TW OK

#GO# ENTRY=3003
RET A=AC X=20 Y=05 P=F5 S=FD NV-BdIzC
>D 1A00 1A03
1A00: 01 AC 00 00 | ....
```

The subsequent cold boot reported `HIMON V 00.0728(1751)` and every resident
checkpoint matched the staged image:

```text
>D F000 F00F
F000: 4C 10 F0 4C CB F2 4C D2 | F2 4C DA F2 53 52 01 07 | L..L..L..L..SR..
>D F844 F847
F844: 7A 0F 6A 5F | z.j_
>D FD60 FD6F
FD60: 08 78 AD F0 1F C9 05 F0 | 0D C9 06 F0 0E C9 07 F0 | .x..............
>D FFE0 FFEF
FFE0: 04 48 A9 EE 1C EC 7F 68 | 0C EC 7F 60 CC CE EC EE | .H.....h...`....
>D FFF0 FFFF
FFF0: FF FF FF FF FF FF FF FF | FF FF 98 F0 00 F0 AC F0 | ................
>ASM NEW
ASM-F2 00.0728(1751)
```

The first paste of `str8-bank-crc-all-3000.a` was rejected at its CRC bit-loop
label:

```text
ASM>$30B7: BIT     ASL CRCLO
ERR=$03 BO PC=$30B7
...
ASM>$30C8:         BNE BIT
...
ERR=$09 BAD FIX PC=$30CC
#56AD7400# EXEC ERR=$09
>
```

`BIT` is a 65C02 mnemonic, so ASM-F2 parsed it as an instruction rather than a
label. No `G 3000` followed this rejected assembly and the fixture never called
STR8 or changed flash. The source now uses `CRCBIT`; the corrected file is
`DOC/GUIDES/ASM/SAMPLES/str8-bank-crc-all-3000.a`, SHA-256
`D92C504C1501241F3FC791C11F081178E4B053211C3D9F7B15B5F1A5F7891326`.
Resume the acceptance card at section 5. The installed firmware does not need
to be rewritten.

## 2026-07-28 STR8 Size-Pass CRC, Command, And Restore Continuation

This continuation assembled the corrected `CRCBIT` fixture cleanly and ran all
32 read-only sector fingerprints. Status, the retired `$FFF0` bytes, and the
complete first table were:

```text
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=00 Y=01 P=B5 S=FD Nv-BdIzC
>D 1A00 1A04
1A00: AC 00 00 00 00 | .....
>D 1A08 1A0B
1A08: FF FF FF FF | ....
>D 1A10 1A4F
1A10: 3A FC 4E 26 D9 A8 E1 0F | E1 0F E1 0F E1 0F E1 0F | :.N&............
1A20: EC B7 36 70 CE 76 62 95 | C6 84 1A F2 FB 3C 77 1E | ..6p.vb......<w.
1A30: EC B7 36 70 CE 76 B2 73 | C6 84 1A F2 93 6D 77 1E | ..6p.v.s.....mw.
1A40: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
```

This passes the corrected fixture itself, all four `$FFF0=FF` observations,
and the exact frozen Bank-3 fingerprint.

The candidate command screen omitted `E`. `?` printed only the identity, and
`E` used the unknown-command path:

```text
STR8-N V0 #5F6A0F7A
ROM $F000
? B U 0 1 2 G R
STR8-N>
STR8-N V0 #5F6A0F7A
STR8-N>
?
STR8-N>
```

An explicit Bank-2 backup printed only the selected copy:

```text
BACKUP B3 TO B0/1/2:  2 ERASE? Y: y
COPY B3->B2

OK
```

A subsequent high restore from Bank 2 printed its one copy and reset through
the candidate STR8/HIMON. An empty backup selection later aborted before any
erase:

```text
RESTORE B2->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: y
COPY B2->B3

STR8-N
...
BOOT COLD
RAM ZERO OK

HIMON V 00.0728(1751)
...
BACKUP B3 TO B0/1/2:
ABORT
```

The operator then deliberately erased Bank-3 `$8000-$BFFF`, observed `$8000`
as `$FF`, and backed that state to Bank 1. Consequently this Bank-1 copy is
not the canonical candidate:

```text
#GO# ENTRY=3000
RET A=AC X=03 Y=00 P=B5 S=FD Nv-BdIzC
>D 8000
8000: FF | .
...
BACKUP B3 TO B0/1/2:  1 ERASE? Y: y
COPY B3->B1

OK
```

High restores from exact Bank 2 and the erased-low Bank 1 both reset as
designed and visibly selected the requested source. A normal Bank-2 lower
restore returned instead of resetting and recovered the first ASM byte:

```text
RESTORE B2->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: n
COPY B2->B3

OK
STR8-N>
G HIMON
BOOT WARM

HIMON V 00.0728(1751)
>D 8000
8000: 46 | F
```

This exercises the normal-restore return path and lower copy, but it is not
the formal high-preservation proof because no differential C-F CRC was
captured.

After a final erased-low Bank-1 high restore, the positive C/D/E update
completed and returned to the pinned HIMON. The first byte of every updated
sector matched the candidate:

```text
UPDATE HIMON C000-EFFF? Y: y
SEND S19 C000-EFFF
...................................................................
PROGRAM C000-EFFF? Y: y...
OK
...
HIMON V 00.0728(1751)
>D C000
C000: 78 | x
>D D000
D000: A0 | .
>D E000
E000: B1 | .
>D 8000
8000: FF | .
```

The current ASM was then reloaded:

```text
>L F
L F S19
L @8000
LF OK WR=3C6D GO=800C
>ASM NEW
ASM-F2 00.0728(1751)
ASM>$2000: .
ASM BYE
```

Evidence boundary: the corrected CRC fixture, pinned pre-copy Bank-3 image,
candidate command surface, removed `E`, empty backup abort, selected-copy
output, both restore control-flow paths, positive `U`, and final current ASM
identity passed. No CRC table was captured after `B2`, `B1`, the normal
restore, or the final recovery. Therefore selected-destination no-cascade,
normal-restore high preservation, and final canonical Bank-3 identity remain
open. The transcript also did not run the worker-tail, record-service,
`L F` equal/erased/needs-erase, negative `U`, legacy `$FFF0=FE`, or final `R`
gates.

The operations predict Bank 0 unchanged, Bank 1 with erased lower sectors and
current C-F, Bank 2 exact, and Bank 3 exact after `U` plus `L F`. The
state-aware continuation at the top of
`DOC/GUIDES/STR8/STR8_SIZE_PASS_BOARD_TEST.md` begins by measuring that state
and stops on any mismatch before further writes.

## 2026-07-28 STR8 Size-Pass State-Aware `RUN2-PRE` Proof

The board cold-booted the pinned HIMON and assembled the corrected CRC fixture
cleanly:

```text
BOOT COLD
RAM ZERO OK

HIMON V 00.0728(1751)
>ASM NEW
ASM-F2 00.0728(1751)
...
ASM>$30B7: CRCBIT  ASL CRCLO
...
ASM>$30CA:         BNE CRCBIT
...
ASM OK
SEAL> .
ASM BYE
```

The read-only run returned success with carry set. All four retired
enrollment bytes were `$FF`, and every row exactly matched the predicted
post-recovery state:

```text
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=00 Y=01 P=B5 S=FD Nv-BdIzC
>D 1A00 1A04
1A00: AC 00 00 00 00 | .....
>D 1A08 1A0B
1A08: FF FF FF FF | ....
>D 1A10 1A4F
1A10: 3A FC 4E 26 D9 A8 E1 0F | E1 0F E1 0F E1 0F E1 0F | :.N&............
1A20: E1 0F E1 0F E1 0F E1 0F | C6 84 1A F2 47 98 6E 18 | ............G.n.
1A30: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A40: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
>
```

This closes the final canonical Bank-3 CRC after the preceding `U` plus
`L F` recovery. It also proves the intended differential setup: Bank 0 is
unchanged, Bank 1 has erased lower sectors and candidate high sectors, and
Banks 2 and 3 are exact candidates. The fixture remains resident at `$3000`.

No backup or restore occurred in this continuation. Selected-destination
no-cascade and differential normal-restore preservation therefore remain
open. The next destructive operation is the state-aware Bank-2 backup in
`DOC/GUIDES/STR8/STR8_SIZE_PASS_BOARD_TEST.md`; Bank 1 must remain unchanged
afterward.

## 2026-07-28 STR8 Size-Pass Aborted `B` Inputs And Exact B2 Restore

This continuation entered the candidate STR8. Main-menu command `3` took the
unknown-command path. Two backup prompts then aborted without a visible
destination:

```text
STR8-N>
?
STR8-N>
BACKUP B3 TO B0/1/2:
ABORT
STR8-N>
BACKUP B3 TO B0/1/2:
ABORT
```

Because neither prompt echoed `2` and neither printed `2 ERASE?`, `COPY
B3->B2`, or `OK`, this is not a Bank-2 backup and contributes no no-cascade
evidence. The next input was main-menu command `2`, which invoked restore:

```text
STR8-N>
RESTORE B2->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: y
COPY B2->B3

STR8-N

HIMON IN 3S. S=STR8-N  3 2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0728(1751)
```

Bank 2 and Bank 3 were exact candidates before this operation, so the high
restore was expected to be content-neutral. It exercised the reset path again
but cleared the RAM fixture. The operator reassembled the corrected fixture,
which returned success and reproduced the entire prior state:

```text
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=00 Y=01 P=B5 S=FD Nv-BdIzC
>D 1A00 14FF
D [a [b]]
>D 1A00 1A50
1A00: AC 00 00 00 00 00 00 00 | FF FF FF FF 00 00 00 00 | ................
1A10: 3A FC 4E 26 D9 A8 E1 0F | E1 0F E1 0F E1 0F E1 0F | :.N&............
1A20: E1 0F E1 0F E1 0F E1 0F | C6 84 1A F2 47 98 6E 18 | ............G.n.
1A30: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A40: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A50: 00 | .
>
```

The first dump command had a mistyped end address (`14FF`) and was rejected
by HIMON; it did not alter memory or flash. The corrected dump proves all
`$FFF0` bytes remain `$FF`, Bank 0 and Bank 1 retain their differential rows,
and Banks 2 and 3 remain exact.

The board ended at HIMON with the CRC fixture resident at `$3000`. The next
operation remains the selected Bank-2 backup. The acceptance card now
separates keyboard input from expected output so the destination `2` is
entered while `BACKUP B3 TO B0/1/2:` is waiting.

## 2026-07-28 STR8 Size-Pass Backup Selection And Negative Confirmation

This continuation again entered the candidate STR8. Main-menu command `3`
used the unknown-command path and an empty backup destination aborted. The
operator then supplied valid destinations 2 and 1, and STR8 printed the
matching confirmation for each:

```text
STR8-N>
?
STR8-N>
BACKUP B3 TO B0/1/2:
ABORT
STR8-N>
BACKUP B3 TO B0/1/2:  2 ERASE? Y: n
ABORT
STR8-N>
BACKUP B3 TO B0/1/2:  1 ERASE? Y: n
ABORT
STR8-N>
G HIMON
BOOT WARM
```

There was no `COPY` line or `OK` after either selection. These are valid
negative-confirmation tests: destinations 2 and 1 route to their own prompts,
and `n` prevents flash mutation. They are not selected-copy or no-cascade
proofs.

The resident CRC fixture then returned success and reproduced the full
differential table:

```text
> G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=00 Y=01 P=B5 S=FD Nv-BdIzC
>D 1A00 1A50
1A00: AC 00 00 00 00 00 00 00 | FF FF FF FF 00 00 00 00 | ................
1A10: 3A FC 4E 26 D9 A8 E1 0F | E1 0F E1 0F E1 0F E1 0F | :.N&............
1A20: E1 0F E1 0F E1 0F E1 0F | C6 84 1A F2 47 98 6E 18 | ............G.n.
1A30: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A40: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A50: 00 | .
>
```

Thus no flash changed: Bank 1 remains distinctive and Banks 2 and 3 remain
exact. The board ended at HIMON with the fixture resident at `$3000`. The
next required destructive input is `y` at the selected Bank-2 `2 ERASE? Y:`
prompt, followed by a CRC proof that Bank 1 did not change.

## 2026-07-28 STR8 Size-Pass Positive B2 No-Cascade Proof

The first Bank-2 selection received `2` rather than `y` at its erase
confirmation and aborted safely. The repeated selection received `y`, copied
only to Bank 2, and returned success:

```text
STR8-N>
BACKUP B3 TO B0/1/2:  2 ERASE? Y: 2
ABORT
STR8-N>
BACKUP B3 TO B0/1/2:  2 ERASE? Y: y
COPY B3->B2

OK
STR8-N>
G HIMON
BOOT WARM

HIMON V 00.0728(1751)
```

There was no `B2->B1`, `B1->B0`, or second copy line. The resident read-only
fixture returned success after the write:

```text
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=00 Y=01 P=B5 S=FD Nv-BdIzC
>D 1A00 1A50
1A00: AC 00 00 00 00 00 00 00 | FF FF FF FF 00 00 00 00 | ................
1A10: 3A FC 4E 26 D9 A8 E1 0F | E1 0F E1 0F E1 0F E1 0F | :.N&............
1A20: E1 0F E1 0F E1 0F E1 0F | C6 84 1A F2 47 98 6E 18 | ............G.n.
1A30: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A40: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A50: 00 | .
>
```

Every byte matches `RUN2-PRE`. Bank 2 equals Bank 3, Bank 0 is unchanged, and
Bank 1 retains its distinctive four erased-low CRC pairs. A legacy cascade
would have changed Bank 1 to the exact candidate row, so this is the
hardware-selected-destination/no-cascade proof for `B2`.

The board ended at HIMON with the CRC fixture resident at `$3000`. Bank 0
remains distinctive and is the source for the next differential normal
restore. That gate must answer `n` at `FLASH C000-FFFF?`, prove Bank-3 C-F
unchanged by CRC, then recover the exact candidate through Bank 2.

## 2026-07-28 STR8 Size-Pass Differential Restore Abort

This attempt did not reach a flash operation. The backup destination prompt
received empty input, and the first Bank-0 restore confirmation received `n`:

```text
STR8-N>
BACKUP B3 TO B0/1/2:
ABORT
STR8-N>
RESTORE B0->B3? Y: n
ABORT
STR8-N>
G HIMON
BOOT WARM

HIMON V 00.0728(1751)
```

Because the first restore question was declined, STR8 never printed
`WARN: MAY NOT BOOT`, never asked `FLASH C000-FFFF?`, and never copied Bank 0.
The differential restore therefore remains pending.

At HIMON, a bare `3000` was interpreted as a name lookup and failed harmlessly.
The corrected `G 3000` invocation returned success and proved the complete
bank state was unchanged:

```text
> 3000
#1ED86626# HSH_NF!
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=00 Y=01 P=B5 S=FD Nv-BdIzC
>D 1A00 1A50
1A00: AC 00 00 00 00 00 00 00 | FF FF FF FF 00 00 00 00 | ................
1A10: 3A FC 4E 26 D9 A8 E1 0F | E1 0F E1 0F E1 0F E1 0F | :.N&............
1A20: E1 0F E1 0F E1 0F E1 0F | C6 84 1A F2 47 98 6E 18 | ............G.n.
1A30: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A40: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A50: 00 | .
>
```

The board ended at HIMON with the CRC fixture resident at `$3000`. No recovery
is needed. On the next attempt, type `y` at `RESTORE B0->B3?` and type `n`
only after the separate `FLASH C000-FFFF?` prompt appears.

## 2026-07-28 STR8 Size-Pass Positive B0 And Same-Image Normal Restore

The run first selected Bank 0 as a positive backup destination. It printed
only the requested copy and returned success:

```text
STR8-N>
BACKUP B3 TO B0/1/2:  0 ERASE? Y: y
COPY B3->B0

OK
```

This operation replaced Bank 0's distinctive old image with the exact
Bank-3 candidate. The operator then supplied the correct two-answer sequence
for ordinary restore:

```text
STR8-N>
RESTORE B0->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: n
COPY B0->B3

OK
STR8-N>
```

The normal-restore prompt, lower-copy path, `OK` return, and high-flash
decline all executed. However, Bank 0 and Bank 3 were identical before this
restore, so it is not a differential proof that high data from the source was
excluded.

The transcript ended at STR8 before a post-operation CRC capture. Bank 3
should already be exact, so a Bank-2 recovery is neither required nor desired
at this point. The CRC fixture remains in RAM. The immediate next action is
`G`, then `G 3000` and the full table. Bank 0, Bank 2, and Bank 3 must be the
exact row, and Bank 1 must retain its four erased-low pairs. That capture will
close the positive Bank-0 selected-destination/no-cascade gate.

Because the original distinctive Bank-0 high sectors were overwritten, the
stronger normal-restore proof is deferred to the legacy `$FFF0=FE` gate. That
gate now uses Bank 0's `$B04A` modified F-sector CRC against canonical Bank
3's `$186E`, performs a lower-only Bank-0 restore, and requires the
differential high CRCs to remain unchanged.

## 2026-07-28 STR8 Size-Pass Positive B0 Post-Copy CRC

The operator returned warm to HIMON and ran the resident read-only fixture:

```text
?
STR8-N>
G HIMON
BOOT WARM

HIMON V 00.0728(1751)
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=00 Y=01 P=B5 S=FD Nv-BdIzC
>D 1A00 1A50
1A00: AC 00 00 00 00 00 00 00 | FF FF FF FF 00 00 00 00 | ................
1A10: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A20: E1 0F E1 0F E1 0F E1 0F | C6 84 1A F2 47 98 6E 18 | ............G.n.
1A30: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A40: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A50: 00 | .
>
```

All `$FFF0` bytes remain `$FF`. Bank 0 now exactly matches Bank 3, while the
unselected Bank 1 retains its distinctive erased-low row and Bank 2 remains
exact. This closes the positive Bank-0 selected-destination/no-cascade gate.
It also confirms that the subsequent same-image normal restore ended on the
exact Bank-3 candidate.

The initial `?` is an unknown-command response at STR8 and has no state
effect. The board ended at HIMON with the CRC fixture resident at `$3000`.
The next gates are invalid backup destination `3`, followed by the positive
Bank-1 copy and final all-four-banks exact CRC.

## 2026-07-28 STR8 Size-Pass Bank-1 Restore And Recovery

This run did not execute a Bank-1 backup. Main-menu command `1` selected
restore, and both confirmations were accepted:

```text
STR8-N>
RESTORE B1->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: y
COPY B1->B3

STR8-N

HIMON IN 3S. S=STR8-N  3 2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0728(1751)
```

Bank 1 still contained erased lower sectors and current high sectors, so the
full restore intentionally replaced Bank-3 ASM with erased data. The reset
cleared the RAM fixture. The resulting failures were expected consequences
of those two facts, not new firmware defects:

```text
>ASM NEW
#56AD7400# HSH_NF!
>G 3000
GO 3000

BRK 00 PC=3002
...
```

`L F` reinstalled the pinned ASM:

```text
>L F
L F S19
L @8000
LF OK WR=3C6D GO=800C
>ASM NEW
ASM-F2 00.0728(1751)
```

After the operator reassembled the CRC fixture, Bank 3 was exact again and
Bank 1 remained distinctive. The run then performed another Bank-0 normal
restore with high flash declined; its CRC table remained unchanged. A
subsequent exact Bank-0 high restore reset and cleared RAM again:

```text
RESTORE B0->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: n
COPY B0->B3

OK
...
RESTORE B0->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: y
COPY B0->B3

STR8-N
...
BOOT COLD
RAM ZERO OK
```

The immediate `G 3000` trap and mistyped `AASM NEW` after reset were harmless.
The operator again loaded ASM with `L F`, assembled the corrected fixture, and
finished on the fully recovered state:

```text
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=00 Y=01 P=B5 S=FD Nv-BdIzC
>D 1A00 1A50
1A00: AC 00 00 00 00 00 00 00 | FF FF FF FF 00 00 00 00 | ................
1A10: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A20: E1 0F E1 0F E1 0F E1 0F | C6 84 1A F2 47 98 6E 18 | ............G.n.
1A30: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A40: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A50: 00 | .
>
```

Banks 0, 2, and 3 are exact; Bank 1 still has erased lower sectors/current
high sectors. The CRC fixture is resident at `$3000`. No Bank-1 backup or
invalid backup-destination-3 test occurred. For the remaining positive test,
the operator must type `B` at `STR8-N>`, wait for
`BACKUP B3 TO B0/1/2:`, and only then type `1`.

## 2026-07-28 STR8 Size-Pass Positive B1 And Four-Bank Convergence

The operator selected Bank 1 through the backup prompt. STR8 printed only the
requested copy and returned success:

```text
BACKUP B3 TO B0/1/2:  1 ERASE? Y: y
COPY B3->B1

OK
STR8-N>
G HIMON
BOOT WARM

HIMON V 00.0728(1751)
```

The first dump spelling omitted the space after `D` and caused only a
harmless HIMON lookup failure. The corrected dump showed complete
four-bank convergence:

```text
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=00 Y=01 P=B5 S=FD Nv-BdIzC
>D1A00 1A50
#0943D2CD# HSH_NF!
>D 1A00 1A50
1A00: AC 00 00 00 00 00 00 00 | FF FF FF FF 00 00 00 00 | ................
1A10: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A20: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A30: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A40: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A50: 00 | .
```

All four `$FFF0` values are `$FF`, and every bank has the pinned candidate
row. This closes the positive Bank-1 backup path. Combined with the earlier
differential post-copy captures for Bank 2 and Bank 0, the selected-copy and
no-cascade behavior passes for all three destinations.

The operator reentered STR8, but the final backup destination prompt again
received empty input:

```text
BACKUP B3 TO B0/1/2:
ABORT
STR8-N>
```

This is another safe empty-input pass, not the invalid-destination-3 test.
The board ended at STR8 with all banks canonical and the CRC fixture resident.
Type `B`, wait for `BACKUP B3 TO B0/1/2:`, then type `3`; it must abort without
an erase/copy. After that one non-writing gate, continue to the worker-tail
fixture.

## 2026-07-28 STR8 Invalid-Destination Echo Clarification

The operator confirms that the final backup-destination response in the
preceding entry was `3`, not empty input:

```text
BACKUP B3 TO B0/1/2:
ABORT
STR8-N>
```

The lack of a printed `3` is expected firmware behavior, not missing terminal
input. `STR8_CMD_BACKUP` reads the byte, rejects values below `'0'` or at/above
`'3'`, and branches directly to `ABORT`. It calls
`STR8_CON_WRITE_BYTE_BLOCK` to republish the destination only after the range
check passes. Therefore valid selections appear before `ERASE?`, while invalid
`3` remains unechoed.

This clarification closes the invalid backup-destination gate. No `ERASE?`,
`COPY`, or reset followed the input. Combined with the accepted B0/B1/B2 copy
and CRC evidence, sections 6 and 7 pass. The board remains at STR8 with all
four banks canonical; the next gate is the section-8 worker-tail fixture.

## 2026-07-28 STR8 Shared Worker-Tail Board Proof

The operator returned warm to the pinned HIMON, assembled
`str8-worker-tail-proof-3000.a` cleanly with `ASM-F2 00.0728(1751)`, and ran
the RAM-only fixture:

```text
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=AC X=03 Y=00 P=F5 S=FD NV-BdIzC
>D 1A00 1A04
1A00: AC 05 46 46 00 | ..FF.
>D 8000
8000: 46 | F
>
```

The exact `AC 05 46 46` row proves all five cases completed and Bank-3
`$8000` was unchanged. This covers the candidate worker's exact copy
bounds/guards, shared polling immediate-success path, forced timeout and flash
reset return, impossible 0-to-1 write rejection without a program command,
and the factored `$AA/$55` unlock/reset tail. The fixture issued no erase or
program command.

Section 8 passes on hardware. The board ended at HIMON with all flash banks
canonical and the worker fixture at `$3000`. The next gate is the
section-9 current-face record-service regression.

## 2026-07-28 STR8 Size-Pass Final Hardware Acceptance

The 3,478-line source transcript has SHA-256
`F1CDBCAB8E3131AD59DB9DF35D82A458D996340B901ADA1AFFF0D0E6F8CA1E07`.
The operator continued with the same frozen board candidate:

```text
HIMON V 00.0728(1751)
ASM-F2 00.0728(1751)
STR8-N V0 #5F6A0F7A
```

The section-9 current-face record fixture loaded at the required entry and
all four service cases returned the accepted status/case/length rows:

```text
L OK=07BB GO=3000
RET A=AC X=0F Y=01 P=35 S=FD Nv-BdIzC
6000: 11 22 33 44 | ."3D
RET A=AC X=06 Y=02 P=35 S=FD Nv-BdIzC
RET A=AC X=01 Y=03 P=35 S=FD Nv-BdIzC
RET A=AC X=01 Y=04 P=75 S=FD NV-BdIzC
```

The separate `L G` transport fixture also passed:

```text
L OK=0080 GO=3000
#LOADGO# ENTRY=3000
RET A=A5 X=30 Y=30 P=F5 S=FD NV-BdIzC
4900: A5 | .
```

Section 10 exercised all four `L F` byte-programming decisions. The matching
write, erased-byte write, and repeated matching write succeeded. The
zero-over-`$5A` case correctly refused a required erase without changing the
scratch row:

```text
LF OK WR=0004 GO=8000
8000: 46 | F
LF OK WR=0001 GO=BFE2
BFE0: FF FF 5A FF | ..Z.
LF OK WR=0001 GO=BFE2
BFE0: FF FF 5A FF | ..Z.
LF ERASE=BFE2 OLD=5A NEW=00
LF FAIL=03 WR=0000 SKIP=0004 GO=BFE0
BFE0: FF FF 5A FF | ..Z.
```

An exact Bank-2 normal restore with high flash declined returned `OK`, and the
subsequent CRC fixture showed all banks canonical and the scratch row erased.
Section 11 then sent the empty/out-of-range negative `U` inputs. They produced
`S19 FAIL`, `NO S19 DATA`, and an additional `S19 FAIL`; no `PROGRAM` prompt
or flash operation followed. A full CRC rerun remained canonical.

Section 12 first staged and programmed the deliberate legacy enrollment byte
`$FFF0=FE` while retaining the pinned vectors:

```text
TW STG
TW OK
19F0: FE | .
TW PRG
TW OK
1A00: 01 AC 00 00 | ....
FFF0: FE FF FF FF FF FF FF FF | FF FF 98 F0 00 F0 AC F0 | ................
```

STR8 accepted that legacy active-low bit as unprotected. A selected Bank-0
backup printed `COPY B3->B0` and returned `OK`, with no enrollment gate.
The exact top writer was then reassembled, staged with canonical `$FFF0=FF`,
programmed successfully, and verified with the pinned vectors.

The read-only CRC fixture captured the intended differential state:

```text
1A00: AC 00 00 00 00 00 00 00 | FE FF FF FF 00 00 00 00 | ................
1A10: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 4A B0 | ..6p.v4.....G.J.
1A20: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A30: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A40: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
```

The operator then selected normal Bank-0 restore and declined high flash:

```text
RESTORE B0->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: n
COPY B0->B3

OK
```

The complete post-restore CRC table was byte-for-byte identical to the
differential table above. Bank 0 retained `$FFF0=FE` and its F-sector CRC
`4A B0`, while live Bank 3 retained `$FFF0=FF` and CRC `6E 18`. This is the
decisive hardware proof that the ordinary restore does not copy the protected
high sector.

A final selected `B3->B0` cleanup returned `OK`. All four `$FFF0` bytes then
read `$FF`, and every bank converged to the pinned candidate row:

```text
1A00: AC 00 00 00 00 00 00 00 | FF FF FF FF 00 00 00 00 | ................
1A10: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A20: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A30: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
1A40: EC B7 36 70 CE 76 34 9B | C6 84 1A F2 47 98 6E 18 | ..6p.v4.....G.n.
```

Finally, section 13 exercised the STR8 reset command. The board cold-booted,
cleared RAM, and retained the canonical top sector and fixed vectors:

```text
BOOT COLD
RAM ZERO OK

HIMON V 00.0728(1751)
FFF0: FF FF FF FF FF FF FF FF | FF FF 98 F0 00 F0 AC F0 | ................
```

Sections 9-13 pass. Together with the prior entries for installation,
resident faces, command parsing, non-cascading B0/B1/B2 backup, restore
behavior, and the shared worker tail, this completes on-board acceptance of
the STR8 resident and worker size pass. The board finished with the exact
candidate in all four banks and no remaining recovery action.

## 2026-07-28 STR8 J0-J2 Read-Only Inventory And RAM Handoff Proof

The 1,431-line operator transcript is 25,453 bytes and has SHA-256
`AC5A9E549227EE48D7F7B40F7C2E8415F37945BFB403DDE57C256315672AAAC5`.
The operator first completed a confirmed Bank-3 `$C000-$EFFF` `U` update;
Bank 3 then cold-booted HIMON `V 00.0728(2121)`. The inventory below is the
post-update baseline. No flash mutation occurred during the inventory or
subsequent `J` handoffs.

The read-only whole-bank fixture assembled at `$3000`, returned `$AC`, and
left the explicit bank latch at Bank 3:

```text
RET A=AC X=03 Y=0F P=B5 S=FD Nv-BdIzC
1A00: AC 00 00 00 00 EE 03 00 | 00 00 00 00 00 00 00 00 | ................
1A10: 59 4B 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5 | YK..............
1A20: 3D 2A 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5 | =*..............
1A30: EF 04 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5 | ................
1A40: 80 4F 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5 | .O..............
```

Decoded provisional inventory:

```text
Bank 0  full-image CRC $4B59
Bank 1  full-image CRC $2A3D
Bank 2  full-image CRC $04EF
Bank 3  full-image CRC $4F80

all banks  NMI $F098, RESET $F000, IRQ $F0AC
all banks  F000-F003 = A0 00 B1 CF
all banks  F00C-F00F = 04 B0 0C A5
```

The fixture was run a second time after the first `J2` cycle and produced the
same status, latch, CRC, vector, and face records.

The host candidate RAM image loaded as `L OK=0B4C GO=3000` and identified
itself as Bank 3:

```text
STR8-N V0 #5F6A0F7A B3
RAM $0200 BUF $4000-$4FFF
? B U 0 1 2 J0 J1 J2 G R
```

All three requested handoffs entered a target through its own `$F000` reset
path without `JERR`. Physical reset after every target returned to the
installed Bank-3 STR8 and HIMON `V 00.0728(2121)`:

```text
J B2 -> target HIMON V 00.0728(2113) -> reset -> Bank 3 V 00.0728(2121)
J B1 -> target HIMON V 00.0728(2113) -> reset -> Bank 3 V 00.0728(2121)
J B0 -> target HIMON V 00.0728(2042) -> reset -> Bank 3 V 00.0728(2121)
```

A repeated `L G` attempt with no valid S19 stream produced many `LERR=$01`
lines between the `J2` and `J1` cycles. It was not a `J` failure and physical
reset again recovered Bank 3.

Phase A passes. Phase B proves the RAM candidate's parser, direct RAM bank
handoff, and physical-reset recovery for all three banks. Two acceptance
items remain before resident installation: Banks 1 and 2 need a read-only
identity distinction because both banners report version `2113` (their
reported ASM presence differs), and a final whole-bank inventory must prove
the baseline CRCs remained unchanged after the last `J1`/`J0` cycles. The
resident stored-worker mode `$08` path remains uninstalled and unproven.

## 2026-07-28 STR8 J0-J2 Identity Follow-Up And Bank-3 State Change

The 2,337-line follow-up transcript is 40,073 bytes and has SHA-256
`F46E69444B5103004AF0931CD59E106D145D1AF182F65D5FFD12D004759B8B31`.

The direct target dumps distinguish the two targets that share HIMON version
`2113`:

```text
J B2
HIMON V 00.0728(2113)
8000: 46 4E D6 00 74 AD 56 05 | 0C 80 87 B9 20 7B 85 B0

J B1
HIMON V 00.0728(2113)
8000: FF FF FF FF FF FF FF FF | FF FF FF FF FF FF FF FF
```

Bank 2 has the expected ASM-F2 low-flash face; Bank 1 is erased at
`$8000-$800F`. A subsequent Bank-0 dump was also erased there, and `ASM NEW`
returned `#56AD7400# HSH_NF!`, independently confirming that Bank 0 lacks ASM.
This closes the Bank-1/Bank-2 identity ambiguity in the RAM handoff proof.

The later part of the session is not a clean non-destructive post-`J`
inventory. After the Bank-0 test, the operator invoked the Bank-3 bootloader,
attempted `L F`, and then explicitly confirmed a full high-flash
Bank-2-to-Bank-3 restore:

```text
LF ERASE=B9CC OLD=31 NEW=35
LF FAIL=03 WR=39C0 SKIP=02AD GO=800C

RESTORE B2->B3? Y: y
WARN: MAY NOT BOOT
FLASH C000-FFFF? Y: y
COPY B2->B3
```

The final inventory completed and restored the latch to Bank 3:

```text
1A00: AC 00 00 00 00 EE 03 00 | 00 00 00 00 00 00 00 00
1A10: 59 4B 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5
1A20: 3D 2A 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5
1A30: EF 04 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5
1A40: EF 04 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5
```

Banks 0-2 retained their original CRCs `$4B59/$2A3D/$04EF`. Bank 3 changed
from the post-`U` baseline `$4F80` to `$04EF` and now exactly matches Bank 2,
as expected after the confirmed full restore. Its low face is the ASM-F2
signature and it boots HIMON `V 00.0728(2113)`, not the prior Bank-3
`V 00.0728(2121)`.

The identity follow-up passes, but the full-bank restore deliberately
invalidates the requested clean post-`J` Bank-3 comparison. Do not install the
resident `J` candidate until the intended Bank-3 payload is chosen. The
recommended recovery of the reported layout is to repeat the previously
successful `$C000-$EFFF` `U` update, restore HIMON `2121`, and require a fresh
inventory of `$4B59/$2A3D/$04EF/$4F80` with PCR `$EE` and decoded Bank 3 before
the top-sector install.

## 2026-07-28 STR8 J0-J2 Bank-3 Recovery And Clean CRC Acceptance

The 4,324-line continuation transcript is 81,772 bytes and has SHA-256
`F5199F7754F1DF246B5E6D7CCC24B7F36E06B45ACDEC8E73BF47A88D680E55DC`.
It includes the prior sessions and then continues through the requested
Bank-3 recovery and clean read-only comparisons.

The operator repeated the proven `$C000-$EFFF` `U` update after the earlier
full Bank-2-to-Bank-3 restore. Programming returned `OK`; warm and cold boot
both reported HIMON `V 00.0728(2121)`. The recovered pre-jump inventory was:

```text
1A00: AC 00 00 00 00 EE 03 00 | 00 00 00 00 00 00 00 00
1A10: 59 4B 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5
1A20: 3D 2A 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5
1A30: EF 04 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5
1A40: 80 4F 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5
```

This restores the intended full-image CRCs:

```text
Bank 0 $4B59   Bank 1 $2A3D   Bank 2 $04EF   Bank 3 $4F80
```

The exact `$0B4C` RAM candidate then executed `J2`, entered target HIMON
`2113`, and recovered by physical reset to Bank-3 HIMON `2121`. A complete
inventory immediately afterward matched the recovered baseline byte for
byte. Some invalid `L G` transport text produced `LERR=$01`/`LS03` before
that reset; it issued no flash operation and did not change the inventory.

The operator next executed `J0`, entered target HIMON `2042`, confirmed its
missing ASM hash, and physically reset to Bank 3. The final complete inventory
again matched the recovered baseline byte for byte:

```text
1A00: AC 00 00 00 00 EE 03 00 | 00 00 00 00 00 00 00 00
1A10: 59 4B 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5
1A20: 3D 2A 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5
1A30: EF 04 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5
1A40: 80 4F 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5
```

No `L F`, restore, backup, or other flash mutation occurred between the
recovered baseline and final inventory. Together with the earlier successful
`J1` entry, reset recovery, Bank-1 erased low-face proof, and unchanged Bank-1
CRC, this closes Phase A and the direct-RAM Phase B acceptance for all three
targets. It proves the direct RAM candidate's bank selection, plausible-vector
handoff, physical-reset recovery, and non-destructive behavior on the current
board images.

The live top sector is still the older STR8 without `J` commands. Resident
worker mode `$08` has not executed on hardware. Phase C installation and its
post-install resident `J2`/`J1`/`J0` sequence remain the only implementation
acceptance gate.

## 2026-07-28 STR8 J0-J2 Resident Installation Partial Acceptance

The 552-line Phase-C transcript is 12,098 bytes and has SHA-256
`10E7FD3F4A619D7D7958AD2FF8F244C7DE73055E8A8D0359DE53E741641AE808`.
It begins after the protected Bank-3 top sector was installed; the actual
TopWriter `S`/`V`/`P` programming exchange is not present.

The installed result cold-boots through the new Bank-3 prompt, times out into
the intended HIMON `2121`, and exposes the resident candidate command surface:

```text
B3 HIMON IN 3S. S=STR8-N  3 2 1
BOOT COLD
RAM ZERO OK
HIMON V 00.0728(2121)

STR8-N V0 #5F6A0F7A B3
ROM $F000
? B U 0 1 2 J0 J1 J2 G R
```

The only post-install table in the capture reports PCR `$EE`, decoded Bank 3,
unchanged Banks 0-2 CRCs, provisional Bank-3 CRC `$0D8A`, and the new hardware
vectors:

```text
1A00: AC 00 00 00 00 EE 03 00 | 00 00 00 00 00 00 00 00
1A10: 59 4B 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5
1A20: 3D 2A 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5
1A30: EF 04 98 F0 00 F0 AC F0 | A0 00 B1 CF 04 B0 0C A5
1A40: 8A 0D 9A F0 00 F0 AE F0 | A0 00 B1 CF 04 B0 0C A5
```

This is useful diagnostic evidence, but not the final inventory gate. The old
fixture was assembled and started while Bank 2 was visible after the RAM
candidate's `J2`. Its `G 3000` run produced anomalous `... OK` and repeated
STR8 boot output. A later confirmed `U` rewrote Bank 3 `$C000-$EFFF`; the
table above was dumped only after that warm boot and was not recomputed
afterward. The final corrected fixture must start from Bank-3 HIMON and
reconfirm all four CRCs.

The resident ROM path then executed `J1`, entered HIMON `2113` without ASM,
and recovered by physical reset to the installed Bank-3 prompt. Resident `J0`
subsequently entered HIMON `2042` without `JERR`. The transcript ends at that
target, before the required physical-reset recovery and final inventory.
Resident `J2` was not exercised; the `J2` near the beginning used the loaded
`$0B4C` RAM candidate.

The zero `$1A00-$1A4F` dumps after the `J1` and `J0` target boots are expected
consequences of `RAM ZERO OK`; they are not inventory results.

### Inventory face-field correction

Review of `str8-jump-inventory-3000.a` found that the record comments promised
Bank `$F000-$F003` and `$F00C-$F00F`, but the implementation read staged RAM
`$4F00-$4F03` and `$4F0C-$4F0F`. For a `$F000` sector staged at
`$4000-$4FFF`, those locations correspond to Bank `$FF00` and `$FF0C`, not
`$F000` and `$F00C`. Therefore every prior full-image CRC and vector result is
valid, but the trailing eight bytes in each historical record are FF-page
face bytes. They are not evidence of the STR8 service header.

The fixture is corrected to read `$4000-$4003` and `$400C-$400F`. It must run
from Bank 3 because `$F003` is the live installed STR8 service contract. Final
Phase C acceptance requires:

```text
physical reset from the current J0 target -> Bank 3 HIMON 2121
resident J2 -> target HIMON 2113 -> physical reset -> Bank 3
corrected inventory status/PCR/bank = AC/EE/03
Bank 0-2 CRCs = $4B59/$2A3D/$04EF
Bank 3 CRC = $0D8A
Bank 3 F000-F003 = 4C 10 F0 4C
Bank 3 F00C-F00F = 53 52 01 07
direct marker/worker/vector dumps match the installed candidate
```

The resident candidate is installed and resident `J1` plus target entry for
`J0` pass. Do not yet call resident `J0`-`J2` fully hardware-proven.

## 2026-07-28 STR8 J0-J2 Resident Functional Acceptance And Echo Gap

The 334-line follow-up transcript is 9,346 bytes and has SHA-256
`2D761D78F2F888663A7233A5C6B673AD3B4B6567A4EBE91C3F648A3A3188C2F5`.

The first cycle began at the Bank-0 target left by the preceding transcript.
Physical reset returned to the Bank-3 countdown and HIMON `2121`, closing
resident `J0` reset recovery. The operator then entered the resident ROM
STR8, selected `J2`, reached target HIMON `2113`, and physically reset back to
Bank 3. This closes the resident worker-mode `$08` functional handoff and
reset-recovery matrix for `J0`, `J1`, and `J2`.

From Bank-3 HIMON, the corrected inventory fixture assembled at `$3000`,
returned `A=$AC/C=1`, and reported PCR `$EE` with decoded Bank 3:

```text
1A00: AC 00 00 00 00 EE 03 00 | 00 00 00 00 00 00 00 00
1A10: 59 4B 98 F0 00 F0 AC F0 | 4C 10 F0 4C 53 52 01 07
1A20: 3D 2A 98 F0 00 F0 AC F0 | 4C 10 F0 4C 53 52 01 07
1A30: EF 04 98 F0 00 F0 AC F0 | 4C 10 F0 4C 53 52 01 07
1A40: DB E4 9A F0 00 F0 AE F0 | 4C 10 F0 4C 53 52 01 07
```

The authoritative installed full-image CRCs are therefore:

```text
Bank 0 $4B59   Bank 1 $2A3D   Bank 2 $04EF   Bank 3 $E4DB
```

The corrected face fields prove that every bank currently begins with the
`$F000` STR8 jump and `SR/01/07` service header. The direct installed-image
checks also match the candidate exactly:

```text
F000: 4C 10 F0 4C 19 F3 4C 20 F3 4C 28 F3 53 52 01 07
F8D4: 7A 0F 6A 5F
FD16: 08 78 AD F0 1F C9 05 F0 11 C9 06 F0 12 C9 07 F0
FFF0: FF FF FF FF FF FF FF FF FF FF 9A F0 00 F0 AE F0
```

This supersedes provisional Bank-3 CRC `$0D8A`, which came from the anomalous
old-fixture run. Banks 0-2 retain their established CRCs, and the installed
resident `J0`-`J2` handoff is functionally hardware-proven. The original
TopWriter `S`/`V`/`P` exchange is still absent, but the installed bytes,
vectors, inventory, boot behavior, and all three handoffs are now captured.

The operator also identified a user-interface gap: typed `J0`, `J1`, and `J2`
do not appear after `STR8-N>`. The parser is not losing the bytes—the
transcript shows the resulting `J B0` and `J B2` lines and successful
handoffs. `STR8_READ_COMMAND` consumes input without echo; unlike confirmation
and backup operands, the `J` command path did not write either byte back.

The host source now echoes the recognized `J` and every consumed operand byte.
This is a new six-byte resident-only follow-up candidate. It does not alter the
worker, handoff state, bank selection, or vectors. It is not installed in this
transcript. The regenerated 31,052-byte
`str8n-topwrite-transient-3000.a` has SHA-256
`974B8B1F68A62B378BE3E18E4439692CA178D7F6CC14FCBEA69B4DB240DA8F64`.
It needs a protected top-sector install plus visible-command smoke before the
echo behavior is hardware-proven.

## 2026-07-28 STR8 J Echo RAM Pass And Protected-Sector Install

The 1,685-line continuation transcript is 55,168 bytes and has SHA-256
`224980B628304641BB8B5BFDA9428C2EBA183663A2D9AAEFA0FF7C93A598CF66`.
It includes the preceding functional-acceptance material, then continues with
the new echo candidate's RAM preflight and protected-sector installation.

From Bank-3 HIMON, the new RAM candidate loaded at the exact expected length:

```text
L OK=0B52 GO=3000

STR8-N V0 #5F6A0F7A B3
RAM $0200 BUF $4000-$4FFF
? B U 0 1 2 J0 J1 J2 G R
STR8-N>J2
J B2
```

This is the first hardware proof that the added echo writes display the
two-byte command. The handoff selected Bank 2's older top-sector STR8 surface,
which lacks the Bank-3 suffix and `J` help, and physical reset returned to the
installed Bank-3 image. The transcript does not reload the RAM candidate for
`J1` or `J0`; later invisible `J B1`/`J B0` cycles still use the pre-echo
resident ROM.

The regenerated TopWriter then assembled through `END` at `$5000` and executed
the complete guarded menu sequence:

```text
TOPWRITER
TW> S
TW STG
TW OK
TW> V
TW OK
TW> P
TW OK
TYPE WRITE TO PROGRAM B3> WRITE
TW PRG
TW OK
```

The writer was assembled and launched while Bank 2's ASM-F2 `2113` image was
visible rather than from the recommended Bank-3 starting point. Its
self-contained RAM worker explicitly targeted Bank 3, stage verification
passed, programming/read-back verification returned `TW OK`, and the following
physical reset cold-booted Bank 3 into HIMON `2121`.

The six-byte echo follow-up is therefore installed and bootable. The capture
ends at HIMON before resident `J0`/`J1`/`J2` echo is exercised. Final
acceptance still requires:

```text
resident prompt visibly shows J0, J1, and J2
each prints matching J Bn and reset-recovers to Bank 3
F000-F00F = 4C 10 F0 4C 1F F3 4C 26 F3 4C 2E F3 53 52 01 07
F8DA-F8DD = 7A 0F 6A 5F
worker head and vectors remain unchanged
corrected inventory records a new Bank-3 CRC
Banks 0-2 remain $4B59/$2A3D/$04EF before and after the three handoffs
```

## 2026-07-28 STR8 J Echo Resident And CRC Acceptance

The 1,115-line final transcript is 28,577 bytes and has SHA-256
`F322AE26E29A262E31B5A9EF1F7C19EAF7476A5C82708B8634511400913C71FE`.

The opening `$1A00-$1A4F` dump is all zero because it immediately follows a
cold boot with `RAM ZERO OK`; it is not an inventory result. Direct dumps then
confirmed the installed echo-build image:

```text
F000: 4C 10 F0 4C 1F F3 4C 26 F3 4C 2E F3 53 52 01 07
F8DA: 7A 0F 6A 5F
FD16: 08 78 AD F0 1F C9 05 F0 11 C9 06 F0 12 C9 07 F0
FFFA: 9A F0 00 F0 AE F0
```

An `L G` attempt followed by repeated `LERR=$01` contained no valid S19 input.
It performed no flash operation, and physical reset returned to the installed
Bank-3 HIMON `2121`.

From Bank 3, the corrected inventory fixture assembled at `$3000`, returned
`A=$AC/C=1`, and reported PCR `$EE` with decoded Bank 3:

```text
1A00: AC 00 00 00 00 EE 03 00 | 00 00 00 00 00 00 00 00
1A10: 59 4B 98 F0 00 F0 AC F0 | 4C 10 F0 4C 53 52 01 07
1A20: 3D 2A 98 F0 00 F0 AC F0 | 4C 10 F0 4C 53 52 01 07
1A30: EF 04 98 F0 00 F0 AC F0 | 4C 10 F0 4C 53 52 01 07
1A40: 63 46 9A F0 00 F0 AE F0 | 4C 10 F0 4C 53 52 01 07
```

The authoritative installed echo-build CRCs are:

```text
Bank 0 $4B59   Bank 1 $2A3D   Bank 2 $04EF   Bank 3 $4663
```

Resident STR8 then visibly accepted and executed every V1 handoff:

```text
STR8-N>J0
J B0
... HIMON V 00.0728(2042)

STR8-N>J1
J B1
... HIMON V 00.0728(2113)

STR8-N>J2
J B2
... HIMON V 00.0728(2113)
```

The transcript returns to the Bank-3 STR8 surface between targets, recording
physical-reset recovery. Thus the parser echo, resident RAM-worker mode `$08`,
target selection, and current target identities pass for all three banks.

After `J2`, the operator first assembled the fixture while Bank 2 was visible,
despite its `RUN ONLY FROM BANK 3` requirement. `G 3000` cold-booted Bank 3
instead of returning `A=$AC`; that run is invalid and is not used as inventory
evidence. From the recovered Bank-3 HIMON `2121`, the fixture was reassembled
and run again. It returned `A=$AC/C=1`, PCR `$EE`, decoded Bank 3, and exactly
the same `$4B59/$2A3D/$04EF/$4663` CRCs shown above. Final direct dumps again
matched the installed header, marker, worker head, and vectors.

The echo-build resident `J0`-`J2` implementation is fully hardware-accepted on
the recorded board images. V1 still performs vector plausibility only.
Identity and CRC authentication require future Bank-3-owned metadata.

## 2026-07-30 STR8 Boot Selector Protected Install And Partial Smoke

The 2,815-line, 115,732-byte transcript has SHA-256
`14C5354474081424AC4689F264103992754B409B4356BDFAEAC7AE29316018F5`.
It begins on the earlier unstamped STR8-N image, cold-times out through
`BOOT COLD` and `RAM ZERO OK` into HIMON `00.0728(2121)`, and assembles the
self-contained guarded TopWriter with ASM-F2 `00.0728(2113)`.

The first protected-sector install embedded STR8-N `00.0730(2331)`. Assembly
reached `$5000`, and the complete guarded exchange passed:

```text
TW> S
TW STG
TW OK
TW> V
TW OK
TW> P
TW OK
TYPE WRITE TO PROGRAM B3> WRITE
TW PRG
TW OK
TW> Q
RET A=AC X=10 Y=00 P=77 S=FD NV-BdIZC
```

The staged `$F000-$FFFF` sector is fully present in the transcript. Its
SHA-256 is
`6F5504BFCB63452F439895F0DBDDFF422E1330BE70C04A1491DB6686D5ACDB4F`.
After programming, reset printed:

```text
STR8-N V 00.0730(2331) #5F6A0F7A B3
B3 0/1/2=BOOT 3=HIMON S=STR8  3 2 1
BOOT COLD
RAM ZERO OK
HIMON V 00.0728(2121)
```

This proves the stamped reset face and cold-timeout path. Later partial
countdowns enter the STR8 screen and `G HIMON` reports `BOOT WARM`; because
selector input is not echoed, the capture proves takeover but does not
separately identify uppercase versus lowercase `S`.

The session also passes an aborted `U`, a verified `B3->B0` backup, an accepted
HIMON `U`, and the established confirmed `B2->B3` restore. That restore
temporarily returns the board to an earlier unstamped STR8 image. HIMON is then
updated to `00.0730(2338)`, and a second self-contained TopWriter is assembled.
Its full `S`/`V`/confirmed-`P` exchange also returns `A=$AC`.

The final installed `$F000-$FFFF` sector reports:

```text
STR8-N V 00.0730(2338) #5F6A0F7A B3
```

Its SHA-256 is
`39D1797DBB301C771FE91A68AB5634AF9E45398AAB89135C1254A05FB705A615`,
and all 4,096 bytes match the current host BIN's top sector. That host
`himon-str8-rom.bin` has SHA-256
`A8ED60EF826D0931B09CF8EA52AB8A1B5299B0488C324044DBE0B626712FBF46`;
the transcript does not install that full combined BIN as one operation. The
final visible Bank-3 component identities are STR8-N `00.0730(2338)`, HIMON
`00.0730(2338)`, and ASM-F2 `00.0728(2113)`. The ASM stamp remains older
because this was a top-sector install plus HIMON-only `U`, not a full combined
image install.

The capture ends after a verified `B3->B2` backup:

```text
BACKUP B3 TO B0/1/2:  2 ERASE? Y: y
COPY B3->B2
OK
```

That operation intentionally changes Bank 2. No final inventory or CRC table
is present, so this transcript cannot close the non-destructive selector
matrix. Timed four-second attach behavior, queued-input flushing, selector `3`
RAM retention, reset-time `0`/`1`/`2`, invalid-input continuation, and the
post-test four-bank inventory remain pending.

## 2026-07-30 STR8 Boot Selector Warm-3 And Flush Follow-Up

The 1,039-line, 42,742-byte continuation transcript has SHA-256
`AAECA204DA54B3C8E85580F7F2DAFD574FDD846F568B6BEB8C020D0F95B2C174`.
It begins by completing the previously recorded verified `B3->B2` backup.
Interactive `J2` then enters the copied current image immediately, without
`BOOT IN 3S`:

```text
STR8-N>J2
J B2

STR8-N V 00.0730(2338) #5F6A0F7A B3
B3 0/1/2=BOOT 3=HIMON S=STR8  3 2 1
BOOT COLD
RAM ZERO OK
HIMON V 00.0730(2338)
```

Interactive `J1` likewise enters Bank 1 immediately. Its older unstamped
STR8-N and HIMON `00.0728(2113)` identities distinguish it from the current
Bank 2 and Bank 3 images. These observations pass the immediate interactive
`J1` and `J2` regression cases; `J0` is not present in this continuation.

The operator then assembled TopWriter at `$3000`, launched it successfully,
quit, reset, and selected `3`. The capture reports warm entry and launches the
same RAM-resident program again:

```text
STR8-N V 00.0730(2338) #5F6A0F7A B3
B3 0/1/2=BOOT 3=HIMON S=STR8  3
BOOT WARM

HIMON V 00.0730(2338)
>G 3000
GO 3000
TOPWRITER
S STAGE+VERIFY
V VERIFY STAGE
P PROGRAM BANK 3
I STATUS
Q QUIT
TW> Q
```

The intact executable TopWriter body is the RAM sentinel. Its successful
post-reset execution closes selector `3` warm-entry and RAM-retention proof.
Only `Q` is used in this TopWriter session; it performs no stage or program
operation.

The operator separately reports that input queued during the silent attach
period was discarded before the selector opened. A discarded byte produces no
terminal token, so this is recorded as operator-observed hardware proof of the
bounded pre-selector RX flush.

The delay values are intentionally not accepted as final timing in this pass.
The current build still uses approximately 4.003 seconds before the banner and
3.010 seconds before a selected Bank 0-2 handoff at 8 MHz, but those values may
be tuned. Any timing change requires the attach/flush and selected-bank delay
observations to be repeated.

Reset-time `0`/`1`/`2`, invalid-input continuation, separately observed
uppercase/lowercase `S`, interactive `J0`, and a fresh post-test four-bank
inventory remain open.

## 2026-07-30 STR8 Boot Selector Bank 1 And Bank 2 Follow-Up

The operator-supplied continuation passes the reset-time Bank 1 path:

```text
STR8-N V 00.0730(2338) #5F6A0F7A B3
B3 0/1/2=BOOT 3=HIMON S=STR8  3 2
J B1
BOOT IN 3S

STR8-N
HIMON IN 3S. S=STR8-N  3 2 1
BOOT COLD
RAM ZERO OK
HIMON V 00.0728(2113)
```

`J B1` and `BOOT IN 3S` prove that the reset selector used the delayed bank
handoff rather than the immediate prompt command. The older unstamped STR8-N
and HIMON `00.0728(2113)` identities visibly authenticate the Bank 1 guest.
The later stamped Bank 3 face shows recovery to the current image.

The subsequent `G 3000` reaches `BRK 00 PC=3002`. This is expected after the
Bank 1 guest explicitly reports `BOOT COLD` and `RAM ZERO OK`; it is not a
failure of the separately accepted selector `3` warm-retention path.

The continuation also passes the reset-time Bank 2 route:

```text
STR8-N V 00.0730(2338) #5F6A0F7A B3
B3 0/1/2=BOOT 3=HIMON S=STR8  3
J B2
BOOT IN 3S

STR8-N V 00.0730(2338) #5F6A0F7A B3
B3 0/1/2=BOOT 3=HIMON S=STR8  3 2 1
BOOT COLD
RAM ZERO OK
HIMON V 00.0730(2338)
```

Bank 2 contains the verified Bank-3 copy made earlier in the session, so the
matching stamped STR8-N and HIMON `00.0730(2338)` identities are the expected
guest result. That copied STR8 reset path explicitly reselects Bank 3 before
continuing, as designed.

These observations close the functional reset-time `1` and `2` cases,
including the additional-delay route. They do not measure or freeze the
duration. Reset-time `0`, delay tuning, invalid-input continuation, separately
observed uppercase/lowercase `S`, interactive `J0`, and the final inventory
remain open.

## 2026-07-30 STR8 Boot Selector Bank 0 Operator Acceptance

The operator explicitly accepts the reset-time Bank 0 selector case. No new
terminal transcript accompanies this acceptance, so it is recorded as
operator-declared rather than capture-backed evidence.

Together with the captured Bank 1 and Bank 2 results, this closes the
functional reset-time `0`/`1`/`2` selector set and its additional-delay route.
It does not freeze the delay duration or replace the remaining invalid-input,
separate `S`/`s`, interactive `J0`, and final-inventory gates.

## 2026-07-30 STR8 Boot Selector Final Operator Acceptance

The operator explicitly accepts all remaining boot-selector gates for the
installed `00.0730(2338)` candidate:

- the current approximately 4.003-second attach delay;
- the current approximately 3.010-second selected-bank delay;
- invalid-input continuation;
- uppercase and lowercase `S`;
- the interactive `J0` regression;
- the final non-destructive bank inventory.

No additional terminal capture, elapsed-time measurement, or CRC table
accompanies this closure. These items are therefore operator-declared
acceptance, distinct from the capture-backed protected install, stamped face,
cold timeout, STR8 takeover, warm-`3` RAM retention, RX flush, Bank 1/2 delayed
handoffs, and interactive `J1`/`J2` evidence recorded above.

Result: the boot-selector candidate is accepted with no remaining gates.
Future delay tuning creates a changed candidate and reopens only the affected
timing and selector observations.

## 2026-07-31 TopWriter Menu Operator Clarification

The operator confirms the complete TopWriter menu surface was exercised:
`S`, `V`, `I`, invalid input, canceled `P`, confirmed `P`, and `Q`. Existing
capture-backed entries above already show two successful `S`/`V`/confirmed-`P`
sequences and `Q`. The `I`, invalid-input, and canceled-`P` cases are recorded
as operator-declared acceptance because no separate excerpt is retained.

The earlier visibility ambiguity belongs to the STR8 reset-time selector, not
TopWriter. TopWriter calls the ASM-F2 echoed uppercase line reader, while the
accepted STR8 selector consumed its single-byte input without echo. Current
source work after this accepted image changes STR8 interactive input to echo
all human-entered control bytes; that changed candidate requires its own
compact visibility regression.

## 2026-07-31 TopWriter Status Capture

The operator supplied a distinct 1,051-line, 43,037-byte transcript with
SHA-256
`70A9A1EA05C217CEC9DFB25C5F33D18683AFD00CA1F5EFAB37DD3CBE010E9F14`.
It records assembly of the self-contained TopWriter through `ASM OK` and ends
with the status operation:

```text
TOPWRITER
S STAGE+VERIFY
V VERIFY STAGE
P PROGRAM BANK 3
I STATUS
Q QUIT
TW> I
TW MODE=$00 RES=$00 @=$0000
TW>
```

This upgrades `I` from operator-declared to capture-backed acceptance. Invalid
menu input and canceled `P` remain operator-declared. The transcript embeds
the accepted STR8-N `00.0730(2338)` top sector with face check `$F922`; it
predates the current complete-interactive-echo source candidate and does not
close that candidate's visibility regression.

The same capture also reinforces the input-path distinction: reset-time STR8
choices lead to the selected action without printing the typed choice, while
TopWriter visibly echoes `I`. This is historical evidence for the accepted
pre-echo selector image, not proof of the later echo change.

## 2026-07-31 TopWriter Canceled Program Capture

The operator supplied the continuation that closes the canceled-`P` menu
gate:

```text
>G 3000
GO 3000
TOPWRITER
S STAGE+VERIFY
V VERIFY STAGE
P PROGRAM BANK 3
I STATUS
Q QUIT
TW> S
TW STG
TW OK
TW> V
TW OK
TW> P
TW OK
TYPE WRITE TO PROGRAM B3>
TW CANCEL
TW>
```

`S` copied and verified the staged sector, `V` independently verified it, and
`P` completed its required preflight verification. The empty confirmation did
not equal `WRITE`, so control took the cancellation path. No `TW PRG` appears;
the erase/program worker was not called.

The preceding automatic `#GO# ENTRY=3000` returned `A=$E0`. It is not used as
acceptance evidence because the explicit manual run immediately afterward
restaged the image and passed both verification paths. Canceled `P` is now
capture-backed. Invalid TopWriter menu input remains operator-declared.

## 2026-07-31 HIMON HCOLD And HWARM Hardware Acceptance

The operator supplied a 1,192-line, 46,912-byte session transcript with
SHA-256
`EE31D239412D7E015FB5D521F857F12434B68814A185A966C99FEED677D8197E`.
The session first used the self-contained TopWriter to install the
`STR8-N V 00.0731(1317)` top sector, then used STR8 `U` to install successive
HIMON candidates. The final `HIMON V 00.0731(1400)` image exposes the renamed
HIMON startup entries:

```text
>#
HASH     ENTRY K TEXT
56AD7400 800C 05 ASM V1
D5735621 C030 03 HCOLD
81DE061A C044 03 HWARM
...
B0051A80 C000 03 HIMON: V 00.0731(1400)
A2AD0E18 F000 03 STR8: BOOTLOADER
```

The hashes, entry addresses, confirm kind, and display text all match the
host-built catalog. The old `BOOT_COLD_RESET` and `BOOT_WARM_RESET` records
are absent from the final listing.

Both exact commands pass the confirmed execution path on hardware:

```text
>HWARM
RUN HWARM @C044 K=03 ? y
BOOT WARM

HIMON V 00.0731(1400)
>HCOLD
RUN HCOLD @C030 K=03 ? y
BOOT COLD
RAM ZERO OK

HIMON V 00.0731(1400)
>
```

`HWARM` returns to HIMON without the cold RAM-clear report. `HCOLD` reports
`RAM ZERO OK` and returns to HIMON, proving the intended destructive cold
startup behavior. The short HIMON-owned command names are hardware-accepted;
STR8-N remains the owner of reset and boot selection.

## 2026-07-31 STR8 Interactive Echo And Cancel Hardware Proof

The operator supplied a 1,409-line, 54,729-byte session transcript with
SHA-256
`302444B4A7299EBF0AF926BC9BEB6D647D950688ACAC6BBDAB5DE5D5E1E14687`.
The self-contained TopWriter installed `STR8-N V 00.0731(1438)`. Its identity
line has no copied bank suffix:

```text
STR8-N V 00.0731(1438) #5F6A0F7A
```

The reset selector displayed the lowercase `s` test as uppercase `S`. At the
resident prompt, command, operand, and confirmation bytes were likewise
displayed uppercase and exactly once. The ordered cancel matrix exercised
Backspace at the first blank backup-destination prompt and empty Enter at a
blank confirmation prompt; both reached `ABORT`. Invalid lowercase `z` was
displayed as `Z` and aborted. Representative output:

```text
STR8-N>B
BACKUP B3 TO B0/1/2:
ABORT
STR8-N>B
BACKUP B3 TO B0/1/2:  1 ERASE? Y:
ABORT
STR8-N>B
BACKUP B3 TO B0/1/2:  2 ERASE? Y: Z
ABORT
STR8-N>J0
J B0
```

Confirmed `B0` completed `COPY B3->B0` / `OK`. Blank and invalid `U`
confirmations aborted without entering the S19 stream, while a valid `Y`
entered it and a blank program confirmation aborted. Bare restore prompts
also accepted blank or invalid responses as aborts. `J0` then entered the
guest and its reset path returned to Bank 3 HIMON. This closes the requested
uppercase-echo, Backspace, and Enter-as-negative behavior for the installed
candidate. Delete shares the Backspace source branch but is not separately
identified by this plain terminal capture.

## 2026-07-31 Bank Check ASM-F2 String-Literal Negative

The same session attempted `bank_check.a` twice. All code and the four-byte
mode table assembled through `$30D8`, but ASM-F2 rejected each quoted string
operand with `ERR=$03 BO`; `END` then correctly reported the unresolved
result as `ERR=$09 BAD FIX`:

```text
ASM>$30D8: MHEAD   DB $0D,$0A,"BANK CHECK PCR=$",$00
ERR=$03 BO PC=$30D8
...
ASM>$30D8:         END
ERR=$09 BAD FIX PC=$30D8
```

Changing one operand to a multi-character single-quoted string produced the
same result, confirming that ASM-F2 requires individual character-byte
operands. The repository sample now spells all messages as lists such as
`DB 'B','A','N','K'`. This transcript is a source-compatibility negative, not
runtime proof of the corrected bank checker.

## 2026-07-31 Bank Check Corrected Hardware Acceptance

The operator supplied the 1,803-line, 66,898-byte follow-up transcript with
SHA-256
`936A55A90A6F5FA12E0E9BB8D332FD0A3A2E9641D1B5E3B8CCC0CCA748B02E4E`.
The corrected individual-character form assembled without any error through
the expected end address:

```text
ASM>$3130:         DB 'P','L','I','C','I','T',$00
ASM>$3137:
ASM>$3137:         END
ASM OK
```

Running the checker returned the explicit Bank-3 PCR mode, both select lines
high, status `$AC`, and carry set:

```text
>G 3000
GO 3000

BANK CHECK PCR=$EE SELECT=$EE FA15=1 FAMS=1 BANK=3 EXPLICIT

#GO# ENTRY=3000
RET A=AC X=0A Y=09 P=77 S=FD NV-BdIZC
```

The session then entered reset-time Bank 0 through STR8, observed `J B0` and
`BOOT IN 3S`, cold-reset back through Bank 3 HIMON, reassembled the corrected
source, and obtained the same output and return state a second time. This
closes corrected ASM-F2 source compatibility and the read-only explicit
Bank-3 decode path. The program still reports programmed PCR mode rather than
independently measuring CA2/FA15 or CB2/FAMS pin voltage; the other three
explicit table modes were not separately forced in this capture.

## 2026-07-31 Bank Check Retirement And Bank Jump Record Supersession

The two Bank Check entries above remain as an exact historical transcript, but
their diagnostic is retired. The second execution did occur after STR8 selected
Bank 0. The guest then reset/returned through STR8 and HIMON, which explicitly
selected Bank 3 before `bank_check.a` read PCR. Its repeated Bank 3 result was
therefore the current selection, not evidence against the preceding Bank 0
handoff.

The repository sample and its ordinary documentation have been removed. The
replacement host candidate records a successful validated `J0`-`J2` target
immediately before the final jump and publishes it at `$1FFD-$1FFF` as
`42 4A bank`. HIMON preserves a valid signed record through cold RAM clearing;
`42 4A FF` means no valid target is known. This entry documents supersession
only. The new Bank Jump Record still requires the separate hardware proof; no
claim in the historical transcript is being rewritten as that proof.

## 2026-07-31 Dense 32K S19 Flash-Pause FTDI/Tera Term Acceptance

The operator supplied a 674-line, 20,701-byte Windows Tera Term transcript with
SHA-256
`434B348164CC72F7826BBC1F751791B040B1958F5D5F67FF43FC5F3EA10A9F05`.
The board reported STR8-N `00.0731(1517)`, HIMON `00.0731(1515)`, and ASM-F2
`00.0728(2113)`. ASM-F2 accepted the complete fixed-load proof through `END`:

```text
ASM>$232D: CRLF    LDA #$0D
ASM>$232F:         JSR BIO_FTDI_WRITE_BYTE_BLOCK
ASM>$2332:         LDA #$0A
ASM>$2334:         JMP BIO_FTDI_WRITE_BYTE_BLOCK
ASM>$2337:
ASM>$2337:         END
ASM OK
```

The operator used Windows Tera Term Send File with both bulk and sequential
reads. Their order is immaterial for this test and is not assigned to
individual runs in the transcript. All three captured executions received the
dense 32K all-zero S19, paused target reads for real Bank-0 sector
erase/program/full-sector verification, validated S9 `$0000`, programmed the
held final sector, printed eight dots, and returned `A=$AC` with carry set:

```text
SEND BANK0-ZERO-8000-FFFF.S19 NOW
........ 8 SECTORS ERASED/PROGRAMMED/VERIFIED

#GO# ENTRY=2000
RET A=AC X=71 Y=25 P=F5 S=FD NV-BdIzC
```

Repeating the all-zero image still exercised erase and program: Bank 0 held
programmed `$00`, not erased `$FF`, before each repeat. No checksum, ordering,
coverage, S9, flash, verification, or transport failure occurred. This closes
the dense 32K transport-with-real-flash-pauses gate for the tested Windows
Tera Term and FTDI FIFO profile. At this proof step the dense 28K FTDI form
remained open; the following entry closes it.

**ACIA warning:** this proof does not qualify an ACIA receive path. The FTDI
and Windows queues retained the stream while target reads stopped. A typical
ACIA has shallow receive storage and may overrun during erase/program/verify;
an interrupt-fed RAM ring cannot drain while the RAM flash worker masks
interrupts. ACIA support remains explicitly unproven and unsupported until a
documented pacing or flow-control profile passes separate dense 32K and 28K
hardware proofs.

## 2026-07-31 Dense 28K S19 Flash-Pause FTDI/Tera Term Acceptance And T48 Backup

The operator supplied a 1,033-line, 32,062-byte Windows Tera Term transcript
with SHA-256
`058AEA26AE5B41785D4871AFB2111C15AC0517145AB170B108A6B736F1532233`.
The board reported STR8-N `00.0731(1517)`, HIMON `00.0731(1515)`, and ASM-F2
`00.0728(2113)`. ASM-F2 accepted the separate 28K source through `$2351`:

```text
ASM>$2347: CRLF    LDA #$0D
ASM>$2349:         JSR BIO_FTDI_WRITE_BYTE_BLOCK
ASM>$234C:         LDA #$0A
ASM>$234E:         JMP BIO_FTDI_WRITE_BYTE_BLOCK
ASM>$2351:
ASM>$2351:         END
ASM OK
```

The proof required exact confirmation `WRITE B0 28K`, accepted 896 contiguous
32-byte S1 records covering `$8000-$EFFF`, required every data byte to equal
`$5A`, and validated S9 `$8000`. Bank 0 was the disposable real-flash timing
sink so the RAM proof did not erase the Bank-3 HIMON console routines it still
used. Sectors `$8000-$DFFF` were erased, programmed, and verified while the
host continued sending. Sector `$E000-$EFFF` was held until S9 validation and
then committed. The board printed seven completion dots and returned `$AC`
with carry set:

```text
source SHA-256 B9208703E49A11B7A2E4987D6099DC788D4054B135F4D0F981B137BC1A0406B9
S19   SHA-256 73B75CB7EDAB18B334E7F956C706B25A1CC240D2151FE86ECE720657154D457B
S19 bytes/records/data = 68182/898/$7000
```

```text
SEND STR8-28K-5A-8000-EFFF.S19 NOW
....... 7 SECTORS ERASED/PROGRAMMED/VERIFIED

#GO# ENTRY=2000
RET A=AC X=84 Y=25 P=F5 S=FD NV-BdIzC
```

This closes the dense 28K transport-with-real-flash-pauses gate for the same
Windows Tera Term and FTDI FIFO path as the accepted 32K proof. It does not
qualify an ACIA path.

The operator also supplied the post-test T48 full-chip readback
`BUILD/RYORS-0731-S19-TRANSPORT-TESTS-IMAGE BACKUP.BIN`. It is exactly 131,072
bytes and has SHA-256
`746AF1572F5E2AD4D121C683BDA65DCBCC76B7EFAFED5E58998A9E5D95A52772`.
Its physical Bank-0 range `$00000-$06FFF` contains 28,672 consecutive `$5A`
bytes and `$07000-$07FFF` contains 4,096 consecutive `$00` bytes, with no
mismatches. This independently corroborates the expected post-test state:
CPU `$8000-$EFFF` was replaced by the 28K proof and CPU `$F000-$FFFF` retained
the earlier all-zero 32K-test content.

The same readback is retained as the exact Bank-2 and Bank-3 recovery source.
The extracted 32K images are distinct and must not be interchanged:

```text
Bank 2  chip $10000-$17FFF  CPU $8000-$FFFF
        STR8-N/HIMON 00.0731(1438)/00.0731(1438)
        SHA-256 E261EEC99B9387507BAEA85F0A1E80F68DC98A4C016CC83D0AEDAD9E46690685
        BUILD/RYORS-0731-S19-TRANSPORT-TESTS-BANK2-1438-BACKUP.BIN

Bank 3  chip $18000-$1FFFF  CPU $8000-$FFFF
        STR8-N/HIMON 00.0731(1517)/00.0731(1515)
        SHA-256 B5BAA7C6287C9B5DF584F23F31D0E4E2D3453E7EB449B45CC5E45CEEE6DEB75E
        BUILD/RYORS-0731-S19-TRANSPORT-TESTS-BANK3-1517-BACKUP.BIN
```

Each extracted file is exactly 32,768 bytes and exactly matches its source
slice in the T48 readback. The filenames record intended placement; a raw 32K
`.BIN` does not encode its bank number. Restoring with the programmer must
place Bank 2 at chip offset `$10000` and Bank 3 at `$18000`. The original 128K
file remains the byte-exact full-chip recovery capture.

## 2026-08-01 STR8 V0 Copy/Restore Reclaim Hardware Acceptance

The operator supplied a 1,470-line, 59,074-byte board transcript with SHA-256
`AE84BF47DF25FF8DCE3538B8FD4B93DB10BF520A3C577617FACC48CC64D36A5E`.
ASM-F2 assembled the self-contained current TopWriter through `ASM OK`. The
writer staged and verified the image, required the exact destructive `WRITE`
confirmation, programmed Bank 3, and reported success:

```text
TW> S
TW STG
TW OK
TW> V
TW OK
TW> P
TW OK
TYPE WRITE TO PROGRAM B3> WRITE
TW PRG
TW OK
TW> I
TW MODE=$01 RES=$AC @=$0000
```

The TopWriter status mode `$01` belongs to TopWriter's own transaction report;
it is not a dispatch through the reclaimed STR8 worker. Cold boot identified
the installed candidate as `STR8-N V 00.0801(2234) #5F6A0F7A`. Its prompt
advertised only the intended transitional commands, and every retired resident
copy/restore command failed as an unknown command:

```text
? U J0 J1 J2 G R
STR8-N>B
?
STR8-N>0
?
STR8-N>1
?
STR8-N>2
?
```

A separate ASM-F2 RAM fixture called the installed worker for every byte value
except the four legal modes `$05-$08`. All 252 unrecognized modes returned
without entering an operation. The fixture's success byte was `$AC`, carry was
set, and its four-byte failure record remained clear:

```text
RET A=AC X=00 Y=5D P=F5 S=FD NV-BdIzC
1A00: 00 00 00 00
```

The post-test read-only inventory returned `$AC` and decoded explicit Bank 3.
It recorded CRCs B0 `$5B4A`, B1 `$19F9`, B2 `$19F9`, and B3 `$068B`.
Banks 1-3 had reset/NMI/IRQ vectors `$F0C0/$F000/$F0D4` and the expected
`$F000` head/signature. Bank 0 had zero head and vectors, so it was correctly
treated as nonlaunchable and `J0` was not attempted. The fixture's first
comment line caused ASM-F2 to retain `ERR=$03 BO`, including a later
`#56AD7400# EXEC ERR=$03` notice; the source nevertheless finished with
`ASM OK`, ran manually, and returned `$AC`. The retained error notice is a
session/parser artifact and is not used as acceptance evidence.

Reset-time Bank 2 displayed `J B2` and `BOOT IN 3S`, but the next visible
identity was Bank-3 `00.0801(2234)`, followed by its normal selector. Resident
`J2` and `J1` produced the same pattern: `J B2` or `J B1`, immediately followed
by the Bank-3 identity. This is not physical-reset recovery and is not proof
that either selected bank remained running. The inventory shows that Banks 1
and 2 have reset vector `$F000` and a STR8 service signature. Their selected
STR8 startup reaches `STR8_INIT`, which writes PCR `$EE` and remaps Bank 3
before printing its banner. The trace is therefore consistent with entering
the selected bank's reset path and then immediately switching itself back to
Bank 3. `G` separately retained its warm HIMON path.

This accepts the V0 copy/restore reclaim and the fail-closed unknown-mode
behavior on hardware. It does not claim a before/after inventory pair, a Bank-0
handoff, a sustained Bank-1 or Bank-2 boot, separate board execution of every
surviving mode `$05-$08`, or any future V1 directory/installer/migration
behavior. Those broader gates remain open.

## 2026-08-01 STR8 Selected-Bank Startup Regression Diagnosis

The earlier 2026-07-28 handoff evidence remains valid: `J0`, `J1`, and `J2`
entered the selected banks and exposed their distinct target identities. The
later unconditional PCR `$EE` write was added after that proof so software
could decode Bank 3 deterministically. Immediately after hardware reset the
VIA PCR may still describe an input/reset state even though the board pull-ups
physically select Bank 3; writing `$EE` converted that state to the canonical
Bank-3 output pattern used by the decoder.

That normalization was not required for physical Bank-3 selection and was
incorrect in generic STR8 startup. A complete Bank-3 image copied into Bank 0,
1, or 2 enters its own reset path after `J0`, `J1`, or `J2`, executes the same
write, and immediately remaps Bank 3. The `00.0801(2234)` transcript made this
regression visible: the selected bank began at `$F000`, then STR8 initialization
selected Bank 3 before printing the identity.

Current source removes the unconditional PCR write from `STR8_INIT` and makes
the reset selector text bank-neutral. Hardware reset continues to depend on
the board pull-ups to select Bank 3, while entry through `J0`-`J2` now leaves
the selected bank unchanged. Explicit recovery/error paths may still select
Bank 3 deliberately. This is a source-level diagnosis and repair; corrected
Bank-3 installation and sustained Bank-0/1/2 board handoff proof remain open.
Previously installed or copied STR8 images that contain the retired `$EE`
write retain the regression until they are replaced.

## 2026-08-02 Stale TopWriter and Bank-Copy Assembly Diagnosis

The operator supplied a 1,417-line, 56,784-byte transcript with SHA-256
`F231987A1C5EDB5C42E1EA9F0C48CF0D3EC310D595ECDD41B65213858D2F8A49`.
The session began on installed STR8 `00.0801(2234)`. The pasted TopWriter
assembled and its stage, verify, confirmed program, and status paths all
returned success:

```text
ASM OK
TW> S
TW OK
TW> V
TW OK
TW> P
TW OK
TYPE WRITE TO PROGRAM B3> WRITE
TW PRG
TW OK
RET A=AC X=10 Y=00 P=77 S=FD NV-BdIZC
```

This did not install the selected-bank repair. The pasted TopWriter was the
stale pre-repair generated file: its embedded image still contained
`A9 EE 8D EC 7F 60` at RAM `$405B`, the old `LDA #$EE / STA $7FEC / RTS`
startup sequence. The successful write therefore reinstalled the forced
Bank-3 behavior.

The following `str8-bank-copy-2000.a` paste did not assemble and did not run.
ASM-F2 rejected each unresolved `BC_INPUT+n` operand with `ERR=$03 BO`, then
reported:

```text
ASM>$23D9:         END
ERR=$09 BAD FIX PC=$23D9
#56AD7400# EXEC ERR=$09
```

There was no `ASM OK`, `SEAL`, `G 2000`, confirmation, or bank-copy result for
that source. No bank-copy flash mutation is claimed. Current source replaces
the unsupported addend operands with absolute `$1C01-$1C07` addresses. The
TopWriter has been regenerated from corrected STR8 and is now a normal
`firmware`/`all` and `release` dependency, so a combined-ROM rebuild also
refreshes its embedded top-sector image. Corrected installation, fresh ASM-F2
assembly, full-bank copy, and sustained selected-bank execution remain open.

## 2026-08-02 Corrected TopWriter Install and Direct-Import Failure

The operator supplied a 1,443-line, 57,179-byte transcript with SHA-256
`88AB1C39458109F993A05ED52026CEFF726B053DED64CC9CC9B74A9F28C4990C`.
It first reconfirmed the installed `00.0801(2234)` regression: `J2` displayed
`J B2`, then the old Bank-3 identity and `B3`-prefixed selector.

The regenerated TopWriter had the corrected `$F895` face and `$F8D6` prompt
addresses. Its embedded initialization at RAM `$405B` was
`4C D9 F7`, a tail jump to console initialization, rather than the retired
`A9 EE 8D EC 7F 60` Bank-3 write. ASM-F2 reported `ASM OK`; stage, verify, and
confirmed program all returned `TW OK`; and the program returned `$AC` with
carry set. Reset then showed:

```text
STR8-N V 00.0802(1323) #5F6A0F7A

0/1/2=BOOT 3=HIMON S=STR8
```

This accepts installation and cold boot of the repaired Bank-3 top sector,
including the bank-neutral selector. A following `J2` again displayed the
same repaired identity, but Bank 2 had not yet been replaced. Its older STR8
could still select the newly repaired Bank 3 before that banner, so this is not
sustained Bank-2 proof.

The corrected-addend `str8-bank-copy-2000.a` paste reached `ASM OK` and `SEAL`
without the prior `BO`/`BAD FIX` errors. `G 2000` then stopped immediately:

```text
>G 2000
GO 2000

BRK 00 PC=0003
A=01 X=03 Y=20 P=75 S=F9 NV-BdIzC
```

`X=$03/Y=$20` is the exact `$2003` `BC_TITLE` pointer loaded by `BC_MAIN`.
Execution therefore reached the `BC_PUTS` import stub, whose package import was
not linked for a direct `G`; it transferred to `$0000` and hit BRK. The title,
source prompt, destination prompt, and confirmation never printed. No worker
mode or flash operation ran, and no bank copy is claimed.

Current utility source is now truly direct-run: it has no `IMPORT` or `ENTRY`
directives and calls HIMON's initialized published service vectors through
`$7E08` (write byte), `$7E0A` (write C string), and `$7E10` (read uppercase
C string). Host WDC assembly and source-shape checks pass. Full board execution,
the eight-sector Bank-3-to-disposable-bank copy, and selected-bank PCR proof
remain open.

## 2026-08-02 Full-Bank Copy and Sustained Bank-2 Selection Acceptance

The operator supplied a 954-line, 31,798-byte transcript with SHA-256
`253D097450231DF9367F14D6394DCA54F7CCAF01E2459F89873B8D34414CE6E3`.
It was captured after installation of the selected-bank startup repair and
before the later removal of the visible STR8 identity hash. Its
`STR8-N V 00.0802(1323) #5F6A0F7A` banners are therefore expected historical
output; they are not evidence for or against the later host-only banner change.

The corrected direct-run `str8-bank-copy-2000.a` used HIMON's published service
vectors, assembled through `ASM OK` and `SEAL`, and completed a full Bank-3 to
Bank-2 copy:

```text
STR8 BANK COPY $8000-$FFFF
SOURCE BANK 0-3> 3
DEST BANK 0-2> 2
WARNING: SOURCE HAS STR8; IT MAY SELECT B3
COPY B3->B2 $8000-$FFFF
TYPE COPY 32> COPY 32
COPYING ........ OK
RET A=AC X=F7 Y=05 P=F5 S=FD NV-BdIzC
```

The eight dots account for all eight 4K sectors. `OK`, `A=$AC`, carry set, and
worker mode `$05` accept the complete program/read-back-verify path. The same
utility subsequently completed and verified Bank 3 to Bank 1 with confirmation
`COPY 31`, eight dots, `OK`, and the same `$AC`/carry result.

Bank 2 was copied before Bank-3 HIMON was updated, so it retained HIMON
`00.0731(1515)`. The operator then used resident `U` to update Bank 3 to HIMON
`00.0802(1334)` before copying that newer image to Bank 1. This deliberately
created a bank-distinguishing payload: Bank 2 contained `0731`, while Banks 1
and 3 contained `1334`.

The reset selector's Bank-0 attempt failed closed on its zero reset vector and
returned to STR8:

```text
J B0
BOOT IN 3S
JERR B0 V=$0000
```

Resident `J1` reached HIMON `00.0802(1334)`, but that identity is shared by
Banks 1 and 3 and therefore is not independent proof that Bank 1 remained
selected. The reset selector's `2` path did produce independent proof:

```text
J B2
BOOT IN 3S
STR8-N V 00.0802(1323) #5F6A0F7A
0/1/2=BOOT 3=HIMON S=STR8  3 2 1
BOOT COLD
RAM ZERO OK
HIMON V 00.0731(1515)
```

Reaching Bank 2's older `0731` payload after Bank 3 had become `1334` proves
that copied STR8 preserved Bank 2 through startup and cold entry. It could not
have remapped Bank 3. From that Bank-2 environment, choosing selector `3`
entered local HIMON warm and again printed `00.0731(1515)`, further proving
that this local-payload path did not change banks.

This closes direct-run full-bank-copy execution for Bank 3 to Banks 2 and 1,
and closes sustained selected-bank startup behavior for the Bank-2 reset
selector. The transcript has no
PCR `$7FEC` dump, but the distinct HIMON identity is stronger independent bank
evidence. It does not independently distinguish sustained Bank-1 execution and
does not record a direct resident `J2` with the distinguishing payload or
physical-reset recovery after this exact copy/selector sequence. Those cases
remain open. The later visible-hash removal also remains board-pending.

## 2026-08-02 No-Hash Install, Four-Dot Execution, and Direct J Follow-Up

The operator supplied a 2,555-line, 101,540-byte transcript with SHA-256
`9684C5A571C7703097FC2CDF42E37AB05044DDEAE2CE974E7E4DC298195D4500`.
It contains two TopWriter generations. The first has face/prompt checks
`$F895/$F8CC` and installs no-hash STR8 `00.0802(1349)` without the new dot
loop. That historical install is not used as four-dot evidence. HIMON was then
updated to `00.0802(1404)`.

The second TopWriter has the current `$F8AC/$F8E3` face/prompt checks. Its
embedded `$F128` routine contains the leading CR/LF, four-count loop, `$23`
delay tick, and `'.'` output. ASM-F2 reached `ASM OK` and `SEAL`; stage, verify,
confirmed program, and return all passed:

```text
TW> S
TW STG
TW OK
TW> V
TW OK
TW> P
TW OK
TYPE WRITE TO PROGRAM B3> WRITE
TW PRG
TW OK
RET A=AC X=10 Y=00 P=77 S=FD NV-BdIZC
```

The following power-off reset entered Bank-3 STR8 `00.0802(1404)` and displayed
no `#5F6A0F7A` suffix. This accepts the visible-hash removal on hardware. The
captured first line is `>...`, however, not an independently captured line of
four dots. Later live STR8 entries repeatedly print the exact intended form:

```text
....
STR8-N V 00.0802(1404)
```

This accepts execution of the four-dot routine and its line formatting on
hardware. Exact four-dot capture immediately after a power cycle, and queued
input rejection during the dot interval, remain focused follow-up gates.

The corrected direct-run bank-copy utility then completed and verified the
previously open Bank-3-to-Bank-0 case:

```text
SOURCE BANK 0-3> 3
DEST BANK 0-2> 0
COPY B3->B0 $8000-$FFFF
TYPE COPY 30> COPY 30
COPYING ........ OK
RET A=AC X=F7 Y=05 P=F5 S=FD NV-BdIzC
```

Selector `0` and resident `J0` both entered a copied `00.0802(1404)` image that
printed four dots and reached HIMON `00.0802(1404)`. Because Banks 0 and 3 were
byte-identical, these traces do not independently distinguish sustained Bank 0.

Banks 1 and 2 retained older, distinguishable payloads. With Bank 3 at no-hash
`1404`, selector `1` and resident `J1` both reached hash-bearing STR8 `1323`
and HIMON `1334`. Selector `2` and resident `J2` both reached hash-bearing STR8
`1323` and HIMON `0731`:

```text
STR8-N>J1
J B1
STR8-N V 00.0802(1323) #5F6A0F7A
HIMON V 00.0802(1334)

STR8-N>J2
J B2
STR8-N V 00.0802(1323) #5F6A0F7A
HIMON V 00.0731(1515)
```

Those distinct identities close the cross-bank selector routes into Banks 1
and 2. The resident `J1` was issued after Bank 1 was already selected, and
resident `J2` after Bank 2 was already selected. They accept resident-command
and self-target worker smoke, but they do not independently prove cross-bank
resident `J1`/`J2` from Bank 3. The old hash in Banks 1 and 2 is expected
because those banks were not updated to `1404`. The final selector `3` from
Bank 2 warm-entered its local HIMON `0731`, again proving that local path does
not change banks. Cross-bank resident `J1`/`J2`, physical-reset recovery after
this exact matrix, and an independent Bank-0 identity/PCR observation remain
open.

### Operator Continuation: Cross-Bank J0 and J2

The operator supplied an additional terminal continuation after the archived
transcript. A current no-hash `1404` STR8 issued direct `J2` and reached old
Bank-2 STR8 `1323`. This is an independently distinguishable cross-bank direct
`J2` result:

```text
STR8-N V 00.0802(1404)
STR8-N>J2
J B2
STR8-N V 00.0802(1323) #5F6A0F7A
```

Later, an old hash-bearing `1323` bank issued direct `J0` and reached copied
Bank-0 STR8/HIMON `1404`:

```text
STR8-N V 00.0802(1323) #5F6A0F7A
STR8-N>J0
J B0
STR8-N V 00.0802(1404)
HIMON V 00.0802(1404)
```

This accepts cross-bank resident `J0`, independently distinguishes sustained
Bank 0, and accepts cross-bank resident `J2`. Direct `J1` moved between Banks 2
and 1, but both display STR8 `1323` and the continuation selected `S` before a
distinct HIMON identity was printed; that trace is not independent Bank-1
proof for the direct command. Cross-bank resident `J1` remains open.

The attempted `D 7FEC` returned `FTDI VIA IO SKIP`, so HIMON deliberately did
not expose a PCR byte. No PCR evidence is claimed. A following reset-selector
`2` route from current `1404` into Bank-2 STR8/HIMON `1323/0731` reconfirmed
the already-accepted cross-bank selector behavior.

## 2026-08-02 Sixteen-Dot Install and Cross-Bank Follow-Up

The operator supplied a 2,080-line, 75,775-byte terminal transcript with
SHA-256
`3BC4BDC12CE20349F2793CFEFECEF88669FF180A7DB23EF18E03A5360D22AF7F`.
The current TopWriter used face/prompt checks `$F8B4/$F8EB`; ASM-F2 reached
`ASM OK` and `SEAL`, and all protected programming gates passed:

```text
TW> S
TW STG
TW OK
TW> V
TW OK
TW> P
TW OK
TYPE WRITE TO PROGRAM B3> WRITE
TW PRG
TW OK
```

The installed no-hash candidate identifies as STR8 `00.0802(1420)`. Its
embedded attach routine contains the `$10` tick count and `$0E/$0D` delay
schedule. Every later live entry printed exactly 16 dots:

```text
................
STR8-N V 00.0802(1420)
```

The power-off capture contained 14 dots before the same identity:

```text
>POWER OFF
#8CCA7226# HSH_NF!
>..............
STR8-N V 00.0802(1420)
```

Because the same installed code repeatedly emits all 16 dots once the serial
connection is live, the missing two power-cycle characters are transport
startup loss while the FTDI/host path reattaches, not a shortened firmware
loop. The emitter and line format are accepted on hardware. No byte was sent
during the dots, so queued-input rejection remains a focused follow-up.

The direct-run bank-copy sample verified two full 32K operations in this
transcript:

```text
COPY B3->B2 $8000-$FFFF
TYPE COPY 32> COPY 32
COPYING ........ OK
RET A=AC X=F7 Y=05 P=F5 S=FD NV-BdIzC

COPY B3->B1 $8000-$FFFF
TYPE COPY 31> COPY 31
COPYING ........ OK
RET A=AC X=F7 Y=05 P=F5 S=FD NV-BdIzC
```

Bank 2 was copied while Bank-3 HIMON was `1404`. STR8 `U` then installed
HIMON `1425` in Bank 3, and Bank 1 was copied afterward. The resulting payload
inventory was:

```text
B3  STR8 1420 / HIMON 1425
  selector 2
B2  STR8 1420 / HIMON 1404
  selector 1
B1  STR8 1420 / HIMON 1425
  selector 0
B0  STR8 1404 / HIMON 1404, four-dot attach
```

The power-off reset reached Bank-3 `1420/1425`, accepting physical-reset
recovery after the install and copy work. It does not stand in for a distinct
reset after every later handoff.

The direct-command chain provides new evidence but does not close direct-J1.
From Bank 0, `J1` changed four-dot STR8 `1404` to sixteen-dot STR8 `1420`.
Because Banks 1 and 3 are exact `1420/1425` copies, that result cannot identify
which of those two banks remained selected. From the resulting session, `J2`
entered STR8 `1420`, and `G` then reached distinct Bank-2 HIMON `1404`:

```text
STR8-N V 00.0802(1404)
STR8-N>J1
J B1
................
STR8-N V 00.0802(1420)

STR8-N>J2
J B2
................
STR8-N V 00.0802(1420)
STR8-N>G
G HIMON
BOOT WARM
HIMON V 00.0802(1404)
```

This reconfirms cross-bank resident `J2`. Together with the earlier
distinguishable direct `J0`, direct `J0/J2` are hardware-accepted. Direct `J1`
still requires a Bank-1 identity different from Bank 3, or another independent
bank-state observation. The verified B3-to-B1 copy proves Bank 1 was written;
it does not by itself prove Bank 1 stays selected while its copied code runs.

## 2026-08-02 Six-Second STR8-N Prompt Acceptance

The operator supplied a 3,235-line, 120,635-byte transcript with SHA-256
`8A66D3565868597DABF93B1B2566EDB6868DE4B50EF9C697734332E458A6B366`.
Its earlier portion repeats prior evidence; the new acceptance run begins with
HIMON `00.0802(1440)` and the current `$F8B4/$F8EB` TopWriter source.

ASM-F2 reached `ASM OK` and `SEAL`. The TopWriter stage, verify, confirmed
Bank-3 program, and return all succeeded:

```text
TW> S
TW STG
TW OK
TW> V
TW OK
TW> P
TW OK
TYPE WRITE TO PROGRAM B3> WRITE
TW PRG
TW OK
RET A=AC X=10 Y=00 P=77 S=FD NV-BdIZC
```

The installed no-hash STR8 candidate identified as `00.0802(1440)`. The first
capture after programming again retained 14 of the 16 attach dots, consistent
with the already-accepted serial-startup loss. More importantly, the new
selector prompt executed every count and timed out normally:

```text
>..............
STR8-N V 00.0802(1440)
0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3 2 1
BOOT COLD
RAM ZERO OK
HIMON V 00.0802(1440)
```

A subsequent live STR8 entry printed all 16 attach dots. The operator entered
`0` during the first prompting tick, and STR8 accepted it immediately:

```text
................
STR8-N V 00.0802(1440)
0/1/2=BOOT 3=HIMON S=STR8  6 0
J B0
BOOT IN 3S
```

This hardware-accepts the six-count STR8-N prompting timeout and key polling.
It also confirms that the separate selected-bank `BOOT IN 3S` delay remains in
place. Bank 0 entered its older four-dot/three-count STR8 `1404` image, so the
new prompting constants were installed only in Bank 3 as intended. No exact
wall-clock measurement accompanies the transcript; the approximately
5.991-second duration remains the host cycle-model result.

The later traversal of the older Bank-0/1/2 images reconfirms existing selector
and direct-command behavior. It does not close direct `J1`: Banks 1 and 3 were
still not given independently distinguishable current payloads for that test.

## 2026-08-02 Distinct Bank-1 and Direct-J1 Acceptance

The operator supplied a 1,525-line, 58,969-byte transcript with SHA-256
`1D66B8E6A2FC3FB571F629D217048279A8E0EEC8E5358A405946189ABE4E815C`.
It begins from Bank-3 STR8/HIMON `00.0802(1440)` and deliberately creates an
identity unique to every bank before the final direct-J1 test.

The direct-run bank-copy source assembled through `ASM OK` and `SEAL`. Its
confirmation guard first rejected an incorrect phrase without writing flash:

```text
COPY B3->B1 $8000-$FFFF
TYPE COPY 31> WRITE 31
ABORT - NO FLASH WRITE
RET A=E0 X=FD Y=18 P=F4 S=FD NV-BdIzc
```

The exact retry copied and verified all eight sectors:

```text
COPY B3->B1 $8000-$FFFF
TYPE COPY 31> COPY 31
COPYING ........ OK
RET A=AC X=F7 Y=05 P=F5 S=FD NV-BdIzC
```

The current TopWriter was then assembled and sealed. An attempted `G 3000` at
the `SEAL>` prompt correctly produced assembler `ERR=$03 BO PC=$5000`; after
the required `.` completed sealing, `G 3000` opened TopWriter normally. Stage,
verify, confirmed Bank-3 programming, and return all passed. STR8 identified
as `00.0802(1452)`, and `U` installed matching HIMON `1452` in Bank 3. Bank 1
remained the verified `1440` copy.

The resulting identities were:

```text
B3  STR8 1452 / HIMON 1452
B1  STR8 1440 / HIMON 1440
B2  STR8 1420 / HIMON 1404
B0  STR8 1404 / HIMON 1404, four-dot attach
```

From Bank-3 `1452`, reset selector `1` reached Bank-1 STR8 `1440`, proving
sustained Bank-1 selection against the now-distinct Bank 3:

```text
STR8-N V 00.0802(1452)
0/1/2=BOOT 3=HIMON S=STR8  6 1
J B1
BOOT IN 3S
................
STR8-N V 00.0802(1440)
```

The operator then traversed Bank 1 through direct `J0` to Bank 0, reset
selector `1` back to Bank 1, and direct `J2` to Bank 2. From distinct Bank-2
STR8 `1420`, the formerly open resident `J1` crossed into Bank-1 STR8 `1440`.
The following `G` warm-entered local HIMON `1440`:

```text
STR8-N V 00.0802(1420)
STR8-N>J1
J B1
................
STR8-N V 00.0802(1440)
STR8-N>G
G HIMON
BOOT WARM
HIMON V 00.0802(1440)
```

Bank 3 would have displayed `1452`; Bank 2 displayed `1420`; Bank 0 displayed
four-dot `1404`. The `1440` STR8/HIMON pair therefore independently identifies
Bank 1 and rules out a Bank-3 remap. This accepts cross-bank resident `J1`.
Together with the earlier independently distinguished `J0` and `J2`, the full
resident cross-bank `J0/J1/J2` matrix and sustained Bank-0/1/2 execution are
hardware-accepted.

## 2026-08-02 Operator Acceptance: Dot-Time Input Rejection

The operator explicitly reports that the remaining attach-display test passed:
input sent during the 16-dot interval was discarded before the STR8-N selector
opened and was not consumed as a selector response. A successfully discarded
byte produces no printable terminal token, so this is recorded as
operator-observed hardware proof. The 16-dot emitter, post-dot RX flush, and
six-second prompting-delay slice now have no remaining board gates.

## 2026-08-02 J3 Installation and Ambiguous First Return

The operator supplied a 2,512-line, 101,626-byte transcript with SHA-256
`9DA64153ED77D02AA9CA06735F05E40D919CD7D3EE952A2D272B1CF6503E25AF`.
It installs the J3-capable STR8 candidate, copies it to Bank 0, exercises J3
from that copy, and finally prepares distinct source and destination identities
for the acceptance run.

The generated TopWriter assembled through `ASM OK` and `SEAL`. Stage, verify,
confirmed Bank-3 programming, and return all passed:

```text
TW> S
TW STG
TW OK
TW> V
TW OK
TW> P
TW OK
TYPE WRITE TO PROGRAM B3> WRITE
TW PRG
TW OK
RET A=AC X=10 Y=00 P=77 S=FD NV-BdIZC
```

The installed image identified as STR8 `00.0802(1509)` and published the new
command in its resident help:

```text
? U J0 J1 J2 J3 G R
```

The subsequent `U` operation advanced Bank-3 HIMON to `00.0802(1514)`. The
direct-run copy utility then accepted source Bank 3 and destination Bank 0,
printed `COPY B3->B0 $8000-$FFFF`, verified all eight sectors, and returned
`A=$AC` with carry set. At this point Banks 0 and 3 were exact
STR8/HIMON `1509/1514` copies.

Selector `0` entered the Bank-0 copy. Its resident J3 command executed:

```text
STR8-N>J3
J B3
................
STR8-N V 00.0802(1509)
```

The following timeout reached HIMON `1514`. This accepts the installed J3
parser and a functional Bank-3 handoff smoke from a Bank-0 STR8 copy. It does
not independently identify the selected destination: staying in Bank 0 or
correctly selecting Bank 3 would expose the same `1509/1514` identities.

The transcript ends after another successful TopWriter and `U` sequence
advanced only Bank 3 to STR8/HIMON `00.0802(1518)`. Bank 0 remains the
verified `1509/1514` copy. The board is therefore prepared for the definitive,
non-destructive return test without another copy or flash operation:

```text
Bank-3 STR8 1518: choose selector 0
Bank-0 STR8 1509: choose S, issue J3
require J B3 and Bank-3 STR8 1518
choose S, issue G, require HIMON 1518
```

Result: partial board pass. J3 command installation and Bank-0 execution pass;
distinct Bank-3 destination proof remains open. Optional follow-up may also
confirm `J4` prints `?` and `$1FFD-$1FFF` contains `42 4A 03` after J3.

## 2026-08-02 J3 Distinct Bank-3 Return Acceptance

The operator completed the prepared non-destructive follow-up. The run began
in Bank-3 STR8/HIMON `00.0802(1518)`. Reset selector `0` printed `J B0` and
entered the verified Bank-0 copy, which independently identified itself as
STR8 `00.0802(1509)`:

```text
STR8-N V 00.0802(1518)
0/1/2=BOOT 3=HIMON S=STR8  6 0
J B0
BOOT IN 3S

................
STR8-N V 00.0802(1509)
```

The operator selected `S` and issued the new resident command. It selected
Bank 3 and entered the newer image:

```text
STR8-N>J3
J B3

................
STR8-N V 00.0802(1518)
```

No selector input followed. The normal countdown expired, printed
`BOOT COLD` and `RAM ZERO OK`, and entered HIMON `00.0802(1518)`. Bank 0
retains STR8/HIMON `1509/1514`; therefore an accidental stay in Bank 0 cannot
produce either `1518` identity. The trace independently proves the Bank-3
destination and accepts resident J3 from a copied STR8 in Bank 0.

Result: J3 host and hardware acceptance complete. `J4` rejection and Bank
Jump Record `42 4A 03` inspection remain optional regression observations,
not open acceptance gates.

## 2026-08-02 J3 Bank Jump Record Cold-Preservation Acceptance

The operator installed the focused HIMON fix through the existing STR8 `U`
path. The update programmed and verified `$C000-$EFFF`, and `G` identified the
new monitor as HIMON `00.0802(1536)`.

From Bank-3 STR8 `1518`, reset selector `0` entered Bank-0 STR8 `1509`. The
operator selected `S` and issued `J3`; it printed `J B3`, returned to Bank-3
STR8 `1518`, and then timed out normally:

```text
BOOT COLD
RAM ZERO OK

HIMON V 00.0802(1536)
>D 1FFD 1FFF
1FFD: 42 4A 03 | BJ.
```

This is the path that previously lost Bank 3 because HIMON treated `$03` as
out of range before clearing RAM. The operator then exercised a second cold
clear explicitly:

```text
>HCOLD
RUN HCOLD @C030 K=03 ? y
BOOT COLD
RAM ZERO OK

HIMON V 00.0802(1536)
>D 1FFD 1FFF
1FFD: 42 4A 03 | BJ.
```

The signed record survives both the J3 cold entry and confirmed `HCOLD`.
Result: the shared `$04` bank-count correction and J3 record preservation are
hardware-accepted. This focused result does not substitute for the full Bank
Jump Record card's unknown baseline, J0/J1/J2, invalid-vector, and flash-CRC
matrix.

## 2026-08-02 STR8 Missing Local-App Fallback Acceptance

The candidate installed as STR8 `00.0802(1709)`. The current direct-run bank
maintenance source assembled through `ASM OK` and `SEAL`. Its map command
completed all four rows and returned to its menu; Bank-3 sector F was shown as
protected:

```text
BANK 8 9 A B C D E F
E=ERASED U=USED P=B3F PROTECTED
B0 E E E E E E E E
B1 E E E E E E E E
B2 U U U E E E E E
B3 U U U U U U U P
 OK
```

The operator selected Bank 3 sector C and supplied the exact destructive
confirmation:

```text
C=COPY E=ERASE M=MAP Q=QUIT> E
BANK 0-3> 3
SECTOR 8-F, ALL, OR X-Y; B3 MAX E> C
TYPE ERASE 3C> ERASE 3C
```

The maintenance utility emitted no output through erased HIMON services and
transferred to Bank-3 STR8 in protected sector F. With no selector input, the
full countdown expired and the new local-app gate rejected the all-`$FF`
`$C000-$C00F` entry face:

```text
................
STR8-N V 00.0802(1709)

0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3 2 1

NO BOOT @C000

STR8-N V 00.0802(1709)
ROM $F000
? U J0 J1 J2 J3 G R
STR8-N>
```

There was no second attach sequence and no reset loop. From that recovery
prompt, `U` received, programmed, and verified the HIMON `$C000-$EFFF` S19.
The following positive warm-entry check passed:

```text
STR8-N>G
G HIMON
BOOT WARM

HIMON V 00.0802(1657)
```

Result: the requested no-input missing-app fallback and in-place `U` recovery
are hardware-accepted. This run also accepts maintenance map, post-map loop,
Bank-3 single-sector-C erase, no-HIMON post-erase execution, and protected
sector-F STR8 return.

## 2026-08-02 STR8 Missing-App Warm-Fallback Acceptance

The focused continuation restored the maintenance utility, displayed the
four-bank map, and confirmed the ordered Bank-3 range `9-D`:

```text
C=COPY E=ERASE M=MAP Q=QUIT> E
BANK 0-3> 3
SECTOR 8-F, ALL, OR X-Y; B3 MAX E> 9-D
TYPE ERASE 39-D> ERASE 39-D
```

STR8 `00.0802(1709)` again reached the resident menu through the no-input
`NO BOOT @C000` fallback. With the local target still erased, the operator
then directly exercised the resident warm command:

```text
STR8-N>G
G HIMON

NO BOOT @C000

STR8-N V 00.0802(1709)
ROM $F000
? U J0 J1 J2 J3 G R
STR8-N>
```

Finally, a fresh STR8 entry received selector `3` during count `6` and used
the same safe fallback:

```text
................
STR8-N V 00.0802(1709)

0/1/2=BOOT 3=HIMON S=STR8  6 3

NO BOOT @C000

STR8-N V 00.0802(1709)
ROM $F000
? U J0 J1 J2 J3 G R
STR8-N>
```

Result: all local-app availability entry paths are host- and hardware-
accepted: no-input cold, resident `G` warm, and startup selector-`3` warm.
The maintenance ordered-range run demonstrably progressed through sector C;
because its RAM result board was not inspected afterward, this transcript is
not used as proof that every selected sector through D completed.

## 2026-08-02 STR8 Bank Maintenance Package Negative

The current direct-run maintenance source again assembled through `ASM OK`.
At the seal prompt, the operator attempted to build an AP package:

```text
ASM>$2625:         END
ASM OK
SEAL> PACKAGE $3000
PKG ERR=$02
SEAL>
```

This is a package-only negative, not an assembly or flash failure. `$3000` is
a valid package-output buffer and does not overlap the `$2000-$2624` body.
`$02` is the seal bad-flags status. The program contains substantially more
internal absolute references than the ASM-F2 V1 `ASM_RELOC_MAX=$10` table can
describe, so it is intentionally direct-run rather than AP-package-clean.
No maintenance command or flash mutation occurred. The correct continuation
is `SEAL> .`, followed by `G 2000` at HIMON.

## 2026-08-02 Movable Session Reporter Package and AP Range Negative

After the maintenance run, the operator cold-cleared RAM, reloaded current
ASM-F2 `00.0802(1709)`, and pasted the generated movable reporter. The board
assembled the full `$0C5F` body and its `$E0`-row private rebase table, then
built the one-sector AP envelope successfully:

```text
ASM>$2C5F:         ENTRY START
ASM>$2C5F:         END
ASM OK
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$0C8B
SEAL> .
ASM BYE
```

This accepts current-image ASM-F2 source compatibility, emission of the
private rebase table into the package, and the `$1000` AP-envelope size gate.
It does not yet accept execution of that table, Bank-0 installation,
relocation to `$4000`, or post-session reporting.

The following command was a safe range negative:

```text
>AP B3
AP [Bn] pkg dst
>AP B0 $3000 $8000
APERR=$06
```

`APERR=$06` is the expected `BAD RANGE`. In banked form, the package source
must be visible in the selected bank at `$8000-$FFFF`; `$3000` is only the RAM
envelope bay. The reporter body must load within `$2000-$4FFF`. At its current
`$0C5F` length its legal starts end at `$43A1`, so `$8000` is also an invalid
destination. Range validation occurred before execution and made no flash
write. The `$3000` source check also failed before the STR8 bank-staging worker
ran, so the RAM envelope remains available on the captured prompt.

The immediate non-destructive continuation is `AP $3000 $4000` without a bank
argument. It should run the envelope already in RAM and report the reporter's
own build session. The captured map showed Bank 0 fully erased immediately
before this package build. On that unchanged board state, the persistent
continuation is to preserve the `$3000` envelope, assemble and direct-run
`bank0ap-put-transient-2000.a`, select `$8000` or the AUTO result, and confirm
the displayed `$0C8B` write. Record the installed address as `$XXXX`, then use
`AP B0 $XXXX $4000` before the target ASM session and `G 4000` after it.

## 2026-08-02 STR8 Bank-3 Copy, Confirmation, Erase, and Recovery

The board ran STR8, HIMON, and ASM-F2 `00.0802(1823)`. The current persistent
menu source ended at `$2625`, assembled through `ASM OK`, exited with `SEAL> .`,
and ran directly at `$2000`. Bank 3 was copied to disposable Bank 2 with the
exact confirmation. Eight completion dots, `OK`, and the reprinted menu show
that all eight copy-sector worker calls returned success:

```text
C=COPY E=ERASE M=MAP Q=QUIT> C
SOURCE BANK 0-3> 3
DEST BANK 0-2> 2
!STR8
TYPE COPY 32> COPY 32

........ OK

STR8 BANK MAINT
```

The immediate live map found all eight Bank-2 sectors used and kept Bank-3
sector F protected. `Q` then returned normally to HIMON with `$AC` and carry
set:

```text
BANK 8 9 A B C D E F
E=ERASED U=USED P=B3F PROTECTED
B0 E E E E E E E E
B1 E E E E E E E E
B2 U U U U U U U U
B3 U U U U U U U P
 OK

STR8 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY E=ERASE M=MAP Q=QUIT> Q

#GO# ENTRY=2000
RET A=AC X=00 Y=00 P=F5 S=FD NV-BdIzC
```

The exact-confirmation negative selected Bank-3 range B-E but supplied the
confirmation for range 8-E. The utility rejected it before a write and stayed
resident:

```text
C=COPY E=ERASE M=MAP Q=QUIT> E
BANK 0-3> 3
SECTOR 8-F, ALL, OR X-Y; B3 MAX E> B-E
TYPE ERASE 3B-E> ERASE 38-E
ABORT

STR8 BANK MAINT
```

The operator then selected 8-E and supplied its exact confirmation. The
utility made no post-start HIMON calls and transferred to protected STR8 at
`$F000`. The countdown's dots are STR8 startup output, not maintenance
completion dots. The blank local `$C000` fallback proves that the ordered
erase progressed successfully through at least sector C:

```text
C=COPY E=ERASE M=MAP Q=QUIT> E
BANK 0-3> 3
SECTOR 8-F, ALL, OR X-Y; B3 MAX E> 8-E
TYPE ERASE 38-E> ERASE 38-E


................
STR8-N V 00.0802(1823)

0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3 2 1

NO BOOT @C000
```

From resident STR8, `J2` cold-booted the copied Bank-2 image. Its HIMON could
enter STR8 and ASM-F2, and a later `J2` repeated the cold boot. Conversely,
`J3` again reached protected STR8 but reported the expected blank local
`$C000`; `J0` rejected the erased Bank-0 reset vector:

```text
STR8-N>J2
J B2

................
STR8-N V 00.0802(1823)

0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3 2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0802(1823)
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

................
STR8-N V 00.0802(1823)

0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3 2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0802(1823)
>ASM
ASM-F2 00.0802(1823)
ASM>$2000: .
ASM BYE
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

................
STR8-N V 00.0802(1823)

0/1/2=BOOT 3=HIMON S=STR8  6 S
STR8-N V 00.0802(1823)
ROM $F000
? U J0 J1 J2 J3 G R

STR8-N>J3
J B3

................
STR8-N V 00.0802(1823)

0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3 2 1

NO BOOT @C000

STR8-N V 00.0802(1823)
ROM $F000
? U J0 J1 J2 J3 G R
STR8-N>J0
J B0

JERR B0 V=$FFFF
STR8-N>J2
J B2

................
STR8-N V 00.0802(1823)

0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3 2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0802(1823)
```

Result: full Bank-3-to-Bank-2 copy, source STR8-signature warning, post-copy
menu persistence, live map, `Q`, mismatched exact-confirmation abort, Bank-3
post-erase STR8 return, protected sector-F survival, and Bank-2 recovery boot
are hardware-accepted. The result board was not inspected after `ERASE 38-E`,
so this evidence does not claim that sectors D and E completed even though the
selected operation covered 8-E.

## 2026-08-02 Bank-2 Maintenance Map Return-Bank Failure

After the Bank-3-to-Bank-2 recovery copy and the Bank-3 `$8000-$EFFF` erase,
the RAM-resident maintenance body remained at `$2000`. The operator selected
Bank 2, warm-booted its copied HIMON, and ran the maintenance map again:

```text
STR8-N>J2
J B2

................
STR8-N V 00.0802(1823)

0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3
BOOT WARM

HIMON V 00.0802(1823)
>G 2000
GO 2000

STR8 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY E=ERASE M=MAP Q=QUIT> M

BANK 8 9 A B C D E F
E=ERASED U=USED P=B3F PROTECTED
B0
................
STR8-N V 00.0802(1823)

0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3 2 1S
STR8-N V 00.0802(1823)
ROM $F000
```

This is a deterministic return-bank failure, not corruption of the `$2000`
body or `$0A00-$19FF` stage. Mode `$06` selected Bank 0, copied its sector into
RAM, and followed the shared worker contract by restoring Bank 3. The map then
resumed in RAM, but its `$7E08/$7E0A` HIMON vectors named routines in the active
bank's `$C000-$EFFF` window. That window was erased in Bank 3, so no first map
marker could be printed. `J2` did not persist across the worker call.

The operator subsequently used resident STR8 `U` to reinstall HIMON
`00.0802(1823)` into Bank 3 and cold-booted it successfully. That recovery is
accepted; it is not proof of the map repair.

The host repair is confined to `str8-bank-maint-2000.a`. The map snapshots the
entry PCR bank bits in `$1B0C`, masks interrupts across each `$F003` stage and
immediate bank restoration, preserves worker carry, and then scans/prints from
the entry bank. The shared STR8 worker continues to restore Bank 3 for every
existing caller. Host WDC assembly passes with 63/64 global symbols, 12/16
locals in the map scope, and an end address of `$2649`. Board acceptance is
pending a complete four-row map from Bank 2 followed by the `$1B0C` entry-bank
shadow remaining `$EC` after `Q`.

## 2026-08-02 Corrected Bank-2 Map Functional Pass

The operator entered resident STR8, selected `J2`, and cold-booted the copied
Bank-2 image. Bank-2 HIMON and ASM-F2 both identified as `00.0802(1823)`. The
corrected maintenance source included the entry-bank PCR save/restore path,
ended at `$2649`, and assembled successfully:

```text
STR8-N>J2
J B2

................
STR8-N V 00.0802(1823)

0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3 2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0802(1823)
>ASM NEW
ASM-F2 00.0802(1823)
```

After the source paste, the final address and assembly result were:

```text
ASM>$2649:         END
ASM OK
SEAL> .
ASM BYE
```

Running the new body at `$2000` completed the map instead of leaving for STR8
after `B0`. It printed every sector marker, returned `OK`, remained in the
maintenance menu, and `Q` returned `$AC` with carry set:

```text
>G 2000
GO 2000

STR8 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY E=ERASE M=MAP Q=QUIT> M

BANK 8 9 A B C D E F
E=ERASED U=USED P=B3F PROTECTED
B0 E E E E E E E E
B1 E E E E E E E E
B2 U U U U U U U U
B3 E E E E U U U P
 OK

STR8 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY E=ERASE M=MAP Q=QUIT> Q

#GO# ENTRY=2000
RET A=AC X=00 Y=00 P=F5 S=FD NV-BdIzC
```

After a STR8 warm handoff, the same RAM body completed the identical map a
second time. The following safe copy-input negative rejected a malformed
destination, prohibited Bank 3, and nonnumeric `Q`; empty destination input
then aborted without reaching destructive confirmation:

```text
>G 2000
GO 2000

STR8 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY E=ERASE M=MAP Q=QUIT> M

BANK 8 9 A B C D E F
E=ERASED U=USED P=B3F PROTECTED
B0 E E E E E E E E
B1 E E E E E E E E
B2 U U U U U U U U
B3 E E E E U U U P
 OK

STR8 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY E=ERASE M=MAP Q=QUIT> C
```

After that first `C` input returned directly to the menu, the captured
destination-input negative was:

```text
STR8 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY E=ERASE M=MAP Q=QUIT> C
SOURCE BANK 0-3> 2
DEST BANK 0-2> 8-E
DEST BANK 0-2> 3
DEST BANK 0-2> Q
DEST BANK 0-2>
ABORT
```

Result: the corrected source's onboard assembly, complete map, repeated map,
post-map menu loop, `Q`, destination validation, and empty destination abort
are hardware-accepted from a `J2` entry. Bank-3 HIMON had already been restored,
and Bank 2 and Bank 3 report the same `1823` versions, so the active bank after
`Q` cannot be identified independently from these banners. The final entry-
bank-preservation gate is the RAM shadow at `$1B0C`, requiring `$EC` rather than
Bank-3 `$EE` after the Bank-2 map and `Q`.

## 2026-08-02 Maintenance Map Direct-PCR Read Guard

The attempted live PCR dump was blocked by HIMON's intentional FTDI/VIA I/O
guard:

```text
7FE0: FTDI VIA IO SKIP
```

No bank identity is claimed from that command. The corrected maintenance body
already masks and saves the menu-entry PCR value at `$1B0C`, then refreshes it
when the post-map menu is entered. After `Q`, the safe observable gate is:

```text
D 1B0C 1B0C
```

The one-byte result must be `$EC` for Bank 2. `$EE` would show that the map
silently returned to Bank 3. This RAM-shadow check replaces the impossible
direct `$7FEC` dump; it does not require rerunning the map if the captured HIMON
prompt and RAM session are still intact.

## 2026-08-02 Selector-2 Corrected Map Replay

The follow-up used the STR8 startup selector rather than the resident `J2`
prompt. Key `2` selected Bank 2, delayed the handoff, and cold-booted its
HIMON:

```text
................
STR8-N V 00.0802(1823)

0/1/2=BOOT 3=HIMON S=STR8  6 2
J B2
BOOT IN 3S

................
STR8-N V 00.0802(1823)

0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3 2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0802(1823)
```

Bank-2 ASM-F2 again assembled the corrected source through `$2649` and
`ASM OK`. The first map completed all rows and `Q` returned `$AC` with carry
set. A STR8 warm handoff preserved the RAM body, and a second `G 2000` produced
the same full map:

```text
BANK 8 9 A B C D E F
E=ERASED U=USED P=B3F PROTECTED
B0 E E E E E E E E
B1 E E E E E E E E
B2 U U U U U U U U
B3 E E E E U U U P
 OK

STR8 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY E=ERASE M=MAP Q=QUIT>
```

The transcript ends at that second maintenance prompt. It contains neither a
second `Q` nor `D 1B0C 1B0C`, so the selector-2 functional replay is accepted
but the entry-bank shadow remains unobserved. From this exact prompt the
remaining sequence is simply:

```text
Q
D 1B0C 1B0C
```

The required one-byte value remains `$EC`.

## 2026-08-02 Bank-2 Map Entry-Bank Shadow Acceptance

The follow-up closed the remaining identity gate with the maintenance body's
safe masked-PCR shadow at `$1B0C`. The first completed map returned through
`Q` with status `$AC` and carry set:

```text
BANK 8 9 A B C D E F
E=ERASED U=USED P=B3F PROTECTED
B0 E E E E E E E E
B1 E E E E E E E E
B2 U U U U U U U U
B3 E E E E U U U P
 OK

STR8 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY E=ERASE M=MAP Q=QUIT> Q

#GO# ENTRY=2000
RET A=AC X=00 Y=00 P=F5 S=FD NV-BdIzC
```

After the following warm handoff, HIMON observed the Bank-2 value `$EC`, not
the Bank-3 value `$EE`:

```text
................
STR8-N V 00.0802(1823)

0/1/2=BOOT 3=HIMON S=STR8  6 3
BOOT WARM

HIMON V 00.0802(1823)
>D 1B0C
1B0C: EC | .
```

The next selector-2 handoff deliberately cold-booted Bank 2 and cleared the
RAM shadow. The resulting `$00` is therefore expected and is not a failed bank
restore:

```text
0/1/2=BOOT 3=HIMON S=STR8  6 2
J B2
BOOT IN 3S

................
STR8-N V 00.0802(1823)

0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3 2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0802(1823)
>D 1B0C
1B0C: 00 | .
```

Bank-2 ASM-F2 then freshly assembled the corrected source through `$2649` and
`ASM OK`. Its full map and `Q` immediately exposed `$EC` at the HIMON prompt:

```text
ASM>$2649:         END
ASM OK
SEAL> .
ASM BYE
>G 2000
GO 2000

STR8 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY E=ERASE M=MAP Q=QUIT> M

BANK 8 9 A B C D E F
E=ERASED U=USED P=B3F PROTECTED
B0 E E E E E E E E
B1 E E E E E E E E
B2 U U U U U U U U
B3 E E E E U U U P
 OK

STR8 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY E=ERASE M=MAP Q=QUIT> Q

#GO# ENTRY=2000
RET A=AC X=00 Y=00 P=F5 S=FD NV-BdIzC
>D 1B0C
1B0C: EC | .
```

A final STR8 warm round-trip preserved the same shadow:

```text
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

................
STR8-N V 00.0802(1823)

0/1/2=BOOT 3=HIMON S=STR8  6 3
BOOT WARM

HIMON V 00.0802(1823)
>D 1B0C
1B0C: EC | .
```

Result: the corrected map's Bank-2 entry-bank restoration is hardware-
accepted. The `$EC` observation distinguishes Bank 2 from the worker's normal
Bank-3 return value `$EE`, survives a warm STR8/HIMON handoff, and reproduces
after a cold reset and fresh onboard assembly. The broader maintenance test
matrix for the separately listed erase, skip, `ALL`, empty-input, and explicit-
failure cases is explicitly deferred and does not block acceptance of this map
repair.

## 2026-08-05 STR8 `$F010` Board Test Fixture Corrections

The `STR8_0805_BOARD_TEST.md` run installed the new Bank-3 top sector and
passed its first three sections. The board read back:

```text
F000: 4C 13 F0 4C 42 F3 4C 5E F3 4C 9C F4 53 52 01 07
F010: 4C 49 F3 78
FFFA: BD F0 00 F0 D1 F0

STR8-N V 00.0805(1203) $F
U J0 J1 J2 J3 G R
```

Both `?` and lowercase `x` printed the implicit help, and `G` warm-entered
HIMON `00.0802(1823)`. The first selector-fixture paste reported
`ERR=$03 BO` at `STA RES+1`; despite a later `ASM OK`, HIMON correctly refused
execution with `EXEC ERR=$03`. The fixture replaced the symbol addend with
absolute `RES1 EQU $1A21`.

The next run executed but returned before any valid selection:

```text
RET A=E1 X=FF Y=30 P=F4 S=FD NV-BdIzc
1A20: 42 53 E1 01 00 00 00 00
0200: 53 56 43 00 1C EC 7F A9 EE 0C EC 7F 64 D1 A9 F0
0210: 85 D2
```

Status `$E1`, step `$01`, and captured PCR `$00` identify the fixture's
incorrect reset-time assertion. Hardware reset had made Bank 3 visible through
the board pull-ups, but no software selection had yet converted PCR to the
explicit Bank-3 `$EE` output pattern. The retained `$0200` contents confirm the
test stopped before `$F010` copied its current worker; no flash path was
reachable.

The corrected fixture records initial PCR only as information and instead
proves that rejected Bank 4 left Bank 3 visible by matching the installed
`$F00C-$F010` identity `53 52 01 07 4C`. Later valid selections still require
the explicit row patterns `$CC/$CE/$EC/$EE`. Hardware acceptance of that final
fixture is not claimed here until its result dump is captured.

The next run captured that result and closes the fixed selector service:

```text
RET A=AC X=03 Y=07 P=F5 S=FD NV-BdIzC
1A20: 42 53 AC 00 00 01 04 00 | 00 CC FF FF FF FF FF FF
1A30: 01 CE FF FF FF FF FF FF | 02 EC 4C 53 52 01 07 78
1A40: 03 EE 4C 53 52 01 07 4C
0200: 4C 12 02 08 78 C9 04 B0 06 20 7C 04 28 38 60 28
0210: 18 60
```

This accepts invalid Bank 4 with Bank 3 unchanged, the `$F010` Bank-0 call,
the retained `$0203` Bank-1/2/3 calls, exact canonical PCR patterns after each
software selection, and the current RAM worker bytes. The initial `$00` PCR is
the documented reset/input state and is not a failure.

The four-bank CRC fixture returned `$AC/C=1` before and after the J tests with
identical rows:

```text
1A10: E1 0F E1 0F E1 0F E1 0F E1 0F E1 0F E1 0F E1 0F
1A20: E1 0F E1 0F E1 0F E1 0F E1 0F E1 0F E1 0F E1 0F
1A30: EC B7 36 70 CE 76 72 C8 A7 71 06 AD D9 18 F6 8A
1A40: EC B7 36 70 CE 76 7F 73 A7 71 06 AD D9 18 32 42
```

Thus Banks 0/1 are fully erased, Banks 2/3 retain their distinct images, and
no selector or J test changed flash. Invalid `J0/J1` preserved `42 4A 02`;
`J2` reached Bank 2 and published bank 2; Bank-2 `J3` returned to Bank 3 and
published bank 3. The run did not issue the requested record dump after either
`HCOLD`, so the two post-cold observations are not claimed from this transcript.

## 2026-08-05 STR8 Maintenance And Bank-3 ALL Completion

The continuation first closed the earlier J3/J2 gap. Bank 3 still held
`42 4A 03`; a repeated J2 handoff reported `42 4A 02` both before and after
`HCOLD`. After physical reset, the combined maintenance source assembled
through `$2649` with `ASM OK`.

The non-writing matrix passed every requested position: empty operation;
empty copy source, destination, and confirmation; empty erase bank, sector,
and confirmation; wrong `NO` erase confirmation; Bank-3 sector F rejection;
and a Bank-0 bad-reset-vector copy source. All returned to the persistent menu
without a flash confirmation or write. The last path printed `!` before the
menu, exercising status `$E6` safely.

The destructive Bank-0 sequence then produced the expected maps:

```text
after COPY 30:     B0 U U U U U U U U
after ERASE 08:    B0 E U U U U U U U
after ERASE 09-B:  B0 E E E E U U U U
after ERASE 0ALL:  B0 E E E E E E E E
```

The already-erased sector-8 repeat returned one dot and `OK`. A mismatched
range confirmation and an empty confirmation both aborted. Exact `COPY 30`
and `COPY 31` restored Banks 0 and 1; the next map showed all sectors used in
Banks 0-2 and B3 sectors 8-E used with F protected. `Q` returned `$AC/C=1`,
and the result row was:

```text
1B00: AC 51 00 00 00 00 00 00 00 00 00 00 EE
```

Resident J0 and J1 then booted their copied images and published
`42 4A 00` and `42 4A 01`. Each reached HIMON `00.0802(1823)` and completed
`HCOLD`; neither post-cold record dump was captured. Later work does not use
`$1FFD-$1FFF`, so a final current dump can close J1, while J0 requires one
short repeat.

The Bank-3 `ALL` operation was executed twice. Each erased `$8000-$EFFF` and
returned directly to the protected `STR8-N V 00.0805(1203) $F` sector. The
first `U` recovery restored HIMON `00.0802(1823)`. The second recovery restored
HIMON `00.0805(1312)`, after which `L F` reported:

```text
LF OK WR=3C6D GO=800C
ASM-F2 00.0805(1312)
```

Final top-sector evidence remained exact:

```text
F000: 4C 13 F0 4C 42 F3 4C 5E F3 4C 9C F4 53 52 01 07
F010: 4C 49 F3 78
FFFA: BD F0 00 F0 D1 F0
```

A fresh maintenance build and map showed all four banks used, B3F protected,
and `Q` returning `$AC/C=1`. The operator stopped at the explicitly deferred
V1-only tests. Two post-cold record observations remain: one current J1 dump
and one J0 repeat. V1 migration tests remain unavailable by design.

## 2026-08-05 Bank Jump Record J0/J1 Cold-Persistence Closure

The focused continuation captured the previously missing current records. J0
remained `42 4A 00` through two `HCOLD` operations, and J1 remained
`42 4A 01` through `HCOLD`. The opening Bank-3 dump also retained
`42 4A 03`. This closes the Bank Jump Record cold-preservation matrix.

Raw board transcript:

```text
STR8-N V 00.0805(1203) $F

0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3 2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0805(1312)
>D 1FFD 1FFF
1FFD: 42 4A 03 | BJ.
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

................
STR8-N V 00.0805(1203) $F

0/1/2=BOOT 3=HIMON S=STR8  6 0
J B0
BOOT IN 3S

................
STR8-N V 00.0805(1203) $F

0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3 2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0802(1823)
>D 1FFD 1FFF
1FFD: 42 4A 00 | BJ.
>HCOLD
RUN HCOLD @C030 K=03 ? y
BOOT COLD
RAM ZERO OK

HIMON V 00.0802(1823)
>HCOLD
RUN HCOLD @C030 K=03 ? y
BOOT COLD
RAM ZERO OK

HIMON V 00.0802(1823)
>D 1FFD 1FFF
1FFD: 42 4A 00 | BJ.
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

................
STR8-N V 00.0805(1203) $F

0/1/2=BOOT 3=HIMON S=STR8  6 S
STR8-N V 00.0805(1203) $F
U J0 J1 J2 J3 G R
STR8-N>J3
J B3

................
STR8-N V 00.0805(1203) $F

0/1/2=BOOT 3=HIMON S=STR8  6 5 4 S
STR8-N V 00.0805(1203) $F
U J0 J1 J2 J3 G R
STR8-N>J1
J B1

................
STR8-N V 00.0805(1203) $F

0/1/2=BOOT 3=HIMON S=STR8  6 5 4 3 2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0802(1823)
>D 1FFD 1FFF
1FFD: 42 4A 01 | BJ.
>HCOLD
RUN HCOLD @C030 K=03 ? y
BOOT COLD
RAM ZERO OK

HIMON V 00.0802(1823)
>D 1FFD 1FFF
1FFD: 42 4A 01 | BJ.
```

## 2026-08-05 STR8 Live-Dots Partial Board Pass and Candidate Copies

The normal candidate was regenerated on board as
`STR8-N V 00.0805(1807) $F`. The pasted image retained the planned header
`4C 13 F0 4C 24 F3 4C 40 F3 4C 7E F4 53 52 01 07` and vector tail
`B6 F0 00 F0 CA F0`. TopWriter rejected the first wrong confirmation, then
staged, programmed, and verified Bank 3:

```text
>G 3000
GO 3000
TOPWRITER
S STAGE+VERIFY
V VERIFY STAGE
P PROGRAM BANK 3
I STATUS
Q QUIT
TW> S
TW STG
TW OK
TW> P
TW OK
TYPE WRITE TO PROGRAM B3> I
TW CANCEL
TW>
TOPWRITER
S STAGE+VERIFY
V VERIFY STAGE
P PROGRAM BANK 3
I STATUS
Q QUIT
TW> S
TW STG
TW OK
TW> P
TW OK
TYPE WRITE TO PROGRAM B3> WRITE
TW PRG
TW OK
TW> I
TW MODE=$01 RES=$AC @=$0000
TW> Q

#GO# ENTRY=3000
RET A=AC X=10 Y=00 P=77 S=FD NV-BdIZC
>
```

The terminal capture contained 35 LF lines before each shown Bank-3 startup.
Live `S`, explicit `J3`, timeout cold, and live `3` warm behaved as follows:

```text
................

STR8-N V 00.0805(1807) $F
0/1/2=BOOT 3=HIMON S=STR8  ..S
U 0-3 J0-3
STR8-N>J3
J B3

[35 LF bytes]
................

STR8-N V 00.0805(1807) $F
0/1/2=BOOT 3=HIMON S=STR8  ................
BOOT COLD
RAM ZERO OK

HIMON V 00.0805(1312)
>D 1FFD 1FFF
1FFD: 42 4A 03 | BJ.
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

[35 LF bytes]
................

STR8-N V 00.0805(1807) $F
0/1/2=BOOT 3=HIMON S=STR8  ..3
BOOT WARM

HIMON V 00.0805(1312)
>D 1FFD 1FFF
1FFD: 42 4A 03 | BJ.
```

The final maintenance run cloned the candidate to B0/B1 while retaining the
old B1 image in B2. All three full-bank operations completed, and the map
reported the expected used/protected shape:

```text
STR8 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY E=ERASE M=MAP Q=QUIT> C
SOURCE BANK 0-3> 3
DEST BANK 0-2> 0
!STR8
TYPE COPY 30> COPY 30

........ OK

STR8 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY E=ERASE M=MAP Q=QUIT> C
SOURCE BANK 0-3> 1
DEST BANK 0-2> 2
!STR8
TYPE COPY 12> COPY 12

........ OK

STR8 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY E=ERASE M=MAP Q=QUIT> C
SOURCE BANK 0-3> 3
DEST BANK 0-2> 1
!STR8
TYPE COPY 31> COPY 31

........ OK

STR8 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY E=ERASE M=MAP Q=QUIT> M

BANK 8 9 A B C D E F
E=ERASED U=USED P=B3F PROTECTED
B0 U U U U U U U U
B1 U U U U U U U U
B2 U U U U U U U U
B3 U U U U U U U P
 OK

STR8 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY E=ERASE M=MAP Q=QUIT> Q

#GO# ENTRY=2000
RET A=AC X=00 Y=00 P=F5 S=FD NV-BdIzC
>
```

This is a partial board acceptance. The run did not capture direct
`$F000-$F013`/`$FFFA-$FFFF` flash reads after programming, did not boot the
new B0/B1 copies, and did not repeat the full early-quarantine plus live
`G`/`R` rejection matrix on `1807`.

## 2026-08-05 STR8 `1807` Readback and Clone-Boot Closure

The continuation began in Bank 3 after a complete 32-dot timeout. One full
resident dump directly read the installed candidate. The significant edge
rows were:

```text
>D F000 FFFF
F000: 4C 13 F0 4C 24 F3 4C 40 | F3 4C 7E F4 53 52 01 07 | L..L$.L@.L~.SR..
F010: 4C 2B F3 78 D8 A2 FF 9A | 20 64 F0 20 61 F0 20 54 | L+.x.... d. a. T
...
F9F0: 53 54 52 38 2D 4E 20 56 | 20 30 30 2E 30 38 30 35 | STR8-N V 00.0805
FA00: 28 31 38 30 37 29 20 24 | 46 0D 8A 0D 0A 55 20 30 | (1807) $F....U 0
FA10: 2D 33 20 4A 30 2D 33 0D | 8A 53 54 52 38 2D 4E BE | -3 J0-3..STR8-N.
...
FFF0: FF FF FF FF FF FF FF FF | FF FF B6 F0 00 F0 CA F0 | ................
```

The board next selected B2, which still displayed the preserved
`STR8-N V 00.0805(1203) $F`. Its full dump retained the distinct `1203`
header and `BD F0 00 F0 D1 F0` vector tail. A live Bank-2 `1` then entered
the copied B1 image. B1 booted `1807`, and its independent full dump matched
the Bank-3 rows above, including the `1807` identity and
`B6 F0 00 F0 CA F0` vectors.

The remaining transitions repeatedly exercised both new clones:

```text
STR8-N V 00.0805(1807) $F
0/1/2=BOOT 3=HIMON S=STR8  ..0
J B0
BOOT IN 3S

[35 LF bytes]
................

STR8-N V 00.0805(1807) $F
0/1/2=BOOT 3=HIMON S=STR8  ................
BOOT COLD
RAM ZERO OK

HIMON V 00.0805(1312)
```

After a B2 fallback round-trip through explicit `J0`, B0 again booted `1807`.
B0 live-selected B1; B1 booted `1807`, then live-selected B0; B0 booted
`1807` once more. Every new-bank reset visibly included the 35-LF terminal
clear and completed normally.

This closes direct flash readback and the post-copy B0/B1 boot checks. The
operator additionally confirms that an early valid key was transmitted during
the unpolled first dot phase and that live `G` and `R` were transmitted; all
were ignored as required. The `1807` live-dots and warm-selector board rail is
hardware-accepted.

## 2026-08-06 STR8 V1 Bank-3 Migration Checkpoint

The first migration attempt stopped before the V1 transaction after readback
exposed the wrong input artifact. The ordinary regenerated TopWriter installed
and verified legacy `00.0806(1707)` with `TW MODE=$01 RES=$AC @=$0000`; its
`$F000` header, `B6 F0 00 F0 CA F0` vectors, and `U 0-3 J0-3` command line
identified it unambiguously. The board remained bootable. This pass also
hardware-proves the currently regenerated
`DOC/GUIDES/ASM/SAMPLES/str8n-topwrite-transient-3000.a` legacy sample.

The retry used the separate V1 migration artifact under `SRC/BUILD`. Its
recorded SHA-256 values were:

```text
909AB0AA44FB50C8EC400896E59182E67A2212062AC07635412CBF7C289E1CD0  himon-str8-v1.bin
8CA9D763A81A9F1E6DD65D346D184CF963AD512EF60CCE49D3A6F575960668FC  himon-str8-v1-install.s19
79276C789ECB419B1ECE7F07B4007EFB08FABCCE60C6A38C185A769206D2660B  str8-v1-i-bank012.s19
969FF360316D996C7CF2DA05DDEFA04428703FF3E1B740876E25C6020053260D  str8n-v1-topwrite-transient-3000.a
```

Stage, verify, program, and full-sector verify completed with
`TW MODE=$01 RES=$AC @=$0000`. Direct installed-flash reads then matched the
frozen candidate edges:

```text
1A00: 01 AC 00 00
F000: 4C 13 F0 4C 46 F7 18 60 EA 4C 19 F9 53 52 01 07
F010: 4C 4D F7 78
FF28: 4C 12 02 08 78 C9 04 B0 06 20 73 02 28 38 60 28
FFB0-FFEF: all FF
FFFA: AB F0 00 F0 BF F0
```

A physical reset booted `STR8-N V 00.0806(1707) $F`; live `S` entered the
new `I 0-3 J0-3` prompt. Bank-3 migration, packed jump-worker installation,
empty-directory installation, vectors, and reset entry are hardware-accepted.
The unmatched `?`/`G`/`R` checks, warm `3`, destructive Bank-2 journaled `I`,
`J2`, and reset-persistence checks remain pending.
