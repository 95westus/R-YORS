"""Trace the frozen HIMON/AP call and RAM contracts without board I/O.

This is a characterization audit, not hardware acceptance. Actual resident,
manager, and STR8 selector bytes execute; only terminal TX is intercepted.
Flash writes are forbidden. INSTALL traces stop before entering its worker.
Stack peaks are observed fixture depths, not exhaustive/interrupt bounds.
"""
import argparse
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'SRC/BUILD/tmp/asm-error-deps'))
from py65.devices.mpu65c02 import MPU
from report_himon_ap_baseline import sha, srecord, symbols, spans


def fnv(data):
    value = 0x811C9DC5
    for byte in data:
        value = ((value ^ byte) * 0x1000193) & 0xFFFFFFFF
    return value


def word(value):
    return value.to_bytes(2, 'little')


def packed_name(name):
    alphabet = b'\x00ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_?.'
    codes = [alphabet.index(c) for c in name]
    codes += [0] * ((-len(codes)) % 3)
    return b''.join(word((codes[i]*40+codes[i+1])*40+codes[i+2])
                    for i in range(0,len(codes),3))


def import_record(kind,name):
    return b'\x01'+bytes([kind])+fnv(name).to_bytes(4,'little')+bytes([len(name)])+packed_name(name)


def package(body=b'\x60', imports=b'\x00', reloc=b'\x00', exported=False):
    seal = b'\x01' + word(0x2800) + word(0x2800+len(body)) + word(len(body)) + fnv(body).to_bytes(4,'little')
    export = b'\x00'
    if exported:
        # Single EXEC+ENTRY at offset zero, public name T, one PACK40 word.
        export = b'\x01\x81\x00\x00' + fnv(b'T').to_bytes(4,'little') + b'\x01'+packed_name(b'T')
    sections = b''.join(bytes([tag])+word(len(data))+data for tag,data in
                        zip(b'SREIB', [seal,reloc,export,imports,body]))
    return b'AP\x02'+word(len(sections)+5)+sections


class Memory:
    def __init__(self, build, top):
        self.ram = bytearray([0xCC])*0x8000
        self.ram[0x7FEC] = 0xFF
        self.banks = [bytearray([0xFF])*0x8000 for _ in range(4)]
        for name in ['himon-rom-c000','asm-v1-flash-8000']:
            for address,value in srecord(build/'s19'/f'{name}.s19').items():
                self.banks[3][address-0x8000] = value
        self.banks[3][0x7000:] = top
        self.writes = set()
        self.bank_visits = []

    @property
    def bank(self):
        value = self.ram[0x7FEC]
        # Decode the two bank bits even during the selector's TRB/TSB update.
        return ((value & 2) >> 1) | ((value & 0x20) >> 4)

    def __getitem__(self, address):
        if isinstance(address,slice):
            return [self[a] for a in range(*address.indices(65536))]
        return self.ram[address] if address < 0x8000 else self.banks[self.bank][address-0x8000]

    def __setitem__(self, address, value):
        if address >= 0x8000:
            raise AssertionError(f'Forbidden flash write ${address:04X}')
        self.ram[address] = value
        self.writes.add(address)
        if address == 0x7FEC:
            self.bank_visits.append(self.bank)


