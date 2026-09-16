from pathlib import Path
import json,sys,subprocess,shutil
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(ROOT/'SRC/tools'))
from check_fnv_ram_hrec import hrec,fnv
from report_himon_ap_baseline import srecord
from prepare_scoped_recovery import write_s19
from audit_himon_ap_contracts import Machine
for name in ('console.py','bank_archive.py','bank-stage-2000.s19'):
 shutil.copy2(ROOT/'LOCAL/scoped-qualification-20260916'/name,HERE/name)
baseline=ROOT/'DOC/GUIDES/LOGS/SCOPED_QUALIFICATION_2026-09-16/final/flash-128k.bin'
shutil.copy2(baseline,HERE/'baseline.bin')
code=srecord(ROOT/'SRC/BUILD/s19/fnv-ram-hrec-2000.s19')
assert json.loads((ROOT/'SRC/BUILD/tmp/fnv-ram-hrec.json').read_text())['result']=='PASS'
cases=[('inline-edge',[(0x3FF7,hrec())],{},0xAC,1,0x3FF7,0x3FFF,0,1),
 ('text-pointer',[(0x3000,hrec(5)),(0x3100,b'\x60'),(0x3200,b'TEX\xD4')],{},0xAC,1,0x3000,0x3100,0x3200,5),
 ('confirm-pointer',[(0x3000,hrec(3)),(0x3100,b'\x60'),(0x3200,b'CONFIR\xCD')],{},0xAC,1,0x3000,0x3100,0x3200,3),
 ('duplicate',[(0x3000,hrec()),(0x3100,hrec())],{},0xD2,2,0,0,0,0),
 ('malformed-pointer',[(0x3000,hrec(5,entry=0x7F00)),(0x3200,b'\xC1')],{},0xD1,0,0,0,0,0),
 ('disabled',[(0x3000,hrec())],{4:0},0xD4,0,0,0,0,0),
 ('wrong-format',[(0x3000,hrec())],{6:1},0xD4,0,0,0,0,0)]
driver=''' ORG $2400
START CLD
 LDX #$1F
COPY LDA $2500,X
 STA $7D40,X
 DEX
 BPL COPY
 JSR $2000
 STA $2800
 PHP
 PLA
 STA $2801
 LDX #$1F
RESULT LDA $7D40,X
 STA $2810,X
 DEX
 BPL RESULT
 RTS
 END
'''
(HERE/'driver.asm').write_text(driver)
for cmd in (['wdc02as','-G','-L','-S','-W','driver.asm'],['wdcln','-g','-s','-t','-hm19','-j','-o','driver.s19','driver.obj']):
 r=subprocess.run(cmd,cwd=HERE,capture_output=True,text=True)
 assert r.returncode==0,(r.stdout,r.stderr)
driverbytes=srecord(HERE/'driver.s19');rows=[]
for name,patches,request,status,count,record,entry,extra,kind in cases:
 blob=bytearray(8192);blob[4096:]=b'\xFF'*4096
 for a,v in {**code,**driverbytes}.items():blob[a-0x2000]=v
 card=bytearray(32);card[4:6]=bytes([1,8]);card[7:11]=fnv(b'RAMTEST').to_bytes(4,'little')
 for a,v in request.items():card[a]=v
 blob[0x500:0x520]=card
 for a,data in patches:blob[a-0x2000:a-0x2000+len(data)]=data
 (HERE/(name+'.bin')).write_bytes(blob);write_s19(HERE/(name+'.s19'),blob,0x2000,0x2400)
 m=Machine(ROOT/'SRC/BUILD',baseline.read_bytes()[-4096:]);m.m.ram[0x2000:0x4000]=blob
 m.run(0x2400);result=bytes(m.m.ram[0x2800:0x2830])
 assert (result[0],bool(result[1]&1),result[0x1B])==(status,status==0xAC,count)
 assert int.from_bytes(result[0x1F:0x21],'little')==record
 assert result[0x28:0x2D]==entry.to_bytes(2,'little')+extra.to_bytes(2,'little')+bytes([kind])
 rows.append(dict(name=name,status=status,expected=result.hex()))
(HERE/'board-plan.json').write_text(json.dumps(rows,indent=2)+'\n')
print('PASS seven exact driver/fixture host rehearsals')
