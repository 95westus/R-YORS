# HIMON Search Implementation Guide

This guide turns the freed `S` command slot into HIMON memory search. The
central workflow still starts outside the resident source: write and debug the
routine in RAM, then build an S19 that writes the proven bytes into flash.
After the flash load verifies, the S19 is no longer the thing being run; the
code is now resident in the board's flash-backed "ROM" window.

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

- `S` is no longer the resident step command; `N` owns step/next and `S` is
  available for search.
- Search syntax is already shaped as:

```text
S addr end b0 [b1 ...] 'TEXT' bx ...
S addr +count b0 [b1 ...] 'TEXT' bx ...
```

- After the range, each pattern atom is either a hex byte token or an
  apostrophe-quoted text chunk. Text chunks can appear at the start, middle, or
  end of the pattern. Use hex byte `$27` when the pattern must contain an
  apostrophe byte.
- Resident HIMON command input currently uppercases printable text before
  dispatch. The current RAM proof preserves printable input and only folds the
  command letter, so lowercase and mixed-case apostrophe text can be tested
  directly there.
- Search hits print like `D` context rows: exact hit first, aligned display row
  second, and `*` between them when the match crosses a 16-byte display row:

```text
B88F B880: ...
022B*0220: ...
```

- Current `L F` writes only blank bytes in `$8000-$BFFF` and protects
  `$C000-$FFFF`.
- The command-record scanner starts at `$8000`. A flash FNV record for `S` below
  `$C000` can own the search command before the integrated HIMON search body is
  folded in.

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
SEARCH_PARSE_PATTERN    append hex bytes and apostrophe-quoted text atoms
SEARCH_SCAN_RANGE       walk candidate start addresses
SEARCH_MATCH_AT         compare pattern bytes at current address
SEARCH_PRINT_HIT        print exact hit plus D-style context row
SEARCH_SKIP_IO          skip/report $7F00-$7FFF when a range crosses I/O
SEARCH_CHECK_ABORT      Ctrl-C check during long scans
```

Prefer existing HIMON helpers for parsing, range state, output, and Ctrl-C
where they fit. Add a new helper only when it removes real duplication or keeps
the search body smaller and easier to prove.

Search abort polling deliberately uses the current BIO Ctrl-C routine as a
consuming poll. That is acceptable while search owns the keyboard during a long
scan: ordinary pending input can be thrown away because the operator is trying
to interrupt the scan. Do not generalize that routine into a monitor-wide
keyboard peek. A future non-destructive peek belongs above the FTDI PIN layer as
BIO-owned lookahead storage, and all RX readers would then need to consume
through BIO so the cached byte and hardware FIFO do not diverge.

Keep the stable block-read/write contracts stable during search work.
`BIO_FTDI_READ_BYTE_BLOCK` and `BIO_FTDI_WRITE_BYTE_BLOCK` are unbounded waits.
If search, HIMON, or a future prompt needs bounded I/O, use timeout-shaped BIO
helpers or explicit wait-long wrappers that return `C=0` on timeout. Do not make
existing block callers suddenly depend on carry checks they may not perform.

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

The join proof is not the search proof. It proves the small runtime service
boundary that search should eventually use:

```text
caller has a hash -> resident joiner finds executable record -> caller invokes it
```

That is the bootstrap layer. Search is the real command proof. Its promotion
path should be:

```text
RAM standalone search
RAM search using resident join helpers
RAM search with the same command header shape planned for flash
low-flash search placed only in a proven blank hole
L F delivery into $8000-$BFFF
later fold the boring version into HIMON proper
```

This keeps each question separate. The join proof answers "can a loaded routine
find and call resident services without fixed addresses?" Search answers "does
the actual command parse, scan, print, abort, and avoid I/O correctly?" The
flash-shadow phase answers "can this command live as a discoverable record in
low flash before it is part of the HIMON ROM build?"

When the full assembler/linker path exists, this ladder gets shorter but does
not disappear. The board-side tools should be able to emit the command record,
record imports, resolve or fix up joins, and place the bytes in an approved
hole. That removes much of the host-side S19/relink ceremony. It does not remove
the need to prove behavior in RAM before writing flash, or to prove the flash
destination is blank before `L F`.

## Phase 1: RAM Proof

Phase 1 has two RAM artifacts:

```text
static-linked first proof:
SRC/TEST/apps/himon-search-static-proof.asm
SRC/BUILD/s19/himon-search-static-proof-3000.s19
SRC/BUILD/map/himon-search-static-proof-3000.map
link address: $3000

