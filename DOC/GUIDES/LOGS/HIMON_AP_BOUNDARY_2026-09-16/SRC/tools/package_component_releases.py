"""Create explicit, separately verified HIMON and ASM-F2 release archives."""
import argparse
from contextlib import contextmanager
from datetime import datetime
import json
import posixpath
from pathlib import Path
import re
import shutil
import subprocess
import uuid
import zipfile
from urllib.parse import quote, unquote, urlsplit

from verify_component_release import read_s19, sha, verify

ROOT = Path(__file__).resolve().parents[2]
BOARD_SHA = '26134784D88C41F8EB7F2C303A68E616993A8424A62D005D73CF338632A27F96'
COMBINED = 'ryors-v1.2-himon-asm-bank3-8-e.s19'

COMMON_MANUALS = [
    'OPERATORS_GUIDE.md', 'TECHNICAL_GUIDE.md', 'INSTALLATION_FLOW.md',
    'CAPABILITIES.md', 'REF.md', 'GLOSSARY.md', 'MEMORY/MEMORY_MAP.md',
    'AP/AP_OIL_GUIDE.md', 'RELEASES.md', 'RELEASE_APPLICATIONS.md',
    'ASM/ASM_USER_GUIDE.md', 'ASM/ASM_ABI_V1.md', 'ASM/ADDRESS_PRACTICES.md',
]


def prepare_manuals(folder, origins, source_commit, release_tag):
    """Retain offline links for included files; pin source-only links to Git."""
    lookup = {(ROOT / origin).resolve(): destination for destination, origin in origins.items()
              if not origin.startswith('generated') and (ROOT / origin).is_file()}
    external = []
    manuals = []
    for destination, origin in origins.items():
        if not destination.endswith('.md') or not origin.startswith('DOC/GUIDES/'):
            continue
        # Dated evidence is byte-preserved. Its original raw-log references
        # intentionally require the repository and are not offline manuals.
        if '/LOGS/' in origin or 'BOARD_TEST' in origin:
            continue
        source = ROOT / origin
        target = folder / destination
        manuals.append(destination)
        def rewrite(match):
            label, address = match.group(1), match.group(2)
            if address.startswith(('#', 'http:', 'https:', 'mailto:', 'data:')):
                return match.group(0)
            # Markdown destinations in these maintained manuals have no titles.
            address = address.strip('<>')
            pieces = urlsplit(address.replace('\\', '/'))
            resolved = (source.parent / unquote(pieces.path)).resolve()
            suffix = '#' + pieces.fragment if pieces.fragment else ''
            if resolved in lookup:
                link = posixpath.relpath(lookup[resolved], posixpath.dirname(destination)) + suffix
            elif resolved.is_relative_to(ROOT):
                relative = resolved.relative_to(ROOT).as_posix()
                reference = release_tag if relative.startswith('RELEASE/') else source_commit
                link = 'https://github.com/95westus/R-YORS/blob/' + reference + '/' + quote(relative) + suffix
                external.append({'manual': destination, 'reference': relative, 'exists_in_source': resolved.exists()})
            elif resolved.is_relative_to(ROOT.parent / 'STR8-N'):
                str8root = ROOT.parent / 'STR8-N'
                commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=str8root, text=True).strip()
                relative = resolved.relative_to(str8root).as_posix()
                link = 'https://github.com/95westus/STR8-N/blob/' + commit + '/' + quote(relative) + suffix
                external.append({'manual': destination, 'reference': 'STR8-N/' + relative, 'exists_in_source': resolved.exists()})
            else:
                raise ValueError(f'Unmapped local manual reference: {origin}: {address}')
            return '[' + label + '](' + link + ')'
        chunks = target.read_text(encoding='utf-8-sig').split('```')
        for i in range(0, len(chunks), 2):
            chunks[i] = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', rewrite, chunks[i])
        target.write_text('```'.join(chunks), encoding='utf-8', newline='\n')
    return manuals, external


@contextmanager
def workspace_temp(prefix):
    # Inherit workspace ACLs; Python 3.13's private Windows temp ACL can
    # exclude a sandbox's secondary identity from the directory it created.
    base = (ROOT / 'SRC/BUILD/tmp').resolve()
    path = base / (prefix + uuid.uuid4().hex)
    path.mkdir()
    try:
        yield path
    finally:
        assert path.resolve().parent == base, 'Cleanup escaped build workspace'
        shutil.rmtree(path)


