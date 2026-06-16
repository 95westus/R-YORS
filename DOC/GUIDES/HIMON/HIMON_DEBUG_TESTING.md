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
L OK=0163 GO=3000
HIMON DEBUG PROOF $3000
BRK $41: USE N TO STEP
BRK 41 PC=...
```

`BRK $41` is the intentional start stop. `BRK $42` is the intentional pass
stop. Any `BRK $E1` through `BRK $E9` means the proof ran down a bad path.

Loader note:

```text
LS03
NMI PC=DAAA or DB0B
```

`LS03` means HIMON left the S19 loader with FTDI status `$03`. If the NMI PC
lands inside `BIO_FTDI_READ_BYTE_BLOCK` in `SRC/BUILD/map/himon-rom-c000.map`, the
monitor was in the blocking serial read path, not running the proof. Restart
`L G` and send the S19 again before treating it as a debug failure.

Do not press Ctrl-C while HIMON is in `L` or `L G`; HIMON sees it as the FTDI
Ctrl-C status and the loader can abort with `LS03`. For capture, use terminal
logging, copy after the prompt returns, or a copy shortcut that does not send
Ctrl-C to the serial session.

## Debug Checks

Use `R` after the first stop to confirm the trapped context is valid.

Use `N` for the normal step command. `S` is no longer a resident step command;
it is reserved for memory search through the FNV command path.

Think of search as a tool behind the prompt, while debug is a HIMON subsystem.
Search will parse a command, scan memory, print hits, and return to the prompt.
Debug has prompt commands too, but it also owns saved trap context, catches
BRK/NMI asynchronously, and can stop or resume user code. That is why debug
behaves like part of the monitor's execution system instead of just another
command.

```text
>R
>N
>N
>N
```

Each successful step should print a
`STEP PC=... OP=... MNEM [operand] LEN=... NEXT=...` line, resume, then trap
again at the planted temporary `BRK`.
Debugger-owned step/breakpoint traps print a compact state line:

```text
@3045 A=01 X=37 Y=1B P=74 S=FB NV-BdIzc
```

The underlying planted byte is still `BRK 00`; HIMON marks it as debugger
state instead of reporting it as a real program `BRK 00`.
For `BRK`, `OP=00` is always the opcode and the following byte is the signature;
debug prints that as `SIG=xx`.

Old-ROM marker: if every step line prints the same mnemonic, especially
`BBR4`, the board is still running a ROM from before the mnemonic-save fix.
Flash the current `SRC/BUILD/bin/himon-str8-rom.bin` and rerun a short step
check.

Old-ROM marker: if every debug trap prints a fresh `HIMON` banner before the
`BRK`/register report, the board is still running the older shared re-entry
path. Current HIMON prints the banner on boot/reset entry, then debug re-entry
goes straight to the stop report and prompt so breakpoint tables are not
forgotten between traps.

## Reading A Debug Transcript

The common line types mean:

```text
STEP PC=hhhh OP=oo ... NEXT=nnnn
  N decoded the instruction at hhhh before running it and planted a temporary
  debugger trap at nnnn.

RESUME hhhh
  HIMON returned to user code at hhhh with RTI.

@hhhh A=.. X=.. Y=.. P=.. S=.. flags
  HIMON stopped at a debugger-owned synthetic trap. This is a temporary step
  trap or a user breakpoint backed by BRK 00. The original opcode has been
  restored before printing. User breakpoints are one-shot in the current build.

BRK xx PC=hhhh
  User code executed a real BRK with signature xx. The PC is the resume address
  after the two-byte BRK instruction, not the BRK opcode address.

NMI PC=hhhh
  HIMON entered through NMI, not BRK.
