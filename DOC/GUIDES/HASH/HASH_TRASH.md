# Hash Trash

This file is the parking lot for hash/catalog ideas that are tempting enough to
remember, but not ready to become ABI, source layout, or command behavior.

An item in Hash Trash is not automatically bad. It means: do not build on it
until the project has a proof, a record shape, and a reason it beats the simpler
rule.

## Parked: Use K Bits 2 And 3 As Selector Or Permission

Idea:

```text
K bit 0  executable/callable
K bit 1  confirm before execution
K bits 2-3 selector, permission, or policy
```

Status: parked.

Reason:

```text
selector      asks "which body/provider/space?"
permission    asks "who may do this, and under what authority?"
kind          currently asks "can this be called, and must it confirm?"
```

Those are different questions. Packing them into one byte too early makes the
first catalog linker harder to reason about. A selector may need a full field,
a compact table index, or a provider class. A permission may need operator
state, recovery context, flash range authority, or a separate safety record.
None of those should be hidden in two spare K bits before the record format
knows what it is protecting.

Current rule:

```text
K=$00  described/known, not directly executable
K=$01  executable/callable
K=$03  executable/callable with confirmation
bits 2-3 reserved
```

Future permission or selector work should get its own QCC note first. If it
survives that, promote it into `DECISIONS.md` as a named record field or control
byte, not as a casual reinterpretation of K.

## Candidate: K Bit 2 For Command Expansion

Idea:

```text
K bit 0  executable/callable
K bit 1  confirm before execution
K bit 2  command expansion/completion allowed
```

This is a better candidate than a general selector because it is still about
command behavior. Exact hash lookup would not change: if the user types the
full token and bit 0 is set, the record may execute. Prefix completion,
abbreviation expansion, or automatic "AS -> ASM" style help would only consider
records where bit 2 is set.

That gives dangerous entries a clean shape:

```text
K=$03  executable + confirm, exact name only
```

`BOOT_COLD_RESET`, `BOOT_WARM_RESET`, flash erase/write, and future reset or
recovery commands should stay exact-only unless there is a strong reason to
make them expandable. Friendly interactive commands could eventually use:

```text
K=$05  executable + expandable
K=$07  executable + confirm + expandable
```

Status: parked, but promising. Do not spend bit 2 until HIMON actually has a
completion/expansion path to enforce the rule.
