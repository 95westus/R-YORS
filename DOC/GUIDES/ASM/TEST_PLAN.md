# ASM Current Test Plan

This is the current, compact acceptance plan for ASM-F2 and its AP/OIL
boundary. Completed chronological gates were moved intact to
[TEST_HISTORY.md](TEST_HISTORY.md). Board transcripts remain in the
[hardware test log](../LOGS/HARDWARE_TEST_LOG.md).

For live commands and ownership, the
[capability matrix](../CAPABILITIES.md) is authoritative.

## Acceptance Rule

An ASM feature is complete only when all applicable gates agree:

1. source and generated contracts are current;
2. focused host regression tests pass;
3. the full ASM regression target passes;
4. resident size and memory ownership remain within their frozen bounds;
5. operator and technical documentation describe the resulting behavior;
6. destructive, banked, or board-specific behavior has recorded hardware
   proof.

The feature queue in [TODO.md](../PLANNING/TODO.md) remains unchecked until
those gates agree.

## Host Gate

Run the complete supported suite:

```text
make -C SRC asm-test
```

The text-diagnostic emulator check uses pinned `py65==1.2.0`. Install once
from the repository root with:

```text
python -m pip install --target SRC/BUILD/tmp/asm-error-deps py65==1.2.0
```

That target includes the ASM ABI, AP Store, APMAN, opcode, compact-data,
terminal, STR8 read-only bank-tool, WDC comparison, runtime, paste, flash,
session-report, AP-v2, BANKAUDIT, BANKDUMP, PIA carrier, and exhaustive error checks declared by
`SRC/Makefile`.

Useful focused gates are:

```text
make -C SRC asm-abi-check
make -C SRC asm-opcode-coverage
make -C SRC asm-dc-check
make -C SRC asm-error-check
make -C SRC asm-ap-v2-check
make -C SRC ap-store-v1-check
make -C SRC ap-store-inventory-check
make -C SRC ap-store-sector-tool-check
make -C SRC ap-store-chain-tool-check
make -C SRC ap-store-slice6-tool-check
make -C SRC himon-banked-ap-check
make -C SRC himon-str8-record-check
make -C SRC himon-io-led-check
make -C SRC str8-readonly-bank-tools-check
```

Run `git diff --check` before accepting documentation or source changes.

## HIMON Live USB LED Acceptance (2026-09-10)

Status: host-qualified and board-accepted on COM4.

HIMON's private `HIM_READ_BYTE_BLOCK` now polls
`BIO_FTDI_READ_BYTE_NONBLOCK`. While no byte is available it resamples PWE#
through `SYS_CHECK_ENUMERATED` and updates `$21`/`$43` only when the indicated
host state changes. Host-bearing `$07`, `$0B`, and `$43` remain undisturbed
while PWE# stays asserted, so a partial-line `$07` remains visible. If PWE#
deasserts it changes to `$21`; a later assertion changes `$21` to `$43`.

This is HIMON-only policy. STR8-N is unchanged, both raw BIO blocking FNV
records remain LED-neutral, and ASM-F2 inherits the behavior only through the
HIMON line-input service vector. Single-character HIMON confirmations call the
same private wait routine.

The focused `himon-io-led-check` freezes the cooperative loop and both linked
transition paths in addition to the existing activity veneers, raw FNV
pointers, service-vector routing, and ROM bound. The candidate ends at
`_END_DATA=$EE95`, leaving `$016B` bytes below STR8-N at `$F000`; it adds no
fixed RAM. The focused check and complete `asm-test` suite pass; flash ASM
remains unchanged at `_END_DATA=$BD95`.

