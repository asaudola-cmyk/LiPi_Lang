#!/usr/bin/env python3
"""
bn2min.py — Bengali Lipi 1.0 → Minimal Syntax Converter
=========================================================
WHY: লিপি project কে global standard করতে হলে Bengali Lipi 1.0 syntax
     (কাজ, ধরি, দেখাও, যদি, { }) → Minimal syntax (fn, say, if, indentation)
     এ convert করতে হবে।

Usage:
    python3 bn2min.py input.lp -o output.lp
    python3 bn2min.py --dir tests/ --out-dir tests_min/
    python3 bn2min.py --dir . --in-place (overwrite)
"""

import re
import sys
import os
import argparse
from pathlib import Path

# ─── Keyword Mapping: Bengali → Minimal ──────────────────────────────────────
KEYWORD_MAP = {
    # Function definition
    'কাজ':          'fn',
    # Variable declaration
    'ধরি':          '',   # drop keyword: "ধরি x = 42" → "x = 42"
    'ধ্রুবক':      '',   # const — just keep assignment
    # Output
    'দেখাও':       'say',
    'বলো':          'say',
    # Control flow
    'যদি':          'if',
    'নাহলে_যদি':   'elif',
    'নাহলে':        'else',
    'যতক্ষণ':      'while',
    # Loop
    'প্রতিটি':     'each',
    'ভেতরে':        'in',
    # Return
    'ফেরত':         'return',
    # Include
    'অন্তর্ভুক্ত': 'include',
    # Struct
    'গঠন':          'struct',
    # Boolean / null
    'সত্য':         'true',
    'মিথ্যা':       'false',
    'শূন্য':        'null',
    # Logical operators
    'এবং':          'and',
    'অথবা':         'or',
    'না':            'not',
    # Loop control
    'থামো':         'break',
    'চালিয়ে_যাও': 'continue',
}

# Bengali digit to ASCII
BN_DIGIT_MAP = {chr(0x09E6 + i): str(i) for i in range(10)}

def bn_digits_to_ascii(s: str) -> str:
    """Convert Bengali numeral characters to ASCII digits."""
    return ''.join(BN_DIGIT_MAP.get(c, c) for c in s)

def convert_braces_to_indent(lines: list[str]) -> list[str]:
    """
    Convert brace-based blocks to indentation-based.
    WHY: Bengali Lipi 1.0 uses { } braces.
         Minimal syntax uses Python-like indentation.

    Handles:
      - "fn name(params) {" → "fn name params" (no brace)
      - "if cond {" → "if cond" (no brace, next line indented)
      - Inline "{ stmt }" → stmt on next indented line
      - Standalone "}" → remove
      - "} else {" → "else"
    """
    result = []
    current_indent = 0
    indent_stack = [0]

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Skip empty lines
        if not stripped:
            result.append('')
            i += 1
            continue

        # Get leading whitespace
        leading = len(line) - len(line.lstrip())
        content = line.rstrip()

        # Standalone closing brace "}" → dedent, no output
        if stripped == '}':
            if len(indent_stack) > 1:
                indent_stack.pop()
                current_indent = indent_stack[-1]
            i += 1
            continue

        # "} else {" or "} else" pattern
        m = re.match(r'\s*\}\s*(else|নাহলে)\s*\{?\s*$', content)
        if m:
            if len(indent_stack) > 1:
                indent_stack.pop()
                current_indent = indent_stack[-1]
            result.append(' ' * current_indent + 'else')
            # Push new indent level for else block
            indent_stack.append(current_indent + 4)
            current_indent = current_indent + 4
            i += 1
            continue

        # "} elif cond {" or "} নাহলে_যদি cond {"
        m = re.match(r'\s*\}\s*(elif|নাহলে_যদি)\s+(.+?)\s*\{?\s*$', content)
        if m:
            kw = 'elif'
            cond = m.group(2).strip()
            if len(indent_stack) > 1:
                indent_stack.pop()
                current_indent = indent_stack[-1]
            result.append(' ' * current_indent + f'elif {cond}')
            indent_stack.append(current_indent + 4)
            current_indent = current_indent + 4
            i += 1
            continue

        # Line ending with "{" → open block
        if content.rstrip().endswith('{'):
            # Check if this is an inline single-statement block: "if x { stmt }"
            m_inline = re.match(r'^(\s*.+?)\s*\{\s*(.+?)\s*\}\s*$', content)
            if m_inline:
                header = m_inline.group(1).rstrip()
                body_stmt = m_inline.group(2).strip()
                # Output header without brace
                result.append(' ' * leading + header.lstrip())
                # Output body indented
                result.append(' ' * (leading + 4) + body_stmt)
                i += 1
                continue

            # Multi-line block: remove trailing "{"
            header = content.rstrip().rstrip('{').rstrip().rstrip()
            result.append(' ' * leading + header.lstrip())
            # Push new indent
            new_indent = leading + 4
            indent_stack.append(new_indent)
            current_indent = new_indent
            i += 1
            continue

        # Normal line
        result.append(' ' * leading + stripped)
        i += 1

    return result

