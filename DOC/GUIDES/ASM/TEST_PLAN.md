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

AM03 automatic handoff is silent. Its board oracle must observe a child-written
RAM marker, a fresh loaded BODY, retired scope/staging state, or actual
BANKDUMP menu/map/return; do not require the legacy `GO`/`AP LOAD` messages.
The [corrected AM03 verification](../LOGS/AM03_BOARD_2026-09-16/HANDOFF_CORRECTION.md)
passes these checks on the installed pair. The separate physical-reset gate
also passes, with all three handoff checks repeated and all 32 flash sectors
matching the expected image. Preserve earlier failed harness transcripts as historical
evidence, not as proof that child execution failed.

The [safe RAM AP handoff proof](../AP/RAM_AP_HANDOFF_2026-09-16.md) adds
`make -C SRC fnv-ram-ap-handoff-check` to `asm-test`. Require two complete
uniqueness passes with exact location/entry/BODY agreement, bounded load to
`$2000-$2FFF`, resident relocation/import linking, final canonical entry
revalidation, and complete card/name/stage/private-state retirement before
child entry or failure return. Assert no provider or flash write, no staged or
provider execution, no foreign-ROM fetch, no entry after any link failure, and
ASM-resume invalidation on every path. Require balanced child `RTS` return with
child A/flags preserved. Board proof uses only
RAM transients and accepted flash carriers; no flash update is part of this
slice.

The [RAM AP/combined uniqueness proof](../AP/RAM_AP_UNIQUENESS_2026-09-16.md)
adds `make -C SRC fnv-ram-ap-check` to `asm-test`. Require bounded full-envelope
copy before PARSE, canonical-name and entry validation, duplicate saturation
across RAM/banks, exact policy/window/role intersections, safe restore-error
propagation and unique-location revalidation. Assert provider immutability,
no provider load/link/entry, no out-of-window reads and no foreign ROM fetch.
Board proof uses existing flash carriers, temporary RAM envelopes and complete
before/after flash archives. Pin private helper addresses and image identities
in exported metadata; keep command-execution acceptance separate.

The [initial RAM HREC proof](../AP/RAM_HREC_PROOF_2026-09-16.md) adds
`make -C SRC fnv-ram-hrec-check` to `asm-test`. Require linked-byte validation
of the one-window request, supported HREC shapes, all record/pointer boundary
cases, terminated text, duplicate saturation and cleared failure results.
The memory model must reject provider writes, I/O/flash access and execution
outside the inspector. Board proof uses RAM-only drivers and exact before/after
four-bank archives; this is not acceptance of integrated RAM command lookup.

The [scoped FNV integration candidate](../AP/HIMON_SCOPED_FNV_IMPLEMENTATION_2026-09-16.md)
has two `asm-test` prerequisites. Run
`make -C SRC fnv-scope-policy-check fnv-scope-check`.
Require every policy/request byte pair, invalid/erased-policy refusal,
`$A6` and every additional bit-clear excluding B0, only the three declared
card writes, bounded code/stack/card reads, and balanced return for the 28-byte
policy primitive. The linked check must also cover traversal order, bank and
sector intersections, protected roles, AM01 refusal/AM02 bootstrap, resident
precedence, canonical name and entry bounds, malformed/duplicate refusal,
unique revalidation, real BANKDUMP import linking and RAM-safe bank restoration.
Require no flash writes and no instruction fetch from foreign-bank ROM.
RAM-provider/HREC search remains an implementation gate. Coordinated
installation, policy provisioning, physical reset and final flash isolation
remain required board gates.

The subsequent no-WORK/B2:F role candidate must also prove B1:E/F are ordinary
locations, B2:F is excluded from discovery and manager bootstrap, and all 24
APMAN role-guard locations leave exactly B2:F protected. STR8's
`bank-maint-role-check` retains both layouts; `top-backup-role-check` executes
backup and recovery for all updater variants. Before board migration preserve
readbacks, inspect B2:F, and retain the old B1:F backup until the new one verifies.
These migration/readback gates now pass on COM4; physical reset and final four-bank isolation pass
([evidence](../LOGS/SECTOR_ROLES_BOARD_2026-09-16.md)). Scoped discovery and all 24 AM02 role-guard board tests now pass. The pair is now installed with `$A6`;
[step-2 smoke](../LOGS/SCOPED_SMOKE_BOARD_2026-09-16.md) passes disabled/enabled
APTEST, direct RAM AP, ASM, physical reset and exact final isolation. The [wider banked AP matrix](../LOGS/SCOPED_QUALIFICATION_2026-09-16.md) now passes:
B1/B2 BANKDUMP and imports, malformed/duplicate refusal, resident precedence,
paced operator LED confirmation with actual PCR samples, reset and final
four-bank isolation. Only B2:A and expected B3:F directory/journal bytes differ
from the step-2 baseline; B1:A is restored erased.

