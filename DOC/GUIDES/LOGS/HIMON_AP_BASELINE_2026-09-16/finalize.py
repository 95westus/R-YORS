"""Freeze baseline comparison/evidence after both builds finish."""
import importlib.util
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('ledger', ROOT / 'SRC/tools/report_himon_ap_baseline.py')
ledger = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ledger)

reports = [ledger.report(HERE / name) for name in ['build-1', 'build-2']]
assert reports[0] == reports[1], 'Rebuild changed measured bytes or artifact hashes'
paths = ['s19/himon-rom-c000.s19', 's19/himon-rom-c000.map',
         's19/asm-v1-flash-8000.s19', 's19/asm-v1-flash-8000.map',
         's19/apman-7000.s19', 's19/apman-7000.map',
         'bin/apman-v1.ap', 'bin/apman-v1-bank2-8000.bin',
         's19/apman-v1-bank2-8000.s19',
         's19/ryors-v1.2-asm-bank3-8-b.s19',
         's19/ryors-v1.2-himon-bank3-c-e.s19',
         's19/ryors-v1.2-himon-asm-bank3-8-e.s19']
compared = []
for name in paths:
    first, second = [(HERE / build / name).read_bytes() for build in ['build-1','build-2']]
    assert first == second, name
    compared.append({'path': name, 'bytes': len(first), 'sha256': ledger.sha(first)})
for build in ['build-1','build-2']:
    (HERE / build / 'components').mkdir(exist_ok=True)
    for name, begin, limit in [('himon-rom-c000',0xC000,0xF000), ('asm-v1-flash-8000',0x8000,0xC000)]:
        memory = ledger.srecord(HERE / build / 's19' / (name+'.s19'))
        data = bytes(memory.get(a,255) for a in range(begin,limit))
        (HERE / build / 'components' / (name+'.bin')).write_bytes(data)

# Exercise integrity failures of the new measurement tool using disposable inputs.
negative = HERE / 'ledger-negative'
for name in paths[:8]:
    dest = negative / name
    dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(HERE / 'build-1' / name, dest)
assert ledger.report(negative) == reports[0]
cases = []
def rejected(name, relative, changed):
    path = negative / relative
    original = path.read_bytes()
    try:
        path.write_bytes(changed(original))
        try:
            ledger.report(negative)
        except ValueError as exc:
            cases.append({'case': name, 'result': 'rejected', 'message': str(exc)})
        else:
            raise AssertionError(name+' incorrectly accepted')
    finally:
        path.write_bytes(original)
rejected('S19 checksum corruption', 's19/himon-rom-c000.s19',
         lambda b: b.replace(b'S113C0004C',b'S113C0004D',1))
rejected('Map span mismatch', 's19/himon-rom-c000.map',
         lambda b: b.replace(b'0000edea _END_DATA',b'0000edeb _END_DATA',1))
rejected('AP package BODY corruption', 'bin/apman-v1.ap',
         lambda b: b[:-1]+bytes([b[-1]^1]))
rejected('Carrier erased-tail corruption', 'bin/apman-v1-bank2-8000.bin',
         lambda b: b[:-1]+b'\x00')

result = {'result':'PASS', 'identical_artifacts':compared,
          'ledger_identical':True, 'negative_checks':cases,
          'generator_sha256':ledger.sha((ROOT/'SRC/tools/report_himon_ap_baseline.py').read_bytes())}
(HERE/'reproducibility.json').write_text(json.dumps(result,indent=2)+'\n')

# Restore only the build-generated branding change to the captured pre-task bytes.
logo = ROOT / 'DOC/branding/logo-r-yors.svg'
saved_logo = HERE / 'source/DOC/branding/logo-r-yors.svg'
assert b'VERSION .0915' in logo.read_bytes()
logo.write_bytes(saved_logo.read_bytes())

out = ROOT / 'DOC/GUIDES/LOGS/HIMON_AP_BASELINE_2026-09-16'
out.mkdir(exist_ok=True)
names = ['environment.json','source-manifest.json','initial.patch','build-1.log','build-1.json',
         'build-2.log','build-2.json','ledger.json','board-verification.json',
         'com4-result.json','com4.jsonl','reproducibility.json',
         'capture.py','probe.py','verify_board.py','finalize.py']
manifest = []
for name in names:
    source = HERE / name
    shutil.copy2(source,out/name)
    manifest.append({'path':name,'bytes':source.stat().st_size,'sha256':ledger.sha(source.read_bytes())})
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'result':'PASS','identical_artifacts':len(compared),'negative_checks':len(cases),
                  'evidence_files':len(names)},indent=2))
