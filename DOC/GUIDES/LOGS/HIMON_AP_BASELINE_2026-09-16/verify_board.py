"""Reconcile the read-only COM4 dump with host artifacts and prior evidence."""
import hashlib
import importlib.util
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('ledger', ROOT / 'SRC/tools/report_himon_ap_baseline.py')
ledger = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ledger)
text = (HERE / 'bank3-dump.txt').read_text()
memory = {}
for address, left, right in re.findall(r'(?:^|[\r\n])([0-9A-F]{4}): ((?:[0-9A-F]{2} ){8})\| ((?:[0-9A-F]{2} ){8})\|', text):
    for offset, value in enumerate(bytes.fromhex(left+right)):
        site = int(address, 16) + offset
        assert site not in memory
        memory[site] = value
assert set(memory) == set(range(0x8000, 0x10000))
bank = bytes(memory[a] for a in sorted(memory))
(HERE / 'bank3.bin').write_bytes(bank)
prior = ROOT / 'LOCAL/bso2-b2/board/after-readback/bank3.bin'
result = {'bank3_sha256': ledger.sha(bank), 'bytes': len(bank),
          'matches_bso2_post_install_bank3': bank == prior.read_bytes(), 'components': []}
for name, start, limit, labels in [
    ('himon-rom-c000', 0xC000, 0xF000, ['MSG_HIMON_VERSION_TEXT', 'MSG_HIMON_VERSION_HASH_TEXT']),
    ('asm-v1-flash-8000', 0x8000, 0xC000, ['MSG_TITLE'])]:
    path = ROOT / 'SRC/BUILD/s19' / (name + '.s19')
    sym, emitted = ledger.symbols(path.with_suffix('.map')), ledger.srecord(path)
    expected = bytes(emitted.get(a, 255) for a in range(start, limit))
    actual = bank[start-0x8000:limit-0x8000]
    allowed = set()
    strings = []
    for label in labels:
        a = sym[label]
        end = a
        while not emitted[end] & 128:
            end += 1
        end += 1
        allowed.update(range(a,end))
        strings.append({'symbol': label, 'address': f'{a:04X}',
            'host': bytes(emitted[x] & 127 for x in range(a,end)).decode('ascii'),
            'board': bytes(memory[x] & 127 for x in range(a,end)).decode('ascii')})
    differences = [a for a in range(start,limit) if memory[a] != emitted.get(a,255)]
    assert set(differences) <= allowed, (name, differences)
    result['components'].append({'name': name, 'board_sha256': ledger.sha(actual),
        'host_dense_sha256': ledger.sha(expected), 'difference_addresses': [f'{a:04X}' for a in differences],
        'timestamp_only': True, 'strings': strings})
result['directory_hex'] = bank[0x7FB0:0x7FF0].hex().upper()
result['configuration_hex'] = bank[0x7FF0:0x7FFA].hex().upper()
(HERE / 'board-verification.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
