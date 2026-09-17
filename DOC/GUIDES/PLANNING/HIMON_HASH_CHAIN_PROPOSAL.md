# HIMON Explicit-Call Register Chains

Status: proposal only. This document does not describe the current HIMON
image, an implementation commitment, or hardware-proven behavior. The current
qualified command remains `# ![+] NAME` and always prints a return report; see
[HIMON_HASH_CALL_2026-09-17.md](../HIMON/HIMON_HASH_CALL_2026-09-17.md).

This proposal records a possible HIMON bridge into the broader `#ISH`
interactive language direction. The authoritative language-level proposal is
maintained in the sibling `R-YORS-II` repository. This document owns only the
possible behavior of a future R-YORS HIMON implementation.

## Proposed Explicit-Call Form

```text
# ![+] NAME [A=aa] [X=xx] [Y=yy] [P=pp]
             [N|n] [V|v] [D|d] [I|i] [Z|z] [C|c] [RET]
```

`NAME` identifies exactly one returning resident executable FNV record. The
existing `+` modifier remains orthogonal to return reporting: it requests the
`#hash# ENTRY=address` identity line. `RET` requests the returned-register
report. Without `RET`, HIMON suppresses its report but still captures returned
machine state for the next explicit call. Output emitted by the target routine
itself is never suppressed by this option.

The proposed chain state is `A`, `X`, `Y`, and `P`:

- `A=aa`, `X=xx`, and `Y=yy` replace one inherited byte.
- `P=pp` replaces the complete proposed input status byte.
- An uppercase flag token sets its bit; its lowercase form clears it.
- Flag tokens are `N/n`, `V/v`, `D/d`, `I/i`, `Z/z`, and `C/c`.
- Options apply from left to right, so a flag token may refine an earlier
  `P=pp`.
- Any value not mentioned is inherited from the preceding successful return.

`B/b` is excluded. The 6502 break indication is not ordinary persistent
processor state. Status bit 5 is normalized according to the machine profile.

The hardware stack pointer is deliberately not assignable or inherited. HIMON
owns S while its parser, call trampoline, target call, and `RTS` return are
active. A `RET` report may continue to display the observed S for diagnosis,
but S is not chain state. A routine needing a software-stack or workspace
pointer must receive it through its documented register or memory ABI.

Example:

```text
# ! FIRST A=10 C
# ! SECOND n
# !+ THIRD Z RET
```

`SECOND` inherits the returned state of `FIRST`, changes only N, and executes
without a HIMON return report. `THIRD` inherits the return from `SECOND`, sets
Z, prints its identity because of `+`, and prints its return because of `RET`.

## State And Failure Rules

- A successful `RTS` return captures A/X/Y/P even when `RET` is absent.
- Parse failure must not partially alter chain state.
- Lookup failure, a non-executable record, refused confirmation, or a false
  condition must leave chain state unchanged.
- The first call after cold or warm entry needs documented initial A/X/Y/P
  values; no implementation may inherit uninitialized RAM accidentally.
- A live NMI, BRK, or debugger context continues to block an explicit call.
  Interactive chaining must not overwrite stopped-machine state.
- A called routine must obey the normal HIMON call/stack contract. A blocking
  or non-returning routine retains that behavior.
- Returned decimal state must be captured before HIMON clears D for its own
  formatting work.

The input trampoline must restore A/X/Y/P without allowing register loads to
replace the requested condition flags. One viable ordering is to load Y and X,
push saved P, load saved A, pull P, and only then enter the target. The exact
implementation remains subject to size and stack-depth proof.

## Proposed Conditional Form

One condition may guard the rest of an input record:

```text
IF A=xx command
IF X=xx command
IF Y=xx command
IF P=xx command
IF N command
IF n command
IF V command
IF v command
IF D command
IF d command
IF I command
IF i command
IF Z command
IF z command
IF C command
IF c command
```

The condition reads retained chain state without changing it. When true, the
remainder executes as one ordinary HIMON command and may establish new chain
state. When false, the record is silent and the retained state is unchanged.
The initial proposal has one condition, no compound expression, and no `ELSE`.

```text
# ! READ_CHAR
IF A=59 # ! YES
IF A=4E # ! NO

# ! TRY_OPERATION
IF C # ! SUCCESS RET
IF c # ! FAILURE RET
```

Conditions are evaluated when their record is reached. If a true arm calls a
routine, a following `IF` sees that routine's return rather than a frozen copy
of the state tested by the first `IF`. This is intentional chaining. A future
mutually exclusive `IF`/`ELSE` form would need a separate proposal.

## Compatibility And Qualification Gates

This proposal changes the default output of explicit calls, so it cannot be
presented as a compatible implementation detail. Existing scripts and board
checks currently expect `# ! NAME` to print `RET`. Any implementation must
either accept that intentional command-language change or introduce a versioned
or alternate spelling.

Before acceptance, the implementation must include:

- a final grammar and stable usage/error text;
- defined cold-entry and warm-entry chain initialization;
- transactional parsing and exact left-to-right option behavior;
- host tests for every register, flag, failure path, and conditional form;
- stack-depth and decimal/interrupt-state tests using real call paths;
- retained debugger, AP/APMAN, ASM handoff, and bare-name regressions;
- resident size measurement and any required size recovery;
- updated HIMON documentation and automation expectations; and
- board proof, exact readback, reset recovery, and preserved transcripts.

No ASM Feature Queue checkbox should be changed merely because this proposal
exists. Implementation, measurement, regression evidence, documentation, and
required board proof must agree first.