hash-resolved follow-up proof:
SRC/TEST/apps/himon-search-proof.asm
SRC/BUILD/s19/himon-search-proof-3000.s19
SRC/BUILD/map/himon-search-proof-3000.map
link address: $3000
```

The first pass is intentionally static-linked:

```text
make -C SRC himon-search-static-proof
source: SRC/TEST/apps/himon-search-static-proof.asm
S19:    SRC/BUILD/s19/himon-search-static-proof-3000.s19
map:    SRC/BUILD/map/himon-search-static-proof-3000.map
start:  $3000
RAM:    $7800 line buffer, $7900 pattern buffer
I/O:    static-linked BIO_FTDI_* plus UTL_HEX_ASCII_TO_NIBBLE payloads
size:   $0520 bytes total in the current static-linked RAM proof
```

The RAM proof does not need a command FNV record. It can run under HIMON with
`L G` or `L` plus `G 3000`, then provide its own tiny `S>` prompt or run a
canned self-test table using the same grammar planned for HIMON.

### Phase 1A: Standalone RAM S

Start the next search pass with the static-linked standalone RAM `S>` tool.
This phase is about command behavior only:

```text
load:      L or L G with SRC/BUILD/s19/himon-search-static-proof-3000.s19
entry:     $3000
prompt:    S>
scope:     parse, scan, print hits, no-found, usage, Ctrl-C, I/O skip
not yet:   runtime imports, command FNV record, flash placement, L F delivery
```

Keep two records for every board pass:

```text
actual board output  exact serial transcript, minimally edited
summary transcript   short operator-readable command/result log
```

The actual board output is the evidence. Paste it as received, including
prompts, typos, loader output, and odd spacing. The summary transcript is the
working memory: one line per important command, with expected/observed result
and a short note when behavior changes.

Use this entry shape for new passes:

### YYYY-MM-DD RAM standalone search pass

Build identity:

```text
S19: SRC/BUILD/s19/himon-search-static-proof-3000.s19
map: SRC/BUILD/map/himon-search-static-proof-3000.map
HIMON map/bin under test:
start: $3000
pattern max:
notes:
```

Actual board output:

```text
paste exact serial transcript here
```

Summary transcript:

```text
L/G search proof -> S> prompt
S 34AF +20 'HIMON' -> expected/observed
S 7EF0 8010 00    -> expected S IO note if range crosses $7F00-$7FFF
S ...             -> expected/observed
Q                 -> returns to HIMON
```

Result:

```text
PASS/FAIL/PARTIAL, with next action
```

### 2026-05-21 RAM standalone search pass

Build identity:

```text
S19: SRC/BUILD/s19/himon-search-static-proof-3000.s19
map: SRC/BUILD/map/himon-search-static-proof-3000.map
HIMON under test: HIMON V 00.0521(1847)
start: $3000
loaded size: $0520
map end: $3520
pattern max: $40
notes: static-linked proof; MSG_TITLE at $34AF
```

Actual board output:

```text
HIMON V 00.0521(1847)
>L
L S19
L @3000
L OK=0520 GO=3000
>G 3000
GO 3000
HIMON SEARCH STATIC $3000
S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUIT
S> s 3000 +100 53
304F 3040: AC 31 F0 1E C9 3F F0 25 | 29 DF C9 51 F0 16 C9 53 | .1...?.%)..Q...S
S> s 3000 +100 'HIMON'
S NF
S> s 3000 +100 48 'IMON'
S NF
S> S 3000 +100 'HI' 4D 'ON'
S NF
S> S 3000 +100 ''
S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUIT
S> S FFFF 0 00
S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUIT
S> S 3000 +0 20
S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUIT
S> S 7EF0 8010 00
7EF0 7EF0: 00 00 00 00 00 00 00 00 | 74 E1 43 D1 9C D1 EA D1 | ........t.C.....
7EF1 7EF0: 00 00 00 00 00 00 00 00 | 74 E1 43 D1 9C D1 EA D1 | ........t.C.....
7EF2 7EF0: 00 00 00 00 00 00 00 00 | 74 E1 43 D1 9C D1 EA D1 | ........t.C.....
7EF3 7EF0: 00 00 00 00 00 00 00 00 | 74 E1 43 D1 9C D1 EA D1 | ........t.C.....
7EF4 7EF0: 00 00 00 00 00 00 00 00 | 74 E1 43 D1 9C D1 EA D1 | ........t.C.....
7EF5 7EF0: 00 00 00 00 00 00 00 00 | 74 E1 43 D1 9C D1 EA D1 | ........t.C.....
7EF6 7EF0: 00 00 00 00 00 00 00 00 | 74 E1 43 D1 9C D1 EA D1 | ........t.C.....
7EF7 7EF0: 00 00 00 00 00 00 00 00 | 74 E1 43 D1 9C D1 EA D1 | ........t.C.....
S IO
S>
```

Summary transcript:

```text
L/G search proof -> static S> prompt PASS
S 3000 +100 53 -> hit at $304F PASS
S 3000 +100 'HIMON' -> S NF, expected because title/data is outside $3000-$30FF
S 3000 +100 48 'IMON' -> S NF for same range reason
S 3000 +100 'HI' 4D 'ON' -> S NF for same range reason
S 3000 +100 '' -> usage PASS
S FFFF 0 00 -> usage PASS
S 3000 +0 20 -> usage PASS
S 7EF0 8010 00 -> hits before I/O window, then S IO PASS
```

Follow-up actual board output:

```text
S> S 34AF +20 'HIMON'
34AF*34A0: 57 38 60 38 E9 37 38 60 | 38 E9 30 38 60 18 60 48 | W8`8.78`8.08`.`H
S> 'HI' 4D 'ON'
S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUIT
S> S 34AF +20 'STATIC' 20 24
34BC*34B0: 49 4D 4F 4E 20 53 45 41 | 52 43 48 20 53 54 41 54 | IMON SEARCH STAT
S>
```

Second follow-up actual board output:

```text
S> S 34AF +20 'STATIC' 20 24
34BC*34B0: 49 4D 4F 4E 20 53 45 41 | 52 43 48 20 53 54 41 54 | IMON SEARCH STAT
S> S 34AF +20 48 'IMON'
34AF*34A0: 57 38 60 38 E9 37 38 60 | 38 E9 30 38 60 18 60 48 | W8`8.78`8.08`.`H
S>
```

Quit actual board output:

```text
S> Q
S DONE

