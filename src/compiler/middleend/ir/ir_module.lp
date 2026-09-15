// ==============================================================================
// 👑 LIPI FIRST 1.0.0 MIDDLE-END IR MODULE (src/compiler/middleend/ir/ir_module.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Compiler Architecture
//
// WHY: An IR Module represents the top-level container of a compilation unit.
//      It aggregates:
//      1. Global symbols, constants, and static data descriptors.
//      2. Function definitions with their corresponding Control Flow Graphs.
//      3. Target architecture and compilation pass metadata.
//      Whole-program and inter-procedural passes (such as function inlining and
//      global dead code elimination) operate directly on the IR Module.
// ==============================================================================

include "src/compiler/middleend/ir/ir_function.lp"

// ── 1. Global Variable / Constant Descriptor ──────────────────────────────────
// WHY: Differentiating between mutable static data and compile-time constants
//      enables placement into read-only (.rodata) vs read-write (.data/.bss) sections.

struct GlobalVar
    name      // string: unique symbol identifier (e.g. "@g_table", "@str_hello")
    gtype     // string: type descriptor ("i64", "ptr", "string", etc.)
    init_val  // immediate value or string pointer
    is_const  // integer: 1 if read-only constant, 0 if mutable variable

fn global_var_new name gtype init_val is_const
    g = GlobalVar()
    g.name = name
    g.gtype = gtype
    g.init_val = init_val
    g.is_const = is_const
    return g

// ── 2. IR Module Structure ────────────────────────────────────────────────────

struct IRModule
    name        // string: module identifier (e.g. "core", "math_engine")
    globals     // list: GlobalVar records
    functions   // list: IRFunction objects
    meta_keys   // list: metadata key strings
    meta_vals   // list: metadata value strings

// ── 3. Constructor ────────────────────────────────────────────────────────────

fn ir_module_new name
    m = IRModule()
    m.name = name
    m.globals = list()
    m.functions = list()
    m.meta_keys = list()
    m.meta_vals = list()
    return m

// ── 4. Function Management ────────────────────────────────────────────────────

// Adds a function definition to this module
fn ir_module_add_function mod_obj fn_obj
    if mod_obj == 0 or fn_obj == 0 return 0
    push(mod_obj.functions, fn_obj)
    return 1

fn IRModule.add_function self fn_obj
    return ir_module_add_function(self, fn_obj)

fn add_function mod_obj fn_obj
    return ir_module_add_function(mod_obj, fn_obj)

// Searches for a function by name within the module
// WHY: Required by function inlining and inter-procedural call graph resolution.
fn ir_module_find_function mod_obj fn_name
    if mod_obj == 0 return 0
    i = 0
    cnt = len(mod_obj.functions)
    while i < cnt
        f = get(mod_obj.functions, i)
        if f.name == fn_name
            return f
        i = i + 1
    return 0

fn IRModule.find_function self fn_name
    return ir_module_find_function(self, fn_name)

fn find_function mod_obj fn_name
    return ir_module_find_function(mod_obj, fn_name)

// Returns the number of functions in the module
fn ir_module_count_functions mod_obj
    if mod_obj == 0 return 0
    return len(mod_obj.functions)

fn IRModule.count_functions self
    return ir_module_count_functions(self)

fn count_functions mod_obj
    return ir_module_count_functions(mod_obj)

// ── 5. Global Variable Management ─────────────────────────────────────────────

// Registers a global variable or constant in the module
fn ir_module_add_global mod_obj name gtype init_val is_const
    if mod_obj == 0 return 0
    g = global_var_new(name, gtype, init_val, is_const)
    push(mod_obj.globals, g)
    return g

fn IRModule.add_global self name gtype init_val is_const
    return ir_module_add_global(self, name, gtype, init_val, is_const)

fn add_global mod_obj name gtype init_val is_const
    return ir_module_add_global(mod_obj, name, gtype, init_val, is_const)

// Finds a global variable by symbol name
fn ir_module_find_global mod_obj name
    if mod_obj == 0 return 0
    i = 0
    cnt = len(mod_obj.globals)
    while i < cnt
        g = get(mod_obj.globals, i)
        if g.name == name
            return g
        i = i + 1
    return 0

fn IRModule.find_global self name
    return ir_module_find_global(self, name)

fn find_global mod_obj name
    return ir_module_find_global(mod_obj, name)

// Returns total number of registered globals
fn ir_module_count_globals mod_obj
    if mod_obj == 0 return 0
    return len(mod_obj.globals)

fn IRModule.count_globals self
    return ir_module_count_globals(self)

fn count_globals mod_obj
    return ir_module_count_globals(mod_obj)

// ── 6. Metadata Management ────────────────────────────────────────────────────
// WHY: Encapsulates build configuration (e.g. target="x86_64", opt_level="O2")
//      without hardcoding machine characteristics into the IR structure.

fn ir_module_set_metadata mod_obj key val
    if mod_obj == 0 return 0
    i = 0
    cnt = len(mod_obj.meta_keys)
    while i < cnt
        if get(mod_obj.meta_keys, i) == key
            list_set(mod_obj.meta_vals, i, val)
            return 1
        i = i + 1
    push(mod_obj.meta_keys, key)
    push(mod_obj.meta_vals, val)
    return 1

fn IRModule.set_metadata self key val
    return ir_module_set_metadata(self, key, val)

fn set_metadata mod_obj key val
    return ir_module_set_metadata(mod_obj, key, val)

fn ir_module_get_metadata mod_obj key default_val
    if mod_obj == 0 return default_val
    i = 0
    cnt = len(mod_obj.meta_keys)
    while i < cnt
        if get(mod_obj.meta_keys, i) == key
            return get(mod_obj.meta_vals, i)
        i = i + 1
    return default_val

fn IRModule.get_metadata self key default_val
    return ir_module_get_metadata(self, key, default_val)

fn get_metadata mod_obj key default_val
    return ir_module_get_metadata(mod_obj, key, default_val)