Board acceptance is recorded by the
[live USB LED board card](../HIMON/HIMON_LIVE_USB_LED_BOARD_TEST_2026-09-10.md).
The guarded Bank-3 C-E install returned `OK` and cold-entered exact HIMON
`00.0910(1202)`. The board then accepted live HIMON `$43 -> $21 -> $43`,
latched-RX `$07 -> $21 -> $43`, ASM-F2 `$43 -> $21 -> $43`, and a harmless
single-character confirmation `$0B -> $21 -> $43`. Physical RESET returned
through STR8-N 1.32 and warm-entered the same HIMON identity at `$43`. The
hardware log retains the exact transcript and operator LED observations.

## HIMON I/O LED Acceptance (2026-09-06)

ASM-F2 requires no private LED code. Its input routines resolve to HIMON's
resident `SYS_READ_CSTRING*` records, and its output shims use the fixed `RY`
service-vector block. HIMON now publishes `$21`/`$43` before a line wait,
latches `$07` after receive, and publishes `$0B` before output at those shared
boundaries. The service-vector addresses, order, count, signature, checksum
shape, and ABI version remain unchanged.

The raw `BIO_FTDI_READ_BYTE_BLOCK` and `BIO_FTDI_WRITE_BYTE_BLOCK` FNV records
still point directly to their LED-neutral entries. A user application that
wants all eight Port A bits can use those raw services or STR8-N's public raw
console ABI; calling the HIMON service vector opts into HIMON's display policy.

The focused `himon-io-led-check` validates the exact linked PIA stores, wrapper
targets, service-vector words, raw FNV pointers, and `$F000` margin. The full
ASM host suite passes with flash ASM unchanged at `_END_DATA=$BD95`. The COM4
board run accepted:

1. `$43` at the HIMON prompt with the FTDI host present;
2. `$07` after a partial HIMON line and after a partial ASM-F2 source line;
3. `$0B` latched by an ASM-F2 program that emits through the `$7E08` HIMON
   service vector and then loops; and
4. physical RESET recovery to STR8-N 1.31, HIMON, and `$43`.

The focused [HIMON I/O LED board card](../HIMON/HIMON_IO_LED_BOARD_TEST_2026-09-06.md)
records the installed identity, transfer hash, transcript summary, and observed
LED values. The detailed observations are appended to the hardware log.

## Text Diagnostics Accepted (2026-09-05)

The focused emulator runner `SRC/tools/check_asm_errors.ps1` passes against
the linked resident ASM image and existing HIMON ROM image. Console I/O and
service discovery are simulated; ASM instructions, resident FNV/hex/PACK40,
and AP parse/package services execute from their S19 bytes. Flash writes are
mocked. This is host execution evidence, not board proof.

- All 256 values pass in four rendering contexts (1,024 checks), including
  unknown status bounds and exact `A/C/X/Y` failure returns.
- Native parser versus seal/AP worker routing, SEAL flags, and READ failures
  pass 2,550 injected command cases; two-address INSTALL adds 255 cases.
- All 23 prefix/suffix/PC-address checks pass, including shared strings.
- Real inputs exercise statuses `$01,$03-$09`, addressing/width/range errors,
  duplicate/reserved/out-of-scope names, symbol rows/name pool/fixup exhaustion,
  missing END, invalid seals, malformed APs, and atomic partial-line and
  `$7CFF/$7D00` boundary rollback. `$02` and legacy `$0A` are tested by injection;
  the current source vocabulary has no producing directive/local-NYI case.
- Startup/service failure, saved-session refusal, `.P`, sticky session status,
  NEW, successful assembly/SEAL/RELOCATE/PACKAGE/LOAD (and optional CHECK),
  and legacy flash-failure mapping pass.
- The optional CHECK build passes the same tests plus 510 CHECK parser/worker
  cases. It uses a **host-only** separate CODE `$8000` / DATA `$7080` layout:
  optional CHECK does not fit the contiguous resident budget and stays disabled.
  Never install `BUILD/tmp/asm-errors-check/optional.s19` on the board.

