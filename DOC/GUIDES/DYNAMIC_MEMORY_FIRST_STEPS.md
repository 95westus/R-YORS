# First Steps: Dynamic Memory Allocation for R-YORS

This note merges the working W65C02 dynamic-memory explanation with R-YORS
memory-map context. It is a design/learning guide, not a current source
implementation.

## Scope

- STR8 should not need general dynamic memory allocation. Recovery/update code
  wants fixed work areas, bounded buffers, and predictable failure behavior.
- HIMON/Himonia-F does not need this yet. If dynamic allocation arrives there,
  it should start as a small, documented service for session work, not as a
  hidden dependency in monitor hot paths.
- User programs, assembler experiments, and future catalog/fixup staging are
  the natural first places to use these ideas.
- The allocator does not know about types. It reserves bytes; the caller decides
  whether those bytes hold a byte, word, pointer, string, record, or block.

## Layer Placement

When HIMON eventually uses dynamic memory, dynamic memory should be a real
layer. It should not be treated as casual utility code hidden behind unrelated
monitor routines.

The layer is hardware-constrained because it manages raw RAM, zero-page pointer
lanes, stack assumptions, monitor buffers, and failure boundaries. It is not
hardware access in the `PIN_*` or `BIO_*` device-driver sense. Its job is memory
ownership policy: who owns which bytes, for how long, and what happens when a
request fails.

Recommended prefix family:

```text
MEM_*   memory ownership, allocation, pools, heap marks, and ZP lanes
```

Suggested internal split:

```text
MEM_MAP_*    fixed RAM/heap range knowledge
MEM_ZP_*     zero-page pointer lane ownership
MEM_BUMP_*   bump allocation
MEM_MARK_*   mark/release allocation
MEM_POOL_*   fixed-size byte/word/pointer/record pools
MEM_FREE_*   later free-list heap, only if truly needed
```

Public monitor/application calls may later be `SYS_*` wrappers over `MEM_*`,
for example `SYS_ALLOC` or `SYS_MEMMARK`. STR8 should stay out of this layer and
continue using fixed work areas.

## Minimal Allocate Shape

Use a half-open heap range:

```text
heap_start <= valid allocated byte < heap_limit
```

The simplest allocator keeps one 16-bit pointer to the first free byte.

```text
heap_ptr = heap_start

allocate(size):
    if size == 0:
        size = 1

    old = heap_ptr
    new = heap_ptr + size

    if new > heap_limit:
        fail

    heap_ptr = new
    return old
```

If `heap_limit` is the first invalid address, `new == heap_limit` is still
valid: the allocation used the final byte just below the limit.

## W65C02 Allocate Sketch

This is a sketch for an 8-bit size bump allocator. It is intentionally small,
but it includes the heap-limit check that many toy examples omit.

```asm
; Sketch only.
; Input:
;   A = bytes to allocate, 0..255; 0 is treated as 1
; Output:
;   C clear = success, X/Y = allocated address low/high
;   C set   = out of memory
; Uses:
;   HEAP_PTR_LO/HI
;   HEAP_LIMIT_LO/HI  ; first invalid address, so equality is okay
;   ALLOC_NEW_LO/HI   ; scratch, preferably zero page

ALLOC8:
        CMP #0
        BNE ALLOC8_SIZE_OK
        LDA #1

ALLOC8_SIZE_OK:
        LDX HEAP_PTR_LO
        LDY HEAP_PTR_HI

        CLC
        ADC HEAP_PTR_LO
        STA ALLOC_NEW_LO
        LDA HEAP_PTR_HI
        ADC #0
        BCS ALLOC8_FAIL
        STA ALLOC_NEW_HI

        LDA ALLOC_NEW_HI
        CMP HEAP_LIMIT_HI
        BCC ALLOC8_COMMIT
        BNE ALLOC8_FAIL

        LDA ALLOC_NEW_LO
        CMP HEAP_LIMIT_LO
        BEQ ALLOC8_COMMIT
        BCC ALLOC8_COMMIT

ALLOC8_FAIL:
        SEC
        RTS

ALLOC8_COMMIT:
        LDA ALLOC_NEW_LO
        STA HEAP_PTR_LO
        LDA ALLOC_NEW_HI
        STA HEAP_PTR_HI
        CLC
        RTS
```

This only allocates up to 255 bytes at a time. A later allocator can accept a
16-bit size by keeping `size_lo/size_hi` in zero page and doing a full 16-bit
addition and comparison.

## Byte, Word, And Pointer Requests

The allocator has only one primitive:

```text
allocate(n bytes)
```

Convenience names can sit on top:

```text
allocate byte:    allocate(1)
allocate word:    allocate(2)
allocate pointer: allocate(2)
```

Those three calls can all return the same kind of thing: a 16-bit address of
the first reserved byte.

## Allocating A Byte

A byte allocation reserves one address.

```text
ptr -> [ value ]
```

This is useful for isolated flags, counters, or small state values. It is not
the best way to manage many tiny values if the allocator has per-block headers.
A free-list allocator with a four-byte header would spend more memory on
metadata than on the one byte of payload.

For many single-byte objects, prefer one of these:

```text
fixed byte pool
bitset/bitmap
packed flags inside a record
```

## Allocating A Word

A word allocation reserves two consecutive bytes.

```text
ptr+0 = low byte
ptr+1 = high byte
```

The W65C02 stores 16-bit values little-endian:

```text
$1234 -> $34,$12
```

The CPU does not require word alignment. A word can begin at an odd address.
Optional even alignment can make dumps easier to read, but it wastes bytes and
should be a deliberate convention, not an assumed hardware rule.

## Allocating A Pointer

There are two separate ideas:

```text
the allocator returns a pointer
allocating storage that holds a pointer
```

The allocator returning a pointer means:

```text
allocate(16) returns $4000
```

That address is the start of 16 reserved bytes.

Allocating storage that holds a pointer means:

```text
slot = allocate(2)
```

Now `slot` points to two heap bytes that can store another address:

```text
slot+0 = target low byte
slot+1 = target high byte
```

Example:

```text
target = $6120

slot+0 = $20
slot+1 = $61
```

Pointer storage is structurally the same as word storage. The difference is
meaning: the word value is treated as an address.

## The Zero-Page Bottleneck

Heap memory should not live in zero page. Zero page is too small and too useful.
The current HIMON map leaves `$00-$CC` free from the monitor's point of
view while user code is running, but `$CD-$EF` and `$F0-$FF` are volatile
service/parser scratch windows.

The important W65C02 rule is that indirect data-addressing pointer variables
live in zero page:

```text
(zp),Y
(zp)
```

So a pointer stored in heap memory cannot be dereferenced directly as a heap
operand. The usual pattern is:

```text
1. Use a zero-page pointer to read the heap object.
2. Copy the two pointer bytes from heap into a zero-page temp pointer.
3. Use that zero-page temp pointer with indirect addressing.
```

This is why a future allocator design must reserve not just heap RAM, but also
a few zero-page lanes for active pointers and scratch. Those lanes must be part
of the routine contract, especially across monitor or ABI calls.

## Where A First R-YORS Heap Belongs

Do not silently claim a global heap in current HIMON/Himonia-F. The current RAM
map already gives strong ownership to monitor buffers, parser workspaces, flash
helpers, vectors, and user areas.

For experiments, the safest first model is app-owned:

```text
heap_start inside the user program area
heap_limit before monitor-owned buffers
heap_ptr reset when the program/session ends
```

In current map terms, that usually means staying inside the UPA-style user
space rather than crossing into high monitor buffers. A monitor-owned heap would
need an explicit reservation in `MEMORY_MAP.md` and clear clobber rules.

## Freeing Memory

The bump allocator does not free individual objects.

```text
allocate -> allocate -> allocate -> reset whole heap later
```

That is not a flaw for many 8-bit workloads. It is often the right shape for:

```text
load a level
assemble one input batch
build a temporary symbol table
stage records before writing flash
allocate app state at startup
```

The first improvement is mark/release:

```text
mark = heap_ptr
do temporary allocations
heap_ptr = mark
```

This gives stack-like lifetimes without per-block metadata.

## Free Lists And Fragmentation

A general `free` allocator needs metadata. One simple block shape is:

```text
size low
size high
next free low
next free high
payload...
```

That means even a one-byte allocation may consume five or more bytes. It also
means allocation may need to walk a linked list looking for a suitable block.
On a 1-2 MHz 8-bit CPU, that cost matters.

Fragmentation is the deeper problem:

```text
used free used free used
```

There may be enough free bytes total, but not enough contiguous free bytes for
the next request. Without an MMU or handle table, memory cannot be safely moved
after callers have been handed raw 16-bit addresses.

If arbitrary `free` is truly needed, use coalescing:

```text
when adjacent free blocks touch, merge them
```

Even then, fixed pools are often better for small common sizes.

## Practical R-YORS Direction

Use more than one allocator shape:

```text
bump allocator
  session, load, assemble, or startup lifetime

mark/release
  temporary nested work

fixed-size pools
  many byte, word, pointer, symbol, fixup, or record nodes

free-list heap
  only for a future use case that really needs arbitrary free/reuse
```

For STR8:

```text
no general heap
fixed buffers and fixed work areas
failure paths must be predictable
```

For HIMON/Himonia-F:

```text
not yet
start with app/session-owned allocation if needed
keep monitor hot paths and ABI services independent of heap state
```

For future hashed ASM/catalog work:

```text
symbol records and fixups may benefit from pools
temporary line/batch work may benefit from bump allocation
flash records should still follow append/verify/commit/condense policy
```

## First Implementation Checklist

Before writing a real R-YORS allocator, decide:

```text
owner       app, monitor session, assembler pass, or catalog staging
lifetime    reset-only, mark/release, fixed pool, or free-list
heap range  exact start/limit from the current memory map
zp lanes    temp pointers, result pointer, size, and scratch
ABI         registers returned, carry behavior, and clobbered bytes
failure     carry set, zero pointer, error code, or monitor message
```

Start with an 8-bit-size bump allocator. Add a 16-bit-size path only when a
caller actually needs allocations larger than 255 bytes. Add fixed pools before
adding a general free-list heap.
