"""Receive physical RESET, verify handoff, and archive exact final flash."""
from datetime import datetime
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys
import time

import console
import bank_archive as arc

HERE = Path(__file__).resolve().parent
OUT = HERE / ('physical-reset-' + datetime.now().strftime('%Y%m%d-%H%M%S'))
OUT.mkdir()
console.LOG = OUT / 'serial-com4.jsonl'
arc.LOG = console.LOG


def dump(board, start, end):
    return arc.dump_bytes(board.command(f'D {start:04X} {end:04X}', seconds=40), start, end)


expected = bytearray((HERE / 'final/flash-128k.bin').read_bytes())
# Full B2 recovery and compatible AM03 reinstall consumed two further pairs.
assert expected[0x1FFDE] == 0xFC
expected[0x1FFDE] = 0xC0
assert hashlib.sha256(expected[-4096:]).hexdigest() == json.loads(
    (HERE / 'reinstall-am03-result.json').read_text())['top_after_sha256']

with console.Board() as board:
    assert dump(board, 0xF000, 0xFFFF) == expected[-4096:]
    print('ARMED: press physical RESET once; COM4 receive-only. ' + str(OUT), flush=True)
    received = bytearray()
    deadline = time.monotonic() + 1200
    while time.monotonic() < deadline:
        received.extend(board.read(2))
        (OUT / 'reset-received.txt').write_bytes(received)
        if (b'RST H' in received and b'HIMON V 00.0916(1949)' in received
                and re.search(rb'\r\n>$', received)):
            break
    else:
        raise AssertionError('Physical reset not captured within 20 minutes')
    print(received.decode('ascii', 'replace'), flush=True)
    assert dump(board, 0xF000, 0xFFFF) == expected[-4096:]
    assert dump(board, 0x7E60, 0x7E6F)[10] == 0, 'ASM resume flag not cleared'
    (OUT / 'reset.json').write_text(json.dumps(dict(
        result='PASS', reset_banner=True, himon='00.0916(1949)',
        top_exact=True, asm_resume_cleared=True), indent=2)+'\n')

subprocess.run([sys.executable, str(HERE / 'verify_handoff.py'),
                '--output-dir', str(OUT)], check=True)
arc.archive(OUT / 'final', [0, 1, 2, 3])
actual = (OUT / 'final/flash-128k.bin').read_bytes()
assert actual == expected, 'Post-reset flash differs from verified installed image'
(OUT / 'result.json').write_text(json.dumps(dict(
    result='PASS', physical_reset=True, handoff_cases=3,
    all_32_sectors_exact=True,
    flash_sha256=hashlib.sha256(actual).hexdigest()), indent=2)+'\n')
print('PASS physical RESET, handoff and all 32 flash sectors; evidence ' + str(OUT), flush=True)
