"""Exercise AM03's integrated RAM/banked AP ownership handoff."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from audit_himon_ap_contracts import ROOT, Machine, fnv, import_record, word
from check_fnv_scope import capsule
from prepare_scoped_recovery import write_s19
from report_himon_ap_baseline import srecord, symbols


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    build = ROOT/'SRC/BUILD'
    himon = symbols(build/'s19/himon-rom-c000.map')
    apman = symbols(build/'s19/apman-7000.map')
    manager = srecord(build/'s19/apman-7000.s19')
    assert min(manager) == 0x6C00 and apman['APMAN_IMAGE_END'] <= 0x7C00
    folder = build/'tmp/fnv-ram-ap-handoff'
    folder.mkdir(parents=True, exist_ok=True)
    private = {
        'HIM_FNV_MATCH_NAME': himon['HIM_FNV_MATCH_NAME'],
        'APMAN_FIND_ENTRY_ROW': apman['APMAN_FIND_ENTRY_ROW'],
        'RAM_AP_FIND': 0x2000,
    }
    (folder/'image-addresses.inc').write_text(
        ''.join(f'{name} EQU ${address:04X}\n' for name, address in private.items()))
    source = ROOT/'SRC/APPS/fnv-ram-ap-handoff-5000.asm'
    (folder/source.name).write_bytes(source.read_bytes())
    logs = []
    for command in (
            ['wdc02as', '-G', '-L', '-S', '-W', source.name],
            ['wdcln', '-g', '-s', '-t', '-hm19', '-j', '-o',
             'fnv-ram-ap-handoff-5000.s19', 'fnv-ram-ap-handoff-5000.obj']):
        run = subprocess.run(command, cwd=folder, capture_output=True, text=True)
        logs.append(run.stdout+run.stderr)
        (folder/'build.log').write_text('\n'.join(logs))
        assert run.returncode == 0, (command, run.stdout, run.stderr)
    legacy = srecord(folder/'fnv-ram-ap-handoff-5000.s19')
    legacy_symbols = symbols(folder/'fnv-ram-ap-handoff-5000.map')
    assert min(legacy) == 0x5000 and max(legacy) < 0x5400
    assert legacy_symbols['RAM_AP_HANDOFF_END'] == max(legacy)+1
    legacy_blob = bytes(legacy[a] for a in range(min(legacy), max(legacy)+1))
    write_s19(build/'s19/fnv-ram-ap-handoff-5000.s19',
              legacy_blob, 0x5000, 0x5000)
    top = (ROOT.parent/'STR8-N/BUILD/v1.35/bin/str8n-v1.35-bank3-f000-ffff.bin').read_bytes()
    cases = []

    def check(label, package=None, banks=(), request=4, ram_enable=1, fmt=1,
              expected_a=0x5A, expected_carry=True, expected_entry=0,
              expected_load=True, expected_enter=None,
              mutate_provider=False, mutate_stage=False, linked_word=None):
        if expected_enter is None:
            expected_enter = expected_load
        m = Machine(build, top)
        m.m.banks[3][0x7FF0:0x7FF3] = bytes([0xFF, 0x2F, 0xA6])
        for bank, sector, data in banks:
            start = (sector-8)*4096
            m.m.banks[bank][start:start+4096] = data.ljust(4096, b'\xFF')
        for address, value in manager.items():
            m.m.ram[address] = value
        m.m.ram[0x3000:0x4000] = b'\xFF'*0x1000
        if package is not None:
            m.m.ram[0x3000:0x3000+len(package)] = package
        m.m.ram[0x1A00:0x1A08] = b'RAMTEST\0'
        card = bytearray(32)
        card[0] = request
        card[3:7] = bytes([0xFF, ram_enable, 0x08, fmt])
        card[7:11] = fnv(b'RAMTEST').to_bytes(4, 'little')
        card[19:22] = word(0x1A00)+bytes([7])
        m.m.ram[0x7D40:0x7D60] = card

        parent = type(m.m)
        class GuardedMemory(parent):
            def __getitem__(self, address):
                if isinstance(address, int) and 0x7F00 <= address < 0x8000:
                    assert address in (0x7FA0, 0x7FEC), (label, 'unexpected I/O read', hex(address))
                return super().__getitem__(address)
            def __setitem__(self, address, value):
                assert not 0x3000 <= address < 0x4000, (label, 'provider write', hex(address))
                if 0x7F00 <= address < 0x8000:
                    assert address in (0x7FA0, 0x7FEC), (label, 'unexpected I/O write', hex(address))
                return super().__setitem__(address, value)
        m.m.__class__ = GuardedMemory

        provider_before = bytes(m.m.ram[0x3000:0x4000])
        prior_step = m.c.step
        finder_calls = 0
        load_seen = False
        entered = False
        injected = False

        def step():
            nonlocal finder_calls, load_seen, entered, injected
            pc = m.c.pc
            assert not 0x0A00 <= pc < 0x1A00, (label, 'stage execution', hex(pc))
            assert not 0x3000 <= pc < 0x4000, (label, 'provider execution', hex(pc))
            if m.m.bank != 3:
                assert pc < 0x8000, (label, 'foreign ROM fetch', m.m.bank, hex(pc))
            if pc == apman['AM03_FIND_COMBINED']:
                finder_calls += 1
                if mutate_provider and finder_calls == 2:
                    m.m.ram[0x3000] = 0
                    injected = True
            if (pc == himon['HIM_AP_SERVICE'] and m.m.ram[0x7E2F] == 1
                    and mutate_stage and not injected):
                m.m.ram[0x0A00+len(package)-1] ^= 0xFF
                injected = True
            if pc == himon['HIM_AP_LOAD_PARSED']:
                load_seen = True
            if load_seen and pc == 0x2000+expected_entry:
                entered = True
                assert bytes(m.m.ram[0x7D40:0x7D60]) == b'\0'*32
                assert bytes(m.m.ram[0x1A00:0x1B00]) == b'\0'*256
                assert bytes(m.m.ram[0x0A00:0x1A00]) == b'\0'*0x1000
                assert bytes(m.m.ram[0x1B00:0x1B20]) == b'\0'*32
            return prior_step()

        m.c.step = step
        result = m.run(apman['AM03_SCOPE_HANDOFF'], limit=12_000_000)
        assert (result['a'], result['carry']) == (expected_a, expected_carry), (label, result)
        assert load_seen == expected_load, (label, 'load', load_seen)
        assert entered == expected_enter, (label, 'entry', entered)
        assert bytes(m.m.ram[0x7D40:0x7D60]) == b'\0'*32
        assert bytes(m.m.ram[0x1A00:0x1B00]) == b'\0'*256
        assert bytes(m.m.ram[0x0A00:0x1A00]) == b'\0'*0x1000
        assert bytes(m.m.ram[0x1B00:0x1B20]) == b'\0'*32
        if not mutate_provider:
            assert bytes(m.m.ram[0x3000:0x4000]) == provider_before
        if mutate_provider or mutate_stage:
            assert injected
        if linked_word is not None:
            assert bytes(m.m.ram[0x2000:0x2002]) == word(linked_word)
        cases.append(dict(case=label, result='PASS', a=f'{result["a"]:02X}',
                          carry=result['carry'], finder_calls=finder_calls,
                          load=load_seen, entered=entered, steps=result['steps']))
        print(label, 'PASS', flush=True)

    basic = capsule(name=b'RAMTEST')
    check('unique-ram-enters-and-returns', basic)
    check('nonzero-entry-offset', capsule(name=b'RAMTEST',
          body=b'\xEA\xEA\xA9\x5A\x38\x60', offset=2), expected_entry=2)
    imported = capsule(name=b'RAMTEST', body=b'\x00\x00\xA9\x5A\x38\x60', offset=2,
                       imports=import_record(1, b'FNV1A_INIT'),
                       reloc=b'\x01\x04\x00\x00\x00\x00')
    check('resident-import-linked-before-entry', imported, expected_entry=2,
          linked_word=himon['FNV1A_INIT'])
    check('unique-banked-enters-and-returns', None, banks=[(2, 9, basic)],
          ram_enable=0)
    check('duplicate-refuses-before-load', basic, banks=[(2, 9, basic)],
          expected_a=0xD2, expected_carry=False, expected_load=False)
    missing = capsule(name=b'RAMTEST', body=b'\x00\x00\xA9\x5A\x38\x60', offset=2,
                      imports=import_record(1, b'NO_SUCH_IMPORT'),
                      reloc=b'\x01\x04\x00\x00\x00\x00')
    check('missing-import-never-enters', missing, expected_a=9,
          expected_carry=False, expected_entry=2, expected_load=True,
          expected_enter=False)
    check('malformed-provider-refuses', basic[:-1]+b'\0', expected_a=0xD1,
          expected_carry=False, expected_load=False)
    check('invalid-card-refuses', basic, fmt=0, expected_a=0xD4,
          expected_carry=False, expected_load=False)
    check('provider-change-between-scans-refuses', basic, expected_a=0xD1,
          expected_carry=False, expected_load=False, mutate_provider=True)
    check('staged-body-change-refuses', basic, expected_a=7,
          expected_carry=False, expected_load=False, mutate_stage=True)
    check('child-carry-and-a-are-preserved', capsule(name=b'RAMTEST',
          body=b'\xA9\xA7\x18\x60'), expected_a=0xA7, expected_carry=False)

    input_paths = ('s19/himon-rom-c000.s19', 's19/apman-7000.s19',
                   's19/fnv-ram-ap-2000.s19',
                   'bin/apman-v1.ap', 'bin/apman-v1-bank2-8000.bin')
    inputs = {name: hashlib.sha256((build/name).read_bytes()).hexdigest()
              for name in input_paths}
    report = dict(result='PASS', implementation='AM03 integrated manager',
                  manager_base='6C00', manager_end=f'{apman["APMAN_IMAGE_END"]:04X}',
                  bytes=len(legacy_blob), end_exclusive=f'{max(legacy)+1:04X}',
                  binary_sha256=hashlib.sha256(legacy_blob).hexdigest(),
                  private_addresses=private,
                  legacy_transient=dict(bytes=len(legacy_blob),
                      end_exclusive=f'{max(legacy)+1:04X}',
                      sha256=hashlib.sha256(legacy_blob).hexdigest(),
                      private_addresses=private),
                  inputs=inputs, tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  cases=cases)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2)+'\n')
    print(f'PASS {len(cases)} AM03 integrated handoff cases', flush=True)


if __name__ == '__main__':
    main()
