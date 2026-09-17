"""Compare the final four-bank archive with the exact allowed flash changes."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BUILD = ROOT / 'SRC/BUILD'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def next_journal(top, bank):
    start = 0xFBC + 16 * bank
    for pair in range(16):
        at, shift = start + pair // 4, (pair % 4) * 2
        if (top[at] >> shift) & 3 == 3:
            top[at] &= ~(3 << shift)
            return
    raise AssertionError(f'no journal pair for bank {bank}')


baseline = (ROOT / 'DOC/GUIDES/LOGS/STR8N_V135_BOARD_2026-09-16/'
            'enabled/flash-128k.bin').read_bytes()
actual = (HERE / 'final/flash-128k.bin').read_bytes()
expected = bytearray(baseline)
expected[0x10000:0x11000] = (BUILD / 'bin/apman-v1-bank2-8000.bin').read_bytes()
himon = (BUILD / 'bin/himon-rom-c000.bin').read_bytes()[0x4000:0x7000]
expected[0x1C000:0x1F000] = himon
top = bytearray(expected[0x1F000:0x20000])
next_journal(top, 2)
next_journal(top, 3)
next_journal(top, 3)
expected[0x1F000:0x20000] = top

assert actual == expected
changed = []
for bank in range(4):
    for sector in range(8, 16):
        at = bank * 0x8000 + (sector - 8) * 0x1000
        if actual[at:at + 0x1000] != baseline[at:at + 0x1000]:
            changed.append(f'B{bank}:{sector:X}')
assert changed == ['B2:8', 'B3:D', 'B3:E', 'B3:F'], changed

result = {
    'result': 'PASS',
    'baseline_sha256': sha(baseline),
    'actual_sha256': sha(actual),
    'expected_sha256': sha(expected),
    'changed_sectors': changed,
    'journal_transactions': ['B2', 'B3', 'B3'],
}
(HERE / 'final-verification.json').write_text(
    json.dumps(result, indent=2) + '\n', encoding='ascii')
print('PASS exact final flash isolation', result['actual_sha256'])
