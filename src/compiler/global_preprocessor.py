#!/usr/bin/env python3
# ==============================================================================
# 🌍 লিপি Global Mode Preprocessor
# File: src/compiler/global_preprocessor.py
#
# WHY এই script:
#   লিপির compiler bootstrap (lipic) বাংলা keywords কে C-level parser এ পাঠায়।
#   কিন্তু কিছু English keywords (function, print, println, const) directly
#   supported নয়।
#   এই preprocessor টা code পড়ার আগে সব English aliases কে তাদের বাংলা
#   equivalent এ translate করে।
#   ফলাফল: একজন global developer সম্পূর্ণ English এ লিপি লিখতে পারবে।
#
# Translation Map:
#   function → কাজ
#   print/println/echo → দেখাও
#   const → ধ্রুবক
#   struct → গঠন
#   include → অন্তর্ভুক্ত
#   and → এবং
#   or  → অথবা
#   not → না
#   true → সত্য
#   false → মিথ্যা
#   null/nil → শূন্য
# ==============================================================================

import re
import sys
import os
import subprocess
import tempfile

# ─── Global → Bengali Keyword Map ────────────────────────────────────────────
# WHY: Complete mapping so English-only developers can use Lipi without
# learning any Bengali keywords. Bengali users are not affected.
KEYWORD_MAP = {
    # Function declaration
    r'\bfunction\b':  'কাজ',
    r'\bfunc\b':      'কাজ',
    r'\bdef\b':       'কাজ',
    r'\bprocedure\b': 'কাজ',
    r'\bmethod\b':    'কাজ',

    # Variable declaration
    r'\bconst\b':     'ধরি',      # WHY: const/let/var all map to ধরি for now
    r'\bval\b':       'ধরি',      # Kotlin-style val
    # let, var → already work natively

    # Output
    r'\bprintln\b':   'দেখাও',
    r'\bprint\b':     'দেখাও',
    r'\becho\b':      'দেখাও',
    r'\blog\b':       'দেখাও',
    r'\bconsole\.log\b': 'দেখাও',
    r'\bprintf\b':    'দেখাও',
    r'\bputs\b':      'দেখাও',
    r'\bprintout\b':  'দেখাও',

    # Struct/class definition
    r'\bstruct\b':    'গঠন',
    r'\bclass\b':     'গঠন',
    r'\brecord\b':    'গঠন',
    r'\btype\b':      'গঠন',      # WHY: Go-style type alias

    # Control flow — if/else/while already work but map for completeness
    r'\belseif\b':    'নাহলে_যদি',
    r'\belif\b':      'নাহলে_যদি',
    r'\bunless\b':    'যদি না',   # Ruby-style unless

    # Include/import
    r'\bimport\b':    'অন্তর্ভুক্ত',
    r'\binclude\b':   'অন্তর্ভুক্ত',
    r'\busing\b':     'অন্তর্ভুক্ত',  # C#-style using
    r'\brequire\b':   'অন্তর্ভুক্ত',  # Ruby-style require

    # Boolean literals
    r'\btrue\b':      'সত্য',
    r'\bTrue\b':      'সত্য',
    r'\bTRUE\b':      'সত্য',
    r'\bfalse\b':     'মিথ্যা',
    r'\bFalse\b':     'মিথ্যা',
    r'\bFALSE\b':     'মিথ্যা',
    r'\bnull\b':      'শূন্য',
    r'\bnil\b':       'শূন্য',
    r'\bNone\b':      'শূন্য',
    r'\bundefined\b': 'শূন্য',
    r'\bNULL\b':      'শূন্য',

    # Logical operators (word form)
    r'\band\b':       'এবং',
    r'\bAND\b':       'এবং',
    r'\bor\b':        'অথবা',
    r'\bOR\b':        'অথবা',
    r'\bnot\b':       'না',

    # Loop extras
    r'\bbreak\b':     'থামো',
    r'\bcontinue\b':  'চালিয়ে_যাও',

    # Error handling
    r'\btry\b':       'চেষ্টা',
    r'\bcatch\b':     'ধরো',
    r'\bthrow\b':     'নিক্ষেপ',
    r'\braise\b':     'নিক্ষেপ',
    r'\bfinally\b':   'অবশেষে',
}

