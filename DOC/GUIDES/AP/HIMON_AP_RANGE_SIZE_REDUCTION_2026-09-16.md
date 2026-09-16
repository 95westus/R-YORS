# Resident AP range-check size reduction - 2026-09-16

The resident source-base and destination-range predicates now branch to their
existing nearby bad-range exits. No accepted source/destination window, status,
register result, copy order, or service entry changes. This is the first resident
size slice after the 41-byte APMAN reduction.

| Measurement | Before | After | Saving |
| --- | ---: | ---: | ---: |
| Source-base predicate | 38 | 32 | 6 bytes |
| Destination-range predicate | 130 | 116 | 14 bytes |
| HIMON occupied bytes | 11,868 | 11,848 | 20 bytes |
| HIMON end, exclusive | `$EE5C` | `$EE48` | 20 bytes |
| HIMON reserve below `$F000` | 420 | 440 | +20 bytes |
| ASM-F2 occupied bytes | 15,235 | 15,235 | 0 bytes |
| APMAN BODY / overlay reserve | 3,031 / 41 | 3,031 / 41 | 0 bytes |

All 20 saved bytes are Bank-3 resident code. External package sizes, allocated
flash sectors, RAM allocation and call depth do not change. No wrapper or table
is added. The manager's 555-byte worker is unchanged.

The linked-code sweep compares the old and new A/X/Y/P/SP, all AP scratch bytes
in `$7E20-$7E4F`, and ordered memory writes. It also checks the result against
independent address-window rules and rejects writes outside that scratch span.
It passes 30,710 destination cases and all 256 source high-byte cases. The
destination sweep covers both operations, every high byte, low bytes
`$00/$01/$FE/$FF`, zero and large lengths, and lengths on either side of the
protected boundaries and 16-bit overflow. It is not an exhaustive Cartesian
product of all 16-bit destinations and lengths.

In this linked layout, observed predicate execution cost changes by -5 to +1
cycles. At the board's 8 MHz clock, the largest observed added cost is 0.125
microseconds per invocation. There are no additional calls or stack bytes.
The slower initialization-loop candidate remains a separate change because its
early-error register behavior needs separate qualification.

## Reproduction and board card

Freeze `HIMON_VISIBLE_STAMP=0915(2324)` when comparing this slice. The maintained
`himon-ap-range-check` target runs through `himon-ap-contract-check` and
`asm-test`. The optional `--baseline-build` argument to
`SRC/tools/check_himon_ap_ranges.py` adds exact old/new comparisons.

```text
make -C SRC "HIMON_VISIBLE_STAMP=0915(2324)" asm-test himon-banked-ap-check himon-str8-record-check himon-io-led-check board-s19-check himon-rom-bin
python -B SRC/tools/check_himon_ap_ranges.py --baseline-build LOCAL/himon-ap-range-size-20260916/before --output LOCAL/himon-ap-range-size-20260916/ranges-comparison.json
```

After host gates pass, capture a fresh four-bank backup and verify it against
the previous accepted board image. Install only the dense HIMON `$C000-$EFFF`
payload using STR8-N `I / 3 / C-E`. Require exact immediate readback and preserve
ASM, the STR8 code/configuration and all other banks; only the documented D3
installation-journal bits may change outside C-E.

Exercise ordinary LOAD and TAKEOVER on both sides of `$5000`, `$7000` and
`$7C00`, checking exact status, copied bytes and rejection redzones. Exercise
accepted stage/RAM sources and rejected gap/top-page sources. Then verify the
installed manager, typed imports through BANKAUDIT, fresh ASM execution,
persistent APTEST, stale-resume rejection, software W/C recovery and physical
RESET. Capture final four-bank readback and retain all serial traffic.

Host and board acceptance results belong in the
[qualification record](../LOGS/HIMON_AP_RANGE_SIZE_2026-09-16.md).