def qualify(stamp, baseline, logs):
    bank = baseline.read_bytes()
    assert len(bank) == 32768 and sha(bank) == BOARD_SHA, 'Baseline must be the retained, reset-qualified COM4 bank'
    memory, entry = read_s19(ROOT / 'SRC/BUILD/s19' / COMBINED)
    assert entry == 0xC000 and set(memory) == set(range(0x8000, 0xF000))
    payload = bytes(memory[a] for a in range(0x8000, 0xF000))
    original = bank[:0x7000]
    expected = bytearray(original)
    plain = bytes(b & 127 for b in original)
    pattern = rb'(ASM-F2 00\.|HIMON V 00\.|HIMON: V 00\.)(\d{4}\(\d{4}\))'
    matches = list(re.finditer(pattern, plain))
    assert len(matches) == 3
    versions = []
    for match in matches:
        begin, end = match.span(2)
        encoded = bytes((old & 128) | new for old, new in zip(original[begin:end], stamp.encode('ascii')))
        assert len(encoded) == end - begin
        expected[begin:end] = encoded
        versions.append({'address': f'{0x8000+begin:04X}', 'before': match[2].decode(), 'after': stamp})
    assert payload == expected, 'Release differs from qualified firmware outside exact timestamp fields'
    for name, start, end, s9 in [('ryors-v1.2-asm-bank3-8-b.s19', 0x8000, 0xBFFF, 0xFFFF),
                                 ('ryors-v1.2-himon-bank3-c-e.s19', 0xC000, 0xEFFF, 0xC000)]:
        component, component_entry = read_s19(ROOT / 'SRC/BUILD/s19' / name)
        assert set(component) == set(range(start, end + 1)) and component_entry == s9
        assert all(component[a] == memory[a] for a in component)
    checks = {}
    for label, path, required in logs:
        data = path.read_bytes()
        assert required in data.decode(errors='replace'), f'No successful completion marker: {path}'
        checks[label] = {'file': path.name, 'sha256': sha(data)}
    return {
        'schema': 1, 'created': datetime.now().astimezone().isoformat(),
        'release_stamp': stamp, 'basis': 'Complete host regression plus exact timestamp-only equivalence to physical-reset-qualified COM4 firmware.',
        'board_record': 'DOC/GUIDES/LOGS/ASMF2_SIZE_2026-09-15.md',
        'baseline_full_bank_sha256': BOARD_SHA,
        'board_versions': {'STR8-N': '1.34', 'HIMON': '00.0915(2233)', 'ASM-F2': '00.0915(2243)'},
        'timestamp_fields': versions,
        'changed_byte_count': sum(a != b for a, b in zip(original, payload)),
        'combined_s19_sha256': sha((ROOT / 'SRC/BUILD/s19' / COMBINED).read_bytes()),
        'combined_payload_sha256': sha(payload), 'host_checks': checks,
        'scope': 'The newly stamped combined file has not been reflashed. Its firmware differs from the qualified board solely in the three documented timestamp fields. Application qualification remains per application; no new Bank 0-2 or game board proof is claimed.'
    }


