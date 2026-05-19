# STR8 Recovery Monitor

`STR8` means `Subroutine To Return`. It is pronounced `S-T-R-8`, can also be
read as `Straight 8`, and deliberately echoes `RTS` / Return from Subroutine.

Future naming may let STR8 grow into `STR8-N`, read as `STRAIGHTEN`: a richer
repair/normalization path once the small recovery anchor has proved itself.
That name is a direction, not a promise that the first STR8 must own every
system policy.

Terms such as bank, sector, segment, protected window, owns, uses, requests,
contract, buried, gone, and condense follow [GLOSSARY.md](../GLOSSARY.md).

STR8 is the protected recovery/update monitor for HIMON. It is not
just a crash handler and not just a flash writer. It keeps the machine on a
known-good path while code, routines, data, and banks are being changed.

V0 STR8 is image-oriented recovery: banks 0-2 hold whole 32K ROM images for
backup and restore, while the selected STR8 protected window is flashed through
its own guarded path. HIMON owns catalog lookup, rich command behavior, and
IRQ/vector control in the first version. Future STR8-N/STRAIGHTEN may offer
catalog, compact-hash lookup, scan, repair, and vector-layer services after the
image-recovery path is stable, but it should remain useful to systems that keep
their own memory map, interrupt policy, or runtime supervisor.

Working definition:

```text
STR8 = the top-sector recovery anchor and flash mutation guard.
```

Product-boundary definition: STR8 is the board management product inside
R-YORS. See [PRODUCT_BOUNDARIES.md](PRODUCT_BOUNDARIES.md) for the split
between R-YORS, STR8, IVI/LEAF, HIMON, and peer payload targets.

System relationship:

```text
R-YORS boots through STR8.
STR8 keeps recovery/update safe.
STR8 hands normal operation to HIMON.
HIMON provides the monitor, command dispatch, assembler, catalog lookup,
and debug tools.
```

## Milestone Snapshot

The current STR8 hardware milestone is image rotation and recovery, proven with
three bootable live-bank payloads:

```text
HIMON      recovery/inspection monitor
OSI BASIC  interactive programming payload
fig-FORTH  threaded language payload
```

The board proof covers `M`, `B`, `E`, Bank 0 rotation, the fixed
`$C000-$EFFF` `U` / `UPDATE HIMON` gate, HIMON U1->U2 update, booting OSI
BASIC and fig-FORTH through that same gate, and restoring known-good HIMON from
Bank 2 by the high-flash recovery path. This promotes STR8 from proposed
recovery idea to bench-proven recovery/update guard.

The milestone does not make STR8 a finished field-updater. STR8 self-update,
whole-ROM install, catalog-aware repair, raw range update, and original
WDCMONv2/base-image preservation remain separate future work.

## Core Questions

V0's recovery target is settled:

```text
restore from a whole 32K ROM image in bank 0, 1, or 2
logical image range: $8000-$FFFF
bank 3 restore: write ordinary image bytes by guarded flash flow
protected STR8 window: skip unless explicit STR8 install/update is requested
```

Bank 0 begins as the optional WDCMONv2/base-image hold slot. A future
WDCMONv2-to-R-YORS bridge should offer to save the board's original live base
flash image before conversion, but that preservation flow is a TODO and is not
part of today's STR8 test target.

Until explicitly enrolled, bank 0 is excluded from automatic backup rotation.
The STR8 `E` command enrolls bank 0 after a destructive confirmation and sets a
one-way in-flash flag. The current proof uses bit 0 of `$FFF0`: erased/set
means `B0 HOLD`, cleared means `B0 ROT`. After enrollment, automatic backup
rotates `1 -> 0`, `2 -> 1`, and `3 -> 2`. Bank 0 then remains in the rotation
until erase/reflash or a deliberate STR8 configuration rebuild.

First principle: STR8 cannot safely erase the code it is currently running
from. Self-recovery therefore needs either a protected window that is not erased
during normal updates, or a RAM-resident updater that has already copied all
required flash routines out of the target erase area.

Future open recovery questions remain for self-update, catalog-aware repair,
and richer install/export flows. Those are not V0.

## Recommended Split

Use a two-level model:

```text
STR8 protected window:
  minimal, protected, always recoverable
  provides recovery entry, flash guard state, verifier, and repair hooks

HIMON body:
  normal monitor/catalog/assembler/loader services
  can be updated by STR8
```

The live bank has a deliberate budget target:

```text
$8000-$BFFF   16K user code/data/app space
$C000-$EFFF   12K HIMON monitor/tools budget
$F000-$FFFF    4K STR8 recovery-owned erase sector
```

This is a boundary target, not a panic rule. STR8 should stay inside the top
4K sector and may use less than that. HIMON should fit below `$F000`; growing
past the 12K budget should be an intentional call because it consumes user
code/data space.

