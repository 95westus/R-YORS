# STR8 J0-J2 Opaque-Bank Implementation Plan

This is the implementation and hardware-proof plan for non-destructive STR8
`J0`, `J1`, and `J2` handoff. It supersedes the earlier assumption that every
bootable bank must reserve `$F000-$FFFF` for a STR8-compatible top sector.

```text
status:     J0-J2 V1 and visible command echo fully hardware-accepted
provenance: ORIG-WLP2, COLLAB-AI
evidence:   DERIVED-SRC for current addresses, worker shape, and size baseline
```

The current source, build maps, and hardware transcripts remain the authority
for implemented behavior. Bare `0`, `1`, and `2` remain destructive Bank 3
restore commands.

The 2026-07-28 host candidate now contains the `J0`-`J2` parser, RAM-proof
handoff, resident RAM-worker handoff, VIA-PCR bank decoder, shared handoff
state, and build-time size/state assertions. Both STR8 and the combined ROM
build successfully. The read-only inventory and direct `$3000` RAM handoffs
have passed on hardware for Banks 0-2, including physical-reset recovery to
Bank 3 after every handoff. Bank 1/2 identity differentiation also passed:
Bank 2 has the ASM-F2 low face and Bank 1 is erased at `$8000-$800F`. A later
explicit full `B2->B3` restore changed Bank 3 from CRC `$4F80`/HIMON `2121` to
CRC `$04EF`/HIMON `2113`; the operator then repeated the proven `U` update and
restored the intended `$4F80`/HIMON `2121` state. Clean inventories before and
after new direct-RAM handoffs matched byte for byte. Phase A and direct-RAM
Phase B are accepted. The resident candidate is now installed. Resident worker
mode `$08` passes all `J0`/`J1`/`J2` target entries and physical-reset
recoveries. The corrected Bank-3-started inventory and direct faces pass with
pre-echo CRCs `$4B59/$2A3D/$04EF/$E4DB`. A six-byte resident-only command echo
fix passed its `$0B52` RAM `J2` preflight and is now installed through a
complete TopWriter `S`/`V`/confirmed-`P` exchange. Bank 3 cold-boots afterward.
The installed echo image's direct faces pass. Resident `J0`, `J1`, and `J2`
are visible at the prompt, enter the intended target systems, and reset-recover
to Bank 3. Corrected Bank-3-started inventories before and after the handoffs
match at `$4B59/$2A3D/$04EF/$4663`. This completes V1 mechanism acceptance on
the recorded R-YORS images; Bank-3-owned identity and CRC metadata remains a
future requirement.

The exact first-board command rail is
[STR8_J012_BOARD_TEST.md](../STR8/STR8_J012_BOARD_TEST.md).

Post-V1 note: the host-built reset-selector follow-up adds boot-time
`0`/`1`/`2` choices that reuse the accepted `J0`-`J2` worker after an
additional three-second pause. It also accepts `3` to warm-start HIMON while
preserving RAM and `S` for STR8 after a 16-dot attach delay and RX flush. It
does not change prompt `J0`-`J2` or bare restore commands. Its separate pending
proof rail is
[STR8_BOOT_SELECTOR_BOARD_TEST.md](../STR8/STR8_BOOT_SELECTOR_BOARD_TEST.md).
The frozen V1 record below remains the authority for the original `J` proof.

## Frozen Machine Model

Bank 3 is the boot supervisor and physical-reset recovery root. Banks 0-2 are
opaque 32K systems:

```text
physical RESET
    |
    v
Bank 3 STR8 selector -- timeout --> Bank 3 default payload
    |
    +-- J0 --> Bank 0 reset vector
    +-- J1 --> Bank 1 reset vector
    `-- J2 --> Bank 2 reset vector
