"""Guarded COM4 qualification for the resident range-branch reduction."""
from pathlib import Path
import importlib.util
import json
import re
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT/'SRC/tools'))
import console
from report_himon_ap_baseline import sha, srecord
from audit_himon_ap_contracts import package, word
console.LOG = HERE/'serial-com4.jsonl'
Board = console.Board


def save(name, data):
    (HERE/name).write_text(json.dumps(data, indent=2)+'\n')


def dump(b, start, end):
    response = b.command(f'D {start:04X} {end:04X}', seconds=50)
    memory = {}
    for address, left, right in re.findall(rb'^([0-9A-F]{4}): ([0-9A-F ]+)\| ([0-9A-F ]+)\|', response, re.M):
        row = bytes.fromhex((left+right).decode())
        assert len(row) == 16
        for offset, value in enumerate(row):
            site = int(address,16)+offset
            assert site not in memory
            memory[site] = value
    assert set(memory) == set(range(start,end+1))
    return bytes(memory[a] for a in range(start,end+1))


def record(kind, address, data=b''):
    raw = bytes([len(data)+3])+address.to_bytes(2,'big')+bytes(data)
    return 'S'+str(kind)+(raw+bytes([~sum(raw)&255])).hex().upper()


def load(b, name, spans, entry=0x2100):
    lines = [record(1,address+i,data[i:i+32]) for address,data in spans for i in range(0,len(data),32)]
    path = HERE/(name+'.s19')
    path.write_text('\n'.join(lines+[record(9,entry)])+'\n')
    b.command('L', until=r'L S19\r')
    result = b.transfer(path, until=r'\r\n>$', seconds=30)
    assert b'L OK=' in result and b'LERR' not in result


def request(op, src, dst, guard=None):
    code = bytearray()
    if guard:
        start,length=guard
        assert 0<length<128
        # HIMON L protects high monitor RAM. Seed only this test's redzone
        # from the caller, before invoking the AP service under test.
        code.extend(b'\xA2'+bytes([length-1])+b'\xA9\xCC\x9D'+word(start)+b'\xCA\x10\xFA')
    for address,value in [(0x7E2F,op),(0x7E31,src&255),(0x7E32,src>>8),
                          (0x7E33,dst&255),(0x7E34,dst>>8)]:
        code.extend(b'\xA9'+bytes([value])+b'\x8D'+word(address))
    call=len(code); code.extend(b'\x20\0\0')
    code.extend(bytes.fromhex('8D 00 22 08 68 8D 01 22 AD 30 7E 8D 02 22 60'))
    code[call+1:call+3]=word(0x2100+len(code))
    code.extend(bytes.fromhex('6C 2D 7E'))
    return code


def selector(b):
    b.command('STR8', until=r'K=03 \? ')
    b.send(b'Y'); b.read(15,r'0-2 C W S: ')
    b.send(b'S'); b.read(10,r'STR8-N>')


def smoke(b):
    b.command('ASM NEW', until=r'ASM>\$2000: ')
    for line, end in [('LDA #$AC','2002'),('SEC','2003'),('RTS','2004')]:
        b.command(line, until=rf'ASM>\${end}: ')
    b.command('END', until=r'SEAL> ')
    b.command('.')
    response=b.command('G 2000')
    assert b'RET A=AC' in response
    assert dump(b,0x2000,0x200F)[:4]==bytes.fromhex('A9 AC 38 60')
    r=b.command('AP B2 APTEST 5000',seconds=30)
    assert b'GO 5002' in r
    assert dump(b,0x5000,0x500F)[:6]==bytes.fromhex('00 00 A9 5A 38 60')


