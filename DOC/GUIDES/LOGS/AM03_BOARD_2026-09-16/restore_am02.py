"""Restore the accepted AM02 B2:8 carrier after the failed AM03 board gate."""
from pathlib import Path
import hashlib
import json

import bank_archive as arc
import console

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
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


def finish_pending_journal(top, bank):
    start = 0xFBC + 16 * bank
    for pair in range(16):
        at, shift = start + pair // 4, (pair % 4) * 2
        if (top[at] >> shift) & 3 == 2:
            top[at] &= ~(3 << shift)
            return
    raise AssertionError(f'no pending journal pair for bank {bank}')


baseline = (ROOT / 'DOC/GUIDES/LOGS/STR8N_V135_BOARD_2026-09-16/'
            'enabled/flash-128k.bin').read_bytes()
final = (HERE / 'final/flash-128k.bin').read_bytes()
bank2 = baseline[0x10000:0x18000]
am02 = bank2[:0x1000]
image = HERE / 'restore-am02-b2-8-f.s19'
arc.write_s19(image, 0x8000, bank2,
              int.from_bytes(bank2[0x7FFC:0x7FFE], 'little'))
with console.Board() as board:
    current_top = dump(board, 0xF000, 0xFFFF)
    assert [(i, a, b) for i, (a, b) in enumerate(zip(
        final[0x1F000:0x20000], current_top)) if a != b] == [
            (0xFDE, 0xFC, 0xF8)]
    expected_top = bytearray(current_top)
    finish_pending_journal(expected_top, 2)
    selector(board)
    board.command('I', until=r'B0-3: ')
    board.command('2', until=r'RANGE: ')
    board.command('8-F', until=r'I B2 8-F WRITE\? Y: ')
    board.command('Y', until=r'S19[\r\n]+')
    reply = board.transfer(image, seconds=60, until=r'(?:COMMIT\? Y: |FAIL)')
    assert b'COMMIT? Y:' in reply and b'FAIL' not in reply
    reply = board.command('Y', until=r'STR8-N>', seconds=60)
    assert b'OK' in reply and b'FAIL' not in reply
    reply = board.command('C', seconds=20)
    assert b'HIMON V 00.0916(1949)' in reply
    assert dump(board, 0xF000, 0xFFFF) == expected_top

arc.archive(HERE / 'restored-b2', [2])
assert (HERE / 'restored-b2/bank2.bin').read_bytes() == bank2

result = {
    'result': 'PASS',
    'restored': 'B2:8-F accepted baseline with AM02 at B2:8',
    'am02_sector_sha256': sha(am02),
    'bank2_sha256': sha(bank2),
    'top_after_sha256': sha(expected_top),
}
(HERE / 'restore-am02-result.json').write_text(
    json.dumps(result, indent=2) + '\n', encoding='ascii')
print('PASS restored accepted AM02 B2:8 with exact readback')
