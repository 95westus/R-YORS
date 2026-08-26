# PIA LED Named Carrier Card

Hardware status: the carrier transport passed with the older LED register
model, but no EDU LED changed. The maintained source now uses the W65C21's
multiplexed Port-A/DDRA register at `$7FA0` and CRA at `$7FA1`; that physical
LED correction still needs its focused board rerun.

This is the small APMAN example:

```text
ASM NEW -> PACKAGE -> INSTALL -> RESET -> AP by name
```

Install the B2:8 APMAN bootstrap and current Bank-3 image first, using sections
1 and 2 of [APMAN_V1_BOARD_TEST.md](APMAN_V1_BOARD_TEST.md).

## Exact source

```text
C:\SRC\R-YORS\RELEASE\ARTIFACTS\SOURCES\pia-led-show-2000.a
```

## Assemble, package, and install

At HIMON:

```text
ASM NEW
```

Send the exact source above. After `ASM OK` and `SEAL>`, type:

```text
SEAL
PACKAGE PIALED $3000
INSTALL 3000 B1
.
RESET
```

Require `PKG OK @=$3000 L=$00D0`. `B1` is the install confirmation. APMAN
selects the first completely erased, unreserved B1 sector and prints it; no
Bank Maintenance menu, PUT helper, or separate `G` command is used.

## List and run after reset

```text
APS B1
APS B1 PIALED
AP B1 PIALED
```

The program loads at its sealed `$2000` base, walks the eight LED patterns,
restores the previous Port-A state, DDRA, and CRA, then returns `A=$AC` with
carry set. The `GO 2000` line printed by HIMON is output from `AP`, not another
command to type.

If another B1 carrier already uses the executable name `PIALED`, name discovery
must reject the duplicate. Either reclaim that older carrier for a later test
or run this carrier by the exact sector address printed by INSTALL:

```text
AP B1 A000
```

Replace `A000` with the actual printed sector.

## Historical transport proof

Before APMAN, the board assembled the older 87-byte LED body, packaged it at
`$7000`, and Bank Maintenance put it at B1:D. After reset,
`AP B1 D000 2000` loaded, relocated, and executed it, returning `A=$AC` and
`X=$10`; therefore all 16 pattern rows ran. No physical LED changed because
that source incorrectly treated `$7FA1/$7FA3` as W65C22 Port-A/DDRA registers.
The current 132-byte body corrects that hardware model. This historical run is
carrier-transport evidence only, not acceptance of the corrected LED output.
