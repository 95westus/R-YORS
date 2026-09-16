"""Exercise the installed manager and one onboard-built sacrificial AP."""
import re
import sys
from provision import HERE, ROOT, Board, dump, load, previous, save_json, archive, enter_str8
from audit_himon_ap_contracts import fnv, packed_name, word
from report_himon_ap_baseline import symbols

BODY = bytes.fromhex('00 00 A9 5A 38 60')
NAME = b'APTEST'


def expected_package():
    seal = b'\x01' + word(0x2000) + word(0x2000+len(BODY)) + word(len(BODY)) + fnv(BODY).to_bytes(4, 'little')
    export = b'\x01\x81' + word(2) + fnv(NAME).to_bytes(4, 'little') + bytes([len(NAME)]) + packed_name(NAME)
    sections = b''.join(bytes([tag])+word(len(data))+data for tag, data in
                       zip(b'SREIB', [seal, b'\x00', export, b'\x00', BODY]))
    return b'AP\x02'+word(len(sections)+5)+sections


def child_result(b, command):
    # Run outside the low staging area and the tested child destinations.
    # Exercise the resident MANAGER operation and its installed carrier.
    code = bytearray()
    for addr, value in [(0x7C60,1), (0x7E2F,4),
                        *[(0x7A00+i,v) for i,v in enumerate(command.encode()+b'\0')]]:
        code.extend(b'\xA9'+bytes([value])+b'\x8D'+word(addr))
    call = len(code); code.extend(b'\x20\0\0')
    code.extend(bytes.fromhex('8D 00 22 08 68 8D 01 22 60'))
    stub = 0x2100+len(code); code.extend(bytes.fromhex('6C 2D 7E'))
    code[call+1:call+3] = word(stub)
    assert len(code) < 0x100
    load(b, previous.transfer_file('child-return',[(0x2100,code),(0x2200,b'\xCC'*16)],0x2100))
    r = b.command('G 2100',seconds=30)
    assert b'GO 5002' in r
    result = dump(b,0x2200,0x220F)
    assert result[0] == 0x5A and result[1]&1


