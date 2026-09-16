"""Guarded replacement of the existing B2:8 manager; preserve other media."""
from pathlib import Path
import hashlib
import json
import shutil
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path.insert(0,str(ROOT/'LOCAL/bso2-b2/tools'))
sys.path.insert(0,str(ROOT/'LOCAL/himon-ap-change-20260916'))
import bank_archive as archive
import board as previous
LOG=HERE/'serial-com4.jsonl'
archive.LOG=LOG
previous.console.LOG=LOG
previous.HERE=HERE
Board=previous.console.Board
dump,load=previous.dump,previous.load
sha=lambda b:hashlib.sha256(b).hexdigest()

def save_json(name,data):
    (HERE/name).write_text(json.dumps(data,indent=2)+'\n')

def enter_str8(b):
    b.command('STR8',until=r'K=03 \? ')
    b.send(b'Y'); b.read(15,r'0-2 C W S: ')
    b.send(b'S'); b.read(10,r'STR8-N>')

def maintenance(b):
    enter_str8(b)
    b.command('L',until=r'S19[\r\n]+')
    r=b.transfer(HERE/'bank-maint-2000.s19',until=r'Q/ENTER=QUIT> ',seconds=30)
    assert b'BANK MAINT' in r

if __name__=='__main__':
    mode=sys.argv[1]
    if mode=='backup':
        archive.archive(HERE/'before-readback',[0,1,2,3])
        for bank in range(4):
            data=(HERE/f'before-readback/bank{bank}.bin').read_bytes()
            assert data==(ROOT/f'LOCAL/himon-ap-bank2-20260916/final-readback/bank{bank}.bin').read_bytes()
        print('PASS fresh four-bank backup matches the preceding hardware qualification')
    elif mode=='prepare':
        for name,source in {
            'apman-v1.ap':ROOT/'SRC/BUILD/bin/apman-v1.ap',
            'apman-v1-bank2-8000.bin':ROOT/'SRC/BUILD/bin/apman-v1-bank2-8000.bin',
            'apman-v1-bank2-8000.s19':ROOT/'SRC/BUILD/s19/apman-v1-bank2-8000.s19',
            'bank-maint-2000.s19':ROOT.parent/'STR8-N/BUILD/v1.34/s19/str8n-v1.34-bank-maint-2000.s19',
            'bank-stage-2000.s19':archive.HELPER,
            'bank-stage-2000.asm':archive.HELPER.with_suffix('.asm'),
            'bank_archive.py':Path(archive.__file__),
            'console.py':Path(previous.console.__file__),
        }.items():
            assert not (HERE/name).exists()
            shutil.copyfile(source,HERE/name)
        pkg=(HERE/'apman-v1.ap').read_bytes()
        image=(HERE/'apman-v1-bank2-8000.bin').read_bytes()
        assert len(pkg)==0xC05 and image==pkg+b'\xFF'*(4096-len(pkg))
        memory,entry=archive.read_s19(HERE/'apman-v1-bank2-8000.s19')
        assert entry==0x8000 and set(memory)==set(range(0x8000,0x9000))
        assert bytes(memory[a] for a in sorted(memory))==image
        save_json('prepared.json',{'package_sha256':sha(pkg),'carrier_sha256':sha(image)})
        print('PASS exact dense candidate and recovery inputs archived')
    elif mode=='capture-before':
        with Board() as b:
            outputs={}
            for cmd in ('APS','APS B1 BANKAUDIT','APS B1 MICROCHESS','APS B2 APTEST',
                        'AP D B1 BANKAUDIT','AP D B1 8000','AP D B2 APTEST','AP D B2 9000'):
                outputs[cmd]=b.command(cmd,seconds=50).decode('ascii')
            save_json('board-output-before.json',outputs)
    elif mode=='install-manager':
        assert json.loads((HERE/'qualified.json').read_text())['exit_code']==0
        assert json.loads((HERE/'apman-size.json').read_text())['result']=='PASS'
        assert not (HERE/'install-started.json').exists()
        before=(HERE/'before-readback/bank3.bin').read_bytes()
        with Board() as b:
            assert dump(b,0x8000,0xFFFF)==before
            enter_str8(b)
            b.command('I',until=r'B0-3: ')
            b.command('2',until=r'RANGE: ')
            b.command('8',until=r'I B2 8-8 WRITE\? Y: ')
            save_json('install-started.json',{'bank':2,'sector':'8','sha256':sha((HERE/'apman-v1-bank2-8000.bin').read_bytes())})
            b.command('Y',until=r'S19[\r\n]+')
            r=b.transfer(HERE/'apman-v1-bank2-8000.s19',until=r'(?:COMMIT\? Y: |FAIL)',seconds=40)
            assert b'COMMIT? Y: ' in r and b'FAIL' not in r
            r=b.command('Y',until=r'STR8-N>',seconds=40)
            assert b'OK' in r and b'FAIL' not in r
            b.command('C',seconds=20)
            after=dump(b,0x8000,0xFFFF)
            (HERE/'enrolled-b3.bin').write_bytes(after)
            expected=bytearray(before)
            assert expected[0x7FDC]==0xFC
            expected[0x7FDC]=0xF0
            assert after==expected
        archive.archive(HERE/'manager-readback',[2])
        expected=bytearray((HERE/'before-readback/bank2.bin').read_bytes())
        expected[:0x1000]=(HERE/'apman-v1-bank2-8000.bin').read_bytes()
        assert (HERE/'manager-readback/bank2.bin').read_bytes()==expected
        print('PASS manager exact; rest of Bank 2 preserved; B3 only FFDC FC->F0')
    elif mode=='compare-output':
        before=json.loads((HERE/'board-output-before.json').read_text())
        after={}
        with Board() as b:
            for cmd,old in before.items():
                result=b.command(cmd,seconds=50).decode('ascii')
                expected=old.replace('APC APMAN L=0C2E','APC APMAN L=0C05')
                assert result==expected,(cmd,result,expected)
                after[cmd]=result
        save_json('board-output-after.json',after)
        print('PASS eight exact board-output comparisons; only manager self-length differs')
    elif mode=='erase-fixture':
        assert not (HERE/'fixture-erase-started.json').exists()
        assert (HERE/'manager-readback/bank2.bin').read_bytes()[0x1000:0x2000]==(HERE/'before-readback/bank2.bin').read_bytes()[0x1000:0x2000]
        with Board() as b:
            assert dump(b,0x8000,0xFFFF)==(HERE/'enrolled-b3.bin').read_bytes()
            maintenance(b)
            b.command('E',until=r'BANK 0-3> ')
            b.command('2',until=r'SECTOR 8-F, ALL, OR X-Y; B3 MAX E> ')
            b.command('9',until=r'TYPE ERASE 29> ')
            save_json('fixture-erase-started.json',{'bank':2,'sector':'9','purpose':'Reinstall the same APTEST through reduced APMAN'})
            r=b.command('ERASE 29',until=r'Q/ENTER=QUIT> ',seconds=40)
            assert b'. OK' in r and b'!\r\n' not in r
            b.command('Q',until=r'0-2 C W S: ')
            b.send(b'S'); b.read(10,r'STR8-N>')
            b.command('C',seconds=20)
            assert dump(b,0x8000,0xFFFF)==(HERE/'enrolled-b3.bin').read_bytes()
        archive.archive(HERE/'fixture-erased-readback',[2])
        expected=bytearray((HERE/'manager-readback/bank2.bin').read_bytes())
        expected[0x1000:0x2000]=b'\xFF'*4096
        assert (HERE/'fixture-erased-readback/bank2.bin').read_bytes()==expected
        print('PASS only the backed-up APTEST sector erased for real INSTALL retest')