#GO# ENTRY=3000
RET A=0A X=19 Y=06 P=75 S=FD NV-BdIzC
>
```

Follow-up summary:

```text
S 34AF +20 'HIMON' -> hit at $34AF PASS
'HI' 4D 'ON' -> usage PASS, command omitted the required range prefix
S 34AF +20 'STATIC' 20 24 -> mixed text/hex hit at $34BC PASS
S 34AF +20 48 'IMON' -> mixed hex/text hit at $34AF PASS
Q -> S DONE, #GO# return report, HIMON prompt PASS
```

Result:

```text
PASS for the static RAM proof. Loader, prompt, hex search, quoted text, mixed
text/hex atoms, bad range handling, empty quoted text, zero count handling, I/O
skip note, and clean `Q` return to HIMON are proven.
```

Next board checks:

```text
S 34AF +20 'HI' 4D 'ON'
```

First RAM standalone checklist:

```text
build himon-search-static-proof
load and enter at $3000
prove the S> prompt appears
prove at least one hex-byte pattern search
prove at least one apostrophe text search
prove no-found output
prove usage on malformed input
prove $7F00-$7FFF I/O skip note
quit cleanly back to HIMON
```

### Phase 1B: RAM Hash-Resolved S

After the static-linked proof is boring, move to the current hash-resolved RAM
proof:

```text
make -C SRC himon-search-proof
source: SRC/TEST/apps/himon-search-proof.asm
S19:    SRC/BUILD/s19/himon-search-proof-3000.s19
map:    SRC/BUILD/map/himon-search-proof-3000.map
start:  $3000
RAM:    $7800 line buffer, $7900 pattern buffer
I/O:    hash-resolved resident BIO_FTDI_* plus local hex output; no SYS_* stack
size:   $0589 bytes total in the current hash-resolved RAM proof
```

This version still carries its own tiny record scanner, but it no longer carries
the BIO/FTDI helper payloads. It resolves current HIMON inline executable
records by requiring kind bit 0, then calls the resident entries. It deliberately
does not handle pointer/extra record shapes; that belongs to the resident join
layer or a later import resolver phase. If it cannot resolve the first write
import, it returns before printing with `A=$E1`. If a later import fails, it can
print `S IMP` and returns `A=$E2` through `$E5` for READ, FLUSH, CTRL-C, or
HEX-IN.

The smaller HREC join proof isolates the resolver/join idea before search uses
it as a normal dependency path:

```text
make -C SRC hrec-join-proof
source: SRC/TEST/apps/hrec-join-proof.asm
S19:    SRC/BUILD/s19/hrec-join-proof-4000.s19
map:    SRC/BUILD/map/hrec-join-proof-4000.map
start:  $4000
size:   $05FC bytes total in the current bootstrap proof
```

This proof carries a tiny local scanner only long enough to find resident
`THE_JOIN_EXEC_XY`. After that, ordinary joins go through HIMON's resident
joiner. It silently joins `BIO_FTDI_WRITE_BYTE_BLOCK` first; if the joiner or
write routine is missing, it returns without printing. Once write is joined, it
prints through the joined ROM routine, joins READ/FLUSH/CTRL/HEX by hash, and
makes one real joined call to `UTL_HEX_ASCII_TO_NIBBLE` by parsing `'A'` into
`$0A`.

The same proof also checks a missing hash, rejects a non-executable kind, proves
the joined hex helper can report its own input error by rejecting `'G'`, proves
a RAM-local pointer/extra record, and lets the operator type hashes at `J>`.

Expected current output:

```text
HREC JOIN PROOF $4000
WRITE H=$379FE930 E=$DF09 OK
JOINER H=$A9AF15F7 E=$DB0D OK
READ H=$20285B85 E=$DEF7 OK
FLUSH H=$2F6622B9 E=$E212 OK
CTRL H=$426150D2 E=$E22E OK
HEX H=$ADD714B1 E=$E18D IN=A OUT=$0A OK
MISSING H=$DEADBEEF E=---- NF OK
KIND K=$02 OK
HEXINV H=$ADD714B1 E=$E18D IN=G C=0 OK
PTR H=$76543210 E=$4235 X=PTR-EXTR OUT=$10 OK
TYPE 8 HEX HASH, CR QUIT
J> 76543210
USER H=$76543210 E=$4235 OK
J> 379FE930
USER H=$379FE930 E=$DF09 OK
J> DEADBEEF
USER H=$DEADBEEF E=---- NF
J>
DONE
```

See `DOC/GUIDES/CATALOG/HREC_JOIN_PROOF.md` for the Q/A trail, terminology, edge cases,
and size notes behind this proof.

Earlier hardware transcripts below were captured on the `$070E` SYS-backed
proof build. They remain behavioral proof for the parser and matcher, but some
text examples use the older apostrophe-to-end-of-line tail. The current parser
uses closed apostrophe text atoms so hex bytes may follow text. The current
source has since been rebuilt to use the BIO layer directly, matching the rest
of HIMON's low-level I/O shape. The BIO build was `$04EB`; after
`BIO_FTDI_READ_BYTE_BLOCK` gained its promoted 8-byte FNV signature, the image
became `$04F3`; after `BIO_FTDI_WRITE_BYTE_BLOCK` gained the same promoted
8-byte FNV signature, the image became `$04FB`; after
`PIN_FTDI_READ_BYTE_NONBLOCK` and `PIN_FTDI_WRITE_BYTE_NONBLOCK` gained their
promoted 8-byte FNV signatures, the image became `$050B`; after
`BIO_FTDI_FLUSH_RX` gained its promoted 8-byte FNV signature, the image is
`$0513`; after the linked `UTL_HEX_NIBBLE_TO_ASCII`,
`UTL_HEX_BYTE_TO_ASCII_YX`, and `UTL_HEX_ASCII_TO_NIBBLE` helpers gained their
promoted 8-byte FNV signatures, the image is `$052B`; after the proof stopped
linking resident helper payloads and resolved `BIO_FTDI_*` plus
`UTL_HEX_ASCII_TO_NIBBLE` by emitted hash headers at startup, the image is
`$0572`; after the proof stopped uppercasing apostrophe text and kept only the
command-letter fold, the image is `$0565`; after the local resolver accepted
current inline executable kind `$01` instead of requiring kind `$00`, the image
is `$056B`; after the parser switched to closed quoted text atoms, the image is
`$0571`; after empty quoted text atoms were rejected explicitly, the image is
`$0579`; after stale resolver `BNE fail` checks were removed and import failure
return codes were added, the image is `$0589`. Re-run a short smoke pass after
loading the current ROM-bound build before using it as the base for flash-shadow
work.

2026-05-21 first hash-resolved board observation, using the older `$0579` image:

```text
>G F000
GO F000

