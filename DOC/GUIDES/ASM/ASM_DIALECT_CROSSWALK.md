# ASM-F2 Hosted-Assembler Crosswalk

Status: current for the repository ASM-F2 `00.0821(1039)` build on 2026-08-21.
The bounded-table observation below is also reproduced in the supplied board
transcript from ASM-F2 `00.0821(0132)`.

This is a semantic crosswalk, not a source-compatibility promise. ASM-F2 is a
one-pass onboard W65C02 workbench with bounded live RAM tables. WDC Tools,
ca65, and vasm are hosted assembler/linker systems with different expression,
section, object, and relocation models. `cc65` names the toolchain; `ca65` is
its assembler.

For syntax details, use the primary manuals for the
[WDC assembler/linker](https://wdc65xx.com/wdc/documentation/Assembler_Linker.pdf),
[ca65](https://cc65.github.io/doc/ca65.html), and
[vasm oldstyle syntax](https://sun.hasenbraten.de/vasm/release/vasm_6.html).
The vasm column below assumes the 6502 backend with the `oldstyle` syntax
module; other vasm syntax modules deliberately spell directives differently.

## Directive Crosswalk

| ASM-F2 | WDC assembler | ca65 | vasm oldstyle | Important difference |
|---|---|---|---|---|
| `NAME EQU expr` | `NAME EQU expr` | `NAME = expr` | `NAME EQU expr` | ASM-F2 requires the value now; it has no forward-`EQU` dependency solver. |
| `DB items` | `DB items` | `.byte items` | `db items` or `byte items` | An ASM-F2 word-width item emits two little-endian bytes; select `<` or `>` when exactly one byte is intended. |
| `DW exprs` | `DW exprs` | `.word exprs` | `dw exprs` or `word exprs` | ASM-F2 supports current and forward label fixups, within its live-table limits. |
| `DS count` | `DS count` | `.res count` | `ds count` or `blk count` | Plain ASM-F2 `DS` creates unowned output and prevents sealing. `DS count,init-list` owns and initializes the bytes. Hosted fill/output behavior depends on assembler, segment, and output format. |
| `ORG expr` | `ORG expr` | `.org expr` | `org expr` | ASM-F2 changes its direct output PC, cannot move backward, and records forward holes as seal-ineligible. Hosted relocatable projects normally place sections with a linker configuration instead. |
| `END` | `END` | `.end` | `end` | ASM-F2 also resolves fixups, prints the session report, and enters `SEAL>` after a clean end. |
| `ENTRY name` | no AP-equivalent | no AP-equivalent | no AP-equivalent | Records the AP v2 executable entry/public row. A hosted build expresses visibility and executable entry separately through its object format and linker. |
| `EXPORT name` | commonly `XDEF name` | `.export name` | `xdef name` or `global name` | ASM-F2 writes an AP v2 public metadata row, not a hosted object-file symbol. |
| `IMPORT name` | commonly `XREF name` | `.import name` | `xref name` or `global name` | ASM-F2 forces matching unresolved operands into AP v2 typed import relocation rows for resident RJOIN at load time. |
| `DC ...` | no portable one-line match | use `.byte`/`.asciiz` or explicit bytes | use `fcc`, `fcs`, `string`, or explicit bytes | ASM-F2's raw/C/H/P family is local syntax. Do not assume another assembler's `DC` has the same byte encoding. |

`START` is an ordinary ASM-F2 label, not a directive. Prefer `ENTRY MAIN` for
an AP program's package entry.

ASM-F2 string forms are:

```asm
DC 'text'         ; raw bytes
DC C'text'        ; text, then $00
DC H'text'        ; high bit on final character
DC P'text'        ; one-byte length, then text
```

When porting one of these forms, translate the intended bytes, not merely the
word `DC`. In particular, inspect a hosted listing or binary before relying on
a WDC/vasm compatibility spelling.

## Rules That Commonly Break Ports

### Source spelling controls address width

ASM-F2 preserves width intent from the source:

```asm
LDA $12       ; zero page
LDA $0012     ; absolute

ZP EQU $12
AB EQU $0012
LDA ZP        ; zero page
LDA AB        ; absolute
```

It does not silently promote or demote an address because the value happens
to fit. Hosted assemblers may infer an address size from symbol/segment facts,
choose a shorter encoding, or require an explicit force-size syntax. Preserve
the intended machine-code width explicitly when translating either direction.

### Expressions are strictly left to right

ASM-F2 supports `+ - | & ^ << >>`, has no grouping parentheses, and gives
shifts no precedence advantage. For example:

```text
1+2<<3     ASM-F2: (1+2)<<3 = 24
```

A hosted assembler with conventional precedence may produce a different
value. Use simple expressions or resolved intermediate `EQU` values in source
that humans will port between dialects.

### AP directives are not hosted object directives

`ENTRY`, `EXPORT`, and `IMPORT` build AP v2 metadata. `SEAL` validates the
contiguous body and relocation facts; `PACKAGE` serializes the `AP 02`
envelope; HIMON later loads it and resolves imports through resident RJOIN.

Hosted export/import directives instead describe symbols in that toolchain's
object format for its linker. They do not create AP rows, an AP envelope, an
ASM-F2 `SEAL` record, or HIMON load-time RJOIN metadata. There is therefore no
direct hosted spelling for `ENTRY`; reproduce its intent with the hosted
linker's entry configuration, then use a separate converter only if AP output
is actually required.

### Forward references and relocations consume different bounded tables

Current ASM-F2 limits are:

```text
global symbols       128
forward fixups       128
relocation rows       64
exports               64
imports               64
report references    192
locals per scope      16
source line            63 visible characters
```

One unresolved emitted use consumes one fixup row; rows are not deduplicated
by target name. Define a helper, table, or string before many references to it
when the program only needs a fixed load address. That removes forward-fixup
rows, but it does not remove relocation rows for internal absolute addresses.

These forms normally do not need relocation rows:

- relative branches;
- resolved `EQU` constants and fixed hardware addresses;
- resident routine calls resolved to their fixed current HIMON addresses.

An internal absolute `JSR`, `JMP`, address operand, or `DW LABEL` normally
needs one relocation row if the result must move. `#<LABEL` and `#>LABEL` are
two independently patched bytes and therefore cost two rows.

The failure modes are deliberately different:

- exhausting 128 forward-fixup rows is an assembly-time `ERR=$09 BAD FIX`;
- exceeding 64 relocation rows can leave ordinary fixed-address assembly
  valid, but marks the session seal-ineligible (`FLAGS=$09` for relocation
  overflow alone), so `SEAL` and `PACKAGE` must be rejected;
- a fixed-address program in that second state may be run only at its original
  `ORG`, after separately checking that assembly reached `ASM OK` and that the
  program itself has a proven return path.

Finishing AP work does not make either table unbounded. AP depends on the
relocation table and therefore makes the 64-row budget more important. For a
large fixed-load exerciser, table-driven byte streams and backward references
are appropriate. For a movable AP, budget relocation rows during design and
split the program or remove internal absolute address sites when necessary.

## Porting Checklist

1. Choose fixed-load or movable AP before restructuring references.
2. Preserve `$hh` versus `$hhhh` intent; compare emitted opcodes and lengths.
3. Rewrite compound expressions or verify their left-to-right value by hand.
4. Translate every `DC` form by byte contract.
5. Count unresolved uses against 128 fixups and movable address sites against
   64 relocations; do not count only distinct symbols.
6. Replace AP metadata with hosted linker configuration only when producing a
   hosted object/executable. It is not an AP package substitute.
7. For AP output require `SEAL OK FLAGS=$01`; for a fixed direct run require a
   clean `ASM OK`, the original `ORG`, and a separately verified exit path.
