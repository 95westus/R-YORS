# HIMON/AM03 board qualification — 2026-09-16

Status: **FAILED — do not commit or release AM03 as board-accepted.**

The host gate passed, including 59 scoped integration cases, 43 retained RAM
uniqueness cases, and 11 integrated handoff cases. The installed candidate was
AM03 `B2:8` SHA-256
`34FDEEE4902C7D88222D2A6F84010D26A6257550EED1CE7AEBEA77C970F4B0F0`
paired with HIMON `00.0916(1949)`.

Installation and integrity checks passed:

- AM03 and HIMON writes committed and exact live readback passed.
- HIMON C000–EFFF SHA-256 is
  `99A83CD507B48EE898D815E4A2F914F11A556CA6C377F95C5365A2C745298153`.
- Explicit `AP B2 APTEST 5000` loaded, ran, and returned correctly.
- An intentional RAM-provider plus bank-carrier duplicate returned `$D2`.
- The final four-bank archive exactly matches the constructed expected image.
  Its SHA-256 is
  `6D6E31CCAA7BC38B07D7894268E1AAC32FF6CEB5419D87E4D18B7D1B4C623347`.
- Against the accepted STR8-N v1.35/policy-A6 baseline, only B2:8, B3:D,
  B3:E, and B3:F differ. Three journal transactions (B2, B3, B3) account
  for the top-sector journal changes.

The acceptance gate failed in AM03's successful resident-miss handoff:

- With `$3000-$3FFF` verified zero, bare `APTEST` returned to the prompt
  without `GO 2002`.
- With one valid, unique `RAMTEST` AP in that window, bare `RAMTEST` also
  returned without entering the child.
- The provider window was restored to zero after testing.

Recovery testing proved that the timestamped HIMON bootstrap requires AM03:
an exact full-B2 restoration of the accepted AM02 baseline completed safely,
but `APS B2 APMAN` then returned `APMAN NF`. AM03 was therefore reinstalled
at B2:8 and all 32 KiB of B2 were read back exactly. The board closes on the
paired HIMON/AM03 candidate, with top-sector SHA-256
`F354D2276C6D0BB374E6C838447AA5BCE75D9B92353AFC21D7074844B2AD2A33`.
This restores explicit AP operation but does not cure or waive the failed
resident-miss handoff gate.

The raw serial record is `serial-com4.jsonl`. `finish-himon-result.json` and
`final-verification.json` capture exact image checks. `smoke.py` and
`ram_smoke.py` retain the failing assertions so the defect cannot be mistaken
for acceptance. `restore-am02-result.json` and `reinstall-am03-result.json`
retain the recovery and compatibility diagnosis.

## Subsequent correction: handoff passes

The failure interpretation above is superseded by
[HANDOFF_CORRECTION.md](HANDOFF_CORRECTION.md). The original tests required a
`GO` banner that AM03 does not emit. `verify_handoff.py` now proves actual RAM
child execution through a marker write and bank child execution through the
BANKDUMP menu/map/return, with state retirement and provider preservation.
The same installed firmware passes; no firmware or flash change was needed.
Earlier transcripts and failed test scripts are retained intact. Physical
reset remains a separate open gate.

## Subsequent physical-reset pass

Physical RESET now passes: STR8-N 1.35 boots into HIMON `00.0916(1949)`,
the ASM resume flag is clear, and all three corrected handoff checks pass
again. All 32 flash sectors match the expected image; no flash writes were
performed during these tests. See the appended
[acceptance record](HANDOFF_CORRECTION.md#subsequent-physical-reset-acceptance)
and [machine-readable result](physical-reset-20260916-203949/result.json).
