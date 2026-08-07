# STR8-N Four-Bank Installer V1.01 Plan

```text
status:       V1 MIGRATION + FIRST JOURNALED BANK INSTALL HARDWARE-ACCEPTED
next gate:    NEGATIVE/INTERRUPTED RECOVERY BOARD MATRIX OR NEXT V1 SLICE
source date:  2026-08-06
```

This is the accepted V1.01 plan for turning the WDC board into four independently
selectable bank environments while keeping STR8-N as the Bank-3 reset
supervisor. Banks may contain code, data, volumes, overlays, tools, or any
other payload. Directory `TYPE` is display metadata only; it never selects a
loader or grants permission to execute.

V1.01 uses one destination-explicit `I` command. It installs complete 32K
images into Banks 0-2 and the 28K `$8000-$EFFF` payload into Bank 3. Bank 3 is
selected through the same `BANK 0-3` prompt, but `I3` can never write the
Bank-3 supervisor sector at `$F000-$FFFF`. The transitional fixed-range `U`
command is retired from V1 rather than generalized.

V1.01 deliberately does not include a volume manager, mutable bank descriptions,
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
can therefore require external recovery. Ordinary `I` never erases that
sector. Its replacement remains a separate expert/recovery operation.

## Final Flash Layout

Banks 0-2 are opaque 32K images:

```text
$8000-$FFFF  complete bank image, including that image's own vectors
```

Bank 3 is divided into an arbitrary payload and the fixed supervisor:

```text
$8000-$EFFF  arbitrary Bank-3 payload, 28K
$F000-...    resident STR8-N code and data, growing upward
...          contiguous free growth gap, at least $0040
...-$FFAF    stored RAM worker, packed downward
$FFB0-$FFEF  fixed Bank Directory, 64 bytes
$FFF0-$FFF9  existing configuration pocket
$FFFA-$FFFF  STR8-N NMI, RESET, and IRQ vectors
```

The build must enforce:

```text
workerStoreEndExclusive = $FFB0
worker execution size   <= $0800
resident/worker gap     >= $0040 during installer development
directory size          == $0040
```

The stable STR8-N entries remain:

```text
$F000  STR8-N start
$F003  RAM-worker service
$F006  retired AP bridge; carry-clear tombstone
$F009  validated-record service
$F00C  SR/01/07 service signature and capabilities
$F010  RAM-caller bank-selection service
```

`JSR $F010` is the published userland bank selector. The caller passes
`A=$00-$03`; carry set means the bank was selected and carry clear means the
request was rejected without changing banks. Because selecting a bank replaces
the complete `$8000-$FFFF` window, both the caller and its JSR return address
must be RAM below `$8000`. STR8 copies its worker to `$0200`, verifies that RAM
return condition, and tail-calls the fixed `$0203` RAM trampoline. `A`, `X`,
and `Y` are clobbered. The selected bank remains visible on return.

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

The 2026-08-01 read-only directory slice adds the shared
`STR8/str8-directory-eq.inc` constants and the host reference gate:

```text
make -C SRC str8-directory-check
```

The gate checks the guarded preview's four empty records plus 33 exact legal
journal states, 61 illegal progression fixtures, and record fixtures covering
empty, complete, incomplete, exhausted, malformed reserved/description/seal,
and bank-specific LOCAL ENTRY cases. It distinguishes record states EMPTY,
INCOMPLETE, COMPLETE, and INVALID; a COMPLETE record may report no next pair
when all sixteen transactions are consumed. A partial first-install descriptor
is record-INVALID and nonlaunchable even when its independently scanned journal
correctly reports STARTED and the same retry pair.

The 2026-08-02 installer foundation promotes the read-only validator into
resident STR8-N as `STR8_DIR_VALIDATE_BANK_A` and
`STR8_DIR_SCAN_JOURNAL`. The compiled
`$0118`-byte implementation shares the record parser's serial zero-page work
set, performs no bank selection, and cannot mutate flash. It returns the exact
EMPTY, INCOMPLETE, COMPLETE, or INVALID record state plus the next/retry journal
pair.

`make -C SRC str8-directory-check` executes the compiled 65C02 validator from
the guarded V1 preview across all 94 journal fixtures and 33 record fixtures,
in addition to the independent host reference model.

The 2026-08-05 slice adds `STR8_DIR_WRITE_BYTES`, the dedicated Bank-3
directory one-to-zero writer. It accepts only `$FFB0-$FFEF`, lengths 1-64,
preflights the complete request before calling RAM-worker mode `$07`, and
verifies the complete request afterward. Mode `$07` independently selects
Bank 3 and repeats the whole-request one-to-zero preflight before its first
flash-program call. Thus a later illegal byte cannot leave earlier bytes
partially programmed, even if the resident preflight observed the wrong bank.

The independent model classifies all 65,536 old/new byte pairs as 6,561 legal
and 58,975 illegal. The compiled writer passes 77 cases covering the 64-byte
boundary, range/count rejection, idempotent data, later-byte atomic rejection,
worker failure and readback mismatch tuples, all 16 START transitions, all 16
COMPLETE transitions, and attempted journal rollback. The linked worker gate
also verifies that the second pointer initialization and complete preflight
precede its first flash-write call.

