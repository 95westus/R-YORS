from pathlib import Path
import json,hashlib,re,sys,time
import console
import bank_archive as arc
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BUNDLE=ROOT/'DOC/GUIDES/LOGS/SCOPED_RECOVERY_PREP_2026-09-16'
console.LOG=HERE/'serial-com4.jsonl'
arc.HELPER=HERE/'bank-stage-2000.s19';arc.LOG=console.LOG
arc.get_board_class=lambda:console.Board
def sha(b):return hashlib.sha256(b).hexdigest()
def save(name,obj):(HERE/name).write_text(json.dumps(obj,indent=2)+'\n')
def dump(b,start,end):return arc.dump_bytes(b.command(f'D {start:04X} {end:04X}',seconds=40),start,end)
def selector(b):
 b.command('STR8',until=r'K=03 \? ')
 b.send(b'Y');b.read(15,r'0-2 C W S: ')
 b.send(b'S');b.read(10,r'STR8-N>')
def expected(policy):
 data=bytearray((BUNDLE/'baseline-flash-128k.bin').read_bytes())
 data[0x10000:0x11000]=(BUNDLE/'candidate-am02-b2-8.bin').read_bytes()
 data[0x1C000:0x1F000]=(BUNDLE/'candidate-himon-b3-c-e.bin').read_bytes()
 data[0x1F000:]=(BUNDLE/f'expected-paired-policy-{policy.lower()}-top.bin').read_bytes()
 if policy=='A6':data[0x17000:0x18000]=(BUNDLE/'expected-paired-policy-ff-top.bin').read_bytes()
 return bytes(data)
def verify(phase,policy):
 data=(HERE/phase/'flash-128k.bin').read_bytes()
 assert data==expected(policy),f'{phase}: unexpected flash bytes'
 before=(HERE/'before/flash-128k.bin').read_bytes()
 changed=[f'B{b}:{s:X}' for b in range(4) for s in range(8,16)
  if data[b*32768+(s-8)*4096:b*32768+(s-7)*4096]!=before[b*32768+(s-8)*4096:b*32768+(s-7)*4096]]
 save(phase+'-verification.json',dict(result='PASS',policy=policy,flash_sha256=sha(data),changed_sectors=changed,
  b0_b1_asm_aptest_preserved=True,expected_journals=True))
 print('PASS exact complete image:',phase,policy,sha(data),flush=True)
mode=sys.argv[1]
if mode in ('before','paired','enabled','final'):
 arc.archive(HERE/mode,[0,1,2,3])
 if mode=='before':
  assert (HERE/'before/flash-128k.bin').read_bytes()==(BUNDLE/'baseline-flash-128k.bin').read_bytes()
  save('preflight.json',dict(result='PASS',baseline_unchanged=True))
 else:verify(mode,'FF' if mode=='paired' else 'A6')
elif mode=='pair':
 gate=json.loads((ROOT/'DOC/GUIDES/LOGS/SCOPED_HOST_GATES_2026-09-16/manifest.json').read_text())
 assert gate['status'].startswith('PASS')
 assert json.loads((HERE/'preflight.json').read_text())['result']=='PASS'
 for name,digest in json.loads((BUNDLE/'manifest.json').read_text())['files'].items():assert sha((BUNDLE/name).read_bytes())==digest
 assert not (HERE/'pair-started.json').exists(),'Do not repeat started transaction'
 with console.Board() as b:
  assert dump(b,0xF000,0xFFFF)==(BUNDLE/'baseline-live-top.bin').read_bytes()
  selector(b)
  for bank,span,name in ((2,'8','candidate-am02-b2-8'),(3,'C-E','candidate-himon-b3-c-e')):
   b.command('I',until=r'B0-3: ')
   b.command(str(bank),until=r'RANGE: ')
   b.command(span,until=rf'I B{bank} .*WRITE\? Y: ')
   save('pair-started.json',dict(bank=bank,range=span,artifact=name))
   b.command('Y',until=r'S19[\r\n]+')
   r=b.transfer(BUNDLE/(name+'.s19'),seconds=60,until=r'(?:COMMIT\? Y: |FAIL)')
   assert b'COMMIT? Y:' in r and b'FAIL' not in r,'Remain in STR8; use prepared recovery card'
   r=b.command('Y',until=r'STR8-N>',seconds=60)
   assert b'OK' in r and b'FAIL' not in r
   save(f'install-b{bank}.json',dict(result='PASS',range=span,sha256=sha((BUNDLE/(name+'.bin')).read_bytes())))
  r=b.command('C',seconds=20)
  assert b'HIMON V 00.0915(2324)' in r
  assert dump(b,0xC000,0xEFFF)==(BUNDLE/'candidate-himon-b3-c-e.bin').read_bytes()
  assert dump(b,0xF000,0xFFFF)==(BUNDLE/'expected-paired-policy-ff-top.bin').read_bytes()
