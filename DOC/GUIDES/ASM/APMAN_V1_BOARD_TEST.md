# APMAN V1 Board Preparation and First Carrier Test

Status: host candidate. This card is destructive to all of Bank 2 and D2.
Do not mark APMAN hardware-proven until every required checkpoint below passes.

The intended cycle is:

```text
erase B2 -> clear D2 -> enroll B2 as APC storage -> install APMAN
-> update B3:8-E -> reset -> ASM NEW -> package -> install -> reset -> AP
```

## Exact files

```text
Bank Maintenance menu (load this first)
C:\SRC\R-YORS\RELEASE\ARTIFACTS\COMPONENT-IMAGES\str8n-v1.23-bank-maint-menu-2000.s19

Dense APMAN carrier for Bank 2 sector 8
C:\SRC\R-YORS\RELEASE\ARTIFACTS\COMPONENT-IMAGES\apman-v1-bank2-8000.s19

Candidate HIMON + ASM-F2 Bank-3 sectors 8-E
C:\SRC\R-YORS\RELEASE\ryors-v1.2-himon-asm-bank3-8-e.s19

Onboard BANKAUDIT source used after the update
C:\SRC\R-YORS\RELEASE\ARTIFACTS\SOURCES\bank-audit-2000.a
```

The APMAN S19 is exactly `$8000-$8FFF`, including its erased `$FF` tail. The
corrected carrier is `$0B40` bytes. Do not use the earlier `$0B09` carrier or
any short APMAN S19 whose last data address is near `$8B08`.

## Correction card after the 00.0826(1510) first-board run

The first-board run proved installation and resident APS discovery, then
exposed two defects: Bank Maintenance displayed a valid AP-v2 carrier as `U`,
and APMAN recursively executed itself. The corrected external APMAN fails that
command once with `$DB`; the corrected Bank Maintenance menu displays the
carrier as `A`. Neither correction changes resident HIMON, ASM-F2, STR8-N, the
directory, or B3. Do not rewrite B3:8-E or B3:F for this correction.

At HIMON, enter STR8-N and load this exact corrected menu:

```text
> STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y
STR8-N>L
S19
```

Send:

```text
C:\SRC\R-YORS\RELEASE\ARTIFACTS\COMPONENT-IMAGES\str8n-v1.23-bank-maint-menu-2000.s19
```

Erase only the old APMAN sector:

```text
BM> E
BANK 0-3> 2
SECTOR 8-F, ALL, OR X-Y; B3 MAX E> 8
TYPE ERASE 28> ERASE 28
. OK
RESET
```

At STR8-N, reinstall the corrected dense carrier. D2 is already enrolled, so
there are no `TYPE` or `DESC` questions:

```text
STR8-N>I
B0-3: 2
RANGE: 8
I B2 8-8 WRITE? Y: Y
S19
```

Send:

```text
C:\SRC\R-YORS\RELEASE\ARTIFACTS\COMPONENT-IMAGES\apman-v1-bank2-8000.s19
```

Finish the write:

```text
COMMIT? Y: Y.
OK
```

Reload the corrected Bank Maintenance menu, then verify:

```text
BM> M
```

Required B2 row and envelope line:

```text
B2 A E E E E E E E
AP ENVELOPES
AP B2 8000 L0B40
OK
```

Reset to HIMON and run these exact checks:

```text
> APS B2 APMAN
APS B2 8000 APC APMAN L=0B40 @7000
> AP B2 APMAN 2000
APMAN ERR=$DB
```

`AP B2 APMAN 2000` is deliberately invalid: APMAN is the manager, not an
ordinary application. It must print no `AP LOAD` and no `GO`, and it must
return immediately to one HIMON prompt. Continue at section 8 only after all
of these corrected checkpoints pass.

## 1. Enter STR8-N and load Bank Maintenance

At HIMON, type:

```text
> STR8
RUN STR8: BOOTLOADER @F000 K=03 ? y
```

