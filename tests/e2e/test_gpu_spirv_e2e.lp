@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE: GPU COMPUTE & SPIR-V ACCELERATOR E2E TEST SUITE
@! File: tests/e2e/test_gpu_spirv_e2e.maya
@! Milestone 4: SPIR-V 1.0 Binary Shader Emission & Compute Pipeline Dispatch
@! 100% Pure Maya Implementation — Zero C++ / Vulkan SDK / CUDA / LLVM Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/gpu/compute"
import "universe/gpu/shader"
import "universe/gpu/directive"

@! ============================================================================
@! 1. TEST STATE & ASSERTION FRAMEWORK
@! ============================================================================

@struct TestState
  total: i64
  passed: i64
  failed: i64
@end

@fn test_state_new()
  return {
    total: 0,
    passed: 0,
    failed: 0
  }
@end

@fn assert_true(state, cond, test_id, desc)
  state.total = state.total + 1
  @if cond == 1 || cond == true
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected true, got false)")
    return 0
  @end
@end

@fn assert_false(state, cond, test_id, desc)
  state.total = state.total + 1
  @if cond == 0 || cond == false
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected false, got true)")
    return 0
  @end
@end

@fn assert_eq_int(state, actual, expected, test_id, desc)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected " + expected.to_str() + ", got " + actual.to_str() + ")")
    return 0
  @end
@end

@fn assert_eq_str(state, actual, expected, test_id, desc)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected '" + expected + "', got '" + actual + "')")
    return 0
  @end
@end

@! ============================================================================
@! 2. TIER 1: SPIR-V BINARY HEADER & ENCODING SPECIFICATION
@! ============================================================================

@fn test_spirv_header_and_constants(state)
  println("\n▶ Tier 1.1: SPIR-V Magic Constants & Emitter Initialization")

  @! Assert Standard Constants
  assert_eq_int(state, SPIRV_MAGIC(), 119734787, "T1.1_01", "SPIRV_MAGIC constant equals 0x07230203 (119734787)")
  assert_eq_int(state, SPIRV_VERSION_1_0(), 65536, "T1.1_02", "SPIRV_VERSION_1_0 constant equals 0x00010000 (65536)")
  assert_eq_int(state, SPIRV_VERSION_1_5(), 66816, "T1.1_03", "SPIRV_VERSION_1_5 constant equals 0x00010500 (66816)")
  assert_eq_int(state, SPIRV_GENERATOR_MAYA(), 4919, "T1.1_04", "SPIRV_GENERATOR_MAYA constant equals 0x00001337 (4919)")

  @! Initialize Emitter
  emitter = spirv_emitter_new()
  assert_eq_int(state, emitter.words.len(), 0, "T1.1_05", "New emitter initialized with empty word stream")
  assert_eq_int(state, emitter.bound, 1, "T1.1_06", "New emitter ID bound initialized to 1")
  assert_eq_int(state, emitter.version, SPIRV_VERSION_1_0(), "T1.1_07", "New emitter version set to 1.0 (65536)")
  assert_eq_int(state, emitter.generator, SPIRV_GENERATOR_MAYA(), "T1.1_08", "New emitter generator ID set to Maya (4919)")
  assert_eq_int(state, emitter.schema, 0, "T1.1_09", "New emitter schema set to 0")

  @! Emit Binary Header
  test_bound = 42
  emitter = spirv_emit_header(emitter, test_bound)
  assert_eq_int(state, emitter.words.len(), 5, "T1.1_10", "SPIR-V Header length is exactly 5 32-bit words")
  assert_eq_int(state, emitter.words[0], 119734787, "T1.1_11", "Header Word 0 is SPIR-V Magic Number (0x07230203)")
  assert_eq_int(state, emitter.words[1], 65536, "T1.1_12", "Header Word 1 is Version 1.0 (0x00010000)")
  assert_eq_int(state, emitter.words[2], 4919, "T1.1_13", "Header Word 2 is Maya Generator Magic (0x00001337)")
  assert_eq_int(state, emitter.words[3], test_bound, "T1.1_14", "Header Word 3 is ID Bound count (42)")
  assert_eq_int(state, emitter.words[4], 0, "T1.1_15", "Header Word 4 is Reserved Schema (0)")
@end

