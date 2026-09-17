from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT/'SRC/tools'))
from audit_himon_ap_contracts import Machine, fnv, import_record, word
from check_fnv_scope import capsule
from report_himon_ap_baseline import srecord, symbols


def record(kind, address, data=b''):
    raw = bytes([len(data)+3, address >> 8, address & 255])+data
    return 'S'+kind+(raw+bytes([(~sum(raw)) & 255])).hex().upper()


def write_s19(path, memory, entry):
    addresses = sorted(memory)
    lines = []
    index = 0
    while index < len(addresses):
        start = addresses[index]
        data = bytearray()
        while index < len(addresses) and addresses[index] == start+len(data) and len(data) < 32:
            data.append(memory[addresses[index]])
            index += 1
        lines.append(record('1', start, bytes(data)))
    lines.append(record('9', entry))
    path.write_text('\n'.join(lines)+'\n', encoding='ascii')


for name in ('console.py', 'bank_archive.py', 'bank-stage-2000.s19'):
    shutil.copy2(ROOT/'DOC/GUIDES/LOGS/RAM_AP_UNIQUENESS_2026-09-16'/name, HERE/name)

baseline = (ROOT/'DOC/GUIDES/LOGS/RAM_AP_UNIQUENESS_2026-09-16/final/flash-128k.bin').read_bytes()
(HERE/'baseline.bin').write_bytes(baseline)
host = json.loads((ROOT/'SRC/BUILD/tmp/fnv-ram-ap-handoff.json').read_text())
assert host['result'] == 'PASS'
for name in ('himon-rom-c000', 'asm-v1-flash-8000'):
    assert all(baseline[3*32768+address-0x8000] == value
               for address, value in srecord(ROOT/f'SRC/BUILD/s19/{name}.s19').items())
manager = baseline[2*32768:2*32768+4096]
assert manager == (ROOT/'SRC/BUILD/bin/apman-v1-bank2-8000.bin').read_bytes()

driver = '''                        CHIP 65C02
                        ORG $6000
START:                  CLD
                        STZ $7E31
                        LDA #$40
                        STA $7E32
                        STZ $7E33
                        LDA #$70
                        STA $7E34
                        LDA #$01
                        STA $7E2F
                        JSR AP
                        BCC CAPTURE
                        LDX #$1F
COPY_CARD:              LDA $6200,X
                        STA $7D40,X
                        DEX
                        BPL COPY_CARD
                        STZ $6900
                        JSR $5000
CAPTURE:                STA $6800
                        PHP
                        PLA
                        STA $6801
                        LDA $6900
                        STA $6802
                        LDA $7E30
                        STA $6803
                        RTS
AP:                     JMP ($7E2D)
                        END
'''
(HERE/'driver.asm').write_text(driver)
for command in (['wdc02as', '-G', '-L', '-S', '-W', 'driver.asm'],
                ['wdcln', '-g', '-s', '-t', '-hm19', '-j', '-o', 'driver.s19', 'driver.obj']):
    run = subprocess.run(command, cwd=HERE, capture_output=True, text=True)
    assert run.returncode == 0, (run.stdout, run.stderr)

