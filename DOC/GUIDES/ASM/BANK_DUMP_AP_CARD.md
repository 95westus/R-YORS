# BANKDUMP Banked APC Utility

Status: accepted on board. The symbol-lean `$09AD` read-only bank-map
extension assembled, packaged, installed at B2:9, survived reset, resolved by
name, printed the complete map, and restored Bank 3.

`BANKDUMP` is the read-only physical-flash inspection APC. It selects one
Bank 0-3 sector, copies all 4K to `$4000-$4FFF`, restores Bank 3, calculates
CRC-16/CCITT-FALSE, and then displays only the staged RAM copy. It contains no
flash erase/program path.

The four modes are:

- `M` at the bank prompt: scan and classify all 32 physical sectors.

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

The host body occupies `$2000-$292B`, `$092C` bytes, with FNV32
`$CEF1F837`. The onboard AP-v2 package has three import relocations and exact
length `$09AD`.

Map classification matches Bank Maintenance: `E` requires all 4096 bytes to
be `$FF`; `A` requires a complete AP-v2 envelope with matching body FNV and
may occur anywhere in the sector; other occupied sectors are `U`. Configured
roles override content as `W`, `B`, or `P`.

`BANKDUMP` is deliberately fixed at its sealed `$2000` base. Run it by name
without a destination override. Its HIMON console imports remain dynamically
linked, but its internal calls and data pointers are generated from and
checked against the host `$2000` map.

The onboard card deliberately retains only four symbols: `BANKDUMP` and its
three imports. Constants, internal calls, data addresses, and branch targets
are fixed from the checked host map. This stays below ASM-F2's global symbol
budget while the readable host `.asm` retains all routine names.

Do not enter `G 2000` on the raw ASM-F2 body. Its imports are unresolved until
`PACKAGE` and the named `AP` load link them. At `SEAL>`, use only the package,
install, and exit commands shown below.

### Historical correction after `ERR=$08 BS`

The first map-extension card exceeded ASM-F2's global symbol budget beginning
at `AP_RECORD`. It ended with `ERR=$09 BAD FIX`; no `PACKAGE` or `INSTALL`
command ran. If that is the immediately preceding board state, flash is
unchanged and B2:9 remains erased. Enter:

```text
RESET
ASM NEW
```

Then send the current complete `.a` and continue at `PACKAGE` below. Do not
repeat the erase step.

## Fresh or replacement install

The accepted `$09AD` BANKDUMP is currently installed at B2:9. For a fresh
installation, or if B2:9 contains an older/different carrier, erase that
sector first. No STR8-N, HIMON, ASM, APMAN, directory, or Bank-3 update is
needed.

At HIMON enter `L` and send this complete file:

```text
C:\SRC\STR8-N\BUILD\v1.32\s19\str8n-v1.32-bank-maint-menu-2000.s19
```

Then enter:

```text
G 2000
```

At `BM>` enter:

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

This is the `$09AD` map-extension card. Do not reuse the earlier `$0597`
source.

At `SEAL>` enter exactly:

```text
PACKAGE BANKDUMP $3000
INSTALL 3000 B2
.
```

Expected package/install lines for the current board are:

```text
PKG OK @=$3000 L=$09AD
INST B2 9000 L=09AD
ASM BYE
```

Reset and prove named discovery:

```text
RESET
APS B2 BANKDUMP
```

Expected:

```text
APS B2 9000 APC BANKDUMP L=09AD @2000
```

## Test 1: complete bank map

```text
AP B2 BANKDUMP
BANK 0-3 OR M=MAP> M
```

Expected current-board map:

```text
B# 8 9 A B C D E F

B0 U U U U U U U U
B1 U A A U U A W B
B2 A A E E E E E E
B3 U U U U U U U P
E=ERASED U=USED A=AP VALID
W=WORK B=B3F BKUP P=B3F PROTECTED
BANKDUMP MAP OK; B3 RESTORED
```

The accepted run classified B1:C as `U`: its current bytes no longer pass the
complete AP-v2/body-FNV validator. Require `A` at B2:8 for APMAN and B2:9 for
BANKDUMP. The other `U` contents are board inventory, not hard-coded policy.

## Test 2: inspect APMAN itself

Enter the command with `A` in the first column:

```text
AP B2 BANKDUMP
```

Then answer:

```text
BANK 0-3 OR M=MAP> 2
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

## Test 3: one page

```text
AP B2 BANKDUMP
BANK 0-3 OR M=MAP> 1
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

This test passed on 2026-08-26. CRC `$FA1C`, all 16 rows from `$C000-$C0FF`,
the completion message, and Bank-3 restoration matched.

## Test 4: whole-sector paging and safe quit

```text
AP B2 BANKDUMP
BANK 0-3 OR M=MAP> 2
SECTOR 8-F> F
H=APC HEADER P=PAGE A=ALL Q=QUIT> A
```

After the first 16 rows:

```text
-- MORE (ENTER=NEXT, Q=QUIT)> Q

BANKDUMP QUIT; NO FLASH WRITE
```

This test passed on 2026-08-26 against erased B2:F. BANKDUMP reported CRC
`$0FE1`, printed `$F000-$F0FF`, accepted `Q` at the first page boundary, and
returned through the no-write quit path.

Success returns `A=$AC`, carry set. A deliberate `Q` returns `A=$E0`, carry
clear. A staging/restore failure prints `BANKDUMP E1`, returns `A=$E1`, carry
clear, and attempts Bank-3 restoration before returning.
