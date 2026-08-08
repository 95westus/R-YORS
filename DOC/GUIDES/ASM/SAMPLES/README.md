# Maintained ASM Samples

This directory is the current board-facing ASM source surface. Keep maintained
operator tools here. Historical implementations, smoke programs, negative
fixtures, proof-only sources, and completed board-test cards belong in
[`OLD`](OLD/README.md).

## AP Build, Install, And Reporting

- `asm-session-report-ap-2000.a` - current movable, Bank-0-storable ASM
  session reporter when supplied from a compatible RAM/visible-flash path.

The old Bank-0/Bank-2 AP installation surface is archived. Split-V1 HIMON now
contains the `$F010/$0203` banked AP staging replacement; its host matrix is
accepted, while a Bank-0-stored reporter run remains the board gate before the
path is current again.

## Flash Tools

- `flash-bank-read-ap-2000.a` is the movable read-only sector/CRC AP migrated
  to `$F010/$0203` staging.
- `flash-bank-dump-ap-2000.a` is the fixed-load read-only sector dump migrated
  to `$F010/$0203` staging while preserving its historical fixed addresses.
- `str8-bank-maint-2000.a` is the supported carried-worker copy/erase/map
  utility. Its `M` path is read-only and also displays the V1 directory.

The two AP bodies are current. Loading a Bank-0-stored AP now uses HIMON's
migrated banked staging path, which is host-accepted and awaits board proof.

## STR8 Tools

Active tools do not request legacy mutation/stage modes through `$F003`.
Installed split-V1 images `1900` and `2033` had an unguarded jump-only
doorway; board image `2135` rejects every non-`$08` request. The incompatible
sources and an explanation of their former roles are under `OLD`.

- `str8-bank-crc-all-3000.a` - read-only all-bank CRC inventory through
  `$F010/$0203`; no mutation-worker authority.
- `str8-bank-maint-2000.a` - carried-worker copy/erase/map utility; `M` also
  displays all four Bank-3 directory records.
- `str8-jump-inventory-3000.a` - read-only pre-handoff bank inventory through
  `$F010/$0203`; no mutation-worker authority.
- `topwr-transient-3000.a` - maintained staged top-sector shop tool; preserve
  the live V1 directory when overlaying a replacement image.
- `str8n-v1-refresh-transient-3000.a` - generated current V1 top-sector
  refresh writer; copies live `$FFB0-$FFEF` before staging.

Generated maintained sources must continue to target this directory. Generated
legacy reporter forms target `OLD` so regeneration does not repopulate the
active sample surface.

## Split-V1 `$F003` Classification

| Historical source under `OLD` | Class | Current disposition |
| --- | --- | --- |
| `str8-bank-crc-all-3000.a` | read-only | Replaced here by `$F010/$0203` source |
| `str8-jump-inventory-3000.a` | read-only | Replaced here by `$F010/$0203` source |
| `flash-bank-read-ap-2000.a` | read-only | Replaced here by `$F010/$0203` source; HIMON loader host-accepted, board proof pending |
| `flash-bank-dump-ap-2000.a` | read-only | Replaced here by `$F010/$0203` source; HIMON loader host-accepted, board proof pending |
| `str8-bank-copy-2000.a` | destructive | Retired; use `str8-bank-maint` `C` |
| `flash-erase-bank-ap-2000.a` | destructive | Retired; use `str8-bank-maint` `E` |
| `bank0ap-put-transient-2000.a` | destructive | Retired; use `str8-bank-maint` for supported bank mutation |
| `bank2put-8000-transient-3000.a` | destructive | Retired; use `str8-bank-maint` for supported bank mutation |
| `bankput-transient-3000.a` | destructive | Retired; use `str8-bank-maint` for supported bank mutation |
| `flash-bank-erase-write-ap-2000.a` | destructive | Retired; use `str8-bank-maint` for supported bank mutation |

No maintained sample or live HIMON path now requests stage/mutation modes
through `$F003`. HIMON's replacement is host-accepted at `$0300` and uses
`$F010/$0203`; a successful board `AP Bn` load remains required before split
V1 becomes the default combined-image baseline.
