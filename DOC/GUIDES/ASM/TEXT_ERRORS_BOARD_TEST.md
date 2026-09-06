# ASM-F2 Text Diagnostics Board Card

Status: accepted on COM4, 2026-09-05, including operator-confirmed physical
RESET and post-reset ASM smoke. The candidate and exhaustive host results are in
[TEST_PLAN.md](TEST_PLAN.md), and the exact install/readback and test evidence
is in [the hardware record](../LOGS/ASMF2_TEXT_2026-09-05.md).
Any future flash update still needs operator authority and a reviewed payload.
For an existing Bank-3 HIMON entry, use a validated dense ASM-only transfer
with S9 `$FFFF` (preserve entry), not the generic component's `$8000` S9.

## Source Diagnostics

Start a fresh `ASM NEW` session from HIMON. Enter these lines individually:

| Source | Expected |
| --- | --- |
| `FOO BAR` | `ERR UNKNOWN OP PC=$2000` |
| `LDA #` | `ERR OPERAND PC=$2000` |
| `LDA A` | `ERR ADDR MODE PC=$2000` |
| `LDA 1000` | `ERR SIZE PC=$2000` |
| `BNE $3000` | `ERR RANGE PC=$2000` |
| 64 consecutive `A` characters | `ERR LINE PC=$2000` |
| `FOO EQU 1` | accepted |
| `FOO EQU 2` | `ERR NAME PC=$2000` |
| `JMP MISSING` | accepted; PC becomes `$2003` |
| `END` | `ERR FIXUP PC=$2003`; returns to HIMON |

HIMON may print `EXEC ERR=$09`; the numeric executable return remains intact.
`DIRECTIVE`, legacy `LOCAL`, unknown statuses, and unavailable-service faults
are covered by the exhaustive host injection, not artificial board corruption.

## Rollback and Successful Workflow

Enter `ASM NEW`, then:

```text
DB $A5
DB $11,
DB $5A
.
```

Require `ERR OPERAND PC=$2001`, final PC `$2002`, and HIMON failure `$03`.
Dump `$2000-$2001`: require `A5 5A`. The rejected line must not consume a byte.

In another fresh session:

```text
LDA #$AC
RTS
END
SEAL
PACKAGE $3000
LOAD $3000 $4000
.
```

Require `ASM OK`, `SEAL OK`, `PKG OK @=$3000`, and `LOAD OK=$4000`.
Dump both `$2000-$2002` and `$4000-$4002`: require `A9 AC 60`.
In the source session, `.P` must still print the correct PC.

## Context-Specific Failures

Start fresh and enter:

```text
DB 1
ORG $2010
DB 2
END
SEAL
RELOCATE $3000
PACKAGE $3000
.
```

Require `SEAL INVALID FLAGS=$03`, `REL INVALID`, `PKG INVALID`, and HIMON
failure `$02`. This is seal status `$02`, not the parser's directive error.

For invalid AP text, start fresh, enter `DB 0,0,0,0,0`, `END`, then
`LOAD $2000 $4000`. Require `LOAD INVALID`, then exit with `.` and require
HIMON failure `$07`.

For the protected boundary, first use a separate `ASM NEW` session to enter
`ORG $7CFF`, `DB $3C`, and `.`. HIMON `M` deliberately protects this upper
user region. Verify the sentinel using `D 7CF0 7CFF`. In another `ASM NEW`
session, enter `ORG $7CFF` and `DB $A5,$5A`. Require
`ERR RANGE PC=$7CFF`; exit and verify the original `$7CFF` byte remains.

Also exercise 129 short EQU names (row exhaustion), 67 distinct 31-character
EQU names (name-pool exhaustion), and 129 `JMP MISSING` lines (fixup exhaustion),
each in a fresh session. Require NAME/NAME/FIXUP, then numeric $08/$08/$09.
At `SEAL>`, malformed `$GG` operands must give `REL OPERAND`, `PKG OPERAND`,
`LOAD OPERAND`, and `INST OPERAND`; no flash write is requested by these cases.

Leave board proof pending if installed identities do not match the reviewed
candidate. Append new transcripts; preserve previous hardware logs.