if __name__ == '__main__':
    mode = sys.argv[1]
    results = []
    if mode == 'manager':
        with Board() as b:
            r = b.command('APS', seconds=50)
            (HERE/'persistent-inventory.txt').write_bytes(r)
            assert b'APMAN' in r and b'BANKAUDIT' in r and b'MICROCHESS' in r
            assert b'APMAN NF' not in r and b'APMAN ERR' not in r
            results.append('persistent manager bootstrap and complete inventory')
            r = b.command('APS B2 APMAN', seconds=30)
            assert b'APS B2 8000 APC APMAN L=0C05 @7000' in r
            results.append('exact installed manager identity/length/load address')
            for cmd in ('AP D B2 APMAN', 'AP D B2 8000'):
                r = b.command(cmd, seconds=30)
                assert b'APD B2 8000 APC APMAN' in r and b'APMAN ERR' not in r
                results.append(cmd+' validates and inspects stored manager')
            for cmd in ('AP B2 APMAN 2000', 'AP L B2 APMAN 5000'):
                r = b.command(cmd, seconds=30)
                assert r.count(b'APMAN ERR=$DB') == 1 and b'AP LOAD' not in r and b'GO ' not in r
                assert dump(b, 0x7C60, 0x7C6F)[1] == 0xDB
                results.append(cmd+' self-execution guard')
            r = b.command('AP L B1 BANKAUDIT 5000', seconds=30)
            assert b'AP LOAD B1 8000 -> 5000' in r and b'GO ' not in r
            results.append('persistent manager loads linked child at 5000 without running')
            r = b.command('AP B1 BANKAUDIT 5000', seconds=50)
            assert b'BANKAUDIT OK; B3 RESTORED' in r and r.endswith(b'\r\n>')
            (HERE/'manager-bankaudit.txt').write_bytes(r)
            results.append('persistent manager links/runs BANKAUDIT at 5000 and returns')
            r = b.command('AP B2 ABSENT', seconds=30)
            assert r.count(b'APMAN ERR=$D1') == 1 and b'GO ' not in r
            assert dump(b, 0x7C60, 0x7C6F)[1] == 0xD1
            results.append('missing child returns one D1 diagnostic/status')
            assert dump(b, 0x8000, 0xFFFF) == (HERE/'enrolled-b3.bin').read_bytes()
        save_json('manager-tests.json', results)
    elif mode == 'install-fixture':
        assert not (HERE/'fixture-install-started.json').exists()
        source = ['ORG $2000', 'DB $00,$00', 'APTEST LDA #$5A', 'SEC', 'RTS', 'ENTRY APTEST', 'END']
        (HERE/'aptest-2000.a').write_text('\n'.join(source)+'\n')
        package = expected_package()
        (HERE/'aptest-expected.ap').write_bytes(package)
        with Board() as b:
            b.command('ASM NEW', until=r'ASM>\$2000: ')
            for line in source:
                r = b.command(line, until=r'SEAL> ' if line=='END' else r'ASM>\$[0-9A-F]{4}: ')
                assert b'ERR ' not in r
            r = b.command('PACKAGE APTEST 3000', until=r'SEAL> ')
            assert f'PKG OK @=$3000 L=${len(package):04X}'.encode() in r
            b.command('.')
            actual = dump(b, 0x3000, (0x3000+len(package)-1)|15)[:len(package)]
            (HERE/'aptest-onboard.ap').write_bytes(actual)
            assert actual == package, 'Onboard package differs from independent expected bytes'
            b.command('ASM S', until=r'SEAL> ')
            save_json('fixture-install-started.json', {'bank': 2, 'expected_sector': '9000', 'source': '3000', 'package_length': len(package)})
            r = b.command('INSTALL 3000 B2', until=r'ASM>\$2000: ', seconds=50)
            assert f'INST B2 9000 L={len(package):04X}'.encode() in r and b'SEAL> ' not in r
            b.command('.')
            sym = symbols(ROOT/'SRC/BUILD/s19/asm-v1-flash-8000.map')
            base = sym['ASM_SYM_COUNT']&0xFFF0
            data = dump(b, base, base+31)
            assert data[sym['ASM_SYM_COUNT']-base] == data[sym['ASM_FIX_COUNT']-base] == 0
            assert dump(b, 0x7C60, 0x7C6F)[1] == 0xAC
            assert dump(b, 0x3000, (0x3000+len(package)-1)|15)[:len(package)] == package
            assert dump(b, 0x8000, 0xFFFF) == (HERE/'enrolled-b3.bin').read_bytes()
            results.extend(['onboard source/package exactly matches independent expected AP bytes',
                            'ASM INSTALL writes B2:9 through carried worker and returns AC',
                            'INSTALL returns fresh ASM at 2000 with zero symbol/fixup counts',
                            'INSTALL preserves source package and all Bank 3 bytes'])
        save_json('install-tests.json', results)
    elif mode == 'fixture':
        with Board() as b:
            r = b.command('APS B2 APTEST', seconds=30)
            assert f'APS B2 9000 APC APTEST L={len(expected_package()):04X} @2000'.encode() in r
            r = b.command('AP D B2 APTEST', seconds=30)
            assert b'APD B2 9000 APC APTEST' in r and b'APMAN ERR' not in r
            for dst in (0x2000, 0x5000, 0x6FFA):
                r = b.command(f'AP B2 APTEST {dst:04X}', seconds=30)
                assert f'GO {dst+2:04X}'.encode() in r and r.endswith(b'\r\n>')
                base = dst&0xFFF0
                actual = dump(b, base, (dst+len(BODY)-1)|15)
                assert actual[dst-base:dst-base+len(BODY)] == BODY
                results.append(f'APTEST exact BODY at {dst:04X}; entry +2; return to HIMON')
            child_result(b, 'AP B2 APTEST 5000')
            results.append('resident MANAGER + persistent child RTS returns A=5A/C=1 to RAM caller')
            load(b, previous.transfer_file('boundary-sentinel', [(0x6FF0,b'\xCC'*16)],0x6FF0))
            r = b.command('AP B2 APTEST 6FFB', seconds=30)
            assert b'APMAN ERR=$D4' in r and b'GO ' not in r
            assert dump(b,0x6FF0,0x6FFF) == b'\xCC'*16
            results.append('BODY crossing 7000 rejected before copy; redzone preserved')
            r = b.command('ASM S'); assert b'EXEC ERR=$03' in r
            results.append('ASM stale resume refused after persistent takeover')
            for kind in ('W','C'):
                enter_str8(b)
                r = b.command(kind, seconds=20)
                assert b'HIMON V 00.0915(2324)' in r
                assert dump(b,0x7E60,0x7E6F)[10] == 0
                r = b.command('AP B2 APTEST 5000', seconds=30)
                assert b'GO 5002' in r and r.endswith(b'\r\n>')
                results.append('persistent AP after STR8 software '+kind+' entry')
        save_json('fixture-tests.json', results)
    elif mode == 'archive-final':
        archive.archive(HERE/'final-readback', [0,1,2,3])
        for bank in (0,1):
            assert (HERE/f'final-readback/bank{bank}.bin').read_bytes() == (HERE/f'before-readback/bank{bank}.bin').read_bytes()
        pkg = expected_package()
        expected = (HERE/'apman-v1-bank2-8000.bin').read_bytes()+pkg+b'\xFF'*(0x7000-len(pkg))
        assert (HERE/'final-readback/bank2.bin').read_bytes() == expected
        assert (HERE/'final-readback/bank3.bin').read_bytes() == (HERE/'enrolled-b3.bin').read_bytes()
        results.append('exact final four-bank readback; only authorized B2 and D2 changes')
        save_json('isolation-tests.json', results)
    print('PASS', mode, *results, sep='\n')
