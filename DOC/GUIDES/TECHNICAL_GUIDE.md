# R-YORS Technical Guide

R-YORS is the HIMON/ASM/OIL workbench. STR8-N is its independently built reset
and recovery supervisor. The repositories meet at a checked artifact and ABI
boundary, not through shared implementation source.

## Components

```text
physical RESET -> standalone STR8-N -> HIMON -> ASM-F2 / AP / debugger
                       |
                       +-----------> Bank 0-2 guest or Bank-3 reset vector
```

| Component | Repository | Main ownership |
| --- | --- | --- |
| ASM-F2 | R-YORS | `$8000-$BFFF`, onboard assembly and AP production |
| HIMON | R-YORS | `$C000-$EFFF`, monitor, loader, debugger, RJOIN/AP host |
| STR8-N | STR8-N | `$F000-$FFFF`, reset, vectors, recovery and guarded flash installation |

## Build Contract

`make -C SRC all` performs these gates:

1. Ask the configured adjacent STR8-N checkout to build its manifest.
2. Verify manifest schema, project/version, top-sector hash, public-contract
   hash, layout, service addresses, vectors, resident signature, and erased
   fresh-image directory/configuration pocket against
   `SRC/INTEGRATION/str8n.lock.json`.
3. Import only the verified generated `str8n-public.inc` into `SRC/BUILD/inc`.
4. Assemble/link ASM-F2 and HIMON.
5. Emit dense R-YORS `$8000-$BFFF`, `$C000-$EFFF`, and `$8000-$EFFF` S19
   payloads.

Normal development permits a dirty STR8-N checkout when its content still
matches the lock. `make release` additionally requires the external checkout
to be clean. The content lock deliberately avoids churn for docs-only STR8-N
commits.

Override a non-sibling checkout with:

```text
make -C SRC all STR8N_HOME="C:/path/to/STR8-N"
```

## Artifacts

The `RELEASE/` root publishes only board-facing products. Component images are
moved under `RELEASE/ARTIFACTS/COMPONENT-IMAGES/`:

```text
RELEASE/ARTIFACTS/COMPONENT-IMAGES/ryors-v1.2-asm-bank3-8-b.s19
RELEASE/ARTIFACTS/COMPONENT-IMAGES/ryors-v1.2-himon-bank3-c-e.s19
RELEASE/ryors-v1.2-himon-asm-bank3-8-e.s19
RELEASE/ryors-v1.2-str8n-himon-asm-bank0-2-8-f.s19
RELEASE/ryors-v1.2-str8n-himon-asm-bank0-2-8-f.bin
```

The adjacent STR8-N repository owns its 4K programmer BIN, resident/worker
S19, Bank Maintenance, top updater, directory refresh, manifest, public ABI,
and final 32K composition. Run there:

```text
make ryors-full-bank
```

AP transit tools are under `RELEASE/ARTIFACTS/AP-STORE/`; source and onboard
carriers are under `RELEASE/ARTIFACTS/SOURCES/`.

The composer validates every R-YORS S-record/checksum and range, appends the
current checked top image, and verifies RESET before writing the Bank-0/1/2
`8-F` payload. Bank-3 sector F is never included in a normal `I` update.

`himon-apv2-bank3-c-e.s19` is the explicitly named HIMON-only APv2 update:
12 KiB of dense S1 payload from `$C000` through `$EFFF`, followed by S9
`$C000`. It is accepted by STR8-N `I` with Bank 3 and range `C-E`, including
first enrollment or replacement of the normal `$C000` Bank-3 entry.

## Runtime Public Interface

HIMON includes only the generated external contract. The fixed v1.29 services
used or checked by R-YORS are:

```text
$F003   raw console initialization
$F006   resident ABI query
$F009   S-record parse/checksum service, SR/02 capabilities 03
$F010   bank-selection service
$F013   blocking character input
$F019   blocking character output
$F03E   non-consuming character-ready query
$0203   return-capable RAM bank selector
$7DFD-$7DFF   Bank Jump Record, "BJ" plus bank/FF
```

The full unified STR8-N worker runs at `$0200-$0453`; the selector needed by
HIMON ends at `$0228`. HIMON's banked-AP helper starts at `$0500`, and the
build rejects overlap if the external contract moves.

Private STR8-N worker modes, internal maps, resident labels, and directory
implementation details are not R-YORS interfaces.

## Loader Semantics

The two `L` commands intentionally differ:

| Context | Destination | S9 behavior |
| --- | --- | --- |
| HIMON `L` | RAM below `$7A00` | Reports S9; does not execute |
| STR8-N `L` | Recovery RAM `$2000-$7AFF` | Executes a valid in-range S9 |

HIMON accepts bare `L` only; `L G` and `L F` are usage errors. Explicit `G`
runs a HIMON-loaded program. STR8-N uses its load-and-run behavior for versioned
maintenance and recovery tools.

