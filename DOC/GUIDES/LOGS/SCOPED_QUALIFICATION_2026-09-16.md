# Scoped banked AP qualification — 2026-09-16

The banked AP portion is accepted on COM4 with policy `$A6`, following the
[host gates](SCOPED_HOST_GATES_2026-09-16.md) and
[paired installation smoke](SCOPED_SMOKE_BOARD_2026-09-16.md).
BANKDUMP is retained at **B2:A**; APTEST remains at B2:9. RAM-provider/HREC
search and SPI SRAM WORK allocation remain separate, unimplemented work.

## Evidence and scope

The [evidence directory](SCOPED_QUALIFICATION_2026-09-16/) retains raw serial,
scripts, host results, fixture images, every programming checkpoint, readbacks,
operator observations, reset capture and the complete final four-bank archive.
`evidence-manifest.json` hashes every retained file except itself.
Earlier hardware records are unchanged.

Ten host-modeled fixture transitions and their real-board counterparts pass:

| Case | Board result |
| --- | --- |
| Unique BANKDUMP in B2:A, then B1:A | Named and bare launch, real imports, menu and return pass |
| Valid BANKDUMP in both banks | `$D2`, no execution |
| Corrupt BODY CRC | `$D1`, no execution |
| Forged canonical name with BANKDUMP hash | `$D1`, no execution |
| Out-of-bounds export entry | `$D1`, no execution |
| Unresolved import | `$D3`, no entry |
| External FNV1A_INIT shadow | Resident command wins without external load |
| Temporary B1:A erased | BANKDUMP missing, `$D1` |
| Final BANKDUMP restored to B2:A | Header, page, map, all-pages/quit and three exact linked imports pass |

The real BANKDUMP BODY is wrapped with named imports resolved against the
installed resident records. This does not reuse stale raw import addresses.
The host checks enforce selector restoration, no foreign-bank instruction
fetch and no flash writes during lookup. Fixture installation itself uses the
existing STR8 installer and its journal, with exact pre/post readbacks.

## Role and display proof

Four additional host diagnostics and their board runs pass. The actual AM02
role predicate protects only B2:F across all 24 B0–B2 locations; B1:E/F are
ordinary locations. These predicate tests do not dispatch an erase/program worker.

RAM-only hooks pace the production finder/AM02 staging path after checked bank
selection, record Port A and actual PCR, and restore the original instructions
before returning. B2 produces `82 92 A2 B2 C2 D2 E2`; B1 produces
`81 91 A1 B1 C1 D1 E1 F1`. Both return to `43`. The operator confirmed B2
and requested a repeat of B1 before confirming its sequence. The first and
repeated B1 receipts are both retained. B0-only request produces no staged
sector or PCR sample under `$A6`. PCR samples alternate selected B2 (`EC`) or
B1 (`CE`) with restored B3 (`EE`).

This closes the scoped bank/sector observation gate using paced RAM
instrumentation and explicit human observation. It is not a logic-analyzer
capture of every transition during uninstrumented command timing. An initial
diagnostic build assertion and the superseded, unused first diagnostic version
are retained; only the corrected v2 was used for this board proof.

## Reset, final state and isolation

Physical RESET was captured receive-only before post-reset commands. APTEST
executes at `$5002` with its exact six-byte BODY. Bare BANKDUMP loads B2:A,
completes its map and restores B3. The complete post-reset 128 KiB readback
matches the host-predicted final image byte for byte:

`8a9977c675364f95a53b58b23067ba469d3595026064a2530e7c3e9db3096f4b`

Relative to the accepted step-2 baseline, only **B2:A and B3:F** differ.
B1:A is again entirely erased. B3:F differences are directory enrollment and
installer journal bytes: `FFC0 FFC4 FFC5 FFC6 FFC7 FFC8 FFC9 FFCC FFCD FFDC FFDD`.
The initially erased B1 directory row is now enrolled as type `$A2`, descriptor
`APC01`, with no entry. That metadata is intentionally retained after removing
the temporary fixture; it is not firmware damage or an unreported rollback.

Roles/policy remain `FF 2F A6`: no flash WORK, protected backup B2:F, B1+B2
discovery enabled. B0, all B1 payload sectors, B2:8 AM02, B2:9 APTEST, both
retained backup sectors and all firmware bytes remain exact. HIMON stays
12,280 bytes (8 free); AM02 BODY stays 3,059 bytes (13 free).
No firmware source change or additional top updater was needed for this slice.