Resident measurement: CODE `$3AE0`, DATA `$02B5`, UDATA `$1D6E`;
`_END_DATA=$BD95`, headroom `$026B` (619 bytes), above the `$0200` reserve.
Compared with the previous `$BD2B` artifact, this costs `$006A` (106) ROM
bytes and zero additional RAM. Context decoding accounts for the growth beyond
the original size-neutral estimate. Every compact message pointer passes the
map check; the contiguous message span is limited to 256 bytes.

Tested candidate: `ASM-F2 00.0905(2321)`, S19 SHA-256
`1C69CB555AD6F999661F7339DB475F11FC17F5CADA3E69525F8C41A1CD37F1EA`.
HIMON ROM S19 used for the emulator services: SHA-256
`AE8C8E28BD826654144F07EEB8E93DB3EF2C7A51A8A63EA8B7D3DF84E31A97DD`.
Generated session-report samples were refreshed from the changed helper
addresses; the reporter continues to expose numeric diagnostic status.

The full `make -C SRC asm-test` gate now passes, including every formerly
blocked external-contract branch. The exact lock is advanced from 1.29 to
the conservative STR8-N 1.30 image; the public ABI hash is unchanged. Version,
ROM hash, ABI hash, layout, and service-address checks remain strict. Negative
fixtures reject old/future version locks, wrong ROM/ABI hashes, old resident
end, and a changed record-service address; the clean accepted image passes.

`make -C SRC board-s19-check "HIMON_VISIBLE_STAMP=0905(2321)"` also passes
all nine payload identity comparisons. Freeze this stamp when reproducing
the board candidate; ordinary builds deliberately generate a new timestamp.
With already-built images, run the focused runner from `SRC` directly:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File tools/check_asm_errors.ps1
```

The [board card](TEXT_ERRORS_BOARD_TEST.md) passed its diagnostic cases on
COM4 at 115200 baud, with unchanged HIMON `00.0902(1707)` and STR8-N 1.30.
Exact 16K ASM readback and preservation of HIMON/STR8 code passed; only the
expected D3 installation-journal pair changed. Operator-confirmed physical
RESET passed with a complete receive-only STR8-N 1.30 selector, default warm
boot, and HIMON prompt trace. Post-reset ASM retained its identity and text
errors; a fresh session passed assembly/SEAL/PACKAGE/LOAD and exact `A9 AC 60`
readback. The feature queue is now accepted. Detailed evidence is in
[the new hardware record](../LOGS/ASMF2_TEXT_2026-09-05.md).

## Current Board Gate

For changes that touch the onboard path, prove only the affected rows plus the
short regression rail:

- boot through STR8-N into the expected HIMON/ASM-F2 identity;
- assemble a known-good source and confirm emitted bytes and status;
- `SEAL`, `PACKAGE`, and direct AP load/link where applicable;
- `INSTALL package Bn`, reset-time rediscovery, `APS`, named `AP`, and `AP L`
  for carrier or manager changes;
- missing-import, overlap, malformed-envelope, and bank-restore rejection for
  AP/OIL changes;
- before/after sector or bank CRCs for every flash mutation;
- physical reset recovery to Bank 3 after banked work.

Record the exact image identity, commands, output, CRC evidence, and result in
the hardware log. Do not copy the whole procedure into the log; link this plan
or a focused board card and retain only evidence needed to distinguish the
run.

## Current Accepted Baseline

The capability matrix identifies the live release and board-accepted surface.
Baseline changes belong there first; this plan deliberately does not duplicate
the version and status narrative.

## Evidence Placement

| Information | Canonical home |
| --- | --- |
| Live commands, versions, and ABI ownership | `CAPABILITIES.md` |
| Current acceptance requirements | this file |
| Exact focused procedure | a narrowly scoped board card |
| Executed transcript and observed result | `LOGS/HARDWARE_TEST_LOG.md` |
| Completed development chronology | `TEST_HISTORY.md` |

Distinct failures, retries, corrections, and final acceptance runs are not
duplicates. Keep them when they explain why the accepted result is trustworthy.
