"""Guarded COM4 qualification for the functional HIMON/AP change."""
from pathlib import Path
import json
import re
import sys
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'SRC/BUILD/tmp/himon-size-board'))
sys.path.insert(0,str(ROOT/'SRC/tools'))
import console
from report_himon_ap_baseline import srecord,sha
from audit_himon_ap_contracts import package,word
console.LOG=HERE/'com4.jsonl'

def dump(board,start,end):
    result=board.command(f'D {start:04X} {end:04X}',seconds=50)
    memory={}
    for a,left,right in re.findall(rb'^([0-9A-F]{4}): ([0-9A-F ]+)\| ([0-9A-F ]+)\|',result,re.M):
        row=bytes.fromhex((left+right).decode()); assert len(row)==16
        for i,v in enumerate(row):
            addr=int(a,16)+i; assert addr not in memory; memory[addr]=v
    assert set(memory)==set(range(start,end+1))
    return bytes(memory[a] for a in range(start,end+1))

def record(kind,address,data=b''):
    raw=bytes([len(data)+3,address>>8,address&255])+bytes(data)
    return 'S'+kind+(raw+bytes([~sum(raw)&255])).hex().upper()

def transfer_file(name,spans,entry):
    rows=[]
    for address,data in spans:
        for i in range(0,len(data),32): rows.append(record('1',address+i,data[i:i+32]))
    rows.append(record('9',entry)); p=HERE/(name+'.s19'); p.write_text('\n'.join(rows)+'\n'); return p

def load(board,path):
    board.command('L',until=r'L S19\r')
    r=board.transfer(path,until=r'\r\n>$',seconds=30)
    assert b'L OK=' in r and b'LERR' not in r

def request(op,source,destination,manager=False,mode=3,install_source=0xA00):
    code=bytearray(); calls=[]
    def store(addr,value): code.extend(b'\xA9'+bytes([value])+b'\x8D'+word(addr))
    for addr,value in [(0x7E2F,op),(0x7E31,source&255),(0x7E32,source>>8),
                       (0x7E33,destination&255),(0x7E34,destination>>8)]: store(addr,value)
    calls.append(len(code)); code.extend(b'\x20\0\0')
    if manager:
        # The candidate package is loaded before entering its fixed RAM body.
        code.extend(b'\xB0\x01\x00')
        for addr,value in [(0x7C60,mode),(0x7C62,install_source&255),(0x7C63,install_source>>8),
                           (0x7C64,2),(0x7C65,0xA5)]: store(addr,value)
        code.extend(b'\x20\x00\x70')
    code.extend(b'\x8D\x00\x21\x08\x68\x8D\x01\x21\x60')
    stub=0x2000+len(code); code.extend(b'\x6C\x2D\x7E')
    for offset in calls: code[offset+1:offset+3]=word(stub)
    return bytes(code)

