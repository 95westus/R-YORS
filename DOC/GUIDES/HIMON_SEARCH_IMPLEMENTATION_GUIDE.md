# HIMON Search Implementation Guide

This guide turns `S` into HIMON memory search without changing source first.
The central workflow is: write and debug the routine in RAM, then build an S19
that writes the proven bytes into flash. After the flash load verifies, the S19
is no longer the thing being run; the code is now resident in the board's
flash-backed "ROM" window.

The order is deliberate:

```text
document the target
prove search as a RAM S19 under HIMON
turn it into a low-flash FNV command-record S19
load that record with L F only after the hole is proven blank
run it from flash/ROM; the S19 becomes proof/delivery history
fold the clean implementation into HIMON later
```

## Current Anchors

- `S` is currently step, but the target command surface moves step/next to `N`
  and frees `S` for search.
- Search syntax is already shaped as:

```text
S addr end|+count b0 [b1 ...]
S addr end|+count b0 [b1 ...] 'TEXT
S addr end|+count 'TEXT
```

- Hex byte tokens are the default pattern atoms. Apostrophe text is a final V0
  tail; it consumes the rest of the command line and does not return to hex
  parsing.
- HIMON command input currently uppercases printable text before dispatch. Exact
  lowercase or mixed-case byte searches use hex spelling until input policy
  changes.
- Search hits print like `D` context rows: exact hit first, aligned display row
  second, and `*` between them when the match crosses a 16-byte display row:

```text
B88F B880: ...
022B*0220: ...
```

- Current `L F` writes only blank bytes in `$8000-$BFFF` and protects
  `$C000-$FFFF`.
- The command-record scanner starts at `$8000`. A flash FNV record for `S` below
  `$C000` can shadow the old in-ROM `S` record without rebuilding HIMON first.

## V0 Behavior

`S` is a prompt command, not a debug trap. It parses, scans, prints hits, and
returns to the prompt. It does not patch user code, consume breakpoints, alter
trap context, or resume execution.

Target behavior:

- `N` remains the only step/next command.
- `NEXT` is not added as an alias.
- Empty patterns are usage errors.
- Malformed ranges, wrapped ranges, too-long patterns, and bad hex bytes are
  usage errors before any scan starts.
- No-hit search should report a compact no-found message rather than silently
  returning. Prefer `S NF` unless a better monitor-wide wording is chosen.
- Ctrl-C during a long scan aborts search and returns to the prompt.
- The pattern buffer is fixed-size. The RAM proof may own its own buffer; the
  final HIMON integration must either reserve search workspace or explicitly
  reuse an existing buffer only when its owner is inactive.

I/O policy must be boring. Reads from `$7F00-$7FFF` are memory-mapped I/O, so a
mistyped all-memory search must not accidentally consume device state. First V0
implementation should skip that I/O window when a range crosses it and print a
short note such as `S IO`. A future explicit I/O-search form can be designed
later if it is ever needed.

## Implementation Shape

Build search as routines of routines, with W65C02S instructions used for size.
The proof can keep these helpers local, but the labels should already show the
shape that can move into HIMON later:

```text
CMD_SEARCH              command entry and usage/error routing
SEARCH_PARSE_PATTERN    append hex bytes and final apostrophe text tail
SEARCH_SCAN_RANGE       walk candidate start addresses
SEARCH_MATCH_AT         compare pattern bytes at current address
SEARCH_PRINT_HIT        print exact hit plus D-style context row
SEARCH_SKIP_IO          skip/report $7F00-$7FFF when a range crosses I/O
SEARCH_CHECK_ABORT      Ctrl-C check during long scans
```

Prefer existing HIMON helpers for parsing, range state, output, and Ctrl-C
where they fit. Add a new helper only when it removes real duplication or keeps
the search body smaller and easier to prove.

W65C02S-size bias:

- use `STZ` for fixed-state clears instead of load/store pairs;
- use `BRA` for local tails and short always-branches;
- use `PHX`/`PLX` and `PHY`/`PLY` when they are smaller than allocating another
  scratch byte;
- keep hot scan pointers in zero page and use `(zp),Y` compares;
- favor tail `JMP` into existing print/write helpers instead of `JSR`/`RTS`
  pairs when the caller is finished;
- do not make a general framework when a tiny callable leaf routine is enough.

## RAM To ROM Lifecycle

Treat every build artifact according to what it actually is:

```text
source .asm        editable truth
RAM proof S19      temporary load/debug package
flash S19          delivery package for L F
flash bytes        resident code in the CPU ROM window
map/listing        proof of where the bytes landed
```

