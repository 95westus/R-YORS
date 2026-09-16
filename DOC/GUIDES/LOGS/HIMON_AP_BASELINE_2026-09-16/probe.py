"""Read-only console identity probe; no reset, loader, execution, or flash commands."""
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('baseline_console', ROOT / 'SRC/BUILD/tmp/himon-size-board/console.py')
console = importlib.util.module_from_spec(spec)
spec.loader.exec_module(console)
console.LOG = HERE / 'com4.jsonl'
with console.Board() as board:
    passive = board.read(3)
    print('Passive:', repr(passive), flush=True)
    board.send(b'?\r')
    response = board.read(5)
    print(response.decode('ascii', 'replace'), flush=True)
    result = {'passive': passive.decode('ascii', 'replace'), 'query': '?',
              'response': response.decode('ascii', 'replace'), 'port': 'COM4', 'baud': 115200}
    if b'#? D M R X G AP APS L B N STR8' in response and response.endswith(b'\r\n>'):
        result['identity'] = 'HIMON command prompt'
        board.send(b'D 8000 FFFF\r')
        dump = board.read(50, r'\r\n>$')
        (HERE / 'bank3-dump.txt').write_bytes(dump)
        result['dump'] = 'bank3-dump.txt'
    else:
        result['identity'] = 'See response; no further commands sent'
    (HERE / 'com4-result.json').write_text(json.dumps(result, indent=2) + '\n')
