#!/usr/bin/env python3
"""
লিপি ২.০ Runtime Entry Point
Usage:
    python -m src.runtime file.lp
    python -m src.runtime -e 'say "Hello"'
    python -m src.runtime --repl
    python -m src.runtime --tokens file.lp
    python -m src.runtime --ast file.lp
"""
from __future__ import annotations
import sys
import os
import argparse

# WHY: Lipi programs can be recursive (factorial, fibonacci, AST traversal)
# Python default limit is 1000 — too low for real programs.
# 10000 handles fibonacci(30), factorial(500), etc. safely.
sys.setrecursionlimit(10000)


def main() -> int:
    ap = argparse.ArgumentParser(
        prog='lipic2',
        description='লিপি ২.০ Runtime — Simpler than Python',
    )
    ap.add_argument('file', nargs='?', help='Lipi source file (.lp)')
    ap.add_argument('-o', '--output', help='Output path (ignored, for compatibility)')
    ap.add_argument('-e', '--eval', metavar='CODE', help='Evaluate code string directly')
    ap.add_argument('--tokens', action='store_true', help='Show lexer tokens and exit')
    ap.add_argument('--ast', action='store_true', help='Show AST and exit')
    ap.add_argument('--repl', action='store_true', help='Start interactive REPL')
    ap.add_argument('-V', '--version', action='store_true', help='Show version')
    args = ap.parse_args()

    if args.version:
        print('লিপি ২.০ Runtime v2.0.0')
        return 0

    if args.repl or (not args.file and not args.eval):
        return _repl()

    if args.eval:
        source = args.eval + '\n'
        filename = '<eval>'
    else:
        try:
            with open(args.file, 'r', encoding='utf-8') as f:
                source = f.read()
            filename = args.file
        except FileNotFoundError:
            print(f'❌ ফাইল পাওয়া যায়নি: {args.file}', file=sys.stderr)
            return 1
        except PermissionError:
            print(f'❌ ফাইল পড়ার অনুমতি নেই: {args.file}', file=sys.stderr)
            return 1

    return _run(source, filename, show_tokens=args.tokens, show_ast=args.ast)


def _run(source: str, filename: str, show_tokens=False, show_ast=False) -> int:
    """Lex → Parse → Interpret one source string."""
    from .lexer import Lexer, LexError
    from .parser import Parser, ParseError
    from .interpreter import Interpreter, LipiError

    # ── Lex ──────────────────────────────────────────────────────────────────
    try:
        lexer = Lexer(source, filename)
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

    print('লিপি ২.০ REPL — "exit" বা "বের" লিখে বের হও')
    print('─' * 40)
    interp = Interpreter(filename='<repl>')

    while True:
        try:
            try:
                line = input('lipi> ')
            except EOFError:
                print()
                break

            stripped = line.strip()
            if stripped in ('exit', 'quit', 'বের', 'বাহির'):
                break
            if not stripped:
                continue

            # Run line through full pipeline but reuse interpreter state
            try:
                from .lexer import Lexer
                from .parser import Parser
                tokens = Lexer(line + '\n', '<repl>').tokenize()
                ast = Parser(tokens).parse()
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