def main(args):
    assert re.fullmatch(r'\d{4}\(\d{4}\)', args.stamp)
    out = args.out.resolve()
    assert out == (ROOT / 'RELEASE').resolve(), 'Publication directory must be repository RELEASE'
    out.mkdir(exist_ok=True)
    logs = [('asm-test', args.host_log, 'RELEASE_ASM_TEST_PASS ' + args.stamp),
            ('board-s19-check', args.image_log, 'RELEASE_IMAGES_PASS ' + args.stamp)]
    qualification = qualify(args.stamp, args.qualified_bank, logs)
    version = '00.' + args.stamp
    slug = version.replace('(', '-').replace(')', '')
    source_state = {'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    'dirty': bool(subprocess.check_output(['git', 'status', '--porcelain', '--', '.', ':(exclude)RELEASE'], cwd=ROOT, text=True)),
                    'dirty_scope': 'Repository source/docs/tools, excluding generated RELEASE products.'}
    package_results = []
    with workspace_temp('component-release-') as temporary:
        stage = Path(temporary)
        for product, role, component, start, end, entry in [
                ('HIMON', 'himon', 'ryors-v1.2-himon-bank3-c-e.s19', 0xC000, 0xEFFF, 0xC000),
                ('ASM-F2', 'asm', 'ryors-v1.2-asm-bank3-8-b.s19', 0x8000, 0xBFFF, 0xFFFF)]:
            folder = stage / product
            folder.mkdir()
            origins = {}
            def put(source, destination):
                source = Path(source)
                target = folder / destination
                assert source.is_file(), source
                assert not target.exists(), destination
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)
                origins[destination] = source.relative_to(ROOT).as_posix() if source.is_relative_to(ROOT) else source.name
            def write(destination, content):
                target = folder / destination
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(content, encoding='utf-8', newline='\n')
                origins[destination] = 'generated by package_component_releases.py'
            put(ROOT / 'LICENSE', 'LICENSE')
            put(ROOT / 'SRC/tools/verify_component_release.py', 'VERIFY.py')
            put(ROOT / 'DOC/GUIDES/RELEASE_APPLICATIONS.md', 'APPLICATIONS/README.md')
            for manual in COMMON_MANUALS:
                put(ROOT / 'DOC/GUIDES' / manual, 'DOC/GUIDES/' + manual)
            write('QUALIFICATION.json', json.dumps(qualification, indent=2) + '\n')
            firmware = []
            for filename, image_role, lo, hi, s9 in [(component, role, start, end, entry), (COMBINED, 'combined', 0x8000, 0xEFFF, 0xC000)]:
                relative = 'FIRMWARE/' + filename
                put(ROOT / 'SRC/BUILD/s19' / filename, relative)
                memory, actual_entry = read_s19(folder / relative)
                assert actual_entry == s9 and set(memory) == set(range(lo, hi + 1))
                payload = bytes(memory[a] for a in range(lo, hi + 1))
                item = {'role': image_role, 's19': relative, 'start': lo, 'end': hi, 'entry': s9, 'payload_sha256': sha(payload)}
                if image_role != 'combined':
                    item['bin'] = f'FIRMWARE/{product.lower()}-{lo:04x}-{hi:04x}.bin'
                    (folder / item['bin']).write_bytes(payload)
                    origins[item['bin']] = f'dense bytes from {relative}; CPU ${lo:04X}-${hi:04X}'
                firmware.append(item)
            for label, logpath, _ in logs:
                put(logpath, 'QUALIFICATION/' + label + '.log')
            put(ROOT / 'DOC/GUIDES/LOGS/ASMF2_SIZE_2026-09-15.md', 'QUALIFICATION/ASMF2_SIZE_2026-09-15.md')
            put(ROOT / 'DOC/GUIDES/LOGS/HIMON_SIZE_2026-09-15.md', 'QUALIFICATION/HIMON_SIZE_2026-09-15.md')
            if role == 'himon':
                for filename in ['himon.asm', 'himon-disasm.inc', 'himon-shared-eq.inc']:
                    put(ROOT / 'SRC/HIMON' / filename, 'SOURCE/' + filename)
                # Retain the extracted implementation in future source-reference bundles.
                for filename in ['himon-ap-adapter.inc', 'himon-ap-resolver.inc']:
                    put(ROOT / 'SRC/HIMON' / filename, 'SOURCE/HIMON/' + filename)
                for path in sorted((ROOT / 'SRC/AP').glob('*.inc')):
                    put(path, 'SOURCE/AP/' + path.name)
                for filename in ['HIMON_MAP.md', 'HIMON_DEBUG_TESTING.md']:
                    put(ROOT / 'DOC/GUIDES/HIMON' / filename, 'DOC/GUIDES/HIMON/' + filename)
                for filename in ['BANK_AUDIT_AP_CARD.md', 'BANK_DUMP_AP_CARD.md', 'PIA_LED_BANKED_AP_CARD.md']:
                    put(ROOT / 'DOC/GUIDES/ASM' / filename, 'DOC/GUIDES/ASM/' + filename)
                for app in ['bank-audit-2000', 'bank-dump-2000', 'pia-led-show-2000']:
                    # BANKAUDIT/BANKDUMP host fixtures pin old HIMON addresses;
                    # their named-import .a forms are the supported release path.
                    variants = [('a', 'DOC/GUIDES/ASM/SAMPLES')]
                    if app == 'pia-led-show-2000':
                        variants += [('asm', 'SRC/APPS'), ('s19', 'SRC/BUILD/s19')]
                    for extension, source_dir in variants:
                        put(ROOT / source_dir / (app + '.' + extension), 'APPLICATIONS/UTILITIES/' + app + '.' + extension)
                put(ROOT / 'DOC/GUIDES/ASM/SAMPLES/edu-rtc-read-7000.a', 'APPLICATIONS/UTILITIES/edu-rtc-read-7000.a')
                for name, source in [('life.asm', 'SRC/APPS/life.asm'), ('life-2000.s19', 'SRC/BUILD/s19/life-2000.s19'),
                                     ('life-2000-load.bin', 'SRC/BUILD/bin/life-2000-load.bin'), ('LIFE-NOTICE.txt', 'SRC/APPS/LIFE-NOTICE.txt')]:
                    put(ROOT / source, 'APPLICATIONS/LIFE/' + name)
                for name, source in [('microchess-2000.asm', 'SRC/APPS/microchess-2000.asm'),
                                     ('microchess-2000.a', 'DOC/GUIDES/ASM/SAMPLES/microchess-2000.a'),
                                     ('microchess.ap', 'SRC/BUILD/bin/microchess.ap'),
                                     ('microchess-ap-3000.s19', 'SRC/BUILD/s19/microchess-ap-3000.s19'),
                                     ('MICROCHESS-LICENSE.txt', 'SRC/APPS/MICROCHESS-LICENSE.txt'),
                                     ('GUIDE.md', 'DOC/GUIDES/ASM/MICROCHESS_AP.md')]:
                    put(ROOT / source, 'APPLICATIONS/MICROCHESS/' + name)
                for name, source in [('apman-v1.ap', 'SRC/BUILD/bin/apman-v1.ap'),
                                     ('apman-v1-bank2-8000.s19', 'SRC/BUILD/s19/apman-v1-bank2-8000.s19'),
                                     ('apman-v1-bank2-8000.bin', 'SRC/BUILD/bin/apman-v1-bank2-8000.bin'),
                                     ('HISTORICAL-BOARD-TEST.md', 'DOC/GUIDES/ASM/APMAN_V1_BOARD_TEST.md')]:
                    put(ROOT / source, 'APPLICATIONS/APMAN/' + name)
                write('APPLICATIONS/APMAN/README.md', '''# APMAN optional carrier manager

The AP v2 envelope is `apman-v1.ap`. The matching dense BIN/S19 occupies one
4 KiB sector at Bank 2:$8000-$8FFF; it is an initial bootstrap carrier, not
a whole-bank image. It replaces that sector when installed. It does not
contain any WDC firmware or a snapshot of an owner's bank.

For an already provisioned APMAN carrier, ASM's `INSTALL package Bn` and
HIMON's AP/APS commands use the current resident protocol. A suitable free
destination sector is required. Inspect the directory and bank contents
before choosing any installation destination.

New carrier provisioning also requires a consistent STR8 directory entry.
It depends on the current bank's state and is not automatic on running a
game or assembler example. The STR8 package includes Bank Maintenance and
its operator guide for directory/flash work. `HISTORICAL-BOARD-TEST.md`
records an earlier destructive bench setup; it is evidence, not a script to
paste into a current board. The 2026-09-15 firmware qualification did not
requalify an APMAN carrier installation. Run the other packaged AP examples
from RAM when persistent installation is not needed.
''')
            else:
                for filename in ['asm-v1-core.asm', 'asm-v1-flash.asm', 'asm-abi-v1.inc']:
                    put(ROOT / 'SRC/ASM' / filename, 'SOURCE/' + filename)
                for filename in ['ASM_CALL_MAP.md', 'ASM_DIALECT_CROSSWALK.md', 'SIZE_REDUCTION_2026-09-15.md']:
                    put(ROOT / 'DOC/GUIDES/ASM' / filename, 'DOC/GUIDES/ASM/' + filename)
                for app in ['asm-session-report-v1.2-ap-2000', 'seal-workflow-2000', 'expr-operators-ap-2000',
                            'unresolved-addends-2000', 'str8n-v1.2-bank-crc-all-3000',
                            'terminal-answerback-vt100-3000', 'vt102-exerciser-7000', 'vt525-exerciser-7000']:
                    put(ROOT / 'DOC/GUIDES/ASM/SAMPLES' / (app + '.a'), 'APPLICATIONS/' + app + '.a')
                for app in ['expr-negative-rollback-2000', 'opcode-reduction-runtime-2000', 'symbol-name-pool-rollback', 'symbol128-slot-rollback']:
                    put(ROOT / 'DOC/GUIDES/ASM/SAMPLES' / (app + '.a'), 'VALIDATION/' + app + '.a')
            range_text = 'C-E' if role == 'himon' else '8-B'
            write('README.md', f'''# {product} {version}

Built {qualification['created']}. This package is a local release from the
recorded source revision; `MANIFEST.json` records its working-tree status and
file hashes. Source snapshots are reference material; the repository contains
the complete build system. No proprietary tools, WDC firmware, owner bank
dumps, BASIC or Forth products are included.

Start with [the included manuals](MANUALS.md) for operator, technical,
installation, memory-map, assembler, and application instructions.

## Install

Requires STR8-N 1.34. From HIMON enter `STR8`, confirm, then select `S`.
At `STR8-N>` enter `I`, bank `3`, range `{range_text}`, and confirm `Y`.
Only after `S19` appears send `FIRMWARE/{component}`. Wait for
`COMMIT? Y:`, confirm `Y`, and require `OK`. Enter `C` to start HIMON;
`ASM NEW` enters ASM-F2. Send text with CR line endings at 115200 baud.

For a new combined installation, or recovery of an interrupted transaction,
use `I / 3 / 8-E` with `FIRMWARE/{COMBINED}` instead. Its S9 is `$C000`.
The ASM-only stream's S9 `$FFFF` retains an existing HIMON directory entry;
it cannot enroll an empty bank. An incomplete Bank-3 transaction requires
the complete writable range 8-E. Bank-3 sector F is owned by STR8 and is not
included in these streams. The BIN is only the address-labelled component
range, not a complete bootable ROM or a whole-bank replacement.

## Qualification

The complete host regression and image checks passed. The combined 28 KiB
payload is byte-identical to the physical-reset-qualified COM4 firmware
except for its three timestamp strings, now `{args.stamp}`. The new stamped
stream was not reflashed. Read `QUALIFICATION.json` for exact comparison,
hashes, prior board identities, and limits. Current hardware is unchanged.
Application proof varies; consult `APPLICATIONS/README.md` before use.

## Verify

Extract the ZIP and run `python -B VERIFY.py` (Python 3.9 or newer).
The verifier checks the exact inventory, hashes, notices, record checksums,
S9 entries, component BIN/S19 agreement, and combined image identity.
`SHA256SUMS.txt` covers every other package file. Preserve LICENSE and all
application-specific attribution and redistribution notices.
''')
            release_tag = ('himon-v' if role == 'himon' else 'asm-f2-v') + slug
            manuals, external = prepare_manuals(folder, origins, source_state['commit'], release_tag)
            index = '# Manuals included in this package\n\n'
            index += '\n'.join(f'- [{Path(name).stem}]({name})' for name in sorted(manuals)) + '\n\n'
            index += ('Included manuals work offline. References to source files or historical material\n'
                      'outside this package are explicit GitHub links pinned to the source commit\n'
                      'or release tag; they require those references to be published. Dated qualification records and\n'
                      'historical board cards are preserved unchanged; raw-log references require\n'
                      'the original repository. Start with README.md for this release identity.\n')
            write('MANUALS.md', index)
            files = {p.relative_to(folder).as_posix(): {'bytes': p.stat().st_size, 'sha256': sha(p.read_bytes()),
                     'source': origins[p.relative_to(folder).as_posix()]} for p in sorted(folder.rglob('*')) if p.is_file()}
            manifest = {'schema': 1, 'product': product, 'version': version, 'created': qualification['created'],
                        'source_state': source_state, 'release_tag': release_tag, 'firmware': firmware, 'manuals': manuals,
                        'source_references': external, 'files': files}
            (folder / 'MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
            sums = ''.join(f'{sha(p.read_bytes())}  {p.relative_to(folder).as_posix()}\n' for p in sorted(folder.rglob('*')) if p.is_file())
            (folder / 'SHA256SUMS.txt').write_text(sums, encoding='ascii')
            verify(folder)
            archive = stage / f'{product.lower()}-{slug}.zip'
            with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as z:
                for path in sorted(folder.rglob('*')):
                    if path.is_file():
                        z.write(path, path.relative_to(folder).as_posix())
            unpacked = stage / (product + '-verify')
            with zipfile.ZipFile(archive) as z:
                z.extractall(unpacked)
            verify(unpacked)
            destination = out / archive.name
            shutil.copyfile(archive, destination)
            package_results.append({'file': archive.name, 'sha256': sha(archive.read_bytes()), 'bytes': archive.stat().st_size})
    combined = out / COMBINED
    shutil.copyfile(ROOT / 'SRC/BUILD/s19' / COMBINED, combined)
    (out / 'QUALIFICATION.json').write_text(json.dumps(qualification, indent=2) + '\n', encoding='utf-8')
    (out / 'component-release-manifest.json').write_text(json.dumps(package_results, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(package_results, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stamp', required=True)
    parser.add_argument('--out', type=Path, default=ROOT / 'RELEASE')
    parser.add_argument('--qualified-bank', type=Path, default=ROOT / 'SRC/BUILD/tmp/asmf2-size-board/final-b3.bin')
    parser.add_argument('--host-log', type=Path, default=ROOT / 'SRC/BUILD/tmp/asmf2-size-board/release-asm-test.log')
    parser.add_argument('--image-log', type=Path, default=ROOT / 'SRC/BUILD/tmp/asmf2-size-board/release-images.log')
    main(parser.parse_args())
