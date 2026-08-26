# BANKAUDIT Banked AP Utility

Status: host-built and structurally checked. APMAN provides the simple
bank-aware `INSTALL`; the complete board proof remains pending.

`BANKAUDIT` is a read-only system-maintenance AP. It computes
CRC-16/CCITT-FALSE over every 4K flash sector in Banks 0-3, prints four compact
rows, leaves the 32 little-endian CRC values at `$7C10-$7C4F`, captures bytes
`$FFF0/$FFF1` from each bank at `$7C08-$7C0F`, and restores Bank 3 after every
staged read. It has no flash erase/program path.

## Exact files

```text
Onboard ASM-F2 source
C:\SRC\R-YORS\RELEASE\ARTIFACTS\SOURCES\bank-audit-2000.a

Host-built counterpart
C:\SRC\R-YORS\RELEASE\ARTIFACTS\SOURCES\bank-audit-2000.asm

Direct RAM-load S19
C:\SRC\R-YORS\RELEASE\ARTIFACTS\COMPONENT-IMAGES\bank-audit-2000.s19
```

The host body occupies `$2000-$2201`, `$0202` bytes, with FNV32 `$0EFD2A83`.
The `.a` and `.asm` shared bodies are checked line-for-line. The onboard `.a`
imports `BIO_FTDI_PUT_CSTR`, so its AP package resolves the compatible resident
console routine when loaded rather than freezing the host build's address. Its
one entry export, one import, and 16 relocation rows produce an exact `$0294`
AP v2 envelope.

## Complete APMAN cycle

First install the APMAN bootstrap exactly as shown in
[APMAN_V1_BOARD_TEST.md](APMAN_V1_BOARD_TEST.md), and boot the candidate HIMON
and ASM-F2 image.

At HIMON:

```text
ASM NEW
```

Send this one file:

```text
C:\SRC\R-YORS\RELEASE\ARTIFACTS\SOURCES\bank-audit-2000.a
```

At `SEAL>`:

```text
PACKAGE BANKAUDIT $3000
INSTALL 3000 B1
```

Expected package and captured-board install lines are:

```text
PKG OK @=$3000 L=$0294
INST B1 A000 L=0294
```

`B1` is the in-command destination confirmation. Record the address printed by
`INST`; APMAN chooses the first completely erased, unreserved 4K sector. Then:

```text
.
RESET
```

After HIMON returns, run by name; no helper and no separate `G` are needed:

```text
APS B1
AP B1 BANKAUDIT
```

The reported sector address remains an exact fallback, for example
`AP B1 A000`. Both forms default to the package's sealed `$2000` base.

The utility prints this shape, with board-specific CRCs:

```text
BANKAUDIT CRC16/4K
B0 8=hhhh 9=hhhh A=hhhh B=hhhh C=hhhh D=hhhh E=hhhh F=hhhh
B1 8=hhhh 9=hhhh A=hhhh B=hhhh C=hhhh D=hhhh E=hhhh F=hhhh
B2 8=hhhh 9=hhhh A=hhhh B=hhhh C=hhhh D=hhhh E=hhhh F=hhhh
B3 8=hhhh 9=hhhh A=hhhh B=hhhh C=hhhh D=hhhh E=hhhh F=hhhh
BANKAUDIT OK; B3 RESTORED
```

Success returns `A=$AC`, carry set. Failure prints `BANKAUDIT E1`, records the
failing bank/sector at `$7C01/$7C02`, attempts to restore Bank 3, and returns
`A=$E1`, carry clear.

Do not use the direct S19 and the onboard `.a` in the same cycle. The S19 is a
diagnostic fallback; the `.a` is the proof that ASM-F2 produced the persistent
AP that later ran after reset.
