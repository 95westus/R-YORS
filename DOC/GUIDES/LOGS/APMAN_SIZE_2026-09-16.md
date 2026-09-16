# APMAN size and COM4 qualification - 2026-09-16

The [source change](../AP/APMAN_SIZE_REDUCTION_2026-09-16.md) shares INSTALL
package-card updates and APS/AP D carrier formatting. APMAN BODY drops from
3,072 to 3,031 bytes (`$0BD7`), ending at `$7BD7` exclusive, with 41 bytes
free below `$7C00`. The envelope is 3,077 bytes (`$0C05`). It still occupies
one 4K carrier sector. No Bank-3 bytes or sectors are released.

## Host qualification

The frozen stamp is `HIMON_VISIBLE_STAMP=0915(2324)`. This command passed:

```text
make -C SRC "HIMON_VISIBLE_STAMP=0915(2324)" asm-test himon-banked-ap-check himon-str8-record-check himon-io-led-check board-s19-check himon-rom-bin
```

The separate focused runner passed 18 cases against each of the old and new
builds, with matching A/carry, statuses, output, package facts, staging and
worker bytes. Cases cover six PACK40 names, APS list/detail, AP D by name and
address, reserved/occupied sectors, and short, unaligned and full-sector
INSTALL. Each build's output is checked exactly; only its independently
checked APMAN self-length is normalized for comparison. Host INSTALL stops
before the flash worker, and all emulated flash writes are forbidden.

The maintained `apman-size-check` target is now a prerequisite of
`himon-ap-contract-check`, which runs through `asm-test`. The 53 contract
cases, 13 boundary cases, five source bypass negatives, and nine board S19
identity comparisons also pass. Ten resident S19/BIN/map artifacts are exact
matches to the preceding qualification, without timestamp exclusions. The
555-byte carried worker is unchanged. HIMON remains 11,868 bytes; ASM-F2
remains 15,235 bytes.

The behavioral projection was extended to include A after the CPU runs;
all saved before/after A values matched on re-comparison. The receipt records
that check and the final checker hash. No code or fixture changed afterward.

## Board procedure and results

COM4 uses 115200 baud with DTR/RTS false. A fresh complete 128K backup matched
the preceding [Bank-2 qualification](HIMON_AP_BANK2_2026-09-16.md).

STR8-N 1.34 `I / 2 / 8` replaced only B2:8 with the dense, host-tested
carrier. Its existing `A2 APC02` identity was retained; D2's journal byte
`$FFDC` advanced from `$FC` to `$F0`. Immediate readback verified exact APMAN
bytes and preserved B2:9-F. The installer performed its own sector erase.

Eight before/after board transcripts match exactly except for APMAN's new
self-length: complete APS inventory; BANKAUDIT, MICROCHESS and APTEST detail;
and BANKAUDIT/APTEST AP D by both name and sector address. Further checks
cover manager self-execution rejection, one missing-name diagnostic, linked
load without execution, and BANKAUDIT execution with Bank 3 restored.

To exercise the changed successful INSTALL path, Bank Maintenance erased
only the backed-up APTEST test sector B2:9. All of Bank 2 was read back to
prove the erase was isolated. Onboard ASM rebuilt and packaged APTEST;
its `$0034` envelope exactly matches the independent expected package.
`INSTALL 3000 B2` used the reduced manager and its carried worker to reproduce
B2:9, then returned to fresh ASM at `$2000` with zero symbol/fixup counts.

APTEST runs at `$2000`, `$5000`, and `$6FFA` retain exact BODY bytes and entry
offset +2. A RAM caller verifies A=`$5A`/C=1. The crossing destination `$6FFB`
fails before copying with its redzone intact. Stale ASM resume is rejected;
STR8 software W/C recovery rediscovers the manager and runs the child.

## Exact flash result

Banks 0 and 1 and B2:9-F are byte-identical to the fresh backup. Only the
manager sector and the expected D2 journal byte differ. All 32 sector CRCs
reported by the board's BANKAUDIT match the independent full-bank readback.

| Image | SHA-256 |
| --- | --- |
| New APMAN envelope | `c53f820a05b0b7cd5921518f97beebb12a3f2c247d2526dfa2ac0ca91be0555e` |
| New 4K carrier | `1fed29fe2236e8c2e8aaba574d5dc452f8885efac75060c33a4eb02c8edc779b` |
| Final Bank 2 | `0b67c0fc66568f8903927d4014069a306a8ea8838fc557991813828bbe01a13c` |
| Final Bank 3 | `39718b56169da58f52443e537efff0f4c59a7c0822581c9138d1dd36109bd614` |
| Final 128K flash | `81bc7400407662a66b65deac09ead6c7c768fdbda48e17d21f130e43517e7642` |

## Physical reset

The receive-only trace captured `RST H`, STR8-N 1.34, `BOOT WARM`, and HIMON
`00.0915(2324)`. Reset cleared ASM resume. Both B2 carriers were rediscovered;
APTEST ran at `$5002` with its exact BODY. Fresh ASM assembled and executed
`LDA #$AC / SEC / RTS`, returning A=`$AC`, C=1. Complete Bank-3 readback
remained exact. COM4 closed at the HIMON prompt.

All 27 workflow/isolation/reset checks and eight output comparisons pass.
Operator-observed LED values and NMI remain separate gates; the LED feature
queue is still open.

Final four-bank readback and the physical-reset result are recorded in
[the verification receipt](APMAN_SIZE_2026-09-16/verification.json). The
[evidence manifest](APMAN_SIZE_2026-09-16/manifest.json) retains exact images,
before/after output, raw serial traffic, source patch, build receipts and
focused results. Earlier transcripts remain intact. No release was published.
