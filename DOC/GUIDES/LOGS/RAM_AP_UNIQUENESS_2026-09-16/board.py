from pathlib import Path
import json,hashlib
import console,bank_archive as arc
HERE=Path(__file__).resolve().parent
console.LOG=HERE/'serial-com4.jsonl';arc.LOG=console.LOG;arc.HELPER=HERE/'bank-stage-2000.s19';arc.get_board_class=lambda:console.Board
def dump(b,a,z):return arc.dump_bytes(b.command(f'D {a:04X} {z:04X}',seconds=50),a,z)
arc.archive(HERE/'before',[0,1,2,3])
assert (HERE/'before/flash-128k.bin').read_bytes()==(HERE/'baseline.bin').read_bytes()
rows=[]
with console.Board() as b:
 for row in json.loads((HERE/'board-plan.json').read_text()):
  name=row['name'];blob=(HERE/(name+'.bin')).read_bytes()
  b.command('L',until=r'L S19\r');r=b.transfer(HERE/(name+'.s19'),seconds=40,until=r'\r\n>$')
  assert b'L OK=' in r and b'LERR' not in r
  assert dump(b,0x2000,0x4FFF)==blob
  r=b.command('G 2600',seconds=60);assert b'RET' in r and b'BRK' not in r
  result=dump(b,0x2900,0x292F);wanted=bytes.fromhex(row['expected'])
  assert result[0]==wanted[0] and result[1]&1==wanted[1]&1 and result[2:]==wanted[2:],(name,result.hex(),wanted.hex())
  assert dump(b,0x3000,0x3FFF)==blob[4096:8192]
  rows.append(dict(case=name,result='PASS',bytes=result.hex()))
  (HERE/'board-results.json').write_text(json.dumps(rows,indent=2)+'\n');print('PASS '+name,flush=True)
arc.archive(HERE/'final',[0,1,2,3])
actual=(HERE/'final/flash-128k.bin').read_bytes();assert actual==(HERE/'baseline.bin').read_bytes()
(HERE/'isolation.json').write_text(json.dumps(dict(result='PASS',all_flash_unchanged=True,sha256=hashlib.sha256(actual).hexdigest()),indent=2)+'\n')
print('PASS eight RAM AP/combined uniqueness board cases; all flash unchanged',flush=True)
