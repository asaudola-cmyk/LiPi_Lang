@! ============================================================================
@! MAYA COMPILER — 100% PURE MAYA ABSTRACT SYNTAX TREE (AST) DEFINITIONS
@! Zero External Dependencies — Full AST Node Set & Constructors
@! 100% Compatible with compiler/backend/maya_ir.maya
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"

@! ============================================================================
@! 1. SOURCE LOCATION TRACKING
@! ============================================================================

@struct SourceLocation
  line: i64
  col: i64
  file: string
@end

@fn loc_new(line: i64, col: i64, file: string) -> SourceLocation
  return {
    line: line,
    col: col,
    file: file
  }
@end

@! ============================================================================
@! 2. CANONICAL AST NODE STRUCT (22-Field Zero-Collision Schema)
@! ============================================================================

@struct ASTNode
  kind: string          @! 0
  name: string          @! 1
  params: array         @! 2
  body: array           @! 3
  ret_type: string      @! 4
  val: i64              @! 5
  op: string            @! 6
  left: ASTNode         @! 7
  right: ASTNode        @! 8
  expr: ASTNode         @! 9
  condition: ASTNode    @! 10
  then_body: array      @! 11
  elif_branches: array  @! 12
  else_body: array      @! 13
  target: string        @! 14
  value: ASTNode        @! 15
  elements: array       @! 16
  args: array           @! 17
  func: ASTNode         @! 18
  variable: string      @! 19
  iterable: ASTNode     @! 20
  index: ASTNode        @! 21
  cond: ASTNode         @! 22
@end

@struct ASTProgram
  imports: array        @! Array of string module paths
  structs: array        @! Array of ASTNode (kind: "StructDef")
  enums: array          @! Array of ASTNode (kind: "EnumDef")
  impls: array          @! Array of ASTNode (kind: "ImplBlock")
  functions: array      @! Array of ASTNode (kind: "FnDef")
  constants: array      @! Array of ASTConstant
  top_level: array      @! Array of top-level statement AST nodes
@end

@struct ASTParam
  name: string
  type_name: string
  default_val: ASTNode
@end

@struct ASTField
  name: string
  type_name: string
  default_val: ASTNode
  index: i64
@end

@struct ASTMatchArm
  pattern: ASTNode
  body: array
@end

@struct ASTElifBranch
  condition: ASTNode
  body: array
  cond: ASTNode
@end

@struct EnumVariant
  name: string
  value: i64
@end

@struct ASTConstant
  name: string
  value: i64
@end

@! ============================================================================
@! 3. DIRECT CONSTRUCTOR FUNCTIONS
@! ============================================================================

@fn ast_param(name, type_name, default_val) -> ASTParam
  return {
    name: name,
    type_name: type_name,
    default_val: default_val
  }
@end

@fn ast_field(name, type_name, default_val, index) -> ASTField
  return {
    name: name,
    type_name: type_name,
    default_val: default_val,
    index: index
  }
@end

@fn ast_constant(name: string, value: i64) -> ASTConstant
  return {
    name: name,
    value: value
  }
@end

@fn ast_match_arm(pattern, guard, body) -> ASTMatchArm
  return {
    pattern: pattern,
    body: body
  }
@end

@fn ast_enum_variant(name: string, value: i64) -> EnumVariant
  return {
    name: name,
    value: value
  }
@end

@fn ast_elif_branch(condition, body) -> ASTElifBranch
  return {
    condition: condition,
    body: body,
    cond: condition
  }
@end

