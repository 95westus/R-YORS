"""Freeze artifacts after the full regression command has exited successfully."""
from pathlib import Path
import json
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'SRC/tools'))
from report_himon_ap_baseline import sha,srecord,symbols

old=HERE/'before';new=ROOT/'SRC/BUILD'
checks=[]
for name in ('himon-c000','himon-rom-c000'):
    a=symbols(old/'s19'/f'{name}.map');b=symbols(new/'s19'/f'{name}.map')
    assert a['_END_DATA']-b['_END_DATA']==20
    checks.append({'image':name,'saving':20,'before_end':a['_END_DATA'],'after_end':b['_END_DATA']})
unchanged=['s19/asm-v1-flash-8000.s19','s19/asm-v1-flash-8000.map',
           's19/apman-7000.s19','s19/apman-7000.map','bin/apman-v1.ap',
           'bin/apman-v1-bank2-8000.bin','s19/apman-v1-bank2-8000.s19']
for name in unchanged:
    assert (old/name).read_bytes()==(new/name).read_bytes(),name
comparison=json.loads((HERE/'ranges-comparison.json').read_text())
assert comparison['result']=='PASS'
assert comparison['inputs']['.s19']==sha((new/'s19/himon-rom-c000.s19').read_bytes())
for name in ('himon-ap-boundary','himon-ap-ranges','himon-ap-contracts','apman-size'):
    shutil.copy2(new/'tmp'/f'{name}.json',HERE/f'{name}.json')
for folder in ('s19','bin'):
    out=HERE/'after'/folder;out.mkdir(parents=True,exist_ok=True)
    for p in (new/folder).iterdir():
        if p.is_file():shutil.copy2(p,out/p.name)
transfer=HERE/'himon-c-e.s19'
shutil.copy2(new/'s19/himon-apv2-bank3-c-e.s19',transfer)
image=srecord(transfer);assert set(image)==set(range(0xC000,0xF000))
rom=srecord(new/'s19/himon-rom-c000.s19')
assert all(image[a]==rom.get(a,255) for a in image)
assert len(json.loads((HERE/'himon-ap-contracts.json').read_text())['cases'])==53
(HERE/'source-change.patch').write_bytes(subprocess.check_output(['git','diff','--','SRC/AP/ap-core.inc','SRC/Makefile','SRC/tools/check_board_s19_identity.ps1'],cwd=ROOT))
shutil.copy2(ROOT/'SRC/AP/ap-core.inc',HERE/'source-after.inc')
shutil.copy2(ROOT/'SRC/tools/check_himon_ap_ranges.py',HERE/'check_himon_ap_ranges.py')
receipt=dict(result='PASS',regression_command='make -C SRC HIMON_VISIBLE_STAMP=0915(2324) asm-test himon-banked-ap-check himon-str8-record-check himon-io-led-check board-s19-check himon-rom-bin',
             regression_log_sha256=sha((HERE/'host-regression.log').read_bytes()),
             packaging_log_sha256=sha((HERE/'packaging-regression.log').read_bytes()),
             initial_failure='Firmware gates passed; final packaging gate retained old $2E5C size. Updated to measured $2E48 and reran board-s19-check/himon-rom-bin.',
             install_sha256=sha(transfer.read_bytes()),measurements=checks,
             unchanged={n:sha((new/n).read_bytes()) for n in unchanged})
(HERE/'host-pass.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2))
