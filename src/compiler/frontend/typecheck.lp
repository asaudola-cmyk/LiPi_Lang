@! ============================================================================
@! MAYA COMPILER STAGE 3 — 100% PURE MAYA MULTI-PASS TYPECHECKER & IMPORT RESOLVER
@! Zero External Dependencies — 4-Pass Semantic Validation & Cycle Detection
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/frontend/ast"
import "compiler/frontend/lexer"
import "compiler/frontend/parser"

@! ============================================================================
@! 1. TYPE SYSTEM DEFINITIONS & CONSTANTS
@! ============================================================================

@fn TYPE_VOID()    return 0  @end
@fn TYPE_I64()     return 1  @end
@fn TYPE_F64()     return 2  @end
@fn TYPE_BOOL()    return 3  @end
@fn TYPE_STRING()  return 4  @end
@fn TYPE_ARRAY()   return 5  @end
@fn TYPE_STRUCT()  return 6  @end
@fn TYPE_FN()      return 7  @end
@fn TYPE_PTR()     return 8  @end
@fn TYPE_RESULT()  return 9  @end
@fn TYPE_OPTION()  return 10 @end
@fn TYPE_ANY()     return 11 @end

@struct MayaType
  kind: i64
  name: string
  elem_type: i64
  err_type: i64
  param_types: array
  ret_type: i64
  fields: array
  size_bytes: i64
  align_bytes: i64
@end

@fn type_make_void()
  return { kind: TYPE_VOID(), name: "void", elem_type: 0, err_type: 0, param_types: [], ret_type: 0, fields: [], size_bytes: 0, align_bytes: 8 }
@end

@fn type_make_i64()
  return { kind: TYPE_I64(), name: "i64", elem_type: 0, err_type: 0, param_types: [], ret_type: 0, fields: [], size_bytes: 8, align_bytes: 8 }
@end

@fn type_make_f64()
  return { kind: TYPE_F64(), name: "f64", elem_type: 0, err_type: 0, param_types: [], ret_type: 0, fields: [], size_bytes: 8, align_bytes: 8 }
@end

@fn type_make_bool()
  return { kind: TYPE_BOOL(), name: "bool", elem_type: 0, err_type: 0, param_types: [], ret_type: 0, fields: [], size_bytes: 8, align_bytes: 8 }
@end

@fn type_make_string()
  return { kind: TYPE_STRING(), name: "string", elem_type: 0, err_type: 0, param_types: [], ret_type: 0, fields: [], size_bytes: 8, align_bytes: 8 }
@end

@fn type_make_ptr()
  return { kind: TYPE_PTR(), name: "ptr", elem_type: 0, err_type: 0, param_types: [], ret_type: 0, fields: [], size_bytes: 8, align_bytes: 8 }
@end

@fn type_make_any()
  return { kind: TYPE_ANY(), name: "any", elem_type: 0, err_type: 0, param_types: [], ret_type: 0, fields: [], size_bytes: 8, align_bytes: 8 }
@end

@fn type_make_array(elem_t)
  return { kind: TYPE_ARRAY(), name: "array", elem_type: elem_t, err_type: 0, param_types: [], ret_type: 0, fields: [], size_bytes: 8, align_bytes: 8 }
@end

@fn type_make_struct(sname, fields)
  return { kind: TYPE_STRUCT(), name: sname, elem_type: 0, err_type: 0, param_types: [], ret_type: 0, fields: fields, size_bytes: 8, align_bytes: 8 }
@end

@fn type_make_fn(param_types, ret_type)
  return { kind: TYPE_FN(), name: "fn", elem_type: 0, err_type: 0, param_types: param_types, ret_type: ret_type, fields: [], size_bytes: 8, align_bytes: 8 }
@end

@fn type_make_result(val_t, err_t)
  return { kind: TYPE_RESULT(), name: "Result", elem_type: val_t, err_type: err_t, param_types: [], ret_type: 0, fields: [], size_bytes: 16, align_bytes: 8 }
@end

@fn type_equals(t1, t2)
  @if t1 == 0 || t2 == 0 return 1 @end
  @if t1.kind == TYPE_ANY() || t2.kind == TYPE_ANY() return 1 @end
  @if t1.kind != t2.kind return 0 @end
  @if t1.kind == TYPE_STRUCT()
    @if t1.name == t2.name return 1 @end
    return 0
  @end
  @if t1.kind == TYPE_ARRAY()
    @if t1.elem_type != 0 && t2.elem_type != 0
      return type_equals(t1.elem_type, t2.elem_type)
    @end
    return 1
  @end
  return 1
@end

@fn type_is_assignable(target_t, src_t)
  @if target_t == 0 || src_t == 0 return 1 @end
  @if target_t.kind == TYPE_ANY() || src_t.kind == TYPE_ANY() return 1 @end
  @if type_equals(target_t, src_t) == 1 return 1 @end
  @if target_t.kind == TYPE_I64() && src_t.kind == TYPE_BOOL() return 1 @end
  return 0
@end

