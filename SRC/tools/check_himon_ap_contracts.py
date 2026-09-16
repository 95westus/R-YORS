"""Execute current HIMON/AP contracts with real linked bytes; forbid flash writes.

INSTALL stops before the worker. Board programming is a separate qualification.
The historical audit runner remains unchanged so its evidence stays reproducible.
"""
import argparse
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
from audit_himon_ap_contracts import ROOT, Machine, package, word, import_record, fnv, sha


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-dir', type=Path, default=ROOT/'SRC/BUILD')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    top = (ROOT.parent/'STR8-N/BUILD/v1.34/bin/str8n-v1.34-bank3-f000-ffff.bin').read_bytes()
    lock = json.loads((ROOT/'SRC/INTEGRATION/str8n.lock.json').read_text())
    assert sha(top).upper() == lock['artifacts']['topSectorSha256']
    build = args.build_dir
    carrier = (build/'bin/apman-v1-bank2-8000.bin').read_bytes()
    rows = []

    def make():
        m = Machine(build, top)
        m.m.banks[3][0x7FF2] = 0xA7  # Explicit emulator enrollment for legacy workflows.
        m.m.banks[3][0x7FF0:0x7FF2] = bytes((0x1E, 0x1F))  # legacy role fixture
        assert m.m.ram[0x7E6A] == 0, 'reset must prohibit stale resume'
        m.m.ram[0x7E6A] = 1
        return m

    def save(name, m, result):
        result.update(case=name, resume=m.m.ram[0x7E6A])
        rows.append(result)
        print(name, 'PASS', flush=True)

    def source(m, data, address=0x3000):
        if address < 0x8000:
            m.m.ram[address:address+len(data)] = data
        else:
            m.m.banks[3][address-0x8000:address-0x8000+len(data)] = data
        m.setword('HIM_AP_SRC_LO', address)

    # Full-span checks, overflow, both destination policies, and unchanged source policy.
    for op, dst, length, expected in [
        (1,0x4000,1,0),(1,0x4FFF,1,0),(1,0x4FFF,2,6),
        (1,0x5000,1,6),(1,0x6FFF,1,6),(1,0x7000,1,0),
        (1,0x7BFF,1,0),(1,0x7BFF,2,6),(1,0x7C00,1,6),
        (5,0x1FFF,1,6),(5,0x2000,1,0),(5,0x4FFF,2,0),
        (5,0x5000,4,0),(5,0x6D6D,1,0),(5,0x6FFF,1,0),
        (5,0x6FFF,2,6),(5,0x7000,1,6),(5,0xFFFF,2,6)]:
        m=make(); data=package(b'\x60'*length); source(m,data)
        m.setword('HIM_AP_DST_LO',dst); m.set('HIM_AP_OP',op)
        before=bytes(m.m.ram)
        r=m.run('HIM_AP_SERVICE')
        assert r['carry']==(expected==0) and r['ap_status']==expected
        if expected:
            assert bytes(m.m.ram[0x2000:0x7C00])==before[0x2000:0x7C00]
        else:
            assert m.m.ram[dst:dst+length]==b'\x60'*length
        assert m.m.ram[0x7E6A] == (0 if op==5 and not expected else 1)
        save(f'load-{op}-dst-{dst:04X}-len-{length}',m,r)

    for address in (0x4FF0,0x5000,0x6FFF,0x1FF0):
        m=make(); source(m,package(),address); m.setword('HIM_AP_DST_LO',0x4000)
        m.set('HIM_AP_OP',5); r=m.run('HIM_AP_SERVICE')
        assert not r['carry'] and r['ap_status']==6 and m.m.ram[0x7E6A]==1
        save(f'source-rejected-{address:04X}',m,r)

    for op in (1,5):
        m=make(); data=package(b'\x60'*4); source(m,data)
        m.setword('HIM_AP_DST_LO',0x3000+len(data)-4); m.set('HIM_AP_OP',op)
        r=m.run('HIM_AP_SERVICE')
        assert not r['carry'] and r['ap_status']==6 and m.m.ram[0x7E6A]==1
        assert bytes(m.m.ram[0x3000:0x3000+len(data)])==data
        save(f'overlap-{op}',m,r)

    for op in (0,2,255):
        m=make(); source(m,package()); m.set('HIM_AP_OP',op)
        r=m.run('HIM_AP_SERVICE')
        assert r['carry']==(op!=255) and m.m.ram[0x7E6A]==1
        save(f'operation-{op}',m,r)

    for kind, name, expected in [(1,b'FNV1A_INIT',0),(2,b'FNV1A_INIT',9),(2,b'T',0)]:
        m=make(); resolved=m.s['FNV1A_INIT']
        if name==b'T':
            record=b'FN\xD6'+fnv(name).to_bytes(4,'little')+b'\x00\xA5'
            m.m.banks[3][0x6F00:0x6F00+len(record)]=record; resolved=0xEF08
        source(m,package(b'\0\0\x60',imports=import_record(kind,name),reloc=b'\x01\x04\0\0\0\0'))
        m.setword('HIM_AP_DST_LO',0x5000); m.set('HIM_AP_OP',5)
        r=m.run('HIM_AP_SERVICE')
        assert r['carry']==(expected==0) and r['ap_status']==expected and m.m.ram[0x7E6A]==0
        assert m.m.ram[0x5002]==0x60
        if not expected: assert m.m.ram[0x5000:0x5002]==word(resolved)
        save(f'typed-import-{kind}-{name.decode()}',m,r)

    # Unsafe sources are rejected before any low memory / overlay / bank writes.
    for address in (0x0200,0x0A00,0x1900,0x1A00,0x4FF0,0x5000,0x7000,0xFEF0):
        m=make(); data=package(exported=True); source(m,data,address)
        m.m.banks[2][:0x1000]=carrier
        m.m.ram[0x7C60]=3; m.m.ram[0x7C62:0x7C64]=word(address)
        m.m.ram[0x7C64:0x7C66]=b'\x01\xA5'; m.set('HIM_AP_OP',4)
        before=bytes(m.m.ram); r=m.run('HIM_AP_SERVICE')
        assert not r['carry'] and r['a']==r['manager_status']==r['ap_status']==0xD4
        assert not r['bank_visits'] and bytes(m.m.ram[0x200:0x7C00])==before[0x200:0x7C00]
        assert m.m.ram[0x7E6A]==1
        save(f'install-unstable-{address:04X}',m,r)

    for name,command,mode,installed,dst in [
        ('absent','APS',2,False,0x4000),('corrupt','APS',2,True,0x4000),
        ('load','AP L B1 8000 5000',1,True,0x5000),
        ('last-byte','AP L B1 8000 6FFF',1,True,0x6FFF),
        ('overlay-rejected','AP L B1 8000 7000',1,True,0x7000),
        ('named','AP L B1 T 5000',1,True,0x5000),
        ('duplicate','AP L B1 T 5000',1,True,0x5000),
        ('duplicate-detail','APS B1 T',2,True,0x5000),
        ('not-found','AP L B1 MISSING 5000',1,True,0x5000),
        ('child-return','AP B1 8000 5000',1,True,0x5000),
        ('install','INSTALL 3000 B1',3,True,0x3000)]:
        m=make(); data=package(exported=True); source(m,data)
        if installed: m.m.banks[2][:0x1000]=carrier
        if name=='corrupt': m.m.banks[2][100]^=1
        if mode!=3: m.m.banks[1][:len(data)]=data
        if name.startswith('duplicate'): m.m.banks[1][0x1000:0x1000+len(data)]=data
        m.m.ram[0x7A00:0x7B00]=(command.encode()+b'\0').ljust(256,b'\0')
        m.m.ram[0x7C60]=mode; m.m.ram[0x7C62:0x7C64]=word(0x3000)
        m.m.ram[0x7C64:0x7C66]=b'\x01\xA5'; m.set('HIM_AP_OP',4)
        r=m.run('HIM_AP_SERVICE',stop=0x200 if mode==3 else None)
        assert m.m.ram[0x7E6A]==0
        if name in ('absent','corrupt'):
            assert not r['carry'] and r['a']==r['ap_status']==r['manager_status']==0xDA
            assert 'APMAN NF' in r['output']
        elif name.startswith('duplicate'):
            assert not r['carry'] and r['manager_status']==0xD2
            assert r['output'].count('APMAN ERR=')==1 and '$D2' in r['output']
        elif name in ('not-found','overlay-rejected'):
            assert not r['carry'] and r['manager_status']==(0xD1 if name=='not-found' else 0xD4)
        elif mode==3:
            assert r['result']=='stopped-before-worker' and m.m.ram[0x7DF0]==5
            assert bytes(m.m.ram[0xA00:0xA00+len(data)])==data
        else: assert r['carry'] and r['manager_status']==0xAC and m.m.ram[dst]==0x60
        save('manager-'+name,m,r)

    # Actual ASM client keeps ordinary LOAD and cannot replace its own UDATA.
    for dst in (0x4000,0x5000):
        m=make(); source(m,package()); base=m.asm['ASM_RELOCATE_BASE_LO']
        m.m.ram[base:base+2]=word(dst); r=m.run('ASM_PACKAGE_LOAD',x=0,y=0x30)
        assert r['carry']==(dst==0x4000) and m.m.ram[0x7E6A]==1
        save(f'asm-client-{dst:04X}',m,r)
    m=make(); source(m,package(exported=True)); base=m.asm['ASMF_ARG0_LO']
    m.m.ram[base:base+2]=word(0x3000)
    m.m.ram[m.asm['ASM_SYM_COUNT']]=3; m.m.ram[m.asm['ASM_FIX_COUNT']]=2
    r=m.run('ASMF_INSTALL_BANK',a=1,stop=m.asm['ASMF_LOOP'])
    assert m.m.ram[m.asm['ASM_SYM_COUNT']]==m.m.ram[m.asm['ASM_FIX_COUNT']]==0
    assert m.m.ram[0x7E6A]==0 and m.m.ram[m.asm['ASM_SESSION_STATE']]==1
    save('asm-install-fresh-session',m,r)
    # A takeover can fill the old $5003 flag byte; ASM S must still refuse.
    m=make(); source(m,package(b'\x01'*4)); m.setword('HIM_AP_DST_LO',0x5000)
    m.set('HIM_AP_OP',5); assert m.run('HIM_AP_SERVICE')['carry']
    m.m.ram[0x7A00:0x7A06]=b'ASM S\0'
    r=m.run(m.asm['START'])
    assert not r['carry'] and r['a']==3 and m.m.ram[0x7E6A]==0
    save('asm-resume-refused-after-takeover',m,r)

    names=['s19/himon-rom-c000.s19','s19/himon-rom-c000.map',
           's19/asm-v1-flash-8000.s19','s19/asm-v1-flash-8000.map',
           's19/apman-7000.s19','s19/apman-7000.map','bin/apman-v1-bank2-8000.bin']
    evidence=dict(scope='host contract regression; no flash writes',top_sha256=sha(top),
                  inputs={n:sha((build/n).read_bytes()) for n in names},
                  tool_sha256=sha(Path(__file__).read_bytes()),cases=rows)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(evidence,indent=2)+'\n')
    print(f'PASS {len(rows)} current contract cases; no flash writes')


if __name__=='__main__': main()
