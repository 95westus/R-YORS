# STR8 Work Process

This is the working rail for returning to STR8 without reopening the whole
design each time.

## Review Result

Current STR8 is not just a sketch anymore. The code and docs agree on a small
V0 recovery surface:

```text
?          identity and Bank 0 state
B          backup rotation
E          enroll Bank 0 into rotation
U          update HIMON from S19, fixed $C000-$EFFF gate
0/1/2      restore selected backup bank to Bank 3
G          go HIMON
R          reset
```

The current Phase-1 host build runs STR8 from bank 3 `$F000`, stores the RAM
flash worker at `$FCC9-$FFEF`, copies that worker into the `$0200-$09FF` tray, uses
`$1FE9-$1FFF` for worker/update state, stages ordinary copy sectors through
`$4000-$4FFF`, and stages HIMON update sectors through `$4000-$6FFF`.
The top sector also exposes stable service entries at `$F003` for running
selected worker modes, `$F006` as an AP import-link compatibility doorway, and
`$F009` for the V1 validated-record service. `$F00C-$F00F` is `53 52 01 07`.
The linker itself is resident HIMON code; `$F006` selects the AP `LINK`
operation and jumps through HIMON's `$7E2D-$7E2E` AP service vector.

The current build targets are:

```text
make -C SRC all
make -C SRC str8
make -C SRC himon-str8-rom-bin
make -C SRC himon-str8-rom-install-s19
make -C SRC himon-str8-himon-update-s19
make -C SRC fig-forth-str8-update-s19
make -C SRC msbasic-osi-str8-update-s19
```

The hardware log preserves earlier proof of the retired `M` map plus the
current prompt, `G`, burn-check bytes, `B`
backup rotation, `E` / Bank 0 enrollment, post-enrollment B0/B1/B2 rotation,
`U` / `UPDATE HIMON` from visible U1 to visible U2, fig-Forth as a `$C000`
payload, OSI BASIC as a `$C000` payload, and high-flash recovery from the
backup chain. The nonerased ordinary-byte restore proof below `$C000` and the
deterministic post-verify high-flash failure proof both passed on 2026-07-19.
It does not yet prove STR8 self-update or a physical flash failure during an
erase/program operation.

The pasteable fixtures and byte-level operator sequence for the first two gaps
are now frozen in
[STR8_V0_RESTORE_FAILURE_GATES.md](STR8_V0_RESTORE_FAILURE_GATES.md). The
high-restore fixture injects failure after the RAM worker verifies the
replacement `$F000` sector and proves the worker halts rather than returning
through replaced ROM; it deliberately does not claim to simulate a physical
failure during flash erase or programming.

## Start Here

Start with the STR8 V0 acceptance pass.

STR8 has already been proven to work as the recovery path. This pass is not a
first proof. It is the current-build regression pass: rebuild the image we are
about to trust, confirm the known-good behavior is still present, and record
the evidence before adding update machinery.

Do not begin by adding catalog repair, wear maps, or self-update machinery.
Also do not expose `U T`, `U H`, or `U S` as operator commands; those are design
shorthand, not an error-proof user surface. IVI is now the stable vector
mechanism: RESET enters STR8, NMI/IRQ enter STR8 stubs, and payload policy still
lives behind RAM vectors. IVY is only how IVI is pronounced; LEAF is the later
front-door name built on IVI. The next trustworthy step is to show that the
current image still behaves like the proven rescue core on the bench.

V0 acceptance means:

```text
build current artifacts
record exact ROM image identity
run non-destructive STR8 regression smoke
run destructive backup/restore/enroll regression checks with programmer recovery ready
record serial transcript in HARDWARE_TEST_LOG.md
update operator/technical/decision docs if behavior differs from source
only then design the first target-update primitive
```

## Work Loop

Use this loop for each STR8 work item:

1. Read the canonical lane:
   `OPERATORS_GUIDE.md`, `TECHNICAL_GUIDE.md`, `STR8.md`,
   `STR8_DECISION_REFERENCE.md`, `STR8_FLASH_UPDATE_PROPOSAL.md`,
   `BRINGUP.md`, and the latest `HARDWARE_TEST_LOG.md`.
