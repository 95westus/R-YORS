from pathlib import Path
import json,hashlib,shutil
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
def sha(b):return hashlib.sha256(b).hexdigest()
def save(name,obj):(HERE/name).write_text(json.dumps(obj,indent=2)+'\n')
assert json.loads((HERE/'physical-reset.json').read_text())['result']=='PASS'
actual=(HERE/'final/flash-128k.bin').read_bytes()
expected=(HERE/'10-b2a-bankdump-expected.bin').read_bytes()
before=(HERE/'before/flash-128k.bin').read_bytes()
assert len(actual)==131072 and actual==expected
changed=[f'B{i//8}:{i%8+8:X}' for i in range(32) if actual[i*4096:(i+1)*4096]!=before[i*4096:(i+1)*4096]]
assert changed==['B2:A','B3:F']
assert actual[32768+8192:32768+12288]==b'\xff'*4096
assert actual[-16:-13]==bytes.fromhex('FF 2F A6')
save('final-verification.json',dict(result='PASS',sha256=sha(actual),baseline_sha256=sha(before),changed_sectors=changed,exact_expected=True,b1a_erased=True,roles_policy='FF 2F A6',top_changed_addresses=[f'{0xF000+i:04X}' for i,(a,b) in enumerate(zip(before[-4096:],actual[-4096:])) if a!=b]))
save('operator-observations.json',dict(b2=dict(expected='82 92 A2 B2 C2 D2 E2 then 43',reply='Saw the full expected sequence and 43',result='PASS'),b1=dict(expected='81 91 A1 B1 C1 D1 E1 F1 then 43',first_reply='redo the sequenece',repeat_reply='the sequnce was observed',result='PASS'),physical_reset_reply='done',source='operator replies in this conversation'))
dest=ROOT/'DOC/GUIDES/LOGS/SCOPED_QUALIFICATION_2026-09-16'
assert not dest.exists()
shutil.copytree(HERE,dest,ignore=shutil.ignore_patterns('__pycache__'))
files={p.relative_to(dest).as_posix():sha(p.read_bytes()) for p in sorted(dest.rglob('*')) if p.is_file()}
(dest/'evidence-manifest.json').write_text(json.dumps(dict(algorithm='SHA256',files=files),indent=2)+'\n')
print(json.dumps(dict(result='PASS',files=len(files),sha256=sha(actual),changed_sectors=changed)))
