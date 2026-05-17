# QCC STR8

This page keeps STR8 and future STR8-N/STRAIGHTEN questions in QCC form.

## Q: Does STR8 own memory and interrupts?

Comment: The current direction is no. STR8 should be useful in systems where
the user already has memory policy, vector policy, and interrupt layering.
STR8 can cooperate with R-YORS layers, but it should not require ownership of
all RAM, all vectors, or all interrupt behavior.

Concern: STR8 still needs enough reserved workspace and safe entry rules to do
recovery/update work. That reservation should be explicit in the memory map.

## Q: What does STR8 own?

Comment: STR8 owns recovery/update guardrails:

```text
safe boot path
image validation
flash rewrite boundaries
protected recovery window
handoff to HIMON
future condense/compress calls
```

Concern: Normal interactive monitor behavior belongs to HIMON. STR8 should not
grow into a second full monitor by accident.

## Q: How should STR8 treat a factory WDCMONv2 image?

Comment: The preferred recovery story is full-bank preservation, not clever
partial reconstruction. If a stock board arrives with WDC code in the
`$8000-$FFFF` flash window and WDCMONv2 near the top of ROM, STR8 should first
preserve that default image as a complete 32K bank before R-YORS becomes the
live boot image:

```text
Bank 0  WDC factory/base image, B0 HOLD
Bank 1  older R-YORS backup
Bank 2  newer R-YORS backup
Bank 3  live boot image
```

"Purge WDCMONv2" should mean "remove it from the live boot bank after a
verified factory image has been stashed," not "erase the only copy." A restore
from Bank 0 can deliberately return the board to WDC-style behavior. The
operator warning should be loud because restoring Bank 0 may remove R-YORS from
the ordinary live image.

Concern: Coexistence is possible only when the address ranges and vectors do
not fight. Current R-YORS STR8 owns the `$F000-$FFFF` top sector; a stock
WDCMONv2-at-`$F800` image cannot coexist with that layout in the same live bank
without either moving/relinking something, preserving WDCMONv2 in another bank,
or letting WDCMONv2 remain the boot owner.

## Q: What kind of WDCMONv2 bridge should R-YORS build?

Comment: A vector-only bridge is attractive because the final hardware vectors
are tiny:

```text
$FFFA-$FFFB  NMI
$FFFC-$FFFD  RESET
$FFFE-$FFFF  IRQ/BRK
```

Changing those six bytes can choose which monitor receives reset, NMI, and
IRQ/BRK, but only if the code bodies for both choices already exist at
non-overlapping addresses. The vectors pick an entry point; they do not make
two different programs fit at the same address.

Current conflict:

```text
STR8 current top sector  $F000-$FFFF
WDCMONv2 possible body   $F800-$FFFF
```

If WDCMONv2 really occupies `$F800-$FFFF`, and STR8 also stores code/worker
material there, a vector-only switch cannot make the board be WDCMONv2 one
moment and R-YORS the next inside the same live bank. One image must move, be
stashed in another bank, or be restored by a fuller transaction.

Possible bridge shapes:

```text
vector-only bridge:
  both monitor bodies already present
  non-overlapping code ranges
  vectors select the active entry

shared top-sector trampoline:
  tiny stable reset owner remains fixed
  trampoline selects WDCMONv2 or STR8/HIMON
  requires planned top-sector layout

full top-sector transaction:
  stage $F000-$FFFF in RAM
  merge desired monitor/top-sector bytes
  preserve or rebuild config/vectors
  erase/write/verify the full sector

full-bank restore bridge:
  preserve WDCMONv2 as a complete Bank 0 image
  restore Bank 0 -> Bank 3 for WDC mode
  reinstall or restore R-YORS for R-YORS mode
```

Concern: The vectors live inside the same `$F000-$FFFF` erase sector as the
top monitor code. Flash can clear bits from `1` to `0` without erase, but it
cannot set `0` bits back to `1`. Any vector change that needs `0->1` requires
a full top-sector erase/rewrite, so the bridge must already be prepared to
stage and preserve the rest of `$F000-$FFFF`.

## Q: What should the first WDCMONv2 RAM bridge do?

Comment: The first bridge should look like a normal WDC-loaded program, in the
same spirit as the stock/demo programs that WDCMONv2 already knows how to load
and run. WDCMONv2 is the launch ramp, not the permanent owner of the update
policy.

