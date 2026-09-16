"""Freeze the manager boundary slice after its host gates pass; no board access."""
from pathlib import Path
import ast
import difflib
import json
import re
import shutil
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path.insert(0,str(ROOT/'SRC/tools'))
from check_himon_ap_extraction import compare
from report_himon_ap_baseline import sha,report,srecord

assert json.loads((HERE/'qualified.json').read_text())['exit_code']==0
identity=compare(HERE/'baseline',ROOT/'SRC/BUILD')
(HERE/'identity.json').write_text(json.dumps(dict(result='PASS',identical_artifacts=identity,exclusions=[]),indent=2)+'\n')
ledger=report(ROOT/'SRC/BUILD')
assert ledger['himon_totals']==dict(ap=3077,shared=2681,himon=6110)
(HERE/'ledger.json').write_text(json.dumps(ledger,indent=2)+'\n')
memory=srecord(ROOT/'SRC/BUILD/s19/himon-rom-c000.s19')
spans=json.loads((HERE/'inline-spans.json').read_text())
assert sum(row['bytes'] for row in spans)==37
for row in spans:
    assert bytes(memory[a] for a in range(row['start'],row['end_exclusive'])).hex()==row['hex']

for name,count in [('himon-ap-contracts',53),('himon-ap-boundary',13)]:
    result=json.loads((ROOT/f'SRC/BUILD/tmp/{name}.json').read_text())
    assert len(result['cases'])==count
    for path,digest in result['inputs'].items(): assert sha((ROOT/'SRC/BUILD'/path).read_bytes())==digest,path
    shutil.copyfile(ROOT/f'SRC/BUILD/tmp/{name}.json',HERE/(name+'.json'))
boundary=json.loads((HERE/'himon-ap-boundary.json').read_text())
assert len(boundary['negative_boundary_cases'])==5
for name,digest in boundary['source_sha256'].items(): assert sha((ROOT/'SRC'/name).read_bytes())==digest
assert boundary['tool_sha256']==sha((ROOT/'SRC/tools/check_himon_ap_boundary.py').read_bytes())
assert json.loads((HERE/'source-check.json').read_text())['expanded_sequence_identical']
for name in ('check_himon_ap_boundary.py','package_component_releases.py'):
    ast.parse((ROOT/'SRC/tools'/name).read_text())

# Inline ownership must preserve the documented edges and stack estimates.
def content(path):
    return [re.sub(r'^(\s+)\d+(\s+(?:JSR|JMP)\s+)',r'\1\2',line) for line in path.read_text().splitlines()
            if not line.startswith(('Generated:','- Source files scanned:'))]
for name in ('ROUTINE_GRAPH_INSIGHTS.md','HIMON_ROUTINE_TREE.md','STACK_DEPTH_MAP.md','HIMON_EDGE_DUMP.md'):
    assert content(HERE/'generated-before'/name)==content(ROOT/'DOC/GENERATED'/name),name

# Restore only the build's recognized logo stamp side effect.
logo='DOC/branding/logo-r-yors.svg'
old=(HERE/'source'/logo).read_bytes(); actual=(ROOT/logo).read_bytes()
if actual!=old:
    assert actual==old.replace(b'VERSION .0913',b'VERSION .0915'),'Unexpected logo edit'
    (ROOT/logo).write_bytes(old)
allowed={'SRC/AP/ap-manager.inc','SRC/Makefile','SRC/tools/read_himon_source.ps1',
         'SRC/tools/package_component_releases.py','SRC/tools/gen_docs.ps1','SRC/tools/check_himon_ap_boundary.py',
         'DOC/GUIDES/ASM/TEST_PLAN.md','DOC/GUIDES/PLANNING/FOUR_MODULE_PLAN.md'}
changed=[]
for row in json.loads((HERE/'source-manifest.json').read_text()):
    if sha((ROOT/row['path']).read_bytes())!=row['sha256']:
        assert row['path'] in allowed or row['path'].startswith('DOC/GENERATED/'),row['path']
        changed.append(row['path'])
source_paths=[n for n in changed if n.startswith('SRC/')]+[
    'SRC/HIMON/himon-ap-manager-'+n+'.inc' for n in ('source-error','shadow','missing')]
patch=[]
for name in source_paths:
    p=HERE/'source'/name
    before=p.read_text().splitlines(keepends=True) if p.exists() else []
    patch.extend(difflib.unified_diff(before,(ROOT/name).read_text().splitlines(keepends=True),
                                    fromfile='before/'+name,tofile='after/'+name))
(HERE/'manager-boundary-source.patch').write_text(''.join(patch))
summary=dict(result='PASS',identical_artifacts=len(identity),linked_symbols_unchanged=True,
    expanded_instruction_sequence_unchanged=True,inline_adapter_bytes=37,rom_growth=0,ram_growth=0,
    added_calls=0,contract_cases=53,resolver_cases=6,manager_cases=7,bypass_negatives=5,
    nested_manager_cycle_rejected=True,generated_graph_and_stack_estimates_preserved=True,
    all_other_initial_files_preserved=True,board_access=False,existing_files_changed=changed)
(HERE/'verification.json').write_text(json.dumps(summary,indent=2)+'\n')

out=ROOT/'DOC/GUIDES/LOGS/HIMON_AP_MANAGER_BOUNDARY_2026-09-16'
assert not out.exists(),'Preserve frozen evidence; append rather than overwrite'
out.mkdir()
for name in ('qualified.log','qualified.json','identity.json','ledger.json','inline-spans.json',
             'source-check.json','himon-ap-contracts.json','himon-ap-boundary.json','verification.json',
             'manager-boundary-source.patch','build.py','check_source.ps1','finalize.py'):
    shutil.copyfile(HERE/name,out/name)
for name in source_paths:
    p=out/name; p.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(ROOT/name,p)
for row in identity:
    p=out/'artifacts'/row['path']; p.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(ROOT/'SRC/BUILD'/row['path'],p)
files=[dict(path=p.relative_to(out).as_posix(),bytes=p.stat().st_size,sha256=sha(p.read_bytes()))
       for p in sorted(out.rglob('*')) if p.is_file()]
(out/'manifest.json').write_text(json.dumps(dict(scope='HIMON command-shadow/diagnostic ownership; byte-identical host slice',
    board_access=False,artifacts=files),indent=2)+'\n')
print(json.dumps(summary,indent=2))