class Machine:
    def __init__(self, build, top):
        self.s = symbols(build/'s19/himon-rom-c000.map')
        self.asm = symbols(build/'s19/asm-v1-flash-8000.map')
        self.manager = symbols(build/'s19/apman-7000.map')
        self.m = Memory(build,top)
        self.c = MPU(memory=self.m)
        self.run('MON_INIT_SERVICE_VECTORS')

    def set(self, name, value):
        self.m.ram[self.s[name]] = value

    def setword(self, name, value):
        a = self.s[name]
        self.m.ram[a:a+2] = word(value)

    def run(self, entry, stop=None, limit=5_000_000, a=0x59, x=0xA6, y=0x37):
        c,m = self.c,self.m
        c.pc = self.s.get(entry,self.asm.get(entry,entry)) if isinstance(entry,str) else entry
        c.a,c.x,c.y,c.p,c.sp = a,x,y,0x20,0xFF
        c.stPushWord(0x1FFE)
        m.writes.clear()
        m.bank_visits.clear()
        before = bytes(m.ram)
        low = c.sp
        output = bytearray()
        outcome = 'return'
        for steps in range(limit):
            if c.pc == 0x1FFF:
                assert c.sp == 0xFF, ('unbalanced return',entry,c.sp)
                break
            if stop is not None and c.pc == stop:
                outcome = 'stopped-before-worker' if stop==0x200 else 'stopped-at-caller-boundary'
                break
            if c.pc == self.s['BIO_FTDI_WRITE_BYTE_BLOCK']:
                output.append(c.a)
                c.p |= 1
                c.pc = (c.stPopWord()+1)&0xFFFF
            else:
                assert m[c.pc] != 0, ('unexpected BRK',hex(c.pc),entry)
                c.step()
            low = min(low,c.sp)
        else:
            raise AssertionError(('instruction limit',entry,hex(c.pc)))
        assert m.bank == 3
        return dict(entry=entry,result=outcome,a=c.a,x=c.x,y=c.y,carry=bool(c.p&1),
                    ap_status=m.ram[0x7E30],manager_status=m.ram[0x7C61],
                    stack_peak_bytes_including_entry=0xFF-low,steps=steps,
                    writes=spans(m.writes),changed=spans(a for a in m.writes if m.ram[a]!=before[a]),
                    bank_visits=m.bank_visits.copy(),output=output.decode('ascii','replace'))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--build-dir',type=Path,default=ROOT/'LOCAL/himon-ap-baseline-20260916/build-1')
    p.add_argument('--top',type=Path,default=ROOT.parent/'STR8-N/BUILD/v1.34/bin/str8n-v1.34-bank3-f000-ffff.bin')
    p.add_argument('--output',type=Path,required=True)
    args = p.parse_args()
    top = args.top.read_bytes()
    lock = json.loads((ROOT/'SRC/INTEGRATION/str8n.lock.json').read_text())
    assert sha(top).upper() == lock['artifacts']['topSectorSha256']
    results = []
    make = lambda: Machine(args.build_dir,top)

    def save(label,m,result):
        result['case'] = label
        result['asm_name_tables_written'] = any(0x200<=a<0x1A00 for a in m.m.writes)
        result['asm_udata_written'] = any(0x5000<=a<0x6D6E for a in m.m.writes)
        results.append(result)
        print(label, 'C='+str(int(result['carry'])), 'AP='+hex(result['ap_status']),
              'AM='+hex(result['manager_status']), 'stack='+str(result['stack_peak_bytes_including_entry']),flush=True)

    for op,label,dst,expected in [(0,'parse',0x4000,0),(1,'direct-load',0x4000,0),
            (1,'direct-load-last-byte-4FFF',0x4FFF,0),(1,'direct-load-5000-rejected',0x5000,6),
            (1,'direct-tool-load-7BFF',0x7BFF,0),(1,'direct-load-7C00-rejected',0x7C00,6),
            (2,'suggest-read-only',0x4000,0),(255,'unknown-operation',0x4000,7)]:
        m = make()
        data=package()
        m.m.ram[0x3000:0x3000+len(data)] = data
        m.setword('HIM_AP_SRC_LO',0x3000)
        m.setword('HIM_AP_DST_LO',dst)
        m.set('HIM_AP_OP',op)
        result=m.run('HIM_AP_SERVICE')
        assert result['ap_status']==expected and result['carry']==(expected==0)
        assert not any(0x200<=a<0x1A00 or 0x5000<=a<0x6D6E for a in m.m.writes)
        save(label,m,result)

    for kind,label,expected in [(1,'typed-exec-import',0),(2,'wrong-kind-import',9),
                                (2,'typed-data-import',0)]:
        m=make()
        public_name = b'T' if label=='typed-data-import' else b'FNV1A_INIT'
        resolved = m.s['FNV1A_INIT']
        if label=='typed-data-import':
            record=b'FN\xD6'+fnv(public_name).to_bytes(4,'little')+b'\x00\xA5'
            m.m.banks[3][0x6F00:0x6F00+len(record)]=record
            resolved=0xEF08
        imports=import_record(kind,public_name)
        data=package(b'\x00\x00\x60',imports=imports,reloc=b'\x01\x04\x00\x00\x00\x00')
        m.m.ram[0x3000:0x3000+len(data)] = data
        m.setword('HIM_AP_SRC_LO',0x3000)
        m.setword('HIM_AP_DST_LO',0x4000)
        m.set('HIM_AP_OP',1)
        result=m.run('HIM_AP_SERVICE')
        assert result['ap_status']==expected and result['carry']==(expected==0)
        assert m.m.ram[0x4002]==0x60, 'BODY must have been copied before import failure'
        if not expected:
            assert m.m.ram[0x4000:0x4002]==word(resolved)
        save(label,m,result)

    m=make()
    data=package(b'\x00\x00\x60',
                 imports=import_record(1,b'FNV1A_INIT'),
                 reloc=b'\x01\x04\x00\x00\x00\x00')
    m.m.ram[0x3000:0x3000+len(data)]=data
    m.setword('HIM_AP_SRC_LO',0x3000)
    m.setword('HIM_AP_DST_LO',0x4000)
    m.set('HIM_AP_OP',0)
    assert m.run('HIM_AP_SERVICE')['carry']
    m.m.ram[0x4000:0x4003]=b'\x00\x00\x60'
    m.set('HIM_AP_OP',3)
    result=m.run('HIM_AP_SERVICE')
    assert result['carry'] and result['ap_status']==0
    assert m.m.ram[0x4000:0x4002]==word(m.s['FNV1A_INIT'])
    save('link-parsed-state',m,result)

    carrier=(args.build_dir/'bin/apman-v1-bank2-8000.bin').read_bytes()
    m=make()
    data=package()
    m.m.ram[0x3000:0x3000+len(data)]=data
    base=m.asm['ASM_RELOCATE_BASE_LO']
    m.m.ram[base:base+2]=word(0x4000)
    result=m.run('ASM_PACKAGE_LOAD',x=0,y=0x30)
    assert result['carry'] and m.m.ram[0x4000]==0x60
    assert not any(0x200<=a<0x1A00 for a in m.m.writes)
    save('asm-client-direct-load',m,result)

    m=make()
    data=package(exported=True)
    m.m.ram[0x3000:0x3000+len(data)]=data
    base=m.asm['ASMF_ARG0_LO']
    m.m.ram[base:base+2]=word(0x3000)
    m.m.ram[m.asm['ASM_SYM_COUNT']]=3
    m.m.ram[m.asm['ASM_FIX_COUNT']]=2
    result=m.run('ASMF_INSTALL_BANK',a=1,stop=m.asm['ASMF_LOOP'])
    assert result['result']=='stopped-at-caller-boundary'
    assert m.m.ram[m.asm['ASM_SYM_COUNT']]==3 and m.m.ram[m.asm['ASM_FIX_COUNT']]==2
    assert m.m.ram[0xA00:0x1A00]==b'\xff'*0x1000
    save('asm-install-absent-retains-stale-counts',m,result)

    for label,command,mode,manager,source,stop in [
            ('manager-absent','APS',2,False,0x3000,None),
            ('manager-corrupt','APS',2,True,0x3000,None),
            ('manager-load-only','AP L B1 8000 4000',1,True,0x3000,None),
            ('manager-named-load','AP L B1 T 4000',1,True,0x3000,None),
            ('manager-duplicate-status','AP L B1 T 4000',1,True,0x3000,None),
            ('manager-child-return','AP B1 8000 4000',1,True,0x3000,None),
            ('manager-5000-rejected','AP L B1 8000 5000',1,True,0x3000,None),
            ('manager-install-pre-worker','INSTALL 3000 B1',3,True,0x3000,0x200),
            ('manager-install-staged-source-lost','INSTALL 0A00 B1',3,True,0x0A00,0x200)]:
        m=make()
        if manager:
            m.m.banks[2][:0x1000]=carrier
        if label=='manager-corrupt':
            m.m.banks[2][100]^=1
        data=package(exported=True)
        if mode==1:
            m.m.banks[1][:len(data)]=data
        if label=='manager-duplicate-status':
            m.m.banks[1][0x1000:0x1000+len(data)]=data
        m.m.ram[source:source+len(data)]=data
        m.m.ram[0x7A00:0x7B00]=(command.encode()+b'\0').ljust(256,b'\0')
        shadow=bytes(m.m.ram[0x7A00:0x7B00])
        m.m.ram[0x7C60]=mode
        m.m.ram[0x7C62:0x7C64]=word(source)
        m.m.ram[0x7C64:0x7C66]=b'\x01\xA5'
        m.set('HIM_AP_OP',4)
        result=m.run('HIM_AP_SERVICE',stop=stop)
        assert bytes(m.m.ram[0x1A00:0x1B00])==shadow
        assert not any(0x5000<=a<0x6D6E for a in m.m.writes)
        if label in ('manager-absent','manager-corrupt'):
            assert 'APMAN NF' in result['output']
            assert result['carry'] and result['ap_status']==7
        if label in ('manager-load-only','manager-named-load','manager-child-return'):
            assert result['carry'] and result['manager_status']==0xAC and m.m.ram[0x4000]==0x60
        if label=='manager-5000-rejected':
            assert not result['carry'] and result['manager_status']==0xD3
        if label=='manager-duplicate-status':
            assert not result['carry'] and result['manager_status']==0xD1
            assert 'APMAN ERR=$D2' in result['output'] and 'APMAN ERR=$D1' in result['output']
        if label=='manager-install-pre-worker':
            assert result['result']=='stopped-before-worker'
            assert bytes(m.m.ram[0xA00:0xA00+len(data)])==data
            assert m.m.ram[0x7DF0]==5 and m.m.ram[0x7DEF]==1
        if label=='manager-install-staged-source-lost':
            # Bootstrap replaces the caller's staged package with APMAN;
            # install then clears that same tray before copying from it.
            assert result['result']=='stopped-before-worker'
            assert bytes(m.m.ram[0xA00:0x1A00])==b'\xff'*0x1000
        save(label,m,result)

    evidence=dict(schema=1,scope='host characterization; no serial/flash writes',
                  build_dir=str(args.build_dir),top_sha256=sha(top),
                  inputs={name:sha((args.build_dir/name).read_bytes()) for name in [
                      's19/himon-rom-c000.s19','s19/himon-rom-c000.map',
                      's19/asm-v1-flash-8000.s19','s19/asm-v1-flash-8000.map',
                      's19/apman-7000.s19','s19/apman-7000.map','bin/apman-v1.ap',
                      'bin/apman-v1-bank2-8000.bin']},
                  audit_tool_sha256=sha(Path(__file__).read_bytes()),
                  terminal_hook='BIO_FTDI_WRITE_BYTE_BLOCK only; preserves A/X/Y and sets C',
                  stack_scope='observed bytes including 2-byte synthetic caller; no interrupt or child execution bound',
                  cases=results)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(evidence,indent=2)+'\n')
    print(f'PASS {len(results)} characterization cases; no flash writes')


if __name__=='__main__':
    main()
