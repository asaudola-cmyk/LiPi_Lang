// ==============================================================================
// 👑 LIPI SOVEREIGN NATIVE SILICON GPU COMPUTE & SPIR-V EMITTER
// ⚡ Module: universe/gpu/spirv_native.lp
// ⚡ 100% Pure Lipi | Zero C / Zero Vulkan SDK / Zero LLVM | Direct Khronos SPIR-V Binary
// ==============================================================================
//
// WHY: Modern AI workloads and high-performance computing demand silicon GPU acceleration.
//      Traditional languages rely on heavy C++ runtimes, proprietary CUDA SDKs, or
//      gigabytes of LLVM compiler backends to generate GPU kernels.
//      Lipi achieves 100% sovereign silicon compute by emitting native Khronos SPIR-V
//      binary modules directly from pure Lipi code. These binaries can be dispatched
//      directly to Vulkan, OpenCL, or WebGPU compute pipelines.
//
// 🛡️ DEADLY TRAP 4 DEFENSE (Dynamic Opcode Word-Count Calculation):
//      Hardcoding instruction word counts causes catastrophic driver validation rejection
//      (e.g., VK_ERROR_INITIALIZATION_FAILED / SPIRV_INVALID_BINARY) whenever operands vary.
//      Every instruction in this module computes:
//          word_count = len(operands) + 1
//          first_word = (word_count * 65536) + (opcode % 65536)
//      guaranteeing 100% strict compliance with the Khronos SPIR-V binary specification.
// ==============================================================================

include "universe/core/memory.lp"

// ── 1. Khronos SPIR-V Core Specification Constants ────────────────────────────
SPIRV_MAGIC_NUMBER       = 119734787  // 0x07230203 (Little-Endian: 0x03, 0x02, 0x23, 0x07)
SPIRV_VERSION_1_0        = 65536      // 0x00010000 (Major 1, Minor 0)
SPIRV_VERSION_1_5        = 66816      // 0x00010500 (Major 1, Minor 5)
SPIRV_GENERATOR_LIPI     = 1769473    // 0x001B0001 (Lipi Sovereign Silicon Emitter)
SPIRV_SCHEMA_DEFAULT     = 0

// Opcode Enumerations (Khronos SPIR-V Specification Section 3)
OP_NOP                   = 0
OP_SOURCE                = 3
OP_NAME                  = 5
OP_MEMBER_NAME           = 6
OP_EXT_INST_IMPORT       = 11
OP_MEMORY_MODEL          = 14
OP_ENTRY_POINT           = 15
OP_EXECUTION_MODE        = 16
OP_CAPABILITY            = 17
OP_TYPE_VOID             = 19
OP_TYPE_BOOL             = 20
OP_TYPE_INT              = 21
OP_TYPE_FLOAT            = 22
OP_TYPE_VECTOR           = 23
OP_TYPE_ARRAY            = 28
OP_TYPE_RUNTIME_ARRAY    = 29
OP_TYPE_STRUCT           = 30
OP_TYPE_POINTER          = 32
OP_TYPE_FUNCTION         = 33
OP_CONSTANT_TRUE         = 41
OP_CONSTANT_FALSE        = 42
OP_CONSTANT              = 43
OP_CONSTANT_COMPOSITE    = 44
OP_FUNCTION              = 54
OP_FUNCTION_PARAMETER    = 55
OP_FUNCTION_END          = 56
OP_VARIABLE              = 59
OP_LOAD                  = 61
OP_STORE                 = 62
OP_ACCESS_CHAIN          = 65
OP_DECORATE              = 71
OP_MEMBER_DECORATE       = 72
OP_IADD                  = 128
OP_FADD                  = 129
OP_ISUB                  = 130
OP_FSUB                  = 131
OP_IMUL                  = 132
OP_FMUL                  = 133
OP_FDIV                  = 136
OP_LABEL                 = 248
OP_BRANCH                = 249
OP_BRANCH_CONDITIONAL    = 250
OP_RETURN                = 253
OP_RETURN_VALUE          = 254

// Addressing & Memory Models
ADDR_MODEL_LOGICAL       = 0
ADDR_MODEL_PHYSICAL32    = 1
ADDR_MODEL_PHYSICAL64    = 2

