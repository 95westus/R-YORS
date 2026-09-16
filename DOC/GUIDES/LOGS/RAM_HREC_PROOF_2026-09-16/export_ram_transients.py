"""Export current built RAM images as matching ASM-F2, S19 and raw BIN files."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read_s19(path):
    memory, entry = {}, None
    for line in path.read_text().splitlines():
        if not line.strip():
            continue
        assert line.startswith('S'), (path, line)
        kind = int(line[1])
        raw = bytes.fromhex(line[2:])
        assert raw[0] == len(raw)-1 and sum(raw) & 255 == 255, (path, 'checksum/count')
        width = {0: 2, 1: 2, 2: 3, 3: 4, 5: 2, 6: 3, 7: 4, 8: 3, 9: 2}[kind]
        address = int.from_bytes(raw[1:1+width], 'big')
        if kind in (7, 8, 9):
            assert entry is None, (path, 'duplicate entry')
            entry = address
        if kind in (1, 2, 3):
            for offset, value in enumerate(raw[1+width:-1]):
                assert address+offset not in memory, (path, 'overlap')
                memory[address+offset] = value
    assert memory and entry is not None, (path, 'missing data/entry')
    return memory, entry


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--str8-home', type=Path, default=ROOT.parent/'STR8-N')
    parser.add_argument('--output', type=Path, default=ROOT/'RAM-TRANSIENTS')
    args = parser.parse_args()
    # Canonical maintained STR8 tools; lab-only factory reconstruction and
    # private $0200 worker images are not operator transients.
    str8_names = ('bank-maint', 'bank-maint-menu', 'str8-in65-bank-maint',
                  'console-abi-test', 'led-worker-test', 'irq-test', 'top-update',
                  'directory-refresh', 'str8-in65-top-update',
                  'wdcmonv2-archive', 'wdcmonv2-install')
    sources = [(ROOT, p) for p in sorted((ROOT/'SRC/BUILD/s19').glob('*.s19'))]
    for name in str8_names:
        p = args.str8_home/f'BUILD/v1.34/s19/str8n-v1.34-{name}-2000.s19'
        assert p.is_file(), p
        sources.append((args.str8_home, p))
    out = args.output
    for folder in ('A', 'S19', 'BIN'):
        (out/folder).mkdir(parents=True, exist_ok=True)
    rows, excluded, seen = [], [], set()
    for home, source in sources:
        memory, entry = read_s19(source)
        addresses = sorted(memory)
        low, high = addresses[0], addresses[-1]
        if low < 0x2000 or high >= 0x7D00:
            excluded.append(dict(file=str(source.relative_to(home)), reason='outside RAM transient window $2000-$7CFF'))
            continue
        assert source.stem not in seen, ('duplicate output', source.stem)
        seen.add(source.stem)
        binary = bytes(memory.get(a, 255) for a in range(low, high+1))
        kind = 'AP envelope' if binary[:3] == b'AP\x02' else 'RAM image'
        lines = [f'; GENERATED FROM {home.name}/{source.relative_to(home).as_posix()}',
                 '; EXACT LINKED BYTE CARRIER; EDIT THE ORIGINAL SOURCE.',
                 f'; LOAD BASE ${low:04X}; S19 ENTRY ${entry:04X}; SEE MANIFEST/README.',
                 '; LOAD/ENTRY REQUIREMENTS AND HASHES ARE IN manifest.json.']
        if source.stem in ('bank-audit-2000', 'bank-dump-2000'):
            lines.append('; HOST FIXTURE: USE THE -imports.a COMPANION ON CURRENT HIMON.')
        lines = [line[:63] for line in lines]
        index = 0
        while index < len(addresses):
            lines.append(f'        ORG ${addresses[index]:04X}')
            while index < len(addresses):
                start = addresses[index]
                values = []
                while index < len(addresses) and len(values) < 8 and addresses[index] == start+len(values):
                    values.append(memory[addresses[index]])
                    index += 1
                lines.append('        DB '+','.join(f'${b:02X}' for b in values))
                if index == len(addresses) or addresses[index] != start+len(values):
                    break
        lines.append('        END')
        outputs = {'A': ('a', ('\n'.join(lines)+'\n').encode('ascii')),
                   'S19': ('s19', source.read_bytes()), 'BIN': ('bin', binary)}
        hashes = {}
        for folder, (extension, data) in outputs.items():
            target = out/folder/f'{source.stem}.{extension}'
            target.write_bytes(data)
            hashes[target.relative_to(out).as_posix()] = sha(data)
        requirements = 'Use the original tool procedure and matching resident ABI; S9 is not proof that an image is standalone.'
        native_source = None
        if kind == 'AP envelope':
            requirements = 'Data package: stage and use AP LOAD/INSTALL; do not jump to the S9 address.'
        elif source.stem == 'apman-7000':
            requirements = 'Private AM02 overlay; requires HIMON bootstrap and initialized manager request state.'
        elif source.stem == 'fnv-ram-hrec-2000':
            kind = 'private RAM HREC inspection proof'
            requirements = 'Initialize private $7D40-$7D5F card: banks=0, RAM enable=1, windows=$08, format=0, wanted hash. Bank 3, decimal clear. Scans only $3000-$3FFF; returns metadata, never executes providers. Not a monitor command or public resolver ABI. See DOC/GUIDES/AP/RAM_HREC_PROOF_2026-09-16.md.'
        elif source.stem in ('bank-audit-2000', 'bank-dump-2000'):
            kind = 'host comparison fixture'
            requirements = 'Pins historical HIMON call addresses: do not launch this raw image on the current monitor. Use the companion -imports.a and normal AP load/link.'
            native_source = f'A/{source.stem}-imports.a'
            native = (ROOT/'DOC/GUIDES/ASM/SAMPLES'/f'{source.stem}.a').read_bytes()
            (out/native_source).write_bytes(native)
            hashes[native_source] = sha(native)
        rows.append(dict(name=source.stem, kind=kind, source_repository=home.name,
                         source=source.relative_to(home).as_posix(),
                         load_address=f'{low:04X}', last_address=f'{high:04X}',
                         s19_entry=f'{entry:04X}', data_bytes=len(memory), bin_bytes=len(binary),
                         hole_fill='FF', requirements=requirements, native_source=native_source, files=hashes))
    manifest = dict(status='generated candidate artifacts; hardware acceptance remains image-specific',
                    generator='SRC/tools/export_ram_transients.py',
                    flash_roles=dict(work='NONE', top_backup='B2:F', policy_default='FF'),
                    tools=rows, excluded=excluded)
    (out/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(f'Exported {len(rows)} RAM images in A/S19/BIN to {out}')


if __name__ == '__main__':
    main()
