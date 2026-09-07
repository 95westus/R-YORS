# EDU RTC read board test: 2026-09-07

This is the authoritative replacement for the earlier duplicated interactive
captures. The user supplied one clean physical-reset, cold-boot, assemble, and
run transcript for `edu-rtc-read-7000.a`. Repeated source-echo lines are omitted
here; the significant console output is retained verbatim below.

## Environment

- Board: W65C02SXB with W65C02EDU
- Firmware: STR8-N 1.31
- Boot: cold, with `RAM ZERO OK`
- Monitor: HIMON `00.0906(1935)`
- Assembler: ASM-F2 `00.0905(2321)`
- Load and entry address: `$7000`

## Console evidence

```text
>RESET

STR8-N 1.31
0-2 C W S: C
BOOT COLD
RAM ZERO OK

HIMON V 00.0906(1935)
>ASM NEW
ASM-F2 00.0905(2321)
...
ASM>$72BB:         END
ASM OK
SEAL> .
ASM BYE
>G 7000
GO 7000
DATE YY-MM-DD 01-01-01  TIME 00:00:00
WARNING: RTC OSCILLATOR IS NOT RUNNING

#GO# ENTRY=7000
RET A=00 X=65 Y=26 P=37 S=FD Nv-BdIZC
>
```

## Result

Accepted. ASM-F2 assembled the complete source after a cold boot, HIMON ran it
from RAM at `$7000`, the MCP79411 read completed successfully, and the program
returned its documented success result `A=$00`, carry set. The displayed
default-like time and explicit oscillator warning are consistent with the RTC
oscillator not running; this reader intentionally does not initialize or write
the RTC.
