"""Focused offline preparation checks; no serial, no physical flash access."""
import argparse
import json
from pathlib import Path
import sys
from prepare_scoped_recovery import ROOT, STR8, sha, read_s19

sys.path.insert(0, str(STR8/'tools'))
from test_worker_optimization import FlashMemory, MPU, PCR, LED, symbols
from test_conservative_resident import Run

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--bundle',type=Path,default=ROOT/'LOCAL/scoped-recovery-20260916')
    out=ap.parse_args().bundle.resolve()
    manifest=json.loads((out/'manifest.json').read_text())
    for name,digest in manifest['files'].items():
        assert sha((out/name).read_bytes())==digest,name
    baseline=(out/'baseline-flash-128k.bin').read_bytes()
    receipts=[]
    for policy,expected in ((0xA6,0xFF),(0xFF,0xA6)):
        folder=out/f'policy-{policy:02x}'
        sym=symbols(folder/'policy.map')
        memory,entry=read_s19(folder/'policy.s19')
        assert set(memory)==set(range(0x2000,0x5000)) and entry==0x2000
        target=(folder/'top.bin').read_bytes()
        assert target[:0xFF2]==baseline[-4096:-14] and target[0xFF3:]==baseline[-13:]

        def setup(change=None):
            mem=FlashMemory(b'')
            for bank in range(4):mem.banks[bank][:]=baseline[bank*32768:(bank+1)*32768]
            mem.banks[3][0x7FF2]=expected
            # A realistic completed install changes journal bytes. The policy
            # updater must preserve live metadata, not restore frozen journals.
            mem.banks[3][0x7FEC]=0
            if change:mem.banks[3][change[0]-0x8000]=change[1]
            mem.ram[PCR]=0xEE;mem.ram[LED]=0xF0
            for a,b in memory.items():mem.ram[a]=b
            return mem,MPU(memory=mem)

        def run(mem,cpu,start,stops,answers):
            cpu.pc=sym[start];cpu.sp=255
            answers=iter(answers);messages=[]
            for _ in range(4_000_000):
                if cpu.pc in stops:return messages
                assert 0x2000<=cpu.pc<0x4000,hex(cpu.pc)
                if cpu.pc in (sym['TU_PUTS'],sym['TU_READ_LINE'],sym['TU_OUT']):
                    if cpu.pc==sym['TU_READ_LINE']:
                        data=next(answers).encode()+b'\0'
                        mem.ram[sym['TU_INPUT']:sym['TU_INPUT']+len(data)]=data
                    elif cpu.pc==sym['TU_PUTS']:
                        a=cpu.x|(cpu.y<<8);end=a
                        while mem.ram[end]:end+=1
                        messages.append(bytes(mem.ram[a:end]).decode('ascii'))
                    cpu.pc=(cpu.stPopWord()+1)&65535
                else:cpu.step()
            raise AssertionError(('instruction limit',hex(cpu.pc)))

        mem,cpu=setup();old=bytes(mem.banks[3][0x7000:])
        messages=run(mem,cpu,'START',{sym['TU_SUCCESS']},['BACKUP B2F',f'POLICY {policy:02X}'])
        want=bytearray(old);want[0xFF2]=policy
        assert bytes(mem.banks[3][0x7000:])==want
        assert bytes(mem.banks[2][0x7000:])==old
        assert any(f'TYPE POLICY {policy:02X}>' in m for m in messages)
        assert all((bank==2 and at>=0xF000) or (bank==3 and at>=0xF000) for _,bank,at,_ in mem.mutations)
        assert bytes(mem.banks[0])+bytes(mem.banks[1])==baseline[:65536]
        assert bytes(mem.banks[2][:0x7000])==baseline[0x10000:0x17000]
        assert bytes(mem.banks[3][:0x7000])==baseline[0x18000:0x1F000]
        # Actual RAM recovery branches after simulated interruption; no claim
        # about electrical failure timing or power-loss survival of RAM.
        for choice in ('R','O'):
            mem.banks[3][0x7000:]=b'\0'*4096
            stop=sym['TU_SUCCESS'] if choice=='R' else sym['TU_ARM_SOFT_RESET']
            run(mem,cpu,'TU_RECOVERY',{stop},[choice])
            assert bytes(mem.banks[3][0x7000:])==(want if choice=='R' else old)
        receipts.append(dict(case=f'policy-{policy:02X}',result='PASS',
            backup_exact=True,live_journal_preserved=True,retry_and_restore=True,
            only_mutations=['B2:F','B3:F']))
        for address,value in ((0xFFF0,0x1E),(0xFFF1,0x1F),(0xFFF2,policy),(0xFFF2,0xA7)):
            mem,cpu=setup((address,value))
            run(mem,cpu,'START',{0xF000},[])
            assert not mem.mutations and mem.ram[sym['TU_STATUS']]==0xE0
            receipts.append(dict(case=f'policy-{policy:02X}-reject-{address:04X}-{value:02X}',result='PASS'))
        mem,cpu=setup()
        run(mem,cpu,'START',{0xF000},[''])
        assert not mem.mutations
        mem,cpu=setup();old=bytes(mem.banks[3])
        run(mem,cpu,'START',{0xF000},['BACKUP B2F',''])
        assert bytes(mem.banks[3])==old
        assert all(bank==2 and at>=0xF000 for _,bank,at,_ in mem.mutations)
        receipts.append(dict(case=f'policy-{policy:02X}-cancel-both-prompts',result='PASS'))

    # Run linked STR8 dense receiver against every exact paired payload.
    # Console and sector-worker dispatch are intercepted. This proves S19
    # framing, staging/order, and final commit, not electrical programming.
    for path in sorted(out.glob('*.s19')):
        memory,entry=read_s19(path)
        start,end=min(memory),max(memory)+1
        assert set(memory)==set(range(start,end)) and start%4096==end%4096==0
        payload=bytes(memory[a] for a in range(start,end))
        assert payload==path.with_suffix('.bin').read_bytes()
        bank=2 if '-b2-' in path.stem else 3
        r=Run(1);r.console(path.read_bytes())
        r.mem[0x90],r.mem[0x97]=bank,1
        r.mem[0xA1:0xA3]=[start>>8,(end>>8)&255]
        calls=[]
        def worker():
            calls.append(('sector',r.mem[0x7DE9],bytes(r.mem[0xA00:0x1A00])))
            r.carry(True)
        def confirm():calls.append(('commit',));r.carry(True)
        r.hook('STR8_I_RUN_SECTOR_WORKER',worker)
        r.hook('STR8_I_CONFIRM_COMMIT',confirm)
        r.run('STR8_I_RECEIVE_DENSE',limit=12_000_000)
        assert r.cpu.p&1,path
        sectors=[c for c in calls if c[0]=='sector']
        assert b''.join(c[2] for c in sectors)==payload
        assert len(sectors)==len(payload)//4096 and calls[-2]==('commit',)
        receipts.append(dict(case=path.name,result='PASS',bank=bank,bytes=len(payload),
            scope='linked dense receiver; worker and console intercepted'))
    # Exact preservation properties of complete recovery images.
    assert (out/'recovery-old-b2-8-f.bin').read_bytes()==baseline[0x10000:0x18000]
    assert (out/'recovery-old-b3-8-e.bin').read_bytes()==baseline[0x18000:0x1F000]
    assert (out/'recovery-new-b2-8-f.bin').read_bytes()[4096:]==baseline[0x11000:0x18000]
    assert (out/'recovery-new-b3-8-e.bin').read_bytes()[:0x4000]==baseline[0x18000:0x1C000]
    # Full STR8 I admission, START/COMPLETE journal, and paired sequence.
    # Only physical worker dispatch and directory byte programming are stubbed.
    r=Run(1)
    r.mem[0xF000:]=baseline[-4096:]
    banks=[bytearray(baseline[i*32768:(i+1)*32768]) for i in range(4)]
    writes=[]
    def directory_write():
        at=r.mem[0x7E9E]|r.mem[0x7E9F]<<8
        count=r.mem[0x7EA0]
        assert 0xFFB0<=at and at+count<=0xFFF0
        for i in range(count):
            value=r.mem[0x7B00+i]
            assert r.mem[at+i]&value==value
            r.mem[at+i]=value
            writes.append(('journal',at+i,value))
        r.cpu.a=0;r.carry(True)
    def program_sector():
        bank=r.mem[0x90];at=r.mem[0x7DE9]<<8
        assert bank in (2,3) and 0x8000<=at<=0xF000
        assert bank!=3 or at<0xF000
        banks[bank][at-0x8000:at-0x8000+4096]=r.mem[0xA00:0x1A00]
        writes.append(('sector',bank,at))
        r.carry(True)
    r.hook('STR8_COPY_WORKER_TO_RAM',lambda:r.carry(True))
    r.hook('STR8_DIR_WRITE_BYTES',directory_write)
    r.hook('STR8_I_RUN_SECTOR_WORKER',program_sector)
    def install(name,bank,span,success=True):
        r.output=[]
        r.mem[0x7B00:0x7B02]=[ord('I'),0]  # command loop normally supplies this
        r.console(f'{bank}\r{span}\rY\r'.encode()+(out/(name+'.s19')).read_bytes()+b'Y\r')
        r.run('STR8_CMD_INSTALL_PREVIEW',limit=15_000_000)
        output=bytes(r.output)
        assert (b'OK' in output)==success,(name,output)
        receipts.append(dict(case='command-'+name,result='PASS',accepted=success,
            output=output.decode('ascii','replace')))
    install('candidate-am02-b2-8',2,'8')
    install('candidate-himon-b3-c-e',3,'C-E')
    assert bytes(r.mem[0xF000:])==(out/'expected-paired-policy-ff-top.bin').read_bytes()
    assert bytes(banks[2][:4096])==(out/'candidate-am02-b2-8.bin').read_bytes()
    assert bytes(banks[3][0x4000:0x7000])==(out/'candidate-himon-b3-c-e.bin').read_bytes()
    install('rollback-himon-b3-c-e',3,'C-E')
    install('rollback-am01-b2-8',2,'8')
    assert bytes(banks[2])==baseline[0x10000:0x18000]
    assert bytes(banks[3])==baseline[0x18000:0x20000]
    # Simulate START without COMPLETE at the next unused pair, then demonstrate
    # refusal of a narrow retry and acceptance of the archived full recovery.
    for bank,span,narrow,full in ((2,'8','rollback-am01-b2-8','recovery-old-b2-8-f'),
                                (3,'C-E','rollback-himon-b3-c-e','recovery-old-b3-8-e')):
        start=0xFFBC+16*bank
        for pair in range(16):
            at=start+pair//4;shift=(pair%4)*2
            if (r.mem[at]>>shift)&3==3:
                r.mem[at]&=~(1<<shift);break
        else:raise AssertionError('journal exhausted')
        previous=len(writes)
        install(narrow,bank,span,False)
        assert len(writes)==previous
        install(full,bank,'8-F' if bank==2 else '8-E')
    changes=[hex(a) for a in range(0xF000,0x10000) if r.mem[a]!=baseline[a+0x10000]]
    assert all(0xFFDC<=int(a,16)<=0xFFDF or 0xFFEC<=int(a,16)<=0xFFEF for a in changes)
    receipts.append(dict(case='paired-journal-isolation',result='PASS',changed_top_addresses=changes))
    result=dict(result='PASS',board_access=False,cases=receipts,
        limitations=['No electrical proof; pair command tests intercept physical worker and directory byte writes',
        'Select the B2 full recovery image for the actual backup generation; fresh archive must match the checkpoint'])
    (out/'host-check.json').write_text(json.dumps(result,indent=2)+'\n')
    print(f'PASS: {len(receipts)} focused policy/recovery checks; no board access')

if __name__=='__main__':main()
