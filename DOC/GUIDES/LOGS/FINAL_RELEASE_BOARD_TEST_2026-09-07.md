# Final v1.32 Release Board Test — 2026-09-07

Status: accepted on the W65C02SXB/EDU at COM4, 115200 baud. This run tests
the exact R-YORS artifact republished after the STR8-N v1.32 tooling commit.

## Exact identities

```text
STR8-N commit                    325d8c2cde87e695501239c648bd0f73fe058a59
published STR8-N manifest       dirty=false
R-YORS Bank-3 8-E S19 SHA-256   8C8382BD72B07B0555E368786FAB69E58F3735AA9069F1571DADD3BDE4D991C0
BANKAUDIT .a SHA-256             02E20E8EFAC795543FCDAACF6A2398F5CF157FB0560639227A18FD898D3B2E0A
COM4 JSONL SHA-256               15A001C6168F77AE9E54E521DF0C9E7C01C51F07AF1F3887295D28EB72DC3175
```

The owner-local append-only transcript is
`STR8-N/BUILD/v1.32/local/release-postcommit-board-20260907-100127.jsonl`.
It contains 967 valid JSONL records.

## Guarded install and boot identity

STR8-N 1.32 accepted the exact published S19 through `I B3 8-E`, reached the
explicit `COMMIT? Y` gate, programmed and verified the final sector, and
reported `. OK`. Only Bank-3 sectors 8-E were selected; protected sector F
was not selected.

The warm boot and assembler entry identified the republished image exactly:

```text
BOOT WARM

HIMON V 00.0907(0959)
>ASM
ASM-F2 00.0907(0959)
ASM>$2000: .
ASM BYE
>
```

## Packaged BANKAUDIT retry

The previously installed current BANKAUDIT package remained discoverable:

```text
APS B1 BANKAUDIT
APS B1 8000 APC BANKAUDIT L=0299 @2000
```

Both the named AP run and a second HIMON-visible `G 2000` run completed the
full read-only audit. The final visible result was:

```text
BANKAUDIT CRC16/4K
B0 8=5579 9=D507 A=ACD0 B=EFDF C=EFDF D=EFDF E=EFDF F=D007
B1 8=FA1C 9=0FE1 A=0FE1 B=0FE1 C=0FE1 D=0FE1 E=0FE1 F=1336
B2 8=60CF 9=0FE1 A=0FE1 B=0FE1 C=0FE1 D=0FE1 E=0FE1 F=0FE1
B3 8=BBBC 9=2029 A=A504 B=F4C2 C=D2D8 D=2535 E=DB3E F=BB16
BANKAUDIT OK; B3 RESTORED

#GO# ENTRY=2000
RET A=AC X=BF Y=1B P=B5 S=FD Nv-BdIzC
>
```

Acceptance requirements are met: all 32 CRCs printed, Bank 3 was restored,
A returned `$AC`, and carry was set. The final board state is the HIMON `>`
prompt.