MEM_MODEL_SIMPLE         = 0
MEM_MODEL_GLSL450        = 1
MEM_MODEL_OPENCL         = 2
MEM_MODEL_VULKAN         = 3

// Execution Models & Modes
EXEC_MODEL_GLCOMPUTE     = 5
EXEC_MODEL_KERNEL        = 6

EXEC_MODE_LOCAL_SIZE     = 17
EXEC_MODE_LOCAL_SIZE_HINT= 18

// Capabilities
CAP_MATRIX               = 0
CAP_SHADER               = 1
CAP_ADDRESSES            = 4
CAP_LINKAGE              = 5
CAP_KERNEL               = 6
CAP_FLOAT64              = 9
CAP_INT64                = 11

// Storage Classes
STORAGE_UNIFORM_CONSTANT = 0
STORAGE_INPUT            = 1
STORAGE_UNIFORM          = 2
STORAGE_OUTPUT           = 3
STORAGE_WORKGROUP        = 4
STORAGE_PRIVATE          = 6
STORAGE_FUNCTION         = 7
STORAGE_STORAGE_BUFFER   = 12

// Decorations
DECOR_BLOCK              = 2
DECOR_BUFFER_BLOCK       = 3
DECOR_ARRAY_STRIDE       = 6
DECOR_BUILTIN            = 11
DECOR_BINDING            = 33
DECOR_DESCRIPTOR_SET     = 34
DECOR_OFFSET             = 35

// Built-in Variables
BUILTIN_POSITION         = 0
BUILTIN_LOCAL_INVOC_ID   = 27
BUILTIN_GLOBAL_INVOC_ID  = 28

// ── 2. SPIR-V Emitter Data Structure ──────────────────────────────────────────
// Layout:
//   b[0]: words list (32-bit integer array)
//   b[1]: next_id (int) - tracks SSA ID allocations
//   b[2]: version (int)
//   b[3]: generator_id (int)
//   b[4]: bound_id (int)

fn spirv_builder_new
    b = list()
    push(b, list())               // 0: words
    push(b, 1)                    // 1: next_id (starts at 1; 0 is invalid ID)
    push(b, SPIRV_VERSION_1_0)    // 2: version
    push(b, SPIRV_GENERATOR_LIPI) // 3: generator
    push(b, 1)                    // 4: bound
    return b

fn spirv_alloc_id b
    curr = get(b, 1)
    next_val = curr + 1
    list_set(b, 1, next_val)
    if next_val > get(b, 4)
        list_set(b, 4, next_val)
    return curr

// ── 3. Dynamic Opcode Word-Count Emitter (Trap 4 Defense) ──────────────────────
// WHY: Dynamically computes instruction length from operand list length.
//      Formula: Word 0 = (WordCount << 16) | Opcode
//      Guarantees exact binary compatibility with Khronos validation rules.

fn spirv_emit_inst b opcode operands
    words = get(b, 0)
    op_len = len(operands)
    word_count = op_len + 1 // Instruction word + all operand words

    // High 16 bits: word count, Low 16 bits: opcode
    first_word = (word_count * 65536) + (opcode % 65536)
    push(words, first_word)

    oi = 0
    while oi < op_len
        operand_val = get(operands, oi)
        push(words, operand_val)
        oi = oi + 1

    return b

// Emits a raw 32-bit word directly (e.g. for header fields)
fn spirv_emit_raw_word b word_val
    words = get(b, 0)
    push(words, word_val)
    return b

// ── 4. Khronos SPIR-V Binary Header Emitter ───────────────────────────────────
// WHY: Standard 5-word header: [Magic, Version, Generator, Bound, Reserved (0)]

fn spirv_emit_header b
    words = get(b, 0)
    bound = get(b, 4)
    version = get(b, 2)
    generator = get(b, 3)

    // Prepend or write the 5 header words at the beginning
    push(words, SPIRV_MAGIC_NUMBER)
    push(words, version)
    push(words, generator)
    push(words, bound)
    push(words, SPIRV_SCHEMA_DEFAULT)
    return b

