"""Positive and negative checks for the published component archives."""
import argparse
import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import zipfile
from verify_component_release import sha, verify
from package_component_releases import workspace_temp


def reseal(root):
    path = root / 'MANIFEST.json'
    manifest = json.loads(path.read_text())
    for name in list(manifest['files']):
        file = root / name
        if not file.exists():
            del manifest['files'][name]
        else:
            manifest['files'][name].update(bytes=file.stat().st_size, sha256=sha(file.read_bytes()))
    path.write_text(json.dumps(manifest), encoding='utf-8')
    paths = sorted(p for p in root.rglob('*') if p.is_file() and p.name != 'SHA256SUMS.txt')
    (root / 'SHA256SUMS.txt').write_text(''.join(f'{sha(p.read_bytes())}  {p.relative_to(root).as_posix()}\n' for p in paths), encoding='ascii')


def main(directory):
    directory = directory.resolve()
    archives = json.loads((directory / 'component-release-manifest.json').read_text())
    with workspace_temp('release-negative-') as temp:
        base = Path(temp)
        for item in archives:
            archive = directory / item['file']
            assert sha(archive.read_bytes()) == item['sha256']
            root = base / archive.stem
            with zipfile.ZipFile(archive) as z:
                z.extractall(root)
            verify(root)
            optimized = subprocess.run([sys.executable, '-O', '-B', str(root / 'VERIFY.py')], capture_output=True, text=True)
            assert optimized.returncode != 0 and 'without -O' in optimized.stderr
            cases = ['extra-file', 'bin-mismatch', 'bad-entry', 'missing-manual', 'broken-manual-link']
            if archive.name.startswith('himon'):
                cases.append('missing-microchess-notice')
            for case in cases:
                trial = base / (archive.stem + '-' + case)
                with zipfile.ZipFile(archive) as z:
                    z.extractall(trial)
                manifest = json.loads((trial / 'MANIFEST.json').read_text())
                component = next(i for i in manifest['firmware'] if i['role'] != 'combined')
                if case == 'extra-file':
                    (trial / 'unlisted.txt').write_text('must reject')
                elif case == 'bin-mismatch':
                    path = trial / component['bin']
                    data = bytearray(path.read_bytes()); data[0] ^= 1; path.write_bytes(data)
                    reseal(trial)
                elif case == 'bad-entry':
                    path = trial / component['s19']
                    lines = path.read_text().splitlines()
                    lines[-1] = 'S90380007C'
                    path.write_text('\n'.join(lines) + '\n')
                    reseal(trial)
                elif case == 'missing-manual':
                    (trial / 'DOC/GUIDES/OPERATORS_GUIDE.md').unlink()
                    reseal(trial)
                elif case == 'broken-manual-link':
                    with (trial / 'DOC/GUIDES/OPERATORS_GUIDE.md').open('a', encoding='utf-8') as f:
                        f.write('\n[broken](missing-manual.md)\n')
                    reseal(trial)
                else:
                    (trial / 'APPLICATIONS/MICROCHESS/MICROCHESS-LICENSE.txt').unlink()
                    reseal(trial)
                try:
                    with contextlib.redirect_stdout(io.StringIO()):
                        verify(trial)
                except (AssertionError, FileNotFoundError):
                    print('PASS rejected', archive.name, case)
                else:
                    raise AssertionError(f'Accepted invalid package: {case}')
    print('PASS component archives and 13 negative cases (including manuals and optimized Python)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', nargs='?', type=Path, default=Path(__file__).resolve().parents[2] / 'RELEASE')
    main(parser.parse_args().directory)
