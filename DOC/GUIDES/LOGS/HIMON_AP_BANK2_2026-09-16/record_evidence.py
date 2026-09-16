"""Freeze the completed Bank-2 cycle and append its hardware-log entry once."""
from pathlib import Path
import ast
import binascii
import hashlib
import json
import re
import shutil

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=ROOT/'DOC/GUIDES/LOGS/HIMON_AP_BANK2_2026-09-16'
sha=lambda data:hashlib.sha256(data).hexdigest()

checks={name:json.loads((HERE/(name+'-tests.json')).read_text())
        for name in ('manager','install','fixture','isolation','physical')}
assert sum(map(len,checks.values()))==27
assert json.loads((HERE/'artifact-identity.json').read_text())['result']=='PASS'
for name in ('provision.py','qualify.py','reset_check.py','record_evidence.py'):
    ast.parse((HERE/name).read_text())

before=[(HERE/f'before-readback/bank{bank}.bin').read_bytes() for bank in range(4)]
after=[(HERE/f'final-readback/bank{bank}.bin').read_bytes() for bank in range(4)]
assert before[0]==after[0] and before[1]==after[1]
changed=[0x8000+i for i,(old,new) in enumerate(zip(before[3],after[3])) if old!=new]
assert changed and all(0xFFD0<=addr<=0xFFDF for addr in changed)
assert after[3][:0x7000]==before[3][:0x7000]
assert after[2]==(HERE/'apman-v1-bank2-8000.bin').read_bytes()+(HERE/'aptest-onboard.ap').read_bytes()+b'\xFF'*(0x7000-0x34)

crc_rows=re.findall(rb'B([0-3]) ((?:[89A-F]=[0-9A-F]{4} ){8})',(HERE/'manager-bankaudit.txt').read_bytes())
assert len(crc_rows)==4
for bank,fields in crc_rows:
    for sector,value in re.findall(rb'([89A-F])=([0-9A-F]{4})',fields):
        offset=(int(sector,16)-8)*4096
        assert binascii.crc_hqx(after[int(bank)][offset:offset+4096],0xFFFF)==int(value,16)

# Verify earlier evidence and unrelated user work against their retained hashes.
old=ROOT/'DOC/GUIDES/LOGS/HIMON_AP_CHANGE_2026-09-16'
for item in json.loads((old/'manifest.json').read_text())['artifacts']:
    assert sha((old/item['path']).read_bytes())==item['sha256'],item['path']
old_source={item['path']:item for item in json.loads((ROOT/'LOCAL/himon-ap-change-20260916/source-manifest.json').read_text())}
unrelated=['DOC/GUIDES/ASM/SAMPLES/README.md','DOC/GUIDES/ASM/RTERM_ADVANCED_DEMO.md',
           'DOC/GUIDES/ASM/SAMPLES/rterm-advanced-7000.a','SRC/APPS/rterm-advanced-7000.asm',
           'SRC/tools/build_rterm_demo.py','SRC/tools/check_rterm_demo.py']
for name in unrelated: assert sha((ROOT/name).read_bytes())==old_source[name]['sha256'],name
host=json.loads((ROOT/'SRC/BUILD/tmp/himon-ap-contracts.json').read_text())
assert len(host['cases'])==53
for name,digest in host['inputs'].items(): assert sha((ROOT/'SRC/BUILD'/name).read_bytes())==digest

summary=dict(result='PASS',board_checks=checks,check_count=27,bank3_changed_addresses=[f'{a:04X}' for a in changed],
             bank_audit_crc_fields_matched=32,physical_reset_operator_confirmed=True,
             pending=['operator-observed bank/sector LED values','NMI'],
             final_state='HIMON prompt in Bank 3; COM4 closed',
             prior_contract_artifacts_unchanged=True,unrelated_files_preserved=unrelated)
(HERE/'verification.json').write_text(json.dumps(summary,indent=2)+'\n')

