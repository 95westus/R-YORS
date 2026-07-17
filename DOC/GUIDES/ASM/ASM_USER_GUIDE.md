# ASM User Guide

Status: current operator guide for ASM v1 as of 2026-07-06. ASM is a young
onboard W65C02 workbench, not yet a finished hosted toolchain. The hardware
proof source of truth remains [TEST_PLAN.md](TEST_PLAN.md).

## What ASM Is

ASM is the flash-resident onboard assembler entered from HIMON as `ASM`.
It reads ordinary source lines, emits native W65C02 bytes into RAM, resolves
forward references at `END`, and then opens a small `SEAL>` command window for
relocation/package work.

The current flash image is loaded at `$8000` and enters through the HIMON
FNV/RJOIN catalog. It starts new source sessions at `$2000` unless source uses
`ORG`.

For the short operator view of which address belongs to which command, see
[ADDRESS_PRACTICES.md](ADDRESS_PRACTICES.md).

## Current Operational Process

The movable-package lifecycle is named `SPILL`:

```text
SEAL     freeze/check facts
PACK     emit AP envelope; current command spelling is PACKAGE
INSTALL  store AP envelope
LOAD     read AP and relocate BODY into RAM
LINK     future import binding in the loaded overlay/temp-RAM image
```

Current flash ASM implements `SPIL`: `SEAL`, `PACKAGE`, `INSTALL`, and `LOAD`.
`LINK` is parked until imported packages can bind resident/package symbols
without growing the default flash image too much. Future `LINK` should patch
import relocation rows in the already loaded RAM image; it should make that
overlay/temp-RAM body runnable, but execution remains a separate HIMON `G` or
future run command.

Build the current board artifacts on the host:

```text
make -C SRC all
make -C SRC asm-session-report
```

`make -C SRC all` creates the current 32K onboard image with ASM-F2 already in
low flash. Bank 3 does not carry the ASM session reporter AP; build or install
that reporter separately and keep it as a Bank 0 AP. Run it with the explicit
banked AP form:

```text
AP B0 $hhhh $4800
```

Some current board-ingested files still live under
`DOC/GUIDES/ASM/SAMPLES/` because the present ASM-F2 workflow pastes or
packages them directly. Treat the paths named in this guide as current until a
replacement is documented; retired samples and proof-only sources move by the
plan in [../PLANNING/HISTORICAL_CODE_MIGRATION_PLAN.md](../PLANNING/HISTORICAL_CODE_MIGRATION_PLAN.md).
For the short Life bank-2 bench sequence, see
[LIFE16_QUICK_CARD.md](LIFE16_QUICK_CARD.md). For the complete method and the
reason behind each step, see [LIFE16_BANK2_EXAMPLE.md](LIFE16_BANK2_EXAMPLE.md).

On a board burned with the `make all` image, update/install the full image and
then return to HIMON with `G HIMON`; ASM-F2 is already present at `$8000`. If
you need the session report after an ASM session, exit ASM with `.` and run the
reporter AP from its Bank 0 store address:

```text
AP B0 $hhhh $4800
```

For an older board image or a narrow development pass, update HIMON through
STR8 when needed, then return with `G HIMON`. Load the optional external
reporter first if table detail will be needed later:

```text
L              send SRC/BUILD/s19/asm-session-report-7000.s19
```

Load flash-resident ASM into the visible low-flash window:

```text
L F            send SRC/BUILD/s19/asm-v1-flash-8000.s19
```

The current flash image should report `LF OK WR=3969 GO=800C`. A useful service
sanity check after updating HIMON is:

```text
D 7E25 2C      expect F1 D6 00 00 00 00 00 00 on current Overlay Integration Layer (OIL) image
```

The prompt text below shows where each line is typed; do not paste the prompt
characters. A normal assemble, package, install, load, and run session looks
like this:

```text
>ASM NEW
ASM>$2000: ORG $2000
ASM>$2000: LDA #$5A
ASM>$2002: RTS
ASM>$2003: END
SEAL> PACKAGE $3200
SEAL> INSTALL $3200
SEAL> INSTALL $3200 $hhhh
SEAL> LOAD $hhhh $3000
SEAL> .
>D 3000 3002
>G 3000
```

