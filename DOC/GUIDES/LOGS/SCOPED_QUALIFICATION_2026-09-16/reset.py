from pathlib import Path
import json,re,time
import console,bank_archive as arc
HERE=Path(__file__).resolve().parent
console.LOG=HERE/'serial-com4.jsonl'
def dump(b,a,z):return arc.dump_bytes(b.command(f'D {a:04X} {z:04X}',seconds=30),a,z)
with console.Board() as b:
 print('COM4 listening; receive-only until physical RESET prompt',flush=True)
 received=bytearray();deadline=time.monotonic()+1200
 while time.monotonic()<deadline:
  received.extend(b.read(2))
  (HERE/'physical-reset.txt').write_bytes(received)
  if b'RST H' in received and b'HIMON V 00.0915(2324)' in received and re.search(rb'\r\n>$',received):break
 else:raise AssertionError('Physical RESET not captured')
 assert dump(b,0xF000,0xFFFF)==(HERE/'10-b2a-bankdump-expected.bin').read_bytes()[-4096:]
 r=b.command('AP B2 APTEST 5000',seconds=45)
 assert b'GO 5002' in r
 assert dump(b,0x5000,0x500F)[:6]==bytes.fromhex('00 00 A9 5A 38 60')
 r=b.command('BANKDUMP',seconds=45,until=r'BANK 0-3 OR M=MAP> ')
 assert b'AP LOAD B2 A000 -> 2000' in r and b'BANKDUMP READ-ONLY' in r
 r=b.command('M',seconds=45)
 assert b'BANKDUMP MAP OK; B3 RESTORED' in r
 assert dump(b,0xF000,0xFFFF)==(HERE/'10-b2a-bankdump-expected.bin').read_bytes()[-4096:]
 (HERE/'physical-reset.json').write_text(json.dumps(dict(result='PASS',physical_reset=True,policy='A6',aptest_entry='5002',aptest_body_exact=True,bankdump_bare_b2a=True,bankdump_map_return=True,top_exact=True),indent=2)+'\n')
 print('PASS physical RESET, APTEST, BANKDUMP, exact top',flush=True)
