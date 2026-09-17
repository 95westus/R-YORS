"""Bank-backed AM03 smoke before the physical-reset gate."""
from pathlib import Path
import json
import console, bank_archive as arc
HERE=Path(__file__).resolve().parent
console.LOG=HERE/'serial-com4.jsonl'
def dump(b,a,z): return arc.dump_bytes(b.command(f'D {a:04X} {z:04X}',seconds=40),a,z)
rows=[]
empty_provider=bytes(0x1000)
provider_fixture=HERE/'ram-provider-empty-3000.s19'
arc.write_s19(provider_fixture,0x3000,empty_provider,0xC000)
with console.Board() as b:
    arc.load(b,provider_fixture)
    assert dump(b,0x3000,0x3FFF)==empty_provider
    rows.append('deterministic empty RAM provider window')
    r=b.command('APS B2 APMAN',seconds=45)
    assert b'APMAN L=0FDF @6C00' in r
    rows.append('AM03 B2:8 inventory')
    r=b.command('AP B2 APTEST 5000',seconds=45)
    assert b'GO 5002' in r
    assert dump(b,0x5000,0x500F)[:6]==bytes.fromhex('00 00 A9 5A 38 60')
    rows.append('explicit B2 APTEST load/execute')
    r=b.command('APTEST',seconds=45)
    assert b'GO 2002' in r
    assert dump(b,0x2000,0x200F)[:6]==bytes.fromhex('00 00 A9 5A 38 60')
    assert dump(b,0x7D40,0x7D5F)==bytes(32)
    assert dump(b,0x1B00,0x1B1F)==bytes(32)
    rows.append('resident-miss bank discovery/load/execute/retire')
    r=b.command('BANKDUMP',seconds=45,until=r'BANK 0-3 OR M=MAP> ')
    assert b'AP LOAD B2 A000 -> 2000' in r and b'BANKDUMP READ-ONLY' in r
    r=b.command('M',seconds=45)
    assert b'BANKDUMP MAP OK; B3 RESTORED' in r
    rows.append('BANKDUMP imports/menu/return')
    r=b.command('H',seconds=20)
    assert b'HIMON' in r
    rows.append('resident precedence/control return')
(HERE/'smoke.json').write_text(json.dumps({'result':'PASS','cases':rows},indent=2)+'\n')
print('PASS',len(rows),'AM03 bank-backed smoke cases')
