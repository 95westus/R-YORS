# OIL .710 On-Board Intensive Test Plan

Release: `.710`

Internal name: OIL

TLA: Online Interactive Linker

Deadline: 2026-07-10 16:20 CDT

Status: host build was reported complete with `make realclean all
asm-session-report`; the board is loaded; the tracked code changes have not yet
been run on the board. This document is the release test rail and size review
for those unproven changes.

## Release Meaning

OIL means the live board can assemble, package, load, link, and run AP bodies
interactively, including resident RJOIN imports and banked AP package sources.
The core release proof is not only that the code builds, but that HIMON can ask
STR8 to stage a banked source sector, resolve AP import relocation rows through
resident FNV records, apply internal AP relocations, and run the result from
RAM.

## Current Layout Facts

These are the current map values to verify against board bytes before calling
the release proved:

```text
HIMON body/data end:             $EFE9
HIMON headroom before STR8:      $0017
STR8 body/data end:              $FC69
STR8 worker storage:             $FCE3-$FFEF
STR8 top-sector hole:            $FC69-$FCE2, $007A bytes
STR8 worker RAM body:            $0200-$050C, $030D bytes
STR8 stable worker service:      $F003
STR8 stable AP import service:   $F006
STR8 IVI entries:                $F092/$F0A6
6502 vectors:                    $FFFA-$FFFF = 92 F0 00 F0 A6 F0
ASM flash body/data end:         $B966
ASM flash headroom before HIMON: $069A
```

Release blocker: the attached board stamp is `HIMON V 00.0709(1413)`. A local
rebuild may have a later minute stamp. The visible HIMON version should be
`.710`, or the release notes must explicitly accept the visible stamp as
intentional.

## Attached Preflight Finding

The 2026-07-09 attached board transcript proves the board restored bank 0 to
bank 3, updated HIMON `$C000-$EFFF`, loaded the reporter, and loaded flash ASM.
It does not prove OIL. It shows the STR8 top sector is still the older full
banner image, not the current OIL map image.

Observed:

```text
STR8 V0 #5F6A0F7A
HIMON V 00.0709(1413)
L OK=06D5 GO=7000
LF OK WR=3966 GO=800C
>D F000 F008
F000: 78 D8 A2 FF 9A 20 36 F0 | 20 | x.... 6.
...
FFF0: FF FF FF FF FF FF FF FF | FF FF 89 F0 00 F0 9D F0 | ................
```

That fails Gate 0 for the current OIL layout. `$F003` and `$F006` are not the
stable service jumps expected by current HIMON, and the vectors are
`89 F0 00 F0 9D F0` instead of `92 F0 00 F0 A6 F0`. The stored worker also
appears in the older `$FDxx` region rather than the current `$FCE3-$FFEF`
layout.

Blocking rule: do not run Gate 3 through Gate 8 from this mixed image. Current
HIMON calls `$F006` after copying an AP body, and `AP Bn` calls `$F003`; with
the old STR8 top sector those addresses are not the OIL services.

Next required action: use the procedure below to load/prove the current STR8
top sector first, then rerun Gate 0. Only after Gate 0 passes should AP
import-link or banked AP testing continue.

## STR8 Top-Sector Update Procedure

This is the dangerous part of OIL `.710`: it erases and rewrites the active
bank 3 `$F000-$FFFF` recovery sector. Do not do this casually. If power fails
or the staged image is wrong, reset may not reach STR8. Have the external
programmer path ready before `G 3003`.

### Host Preparation

Build the full vector-complete bank image and the RAM-staged top-sector S19:

```text
make -C SRC str8-top-stage-s19
```

The target emits:

```text
SRC/BUILD/bin/himon-str8-rom.bin
SRC/BUILD/s19/str8-top-stage-0a00.s19
```

The generated `str8-top-stage-0a00.s19` is not a normal ROM install stream. It
is the top 4K of `himon-str8-rom.bin`, source offset `$7000-$7FFF`, remapped
to RAM `$0A00-$19FF`. It keeps all `$FF` bytes so the staged RAM sector becomes
an exact image of the new top sector, not a patch over the old one.

Required host output checks:

