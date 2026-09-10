#!/usr/bin/env python3
"""
Lipi → C Transpiler (lipic3 bootstrap)
WHY: This is the path to full independence — Lipi programs compiled
     to native C binaries, no Python needed at runtime.

Usage:
    python3 -m src.compiler.c_codegen input.lp -o output.c
    gcc -O2 output.c -lm -o output
    ./output

Design:
    - Reuses existing Lexer + Parser (no duplication)
    - All Lipi values → LipiVal (tagged union, defined in lipi_runtime.h)
    - Functions → C functions returning LipiVal
    - Variables → LipiVal locals in C
    - Recursion works naturally in C
"""
from __future__ import annotations
import sys
import os
import argparse
from io import StringIO
from typing import List, Optional

# Reuse existing Lexer and Parser
_REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, _REPO_ROOT)

from src.runtime.lexer import Lexer, LexError
from src.runtime.parser import Parser, ParseError
from src.runtime.ast_nodes import (
    Node, Program, Block, Number, String, Bool, Null, Identifier,
    BinOp, UnaryOp, Assign, FieldAssign, FieldAccess,
    FnDef, FnCall, Return, If, While, Repeat, ForRange, ForEach,
    StructDef, Include, Break, Continue,
)

# ── Name sanitization ─────────────────────────────────────────────────────────
def c_name(name: str) -> str:
    """Convert Lipi identifier to valid C identifier.
    WHY: Lipi allows Unicode identifiers (Bengali, Arabic, etc.);
         C only allows ASCII. We encode non-ASCII as _uXXXX_.
    """
    if not name:
        return '_empty_'
    result = []
    for ch in name:
        if ch.isascii() and (ch.isalnum() or ch == '_'):
            result.append(ch)
        else:
            result.append(f'_u{ord(ch):04X}_')
    out = ''.join(result)
    if out[0].isdigit():
        out = '_' + out
    # Avoid C keywords
    # Avoid C keywords AND C stdlib function names that would conflict
    # WHY: gcc complains "conflicting types for 'div'" if user defines fn div n = ...
    #      because <stdlib.h> already declares div(int,int) → div_t
    C_KEYWORDS = {
        # C language keywords
        'int','long','double','float','char','void','return','if','else',
        'while','for','do','switch','case','break','continue','struct',
        'typedef','static','inline','const','unsigned','signed','extern',
        'auto','register','volatile','sizeof','enum','union','goto','default',
        # C stdlib functions that would conflict with user-defined Lipi functions
        'div','mod','abs','min','max','pow','log','exp',
        'sin','cos','tan','sqrt','sort','round',
        'exit','time','clock','rand','srand',
        'printf','puts','putchar','getchar','scanf',
        'open','close','read','write','fopen','fclose','fread','fwrite',
        'malloc','calloc','realloc','free','memcpy','memset','memmove',
        'strlen','strcpy','strcat','strcmp','strdup','strstr','strchr',
        'atoi','atof','strtol','strtod',
        # Lipi runtime names
        'lv_null','lv_num','lv_str','lv_bool','lv_list','lv_push','lv_get',
        'lv_len','lv_add','lv_sub','lv_mul','lv_div','lv_mod','lv_neg',
        'lipi_say','lv_truthy','lv_equal',
    }
    if out in C_KEYWORDS:
        out = 'lipi_' + out

    return out