The writer is compiled only into the guarded V1 layout preview. No `I` command
or other resident command reaches it, the normal legacy firmware does not
contain it, and the preview emits no install S19, TopWriter, or stamped image.
Consequently this is host acceptance, not an onboard flash test. The normal
legacy image retains hardware-proven fixed `$C000-$EFFF` `U`; the guarded V1
preview later retires that command. Image-sector mutation remains disabled.

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

The V1.01 prompt is:

```text
I 0-3 J0-3
```

The normal legacy image prints
`U 0-3 J0-3`. The guarded V1 preview prints the final surface above: `U`,
`G`, and `R` are absent, and `I` accepts Bank 0-3. During the dry
preflight slices it ends with `NO WRITE`; no flash mutation is reachable.

There is no `?` command. The identity is printed when STR8-N enters its menu;
any command that does not match the active command set prints the help line.
`I` prompts for Bank 0-3, installing 32K into Banks 0-2 or 28K into the Bank-3
payload. Bare `0` through `2` immediately reuse the corresponding bank
handoff; bare `3` enters the Bank-3 payload warmly. `J0` through `J3` remain
the explicit non-destructive handoffs, with `J3` retaining STR8 re-entry.

The destructive V0 meanings of `B` and bare prompt `0`, `1`, or `2`, plus the
separate `G`, `R`, and fixed 12K `U` updater, are retired in V1. The bare
digits are repurposed only as safe selector aliases. `B` remains reserved for
the future external S19 backup generator. Unknown worker modes must fail
explicitly and must never fall through to an old copy operation.

Command and prompted input use a small shared line editor:

- Printable lowercase is folded before echo, so echoed input is uppercase.
- Backspace and Delete remove the previous buffered character and update the
  display.
- CR, LF, and CR/LF terminate a line consistently.
- An empty line is a negative or abort response.
- Confirmation succeeds only for `Y`; every other response aborts.

The 2026-08-05 Part-1 preview replaces the V1 single-character reader with
the shared editor while leaving the legacy firmware reader unchanged. It uses
the existing `$7B00` record buffer transiently, folds before echo, renders
Backspace/Delete as erase sequences, zero-terminates the result, and consumes
exactly one deferred LF after CR. The S19 console reader shares that deferred-
LF path so a CR/LF confirmation cannot leak its LF into the following stream.

The compiled host gate covers uppercase folding, Backspace, Delete, CR, LF,
CR/LF, maximum-length rejection, empty input, valid Bank 0-2 `I` preview, and
invalid/empty bank responses. It also executes lowercase `Y`, `N`, and empty
confirmation lines and requires carry only for `Y`. All twelve compiled cases
pass. Every `I` case leaves the directory unchanged and makes no RAM-worker
call.

Part 2 extends the same non-mutating `I` shell to Bank 0-3. Empty records
prompt for a two-digit TYPE and exactly five valid DESCRIPTION characters;
existing records publish their immutable metadata instead. The preview prints
the exact `$8000-$FFFF` or `$8000-$EFFF` extent, directory state, next/retry
journal pair, and an existing Bank-3 LOCAL ENTRY. Invalid records, exhausted
journals, invalid TYPE, invalid DESCRIPTION, and empty/invalid bank responses
fail closed. Twenty-one compiled editor/confirmation/command/`I` cases pass,
including `?` and another unknown byte producing the complete help line, and
EMPTY, INCOMPLETE, COMPLETE, FULL, and INVALID records. Every `I` case verifies
an unchanged directory and zero RAM-worker calls. No directory write, journal
transition, S19 receive, erase, or program path is reachable.

The STR8-N version line contains no guessed bank suffix:

```text
STR8-N V 00.xxxx(xxxx)
```

The binary marker bytes `7A 0F 6A 5F` remain in ROM for image recognition;
they are not operator-facing banner text.

## `I` Operator Flow

For an empty directory record, `I` prompts separately for:

```text
BANK 0-3
TYPE, two hex digits
DESCRIPTION, exactly five characters
FINAL INSTALL CONFIRMATION
```

For an existing record, `I` displays and validates the immutable TYPE,
DESCRIPTION, and Bank-3 LOCAL ENTRY instead of accepting replacements.

The initial `Y` is the final destructive confirmation. After it, STR8-N writes
and verifies the journal START transition and then requests the S19 stream.
Sending the S19 begins sector mutation; there is no later post-receive erase
confirmation.

Persistent installer state that must survive worker calls occupies the
17-byte transient user-ZP frame `$0090-$00A0`. STR8 owns that frame only while
the foreground recovery transaction is active. It does not overlap worker
zero page `$00CD-$00D6`, the worker state board `$1FE9-$1FFF`, or transient
command-reader state.

The installer uses:

```text
$0090-$00A0  persistent installer state during I
$0200-$09FF  RAM worker-code tray
$0A00-$19FF  one full 4K staged sector
$7B00-$7BFB  existing validated S19 record buffer
$7E95-$7EA8  existing record request/result card
```