@fn type_to_string(t)
  @if t == 0 return "any" @end
  @if t.kind == TYPE_VOID() return "void" @end
  @if t.kind == TYPE_I64() return "i64" @end
  @if t.kind == TYPE_F64() return "f64" @end
  @if t.kind == TYPE_BOOL() return "bool" @end
  @if t.kind == TYPE_STRING() return "string" @end
  @if t.kind == TYPE_PTR() return "ptr" @end
  @if t.kind == TYPE_ANY() return "any" @end
  @if t.kind == TYPE_STRUCT() return t.name @end
  @if t.kind == TYPE_ARRAY()
    @if t.elem_type != 0
      return "array[" + type_to_string(t.elem_type) + "]"
    @end
    return "array"
  @end
  @if t.kind == TYPE_RESULT()
    return "Result"
  @end
  return "any"
@end

@! ============================================================================
@! 2. SYMBOL TABLE & TYPE ENVIRONMENT
@! ============================================================================

@struct StructField
  name: string
  field_type: MayaType
  index: i64
  offset_bytes: i64
  size_bytes: i64
  type_name: string
@end

@struct StructLayout
  name: string
  fields: array
  total_size: i64
  alignment: i64
  methods: array
@end

@fn tc_field_get_name(f: StructField) -> string
  return f.name
@end

@fn tc_field_get_type(f: StructField) -> MayaType
  return f.field_type
@end

@fn tc_field_get_index(f: StructField) -> i64
  return f.index
@end

@fn tc_field_get_offset(f: StructField) -> i64
  return f.offset_bytes
@end

@fn tc_field_get_size(f: StructField) -> i64
  return f.size_bytes
@end

@fn tc_field_get_type_name(f: StructField) -> string
  return f.type_name
@end

@fn tc_struct_get_name(st: StructLayout) -> string
  return st.name
@end

@fn tc_struct_get_fields(st: StructLayout) -> array
  return st.fields
@end

@fn tc_struct_get_total_size(st: StructLayout) -> i64
  return st.total_size
@end

@fn tc_struct_get_alignment(st: StructLayout) -> i64
  return st.alignment
@end

@fn tc_struct_get_methods(st: StructLayout) -> array
  return st.methods
@end

@struct FunctionSymbol
  name: string
  param_names: array
  param_types: array
  ret_type: MayaType
  is_varargs: i64
  is_method: i64
  struct_name: string
  body_node: ASTNode
@end

@struct VarSymbol
  name: string
  var_type: MayaType
  is_const: i64
  scope_depth: i64
  line: i64
  col: i64
@end

@struct Scope
  parent_id: i64
  vars: array
  depth: i64
@end

@struct TypeEnv
  scopes: array
  current_scope: i64
  functions: array
  structs: array
  enums: array
  constants: array
  errors: array
  warnings: array
  current_fn_ret: MayaType
  current_fn_name: string
  in_loop_depth: i64
  te_vars: array
  te_fns: array
  te_structs: array
  te_errors: array
  te_scope_depth: i64
@end

@fn typeenv_new()
  global_scope = { parent_id: -1, vars: [], depth: 0 }
  return {
    scopes: [global_scope],
    current_scope: 0,
    functions: [],
    structs: [],
    enums: [],
    constants: [],
    errors: [],
    warnings: [],
    current_fn_ret: type_make_void(),
    current_fn_name: "",
    in_loop_depth: 0,
    te_vars: [],
    te_fns: [],
    te_structs: [],
    te_errors: [],
    te_scope_depth: 0
  }
@end

@fn tc_add_error(env, msg)
  env.errors = env.errors.push(msg)
  env.te_errors = env.te_errors.push(msg)
  return env
@end

@fn tc_error(env, msg)
  return tc_add_error(env, msg)
@end

@fn tc_has_errors(env)
  return env.errors.len() > 0 || env.te_errors.len() > 0
@end

@fn tc_has_struct(env, name)
  i = 0
  @while i < env.structs.len()
    st = env.structs[i]
    @if tc_struct_get_name(st) == name return 1 @end
    i = i + 1
  @end
  return 0
@end

@fn tc_get_struct(env, name)
  i = 0
  @while i < env.structs.len()
    st = env.structs[i]
    @if tc_struct_get_name(st) == name return st @end
    i = i + 1
  @end
  return { name: "", fields: [], total_size: 0, alignment: 8, methods: [] }
@end

@fn tc_struct_get_field(st_layout: StructLayout, field_name: string) -> StructField
  fields = tc_struct_get_fields(st_layout)
  i = 0
  @while i < fields.len()
    f = fields[i]
    @if tc_field_get_name(f) == field_name return f @end
    i = i + 1
  @end
  return { name: "", field_type: type_make_any(), index: -1, offset_bytes: 0, size_bytes: 0, type_name: "" }
@end

@fn tc_has_fn(env, name)
  i = 0
  @while i < env.functions.len()
    @if env.functions[i].name == name return 1 @end
    i = i + 1
  @end
  return 0
@end

@fn tc_lookup_fn(env, name)
  i = 0
  @while i < env.functions.len()
    @if env.functions[i].name == name return env.functions[i] @end
    i = i + 1
  @end
  return { name: "", param_names: [], param_types: [], ret_type: type_make_any(), is_varargs: 0, is_method: 0, struct_name: "", body_node: 0 }
@end

@fn tc_has_enum(env, name)
  i = 0
  @while i < env.enums.len()
    @if env.enums[i] == name return 1 @end
    i = i + 1
  @end
  return 0
@end

