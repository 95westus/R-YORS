# HIMON Message Page And `# !` Board Installation — 2026-09-17

COM4 used 115200 baud with DTR/RTS false. The candidate was built with visible
stamp `0916(1949)`. Its dense `$C000-$EFFF` payload SHA-256 is
`EFB70738BC97D3EBF28C37E6B14571E0244296906CCBA16A58A4E9650EE0DEA8`.

From HIMON, the confirmed `STR8` command performed a cooperating software
restart. `S` selected the STR8-N 1.35 menu. The guarded installer was then run
for Bank 3 and exactly sectors C-E. The 385-record dense S19 transfer reached
the commit gate; the confirmed erase/program/verify transaction returned:

```text
I B3 C-E WRITE? Y:
S19
..COMMIT? Y:
Y.
OK
STR8-N>
```

No sector-F update was requested. STR8-N's transaction verification passed;
an independent flash dump/readback was not performed in this run.

Cold entry reached the newly installed monitor:

```text
C
BOOT COLD

HIMON V 00.0916(1949)
>
```

The primary interactive-call smoke then used the real blocking FTDI routine.
After entering the command, `A` was sent as one byte without Enter:

```text
> # ! BIO_FTDI_READ_BYTE_BLOCK

#20285B85# ENTRY=E8E7
RET A=41 X=E7 Y=07 P=35 S=F9 Nv-BdIzC
>
```

## Follow-up affected-path qualification

The resident catalog and relocated message paths passed help, D/M/G/B usage,
no-context R/X/N, specific FNV lookup, `_FNV`-suffix miss, `# !` syntax/miss,
and K01 listing checks. An unknown bare token still takes the established APMAN
fallback and reports `APMAN ERR=$D1`; this is not an FNV execution failure.

The installed AM03 manager and persistent carriers passed:

```text
APS B2 8000 APC APMAN L=0FDF @6C00
APS B2 9000 APC APTEST L=0034 @2000
AP LOAD B2 9000 -> 5000
GO 5002
5000: 00 00 A9 5A 38 60
```

APTEST detail, load-only, named execution, and quiet bare `APTEST` all produced
the exact body. A Bank-0 APTEST request refused with `$D1`; APMAN self-execution
refused with `$DB`. The complete 24-sector `APS` inventory returned `APS OK`.

BANKAUDIT discovery, load-only, linked execution, imports, all-bank reads, and
Bank-3 restoration passed. Its live Bank-3 sector CRCs were:

```text
B3 8=1C8B 9=07C0 A=A4B7 B=A9ED C=AB82 D=A690 E=7FEC F=437C
```

The candidate S19 independently computes C=`AB82`, D=`A690`, E=`7FEC`, exactly
matching flash. No mutation command was used during qualification.

A RAM-only S19 fixture exercised the shared execution/debug paths. `G 2000`
returned `A=5A X=22 Y=33`; BRK `$42` captured PC `$2012`; `# !` refused with
`# ! LIVE CTX`; R showed the unchanged context; and X resumed it. A second
fixture passed breakpoint capture, `N` decoding/stepping from `$2020` to
`$2022`, A=`$11`, and final X context consumption. Fresh ASM-F2
`00.0915(2324)` assembled `A9 AC 38 60`; HIMON G returned A=`$AC`.

STR8-N software W and C re-entry each returned the correct HIMON banner and
reran APTEST. A later physical RESET was captured receive-only:

```text
RST H

STR8-N 1.35
0-2 C W S:
BOOT WARM

HIMON V 00.0916(1949)
>
```

After reset, the debug context was clear, APTEST again loaded and ran at
`$5002` with its exact body, and the BIO read-byte FNV lookup resolved at
`$E8E7`.

## Independent flash readback

HIMON's read-only memory dump captured the complete mapped Bank 3 range
`$8000-$FFFF` as 32,768 bytes. The readback SHA-256 is:

```text
FE30674662F36542A74047B08B447F736378C0E6DEC96B722F6BC93EEA5EC9AB
```

The independently read `$C000-$EFFF` slice compares byte for byte equal to
`SRC/BUILD/s19/himon-rom-c000.s19` and the installed dense component. Both
actual and expected slice SHA-256 values are:

```text
EFB70738BC97D3EBF28C37E6B14571E0244296906CCBA16A58A4E9650EE0DEA8
```

This comparison includes the 206-byte `$FF` reserve at `$EE32-$EEFF` and the
complete fixed message page at `$EF00-$EFFF`. The readback's `$8000-$BFFF`
ASM area is unchanged from the latest accepted pre-install Bank-3 capture.
The STR8-N 1.35 code, worker, configuration and vectors match the canonical
1.35 top image outside its mutable directory, with the already-qualified
policy byte `$FFF2=$A6` as the sole configured difference.

The readback artifact is retained locally at
`SRC/BUILD/tmp/himon-hash-call-bank3-readback-2026-09-17.bin`. This completes
the storage-level verification and accepts the recently affected monitor, AP,
return-reporting, debugger and boot paths. No release was published.
