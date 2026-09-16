# HIMON/AP typed-import boundary - 2026-09-16

This first Phase-2 slice makes HIMON own the conversion from an AP import
to a resident catalog address. `HIM_AP_LINK_RESOLVE_SLOT_X` now lives in
`SRC/HIMON/himon-ap-resolver.inc`. `AP/ap-link.inc` includes it at its original
assembly position, `$DDA3-$DDE9` (71 bytes). Its existing entry and helper
labels remain unchanged. AP's linker calls this interface without knowing
the resident catalog's EXEC bit or private lookup routine.

The move adds no wrapper, public vector, register conversion, or RAM cell.
It preserves the existing static link between AP and HIMON. The resident
catalog, resolver, and shared primitives remain in their original locations.

## Provider/client contract

| Item | Existing contract, now owned explicitly |
| --- | --- |
| Caller | AP's `HIM_AP_LINK_RESOLVE_ROW_X`; validates the relocation's import index against the saved import count |
| Input | X = valid slot index; `HIM_AP_IMPORT_LO/HI` points to the parsed imports section, including its count byte |
| Row traversal | Existing AP helper `HIM_AP_LINK_IMPORT_ROW_PTR_X`; advances over variable-length PACK40 names |
| HIMON conversion | Copy the row's FNV hash into shared hash scratch, call `THE_JOIN_FIND`, require the resident EXEC bit for AP EXEC and its absence for AP DATA |
| Success | C=1; `HIM_AP_LINK_RES_LO/HI` (`$7DC3-$7DC4`) contains the resident address |
| Failure | C=0; result pair unchanged; other scratch is not a valid result |
| Caller continuation | AP applies the signed import addend and performs relocation patching; its failure path reports BAD_FIX |
| Volatile state | A/X/Y/flags, AP row pointer and temporary scratch, FNV hash scratch, monitor address scratch, catalog scan/extra-pointer scratch; stack balanced on return |
| Preconditions | Validated package/import rows, valid slot, Bank 3 visible, foreground/non-reentrant service usage |

The existing resolver's first-match behavior is preserved, including rejection
when the found resident record has the wrong kind. This is separate from
APMAN's duplicate *carrier-name* policy. No new collision or catalog-search
policy is introduced.

## Remaining shared dependencies

| Dependency | Decision for this slice |
| --- | --- |
| Resident catalog record kinds and lookup | HIMON adapter owns them; AP files may not reference `THE_JOIN_*` or `CMD_HASH_*` directly |
| FNV calculation | Intentional shared primitive; AP BODY validation still calls the existing implementation |
| `CMDP_*` pointer/address scratch | Existing shared foreground storage; retain addresses and document overlap rather than allocating replacement RAM |
| Manager command shadow and diagnostics | Existing monitor coupling remains in manager bootstrap; a later bounded slice can address it |
| ASM resume byte `$7E6A` | Existing takeover/session contract retained; no lifetime or behavior change |
| STR8 selector/staging | Existing published selector ABI and checked RAM caller retained |

## Build and verification

Both HIMON object targets already depend on `HIMON/*.inc`; this includes the
new nested adapter. The structural source reader now expands that adapter,
and source-reference release packaging includes it. Generated routine maps
identify the HIMON owner. The size ledger separately displays its 71 bytes
inside the existing AP functional subtotal, so totals remain comparable.

`make -C SRC himon-ap-boundary-check` checks the ownership boundary and runs
six linked-code resolver cases: EXEC, DATA, both kind mismatches, missing
symbol, and a nonzero slot after a longer PACK40 name. Failure preserves a
seeded result pair; all cases preserve application/package RAM, balance the
stack, and perform no bank selection or flash write. Two negative source
fixtures prove that direct lookup and catalog-kind access are rejected.
The target is included through `himon-ap-contract-check` in `asm-test`.

The [dated evidence receipt](../LOGS/HIMON_AP_BOUNDARY_2026-09-16/manifest.json)
records a passing full `asm-test`, all 53 existing contract cases, the six
focused resolver cases, both bypass negatives, and nested-include cycle
rejection. All 15 S19/BIN/AP/map artifacts and every linked symbol match the
baseline exactly, without timestamp exclusions. Expanded noncomment source
also matches. Generated contracts identify the new source owner.

HIMON remains 11,868 bytes with 420 bytes free; ASM remains 15,235 bytes with
1,149 bytes free; APMAN remains 3,072 BODY bytes with no overlay headroom.
ROM/RAM growth and added call overhead are zero. This slice establishes
ownership; it claims no size saving. Earlier hardware transcripts and
unrelated working files remain unchanged.
No serial connection or board programming is part of this source-ownership
slice. Existing [Bank-2 and physical RESET proof](../LOGS/HIMON_AP_BANK2_2026-09-16.md)
continues to identify the installed firmware and carriers.

Reproduce with the frozen stamp:

```text
make -C SRC "HIMON_VISIBLE_STAMP=0915(2324)" asm-test himon-banked-ap-check himon-str8-record-check himon-io-led-check board-s19-check himon-rom-bin
python -B SRC/tools/check_himon_ap_extraction.py --baseline LOCAL/himon-ap-boundary-20260916/baseline --output LOCAL/himon-ap-boundary-20260916/identity.json
```