Use the address printed by `INSTALL $3200`; `$hhhh` is an example placeholder,
not a fixed address. `INSTALL pkg` is advisory and
does not write. `INSTALL pkg flash_addr` writes the unchanged AP envelope to an
erased visible low-flash hole. In a memory dump, the installed package begins
at the `AP` signature, not at an earlier row boundary such
as `$BD10`. If that hole is already occupied, `INSTALL pkg` suggests the next
erased hole, and an explicit install to the occupied address reports
`INST ERR=$06 BAD RANGE`.

## Return Status

Runnable ASM samples use one top-level return convention:

```text
C=1  success; A=$00 or the sample's documented success status
C=0  failure/abort; A=the documented nonzero status
```

HIMON captures flags immediately after a `G` or `AP` target returns, so the
`RET ... C`/`RET ... c` display is authoritative. Internal subroutines may use
carry for their own contracts; only the executable's final exit sets the
top-level result.

ASM-F2 keeps a nonzero result sticky for the active session. Typing `.` after
any assembly, seal, package, load, install, or input failure returns `C=0` and
that status in A. A clean session returns `C=1,A=$00`. Successful `ASM NEW` or
`NEW` starts a fresh result. Because `ASM` is an FNV command rather than a
direct `G`, HIMON renders its failed return as
`#56AD7400# EXEC ERR=$hh` instead of a `RET` line.

To load an already-installed package later, enter an empty source session just
to reach `SEAL>`:

```text
>ASM NEW
ASM>$2000: END
SEAL> LOAD $hhhh $3800
SEAL> .
>G 3800
```

Prompt ownership matters:

```text
ASM>$hhhh:   source lines only
SEAL>        SEAL, RELOCATE, PACKAGE, LOAD, INSTALL, NEW, .
>            HIMON commands such as D, G, L, #, STR8
```

For example, `D 3800 FF` at `SEAL>` reports `ERR=$03 BO`; exit with `.` and run
the dump at HIMON's `>` prompt.

## Starting And Leaving

From HIMON:

```text
ASM
```

Expected entry:

```text
ASM-F2
ASM>$2000:
```

The source prompt is:

```text
ASM>$hhhh:
```

`$hhhh` is the current assembler PC before the next accepted source line.
Accepted source lines are quiet. Rejected source lines print:

```text
ERR=$ee NAME PC=$hhhh
```

While still in source mode, `.P` prints the current PC without assembling:

```text
.P
```

Exit either source mode or `SEAL>` with:

```text
.
```

The flash wrapper prints `ASM BYE` and returns to HIMON.

## Quick Example

Paste or type the source lines after entering `ASM`; do not include the prompt
text:

```asm
ORG $2000
LDA #$5A
STA $7100
RTS
END
.
```

After returning to HIMON:

```text
G 2000
D 7100
```

The run should return with `A=5A`, and `$7100` should contain `$5A`.

## Source Lines

V1 source shape:

```text
[label[:]] operation [operand]
```

Rules:

- One physical line is one source line.
- The line limit is 63 visible characters.
- Spaces and tabs are whitespace; tabs have no column meaning.
- `;` starts a comment outside character quotes.
- Empty and comment-only lines are accepted.
- Tokens fold to uppercase outside quotes.
- Character quotes preserve exact byte value.
- A label colon is optional.

Good shapes:

```asm
MAIN LDA #$5A
MAIN: LDA #$5A
LOOP
LOOP:
COUNT EQU 10
BUF DS COUNT,$AA,$55
```

Rejected shapes:

```asm
LABEL ORG $2000
LABEL END
EQU $12
ORG
END X
LDA #1 EXTRA
```

## Labels

Global symbols may use:

```text
A-Z 0-9 _
```

Global symbols must not begin with a digit, and must not collide with
mnemonics, directives, or register names. `A`, `X`, and `Y` are reserved.
Current global symbol text is capped at 31 visible characters.

