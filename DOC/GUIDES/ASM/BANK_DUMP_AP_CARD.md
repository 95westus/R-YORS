# BANKDUMP Banked APC Utility

Status: corrected `$0597` carrier and APMAN-header mode are board-proven.
Separate page mode and corrected all-pages safe-quit checks remain open.

`BANKDUMP` is the read-only physical-flash inspection APC. It selects one
Bank 0-3 sector, copies all 4K to `$4000-$4FFF`, restores Bank 3, calculates
CRC-16/CCITT-FALSE, and then displays only the staged RAM copy. It contains no
flash erase/program path.

The three modes are:

- `H`: decode an AP-v2 envelope at the sector base and dump its first 256
  bytes.
- `P`: dump one selected 256-byte page, `0-F`.
- `A`: dump all 16 pages, pausing after each page; `Q` stops safely.

## Exact files

```text
Onboard ASM-F2 source
C:\SRC\R-YORS\RELEASE\ARTIFACTS\SOURCES\bank-dump-2000.a

Host-built counterpart
C:\SRC\R-YORS\RELEASE\ARTIFACTS\SOURCES\bank-dump-2000.asm

Direct RAM-load S19
C:\SRC\R-YORS\RELEASE\ARTIFACTS\COMPONENT-IMAGES\bank-dump-2000.s19
```

The host body occupies `$2000-$2515`, `$0516` bytes, with FNV32
`$2CB2A3ED`. The onboard AP-v2 package has three import relocations and exact
length `$0597`.

`BANKDUMP` is deliberately fixed at its sealed `$2000` base. Run it by name
without a destination override. Its HIMON console imports remain dynamically
linked, but its internal calls and data pointers are generated from and
checked against the host `$2000` map.

Do not enter `G 2000` on the raw ASM-F2 body. Its imports are unresolved until
`PACKAGE` and the named `AP` load link them. At `SEAL>`, use only the package,
install, and exit commands shown below.

## Install on the current board

The first board card contained three quoted semicolons that ASM-F2 treated as
comments. It installed a shortened, invalid `$0564` carrier at B2:9. Remove
that copy before installing the corrected `$0597` carrier. No STR8-N, HIMON,
ASM, APMAN, directory, or Bank-3 update is needed.

At the current Bank Maintenance `BM>` prompt enter:

```text
E
BANK 0-3> 2
SECTOR 8-F, ALL, OR X-Y; B3 MAX E> 9
TYPE ERASE 29> ERASE 29
```

Require:

```text
. OK
```

Then enter:

```text
Q
RESET
APS B2
```

B2:9 must no longer be listed as `BANKDUMP`.

At HIMON:

```text
ASM NEW
```

Send this one complete file:

```text
C:\SRC\R-YORS\RELEASE\ARTIFACTS\SOURCES\bank-dump-2000.a
```

This is the corrected card. Do not reuse the earlier pasted `$0564` source.

At `SEAL>` enter exactly:

```text
PACKAGE BANKDUMP $3000
INSTALL 3000 B2
.
```

Expected package/install lines for the current board are:

```text
PKG OK @=$3000 L=$0597
INST B2 9000 L=0597
... OK
ASM BYE
```

Reset and prove named discovery:

```text
RESET
APS B2 BANKDUMP
```

Expected:

```text
APS B2 9000 APC BANKDUMP L=0597 @2000
```

## Test 1: inspect APMAN itself

Enter the command with `A` in the first column:

```text
AP B2 BANKDUMP
```

Then answer:

```text
BANK 0-3> 2
SECTOR 8-F> 8
H=APC HEADER P=PAGE A=ALL Q=QUIT> H
```

The current proven APMAN carrier should begin:

```text
BANKDUMP B2:8000 CRC16=60CF
APC V=02 PKG=0B40 BASE=7000 END=7B12 BODY=0B12 FNV=421C7515

8000: 41 50 02 40 0B 53 0B 00 01 00 70 12 7B 12 0B 15 |AP.@.S....p.{...|
8010: 75 1C 42 52 01 00 00 45 0D 00 01 81 00 00 20 86 |u.BR...E...... .|
...
80F0: B0 03 4C 4A 78 20 09 78 A0 00 B1 A0 F0 03 4C 4A |..LJx .x......LJ|

BANKDUMP OK; B3 RESTORED
```

The 16 raw rows are the complete first 256 bytes; the card abbreviates only
the middle rows. The decoded line and CRC are exact for the currently proven
`$0B40` B2:8 APMAN image.

This test passed on 2026-08-26 with the corrected `$0597` B2:9 carrier after a
warm reset. Named discovery, load, execution, the exact decoded APMAN fields,
CRC `$60CF`, completion text, and Bank-3 restoration all matched this card.

## Test 2: one page

```text
AP B2 BANKDUMP
BANK 0-3> 1
SECTOR 8-F> C
H=APC HEADER P=PAGE A=ALL Q=QUIT> P
PAGE 0-F> 0
```

Expected shape for the installed BANKAUDIT carrier:

```text
BANKDUMP B1:C000 CRC16=FA1C
C000: 41 50 02 99 02 ...
...
C0F0: ...

BANKDUMP OK; B3 RESTORED
```

## Test 3: whole-sector paging and safe quit

```text
AP B2 BANKDUMP
BANK 0-3> 2
SECTOR 8-F> F
H=APC HEADER P=PAGE A=ALL Q=QUIT> A
```

After the first 16 rows:

```text
-- MORE (ENTER=NEXT, Q=QUIT)> Q

BANKDUMP QUIT; NO FLASH WRITE
```

Success returns `A=$AC`, carry set. A deliberate `Q` returns `A=$E0`, carry
clear. A staging/restore failure prints `BANKDUMP E1`, returns `A=$E1`, carry
clear, and attempts Bank-3 restoration before returning.
