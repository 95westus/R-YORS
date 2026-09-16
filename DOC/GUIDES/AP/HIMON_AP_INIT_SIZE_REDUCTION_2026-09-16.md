# Resident AP parser initialization reduction - 2026-09-16

The six contiguous BODY pointer/length and relocation/import-count cells at
`$7E37-$7E3C` now clear through one indexed STZ loop. Four separate pointer
cells still clear individually. The loop does not include the install-result
cells at `$7E3D-$7E3E`.

| Measurement | Before | After | Difference |
| --- | ---: | ---: | ---: |
| Six-cell clear | 18 bytes | 8 bytes | -10 bytes |
| Complete ten-cell clear | 30 bytes / 40 cycles | 20 bytes / 77 cycles | -10 bytes / +37 cycles |
| HIMON occupied bytes | 11,848 | 11,838 | -10 bytes |
| HIMON end, exclusive | `$EE48` | `$EE3E` | -10 bytes |
| HIMON reserve | 440 bytes | 450 bytes | +10 bytes |
| ASM-F2 occupied bytes | 15,235 | 15,235 | unchanged |
| APMAN BODY / overlay reserve | 3,031 / 41 bytes | 3,031 / 41 bytes | unchanged |

The clear block adds 37 cycles, or 4.625 microseconds at the board's 8 MHz
clock. Whole-PARSE measurements across 51 fixtures add 29-37 cycles
(3.625-4.625 microseconds), including the effects of moved branch addresses.
No calls, stack bytes, RAM cells, tables or external package bytes are
added. Both resident variants save ten bytes; no flash sector is released.

X finishes the clear loop at `$FF`. Early errors can therefore return a
different X value. The published [ABI](../ASM/ASM_ABI_V1.md) makes X volatile
on failure; successful PARSE still returns the source address in X/Y. No
preservation wrapper is needed. A, Y, flags, status, observed stack depth,
all non-stack RAM and the set of written non-stack addresses match the old
parser in the focused fixtures. Initialization store order changes inside
the existing foreground, non-reentrant operation.

## Host checks

`himon-ap-init-check` runs through `himon-ap-contract-check` and `asm-test`.
The checker asserts the six-cell linked layout, runs all 256 incoming X values
against four RAM fill patterns, and checks the entire RAM region for unexpected
writes or changed guard cells at the end of initialization. All 1,024 clear
cases pass. The old/new block measurement is 40 versus 77 cycles.

Another 153 parser cases cover three incoming X values, stage and RAM sources,
page-crossing BODY lengths, exports, invalid source windows, corrupt headers,
tags, seals and BODY bytes, and truncated sections. All public results and
guard cells agree. X differs in 38 early-failure comparisons, as permitted by
the ABI; success X/Y agrees exactly.

```text
make -C SRC "HIMON_VISIBLE_STAMP=0915(2324)" asm-test himon-banked-ap-check himon-str8-record-check himon-io-led-check board-s19-check himon-rom-bin
python -B SRC/tools/check_himon_ap_init.py --baseline-build LOCAL/himon-ap-init-size-20260916/before --output LOCAL/himon-ap-init-size-20260916/init-comparison.json
```

## Board card

After host gates pass, take a fresh full flash backup and compare it to the
preceding range-size qualification. Install only B3:C-E through STR8-N I,
then verify the complete Bank-3 readback and the permitted D3 journal change.

The focused RAM caller seeds the ten parser cells and two install-result
guards with `$A5`, then invokes PARSE with X=`$00/$A6/$FF`. Bad-source and
bad-signature cases must return the expected status, X=`$FF`, zero parser
outputs and intact install-result guards. Valid parsing must preserve those
guards and return the source in X/Y. Follow with source/destination boundaries,
persistent manager/import/BANKAUDIT, fresh ASM/APTEST, warm/cold recovery,
physical RESET and final four-bank readback with sector CRC comparison.

Acceptance and exact image identities are recorded in the
[qualification record](../LOGS/HIMON_AP_INIT_SIZE_2026-09-16.md).
