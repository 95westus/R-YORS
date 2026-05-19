# QCC STR8

This page keeps STR8 and future STR8-N/STRAIGHTEN questions in QCC form.

## Q: Does STR8 own memory and interrupts?

Comment: The current direction is no. STR8 should be useful in systems where
the user already has memory policy, vector policy, and interrupt layering.
STR8 can cooperate with R-YORS layers, but it should not require ownership of
all RAM, all vectors, or all interrupt behavior.

Concern: STR8 still needs enough reserved workspace and safe entry rules to do
recovery/update work. That reservation should be explicit in the memory map.

## Q: What should NMI mean while STR8 is running?

Comment: STR8 should treat NMI as inert unless a specific STR8 mode deliberately
opens a safe recognition window. In ordinary STR8 prompt, countdown, recovery,
and update work, an NMI press is not a command path:

```text
NMI edge arrives
CPU enters the STR8-safe NMI target
handler does the smallest safe thing, normally RTI
STR8 continues where it was
```

If STR8 needs operator input, it should ask for a polled event, key, or latched
state at known-safe points. The fact that the physical input arrives on NMI
does not mean STR8 should use asynchronous NMI control flow as the user
interface.

Concern: A 65C02 NMI cannot be masked by `SEI`. Even a do-nothing NMI still
requires vector fetch and handler fetch. During flash erase/program, fetching
the vector or RTI stub from the same flash device or from the wrong selected
bank may be unsafe. Therefore the "NMI does nothing" policy needs an
implementation proof: valid vector bytes, a fetchable tiny handler or RAM-safe
path, and bank state that cannot expose the wrong handler. Until that is proved,
NMI during flash mutation remains something STR8 should not depend on.

## Q: Could NMI vector patching become a supervisor boot signal?

Comment: Yes, as a possible future, but it should be framed as a boot-time
recognition window rather than as a general STR8 interrupt API.

One possible shape:

```text
reset enters STR8
STR8 installs a tiny NMI target for the boot window
NMI/button sets STR8_SUP_REQUEST and RTIs
STR8 polls STR8_SUP_REQUEST at safe points
if set, STR8 enters supervisor/recovery mode
before flash mutation, STR8 restores inert NMI behavior
on HIMON handoff, HIMON installs its normal NMI policy
```

This makes NMI a way to request a mode, not a way to interrupt arbitrary STR8
work. The active NMI target could have a few named states:

```text
STR8_NMI_RTI          ignore NMI during STR8
STR8_NMI_SUP_REQUEST  set supervisor-request flag, then RTI
HIMON_NMI_TRAP        normal HIMON/debug NMI behavior after handoff
```

Concern: The current image still has the hardware NMI vector in the top flash
vector block, and the current HIMON/SYS vector layer may dispatch through RAM
target cells. A future supervisor request must say exactly which vector is being
patched: final hardware bytes, a STR8 stub, or a RAM vector target behind a
stable trampoline. It must also close the recognition window before erase/write
starts, because flash mutation is not a safe time to use NMI as an event source.

## Q: Should STR8 introduce IVI, Interrupt Vector Indirection?

Comment: Yes, if STR8 is the chosen boot/recovery product for the board. `IVI`
is pronounced `IVY`. If a user does not install STR8, then STR8 vector policy
is irrelevant. But if the user chooses STR8, it is reasonable for STR8 to own
the hardware vector front door and provide a recoverable indirection layer.

The shape:

```text
RESET    -> STR8 reset supervisor
NMI      -> IVI_NMI
IRQ/BRK  -> IVI_IRQ_BRK

IVI_NMI:
  JMP (IVI_NMI_VEC)

IVI_IRQ_BRK:
  inspect stacked status B flag
  if IRQ: JMP (IVI_IRQ_VEC)
  if BRK: decode BRK operand/signature and dispatch
```

That lets HIMON install what HIMON wants:

```text
RESET -> STR8 boot decision, then HIMON cold/warm entry
NMI   -> HIMON NMI/debug/re-enter path
IRQ   -> real IRQ owner such as ACIA/VIA/user code
BRK   -> HIMON debugger now, richer BRK service table later
```

Another payload, `BETTERMON` or a user application, can install different
targets. STR8 provides the stable patch points; the payload owns the meanings
after handoff.

Possible BRK table direction:

```text
BRK $00-$7F  payload/user/debug space
BRK $80-$BF  STR8/IVI recovery or board services
BRK $C0-$FF  system/future/reserved
```