____      ____    ____   ____      ____
|   \    /   |   /    \  |   \    /
|___/    |___|  |      | |___/    \___
|   \    /   |  |      | |   \        \
|    \  /    |   \____/  |    \   ____/

HIMON IN 3S. S=STR8  3 2 1
BOOT COLD
RAM ZERO OK

HIMON V 00.0521(1847)
>L
L S19
L @3000
L OK=0579 GO=3000
>G 3000
GO 3000

#GO# ENTRY=3000
RET A=01 X=EF Y=07 P=34 S=FD Nv-BdIzc
>
```

Interpretation: the proof returned before printing its title, so bootstrap
failed before it had a write routine. `A=01` exposed the actual code bug: the
finder had accepted an executable record and returned `A=01`, but each resolver
still had the old `BNE fail` check from the earlier kind `$00` experiment. The
current `$0589` image removes those stale checks.

2026-05-21 hash-resolved board pass, using the corrected `$0589` image:

```text
>L
L S19
L @3000
L OK=0589 GO=3000
>G 3000
GO 3000
HIMON SEARCH PROOF $3000
S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUIT
S> s 0 ffff ff 00
7900 7900: FF 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
D3A9 D3A0: F4 7E 99 FE 00 AD F5 7E | 99 FF 00 AD F6 7E 99 00 | .~.....~.....~..
S IO
S> q
S DONE

