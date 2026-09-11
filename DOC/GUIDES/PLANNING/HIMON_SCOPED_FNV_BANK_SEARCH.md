# HIMON Scoped FNV And AP Bank Search

Status: accepted design direction; not current command behavior. No source,
RAM address, Bank-3 configuration byte, operator command, host check, or board
proof is complete merely because this contract is documented.

Scope: this is the bounded first external-discovery proof for current HIMON and
AP carriers. It intentionally preserves resident-first lookup and rejects
duplicate external names. It is not the final generation-aware replacement
policy. The sibling R-YORS II planning repository defines that later work in
`DOC/DYNAMIC_FNV_PROVIDER_REGISTRY_PROPOSAL.md`: B3 becomes a baseline
provider, while a higher active compatible generation in any operator-enrolled
B0-B2 managed store may shadow it after candidate testing and atomic promotion.

This plan gives HIMON a bounded way to resolve a public FNV-1a name outside its
resident Bank-3 catalog. The immediate proving case is `BANKDUMP`: after the
resident lookup misses, HIMON may find the one fully valid AP-v2 carrier whose
entry export names `BANKDUMP`, retain its bank and sector, then perform the
logical equivalent of `AP Bx BANKDUMP` through the normal stage, validate,
load, relocate, link, restore-Bank-3, and execute path.

The design keeps three questions separate:

```text
identity       which canonical public name/hash is wanted?
eligibility    which external flash banks may ever provide it?
request scope  which eligible banks and RAM windows should this lookup visit?
```

FNV-1a answers identity. Bank-3 `$FFF2` answers persistent external-bank
eligibility. RAM request bytes answer the scope of one lookup. None of those
fields replaces record/container validation.

## Current Facts That Must Not Be Reinterpreted

- Current HIMON resident records use
  `'F','N',('V'|$80),hash0,hash1,hash2,hash3,K,payload...`.
- `K` describes hot-path record shape and execution behavior. It is not a bank
  selector, permission byte, storage state, or search request.
- Current `THE_JOIN_FIND` and `THE_JOIN_EXEC_XY` return resident callable
  addresses. A banked AP result is instead a carrier location that must be
  staged and linked before execution. The two result contracts remain separate.
- An AP-v2 carrier does not become a resident HREC merely because its export
  row carries an FNV32 name. AP signature, bounds, seal, BODY FNV, export row,
  kind, and entry metadata must all validate.
- For the accepted BANKDUMP image, `$71516DF1` is FNV-1a of the uppercase public
  name `BANKDUMP`. `$CEF1F837` is the currently accepted BODY FNV. The first
  locates the named export; the second proves the current BODY bytes.
- Bank 3 remains the recovery root and owns the policy. Bank 0 currently holds
  WDCMONv2 and is not an FNV/AP provider. Banks 1 and 2 are the only enrolled
  external lookup banks in the initial policy.

## Persistent External-Bank Eligibility

The accepted future use of Bank-3 configuration byte `$FFF2` is:

```text
bits 7-3  %10100      scoped AP/FNV bank-policy signature/version 0
bit 2     Bank 2 may be searched
bit 1     Bank 1 may be searched
bit 0     Bank 0 may be searched
```

Named values are:

```text
$A0  no external bank
$A1  B0
$A2  B1
$A3  B0+B1
$A4  B2
$A5  B0+B2
$A6  B1+B2       initial policy for the present board
$A7  B0+B1+B2
$FF  absent/unconfigured: automatic external search disabled
```

Any value whose upper five bits are not `$A0` is invalid. Invalid and erased
`$FF` values both produce an allowed-bank mask of zero. They do not fall back
to a compiled B0-B2 scan. Resident HIMON lookup and explicit physical
diagnostics remain available; automatic external discovery does not guess.

The initial board policy will become `$A6` only through a separately specified,
host-checked, full Bank-3:F update and board proof. Until that happens,
`$FFF2-$FFF9` remain physically erased and unassigned under the current
implemented configuration contract.

B0, B1, and B2 are symmetric in the policy encoding. `$A6` is the initial
choice because the present B0 contains opaque WDCMONv2; it is not a permanent
architectural reservation. An enrolled bank may mix opaque, reserved, carrier,
and AP Store sectors. Enrollment permits bounded discovery, not mutation, and
only format-valid candidates are considered.

