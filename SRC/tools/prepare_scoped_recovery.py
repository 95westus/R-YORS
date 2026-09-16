"""Prepare offline-only scoped policy/pair recovery bundle; never opens serial."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
STR8 = ROOT.parent / 'STR8-N'
BASE = ROOT / 'DOC/GUIDES/LOGS/SECTOR_ROLES_BOARD_2026-09-16'

def sha(data):
    return hashlib.sha256(data).hexdigest()

def record(kind, address, data=b''):
    raw = bytes((len(data)+3, address >> 8, address & 255)) + data
    return f'S{kind}' + (raw + bytes((~sum(raw) & 255,))).hex().upper()

def write_s19(path, data, address, entry):
    lines = [record(1, address+i, data[i:i+32]) for i in range(0, len(data), 32)]
    path.write_text('\n'.join(lines+[record(9, entry)])+'\n', encoding='ascii')

def read_s19(path):
    memory, entry = {}, None
    for line in path.read_text().splitlines():
        raw = bytes.fromhex(line[2:])
        assert raw[0] == len(raw)-1 and sum(raw) & 255 == 255, path
        assert line[:2] in ('S1', 'S9'), (path, line[:2])
        at = int.from_bytes(raw[1:3], 'big')
        if line[:2] == 'S9':
            assert entry is None and len(raw) == 4
            entry = at
        else:
            assert entry is None
            for i, byte in enumerate(raw[3:-1]):
                assert at+i not in memory
                memory[at+i] = byte
    assert memory and entry is not None
    return memory, entry

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, default=ROOT/'LOCAL/scoped-recovery-20260916')
    args = ap.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    baseline = (BASE/'after-reset/flash-128k.bin').read_bytes()
    assert sha(baseline) == '3266041931068fd5a03db030eaef902be61bf2678fa75f1c559cee6df70741dc'
    top = baseline[-4096:]
    assert top[0xFF0:0xFF3] == bytes.fromhex('FF2FFF')
    inputs = [BASE/'after-reset/flash-128k.bin',
              ROOT/'SRC/BUILD/bin/himon-rom-c000.bin',
              ROOT/'SRC/BUILD/s19/apman-v1-bank2-8000.s19',
              STR8/'tools/top-update/str8n-v1.23-top-update-2000.asm',
              STR8/'tools/bank-maint/str8n-v1.23-bank-maint-rename.inc']
    himon = inputs[1].read_bytes()[0x4000:0x7000]
    assert len(himon) == 12288
    memory, entry = read_s19(inputs[2])
    assert set(memory) == set(range(0x8000, 0x9000)) and entry == 0x8000
    manager = bytes(memory[a] for a in range(0x8000, 0x9000))
    assert b'AM02' in manager and b'AM01' in baseline[0x10000:0x11000]
    payloads = {
        'candidate-himon-b3-c-e': (himon, 0xC000, 0xC000),
        'candidate-am02-b2-8': (manager, 0x8000, 0x8000),
        'rollback-himon-b3-c-e': (baseline[0x1C000:0x1F000], 0xC000, 0xC000),
        'rollback-am01-b2-8': (baseline[0x10000:0x11000], 0x8000, 0x8000),
        'recovery-old-b3-8-e': (baseline[0x18000:0x1F000], 0x8000, 0xC000),
        'recovery-old-b2-8-f': (baseline[0x10000:0x18000], 0x8000, int.from_bytes(baseline[0x17FFC:0x17FFE], 'little')),
        'recovery-new-b3-8-e': (baseline[0x18000:0x1C000]+himon, 0x8000, 0xC000),
        'recovery-new-b2-8-f': (manager+baseline[0x11000:0x18000], 0x8000, int.from_bytes(baseline[0x17FFC:0x17FFE], 'little')),
    }
    paired_top=bytearray(top)
    for bank in (2,3):
        start=0xFBC+16*bank
        for pair in range(16):
            at=start+pair//4;shift=(pair%4)*2
            if (paired_top[at]>>shift)&3==3:
                paired_top[at]&=~(3<<shift);break
        else:raise AssertionError('No complete transaction available in baseline journal')
    (out/'expected-paired-policy-ff-top.bin').write_bytes(paired_top)
    enabled_top=bytearray(paired_top);enabled_top[0xFF2]=0xA6
    (out/'expected-paired-policy-a6-top.bin').write_bytes(enabled_top)
    # Full B2 recovery must carry the backup generation appropriate to the
    # last top update; otherwise it silently restores an older B2:F backup.
    for stage,backup in (('after-a6',paired_top),('after-ff',enabled_top)):
        for version,body in (('old',baseline[0x10000:0x11000]),('new',manager)):
            data=body+baseline[0x11000:0x17000]+backup
            payloads[f'recovery-{version}-b2-8-f-{stage}']=(data,0x8000,int.from_bytes(backup[0xFFC:0xFFE],'little'))
    for name, (data, address, entry) in payloads.items():
        (out/(name+'.bin')).write_bytes(data)
        write_s19(out/(name+'.s19'), data, address, entry)
    (out/'baseline-flash-128k.bin').write_bytes(baseline)
    (out/'baseline-live-top.bin').write_bytes(top)
    (out/'baseline-b2f-backup.bin').write_bytes(baseline[0x17000:0x18000])
    (out/'baseline-b1f-backup.bin').write_bytes(baseline[0xF000:0x10000])
    source = inputs[3].read_text()
    for policy, expected in ((0xA6, 0xFF), (0xFF, 0xA6)):
        folder = out/f'policy-{policy:02x}'
        folder.mkdir()
        target = bytearray(top); target[0xFF2] = policy
        (folder/'top.bin').write_bytes(target)
        include = f'TU_CANDIDATE_SUM EQU ${sum(target)&65535:04X}\n'
        include += '\n'.join(' DB '+','.join(f'${x:02X}' for x in target[i:i+16]) for i in range(0,4096,16))+'\n'
        (folder/'str8n-v1.34-top-image.inc').write_text(include)
        # RAM-only derivative: retain the proven programming/recovery routines.
        # Check roles and transition before backup mutation; unique confirmation.
        guard = f'''TU_PF_SIG1_OK:
                        LDA $FFF0
                        CMP #$FF
                        BNE POLICY_REJECT
                        LDA $FFF1
                        CMP #$2F
                        BNE POLICY_REJECT
                        LDA $FFF2
                        CMP #${expected:02X}
                        BEQ POLICY_ACCEPT
POLICY_REJECT:          JMP TU_PREFLIGHT_FAIL
POLICY_ACCEPT:
'''
        derived = source.replace('TU_PF_SIG1_OK:', guard)
        derived = derived.replace('"STR8-N 1.34 TOP UPDATE"', f'"STR8-N 1.34 POLICY {policy:02X}"')
        derived = derived.replace('"TYPE STR8-N 1.34> "', f'"TYPE POLICY {policy:02X}> "')
        derived = derived.replace('"STR8-N 1.34",0', f'"POLICY {policy:02X}",0')
        (folder/'policy.asm').write_text(derived)
        shutil.copy2(inputs[4], folder/inputs[4].name)
        commands = [
            ['wdc02as','-G','-L','-S','-W','-I','.', '-DSTR8_TOP_EMBED=0',
             '-DSTR8_DIRECTORY_REFRESH=0','-DSTR8_IN65_VERSION_134=1','policy.asm'],
            ['wdcln','-g','-s','-t','-hm19','-j','-o','policy.s19','policy.obj']]
        for command in commands:
            r = subprocess.run(command, cwd=folder, text=True, capture_output=True)
            with (folder/'build.log').open('a') as log:
                log.write(' '.join(command)+'\n'+r.stdout+r.stderr)
            if r.returncode:
                raise RuntimeError((command, r.stdout, r.stderr))
        # Normalize link output to dense S1/S9 with the loader's RAM entry.
        lines = (folder/'policy.s19').read_text().splitlines()
        mem = {}
        for line in lines:
            if line.startswith('S1'):
                raw=bytes.fromhex(line[2:]);assert sum(raw)&255==255
                at=int.from_bytes(raw[1:3],'big')
                for i,x in enumerate(raw[3:-1]):
                    assert at+i not in mem
                    mem[at+i]=x
        assert min(mem)==0x2000 and max(mem)==0x4FFF
        image=bytes(mem.get(a,255) for a in range(0x2000,0x5000))
        assert image[0x2000:]==target
        (folder/'policy.bin').write_bytes(image)
        write_s19(folder/'policy.s19',image,0x2000,0x2000)
    manifest = dict(status='PREPARED; host qualification separate; NOT FLASHED',
        baseline_sha256=sha(baseline), intended_policy='A6 (user selected)',
        inputs={str(p):sha(p.read_bytes()) for p in inputs},
        files={p.relative_to(out).as_posix():sha(p.read_bytes()) for p in sorted(out.rglob('*')) if p.is_file()})
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(out)

if __name__ == '__main__':
    main()