@fn test_spirv_word_encoding_and_endianness(state)
  println("\n▶ Tier 1.2: Word Stream Instruction Encoding & Little-Endian Serialization")

  @! Test Instruction Word Packing: ((word_count * 65536) | opcode)
  emitter = spirv_emitter_new()
  emitter = spirv_emit_header(emitter, 10)

  @! 1. Emit OpCapability (opcode 17, 1 operand -> word count 2)
  emitter = spirv_emit_capability(emitter, CAP_SHADER())
  cap_word = emitter.words[5]
  expected_cap_word = (2 * 65536) | 17
  assert_eq_int(state, cap_word, expected_cap_word, "T1.2_01", "OpCapability first word packed as ((2 * 65536) | 17)")
  assert_eq_int(state, emitter.words[6], 1, "T1.2_02", "OpCapability operand 0 is CAP_SHADER (1)")

  @! 2. Emit OpMemoryModel (opcode 14, 2 operands -> word count 3)
  emitter = spirv_emit_memory_model(emitter, ADDR_LOGICAL(), MEM_GLSL450())
  mem_word = emitter.words[7]
  expected_mem_word = (3 * 65536) | 14
  assert_eq_int(state, mem_word, expected_mem_word, "T1.2_03", "OpMemoryModel first word packed as ((3 * 65536) | 14)")
  assert_eq_int(state, emitter.words[8], 0, "T1.2_04", "OpMemoryModel addressing model is Logical (0)")
  assert_eq_int(state, emitter.words[9], 1, "T1.2_05", "OpMemoryModel memory model is GLSL450 (1)")

  @! 3. Test Little-Endian 4-Byte Stream Unpacking
  bytes = spirv_words_to_bytes(emitter.words)
  assert_eq_int(state, bytes.len(), emitter.words.len() * 4, "T1.2_06", "Byte stream length equals word count * 4")

  @! Magic word 0x07230203 -> bytes [0x03, 0x02, 0x23, 0x07] = [3, 2, 35, 7]
  assert_eq_int(state, bytes[0], 3, "T1.2_07", "Magic byte 0 == 0x03 (3)")
  assert_eq_int(state, bytes[1], 2, "T1.2_08", "Magic byte 1 == 0x02 (2)")
  assert_eq_int(state, bytes[2], 35, "T1.2_09", "Magic byte 2 == 0x23 (35)")
  assert_eq_int(state, bytes[3], 7, "T1.2_10", "Magic byte 3 == 0x07 (7)")

  @! Version 1.0 (0x00010000) -> bytes [0x00, 0x00, 0x01, 0x00] = [0, 0, 1, 0]
  assert_eq_int(state, bytes[4], 0, "T1.2_11", "Version 1.0 byte 0 == 0")
  assert_eq_int(state, bytes[5], 0, "T1.2_12", "Version 1.0 byte 1 == 0")
  assert_eq_int(state, bytes[6], 1, "T1.2_13", "Version 1.0 byte 2 == 1")
  assert_eq_int(state, bytes[7], 0, "T1.2_14", "Version 1.0 byte 3 == 0")

  @! Maya Generator (0x00001337) -> bytes [0x37, 0x13, 0x00, 0x00] = [55, 19, 0, 0]
  assert_eq_int(state, bytes[8], 55, "T1.2_15", "Generator byte 0 == 0x37 (55)")
  assert_eq_int(state, bytes[9], 19, "T1.2_16", "Generator byte 1 == 0x13 (19)")
  assert_eq_int(state, bytes[10], 0, "T1.2_17", "Generator byte 2 == 0")
  assert_eq_int(state, bytes[11], 0, "T1.2_18", "Generator byte 3 == 0")

  @! Bound (10 = 0x0000000A) -> bytes [10, 0, 0, 0]
  assert_eq_int(state, bytes[12], 10, "T1.2_19", "Bound byte 0 == 10")
  assert_eq_int(state, bytes[13], 0, "T1.2_20", "Bound byte 1 == 0")
  assert_eq_int(state, bytes[14], 0, "T1.2_21", "Bound byte 2 == 0")
  assert_eq_int(state, bytes[15], 0, "T1.2_22", "Bound byte 3 == 0")

  @! String Packing Test for Entry Point Names
  packed_str = spirv_pack_string("main")
  @! "main\0\0\0\0" packed into words: 'm'=109, 'a'=97, 'i'=105, 'n'=110
  expected_first_str_word = 109 | (97 * 256) | (105 * 65536) | (110 * 16777216)
  assert_eq_int(state, packed_str[0], expected_first_str_word, "T1.2_23", "spirv_pack_string('main') first word correctly packs 'main'")
  assert_eq_int(state, packed_str[1], 0, "T1.2_24", "spirv_pack_string('main') second word is null terminator word")
@end

@! ============================================================================
@! 3. TIER 2: SPIR-V INSTRUCTION SET EMISSION SPECIFICATION
@! ============================================================================