The RAM proof S19 is for fast mistakes. Load it, run it, debug it, throw it
away, rebuild it. It should live in UPA, normally around `$3000`, and should
not rely on being discovered as a HIMON command record.

The flash S19 is different. It is not "the program" in the final state; it is
the packet used to write the program into erased flash. Once `L F` writes and
verifies those bytes, the command record and routine live in the `$8000-$BFFF`
flash window. HIMON can discover the FNV record there on the next command scan.

Keep the flash S19, map, and transcript as provenance, but do not think of the
board as running the S19. It is running the bytes that the S19 delivered.

## Phase 1: RAM Proof

Create a standalone RAM proof, likely:

```text
SRC/TEST/apps/himon-search-proof.asm
SRC/BUILD/s19/himon-search-proof-3000.s19
SRC/BUILD/map/himon-search-proof-3000.map
link address: $3000
```

Current first proof:

```text
make -C SRC himon-search-proof
source: SRC/TEST/apps/himon-search-proof.asm
S19:    SRC/BUILD/s19/himon-search-proof-3000.s19
map:    SRC/BUILD/map/himon-search-proof-3000.map
start:  $3000
RAM:    $7800 line buffer, $7900 pattern buffer
I/O:    BIO_FTDI_* plus BIO_WRITE_*; no SYS_* line/edit stack
size:   $04EB bytes total in the current BIO-backed RAM proof
```

The RAM proof does not need a command FNV record. It can run under HIMON with
`L G` or `L` plus `G 3000`, then provide its own tiny `S>` prompt or run a
canned self-test table using the same grammar planned for HIMON.

Earlier hardware transcripts below were captured on the `$070E` SYS-backed
proof build. They remain behavioral proof for the parser and matcher. The
current source has since been rebuilt to use the BIO layer directly, matching
the rest of HIMON's low-level I/O shape and reducing the RAM image to `$04EB`.
Re-run a short smoke pass after loading the BIO build before using it as the
base for flash-shadow work.

First interactive proof shape:

```text
>L G
S> S 3000 36FF 53
S> S 3000 +100 'HIMON
S> S 7EF0 8010 00
S> Q
```

First hardware observation:

```text
S> S 0 FFFF 'ABCDEFGHIJKLMNOPQRSTUVWXYZ
780A*7800: ... | S 0 FFFF 'ABCDEF
7900*7900: ... | ABCDEFGHIJKLMNOP
S IO

S> S 0 FFFF 'ABCDEFGHIJKLMNOPQRSTUVWXYZ012345
780A*7800: ... | S 0 FFFF 'ABCDEF
7900*7900: ... | ABCDEFGHIJKLMNOP
S IO

S> S 0 FFFF 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456
S START END|+COUNT BB [BB...] ['TEXT], ? HELP, Q QUIT
```

Interpretation:

- Searching `$0000-$FFFF` correctly finds the command line in `$7800` and the
  pattern buffer in `$7900`.
- `*` appears because both matches cross a 16-byte display row.
- `S IO` is expected because the range crosses the memory-mapped I/O page
  `$7F00-$7FFF`; this is a note, not a failure.
- That first pass used a 32-byte pattern cap. The current proof target is
  `SEARCH_PAT_MAX = $40`, so a 64-byte pattern is accepted and 65 bytes or more
  reports usage before scanning.

Second hardware observation after reloading the `$40` build:

```text
>L
L S19
L @3000
L OK=070E GO=3000
>G 3000

S> S 8000 FFFF 'ERASE IS BASED, SEX IS FUN, AND CANDY ROTS YOUR TEETH
S NF

S> S 0 FFFF 'ERASE IS BASED, SEX IS FUN, AND CANDY ROTS YOUR TEETH
780A*7800: ...
7900*7900: ...
S IO
```

Interpretation:

- The reload boundary matters. The older resident RAM proof still enforced the
  32-byte cap; after loading the `$070E` image, a 57-byte text pattern is
  accepted, proving `SEARCH_PAT_MAX = $40` is live.
- Searches over `$0000-$FFFF` are intentionally self-referential: the current
  command line in `$7800`, the current pattern buffer in `$7900`, and search
  zero-page state can all match. Use `$8000-$FFFF` or a narrower range when the
  proof is meant to ignore its own workspace.
