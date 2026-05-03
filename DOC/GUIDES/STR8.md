# STR8 Recovery Monitor

`STR8` means `Subroutine To Return`. It is pronounced `S-T-R-8`, can also be
read as `Straight 8`, and deliberately echoes `RTS` / Return from Subroutine.

Future naming may let STR8 grow into `STR8-N`, read as `STRAIGHTEN`: a richer
repair/normalization path once the small recovery anchor has proved itself.
That name is a direction, not a promise that the first STR8 must own every
system policy.

STR8 is the protected recovery/update monitor for Himonia-F/Himon. It is not
just a crash handler and not just a flash writer. It keeps the machine on a
known-good path while code, routines, data, and banks are being changed.

V0 STR8 is image-oriented recovery: banks 0-2 hold whole 32K ROM images for
backup and restore, while the selected STR8 protected window is flashed through
its own guarded path. HIMON owns hashed catalog lookup, rich command behavior,
and IRQ/vector control in the first version. Future STR8-N/STRAIGHTEN may offer
catalog, FNV, scan, repair, and vector-layer services after the image-recovery
path is stable, but it should remain useful to systems that keep their own
memory map, interrupt policy, or runtime supervisor.

Working definition:

```text
STR8 = the top-sector recovery anchor and flash mutation guard.
```

System relationship:

```text
R-YORS boots through STR8.
STR8 keeps recovery/update safe.
STR8 hands normal operation to HIMON.
HIMON provides the monitor, command dispatch, assembler, catalog lookup,
and debug tools.
```

## Core Questions

V0's recovery target is settled:

```text
restore from a whole 32K ROM image in bank 0, 1, or 2
logical image range: $8000-$FFFF
bank 3 restore: write ordinary image bytes by guarded flash flow
protected STR8 window: skip unless explicit STR8 install/update is requested
```

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

The settled V0 split is small, W65C02-specific, and aligned to the actual STR8
size rather than wasting the whole top flash sector.

The physical top erase sector is still `$F000-$FFFF`, because flash erase
granularity is 4K and the hardware vectors live at the top of ROM. The STR8
protected byte window is selected after the true code size is known. Use the
highest start address that fits:

```text
$FC00-$FFFF  1K protected STR8 window
$FA00-$FFFF  1.5K protected STR8 window
$F800-$FFFF  2K protected STR8 window
$F600-$FFFF  2.5K protected STR8 window
$F400-$FFFF  3K protected STR8 window
$F200-$FFFF  3.5K protected STR8 window
$F000-$FFFF  4K protected STR8 window, only if STR8 needs the whole sector

$FFF0-$FFF8  one-time flash board/version/config bytes, inside the window
$FFF9-$FFFF  vector tail; W65C02 hardware vectors are $FFFA-$FFFF
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
operator explicitly requests a STR8 install/update. The `$FFF0-$FFF8` bytes are
reserved for one-time flash data such as board id, version, and config
information. The final hardware vector bytes are the W65C02 vector table:

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

Reference integration rule:

```text
hardware vector -> STR8 entry/trampoline/router -> active handler
```

Reference normal operation:

```text
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

So yes: Himonia-F/HIMON controls practical trap handling in V0. Later
STR8-N/STRAIGHTEN can offer a recovery-safe vector path for systems that choose
it. Systems that already own interrupts can still use STR8 routines directly and
keep their own policy.

The code may use W65C02 instructions when they keep the anchor smaller or
clearer. NMOS 6502 portability is not a STR8 V0 goal.

## Recovery I/O Layering

STR8 should talk to the smallest useful layer that still preserves a reusable
contract.

Working rule:

```text
prefer BIO_* for STR8 recovery I/O
use PIN_* only when no BIO_* helper exists yet
promote repeated PIN_* use into BIO_*
avoid COR_*/SYS_* in the STR8 hot path unless explicitly recovery-safe
```

That gives STR8 a direct, small path for bytes, hex, CRLF, and future flash
status output without dragging in the normal monitor personality. `PIN_*`
remains the hardware/register edge. `BIO_*` is the first reusable board I/O
contract. `COR_*` and `SYS_*` sit above that for richer monitor/application
behavior.