elif mode=='policy':
 assert json.loads((HERE/'paired-verification.json').read_text())['result']=='PASS'
 assert json.loads((HERE/'disabled-smoke.json').read_text())['result']=='PASS'
 assert not (HERE/'policy-started.json').exists()
 with console.Board() as b:
  top=dump(b,0xF000,0xFFFF)
  assert top==(BUNDLE/'expected-paired-policy-ff-top.bin').read_bytes()
  selector(b);b.command('L',until=r'S19[\r\n]+')
  r=b.transfer(BUNDLE/'policy-a6/policy.s19',seconds=30,until=r'TYPE BACKUP B2F> ')
  assert b'STR8-N 1.34 POLICY A6' in r
  save('policy-started.json',dict(before_sha256=sha(top),targets=['B2:F','B3:F']))
  r=b.command('BACKUP B2F',seconds=60,until=r'TYPE POLICY A6> ')
  assert b'BACKUP VERIFIED' in r and f'SUM=${sum(top)&65535:04X}'.encode() in r
  (HERE/'policy-backup.txt').write_bytes(r)
  r=b.command('POLICY A6',seconds=60,until=r'(?:\r\n>$|WRITE FAIL: R=RETRY O=RESTORE OLD> )')
  (HERE/'policy-update.txt').write_bytes(r)
  assert b'WRITE FAIL' not in r,'Keep RAM updater running; do not reset'
  assert b'STR8-N 1.34 VERIFIED; RESET' in r and b'HIMON V 00.0915(2324)' in r
  assert dump(b,0xF000,0xFFFF)==(BUNDLE/'expected-paired-policy-a6-top.bin').read_bytes()
  save('policy.json',dict(result='PASS',roles='FF 2F A6',software_reset=True))
elif mode in ('disabled-smoke','enabled-smoke'):
 policy='FF' if mode=='disabled-smoke' else 'A6'
 assert json.loads((HERE/('paired-verification.json' if policy=='FF' else 'enabled-verification.json')).read_text())['result']=='PASS'
 rows=[]
 with console.Board() as b:
  assert dump(b,0xF000,0xFFFF)==(BUNDLE/f'expected-paired-policy-{policy.lower()}-top.bin').read_bytes()
  if policy=='FF':
   for command in ('AP B2 APTEST 5000','APTEST'):
    r=b.command(command,seconds=45)
    assert b'GO ' not in r and b'NF' in r,(command,r)
    rows.append(dict(command=command,result='PASS',output=r.decode('ascii','replace')))
  else:
   for command,entry in (('AP B2 APTEST 5000','5002'),('APTEST','2002')):
    r=b.command(command,seconds=45)
    assert f'GO {entry}'.encode() in r,(command,r)
    address=int(entry,16)-2
    assert dump(b,address,address+15)[:6]==bytes.fromhex('00 00 A9 5A 38 60')
    rows.append(dict(command=command,result='PASS',output=r.decode('ascii','replace')))
   r=b.command('AP B0 APTEST 5000',seconds=45)
   assert b'GO ' not in r and b'APERR=' in r
   rows.append(dict(command='AP B0 APTEST 5000',result='PASS',output=r.decode('ascii','replace'),
     limitation='Serial refusal is not electrical proof of no B0 selection'))
   r=b.command('APS B2 APMAN',seconds=45)
   assert b'APMAN L=0C21 @7000' in r
   rows.append(dict(command='APS B2 APMAN',result='PASS',output=r.decode('ascii','replace')))
  # Direct AP executes BODY base, not an APMAN export's offset. Use the
  # existing host/board-qualified minimal package builder with entry at zero.
  sys.path.insert(0,str(ROOT/'SRC/tools'))
  from audit_himon_ap_contracts import package
  fixture=HERE/'direct-ram-3000.s19'
  arc.write_s19(fixture,0x3000,package(bytes.fromhex('A9 5A 38 60')),0x3000)
  b.command('L',until=r'L S19\r')
  b.transfer(fixture,seconds=30,until=r'\r\n>$')
  r=b.command('AP 3000 5000',seconds=30)
  assert b'GO 5000' in r and b'BRK' not in r
  assert dump(b,0x5000,0x500F)[:4]==bytes.fromhex('A9 5A 38 60')
  rows.append(dict(command='AP 3000 5000',result='PASS',output=r.decode('ascii','replace')))
  b.command('ASM NEW',until=r'ASM>\$2000: ')
  for line,end in [('LDA #$AC','2002'),('SEC','2003'),('RTS','2004')]:b.command(line,until=rf'ASM>\${end}: ')
  b.command('END',until=r'SEAL> ');b.command('.')
  r=b.command('G 2000');assert b'RET A=AC' in r
  assert dump(b,0x2000,0x200F)[:4]==bytes.fromhex('A9 AC 38 60')
  rows.append(dict(command='ASM assemble and G 2000',result='PASS',output=r.decode('ascii','replace')))
  assert dump(b,0xF000,0xFFFF)==(BUNDLE/f'expected-paired-policy-{policy.lower()}-top.bin').read_bytes()
 save(mode+'.json',dict(result='PASS',policy=policy,cases=rows))
elif mode=='reset':
 with console.Board() as b:
  print('Receive-only physical RESET capture ready',flush=True)
  data=bytearray();end=time.monotonic()+1200
  while time.monotonic()<end:
   data.extend(b.read(1));(HERE/'physical-reset.txt').write_bytes(data)
   if b'RST H' in data and b'HIMON V 00.0915(2324)' in data and re.search(rb'\r\n>$',data):
    assert dump(b,0xF000,0xFFFF)==(BUNDLE/'expected-paired-policy-a6-top.bin').read_bytes()
    r=b.command('AP B2 APTEST 5000',seconds=45)
    assert b'GO 5002' in r
    assert dump(b,0x5000,0x500F)[:6]==bytes.fromhex('00 00 A9 5A 38 60')
    save('physical-reset.json',dict(result='PASS',hardware_reset=True,policy='A6',aptest_after_reset=True))
    break
  else:raise AssertionError('Physical RESET not observed')
else:raise ValueError(mode)
