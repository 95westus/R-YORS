"""Prove the accepted AM02 behavior after recovering from the AM03 failure."""
from pathlib import Path
import json

import bank_archive as arc
import console

HERE = Path(__file__).resolve().parent
console.LOG = HERE / 'serial-com4.jsonl'


def dump(board, start, end):
    return arc.dump_bytes(
        board.command(f'D {start:04X} {end:04X}', seconds=40), start, end)


rows = []
with console.Board() as board:
    arc.load(board, HERE / 'ram-provider-empty-3000.s19')
    assert dump(board, 0x3000, 0x3FFF) == bytes(0x1000)
    rows.append('empty RAM provider fixture')
    reply = board.command('APS B2 APMAN', seconds=45)
    assert b'APMAN L=0C21 @7000' in reply
    assert b'AM02' in reply
    rows.append('AM02 B2:8 inventory')
    reply = board.command('AP B2 APTEST 5000', seconds=45)
    assert b'GO 5002' in reply
    assert dump(board, 0x5000, 0x500F)[:6] == bytes.fromhex(
        '00 00 A9 5A 38 60')
    rows.append('explicit B2 APTEST load/execute')
    reply = board.command('APTEST', seconds=45)
    assert b'GO 2002' in reply
    assert dump(board, 0x2000, 0x200F)[:6] == bytes.fromhex(
        '00 00 A9 5A 38 60')
    rows.append('bare B2 APTEST discovery/load/execute')
    reply = board.command('BANKDUMP', seconds=45,
                          until=r'BANK 0-3 OR M=MAP> ')
    assert b'AP LOAD B2 A000 -> 2000' in reply
    assert b'BANKDUMP READ-ONLY' in reply
    reply = board.command('M', seconds=45)
    assert b'BANKDUMP MAP OK; B3 RESTORED' in reply
    rows.append('bare BANKDUMP imports/menu/return')
    reply = board.command('H', seconds=20)
    assert b'HIMON' in reply
    rows.append('resident precedence/control return')

result = {'result': 'PASS', 'cases': rows}
(HERE / 'post-rollback-smoke.json').write_text(
    json.dumps(result, indent=2) + '\n', encoding='ascii')
print('PASS', len(rows), 'post-rollback AM02 board cases')
