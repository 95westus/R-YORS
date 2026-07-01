# ASM Movable Modules And Flash Object Store

Status: planned next direction after the required ASM board proofs. Do not
start this before the current onboard expression-math proof and remaining
required hardware gates are captured.

This plan turns ASM output from "bytes at the current RAM address" into a
sealed, movable module. A sealed module can be installed into bank 3 flash,
stored in banks 0-2, loaded back into a RAM overlay, moved to a new flash base,
and repaired by relocation metadata instead of by guessing.

## Direction

The next direction after the required board tests is:

```text
assemble small ASM program at $2000
seal it with body length, entry, and relocation rows
install it into a bank 3 $8000-$BFFF hole
run it from flash
move/install the same sealed body to a different base
run it again
```

This is the first real proof that ASM output has enough truth attached to
survive movement.

## Ground Rules

Do not infer code length from `$FF`. `$FF` can be opcode/data, an erased flash
byte, or a flash-friendly fixup placeholder. Length comes from ASM session
facts: start, current PC, high-water PC, emitted/reserved byte count, and an
explicit sealed span.

Use two granularities:

```text
physical flash transaction  4K sector
logical allocation          $100 block
```

Flash erase/rewrite remains sector-sized. Allocation and directory accounting
can use 256-byte blocks: 16 blocks per sector, 128 blocks per 32K bank. Start
with contiguous block runs. Extents are later work.

Treat banks 0-2 as storage first. Selecting a bank changes the entire
`$8000-$FFFF` window, so direct execution from banks 0-2 is a later and harder
mode. First store modules there, then copy/install/load them through a RAM
worker that restores bank 3 before returning to normal HIMON.

Use flash for sealed, checkpointed, append-only, or staged facts. Do not use
flash as a constantly rewritten live symbol table. Hot mutable ASM state stays
in RAM; flash may hold large-session spill/checkpoint records only when they
are written transactionally and wear-aware.

## Single-Level Store

A transparent flat memory illusion is not feasible on this board. The CPU sees
only one selected 32K flash bank at `$8000-$FFFF`, and 65C02 absolute operands
still encode concrete addresses.

An object-level single-level store is feasible:

```text
object id / hash / name -> current physical location
```

The object store can place a sealed module in:

```text
RAM overlay
bank 3 live flash
bank 0-2 storage flash
host-exported package, later
```

Callers should ask for a named object. The store decides whether to run it in
place, install it into bank 3, or load/relocate it into RAM.

## Seal Record

After `END`, a future ASM `SEAL` step records the RAM session as a module:

```text
module name/hash
source base
exact body length
entry offset
body hash/check
export rows
import rows
relocation rows
storage metadata
```

`END` is allowed to derive the first span facts automatically. A clean `END`
already has enough session state for:

```text
source base = ASM start PC
span end    = ASM high-water PC, exclusive
body length = span end - source base
```

This is the same value shape printed by the compact report as `BYTES`.
`current PC` remains useful for diagnostics, but sealed-body length comes from
exclusive `HIGH - START`, not from scanning RAM and not from guessing at erased
`$FF` bytes. A later `SEAL` command should consume these ended-session facts and
write the module record explicitly; plain `END` should not silently allocate
flash or publish a catalog record.

Current ASM v1 code captures the clean-`END` fact record in RAM as:

```text
flags bit0 valid after clean END
      bit1 forward-ORG hole seen
      bit2 plain DS count/unowned bytes seen
base  = start_pc
end   = high_water_pc, exclusive
len   = end - base
fnv   = FNV32 over bytes [base,end), derived only after validation passes
```

These fields are cleared on session reset or fatal session failure. They are not
a K bit, not a flash record, and not a catalog publication.
The ineligibility bits do not reject normal ASM source today; they give a later
explicit `SEAL` command a clean reason to refuse a non-contiguous or unowned
span.
The contiguous byte run at `ASM_SEAL_REC` is the RAM-only record. It proves
exactly which emitted body bytes a later published record would name, but it
does not install or reserve anything in flash. Its first shape is:

```text
+$00 flags
+$01 base lo, +$02 base hi
+$03 end lo,  +$04 end hi
+$05 len lo,  +$06 len hi
+$07 fnv0, +$08 fnv1, +$09 fnv2, +$0A fnv3
```

The first post-session `SEAL` dry-run should stay RAM-only. It runs after
`END`, consumes the frozen facts above, fills `ASM_SEAL_REC`, and writes no
flash/catalog record.
It accepts only `FLAGS=$01` and should report exact facts on success:

```text
SEAL OK FLAGS=$01 BASE=$hhhh END=$hhhh
SEAL REC @=$hhhh LEN=$hhhh FNV=$hhhhhhhh
```

On failure it should keep the output small and factual:

```text
SEAL ERR=$ee FLAGS=$ff
```

First-pass `SEAL ERR` values:

```text
$01  no clean END / valid bit clear
$02  bad span flags: valid bit set, but FLAGS != $01
```

First-pass `SEAL FLAGS` bits:

```text
$01  valid clean-END facts are present
$02  non-initial forward ORG hole was seen
$04  plain DS count/unowned bytes were seen
$08-$80 reserved; any reserved bit makes FLAGS ineligible
```

