# R-YORS / STR8-N v1.32 Release Refresh Board Test — 2026-09-07

Status: the refreshed release smoke test passed on the W65C02SXB/EDU at
COM4, 115200 baud. The regenerated Bank-3 `$8000-$EFFF` image was installed
and verified without writing protected sector F. One diagnostic fallback
caveat remains open, as recorded below.

## Exact artifacts

| Artifact | SHA-256 |
| --- | --- |
| STR8-N v1.32 top BIN | `5447E9F197ED8FE7AB90FEEEBF25318FBBDCA721612356050F600CDE2268425E` |
| STR8-N v1.32 Bank Maintenance menu | `64DB38E4C10D512ABF1D7A070C84C16DD5F8F61762ED4A717CA2FF15EF333191` |
| R-YORS v1.2 Bank-3 8-E S19 | `336C70CBE0E90C6F58528AFA3E8563EB0121BBCADB2203EFBA3394CD5B413E49` |
| BANKAUDIT direct S19 | `530AB4775AF5C6B3DAE7BC0FD4C30BC91EFB308880599F2019C9552B23D327EE` |

The owner-local append-only JSONL is
`STR8-N/BUILD/v1.32/local/release-refresh-board-20260907-092602.jsonl`,
SHA-256
`3F076A749A3C6BD3BD1E1FEC623667B410CB734EAF4FB8924CA9C0B8407AF2B0`.

## Reset and maintenance-menu proof

From the installed HIMON prompt, unmarked `G F000` produced `RST H` and
`STR8-N 1.32`. The HIMON `STR8` record path produced `RST S` and entered the
same resident image.

The current Bank Maintenance menu loaded through STR8-N `L`, executed its
S9 `$2000` entry, identified as `STR8-N 1.32 BANK MAINT + TOP`, and completed
the read-only `M` map/directory command with `OK`. The map showed Bank-3
sectors 8-E used, sector F protected, and the live D0 `WDCV2` and D3 `HIMON`
directory rows.

## Bank-3 8-E installation and smoke test

The exact refreshed R-YORS S19 was submitted through `I B3 8-E`. STR8-N
accepted the complete stream, reached `COMMIT? Y`, programmed only sectors
8-E, and reported `. OK`.

`W` then produced:

```text
BOOT WARM

HIMON V 00.0907(0920)
>
```

`ASM` entered `ASM-F2 00.0907(0920)` at `ASM>$2000:`. A single `.` exited
cleanly with `ASM BYE` and returned to HIMON.

## Bank-3 readback identity

BANKAUDIT populated its little-endian CRC table at `$7C40-$7C4F` with:

```text
B3:8 BBBC
B3:9 2029
B3:A A504
B3:B 5477
B3:C D2D8
B3:D 2535
B3:E 8825
B3:F 5855
```

The host recomputation over the released 8-E S19 matches sectors 8-E exactly.
The canonical v1.32 top BIN has CRC `$6096` with an erased directory pocket;
after overlaying the board's preserved `$FFB0-$FFF9` directory/configuration
bytes, the expected sector-F CRC is `$5855`, matching the board. Thus all
eight Bank-3 sector CRCs agree with the released bytes plus intentional live
metadata.

## Open diagnostic caveat

The direct BANKAUDIT S19 loaded with `L OK=0202 ENTRY=2000` and computed the
complete CRC table, but its report/return path did not print the documented
table or return `A=$AC`; HIMON reported `RET A=20` and `$7C00` remained zero.
This does not invalidate the independently compared CRC bytes, but the direct
fallback is not board-accepted by this run.

The board has no APMAN carrier installed (`AP B2 BANKDUMP` returned
`APMAN NF`, consistent with the maintenance map showing Bank 2 erased), so
the dynamically linked packaged `.a` path was not exercised. No APMAN or
Bank-2 installation was attempted during this smoke test.
