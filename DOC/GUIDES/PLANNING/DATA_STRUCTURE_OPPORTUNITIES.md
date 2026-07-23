# Data Structure Opportunities Audit

Status: planning audit recorded 2026-07-22. No source-layout or runtime change
is implied by this document.

R-YORS already uses compact logical records throughout HIMON, STR8, and ASM.
The useful next step is not to make the W65C02 runtime look like a high-level
language. It is to give shared byte layouts one source of truth while retaining
the physical forms that keep the machine code small.

## Working Rule

Separate the logical schema from its physical representation:

```text
logical row or ABI
  -> named fields, offsets, widths, limits, and invariants
  -> compact runtime representation selected for the access pattern
```

An interleaved record is appropriate when code walks one complete record.
Parallel arrays remain appropriate when W65C02 code selects the same field from
many slots with `absolute,X`. A shared include or source manifest can define the
schema without forcing either representation.

## Priority 1: Small Shared Schemas

### Resident FNV records

The current HIMON record is described in
[`himon.asm`](../../../SRC/HIMON/himon.asm):

```text
+0  'F'
+1  'N'
+2  ('V'|$80)
+3  hash0
+4  hash1
+5  hash2
+6  hash3
+7  kind
+8  inline code or entry_lo
+9  entry_hi when the kind carries pointers
+10 extra_lo when the kind carries text
+11 extra_hi when the kind carries text
```

The scanner and join routines currently use literal offsets such as `$03`,
`$07`, `$08`, and `$0A`. Define named `CMD_FNV_OFF_*` values and the applicable
header/pointer record sizes, then use those names in both record readers and
emitters. This can be a source-only clarification with no ROM-byte change.

Keep each record beside the code or metadata it publishes. The ROM scan and
first-match behavior are part of the discoverable-record design; this audit
does not recommend a centralized command registry.

### STR8 worker state board

The `$1FE9-$1FFF` state board is one shared fixed-address structure. Its fields
are currently repeated in:

- [`str8.asm`](../../../SRC/STR8/str8.asm)
- [`str8-worker.asm`](../../../SRC/STR8/str8-worker.asm)
- [`himon.asm`](../../../SRC/HIMON/himon.asm)

A narrow `str8-worker-state-eq.inc` could define a base, field offsets, size,
end address, and explicitly reserved offsets. STR8, the copied worker, and
HIMON would consume the same contract. Preserve all addresses and document the
currently unused gaps instead of closing or repurposing them incidentally.

### HIMON published service block

The canonical `$7E00` service and AP request/result cells live in
[`himon-shared-eq.inc`](../../../SRC/HIMON/himon-shared-eq.inc). Selected
addresses and values are repeated with ASM-local names in
[`asm-v1-core.asm`](../../../SRC/ASM/asm-v1-core.asm) and
[`asm-v1-flash.asm`](../../../SRC/ASM/asm-v1-flash.asm).

Extracting the public subset into a narrow `himon-service-eq.inc` would let the
publisher and consumers share signature, version, vector, checksum, request,
and result definitions. Private monitor workspace and lifetime aliases should
remain in `himon-shared-eq.inc`.

### AP package format

The serialized AP package schema is defined independently under `ASM_*` names
in [`asm-v1-core.asm`](../../../SRC/ASM/asm-v1-core.asm) and under `HIM_AP_*`
names in [`himon.asm`](../../../SRC/HIMON/himon.asm). The repeated facts include:

- `AP` signature and version;
- header offsets and length;
- `S`, `R`, `E`, `I`, and `B` section tags;
- seal-record size;
- relocation kinds and serialized row shape.

Move only serialized-format facts into an `ap-package-eq.inc` contract. Keep
implementation policy local: RAM/flash bounds, scratch addresses, parser state,
and current table capacities are not necessarily properties of the on-media
format. Prefix aliases may be retained temporarily if they make the first
change smaller and easier to compare.

The existing [`str8-record-eq.inc`](../../../SRC/STR8/str8-record-eq.inc) is the
model for this kind of shared fixed ABI.

## Priority 2: Structured Metadata Sources

### W65C02 opcode description

Opcode facts currently appear in three useful but manually synchronized forms:

- ASM opcode rows and pointer shards in
  [`asm-v1-core.asm`](../../../SRC/ASM/asm-v1-core.asm);
- HIMON mnemonic and instruction-length tables in
  [`himon.asm`](../../../SRC/HIMON/himon.asm);
- the independent coverage oracle in
  [`check_asm_opcode_coverage.ps1`](../../../SRC/tools/check_asm_opcode_coverage.ps1).

If table churn justifies another generated artifact, a canonical descriptor can
hold mnemonic, opcode, addressing mode, and instruction length, then emit the
different compact assembler and disassembler forms. The runtime tables should
remain specialized for their inverse access patterns. Keep independent spot
checks and shape checks so a generator defect cannot validate its own output.

### ASM vocabulary

ASM vocabulary identity is spread across `ASM_VID_*` constants and the
`ASM_VOC_HASH0..3` and `ASM_VOC_KIND_TAB` arrays in
[`asm-v1-core.asm`](../../../SRC/ASM/asm-v1-core.asm). A canonical vocabulary
row would contain at least:

```text
token, stable id, kind, hash32, active/parked role
```

It could emit the existing structure-of-arrays representation and verify that
all arrays contain `ASM_VOC_COUNT` elements. Stable IDs must remain explicit;
sorting or adding a token must not silently renumber the established vocabulary.

## Structures To Preserve

The following ASM tables are already logical records stored as parallel arrays:

- session symbols (`ASM_SYM_*`);
- local labels (`ASM_LOCAL_*`);
- fixups (`ASM_FIX_*`);
- relocation rows (`ASM_RELOC_*`);
- vocabulary hashes and kinds (`ASM_VOC_*`).

This is deliberate and is documented in
[`HASHED_ASM.md`](../ASM/HASHED_ASM.md). Converting these tables to interleaved
rows would make ordinary field scans require stride arithmetic or extra pointer
work. Prefer field-count assertions, common limit constants, and accessor
routines where serialized layouts are variable-length.

The overlays in `himon-shared-eq.inc` are also deliberate lifetime unions, not
duplicate allocations. They would benefit from named block boundaries and
overlap checks, but aliases should not be separated unless their lifetimes
actually overlap.

## Useful Invariants

Any later implementation should add or retain checks for these properties:

- a shared ABI base plus final offset equals its declared end and size;
- every consumer sees the same signature, version, tags, and status values;
- every structure-of-arrays field contains the declared slot count;
- reserved fixed-address bytes remain reserved;
- AP serialized constants match between producer, parser, linker, and docs;
- the disassembler describes all 256 opcode positions;
- ASM opcode rows still pass the independent coverage audit;
- generated tables are byte-stable when their logical source has not changed.

## Safe Implementation Order

1. Name the HIMON FNV offsets and replace literals, proving identical output.
2. Introduce one shared fixed-address include at a time, beginning with the
   STR8 worker state or HIMON public service block.
3. Extract AP serialized constants without moving parser or linker code.
4. Add count/end assertions around existing parallel arrays.
5. Consider opcode or vocabulary generation only after the schemas and their
   independent checks are stable.

For each step, keep the change inspectable, run `make -C SRC asm-test` where ASM
is affected, run the relevant full-image build for shared ABI changes, compare
binary/map output when a no-byte-change result is expected, and finish with
`git diff --check`. Hardware transcripts remain append-only evidence and are
not rewritten by schema cleanup.
