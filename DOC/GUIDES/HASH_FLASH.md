# HASH FLASH

HASH FLASH is the short alert stream for command-surface changes that are easy
to miss if you remember yesterday's monitor behavior.

The settled calls still belong in [DECISIONS.md](./DECISIONS.md). Operator
syntax belongs in [RTFM-himon.md](./RTFM-himon.md). This file is the readable
bridge between those two places.

Entries use CBI format, named for Computer Bank, Inc., the project author's
RPG II coding-days employer:

```text
YYYY-MM-DDTHH:mm+/-HH:MM programmer comment
```

Use ISO 8601 timestamps without seconds, for example
`2026-05-11T21:33-05:00`.

## REHASH: Command Safety

```text
2026-05-11T21:33-05:00 WLP2 Destructive commands require 4+ characters; current
                             short destructive/proof commands are transition debt.
```

Examples of future destructive command spellings:

```text
COPY start end|+count dest
FILL start end|+count byte
MOVE start end|+count dest
FLASH ...
BANK ...
ERASE ...
```

## REHASH: HIMON Range Syntax

```text
2026-05-11T21:33-05:00 WLP2 HIMON range syntax targets inclusive `start end`
                             plus explicit `start +count`.
```

The target range grammar is:

```text
start end       end is inclusive
start +count    count is the number of bytes
```

Short end tokens inherit the high byte from `start` when that is safe. Common
page-local display stays terse while true counts remain explicit. Use `+count`
only when the operator means a byte count. If a short inherited end would land
before `start`, use a full end address or `+count`.

```text
D 100 3      dump $0100-$0103
D 3000 FF    dump $3000-$30FF
D 3000 +100  dump $3000-$30FF
```

Bare `D` should repeat the previous dump length from the byte after the previous
dump:

```text
D 3000 FF
D            dump $3100-$31FF
```

## REHASH: Search And Step

```text
2026-05-11T21:33-05:00 WLP2 `S` moves from single-step to memory search;
                             step/next moves to `N` or `NEXT`.
```

Target search syntax is:

```text
S addr end|+count b0 [b1 ...]
S addr end|+count b0 [b1 ...] 'TEXT
S addr end|+count 'TEXT
```

Hex byte tokens are the default pattern. Apostrophe text is a final V0 tail: it
consumes the rest of the command line. There is no closing-quote parser and no
return to hex parsing after text.

```text
S 0 FFFF 4D 4D 'M
```

That searches for three `M` bytes.

## FLASHBACK: Search Display

```text
2026-05-11T21:33-05:00 WLP2 Search hits print like D-style context rows: exact
                             hit first, aligned display row second.
```

A hit is immediately inspectable without running a separate `D` command. This
keeps the useful BSO2 monitor search-display convention while making it part of
HIMON's command language. `*` marks a match that continues into the next
16-byte display row.

```text
B88F B880: ...
022B*0220: ...
```

The first word is the exact hit address. The second word is the aligned dump
row.

## FLASHBACK: HBSTR Search

```text
2026-05-11T21:33-05:00 WLP2 Ctrl-letter high-bit-string search remains a design
                             note; V0 search input stays printable.
```

For V0, an operator can use hex for the high-bit terminator or search a useful
partial. A future printable HBSTR form remains possible:

```text
S 0 FFFF `HIMON
```

That would mean `H I M O (N|$80)`.

## REHASH: RAM-Only Debug Edict

```text
2026-05-13T12:43-05:00 WLP2 HIMON debug patching is RAM-only; ROM/flash code
                             may run opaquely, but is not a patch target.
```

Full debugger functionality belongs in RAM. Any debugger operation that plants,
restores, or depends on a synthetic `BRK` must classify the target address
before writing. ROM/flash and I/O targets are rejected for debug patching.

This applies to user breakpoints, temporary `N` / `NEXT` breakpoints, and any
future true stepper that uses trap planting. A debugger trap is not a generic
memory-write probe. HIMON must not test `$8000-$FFFF` by storing `BRK` and
reading it back. Generic memory edit, ROM, flash, and banked flash routines have
their own policy.

ROM/flash can still execute while RAM code is being debugged. A RAM `JSR` into
ROM can be treated as opaque code if the debugger plants the next trap at a
known RAM return address. A `JMP` into ROM is not a returning call. Debug resumes
only when control reaches a known RAM continuation, the user traps with NMI, or
ROM executes an intentional `BRK xx`.

HIMON should distinguish synthetic debugger breakpoints from real `BRK xx`
program behavior. A synthetic RAM breakpoint restores the original opcode and
rewinds PC to the replaced instruction. A real `BRK xx`, including one in
ROM/flash, reports the BRK site and the architectural resume PC:

```text
BRK xx AT=hhhh NEXT=hhhh A=bb X=bb Y=bb P=bb S=bb
```

Address classification is the shared primitive. `UTL_ADDR16_GET_BAND` answers
where an address lives; debug, memory edit, and flash routines decide separately
what they are allowed to do there.

## REHASH: RREC Flash Work And Hash Transition

```text
2026-05-13T12:43-05:00 WLP2 RREC should let RAM flash workers resolve helper
                             routines by hash/routine id across ROM, RAM, and
                             selected flash-bank paths.
```

Future RREC/hashed routine support should make flash/ROM work callable from RAM
without requiring every RAM worker to carry every helper inline.

The intended flow:

```text
build or load a flash/ROM worker into RAM
run the RAM-resident worker
resolve helper calls by routine record / routine id
use the current resolver path
try each configured source in order
fail explicitly if no matching routine is found
```

For a nominal first implementation, the resolver path can be a small fixed list.
The order is policy, not ABI. It may begin with the active ROM/catalog, or it
may prefer a staged RREC block or selected flash-bank page when the operator or
worker explicitly wants newer helper code.

Likely resolver sources:

```text
active ROM/catalog
staged RREC blocks
RAM routine regions
selected flash-bank pages
```

Longer term, the search order should be selectable at runtime or carried as
part of the worker/session policy. The important V0 rule is simple: resolve
predictably, search only named sources, and fail explicitly when no helper is
found.

Resolving a helper in ROM means "call it as opaque ROM code." It does not make
that ROM address debug-patchable. The RAM-only debug edict still applies.

FNV-1a solved immediate command and routine lookup, but it is now transition
debt rather than a permanent promise. Its math is expensive for small W65C02
code. RREC should leave room for a cheaper resolver hash or routine-id scheme.

Candidates under investigation:

```text
eorrot
8-8-16 hash partitioning
other compact routine-id layouts if they prove smaller and easier to verify
```
