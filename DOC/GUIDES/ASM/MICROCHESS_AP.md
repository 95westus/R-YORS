# Microchess AP

Status: host-built and board-qualified for onboard assembly, AP-v2 packaging,
RAM execution, gameplay, Bank-1 carrier installation, discovery, and installed
execution. A physical-RESET persistence capture after carrier installation is
still pending.

This is the complete implementation and routine guide for the R-YORS port of
Peter Jennings' Microchess. The application is a fixed-load AP-v2 package: its
BODY runs at `$2000`, exports `MICROCHESS`, uses the HIMON/FTDI console path,
and returns cleanly to its AP caller when the operator presses `Q`.

## Provenance And Copyright

The port starts from Daryl Rictor's serial-terminal edition, corrected by Bill
Forster, hosted by Peter Jennings at
[benlo.com/files/Microchess6502.txt](https://benlo.com/files/Microchess6502.txt).
Jennings' [Microchess history and source page](https://www.benlo.com/microchess/)
identifies the original 1976 code and permits derivative open-source use with
attribution and license text. The Computer History Museum preserves the
[1976 Micro-Ware manual](https://www.computerhistory.org/chess/doc-431614f6d8478/).

The formerly published 6502.org path,
`http://6502.org/source/games/uchess/uchess.htm`, did not resolve during the
2026-09-10 provenance check. The port therefore uses the corrected source from
the author's own site instead of relying on a cached or OCR-uncertain copy.
Jennings' current history page describes original-code derivations as MIT,
while the linked serial source itself carries the three-condition notice below.
This repository conservatively retains the complete terms embedded in the
specific source that was ported.

The complete upstream copyright notice, three redistribution conditions, and
warranty disclaimer are retained at the head of
`SRC/APPS/microchess-2000.asm` and in the distributable sidecar
`SRC/APPS/MICROCHESS-LICENSE.txt`. The visible board banner also says:

```text
MicroChess (c) 1976 Peter Jennings benlo.com - R-YORS AP
```

The source additionally discloses that the R-YORS-specific adaptation was
produced with assistance from OpenAI Codex, an AI coding system, requires
independent review and hardware verification, and does not alter the upstream
copyright or license terms.

Do not remove or abbreviate the source notice when redistributing source. A
binary redistribution must carry the same notice, conditions, and disclaimer
in its accompanying material. Peter Jennings' name may not be used to endorse
the derivative without permission. This section records the upstream terms;
it is not a substitute for reading the notice in the source.

## Build Products

From the repository root:

```text
make -C SRC microchess
```

The target produces:

| Artifact | Purpose |
| --- | --- |
| `SRC/BUILD/s19/microchess-2000.s19` | Direct fixed-load image, entry `$2000` |
| `SRC/BUILD/bin/microchess.ap` | AP-v2 envelope, export `MICROCHESS` |
| `SRC/BUILD/s19/microchess-ap-3000.s19` | AP envelope staged at `$3000` for HIMON `L` |
| `SRC/BUILD/s19/microchess-2000.map` | Exact linked routine addresses |
| `DOC/GUIDES/ASM/SAMPLES/microchess-2000.a` | Complete symbol-lean source for onboard ASM-F2 |
| `SRC/APPS/MICROCHESS-LICENSE.txt` | Notice that must accompany binary redistribution |

Current measured identity:

```text
engine/BODY     $2000-$2565, $0565 bytes (1381)
AP envelope     $05E6 bytes (1510)
BODY FNV-1a-32  $BA97DF23
entry offset    $0000
relocations     3 ABS16 import rows
imports         BIO_FTDI_READ_BYTE_BLOCK, BIO_FTDI_WRITE_BYTE_BLOCK,
                SYS_WRITE_HEX_BYTE
exports         MICROCHESS, executable, offset $0000
```

The three tiny adapters contain `$FFFF` JMP targets in the sealed BODY. HIMON
resolves the typed EXEC imports and patches those words after loading. STR8-N
therefore supplies boot and bank services below this layer, while HIMON owns
the AP's console boundary. `SYS_WRITE_HEX_BYTE` is now published beside its
device-neutral SYS implementation as FNV `$A1722743`, K05 EXEC+TEXT; it retains
the `A/X/Y`-preserved/carry-status contract while delegating to the active console
backend. The package remains far below the one-sector `$1000` carrier ceiling.

The board renderer's `POUT42` exit uses `BRA POUT3`. The upstream serial port
used `BNE` as an unconditional branch after writing a nonzero piece character,
but an imported console service owns N/Z on return; the explicit W65C02 branch
removes that undocumented flag dependency.

## Complete Onboard ASM To AP Run

The `.a` card is fixed at `$2000`. It retains only four global symbols: its
`MICROCHESS` entry and the three imports. Internal
branches, calls, constants, and data addresses are frozen from the checked WDC
map. This avoids ASM-F2's 128-symbol ceiling and still produces the exact same
AP bytes as the host build.

Start at the HIMON prompt with a fresh assembler session:

```text
ASM NEW
```

Send this entire file as text, including its final `END`:

```text
C:\SRC\R-YORS\DOC\GUIDES\ASM\SAMPLES\microchess-2000.a
```

The last source response must be:

```text
ASM OK
SEAL>
```

At `SEAL>` enter these commands exactly:

```text
SEAL
PACKAGE MICROCHESS $3000
.
```

Require the success lines:

```text
SEAL OK
PKG OK @=$3000 L=$05E6
ASM BYE
```

`PACKAGE` leaves the complete envelope at `$3000-$35E5`. Do not use `G 2000`:
the BODY still contains three unresolved import words. Do not load another file
or create another package before running it, because `$3000` is a transient RAM
buffer.

Back at HIMON, load/link the BODY at its required fixed address and call its
entry:

```text
AP $3000 $2000
```

HIMON validates S/R/E/I/B sections and BODY FNV, resolves the two BIO imports
and the SYS hex import, patches their three `$FFFF` operands, and calls
`MICROCHESS`. At the chess `?`
prompts, a complete smoke exchange is:

```text
C
P
6
2
4
2
<Return>
P
Q
```

`C` initializes the board, the first `P` plays the canned `$13->$33` move,
`6242` plus Return applies the human move, and the second `P` performs a real
off-book search. `Q` must return to HIMON with a line showing `A=AC` and carry
set. Retain that terminal transcript for physical-board acceptance.

## Write MicroChess To A Flash Carrier

MicroChess fits in one AP carrier sector. This is an optional destructive step:
`INSTALL` programs one previously erased, unreserved 4K sector in Bank 0, 1,
or 2. Keep Bank 3 for the active system image, inspect the target bank first,
and retain a recovery image before writing.

After the source has assembled and while still at `SEAL>`, build the RAM
envelope and ask APMAN to install it in the first suitable Bank 1 sector:

```text
SEAL> SEAL
SEAL OK
SEAL> PACKAGE MICROCHESS $3000
PKG OK @=$3000 L=$05E6
SEAL> INSTALL 3000 B1
INST B1 hhhh L=05E6
SEAL> .
ASM BYE
>
```

Here `hhhh` represents the actual sector base printed by the board, such as
`C000`; do not assume that example address is free. The bank token is the
destructive confirmation. APMAN validates the AP-v2 envelope, rejects a
duplicate `MICROCHESS` identity in that bank, skips reserved/work sectors,
selects a completely erased sector, writes and verifies the entire carrier,
and restores Bank 3 before returning.

Confirm discovery and execute the flash copy by its AP entry name:

```text
>APS B1 MICROCHESS
APS B1 hhhh APC MICROCHESS L=05E6 @2000
>AP B1 MICROCHESS
GO 2000
```

At `?`, enter `C` before playing and `Q` to return to HIMON. `AP L B1
MICROCHESS` is the load-and-link-only form. After a physical reset, repeat
`APS B1 MICROCHESS` and `AP B1 MICROCHESS` to prove persistence. If Bank 1 has
no suitable erased carrier sector, inspect `APS B0` or `APS B2` and deliberately
choose one of those banks; do not erase or overwrite a reported carrier merely
to force the example address.

## Run Through HIMON

Use the current HIMON ROM built with `SYS_WRITE_HEX_BYTE_FNV`. An older HIMON
without that resident record will reject this three-import package with
`BAD FIX` rather than entering MicroChess.

At a bare HIMON `>` prompt, enter `L`, then send
`SRC/BUILD/s19/microchess-ap-3000.s19`. When HIMON reports the `$3000` load,
run the fixed-load package with:

```text
AP $3000 $2000
```

Do not request another BODY destination. Its three relocation rows patch only
the HIMON import operands; the engine's absolute code/data references remain
linked for `$2000`.
Press `Q` at the Microchess prompt to return with `A=$AC` and carry set.

The direct `microchess-2000.s19` intentionally leaves the two import operands
at `$FFFF`; it is a build/debug artifact, not a standalone image. Use the AP
envelope so HIMON can resolve and patch the console calls before execution.

## Operator Controls

Microchess prints the board, the three legacy display bytes, and `?` before
each key. Commands are case-insensitive in this port.

| Input | Effect |
| --- | --- |
| `C` | Clear/reset to the standard initial position and reset the opening-book index. Do this first. |
| `E` | Exchange sides by rotating the board 180 degrees and swapping the two 16-piece arrays. |
| `P` | Ask Microchess to play. It uses the opening table when the prior move matches, otherwise it searches. |
| `0`-`7` | Enter one square digit. Enter four digits as `from-rank`, `from-file`, `to-rank`, `to-file`. |
| Return | Commit the four-digit human move. |
| `Q` | Restore the saved caller stack and return to HIMON. |

Squares are one byte with rank in the high nibble and file in the low nibble.
Thus `6343` moves the piece on `$63` to `$43`. If the computer plays first
after `C`, the opening table produces `$13->$33`.

The human-input path trusts the operator: it locates the piece on the entered
from-square and applies the move. It does not run that move through the
computer's legality generator. The original compact engine has no separate
castling, en-passant, promotion, repetition, fifty-move, or draw-claim
machinery. Checkmate and stalemate both reach the legacy `MATE` result.

## Runtime Memory Contract

The KIM-1 source stored its board and most state in zero page and reset the
hardware stack to `$FF`. The zero-page layout is preserved because its indexed
wraparound is semantic; the hardware-stack reset is adapted for a returning AP.

| Range | Owner while Microchess runs | Contents |
| --- | --- | --- |
| `$0050-$005F` | Microchess | first side's 16 piece locations (`BOARD`) |
| `$0060-$006F` | Microchess | other side's 16 piece locations (`BK`) |
| `$00B0-$00FC` | Microchess | move state, counters, evaluation, display bytes |
| `$1B00` | Microchess | AP caller's entry stack pointer |
| `$0100-$01FF` | Microchess plus caller | caller return stack and alternate move/unmove stack |
| `$2000-$258C` | loaded AP BODY | engine, UI, tables, and two import adapters |

`MOVE` and `UMOVE` still implement Jennings' two-stack design. `SP1` remembers
the active call stack; `SP2` tracks the alternate move-record stack. The AP
entry saves the incoming stack pointer instead of setting SP to `$FF`. On each
`CHESS` cycle, SP returns to that saved value and SP2 is reset `$37` bytes
below it, preserving the original `$FF/$C8` separation while retaining the AP
return frame. This also discards the deliberately abandoned `JSR GO` frame and
old permanent-move record. `DONE` restores the caller pointer before `RTS`
consumes its return address.

The zero-page locations are not merely a size choice. Negative `STATE` values
index `BCAP0,X` and intentionally wrap modulo 256 into earlier counters. An
absolute relocation would turn that into 16-bit indexing and corrupt the
position during an off-book search. The AP therefore owns these original
zero-page ranges while running.

## Core Representation

Microchess stores pieces, not squares. `BOARD[0..15]` and `BK[0..15]` each
hold the square occupied by one piece; `$CC` means captured. Within a side the
indices are king, queen, two rooks, two bishops, two knights, then eight
pawns. `REVERSE` makes one generator serve both colors by exchanging arrays
and replacing every square `s` with `$77-s`.

Square arithmetic is deliberately cheap. `MOVEX` holds signed byte deltas for
king, queen, rook, bishop, knight, and pawn directions. After adding a delta,
`CMOVE` tests `(square & $88)`: either bit set means that a nibble left the
`0..7` board. Occupancy is found by scanning the 32 piece locations.

`CMOVE` returns three independent facts in processor flags:

| Flag | Meaning on return |
| --- | --- |
| N | Set for an off-board move or a destination occupied by the moving side. |
| V | Set when the move captures the opposing side; clear for an empty destination. |
| C | Set when check testing finds that the move leaves the mover's king capturable. |

## Complete Routine Map

Addresses below are from the current host-qualified map. Internal loop labels
are listed with their owning routine so the entire control flow is accounted
for without pretending every branch target is a callable subroutine.

### Entry, Commands, And Human Moves

| Address | Routine/labels | Contract |
| --- | --- | --- |
| `$2000` | `MICROCHESS` | Save caller SP, clear reverse mode, then enter `CHESS`. |
| `$2008` | `CHESS`, `OUT` | Reset both stack domains without losing the AP return frame, render with `POUT`, read one normalized key with `KIN`, and dispatch it. `WHSET`, `NOSET`, `NOREV`, `CLDSP`, `NOGO`, and `NOMV` are command branches. |
| `$2061` | `DONE` | Restore `CALLER_SP`; return `A=$AC`, C=1. |
| `$20FF` | `INPUT` | Reject values above 7; fold a square digit through `DISMV`; on display completion locate the piece occupying `DIS2`. `DISP`, `SEARCH`, `HERE`, and `ERROR` are its branch points. |
| `$230B` | `DISMV` | Shift one input nibble into the legacy from/to display pair; copy the newest destination into `SQUARE`. |

### Search Director And Counters

| Address | Routine/labels | Contract |
| --- | --- | --- |
| `$2069` | `JANUS` | State-machine dispatcher called after every generated move. It chooses counting, deeper capture-tree work, reply generation, or final evaluation. |
| `$206D` | `COUNTS` | Increment mobility, capture-value, and best-captured-piece counters selected by `STATE`. `OVER`, `NOQ`, `ELOOP`, `FOUN`, `LESS`, and `NOCAP` are internal paths. |
| `$20A8` | `ON4` | At state 4, make the trial move, reverse, generate the immediate reply, reverse back, generate continuation moves at state 8, unmake, and evaluate. |
| `$20C9` | `NOCOUNT` | At state `$F9`, detect whether reply generation can capture the king and clear `INCHEK`. |
| `$20D8` | `TREE` | For capture-search states, value the captured piece, retain the best capture at that ply, decrement `STATE`, and recurse through `GENRM` until turnaround state `$FB`. |

The counter block deliberately aliases storage. `MOB`, `MAXC`, `CC`, and
`PCAP` are base addresses indexed by `STATE`; names such as `BMOB`, `WMOB`,
and `PMOB` are readable aliases for particular indexed positions. Moving one
name independently would break evaluation.

### Move Generation And Legality

| Address | Routine/labels | Contract |
| --- | --- | --- |
| `$2118` | `GNMZ`, `GNMX` | Clear the 17-byte counter window (`COUNT..COUNT+$10`), then fall into `GNM`. |
| `$2121` | `GNM` | Iterate piece indices 15 down to 0 and dispatch by type. `NEWP` and `NEX` select the next piece. |
| `$2145` | `KING` | Generate eight one-step moves through `SNGMV`. |
| `$214C` | `QUEEN` | Generate eight sliding directions through `LINE`. |
| `$2153` | `ROOK`, `AGNR` | Generate the four orthogonal sliding directions. |
| `$215E` | `BISHOP` | Generate the four diagonal sliding directions. |
| `$2169` | `KNIGHT`, `AGNN` | Generate eight knight jumps through `SNGMV`. |
| `$2178` | `PAWN`, `P1`, `P2`, `P3` | Try two capture diagonals, then one or two forward squares. The double step is allowed from the encoded starting rank. |
| `$21A6` | `SNGMV` | Call `CMOVE`, call `JANUS` if nonnegative/legal, reset the source square, and advance direction. |
| `$21B4` | `LINE` | Repeatedly call `CMOVE` along one ray. Stop at board edge, own piece, check failure, or after a capture; otherwise evaluate and continue. |
| `$21E2` | `CMOVE` | Add the selected `MOVEX` delta, perform edge and occupancy tests, optionally invoke `CHKCHK`, and return the N/V/C flag contract. `LOOP`, `NO`, `SPX`, `RETL`, and `ILLEGAL` are internal exits. |
| `$220E` | `CHKCHK` | Save flags/state, make and reverse the trial move, set state `$F9`, generate every opposing reply, unmake, then report whether the king was capturable. |
| `$2237` | `RESET` | Reload `SQUARE` from the current piece's stored location. |

### Position Mutation And Two-Stack Undo

| Address | Routine/labels | Contract |
| --- | --- | --- |
| `$21CA` | `REVERSE`, `ETC` | For all 16 entries, exchange the two sides and rotate both locations with `$77-square`. |
| `$223E` | `GENRM`, `GENR2`, `RUM` | Make a trial move, reverse, generate replies, reverse back; shared spine for capture-tree and check testing. |
| `$224A` | `UMOVE` | Switch to the alternate stack, pop `MOVEN`, captured piece, source square, moving piece, and destination, restore both piece entries, then switch back. |
| `$2264` | `MOVE`, `CHECK`, `TAKE`, `STRV` | Switch stacks; push destination, captured-piece index, original source, mover index, and direction; mark a capture `$CC`; write the mover's destination; switch back. |

The move record order is exactly the reverse of `UMOVE`'s pop order. Capturing
an empty square records X=`$FF`; indexed storage wraps to the byte immediately
before `BOARD`, matching the original compact technique. That transient byte
is not interpreted as a live piece entry.

### Evaluation And Move Choice

| Address | Routine/labels | Contract |
| --- | --- | --- |
| `$2290` | `CKMATE` | Reject a line where the opponent can take this side's king; award `$FF` when the opponent has no mobility and its king remains attacked. |
| `$22A5` | `RETV` | Restore search state 4 and fall into `PUSH`. |
| `$22A9` | `PUSH` | Replace `BESTV/BESTP/BESTM` only on a strictly greater score. Equal scores retain the earlier move. |
| `$22B9` | `RETP` | Print one dot as a thinking-progress indication, then return through the character adapter. |
| `$22BE` | `GO` | Match `DIS3` against the reverse-walked `OPNING` table or disable the book. Outside the book, collect state `$0C` and state 4 statistics, then play the best move. `END`, `NOOPEN`, and `MV2` are internal paths. |
| `$2308` | `MATE` | Return `$FF` when no move reaches the minimum score; the legacy UI treats resignation and stalemate alike. |
| `$231B` | `STRATGY` | Combine mobility, maximum captures, capture counts, exchange terms, and positional bonuses into an unsigned score, then continue through `CKMATE`. |

`STRATGY` applies the original three weight bands: quarter-weight terms are
summed before the first shift, half-weight terms before the second shift, and
full-weight capture/exchange terms afterward. It clamps the first underflow to
zero and adds a small bonus for central squares `$33/$34/$22/$25` or for moving
a non-king piece out of its back rank.

### Terminal UI And Adapters

| Address | Routine/labels | Contract |
| --- | --- | --- |
| `$2381` | `POUT` | Print CR/LF, copyright banner, files, eight board rows, piece symbols/square shading, and the three legacy display bytes. `POUT1..POUT4` own row/cell scanning. |
| `$23F2` | `POUT5`, `POUT6` | Preserve X and print a 25-character horizontal border plus CR/LF. |
| `$2404` | `POUT8` | Print the bottom file labels and `DIS1 DIS2 DIS3` as hex. |
| `$2420` | `POUT9` | Print CR/LF. |
| `$242B` | `POUT10`, `POUT11` | Print file labels `00` through `07`. |
| `$243D` | `POUT12` | Print the row nibble derived from Y. |
| `$2444` | `POUT13`, `POUT14`, `POUT15` | Print the NUL-terminated copyright banner. |
| `$2452` | `KIN` | Print `?`, block for one byte, strip bit 7, turn ASCII `0..7` into binary nibbles, and uppercase `a..z`. |
| `$2473` | `syskin` | Jump through the AP import patched to `BIO_FTDI_READ_BYTE_BLOCK`. |
| `$2476` | `syschout` | Jump through the AP import patched to `BIO_FTDI_WRITE_BYTE_BLOCK`. |
| `$2479` | `syshexout` | Jump through the AP import patched to the published, A/X/Y-preserving `SYS_WRITE_HEX_BYTE`. |

The exact addresses can shift when the adapter changes. The symbol map, not
this narrative snapshot, is the final address authority.

### Constant Tables

| Current start | Table | Meaning |
| --- | --- | --- |
| `$247C` | `banner` | Visible attribution banner. |
| `$24B7` | `cpl` | Color letters used by normal/reversed display. |
| `$24E7` | `cph` | Piece-type letters `KQRRBBNNPPPPPPPP` for both sides. |
| `$2508` | `SETW` | Standard 32-piece starting locations. |
| `$2528` | `MOVEX` | Zero plus 16 signed direction deltas. |
| `$2539` | `POINTS` | King/queen/rook/bishop/knight/pawn capture values by piece index. |
| `$2549` | `OPNING` | Reverse-walked canned opening reply triples, terminated by `$CC`. |

## Host Acceptance

`make -C SRC microchess` performs both structural and behavioral checks:

- retained copyright, redistribution terms, and non-endorsement clause;
- no direct `$7F70-$7F73` 6551 access;
- no KIM-only `LDX #$FF` stack reset;
- exact wrap-sensitive zero-page bases and aliases;
- exact fixed entry, SREIB section order, three typed imports, three matching
  ABS16 import relocations, BODY length, and one-sector envelope fit;
- assembly of all 659 `.a` lines by the real ASM-F2 image under py65, followed
  by `SEAL` and named `PACKAGE`, with byte-exact comparison to the host AP;
- py65 execution of lowercase `c`, an opening `p`, human `$62->$42`, an
  off-book searched reply, repeated board rendering, and `q` return-stack
  restore.

The 2026-09-10 COM4 transcript proves RAM-envelope load, `AP $3000 $2000`, `C`,
one human/computer exchange, `Q`, the `RET A=AC ... C set` line, installation
at `B1:9000`, named discovery, and installed execution. The remaining board
gate is a physical reset followed by named discovery and execution of the
same carrier.

## Refreshing From Upstream

The checked importer records the mechanical and semantic adaptation:

```text
powershell -NoProfile -ExecutionPolicy Bypass \
  -File SRC/tools/port_microchess.ps1 \
  -UpstreamPath SRC/BUILD/tmp/Microchess6502.upstream.txt \
  -OutPath SRC/APPS/microchess-2000.asm
```

It refuses input without the expected Jennings copyright line and Forster OCR
correction marker. After any refresh, inspect the source diff, rebuild, rerun
the host smoke, and repeat the board card. Do not update the measured identity
or mark the feature accepted until all of those agree.