Labels bind the current PC before emitting the rest of the line:

```asm
MAIN JSR TARGET
TARGET RTS
```

## Local Labels

Local labels are scoped under the most recent nonlocal PC label.

Accepted local spellings:

```text
.NAME
.NAME:
?NAME
?NAME:
```

Local names are label-only helpers. They cannot be `EQU` symbols and cannot be
`EXPORT` or `IMPORT` names. Current limit is 16 local label rows per active
global scope, with 15 visible characters per local name including the prefix.

Example:

```asm
ORG $2000
MAIN LDX #$03
.LOOP DEX
BNE .LOOP
RTS
END
.
```

A local label before any nonlocal PC label is `BAD SYM`.

## Literals And Expressions

Literal forms:

```text
123          decimal
$FF          hexadecimal
$00F0        hexadecimal with absolute-width source intent
%10101010    binary
%XXXXXXX1    binary mask/pattern
'A'          character byte
'''          single quote character
*            current assembler PC
```

Expressions are simple left-to-right infix:

```text
term { op term }*
```

Operators:

```text
+ - | & ^
```

Selectors:

```text
<expr         low byte
>expr         high byte
```

V1 does not support grouping parentheses or forward `EQU` dependencies.

## Address Width

Source spelling controls address width. ASM does not silently choose zero page
because a value is small.

```asm
LDA $12       ; zero page
LDA $0012     ; absolute

ZPFOO EQU $12
ABSFOO EQU $0012
LDA ZPFOO     ; zero page
LDA ABSFOO    ; absolute
```

Decimal numbers are concrete values. They are valid for immediates, bit
numbers, counts, and data, but not as memory-address operands:

```asm
LDA #13       ; OK
LDA 13        ; BAD WIDTH
```

## Directives

Current v1 directives:

```text
EQU
DB
DW
DS
ORG
END
ENTRY
EXPORT
IMPORT
```

`EQU` defines a resolved value now:

```asm
COUNT EQU 10
ADDR  EQU $2000
LOW   EQU <ADDR
```

`DB` emits byte data. If an item is word-width, `DB` emits the word in little
endian order; use `<` and `>` when one byte is intended:

```asm
DB $12,$34,'A'
DB <ADDR,>ADDR
```

`DW` emits each resolved expression as a 16-bit little-endian word:

```asm
DW START,TARGET,$1234
```

`DS count` advances the PC without initializing bytes. `DS count, init-list`
emits exactly `count` bytes by repeating or truncating the initializer list:

```asm
DS 3
DS 5,$AA,$55
```

Important seal rule: ordinary ASM accepts forward `ORG` gaps and plain
`DS count`, but `SEAL` rejects bodies with holes or unowned bytes. Use a single
contiguous body and initialized `DS` when the result should be sealable.

`ORG expr` sets the assembler PC. It emits no bytes and cannot move backward:

```asm
ORG $2000
```

`END` closes the source session, resolves required fixups, prints the tables,
and enters `SEAL>` on success.

`ENTRY name` records a defined global PC label as the package entry name using
the same compact public export row as `EXPORT name` in this size-first slice.
Use `ENTRY name` instead of also exporting the same name.

`EXPORT name` records a defined global PC label as public package metadata.
`IMPORT name` declares an external symbol as intentional package metadata and
forces matching operands to become import relocation rows.

Plain English:

```text
ENTRY   this is the package front door
EXPORT  this package provides this global label for outside callers
IMPORT  this package needs this global label from outside providers
```

Export only the intended public contract. Do not export every helper routine.
For a normal AP program, `ENTRY MAIN` is usually the one public row needed.

`START` is not reserved; it is available as an ordinary label.

## Instructions

Use ordinary W65C02 mnemonics implemented by the current ASM opcode table.
Unsupported mnemonics report `BAD MNEM`; unsupported addressing combinations
report `BAD MODE` or `BAD WIDTH`.

Bit operations use the base mnemonic plus an explicit bit number:

```asm
RMB 3,$12
SMB 7,$12
BBR 3,$12,TARGET
BBS 7,$12,TARGET
```

Do not write `RMB3` or `BBS7`.

Direct `JSR name` and `JMP name` first check the current session. If the name
is not a session symbol and it is resident in the running HIMON/RJOIN catalog,
ASM can emit the resident address directly. Declaring `IMPORT name` first
forces deferred import metadata instead.

The difference is binding time:

```asm
JSR BIO_FTDI_PUT_CSTR
```

With no `IMPORT`, ASM asks the running HIMON/RJOIN catalog for the address now
and writes that concrete address into the emitted body. The package carries no
import row for that call. Use this for a proof or body that is intentionally
tied to the current resident image.

```asm
IMPORT BIO_FTDI_PUT_CSTR
JSR BIO_FTDI_PUT_CSTR
```

With `IMPORT`, ASM leaves placeholder bytes in the body, writes import metadata,
and records import relocation rows. HIMON/STR8/OIL resolves the name through the
resident RJOIN catalog when the AP package is loaded, then patches the loaded
RAM body. Use this when the package should stay movable and bind to whichever
resident image loads it later. This costs one import slot and one relocation row
for each patched address use.

## END Versus SEAL

`END` finalizes assembly. It resolves required fixups, freezes the body facts,
prints tables, and switches to:

```text
SEAL>
```

`SEAL>` is not source mode. It accepts only the wrapper commands below.
Before a clean `END`, those same words are ordinary source words and will not
run the post-session command.

## SEAL Commands

`SEAL` validates the frozen body facts and prints record summaries:

```text
SEAL
```

Success shape:

```text
SEAL OK FLAGS=$01 BASE=$hhhh END=$hhhh
SEAL REC @=$hhhh LEN=$hhhh FNV=$hhhhhhhh
SEAL REL @=$hhhh COUNT=$nn
```

If exports or imports exist, `SEAL` also prints `SEAL EXP` and/or `SEAL IMP`.

The default flash image omits the older interactive `RESOLVE` command. Import
metadata can still be packaged. In the combined HIMON/STR8 image, `LOAD` and
HIMON `AP` resolve declared imports that name resident RJOIN symbols through
the STR8 import-link service at `$F006`; missing or non-resident imports still
fail with `BAD FIX`.

`RELOCATE address` copies the frozen body to a RAM destination and applies
internal relocation rows there:

```text
RELOCATE $3000
```

Success shape:

```text
REL OK BASE=$3000 C=$nn
```

`RELOCATE` does not resolve import rows.

`PACKAGE address` writes an AP v1 package envelope to RAM:

```text
PACKAGE $3200
```

Success shape:

```text
PKG OK @=$3200 L=$hhhh
```

The envelope layout is:

```text
AP header
S tagged seal section
R tagged relocation section
E tagged export section
I tagged import section
B tagged body section
```

`PACKAGE` self-verifies the written BODY FNV before reporting success. It does
not install to flash, resolve imports, relocate the body, or run code. The AP
envelope can be copied as data; executing its BODY at a new address requires a
relocation/load step.

`LOAD pkg dest` reads an AP v1 envelope from RAM or currently visible flash,
copies the BODY to RAM, applies internal relocation rows, and resolves resident
RJOIN import rows when the `$F006` STR8 import-link service is present:

```text
LOAD $3200 $3000
```

`LOAD` is a post-`END` `SEAL>` command, not an ASM source line. To load an
already-installed flash package without assembling new code, open an empty
session and immediately end it:

```text
>ASM NEW
ASM>$2000: END
SEAL> LOAD $hhhh $3800
SEAL> .
>G 3800
```

Success shape:

```text
LOAD OK=$3000 L=$hhhh C=$nn
```

The destination BODY span must fit wholly in `$2000-$4FFF`. `LOAD` deliberately
does only a minimal package parse in this slice; full `CHECK`/FNV validation is
deferred. Resident imports are linked through RJOIN; missing imports,
non-resident dependencies, and unsupported relocation rows fail with
`LOAD ERR=$09 BAD FIX`. A RAM package may be above or below its destination,
but the complete envelope and destination BODY ranges must not overlap.