# ── C Code Generator ──────────────────────────────────────────────────────────
class CCodeGen:
    """Walks the Lipi AST and emits C code."""

    def __init__(self, source_name: str = '<input>'):
        self.source_name  = source_name
        self.out          = StringIO()
        self.indent_level = 0
        # Track declared structs to emit C struct definitions
        self.structs: dict[str, List[str]] = {}
        # Track function definitions to emit forward declarations
        self.functions: List[str] = []
        # Unique label counter for loops
        self._label_cnt = 0
        # Collect forward decls and struct defs
        self._prelude    = StringIO()
        self._fn_bodies  = StringIO()
        self._main_body  = StringIO()
        # Current output target
        self._current    = self._main_body
        self._in_fn      = False
        # Track declared variables per scope to avoid re-declaring (shadowing bug)
        # WHY: In C, "LipiVal i = i + 2" inside a while loop creates a NEW local i
        #      that shadows the outer i → infinite loop! We must emit "i = i + 2" for
        #      reassignments (already declared vars).
        self._declared_vars: set = set()
        # Stack of scope var sets for nested scopes (fn bodies)
        self._scope_stack: List[set] = []

    # ── Output helpers ────────────────────────────────────────────────────────
    def w(self, line: str = ''):
        """Write indented line to current output."""
        if line:
            self._current.write('    ' * self.indent_level + line + '\n')
        else:
            self._current.write('\n')

    def wi(self): self.indent_level += 1
    def wo(self): self.indent_level = max(0, self.indent_level - 1)

    def fresh_label(self) -> str:
        self._label_cnt += 1
        return f'_lipi_L{self._label_cnt}'

    # ── Top-level generate ────────────────────────────────────────────────────
    def generate(self, program: Program) -> str:
        """Generate complete C source from a Lipi Program AST."""
        # First pass: collect struct defs and fn defs
        self._collect_defs(program.stmts)

        # Emit header
        hdr = StringIO()
        hdr.write(f'/* Generated by Lipi→C transpiler (lipic3)\n')
        hdr.write(f'   Source: {self.source_name}\n')
        hdr.write(f'   Lipi First 1.0 — Sovereign */\n\n')
        hdr.write('#include "lipi_runtime.h"\n\n')

        # Emit struct type definitions
        for struct_name, fields in self.structs.items():
            cn = c_name(struct_name)
            hdr.write(f'/* Lipi struct: {struct_name} */\n')
            field_names_arr = ', '.join(f'"{f}"' for f in fields)
            hdr.write(f'static const char* __{cn}_fields[] = {{{field_names_arr}}};\n')
            hdr.write(f'static inline LipiVal {cn}_new() {{\n')
            hdr.write(f'    LipiVal v; v.type = LV_STRUCT;\n')
            hdr.write(f'    v.strct = lv_struct_new("{struct_name}", __{cn}_fields, {len(fields)});\n')
            hdr.write(f'    return v;\n')
            hdr.write(f'}}\n\n')

        # Forward declarations for all functions
        hdr.write('/* Forward declarations */\n')
        for fn_name in self.functions:
            hdr.write(f'static LipiVal {c_name(fn_name)}(LipiVal*, int);\n')
        hdr.write('\n')

        # Function bodies
        self._current = self._fn_bodies
        self._in_fn = True
        for stmt in program.stmts:
            if isinstance(stmt, FnDef):
                self._gen_fn_def(stmt)

        # Main body
        self._current = self._main_body
        self._in_fn = False
        self.indent_level = 1
        for stmt in program.stmts:
            if not isinstance(stmt, (FnDef, StructDef)):
                self._gen_stmt(stmt)

        # Assemble final output
        result = StringIO()
        result.write(hdr.getvalue())
        result.write(self._fn_bodies.getvalue())
        result.write('int main(void) {\n')
        result.write(self._main_body.getvalue())
        result.write('    return 0;\n')
        result.write('}\n')
        return result.getvalue()

    def _collect_defs(self, stmts):
        for stmt in stmts:
            if isinstance(stmt, StructDef):
                self.structs[stmt.name] = stmt.fields
            elif isinstance(stmt, FnDef):
                self.functions.append(stmt.name)

    # ── Statement generation ──────────────────────────────────────────────────
    def _gen_stmt(self, node: Node):
        if isinstance(node, Assign):
            val = self._gen_expr(node.value)
            cn  = c_name(node.name)
            if cn in self._declared_vars:
                # WHY: Already declared — emit reassignment, not new declaration.
                #      If we emit "LipiVal cn = ..." again inside a while/if,
                #      C creates a new local shadowing the outer → infinite loops!
                self.w(f'{cn} = {val};')
            else:
                self._declared_vars.add(cn)
                self.w(f'LipiVal {cn} = {val};')

        elif isinstance(node, FieldAssign):
            obj  = self._gen_expr(node.obj)
            val  = self._gen_expr(node.value)
            self.w(f'lv_field_set({obj}, "{node.field}", {val});')

        elif isinstance(node, FnDef):
            pass  # handled in _gen_fn_def

        elif isinstance(node, StructDef):
            pass  # handled in header

        elif isinstance(node, Return):
            if node.value:
                val = self._gen_expr(node.value)
                self.w(f'return {val};')
            else:
                self.w('return lv_null();')

        elif isinstance(node, If):
            cond = self._gen_expr(node.condition)
            self.w(f'if (lv_truthy({cond})) {{')
            self.wi()
            self._gen_block(node.then_block)
            self.wo()
            if node.else_block:
                self.w('} else {')
                self.wi()
                self._gen_block(node.else_block)
                self.wo()
            self.w('}')

        elif isinstance(node, While):
            cond = self._gen_expr(node.condition)
            self.w(f'while (lv_truthy({cond})) {{')
            self.wi()
            self._gen_block(node.body)
            self.wo()
            self.w('}')

        elif isinstance(node, Repeat):
            cnt  = self._gen_expr(node.count)
            lbl  = self.fresh_label()
            self.w(f'{{ LipiVal {lbl}_n = {cnt}; for (long long {lbl}_i=0; {lbl}_i<(long long){lbl}_n.num; {lbl}_i++) {{')
            self.wi()
            self._gen_block(node.body)
            self.wo()
            self.w('}}')

        elif isinstance(node, ForRange):
            start = self._gen_expr(node.start)
            end   = self._gen_expr(node.end)
            step  = self._gen_expr(node.step) if node.step else 'lv_num(1)'
            var   = c_name(node.var)
            lbl   = self.fresh_label()
            self.w(f'{{ LipiVal {lbl}_s={start}, {lbl}_e={end}, {lbl}_st={step};')
            self.w(f'  for (LipiVal {var}={lbl}_s; lv_le({var},{lbl}_e); {var}=lv_num({var}.num+{lbl}_st.num)) {{')
            self.wi()
            self._gen_block(node.body)
            self.wo()
            self.w('}}')

        elif isinstance(node, ForEach):
            iterable = self._gen_expr(node.iterable)
            var      = c_name(node.var)
            lbl      = self.fresh_label()
            self.w(f'{{ LipiVal {lbl}_it = {iterable};')
            self.w(f'  if ({lbl}_it.type == LV_LIST) {{')
            self.w(f'    for (int {lbl}_i=0; {lbl}_i<{lbl}_it.list->count; {lbl}_i++) {{')
            self.w(f'      LipiVal {var} = {lbl}_it.list->items[{lbl}_i];')
            self.wi()
            self._gen_block(node.body)
            self.wo()
            self.w(f'    }}')
            self.w(f'  }} else if ({lbl}_it.type == LV_STR) {{')
            self.w(f'    for (int {lbl}_i=0; {lbl}_it.str[{lbl}_i]; {lbl}_i++) {{')
            self.w(f'      char {lbl}_ch[2] = {{0}}; {lbl}_ch[0] = {lbl}_it.str[{lbl}_i];')
            self.w(f'      LipiVal {var} = lv_str({lbl}_ch);')
            self.wi()
            self._gen_block(node.body)
            self.wo()
            self.w(f'    }}')
            self.w(f'  }}')
            self.w(f'}}')

        elif isinstance(node, Break):
            self.w('break;')

        elif isinstance(node, Continue):
            self.w('continue;')

        elif isinstance(node, FnCall):
            # Expression statement (discard result)
            expr = self._gen_fn_call(node)
            self.w(f'{expr};')

        elif isinstance(node, Include):
            # Runtime include — we don't handle at compile time yet
            self.w(f'/* include "{node.path}" — skipped in C target */')

        else:
            # Expression as statement
            expr = self._gen_expr(node)
            if expr and expr != 'lv_null()':
                self.w(f'{expr};')

    def _gen_block(self, node: Node):
        if isinstance(node, (Program, Block)):
            for stmt in node.stmts:
                self._gen_stmt(stmt)
        else:
            self._gen_stmt(node)

    # ── Function definition ───────────────────────────────────────────────────
    def _gen_fn_def(self, node: FnDef):
        fn_cn    = c_name(node.name)
        params   = node.params

        self._current.write(f'/* fn {node.name} */\n')
        self._current.write(f'static LipiVal {fn_cn}(LipiVal* _args, int _nargs) {{\n')
        self.indent_level = 1

        # Save outer scope's declared vars — each fn has its own scope
        # WHY: Variables in fn body should not see main scope's declared vars
        #      and should not pollute main scope tracking either.
        outer_declared = self._declared_vars
        self._declared_vars = set()

        # Params are already declared (from _args unpack)
        for i, param in enumerate(params):
            pn = c_name(param)
            self._declared_vars.add(pn)
            self.w(f'LipiVal {pn} = (_nargs > {i}) ? _args[{i}] : lv_null();')

        # Generate body
        self._gen_block(node.body)

        # Default return
        self.w('return lv_null();')
        self._current.write('}\n\n')
        self.indent_level = 0

        # Restore outer scope
        self._declared_vars = outer_declared


    # ── Expression generation ─────────────────────────────────────────────────
    def _gen_expr(self, node: Node) -> str:
        if node is None:
            return 'lv_null()'

        if isinstance(node, Number):
            v = node.value
            if isinstance(v, float) and v.is_integer():
                return f'lv_num({int(v)})'
            return f'lv_num({v})'

        if isinstance(node, String):
            # Escape for C string literal
            escaped = node.value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r')
            # Handle {name} interpolation — simplified: just treat as literal for now
            # Full interpolation handled by runtime lv_str interp
            return f'lv_str("{escaped}")'

        if isinstance(node, Bool):
            return f'lv_bool({1 if node.value else 0})'

        if isinstance(node, Null):
            return 'lv_null()'

        if isinstance(node, Identifier):
            name = node.name
            # Built-in constants
            if name in ('true', 'TRUE'):  return 'lv_bool(1)'
            if name in ('false', 'FALSE'): return 'lv_bool(0)'
            if name in ('null', 'nil'):    return 'lv_null()'
            # Built-in functions
            if name == 'say':   return '_lipi_builtin_say'
            if name == 'len':   return '_lipi_builtin_len'
            if name == 'abs':   return '_lipi_builtin_abs'
            if name == 'sqrt':  return '_lipi_builtin_sqrt'
            if name == 'push':  return '_lipi_builtin_push'
            if name == 'list':  return '_lipi_builtin_list'
            if name == 'str':   return '_lipi_builtin_str'
            if name == 'int':   return '_lipi_builtin_int'
            return c_name(name)

        if isinstance(node, BinOp):
            l = self._gen_expr(node.left)
            r = self._gen_expr(node.right)
            op = node.op
            if op == '+':  return f'lv_add({l},{r})'
            if op == '-':  return f'lv_sub({l},{r})'
            if op == '*':  return f'lv_mul({l},{r})'
            if op == '/':  return f'lv_div({l},{r})'
            if op == '%':  return f'lv_mod({l},{r})'
            if op == '==': return f'lv_bool(lv_equal({l},{r}))'
            if op == '!=': return f'lv_bool(!lv_equal({l},{r}))'
            if op == '<':  return f'lv_bool(lv_lt({l},{r}))'
            if op == '<=': return f'lv_bool(lv_le({l},{r}))'
            if op == '>':  return f'lv_bool(lv_gt({l},{r}))'
            if op == '>=': return f'lv_bool(lv_ge({l},{r}))'
            if op == 'and': return f'lv_bool(lv_truthy({l}) && lv_truthy({r}))'
            if op == 'or':  return f'lv_bool(lv_truthy({l}) || lv_truthy({r}))'
            return f'lv_null() /* unknown op {op} */'

        if isinstance(node, UnaryOp):
            operand = self._gen_expr(node.operand)
            if node.op == '-':   return f'lv_neg({operand})'
            if node.op == 'not': return f'lv_bool(!lv_truthy({operand}))'
            return operand

        if isinstance(node, FieldAccess):
            obj = self._gen_expr(node.obj)
            return f'lv_field_get({obj}, "{node.field}")'

        if isinstance(node, FnCall):
            return self._gen_fn_call(node)

        return 'lv_null()'

    def _gen_fn_call(self, node: FnCall) -> str:
        # Special-case built-in functions
        if isinstance(node.func, Identifier):
            name = node.func.name

            if name in ('say', 'show', 'print', 'println', 'echo', 'puts', 'বলো', 'দেখাও'):
                # Print all args space-separated
                if not node.args:
                    return 'lipi_say(lv_str(""))'
                if len(node.args) == 1:
                    return f'lipi_say({self._gen_expr(node.args[0])})'
                # Multiple args: concatenate
                parts = ' '.join(f'lv_to_str({self._gen_expr(a)})' for a in node.args)
                # Simple 2-arg concat
                result = self._gen_expr(node.args[0])
                for a in node.args[1:]:
                    result = f'lv_add({result}, {self._gen_expr(a)})'
                return f'lipi_say({result})'

            if name in ('len', 'length'):
                a = self._gen_expr(node.args[0]) if node.args else 'lv_null()'
                return f'lv_len({a})'

            if name == 'abs':
                a = self._gen_expr(node.args[0]) if node.args else 'lv_null()'
                return f'lipi_abs({a})'

            if name == 'sqrt':
                a = self._gen_expr(node.args[0]) if node.args else 'lv_null()'
                return f'lipi_sqrt({a})'

            if name in ('str',):
                a = self._gen_expr(node.args[0]) if node.args else 'lv_null()'
                return f'lv_str(lv_to_str({a}))'

            if name in ('int',):
                a = self._gen_expr(node.args[0]) if node.args else 'lv_null()'
                return f'lv_num((long long){a}.num)'

            if name == 'push':
                lst = self._gen_expr(node.args[0]) if len(node.args)>0 else 'lv_null()'
                item = self._gen_expr(node.args[1]) if len(node.args)>1 else 'lv_null()'
                return f'lv_push({lst}, {item})'

            if name == 'get':
                lst = self._gen_expr(node.args[0]) if len(node.args)>0 else 'lv_null()'
                idx = self._gen_expr(node.args[1]) if len(node.args)>1 else 'lv_null()'
                return f'lv_get({lst}, {idx})'

            if name == 'list':
                n = len(node.args)
                if n == 0:
                    return 'lv_list_make(0)'
                args_c = ', '.join(self._gen_expr(a) for a in node.args)
                return f'lv_list_make({n}, {args_c})'

            # Struct constructor: MyStruct()
            if name in self.structs:
                cn = c_name(name)
                return f'{cn}_new()'

            # User-defined function call
            if name in self.functions or True:
                fn_cn = c_name(name)
                if not node.args:
                    return f'{fn_cn}(NULL, 0)'
                n = len(node.args)
                args_exprs = ', '.join(self._gen_expr(a) for a in node.args)
                lbl = self.fresh_label()
                # We need to emit: LipiVal _args[] = {...}; fn(_args, n)
                # Since _gen_expr returns a string, we inline it
                # For now: use compound literal (C99)
                args_c = ', '.join(self._gen_expr(a) for a in node.args)
                return f'{fn_cn}((LipiVal[{n}]){{{args_c}}}, {n})'

        # Function expression (dynamic call)
        fn_expr = self._gen_expr(node.func)
        n = len(node.args)
        if n == 0:
            return f'({fn_expr}).fn(NULL, 0)'
        args_c = ', '.join(self._gen_expr(a) for a in node.args)
        return f'({fn_expr}).fn((LipiVal[{n}]){{{args_c}}}, {n})'


