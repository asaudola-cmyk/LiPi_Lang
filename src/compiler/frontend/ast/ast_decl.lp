// ============================================================================
// LIPI FRONTEND COMPILER — DECLARATION AST NODES & PROGRAM ROOT
// Module: src/compiler/frontend/ast/ast_decl.lp
// Standard: Lipi First 1.0.0 (প্রথম ১.০.০)
// 100% Pure Lipi | Zero C | Zero Libc | Zero External Dependencies
// ============================================================================
//
// WHY THIS MODULE:
// 1. Encapsulates all top-level and module-level declarations: functions (`fn`/`কাজ`),
//    structs (`struct`/`গঠন`), impl blocks, enums, globals/constants, and imports.
// 2. Bilingual symbol table mapping: Function and struct definitions capture
//    both ASCII and Unicode Bengali identifiers into unified AST declaration symbols.
// 3. Root compilation unit model: `ASTProgram` aggregates modular declarations
//    into categorized collections for downstream type checking, symbol resolution,
//    and ELF linker symbol emission.
// ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "compiler/frontend/lexer/token"
import "compiler/frontend/ast/ast_node"

// ── 1. Supporting Declaration Descriptors ─────────────────────────────────────

// WHY: Function formal parameter descriptor with zero-collision schema
@struct ASTParam
  param_name: string
  param_type: string
  param_default: ASTNode
  param_span: SourceSpan
@end

// WHY: Struct field declaration descriptor with memory layout index
@struct ASTField
  field_name: string
  field_type: string
  field_default: ASTNode
  field_index: i64
  field_span: SourceSpan
@end

// WHY: Enumeration variant tag descriptor with integer discriminator
@struct ASTEnumVariant
  variant_name: string
  variant_value: i64
  variant_span: SourceSpan
@end

// WHY: Global constant definition descriptor
@struct ASTConstant
  const_name: string
  const_value: i64
@end

// WHY: Program root model aggregating all module declarations
@struct ASTProgram
  prog_imports: array
  prog_structs: array
  prog_enums: array
  prog_impls: array
  prog_functions: array
  prog_constants: array
  prog_top_level: array
@end

// ── 2. Descriptor Constructors ───────────────────────────────────────────────

@fn ast_param_new(name: string, type_name: string, default_val: ASTNode, span: SourceSpan)
  // WHY: Allocates parameter specification with name, type constraint, and optional default
  return {
    param_name: name,
    param_type: type_name,
    param_default: default_val,
    param_span: span
  }
@end

@fn ast_param(name, type_name, default_val)
  // WHY: Legacy compatibility constructor for parameters
  return ast_param_new(name, type_name, default_val, source_span_zero())
@end

@fn ast_field_new(name: string, type_name: string, default_val: ASTNode, index: i64, span: SourceSpan)
  // WHY: Allocates struct field specification with hardware field offset index
  return {
    field_name: name,
    field_type: type_name,
    field_default: default_val,
    field_index: index,
    field_span: span
  }
@end

@fn ast_field(name, type_name, default_val, index)
  // WHY: Legacy compatibility constructor for struct fields
  return ast_field_new(name, type_name, default_val, index, source_span_zero())
@end

@fn ast_enum_variant_new(name: string, value: i64, span: SourceSpan)
  // WHY: Allocates enum variant mapping identifier to integer discriminator
  return {
    variant_name: name,
    variant_value: value,
    variant_span: span
  }
@end

@fn ast_enum_variant(name: string, value: i64)
  // WHY: Legacy compatibility constructor for enum variants
  return ast_enum_variant_new(name, value, source_span_zero())
@end

@fn ast_constant(name: string, value: i64)
  // WHY: Legacy compatibility constructor for constants
  return {
    const_name: name,
    const_value: value
  }
@end

// ── 3. Declaration AST Node Constructors ──────────────────────────────────────

@fn ast_decl_fn(name: string, params: array, ret_type: string, body: array, is_public: i64, span: SourceSpan)
  // WHY: Allocates function declaration AST node with System V ABI signature
  node = ast_node_new(AST_TAG_FN_DEF(), "FnDef", span)
  node.name = name
  node.params = params
  node.ret_type = ret_type
  node.body = body
  node.val = is_public
  return node
