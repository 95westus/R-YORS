from pathlib import Path
import sys,json,subprocess,shutil
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];sys.path.insert(0,str(ROOT/'SRC/tools'))
from audit_himon_ap_contracts import Machine,fnv
from check_fnv_scope import capsule
from report_himon_ap_baseline import srecord
from prepare_scoped_recovery import write_s19
for name in ('console.py','bank_archive.py','bank-stage-2000.s19'):
 shutil.copy2(ROOT/'LOCAL/scoped-qualification-20260916'/name,HERE/name)
baseline=(ROOT/'DOC/GUIDES/LOGS/RAM_HREC_PROOF_2026-09-16/final/flash-128k.bin').read_bytes()
(HERE/'baseline.bin').write_bytes(baseline)
code=srecord(ROOT/'SRC/BUILD/s19/fnv-ram-ap-2000.s19')
assert json.loads((HERE/'host.json').read_text())['result']=='PASS'
for name in ('himon-rom-c000','asm-v1-flash-8000'):
 assert all(baseline[3*32768+a-0x8000]==v for a,v in srecord(ROOT/f'SRC/BUILD/s19/{name}.s19').items())
assert (ROOT/'SRC/BUILD/bin/apman-v1-bank2-8000.bin').read_bytes()==baseline[0x10000:0x11000]
driver=''' ORG $2600
START CLD
 STZ $7E31
 STZ $7E33
 LDA #$40
 STA $7E32
 LDA #$70
 STA $7E34
 LDA #$01
 STA $7E2F
 JSR AP
 BCC CAPTURE
 LDX #$1F
COPY LDA $2800,X
 STA $7D40,X
 DEX
 BPL COPY
 JSR $2000
CAPTURE STA $2900
 PHP
 PLA
 STA $2901
 LDX #$1F
RESULT LDA $7D40,X
 STA $2910,X
 DEX
 BPL RESULT
 RTS
AP JMP ($7E2D)
 END
'''
(HERE/'driver.asm').write_text(driver)
for cmd in (['wdc02as','-G','-L','-S','-W','driver.asm'],['wdcln','-g','-s','-t','-hm19','-j','-o','driver.s19','driver.obj']):
 r=subprocess.run(cmd,cwd=HERE,capture_output=True,text=True);assert r.returncode==0,(r.stdout,r.stderr)
db=srecord(HERE/'driver.s19');good=capsule(name=b'RAMTEST');bd=capsule(name=b'BANKDUMP')
cases=[('unique-ram-edge',b'RAMTEST',[(0x4000-len(good),good)],{},0xAC,1,1),
 ('ram-flash-duplicate',b'BANKDUMP',[(0x3000,bd)],{},0xD2,2,0),
 ('malformed-ram-bank-unique',b'BANKDUMP',[(0x3000,bd[:-1]+b'\0')],{},0xAC,1,2),
 ('disabled-ram-bank-unique',b'BANKDUMP',[(0x3000,bd)],{4:0},0xAC,1,2),
 ('sector-exclusion-ram-unique',b'BANKDUMP',[(0x3000,bd)],{3:1},0xAC,1,1),
 ('two-ram-duplicates',b'RAMTEST',[(0x3000,good),(0x3200,good)],{},0xD2,2,0),
 ('forged-name-bank-unique',b'BANKDUMP',[(0x3000,capsule(name=b'NOTDUMPX',hash_name=b'BANKDUMP'))],{},0xAC,1,2),
 ('bad-ram-window',b'RAMTEST',[(0x3000,good)],{5:0x88},0xD4,0,0)]
rows=[]
for name,wanted,patches,req,status,count,source in cases:
 blob=bytearray(0x3000);blob[0x1000:0x2000]=b'\xFF'*4096;blob[0x2000:]=baseline[0x10000:0x11000]
 for a,v in {**code,**db}.items():blob[a-0x2000]=v
 card=bytearray(32);card[0]=7;card[3:7]=bytes([255,1,8,1]);card[7:11]=fnv(wanted).to_bytes(4,'little');card[19:22]=bytes([0,0x2F,len(wanted)])
 for a,v in req.items():card[a]=v
 blob[0x800:0x820]=card;blob[0xF00:0xF00+len(wanted)]=wanted
 for a,data in patches:blob[a-0x2000:a-0x2000+len(data)]=data
 m=Machine(ROOT/'SRC/BUILD',baseline[-4096:])
 for b in range(4):m.m.banks[b][:]=baseline[b*32768:(b+1)*32768]
 m.m.ram[0x2000:0x5000]=blob;m.run(0x2600,limit=8_000_000)
 result=bytes(m.m.ram[0x2900:0x2930])
 assert (result[0],bool(result[1]&1),result[0x1B],result[0x1C])==(status,status==0xAC,count,source),(name,result.hex())
 assert bytes(m.m.ram[0x3000:0x4000])==blob[4096:8192]
 (HERE/(name+'.bin')).write_bytes(blob);write_s19(HERE/(name+'.s19'),blob,0x2000,0x2600)
 rows.append(dict(name=name,expected=result.hex()));print(name,'host rehearsal PASS',flush=True)
(HERE/'board-plan.json').write_text(json.dumps(rows,indent=2)+'\n')
