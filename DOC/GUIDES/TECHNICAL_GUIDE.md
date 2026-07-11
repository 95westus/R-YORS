# R-YORS Technical Guide

This is the canonical technical guide for the current R-YORS, STR8, HIMON,
ASM, and OIL shape. It summarizes the architecture, build products, memory
ownership, flash policy, and source layout without carrying the project story.

For board operation, read [OPERATORS_GUIDE.md](./OPERATORS_GUIDE.md). For the
narrative lane, read [BOOK.md](STORY/BOOK.md),
[HISTORICAL_DOCUMENTS.md](STORY/HISTORICAL_DOCUMENTS.md), and
[../IDEAS.md](../IDEAS.md).

## Product Roles

```text
R-YORS  project/system direction and vocabulary
STR8    reset-time recovery/update guard
IVI     interrupt-vector indirection mechanism
LEAF    future friendly front door over IVI
HIMON   default monitor/debug/catalog/assembler payload
ASM     onboard assembler and AP object producer
OIL     Overlay Integration Layer for AP storage, load, relocation, imports, and run
THE     future hash/catalog resolver environment
```

Current boot relationship:

```text
RESET -> STR8 -> HIMON -> ASM creates AP objects
                         OIL integrates and runs AP objects
```

STR8 should remain useful even when the payload is not HIMON. HIMON is the
bundled workbench and default `$C000` payload, not the reason STR8 exists.

## Current Proof State

As of 2026-05-18, STR8 has hardware proof for:

```text
flash map by bank/sector
backup rotation before and after Bank 0 enrollment
Bank 0 enrollment
fixed $C000-$EFFF S19 update gate
HIMON U1-to-U2 update
bootable OSI BASIC payload through the same gate
bootable fig-FORTH payload through the same gate
high-flash recovery from Bank 2 back to known-good HIMON
```

HIMON has hardware proof for RAM-only debug commands `B`, `B C`, `B L`, `N`,
and `X`, with one-shot breakpoints and `DBG RAM` rejection outside user RAM.

OIL `.710` has hardware proof for RAM, visible-flash, and banked-flash AP
sources; internal relocation; resident RJOIN imports; missing-import rejection;
overlap guards; and execution.

This is still a bench-proven recovery/update guard, not a field-updater or
self-updater release.

## Source Layout

Current source aliases in the docs:

```text
HIMON       SRC/HIMON/
STR8        SRC/STR8/
ROM         ROM support source alias in generated docs
LIB         SRC/LIB/
PROOFS      SRC/PROOFS/ transition lane for current proof scaffolds
APPS        SRC/APPS/ transition lane for current standalone applications
TESTS       SRC/TESTS/ transition lane for current test harnesses
ARCHIVE     SRC/ARCHIVE/ retired source and historical code/data
SRC/tools   host build and support scripts
DOC         hand-written and generated documentation
LOCAL       ignored local source homes
```

Active source lanes should contain only code/data used to create current
onboard R-YORS images or board-ingested data. Current in-use STR8-N, HIMON V,
and ASM-F2 files keep their existing structure until a deliberate replacement
exists. The cleanup plan for retired samples, tests, proofs, demos, and one-off
data lives in
[HISTORICAL_CODE_MIGRATION_PLAN.md](PLANNING/HISTORICAL_CODE_MIGRATION_PLAN.md).

New code/data should be processed on board where practical: through HIMON,
flash ASM-F2, AP packages, STR8 update/install flows, or later managed onboard
records. Host-side sources and generators remain only where they still
bootstrap or regenerate current onboard artifacts.

Physical paths used by the current build:

```text
SRC/HIMON/himon.asm
SRC/HIMON/*.inc
SRC/HIMON/fnv1a-fold.asm
SRC/ASM/asm-v1-core.asm
SRC/ASM/asm-v1-flash.asm
SRC/STR8/str8.asm
SRC/STR8/str8-worker.asm
SRC/LIB/ftdi/*.asm
SRC/LIB/dev/*.asm
SRC/LIB/util/*.asm
```

Generated routine maps intentionally focus on current operational HIMON/STR8
and ROM-support source. Legacy demos, harnesses, games, ACIA/PIA experiments,
and archived monitors are kept out of that operational graph unless promoted.

## Build Products

Primary combined ROM image:

```text
SRC/BUILD/bin/himon-str8-rom.bin
```

Primary install and update streams:

```text
SRC/BUILD/s19/himon-str8-rom-install.s19
SRC/BUILD/s19/himon-str8-himon-update.s19
SRC/BUILD/s19/fig-forth-str8-update.s19
SRC/BUILD/s19/msbasic-osi-str8-update.s19
```

