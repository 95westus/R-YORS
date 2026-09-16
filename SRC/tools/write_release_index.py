"""Index only current release products; retain older loose artifacts as history."""
import json
from pathlib import Path
from verify_component_release import sha

root = Path(__file__).resolve().parents[2] / 'RELEASE'
qualification = json.loads((root / 'QUALIFICATION.json').read_text())
components = json.loads((root / 'component-release-manifest.json').read_text())
products = [item['file'] for item in components] + ['str8n-v1.34-release.zip',
            'ryors-v1.2-himon-asm-bank3-8-e.s19', 'QUALIFICATION.json']
for item in components:
    assert sha((root / item['file']).read_bytes()) == item['sha256']
index = {'schema': 1, 'created': qualification['created'],
         'firmware_stamp': qualification['release_stamp'],
         'products': {name: {'bytes': (root / name).stat().st_size, 'sha256': sha((root / name).read_bytes())} for name in products}}
(root / 'release-index.json').write_text(json.dumps(index, indent=2) + '\n', encoding='utf-8')
stamp = qualification['release_stamp']
readme = f'''# Current release packages

HIMON and ASM-F2 build identity: **00.{stamp}**. STR8-N: **v1.34**.

| Package | Contents |
| --- | --- |
| [STR8-N v1.34](str8n-v1.34-release.zip) | Canonical 4 KiB BIN, S19/update tools, Bank Maintenance `.a`, WDC-to-STR8 migration kit, guides, MIT license, manifests and verification |
| [HIMON](%HIMON%) | C-E S19 and BIN, combined 8-E S19, monitor docs, maintenance/LED/RTC apps, Life and MicroChess with their notices and available `.a` source |
| [ASM-F2](%ASM%) | 8-B S19 and BIN, combined 8-E S19, current reporter `.a`, assembler examples, terminal/bank tools, and separate validation fixtures |

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
only in {qualification['changed_byte_count']} bytes within its three timestamp fields.
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
'''
readme = readme.replace('%HIMON%', next(p for p in products if p.startswith('himon-')))
readme = readme.replace('%ASM%', next(p for p in products if p.startswith('asm-f2-')))
(root / 'README.md').write_text(readme, encoding='utf-8')
names = sorted(products + ['release-index.json', 'component-release-manifest.json', 'README.md'])
(root / 'SHA256SUMS.txt').write_text(''.join(f'{sha((root / name).read_bytes())}  {name}\n' for name in names), encoding='ascii')
print('Release index written for three ZIPs and qualified combined 8-E image')
