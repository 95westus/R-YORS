from pathlib import Path
import sys,json,hashlib,shutil
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];sys.path.insert(0,str(ROOT/'SRC/tools'))
from report_himon_ap_baseline import srecord
def sha(data):return hashlib.sha256(data).hexdigest()
assert json.loads((HERE/'regression.json').read_text())['result']=='PASS'
assert json.loads((HERE/'isolation.json').read_text())['result']=='PASS'
assert len(json.loads((HERE/'board-results.json').read_text()))==8
baseline=(HERE/'baseline.bin').read_bytes()
assert (HERE/'before/flash-128k.bin').read_bytes()==(HERE/'final/flash-128k.bin').read_bytes()==baseline
identities={}
for name in ('himon-rom-c000','asm-v1-flash-8000'):
 data=srecord(ROOT/f'SRC/BUILD/s19/{name}.s19')
 assert all(baseline[3*32768+a-0x8000]==v for a,v in data.items()),name
 identities[name]=sha(bytes(data[a] for a in sorted(data)))
manager=(ROOT/'SRC/BUILD/bin/apman-v1-bank2-8000.bin').read_bytes()
assert manager==baseline[0x10000:0x11000];identities['apman-v1-bank2-8000']=sha(manager)
host=json.loads((ROOT/'SRC/BUILD/tmp/fnv-ram-ap.json').read_text())
assert host['result']=='PASS' and host['bytes']==476 and len(host['cases'])==43
exports=json.loads((ROOT/'RAM-TRANSIENTS/manifest.json').read_text())
for row in exports['tools']:
 for file,digest in row['files'].items():assert sha((ROOT/'RAM-TRANSIENTS'/file).read_bytes())==digest,file
row=next(r for r in exports['tools'] if r['name']=='fnv-ram-ap-2000')
binary=(ROOT/'RAM-TRANSIENTS/BIN/fnv-ram-ap-2000.bin').read_bytes()
assert sha(binary)==host['binary_sha256'] and len(binary)==476
assert row['image_pins']==dict(inputs=host['inputs'],private_addresses=host['private_addresses'])
for plan in json.loads((HERE/'board-plan.json').read_text()):
 assert (HERE/(plan['name']+'.bin')).read_bytes()[:len(binary)]==binary
(HERE/'export-verification.json').write_text(json.dumps(dict(result='PASS',tools=len(exports['tools']),inspector=row,board_fixtures_match_export=True),indent=2)+'\n')
(HERE/'image-identities.json').write_text(json.dumps(dict(result='PASS',visible_stamp='0915(2324)',exact_installed_images=identities),indent=2)+'\n')
shutil.copy2(ROOT/'SRC/BUILD/tmp/fnv-ram-ap.json',HERE/'final-host.json')
shutil.copytree(ROOT/'SRC/BUILD/tmp/fnv-ram-ap',HERE/'linked')
for source in ('SRC/APPS/fnv-ram-ap-2000.asm','SRC/tools/check_fnv_ram_ap.py','SRC/tools/export_ram_transients.py'):
 shutil.copy2(ROOT/source,HERE/Path(source).name)
for ext,folder in [('a','A'),('s19','S19'),('bin','BIN')]:
 shutil.copy2(ROOT/f'RAM-TRANSIENTS/{folder}/fnv-ram-ap-2000.{ext}',HERE/f'exported-fnv-ram-ap-2000.{ext}')
dest=ROOT/'DOC/GUIDES/LOGS/RAM_AP_UNIQUENESS_2026-09-16';assert not dest.exists()
shutil.copytree(HERE,dest,ignore=shutil.ignore_patterns('__pycache__'))
files={p.relative_to(dest).as_posix():sha(p.read_bytes()) for p in sorted(dest.rglob('*')) if p.is_file()}
(dest/'evidence-manifest.json').write_text(json.dumps(dict(algorithm='SHA256',files=files),indent=2)+'\n')
with (ROOT/'DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md').open('a',encoding='utf-8') as f:
 f.write('\n\n## 2026-09-16 — RAM AP validation and combined uniqueness\n\n[Contract, results and evidence](RAM_AP_UNIQUENESS_2026-09-16.md): 476-byte\nimage-pinned metadata inspector. Forty-three linked-byte host cases, eight\nRAM-only COM4 cases and full asm-test pass. A valid RAM BANKDUMP and B2:A\ncarrier produce duplicate refusal; malformed/disabled RAM and sector masks\nselect the correct unique source. No provider load/link/entry. Provider windows\nand all flash remain exact. Final 128 KiB SHA256:\n`8a9977c675364f95a53b58b23067ba469d3595026064a2530e7c3e9db3096f4b`.\nNo flashing; SPI SRAM/WORK remain deferred. Load/link ownership and command\nentry remain the next separate gate.\n')
print('PASS image/export/board identity checks; archived',len(files),'files')
