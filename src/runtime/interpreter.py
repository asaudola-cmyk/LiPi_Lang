from __future__ import annotations
from typing import Any, Dict, Optional, List
import re
from .ast_nodes import (
    Program, Block, Number, String, Bool, Null, Identifier,
    BinOp, UnaryOp, Assign, FieldAssign, FieldAccess,
    FnDef, FnCall, Return, If, While, Repeat, ForRange, ForEach,
    Include, StructDef, Break, Continue, Node
)


class LipiError(Exception):
    pass


class ReturnException(Exception):
    def __init__(self, value):
        self.value = value


class BreakException(Exception):
    pass


class ContinueException(Exception):
    pass


class Environment:
    def __init__(self, parent: Optional['Environment'] = None):
        self.vars: Dict[str, Any] = {}
        self.parent = parent

    def get(self, name: str) -> Any:
        if name in self.vars:
            return self.vars[name]
        if self.parent:
            return self.parent.get(name)
        raise NameError(f"Variable '{name}' is not defined")

    def set(self, name: str, value: Any):
        """Create/update variable in current scope."""
        self.vars[name] = value

    def assign(self, name: str, value: Any):
        """Update existing variable (walks up scope chain) or create in current scope.
        WHY: So inner functions can read outer vars, and assignment updates the right scope.
        """
        if name in self.vars:
            self.vars[name] = value
        elif self.parent and self.parent.has(name):
            self.parent.assign(name, value)
        else:
            self.vars[name] = value  # create new in current scope

    def has(self, name: str) -> bool:
        if name in self.vars:
            return True
        if self.parent:
            return self.parent.has(name)
        return False


class LipiFunction:
    def __init__(self, name: str, params: List[str], body, closure: Environment):
        self.name = name
        self.params = params
        self.body = body
        self.closure = closure  # WHY: capture lexical scope for closures

    def call(self, args: List[Any], interpreter: 'Interpreter') -> Any:
        if len(args) != len(self.params):
            raise LipiError(
                f"Function '{self.name}' expects {len(self.params)} args, got {len(args)}"
            )
        # WHY: New env with closure as parent — each call gets fresh local scope
        env = Environment(parent=self.closure)
        for param, arg in zip(self.params, args):
            env.set(param, arg)
        try:
            interpreter.exec_block(self.body, env)
        except ReturnException as ret:
            return ret.value
        return None

    def __repr__(self):
        return f"<fn {self.name}({', '.join(self.params)})>"


class LipiStructType:
    def __init__(self, name: str, fields: List[str]):
        self.name = name
        self.fields = fields

    def instantiate(self) -> 'LipiStruct':
        return LipiStruct(self.name, {f: None for f in self.fields})

    def __repr__(self):
        return f"<struct {self.name}>"


class LipiStruct:
    def __init__(self, name: str, fields: Dict[str, Any]):
        self.name = name
        self.fields = fields

    def __repr__(self):
        parts = ', '.join(f'{k}={v!r}' for k, v in self.fields.items())
        return f"{self.name}({parts})"


