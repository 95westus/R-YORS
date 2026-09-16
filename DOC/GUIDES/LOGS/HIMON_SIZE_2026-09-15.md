# HIMON Size Qualification — 2026-09-15

Result: the 268-byte HIMON reduction passed host checks and focused COM4
hardware qualification, including physical RESET and exact ROM readback.
The image occupies 11,754 bytes, ends at `$EDEA` exclusive, and leaves 534
bytes below STR8-N at `$F000` (previously 12,022 bytes, end `$EEF6`).

| Change | Bytes saved |
| --- | ---: |
| Remove unreachable non-FAST FNV update routines | 51 |
| Reuse AP seal-verifier pointer/count setup | 37 |
| Compact mnemonic names and generate bit-operation digits | 180 net |
| Total | 268 |

The active FAST FNV implementation, published FNV records, AP-v2 format,
and visible mnemonic spelling are unchanged. The frozen visible stamp is
`HIMON V 00.0914(1200)`; hashes distinguish this image from earlier builds
using that same stamp.

## Image identity and installation

- Linked `himon-rom-c000.s19` SHA-256:
  `F71AF701304AA7653A392DDACF6282BCBD1B2F4FED6FC18AC7A23BA23530795A`.
- Dense C-E transfer SHA-256:
  `CD1C0101F1A0BC0A2E8D7691A58E492506500706A3A7F2643475C0161464C472`.
  The stream covers exactly `$C000-$EFFF`, has S9 entry `$C000`, and pads
  `$EDEA-$EFFF` with `$FF`. It contains no sector-F payload.
- Before-install Bank-3 `$8000-$FFFF` SHA-256:
  `2DF0C27DEEB0AD27101C8A75C07B1D6275D11A061C3AB4E94E3FA2B0CF05703C`.
- After-install and after-physical-RESET full-bank SHA-256:
  `7C37815A3EC8C96F6DEC29662D41A5DC2318D39F406BB4AFEAA0975BA8E36B7E`.

COM4 at 115200 baud initially exposed STR8-N 1.34. `C` returned `NO`.
A read-only RAM dumper established that WDCMONV2 occupied sectors 8-B and
C-E contained zero bytes, with no HIMON marker. ASM-F2 was absent. The
STR8-N resident/worker/configuration/vector bytes matched the local 1.34
build. D0 described WDCV2 and D1-D3 were erased.

The STR8-N guarded installer enrolled Bank 3 with `TYPE=5A`, `DESC=RYORS`,
then installed only C-E:

```text
STR8-N>I
B0-3: 3
RANGE: C-E
TYPE: 5A
DESC: RYORS
I B3 C-E WRITE? Y: Y
S19
..COMMIT? Y: Y.
OK
STR8-N>C
BOOT COLD

HIMON V 00.0914(1200)
>
```

Full readback matched the candidate C-E bytes exactly. Sectors 8-B,
STR8-N resident/worker code, D0-D2, configuration, and vectors were unchanged.
The only additional change was the installer-owned D3 descriptor at `$FFE0`:
`5AFFFFFF52594F5253FE00C0FCFFFFFF` (RYORS, entry `$C000`, completed journal).

| Bank-3 sector | Before CRC32 | After CRC32 |
| --- | --- | --- |
| 8 | A4344138 | A4344138 |
| 9 | D66BA400 | D66BA400 |
| A | E6172F88 | E6172F88 |
| B | C71C0011 | C71C0011 |
| C | C71C0011 | 6FA1DD87 |
| D | C71C0011 | 1924788E |
| E | C71C0011 | EBDA7118 |
| F | D819F7E9 | 3C97D488 |

Sector F differs solely because of the D3 enrollment above.

## Checks

Host checks passed with frozen stamp `0914(1200)`: full `make -C SRC asm-test`,
focused banked AP, STR8 record-client, and I/O LED checks. The new linked-image
`himon-size-check` passed both original and reduced images: 256 opcode
displays, 262 FNV vectors, and 77 AP parse/load cases. In-memory mutation
checks detected mnemonic corruption, a damaged FNV basis, and bypassed seal
comparison.

Hardware checks passed:

1. Compact `?` help and resident hash lookup:
   `FNV1A_INIT` resolved as `4B9AEE1E ENTRY=E22D K=05 HASH INIT`;
   `FNV1A_UPDATE_A_FAST` as `A8802314 ENTRY=E274 K=05 HASH MIX`.
2. A RAM fixture invoked the linked debugger printer for all 256 opcode
   values. Every display matched the independent expected mnemonic,
   including all RMB/SMB/BBR/BBS digits, unknown-opcode suppression, and
   BRK signature `$5A`. This prints WAI/STP names without executing them.
3. Six valid direct AP loads covered BODY lengths 1, 255, 256, and 257,
   differing package alignment, and sources `$20DC`, `$20DE`, and `$37F8`.
   Each loaded to `$4000`, executed, and returned; readback matched the
   complete body and surrounding `$CC` guards.
4. Seven corrupt AP packages (each of four seal hash bytes, first/last BODY
   bytes, and inconsistent seal length) returned `APERR=$07`, did not
   execute, and left the destination and guards unchanged.
5. A real BRK fixture exercised 34 `N` steps: LDA, STA, and all 32 numbered
   RMB/SMB/BBR/BBS operations. Every step reported the expected mnemonic
   and debugger trap. `X` then reached `BRK 42 PC=305A`.
6. Physical RESET produced the following capture, followed by successful
   help and FNV lookup. All 32,768 Bank-3 bytes matched the post-install
   readback exactly.

```text
RST H

STR8-N 1.34
0-2 C W S:
BOOT WARM

HIMON V 00.0914(1200)
>
```

This is focused qualification of the HIMON size changes. It does not claim
an onboard ASM-F2 regression, physical LED observation, or requalification
of Bank 0-2 carriers. WDCMONV2 was preserved.

## Retained evidence

The append-only [raw serial transcript](HIMON_SIZE_2026-09-15.jsonl) contains
timestamped TX/RX bytes encoded as hex, including installation, RAM fixtures,
AP cases, ROM dumps, debugger stepping, and physical RESET. At completion it
is 1,058,696 bytes, SHA-256
`404819EED1642EE8A6E1BAD30CB33501C96F4750F5BE776B5429F02F4056BC85`.
Earlier hardware transcripts are retained unchanged.

## Timestamp correction and reinstall — 22:33 build

At the user's request, the image was rebuilt with the local timestamp
`0915(2233)` and reinstalled on COM4. The original frozen-stamp evidence
above remains intact. The current board banner is:

```text
BOOT COLD

HIMON V 00.0915(2233)
>
```

An exact comparison with the previously qualified ROM proved that only the
two high-bit-terminated timestamp strings changed (eight bytes total).
Size remains 11,754 bytes, end `$EDEA`, with 534 bytes free. The linked-image
checks passed again: 256 opcode displays, 262 FNV vectors, and 77 AP cases.
The dense install stream was independently checked for record checksums,
exact `$C000-$EFFF` coverage, and S9 entry `$C000`.

Before installation, full-bank readback matched the previously qualified
image. STR8-N installed C-E, completed its guarded transaction with `OK`,
and cold-entered the new banner. After installation, all 32,768 readback
bytes matched the new C-E payload and preserved surroundings, with the
expected completed second transaction at `$FFEC` (`FC` to `F0`). No other
sector-F byte changed. Compact help and FNV hash lookup passed. Physical
RESET was not repeated for this timestamp-only update.

- Linked S19 SHA-256:
  `1E93E4F018243466E27C8A8619475B0B837D19F89B4302D6AA211B111CC0EDA3`.
- Dense C-E transfer SHA-256:
  `47A15212824901F6B05DDC4FEE9A8EEB051B839BCE4A0CDDC27CC82DF856A50D`.
- Final full-bank readback SHA-256:
  `C3B0FB5210C75A3C1E8EC9B63B3A8FB13F24C2393E94A14B695BA74B23C4C5B7`.
- Separate [reinstall transcript](HIMON_RESTAMP_2026-09-15.jsonl):
  731,162 bytes, SHA-256
  `948A1FA60C191F9FDD55AE8F362E714AA6E972EF7C06162C1F82A2879425EA3A`.
