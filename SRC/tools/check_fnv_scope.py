"""Execute scoped lookup and command integration from linked HIMON/APMAN bytes.

The real STR8 selector runs; terminal TX is the only intercepted service.
All flash writes fail. Synthetic policy enrollment is confined to emulator RAM.
"""
import argparse
import json
from pathlib import Path
from audit_himon_ap_contracts import ROOT, Machine, fnv, packed_name, word, import_record
from report_himon_ap_baseline import sha, srecord, symbols


def capsule(name=b'BANKDUMP', body=b'\xA9\x5A\x38\x60', offset=0, flags=0x81,
            hash_name=None, packed=None, imports=b'\0', reloc=b'\0'):
    seal = b'\x01'+word(0x2000)+word(0x2000+len(body))+word(len(body))+fnv(body).to_bytes(4,'little')
    export = bytes([1,flags])+word(offset)+fnv(hash_name or name).to_bytes(4,'little')+bytes([len(name)])+(packed_name(name) if packed is None else packed)
    sections = b''.join(bytes([tag])+word(len(data))+data for tag,data in
                        zip(b'SREIB', [seal,reloc,export,imports,body]))
    return b'AP\x02'+word(len(sections)+5)+sections


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--build-dir',type=Path,default=ROOT/'SRC/BUILD')
    p.add_argument('--output',type=Path,required=True)
    args=p.parse_args()
    top=(ROOT.parent/'STR8-N/BUILD/v1.35/bin/str8n-v1.35-bank3-f000-ffff.bin').read_bytes()
    carrier=(args.build_dir/'bin/apman-v1-bank2-8000.bin').read_bytes()
    cases=[]

    def make(policy=0xA6, manager_bank=2, roles=(0x1E, 0x1F)):
        m=Machine(args.build_dir,top)
        m.m.banks[3][0x7FF2]=policy
        m.m.banks[3][0x7FF0:0x7FF2] = bytes(roles)
        if manager_bank is not None:
            m.m.banks[manager_bank][:0x1000]=carrier
        m.requests=[]; m.stages=[]
        step=m.c.step
        def traced_step():
            if m.c.pc in (0xF010,0x0203):
                m.requests.append(m.c.a)
            if m.c.pc==m.manager['APMAN_STAGE_RAW']:
                m.stages.append((m.m.ram[0xA7],m.m.ram[0xA8]))
            if m.m.bank!=3:
                assert m.c.pc<0x8000, ('foreign-bank fetch',m.c.pc,m.m.bank)
            return step()
        m.c.step=traced_step
        return m

    def install(m, bank, sector, data):
        off=(sector-8)*4096
        m.m.banks[bank][off:off+4096]=data.ljust(4096,b'\xFF')

    def command(m, text, entry='HIM_FNV_FALLBACK', mode=None):
        m.m.ram[0x7A00:0x7B00]=(text.encode()+b'\0').ljust(256,b'\0')
        m.setword('CMDP_PTR_LO',0x7A00+len(text)-len(text.lstrip()))
        if mode is not None:
            m.m.ram[0x7C60]=mode
        # The real dispatcher uses the hash produced by the token parser.
        if entry=='CMD_DISPATCH_HASH':
            m.run('CMD_HASH_TOKEN')
        return m.run(entry,stop=m.s['MAIN_LOOP'] if entry=='CMD_DISPATCH_HASH' else None)

    def save(name,m,r):
        assert m.m.bank==3
        r.update(case=name,selector_requests=m.requests,staged_sectors=m.stages,
                 match_count=m.m.ram[0x7D4B])
        cases.append(r)
        print(name,'PASS',flush=True)

    for policy in (0xFF,0,0xA0,0xA8,0xE6):
        m=make(policy); install(m,2,9,capsule())
        r=command(m,'BANKDUMP')
        assert not m.requests and 'GO ' not in r['output']
        save(f'disabled-{policy:02X}',m,r)

    for bank in (2,1):
        m=make(); install(m,bank,9,capsule())
        r=command(m,'BANKDUMP')
        assert r['carry'] and r['a']==0x5A and r['output']==''
        assert 0 not in m.requests
        assert m.stages[:14]==[(b,s) for b in (2,1) for s in range(0x80,0x100,0x10)
                               if (b,s) not in ((1,0xE0),(1,0xF0))]
        assert m.stages[-1]==(bank,0x90)
        save(f'unique-b{bank}',m,r)

    m=make(); install(m,0,9,capsule())
    r=command(m,'BANKDUMP')
    assert not r['carry'] and r['a']==0xD1 and r['manager_status']==0 and 0 not in m.requests
    save('excluded-b0',m,r)

    m=make(0xA7); install(m,0,9,capsule())
    r=command(m,'BANKDUMP')
    assert r['carry'] and r['a']==0x5A and 0 in m.requests
    save('explicitly-enrolled-b0',m,r)

    for count in (2,3,16):
        m=make()
        locations=[(b,s) for b in (2,1) for s in range(8,16) if (b,s)!=(2,8)]
        # For 16 providers place the manager in B0 and explicitly enroll it.
        if count==16:
            m=make(0xA7,0); locations=[(b,s) for b in (2,1) for s in range(8,16)]
        for b,s in locations[:count]: install(m,b,s,capsule())
        r=command(m,'BANKDUMP')
        assert not r['carry'] and r['a']==0xD2 and r['manager_status']==0
        assert m.m.ram[0x7D4B]==0
        assert r['output'].count('APMAN ERR=')==1 and 'GO ' not in r['output']
        save(f'duplicate-{count}',m,r)

    bad={
        'wrong-kind':capsule(flags=0x82),
        'offset-end':capsule(offset=4),
        'offset-wrap':capsule(offset=0xFFFF),
        'forged-hash':capsule(name=b'NOTDUMPX',hash_name=b'BANKDUMP'),
        'invalid-pack40':capsule(packed=b'\xFF'*6),
        'body-corrupt':capsule()[:-1]+b'\0',
        'truncated-header':b'AP\x02\xFF\xFF',
    }
    for name,data in bad.items():
        m=make(); install(m,2,9,data)
        before=bytes(m.m.ram[0x2000:0x2004])
        r=command(m,'BANKDUMP')
        assert not r['carry'] and 'GO ' not in r['output']
        assert bytes(m.m.ram[0x2000:0x2004])==before
        save(name,m,r)

    for name in (b'T',b'AA',b'ABC',b'FOUR',b'LONG_0123456789?.',b'A'*31):
        m=make(); install(m,2,9,capsule(name=name))
        r=command(m,name.decode())
        assert r['carry'] and r['a']==0x5A, (name, r)
        save('canonical-'+name.decode(),m,r)

    m=make(); install(m,2,9,capsule())
    r=command(m,'BANKDUMP',entry='CMD_DISPATCH_HASH')
    assert r['a']==0x5A and r['output']=='' and 0 not in m.requests
    save('resident-miss-dispatch',m,r)

    m=make(); install(m,2,9,capsule(name=b'FNV1A_INIT'))
    r=command(m,'FNV1A_INIT',entry='CMD_DISPATCH_HASH')
    assert not m.requests and 'GO ' not in r['output']
    save('resident-hit-authoritative',m,r)

    for policy,manager_bank in ((0xA6,0),(0xFF,2)):
        m=make(policy,manager_bank); install(m,1,9,capsule())
        r=command(m,'BANKDUMP')
        assert 'GO ' not in r['output'] and 0 not in m.requests
        save(f'ineligible-manager-{policy:02X}',m,r)

    for text in ('AP L B1 BANKDUMP 5000','AP B0 BANKDUMP'):
        m=make(); install(m,1,9,capsule()); install(m,0,9,capsule())
        r=command(m,text,entry='HIM_APMAN_BOOTSTRAP',mode=1)
        assert 0 not in m.requests
        assert r['carry']==text.startswith('AP L')
        if r['carry']: assert bytes(m.m.ram[0x5000:0x5004])==b'\xA9\x5A\x38\x60'
        save(text,m,r)

    m=make(); install(m,2,9,capsule())
    r=command(m,'   BANKDUMP  ',entry='CMD_DISPATCH_HASH')
    assert r['a']==0x5A and r['output']==''
    save('bare-command-leading-and-trailing-spaces',m,r)

    for offset in (4,0xFFFF):
        m=make(); install(m,1,9,capsule(offset=offset))
        r=command(m,'AP B1 9000 5000',entry='HIM_APMAN_BOOTSTRAP',mode=1)
        assert not r['carry'] and 'GO ' not in r['output']
        save(f'physical-selector-bad-entry-{offset:04X}',m,r)

    # New resident code cannot bootstrap an old policy-unaware AM01 manager.
    m=make(manager_bank=None)
    # A minimal, well-sealed AM01 fixture avoids dependency on local archives.
    install(m,2,8,capsule(name=b'APMAN',body=b'\x80\x04AM01\x60'))
    r=command(m,'BANKDUMP')
    assert not r['carry'] and r['manager_status']==0xDA
    save('reject-policy-unaware-manager',m,r)

    for sector in (14,15):
        m=make(manager_bank=None); install(m,1,sector,carrier)
        r=command(m,'BANKDUMP')
        assert not r['carry'] and r['manager_status']==0xDA
        save(f'bootstrap-protected-b1-{sector:X}',m,r)

    m=make(); install(m,2,9,capsule(body=b'\x20\0\0\x60',imports=import_record(1,b'NO_SUCH_IMPORT'),
                                  reloc=b'\x01\x04\x01\x00\x00\x00'))
    r=command(m,'BANKDUMP')
    assert not r['carry'] and r['a']==9 and r['manager_status']==0 and 'GO ' not in r['output']
    save('import-link-failure-no-entry',m,r)

    m=make(); install(m,2,9,b'FN\xD6'+fnv(b'BANKDUMP').to_bytes(4,'little')+b'\x01\x60')
    r=command(m,'BANKDUMP')
    assert not r['carry'] and 'GO ' not in r['output']
    save('banked-hrec-is-not-an-ap-provider',m,r)

    image=srecord(args.build_dir/'s19/bank-dump-2000.s19')
    sym=symbols(args.build_dir/'s19/bank-dump-2000.map')
    body=bytes(image[a] for a in sorted(image))
    assert len(body)==0x92C and fnv(body)==0xCEF1F837
    names=[b'BIO_FTDI_PUT_CSTR',b'SYS_READ_CSTRING_ECHO_UPPER',b'BIO_FTDI_WRITE_BYTE_BLOCK']
    sites=[sym['PUTS']+1,sym['READ_LINE']+5,sym['PUTC']+1]
    imports=bytes([3])+b''.join(import_record(1,n)[1:] for n in names)
    # AP relocation tables are columnar: kind, site low/high, target low/high.
    offsets=[a-0x2000 for a in sites]
    reloc=bytes([3])+b'\x04'*3+bytes(a&255 for a in offsets)+bytes(a>>8 for a in offsets)+bytes(range(3))+b'\0'*3
    data=capsule(body=body,imports=imports,reloc=reloc)
    assert len(data)==0x9AD
    m=make(); install(m,2,9,data)
    expected=[]
    for name in names:
        m.m.ram[0x3000:0x3004]=fnv(name).to_bytes(4,'little')
        found=m.run('THE_JOIN_EXEC_XY',x=0,y=0x30)
        assert found['carry']
        expected.append(found['x']|(found['y']<<8))
    m.m.ram[0x7A00:0x7A09]=b'BANKDUMP\0';m.setword('CMDP_PTR_LO',0x7A00)
    # Three resident import scans plus full BODY validation exceed the small
    # fixture's five-million-instruction limit (about 5.9 million here).
    r=m.run('HIM_FNV_FALLBACK',stop=0x2000,limit=16_000_000)
    assert m.c.pc==0x2000 and r['output']=='' and 0 not in m.requests
    for site,target in zip(sites,expected):
        assert m.m.ram[site:site+2]==word(target)
    save('real-bankdump-load-link-entry',m,r)

    # Direct private service: actual manager callback, bounded bank/sector masks.
    for request,windows,expected in ((7,2,True),(4,2,True),(2,2,False),
                                     (0,255,False),(255,128,False),(7,0,False)):
        m=make(); install(m,2,9,capsule())
        for address,value in srecord(args.build_dir/'s19/apman-7000.s19').items():
            m.m.ram[address]=value
        for name,value in [('FNV_REQUEST_BANKS',request),('FNV_BANK_WINDOWS',windows),
                           ('FNV_FORMAT',1),('FNV_RAM_ENABLE',0),('FNV_NAME_LEN',8)]:
            m.set(name,value)
        m.setword('FNV_NAME_LO',0x1A00); m.m.ram[0x1A00:0x1A08]=b'BANKDUMP'
        m.setword('FNV_VALIDATE_LO',m.manager['APMAN_SCOPE_CANDIDATE'])
        m.m.ram[0x7C70:0x7C74]=fnv(b'BANKDUMP').to_bytes(4,'little')
        m.m.ram[0x7D47:0x7D4B]=fnv(b'BANKDUMP').to_bytes(4,'little')
        m.set('HIM_AP_OP',6)
        r=m.run('HIM_AP_SERVICE')
        assert r['carry']==expected and 0 not in m.requests
        traversal=[(b,s) for b in (2,1) if request&(1<<b)
                   for s in range(0x80,0x100,0x10) if windows&(1<<((s>>4)-8))
                   and (b,s) not in ((1,0xE0),(1,0xF0))]
        assert m.stages==traversal+([(2,0x90)] if expected else [])
        save(f'masks-{request:02X}-{windows:02X}',m,r)

    for field,value in (('FNV_RAM_ENABLE',1),('FNV_FORMAT',0),('FNV_FORMAT',255)):
        m=make(); m.set('FNV_FORMAT',1); m.set('FNV_RAM_ENABLE',0)
        m.set(field,value); m.set('HIM_AP_OP',6)
        r=m.run('HIM_AP_SERVICE')
        assert not r['carry'] and r['a']==0xD4 and not m.requests
        save(f'unsupported-{field}-{value}',m,r)

    for text in ('BANKDUMP EXTRA','A'*32):
        m=make(); install(m,2,9,capsule())
        r=command(m,text)
        assert not r['carry'] and 'GO ' not in r['output']
        save('bad-command-'+text,m,r)

    for sector in (14,15):
        m=make(); install(m,1,sector,capsule())
        r=command(m,'BANKDUMP')
        assert not r['carry'] and (1,sector<<4) not in m.stages
        save(f'protected-b1-{sector:X}',m,r)

    # A transient restore failure must be retried in RAM before any ROM return.
    m=make(); install(m,2,9,capsule()); prior=m.c.step; injected=[]
    def fail_restore_once():
        if m.stages and not injected and m.c.pc==0x0203 and m.c.a==3:
            injected.append(m.m.bank)
            m.c.p &= ~1
            m.c.pc=(m.c.stPopWord()+1)&0xFFFF
            return
        return prior()
    m.c.step=fail_restore_once
    r=command(m,'BANKDUMP')
    assert injected and not r['carry'] and r['a']==0xD9 and r['manager_status']==0
    assert m.m.bank==3 and 'GO ' not in r['output']
    save('restore-failure-retry-from-ram',m,r)

    # New default removes flash WORK, releases B1:E/F, protects only B2:F.
    for sector in (14,15):
        m=make(roles=(0xFF,0x2F)); install(m,1,sector,capsule())
        r=command(m,'BANKDUMP')
        assert r['carry'] and r['a']==0x5A and r['output']=='' and (2,0xF0) not in m.stages
        assert m.stages[:15]==[(b,s) for b in (2,1) for s in range(0x80,0x100,0x10)
                              if (b,s)!=(2,0xF0)]
        save(f'no-flash-work-released-b1-{sector:X}',m,r)
    m=make(roles=(0xFF,0x2F)); install(m,2,15,capsule())
    r=command(m,'BANKDUMP')
    assert not r['carry'] and (2,0xF0) not in m.stages and 'GO ' not in r['output']
    save('protected-backup-b2-F',m,r)
    m=make(manager_bank=None,roles=(0xFF,0x2F)); install(m,2,15,carrier)
    r=command(m,'BANKDUMP')
    assert not r['carry'] and r['manager_status']==0xDA
    save('bootstrap-protected-backup-b2-F',m,r)

    m=make(roles=(0xFF,0x2F))
    for address,value in srecord(args.build_dir/'s19/apman-7000.s19').items():
        m.m.ram[address]=value
    for bank in range(3):
        for sector in range(8,16):
            m.m.ram[0xA7]=bank; m.m.ram[0xA8]=sector<<4
            r=m.run(m.manager['APMAN_LOCATION_PROTECTED'])
            assert r['carry']==((bank,sector)==(2,15))
    save('new-role-install-guard-all-24-locations',m,r)

    evidence=dict(scope='linked host integration; synthetic enrollment; no board or flash writes',
                  himon_end=m.s['_END_DATA'],manager_end=m.manager['APMAN_IMAGE_END'],
                  inputs={n:sha((args.build_dir/n).read_bytes()) for n in
                          ['s19/himon-rom-c000.s19','s19/apman-7000.s19','bin/apman-v1-bank2-8000.bin']},
                  tool_sha256=sha(Path(__file__).read_bytes()),cases=cases)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(evidence,indent=2)+'\n')
    print(f'PASS {len(cases)} scoped integration cases')


if __name__=='__main__': main()