The bridge should run from RAM and ask only a few plain questions:

```text
WDC RYORS BRIDGE

BACKUP LIVE BANK 3 TO BANK 0? Y/N
INSTALL STR8/R-YORS TO BANK 3? Y/N
```

Before asking, it should print the facts it thinks it sees:

```text
LIVE=B3
B0=ERASED/USED/UNKNOWN
TOP=WDCMON/RYORS/UNKNOWN
TARGET=RYORS 0.0517 #89ABCDEF
```

The backup action is full-bank preservation:

```text
if B0 is erased:
  copy live Bank 3 -> Bank 0
  verify Bank 0 == original Bank 3
  leave Bank 0 conceptually B0 HOLD

if B0 is used:
  refuse or require a stronger typed confirmation before erase
```

The install action should receive or carry a R-YORS/STR8 install payload, stage
dangerous sectors in RAM, write/verify from RAM, and reset into STR8 when the
live boot image is valid enough.

Concern: Once flash mutation begins, the bridge must not depend on WDCMONv2
ROM calls. It may use WDCMONv2 to get launched and perhaps to receive bytes
before the flash transaction, but the erase/write/verify core has to be
self-contained in RAM. If the bridge replaces the live top sector and fails
halfway, recovery may require the saved Bank 0 image, a WDC bridge rerun, or
the external programmer.

## Q: What boring features are worthwhile for STR8?

Comment: STR8 should be the small flash manager, not a second rich monitor.
Its value is that flash operations become explicit, repeatable, and boring:

```text
IDENTIFY
MAP
BACKUP
RESTORE
INSTALL HIMON
INSTALL STR8
VERIFY
```

HIMON remains the workbench: editor, loader, debugger, assembler, catalog view,
and normal command environment. STR8 owns survival: boot checks, bank policy,
flash range policy, staging, erase, write, verify, rollback, and recovery
messages.

The short identity line belongs in this spirit:

```text
RYORS 0.0517 #89ABCDEF B0 HOLD
```

The displayed epoch date is `(year - 2026).MMDD`. The hash should identify the
canonical image text, while mutable policy such as `B0 HOLD` comes from the
STR8 config byte rather than being part of the image hash.

Concern: "Boring" must not mean vague. Each operation should say what range it
will touch, whether erase is required, what is preserved, what was verified,
and whether bank 3 was restored before any ROM code resumes.

## Q: Can STR8 yield to monitors or apps other than HIMON?

Comment: Yes, later. STR8 does not have to mean "the thing that only starts
HIMON." It can become the tiny boot/recovery chooser that validates a target
and yields to it:

```text
LOMON   low/small monitor
MIDMON  middle monitor/tools
HIMON   full R-YORS monitor
CHESS   app/game/demo target
WDC     restored factory/base image
```

A future boot-target display could stay compact:

```text
STR8>BOOT
0 WDC    B0  #12345678
1 LOMON  B3  $9000
2 MIDMON B3  $A000
3 HIMON  B3  $C000
4 CHESS  B3  $8000
```

For V0, `G` can remain the simple HIMON handoff. The richer target table should
wait until STR8 has reliable identity, map, verify, and install behavior.

Concern: A boot-target table must not turn STR8 into a general application
shell. STR8 should verify enough to avoid jumping into garbage, select the
bank/range if needed, and jump. The target owns its own UI, memory rules, and
return/reset behavior.

## Q: Could STR8 become the useful product by itself?

Comment: Yes. STR8 can be valuable as a neutral W65C02SXB boot/recovery tool
even for users who do not want HIMON, THE, R-YORS catalogs, or the later
assembler/runtime stack. In that shape, STR8 is a small board utility:

```text
bank-aware boot selector
factory-image saver
flash backup/restore guard
installer/verifier
known-good escape hatch
```

The product boundary should stay layered:

```text
STR8 core     tiny, boring, recovery-safe
STR8 menu     optional boot chooser UI
HIMON         one possible payload
R-YORS        one possible full stack
```

Boot behavior should be quiet by default:

```text
reset -> STR8
if default target is valid and no key pressed: boot it
if key pressed or target bad: show menu/recovery
```

An eventual menu could be useful without being a full monitor:

