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

## Q: How long should a 32K STR8 flash copy take?

Comment: The SST39SF010A chip timing gives a useful lower bound, not the current
STR8 RAM proof wall-clock time. The part has uniform 4K sectors, typical 4K
sector erase time of about 18 ms, and typical byte-program time of about 14 us.
For a dense 32K bank rewrite:

```text
8 sectors * 18 ms       = 144 ms erase time
32768 bytes * 14 us     = 459 ms program time
chip-level lower bound  ~= 0.6 s before software/read/verify overhead
```

The current RAM proof is intentionally simple and slower. It calls
`FLASH_WRITE_BYTE_RAW_AXY` for each non-`$FF` byte, and that routine copies the
RAM flash worker before each byte program. At the current 8 MHz timing model,
that worker-copy overhead alone is roughly 0.5 ms per programmed byte, so a
dense 32K image can land in the 20-30 second range. Sparse images with many
`$FF` bytes are faster because STR8 skips byte-program calls for `$FF` source
bytes.

Concern: Do not use visible LED activity as the timing proof. The first real
proof should measure serial progress or an explicit activity pin around erase,
program, and verify phases. Later STR8 should batch the RAM worker or keep it
resident for a sector/bank operation so the observed time moves closer to the
flash device timing.

## Q: Why QCC for STR8?

Comment: STR8 is still deciding how small it stays in V0 and how much future
STRAIGHTEN will own.

Concern: Settled boundaries should move into `DECISIONS.md`; experiments and
"what if STR8 owns this?" should stay here until proved.