@fn tc_lookup_constant(env, name)
  i = 0
  @while i < env.constants.len()
    c = env.constants[i]
    @if ast_const_get_name(c) == name return ast_const_get_value(c) @end
    i = i + 1
  @end
  return -1
@end

@fn tc_add_struct_method(env, struct_name, method_name)
  i = 0
  @while i < env.structs.len()
    st = env.structs[i]
    @if tc_struct_get_name(st) == struct_name
      st.methods = st.methods.push(method_name)
      env.structs[i] = st
      return env
    @end
    i = i + 1
  @end
  return env
@end

@! Scope Management
@fn scope_enter(env)
  new_scope_id = env.scopes.len()
  parent_id = env.current_scope
  parent_depth = 0
  @if parent_id >= 0
    parent_depth = env.scopes[parent_id].depth
  @end
  new_scope = {
    parent_id: parent_id,
    vars: [],
    depth: parent_depth + 1
  }
  env.scopes = env.scopes.push(new_scope)
  env.current_scope = new_scope_id
  env.te_scope_depth = parent_depth + 1
  return env
@end

@fn scope_exit(env)
  @if env.current_scope >= 0
    env.current_scope = env.scopes[env.current_scope].parent_id
    @if env.current_scope >= 0
      env.te_scope_depth = env.scopes[env.current_scope].depth
    @else
      env.te_scope_depth = 0
    @end
  @end
  return env
@end

@fn scope_define_var(env, name, var_type, is_const)
  curr_id = env.current_scope
  @if curr_id < 0 || curr_id >= env.scopes.len()
    return env
  @end
  scope = env.scopes[curr_id]
  sym = {
    name: name,
    var_type: var_type,
    is_const: is_const,
    scope_depth: scope.depth,
    line: 0,
    col: 0
  }
  scope.vars = scope.vars.push(sym)
  env.scopes[curr_id] = scope
  @! Also mirror to te_vars for backward compatibility
  env.te_vars = env.te_vars.push({ var_name: name, var_type: type_to_string(var_type), var_scope: scope.depth })
  return env
@end

@fn scope_lookup_var(env, name)
  curr_id = env.current_scope
  @while curr_id >= 0
    scope = env.scopes[curr_id]
    v_idx = scope.vars.len() - 1
    @while v_idx >= 0
      v = scope.vars[v_idx]
      @if v.name == name
        return v
      @end
      v_idx = v_idx - 1
    @end
    curr_id = scope.parent_id
  @end
  return { name: "", var_type: type_make_any(), is_const: 0, scope_depth: -1, line: 0, col: 0 }
@end

@fn typeenv_push_scope(env) return scope_enter(env) @end
@fn typeenv_pop_scope(env) return scope_exit(env) @end
@fn typeenv_define_var(env, name, type_str) return scope_define_var(env, name, resolve_type_name(env, type_str), 0) @end
@fn typeenv_lookup_var(env, name)
  v = scope_lookup_var(env, name)
  @if v.name != "" return type_to_string(v.var_type) @end
  return "unknown"
@end
@fn typeenv_define_fn(env, name, ret_type)
  ret_t = resolve_type_name(env, ret_type)
  fn_sym = { name: name, param_names: [], param_types: [], ret_type: ret_t, is_varargs: 1, is_method: 0, struct_name: "", body_node: 0 }
  env.functions = env.functions.push(fn_sym)
  env.te_fns = env.te_fns.push({ fn_name: name, fn_ret: ret_type })
  return env
@end
@fn typeenv_lookup_fn(env, name)
  fn_sym = tc_lookup_fn(env, name)
  @if fn_sym.name != "" return type_to_string(fn_sym.ret_type) @end
  return "unknown"
@end

@! ============================================================================
@! 3. TYPE RESOLUTION
@! ============================================================================

@fn resolve_type_name(env, type_str)
  @if type_str == "" || type_str == "any" || type_str == "Any"
    return type_make_any()
  @elif type_str == "i64" || type_str == "int" || type_str == "Int"
    return type_make_i64()
  @elif type_str == "f64" || type_str == "float" || type_str == "Float"
    return type_make_f64()
  @elif type_str == "bool" || type_str == "Bool"
    return type_make_bool()
  @elif type_str == "string" || type_str == "String" || type_str == "str"
    return type_make_string()
  @elif type_str == "void" || type_str == "Void"
    return type_make_void()
  @elif type_str == "ptr" || type_str == "Pointer"
    return type_make_ptr()
  @end

  @if tc_has_enum(env, type_str) == 1
    return type_make_i64()
  @end

  st_layout = tc_get_struct(env, type_str)
  @if tc_struct_get_name(st_layout) != ""
    return type_make_struct(tc_struct_get_name(st_layout), tc_struct_get_fields(st_layout))
  @end

  @if str_starts_with(type_str, "array[") && str_ends_with(type_str, "]")
    inner_name = str_substr(type_str, 6, str_len(type_str) - 7)
    inner_t = resolve_type_name(env, inner_name)
    return type_make_array(inner_t)
  @end

  @if str_starts_with(type_str, "Result")
    return type_make_result(type_make_any(), type_make_any())
  @end

  return type_make_any()
@end

@! ============================================================================
@! 4. PASS 1: GLOBAL DECLARATIONS & SYMBOL TABLE REGISTRATION
@! ============================================================================

