# PIA LED Banked AP Card

This is the complete ASM -> named AP package -> banked flash -> cold boot ->
AP run example. It uses Bank 2 sector 8 as the carrier and loads the LED body
at `$4000`. Use it only while Bank Maintenance `M` reports `B2 8` erased.
For the storage-model distinction, see
[BANKED_AP_CARRIER_VS_AP_STORE.md](BANKED_AP_CARRIER_VS_AP_STORE.md).

## 1. Assemble and package the LED program

At the HIMON `>` prompt:

```text
ASM NEW
```

Send the complete
[pia-led-show-2000.a](SAMPLES/pia-led-show-2000.a). At `SEAL>`, enter:

```text
SEAL
PACKAGE MAIN $7000
.
```

Require:

```text
SEAL OK
PKG OK @=$7000 L=$00A3
ASM BYE
```

`MAIN` is the package identity and must match the source's `ENTRY MAIN`.

## 2. Put that package into Bank 2 sector 8

At the HIMON `>` prompt:

```text
ASM NEW
```

Send the complete release file
`RELEASE/ARTIFACTS/SOURCES/str8n-v1.23-bank-maint-menu-2000.a`. At `SEAL>`,
enter:

```text
.
G 2000
```

At the Bank Maintenance prompt, enter exactly:

```text
BM> P
TYPE PUT BnS000 (n=0-2,S=8-F)> PUT B28000
 OK
BM> Q
```

Stop if the tool prints `ABORT`, `PROTECTED ROLE`, or `!` instead of `OK`.
`PUT B28000` means Bank 2, address `$8000`, and consumes the exact AP envelope
at `$7000`. It preserves the rest of the 4K sector.

## 3. Cold boot and run only from banked flash

After `Q` returns to STR8-N, enter:

```text
STR8-N>C
BOOT COLD
RAM ZERO OK
```

At the new HIMON `>` prompt:

```text
AP B2 $8000 $4000
```

The eight PIA LEDs should run the complete pattern. Require the final return to
show `A=AC` with carry set. No `G` command follows `AP`: `AP` loads, relocates,
and runs the package entry itself.