#GO# ENTRY=3000
RET A=0A X=82 Y=06 P=F5 S=FD NV-BdIzC
>#
HASH     ENTRY K TEXT
EC7A30F0 C030 03 BOOT_COLD_RESET
5333AEAB C044 03 BOOT_WARM_RESET
3A0CB08E C102 01
260C9112 C115 01
270C92A5 C1CF 01
C10BF213 C27A 01
C80BFD18 C30E 01
D70C14B5 C32D 01
DD0C1E27 C352 01
C20BF3A6 C38C 01
C90BFEAB C3CB 01
D40C0FFC C5C1 01
C70BFB85 C5CE 01
CB0C01D1 C679 01
D00C09B0 CA6E 01
C40BF6CC CC7E 01
A9AF15F7 DB0D 01
20285B85 DEF7 01
379FE930 DF09 01
483BB2DD E03B 01
D55FC6FC E064 01
BEB18931 E0A1 01
43621C9C E0B4 01
F91947F8 E0C0 01
B85E3F10 E0CC 01
ADD714B1 E18D 01
2F6622B9 E212 01
426150D2 E22E 01
30A462F2 E245 01
226EDE8F E3AF 01
7142DD21 E3C7 01
D4C88B87 E3E1 01
B0051A80 C000 03 HIMON V 00.0521(1847)
># S
D60C1322 HSH_NF!
>G 3000
GO 3000
HIMON SEARCH PROOF $3000
S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUIT
S> s 0 ffff 00 ff
0005 0000: 0E 78 FF 00 00 00 FF FF | 05 00 06 00 00 00 FF 02 | .x..............
000D 0000: 0E 78 FF 00 00 00 FF FF | 0D 00 0E 00 00 00 FF 02 | .x..............
7900 7900: 00 FF 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 | ................
S IO
S>
```

Summary:

```text
L/G hash-resolved proof -> S> prompt PASS
S 0 FFFF FF 00 -> hits RAM pattern buffer and ROM helper bytes, then S IO PASS
Q -> S DONE, #GO# return report, HIMON prompt PASS
# -> resident hash records visible, including helper imports PASS
# S -> HSH_NF expected because S is not a resident K=$05 flash record yet
restart at $3000 -> S> prompt PASS
S 0 FFFF 00 FF -> hits RAM state/pattern buffer, then S IO PASS
```

Result:

```text
PASS for the hash-resolved RAM proof areas tested so far. The proof resolves
resident BIO/FTDI and HEX helpers by hash, runs the same search command loop,
and returns cleanly to HIMON. `# S` remains not-found until the later low-flash
K=$05 S command record is created and loaded with L F.
```

First interactive proof shape:

```text
>L G
S> S 3000 36FF 53
S> S 3000 +100 'HIMON'
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
- Mixed hex plus quoted text atoms work.
- Whole-memory no-hit tests are self-polluting because the current pattern is
  stored in `$7900`; use a range that excludes `$7900` when testing no-found.
