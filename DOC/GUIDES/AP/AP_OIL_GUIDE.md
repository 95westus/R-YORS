# AP And OIL Guide

This is the current guide to Application Packages (AP), AP Capsules (APC),
the Overlay Integration Layer (OIL), APMAN, and AP Store. For the exact live
command surface, the [capability matrix](../CAPABILITIES.md) wins.

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
- APMAN occupies `$7000-$7BF4` while delegated carrier operations are active.
- Banked media is staged at `$0A00-$19FF`.
- The HIMON command buffer is at `$7A00`; manager operations shadow it before
  APMAN overwrites its own execution range.
- Application BODY destinations must not overlap live HIMON, I/O, protected
  request cards, staging RAM, or the active APMAN overlay.
- STR8-N restores Bank 3 around bank access and owns the checked flash mutation
  mechanisms used by the manager.

The [Memory Map](../MEMORY/MEMORY_MAP.md) is authoritative for addresses.

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
- Current carrier manager proof: [APMAN Board Test](../ASM/APMAN_V1_BOARD_TEST.md)
- Current read-only carrier inspection proof: [APMAN Inspection](../LOGS/APMAN_INSPECT_2026-09-10.md)
- Current physical inspector proof: [BANKDUMP Card](../ASM/BANK_DUMP_AP_CARD.md)
- Board transcripts: [Hardware Test Log](../LOGS/HARDWARE_TEST_LOG.md)
- Historical `.710` release rail: [OIL .710 Test Plan](../PLANNING/OIL_710_TEST_PLAN.md)
- Documentation classification: [History And Evidence](../HISTORY.md)

The `.710` plan and AP Store slice cards preserve the commands and assumptions
of their tested images. They are evidence, not current operating instructions.