```text
STR8 BOOT
0 WDCMON  B0  $F800  #12345678
1 BASIC   B3  $8000  #...
2 FORTH   B3  $A000  #...
3 HIMON   B3  $C000  #...
4 CHESS   B2  $8000  #...
```

Target records probably need only compact facts:

```text
name
bank
entry address
protected ranges
hash/check
default flag
role/notes
```

Concern: STR8-as-product must not require the user to buy into the rest of
R-YORS. The menu must remain optional, compact, and recovery-oriented. If STR8
becomes too chatty, catalog-heavy, or application-like, it stops being the
thing an operator trusts when the payload is broken.

## Q: Should STR8 load/update HIMON and STR8 itself?

Comment: Yes. STR8 is the right authority for dangerous flash update flows.
HIMON may receive, inspect, or prepare an update package, but STR8 should make
the flash decision:

```text
is the target range legal?
does this touch the protected top sector?
is erase required?
has the live image been backed up?
does the written image verify?
is the new HIMON bootable enough to hand off?
```

HIMON updates should be the friendlier case. STR8 can stage a HIMON S-record or
sector image, refuse the protected top sector, update the ordinary HIMON/body
sectors, verify by read-back, update identity bytes when appropriate, then hand
off to HIMON.

STR8 updates are the harder case. They need a RAM-resident transaction that
stages the full top sector, merges the new STR8 and RAM-worker bytes, preserves
or deliberately rebuilds the config pocket and vectors, confirms the
protected-sector erase, writes and verifies from RAM, then resets.

Concern: STR8 self-update must not return casually into ROM code that may have
just been erased or replaced. The update path must either reset or return
through a tiny RAM-safe continuation after bank 3 and the top sector are known
good.

## Q: Can future STR8 move flash chunks around?

Comment: Eventually, yes, but only after STR8 can classify what it is moving.
The future useful direction is a flash housekeeper that finds erased `$FF`
space, recognizes live non-`$FF` chunks, moves safe chunks into better homes,
and makes larger erased sectors available again.

The first version should stay sector-based:

```text
sector is erased
sector is used
sector is protected
sector looks like WDC/base image
sector looks like R-YORS/HIMON
sector looks like STR8/top-sector material
```

Later STR8 or STR8-N can become record-aware:

```text
this block has a header
this block has a type
this block has a length
this block has a hash/name identity
this block has a checksum
this block can be relocated
this block must stay fixed
this block is stale/buried
```

The safe movement shape is transactional:

```text
copy live chunk to new blank space
verify copy
mark new chunk valid
update catalog/link record
mark old chunk stale
erase stale sector only when no live chunks remain
```

A compact block header will probably be needed before this becomes real:

```text
magic/type
length
hash
flags
load address or relocation policy
checksum
valid/commit byte
```

Concern: STR8 must not move random non-`$FF` bytes just because they are not
blank. Unknown used bytes should be reported and preserved until a recognizer,
header, catalog record, or explicit operator action gives STR8 enough authority
to relocate them.

## Q: Where should ROM garbage collection live?

Comment: STR8/STRAIGHTEN is the right home for dangerous sector rebuilds, or
for calling a catalog maintenance subsystem that performs them.

Concern: HIMON lookup can skip buried records, but should not silently erase or
rebuild sectors during normal command lookup.

## Q: What can STR8 scan?

Comment: Scan ranges may be selected by full start/end, start plus length, or a
4K sector selector:

```text
0-F  one full 4K sector selector
0-7  RAM region selectors
7F   IO page is special
8-F  flash region selectors
```

Concern: RAM, IO, and flash have different rules. A selector that is safe for
flash scanning is not automatically safe for IO probing.

## Q: How should future flash range guards evolve?

Comment: Treat the current `FLASH_ADDR_ALLOWED_XY` as a conservative HIMON
public-writer guard, not as the permanent truth about all valid flash writes.
It currently allows `$8000-$CFFF` and protects `$D000-$FFFF`, which matches the
early `L F` blank-byte loader and HIMON-at-`$D000` world. STR8 needs a richer
policy split:

```text
FLSH_*   selects or queries the visible $8000-$FFFF flash window
FLASH_*  performs low-level erase/program/check in the currently selected window
POLICY   decides whether this caller and operation may touch this range
```