if __name__=='__main__':
    mode=sys.argv[1]
    if mode in ('backup','final-archive'):
        spec=importlib.util.spec_from_file_location('archive',ROOT/'LOCAL/apman-size-20260916/bank_archive.py')
        archive=importlib.util.module_from_spec(spec); spec.loader.exec_module(archive)
        archive.ROOT=ROOT;archive.HERE=HERE;archive.HELPER=HERE/'bank-stage-2000.s19'
        archive.LOG=console.LOG;archive.get_board_class=lambda:Board
        target=HERE/('before-readback' if mode=='backup' else 'final-readback')
        archive.archive(target,[0,1,2,3])
        if mode=='backup':
            assert sha((target/'flash-128k.bin').read_bytes())=='81bc7400407662a66b65deac09ead6c7c768fdbda48e17d21f130e43517e7642'
        else:
            for bank in (0,1,2):
                assert (target/f'bank{bank}.bin').read_bytes()==(HERE/f'before-readback/bank{bank}.bin').read_bytes()
            assert (target/'bank3.bin').read_bytes()==(HERE/'installed-b3.bin').read_bytes()
            save('isolation.json',{'result':'PASS','preserved_banks':[0,1,2],'bank3_sha256':sha((target/'bank3.bin').read_bytes())})
    elif mode=='install':
        gate=json.loads((HERE/'host-pass.json').read_text());assert gate['result']=='PASS'
        transfer=HERE/'himon-c-e.s19';assert sha(transfer.read_bytes())==gate['install_sha256']
        memory=srecord(transfer);assert set(memory)==set(range(0xC000,0xF000))
        image=bytes(memory[a] for a in range(0xC000,0xF000))
        assert transfer.read_text().splitlines()[-1]==record(9,0xC000)
        before=(HERE/'before-readback/bank3.bin').read_bytes()
        assert not (HERE/'install-started.json').exists()
        with Board() as b:
            assert dump(b,0x8000,0xFFFF)==before
            selector(b)
            b.command('I',until=r'B0-3: ')
            b.command('3',until=r'RANGE: ')
            b.command('C-E',until=r'I B3 C-E WRITE\? Y: ')
            save('install-started.json',{'bank':3,'sectors':'C-E','payload_sha256':sha(image)})
            b.command('Y',until=r'S19[\r\n]+')
            r=b.transfer(transfer,seconds=50,until=r'(?:COMMIT\? Y: |FAIL)')
            assert b'COMMIT? Y: ' in r and b'FAIL' not in r
            r=b.command('Y',until=r'STR8-N>',seconds=50)
            assert b'OK' in r and b'FAIL' not in r
            r=b.command('C',seconds=20);assert b'HIMON V 00.0915(2324)' in r
            after=dump(b,0x8000,0xFFFF);(HERE/'installed-b3.bin').write_bytes(after)
            assert after[:0x4000]==before[:0x4000] and after[0x4000:0x7000]==image
            changes=[0x8000+i for i,(x,y) in enumerate(zip(before,after)) if x!=y and i>=0x7000]
            assert changes and all(0xFFEC<=a<=0xFFEF for a in changes)
            assert all(before[a-0x8000]&after[a-0x8000]==after[a-0x8000] for a in changes)
            save('install.json',dict(result='PASS',before_sha256=sha(before),after_sha256=sha(after),journal_changes=changes,payload_sha256=sha(image)))
    elif mode=='qualify':
        results=[]
        with Board() as b:
            assert dump(b,0x8000,0xFFFF)==(HERE/'installed-b3.bin').read_bytes()
            for op,dst,length,valid in [(1,0x4FFF,1,True),(1,0x4FFF,2,False),(1,0x5000,1,False),
                (1,0x7000,1,True),(1,0x7BFF,1,True),(1,0x7BFF,2,False),
                (5,0x5000,4,True),(5,0x6FFF,1,True),(5,0x6FFF,2,False),(5,0x7000,1,False)]:
                name=f'load-{op}-{dst:04X}-{length}'
                start=dst&0xFFF0;end=(dst+length-1)|15
                body=b'\x60'*length
                load(b,name,[(0x2100,request(op,0x3000,dst,guard=(start,end-start+1))),
                             (0x3000,package(body))])
                b.command('G 2100')
                status=dump(b,0x2200,0x220F)
                assert bool(status[1]&1)==valid and status[0]==status[2]==(0 if valid else 6),(name,status.hex())
                actual=dump(b,start,end);expected=bytearray(b'\xCC'*(end-start+1))
                if valid:expected[dst-start:dst-start+length]=body
                assert actual==expected,name
                results.append(name+' exact status/BODY/redzones')
            for src,valid in [(0x0A00,True),(0x1900,True),(0x3000,True),
                              (0x1A00,False),(0x5000,False),(0x7FFF,False),(0xFF00,False)]:
                name=f'source-{src:04X}'
                spans=[(0x2100,request(0,src,0x4000))]
                if valid:spans.append((src,package()))
                load(b,name,spans);b.command('G 2100')
                status=dump(b,0x2200,0x220F)
                assert bool(status[1]&1)==valid and status[0]==status[2]==(0 if valid else 6)
                results.append(name+' parser source boundary')
            r=b.command('APS B2 APMAN',seconds=30);assert b'APMAN L=0C05 @7000' in r
            r=b.command('AP B1 BANKAUDIT 5000',seconds=50)
            assert b'BANKAUDIT OK; B3 RESTORED' in r
            (HERE/'bankaudit.txt').write_bytes(r)
            results.append('persistent manager/flash-source/typed imports/BANKAUDIT')
            smoke(b);results.append('fresh ASM execution and persistent APTEST')
            r=b.command('ASM S');assert b'EXEC ERR=$03' in r
            for mode in ('W','C'):
                selector(b);r=b.command(mode,seconds=20)
                assert b'HIMON V 00.0915(2324)' in r
                assert dump(b,0x7E60,0x7E6F)[10]==0
                smoke(b);results.append('software '+mode+' recovery/ASM/APTEST')
            assert dump(b,0x8000,0xFFFF)==(HERE/'installed-b3.bin').read_bytes()
            save('board-tests.json',{'result':'PASS','cases':results})
    elif mode=='reset':
        with Board() as b:
            print('COM4 listening for physical RESET; receive-only until HIMON prompt',flush=True)
            received=bytearray();deadline=time.monotonic()+600
            while time.monotonic()<deadline:
                received.extend(b.read(2));(HERE/'physical-reset.txt').write_bytes(received)
                if b'RST H' in received and b'HIMON V 00.0915(2324)' in received and re.search(rb'\r\n>$',received):
                    assert dump(b,0x7E60,0x7E6F)[10]==0
                    smoke(b)
                    assert dump(b,0x8000,0xFFFF)==(HERE/'installed-b3.bin').read_bytes()
                    save('physical-tests.json',{'result':'PASS','checks':['RST H/STR8/HIMON recovery','resume cleared','fresh ASM and persistent APTEST','exact Bank 3 readback']})
                    print('PASS physical RESET and post-reset workflow',flush=True)
                    break
            else:raise SystemExit('Physical RESET still pending')