Possible layouts:

```text
Protected top-sector model:
  $8000-$EFFF          HIMON body, apps, routine packs, data
  $F000-(start-1)      usable top-sector bytes below STR8, if any
  start-$FFFF          selected STR8 protected window

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
physical top erase sector is bank 3 $F000-$FFFF
protected STR8 window starts at $FC00, $FA00, $F800, $F600, $F400, $F200, or $F000
protected bytes are flashed through a separate STR8 install/update path
non-STR8 top-sector updates use read/stage/erase/full-sector-write/verify
STR8 code/data/recovery lives from selected start through $FFEF
one-time board/version/config window is $FFF0-$FFF8
vector tail starts at $FFF9; hardware vectors live at $FFFA-$FFFF
V0 uses whole 32K ROM bank images as recovery and backup sources
V0 HIMON controls IRQ/vector behavior
V0 has no FNV/catalog lookup
no flash garbage collection
no relocation replay
no command-text compression in STR8 itself
no rich user interface
```

V0 should do only enough to keep boot and flash mutation recoverable:

```text
reset entry
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
STR8 may use FNV once that direction becomes real.

## Boot Relationship

Current prototypes may boot directly into Himonia-F. The proposed R-YORS/STR8
path boots through STR8 first, then hands normal operation to HIMON/Himonia-F
after a small validity check.

At boot, STR8 should be able to:

- verify the HIMON body enough to decide whether normal boot is safe
- enter recovery mode if the body is missing, partial, or corrupt
- preserve a small failure reason for the user
- provide a minimal serial/FTDI path if the normal monitor body cannot run
- expose flash repair/install commands

In the first implementation, this can be mostly policy and a few guard bytes.
The full recovery monitor can grow later.

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

This is not the normal path for a board that already has Himonia-F/R-YORS
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
minimal FTDI/serial byte API
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
? / ID     print STR8, board, version, and boot failure reason
B          rotate backup images: 1->0, 2->1, 3->2
0          restore bank 0 to bank 3
1          restore bank 1 to bank 3
2          restore bank 2 to bank 3
V          verify selected/copy target bank image
G          go HIMON / timeout default
R          reset/retry normal boot
```

`L S`, `L F`, `GO addr`, catalog repair, and richer loading are later features.
The recovery loader should avoid the full assembler, full catalog UI,
compression tools, and rich command parser. Those belong in HIMON once normal
operation is safe.

## STR8 Protected Address Map

```mermaid
flowchart LR
    GROWTH[$8000-$EFFF growth/body area]
    TOP[$F000-$FFFF physical 4K top sector]
    FREE[usable top-sector bytes below selected STR8 start]
    STR8CODE[$FC00/$FA00/...-$FFEF STR8 body]
    FLASH9[$FFF0-$FFF8 one-time board/version/config]
    VECTORS[$FFF9-$FFFF vector tail]

    GROWTH -->|normal HIMON body, apps, packs, data| HIMONBODY[mutable by guarded update]
    TOP --> FREE
    TOP --> STR8CODE
    TOP --> FLASH9
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
bank 0 = platinum R-YORS/HIMON/STR8 image and oldest backup slot for now
```

On a backup request:

```text
copy bank 1 -> bank 0
copy bank 2 -> bank 1
copy bank 3 -> bank 2
```

On a recovery/restore request:

```text
restore ordinary bytes from selected 32K bank image 0, 1, or 2 -> bank 3
skip selected STR8 protected window unless explicit STR8 install/update is requested
```

Bank 0 starts as a platinum R-YORS/HIMON/STR8 image. Under the current backup
rotation it is also the oldest backup slot. If bank 0 must remain permanently
platinum, that needs a later protect/confirm policy.

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

- What is the first concrete STR8 V0 protected-window start: `$FC00`, `$FA00`,
  `$F800`, `$F600`, `$F400`, `$F200`, or `$F000`?
- What fixed image marker/check should STR8 V0 use for whole-image recovery
  images?
- Which catalog, FNV, scan, and vector-layer hooks should future
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