The `$A6` bit pattern is deliberately flash-conservative:

```text
$A6 = %10100110
                 ^ B0 allow bit is zero
```

Ordinary flash programming can only change `1` to `0`. A torn or additional
bit-clear can therefore remove an allowed bank or invalidate the `$A0` policy
signature, but it cannot change B0 from excluded to enrolled. Enrolling B0
requires the explicit full-sector rewrite described below.

`$FFF2` is read only while Bank 3 is selected. The decoded low-three-bit mask
is copied to RAM before any bank change because `$FFF2` in Bank 0, 1, or 2 is
an unrelated byte in that bank's opaque `$F000-$FFFF` image.

Conceptual decode:

```asm
FNV_POLICY_LOAD:        LDA             $FFF2
                        PHA
                        AND             #$F8
                        CMP             #$A0
                        BNE             ?ABSENT
                        PLA
                        AND             #$07
                        STA             FNV_ALLOWED_BANKS
                        RTS
?ABSENT:                PLA
                        STZ             FNV_ALLOWED_BANKS
                        RTS
```

The final source may use a smaller equivalent routine. The behavior, not these
labels or bytes of code, is frozen by this design.

## RAM Request And Result Card

The live scanner uses a RAM card. Exact addresses are deliberately not assigned
until the HIMON/APMAN overlay audit is complete. The card must survive FNV
updates, AP parsing, sector staging, and calls that clobber shared zero page.

Minimum request fields:

```text
FNV_REQUEST_BANKS       bit 0=B0, bit 1=B1, bit 2=B2
FNV_ALLOWED_BANKS       decoded persistent policy
FNV_EFFECTIVE_BANKS     REQUEST AND ALLOWED
FNV_BANK_WINDOWS        bits 0-7 select bank sectors $8-$F
FNV_RAM_ENABLE          zero=no RAM; nonzero=use RAM window mask
FNV_RAM_WINDOWS         bits 0-7 select CPU windows $0-$7
FNV_FORMAT              HREC or AP_EXPORT; never infer one from the other
FNV_WANTED_HASH0..3     stable little-endian FNV32 target
```

Minimum result fields:

```text
FNV_MATCH_COUNT         zero, one, or saturated duplicate count
FNV_FOUND_SOURCE        RAM or external bank
FNV_FOUND_BANK          0-2 for an external AP result
FNV_FOUND_WINDOW        RAM window or flash sector high nibble
FNV_FOUND_ADDR_LO/HI    bounded candidate/record address when applicable
```

The effective external mask is always:

```asm
                        LDA             FNV_REQUEST_BANKS
                        AND             FNV_ALLOWED_BANKS
                        STA             FNV_EFFECTIVE_BANKS
```

A request cannot add a bank that persistent policy excludes. With current
policy `$A6`:

```text
request  $07   asks for B0+B1+B2
allow    $06   permits B1+B2
result   $06   searches B2 and B1; never selects B0
```

## Fixed Search Order

The accepted order is:

```text
1  resident Bank-3 HIMON HREC lookup
2  explicitly selected RAM windows
3  eligible Bank 2 AP sectors, $8 through $F
4  eligible Bank 1 AP sectors, $8 through $F
5  eligible Bank 0 AP sectors, $8 through $F
```

Resident HREC lookup remains authoritative. If it finds an executable record,
HIMON does not search RAM or AP carriers for a shadow with the same hash. This
protects recovery commands and preserves current command dispatch.

RAM is a fallback only when the caller explicitly enables it and supplies a
nonzero RAM-window mask. External banks are considered in B2/B1/B0 order to
match current APMAN discovery and the present carrier layout. Within one bank,
sectors are visited in ascending CPU order, `$8000` through `$F000`.

The bank order does not make the first external hit a winner. The scanner must
visit all enabled external locations and require one unique fully validated
match. Search order controls traversal and diagnostics; uniqueness controls
execution.

After the resident HREC miss, the uniqueness set includes every selected RAM
and eligible banked provider visited for the requested `FNV_FORMAT`. An explicit
RAM window does not silently shadow a second valid AP export in flash; the two
matches produce duplicate failure until a later, separately accepted provider-
precedence rule exists.

