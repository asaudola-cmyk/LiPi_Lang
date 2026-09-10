#!/usr/bin/env python3
"""
Lipi Programming Language Runtime — Entry Point
Version: First 1.0 (Sovereign)
Runtime: lipic2 2.0.0

Usage:
    lipi                    → Interactive REPL
    lipi file.lp            → Run a Lipi file
    lipi -e 'say "Hello"'   → Evaluate one-liner
    lipi --version          → Show version
    lipi --tokens file.lp   → Show lexer tokens
    lipi --ast file.lp      → Show AST
"""
from __future__ import annotations
import sys
import argparse

# WHY: Lipi programs can be recursive (factorial, fibonacci, AST traversal)
# Python default limit is 1000 — too low for real programs.
# 10000 handles fibonacci(30), factorial(500), etc. safely.
sys.setrecursionlimit(10000)

LIPI_VERSION  = "First 1.0"
LIPI_CODENAME = "Sovereign"
LIPI_RUNTIME  = "lipic2 2.0.0 (Python)"
LIPI_GITHUB   = "https://github.com/asaudola-cmyk/LiPi_Lang"


def main() -> int:
    ap = argparse.ArgumentParser(
        prog='lipi',
        description='Lipi Programming Language — Simpler than Python, global by design',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Examples:
  lipi                       Start interactive REPL
  lipi hello.lp              Run a Lipi file
  lipi -e 'say "Hello"'      Evaluate a one-liner
  lipi --version             Show version info

Docs: {LIPI_GITHUB}
""",
    )
    ap.add_argument('file', nargs='?', help='Lipi source file (.lp)')
    ap.add_argument('script_args', nargs='*', help='Arguments passed to the Lipi script via argv()')
    ap.add_argument('-e', '--eval', metavar='CODE', help='Evaluate code string directly')
    ap.add_argument('--tokens', action='store_true', help='Show lexer tokens and exit')
    ap.add_argument('--ast', action='store_true', help='Show AST and exit')
    ap.add_argument('--repl', action='store_true', help='Start interactive REPL')
    ap.add_argument('-V', '--version', action='store_true', help='Show version')
    args = ap.parse_args()

    # WHY: Make script args available to Lipi programs via argv() builtin
    # E.g.: lipi c_codegen.lp input.lp output.c  → argv() returns ["input.lp", "output.c"]
    script_args = args.script_args if args.script_args else []
    # Store globally so interpreter can expose via argv()
    # WHY: Use pipe | as separator (null bytes not allowed in Linux env vars)
    import os
    all_args = [args.file or ''] + script_args
    os.environ['_LIPI_ARGV'] = '|'.join(all_args)


    if args.version:
        print(f'Lipi {LIPI_VERSION} — {LIPI_CODENAME}')
        print(f'Runtime:  {LIPI_RUNTIME}')
        print(f'Python:   {sys.version.split()[0]}')
        print(f'GitHub:   {LIPI_GITHUB}')
        return 0

    if args.repl or (not args.file and not args.eval):
        return _repl()

    if args.eval:
        source   = args.eval + '\n'
        filename = '<eval>'
    else:
        try:
            with open(args.file, 'r', encoding='utf-8') as f:
                source = f.read()
            filename = args.file
        except FileNotFoundError:
            print(f'❌ File not found: {args.file}', file=sys.stderr)
            return 1
        except PermissionError:
            print(f'❌ Permission denied: {args.file}', file=sys.stderr)
            return 1

    return _run(source, filename, show_tokens=args.tokens, show_ast=args.ast)



def _run(source: str, filename: str, show_tokens=False, show_ast=False) -> int:
    """Lex → Parse → Interpret one source string."""
    from .lexer import Lexer, LexError
    from .parser import Parser, ParseError
    from .interpreter import Interpreter, LipiError

    # ── Lex ──────────────────────────────────────────────────────────────────
    try:
        lexer  = Lexer(source, filename)
        tokens = lexer.tokenize()
    except LexError as e:
        print(f'❌ Lex Error: {e}', file=sys.stderr)
        return 1

    if show_tokens:
        for t in tokens:
            print(t)
        return 0

    # ── Parse ─────────────────────────────────────────────────────────────────
    try:
        ast = Parser(tokens).parse()
    except ParseError as e:
        print(f'❌ Parse Error: {e}', file=sys.stderr)
        return 1
    except Exception as e:
        print(f'❌ Parse Error: {type(e).__name__}: {e}', file=sys.stderr)
        return 1

    if show_ast:
        import pprint
        pprint.pprint(ast)
        return 0

    # ── Interpret ─────────────────────────────────────────────────────────────
    try:
        interp = Interpreter(filename=filename)
        interp.run(ast)
        return 0
    except LipiError as e:
        print(f'❌ Runtime Error: {e}', file=sys.stderr)
        return 1
    except NameError as e:
        print(f'❌ Name Error: {e}', file=sys.stderr)
        return 1
    except RecursionError:
        print('❌ Stack overflow: recursion too deep', file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print('\n❌ Interrupted', file=sys.stderr)
        return 130
    except Exception as e:
        print(f'❌ Error: {type(e).__name__}: {e}', file=sys.stderr)
        return 1


def _repl() -> int:
    """Interactive Read-Eval-Print Loop."""
    from .lexer import Lexer, LexError
    from .parser import Parser, ParseError
    from .interpreter import Interpreter, LipiError

    print(f'Lipi {LIPI_VERSION} — {LIPI_CODENAME}')
    print(f'Runtime: {LIPI_RUNTIME}')
    print('Type "exit" to quit. Unicode identifiers supported.')
    print('─' * 50)
    interp = Interpreter(filename='<repl>')

    while True:
        try:
            try:
                line = input('lipi> ')
            except EOFError:
                print()
                break

            stripped = line.strip()
            if stripped in ('exit', 'quit', 'বের', ':q', 'q'):
                break
            if not stripped:
                continue

            try:
                tokens = Lexer(line + '\n', '<repl>').tokenize()
                ast    = Parser(tokens).parse()
                for stmt in ast.stmts:
                    interp.exec(stmt, interp.global_env)
            except (LexError, ParseError) as e:
                print(f'❌ {e}')
            except LipiError as e:
                print(f'❌ {e}')
            except NameError as e:
                print(f'❌ {e}')
            except Exception as e:
                print(f'❌ {type(e).__name__}: {e}')

        except KeyboardInterrupt:
            print()
            continue

    return 0


if __name__ == '__main__':
    sys.exit(main())