2. Name the work as either V0 proof, V0 fix, proposal, or future STR8-N idea.
3. State the flash ranges touched before editing code.
4. Keep destructive behavior behind the RAM worker or another RAM-safe path.
5. Build the narrow target first, then the combined ROM if needed.
6. Test read-only behavior before destructive behavior.
7. Log hardware evidence when the board proves something.
8. Promote settled behavior into `OPERATORS_GUIDE.md`,
   `TECHNICAL_GUIDE.md`, `BRINGUP.md`, or `STR8_DECISION_REFERENCE.md`;
   leave speculation in `QCC_STR8.md`.

## Acceptance Checklist

Before the next feature, rerun this checklist on hardware for the current build:

```text
Build:
  make -C SRC all
  make -C SRC str8
  make -C SRC himon-str8-rom-bin
  make -C SRC himon-str8-rom-install-s19

Artifact check:
  himon-str8-rom.bin is 32768 bytes
  ASM-F2 starts at CPU $8000 and enters at $800C
  Bank 3 has no built-in ASM report AP; reporter runs from Bank 0 with AP B0 $hhhh $4800
  HIMON starts at CPU $C000
  STR8 starts at CPU $F000
  worker source is CPU $FCC9-$FFEF
  vectors point to STR8 IVI entries: F099/F000/F0AD
  record service/header is F009/F00C-F00F = 53 52 01 07

Non-destructive STR8:
  reset enters STR8 countdown
  S reaches STR8 prompt
  ? prints identity and B0 state
  U rejects out-of-range S19 before erase
  G enters HIMON
  R resets through the live vector

Destructive STR8, separate bench pass:
  B before Bank 0 enrollment rotates 2->1 and 3->2
  lower-sector nonerased collision gate passed 2026-07-19 (`AC 56`)
  E confirms and clears the Bank 0 rotation flag
  B after enrollment rotates 1->0, 2->1, and 3->2
  restore abort path leaves Bank 3 selected and STR8 usable
  injected high-flash post-verify failure gate passed 2026-07-19
```

Use [STR8_V0_RESTORE_FAILURE_GATES.md](STR8_V0_RESTORE_FAILURE_GATES.md) for
the guarded lower-sector collision and high-mode post-verify failure procedures.
Both fixtures default to a nonwriting `ARM=$00` latch.

Do not combine first-time destructive proofs. If a pass can erase Bank 0,
rewrite Bank 3, or touch high flash, give it its own transcript and recovery
plan.

## First HIMON Install/Update Proof

The first plain bench proof passed on 2026-05-17. The operator transcript showed
the intended update shape:

```text
Bank 3 booted known-good HIMON U1
B copied Bank 3 -> Bank 2
U received compact C000-EFFF S19 and programmed HIMON U2
boot showed HIMON U2
G F000 reached STR8 after the update
high-flash restore Bank 2 -> Bank 3 restored HIMON U1
```

This is the first useful `UPDATE HIMON` proof, not an external-programmer
exercise. STR8 received the candidate through the HIMON target path, enforced
the `$C000-$EFFF` gate, staged sectors, and asked before erase/write. The proof
is still partial because it does not prove every future transport or STR8
self-update case. It proves the part that matters first: a bad HIMON does not
trap the board, because STR8 is still present and Bank 2 holds the last
known-good image.

Current STR8 restore has two answers. A normal `2` restore with the high-flash
warning declined preserves `$C000-$FFFF`, so it will not replace a bad HIMON.
To recover a bad HIMON with today's command set, Bank 2 must be known good and
the operator must intentionally accept the high-flash restore warning:

```text
FLASH C000-FFFF? Y
```

That path is more dangerous because it also rewrites the top sector. Use it
only for this controlled proof, with the external programmer treated as the
last-resort recovery choice for a bricked board.

Make the HIMON change obvious. A different banner, version string, or prompt is
enough. Do not rely on a hidden byte change for this test; the transcript should
show old monitor, backup, new monitor, and restore-to-old monitor if recovery is
needed.

