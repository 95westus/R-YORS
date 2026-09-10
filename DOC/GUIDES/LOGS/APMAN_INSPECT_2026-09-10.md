# APMAN Read-Only Carrier Inspection — 2026-09-10

Status: accepted on the physical W65C02 board through COM4.

## Accepted artifacts

```text
APMAN AP package       $0C23  SHA256 87C25EC963F8B7F7A844DF0FAD39D9B70BBE4046EE2FDBB3F4DE27E7C785D4B5
APMAN dense BIN        $1000  SHA256 3E1E04848ACFB838CC2069239DD3155249F78EFC5D5D52912B6E2DFCDBD494DB
APMAN dense S19               SHA256 4D6FBFBA9A256879B93BCB4443EF28F5AE741E29CF52650B54CAEEC2EF0A1920
HIMON B3:C-E S19              SHA256 EB071862909545D6B07B27C36416454F69A0FB127A6079E3767A26FE17E606D0
raw JSONL capture             SHA256 90E879B4EC435F141150821F5CC8BCF05E000936132025C590D6352EB844982E
```

The raw append-only capture is
`C:\SRC\STR8-N\BUILD\v1.32\local\apman-inspect-board-20260910.jsonl`.

The initial APMAN-only attempt installed and verified B2:8 but exposed an
integration gap before any inspection ran:

```text
AP D B2 APMAN
AP pkg dst | AP [L] Bn name|s000 [dst]
>
```

HIMON had forwarded only `B` and `L` forms to APMAN. The correction adds `D`
to that same front door and advertises `[L|D]`; the strengthened host check
requires this route. With explicit operator approval, STR8-N installed the
matched HIMON image only into B3:C-E:

```text
STR8-N>I
B0-3: 3
RANGE: C-E
I B3 C-E WRITE? Y: Y
S19
..COMMIT? Y: Y.
OK
STR8-N>W
BOOT WARM

HIMON V 00.0910(1343)
>
```

## Positive inspection

Both `AP D B2 APMAN` and `AP D B2 8000` printed the same validated result:

The section rows retain canonical **SREIB** order—Seal, Relocations, Exports,
Imports, Body—pronounced approximately “shrybe” after German *schreib*
(“write”). This is documentation terminology only; no envelope tag or byte
order changed.

```text
APD B2 8000 APC APMAN L=0C23 @7000
S 0005-0012
R 0013-0016
E 0017-0026
I 0027-002A
B 002B-0C22
0000: 41 50 02 23 0C 53 0B 00 01 00 70 F5 7B F5 0B 8E
0010: C3 D1 91 52 01 00 00 45 0D 00 01 81 00 00 20 86
0020: 16 9A 05 CD 08 70 08 49 01 00 00 42 F5 0B 80 04
0030: 41 4D 30 31 9C 61 7C 9C 6E 7C AD 60 7C C9 01 F0
>
```

There were exactly four 16-byte rows, no bytes after `$003F`, and no
`AP LOAD`, `GO`, or child-manager execution.

## Rejection rails

```text
AP D B2 NO_SUCH_AP
APMAN ERR=$D1
>AP D B2 8FFF
APMAN ERR=$D1
>AP D B3 APMAN
APMAN ERR=$D0
>AP D B2 APMAN 2000
APMAN ERR=$D0
>
```

Each rejection returned once with no dump. No approved malformed or duplicate
carrier fixture was present in the `APS` inventory, so the card's optional
fixture cases were not run.

## Regression and immutability

`APS` reported B1:8 `BANKAUDIT`, the reserved B1:E/B1:F roles, and B2:8
`APMAN L=0C23`. `AP L B1 BANKAUDIT` loaded without running; ordinary
`AP B1 BANKAUDIT` executed and restored Bank 3.

The complete pre-install table was:

```text
B0 8=5579 9=D507 A=ACD0 B=EFDF C=EFDF D=EFDF E=EFDF F=D007
B1 8=FA1C 9=0FE1 A=0FE1 B=0FE1 C=0FE1 D=0FE1 E=0FE1 F=1336
B2 8=60CF 9=0FE1 A=0FE1 B=0FE1 C=0FE1 D=0FE1 E=0FE1 F=0FE1
B3 8=BBBC 9=2029 A=A504 B=F4C2 C=7909 D=4900 E=3A2C F=516B
BANKAUDIT OK; B3 RESTORED
```

Across the two approved installs, only APMAN B2:8, HIMON B3:C-E, and STR8-N's
B3:F directory journal changed. No other sector CRC moved.

The complete baseline taken after both approved installations was:

```text
B0 8=5579 9=D507 A=ACD0 B=EFDF C=EFDF D=EFDF E=EFDF F=D007
B1 8=FA1C 9=0FE1 A=0FE1 B=0FE1 C=0FE1 D=0FE1 E=0FE1 F=1336
B2 8=77D3 9=0FE1 A=0FE1 B=0FE1 C=0FE1 D=0FE1 E=0FE1 F=0FE1
B3 8=BBBC 9=2029 A=A504 B=F4C2 C=9CDB D=3364 E=19A6 F=5F3A
BANKAUDIT OK; B3 RESTORED
```

The same table appeared after the positive inspections, all rejections,
`APS`, `AP L`, ordinary named `AP`, and a physical reset. The reset returned:

```text
BOOT WARM

HIMON V 00.0910(1343)
>
```

Result: the matched HIMON/APMAN command is hardware-accepted. The inspection
phase made no flash or directory change, and every bank-selection path restored
Bank 3.