The ranges are placeholders. The stronger idea is that one hardware IRQ/BRK
vector can become an inspectable dispatch front door without reflashing the
top-sector vector bytes every time a monitor wants a different BRK policy.

Concern: IVI must not become a hidden operating system. Its promise is
recoverable mechanism:

```text
hardware vectors stay stable
STR8 can always regain control on reset
payloads can patch indirect targets
payloads own semantics after handoff
```

If IVI starts dictating every NMI, IRQ, and BRK meaning forever, it violates the
payload-owns-policy spirit. If it gives patchable vectors, safe defaults, and
documented dispatch rules, it strengthens STR8 as a standalone board product.

## Q: How should STR8/IVI be explained as useful?

Comment: The user-facing value is not "more vector machinery." It is "install
one small recovery layer and stop reflashing fragile top-sector vectors for
every experiment."

Possible product framing:

```text
STR8 gives the board a recoverable boot door.
IVI gives every monitor safe interrupt patch points.
HIMON is the bundled monitor, not the only possible payload.
Your monitor can boot through STR8 and still own its NMI/IRQ/BRK behavior.
```

For a board user who does not want a complex toolchain, STR8 can be the first
useful thing:

```text
install STR8 once
use MAP/BACKUP/RESTORE/INSTALL
load HIMON, WDCMONv2, BETTERMON, or an app as a target
recover through STR8 if the target is missing or bad
change interrupt behavior through IVI patch points instead of reflashing vectors
```

Concern: The sell must stay honest. IVI does not make unsafe flash mutation
safe by itself, and it does not remove the need for a clear payload handoff
contract. It reduces one specific pain: hardware vector changes become rare,
recoverable, and visible.

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

## Q: Where do wear counts and scratch sectors live?

Comment: Not in stolen bytes inside ordinary data sectors, and not in hidden
holes in the STR8 top sector. If R-YORS records erase wear, it should do so as
explicit flash metadata, probably named by hash/kind as `WMAP` rather than as a
filesystem file.

Exact erase counts to 100,000 need 17 bits. If R-YORS only records each 128th
erase event, the persistent bucket count needs only 10 bits because:

```text
ceil(100000 / 128) = 782
```

That makes the counter payload small, but the flash physics are still sector
physics. A tiny counter table still needs an erase-sector home. The preferred
future shape is append-only:

```text
write a newer WMAP record
verify it
seal it
let hash/kind/generation choose the newest sealed WMAP
bury or ignore old WMAP records until condense
```

Temporary flash should be treated as a lease, not as storage holding the only
truth. A future STRAIGHTEN scratch chooser may pick an erased sector with low
wear, but the scratch sector must be free, reclaimable, or fully staged before
erase:

```text
TMP    disposable work area; no only-copy truth
STAGE  provisional transaction area with hash/check/state
FINAL  sealed hash-visible records or image bytes
```

Half-sector policy windows are possible, but they are not erase units. A 2K
window in sector X and a 2K window in sector Y can ping-pong only if STR8 treats
reclaim as a full 4K sector transaction and preserves or discards the other 2K
half by explicit policy.

Concern: A "least worn scratch sector" does not exist until the bank layout has
a managed pool. V0 banks 0-2 are still recovery images, and bank 3 is still the
live boot bank. STR8 must not borrow protected STR8/vector bytes, live boot
required bytes, the only valid backup image, or sealed final records just
because a sector has attractive wear.

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

## Q: What if a future bank layout stopped being whole 32K images?

Comment: This is a thought experiment, not a change to the current STR8 bank
policy. The current proof uses whole 32K images because the recovery rule is
simple and visible. If a later design reserved banks and divided one bank into
smaller image or staging regions, it might look like:

```text
bank 0  WDC/base/reserved
bank 1  reserved for future managed use
bank 2  lower 16K image slot
bank 2  upper 16K image slot
bank 3  $8000-$BFFF reserved/growth/stage
bank 3  $C000-$FFFF HIMON/STR8/vector
```

If the shorthand is written as `0-7` and `8-F`, the implementation document
must translate it into exact bank-relative sectors or CPU-visible ranges before
any flash writer trusts it. On this board, each selected 32K bank maps to
`$8000-$FFFF` and contains eight 4K erase sectors, so range names must not hide
the physical geometry.

Smaller image slots need explicit records:

```text
bank
start address
length
entry address, if executable
hash/check
generation
role
protected ranges
dependencies
```

This can be useful. A 16K payload below `$C000` can coexist with a fixed
HIMON/STR8 top half. A 16K upper-half image is more dangerous because it
overlaps HIMON, STR8, the config pocket, and vectors unless the operation is an
explicit protected update.

