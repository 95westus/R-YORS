# HIMON Debug Testing

This is the bench process for testing HIMON debug work from a fresh ROM image
with a RAM-loaded proof program.

## Build The Bench Artifacts

```text
make -C SRC himon-str8-rom-bin
make -C SRC himon-debug-proof
```

Outputs:

```text
SRC/BUILD/bin/himon-str8-rom.bin
SRC/BUILD/s19/himon-debug-proof-3000.s19
SRC/BUILD/map/himon-debug-proof-3000.map
SRC/BUILD/sym/himon-debug-proof-3000.sym
```

`himon-str8-rom.bin` is the 32K `$8000-$FFFF` ROM-bank image. The debug proof
S19 is linked for RAM at `$3000` and is meant to be loaded under HIMON.

## Flash The Current ROM

Before flashing, keep a known-good image and programmer recovery path ready.

```text
flash SRC/BUILD/bin/himon-str8-rom.bin as the live ROM image
reset the board
let STR8 enter HIMON, or press S and use G from STR8
confirm the HIMON prompt appears
```

Do not start destructive STR8 tests during this pass. This pass is about HIMON
debug behavior only.

## Load The RAM Proof

At the HIMON prompt:

```text
>L G
```

Send:

```text
SRC/BUILD/s19/himon-debug-proof-3000.s19
```

Expected first stop:

```text
HIMON DEBUG PROOF $3000
BRK $41: USE N OR S TO STEP
BRK 41 PC=...
```

`BRK $41` is the intentional start stop. `BRK $42` is the intentional pass
stop. Any `BRK $E1` through `BRK $E9` means the proof ran down a bad path.

Loader note:

```text
LS03
NMI PC=DAAA
```

`LS03` means HIMON left the S19 loader with FTDI status `$03`. In the current
map, `$DAAA` is `BIO_FTDI_READ_BYTE_BLOCK`, so an NMI there means the monitor
was in the blocking serial read path, not running the proof. Restart `L G` and
send the S19 again before treating it as a debug failure.

Do not press Ctrl-C while HIMON is in `L` or `L G`; HIMON sees it as the FTDI
Ctrl-C status and the loader can abort with `LS03`. For capture, use terminal
logging, copy after the prompt returns, or a copy shortcut that does not send
Ctrl-C to the serial session.

## Debug Checks

Use `R` after the first stop to confirm the trapped context is valid.

Use `N` for the normal step command. `S` currently calls the same step body,
but `S` is being freed for search.

```text
>R
>N
>N
>N
```

Each successful step should print a `STEP PC=... OP=... MNEM LEN=... NEXT=...`
line, resume, then trap again at the planted temporary `BRK`.
Temporary step traps usually report `BRK 00`; that is the planted debugger
byte, not a bad-path proof code.

The proof walks these branch cases:

```text
BCC taken
BCS taken
BVC taken
BVS taken
BMI taken
BEQ taken
BPL taken
BNE taken
BRA taken
```

First bench checkpoint:

```text
3013 OP=18 CLC -> 3014
3014 OP=90 BCC -> 3018
3018 OP=38 SEC -> 3019
3019 OP=B0 BCS -> 301D
301D OP=B8 CLV -> 301E
301E OP=50 BVC -> 3022
```

That sequence proves normal one-byte stepping and taken branch target
calculation for `BCC`, `BCS`, and `BVC`.

Use the map file when checking exact labels:

```text
SRC/BUILD/map/himon-debug-proof-3000.map
```

Useful manual checks:

```text
>D 3000 30FF     inspect proof bytes
>U 3000 30FF     disassemble proof bytes
>B 3000          set a valid RAM breakpoint
>B L             list breakpoints
>B C 3000        clear breakpoint
>B 8000          should print DBG RAM
```

## Pass Criteria

The pass path is:

```text
L G loads the proof
BRK $41 appears
R shows valid context
N/S steps through the listed branch cases
no BRK $E1-$E9 appears
BRK $42 appears at the end
B rejects non-UPA patch targets with DBG RAM
B set/list/clear works for a RAM address in $2000-$77FF
```

Record the tested files:

```text
ROM:   SRC/BUILD/bin/himon-str8-rom.bin
S19:   SRC/BUILD/s19/himon-debug-proof-3000.s19
MAP:   SRC/BUILD/map/himon-debug-proof-3000.map
date:  yyyy-mm-dd
notes: pass/fail and any BRK code seen
```

## Promotion Rule

Keep new debug/search work as a RAM S19 proof until it behaves cleanly under
HIMON. After that:

```text
HIMON feature: fold the routine into SRC/TEST/apps/himon and rebuild ROM.
flash member: link at the intended ROM address and add a verified image builder.
```

S19 is the proof/load format. A `.bin` is a placed raw image, not just a
converted S19. The current main `.bin` path is:

```text
make -C SRC himon-str8-rom-bin
```

For a new ROM member, add an explicit script or Makefile rule that places bytes
at the correct `$8000-$FFFF` bank offset and verifies the result before it is
called burnable.
