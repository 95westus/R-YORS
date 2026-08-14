# APv2 Installed-Image Test Cards

These cards exercise installed flash ASM and the resident HIMON APv2 loader.
They are RAM-only: do not use `INSTALL`, `AP Bn`, STR8-N `I`, or any flash
command during these tests.

Hardware status: Cards 0-6 accepted on `00.0813(2009)` and Card 7 accepted on
the corrected named-package build `00.0813(2101)`.

## Prompt Rule

Check the prompt before every command:

```text
ASM>   source lines or . only
SEAL>  SEAL, PACKAGE, LOAD, or . only
>      HIMON commands: ASM, L, D, M, AP, or G
```

`D`, `M`, `AP`, `G`, and `L` are never SEAL commands. Every card below puts
the exit `.` in its own SEAL/ASM phase. Do not start the following HIMON phase
until `ASM BYE` has printed and the prompt is exactly bare `>`.

Prompt characters shown in prose are context; do not paste them. Stop at the
first unexpected status and retain the complete transcript.

## Card 0: Leave And Re-enter SEAL

At a bare HIMON `>` prompt, first force a source-mode exit with no completed
session:

```text
ASM NEW
```

At the first `ASM>` prompt, enter `.` and wait for `ASM BYE` plus bare `>`.
Then enter:

```text
ASM SEAL
```

Require the ASM-F2 banner followed by HIMON `#56AD7400# EXEC ERR=$03`; there
is no preserved completed session. Then enter at bare HIMON `>`:

```text
ASM NEW
```

At `ASM>`, enter:

```text
ORG $2000
RTS
END
```

At `SEAL>`, leave and re-enter using the prompts shown:

```text
SEAL> .
ASM BYE
>ASM SEAL
ASM-F2 ...
SEAL> SEAL
SEAL OK
SEAL> .
ASM BYE
>
```

This proves that `.` changes prompt ownership without erasing the frozen
session, and that top-level `ASM SEAL` resumes it. Do not type a HIMON `D`,
`M`, `G`, or `AP` command until the final bare `>`.

## Reporter Preload

Preload the reporter once before Cards 1 and 3-7. If an earlier test wrote
inside `$7000-$771C` or stopped in BRK, reload it before continuing.

The reporter is coupled to the final flash-ASM map. After the last ASM build,
run `make -C SRC asm-test` (or `make -C SRC asm-session-report`) and use the
newly generated `$7000` S19. `asm-test` deliberately depends on the full
reporter target so it cannot leave this board artifact stale.

At the bare HIMON `>` prompt, enter:

```text
L
```

Send:

```text
SRC/BUILD/s19/asm-session-report-v1.2-7000.s19
```

For the ASM-F2 `00.0813(2009)` layout, the corrected reporter SHA-256 is
`DB65584B5D36F5B0A2AF6BB4E9D63B5DEDA0A3C063E0B66D0966E022FB24D57F`.
The stale `C1D4543F...` artifact is rejected; it streams table/string memory
as console text instead of producing a report.

Require:

```text
L OK=071D ENTRY=7000
```

Do not run it yet. The reporter occupies `$7000-$771C`; the cards use
`$7900-$7902` for execution sentinels.

## Card 1: Full 64-Row Relocation And Execution

At bare HIMON `>`:

```text
ASM NEW
```

At `ASM>`, send [apv2-reloc64-2000.a](SAMPLES/apv2-reloc64-2000.a).
After `END` changes the prompt to `SEAL>`, enter only:

```text
SEAL
PACKAGE $3200
.
```

Wait for `ASM BYE` and bare `>`. Then enter these HIMON commands:

```text
D 3200 3204
D 3213 3216
AP $3200 $3000
D 3000 3006
D 7900
G 7000
```

Require:

```text
3200: 41 50 02 ...
3213: 52 41 01 40 ...
#GO# ENTRY=3000
RET A=64 ... C set
3000: 4C 81 30 81 30 81 30
7900: 64
COUNTS ... FIX=40 REL=40 EXP=01 IMP=00
```

## Card 2: Typed Import Match And Mismatch

At bare HIMON `>`:

```text
ASM NEW
```

At `ASM>`, send
[str8n-v1.2-ap-link-smoke-2000.a](SAMPLES/str8n-v1.2-ap-link-smoke-2000.a).
After `END` changes the prompt to `SEAL>`, enter only:

```text
SEAL
PACKAGE $4000
.
```

Wait for `ASM BYE` and bare `>`. Then run the positive HIMON commands:

```text
D 4000 4004
D 4040 4049
AP $4000 $3000
D 5848 584B
```

Require:

```text
4000: 41 50 02 82 00
4040: 49 13 00 01 01 42 0F FA AE 11
BANK RJOIN
RET A=AC ... C set
5848: AC ...
```

Still at bare HIMON `>`, run the negative contract check. For each `M`
command, type the replacement byte shown in the comment:

```text
M 5848          enter 00
M 4044          enter 02
AP $4000 $3000
D 5848
M 4044          restore 01
```

