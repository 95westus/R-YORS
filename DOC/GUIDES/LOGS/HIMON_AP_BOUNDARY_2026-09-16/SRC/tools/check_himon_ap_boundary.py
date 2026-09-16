"""Check AP's catalog boundary and execute the HIMON provider from linked bytes."""
import argparse
import json
from pathlib import Path
import re

from audit_himon_ap_contracts import ROOT, Machine, fnv, import_record, word
from report_himon_ap_baseline import sha

ENTRY = 'HIM_AP_LINK_RESOLVE_SLOT_X'
OWNER = 'HIMON/himon-ap-resolver.inc'


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-dir', type=Path, default=ROOT/'SRC/BUILD')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source = {p.relative_to(ROOT/'SRC').as_posix(): p.read_text()
              for p in (ROOT/'SRC/AP').glob('*.inc')}
    source[OWNER] = (ROOT/'SRC'/OWNER).read_text()
    check_source(source)
    # Prove the architectural gate detects an accidental direct lookup/kind read.
    negatives = []
    for bad in ('JSR THE_JOIN_FIND', 'AND #CMD_HASH_KIND_EXEC'):
        altered = dict(source)
        altered['AP/ap-link.inc'] += '\n                        '+bad+'\n'
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
        result.update(kind=kind,name=name.decode(),slot=slot,resolved=f'{expected:04X}')
        cases.append(result)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    inputs = {name:sha((args.build_dir/name).read_bytes()) for name in
              ('s19/himon-rom-c000.s19','s19/himon-rom-c000.map',
               's19/asm-v1-flash-8000.s19','s19/asm-v1-flash-8000.map')}
    args.output.write_text(json.dumps(dict(result='PASS',inputs=inputs,str8_sha256=sha(top),
        source_sha256={n:sha((ROOT/'SRC'/n).read_bytes()) for n in source},
        tool_sha256=sha(Path(__file__).read_bytes()),negative_boundary_cases=negatives,cases=cases),indent=2)+'\n')
    print('PASS AP catalog boundary; 2 bypass negatives; 6 linked resolver cases')


if __name__ == '__main__':
    main()
