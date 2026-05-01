#!/usr/bin/env python3
"""
Emit a WDC02AS-flavored OSI Microsoft BASIC source from mist64/msbasic.

This intentionally does only the OSI configuration.  It is a small source
translator/preprocessor, not a general ca65 compatibility layer.
"""

from __future__ import annotations

import argparse
import ast
import re
from dataclasses import dataclass
from pathlib import Path


SEGMENT_ORDER = ["HEADER", "VECTORS", "KEYWORDS", "ERROR", "CODE", "CHRGET", "INIT", "EXTRA"]

# Current HIMON monitor entry points. The Makefile patches generated BASIC
# from himon-rom.map before assembly so these defaults do not silently rot.
MONITOR_ADDRS = {
    "GET_CHAR": "$FEED",  # HIMONIA_ABI_READ_BYTE in BUILD/map/himon-rom.map
    "PUT_CHAR": "$F00D",  # HIMONIA_ABI_WRITE_BYTE in BUILD/map/himon-rom.map
    "GET_CTRL_C": "$EB5D",  # SYS_GET_CTRL_C in BUILD/map/himon-rom.map
}

BASIC_CMD_FNV_HASH = "$5D,$CB,$C5,$82"  # FNV-1a("BASIC"), little-endian.

OVERRIDES = {
    "MONRDKEY": MONITOR_ADDRS["GET_CHAR"],
    "MONCOUT": MONITOR_ADDRS["PUT_CHAR"],
}

CALL_RENAMES = {
    "MONRDKEY": "MSBASIC_GET_CHAR",
    "MONCOUT": "MSBASIC_PUT_CHAR",
}

STUB_LABELS = {"MONISCNTC", "LOAD", "SAVE"}

# WDC02AS treats tokens like FADDH as hexadecimal constants with an H suffix.
SYMBOL_RENAMES = {
    "FADDH": "FADDH_",
}

LONG_BRANCH_INVERSE = {
    "JEQ": "BNE",
    "JNE": "BEQ",
    "JCC": "BCS",
    "JCS": "BCC",
    "JPL": "BMI",
    "JMI": "BPL",
    "JVC": "BVS",
    "JVS": "BVC",
}

CHRGET_ZP_OFFSETS = {
    "CHRGOT": 6,
    "TXTPTR": 7,
    "CHRGOT2": 13,
    "RNDSEED": 24,
}

ABSOLUTE_OPCODES = {
    "LDA": "$AD",
}


@dataclass
class CondFrame:
    parent_active: bool
    active: bool
    taken: bool


def split_comment(line: str) -> tuple[str, str]:
    in_quote = False
    quote = ""
    for i, ch in enumerate(line):
        if ch in ("'", '"'):
            if not in_quote:
                in_quote = True
                quote = ch
            elif quote == ch:
                in_quote = False
        elif ch == ";" and not in_quote:
            return line[:i], line[i:]
    return line, ""


def split_args(text: str) -> list[str]:
    args: list[str] = []
    cur: list[str] = []
    in_quote = False
    quote = ""
    for ch in text:
        if ch in ("'", '"'):
            if not in_quote:
                in_quote = True
                quote = ch
            elif quote == ch:
                in_quote = False
            cur.append(ch)
        elif ch == "," and not in_quote:
            args.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    if cur or text.endswith(","):
        args.append("".join(cur).strip())
    return args


def parse_string(text: str) -> str:
    text = text.strip()
    try:
        return ast.literal_eval(text)
    except Exception as exc:  # pragma: no cover - diagnostics for source drift
        raise ValueError(f"cannot parse string literal {text!r}") from exc


def hbit_bytes(text: str, last_only: bool) -> list[int]:
    raw = [ord(ch) for ch in text]
    if not raw:
        return []
    if last_only:
        raw[-1] |= 0x80
    else:
        raw = [(b | 0x80) for b in raw]
    return raw


def db_for_bytes(values: list[int]) -> str:
    return "                        DB              " + ",".join(f"${v:02X}" for v in values)


