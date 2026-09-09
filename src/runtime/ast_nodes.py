from __future__ import annotations
from dataclasses import dataclass, field
from typing import Any, List, Optional

# Base node
@dataclass
class Node: pass

@dataclass
class Program(Node):
    stmts: List[Node]

@dataclass
class Number(Node):
    value: float  # Bengali or ASCII, stored as Python number

@dataclass
class String(Node):
    value: str  # raw string content

@dataclass
class Bool(Node):
    value: bool

@dataclass
class Null(Node):
    pass

@dataclass
class Identifier(Node):
    name: str

@dataclass
class BinOp(Node):
    op: str
    left: Node
    right: Node

@dataclass
class UnaryOp(Node):
    op: str
    operand: Node

@dataclass
class Assign(Node):
    name: str
    value: Node

@dataclass
class FieldAssign(Node):
    obj: Node
    field: str
    value: Node

@dataclass
class FieldAccess(Node):
    obj: Node
    field: str

@dataclass
class FnDef(Node):
    name: str
    params: List[str]
    body: Node  # Block for multi-line, any Node for one-liner

@dataclass
class FnCall(Node):
    func: Node
    args: List[Node]

@dataclass
class Return(Node):
    value: Optional[Node] = None

@dataclass
class If(Node):
    condition: Node
    then_block: Node
    else_block: Optional[Node] = None

@dataclass
class While(Node):
    condition: Node
    body: Node

@dataclass
class Repeat(Node):
    count: Node
    body: Node

@dataclass
class ForRange(Node):
    var: str
    start: Node
    end: Node
    step: Optional[Node]
    body: Node

@dataclass
class ForEach(Node):
    var: str
    iterable: Node
    body: Node

@dataclass
class Block(Node):
    stmts: List[Node]

@dataclass
class Include(Node):
    path: str

@dataclass
class StructDef(Node):
    name: str
    fields: List[str]

@dataclass
class Break(Node):
    pass

@dataclass
class Continue(Node):
    pass
