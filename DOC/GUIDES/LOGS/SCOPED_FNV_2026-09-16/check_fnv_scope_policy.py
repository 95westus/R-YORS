"""Build and exhaustively execute the private scoped-policy W65C02 prototype.

No production firmware, serial access, bank switching or flash writes.
Requires WDC tools and the same py65 dependency as the existing AP checks.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT/'SRC/BUILD/tmp/asm-error-deps'))
from py65.devices.mpu65c02 import MPU
from report_himon_ap_baseline import srecord, sha


class Memory(list):
    def __init__(self):
        super().__init__([0xCC]*65536)
        self.trace = False

    def __setitem__(self, address, value):
        if self.trace:
            assert address in (0x7D40, 0x7D41, 0x7D42), hex(address)
            self.writes.add(address)
        super().__setitem__(address, value)

    def __getitem__(self, address):
        if self.trace and isinstance(address, int):
            assert address in self.code or address in (0x1FE, 0x1FF, 0x7D41), hex(address)
        return super().__getitem__(address)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT/'SRC/BUILD/tmp/fnv-scope-policy.json')
    args = parser.parse_args()
    work = ROOT/'SRC/BUILD/tmp/fnv-scope-policy'
    work.mkdir(parents=True, exist_ok=True)
    fixture = work/'policy.asm'
    fixture.write_text('''                        CHIP 65C02
                        MODULE SCOPE_POLICY_TEST
                        XDEF FNV_SCOPE_POLICY
                        INCLUDE "AP/fnv-scope-card.inc"
                        CODE
                        INCLUDE "AP/fnv-scope-policy.inc"
                        ENDMOD
                        END
''')
    subprocess.run(['wdc02as', '-G', '-L', '-S', '-W', '-I', str(ROOT/'SRC'), 'policy.asm'], cwd=work, check=True)
    subprocess.run(['wdcln', '-g', '-s', '-t', '-c2000', '-hm19', '-j', '-o', 'policy.s19', 'policy.obj'], cwd=work, check=True)
    linked = srecord(work/'policy.s19')
    assert set(linked) == set(range(0x2000, 0x2000+len(linked)))
    memory = Memory()
    memory.code = set(linked)
    for address, value in linked.items():
        memory[address] = value
    # RTS consumes a synthetic caller return and stops at $4000.
    memory[0x1FE], memory[0x1FF] = 0xFF, 0x3F
    cpu = MPU(memory=memory)
    cases = 0
    for policy in range(256):
        # Independent finite oracle: the only accepted encodings are A0-A7.
        allowed = dict(zip(range(0xA0, 0xA8), range(8))).get(policy, 0)
        for request in range(256):
            memory.trace = False
            memory[0x7D40:0x7D43] = [0xCC]*3
            memory.writes = set()
            memory.trace = True
            cpu.pc, cpu.sp, cpu.a, cpu.x, cpu.y, cpu.p = 0x2000, 0xFD, policy, request, 0xCC, 0x30
            for _ in range(20):
                if cpu.pc == 0x4000:
                    break
                assert cpu.pc in linked, hex(cpu.pc)
                cpu.step()
            assert cpu.pc == 0x4000 and cpu.sp == 0xFF
            expected = sum(1 << bank for bank in range(3)
                           if (allowed & (1 << bank)) and (request & (1 << bank)))
            assert cpu.a == expected and cpu.x == request
            assert memory[0x7D40:0x7D43] == [request, allowed, expected]
            assert memory.writes == {0x7D40, 0x7D41, 0x7D42}
            if policy == 0xA6 or (policy & 0xA6) == policy:
                # Every possible additional bit-clear of A6 excludes B0.
                assert not (cpu.a & 1)
            cases += 1
    evidence = dict(scope='host-only W65C02 policy primitive; not firmware integration',
                    cases=cases, linked_bytes=len(linked),
                    linked_sha256=sha(bytes(linked[a] for a in sorted(linked))),
                    sources={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in
                             (ROOT/'SRC/AP/fnv-scope-policy.inc', ROOT/'SRC/AP/fnv-scope-card.inc', Path(__file__))},
                    guarantees=['all policy/request bytes', 'invalid and erased policy disabled',
                                'A6 and every bit-clear exclude B0', 'only three card writes',
                                'no I/O or bank selection', 'balanced RTS and preserved X'])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(evidence, indent=2)+'\n')
    print(f'PASS {cases} linked policy/request cases; {len(linked)} bytes; no board I/O')


if __name__ == '__main__':
    main()