The [2026-09-16 follow-up](../LOGS/AP_FNV_FOLLOWUP_2026-09-16.md) completes
Microchess's physical-reset discovery/bare-launch gate. Repeated B0/B1/B2
APS scans produced operator-observed LED activity; exact bank/sector sequence
identification was still open in that earlier record. The later qualification
closes the scoped B1/B2 display gate with separately recorded human
observations; serial output alone is not visual proof.

The [2026-09-16 AP interface/RAM audit](../AP/HIMON_AP_INTERFACE_RAM_AUDIT_2026-09-16.md)
adds a separate 23-case characterization run against the frozen Step-1 images:

```text
python -B SRC/tools/audit_himon_ap_contracts.py --output DOC/GUIDES/LOGS/HIMON_AP_AUDIT_2026-09-16.json
```

Run that command from the repository root. It characterizes existing behavior,
including known faults; passing does not accept those faults. It uses no serial
port and stops INSTALL before its flash worker. Before accepting a manager
contract correction, require stable-source rejection before bootstrap, explicit
ASM session invalidation/preservation, deterministic absent-manager failure,
single duplicate-status propagation, exact range/size checks, full regression,
and the relevant board lifecycle/reset proof. The
[functional correction](../AP/HIMON_AP_CONTRACT_CHANGE_2026-09-16.md) now has 53 passing
linked-code cases and 13 COM4 checks, including software warm/cold entry.
`make -C SRC himon-ap-contract-check` runs the current acceptance assertions;
it is part of `asm-test`. The old audit remains a historical characterization.
The [typed-import boundary slice](../AP/HIMON_AP_BOUNDARY_2026-09-16.md) adds
`himon-ap-boundary-check`: six linked resolver cases and two source-boundary
negative fixtures. It runs through the same contract target and requires
exact artifact/symbol identity for this source-only ownership change.
The [manager presentation slice](../AP/HIMON_AP_MANAGER_BOUNDARY_2026-09-16.md)
extends that gate to 13 linked cases (six resolver, seven manager) and five
source bypass negatives. Require all 256 command bytes and adjacent guards,
pre-shadow INSTALL rejection, exact error text/results, and absent/corrupt
manager return. Three shadow checks stop before staging; completed calls
must balance the stack. Keep the separate 53-case contract suite passing.
The subsequent [Bank-2 board cycle](../LOGS/HIMON_AP_BANK2_2026-09-16.md)
proves persistent APMAN setup and a new destructive INSTALL cycle, including
exact onboard package bytes, fresh ASM return, exported entry selection,
upper-boundary rejection, child return, software warm/cold recovery, and
complete four-bank isolation. Physical RESET, post-reset rediscovery/run,
and fresh ASM smoke also pass; NMI and visual LED acceptance remain separate gates.

