"""Replace the stale B3:C-E HIMON payload and verify the exact live result."""
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
    reply = board.command(f'D {start:04X} {end:04X}', seconds=40)
    return arc.dump_bytes(reply, start, end)


def selector(board):
    board.command('STR8', until=r'K=03 \? ')
    board.send(b'Y')
    board.read(15, r'0-2 C W S: ')
    board.send(b'S')
    board.read(10, r'STR8-N>')


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
manager = (BUILD / 'bin/apman-v1-bank2-8000.bin').read_bytes()
himon_rom = (BUILD / 'bin/himon-rom-c000.bin').read_bytes()
himon = himon_rom[0x4000:0x7000]

expected_before_top = bytearray(baseline[0x1F000:0x20000])
next_journal(expected_before_top, 2)
next_journal(expected_before_top, 3)
expected_after_top = bytearray(expected_before_top)
next_journal(expected_after_top, 3)

with console.Board() as board:
    assert dump(board, 0xF000, 0xFFFF) == expected_before_top
    selector(board)
    board.command('I', until=r'B0-3: ')
    board.command('3', until=r'RANGE: ')
    board.command('C-E', until=r'I B3 .*WRITE\? Y: ')
    board.command('Y', until=r'S19[\r\n]+')
    reply = board.transfer(BUILD / 's19/himon-apv2-bank3-c-e.s19',
                           seconds=60, until=r'(?:COMMIT\? Y: |FAIL)')
    assert b'COMMIT? Y:' in reply and b'FAIL' not in reply
    reply = board.command('Y', until=r'STR8-N>', seconds=60)
    assert b'OK' in reply and b'FAIL' not in reply
    reply = board.command('C', seconds=20)
    assert b'HIMON V 00.0916(1949)' in reply
    assert dump(board, 0xC000, 0xEFFF) == himon
    assert dump(board, 0xF000, 0xFFFF) == expected_after_top

result = {
    'result': 'PASS',
    'himon_payload_sha256': sha(himon),
    'himon_rom_sha256': sha(himon_rom),
    'himon_board_s19_sha256': sha(
        (BUILD / 's19/himon-apv2-bank3-c-e.s19').read_bytes()),
    'top_after_sha256': sha(expected_after_top),
}
(HERE / 'finish-himon-result.json').write_text(
    json.dumps(result, indent=2) + '\n', encoding='ascii')
print('PASS fresh HIMON B3:C-E install and exact readback')
