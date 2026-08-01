# STR8-N Four-Bank Installer V1 Plan

```text
status:       DESIGN FROZEN; 32K FTDI TRANSPORT PROVEN
next gate:    DENSE 28K FTDI TRANSPORT PROOF; ACIA UNQUALIFIED
source date:  2026-07-31
```

This is the accepted V1 plan for turning the WDC board into four independently
selectable bank environments while keeping STR8-N as the Bank-3 reset
supervisor. Banks may contain code, data, volumes, overlays, tools, or any
other payload. Directory `TYPE` is display metadata only; it never selects a
loader or grants permission to execute.

V1 deliberately does not include a volume manager, mutable bank descriptions,
wear balancing, sparse S19 input, or the external S19 backup generator. Those
remain later work.

> **Transport warning:** the accepted 32K result applies only to Windows Tera
> Term Send File over the current FTDI FIFO path. It does not qualify an ACIA.
> An ACIA may overrun while erase/program/verify stops target reads, especially
> when the RAM flash worker masks interrupts. ACIA operation is unsupported
> until its own pacing or flow-control profile passes the complete dense proof.

## Hardware and Recovery Contract

Physical reset maps Bank 3 and enters STR8-N. STR8-N may then select and hand
off to any installed bank. A successful handoff leaves the selected bank
visible; STR8-N does not switch back behind the payload.

Flash erase sectors are 4K. Every erase, program, verify, or bank-changing
handoff runs from RAM. Resident flash code must never continue executing after
selecting another bank.

The Bank-3 top sector contains STR8-N, its stored RAM worker, the central Bank
Directory, configuration, and vectors. Failure during a top-sector replacement
can therefore require external recovery. The ordinary `I` installer never
erases that sector.

## Final Flash Layout

Banks 0-2 are opaque 32K images:

```text
$8000-$FFFF  complete bank image, including that image's own vectors
```

Bank 3 is divided into an arbitrary payload and the fixed supervisor:

```text
$8000-$EFFF  arbitrary Bank-3 payload, 28K
$F000-...    resident STR8-N code and data, growing upward
...          contiguous free growth gap, at least $0100
...-$FFAF    stored RAM worker, packed downward
$FFB0-$FFEF  fixed Bank Directory, 64 bytes
$FFF0-$FFF9  existing configuration pocket
$FFFA-$FFFF  STR8-N NMI, RESET, and IRQ vectors
```

The build must enforce:

```text
workerStoreEndExclusive = $FFB0
worker execution size   <= $0800
resident/worker gap     >= $0100
directory size          == $0040
```

The stable STR8-N entries remain:

```text
$F000  STR8-N start
$F003  RAM-worker service
$F006  HIMON AP compatibility bridge
$F009  validated-record service
$F00C  SR/01/07 service signature and capabilities
```

## Fixed Bank Directory

The directory exists only in Bank 3 and is the common, immutable V1 metadata
source for all four banks:

```text
$FFB0-$FFBF  Bank 0 record
$FFC0-$FFCF  Bank 1 record
$FFD0-$FFDF  Bank 2 record
$FFE0-$FFEF  Bank 3 record
```

Each record is exactly 16 bytes:

```text
+0       TYPE             arbitrary hex byte; display metadata only
+1..+3   RESERVED         must remain $FF
+4..+8   DESCRIPTION      exactly five uppercase display characters
+9       FLAGS/SEAL       exactly $FE when sealed
+A..+B   LOCAL ENTRY      little-endian Bank-3 entry; $FFFF for Banks 0-2
+C..+F   INSTALL JOURNAL  four bytes; sixteen two-bit transactions
```

Description input accepts `A-Z`, `0-9`, `-`, `_`, and `.`. Lowercase input is
folded to uppercase. TYPE, DESCRIPTION, and the Bank-3 LOCAL ENTRY are
immutable after first installation. Changing them requires later explicit
top-sector maintenance.

An entirely `$FF` record is empty. A partially programmed or structurally
unexpected record is never launchable.

## Seal and Install Journal

The seal is programmed from `$FF` to exactly `$FE`. Validation requires the
whole byte to equal `$FE`; merely finding bit zero clear is insufficient.

