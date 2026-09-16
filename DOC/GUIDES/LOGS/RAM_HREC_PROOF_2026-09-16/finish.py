from pathlib import Path
import json,hashlib,shutil,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(ROOT/'SRC/tools'))
from report_himon_ap_baseline import srecord
def sha(data):return hashlib.sha256(data).hexdigest()
baseline=(HERE/'baseline.bin').read_bytes()
assert json.loads((HERE/'isolation.json').read_text())['result']=='PASS'
assert len(json.loads((HERE/'board-results.json').read_text()))==7
identities={}
for name in ('himon-rom-c000','asm-v1-flash-8000'):
 data=srecord(ROOT/f'SRC/BUILD/s19/{name}.s19')
 assert all(baseline[3*32768+a-0x8000]==v for a,v in data.items()),name
 identities[name]=sha(bytes(data[a] for a in sorted(data)))
manager=(ROOT/'SRC/BUILD/bin/apman-v1-bank2-8000.bin').read_bytes()
assert manager==baseline[0x10000:0x11000]
identities['apman-v1-bank2-8000']=sha(manager)
host=json.loads((ROOT/'SRC/BUILD/tmp/fnv-ram-hrec.json').read_text())
assert host['result']=='PASS' and host['bytes']==333 and len(host['cases'])==72
assert sha((ROOT/'SRC/APPS/fnv-ram-hrec-2000.asm').read_bytes())==host['source_sha256']
exports=json.loads((ROOT/'RAM-TRANSIENTS/manifest.json').read_text())
for row in exports['tools']:
 for name,h in row['files'].items():assert sha((ROOT/'RAM-TRANSIENTS'/name).read_bytes())==h,name
row=next(r for r in exports['tools'] if r['name']=='fnv-ram-hrec-2000')
assert row['data_bytes']==333 and row['load_address']=='2000' and row['last_address']=='214C'
assert sha((ROOT/'RAM-TRANSIENTS/BIN/fnv-ram-hrec-2000.bin').read_bytes())==host['binary_sha256']
(HERE/'export-verification.json').write_text(json.dumps(dict(result='PASS',tools=len(exports['tools']),inspector=row),indent=2)+'\n')
(HERE/'image-identities.json').write_text(json.dumps(dict(result='PASS',restored_visible_stamp='0915(2324)',exact_installed_images=identities),indent=2)+'\n')
shutil.copy2(ROOT/'SRC/BUILD/tmp/fnv-ram-hrec.json',HERE/'final-host.json')
shutil.copytree(ROOT/'SRC/BUILD/tmp/fnv-ram-hrec',HERE/'linked')
for source in ('SRC/APPS/fnv-ram-hrec-2000.asm','SRC/tools/check_fnv_ram_hrec.py','SRC/tools/export_ram_transients.py'):
 shutil.copy2(ROOT/source,HERE/Path(source).name)
for ext,folder in [('a','A'),('s19','S19'),('bin','BIN')]:
 shutil.copy2(ROOT/f'RAM-TRANSIENTS/{folder}/fnv-ram-hrec-2000.{ext}',HERE/f'exported-fnv-ram-hrec-2000.{ext}')
dest=ROOT/'DOC/GUIDES/LOGS/RAM_HREC_PROOF_2026-09-16'
assert not dest.exists()
shutil.copytree(HERE,dest,ignore=shutil.ignore_patterns('__pycache__'))
files={p.relative_to(dest).as_posix():sha(p.read_bytes()) for p in sorted(dest.rglob('*')) if p.is_file()}
(dest/'evidence-manifest.json').write_text(json.dumps(dict(algorithm='SHA256',files=files),indent=2)+'\n')
with (ROOT/'DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md').open('a',encoding='utf-8') as f:
 f.write('\n\n## 2026-09-16 — initial RAM HREC inspector\n\n[Contract, results and evidence](RAM_HREC_PROOF_2026-09-16.md): 333-byte\nmetadata-only transient, 72 linked-byte host cases and seven RAM-only COM4\ncases pass. Full asm-test passes. Inline/pointer records, confirmation kind,\nduplicates, malformed pointers and disabled/wrong-format requests are covered.\nAll provider windows and the complete 128 KiB flash image remain unchanged.\nFinal flash SHA256: `8a9977c675364f95a53b58b23067ba469d3595026064a2530e7c3e9db3096f4b`.\nNo provider execution or command integration. SPI SRAM is not installed;\nSPI support and WORK allocation remain deferred.\n')
print('PASS final host/export/installed-image identity checks; archived',len(files),'files')