class OsiWdcEmitter:
    def __init__(self, source_root: Path) -> None:
        self.source_root = source_root
        self.symbols: dict[str, int | str] = {"osi": 1}
        self.cond_stack: list[CondFrame] = []
        self.current_segment: str | None = None
        self.segments: dict[str, list[str]] = {seg: [] for seg in SEGMENT_ORDER}
        self.preamble: list[str] = []
        self.zp_equates: list[str] = []
        self.zp_pc = 0
        self.dummy_count = 0
        self.error_offset = 0
        self.long_branch_id = 0
        self.in_macro_definition = False
        self.pending_low_byte_label: str | None = None

    def active(self) -> bool:
        return all(frame.active for frame in self.cond_stack)

    def parent_active(self) -> bool:
        if not self.cond_stack:
            return True
        return all(frame.active for frame in self.cond_stack[:-1])

    def emit(self, line: str = "") -> None:
        if self.current_segment in self.segments:
            self.segments[self.current_segment].append(self.mangle_symbols(line))

    def mangle_symbols(self, text: str) -> str:
        for old, new in SYMBOL_RENAMES.items():
            text = re.sub(rf"\b{re.escape(old)}\b", new, text)
        return text

    def emit_equate(self, name: str, expr: str, *, in_place: bool = False) -> None:
        name = SYMBOL_RENAMES.get(name, name)
        expr = self.mangle_symbols(expr)
        line = f"{name:<26} EQU             {expr}"
        if in_place and self.current_segment in self.segments:
            self.emit(line)
        elif self.current_segment == "ZEROPAGE":
            self.zp_equates.append(line)
        else:
            self.preamble.append(line)

    def eval_expr(self, expr: str) -> int | None:
        text = expr.strip()
        text = re.sub(r"\$([0-9A-Fa-f]+)", r"0x\1", text)
        text = re.sub(r"%([01]+)", r"0b\1", text)
        text = re.sub(
            r"\.defined\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)",
            lambda m: "1" if m.group(1) in self.symbols else "0",
            text,
        )
        text = re.sub(
            r"\.def\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)",
            lambda m: "1" if m.group(1) in self.symbols else "0",
            text,
        )
        text = text.replace("&&", " and ")
        text = text.replace("||", " or ")
        text = re.sub(r"!(?!=)", " not ", text)
        text = re.sub(r"(?<![<>=!])=(?!=)", "==", text)

        unknown_seen = False

        def repl_symbol(match: re.Match[str]) -> str:
            nonlocal unknown_seen
            name = match.group(0)
            lowered = name.lower()
            if lowered in {"and", "or", "not"}:
                return lowered
            value = self.symbols.get(name)
            if isinstance(value, int):
                return str(value)
            unknown_seen = True
            return "0"

        text = re.sub(r"\b[A-Za-z_][A-Za-z0-9_]*\b", repl_symbol, text)
        try:
            value = int(eval(text, {"__builtins__": {}}, {}))
            return None if unknown_seen else value
        except Exception:
            return None

    def define_symbol(self, name: str, expr: str) -> None:
        name = SYMBOL_RENAMES.get(name, name)
        raw_expr = expr.strip()
        if raw_expr == "*-1" and self.rewrite_previous_jsr_high_label(name):
            self.symbols[name] = name
            return
        match = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_]*)\s*\+\s*1", raw_expr)
        if match and self.current_segment in self.segments:
            base = SYMBOL_RENAMES.get(match.group(1), match.group(1))
            if self.segments[self.current_segment] and self.segments[self.current_segment][-1].strip() == f"{base}:":
                self.symbols[name] = name
                self.pending_low_byte_label = name
                return
        expr = self.replace_byte_extracts(raw_expr, allow_symbolic_low=True)
        if name in STUB_LABELS:
            self.symbols[name] = name
            return
        out_expr = OVERRIDES.get(name, expr.strip())
        if name == "INPUTBUFFERX":
            out_expr = "$0000"
        value = self.eval_expr(out_expr)
        self.symbols[name] = value if value is not None else out_expr
        in_place = self.current_segment in self.segments
        self.emit_equate(name, out_expr, in_place=in_place)

    def rewrite_previous_jsr_high_label(self, label: str) -> bool:
        if self.current_segment not in self.segments:
            return False
        lines = self.segments[self.current_segment]
        if not lines:
            return False
        code, comment = split_comment(lines[-1])
        match = re.match(r"\s*JSR\s+(.+?)\s*$", code, flags=re.I)
        if not match:
            return False
        operand = match.group(1).strip()
        low, high = self.byte_operands(operand)
        suffix = f" {comment}" if comment else ""
        lines[-1] = f"                        DB              $20{suffix}"
        lines.append(f"                        DB              {low}")
        lines.append(f"{label + ':':<24}DB              {high}")
        return True

    def byte_operands(self, operand: str) -> tuple[str, str]:
        value = self.eval_expr(operand)
        if value is not None:
            return f"${value & 0xFF:02X}", f"${(value >> 8) & 0xFF:02X}"
        return f"<{operand}", f">{operand}"

    def process_file(self, filename: str) -> None:
        path = (self.source_root / filename).resolve()
        for raw in path.read_text(encoding="utf-8").splitlines():
            self.process_line(raw)

    def handle_conditional(self, stripped: str) -> bool:
        lower = stripped.lower()
        if lower.startswith(".ifdef "):
            name = stripped.split(None, 1)[1].strip()
            parent = self.active()
            cond = name in self.symbols
            self.cond_stack.append(CondFrame(parent, parent and cond, parent and cond))
            return True
        if lower.startswith(".ifndef "):
            name = stripped.split(None, 1)[1].strip()
            parent = self.active()
            cond = name not in self.symbols
            self.cond_stack.append(CondFrame(parent, parent and cond, parent and cond))
            return True
        if lower.startswith(".if "):
            parent = self.active()
            cond = bool(self.eval_expr(stripped.split(None, 1)[1]) or 0)
            self.cond_stack.append(CondFrame(parent, parent and cond, parent and cond))
            return True
        if lower.startswith(".elseif "):
            frame = self.cond_stack[-1]
            if frame.parent_active and not frame.taken:
                cond = bool(self.eval_expr(stripped.split(None, 1)[1]) or 0)
                frame.active = cond
                frame.taken = cond
            else:
                frame.active = False
            return True
        if lower == ".else":
            frame = self.cond_stack[-1]
            frame.active = frame.parent_active and not frame.taken
            frame.taken = True
            return True
        if lower == ".endif":
            self.cond_stack.pop()
            return True
        return False

    def set_segment(self, stripped: str) -> bool:
        match = re.match(r'\.segment\s+"([^"]+)"', stripped, flags=re.I)
        if match:
            segment = match.group(1).upper()
            if segment == "DUMMY":
                self.current_segment = "DUMMY"
            elif segment in self.segments:
                self.current_segment = segment
            else:
                raise ValueError(f"unsupported segment {segment}")
            return True
        if stripped.lower() == ".zeropage":
            self.current_segment = "ZEROPAGE"
            return True
        return False

    def handle_macro_call(self, stripped: str) -> bool:
        match = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\s*(.*)$", stripped)
        if not match:
            return False
        name = match.group(1)
        rest = match.group(2).strip()
        args = split_args(rest)

        if name == "init_token_tables":
            self.current_segment = "VECTORS"
            self.emit("TOKEN_ADDRESS_TABLE:")
            self.current_segment = "KEYWORDS"
            self.emit("TOKEN_NAME_TABLE:")
            self.dummy_count = 0
            return True

        if name == "count_tokens":
            self.define_symbol("NUM_TOKENS", str(self.dummy_count))
            return True

        if name == "keyword_rts":
            key = parse_string(args[0])
            vec = args[1]
            token = args[2] if len(args) > 2 else ""
            self.current_segment = "VECTORS"
            self.emit(f"                        DW              {vec}-1")
            self.emit_keyword(key, token)
            return True

        if name == "keyword_addr":
            key = parse_string(args[0])
            vec = args[1]
            token = args[2] if len(args) > 2 else ""
            self.current_segment = "VECTORS"
            self.emit(f"                        DW              {vec}")
            self.emit_keyword(key, token)
            return True

        if name == "keyword":
            key = parse_string(args[0])
            token = args[1] if len(args) > 1 else ""
            self.emit_keyword(key, token)
            return True

        if name == "init_error_table":
            self.current_segment = "ERROR"
            self.emit("ERROR_MESSAGES:")
            self.error_offset = 0
            return True

        if name == "define_error":
            error_name = args[0]
            msg = parse_string(args[1])
            self.symbols[error_name] = self.error_offset
            self.emit_equate(error_name, str(self.error_offset))
            self.current_segment = "ERROR"
            self.emit(db_for_bytes(hbit_bytes(msg, last_only=True)))
            self.error_offset += len(msg)
            return True

        if name == "htasc":
            self.emit(db_for_bytes(hbit_bytes(parse_string(args[0]), last_only=True)))
            return True

        if name == "asc80":
            self.emit(db_for_bytes(hbit_bytes(parse_string(args[0]), last_only=False)))
            return True

        return False

    def emit_keyword(self, key: str, token: str) -> None:
        self.current_segment = "KEYWORDS"
        self.emit(db_for_bytes(hbit_bytes(key, last_only=True)))
        if token:
            self.symbols[token] = (self.dummy_count + 0x80) & 0xFF
            self.emit_equate(token, f"${(self.dummy_count + 0x80) & 0xFF:02X}")
        self.dummy_count += 1

    def handle_zp_line(self, code: str) -> bool:
        stripped = code.strip()
        if self.current_segment != "ZEROPAGE":
            return False

        org_match = re.match(r"\.org\s+(.+)$", stripped, flags=re.I)
        if org_match:
            value = self.eval_expr(org_match.group(1))
            if value is None:
                raise ValueError(f"cannot evaluate ZP org {stripped}")
            self.zp_pc = value
            return True

        label_match = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):\s*$", stripped)
        if label_match:
            name = label_match.group(1)
            self.symbols[name] = self.zp_pc
            self.zp_equates.append(f"{name:<26} EQU             ${self.zp_pc:02X}")
            return True

        assign_match = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*(?::=|=)\s*(.+)$", stripped)
        if assign_match:
            name, expr = assign_match.groups()
            raw_expr = expr.strip()
            special = self.resolve_chrget_zp_alias(name, raw_expr)
            expr = self.replace_byte_extracts(raw_expr, allow_symbolic_low=True)
            value = special if special is not None else self.eval_expr(expr)
            self.symbols[name] = value if value is not None else expr
            out_expr = f"${value:02X}" if value is not None else expr
            self.zp_equates.append(f"{name:<26} EQU             {out_expr}")
            return True

        res_match = re.match(r"\.res\s+(.+)$", stripped, flags=re.I)
        if res_match:
            value = self.eval_expr(res_match.group(1))
            if value is None:
                raise ValueError(f"cannot evaluate ZP res {stripped}")
            self.zp_pc += value
            return True

        return True

    def resolve_chrget_zp_alias(self, name: str, expr: str) -> int | None:
        if name not in CHRGET_ZP_OFFSETS:
            return None
        compact = re.sub(r"\s+", "", expr)
        expected = f"<(GENERIC_{name}-GENERIC_CHRGET+CHRGET)"
        if compact != expected:
            return None
        base = self.symbols.get("CHRGET")
        if not isinstance(base, int):
            return None
        return (base + CHRGET_ZP_OFFSETS[name]) & 0xFF

    def transform_source_line(self, code: str, comment: str) -> str:
        raw = code.rstrip()
        stripped = raw.strip()

        assign_match = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*(?::=|=)\s*(.+)$", stripped)
        if assign_match:
            name, expr = assign_match.groups()
            self.define_symbol(name, expr)
            return ""

        label_prefix = ""
        rest = raw
        label_match = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$", stripped)
        if label_match:
            label_prefix = f"{SYMBOL_RENAMES.get(label_match.group(1), label_match.group(1))}:"
            rest = label_match.group(2)
            if not rest:
                return label_prefix + (f" {comment}" if comment else "")

        rest_stripped = rest.strip()
        if not rest_stripped:
            return raw + (comment if comment else "")

        directive_match = re.match(r"\.(byte|word|addr|res)\b(.*)$", rest_stripped, flags=re.I)
        if directive_match:
            op = {"byte": "DB", "word": "DW", "addr": "DW", "res": "DS"}[directive_match.group(1).lower()]
            operand = self.replace_byte_extracts(directive_match.group(2).strip())
            body = f"{op:<8}        {operand}" if operand else op
            return self.join_label(label_prefix, body, comment)

        token_match = re.match(r"([A-Za-z][A-Za-z0-9_]*)\b(.*)$", rest_stripped)
        if token_match:
            op = token_match.group(1).upper()
            operand = self.replace_byte_extracts(token_match.group(2).strip())
            if op in LONG_BRANCH_INVERSE:
                return self.expand_long_branch(op, operand, comment)
            if op == "BRA":
                op = "JMP"
            if op == "JSR" and operand in CALL_RENAMES:
                operand = CALL_RENAMES[operand]
            if self.pending_low_byte_label:
                return self.split_absolute_instruction_with_low_label(label_prefix, op, operand, comment)
            body = f"{op:<8}        {operand}" if operand else op
            return self.join_label(label_prefix, body, comment)

        return raw + (comment if comment else "")

    def split_absolute_instruction_with_low_label(
        self, label_prefix: str, op: str, operand: str, comment: str
    ) -> str:
        label = self.pending_low_byte_label
        self.pending_low_byte_label = None
        opcode = ABSOLUTE_OPCODES.get(op)
        if opcode is None:
            raise ValueError(f"cannot place low-byte label inside {op} {operand}")
        low, high = self.byte_operands(operand)
        first = self.join_label(label_prefix, f"DB              {opcode}", comment)
        return "\n".join(
            [
                first,
                f"{label + ':':<24}DB              {low}",
                f"                        DB              {high}",
            ]
        )

    def patch_ror_default_memory_top(self, lines: list[str]) -> list[str]:
        for start, line in enumerate(lines):
            if line.strip() != "LDA             #<RAMSTART2":
                continue
            scan_stop = min(start + 32, len(lines))
            label_index = None
            end = None
            for index in range(start + 1, scan_stop):
                if lines[index].startswith("L40EE:"):
                    label_index = index
                    break
                if lines[index].strip().startswith("BNE             L40FA"):
                    end = index
            if label_index is None or end is None:
                break
            replacement = [
                "                        LDA             #<MSBASIC_ROR_DEFAULT_MEMTOP",
                "                        LDY             #>MSBASIC_ROR_DEFAULT_MEMTOP",
                "                        STA             LINNUM",
                "                        STY             LINNUM+1",
                "                        JMP             L40FA",
            ]
            return lines[:start] + replacement + lines[end + 1 :]
        raise RuntimeError("could not patch OSI BASIC default memory probe")

    def replace_byte_extracts(self, text: str, *, allow_symbolic_low: bool = False) -> str:
        def repl(match: re.Match[str]) -> str:
            op = match.group(1)
            inner = match.group(2).strip()
            value = self.eval_expr(inner)
            if value is not None:
                value = (value & 0xFF) if op == "<" else ((value >> 8) & 0xFF)
                return f"${value:02X}"
            if allow_symbolic_low and op == "<":
                return f"({inner})"
            return match.group(0)

        return re.sub(r"([<>])\(([^()]+)\)", repl, text)

    def join_label(self, label_prefix: str, body: str, comment: str) -> str:
        if label_prefix:
            line = f"{label_prefix:<24}{body}"
        else:
            line = f"                        {body}"
        if comment:
            line += " " + comment
        return line

    def expand_long_branch(self, op: str, operand: str, comment: str) -> str:
        self.long_branch_id += 1
        skip = f"MSB_LB_{self.long_branch_id:04d}"
        inverse = LONG_BRANCH_INVERSE[op]
        suffix = f" {comment}" if comment else ""
        return (
            f"                        {inverse:<8}        {skip}{suffix}\n"
            f"                        JMP             {operand}\n"
            f"{skip}:"
        )

    def process_line(self, raw: str) -> None:
        code, comment = split_comment(raw)
        stripped = code.strip()

        if self.in_macro_definition:
            if stripped.lower().startswith(".endmacro"):
                self.in_macro_definition = False
            return

        if stripped.lower().startswith(".macro"):
            self.in_macro_definition = True
            return

        if self.handle_conditional(stripped):
            return

        if not self.active():
            return

        if not stripped:
            if comment and self.current_segment in self.segments:
                self.emit(comment)
            return

        if stripped.lower().startswith(".include"):
            match = re.search(r'"([^"]+)"', stripped)
            if not match:
                raise ValueError(f"unsupported include syntax: {raw}")
            self.process_file(match.group(1))
            return

        if stripped.lower().startswith((".debuginfo", ".setcpu", ".macpack", ".feature")):
            return

        if self.set_segment(stripped):
            return

        if self.handle_zp_line(code):
            return

        if self.handle_macro_call(stripped):
            return

        transformed = self.transform_source_line(code, comment)
        if transformed:
            for line in transformed.splitlines():
                self.emit(line)

    def write(self, out_path: Path) -> None:
        lines: list[str] = [
            "; -----------------------------------------------------------------------------",
            "; AUTO-GENERATED FILE.  Do not edit by hand.",
            "; Generated by tools/emit_msbasic_osi_wdc.py from mist64/msbasic OSI sources.",
            "; -----------------------------------------------------------------------------",
            "",
            "; HIMON monitor ABI entry points patched from himon-rom.map before assembly.",
            f"MSBASIC_GET_CHAR_ADDR      EQU             {MONITOR_ADDRS['GET_CHAR']}",
            f"MSBASIC_PUT_CHAR_ADDR      EQU             {MONITOR_ADDRS['PUT_CHAR']}",
            f"MSBASIC_GET_CTRL_C_ADDR    EQU             {MONITOR_ADDRS['GET_CTRL_C']}",
            "MSBASIC_ROR_DEFAULT_MEMTOP EQU             $77FF",
            "",
        ]
        lines.extend(self.preamble)
        lines.append("")
        lines.append("; Zero-page layout")
        lines.extend(self.zp_equates)
        lines.append("")
        lines.append("                        CODE")
        lines.extend(
            [
                "",
                "; HIMON FNV command record for BASIC.",
                "; The monitor enters executable records at record+8.",
                "MSBASIC_FNV:",
                f"                        DB              'F','N',('V'+$80),{BASIC_CMD_FNV_HASH},$00",
                "MSBASIC_ENTRY:",
                "                        JMP             COLD_START",
            ]
        )
        for seg in SEGMENT_ORDER:
            if not self.segments[seg]:
                continue
            lines.append("")
            lines.append(f"; --- {seg} ---------------------------------------------------------------")
            lines.extend(self.segments[seg])
        lines.extend(
            [
                "",
                "; ROR monitor compatibility stubs used by the first fixed-equate pass.",
                "MSBASIC_GET_CHAR:",
                "                        JSR             MSBASIC_GET_CHAR_ADDR",
                "                        CMP             #$61",
                "                        BCC             MSBASIC_GET_CHAR_DONE",
                "                        CMP             #$7B",
                "                        BCS             MSBASIC_GET_CHAR_DONE",
                "                        AND             #$DF",
                "MSBASIC_GET_CHAR_DONE:",
                "                        RTS",
                "MSBASIC_PUT_CHAR:",
                "                        JMP             MSBASIC_PUT_CHAR_ADDR",
                "MSBASIC_MONISCNTC:",
                "MONISCNTC:",
                "                        JSR             MSBASIC_GET_CTRL_C_ADDR",
                "                        BCC             MSBASIC_MONISCNTC_DONE",
                "                        JMP             CONTROL_C_TYPED",
                "MSBASIC_MONISCNTC_DONE:",
                "                        RTS",
                "LOAD:",
                "SAVE:",
                "                        RTS",
                "",
                "                        END",
                "",
            ]
        )
        lines = self.patch_ror_default_memory_top(lines)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text("\n".join(lines), encoding="ascii", newline="\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    emitter = OsiWdcEmitter(args.source_root)
    emitter.process_file("msbasic.s")
    emitter.write(args.out)


if __name__ == "__main__":
    main()
