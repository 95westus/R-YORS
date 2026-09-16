from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'LOCAL/himon-ap-change-20260916'))
import capture
capture.HERE=Path(__file__).resolve().parent
capture.build('qualified', ['asm-test','himon-banked-ap-check','himon-str8-record-check',
                          'himon-io-led-check','board-s19-check','himon-rom-bin'])