The current V0 split is small, W65C02-specific, and gives STR8 the whole
physical top flash sector so recovery code can keep growing without crowding
the vectors.

The physical top erase sector is still `$F000-$FFFF`, because flash erase
granularity is 4K and the hardware vectors live at the top of ROM. The current
combined image uses `$F000-$FFFF` as the protected STR8 top sector:

```text
$FC00-$FFFF  1K protected STR8 window
$FA00-$FFFF  1.5K protected STR8 window
$F800-$FFFF  2K protected STR8 window
$F600-$FFFF  2.5K protected STR8 window
$F400-$FFFF  3K protected STR8 window
$F200-$FFFF  3.5K protected STR8 window
$F000-$FFFF  4K protected STR8 window, current combined image

$FFF0-$FFF9  one-time flash board/version/config bytes, inside the window
$FFFA-$FFFF  W65C02 hardware vector block
```

Protected-window bytes are flashed through a separate install/self-update path.
That path still stages the full top sector and preserves non-target bytes,
because hardware erase granularity is 4K. Ordinary writes must not treat the
selected STR8 protected window as casual free space. Bytes below the chosen
protected start but still inside `$F000-$FFFF` may hold common routines or
HIMON-facing material, but updating them requires the same top-sector
transaction: read the full 4K sector into RAM, update only the allowed bytes in
the staged image, erase `$F000-$FFFF`, write the full staged sector back, and
verify by read-back.

V0 restore still reasons about complete `$8000-$FFFF` ROM images as sources,
but the bank 3 write path skips the selected STR8 protected window unless the
operator explicitly requests a STR8 install/update. The `$FFF0-$FFF9` bytes are
reserved for one-time flash data such as board id, version, and config
information. They can be patched only by clearing bits until the top sector is
erased/rebuilt. The final hardware vector bytes are the W65C02 vector table:

```text
$FFFA-$FFFB  NMI
$FFFC-$FFFD  RESET
$FFFE-$FFFF  IRQ/BRK
```

Those vector bytes remain part of the selected STR8 protected window. They are
treated as vector table rather than normal code storage.

## Vector Integration Policy

V0 HIMON controls IRQ/vector behavior.

Direction change: earlier STR8 notes leaned toward future STR8 ownership of the
final hardware vectors and broader trap authority. After careful
reconsideration by the project author, the direction is softer and more
reusable: STR8 should offer recovery-safe hooks and routines, while the active
system may keep its own memory and interrupt policy.

STR8 should not assume it owns memory management or application interrupt
policy. A board, application, or user-built system may already have its own RAM
map, interrupt discipline, and trap supervisor. STR8 should be useful in that
world as a set of recovery routines and guarded update paths, not as a demand
that the rest of the system reorganize around it.

That keeps STR8 in the R-YORS spirit: routines made from routines, useful as
layers a system can choose and combine rather than a hidden operating-system
claim over the board.

The R-YORS reference path can still route reset/trap behavior through STR8 or a
shared vector layer when that makes recovery safer. The preferred integration is
through explicit hooks such as `SYS_VEC`/IRQ-vector services when they exist,
rather than by silently claiming all practical NMI/BRK/IRQ behavior.

During STR8-owned time, NMI should normally be inert. If an NMI edge arrives
while STR8 is waiting, prompting, or doing recovery work, the reference behavior
is a tiny STR8-safe target that returns with `RTI`; the button press does not
become a command by itself. If STR8 needs operator input, it should poll a key,
event latch, or request flag at safe points.

Future supervisor entry may deliberately open a short boot recognition window
where NMI sets a `STR8_SUP_REQUEST` flag and then returns. STR8 would poll that
flag and choose supervisor/recovery mode before normal HIMON handoff. Before
flash erase/write/verify starts, STR8 should restore inert NMI behavior and
must not depend on asynchronous NMI as an event source.

### Interrupt Vector Indirection

`IVI` means Interrupt Vector Indirection. It came from BSO2 and is pronounced
`IVY`. If a user chooses STR8 as the board's boot/recovery product, STR8 may
reasonably own the hardware vector front door and provide patchable indirect
targets:

```text
RESET    -> STR8 reset supervisor
NMI      -> IVI_NMI
IRQ/BRK  -> IVI_IRQ_BRK

IVI_NMI      -> JMP (IVI_NMI_VEC)
IVI_IRQ_BRK  -> split stacked B flag
  IRQ        -> JMP (IVI_IRQ_VEC)
  BRK        -> decode BRK operand/signature, then dispatch
```

That is mechanism, not permanent interrupt policy. During STR8-owned time,
these targets are safe defaults or recovery handlers. After handoff, the
payload may install its own NMI, IRQ, and BRK targets through the documented
patch points. HIMON can use IVI for NMI/debug re-entry, a real IRQ owner, and a
BRK expansion table; another monitor can install different meanings without
reflashing `$FFFA-$FFFF`.

The product value is simple:

```text
install STR8 once
hardware vectors stay recoverable
payloads patch indirect vectors
BRK services can grow behind one stable IRQ/BRK entry
experiments do not require top-sector vector reflashing
```

Future BRK dispatch can reserve ranges without making STR8 own every meaning:

```text
BRK $00-$7F  payload/user/debug space
BRK $80-$BF  STR8/IVI recovery or board services
BRK $C0-$FF  system/future/reserved
```

The exact ranges are not settled. The important rule is that IVI may split and
route BRK, while the selected payload owns the meanings it claims.

Reference integration rule:

```text
hardware vector -> STR8 entry/trampoline/router -> active handler
```

Reference normal operation:

```text
RESET enters STR8 at $F000
STR8 seeds IVI RAM vectors with safe defaults
STR8 waits for S, or times out to HIMON
STR8 validates HIMON
STR8 hands off to HIMON
HIMON installs NMI/BRK/IRQ handlers through STR8 or SYS_VEC calls
STR8 routes traps to the installed HIMON handlers
```

Reference recovery operation:

```text
HIMON missing/corrupt/unsafe
STR8 ignores or clears HIMON-installed handlers
STR8 routes traps to minimal recovery handlers
```

In the current combined image, STR8 owns the physical vector front door and
HIMON controls the practical trap behavior after handoff by patching the RAM
targets. Systems that already own interrupts can still use the same IVI cells
directly and keep their own policy. LEAF is the newer/friendlier front-door idea
built on this IVI mechanism; it is not a separate policy owner yet.

The code may use W65C02 instructions when they keep the anchor smaller or
clearer. NMOS 6502 portability is not a STR8 V0 goal.

## Recovery I/O Layering

STR8 should talk to the smallest useful layer that keeps recovery independent
and avoids duplicate public catalog providers.

Working rule:

```text
use private STR8_CON_* for V0 console init/read/write/flush
do not publish STR8_CON_* as BIO_*/PIN_* catalog records
keep public BIO_FTDI_* ownership in HIMON/current ROM body
avoid COR_*/SYS_* in the STR8 hot path unless explicitly recovery-safe
```

That accepts a small private code duplicate inside the protected STR8 anchor so
recovery does not depend on HIMON's resident BIO copy, and so the combined image
does not publish a second global `BIO_FTDI_*` provider with the same lookup hash.
`PIN_*` remains the hardware/register edge, `BIO_*` remains the reusable board
I/O contract, and `COR_*`/`SYS_*` sit above that for richer
monitor/application behavior.

Future catalogs should mark the active recovery dependency chain with
`REQUIRED_FOR_RECOVERY` metadata rather than inferring protection from a
`BIO_*` or `PIN_*` prefix. STR8 V0's private `STR8_CON_*` helpers mean HIMON's
public `BIO_FTDI_*` records are not automatically pinned for recovery. If a
later STR8-N path imports shared `BIO_CON_*` or `PIN_*` providers, those exact
providers and their required dependencies become recovery-required until an
explicit recovery update transaction replaces them.

Possible layouts:

```text
Protected top-sector model:
  $8000-$BFFF          app/growth space in the selected ROM bank
  $C000-$E75B          current HIMON body and data
  $E75C-$EFFF          slack inside the used E sector
  $F000-$FFFF          STR8 protected top sector

RAM-updater model:
  special install/self-update path only
  before erasing protected areas, copy updater to RAM and run from RAM
  leave either a valid STR8 sector or a clear external-recovery requirement
```

The protected top-sector model matches the hardware reality that the top 4K
erase sector contains the reset vectors and recovery authority. The whole sector
must be erased and rewritten as a sector when any byte in it changes, but the
protected policy window should be no larger than STR8 actually needs. STR8
should not grow into a full monitor just because the sector is special; HIMON
still owns the rich interactive environment.

## STR8 V0 Constraints

V0 should stay deliberately small:

```text
W65C02-specific code is allowed
first implementation is a RAM-resident S19 launched under HIMON
first RAM proof image links at $3000
first RAM proof reserves $4000-$4FFF as the 4K copy buffer
first RAM proof can perform backup rotation with read-back verify
first RAM proof can enroll bank 0 into rotation by clearing an in-flash flag bit
first RAM proof can restore bank 0, 1, or 2 to bank 3 while preserving STR8 bytes
current ROM build links STR8 at $F000 and stores a RAM worker at $FC00
current ROM build copies the worker to $0200 before B/U/0/1/2 flash mutation
current ROM build copies the worker to $0200 before E config mutation
current ROM build has working ?, B, E, M, U, 0, 1, 2, G, and R commands
current STR8 identity marker is `#5F6A0F7A`
physical top erase sector is bank 3 $F000-$FFFF
current protected STR8 proof window starts at $F000
protected bytes are flashed through a separate STR8 install/update path
non-STR8 top-sector updates use read/stage/erase/full-sector-write/verify
STR8 code/data/recovery lives from selected start through $FFEF
one-time board/version/config window is $FFF0-$FFF9
hardware vector block is $FFFA-$FFFF
V0 uses whole 32K ROM bank images as recovery and backup sources
V0 bank copy uses a 4K RAM buffer one erase sector at a time
V0 HIMON controls IRQ/vector behavior
V0 has no catalog lookup
no flash garbage collection
no relocation replay
no command-text compression in STR8 itself
no rich user interface
```

V0 should do only enough to keep boot and flash mutation recoverable:

```text
reset entry
startup delay before first console output
initialize FTDI/VIA console path directly
leave IRQ/vector policy with HIMON/reference system in V0
boot check
handoff to HIMON
minimal recovery entry
selected STR8 protected-window check
flash write/erase guard hooks
small verify/check routines
```

STR8 V0 verification means fixed-range checks, flash status, byte-for-byte
read-back across restored ordinary image bytes, and separate read-back
verification after any protected-window install/update. Future catalog-owning
STR8 may use compact hash lookups after the CRC16 record shape is settled.

## Boot Relationship

Earlier prototypes could boot directly into HIMON. The current R-YORS/STR8
reference path boots through STR8 first, then hands normal operation to HIMON
or to another image occupying the live `$C000-$EFFF` payload window.

At boot, STR8 should be able to:

- verify the HIMON body enough to decide whether normal boot is safe
- enter recovery mode if the body is missing, partial, or corrupt
- preserve a small failure reason for the user
- provide a minimal serial/FTDI path if the normal monitor body cannot run
- expose flash repair/install commands

In the current implementation, this is mostly policy, fixed gates, guarded
flash mutation, and a small resident prompt. Richer validation and repair can
grow later.

## WDCMONv2 Board-Onboarding Bridge

One desired future path is to let someone buy a stock W65C02SXB-style board and
move from WDCMONv2 into R-YORS without requiring an external ROM/flash
programmer or deep WDC toolchain work.

Author preference: if a T48 programmer is available, directly programming the
flash/ROM remains the cleanest installation method. The bridge exists so a new
board owner can still get to R-YORS using only the stock WDCMONv2 load/run
path.

This bridge is a future option, not a committed STR8 V0 feature. It may never
be implemented, or its final form may have more or fewer features than this
sketch depending on what the board and installer actually need.

This is not the normal path for a board that already has R-YORS/HIMON
flashed and running. It is a first-install ramp for a fresh board.

Working shape:

```text
board boots existing WDCMONv2
user loads a simple BSO2/WDC-style bridge program using WDCMONv2's load/run style
bridge prints/verifies board and firmware identity
bridge uses WDC-style signatures and fixed jump/service vectors where useful
bridge receives or carries STR8/HIMON image data
bridge erases/programs/verifies the target flash region
board reboots through STR8
STR8 validates and hands off to HIMON
```

The bridge is not meant to become the permanent monitor and it should not make
the user live in WDC's methods. It borrows only the stock board's existing
loading path and the simple BSO2/WDC-style program shape so the user can start
from what they already have. Once the bridge is running, its job is to convert
flash to the R-YORS layout.

BSO2 is the model for the structure, not a literal source dependency:

```text
CODE region
board/ROM signature
reset/NMI/IRQ jump trampolines
documented cold-start routine
small board I/O initialization
minimal FTDI/serial byte contract
known load/link address
single-purpose reflash flow
```

That gives the user a plain loader-shaped program that can be started from
WDCMONv2 and then does the controlled conversion to R-YORS.

Useful pieces to preserve from the WDC side:

```text
board/firmware signature   tells the bridge what it is running on
jump/service vectors       give stable callable entry points
simple load/execute path    lets the user start without a dedicated programmer
```

The STR8 side should treat this as an installation authority with extra care:
verify the image, verify the target range, avoid erasing the running bridge,
and leave either a valid STR8 anchor or a clear recovery failure reason.

Possible later nicety: before conversion, STR8 or the bridge may offer to save
or record the original WDCMONv2 image/provenance somewhere safe. That backup
question belongs to the future installer design; it is not required to define
STR8's recovery contract.

## Proposed STR8 Overview Map

This is the future high-level STR8/HIMON shape. It keeps STR8 small while
allowing later catalog-aware flash mutation. V0 is simpler: image-based
restore/verify and backup rotation.

```mermaid
flowchart TD
    RESET[RESET vector] --> STR8_ENTRY[STR8 entry]
    NMI[NMI vector] --> STR8_TRAP[STR8 trap/recovery entry]
    IRQ[IRQ/BRK vector] --> STR8_TRAP

    STR8_ENTRY --> ANCHOR[selected STR8 protected window]
    STR8_TRAP --> ANCHOR
    ANCHOR --> BOOTCHECK[boot/check HIMON body]

    BOOTCHECK --> SAFE{HIMON valid?}
    SAFE -->|yes| HANDOFF[handoff to HIMON]
    SAFE -->|no| RECOVERY[minimal recovery mode]

    HANDOFF --> HIMON[HIMON monitor]
    HIMON --> ASM[hashed ASM / user build]
    ASM --> LF[L F or flash install request]
    LF --> STR8_API[STR8 guard routines]

    RECOVERY --> STR8_API
    STR8_API --> SCAN[scan fixed writable flash ranges]
    SCAN --> CLASSIFY[classify protected, erased, image, unknown]
    CLASSIFY --> CHOOSE[user or fixed policy chooses destination]
    CHOOSE --> RANGE{protected range?}
    RANGE -->|yes| REFUSE[refuse or require recovery authority]
    RANGE -->|no| PLAN[plan write/erase transaction]

    PLAN --> STAGE{RAM staged?}
    STAGE -->|yes| RAMIMG[assemble/verify image in RAM]
    STAGE -->|no| DIRECT[direct erased-flash write]
    RAMIMG --> PROGRAM[program flash bytes]
    DIRECT --> PROGRAM

    PROGRAM --> VERIFY[verify flash]
    VERIFY --> OK{verified?}
    OK -->|no| RECOVERY
    OK -->|yes| CATALOG[future catalog/export commit]
    CATALOG --> RETURN[return to HIMON or recovery prompt]