The [APMAN size slice](../AP/APMAN_SIZE_REDUCTION_2026-09-16.md) requires
`apman-size-check` in addition to those gates. Compare exact APS/AP D output
across PACK40 name lengths and successful INSTALL's result card, source,
full staging image, copied worker, and destination configuration. The host
runner must forbid flash writes and stop before the programming worker.
Compare with the preceding binary for this optimization. Board proof must
include actual ASM INSTALL, exact carrier readback, both inspection selector
forms, named load/run, and physical-reset rediscovery. Report BODY/envelope
savings separately from unchanged resident sizes and carrier allocation.

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
make -C SRC asm-size-check
make -C SRC asm-ap-v2-check
make -C SRC apman
make -C SRC ap-store-v1-check
make -C SRC ap-store-inventory-check
make -C SRC ap-store-sector-tool-check
make -C SRC ap-store-chain-tool-check
make -C SRC ap-store-slice6-tool-check
make -C SRC himon-banked-ap-check
make -C SRC himon-ap-contract-check
make -C SRC himon-str8-record-check
make -C SRC himon-io-led-check
make -C SRC himon-size-check
make -C SRC microchess
make -C SRC str8-readonly-bank-tools-check
```

### HIMON/ASM ABI single-source gate

`asm-abi-check` treats `SRC/ASM/asm-abi-v1.inc` as the sole literal-address
authority for the published `$7E00-$7E40` HIMON/ASM boundary. It verifies the
fixed values and AP-v2 package contract, exact HIMON service-vector order, and
the aliases used by HIMON, the ASM core, and the flash wrapper. It also rejects
any new literal `EQU` in that range outside the canonical ABI include.

The 2026-09-14 zero-byte cleanup was built before and after with frozen visible
stamp `0914(1200)`. Both builds produced identical ASM S19 SHA-256
`EE0F64FBEA17B14625242A2B5FE8325FEFF8EE44F830EBA825D61453C2A5B385`
and identical HIMON S19 SHA-256
`91FFD858A5460F10C8D1CF67A893DAE4E9144FF8C1A95C59D0FC75D59C5D7558`.
ASM remains `_END_DATA=$BD95`; HIMON remains `_END_DATA=$EEF6`. Because no
emitted byte, RAM allocation, command behavior, or bank behavior changed, the
existing hardware evidence remains applicable and no new board gate is opened.

## ASM-F2 Size Reduction Qualification

The 2026-09-15 qualified image saves 530 ROM bytes with no UDATA or published ABI
change. Initialization cleanup, state-clearing loops, and redundant AP-writer
reload removal save 176 bytes; the shared opcode-pattern implementation saves
another 354. ASM-F2 occupies 15,235 bytes, ends at `$BB83`, and leaves 1,149
bytes below `$C000`. Its visible stamp is `00.0915(2243)`.

`asm-size-check`, included in `asm-test`, runs the linked 65C02 code against
independent expectations: 65,536 opcode ID/mode pairs, 1,024 bit-number byte
cases, six exact state-clear memory checks, 105 unhooked cold/warm service
initialization cases, 78 AP export/import records, and six complete AP-v2
packages. The same expectations pass the original image. Mutation checks
exercise the oracles. Existing diagnostic and source-workflow tests remain
required, including the optional CHECK build and every nonflash core profile.

See [size qualification](SIZE_REDUCTION_2026-09-15.md) for exact image identity,
full-suite results and timing tradeoffs. The image is installed in COM4
Bank-3 sectors 8-B. The [board record](../LOGS/ASMF2_SIZE_2026-09-15.md)
retains exact flash verification, all 217 instruction forms, nine rejected
source cases, NEW clearing, SEAL/RELOCATE/PACKAGE/LOAD, eight exports and
three imports, runtime/debugger checks, and physical RESET followed by fresh
assembly/run and unchanged full-bank readback. Prior board transcripts apply
to their original images; Bank 0-2 carriers were not requalified.

The full `asm-test` suite and all nine `board-s19-check` payload comparisons
pass with stamp `0915(2243)`. Generated routine documents and session-report
samples are current. The ASM-only component now uses S9 `$FFFF`; the identity
gate rejects the old `$8000` entry, and a corrected 8-B install passed on the
board. Host, documentation, and board gates agree; the feature queue is accepted.

The separate release ZIPs use `0915(2324)`. The full suite and nine canonical
image comparisons passed again for that stamp; exact comparison with the
reset-qualified COM4 bank permits only nine changed bytes in three timestamp
fields. The combined 8-E S19 is included identically in both component ZIPs.
This release qualification does not claim a new board flash operation.
Package checks also cover manuals/offline links, licenses, exact inventory,
S19/BIN agreement, and rejection of altered or incomplete distributions.

## HIMON Size Reduction Qualification

The 2026-09-15 candidate removes the unused non-FAST FNV update path (51
bytes), redundant AP seal-verifier pointer/count setup (37 bytes), and repeated
mnemonic name bytes (180 bytes net). The linked image with frozen visible stamp
`0914(1200)` shrinks from 12,022 to 11,754 bytes: `_END_DATA=$EEF6` becomes
`$EDEA`, leaving 534 bytes below `$F000`. The published FNV records, active
hash implementation, AP format, and mnemonic output remain unchanged.

`himon-size-check` executes the linked image with the same pinned py65 used by
the diagnostic gate. It covers all 256 opcode displays, FNV service results,
and AP parsing/seal validation across BODY page boundaries and malformed
packages. It is included in `asm-test`.

The focused linked checks pass on both the original and candidate images:
256 opcode step displays, 262 FNV vectors, and 77 AP parse/load cases. In-memory
mutation checks confirm rejection of corrupted mnemonic data, a damaged FNV
basis, and bypassed seal comparison. The banked-AP, STR8 client, and I/O LED
checks and full `make -C SRC asm-test` pass with the same frozen stamp.
Candidate HIMON S19 SHA-256 is
`F71AF701304AA7653A392DDACF6282BCBD1B2F4FED6FC18AC7A23BA23530795A`.

COM4 accepted this image on 2026-09-15: exact Bank-3 readback, resident hash
lookup, all 256 mnemonic displays, 34 actual debugger steps, and 13 direct AP
cases (six valid loads and seven corruption rejections). Physical RESET
reported `RST H`, returned through STR8-N 1.34 to HIMON `00.0914(1200)`, and
retained an identical full-bank readback. WDCMONV2 in sectors 8-B and STR8-N
code/configuration/vectors were preserved; only C-E and the installer-owned
D3 enrollment changed. See the [qualification record](../LOGS/HIMON_SIZE_2026-09-15.md)
and its retained raw serial transcript. ASM-F2 was absent on this board, so
this run does not claim an onboard ASM regression or requalify unrelated AP
carriers. Earlier hardware logs retain their original image scope.

The final timestamp correction was installed on COM4 as `00.0915(2233)`.
Comparison proved that only the two ROM timestamp strings changed; size
and layout are identical. The linked 256/262/77 checks passed again, and
full-bank readback verified the new C-E bytes plus the expected installer
journal advance. Cold entry, help, and hash lookup passed. Physical RESET
above applies to the preceding, otherwise byte-identical image; it was not
repeated for the timestamp correction. The qualification record includes
the new image hashes and separate serial transcript.

## APMAN Bank/Sector LED Host Qualification

Historical status of the original build: host-qualified; COM4 functional paths accepted; visual LED observation
and physical-reset recovery pending.

APMAN writes `SECTOR|BANK` to PIA Port A immediately before the checked bank
selection in `APMAN_STAGE_RAW`. Sector bases `$80-$F0` occupy the upper nibble
and Bank 0-2 occupies the low bits. Because all banked carrier reads use this
common staging path, `AP`, `AP L`, `AP D`, and `APS` receive the indication
without delays. APMAN reloads `BANK` before calling `$F010`, still executes
from RAM while another bank is selected, and still restores Bank 3 before
returning. Later HIMON console output or input wait reclaims the display; an
executed application remains free to own Port A.

The APMAN check freezes the linked `PHP`, `SEI`, LED publication, selector
reload, and `JSR $F010` bytes. `make -C SRC apman` passes with BODY `$0BFC`,
end `$7BFC` exclusive, AP-v2 package `$0C2A`, and four bytes of overlay
headroom below `$7C00`.

Board acceptance must exercise `APS`, `AP D`, `AP L`, and named `AP` across
the available Bank 0-2 media; observe the encoded bank/sector changes, Bank-3
restoration, HIMON's subsequent wait/activity status, application handoff,
and physical-reset recovery. Do not mark the queue item complete from host
checks alone.

COM4 accepted the guarded B2:8 erase/install, `$0C2A` named discovery, exact
`AP D` section bounds and prefix, full `APS`, `AP L B1 BANKAUDIT`, and named
BANKAUDIT execution. The read-only run completed all four CRC rows with B2:8
CRC `$A5C2`, reported `BANKAUDIT OK; B3 RESTORED`, and returned to a responsive
HIMON `00.0910(1709)`. No host observation can certify the physical LED pattern,
and the run did not include a physical RESET, so those two gates remain open.

## Microchess AP Host Qualification

Status: help-enabled `$06A6` build board-qualified for onboard assembly,
AP-v2 packaging, RAM and `B1:9000` carrier load/link/entry, named discovery,
board rendering, exact `H` output, and `Q` return. The resident 66-byte
`MICROCHESS` launcher is host-checked and hardware-proven under HIMON
`00.0910(2121)`. Physical-reset persistence of this exact build remains
pending.

The `microchess` target builds Peter Jennings' engine as a fixed `$2000`
AP-v2 BODY and stages its envelope at `$3000`. Its focused structural check
retains the upstream notice and license, rejects KIM-only stack reset,
validates the wrap-sensitive zero-page aliases, and requires the three typed,
HIMON-published console imports with matching ABS16 relocation rows. The
pinned py65 smoke also sends the complete symbol-lean `.a` through the real
ASM-F2 image and requires its `$06A6` AP package to equal the host package
byte-for-byte. The runtime smoke executes lowercase `h`, verifies the command,
copyright, and AI-assistance lines, resets, plays the canned `$13->$33` move,
a human `$62->$42` move, a real off-book searched reply, board output,
`A=$AC/C=1`, and restoration of
the caller stack.

Physical acceptance must follow the card in
[MICROCHESS_AP.md](MICROCHESS_AP.md) and be appended to the hardware log. Do
not mark the queue item complete from host execution alone.

The 2026-09-10 help-output board run assembled through `$2625`, produced the
expected `$06A6` package, entered it through `AP 3000 2000`, and printed all
three required `H` lines exactly. Its transcript ends after entering the four
digits of the human move, before Return or `Q`; those runtime paths remain
covered by the host smoke and the preceding-build board run.

A later COM4 run erased only obsolete carrier sector B1:9, installed the
current `$06A6` package at the same address, and proved `APS B1 MICROCHESS`,
`AP B1 MICROCHESS`, exact `H`, and `Q`. Guarded STR8-N 1.33 C-E updates first
proved the K01 launcher, then installed the corrected K05 HIMON
`00.0910(2121)`. `?` retained compact command help; bare `#` printed
`34EBE8D5 C39C 05 MICROCHESS`, and `# MICROCHESS` resolved the same entry.
Bare `MICROCHESS` printed `AP LOAD B1
9000 -> 2000`, entered the application, printed the exact help disclosure,
and returned through `Q`. No physical RESET occurred after these writes.

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

