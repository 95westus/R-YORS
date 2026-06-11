# ASM Flash $8000 Game Plan

Status: active migration plan. The first flash slice builds with
`make -C SRC asm-v1-flash` and has hardware proof through current `L F`,
direct `G 800C` entry, and HIMON `ASM` hash-command dispatch.

## Goal

Move the ASM v1 runtime from a RAM-loaded proof image to a flash-resident image
near `$8000`, loaded by the current HIMON `L F` path, and make it callable from
HIMON through a FNV command/catalog lookup.

The intended split is:

```text
$8000+          flash-resident ASM runtime and one FNV command record
$2000+          user program opcodes emitted by ASM
$7DFF downward  ASM session metadata: symbols, fixups, refs, locals, names
$7E00-$7E01     HIMON-published RJOIN seed, protected
```

The ASM runtime gets a FNV signature so HIMON can find it. Programs assembled by
ASM do not need FNV headers unless the user explicitly exports/seals them later.
That keeps the normal "assemble opcodes into RAM" path bare and simple.

## Current Loader Reality

Use the current `L F` as it exists now:

```text
fixed-address S19 only
writes blank `$FF` flash bytes in HIMON's guarded flash window
protects HIMON fixed-entry space
verifies bytes after programming
does not erase sectors
does not auto-place
does not relocate absolute operands inside code
```

So the first flash ASM image should be linked to a fixed address, probably
`$8000`, and loaded only into an erased/blank flash window. Future `L F`
auto-place can come later. Do not make the first `$8000` ASM proof depend on
relocation.

## Current Flash Slice

The current first slice is `SRC/ASM/asm-v1-flash.asm` linked with
`asm-v1-core.asm` built as `ASM_RUNTIME_ONLY` plus `ASM_FLASH_RUNTIME`.

Current host facts:

```text
target:       make -C SRC asm-v1-flash
S19:          SRC/BUILD/s19/asm-v1-flash-8000.s19
FNV record:   $8000, token hash $56AD7400 for ASM
entry:        START from the link map, currently $800C
S19 range:    $8000-$AD66 only
runtime RAM:  UDATA at $6000-$6DBA, omitted from the S19
default emit: ASM_BEGIN starts emitted opcodes at $2000
```

This is intentionally not the final RAM layout. It proves the flash-resident
runtime split without yet moving ASM metadata down from `$7DFF`.

Current board facts:

```text
HIMON:       V 00.0610(2014)
load:        L F at $8000
write size:  WR=2D67
entry:       GO=800C, run by G 800C
command:     cold-boot HIMON `ASM` enters the same flash image
proof:       flash ASM assembled and ran interactive Life from $2000
```

## FNV Entry Shape

The flash image should start with, or contain early, a normal executable FNV
record:

```asm
ASM_HASH0       EQU $00
ASM_HASH1       EQU $74
ASM_HASH2       EQU $AD
ASM_HASH3       EQU $56

ASM_FNV:
        DB 'F','N',CMD_FNV_SIG2
        DB ASM_HASH0,ASM_HASH1,ASM_HASH2,ASM_HASH3
        DB CMD_HASH_KIND_EXEC_TEXT
        DW ASM_ENTRY
        DW ASM_TEXT

ASM_ENTRY:
        ; enter ASM command/session wrapper

ASM_TEXT:
        DB "ASM V",('1'+$80)
```

Candidate command token:

```text
token text: ASM
hash32:     $56AD7400
record LE:  00 74 AD 56
```

Before sealing this into source, verify it with HIMON's quote-hash command on
hardware:

```text
>"ASM"
expect hash $56AD7400
```

The lookup token and display text are separate. `ASM` is the command token.
`ASM V1`, `ASM RT`, or a later prettier text can be the catalog display text
without changing the command hash.

## Entry Contract

The callable entry should behave like a HIMON command target:

```text
called by HIMON command/hash dispatch
returns to HIMON with RTS
uses HIMON-published RJOIN seed at $7E00/$7E01
rejects a missing, $FFFF, or non-ROM-ish RJOIN seed clearly
opens an ASM session through the existing ASM_BEGIN path
does not require STR8 or HIMON top-sector vector patching
```

The seed-only RJOIN contract remains mandatory. ASM should not carry a private
fallback flash scanner in this direction.

## Memory Split Work

The hard part is not the FNV record. The hard part is making sure the
flash-resident runtime has no mutable state living in flash.

Required split:

```text
code and constant tables       flash, linked at fixed $8000 proof address
mutable session state          RAM arena
line buffer                    RAM arena
symbol/fixup/ref/local rows    RAM arena, high-down from $7DFF side
emitted user opcodes           RAM, low-up from $2000 side
RJOIN seed                     $7E00/$7E01, reserved
```

