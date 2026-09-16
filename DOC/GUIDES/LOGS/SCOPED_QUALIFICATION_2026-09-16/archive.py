from pathlib import Path
import sys
import console,bank_archive as arc
HERE=Path(__file__).resolve().parent
console.LOG=HERE/'serial-com4.jsonl'
arc.LOG=console.LOG;arc.HELPER=HERE/'bank-stage-2000.s19'
arc.get_board_class=lambda:console.Board
arc.archive(HERE/sys.argv[1],[0,1,2,3])
if sys.argv[1]=='before':
 assert (HERE/'before/flash-128k.bin').read_bytes()==(HERE.parents[1]/'DOC/GUIDES/LOGS/SCOPED_SMOKE_BOARD_2026-09-16/final/flash-128k.bin').read_bytes()
 print('Fresh baseline exactly matches accepted A6 smoke image')