## AM03 offline integration gate

Before an AM03 board install, run `make -C SRC asm-test` with the frozen
visible stamp. Its prerequisites must prove the `$6C00-$7BFF` tray and
carrier limits, audit every AP in the accepted final readback against the
`$6C00` child ceiling, exercise combined RAM/bank uniqueness and guarded
handoff, and retain the resident-front-door scope regression. The handoff cases
must include provider change between scans, staged tampering, failed imports,
duplicate refusal, exact retirement and child A/carry return.

These checks qualify an offline candidate only. Board acceptance requires a
paired HIMON/AM03 install at B2:8, reset/isolation proof and the existing banked
regression. A real RAM-backed command remains deferred until provider hardware
is installed.

## Current Board Gate

For changes that touch the onboard path, prove only the affected rows plus the
short regression rail:

- boot through STR8-N into the expected HIMON/ASM-F2 identity;
- assemble a known-good source and confirm emitted bytes and status;
- `SEAL`, `PACKAGE`, and direct AP load/link where applicable;
- `INSTALL package Bn`, reset-time rediscovery, `APS`, named `AP`, and `AP L`
  for carrier or manager changes;
- `AP D Bn name|s000` by both selector forms for APMAN inspection changes:
  require HIMON front-door forwarding, the same AP-v2 validation and duplicate
  rejection as `AP`, exact five-section boundaries, a `$40`-byte envelope
  prefix only, no `AP LOAD` or `GO`, unchanged post-install sector CRCs, and
  Bank-3 restoration;
- missing-import, overlap, malformed-envelope, and bank-restore rejection for
  AP/OIL changes;
- before/after sector or bank CRCs for every flash mutation;
- physical reset recovery to Bank 3 after banked work.

Record the exact image identity, commands, output, CRC evidence, and result in
the hardware log. Do not copy the whole procedure into the log; link this plan
or a focused board card and retain only evidence needed to distinguish the
run.

## Current Accepted Baseline

The [parser initialization slice](../AP/HIMON_AP_INIT_SIZE_REDUCTION_2026-09-16.md)
adds clear-block guard checks for every incoming X value and parser error-path
comparisons. Its focused board caller verifies early-error X and zeroed state,
success X/Y, and untouched install-result cells before the normal recovery rail.

The resident AP range-check reduction has a focused
[size and board card](../AP/HIMON_AP_RANGE_SIZE_REDUCTION_2026-09-16.md).
Its maintained host sweep checks both destination policies and source-base
windows from linked instructions; optional baseline comparison also checks
registers, scratch and ordered writes. Board qualification requires exact
HIMON C-E installation/readback, boundary redzones, manager/import and fresh
ASM smoke, recovery, and preservation of the remaining flash image.

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