```

That PC rule matters. In the proof:

```text
304A  BRK $42
304C  BRA $FE
```

So `BRK 42 PC=304C` means `$304A` executed and `$304C` has not run yet. If
`B L` still shows `304C 80`, the breakpoint at `$304C` is pending. Use `X` to
resume into it; `N` from a PC that is already patched by a pending breakpoint is
a sharper edge and should be avoided until the debugger smooths it.

Breakpoint table lines mean:

```text
3007 20
302F A9
3043 A2
```

The first value is the pending breakpoint address. The second value is the
original opcode saved by HIMON. The list is currently slot order, not sorted
address order. `B C hhhh` removes a pending breakpoint; after an `@hhhh`
breakpoint hit, that breakpoint has already been consumed.

Breakpoints are one-shot on purpose in this build. On hit, HIMON restores the
original opcode and clears the slot so `X` can resume from the same PC without
recursively hitting the same `BRK 00`. Persistent breakpoints are future work;
they need a step-over/replant state.

Only set breakpoints on opcode bytes. Avoid operands, BRK signature bytes, data
bytes, and code that is already patched by a pending breakpoint.

## Register Mutation Recommendations

Current HIMON already has a saved trap context with `A`, `X`, `Y`, `P`, `S`,
and `PC`. `R` and `X` currently parse assignments to that context:

```text
R [A=bb X=bb Y=bb P=bb S=bb PC=hhhh]
X [A=bb X=bb Y=bb P=bb S=bb PC=hhhh]
```

Keep `R` as the safe register editor if ROM space allows. It is not strictly
required because stopped contexts are already printed and `X` can mutate before
resuming, but `R` gives the operator a low-risk way to inspect or alter the
saved state without accidentally running user code.

Recommended command shape:

```text
R [A=bb X=bb Y=bb P=bb S=bb PC=hhhh]
X [A=bb X=bb Y=bb P=bb S=bb PC=hhhh]
N [A=bb X=bb Y=bb P=bb S=bb PC=hhhh]
G addr [A=bb X=bb Y=bb P=bb S=bb]
```

`R` should allow all saved-context fields. `X` should allow all fields too,
because it resumes with `RTI` from that context. `N` should allow the same
fields before stepping; mutating `P` is especially useful because branch
single-step resolution depends on the saved flags, and mutating `PC` is useful
for retrying or skipping an instruction. Mutating `S` is sharp but legitimate
for an expert monitor. If `S` remains a step alias in a given build, it should
follow `N` instead of growing a separate syntax.

`G` currently accepts only an address. It starts a fresh execution, so it clears
the saved BRK/NMI marker before transferring to the requested address. That
lets a returning program print fresh `#GO# ... RET` telemetry even if the
operator previously stopped in a trap. Later top-level input aborts can create a
new BRK context, so `R` is not guaranteed to stay empty after the run. Use `X`,
not `G`, to preserve and resume the saved trap context.

If register arguments are added, prefer treating the address argument as the
new `PC` and then resuming through the existing context/`RTI` path instead of
hand-loading registers before a `JMP`. That keeps `A`, `X`, `Y`, `P`, `S`, and
`PC` behavior consistent with `X`. `G PC=hhhh` is unnecessary because `G hhhh`
already names the target address.

Fresh-run policy check:

```text
load a returning RAM proof at $2000
create a top-level abort trap, for example Ctrl-C at an empty HIMON prompt
G 2000 should run the proof and print a fresh #GO# ... RET block
R should not show the old trap; it may show NOCTX or a later top-level BRK 03
```

Board proof on `HIMON V 00.0606(2155)` first repeated the ASM runtime paste
failure path and showed manual `G 2000` returning through `#GO# ... RET`. A
follow-up in the same operator transcript created a live `NMI PC=40D2` context
inside the ASM paste prompt, then `G 2000` still returned through fresh
`#GO# ... RET`. A follow-up `R` printed `BRK 03 PC=C0D1`, which was the
top-level HIMON input abort path in that build, not the earlier NMI context.
Current builds have shifted the same saved-PC report to `BRK 03 PC=C0DB`.

At the HIMON `>` prompt, `Q` is quiesce, not "quit": it executes `SEI`, `WAI`,
then re-enters HIMON when an interrupt wakes the CPU. Use app-local `Q` commands
only inside apps that document them; after an app returns to `>`, run another
monitor command such as `G 2000` or reset/re-enter explicitly.

Keep raw `P=bb` as the exact status-register form. A friendlier future `F=`
syntax can be added as sugar for individual flags, matching the printed flag
style where uppercase means set and lowercase means clear:

```text
N F=Cz      set carry, clear zero
X F=nvBDizc set/clear the listed flags by case
G 3000 F=I  start with interrupt disable set
```

