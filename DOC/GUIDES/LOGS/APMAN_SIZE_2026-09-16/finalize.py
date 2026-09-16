"""Freeze host and board evidence after all gates; preserve previous transcripts."""
from pathlib import Path
import ast
import binascii
import json
import re
import shutil
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path.insert(0,str(ROOT/'SRC/tools'))
from report_himon_ap_baseline import sha

assert json.loads((HERE/'qualified.json').read_text())['exit_code']==0
measurement=json.loads((HERE/'measurement.json').read_text())
focused=json.loads((HERE/'apman-size.json').read_text())
assert measurement['result']==focused['result']=='PASS'
assert len(focused['cases'])==len(focused['baseline_cases'])==18
assert focused['tool_sha256']==sha((ROOT/'SRC/tools/check_apman_size.py').read_bytes())
for name,digest in focused['inputs'].items():
    assert sha((ROOT/'SRC/BUILD'/name).read_bytes())==digest,name
for name,count in [('himon-ap-contracts',53),('himon-ap-boundary',13)]:
    r=json.loads((ROOT/f'SRC/BUILD/tmp/{name}.json').read_text())
    assert len(r['cases'])==count
    for path,digest in r['inputs'].items():
        assert sha((ROOT/'SRC/BUILD'/path).read_bytes())==digest,path
    shutil.copyfile(ROOT/f'SRC/BUILD/tmp/{name}.json',HERE/(name+'.json'))
checks={name:json.loads((HERE/(name+'-tests.json')).read_text())
        for name in ('manager','install','fixture','isolation','physical')}
assert sum(map(len,checks.values()))==27
before=[(HERE/f'before-readback/bank{i}.bin').read_bytes() for i in range(4)]
after=[(HERE/f'final-readback/bank{i}.bin').read_bytes() for i in range(4)]
assert before[:2]==after[:2]
assert before[2][4096:]==after[2][4096:]
assert after[2][:4096]==(HERE/'apman-v1-bank2-8000.bin').read_bytes()
assert [0x8000+i for i,(a,b) in enumerate(zip(before[3],after[3])) if a!=b]==[0xFFDC]
assert before[3][0x7FDC]==0xFC and after[3][0x7FDC]==0xF0
crc_rows=re.findall(rb'B([0-3]) ((?:[89A-F]=[0-9A-F]{4} ){8})',(HERE/'manager-bankaudit.txt').read_bytes())
assert len(crc_rows)==4
for bank,fields in crc_rows:
    for sector,value in re.findall(rb'([89A-F])=([0-9A-F]{4})',fields):
        offset=(int(sector,16)-8)*4096
        assert binascii.crc_hqx(after[int(bank)][offset:offset+4096],0xFFFF)==int(value,16)
oldout=json.loads((HERE/'board-output-before.json').read_text())
newout=json.loads((HERE/'board-output-after.json').read_text())
assert len(oldout)==8
assert {k:v.replace('APC APMAN L=0C2E','APC APMAN L=0C05') for k,v in oldout.items()}==newout

logo='DOC/branding/logo-r-yors.svg'
old=(HERE/'source'/logo).read_bytes(); actual=(ROOT/logo).read_bytes()
if old!=actual:
    assert actual==old.replace(b'VERSION .0913',b'VERSION .0915')
    (ROOT/logo).write_bytes(old)
allowed={'SRC/APPS/apman-7000.asm','SRC/Makefile','DOC/GENERATED/HIMON_AP_BASELINE.md',
    'DOC/GUIDES/ASM/TEST_PLAN.md','DOC/GUIDES/PLANNING/FOUR_MODULE_PLAN.md',
    'DOC/GUIDES/PLANNING/TODO.md','DOC/GUIDES/AP/AP_OIL_GUIDE.md'}
changed=[]
for row in json.loads((HERE/'source-manifest.json').read_text()):
    if sha((ROOT/row['path']).read_bytes())!=row['sha256']:
        assert row['path'] in allowed,row['path']
        changed.append(row['path'])
for name in ['provision.py','qualify.py','reset_check.py','measure.py','finalize.py']:
    ast.parse((HERE/name).read_text())
summary=dict(result='PASS',size=measurement,board_checks=checks,
    board_workflow_checks=27,board_exact_output_comparisons=8,hardware_crc_fields=32,
    physical_reset=True,changed_bank3_addresses=['FFDC'],
    preserved=['Banks 0 and 1','Bank 2 sectors 9-F','all Bank 3 bytes except D2 journal FFDC',
               'all earlier transcripts and unrelated initial files'],
    changed_initial_files=changed,final_bank_sha256=[sha(b) for b in after],
    final_flash_sha256=sha(b''.join(after)),pending=['visual LED acceptance','NMI'],
    final_state='HIMON prompt in Bank 3; COM4 closed')