- Ctrl-C abort reports `S ABORT` and returns to the proof prompt.
- Exact pattern cap boundary is proven: a 64-byte apostrophe string scans and
  a 65-byte apostrophe string routes to usage.

RAM proof checks:

- hex-only pattern: `S 3000 30FF 4D`
- text-only pattern: `S 3000 30FF 'TEXT'`
- mixed hex and text atoms: `S 3000 30FF 4D 'M' 00`
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

After Phase 1A static behavior and Phase 1B hash-resolved behavior are both
boring, build a low-flash command member. This is the "give it a hash, create
an S19 at a nice hole, and L F it" phase.

The `S` command hash is the stable token for the search record:

```text
token: S
hash32 display: $D60C1322
record bytes: 46 4E D6 22 13 0C D6 05 <entry-lo> <entry-hi> <extra-lo> <extra-hi>
meaning: 'F','N',('V'+$80),hash0,hash1,hash2,hash3,kind=$05,DW ENTRY,DW EXTRA
resident entry: provided by the low-flash search member
extra text: high-bit-terminated display text, such as S(earch)
```

Candidate placement:

```text
preferred candidate: $BBA2 if blank on the board
guard before:        $BBA0-$BBA1, expected $FF $FF
calculation:         $C000-$0002-$045C = $BBA2
actual image range:  $BBA2-$BFFD
actual size:         $045C bytes, 1116 decimal
guard after:         $BFFE-$BFFF, expected $FF $FF
next protected ROM:  $C000
record:              $BBA2-$BBAD
entry:               $BBAE
extra:               $BFF6, high-bit text S(earch)
allowed by L F:      yes, if all target bytes are $FF
protected region:    do not target $C000+
artifact:            SRC/BUILD/s19/himon-search-flash-bba2.s19
map:                 SRC/BUILD/map/himon-search-flash-bba2.map
```

The `$E9B0` HIMON-tail idea is scratched for this pass. Keep the flash-shadow
experiment in `$8000-$BFFF` so it stays inside the current conservative `L F`
write policy. The `$BBA2` placement packs the current `$045C` flash command
against the top of low flash while preserving a two-byte `$FF` guard before the
record and a two-byte `$FF` guard before `$C000`.

Use `K=$05` for the flash-shadow command record when `S` should be visible in
hash/catalog displays as more than a raw token without asking for confirmation
on every run. HIMON treats kind bit 0 as executable, legacy exact `$03` as a
confirming pointer record, and exact `$05` as a non-confirming pointer record:

```text
F N V+80 hash0 hash1 hash2 hash3 05
DW SEARCH_ENTRY
DW SEARCH_EXTRA
SEARCH_ENTRY:
    ; command code
SEARCH_EXTRA:
    ; high-bit-terminated text, for example S(earch)
```

The `EXTRA` pointer is display metadata. The called search routine does not
receive it as an argument.

Build:

```text
make -C SRC himon-search-flash
```

First `L F` board script:

```text
>L F
send SRC/BUILD/s19/himon-search-flash-bba2.s19
># S
>S BBA0 BFFF 46 4E D6
>S BBA0 BFFF 'S(earch)'
```

The earlier K=`$03` flash-shadow proof asked for `Y` before every run. K=`$05`
keeps the display metadata while removing that prompt.

`$BBA2` is the current candidate, not a promise. If `$BBA0-$BFFF` is occupied by
CALC, a local language image, an earlier experiment, or anything not all `$FF`,
pick another blank page in `$8000-$BFFF`. Do not erase as part of this step.

Before `L F`:

```text
record current ROM/bin identity
record the exact S19 and map filenames
dump or otherwise confirm $BBA0-$BFFF target bytes are $FF
confirm the S19 contains only the intended low-flash range
confirm the S9 start address is the command entry
keep external recovery available before any live flash write
```

Board proof:

```text
>L F            enter flash S19 load mode
send SRC/BUILD/s19/himon-search-flash-bba2.s19
># S            should resolve S to $BBAE K=05 S(earch)
>S BBA0 BFFF 46 4E D6
>S BBA0 BFFF 'S(earch)'
>N              still steps trapped context
```

Observed K=`$03` flash-shadow proof before the K=`$05` split:

```text
>L F
L F S19
L @BA67
LF OK WR=045C GO=BA73
># S
D60C1322 ENTRY=BA73 K=03  S(earch)
>#
HASH     ENTRY K TEXT
D60C1322 BA73 03 S(earch)
...
>G BA73
GO BA73
S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUIT

#GO# ENTRY=BA73
RET A=0A X=70 Y=32 P=74 S=FD NV-BdIzc
>S B000 C000 'TEXT'
RUN S(earch) @BA73 K=03 ? y
BE87 BE80: 4E 54 20 42 42 7C 27 54 | 45 58 54 27 20 5B 2E 2E | NT BB|'TEXT' [..
```

This proves all three pieces of the flash-shadow command: `L F` wrote the record,
`# S` finds it as K=`$03`, and normal command dispatch preserves the argument
line through the `RUN S(earch) ... ?` confirmation. Direct `G BA73` has no HIMON
command token and therefore correctly prints usage.

The command-entry detail matters: `K=$03` confirmation prints through HIMON's
string writer, which uses `$FE/$FF` as a temporary text pointer. The flash `S`
command copies HIMON's saved command token start from `$FA/$FB`, then advances
past the one-byte `S` token before parsing `addr end|+count ...`.

Observed flash-shadow coverage:

```text
>S B000 FFFF 'FN'
RUN S(earch) @BA73 K=03 ? y
BA67 BA60: FF FF FF FF FF FF FF 46 | 4E D6 22 13 0C D6 03 73 | .......FN."....s
...
E414 E410: A1 E0 8D E1 46 4E D6 80 | 1A 05 B0 03 00 C0 22 E4 | ....FN........".
>S BE70 BEAF 'HELP'
RUN S(earch) @BA73 K=03 ? y
BE96 BE90: 2E 5D 2C 20 3F 20 48 45 | 4C 50 2C 20 51 20 51 55 | .], ? HELP, Q QU
>S BE70 +60 'TEXT'
RUN S(earch) @BA73 K=03 ? y
BE87 BE80: 4E 54 20 42 42 7C 27 54 | 45 58 54 27 20 5B 2E 2E | NT BB|'TEXT' [..
>S BE70 +40 'END' 7C 2B 'COUNT'
RUN S(earch) @BA73 K=03 ? y
BE78*BE70: 53 20 53 54 41 52 54 20 | 45 4E 44 7C 2B 43 4F 55 | S START END|+COU
>S BE70 +60 54 'EXT'
RUN S(earch) @BA73 K=03 ? y
BE87 BE80: 4E 54 20 42 42 7C 27 54 | 45 58 54 27 20 5B 2E 2E | NT BB|'TEXT' [..
>S BE70 +60 'NOTTHERE'
RUN S(earch) @BA73 K=03 ? y
S NF
>S BE70 +60 ''
RUN S(earch) @BA73 K=03 ? y
S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUIT
>S BE70 +0 20
RUN S(earch) @BA73 K=03 ? y
S START END|+COUNT BB|'TEXT' [...], ? HELP, Q QUIT
>S 7EF0 8010 00
RUN S(earch) @BA73 K=03 ? y
7EF0 7EF0: 00 0A 70 32 74 73 BA FD | 74 E1 43 D1 9C D1 EA D1 | ..p2ts..t.C.....
S IO
>S 0 FFFF 'HIMON'
RUN S(earch) @BA73 K=03 ? y
S ABORT
```

Coverage result: catalog, direct entry usage, command dispatch, end-range,
`+count`, mixed text/hex/text atoms, byte-plus-text atoms, no-found, bad syntax,
zero count, I/O-boundary detection, and in-command Ctrl-C abort all passed. The
earlier `BRK 03 PC=C0D1` happened after `S` had already returned to a fresh
HIMON prompt; the later wide `'HIMON'` scan captured the intended `S ABORT`
case.

If `L F` reports protect, erase, write, or verify failure, stop. Do not keep
trying variants over a partly written area until the page has been inspected and
the recovery path is clear.

### Search Proof Comparison