For this proof, keep STR8 fixed. The intended update candidate is HIMON only:
`$C000-$EFFF` accepted, `$F000-$FFFF` refused. If an emergency programmer image
or other whole-ROM image is used outside the normal test path, say that in the
log and do not count it as proving `UPDATE HIMON`.

## Planned Smart Backup Guidelines

The current implementation still uses whole-bank backup and restore. The agreed
next direction is a managed 64K arena across banks 0 and 1, with bank 2 kept
available for `rcat`/`hrec`/`rrec`, SYS/USR tools, and related records.

Planned bank 0/1 layout:

```text
bank 0 $8000-$8FFF   metadata/catalog sector
bank 0 $9000-$FFFF   payload slots 0-6
bank 1 $8000-$EFFF   payload slots 7-13
bank 1 $F000-$FFFF   reserved STR8_TOP_SAFE payload slot
```

That leaves 56K for ordinary managed backups plus one raw 4K top-sector rescue
slot. If `STR8_TOP_SAFE` is not populated, it is still held out of ordinary
allocation when a STR8 self-update is possible.

Payload slots are raw 4K flash-sector images. Do not put headers in them.
Metadata belongs in the catalog sector: source bank/range, destination slot,
type label, version string when recognized, CRC/hash, verify status, and commit
state. The catalog should be append-only enough that the last complete
committed snapshot wins after reset.

The smart backup user surface should classify first, then mutate only after the
operator chooses the writing command:

```text
BACKUP CHECK 8000-FFFF   scan, classify, and print only
BACKUP 8000-FFFF         copy non-empty sectors, verify, and catalog
CATALOG                  show committed snapshots and reserved slots
```

`BACKUP 8000-FFFF` scans in 4K windows. Erased windows are recorded as erased
in metadata and do not consume payload slots. Non-empty windows are copied,
read back, verified byte-for-byte, and cataloged only after verification:

```text
8000 EMPTY SKIP
9000 EMPTY SKIP
A000 EMPTY SKIP
B000 EMPTY SKIP
C000 SIG FOUND: HIMON V 00.0520(1342)
C000 BANK0:9000 COPIED VERIFIED CATALOGED
F000 SIG FOUND: STR8  V 00.0520(1842)Z
F000 BANK1:F000 COPIED VERIFIED CATALOGED
```

For top-sector updates on W65C02SXB/EDU, remember the limit: a corrupted active
bank 3 `$F000-$FFFF` sector cannot be rescued by onboard software after reset.
The backup is still valuable because it gives an external programmer a known
physical source sector to copy back to physical `$1F000-$1FFFF`.

## Future AP Package Install Rail

AP v1 package install starts as object storage, not execution. A first
`INSTALL` path may search managed flash for an erased hole large enough for the
package envelope, copy the envelope bytes from RAM or another flash location,
read back the programmed bytes, and catalog the result as unvalidated. That is
useful even before a full AP validator exists, but unvalidated packages must
not be run, published to RJOIN, or treated as trusted code.

Keep three facts separate:

```text
envelope location     where the AP package bytes live
body execution base   where the BODY bytes will run
catalog status        whether write, verify, validation, and commit happened
```

For the banked AP direction, the retained RAM envelope location is the
`$0A00-$19FF` sector staging buffer. That buffer can hold a complete 4K
flash-sector image or one banked AP package envelope copied from banks 0-2. It
is staging only; AP BODY bytes run from the requested load address after
relocation/linking.

Moving the envelope does not require relocation. Loading or installing the BODY
to execute at a different base does require relocation through the package REL
section. A future loader can copy an installed package back to RAM as an
envelope, retain that envelope in the sector staging buffer, load the BODY into
RAM for execution, or create a relocated executable flash artifact, but those
are distinct operations. The banked AP overlay-call proposal is parked in
`DOC/GUIDES/QCC/STR8.md` until it becomes implementation work.

Use a flash lifecycle/status byte separate from the HREC/RJOIN `K` kind byte.
The erased value is `$FF`; install phases clear bits as they complete:

```text
$FF        erased / empty / never committed
bit clear  write started
bit clear  flash readback verified
bit clear  AP package validated
bit clear  imports resolved / load-ready
bit clear  committed / active
```