The one-argument `INSTALL pkg` form is read-only advisory:

```text
INSTALL $3200
```

Success shape:

```text
INST @=$hhhh L=$hhhh
```

It parses enough AP header/length information to find the first erased
contiguous visible flash hole in `$8000-$FEFF` large enough for the whole
envelope. `INSTALL pkg flash_addr` writes the unchanged AP envelope to an erased
visible low-flash hole through HIMON's install service. Both operands are ASM
expressions, so use `$` on literal hex addresses:

```text
INSTALL $3200 $hhhh
```

Banked install across banks 0-2 is intentionally a board source tool in this
slice, not a polished `INSTALL` command. Use
`DOC/GUIDES/ASM/SAMPLES/bankput-transient-3000.a`: it copies the selected bank sector
into the `$0A00-$19FF` sector staging buffer, overlays the AP envelope, then
programs/verifies that 4K sector through the `$F003` STR8 worker service.
`DOC/GUIDES/ASM/SAMPLES/bank2put-8000-transient-3000.a` is the fixed variant for an AP
envelope at bank 2 `$8000`. For bank 0 interactive install, use the one-run
`bank0ap-put-transient-2000.a` flow. That path uses `PACKAGE $3000`; the installer then
replaces the BODY source at `$2000` while preserving the envelope at `$3000`.
It stages and validates before accepting exact `YES` for the destructive
program/verify step. HIMON then runs a banked package with:

```text
AP B0 $8000 $3000
AP B1 $9000 $3000
AP B2 $9000 $3000
AP B0 $hhhh $4800
```

That path copies the banked AP envelope into the sector staging buffer, loads
and links BODY bytes into `$2000-$4FFF`, and runs from the requested load
address. It never executes directly from banked flash.

Flash ASM keeps symbol names at `$0200-$09FF` and fixup names at
`$0A00-$19FF`. `PACKAGE` serializes the required AP metadata before those
tables are released. Any STR8 flash worker or banked `AP` operation then
reuses that low RAM, so run `asm-session-report` before staging if symbol and
fixup names from the current session are required.

For STR8 top-sector update or recovery work, use
`DOC/GUIDES/ASM/SAMPLES/str8n-topwrite-transient-3000.a` only when the intended task is
to rewrite bank 3 `$F000-$FFFF`. `G 3000` stages the embedded STR8-N image into
`$0A00-$19FF` and should leave `$1A00-$1A03 = 00 AC 00 00`. After verifying
the staged bytes, `G 3003` erases/programs/verifies the active top sector and
should leave `$1A00-$1A03 = 01 AC 00 00`. The `$FACE` identity check should
read `STR8-N V0 #5F6A0F7A`.

`CHECK address` exists only in full-core or package-check diagnostic builds.
It is intentionally omitted from the default flash-resident ASM image to keep
space below `$C000`.

## External Session Report

Default flash ASM no longer prints `ASM TABLES` after `END`. Use the external
report proof when the live symbol/fixup/reloc tables are needed:

```text
make -C SRC all
make -C SRC asm-session-report
```

The current `make all` image does not store the fixed-address reporter after
ASM-F2. If it is stored in Bank 0, load it before the session to inspect, then
exit that session with `.` and run the resident copy:

```text
AP B0 $hhhh $4800
ASM NEW
...target source...
.
G 4800
```

`make -C SRC asm-session-report` also builds the explicit reporter artifacts.
The host-built RAM reporter is `SRC/BUILD/s19/asm-session-report-7000.s19`.
Load it before the ASM session to inspect, then after `END` and `.` run
`G 7000`.
For flash ASM itself, `DOC/GUIDES/ASM/SAMPLES/asm-session-report-4800.a` is a
compact ASM-F2 source program generated with literal message addresses and
single-character `DB` atoms. Assemble it before the session it will inspect,
then after that session exits run `G 4800`. `asm-session-report-transient-7000.a` is kept
for non-flash/runtime-paste ASM builds that still allow `$7000` output.

