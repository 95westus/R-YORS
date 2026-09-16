"""Account for the APMAN reduction without weakening the extraction identity gate."""
from pathlib import Path
import difflib
import json
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path.insert(0,str(ROOT/'SRC/tools'))
from report_himon_ap_baseline import sha,srecord,symbols,report
from check_himon_ap_extraction import ARTIFACTS

before=HERE/'baseline'
after=ROOT/'SRC/BUILD'
rows=[]
for name in ARTIFACTS:
    old=(before/name).read_bytes(); new=(after/name).read_bytes()
    changed='apman' in name
    assert (old!=new)==changed,name
    rows.append(dict(path=name,changed=changed,before_sha256=sha(old),after_sha256=sha(new),
                     before_file_bytes=len(old),after_file_bytes=len(new)))
bm=symbols(before/'s19/apman-7000.map'); am=symbols(after/'s19/apman-7000.map')
bi=srecord(before/'s19/apman-7000.s19'); ai=srecord(after/'s19/apman-7000.s19')
def blob(memory,start,end):
    return bytes(memory[a] for a in range(start,end))
oldworker=blob(bi,bm['APMAN_WORKER_IMAGE'],bm['APMAN_WORKER_IMAGE_END'])
newworker=blob(ai,am['APMAN_WORKER_IMAGE'],am['APMAN_WORKER_IMAGE_END'])
assert oldworker==newworker and len(newworker)==555
assert len(bi)==3072 and len(ai)==3031
assert am['APMAN_IMAGE_END']==0x7BD7
assert len((before/'bin/apman-v1.ap').read_bytes())-len((after/'bin/apman-v1.ap').read_bytes())==41
assert bm['APMAN_FILL_STAGE_FF']-bm['APMAN_INSTALL_FOUND']-(am['APMAN_FILL_STAGE_FF']-am['APMAN_INSTALL_FOUND'])==19
# Existing fact helper is exactly the old inline operation plus RTS.
oldfacts=blob(bi,bm['APMAN_INSTALL_FOUND'],bm['APMAN_INSTALL_FOUND']+22)
assert blob(ai,am['APMAN_SET_PACKAGE_FACTS'],am['APMAN_SET_PACKAGE_FACTS']+23)==oldfacts+b'\x60'
assert am['APMAN_PRINT_SECTIONS']-am['APMAN_PRINT_CARRIER_SUMMARY']==30
summary=dict(result='PASS',artifacts=rows,identical_resident_artifacts=sum(not r['changed'] for r in rows),
    timestamp_exclusions=[],body_before=3072,body_after=3031,overlay_headroom=41,
    package_before=3118,package_after=3077,carrier_bytes_before=4096,carrier_bytes_after=4096,
    bank3_bytes_saved=0,body_and_envelope_bytes_saved=41,sectors_released=0,
    breakdown=dict(install_facts=19,carrier_summary=22),
    worker_bytes=555,worker_sha256=sha(newworker),persistent_ram_growth=0,
    additional_call_overhead_cycles=12,additional_transient_stack_bytes=2)
(HERE/'measurement.json').write_text(json.dumps(summary,indent=2)+'\n')
(HERE/'ledger.json').write_text(json.dumps(report(after),indent=2)+'\n')
paths=['SRC/APPS/apman-7000.asm','SRC/Makefile','SRC/tools/check_apman_size.py']
patch=[]
for name in paths:
    original=HERE/'source'/name
    old=original.read_text().splitlines(keepends=True) if original.exists() else []
    patch.extend(difflib.unified_diff(old,(ROOT/name).read_text().splitlines(keepends=True),
                                    fromfile='before/'+name,tofile='after/'+name))
(HERE/'size-source.patch').write_text(''.join(patch))
print('PASS 41 bytes saved; 10 resident artifacts exact; carried worker exact; zero sectors released')