## RAM S19 Loading Stays In HIMON

`I` never offers RAM as a destination. At its command boundary it always means
a persistent, journaled flash transaction for the selected Bank 0-3. Internal
RAM staging does not change that operator contract.

HIMON retains the existing RAM-load interface. `L` validates an S19 stream and
loads its S1 data into permitted RAM; `L G` performs that load and then enters
the validated S9 address. Those operations do not erase flash. HIMON may use
STR8's shared record parser, but RAM destination policy and the operator-facing
commands remain in HIMON. The separate compatibility command `L F` remains a
flash path and is not a synonym for `L` or `I`.

## Dense V1.01 S19 Contract

V1.01 accepts only a dense, canonical S19 stream:

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
I, Banks 0-2  exactly $8000-$FFFF
I, Bank 3     exactly $8000-$EFFF
```

For Banks 0-2, the S9 address must equal the staged reset vector at
`$FFFC/$FFFD`. A vector and S9 of `$FFFF` are permitted for a deliberately
nonlaunchable data bank. A launchable vector must point within `$8000-$FFFF`.

For Bank-3 `I`, S9 is the immutable LOCAL ENTRY. It must be within `$8000-$EFFF`,
or exactly `$FFFF` for a deliberately nonlaunchable payload.

V1.01 has no whole-image CRC. Integrity comes from every S-record checksum, exact
dense coverage, strict ordering, final-entry validation, full-sector read-back
verification, and the install journal.

### 2026-08-05 Compiled Dry Receiver/Stager

`make -C SRC str8-installer-dry-check` builds a separate
`STR8_V1_INSTALLER_DRY` S19 and executes its linked 65C02 `I` receiver. This
image is a host proof only: the sector-ready hook returns without invoking the
worker, no flash or directory byte can change, and it is not combined with the
stored worker or emitted as a migration artifact.

The compiled positive cases consume an optional-S0 32K Bank-2 stream in
251-byte records and a no-S0 28K Bank-3 stream in 193-byte records. Both force
S1 records across 4K boundaries, byte-compare every staged sector, hold the
final sector until S9, and validate the reset-vector or LOCAL ENTRY rule. The
negative matrix covers an initial gap, zero-length S1, early S9, reset/S9
mismatch, invalid and immutable-mismatch Bank-3 entries, duplicate S0, parser
checksum failure, and queued bytes after S9. All eleven installer cases pass.

The accepted flash-layout preview remains unchanged:

```text
resident                   $F000-$FC00  size $0C01 = 3073
resident/worker gap         $FC01-$FD1E  size $011E = 286
stored worker               $FD1F-$FFAF  size $0291 = 657
directory                   $FFB0-$FFEF  size $0040 = 64
configuration/vectors       $FFF0-$FFFF  size $0010 = 16
room beyond $0040 floor                    $00DE = 222
```

The deliberately standalone dry receiver measures:

```text
dry resident                $F000-$FDF7  size $0DF8 = 3576
growth over preview                        $01F7 = 503
would overlap worker        $FD1F-$FDF7  size $00D9 = 217
fit debt including $0040 gap               $0119 = 281
```

It stays below the `$FFB0` directory, but cannot coexist with the current
worker. Step 2 may reuse the proof while implementing the transaction, but no
flashable V1 artifact exists until resident/worker fit is closed.

### 2026-08-05 Compiled Journaled Mutation Transaction

`make -C SRC str8-installer-transaction-check` builds the separate guarded
`STR8_V1_INSTALLER_TXN` host proof. Confirmation changes to `WRITE? Y:`. The
resident writes and verifies journal START first, writes immutable metadata for
an empty record, streams each accepted sector through worker mode `$05`, and
publishes a Bank-3 LOCAL ENTRY and the seal before writing COMPLETE last.
Failures return `I FAIL $10/$12` for receive/worker failures or the directory
writer's status after `DIR FAIL`; no failure path writes COMPLETE.

The compiled gate covers full Bank-2 32K and Bank-3 28K transactions with exact
flash and directory comparisons and exact persistent-event ordering. It also
injects failures at START, metadata, every `$8000-$F000` sector boundary,
Bank-3 entry, seal, and COMPLETE; proves completed records advance to the next
pair; and proves sealed INCOMPLETE records retry the same pair idempotently.
The combined dry/transaction matrix reports 38 installer cases. A first-install
record interrupted before its seal remains structurally INVALID and
nonlaunchable, while its journal independently retains STARTED; interactive
recovery of that provisional record is outside this slice.

The transaction build is deliberately standalone and measures:

```text
transaction resident        $F000-$FF36  size $0F37 = 3895
growth over dry                             $013F = 319
would overlap worker         $FD1F-$FF36  size $0218 = 536
fit debt including $0040 gap                $0258 = 600
room before directory        $FF37-$FFAF  size $0079 = 121
```

It remains below the immutable `$FFB0` directory boundary, but cannot coexist
with the current `$FD1F-$FFAF` worker. No V1 migration S19, TopWriter, stamped
ROM, or board-test candidate is emitted until that fit debt is closed.

### 2026-08-06 Current Fit-Closure Ledger

Six isolated size passes now follow the original transaction proof. Moving the
17-byte installer state frame to `$0090-$00A0` reclaimed `$0047` transaction
bytes. Replacing 40 repeated fixed-message page loads with two map-guarded
page helpers reclaimed another `$004A`. Removing four page loads overwritten
by those helpers reclaimed `$0008` more. Omitting the transaction-dead menu,
screen, legacy `U` success path, and `OK` string reclaimed another `$001A`.
Reusing the bank shift's known clear carry and tail-calling the carry-setting
sector-dot writer reclaimed `$0003` more. Sharing one normalized failure carry
and removing three branch-redundant clears reclaimed another `$0004`. Together
they remove `$00BA` = 186 bytes without changing the worker or transaction
semantics.

```text
normal resident             $F000-$FAF6  size $0AF7 = 2807
V1 preview resident         $F000-$FBDC  size $0BDD = 3037
dry resident                $F000-$FDBF  size $0DC0 = 3520
transaction resident        $F000-$FE7C  size $0E7D = 3709
transaction/worker overlap  $FD1F-$FE7C  size $015E = 350
fit debt including $0040 gap               $019E = 414
room before directory       $FE7D-$FFAF  size $0133 = 307
stored worker               $FD1F-$FFAF  size $0291 = 657
```

The transaction remains a host proof only. Fit closure must remove at least
350 more physical-overlap bytes, or 414 bytes while retaining the frozen
`$0040` development reserve, before generating a flashable migration image or
starting the V1 transaction board ladder.

### 2026-08-06 Split-Worker Fit Closure

The later three-slice resolution replaces the monolithic stored worker with a
permanent 136-byte jump worker and a transaction-uploaded 555-byte mutation
worker. The flashable resident copies only `$FF28-$FFAF` to `$0200-$0287`.
Using the sub-page copy path also reclaims 16 resident bytes. The resulting
resident ends at `$FEC3`, leaving `$0064` before the packed worker and `$0024`
beyond the required `$0040` reserve. The directory remains exactly
`$FFB0-$FFEF`.

`make -C SRC str8-v1-artifact` emits the candidate BIN, ordinary install S19,
one-file mutation-worker-plus-bank `I` stream, and a self-contained migration
TopWriter under `SRC/BUILD`. Fit is closed; hardware acceptance now follows
`DOC/GUIDES/STR8/STR8_V1_MIGRATION_BOARD_TEST.md`.

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

For Bank-3 `I`:

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
6. On the first Bank-3 `I`, write and verify LOCAL ENTRY.
7. On first install, write and verify seal `$FE`.
8. Write and verify journal COMPLETE last.

On syntax, checksum, order, coverage, range, transport, S9, flash, or verify
failure, STR8-N stops target programming and leaves the journal incomplete. It
asks the operator to stop the sender or issue Ctrl-C, then drains and waits for
a defined idle boundary. Queued S19 input must never become STR8-N commands.

## Mandatory Dense Transport Proof

The dense 32K and 28K FTDI forms both passed on 2026-07-31. Every other
physical receive path remains separately unqualified.

The existing three-sector HIMON updater is useful evidence, but it receives its
entire 12K S19 into RAM before programming. It therefore does not prove that
the host, terminal, FTDI path, and receive FIFO tolerate the no-read intervals
created when the new installer programs a sector during an active stream.

Before real `I` erasure is enabled, a RAM-only proof
must:

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

### 2026-07-31 Windows Tera Term/FTDI 28K Result

The separate RAM proof accepted the dense `$8000-$EFFF` Bank-3 transport
shape while using Bank 0 only as a disposable real-flash timing sink. Every
S1 data byte was `$5A`. It programmed sectors `$8000-$DFFF` during reception,
held `$E000-$EFFF` until S9 `$8000` validated, then programmed and verified
that final sector. Bank 0 sector `F` and all of Bank 3 remained untouched by
the proof code.

```text
SEND STR8-28K-5A-8000-EFFF.S19 NOW
....... 7 SECTORS ERASED/PROGRAMMED/VERIFIED
RET A=AC X=84 Y=25 P=F5 S=FD NV-BdIzC
```

A post-test 128K T48 readback independently contains exactly `$5A` at the
Bank-0 physical range `$00000-$06FFF` and `$00` at `$07000-$07FFF`, matching
the 28K run after the earlier full-bank zero proof. The complete readback has
SHA-256
`746AF1572F5E2AD4D121C683BDA65DCBCC76B7EFAFED5E58998A9E5D95A52772`.
The detailed transcript and per-bank recovery hashes are recorded in the
hardware test log.

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

The guarded preview implementation is now host-accepted. Its resident wrapper
rejects zero or overlong requests and every address outside `$FFB0-$FFEF`,
captures the first address/observed/expected tuple for byte-specific failures,
and requires exact readback. The RAM worker repeats the full transition
preflight after selecting Bank 3. It is intentionally not command-reachable
and is not present in the legacy flashable STR8 image.

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

The transitional source now uses shared `STR8_BANK_COUNT=$04` in STR8, its RAM
worker, and HIMON cold-clear preservation. This accepts record banks `$00-$03`
and prevents the pre-J3 `<3` preservation bound from returning. The compiled
host gate passes. HIMON `00.0802(1536)` preserves `42 4A 03` through both the
J3 cold entry and an explicit `HCOLD`, accepting the corrected Bank-3 path on
hardware. The broader record matrix remains a separate gate.

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
mode. `make -C SRC str8-worker-mode-check` executes the compiled dispatcher
prefix for all 256 byte values: `$05-$08` must reach their exact entry points,
and all other 252 values must return carry clear before calling any operation.

The `STR8-N V 00.0801(2234)` board proof installed the reclaimed image through
TopWriter, confirmed that `B` and bare `0`, `1`, and `2` all return `?`, and
ran a RAM fixture across all 252 unrecognized mode bytes. The fixture returned
`A=$AC`, carry set, with its four-byte failure record still zero. This accepts
the reclaim slice.

The same capture invoked reset-time Bank 2 and resident `J2` and `J1`, but it
does not prove a sustained guest boot. Banks 1 and 2 contain a STR8-bearing
image with reset vector `$F000`; after each `J Bn`, the next visible banner is
Bank-3 `00.0801(2234)`. The selected image's STR8 initialization writes the
Bank-3 PCR value before printing, so it remaps Bank 3 immediately. This is a
regression from the earlier hardware-proven opaque-bank behavior, not an
accepted guest contract. Current source removes that unconditional write and
leaves the selected bank unchanged. Repaired `00.0802(1323)` is installed, and
a later full Bank-3-to-Bank-2 copy retained the distinct older Bank-2 HIMON
`0731` payload through reset-selector `2` and cold entry after Bank 3 had been
updated to HIMON `1334`. This accepts sustained Bank-2 startup. The same
direct-run utility also completed a verified Bank-3-to-Bank-1 copy, but Banks
1 and 3 shared the `1334` identity in that capture. A later no-hash Bank-3
`1404` install made the older Bank-1 `1323/1334` and Bank-2 `1323/0731`
payloads independently distinguishable; the cross-bank selector routes retained
Banks 1 and 2. Resident `J1` and `J2` were then self-target tests from those
already-selected banks, not cross-bank direct-J proof. The same utility also
completed a verified Bank-3-to-Bank-0 copy. Because Banks 0 and 3 were then
byte-identical, that capture alone did not prove Bank-0 persistence. A terminal
continuation later crossed directly from an old `1323` bank through `J0` into
Bank-0 `1404`, independently accepting Bank 0, and crossed from a `1404` bank
through direct `J2` into Bank-2 `1323`. A later 16-dot run crossed from
distinct Bank-0 `1404` through `J1` into a `1420/1425` image, but Banks 1 and
3 were exact copies at that point; it therefore does not independently prove
that Bank 1 remained selected. The following direct `J2` reached distinct
Bank-2 HIMON `1404` and reconfirmed that destination. Cross-bank direct `J1`
was then closed with four distinct bank identities: Bank-2 STR8 `1420` issued
`J1`, reached Bank-1 STR8 `1440`, and warm-entered its local HIMON `1440`,
while Bank 3 had already advanced to STR8/HIMON `1452`. Cross-bank direct
`J0/J1/J2` and sustained Bank-0/1/2 execution are accepted. The later V1
directory, installer, migration, persistent bank handoff, and complete
`$05-$08` acceptance gates remain open.

The transitional host image now also accepts `J3` through the same RAM worker,
providing an explicit software return from a copied STR8 to Bank 3 before the
directory manager lands. Its range/table and normal/RAM builds pass. The
installed parser and a Bank-0 functional handoff smoke also pass, but the
first source and target images were identical. The follow-up entered Bank-0
STR8 `1509`, issued `J3`, and reached distinct Bank-3 STR8/HIMON `1518`; the
transitional J3 path is board-accepted. The later V1 work still must
directory-gate `J0-J3` and replace this raw Bank-3 reset-vector return with the
published local entry.

The fitted transaction image now closes the interruption-critical portion of
that gate: `J0-J2` call the compiled validator while Bank 3 is visible and
reach the jump worker only for a COMPLETE record. EMPTY, INVALID, and
INCOMPLETE records fail closed through the existing `JERR Bn V=$0000`
diagnostic. Five compiled-image fixtures cover those three failures, a
COMPLETE Bank-2 launch, and the deliberate transitional `J3` exception. The
resident is `$F000-$FED4`, leaving `$0053` before the packed jump worker and
`$0013` beyond the protected `$0040` reserve. Hardware proof remains pending.
Directory-gating `J3` and replacing its raw reset-vector return with the
published local entry remain a separate later slice.

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

The generated V1 artifacts now separate those two jobs. The one-time
`str8n-v1-topwrite-transient-3000.a` migration writer still uses the embedded
empty directory. Once V1 is installed,
`str8n-v1-refresh-transient-3000.a` copies the live `$FFB0-$FFEF` bytes into
its embedded RAM image before staging, so its existing full-stage verifier and
programmer carry the exact directory through a Bank-3 top-sector refresh. The
refresh source consumes all 64 ASM-F2 symbols and must not be used as the
first old-layout-to-V1 migration writer.

The explicit `str8-v1-negative-streams` target now emits two board-only S19
fixtures. `str8-v1-i-bad-worker-id.s19` changes one checksummed identity byte
and ends before START; it must report `$15` without touching the directory.
`str8-v1-i-interrupt-after-start.s19` contains the exact mutation worker and
only the first `$8000` payload record. That record causes START, but cannot
complete a 4K sector; the receiver then blocks for the next record until the
operator resets. Neither fixture contains S9. These artifacts are never part
of the ordinary install target.

The bad-worker fixture is hardware-accepted on refreshed Bank 3
`00.0806(1900)`: it returned `$15`, left the Bank-2 pair-1 journal COMPLETE at
`FC`, and did not prevent `J2` from launching Bank 2. The post-START physical
reset is also hardware-accepted: `J2` failed closed with `V=$0000`, the
installer rediscovered `INCOMPLETE P=01`, and the journal read back as `F8`.
The same-pair retry is hardware-accepted through eight sector writes, `I OK`,
the pair-1 COMPLETE `F0` journal, and launch of the new Bank-2 image. A final
physical reset returned Bank 3 `00.0806(1900)` and retained the exact `F0`
journal, closing the negative/interrupted same-pair recovery board slice.

An externally programmed full Bank-3 image can overwrite the directory. That
is an explicit full-image operation, not an `I3` payload installation.

## Current Size Baseline and Budget

The accepted preimplementation host build reported:

```text
STR8 resident code/data  $F000-$FAEE  size $0AEF = 2799
stored worker            $FD03-$FFEF  size $02ED = 749
resident/worker gap      $FAEF-$FD02  size $0214 = 532
```

The first V0 reclaim slice removed `B`, bare `0/1/2`, their resident clients,
and worker copy/restore modes `$00/$01/$03`. It retained `U`, `G`, and worker
modes `$05-$08`. The 16-dot attach countdown adds 31 resident bytes. Immediately
before resident validator promotion, the guarded V1 preview reported:

```text
STR8 resident code/data  $F000-$FA0A  size $0A0B = 2571
stored worker            $FD53-$FFAF  size $025D = 605
resident/worker gap      $FA0B-$FD52  size $0348 = 840
```

With the compiled `$0118` read-only validator, `$00A2` directory writer, and
the strengthened `$027F` worker present, the writer-only guarded V1 preview
reported:

```text
STR8 resident code/data  $F000-$FBA4  size $0BA5 = 2981
stored worker            $FD31-$FFAF  size $027F = 639
resident/worker gap      $FBA5-$FD30  size $018C = 396
required post-I reserve                 $0100 = 256
current room beyond floor               $008C = 140
```

The compact buffered editor and non-mutating Part-1 `I` Bank 0-2 preview
consumed that remaining `$008C` exactly:

```text
STR8 resident code/data  $F000-$FC30  size $0C31 = 3121
stored worker            $FD31-$FFAF  size $027F = 639
resident/worker gap      $FC31-$FD30  size $0100 = 256
required post-I reserve                 $0100 = 256
current room beyond floor               $0000 = 0
```

The 2026-08-05 unified-command decision permits the installer to use most of
that policy reserve while keeping `$0040` for board-test corrections. V1
retires the fixed `U` backend/messages and `G`, then adds Bank 0-3 selection,
TYPE/DESCRIPTION validation, immutable-record display, exact range display,
and directory state/pair preflight. The resulting Part-2 preview is smaller
than Part 1:

```text
STR8 resident code/data  $F000-$FBF6  size $0BF7 = 3063
stored worker            $FD31-$FFAF  size $027F = 639
resident/worker gap      $FBF7-$FD30  size $013A = 314
required development reserve          $0040 = 64
current room beyond floor              $00FA = 250
```

The `$0040` floor is a policy reserve, not hardware spacing. It may be consumed
later if the completed, measured installer cannot otherwise fit; resident code
still must never overlap the worker.

The published `$F010`/`$0203` bank-selection service and unknown-command help
follow-up produce this current preview:

```text
STR8 resident code/data  $F000-$FC00  size $0C01 = 3073
stored worker            $FD1F-$FFAF  size $0291 = 657
resident/worker gap      $FC01-$FD1E  size $011E = 286
required development reserve          $0040 = 64
current room beyond floor              $00DE = 222
```

The 2026-08-01 host preflight now enforces this future layout on every normal
combined-ROM build while leaving the legacy top-sector layout selected. The
accepted preflight output is:

```text
V1 PREFLIGHT WORKER       = FD1F-FFAF/291 (not emitted)
V1 PREFLIGHT DIRECTORY    = FFB0-FFEF/40 (not emitted)
V1 PREFLIGHT RESERVE      = FB2B-FD1E/1F4 (min 40)
V1 PREFLIGHT CONFIG/VECT  = FFF0-FFFF unchanged
```

The normal builder emits the current worker at `$FD5F-$FFEF`; it does
not reserve directory bytes or alter TopWriter output. The separate guarded
target:

```text
make -C SRC str8-v1-layout-preview
```

builds `BUILD/bin/himon-str8-v1-layout-preview.bin` with the worker at
`$FD1F-$FFAF` and all 64 directory bytes at `$FFB0-$FFEF` equal to `$FF`.
It uses a separately assembled STR8 image whose worker-copy constant matches
`$FD1F`. The preview target is not part of `all`, `firmware`, or `release`; it
does not produce an install S19, TopWriter, or stamped ROM image. It is not a
flashable migration artifact. Actual onboard V1 layout installation remains
gated on the explicit migration path and directory-preserving later TopWriter
behavior.

The V1 command surface is now frozen at `I`, `J0-J3`, and `R`. The normal
legacy image still retains its proven `U` and `G`; only the guarded V1 preview
retires them. Directory-gated `J0-J3` remains a later functional gate.

The gross installer estimate remains 700-1100 bytes. The build gate, not the
estimate, decides acceptance. If the first implementation is too large, it is
optimized before removing existing compatibility services. Removing HIMON's
current `L F` compatibility adapter is a separate decision, not an automatic
size action.

Persistent new data is expected to be:

```text
Bank Directory                    64 flash bytes
installer state                   17 transient ZP bytes in $0090-$00A0
sector staging                    existing 4096-byte tray
validated record staging          existing 252-byte tray
```

## Future `I` Sector-Range Installer Consideration

This is a candidate extension for further consideration, not a change to the
frozen full-bank/Bank-3-payload V1.01 contract. It would let `I` replace
one or more complete 4K erase sectors while leaving every sector outside the
selected S19 extent unchanged:

| Command | Target | Candidate dense extent | Sector count |
| --- | --- | --- | --- |
| `I` | Banks 0-2 | Any 4K-aligned range within `$8000-$FFFF` | 1-8, or 4K-32K |
| `I` | Bank 3 | Any 4K-aligned range within `$8000-$EFFF` | 1-7, or 4K-28K |

The first S1 data address may supply the range start. It must be exactly a 4K
boundary (`$8000`, `$9000`, and so on). S1 data must then be strictly
increasing, contiguous, and dense through S9. The final address plus one must
also be a 4K boundary, giving an exact 4K multiple. Zero-length records, gaps,
overlaps, duplicates, backward records, and out-of-range bytes are rejected.
Explicit `$FF` bytes mean erase that part of the selected sector; an omitted
address never means preserve an old byte inside the selected range.

This permits examples such as:

```text
I Bank 2  $8000-$BFFF  four-sector / 16K ASM replacement
I Bank 1  $C000-$EFFF  three-sector / 12K payload replacement
I Bank 0  $F000-$FFFF  one-sector / 4K top-image replacement
I Bank 3  $8000-$8FFF  one-sector / 4K payload replacement
I Bank 3  $8000-$EFFF  seven-sector / 28K payload replacement
```

Ordinary Bank-3 range installation still rejects `$F000-$FFFF`. Replacing the
Bank-3 supervisor, worker store, directory, configuration, or vectors belongs
only to the separately considered expert top-sector path. That path must stage
the complete 4K sector, preserve the live directory by default, validate STR8
and all vectors, write sector F last, and retain the external-recovery warning.

Plain S19 has an important confirmation limitation: the first S1 reveals the
start, but the receiver does not know the final extent until S9 arrives. A
streaming installer may already have programmed earlier complete sectors by
then. The current one-sector RAM design can hold the final sector until S9 and
reject a bad final boundary without marking the journal complete, but it cannot
retroactively restore earlier sectors.

The first safe implementation should therefore use one of these range-
declaration gates:

1. Prompt for the expected sector range before requesting S19, then require the
   first S1 and S9-derived extent to match it exactly. This is the recommended
   initial form.
2. Define a canonical STR8 S0 manifest containing bank-independent start and
   end/length, receive that header in a separate preflight phase, display and
   confirm the detected range, then request the dense S1/S9 body.
3. A broad `WRITE Bn RANGE FROM S19` confirmation that discovers the final
   extent only during mutation is technically possible but remains deferred
   because it does not show the operator the exact range before the first
   erase.

### RAM-Batched Receive/Commit Option

Resident STR8-N executes from Bank-3 flash and uses its own FTDI routines, so
an `I` transaction may deliberately consume RAM that belongs to HIMON,
ASM, or the user outside recovery mode. This is materially different from the
direct-run `$2000` maintenance program. A simple sector-pool layout is:

```text
$0090-$00A0  transient installer state during I          17 bytes
$0200-$09FF  RAM worker tray; not an image buffer
$0A00-$19FF  sector buffer 0                         4K
$1A00-$1FE8  optional scatter tail; currently free during I
$1FE9-$1FFF  worker/STR8 state; never image data
$2000-$2FFF  sector buffer 1                         4K
$3000-$3FFF  sector buffer 2                         4K
$4000-$4FFF  sector buffer 3                         4K
$5000-$5FFF  sector buffer 4                         4K
$6000-$6FFF  sector buffer 5                         4K
$7000-$7AFF  optional scatter tail
$7B00-$7BFB  active decoded S19 record tray; not persistent image data
$7E00-$7EFF  HIMON/STR8 service, result, IVY, and vector state; preserve
```

The six directly programmable trays hold 24K. STR8 can receive and validate a
dense image into those trays before erasing any target sector. Images of 4K
through 24K therefore need no receive/program repetition: after S9, STR8 knows
the exact extent, displays it, obtains final confirmation, writes journal
START, and commits the staged sectors.

A 28K image can also fit before mutation if the seventh sector is split across
`$1A00-$1FE8` and `$7000-$7AFF`; the installer state remains separate in its
transient ZP frame. After S9 validation and confirmation, STR8 programs one of
the six contiguous trays, repacks the scattered seventh sector into the freed
4K tray, and writes it last. This more complex path needs explicit host mapping
tests to prove that no worker-state or parser byte can alias image data. It
would allow the complete Bank-3 28K payload to be validated before the first
flash erase.

A dense 32K image cannot coexist in RAM with the CPU stack, worker, installer
state, S19 record tray, IVY/service state, and I/O page. Banks 0-2 therefore
still require at least two receive/commit batches. A practical first schedule
is six sectors (24K), followed by the final two sectors (8K), with sector F held
until S9 and reset-vector validation.

Batching changes the transport proof. Consuming 24K before a flash pause
reduces the number of pauses, but programming six buffered sectors creates a
longer interval in which the target reads no serial bytes. The existing FTDI
per-sector proof does not automatically qualify that longer pause, and an ACIA
remains unsupported. Before accepting batching, repeat dense 28K and 32K
tests with one of these explicit profiles:

- an FTDI/USB path proven to retain or backpressure the remaining stream for
  the complete batch-program interval;
- a paced sender that transmits one announced batch and waits for `NEXT`;
- XON/XOFF or hardware flow control proven to stop before flash begins; or
- a documented line-delay profile that passes repeated real-flash tests.

The batch state must record the expected flash sector for every RAM tray.
STR8 validates the whole batch before journal START or, for later batches,
before changing another sector; programs and verifies each related sector;
then marks those trays free and resumes S19 reception. After RAM staging, the
transaction is not warm-return compatible: completion or abort reinitializes
RAM and returns through a defined STR8 cold path.

For a range package, S9 may be `$FFFF` or an entry within the transmitted
range. It is component transport metadata and never overrides a Bank-0/1/2
reset vector. A Bank-3 directory LOCAL ENTRY remains immutable after first
installation; later component packages do not silently replace it. A partial
installation into an otherwise empty bank may complete as a valid data bank
while `J` still refuses an erased or invalid launch vector.

The existing install journal remains bank-wide. The selected `I` operation
writes START before the first selected sector changes, making the
bank nonlaunchable during a range update, and writes COMPLETE only after every
selected sector passes full read-back verification. This extension is dense
over its declared range; it is separate from the future sparse-S19 format
below.

## Sparse S19 Is a Future Enhancement

Sparse S19 is explicitly outside V1.01. The dense transport proof and dense
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
   directory, and development reserve build gate (now `$0040`).
3. Add directory constants, structural validation, journal scanning, and the
   dedicated one-to-zero directory writer.
4. Replace single-character prompt input with the uppercase buffered editor,
   consolidate Bank 0-3 installation under `I`, retire V1 `U`/`G`, and freeze
   the V1 command surface.
5. Implement dense S19 installer state, exact coverage checks, sector splitting,
   streaming sector writes, S9 gates, and failure drain behavior. The receive,
   dry-stage, S9, drain, and guarded journaled-mutation slices are host-accepted;
   first-install provisional-record recovery and resident/worker fit closure
   remain open.
6. Gate `J0-J2` through directory state (host-accepted; hardware pending), then
   gate `J3`, add the Bank-3 local-entry handoff, and retain Bank Jump Record
   publication through Bank 3.
7. Generate the one-time migration TopWriter and make every later TopWriter
   preserve the live directory exactly.
8. Complete host, RAM, and board failure tests before accepting the installer.

## Acceptance Gates

V1 is accepted only when:

- Host build and all address, ABI, and size assertions pass.
- At least `$0040` contiguous resident/worker development space remains.
- Every legal journal state and representative torn/illegal state is tested.
- Dense S19 checksum, order, coverage, boundary-crossing, S9, and trailing-data
  tests pass.
- Backspace, Delete, uppercase echo, CR, LF, CR/LF, and empty-abort behavior
  pass.
- The dense 32K and 28K transport-with-pauses proofs pass for the supported
  FTDI terminal profile. Both forms passed on 2026-07-31.
- Any claimed ACIA support has its own documented pacing/flow-control profile
  and passes both dense proofs; otherwise ACIA remains explicitly unsupported.
- Power interruption at every transaction stage leaves the target
  nonlaunchable until a successful retry completes.
- The final sector is never programmed before S9 validation.
- `J0-J3`, Bank Jump Record publication, and physical-reset recovery pass.
- A normal TopWriter preserves all 64 live directory bytes exactly.
- Every bank not selected for installation remains byte-for-byte unchanged.
