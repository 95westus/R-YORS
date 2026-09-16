from pathlib import Path
import hashlib,json,shutil
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=ROOT/'DOC/GUIDES/LOGS/SCOPED_SMOKE_BOARD_2026-09-16'
def sha(data):return hashlib.sha256(data).hexdigest()
for name in ('preflight','paired-verification','enabled-verification','disabled-smoke','enabled-smoke','physical-reset','final-verification'):
 assert json.loads((HERE/(name+'.json')).read_text())['result']=='PASS'
assert (HERE/'final/flash-128k.bin').read_bytes()==(HERE/'enabled/flash-128k.bin').read_bytes()
OUT.mkdir(exist_ok=False)
for p in HERE.iterdir():
 if p.is_dir() and p.name in ('before','paired','enabled','final'):
  shutil.copytree(p,OUT/p.name)
 elif p.is_file():
  if p.suffix=='.log':(OUT/p.name).write_text(p.read_text(encoding='utf-16'),encoding='utf-8')
  else:shutil.copy2(p,OUT/p.name)
receipt=dict(status='PASS: host revalidation, paired installation, A6 provisioning, board smoke, physical reset and final isolation',
 scope='Step 2 with user-authorized on-board smoke; broader scoped acceptance remains open',
 flash_sha256=sha((HERE/'final/flash-128k.bin').read_bytes()),
 changed_sectors=json.loads((HERE/'final-verification.json').read_text())['changed_sectors'],
 roles='FF 2F A6',files={p.relative_to(OUT).as_posix():sha(p.read_bytes()) for p in sorted(OUT.rglob('*')) if p.is_file()})
(OUT/'manifest.json').write_text(json.dumps(receipt,indent=2)+'\n')
for name,digest in receipt['files'].items():assert sha((OUT/name).read_bytes())==digest
print('PASS retained',len(receipt['files']),'evidence hashes; final',receipt['flash_sha256'])
