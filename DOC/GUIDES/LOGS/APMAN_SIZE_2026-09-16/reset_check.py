"""Receive-only physical RESET capture, followed by persistent smoke checks."""
import re
import time
from provision import HERE, Board, dump, save_json

with Board() as b:
    print('COM4 listening; no transmitted bytes until a hardware-reset HIMON prompt',flush=True)
    received = bytearray()
    deadline = time.monotonic()+600
    while time.monotonic() < deadline and not (HERE/'stop-reset-wait').exists():
        received.extend(b.read(2))
        (HERE/'physical-reset.txt').write_bytes(received)
        if b'RST H' in received and b'HIMON V 00.0915(2324)' in received and re.search(rb'\r\n>$', received):
            print(received.decode('ascii','replace'),flush=True)
            assert dump(b,0x7E60,0x7E6F)[10] == 0
            r=b.command('APS B2 APMAN',seconds=30)
            assert b'APMAN L=0C05 @7000' in r
            r=b.command('APS B2 APTEST',seconds=30)
            assert b'APTEST L=0034 @2000' in r
            r=b.command('AP B2 APTEST 5000',seconds=30)
            assert b'GO 5002' in r and r.endswith(b'\r\n>')
            assert dump(b,0x5000,0x500F)[:6] == bytes.fromhex('00 00 A9 5A 38 60')
            b.command('ASM NEW',until=r'ASM>\$2000: ')
            b.command('LDA #$AC',until=r'ASM>\$2002: ')
            b.command('SEC',until=r'ASM>\$2003: ')
            b.command('RTS',until=r'ASM>\$2004: ')
            b.command('END',until=r'SEAL> ')
            b.command('.')
            r=b.command('G 2000'); assert b'RET A=AC' in r
            assert dump(b,0x8000,0xFFFF) == (HERE/'enrolled-b3.bin').read_bytes()
            save_json('physical-tests.json', [
                'receive-only RST H / STR8-N 1.34 / default warm HIMON recovery',
                'reset clears ASM resume and rediscovers both B2 carriers',
                'post-reset APTEST executes at 5002 with exact BODY',
                'post-reset fresh ASM assembles and runs A=AC/C=1',
                'post-reset complete Bank 3 remains exact'])
            print('PASS physical RESET and persistent workflow',flush=True)
            break
    else:
        print('No complete physical RESET capture; physical gate remains pending',flush=True)
