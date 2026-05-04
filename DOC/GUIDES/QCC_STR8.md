# QCC STR8

This page keeps STR8 and future STR8-N/STRAIGHTEN questions in QCC form.

## Q: Does STR8 own memory and interrupts?

Comment: The current direction is no. STR8 should be useful in systems where
the user already has memory policy, vector policy, and interrupt layering.
STR8 can cooperate with R-YORS layers, but it should not require ownership of
all RAM, all vectors, or all interrupt behavior.

Concern: STR8 still needs enough reserved workspace and safe entry rules to do
recovery/update work. That reservation should be explicit in the memory map.

## Q: What does STR8 own?

Comment: STR8 owns recovery/update guardrails:

```text
safe boot path
image validation
flash rewrite boundaries
protected recovery window
handoff to HIMON
future condense/compress calls
```

Concern: Normal interactive monitor behavior belongs to HIMON. STR8 should not
grow into a second full monitor by accident.

## Q: Where should ROM garbage collection live?

Comment: STR8/STRAIGHTEN is the right home for dangerous sector rebuilds, or
for calling a catalog maintenance subsystem that performs them.

Concern: HIMON lookup can skip buried records, but should not silently erase or
rebuild sectors during normal command lookup.

## Q: What can STR8 scan?

Comment: Scan ranges may be selected by full start/end, start plus length, or a
4K sector selector:

```text
0-F  one full 4K sector selector
0-7  RAM region selectors
7F   IO page is special
8-F  flash region selectors
```

Concern: RAM, IO, and flash have different rules. A selector that is safe for
flash scanning is not automatically safe for IO probing.

## Q: Why QCC for STR8?

Comment: STR8 is still deciding how small it stays in V0 and how much future
STRAIGHTEN will own.

Concern: Settled boundaries should move into `DECISIONS.md`; experiments and
"what if STR8 owns this?" should stay here until proved.

