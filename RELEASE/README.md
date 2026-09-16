# Current release packages

HIMON and ASM-F2 build identity: **00.0915(2324)**. STR8-N: **v1.34**.

| Package | Contents |
| --- | --- |
| [STR8-N v1.34](str8n-v1.34-release.zip) | Canonical 4 KiB BIN, S19/update tools, Bank Maintenance `.a`, WDC-to-STR8 migration kit, guides, MIT license, manifests and verification |
| [HIMON](himon-00.0915-2324.zip) | C-E S19 and BIN, combined 8-E S19, monitor docs, maintenance/LED/RTC apps, Life and MicroChess with their notices and available `.a` source |
| [ASM-F2](asm-f2-00.0915-2324.zip) | 8-B S19 and BIN, combined 8-E S19, current reporter `.a`, assembler examples, terminal/bank tools, and separate validation fixtures |

All three ZIPs include relevant operator, technical, installation, and
application guides. Start with `MANUALS.md` in HIMON/ASM-F2, or
`README.md` in STR8-N. Links between included manuals work
offline; source and historical references outside the ZIP require the
corresponding repository revision.

The [combined 8-E S19](ryors-v1.2-himon-asm-bank3-8-e.s19) is also available
directly. It covers exactly `$8000-$EFFF`, includes HIMON and ASM-F2, and
ends with S9 `$C000`. Install using STR8-N `I / 3 / 8-E`; send only after
`S19`, confirm COMMIT, require `OK`, then enter `C`. It excludes protected
sector F. Read the package instructions before using a component image.

The complete host regression and nine image identity comparisons passed.
The combined image differs from the physical-reset-qualified COM4 firmware
only in 9 bytes within its three timestamp fields.
The newly stamped stream has not been reflashed. Application qualification
is documented individually. See [QUALIFICATION.json](QUALIFICATION.json)
for the exact baseline, comparisons, and limits.

The migration kit's 12 firmware/source/host-loader artifacts match the
factory-board-tested kit; only documentation, metadata, and verification
were refreshed. No WDC firmware, owner bank dumps, proprietary toolchain,
BASIC, or Forth products are included in these ZIPs. Life carries its MIT
notice/attribution; MicroChess carries its full upstream terms and credits.

Extract each ZIP and run its included verifier. HIMON/ASM-F2 use
`python -B VERIFY.py`; STR8 uses its `VERIFY-PACKAGE.ps1`.
[SHA256SUMS.txt](SHA256SUMS.txt) covers the current products and index files.
[release-index.json](release-index.json) lists their lengths and hashes.

Older loose images and `ARTIFACTS/` are retained historical snapshots and
are not members of these releases. They may contain old versions or obsolete
instructions. Use the files linked above for this release.