`K` answers "what kind of record or callable thing is this?" and should come
from source/package metadata. The lifecycle byte answers "how far did this
flash install transaction get?" and is written by STR8/catalog code.

## Code Rules

Keep STR8 small and literal:

```text
new destructive commands use full words or stronger confirmation
operator update choices name HIMON or STR8, not a vague target/range
V0 verification is read-back compare, not FNV
Bank 3 must be restored before resident STR8 prints status
the worker must not call ROM or HIMON while banks can change
NMI is not part of the flash-mutation control path
Bank 0 policy changes only through enrollment or an explicit future rebuild
top-sector changes are full-sector transactions
```

The current one-key destructive commands are transition debt and proof surface.
They are not the pattern for new destructive commands.

## Documentation Rule

Every STR8 change should leave one of these behind:

```text
OPERATORS_GUIDE.md           operator behavior changed
TECHNICAL_GUIDE.md           architecture or payload contract changed
HARDWARE_TEST_LOG.md         bench behavior was proved
STR8_DECISION_REFERENCE.md   settled design behavior changed
STR8_FLASH_UPDATE_PROPOSAL.md update proposal changed
QCC_STR8.md                  open question or future direction changed
BRINGUP.md                   bringup/checklist changed
TODO.md                      next work changed
```

Generated HTML is only a presentation view. Markdown remains canonical.

## Current Update Path

The first implemented target/range sector-rebuild primitive is the compact `U`
command. It is the fixed HIMON profile of the longer guided update idea:

```text
U
UPDATE HIMON
```

`U` prints the HIMON range, receives S19, rejects anything outside
`$C000-$EFFF`, stages a blank C/D/E image in RAM, overlays the received bytes,
and asks before programming. The
future broader operator-facing surface may still become:

```text
UPDATE
UPDATE HIMON
UPDATE STR8
```

`UPDATE` by itself would print a small menu. `UPDATE STR8` still prints the
top-sector danger and requires stronger confirmation.

The first S19 load path has two fixed gates:

```text
U / UPDATE HIMON accepts only $C000-$EFFF records.
UPDATE STR8 accepts only $F000-$FFFF records.
```

Do not add a mixed or raw-range S19 loader first. If a record lands outside the
selected gate, the operation aborts before erase.

After the current ASM flash-wrapper work settles, the next STR8 staging
change should move the 4K sector buffer down into STR8-owned low RAM. The older
`$0900-$18FF` active-image sketch is superseded/deferred; the agreed low-RAM
sector staging buffer is `$0A00-$19FF`, immediately after the `$0200-$09FF`
flash worker tray. The existing `$1FE9-$1FFF` worker/update board remains
separate.

That change would free `$4000-$6FFF` from STR8 update staging. Ordinary bank
copy can still stage one 4K sector at a time in the sector staging buffer.
HIMON update should become a sector-streaming operation: fill the low 4K image
for `$C000`, erase/write/verify `$C000`, then repeat for `$D000` and `$E000`.
This trades the current "validate the whole C/D/E S19 before burn" shape for
lower RAM pressure; keep the `$C000-$EFFF` gate, record checksum checks,
confirmation, and STR8 recovery path intact.

The 2026-05-17 fig-Forth and OSI BASIC bench passes proved that this same gate
can install different `$C000-$EFFF` payloads while leaving STR8 alive in the top
sector. That is useful for payload experiments, but it also makes the
backup-chain rule more visible: after the payload is in Bank 3, `B` rotates
that payload into Bank 2. Only run `B` after a payload when that is the
intended promotion.

This still preserves the product split:

```text
STR8 keeps recovery and dangerous flash writes safe.
IVI is the stable vector mechanism, not the policy owner.
Future LEAF routines may patch IVI targets after handoff.
Payloads do not become allowed to rewrite STR8 casually.
```

That means:

```text
stage complete 4K destination sectors in RAM
merge incoming bytes into the blank staged sector image
confirm before erase/write
erase, write, and verify each selected full sector
restore Bank 3 before reporting
refuse the selected STR8 protected window unless this is an explicit STR8 path
```

Only after that primitive is dull should STR8 self-update enter the work queue.
