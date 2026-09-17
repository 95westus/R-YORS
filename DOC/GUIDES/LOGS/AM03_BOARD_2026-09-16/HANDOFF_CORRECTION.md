# AM03 handoff verification correction

The earlier diagnosis of a failed successful handoff was incorrect. Both
`smoke.py` and `ram_smoke.py` stopped on `assert b'GO 2002' in reply` before
checking child memory. AM03's success path retires discovery state and jumps
to the child without printing that message. The host integration tests already
expect empty output for this path. The missing banner did not prove failure.

The replacement `verify_handoff.py` passes on COM4 with the same installed
AM03/HIMON binaries:

- Bare APTEST replaces a zeroed destination with its exact six-byte BODY and
  clears the scope card.
- Unique RAMTEST enters at offset two and writes `$A5` to a previously zeroed
  `$6900` marker. This proves execution, beyond merely copying the BODY.
- The RAM provider is unchanged, and the scope card, private state, and entire
  staging tray are zero after the child returns.
- Bare BANKDUMP performs its imported console calls, displays the menu and
  four-bank map, and returns with `BANKDUMP MAP OK; B3 RESTORED`.
- The top sector is unchanged. Temporary provider and marker RAM are restored
  and verified.

Results: `handoff-verification.json`; raw transcript:
`handoff-verification-serial.jsonl`. Original failed harness scripts and raw
transcripts remain intact. Use `verify_handoff.py` for current handoff checks.
No firmware modification or flash write was needed for this correction.

The installed pair is HIMON `00.0916(1949)` and AM03 at B2:8, with STR8-N
1.35 and policy A6. Top SHA-256:
`F354D2276C6D0BB374E6C838447AA5BCE75D9B92353AFC21D7074844B2AD2A33`.
AM03 BODY is 4017 bytes; its 4063-byte envelope leaves 33 carrier bytes.
This corrects the handoff verdict; physical-reset acceptance remains open.

## Subsequent physical-reset acceptance

The operator pressed physical RESET during the receive-only capture in
`physical-reset-20260916-203949`. The board reported `RST H`, STR8-N 1.35,
`BOOT WARM`, and HIMON `00.0916(1949)`, then returned to the prompt.
The top sector matched exactly and the ASM resume flag was cleared.

All three corrected handoff checks passed again after reset: bank APTEST,
RAM child marker/provider preservation/state retirement, and BANKDUMP
imports/menu/map/return. Complete readback of all four banks matched the
expected image across all 32 sectors. No flash writes were performed.
The expected image accounts for the already-recorded installer journal
advance at `$FFDE` from `$FC` to `$C0` after the earlier snapshot.

Full-flash SHA-256:
`3f550b36ab774e9ab190743af68b8266feec7916685756a3fe8a2873d6b760ae`.

Evidence: [final result](physical-reset-20260916-203949/result.json),
[reset checks](physical-reset-20260916-203949/reset.json),
[handoff checks](physical-reset-20260916-203949/handoff-verification.json),
and [serial capture](physical-reset-20260916-203949/serial-com4.jsonl).
This closes the physical-reset gate for this installed pair, not the wider
deferred HREC/SPI feature scope.
