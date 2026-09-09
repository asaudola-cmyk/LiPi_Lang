from __future__ import annotations
from typing import List, Optional, Any
from .lexer import TT, Token
from .ast_nodes import (
    Program, Block, Number, String, Bool, Null, Identifier,
    BinOp, UnaryOp, Assign, FieldAssign, FieldAccess,
    FnDef, FnCall, Return, If, While, Repeat, ForRange, ForEach,
    Include, StructDef, Break, Continue, Node
)

class ParseError(Exception): pass

class Parser:
    def __init__(self, tokens: List[Token]):
        self.tokens = tokens
        self.pos = 0

    def cur(self) -> Token:
        return self.tokens[self.pos] if self.pos < len(self.tokens) else Token(TT.EOF, None, 0, 0)

    def peek(self, offset: int = 1) -> Token:
        p = self.pos + offset
        return self.tokens[p] if p < len(self.tokens) else Token(TT.EOF, None, 0, 0)

    def advance(self) -> Token:
        tok = self.tokens[self.pos]
        self.pos += 1
        return tok

    def skip_newlines(self):
        """Skip NL tokens. WHY: NL between statements is not always significant."""
        while self.cur().type == TT.NL:
            self.advance()

    def expect(self, tt: TT = None, val: Any = None) -> Token:
        tok = self.cur()
        if tt and tok.type != tt:
            raise ParseError(f"Line {tok.line}: Expected {tt.name}, got {tok.type.name} ({repr(tok.value)})")
        if val is not None and tok.value != val:
            raise ParseError(f"Line {tok.line}: Expected '{val}', got '{tok.value}'")
        return self.advance()

    def match(self, tt: TT = None, val: Any = None) -> bool:
        tok = self.cur()
        if tt and tok.type != tt: return False
        if val is not None and tok.value != val: return False
        return True

    def consume_if(self, tt: TT = None, val: Any = None) -> Optional[Token]:
        if self.match(tt, val):
            return self.advance()
        return None

    def parse(self) -> Program:
        self.skip_newlines()
        stmts = []
        while self.cur().type != TT.EOF:
            stmt = self.parse_stmt()
            if stmt is not None:
                stmts.append(stmt)
            self.skip_newlines()
        return Program(stmts)

    def parse_block(self) -> Block:
        """Parse INDENT ... DEDENT block."""
        self.skip_newlines()
        if self.cur().type != TT.INDENT:
            raise ParseError(f"Line {self.cur().line}: Expected indented block")
        self.advance()  # consume INDENT
        stmts = []
        self.skip_newlines()
        while self.cur().type not in (TT.DEDENT, TT.EOF):
            stmt = self.parse_stmt()
            if stmt is not None:
                stmts.append(stmt)
            self.skip_newlines()
        self.consume_if(TT.DEDENT)
        return Block(stmts)

    def parse_inline_or_block(self) -> Node:
        """Parse either inline stmt or indented block.
        WHY: 'if x > 10 say hi' vs 'if x > 10\n    say hi\n    say bye'
        """
        self.skip_newlines()
        if self.cur().type == TT.INDENT:
            return self.parse_block()
        else:
            stmt = self.parse_stmt()
            return Block([stmt]) if stmt else Block([])

    def parse_stmt(self) -> Optional[Node]:
        """Parse one statement."""
        self.skip_newlines()
        tok = self.cur()

        if tok.type == TT.EOF or tok.type == TT.DEDENT:
            return None

        # fn / কাজ (function definition)
        if tok.type == TT.KW and tok.value in ('fn', 'function', 'def', 'কাজ'):
            return self.parse_fndef()

        # if / যদি
        if tok.type == TT.KW and tok.value in ('if', 'যদি'):
            return self.parse_if()

        # else / elif at top level handled by parse_if
        if tok.type == TT.KW and tok.value in ('else', 'নাহলে', 'elif', 'নাহলে_যদি'):
            return None

        # while / যতক্ষণ
        if tok.type == TT.KW and tok.value in ('while', 'যতক্ষণ'):
            return self.parse_while()

        # repeat N [stmt]
        if tok.type == TT.KW and tok.value == 'repeat':
            return self.parse_repeat()

        # for i in 1..10
        if tok.type == TT.KW and tok.value in ('for', 'প্রতিটি'):
            return self.parse_for()

        # each item in list
        if tok.type == TT.KW and tok.value == 'each':
            return self.parse_each()

        # N বার stmt (Bengali repeat: '৫ বার বলো "hi"')
        if tok.type == TT.NUMBER:
            next_tok = self.peek()
            if next_tok.type == TT.KW and next_tok.value == 'বার':
                return self.parse_bengali_repeat()

        # return / ফেরত
        if tok.type == TT.KW and tok.value in ('return', 'ফেরত'):
            return self.parse_return()

        # break / থামো
        if tok.type == TT.KW and tok.value in ('break', 'থামো'):
            self.advance()
            self.skip_newlines()
            return Break()

        # continue / চালিয়ে_যাও
        if tok.type == TT.KW and tok.value in ('continue', 'চালিয়ে_যাও'):
            self.advance()
            self.skip_newlines()
            return Continue()

        # say / show / print / বলো / দেখাও
        if tok.type == TT.KW and tok.value in ('say', 'show', 'print', 'println', 'puts', 'বলো', 'দেখাও'):
            return self.parse_say()

        # include / import / অন্তর্ভুক্ত
        if tok.type == TT.KW and tok.value in ('include', 'import', 'অন্তর্ভুক্ত'):
            return self.parse_include()

        # struct / class / গঠন
        if tok.type == TT.KW and tok.value in ('struct', 'class', 'গঠন'):
            return self.parse_struct()

        # ধরি / ধরো (Bengali variable declaration)
        if tok.type == TT.KW and tok.value in ('ধরি', 'ধরো'):
            self.advance()  # consume ধরি/ধরো
            name_tok = self.expect(TT.IDENT)
            self.expect(TT.OP, '=')
            value = self.parse_expr()
            self.skip_newlines()
            return Assign(name_tok.value, value)

        # Expression statement (assignment, function call, etc.)
        return self.parse_expr_stmt()

    def parse_expr_stmt(self) -> Node:
        """Parse expression that can be assignment, call, or standalone expr."""
        expr = self.parse_expr()

        # Assignment: IDENT = value
        if isinstance(expr, Identifier) and self.match(TT.OP, '='):
            self.advance()  # consume '='
            value = self.parse_expr()
            self.skip_newlines()
            return Assign(expr.name, value)

        # Field assignment: obj.field = value
        if isinstance(expr, FieldAccess) and self.match(TT.OP, '='):
            self.advance()
            value = self.parse_expr()
            self.skip_newlines()
            return FieldAssign(expr.obj, expr.field, value)

        # Compound assignment +=, -=, *=, /=
        for op_sym in ('+=', '-=', '*=', '/='):
            if self.match(TT.OP, op_sym) and isinstance(expr, Identifier):
                self.advance()
                rhs = self.parse_expr()
                op = op_sym[0]  # '+' from '+='
                self.skip_newlines()
                return Assign(expr.name, BinOp(op, expr, rhs))

        self.skip_newlines()
        return expr

    def parse_fndef(self) -> FnDef:
        """Parse: fn name p1 p2 = expr  OR  fn name p1 p2 \n BLOCK"""
        self.advance()  # consume fn/কাজ
        name_tok = self.expect(TT.IDENT)
        name = name_tok.value

        # Parse parameters (IDENT tokens until = or NL or INDENT)
        params = []
        while self.cur().type == TT.IDENT:
            params.append(self.advance().value)

        # Handle parenthesized params: fn greet(name, age)
        if self.match(TT.OP, '('):
            self.advance()  # (
            while not self.match(TT.OP, ')'):
                if self.cur().type == TT.IDENT:
                    params.append(self.advance().value)
                self.consume_if(TT.OP, ',')
            self.expect(TT.OP, ')')

        # One-liner: fn double n = n * 2
        if self.match(TT.OP, '='):
            self.advance()  # consume '='
            body_expr = self.parse_expr()
            self.skip_newlines()
            return FnDef(name, params, Block([Return(body_expr)]))

        # Multi-line block
        body = self.parse_inline_or_block()
        return FnDef(name, params, body)

    def parse_if(self) -> If:
        """Parse if/elif/else chain."""
        self.advance()  # consume 'if'/'যদি'
        condition = self.parse_expr()
        then_block = self.parse_inline_or_block()

        self.skip_newlines()
        else_block = None

        if self.match(TT.KW, 'elif') or self.match(TT.KW, 'নাহলে_যদি'):
            else_block = self.parse_if()  # recursive — treats elif as else: if
        elif self.match(TT.KW, 'else') or self.match(TT.KW, 'নাহলে'):
            self.advance()  # consume 'else'
            else_block = self.parse_inline_or_block()

        return If(condition, then_block, else_block)

    def parse_while(self) -> While:
        self.advance()  # consume 'while'
        condition = self.parse_expr()
        body = self.parse_inline_or_block()
        return While(condition, body)

    def parse_repeat(self) -> Repeat:
        """repeat 5 say 'hi'  OR  repeat 5 \n INDENT block"""
        self.advance()  # consume 'repeat'
        count = self.parse_primary()
        body = self.parse_inline_or_block()
        return Repeat(count, body)

    def parse_bengali_repeat(self) -> Repeat:
        """N বার stmt  (৫ বার বলো 'hi')"""
        count_tok = self.advance()  # consume number
        self.advance()  # consume 'বার'
        count = Number(count_tok.value)
        body = self.parse_inline_or_block()
        return Repeat(count, body)

    def parse_for(self) -> Node:
        """for i in 1..10  OR  for i in 1..10 step 2"""
        self.advance()  # consume 'for'
        var_tok = self.expect(TT.IDENT)
        var = var_tok.value
        self.expect(TT.KW, 'in')
        start = self.parse_add()
        self.expect(TT.OP, '..')
        end = self.parse_add()
        step = None
        if self.match(TT.KW, 'step'):
            self.advance()
            step = self.parse_primary()
        body = self.parse_inline_or_block()
        return ForRange(var, start, end, step, body)

    def parse_each(self) -> ForEach:
        """each item in mylist"""
        self.advance()  # consume 'each'
        var_tok = self.expect(TT.IDENT)
        var = var_tok.value
        self.expect(TT.KW, 'in')
        iterable = self.parse_expr()
        body = self.parse_inline_or_block()
        return ForEach(var, iterable, body)

    def parse_return(self) -> Return:
        self.advance()  # consume 'return'/'ফেরত'
        if self.cur().type in (TT.NL, TT.DEDENT, TT.EOF):
            self.skip_newlines()
            return Return(None)
        value = self.parse_expr()
        self.skip_newlines()
        return Return(value)

    def parse_say(self) -> FnCall:
        """say arg1 arg2 arg3 (space-separated, until NL)"""
        say_tok = self.advance()  # consume 'say'
        func = Identifier(say_tok.value)
        args = []
        while self.cur().type not in (TT.NL, TT.DEDENT, TT.EOF):
            args.append(self.parse_add())
        self.skip_newlines()
        return FnCall(func, args)

    def parse_include(self) -> Include:
        self.advance()  # consume 'include'
        path_tok = self.expect(TT.STRING)
        self.skip_newlines()
        return Include(path_tok.value)

    def parse_struct(self) -> StructDef:
        """struct Point \n INDENT x \n y \n DEDENT"""
        self.advance()  # consume 'struct'
        name_tok = self.expect(TT.IDENT)
        fields = []
        self.skip_newlines()
        if self.cur().type == TT.INDENT:
            self.advance()  # consume INDENT
            self.skip_newlines()
            while self.cur().type not in (TT.DEDENT, TT.EOF):
                if self.cur().type == TT.IDENT:
                    fields.append(self.advance().value)
                self.skip_newlines()
            self.consume_if(TT.DEDENT)
        return StructDef(name_tok.value, fields)

    # ── Expression parsing (operator precedence) ─────────────────────────────

    def parse_expr(self) -> Node:
        """Lowest precedence: or"""
        return self.parse_or()

    def parse_or(self) -> Node:
        left = self.parse_and()
        while self.match(TT.KW, 'or') or self.match(TT.KW, 'অথবা') or self.match(TT.OP, '||'):
            self.advance()
            right = self.parse_and()
            left = BinOp('or', left, right)
        return left

    def parse_and(self) -> Node:
        left = self.parse_not()
        while self.match(TT.KW, 'and') or self.match(TT.KW, 'এবং') or self.match(TT.OP, '&&'):
            self.advance()
            right = self.parse_not()
            left = BinOp('and', left, right)
        return left

    def parse_not(self) -> Node:
        if self.match(TT.KW, 'not') or self.match(TT.KW, 'না'):
            self.advance()
            return UnaryOp('not', self.parse_not())
        return self.parse_compare()

    def parse_compare(self) -> Node:
        left = self.parse_add()
        cmp_ops = {'==', '!=', '<', '>', '<=', '>='}
        while self.cur().type == TT.OP and self.cur().value in cmp_ops:
            op = self.advance().value
            right = self.parse_add()
            left = BinOp(op, left, right)
        return left

    def parse_add(self) -> Node:
        left = self.parse_mul()
        while self.cur().type == TT.OP and self.cur().value in ('+', '-'):
            op = self.advance().value
            right = self.parse_mul()
            left = BinOp(op, left, right)
        return left

    def parse_mul(self) -> Node:
        left = self.parse_unary()
        while self.cur().type == TT.OP and self.cur().value in ('*', '/', '%', '//', '**'):
            op = self.advance().value
            right = self.parse_unary()
            left = BinOp(op, left, right)
        return left

    def parse_unary(self) -> Node:
        if self.match(TT.OP, '-'):
            self.advance()
            return UnaryOp('-', self.parse_unary())
        if self.match(TT.OP, '~'):
            self.advance()
            return UnaryOp('~', self.parse_unary())
        return self.parse_postfix()

    def parse_postfix(self) -> Node:
        """Handle field access obj.field and explicit paren calls fn(args)."""
        expr = self.parse_primary()
        while True:
            if self.match(TT.OP, '.') and self.peek().type == TT.IDENT:
                self.advance()  # consume '.'
                field = self.advance().value
                expr = FieldAccess(expr, field)
            elif self.match(TT.OP, '('):
                # Parenthesized call: fn(a, b)
                self.advance()  # consume '('
                args = []
                while not self.match(TT.OP, ')') and self.cur().type != TT.EOF:
                    args.append(self.parse_expr())
                    self.consume_if(TT.OP, ',')
                self.expect(TT.OP, ')')
                expr = FnCall(expr, args)
            else:
                break
        return expr

    def parse_primary(self) -> Node:
        tok = self.cur()

        # Number literal
        if tok.type == TT.NUMBER:
            self.advance()
            return Number(tok.value)

        # String literal
        if tok.type == TT.STRING:
            self.advance()
            return String(tok.value)

        # Boolean literals
        if tok.type == TT.KW and tok.value in ('true', 'সত্য'):
            self.advance()
            return Bool(True)

        if tok.type == TT.KW and tok.value in ('false', 'মিথ্যা'):
            self.advance()
            return Bool(False)

        # Null literals
        if tok.type == TT.KW and tok.value in ('null', 'nil', 'শূন্য'):
            self.advance()
            return Null()

        # Grouped expression: (expr)
        if tok.type == TT.OP and tok.value == '(':
            self.advance()
            expr = self.parse_expr()
            self.expect(TT.OP, ')')
            return expr

        # Identifier (variable or space-separated function call)
        if tok.type == TT.IDENT:
            self.advance()
            ident = Identifier(tok.value)

            # Space-separated args: greet name age
            # WHY: Lipi allows 'greet "World"' syntax without parens.
            # CRITICAL: use parse_postfix (primary-level) NOT parse_add here!
            # "fibonacci a + fibonacci b" must parse as:
            #   fibonacci(a) + fibonacci(b)   ✅  (primary arg)
            # NOT:
            #   fibonacci(a + fibonacci(b))   ❌  (add-level arg)
            args = []
            while self._is_call_arg_start():
                args.append(self.parse_postfix())

            if args:
                return FnCall(ident, args)
            return ident

        # Builtin keywords usable in expression context
        if tok.type == TT.KW and tok.value in ('len', 'length', 'দৈর্ঘ্য',
                                                  'str', 'int', 'float',
                                                  'abs', 'max', 'min',
                                                  'type', 'ধরন'):
            self.advance()
            func = Identifier(tok.value)
            args = []
            while self._is_call_arg_start():
                args.append(self.parse_postfix())
            return FnCall(func, args)

        raise ParseError(f"Line {tok.line}: Unexpected token {tok.type.name}: {repr(tok.value)}")

    def _is_call_arg_start(self) -> bool:
        """Is the current token a valid start of a space-separated function call argument?
        WHY: Distinguish 'f x y' (call with 2 args) from 'f\nx' (call + next stmt).
        Stop at: NL, DEDENT, EOF, INDENT, any operator, statement keywords.
        """
        tok = self.cur()
        if tok.type in (TT.NL, TT.DEDENT, TT.EOF, TT.INDENT):
            return False
        if tok.type in (TT.NUMBER, TT.STRING):
            return True
        if tok.type == TT.IDENT:
            return True
        # WHY: '(' is NOT a space-arg start — parse_postfix handles fn(args) calls.
        # If we treat '(' as arg start here, 'Point()' would try to parse ')' as expr.
        if tok.type == TT.KW and tok.value in ('true', 'false', 'null', 'nil',
                                                   'সত্য', 'মিথ্যা', 'শূন্য'):
            return True
        # All other operators and keywords stop arg collection
        return False