assert not OUT.exists(),'Evidence already frozen; append a new record rather than overwrite'
OUT.mkdir()
files=['inputs.json','provision.py','qualify.py','reset_check.py','record_evidence.py','console.py',
       'bank_archive.py','bank-stage-2000.asm','bank-stage-2000.s19','bank-maint-2000.s19',
       'apman-v1.ap','apman-v1-bank2-8000.bin','apman-v1-bank2-8000.s19',
       'aptest-2000.a','aptest-expected.ap','aptest-onboard.ap','child-return.s19','boundary-sentinel.s19',
       'maintenance-before.txt','maintenance-erased.txt','persistent-inventory.txt','manager-bankaudit.txt',
       'physical-reset.txt','artifact-identity.json','verification.json','serial-com4.jsonl',
       'reclaimed-b3.bin','enrolled-b3.bin',*[name+'-tests.json' for name in checks]]
for name in files: shutil.copyfile(HERE/name,OUT/name)
for phase in ('before','final'):
    for bank in range(4): shutil.copyfile(HERE/f'{phase}-readback/bank{bank}.bin',OUT/f'{phase}-b{bank}.bin')
    shutil.copyfile(HERE/f'{phase}-readback/manifest.json',OUT/f'{phase}-readback.json')
shutil.copyfile(HERE/'erased-readback/bank2.bin',OUT/'erased-b2.bin')
# Preserve helper dependency identities alongside the prior evidence reference.
dependencies=['LOCAL/himon-ap-change-20260916/board.py','SRC/tools/audit_himon_ap_contracts.py',
              'SRC/tools/report_himon_ap_baseline.py']
manifest=dict(scope='Bank-2 persistent APMAN provisioning and board cycle',board_port='COM4',baud=115200,
              check_count=27,dependencies={name:sha((ROOT/name).read_bytes()) for name in dependencies},
              artifacts=[dict(path=p.name,bytes=p.stat().st_size,sha256=sha(p.read_bytes())) for p in sorted(OUT.iterdir())])
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')

log=ROOT/'DOC/GUIDES/LOGS/HARDWARE_TEST_LOG.md'
prefix=log.read_bytes()
entry='''

## 2026-09-16 Persistent APMAN Bank-2 Provisioning And Reset Proof

COM4 reused the operator-authorized temporary BSO2 bank after a fresh full
128K backup. STR8-N 1.34 Bank Maintenance erased B2:8-F and reclaimed D2
through its verified backup/rewrite path. The resident installer enrolled
`A2 APC02` and wrote the exact tested APMAN carrier at B2:$8000, length `$0C2E`.
The real onboard ASM package/install cycle wrote APTEST at B2:$9000, length
`$0034`, then returned to fresh ASM at `$2000` with zero symbol/fixup counts.

Twenty-two workflow/isolation checks passed: persistent inventory/inspection,
manager self guard, missing-name status, linked BANKAUDIT at `$5000`, exact
onboard package/source preservation, exported entry +2, BODY through `$6FFF`,
rejection before a crossing copy, child RTS A=$5A/C=1, stale ASM refusal, and
software W/C recovery. Full final readback matches the two B2 carriers plus
six erased sectors. B0/B1 are unchanged; B3 differs only in D2 identity.
All 32 hardware BANKAUDIT CRC fields match the independently read flash.

The operator pressed physical RESET. Receive-only `RST H` / STR8-N 1.34 /
default warm HIMON `00.0915(2324)` capture and five follow-up checks passed:
resume clearing, rediscovery, APTEST execution, fresh ASM A=$AC/C=1, and
unchanged complete B3 readback. COM4 closed at the HIMON prompt. NMI and the
operator-observed LED gate remain unqualified in this cycle.

Final Bank 2 SHA-256:
`52011800db06a1c13b3c86688f1a55d35e079590e8b92073a11253e82c84fb44`.
Final Bank 3 SHA-256:
`3eead7cab55b85c887eb67ff1720584931d5fee934a099e3c88358029927c533`.
The unchanged 15 build artifacts retain the preceding full host qualification.
No firmware or release changed. The initial prompt/RET harness expectations
were corrected and rerun, with earlier serial runs retained. See the
[board record](HIMON_AP_BANK2_2026-09-16.md) and
[evidence manifest](HIMON_AP_BANK2_2026-09-16/manifest.json).
'''
with log.open('ab') as f: f.write(entry.encode('utf-8'))
assert log.read_bytes()[:len(prefix)]==prefix
receipt=dict(result='PASS',evidence_files=len(manifest['artifacts']),
             hardware_log_preserved_prefix_bytes=len(prefix),hardware_log_preserved_prefix_sha256=sha(prefix))
(HERE/'evidence-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2))