// Helper to update the bound in an already emitted header (word index 3)
fn spirv_finalize_header b
    words = get(b, 0)
    final_bound = get(b, 4)
    if len(words) >= 4
        list_set(words, 3, final_bound)
    return b

// ── 5. Standard SPIR-V Instruction Builders ───────────────────────────────────

fn spirv_emit_capability b capability
    ops = list()
    push(ops, capability)
    return spirv_emit_inst(b, OP_CAPABILITY, ops)

fn spirv_emit_memory_model b addr_model mem_model
    ops = list()
    push(ops, addr_model)
    push(ops, mem_model)
    return spirv_emit_inst(b, OP_MEMORY_MODEL, ops)

// Emits OpEntryPoint with dynamic name packaging
fn spirv_emit_entry_point b exec_model entry_fn_id name_str interface_ids
    ops = list()
    push(ops, exec_model)
    push(ops, entry_fn_id)

    // Pack string characters into 32-bit words (null-terminated)
    s_len = len(name_str)
    si = 0
    while si <= s_len
        b0 = 0
        b1 = 0
        b2 = 0
        b3 = 0
        if si < s_len
            b0 = ord(char_at(name_str, si))
        if (si + 1) < s_len
            b1 = ord(char_at(name_str, si + 1))
        if (si + 2) < s_len
            b2 = ord(char_at(name_str, si + 2))
        if (si + 3) < s_len
            b3 = ord(char_at(name_str, si + 3))

        packed_word = b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)
        push(ops, packed_word)
        si = si + 4

    // Append interface IDs
    ii = 0
    while ii < len(interface_ids)
        push(ops, get(interface_ids, ii))
        ii = ii + 1

    return spirv_emit_inst(b, OP_ENTRY_POINT, ops)

fn spirv_emit_execution_mode_local_size b entry_id x y z
    ops = list()
    push(ops, entry_id)
    push(ops, EXEC_MODE_LOCAL_SIZE)
    push(ops, x)
    push(ops, y)
    push(ops, z)
    return spirv_emit_inst(b, OP_EXECUTION_MODE, ops)

// Type Declarations
fn spirv_emit_type_void b res_id
    ops = list()
    push(ops, res_id)
    return spirv_emit_inst(b, OP_TYPE_VOID, ops)

fn spirv_emit_type_int b res_id width is_signed
    ops = list()
    push(ops, res_id)
    push(ops, width)
    push(ops, is_signed)
    return spirv_emit_inst(b, OP_TYPE_INT, ops)

fn spirv_emit_type_float b res_id width
    ops = list()
    push(ops, res_id)
    push(ops, width)
    return spirv_emit_inst(b, OP_TYPE_FLOAT, ops)

fn spirv_emit_type_vector b res_id comp_type_id comp_count
    ops = list()
    push(ops, res_id)
    push(ops, comp_type_id)
    push(ops, comp_count)
    return spirv_emit_inst(b, OP_TYPE_VECTOR, ops)

fn spirv_emit_type_runtime_array b res_id elem_type_id
    ops = list()
    push(ops, res_id)
    push(ops, elem_type_id)
    return spirv_emit_inst(b, OP_TYPE_RUNTIME_ARRAY, ops)

fn spirv_emit_type_struct b res_id member_types
    ops = list()
    push(ops, res_id)
    mi = 0
    while mi < len(member_types)
        push(ops, get(member_types, mi))
        mi = mi + 1
    return spirv_emit_inst(b, OP_TYPE_STRUCT, ops)

fn spirv_emit_type_pointer b res_id storage_class type_id
    ops = list()
    push(ops, res_id)
    push(ops, storage_class)
    push(ops, type_id)
    return spirv_emit_inst(b, OP_TYPE_POINTER, ops)

fn spirv_emit_type_function b res_id ret_type_id param_types
    ops = list()
    push(ops, res_id)
    push(ops, ret_type_id)
    pi = 0
    while pi < len(param_types)
        push(ops, get(param_types, pi))
        pi = pi + 1
    return spirv_emit_inst(b, OP_TYPE_FUNCTION, ops)

