from pathlib import Path
import hashlib,json,re,shutil,sys
root=Path(__file__).resolve().parents[2]
local=Path(__file__).resolve().parent
build=root/'SRC/BUILD'
str8=root.parent/'STR8-N'
old=root/'DOC/GUIDES/LOGS/SCOPED_RECOVERY_PREP_2026-09-16'
out=root/'DOC/GUIDES/LOGS/SCOPED_HOST_GATES_2026-09-16'
sys.path.insert(0,str(root/'SRC/tools'))
from export_ram_transients import read_s19
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
log=(local/'ryors-host.log').read_text(encoding='utf-16')
strlog=(local/'str8-host.log').read_text(encoding='utf-16')
assert 'ASM v1 smoke checks passed.' in log
assert 'PASS 59 scoped integration cases' in log
assert 'BOARD S19 IDENTITY = PASS' in log
assert 'Traceback' not in log and 'make: ***' not in log
assert 'BANK MAINT ROLE STARTUP: 432 linked cases PASS' in strlog
assert strlog.count('B2:F backup and B3:F recovery PASS')==4
assert 'Traceback' not in strlog and 'make: ***' not in strlog
frozen=json.loads((old/'manifest.json').read_text())
for name,digest in frozen['files'].items():assert sha(old/name)==digest,name
inputs=json.loads((old/'build-manifest.json').read_text())['inputs']
for path,digest in inputs.items():assert sha(Path(path))==digest,('frozen-input-drift',path)
assert (build/'bin/himon-rom-c000.bin').read_bytes()[0x4000:0x7000]==(old/'candidate-himon-b3-c-e.bin').read_bytes()
assert (build/'bin/apman-v1-bank2-8000.bin').read_bytes()==(old/'candidate-am02-b2-8.bin').read_bytes()
scope=json.loads((build/'tmp/fnv-scope.json').read_text())
assert len(scope['cases'])==59 and scope['himon_end']==0xEFF8 and scope['manager_end']==0x7BF3
policy=json.loads((build/'tmp/fnv-scope-policy.json').read_text())
assert policy['cases']==65536
top=str8/'BUILD/v1.34/bin/str8n-v1.34-bank3-f000-ffff.bin'
assert sha(top)=='959c0142d9bf012c13dddba5aa35c5bcfe30c729a4e6370096e899a418b8266a'
assert top.read_bytes()[0xFF0:0xFF3]==bytes.fromhex('FF2FFF')
collection=json.loads((root/'RAM-TRANSIENTS/manifest.json').read_text())
for row in collection['tools']:
 for name,digest in row['files'].items():assert sha(root/'RAM-TRANSIENTS'/name)==digest,name
 mem,entry=read_s19(root/'RAM-TRANSIENTS/S19'/(row['name']+'.s19'))
 start=min(mem);end=max(mem)+1
 assert bytes(mem.get(a,255) for a in range(start,end))==(root/'RAM-TRANSIENTS/BIN'/(row['name']+'.bin')).read_bytes()
 assembly={};cursor=None
 for line in (root/'RAM-TRANSIENTS/A'/(row['name']+'.a')).read_text().splitlines():
  assert len(line)<=63
  line=line.strip()
  if line.startswith('ORG $'):cursor=int(line[5:],16)
  if line.startswith('DB '):
   for token in line[3:].split(','):
    assert cursor not in assembly
    assembly[cursor]=int(token[1:],16);cursor+=1
 assert assembly==mem,row['name']
assert len(collection['tools'])==40
out.mkdir(exist_ok=False)
(out/'ryors-host.log').write_text(log,encoding='utf-8')
(out/'str8-host.log').write_text(strlog,encoding='utf-8')
for p in sorted((build/'tmp').glob('*.json')):
 if p.name.startswith(('fnv-scope','himon-ap-','apman-size')):shutil.copy2(p,out/p.name)
for p,name in [(root/'RAM-TRANSIENTS/manifest.json','ram-transients-manifest.json'),
 (build/'map/himon-rom-c000.map','himon.map'),(build/'s19/apman-7000.map','apman.map'),
 (top,'canonical-top.bin'),(root/'SRC/INTEGRATION/str8n.lock.json','str8n.lock.json'),
 (old/'host-check.json','step1-host-check.json'),(old/'manifest.json','step1-manifest.json')]:shutil.copy2(p,out/name)
for name in ('candidate-himon-b3-c-e.bin','candidate-am02-b2-8.bin'):shutil.copy2(old/name,out/name)
shutil.copy2(__file__,out/'retain.py')
result=dict(status='PASS: step 2 host gates only; NOT FLASHED',build_stamp='0915(2324)',
 checks=dict(asm_test='PASS',board_s19_identity='PASS',policy_cases=65536,scoped_cases=59,
 maintenance_role_cases=432,updater_variants=4,frozen_step1_evidence_cases=33,ram_images=40),
 limits=dict(himon_bytes=12280,himon_end='EFF8',himon_free=8,am02_body_bytes=3059,am02_end='7BF3',am02_free=13),
 frozen_inputs_unchanged=True,canonical_policy='FF',intended_board_policy='A6',board_access=False,
 files={p.name:sha(p) for p in sorted(out.iterdir()) if p.is_file()})
(out/'manifest.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result['checks'],indent=2))