The first implementation can still use fixed arenas. No malloc is needed for the
first flash ASM. The allocator rule can be simple:

```text
emit_low starts at assembly origin, normally $2000
meta_high starts at configured metadata ceiling, normally $7DFF
each emitted byte checks emit_low <= meta_high
each metadata allocation checks meta_high >= emit_low
collision reports BAD RANGE or the existing nearest table error
```

Table growth should wait until this split is stable. Once the runtime lives in
flash, the RAM side can be enlarged more cleanly because code no longer competes
with tables for the same loaded image space.

## Existing Flash-Callable Proof

`rom-append-calc.asm` already proves the generic mechanism:

```text
fixed-address body in low flash
FNV command record in flash
HIMON command scan finds the record
hash dispatch calls the flash body
body uses resident HIMON services
body returns to HIMON
```

So the ASM flash stub is not needed to prove that `L F` plus a flash FNV record
can work. It is only a cheap ASM-specific doorway smoke: the `ASM` token, the
ASM entry contract, the selected `$8000` address, and the return path before the
full runtime is moved.

## Build Targets

Keep the proven RAM target while adding flash targets beside it:

```text
asm-v1-runtime-paste        current RAM proof, loads at $2000
asm-v1-flash                current fixed-$8000 flash build target
asm-v1-flash-8000.s19       full ASM runtime image for HIMON L F
```

The tiny stub remains optional. `rom-append-calc` already proved the generic
flash-call pattern, so the current work starts with the real flash runtime map
instead of adding a separate doorway-only target.

Stub oracle:

```text
load with L F
verify # K=5 shows ASM text
invoke ASM by hash/command
write a byte pattern to $7100-$7103 or print one short banner
return to HIMON
```

The full runtime move may also start directly from the flash image/map work if
the doorway proof feels redundant. Keep the `rom-append-calc` proof in mind as
the reason this does not need to be ceremonious.

## Phases

### Phase 1: ASM Doorway Smoke

Optional but recommended: create a tiny fixed `$8000` S19 with:

```text
FNV EXEC+TEXT record for ASM
ASM_ENTRY that proves it ran
RTS back to HIMON
```

Board proof:

```text
blank/erase target flash window
L F
send asm-flash-stub-8000.s19
# K=5
call ASM
D 7100 7103
```

Acceptance:

```text
ASM record is found by HIMON scan
ASM entry is called through hash dispatch
return path is clean
no HIMON protected flash is touched
```

Current choice: defer this separate stub unless the board proof for the full
flash image needs a smaller diagnostic.

### Phase 2: Build A Flash Runtime Image

Add the full ASM image as a fixed `$8000` build while leaving RAM ASM intact.
At this phase the code may still fail at startup if mutable state has not been
split correctly; the point is to get an inspectable map/listing and flash S19.

Acceptance:

```text
listing shows FNV record and ASM_ENTRY in flash
listing identifies every mutable ASM label still in the flash segment
RAM proof target still builds and passes
```

Current status: host slice implemented. The map places code at `$8000`, data at
`$A9CD`, and UDATA at `$6000`. The S19 contains only `$8000-$AD66` records.
Hardware proof through `L F`, direct `G 800C`, and cold-boot HIMON `ASM`
command dispatch is recorded in `DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md`.

### Phase 3: Move Mutable State To RAM

Replace in-image mutable storage with explicit RAM arena addresses. The flash
runtime may keep constant tables in flash, but must not write to them.

Acceptance:

```text
ASM_BEGIN clears only RAM session state
ASM emits to $2000+ by default
metadata grows down from $7DFF side
$7E00/$7E01 survives every session
RAM and flash builds both pass the same source-language tests
```

Current status: started, not final. Mutable session state and buffers are in
UDATA, but the arena is currently `$6000+`; it has not yet become the planned
`$7DFF` downward metadata arena.

### Phase 4: Command Surface

Make the normal user path be:

```text
HIMON prompt -> ASM token -> HIMON hash dispatch -> flash ASM entry
```

The first command can enter the current paste/session wrapper. Later wrappers
can split presentation:

```text
ASM I   prompted interactive session
ASM B   quiet batch/paste session
```

Both wrappers must share the same parser, fixup rules, local-label rules,
emitter, and `END` finalizer. The wrapper changes only what is printed.

### Phase 5: Pretty Interactive And Pretty Batch

Interactive should be pleasant while typing:

```text
ASM>
OK PC=$7200
ERR=$06 BAD RANGE PC=$7620
short local context when useful
no giant table dump unless requested
```

Batch should be quiet while source is arriving and polished at the end:

```text
ASM B
ASM OK START=$2000 END=$7640 BYTES=$0040
SYMS=12/32 FIX=0/24 LOCALS=7/8 REFS=18/64
GO=$7200
```

