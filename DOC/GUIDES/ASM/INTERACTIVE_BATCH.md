# Future ASM Interactive And Batch Sessions

Status: parked future command-surface idea. This is not the current ASM path.
The flash-resident `$8000` ASM plan in
[FLASH_8000_GAME_PLAN.md](FLASH_8000_GAME_PLAN.md) treats this as a presentation
split layered on top of the same assembler session spine.

## Current Rule

Today, ASM has one operator-facing session input path. Human typing and pasted
source are treated the same:

```text
ASM RT PASTE
ASM> ORG $7000
OK PC=$7000
ASM> LDA #$41
OK PC=$7002
ASM> END
OK PC=$7002
ASM TABLES
ASM RT PASTE OK
SEAL> .
ASM RT PASTE BYE
```

The current path feeds every accepted physical source line through the same
assembler session spine:

```text
ASM_BEGIN
ASM_ASSEMBLE_LINE
ASM_END
```

There is no present `ASM I`/`ASM B` split, no quiet batch wrapper, and no
different behavior for pasted source. Paste handling remains ordinary line
input plus the existing error/quench policy.

The first flash-resident wrapper, `asm-v1-flash`, is also a simple prompted
session wrapper. It is meant to prove the `$8000` flash image and HIMON FNV
entry path before adding prettier interactive or batch presentation modes.

## Future Idea

A later HIMON command surface may choose to expose two wrappers:

```text
himon>ASM I   prompted interactive session
himon>ASM B   quiet batch/paste session
```

If this is added later, both modes should still use the same source language,
parser, symbol table, fixup table, emitter, and `END` finalization. The mode
would control only console presentation.

## Shared Session Boundary

Whether ASM has one current wrapper or future `ASM I/B` wrappers, `END` remains
the finalization boundary.

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
clean success enters the wrapper's SEAL> command window
```

Do not make interactive use an immediate one-line assembler. A human at the
prompt still owns a full session, and fixups may span lines until `END`.

After a clean `END`, `SEAL> ` is not source mode. It accepts only the wrapper
commands `SEAL`, `NEW`, and `.`. `NEW` is a validated restart at the frozen
`END` PC, not a general `ORG` replacement and not a confirmation prompt. Before
`END`, `SEAL` and `NEW` remain ordinary source words at the `ASM> ` prompt.

## Source Syntax Boundary

Quiet/verbose selection, if it ever exists, is a wrapper choice. It is not ASM
source syntax. Do not add `.Q`, `.V`, or similar source directives for this
purpose.

The source stream remains ordinary ASM source:

```asm
ORG $7000
START LDA #$41
      RTS
END
```

## Timing Detection

Character timing may be useful later as a display convenience, but it must not
change assembler semantics:

```text
same source line handling
same fixup records
same END finalization
same error policy
```

Timing detection is not a current requirement and is not a substitute for any
future explicit command mode.
