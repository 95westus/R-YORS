# STR8 V1.02 Presentation-Successor Board Test

Status: fully hardware-accepted. Exact refresh, visible presentation, live
selection, cold timeout, warm HIMON, post-refresh `C-E` install, and key
discard at the `WAIT` phase boundary are accepted.

## Accepted Candidate

```text
source commit                  8193fc0
visible STR8 identity          STR8-N 1.02/0809.2224
himon-str8-rom.bin SHA-256     4933A5FE0BE772D200C61F3712A3560FF6D577159FD6D597F60183C31EB4E6DE
refresh source SHA-256         C44E7AE23275965B32DF3E67DBB5F774408084DB46360F9A0507E9A8EC726F20
board transcript SHA-256       D2A3DAE1438809F3936D6C087B35E3987F0990B6D2A188FD5205F7F9EBB3D2AC
```

Reproduce the exact refresh source with:

```text
make -C SRC str8-i-refresh-a "HIMON_VISIBLE_STAMP=0809(2224)"
```

## Accepted Evidence

The directory-preserving writer assembled through `$5000`. `S` returned
`TW STG` / `TW OK`; `P` performed its mandatory verify, accepted the full
`WRITE` confirmation, and returned `TW PRG` / `TW OK`.

The new resident then displayed the intended two phases:

```text
STR8-N 1.02/0809.2224
WAIT ................
0-2 BOOT H HIMON S MENU ..S
I H J0-3
STR8-N>
```

A later no-input selector completed all 16 live dots and cold-booted normally.
A live `H` selection printed `BOOT WARM` and entered the identified local
HIMON. Two Bank-3 `C-E` transactions each printed three sector dots and
`I OK`, proving that the presentation-only resident change did not disturb
the range installer.

The resulting HIMON identity remained `00.0808(2058)` because those two sends
used the older self-contained `C-E` stream. That is payload identity, not a
STR8 failure. Likewise, trying a self-contained STR8 `I` stream with HIMON
`L F` correctly failed at its protected `$0200` worker records:

```text
L @0200
LF PROT=0200
LF FAIL=02 WR=0000 SKIP=422B GO=8000
```

## Final Presentation Gate

1. Reset and type `S` once while the first `WAIT` dots are printing.
2. Do not type during the menu dots.
3. Require all 16 menu dots followed by the ordinary `BOOT COLD` path. The
   early `S` must not enter the STR8 menu.
4. Reset once more and type `S` during the menu dots; require the STR8 prompt.

After those two observations, the presentation successor can be called fully
hardware-accepted. No erase/program operation is needed for this final gate.

### 2026-08-18 Final Operator Acceptance

The operator explicitly accepted the remaining phase-boundary behavior on the
installed STR8-N `1.21` successor: a key deliberately sent during `WAIT` was
discarded and did not become a selector response. Discarded quarantine input
has no printable terminal token, so this is operator-observed evidence. The
same retained session shows live selector input separately as `0-2 H S: .S`
and entry to the STR8 prompt. This closes the final no-flash presentation gate.

## Fresh HIMON Range Stream

A current worker-bearing HIMON stream was generated after reviewing the
transcript:

```text
identity                       HIMON V 00.0809(2240)
path                           SRC/BUILD/s19/str8-v1-i-himon-c-e.s19
SHA-256                        D59F3FDEE53CE65377D3C105D569F93170E815A9BF2923833BFE9648DDFF7C70
```

Send this file only after STR8 `I`, Bank 3, range `C-E`. Do not send it to
HIMON `L F`; its initial `$0200-$042A` records are the exact mutation worker
required by STR8.
