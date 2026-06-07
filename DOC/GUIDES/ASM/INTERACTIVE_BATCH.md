# ASM Interactive And Batch Sessions

Status: design note for the monitor-facing ASM command surface.

## Core Idea

Interactive and batch ASM are not two assemblers. They are two console contracts
for the same full ASM session:

```text
himon>ASM I   prompted interactive session
himon>ASM B   quiet batch/paste session
```

Both modes use the same session spine:

```text
ASM_BEGIN
ASM_ASSEMBLE_LINE
ASM_END
```

The source language, parser, symbol table, fixup table, emitter, and final
`END` behavior are identical. The mode only controls what the HIMON-side input
driver prints while it feeds source lines to the assembler.

## Session Boundary

`END` is the real finalization boundary in both modes.

Before `END`:

```text
labels may be defined
forward references may create fixups
pending fixups may remain unresolved
the session PC advances according to emitted-width decisions
```

At `END`:

```text
ASM_END resolves final fixups
unresolved required fixups fail the session
range and width checks for pending fixups are enforced
the final status/report path runs
```

Do not make interactive mode an immediate one-line assembler. A human at the
prompt still owns a full session, and fixups may span lines until `END`.

## Interactive Mode

`ASM I` is for a human operator at the monitor.

Expected console behavior:

```text
himon>ASM I
asm> ORG $7000
... per-line feedback ...
asm> JSR LATER
... pending fixup feedback if useful ...
asm> LATER RTS
... definition/fixup feedback if useful ...
asm> END
... final status/report ...
himon>
```

Interactive mode may show:

```text
prompt before each input line
accepted-line status
current PC
short emitted-byte listings
definition or fixup hints
named error/status text
```

The exact listing text is a wrapper/display decision. Existing hardware
transcripts may show `ASM> `; the design point is that prompted mode has a
visible ASM prompt and useful per-line feedback.

## Batch Mode

`ASM B` is for pasted or transmitted source.

Expected console behavior:

```text
himon>ASM B
ORG $7000
JSR LATER
LATER RTS
END
... final status/report ...
himon>
```

Batch mode should not print:

```text
per-line prompts
per-line accepted-line status
per-line emitted-byte listings
routine "OK PC=$hhhh" chatter
```

Batch mode may still print errors and final status/report output. It is quiet
while accepted source lines are flowing, but it is not silent about failure.

## No Source-Mode Directives

Quiet/verbose selection is not ASM source syntax. Do not add `.Q`, `.V`, or
similar source directives for this purpose.

The mode is chosen by HIMON before the session begins:

```text
ASM I
ASM B
```

The source stream remains ordinary ASM source:

```asm
ORG $7000
START LDA #$41
      RTS
END
```

## Timing Detection

Character timing may be used only as a display convenience inside `ASM I`.

For example, if a human starts in `ASM I` and then pastes a burst of source, the
input driver may temporarily suppress repeated prompts or per-line listings
while the burst is active. That heuristic must not change assembler semantics:

```text
same source line handling
same fixup records
same END finalization
same error policy
```

Explicit `ASM B` remains the deterministic batch path. Timing detection is not
a substitute for the command mode.

## Bare ASM

If HIMON keeps a bare `ASM` command during transition, it should be treated as a
compatibility alias for interactive mode:

```text
ASM      same as ASM I
```

That keeps the operator-facing default friendly while still giving scripted
paste workflows a quiet `ASM B` path.