Each journal transaction uses one two-bit pair, low pair first:

```text
11  unused
10  started/incomplete
00  completed
01  illegal
```

The only legal progressions within one journal byte are:

```text
$FF -> $FE -> $FC -> $F8 -> $F0 -> $E0 -> $C0 -> $80 -> $00
```

After `$00`, installation continues in the next journal byte. Four journal
bytes provide sixteen completed installations per bank.

Validation requires completed earlier pairs, no holes, no `01` pair, at most
one latest `10` pair, and unused later pairs. If the latest transaction is
started but incomplete, the bank is nonlaunchable and `I` retries that same
pair. It does not consume another pair.

The START transition is written and read-back verified before any other
persistent install write after the operator's final confirmation. This makes
every partial first-install descriptor part of a known incomplete transaction.
The COMPLETE transition is written and verified last.

A torn START write cannot make a bank launchable. A torn COMPLETE write occurs
only after the complete image has already passed read-back verification: if
the bit still reads one, the bank remains incomplete; if it reads zero, the
verified transaction is complete.

When all sixteen pairs have been consumed, `I` refuses another installation.
Journal renewal belongs to explicit future top-sector maintenance.

## Command Surface and Input

The reset-time selector is:

```text
0  Bank 0
1  Bank 1
2  Bank 2
3  Bank 3 payload
S  remain in STR8-N
```

Timeout attempts the Bank-3 payload only when its directory record is complete
and its LOCAL ENTRY is launchable. Otherwise timeout remains safely in STR8-N.

The V1 prompt is:

```text
? I J0 J1 J2 J3 R
```

`?` prints the STR8-N identity and compact directory status. `I` installs a
bank image. `J0` through `J3` perform non-destructive handoff. `R` selects Bank
3 and resets into STR8-N.

The destructive V0 meanings of `B`, `U`, bare prompt `0`, `1`, or `2`, and `G`
are retired. `B` remains reserved for the future external S19 backup generator.
Unknown worker modes must fail explicitly and must never fall through to an old
copy operation.

Command and prompted input use a small shared line editor:

- Printable lowercase is folded before echo, so echoed input is uppercase.
- Backspace and Delete remove the previous buffered character and update the
  display.
- CR, LF, and CR/LF terminate a line consistently.
- An empty line is a negative or abort response.
- Confirmation succeeds only for `Y`; every other response aborts.

The STR8-N version line contains no guessed bank suffix:

```text
STR8-N V 00.xxxx(xxxx) #5F6A0F7A
```

## `I` Operator Flow

For an empty directory record, `I` prompts separately for:

```text
BANK 0-3
TYPE, two hex digits
DESCRIPTION, exactly five characters
FINAL INSTALL CONFIRMATION
```

For an existing record, `I` displays and validates the immutable TYPE,
DESCRIPTION, and LOCAL ENTRY instead of accepting replacements.

The initial `Y` is the final destructive confirmation. After it, STR8-N writes
and verifies the journal START transition and then requests the S19 stream.
Sending the S19 begins sector mutation; there is no later post-receive erase
confirmation.

Persistent installer state that must survive worker calls lives within
`$1A00-$1FE8`. It must not depend on worker zero page `$CD-$D6`, the worker
state board `$1FE9-$1FFF`, or transient command-reader state.

The installer uses:

```text
$0200-$09FF  RAM worker-code tray
$0A00-$19FF  one full 4K staged sector
$1A00-$1FE8  persistent installer state
$7B00-$7BFB  existing validated S19 record buffer
$7E95-$7EA8  existing record request/result card
```

## Dense V1 S19 Contract

V1 accepts only a dense, canonical S19 stream:

- An optional S0 may appear only before data.
- Data uses S1 records with valid counts and checksums.
- S1 addresses are strictly increasing and contiguous.
- There are no gaps, overlaps, duplicates, or backward records.
- `$FF` bytes are represented explicitly.
- Zero-length S1 data records are rejected.
- An S1 record may cross a 4K boundary; STR8-N splits its decoded bytes between
  the two staged sectors correctly.
- Exactly one S9 terminates the image.
- No record follows S9; only the S9 line's CR, LF, or CR/LF termination is
  accepted.

