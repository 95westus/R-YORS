"""Capture a release build without interpreting native stderr warnings as failures."""
import argparse
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--stamp', required=True)
parser.add_argument('--phase', choices=['host', 'images'], required=True)
parser.add_argument('--log', type=Path, required=True)
parser.add_argument('--logo')
args = parser.parse_args()
targets = ['asm-test'] if args.phase == 'host' else ['board-s19-check', 'life']
command = ['make', *targets, 'HIMON_VISIBLE_STAMP=' + args.stamp]
if args.logo:
    command.append('RYORS_LOGO_SVG=' + args.logo)
args.log.parent.mkdir(parents=True, exist_ok=True)
with args.log.open('wb') as log:
    log.write(('COMMAND: ' + repr(command) + '\n').encode())
    log.flush()
    result = subprocess.run(command, cwd=Path(__file__).resolve().parents[1], stdout=log, stderr=subprocess.STDOUT)
    if result.returncode == 0:
        marker = 'RELEASE_ASM_TEST_PASS' if args.phase == 'host' else 'RELEASE_IMAGES_PASS'
        log.write(f'\n{marker} {args.stamp}\n'.encode())
print(f'{args.phase}: exit {result.returncode}; {args.log}')
raise SystemExit(result.returncode)
