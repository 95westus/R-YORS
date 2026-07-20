# STR8 V0 Restore And Failure Gates

This card supplies the two remaining pasteable STR8 V0 recovery fixtures:

```text
Gate 1  ordinary lower-sector restore over deliberately different nonerased bytes
Gate 2  injected high-restore failure after the $F000 sector verifies
```

Status on 2026-07-19: both gates passed on hardware and their evidence is
appended to `LOGS/HARDWARE_TEST_LOG.md`. Gate 2's revised source assembled,
passed its nonwriting latch, safely reported a Bank-2/Bank-3 mismatch, then
passed after an intentional B3-to-B2 backup rotation. It tests the installed
STR8 RAM worker through its stable `$F003` service; neither fixture changes
STR8 firmware or its ROM-resident worker.

## Frozen Inputs

```text
bd7f4cae699619e3154d7080c521b2f55bfb67d4  str8-restore-nonerased-3000.a
11664524085cad0a74859c0b03a0a812ff27b860  str8-highfail-inject-3000.a
```

Active paths:

- [str8-restore-nonerased-3000.a](../ASM/SAMPLES/str8-restore-nonerased-3000.a)
- [str8-highfail-inject-3000.a](../ASM/SAMPLES/str8-highfail-inject-3000.a)

The files ship with `ARM EQU $00`. An unchanged fixture is a dry safety check:
`G 3000` must return `$E0` with carry clear and must not write flash. Change
that one constant to `$A5` only for the destructive run described below.

## Shared Safety Boundary

Do not run either gate unless all of the following are true:

1. An external programmer and a known-good complete board image are ready.
2. Physical Bank 2 is the intended restore source and its contents may be
   copied into Bank 3.
3. Bank 3 `$8000-$EFFF` is sacrificial for the test.
4. The current ASM-F2 flash S19 is ready for `L F` afterward.
5. Power and serial are stable; no other flash operation is in progress.

Gate 1 replaces Bank 3 `$8000-$BFFF`. Gate 2 replaces all Bank 3
`$8000-$FFFF`. The fixture and verification code run from RAM at `$3000` and
survive those writes. Gate 1 must return warm without a reset. Gate 2 requires
one physical reset without power loss, followed by STR8-to-HIMON warm entry.

## Gate 1: Restore Over Nonerased Lower Flash

This gate proves the normal `STR8_COPY_MODE_RESTORE=$01` path erases a
nonblank destination sector before programming it. The fixture uses Bank 2 as
source, Bank 3 as destination, sector `$9000-$9FFF`, and marker byte `$9FF0`.

### Dry latch check

```text
ASM NEW
  paste ASM/SAMPLES/str8-restore-nonerased-3000.a unchanged
.
G 3000
D 1A00 1A07
```

Require `$1A00=$E0` and a return with carry clear. Stop if flash changes.

### Prepare the deliberate collision

Reassemble the same file after changing only:

```text
ARM     EQU $A5
```

Then:

```text
G 3000
D 1A00 1A07
D 9FF0
```

Required preparation result:

```text
$1A00 = AC
$1A01 = 50
$1A06 = 02
$1A07 = 90
$1A03 = bitwise complement of $1A02
$9FF0 = $1A03, and differs from source/original byte $1A02
RET A=AC with carry set
```

`$AC/$50` proves the Bank 3 sector was erased, programmed with the staged
collision, and read back before the restore command. If the result is
`$E1-$E3`, stop; do not enter STR8 restore.

### Run the real operator restore

From HIMON, enter STR8 and press `S` during its countdown:

```text
STR8
  answer y to HIMON's RUN confirmation
  press S during "HIMON IN 3S"
```

At the STR8 prompt:

```text
2
RESTORE B2->B3? Y: y
FLASH C000-FFFF? Y: n
```

Wait for `COPY B2->B3`, `OK`, and the STR8 prompt. Declining the second prompt
is essential: this gate must use ordinary restore and must leave
`$C000-$FFFF` untouched. Then return warm to HIMON:

```text
G
G 3003
D 1A00 1A07
D 9FF0
```

