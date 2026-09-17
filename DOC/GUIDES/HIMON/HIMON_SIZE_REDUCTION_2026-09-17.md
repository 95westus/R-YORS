# HIMON Size Reduction — 2026-09-17

This records the first size-only stage. The subsequent message-page layout and
explicit `# ! NAME` feature are measured in the
[follow-up implementation note](HIMON_HASH_CALL_2026-09-17.md).

Unreleased, size-only source change against `61394ff`. No board installation or
hardware qualification has been performed. Optional interactive FNV execution
with return-register reporting is not implemented by this change.

## Linked Storage

Both measurements use the visible stamp `00.0916(1949)` to keep the comparison
independent of version text. This does not identify a new released image.

| Measurement | Before | After |
| --- | ---: | ---: |
| CODE | 11,106 bytes | 10,848 bytes |
| DATA (resident ROM data) | 1,174 bytes | 1,174 bytes |
| Total at `$C000` | 12,280 bytes | 12,022 bytes |
| End, exclusive | `$EFF8` | `$EEF6` |
| Space below STR8-N at `$F000` | 8 bytes | 266 bytes |

The reduction is **258 bytes**. The remaining contiguous space is
`$EEF6-$EFFF`, including the full 256-byte page `$EF00-$EFFF` plus ten bytes
before it. No block has been reserved or populated yet.

| Change | Bytes saved |
| --- | ---: |
| Compact flag display, including its eight-byte letter table | 68 |
| Share the existing string/newline helper at 26 call sites | 78 |
| Share G/AP launch tail | 37 |
| Share X/N resume tail | 22 |
| Reuse the resident ASCII-to-hex converter | 38 |
| Alias duplicate address and space printers | 15 |
| Total | 258 |

There is no added fixed RAM or zero-page allocation. All existing map symbols
below `$8000` retain their values. The flag loop uses one temporary stack byte;
non-tail calls to the shared string/newline helper add a two-byte return address
while printing. These are transient stack costs, not new reserved RAM.

## Behavior And Host Evidence

Launch and resume sharing uses jumps, preserving the existing launch/RTI stack
behavior. Display helpers may use private scratch registers but do not alter
the saved register context. The existing first `N/n` display uses entry carry,
not saved P bit 7; this behavior is intentionally retained in the size-only
change.

Focused linked-image checks pass for 512 flag displays, 512 full return reports,
quiet and live-trap return paths, 11 usage lines, shared printers, 256 hex input
bytes, 24 hex tokens, G/AP launch, X/N resume, all 256 opcode step displays,
262 FNV vectors, and 77 AP parse/load cases. The removed private hex converter
also matches its replacement for all 256 inputs in both binary and decimal
mode, including A/X/Y/P results.

The complete `asm-test` suite, `himon-banked-ap-check`, and
`himon-io-led-check` also pass. This includes AP contracts, scoped FNV lookup,
RAM-provider lookup and handoff, and STR8 client checks. `git diff --check`
passes; these are host checks, not board qualification.

Commands run successfully from the repository root:

```text
make -C SRC himon-size-check HIMON_VISIBLE_STAMP="0916(1949)"
python -B SRC/tools/check_himon_size.py --baseline SRC/BUILD/tmp/himon-compact-before/himon-rom-c000.s19
make -C SRC asm-test himon-banked-ap-check himon-io-led-check HIMON_VISIBLE_STAMP="0916(1949)"
git diff --check
```

The baseline S19 and matching map were saved locally before rebuilding; they
are ignored build artifacts, not release files. Board proof remains outstanding.
