# ASM Session, Carry, And AP Boundary Board Test

This card closes the currently deferred ASM-F2 board proofs. Use matching
current HIMON and ASM-F2 images. The reporter is map-coupled and must be rebuilt
and installed from the same ASM-F2 image used for the target sessions.

Record the complete output, including both visible version strings and every
`RET` line. Do not run a banked `AP` between a target ASM session and its
following `G 4800` report.

## 1. Direct Carry Display

Hardware status: passed on `HIMON/ASM-F2 00.0715(1804)`. The commands remain
here as a regression check for later HIMON return-wrapper changes.

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/return-carry-proof-transient-2000.a
ASM OK
SEAL> .
ASM BYE
>G 2000
```

Expected: `RET A=AC ... C` with carry set.

```text
>G 2004
```

Expected: `RET A=E1 ... c` with carry clear.

## 2. Rebuild And Install The Current Reporter

Use a reserved Bank 0 area with enough erased space. AUTO placement is the
preferred proof because it also preserves existing packages in the sector.

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/asm-session-report-4800.a
ASM OK
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$llll
SEAL> .
ASM BYE
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/bank0ap-put-transient-2000.a
ASM OK
SEAL> .
ASM BYE
>G 2000
```

At `DST`, press Enter for AUTO. Verify the printed Bank 0 address, type exact
`YES`, and record it as `$hhhh`. Require `PROGRAM OK`, `RET A=AC ... C`, and:

```text
>D 1A00 1A06
```

Expected: `AC ll hh lenlo lenhi sector 00`.

Preload the stored reporter. Its immediate report follows a bank staging
operation, so low-table names may be stale; only residency and a clean return
matter at this point.

```text
>AP B0 $hhhh $4800
```

Require no `APERR`. Do not issue another `AP` before the next `G 4800`.

## 3. Failed Session Reporter Return

Hardware status: passed on `HIMON/ASM-F2 00.0715(1804)` with both
`NOPE #$01` and the maintained `FOO BAR` probe.

```text
>ASM NEW
ASM>$2000: FOO BAR
ERR=$01 BM PC=$2000
ASM>$2000: .
ASM BYE
```

Expected: HIMON reports the ASM command failure as `EXEC ERR=$01`.
Bare `NOPE` is not this test: with no operand it is accepted as a pending
label and exits without an error. `FOO BAR` is the parser's documented
unknown-label plus unknown-operation bad-mnemonic case; this image renders
that status compactly as `BM`.

```text
>G 4800
```

Require a coherent report for the failed session, `STATUS` reflecting `$01`,
`ASM REPORT OK`, and `RET A=01 ... c` with carry clear.

## 4. Clean Session Reporter Return

Hardware status: passed on `HIMON/ASM-F2 00.0715(1804)`.

```text
>ASM NEW
ASM>$2000: LDA #$AC
ASM>$2002: RTS
ASM>$2003: END
ASM OK
SEAL> .
ASM BYE
>G 4800
```

Require `STATUS=OK`, `START=$2000`, `PC/HIGH=$2003`, `ASM REPORT OK`, and
`RET A=00 ... C` with carry set. This is the positive preload-then-report
lifecycle proof.

## 5. Exact `$1000` Envelope

Hardware status: passed on `HIMON/ASM-F2 00.0715(1804)`.

This fixture is package-only and performs no flash write.
It uses fifteen initialized `DS $FF` lines plus `DS $EF`; ASM-F2 intentionally
rejects any single `DS` count above `$FF`.

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/ap-envelope-1000-fixture-2000.a
ASM OK
SEAL> PACKAGE $3000
PKG OK @=$3000 L=$1000
SEAL> .
ASM BYE
>D 3000 3004
```

Expected header: `41 50 01 00 10`.

```text
>D 3FF8 3FFF
```

Expected: eight `$A5` BODY bytes through the last byte of the package buffer.

## 6. Rejected `$1001` Envelope

This fixture uses fifteen initialized `DS $FF` lines plus `DS $F0`.
Hardware status: passed on `HIMON/ASM-F2 00.0715(1804)`.

```text
>ASM NEW
paste DOC/GUIDES/ASM/SAMPLES/ap-envelope-1001-fixture-2000.a
ASM OK
SEAL> PACKAGE $3000
```

Expected: `PKG ERR=$06`, the assembler's `BAD RANGE` status. Do not install
or run this fixture. Exit with `.`; HIMON then reports `EXEC ERR=$06`.

## Pass Conditions

```text
direct carry proof       A=AC/C=1 and A=E1/C=0
failed reporter session  A=01/C=0
clean reporter session   A=00/C=1
exact envelope           PKG L=$1000, header length 00 10
oversize envelope        PKG ERR=$06 at L=$1001
```
