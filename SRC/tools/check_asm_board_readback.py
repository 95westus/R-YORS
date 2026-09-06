"""Verify complete HIMON Bank-3 dumps; save owner-local, no-overwrite evidence.

No serial or flash writes. Before: verify locked STR8-N non-directory bytes.
After: also require exact ASM payload and preservation of HIMON and all top
bytes except D3's expected active-low installation journal transition.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zlib


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--log', type=Path, required=True)
    parser.add_argument('--top', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--baseline', type=Path)
    parser.add_argument('--asm-s19', type=Path)
    args = parser.parse_args()
    transcript = ''.join(bytes.fromhex(row['hex']).decode('ascii', 'replace')
                         for line in args.log.read_text().splitlines()
                         if (row := json.loads(line)).get('direction') == 'RX')
    rows = {}
    for match in re.finditer(r'(?:^|[\r\n])([0-9A-F]{4}): ((?:[0-9A-F]{2} ){8})\| ((?:[0-9A-F]{2} ){8})\|', transcript):
        address = int(match[1], 16)
        if address == 0x8000:
            rows = {}
        rows[address] = bytes.fromhex(match[2] + match[3])
    assert all(address in rows for address in range(0x8000, 0x10000, 16)), 'incomplete bank dump'
    actual = b''.join(rows[address] for address in range(0x8000, 0x10000, 16))
    top = args.top.read_bytes()
    assert len(top) == 4096
    assert actual[0x7000:0x7FB0] == top[:0xFB0], 'STR8 resident/worker mismatch'
    assert actual[0x7FF0:] == top[0xFF0:], 'STR8 config/vector mismatch'
    if args.baseline:
        before = args.baseline.read_bytes()
        assert len(before) == len(actual)
        assert actual[0x4000:0x7FEC] == before[0x4000:0x7FEC], 'HIMON/top/directory preservation failure'
        assert actual[0x7FF0:] == before[0x7FF0:], 'config/vector preservation failure'
        old = int.from_bytes(before[0x7FEC:0x7FF0], 'little')
        new = int.from_bytes(actual[0x7FEC:0x7FF0], 'little')
        assert old and new == (old & (old - 1) & ((old & (old - 1)) - 1)), 'expected exactly one completed journal pair'
    if args.asm_s19:
        expected = {}
        for line in args.asm_s19.read_text().splitlines():
            raw = bytes.fromhex(line[2:])
            assert len(raw) == raw[0] + 1 and sum(raw) & 255 == 255
            if line.startswith('S1'):
                address = int.from_bytes(raw[1:3], 'big')
                for offset, value in enumerate(raw[3:-1]):
                    assert address + offset not in expected
                    expected[address + offset] = value
        assert set(expected) == set(range(0x8000, 0xC000)), 'ASM payload must be dense 8-B'
        assert actual[:0x4000] == bytes(expected[address] for address in range(0x8000, 0xC000)), 'ASM readback mismatch'
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open('xb') as output:
        output.write(actual)
    for offset in range(0, 0x8000, 0x1000):
        sector = actual[offset:offset + 0x1000]
        print(f'B3:{(offset + 0x8000) >> 12:X} CRC32={zlib.crc32(sector):08X} SHA256={hashlib.sha256(sector).hexdigest().upper()}')
    print('BANK SHA256=' + hashlib.sha256(actual).hexdigest().upper())
    print('D3=' + actual[0x7FE0:0x7FF0].hex().upper())
    print('BOARD READBACK PASS: ' + str(args.out))


if __name__ == '__main__':
    main()