```text
BIN offset range      = 7000-7FFF
Stage address range   = 0A00-19FF
S9 start              = 0A00
S1 data bytes         = 4096
Stage head            = 4C 09 F0 4C 93 F3 4C 9A F3
Stage vectors         = 92 F0 00 F0 A6 F0
```

Do not use `str8-f000.s19` by itself for this job. It does not carry the full
sector image with relocated worker bytes and final vectors.

### Board Preparation

The board should be in HIMON with working `L`, `D`, `G`, and flash ASM. The
attached preflight already showed:

```text
L OK=06D5 GO=7000
LF OK WR=3966 GO=800C
```

Assemble the top-sector writer if it is not already at `$3000`:

```text
ASM NEW
  paste DOC/GUIDES/ASM/SAMPLES/topwr-3000.a
  expected: ASM OK
.
```

If assembly reports `ERR=$06 BAD RANGE PC=$315F` followed by
`ERR=$09 BAD FIX`, the old `topwr-3000.a` was pasted. Use the current sample;
the erase-timeout reset path is now inline so there is no too-far `BRA WRESET`
fixup.

Stage the live top sector into RAM first:

```text
G 3000
D 1A00 1A03
```

Expected:

```text
$1A01 = AC
```

If `$1A01` is not `$AC`, stop. The writer is not safe to use.

Optional old-image sanity checks before overlay:

```text
D 0A00 0A08
D 19FA 19FF
```

On the attached mixed image these should show the old STR8 head and old vector
tail.

### Load The New Staged Sector

Load the host-generated staging stream into RAM:

```text
L
  send SRC/BUILD/s19/str8-top-stage-0a00.s19
```

Expected:

```text
L @0A00
L OK=1000 GO=0A00
```

Before programming flash, prove the staged RAM image:

```text
D 0A00 0A08
  expected: 4C 09 F0 4C 93 F3 4C 9A F3
D 16E3 16F2
  expected: 08 78 AD F0 1F C9 04 F0 ...
D 19FA 19FF
  expected: 92 F0 00 F0 A6 F0
```

Address mapping reminder:

```text
RAM $0A00 = ROM $F000
RAM $16E3 = ROM $FCE3
RAM $19FA = ROM $FFFA
```

If any staged byte is wrong, do not run `G 3003`. Reset is still safe at this
point because flash has not been erased.

### Program The Active Top Sector

Last chance rule: after this command starts, do not reset or power off until it
returns.

```text
G 3003
D 1A00 1A03
```

Expected:

```text
$1A00 = 01
$1A01 = AC
$1A02/$1A03 = 00 00
```

Failure statuses:

```text
$1A01 = E1  erase timeout
$1A01 = E2  program timeout, fail address in $1A02/$1A03
$1A01 = E3  verify mismatch, fail address in $1A02/$1A03
```

If status is not `$AC`, stop and capture the transcript. Do not proceed to OIL
AP tests. Prefer the external programmer recovery path over repeated blind
attempts.

### Verify Before Reset

While still in HIMON, dump the newly programmed ROM bytes:

```text
D F000 F008
  expected: 4C 09 F0 4C 93 F3 4C 9A F3
D FCE3 FCF2
  expected: 08 78 AD F0 1F C9 04 F0 ...
D FFFA FFFF
  expected: 92 F0 00 F0 A6 F0
```

Only then reset:

```text
R
```

or press the hardware reset button. Enter STR8 if desired, then return to HIMON
and rerun Gate 0 exactly. Gate 0 is the release proof that the board is no
longer the mixed old-STR8/current-HIMON image.

### External Programmer Recovery Note

If the board cannot reset after the top-sector write, program physical bank 3
from the current vector-complete image:

```text
full bank 3 image:  SRC/BUILD/bin/himon-str8-rom.bin -> physical $18000-$1FFFF
top sector only:    bin offset $7000-$7FFF           -> physical $1F000-$1FFFF
```

After external recovery, rerun Gate 0 before any AP tests.

## Evidence Rules

- Capture every required pass in `DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md` by
  appending a new transcript block.
- Do not count host build output as board proof.
- Record exact version banner, STR8 entry bytes, vector bytes, test source
  names, AP status bytes, and any visible strings printed by AP payloads.
- Use bank 2 first for destructive banked AP tests. Banks 0 and 1 should be
  used only after bank 2 passes and a restore path is accepted.