def translate_keywords(lines: list[str]) -> list[str]:
    """Replace Bengali keywords with English Minimal equivalents."""
    result = []
    for line in lines:
        original = line

        # Skip comment lines
        stripped = line.strip()
        if stripped.startswith('//') or stripped.startswith('#'):
            # Convert // comment from Bengali (keep as-is, just update keywords in code)
            result.append(line)
            continue

        # ─── Convert ধরি (drop the keyword) ──────────────────────────────
        # "ধরি x = val" → "x = val"
        line = re.sub(r'\bধরি\s+', '', line)
        line = re.sub(r'\bধ্রুবক\s+', '', line)

        # ─── Convert কাজ (function definition) ──────────────────────────
        # "কাজ name(params)" → "fn name(params)"
        line = re.sub(r'\bকাজ\b', 'fn', line)

        # ─── Convert output keywords ──────────────────────────────────────
        line = re.sub(r'\bদেখাও\b', 'say', line)
        line = re.sub(r'\bবলো\b', 'say', line)

        # ─── Convert control flow ─────────────────────────────────────────
        # WHY: Order matters — নাহলে_যদি before নাহলে
        line = re.sub(r'\bনাহলে_যদি\b', 'elif', line)
        line = re.sub(r'\bনাহলে\b', 'else', line)
        line = re.sub(r'\bযদি\b', 'if', line)
        line = re.sub(r'\bযতক্ষণ\b', 'while', line)
        line = re.sub(r'\bপ্রতিটি\b', 'each', line)
        line = re.sub(r'\bভেতরে\b', 'in', line)

        # ─── Convert return / include / struct ──────────────────────────
        line = re.sub(r'\bফেরত\b', 'return', line)
        line = re.sub(r'\bঅন্তর্ভুক্ত\b', 'include', line)
        line = re.sub(r'\bগঠন\b', 'struct', line)

        # ─── Boolean / null ───────────────────────────────────────────────
        line = re.sub(r'\bসত্য\b', 'true', line)
        line = re.sub(r'\bমিথ্যা\b', 'false', line)
        line = re.sub(r'\bশূন্য\b', 'null', line)

        # ─── Logical operators ────────────────────────────────────────────
        line = re.sub(r'\bএবং\b', 'and', line)
        line = re.sub(r'\bঅথবা\b', 'or', line)

        # ─── Loop control ─────────────────────────────────────────────────
        line = re.sub(r'\bথামো\b', 'break', line)
        line = re.sub(r'\bচালিয়ে_যাও\b', 'continue', line)

        # ─── Bengali digits in numeric literals ───────────────────────────
        # WHY: "২৫০" → "250" for global readability
        # But keep Bengali in strings (inside quotes) unchanged
        # Simple approach: convert outside of quoted strings
        line = _convert_bn_digits_outside_strings(line)

        # ─── বাংলা_সংখ্যা() → remove wrapper (lipic2 outputs ASCII anyway) ──
        # "বাংলা_সংখ্যা(x)" → "x"
        line = re.sub(r'বাংলা_সংখ্যা\(([^)]+)\)', r'\1', line)

        # ─── সিপিউ_ক্লক() → cpu_clock() ─────────────────────────────────
        line = re.sub(r'সিপিউ_ক্লক\(\)', 'cpu_clock()', line)

        # ─── মেমরি_বরাদ্দ → malloc, মেমরি_মুক্তি → free ─────────────────
        line = re.sub(r'মেমরি_বরাদ্দ\(', 'malloc(', line)
        line = re.sub(r'মেমরি_মুক্তি\(', 'free(', line)

        # ─── দৈর্ঘ্য → len ───────────────────────────────────────────────
        line = re.sub(r'\bদৈর্ঘ্য\b', 'len', line)

        # ─── সাইজ → size_of ──────────────────────────────────────────────
        line = re.sub(r'\bসাইজ\b', 'size_of', line)

        result.append(line)

    return result