@fn ast_node(kind: string) -> ASTNode
  return {
    kind: kind,
    name: "",
    params: [],
    body: [],
    ret_type: "i64",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_literal_int(val: i64) -> ASTNode
  return {
    kind: "LiteralInt",
    name: "",
    params: [],
    body: [],
    ret_type: "i64",
    val: val,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_literal_float(val: f64) -> ASTNode
  return {
    kind: "LiteralFloat",
    name: "",
    params: [],
    body: [],
    ret_type: "f64",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_literal_str(s: string) -> ASTNode
  return {
    kind: "LiteralStr",
    name: s,
    params: [],
    body: [],
    ret_type: "string",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_literal_bool(b: i64) -> ASTNode
  return {
    kind: "LiteralBool",
    name: "",
    params: [],
    body: [],
    ret_type: "bool",
    val: b,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_literal_none() -> ASTNode
  return {
    kind: "LiteralNone",
    name: "none",
    params: [],
    body: [],
    ret_type: "none",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_variable(name: string) -> ASTNode
  return {
    kind: "Variable",
    name: name,
    params: [],
    body: [],
    ret_type: "i64",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_unary_op(op: string, expr: ASTNode) -> ASTNode
  return {
    kind: "UnaryOp",
    name: "",
    params: [],
    body: [],
    ret_type: "i64",
    val: 0,
    op: op,
    left: 0,
    right: 0,
    expr: expr,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_binary_op(left: ASTNode, op: string, right: ASTNode) -> ASTNode
  return {
    kind: "BinaryOp",
    name: "",
    params: [],
    body: [],
    ret_type: "i64",
    val: 0,
    op: op,
    left: left,
    right: right,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_pipeline(left: ASTNode, right: ASTNode) -> ASTNode
  return {
    kind: "Pipeline",
    name: "",
    params: [],
    body: [],
    ret_type: "i64",
    val: 0,
    op: "|>",
    left: left,
    right: right,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_call(func_expr: ASTNode, args: array) -> ASTNode
  fn_name = ""
  @if func_expr != 0 && func_expr.kind == "Variable"
    fn_name = func_expr.name
  @end
  return {
    kind: "Call",
    name: fn_name,
    params: [],
    body: [],
    ret_type: "i64",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: args,
    func: func_expr,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_member_access(target: ASTNode, field_name: string) -> ASTNode
  return {
    kind: "MemberAccess",
    name: field_name,
    params: [],
    body: [],
    ret_type: "i64",
    val: 0,
    op: "",
    left: target,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_index(target: ASTNode, index_expr: ASTNode) -> ASTNode
  return {
    kind: "Index",
    name: "",
    params: [],
    body: [],
    ret_type: "i64",
    val: 0,
    op: "",
    left: target,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: index_expr,
    cond: 0
  }
@end

@fn ast_array_lit(elements: array) -> ASTNode
  return {
    kind: "ArrayLit",
    name: "",
    params: [],
    body: [],
    ret_type: "array",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: elements,
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_map_lit(entries: array) -> ASTNode
  return {
    kind: "MapLit",
    name: "",
    params: [],
    body: [],
    ret_type: "map",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: entries,
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_closure(params: array, body: array) -> ASTNode
  return {
    kind: "Closure",
    name: "",
    params: params,
    body: body,
    ret_type: "i64",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_fn_def(name: string, params: array, ret_type: string, body: array) -> ASTNode
  return {
    kind: "FnDef",
    name: name,
    params: params,
    body: body,
    ret_type: ret_type,
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_struct_def(name: string, fields: array) -> ASTNode
  return {
    kind: "StructDef",
    name: name,
    params: fields,
    body: [],
    ret_type: "i64",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_enum_def(name: string, variants: array) -> ASTNode
  return {
    kind: "EnumDef",
    name: name,
    params: [],
    body: [],
    ret_type: "i64",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: variants,
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_impl_block(trait_name: string, target_type: string, methods: array) -> ASTNode
  return {
    kind: "ImplBlock",
    name: target_type,
    params: [],
    body: methods,
    ret_type: trait_name,
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_if_stmt(cond: ASTNode, then_body: array, elif_branches: array, else_body: array) -> ASTNode
  return {
    kind: "IfStmt",
    name: "",
    params: [],
    body: [],
    ret_type: "void",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: cond,
    then_body: then_body,
    elif_branches: elif_branches,
    else_body: else_body,
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: cond
  }
@end

@fn ast_while_loop(cond: ASTNode, body: array) -> ASTNode
  return {
    kind: "WhileLoop",
    name: "",
    params: [],
    body: body,
    ret_type: "void",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: cond,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: cond
  }
@end

@fn ast_for_loop(variable: string, iterable: ASTNode, body: array) -> ASTNode
  return {
    kind: "ForLoop",
    name: "",
    params: [],
    body: body,
    ret_type: "void",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: variable,
    iterable: iterable,
    index: 0,
    cond: 0
  }
@end

@fn ast_assign(target: string, value: ASTNode) -> ASTNode
  return {
    kind: "Assign",
    name: "",
    params: [],
    body: [],
    ret_type: "void",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: target,
    value: value,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_assign_op(target: string, value: ASTNode, op: string) -> ASTNode
  return {
    kind: "AssignOp",
    name: "",
    params: [],
    body: [],
    ret_type: "void",
    val: 0,
    op: op,
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: target,
    value: value,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_return(value: ASTNode) -> ASTNode
  return {
    kind: "Return",
    name: "",
    params: [],
    body: [],
    ret_type: "void",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: value,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_break() -> ASTNode
  return ast_node("Break")
@end

@fn ast_continue() -> ASTNode
  return ast_node("Continue")
@end

@fn ast_defer(stmt: ASTNode) -> ASTNode
  return {
    kind: "Defer",
    name: "",
    params: [],
    body: [stmt],
    ret_type: "void",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_try_catch(try_body: array, err_var: string, catch_body: array) -> ASTNode
  return {
    kind: "TryCatch",
    name: "",
    params: [],
    body: [],
    ret_type: "void",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: try_body,
    elif_branches: [],
    else_body: catch_body,
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: err_var,
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_match_stmt(target: ASTNode, arms: array) -> ASTNode
  return {
    kind: "MatchStmt",
    name: "",
    params: [],
    body: [],
    ret_type: "void",
    val: 0,
    op: "",
    left: target,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: arms,
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_match_expr(target: ASTNode, arms: array) -> ASTNode
  return {
    kind: "MatchExpr",
    name: "",
    params: [],
    body: [],
    ret_type: "i64",
    val: 0,
    op: "",
    left: target,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: arms,
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_import(path: string) -> ASTNode
  return {
    kind: "Import",
    name: path,
    params: [],
    body: [],
    ret_type: "void",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_expression_stmt(expr: ASTNode) -> ASTNode
  return {
    kind: "ExpressionStmt",
    name: "",
    params: [],
    body: [],
    ret_type: "void",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: expr,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_program_new() -> ASTProgram
  return {
    imports: [],
    structs: [],
    enums: [],
    impls: [],
    functions: [],
    constants: [],
    top_level: []
  }
@end

@! ============================================================================
@! 4. TYPED AST GETTER FUNCTIONS
@! ============================================================================

@fn ast_get_kind(node: ASTNode) -> string
  @if node == 0 return "" @end
  return node.kind
@end

@fn ast_get_name(node: ASTNode) -> string
  @if node == 0 return "" @end
  return node.name
@end

@fn ast_get_op(node: ASTNode) -> string
  @if node == 0 return "" @end
  return node.op
@end

@fn ast_get_val(node: ASTNode) -> i64
  @if node == 0 return 0 @end
  return node.val
@end

@fn ast_get_ret_type(node: ASTNode) -> string
  @if node == 0 return "" @end
  return node.ret_type
@end

@fn ast_get_target(node: ASTNode) -> string
  @if node == 0 return "" @end
  return node.target
@end

@fn ast_get_left(node: ASTNode) -> ASTNode
  return node.left
@end

@fn ast_get_right(node: ASTNode) -> ASTNode
  return node.right
@end

@fn ast_get_expr(node: ASTNode) -> ASTNode
  return node.expr
@end

@fn ast_get_condition(node: ASTNode) -> ASTNode
  return node.condition
@end

@fn ast_get_value(node: ASTNode) -> ASTNode
  return node.value
@end

@fn ast_get_params(node: ASTNode) -> array
  return node.params
@end

@fn ast_get_body(node: ASTNode) -> array
  return node.body
@end

@fn ast_get_then_body(node: ASTNode) -> array
  return node.then_body
@end

@fn ast_get_else_body(node: ASTNode) -> array
  return node.else_body
@end

@fn ast_get_elif_branches(node: ASTNode) -> array
  return node.elif_branches
@end

@fn ast_get_elements(node: ASTNode) -> array
  return node.elements
@end

@fn ast_get_args(node: ASTNode) -> array
  return node.args
@end

@fn ast_param_get_name(param: ASTParam) -> string
  return param.name
@end

@fn ast_param_get_type(param: ASTParam) -> string
  return param.type_name
@end

@fn ast_field_get_name(field: ASTField) -> string
  return field.name
@end

@fn ast_field_get_type(field: ASTField) -> string
  return field.type_name
@end

@fn ast_const_get_name(c: ASTConstant) -> string
  return c.name
@end

@fn ast_const_get_value(c: ASTConstant) -> i64
  return c.value
@end

@fn ast_get_func(node: ASTNode) -> ASTNode
  return node.func
@end

@fn ast_get_cond(node: ASTNode) -> ASTNode
  return node.cond
@end

@fn ast_get_variable(node: ASTNode) -> string
  return node.variable
@end

@fn ast_get_iterable(node: ASTNode) -> ASTNode
  return node.iterable
@end

@fn ast_get_index(node: ASTNode) -> ASTNode
  return node.index
@end

@fn ast_elif_get_condition(branch: ASTElifBranch) -> ASTNode
  return branch.condition
@end

@fn ast_elif_get_cond(branch: ASTElifBranch) -> ASTNode
  return branch.cond
@end

@fn ast_elif_get_body(branch: ASTElifBranch) -> array
  return branch.body
@end

@fn ast_match_arm_get_pattern(arm: ASTMatchArm) -> ASTNode
  return arm.pattern
@end

@fn ast_match_arm_get_body(arm: ASTMatchArm) -> array
  return arm.body
@end

@fn ast_variant_get_name(v: EnumVariant) -> string
  return v.name
@end

@fn ast_variant_get_value(v: EnumVariant) -> i64
  return v.value
@end