@fn test_spirv_type_and_function_instructions(state)
  println("\n▶ Tier 2.1: SPIR-V Type System & Function Emission")

  emitter = spirv_emitter_new()
  emitter = spirv_emit_header(emitter, 30)

  @! OpCapability
  emitter = spirv_emit_capability(emitter, CAP_SHADER())
  assert_eq_int(state, OP_CAPABILITY(), 17, "T2.1_01", "OP_CAPABILITY opcode is 17")
  assert_eq_int(state, CAP_SHADER(), 1, "T2.1_02", "CAP_SHADER is 1")
  assert_eq_int(state, CAP_KERNEL(), 6, "T2.1_03", "CAP_KERNEL is 6")
  assert_eq_int(state, CAP_FLOAT64(), 9, "T2.1_04", "CAP_FLOAT64 is 9")
  assert_eq_int(state, CAP_INT64(), 11, "T2.1_05", "CAP_INT64 is 11")

  @! OpMemoryModel
  emitter = spirv_emit_memory_model(emitter, ADDR_LOGICAL(), MEM_GLSL450())
  assert_eq_int(state, OP_MEMORY_MODEL(), 14, "T2.1_06", "OP_MEMORY_MODEL opcode is 14")
  assert_eq_int(state, ADDR_LOGICAL(), 0, "T2.1_07", "ADDR_LOGICAL is 0")
  assert_eq_int(state, MEM_GLSL450(), 1, "T2.1_08", "MEM_GLSL450 is 1")
  assert_eq_int(state, MEM_VULKAN(), 3, "T2.1_09", "MEM_VULKAN is 3")

  @! OpEntryPoint
  emitter = spirv_emit_entry_point(emitter, EXEC_GLCOMPUTE(), 1, "main", [])
  assert_eq_int(state, OP_ENTRY_POINT(), 15, "T2.1_10", "OP_ENTRY_POINT opcode is 15")
  assert_eq_int(state, EXEC_GLCOMPUTE(), 5, "T2.1_11", "EXEC_GLCOMPUTE is 5")
  assert_eq_int(state, EXEC_VERTEX(), 0, "T2.1_12", "EXEC_VERTEX is 0")
  assert_eq_int(state, EXEC_FRAGMENT(), 4, "T2.1_13", "EXEC_FRAGMENT is 4")

  @! OpExecutionMode LocalSize 64, 1, 1
  emitter = spirv_emit_execution_mode(emitter, 1, EXEC_MODE_LOCAL_SIZE(), 64, 1, 1)
  assert_eq_int(state, OP_EXECUTION_MODE(), 16, "T2.1_14", "OP_EXECUTION_MODE opcode is 16")
  assert_eq_int(state, EXEC_MODE_LOCAL_SIZE(), 17, "T2.1_15", "EXEC_MODE_LOCAL_SIZE is 17")

  @! OpTypeVoid (ID 2)
  emitter = spirv_emit_type_void(emitter, 2)
  assert_eq_int(state, OP_TYPE_VOID(), 19, "T2.1_16", "OP_TYPE_VOID opcode is 19")

  @! OpTypeBool (ID 3)
  emitter = spirv_emit_type_bool(emitter, 3)
  assert_eq_int(state, OP_TYPE_BOOL(), 20, "T2.1_17", "OP_TYPE_BOOL opcode is 20")

  @! OpTypeInt (ID 4: 32-bit signed, ID 5: 64-bit unsigned)
  emitter = spirv_emit_type_int(emitter, 4, 32, 1)
  emitter = spirv_emit_type_int(emitter, 5, 64, 0)
  assert_eq_int(state, OP_TYPE_INT(), 21, "T2.1_18", "OP_TYPE_INT opcode is 21")

  @! OpTypeFloat (ID 6: 32-bit float, ID 7: 64-bit float)
  emitter = spirv_emit_type_float(emitter, 6, 32)
  emitter = spirv_emit_type_float(emitter, 7, 64)
  assert_eq_int(state, OP_TYPE_FLOAT(), 22, "T2.1_19", "OP_TYPE_FLOAT opcode is 22")

  @! OpTypeVector (ID 8: vec4 of float ID 6)
  emitter = spirv_emit_type_vector(emitter, 8, 6, 4)
  assert_eq_int(state, OP_TYPE_VECTOR(), 23, "T2.1_20", "OP_TYPE_VECTOR opcode is 23")

  @! OpTypeRuntimeArray (ID 9: array of float ID 6)
  emitter = spirv_emit_type_runtime_array(emitter, 9, 6)
  assert_eq_int(state, OP_TYPE_RUNTIME_ARRAY(), 29, "T2.1_21", "OP_TYPE_RUNTIME_ARRAY opcode is 29")

  @! OpTypeStruct (ID 10: struct containing ID 4 and ID 6)
  emitter = spirv_emit_type_struct(emitter, 10, [4, 6])
  assert_eq_int(state, OP_TYPE_STRUCT(), 30, "T2.1_22", "OP_TYPE_STRUCT opcode is 30")

  @! OpTypePointer (ID 11: Function storage of ID 4, ID 12: StorageBuffer of ID 6)
  emitter = spirv_emit_type_pointer(emitter, 11, STORAGE_FUNCTION(), 4)
  emitter = spirv_emit_type_pointer(emitter, 12, STORAGE_STORAGE_BUFFER(), 6)
  assert_eq_int(state, OP_TYPE_POINTER(), 32, "T2.1_23", "OP_TYPE_POINTER opcode is 32")
  assert_eq_int(state, STORAGE_FUNCTION(), 7, "T2.1_24", "STORAGE_FUNCTION storage class is 7")
  assert_eq_int(state, STORAGE_STORAGE_BUFFER(), 12, "T2.1_25", "STORAGE_STORAGE_BUFFER storage class is 12")
  assert_eq_int(state, STORAGE_UNIFORM(), 2, "T2.1_26", "STORAGE_UNIFORM storage class is 2")
  assert_eq_int(state, STORAGE_WORKGROUP(), 4, "T2.1_27", "STORAGE_WORKGROUP storage class is 4")

  @! OpTypeFunction (ID 13: void -> void)
  emitter = spirv_emit_type_function(emitter, 13, 2, [])
  assert_eq_int(state, OP_TYPE_FUNCTION(), 33, "T2.1_28", "OP_TYPE_FUNCTION opcode is 33")

  @! Function Definition: OpFunction, OpLabel, OpReturn, OpFunctionEnd
  emitter = spirv_emit_function(emitter, 2, 1, 0, 13)
  assert_eq_int(state, OP_FUNCTION(), 54, "T2.1_29", "OP_FUNCTION opcode is 54")

  emitter = spirv_emit_label(emitter, 14)
  assert_eq_int(state, OP_LABEL(), 248, "T2.1_30", "OP_LABEL opcode is 248")

  emitter = spirv_emit_return(emitter)
  assert_eq_int(state, OP_RETURN(), 253, "T2.1_31", "OP_RETURN opcode is 253")

  emitter = spirv_emit_function_end(emitter)
  assert_eq_int(state, OP_FUNCTION_END(), 56, "T2.1_32", "OP_FUNCTION_END opcode is 56")

  @! Verify that word stream and byte stream are valid
  words = emitter.words
  assert_true(state, words.len() > 20, "T2.1_33", "Full SPIR-V emitter produces non-trivial instruction stream (>20 words)")
  raw_bytes = spirv_words_to_bytes(words)
  assert_eq_int(state, raw_bytes.len(), words.len() * 4, "T2.1_34", "Serialized instruction bytes match word stream count")