class Interpreter:
    def __init__(self, filename: str = '<input>'):
        self.filename = filename
        self.global_env = Environment()
        self._load_stdlib()

    def _load_stdlib(self):
        """Register built-in functions in global scope."""
        env = self.global_env

        def lipi_say(*args):
            print(' '.join(self.lipi_str(a) for a in args))

        def lipi_input(prompt=''):
            return input(prompt)

        def lipi_len(x):
            if isinstance(x, (str, list)):
                return len(x)
            if isinstance(x, LipiStruct):
                return len(x.fields)
            raise LipiError(f"len() not supported for {self.lipi_type(x)}")

        def lipi_range(*args):
            return list(range(*args))

        builtins = {
            # Output
            'say': lipi_say, 'show': lipi_say, 'print': lipi_say,
            'println': lipi_say, 'puts': lipi_say, 'echo': lipi_say,
            'বলো': lipi_say, 'দেখাও': lipi_say,
            # Input
            'input': lipi_input, 'read': lipi_input,
            # Type conversions
            'str': lambda x: self.lipi_str(x),
            'int': lambda x: int(float(x)) if isinstance(x, str) else int(x),
            'float': lambda x: float(x),
            # Collections
            'len': lipi_len, 'length': lipi_len, 'দৈর্ঘ্য': lipi_len,
            'range': lipi_range,
            'list': lambda *args: list(args),
            'append': lambda lst, item: lst.append(item) or lst,
            # Math
            'abs': abs,
            'max': lambda *args: max(args) if len(args) > 1 else max(args[0]),
            'min': lambda *args: min(args) if len(args) > 1 else min(args[0]),
            'pow': pow,
            # Type query
            'type': lambda x: self.lipi_type(x),
            'ধরন': lambda x: self.lipi_type(x),
        }
        for name, fn in builtins.items():
            env.set(name, fn)

    def run(self, program: Program):
        """Execute top-level program."""
        self.exec_block(program, self.global_env)

    def exec_block(self, node, env: Environment):
        """Execute a block or program node."""
        if isinstance(node, (Program, Block)):
            for stmt in node.stmts:
                self.exec(stmt, env)
        else:
            self.exec(node, env)

    def exec(self, node, env: Environment):
        """Execute one statement node."""
        if node is None:
            return

        if isinstance(node, Assign):
            val = self.eval(node.value, env)
            env.assign(node.name, val)

        elif isinstance(node, FieldAssign):
            obj = self.eval(node.obj, env)
            if not isinstance(obj, LipiStruct):
                raise LipiError(f"Cannot set field on {self.lipi_type(obj)}")
            obj.fields[node.field] = self.eval(node.value, env)

        elif isinstance(node, FnDef):
            fn = LipiFunction(node.name, node.params, node.body, env)
            env.assign(node.name, fn)

        elif isinstance(node, StructDef):
            st = LipiStructType(node.name, node.fields)
            env.assign(node.name, st)

        elif isinstance(node, If):
            cond = self.eval(node.condition, env)
            if self.is_truthy(cond):
                self.exec_block(node.then_block, env)
            elif node.else_block:
                self.exec_block(node.else_block, env)

        elif isinstance(node, While):
            while self.is_truthy(self.eval(node.condition, env)):
                try:
                    self.exec_block(node.body, env)
                except BreakException:
                    break
                except ContinueException:
                    continue

        elif isinstance(node, Repeat):
            n = int(self.eval(node.count, env))
            for _ in range(n):
                try:
                    self.exec_block(node.body, env)
                except BreakException:
                    break
                except ContinueException:
                    continue

        elif isinstance(node, ForRange):
            start = int(self.eval(node.start, env))
            end = int(self.eval(node.end, env))
            step = int(self.eval(node.step, env)) if node.step else 1
            for i in range(start, end + 1, step):
                loop_env = Environment(parent=env)
                loop_env.set(node.var, i)
                try:
                    self.exec_block(node.body, loop_env)
                except BreakException:
                    break
                except ContinueException:
                    continue

        elif isinstance(node, ForEach):
            iterable = self.eval(node.iterable, env)
            if not hasattr(iterable, '__iter__'):
                raise LipiError(f"'{self.lipi_type(iterable)}' is not iterable")
            for item in iterable:
                loop_env = Environment(parent=env)
                loop_env.set(node.var, item)
                try:
                    self.exec_block(node.body, loop_env)
                except BreakException:
                    break
                except ContinueException:
                    continue

        elif isinstance(node, Return):
            val = self.eval(node.value, env) if node.value else None
            raise ReturnException(val)

        elif isinstance(node, Break):
            raise BreakException()

        elif isinstance(node, Continue):
            raise ContinueException()

        elif isinstance(node, Include):
            self._exec_include(node.path, env)

        else:
            # Expression statements (FnCall, standalone expr, etc.)
            self.eval(node, env)

    def eval(self, node, env: Environment) -> Any:
        """Evaluate expression → Python value."""
        if isinstance(node, Number):
            return node.value

        if isinstance(node, String):
            return self._interp_string(node.value, env)

        if isinstance(node, Bool):
            return node.value

        if isinstance(node, Null):
            return None

        if isinstance(node, Identifier):
            return env.get(node.name)

        if isinstance(node, BinOp):
            return self._eval_binop(node, env)

        if isinstance(node, UnaryOp):
            val = self.eval(node.operand, env)
            if node.op == '-':
                return -val
            if node.op == 'not':
                return not self.is_truthy(val)
            if node.op == '~':
                return ~int(val)

        if isinstance(node, FieldAccess):
            obj = self.eval(node.obj, env)
            if isinstance(obj, LipiStruct):
                if node.field not in obj.fields:
                    raise LipiError(f"Struct '{obj.name}' has no field '{node.field}'")
                return obj.fields[node.field]
            raise LipiError(f"Cannot access field '{node.field}' on {self.lipi_type(obj)}")

        if isinstance(node, FnCall):
            func = self.eval(node.func, env)
            args = [self.eval(a, env) for a in node.args]
            return self._call_function(func, args, node)

        if isinstance(node, Block):
            # Block as expression: last statement is return value
            result = None
            for stmt in node.stmts:
                result = self.eval(stmt, env)
            return result

        if isinstance(node, (Assign, FieldAssign, FnDef, StructDef,
                              If, While, Repeat, ForRange, ForEach,
                              Return, Break, Continue, Include)):
            # Statement nodes evaluated for side-effects
            self.exec(node, env)
            return None

        raise LipiError(f"Cannot evaluate node: {type(node).__name__}")

    def _eval_binop(self, node: BinOp, env: Environment) -> Any:
        op = node.op

        # Short-circuit for and/or
        if op == 'and':
            left = self.eval(node.left, env)
            if not self.is_truthy(left):
                return left
            return self.eval(node.right, env)

        if op == 'or':
            left = self.eval(node.left, env)
            if self.is_truthy(left):
                return left
            return self.eval(node.right, env)

        left = self.eval(node.left, env)
        right = self.eval(node.right, env)

        if op == '+':
            if isinstance(left, str) or isinstance(right, str):
                return self.lipi_str(left) + self.lipi_str(right)
            return left + right
        if op == '-':
            return left - right
        if op == '*':
            return left * right
        if op == '/':
            if right == 0:
                raise LipiError("Division by zero")
            result = left / right
            # WHY: Return int when result is whole number, for clean display
            return int(result) if isinstance(result, float) and result == int(result) else result
        if op == '%':
            if right == 0:
                raise LipiError("Modulo by zero")
            return left % right
        if op == '//':
            return left // right
        if op == '**':
            return left ** right
        if op == '==':
            return left == right
        if op == '!=':
            return left != right
        if op == '<':
            return left < right
        if op == '>':
            return left > right
        if op == '<=':
            return left <= right
        if op == '>=':
            return left >= right
        if op == '&':
            return int(left) & int(right)
        if op == '|':
            return int(left) | int(right)
        if op == '^':
            return int(left) ^ int(right)
        if op == '<<':
            return int(left) << int(right)
        if op == '>>':
            return int(left) >> int(right)

        raise LipiError(f"Unknown operator: {op}")

    def _call_function(self, func, args: list, node=None) -> Any:
        if callable(func):  # Python builtin/lambda
            return func(*args)
        if isinstance(func, LipiFunction):
            return func.call(args, self)
        if isinstance(func, LipiStructType):
            # Struct constructor call: Point()
            return func.instantiate()
        raise LipiError(f"'{self.lipi_type(func)}' is not callable")

    def _interp_string(self, raw: str, env: Environment) -> str:
        """Handle {expr} interpolation inside strings.
        WHY: 'Hello {name}!' → 'Hello World!' — enables template strings.
        """
        def replace_expr(m):
            expr_src = m.group(1).strip()
            try:
                from .lexer import Lexer
                from .parser import Parser
                tokens = Lexer(expr_src + '\n', '<interp>').tokenize()
                ast_node = Parser(tokens).parse_expr()
                return self.lipi_str(self.eval(ast_node, env))
            except Exception:
                return m.group(0)  # leave as-is if parse fails

        return re.sub(r'\{([^}]+)\}', replace_expr, raw)

    def _exec_include(self, path: str, env: Environment):
        """Execute an included .lp file."""
        import os
        search_paths = ['.', os.path.dirname(self.filename) or '.']
        for base in search_paths:
            full = os.path.join(base, path)
            if not full.endswith('.lp'):
                full += '.lp'
            if os.path.exists(full):
                from .lexer import Lexer
                from .parser import Parser
                with open(full, 'r', encoding='utf-8') as f:
                    src = f.read()
                tokens = Lexer(src, full).tokenize()
                prog = Parser(tokens).parse()
                self.exec_block(prog, env)
                return
        raise LipiError(f"Cannot find included file: {path}")

    def lipi_str(self, value: Any) -> str:
        """Convert Python value to Lipi display string."""
        if value is None:
            return "null"
        if isinstance(value, bool):
            return "true" if value else "false"
        if isinstance(value, float):
            return str(int(value)) if value == int(value) else str(value)
        if isinstance(value, int):
            return str(value)
        if isinstance(value, str):
            return value
        if isinstance(value, list):
            return '[' + ', '.join(self.lipi_str(i) for i in value) + ']'
        if isinstance(value, (LipiFunction, LipiStructType, LipiStruct)):
            return repr(value)
        return str(value)

    def lipi_type(self, value: Any) -> str:
        """Return Lipi type name for a Python value."""
        if value is None:
            return 'null'
        if isinstance(value, bool):
            return 'boolean'
        if isinstance(value, (int, float)):
            return 'number'
        if isinstance(value, str):
            return 'string'
        if isinstance(value, list):
            return 'list'
        if isinstance(value, LipiFunction):
            return 'function'
        if isinstance(value, LipiStructType):
            return 'struct_type'
        if isinstance(value, LipiStruct):
            return value.name
        return 'unknown'

    def is_truthy(self, value: Any) -> bool:
        """Lipi truthiness: None, 0, False, '' are falsy. Everything else truthy."""
        if value is None:
            return False
        if isinstance(value, bool):
            return value
        if isinstance(value, (int, float)):
            return value != 0
        if isinstance(value, str):
            return len(value) > 0
        if isinstance(value, list):
            return len(value) > 0
        return True
