"""Install the host-qualified HIMON/AM03 pair after an exact live preflight."""
from pathlib import Path
import hashlib, json
import console
import bank_archive as arc

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BUILD = ROOT / 'SRC/BUILD'
console.LOG = HERE / 'serial-com4.jsonl'

def sha(data): return hashlib.sha256(data).hexdigest()
def save(name, value): (HERE/name).write_text(json.dumps(value, indent=2)+'\n')
def dump(board, start, end):
    return arc.dump_bytes(board.command(f'D {start:04X} {end:04X}', seconds=40), start, end)
def selector(board):
    board.command('STR8', until=r'K=03 \? ')
    board.send(b'Y'); board.read(15, r'0-2 C W S: ')
    board.send(b'S'); board.read(10, r'STR8-N>')
def next_journal(top, bank):
    start = 0xFBC + 16*bank
    for pair in range(16):
        at, shift = start+pair//4, (pair%4)*2
        if (top[at] >> shift) & 3 == 3:
            top[at] &= ~(3 << shift)
            return
    raise AssertionError(f'no journal pair for bank {bank}')

before_path = ROOT / 'DOC/GUIDES/LOGS/STR8N_V135_BOARD_2026-09-16/enabled/flash-128k.bin'
before = before_path.read_bytes()
assert sha(before) == 'd1d4b9db35106ce84ac9f55983a745bd852a6acbc4594f4d3aec74fbfacf45af'
manager = (BUILD/'bin/apman-v1-bank2-8000.bin').read_bytes()
himon_rom = (BUILD/'bin/himon-rom-c000.bin').read_bytes()
himon = himon_rom[0x4000:0x7000]
assert len(manager) == 4096 and sha(manager) == '34fdeee4902c7d88222d2a6f84010d26a6257550eed1ce7aebea77c970f4b0f0'
assert len(himon) == 12288

expected = bytearray(before)
expected[0x10000:0x11000] = manager
expected[0x1C000:0x1F000] = himon
top = bytearray(expected[0x1F000:0x20000])
next_journal(top, 2); next_journal(top, 3)
expected[0x1F000:0x20000] = top
arc.write_s19(HERE/'rollback-b2-8-f.s19', 0x8000, before[0x10000:0x18000], int.from_bytes(before[0x17FFC:0x17FFE], 'little'))
arc.write_s19(HERE/'rollback-b3-8-e.s19', 0x8000, before[0x18000:0x1F000], 0xC000)
arc.write_s19(HERE/'expected-bank2.s19', 0x8000, expected[0x10000:0x18000], int.from_bytes(expected[0x17FFC:0x17FFE], 'little'))
arc.write_s19(HERE/'expected-bank3.s19', 0x8000, expected[0x18000:0x20000], int.from_bytes(expected[0x1FFFC:0x1FFFE], 'little'))
save('candidate.json', {'result':'PREPARED', 'baseline_sha256':sha(before),
    'expected_sha256':sha(expected), 'manager_sha256':sha(manager),
    'himon_sha256':sha(BUILD.joinpath('s19/himon-rom-c000.s19').read_bytes()),
    'manager_s19_sha256':sha(BUILD.joinpath('s19/apman-v1-bank2-8000.s19').read_bytes())})

with console.Board() as board:
    assert dump(board, 0xF000, 0xFFFF) == before[0x1F000:]
    selector(board)
    for bank, span, image in ((2, '8', BUILD/'s19/apman-v1-bank2-8000.s19'),
                              (3, 'C-E', BUILD/'s19/himon-apv2-bank3-c-e.s19')):
        board.command('I', until=r'B0-3: ')
        board.command(str(bank), until=r'RANGE: ')
        board.command(span, until=rf'I B{bank} .*WRITE\? Y: ')
        board.command('Y', until=r'S19[\r\n]+')
        reply = board.transfer(image, seconds=60, until=r'(?:COMMIT\? Y: |FAIL)')
        assert b'COMMIT? Y:' in reply and b'FAIL' not in reply
        reply = board.command('Y', until=r'STR8-N>', seconds=60)
        assert b'OK' in reply and b'FAIL' not in reply
    reply = board.command('C', seconds=20)
    assert b'HIMON V 00.0916(1949)' in reply
    assert dump(board, 0xC000, 0xEFFF) == himon
    assert dump(board, 0xF000, 0xFFFF) == top
save('install-result.json', {'result':'PASS', 'expected_flash_sha256':sha(expected)})
print('PASS paired HIMON/AM03 install; expected flash', sha(expected))