`P=bb` and `F=` should compose by applying assignments in command-line order if
both are supplied.

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
3014 OP=90 BCC $02 -> 3018
3018 OP=38 SEC -> 3019
3019 OP=B0 BCS $02 -> 301D
301D OP=B8 CLV -> 301E
301E OP=50 BVC $02 -> 3022
```

That sequence proves normal one-byte stepping and taken branch target
calculation for `BCC`, `BCS`, and `BVC`.

Full branch bench checkpoint:

```text
3022 OP=A9 LDA #$7F -> 3024
3024 OP=18 CLC -> 3025
3025 OP=69 ADC #$01 -> 3027
3027 OP=70 BVS $02 -> 302B
302B OP=30 BMI $02 -> 302F
302F OP=A9 LDA #$00 -> 3031
3031 OP=F0 BEQ $02 -> 3035
3035 OP=10 BPL $02 -> 3039
3039 OP=A9 LDA #$01 -> 303B
303B OP=D0 BNE $02 -> 303F
303F OP=80 BRA $02 -> 3043
3043 OP=A2 LDX #$37 -> 3045
3045 OP=A0 LDY #$31 -> 3047
3047 OP=20 JSR $304E -> 304A, prints DEBUG PROOF DONE
304A OP=00 BRK $42 SIG=42 -> BRK 42 PC=304C
304C OP=80 BRA $FE -> 304C
```

`BRK $42` is the pass stop. Continuing past it tests debug edge behavior, not
the branch proof itself. The proof parks in a self-`BRA` idle loop after the
pass stop so an extra `N` remains in known code instead of wandering into data
or support routines. Repeated `N` after `BRK $42` should keep reporting
`PC=304C OP=80 BRA $FE NEXT=304C`.

BRK signature policy for this proof:

```text
@hhhh   temporary debugger step/breakpoint stop, backed by BRK 00
BRK 41  intentional start stop
BRK 42  intentional pass stop
BRK E1-E9  bad-path proof failures
```

A future dedicated `BRK xx` handler should classify fixed signatures. Known
proof signatures can say "start", "pass", or "bad path"; unexpected signatures
while stepping are a hint that execution is about to leave code or enter data.

Use the map file when checking exact labels:

```text
SRC/BUILD/map/himon-debug-proof-3000.map
```

Useful manual checks:

```text
>D 3000 30FF     inspect proof bytes
>U 3000 30FF     disassemble proof bytes
>B 3043          set a valid RAM breakpoint on LDX #$37
>B L             list breakpoints
>B C 3043        clear breakpoint
>B 8000          should print DBG RAM
>B 3007          fill breakpoint slot 0
>B 300A          fill breakpoint slot 1
>B 302F          fill breakpoint slot 2
>B 3043          fill breakpoint slot 3
>B 304C          should print BP FULL
>B C 2222        should print BP NF
```

`B L` currently prints active breakpoint slots in table order. A future small
sorted-list helper should print them in address order; for the current four
slots, a repeated min-scan printer is probably cheaper than a general sort.

Breakpoint workflow check:

```text
>L G             load proof and stop at BRK 41 / PC=3013
>B 3043          patch breakpoint
>B L             should list only 3043 A2 after a fresh load
>N               step normally; monitor commands preserve the trapped proof PC
...              continue N until PC=303F
>N               BRA target overlaps B 3043, so N resumes into that breakpoint
```

Expected overlap hit:

```text
STEP PC=303F OP=80 BRA $02 LEN=02 NEXT=3043
 BP
RESUME 303F
@3043 A=01 X=1B Y=1B P=74 S=FB NV-BdIzc
```

`L` clears active debug patches before accepting S-records, so breakpoints do
not survive a program reload as stale table entries.

## Pass Criteria

The pass path is:

```text
L G loads the proof
BRK $41 appears
R shows valid context
N steps through the listed branch cases
no BRK $E1-$E9 appears
BRK $42 appears at the end
B rejects non-UPA patch targets with DBG RAM
B set/list/clear works for a RAM address in $2000-$77FF
B reports BP FULL when all four slots are active
B C reports BP NF when the address is not active
N can resume into a user breakpoint when its step target overlaps one
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
HIMON feature: fold the routine into SRC/HIMON and rebuild ROM.
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
