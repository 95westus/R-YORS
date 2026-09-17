from pathlib import Path
import hashlib
import json
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def sha(data):
    return hashlib.sha256(data).hexdigest()


host = json.loads((ROOT/'SRC/BUILD/tmp/fnv-ram-ap-handoff.json').read_text())
assert host['result'] == 'PASS' and host['bytes'] == 322 and len(host['cases']) == 11
assert len(json.loads((HERE/'board-results.json').read_text())) == 8
isolation = json.loads((HERE/'isolation.json').read_text())
assert isolation == {'result': 'PASS', 'all_flash_unchanged': True,
                     'sha256': '8a9977c675364f95a53b58b23067ba469d3595026064a2530e7c3e9db3096f4b'}
baseline = (HERE/'baseline.bin').read_bytes()
assert (HERE/'before/flash-128k.bin').read_bytes() == baseline
assert (HERE/'final/flash-128k.bin').read_bytes() == baseline

exports = json.loads((ROOT/'RAM-TRANSIENTS/manifest.json').read_text())
row = next(item for item in exports['tools'] if item['name'] == 'fnv-ram-ap-handoff-5000')
binary = (ROOT/'RAM-TRANSIENTS/BIN/fnv-ram-ap-handoff-5000.bin').read_bytes()
assert sha(binary) == host['binary_sha256']
assert row['image_pins'] == dict(inputs=host['inputs'], private_addresses=host['private_addresses'])
for file, digest in row['files'].items():
    assert sha((ROOT/'RAM-TRANSIENTS'/file).read_bytes()) == digest

(HERE/'regression.json').write_text(json.dumps(dict(
    command="make -C SRC asm-test HIMON_VISIBLE_STAMP='0915(2324)'",
    result='PASS', exit_code=0, safe_handoff_cases=11), indent=2)+'\n')
(HERE/'export-verification.json').write_text(json.dumps(dict(
    result='PASS', exported_tool=row), indent=2)+'\n')
shutil.copy2(ROOT/'SRC/BUILD/tmp/fnv-ram-ap-handoff.json', HERE/'final-host.json')
linked = HERE/'linked'
if linked.exists():
    shutil.rmtree(linked)
shutil.copytree(ROOT/'SRC/BUILD/tmp/fnv-ram-ap-handoff', linked)
for source in ('SRC/APPS/fnv-ram-ap-handoff-5000.asm',
               'SRC/tools/check_fnv_ram_ap_handoff.py',
               'SRC/tools/export_ram_transients.py'):
    shutil.copy2(ROOT/source, HERE/Path(source).name)
for extension, folder in (('a', 'A'), ('s19', 'S19'), ('bin', 'BIN')):
    shutil.copy2(ROOT/f'RAM-TRANSIENTS/{folder}/fnv-ram-ap-handoff-5000.{extension}',
                 HERE/f'exported-fnv-ram-ap-handoff-5000.{extension}')

files = {path.relative_to(HERE).as_posix(): sha(path.read_bytes())
         for path in sorted(HERE.rglob('*'))
         if path.is_file() and path.name != 'evidence-manifest.json'}
(HERE/'evidence-manifest.json').write_text(json.dumps(
    dict(algorithm='SHA256', files=files), indent=2)+'\n')
print('PASS safe handoff evidence sealed:', len(files), 'files')