- The proof compares only `SEARCH_PAT_LEN` bytes. Shorter later patterns can
  leave old bytes after the active pattern in `$7900`; this is harmless for
  matching but noisy in diagnostic dumps and whole-memory searches. The ROM
  version should either clear or NUL-terminate the pattern buffer if that
  visibility matters.
- Hex patterns such as `S 0 FFFF 0D` correctly find ROM strings, code bytes,
  and the proof's own RAM state. Repeated rows are expected when multiple hits
  land in the same 16-byte display row; a later polish pass can suppress
  duplicate row prints if the byte cost is worth it.

Edge-test observation:

```text
S> S FFFF 0 4D 4D
S START END|+COUNT BB [BB...] ['TEXT], ? HELP, Q QUIT

S> S 3000 3000 20
3000 3000: ...

S> S 3000 3000 20 E6
S NF

S> S 3000 3001 20 E6
3000 3000: ...

S> S 3000 +0 20
S START END|+COUNT BB [BB...] ['TEXT], ? HELP, Q QUIT

S> S FFFF +2 00
S START END|+COUNT BB [BB...] ['TEXT], ? HELP, Q QUIT

S> S 30F0 FF 20
30FA 30F0: ...

S> S 30F0 0F 20
S START END|+COUNT BB [BB...] ['TEXT], ? HELP, Q QUIT

S> S 7F00 7FFF 00
S IO
S NF

S> S 300F 3010 E0 32
300F*3000: ...

S> S F470 F490 0D 0A 'STR8
F474 F470: ...

S> S 0 FFFF 12 34 56 78 9A BC DE F0
7900 7900: ...
S IO

S> S 0 FFFF 12 34 56 78 9A BC DE F0
7900 7900: ...
S ABORT
```

Interpretation:

- Wrapped ranges, zero counts, and `+count` wrap are rejected before scanning.
- Inclusive end behavior is correct: a one-byte range can match one byte, while
  a longer pattern fails if it would run past the inclusive end.
- Page-local end syntax works for two-digit ends: `S 30F0 FF ...` searches
  `$30F0-$30FF`, while `S 30F0 0F ...` rejects the backwards page-local range.
- I/O-only and I/O-crossing ranges skip `$7F00-$7FFF`, report `S IO`, and do
  not hang.
- The row-crossing marker is correct: `300F` with a one-byte match uses a
  space, while `300F` with a two-byte match crossing into `3010` uses `*`.
- Empty patterns, empty apostrophe text, oversized hex words, bad hex tokens,
  and junk after a hex atom all route to usage.
- Mixed hex plus final text tail works.
- Whole-memory no-hit tests are self-polluting because the current pattern is
  stored in `$7900`; use a range that excludes `$7900` when testing no-found.
- Ctrl-C abort reports `S ABORT` and returns to the proof prompt.
- Exact pattern cap boundary is proven: a 64-byte apostrophe string scans and
  a 65-byte apostrophe string routes to usage.

RAM proof checks:

- hex-only pattern: `S 3000 30FF 4D`
- final text tail: `S 3000 30FF 'TEXT`
- mixed hex plus text tail: `S 3000 30FF 4D 'M`
- page-local end syntax after the shared range parser is ready:
  `S 3000 FF ...` means `$3000-$30FF`
- explicit count syntax: `S 3000 +100 ...`
- match at start, middle, and final byte of range
- overlapping matches
- no match
- match that crosses a 16-byte display row
- range crossing `$7F00-$7FFF` skips I/O
- Ctrl-C abort during a long scan
- bad input returns usage and leaves monitor/debug state alone

Use debug proof conventions for intent markers if the proof is self-checking:

```text
BRK 41  proof start
BRK 42  proof pass
BRK E1-E9  bad path
```

During this phase, use `N` for stepping. Treat any remaining `S` step behavior
as old-ROM behavior, not the target.

## Phase 2: Flash Shadow Command

After the RAM proof behaves cleanly, build a low-flash command member. This is
the "give it a hash, create an S19 at a nice hole, and L F it" phase.

The `S` command hash already exists in the current image:

```text
token: S
hash32 display: $D60C1322
record bytes: 46 4E D6 22 13 0C D6 00
meaning: 'F','N',('V'+$80),hash0,hash1,hash2,hash3,kind=$00
```

Candidate placement:

```text
preferred candidate: $B800 if blank on the board
record:              $B800-$B807
entry:               $B808
allowed by L F:      yes, if all target bytes are $FF
protected region:    do not target $C000+
```

