@! ============================================================================
@! ADVERSARIAL STRESS TEST: C Bridge Header Assimilation & FFI CodeGen (Challenger 1)
@! File: tests/adversarial/test_adv_phase5_c_bridge.maya
@! Tests:
@! 1. Complex C Header Tokenizer (Nested comments, multi-line blocks)
@! 2. Macros with integer and string values
@! 3. Structs with multi-level pointer depths (char**), const fields
@! 4. Enums with explicit custom values (e.g. 100, 101)
@! 5. Typedef aliases (pointers and primitives)
@! 6. Functions with varargs (...)
@! 7. Pure Maya FFI Bridge Code Generation
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/assimilator/c_bridge"

@fn assert_true(cond, msg: string) -> i64
  @if cond == 0 || cond == false
    println("  ❌ [ADV FAIL] " + msg)
    return 0
  @end
  println("  ✓ [ADV PASS] " + msg)
  return 1
@end

@fn assert_eq_int(actual: i64, expected: i64, msg: string) -> i64
  @if actual == expected
    println("  ✓ [ADV PASS] " + msg + " (Got " + actual.to_str() + ")")
    return 1
  @else
    println("  ❌ [ADV FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn assert_eq_str(actual: string, expected: string, msg: string) -> i64
  @if actual == expected
    println("  ✓ [ADV PASS] " + msg + " (Got '" + actual + "')")
    return 1
  @else
    println("  ❌ [ADV FAIL] " + msg + " -> Expected '" + expected + "', got '" + actual + "'")
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("🔥 [CHALLENGE 4: Complex C Header Assimilation & FFI CodeGen] 🔥")
  println("=================================================================")

  total_asserts = 0
  passed_asserts = 0

  complex_c_header = "// System Graphics & Compute Interface\n/* Multi-line header comments\n * with asterisks and nested // tokens\n */\n#define VK_MAX_DEVICES 16\n#define VK_ENGINE_NAME \"MayaEngine\"\n#define VK_TIMEOUT_NS 5000000\n\n/* Typedef struct with nested pointer depth */\ntypedef struct {\n    uint32_t device_id;\n    char** extension_names;\n    void* user_data;\n    const float* transform_matrix;\n} VkDeviceConfig;\n\n/* Standard struct declaration without typedef */\nstruct {\n    uint64_t cache_size;\n    uint8_t* raw_blob;\n};\n\n/* Enum with explicit values and auto-increment */\ntypedef enum {\n    VK_SUCCESS = 0,\n    VK_NOT_READY = 1,\n    VK_TIMEOUT = 2,\n    VK_ERROR_OUT_OF_MEMORY = 100,\n    VK_ERROR_INITIALIZATION_FAILED = 101\n} VkResult;\n\n/* Typedef aliases */\ntypedef uint64_t VkHandle;\ntypedef void* VkInstanceHandle;\n\n/* Complex function prototypes */\nextern \"C\" {\n    int vkCreateInstance(const VkDeviceConfig* config, VkInstanceHandle* out_instance);\n    void* vkAllocateMemory(VkInstanceHandle instance, size_t size, uint32_t flags);\n    void vkFreeMemory(VkInstanceHandle instance, void* mem);\n    int vkLogDebug(int level, const char* format, ...);\n}\n"

  ast_c = c_parse_header_declarations(complex_c_header, "vulkan_mini.h")

  @! 4.1 Macros
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(ast_c.macros.len(), 3, "Parsed 3 preprocessor macro constants")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_str(ast_c.macros[0].name, "VK_MAX_DEVICES", "Macro 0 name is VK_MAX_DEVICES")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(ast_c.macros[0].int_val, 16, "Macro 0 value == 16")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(ast_c.macros[2].int_val, 5000000, "Macro 2 value == 5000000")

  @! 4.2 Structs with nested pointers
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(ast_c.structs.len(), 2, "Parsed 2 struct definitions (VkDeviceConfig, VkPipelineCache)")
  
  s_dev = ast_c.structs[0]
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_str(s_dev.name, "VkDeviceConfig", "Struct 0 name is VkDeviceConfig")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(s_dev.fields.len(), 4, "VkDeviceConfig has 4 fields")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_str(s_dev.fields[0].name, "device_id", "Field 0 is device_id")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_str(s_dev.fields[1].name, "extension_names", "Field 1 is extension_names")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(s_dev.fields[1].field_type.pointer_depth, 2, "Field extension_names has pointer_depth == 2 (char**)")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(s_dev.fields[3].field_type.is_const, 1, "Field transform_matrix is const")

  @! 4.3 Enums
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(ast_c.enums.len(), 1, "Parsed 1 enum definition (VkResult)")
  e_res = ast_c.enums[0]
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_str(e_res.name, "VkResult", "Enum name is VkResult")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(e_res.variants.len(), 5, "VkResult has 5 variants")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(e_res.variants[3].val, 100, "VK_ERROR_OUT_OF_MEMORY == 100")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(e_res.variants[4].val, 101, "VK_ERROR_INITIALIZATION_FAILED == 101")

  @! 4.4 Typedefs
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(ast_c.typedefs.len(), 2, "Parsed 2 type aliases (VkHandle, VkInstanceHandle)")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_str(ast_c.typedefs[0].alias_name, "VkHandle", "Typedef 0 is VkHandle")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_str(ast_c.typedefs[1].alias_name, "VkInstanceHandle", "Typedef 1 is VkInstanceHandle")

  @! 4.5 Functions & Varargs
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(ast_c.functions.len(), 4, "Parsed 4 foreign function prototypes")
  f_create = ast_c.functions[0]
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_str(f_create.name, "vkCreateInstance", "Function 0 is vkCreateInstance")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(f_create.params.len(), 2, "vkCreateInstance has 2 parameters")

  f_log = ast_c.functions[3]
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_str(f_log.name, "vkLogDebug", "Function 3 is vkLogDebug")
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(f_log.is_varargs, 1, "vkLogDebug has varargs (...)")

  @! 4.6 FFI Bridge Code Generation Test
  ca = {
    ca_funcs: [
      { cf_name: "vkCreateInstance", cf_lib: "libvulkan.so", cf_args: [{name: "config", type: "i64"}, {name: "out_instance", type: "i64"}], cf_ret_type: "i64" },
      { cf_name: "vkAllocateMemory", cf_lib: "libvulkan.so", cf_args: [{name: "instance", type: "i64"}, {name: "size", type: "i64"}, {name: "flags", type: "i64"}], cf_ret_type: "i64" },
      { cf_name: "vkFreeMemory", cf_lib: "libvulkan.so", cf_args: [{name: "instance", type: "i64"}, {name: "mem", type: "i64"}], cf_ret_type: "void" }
    ],
    ca_libs: ["libvulkan.so"],
    ca_loaded: 1,
    ast: ast_c
  }

  bridge_out = "/tmp/test_vulkan_bridge.maya"
  gen_ok = c_generate_bridge(ca, bridge_out)
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_eq_int(gen_ok, 1, "Bridge code generation succeeded")

  gen_code = file_read(bridge_out)
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_true(
    contains(gen_code, "const C_VK_MAX_DEVICES = 16"),
    "Generated bridge contains macro constant C_VK_MAX_DEVICES"
  )
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_true(
    contains(gen_code, "@struct C_VkDeviceConfig")
    "Generated bridge contains @struct C_VkDeviceConfig"
  )
  total_asserts = total_asserts + 1
  passed_asserts = passed_asserts + assert_true(
    contains(gen_code, "@fn c_vkCreateInstance(config: i64, out_instance: i64) -> i64")
    "Generated bridge contains @fn c_vkCreateInstance wrapper"
  )

  println("\n=================================================================")
  println("📊 C BRIDGE RESULTS: " + passed_asserts.to_str() + " / " + total_asserts.to_str() + " assertions passed")
  println("=================================================================")
  @if passed_asserts == total_asserts
    return 0
  @else
    return 1
  @end
@end