- Do not run the top-sector program half of `topwr-3000.a` unless the release
  action is explicitly to update the top sector.

## Gate 0: Identity And Fixed Entries

Purpose: prove the loaded board is the image under review.

Required checks:

```text
Boot/reset: record visible STR8/HIMON banner and version.
D F000 F008
  expected: 4C 09 F0 4C 93 F3 4C 9A F3
D FFFA FFFF
  expected: 92 F0 00 F0 A6 F0
D FCE3 FCF2
  expected: worker head begins 08 78 AD F0 1F C9 04 F0
D 7E1F 7E24
  expected: PACK40 vectors plus clear import pointer, B2 D7 F2 D7 00 00
D 7E25 7E40
  expected: F1 D6 at $7E25, flash request cells clear, 8E D8 at $7E2D,
            AP request/result cells clear
# AP
  expected: AP command hash $3AD53794, entry $C687 in the current map
AP
  expected: usage text AP [Bn] pkg dst
```

Fail this gate if `$F003`, `$F006`, or the vector bytes do not match the map.

## Gate 1: STR8 And HIMON Smoke

Purpose: prove the shortened STR8 banner and stable service jumps did not break
normal board entry.

Run a non-destructive smoke pass:

```text
Reset into STR8 and let it continue to HIMON.
?
M
G HIMON
R
```

Expected result: normal command behavior, no unexpected bank change, and normal
return to HIMON prompt.

## Gate 2: ASM Resident Setup

Purpose: confirm the board has the assembler and reporter used by the OIL tests.

If not already loaded, run:

```text
L
  send SRC/BUILD/s19/asm-session-report-7000.s19
  expected: L OK=06D5 GO=7000
L F
  send SRC/BUILD/s19/asm-v1-flash-8000.s19
  expected current build: LF OK WR=3969 GO=800C
ASM
  expected: ASM-F1
.
```

If low flash already contains the identical ASM image, record the loader result
and continue only if `ASM` enters the flash resident assembler.

## Gate 3: RAM AP Import Link

Purpose: isolate the new STR8 `$F006` AP import-link service before adding
banked source staging.

Use `DOC/GUIDES/ASM/SAMPLES/banked-rjoin-smoke.a` as a RAM package:

```text
ASM NEW
  paste banked-rjoin-smoke.a
PACKAGE $3200
LOAD $3200 $3000
.
G 3000
D 5848 5850
D 7E2D 7E40
G 7000
```

Expected result:

```text
LOAD reports one import relocation row.
AP runs and prints BANK RJOIN.
$5848 = AC
$584A/$584B = resolved BIO_FTDI_PUT_CSTR target
Current map expects SYS_WRITE_CSTRING at $E779, so bytes 79 E7 are expected.
AP status remains zero after success.
Reporter output still parses the package and import count.
```

Fail this gate on `BAD FIX`, missing visible string, wrong status byte, or a
resolved address that does not match the resident FNV record.

## Gate 4: Missing Import Negative Test

Purpose: prove unresolved imports still fail clearly.

Build a tiny AP package that imports a deliberately missing name such as
`OIL_MISSING_SYMBOL`, references it with `JSR OIL_MISSING_SYMBOL`, then package
and load it:

```text
ASM NEW
  paste missing-import AP source
PACKAGE $3200
LOAD $3200 $3000
```

Expected result: `LOAD` fails with `BAD FIX` or AP error `$09`. The failure
must not run the body and must not leave a false success byte in `$5848`.

## Gate 5: Banked AP Without Imports

Purpose: prove `AP Bn pkg dst`, STR8 worker staged-sector copy mode, AP source
range relaxation, and internal AP relocations.

Use `DOC/GUIDES/ASM/SAMPLES/banked-ap-smoke.a` and
`DOC/GUIDES/ASM/SAMPLES/bankput-3000.a`. Start with bank 2:

```text
ASM NEW
  paste banked-ap-smoke.a
PACKAGE $3200
ASM NEW
  paste bankput-3000.a, verify BANK=$02, PKG=$3200, DST=$9000
.
G 3000
D 1A00 1A03
AP B2 $9000 $3000
D 5848 5850
G 7000
```

Expected result:

```text
bankput status $1A00 = AC
AP B2 succeeds.
$5848 = AC
$584A/$584B = relocated TARGET address in the loaded AP body
$5850 = 5A
Reporter output still parses the AP package.
```

After bank 2 passes, repeat for bank 1 and bank 0 only if the release owner
accepts overwriting the `$9000` sector in those backup banks.

## Gate 6: Banked AP With RJOIN Import

Purpose: prove the full OIL path: banked source sector, AP body copy, STR8
resident import linker, HIMON internal relocator, and AP execution.

Use `banked-rjoin-smoke.a` and `bankput-3000.a`, first on bank 2:

```text
ASM NEW
  paste banked-rjoin-smoke.a
PACKAGE $3200
ASM NEW
  paste bankput-3000.a, verify BANK=$02, PKG=$3200, DST=$9000
.
G 3000
D 1A00 1A03
AP B2 $9000 $3000
D 5848 5850
G 7000
```

Expected result:

```text
bankput status $1A00 = AC
AP B2 runs and prints BANK RJOIN.
$5848 = AC
$584A/$584B = resident resolved string-output target, expected 79 E7 now
No BAD FIX, BAD RANGE, or BAD LINE output.
```

This is the primary release gate for OIL.

## Gate 7: Banked AP Error Surface

Purpose: prove the new syntax fails safely.

Run after at least one good banked AP package exists in bank 2:

```text
AP B3 $9000 $3000
  expected: usage or rejected bank
AP B2 $7000 $3000
  expected: APERR=$06 or BAD RANGE
AP B2 $9000 $5000
  expected: APERR=$06 or BAD RANGE
AP B2 $9001 $3000
  expected: APERR=$07 or BAD LINE if header is not valid there
AP B2 $9000 $9000
  expected: APERR=$06 or BAD RANGE
AP B2 $9000 $3000 X
  expected: usage
```

The important proof is that bad inputs do not program flash, do not run random
RAM, and do not report success.

## Gate 8: Overlap And Staging Regression

Purpose: prove the old AP overlap protection remains intact while staged bank
sources are accepted.

Checks:

```text
RAM package at $3200, then LOAD $3200 $3200
  expected: BAD RANGE
AP B2 $9000 $3000
  expected: accepted staged source path after banked package install
```

## Gate 9: Existing Regression Shortlist

Purpose: catch accidental fallout from STR8 worker and service entry changes.

Run the familiar non-destructive checks that fit the remaining release window:

```text
M
G HIMON
R
ASM, then . back to HIMON
reload reporter S19 after any cold boot/RAM ZERO
G 7000 reporter after reload or after each meaningful AP package
```

Only run `topwr-3000.a` as a lab tool:

```text
G 3000
  stage live $F000-$FFFF to $0A00-$19FF
D 1A00 1A03
  expected: stage status AC
```

Do not run `G 3003` from `topwr-3000.a` unless the release task explicitly
includes programming the top sector and a recovery path is ready.

## Final Release Evidence

Before declaring `.710` proved, the transcript should show:

```text
Board identity bytes from Gate 0.
Visible release/version stamp.
At least one RAM AP import-link success.
At least one missing-import failure.
At least one banked no-import AP success.
At least one banked RJOIN AP success.
At least one banked bad-input failure.
Reporter output for the meaningful packages.
No unreviewed top-sector program operation.
```

Board result captured 2026-07-09 in
`DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`: Gates 0 and 3 through 9 passed on
HIMON `V 00.0709(1850)`. Gate 0 showed the fixed STR8 jump table, vectors,
stored worker head, service cells, AP hash entry, and `AP [Bn] pkg dst` usage.
Gates 3 through 9 proved RAM import linking, missing-import failure, banked
AP without imports, banked AP with RJOIN import, banked AP bad-input handling,
overlap rejection plus staged source acceptance, and the regression shortlist.

## Size Review And Optimization Recommendations

The hard limits are plain: HIMON has only `$0017` bytes before STR8, and STR8
has only `$007A` bytes free before the stored worker. ASM has `$069A` bytes
free and is not the urgent size problem for this release.

### 1. Keep .710 Code Frozen Until Board Proof

Plain words: prove the build that is loaded. Do not move furniture in the house
while the inspection is under way.

Pros:

- Lowest deadline risk.
- Gives the OIL transcript one clear build identity.
- Avoids turning an untested feature into two untested features.