# ── Entry point ───────────────────────────────────────────────────────────────
def compile_to_c(source: str, source_name: str = '<input>') -> str:
    """Compile Lipi source to C code string."""
    lexer  = Lexer(source, source_name)
    tokens = lexer.tokenize()
    ast    = Parser(tokens).parse()
    gen    = CCodeGen(source_name)
    return gen.generate(ast)


def main() -> int:
    ap = argparse.ArgumentParser(
        prog='lipc',
        description='Lipi → C transpiler (lipic3 bootstrap)',
    )
    ap.add_argument('file', help='Lipi source file (.lp)')
    ap.add_argument('-o', '--output', default=None, help='Output C file (default: <name>.c)')
    ap.add_argument('--emit-c', action='store_true', help='Only emit C, do not compile')
    args = ap.parse_args()

    try:
        with open(args.file, 'r', encoding='utf-8') as f:
            source = f.read()
    except FileNotFoundError:
        print(f'❌ File not found: {args.file}', file=sys.stderr)
        return 1

    try:
        c_code = compile_to_c(source, args.file)
    except (LexError, ParseError) as e:
        print(f'❌ Compile Error: {e}', file=sys.stderr)
        return 1

    out_file = args.output or (os.path.splitext(args.file)[0] + '.c')
    with open(out_file, 'w') as f:
        f.write(c_code)

    print(f'✔ {args.file} → {out_file}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
