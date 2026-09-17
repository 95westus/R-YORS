"""Check linked AP range predicates against address windows and an optional baseline.

No board I/O. Execute actual linked instructions, including shared error exits;
reject writes outside AP scratch. The sweep covers every address high byte,
four low-byte edges, and lengths around each protected boundary and overflow.
"""
import argparse
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'SRC/BUILD/tmp/asm-error-deps'))
from py65.devices.mpu65c02 import MPU
from report_himon_ap_baseline import sha, srecord, symbols


class Memory(list):
    def __init__(self, image):
        super().__init__([0xCC] * 65536)
        for address, value in image.items():
            list.__setitem__(self, address, value)
        self.writes = []

    def __setitem__(self, address, value):
        assert 0x7E20 <= address < 0x7E50, f'Unexpected write ${address:04X}'
        self.writes.append((address, value))
        super().__setitem__(address, value)


class Runner:
    def __init__(self, build):
        stem = build / 's19/himon-rom-c000'
        self.s = symbols(stem.with_suffix('.map'))
        self.memory = Memory(srecord(stem.with_suffix('.s19')))
        self.cpu = MPU(memory=self.memory)
        self.hashes = {suffix: sha(stem.with_suffix(suffix).read_bytes())
                       for suffix in ('.s19', '.map')}

    def run(self, entry, values):
        m, c = self.memory, self.cpu
        list.__setitem__(m, slice(0x7E20, 0x7E50), [0xCC] * 48)
        for name, value in values.items():
            list.__setitem__(m, self.s[name], value)
        # Synthetic caller; the routines themselves must not write the stack.
        list.__setitem__(m, slice(0x1FE, 0x200), [0xFE, 0x1F])
        m.writes.clear()
        c.pc, c.a, c.x, c.y = self.s[entry], 0x59, 0xA6, 0x37
        c.p, c.sp, c.processorCycles = 0x20, 0xFD, 0
        for _ in range(150):
            if c.pc == 0x1FFF:
                assert c.sp == 0xFF
                return (c.a, c.x, c.y, c.p, c.sp,
                        bytes(m[0x7E20:0x7E50]), tuple(m.writes)), c.processorCycles
            c.step()
        raise AssertionError(f'{entry}: instruction limit at ${c.pc:04X}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-dir', type=Path, default=ROOT / 'SRC/BUILD')
    parser.add_argument('--baseline-build', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    current = Runner(args.build_dir)
    previous = Runner(args.baseline_build) if args.baseline_build else None
    counts = {'destination': 0, 'source_base': 0}
    cycle_deltas = []

    def check(kind, entry, values, valid):
        result, cycles = current.run(entry, values)
        assert bool(result[3] & 1) == valid, (entry, values, result)
        status = current.memory[current.s['HIM_AP_STATUS']]
        assert status == (0xCC if valid else 6), (values, status)
        if not valid:
            assert result[0] == 6
        if previous:
            old, old_cycles = previous.run(entry, values)
            assert result == old, (entry, values, old, result)
            cycle_deltas.append(cycles - old_cycles)
        counts[kind] += 1

    for op in (1, 5):
        windows = ((0x2000, 0x7000),) if op == 5 else (
            (0x2000, 0x5000), (0x6C00, 0x7C00))
        for high in range(256):
            for low in (0, 1, 0xFE, 0xFF):
                destination = high * 256 + low
                lengths = {0, 1, 2, 0xFF, 0x100, 0x101, 0x1000, 0xFFFF}
                for end in (0x2000, 0x5000, 0x6C00, 0x7000, 0x7C00, 0x10000):
                    lengths.update(end - destination + delta for delta in (-1, 0, 1)
                                   if 0 <= end - destination + delta <= 0xFFFF)
                for length in sorted(lengths):
                    valid = length > 0 and any(
                        start <= destination and destination + length <= end
                        for start, end in windows)
                    values = dict(HIM_AP_OP=op, HIM_AP_DST_LO=low, HIM_AP_DST_HI=high,
                                  HIM_AP_BODY_LEN_LO=length & 255,
                                  HIM_AP_BODY_LEN_HI=length >> 8)
                    check('destination', 'HIM_AP_LOAD_RANGE_OK', values, valid)

    for high in range(256):
        valid = 0x0A <= high < 0x1A or 0x20 <= high < 0x50 or 0x80 <= high < 0xFF
        check('source_base', 'HIM_AP_SOURCE_BASE_OK', {'HIM_AP_SRC_HI': high}, valid)

    report = dict(result='PASS', cases=counts, inputs=current.hashes,
                  tool_sha256=sha(Path(__file__).read_bytes()))
    if previous:
        report.update(baseline_inputs=previous.hashes,
                      compared='A/X/Y/P/SP, AP scratch bytes and ordered writes',
                      cycle_delta=[min(cycle_deltas), max(cycle_deltas)])
        report['sizes'] = {}
        for start, end in [('HIM_AP_SOURCE_BASE_OK', 'HIM_AP_LOAD_RANGE_OK'),
                           ('HIM_AP_LOAD_RANGE_OK', 'HIM_AP_COPY_BODY_TO_DST')]:
            before = previous.s[end] - previous.s[start]
            after = current.s[end] - current.s[start]
            report['sizes'][start] = dict(before=before, after=after, saving=before-after)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(f'PASS AP ranges: {counts}; baseline comparison={previous is not None}')


if __name__ == '__main__':
    main()