```

The future core rule is that normal work may begin in HIMON, but flash mutation
can cross a STR8 boundary before bytes are trusted. V0 does not do
catalog-shaped work; it restores and verifies fixed bank images with the
protected STR8 window handled separately.

## Minimal Recovery

Minimal recovery is not full HIMON. It is a small HIMON-lite only in the sense
that it has enough serial I/O and flash safety to repair the machine.

V0 command surface should be closer to this:

```text
?          print tiny STR8 ID/state
B          backup rotation, with verify built in
E          enroll bank 0 into backup rotation, destructive, confirmed
0          restore bank 0 to bank 3, with verify built in
1          restore bank 1 to bank 3, with verify built in
2          restore bank 2 to bank 3, with verify built in
G          go HIMON
R          reset through the live reset vector
```

STR8 keeps `R` as reset. `L S`, `L F`, `GO addr`, standalone verify, catalog
repair, and richer loading are later features. The recovery loader should avoid
the full assembler, full catalog UI, compression tools, and rich command parser.
Those belong in HIMON once normal operation is safe.

There is no casual bank 0 erase command in the first command surface. `E` is the
only Bank 0 policy change: it confirms the destructive consequence, sets the
one-way rotation flag, and lets future `B` commands use bank 0 as the oldest
automatic backup slot.

## Current Command Worker Map

The current ROM build keeps the prompt and text in resident STR8, but runs flash
mutation from RAM:

```mermaid
flowchart TD
    RESET[RESET vector] --> STR8[STR8 shell at $F000]
    STR8 --> PROMPT[STR8 prompt]

    PROMPT --> Q[? ID/state]
    PROMPT --> B[B backup]
    PROMPT --> E[E enroll Bank 0]
    PROMPT --> RST[0/1/2 restore]
    PROMPT --> G[G go HIMON]
    PROMPT --> R[R reset]

    G --> HIMON[HIMON at $C000]
    R --> RESETV[live reset vector]

    B --> COPY[copy worker $FC00 -> $0200]
    E --> COPY
    RST --> COPY
    COPY --> WORKER[RAM flash worker]
    WORKER --> FLASH[bank select / erase / write / verify]
    FLASH --> BANK3[restore Bank 3]
    BANK3 --> STR8

    Q --> STR8
```

The worker does not call ROM, HIMON, or BIO while flash banks are being changed.
It restores Bank 3 and returns carry/status; the resident STR8 shell prints the
result.

## Future Advanced Sector Tool

A later advanced mode may expose sector-level flash maintenance, but it is not
part of V0's tiny recovery prompt. It belongs behind an explicit advanced entry
such as `A`, a confirmation, and possibly a larger STR8-N or HIMON maintenance
build.

Good fit:

```text
select source bank
select source sector
select destination bank
select destination sector
erase selected destination sector, confirmed
copy source bank/sector -> destination bank/sector, verify
compare/check selected source and destination sector
quit advanced mode
```

Bad fit:

```text
the normal ? B E M U 0 1 2 G R rescue/update path
automatic backup policy
casual bank 0 erase before enrollment
catalog garbage collection
rich monitor UI
```

Guard rails:

- Advanced copy must never silently change the Bank 0 enrollment flag. `E`
  remains the ordinary Bank 0 policy command.
- Writes to live bank 3, Bank 0 before enrollment, the selected STR8 protected
  window, or the hardware vector bytes need refusal or loud confirmation.
- The running STR8 code, RAM flash worker, and staged sector image must not be
  erased out from under the operation.
- Copy must verify immediately by read-back compare. A separate later verify is
  not enough for a destructive maintenance command.
- Sector copies can intentionally create mixed images. STR8 should report that
  risk instead of pretending a copied sector means the whole bank is bootable.
- Sector size comes from flash geometry. The current board uses 4K erase
  sectors, but the UI should not make the number part of the policy.

## STR8 Protected Address Map

```mermaid
flowchart LR
    GROWTH[$8000-$EFFF growth/body area]
    TOP[$F000-$FFFF physical 4K top sector]
    FREE[usable top-sector bytes below selected STR8 start]
    STR8CODE[$FC00/$FA00/...-$FFEF STR8 body]
    FLASH10[$FFF0-$FFF9 one-time board/version/config]
    VECTORS[$FFFA-$FFFF vector block]

    GROWTH -->|normal HIMON body, apps, packs, data| HIMONBODY[mutable by guarded update]
    TOP --> FREE
    TOP --> STR8CODE
    TOP --> FLASH10
    TOP --> VECTORS
    FREE -->|read/stage/erase/write full sector| HIMONBODY
    STR8CODE -->|selected STR8 protected window| ANCHOR[protected STR8]
    VECTORS -->|NMI RESET IRQ/BRK| ANCHOR