On failure:

```text
ASM ERR LINE=27 STATUS=BAD RANGE PC=$7620
TEXT=LDA #$1234
SYMS=3/32 FIX=1/24 LOCALS=0/8 REFS=5/64
```

Pretty does not mean chatty. It means stable columns, useful final facts, and
no surprise flood during paste.

### Phase 6: Table Headroom

After the flash/RAM split is stable, reconsider table sizes. The first bump can
stay fixed-size:

```text
globals:    from 32 to 64
fixups:     from 24 to 48 or 64
locals:     from 8 per global to 16 if real source wants it
local text: keep 15 visible chars unless a real source proves 8 is enough
```

Do this after the memory collision checks exist. More rows are useful only if
ASM can prove they do not collide with emitted code.

## Test Matrix

Host gates:

```text
make -C SRC asm-test
make -C SRC asm-v1-flash
asm-v1-flash-8000 map/listing check
asm-v1-flash-8000 S19 range check: no records below $8000
static check: no mutable flash writes
static check: no RAM arena overlap
```

Board gates:

```text
L F flash stub at $8000
# K=5 sees ASM
hash-call ASM stub returns cleanly
L F full ASM image at $8000
call ASM through hash dispatch
assemble opcode/addressing smoke sample
assemble local-label stress sample
assemble RJOIN hash-stats sample
run emitted code from $2000+ or requested ORG
dump oracle bytes
confirm $7E00/$7E01 unchanged
```

Negative gates:

```text
missing RJOIN seed -> clear failure
nonblank flash byte during L F -> no silent overwrite
metadata/opcode collision -> BAD RANGE or existing nearest table error
duplicate ASM FNV record -> documented first-match behavior
batch source error -> quiet drain and single useful final error report
```

## Risks And Decisions

First-match risk:

```text
If multiple ASM records exist in scanned flash, HIMON will find whichever record
the scanner reaches first. The first proof should use one erased target window
and one ASM record.
```

Relocation risk:

```text
Current L F does not relocate code. Link the first image at $8000. Future
auto-place needs relocation facts before it can safely move absolute operands.
```

Flash rewrite risk:

```text
Flash can program 1 bits to 0, not 0 back to 1. Changing the FNV record, text,
or code in place needs an erased window or a later erase/maintenance path.
```

Compatibility risk:

```text
Keep the RAM ASM proof until the flash image is hardware-proven. It is the
escape hatch while the RAM arena split is being made.
```

## First Coding Slice

The smallest useful next implementation slice is either the optional doorway
smoke or the real flash map work.

Doorway smoke:

```text
1. Add asm-flash-stub-8000 build output.
2. Embed one ASM FNV EXEC+TEXT record.
3. Link stub at $8000.
4. Load with current L F on blank flash.
5. Confirm HIMON can find and call ASM by hash.
```

Real flash map work:

```text
1. Done: add asm-v1-flash build output.
2. Done: emit the ASM FNV EXEC+TEXT record.
3. Done: produce a map/listing that separates UDATA from flash records.
4. Done: keep the current RAM proof build in asm-test.
5. Next: run the board L F proof and capture the transcript.
6. Next: move the UDATA arena from $6000+ toward the $7DFF-down plan.
```

Because `rom-append-calc` already proved the generic flash-call path, the stub
is a confidence smoke, not a blocker.

## Table Expansion Before Flash

ASM can expand some tables before the flash/RAM split, but it is not free while
the runtime still loads at `$2000`. The current RAM proof carries the mutable
tables inside the loaded image, so every extra row pushes the loaded image
higher in RAM.

Current proof limits:

```text
globals:    32 rows, 31 visible chars
fixups:     24 rows, 31 visible target chars
refs:       64 count-only cap in current code
locals:     8 rows per active global scope, 15 visible chars
```

Current storage cost:

```text
one global row: 50 bytes
one fixup row:  47 bytes including rollback bytes
one local row:  23 bytes at 15 visible local chars
refs:           no row table in current code, mostly a count/report cap
```

Likely safe before flash:

```text
REF_MAX $40 -> $80     cheap, if report-count headroom is useful
LOCAL_MAX 8 -> 16      about +$00B8 bytes
FIX_MAX $18 -> $20     about +$0178 bytes
```

More expensive before flash:

```text
SYM_MAX $20 -> $40     about +$0640 bytes
FIX_MAX $18 -> $30     about +$0468 bytes
FIX_MAX $18 -> $40     about +$0758 bytes
```

Recommendation:

```text
Do not spend a big table bump while ASM is still RAM-hosted unless a current
sample actually hits the limit. Modest local/fixup bumps are reasonable. The
large symbol/fixup headroom belongs after code moves to flash and metadata has
the planned high-down RAM arena with collision checks.
```
