# HIMON/AP manager presentation boundary - 2026-09-16

This Phase-2 slice gives HIMON ownership of the manager bootstrap's command
shadow and diagnostic text. AP retains source validation, status decisions,
ASM-session invalidation, manager discovery/loading, and checked bank staging.
The three moved blocks remain inline at their original assembly positions;
they are not callable routines or new public interfaces.

| HIMON source owner | Linked bytes | Contract at the include boundary |
| --- | --- | --- |
| `himon-ap-manager-source-error.inc` | `$D42B-$D43A`, 16 bytes | AP has set both status cells to `$D4`; HIMON prints `APERR=$D4` and CRLF. AP then reloads A from manager status and returns C=0. |
| `himon-ap-manager-shadow.inc` | `$D443-$D44D`, 11 bytes | Copy all 256 bytes from `CMD_BUF` `$7A00-$7AFF` to `$1A00-$1AFF`, including bytes after NUL. Source and adjacent destination bytes are preserved. Fall through to discovery. |
| `himon-ap-manager-missing.inc` | `$D4BE-$D4C7`, 10 bytes | After discovery is exhausted, HIMON prints `APMAN NF` and CRLF. AP then sets A/AP status/manager status to `$DA` and returns C=0. |

The includes preserve the enclosing global label and the command copy's
existing `?CMD_COPY` local label. They add no wrapper call, return, scratch
allocation, branch, or public symbol. The command copy leaves X=0; diagnostic
output uses the existing volatile registers and console scratch. AP's
post-output status reload remains in place.

## Ordering and ownership

Unstable or malformed INSTALL sources fail before command copying, selector
copying, staging, or overlay loading. These early failures retain the prior
ASM-resume flag. Valid manager entry clears `$7E6A`, shadows the command page,
then discovers/stages the manager. A missing or corrupt manager still clears
resume because discovery has used the old ASM workspace.

HIMON owns this private command-page convention because APMAN's
`$7000-$7BFF` BODY overwrites the original command buffer. APMAN continues to
parse the shadow using its existing request card. This slice does not redesign
that protocol or make the resident MANAGER operation console-independent.

AP's bootstrap no longer directly references `CMD_BUF`, diagnostic strings,
or the three output helpers. It still uses the documented shared foreground
pointer/scratch cells. FNV, catalog lookup through the preceding HIMON
resolver adapter, STR8's published bank-selector ABI, and AP wire format
remain unchanged.

## Verification and tooling

The source boundary gate rejects direct command-buffer access, diagnostic
output, or missing-manager string access added back to AP's bootstrap. Its
previous catalog checks remain intact: five bypass negatives now run in total.
The linked-code boundary suite adds seven manager cases to the six resolver
cases:

- AP, APS, and validated INSTALL each copy the entire command page, including
  an early NUL and the last byte, with adjacent sentinels intact. These three
  tests stop immediately before the first sector-stage call.
- Unstable `$0A00` and malformed `$3000` INSTALL input return exact `$D4`
  diagnostics/results while preserving low/application/overlay RAM and resume.
- Absent and corrupt managers return exactly one `APMAN NF` line and `$DA`
  results, with the full command shadow retained and Bank 3 restored.

The emulator forbids flash writes. Completed calls balance their stacks;
the three pre-stage stops are partial-path checks, not completed calls. The
existing 53-case contract suite covers the remaining manager/child, INSTALL,
takeover, and ASM continuation behavior.

Both HIMON object targets already depend on all HIMON includes. Structural
checks expand the new files; release source-reference bundles include them.
The documentation generator now derives each inline fragment's parent label
from its include site, preserving call/stack edges that would otherwise be
dropped before a fragment's first global label. Generated files remain outputs
of their maintained generators.

The [evidence record](../LOGS/HIMON_AP_MANAGER_BOUNDARY_2026-09-16/manifest.json)
tracks full regression and exact linked artifact/symbol comparison against the
preceding [resolver boundary](HIMON_AP_BOUNDARY_2026-09-16.md).
The full regression passes, including 53 contract cases, 13 boundary cases,
five bypass negatives, and the nested manager-include cycle rejection. All
15 S19/BIN/AP/map artifacts and every linked symbol are identical, with no
timestamp exclusions. The expanded instruction/declaration sequence also
matches. Generated graph/stack content is preserved; only document timestamps,
source-file count, and detailed source-line references are excluded from the
document comparison.

ROM/RAM growth and added calls are zero. HIMON remains 11,868 bytes with 420
bytes free; ASM remains 15,235 bytes with 1,149 bytes free; APMAN remains 3,072
BODY bytes with no overlay headroom. No size saving is claimed by this move.
No COM4 access or board programming is part of this source-ownership slice.
Existing [Bank-2/reset proof](../LOGS/HIMON_AP_BANK2_2026-09-16.md) identifies
the installed firmware and carriers. Visual LED acceptance and NMI remain
separate hardware work.

The remaining shared scratch, FNV, and session-lifetime dependencies are
intentional contracts. The next useful implementation candidate is a measured
APMAN size reduction; its overlay still has no spare bytes.

Reproduce with the frozen stamp:

```text
make -C SRC "HIMON_VISIBLE_STAMP=0915(2324)" asm-test himon-banked-ap-check himon-str8-record-check himon-io-led-check board-s19-check himon-rom-bin
```