Useful targets:

```text
make all
make release
make release-local
make docs-html
make -C SRC docs
make -C SRC himon
make -C SRC str8
make -C SRC himon-str8-rom-bin
make -C SRC life
make -C SRC himon-str8-himon-update-s19
make -C SRC fig-forth-str8-update-s19
make -C SRC msbasic-osi-str8-update-s19
```

`make docs-html` is an explicit/manual presentation rebuild only. `DOC/HTML`
is ignored and untracked; Markdown remains canonical.

Burnable `.bin` files are exactly one 32K CPU `$8000-$FFFF` bank image. The
file does not encode a bank number; bank placement is managed by the programmer
or by STR8.

## CPU And Flash Model

The W65C02 sees selected flash at `$8000-$FFFF`:

```text
$0000-$7FFF  RAM/I/O decode, same regardless of selected flash bank
$8000-$FFFF  selected 32K flash bank window
```

Physical bank roles:

```text
Bank 3  live boot image
Bank 2  newest backup image
Bank 1  older backup image
Bank 0  base/factory hold until enrolled into rotation
```

The current target live-bank budget is:

```text
$8000-$BFFF   16K low-flash code/data, currently ASM-F2 plus AP packages
$C000-$EFFF   12K payload gate, currently HIMON
$F000-$FFFF    4K STR8 recovery sector
```

In the current `make all` image, `$8000-$BFFF` is no longer empty user scratch:
ASM-F2 is present at `$8000`, and the ASM session reporter AP package is stored
immediately after ASM-F2. STR8 may use less than 4K, but the whole top erase
sector is recovery-owned for V0 policy.

Future bank planning may split the backup model into regions instead of whole
banks. The current sketch treats banks 0 and 1 together as five 12K backup
slots plus one 4K metadata sector for names, labels, origins, checks, and
roles; bank 2 becomes SYS/USR space; bank 3 remains the default boot bank with
`$8000-$BFFF` user-available. This is not current V0 behavior.

## Combined Image Layout

Current combined-image facts:

```text
ASM-F2 base:    $8000
ASM-F2 entry:   $800C
ASM-F2 end:     $B969
ASM report AP:  $B969-$BF78, run with ASMREPORT -> $4800
HIMON entry:     $C000
HIMON body:      $C000-$EFFF
STR8 entry:      $F000
STR8 body:       $F000-$FCC5
STR8 identity:   #5F6A0F7A
marker bytes:    $FA17 = 7A 0F 6A 5F
worker source:   $FCE3-$FFEF
config pocket:   $FFF0-$FFF9
vectors:         $FFFA-$FFFF = 92 F0 00 F0 A6 F0
```

The combined `himon-str8-rom.bin` places HIMON at CPU `$C000`, STR8 at CPU
`$F000`, and the reset vector at file offset `$7FFC`. NMI and IRQ/BRK vectors
enter STR8 IVI stubs first.

`ASMREPORT` is a compact HIMON FNV command wrapper around the built-in ASM
session report AP. The build generates `BUILD/inc/himon-asmreport.inc` from
the ASM-F2 `_END_DATA` map, so the AP source follows the end of ASM-F2; the
current composite image stores it at `$B969` and loads/runs it at `$4800`.

## Boot And Handoff

On reset, STR8:

```text
sets the CPU to a known monitor/recovery state
seeds IVI RAM vector cells with safe defaults
initializes FTDI console I/O
prints the R-YORS banner and countdown
waits for S to enter STR8
jumps to HIMON at $C000 when the countdown expires
```

Current vector path:

```text
NMI      -> STR8 IVI entry at $F092 -> RAM vector $7EFA-$7EFB
RESET    -> STR8 START at $F000
IRQ/BRK  -> STR8 IVI entry at $F0A6 -> RAM vectors $7EFC-$7EFF
```

HIMON patches the RAM targets after handoff. IVI is a mechanism, not a claim
that STR8 owns all interrupt meanings after payload entry.

Payloads that own interrupts may install their own targets:

```text
$7EFA-$7EFB  NMI target
$7EFC-$7EFD  BRK target
$7EFE-$7EFF  non-BRK IRQ target
```

Patch those cells only after the payload's handlers and stack policy are ready.

## STR8 Implementation

STR8 is split into a resident shell and a RAM worker.

Resident STR8:

```text
owns reset-time prompt and countdown
owns command parsing for the recovery prompt
owns fixed S19 update-gate validation
keeps private console helpers as STR8_CON_*
copies the flash worker from ROM to RAM
reports status after the worker restores Bank 3
```