```

The following rules are frozen for the first implementation:

- Physical reset selects Bank 3 through the board pull-ups.
- Bank 3 retains STR8 at `$F000-$FFFF`. This is what makes the selector,
  timeout, and recovery path possible.
- Timeout stays in Bank 3 and launches the Bank 3 default payload. It does not
  silently select Bank 0, 1, or 2.
- Each Bank 0-2 target owns its complete `$8000-$FFFF` image. `$F000-$FFFF`
  may contain STR8, WOZMON, another monitor, an OS, language code, data, or
  anything else required by that system.
- STR8 does not require a Boot Passport Block, STR8 signature, shared service
  entries, shared interrupt stubs, or any other reserved target-bank bytes.
- `J0`-`J2` are non-destructive. They do not erase or program flash.
- After a successful handoff, Bank 3 STR8 is unmapped. It cannot enforce a
  timeout, validate later behavior, service interrupts, or recover control.
- Physical reset is the universal return path. A guest may provide its own
  bank-switch command, but STR8 does not require guest cooperation.

If Bank 3 `$F000-$FFFF` is replaced by WOZMON or another unrelated top sector,
this STR8 selector no longer exists. Supporting that arrangement would require
a different reset supervisor or external hardware and is outside this plan.

## Bank Roles Are Configuration, Not ABI

The current and possible future roles are inventory facts, not meanings built
into `J`:

| Bank | 2026-07-28 operator-reported live use | Example future use | `J` interpretation |
| --- | --- | --- | --- |
| 0 | R-YORS without ASM | R-YORS, a preserved image, or data | Try Bank 0's reset vector |
| 1 | different R-YORS build without ASM | OSI BASIC | Try Bank 1's reset vector |
| 2 | R-YORS with ASM | fig-FORTH | Try Bank 2's reset vector |
| 3 | R-YORS with ASM and the newest/timestamped STR8 | R-YORS with STR8 | Reset/default supervisor; no `J3` in this phase |

`J1` never means OSI BASIC, and `J2` never means FORTH. Those labels belong in
an external inventory or in the selected system's own banner. Reprogramming a
bank changes its system without changing the `J` implementation.

Before any hardware write, record the actual current identity and CRC of every
bank. Do not treat the table above as proof of what is on a particular board.

## Scope

The first delivery includes:

1. `J0`, `J1`, and `J2` parsing in Bank 3 STR8.
2. A read-only bootability gate based on the target reset vector.
3. A final bank-select/reset-vector handoff executed entirely from RAM.
4. A documented current-bank decoder for software that wants to report its
   physical bank.
5. Host/build gates and staged hardware proof.
6. Updated operator, technical, decision, and planning documentation.

It does not include:

- `J3`;
- automatic timeout boot of Bank 0-2;
- a persistent boot preference;
- a target-resident BPB or shared STR8 ABI;
- whole-bank CRC authentication without external metadata;
- programming OSI BASIC, FORTH, WOZMON, or any other new image;
- a guest-independent way to regain control without physical reset;
- changes to destructive `B`, `0`, `1`, `2`, `U`, or high-restore policy.

## Command Contract

### Accepted input

The first parser accepts both compact and spaced forms:

```text
J0
J1
J2
J 0
J 1
J 2
```

Lowercase `j` is accepted because current dispatch folds command letters to
uppercase. Spaces between `J` and the bank digit are ignored. CR/LF before the
digit are ignored by the existing input helper. Any other character or a digit
outside `0`-`2` fails without selecting another bank.

Bare `0`, `1`, and `2` keep their current destructive restore meaning. This
separation is intentional:

```text
2     restore Bank 3 from Bank 2 after confirmation
J2    execute Bank 2 without writing flash
```

STR8 is a streaming, single-character console rather than a line parser.
After `J`, it waits for the next non-space/non-CR/LF byte and acts immediately.
There is no "missing digit" result until another byte arrives. Flush queued RX
after accepting the digit so accidental trailing input is not delivered to the
guest. `J3`, `J-1`, and `J?` fail on their first non-space operand. `J20`
therefore means `J2` followed by trailing input that is flushed; it is not a
line that can be rejected as a whole.

### Operator output

The original installed candidate consumes the two command bytes without
echoing them, then prints the selected bank. The host follow-up must display
the recognized `J` and each consumed operand byte at the prompt:

```text
STR8-N>J2
J B2
```

This is byte echo, not line editing. The folded command letter appears as
uppercase `J`; spaces in `J 2` appear as entered. CR/LF skipped by
`STR8_READ_COMMAND` are not echoed.

Before selecting a target, STR8 must also print the `J Bn` state line so a
silent guest can be diagnosed.

The bank must be visible before the irreversible handoff. The vector cannot be
printed by resident STR8 after target selection because resident ROM is then
unmapped. On refusal, the RAM worker saves the vector, restores Bank 3, and
returns so resident STR8 can print:

```text
JERR B0 V=$FFFF
```

The success path prints no `OK` after selection because the code that owns the
console may have disappeared. The target system owns all output after the
jump.

## What "Bootable" Means In V1

V1 performs a plausibility gate, not identity or integrity authentication.

After selecting the target from RAM, read `$FFFC-$FFFD` and accept the vector
only when:

```text
$8000 <= reset vector <= $FFFF
reset vector != $FFFF
```

The lower bound keeps the first contract to a self-contained flash image and
rejects `$0000`, erased/empty low values, RAM entry points, and I/O addresses.
`$FFFF` is rejected as the common erased vector. `$FF00` must remain valid
because it is a normal WOZMON-style entry.

Do not require the target NMI or IRQ vectors to pass the same gate. The guest
owns those vectors, may deliberately share stubs, and starts with IRQ disabled.
NMI remains a board-level risk during the few handoff instructions.

This gate can reject obvious data banks and erased images. It cannot prove
that:

- the bank contains the expected R-YORS, BASIC, or FORTH build;
- all bytes required by the system are intact;
- a random data image with a plausible final vector is safe;
- the reset routine will initialize the board correctly.

Stronger validation therefore needs Bank 3 metadata external to the opaque
target. This is a future requirement, not an optional refinement. Before
unattended launch, timed alternate-bank boot, or managed mixed-system
operation is promoted, Bank 3 must own a validation manifest containing at
least the bank number, expected full-image CRC, expected reset vector, image
role/type, human-readable build tag or timestamp, and enabled/committed state.
The manifest may add a format/profile version, but it may not consume fixed
bytes inside Banks 0-2. Manifest placement, CRC algorithm, and update authority
are deferred until the manual RAM handoff is proven.

For initial hardware work, only jump to a bank whose full image has just been
read back and whose expected CRC and vector are recorded in the transcript.

## Knowing The Current Bank

The flash bank is a hardware selection, not an image identity. CA2 and CB2 in
the FTDI VIA PCR at `$7FEC` drive the two flash address-select inputs. Existing
code uses:

| Bank | Explicit PCR bank-control pattern |
| ---: | ---: |
| 0 | `$CC` |
| 1 | `$CE` |
| 2 | `$EC` |
| 3 | `$EE` |

Add a narrow `FLSH_BANK_GET_A` routine beside `FLSH_BANK_SELECT_A`. Its
contract should be:

```text
IN:     none
OUT:    A = bank 0-3 and C=1 when the PCR mode is recognized
        A = raw masked PCR state and C=0 when it is not recognized
