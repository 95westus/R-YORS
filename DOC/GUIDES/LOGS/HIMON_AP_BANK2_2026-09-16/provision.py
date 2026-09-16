"""COM4 Bank-2 conversion and persistent APMAN qualification receipts."""
from pathlib import Path
import contextlib
import hashlib
import io
import json
import shutil
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'LOCAL/bso2-b2/tools'))
sys.path.insert(0, str(ROOT / 'LOCAL/himon-ap-change-20260916'))
import bank_archive as archive
import board as previous

LOG = HERE / 'serial-com4.jsonl'
archive.LOG = LOG
previous.console.LOG = LOG
previous.HERE = HERE
Board = previous.console.Board
dump, load = previous.dump, previous.load
sha = lambda data: hashlib.sha256(data).hexdigest()


def save_json(name, obj):
    (HERE / name).write_text(json.dumps(obj, indent=2) + '\n')


def enter_str8(b):
    b.command('STR8', until=r'K=03 \? ')
    b.send(b'Y')
    print(b.read(15, r'0-2 C W S: ').decode(), flush=True)
    b.send(b'S')
    print(b.read(10, r'STR8-N>').decode(), flush=True)


def prepare():
    files = {
        'apman-v1.ap': ROOT / 'SRC/BUILD/bin/apman-v1.ap',
        'apman-v1-bank2-8000.bin': ROOT / 'SRC/BUILD/bin/apman-v1-bank2-8000.bin',
        'apman-v1-bank2-8000.s19': ROOT / 'SRC/BUILD/s19/apman-v1-bank2-8000.s19',
        'bank-maint-2000.s19': Path('C:/SRC/STR8-N/BUILD/v1.34/s19/str8n-v1.34-bank-maint-2000.s19'),
        'bank-stage-2000.s19': archive.HELPER,
        'bank-stage-2000.asm': archive.HELPER.with_suffix('.asm'),
        'bank_archive.py': Path(archive.__file__),
        'console.py': Path(previous.console.__file__),
    }
    for name, source in files.items():
        dest = HERE / name
        assert not dest.exists()
        shutil.copyfile(source, dest)
    pkg = (HERE / 'apman-v1.ap').read_bytes()
    assert pkg == (ROOT / 'LOCAL/himon-ap-change-20260916/functional/bin/apman-v1.ap').read_bytes()
    image = (HERE / 'apman-v1-bank2-8000.bin').read_bytes()
    assert len(pkg) == 0xC2E and image == pkg + b'\xFF' * (4096-len(pkg))
    memory, entry = archive.read_s19(HERE / 'apman-v1-bank2-8000.s19')
    assert entry == 0x8000 and set(memory) == set(range(0x8000, 0x9000))
    assert bytes(memory[a] for a in sorted(memory)) == image
    memory, entry = archive.read_s19(HERE / 'bank-maint-2000.s19')
    assert entry == 0x2000 and min(memory) == 0x2000 and max(memory) < 0x7B00
    save_json('inputs.json', {name: {'source': str(source), 'sha256': sha((HERE/name).read_bytes())}
                             for name, source in files.items()})
    print('PASS exact previously tested APMAN package/carrier; maintenance S19 valid')