Possible future guard families:

```text
FLASH_ADDR_ALLOWED_XY       current HIMON L F public writer guard
FLSH_RANGE_ALLOWED_CTX      generic operation-context guard
STR8_RANGE_BACKUP_OK        allow whole destination backup bank/window
STR8_RANGE_RESTORE_OK       allow ordinary bank 3 bytes, skip STR8 window
STR8_RANGE_INSTALL_OK       allow protected-window install via top-sector transaction
STR8_RANGE_FACTORY_OK       allow bank 0 only after explicit clear-check/confirm
```

The operation context should include enough facts to avoid hidden globals:

```text
operation kind:  LF, BACKUP, RESTORE, INSTALL, FACTORY, QUERY
source bank:     0-3 or none
destination bank:0-3 or none
window/range:    CPU $8000-$FFFF address range or 4K window selector
protected start: selected STR8 protected-window start
authority:       HIMON, STR8 RAM worker, recovery, factory action
```

Raw erase/program routines should remain available, but only as mechanism:

```text
FLASH_SECTOR_ERASE_RAW_XY
FLASH_WRITE_BYTE_RAW_AXY
```

Callers that use raw routines must first make an explicit policy decision and
must run from RAM or another bank-stable region if the selected flash window can
change away from the code that is executing.

Concern: A single global "writable flash range" will be wrong for at least one
important operation. Backup must write whole bank images into bank 1/2, restore
must avoid the STR8 window in bank 3, install must touch only the protected path,
and HIMON `L F` should stay far more conservative than STR8 recovery.

## Q: How long should a 32K STR8 flash copy take?

Comment: The SST39SF010A chip timing gives a useful lower bound, not the current
STR8 RAM proof wall-clock time. The part has uniform 4K sectors, typical 4K
sector erase time of about 18 ms, and typical byte-program time of about 14 us.
For a dense 32K bank rewrite:

```text
8 sectors * 18 ms       = 144 ms erase time
32768 bytes * 14 us     = 459 ms program time
chip-level lower bound  ~= 0.6 s before software/read/verify overhead
```

The current RAM proof is intentionally simple and slower. It calls
`FLASH_WRITE_BYTE_RAW_AXY` for each non-`$FF` byte, and that routine copies the
RAM flash worker before each byte program. At the current 8 MHz timing model,
that worker-copy overhead alone is roughly 0.5 ms per programmed byte, so a
dense 32K image can land in the 20-30 second range. Sparse images with many
`$FF` bytes are faster because STR8 skips byte-program calls for `$FF` source
bytes.

Concern: Do not use visible LED activity as the timing proof. The first real
proof should measure serial progress or an explicit activity pin around erase,
program, and verify phases. Later STR8 should batch the RAM worker or keep it
resident for a sector/bank operation so the observed time moves closer to the
flash device timing.

## Q: Why am I not working on LEDs yet?

Comment: LEDs are downstream of the flash state machine. R-YORS should use LEDs
as visible status for flash in progress, erase, read, write, verify/error,
IRQ/time, console, and other enumerated machine states. But those states need to
exist as clean flash/recovery boundaries before the LED layer can be useful.

Current priority is still pulling flash into shape:

```text
read
stage
erase
write
verify
protect
error/result
```

After those states are named, add one small LED/status routine and call it at
stable operation boundaries first. The existing `BIO_PIA_LED_*` routines are
the likely hardware-facing layer; STR8 should expose a higher-level status byte
or event code instead of scattering raw PIA calls through flash code.

Possible first status names:

```text
LED_IDLE
LED_FLASH
LED_ERASE
LED_READ
LED_WRITE
LED_VERIFY
LED_IRQ
LED_TIME
LED_CONSOLE
LED_ERROR
```

Concern: Do not let LEDs become proof of flash correctness. A blink can prove
that code reached a point; it cannot prove erase/write/verify succeeded. Also
avoid putting ROM/BIO LED calls inside the RAM flash worker while bank mutation
is active unless there is a deliberately RAM-safe status hook.

## Q: Why QCC for STR8?

Comment: STR8 is still deciding how small it stays in V0 and how much future
STRAIGHTEN will own.

Concern: Settled boundaries should move into `DECISIONS.md`; experiments and
"what if STR8 owns this?" should stay here until proved.