Concern: Once a bank is partitioned this way, automatic `B` backup rotation can
no longer pretend the bank is one complete 32K image. STR8 needs range-aware
restore and verify rules, and the map display must say which sectors are
reserved, staged, final, image, WDC/base, HIMON, and STR8.

## Q: Could STR8-N pack named regions instead of whole banks?

Comment: Yes, as a future STR8-N/STRAIGHTEN direction. STR8-N can become a
boot recovery and flash-management layer that backs up regions, remembers
where each region came from, and later restores or relocates them by metadata
rather than by whole-bank position alone.

The future verb is `PACK` in the broad sense: place live regions somewhere
safe, record their origin and role, and make later recovery/restore possible.
Some backed-up regions may eventually be compressed, but compression must be
optional and explicit. STR8-N must be able to verify, name, and restore a
region without guessing what compressed bytes mean.

Near-term bank-layout direction:

```text
banks 0 and 1 together:
  64K managed backup arena
  five 12K backup slots = 60K total
  one 4K metadata sector for names, labels, origin records, checks, and roles

bank 2:
  SYS/USR bank

bank 3:
  default boot bank
  $8000-$BFFF  16K user-available space
  $C000-$EFFF  12K default payload gate, currently HIMON-shaped
  $F000-$FFFF   4K STR8 recovery/top-sector region
```

A first metadata record for a 12K slot likely needs:

```text
name or label
source bank
source start address
length
entry address, if executable
role: system, user, payload, backup, scratch, factory, unknown
hash/check
generation
compression kind: none first, later optional
restore policy
```

This keeps the useful part of whole-image recovery, but stops pretending that a
backup source must always be a full 32K bank.

Concern: This is not the current `B`, `0`, `1`, and `2` contract. The current
implementation still uses whole 32K image copies. Before the 5x12K layout can
be trusted, STR8 needs exact slot boundaries, sector erase rules, metadata
commit rules, and a restore display that tells the operator what region is
being restored and where it came from. Unknown regions must be preserved or
reported, not packed, moved, or compressed silently.

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
TARGET=RYORS 0.0517 #5F6A0F7A
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
RYORS 0.0517 #5F6A0F7A B0 HOLD
```

The displayed epoch date is `(year - 2026).MMDD`. For current STR8, the marker
is FNV-1a32 over a private phrase:

```text
private phrase -> #5F6A0F7A
```

Mutable policy such as `B0 HOLD` comes from the STR8 config byte rather than
being part of the identity marker.

A HIMON quoted-hash command can make this a small public challenge without
publishing the phrase:

```text
> "GUESS TEXT"
#XXXXXXXX#
```

The command hashes text between the command quote and the closing quote, after
HIMON uppercases input and trims leading/trailing spaces, so `"GUESS TEXT"` and
`" GUESS TEXT "` hash the same bytes. If the result is `#5F6A0F7A`, HIMON
reports a STR8 match. Treat this as an Easter egg, not security; 32-bit FNV-1a
is intentionally compact and non-cryptographic.

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

## Q: Should STR8 load/update targets and STR8 itself?

Comment: Yes. STR8 is the right authority for dangerous flash update flows.
HIMON may receive, inspect, or prepare an update package, but STR8 should make
the flash decision. The V0 installer should be target/range-shaped internally
rather than HIMON-shaped. HIMON is the default bundled target, not the only
possible target:

```text
is the target range legal?
does this touch the protected top sector?
is erase required?
has the live image been backed up?
does the written image verify?
is the new target bootable enough to hand off?
```

Concern: "target/range-shaped" is an implementation rule, not permission to put
raw range selection in the ordinary rescue prompt. The first user surface should
be named and guided:

```text
UPDATE
UPDATE HIMON
UPDATE STR8
```

Generic target/range selection belongs in a later advanced path, after STR8 can
print exact ranges, reject protected overlap, and make the operator confirm the
named consequence rather than a cryptic address.

The first S19 gates should be fixed:

```text
UPDATE HIMON  accepts only $C000-$EFFF
UPDATE STR8   accepts only $F000-$FFFF
```

That still leaves the low-level code reusable. It simply prevents the ordinary
operator from being asked to type or approve raw ranges while the machine is in
its recovery/update prompt.

Payload updates below the protected top sector should be the friendlier case.
STR8 can stage a target S-record or sector image, refuse the protected top
sector, rebuild the ordinary target/body sectors, verify by read-back, update
identity bytes when appropriate, then hand off to the selected target. S19 is a
transport into the RAM staging buffer, not permission to stream bytes directly
into live monitor flash.