# ─── Safe replacement (skip strings and comments) ────────────────────────────
def safe_replace(content, pattern, replacement):
    """
    WHY: Naive regex replace would also replace inside strings and comments.
    This function preserves string literals and comments unchanged.
    Example: print("hello") → দেখাও("hello") [print replaced, "hello" kept]
    """
    result = []
    i = 0
    in_string_double = False
    in_string_single = False
    in_comment_line = False
    in_comment_block = False
    
    compiled = re.compile(pattern)
    
    while i < len(content):
        # Track string/comment state
        c = content[i]
        
        # Line comment
        if not in_string_double and not in_string_single and not in_comment_block:
            if content[i:i+2] == '//':
                # Find end of line
                end = content.find('\n', i)
                if end == -1:
                    end = len(content)
                result.append(content[i:end])
                i = end
                continue
        
        # Block comment
        if not in_string_double and not in_string_single:
            if content[i:i+2] == '/*':
                end = content.find('*/', i+2)
                if end == -1:
                    end = len(content)
                else:
                    end += 2
                result.append(content[i:end])
                i = end
                continue
        
        # Double-quoted string
        if c == '"' and not in_string_single:
            if not in_string_double:
                in_string_double = True
                result.append(c)
                i += 1
                continue
            else:
                if content[i-1:i] != '\\':  # not escaped
                    in_string_double = False
                result.append(c)
                i += 1
                continue
        
        # Single-quoted string
        if c == "'" and not in_string_double:
            if not in_string_single:
                in_string_single = True
                result.append(c)
                i += 1
                continue
            else:
                if content[i-1:i] != '\\':
                    in_string_single = False
                result.append(c)
                i += 1
                continue
        
        # Inside string — don't replace
        if in_string_double or in_string_single:
            result.append(c)
            i += 1
            continue
        
        # Check for pattern match at current position
        m = compiled.match(content, i)
        if m:
            result.append(replacement)
            i = m.end()
        else:
            result.append(c)
            i += 1
    
    return ''.join(result)

def translate_to_lipi(content):
    """
    WHY: Apply all keyword translations in order.
    Order matters: longer patterns first to avoid partial matches.
    """
    # Sort by length descending to match longer patterns first
    sorted_map = sorted(KEYWORD_MAP.items(), key=lambda x: len(x[0]), reverse=True)
    
    for pattern, replacement in sorted_map:
        content = safe_replace(content, pattern, replacement)
    
    return content

def process_file(input_path, output_binary=None, verbose=False):
    """
    WHY: Main processing pipeline:
    1. Read input file
    2. Translate English keywords → Bengali
    3. Save to temp file
    4. Compile with lipic
    5. Run or save binary
    """
    # Find lipi home
    script_dir = os.path.dirname(os.path.abspath(__file__))
    lipi_home = os.path.dirname(os.path.dirname(script_dir))
    lipic = os.path.join(lipi_home, 'bin', 'lipic')
    
    if not os.path.exists(lipic):
        # Try PATH
        lipic = 'lipic'
    
    # Read input
    try:
        with open(input_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"❌ ফাইল পাওয়া যায়নি: {input_path}", file=sys.stderr)
        return 1
    
    # Detect if file uses English keywords (optimization)
    has_english = any(re.search(pat, content) for pat in KEYWORD_MAP)
    
    if verbose:
        print(f"[Global] {input_path} — English keywords: {'YES' if has_english else 'NO'}")
    
    # Translate
    translated = translate_to_lipi(content)
    
    if verbose and has_english:
        print(f"[Global] Translation complete — keywords converted to Bengali")
    
    # Write to temp file
    with tempfile.NamedTemporaryFile(
        mode='w', encoding='utf-8', 
        suffix='_global.lp', 
        delete=False
    ) as tmp:
        tmp.write(translated)
        tmp_path = tmp.name
    
    try:
        # Compile with lipic
        cmd = [lipic, tmp_path]
        if output_binary:
            cmd.extend(['-o', output_binary])
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if verbose or result.returncode != 0:
            print(result.stdout, end='')
            print(result.stderr, end='', file=sys.stderr)
        
        return result.returncode
    finally:
        os.unlink(tmp_path)

def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description='লিপি Global Mode Preprocessor — Write Lipi in any language',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 global_preprocessor.py hello.lp              # compile (Bengali output binary)
  python3 global_preprocessor.py hello.lp -o hello     # compile to specific binary
  python3 global_preprocessor.py hello.lp --translate  # just show translated code
  python3 global_preprocessor.py hello.lp --verbose    # verbose output

Supported English keywords:
  function/func/def  →  কাজ
  print/println/echo →  দেখাও
  const              →  ধরি  
  struct/class       →  গঠন
  import/include     →  অন্তর্ভুক্ত
  true/false/null    →  সত্য/মিথ্যা/শূন্য
  break/continue     →  থামো/চালিয়ে_যাও
  and/or/not         →  এবং/অথবা/না
        """
    )
    
    parser.add_argument('input', help='Input .lp file')
    parser.add_argument('-o', '--output', help='Output binary path')
    parser.add_argument('--translate', action='store_true',
                       help='Print translated code (don\'t compile)')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Verbose output')
    
    args = parser.parse_args()
    
    if args.translate:
        # Just show translation
        with open(args.input, 'r', encoding='utf-8') as f:
            content = f.read()
        translated = translate_to_lipi(content)
        print("// ═══ লিপি Global Preprocessor — Translation Output ═══")
        print(f"// Input: {args.input}")
        print("// ════════════════════════════════════════════════════")
        print(translated)
        return 0
    
    return process_file(args.input, args.output, args.verbose)

if __name__ == '__main__':
    sys.exit(main())
