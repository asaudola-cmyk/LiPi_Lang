#!/usr/bin/env python3
# ==============================================================================
# 🌟 লিপি ২.০ — Radical Syntax Transpiler
# "Text এর মতো লেখো, Computer বুঝবে"
#
# Design Philosophy:
#   - Python থেকেও সহজ
#   - কোনো parentheses নেই function call এ
#   - কোনো colon নেই if/fn/for এর পরে
#   - Indentation দিয়ে block (Python style)
#   - "loop 5" = repeat 5 times (Python: for _ in range(5))
#   - "for i in 1..10" = range loop
#   - "each item in list" = foreach
#   - String interpolation: "Hello {name}!"
#   - Unicode AND ASCII both work everywhere
#   - Bengali OR English keywords — user chooses
#
# This transpiler converts Lipi 2.0 → Lipi 1.0 Bengali → binary
# ==============================================================================

import re
import sys
import os
import subprocess
import tempfile

# ─── Keyword Map (English → Bengali Lipi 1.0) ────────────────────────────────
KEYWORDS = {
    'show':     'দেখাও',
    'print':    'দেখাও',
    'println':  'দেখাও',
    'fn':       'কাজ',
    'function': 'কাজ',
    'def':      'কাজ',
    'return':   'ফেরত',
    'if':       'যদি',
    'else':     'নাহলে',
    'elif':     'নাহলে_যদি',
    'elseif':   'নাহলে_যদি',
    'while':    'যতক্ষণ',
    'let':      'ধরি',
    'var':      'ধরি',
    'const':    'ধ্রুবক',
    'struct':   'গঠন',
    'true':     'সত্য',
    'false':    'মিথ্যা',
    'null':     'শূন্য',
    'nil':      'শূন্য',
    'break':    'থামো',
    'continue': 'চালিয়ে_যাও',
    'include':  'অন্তর্ভুক্ত',
    'import':   'অন্তর্ভুক্ত',
    'and':      'এবং',
    'or':       'অথবা',
    'not':      'না',
    'new':      'নতুন',
}

