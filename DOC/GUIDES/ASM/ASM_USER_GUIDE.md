# ASM User Guide

Status: current operator guide for ASM v1 as of 2026-07-05. ASM is a young
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

## Starting And Leaving

From HIMON:

```text
ASM
```

Expected entry:

```text
ASM FLASH
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

The flash wrapper prints `ASM FLASH BYE` and returns to HIMON.

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

`EXPORT name` records a defined global PC label as public package metadata.
`IMPORT name` declares an external symbol as intentional package metadata and
forces matching operands to become import relocation rows.

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

`RESOLVE` resolves import rows through the current resident RJOIN catalog and
patches the RAM body in place:

```text
RESOLVE
```

Success shape:

```text
RESOLVE OK COUNT=$nn
```

`RELOCATE address` copies the frozen body to a RAM destination and applies
internal relocation rows there:

```text
RELOCATE $3000
```

Success shape:

```text
RELOCATE OK BASE=$3000 COUNT=$nn
```

`RELOCATE` does not resolve import rows.

`PACKAGE address` writes an AP v1 package envelope to RAM:

```text
PACKAGE $3200
```

Success shape:

```text
PACKAGE OK @=$3200 LEN=$hhhh
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

`CHECK address` exists only in full-core or package-check diagnostic builds.
It is intentionally omitted from the default flash-resident ASM image to keep
space below `$C000`.

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
.
```

Expected behavior:

- `SEAL` reports `BASE=$2000 END=$2008` and three relocation rows.
- `RELOCATE $3000` writes a runnable copy at `$3000`.
- `PACKAGE $3200` writes an AP v1 envelope whose body still contains the
  original `$2000`-based bytes.

From HIMON:

```text
D 3000 3007
D 3200 3236
G 3000
```

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
import record. A future loader/installer is responsible for resolving that
import before execution. `RESOLVE` can patch imports now only when the imported
name is present in the current resident RJOIN catalog.

## Memory Use

Current flash ASM default target:

```text
$2000        initial ASM source PC
```

Current practical map while ASM is running:

```text
$2000-$5FFF  user code/data/package workspace, choose non-overlapping areas
$6000-$7EFF  protected ASM/HIMON workspace while ASM is active
$7F00-$7FFF  I/O, do not use
```

The flash wrapper deliberately rejects direct assembly output into the protected
high-RAM region. For example, `ORG $7000` is currently `BAD RANGE` in flash ASM.
Runtime code may still use ordinary RAM after leaving ASM if it does not depend
on returning to the same live ASM workspace. Future AP overlay work may use
`$3000-$6FFF` after ASM has produced a package and returned to HIMON, but that
is a loader contract, not source-mode permission to assemble over ASM.

Current proof-sized table limits:

```text
global symbols       40
fixups               96
report references    160
locals per scope     16
line length          63 visible chars
global name length   31 visible chars
local name length    15 visible chars including . or ?
```

These are implementation limits, not permanent language promises.

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
- No parentheses or precedence in expressions.
- No forward `EQU` dependency solver.
- No string data directives yet: `HBSTR`, `CSTR`, `PSTR`, `X'...'`, and
  `B'...'` are parked later forms.
- No default flash-image `CHECK` command.
- `PACKAGE` writes an AP envelope but does not install or load it.
- Local labels are not exported, imported, or reported as public symbols.

For design detail, see [HASHED_ASM.md](HASHED_ASM.md). For board evidence, see
[TEST_PLAN.md](TEST_PLAN.md).