Measured from the current source files and linker maps:

| Build | Source lines | CODE | DATA | Total | Purpose |
| --- | ---: | ---: | ---: | ---: | --- |
| `himon-search-static-proof` | 676 | `$04AF` / 1199 | `$0071` / 113 | `$0520` / 1312 | RAM standalone, statically linked helpers |
| `himon-search-proof` | 913 | `$04FF` / 1279 | `$008A` / 138 | `$0589` / 1417 | RAM standalone, runtime hash-resolved helpers |
| `himon-search-flash` | 752 | `$03FD` / 1021 | `$005F` / 95 | `$045C` / 1116 | Low-flash K=`$05` command record |

Source diff counts:

| Compare | Diff stat | Hunks | Source line delta | CODE delta | DATA delta | Total delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| static proof -> hash proof | +251 / -14 lines | 15 | +237 | +`$0050` / +80 | +`$0019` / +25 | +`$0069` / +105 |
| static proof -> flash command | +219 / -143 lines | 24 | +76 | -`$00B2` / -178 | -`$0012` / -18 | -`$00C4` / -196 |
| flash command -> hash proof | +180 / -19 lines | 20 | +161 | +`$0102` / +258 | +`$002B` / +43 | +`$012D` / +301 |

Assembly complexity counters are simple static counts, not a full cyclomatic
analysis. They are useful here because the files are W65C02S assembly and the
main question is how much machinery each proof carries.

| Build | Nonblank | Code/data lines | Labels | JSR | JMP | Branches | EQU | Data dirs |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| static proof | 618 | 594 | 89 | 73 | 12 | 97 | 23 | 8 |
| hash proof | 841 | 815 | 121 | 88 | 12 | 127 | 47 | 14 |
| flash command | 691 | 664 | 99 | 67 | 10 | 102 | 47 | 12 |

Complexity deltas:

| Compare | Code/data lines | Labels | JSR | JMP | Branches | EQU |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| static proof -> hash proof | +221 | +32 | +15 | 0 | +30 | +24 |
| static proof -> flash command | +70 | +10 | -6 | -2 | +5 | +24 |
| flash command -> hash proof | +151 | +22 | +21 | +2 | +25 | 0 |

The comparison proves the promotion ladder:

```text
static RAM proof
    proves the command behavior with all helper code carried locally

hash-resolved RAM proof
    proves the same behavior while discovering resident helpers by FNV records

flash command
    proves the command can live as a K=$05 FNV record in low flash, be found by
    HIMON's catalog, keep display text, skip confirmation, and run from ROM
```

The flash command is the smallest binary even though its source is larger than
the static proof. That is the useful result: once HIMON owns the shell, command
dispatch, confirmation text, and resident helper table, the command member only
needs the search parser/scanner/printer plus a small import resolver. The board
transcript above proves that this was not just a link-map theory; the same `S`
command made the trip from RAM proof to hash-visible flash resident code.

### What "Lay It Into HIMON" Means

The flash-shadow command is a resident command, but it is still outside the
HIMON image. Laying it into HIMON means replacing the low-flash specimen with a
native HIMON command member:

```text
CMD_SEARCH_FNV
    FNV record for token S, K=$05, DW CMD_SEARCH, DW MSG_SEARCH_EXTRA

CMD_SEARCH
    command entry that starts from CMDP_START, skips the S token, parses args,
    scans memory, prints hits, reports S NF/S IO/S ABORT/usage
```

The body would mostly come from `himon-search-flash.asm`, but not as a blind
paste. The native version should delete the flash import resolver and call HIMON
locals directly: FTDI write/read, Ctrl-C check, CRLF, hex output, and
`UTL_HEX_ASCII_TO_NIBBLE`. Its zero-page names should also be folded into the
HIMON command scratch space instead of remaining app-local `$00-$23` names.

The important command-line rule stays the same. `CMD_SEARCH` should not trust
`$FE/$FF` on entry because display/confirm printing may use that pointer. It
should copy `CMDP_START` from `$FA/$FB`, advance past the `S` token, and parse
the argument tail from there.

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
- Done: remove the resident internal `S` step binding so search can own the
  `S` hash.
- Done: make `CMD_N` own the step path directly instead of jumping through
  the old `S` step entry.
- Update help, usage strings, the operator guide, debug testing docs, and
  generated maps.
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
