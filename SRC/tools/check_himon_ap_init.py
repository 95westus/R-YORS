"""Check AP parser clearing, guard cells and early failures from linked code.

Optional old/new comparison preserves all non-stack RAM and public results.
X is compared on success; the ABI explicitly makes it volatile on failure.
"""
import argparse
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from audit_himon_ap_contracts import ROOT, MPU, package, word
from report_himon_ap_baseline import sha, srecord, symbols

CLEARED = ('HIM_AP_BODY_LO', 'HIM_AP_BODY_HI', 'HIM_AP_BODY_LEN_LO',
           'HIM_AP_BODY_LEN_HI', 'HIM_AP_RELOC_COUNT', 'HIM_AP_IMPORT_COUNT',
           'HIM_AP_REL_LO', 'HIM_AP_REL_HI', 'HIM_AP_IMPORT_LO', 'HIM_AP_IMPORT_HI')


class Memory(bytearray):
    def __setitem__(self, address, value):
        assert isinstance(address, int) and address < 0x8000, address
        self.writes.add(address)
        super().__setitem__(address, value)


class Runner:
    def __init__(self, build):
        stem = build/'s19/himon-rom-c000'
        self.s = symbols(stem.with_suffix('.map'))
        self.m = Memory([0xCC]*65536)
        for address, value in srecord(stem.with_suffix('.s19')).items():
            bytearray.__setitem__(self.m, address, value)
        self.m.writes = set()
        self.c = MPU(memory=self.m)
        self.inputs = {suffix: sha(stem.with_suffix(suffix).read_bytes())
                       for suffix in ('.s19', '.map')}
        assert [self.s[name] for name in CLEARED[:6]] == list(range(0x7E37, 0x7E3D))
        self.clear_end = self.s.get('HIM_AP_PARSE_CLEAR_DONE', self.s['HIM_AP_PARSE_MIN']+30)

    def reset(self, fill, x):
        bytearray.__setitem__(self.m, slice(0, 0x8000), bytes([fill])*0x8000)
        self.c.a, self.c.x, self.c.y = 0x59, x, 0x37
        self.c.p, self.c.sp, self.c.processorCycles = 0x20, 0xFF, 0
        self.c.pc = self.s['HIM_AP_PARSE_MIN']
        self.m.writes.clear()

    def clear(self, fill, x):
        self.reset(fill, x)
        for _ in range(40):
            if self.c.pc == self.clear_end:
                break
            self.c.step()
        else:
            raise AssertionError('Parser clear block did not finish')
        expected = bytearray([fill])*0x8000
        for name in CLEARED:
            expected[self.s[name]] = 0
        assert self.m[:0x8000] == expected, (fill, x)
        assert self.m.writes == {self.s[name] for name in CLEARED}
        assert (self.c.a, self.c.y, self.c.sp) == (0x59, 0x37, 0xFF)
        return self.c.processorCycles

    def parse(self, source, data, x):
        self.reset(0xA5, x)
        if data:
            assert source+len(data) < 0x8000
            bytearray.__setitem__(self.m, slice(source, source+len(data)), data)
        bytearray.__setitem__(self.m, self.s['HIM_AP_SRC_LO'], source & 255)
        bytearray.__setitem__(self.m, self.s['HIM_AP_SRC_HI'], source >> 8)
        self.c.stPushWord(0x1FFE)
        low = self.c.sp
        for _ in range(2_000_000):
            if self.c.pc == 0x1FFF:
                break
            assert self.m[self.c.pc] != 0, f'Unexpected BRK at {self.c.pc:04X}'
            self.c.step()
            low = min(low, self.c.sp)
        else:
            raise AssertionError('Parser did not return')
        assert self.c.sp == 0xFF
        # Install-result cells adjacent to the loop are not parser outputs.
        assert self.m[0x7E3D:0x7E3F] == b'\xA5\xA5'
        result = dict(a=self.c.a, x=self.c.x, y=self.c.y, p=self.c.p,
                      status=self.m[self.s['HIM_AP_STATUS']], stack_peak=0xFF-low)
        ram = bytes(self.m[:0x100]+self.m[0x200:0x8000])
        writes = self.m.writes-set(range(0x100, 0x200))
        return result, ram, writes


def fixtures():
    for source in (0x0A00, 0x1900, 0x20DC, 0x20DE, 0x37F8):
        for length in (1, 255, 256, 257):
            if source == 0x1900 and length > 1:
                continue
            yield f'valid-{source:04X}-{length}', source, package(bytes([0x60])*length), 0
    yield 'export', 0x3000, package(exported=True), 0
    for source in (0, 0x09FF, 0x1A00, 0x1FFF, 0x4FFF, 0x5000, 0x7FFF, 0xFF00):
        yield f'bad-source-{source:04X}', source, b'', 6
    valid = package(bytes(range(256))+b'\xA5')
    for offset in (0, 1, 2, 5, 6, 8, 15, 16, 17, 18, 31, 32, 34, len(valid)-1):
        data = bytearray(valid); data[offset] ^= 1
        yield f'corrupt-{offset}', 0x3000, data, 7
    for end, status in ((5, 6), (7, 6), (8, 7), (18, 6), (20, 6), (23, 6),
                        (26, 6), (30, 6), (33, 6), (34, 7), (len(valid)-1, 7)):
        data = bytearray(valid[:end]); data[3:5] = word(end)
        yield f'truncated-{end}', 0x3000, data, status


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--build-dir', type=Path, default=ROOT/'SRC/BUILD')
    p.add_argument('--baseline-build', type=Path)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    current = Runner(args.build_dir)
    previous = Runner(args.baseline_build) if args.baseline_build else None
    cycles = set(); deltas = set()
    for fill in (0, 0x55, 0xAA, 0xFF):
        for x in range(256):
            cost = current.clear(fill, x); cycles.add(cost)
            if previous:
                deltas.add(cost-previous.clear(fill, x))
    cases = []
    for name, source, data, status in fixtures():
        for x in (0, 0xA6, 0xFF):
            result, ram, writes = current.parse(source, data, x)
            assert result['status'] == result['a'] == status, (name, result)
            assert bool(result['p'] & 1) == (status == 0), (name, result)
            if status == 0:
                assert result['x'] | (result['y'] << 8) == source
            if previous:
                old, old_ram, old_writes = previous.parse(source, data, x)
                assert ram == old_ram and writes == old_writes, name
                keys = ('a', 'y', 'p', 'status', 'stack_peak') + (('x',) if status == 0 else ())
                assert all(result[k] == old[k] for k in keys), (name, result, old)
                result['baseline_x'] = old['x']
            cases.append(dict(name=name, input_x=x, **result))
    report = dict(result='PASS', clear_cases=1024, clear_cycles=sorted(cycles),
                  inputs=current.inputs, cases=cases,
                  tool_sha256=sha(Path(__file__).read_bytes()))
    if previous:
        report.update(baseline_inputs=previous.inputs, clear_cycle_delta=sorted(deltas),
                      saving=(previous.clear_end-previous.s['HIM_AP_PARSE_MIN'])-
                             (current.clear_end-current.s['HIM_AP_PARSE_MIN']))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2)+'\n')
    print(f'PASS AP initialization: 1024 clear/guard cases, {len(cases)} parser cases; '
          f'baseline comparison={previous is not None}')


if __name__ == '__main__':
    main()
