# AP/FNV follow-up - 2026-09-16

COM4 at 115200 baud completes the Microchess physical-reset persistence gate
without installing or changing firmware. The first scoped-search policy
primitive is separately qualified on the host; it is not installed firmware.

## Microchess persistence

Initial discovery found `MICROCHESS L=06A6 @2000` at B1:$9000 and
`APMAN L=0C05 @7000` at B2:$8000. Receive-only capture then recorded:

```text
RST H
STR8-N 1.34
0-2 C W S:
BOOT WARM
HIMON V 00.0915(2324)
>
```

No serial bytes were transmitted by the reset-capture script. After this
hardware reset, `APS B1 MICROCHESS` rediscovered the same carrier and bare
`MICROCHESS` printed `AP LOAD B1 9000 -> 2000` and `GO 2000`.
`C` initialized the board, `H` produced all three exact command/copyright/AI
notice lines, and `Q` returned to HIMON. Subsequent `APS B2 APMAN` succeeded.
This completes the remaining carrier/alias reset gate; earlier assembly,
package, import, play and return-register evidence remains unchanged.

The initial follow-up harness incorrectly required CRLF before the HIMON
prompt after `Q`. The application returns a bare `>` there. The harness
stopped after the successful return, was corrected to accept that prompt,
and the full discovery/launch/C/H/Q sequence passed. Both runs remain in the
raw transcript. The uninitialized launch display is not a new-game board;
`C` is required as documented.

## LED observation

Three read-only `APS B0` scans, then three B1 scans, then three B2 scans ran
with pauses. All returned to HIMON. B1 listed BANKAUDIT at $8000 and
MICROCHESS at $9000; B2 listed APMAN at $8000 and APTEST at $9000.

The operator reported: "i saw the lights changing, but was not able to
identify the sequences". This establishes visible activity, not exact
bank/sector encoding. The APMAN visual acceptance checkbox stays open.
No new delay or LED instrumentation was added to firmware to alter this test.

## Host work and limits

The [RAM contract](../AP/HIMON_AP_SCOPED_RAM_CONTRACT.md) records current
ownership and the private `$7D40-$7D5F` foreground proof card. A stale source
comment claiming `$1A00-$1FFF` was wholly unclaimed was corrected to describe
the manager command shadow and application ownership.

`fnv-scope-policy.inc` is a standalone 28-byte W65C02 routine. It accepts a
captured policy byte in A and request mask in X; returns the effective mask
and writes only request/allowed/effective card fields. WDC-linked instructions
pass all 65,536 byte combinations in py65. Invalid and erased policies
disable lookup; every additional bit-clear of `$A6` still excludes B0. The
runner forbids reads outside code, caller stack and allowed-mask storage, and
writes outside the three result fields. It performs no board I/O.

`make -C SRC asm-test HIMON_VISIBLE_STAMP="0915(2324)"` passed, including
the 53 current AP contract cases, 13 boundary cases, 30,966 range comparisons,
1,024 initialization guard cases, 153 parser comparisons, 18 APMAN cases,
and Microchess's exact onboard assembly/package comparison. The standalone
policy check also passed after its read-boundary assertions were added.
Final HIMON S19, ASM-F2 S19, and APMAN envelope are byte-identical to the
accepted parser-initialization baseline. `git diff --check` passed.

Production HIMON/APMAN do not include this routine. `$FFF2`, bank enrollment,
automatic discovery, provider validation and dispatch are unchanged. The
policy primitive is only the first implementation slice, not scoped-search
acceptance. B2:9 contains APTEST, so the older BANKDUMP example requires a
separately prepared erased-sector fixture.

## Evidence

The [manifest](AP_FNV_FOLLOWUP_2026-09-16/manifest.json) retains the raw serial
log, reset capture, follow-up scripts, check results, and host validation.
Local working artifacts are under `LOCAL/ap-fnv-followup-20260916/`.
Earlier hardware transcripts were preserved. COM4 was closed at HIMON;
no flash-programming commands, commits or release publication were performed.
