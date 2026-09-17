"""Verify silent AM03 child execution with observable effects; no flash writes."""
from pathlib import Path
import hashlib
import json
import sys
import argparse

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT / 'SRC/tools'))
from check_fnv_scope import capsule
import console
import bank_archive as arc

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output-dir', type=Path, default=HERE)
OUT = parser.parse_args().output_dir.resolve()
OUT.mkdir(parents=True, exist_ok=True)
console.LOG = OUT / 'handoff-verification-serial.jsonl'


def dump(board, start, end):
    return arc.dump_bytes(board.command(f'D {start:04X} {end:04X}', seconds=40), start, end)


def load(board, name, address, data):
    path = OUT / name
    arc.write_s19(path, address, data, 0x2000)
    arc.load(board, path)


cases = []
with console.Board() as board:
    top_before = dump(board, 0xF000, 0xFFFF)
    provider_before = dump(board, 0x3000, 0x3FFF)
    marker_before = dump(board, 0x6900, 0x690F)
    try:
        load(board, 'verify-empty-provider.s19', 0x3000, bytes(4096))
        load(board, 'verify-empty-child.s19', 0x2000, bytes(16))
        reply = board.command('APTEST', seconds=45)
        assert b'ERR' not in reply and b'NF' not in reply
        assert dump(board, 0x2000, 0x200F)[:6] == bytes.fromhex('00 00 A9 5A 38 60')
        assert dump(board, 0x7D40, 0x7D5F) == bytes(32)
        cases.append('bare bank APTEST fresh load and retirement')

        # Nonzero entry offset; only actual child execution writes this marker.
        body = bytes.fromhex('EA EA A9 A5 8D 00 69 A9 5A 38 60')
        package = capsule(name=b'RAMTEST', body=body, offset=2)
        provider = package.ljust(4096, b'\0')
        load(board, 'verify-marker-clear.s19', 0x6900, bytes(16))
        load(board, 'verify-ram-provider.s19', 0x3000, provider)
        reply = board.command('RAMTEST', seconds=45)
        assert b'ERR' not in reply and b'NF' not in reply
        assert dump(board, 0x6900, 0x690F) == b'\xA5' + bytes(15)
        assert dump(board, 0x2000, 0x200F)[:len(body)] == body
        assert dump(board, 0x3000, 0x3FFF) == provider
        assert dump(board, 0x7D40, 0x7D5F) == bytes(32)
        assert dump(board, 0x1B00, 0x1B1F) == bytes(32)
        assert dump(board, 0x0A00, 0x19FF) == bytes(4096)
        cases.append('unique RAM child executed marker write and retired state')

        load(board, 'verify-empty-provider.s19', 0x3000, bytes(4096))
        reply = board.command('BANKDUMP', seconds=45, until=r'BANK 0-3 OR M=MAP> ')
        assert b'BANKDUMP READ-ONLY' in reply
        reply = board.command('M', seconds=45)
        assert b'BANKDUMP MAP OK; B3 RESTORED' in reply
        cases.append('bank BANKDUMP imported calls, menu, map, return')
        assert dump(board, 0xF000, 0xFFFF) == top_before
    finally:
        load(board, 'verify-provider-restore.s19', 0x3000, provider_before)
        load(board, 'verify-marker-restore.s19', 0x6900, marker_before)
        assert dump(board, 0x3000, 0x3FFF) == provider_before
        assert dump(board, 0x6900, 0x690F) == marker_before

result = dict(result='PASS', cases=cases,
              top_sha256=hashlib.sha256(top_before).hexdigest(),
              explanation='AM03 successful handoff is silent; GO is not its contract.')
(OUT / 'handoff-verification.json').write_text(json.dumps(result, indent=2)+'\n')
print('PASS', len(cases), 'observable AM03 handoff checks')