def _convert_bn_digits_outside_strings(line: str) -> str:
    """
    Convert Bengali digit chars to ASCII but only OUTSIDE string literals.
    WHY: "হ্যালো ৪২" inside a string should stay as-is,
         but variable ৪২ or loop ৪২ → 42.
    """
    result = []
    in_string = False
    string_char = None
    i = 0
    while i < len(line):
        c = line[i]
        if not in_string:
            if c in ('"', "'"):
                in_string = True
                string_char = c
                result.append(c)
            elif c == '/' and i + 1 < len(line) and line[i+1] == '/':
                # Rest is comment — keep as-is
                result.append(line[i:])
                break
            else:
                # Convert Bengali digit if found
                result.append(BN_DIGIT_MAP.get(c, c))
        else:
            result.append(c)
            if c == '\\':
                i += 1
                if i < len(line):
                    result.append(line[i])
            elif c == string_char:
                in_string = False
        i += 1
    return ''.join(result)

def fix_fn_syntax(lines: list[str]) -> list[str]:
    """
    Convert function definition syntax:
    "fn name(a, b)" → "fn name a b"
    WHY: Minimal syntax uses space-separated params, not parens.
    But function CALLS keep parens: "name(a, b)" stays as-is.
    """
    result = []
    for line in lines:
        # Match: fn name(params)  — definition (starts line, possibly indented)
        m = re.match(r'^(\s*fn\s+\w[\w_\u0985-\u09FF]*)\s*\(([^)]*)\)\s*(.*)$', line)
        if m:
            prefix = m.group(1)    # "fn name"
            params = m.group(2)    # "a, b, c"
            rest = m.group(3)      # might be "{" or empty
            # Convert "a, b, c" → "a b c"
            param_list = [p.strip() for p in params.split(',') if p.strip()]
            param_str = ' '.join(param_list)
            new_line = f"{prefix} {param_str}".rstrip()
            if rest.strip() and rest.strip() not in ('{', ''):
                new_line += f" {rest.strip()}"
            result.append(new_line)
        else:
            result.append(line)
    return result

def convert_file(source: str) -> str:
    """
    Main conversion pipeline.
    Bengali Lipi 1.0 source → Minimal syntax.
    """
    # Split to lines
    lines = source.split('\n')

    # Step 1: Translate keywords
    lines = translate_keywords(lines)

    # Step 2: Convert braces to indentation
    lines = convert_braces_to_indent(lines)

    # Step 3: Fix fn definition syntax (parens → spaces)
    lines = fix_fn_syntax(lines)

    # Step 4: Clean up consecutive blank lines (max 1)
    cleaned = []
    prev_blank = False
    for line in lines:
        is_blank = not line.strip()
        if is_blank and prev_blank:
            continue
        cleaned.append(line)
        prev_blank = is_blank

    return '\n'.join(cleaned)

def process_file(input_path: str, output_path: str = None, in_place: bool = False):
    """Read, convert, write one file."""
    with open(input_path, 'r', encoding='utf-8') as f:
        source = f.read()

    converted = convert_file(source)

    if in_place or output_path == input_path:
        with open(input_path, 'w', encoding='utf-8') as f:
            f.write(converted)
        print(f'✔ {input_path} (in-place)')
    elif output_path:
        os.makedirs(os.path.dirname(output_path), exist_ok=True) if os.path.dirname(output_path) else None
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(converted)
        print(f'✔ {input_path} → {output_path}')
    else:
        print(converted)

def main():
    parser = argparse.ArgumentParser(
        prog='bn2min',
        description='Bengali Lipi 1.0 → Minimal Syntax Converter'
    )
    parser.add_argument('input', nargs='?', help='Input .lp file')
    parser.add_argument('-o', '--output', help='Output file')
    parser.add_argument('--in-place', action='store_true',
                        help='Overwrite input file in place')
    parser.add_argument('--dir', help='Convert all .lp files in directory')
    parser.add_argument('--out-dir', help='Output directory for --dir mode')
    parser.add_argument('--preview', action='store_true',
                        help='Show converted output without writing')
    args = parser.parse_args()

    if args.dir:
        in_dir = Path(args.dir)
        out_dir = Path(args.out_dir) if args.out_dir else None
        lp_files = list(in_dir.rglob('*.lp'))
        print(f'Found {len(lp_files)} .lp files in {in_dir}')
        for f in lp_files:
            if out_dir:
                rel = f.relative_to(in_dir)
                out_f = out_dir / rel
                process_file(str(f), str(out_f))
            else:
                process_file(str(f), in_place=True)
        return

    if not args.input:
        parser.print_help()
        return

    if args.preview:
        with open(args.input, 'r', encoding='utf-8') as f:
            source = f.read()
        print(convert_file(source))
        return

    process_file(args.input, args.output, args.in_place)

if __name__ == '__main__':
    main()