(HERE/'verification.json').write_text(json.dumps(summary,indent=2)+'\n')

out=ROOT/'DOC/GUIDES/LOGS/APMAN_SIZE_2026-09-16'
assert not out.exists(),'Keep frozen evidence intact; use a new record for later work'
out.mkdir()
names=['qualified.log','qualified.json','measurement.json','ledger.json','size-source.patch',
    'apman-size.json','himon-ap-contracts.json','himon-ap-boundary.json','verification.json',
    'build.py','provision.py','qualify.py','reset_check.py','measure.py','finalize.py',
    'console.py','bank_archive.py','bank-stage-2000.asm','bank-stage-2000.s19','bank-maint-2000.s19',
    'prepared.json','install-started.json','fixture-erase-started.json','fixture-install-started.json',
    'board-output-before.json','board-output-after.json','persistent-inventory.txt','manager-bankaudit.txt',
    'physical-reset.txt','serial-com4.jsonl','aptest-2000.a','aptest-expected.ap','aptest-onboard.ap',
    'child-return.s19','boundary-sentinel.s19','enrolled-b3.bin',
    *[name+'-tests.json' for name in checks]]
for name in names: shutil.copyfile(HERE/name,out/name)
for row in measurement['artifacts']:
    for phase,base in [('before',HERE/'baseline'),('after',ROOT/'SRC/BUILD')]:
        dest=out/'artifacts'/phase/row['path'];dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(base/row['path'],dest)
for phase in ('before','final'):
    for i in range(4): shutil.copyfile(HERE/f'{phase}-readback/bank{i}.bin',out/f'{phase}-b{i}.bin')
    shutil.copyfile(HERE/f'{phase}-readback/manifest.json',out/f'{phase}-readback.json')
for name in ('SRC/APPS/apman-7000.asm','SRC/tools/check_apman_size.py',
             'SRC/tools/audit_himon_ap_contracts.py','SRC/tools/report_himon_ap_baseline.py',
             'SRC/tools/build_ap_fixed_package.ps1','SRC/BUILD/inc/apman-str8-worker.inc'):
    dest=out/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,dest)
files=[dict(path=p.relative_to(out).as_posix(),bytes=p.stat().st_size,sha256=sha(p.read_bytes()))
       for p in sorted(out.rglob('*')) if p.is_file()]
(out/'manifest.json').write_text(json.dumps(dict(scope='Measured APMAN reduction and COM4 qualification',
    board_port='COM4',baud=115200,artifacts=files),indent=2)+'\n')

log=ROOT/'DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md'
prefix=log.read_bytes()
entry='''

## 2026-09-16 APMAN 41-byte Size Reduction And Reset Proof

The reduced manager is installed at B2:8: BODY `$0BD7` (3,031), end `$7BD7`
exclusive, envelope `$0C05` (3,077), with 41 bytes free below `$7C00`.
Full host regression, 18 old/new linked differential cases, ten unchanged
resident artifacts and the unchanged 555-byte carried worker pass.

COM4 passed eight exact before/after output comparisons (only the manager's
self-length differs), 27 workflow/isolation/reset checks, and all 32 BANKAUDIT
CRC comparisons. STR8 I replaced B2:8; Bank Maintenance erased the retained
APTEST test sector B2:9, then real ASM PACKAGE/INSTALL reproduced it exactly
through reduced APMAN and returned to a fresh session. All four banks were
read back. B0/B1 and B2:9-F match the fresh backup; B3 differs only at `$FFDC`
(`$FC->$F0`, the D2 installation journal). HIMON/ASM/STR8 code is unchanged.

Receive-only physical RESET capture proves `RST H`, STR8-N 1.34, warm HIMON, persistent
manager/fixture discovery, APTEST execution, and fresh ASM A=$AC/C=1. COM4
closed at the HIMON prompt. LED visual acceptance and NMI remain separate.
See [the qualification record](APMAN_SIZE_2026-09-16.md) and its
[hashed evidence](APMAN_SIZE_2026-09-16/manifest.json). No release was published.
'''
log.write_bytes(prefix+entry.encode())
assert log.read_bytes()[:len(prefix)]==prefix
print(json.dumps(dict(result='PASS',evidence_files=len(files),board_checks=35,
    final_bank_sha256=summary['final_bank_sha256'],final_flash_sha256=summary['final_flash_sha256']),indent=2))