@end

@fn ast_fn_def(name: string, params: array, ret_type: string, body: array)
  // WHY: Legacy compatibility constructor for function definitions
  return ast_decl_fn(name, params, ret_type, body, 1, source_span_zero())
@end

@fn ast_decl_struct(name: string, fields: array, span: SourceSpan)
  // WHY: Allocates structured composite type definition storing fields in params
  node = ast_node_new(AST_TAG_STRUCT_DEF(), "StructDef", span)
  node.name = name
  node.params = fields
  node.ret_type = name
  return node
@end

@fn ast_struct_def(name: string, fields: array)
  // WHY: Legacy compatibility constructor for struct definitions
  return ast_decl_struct(name, fields, source_span_zero())
@end

@fn ast_decl_impl(trait_name: string, target_type: string, methods: array, span: SourceSpan)
  // WHY: Allocates impl block binding methods to target struct type
  node = ast_node_new(AST_TAG_STRUCT_DEF(), "ImplBlock", span)
  node.name = target_type
  node.ret_type = trait_name
  node.body = methods
  return node
@end

@fn ast_impl_block(trait_name: string, target_type: string, methods: array)
  // WHY: Legacy compatibility constructor for impl blocks
  return ast_decl_impl(trait_name, target_type, methods, source_span_zero())
@end

@fn ast_decl_enum(name: string, variants: array, span: SourceSpan)
  // WHY: Allocates enumerated type definition storing variants in elements
  node = ast_node_new(AST_TAG_ENUM_DEF(), "EnumDef", span)
  node.name = name
  node.elements = variants
  node.ret_type = name
  return node
@end

@fn ast_enum_def(name: string, variants: array)
  // WHY: Legacy compatibility constructor for enum definitions
  return ast_decl_enum(name, variants, source_span_zero())
@end

@fn ast_decl_global(name: string, type_name: string, init_val: ASTNode, is_const: i64, span: SourceSpan)
  // WHY: Allocates module-level global variable or constant binding
  node = ast_node_new(AST_TAG_GLOBAL_VAR(), "GlobalVar", span)
  node.name = name
  node.ret_type = type_name
  node.value = init_val
  node.val = is_const
  return node
@end

@fn ast_decl_import(path: string, alias: string, span: SourceSpan)
  // WHY: Allocates module import declaration pointing to external source file
  node = ast_node_new(AST_TAG_IMPORT(), "Import", span)
  node.name = path
  node.target = alias
  node.ret_type = "void"
  return node
@end

@fn ast_import(path: string)
  // WHY: Legacy compatibility constructor for import statements
  return ast_decl_import(path, "", source_span_zero())
@end

// ── 4. Program Compilation Unit ───────────────────────────────────────────────

@fn ast_program_new()
  // WHY: Allocates empty program root container
  return {
    prog_imports: [],
    prog_structs: [],
    prog_enums: [],
    prog_impls: [],
    prog_functions: [],
    prog_constants: [],
    prog_top_level: []
  }
@end

@fn ast_program_add_fn(prog: ASTProgram, fn_node: ASTNode)
  // WHY: Appends function declaration to program registry
  prog.prog_functions = prog.prog_functions.push(fn_node)
  return prog
@end

@fn ast_program_add_struct(prog: ASTProgram, struct_node: ASTNode)
  // WHY: Appends struct declaration to program registry
  prog.prog_structs = prog.prog_structs.push(struct_node)
  return prog
@end

@fn ast_program_add_enum(prog: ASTProgram, enum_node: ASTNode)
  // WHY: Appends enum declaration to program registry
  prog.prog_enums = prog.prog_enums.push(enum_node)
  return prog
@end

@fn ast_program_add_import(prog: ASTProgram, import_node: ASTNode)
  // WHY: Appends module import declaration to program registry
  prog.prog_imports = prog.prog_imports.push(import_node)
  return prog
@end

@fn ast_program_add_top_level(prog: ASTProgram, stmt_node: ASTNode)
  // WHY: Appends top-level statement to program initialization sequence
  prog.prog_top_level = prog.prog_top_level.push(stmt_node)
  return prog
@end
