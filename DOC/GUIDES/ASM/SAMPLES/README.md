# Maintained ASM Samples

This directory contains maintained operator tools, examples, and named
regression fixtures for ASM-F2. The release separates application sources
from deliberate rejection/limit tests; see the
[release application catalog](../../RELEASE_APPLICATIONS.md). Historical
implementations and completed board-test cards remain in [`OLD`](OLD/README.md).

The current release is ASM-F2/HIMON `00.0915(2324)` with STR8-N 1.34.
It is timestamp-only equivalent to the reset-qualified firmware pair;
individual application board claims retain their original dates and scope.

`ap-store-v1-sector-tool-7000.a` is generated from the host-linked
`SRC/PROOFS/ap-store-v1-sector-tool.asm` S19. It is an exact ASM-F2 image
carrier for AP Status at `$7000`, PREPARE at `$7003`, and confirmed EXECUTE at
`$7006`; edit the host source, not the generated `DB` rows.

## AP Build, Install, And Reporting

- `asm-session-report-v1.2-ap-2000.a` - current movable, Bank-0-storable ASM
  session reporter, also storable in another suitable Bank 0-2 carrier.
  Package at `$3000`, preload at `$4000` before the target session, then run
  `G 4000` afterward. The generated source must match the ASM release map.
- `expr-negative-rollback-2000.a` - final-image expression rejection and
  transactional rollback card.
- `unresolved-addends-2000.a` - forward internal absolute, relative, data,
  selector, and packaged declared-import addend acceptance card.
- `opcode-reduction-runtime-2000.a` - runtime coverage for the compact shared
  ALU and shift/rotate opcode tables.
- `pia-led-show-2000.a` - movable AP demo that drives all eight PIA port-A
  LEDs, then restores the prior output and direction state.
- `seal-workflow-2000.a` - small named body for final post-`END` command-flow
  testing.
- `microchess-2000.a` - fixed `$2000` game AP; keep its complete inline credits
  and `SRC/APPS/MICROCHESS-LICENSE.txt` with distributed copies.
- `bank-audit-2000.a`, `bank-dump-2000.a` - maintained utility AP sources with
  named HIMON imports. Their older direct host images pin obsolete HIMON
  addresses and are not included in the current release.

The old general Bank-0/Bank-2 AP installation surface is archived. Split-V1
HIMON's `$F010/$0203` banked AP staging path, invalid-package rejection, and
valid-package execution are hardware-accepted. The fixed `str8-bank-maint P`
carrier at Bank 0 `$BF00` closed that proof without restoring the old `$F003`
installers. Its exact marker source is retained under `OLD` as a regression
fixture.

## Flash Tools

- `str8n-v1.2-flash-bank-read-ap-2000.a` is the movable read-only sector/CRC AP migrated
  to `$F010/$0203` staging.
- `str8n-v1.2-flash-bank-dump-ap-2000.a` is the fixed-load read-only sector dump migrated
  to `$F010/$0203` staging while preserving its historical fixed addresses.
- The current carried-worker copy/erase/map utility is in the adjacent
  `STR8-N/tools/bank-maint/str8n-v1.34-bank-maint-menu-2000.a`.
  Its read-only `M` command marks only structurally valid,
  body-FNV-matched AP envelopes as `A` and prints the directory. Use APMAN's
  `INSTALL package Bn` for ordinary named AP carriers; Bank Maintenance `P`
  retains its narrower legacy package policy.

The two read/dump AP bodies are current. The migrated banked staging path and
a valid Bank-0 package execution are hardware-accepted.

## STR8 Tools

Active tools do not request legacy mutation/stage modes through `$F003`.
Installed split-V1 images `1900` and `2033` had an unguarded jump-only
doorway; board image `2135` rejects every non-`$08` request. The incompatible
sources and an explanation of their former roles are under `OLD`.

- `str8n-v1.2-bank-crc-all-3000.a` - read-only all-bank CRC inventory through
  `$F010/$0203`; no mutation-worker authority.
