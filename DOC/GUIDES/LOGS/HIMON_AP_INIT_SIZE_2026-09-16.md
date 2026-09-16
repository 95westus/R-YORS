# Resident AP initialization size qualification - 2026-09-16

This [parser initialization slice](../AP/HIMON_AP_INIT_SIZE_REDUCTION_2026-09-16.md)
follows the committed range reduction (`2516f2f`). The six-cell indexed clear
saves another ten resident bytes. HIMON is 11,838 bytes, ending at `$EE3E`
exclusive, with 450 bytes free below `$F000`. Clearing costs 37 additional
cycles, or 4.625 microseconds at 8 MHz, with no extra stack or RAM allocation.

## Focused host results

All 1,024 clear/guard cases and 153 old/new parser comparisons pass. The
clear block writes exactly the ten intended cells, leaving all other RAM
unchanged at its endpoint. Full parser cases preserve install-result guards,
all non-stack RAM, written-address sets, A/Y/flags/status and stack depth.
Success X/Y agrees exactly; X differs in 38 early-error comparisons, as
permitted by the existing ABI's volatile failure registers.

All nine generated board-caller fixtures also pass in the linked-code emulator
before hardware use. They seed parser cells and adjacent install results with
`$A5`, call PARSE with three incoming X values, and inspect valid, bad-source
and bad-signature results.

The frozen stamp is `0915(2324)`. The new linked HIMON S19 SHA-256 is
`f71044cc458ca4be773defff18ec7e6a427b4460ca53cc3edba42c8047aa90cf`.

The complete frozen-stamp host command in the size card passes, including
the new initialization gate, the existing 30,966 range cases, 53 contract
cases, 13 ownership cases and five bypass negatives, 18 manager cases, the
ASM/parser/debugger/FNV checks, and all nine S19 payload identity comparisons.
Seven ASM and manager artifact files remain byte-identical to the preceding
build. Whole-PARSE timing over 51 fixtures increases by 29-37 cycles
(3.625-4.625 microseconds at 8 MHz), including moved-branch effects.

## Board installation and workflow

The fresh four-bank COM4 backup exactly matches the previous qualified image,
SHA-256 `91a61597d9f5b239971169047876918091841468ffe654fe3cb8ed8a1d0200c3`.
STR8-N 1.34 installed only B3:C-E. Immediate complete Bank-3 readback matches
the candidate and preserves ASM; outside C-E, only D3 journal byte `$FFED`
changed from `$F0` to `$C0`. STR8 code, configuration and vectors are intact.

All 30 board workflow cases pass: nine initialization-specific cases, ten
destination boundaries, seven source boundaries, persistent manager/import/
BANKAUDIT, fresh ASM/APTEST, and software W/C recovery. On hardware, early
errors return X=`$FF` and the expected status with parser outputs zeroed;
valid PARSE returns the source in X/Y. Install-result guards survive all nine
focused cases. Stale ASM resume after takeover is rejected.

| Artifact | SHA-256 |
| --- | --- |
| HIMON C-E dense payload bytes | `c957f837a816a27b62ff46218d85e7a81ed14c9d3d66abe23db7340c8c9385ba` |
| HIMON C-E install S19 | `913cc42d451f5ad95432a280f167d379106dc23da23ab9f85fcd76fe7c295ed0` |
| Installed Bank 3 | `6753fbd47b96e0e748be07c2024d30763811dd89c8383a0dd88883065c47294a` |

## Physical reset and final isolation

The receive-only trace captured `RST H`, STR8-N 1.34, `BOOT WARM`, and the
expected HIMON stamp. Reset cleared ASM resume. Fresh ASM assembled and ran
`LDA #$AC / SEC / RTS`, returning A=`$AC`, C=1; persistent APTEST ran at
`$5002` with its exact BODY. Bank-3 readback remained identical to the candidate.

Final four-bank readback preserves all of Banks 0-2 and B3:8-B. Only HIMON C-E
and the expected D3 journal byte differ from the fresh backup. All 32 live
BANKAUDIT CRCs match independent final-readback CRCs. The complete 128K
SHA-256 is `a0af5849bcb4985699b58f22daa1a801262469e2172bb15827189990cf5bf1cc`.

The slice is accepted. COM4 closed at the HIMON prompt in Bank 3. No release
was published; the separate visual LED and NMI gates remain unchanged.
The [verification receipt](HIMON_AP_INIT_SIZE_2026-09-16/verification.json) and
[evidence manifest](HIMON_AP_INIT_SIZE_2026-09-16/manifest.json) retain host
results, exact artifacts, serial traffic, timing measurements and complete
before/final readbacks. Earlier records remain intact.
