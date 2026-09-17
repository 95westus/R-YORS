# HIMON `# !` / `# !+` Split-Report Board Install — 2026-09-17

Status: PASS on COM4 at 115200 baud with DTR/RTS false.

The full `make -C SRC asm-test HIMON_VISIBLE_STAMP="0917(1534)"` suite passed
before the board transaction. The final image uses 12,107 bytes through
`$EE4A`, leaving 181 bytes of `$FF` padding below the fixed message page.

STR8-N 1.35 accepted the guarded `I`, Bank 3, `C-E` transaction. All 385 dense
S19 records were received, COMMIT was explicitly confirmed, programming and
verification returned `OK`, and cold entry printed:

```text
BOOT COLD

HIMON V 00.0917(1534)
>
```

The complete `$C000-$EFFF` board readback equals the candidate byte for byte.
Its payload SHA-256 is
`49C0A779F58BAC0FC5D4EC601096863C0C00D56B25823A6EBFA26C94D308EEDB`.
The `$F000-$FFFF` readback equals its preflight image except for the single
expected Bank-3 journal transition at top-image offset `$FEF`, bits 1:0.
Sectors 8-B and F were not in the requested erase/program range.

The two final behavior checks were:

```text
> # ! FNV1A_INIT

RET A=C5 X=FF Y=07 P=B5 S=F9 Nv-BdIzC
> # !+ FNV1A_INIT

#4B9AEE1E# ENTRY=E3B7
RET A=C5 X=FF Y=07 P=B5 S=F9 Nv-BdIzC
>
```

The exact machine-readable result is in `result.json`; the append-only TX/RX
capture is `serial-com4.jsonl`. `flash_and_verify.py` retains the guarded
transaction and exact readback assertions used for this run.
