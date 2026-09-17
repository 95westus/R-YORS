"""Archive flash read-only through HIMON L/G/D on COM4; never installs flash.

Example: python bank_archive.py --out ../board/before --banks 0 1 2 3
Run only while HIMON's prompt is active in Bank 3. Each sector staging call
returns to HIMON after restoring Bank 3. Avoid NMI/RESET during staging.
"""

import argparse
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
HELPER = HERE / 'bank-stage-2000.s19'
LOG = HERE / 'serial-com4.jsonl'
PROMPT = r'\r\n>$'


def get_board_class():
    path = ROOT / 'SRC/BUILD/tmp/himon-size-board/console.py'
    spec = importlib.util.spec_from_file_location('bso2_board_console', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.LOG = LOG
    return module.Board


def srecord(kind, address, data=b''):
    body = bytes([len(data) + 3, address >> 8, address & 255]) + bytes(data)
    return 'S' + kind + (body + bytes([(~sum(body)) & 255])).hex().upper()


def write_s19(path, address, data, entry):
    lines = [srecord('1', address + i, data[i:i + 32])
             for i in range(0, len(data), 32)]
    lines.append(srecord('9', entry))
    path.write_text('\n'.join(lines) + '\n', encoding='ascii')


def read_s19(path):
    memory = {}
    entry = None
    for line in path.read_text(encoding='ascii').splitlines():
        raw = bytes.fromhex(line[2:])
        if len(raw) != raw[0] + 1 or sum(raw) & 255 != 255:
            raise ValueError('S-record count/checksum failed: ' + str(path))
        address = int.from_bytes(raw[1:3], 'big')
        if line.startswith('S1'):
            for offset, value in enumerate(raw[3:-1]):
                if address + offset in memory:
                    raise ValueError('Overlapping helper data')
                memory[address + offset] = value
        elif line.startswith('S9'):
            if len(raw) != 4 or entry is not None:
                raise ValueError('Invalid or duplicate S9')
            entry = address
        elif not line.startswith('S0'):
            raise ValueError('Unsupported helper record type')
    return memory, entry


def dump_bytes(response, start, end):
    text = response.decode('ascii', 'strict')
    rows = re.findall(r'(?:^|[\r\n])([0-9A-F]{4}): '
                      r'((?:[0-9A-F]{2} ){8})\| '
                      r'((?:[0-9A-F]{2} ){8})\|', text)
    result = {}
    for address, left, right in rows:
        base = int(address, 16)
        for offset, value in enumerate(bytes.fromhex(left + right)):
            if base + offset in result:
                raise ValueError('Duplicate dump address')
            result[base + offset] = value
    if not all(address in result for address in range(start, end + 1)):
        raise ValueError(f'Incomplete HIMON dump ${start:04X}-${end:04X}')
    return bytes(result[address] for address in range(start, end + 1))


def load(board, path):
    board.command('L', until=r'L S19\r', seconds=5)
    response = board.transfer(path, until=PROMPT, seconds=15)
    if b'L OK=' not in response or b'LERR' in response:
        raise ValueError('HIMON rejected load: ' + str(path))


def archive(out, banks):
    helper_bytes, entry = read_s19(HELPER)
    if entry != 0x2000 or not helper_bytes or min(helper_bytes) != 0x2000:
        raise ValueError('Wrong staging helper entry/range')
    if max(helper_bytes) >= 0x2100:
        raise ValueError('Helper overlaps parameter storage')
    if set(helper_bytes) != set(range(0x2000, max(helper_bytes) + 1)):
        raise ValueError('Helper image contains gaps')
    out = out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    summary = {'serial_log': str(LOG), 'helper_sha256': hashlib.sha256(
        HELPER.read_bytes()).hexdigest(), 'banks': {}}
    Board = get_board_class()
    with Board() as board:
        with contextlib.redirect_stdout(io.StringIO()):
            board.command('', seconds=5)
            load(board, HELPER)
            last = max(helper_bytes) | 15
            actual = dump_bytes(board.command(f'D 2000 {last:04X}'), 0x2000, last)
            expected = bytes(helper_bytes[a] for a in sorted(helper_bytes))
            if actual[:len(expected)] != expected:
                raise ValueError('Staging helper RAM readback mismatch')
        for bank in banks:
            complete = bytearray()
            for sector in range(8, 16):
                params = out / f'params-b{bank}-{sector:X}.s19'
                write_s19(params, 0x2100, bytes([bank, sector << 4, 0]), 0x2000)
                with contextlib.redirect_stdout(io.StringIO()):
                    load(board, params)
                    response = board.command('G 2000', seconds=10)
                    if b'RET' not in response:
                        raise ValueError('Staging helper did not return to HIMON')
                    status = dump_bytes(board.command('D 2100 210F'), 0x2100, 0x210F)
                    if status[:3] != bytes([bank, sector << 4, 0xAC]):
                        raise ValueError('Staging status failed: ' + status.hex())
                    response = board.command('D 4000 4FFF', seconds=30)
                    data = dump_bytes(response, 0x4000, 0x4FFF)
                (out / f'bank{bank}-{sector:X}.bin').write_bytes(data)
                complete.extend(data)
                print(f'Archived B{bank}:{sector:X}; B3 restored', flush=True)
            binary = bytes(complete)
            (out / f'bank{bank}.bin').write_bytes(binary)
            reset = int.from_bytes(binary[0x7FFC:0x7FFE], 'little')
            write_s19(out / f'bank{bank}.s19', 0x8000, binary, reset)
            summary['banks'][str(bank)] = {'bytes': len(binary),
                'sha256': hashlib.sha256(binary).hexdigest(), 'reset': f'{reset:04X}'}
            (out / 'manifest.json').write_text(json.dumps(summary, indent=2) + '\n')
            print(f'B{bank} SHA256={summary["banks"][str(bank)]["sha256"]}', flush=True)
    if banks == [0, 1, 2, 3]:
        full = b''.join((out / f'bank{bank}.bin').read_bytes() for bank in banks)
        (out / 'flash-128k.bin').write_bytes(full)
        summary['flash_sha256'] = hashlib.sha256(full).hexdigest()
    (out / 'manifest.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True, type=Path,
                        help='New archive directory; existing paths are refused')
    parser.add_argument('--banks', nargs='+', type=int, choices=range(4),
                        default=[0, 1, 2, 3])
    args = parser.parse_args()
    if len(set(args.banks)) != len(args.banks):
        parser.error('Duplicate bank selections')
    archive(args.out, args.banks)


if __name__ == '__main__':
    main()

