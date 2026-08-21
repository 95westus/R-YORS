# `#ISH` Proposal

Status: informal planning proposal recorded 2026-08-21. The canonical name is
`#ISH`, with `#ish` accepted as its lowercase form. The name is not yet an
acronym, committed language, command, ABI, or resident feature.

## The Idea

`#ISH` could be a small, readable source layer for composing existing R-YORS
routines. It would keep machine state visible, but remove repetitive load,
call, and branch spelling from simple programs:

```text
ADDR = $0200
A = 64
SYS_CONSOLE_GET_CSTRING
IF NC HANDLE_IO_ERROR
```

The useful middle ground is above raw W65C02 source and below a general
high-level language. A `#ISH` statement should lower to a short, inspectable ASM
sequence. It should not introduce a virtual machine, hidden heap, scheduler,
exception system, or second runtime ABI.

The first implementation, if the idea survives paper review, should be a host
translator that emits ordinary ASM source. Onboard parsing can remain a later
possibility. The emitted source would continue through the existing ASM/AP
seal, relocation, import, and load paths.

## Proposed Reading Of The Example

The sample appears to ask for this flow:

1. Read at most 64 characters into a C string at `$0200`.
2. On I/O failure or timeout, report `$E1` and stop.
3. Validate the completed buffer as ASCII.
4. On invalid input, report `$E2` and stop.
5. Otherwise return success to the caller or monitor.

A carry-consistent draft would look like:

```ish
START:
ADDR  = $0200
LIMIT = 64
SYS_CONSOLE_GET_CSTRING
IF NC HANDLE_IO_ERROR

ADDR = $0200
SYS_STRING_VALIDATE_ASCII
IF NC HANDLE_PARSE_ERROR

A = $00
SYS_SYSTEM_EXIT

HANDLE_IO_ERROR:
A = $E1
SYS_CONSOLE_PRINT_HEX
SYS_SYSTEM_HALT

HANDLE_PARSE_ERROR:
A = $E2
SYS_CONSOLE_PRINT_HEX
SYS_SYSTEM_HALT
```

`IF NC` is intentional here. The current R-YORS service convention generally
uses carry set for success and carry clear for rejection or failure. If `#ISH`
uses `IF C`, it should mean exactly "branch when carry is set"; it should not
silently reinterpret carry according to the preceding call.

The trailing `IF C START` statements from the sketch are omitted because an
unconditional halt should not return. If the intended behavior is retry, the
program should branch to `START` instead of halting. If `SYS_SYSTEM_EXIT` can
fail and return, that contract and its failure branch need to be explicit.

## Small Initial Surface

Keep the first surface deliberately narrow:

```text
LABEL:                  define a code label
A = expression          load an 8-bit register
X = expression
Y = expression
ADDR = expression       load the agreed 16-bit address argument
LIMIT = expression      load the agreed bounded-length argument
ROUTINE_NAME            call or import-and-call a routine
IF C label              branch when carry is set
IF NC label             branch when carry is clear
GOTO label              unconditional branch or jump
RETURN                  return to the caller
```

Expressions should initially be no richer than ASM v1 expressions. Hex remains
`$hhhh`; symbols remain explicit; no implicit strings, dynamic values, or type
conversions are needed. Register names are reserved. Other left-hand names such
as `ADDR` and `LIMIT` are service-facing argument roles, not storage variables.

Routine invocation should resolve through the existing import and RJOIN/AP
machinery. A bare routine name is attractive only if the translator can prove
that it is callable; data exports must not become accidental calls. An explicit
`CALL ROUTINE_NAME` spelling is a reasonable fallback if bare names prove
ambiguous.

## Lowering Direction

The translator should expose rather than replace the W65C02 ABI. For example,
given a service whose real contract is `X/Y=destination`, this:

```ish
ADDR = $0200
SYS_READ_CSTRING
IF NC READ_FAILED
```

could emit:

```asm
        LDX #<$0200
        LDY #>$0200
        JSR SYS_READ_CSTRING
        BCC READ_FAILED
```

