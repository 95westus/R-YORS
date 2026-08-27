# R-YORS II Self-Building System Proposal

Status: formal architecture and shortest-path proposal recorded 2026-08-27.
It is not yet an accepted implementation plan, frozen ABI, language standard,
wire protocol, flash format, or release-name commitment. It gathers the
R-YORS, STR8-N, HIMON, ASM-F2, AP, FNV, `#ISH`, host-terminal, and later RPG II
directions into one system proposal for review.

For the compact board-facing form, see
[R-YORS II In 63'ese](R_YORS_II_63ESE_SUMMARY.md).

## Executive Call

Treat **R-YORS II** as the name of the next architecture, but do not begin with
a clean-sheet rewrite and do not fork the repository merely to acquire the
name.

R-YORS II should be an evolutionary system made from the hardware-proven
R-YORS parts:

```text
STR8-N             reset, recovery, bank, and flash authority
HIMON              operator monitor and callable resident service root
ASM-F2             onboard assembly engine and object producer
RJOIN/FNV32        named routine and object identity/resolution
AP v2              proven movable package, import, and relocation envelope
host terminal      console, source/file transport, transcript, and archive I/O
```

The architectural change is that the host ceases to be the compiler, linker,
image builder, or decision maker. The tested C terminal program becomes an
intelligent terminal and file-I/O device. It may scrape the screen, recognize
a board request, send a named file, receive a named file, and preserve a
transcript. Source may remain on host disk. Compilation and system construction
remain board operations.

This qualifies as the intended practical self-hosting boundary:

```text
host owns bytes at rest and moves bytes over USB
board understands, builds, tests, names, installs, and runs those bytes
```

The first useful proof is intentionally small:

```text
host supplies PIN source
        |
        v
board #ISH/ASM-F2 builds it into RAM
        |
        v
HIMON invokes PIN_PUT_CHAR / PIN_GET_CHAR / PIN_CHECK_CHAR
        |
        v
board reports A, X, Y, P, carry, result code, and selected memory evidence
```

Do this before building an onboard filesystem, elaborate WORK-sector manager,
fully relocatable ROM composer, SPI-RAM driver, general debugger framework, or
RPG compiler.

## The Product Boundary

R-YORS II is self-building even when its source library lives on the host.
Self-hosting here does not mean that the W65C02 must provide its own disk,
keyboard, editor, or permanent source filesystem. It means that no host-side
program is required to understand or transform the source into executable
W65C02 code.

The USB connection is the machine's console and removable file channel:

```text
HOST                                      BOARD
----                                      -----
terminal display     <-----------------   console output
keyboard/input       ----------------->   console input
source file bytes    ----------------->   #ISH / ASM-F2 input
binary/log bytes     <-----------------   save/export output
transcript/archive   <---------------->   operator and build records

no required parse                         parse source
no required assemble                      assemble
no required link                          resolve/link
no required image layout                  choose/layout image
no required flash policy                  validate/install/verify flash
```

The host may automate terminal work without becoming the authority. Screen
scraping, waiting for prompts, supplying requested files, retaining output,
and checking transport CRCs are legitimate terminal-device functions. A host
program that assigns target addresses, resolves imports, emits machine code,
or composes the boot bank has crossed back into the target toolchain.

Host build tools should remain as bootstrap, comparison, test-oracle, and
disaster-recovery tools. Operational independence does not require deleting a
known-good independent way to reproduce or inspect the system.

## Why R-YORS II, But Not A Rewrite

There are three possible development shapes:

| Shape | Benefit | Cost and risk | Call |
| --- | --- | --- | --- |
| Keep adding unrelated features to current R-YORS | No naming or transition work | Boundaries blur; every experiment becomes resident debt | Reject |
| Rewrite a new R-YORS II from zero | Clean paper architecture | Longest path; discards hardware proof; creates a new bootstrap problem | Reject |
| Declare the II contracts and grow vertical slices on the proven base | Preserves proof while preventing new accidental coupling | Requires discipline about what is I and what is II | Recommend |

R-YORS II should initially be a release architecture, not a second code tree.
The current board image remains the recovery and development base. New work is
admitted when it satisfies an II boundary. When the first complete source-to-
RAM-to-call proof is accepted, the II name can become an active development
line or release profile without pretending that every inherited byte was
rewritten.

The rule is:

> Reuse proven mechanism. Replace accidental policy. Add no framework before
> one vertical slice needs it.

## System Shape

The proposed machine grows in layers:

```text
                         HOST TERMINAL / FILE DEVICE
                    terminal scrape, GET, PUT, transcripts
                                      |
                                      v
+--------------------------------------------------------------------------+
| HIMON operator plane                                                     |
| prompt, memory, go/call, return-state display, named routine discovery   |
+--------------------------------------------------------------------------+
| #ISH source/control plane                                                |
| visible registers, calls, conditions, memory inspection, build commands  |
+--------------------------------------------------------------------------+
| ASM-F2 build plane                                                       |
| parse, emit, symbols, fixups, seal, package, load, install                |
+--------------------------------------------------------------------------+
| routine/object plane                                                     |
| #MAKE-selected PIN/BIO/COR/SYS/APP families, FNV32 and AP v2 objects     |
+--------------------------------------------------------------------------+
| STR8-N machine plane                                                     |
| reset, bank choice, guarded flash mutation, recovery, handoff             |
+--------------------------------------------------------------------------+
| W65C02SXB / W65C02EDU hardware                                           |
| RAM, banked flash, VIA/PIA, FTDI, optional SPI devices                   |
+--------------------------------------------------------------------------+
```

Later W65C816SXB/EDU work should preserve the conceptual planes while gaining
larger addresses, banks, and memory. Do not spread 24-bit assumptions through
the W65C02 contracts in anticipation of that port.

## The First Vertical Slice

The fastest route to the desired machine is not a boot-image builder. It is a
small routine-development loop that proves the whole ownership boundary.

### Operator experience

An illustrative session is:

```text
#
#ISH GET PIN1.ISH
HOST> GET PIN1.ISH
RX 0317 CRC 6A29

BUILD RAM $3000
OK CODE=0098 EXPORTS=03 FIX=02

TEST PIN_CHECK_CHAR
RC C=1 A=41 X=00 Y=00 P=31

TEST PIN_GET_CHAR
RC C=0 A=00 X=00 Y=00 P=32

M $3000 $3097
...
```

The exact spelling is not frozen. The significant ownership is:

1. The board requests `PIN1.ISH`.
2. The host sends its bytes and a transport check.
3. The board parses and assembles the source.
4. The board places the result in an explicitly owned RAM range.
5. The board resolves and invokes named exports.
6. HIMON reports machine state and memory evidence.

### First routine family

Use one small, real PIN family rather than a synthetic LED-only program:

```text
PIN_PUT_CHAR
PIN_GET_CHAR
PIN_CHECK_CHAR
```

The final names and exact device suffix may follow existing project naming,
for example `PIN_FTDI_*`. What matters is a family with distinct contracts:

```text
PUT    input byte, ready/busy or success result
GET    consume a byte when one is available
CHECK  report availability without pretending to consume a byte
```

If hardware makes `CHECK` consuming, the contract must say so. `#ISH` must not
hide the distinction between a hardware readiness check, a BIO-cached peek,
and a consuming FIFO read.

### Proof record

Each exported routine needs a compact human and machine contract:

```text
name/FNV32
kind and ABI version
entry
inputs in A/X/Y/C or memory
outputs in A/X/Y/C
P flags whose result is meaningful
register and memory clobbers
blocking, bounded, or nonblocking behavior
RAM/ZP/I/O ownership
test case and accepted result
```

The HIMON-style return-context display is the observation surface. It does not
make every displayed register part of the ABI. The contract decides which
values are meaningful; the monitor shows enough state to prove the contract.

## `#ISH` In R-YORS II

The existing `#ISH` idea remains the right language level: above raw assembly,
below a virtual machine or general high-level runtime. R-YORS II changes its
first implementation direction. The host-translator-first experiment is no
longer the preferred system path. The host supplies text; the board owns the
translation.

`#ISH` should be a thin, inspectable frontend to ASM-F2, not an unrelated
compiler stack. Prefer direct calls into shared expression, symbol, fixup, and
emission routines over this expensive path:

```text
#ISH text -> generated ASM text -> reparse ASM text
```

The better onboard path is:

```text
#ISH statement
      |
      +-- expression service
      +-- symbol/fixup service
      +-- opcode/emission service
      v
ASM-F2 session state and output
```

### Initial language character

The initial language should make the W65C02 visible:

```text
A = $41
X = 0
Y = >BUFFER
CALL PIN_PUT_CHAR
IF NC BUSY
RETURN
```

Useful first forms are:

```text
LABEL:
A = expression
X = expression
Y = expression
CALL routine
IF C label
IF NC label
IF Z label
IF NZ label
GOTO label
RETURN
BYTE[address] = expression
INSPECT start [end]
```

Memory writes and inspection must remain explicit. A friendly assignment must
not silently choose zero page, allocate storage, or change an address width.

### Compiled and immediate forms

`#ISH` may provide both without becoming an interpreter VM:

```text
immediate control   INSPECT, GET, BUILD, TEST, SHOW, DROP
compiled source     register loads, calls, branches, stores, returns
```

The immediate words call HIMON/ASM services. The compiled words emit normal
W65C02 instructions and ordinary fixups. This makes the monitor feel like a
language environment without adding bytecode, a hidden data stack, garbage
collection, exceptions, or a second calling convention.

### One pass or two

Do not make classic one-pass versus two-pass assembly a product identity.
The required behavior is correct forward reference resolution and bounded,
diagnosable resource use.

The shortest first route is the current assembler model:

```text
one source ingestion
immediate emission where known
symbol and fixup records for forward values
END resolves or rejects the session atomically
```

A later large build may use two logical passes. Because the host is a file
device, the board can request the same source again for pass 2. The source does
not have to be cached onboard merely to satisfy a textbook definition of
self-hosting.

## `#MAKE` / SYSGEN Chooses The System

`PIN -> BIO -> COR -> SYS -> APP` is a vocabulary and maximum layering model,
not a mandatory five-call path. A `#MAKE` recipe, acting as the small-system
equivalent of SYSGEN, should select the shortest family closure that satisfies
the requested machine.

Examples are:

```text
hardware diagnostic       PIN -> APP
buffered terminal tool     PIN -> BIO -> APP
stable console system      PIN -> BIO -> SYS -> APP
shared runtime system      PIN -> BIO -> COR -> SYS -> APP
STR8-only boot supervisor  STR8-N, with no HIMON service ladder
```

`COR` is present only when selected code needs shared runtime mechanism. `SYS`
is present only when the generated system promises a stable application-facing
service. An application or proof is allowed to call PIN directly when that
hardware coupling is its stated purpose. Namespace names describe ownership
and contract level; they must not force unused wrapper layers into every image.

An eventual recipe might read conceptually:

```text
#MAKE SYSTEM TINYTERM
  ROOT STR8-N
  CONSOLE FTDI
  INCLUDE PIN_CHAR BIO_CHAR
  INCLUDE HIMON_MIN
  OMIT COR DEBUG ASM AP
ENDMAKE
```

or:

```text
#MAKE SYSTEM DEV65
  ROOT STR8-N
  CONSOLE FTDI
  INCLUDE HIMON ASM-F2 #ISH FSEDIT AP DEBUG
ENDMAKE
```

The spelling is not frozen. The required behavior is dependency closure:
`#MAKE` includes what selected routines require, rejects unsatisfied or
incompatible requirements, and leaves unrelated layers absent. It should
produce a readable composition report before any image is written.

The first RAM PIN proof does not need the complete `#MAKE` implementation. Its
explicit list of source, exports, RAM range, and tests is the first hand-written
recipe. `#MAKE` becomes code when repeating those choices manually becomes the
next obstacle.

## Routine Families Before A Large Language

The growing system should offer callable routine families from which `#MAKE`
selects a system:

```text
PIN_*    physical register, pin, FIFO, SPI, and device primitives
BIO_*    buffered/logical device behavior
COR_*    common runtime mechanism
SYS_*    stable application-facing services
APP_*    programs and operator applications
```

The first #ISH programs should compose and test useful portions of these
families. A configured system need not contain the whole ladder. For example:

```text
PIN_CHECK_CHAR
PIN_GET_CHAR
PIN_PUT_CHAR
        |
        v
BIO_PEEK_CHAR
BIO_GET_CHAR
BIO_PUT_CHAR
        |
        v
SYS_GET_CSTRING
SYS_PUT_CSTRING
SYS_READ_LINE
```

`SYS_GET_CSTRING` is a good early higher-level proof only after its bounds are
real. Its contract must state:

```text
destination address
capacity, including or excluding NUL
termination guarantee
blank-input result
overflow result
Ctrl-C result
timeout/blocking behavior
A/X/Y/C/P outputs and clobbers
```

The language should learn routine signatures, not accumulate ad hoc special
cases for each friendly service name.

## FSEDIT: The Onboard Source Editor

FSEDIT is an intended simple full-screen editor in the operator style of the
System/34 POP utility. It closes an important loop:

```text
GET source -> edit on board -> BUILD -> TEST -> edit -> BUILD -> PUT source
```

The host may remain the durable file cabinet. FSEDIT makes the board the place
where source is inspected and changed; it does not require an onboard
filesystem before it is useful.

FSEDIT should itself be an AP-capable program. Depending on the configured
system, its package or selected overlays may be obtained from:

```text
ordinary RAM
visible or banked flash/AP Store
the host terminal/file responder
SPI SD storage
SPI SRAM
another future block or file provider
```

Storage location and execution location are distinct. A FSEDIT AP in banked
flash, SPI SD, SPI SRAM, or the host file store is data until the loader copies
and relocates the required body into executable RAM. A fixed/PIC component in
currently visible flash may execute in place only under an explicit contract.

### Two independent windows

Do not conflate the screen with the file cache:

```text
display window   terminal columns x rows visible to the operator
file window      source bytes/lines currently held in W65C02 RAM
```

A large terminal may show more rows while the editor retains a small file
window. SPI SRAM may allow a much larger file window without changing an
80x24 display. `#MAKE`, terminal negotiation, and available-memory acquisition
should select both sizes.

FSEDIT should have a conservative minimum profile and then grow buffers from
reported capability rather than compile one permanent maximum:

```text
terminal rows/columns
free ordinary RAM span
SPI SRAM present/size
backend block and transfer size
Debug/ASM overlays currently resident
requested undo and line-index depth
```

### Nucleus and overlays

Keep a small editor nucleus resident while optional functions page through an
overlay area:

```text
resident nucleus
  terminal draw and cursor state
  key/command dispatch
  file-window descriptor
  dirty-state and save/abandon gate
  backend read/write calls
  overlay loader and return point

optional overlays
  search/replace
  larger line index
  help
  block copy/move
  syntax/display assistance
  backend-specific utilities
```

The loader must never evict the instructions that are performing the load.
Every overlay returns to the nucleus before another overlay is selected.
Optional overlays may be AP bodies or sections selected by a small overlay
manifest; this does not require all FSEDIT code to become independently named
applications.

### File-window records

The initial paging contract can stay small and explicit:

```text
file/backend identity
file offset of the first resident byte
resident valid length
allocated window length
cursor and top-line offsets
dirty low/high extent or dirty-page bits
preceding/following text availability
line-start index for the resident window
```

Within the active window, a gap buffer is a reasonable first editing
mechanism: insertion and deletion near the cursor are cheap, while moving far
enough to require another file window causes a controlled flush/load. This is
an implementation candidate, not yet a frozen file representation.

No operation may silently discard a dirty window. Moving outside it must do
one of:

```text
write the changed range successfully, then load the next range
retain the dirty window while another buffer is available
ask the operator to save/abandon
fail and leave the current window intact
```

### Backend contract

FSEDIT should edit through one bounded byte/range or record-stream interface:

```text
OPEN name/mode       -> handle, length, capabilities
READ handle,off,len  -> returned length and status
WRITE handle,off,len -> accepted length and status
SIZE/TRUNCATE
COMMIT
CLOSE/ABANDON
```

The names are illustrative. A host adapter turns these into terminal file
requests. SPI SRAM provides direct range behavior. An SPI SD adapter maps them
onto its block/filesystem policy. Flash/AP Store should normally use
copy-on-write object replacement rather than pretend that text is cheaply
mutable in place.

Backends may have different atomic guarantees. FSEDIT must report them. A safe
host save can write a temporary file and publish/rename it after a complete
length and CRC check. A flash save writes a new committed generation before
invalidating the old one.

### Shortest FSEDIT path

Do not begin with paging and every backend. Build it vertically:

```text
FSEDIT-0
  host GET of one file that fits in ordinary RAM
  variable terminal rows/columns
  cursor, insert, delete, split/join line, save, abandon
  host PUT with length/CRC and explicit commit

FSEDIT-1
  one bounded file window
  range GET/PUT through the same host terminal responder
  dirty-window gate and forward/backward window motion

FSEDIT-2
  package FSEDIT as AP
  optional code overlays
  variable file-window sizing from available RAM

FSEDIT-3
  SPI SRAM and SPI SD backends
  larger indexes, multiple buffers, and optional undo
```

FSEDIT-0 is useful even if every later step is deferred. It should follow the
first source-to-RAM build proof rather than block it.

## Debug Is An Optional Capability

The first vertical slice should use existing HIMON memory, call, and
return-context facilities. It should not wait for a plug-in debugger.

The later optional Debug module may add:

```text
breakpoint and single-step commands
symbol-aware state display
watch memory
trace recent routine joins/fixups
source/build identity display
conditional stop
```

It should be an AP/RAM overlay or selectable image component. A machine built
without Debug must omit its commands, hooks, RAM claims, and help text. The
core monitor retains enough call-state and memory inspection to recover from a
bad trial module.

## FNV32, RAM Trials, AP, And Images

Do not choose one universal artifact.

```text
raw RAM trial       fastest write/test/edit loop; session-owned
FNV32 export        stable routine identity and named call
AP v2 package       movable family, imports, relocation, storage, reload
boot image          selected fixed system composition
```

### Shortest-path rule

For the first PIN proof, assemble directly into bounded RAM and publish the
session's validated exports. Do not design a new flash-module format first.

When a useful routine family must survive reset, move, import other routines,
or live in AP Store, package it using the already-proven AP v2 path. A smaller
execute-in-place FNV module remains a valid later optimization only after a
real family demonstrates that AP overhead or copy/relocation is the obstacle.

### Hash width

Keep full FNV32 for public routine identity, imports, exports, and cross-bank
resolution. A folded 16-bit value may index a bucket, but the full FNV32 and
record contract must decide execution. Automatic execution must reject zero or
multiple validated full matches.

## B1:E WORK Is Not On The Critical Path

B1:E remains the designated application WORK sector. It can later provide an
append-only build journal, fixup/symbol spill, source cursor, layout plan, and
sector receipts.

It is not needed for the first source-to-RAM-to-call proof. The host can resend
source, the current RAM assembly arenas can hold the first programs, and a
failed session can be discarded. Delaying WORK-format design shortens the
route and prevents a transient flash format from becoming a premature system
dependency.

Introduce WORK when one measured requirement appears:

```text
symbol/fixup capacity blocks a useful routine family
an interrupted image build needs resumable sector receipts
a multi-pass source stream needs board-owned intermediate records
```

When introduced, WORK remains discardable and rebuildable. Persistent source
continues to belong to the host file device unless a later board store has an
actual use case.

### Migration roles belong to Bank Maintenance

The canonical STR8-N development release may continue to publish B1:E WORK and
B1:F protected top backup. The stock-board migration candidate is a different
profile: it begins with `$FFF0=$FF` and `$FFF1=$FF` because promising not to
touch B1/B2 and simultaneously claiming sectors there would be contradictory.

Bank Maintenance is the right first owner of those two configuration bytes.
It can show the complete inventory and make assignment a deliberate, guarded
post-migration operation:

```text
SHOW ROLES     FFF0=FF WORK NONE; FFF1=FF TOP-BACKUP NONE
CHOOSE BACKUP  operator names one qualified sector outside retained B0
COPY/VERIFY    complete live B3:F is written there before B3:F changes
CHOOSE WORK    distinct erased/discardable sector, or leave NONE
PATCH          stage full B3:F; change only selected configuration bytes
COMMIT         RAM worker rewrites and verifies B3:F
RETAIN         preserve the verified backup under the selected policy
```

SYSgen may request roles later, but it should call the same Bank Maintenance
service and display the same plan. It must not hide a raw `$FFF0/$FFF1` patch
inside image composition.

Role assignment and media initialization are separate. A sector locator does
not create a directory row, initialize a VTOC, convert an opaque bank to AP
Store, or enroll a bank in catalog search or backup rotation. After the role
transaction completes, Bank Maintenance may offer those actions separately;
the user may leave the directory/VTOC entirely unpopulated.

This also resolves the bootstrap edge: the first top-backup assignment cannot
depend on an already configured top-backup. It must name an explicit qualified
destination, write and verify the old B3:F there, and only then rewrite B3:F.
B1/B2 remain untouched until that command and destination are confirmed.

## Logical Flash Pages And The `F` Service

Larger transients and variable-size objects should use `$100`-byte logical
pages for allocation, transfer, dirty tracking, display, and placement. This
does not change the SST39SF010A erase geometry:

```text
BYTE PROGRAM UNIT       1 byte
LOGICAL R-YORS PAGE     $0100 bytes
PHYSICAL ERASE SECTOR   $1000 bytes
BANK                    $8000 bytes = 128 logical pages = 8 erase sectors
```

Reserve `F` as the Flash inspection/planning service and `FL#` as the proposed
logical-page selector, where `#` identifies a bank-relative page `$00-$7F`.
The exact final command grammar is deliberately not frozen here. The first
behavior should be read-only plan/display; mutation requires a second explicit
verb and confirmation.

For every proposed byte, compute:

```text
DROP  = OLD AND (NOT NEW), bits changing 1 -> 0
RAISE = NEW AND (NOT OLD), bits that would have to change 0 -> 1

OLD=FF for changed byte    simple byte-program candidate
OLD!=FF and NEW!=OLD       containing 4K sector uses erase/copy/rewrite
any RAISE bit              containing 4K sector uses erase/copy/rewrite
```

The display should show bank, logical page, containing 4K sector, address,
OLD, NEW, `1>0` mask, `0>1` mask, and `SAME`/`PROGRAM`/`ERASE-CYCLE`, followed
by summary byte/bit counts. A target byte that is still `$FF` can receive any
byte value in the sector's post-erase programming episode. For the initial
SST39 service, a changed target byte that is already non-`$FF` is not directly
reprogrammed, even when its requested set bits are a subset of the old value;
it takes the guarded erase/copy/rewrite path. The bit test explains why a
request is impossible without erase, but it does not by itself authorize a
second program pulse on an already-programmed cell.

If any changed byte is non-`$FF`, including any request that needs `0 -> 1`,
`$100` granularity cannot make the erase smaller. The service must stage the
complete containing 4K sector, apply the page patch in RAM, obtain a qualified
recovery copy, erase the physical sector, rewrite all 4K bytes, and compare
them. A `$100` page never straddles a 4K sector when page aligned.

`F` is not a raw bypass around STR8-N policy. It must refuse protected B3:F,
the configured WORK/top-backup sectors, retained WDCMONv2, directory/VTOC
media, or a live AP Store transaction unless the corresponding higher-level
service explicitly authorizes the operation. Erase/program code, data, stack,
LED warning, timeout state, and return path remain in RAM until B3 is restored.

## SPI RAM And Additional Devices

The unpopulated SPI RAM position is an expansion profile, not a prerequisite.
R-YORS II must reach the first self-building proof on the existing board RAM.

When fitted, SPI RAM may provide:

```text
large source or token cache
symbol/fixup spill
overlay backing store
link/image tables
RPG compiler tables and work records
transcript/spool buffers
```

It is slower external memory, not transparent W65C02 main RAM unless hardware
provides such mapping. Access belongs through explicit `PIN_SPI_*`, device,
and later `MEM_*` services. The assembler and compiler should acquire a
capability and use it; they should not assume it exists.

The same rule applies to VIA/PIA-attached SPI and other devices:

```text
PIN    exact register and transfer mechanism
BIO    buffering, framing, retry, and logical stream/block behavior
SYS    stable file, record, console, or memory service
```

A larger memory device should enlarge builds, not change the meaning of a
small #ISH program.

## Onboard Boot-Image Construction

Boot-image construction follows routine development; it is not the first
self-hosting gate.

The eventual board builder should:

1. Select fixed and AP-derived components.
2. Compute dependency closure and final addresses.
3. Resolve every import and relocation before flash mutation.
4. Reject overlap, RAM/vector conflicts, missing symbols, and duplicate
   identities.
5. Synthesize one 4K sector at a time in RAM.
6. Program sectors `$8-$E` into an inactive bank.
7. Verify every sector by read-back.
8. Program top sector `$F`, including reset vectors and identity, last.
9. Verify the complete bank.
10. Qualify it through explicit `Jn` boot before any promotion to Bank 3.

The system's fixed spine should stay small:

```text
STR8-N reset/recovery/flash root
minimal HIMON/service loader root
vectors and image identity
```

Selectable HIMON shell, ASM, Debug, service families, and applications may be
composed around it. Do not require every byte in a boot image to be an AP, and
do not make the recovery root dynamically dependent on the loader it must
recover.

### SYSGEN metadata reduction

AP v2 remains the canonical movable artifact. When SYSGEN binds an AP into a
fixed image, it may offer measured metadata reduction:

```text
KEEP AP       retain relocation/import/export and normal load lifecycle
STRIP TEXT    remove optional debug/text names, retain required AP facts
BAKE          resolve imports/relocations now and emit fixed body plus only
              the HREC/entry/ABI/runtime records selected code still needs
```

A baked component is no longer an AP-v2 object available for arbitrary later
movement. Call it an image component derived from AP. Do not leave the AP
signature while silently removing fields required by its validator.

The full AP should remain in host/AP source storage for rebuild. The image
manifest must retain its FNV32 name/version, body integrity, selected source
generation, assigned range, build ID, stripped-metadata report, and final image
checks. Metadata reduction saves nucleus/image bytes; it must not destroy
runtime resolution, crash diagnosis required by the selected profile, or the
ability to reproduce the build.

### Bank worker and EDU warning LEDs

Any operation that selects a bank which unmaps its caller must use a complete
RAM worker:

```text
visible B3 caller
  -> RAM worker
  -> select target bank
  -> copy/erase/program/readback
  -> restore B3
  -> return to visible caller
```

The worker code, tables, flash state, LED routine, stack use, and return state
must remain accessible throughout the selection. It must not call a PIN/BIO/SYS
routine residing in the bank it just unmapped.

Where the EDU/SXB configuration provides an operator-visible LED without
unsafe interference, the RAM worker may flash a configured pattern from the
moment destructive erase begins until programming, verification, and safe-bank
restore finish:

```text
FLASHING       destructive transaction active; do not power off
OFF/NORMAL     safe transaction end, accompanied by text result
FAIL PATTERN   attention required, accompanied by exact text/status
```

The pattern is an advisory power warning. It is not flash-bus activity proof,
completion proof, or verification. A board profile must declare LED register,
polarity, preserved bits, and ownership; do not commandeer a PIA/VIA port that
the active fixture or guest uses. Correctness still comes from timeout,
read-back, sector compare, CRC, vector, and final bank checks.

## WDCMONv2 Entry Ramp And Standalone STR8-N

A fresh WDC board may still enter through WDCMONv2. A publishable RAM-only
conversion program, provisionally `wdcmonv2ryors.asm`, can run as an ordinary
WDCMONv2-loaded application and perform this guarded sequence:

```text
identify the supported SXB/EDU board and flash geometry
copy and verify original WDCMONv2/SPI Bank 3 into Bank 0
prove Bank 0 vectors and image integrity
install and verify standalone STR8-N into Bank 3
program the Bank-3 top sector last
reset into the STR8-N boot selector/recovery supervisor
```

The artifact name can become `wdcmonv2str8n.asm` if the release installs no
R-YORS payload; that name more accurately describes the first product. The
important point is that the converter does not require HIMON, ASM-F2, AP,
`#ISH`, or the R-YORS routine catalog.

Because current STR8-N source and releases are owned by the adjacent standalone
STR8-N repository, the authoritative converter source, release S19/BIN, and
board card should live there if this direction is accepted. R-YORS should keep
the integration contract, optional later development payload, and cross-project
proof references rather than acquiring a second live STR8-N implementation.

In this profile STR8-N is a standalone board BIOS in the narrow, traditional
boot sense:

```text
reset and physical recovery root
bank selector and no-return guest handoff
guarded flash copy/install/update authority
bank/image inspection and qualification support
```

It is not yet a universal console, character, block-device, or file-service
BIOS. Those services belong to the selected guest or to later published STR8-N
entry contracts if STR8-N deliberately acquires them.

The resulting machine can be useful before R-YORS II exists:

```text
Bank 0   preserved stock WDCMONv2/SPI guest
Bank 1   independent guest, such as an Apple-II-derived/adapted system
Bank 2   another independent guest, test image, or retained recovery image
Bank 3   STR8-N reset/boot/recovery root, optionally with a selected payload
```

An Apple II or other guest still has to be adapted to the SXB/EDU RAM and I/O
hardware; an opaque flash bank does not emulate missing Apple hardware. Once
adapted, however, it owns its selected `$8000-$FFFF` bank and does not depend
on HIMON, ASM-F2, AP, `#ISH`, or R-YORS naming services after `Jn` handoff.

This intermediate release would broaden STR8-N's use. It gives a stock board
owner an immediate result—preserved factory firmware plus guarded multiboot and
recovery—without requiring adoption of the larger R-YORS environment. It also
creates a stable substrate on which different communities can install their
own guest systems.

A publishable conversion kit should include:

```text
assembly source
WDCMONv2-loadable S19
optional programmer BIN and checksums
supported-board and flash identity table
dry-run inventory/report mode
copy, whole-bank compare, CRC, and vector checks
power-loss and failed-verify recovery instructions
exact terminal card and accepted hardware transcript
explicit statement of which banks/sectors will be erased
```

The converter should first offer a non-destructive inventory/dry run. Its
destructive commit must refuse unknown hardware, overlapping RAM, an
unverified Bank-0 copy, or an image whose vectors and expected identity fail.
The copy of WDCMONv2 is established before the source Bank-3 top sector is
changed.

The migration candidate leaves `$FFF2=$FF`, so automatic external FNV/AP
discovery initially remains disabled. A later guarded policy transaction may
set `$FFF2=$A6`; only then are B1/B2 eligible while Bank 0 remains excluded.
`J0`, BANKDUMP, CRC, copy, and recovery remain explicit operations. The search
mask does not govern provisioning or recovery copies.

### Releasing Bank 0 Later

Retaining WDCMONv2 is a configured bank role, not a permanent prohibition. A
future utility may archive and release Bank 0 for another use, but archive,
erase, backup rotation, and catalog enrollment are separate commits.

Recommended flow:

```text
1. Read the exact 32K Bank-0 image.
2. Emit canonical BIN plus CRC/hash and vector/image facts.
3. Optionally emit S19 or carry the checked image through a GibberLink-style
   terminal transport.
4. Read or receive the archive back and compare all 32K where practical.
5. Record the archive name, length, checks, board identity, and source bank.
6. Ask the operator to RELEASE the retained-WDCMONv2 role.
7. Erase Bank 0 and verify erased bytes.
8. Assign the new bank role explicitly.
9. Enroll it in backup rotation only if requested.
10. Set `$FFF2=$A7` only after replacement contents form a validated FNV/AP
    provider and the operator separately enrolls catalog search.
```

BIN is the safest canonical archive because it preserves every byte and exact
bank length. S19 is a useful transport/record view. A GibberLink-style channel
is also a transport; it should carry the same length/check facts and should not
be the only copy. No successful export silently authorizes erase.

The seed is bootstrap material. It may be host-built because there must be a
first path onto a stock board. Installing standalone STR8-N is a complete and
publishable stopping point. If the operator later selects the development
profile, R-YORS II, HIMON, ASM-F2, AP, and `#ISH` can be installed as guests or
as the Bank-3 payload, after which normal system construction follows the
onboard path.

## No Guest Image Required

The onboarding path should not end with "now supply your own 32K ROM." If an
operator has no Bank-0/1/2 image, the system and project should help create one.

The shortest useful service is a guided `#MAKE GUEST`/SYSGEN recipe that starts
from the board profile and a purpose, then selects proven components:

```text
#MAKE GUEST LAB1 BANK 1
  CPU W65C02
  CONSOLE FTDI
  IRQ SAFE
  NMI SAFE
  PIA ENABLE
  VIA ENABLE
  SPI VIA
  MONITOR MIN
ENDMAKE
```

The spelling is illustrative. The result should be a complete candidate guest,
not just generated source fragments:

```text
reset/startup and stack initialization
declared RAM and zero-page ownership
valid NMI, RESET, and IRQ vectors
safe default IRQ/NMI handlers with visible counters/status
selected PIN/BIO device families
minimal console or application entry
image identity, build recipe, range map, and checks
32K candidate image with sector checks and final vector validation
guest qualification card
```

### Hardware-assisted configuration

SYSGEN may ask what is fitted, but configuration claims are not proof. Provide
small, separately runnable diagnostic routines where the hardware permits:

```text
CPU/clock       bounded timing and instruction assumptions
IRQ/NMI         install test handler, provoke/observe safely, count return
PIA             register and selected pin-direction/readback tests
VIA             timer, IFR/IER, port, and handshake tests
FTDI            enumeration, RX-ready, receive, and transmit behavior
VIA/PIA SPI     transfer framing plus known-device/status/readback tests
SPI SRAM        address/data pattern test over a declared disposable range
SPI SD          initialization and read-only identification before writes
```

Every test must state what it may alter. PIA/VIA pin tests cannot assume that
external circuitry tolerates arbitrary output values. Begin with register,
direction, input, timer, and read-only device tests; require an explicit fixture
profile before driving pins or writing storage.

An `OK` row means observed behavior satisfied a named test:

```text
IRQ   OK COUNT=0004 RETURN=YES
PIA   OK DDR=READBACK PORTA=INPUT
VIA   OK T1=PASS IFR=PASS
SPI   OK DEV=SRAM SIZE=128K PATTERN=PASS
```

It must not mean merely that the operator selected `IRQ YES` or `SPI VIA`.

### Starter profiles, not disciplinary silos

The goal is low time-to-use across different work, not one enormous image that
contains every possible service. Maintain small recipe families such as:

```text
MINCON    reset, vectors, FTDI console, memory/go
LABIO     console, timers, PIA/VIA inspection, sampled input
CONTROL   bounded loop, timers, explicit output-safe state, watchdog hooks
STORAGE   SPI transport, SRAM/SD discovery, block test/read tools
DEV65     HIMON, ASM-F2, #ISH, FSEDIT, AP, optional Debug
RETRO     minimal handoff/support substrate for an adapted guest system
```

These names are candidates, not products yet. Each profile should be a short
dependency recipe whose components can be removed. A biologist logging sensors,
an artist driving an installation, a controls experiment, a hardware class,
and a retrocomputing port may share the same interrupt, console, timer, SPI,
and record-I/O routines without sharing one application.

The design measure is elapsed time:

```text
stock board
  -> preserved WDCMONv2 and standalone STR8-N
  -> hardware inventory and bounded checks
  -> selected starter recipe
  -> RAM trial where possible
  -> inactive-bank candidate
  -> verify and Jn qualification
  -> useful application work
```

Do not require the operator to understand AP, FNV, relocation, sector layout,
or vector bytes before reaching the first working image. Those facts remain
visible in the generated report and available for inspection; the recipes make
the safe common choices.

FSEDIT then supplies the customization loop. The operator can open the selected
profile or application source through the host file backend, change routines or
configuration onboard, rebuild in RAM, test, and later generate a new candidate
bank.

## Path Toward A Small IBM-Like System

R-YORS II is not proposed as a System/34 or System/360 emulator. The useful
lineage is architectural behavior:

```text
operator console
named libraries and routines
load modules
control statements/jobs
record-oriented files and data
spooled or requested host-device I/O
return/status conventions
recoverable system generations
language processors built on system services
```

The host terminal/file responder naturally resembles a console plus a simple
external device. Later #ISH control statements can grow into job/control-deck
behavior without forcing the first language to be an operating system.

An RPG II compiler then becomes a later language processor running on services
already useful to the rest of the machine:

```text
file and record descriptions
source input from the host device
symbol and field tables
work storage
code generation through ASM-F2 emission services
AP/load-module output
catalog and image installation
operator diagnostics and listings
```

That is the important direction: RPG is not grafted onto a monitor. The
monitor, catalogs, routine ABI, record I/O, build services, and load-module
lifecycle mature until an RPG compiler has a native machine to inhabit.

## A Living, Growing, And Aging Machine

"Living" should have concrete system meaning rather than implying an unsafe
self-modifying firmware image.

R-YORS II can accumulate:

```text
routine families and versions
AP generations
build and image identities
accepted test records
install/rollback history
bank and sector roles
device capabilities
flash erase/use observations
optional language processors and applications
```

It can rebuild indexes from authoritative records, keep an older accepted
generation while testing a new one, qualify an inactive bank, and report what
it is made from. Aging is visible history and media state, not uncontrolled
mutation. Growth occurs through validated objects, image builds, and explicit
promotion.

## Shortest Credible Delivery Plan

Each phase must leave a useful board capability. Do not start the next phase
merely because its design is interesting.

### Phase 0: declare the boundary

- Record this proposal and choose whether R-YORS II is the active architecture.
- Define the host as terminal/file transport.
- Keep the existing paste path working.
- Do not freeze a richer wire protocol yet.

Exit: everyone can say which side parses, assembles, links, installs, and
executes.

### Phase 0A: optional stock-board STR8-N ramp

- Publish `wdcmonv2ryors.asm`, or the more precise `wdcmonv2str8n.asm`, as a
  WDCMONv2-loadable RAM application.
- Inventory first, then copy and verify the stock Bank-3 WDCMONv2/SPI image in
  Bank 0.
- Install standalone STR8-N as the Bank-3 reset/recovery supervisor.
- Prove `J0` returns to the preserved stock system.
- Prove one independent Bank-1 guest handoff without HIMON or AP involvement.
  If no external guest is available, ship a reference `MINCON`-class image with
  valid vectors, console, and visible interrupt status; its recipe can become
  the later onboard `#MAKE GUEST` proof.

Exit: a stock SXB/EDU board has preserved factory firmware and payload-agnostic
STR8-N multiboot/recovery without adopting R-YORS II.

### Phase 1: PIN in RAM

- Add the smallest onboard `#ISH` surface that reuses ASM-F2 emission.
- Request or paste one PIN-family source file through the C terminal.
- Build it in a bounded RAM region.
- Resolve three named exports.
- Call each from HIMON and display return context.
- Inspect code and work bytes.

Exit: source retained by the host becomes tested executable code without a
host compiler or linker.

### Phase 2: routine family and ABI

- Freeze the first PIN contracts.
- Compose BIO wrappers.
- Add a correctly bounded `SYS_GET_CSTRING`-class service.
- Record tests and clobber/resource contracts.
- Reject duplicate identities and incompatible ABI versions.

Exit: #ISH composes routines made from routines across at least two layers.

### Phase 2A: host-backed FSEDIT

- Load one source file that fits in ordinary RAM through the terminal
  responder.
- Edit it with the minimum full-screen operations.
- Save through length/CRC/commit and build the saved result onboard.
- Keep display size independent from the source-buffer size.
- Preserve the original file when save or transport fails.

Exit: the board can modify, save, rebuild, and retest source while the host
remains only the terminal and durable file device.

### Phase 3: durable movable program

- Package one accepted family with existing AP v2.
- Store, cold-load, relocate, and run it.
- Add optional Debug as a RAM/AP capability only if the existing monitor proof
  surface is no longer adequate.

Exit: a board-built family survives reset and can be loaded without host-side
reassembly.

### Phase 4: onboard image candidate

- Add the smallest useful `#MAKE`/SYSGEN recipe and dependency-closure report.
- Add a two-pass layout and sector composer.
- Build an inactive 32K candidate bank from accepted components.
- Program `$8-$E`, verify, then program `$F` last.
- Boot with `Jn`, qualify, and preserve rollback.
- Use B1:E WORK only if measured build state requires it.

Exit: the board constructs a bootable system image using the host only for
terminal/file bytes.

### Phase 5: system services

- Add record/file-device services over the terminal responder.
- Add job/control statements only where they reduce operator effort.
- Add SPI RAM, VIA/PIA SPI, or other devices through capability-based PIN/BIO/
  SYS layers.
- Add the first guided guest recipe and bounded hardware qualification cards;
  prefer reusable interrupt, PIA, VIA, console, and SPI components over a
  discipline-specific monolith.
- Grow #ISH conditionals, data descriptions, and diagnostics from real users.

Exit: the system can support a nontrivial onboard language processor.

### Phase 6: RPG II

- Implement RPG II from original lineage and behavior.
- Use the established record, routine, build, object, and file-device services.
- Emit normal board-owned modules or image components.

Exit: an RPG program is compiled, installed, and run by the board, with the
host serving only source/data files and terminal I/O.

## Explicit Deferrals

The following do not block Phases 0-2:

```text
FSEDIT paging, overlays, and SPI backends beyond the host-backed first slice
onboard persistent source filesystem
SPI RAM population
new compact FNV module format
folded-16 identity as authority
general heap
multitasking or scheduler
general debugger framework
automatic flash garbage collection
fully packed relocatable boot ROM
RPG syntax or compiler implementation
W65C816 port
```

If one of these is proposed before the PIN-to-BIO vertical slice works, it must
show that it shortens that slice rather than merely belonging to the eventual
machine.

## Acceptance Questions

Before promoting this proposal to a settled direction, decide:

1. Is **R-YORS II** the desired architecture/release name, with the current
   system retained as its bootstrap and proof base?
2. Is the practical self-hosting boundary accepted as "host stores/transports;
   board transforms/builds/installs/runs"?
3. Should the first #ISH implementation be onboard and share ASM-F2 internals,
   superseding the earlier host-translator-first recommendation?
4. Is the first vertical slice the three-routine PIN family built and tested in
   RAM?
5. May B1:E WORK, SPI RAM, a new module format, and the image compositor remain
   off the critical path until the RAM routine loop is proven?
6. Is the long system direction an IBM midrange/mainframe-like operator,
   library, load-module, job, record, and RPG environment rather than literal
   hardware emulation?
7. Should `#MAKE`/SYSGEN select a minimal dependency closure rather than make
   `PIN -> BIO -> COR -> SYS -> APP` mandatory?
8. Should the WDCMONv2-to-standalone-STR8-N converter be treated as its own
   publishable product and stopping point before R-YORS II installation?
9. Is FSEDIT accepted as the intended onboard editor, beginning with one
   host-backed RAM-resident file and growing into explicit data windows,
   AP overlays, SPI SRAM, and SPI SD backends?
10. Should onboarding promise a guided path to create a minimal qualified guest
    when the operator has no Bank-0/1/2 image, with time-to-use and reusable
    hardware profiles as explicit design measures?

If accepted, the next planning artifact should be one short Phase-1 test card,
not another broad subsystem design.