if __name__ == '__main__':
    mode = sys.argv[1]
    if mode == 'prepare':
        prepare()
    elif mode == 'backup':
        archive.archive(HERE / 'before-readback', [0, 1, 2, 3])
        before = HERE / 'before-readback'
        assert (before/'bank3.bin').read_bytes() == (ROOT/'LOCAL/himon-ap-change-20260916/installed-b3.bin').read_bytes()
        assert (before/'bank2.bin').read_bytes() == (ROOT/'LOCAL/bso2-b2/bso2-bank2-8000-ffff.bin').read_bytes()
        for bank in (0, 1):
            assert (before/f'bank{bank}.bin').read_bytes() == (ROOT/f'LOCAL/bso2-b2/board/after-readback/bank{bank}.bin').read_bytes()
        print('PASS live four-bank backup exactly matches expected installed firmware and BSO2')
    elif mode == 'leave-maintenance':
        with Board() as b:
            b.command('Q', until=r'0-2 C W S: ', seconds=15)
            b.send(b'S'); b.read(10, r'STR8-N>')
            b.command('C', seconds=20)
    elif mode == 'erase-reclaim':
        before = HERE / 'before-readback'
        baseline = (before/'bank3.bin').read_bytes()
        assert len((before/'flash-128k.bin').read_bytes()) == 131072
        assert not (HERE/'erase-started.json').exists(), 'Inspect previous transaction before retrying'
        with Board() as b:
            assert dump(b, 0x8000, 0xFFFF) == baseline
            enter_str8(b)
            b.command('L', until=r'S19[\r\n]+')
            r = b.transfer(HERE/'bank-maint-2000.s19', until=r'Q/ENTER=QUIT> ', seconds=30)
            assert b'BANK MAINT' in r
            r = b.command('M', until=r'Q/ENTER=QUIT> ', seconds=40)
            (HERE/'maintenance-before.txt').write_bytes(r)
            assert b'D2 FF BSO-2 FFFF FCFFFFFF' in r
            b.command('E', until=r'BANK 0-3> ')
            b.command('2', until=r'SECTOR 8-F, ALL, OR X-Y; B3 MAX E> ')
            b.command('ALL', until=r'TYPE ERASE 2ALL> ')
            save_json('erase-started.json', {'bank': 2, 'range': '8-F', 'backup_sha256': sha((before/'flash-128k.bin').read_bytes())})
            r = b.command('ERASE 2ALL', until=r'Q/ENTER=QUIT> ', seconds=50)
            assert b'........ OK' in r and b'!\r\n' not in r
            b.command('R', until=r'RECLAIM DIR 0-3> ')
            b.command('2', until=r'TYPE CLEAR D2> ', seconds=30)
            r = b.command('CLEAR D2', until=r'Q/ENTER=QUIT> ', seconds=50)
            assert b'BACKUP VERIFIED' in r and b' OK' in r and b'!\r\n' not in r
            r = b.command('M', until=r'Q/ENTER=QUIT> ', seconds=40)
            (HERE/'maintenance-erased.txt').write_bytes(r)
            assert b'B2 E E E E E E E E' in r and b'D2 FF ..... FFFF FFFFFFFF' in r
            b.command('Q', until=r'0-2 C W S: ', seconds=15)
            b.send(b'S'); b.read(10, r'STR8-N>')
            b.command('C', seconds=20)
            after = dump(b, 0x8000, 0xFFFF)
            (HERE/'reclaimed-b3.bin').write_bytes(after)
            expected = bytearray(baseline); expected[0x7FD0:0x7FE0] = b'\xFF'*16
            assert after == expected, 'Unexpected B3 change: inspect saved readback'
        archive.archive(HERE/'erased-readback', [2])
        assert (HERE/'erased-readback/bank2.bin').read_bytes() == b'\xFF'*32768
        print('PASS Bank 2 entirely erased; only D2 changed in Bank 3')
    elif mode == 'install-manager':
        assert (HERE/'erased-readback/bank2.bin').read_bytes() == b'\xFF'*32768
        assert not (HERE/'install-started.json').exists(), 'Inspect previous transaction before retrying'
        with Board() as b:
            baseline = (HERE/'reclaimed-b3.bin').read_bytes()
            assert dump(b, 0x8000, 0xFFFF) == baseline
            enter_str8(b)
            b.command('I', until=r'B0-3: ')
            b.command('2', until=r'RANGE: ')
            b.command('8', until=r'TYPE: ')
            b.command('A2', until=r'DESC: ')
            b.command('APC02', until=r'I B2 8-8 WRITE\? Y: ')
            save_json('install-started.json', {'image_sha256': sha((HERE/'apman-v1-bank2-8000.bin').read_bytes())})
            b.command('Y', until=r'S19[\r\n]+')
            r = b.transfer(HERE/'apman-v1-bank2-8000.s19', until=r'(?:COMMIT\? Y: |FAIL)', seconds=40)
            assert b'COMMIT? Y: ' in r and b'FAIL' not in r
            r = b.command('Y', until=r'STR8-N>', seconds=40)
            assert b'OK' in r and b'FAIL' not in r
            b.command('C', seconds=20)
            after = dump(b, 0x8000, 0xFFFF)
            (HERE/'enrolled-b3.bin').write_bytes(after)
            expected = bytearray(baseline)
            expected[0x7FD0:0x7FE0] = bytes.fromhex('A2 FF FF FF 41 50 43 30 32 FE FF FF FC FF FF FF')
            assert after == expected
        archive.archive(HERE/'manager-readback', [0, 1, 2, 3])
        after = HERE/'manager-readback'
        for bank in (0, 1):
            assert (after/f'bank{bank}.bin').read_bytes() == (HERE/f'before-readback/bank{bank}.bin').read_bytes()
        assert (after/'bank2.bin').read_bytes() == (HERE/'apman-v1-bank2-8000.bin').read_bytes() + b'\xFF'*0x7000
        assert (after/'bank3.bin').read_bytes() == (HERE/'enrolled-b3.bin').read_bytes()
        print('PASS exact persistent manager; Banks 0/1 preserved; Bank 3 only D2 enrollment')
