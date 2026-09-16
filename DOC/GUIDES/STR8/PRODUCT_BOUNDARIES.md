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
STR8-N/BUILD/v1.34/include/str8n-public.inc
STR8-N/BUILD/v1.34/bin/str8n-v1.34-bank3-f000-ffff.bin
```

`SRC/INTEGRATION/str8n.lock.json` pins the accepted top image, public ABI
artifact, fixed layout, and service addresses. The normal build verifies the
external manifest before assembling HIMON. Release builds additionally reject
a dirty STR8-N worktree.

This is an exact image lock, not a minimum-version check. The accepted 1.34
resident ends at `$FCF1` with a 134-byte margin before its stored RAM worker
at `$FD78-$FFAF` (568 bytes, copied to `$0200-$0437`).
Its private loader paths publish the shared PIA LED status vocabulary while
the public raw console services remain LED-neutral. The top-sector and public
contract hashes are pinned explicitly. Future versions or different binaries
require another review.

## Image Boundary

```text
$8000-$BFFF  ASM-F2 and R-YORS low-flash space
$C000-$EFFF  HIMON
$F000-$FFFF  STR8-N protected top sector
```

R-YORS emits a dense 28K `$8000-$EFFF` S19. STR8-N's `ryors-full-bank` target
validates it and appends the current protected top to create a complete 32K
Bank-0/1/2 payload. R-YORS never constructs sector F.

The [current release shelf](../../../RELEASE/README.md) distributes three
separate packages: STR8-N v1.34, HIMON `00.0915(2324)`, and ASM-F2
`00.0915(2324)`. STR8-N includes its canonical top BIN, WDCMONv2 migration
kit, maintenance applications, and owner manuals. HIMON/ASM include their
component BIN/S19 and the combined `8-E` stream, relevant manuals, and
applications with license notices. No WDC firmware, owner bank dumps,
proprietary tools, BASIC, or Forth products are distributed. Life and
MicroChess retain their specified notices.

HIMON's BIN is a 12 KiB `C-E` component; ASM-F2's is a 16 KiB `8-B`
component. Neither includes sector F or forms a bootable whole bank. The
ASM-only S9 `$FFFF` retains an already enrolled HIMON `$C000` entry. Use
the combined image for first R-YORS enrollment or incomplete-install recovery.

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