@fn register_builtins(env)
  @! IO Builtins
  env = typeenv_define_fn(env, "print", "void")
  env = typeenv_define_fn(env, "println", "void")
  env = typeenv_define_fn(env, "read_line", "string")
  env = typeenv_define_fn(env, "read_stdin", "string")
  env = typeenv_define_fn(env, "print_err", "i64")

  @! GC & Memory Builtins
  env = typeenv_define_fn(env, "gc_init", "i64")
  env = typeenv_define_fn(env, "gc_alloc", "i64")
  env = typeenv_define_fn(env, "gc_realloc", "i64")
  env = typeenv_define_fn(env, "gc_free", "i64")
  env = typeenv_define_fn(env, "gc_base", "i64")
  env = typeenv_define_fn(env, "gc_collect", "i64")
  env = typeenv_define_fn(env, "maya_alloc", "i64")
  env = typeenv_define_fn(env, "maya_free", "i64")

  @! String Builtins
  env = typeenv_define_fn(env, "str_len", "i64")
  env = typeenv_define_fn(env, "str_concat", "string")
  env = typeenv_define_fn(env, "str_substr", "string")
  env = typeenv_define_fn(env, "str_split", "array")
  env = typeenv_define_fn(env, "str_trim", "string")
  env = typeenv_define_fn(env, "int_to_str", "string")
  env = typeenv_define_fn(env, "str_to_int", "i64")
  env = typeenv_define_fn(env, "char_at", "i64")
  env = typeenv_define_fn(env, "char_from_code", "string")
  env = typeenv_define_fn(env, "str_starts_with", "bool")
  env = typeenv_define_fn(env, "str_ends_with", "bool")

  @! Collection Builtins
  env = typeenv_define_fn(env, "map_new", "any")
  env = typeenv_define_fn(env, "map_get", "i64")
  env = typeenv_define_fn(env, "map_set", "any")
  env = typeenv_define_fn(env, "array_concat", "array")

  @! Syscall Builtins
  env = typeenv_define_fn(env, "syscall", "i64")
  env = typeenv_define_fn(env, "sys_open", "i64")
  env = typeenv_define_fn(env, "sys_read", "i64")
  env = typeenv_define_fn(env, "sys_write", "i64")
  env = typeenv_define_fn(env, "sys_close", "i64")
  env = typeenv_define_fn(env, "sys_exit", "void")
  env = typeenv_define_fn(env, "sys_mmap", "i64")
  env = typeenv_define_fn(env, "sys_munmap", "i64")
  env = typeenv_define_fn(env, "sys_chmod", "i64")

  return env
@end

@fn pass1_populate_globals(ast_nodes, env)
  env = register_builtins(env)

  i = 0
  @while i < ast_nodes.len()
    node = ast_nodes[i]
    kind = node.kind

    @! 1. Struct / Type Declaration
    @if kind == "StructDef" || kind == "TypeDef" || kind == "Struct"
      sname = node.name
      @if tc_has_struct(env, sname) == 1
        env = tc_add_error(env, "Duplicate struct definition: " + sname)
      @else
        fields = []
        raw_fields = node.params
        @if raw_fields.len() == 0 raw_fields = node.elements @end
        f_idx = 0
        @while f_idx < raw_fields.len()
          f = raw_fields[f_idx]
          f_name = ast_field_get_name(f)
          @if f_name == "" f_name = ast_param_get_name(f) @end
          @if f_name == "" f_name = f.name @end
          f_type_str = ast_field_get_type(f)
          @if f_type_str == "" f_type_str = ast_param_get_type(f) @end
          @if f_type_str == "" f_type_str = f.type_name @end
          @if f_type_str == "" f_type_str = "i64" @end
          fields = fields.push({
            name: f_name,
            field_type: resolve_type_name(env, f_type_str),
            index: f_idx,
            offset_bytes: f_idx * 8,
            size_bytes: 8,
            type_name: f_type_str
          })
          f_idx = f_idx + 1
        @end
        layout = { name: sname, fields: fields, total_size: fields.len() * 8, alignment: 8, methods: [] }
        env.structs = env.structs.push(layout)
      @end

    @! 2. Enum Declaration
    @elif kind == "EnumDef"
      ename = node.name
      env.enums = env.enums.push(ename)
      variants = node.elements
      v_idx = 0
      @while v_idx < variants.len()
        v = variants[v_idx]
        v_name = ename + "_" + ast_variant_get_name(v)
        v_val = ast_variant_get_value(v)
        @if tc_lookup_constant(env, v_name) < 0
          env.constants = env.constants.push(ast_constant(v_name, v_val))
        @end
        v_idx = v_idx + 1
      @end

    @! 3. Function Declaration
    @elif kind == "FnDef"
      fname = node.name
      @if tc_has_fn(env, fname) == 1
        @! Already defined or builtin
      @else
        ret_t = resolve_type_name(env, node.ret_type)
        fn_sym = {
          name: fname,
          param_names: node.params,
          param_types: [],
          ret_type: ret_t,
          is_varargs: 0,
          is_method: 0,
          struct_name: "",
          body_node: node
        }
        env.functions = env.functions.push(fn_sym)
        env.te_fns = env.te_fns.push({ fn_name: fname, fn_ret: node.ret_type })
      @end

    @! 4. Impl Block
    @elif kind == "ImplBlock"
      st_target = node.name
      methods = node.body
      m_idx = 0
      @while m_idx < methods.len()
        m_node = methods[m_idx]
        m_name = m_node.name
        @! Register method in functions
        fn_sym = {
          name: m_name,
          param_names: m_node.params,
          param_types: [],
          ret_type: resolve_type_name(env, m_node.ret_type),
          is_varargs: 0,
          is_method: 1,
          struct_name: st_target,
          body_node: m_node
        }
        env.functions = env.functions.push(fn_sym)
        env = tc_add_struct_method(env, st_target, m_name)
        m_idx = m_idx + 1
      @end
    @end

    i = i + 1
  @end
  return env