Both paths use STR8-N's `$F009` `SR/02` parser. HIMON has no private S19
decoder; it owns only its destination/copy/accounting and load-only session
policy, and refuses `L` before receive if STR8-N is absent or incompatible.

Both receivers poison a session after the first fatal record or destination
error. They stop applying S1 data and keep the command prompt closed while
discarding through a syntactically valid S9; Ctrl-C ends a truncated transfer.
This prevents the tail of a wrong RAM/flash file from becoming monitor input.

## Memory And Phase Ownership

The authoritative address list is the [Memory Map](MEMORY/MEMORY_MAP.md).
Important shared boundaries are:

```text
$0200-$19FF   ASM tables during assembly, STR8-N worker/staging during recovery
$1A00-$1AFF   APMAN command shadow during delegated AP operations
$1B00-$1FFF   user/free outside another phase owner
$2000-$6FFF   managed AP body destination range
$5000-$6D6D   ASM UDATA while ASM owns the phase
$6D6E-$6FFF   application/headroom outside ASM ownership
$7000-$7B11   transient APMAN body
$7A00-$7AFF   HIMON volatile command area
$7C00-$7DBF   single-owner high tool overlay
$7DC0-$7DC7   HIMON AP-link scratch
$7DE9-$7DFF   STR8-N state and Bank Jump Record
$7F00-$7FFF   I/O
```

ASM and a STR8-N recovery worker do not own low RAM simultaneously. A physical
reset or explicit handoff establishes the next phase.

## ASM/AP Path

ASM-F2 begins at `$800C` and emits normal code or an AP package. AP packages
can carry body bytes, relocation rows, exports, and resident imports. HIMON's
AP service validates the envelope, loads the body, resolves RJOIN imports,
applies relocations, and derives the entry.

The resident command bootstrap discovers the `AM01` APMAN carrier in Banks
2, 1, then 0, stages it, and loads its body at `$7000`. APMAN provides:

```text
AP Bn name|s000 [dst]     load/link/run an installed carrier
AP L Bn name|s000 [dst]   load/link without running
APS                       Bank 0-2 carrier/media status
APS Bn                    list valid carriers in one bank
APS Bn name|s000          show one carrier
INSTALL package Bn        choose the first fully erased 4K sector
```

APMAN stages banked media at `$0A00-$19FF`; managed child bodies may occupy
`$2000-$6FFF`. It rejects itself as a child and restores Bank 3 on every bank
operation path.

The current flash ASM occupies `$8000-$BD2A`; `_END_DATA=$BD2B` leaves `$02D5`
bytes through `$BFFF`. Its UDATA ends at `$6D6E` (exclusive). The resident
wrapper keeps AP-v2 package/load and APMAN-backed install support.

### Can one AP load another AP?

The basic loader mechanism is already public. `$7E2D-$7E2E` contains the AP
service pointer; a parent can use a local `JSR`-to-`JMP ($7E2D)` trampoline,
submit direct LOAD operation `$01` through the `$7E2F-$7E40` card, and receive
the linked child entry in X/Y. This works for a package already reachable in
RAM or currently visible flash, provided parent and child ranges do not
overlap.

Named banked-child execution is not yet a promised application ABI. Current
manager operation `$04` enters the APMAN bootstrap, but the caller must also
put `AP Bn ...` in HIMON's `$7A00` command buffer and set APMAN mode `$01` at
`$7C60`. HIMON then shadows the command at `$1A00`, loads APMAN, and APMAN
jumps to the child. With the service entered through `JSR`, the child's final
`RTS` can in principle unwind back to the parent.

That parent must remain outside APMAN `$7000-$7B11`, staging
`$0A00-$19FF`, shared service/card/ZP workspace, and the child's destination.
The manager and child also do not preserve an application-level register or
memory context contract. Therefore current supported practice is chaining at
the monitor/operator level: return from one AP, then issue the next `AP`.
A small explicit `AP_CHAIN` ABI should hide those private manager cells, state
which registers and memory survive, and be board-tested before applications
rely on parent-to-banked-child calls.

See the [APMAN/APC Dissection](ASM/APMAN_APC_DISSECTION.md) for the exact
carrier-sector, serialized-envelope, RAM-overlay, service-card, and execution
maps.

## Import And Export

Host-side export is complete for R-YORS S19 slices, the dense 28K payload, AP
packages, STR8-N guest normalization, and final 32K composition. The STR8-N
manifest records addresses, sizes, ABI values, and hashes for maintained
artifacts. Full flash export/readback remains an external programmer or host
tool operation; neither resident HIMON nor STR8-N exposes a general
flash-to-S19 export command.

## Documentation Status

`DOC/GUIDES/LOGS/` and dated STR8 board cards are immutable proof for the
images named in them. They may refer to the former integrated R-YORS STR8
source and targets. Current build and operation are defined by this guide, the
[Operator's Guide](OPERATORS_GUIDE.md), the [integration boundary](STR8/PRODUCT_BOUNDARIES.md),
and the standalone STR8-N documentation.