```

The whole `$F000-$FFFF` sector is the physical erase unit. Only the chosen
STR8 window is policy-protected. If code or data below the window changes, the
flash driver still has to read, stage, erase, rewrite, and verify the full 4K
sector.

## Flash Growth Workflow

Desired user flow:

```text
Himon boots.
User writes a program/routine/data definition.
User wants it in flash.
Himon scans writable flash sections.
Himon presents a list of candidate sections.
User picks a section.
User assembles/builds for that section.
User loads/writes with L F.
Himon verifies the written bytes.
Himon discovers the new record.
The routine/program/data is now self-referencing through the catalog.
Repeat until ROM space is intentionally filled.
```

The key idea is that `L F` should not merely program bytes. It should help turn
new flash content into catalog-visible content.

## Future Writable Section Scan

Future STR8 may provide routines to scan flash and classify regions:

```text
selected STR8 protected window
HIMON body
free/erased
catalog records
routine/program pack
data pack
unknown/non-HIMON bytes
bad/partial write
```

This is not V0. A future simple scan can look for erased `$FF` runs and known
record signatures. Later scans can understand module headers, checksums,
sequence numbers, and append-only catalog entries.

## Bank Use Intent

The first STR8 bank policy is image-oriented:

```text
bank 3 = live reset/boot image
bank 2 = most recent backup image
bank 1 = previous backup image
bank 0 = optional WDCMONv2/base hold, unless enrolled into rotation
```

On a backup request before bank 0 enrollment:

```text
copy bank 2 -> bank 1
copy bank 3 -> bank 2
```

On a backup request after `E` enrolls bank 0:

```text
copy bank 1 -> bank 0
copy bank 2 -> bank 1
copy bank 3 -> bank 2
```

The `E` enrollment flag is intentionally one-way under ordinary flash rules.
Once the flag is set, bank 0 stays in automatic rotation until erase/reflash or
a deliberate STR8 configuration rebuild.

On a recovery/restore request:

```text
restore ordinary bytes from selected 32K bank image 0, 1, or 2 -> bank 3
skip selected STR8 protected window unless explicit STR8 install/update is requested
```

Restoring bank 0 means restoring whatever bank 0 currently holds. Before
enrollment that may be a WDCMONv2/base image and may remove R-YORS from the live
boot image. After enrollment it is simply the oldest rotating backup image.

Saving the board's original WDCMONv2/base flash image remains a future bridge
TODO, not a requirement for today's STR8 RAM proof.

The generic primitive remains a bank copy:

```text
FLSH_COPY_BANK_AX   ; A = source bank, X = destination bank
```

A later installer/bridge wrapper for restoring a saved base image may be
deliberately descriptive:

```text
STR8_RESTORE_FACTORY
FLASH_S19_BOARD_RESET_TO_FACTORY
```

Full-bank copy in the current RAM-resident S19 proof stages one 4K erase sector
at a time through `$4000-$4FFF`:

```text
B command, B0 HOLD: copy bank 2 -> bank 1, then bank 3 -> bank 2
B command, B0 ROT:  copy bank 1 -> bank 0, bank 2 -> bank 1, bank 3 -> bank 2
0/1/2 commands:     copy selected bank -> bank 3 while preserving STR8 bytes
```

Each 4K window reads from the source bank, writes the destination bank, and
verifies by simple read-back compare. The `$F000` ROM build uses the same copy
policy by first copying its worker from bank 3 `$FC00-$FFFF` into RAM
`$0200-$05FF`. Ordinary restore into bank 3 preserves `$C000-$FFFF` unless the
operator explicitly confirms high flash, so HIMON, the ROM worker, and the
protected STR8/vector window remain usable after a normal restore. Catalog
lookup, hashed metadata, wear leveling, and cycle counts are later work.

Partitioned-bank layouts remain QCC thought experiments until promoted. They
are not part of the current `B`, `0`, `1`, and `2` recovery contract.

## STR8 Target Update Direction

The flash guard should stay in place. Updating HIMON or STR8 should not mean
"turn off the guard and let a ROM-resident command erase whatever it is running
from." The safer shape is a confirmed RAM-resident sector rebuild.

The V0 installer should be target/range-shaped internally, not HIMON-shaped.
HIMON is the default bundled target and the first useful proof, but the low
level operation should read as "install this target image/range" so another
monitor or app can use the same path later:

```text
target name:     HIMON, BETTERMON, app, or explicit range
target range:    bank plus CPU-visible address range
entry address:   where STR8 should hand off after validation
protected range: what must not be erased by this install
```

The operator-facing surface should stay simpler than the internal primitive.
First expose named profiles such as:

```text
UPDATE
UPDATE HIMON
UPDATE STR8
```

Do not ask the operator to choose a raw target/range until a later advanced
mode can print and guard that choice well enough to be mistake-proof.

The first S19 update gates are fixed and named:

```text
UPDATE HIMON
  accepts only $C000-$EFFF records
  refuses $F000-$FFFF records
  keeps STR8 alive if HIMON is bad

