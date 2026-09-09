from __future__ import annotations
import re
from enum import Enum, auto
from typing import List, NamedTuple, Any

class TT(Enum):
    NUMBER  = auto()  # 42, ৪২, 3.14
    STRING  = auto()  # "hello"
    IDENT   = auto()  # variable/function name
    KW      = auto()  # keyword
    OP      = auto()  # operator or punctuation
    NL      = auto()  # significant newline
    INDENT  = auto()  # indentation increase
    DEDENT  = auto()  # indentation decrease
    EOF     = auto()

class Token(NamedTuple):
    type: TT
    value: Any
    line: int
    col: int

# ALL keywords — English minimal + Bengali Style E
KEYWORDS = {
    # English
    'if', 'else', 'elif', 'fn', 'return', 'say', 'show', 'print', 'println',
    'repeat', 'for', 'each', 'in', 'while', 'include', 'import',
    'struct', 'class', 'null', 'nil', 'true', 'false',
    'and', 'or', 'not', 'break', 'continue', 'step', 'to', 'times',
    # Bengali keywords
    'যদি', 'নাহলে', 'নাহলে_যদি', 'কাজ', 'ফেরত', 'বলো', 'দেখাও',
    'যতক্ষণ', 'ধরো', 'ধরি', 'অন্তর্ভুক্ত', 'গঠন', 'শূন্য', 'সত্য', 'মিথ্যা',
    'এবং', 'অথবা', 'না', 'থামো', 'চালিয়ে_যাও', 'প্রতিটি', 'বার', 'ভেতরে',
}

# Bengali digit → ASCII digit map
BN_DIGIT_MAP = {chr(0x09E6 + i): str(i) for i in range(10)}
BN_DIGITS = set(BN_DIGIT_MAP.keys())

def bn_to_ascii_num(s: str) -> str:
    """Convert Bengali numeral string to ASCII: '৪২' → '42'"""
    return ''.join(BN_DIGIT_MAP.get(c, c) for c in s)

class LexError(Exception): pass

