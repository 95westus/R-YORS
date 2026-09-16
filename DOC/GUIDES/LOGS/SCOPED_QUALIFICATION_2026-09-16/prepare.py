from pathlib import Path
import sys,json,hashlib
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sys.path.insert(0,str(ROOT/'SRC/tools'))
from check_fnv_scope import capsule
from audit_himon_ap_contracts import Machine,fnv,word,import_record
from report_himon_ap_baseline import srecord,symbols
sys.path.insert(0,str(ROOT.parent/'STR8-N/tools'))
from test_conservative_resident import Run
from prepare_scoped_recovery import write_s19
baseline=(HERE/'before/flash-128k.bin').read_bytes()
assert hashlib.sha256(baseline).hexdigest()=='8e75c342dcee502c1fcf5c1f2e5e024f88f4f91551bf6b4a0b9440379afff45e'
for bank in (1,2):assert baseline[bank*32768+0x2000:bank*32768+0x3000]==b'\xff'*4096
build=ROOT/'SRC/BUILD'
image=srecord(build/'s19/bank-dump-2000.s19');sym=symbols(build/'s19/bank-dump-2000.map')
body=bytes(image[a] for a in sorted(image));assert len(body)==0x92C and fnv(body)==0xCEF1F837
names=[b'BIO_FTDI_PUT_CSTR',b'SYS_READ_CSTRING_ECHO_UPPER',b'BIO_FTDI_WRITE_BYTE_BLOCK']
sites=[sym['PUTS']+1,sym['READ_LINE']+5,sym['PUTC']+1]
offsets=[a-0x2000 for a in sites]
imports=bytes([3])+b''.join(import_record(1,n)[1:] for n in names)
reloc=bytes([3])+b'\x04'*3+bytes(a&255 for a in offsets)+bytes(a>>8 for a in offsets)+bytes(range(3))+b'\0'*3
fixtures={
 'bankdump':capsule(body=body,imports=imports,reloc=reloc),
 'erased':b'\xff'*4096,
 'bad-crc':capsule()[:-1]+b'\0',
 'forged-name':capsule(name=b'NOTDUMPX',hash_name=b'BANKDUMP'),
 'bad-entry':capsule(offset=0xFFFF),
 'bad-import':capsule(body=b'\x20\0\0\x60',imports=import_record(1,b'NO_SUCH_IMPORT'),reloc=b'\x01\x04\x01\x00\x00\x00'),
 'resident-shadow':capsule(name=b'FNV1A_INIT'),
}
assert len(fixtures['bankdump'])==0x9AD
steps=[(2,'bankdump'),(1,'bankdump'),(2,'erased'),(1,'bad-crc'),(1,'forged-name'),
       (1,'bad-entry'),(1,'bad-import'),(1,'resident-shadow'),(1,'erased'),(2,'bankdump')]
r=Run(1);r.mem[0xF000:]=baseline[-4096:]
banks=[bytearray(baseline[i*32768:(i+1)*32768]) for i in range(4)]
events=[];receipts=[];plan=[]
def directory_write():
 at=r.mem[0x7E9E]|r.mem[0x7E9F]<<8;count=r.mem[0x7EA0]
 assert 0xFFC0<=at and at+count<=0xFFE0
 for i in range(count):
  v=r.mem[0x7B00+i];assert r.mem[at+i]&v==v;r.mem[at+i]=v
 r.cpu.a=0;r.carry(True)
def worker():
 bank=r.mem[0x90];at=r.mem[0x7DE9]<<8
 assert bank in (1,2) and at==0xA000
 banks[bank][0x2000:0x3000]=r.mem[0xA00:0x1A00];events.append((bank,at));r.carry(True)
r.hook('STR8_COPY_WORKER_TO_RAM',lambda:r.carry(True));r.hook('STR8_DIR_WRITE_BYTES',directory_write)
r.hook('STR8_I_RUN_SECTOR_WORKER',worker)
for number,(bank,name) in enumerate(steps,1):
 stem=f'{number:02d}-b{bank}a-{name}'
 data=fixtures[name].ljust(4096,b'\xff')
 (HERE/(stem+'.bin')).write_bytes(data);write_s19(HERE/(stem+'.s19'),data,0xA000,0xFFFF)
 r.mem[0x7B00:0x7B02]=[ord('I'),0];r.output=[]
 descriptor=b'A2\rAPC01\r' if number==2 else b''
 r.console(f'{bank}\rA\r'.encode()+descriptor+b'Y\r'+(HERE/(stem+'.s19')).read_bytes()+b'Y\r')
 r.run('STR8_CMD_INSTALL_PREVIEW',limit=10_000_000)
 assert b'OK' in bytes(r.output),(stem,bytes(r.output))
 expected=b''.join(bytes(b) for b in banks[:3])+bytes(banks[3][:0x7000])+bytes(r.mem[0xF000:])
 (HERE/(stem+'-expected.bin')).write_bytes(expected)
 plan.append(dict(number=number,bank=bank,sector='A',fixture=name,stem=stem,new_descriptor=number==2,
  expected_sha256=hashlib.sha256(expected).hexdigest(),install_console=bytes(r.output).decode('ascii')))
 # Run the real finder against this exact flash checkpoint; stop before the
 # BANKDUMP menu, then verify named imports. No flash writes are allowed.
 m=Machine(build,expected[-4096:])
 for i in range(4):m.m.banks[i][:]=expected[i*32768:(i+1)*32768]
 requests=[];oldstep=m.c.step
 def traced():
  if m.c.pc in (0xF010,0x0203):requests.append(m.c.a)
  if m.m.bank!=3:assert m.c.pc<0x8000
  return oldstep()
 m.c.step=traced
 text=b'FNV1A_INIT' if name=='resident-shadow' else b'BANKDUMP'
 m.m.ram[0x7A00:0x7A00+len(text)+1]=text+b'\0';m.setword('CMDP_PTR_LO',0x7A00)
 if name=='resident-shadow':
  m.run('CMD_HASH_TOKEN');result=m.run('CMD_DISPATCH_HASH',stop=m.s['MAIN_LOOP']);assert not requests
 else:
  success=number in (1,3,10)
  result=m.run('HIM_FNV_FALLBACK',stop=0x2000 if success else None,limit=9_000_000)
  assert 0 not in requests
  if success:
   assert m.c.pc==0x2000 and 'GO 2000' in result['output']
   for site,targetname in zip(sites,names):
    # Published resolver identity, not pinned historical fixture addresses.
    m.m.ram[0x3000:0x3004]=fnv(targetname).to_bytes(4,'little')
    found=m.run('THE_JOIN_EXEC_XY',x=0,y=0x30)
    assert found['carry'] and m.m.ram[site:site+2]==word(found['x']|(found['y']<<8))
  else:
   status=0xD2 if number==2 else 0xD3 if name=='bad-import' else 0xD1
   assert result['manager_status']==status and 'GO ' not in result['output'],(stem,result)
 receipts.append(dict(case=stem,result='PASS',resolver=result,selector_requests=requests))
 print(stem,'host PASS',flush=True)
(HERE/'plan.json').write_text(json.dumps(plan,indent=2)+'\n')
(HERE/'fixture-host.json').write_text(json.dumps(dict(result='PASS',cases=receipts,
 caveat='STR8 I console and physical worker/directory writes intercepted; real receiver, journal logic, finder and linker execute'),indent=2)+'\n')
print('All planned fixture transitions and resolver cases PASS',flush=True)