The exact expansion belongs to a small service signature description, not a
growing collection of special cases in the parser. That description could
name argument roles, register placement, result registers and flags, callable
kind, and clobbers. It should describe the existing ABI rather than invent a
parallel one.

`#ISH` source should be able to request an AP import for a named service and then
use the assembler's normal linking path. A host-only direct-address mode may
be useful for diagnostics, but should not become the portable program form.

## Gaps Exposed By The Example

The example's friendly names are not all current published R-YORS services.
The closest resident input surface is `SYS_READ_CSTRING`, with `X/Y` carrying
the destination and backend-defined `A/C` results. The repository does not yet
publish the example names `SYS_CONSOLE_GET_CSTRING`,
`SYS_STRING_VALIDATE_ASCII`, `SYS_CONSOLE_PRINT_HEX`, `SYS_SYSTEM_EXIT`, or
`SYS_SYSTEM_HALT` as one coherent application ABI.

More importantly, `A=64` is not enough to make the current C-string reader
bounded. A proposed console-get service must say whether 64 includes the final
NUL, what happens at capacity, whether the buffer is always terminated, and
how Ctrl-C, timeout, blank input, overflow, and editing are distinguished. `#ISH`
must not imply safety that the called service does not provide.

`ERROR=$0080` is unused in the sketch. It could eventually point to a compact
diagnostic card, but that is a separate ABI decision. The first slice should
prefer status in `A` and carry unless a real consumer needs structured error
details.

`SYS_SYSTEM_EXIT` also needs a concrete meaning. For a loaded application it
could lower to `RTS` with `A` and carry as the result. `SYS_SYSTEM_HALT` could
mean an intentional non-returning monitor stop, a `WAI` loop, or `STP` until
reset; those are observably different and should not be hidden behind one name
until the system chooses a contract.

## Suggested First Slice

The smallest useful experiment would contain only:

- a host-side line parser for labels, register/role assignment, named calls,
  `IF C`, `IF NC`, `GOTO`, and `RETURN`;
- a tiny declarative signature table for a few already-published routines;
- ordinary ASM output with comments showing each `#ISH` source line;
- one serial-read example using the existing `SYS_READ_CSTRING` contract and
  a local ASCII validator;
- golden tests that compare exact emitted ASM and rejected input diagnostics.

This slice should not add resident code. It should first answer whether the
notation remains smaller and clearer once real register contracts, imports,
and error paths are shown.

If bounded input is still the motivating example, design and prove that SYS
routine independently. Only after its capacity and failure contract is stable
should `ADDR`, `LIMIT`, and `SYS_CONSOLE_GET_CSTRING` become a standard `#ISH`
signature.

## Proof Questions

Before treating `#ISH` as more than a proposal, demonstrate:

- exact lowering for constants, symbols, low/high address bytes, and forward
  branches;
- rejection of values wider than their assigned register or role;
- unambiguous `C=1` success and `C=0` failure paths;
- preservation of AP import kind and normal unresolved-import failure;
- correct bounded-read behavior at capacities 0, 1, 64, 255, and overflow;
- guaranteed C-string termination on every documented input result;
- explicit clobber behavior across calls;
- no resident ROM or RAM cost for the host-translator slice;
- an emitted program that passes host checks before any board-proof request.

## Decisions To Leave Open

- Whether `#ISH` receives a long name.
- Whether calls are bare routine names or use `CALL`.
- Whether `ADDR` and `LIMIT` are universal roles or service-specific aliases.
- Whether the source is translated directly to ASM text or to a small
  intermediate record first.
- Whether `EXIT` is syntax that lowers to `RETURN`, or a real system routine.
- Whether any future translator belongs on board.
- Whether this notation is a stepping stone toward another language or remains
  a convenient routine-composition format.

Those choices do not need to be frozen to test the central idea: readable
statements, visible machine state, existing routine contracts, and inspectable
W65C02 output made from routines made from routines.