inspector = srecord(ROOT/'SRC/BUILD/s19/fnv-ram-ap-2000.s19')
handoff = srecord(ROOT/'SRC/BUILD/s19/fnv-ram-ap-handoff-5000.s19')
driver_image = srecord(HERE/'driver.s19')
himon = symbols(ROOT/'SRC/BUILD/s19/himon-rom-c000.map')
zero_check = bytes.fromhex('AD407D0D002F0D000A0D0054D009A9A58D0069A95A3860A9EE1860')
linked = b'\0\0\xA9\xA5\x8D\x00\x69\xA9\x5A\x38\x60'
missing = b'\0\0\xA9\xA5\x8D\x00\x69\xA9\x5A\x38\x60'
fixtures = [
    dict(name='ram-retire-enter-return', wanted=b'RAMTEST', package=capsule(name=b'RAMTEST', body=zero_check),
         request=0, enable=1, a=0x5A, carry=True, marker=0xA5, loaded=zero_check),
    dict(name='ram-import-link-enter', wanted=b'RAMTEST', package=capsule(name=b'RAMTEST', body=linked, offset=2,
         imports=import_record(1, b'FNV1A_INIT'), reloc=b'\x01\x04\x00\x00\x00\x00'),
         request=0, enable=1, a=0x5A, carry=True, marker=0xA5,
         loaded=word(himon['FNV1A_INIT'])+linked[2:]),
    dict(name='bank-aptest-enter-return', wanted=b'APTEST', package=None,
         request=4, enable=0, a=0x5A, carry=True, marker=0),
    dict(name='ram-bank-duplicate-refuses', wanted=b'BANKDUMP', package=capsule(name=b'BANKDUMP'),
         request=4, enable=1, a=0xD2, carry=False, marker=0),
    dict(name='missing-import-never-enters', wanted=b'RAMTEST', package=capsule(name=b'RAMTEST', body=missing, offset=2,
         imports=import_record(1, b'NO_SUCH_IMPORT'), reloc=b'\x01\x04\x00\x00\x00\x00'),
         request=0, enable=1, a=9, carry=False, marker=0, loaded=missing),
    dict(name='malformed-provider-refuses', wanted=b'RAMTEST', package=capsule(name=b'RAMTEST')[:-1]+b'\0',
         request=0, enable=1, a=0xD1, carry=False, marker=0),
    dict(name='invalid-card-refuses', wanted=b'RAMTEST', package=capsule(name=b'RAMTEST'),
         request=0, enable=1, fmt=0, a=0xD4, carry=False, marker=0),
    dict(name='child-clear-carry-return', wanted=b'RAMTEST',
         package=capsule(name=b'RAMTEST', body=bytes.fromhex('A9A58D0069A9A71860')),
         request=0, enable=1, a=0xA7, carry=False, marker=0xA5,
         loaded=bytes.fromhex('A9A58D0069A9A71860')),
]

rows = []
for item in fixtures:
    memory = {**inspector, **handoff, **driver_image}
    memory.update({0x2F00+i: value for i, value in enumerate(item['wanted']+b'\0')})
    memory.update({0x3000+i: 0xFF for i in range(4096)})
    if item['package'] is not None:
        memory.update({0x3000+i: value for i, value in enumerate(item['package'])})
    memory.update({0x4000+i: value for i, value in enumerate(manager)})
    card = bytearray(32)
    card[0] = item['request']
    card[3:7] = bytes([0xFF, item['enable'], 8, item.get('fmt', 1)])
    card[7:11] = fnv(item['wanted']).to_bytes(4, 'little')
    card[19:22] = word(0x2F00)+bytes([len(item['wanted'])])
    memory.update({0x6200+i: value for i, value in enumerate(card)})
    memory.update({0x6800+i: 0 for i in range(0x104)})
    path = HERE/(item['name']+'.s19')
    write_s19(path, memory, 0x6000)

    machine = Machine(ROOT/'SRC/BUILD', baseline[-4096:])
    for bank in range(4):
        machine.m.banks[bank][:] = baseline[bank*32768:(bank+1)*32768]
    for address, value in memory.items():
        machine.m.ram[address] = value
    result = machine.run(0x6000, limit=12_000_000)
    captured = bytes(machine.m.ram[0x6800:0x6804])
    assert (captured[0], bool(captured[1]&1), captured[2]) == (item['a'], item['carry'], item['marker']), (item['name'], captured.hex(), result)
    assert bytes(machine.m.ram[0x3000:0x4000]) == bytes(memory[a] for a in range(0x3000, 0x4000))
    assert bytes(machine.m.ram[0x7D40:0x7D60]) == b'\0'*32
    assert bytes(machine.m.ram[0x2F00:0x2F20]) == b'\0'*32
    assert bytes(machine.m.ram[0x0A00:0x1A00]) == b'\0'*4096
    assert bytes(machine.m.ram[0x5400:0x5410]) == b'\0'*16
    if 'loaded' in item:
        assert bytes(machine.m.ram[0x2000:0x2000+len(item['loaded'])]) == item['loaded']
    row = {key: item[key] for key in ('name', 'a', 'carry', 'marker')}
    row.update(s19_sha256=hashlib.sha256(path.read_bytes()).hexdigest(), capture=captured.hex(),
               provider_sha256=hashlib.sha256(bytes(memory[a] for a in range(0x3000, 0x4000))).hexdigest(),
               loaded=item.get('loaded', b'').hex())
    rows.append(row)
    print(item['name'], 'host rehearsal PASS', flush=True)

(HERE/'board-plan.json').write_text(json.dumps(rows, indent=2)+'\n')
