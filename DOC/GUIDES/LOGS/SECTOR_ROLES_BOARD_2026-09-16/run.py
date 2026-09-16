from pathlib import Path
import hashlib
import json
import re
import sys
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
import console
import bank_archive as arc
console.LOG=HERE/'serial-com4.jsonl'
arc.ROOT=ROOT;arc.HERE=HERE;arc.LOG=console.LOG
arc.HELPER=HERE/'bank-stage-2000.s19';arc.get_board_class=lambda:console.Board

def sha(data):return hashlib.sha256(data).hexdigest()
def save(name,obj):(HERE/name).write_text(json.dumps(obj,indent=2)+'\n')

if __name__=='__main__':
 mode=sys.argv[1]
 if mode in ('before-a','before-b','after','after-reset'):
  arc.archive(HERE/mode,[0,1,2,3])
 elif mode=='inspect':
  a=(HERE/'before-a/flash-128k.bin').read_bytes()
  b=(HERE/'before-b/flash-128k.bin').read_bytes()
  assert len(a)==131072 and a==b,'fresh independent readbacks differ'
  target=a[0x17000:0x18000]
  old=a[0xF000:0x10000]
  top=a[0x1F000:0x20000]
  assert top[0xFF0:0xFF3]==bytes((0x1E,0x1F,0xFF))
  assert target==b'\xFF'*4096,'B2:F is occupied: inspect before replacement'
  candidate=(ROOT/'RAM-TRANSIENTS/S19/str8n-v1.34-top-update-2000.s19')
  manifest=json.loads((ROOT/'RAM-TRANSIENTS/manifest.json').read_text())
  row=next(r for r in manifest['tools'] if r['name']==candidate.stem)
  assert sha(candidate.read_bytes())==row['files']['S19/'+candidate.name]
  memory,entry=arc.read_s19(candidate)
  assert entry==0x2000 and set(memory)==set(range(0x2000,0x5000))
  embedded=bytes(memory[i] for i in range(0x4000,0x5000))
  assert sha(embedded)=='959c0142d9bf012c13dddba5aa35c5bcfe30c729a4e6370096e899a418b8266a'
  assert b'BACKUP B2F' in bytes(memory[i] for i in range(0x2000,0x4000))
  expected=bytearray(embedded);expected[0xFB0:0xFF0]=top[0xFB0:0xFF0]
  assert [i for i,(x,y) in enumerate(zip(top,expected)) if x!=y]==[0xFF0,0xFF1]
  (HERE/'old-live-top.bin').write_bytes(top)
  (HERE/'retained-old-b1f.bin').write_bytes(old)
  (HERE/'expected-live-top.bin').write_bytes(expected)
  (HERE/'top-update-2000.s19').write_bytes(candidate.read_bytes())
  save('preflight.json',dict(result='PASS',two_readbacks_identical=True,
       flash_sha256=sha(a),b2f='4096 erased bytes',old_b1f_sha256=sha(old),
       old_top_sha256=sha(top),expected_top_sha256=sha(expected),
       updater_sha256=sha(candidate.read_bytes()),changed_top_addresses=['FFF0','FFF1']))
  print((HERE/'preflight.json').read_text())
 elif mode=='install':
  gate=json.loads((HERE/'preflight.json').read_text());assert gate['result']=='PASS'
  image=HERE/'top-update-2000.s19'
  assert sha(image.read_bytes())==gate['updater_sha256']
  assert not (HERE/'write-started.json').exists(),'Do not repeat a started installation'
  with console.Board() as b:
   response=b.command('D F000 FFFF',seconds=30)
   assert arc.dump_bytes(response,0xF000,0xFFFF)==(HERE/'old-live-top.bin').read_bytes()
   b.command('STR8',until=r'K=03 \? ')
   b.send(b'Y');b.read(15,r'0-2 C W S: ')
   b.send(b'S');b.read(10,r'STR8-N>')
   b.command('L',until=r'S19[\r\n]+')
   r=b.transfer(image,seconds=30,until=r'TYPE BACKUP B2F> ')
   assert b'STR8-N 1.34 TOP UPDATE' in r and b'BACKUP B2:F; TARGET B3:F' in r
   save('write-started.json',dict(updater_sha256=gate['updater_sha256'],targets=['B2:F','B3:F'],old_b1f='retain unchanged'))
   r=b.command('BACKUP B2F',until=r'TYPE STR8-N 1.34> ',seconds=50)
   assert b'BACKUP VERIFIED' in r and b'SAFE PHY $17000-$17FFF; TARGET PHY $1F000-$1FFFF' in r
   expected_sum=sum((HERE/'old-live-top.bin').read_bytes())&65535
   assert f'SUM=${expected_sum:04X}'.encode() in r
   (HERE/'backup-verified.txt').write_bytes(r)
   r=b.command('STR8-N 1.34',until=r'(?:\r\n>$|WRITE FAIL: R=RETRY O=RESTORE OLD> )',seconds=50)
   (HERE/'update-result.txt').write_bytes(r)
   assert b'WRITE FAIL' not in r,'Updater remains in RAM recovery; do not reset'
   assert b'STR8-N 1.34 VERIFIED; RESET' in r and b'HIMON V 00.0915(2324)' in r
   actual=arc.dump_bytes(b.command('D F000 FFFF',seconds=30),0xF000,0xFFFF)
   (HERE/'immediate-live-top.bin').write_bytes(actual)
   assert actual==(HERE/'expected-live-top.bin').read_bytes()
   save('install.json',dict(result='PASS',backup_verified=True,software_reset=True,
        live_top_sha256=sha(actual),roles=actual[0xFF0:0xFF3].hex(' ')))
 elif mode=='verify':
  phase=sys.argv[2]
  before=(HERE/'before-a/flash-128k.bin').read_bytes()
  after=(HERE/phase/'flash-128k.bin').read_bytes()
  assert len(after)==len(before)==131072
  assert after[:0x17000]==before[:0x17000], 'Change outside B2:F/B3:F'
  assert after[0x18000:0x1F000]==before[0x18000:0x1F000], 'HIMON/ASM changed'
  assert after[0x17000:0x18000]==before[0x1F000:0x20000], 'B2:F is not exact old live top'
  assert after[0x1F000:]==(HERE/'expected-live-top.bin').read_bytes()
  assert after[0xF000:0x10000]==(HERE/'retained-old-b1f.bin').read_bytes()
  changes=[f'B{b}:{s:X}' for b in range(4) for s in range(8,16)
           if before[b*32768+(s-8)*4096:b*32768+(s-7)*4096]!=after[b*32768+(s-8)*4096:b*32768+(s-7)*4096]]
  assert changes==['B2:F','B3:F']
  save(phase+'-verification.json',dict(result='PASS',changed_sectors=changes,
       old_b1f_retained=True,b2f_exact_old_live_top=True,directory_preserved=True,
       himon_asm_apman_unchanged=True,flash_sha256=sha(after)))
  print((HERE/(phase+'-verification.json')).read_text())
 elif mode=='reset':
  with console.Board() as b:
   print('Receive-only capture ready for physical RESET.',flush=True)
   data=bytearray();end=time.monotonic()+1200
   while time.monotonic()<end:
    data.extend(b.read(1));(HERE/'physical-reset.txt').write_bytes(data)
    if b'RST H' in data and b'HIMON V 00.0915(2324)' in data and re.search(rb'\r\n>$',data):
     print(data.decode('ascii','replace'),flush=True)
     actual=arc.dump_bytes(b.command('D F000 FFFF',seconds=30),0xF000,0xFFFF)
     assert actual==(HERE/'expected-live-top.bin').read_bytes()
     save('physical-reset.json',dict(result='PASS',hardware_reset_banner=True,roles='FF 2F FF',live_top_sha256=sha(actual)))
     break
   else:raise AssertionError('Physical RESET not observed')
