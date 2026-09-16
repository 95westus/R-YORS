"""Verify and freeze the host-only AP/HIMON boundary slice."""
from pathlib import Path
import ast
import difflib
import hashlib
import json
import shutil
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path.insert(0,str(ROOT/'SRC/tools'))
from check_himon_ap_extraction import compare
from report_himon_ap_baseline import report,markdown,sha

assert json.loads((HERE/'qualified.json').read_text())['exit_code']==0
identity=compare(HERE/'baseline',ROOT/'SRC/BUILD')
(HERE/'identity.json').write_text(json.dumps(dict(result='PASS',identical_artifacts=identity,exclusions=[]),indent=2)+'\n')
ledger=report(ROOT/'SRC/BUILD')
assert ledger['himon_totals']==dict(ap=3077,shared=2681,himon=6110)
provider=[r for r in ledger['himon_ownership'] if r.get('start_symbol')=='HIM_AP_LINK_RESOLVE_SLOT_X']
assert len(provider)==1 and provider[0]['bytes']==71
(HERE/'ledger.json').write_text(json.dumps(ledger,indent=2)+'\n')
(ROOT/'DOC/GENERATED/HIMON_AP_BASELINE.md').write_text(markdown(ledger),encoding='utf-8',newline='\n')

for name,count in [('himon-ap-contracts',53),('himon-ap-boundary',6)]:
    result=json.loads((ROOT/f'SRC/BUILD/tmp/{name}.json').read_text())
    assert len(result['cases'])==count
    for path,digest in result['inputs'].items(): assert sha((ROOT/'SRC/BUILD'/path).read_bytes())==digest,path
    shutil.copyfile(ROOT/f'SRC/BUILD/tmp/{name}.json',HERE/(name+'.json'))
assert json.loads((HERE/'source-check.json').read_text())['expanded_sequence_identical']
for name in ('check_himon_ap_boundary.py','report_himon_ap_baseline.py','package_component_releases.py'):
    ast.parse((ROOT/'SRC/tools'/name).read_text())
contracts=(ROOT/'DOC/GENERATED/ROUTINE_CONTRACTS.md').read_text()
assert 'HIMON/himon-ap-resolver.inc' in contracts and 'HIM_AP_LINK_RESOLVE_SLOT_X' in contracts
assert 'HIM_AP_LINK_RESOLVE_SLOT_X' in (ROOT/'DOC/GENERATED/HIMON_EDGE_DUMP.md').read_text()

# Undo only the identified version-stamp logo side effect, preserving its input.
logo='DOC/branding/logo-r-yors.svg'
old=(HERE/'source'/logo).read_bytes(); actual=(ROOT/logo).read_bytes()
if actual!=old:
    assert actual==old.replace(b'VERSION .0913',b'VERSION .0915'), 'Unexpected logo edit; preserve and inspect'
    (ROOT/logo).write_bytes(old)

allowed={
    'SRC/AP/ap-link.inc','SRC/AP/ap-contract.inc','SRC/Makefile',
    'SRC/tools/read_himon_source.ps1','SRC/tools/package_component_releases.py',
    'SRC/tools/report_himon_ap_baseline.py','DOC/GUIDES/ASM/TEST_PLAN.md',
    'DOC/GUIDES/PLANNING/FOUR_MODULE_PLAN.md',
}
changed=[]
for item in json.loads((HERE/'source-manifest.json').read_text()):
    if sha((ROOT/item['path']).read_bytes())!=item['sha256']:
        assert item['path'] in allowed or item['path'].startswith('DOC/GENERATED/'),item['path']
        changed.append(item['path'])
patch=[]
source_paths=[n for n in changed if n.startswith('SRC/')]+['SRC/HIMON/himon-ap-resolver.inc','SRC/tools/check_himon_ap_boundary.py']
for name in source_paths:
    p=HERE/'source'/name
    old=p.read_text().splitlines(keepends=True) if p.exists() else []
    patch.extend(difflib.unified_diff(old,(ROOT/name).read_text().splitlines(keepends=True),fromfile='before/'+name,tofile='after/'+name))
(HERE/'boundary-source.patch').write_text(''.join(patch))

summary=dict(result='PASS',identical_artifacts=len(identity),linked_symbols_unchanged=True,
    expanded_instruction_sequence_unchanged=True,provider_start='DDA3',provider_end_inclusive='DDE9',provider_bytes=71,
    rom_growth=0,ram_growth=0,additional_wrapper_calls=0,contract_cases=53,resolver_cases=6,
    boundary_negative_cases=2,source_cycle_negative=True,
    source_modified=source_paths,existing_files_changed=changed,
    all_other_initial_files_preserved=True,board_access=False)
(HERE/'verification.json').write_text(json.dumps(summary,indent=2)+'\n')

out=ROOT/'DOC/GUIDES/LOGS/HIMON_AP_BOUNDARY_2026-09-16'
assert not out.exists(),'Preserve frozen evidence; append rather than overwrite'
out.mkdir()
for name in ('qualified.log','qualified.json','identity.json','ledger.json','source-check.json',
             'himon-ap-contracts.json','himon-ap-boundary.json','verification.json','boundary-source.patch',
             'build.py','check_source.ps1','finalize.py'):
    shutil.copyfile(HERE/name,out/name)
for name in source_paths:
    p=out/name; p.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(ROOT/name,p)
for row in identity:
    p=out/'artifacts'/row['path']; p.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(ROOT/'SRC/BUILD'/row['path'],p)
files=[dict(path=p.relative_to(out).as_posix(),bytes=p.stat().st_size,sha256=sha(p.read_bytes()))
       for p in sorted(out.rglob('*')) if p.is_file()]
(out/'manifest.json').write_text(json.dumps(dict(scope='HIMON-owned AP typed-import provider; byte-identical host slice',
    board_access=False,artifacts=files),indent=2)+'\n')
print(json.dumps(summary,indent=2))