Require `APERR=$09`, no `BANK RJOIN`, and `$5848=$00`. A successful run with
kind `$02` is a failure.

## Card 3: 64 Export Rows

At bare HIMON `>`:

```text
ASM NEW
```

At `ASM>`, send [apv2-export64-2000.a](SAMPLES/apv2-export64-2000.a).
After `END` changes the prompt to `SEAL>`, enter only:

```text
SEAL
PACKAGE $3200
.
```

Wait for `ASM BYE` and bare `>`. Then enter these HIMON commands:

```text
D 3200 3204
D 3217 321A
AP $3200 $3000
D 7901
G 7000
```

Require:

```text
3200: 41 50 02 A9 02
3217: 45 81 02 40
#GO# ENTRY=3000
RET A=40 ... C set
7901: 40
COUNTS ... EXP=40 IMP=00
```

The reporter must list export rows `$00-$3F` and finish with `ASM REPORT OK`.

## Card 4: 64 Import Rows And Missing-Name Failure

This revised card emits one ABS16 relocation use for every import. Reload the
reporter before this card if `$7000-$771C` may have been modified.

At bare HIMON `>`, inspect the sentinel:

```text
M 7902
```

If it is already `$00`, press Enter without rewriting it. Otherwise enter
replacement byte `$00`. Still at bare HIMON `>`, enter:

```text
ASM NEW
```

At `ASM>`, send [apv2-import64-2000.a](SAMPLES/apv2-import64-2000.a).
After `END` changes the prompt to `SEAL>`, enter only:

```text
SEAL
PACKAGE $3200
.
```

Wait for `ASM BYE` and bare `>`. Then enter these HIMON commands:

```text
D 3200 3204
D 3213 3216
D 3367 336A
AP $3200 $3000
D 7902
G 7000
```

Require:

```text
PKG OK @=$3200 L=$03F5
3200: 41 50 02 F5 03
3213: 52 41 01 40
3367: 49 01 02 40
APERR=$09
7902: 00
COUNTS ... FIX=40 REL=40 EXP=01 IMP=40
```

There must be no `GO 3000`. The reporter must list 64 relocation rows and 64
import rows and finish with `ASM REPORT OK`.

## Card 5: 128 Symbol Slots And 129th-Allocation Rollback

At bare HIMON `>`:

```text
ASM NEW
```

At `ASM>`, send [symbol128-slot-rollback.a](SAMPLES/symbol128-slot-rollback.a).
The final `S128 EQU $00` must report:

```text
ERR=$08 BAD SYM
```

The prompt remains `ASM>`. Exit ASM with this single command:

```text
.
```

Wait for `ASM BYE` and bare `>`. Then run the reporter as a HIMON command:

```text
G 7000
```

Require:

```text
STATUS=$08
SYMS=$80/$80
NAMEPOOL=$0200/$0800
ASM REPORT OK
```

This proves the rejected 129th name changed neither the symbol count nor the
name-pool cursor.

## Card 6: Name-Pool Exhaustion And Allocation Rollback

At bare HIMON `>`:

```text
ASM NEW
```

At `ASM>`, send
[symbol-name-pool-rollback.a](SAMPLES/symbol-name-pool-rollback.a). Its 66
accepted names consume `$07FE`. The final `BAD` name must report:

```text
ERR=$08 BAD SYM
```

The prompt remains `ASM>`. Exit ASM with:

```text
.
```

Wait for `ASM BYE` and bare `>`. Then run:

```text
G 7000
```

Require:

```text
STATUS=$08
SYMS=$42/$80
NAMEPOOL=$07FE/$0800
ASM REPORT OK
```

Let the reporter finish all 66 long-name rows.

## Card 7: Named Runnable-Package Identity

At bare HIMON `>`, seed the destination:

```text
M 3200
```

Enter replacement byte `$5A`. Still at bare HIMON `>`, enter:

```text
ASM NEW
```

At `ASM>`, send [apv2-named-identity-2000.a](SAMPLES/apv2-named-identity-2000.a).
After `END` changes the prompt to `SEAL>`, enter only:

```text
PACKAGE WRONG $3200
.
```

Require `PKG ERR=$08`, then wait for `ASM BYE` and bare `>`. Verify the rejected
name wrote nothing:

```text
D 3200
```

Require `$3200=$5A`. Start a fresh session at bare HIMON `>`:

```text
ASM NEW
```

Send the same source again at `ASM>`. After `END` reaches `SEAL>`, enter only:

```text
PACKAGE ASMREPORT $3200
.
```

Wait for `ASM BYE` and bare `>`. Then enter these HIMON commands:

```text
AP $3200 $3000
G 7000
```

Require `PKG OK`, then require the package to return `A=$A7` with carry set
and make the reporter's `PKG ... ID` field end in `ASMREPORT`.

## Closeout

Capture the complete terminal transcript. Record the STR8-N, HIMON, and ASM-F2
banners, all status lines, the exact dumps above, and each final reporter
status. Do not reinterpret a command entered at the wrong prompt as a firmware
result.