Required logical coverage is:

```text
Banks 0-2  exactly $8000-$FFFF
Bank 3     exactly $8000-$EFFF
```

For Banks 0-2, the S9 address must equal the staged reset vector at
`$FFFC/$FFFD`. A vector and S9 of `$FFFF` are permitted for a deliberately
nonlaunchable data bank. A launchable vector must point within `$8000-$FFFF`.

For Bank 3, S9 is the immutable LOCAL ENTRY. It must be within `$8000-$EFFF`,
or exactly `$FFFF` for a deliberately nonlaunchable payload.

V1 has no whole-image CRC. Integrity comes from every S-record checksum, exact
dense coverage, strict ordering, final-entry validation, full-sector read-back
verification, and the install journal.

## Sector Streaming and Final-Sector Gate

Only one sector is staged. Earlier complete sectors are erased, programmed,
and verified while the sender still has later S-records to transmit.

For Banks 0-2:

```text
stream/program/verify  $8000-$EFFF
hold                   $F000-$FFFF
validate S9             against staged $FFFC/$FFFD
program final sector    only after S9 validation
```

For Bank 3:

```text
stream/program/verify  $8000-$DFFF
hold                   $E000-$EFFF
validate S9             as $8000-$EFFF or $FFFF
program final sector    only after S9 validation
```

The final successful sequence is:

1. Write and verify journal START.
2. On first install, write and verify TYPE and DESCRIPTION; reserved bytes stay
   `$FF`.
3. Receive, validate, stage, program, and verify every earlier sector.
4. Receive and validate the unique S9.
5. Program and verify the held final sector.
6. On first Bank-3 install, write and verify LOCAL ENTRY.
7. On first install, write and verify seal `$FE`.
8. Write and verify journal COMPLETE last.

On syntax, checksum, order, coverage, range, transport, S9, flash, or verify
failure, STR8-N stops target programming and leaves the journal incomplete. It
asks the operator to stop the sender or issue Ctrl-C, then drains and waits for
a defined idle boundary. Queued S19 input must never become STR8-N commands.

## Mandatory Dense Transport Proof

The 32K FTDI half of this gate passed on 2026-07-31. The dense 28K FTDI form is
the next transport gate. Every other physical receive path remains separately
unqualified.

The existing three-sector HIMON updater is useful evidence, but it receives its
entire 12K S19 into RAM before programming. It therefore does not prove that
the host, terminal, FTDI path, and receive FIFO tolerate the no-read intervals
created when the new installer programs a sector during an active stream.

Before real `I` erasure is enabled, a RAM-only proof must:

1. Receive a complete dense 32K canonical S19 without writing flash.
2. Insert a worst-case flash-length no-read pause at every 4K boundary.
3. Use the intended terminal, baud rate, cable, FTDI path, and Send File
   settings.
4. Validate record checksums, strict coverage, exact byte count, and S9.
5. Repeat the proof for the dense 28K Bank-3 form.

The pause is based on the slowest measured erase/program/verify sector time,
with margin. If raw Send File fails, the supported V1 transport profile will
use a documented terminal line delay or flow-control setting and the full proof
will be repeated. Real bank installation remains gated until one documented
profile passes.

The proof image must be dense and near worst case. Sparse input must not be
used to hide a buffering or backpressure failure.

### 2026-07-31 Windows Tera Term/FTDI 32K Result

The real-flash Bank-0 proof supersedes the synthetic-pause requirement for the
32K FTDI case. Windows Tera Term Send File completed with both bulk and
sequential reads; their order is irrelevant to this gate. Three captured runs
each printed eight completed-sector dots and returned `A=$AC`, carry set:

```text
SEND BANK0-ZERO-8000-FFFF.S19 NOW
........ 8 SECTORS ERASED/PROGRAMMED/VERIFIED
RET A=AC X=71 Y=25 P=F5 S=FD NV-BdIzC
```

These were real erase/program/full-sector-verify pauses. Repeating the all-zero
image did not turn the test into an equal-byte fast path: a programmed-zero
sector is not erased `$FF`, so every sector was erased and then programmed
again. Exact S19 checksums, dense ordering, full `$8000-$FFFF` coverage, S9
`$0000`, the held final sector, and read-back verification all completed.

