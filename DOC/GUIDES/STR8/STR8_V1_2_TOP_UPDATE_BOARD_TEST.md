# STR8-N v1.2 Top-Update Board Test

Date: 2026-08-11

Status: onboard migration path hardware-accepted. The transcript accepts the
Bank-3 `$8-$E` prerequisite install under STR8-N 1.1, `L` loading of the v1.2
RAM updater, verified backup to Bank 1 sector F, Bank-3 sector-F erase/program/
verify, physical reset-vector transfer, and live-selector entry into STR8-N
1.2.

## Captured transcript

```text
>...
BOOT COLD
RAM ZERO OK

HIMON V 00.0810(1814)
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

WAIT... WAIT... WAIT... WAIT... WAIT... WAIT...
STR8-N 1.1
0-2 H S: .S
I L H J
STR8-N>I
B0-3: 3
RANGE: 8-E
I B3 8-E WRITE? Y: Y
S19
......COMMIT? Y: Y.
OK
STR8-N>L
S19

STR8-N 1.2 TOP UPDATE
BACKUP B1:F; TARGET B3:F
TYPE BACKUP B1F> BACKUP B1F
BACKUP VERIFIED
SAFE PHY $0F000-$0FFFF; TARGET PHY $1F000-$1FFFF; SUM=$0F1E
TYPE STR8-N 1.2> STR8-N 1.2
ERASING B3:F - NO RESET/NMI/POWER
STR8-N 1.2 VERIFIED; RESET

WAIT... WAIT... WAIT... WAIT... WAIT... WAIT...
STR8-N 1.2
0-2 H S: ..S
I L H J
STR8-N>
```

## Accepted claims

- Existing STR8-N 1.1 installed the v1.2 ASM/HIMON payload into Bank 3
  `$8000-$EFFF` and committed it.
- The `L` path loaded and started the v1.2 top updater from RAM.
- The updater copied Bank-3 sector F to physical `$0F000-$0FFFF` and verified
  that backup before authorizing the active-sector erase.
- The exact `STR8-N 1.2` confirmation guarded the destructive operation.
- The updater erased, programmed, and internally verified physical
  `$1F000-$1FFFF`, then entered the new reset vector.
- The new resident completed its reset wait phases and accepted `S` during the
  live selector, displaying `STR8-N 1.2` and its `I L H J` command surface.

## Relocated-RAM follow-on transcript

The same installed image then accepted warm HIMON/ASM, `J3` and cold Bank Jump
Record preservation, the ASM `$7CFF/$7D00` boundary, and Bank Maintenance `M`:

```text
STR8-N>H
BOOT WARM

HIMON V 00.0811(1004)
>ASM
ASM-F2 00.0811(1004)
ASM>$2000: .
ASM BYE
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

WAIT... WAIT... WAIT... WAIT... WAIT... WAIT...
STR8-N 1.2
0-2 H S: .S
I L H J
STR8-N>J3
J B3

WAIT... WAIT... WAIT... WAIT... WAIT... WAIT...
STR8-N 1.2
0-2 H S: ......
BOOT COLD
RAM ZERO OK

HIMON V 00.0811(1004)
>D 7DFD 7DFF
7DFD: 42 4A 03 | BJ.
>D 7D00 7D02
7D00: 00 00 00 | ...
>ASM NEW
ASM-F2 00.0811(1004)
ASM>$2000: ORG $7CFD
ASM>$7CFD: DB $11,$22,$33
ASM>$7D00: .
ASM BYE
>D 7CFD 7CFF
7CFD: 11 22 33 | ."3
>D 7D00 7D02
7D00: 00 00 00 | ...
>ASM NEW
ASM-F2 00.0811(1004)
ASM>$2000: ORG $7CFF
ASM>$7CFF: DB $A5,$5A
ERR=$06 BAD RANGE PC=$7CFF
ASM>$7CFF: .
ASM BYE
#56AD7400# EXEC ERR=$06
>D 7CFF
7CFF: 33 | 3
>D 7D00
7D00: 00 | .
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

WAIT... WAIT... WAIT... WAIT... WAIT... WAIT...
STR8-N 1.2
0-2 H S: .S
I L H J
STR8-N>L
S19

STR8-N 1.1 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY+DIR E=ERASE M=MAP+DIR P=AP B0BF00 Q=QUIT> M

BANK 8 9 A B C D E F

B0 U U U U U U U U
B1 E E E E E E E U
B2 E E E E E E E E
B3 U U U U U U U P
E=ERASED U=USED A=AP VALID P=B3F PROTECTED

DIR B T DESC ENTRY JOURNAL
D0 F0 TEST0 FFFF FCFFFFFF
D1 FE TEST1 FFFF FEFFFFFF
D2 F8 TEST2 FFFF FCFFFFFF
D3 FF RYORS C000 C0FFFFFF
 OK

STR8-N 1.1 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY+DIR E=ERASE M=MAP+DIR P=AP B0BF00 Q=QUIT> Q

WAIT... WAIT... WAIT... WAIT... WAIT... WAIT...
STR8-N 1.2
0-2 H S: ..H
BOOT WARM

HIMON V 00.0811(1004)
>D 7DC0 7DC7
7DC0: 00 00 00 00 00 00 00 00 | ........
>
```

The `STR8-N 1.1 BANK MAINT` text is a stale banner in the otherwise v1.2
relocated tool; its successful map proves the `$7C00-$7D1A` runtime path. The
banner was corrected after this run and the rebuilt v1.2 S19 is
`0EB33A64D36EAC4EFF7BA9C64A6DBE24BA81EC38A8BB91540898C6AE7445FB3F`.

## AP-link scratch and low-user-RAM canaries

The next hardware session built an importing AP package in RAM, applied it at
`$3000`, and executed it. `AP` relocated the call operand to `$E6EC`, execution
returned `$AC` with carry set, and the complete HIMON import-link record at
`$7DC0-$7DC7` was `06 0F 30 EC E6 04 05 01`. This accepts the relocated
HIMON AP-link scratch through the real `IMPORT`/`PACKAGE`/`AP`/`RJOIN` path.

The same session wrote eight distinct canaries spanning `$1A00-$1FFF` and
verified them immediately, after the AP-link operation, and after ASM emitted
three bytes at `$7CFD-$7CFF`. Every check returned `$AC` with carry set and
left the fixture status at `$71F0-$71F1` as `AC FF`:

```text
>ASM NEW
ASM-F2 00.0811(1004)
ASM>$2000: ; STR8N-V1.2-AP-LINK-SMOKE-2000.A
ASM>$2000: ; RAM-ONLY IMPORT/RJOIN AP TEST. DOES NOT WRITE FLASH.
ASM>$2000:
ASM>$2000:         ORG $2000
ASM>$2000:
ASM>$2000:         IMPORT BIO_FTDI_PUT_CSTR
ASM>$2000:
ASM>$2000: MAIN    BRA RUN
ASM>$2002:         ENTRY MAIN
ASM>$2002:
ASM>$2002: RUN     LDX #<MSG
ASM>$2004:         LDY #>MSG
ASM>$2006:         JSR BIO_FTDI_PUT_CSTR
ASM>$2009:         LDA #<BIO_FTDI_PUT_CSTR
ASM>$200B:         STA $584A
ASM>$200E:         LDA #>BIO_FTDI_PUT_CSTR
ASM>$2010:         STA $584B
ASM>$2013:         LDA #$AC
ASM>$2015:         STA $5848
ASM>$2018:         SEC
ASM>$2019:         RTS
ASM>$201A: MSG     DB $0D,$0A,'B','A','N','K',' '
ASM>$2021:         DB 'R','J','O','I','N',$0D,$0A,0
ASM>$2029:         END
ASM OK
SEAL> PACKAGE $4000
PKG OK @=$4000 L=$0076
SEAL> .
ASM BYE
>AP $4000 $3000
GO 3000

BANK RJOIN

#GO# ENTRY=3000
RET A=AC X=1A Y=0E P=F5 S=FD NV-BdIzC
>D 5848
5848: AC | .
>D 584A 584B
584A: EC E6 | ..
>D 3006 3008
3006: 20 EC E6 |  ..
>D 7DC0 7DC7
7DC0: 06 0F 30 EC E6 04 05 01 | ..0.....
>ASM NEW
ASM-F2 00.0811(1004)
ASM>$2000: ; STR8N-V1.2-LOW-USER-CANARY-7000.A
ASM>$2000: ; EXPLICIT TEST FIXTURE FOR USER-FREE $1A00-$1FFF.
ASM>$2000: ; G 7000 SETS CANARIES.
ASM>$2000: ; G 7003 CHECKS CANARIES.
ASM>$2000:
ASM>$2000:         ORG $7000
ASM>$7000:
ASM>$7000: SETENT  JMP CSETV
ASM>$7003: CHKENT  JMP CCHK
ASM>$7006:
ASM>$7006: CSETV   LDA #$A1
ASM>$7008:         STA $1A00
ASM>$700B:         LDA #$AF
ASM>$700D:         STA $1AFF
ASM>$7010:         LDA #$B1
ASM>$7012:         STA $1B00
ASM>$7015:         LDA #$C1
ASM>$7017:         STA $1C00
ASM>$701A:         LDA #$D1
ASM>$701C:         STA $1D00
ASM>$701F:         LDA #$E1
ASM>$7021:         STA $1E00
ASM>$7024:         LDA #$FE
ASM>$7026:         STA $1FFE
ASM>$7029:         LDA #$FF
ASM>$702B:         STA $1FFF
ASM>$702E:         LDA #$AC
ASM>$7030:         STA $71F0
ASM>$7033:         LDA #$FF
ASM>$7035:         STA $71F1
ASM>$7038:         LDA #$AC
ASM>$703A:         SEC
ASM>$703B:         RTS
ASM>$703C:
ASM>$703C: CCHK    LDX #$00
ASM>$703E:         LDA $1A00
ASM>$7041:         CMP #$A1
ASM>$7043:         BNE CFAIL
ASM>$7045:         INX
ASM>$7046:         LDA $1AFF
ASM>$7049:         CMP #$AF
ASM>$704B:         BNE CFAIL
ASM>$704D:         INX
ASM>$704E:         LDA $1B00
ASM>$7051:         CMP #$B1
ASM>$7053:         BNE CFAIL
ASM>$7055:         INX
ASM>$7056:         LDA $1C00
ASM>$7059:         CMP #$C1
ASM>$705B:         BNE CFAIL
ASM>$705D:         INX
ASM>$705E:         LDA $1D00
ASM>$7061:         CMP #$D1
ASM>$7063:         BNE CFAIL
ASM>$7065:         INX
ASM>$7066:         LDA $1E00
ASM>$7069:         CMP #$E1
ASM>$706B:         BNE CFAIL
ASM>$706D:         INX
ASM>$706E:         LDA $1FFE
ASM>$7071:         CMP #$FE
ASM>$7073:         BNE CFAIL
ASM>$7075:         INX
ASM>$7076:         LDA $1FFF
ASM>$7079:         CMP #$FF
ASM>$707B:         BNE CFAIL
ASM>$707D:         LDA #$AC
ASM>$707F:         STA $71F0
ASM>$7082:         LDA #$FF
ASM>$7084:         STA $71F1
ASM>$7087:         LDA #$AC
ASM>$7089:         SEC
ASM>$708A:         RTS
ASM>$708B:
ASM>$708B: CFAIL   STX $71F1
ASM>$708E:         LDA #$E0
ASM>$7090:         STA $71F0
ASM>$7093:         CLC
ASM>$7094:         RTS
ASM>$7095: .
ASM BYE
>G 7000
GO 7000

#GO# ENTRY=7000
RET A=AC X=30 Y=30 P=F5 S=FD NV-BdIzC
>D 1A00
1A00: A1 | .
>D 1AFF 1B00
1AFF: AF B1 | ..
>D 1C00
1C00: C1 | .
>D 1D00
1D00: D1 | .
>D 1E00
1E00: E1 | .
>D 1FFE 1FFF
1FFE: FE FF | ..
>D 71F0 71F1
71F0: AC FF | ..
>G 7003
GO 7003

#GO# ENTRY=7003
RET A=AC X=07 Y=30 P=F5 S=FD NV-BdIzC
>D 71F0 71F1
71F0: AC FF | ..
>ASM NEW
ASM-F2 00.0811(1004)
ASM>$2000: ORG $7CFD
ASM>$7CFD: DB $44,$55,$66
ASM>$7D00: .
ASM BYE
>G 7003
GO 7003

#GO# ENTRY=7003
RET A=AC X=07 Y=30 P=F5 S=FD NV-BdIzC
>D 71F0 71F1
71F0: AC FF | ..
```