if __name__=='__main__':
    if sys.argv[1]=='probe':
        with console.Board() as b:
            print('Passive:',repr(b.read(1)),flush=True)
            r=b.command('?'); assert b'#? D M R X G AP APS L B N STR8' in r
            data=dump(b,0x8000,0xFFFF)
            p=HERE/'before-b3.bin'; assert not p.exists(); p.write_bytes(data)
            print('Baseline Bank3 SHA256',sha(data),flush=True)
    elif sys.argv[1]=='install':
        transfer=HERE/'functional-28k.s19'
        transfer.write_bytes((ROOT/'SRC/BUILD/s19/ryors-v1.2-himon-asm-bank3-8-e.s19').read_bytes())
        memory=srecord(transfer)
        assert set(memory)==set(range(0x8000,0xF000))
        image=bytes(memory[a] for a in range(0x8000,0xF000))
        assert transfer.read_text().splitlines()[-1]==record('9',0xC000)
        before=(HERE/'before-b3.bin').read_bytes()
        assert len(before)==32768 and not (HERE/'installed-b3.bin').exists()
        print('Installing B3:8-E SHA256',sha(image),flush=True)
        with console.Board() as b:
            assert dump(b,0x8000,0xFFFF)==before
            b.command('STR8',until=r'K=03 \? ')
            b.send(b'Y'); print(b.read(15,r'0-2 C W S: ').decode(),flush=True)
            b.send(b'S'); print(b.read(10,r'STR8-N>').decode(),flush=True)
            b.command('I',until=r'B0-3: ')
            b.command('3',until=r'RANGE: ')
            b.command('8-E',until=r'I B3 8-E WRITE\? Y: ')
            b.command('Y',until=r'S19[\r\n]+')
            result=b.transfer(transfer,seconds=50,until=r'(?:COMMIT\? Y: |FAIL)')
            assert b'COMMIT? Y: ' in result and b'FAIL' not in result
            result=b.command('Y',until=r'STR8-N>',seconds=50)
            assert b'OK' in result and b'FAIL' not in result
            result=b.command('C',seconds=20)
            assert b'HIMON V 00.0915(2324)' in result
            after=dump(b,0x8000,0xFFFF); (HERE/'installed-b3.bin').write_bytes(after)
            assert after[:0x7000]==image, 'ROM payload readback differs'
            changed=[0x8000+i for i,(a,z) in enumerate(zip(before,after)) if a!=z and i>=0x7000]
            assert changed and all(0xFFEC<=a<=0xFFEF for a in changed),changed
            assert all((before[a-0x8000]&after[a-0x8000])==after[a-0x8000] for a in changed)
            (HERE/'installed.json').write_text(json.dumps(dict(payload_sha256=sha(image),
                before_sha256=sha(before),after_sha256=sha(after),top_changes=changed),indent=2)+'\n')
            print('PASS exact B3:8-E readback; only D3 journal changed above it',flush=True)
    elif sys.argv[1]=='qualify':
        results=[]
        with console.Board() as b:
            assert dump(b,0x8000,0xFFFF)==(HERE/'installed-b3.bin').read_bytes()
            for dst,body,valid in [(0x5000,b'\x60\x01\x01\x01',True),
                                   (0x6FFF,b'\x60',True),(0x6FFF,b'\x60\x60',False),
                                   (0x7000,b'\x60',False)]:
                base=dst&0xFFF0; initial=b'\xCC'*32
                load(b,transfer_file(f'boundary-{dst:04X}-{len(body)}',
                     [(0x3000,package(body)),(base,initial)],0x3000))
                r=b.command(f'AP 3000 {dst:04X}')
                if valid: assert f'GO {dst:04X}'.encode() in r and b'RET' in r
                else: assert b'APERR=$06' in r and b'GO ' not in r
                actual=dump(b,base,base+31); expected=bytearray(initial)
                if valid: expected[dst-base:dst-base+len(body)]=body
                assert actual==expected
                results.append(f'takeover {dst:04X}+{len(body)} accepted={valid}; exact BODY/redzones')
            load(b,transfer_file('ordinary-protected',[(0x2000,request(1,0x3000,0x5000)),
                 (0x3000,package()),(0x5000,b'\xCC'*16)],0x2000))
            b.command('G 2000'); result=dump(b,0x2100,0x210F)
            assert result[0]==6 and not (result[1]&1) and dump(b,0x5000,0x500F)==b'\xCC'*16
            results.append('ordinary LOAD 5000 rejected; RAM preserved')
            # Real ASM creates a resumable END session, then AP takes it over.
            b.command('ASM',until=r'ASM>\$2000: ')
            b.command('RTS',until=r'ASM>\$2001: ')
            b.command('END',until=r'SEAL> ')
            b.command('.')
            assert dump(b,0x7E60,0x7E6F)[10]==1
            load(b,transfer_file('resume-takeover',[(0x3000,package(b'\x60\x01\x01\x01'))],0x3000))
            b.command('AP 3000 5000')
            assert dump(b,0x7E60,0x7E6F)[10]==0
            r=b.command('ASM S'); assert b'EXEC ERR=$03' in r and b'SEAL> ' not in r
            b.command('ASM',until=r'ASM>\$2000: '); b.command('.')
            results.append('ASM S refused after takeover; fresh ASM entry works')
            # Reject unsafe INSTALL through the actual resident MANAGER doorway.
            code=bytearray()
            for addr,value in [(0x7C60,3),(0x7C62,0),(0x7C63,0xA),(0x7C64,2),(0x7C65,0xA5)]:
                code.extend(b'\xA9'+bytes([value])+b'\x8D'+word(addr))
            call=request(4,0xA00,0x4000)
            # request's internal trampoline is based at $2000; relocate its JSR.
            call=bytearray(call); jsr=25; assert call[jsr]==0x20
            call[jsr+1:jsr+3]=word(int.from_bytes(call[jsr+1:jsr+3],'little')+len(code))
            code.extend(call)
            load(b,transfer_file('unsafe-install',[(0x2000,code)],0x2000))
            r=b.command('G 2000'); assert b'APERR=$D4' in r
            result=dump(b,0x2100,0x210F); assert result[0]==0xD4 and not(result[1]&1)
            results.append('resident INSTALL 0A00 rejected before bootstrap')
            # Load the exact new APMAN into RAM; exercise its own guard and scan.
            manager=(ROOT/'SRC/BUILD/bin/apman-v1.ap').read_bytes()
            load(b,transfer_file('manager-guard',[(0x2000,request(1,0x4000,0x7000,manager=True)),
                 (0x4000,manager)],0x2000))
            r=b.command('G 2000'); assert b'APMAN ERR=$D4' in r
            result=dump(b,0x2100,0x210F); assert not(result[1]&1)
            results.append('new RAM APMAN rejects unstable INSTALL; no worker entered')
            load(b,transfer_file('manager-inventory',[(0x2000,request(1,0x4000,0x7000,manager=True,mode=2)),
                 (0x4000,manager),(0x1A00,b'APS B1\0')],0x2000))
            r=b.command('G 2000',seconds=30)
            (HERE/'manager-inventory.txt').write_bytes(r)
            assert b'APC' in r and b'RET' in r and b'APMAN ERR' not in r
            results.append('new RAM APMAN scans B1 and returns with B3 restored')
            assert dump(b,0x8000,0xFFFF)==(HERE/'installed-b3.bin').read_bytes()
            (HERE/'board-tests.json').write_text(json.dumps(results,indent=2)+'\n')
            print('PASS',len(results),'board checks; flash unchanged during qualification',flush=True)
    elif sys.argv[1]=='extended':
        results=json.loads((HERE/'board-tests.json').read_text())
        with console.Board() as b:
            manager=(ROOT/'SRC/BUILD/bin/apman-v1.ap').read_bytes()
            load(b,transfer_file('manager-high-child',[(0x2000,request(1,0x4000,0x7000,manager=True,mode=1)),
                 (0x4000,manager),(0x1A00,b'AP B1 BANKAUDIT 5000\0')],0x2000))
            r=b.command('G 2000',seconds=50)
            assert b'-> 5000' in r and b'BANKAUDIT OK; B3 RESTORED' in r and b'RET' in r
            results.append('new RAM APMAN links and tail-runs BANKAUDIT at 5000; B3 restored')
            load(b,transfer_file('asm-install-source',[(0x3000,package(exported=True))],0x3000))
            b.command('ASM',until=r'ASM>\$2000: ')
            b.command('KEEP RTS',until=r'ASM>\$2001: ')
            b.command('END',until=r'SEAL> ')
            r=b.command('INSTALL 3000 B2',until=r'ASM>\$2000: ',seconds=50)
            assert b'APMAN NF' in r and b'SEAL> ' not in r
            b.command('.')
            from report_himon_ap_baseline import symbols
            sym=symbols(ROOT/'SRC/BUILD/s19/asm-v1-flash-8000.map')
            base=sym['ASM_SYM_COUNT']&0xFFF0; data=dump(b,base,base+31)
            assert data[sym['ASM_SYM_COUNT']-base]==data[sym['ASM_FIX_COUNT']-base]==0
            assert dump(b,0x7C60,0x7C6F)[1]==0xDA
            results.append('ASM INSTALL absent manager returns DA; fresh session and zero name counts')
            for kind in ('W','C'):
                b.command('STR8',until=r'K=03 \? '); b.send(b'Y')
                b.read(15,r'0-2 C W S: '); b.send(kind.encode())
                r=b.read(15,r'\r\n>$'); assert b'HIMON V 00.0915(2324)' in r
                assert dump(b,0x7E60,0x7E6F)[10]==0
                assert b'#? D M R X G AP APS L B N STR8' in b.command('?')
                results.append(f'STR8 software {kind} entry republishes services and clears resume')
            assert dump(b,0x8000,0xFFFF)==(HERE/'installed-b3.bin').read_bytes()
        (HERE/'board-tests.json').write_text(json.dumps(results,indent=2)+'\n')
        print('PASS',len(results),'board checks; B0-B2 flash untouched',flush=True)