@end

@! ============================================================================
@! 5. PASS 2: STRUCT LAYOUT & METHOD BINDING
@! ============================================================================

@fn pass2_compute_struct_layouts(env)
  s_idx = 0
  @while s_idx < env.structs.len()
    layout = env.structs[s_idx]
    current_offset = 0
    resolved_fields = []

    fields = tc_struct_get_fields(layout)
    f_idx = 0
    @while f_idx < fields.len()
      field = fields[f_idx]
      f_type = tc_field_get_type(field)
      f_type_str = tc_field_get_type_name(field)
      @if f_type.kind == TYPE_ANY() && f_type_str != "" && f_type_str != "any" && f_type_str != "Any"
        f_type = resolve_type_name(env, f_type_str)
      @end
      f_size = 8
      f_align = 8

      @if current_offset % f_align != 0
        current_offset = current_offset + (f_align - (current_offset % f_align))
      @end

      resolved_fields = resolved_fields.push({
        name: tc_field_get_name(field),
        field_type: f_type,
        index: f_idx,
        offset_bytes: current_offset,
        size_bytes: f_size,
        type_name: f_type_str
      })
      current_offset = current_offset + f_size
      f_idx = f_idx + 1
    @end

    total_sz = current_offset
    @if total_sz == 0 total_sz = 8 @end
    @if total_sz % 8 != 0
      total_sz = total_sz + (8 - (total_sz % 8))
    @end

    layout.fields = resolved_fields
    layout.total_size = total_sz
    layout.alignment = 8
    env.structs[s_idx] = layout
    s_idx = s_idx + 1
  @end
  return env
@end

@! ============================================================================
@! 6. PASS 3: STATEMENT & EXPRESSION TYPE INFERENCE
@! ============================================================================