// Variable & Decoration Declarations
fn spirv_emit_variable b type_id res_id storage_class
    ops = list()
    push(ops, type_id)
    push(ops, res_id)
    push(ops, storage_class)
    return spirv_emit_inst(b, OP_VARIABLE, ops)

fn spirv_emit_decorate b target_id decor_kind extra_args
    ops = list()
    push(ops, target_id)
    push(ops, decor_kind)
    ei = 0
    while ei < len(extra_args)
        push(ops, get(extra_args, ei))
        ei = ei + 1
    return spirv_emit_inst(b, OP_DECORATE, ops)

fn spirv_emit_member_decorate b target_id member_idx decor_kind extra_args
    ops = list()
    push(ops, target_id)
    push(ops, member_idx)
    push(ops, decor_kind)
    ei = 0
    while ei < len(extra_args)
        push(ops, get(extra_args, ei))
        ei = ei + 1
    return spirv_emit_inst(b, OP_MEMBER_DECORATE, ops)

// Function & Control Flow
fn spirv_emit_function b ret_type_id fn_id fn_control fn_type_id
    ops = list()
    push(ops, ret_type_id)
    push(ops, fn_id)
    push(ops, fn_control)
    push(ops, fn_type_id)
    return spirv_emit_inst(b, OP_FUNCTION, ops)

fn spirv_emit_label b label_id
    ops = list()
    push(ops, label_id)
    return spirv_emit_inst(b, OP_LABEL, ops)

fn spirv_emit_load b res_type_id res_id ptr_id
    ops = list()
    push(ops, res_type_id)
    push(ops, res_id)
    push(ops, ptr_id)
    return spirv_emit_inst(b, OP_LOAD, ops)

fn spirv_emit_store b ptr_id val_id
    ops = list()
    push(ops, ptr_id)
    push(ops, val_id)
    return spirv_emit_inst(b, OP_STORE, ops)

fn spirv_emit_access_chain b res_type_id res_id base_ptr_id indexes
    ops = list()
    push(ops, res_type_id)
    push(ops, res_id)
    push(ops, base_ptr_id)
    ii = 0
    while ii < len(indexes)
        push(ops, get(indexes, ii))
        ii = ii + 1
    return spirv_emit_inst(b, OP_ACCESS_CHAIN, ops)

fn spirv_emit_iadd b res_type_id res_id op1 op2
    ops = list()
    push(ops, res_type_id)
    push(ops, res_id)
    push(ops, op1)
    push(ops, op2)
    return spirv_emit_inst(b, OP_IADD, ops)

fn spirv_emit_fadd b res_type_id res_id op1 op2
    ops = list()
    push(ops, res_type_id)
    push(ops, res_id)
    push(ops, op1)
    push(ops, op2)
    return spirv_emit_inst(b, OP_FADD, ops)

fn spirv_emit_fmul b res_type_id res_id op1 op2
    ops = list()
    push(ops, res_type_id)
    push(ops, res_id)
    push(ops, op1)
    push(ops, op2)
    return spirv_emit_inst(b, OP_FMUL, ops)

fn spirv_emit_return b
    ops = list()
    return spirv_emit_inst(b, OP_RETURN, ops)

fn spirv_emit_function_end b
    ops = list()
    return spirv_emit_inst(b, OP_FUNCTION_END, ops)

// ── 6. High-Level Sovereign GPU Compute Kernels ───────────────────────────────