Do not let the short selector timeout expire. Expected menu:

```text
STR8-N 1.23
0-2 C W S: <current directory initials>
I L C W J
STR8-N>
```

At that STR8-N prompt, immediately type:

```text
STR8-N>L
S19
```

When the terminal is waiting for the S19, send this exact file:

```text
C:\SRC\R-YORS\RELEASE\ARTIFACTS\COMPONENT-IMAGES\str8n-v1.23-bank-maint-menu-2000.s19
```

Do not type `G`. STR8-N runs the S9 `$2000` entry automatically. Expected:

```text
STR8-N 1.23 BANK MAINT + TOP
M  MAP+DIR
C  COPY+ENROLL
D  ADOPT DIR
N  RENAME DIR
R  RECLAIM DIR
E  ERASE BANK RANGE
P  PUT AP $7000 -> BANK SECTOR
U  UPDATE B3:F (BACKUP B1:F; RESET)
?  MENU
Q/ENTER  RETURN TO STR8-N
BM>
```

## 2. Record the destructive-operation baseline

Type:

```text
BM> M
```

Save this output. Confirm that only B2 is being discarded. The exact B0, B1,
and B3 rows depend on earlier board work; do not erase any of them in this
pass. The pre-erase D2 row is expected to be the old `SPARE` row:

```text
D2 F2 SPARE FFFF FCFFFFFF
```

If D2 is already all `$FF`, the later `R 2` command reports `DIR EMPTY`
instead of asking for `CLEAR D2`; that is already the desired state.

## 3. Erase all eight B2 sectors

Type each answer exactly:

```text
BM> E
BANK 0-3> 2
SECTOR 8-F, ALL, OR X-Y; B3 MAX E> ALL
TYPE ERASE 2ALL> ERASE 2ALL
```

Expected completion:

```text
........ OK
```

There must be eight dots. Stop on `!`, `PROTECTED ROLE`, reset, or any other
result.

## 4. Clear/reset D2

Type:

```text
BM> R
RECLAIM DIR 0-3> 2
```

For the old D2 row, expected prompt and exact confirmation are:

```text
B3F REWRITE
TYPE CLEAR D2> CLEAR D2
BACKUP VERIFIED
 OK
```

This temporarily backs up B3:F in B2:F, rewrites and verifies B3:F with D2
cleared, and finally erases/verifies B2:F again. Do not reset or remove power
between `CLEAR D2` and ` OK`.

If D2 was already empty, the acceptable alternate result is:

```text
DIR EMPTY
 OK
```

Now type:

```text
BM> M
```

The required lines are:

```text
B2 E E E E E E E E
D2 FF ..... FFFF FFFFFFFF
```

`M` must finish with ` OK`. B0, B1, D0, D1, B3, and D3 must match the saved
baseline. Physically reset the board after this checkpoint.

## 5. Enroll B2 as APC storage and install APMAN at B2:8

At STR8-N, type each answer exactly:

```text
STR8-N>I
B0-3: 2
RANGE: 8
TYPE: A2
DESC: APC02
I B2 8-8 WRITE? Y: Y
S19
```

Send this exact dense file:

```text
C:\SRC\R-YORS\RELEASE\ARTIFACTS\COMPONENT-IMAGES\apman-v1-bank2-8000.s19
```

At the end of the transfer, type the final `Y`:

```text
COMMIT? Y: Y.
OK
```

The dot appears only after B2:8 programs and verifies. D2 is now expected to
be:

```text
D2 A2 APC02 FFFF FCFFFFFF
```

Bank 2 is APC storage, not a bootable bank: do not select `2` at the STR8-N
boot selector and do not use `J2`.

## 6. Install the candidate HIMON and ASM-F2 at B3:8-E

Still in STR8-N, type:

```text
STR8-N>I
B0-3: 3
RANGE: 8-E
I B3 8-E WRITE? Y: Y
S19
```

