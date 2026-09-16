# HIMON/AP baseline - 2026-09-16

Result: Step 1 is complete. The host baseline is reproducible, existing host
checks pass, every emitted HIMON byte is assigned once in the size ledger,
and a read-only COM4 capture identifies the current Bank-3 image. No firmware
source, ABI, RAM allocation, carrier placement, or flash contents changed.

This completes the build/measurement step of the agreed sequence. The full
interface and RAM-lifetime audit is Step 2; source extraction follows it.
The broader Phase 0 in the four-module plan therefore remains partially open.

## Source and build provenance

- R-YORS revision: `2fb6a9fe1f0ac81491dfa7e448e7671755fd63b3`.
- Existing dirty work: RTERM demo files/Makefile additions, ASM documentation,
  and BSO2 hardware records. The initial status, patch, file hashes, and source
  snapshot were retained; those changes were not reverted.
- STR8-N revision: `846032d48e4345e389dfd6b0b5d40c1e70e10129`, clean at capture;
  exact integration lock is version 1.34.
- Canonical STR8-N top SHA-256:
  `9538D97854BA9D5D76143CBA0FEDB3B2E7CE18F977CE89557406E63404026CB7`.
- Public contract SHA-256:
  `947F8D096EBE42CE07C072E179B618115341E390D0975131B6204D863C95E4DD`.
- WDC assembler 3.49.1 (February 6, 2006); linker 3.49.1 (April 24, 2006);
  GNU Make 3.81; Python 3.13.14; py65 1.2.0 in the existing local test
  dependency directory; pyserial 3.5. Executable paths and hashes are retained
  in [environment.json](HIMON_AP_BASELINE_2026-09-16/environment.json).
- Both builds use `HIMON_VISIBLE_STAMP=0915(2324)`, matching the published
  component stamp. The stamp target's incidental logo change was restored to
  the exact pre-task bytes after both builds.

The initial build forces HIMON, the ASM flash wrapper, and APMAN source
prerequisites and runs:

```text
make -C SRC "HIMON_VISIBLE_STAMP=0915(2324)" \
  -W HIMON/himon.asm -W ASM/asm-v1-flash.asm -W APPS/apman-7000.asm \
  asm-test himon-banked-ap-check himon-str8-record-check \
  himon-io-led-check board-s19-check himon-rom-bin
```

The second build additionally forces all assembly/include prerequisites under
HIMON, LIB, ASM, APPS and TESTS, rebuilding the library/runtime inputs as well
as the top-level components. Its targets are `himon-rom asm-v1-flash apman
board-s19-check`. Exact argument arrays, working directories, start/end times,
and exit codes are in [build-1.json](HIMON_AP_BASELINE_2026-09-16/build-1.json)
and [build-2.json](HIMON_AP_BASELINE_2026-09-16/build-2.json).

Both runs exit zero. The second run reproduces these 12 artifacts byte for
byte: HIMON, ASM-F2 and APMAN S19/map pairs; APMAN AP envelope; APMAN carrier
BIN/S19; ASM-only, HIMON-only and combined 28K installation S19 streams.
The complete measurement JSON is also identical. See
[reproducibility.json](HIMON_AP_BASELINE_2026-09-16/reproducibility.json).
Assembly listings contain wall-clock headings and are preserved as evidence,
not asserted to be byte-identical.

## Measured image and ownership ledger

| Component | Emitted bytes | End exclusive | Contiguous headroom |
| --- | ---: | --- | ---: |
| HIMON including resident AP | 11,754 | `$EDEA` | 534 below `$F000` |
| ASM-F2 | 15,235 | `$BB83` | 1,149 below `$C000` |
| APMAN BODY | 3,068 | `$7BFC` | 4 below `$7C00` |

HIMON CODE is 10,580 bytes and DATA is 1,174 bytes. The physical ownership
partition is 2,966 dedicated AP bytes, 2,681 shared-support bytes, and 6,107
other HIMON bytes. HIMON excluding dedicated AP is therefore 8,788 bytes,
including those shared groups. Shared groups include catalog UI and linked
console/flash/debug support; this is not the minimum dependency closure of a
standalone AP loader or an estimate of removable bytes. Initialization and
the MicroChess launcher remain in the monitor group.

The [generated ledger](../../GENERATED/HIMON_AP_BASELINE.md) gives exact
symbol-bounded ranges, ownership totals, CODE/DATA accounting, hashes, and
padding. Its generator rejects missing/overlapping S19 addresses, invalid
checksums, range/accounting disagreement, package/BODY disagreement, and
non-erased carrier tails. Four negative checks actually exercised corrupted
S19, a mismatched map end, a damaged AP BODY, and a damaged carrier tail.

