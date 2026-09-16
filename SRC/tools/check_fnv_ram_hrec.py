"""Build and execute the private RAM-only HREC inspector, without board I/O."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from audit_himon_ap_contracts import ROOT, MPU, fnv, word
from report_himon_ap_baseline import srecord, symbols
from prepare_scoped_recovery import write_s19


def hrec(kind=1, name=b'RAMTEST', entry=0x3100, extra=0x3200):
    return b'FN\xD6'+word32(fnv(name))+bytes([kind])+(b'\x60' if kind==1 else word(entry)+word(extra))


def word32(value):
    return value.to_bytes(4, 'little')


class Memory:
    def __init__(self, code):
        self.data=bytearray([0xCC])*65536
        self.code=code
        for a,v in code.items():self.data[a]=v
        self.data[0x3000:0x4000]=b'\xFF'*4096
        self.data[0x7D40:0x7D60]=bytes(32)
        self.data[0x7D44:0x7D46]=bytes([1,8])
        self.data[0x7D47:0x7D4B]=word32(fnv(b'RAMTEST'))
        self.reads=set();self.writes=set()

    def __getitem__(self,a):
        assert (a in self.code or 0x100<=a<0x200 or 0xA0<=a<=0xA8 or
                0x3000<=a<0x4000 or 0x7D40<=a<0x7D60), ('out-of-contract read',hex(a))
        self.reads.add(a)
        return self.data[a]

    def __setitem__(self,a,v):
        assert (0x100<=a<0x200 or 0xA0<=a<=0xA8 or
                0x7D4B<=a<0x7D53 or 0x7D58<=a<0x7D60 or a==0x7E6A), ('out-of-contract write',hex(a))
        self.writes.add(a);self.data[a]=v


def execute(code, memory):
    cpu=MPU(memory=memory);cpu.pc=0x2000;cpu.sp=0xFF;cpu.p=0x20
    cpu.stPushWord(0x1FFE)
    for steps in range(2_000_000):
        if cpu.pc==0x1FFF:break
        assert cpu.pc in code, ('unexpected execution',hex(cpu.pc))
        cpu.step()
    else:raise AssertionError('instruction budget')
    assert cpu.sp==0xFF
    return cpu.a,bool(cpu.p&1),steps


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--build-dir',type=Path,default=ROOT/'SRC/BUILD/tmp/fnv-ram-hrec')
    args=p.parse_args();folder=args.build_dir.resolve();folder.mkdir(parents=True,exist_ok=True)
    source=ROOT/'SRC/APPS/fnv-ram-hrec-2000.asm'
    (folder/source.name).write_bytes(source.read_bytes())
    logs=[]
    for cmd in (['wdc02as','-G','-L','-S','-W',source.name],
                ['wdcln','-g','-s','-t','-hm19','-j','-o','fnv-ram-hrec-2000.s19','fnv-ram-hrec-2000.obj']):
        r=subprocess.run(cmd,cwd=folder,capture_output=True,text=True)
        logs.append(r.stdout+r.stderr)
        (folder/'build.log').write_text('\n'.join(logs))
        assert r.returncode==0,(cmd,r.stdout,r.stderr)
    code=srecord(folder/'fnv-ram-hrec-2000.s19');sy=symbols(folder/'fnv-ram-hrec-2000.map')
    assert min(code)==0x2000 and max(code)<0x3000
    assert sy['RAM_HREC_FIND']==0x2000 and sy['RAM_HREC_END']==max(code)+1
    cases=[]
    def check(name, patches=(), request=None, expected=0xD1, count=0, record=0, entry=0, extra=0, kind=0):
        m=Memory(code)
        for a,data in patches:m.data[a:a+len(data)]=data
        if request:
            for a,v in request.items():m.data[a]=v
        # Poison result fields: neither failure nor reuse can expose stale pointers.
        m.data[0x7D4B:0x7D53]=b'\xEE'*8;m.data[0x7D58:0x7D60]=b'\xEE'*8
        before=bytes(m.data)
        a,carry,steps=execute(code,m)
        assert (a,carry,m.data[0x7D4B])==(expected,expected==0xAC,count), (name,a,carry,m.data[0x7D4B])
        assert m.data[0x3000:0x4000]==before[0x3000:0x4000]
        assert m.data[0x7D4F:0x7D51]==word(record),(name,'record')
        assert m.data[0x7D58:0x7D5D]==word(entry)+word(extra)+bytes([kind]),(name,'metadata')
        assert m.data[0x7D4C:0x7D4F]==(bytes([1,255,3]) if carry else bytes(3))
        if expected==0xD4:assert not any(0x3000<=x<0x4000 for x in m.reads)
        cases.append(dict(case=name,result='PASS',status=f'{a:02X}',count=count,steps=steps,
                          provider_reads=len([x for x in m.reads if 0x3000<=x<0x4000])))

    check('empty')
    for address in (0x3000,0x30FC,0x3FEF,0x3FF7):
        check(f'inline-{address:04X}',[(address,hrec())],expected=0xAC,count=1,record=address,entry=address+8,kind=1)
    for k in (3,5):
        for address in (0x3000,0x3FF4):
            check(f'pointer-{k}-{address:04X}',[(address,hrec(k)),(0x3100,b'\x60'),(0x3200,b'TEX\xD4')],expected=0xAC,count=1,record=address,entry=0x3100,extra=0x3200,kind=k)
    for k in (0,2,4,6,7,0x81,0xFF):check(f'unsupported-kind-{k}',[(0x3000,hrec(k))])
    for target in (0,0x2FFF,0x4000,0x7F00,0x8000,0xFFFF):
        check(f'bad-entry-{target:04X}',[(0x3000,hrec(5,entry=target)),(0x3200,b'\xC1')])
        check(f'bad-extra-{target:04X}',[(0x3000,hrec(5,extra=target))])
    for text in (b'\x00',b'\x80',b'\xFF',b'ABC\x00'):
        check('bad-text-'+text.hex(),[(0x3000,hrec(5)),(0x3200,text)])
    check('unterminated-at-boundary',[(0x3000,hrec(5,extra=0x3FFF)),(0x3FFF,b'A')])
    check('terminated-at-boundary',[(0x3000,hrec(5,entry=0x3FFE,extra=0x3FFF)),(0x3FFE,b'\x60\xC1')],expected=0xAC,count=1,record=0x3000,entry=0x3FFE,extra=0x3FFF,kind=5)
    for address in range(0x3FF5,0x4000):
        check(f'truncated-pointer-{address:04X}',[(address,hrec(5)[:0x4000-address])])
    for address in range(0x3FF8,0x4000):
        check(f'truncated-inline-{address:04X}',[(address,hrec()[:0x4000-address])])
    check('wrong-hash',[(0x3000,hrec(name=b'OTHER'))])
    for index,value in enumerate(b'XXV'):
        data=bytearray(hrec());data[index]=value
        check(f'wrong-signature-{index}',[(0x3000,data)])
    check('loose-hash',[(0x3000,word32(fnv(b'RAMTEST')))])
    from check_fnv_scope import capsule
    check('ap-is-not-hrec',[(0x3000,capsule(name=b'RAMTEST'))])
    for n in (2,3,20):
        check(f'duplicate-{n}',[(0x3000+i*32,hrec()) for i in range(n)],expected=0xD2,count=2)
    for name,request in [('disabled',{0x7D44:0}),('no-window',{0x7D45:0}),('wrong-window',{0x7D45:4}),('mixed-window',{0x7D45:0x88}),('ap-format',{0x7D46:1}),('bad-format',{0x7D46:255}),('bank-request',{0x7D40:2})]:
        check(name,[(0x3000,hrec())],request,expected=0xD4)
    for policy in (0xFF,0xA6,0xA7):
        check(f'policy-does-not-enable-ram-{policy:02X}',[(0xFFF2,bytes([policy]))],{0x7D44:0},expected=0xD4)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    blob=bytes(code[a] for a in range(min(code),max(code)+1))
    # Publish only after every linked-byte case passes; exporter picks this up.
    out=ROOT/'SRC/BUILD/s19/fnv-ram-hrec-2000.s19'
    out.parent.mkdir(parents=True,exist_ok=True)
    write_s19(out,blob,0x2000,0x2000)
    result=dict(result='PASS',source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                binary_sha256=hashlib.sha256(blob).hexdigest(),bytes=len(blob),end_exclusive=f'{max(code)+1:04X}',
                contract='RAM-only metadata inspection; no execution or command integration',cases=cases)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(f'PASS {len(cases)} linked-byte RAM HREC cases; {len(blob)} bytes; no provider writes, I/O, flash or candidate execution')


if __name__=='__main__':main()
