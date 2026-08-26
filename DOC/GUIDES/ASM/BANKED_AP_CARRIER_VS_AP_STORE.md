# Banked AP Carrier Versus AP Store

Both paths persist an AP v2 envelope in banked flash and use the same HIMON
loader. They solve different problems.

```text
AP carrier = one complete named program in one 4K sector
AP Store   = managed objects, generations, chunks, and deletion history
```

In ordinary terms, a carrier is a labeled toolbox in its own locker. AP Store
is a filing system that can keep several versions and reconstruct a large item
from several records.

| Property | AP carrier (APC) | AP Store V1 |
|---|---|---|
| Flash shape | One complete AP v2 envelope at a 4K sector base | AP data inside append-only records/chunks |
| Maximum | `$1000` bytes including the envelope | `$1000` envelope through the current chained-object tools |
| Name | AP executable `ENTRY` name | Object number plus generation |
| Install | `SEAL> INSTALL source Bn` | Plan/confirm/execute transit tools |
| Find | Bank plus name or sector address | Newest or exact object generation |
| Run | `AP Bn name` or `AP Bn s000` | Reconstruct, validate, then load/run |
| Load only | `AP L Bn name` | Reader/tool-specific operation |
| Status | `APS`, `APS Bn`, `APS Bn name` | Same `APS` media view plus store tools |
| Replacement | Erase/reinstall the whole carrier sector | Append a newer generation |
| Deletion | Reclaim/erase the carrier sector | Append a tombstone |

## Current APMAN carrier path

APMAN is itself an APC. HIMON discovers it in Bank 2, then Bank 1, then Bank 0,
loads it at `$7000`, and gives it the command line. The initial release places
APMAN at B2:`$8000`. Bank 0 has no hard-coded special status; current WDCMONV2
contents are simply occupied media and are never selected as an erased hole.

At `SEAL>`, a named package can be installed with one command:

```text
PACKAGE BANKAUDIT $3000
INSTALL 3000 B1
```

The explicit `B1` is the destructive confirmation. APMAN validates the
envelope, requires its total length to be at most `$1000`, skips the configured
WORK and B3:F-backup locations, selects the first completely erased sector in
that bank, writes and verifies the whole sector from RAM, restores Bank 3, and
prints the exact location. It does not pack several programs into one sector.

After reset, either the package name or its sector address may be used:

```text
APS B1
AP B1 BANKAUDIT
AP B1 A000
AP L B1 BANKAUDIT
```

`AP` loads, fixes imports/relocations, and executes the entry. `AP L` performs
the same load/fix but does not execute. With no explicit RAM destination, the
AP header's sealed base is used. An optional final destination overrides it:

```text
AP B1 BANKAUDIT 3000
AP L B1 A000 3000
```

Because APMAN itself is live at `$7000`, its first version permits the loaded
BODY only in `$2000-$6FFF` (the exclusive end may equal `$7000`). This is a
manager-overlay limit, not a carrier-media limit. Direct recovery form
`AP package-address destination` remains resident in HIMON.

Names are the AP executable `ENTRY` identities already stored in the envelope;
there is no second carrier directory. A name collision within the selected
bank fails. A sector address always disambiguates.

`APS` remains AP Status:

- `APS` prints all Bank 0-2 sector roles/media states.
- `APS B1` lists valid carriers in Bank 1.
- `APS B1 BANKAUDIT` or `APS B1 A000` prints one carrier's name, envelope
  length, and sealed load address.

AP Store V1 media bytes are unchanged. Its active headers still appear as
`+ G=nnnn`; configured roles appear as `= WORK` and `= BKUP B3F`; erased and
unknown media appear as `HDR ERASED` and `UNMANAGED`.

The old STR8-N Bank Maintenance `P` command remains a narrow recovery writer
for legacy small envelopes. It is no longer the normal ASM/package/install
flow and does not provide APMAN name discovery.

## AP Store V1

AP Store manages append-only records rather than assigning one sector to one
program. It provides object generations, chaining, validation, tombstones,
capacity planning, and replay protection. Those features require more tools
and more operator steps. A later consolidated AP Store manager may itself be
an APC loaded into RAM, but the V1 media layout does not need to change.

Choose a carrier for one named utility that should be easy to assemble,
install, reboot, list, and run. Choose AP Store when version history, shared
managed capacity, multi-record reconstruction, or tombstone deletion is the
actual requirement.

The exact first-carrier board sequence is in
[APMAN_V1_BOARD_TEST.md](APMAN_V1_BOARD_TEST.md).