Required proof:

```text
$1A00-$1A01 = AC 56
$1A02/$1A03 still record the original/complement pair
$1A04-$1A05 = 00 00
$1A06-$1A07 = 02 90
$9FF0 = original/source byte $1A02
RET A=AC with carry set
```

The verifier compares all 4096 bytes of staged Bank 2 `$9000-$9FFF` with
visible Bank 3, not only the marker. `$E5` records the first mismatching byte
as low offset/page in `$1A04/$1A05`.

The proof was captured successfully on 2026-07-19. An earlier `LF FAIL=03`
capture belonged to the preceding `$9000` test state, not to the ASM-F2 loader
or this restore proof. The operator then erased `$8000-$EFFF`, ran `L F`, and
sent `asm-v1-flash-8000.s19`; that valid recovery sequence returned
`LF OK WR=3C6D GO=800C` and entered ASM-F2 `00.0719(1841)`.

When a reload is needed, the intended procedure remains:

```text
L F
  send the current ASM-F2 flash S19
ASM NEW
  confirm the expected ASM-F2 banner, then exit with .
```

## Gate 2: Injected Failure After The Live Top Sector

The installed worker has no software argument that reliably makes a healthy
flash chip fail erase/program/verify. Power interruption, hardware write
protection, or intentionally damaging `$F000-$FFFF` would not be a controlled
test. This fixture therefore applies a reviewed patch to the RAM copy only.

Before writing, it byte-compares Bank 2 and Bank 3 `$C000-$FFFF`. A mismatch
returns `$E5` without modifying flash. It then stages an exact copy of live
Bank 2 `$F000-$FFFF` at `$0A00-$19FF`, verifies the current worker bytes at
`$0275-$0279`, and injects carry-clear only after high restore has erased,
programmed, and verified Bank 3 `$F000-$FFFF` and advances its sector mark to
`$00`.

The revised frozen source passed this board ASM-F2's clean assembly and dry
latch on 2026-07-19:

```text
RET A=E0 X=30 Y=30 P=F4 ... C=0
$1A00-$1A07 = E0 00 00 00 00 00 02 03
```

Its armed run then returned `A=E5`, `Y=FE`, and carry clear before the worker
was patched or any high flash was written. This is the designed source-match
guard, not a Gate 2 failure. The current Bank 2 source predates the Bank 3
HIMON update, so the two top images are not interchangeable.

On any `$E5`, immediately capture `D 1A00 1A07` before replacing either bank.
The row records the first mismatch as `FAIL-LO` at `$1A03`, `FAIL-PAGE` at
`$1A04`, and sector high byte at `$1A05`; it remains a nonwriting result.

### Establish a deliberate matched Bank 2 source

Do this only if replacing Bank 1 and Bank 2 is intended. With `B0 HOLD`, the
normal STR8 backup rotation erases Bank 1 and Bank 2, copies Bank 2 to Bank 1,
then copies the current complete Bank 3 image to Bank 2. It is the required
way to make the high-test source exactly equal to the live target:

```text
STR8
  answer y to HIMON's RUN confirmation
  press S during "HIMON IN 3S"
B
BACKUP ERASE B1/B2. Y: y
  answer y only after confirming Bank 1 may be replaced
```

Require `COPY B2->B1`, `COPY B3->B2`, and `OK`. Then return warm to HIMON and
paste the unchanged high fixture again with `ARM EQU $00`; require the clean
dry result above. Reassemble it with `ARM EQU $A5` only when ready to commit
the terminal test: after a successful source-match preflight it immediately
patches the RAM worker and starts the high restore. This rotation is a
deliberate backup operation, not part of the injected-failure proof itself.

The actual installed worker must then take its high-mode failure branch,
reselect Bank 3, reset the flash command state, disable IRQ, and halt forever
instead of returning through replaced ROM. The newly written top sector can
then be compared byte-for-byte with its retained source after hardware reset.

### Dry latch check

```text
ASM NEW
  paste ASM/SAMPLES/str8-highfail-inject-3000.a unchanged
.
G 3000
D 1A00 1A07
```