class Lexer:
    def __init__(self, source: str, filename: str = '<input>'):
        self.source = source
        self.filename = filename
        self.pos = 0
        self.line = 1
        self.col = 1
        self.tokens: List[Token] = []
        self.indent_stack = [0]  # WHY: track indentation levels for INDENT/DEDENT

    def error(self, msg: str):
        raise LexError(f"{self.filename}:{self.line}:{self.col}: {msg}")

    def cur(self) -> str:
        return self.source[self.pos] if self.pos < len(self.source) else '\0'

    def peek(self, offset: int = 1) -> str:
        p = self.pos + offset
        return self.source[p] if p < len(self.source) else '\0'

    def advance(self) -> str:
        c = self.source[self.pos]
        self.pos += 1
        if c == '\n':
            self.line += 1
            self.col = 1
        else:
            self.col += 1
        return c

    def emit(self, tt: TT, val: Any = None, ln: int = None, col: int = None):
        self.tokens.append(Token(tt, val, ln or self.line, col or self.col))

    def tokenize(self) -> List[Token]:
        while self.pos < len(self.source):
            self._next_token()
        # Close all open indent levels at EOF
        while len(self.indent_stack) > 1:
            self.indent_stack.pop()
            self.emit(TT.DEDENT, 0)
        self.emit(TT.EOF, None)
        return self.tokens

    def _next_token(self):
        c = self.cur()
        ln, col = self.line, self.col

        # Newline — significant in Lipi (block boundaries)
        if c == '\n':
            self.advance()
            # Don't emit NL for consecutive blank lines
            # (handled by _handle_indent checking if next line is blank)
            self.emit(TT.NL, '\n', ln, col)
            self._handle_indent()
            return

        if c == '\r':
            self.advance()  # skip \r (Windows \r\n)
            return

        # Horizontal whitespace — skip
        if c in ' \t':
            self.advance()
            return

        # Line comment //
        if c == '/' and self.peek() == '/':
            while self.pos < len(self.source) and self.cur() != '\n':
                self.advance()
            return

        # Block comment /* */
        if c == '/' and self.peek() == '*':
            self.advance(); self.advance()  # skip /*
            depth = 1
            while self.pos < len(self.source) and depth > 0:
                if self.cur() == '/' and self.peek() == '*':
                    self.advance(); self.advance()
                    depth += 1
                elif self.cur() == '*' and self.peek() == '/':
                    self.advance(); self.advance()
                    depth -= 1
                else:
                    self.advance()
            return

        # Hash comment # (Python/shell style)
        if c == '#':
            while self.pos < len(self.source) and self.cur() != '\n':
                self.advance()
            return

        # String literal " or '
        if c in '"\'':
            self._scan_string(ln, col)
            return

        # ASCII digit
        if c.isdigit():
            self._scan_number_ascii(ln, col)
            return

        # Bengali digit ০-৯
        if c in BN_DIGITS:
            self._scan_number_bengali(ln, col)
            return

        # Operator / punctuation
        if c in '+-*/%=!<>&|^~()[]{}.,;:':
            self._scan_operator(ln, col)
            return

        # Identifier or keyword (ASCII letter, _, or Unicode letter)
        if c.isalpha() or c == '_' or (ord(c) > 127 and c not in BN_DIGITS):
            self._scan_ident(ln, col)
            return

        self.error(f"Unexpected character: {repr(c)}")

    def _handle_indent(self):
        """After newline: measure indentation and emit INDENT/DEDENT tokens.
        WHY: Lipi uses indentation like Python — no braces needed.
        """
        # Count spaces (tabs = 4 spaces)
        spaces = 0
        while self.pos < len(self.source) and self.cur() in ' \t':
            if self.cur() == '\t':
                spaces += 4
            else:
                spaces += 1
            self.pos += 1
            self.col += 1

        # Skip blank lines and lines starting with comments
        if self.pos >= len(self.source):
            return
        next_c = self.cur()
        if next_c in '\n\r':
            return  # blank line
        if next_c == '/' and self.peek() == '/':
            return  # comment line
        if next_c == '#':
            return  # hash comment

        current = self.indent_stack[-1]

        if spaces > current:
            # WHY: more indentation = entering a new block
            self.indent_stack.append(spaces)
            self.emit(TT.INDENT, spaces)
        elif spaces < current:
            # WHY: less indentation = leaving one or more blocks
            while self.indent_stack and self.indent_stack[-1] > spaces:
                self.indent_stack.pop()
                self.emit(TT.DEDENT, spaces)
            if not self.indent_stack or self.indent_stack[-1] != spaces:
                self.error(
                    f"IndentationError: expected {self.indent_stack[-1] if self.indent_stack else 0} "
                    f"spaces, got {spaces}"
                )
        # same level: no token emitted

    def _scan_string(self, ln: int, col: int):
        """Scan string literal with escape sequences."""
        quote = self.advance()  # opening quote
        chars = []
        while self.pos < len(self.source):
            c = self.cur()
            if c == quote:
                self.advance()  # closing quote
                break
            if c == '\\':
                self.advance()
                esc = self.advance()
                chars.append({'n': '\n', 't': '\t', 'r': '\r',
                               '\\': '\\', '"': '"', "'": "'",
                               '{': '{', '}': '}'}.get(esc, '\\' + esc))
            else:
                chars.append(self.advance())
        else:
            self.error("Unterminated string literal")
        self.emit(TT.STRING, ''.join(chars), ln, col)

    def _scan_number_ascii(self, ln: int, col: int):
        """Scan integer or float with ASCII digits."""
        num = []
        while self.pos < len(self.source) and self.cur().isdigit():
            num.append(self.advance())
        # Float?
        if self.pos < len(self.source) and self.cur() == '.' and self.peek() != '.':
            # WHY: '..' is range operator, not decimal point
            num.append(self.advance())  # '.'
            while self.pos < len(self.source) and self.cur().isdigit():
                num.append(self.advance())
            self.emit(TT.NUMBER, float(''.join(num)), ln, col)
        else:
            self.emit(TT.NUMBER, int(''.join(num)), ln, col)

    def _scan_number_bengali(self, ln: int, col: int):
        """Scan Bengali digit string (০-৯) → Python int."""
        num = []
        while self.pos < len(self.source) and self.cur() in BN_DIGITS:
            num.append(BN_DIGIT_MAP[self.advance()])
        self.emit(TT.NUMBER, int(''.join(num)), ln, col)

    def _scan_operator(self, ln: int, col: int):
        """Scan one or two character operators."""
        c = self.advance()
        nxt = self.cur()
        two = c + nxt
        # WHY: check two-char ops first to avoid e.g. '=' being emitted before '=='
        if two in {'==', '!=', '<=', '>=', '<<', '>>', '&&', '||',
                   '..', '->', '+=', '-=', '*=', '/=', '//', '**'}:
            self.advance()  # consume second char
            self.emit(TT.OP, two, ln, col)
        else:
            self.emit(TT.OP, c, ln, col)

    def _scan_ident(self, ln: int, col: int):
        """Scan identifier or keyword. Supports Bengali Unicode letters."""
        chars = []
        while self.pos < len(self.source):
            c = self.cur()
            is_ascii = c.isalnum() or c == '_'
            # Bengali letter range U+0985-U+09FF, excluding digit range U+09E6-U+09EF
            is_bn_letter = (0x0985 <= ord(c) <= 0x09FF) and c not in BN_DIGITS
            # Also allow underscore-connected Bengali words (নাহলে_যদি)
            if is_ascii or is_bn_letter:
                chars.append(self.advance())
            else:
                break
        name = ''.join(chars)
        if name in KEYWORDS:
            self.emit(TT.KW, name, ln, col)
        else:
            self.emit(TT.IDENT, name, ln, col)
