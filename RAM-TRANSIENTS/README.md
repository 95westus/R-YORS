# RAM transients

Run `make -C SRC ram-transients HIMON_VISIBLE_STAMP='0915(2324)'` to rebuild
and export the current RAM tools from R-YORS and sibling STR8-N. This folder
contains generated candidate artifacts; it does not change the installed board.

- `A/`: self-contained ASM-F2 `ORG`/`DB` byte carriers generated from each S19.
  Edit the original sources, then rebuild. These preserve linked bytes rather
  than providing relocatable source.
- `S19/`: original checked S-records, including their load addresses and S9.
- `BIN/`: raw bytes from the lowest through highest load address, with `$FF`
  in holes. BIN has no address or entry header; consult `manifest.json`.
- `manifest.json`: source provenance, load range, entry, requirements and hashes
  for every exported image.

The collection includes Bank Maintenance, its combined top-update menu,
standalone top update, directory refresh, console/interrupt/LED tests,
bank readers, applications, AP Store tools and built RAM proof images.
`fnv-ram-hrec-2000` is a private metadata inspector with an initialized request
card, not a standalone monitor command. Its
[contract](../DOC/GUIDES/AP/RAM_HREC_PROOF_2026-09-16.md) limits inspection to
existing `$3000-$3FFF` RAM and does not authorize provider execution.
`fnv-ram-ap-2000` is the subsequent
[RAM AP/combined uniqueness inspector](../DOC/GUIDES/AP/RAM_AP_UNIQUENESS_2026-09-16.md).
It requires matching HIMON/AM03 image pins from the manifest and a freshly
loaded manager. Its result is an envelope location and entry offset, with no
provider load/link/entry. The HREC and AP proofs are alternative `$2000` images.
`fnv-ram-ap-handoff-5000` is the retained matching
[safe handoff](../DOC/GUIDES/AP/RAM_AP_HANDOFF_2026-09-16.md). It survives at
`$5000`, repeats the inspector search, loads/links the selected BODY over the
inspector at `$2000`, retires all discovery state, and enters the child. It is
also private and image-pinned; it is not a standalone monitor command. AM03
now integrates this transition into resident-miss dispatch.
The maintained WDCMONv2 archive/migration RAM tools retain their original use
requirements. Lab-only factory reconstruction images, private `$0200` workers,
and flash-resident images are excluded. The manifest records excluded R-YORS
images; historical files elsewhere are not promoted into this collection.

An S9 address is not a promise that an image can be launched on its own. AP
envelopes are data packages, and APMAN requires its monitor bootstrap. Follow
each original tool procedure. Byte carriers that overlap active monitor/ASM
buffers must not be assembled in place; their `.a` files still describe the
exact image for inspection or a suitable separate assembly environment.
In particular, the new top updater uses **B2:F**
for its verified backup and installs **no flash WORK sector**. This ordinary
updater is now installed and readback-verified on COM4; physical reset and final four-bank isolation pass. See the [board record](../DOC/GUIDES/LOGS/SECTOR_ROLES_BOARD_2026-09-16.md).
The scoped HIMON/AM02 pair is now installed with policy `$A6` and bounded
[board smoke](../DOC/GUIDES/LOGS/SCOPED_SMOKE_BOARD_2026-09-16.md) passing.
[Banked AP board qualification](../DOC/GUIDES/LOGS/SCOPED_QUALIFICATION_2026-09-16.md) now passes;
RAM-provider/HREC lookup remains open. Canonical top-updater
artifacts still install default policy `$FF`; the task-specific `$A6` updater
and recovery streams are retained separately with their recovery card.
SPI SRAM is not yet allocated by these files.

The exporter does not delete unrelated files. Files listed in the current
manifest are the current exported set; do not treat unlisted leftovers as
current builds. Generated payloads are local build products, not release ZIPs.

`bank-audit-2000` and `bank-dump-2000` raw images are host comparison fixtures
with historical HIMON call addresses. **Use their `A/*-imports.a` companions**
and the documented AP build/load/link workflow on the current monitor. The
manifest labels these fixtures; merely collecting them does not make their
raw S19/BIN executable against a different resident image.
