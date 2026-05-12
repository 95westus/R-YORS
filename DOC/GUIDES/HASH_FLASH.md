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