@end

@fn test_spirv_variables_and_decorations(state)
  println("\n▶ Tier 2.2: SPIR-V Variables, Memory Operations & Decorations")

  emitter = spirv_emitter_new()
  emitter = spirv_emit_header(emitter, 25)

  @! OpDecorate (Binding = 0, DescriptorSet = 0)
  assert_eq_int(state, OP_DECORATE(), 71, "T2.2_01", "OP_DECORATE opcode is 71")
  assert_eq_int(state, OP_MEMBER_DECORATE(), 72, "T2.2_02", "OP_MEMBER_DECORATE opcode is 72")
  assert_eq_int(state, DECORATION_BINDING(), 33, "T2.2_03", "DECORATION_BINDING is 33")
  assert_eq_int(state, DECORATION_DESCRIPTOR_SET(), 34, "T2.2_04", "DECORATION_DESCRIPTOR_SET is 34")
  assert_eq_int(state, DECORATION_OFFSET(), 35, "T2.2_05", "DECORATION_OFFSET is 35")
  assert_eq_int(state, DECORATION_BUFFER_BLOCK(), 3, "T2.2_06", "DECORATION_BUFFER_BLOCK is 3")

  emitter = spirv_emit_decorate(emitter, 1, DECORATION_DESCRIPTOR_SET(), [0])
  emitter = spirv_emit_decorate(emitter, 1, DECORATION_BINDING(), [0])
  emitter = spirv_emit_member_decorate(emitter, 10, 0, DECORATION_OFFSET(), [0])

  @! OpVariable
  assert_eq_int(state, OP_VARIABLE(), 59, "T2.2_07", "OP_VARIABLE opcode is 59")
  emitter = spirv_emit_variable(emitter, 12, 1, STORAGE_STORAGE_BUFFER(), 0)

  @! OpLoad & OpStore & OpAccessChain
  assert_eq_int(state, OP_LOAD(), 61, "T2.2_08", "OP_LOAD opcode is 61")
  assert_eq_int(state, OP_STORE(), 62, "T2.2_09", "OP_STORE opcode is 62")
  assert_eq_int(state, OP_ACCESS_CHAIN(), 65, "T2.2_10", "OP_ACCESS_CHAIN opcode is 65")

  emitter = spirv_emit_access_chain(emitter, 12, 15, 1, [0, 1])
  emitter = spirv_emit_load(emitter, 6, 16, 15)
  emitter = spirv_emit_store(emitter, 15, 16)

  @! Arithmetic Opcodes
  assert_eq_int(state, OP_IADD(), 128, "T2.2_11", "OP_IADD opcode is 128")
  assert_eq_int(state, OP_FADD(), 129, "T2.2_12", "OP_FADD opcode is 129")
  assert_eq_int(state, OP_ISUB(), 130, "T2.2_13", "OP_ISUB opcode is 130")
  assert_eq_int(state, OP_FSUB(), 131, "T2.2_14", "OP_FSUB opcode is 131")
  assert_eq_int(state, OP_IMUL(), 132, "T2.2_15", "OP_IMUL opcode is 132")
  assert_eq_int(state, OP_FMUL(), 133, "T2.2_16", "OP_FMUL opcode is 133")

  @! Builtin Decorators
  assert_eq_int(state, BUILTIN_POSITION(), 0, "T2.2_17", "BUILTIN_POSITION is 0")
  assert_eq_int(state, BUILTIN_GLOBAL_INVOCATION_ID(), 28, "T2.2_18", "BUILTIN_GLOBAL_INVOCATION_ID is 28")
  assert_eq_int(state, BUILTIN_LOCAL_INVOCATION_ID(), 27, "T2.2_19", "BUILTIN_LOCAL_INVOCATION_ID is 27")
  assert_eq_int(state, BUILTIN_WORKGROUP_ID(), 26, "T2.2_20", "BUILTIN_WORKGROUP_ID is 26")
  assert_eq_int(state, BUILTIN_NUM_WORKGROUPS(), 24, "T2.2_21", "BUILTIN_NUM_WORKGROUPS is 24")
@end

@! ============================================================================
@! 4. TIER 3: COMPUTE KERNEL BUILDER & MULTI-STAGE SHADER SUITE
@! ============================================================================