RAM worker:

```text
runs from $0200
switches flash banks
erases and programs selected sectors
copies and verifies bank images
scans sector emptiness for M
restores Bank 3 before returning to resident STR8
```

Current RAM workspace:

```text
$0200-$09FF   flash worker tray, STR8 copied from $FCE3-$FFEF at exact worker length
$0A00-$19FF   sector staging buffer
$1A00-$1FE8   RJOIN/link scratch and reserved low-RAM scratch
$1FE9-$1FFF   STR8 worker/update state board and map bytes
$2000-$4FFF   current AP/member load and run area
$4000-$4FFF   current STR8 high-RAM sector buffer for bank copy
$4000-$6FFF   current staged C/D/E sector buffers during U
```

Banked AP flow keeps storage and execution separate:

```text
bank N package -> $0A00 sector staging buffer -> AP load dst -> run dst
```

STR8 also publishes two stable top-sector service entries for the minimal
banked AP path:

```text
$F003   run selected STR8 worker mode after copying worker to $0200
$F006   link AP import relocation rows against resident RJOIN symbols
```

`M` is read-only from the operator's point of view, but still uses the worker
to switch banks and scan sectors.

Current top-sector reserve policy:

```text
$F000-$FA16  STR8 resident code
             size $0A17 = 2583 bytes

$FA17-$FC68  STR8 resident data
             size $0252 = 594 bytes

$FC69-$FCE2  contiguous unused $FF growth hole
             size $007A = 122 bytes

$FCE3-$FFEF  stored STR8 RAM worker image
             size $030D = 781 bytes
             linked at $0200 inside the $0200-$09FF RAM worker-code tray

$FFF0-$FFF9  STR8 config pocket
             size $000A = 10 bytes

$FFFA-$FFFF  W65C02 vectors
             size $0006 = 6 bytes
```

The working rule is that STR8 code/data grows upward from `$F000`, while the
stored RAM worker is packed against `$FFEF` and grows downward as needed. That
keeps one visible free hole between resident STR8 data and the worker image.
Any future STR8 fast-path cache or private metadata should live in a deliberate
record area, not in a fixed accidental gap. `$FFF0-$FFFF` stays out of general
allocation.

## STR8 Update Gate

The current `U` gate is intentionally narrow:

```text
target range:  $C000-$EFFF
record type:   S1 data records only
S0:            skipped
S9:            ends transfer
outside range: abort before erase
programming:   requires confirmation after S19 validation
```

STR8 stages blank C/D/E sectors in RAM, overlays incoming S19 bytes, asks again,
then erases/writes/verifies the three sectors.

This gate is named `UPDATE HIMON` in the current prompt because HIMON is the
default payload. Technically it is a fixed `$C000-$EFFF` payload installer. The
same path has booted HIMON, OSI BASIC, and fig-FORTH.

## STR8 Backup And Restore

Before Bank 0 enrollment:

```text
B:  Bank 2 -> Bank 1
    Bank 3 -> Bank 2
```

After Bank 0 enrollment:

```text
B:  Bank 1 -> Bank 0
    Bank 2 -> Bank 1
    Bank 3 -> Bank 2
```

Restore commands copy selected backup banks into Bank 3 and verify by read-back
compare. Ordinary restore preserves the protected high region. A separately
confirmed high-flash recovery path exists for restoring known-good HIMON over a
bad `$C000` payload.

Bank 0 enrollment clears bit 0 at `$FFF0`:

```text
bit set/erased  = B0 HOLD
bit cleared     = B0 ROT
```

Leaving rotation requires erase/reflash or deliberate STR8 config rebuild.

## HIMON Implementation

HIMON is the default monitor payload. It owns:

```text
interactive monitor prompt
memory dump and modify
S-record load and guarded flash load
disassembly and assembler direction
trap/debug context
legacy FNV-era command lookup
catalog/hash experiments
```

Current commands are summarized in [OPERATORS_GUIDE.md](./OPERATORS_GUIDE.md).
Detailed debug proof procedure lives in
[HIMON_DEBUG_TESTING.md](HIMON/HIMON_DEBUG_TESTING.md).

## ASM Implementation

ASM v1 is the current onboard assembler direction. It is built from
`SRC/ASM/asm-v1-core.asm`, loads as a RAM runtime at `$2000`, and uses HIMON
resident services through the RJOIN seed stored at `$7E00-$7E01`. Runtime paste
source currently emits proof code around `$7000`; ASM output policy protects the
monitor/debugger/vector/I/O window at `$7E00+`.