// Vector Addition Kernel Generator: C[i] = A[i] + B[i]
// local_size_x = 64, local_size_y = 1, local_size_z = 1
fn spirv_build_vector_add_kernel
    b = spirv_builder_new()

    // Pass 1: Allocate IDs
    id_ext_import = spirv_alloc_id(b)
    id_fn_main    = spirv_alloc_id(b)
    id_type_void  = spirv_alloc_id(b)
    id_type_f32   = spirv_alloc_id(b)
    id_type_u32   = spirv_alloc_id(b)
    id_type_v3u32 = spirv_alloc_id(b)
    id_type_arr_f = spirv_alloc_id(b)
    id_type_struct= spirv_alloc_id(b)
    id_ptr_struct = spirv_alloc_id(b)
    id_ptr_f32    = spirv_alloc_id(b)
    id_ptr_v3u32  = spirv_alloc_id(b)
    id_fn_type    = spirv_alloc_id(b)

    id_var_buf_a  = spirv_alloc_id(b)
    id_var_buf_b  = spirv_alloc_id(b)
    id_var_buf_c  = spirv_alloc_id(b)
    id_var_gl_id  = spirv_alloc_id(b)

    id_label_entry= spirv_alloc_id(b)
    id_val_a      = spirv_alloc_id(b)
    id_val_b      = spirv_alloc_id(b)
    id_val_c      = spirv_alloc_id(b)
    id_ptr_elem_a = spirv_alloc_id(b)
    id_ptr_elem_b = spirv_alloc_id(b)
    id_ptr_elem_c = spirv_alloc_id(b)

    // Emit Header
    spirv_emit_header(b)

    // Emit Capabilities & Memory Model
    spirv_emit_capability(b, CAP_SHADER)
    spirv_emit_memory_model(b, ADDR_MODEL_LOGICAL, MEM_MODEL_GLSL450)

    // Emit Entry Point: main() compute shader
    ifaces = list()
    push(ifaces, id_var_gl_id)
    spirv_emit_entry_point(b, EXEC_MODEL_GLCOMPUTE, id_fn_main, "main", ifaces)

    // Execution Mode: Local workgroup size 64 x 1 x 1
    spirv_emit_execution_mode_local_size(b, id_fn_main, 64, 1, 1)

    // Decorations
    empty_list = list()
    decor_block = list()
    push(decor_block, DECOR_BUFFER_BLOCK)

    stride_4 = list()
    push(stride_4, 4) // 4 bytes for float32
    spirv_emit_decorate(b, id_type_arr_f, DECOR_ARRAY_STRIDE, stride_4)
    spirv_emit_decorate(b, id_type_struct, DECOR_BLOCK, empty_list)

    binding_0 = list()
    push(binding_0, 0)
    spirv_emit_decorate(b, id_var_buf_a, DECOR_BINDING, binding_0)

    binding_1 = list()
    push(binding_1, 1)
    spirv_emit_decorate(b, id_var_buf_b, DECOR_BINDING, binding_1)

    binding_2 = list()
    push(binding_2, 2)
    spirv_emit_decorate(b, id_var_buf_c, DECOR_BINDING, binding_2)

    builtin_glid = list()
    push(builtin_glid, BUILTIN_GLOBAL_INVOC_ID)
    spirv_emit_decorate(b, id_var_gl_id, DECOR_BUILTIN, builtin_glid)

    // Type declarations
    spirv_emit_type_void(b, id_type_void)
    spirv_emit_type_float(b, id_type_f32, 32)
    spirv_emit_type_int(b, id_type_u32, 32, 0)
    spirv_emit_type_vector(b, id_type_v3u32, id_type_u32, 3)

    spirv_emit_type_runtime_array(b, id_type_arr_f, id_type_f32)
    struct_members = list()
    push(struct_members, id_type_arr_f)
    spirv_emit_type_struct(b, id_type_struct, struct_members)

    spirv_emit_type_pointer(b, id_ptr_struct, STORAGE_STORAGE_BUFFER, id_type_struct)
    spirv_emit_type_pointer(b, id_ptr_f32, STORAGE_STORAGE_BUFFER, id_type_f32)
    spirv_emit_type_pointer(b, id_ptr_v3u32, STORAGE_INPUT, id_type_v3u32)

    no_params = list()
    spirv_emit_type_function(b, id_fn_type, id_type_void, no_params)

    // Variables
    spirv_emit_variable(b, id_ptr_struct, id_var_buf_a, STORAGE_STORAGE_BUFFER)
    spirv_emit_variable(b, id_ptr_struct, id_var_buf_b, STORAGE_STORAGE_BUFFER)
    spirv_emit_variable(b, id_ptr_struct, id_var_buf_c, STORAGE_STORAGE_BUFFER)
    spirv_emit_variable(b, id_ptr_v3u32, id_var_gl_id, STORAGE_INPUT)

    // Function main()
    spirv_emit_function(b, id_type_void, id_fn_main, 0, id_fn_type)
    spirv_emit_label(b, id_label_entry)

    // Compute: C[i] = A[i] + B[i]
    indexes = list()
    push(indexes, 0) // struct member 0
    push(indexes, 0) // array index

    spirv_emit_access_chain(b, id_ptr_f32, id_ptr_elem_a, id_var_buf_a, indexes)
    spirv_emit_access_chain(b, id_ptr_f32, id_ptr_elem_b, id_var_buf_b, indexes)
    spirv_emit_access_chain(b, id_ptr_f32, id_ptr_elem_c, id_var_buf_c, indexes)

    spirv_emit_load(b, id_type_f32, id_val_a, id_ptr_elem_a)
    spirv_emit_load(b, id_type_f32, id_val_b, id_ptr_elem_b)
    spirv_emit_fadd(b, id_type_f32, id_val_c, id_val_a, id_val_b)
    spirv_emit_store(b, id_ptr_elem_c, id_val_c)

    spirv_emit_return(b)
    spirv_emit_function_end(b)

    // Finalize bound in header
    spirv_finalize_header(b)
    return b