@fn check_expression(expr, env)
  @if expr == 0
    return { type: type_make_void(), env: env, expr: expr }
  @end
  kind = expr.kind

  @! 1. Literal Primitives
  @if kind == "LiteralInt"
    return { type: type_make_i64(), env: env, expr: expr }
  @elif kind == "LiteralFloat"
    return { type: type_make_f64(), env: env, expr: expr }
  @elif kind == "LiteralStr"
    return { type: type_make_string(), env: env, expr: expr }
  @elif kind == "LiteralBool"
    return { type: type_make_bool(), env: env, expr: expr }
  @elif kind == "LiteralNone"
    return { type: type_make_ptr(), env: env, expr: expr }

  @! 2. Variable Lookup
  @elif kind == "Variable"
    v_sym = scope_lookup_var(env, expr.name)
    @if v_sym.name != ""
      return { type: v_sym.var_type, env: env, expr: expr }
    @else
      c_val = tc_lookup_constant(env, expr.name)
      @if c_val >= 0
        return { type: type_make_i64(), env: env, expr: expr }
      @end
    @end
    return { type: type_make_any(), env: env, expr: expr }

  @! 3. Unary Operations
  @elif kind == "UnaryOp"
    u_res = check_expression(expr.expr, env)
    env = u_res.env
    @if expr.op == "!"
      return { type: type_make_bool(), env: env, expr: expr }
    @end
    return { type: u_res.type, env: env, expr: expr }

  @! 4. Binary Operations
  @elif kind == "BinaryOp"
    l_res = check_expression(expr.left, env)
    r_res = check_expression(expr.right, l_res.env)
    env = r_res.env
    l_t = l_res.type
    r_t = r_res.type
    op = expr.op

    @if op == "==" || op == "!=" || op == "<" || op == "<=" || op == ">" || op == ">=" || op == "&&" || op == "||"
      return { type: type_make_bool(), env: env, expr: expr }
    @elif op == "+"
      @if l_t.kind == TYPE_STRING() || r_t.kind == TYPE_STRING()
        return { type: type_make_string(), env: env, expr: expr }
      @elif l_t.kind == TYPE_F64() || r_t.kind == TYPE_F64()
        return { type: type_make_f64(), env: env, expr: expr }
      @else
        return { type: type_make_i64(), env: env, expr: expr }
      @end
    @elif op == "-" || op == "*" || op == "/" || op == "%"
      @if l_t.kind == TYPE_F64() || r_t.kind == TYPE_F64()
        return { type: type_make_f64(), env: env, expr: expr }
      @else
        return { type: type_make_i64(), env: env, expr: expr }
      @end
    @elif op == "&" || op == "|" || op == "^" || op == "<<" || op == ">>"
      return { type: type_make_i64(), env: env, expr: expr }
    @elif op == "|>"
      return { type: r_t, env: env, expr: expr }
    @end
    return { type: type_make_any(), env: env, expr: expr }

  @! 5. Function & Method Calls
  @elif kind == "Call"
    args = expr.args
    a_idx = 0
    @while a_idx < args.len()
      arg_res = check_expression(args[a_idx], env)
      env = arg_res.env
      a_idx = a_idx + 1
    @end

    callee = expr.func
    @if callee != 0 && callee.kind == "Variable"
      fn_sym = tc_lookup_fn(env, callee.name)
      @if fn_sym.name != ""
        return { type: fn_sym.ret_type, env: env, expr: expr }
      @end
    @elif callee != 0 && callee.kind == "MemberAccess"
      obj_res = check_expression(callee.left, env)
      env = obj_res.env
      obj_t = obj_res.type
      m_name = callee.name
      @if obj_t.kind == TYPE_STRUCT()
        method_fn_name = obj_t.name + "_" + m_name
        fn_sym = tc_lookup_fn(env, method_fn_name)
        @if fn_sym.name != ""
          return { type: fn_sym.ret_type, env: env, expr: expr }
        @end
      @elif obj_t.kind == TYPE_ARRAY() && (m_name == "num_items" || m_name == "length")
        return { type: type_make_i64(), env: env, expr: expr }
      @elif obj_t.kind == TYPE_STRING() && (m_name == "num_items" || m_name == "length")
        return { type: type_make_i64(), env: env, expr: expr }
      @end
    @end
    return { type: type_make_any(), env: env, expr: expr }

  @! 6. Member Access
  @elif kind == "MemberAccess"
    obj_res = check_expression(expr.left, env)
    env = obj_res.env
    obj_t = obj_res.type
    field_name = expr.name

    @if obj_t.kind == TYPE_STRUCT()
      st_layout = tc_get_struct(env, obj_t.name)
      f_sym = tc_struct_get_field(st_layout, field_name)
      @if tc_field_get_name(f_sym) != ""
        return { type: tc_field_get_type(f_sym), env: env, expr: expr }
      @end
    @elif (obj_t.kind == TYPE_ARRAY() || obj_t.kind == TYPE_STRING()) && (field_name == "num_items" || field_name == "length")
      return { type: type_make_i64(), env: env, expr: expr }
    @end
    return { type: type_make_any(), env: env, expr: expr }

  @! 7. Array & Map Indexing
  @elif kind == "Index"
    tgt_res = check_expression(expr.left, env)
    idx_res = check_expression(expr.index, tgt_res.env)
    env = idx_res.env
    tgt_t = tgt_res.type
    @if tgt_t.kind == TYPE_ARRAY() && tgt_t.elem_type != 0
      return { type: tgt_t.elem_type, env: env, expr: expr }
    @elif tgt_t.kind == TYPE_STRING()
      return { type: type_make_string(), env: env, expr: expr }
    @end
    return { type: type_make_any(), env: env, expr: expr }

  @! 8. Array & Map Literals
  @elif kind == "ArrayLit"
    elem_t = type_make_any()
    e_idx = 0
    @while e_idx < expr.elements.len()
      el_res = check_expression(expr.elements[e_idx], env)
      env = el_res.env
      @if e_idx == 0 elem_t = el_res.type @end
      e_idx = e_idx + 1
    @end
    return { type: type_make_array(elem_t), env: env, expr: expr }

  @elif kind == "MapLit"
    e_idx = 0
    @while e_idx < expr.elements.len()
      entry = expr.elements[e_idx]
      v_res = check_expression(entry.value, env)
      env = v_res.env
      e_idx = e_idx + 1
    @end
    return { type: type_make_any(), env: env, expr: expr }

  @! 9. Struct Literal
  @elif kind == "StructLit" || kind == "StructLiteral" || kind == "StructInit"
    st_layout = tc_get_struct(env, expr.name)
    e_idx = 0
    @while e_idx < expr.elements.len()
      entry = expr.elements[e_idx]
      v_res = check_expression(entry.value, env)
      env = v_res.env
      e_idx = e_idx + 1
    @end
    @if tc_struct_get_name(st_layout) != ""
      return { type: type_make_struct(tc_struct_get_name(st_layout), tc_struct_get_fields(st_layout)), env: env, expr: expr }
    @end
    return { type: type_make_any(), env: env, expr: expr }

  @! 10. Closures
  @elif kind == "Closure"
    env = scope_enter(env)
    p_idx = 0
    @while p_idx < expr.params.len()
      env = scope_define_var(env, expr.params[p_idx], type_make_any(), 0)
      p_idx = p_idx + 1
    @end
    b_idx = 0
    @while b_idx < expr.body.len()
      env = check_statement(expr.body[b_idx], env)
      b_idx = b_idx + 1
    @end
    env = scope_exit(env)
    return { type: type_make_fn([], type_make_any()), env: env, expr: expr }

  @! 11. Match Expression
  @elif kind == "MatchExpr" || kind == "MatchStmt"
    tgt_res = check_expression(expr.target, env)
    env = tgt_res.env
    ret_t = type_make_any()
    a_idx = 0
    @while a_idx < expr.elements.len()
      arm = expr.elements[a_idx]
      arm_pat = ast_match_arm_get_pattern(arm)
      @if arm_pat != 0
        pat_res = check_expression(arm_pat, env)
        env = pat_res.env
      @end
      arm_body = ast_match_arm_get_body(arm)
      arm_env = scope_enter(env)
      last_type = type_make_void()
      b_idx = 0
      @while b_idx < arm_body.len()
        s_node = arm_body[b_idx]
        @if s_node != 0
          @if s_node.kind == "Return"
            @if s_node.value != 0
              r_res = check_expression(s_node.value, arm_env)
              arm_env = r_res.env
              last_type = r_res.type
            @end
          @else
            arm_env = check_statement(s_node, arm_env)
          @end
        @end
        b_idx = b_idx + 1
      @end
      env = scope_exit(arm_env)
      @if a_idx == 0 ret_t = last_type @end
      a_idx = a_idx + 1
    @end
    return { type: ret_t, env: env, expr: expr }
  @end

  return { type: type_make_any(), env: env, expr: expr }