@fn test_spirv_compute_kernel_builder(state)
  println("\n▶ Tier 3.1: spirv_build_compute_kernel Binary Generation")

  k_name = "maya_vector_add_kernel"
  kernel_emitter = spirv_build_compute_kernel(k_name, 64, 1, 1)

  @! Assert Header
  assert_eq_int(state, kernel_emitter.words[0], SPIRV_MAGIC(), "T3.1_01", "Compute kernel header magic matches SPIRV_MAGIC")
  assert_eq_int(state, kernel_emitter.words[1], SPIRV_VERSION_1_0(), "T3.1_02", "Compute kernel version matches 1.0 (65536)")
  assert_eq_int(state, kernel_emitter.words[2], SPIRV_GENERATOR_MAYA(), "T3.1_03", "Compute kernel generator matches Maya (4919)")
  assert_eq_int(state, kernel_emitter.words[3], 12, "T3.1_04", "Compute kernel ID bound is 12")
  assert_eq_int(state, kernel_emitter.words[4], 0, "T3.1_05", "Compute kernel schema is 0")

  @! Assert Opcodes Present in Stream
  words = kernel_emitter.words
  found_capability = 0
  found_mem_model = 0
  found_entry_point = 0
  found_exec_mode = 0
  found_type_void = 0
  found_type_fn = 0
  found_type_int = 0
  found_type_float = 0
  found_type_pointer = 0
  found_fn = 0
  found_label = 0
  found_return = 0
  found_fn_end = 0

  idx = 5
  @while idx < words.len()
    inst_word = words[idx]
    opcode = inst_word & 65535
    word_count = (inst_word / 65536) & 65535

    @if opcode == OP_CAPABILITY() found_capability = 1 @end
    @if opcode == OP_MEMORY_MODEL() found_mem_model = 1 @end
    @if opcode == OP_ENTRY_POINT() found_entry_point = 1 @end
    @if opcode == OP_EXECUTION_MODE() found_exec_mode = 1 @end
    @if opcode == OP_TYPE_VOID() found_type_void = 1 @end
    @if opcode == OP_TYPE_FUNCTION() found_type_fn = 1 @end
    @if opcode == OP_TYPE_INT() found_type_int = 1 @end
    @if opcode == OP_TYPE_FLOAT() found_type_float = 1 @end
    @if opcode == OP_TYPE_POINTER() found_type_pointer = 1 @end
    @if opcode == OP_FUNCTION() found_fn = 1 @end
    @if opcode == OP_LABEL() found_label = 1 @end
    @if opcode == OP_RETURN() found_return = 1 @end
    @if opcode == OP_FUNCTION_END() found_fn_end = 1 @end

    idx = idx + word_count
  @end

  assert_eq_int(state, found_capability, 1, "T3.1_06", "OpCapability (Shader) emitted in compute kernel")
  assert_eq_int(state, found_mem_model, 1, "T3.1_07", "OpMemoryModel (Logical, GLSL450) emitted in compute kernel")
  assert_eq_int(state, found_entry_point, 1, "T3.1_08", "OpEntryPoint (GLCompute) emitted in compute kernel")
  assert_eq_int(state, found_exec_mode, 1, "T3.1_09", "OpExecutionMode (LocalSize 64,1,1) emitted in compute kernel")
  assert_eq_int(state, found_type_void, 1, "T3.1_10", "OpTypeVoid emitted in compute kernel")
  assert_eq_int(state, found_type_fn, 1, "T3.1_11", "OpTypeFunction emitted in compute kernel")
  assert_eq_int(state, found_type_int, 1, "T3.1_12", "OpTypeInt emitted in compute kernel")
  assert_eq_int(state, found_type_float, 1, "T3.1_13", "OpTypeFloat emitted in compute kernel")
  assert_eq_int(state, found_type_pointer, 1, "T3.1_14", "OpTypePointer emitted in compute kernel")
  assert_eq_int(state, found_fn, 1, "T3.1_15", "OpFunction emitted in compute kernel")
  assert_eq_int(state, found_label, 1, "T3.1_16", "OpLabel emitted in compute kernel")
  assert_eq_int(state, found_return, 1, "T3.1_17", "OpReturn emitted in compute kernel")
  assert_eq_int(state, found_fn_end, 1, "T3.1_18", "OpFunctionEnd emitted in compute kernel")

  k_bytes = spirv_words_to_bytes(words)
  assert_true(state, k_bytes.len() >= 20, "T3.1_19", "Compute kernel byte stream size >= 20 bytes")
  assert_eq_int(state, k_bytes.len(), words.len() * 4, "T3.1_20", "Compute kernel byte stream size equals words * 4")
@end

