"""Install and verify STR8-N v1.35 on COM4 with retained flash evidence."""
from pathlib import Path
import hashlib
import importlib.util
import json
import re
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OLD = ROOT / 'DOC/GUIDES/LOGS/SECTOR_ROLES_BOARD_2026-09-16'
STR8 = ROOT.parent / 'STR8-N'


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


console = load_module('str8n_v135_console', OLD / 'console.py')
arc = load_module('str8n_v135_archive', OLD / 'bank_archive.py')
console.LOG = HERE / 'serial-com4.jsonl'
arc.ROOT = ROOT
arc.HERE = HERE
arc.LOG = console.LOG
arc.HELPER = OLD / 'bank-stage-2000.s19'
arc.get_board_class = lambda: console.Board


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save(name, value):
    (HERE / name).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def archive(name):
    arc.archive(HERE / name, [0, 1, 2, 3])


def inspect():
    before = (HERE / 'before/flash-128k.bin').read_bytes()
    assert len(before) == 131072
    live = before[0x1F000:0x20000]
    backup = before[0x17000:0x18000]
    assert b'STR8-N 1.34' in live
    assert live[0xFF0:0xFF3] == bytes((0xFF, 0x2F, 0xA6))
    candidate = STR8 / 'BUILD/v1.35/s19/str8n-v1.35-top-update-2000.s19'
    memory, entry = arc.read_s19(candidate)
    assert entry == 0x2000 and set(memory) == set(range(0x2000, 0x5000))
    updater = bytes(memory[address] for address in range(0x2000, 0x4000))
    embedded = bytes(memory[address] for address in range(0x4000, 0x5000))
    assert b'STR8-N 1.35 TOP UPDATE' in updater
    assert sha(embedded) == '96416190b7e1a37e2c01a407ab9c8ea4ade06855bbfd0ddcc306ff68418a359a'
    assert embedded[0xFF0:0xFF3] == bytes((0xFF, 0x2F, 0xFF))
    expected = bytearray(embedded)
    expected[0xFB0:0xFF0] = live[0xFB0:0xFF0]
    (HERE / 'old-live-top.bin').write_bytes(live)
    (HERE / 'old-backup-b2f.bin').write_bytes(backup)
    (HERE / 'expected-live-top.bin').write_bytes(expected)
    (HERE / 'top-update-2000.s19').write_bytes(candidate.read_bytes())
    changes = [f'{0xF000 + i:04X}' for i, (old, new) in enumerate(zip(live, expected)) if old != new]
    save('preflight.json', {
        'result': 'PASS', 'flash_sha256': sha(before),
        'old_top_sha256': sha(live), 'old_backup_b2f_sha256': sha(backup),
        'expected_top_sha256': sha(expected), 'updater_sha256': sha(candidate.read_bytes()),
        'changed_top_addresses': changes, 'policy_transition': 'A6 -> FF; restore A6 with guarded F command after v1.35 verification',
    })
    print((HERE / 'preflight.json').read_text())


def install():
    gate = json.loads((HERE / 'preflight.json').read_text())
    assert gate['result'] == 'PASS'
    image = HERE / 'top-update-2000.s19'
    assert sha(image.read_bytes()) == gate['updater_sha256']
    with console.Board() as board:
        current = arc.dump_bytes(board.command('D F000 FFFF', seconds=30), 0xF000, 0xFFFF)
        assert current == (HERE / 'old-live-top.bin').read_bytes()
        board.command('STR8', until=r'K=03 \? ')
        board.send(b'Y')
        board.read(15, r'0-2 C W S: ')
        board.send(b'S')
        board.read(10, r'STR8-N>')
        board.command('L', until=r'S19[\r\n]+')
        response = board.transfer(image, seconds=30, until=r'TYPE BACKUP B2F> ')
        assert b'STR8-N 1.35 TOP UPDATE' in response
        assert b'BACKUP B2:F; TARGET B3:F' in response
        response = board.command('BACKUP B2F', until=r'TYPE STR8-N 1.35> ', seconds=50)
        assert b'BACKUP VERIFIED' in response
        assert b'SAFE PHY $17000-$17FFF; TARGET PHY $1F000-$1FFFF' in response
        response = board.command('STR8-N 1.35', until=r'(?:\r\n>$|WRITE FAIL: R=RETRY O=RESTORE OLD> )', seconds=50)
        (HERE / 'update-result.txt').write_bytes(response)
        assert b'WRITE FAIL' not in response
        assert b'STR8-N 1.35 VERIFIED; RESET' in response
        actual = arc.dump_bytes(board.command('D F000 FFFF', seconds=30), 0xF000, 0xFFFF)
        assert actual == (HERE / 'expected-live-top.bin').read_bytes()
    save('install.json', {'result': 'PASS', 'backup_verified': True,
                          'software_reset': True, 'live_top_sha256': sha(actual)})


def verify():
    before = (HERE / 'before/flash-128k.bin').read_bytes()
    after = (HERE / 'after/flash-128k.bin').read_bytes()
    assert len(before) == len(after) == 131072
    changes = [f'B{bank}:{sector:X}' for bank in range(4) for sector in range(8, 16)
               if before[bank*32768+(sector-8)*4096:bank*32768+(sector-7)*4096] !=
                  after[bank*32768+(sector-8)*4096:bank*32768+(sector-7)*4096]]
    assert changes == ['B2:F', 'B3:F']
    assert after[0x17000:0x18000] == before[0x1F000:0x20000]
    assert after[0x1F000:0x20000] == (HERE / 'expected-live-top.bin').read_bytes()
    assert after[:0x17000] == before[:0x17000]
    assert after[0x18000:0x1F000] == before[0x18000:0x1F000]
    save('verification.json', {'result': 'PASS', 'changed_sectors': changes,
                               'b2f_exact_old_top': True,
                               'other_sectors_unchanged': True,
                               'flash_sha256': sha(after)})
    print((HERE / 'verification.json').read_text())


