"""Check AP/HIMON ownership and execute resolver/manager boundaries from linked bytes."""
import argparse
import json
from pathlib import Path
import re

from audit_himon_ap_contracts import ROOT, Machine, fnv, import_record, word, package
from report_himon_ap_baseline import sha

ENTRY = 'HIM_AP_LINK_RESOLVE_SLOT_X'
OWNER = 'HIMON/himon-ap-resolver.inc'
MANAGER_OWNERS = ['HIMON/himon-ap-manager-'+name+'.inc'
                  for name in ('source-error','shadow','missing')]


def check_source(src):
    """Catalog representation belongs to the HIMON adapter, not AP's files."""
    active = {}
    for name, text in src.items():
        code = '\n'.join(line.split(';', 1)[0] for line in text.splitlines())
        active[name] = code
        if name.startswith('AP/'):
            if re.search(r'\b(?:THE_JOIN_\w+|CMD_HASH_\w+)\b', code):
                raise ValueError(f'{name}: AP bypasses the HIMON catalog adapter')
            if re.search(rf'(?m)^{ENTRY}:', code):
                raise ValueError(f'{name}: HIMON resolver implementation moved into AP')
    link = active['AP/ap-link.inc']
    if len(re.findall(rf'(?m)^\s*INCLUDE\s+"{re.escape(OWNER)}"\s*$', link)) != 1:
        raise ValueError('AP link must include exactly one HIMON resolver owner')
    owner = active[OWNER]
    if len(re.findall(rf'(?m)^{ENTRY}:', owner)) != 1:
        raise ValueError('HIMON adapter must provide the existing slot interface')
    manager = active['AP/ap-manager.inc']
    if re.search(r'\b(?:CMD_BUF|HIM_WRITE_HBSTRING|SYS_WRITE_HEX_BYTE|SYS_WRITE_CRLF|MSG_AP_ERR|MSG_APMAN_NF)\b',manager):
        raise ValueError('AP manager bypasses HIMON command-shadow/diagnostic ownership')
    for name in MANAGER_OWNERS:
        if len(re.findall(rf'(?m)^\s*INCLUDE\s+"{re.escape(name)}"\s*$',manager)) != 1 or not active.get(name,'').strip():
            raise ValueError('Missing/duplicated HIMON inline manager adapter: '+name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-dir', type=Path, default=ROOT/'SRC/BUILD')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source = {p.relative_to(ROOT/'SRC').as_posix(): p.read_text()
              for p in (ROOT/'SRC/AP').glob('*.inc')}
    source[OWNER] = (ROOT/'SRC'/OWNER).read_text()
    source.update({name:(ROOT/'SRC'/name).read_text() for name in MANAGER_OWNERS})
    check_source(source)
    # Prove the architectural gate detects an accidental direct lookup/kind read.
    negatives = []
    for filename,bad in [('AP/ap-link.inc','JSR THE_JOIN_FIND'),('AP/ap-link.inc','AND #CMD_HASH_KIND_EXEC'),
                         ('AP/ap-manager.inc','LDA CMD_BUF,X'),('AP/ap-manager.inc','JSR HIM_WRITE_HBSTRING'),
                         ('AP/ap-manager.inc','LDX #<MSG_APMAN_NF')]:
        altered = dict(source)
        altered[filename] += '\n                        '+bad+'\n'
        try:
            check_source(altered)
        except ValueError:
            negatives.append(bad)
        else:
            raise AssertionError('Boundary gate accepted '+bad)

    top = (ROOT.parent/'STR8-N/BUILD/v1.34/bin/str8n-v1.34-bank3-f000-ffff.bin').read_bytes()
    lock = json.loads((ROOT/'SRC/INTEGRATION/str8n.lock.json').read_text())
    assert sha(top).upper() == lock['artifacts']['topSectorSha256']
    cases = []
    for kind, name, slot, success in [
        (1,b'FNV1A_INIT',0,True), (2,b'BOUNDARY_DATA',0,True),
        (2,b'FNV1A_INIT',0,False), (1,b'BOUNDARY_DATA',0,False),
        (1,b'BOUNDARY_ABSENT',0,False), (1,b'FNV1A_INIT',1,True),
    ]:
        m = Machine(args.build_dir,top)
        record = b'FN\xD6'+fnv(b'BOUNDARY_DATA').to_bytes(4,'little')+b'\0\xA5'
        m.m.banks[3][0x6F00:0x6F00+len(record)] = record
        rows = import_record(kind,name)
        if slot:
            # Exercise a variable-length preceding PACK40 name, without resolving it.
            rows = bytes([2])+import_record(1,b'PRECEDING_LONG_NAME')[1:]+rows[1:]
        m.m.ram[0x3000:0x3000+len(rows)] = rows
        m.setword('HIM_AP_IMPORT_LO',0x3000)
        m.setword('HIM_AP_LINK_RES_LO',0xCAFE)
        before = bytes(m.m.ram[0x2000:0x5000])
        result = m.run(ENTRY,x=slot)
        assert result['carry'] == success
        expected = (0xEF08 if name==b'BOUNDARY_DATA' else m.s['FNV1A_INIT']) if success else 0xCAFE
        address = m.s['HIM_AP_LINK_RES_LO']
        assert m.m.ram[address:address+2] == word(expected)
        assert bytes(m.m.ram[0x2000:0x5000]) == before
        assert not result['bank_visits']
        result.update(case_type='resolver',kind=kind,name=name.decode(),slot=slot,resolved=f'{expected:04X}')
        cases.append(result)
    # The entire page, including an early NUL and the last byte, belongs to the
    # shadow contract. Stop before staging so both adjacent redzones are live.
    command = bytes((i*37+11)&255 for i in range(256))
    command = command[:5]+b'\0'+command[6:]
    for mode in (1,2,3):
        m=Machine(args.build_dir,top)
        m.m.ram[0x7A00:0x7B00]=command
        m.m.ram[0x19FF:0x1B01]=b'\xA5'*258
        m.m.ram[0x7E6A]=1
        m.m.ram[0x7C60]=mode
        m.set('HIM_AP_OP',4)
        if mode==3:
            data=package(exported=True)
            m.m.ram[0x3000:0x3000+len(data)]=data
            m.m.ram[0x7C62:0x7C64]=word(0x3000)
        result=m.run('HIM_AP_SERVICE',stop=m.s['HIM_AP_STAGE_BANK_SOURCE'])
        assert result['result']=='stopped-at-caller-boundary' and not result['bank_visits']
        assert m.m.ram[0x1A00:0x1B00]==command and m.m.ram[0x7A00:0x7B00]==command
        assert m.m.ram[0x19FF]==m.m.ram[0x1B00]==0xA5 and m.m.ram[0x7E6A]==0
        result.update(case_type='manager',name=f'whole-command-page-mode-{mode}')
        cases.append(result)
    for address in (0x0A00,0x3000):
        m=Machine(args.build_dir,top)
        m.m.ram[0x7C60]=3
        m.m.ram[0x7C62:0x7C64]=word(address)
        m.m.ram[0x7E6A]=1
        m.set('HIM_AP_OP',4)
        before=bytes(m.m.ram[0x200:0x7C00])
        result=m.run('HIM_AP_SERVICE')
        assert not result['carry'] and result['a']==result['ap_status']==result['manager_status']==0xD4
        assert result['output']=='APERR=$D4\r\n' and not result['bank_visits']
        assert bytes(m.m.ram[0x200:0x7C00])==before and m.m.ram[0x7E6A]==1
        result.update(case_type='manager',name=f'reject-before-shadow-{address:04X}')
        cases.append(result)
    for corrupt in (False,True):
        m=Machine(args.build_dir,top)
        m.m.ram[0x7C60]=2
        m.m.ram[0x7A00:0x7B00]=command
        m.m.ram[0x1B00]=0xA5
        m.m.ram[0x7E6A]=1
        m.set('HIM_AP_OP',4)
        if corrupt:
            m.m.banks[2][:0x1000]=(args.build_dir/'bin/apman-v1-bank2-8000.bin').read_bytes()
            m.m.banks[2][100]^=1
        result=m.run('HIM_AP_SERVICE')
        assert not result['carry'] and result['a']==result['ap_status']==result['manager_status']==0xDA
        assert result['output']=='APMAN NF\r\n'
        assert m.m.ram[0x1A00:0x1B00]==command and m.m.ram[0x7A00:0x7B00]==command
        assert m.m.ram[0x1B00]==0xA5 and m.m.ram[0x7E6A]==0
        result.update(case_type='manager',name='corrupt-manager' if corrupt else 'absent-manager')
        cases.append(result)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    inputs = {name:sha((args.build_dir/name).read_bytes()) for name in
              ('s19/himon-rom-c000.s19','s19/himon-rom-c000.map',
               's19/asm-v1-flash-8000.s19','s19/asm-v1-flash-8000.map',
               's19/apman-7000.map','bin/apman-v1-bank2-8000.bin')}
    args.output.write_text(json.dumps(dict(result='PASS',inputs=inputs,str8_sha256=sha(top),
        source_sha256={n:sha((ROOT/'SRC'/n).read_bytes()) for n in source},
        tool_sha256=sha(Path(__file__).read_bytes()),negative_boundary_cases=negatives,cases=cases),indent=2)+'\n')
    print('PASS AP/HIMON boundaries; 5 bypass negatives; 6 resolver + 7 manager cases')


if __name__ == '__main__':
    main()