- `ap-store-v1-slice6-stage-b1sb-1a00.s19` - read-only Slice 6 diagnostic that
  reuses the assembled CRC fixture's `$3088` stage routine to copy B1:B into
  `$4000-$4FFF`; it never erases or programs flash.
- `STR8-N/tools/bank-maint/str8n-v1.34-bank-maint-menu-2000.a` - current
  maintenance carrier in the adjacent repository and STR8-N release.
- `terminal-answerback-vt100-3000.a` - read-only Tera Term/VT100 probe using
  the pinned STR8-N 1.29 raw console ABI. It sends ENQ and Primary Device
  Attributes, bounds both reply waits, and prints replies as hex plus safe
  printable text. Board-accepted with configured answerback `RYORS` and
  Primary DA reply `ESC [ ? 1 ; 2 c`.
- `vt102-exerciser-7000.a` - fixed-load VT102 display, editing, mode, VT52,
  report, and keyboard exerciser using only the raw console ABI; no AP. Its
  measured direct-run image is `$7000-$79CD`.
- `vt525-exerciser-7000.a` - fixed-load VT525/VT500 C1, color, character-set,
  margin, rectangle, status-line, macro, report, and keyboard exerciser; no AP.
  Its measured direct-run image is `$7000-$79B2`.

Both terminal exercisers deliberately use the same transient tray and run one
at a time. Do not move them back to `$3000/$4000`: those ranges overlap the
live `$2000`-based ASM-F2 image and can crash after `END` before `SEAL>` exits.
For a STR8 top-sector update, use the STR8-N v1.34 release's checked RAM
updater and its operator guide. The earlier `.a` top writers and generated
`str8-i-{refresh,migrate,replace-legacy}` experiments are historical; they are
not the current release installation path.

Routine writer generation targets `SRC/BUILD/generated/asm-samples`. Tracked
board-facing samples change only when a generated candidate is deliberately
promoted; normal builds do not rewrite this directory or `OLD`.

## v1.2 RAM Relocation Proofs

- `str8n-v1.2-ap-link-smoke-2000.a` builds a RAM-only importing AP at `$4000`
  and exercises HIMON's relocated `$7DC0-$7DC7` import-link scratch without a
  flash write.
- `str8n-v1.2-low-user-canary-7000.a` sets and checks eight explicit canaries
  across user-free `$1A00-$1FFF`; it is a test fixture, not an allocation.

## Split-V1 `$F003` Classification

| Historical source under `OLD` | Class | Current disposition |
| --- | --- | --- |
| `str8-bank-crc-all-3000.a` | read-only | Replaced here by `$F010/$0203` source |
| `str8-jump-inventory-3000.a` | read-only | Replaced by `str8-bank-crc-all-3000.a`; accepted `$F010/$0203` jump fixture is archived |
| `flash-bank-read-ap-2000.a` | read-only | Replaced here by `$F010/$0203` source; stage/restore and valid AP run accepted |
| `flash-bank-dump-ap-2000.a` | read-only | Replaced here by `$F010/$0203` source; stage/restore and valid AP run accepted |
| `str8-bank-copy-2000.a` | destructive | Retired; use `str8-bank-maint` `C` |
| `flash-erase-bank-ap-2000.a` | destructive | Retired; use `str8-bank-maint` `E` |
| `bank0ap-put-transient-2000.a` | destructive | Retired; use fixed `str8-bank-maint P` for the reviewed Bank-0 proof carrier |
| `bank2put-8000-transient-3000.a` | destructive | Retired; use `str8-bank-maint` for supported bank mutation |
| `bankput-transient-3000.a` | destructive | Retired; use `str8-bank-maint` for supported bank mutation |
| `flash-bank-erase-write-ap-2000.a` | destructive | Retired; use `str8-bank-maint` for supported bank mutation |

No maintained sample or live HIMON path now requests stage/mutation modes
through `$F003`. HIMON's `$0300` replacement uses `$F010/$0203`; read-only
stage/restore and successful valid `AP B0` execution are hardware-accepted.
Split V1 is the default combined-image baseline.