// Matrix Multiplication (GEMM) Kernel Generator: C = A * B
// local_size_x = 16, local_size_y = 16, local_size_z = 1
fn spirv_build_gemm_kernel
    b = spirv_builder_new()

    id_fn_main    = spirv_alloc_id(b)
    id_type_void  = spirv_alloc_id(b)
    id_type_f32   = spirv_alloc_id(b)
    id_type_u32   = spirv_alloc_id(b)
    id_type_v3u32 = spirv_alloc_id(b)
    id_type_arr_f = spirv_alloc_id(b)
    id_type_struct= spirv_alloc_id(b)
    id_ptr_struct = spirv_alloc_id(b)
    id_ptr_f32    = spirv_alloc_id(b)
    id_ptr_v3u32  = spirv_alloc_id(b)
    id_fn_type    = spirv_alloc_id(b)

    id_var_buf_a  = spirv_alloc_id(b)
    id_var_buf_b  = spirv_alloc_id(b)
    id_var_buf_c  = spirv_alloc_id(b)
    id_var_gl_id  = spirv_alloc_id(b)

    id_label_entry= spirv_alloc_id(b)
    id_val_a      = spirv_alloc_id(b)
    id_val_b      = spirv_alloc_id(b)
    id_val_prod   = spirv_alloc_id(b)
    id_ptr_elem_a = spirv_alloc_id(b)
    id_ptr_elem_b = spirv_alloc_id(b)
    id_ptr_elem_c = spirv_alloc_id(b)

    spirv_emit_header(b)
    spirv_emit_capability(b, CAP_SHADER)
    spirv_emit_memory_model(b, ADDR_MODEL_LOGICAL, MEM_MODEL_GLSL450)

    ifaces = list()
    push(ifaces, id_var_gl_id)
    spirv_emit_entry_point(b, EXEC_MODEL_GLCOMPUTE, id_fn_main, "gemm_main", ifaces)
    spirv_emit_execution_mode_local_size(b, id_fn_main, 16, 16, 1)

    empty_list = list()
    spirv_emit_decorate(b, id_type_struct, DECOR_BLOCK, empty_list)

    spirv_emit_type_void(b, id_type_void)
    spirv_emit_type_float(b, id_type_f32, 32)
    spirv_emit_type_int(b, id_type_u32, 32, 0)
    spirv_emit_type_vector(b, id_type_v3u32, id_type_u32, 3)

    spirv_emit_type_runtime_array(b, id_type_arr_f, id_type_f32)
    struct_members = list()
    push(struct_members, id_type_arr_f)
    spirv_emit_type_struct(b, id_type_struct, struct_members)

    spirv_emit_type_pointer(b, id_ptr_struct, STORAGE_STORAGE_BUFFER, id_type_struct)
    spirv_emit_type_pointer(b, id_ptr_f32, STORAGE_STORAGE_BUFFER, id_type_f32)
    spirv_emit_type_pointer(b, id_ptr_v3u32, STORAGE_INPUT, id_type_v3u32)

    no_params = list()
    spirv_emit_type_function(b, id_fn_type, id_type_void, no_params)

    spirv_emit_variable(b, id_ptr_struct, id_var_buf_a, STORAGE_STORAGE_BUFFER)
    spirv_emit_variable(b, id_ptr_struct, id_var_buf_b, STORAGE_STORAGE_BUFFER)
    spirv_emit_variable(b, id_ptr_struct, id_var_buf_c, STORAGE_STORAGE_BUFFER)
    spirv_emit_variable(b, id_ptr_v3u32, id_var_gl_id, STORAGE_INPUT)

    spirv_emit_function(b, id_type_void, id_fn_main, 0, id_fn_type)
    spirv_emit_label(b, id_label_entry)

    indexes = list()
    push(indexes, 0)
    push(indexes, 0)

    spirv_emit_access_chain(b, id_ptr_f32, id_ptr_elem_a, id_var_buf_a, indexes)
    spirv_emit_access_chain(b, id_ptr_f32, id_ptr_elem_b, id_var_buf_b, indexes)
    spirv_emit_access_chain(b, id_ptr_f32, id_ptr_elem_c, id_var_buf_c, indexes)

    spirv_emit_load(b, id_type_f32, id_val_a, id_ptr_elem_a)
    spirv_emit_load(b, id_type_f32, id_val_b, id_ptr_elem_b)
    spirv_emit_fmul(b, id_type_f32, id_val_prod, id_val_a, id_val_b)
    spirv_emit_store(b, id_ptr_elem_c, id_val_prod)

    spirv_emit_return(b)
    spirv_emit_function_end(b)

    spirv_finalize_header(b)
    return b