APMAN's envelope adds 46 bytes to BODY, yielding a 3,114-byte (`$0C2A`)
package. Its 4K carrier has 982 erased tail bytes. Its 555-byte stored flash
worker is already included in BODY. The misleading raw linker
`_END_CODE=$EBFC` must not be used as a CPU end; `APMAN_IMAGE_END=$7BFC`,
S19 coverage, and package BODY agree.

No component has an emitted hole. Dense HIMON and ASM component BINs are
12,288 and 16,384 bytes respectively, including FF padding. The legacy
`himon-rom-bin` target also produced its existing 32K image with private
vectors; that artifact is archived but is not the canonical STR8-N component
or an installation recommendation. The baseline's normalized component BINs
contain only `$C000-$EFFF` and `$8000-$BFFF` respectively.

ASM UDATA is `$5000-$6D6D`, 7,534 allocated bytes, and is not emitted ROM.
APMAN occupies `$7000-$7BFB` while active. Runtime RAM high-water, stack bounds,
and overlapping scratch lifetimes have not been newly qualified by this
measurement step; those remain explicit Step-2 work.

Regenerate the ledger from the frozen first build with:

```text
python SRC/tools/report_himon_ap_baseline.py \
  --build-dir LOCAL/himon-ap-baseline-20260916/build-1 \
  --markdown DOC/GENERATED/HIMON_AP_BASELINE.md \
  --json LOCAL/himon-ap-baseline-20260916/ledger.json
```

The displayed multiline commands use shell-neutral line wrapping for
readability; run them on one line in Windows PowerShell.

## Validation

The [first build log](HIMON_AP_BASELINE_2026-09-16/build-1.log) retains the
full `asm-test` results: ABI ownership, AP Store format/inventory/sector/chain/
delete checks, instruction coverage, runtime/error/rollback checks, package
identity, and size checks. Focused HIMON checks also pass, including 256
opcode displays, 262 FNV vectors, 77 AP parse/load cases, bank-stage behavior,
relocation access, STR8 record integration, and live I/O LED behavior.

`board-s19-check` passes all nine identity targets on both builds. This is
host packaging validation, not a new flash installation or board execution
acceptance. The [second build log](HIMON_AP_BASELINE_2026-09-16/build-2.log)
records the forced rebuild and repeated packaging gate.

`git diff --check` passes. Final source-manifest comparison confirms that no
preexisting firmware/tool source or unrelated dirty file changed. The original
hardware-log byte prefix is hash-identical; only the new entry was appended.

## COM4 read-only identity evidence

COM4 at 115200 baud was already at HIMON. DTR/RTS were held false. The only
transmitted commands were `?` and `D 8000 FFFF`. No helper was loaded, no
program was launched, no bank was selected, and no reset or flash mutation
was requested. The complete 32K dump has exactly one byte per address and
SHA-256:

`99d80e2e7f98a11a03ff8fff56b260c02c9b18f1cd7d2ca05ba7dbd4789d0234`.

It exactly matches the retained Bank-3 readback after the September 16 BSO2
installation. The board still contains HIMON `00.0915(2233)` and ASM-F2
`00.0915(2243)`. Comparison against the frozen host build finds only six
HIMON timestamp bytes and three ASM timestamp bytes different; every other
component byte and padding byte agrees. The differing addresses and decoded
strings are in [board-verification.json](HIMON_AP_BASELINE_2026-09-16/board-verification.json).
Configuration remains `1E 1F FF FF FF FF FF FF FF FF`.

The new [raw transcript](HIMON_AP_BASELINE_2026-09-16/com4.jsonl) is retained
separately from historical transcripts. COM4 was closed at the HIMON prompt.
This check does not requalify AP carriers, physical RESET, or LED observation.
Bank 2 remains unchanged; the operator has designated its BSO2 contents as
temporary validation and permits future erasure/reuse for AP tooling.

## Retained evidence and next step

`LOCAL/himon-ap-baseline-20260916/` contains the initial source snapshot,
preexisting artifacts, both build snapshots, normalized component BINs,
per-snapshot file manifests, build logs, and raw Bank-3 BIN/text capture.
Each original artifact snapshot contains 186 files. The normalized component
BINs were added afterward and their dense hashes are in the generated ledger.

The versionable [evidence manifest](HIMON_AP_BASELINE_2026-09-16/manifest.json)
hashes the environment/source manifest, initial diff, commands, build logs,
ledger, serial transcript, comparisons, and local capture script sources.
Archived script copies document execution from their original
`LOCAL/himon-ap-baseline-20260916/` location; they are not entry points to run
from this log directory. No release artifacts were republished.

Next: finish the interface and RAM-lifetime audit against this exact baseline,
then extract resident AP blocks in place. No feature checkbox is closed by
the baseline alone, and R-YORS II proposals are outside this work.