Useful composite `FLAGS` values:

```text
$00  no valid clean END facts
$01  seal-eligible in v0
$03  valid + forward-ORG hole
$05  valid + unowned plain DS bytes
$07  valid + hole + unowned
```

After clean `END`, current wrappers switch to a small `SEAL> ` command window:

```text
SEAL             dry-run the frozen facts
NEW              reopen ASM at the frozen END PC
.                return to HIMON
```

`NEW` is deliberately validated and non-interactive. It accepts only bare `NEW`
or `NEW ; comment` with optional surrounding spaces/tabs. It does not accept an
address operand; the restart address is always the frozen `END` PC. It does not
ask `Y/N` because the operator is already at the guarded post-session prompt,
and extra confirmation would make paste scripts less deterministic. A valid
`NEW` discards the frozen facts by starting a new ASM session and reports the
restart point with `OK PC=$hhhh`.

Seal v0 is a single contiguous body. The first `ORG` in a fresh/pristine ASM
session may choose the source base and becomes `START`. After that, any
forward `ORG` creates an unowned hole in the `[START,HIGH)` span, even though
the assembler itself emits no fill bytes. Plain `DS count` has the same problem
for sealing: it advances the span without defining reproducible body bytes. A
v0 `SEAL` should reject both shapes. If the module needs padding or reserved
bytes, express them as owned bytes with `DS count,init-list`, normally
`DS count,$00`, so the sealed span is explicit and reproducible.

The body is copied from the emitted RAM span. The source base is the assembly
base used when the bytes were emitted, often `$2000`. Entry is an offset from
the module body base, not a permanent absolute address.

Exports should be name/hash plus offset. Imports should be name/hash plus the
kind of value required. Imported resident calls are resolved by RJOIN/catalog
policy at load/install time unless the installer chooses to freeze the current
address into the installed image.

## Relocation Rows

Fixups answer "what was unresolved while assembling." Relocation rows answer
"what resolved, but depends on the module's final base or selected provider."

Start with a deliberately small relocation vocabulary:

```text
ABS16_INTERNAL   two-byte little-endian address = base + target_offset
LO8_INTERNAL     one byte = low(base + target_offset)
HI8_INTERNAL     one byte = high(base + target_offset)
ABS16_IMPORT     two-byte imported address from RJOIN/catalog
```

Relative branches inside the same module need no relocation because the
distance does not change when the whole body moves. Fixed hardware, I/O, and
fixed RAM addresses must be marked fixed or left out of relocation. Zero-page
operands should not be relocated by default.

Examples:

```text
JSR LOCAL_ROUTINE      ABS16_INTERNAL
JMP LOCAL_TAIL         ABS16_INTERNAL
LDA TABLE             ABS16_INTERNAL when TABLE is inside the module
LDA #<TABLE           LO8_INTERNAL
LDA #>TABLE           HI8_INTERNAL
JSR BIO_FTDI_PUT_CSTR ABS16_IMPORT, unless frozen at seal/install time
BRA LOCAL_LABEL       no relocation
STA $7100             fixed external address unless source declares otherwise
```

## Flash Directory

The managed store is a directory plus allocation bitmap, not a general-purpose
filesystem at first.

Directory records should be append/commit shaped:

```text
state: free/forming/sealed/stale/bad/reserved
name/hash
bank
start block
block count
exact byte length
entry offset
body hash/check
relocation table pointer/length
import table pointer/length
generation
role/tags
```

The final transition to `sealed` is the commit. A failed forming record is
ignored or later reclaimed. A moved object creates a new sealed record, then the
old record is marked stale.

Payload bytes may live separately from the directory. Metadata can live in one
4K sector to start, with payloads in `$100` block runs. Rebuild metadata by
preparing a full 4K sector image in RAM, erasing the sector, writing it, and
verifying readback.

## Wear Map

Every flash sector eventually needs erase accounting. The object store should
reserve space for a wear map from the beginning:

```text
sector id
erase count or erase-count bucket
last generation
state: free/live/stale/forming/reserved/bad
```

The count can start as a coarse bucket rather than a full exact counter if that
saves bytes. Updates must be append-only or copied forward during metadata
sector rebuilds. Never rely on metadata inside a sector that is about to be
erased unless it has already been preserved elsewhere.

Flash temp storage is allowed, but it is a managed lease:

```text
temporary symbol/fixup spill
large-session checkpoint
staged sector image
sealed relocation table
import/export table
append-only diagnostic or wear record
```

Temporary flash records still consume erase life and must have directory state,
generation, and cleanup policy.

## Bank Roles

Current STR8 V0 uses banks 0-2 as whole-image recovery storage. Do not silently
spend that recovery space. Changing bank roles is an explicit policy decision.

Conservative first role split:

```text
bank 3  live boot bank, HIMON/STR8, selected installed modules
bank 2  most recent recovery image
bank 1  first managed module/object store
bank 0  base image or oldest backup unless explicitly enrolled/reassigned
```

Possible later split:

```text
bank 0  metadata sector plus object/payload pool
bank 1  object/payload pool
bank 2  recovery image or SYS/USR role by explicit policy
bank 3  live boot bank
```

The operator-facing surface should print the role plan before committing.

## WDCMONv2 Conversion Bridge

A future WDCMONv2-to-R-YORS bridge is a separate onboarding path that must be
kept compatible with the object-store plan.

The bridge starts from a stock board that still boots WDCMONv2. It is loaded
and started by the WDC process, then runs from RAM. After it starts, it must not
depend on WDCMONv2 ROM calls for flash mutation. Its erase/write/verify core
has to be self-contained in RAM because it may replace the live top sector or
the monitor body it was launched under.

The bridge should do three storage-related jobs before conversion:

```text
identify the board and current flash layout
offer to preserve the original WDCMONv2/base image
record enough provenance for the new R-YORS store to respect that saved image
```

Preferred preservation is still full-bank preservation, not clever partial
reconstruction:

```text
bank 0  original WDCMONv2/base image, B0 HOLD, unless operator chooses otherwise
bank 3  new R-YORS/STR8/HIMON live boot image
```

If the future object store already exists when the bridge is built, the bridge
may seed it with directory/provenance records for the saved base image. If the
object store does not exist yet, the bridge should still leave a simple,
discoverable marker or note that later R-YORS tools can promote into object
metadata.

The bridge is an ingress path, not the first movable-module implementation. It
must not require sealed ASM modules before it can install R-YORS. Later, the
same managed-store machinery can hold bridge images, installer payloads,
module packages, and saved factory images as named objects.

Planning consequences:

```text
do not silently spend bank 0 while it may hold a WDCMONv2/base image
directory records need a role/provenance field, not only a code-module field
wear-map accounting applies to bridge-written sectors too
saved factory/base images are protected objects, not scratch space
```

## First Run Modes

RAM overlay first:

```text
find sealed module in bank 0-2
copy body to RAM overlay
apply relocation for the RAM base
resolve imports through RJOIN/catalog
restore bank 3
run from RAM
```

Bank 3 install second:

```text
find or receive sealed module
choose a bank 3 flash hole under the safe write policy
stage full affected sector image(s) in RAM
copy body bytes into the staged image
apply relocation for the chosen flash base
write and verify affected sector(s)
append/publish directory or RREC record
run from bank 3 flash
```

Direct banked execution from banks 0-2 is later. It needs a RAM trampoline,
strict call rules, and a safe way to restore bank 3 before any resident HIMON
service is called.

## Movement And Condense

A move is copy plus relink:

```text
read sealed object
verify body hash/check
choose new blocks/base
copy body to staging
apply relocation for the new base
write and verify the new copy
append new directory record
mark old record stale
```

Compaction remains sector-based:

```text
collect live records from a sector
build a clean 4K image in RAM
erase the sector
write full staged image
verify
update directory and wear metadata
```

Do not edit directory records in place unless the operation is explicitly a
1-to-0 flash-state transition that is safe until the next erase.

## Phases

1. Finish required board tests.
   Prove current ASM expression behavior and other pending hardware gates
   before starting the movable-module implementation.

2. Define the seal format.
   Record exact body span, entry offset, exports, imports, relocation rows, and
   body hash/check for an ASM RAM session.

3. Preserve relocation facts.
   Teach ASM or a host-side checker to record internal absolute references,
   selector references, and import references as relocation rows.

4. Build RAM overlay load.
   Store a sealed module, reload it to a different RAM base, relocate it, and
   run it from RAM.

5. Build bank 3 install.
   Install the same sealed body into a bank 3 `$8000-$BFFF` hole, relocate it,
   verify flash, and run it from flash.

6. Prove move/reinstall.
   Install the same sealed body at a different flash base, apply relocation
   again, and run it again.

7. Add managed banks 0-2 storage.
   Store sealed modules, relocation tables, checkpoint records, and wear-map
   records under explicit bank-role policy.

8. Integrate the WDCMONv2 conversion bridge.
   Treat the bridge as an onboarding producer of preserved base-image records
   and provenance. It may seed the object store when available, but must not
   require the object store for the first R-YORS conversion path.

9. Add condense/pack.
   Reclaim stale records through full-sector staging, rewrite, verify, and
   wear-map update.

## First Acceptance Target

The first acceptance target is intentionally small:

```text
ASM source assembled at $2000
one exported entry
one internal JSR or JMP needing ABS16_INTERNAL relocation
one #<LABEL / #>LABEL pair needing LO8/HI8 relocation
one fixed external RAM output address, not relocated
optional resident JSR import through RJOIN
```

Acceptance:

```text
sealed body reports exact length and entry offset
relocation rows match expected patch sites
RAM overlay at a different base runs
bank 3 flash install runs
same sealed body moved to another base runs
old flash record can be marked stale without losing the new one
```

## Non-Goals For The First Pass

```text
no transparent flat RAM/flash address space
no direct execution from banks 0-2
no inferred length from $FF
no general free-list filesystem
no silent consumption of STR8 recovery banks
no silent overwrite of a saved WDCMONv2/base image
no live mutable flash symbol table
no compression until plain body records work
```