```text
zero matches    not found
one match       retain location and continue through normal AP load/run
two or more     duplicate; report locations and do not execute
```

Conceptual match handling:

```asm
?MATCH:                 INC             FNV_MATCH_COUNT
                        LDA             FNV_MATCH_COUNT
                        CMP             #$01
                        BNE             ?KEEP_SCANNING
                        LDA             CURRENT_BANK
                        STA             FNV_FOUND_BANK
                        LDA             CURRENT_SECTOR
                        STA             FNV_FOUND_WINDOW
?KEEP_SCANNING:         RTS
```

The real implementation must prevent count wrap or saturate at two.

## Bank-Zero WDCMONv2 Rule

With `$FFF2=$A6`, Bank 0 is outside the catalog provider set until a deliberate
configuration change enrolls it. The following operations must not select or
scan Bank 0 for a name:

```text
automatic resident-miss fallback
automatic APMAN discovery
AP wildcard/scoped named discovery, if such syntax is later exposed
AP B0 name
any other named FNV/AP resolver using this policy
```

This does not make Bank 0 unreadable or unbootable. These remain separate
operations and are not governed by the catalog-search mask:

```text
J0 handoff to WDCMONv2
BANKDUMP physical inspection of B0
read-only CRC or audit of B0
explicit recovery/maintenance operations with their own authority
```

An explicit named lookup against a disabled bank must reject before bank
selection. A compact diagnostic such as `FNV B0 OFF` or `AP B0 OFF` may be
chosen during implementation; exact message text is not frozen here.

If Bank 0 is later replaced with a catalog-capable/AP-bearing system, enrolling
it changes `$FFF2` from `$A6` to `$A7`. That transition requires setting a
flash bit from zero to one, so it necessarily uses the guarded full-sector
stage/erase/rewrite/verify path. That cost is appropriate: changing an opaque
guest bank into an executable provider is a bank-role change, not a transient
search option.

## Selective RAM Search

RAM is never enabled by persistent `$FFF2` policy. It is session/request state.
The compact RAM-window mask is:

```text
bit 0  $0000-$0FFF
bit 1  $1000-$1FFF
bit 2  $2000-$2FFF
bit 3  $3000-$3FFF
bit 4  $4000-$4FFF
bit 5  $5000-$5FFF
bit 6  $6000-$6FFF
bit 7  $7000-$7EFF only
```

`$7F00-$7FFF` is I/O and is never scanned as memory. Selecting RAM window 7
clips the scan at `$7EFF`.

The caller must also respect live ownership:

```text
$0000-$01FF   zero page and hardware stack
$0200...      RAM bank selector/trampoline while active
$0A00-$19FF   AP sector staging
$7000...      APMAN/tool overlay
$7C00...      command cards and high overlays
```

The first implementation should prove one ordinary development window such as
`$3000-$3FFF`, not an all-RAM scan. A staged AP sector must not be rediscovered
as a second RAM copy of the same bank candidate. RAM AP lookup, if implemented,
must require a bounded AP envelope in an allowed RAM range; arbitrary BODY code
or a loose four-byte hash is not an AP candidate.

Examples:

```text
RAM $3000-$3FFF only
    FNV_REQUEST_BANKS = $00
    FNV_RAM_ENABLE    = $01
    FNV_RAM_WINDOWS   = $08

B2 plus RAM $2000-$2FFF
    FNV_REQUEST_BANKS = $04
    FNV_RAM_ENABLE    = $01
    FNV_RAM_WINDOWS   = $04
```

## BANKDUMP Resolution

The intended successful path on the present board is:

```text
operator supplies BANKDUMP
  -> canonical uppercase FNV32 = $71516DF1
  -> resident Bank-3 HREC lookup misses
  -> decode Bank-3 $FFF2=$A6 as allowed mask $06
  -> request mask AND allow mask = B1+B2
  -> RAM disabled unless the caller explicitly requested it
  -> discover/load APMAN only through eligible banks, B2 then B1
  -> scan all B2 sectors $8-$F
       B2:9 validates and exports BANKDUMP
  -> scan all B1 sectors $8-$F for a duplicate
  -> do not select B0
  -> require match count one
  -> load/relocate/link the B2:9 BODY at its declared destination
  -> restore Bank 3
  -> execute the exported entry
```

