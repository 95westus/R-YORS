import argparse
from datetime import datetime
import json
from pathlib import Path
import re
import serial
import time

ROOT = Path(__file__).resolve().parents[4]
LOG = ROOT / 'DOC/GUIDES/LOGS/HIMON_SIZE_2026-09-15.jsonl'

class Board:
    def __enter__(self):
        self.log = LOG.open('a', encoding='utf-8')
        self.serial = serial.Serial(port=None, baudrate=115200, timeout=0.05, write_timeout=5)
        self.serial.dtr = False
        self.serial.rts = False
        self.serial.port = 'COM4'
        self.serial.open()
        return self

    def record(self, direction, data):
        self.log.write(json.dumps({'time': datetime.now().astimezone().isoformat(),
                                   'direction': direction, 'hex': data.hex()}) + '\n')
        self.log.flush()

    def send(self, data):
        self.record('TX', data)
        self.serial.write(data)
        self.serial.flush()

    def read(self, seconds=3, until=None):
        end = time.monotonic() + seconds
        result = bytearray()
        while time.monotonic() < end:
            part = self.serial.read(self.serial.in_waiting or 1)
            if part:
                self.record('RX', part)
                result.extend(part)
                if until and re.search(until, result.decode('ascii', 'replace')):
                    return bytes(result)
        if until:
            raise AssertionError(f'missing {until!r}; got {result[-1600:]!r}')
        return bytes(result)

    def command(self, text, until=r'\r\n>$', seconds=10):
        self.send(text.encode('ascii') + b'\r')
        result = self.read(seconds, until)
        print(result[-2000:].decode('ascii', 'replace'), flush=True)
        return result

    def transfer(self, path, seconds=15, until=None):
        # Paced records allow the monitor/STR8 parser to drain the FTDI FIFO.
        result = bytearray()
        lines = Path(path).read_text().splitlines()
        for line in lines:
            self.send(line.encode('ascii') + b'\r')
            time.sleep(0.015)
            if self.serial.in_waiting:
                data = self.serial.read(self.serial.in_waiting)
                self.record('RX', data)
                result.extend(data)
        if not until or not re.search(until, result.decode('ascii', 'replace')):
            result.extend(self.read(seconds, until))
        print(f'Sent {len(lines)} S19 records; received {len(result)} bytes; tail: ' + result[-2000:].decode('ascii', 'replace'), flush=True)
        return bytes(result)

    def __exit__(self, *args):
        self.serial.close()
        self.log.close()

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--send')
    p.add_argument('--seconds', type=float, default=3)
    p.add_argument('--until')
    args = p.parse_args()
    with Board() as b:
        if args.send is not None:
            b.send(args.send.encode('ascii') + b'\r')
        result = b.read(args.seconds, args.until)
        print(result.decode('ascii', 'replace'))
