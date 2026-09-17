"""Restore the accepted AM02 B2:8 carrier after failed AM03 smoke."""
from pathlib import Path
import json
import console, bank_archive as arc
HERE=Path(__file__).resolve().parent
console.LOG=HERE/'serial-com4.jsonl'
baseline=(HERE.parent/'STR8N_V135_BOARD_2026-09-16/enabled/flash-128k.bin').read_bytes()[0x10000:0x11000]
image=HERE/'rollback-am02-b2-8.s19'
arc.write_s19(image,0x8000,baseline,0x8000)
with console.Board() as b:
    b.command('STR8',until=r'K=03 \? '); b.send(b'Y'); b.read(15,r'0-2 C W S: '); b.send(b'S'); b.read(10,r'STR8-N>')
    b.command('I',until=r'B0-3: '); b.command('2',until=r'RANGE: '); b.command('8',until=r'I B2 .*WRITE\? Y: ')
    b.command('Y',until=r'S19[\r\n]+')
    r=b.transfer(image,seconds=60,until=r'(?:COMMIT\? Y: |FAIL)'); assert b'COMMIT? Y:' in r and b'FAIL' not in r
    r=b.command('Y',until=r'STR8-N>',seconds=60); assert b'OK' in r and b'FAIL' not in r
    r=b.command('C',seconds=20); assert b'HIMON V 00.0916(1949)' in r
    r=b.command('APTEST',seconds=45); assert b'GO 2002' in r
(HERE/'rollback-result.json').write_text(json.dumps({'result':'PASS','restored':'AM02 B2:8','aptest':True},indent=2)+'\n')
print('PASS AM02 rollback and APTEST recovery')
