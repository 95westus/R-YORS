from pathlib import Path
import json,sys
import console,bank_archive as arc
HERE=Path(__file__).resolve().parent
console.LOG=HERE/'serial-com4.jsonl'
mode=sys.argv[1]
assert mode in ('roles','led-b2','led-b1','led-b0')
host=json.loads((HERE/'diagnostic-host-v2.json').read_text());assert host['result']=='PASS'
case=next(c for c in host['cases'] if c['mode']==mode)
memory,entry=arc.read_s19(HERE/(mode+'-v2')/'driver.s19');assert entry==0x2000
expected_top=(HERE/'10-b2a-bankdump-expected.bin').read_bytes()[-4096:]
def dump(b,a,z):return arc.dump_bytes(b.command(f'D {a:04X} {z:04X}',seconds=30),a,z)
with console.Board() as b:
 assert dump(b,0xF000,0xFFFF)==expected_top
 b.command('L',until=r'L S19\r')
 r=b.transfer(HERE/(mode+'-v2')/'driver.s19',until=r'\r\n>$',seconds=30)
 assert b'L OK=2000' in r
 assert dump(b,0x2000,0x3FFF)==bytes(memory[a] for a in range(0x2000,0x4000))
 print('STARTING HELD DISPLAY:',mode,flush=True)
 r=b.command('G 2000',seconds=60)
 assert b'RET' in r and b'BRK' not in r
 result=dump(b,0x2400,0x245F);pcr=dump(b,0x2500,0x251F)
 if mode=='roles':
  assert list(result[:24])==case['expected'] and result[0x31]==0xAC
 else:
  values=case['expected'];bank=int(mode[-1])
  assert result[0x30]==len(values) and list(result[:len(values)])==values
  assert result[0x31]==0xD1 and not result[0x32]&1
  assert result[0x40]==2*len(values)
  assert [x&0xEE for x in pcr[:2*len(values)]]==[0xEC if bank==2 else 0xCE,0xEE]*len(values)
  for address,original in [(host['patch_address'],bytes.fromhex('8D A0 7F')),
       (host['selector_sites'][0],bytes.fromhex('20 10 F0')),(host['selector_sites'][1],bytes.fromhex('20 03 02'))]:
   start=address&0xFFF0;raw=dump(b,start,start+31)
   assert raw[address-start:address-start+3]==original
 assert dump(b,0xF000,0xFFFF)==expected_top
(HERE/(mode+'-board.json')).write_text(json.dumps(dict(result='PASS',mode=mode,
 expected_display=[f'{x:02X}' for x in case['expected']],result_bytes=result.hex(),pcr_samples=pcr.hex(),
 visual_gate='requires separate operator observation; serial/RAM samples alone do not close it'),indent=2)+'\n')
