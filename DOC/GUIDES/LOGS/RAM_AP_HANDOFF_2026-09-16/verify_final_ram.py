from pathlib import Path
import json
import sys

import bank_archive as archive
import console

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT/'SRC/tools'))
from report_himon_ap_baseline import srecord

console.LOG = HERE/'serial-com4.jsonl'
expected = srecord(ROOT/'SRC/BUILD/s19/fnv-ram-ap-handoff-5000.s19')
start, end = min(expected), max(expected)
with console.Board() as board:
    response = board.command(f'D {start:04X} {end | 15:04X}', seconds=30)
    actual = archive.dump_bytes(response, start, end | 15)[:end-start+1]
    assert actual == bytes(expected[address] for address in range(start, end+1))
    response = board.command('D 7E60 7E6F')
    state = archive.dump_bytes(response, 0x7E60, 0x7E6F)
    assert state[0x0A] == 0
result = dict(result='PASS', range=f'{start:04X}-{end:04X}', exact_handoff_readback=True,
              asm_resume=f'{state[0x0A]:02X}')
(HERE/'final-ram-readback.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps(result, indent=2))
