"""Restore the HIMON-compatible AM03 carrier after recovery diagnosis."""
from pathlib import Path
import hashlib
import json

import bank_archive as arc
import console

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BUILD = ROOT / 'SRC/BUILD'
console.LOG = HERE / 'serial-com4.jsonl'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def dump(board, start, end):
    return arc.dump_bytes(
        board.command(f'D {start:04X} {end:04X}', seconds=40), start, end)


def selector(board):
    board.command('STR8', until=r'K=03 \? ')
    board.send(b'Y')
    board.read(15, r'0-2 C W S: ')
    board.send(b'S')
    board.read(10, r'STR8-N>')


def complete_next_journal(top, bank):
    start = 0xFBC + 16 * bank
    for pair in range(16):
        at, shift = start + pair // 4, (pair % 4) * 2
        if (top[at] >> shift) & 3 == 3:
            top[at] &= ~(3 << shift)
            return
    raise AssertionError(f'no free journal pair for bank {bank}')


manager = (BUILD / 'bin/apman-v1-bank2-8000.bin').read_bytes()
image = BUILD / 's19/apman-v1-bank2-8000.s19'
with console.Board() as board:
    current_top = dump(board, 0xF000, 0xFFFF)
    expected_top = bytearray(current_top)
    complete_next_journal(expected_top, 2)
    selector(board)
    board.command('I', until=r'B0-3: ')
    board.command('2', until=r'RANGE: ')
    board.command('8', until=r'I B2 8-8 WRITE\? Y: ')
    board.command('Y', until=r'S19[\r\n]+')
    reply = board.transfer(image, seconds=60, until=r'(?:COMMIT\? Y: |FAIL)')
    assert b'COMMIT? Y:' in reply and b'FAIL' not in reply
    reply = board.command('Y', until=r'STR8-N>', seconds=60)
    assert b'OK' in reply and b'FAIL' not in reply
    reply = board.command('C', seconds=20)
    assert b'HIMON V 00.0916(1949)' in reply
    assert dump(board, 0xF000, 0xFFFF) == expected_top

arc.archive(HERE / 'restored-am03-b2', [2])
actual = (HERE / 'restored-am03-b2/bank2.bin').read_bytes()
baseline = (ROOT / 'DOC/GUIDES/LOGS/STR8N_V135_BOARD_2026-09-16/'
            'enabled/flash-128k.bin').read_bytes()[0x10000:0x18000]
expected = manager + baseline[0x1000:]
assert actual == expected

result = {
    'result': 'PASS',
    'restored': 'B2:8 AM03 compatible with timestamped HIMON',
    'manager_sha256': sha(manager),
    'bank2_sha256': sha(actual),
    'top_after_sha256': sha(expected_top),
}
(HERE / 'reinstall-am03-result.json').write_text(
    json.dumps(result, indent=2) + '\n', encoding='ascii')
print('PASS reinstalled paired AM03 with exact B2 readback')