This result qualifies only the tested Windows Tera Term plus FTDI FIFO stack.
The FTDI and host queues can retain data while the target is not reading. A
typical ACIA has only a shallow hardware receive path and may overrun almost
immediately during the same flash pause. An interrupt-fed RAM ring does not
solve the interval while the flash worker has interrupts masked.

Before any ACIA path is called supported, it must use and document one of:

- hardware flow control that stops the sender before receive capacity is lost;
- explicit host pacing or a sector ACK/resume protocol;
- an XOFF/XON protocol sent before and after the no-read interval; or
- complete pre-flash staging outside the affected receive path.

The selected ACIA profile must then repeat the dense 32K and 28K proofs. The
FTDI pass is not acceptable evidence for that ACIA gate.

## Directory Byte Programming

The current HIMON `L F` record policy cannot write the directory journal. It
accepts only equal destination bytes or destinations still equal to `$FF`, and
it protects high flash. Journal progress requires valid repeated one-to-zero
transitions in the same byte, such as `$FE->$FC`.

STR8-N therefore uses a dedicated directory write wrapper around RAM-worker
mode `$07`:

```text
require (old_byte AND new_byte) == new_byte
stage the desired directory bytes in the existing record buffer
run the no-erase byte programmer from RAM with Bank 3 selected
read back and verify every byte exactly
```

This does not weaken or broaden HIMON's existing `L F` write policy.

## Launch Validation and Bank Jump Record

A bank launches only when its directory record is structurally valid, its seal
is exactly `$FE`, and its latest journal transaction is complete.

`J0` through `J2` then select the target bank, read its reset vector from RAM
worker code, and refuse `$FFFF` or a vector outside `$8000-$FFFF`. `J3` uses the
Bank-3 LOCAL ENTRY and refuses `$FFFF` or an entry outside `$8000-$EFFF`.

Immediately before the final jump, the RAM worker publishes:

```text
$1FFD-$1FFF = $42 $4A bank
```

The accepted bank range expands from `$00-$02` to `$00-$03`. HIMON cold-clear
preservation changes its validation from bank `<3` to bank `<4`.

The directory is checked while Bank 3 is visible. Launch state and the selected
entry are copied into RAM before another bank is selected.

## Worker Modes and Compatibility

V1 retains only these active worker modes:

```text
$05  PROGRAM_STAGED
$06  STAGE_BANK_SECTOR
$07  PROGRAM_RECORD
$08  JUMP_BANK
```

Mode `$06` remains required by HIMON AP support. The V0 full-copy and restore
modes are retired. The worker dispatcher explicitly rejects every unrecognized
mode.

## TopWriter Migration and Preservation

The first V1 top-sector installation is a special migration. In the old layout,
`$FFB0-$FFEF` contains stored worker code, not directory records. A dedicated
one-time migration writer must explicitly initialize those 64 bytes to `$FF`
and pack the new worker below `$FFB0`. It must not infer directory validity from
arbitrary old bytes, and it requires a distinct migration confirmation.

Every later TopWriter must:

1. Stage the complete new `$F000-$FFFF` image.
2. Copy the live `$FFB0-$FFEF` bytes exactly into the staged image.
3. Erase and rebuild the Bank-3 top sector from RAM.
4. Verify the entire sector by read-back.

Later TopWriters preserve all 64 bytes, including incomplete or invalid
records. They never silently erase a damaged record or make it appear fresh.

An externally programmed full Bank-3 image can overwrite the directory. That
is an explicit full-image operation, not an `I3` payload installation.

## Current Size Baseline and Budget

The accepted preimplementation host build reports:

```text
STR8 resident code/data  $F000-$FAEE  size $0AEF = 2799
stored worker            $FD03-$FFEF  size $02ED = 749
resident/worker gap      $FAEF-$FD02  size $0214 = 532
```

Moving the unchanged worker below the directory would produce:

```text
stored worker            $FCC3-$FFAF
resident/worker gap      $FAEF-$FCC2  size $01D4 = 468
required post-I reserve                 $0100 = 256
immediate growth room                   $00D4 = 212
```