@fn test_multi_stage_shader_pipeline(state)
  println("\n▶ Tier 3.2: Multi-Stage Shader Compilation & Uniform Bindings")

  @! 1. Multi-stage Vertex + Fragment Program
  vert_code = "@fn vs_main() -> void { ... }"
  frag_code = "@fn fs_main() -> void { ... }"
  prog = shader_new(vert_code, frag_code)

  assert_eq_str(state, prog.vert, vert_code, "T3.2_01", "Vertex shader source preserved")
  assert_eq_str(state, prog.frag, frag_code, "T3.2_02", "Fragment shader source preserved")
  assert_eq_int(state, prog.is_compiled, 0, "T3.2_03", "Initial program is_compiled is 0")
  assert_eq_int(state, prog.is_bound, 0, "T3.2_04", "Initial program is_bound is 0")

  @! Uniforms & Bindings
  prog = shader_set_uniform(prog, "u_model_matrix", 1)
  prog = shader_set_uniform(prog, "u_light_pos", 2)
  assert_eq_int(state, prog.uniforms.len(), 2, "T3.2_05", "Two uniforms registered to shader program")
  u0 = prog.uniforms[0]
  assert_eq_str(state, u0.name, "u_model_matrix", "T3.2_06", "Uniform 0 name is u_model_matrix")
  assert_eq_int(state, u0.binding, 0, "T3.2_07", "Uniform 0 binding index is 0")
  u1 = prog.uniforms[1]
  assert_eq_str(state, u1.name, "u_light_pos", "T3.2_08", "Uniform 1 name is u_light_pos")
  assert_eq_int(state, u1.binding, 1, "T3.2_09", "Uniform 1 binding index is 1")

  prog = shader_add_binding(prog, 0, "UNIFORM_BUFFER", 1)
  prog = shader_add_binding(prog, 1, "STORAGE_BUFFER", 4)
  assert_eq_int(state, prog.bindings.len(), 2, "T3.2_10", "Two descriptor bindings registered")

  @! Compile Program
  compile_res = shader_compile(prog)
  assert_eq_int(state, compile_res, 1, "T3.2_11", "shader_compile returns 1 (success)")
  assert_eq_int(state, prog.is_compiled, 1, "T3.2_12", "prog.is_compiled updated to 1")
  assert_eq_int(state, prog.vert_stage.is_compiled, 1, "T3.2_13", "Vertex stage compiled flag set to 1")
  assert_eq_int(state, prog.frag_stage.is_compiled, 1, "T3.2_14", "Fragment stage compiled flag set to 1")

  vert_bytes = shader_get_spirv_bytes(prog, "VERTEX")
  frag_bytes = shader_get_spirv_bytes(prog, "FRAGMENT")
  assert_true(state, vert_bytes.len() > 0, "T3.2_15", "Vertex SPIR-V bytes emitted successfully")
  assert_true(state, frag_bytes.len() > 0, "T3.2_16", "Fragment SPIR-V bytes emitted successfully")

  @! Bind and Run
  assert_eq_int(state, shader_bind(prog), 1, "T3.2_17", "shader_bind returns 1")
  assert_eq_int(state, prog.is_bound, 1, "T3.2_18", "prog.is_bound updated to 1")
  assert_eq_int(state, shader_run(prog, [0, 1, 2]), 1, "T3.2_19", "shader_run execution returns 1")

  @! 2. Compute Shader Program
  comp_code = "@fn cs_main() -> void { ... }"
  comp_prog = shader_compute_new(comp_code)
  assert_eq_str(state, comp_prog.comp, comp_code, "T3.2_20", "Compute shader source preserved")
  assert_eq_int(state, shader_compile(comp_prog), 1, "T3.2_21", "Compute shader compilation returns 1")
  assert_eq_int(state, comp_prog.comp_stage.is_compiled, 1, "T3.2_22", "Compute stage compiled flag set to 1")
  comp_bytes = shader_get_spirv_bytes(comp_prog, "COMPUTE")
  assert_true(state, comp_bytes.len() > 0, "T3.2_23", "Compute SPIR-V bytes emitted successfully")
@end

@! ============================================================================
@! 5. TIER 4: WORKGROUP CALCULATION, PIPELINE DISPATCH & @gpu DIRECTIVE
@! ============================================================================

@fn test_gpu_workgroup_math_and_dispatch(state)
  println("\n▶ Tier 4.1: Workgroup Math & Compute Pipeline Dispatch")

  @! Workgroup Math Formula: (threads + 63) / 64
  @! Thread counts and expected workgroups:
  @! 1 thread -> (1 + 63) / 64 = 1
  @! 63 threads -> (63 + 63) / 64 = 1
  @! 64 threads -> (64 + 63) / 64 = 1
  @! 65 threads -> (65 + 63) / 64 = 2
  @! 128 threads -> (128 + 63) / 64 = 2
  @! 129 threads -> (129 + 63) / 64 = 3
  @! 256 threads -> (256 + 63) / 64 = 4
  @! 500 threads -> (500 + 63) / 64 = 8
  @! 1024 threads -> (1024 + 63) / 64 = 16
  @! 65536 threads -> (65536 + 63) / 64 = 1024

  assert_eq_int(state, (1 + 63) / 64, 1, "T4.1_01", "1 thread maps to 1 workgroup")
  assert_eq_int(state, (63 + 63) / 64, 1, "T4.1_02", "63 threads map to 1 workgroup")
  assert_eq_int(state, (64 + 63) / 64, 1, "T4.1_03", "64 threads map to 1 workgroup (exact 1x)")
  assert_eq_int(state, (65 + 63) / 64, 2, "T4.1_04", "65 threads map to 2 workgroups (boundary +1)")
  assert_eq_int(state, (128 + 63) / 64, 2, "T4.1_05", "128 threads map to 2 workgroups (exact 2x)")
  assert_eq_int(state, (129 + 63) / 64, 3, "T4.1_06", "129 threads map to 3 workgroups")
  assert_eq_int(state, (256 + 63) / 64, 4, "T4.1_07", "256 threads map to 4 workgroups (exact 4x)")
  assert_eq_int(state, (500 + 63) / 64, 8, "T4.1_08", "500 threads map to 8 workgroups")
  assert_eq_int(state, (1024 + 63) / 64, 16, "T4.1_09", "1024 threads map to 16 workgroups")
  assert_eq_int(state, (65536 + 63) / 64, 1024, "T4.1_10", "65536 threads map to 1024 workgroups")

  @! Compute Pipeline Layout and Dispatch Object
  bgl0 = bind_group_layout_entry_new(0, 4, "STORAGE_BUFFER")
  bgl1 = bind_group_layout_entry_new(1, 4, "STORAGE_BUFFER")
  layout = compute_pipeline_layout_new([[bgl0, bgl1]], [], 64, 1, 1)

  assert_eq_int(state, layout.workgroup_size_x, 64, "T4.1_11", "Pipeline Layout local size X is 64")
  assert_eq_int(state, layout.workgroup_size_y, 1, "T4.1_12", "Pipeline Layout local size Y is 1")
  assert_eq_int(state, layout.workgroup_size_z, 1, "T4.1_13", "Pipeline Layout local size Z is 1")
  assert_eq_int(state, layout.bind_groups.len(), 1, "T4.1_14", "Pipeline Layout bind group count is 1")

  kernel_em = spirv_build_compute_kernel("gpu_matrix_mult", 64, 1, 1)
  pipeline = gpu_compute_pipeline_new(layout, kernel_em.words, "gpu_matrix_mult")
  assert_eq_int(state, pipeline.is_compiled, 0, "T4.1_15", "Pipeline initially uncompiled")

  pipeline = gpu_compute_pipeline_compile(pipeline)
  assert_eq_int(state, pipeline.is_compiled, 1, "T4.1_16", "Pipeline compile sets is_compiled = 1")
  assert_eq_str(state, pipeline.entry_point, "gpu_matrix_mult", "T4.1_17", "Pipeline entry point matches 'gpu_matrix_mult'")

  @! Dispatch Compute Grid
  target_threads = 512
  workgroups = (target_threads + 63) / 64
  pipeline = gpu_dispatch_compute(pipeline, workgroups, 1, 1)

  assert_eq_int(state, pipeline.dispatch_x, 8, "T4.1_18", "gpu_dispatch_compute records dispatch_x = 8 workgroups")
  assert_eq_int(state, pipeline.dispatch_y, 1, "T4.1_19", "gpu_dispatch_compute records dispatch_y = 1 workgroup")
  assert_eq_int(state, pipeline.dispatch_z, 1, "T4.1_20", "gpu_dispatch_compute records dispatch_z = 1 workgroup")
