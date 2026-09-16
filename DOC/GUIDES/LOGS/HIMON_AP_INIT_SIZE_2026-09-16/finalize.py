"""Freeze successful host, board and reset evidence without touching older logs."""
from pathlib import Path
import binascii
import json
import re
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'SRC/tools'))
from report_himon_ap_baseline import sha

receipts={name:json.loads((HERE/(name+'.json')).read_text()) for name in
          ('host-pass','init-comparison','install','board-tests','physical-tests','isolation')}
assert all(r['result']=='PASS' for r in receipts.values())
for name,count in [('himon-ap-contracts',53),('himon-ap-boundary',13),('apman-size',18)]:
    result=json.loads((HERE/(name+'.json')).read_text())
    assert len(result['cases'])==count
    for path,digest in result['inputs'].items():
        assert sha((ROOT/'SRC/BUILD'/path).read_bytes())==digest,path
assert receipts['init-comparison']['tool_sha256']==sha((ROOT/'SRC/tools/check_himon_ap_init.py').read_bytes())
before=[(HERE/f'before-readback/bank{i}.bin').read_bytes() for i in range(4)]
after=[(HERE/f'final-readback/bank{i}.bin').read_bytes() for i in range(4)]
assert before[:3]==after[:3] and before[3][:0x4000]==after[3][:0x4000]
assert after[3]==(HERE/'installed-b3.bin').read_bytes()
rows=re.findall(rb'B([0-3]) ((?:[89A-F]=[0-9A-F]{4} ){8})',(HERE/'bankaudit.txt').read_bytes())
assert len(rows)==4
for bank,fields in rows:
    for sector,value in re.findall(rb'([89A-F])=([0-9A-F]{4})',fields):
        start=(int(sector,16)-8)*4096
        assert binascii.crc_hqx(after[int(bank)][start:start+4096],0xFFFF)==int(value,16)
sectors=[]
for bank in range(4):
    for sector in range(8,16):
        start=(sector-8)*4096
        a=before[bank][start:start+4096];b=after[bank][start:start+4096]
        sectors.append(dict(bank=bank,sector=f'{sector:X}',changed=a!=b,
                            before_crc=f'{binascii.crc_hqx(a,0xFFFF):04X}',
                            after_crc=f'{binascii.crc_hqx(b,0xFFFF):04X}'))
receipt=dict(result='PASS',himon_bytes=11838,himon_headroom=450,saving=10,
             unchanged_asm_bytes=15235,unchanged_apman_body_bytes=3031,
             clear_cases=1024,parser_comparisons=153,clear_cycle_delta=37,board_cases=receipts['board-tests']['cases'],
             physical_reset=receipts['physical-tests'],sectors=sectors,
             installation=receipts['install'],final_flash_sha256=sha(b''.join(after)),
             final_bank_sha256=[sha(b) for b in after],
             state='HIMON prompt in Bank 3; COM4 closed; no release published')
(HERE/'verification.json').write_text(json.dumps(receipt,indent=2)+'\n')

# Revert only the incidental logo stamp produced by this run from a clean tree.
logo='DOC/branding/logo-r-yors.svg'
original=subprocess.check_output(['git','show','HEAD:'+logo],cwd=ROOT)
actual=(ROOT/logo).read_bytes()
assert actual.replace(b'\r\n',b'\n') in (
    original.replace(b'\r\n',b'\n'),
    original.replace(b'VERSION .0913',b'VERSION .0915').replace(b'\r\n',b'\n'))
if actual.replace(b'\r\n',b'\n') != original.replace(b'\r\n',b'\n'):
    (ROOT/logo).write_bytes((HERE/'logo-before.svg').read_bytes())

out=ROOT/'DOC/GUIDES/LOGS/HIMON_AP_INIT_SIZE_2026-09-16'
out.mkdir(exist_ok=False)
for p in HERE.iterdir():
    if p.is_file():shutil.copy2(p,out/p.name)
for phase in ('before','after'):
    for name in ('s19/himon-rom-c000.s19','s19/himon-rom-c000.map',
                 's19/asm-v1-flash-8000.s19','s19/asm-v1-flash-8000.map',
                 's19/apman-7000.s19','s19/apman-7000.map','bin/apman-v1.ap',
                 'bin/apman-v1-bank2-8000.bin'):
        dest=out/'artifacts'/phase/name;dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(HERE/phase/name,dest)
for phase in ('before','final'):
    for name in ('manifest.json','flash-128k.bin',*[f'bank{i}.bin' for i in range(4)]):
        dest=out/(phase+'-readback')/name;dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(HERE/(phase+'-readback')/name,dest)
files=[dict(path=p.relative_to(out).as_posix(),bytes=p.stat().st_size,sha256=sha(p.read_bytes()))
       for p in sorted(out.rglob('*')) if p.is_file()]
(out/'manifest.json').write_text(json.dumps(dict(scope='Resident HIMON AP initialization size qualification',
    board='COM4 115200 DTR/RTS false',artifacts=files),indent=2)+'\n')
print(json.dumps(receipt,indent=2))