# ─── Transpiler ───────────────────────────────────────────────────────────────
class LipiTranspiler:
    """
    Converts Lipi 2.0 clean syntax → Lipi 1.0 Bengali syntax.

    Lipi 2.0 key innovations over Python:
    1. No parentheses for function CALLS: show x  (not show(x))
    2. No colon after if/fn/for/while
    3. loop N  (not for _ in range(N))
    4. for i in 1..10  (not for i in range(1, 11))
    5. each item in list  (not for item in list)
    6. "Hello {name}!"  string interpolation (built-in)
    7. Zero noise characters
    """

    def __init__(self):
        self.output = []
        self.indent_stack = [0]  # indentation levels
        self.brace_stack = []    # track open braces to close
        self.loop_counter = 0    # unique loop variable names
        self.in_func = False

    def transpile(self, source):
        lines = source.split('\n')
        result_lines = []
        i = 0

        while i < len(lines):
            line = lines[i]
            stripped = line.rstrip()

            # Empty line
            if not stripped or stripped.startswith('//') or stripped.startswith('#'):
                if stripped.startswith('#'):
                    result_lines.append('//' + stripped[1:])
                else:
                    result_lines.append(stripped)
                i += 1
                continue

            # Get indentation level
            indent = len(line) - len(line.lstrip())
            content = stripped.lstrip()

            # Close braces for dedent
            while self.indent_stack and indent < self.indent_stack[-1]:
                self.indent_stack.pop()
                result_lines.append(' ' * indent + '}')

            # Process the line
            translated = self._translate_line(content, indent, lines, i)
            if translated is not None:
                if isinstance(translated, list):
                    result_lines.extend(translated)
                else:
                    result_lines.append(translated)

            # Check if next line is more indented (block start)
            if i + 1 < len(lines):
                next_stripped = lines[i+1].rstrip()
                if next_stripped.strip():
                    next_indent = len(lines[i+1]) - len(lines[i+1].lstrip())
                    if next_indent > indent:
                        # This line starts a block — add opening brace
                        if result_lines and not result_lines[-1].rstrip().endswith('{'):
                            result_lines[-1] = result_lines[-1] + ' {'
                        self.indent_stack.append(next_indent)

            i += 1

        # Close remaining braces
        while len(self.indent_stack) > 1:
            self.indent_stack.pop()
            result_lines.append('}')

        return '\n'.join(result_lines)

    def _translate_line(self, content, indent, all_lines, line_idx):
        """Translate a single Lipi 2.0 line to Lipi 1.0 Bengali."""
        prefix = ' ' * indent

        # ── loop N ──────────────────────────────────────────────────────────
        # "loop 5" → while loop with counter
        m = re.match(r'^loop\s+(\w+)', content)
        if m:
            n = m.group(1)
            self.loop_counter += 1
            var = f'__loop_{self.loop_counter}'
            lines = [
                f'{prefix}ধরি {var} = ০',
                f'{prefix}যতক্ষণ {var} < {n} {{'
            ]
            # Append counter increment at end of block — track with stack
            self.indent_stack.append(indent + 4)
            return lines

        # ── for i in 1..10 ──────────────────────────────────────────────────
        # "for i in 1..10" → while loop
        m = re.match(r'^for\s+(\w+)\s+in\s+(\w+)\.\.(\w+)', content)
        if m:
            var, start, end = m.group(1), m.group(2), m.group(3)
            lines = [
                f'{prefix}ধরি {var} = {start}',
                f'{prefix}যতক্ষণ {var} <= {end} {{'
            ]
            return lines

        # ── each item in list ────────────────────────────────────────────────
        # "each item in mylist" → while with index
        m = re.match(r'^each\s+(\w+)\s+in\s+(.+)', content)
        if m:
            var, lst = m.group(1), m.group(2).strip()
            self.loop_counter += 1
            idx = f'__idx_{self.loop_counter}'
            lines = [
                f'{prefix}ধরি {idx} = ০',
                f'{prefix}যতক্ষণ {idx} < দৈর্ঘ্য({lst}) {{'
                f'  ধরি {var} = {lst}[{idx}]  // each item',
            ]
            return lines

        # ── fn name arg1 arg2 ────────────────────────────────────────────────
        # "fn greet name age" → কাজ greet(name, age)
        # Note: first word is fn/def/function, second is name, rest are args
        m = re.match(r'^(fn|def|function)\s+(\w[\w_]*)\s*(.*)', content)
        if m:
            fn_name = m.group(2)
            args_str = m.group(3).strip()
            # Args can be: "a b c" or "a, b, c" or "(a, b)"
            if args_str.startswith('('):
                # Already has parens
                args = args_str
            elif args_str:
                # Space or comma separated → convert to comma + parens
                args_list = re.split(r'[\s,]+', args_str)
                args = '(' + ', '.join(a for a in args_list if a) + ')'
            else:
                args = '()'
            return f'{prefix}কাজ {fn_name}{args}'

        # ── show / print without parens ──────────────────────────────────────
        # "show Hello World" → দেখাও "Hello World"  (string)
        # "show x" → দেখাও x  (variable)
        # "show "text" x" → দেখাও "text", x
        m = re.match(r'^(show|print|println|puts|echo|log)\s+(.*)', content)
        if m:
            args = m.group(2).strip()
            # String interpolation: "Hello {name}!" → needs special handling
            args = self._expand_interpolation(args)
            return f'{prefix}দেখাও {args}'

        # ── if condition (no colon) ──────────────────────────────────────────
        m = re.match(r'^if\s+(.+)', content)
        if m:
            cond = m.group(1).strip().rstrip(':')  # remove trailing colon if any
            cond = self._translate_expr(cond)
            return f'{prefix}যদি {cond}'

        # ── else ────────────────────────────────────────────────────────────
        if content.strip() in ('else', 'else:'):
            # Close previous if block, open else
            if self.indent_stack and indent < self.indent_stack[-1]:
                self.indent_stack.pop()
            return f'{prefix}}} নাহলে'

        # ── elif / elseif condition ──────────────────────────────────────────
        m = re.match(r'^(elif|elseif|else if)\s+(.+)', content)
        if m:
            cond = m.group(2).strip().rstrip(':')
            cond = self._translate_expr(cond)
            if self.indent_stack and indent < self.indent_stack[-1]:
                self.indent_stack.pop()
            return f'{prefix}}} নাহলে_যদি {cond}'

        # ── while condition ──────────────────────────────────────────────────
        m = re.match(r'^while\s+(.+)', content)
        if m:
            cond = m.group(1).strip().rstrip(':')
            cond = self._translate_expr(cond)
            return f'{prefix}যতক্ষণ {cond}'

        # ── let/var/const x = value ──────────────────────────────────────────
        m = re.match(r'^(let|var|const)\s+(.+)', content)
        if m:
            rest = m.group(2).strip()
            keyword = 'ধরি' if m.group(1) in ('let', 'var') else 'ধ্রুবক'
            return f'{prefix}{keyword} {rest}'

        # ── return ──────────────────────────────────────────────────────────
        m = re.match(r'^return\s*(.*)', content)
        if m:
            val = m.group(1).strip()
            return f'{prefix}ফেরত {val}' if val else f'{prefix}ফেরত'

        # ── struct name ──────────────────────────────────────────────────────
        m = re.match(r'^(struct|class|record)\s+(\w+)', content)
        if m:
            name = m.group(2)
            return f'{prefix}গঠন {name}'

        # ── include/import ───────────────────────────────────────────────────
        m = re.match(r'^(include|import)\s+"(.+)"', content)
        if m:
            path = m.group(2)
            return f'{prefix}অন্তর্ভুক্ত "{path}"'

        # ── Everything else (assignment, expression, raw lipi) ───────────────
        # Translate common English keywords in expressions
        translated = self._translate_expr(content)
        return f'{prefix}{translated}'

    def _translate_expr(self, expr):
        """Translate English keywords within an expression."""
        # Replace logical operators
        expr = re.sub(r'\band\b', 'এবং', expr)
        expr = re.sub(r'\bor\b', 'অথবা', expr)
        expr = re.sub(r'\bnot\b', 'না', expr)
        expr = re.sub(r'\btrue\b', 'সত্য', expr)
        expr = re.sub(r'\bTrue\b', 'সত্য', expr)
        expr = re.sub(r'\bfalse\b', 'মিথ্যা', expr)
        expr = re.sub(r'\bFalse\b', 'মিথ্যা', expr)
        expr = re.sub(r'\bnull\b', 'শূন্য', expr)
        expr = re.sub(r'\bnil\b', 'শূন্য', expr)
        expr = re.sub(r'\bNone\b', 'শূন্য', expr)
        # != can be ≠ or ne
        expr = re.sub(r'\bne\b', '!=', expr)
        expr = re.sub(r'\beq\b', '==', expr)
        expr = re.sub(r'\blt\b', '<', expr)
        expr = re.sub(r'\bgt\b', '>', expr)
        return expr

    def _expand_interpolation(self, args):
        """
        Handle string interpolation: "Hello {name}!" → "Hello", name, "!"
        In Lipi 1.x, string interpolation doesn't work natively,
        so we split the string and use comma syntax for দেখাও.

        Example:
          "Hello {name}!"  →  "Hello", name, "!"
          "{x} + {y} = {x+y}"  →  x, "+", y, "=", x+y
        """
        # If it's a plain string with no interpolation, return as-is
        if not (args.startswith('"') and '{' in args):
            return args

        # Remove outer quotes
        inner = args[1:-1] if args.startswith('"') and args.endswith('"') else args

        # Split by {var} patterns
        parts = re.split(r'\{([^}]+)\}', inner)
        result_parts = []

        for i, part in enumerate(parts):
            if i % 2 == 0:
                # Literal string part
                if part:
                    result_parts.append(f'"{part}"')
            else:
                # Variable/expression part
                result_parts.append(part.strip())

        return ', '.join(result_parts) if result_parts else args


