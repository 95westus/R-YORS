# Maintained ASM Samples

This directory is the current board-facing ASM source surface. Keep maintained
operator tools here. Historical implementations, smoke programs, negative
fixtures, proof-only sources, and completed board-test cards belong in
[`OLD`](OLD/README.md).

## AP Build, Install, And Reporting

- `asm-session-report-v1.2-ap-2000.a` - current movable, Bank-0-storable ASM
  session reporter when supplied from a compatible RAM/visible-flash path.
- `expr-negative-rollback-2000.a` - final-image expression rejection and
  transactional rollback card.
- `opcode-reduction-runtime-2000.a` - runtime coverage for the compact shared
  ALU and shift/rotate opcode tables.
- `seal-workflow-2000.a` - small named body for final post-`END` command-flow
  testing.

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
- `str8n-v1.2-bank-maint-2000.a` is the supported carried-worker copy/erase/map
  utility. `P` adds the fixed Bank-0 `$BF00` AP proof carrier; `M` is read-only
  and marks only structurally valid, body-FNV-matched AP envelopes as `A`.
  It prints the first AP address and package length in each `A` sector before
  displaying the V1 directory.

The two read/dump AP bodies are current. The migrated banked staging path and
a valid Bank-0 package execution are hardware-accepted.

## STR8 Tools

Active tools do not request legacy mutation/stage modes through `$F003`.
Installed split-V1 images `1900` and `2033` had an unguarded jump-only
doorway; board image `2135` rejects every non-`$08` request. The incompatible
sources and an explanation of their former roles are under `OLD`.

- `str8n-v1.2-bank-crc-all-3000.a` - read-only all-bank CRC inventory through
  `$F010/$0203`; no mutation-worker authority.
- `str8n-v1.2-bank-maint-2000.a` - carried-worker copy/erase/map/fixed-AP-put
  utility; `M` distinguishes valid AP envelopes from ordinary used bytes and
  also displays all four Bank-3 directory records.
- `terminal-answerback-vt100-3000.a` - read-only Tera Term/VT100 probe using
  the pinned STR8-N 1.22 raw console ABI. It sends ENQ and Primary Device
  Attributes, bounds both reply waits, and prints replies as hex plus safe
  printable text. Board-accepted with configured answerback `RYORS` and
  Primary DA reply `ESC [ ? 1 ; 2 c`.
- `str8n-v1.2-topwr-transient-3000.a` - maintained staged top-sector shop tool; preserve
  the live V1 directory when overlaying a replacement image.

The current directory-preserving top-sector source is generated as
`SRC/BUILD/generated/asm-samples/str8n-v1.2-i-refresh-transient-3000.a` by
`make -C SRC str8-i-refresh-a`. Generated writer names use
`str8-i-{refresh,migrate,replace-legacy}-transient-3000.a`; only `refresh` is
the normal installed-V1 path. Exact writers used by completed board proofs are
frozen under `OLD`.

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