Estimated reclaim is approximately 727 resident bytes from retired V0 command
clients and messages, plus 120-155 worker bytes from retired full-copy and
restore paths. That gives the new installer approximately 1059-1094 bytes while
retaining the hard `$0100` floor.

The gross installer estimate remains 700-1100 bytes. The build gate, not the
estimate, decides acceptance. If the first implementation is too large, it is
optimized before removing existing compatibility services. Removing HIMON's
current `L F` compatibility adapter is a separate decision, not an automatic
size action.

Persistent new data is expected to be:

```text
Bank Directory                    64 flash bytes
installer state                   about 32-96 RAM bytes in $1A00-$1FE8
sector staging                    existing 4096-byte tray
validated record staging          existing 252-byte tray
```

## Sparse S19 Is a Future Enhancement

Sparse S19 is explicitly outside V1. The dense transport proof and dense
installer are implemented first.

A future STR8 sparse format may omit fixed-size output blocks that contain only
`$FF`. It must be explicitly marked, because an ordinary S19 address gap does
not distinguish an intentional erased run from a lost S1 record. The accepted
future direction is:

```text
S0  identifies the STR8 sparse format
S1  carries non-erased blocks in increasing address order
S5  is mandatory and gives the exact S1-record count
S9  remains mandatory
gaps inside the fixed bank range expand to $FF
```

Skipped sectors must still be erased and verified as `$FF`; they are not left
unchanged. Sparse generation is expected to omit only complete 16- or 32-byte
all-`$FF` blocks, keeping the future target generator small.

## Future External Backup Command

`B` is reserved in V1. A future `B0` through `B3` command will emit a canonical
external-backup S19 for the complete `$8000-$FFFF` bank, with S9 equal to the
bank reset vector. Sparse output may be added under the explicitly marked
future format above.

A full Bank-3 backup includes the payload, STR8-N, worker, all four directory
records, configuration, and vectors. Full Bank-3 restoration requires a
protected top-sector writer or an external programmer. `I3` remains restricted
to the `$8000-$EFFF` payload.

The future `B` estimate is 160-240 resident bytes and no persistent data.

## Implementation Sequence

1. Build the RAM-only dense 32K/28K transport proof with flash-length pauses.
2. Establish the new top-sector layout, `$FFB0` worker ceiling, 64-byte empty
   directory, and `$0100` minimum-gap build gate.
3. Add directory constants, structural validation, journal scanning, and the
   dedicated one-to-zero directory writer.
4. Replace single-character prompt input with the uppercase buffered editor and
   freeze the V1 command surface.
5. Implement dense S19 installer state, exact coverage checks, sector splitting,
   streaming sector writes, S9 gates, and failure drain behavior.
6. Gate `J0-J3` through directory state, add the Bank-3 local-entry handoff, and
   extend the Bank Jump Record to Bank 3.
7. Generate the one-time migration TopWriter and make every later TopWriter
   preserve the live directory exactly.
8. Complete host, RAM, and board failure tests before accepting the installer.

## Acceptance Gates

V1 is accepted only when:

- Host build and all address, ABI, and size assertions pass.
- At least `$0100` contiguous resident/worker growth space remains.
- Every legal journal state and representative torn/illegal state is tested.
- Dense S19 checksum, order, coverage, boundary-crossing, S9, and trailing-data
  tests pass.
- Backspace, Delete, uppercase echo, CR, LF, CR/LF, and empty-abort behavior
  pass.
- The dense 32K and 28K transport-with-pauses proofs pass for the supported
  FTDI terminal profile. The 32K half passed on 2026-07-31; 28K remains open.
- Any claimed ACIA support has its own documented pacing/flow-control profile
  and passes both dense proofs; otherwise ACIA remains explicitly unsupported.
- Power interruption at every transaction stage leaves the target
  nonlaunchable until a successful retry completes.
- The final sector is never programmed before S9 validation.
- `J0-J3`, Bank Jump Record publication, and physical-reset recovery pass.
- A normal TopWriter preserves all 64 live directory bytes exactly.
- Every bank not selected for installation remains byte-for-byte unchanged.
