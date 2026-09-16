# APMAN size reduction - 2026-09-16

This first measured optimization shares two existing operations within APMAN:
successful INSTALL now calls `APMAN_SET_PACKAGE_FACTS`, and APS/AP D share
`APMAN_PRINT_CARRIER_SUMMARY` for `APC name L=length`. Commands, validation,
status values, entry selection, and flash policy are unchanged.

| Measurement | Before | After | Saving |
| --- | ---: | ---: | ---: |
| APMAN BODY | 3,072 (`$0C00`) | 3,031 (`$0BD7`) | 41 bytes |
| BODY end, exclusive | `$7C00` | `$7BD7` | 41 bytes below `$7C00` |
| AP envelope | 3,118 (`$0C2E`) | 3,077 (`$0C05`) | 41 bytes |
| Dense carrier | 4,096 | 4,096 | 0 bytes |
| Allocated carrier sectors | 1 | 1 | 0 sectors |
| HIMON occupied bytes | 11,868 | 11,868 | 0 bytes |
| ASM-F2 occupied bytes | 15,235 | 15,235 | 0 bytes |

The INSTALL substitution replaces 22 inline bytes with a three-byte JSR,
saving 19. The two 29-byte print sequences become two JSRs and one 30-byte
routine including RTS, saving 22. No feature or table was removed. The
555-byte carried flash worker remains byte-identical. The smaller package
uses more erased padding in the same carrier sector; it does not release
Bank-3 space or a flash sector.

Each helper invocation adds one JSR/RTS pair: 12 cycles of call overhead and
two transient stack bytes. A listing can invoke it for several carriers.
The focused APS-all fixture's observed stack peak
rises from 18 to 20 bytes; other fixture peaks stay unchanged. Those figures
include the synthetic caller and are not interrupt-stack bounds.
No persistent RAM, scratch, service card, or ABI
allocation changes. The remaining overlay reserve is still part of the
`$7000-$7BFF` manager/tool tray; this change does not enlarge application
destination ranges or move the command shadow.

Qualification uses the frozen HIMON/ASM stamp `0915(2324)`, exact unchanged
resident-artifact comparison, the full supported regression, and focused
linked-code comparison with the preceding manager. The focused tests exercise
successful INSTALL staging/card/worker setup and exact carrier output with
different PACK40 name lengths. Host INSTALL checks stop before the worker;
the board cycle separately proves real programming, discovery and recovery.

Evidence and final board results are recorded in
[the size qualification record](../LOGS/APMAN_SIZE_2026-09-16.md).