Cons:

- Leaves STR8 with only `$007A` bytes free.
- Leaves HIMON with only `$0017` bytes free.
- Pushes cleanup pressure into the next release.

Recommendation: do this for `.710`.

### 2. Add A Host Guard For STR8 Service Entries

Plain words: make the build fail if `$F003` or `$F006` ever drift. Those are now
doorways HIMON depends on.

Pros:

- Cheap protection with no board behavior change.
- Catches ABI breakage before a ROM reaches the board.
- Matches the existing map-check style in the STR8/HIMON build scripts.

Cons:

- Saves no ROM bytes.
- Adds one more layout rule to maintain.

Recommendation: add after `.710` proof, or sooner only if documentation-only
work remains and no firmware bytes change.

### 3. Fold HIMON AP Error Printing

Plain words: HIMON prints AP failures in more than one path. A shared print
tail can likely save a few bytes.

Pros:

- Small HIMON ROM saving, likely around 10 to 14 bytes.
- Keeps the command behavior the same.
- Easy to inspect.

Cons:

- HIMON has very little headroom, so even small edits require a full AP retest.
- The saving is real but not enough to solve future growth by itself.

Recommendation: good first size cleanup after OIL is proved.

### 4. Remove Redundant Bank Range Defense Only If Desperate

Plain words: the bank-staging helper checks the bank again even though the
command parser already limits it. That belt-and-suspenders check costs bytes.

Pros:

- Saves a few HIMON bytes.
- Keeps the external command syntax unchanged.

Cons:

- Makes the helper less safe if another caller uses it later.
- The byte win is small.

Recommendation: do not take this for `.710`; keep it as an emergency option.

### 5. Unify STR8 Worker Buffer Copy Paths

Plain words: the worker now has ordinary copy and active-buffer copy paths. A
single base/end setup could remove duplicated logic.

Pros:

- Possible worker/top-sector saving, roughly tens of bytes.
- Simplifies future worker modes if done cleanly.

Cons:

- Touches restore, backup, program, and staged-sector behavior.
- Requires destructive STR8 regression testing.
- Not safe under the `.710` deadline.

Recommendation: postpone to the next STR8 size pass.

### 6. Move The Heavy AP Import Linker Out Of STR8 Later

Plain words: STR8 should stay the recovery layer. The new linker is useful, but
it is big for the protected top sector. Keep `$F006` as a stable doorway and
later move the heavy work into a R-YORS/HIMON namespace module if the design
allows it.

Pros:

- Could recover meaningful STR8 top-sector space.
- Keeps STR8 closer to its recovery/update job.
- Lets HIMON or a link module own more of the AP policy.

Cons:

- Adds a dependency from AP linking to a larger resident or loadable module.
- Needs a careful ABI story so existing `$F006` callers keep working.
- More design and board proof than fits before `.710`.

Recommendation: strong post-release design candidate, not a `.710` change.

### 7. Share AP Relocation Helpers Between HIMON And STR8

Plain words: HIMON and STR8 both understand AP relocation rows now. One shared
helper contract could reduce duplicated checks.

Pros:

- May save tens of bytes in STR8.
- Reduces the chance that HIMON and STR8 disagree about AP row shape.

Cons:

- Blurs ownership between monitor policy and STR8 service code.
- Makes STR8 less independent if future callers bypass HIMON.

Recommendation: review after the OIL transcript shows the current split works.

### 8. Keep `topwr-3000.a` External

Plain words: the top-sector writer is a useful shop tool, not something to
stuff into resident STR8 right now.

Pros:

- Saves protected ROM space.
- Keeps dangerous write behavior explicit.
- Fits the current recovery-first STR8 philosophy.

Cons:

- Top-sector update remains manual.
- Operator discipline matters.

Recommendation: keep external for `.710`.

### 9. Do Not Spend The Deadline Trimming ASM

Plain words: ASM has room; STR8 and HIMON are the crowded shelves.

Pros:

- Keeps effort focused on the risky new feature path.
- Avoids destabilizing the assembler before AP proof.

Cons:

- ASM still deserves later cleanup.
- Shared helper moves might eventually save bytes across HIMON and ASM.

Recommendation: no ASM size work for `.710` unless a board test finds a defect.
