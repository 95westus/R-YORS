# Resident HIMON/AP range-size qualification - 2026-09-16

The [range-check slice](../AP/HIMON_AP_RANGE_SIZE_REDUCTION_2026-09-16.md)
saves 20 resident bytes by branching to existing local error exits: six in
source-base validation and fourteen in destination-range validation. Both
HIMON variants shrink by 20 bytes. The ROM image is 11,848 bytes, ending at
`$EE48` exclusive, with 440 bytes free below `$F000`.

ASM-F2 remains 15,235 bytes and APMAN BODY remains 3,031 bytes, with 41 bytes
of overlay reserve. Seven ASM/manager S19, map and package artifacts compare
exactly to the preceding build. No RAM, stack depth, accepted address window,
external package size or flash-sector allocation changes.

## Host qualification

The frozen visible stamp is `0915(2324)`. The full `asm-test` passes, including
53 AP contract cases, 13 ownership-boundary cases, five bypass negatives,
18 APMAN cases, 77 parser/load cases and the existing ASM/debugger/FNV checks.
Banked AP, STR8 record-client and LED checks pass.

The new maintained range sweep passes 30,710 destination cases and all 256
source high-byte cases against independent window rules. Running against the
old and new linked images also matches A/X/Y/P/SP, all AP scratch bytes and
ordered writes. Observed predicate cost changes by -5 to +1 cycles, or at
most 0.125 microseconds added per call at 8 MHz. This sweep is not exhaustive
over all combinations of 16-bit destination and length.

The first full command stopped at the final S19 packaging gate because its
explicit HIMON size assertion still expected `$2E5C`. Updating that assertion
to the independently measured `$2E48` and rerunning `board-s19-check` plus
`himon-rom-bin` passed all nine payload identity comparisons. The firmware
was unchanged between those runs. Both logs are retained.

## COM4 installation and workflow

COM4 uses 115200 baud with DTR/RTS false. The fresh complete four-bank backup
exactly matches the preceding accepted 128K image:
`81bc7400407662a66b65deac09ead6c7c768fdbda48e17d21f130e43517e7642`.

STR8-N 1.34 `I / 3 / C-E` installed only the dense HIMON component.
Immediate full Bank-3 readback matches the candidate in C-E and preserves
ASM in sectors 8-B. Outside C-E, only D3's journal byte `$FFED` changed,
from `$FC` to `$F0`; STR8 code, configuration and hardware vectors are intact.

Twenty-one recorded workflow cases pass: ten destination boundary cases,
seven parser source-base cases, persistent manager/typed-import/BANKAUDIT,
fresh ASM and APTEST, and software W/C recovery. Each destination case checks
status and exact BODY/redzones. Stale ASM resume after takeover is rejected.

The initial board fixture attempted to upload a redzone into `$7BFF` through
HIMON `L`, which correctly returned `LERR=$02`. The corrected RAM caller
initializes its own redzone before the AP invocation; the complete boundary
set then passes. No firmware change was needed. The initial log and harness
are preserved alongside the successful run.

## Exact image identities

| Artifact | SHA-256 |
| --- | --- |
| HIMON linked S19 | `9a16d3f909f4ed941ca382709987fcd927f381e2c246c1b34917b806119d1d01` |
| HIMON C-E dense payload bytes | `0072e698b5edc79c9ecff1eaadb11ca2558f839dc06a1e7871aa3d9bd22fb717` |
| HIMON C-E install S19 | `014e2e98049ec9d23b2584d23dc0be392e5daedb1174517d626b8f4526c1f68b` |
| Installed Bank 3 | `dd6da38d7c982c4ccda15727b4eff516c2285412913bfd7f5144e6493b2e720e` |

## Physical reset and final isolation

The receive-only trace captured `RST H`, STR8-N 1.34, `BOOT WARM`, and HIMON
`00.0915(2324)`. Reset cleared the ASM resume flag. Fresh ASM assembled and
executed `LDA #$AC / SEC / RTS`, returning A=`$AC`, C=1; persistent APTEST
loaded and ran at `$5002` with its exact BODY. Complete Bank-3 readback remained
identical to the installed candidate. The first listener expired before the
operator reset; a newly armed listener captured the repeated reset. The timeout
log and successful raw trace are both retained.

Final four-bank readback preserves all of Banks 0-2 and Bank-3 sectors 8-B.
HIMON C-E matches the candidate, and the only changed byte outside C-E remains
the expected D3 journal byte `$FFED`. All 32 live BANKAUDIT sector CRCs agree
with independent CRCs calculated from the final readback. The final 128K
SHA-256 is `91a61597d9f5b239971169047876918091841468ffe654fe3cb8ed8a1d0200c3`.

This slice is accepted. COM4 closed at the HIMON prompt in Bank 3. The separate
operator-observed LED and NMI gates are not changed by this qualification.
No release was published and no commit was made as part of this run.

The [verification receipt](HIMON_AP_RANGE_SIZE_2026-09-16/verification.json)
records sizes, checks, sector CRCs and image identities. The
[evidence manifest](HIMON_AP_RANGE_SIZE_2026-09-16/manifest.json) preserves the
exact old/new artifacts, host receipts, failed and successful fixture logs,
serial traffic and before/final readbacks. Earlier hardware records are intact.
