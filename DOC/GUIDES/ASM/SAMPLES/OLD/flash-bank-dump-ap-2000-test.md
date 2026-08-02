# Fixed-Load Flash Bank/Sector Dump AP Board Test

`flash-bank-dump-ap-2000.a` is the read-only display member of the Bank-0 AP
toolbox. It asks separately for a physical flash bank and sector, stages the
selected 4K sector into `$4000-$4FFF`, and displays it as 16-byte hex/ASCII
rows in 256-byte pages.

It never erases or programs flash. `Q` at a page boundary exits the display;
Enter advances to the next 256-byte page.

## Preconditions

- A table-free Bank-0 PUT AP is stored; call its address `PUTPKG`.
- A known recovery route is available before making the one intentional
  Bank-0 write that stores this read-only AP.

## 1. Build And Package

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/flash-bank-dump-ap-2000.a
ASM OK
SEAL OK FLAGS=$01 BASE=$2000 END=$22A5
SEAL REL @=$hhhh COUNT=$00
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$hhhh
SEAL> .
ASM BYE
```

Stop on any paste `ERR=`, a seal other than `FLAGS=$01`, a nonzero relocation
count, or a package error. The package length is recorded from the board.

## 2. Store The AP

```text
>AP B0 PUTPKG $2000
```

Choose a reserved erased Bank-0 destination, type exact `YES`, and record the
resulting address as `DUMPPKG`.

## 3. Read And Display A Sector

```text
>AP B0 DUMPPKG $2000
FLASH BANK DUMP
BANK 0-3> 2
SECTOR 8-F> F
```

Expected header and first display row shape:

```text
DUMP B2:$F000-$FFFF
F000: xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx xx |................|
...
-- MORE (ENTER=NEXT, Q=QUIT)>
```

At the first `MORE` prompt enter `Q`. Require:

```text
ABORT - NO FLASH WRITE
RET A=E0 ... c
```

The staging image remains at `$4000-$4FFF` for a monitor dump or comparison:

```text
>D 4000 403F
```

The dumped bytes must match the displayed beginning of physical Bank 2 sector
`$F000-$FFFF`. Record the transcript in `HARDWARE_TEST_LOG.md`; do not replace
earlier read/CRC or erase evidence.