To manually store the reporter as an AP package in Bank 0, use the
`bank0ap-put-transient-2000.a` flow in
[SAMPLES/bank0ap-put-2000-test.md](SAMPLES/bank0ap-put-2000-test.md). This
reporter package is fixed-address: it has literal internal call targets and
must be loaded/run at the same `$4800` origin. It is also tied to the ASM-F2
code/map layout used to generate it: rebuild, repackage, and reinstall the
reporter after ASM-F2 code or map changes. A version-stamp-only rebuild with
the same addresses does not invalidate it. Loading an older reporter at
`$3000` traps when
its literal `$48xx` calls escape the relocated body; loading it at `$4800`
still fails if its hard-coded ASM helper/table addresses no longer match.
Load the matching reporter before the session to inspect, because the banked
load reuses low RAM:

```text
AP B0 $hhhh $4800
ASM NEW
...target source...
.
G 4800
```

If `PACKAGE $3000` reports `PKG ERR=$02`, regenerate the reporter source with
`make -C SRC asm-session-report`; older generated sources could assemble but
set bad seal flags by overflowing the AP relocation table.

`NEW` starts another source session at the frozen `END` PC:

```text
NEW
```

`NEW $addr` is rejected; use `ORG` in the new source session if a different
target is needed.

`.` exits to HIMON.

## Relocate And Package Example

Paste this at the ASM source prompt:

```asm
ORG $2000
MAIN JSR TARGET
LDA #<TARGET
LDX #>TARGET
TARGET RTS
END
```

Then at `SEAL>`:

```text
SEAL
RELOCATE $3000
PACKAGE $3200
LOAD $3200 $3000
INSTALL $3200
.
```

Expected behavior:

- `SEAL` reports `BASE=$2000 END=$2008` and three relocation rows.
- `RELOCATE $3000` writes a runnable copy at `$3000`.
- `PACKAGE $3200` writes an AP v1 envelope whose body still contains the
  original `$2000`-based bytes.
- `LOAD $3200 $3000` reloads the package BODY to `$3000` and applies the same
  internal relocation rows.
- `INSTALL $3200` suggests an erased visible flash hole but does not write it.

From HIMON:

```text
D 3000 3007
D 3200 3236
G 3000
```

For a fuller current-life-cycle proof with no imports, paste
`DOC/GUIDES/ASM/SAMPLES/spill-roundtrip-2000.a`. It exercises forward
references, a backward branch, export metadata, internal code relocation,
`PACKAGE`, `INSTALL`, `LOAD`, and `G`. Load it to non-page-aligned `$3123` so
both low and high relocation bytes have to move. After running `G 3123`,
`D 5848 50` should show `$5848=$AC`, `$5849=$00`, target pointers `$316E` at
`$584A-$584D`, loop pointer `$3144` at `$584E-$584F`, and `$5850=$5A`.

The relocated body should begin:

```text
20 07 30 A9 07 A2 30 60
```

## Import Metadata Example

Use `IMPORT` when the package should remember that an external name must be
resolved later:

```asm
ORG $2200
IMPORT EXT
MAIN JSR EXT
END
```

At `SEAL>`:

```text
SEAL
PACKAGE $3200
.
```

The body contains placeholder bytes for `EXT`, and the package contains an
import record. The current HIMON/STR8 AP loader can resolve imported names that
exist as resident RJOIN symbols, such as `BIO_FTDI_PUT_CSTR`. A made-up name
like `EXT` still fails at load/run time with `BAD FIX`.

## Memory Use

Current flash ASM default target:

```text
$2000        initial ASM source PC
```

Current practical map while ASM is running:

```text
$0200-$09FF  symbol-name pool; released when STR8 reloads its worker
$0A00-$19FF  fixup-name pool; released for flash sector staging
$2000-$2FFF  packageable ASM body/helper emission island
$3000-$3FFF  Bank 0 AP envelope, then AP load/run space
$4000-$4FFF  lower RAM output/load space
$5000-$61A9  protected flash ASM UDATA in the current map
$61AA-$7DFF  upper ASM output/scratch arena
$7E00-$7EFF  HIMON service and monitor workspace
$7F00-$7FFF  I/O, do not use
```