Send:

```text
C:\SRC\R-YORS\RELEASE\ryors-v1.2-himon-asm-bank3-8-e.s19
```

Expected transfer ending; type the shown final `Y`:

```text
......COMMIT? Y: Y.
OK
```

There are six dots before `COMMIT` and the seventh after confirmation. Then
physically reset the board. Expected boot ending:

```text
BOOT WARM

HIMON V 00.0826(1544)
>
```

`1544` is the visible stamp in this exact published candidate. Stop if the
board still prints the older `00.0826(1059)` image after the update.

## 7. Prove APMAN discovery before assembling anything

Type:

```text
> APS B2
```

Expected complete result:

```text
APS B2 8000 APC APMAN L=0B40 @7000
```

Then type:

```text
> APS B2 APMAN
```

Expected complete result is the same single detail line:

```text
APS B2 8000 APC APMAN L=0B40 @7000
```

Stop here and report the transcript if either command prints an error, no
line, a joined `8000APC`, a different package name, or a different length.

## 8. Assemble, package, and install BANKAUDIT

At HIMON type:

```text
> ASM NEW
```

Send exactly this one source file:

```text
C:\SRC\R-YORS\RELEASE\ARTIFACTS\SOURCES\bank-audit-2000.a
```

The paste must end with:

```text
ASM OK
SEAL>
```

At `SEAL>`, type these two commands. `B1` is part of the second command; there
is no later confirmation prompt.

```text
SEAL> PACKAGE BANKAUDIT $3000
PKG OK @=$3000 L=$0294
SEAL> INSTALL 3000 B1
INST B1 A000 L=0294
SEAL>
```

`A000` is expected on the captured board because B1:A is the first erased,
unreserved sector. If APMAN prints a different sector, record it and do not
substitute `A000` later. Both package lengths must be exactly `$0294`.

Do not use Bank Maintenance `P`, do not load a helper, and do not type `G`.
Exit ASM and physically reset:

```text
SEAL> .
ASM BYE
RESET
```

## 9. List and run BANKAUDIT after reset

At the rebooted HIMON prompt, type:

```text
> APS B1 BANKAUDIT
```

Expected shape, using the address and length printed by `INSTALL`:

```text
APS B1 A000 APC BANKAUDIT L=0294 @2000
```

Then type:

```text
> AP B1 BANKAUDIT
```

Expected output:

```text
AP LOAD B1 A000 -> 2000
GO 2000
BANKAUDIT CRC16/4K
B0 8=hhhh 9=hhhh A=hhhh B=hhhh C=hhhh D=hhhh E=hhhh F=hhhh
B1 8=hhhh 9=hhhh A=hhhh B=hhhh C=hhhh D=hhhh E=hhhh F=hhhh
B2 8=hhhh 9=hhhh A=hhhh B=hhhh C=hhhh D=hhhh E=hhhh F=hhhh
B3 8=hhhh 9=hhhh A=hhhh B=hhhh C=hhhh D=hhhh E=hhhh F=hhhh
BANKAUDIT OK; B3 RESTORED

#GO# ENTRY=2000
RET A=AC ... C
```

The CRC values and unchanged register fields are board-specific. Acceptance
requires all 32 CRC fields, `BANKAUDIT OK; B3 RESTORED`, `A=AC`, and carry set
(`C` at the right of HIMON's flags). Finally repeat:

```text
> APS B1 BANKAUDIT
```

It must report the same address and length after the run.

## Optional load-only and address checks

Replace `A000` below if `INSTALL` selected another sector:

```text
> AP L B1 BANKAUDIT
AP LOAD B1 A000 -> 2000

> AP L B1 A000
AP LOAD B1 A000 -> 2000

> AP B1 A000
AP LOAD B1 A000 -> 2000
GO 2000
```

The two `AP L` commands load and fix up metadata but do not execute BANKAUDIT.
The final address form executes the same carrier as the name form.
