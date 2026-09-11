@! ============================================================================
@! WebAssembly IR Representation (Expanded MVP + 2.0)
@! ============================================================================

@fn wasm_type_i32()
  return 127
@end

@fn wasm_type_i64()
  return 126
@end

@fn wasm_type_f32()
  return 125
@end

@fn wasm_type_f64()
  return 124
@end

@fn wasm_type_v128()
  return 123
@end

@fn wasm_type_funcref()
  return 112
@end

@fn wasm_type_externref()
  return 111
@end

@! Control flow
@fn wasm_op_unreachable()
  return 0
@end

@fn wasm_op_nop()
  return 1
@end

@fn wasm_op_block()
  return 2
@end

@fn wasm_op_loop()
  return 3
@end

@fn wasm_op_if()
  return 4
@end

@fn wasm_op_else()
  return 5
@end

@fn wasm_op_end()
  return 11
@end

@fn wasm_op_br()
  return 12
@end

@fn wasm_op_br_if()
  return 13
@end

@fn wasm_op_br_table()
  return 14
@end

@fn wasm_op_return()
  return 15
@end

@fn wasm_op_call()
  return 16
@end

@fn wasm_op_call_indirect()
  return 17
@end

@! Parametric
@fn wasm_op_drop()
  return 26
@end

@fn wasm_op_select()
  return 27
@end

@! Variable access
@fn wasm_op_local_get()
  return 32
@end

@fn wasm_op_local_set()
  return 33
@end

@fn wasm_op_local_tee()
  return 34
@end

@fn wasm_op_global_get()
  return 35
@end

@fn wasm_op_global_set()
  return 36
@end

@! Memory-related
@fn wasm_op_i32_load()
  return 40
@end

@fn wasm_op_i64_load()
  return 41
@end

@fn wasm_op_f32_load()
  return 42
@end

@fn wasm_op_f64_load()
  return 43
@end

@fn wasm_op_i32_load8_s()
  return 44
@end

@fn wasm_op_i32_load8_u()
  return 45
@end

@fn wasm_op_i32_load16_s()
  return 46
@end

@fn wasm_op_i32_load16_u()
  return 47
@end

@fn wasm_op_i64_load8_s()
  return 48
@end

@fn wasm_op_i64_load8_u()
  return 49
@end

@fn wasm_op_i64_load16_s()
  return 50
@end

@fn wasm_op_i64_load16_u()
  return 51
@end

@fn wasm_op_i64_load32_s()
  return 52
@end

@fn wasm_op_i64_load32_u()
  return 53
@end

@fn wasm_op_i32_store()
  return 54
@end

@fn wasm_op_i64_store()
  return 55
@end

@fn wasm_op_f32_store()
  return 56
@end

@fn wasm_op_f64_store()
  return 57
@end

@fn wasm_op_i32_store8()
  return 58
@end

@fn wasm_op_i32_store16()
  return 59
@end

@fn wasm_op_i64_store8()
  return 60
@end

@fn wasm_op_i64_store16()
  return 61
@end

@fn wasm_op_i64_store32()
  return 62
@end

@fn wasm_op_memory_size()
  return 63
@end

@fn wasm_op_memory_grow()
  return 64
@end

@! Constants
@fn wasm_op_i32_const()
  return 65
@end

@fn wasm_op_i64_const()
  return 66
@end

@fn wasm_op_f32_const()
  return 67
@end

@fn wasm_op_f64_const()
  return 68
@end

@! i32 Numeric
@fn wasm_op_i32_eqz()
  return 69
@end

@fn wasm_op_i32_eq()
  return 70
@end

@fn wasm_op_i32_ne()
  return 71
@end

@fn wasm_op_i32_lt_s()
  return 72
@end

@fn wasm_op_i32_lt_u()
  return 73
@end

@fn wasm_op_i32_gt_s()
  return 74
@end

@fn wasm_op_i32_gt_u()
  return 75
@end

@fn wasm_op_i32_le_s()
  return 76
@end

@fn wasm_op_i32_le_u()
  return 77
@end

@fn wasm_op_i32_ge_s()
  return 78
@end

@fn wasm_op_i32_ge_u()
  return 79
@end

@! i64 Numeric
@fn wasm_op_i64_eqz()
  return 80
@end

@fn wasm_op_i64_eq()
  return 81
@end

@fn wasm_op_i64_ne()
  return 82
@end

@fn wasm_op_i64_lt_s()
  return 83
@end

@fn wasm_op_i64_lt_u()
  return 84
@end

@fn wasm_op_i64_gt_s()
  return 85
@end

@fn wasm_op_i64_gt_u()
  return 86
@end

@fn wasm_op_i64_le_s()
  return 87
@end

@fn wasm_op_i64_le_u()
  return 88
@end

@fn wasm_op_i64_ge_s()
  return 89
