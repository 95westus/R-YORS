# STR8-N V1.02 Release Record

Status: frozen hardware-accepted release. Firmware source is commit
`ee45327281b2`; later commits freeze its operator rail, hardware evidence,
release status, and generated documentation. Current source is a partially
hardware-accepted presentation successor and is not byte-identical to this
record; use the listed commit to reproduce these hashes and transcripts.

## Frozen Build

The release identity is the exact compact candidate used by the final Bank-3
sector-F board proof:

```text
STR8-N V 00.0808(2058) $F
```

Reproduce its release artifacts from the repository root with:

```text
make -C SRC str8-v1-artifact "HIMON_VISIBLE_STAMP=0808(2058)"
make -C SRC himon-str8-rom-install-s19 "HIMON_VISIBLE_STAMP=0808(2058)"
```

Require these SHA-256 identities:

```text
B786C0A5C33B72212EADFBE9289A3293825CAB9830CF412E0EADC548EA41668B  SRC/BUILD/bin/himon-str8-rom.bin
B786C0A5C33B72212EADFBE9289A3293825CAB9830CF412E0EADC548EA41668B  SRC/BUILD/bin/himon-str8-v1.bin
4885D7CDA0DF05587248003C9DC8B3C8BA22E5B2989B1F90B8F50484CA0F8B12  SRC/BUILD/s19/himon-str8-rom-install.s19
4885D7CDA0DF05587248003C9DC8B3C8BA22E5B2989B1F90B8F50484CA0F8B12  SRC/BUILD/s19/himon-str8-v1-install.s19
CCC70455DDBEBBF02D793A4EC0AF681FD37BF7DB87908116434ED294E02B0D72  SRC/BUILD/s19/str8-v1-i-bank012.s19
814403A0232D7C72259E44125070626AAB4DA1835368B8D465510520734E67F2  SRC/BUILD/s19/str8-v1-i-asm-8-b.s19
D8DBCC1607A82200877910525068B670BD1DE0E3EBAD04C1531757F4355D2896  SRC/BUILD/s19/str8-v1-i-himon-c-e.s19
BFC071230493EC6F8E09717CC4E6EFAEB396AD4D40B5E1BBD754A2EBEF1389DB  SRC/BUILD/generated/asm-samples/str8n-v1-current-compact-refresh-transient-3000.a
```

The two BIN names and two install-S19 names are exact aliases. The combined
BIN is the host/release artifact; its compact STR8 sector F and refresh source
are the exact bytes accepted by the final board rail.

## Accepted Layout And Function

```text
resident                       $F000-$FE5E  $0E5F bytes
free/reserve gap               $FE5F-$FF1E  $00C0 bytes
growth beyond hard reserve                         $0080 bytes
packed jump worker             $FF1F-$FFAF  $0091 bytes
fixed Bank-3 directory         $FFB0-$FFEF  $0040 bytes
NMI / RESET / IRQ-BRK          $F09C / $F000 / $F0B0
```

Banks 0-2 accept every contiguous 4K-aligned range from 4K through 32K. Bank 3
accepts every contiguous 4K-aligned range from 4K through 28K and rejects its
live sector F. Input remains dense S19 over the accepted FTDI/Tera Term
profile. The resident command surface is `I H J0-3`; the reset selector is
`0/1/2=BOOT H=HIMON S=STR8`.

## Closure Evidence

The final host run passed:

```text
make -C SRC all
make -C SRC str8-directory-check
make -C SRC str8-installer-dry-check
make -C SRC str8-installer-transaction-check
make -C SRC str8-v1-negative-streams str8-v1-artifact str8-v1-range-proof-streams
make -C SRC release
```

The exhaustive transaction gate accepted 261 range cases, 47 installer cases,
94 journal cases, 77 directory-writer cases, 33 record cases, 36 line/input
cases, 13 startup cases, and 5 bank-jump cases. The release target regenerated
the routine maps and passed binary policy.

The hardware rails accepted dense 32K/28K transport, parameterized `8-B` and
`C-E` mutation, interruption/retry, directory preservation, `J0`-`J3`, local
positive and negative `H`, read-only bank staging, a valid Bank-0 AP run, and
the exact compact refresh. The final compact run accepted stage, verify,
confirmed program, live readback, physical reset, warm local HIMON, clean NMI,
and the final cold path. See
[STR8_V1_02_COMPACT_REFRESH_BOARD_TEST.md](STR8_V1_02_COMPACT_REFRESH_BOARD_TEST.md)
and the hardware log.

## Deliberately Outside V1.02

STR8 self-update, sparse S19, ACIA transport, catalog-aware repair, managed
backup allocation, external S19 export, and wear accounting remain later
releases. Direct raw `$F003` modes `$05-$07` board probes and a raw `$7FEC`
bank-state dump are optional diagnostic closure, not V1.02 release gates; the
compiled worker matrix already enforces the fail-closed service contract.