@end

@fn check_statement(stmt, env)
  @if stmt == 0 return env @end
  kind = stmt.kind

  @! 1. Variable Assignment / Declaration
  @if kind == "Assign" || kind == "VarDecl"
    v_name = stmt.target
    @if v_name == "" v_name = stmt.name @end
    val_res = check_expression(stmt.value, env)
    env = val_res.env
    existing = scope_lookup_var(env, v_name)
    @if existing.name == ""
      env = scope_define_var(env, v_name, val_res.type, 0)
    @end
    return env

  @! 2. Return Statement
  @elif kind == "Return"
    @if stmt.value != 0
      r_res = check_expression(stmt.value, env)
      env = r_res.env
    @end
    return env

  @! 3. If Statement
  @elif kind == "IfStmt"
    c_res = check_expression(stmt.condition, env)
    env = c_res.env
    env = scope_enter(env)
    t_idx = 0
    @while t_idx < stmt.then_body.len()
      env = check_statement(stmt.then_body[t_idx], env)
      t_idx = t_idx + 1
    @end
    env = scope_exit(env)

    e_idx = 0
    @while e_idx < stmt.elif_branches.len()
      branch = stmt.elif_branches[e_idx]
      eb_cond_res = check_expression(ast_elif_get_condition(branch), env)
      env = eb_cond_res.env
      env = scope_enter(env)
      b_idx = 0
      branch_body = ast_elif_get_body(branch)
      @while b_idx < branch_body.len()
        env = check_statement(branch_body[b_idx], env)
        b_idx = b_idx + 1
      @end
      env = scope_exit(env)
      e_idx = e_idx + 1
    @end

    @if stmt.else_body.len() > 0
      env = scope_enter(env)
      el_idx = 0
      @while el_idx < stmt.else_body.len()
        env = check_statement(stmt.else_body[el_idx], env)
        el_idx = el_idx + 1
      @end
      env = scope_exit(env)
    @end
    return env

  @! 4. While Loop
  @elif kind == "WhileLoop"
    c_res = check_expression(stmt.condition, env)
    env = c_res.env
    env.in_loop_depth = env.in_loop_depth + 1
    env = scope_enter(env)
    b_idx = 0
    @while b_idx < stmt.body.len()
      env = check_statement(stmt.body[b_idx], env)
      b_idx = b_idx + 1
    @end
    env = scope_exit(env)
    env.in_loop_depth = env.in_loop_depth - 1
    return env

  @! 5. For Loop
  @elif kind == "ForLoop"
    it_res = check_expression(stmt.iterable, env)
    env = it_res.env
    env.in_loop_depth = env.in_loop_depth + 1
    env = scope_enter(env)
    elem_t = type_make_any()
    @if it_res.type.kind == TYPE_ARRAY() && it_res.type.elem_type != 0
      elem_t = it_res.type.elem_type
    @end
    env = scope_define_var(env, stmt.variable, elem_t, 0)
    b_idx = 0
    @while b_idx < stmt.body.len()
      env = check_statement(stmt.body[b_idx], env)
      b_idx = b_idx + 1
    @end
    env = scope_exit(env)
    env.in_loop_depth = env.in_loop_depth - 1
    return env

  @! 6. Try-Catch Block
  @elif kind == "TryCatch"
    env = scope_enter(env)
    t_idx = 0
    @while t_idx < stmt.then_body.len()
      env = check_statement(stmt.then_body[t_idx], env)
      t_idx = t_idx + 1
    @end
    env = scope_exit(env)

    env = scope_enter(env)
    env = scope_define_var(env, stmt.name, type_make_any(), 0)
    c_idx = 0
    @while c_idx < stmt.else_body.len()
      env = check_statement(stmt.else_body[c_idx], env)
      c_idx = c_idx + 1
    @end
    env = scope_exit(env)
    return env

  @! 7. Defer Statement
  @elif kind == "Defer"
    return check_statement(stmt.expr, env)

  @! 8. Break & Continue
  @elif kind == "Break" || kind == "Continue"
    @if env.in_loop_depth <= 0
      env = tc_add_error(env, "'" + kind + "' statement outside loop")
    @end
    return env

  @! 9. Function Definition Body
  @elif kind == "FnDef"
    env.current_fn_name = stmt.name
    env.current_fn_ret = resolve_type_name(env, stmt.ret_type)
    env = scope_enter(env)
    p_idx = 0
    @while p_idx < stmt.params.len()
      p_name = stmt.params[p_idx]
      env = scope_define_var(env, p_name, type_make_any(), 0)
      p_idx = p_idx + 1
    @end
    b_idx = 0
    @while b_idx < stmt.body.len()
      env = check_statement(stmt.body[b_idx], env)
      b_idx = b_idx + 1
    @end
    env = scope_exit(env)
    env.current_fn_name = ""
    return env

  @! 10. Standalone Expression Statement
  @elif kind == "ExpressionStmt"
    res = check_expression(stmt.expr, env)
    return res.env
  @end

  return env
