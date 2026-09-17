"""Exercise AM03's RAM-provider command path, then restore the RAM fixture."""
from pathlib import Path
import json
import sys

import bank_archive as arc
import console

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
console.LOG = HERE / 'serial-com4.jsonl'
sys.path.insert(0, str(ROOT / 'SRC/tools'))
from check_fnv_scope import capsule


def dump(board, start, end):
    return arc.dump_bytes(
        board.command(f'D {start:04X} {end:04X}', seconds=40), start, end)


package = capsule(name=b'RAMTEST', body=bytes.fromhex('00 00 A9 5A 38 60'),
                  offset=2)
provider = package + bytes(0x1000 - len(package))
fixture = HERE / 'ram-provider-aptest-3000.s19'
empty_fixture = HERE / 'ram-provider-empty-3000.s19'
arc.write_s19(fixture, 0x3000, provider, 0xC000)
arc.write_s19(empty_fixture, 0x3000, bytes(0x1000), 0xC000)

try:
    with console.Board() as board:
        arc.load(board, fixture)
        assert dump(board, 0x3000, 0x3FFF) == provider
        reply = board.command('RAMTEST', seconds=45)
        assert b'GO 2002' in reply
        assert dump(board, 0x2000, 0x200F)[:6] == bytes.fromhex(
            '00 00 A9 5A 38 60')
        assert dump(board, 0x3000, 0x3FFF) == provider
        assert dump(board, 0x7D40, 0x7D5F) == bytes(32)
        assert dump(board, 0x1B00, 0x1B1F) == bytes(32)
finally:
    with console.Board() as board:
        arc.load(board, empty_fixture)
        assert dump(board, 0x3000, 0x3FFF) == bytes(0x1000)

result = {
    'result': 'PASS',
    'case': 'unique RAMTEST discovery/load/execute/retire',
    'provider_bytes': len(package),
    'provider_window_restored': 'zero',
}
(HERE / 'ram-smoke.json').write_text(
    json.dumps(result, indent=2) + '\n', encoding='ascii')
print('PASS RAM-provider APTEST and deterministic RAM restore')