UPDATE STR8
  accepts only $F000-$FFFF records
  refuses $C000-$EFFF records
  requires literal STR8 confirmation
  verifies and resets instead of returning casually
```

If a future package contains both ranges, STR8 should split it into two visible
operations. The operator should never have to notice a raw address typo to keep
the board safe.

For V0, treat target replacement as a sector erase/rebuild operation, not as a
casual flash write or byte patch:

```text
select destination bank and 4K sector
read the live destination sector into the RAM staging buffer
receive S19 bytes as transport, if needed
merge incoming bytes into the staged 4K sector image
compare staged image with live flash
if staged image matches flash: report OK, no erase
if staged image differs: confirm sector erase
erase the destination sector
write the complete staged sector back
verify the complete sector by read-back compare
restore bank 3 before printing status
```

The 1->0 direct-program shortcut is later optimization, not the first
target-update contract. V0 may still clear tiny one-way config bits such as
`B0 HOLD -> B0 ROT`, but monitor replacement should be a whole-sector rebuild.

S19 is only the transport format. STR8 should collect or merge S19 data into a
complete 4K RAM sector image before flash is touched. This preserves bytes that
the S19 did not mention.

For now, creating that install transport is still an off-board packaging step.
The host build creates the vector-complete ROM `.bin`, then converts the needed
image/range back into S1/S9 text for the board to receive. The board consumes
the S19; it does not yet manufacture S19 from a binary image. That can change
after onboard ASM/export tooling or a STR8 image builder can hand STR8 complete
sector images or sealed candidate records directly.

Future STR8 may also accept bank-aware S2/S8 `.s28` transport. S2 records carry
24-bit addresses, so the extra byte can name the physical SST39SF010A flash
address instead of only repeating CPU-visible `$8000-$FFFF` addresses. A simple
four-bank physical flash-chip map would be:

```text
bank 0  physical flash $00000-$07FFF
bank 1  physical flash $08000-$0FFFF
bank 2  physical flash $10000-$17FFF
bank 3  physical flash $18000-$1FFFF  reset/default boot bank
```

STR8 would translate that address into `bank`, `bank_offset`, and
`$8000 + bank_offset`, then apply the same protected-window and sector-rebuild
rules before writing anything. That makes `.s28` a good later fast path for
bulk bank storage/retrieval/transport, while V0 can stay with S1/S9 packages.

Current helper target:

```text
make -C SRC himon-str8-rom-install-s19
```

It writes `BUILD/s19/himon-str8-rom-install.s19` from the vector-complete
`BUILD/bin/himon-str8-rom.bin`.

This is a good fit for ordinary HIMON body sectors. Updating `$C000-$EFFF`
should rebuild only the touched HIMON sectors and leave the `$F000-$FFFF`
recovery sector intact. If the new HIMON is bad, reset should still reach STR8.
The same rule applies to a non-HIMON target: rebuild only the target-owned
sectors, preserve STR8's recovery sector, and do not assume the payload is
called HIMON in the low-level installer.

The operator-manual version of that rule is the payload-stream section in
[OPERATORS_GUIDE.md](../OPERATORS_GUIDE.md#str8-payload-streams): build a
payload whose live entry is `$C000`, emit only S1 records in `$C000-$EFFF`,
feed that stream through `U`, and decide deliberately whether the old image or
the new payload belongs in the rotating backup chain. If the payload owns NMI,
BRK, or IRQ, it must patch the IVI RAM targets at `$7EFA-$7EFF` after handoff;
STR8 keeps the top-sector stubs alive but does not define the payload's
interrupt policy.

The top sector needs stricter policy. `$F000-$FFFF` contains STR8, the RAM
worker source copy, the config pocket, and vectors. Updating that sector must
preserve the non-target bytes unless the operator explicitly requested a STR8
update. A failed top-sector rebuild can remove the reset vector or recovery
code, so this path remains the dangerous one.

STR8 self-update is the special case:

```text
new STR8 image is staged in RAM
current top sector is staged in RAM
new STR8 bytes replace the protected-window bytes in the staged image
config bytes are preserved unless explicitly changed
vectors are rebuilt deliberately
operator confirms the protected-sector erase
RAM worker erases $F000-$FFFF, writes the staged sector, verifies, then resets
```

Do not add little fixed holes in `$FE03-$FFEF` for counters or future promises.
Pack STR8 code and data back-to-back, reserve only deliberate fixed pockets
such as `$FFF0-$FFF9`, and treat the remaining slack as growth space. Repeated
write counters belong in a separate metadata sector if they become important;
they should not force routine erases of STR8's protected sector.

Wear maps and scratch use should remain hash-shaped rather than file-shaped. A
future wear map can be an append-only `WMAP` record: write the newer map, verify
it, seal it, and let hash/kind/generation select the newest sealed map. A future
scratch sector can be a `TMP` or `STAGE` lease chosen from erased or
reclaimable low-wear sectors, but it must never contain the only valid copy of
anything required for boot or recovery.

Two 2K policy windows can share two 4K sectors, but erase remains 4K. If a 2K
`WMAP` or `STAGE` window in sector X ping-pongs with a matching window in
sector Y, the other half of each sector must be preserved through the sector
transaction or be explicitly disposable.

## Self-Referencing Flash Content

A flashed routine/program/data item becomes self-referencing when it carries or
is accompanied by catalog metadata:

```text
hash/name identity
kind
address/value
flags
optional compressed name text
optional module id
optional version/content checksum
```

The assembler project uses this directly:

```text
SYS_WRITE_CSTR is typed.
Himon hashes/canonicalizes it.
Catalog lookup returns the address.
The assembled code emits the call target.
```

The text name is not required for fast lookup, but it is important for onboard
catalog maintenance, collision proof, listings, and later self-hosted linking.

## L F Policy

First version of `L F` can be conservative:

- require user-selected destination or explicit flash mode
- refuse selected STR8 protected window and vector regions
- write only erased flash bytes unless an erase command has prepared the sector
- verify every written byte
- rescan and print discovered records after write
- report partial/unknown records instead of guessing

Later `L F` can become catalog-aware:

- detect provided routines already present
- detect unresolved imports
- use existing routine references instead of duplicating code
- reject or qualify duplicate exports
- write append-only catalog records
- commit with a final valid byte or sequence marker

## Duplication Problem

Right now, duplicated code is a real risk.

If every flash load brings its own copy of helper routines, ROM fills quickly and
the catalog becomes ambiguous. That is acceptable for early experiments, but it
is not the end state.

Later loading should distinguish:

```text
provided/exported routine:
  this module offers a routine

