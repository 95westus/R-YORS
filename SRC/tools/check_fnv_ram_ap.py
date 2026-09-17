"""Linked RAM AP + bank uniqueness proof using current private helpers."""
import argparse,json,hashlib,subprocess
from pathlib import Path
from audit_himon_ap_contracts import ROOT,Machine,fnv,word,import_record
from report_himon_ap_baseline import srecord,symbols
from check_fnv_scope import capsule
from prepare_scoped_recovery import write_s19

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--output',type=Path,required=True)
 args=p.parse_args();build=ROOT/'SRC/BUILD';folder=build/'tmp/fnv-ram-ap';folder.mkdir(parents=True,exist_ok=True)
 hs=symbols(build/'s19/himon-rom-c000.map');ms=symbols(build/'s19/apman-7000.map')
 names={'HIM_FNV_MATCH_NAME':hs['HIM_FNV_MATCH_NAME'],**{n:ms[n] for n in ('APMAN_SCOPE_CANDIDATE','APMAN_FIND_ENTRY_ROW')}}
 (folder/'image-addresses.inc').write_text(''.join(f'{n} EQU ${v:04X}\n' for n,v in names.items()))
 source=ROOT/'SRC/APPS/fnv-ram-ap-2000.asm';(folder/source.name).write_bytes(source.read_bytes())
 logs=[]
 for cmd in (['wdc02as','-G','-L','-S','-W',source.name],['wdcln','-g','-s','-t','-hm19','-j','-o','fnv-ram-ap-2000.s19','fnv-ram-ap-2000.obj']):
  r=subprocess.run(cmd,cwd=folder,capture_output=True,text=True);logs.append(r.stdout+r.stderr)
  (folder/'build.log').write_text('\n'.join(logs));assert r.returncode==0,(cmd,r.stdout,r.stderr)
 code=srecord(folder/'fnv-ram-ap-2000.s19');sy=symbols(folder/'fnv-ram-ap-2000.map')
 assert min(code)==0x2000 and max(code)<0x2600 and sy['RAM_AP_END']==max(code)+1
 top=(ROOT.parent/'STR8-N/BUILD/v1.35/bin/str8n-v1.35-bank3-f000-ffff.bin').read_bytes()
 cases=[]
 def check(name,ram=(),banks=(),request=7,windows=255,enable=1,ramwindows=8,policy=0xA6,fmt=1,namelen=7,nameptr=0x2F00,
           status=0xD1,count=0,source=0,bank=0,window=0,address=0,offset=0,bodylen=0,fail_restore=False,mutate_unique=False):
  m=Machine(build,top);m.m.banks[3][0x7FF0:0x7FF3]=bytes([255,0x2F,policy])
  for b,s,data in banks:m.m.banks[b][(s-8)*4096:(s-7)*4096]=data.ljust(4096,b'\xFF')
  for a,v in srecord(build/'s19/apman-7000.s19').items():m.m.ram[a]=v
  for a,v in code.items():m.m.ram[a]=v
  m.m.ram[0x3000:0x4000]=b'\xFF'*4096
  for a,data in ram:m.m.ram[a:a+len(data)]=data
  m.m.ram[0x2F00:0x2F08]=b'RAMTEST\0'
  card=bytearray(32);card[0]=request;card[3:7]=bytes([windows,enable,ramwindows,fmt]);card[7:11]=fnv(b'RAMTEST').to_bytes(4,'little')
  card[19:22]=word(nameptr)+bytes([namelen]);card[11:17]=b'\xEE'*6;card[24:]=b'\xEE'*8
  m.m.ram[0x7D40:0x7D60]=card
  parent=type(m.m)
  class BoundedMemory(parent):
   def __getitem__(self,a):
    if isinstance(a,int):
     assert not 0x4000<=a<0x6C00,('outside provider window',name,hex(a))
     if 0x7F00<=a<0x8000:assert a in (0x7FA0,0x7FEC),('unexpected I/O read',hex(a))
    return super().__getitem__(a)
   def __setitem__(self,a,v):
    assert not 0x3000<=a<0x6C00,('provider/outside workspace write',name,hex(a))
    if 0x7F00<=a<0x8000:assert a in (0x7FA0,0x7FEC),('unexpected I/O write',hex(a))
    return super().__setitem__(a,v)
  m.m.__class__=BoundedMemory
  before=bytes(m.m.ram[0x3000:0x4000]);requests=[];stages=[];injected=[];prior=m.c.step
  def step():
   pc=m.c.pc
   assert not (0x3000<=pc<0x4000 or 0x0A00<=pc<0x1A00),('provider execution',name,pc)
   assert pc not in (hs['HIM_AP_LOAD_PARSED'],hs['HIM_AP_IMPORT_LINK']),('load/link',name,pc)
   if m.m.bank!=3:assert pc<0x8000,('foreign ROM fetch',pc)
   if pc in (0xF010,0x0203):requests.append(m.c.a)
   if pc==ms['APMAN_STAGE_RAW']:stages.append([m.m.ram[0xA7],m.m.ram[0xA8]])
   if fail_restore and stages and not injected and pc==0x0203:
    injected.append(True);m.c.p &=~1;m.c.pc=(m.c.stPopWord()+1)&65535;return
   if mutate_unique and pc==sy['RAM_AP_CANDIDATE'] and m.m.ram[0x7D4B]==1 and not injected:
    injected.append(True);m.m.ram[0x3000]=0
   return prior()
  m.c.step=step;r=m.run(0x2000,limit=8_000_000)
  actual=m.m.ram[0x7D40:0x7D60]
  assert (r['a'],r['carry'],actual[11])==(status,status==0xAC,count),(name,r,actual.hex())
  assert actual[12:17]==bytes([source,bank,window])+word(address),(name,'location',actual.hex())
  assert actual[24:28]==word(offset)+word(bodylen),(name,'metadata',actual.hex())
  assert actual[4]==enable and m.m.bank==3
  assert not any(0x2000<=a<0x2600 or 0x2F00<=a<0x4000 for a in m.m.writes),(name,'provider/code/name writes')
  if not mutate_unique:assert bytes(m.m.ram[0x3000:0x4000])==before
  if status==0xD4:assert not requests and not any(0xA00<=a<0x1A00 for a in m.m.writes)
  if status!=0xD4:
   visited=[[b,s<<4] for b in (2,1,0) if request&(1<<b) and policy&0xF8==0xA0 and policy&(1<<b)
            for s in range(8,16) if windows&(1<<(s-8)) and (b,s)!=(2,15)]
   assert stages[:len(visited)]==visited or fail_restore,(name,'traversal order',stages,visited)
  if policy==0xA6:assert 0 not in requests
  if fail_restore or mutate_unique:assert injected
  cases.append(dict(case=name,result='PASS',status=f'{status:02X}',count=count,selector_requests=requests,stages=stages,steps=r['steps']))
  print(name,'PASS',flush=True)
 good=capsule(name=b'RAMTEST')
 check('empty',request=0)
 for a in (0x3000,0x30FD,0x4000-len(good)):
  check(f'unique-ram-{a:04X}',[(a,good)],request=0,status=0xAC,count=1,source=1,bank=255,window=3,address=a,bodylen=4)
 check('ram-unique-with-empty-banks',[(0x3000,good)],status=0xAC,count=1,source=1,bank=255,window=3,address=0x3000,bodylen=4)
 check('ram-flash-duplicate',[(0x3000,good)],[(2,9,good)],status=0xD2,count=2)
 check('ram-two-duplicate',[(0x3000,good),(0x3200,good)],request=0,status=0xD2,count=2)
 check('twenty-ram-saturates',[(0x3000+i*128,good) for i in range(20)],request=0,status=0xD2,count=2)
 check('entry-offset-metadata',[(0x3000,capsule(name=b'RAMTEST',offset=3))],request=0,status=0xAC,count=1,source=1,bank=255,window=3,address=0x3000,offset=3,bodylen=4)
 check('unresolved-import-is-not-linked',[(0x3000,capsule(name=b'RAMTEST',imports=import_record(1,b'NO_SUCH_IMPORT')))],request=0,status=0xAC,count=1,source=1,bank=255,window=3,address=0x3000,bodylen=4)
 check('three-plus-bank-saturates',[(0x3000,good),(0x3200,good),(0x3400,good)],[(1,9,good)],status=0xD2,count=2)
 check('bank-duplicate-with-ram',[(0x3000,good)],[(2,9,good),(1,9,good)],status=0xD2,count=2)
 for label,data in [('bad-crc',good[:-1]+b'\0'),('forged-name',capsule(name=b'NOTTEST',hash_name=b'RAMTEST')),
   ('bad-entry',capsule(name=b'RAMTEST',offset=4)),('bad-kind',capsule(name=b'RAMTEST',flags=0x82)),
   ('bad-pack40',capsule(name=b'RAMTEST',packed=b'\xFF'*6)),('bad-sections',b'AP\x02\x05\x00')]:
  check(label,[(0x3000,data)],request=0)
 check('malformed-ram-valid-bank',[(0x3000,good[:-1]+b'\0')],[(2,9,good)],status=0xAC,count=1,source=2,bank=2,window=0x90,address=0x9000,bodylen=4)
 check('bank-only',banks=[(1,10,good)],enable=0,status=0xAC,count=1,source=2,bank=1,window=0xA0,address=0xA000,bodylen=4)
 check('disabled-ram-not-counted',[(0x3000,good)],[(2,9,good)],enable=0,status=0xAC,count=1,source=2,bank=2,window=0x90,address=0x9000,bodylen=4)
 check('window-excludes-bank-duplicate',[(0x3000,good)],[(2,9,good)],windows=1,status=0xAC,count=1,source=1,bank=255,window=3,address=0x3000,bodylen=4)
 check('request-excludes-bank-duplicate',[(0x3000,good)],[(2,9,good)],request=2,status=0xAC,count=1,source=1,bank=255,window=3,address=0x3000,bodylen=4)
 for pol in (255,0xA0,0,0xE6):
  check(f'policy-{pol:02X}-ram-independent',[(0x3000,good)],[(2,9,good)],policy=pol,status=0xAC,count=1,source=1,bank=255,window=3,address=0x3000,bodylen=4)
 check('excluded-b0-does-not-duplicate',[(0x3000,good)],[(0,9,good)],status=0xAC,count=1,source=1,bank=255,window=3,address=0x3000,bodylen=4)
 check('enrolled-b0-duplicates',[(0x3000,good)],[(0,9,good)],policy=0xA7,status=0xD2,count=2)
 check('protected-backup-not-counted',[(0x3000,good)],[(2,15,good)],status=0xAC,count=1,source=1,bank=255,window=3,address=0x3000,bodylen=4)
 for a,data in [(0x3FFD,b'AP\x02'),(0x3FFB,b'AP\x02\x06\x00'),(0x3000,b'AP\x02\xFF\xFF'),(0x3000,b'AP\x02\x00\x00')]:
  check(f'bad-length-{a:04X}-{data.hex()}',[(a,data)],request=0)
 for label,kwargs in [('hrec-format',dict(fmt=0)),('invalid-format',dict(fmt=255)),('no-window',dict(ramwindows=0)),
   ('extra-window',dict(ramwindows=0x88)),('unstable-name',dict(nameptr=0x3000)),('empty-name',dict(namelen=0)),('long-name',dict(namelen=32))]:
  check(label,[(0x3000,good)],status=0xD4,**kwargs)
 check('restore-failure-overrides-ram',[(0x3000,good)],[(2,9,good)],status=0xD9,count=0,fail_restore=True)
 check('ram-revalidation-fails',[(0x3000,good)],request=0,status=0xD1,count=1,mutate_unique=True)
 blob=bytes(code[a] for a in range(min(code),max(code)+1));out=build/'s19/fnv-ram-ap-2000.s19'
 write_s19(out,blob,0x2000,0x2000)
 inputs={n:hashlib.sha256((build/n).read_bytes()).hexdigest() for n in ('s19/himon-rom-c000.s19','s19/apman-7000.s19')}
 result=dict(result='PASS',bytes=len(blob),end_exclusive=f'{max(code)+1:04X}',binary_sha256=hashlib.sha256(blob).hexdigest(),private_addresses=names,inputs=inputs,cases=cases)
 args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2)+'\n')
 print(f'PASS {len(cases)} RAM AP/combined uniqueness cases; {len(blob)} bytes',flush=True)

if __name__=='__main__':main()
