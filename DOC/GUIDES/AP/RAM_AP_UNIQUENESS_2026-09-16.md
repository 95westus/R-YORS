# RAM AP validation and combined uniqueness — 2026-09-16

This slice adds a 476-byte, metadata-only W65C02 transient at `$2000-$21DB`.
It validates AP envelopes in explicitly selected existing RAM `$3000-$3FFF`,
then combines those matches with eligible banked AP providers. A valid RAM
provider and a valid flash provider with the same identity are duplicates,
not a precedence choice. No provider is loaded, linked or executed.

Source: [fnv-ram-ap-2000.asm](../../../SRC/APPS/fnv-ram-ap-2000.asm).
Run `make -C SRC fnv-ram-ap-check HIMON_VISIBLE_STAMP='0915(2324)'`.
The check is also an `asm-test` prerequisite. The repeatable RAM export adds
matching `.a`, `.s19` and `.bin` artifacts plus image pins in the manifest.
SPI SRAM is not installed; SPI support and WORK allocation remain deferred.

## Ownership and image dependencies

The transient uses the accepted resident AP service and canonical-name helper,
and the accepted AM02 candidate/entry-row routines. Three private addresses
are generated from the linked maps and recorded with exact image hashes.
This is an image-pinned proof, not a public service ABI. A caller must verify
the matching HIMON/AM02 images and freshly load AM02 before entering it.
The exporter refuses stale image pins or a mismatched proof binary.

No HIMON or AM02 source changes are needed. Their existing margins remain
8 and 13 bytes respectively. This inspector and the earlier HREC inspector
are alternative `$2000` transients; they do not coexist at that address.

| Range | Foreground ownership |
| --- | --- |
| `$2000-$21DB` | inspector code |
| `$2E00-$2E0F` | scan cursor, first RAM location, count and request/status scratch |
| `$2F00-$2F1E` | caller-owned stable canonical name, at most 31 bytes |
| `$3000-$3FFF` | explicitly enabled provider window; never written |
| `$0A00-$19FF` | copied envelope/flash sector staging; invalidated by the next candidate |
| `$7000-$7BFF` | freshly loaded AM02; no nested monitor input while live |
| `$7D40-$7D5F` | private scoped request/result card |

Shared zero page, parser/link scratch, A/X/Y and foreground overlays are
volatile. Calls require Bank 3, decimal clear and no concurrent provider
modification. Valid search invalidates ASM resume. Banked selection retains
the existing RAM execution and restoration rules; NMI qualification is unchanged.

## Private request and result

Initialize the full card before each call. Requested banks and sector windows
use the installed finder encoding. Format must be `$01` (AP export), name
pointer exactly `$2F00`, name length 1–31, and wanted FNV32 at offsets `$07-$0A`.
RAM enable is independent of persistent policy. When nonzero, RAM-window mask
must be exactly `$08`; when zero, RAM is skipped and its mask is ignored.
Invalid requests return `$D4` before staging or bank selection.

For each possible envelope start, the entire declared envelope must fit below
`$4000` before it can be copied. Only those bytes are copied into the staging
tray. The existing PARSE path validates AP signature/version, section bounds,
seal, BODY hash and record shape. Entry-row bounds, stored identity and exact
canonical PACK40 name are then checked using the existing helpers.

The RAM count and first location survive all later bank staging. The installed
finder scans request intersected with persistent policy in B2/B1/B0 order,
respecting sector windows and protected roles. RAM is temporarily disabled in
that bank-only call and its original enable byte is restored on every return.
Counts are combined with saturation at two. Restore failure takes precedence
over an otherwise valid RAM match. A unique RAM result is copied and validated
again; a unique bank result is revalidated by the installed finder.

| Result | Meaning |
| --- | --- |
| `C=1,A=$AC` | one valid provider, metadata only |
| `C=0,A=$D1` | no match, or unique-location revalidation failed |
| `C=0,A=$D2` | duplicate; count saturated at two |
| `C=0,A=$D4` | unsupported request |
| `C=0,A=$D9` | bank restoration fault reported after safe RAM retry |

Card offset `$0B` contains the match count. On success, `$0C` is source 1=RAM
or 2=bank, `$0D` is bank number (`$FF` for RAM), `$0E` is window 3 or sector
high byte, and `$0F-$10` is the original envelope address. `$18-$19` is the
entry **offset**, not a callable address; `$1A-$1B` is BODY length. Failure
clears all location and entry metadata. The result must not retain pointers
into staging or be used to bypass normal load/relocation/import checks.

## Acceptance and remaining boundary

The 43 linked-byte host cases cover RAM and flash uniqueness, saturation,
malformed envelopes, canonical-name forgery, offsets and bounds, masks,
policy-independent RAM, excluded/enrolled B0, protected B2:F, restore failure,
and failure of RAM revalidation. The model forbids provider/code/name writes,
out-of-window reads into `$4000-$6FFF`, unexpected I/O, flash writes, foreign
ROM instruction fetch and provider load/link/entry. HREC format is refused.

The [hardware record](../LOGS/RAM_AP_UNIQUENESS_2026-09-16.md) records eight
RAM-only board cases, full regression and exact four-bank isolation.
Unresolved imports may still appear in valid metadata: this slice deliberately
does not link. The accepted resident-first command dispatcher remains unchanged.
The next slice must settle ownership across normal AP load/link and command
entry, including how the inspector's own `$2000` code is retired or relocated.
No callable RAM-provider command or public request ABI is introduced here.
