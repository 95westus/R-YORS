# AP And OIL Guide

This is the current guide to Application Packages (AP), AP Capsules (APC),
the Overlay Integration Layer (OIL), APMAN, and AP Store. For the exact live
command surface, the [capability matrix](../CAPABILITIES.md) wins.

Release baseline: STR8-N 1.34 and HIMON/ASM-F2 `00.0915(2324)`. The firmware
stamp differs from the reset-qualified board's `2233`/`2243` stamps, with
timestamp-only payload equivalence recorded in `QUALIFICATION.json`.
The release did not reinstall or newly qualify Bank 0-2 application carriers.

The HIMON ZIP supplies `APPLICATIONS/APMAN/README.md`, the optional dense
Bank-2 sector-8 bootstrap, and the historical board record. Consult that
README before provisioning APMAN; do not apply the old record's assumed
bank inventory or erase sequence to another board. Existing carrier users
can check discovery with `APS B2 APMAN` before attempting a new installation.

## Roles

| Part | Role |
| --- | --- |
| ASM-F2 | Produces AP-v2 objects and packages. |
| AP | The packaged metadata, BODY, entry, relocations, exports, and imports. |
| APC | One complete AP envelope stored as data in RAM or flash. |
| OIL | The path that validates, loads, relocates, links, and executes an AP BODY. |
| HIMON | Hosts the resident AP service and dispatches `AP`, `APS`, and ASM operations. |
| APMAN | The banked carrier manager used for Bank 0-2 discovery, installation, status, and loading. |
| STR8-N | Supplies checked bank selection and flash services; it does not own AP linking. |
| AP Store | The accepted append-only multi-object media format; it is separate from the ordinary one-carrier-per-sector path. |

ASM creates AP objects. OIL is not a separate stored program or command: it is
the runtime boundary spanning HIMON's AP service, APMAN, STR8-N bank services,
RJOIN imports, and the loaded BODY.

## Current Supported Carrier Path

The ordinary persistent workflow is:

```text
ASM source
  -> END
  -> SEAL
  -> PACKAGE name address
  -> INSTALL package Bn
  -> reset or HCOLD
  -> APS / APS Bn name
  -> AP Bn name [destination]
```

`INSTALL package Bn` accepts Banks 0-2. The explicit bank token is the
destructive confirmation. APMAN chooses the first completely erased,
unreserved 4K sector, writes one complete AP-v2 envelope, verifies it, and
restores Bank 3.

After installation:

```text
APS                         list Bank 0-2 media
APS B2 APMAN                describe a named carrier
AP D B2 name                validate and inspect by exported name
AP D B2 8000                validate and inspect by sector address
AP B2 name                  load, link, and run it
AP B2 name 4000             request a destination
AP L B2 name 4000           load and link without running
```

The current host-qualified APMAN candidate publishes each banked-media stage
on the eight PIA Port-A LEDs. The displayed byte is `SECTOR|BANK`: the upper
nibble identifies sector `$8-$F`, while the low bits identify Bank 0-2. This
applies to `AP`, `AP L`, `AP D`, and `APS`; it adds no delay. HIMON's next
console output or input wait replaces it with the normal activity/wait status,
and a launched application remains free to take ownership of Port A. Hardware
load/inspect/run paths and physical-reset recovery have passed on COM4;
operator-observed LED values are still pending. The manager's
[size qualification](../LOGS/APMAN_SIZE_2026-09-16.md) identifies the workbench
image after the initial [Bank-2 setup](../LOGS/HIMON_AP_BANK2_2026-09-16.md).
Shared INSTALL facts and carrier formatting reduce APMAN's BODY to `$0BD7`
(3,031 bytes), leaving 41 bytes below `$7C00`; its envelope is `$0C05`.
Commands, resident images, RAM allocation, and the one-sector carrier model
are unchanged. This workbench qualification does not update published ZIPs.

The subsequent [resident range-check reduction](HIMON_AP_RANGE_SIZE_REDUCTION_2026-09-16.md)
saves 20 HIMON bytes, leaving 440 bytes below `$F000`. It preserves the same
AP address policies, RAM allocation, ASM image and APMAN carrier; the manager's
41-byte overlay reserve is unchanged.

The [parser initialization loop](HIMON_AP_INIT_SIZE_REDUCTION_2026-09-16.md)
recovers another ten resident bytes, leaving 450 bytes below `$F000`. It clears
the same cells, preserves successful X/Y results and uses the existing
volatile-X contract on errors. The additional clearing cost is 4.625
microseconds at the board's 8 MHz clock.

The exact syntax and limits are maintained in the
[ASM User Guide](../ASM/ASM_USER_GUIDE.md). Safe address choices are in
[Address Practices](../ASM/ADDRESS_PRACTICES.md).

## Stored Envelope And Loaded BODY

An APC remains data until OIL validates and loads it. The stored address and
the BODY load address are different concepts:

Its five AP-v2 sections use canonical **SREIB** order: Seal, Relocations,
Exports, Imports, Body. SREIB is pronounced approximately “shrybe,” echoing
German *schreib* (“write”), while remaining a mnemonic for the actual tag
order rather than another on-media format.

```text
bank sector
  AP-v2 envelope
    identity and section lengths
    ENTRY / EXPORT / IMPORT / RELOCATION rows
    BODY bytes and FNV
      |
      v
RAM destination
  copied BODY
  relocation fixups
  resident-import fixups
  executable entry
```

The frozen binary contract is in [ASM ABI v1](../ASM/ASM_ABI_V1.md). The exact
APMAN carrier, envelope, staging, and overlay maps are in the
[APMAN/APC Dissection](../ASM/APMAN_APC_DISSECTION.md).

## Current Ownership And Memory Limits

- HIMON owns AP parsing, BODY loading, relocation, resident-import linking,
  entry derivation, and the public AP service.
- The current APMAN candidate occupies `$7000-$7BD6` while delegated carrier
  operations are active, leaving 41 bytes below `$7C00`.
- Banked media is staged at `$0A00-$19FF`.
- The HIMON command buffer is at `$7A00`; manager operations shadow it before
  APMAN overwrites its own execution range.
- Application BODY destinations must not overlap live HIMON, I/O, protected
  request cards, staging RAM, or the active APMAN overlay.
- STR8-N restores Bank 3 around bank access and owns the checked flash mutation
  mechanisms used by the manager.

The [Memory Map](../MEMORY/MEMORY_MAP.md) is authoritative for addresses.

The [2026-09-16 contract correction](HIMON_AP_CONTRACT_CHANGE_2026-09-16.md)
adds explicit takeover loading through `$6FFF`; ordinary ASM LOAD still ends
at `$4FFF`. HIMON AP and APMAN children use takeover and invalidate the old
ASM session. `ASM S` then refuses resume; `ASM` begins fresh. Manager INSTALL
rejects unstable sources before staging, including the `$0A00` tray. Missing
manager returns `$DA`; duplicate names retain `$D2`. The resident changes are
installed on COM4. The subsequent [Bank-2 provisioning and board cycle](../LOGS/HIMON_AP_BANK2_2026-09-16.md)
installed APMAN at B2:$8000 and an onboard-built APTEST at B2:$9000. Persistent
discovery, inspection, load/run through `$6FFF`, real INSTALL, fresh-session
return, software warm/cold recovery, and physical RESET passed with exact flash readback.
Bank 2 is AP storage (`A2 APC02`); it has no bootable guest RESET vector.

## AP Carrier Versus AP Store

The two accepted storage shapes solve different problems:

| AP carrier | AP Store V1 |
| --- | --- |
| One complete AP-v2 envelope per 4K sector | Append-only records across selected sectors |
| Named and installed through current APMAN commands | Uses transient V1 tools and explicit managed-media operations |
| Simple discovery and replacement model | Generations, chaining, tombstones, and exhaustion accounting |
| Current operator path | Accepted media/tool proof, pending consolidated operator manager |

Use the carrier path for ordinary named installation and execution. AP Store
is retained for applications needing multi-object history or multi-sector
records. Its format is accepted, but it is not an alias for `INSTALL` and is
not yet the primary operator workflow. The detailed comparison remains in
[Banked AP Carrier Versus AP Store](../ASM/BANKED_AP_CARRIER_VS_AP_STORE.md).

## Inspection And Recovery

`BANKDUMP` is the accepted read-only physical-sector inspector. It can decode
an AP-v2 header, dump bounded pages, report CRC16, and show the physical 4x8
bank map while restoring Bank 3 before output or return. See the
[BANKDUMP card](../ASM/BANK_DUMP_AP_CARD.md).

Direct visible-envelope loading remains available as a recovery path. Bank-3
resident payload installation remains a STR8-N `I` operation; do not use AP
carrier installation for Bank 3.

## Evidence And History

- Current command and ABI authority: [Capabilities](../CAPABILITIES.md)
- Current operator sequence: [Operator's Guide](../OPERATORS_GUIDE.md)
- Current ASM production workflow: [ASM User Guide](../ASM/ASM_USER_GUIDE.md)
- Original carrier manager proof: [APMAN Board Test](../ASM/APMAN_V1_BOARD_TEST.md)
- Current read-only carrier inspection proof: [APMAN Inspection](../LOGS/APMAN_INSPECT_2026-09-10.md)
- Current physical inspector proof: [BANKDUMP Card](../ASM/BANK_DUMP_AP_CARD.md)
- Board transcripts: [Hardware Test Log](../LOGS/HARDWARE_TEST_LOG.md)
- Historical `.710` release rail: [OIL .710 Test Plan](../PLANNING/OIL_710_TEST_PLAN.md)
- Documentation classification: [History And Evidence](../HISTORY.md)

The `.710` plan and AP Store slice cards preserve the commands and assumptions
of their tested images. They are evidence, not current operating instructions.
