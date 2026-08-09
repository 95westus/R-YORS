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

Current hardware-proven behavior keeps physical reset and timeout rooted in
Bank 3 STR8 while a RAM trampoline boots an opaque Bank 0-2 image through that
bank's reset vector. Each target owns its complete `$8000-$FFFF`; its top sector
may contain STR8, WOZMON, another monitor, or any system-specific code. No
target BPB or shared STR8 ABI is required. After handoff Bank 3 is unmapped, so
physical reset is the universal recovery path. See
[STR8_J012_OPAQUE_BANK_PLAN.md](PLANNING/STR8_J012_OPAQUE_BANK_PLAN.md).

On physical reset, board pull-ups can select Bank 3 while the VIA PCR remains
in its reset/input state and `$7FEC & $EE` reads `$00`. PCR is a canonical bank
identifier only after software writes one of `$CC/$CE/$EC/$EE`. Reset-time
Bank-3 proof must use the physical-reset invariant plus trusted visible image
bytes; forcing PCR to `$EE` during common STR8 startup would break a copied
Bank-0/1/2 image by remapping Bank 3.

STR8 is the shared S19 decode/checksum and flash-mutation boundary; HIMON
retains its RAM-load user interface and policy. The record service validates a
complete record before applying policy. S2/S8 (`.s28`) remains a possible
`V2.xxx`/`V3` linear physical-flash transport, not a change to the 16-bit
runtime. The validate-first S19 record service and V1.02 `I` range installer are
current and hardware-proven; Intel HEX16, counted BIN/CRC16, S2/S8, and managed
append-only volumes remain proposed interfaces rather than current commands.
The retained loader/volume design lives in
[STR8_MULTIBOOT_BANK_VOLUMES.md](PLANNING/STR8_MULTIBOOT_BANK_VOLUMES.md).

## Current Proof State

The hardware log preserves proof for:

```text
flash map by bank/sector
retired backup rotation before and after retired Bank 0 enrollment
fixed $C000-$EFFF S19 update gate
HIMON U1-to-U2 update
bootable OSI BASIC payload through the same gate
bootable fig-FORTH payload through the same gate
high-flash recovery from Bank 2 back to known-good HIMON
```

V1.02 removes rotation, enrollment, backup, and restore from the resident
surface. The `I` selected-bank/range installer, reset-time selector,
non-destructive `J0`-`J3` handoff, and Bank Jump Record are hardware-accepted;
see
[STR8_BANK_JUMP_RECORD_BOARD_TEST.md](STR8/STR8_BANK_JUMP_RECORD_BOARD_TEST.md).

HIMON has hardware proof for RAM-only debug commands `B`, `B C`, `B L`, `N`,
and `X`, with one-shot breakpoints and `DBG RAM` rejection outside user RAM.

OIL `.710` has hardware proof for RAM, visible-flash, and banked-flash AP
sources; internal relocation; resident RJOIN imports; missing-import rejection;
overlap guards; and execution in its original layout. After the AP linker moved
from STR8 into HIMON, the positive RAM-import, missing-import atomicity, and
banked-source RJOIN regressions all passed on the current image.

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

Primary install stream:

```text
SRC/BUILD/s19/himon-str8-rom-install.s19
```

V1.02 compatibility and focused `I` streams:

```text
SRC/BUILD/s19/himon-str8-v1-install.s19
SRC/BUILD/s19/str8-v1-i-bank012.s19
SRC/BUILD/s19/str8-v1-i-asm-8-b.s19
SRC/BUILD/s19/str8-v1-i-himon-c-e.s19
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
make -C SRC str8-v1-artifact
make -C SRC life
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
Bank 3    reset/default V1.02 supervisor image
Banks 0-2 opaque installed 32K systems; bank number carries no system meaning
```

The current target live-bank budget is:

```text
$8000-$BFFF   16K low-flash code/data, currently ASM-F2 plus AP packages
$C000-$EFFF   12K payload gate, currently HIMON
$F000-$FFFF    4K STR8 recovery sector
```

In the current `make all` image, `$8000-$BFFF` is no longer empty user scratch:
ASM-F2 is present at `$8000`. The ASM session reporter AP is not stored in Bank
3; keep that fixed-address reporter as a Bank 0 AP package and run it with
`AP B0 $hhhh $4800`. STR8 may use less than 4K, but the whole top erase sector
is recovery-owned by Bank-3 V1 policy.

Future managed-volume planning may assign regions inside opaque banks. The
current sketch uses 4K slots plus metadata for names, origins, checks, and
roles. It is not part of the V1.02 installer contract.