## Integrated Bank Maintenance canary pass

The final non-destructive relocation leg loaded the corrected v1.2 Bank
Maintenance artifact, ran its complete read-only map, returned with `Q`, and
selected `H` during the live STR8-N selector. HIMON reported `BOOT WARM`, and
the low-user-RAM checker still returned `$AC` with carry set and status
`AC FF`. The empty Bank-3 response to the accidental preceding `I` command
reported `BAD` and made no change.

```text
>STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y

WAIT... WAIT... WAIT... WAIT... WAIT... WAIT...
STR8-N 1.2
0-2 H S: .S
I L H J
STR8-N>I
B0-3:
BAD
STR8-N>L
S19

STR8-N 1.2 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY+DIR E=ERASE M=MAP+DIR P=AP B0BF00 Q=QUIT> M

BANK 8 9 A B C D E F

B0 U U U U U U U U
B1 E E E E E E E U
B2 E E E E E E E E
B3 U U U U U U U P
E=ERASED U=USED A=AP VALID P=B3F PROTECTED

DIR B T DESC ENTRY JOURNAL
D0 F0 TEST0 FFFF FCFFFFFF
D1 FE TEST1 FFFF FEFFFFFF
D2 F8 TEST2 FFFF FCFFFFFF
D3 FF RYORS C000 C0FFFFFF
 OK

STR8-N 1.2 BANK MAINT
B3 ERASE RETURNS TO STR8; SELECT S
!STR8=SOURCE HAS STR8
C=COPY+DIR E=ERASE M=MAP+DIR P=AP B0BF00 Q=QUIT> Q

WAIT... WAIT... WAIT... WAIT... WAIT... WAIT...
STR8-N 1.2
0-2 H S: .H
BOOT WARM

HIMON V 00.0811(1004)
>G 7003
GO 7003

#GO# ENTRY=7003
RET A=AC X=07 Y=30 P=F5 S=FD NV-BdIzC
>D 71F0 71F1
71F0: AC FF | ..
```

## Still open

This transcript does not independently identify the transferred files by
SHA-256 and does not close every v1.2 release gate. Retain separate evidence
for an external full-sector readback, `J0`-`J2`, destructive Bank Maintenance
operations, and external-programmer/Bank-1 restore. The AP import-link RAM ABI
and the low-user-RAM canaries through ASM/AP activity, corrected v1.2 Bank
Maintenance `M`/`Q`, and live-selector warm `H` are accepted. The
non-destructive RAM-relocation test set is complete. None of the remaining
broader release checks weakens the accepted relocation, onboard update, and
reset results.