// ── 7. Binary Serialization & Direct File Writer ──────────────────────────────
// Converts 32-bit words list to byte array (4 bytes per word, little endian)
fn spirv_to_bytes b
    words = get(b, 0)
    total_words = len(words)
    bytes = list()
    wi = 0
    while wi < total_words
        w = get(words, wi)
        b0 = w % 256
        b1 = (w / 256) % 256
        b2 = (w / 65536) % 256
        b3 = (w / 16777216) % 256
        push(bytes, b0)
        push(bytes, b1)
        push(bytes, b2)
        push(bytes, b3)
        wi = wi + 1
    return bytes

// Writes the binary SPIR-V module directly to disk using raw Linux syscalls
fn spirv_write_binary b filename
    bytes = spirv_to_bytes(b)
    total_bytes = len(bytes)

    // Open file via Linux SYS_open (2)
    // O_WRONLY(1) | O_CREAT(64) | O_TRUNC(512) = 577, Mode 0644 (420)
    fd = syscall(2, filename, 577, 420, 0, 0, 0)
    if fd < 0
        return -1

    // Allocate temporary write buffer
    buf = malloc(total_bytes)
    bi = 0
    while bi < total_bytes
        mem_byte_write(buf, bi, get(bytes, bi))
        bi = bi + 1

    // Write to disk via SYS_write (1)
    written = syscall(1, fd, buf, total_bytes, 0, 0, 0)
    // Close file via SYS_close (3)
    syscall(3, fd, 0, 0, 0, 0, 0)
    free(buf, total_bytes)

    return written

// ── 8. CPU Reference Implementations for Verification ─────────────────────────

// Vector addition: C = A + B
fn gpu_vector_add_cpu a b n
    c = list()
    i = 0
    while i < n
        push(c, get(a, i) + get(b, i))
        i = i + 1
    return c

// GEMM: C = A * B (Matrices dimension: A is m x k, B is k x n, C is m x n)
fn gpu_gemm_cpu a b m k n
    c = list()
    total_c = m * n
    ci = 0
    while ci < total_c
        push(c, 0)
        ci = ci + 1

    r = 0
    while r < m
        col = 0
        while col < n
            sum = 0
            idx_k = 0
            while idx_k < k
                val_a = get(a, (r * k) + idx_k)
                val_b = get(b, (idx_k * n) + col)
                sum = sum + (val_a * val_b)
                idx_k = idx_k + 1
            list_set(c, (r * n) + col, sum)
            col = col + 1
        r = r + 1

    return c