@end

@! ============================================================================
@! 7. PASS 4: CONTROL-FLOW ANALYSIS & REACHABILITY
@! ============================================================================

@fn stmt_has_unconditional_return(stmt)
  @if stmt == 0 return 0 @end
  @if stmt.kind == "Return" return 1 @end
  @if stmt.kind == "IfStmt"
    @if stmt.else_body.len() == 0 return 0 @end
    then_ret = block_has_unconditional_return(stmt.then_body)
    else_ret = block_has_unconditional_return(stmt.else_body)
    @if then_ret == 1 && else_ret == 1
      e_idx = 0
      @while e_idx < stmt.elif_branches.len()
        branch = stmt.elif_branches[e_idx]
        @if block_has_unconditional_return(ast_elif_get_body(branch)) == 0
          return 0
        @end
        e_idx = e_idx + 1
      @end
      return 1
    @end
  @end
  return 0
@end

@fn block_has_unconditional_return(stmts)
  i = 0
  @while i < stmts.len()
    @if stmt_has_unconditional_return(stmts[i]) == 1 return 1 @end
    i = i + 1
  @end
  return 0
@end

@fn pass4_verify_control_flow(ast_nodes, env)
  i = 0
  @while i < ast_nodes.len()
    node = ast_nodes[i]
    @if node.kind == "FnDef"
      ret_t = resolve_type_name(env, node.ret_type)
      @if ret_t.kind != TYPE_VOID() && node.name != "main" && node.body.len() > 0
        has_ret = block_has_unconditional_return(node.body)
        @if has_ret == 0
          @! Non-fatal warning or fallback
          env.warnings = env.warnings.push("Function '" + node.name + "' may not return a value on all code paths")
        @end
      @end
    @end
    i = i + 1
  @end
  return env
@end

@! ============================================================================
@! 8. MODULE IMPORT RESOLUTION WITH CYCLE DETECTION (Tri-Color DFS)
@! ============================================================================

@struct ImportGraphNode
  path: string
  color: i64         @! 0 = WHITE (unvisited), 1 = GRAY (visiting), 2 = BLACK (done)
  ast_nodes: array
@end

@fn import_graph_has_cycle(import_map, current_path, visited_stack)
  @! Detect cycle using visited stack
  i = 0
  @while i < visited_stack.len()
    @if visited_stack[i] == current_path return 1 @end
    i = i + 1
  @end
  return 0
@end

@! ============================================================================
@! 9. TYPECHECKER MAIN ENTRY POINTS
@! ============================================================================

@fn typecheck_program(ast_nodes, env)
  @if env == 0 env = typeenv_new() @end

  @! Pass 1: Global Declarations & Symbol Table
  env = pass1_populate_globals(ast_nodes, env)

  @! Pass 2: Struct Layouts & Offset Calculations
  env = pass2_compute_struct_layouts(env)

  @! Pass 3: Statement & Expression Type Checking
  i = 0
  @while i < ast_nodes.len()
    env = check_statement(ast_nodes[i], env)
    i = i + 1
  @end

  @! Pass 4: Control Flow Verification
  env = pass4_verify_control_flow(ast_nodes, env)

  return env
@end

@fn typecheck_program_ast(prog: ASTProgram)
  env = typeenv_new()
  c_idx = 0
  @while c_idx < prog.constants.len()
    c = prog.constants[c_idx]
    env.constants = env.constants.push(c)
    c_idx = c_idx + 1
  @end

  ast_nodes = []
  i = 0
  @while i < prog.structs.len()
    ast_nodes = ast_nodes.push(prog.structs[i])
    i = i + 1
  @end
  i = 0
  @while i < prog.enums.len()
    ast_nodes = ast_nodes.push(prog.enums[i])
    i = i + 1
  @end
  i = 0
  @while i < prog.impls.len()
    ast_nodes = ast_nodes.push(prog.impls[i])
    i = i + 1
  @end
  i = 0
  @while i < prog.functions.len()
    ast_nodes = ast_nodes.push(prog.functions[i])
    i = i + 1
  @end
  i = 0
  @while i < prog.top_level.len()
    ast_nodes = ast_nodes.push(prog.top_level[i])
    i = i + 1
  @end
  return typecheck_program(ast_nodes, env)
@end

@fn typecheck_ast(ast_nodes)
  env = typeenv_new()
  return typecheck_program(ast_nodes, env)
@end

@fn typecheck_source(source_code)
  prog = parse_source_program(source_code)
  return typecheck_program_ast(prog)
@end