CLOBBER: X as required by the table scan
```

The decoder must recognize the four explicit output-mode patterns. It must
also document the reset exception: immediately after reset the PCR may still
be in its input-mode reset state while pull-ups physically select Bank 3.
Bank 3 STR8 may report Bank 3 from the physical-reset invariant without
normalizing the latch.

The original implementation recommendation was:

1. At Bank 3 STR8 initialization, explicitly select Bank 3 once the console/VIA
   setup makes that safe.
2. Decode subsequent PCR read-back against the same table used to select a
   bank.
3. Publish the address, mask, table, and carry contract so an independent guest
   can implement the same small query.
4. Keep image identity separate. `B2` says which physical bank is visible; it
   does not say "FORTH."

That first item is superseded. It was intended to convert the VIA's reset/input
PCR state into canonical output pattern `$EE` so a software bank decoder could
report Bank 3 deterministically. It was not required to select Bank 3: the
board pull-ups already do that on physical reset. More importantly, a copied
STR8 image entered through `J0`-`J2` executes the same initialization and the
write destroys the selected-bank handoff by remapping Bank 3. Generic STR8
startup must therefore leave PCR unchanged. Failure paths and explicit
operations may still select Bank 3 deliberately.

STR8 cannot display the current bank after handing off to an unrelated guest.
The guest must display it itself, or the operator must infer it from the
pre-jump line and target banner.

## RAM State Allocation

The current memory map leaves `$1FF2-$1FF5` unassigned. Allocate the four bytes
as one small handoff record:

| Address | Proposed name | Use |
| ---: | --- | --- |
| `$1FF2` | `STR8_JUMP_BANK` | requested target `0`-`2` |
| `$1FF3` | `STR8_JUMP_VEC_LO` | selected target reset-vector low byte |
| `$1FF4` | `STR8_JUMP_VEC_HI` | selected target reset-vector high byte |
| `$1FF5` | `STR8_JUMP_STATUS` | validation/failure detail |

The 2026-07-31 follow-up also publishes a committed Bank Jump Record at the
tail of the same Recovery State Capsule:

| Address | Implemented name | Use |
| ---: | --- | --- |
| `$1FFD` | `STR8_BANK_JUMP_SIG0` | `$42` (`B`) signature |
| `$1FFE` | `STR8_BANK_JUMP_SIG1` | `$4A` (`J`) commit signature |
| `$1FFF` | `STR8_BANK_LAST_JUMP` | validated target `0`-`2`, or `$FF` |

The worker invalidates the second signature byte, writes the selected bank and
first signature, then writes the second signature as the commit. This happens
after target selection and vector validation, immediately before the final
jump. HIMON validates and carries this byte through cold RAM clearing, then
reconstructs the record. It therefore reports the preceding handoff, not the
Bank 3 PCR state that is live after HIMON regains control.

Add one worker mode without renumbering current modes:

```text
STR8_COPY_MODE_JUMP_BANK = $08
```

Use the same values in resident and worker source. If the build already has a
shared include for worker-state constants when implementation begins, put the
new mode and handoff cells there. Otherwise keep the first patch narrow and add
a build-time equality check before attempting a broader constant refactor.

Suggested status values:

```text
$00  no result / not run
$01  bad command or bank
$02  reset vector below $8000
$03  erased reset vector $FFFF
$80  vector accepted; handoff committed
```

The status is diagnostic only. No Bank 3 code can examine `$80` after a
successful handoff unless the guest later returns by a cooperative path.

## Resident STR8 Changes

The resident half should do only work that is safe while Bank 3 is visible:

1. Add `J` to `STR8_DISPATCH_A` after case folding.
2. Read the next non-space command byte.
3. Accept that first operand only when it is a digit in `0`-`2`.
4. Store the target in `STR8_JUMP_BANK`.
5. Clear the saved vector and status.
6. Print `J Bn`.
7. Flush queued RX so trailing terminal input does not leak into the guest.
8. Copy the existing relocatable worker to `$0200`.
9. Set worker mode `$08` and call the worker.
10. If the worker returns with carry clear, print the saved vector and terse
   error while Bank 3 is selected.
11. Treat a return with carry set as an internal error; the successful path is
    defined never to return.

Do not pre-read the target vector from resident ROM. Selecting another bank
while executing resident `$Fxxx` code would replace the instructions being
executed. All selected-bank reads and the final jump belong in RAM.

## RAM Worker Algorithm

Add a dedicated dispatch branch before the worker's generic copy path:

```text
STR8W_JUMP_BANK:
    disable IRQ
    validate target is 0..2
    select target bank
    read target $FFFC into RAM vector low
    read target $FFFD into RAM vector high
    validate vector
    if invalid:
        select Bank 3
        restore caller status as appropriate
        return C=0

    mark status accepted
    SEI
    CLD
    LDX #$FF
    TXS
    JMP (RAM vector)