Require `$1A00=$E0` and carry clear.

The board assembler must also exit cleanly with `ASM BYE` and no `ERR=$03`.
The fixture uses five explicit patch-byte constants because this ASM-F2 build
does not accept `PATCH+offset` in an absolute memory operand. A prior
preflight stopped at those parser errors and returned `$E2`; it did not arm or
write high flash. Re-run this dry check against the frozen hash above before
changing `ARM`.

### Run the destructive injected failure

Reassemble after changing only:

```text
ARM     EQU $A5
```

Then:

```text
G 3000
```

Expected behavior is deliberately terminal:

- there is no `#GO# ... RET`, prompt, or automatic reset;
- Ctrl-C does not recover the command;
- all Bank 3 `$8000-$FFFF` has been copied and verified from Bank 2;
- the injected failure is taken after the top-sector transaction completes.

Allow at least 60 seconds for the eight sector transactions before deciding
that the CPU is in the expected halt loop. Then press the physical RESET
button. Do not power-cycle: the retained RAM snapshot and result row are part
of the proof.

Press `S` during the STR8 countdown. Reaching the STR8 prompt proves the
failure path left Bank 3 selected and its reset vector executable. Enter HIMON
warm and run the retained verifier:

```text
G
G 3003
D 1A00 1A07
D FFFA FFFF
```

Required proof on the pinned image:

```text
$1A00-$1A07 = AC 00 5A 00 00 F0 02 03
$FFFA-$FFFF = 92 F0 00 F0 A6 F0
RET A=AC with carry set
```

The `$AC` verifier result means all 4096 live top-sector bytes equal the
retained Bank-2 source. `$00` proves the F-sector transaction completed and
the sector mark wrapped, and `$5A` proves the guarded RAM hook was installed.
`$E2` is a safe map mismatch;
review the current worker map and create a new fixture rather than changing
patch bytes at the prompt. `$E4` means the top-sector comparison failed and
the board must be treated as programmer-recovery-only.

After capturing the proof, use the recovery procedure described for Gate 1.
The proven recovery sequence is to erase the intended low-flash range first,
then use `L F` with the current `asm-v1-flash-8000.s19` and confirm `LF OK`.

### Hardware Result: Pass

After the source-match stop, STR8 completed the intentional B3-to-B2 backup
rotation (`COPY B2->B1`, `COPY B3->B2`, `OK`) so the two complete images were
identical. The parser-safe fixture again passed its dry latch. Its armed
`G 3000` produced no normal `RET`; the board restarted through STR8 and, after
warm HIMON entry, the retained verifier produced:

```text
RET A=AC X=33 Y=00 P=F5 S=FD NV-BdIzC
$1A00-$1A07 = AC 00 5A 00 00 F0 02 03
$FFFA-$FFFF = 92 F0 00 F0 A6 F0
```

This closes Gate 2 for STR8-N V0 `#5F6A0F7A` with HIMON `00.0719(1841)` and
the Bank-2-restored ASM-F2 `00.0718(2045)` lower slice. The proof has the
narrow stated meaning: deterministic post-verify worker failure behavior, not
a physical erase/program failure.

## Scope Of Closure

Both gates are closed for the current pinned image. Together they prove normal
restore over a nonerased lower sector and deterministic high-mode failure after
the live top-sector transaction: no false success, no return through replaced
ROM, Bank 3 reselected, terminal halt, and hardware-reset recovery through the
verified replacement top sector.

It does not prove recovery from a physical failure after `$F000-$FFFF` has
already been erased. On this board that event may remove the only executable
reset path. Such a test requires a genuinely sacrificial top-sector image and
external programmer recovery and is not made safer by calling it a software
fixture.

## Gate Closure Record

The hardware log records both complete execution results, the source-match
stop that protected the board, and the successful post-verify injection.
The earlier `LF FAIL=03` belongs to the preceding `$9000` test state. The
erased-low-flash `L F` recovery is hardware-proven and neither gate has an
open recovery issue.