@end

@fn test_gpu_task_and_directive_runtime(state)
  println("\n▶ Tier 4.2: @gpu Task Lifecycle & Kernel Execution")

  @! 1. Task Instantiation
  task_data = [10, 20, 30, 40, 50]
  threads = 128
  task = gpu_task_new("vector_scale_2x", task_data, threads)

  assert_eq_str(state, task.gt_name, "vector_scale_2x", "T4.2_01", "GpuTask name matches")
  assert_eq_int(state, task.gt_threads, 128, "T4.2_02", "GpuTask thread count matches 128")
  assert_eq_int(state, task.gt_status, 0, "T4.2_03", "Initial GpuTask status is 0 (pending)")
  assert_eq_int(state, task.gt_pipeline.is_compiled, 1, "T4.2_04", "GpuTask pipeline is pre-compiled")
  assert_true(state, task.gt_spirv_words.len() > 0, "T4.2_05", "GpuTask contains SPIR-V words")
  assert_eq_int(state, gpu_task_get_spirv_magic(task), SPIRV_MAGIC(), "T4.2_06", "gpu_task_get_spirv_magic returns SPIRV_MAGIC")

  @! 2. Kernel Map Execution
  task = gpu_map_kernel(task, 5)
  assert_eq_int(state, task.gt_status, 1, "T4.2_07", "gpu_map_kernel marks status as 1 (completed)")
  assert_eq_int(state, task.gt_output.len(), 5, "T4.2_08", "Task output buffer length matches input")
  assert_eq_int(state, task.gt_output[0], 15, "T4.2_09", "task.gt_output[0] == 10 + 5 = 15")
  assert_eq_int(state, task.gt_output[1], 25, "T4.2_10", "task.gt_output[1] == 20 + 5 = 25")
  assert_eq_int(state, task.gt_output[2], 35, "T4.2_11", "task.gt_output[2] == 30 + 5 = 35")
  assert_eq_int(state, task.gt_output[3], 45, "T4.2_12", "task.gt_output[3] == 40 + 5 = 45")
  assert_eq_int(state, task.gt_output[4], 55, "T4.2_13", "task.gt_output[4] == 50 + 5 = 55")

  @! 3. Kernel Reduction Execution
  red_sum = gpu_reduce_kernel(task)
  assert_eq_int(state, red_sum, 150, "T4.2_14", "gpu_reduce_kernel sums [10,20,30,40,50] to 150")

  @! 4. Complete gpu_launch Pipeline
  launched_task = gpu_launch("tensor_add", [100, 200, 300], 256)
  assert_eq_int(state, launched_task.gt_status, 1, "T4.2_15", "gpu_launch completes with status = 1")
  assert_eq_int(state, launched_task.gt_pipeline.dispatch_x, 4, "T4.2_16", "gpu_launch dispatches 256/64 = 4 workgroups")
  assert_eq_int(state, launched_task.gt_output.len(), 3, "T4.2_17", "gpu_launch produces correct output length")
  assert_eq_int(state, launched_task.gt_output[0], 100, "T4.2_18", "gpu_launch output[0] matches expected")
  assert_eq_int(state, launched_task.gt_output[1], 200, "T4.2_19", "gpu_launch output[1] matches expected")
  assert_eq_int(state, launched_task.gt_output[2], 300, "T4.2_20", "gpu_launch output[2] matches expected")

  waited_task = gpu_wait(launched_task)
  assert_eq_int(state, waited_task.gt_status, 1, "T4.2_21", "gpu_wait resolves task status = 1")

  @! 5. Parallel For Dispatch
  pfor_results = gpu_parallel_for(8, 1000)
  assert_eq_int(state, pfor_results.len(), 8, "T4.2_22", "gpu_parallel_for generates 8 items")
  assert_eq_int(state, pfor_results[0], 1000, "T4.2_23", "pfor_results[0] == 1000")
  assert_eq_int(state, pfor_results[7], 1007, "T4.2_24", "pfor_results[7] == 1007")