```

Implementation constraints:

- The worker, selected-bank routine, vector validator, vector bytes, and
  indirect jump pointer must all be in RAM.
- Take no branch, subroutine call, literal-table read, or message read from
  `$8000-$FFFF` after selecting Bank 0-2.
- Do not `PLP` on the committed path; IRQ must remain disabled.
- The 65C02 cannot mask NMI. The board proof must leave every NMI source
  quiescent during handoff; otherwise a target NMI vector could run before the
  guest reset routine has initialized its state.
- Initialize decimal and stack state exactly as a hardware reset consumer can
  reasonably expect. The target remains responsible for all other device and
  RAM initialization.
- Do not invoke Bank 3 IVI/LEAF vectors after the selection.
- On every validation or internal failure, select Bank 3 before returning.
- Do not modify flash under any outcome.

The handoff is reset-like but is not an electrical reset. Peripheral state,
RAM contents, pending interrupt flags, and the VIA configuration survive.
Independent guest images must tolerate that or provide an entry specifically
designed for warm bank handoff. This difference must be part of OSI
BASIC/FORTH/WOZMON image qualification.

## Timeout And Bank 3 Default

Keep the current startup sequence:

```text
Bank 3 RESET -> STR8 countdown
key takeover -> STR8 command loop
timeout      -> Bank 3 default payload
```

For the current R-YORS image, timeout continues to enter Bank 3 HIMON cold.
The timeout code does not execute `J3` and does not touch the bank latch.

The visible startup text is bank-neutral because the same image may be entered
from Bank 0-2 through `J`. Do not promise the name of the local payload in the
generic mechanism.

## Destructive Command Interaction

Adding `J` does not make the current backup/restore policy safe for mixed bank
roles:

- `B` can overwrite a Bank 0-2 OS, language, or data bank when used as a
  destination by existing rotation policy.
- Bare `0`, `1`, or `2` can copy an unrelated source into Bank 3.
- High restore can replace Bank 3 STR8 with the source bank's unrelated top
  sector, destroying the selector until external recovery.
- Ordinary restore that preserves the Bank 3 high region may combine an
  unrelated lower image with Bank 3 STR8 and yield an incoherent system.

The first `J` patch must not silently reinterpret these proven commands.
Instead:

1. Put an operator warning in the plan and command documentation.
2. Capture all bank roles before a mixed-system installation.
3. Do not run `B` or restore commands against a mixed-role board unless the
   exact source, destination, protected-window behavior, and rollback image are
   intended.
4. Plan a later role-aware mutation guard using Bank 3 external metadata.

`J` itself remains safe to try from a flash-wear perspective because it is
read-only.

## Space Budget And Stop Gates

The pre-implementation 2026-07-28 combined build baseline was:

```text
resident STR8 end       $F9B3
stored worker           $FD60-$FFEF
resident/worker gap     $F9B3-$FD5F = $03AD (941 bytes)
RAM worker tray         $0200-$09FF = 2048 bytes
stored worker length    $0290 (656 bytes)
unused RAM tray         1392 bytes
```

The first implemented host candidate measures:

```text
resident STR8 end       $FA63
stored worker           $FD16-$FFEF
resident/worker gap     $FA63-$FD15 = $02B3 (691 bytes)
RAM worker tray         $0200-$09FF = 2048 bytes
stored worker length    $02DA (730 bytes)
unused RAM tray         1318 bytes
combined top growth     250 bytes
```

The actual growth exceeded the 100-200 byte planning estimate but remains 179
bytes above the `$0200` stop gate. The combined-image builder now rejects a
smaller gap and also checks mode `$08` plus `$1FF2-$1FF5` resident/worker
agreement. Do not use the remaining gap for unrelated features.

The command-echo follow-up adds six resident bytes without changing the
worker:

```text
resident STR8 end       $FA69
stored worker           $FD16-$FFEF
resident/worker gap     $FA69-$FD15 = $02AD (685 bytes)
RAM worker tray         $0200-$09FF = 2048 bytes
stored worker length    $02DA (730 bytes)
unused RAM tray         1318 bytes
stop-gate headroom      $00AD (173 bytes)
```

The Bank Jump Record follow-up adds 19 worker bytes and moves the packed worker
down while retaining the stop gate:

```text
resident STR8 end       $FAEF
stored worker           $FD03-$FFEF
resident/worker gap     $FAEF-$FD02 = $0214 (532 bytes)
RAM worker tray         $0200-$09FF = 2048 bytes
stored worker length    $02ED (749 bytes)
unused RAM tray         1299 bytes
stop-gate headroom      $0014 (20 bytes)
```

The combined-image builder checks `$1FFD-$1FFF` across resident STR8, the RAM
worker, and HIMON, checks the `$42/$4A/$FF` ABI values, and rejects less than
`$0200` contiguous resident/worker gap.

The 2026-07-29 clean rebuild after restoring the `ae60409` baseline reports
the complete flash-region budget:

| Region | Product | CODE | DATA | End | Remaining to region limit |
| --- | --- | ---: | ---: | ---: | ---: |
| `$8000-$BFFF` | ASM-F2 | `$3987` | `$02E6` | `$BC6D` | `$0393` (915 bytes) to `$C000` |
| `$C000-$EFFF` | HIMON | `$2922` | `$0596` | `$EEB8` | `$0148` (328 bytes) to `$F000` |
| `$F000-$FFFF` | STR8 resident | `$08DA` | `$018F` | `$FA69` | `$0597` (1431 bytes) to `$10000`, raw |

STR8's raw `$0597` remainder is not one free span. The stored RAM worker owns
`$FD16-$FFEF` (`$02DA`, 730 bytes), and `$FFF0-$FFFF` remains the
configuration/vector tail. The usable contiguous resident/worker gap is
`$FA69-$FD15`, `$02AD` (685 bytes), with `$00AD` (173 bytes) above the frozen
`$0200` stop gate. ASM-F2 also links `$11AA` bytes of UDATA at `$5000`; that RAM
workspace is not part of its `$8000-$BFFF` flash consumption.

Apply these size rules:

- Record resident end, worker start/end, exact gap, and RAM worker length after
  every implementation slice.
- Keep at least `$0200` contiguous bytes between resident STR8 and the packed
  worker after the first implementation.
- Stop and review if the gap falls below `$0200`, if the worker exceeds its
  `$0200-$09FF` tray, or if fixed entries/vectors move.
- Prefer routine reuse and compact status output over another parser framework.
- Do not grow HIMON for this feature.
- Do not consume `$F010-$F01F` as a per-bank BPB. Any bytes available there
  are merely Bank 3 STR8 layout space subject to its existing fixed ABI.

## Source And Document Change Set

Expected source touchpoints:

| File | Planned change |
| --- | --- |
| `SRC/STR8/str8.asm` | `J` parser/dispatch, RAM state names, messages, worker invocation, Bank 3 banner |
| `SRC/STR8/str8-worker.asm` | mode `$08`, selected-bank vector read/validation, no-return reset-like tail |
| `SRC/LIB/dev/flsh-drv.asm` | table-driven `FLSH_BANK_GET_A` and shared bank-pattern documentation |
| STR8 build/check scripts | assert worker constants, tray fit, fixed ABI, vectors, and remaining gap |

Expected documentation touchpoints:

- STR8 operator command reference;
- technical guide and memory map;
- decisions, TODO, future direction, index, and TOC;
- generated command/routine documents if their generator consumes the changed
  source or command tables;
- hardware test plan and hardware log after board evidence exists.

Files under `DOC/GENERATED/` remain generated output. Change their generator in
`SRC/tools/` and regenerate rather than hand-editing them.

## Implementation Slices

### Slice 0: Freeze And Inventory

- Build current STR8 and combined ROM.
- Save current resident/worker addresses and sizes.
- Run
  [str8-jump-inventory-v1-3000.a](../ASM/SAMPLES/OLD/str8-jump-inventory-v1-3000.a),
  which records one full-32K CRC, vectors, selected top bytes, and final PCR
  state for every bank without writing flash.
- Record each bank's CRC, reset/NMI/IRQ vectors, known identity, and whether the
  top sector appears to be STR8, WOZMON, or something else.
- Confirm physical reset repeatedly lands in Bank 3.
- Make no flash writes.

Exit gate: a hardware transcript makes the starting state and rollback source
unambiguous.

### Slice 1: Current-Bank Query

- Add and unit-review `FLSH_BANK_GET_A`.
- Test all four explicit PCR patterns in a RAM proof.
- Test/document the PCR reset-state exception.
- Add a small board fixture that selects `0,1,2,3`, queries each, prints the
  result, and always restores Bank 3.
- Do not integrate `J` yet.

Exit gate: decoded bank matches each requested latch state and Bank 3 is
restored after all failure paths.

### Slice 2: RAM-Only Handoff Probe

- Add a standalone RAM fixture that copies only the proposed vector-read and
  validation logic.
- Select each bank, capture `$FFFC-$FFFD` into RAM, restore Bank 3, and print
  the result.
- Exercise invalid synthetic vectors without modifying flash by pointing the
  validator at RAM test cells.
- Inspect the assembled RAM routine to prove it has no post-selection ROM
  dependency.

Exit gate: all banks can be inspected without a write or loss of Bank 3.

### Slice 3: Worker Mode

- Add mode `$08` and handoff state cells.
- First test the invalid/failure path only so the worker must select Bank 3 and
  return.
- Add the committed no-return tail.
- Use a known-good R-YORS copy as the first target, preferably the bank whose
  read-back and vector were just proven.
- Print a unique pre-jump bank/vector line and use the target's existing banner
  as independent evidence.
- Press physical reset and prove return to Bank 3 STR8.

Exit gate: success enters the selected bank; invalid input returns to Bank 3;
physical reset always recovers Bank 3.

### Slice 4: Resident `J` Command

- Add compact and spaced grammar.
- Preserve bare restore commands.
- Test every accepted and rejected spelling.
- Test Bank 0 data/hold behavior only after recording its vector. Do not jump
  merely because the gate happens to accept random data.
- Confirm the command does not call erase or program routines.

Exit gate: the complete command matrix passes and all refusal paths remain in
Bank 3.

### Slice 5: Independent-System Images

> **IMPORTANT: PER-IMAGE QUALIFICATION**
>
> Each unrelated system still needs its own warm-handoff, peripheral, vector,
> and CRC qualification. Proof for R-YORS or one guest must never be reused as
> approval for a different image, build, configuration, or bank.

Qualify one system at a time:

1. Build or obtain an exact 32K image for `$8000-$FFFF`.
2. Record provenance, load address, reset/NMI/IRQ vectors, checksum/CRC, console
   assumptions, RAM use, and warm-handoff requirements.
3. Verify the image in an emulator or controlled RAM path when possible.
4. Back up the destination bank and prove the rollback image.
5. Program the destination through an already-proven explicit process; this is
   a separate operation from `J`.
6. Read the full 32K bank back and compare its expected CRC.
7. Physical reset into Bank 3 STR8, then run `J1` or `J2`.
8. Capture the guest's unique banner or behavior.
9. Physical reset and prove Bank 3 STR8/default timeout again.

OSI BASIC, fig-FORTH, and WOZMON each need their own qualification record.
None is assumed to use the same reset-time peripheral state as R-YORS.
Use
[STR8_GUEST_IMAGE_QUALIFICATION.md](../STR8/STR8_GUEST_IMAGE_QUALIFICATION.md)
for the generic H/P/V/C record, test procedure, stop conditions, and
promotion boundary.

### Slice 6: Regression And Promotion

- Re-run STR8 `?`, `B`, `0`, `1`, `2`, `G`, `U`, and `R` tests appropriate to
  the current bank-role layout.
- Re-run timeout with no key and prove Bank 3 default.
- CRC every bank before and after all `J` tests; values must be unchanged.
- Re-run combined-image ABI/vector/build-size checks.
- Append hardware evidence to the hardware log.
- Promotion gate: passed on 2026-07-28; `J0`-`J2` V1 is implemented and
  hardware-proven on the recorded board images.

## Test Matrix

### Host/build

| Test | Expected result |
| --- | --- |
| STR8 build | passes |
| combined ROM build | passes |
| fixed `$F000/$F003/$F006/$F009` entries | unchanged |
| reset/NMI/IRQ vectors | valid and unchanged for Bank 3 image |
| stored worker | ends no later than `$FFEF` |
| relocated worker | fits `$0200-$09FF` |
| resident/worker gap | at least `$0200` |
| `git diff --check` | clean |

### Parser

| Input | Expected result |
| --- | --- |
| `J0`, `J1`, `J2` | displayed at prompt; invokes non-destructive validation |
| `j0`, `j 2` | displayed with folded `J`; same dispatch as uppercase |
| `J 0`, `J 1`, `J 2` | spaces displayed and accepted |
| bare `0`, `1`, `2` | existing restore confirmation path |
| `J3` | rejected |
| `J` | waits for an operand |
| `Jx`, `J-1` | rejected |
| `J20` | starts `J2`; trailing `0` is flushed |
| CR/LF noise before digit | handled exactly as documented |

### Vector gate

| Vector | Expected result |
| ---: | --- |
| `$0000` | reject, Bank 3 restored |
| `$7FFF` | reject, Bank 3 restored |
| `$8000` | accept |
| `$C000` | accept |
| `$F000` | accept |
| `$FF00` | accept |
| `$FFFF` | reject, Bank 3 restored |

### Hardware behavior

| Case | Expected result |
| --- | --- |
| no startup key | Bank 3 default after timeout |
| takeover key | Bank 3 STR8 command loop |
| valid `Jn` | visible prompt input, pre-jump bank line, target reset entry |
| invalid `Jn` vector | terse error from Bank 3 |
| NMI sources | quiescent across the select/jump window |
| target hangs | physical reset returns to Bank 3 |
| repeated `J` tests | no bank CRC changes |
| independent image | may own all `$8000-$FFFF`; no STR8/BPB dependency |

## Recovery And Rollback

The bench rail for every first jump is:

```text
known Bank 3 STR8 image
full read-back/CRC of all banks
known-good target vector
terminal transcript running
physical RESET reachable
external programmer or proven restore image available
```

If a target hangs, press physical reset. If reset does not return to Bank 3,
stop: do not issue blind restore commands. Verify the bank-select hardware and
recover Bank 3 with the already-recorded image or external programmer.

If Bank 3 high flash is ever replaced with an unrelated source, `J` and its
timeout cannot repair the situation because their code is gone. That failure
belongs to flash-update/restore recovery, not to the jump command.

## Deferred Decisions

These choices do not block the RAM handoff proof:

- where the required Bank 3 external validation manifest will live and how it
  is committed atomically;
- whether an unregistered but plausible vector requires an extra confirmation;
- whether a later `J3` means local Bank 3 reset entry or is simply rejected;
- whether timed boot may later target a registered Bank 0-2 system;
- whether guests share a tiny published bank-query source snippet;
- whether a reset-like peripheral normalization profile is needed for specific
  OSI BASIC, FORTH, or WOZMON builds;
- whether size pressure ever justifies reopening the deferred common HB/NUL
  printer and product-prefix optimization. The `4b73509` planning experiment
  was restored to the hardware-proven `ae60409` baseline after finding only
  about 25-32 bytes of final savings for broad cross-product and hardware
  proof cost.

None of those decisions may reintroduce a required metadata block into the
opaque Bank 0-2 images.

## Definition Of Done

The `J0`-`J2` V1 handoff mechanism is complete when:

- source and generated documentation agree on the command grammar;
- Bank 3 timeout still launches the Bank 3 default;
- selected-bank read and final transfer execute entirely from RAM;
- Bank 0-2 require only a plausible full-image reset vector;
- invalid vectors restore Bank 3 without a flash write;
- the recorded R-YORS target images pass on hardware;
- physical reset recovers Bank 3 from every tested target;
- pre/post full-bank CRCs prove `J` is non-destructive;
- the build-size gates pass; and
- the hardware transcript is appended rather than rewriting prior evidence.

A genuinely independent 32K system is a separate image-qualification gate, not
a reason to reopen the proven bank-switch mechanism. Before promoting any OSI
BASIC, FORTH, WOZMON, or other unrelated image for routine use, complete Slice
5 for that exact image and record its CRC, vectors, peripheral assumptions,
warm-handoff behavior, and physical-reset recovery. Use the
[guest-image qualification procedure](../STR8/STR8_GUEST_IMAGE_QUALIFICATION.md).
