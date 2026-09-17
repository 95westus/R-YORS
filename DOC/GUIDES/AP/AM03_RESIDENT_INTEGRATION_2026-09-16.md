# AM03 resident-miss integration

See [AP/FNV capabilities, limits and future work](AP_FNV_CAPABILITIES.md) for
the operator-level scope and the distinction between current and proposed features.

Status: installed with HIMON `00.0916(1949)`, STR8-N 1.35 and policy `$A6`.
Focused board handoff verification passes. The earlier reported handoff failure
was a test error: AM03 tail-enters silently and does not print AM02's `GO`
message. See the [corrected verification](../LOGS/AM03_BOARD_2026-09-16/HANDOFF_CORRECTION.md).
Physical-reset acceptance for this pair now passes, including post-reset
handoff and exact readback of all 32 flash sectors (see the correction above).

AM03 moves the manager BODY from `$7000` to `$6C00` and folds the proven RAM
AP uniqueness and safe-handoff routines into the manager. HIMON's bootstrap
requires the matching AM03 identity and tray address; resident precedence
remains unchanged. A miss now asks AM03 to
search the explicit `$3000-$3FFF` RAM window and policy-eligible B2/B1
carriers, reject a combined duplicate, repeat discovery, load/link the selected
BODY at `$2000`, retire discovery state, and enter the child through a normal
RTS return edge.

The transition owns staging `$0A00-$19FF`, command shadow
`$1A00-$1AFF`, state `$1B00-$1B1F`, the private scope card
`$7D40-$7D5F`, and the manager card only while discovery is live. Those
ranges are zeroed before child entry and before a failure returns. The provider
window is read-only. The second validated stage is the sole load/link source.

Linked measurements:

| Item | Range or size |
| --- | --- |
| AM03 BODY | `$6C00-$7BB0`, `$0FB1` (4017 bytes) |
| Runtime tray margin | 79 bytes through `$7BFF` |
| AP v2 envelope | `$0FDF` (4063 bytes) |
| Carrier erased tail | 33 bytes |
| Child destination | `$2000`; BODY length 1 through `$1000` |

Host gates cover resident precedence, B2/B1/B0 policy behavior, exact PACK40
names through 31 characters, malformed and duplicate providers, imports,
double-scan provider change, staged tampering, child A/carry preservation,
state retirement, 33,270 destination-range cases, legacy APMAN operations and
the full accepted readback. The readback audit found BANKAUDIT, Microchess,
APTEST and BANKDUMP all ending below `$6C00`; the earlier AM02 manager in that
baseline audit was excluded from the child ceiling. Current HIMON requires AM03;
that older AM02 image is not a drop-in manager for the current pair.

The retained [host qualification record](../LOGS/AM03_HOST_2026-09-16.md)
captures the full gate result and exact candidate identities.

Generated host reports are:

- `SRC/BUILD/tmp/am03-layout.json`
- `SRC/BUILD/tmp/fnv-ram-ap-handoff.json`
- `SRC/BUILD/tmp/fnv-scope.json`
- `SRC/BUILD/tmp/himon-ap-ranges.json`

Board verification now covers bare bank APTEST loading, a unique RAMTEST child
that writes an execution marker, provider preservation, state retirement, and
BANKDUMP imports/menu/map/return. Successful automatic dispatch is silent;
verify child effects rather than requiring `GO` or `AP LOAD` banners.
The tests use the existing `$3000-$3FFF` RAM window. Physical reset, all three
post-reset handoff checks, and full-flash isolation pass; SPI SRAM support
and allocation remain deferred.
