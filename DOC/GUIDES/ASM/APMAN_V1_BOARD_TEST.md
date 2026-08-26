# APMAN V1 First Carrier Board Test

Status: host candidate. Do not treat this card as hardware proof until the
complete sequence and preservation checks pass on the board.

This is the shortest complete proof:

```text
ASM NEW -> PACKAGE -> INSTALL into flash -> RESET -> APS -> AP by name
```

## Exact files

```text
Initial APMAN carrier for Bank 2 sector 8
C:\SRC\R-YORS\RELEASE\ARTIFACTS\COMPONENT-IMAGES\apman-v1-bank2-8000.s19

Candidate HIMON + ASM-F2 Bank-3 sectors 8-E
C:\SRC\R-YORS\RELEASE\ryors-v1.2-himon-asm-bank3-8-e.s19

Onboard BANKAUDIT source
C:\SRC\R-YORS\RELEASE\ARTIFACTS\SOURCES\bank-audit-2000.a
```

## 1. Install APMAN once at B2:8

Enter STR8-N, select install, and answer exactly:

```text
STR8
I
B0-3: 2
RANGE: 8
I B2 8 WRITE? Y: Y
S19
```

Send this file when STR8-N is waiting for S19:

```text
C:\SRC\R-YORS\RELEASE\ARTIFACTS\COMPONENT-IMAGES\apman-v1-bank2-8000.s19
```

Then confirm:

```text
COMMIT? Y: Y
```

Expected end: `OK`. This deliberately consumes the whole B2:8 carrier sector;
do not combine it with another B2:8 image.

## 2. Install the candidate HIMON and ASM-F2

Still in STR8-N, select install and answer:

```text
I
B0-3: 3
RANGE: 8-E
I B3 8-E WRITE? Y: Y
S19
```

Send:

```text
C:\SRC\R-YORS\RELEASE\ryors-v1.2-himon-asm-bank3-8-e.s19
```

Then:

```text
COMMIT? Y: Y
RESET
```

At HIMON, prove discovery before assembling anything:

```text
APS B2
APS B2 APMAN
```

Expected: one valid `APC APMAN` row at `B2 8000`, with an envelope length of
`$0B04` for this candidate.

## 3. Assemble, package, and install BANKAUDIT

At HIMON:

```text
ASM NEW
```

Send exactly:

```text
C:\SRC\R-YORS\RELEASE\ARTIFACTS\SOURCES\bank-audit-2000.a
```

After `ASM OK` and the automatic `SEAL>` prompt, type:

```text
PACKAGE BANKAUDIT $3000
INSTALL 3000 B1
```

`B1` is the confirmation. APMAN selects the first full erased and unreserved
sector, programs it, verifies it, restores Bank 3, and prints a line shaped:

```text
INST B1 A000 L=hhhh
```

The sector may differ; write down the printed address. Do not run Bank
Maintenance `P`, do not load a helper, and do not type `G`.

Exit ASM and reset:

```text
.
RESET
```

## 4. List and run the persistent carrier

At the cold/warm-booted HIMON prompt:

```text
APS B1
APS B1 BANKAUDIT
AP B1 BANKAUDIT
```

Expected utility output shape:

```text
BANKAUDIT CRC16/4K
B0 8=hhhh 9=hhhh A=hhhh B=hhhh C=hhhh D=hhhh E=hhhh F=hhhh
B1 8=hhhh 9=hhhh A=hhhh B=hhhh C=hhhh D=hhhh E=hhhh F=hhhh
B2 8=hhhh 9=hhhh A=hhhh B=hhhh C=hhhh D=hhhh E=hhhh F=hhhh
B3 8=hhhh 9=hhhh A=hhhh B=hhhh C=hhhh D=hhhh E=hhhh F=hhhh
BANKAUDIT OK; B3 RESTORED
```

The monitor return must show `A=AC` with carry set. Run `APS B1` once more;
the carrier must still list with the same name, address, and length.

## Optional address and load-only checks

Replace `A000` with the sector printed by `INSTALL`:

```text
AP L B1 BANKAUDIT
AP L B1 A000
AP B1 A000
```

The two `AP L` commands must report a load but must not print BANKAUDIT's CRC
rows. The final address form must run the same program as the name form.