def transpile_file(input_path, output_binary=None, show_translation=False, verbose=False):
    """Main pipeline: Lipi 2.0 → Lipi 1.0 Bengali → binary"""

    # Find lipic
    script_dir = os.path.dirname(os.path.abspath(__file__))
    lipi_home = os.path.dirname(os.path.dirname(script_dir))
    lipic = os.path.join(lipi_home, 'bin', 'lipic')
    preprocessor = os.path.join(lipi_home, 'src', 'compiler', 'preprocessor.sh')

    if not os.path.exists(lipic):
        lipic = 'lipic'

    # Read source
    try:
        with open(input_path, 'r', encoding='utf-8') as f:
            source = f.read()
    except FileNotFoundError:
        print(f"❌ File not found: {input_path}", file=sys.stderr)
        return 1

    # Transpile
    t = LipiTranspiler()
    lipi1_code = t.transpile(source)

    if show_translation:
        print("// ══════════════════════════════════════════════════")
        print(f"// Lipi 2.0 → Lipi 1.0 Translation of: {input_path}")
        print("// ══════════════════════════════════════════════════")
        print(lipi1_code)
        return 0

    if verbose:
        print(f"[Lipi 2.0] Transpiled {input_path}")
        if hasattr(t, 'warnings') and t.warnings:
            for w in t.warnings:
                print(f"[warn] {w}")

    # Write translated code to temp file
    with tempfile.NamedTemporaryFile(
        mode='w', encoding='utf-8',
        suffix='_lipi2.lp',
        delete=False
    ) as tmp:
        tmp.write(lipi1_code)
        tmp_path = tmp.name

    try:
        # Optional: run Bengali preprocessor (নাহলে_যদি fix)
        processed_path = tmp_path
        if os.path.exists(preprocessor):
            with tempfile.NamedTemporaryFile(
                mode='w', encoding='utf-8',
                suffix='_preproc.lp',
                delete=False
            ) as tmp2:
                preproc_result = subprocess.run(
                    ['bash', preprocessor, tmp_path],
                    capture_output=True, text=True
                )
                tmp2.write(preproc_result.stdout if preproc_result.stdout else lipi1_code)
                processed_path = tmp2.name

        # Compile with lipic
        cmd = [lipic, processed_path]
        if output_binary:
            cmd.extend(['-o', output_binary])

        result = subprocess.run(cmd, capture_output=True, text=True)
        print(result.stdout, end='')
        if result.returncode != 0:
            print(result.stderr, end='', file=sys.stderr)

        # Cleanup preprocessor tmp
        if processed_path != tmp_path and os.path.exists(processed_path):
            os.unlink(processed_path)

        return result.returncode
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


