# R-YORS / STR8-N Product Boundary

STR8-N is an independent adjacent repository. R-YORS no longer carries a
second live copy of its resident, worker, installer, top-updater, or directory
implementation.

## Ownership

| Product | Owns |
| --- | --- |
| R-YORS | HIMON, ASM-F2, OIL/AP integration, `$8000-$EFFF` payloads, and the locked STR8-N consumer contract |
| STR8-N | RESET supervision, `$F000-$FFFF`, hardware vectors, worker, bank directory, install/recovery tools, full-bank composition, manifest, and public ABI |
| HIMON | Monitor commands, RAM-only/load-only `L`, debugger, AP loading/linking, and the default Bank-3 payload |
| ASM-F2 | Onboard source entry, assembly, AP construction, and optional AP checking |

The normal workspace is:

```text
parent/
  R-YORS/
  STR8-N/
```

R-YORS consumes only:

```text
STR8-N/BUILD/str8n-manifest.json
STR8-N/BUILD/v1.21/include/str8n-public.inc
STR8-N/BUILD/v1.21/bin/str8n-v1.21-bank3-f000-ffff.bin
```

`SRC/INTEGRATION/str8n.lock.json` pins the accepted top image, public ABI
artifact, fixed layout, and service addresses. The normal build verifies the
external manifest before assembling HIMON. Release builds additionally reject
a dirty STR8-N worktree.

## Image Boundary

```text
$8000-$BFFF  ASM-F2 and R-YORS low-flash space
$C000-$EFFF  HIMON
$F000-$FFFF  STR8-N protected top sector
```

R-YORS emits a dense 28K `$8000-$EFFF` S19. STR8-N's `ryors-full-bank` target
validates it and appends the current protected top to create a complete 32K
Bank-0/1/2 payload. R-YORS never constructs sector F.

## Runtime Boundary

HIMON binds only to the generated public contract. Current integration uses
the fixed record service, bank-select service and RAM selector, raw console
services, RAM ownership limits, and Bank Jump Record. Private STR8-N labels,
worker modes, and source maps are not R-YORS interfaces.

STR8-N `L` loads a recovery S19 in `$2000-$7AFF` and executes S9. HIMON `L`
loads RAM and reports S9 but does not execute; `L G` and `L F` are rejected.

## Historical Evidence

The older `DOC/GUIDES/STR8/` board cards and `DOC/GUIDES/LOGS/` transcripts
remain hardware evidence for the images named in those records. They are not
current build instructions. Current STR8-N operation and releases are
documented in the standalone repository.
