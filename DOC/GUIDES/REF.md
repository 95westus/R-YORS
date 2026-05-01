# R-YORS Reference

This reference is scoped to the current `ror` workspace.

## Source Lanes

```text
SRC/STASH   stable or promoted code lane
SRC/TEST    active build/test lane, including Himonia-F work
SRC/SESH    session/WIP lane
SRC/BUILD   build output
SRC/tools   host-side build/support scripts
```

Current ASM file count:

```text
SRC/STASH: 1
SRC/TEST:  35
SRC/SESH:  1
```

## Monitor Lineage

```text
himon.asm        smaller monitor shell
himonia.asm      compact supervisory monitor
fnv1a-hbstr.asm  FNV-1a/HBSTR proving app
himonia-f.asm    current FNV-driven path toward HIMON
```

Primary path:

```text
SRC/TEST/apps/himon/
```

## Current Design Names

```text
R-YORS       whole project/system
STR8         Straight 8 boot/recovery/update layer
HIMON        final monitor name that Himonia-F will become
Himonia-F    current FNV-driven implementation path toward HIMON
HASHED_ASM   onboard assembler design using hash symbols and fixups
```

Boot relationship:

```text
R-YORS boots through STR8.
STR8 keeps recovery/update safe.
STR8 hands normal operation to HIMON.
HIMON provides the monitor, command dispatch, assembler, catalog lookup,
and debug tools.
```

## Flash And Bank Policy

```text
bank 3:
  keep cleaner for boot/current monitor/catalog/trampoline material

banks 0-2:
  prefer for growth packs, onboard-built exports, expanded command text,
  stale records, and condense candidates
```

STR8 should scan by bank, report candidate writable sections, and refuse
protected anchor/vector/ABI regions.

STR8 owns the hardware vector bytes. HIMON/Himonia-F may install active
NMI/BRK/IRQ handlers through STR8/SYS vector routing, but recovery ownership
stays with STR8.

Preferred STR8 anchor:

```text
$F800-$FFFF  STR8 protected anchor
$F800-$FFF9  STR8 code/data portion
$FFFA-$FFFF  W65C02 vectors protected by STR8 policy
```

Fallback anchor:

```text
$F000-$FFFF  larger STR8 protected region
```

## Hash Policy

```text
routine header HASH   32-bit FNV-1a over canonical routine text
runtime/catalog hash  32-bit FNV-1a lookup used by Himonia-F/HIMON
symbol hash           32-bit FNV-1a assembler/catalog lookup key
name text             optional proof/listing/collision data
```

Hash is a lookup key, not identity by itself. When identity matters, compare the
stored canonical name text after the hash narrows the candidate set.

FNV-1a is the only runtime/catalog symbol hash. Catalog records do not need a
per-record algorithm tag.

Compact signature policy:

```text
'F'  catalog hash record format v1
'N'  catalog hash record format v2
'V'  catalog hash record format v3
```

All formats still use FNV-1a. Replacing a 3-byte `FNV` text signature with one
format byte saves 2 bytes per record.

## Record Byte Order

```text
word      low byte, then high byte
long      byte0..3, least significant to most significant
hash0..3  FNV-1a low byte through high byte
```

Example:

```text
.word $1234      -> $34,$12
.long $89ABCDEF  -> $EF,$CD,$AB,$89
```

## Tiny ASM Command Surface

```text
A [addr] [label:] MMM [operand] .
                            assemble one statement
DEF name addr kind         define a symbol manually
SYM [name]                 list symbol(s)
FIX                        list unresolved fixups
RESOLVE                    attempt to apply all pending fixups
FORGET name                remove or mark a symbol dead
EXPORT name                mark symbol visible for command/routine lookup
```

`A [addr]` without a complete one-shot statement enters the interactive side of
the assembler.

## Useful Make Targets

```text
make -C SRC himon
make -C SRC himonia
make -C SRC himonia-f
make -C SRC test-mon
make -C SRC test-flash
make -C SRC calc-flash
make -C SRC routine-hash-comments
```

`make -C SRC docs` currently targets source-generated docs in `SRC`. The guide
set under `DOC/GUIDES` is hand-maintained design/reference material unless a
future generator is added.
