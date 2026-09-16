"""Verify an extracted HIMON or ASM-F2 release using only Python's standard library."""
import argparse
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

if not __debug__:
    raise RuntimeError('Package verification requires Python without -O or PYTHONOPTIMIZE')


def sha(data):
    return hashlib.sha256(data).hexdigest().upper()


def read_s19(path):
    memory = {}
    entry = None
    for line in Path(path).read_text(encoding='ascii').splitlines():
        if not line:
            continue
        assert entry is None, f'Record after termination: {path}'
        assert line[:2] in ('S0', 'S1', 'S9'), f'Unexpected record: {path}'
        row = bytes.fromhex(line[2:])
        assert row[0] + 1 == len(row) and sum(row) & 255 == 255, f'Invalid record: {path}'
        address = int.from_bytes(row[1:3], 'big')
        if line[:2] == 'S9':
            assert row[0] == 3
            entry = address
        elif line[:2] == 'S1':
            assert address + len(row[3:-1]) <= 65536
            for offset, value in enumerate(row[3:-1]):
                assert address + offset not in memory, f'Overlap: {path}'
                memory[address + offset] = value
    assert memory and entry is not None, f'Incomplete S19: {path}'
    return memory, entry


def verify(root):
    root = Path(root).resolve()
    manifest = json.loads((root / 'MANIFEST.json').read_text(encoding='utf-8'))
    actual = {p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file()}
    assert actual == set(manifest['files']) | {'MANIFEST.json', 'SHA256SUMS.txt'}, 'Unexpected or missing package file'
    for name, meta in manifest['files'].items():
        path = (root / name).resolve()
        assert path.is_relative_to(root), 'Manifest path escapes package'
        data = path.read_bytes()
        assert len(data) == meta['bytes'] and sha(data) == meta['sha256'], f'Identity mismatch: {name}'
    sums = {}
    for line in (root / 'SHA256SUMS.txt').read_text().splitlines():
        digest, name = line.split('  ', 1)
        assert name not in sums
        sums[name] = digest
    assert set(sums) == actual - {'SHA256SUMS.txt'}
    for name, digest in sums.items():
        assert sha((root / name).read_bytes()) == digest, name
    for name in actual:
        low = name.lower()
        assert not any(word in low for word in ('wdcmonv2', 'msbasic', 'fig-forth', '/local/', '__pycache__')), name
    assert 'LICENSE' in actual
    for stale in ['bank-audit-2000.s19', 'bank-dump-2000.s19']:
        assert 'APPLICATIONS/UTILITIES/' + stale not in actual, 'Legacy direct image pins obsolete HIMON addresses'
    manuals = manifest.get('manuals', [])
    for name in ['DOC/GUIDES/OPERATORS_GUIDE.md', 'DOC/GUIDES/TECHNICAL_GUIDE.md',
                 'DOC/GUIDES/INSTALLATION_FLOW.md', 'DOC/GUIDES/MEMORY/MEMORY_MAP.md',
                 'DOC/GUIDES/AP/AP_OIL_GUIDE.md']:
        assert name in manuals, f'Missing release manual: {name}'
    for name in manuals + ['MANUALS.md', 'README.md']:
        text = (root / name).read_text(encoding='utf-8')
        for chunk in text.split('```')[::2]:
            for address in re.findall(r'\[[^\]]+\]\(([^)]+)\)', chunk):
                if address.startswith(('#', 'http:', 'https:', 'mailto:', 'data:')):
                    continue
                relative = unquote(urlsplit(address.strip('<>')).path)
                target = (root / name).parent / relative
                assert target.resolve().is_relative_to(root) and target.exists(), f'Broken offline manual link: {name}: {address}'
    if any('microchess' in name.lower() for name in actual):
        notice = (root / 'APPLICATIONS/MICROCHESS/MICROCHESS-LICENSE.txt').read_text()
        assert 'Peter Jennings' in notice and 'Redistribution and use in source and binary forms' in notice
    if any('/life/' in name.lower() for name in actual):
        notice = (root / 'APPLICATIONS/LIFE/LIFE-NOTICE.txt').read_text()
        assert 'MIT License' in notice and 'Conway' in notice
    images = {}
    for item in manifest['firmware']:
        memory, entry = read_s19(root / item['s19'])
        assert set(memory) == set(range(item['start'], item['end'] + 1)), item['s19']
        assert entry == item['entry'], item['s19']
        payload = bytes(memory[a] for a in range(item['start'], item['end'] + 1))
        assert sha(payload) == item['payload_sha256']
        if 'bin' in item:
            assert (root / item['bin']).read_bytes() == payload
        images[item['role']] = memory
    qualified = json.loads((root / 'QUALIFICATION.json').read_text())
    combined = images['combined']
    assert sha(bytes(combined[a] for a in range(0x8000, 0xF000))) == qualified['combined_payload_sha256']
    for role, start, end in [('asm', 0x8000, 0xBFFF), ('himon', 0xC000, 0xEFFF)]:
        if role in images:
            assert all(images[role][a] == combined[a] for a in range(start, end + 1))
    assert all(combined[a] == 255 for a in range(0xBB83, 0xC000))
    assert all(combined[a] == 255 for a in range(0xEDEA, 0xF000))
    print(f"PASS {manifest['product']} {manifest['version']}: {len(actual)} files, checksums, licensing notices, BIN/S19 and qualified 8-E identity")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', nargs='?', default=str(Path(__file__).resolve().parent))
    verify(parser.parse_args().directory)