Current RAM-session ceilings are 64 global symbols, 128 fixups, 192 report refs,
and 16 label-only local labels per active global scope. The source contract,
status model, and hardware proof trail live in [HASHED_ASM.md](ASM/HASHED_ASM.md)
and [TEST_PLAN.md](ASM/TEST_PLAN.md). The renderable routine-flow map lives in
[ASM_CALL_MAP.md](ASM/ASM_CALL_MAP.md).

## HIMON Debug Policy

HIMON owns the hardware stack on monitor entry. Resume is explicit: rebuild
context and `RTI`.

The current debug implementation is conservative:

```text
debug patch range:  $2000-$79FF
system RAM:         not patchable
I/O:                not patchable
ROM/flash:          not patchable
synthetic trap:     BRK 00
debug stop display: @hhhh
breakpoint mode:    one-shot
```

`BRK 00` is reserved for HIMON's synthetic debug trap. Real `BRK xx` signatures
remain visible as program stops. Future assertion ranges are documented in
[DECISIONS.md](./DECISIONS.md).

## Range Parser Contract

Commands that accept ranges use:

```text
start end       end is inclusive
start +count    count is the number of bytes
```

One- or two-hex-digit end tokens inherit the high byte from `start`. Three- or
four-hex-digit end tokens are full addresses. Bare `D` continues at the next
address using the previous dump length.

The canonical policy is in [DECISIONS.md](./DECISIONS.md). Operator examples
are in [OPERATORS_GUIDE.md](./OPERATORS_GUIDE.md).

## Hash And Catalog State

Current HIMON contains FNV-1a command/routine identity:

```text
routine header HASH      32-bit FNV-1a comment ID
current HIMON commands   FNV-era command records
legacy quote helper      prints FNV-1a32
```

The settled split is:

```text
public name -> FNV-1a32 -> typed record/payload
local table/scope -> CRC16 or short ID -> verified by record context
record/body integrity -> optional CRC32/checksum
```

The hash narrows lookup. Typed records, stored names, and proof text give the
match its meaning. STR8 V0 does not use FNV, CRC16, or CRC32 for recovery
decisions.

## Payload Contract

The current STR8 payload gate is:

```text
$C000        executable entry or jump stub
$C000-$EFFF  bytes accepted by STR8 U
$F000-$FFFF  STR8-owned recovery sector
```

A payload that does not use interrupts can ignore IVI after entry. A payload
that uses NMI, BRK, or IRQ patches the IVI RAM cells after its handlers are
ready.

STR8 protects the update transaction. It does not prove the payload's RAM map,
interrupt policy, console assumptions, or backup history after the operator
runs `B`.

## Future Update Shape

The right shape for future HIMON/STR8 updates is a RAM-resident sector
transaction:

```text
read live destination sector into RAM
merge staged update bytes
program directly if all changes are 1->0
confirm before erase when erase is needed
erase/write full staged sector
verify by read-back compare
restore Bank 3 before printing status
```

STR8 self-update is a special confirmed operation and should end in reset.

Future STR8-N/STRAIGHTEN may become a range-aware flash manager that can pack
regions elsewhere, remember where they came from, and optionally compress
backed-up regions. That needs explicit metadata and verification before it can
replace the current whole-bank recovery model.

## Documentation Shape

Main docs now use a small reader path:

```text
README.md
DOC/INDEX.md
DOC/GUIDES/OPERATORS_GUIDE.md
DOC/GUIDES/TECHNICAL_GUIDE.md
```

Supporting references stay available, but they should not duplicate the whole
operator or architecture explanation. The narrative lane is explicit and kept
out of the main operation path:

```text
DOC/GUIDES/STORY/BOOK.md
DOC/GUIDES/STORY/HISTORICAL_DOCUMENTS.md
DOC/IDEAS.md
```

## Canonical References

```text
OPERATORS_GUIDE.md            board operation and workflows
STR8/PRODUCT_BOUNDARIES.md    product lanes and ownership
DECISIONS.md                  settled calls and command policy
MEMORY/MEMORY_MAP.md          address ownership
REF.md                        compact technical reference
CATALOG/CATALOG.md            callable routine selection view
HIMON/HIMON_MAP.md            readable HIMON capability map
HIMON/HIMON_EDGE_DUMP.md      raw HIMON edge evidence
STR8/STR8_EDGE_DUMP.md        raw STR8 edge evidence
LOGS/HARDWARE_TEST_LOG.md     board transcript validation
DOC/GENERATED/                source-derived maps and reports
```
