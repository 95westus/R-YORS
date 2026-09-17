from pathlib import Path
import hashlib
import json

import bank_archive as archive
import console

HERE = Path(__file__).resolve().parent
console.LOG = HERE/'serial-com4.jsonl'
archive.LOG = console.LOG
archive.HELPER = HERE/'bank-stage-2000.s19'
archive.get_board_class = lambda: console.Board


def dump(board, start, end, seconds=50):
    aligned_start = start & 0xFFF0
    aligned_end = end | 0x000F
    data = archive.dump_bytes(
        board.command(f'D {aligned_start:04X} {aligned_end:04X}', seconds=seconds),
        aligned_start, aligned_end)
    return data[start-aligned_start:end-aligned_start+1]


baseline = (HERE/'baseline.bin').read_bytes()
if not (HERE/'before').exists():
    archive.archive(HERE/'before', [0, 1, 2, 3])
assert (HERE/'before/flash-128k.bin').read_bytes() == baseline
plan = json.loads((HERE/'board-plan.json').read_text())
rows = []
with console.Board() as board:
    for item in plan:
        path = HERE/(item['name']+'.s19')
        board.command('L', until=r'L S19\r', seconds=5)
        response = board.transfer(path, seconds=45, until=r'\r\n>$')
        assert b'L OK=' in response and b'LERR' not in response
        provider_before = dump(board, 0x3000, 0x3FFF)
        assert hashlib.sha256(provider_before).hexdigest() == item['provider_sha256']
        response = board.command('G 6000', seconds=90)
        assert b'RET' in response and b'BRK' not in response
        capture = dump(board, 0x6800, 0x680F)
        assert (capture[0], bool(capture[1]&1), capture[2]) == (item['a'], item['carry'], item['marker']), (item['name'], capture.hex())
        assert dump(board, 0x3000, 0x3FFF) == provider_before
        assert dump(board, 0x7D40, 0x7D5F) == b'\0'*32
        assert dump(board, 0x2F00, 0x2F1F) == b'\0'*32
        assert dump(board, 0x5400, 0x540F) == b'\0'*16
        if item['loaded']:
            loaded = bytes.fromhex(item['loaded'])
            assert dump(board, 0x2000, 0x2000+len(loaded)-1) == loaded
        if item['name'] in ('ram-retire-enter-return', 'missing-import-never-enters'):
            assert dump(board, 0x0A00, 0x19FF) == b'\0'*4096
        rows.append(dict(case=item['name'], result='PASS', capture=capture.hex()))
        (HERE/'board-results.json').write_text(json.dumps(rows, indent=2)+'\n')
        print('PASS', item['name'], flush=True)

archive.archive(HERE/'final', [0, 1, 2, 3])
final = (HERE/'final/flash-128k.bin').read_bytes()
assert final == baseline
(HERE/'isolation.json').write_text(json.dumps(dict(result='PASS', all_flash_unchanged=True,
    sha256=hashlib.sha256(final).hexdigest()), indent=2)+'\n')
print('PASS eight safe AP handoff board cases; all flash unchanged', flush=True)
