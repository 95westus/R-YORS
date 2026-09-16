# Initial RAM HREC inspection proof — 2026-09-16

This slice implements a separate 333-byte W65C02 transient at `$2000-$214C`.
It inspects explicitly enabled `$3000-$3FFF` using existing on-board RAM.
SPI SRAM is not installed; SPI support and WORK allocation are deferred until
the operator confirms installation. No flash WORK sector is reintroduced.

Source: [fnv-ram-hrec-2000.asm](../../../SRC/APPS/fnv-ram-hrec-2000.asm).
Run `make -C SRC fnv-ram-hrec-check`; this is also an `asm-test` prerequisite.
The repeatable transient export includes matching `.a`, `.s19` and `.bin`
files with private-call requirements in its manifest.

## Bounded contract

This is a metadata inspector, not a public resolver service, monitor command,
or permission to execute a hash match. It does not change HIMON or AM02.
Resident-first command behavior and the accepted banked AP path stay intact.
The current 8-byte HIMON and 13-byte AM02 margins cannot accommodate a new
general resolver without a separately measured relocation/reduction design.

The caller owns the development window and initializes all 32 bytes of the
private scoped card at `$7D40`. Required request values:

| Offset | Value |
| --- | --- |
| `$00` requested banks | zero; combined bank/RAM lookup is not implemented |
| `$04` RAM enable | nonzero |
| `$05` RAM windows | exactly `$08` |
| `$06` format | `$00`, private HREC proof |
| `$07-$0A` wanted identity | little-endian FNV32 |

Unsupported requests return `$D4` before reading the provider window. The
inspector does not read persistent policy: `$A6` never implicitly enables RAM.
No staging tray, manager overlay, I/O or banked flash is searched.

The scan recognizes the exact `F N $D6` signature and wanted hash, then applies
format-specific shape checks. Supported K values are exactly `$01` (inline
entry at record+8), `$03` (entry/confirmation-text pointers), and `$05`
(entry/descriptive-text pointers). Other kinds are ignored. The full header,
inline entry byte or pointer payload must fit inside the window. Both pointers
must stay inside the window; text must contain printable ASCII with a high-bit
terminator before `$4000`. The returned kind preserves confirmation semantics.

All candidate locations are visited. Count saturates at two; duplicates return
`$D2`. No match returns `$D1`. A unique record is revalidated, then returns
`C=1,A=$AC` and the following metadata. Failure returns carry clear, with no
published location or entry pointers; stale result bytes are cleared on entry.

| Offset | Result |
| --- | --- |
| `$0B` | match count 0/1/2 |
| `$0C-$0E` | source=1 (RAM), bank=`$FF`, window=3 |
| `$0F-$10` | record address |
| `$18-$19` | entry address |
| `$1A-$1B` | extra text pointer, zero for inline |
| `$1C` | exact K value |

The formerly reserved `$18-$1C` bytes are private to this standalone proof;
the installed banked finder does not consume them. A/X/Y, flags, `$A0-$A8`
and documented result bytes are volatile. Calls require Bank 3, decimal clear,
foreground ownership and no concurrent provider modification. A valid request
invalidates ASM resume. The provider window and inspector code are read-only.

HREC has no canonical-name field or code-length/seal proof. These shape checks
cannot prove code integrity, intended identity beyond FNV, or that arbitrary
data resembling a record is safe to execute. There is deliberately no indirect
call or jump to the returned entry. AP envelopes use their separate sealed
format and are not accepted merely because their export hash matches.

## Acceptance and next boundary

The 72 linked-byte host cases cover each supported shape, malformed kinds,
signatures and hashes, both sides of record/pointer boundaries, text bounds,
duplicate saturation, stale results and unsupported requests. The memory model
rejects every out-of-contract read/write and every candidate instruction fetch.
Seven separately assembled board drivers rehearse exact requests/results.

The [hardware record](../LOGS/RAM_HREC_PROOF_2026-09-16.md) records board results,
full regression and before/after flash hashes. This completes the initial RAM
HREC inspection proof only. RAM AP-envelope validation, combined RAM/flash
uniqueness, stable ownership across load/link, trusted execution policy,
resident-first integration and any public request interface remain separate
gates. SPI SRAM is not a prerequisite for those existing-RAM design steps.

Follow-up: the [RAM AP/combined uniqueness proof](RAM_AP_UNIQUENESS_2026-09-16.md)
now implements the AP-validation and combined-count portions as a separate,
image-pinned metadata inspector. Load/link ownership and command execution
remain open; the raw-HREC execution limitations above are unchanged.
