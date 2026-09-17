# Safe RAM AP handoff — 2026-09-16

The private `$5000` safe-handoff slice is accepted on the current installed
HIMON/AM02 pair. The 322-byte image occupies `$5000-$5141`; binary SHA-256:

`8fde3b143f20960d27325ea7a16d0ea03148eadacc1f1097af2bed8441f77204`

The [contract](../AP/RAM_AP_HANDOFF_2026-09-16.md) records its ownership and
return rules. Eleven linked-byte host cases and the full `asm-test` regression
pass with the installed visible stamp `0915(2324)`.

Eight RAM-only COM4 cases then passed:

| Case | Observed result |
| --- | --- |
| RAM child checks retired card/name/stage/state, enters and returns | `A=$5A,C=1`, marker `$A5` |
| RAM child with resident `FNV1A_INIT` import | linked word `$E43B`, `A=$5A,C=1`, marker `$A5` |
| Installed APTEST at B2:9 | loaded, entered and returned `A=$5A,C=1` |
| RAM BANKDUMP plus installed B2:A BANKDUMP | duplicate refusal `$D2`, no child marker |
| Missing resident import | AP status `$09`, copied BODY never entered |
| Malformed RAM envelope | refusal `$D1`, no load or entry |
| Unsupported format card | refusal `$D4`, no load or entry |
| Child deliberately clears carry | returned `A=$A7,C=0`, marker `$A5` proves child entry |

Every case read the complete `$3000-$3FFF` provider window before and after and
found it identical. Every case read back zeroed request card, stable-name area
and `$5400-$540F` handoff state. The primary success and missing-import cases
also read all `$0A00-$19FF` as zero. Successful RAM cases read back the exact
linked BODY at `$2000`; the import case contained `$E43B` at its patched word.

The first hardware execution passed, but the evidence harness initially asked
its strict 16-byte-row decoder to parse a partial final dump row. The script
stopped after the successful assertions and before recording the case. The
reader was changed to request aligned rows and slice the requested bytes; the
complete eight-case suite was then rerun. This was an evidence-parser issue,
not a target failure or retry after mutation.

After that completed run, final ownership review moved ASM-session invalidation
to handoff entry so even an invalid request clears the resume flag. The linked
size stayed 322 bytes but the identity changed. All eleven host cases, full
regression and all eight COM4 cases were repeated against the updated bytes.
The earlier complete run and flash archive remain under `pre-resume-fix-*` in
the evidence directory; the unprefixed results and final archive are the
accepted image named above.

After the accepted run, a direct RAM dump matched every byte at `$5000-$5141`
and read `$7E6A=$00`, confirming the final handoff identity and ASM-session
retirement on the board.

Complete pre-test and final four-bank captures are identical to one another and
to the accepted baseline. Their manifests retain the full-flash SHA-256:

`8a9977c675364f95a53b58b23067ba469d3595026064a2530e7c3e9db3096f4b`

No flash command, installer or update stream was used. Installed policy `$A6`,
APTEST B2:9, BANKDUMP B2:A, B2:F backup and Bank-3 firmware remain unchanged.
No physical reset was required because the slice changes only transient RAM.
SPI SRAM and WORK allocation remain deferred until the device is installed.

The [evidence directory](RAM_AP_HANDOFF_2026-09-16/) retains the source/checker
snapshots, generated private addresses, linked artifacts, host/full-regression
results, board fixtures, raw COM4 log, bank S-records, and manifests containing
the bank and sector identities. Redundant raw board-image binaries are omitted;
the S-records retain the readback bytes and the manifests retain the CRC and
SHA-256 evidence. The exported transient `.a`, `.s19` and `.bin` forms are
pinned by the RAM-transient manifest. The next separate slice is resident-miss
command integration; this proof does not alter resident-first command
precedence or publish the private request card.