@end

@fn wasm_op_i64_ge_u()
  return 90
@end

@! f32 Numeric
@fn wasm_op_f32_eq()
  return 91
@end

@fn wasm_op_f32_ne()
  return 92
@end

@fn wasm_op_f32_lt()
  return 93
@end

@fn wasm_op_f32_gt()
  return 94
@end

@fn wasm_op_f32_le()
  return 95
@end

@fn wasm_op_f32_ge()
  return 96
@end

@! f64 Numeric
@fn wasm_op_f64_eq()
  return 97
@end

@fn wasm_op_f64_ne()
  return 98
@end

@fn wasm_op_f64_lt()
  return 99
@end

@fn wasm_op_f64_gt()
  return 100
@end

@fn wasm_op_f64_le()
  return 101
@end

@fn wasm_op_f64_ge()
  return 102
@end

@! i32 Arithmetic
@fn wasm_op_i32_clz()
  return 103
@end

@fn wasm_op_i32_ctz()
  return 104
@end

@fn wasm_op_i32_popcnt()
  return 105
@end

@fn wasm_op_i32_add()
  return 106
@end

@fn wasm_op_i32_sub()
  return 107
@end

@fn wasm_op_i32_mul()
  return 108
@end

@fn wasm_op_i32_div_s()
  return 109
@end

@fn wasm_op_i32_div_u()
  return 110
@end

@fn wasm_op_i32_rem_s()
  return 111
@end

@fn wasm_op_i32_rem_u()
  return 112
@end

@fn wasm_op_i32_and()
  return 113
@end

@fn wasm_op_i32_or()
  return 114
@end

@fn wasm_op_i32_xor()
  return 115
@end

@fn wasm_op_i32_shl()
  return 116
@end

@fn wasm_op_i32_shr_s()
  return 117
@end

@fn wasm_op_i32_shr_u()
  return 118
@end

@fn wasm_op_i32_rotl()
  return 119
@end

@fn wasm_op_i32_rotr()
  return 120
@end

@! i64 Arithmetic
@fn wasm_op_i64_clz()
  return 121
@end

@fn wasm_op_i64_ctz()
  return 122
@end

@fn wasm_op_i64_popcnt()
  return 123
@end

@fn wasm_op_i64_add()
  return 124
@end

@fn wasm_op_i64_sub()
  return 125
@end

@fn wasm_op_i64_mul()
  return 126
@end

@fn wasm_op_i64_div_s()
  return 127
@end

@fn wasm_op_i64_div_u()
  return 128
@end

@fn wasm_op_i64_rem_s()
  return 129
@end

@fn wasm_op_i64_rem_u()
  return 130
@end

@fn wasm_op_i64_and()
  return 131
@end

@fn wasm_op_i64_or()
  return 132
@end

@fn wasm_op_i64_xor()
  return 133
@end

@fn wasm_op_i64_shl()
  return 134
@end

@fn wasm_op_i64_shr_s()
  return 135
@end

@fn wasm_op_i64_shr_u()
  return 136
@end

@fn wasm_op_i64_rotl()
  return 137
@end

@fn wasm_op_i64_rotr()
  return 138
@end

@struct WasmInstr
  opcode: i64
  imm_i64: i64
  imm_f64: i64
  imm_list: array
  block_type: i64
@end

@fn instr_new(opcode)
  return { opcode: opcode, imm_i64: 0, imm_f64: 0, imm_list: [], block_type: 64 }
@end

@fn instr_new_const_i32(val)
  res = instr_new(65)
  res.imm_i64 = val
  return res
@end

@struct WasmFunc
  type_idx: i64
  locals: array
  body: array
@end

@struct FuncType
  params: array
  results: array
@end

@struct Import
  module_name: string
  field_name: string
  kind: i64
  type_idx: i64
@end

@struct TableType
  elem_type: i64
  limits_min: i64
  limits_max: i64
  has_max: i64
@end

@struct MemType
  limits_min: i64
  limits_max: i64
  has_max: i64
@end

@struct WasmGlobal
  val_type: i64
  is_mut: i64
  init_expr: array
@end

@struct Export
  name: string
  kind: i64
  index: i64
@end

@struct DataSegment
  mem_idx: i64
  offset_expr: array
  data: array
@end

@struct ElemSegment
  table_idx: i64
  offset_expr: array
  init: array
@end

@struct WasmModule
  types: array
  imports: array
  functions: array
  tables: array
  memories: array
  globals: array
  exports: array
  start: i64
  has_start: i64
  data: array
  elements: array
@end

@fn wasm_module_new()
  return {
    types: [],
    imports: [],
    functions: [],
    tables: [],
    memories: [],
    globals: [],
    exports: [],
    start: 0,
    has_start: 0,
    data: [],
    elements: []
  }
@end