The flash wrapper rejects output into its protected UDATA span. `ORG $5000`
is `BAD RANGE`; the current map permits `ORG $61AA` through `$7DFF`.
Runtime code may still use ordinary RAM after leaving ASM if it does not depend
on returning to the same live ASM workspace. Future AP overlay work may use
the upper arena, but HIMON AP load destinations remain `$2000-$4FFF` in this
slice.

Current proof-sized table limits:

```text
global symbols       64
fixups               128
relocation rows      16
exports              8
imports              8
report references    192
locals per scope     16
line length          63 visible chars
global name length   31 visible chars
local name length    15 visible chars including . or ?
```

These are implementation limits, not permanent language promises.

The low-RAM split helped, but it did not automatically raise these row counts.
Flash ASM now keeps symbol names in `$0200-$09FF` and fixup names in
`$0A00-$19FF`, which frees the higher ASM workspace and gives STR8 a 4K sector
staging buffer after package metadata has been serialized. The current row
ceilings above are still deliberate constants. If they grow, grow
fixup/relocation capacity first, then symbol/local capacity, then
import/export slots.

## Error Codes

Common status codes:

```text
$00 OK
$01 BAD MNEM
$02 BAD DIR
$03 BAD OPER
$04 BAD MODE
$05 BAD WIDTH
$06 BAD RANGE
$07 BAD LINE
$08 BAD SYM
$09 BAD FIX
$0A LOCAL NYI
$0B RJOIN
```

How to read them:

```text
BAD MNEM    unknown mnemonic
BAD DIR     unknown/unsupported directive shape
BAD OPER    malformed operand or extra/missing operand text
BAD MODE    addressing mode not supported by that mnemonic
BAD WIDTH   source width does not match the instruction or context
BAD RANGE   value, branch, ORG, or target address is out of range
BAD LINE    malformed or too-long source line
BAD SYM     bad, duplicate, missing, reserved, or out-of-scope symbol
BAD FIX     unresolved or failed fixup, commonly at END
RJOIN       resident routine lookup/service setup failed
```

`BAD FIX` at `END` usually means one of:

- a label was misspelled or never defined
- a local label was referenced outside its scope
- an import was intended but not declared
- a resident call name was not available in the current HIMON/RJOIN catalog

## Current Gaps

Known limitations:

- No `ASM I` / `ASM B` split yet; typing and pasting use the same line path.
- Soon ASM-F2 update: make DB-heavy prompt/string sources less fragile than
  today's 63-visible-character physical line cap, either by a longer paste line
  path, explicit continuation, or first-class string data forms. Until then,
  split long `DB` rows manually; overlong rows correctly report `ERR=$07 BL`.
- No parentheses or precedence in expressions.
- No forward `EQU` dependency solver.
- No forward data fixups yet: `DW TARGET`, `DB <TARGET`, and `DB >TARGET`
  require `TARGET` to be known in current flash ASM. The next ASM incarnation
  should support those source forms and emit relocation rows for label data.
- No string data directives yet: `HBSTR`, `CSTR`, `PSTR`, `X'...'`, and
  `B'...'` are parked later forms.
- No default flash-image `CHECK` command.
- No default flash-image `RESOLVE` command; import resolution happens only
  during AP load/run through resident RJOIN.
- `INSTALL pkg flash_addr` writes only erased currently visible low flash.
  Banked install across banks 0-2 is currently `bankput-transient-3000.a`, not a polished
  command.
- `LOAD` does minimal AP parsing and resident RJOIN import linking; no full AP
  FNV validation or dependency manager yet.
- Local labels are not exported, imported, or reported as public symbols.

For design detail, see [HASHED_ASM.md](HASHED_ASM.md). For board evidence, see
[TEST_PLAN.md](TEST_PLAN.md).