def main():
    import argparse

    parser = argparse.ArgumentParser(
        prog='lipi2',
        description='🌟 Lipi 2.0 — Simpler than Python',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Lipi 2.0 Syntax (simpler than Python):
  show "Hello World"          # no parens needed
  let x = 42                  # simple variable
  fn greet name               # no parens, no colon
      show "Hello" name
  if x > 10                   # no colon
      show "big"
  else
      show "small"
  loop 5                      # repeat 5 times
      show "hi"
  for i in 1..10              # range loop
      show i

vs Python:
  print("Hello World")        # needs parens
  x = 42
  def greet(name):            # needs parens + colon
      print(f"Hello {name}")
  if x > 10:                  # needs colon
      print("big")
  else:
      print("small")
  for _ in range(5):          # verbose!
      print("hi")
  for i in range(1, 11):      # confusing range(1,11)!
      print(i)
        """
    )
    parser.add_argument('input', nargs='?', help='Input .lp2 file')
    parser.add_argument('-o', '--output', help='Output binary')
    parser.add_argument('--show', action='store_true',
                        help='Show translated Lipi 1.0 code')
    parser.add_argument('-v', '--verbose', action='store_true')
    parser.add_argument('--demo', action='store_true', help='Run built-in demo')

    args = parser.parse_args()

    if args.demo or not args.input:
        demo = '''// 🌟 Lipi 2.0 Demo — Simpler than Python!

fn factorial n
    if n <= 1
        return 1
    return n * factorial n - 1

fn is_prime n
    if n < 2
        return 0
    let i = 2
    while i * i <= n
        if n % i == 0
            return 0
        i = i + 1
    return 1

show "=== Factorial ==="
for i in 1..8
    let f = factorial i
    show i

show "=== Primes up to 20 ==="
let n = 2
while n <= 20
    let p = is_prime n
    if p == 1
        show n
    n = n + 1
'''
        print("// ── Lipi 2.0 Source ──")
        print(demo)
        print("// ── Translated to Lipi 1.0 ──")
        t = LipiTranspiler()
        print(t.transpile(demo))
        return 0

    return transpile_file(args.input, args.output, args.show, args.verbose)


if __name__ == '__main__':
    sys.exit(main())