## Combined Image Layout

Current combined-image facts:

```text
ASM-F2 base:    $8000
ASM-F2 entry:   $800C
ASM-F2 end:     $BC6D
ASM low hole:   $BC6D-$BFFF
ASM report AP:  Bank 0 package, run with AP B0 $hhhh $4800
HIMON entry:     $C000
HIMON body:      $C000-$EEFF
STR8 entry:      $F000
STR8 resident:   $F000-$FE5E
free/reserve:    $FE5F-$FF1E, $00C0 bytes
jump worker:     $FF1F-$FFAF
V1 directory:    $FFB0-$FFEF
config pocket:   $FFF0-$FFF9
vectors:         $FFFA-$FFFF = 9C F0 00 F0 B0 F0
```

The combined `himon-str8-rom.bin` places HIMON at CPU `$C000`, STR8 at CPU
`$F000`, and the reset vector at file offset `$7FFC`. NMI and IRQ/BRK vectors
enter STR8 IVI stubs first.

The ASM session reporter is deliberately outside the Bank 3 composite image.
Build it with `make -C SRC asm-session-report`, store the AP package in Bank 0,
and run it with the banked AP command at its selected store address.

## Boot And Handoff

On reset, STR8:

```text
sets the CPU to a known monitor/recovery state
seeds IVI RAM vector cells with safe defaults
initializes FTDI console I/O
prints 16 dots over about 5.991 seconds and drains queued RX
prints `STR8-N V 00.mmdd(hhmm) $F` from the resident `$F000` build
opens an approximately 6-second 0/1/2/H/S selector
times out to enter Bank 3 HIMON cold
accepts H to enter the local HIMON warm without changing banks and preserve RAM
requires `A5 5A C3 3C` at `$C003-$C006` for H; otherwise prints `NO HIMON`
accepts S/s to enter STR8
accepts 0/1/2, announces the bank, waits about 3 more seconds, then uses the J handoff
```

Current vector path:

```text
NMI      -> STR8 IVI entry at $F09C -> RAM vector $7EFA-$7EFB
RESET    -> STR8 START at $F000
IRQ/BRK  -> STR8 IVI entry at $F0B0 -> RAM vectors $7EFC-$7EFF
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
owns J0-J3 target parsing and pre-jump bank display
owns I metadata/range collection and validated-record policy
keeps private console helpers as STR8_CON_*
copies the jump worker from ROM or receives the exact mutation worker
reports status after the worker restores Bank 3
```

RAM worker:

```text
runs from $0200
the permanent $0200-$0290 jump worker switches banks and validates/enters reset vectors
an I stream uploads the exact $0200-$042A mutation worker before any payload
the uploaded worker erases/programs/verifies selected sectors and journals the transaction
restores Bank 3 before returning on ordinary worker success/failure
```

Current RAM workspace:

```text
$0200-$09FF   flash worker tray; resident jump worker or uploaded mutation worker
$0A00-$19FF   sector staging buffer
$1A00-$1FE8   RJOIN/link scratch and reserved low-RAM scratch
$1FE9-$1FFF   STR8 worker/update state board and map bytes
$2000-$4FFF   current AP/member load and run area
```

The RSC tail publishes the last successful opaque-bank handoff as a signed
Bank Jump Record: `$1FFD-$1FFF = 42 4A nn`, where `nn` is Bank 0 through 3.
`42 4A FF` means no valid target is known. The STR8 RAM worker commits the
record immediately before the final jump, and HIMON preserves it through cold
RAM clearing so it can be inspected later with `D 1FFD 1FFF`.

Banked AP flow keeps storage and execution separate:

```text
bank N package -> $0A00 sector staging buffer -> AP load dst -> run dst
```

STR8 also publishes two stable top-sector service entries for the minimal
banked AP path:

```text
$F003   copy/run the permanent jump worker; mutation modes fail closed here
$F006   retired AP-link slot: CLC/RTS/NOP
$F009   RFD: V1 validated-record operation multiplexer
$F00C-$F00F  `53 52 01 07`: `SR`, ABI 1, buffer/console/`L F` capabilities
$F010   bank-selection service for RAM callers; returns through $0203
```

The retired STR8 `M` map used the worker to switch banks and scan sectors. Its
hardware transcript remains evidence, but it is not in the current prompt.

Current top-sector reserve policy:

```text
$F000-$FD32  STR8 resident code
             size $0D33 = 3379 bytes

$FD33-$FE5E  STR8 resident data
             size $012C = 300 bytes

$FE5F-$FF1E  contiguous free/reserve gap
             size $00C0 = 192 bytes: $0040 reserve plus $0080 growth

$FF1F-$FFAF  stored jump-only STR8 RAM worker image
             size $0091 = 145 bytes
             linked at $0200 inside the $0200-$09FF RAM worker-code tray

$FFB0-$FFEF  fixed V1 directory
             size $0040 = 64 bytes; erased in a new primary image

$FFF0-$FFF9  STR8 config pocket
             size $000A = 10 bytes

$FFFA-$FFFF  W65C02 vectors
             size $0006 = 6 bytes
```

The working rule is that STR8 code/data grows upward from `$F000`. The fixed V1
directory owns `$FFB0-$FFEF`, and the jump worker is packed immediately below
it. The visible `$FE5F-$FF1E` gap is both growth room and reserve; `$0040` of
its current `$00C0` bytes is mandatory. `$FFF0-$FFFF` stays out of general
allocation.

## STR8 V1.02 Install Gate

`I` selects a destination bank and an inclusive 4K-sector range. Banks 0-2
permit `$8000-$FFFF`; Bank 3 permits `$8000-$EFFF` and always rejects sector F.
A single sector is 4K, so the same receiver handles 4K through 32K on Banks
0-2 and 4K through 28K on Bank 3.

The transaction contract is:

```text
operator:      select bank, range, and new metadata when no record exists
confirmation:  exact Y after the directory/metadata preview
transport:     exact mutation worker first, then dense in-order S1 data
S9:            required transfer terminator; entry must fit the selected image
range errors:  bad start/end, gap, overlap, or out-of-range data aborts
programming:   one staged 4K sector at a time, erase/program/read-back verify
commit:        journal START before payload mutation and COMPLETE last
return:        restore Bank 3 before resident STR8 resumes
```

The host matrix covers every legal bank/range pair and rejects malformed
ranges, bad records, gaps, overlaps, bad S9, and Bank-3 sector F. Hardware has
accepted representative 16K `$8000-$BFFF` and 12K `$C000-$EFFF` transactions.

This install result is not H/P/V/C qualification of an unrelated opaque 32K
image entered through `Jn`. Use
[STR8_GUEST_IMAGE_QUALIFICATION.md](STR8/STR8_GUEST_IMAGE_QUALIFICATION.md)
before promoting such an image. Arbitrary destructive maintenance is kept out
of resident STR8; use the explicit `str8-bank-maint` tool with its carried
mutation worker and recovery procedure.

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

For AP packages, `ENTRY` is the public front door, `EXPORT` publishes other
defined global labels, and `IMPORT` force-defers binding to load time. A plain
undeclared resident `JSR`/`JMP` binds now against the HIMON/RJOIN image running
the assembler and emits that concrete address. An imported call instead emits
placeholder bytes plus import relocation rows; OIL/HIMON/STR8 resolves and
patches those rows when the AP body is loaded. Current package metadata limits
are 8 exports and 8 imports; the tighter practical AP limit is often the shared
16-row relocation table.

The low-RAM split moved symbol names to `$0200-$09FF` and fixup names to
`$0A00-$19FF`, freeing high ASM workspace and giving STR8 a 4K sector staging
buffer after `PACKAGE` has serialized the needed metadata. It changed pressure
and placement, not the hard row ceilings by itself. Expand fixup/relocation
capacity before symbols/locals, and expand import/export slots last.

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

Current `D` is the deliberate exception: `D start [end]` accepts only an
absolute inclusive end, requires it to be greater than start, and has no bare
continuation. Other range-taking commands retain their documented shared
grammar.

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

The current STR8 install envelope is:

```text
Banks 0-2    any 4K-aligned inclusive sector range from 8 through F
Bank 3       any 4K-aligned inclusive sector range from 8 through E
payload      dense, in-order S1 data with a valid in-range S9 entry
transport    exact mutation worker followed by the selected payload range
```

A payload that does not use interrupts can ignore IVI after entry. A payload
that uses NMI, BRK, or IRQ patches the IVI RAM cells after its handlers are
ready.

STR8 protects the update transaction. It does not prove the payload's RAM map,
interrupt policy, console assumptions, or identity after installation.

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

Future STR8-N/STRAIGHTEN may become a catalog-aware flash manager that can pack
regions elsewhere, remember where they came from, and optionally compress
backed-up regions. That needs metadata beyond the current fixed V1 directory
and journal contract.

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
