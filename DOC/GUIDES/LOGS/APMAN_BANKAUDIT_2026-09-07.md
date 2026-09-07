# APMAN Install and BANKAUDIT Retry — 2026-09-07

Status: accepted on the W65C02SXB/EDU at COM4, 115200 baud. This follow-up
closes the packaged-path caveat from the v1.32 release-refresh smoke test.
APMAN was installed in Bank 2, the current BANKAUDIT source was assembled and
installed through APMAN, and the complete 32-sector audit passed.

## Exact artifacts and evidence

| Item | SHA-256 |
| --- | --- |
| APMAN dense Bank-2 S19 | `15A782F03FAEE2DFCC537FC3EF7C0D8BDC5561944744D0FCDE8FA4D10DA36FB6` |
| BANKAUDIT onboard `.a` | `02E20E8EFAC795543FCDAACF6A2398F5CF157FB0560639227A18FD898D3B2E0A` |
| Append-only COM4 JSONL | `3A0F1E65FCD0B0C1D630765062599E340CF002C20915F9C5C280ADC6A8F8CF87` |

The owner-local transcript is
`STR8-N/BUILD/v1.32/local/apman-bankaudit-board-20260907-094055.jsonl`.

## Flash changes

The preflight map showed Bank 2 completely erased and D2 empty. STR8-N 1.32
therefore installed only the released APMAN carrier at `B2:8` and enrolled D2
as type `$A2`, description `APC02`. It did not erase the rest of Bank 2.

After APMAN validation, the onboard ASM-F2/SEAL flow produced the current
BANKAUDIT AP envelope and APMAN selected the first safe erased Bank-1 sector,
`B1:8`. Existing Bank-1 sector F and all Bank-3 code sectors were preserved.

## APMAN validation

The guarded STR8-N install completed with `. OK`. Reloading the current Bank
Maintenance menu reported:

```text
B2 A E E E E E E E
AP ENVELOPES
AP B2 8000 L0B40
D2 A2 APC02 FFFF FCFFFFFF
 OK
```

HIMON then resolved the installed manager by both inventory and name:

```text
APS B2
APS B2 8000 APC APMAN L=0B40 @7000
APS B2 APMAN
APS B2 8000 APC APMAN L=0B40 @7000
AP B2 APMAN 2000
APMAN ERR=$DB
```

The `$DB` result is the required self-load rejection.

## BANKAUDIT package and install

The released `.a` completed with `ASM OK`. SEAL and APMAN reported the exact
expected package length and actual storage slot:

```text
PACKAGE BANKAUDIT $3000
PKG OK @=$3000 L=$0299
INSTALL 3000 B1
INST B1 8000 L=0299
APS B1 BANKAUDIT
APS B1 8000 APC BANKAUDIT L=0299 @2000
```

The named `AP B1 BANKAUDIT` run loaded, linked, and executed successfully. A
second `G 2000` run through HIMON made the return registers directly visible:

```text
BANKAUDIT CRC16/4K
B0 8=5579 9=D507 A=ACD0 B=EFDF C=EFDF D=EFDF E=EFDF F=D007
B1 8=FA1C 9=0FE1 A=0FE1 B=0FE1 C=0FE1 D=0FE1 E=0FE1 F=1336
B2 8=60CF 9=0FE1 A=0FE1 B=0FE1 C=0FE1 D=0FE1 E=0FE1 F=0FE1
B3 8=BBBC 9=2029 A=A504 B=5477 C=D2D8 D=2535 E=8825 F=EBF1
BANKAUDIT OK; B3 RESTORED

#GO# ENTRY=2000
RET A=AC X=BF Y=1B P=B5 S=FD Nv-BdIzC
>
```

The retained result bytes also read `7C00: AC 00 00`. Acceptance requirements
are met: 32 CRCs were printed, Bank 3 was restored, A returned `$AC`, and carry
was set. The final board state is the HIMON `>` prompt.
