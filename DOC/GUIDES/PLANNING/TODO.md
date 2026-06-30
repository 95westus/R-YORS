# R-YORS TODO

## Near Term

- Run the remaining STR8 V0 acceptance/regression pass from
  [STR8_WORK_PROCESS.md](../STR8/STR8_WORK_PROCESS.md): rebuild artifacts, record
  image identity, smoke `?`/`M`/`U` reject/`G`/`R`, then separately rerun the
  remaining lower-sector restore over non-erased bytes and high-flash failure
  behavior checks with a programmer recovery path ready. `B`, `E`, B0 enrolled
  rotation, `U`, visible HIMON U1->U2, fig-Forth payload, OSI BASIC payload,
  and high-flash restores from the backup chain passed on 2026-05-17.
- Keep `MEMORY_MAP.md` and `TECHNICAL_GUIDE.md` aligned with the current STR8
  RAM tray: worker-code tray at `$0200-$09FF`, 4K flash sector mirror at
  `$0A00-$19FF`, RJOIN/debug scratch at `$1A00-$1FE8`, STR8 state at
  `$1FE9-$1FFF`, bank-copy sector buffer at
  `$4000-$4FFF`, and `U` update staging at `$4000-$6FFF`.
- Define `FLSH_` suffix conventions for register-carried arguments, including
  `_A` and `_AX`.
- Treat the current combined ROM protected-window start as `$F000`; revisit
  shrink only after the V0 acceptance pass and size pressure make it useful.
- Keep the first `U` / `UPDATE HIMON` target path boring after the 2026-05-17
  hardware pass: compact S19, `$C000-$EFFF` gate, blank C/D/E staging,
  confirmed erase/write/verify, and no `$F000-$FFFF` update authority.
- Keep the `$C000-$EFFF` payload gate boring. HIMON U1->U2, fig-Forth, and OSI
  BASIC have all passed through STR8 `U`; future payloads should use the same
  compact S19 gate, transcript proof, and backup-promotion warning.
- Define the later STR8 self-update gate: `UPDATE STR8` accepts only
  `$F000-$FFFF`, requires stronger confirmation, and resets after verify.
- Decide when to promote a visibly updated HIMON from candidate to baseline:
  after a good `U`, run `B` only when Bank 2 should become the new recovery
  image.
- Sketch LEAF atomic vector routines only after STR8 V0 acceptance:
  install NMI target, install IRQ target, install BRK target, and leave either
  the old target or new target valid.
- Define STR8 V0's image read-back/check flow, including which bytes ordinary
  restore writes, which selected STR8 protected-window bytes it skips, how STR8
  install/update verifies those bytes separately, and any fixed image marker.
- Define the first catalog record header that can represent hash, kind, bank,
  address, flags, and optional name text.
- Define the first explicit STR8 import labels HIMON will use after the
  simulation stub grows into resident recovery code.
- Revise HIMON command strings and range syntax under the command safety
  mandate: destructive commands require 4+ characters. Candidate bulk commands
  are `COPY start end|+count dest`, `FILL start end|+count bb`, and later
  `MOVE start end|+count dest`; flash/bank mutation stays behind full-word
  confirmed commands.
- Add `D` continuation state: bare `D` repeats the previous dump length from
  the byte after the previous dump, e.g. `D 3000 FF` then `D` displays
  `$3100-$31FF`.
- Define and implement HIMON memory search using the shared range parser:
  target `S addr end|+count b0 [b1 ...]` for hex-byte search,
  `S addr end|+count 'TEXT` for text search, and the simple mixed tail
  `S addr end|+count b0 [b1 ...] 'TEXT`. Treat apostrophe text as a final V0
  tail, not a quoted atom that resumes parsing. Print hits as D-style context
  rows: exact hit address, aligned row address, and `*` when the match crosses
  a 16-byte display row. Current step/next moves to `N` only; do not add
  `NEXT` as an alias.
- Document and design BIO-level FTDI RX lookahead before changing the stable
  input path. A true hardware peek is not available once
  `PIN_FTDI_READ_BYTE_NONBLOCK` reads the FIFO, so any general peek must cache
  bytes at the BIO layer and require all RX consumers to read through BIO.
  Keep `BIO_FTDI_GET_CTRL_C` as a consuming long-scan abort poll for now; do
  not use it as a general non-destructive keyboard peek.
- Keep the `BIO_FTDI_*_BYTE_BLOCK` routines as unbounded blocking APIs unless
  every caller is audited. Bounded waits should use the existing timeout-shaped
  routines or small wrappers with an explicit loop-delay contract, leaving room
  for a timer backend later.
- ASM 2.76 deferred: promote the runtime paste `ASMRP_QUENCH_RX` idea into
  a real shared input-drain contract after the board proof settles. The
  reusable behavior is
  "drain current RX, then keep consuming until the sender has been quiet for an
  explicit idle window." A directly callable routine probably belongs at
  `SYS_QUENCH_RX` or concrete `BIO_FTDI_QUENCH_RX`, because it performs I/O.
  Use a pure `UTL_` name only if the loop is parameterized over caller-supplied
  flush/read-timeout callbacks. First users: ASM paste abort, load abort,
  monitor command parse failure after pasted bursts, and future host-transfer
  recovery.
- Next ASM onboard pass: board-test the host-proven expression-math slice that
  was deliberately not hardware-tested in the commit that added resolved
  `+`/`-` for `EQU`/`ORG`. Load the current ASM image, run the smoke ladder,
  and paste
  [expr-math-7010.a](../ASM/SAMPLES/expr-math-7010.a) using
  [expr-math-7010-test.md](../ASM/SAMPLES/expr-math-7010-test.md). It covers
  known-symbol math, address deltas, `ORG $7000+16`, and a separate
  backward-ORG rejection check. Keep the `|`, `&`, and `^` logical/mask
  expression operators deferred; they are not the next ASM implementation
  slice.
- Add a tiny sorted-list helper for monitor tables such as breakpoint listing.
  `B L` may print slot order for now, but sorted address order will be easier
  to read once multiple breakpoints are active. For the current four breakpoint
  slots, prefer a repeated min-scan printer over a general sort routine.
- Add persistent breakpoint support only after `N`, `@hhhh`, real `BRK xx`, and
  one-shot breakpoint behavior are boring on hardware. Persistent breakpoints
  need a step-over/replant state so HIMON can restore the original opcode,
  execute it once, then replant the `BRK 00` without recursively trapping at
  the same PC.
- Sketch the first W65C02-small `pack_lo_5` decoder and the rule for falling
  back to raw text when compression loses.
- Define the exact `FIX` record bytes for RAM staging and direct flash patching.
- Add a current guide generator only after the hand-maintained map stabilizes.

## Very Possible

- Add `TBE`, The Bit Engine, as a small W65C02S convenience/helper routine
  family for setting, resetting, testing, and branching on bits. Keep RAM
  helpers based on `TSB`/`TRB`/`SMB`/`RMB`/`BBS`/`BBR` separate from flash-safe
  helpers, where clearing `1 -> 0` bits may be the only legal commit action
  without erase.

## Source Follow-Ups

- Re-run routine hash comments after any routine-header reshuffle.
- Check unresolved `XREF` names before using source cross-reference counts as a
  release-quality metric.
- Keep `SRC/HIMON/himon.asm` as the current reference point for
  hash-driven command dispatch.
