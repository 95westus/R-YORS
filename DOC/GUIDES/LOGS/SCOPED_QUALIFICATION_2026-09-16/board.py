from pathlib import Path
import sys,json,hashlib,re,time
import console,bank_archive as arc
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
console.LOG=HERE/'serial-com4.jsonl'
plan=json.loads((HERE/'plan.json').read_text())
def save(name,data):(HERE/name).write_text(json.dumps(data,indent=2)+'\n')
def dump(b,a,z):return arc.dump_bytes(b.command(f'D {a:04X} {z:04X}',seconds=30),a,z)
def load(b,path):
 b.command('L',until=r'L S19\r');r=b.transfer(path,seconds=30,until=r'\r\n>$')
 assert b'L OK=' in r and b'LERR' not in r
def sector(b,bank,s):
 load(b,HERE/'bank-stage-2000.s19')
 params=HERE/'read-params.s19';arc.write_s19(params,0x2100,bytes((bank,s<<4,0)),0x2000)
 load(b,params);r=b.command('G 2000');assert b'RET' in r
 assert dump(b,0x2100,0x210F)[:3]==bytes((bank,s<<4,0xAC))
 return dump(b,0x4000,0x4FFF)
def selector(b):
 b.command('STR8',until=r'K=03 \? ');b.send(b'Y');b.read(15,r'0-2 C W S: ')
 b.send(b'S');b.read(10,r'STR8-N>')
mode=sys.argv[1]
if mode=='install':
 number=int(sys.argv[2]);row=plan[number-1];stem=row['stem'];bank=row['bank']
 assert json.loads((HERE/'fixture-host.json').read_text())['result']=='PASS'
 for name,h in json.loads((HERE/'fixture-manifest.json').read_text())['files'].items():
  assert hashlib.sha256((HERE/name).read_bytes()).hexdigest()==h,name
 assert not (HERE/(stem+'-started.json')).exists(),'Do not repeat started install'
 before=(HERE/('before/flash-128k.bin' if number==1 else plan[number-2]['stem']+'-expected.bin')).read_bytes()
 if number>1:assert json.loads((HERE/(plan[number-2]['stem']+'-board.json')).read_text())['result']=='PASS'
 expected=(HERE/(stem+'-expected.bin')).read_bytes()
 with console.Board() as b:
  assert dump(b,0xF000,0xFFFF)==before[-4096:]
  assert sector(b,bank,10)==before[bank*32768+0x2000:bank*32768+0x3000]
  selector(b);b.command('I',until=r'B0-3: ');b.command(str(bank),until=r'RANGE: ')
  if row['new_descriptor']:
   b.command('A',until=r'TYPE: ');b.command('A2',until=r'DESC: ')
   b.command('APC01',until=r'WRITE\? Y: ')
  else:b.command('A',until=r'WRITE\? Y: ')
  save(stem+'-started.json',dict(bank=bank,sector='A',fixture=row['fixture']))
  b.command('Y',until=r'S19[\r\n]+')
  r=b.transfer(HERE/(stem+'.s19'),seconds=45,until=r'(?:COMMIT\? Y: |FAIL)')
  assert b'COMMIT? Y:' in r and b'FAIL' not in r,'Stay in STR8 and recover from archived checkpoint'
  r=b.command('Y',seconds=45,until=r'STR8-N>');assert b'OK' in r and b'FAIL' not in r
  b.command('C',seconds=20)
  assert dump(b,0xF000,0xFFFF)==expected[-4096:]
  actual=sector(b,bank,10);assert actual==expected[bank*32768+0x2000:bank*32768+0x3000]
  (HERE/(stem+'-readback.bin')).write_bytes(actual)
  save(stem+'-board.json',dict(result='PASS',bank=bank,sector='A',fixture=row['fixture'],
   actual_sha256=hashlib.sha256(actual).hexdigest(),top_exact=True))
elif mode=='reject':
 number=int(sys.argv[2]);name=plan[number-1]['stem']
 cases=[]
 commands=[('BANKDUMP',0xD2)] if number==2 else [('BANKDUMP',0xD3 if number==7 else 0xD1)]
 if number==8:commands=[('FNV1A_INIT',None),('BANKDUMP',0xD1)]
 with console.Board() as b:
  for command,status in commands:
   r=b.command(command,seconds=45)
   assert b'GO ' not in r
   if status is not None:assert f'APMAN ERR=${status:02X}'.encode() in r,(command,r)
   else:assert b'AP LOAD' not in r and b'APMAN ERR' not in r and b'HSH_NF' not in r
   cases.append(dict(command=command,status=status,output=r.decode('ascii','replace')))
  assert dump(b,0xF000,0xFFFF)==(HERE/(name+'-expected.bin')).read_bytes()[-4096:]
 save(name+'-refusal.json',dict(result='PASS',cases=cases))
elif mode=='bankdump':
 number=int(sys.argv[2]);row=plan[number-1];bank=2 if number in (1,10) else 1
 cases=[]
 with console.Board() as b:
  actions=[(f'AP B{bank} BANKDUMP','header'),('BANKDUMP','map'),(f'AP B{bank} BANKDUMP','page')]
  if number==10:actions.append(('BANKDUMP','all-quit'))
  for command,action in actions:
   r=b.command(command,seconds=45,until=r'BANK 0-3 OR M=MAP> ')
   assert f'AP LOAD B{bank} A000 -> 2000'.encode() in r and b'BANKDUMP READ-ONLY' in r
   output=bytearray(r)
   if action=='map':
    output.extend(b.command('M',seconds=45))
    assert b'BANKDUMP MAP OK; B3 RESTORED' in output
   else:
    output.extend(b.command('2',until=r'SECTOR 8-F> '))
    output.extend(b.command('F' if action=='all-quit' else '8',until=r'H=APC HEADER P=PAGE A=ALL Q=QUIT> '))
    if action=='header':
     output.extend(b.command('H',seconds=30));assert b'APC V=02' in output
    elif action=='page':
     output.extend(b.command('P',until=r'PAGE 0-F> '))
     output.extend(b.command('0',seconds=30))
    else:
     output.extend(b.command('A',seconds=30,until=r'-- MORE \(ENTER=NEXT, Q=QUIT\)> '))
     output.extend(b.command('Q',seconds=15))
    assert (b'BANKDUMP QUIT; NO FLASH WRITE' if action=='all-quit' else b'BANKDUMP OK; B3 RESTORED') in output
   cases.append(dict(command=command,action=action,output=output.decode('ascii','replace')))
  for item in json.loads((HERE/'link-targets.json').read_text()):
   start=item['site']&0xFFF0;actual=dump(b,start,start+31)
   at=item['site']-start
   assert int.from_bytes(actual[at:at+2],'little')==item['target']
  assert dump(b,0xF000,0xFFFF)==(HERE/(row['stem']+'-expected.bin')).read_bytes()[-4096:]
 save(row['stem']+'-bankdump.json',dict(result='PASS',bank=bank,cases=cases,imports_exact=True))
else:raise ValueError(mode)