The sticky V0 rule:

```text
first make STR8 install target code/ranges
use HIMON as the default proof target
do not bake HIMON into the low-level installer
then use the proven machinery for the harder STR8/top-sector update
```

For V0, target replacement should mean:

```text
stage full 4K sector in RAM
merge incoming bytes
if staged sector differs, confirm erase
erase selected 4K sector
write full staged sector
verify full staged sector
```

Direct 1->0 byte programming is useful for deliberate one-way flags and later
append-only records, but monitor replacement should not depend on that shortcut
in the first version.

IVI remains the vector mechanism beside this update path. LEAF is the future
friendly surface over it. Payloads such as HIMON can use future LEAF atomic
routines to patch runtime vector targets after handoff:

```text
set NMI target
set IRQ target
set BRK target
set BRK service target, later
```

Those routines should leave either the old target or the new target valid; no
half-patched state. They do not grant flash-write authority and do not make
STR8 responsible for the payload's interrupt meanings.

Future onboard updates do not have to pass through S19. S19 is useful when a
host sends bytes to the board; onboard ASM can instead hand STR8 candidate
records or staged sector images directly.

Until that onboard producer exists, BIN-to-S19 remains an off-board packaging
step:

```text
host build creates vector-complete ROM BIN
host converts selected image/range to S1/S9 transport
board receives S19 into STR8 staging
STR8 rebuilds sectors, writes, verifies, and resets/hands off
```

That is a transport limitation, not the permanent architecture. The future
shape is:

```text
old monitor remains the winner
new XMON/HIMON is built as a candidate
candidate bytes are staged and verified
candidate metadata is formed and sealed
final tiny BOOT/XMON winner record points to the new candidate
reboot through STR8
```

The "atomic" part is the winner-record commit, not the whole monitor write.
Before that commit, STR8 should still choose the old sealed monitor. After that
commit, STR8 may try the new sealed candidate. If validation or boot fails,
STR8 should be able to choose the previous sealed candidate instead of assuming
the latest write is always bootable.

STR8 updates are the harder case. They need a RAM-resident transaction that
stages the full top sector, merges the new STR8 and RAM-worker bytes, preserves
or deliberately rebuilds the config pocket and vectors, confirms the
protected-sector erase, writes and verifies from RAM, then resets.

Concern: STR8 self-update must not return casually into ROM code that may have
just been erased or replaced. The update path must either reset or return
through a tiny RAM-safe continuation after bank 3 and the top sector are known
good.

## Q: Could STR8 use S2/S8 `.s28` as a bank-aware transport later?

Comment: Yes. This is a strong future STR8 idea, but it should be named as
S2/S8 or `.s28` transport rather than as a V0 requirement. Motorola S-record
type S2 carries a 24-bit address, and S8 terminates a 24-bit-address transfer.
The `.s28` name is the file/profile convention, not a separate `S28` record
type.

That extra address byte can describe physical board flash directly. With four
32K banks, STR8 can treat the transfer as physical SST39SF010A flash-chip
addresses:

```text
bank 0  physical flash $00000-$07FFF
bank 1  physical flash $08000-$0FFFF
bank 2  physical flash $10000-$17FFF
bank 3  physical flash $18000-$1FFFF  reset/default boot bank
```

The translation from transport address to board operation is:

```text
bank        = linear_address >> 15
bank_offset = linear_address & $7FFF
cpu_address = $8000 + bank_offset
```

Examples:

```text
$00000  bank 0 physical flash, CPU $8000 when bank 0 is selected
$08000  bank 1 physical flash, CPU $8000 when bank 1 is selected
$10000  bank 2 physical flash, CPU $8000 when bank 2 is selected
$18000  bank 3 physical flash, CPU $8000 at reset/default
$1F000  bank 3 physical flash, CPU $F000 top sector at reset/default
$1FFFA  bank 3 physical flash, CPU $FFFA vector block at reset/default
```

This gives STR8 a clean future fast path for bulk data storage, retrieval, and
transport. The host or onboard producer can say "these bytes belong to physical
bank/range X" without overloading CPU-visible `$8000-$FFFF` addresses, and STR8
can still apply its own guard rules before any erase/write happens.

Concern: S2/S8 makes addressing richer, not safer by magic. STR8 still has to
validate destination banks, protected windows, top-sector writes, bank 0 policy,
factory slots, and self-update rules. For V0, S1/S9 remains enough; S2/S8 is a
later STR8-N-style transport once the bank/range contract is firm.

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