The implementation may pass the found bank/hash directly through an APMAN mode
and command card. It need not manufacture literal command-line text. The
observable operation is equivalent to `AP B2 BANKDUMP`, but avoiding a second
parse and second complete scan is preferable.

APMAN bootstrap and target discovery use the same persistent external-bank
eligibility. If APMAN exists only in a disabled bank, automatic AP lookup fails
closed. The direct visible-RAM AP recovery path remains the way to repair or
replace the manager/configuration without weakening the mask.

## Failure Rules

The scoped resolver fails without execution when any of these is true:

```text
$FFF2 is $FF or has an invalid policy signature
request AND allowed bank mask is zero and RAM is not enabled
requested RAM mask is zero
bank selection or Bank-3 restoration fails
candidate AP signature/version/bounds/seal/BODY FNV fails
entry export is missing, wrong-kind, malformed, or out of bounds
no fully valid matching public name exists
more than one fully valid matching public name exists
AP load, relocation, import link, or final entry validation fails
```

A raw FNV collision is not sufficient for execution. Where the AP export row
retains canonical name length and PACK40 text, the promoted automatic resolver
should compare that proof after the hash rather than treating FNV32 alone as
the complete identity.

Every bank-changing body executes from RAM with interrupts controlled and
restores Bank 3 before returning to HIMON or calling a Bank-3 service. No
alternate-bank instruction fetch, stack return, message output, or service call
is allowed.

## Non-Goals

This design does not:

- change the current HREC `K` byte;
- make STR8 recovery or `J0` use FNV;
- make WDCMONv2 catalog-aware;
- authorize mutation of a searchable bank;
- turn BANKDUMP physical inspection into catalog discovery;
- let a RAM request override persistent flash-bank exclusion;
- choose a newest AP generation when duplicate public names exist;
- assign or compare global provider generations;
- distinguish installed candidates from atomically activated providers;
- allow an external provider to shadow a resident B3 implementation;
- quiesce or rebind live routine callers;
- freeze a public command spelling, RAM ABI address, or service-vector slot;
- declare `$FFF2` implemented before its update/check/board gate passes.

Those lifecycle and precedence rules belong to the proposed Dynamic FNV
Provider Registry. Completing this scoped search proves bank policy,
format-specific validation, uniqueness, restoration, and load/link mechanics
that the later registry can reuse; it must not freeze resident-first precedence
as the final R-YORS II behavior.

## Implementation Slices And Gates

Implement only after this design is queued against current higher-priority AP
work and the HIMON/APMAN RAM overlays are frozen.

1. Add host tests for `$FFF2` decode: `$FF` and invalid values disable automatic
   external lookup; `$A0-$A7` decode exactly; `$A6` produces `$06`.
2. Add a RAM-only proof for request/allow intersection, B2/B1/B0 traversal,
   sector `$8-$F` traversal, unique-match counting, duplicate rejection, and
   Bank-3 restoration. Prove that `$06` never invokes Bank-0 selection.
3. Add format-specific validators. HREC search and AP-export search must share
   range mechanics where useful but retain different proof and result paths.
4. Extend APMAN or a small shared manager mode to accept a stable hash and
   effective bank/sector masks without reparsing a fabricated command line.
5. Integrate resident-miss fallback only after the explicit scoped lookup is
   host-proven and size-measured. Resident hits must remain unchanged.
6. Allocate `$FFF2`, update STR8 configuration constants/integration metadata,
   build a guarded Bank-3:F update, and verify `$A6` on the board.
7. Board-prove `$FF` fail-closed behavior, B2:9 BANKDUMP resolution, B0 omission,
   malformed-carrier rejection, duplicate rejection, optional RAM-window
   behavior, AP load/link/run, and final Bank-3 restoration.
8. Update current operator/reference/map documents only when implemented bytes,
   size, command behavior, and hardware evidence agree.

Until all applicable gates pass, the existing explicit `AP Bn name`, APMAN,
APS, BANKDUMP, resident HREC lookup, Bank-3 configuration, and board transcripts
remain the source of truth.