`$B800` is a candidate, not a promise. If `$B800` is occupied by CALC, a local
language image, an earlier experiment, or anything not all `$FF`, pick another
blank page in `$8000-$BFFF`. Do not erase as part of this step.

Before `L F`:

```text
record current ROM/bin identity
record the exact S19 and map filenames
dump the candidate flash page and confirm target bytes are $FF
confirm the S19 contains only the intended low-flash range
confirm the S9 start address is the command entry
keep external recovery available before any live flash write
```

Board proof:

```text
>L F            enter flash S19 load mode
send search flash S19
># S            should resolve S to the low-flash entry, not the old ROM step
>S 8000 BFFF 46 4E D6
>S 3000 30FF 'TEXT
>N              still steps trapped context
```

If `L F` reports protect, erase, write, or verify failure, stop. Do not keep
trying variants over a partly written area until the page has been inspected and
the recovery path is clear.

### Flash-Shadow Linking Caveat

`L F` plus a `>$8000` S19 is a good bring-up shape, but it is not the same
thing as real catalog linking.

The RAM proof is deliberately self-contained. Even the BIO-backed proof carries
some payload that already exists in the resident HIMON ROM image:

```text
BIO_FTDI_FLUSH_RX
BIO_FTDI_GET_CTRL_C
BIO_FTDI_READ_BYTE_BLOCK
BIO_FTDI_WRITE_BYTE_BLOCK
BIO_WRITE_CRLF
BIO_WRITE_HEX_BYTE
PIN_FTDI_READ_BYTE_NONBLOCK
PIN_FTDI_WRITE_BYTE_NONBLOCK
UTL_HEX_* helpers
```

That is fine for RAM proof work. It makes the proof independent and keeps
mistakes cheap. If that same object is merely re-orged into low flash, however,
the flash image duplicates resident ROM code and spends low-flash bytes on an
I/O stack that is already present in `$C000-$FFFF`.

Until catalog linking is fully in effect, there are two kludges:

1. Carry the duplicate payload.
   - Pro: easiest to build and reason about; the S19 contains everything it
     needs.
   - Pro: fewer hidden assumptions about the exact HIMON build.
   - Con: wastes low-flash space.
   - Con: can create two copies of I/O/helper behavior if ROM and payload drift.
   - Con: not the final mental model for loadable commands.

2. Call resident ROM helpers by fixed absolute address from the current HIMON
   map.
   - Pro: much smaller flash-shadow command.
   - Pro: closer to how a resident command should behave.
   - Con: tied to one exact HIMON ROM/map build.
   - Con: a later HIMON rebuild can move helper addresses and silently break
     the flash-shadow command.
   - Con: every such S19 must record its expected ROM identity and helper
     addresses.

A future catalog/linking path should remove this choice. A command member
should be able to declare imports such as `BIO_WRITE_HEX_BYTE`,
`BIO_FTDI_GET_CTRL_C`, and `CMD_PARSE_HEX_WORD_TOKEN`, then have the loader or
linker resolve those imports against a resident catalog, ABI table, or stable
jump table. Until then, every `L F` search image must say whether it is
self-contained or ROM-bound.

For the first flash-shadow search, prefer an explicitly documented ROM-bound
artifact if the helper addresses are verified from the active HIMON map. Prefer
a self-contained artifact only if the board state or map identity cannot be
trusted. Either way, record the tradeoff in the log before writing flash.

## Phase 3: HIMON Integration

When the RAM and flash-shadow behavior are both boring, fold the command into
HIMON:

- Move the search implementation into the HIMON source tree.
- Replace the internal `CMD_S_FNV` binding with search.
- Make `CMD_N` own the step path directly instead of jumping through `CMD_S`.
- Update help, usage strings, RTFM, debug testing docs, and generated maps.
- Remove or retire the flash-shadow record from the active image plan so only
  one `S` record wins in normal builds.

## Mistakes Should Not Count

This rule is process and behavior:

- No source change before the plan is agreed.
- No flash write before the RAM proof has a recorded pass.
- No `L F` before the target hole is proven blank.
- No writes to `$C000-$FFFF`, vectors, STR8 space, or the running monitor.
- Bad search syntax is a no-op with usage.
- Bad flash placement is a stopped load, not an invitation to erase.
- Search itself never patches memory.
- Re-running a failed search command cannot make the machine worse.

## Log Template

Use this block for each bench pass:

```text
date:
ROM/bin:
RAM proof S19:
RAM proof map:
flash S19:
flash map:
flash hole:
command hash:
commands tried:
expected:
actual:
pass/fail:
notes:
```
