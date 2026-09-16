"""Local evidence capture for the HIMON/AP baseline; no serial or flash I/O."""
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def output(args, cwd=ROOT):
    return subprocess.check_output(args, cwd=cwd).decode('utf-8', 'replace').strip()

def snapshot(name):
    target = HERE / name
    target.mkdir(exist_ok=False)
    rows = []
    for folder in ['s19', 'map', 'lst', 'bin', 'inc', 'lib', 'integration']:
        source = ROOT / 'SRC/BUILD' / folder
        for path in sorted(source.rglob('*')):
            if not path.is_file():
                continue
            rel = path.relative_to(ROOT / 'SRC/BUILD')
            dest = target / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, dest)
            rows.append({'path': rel.as_posix(), 'bytes': path.stat().st_size, 'sha256': digest(path)})
    (target / 'manifest.json').write_text(json.dumps(rows, indent=2) + '\n')
    print(f'{name}: archived {len(rows)} files', flush=True)

def initial():
    meta = {'utc': datetime.now(timezone.utc).isoformat(),
            'revision': output(['git', 'rev-parse', 'HEAD']),
            'status': output(['git', 'status', '--short']),
            'str8_status': output(['git', 'status', '--short'], ROOT.parent / 'STR8-N'),
            'str8_revision': output(['git', 'rev-parse', 'HEAD'], ROOT.parent / 'STR8-N'),
            'python': sys.version, 'python_executable': sys.executable,
            'platform': sys.platform, 'stamp': '0915(2324)', 'tools': {}, 'packages': {}}
    for name in ['make', 'wdc02as', 'wdcln', 'wdclib', 'powershell', 'git']:
        path = Path(shutil.which(name))
        meta['tools'][name] = {'path': str(path), 'sha256': digest(path)}
    for name in ['pyserial', 'py65']:
        try:
            meta['packages'][name] = importlib.metadata.version(name)
        except importlib.metadata.PackageNotFoundError:
            meta['packages'][name] = 'not in default site-packages'
    meta['make_version'] = output(['make', '--version'])
    meta['lock'] = json.loads((ROOT / 'SRC/INTEGRATION/str8n.lock.json').read_text())
    (HERE / 'environment.json').write_text(json.dumps(meta, indent=2) + '\n')
    (HERE / 'initial.patch').write_bytes(subprocess.check_output(['git', 'diff', '--binary', 'HEAD'], cwd=ROOT))
    names = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=ROOT).decode().split('\0')
    rows = []
    for name in sorted(set(names)):
        path = ROOT / name
        if not name or not path.is_file():
            continue
        rows.append({'path': name, 'bytes': path.stat().st_size, 'sha256': digest(path)})
        if name.startswith(('SRC/', 'DOC/branding/')) or name == 'AGENTS.md':
            dest = HERE / 'source' / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, dest)
    (HERE / 'source-manifest.json').write_text(json.dumps(rows, indent=2) + '\n')
    snapshot('preexisting')

def build(name, targets):
    args = ['make', '-C', 'SRC', 'HIMON_VISIBLE_STAMP=0915(2324)',
            '-W', 'HIMON/himon.asm', '-W', 'ASM/asm-v1-flash.asm',
            '-W', 'APPS/apman-7000.asm'] + targets
    if name == 'build-2':
        # Force all source prerequisites potentially used by these components,
        # including the library and runtime object, without deleting artifacts.
        for folder in ['HIMON', 'LIB', 'ASM', 'APPS', 'TESTS']:
            for path in sorted((ROOT / 'SRC' / folder).rglob('*')):
                if path.suffix in ('.asm', '.inc'):
                    args.extend(['-W', path.relative_to(ROOT / 'SRC').as_posix()])
    start = datetime.now(timezone.utc).isoformat()
    with (HERE / f'{name}.log').open('wb') as log:
        result = subprocess.run(args, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    (HERE / f'{name}.json').write_text(json.dumps({'command': args, 'cwd': str(ROOT),
        'start_utc': start, 'end_utc': datetime.now(timezone.utc).isoformat(),
        'exit_code': result.returncode}, indent=2) + '\n')
    print(f'{name}: exit {result.returncode}', flush=True)
    print('\n'.join((HERE / f'{name}.log').read_text(errors='replace').splitlines()[-18:]))
    if result.returncode:
        raise SystemExit(result.returncode)
    snapshot(name)

if __name__ == '__main__':
    if sys.argv[1] == 'initial':
        initial()
    else:
        build(sys.argv[1], sys.argv[2:])
