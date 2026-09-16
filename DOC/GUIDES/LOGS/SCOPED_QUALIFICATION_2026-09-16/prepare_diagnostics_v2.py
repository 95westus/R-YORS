from pathlib import Path
import sys,json,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(ROOT/'SRC/tools'))
from report_himon_ap_baseline import symbols,srecord
from audit_himon_ap_contracts import Machine,fnv,word
from prepare_scoped_recovery import write_s19
build=ROOT/'SRC/BUILD';manager=symbols(build/'s19/apman-7000.map')
raw=srecord(build/'s19/apman-7000.s19')
patch=manager['APMAN_STAGE_RAW']+6
assert bytes(raw[a] for a in range(patch,patch+3))==bytes.fromhex('8D A0 7F')
select_site=manager['APMAN_STAGE_RAW']+11
restore_site=manager['APMAN_STAGE_RAW']+48
assert bytes(raw[a] for a in range(select_site,select_site+3))==bytes.fromhex('20 10 F0')
assert bytes(raw[a] for a in range(restore_site,restore_site+3))==bytes.fromhex('20 03 02')
baseline=(HERE/'before/flash-128k.bin').read_bytes()
receipts=[]
for mode in ('roles','led-b2','led-b1','led-b0'):
 folder=HERE/(mode+'-v2');folder.mkdir(exist_ok=False)
 lines=[' ORG $2000','START PHP',' SEI',' CLD',
  ' LDA #$00',' STA $7E31',' STA $7E33',' LDA #$30',' STA $7E32',
  ' LDA #$70',' STA $7E34',' LDA #$01',' STA $7E2F',' JSR CALL_AP',
  ' BCS LOADED',' STA $2431',' PLP',' RTS','LOADED STZ $2430',' STZ $2440']
 if mode=='roles':
  for bank in range(3):
   for sector in range(8,16):
    lines += [f' LDA #${bank:02X}',' STA $A7',f' LDA #${sector<<4:02X}',' STA $A8',
      f' JSR ${manager["APMAN_LOCATION_PROTECTED"]:04X}',' PHP',' PLA',' AND #$01',
      f' STA ${0x2400+bank*8+sector-8:04X}']
  lines+=[' LDA #$AC',' STA $2431',' PLP',' RTS']
 else:
  bank=int(mode[-1])
  for at,value in ((patch,0x20),(patch+1,0),(patch+2,0x23),
    (select_site+1,0x40),(select_site+2,0x23),(restore_site+1,0x50),(restore_site+2,0x23),
    (0x7D40,1<<bank),(0x7D43,255),(0x7D44,0),(0x7D46,1),
    (0x7D53,0),(0x7D54,0x26),(0x7D55,8),
    (0x7D56,manager['APMAN_SCOPE_CANDIDATE']&255),(0x7D57,manager['APMAN_SCOPE_CANDIDATE']>>8)):
   lines += [f' LDA #${value:02X}',f' STA ${at:04X}']
  for i,value in enumerate(fnv(b'LEDCHECK').to_bytes(4,'little')):
   lines += [f' LDA #${value:02X}',f' STA ${0x7D47+i:04X}',f' STA ${0x7C70+i:04X}']
  lines+=[' LDA #$06',' STA $7E2F',' JSR CALL_AP',' STA $2431',' PHP',' PLA',' STA $2432']
  for at,value in zip(range(patch,patch+3),bytes.fromhex('8D A0 7F')):
   lines += [f' LDA #${value:02X}',f' STA ${at:04X}']
  for site in (select_site,restore_site):
   for at in range(site,site+3):lines += [f' LDA #${raw[at]:02X}',f' STA ${at:04X}']
  lines+=[' PLP',' RTS']
 lines+=['CALL_AP JMP ($7E2D)',' ORG $2300','LED_HOOK PHP',' PHA',' PHX',' PHY',
  ' STA $7FA0',' LDX $2430',' STA $2400,X',' INX',' STX $2430',' PLY',' PLX',' PLA',' PLP',' RTS',
  ' ORG $2340','SELECT_LOG JSR $F010',' JSR PCR_LOG',' JSR HOLD',' RTS',
  ' ORG $2350','RESTORE_LOG JSR $0203',' JMP PCR_LOG',
  ' ORG $2360','PCR_LOG PHP',' PHA',' PHX',' PHY',' LDX $2440',' LDA $7FEC',
  ' STA $2500,X',' INX',' STX $2440',' PLY',' PLX',' PLA',' PLP',' RTS',
  ' ORG $23A0','HOLD PHP',' PHA',' PHX',' PHY',
  ' LDA #$48',' STA $2433','DELAY_OUTER LDX #$FF','DELAY_MIDDLE LDY #$FF',
  'DELAY_INNER DEY',' BNE DELAY_INNER',' DEX',' BNE DELAY_MIDDLE',
  ' DEC $2433',' BNE DELAY_OUTER',' PLY',' PLX',' PLA',' PLP',' RTS',
  ' ORG $2400',' DS 64',' ORG $2600',' DB "LEDCHECK",0',' END']
 (folder/'driver.asm').write_text('\n'.join(lines)+'\n')
 for cmd in (['wdc02as','-G','-L','-S','-W','driver.asm'],['wdcln','-g','-s','-t','-hm19','-j','-o','driver.s19','driver.obj']):
  r=subprocess.run(cmd,cwd=folder,capture_output=True,text=True)
  with (folder/'build.log').open('a') as f:f.write(r.stdout+r.stderr)
  assert r.returncode==0,(cmd,r.stdout,r.stderr)
 data=srecord(folder/'driver.s19')
 data.update({0x3000+i:v for i,v in enumerate(baseline[0x10000:0x11000])})
 # Dense RAM image simplifies load/readback and never includes I/O or flash.
 blob=bytes(data.get(a,0) for a in range(0x2000,0x4000))
 write_s19(folder/'driver.s19',blob,0x2000,0x2000)
 m=Machine(build,baseline[-4096:])
 for bank in range(4):m.m.banks[bank][:]=baseline[bank*32768:(bank+1)*32768]
 m.m.ram[0x2000:0x4000]=blob
 sy=symbols(folder/'driver.map');requests=[];old=m.c.step
 def step():
  if m.c.pc==sy['DELAY_OUTER']:
   # Skip only the wall-clock delay in the host model; verify real loop bytes.
   assert bytes(m.m.ram[sy['DELAY_OUTER']:sy['DELAY_OUTER']+6])==bytes.fromhex('A2 FF A0 FF 88 D0')
   m.m.ram[0x2433]=1;m.c.pc=sy['DELAY_MIDDLE'];m.c.x=1
  if m.c.pc==sy['DELAY_MIDDLE']:m.c.pc=sy['DELAY_INNER'];m.c.y=1
  if m.c.pc in (0xF010,0x0203):requests.append(m.c.a)
  if m.m.bank!=3:assert m.c.pc<0x8000
  return old()
 m.c.step=step
 result=m.run(0x2000,limit=10_000_000)
 if mode=='roles':
  expected=[0]*23+[1];assert list(m.m.ram[0x2400:0x2418])==expected
  assert m.m.ram[0x2431]==0xAC and not requests
 else:
  bank=int(mode[-1]);expected=[] if bank==0 else [(s<<4)|bank for s in range(8,16) if (bank,s)!=(2,15)]
  assert m.m.ram[0x2430]==len(expected) and list(m.m.ram[0x2400:0x2400+len(expected)])==expected
  assert m.m.ram[0x2431]==0xD1 and 0 not in requests
  assert bytes(m.m.ram[patch:patch+3])==bytes.fromhex('8D A0 7F')
  assert m.m.ram[0x2440]==len(expected)*2
  pcr=[x&0xEE for x in m.m.ram[0x2500:0x2500+len(expected)*2]]
  assert pcr==([0xEC if bank==2 else 0xCE,0xEE]*len(expected))
  for site in (select_site,restore_site):assert bytes(m.m.ram[site:site+3])==bytes(raw[a] for a in range(site,site+3))
 receipts.append(dict(mode=mode,result='PASS',expected=expected,selector_requests=requests,linked_result=result,
  note='RAM-only instrumentation; host accelerates delay; hardware retains ~3-second holds at 8MHz'))
 print(mode,'PASS',expected,flush=True)
(HERE/'diagnostic-host-v2.json').write_text(json.dumps(dict(result='PASS',patch_address=patch,selector_sites=[select_site,restore_site],cases=receipts),indent=2)+'\n')