required/imported routine:
  this module needs a routine that may already exist

private routine:
  local to the module; not visible globally

replacement/update:
  newer provider for an existing routine
```

When `L F` sees a provided routine that already exists, it can choose among:

```text
reject duplicate
accept duplicate as module-local
alias to existing provider
replace by version policy
keep both with qualified module names
```

The simplest safe rule:

```text
If global hash/name already exists, reject duplicate global export unless the
user explicitly installs it as module-local or replacement.
```

## Catalog Without Host Tools

The catalog must be maintainable on board. There may be no modern build tools.

That means:

- collision checks happen by runtime catalog scan
- onboard-created exports should include name text, preferably compressed
- `#` is the master catalog view and may show collisions
- host-generated flags are optional conveniences, not required truth

Hash-only records can exist for tiny ROM built-ins, but self-hosted exported
symbols should carry enough name metadata to prove identity on board.

Name metadata may be compressed, but compression must be optional. If the
compressed form is not smaller than the raw form after headers/flags, store the
raw name instead. A small W65C02-friendly decoder is more important than an
aggressive compression ratio.

## Open Decisions

- What fixed image marker/check should STR8 V0 use for whole-image recovery
- Should whole-image recovery use the STR8 identity marker `#5F6A0F7A`, a
  separate per-image check, or both?
- Which catalog, compact-hash, scan, and vector-layer hooks should future
  STR8-N/STRAIGHTEN offer without requiring ownership of user memory or
  interrupt policy?
- What explicit import labels should HIMON use for resident STR8 routines once
  STR8 is no longer a simulation stub?
- Does `L F` assemble/write directly to flash, or assemble into RAM and then
  flash from a verified staging image?
- What is the first catalog record format that supports both compact built-ins
  and onboard-created named exports?
- What is the first compression format for routine names: HBSTR, PACK5, or a
  mixed encoding flag?