@end

@fn test_gpu_buffer_primitives(state)
  println("\n▶ Tier 4.3: GPU Buffer & Parallel Operations")

  @! 1. Buffer Allocation and Fill
  buf_a = gpu_buffer_new(8)
  assert_eq_int(state, buf_a.size, 8, "T4.3_01", "GpuBuffer size is 8")
  assert_eq_str(state, buf_a.device, "CPU", "T4.3_02", "GpuBuffer device is CPU")
  assert_eq_str(state, buf_a.usage, "STORAGE_BUFFER", "T4.3_03", "GpuBuffer default usage is STORAGE_BUFFER")
  assert_eq_int(state, buf_a.binding, 0, "T4.3_04", "GpuBuffer default binding is 0")

  buf_a = gpu_buffer_fill(buf_a, 7)
  assert_eq_int(state, buf_a.data[0], 7, "T4.3_05", "gpu_buffer_fill populates index 0")
  assert_eq_int(state, buf_a.data[7], 7, "T4.3_06", "gpu_buffer_fill populates index 7")

  @! 2. Buffer Copy
  buf_b = gpu_buffer_new(8)
  buf_b = gpu_buffer_copy(buf_a, buf_b)
  assert_eq_int(state, buf_b.data[0], 7, "T4.3_07", "gpu_buffer_copy copies index 0")
  assert_eq_int(state, buf_b.data[7], 7, "T4.3_08", "gpu_buffer_copy copies index 7")

  @! 3. Parallel Vector Arithmetic
  buf_c = gpu_buffer_new(8)
  buf_c = gpu_buffer_fill(buf_c, 3)

  buf_sum = gpu_parallel_add(buf_a, buf_c)
  assert_eq_int(state, buf_sum.data[0], 10, "T4.3_09", "gpu_parallel_add: 7 + 3 = 10 at index 0")
  assert_eq_int(state, buf_sum.data[7], 10, "T4.3_10", "gpu_parallel_add: 7 + 3 = 10 at index 7")

  buf_prod = gpu_parallel_mul(buf_a, buf_c)
  assert_eq_int(state, buf_prod.data[0], 21, "T4.3_11", "gpu_parallel_mul: 7 * 3 = 21 at index 0")
  assert_eq_int(state, buf_prod.data[7], 21, "T4.3_12", "gpu_parallel_mul: 7 * 3 = 21 at index 7")

  @! 4. Reduction Sum
  total_sum = gpu_reduce(buf_sum, 0)
  @! 8 elements of value 10 -> total 80
  assert_eq_int(state, total_sum, 80, "T4.3_13", "gpu_reduce calculates total sum = 80")

  @! 5. Sync & Usage Buffer
  custom_buf = gpu_buffer_with_usage(16, "UNIFORM_BUFFER", 2)
  assert_eq_int(state, custom_buf.size, 16, "T4.3_14", "gpu_buffer_with_usage size is 16")
  assert_eq_str(state, custom_buf.usage, "UNIFORM_BUFFER", "T4.3_15", "gpu_buffer_with_usage usage is UNIFORM_BUFFER")
  assert_eq_int(state, custom_buf.binding, 2, "T4.3_16", "gpu_buffer_with_usage binding is 2")
  assert_eq_int(state, gpu_sync(), 1, "T4.3_17", "gpu_sync returns 1")
@end

@! ============================================================================
@! 6. MAIN TEST SUITE RUNNER
@! ============================================================================

@fn main()
  println("=================================================================")
  println("  MAYA UNIVERSAL ARCHITECTURE: GPU COMPUTE & SPIR-V E2E SUITE    ")
  println("=================================================================")

  state = test_state_new()

  @! Execute all test tiers
  test_spirv_header_and_constants(state)
  test_spirv_word_encoding_and_endianness(state)
  test_spirv_type_and_function_instructions(state)
  test_spirv_variables_and_decorations(state)
  test_spirv_compute_kernel_builder(state)
  test_multi_stage_shader_pipeline(state)
  test_gpu_workgroup_math_and_dispatch(state)
  test_gpu_task_and_directive_runtime(state)
  test_gpu_buffer_primitives(state)

  println("\n=================================================================")
  println("TEST SUMMARY:")
  println("  Total assertions: " + state.total.to_str())
  println("  Passed:           " + state.passed.to_str())
  println("  Failed:           " + state.failed.to_str())
  println("=================================================================")

  @if state.failed == 0
    println("🎉 ALL GPU COMPUTE & SPIR-V ACCELERATOR E2E TESTS PASSED (100%)!")
    return 0
  @else
    println("❌ SOME TESTS FAILED!")
    return 1
  @end
@end