def enable_policy():
    image = STR8 / 'BUILD/v1.35/s19/str8n-v1.35-str8-in65-bank-maint-2000.s19'
    expected = bytearray((HERE / 'expected-live-top.bin').read_bytes())
    expected[0xFF2] = 0xA6
    with console.Board() as board:
        current = arc.dump_bytes(board.command('D F000 FFFF', seconds=30), 0xF000, 0xFFFF)
        assert current == (HERE / 'expected-live-top.bin').read_bytes()
        board.command('STR8', until=r'K=03 \? ')
        board.send(b'Y')
        board.read(15, r'0-2 C W S: ')
        board.send(b'S')
        board.read(10, r'STR8-N>')
        board.command('L', until=r'S19[\r\n]+')
        response = board.transfer(image, seconds=30, until=r'Q=QUIT> ')
        assert b'STR8-N 1.35 BANK MAINT' in response
        finish_policy(board, image, expected)


def finish_policy(board, image, expected):
    board.command('F', until=r'SEARCH FLAG FF/A0-A7 \[A6\]> ')
    response = board.command('', until=r'TYPE FLAGS A6> ', seconds=50)
    assert b'B3F REWRITE' in response
    response = board.command('FLAGS A6', until=r'Q=QUIT> ', seconds=60)
    assert b'BACKUP VERIFIED' in response and b' OK' in response
    board.command('Q', until=r'0-2 C W S: ', seconds=20)
    board.send(b'S')
    board.read(20, r'STR8-N>')
    response = board.command('C', seconds=20)
    assert b'HIMON V 00.0915(2324)' in response
    actual = arc.dump_bytes(board.command('D F000 FFFF', seconds=30), 0xF000, 0xFFFF)
    assert actual == expected
    (HERE / 'expected-policy-a6-top.bin').write_bytes(expected)
    save('policy.json', {'result': 'PASS', 'policy': 'A6',
                         'live_top_sha256': sha(actual),
                         'editor_sha256': sha(image.read_bytes())})


def resume_policy():
    image = STR8 / 'BUILD/v1.35/s19/str8n-v1.35-str8-in65-bank-maint-2000.s19'
    expected = bytearray((HERE / 'expected-live-top.bin').read_bytes())
    expected[0xFF2] = 0xA6
    with console.Board() as board:
        finish_policy(board, image, expected)


def finish_policy_readback():
    image = STR8 / 'BUILD/v1.35/s19/str8n-v1.35-str8-in65-bank-maint-2000.s19'
    expected = bytearray((HERE / 'expected-live-top.bin').read_bytes())
    expected[0xFF2] = 0xA6
    with console.Board() as board:
        response = board.command('C', seconds=20)
        assert b'HIMON V 00.0915(2324)' in response
        actual = arc.dump_bytes(board.command('D F000 FFFF', seconds=30), 0xF000, 0xFFFF)
        assert actual == expected
    (HERE / 'expected-policy-a6-top.bin').write_bytes(expected)
    save('policy.json', {'result': 'PASS', 'policy': 'A6',
                         'live_top_sha256': sha(actual),
                         'editor_sha256': sha(image.read_bytes())})


def verify_policy():
    prior = (HERE / 'after/flash-128k.bin').read_bytes()
    enabled = (HERE / 'enabled/flash-128k.bin').read_bytes()
    assert len(prior) == len(enabled) == 131072
    changes = [f'B{bank}:{sector:X}' for bank in range(4) for sector in range(8, 16)
               if prior[bank*32768+(sector-8)*4096:bank*32768+(sector-7)*4096] !=
                  enabled[bank*32768+(sector-8)*4096:bank*32768+(sector-7)*4096]]
    assert changes == ['B3:F']
    assert enabled[0x17000:0x18000] == prior[0x17000:0x18000]
    assert enabled[0x1F000:0x20000] == (HERE / 'expected-policy-a6-top.bin').read_bytes()
    assert enabled[:0x17000] == prior[:0x17000]
    assert enabled[0x18000:0x1F000] == prior[0x18000:0x1F000]
    save('policy-verification.json', {'result': 'PASS', 'changed_sectors': changes,
                                      'scratch_b1a_restored': True,
                                      'other_sectors_unchanged': True,
                                      'flash_sha256': sha(enabled)})
    print((HERE / 'policy-verification.json').read_text())


if __name__ == '__main__':
    mode = sys.argv[1]
    if mode in ('before', 'after', 'enabled'):
        archive(mode)
    elif mode == 'inspect':
        inspect()
    elif mode == 'install':
        install()
    elif mode == 'verify':
        verify()
    elif mode == 'policy':
        enable_policy()
    elif mode == 'policy-resume':
        resume_policy()
    elif mode == 'policy-finish':
        finish_policy_readback()
    elif mode == 'verify-policy':
        verify_policy()
    else:
        raise SystemExit(f'unknown mode: {mode}')
