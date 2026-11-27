// ==============================================================================
// 👑 LIPI FIRST 1.0.0 AST TO SSA IR LOWERING ENGINE (src/compiler/middleend/ast_to_ssa.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Micro-Architecture
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Bridges the frontend AST representation with the middle-end SSA optimization
//    pipeline (Pass Manager O0, O1, O2, O3, Dominator Tree, LICM, DCE, CSE).
// 2. Canonical Mem2Reg Alloca Pattern:
//    - Every local variable and function argument is given a unique stack slot (OP_ALLOCA)
//      in the entry basic block.
//    - Reads emit OP_LOAD; writes emit OP_STORE.
//    - This ensures valid, strictly verifiable SSA form regardless of complex control flow
//      branching or reassignments, enabling standard SSA optimization passes to promote
//      allocas to SSA registers and phi nodes.
// 3. Bidirectional CFG Symmetry:
//    - Control flow structures (If-Else, While loops, Break, Continue) construct explicit
//      basic blocks and terminators (OP_BR, OP_JMP, OP_RET).
//    - Calls cfg_rebuild_edges at the conclusion of lowering to mathematically guarantee
//      100% edge consistency for downstream dominator tree and loop analyses.
// ==============================================================================

include "src/compiler/middleend/ir/ir_module.lp"
include "src/compiler/middleend/opt/analysis/cfg.lp"

// ── 1. AST-to-SSA Lowering Context ────────────────────────────────────────────

struct AstToSsaContext
    ctx_module          // IRModule reference
    ctx_curr_fn         // IRFunction reference currently being lowered
    ctx_curr_bb         // BasicBlock currently receiving instructions
    ctx_inst_counter    // Monotonic integer instruction ID counter
    ctx_var_names       // list of string variable names currently in scope
    ctx_var_slots       // list of SSAValue (alloca pointer) slots
    ctx_var_types       // parallel list of string types ("i64", "f64", "str", or struct name)
    ctx_var_int_types   // parallel list of narrow int types ("u8","u16","u32","i8","i16","i32","byte","")
    ctx_loop_headers    // list of BasicBlock references for 'continue' targets
    ctx_loop_exits      // list of BasicBlock references for 'break' targets
    ctx_has_unsupported // 1 if any non-SSA-lowerable construct was encountered
    ctx_struct_names    // module-wide registered StructDef names
    ctx_struct_fields   // parallel list of field-name lists per struct
    ctx_struct_idx_map  // dict: struct_name -> index + 1 (O(1) lookup)
    ctx_field_uniq_off  // dict: field_name -> unique byte offset + 1 (0 if ambiguous)
    ctx_field_type_map  // dict: "Struct::field" / "::field" -> normalized field type ("f64","str",struct)
    ctx_fn_names        // module-wide registered user FnDef names
    ctx_fn_ret_types    // parallel list of user FnDef normalized return types
    ctx_fn_param_cnts   // parallel list of user FnDef parameter counts
    ctx_fn_param_types  // parallel list of per-param normalized type lists ("f64" or "")
    ctx_fn_idx_map      // dict: fn_name -> index + 1 (O(1) lookup)
    ctx_mod_const_map   // dict: immutable top-level int constant name -> val
    ctx_mod_mut_globals // dict: mutable global variable name -> 1
    ctx_mod_has_float_cont // 1 if module stores floats in dicts/lists (needs dyn_tagged Index)
    ctx_target_name     // target architecture string ("x86_64", "arm64", "riscv64", "wasm")
    ctx_has_float_dict  // 1 if a float was stored into a dict/list in this function
    ctx_inferred_ret    // inferred return type from OP_RET statements ("", "i64", "f64", "str", struct)
    ctx_fn_has_float_cont // 1 if THIS function contains float dict/list writes/literals
    ctx_local_nonfloat_conts // dict of local var names proven to be non-float containers created in this fn
    ctx_in_member_base  // 1 while lowering base of MemberAccess (e.g. arr[i].field is a struct ptr, never f64)

fn ast_to_ssa_context_new mod_obj fn_obj
    // WHY: Initializes isolated lowering context with pristine scope tables
    ctx = AstToSsaContext()
    ctx.ctx_module = mod_obj
    ctx.ctx_curr_fn = fn_obj
    ctx.ctx_curr_bb = fn_obj.entry_block
    ctx.ctx_inst_counter = 1
    ctx.ctx_var_names = list()
    ctx.ctx_var_slots = list()
    ctx.ctx_var_types = list()
    ctx.ctx_var_int_types = list()
    ctx.ctx_loop_headers = list()
    ctx.ctx_loop_exits = list()
    ctx.ctx_has_unsupported = 0
    ctx.ctx_struct_names = list()
    ctx.ctx_struct_fields = list()
    ctx.ctx_struct_idx_map = 0
    ctx.ctx_field_uniq_off = 0
    ctx.ctx_field_type_map = 0
    ctx.ctx_fn_names = list()
    ctx.ctx_fn_ret_types = list()
    ctx.ctx_fn_param_cnts = list()
    ctx.ctx_fn_param_types = list()
    ctx.ctx_fn_idx_map = 0
    ctx.ctx_mod_const_map = 0
    ctx.ctx_mod_mut_globals = 0
    ctx.ctx_mod_has_float_cont = 0
    ctx.ctx_target_name = "x86_64"
    ctx.ctx_has_float_dict = 0
    ctx.ctx_inferred_ret = ""
    ctx.ctx_fn_has_float_cont = 0
    ctx.ctx_local_nonfloat_conts = dict()
    ctx.ctx_in_member_base = 0
    return ctx

fn ssa_is_narrow_int_type tname
    if tname == "u8" or tname == "byte" or tname == "u16" or tname == "u32" or tname == "i8" or tname == "i16" or tname == "i32"
        return 1
    end
    return 0
end

fn ssa_normalize_type tname
    if tname == 0 or tname == "" or tname == "int" or tname == "i64" or tname == "bool" or tname == "any" or tname == "void"
        return "i64"
    end
    if ssa_is_narrow_int_type(tname) == 1
        return "i64"
    end
    if tname == "array" or tname == "list" or tname == "dict" or tname == "map" or tname == "ptr"
        return "i64"
    end
    if tname == "float" or tname == "f64"
        return "f64"
    end
    if tname == "string" or tname == "str"
        return "str"
    end
    return tname

fn ssa_parse_float_bits s_text
    // WHY: Pure-integer IEEE-754 binary64 parser for SSA LiteralFloat constants (zero libc).
    s_len = len(s_text)
    if s_len == 0
        return 0
    end
    sign = 0
    start = 0
    c0 = char_at(s_text, 0)
    if c0 == "-"
        sign = 1
        start = 1
    elif c0 == "+"
        start = 1
    end
    int_part = 0
    frac_part = 0
    frac_digits = 0
    dot_seen = 0
    exp_seen = 0
    exp_neg = 0
    exp_val = 0
    idx = start
    while idx < s_len
        c = char_at(s_text, idx)
        if c == "." and exp_seen == 0
            dot_seen = 1
        elif c == "e" or c == "E"
            exp_seen = 1
            if idx + 1 < s_len
                nc = char_at(s_text, idx + 1)
                if nc == "-"
                    exp_neg = 1
                    idx = idx + 1
                elif nc == "+"
                    idx = idx + 1
                end
            end
        else
            code = ord(c)
            if code >= 48 and code <= 57
                d = code - 48
                if exp_seen == 1
                    if exp_val < 1000
                        exp_val = (exp_val * 10) + d
                    end
                elif dot_seen == 0
                    if int_part < 90000000000000000
                        int_part = (int_part * 10) + d
                    else
                        exp_val = exp_val + 1
                    end
                else
                    if frac_digits < 17 and frac_part < 90000000000000000
                        frac_part = (frac_part * 10) + d
                        frac_digits = frac_digits + 1
                    end
                end
            end
        end
        idx = idx + 1
    end
    if exp_neg == 1
        exp_val = 0 - exp_val
    end
    if int_part == 0 and frac_part == 0
        if sign == 1
            return 9223372036854775808
        end
        return 0
    end
    exp10 = exp_val - frac_digits
    num = int_part
    k = 0
    while k < frac_digits
        num = num * 10
        k = k + 1
    end
    num = num + frac_part
    den = 1
    exp = 1023
    if exp10 > 320
        res = 2047 * 4503599627370496
        if sign == 1
            res = res + 9223372036854775808
        end
        return res
    end
    if exp10 < (0 - 340)
        if sign == 1
            return 9223372036854775808
        end
        return 0
    end
    while exp10 > 0
        while num >= 450359962737049600
            num = num / 2
            exp = exp + 1
        end
        num = num * 10
        exp10 = exp10 - 1
    end
    while exp10 < 0
        while den >= 450359962737049600
            den = den / 2
            exp = exp - 1
        end
        den = den * 10
        exp10 = exp10 + 1
    end
    while num >= (den * 2)
        den = den * 2
        exp = exp + 1
    end
    while num < den
        num = num * 2
        exp = exp - 1
    end
    if exp >= 2047
        res = 2047 * 4503599627370496
        if sign == 1
            res = res + 9223372036854775808
        end
        return res
    end
    if exp <= 0
        if sign == 1
            return 9223372036854775808
        end
        return 0
    end
    rem = num - den
    mantissa = 0
    b = 0
    while b < 52
        rem = rem * 2
        bit = 0
        if rem >= den
            bit = 1
            rem = rem - den
        end
        mantissa = (mantissa * 2) + bit
        b = b + 1
    end
    rem = rem * 2
    if rem >= den
        mantissa = mantissa + 1
        if mantissa >= 4503599627370496
            mantissa = 0
            exp = exp + 1
        end
    end
    res = (exp * 4503599627370496) + mantissa
    if sign == 1
        res = res + 9223372036854775808
    end
    return res

fn ast_to_ssa_find_struct_idx ctx sname
    if ctx.ctx_struct_idx_map != 0 and has_key(ctx.ctx_struct_idx_map, sname) == 1
        return ctx.ctx_struct_idx_map[sname] - 1
    end
    i = 0
    while i < ctx.ctx_struct_names.len()
        if ctx.ctx_struct_names[i] == sname
            return i
        end
        i = i + 1
    end
    return 0 - 1

fn ast_to_ssa_resolve_field_offset ctx sname fname
    // WHY: Resolves exact 8-byte struct field offset in O(1); returns -1 if missing or ambiguous across structs.
    si = ast_to_ssa_find_struct_idx(ctx, sname)
    if si >= 0
        flist = ctx.ctx_struct_fields[si]
        fi = 0
        while fi < flist.len()
            if flist[fi] == fname
                return fi * 8
            end
            fi = fi + 1
        end
        return 0 - 1
    end
    if ctx.ctx_field_uniq_off != 0
        if has_key(ctx.ctx_field_uniq_off, fname) == 1
            uo = ctx.ctx_field_uniq_off[fname]
            if uo > 0
                return uo - 1
            end
        end
        return 0 - 1
    end
    found_off = 0 - 1
    i = 0
    while i < ctx.ctx_struct_fields.len()
        flist = ctx.ctx_struct_fields[i]
        fi = 0
        while fi < flist.len()
            if flist[fi] == fname
                off = fi * 8
                if found_off < 0
                    found_off = off
                elif found_off != off
                    return 0 - 1
                end
            end
            fi = fi + 1
        end
        i = i + 1
    end
    return found_off

fn ast_to_ssa_resolve_field_type ctx sname fname
    // WHY: Returns exact normalized field type ("f64", "str", nested struct, or "i64") so
    // f64 struct fields (e.g. XorBrain.w11) never trigger bogus OP_I2F cvtsi2sd bit corruption!
    if ctx.ctx_field_type_map != 0
        if sname != 0 and sname != "" and sname != "i64" and sname != "i64_int" and sname != "ptr"
            k_full = sname + "::" + fname
            if has_key(ctx.ctx_field_type_map, k_full) == 1
                ft = ctx.ctx_field_type_map[k_full]
                if ft != 0 and ft != ""
                    return ft
                end
            end
        end
        k_u = "::" + fname
        if has_key(ctx.ctx_field_type_map, k_u) == 1
            ft_u = ctx.ctx_field_type_map[k_u]
            if ft_u != 0 and ft_u != ""
                return ft_u
            end
        end
    end
    return "i64"
end

fn ast_to_ssa_find_user_fn_idx ctx fname
    if ctx.ctx_fn_idx_map != 0 and has_key(ctx.ctx_fn_idx_map, fname) == 1
        return ctx.ctx_fn_idx_map[fname] - 1
    end
    i = 0
    while i < ctx.ctx_fn_names.len()
        if ctx.ctx_fn_names[i] == fname
            return i
        end
        i = i + 1
    end
    return 0 - 1

fn ast_to_ssa_is_mut_global ctx name
    if len(name) >= 2 and str_sub(name, 0, 2) == "g_"
        return 1
    end
    if ctx.ctx_mod_mut_globals != 0 and has_key(ctx.ctx_mod_mut_globals, name) == 1
        return 1
    end
    return 0

fn ast_to_ssa_get_var_int_type ctx name
    idx = ast_to_ssa_find_var_idx(ctx, name)
    if idx >= 0 and idx < ctx.ctx_var_int_types.len()
        return get(ctx.ctx_var_int_types, idx)
    end
    return ""

fn ast_to_ssa_set_var_int_type ctx name itype
    idx = ast_to_ssa_find_var_idx(ctx, name)
    if idx >= 0 and idx < ctx.ctx_var_int_types.len()
        list_set(ctx.ctx_var_int_types, idx, itype)
    end
    return 0

fn ast_to_ssa_emit_truncate_int_width ctx val itype
    // WHY: Emits exact bit-width wrapping/sign-extension in SSA IR for u8/u16/u32/i8/i16/i32.
    if ssa_is_narrow_int_type(itype) == 0
        return val
    end
    fn_obj = ctx.ctx_curr_fn
    if itype == "u8" or itype == "byte"
        res = fn_obj.new_val("i64_int")
        mask = ssa_value_new_const(255, "i64_int")
        inst = ir_build_binop(ctx.ctx_inst_counter, OP_AND, res, val, mask)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, inst)
        return res
    elif itype == "u16"
        res = fn_obj.new_val("i64_int")
        mask = ssa_value_new_const(65535, "i64_int")
        inst = ir_build_binop(ctx.ctx_inst_counter, OP_AND, res, val, mask)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, inst)
        return res
    elif itype == "u32"
        res = fn_obj.new_val("i64_int")
        mask = ssa_value_new_const(4294967295, "i64_int")
        inst = ir_build_binop(ctx.ctx_inst_counter, OP_AND, res, val, mask)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, inst)
        return res
    else
        sh = 32
        if itype == "i8" sh = 56
        elif itype == "i16" sh = 48 end
        sh_c = ssa_value_new_const(sh, "i64_int")
        t1 = fn_obj.new_val("i64_int")
        i1 = ir_build_binop(ctx.ctx_inst_counter, OP_SHL, t1, val, sh_c)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, i1)
        t2 = fn_obj.new_val("i64_int")
        i2 = ir_build_binop(ctx.ctx_inst_counter, OP_SHR, t2, t1, sh_c)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, i2)
        return t2
    end

// ── 2. Variable Scope & Alloca Slot Management ────────────────────────────────

fn ast_to_ssa_find_var_idx ctx name
    i = len(ctx.ctx_var_names) - 1
    while i >= 0
        if get(ctx.ctx_var_names, i) == name
            return i
        end
        i = i - 1
    end
    return 0 - 1

fn ast_to_ssa_find_var ctx name
    idx = ast_to_ssa_find_var_idx(ctx, name)
    if idx >= 0
        return get(ctx.ctx_var_slots, idx)
    end
    return 0

fn ast_to_ssa_get_var_type ctx name
    idx = ast_to_ssa_find_var_idx(ctx, name)
    if idx >= 0 and idx < ctx.ctx_var_types.len()
        return get(ctx.ctx_var_types, idx)
    end
    return "i64"

fn ast_to_ssa_set_var_type ctx name vtype
    idx = ast_to_ssa_find_var_idx(ctx, name)
    if idx >= 0 and idx < ctx.ctx_var_types.len()
        list_set(ctx.ctx_var_types, idx, vtype)
    end
    return 0

fn ast_to_ssa_alloc_var ctx name elem_type
    // WHY: Allocates a dedicated alloca slot in the entry block for mutable local variable
    fn_obj = ctx.ctx_curr_fn
    slot_id = "%slot_" + name
    slot_ptr = ssa_value_new_inst(slot_id, "ptr", 0)
    alloca_inst = ir_build_alloca(ctx.ctx_inst_counter, slot_ptr, elem_type, 0)
    ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1

    // Always place allocas at the entry block to guarantee lifetime over entire function
    basic_block_prepend_inst(fn_obj.entry_block, alloca_inst)
    ir_function_register_alloca(fn_obj, alloca_inst)

    push(ctx.ctx_var_names, name)
    push(ctx.ctx_var_slots, slot_ptr)
    push(ctx.ctx_var_types, elem_type)
    push(ctx.ctx_var_int_types, "")
    return slot_ptr

fn ast_to_ssa_get_or_alloc_var ctx name
    existing = ast_to_ssa_find_var(ctx, name)
    if existing != 0
        return existing
    return ast_to_ssa_alloc_var(ctx, name, "i64")

fn ast_to_ssa_emit_load_typed ctx ptr_slot vtype
    // WHY: Emits OP_LOAD preserving exact local type ("i64", "f64", "str", or struct name)
    fn_obj = ctx.ctx_curr_fn
    res_val = fn_obj.new_val(vtype)
    load_inst = ir_build_load(ctx.ctx_inst_counter, res_val, ptr_slot)
    ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
    basic_block_append_inst(ctx.ctx_curr_bb, load_inst)
    return res_val

fn ast_to_ssa_emit_load ctx ptr_slot
    return ast_to_ssa_emit_load_typed(ctx, ptr_slot, "i64")

// ── 3. Operator Mapping ───────────────────────────────────────────────────────

fn ast_to_ssa_map_binop op_str
    // WHY: Fast mapping from syntactic string operators (and compound AssignOp strings) to numeric SSA opcodes
    if op_str == "+" or op_str == "+=" or op_str == "যোগ" return OP_ADD
    if op_str == "-" or op_str == "-=" or op_str == "বিয়োগ" return OP_SUB
    if op_str == "*" or op_str == "*=" or op_str == "গুণ" return OP_MUL
    if op_str == "@" or op_str == "ম্যাট্রিক্স_গুণ" return OP_MUL
    if op_str == "/" or op_str == "/=" or op_str == "ভাগ" return OP_DIV
    if op_str == "%" or op_str == "%=" or op_str == "ভাগশেষ" return OP_MOD
    if op_str == "&" or op_str == "&=" or op_str == "এবং" return OP_AND
    if op_str == "|" or op_str == "|=" or op_str == "বা" return OP_OR
    if op_str == "^" or op_str == "^=" or op_str == "জর" return OP_XOR
    if op_str == "<<" or op_str == "<<=" or op_str == "বাম_সরাও" return OP_SHL
    if op_str == ">>" or op_str == ">>=" or op_str == "ডান_সরাও" return OP_SHR
    return OP_ADD

fn ast_to_ssa_map_cmp op_str
    // WHY: Maps relational operators to unified OP_CMP predicate enums
    if op_str == "==" or op_str == "সমান" return CMP_EQ
    if op_str == "!=" or op_str == "অসমান" return CMP_NE
    if op_str == "<"  or op_str == "ছোট" return CMP_SLT
    if op_str == "<=" or op_str == "ছোট_বা_সমান" return CMP_SLE
    if op_str == ">"  or op_str == "বড়" return CMP_SGT
    if op_str == ">=" or op_str == "বড়_বা_সমান" return CMP_SGE
    return CMP_EQ

fn ast_to_ssa_is_cmp_op op_str
    if op_str == "==" or op_str == "সমান" return 1
    if op_str == "!=" or op_str == "অসমান" return 1
    if op_str == "<"  or op_str == "ছোট" return 1
    if op_str == "<=" or op_str == "ছোট_বা_সমান" return 1
    if op_str == ">"  or op_str == "বড়" return 1
    if op_str == ">=" or op_str == "বড়_বা_সমান" return 1
    return 0

// ── 4. Expression Lowering ────────────────────────────────────────────────────

fn ast_to_ssa_is_pure_int val
    // WHY: Distinguishes provably pure integer/bool SSA values ("i64_int"/"bool"/int const)
    // from untyped dynamic values ("i64" from unannotated params/fields/calls that may hold STR0 pointers).
    if val == 0 return 0
    if val.vtype == "i64_int" or val.vtype == "bool"
        return 1
    end
    if (val.kind == VAL_KIND_CONST or val.val_kind == VAL_KIND_CONST) and val.vtype == "i64"
        return 1
    end
    return 0

fn ast_to_ssa_ensure_f64 ctx val
    // WHY: Promotes an i64 SSA value to f64 via OP_I2F for mixed int/float arithmetic or explicit f64 returns.
    if val != 0 and val.vtype == "f64"
        return val
    end
    fn_obj = ctx.ctx_curr_fn
    res_f = fn_obj.new_val("f64")
    i2f_inst = ir_build_unary(ctx.ctx_inst_counter, OP_I2F, res_f, val)
    ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
    basic_block_append_inst(ctx.ctx_curr_bb, i2f_inst)
    return res_f

fn ast_to_ssa_lower_expr ctx expr
    // WHY: Recursively transforms AST expression tree into typed SSA instruction sequence
    // supporting i64, f64 floats, STR0 string literals, structs, and inter-function calls.
    if expr == 0
        return ssa_value_new_const(0, "i64")

    ekind = ""
    if expr.kind != 0
        ekind = expr.kind

    // 1. Literal Integer / Boolean / Float / String
    if ekind == "LiteralInt" or ekind == "LiteralBool" or ekind == "IntLiteral"
        return ssa_value_new_const(expr.val, "i64_int")

    if ekind == "LiteralFloat" or ekind == "FloatLiteral"
        ftext = ""
        if expr.name != 0
            ftext = expr.name
        end
        if ftext == ""
            ctx.ctx_has_unsupported = 1
            return ssa_value_new_const(0, "f64")
        end
        fbits = ssa_parse_float_bits(ftext)
        return ssa_value_new_const(fbits, "f64")

    if ekind == "LiteralNone" or ekind == "None"
        return ssa_value_new_const(0, "i64_int")
    end

    if ekind == "LiteralStr" or ekind == "StrLiteral"
        stext = ""
        if expr.name != 0
            stext = expr.name
        end
        if expr.op == "interp"
            // Only bail on actual `${...}` or `{ident}` interpolation; keep literal JSON/CSS/code strings like "body {margin:0}" in SSA!
            has_real_interp = 0
            si_chk = 0
            sn_chk = len(stext)
            while si_chk < sn_chk
                cb_chk = mem_byte_read(stext, si_chk)
                if cb_chk == 36 and si_chk + 1 < sn_chk and mem_byte_read(stext, si_chk + 1) == 123
                    has_real_interp = 1
                    break
                elif cb_chk == 123 and si_chk + 1 < sn_chk
                    sj_chk = si_chk + 1
                    ok_id = 1
                    id_len_c = 0
                    while sj_chk < sn_chk and mem_byte_read(stext, sj_chk) != 125
                        ic = mem_byte_read(stext, sj_chk)
                        if (ic >= 65 and ic <= 90) or (ic >= 97 and ic <= 122) or (ic >= 48 and ic <= 57) or ic == 95 or ic >= 128
                            id_len_c = id_len_c + 1
                        else
                            ok_id = 0
                            break
                        end
                        sj_chk = sj_chk + 1
                    end
                    if ok_id == 1 and id_len_c > 0 and sj_chk < sn_chk and mem_byte_read(stext, sj_chk) == 125
                        has_real_interp = 1
                        break
                    end
                end
                si_chk = si_chk + 1
            end
            if has_real_interp == 1
                ctx.ctx_has_unsupported = 1
                return ssa_value_new_const(0, "str")
            end
        end
        fn_obj = ctx.ctx_curr_fn
        res_s = fn_obj.new_val("str")
        s_inst = ir_build_str_lit(ctx.ctx_inst_counter, res_s, stext)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, s_inst)
        return res_s

    if ekind == "Literal"
        ctx.ctx_has_unsupported = 1
        return ssa_value_new_const(0, "ptr")

    // 2. Variable Reference (Local / Parameter / Immutable Module-Level Integer Constant)
    if ekind == "Variable" or ekind == "Ident"
        var_name = expr.name
        slot = ast_to_ssa_find_var(ctx, var_name)
        if slot != 0
            vt = ast_to_ssa_get_var_type(ctx, var_name)
            return ast_to_ssa_emit_load_typed(ctx, slot, vt)
        end
        if ctx.ctx_mod_const_map != 0 and has_key(ctx.ctx_mod_const_map, var_name) == 1
            return ssa_value_new_const(ctx.ctx_mod_const_map[var_name], "i64_int")
        end
        // Fallback for unbound / mutable global symbols
        ctx.ctx_has_unsupported = 1
        return ssa_value_new_const(0, "i64")

    // 2a. Subscript Indexing: arr[idx] / dict[key] / str[idx]
    if ekind == "Index"
        cont_node = expr.left
        if cont_node == 0
            cont_node = expr.target
        end
        idx_node = expr.index
        if cont_node == 0 or idx_node == 0
            ctx.ctx_has_unsupported = 1
            return ssa_value_new_const(0, "i64")
        end
        saved_mb_idx = ctx.ctx_in_member_base
        ctx.ctx_in_member_base = 0
        cont_v = ast_to_ssa_lower_expr(ctx, cont_node)
        idx_v = ast_to_ssa_lower_expr(ctx, idx_node)
        ctx.ctx_in_member_base = saved_mb_idx
        is_local_nf = 0
        if cont_node.kind == "Variable" or cont_node.kind == "Ident"
            if ctx.ctx_local_nonfloat_conts != 0 and has_key(ctx.ctx_local_nonfloat_conts, cont_node.name) == 1
                is_local_nf = 1
            end
        end
        if ctx.ctx_fn_has_float_cont == 1 or ctx.ctx_has_float_dict == 1
            ctx.ctx_has_unsupported = 1
        elif ctx.ctx_mod_has_float_cont == 1 and saved_mb_idx == 0 and is_local_nf == 0
            // WHY: Only fall back when module has float containers AND this subscript is neither a
            // locally proven non-float list/dict nor a struct-pointer base of `arr[i].field`.
            ctx.ctx_has_unsupported = 1
        end
        fn_obj = ctx.ctx_curr_fn
        get_res = fn_obj.new_val("i64")
        get_inst = ir_build_call(ctx.ctx_inst_counter, get_res, "_lipi_list_get", [cont_v, idx_v])
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, get_inst)
        return get_res
    end

    // 2a2. Array Literal: [e0, e1, ...]
    if ekind == "ArrayLit"
        fn_obj = ctx.ctx_curr_fn
        arr_v = fn_obj.new_val("i64")
        mk_inst = ir_build_call(ctx.ctx_inst_counter, arr_v, "lipi_fn_list", list())
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, mk_inst)
        if expr.elements != 0
            aei = 0
            aec = len(expr.elements)
            while aei < aec
                el_v = ast_to_ssa_lower_expr(ctx, get(expr.elements, aei))
                if el_v.vtype == "f64"
                    ctx.ctx_has_float_dict = 1
                end
                p_tmp = fn_obj.new_val("i64")
                p_inst = ir_build_call(ctx.ctx_inst_counter, p_tmp, "_lipi_list_push", [arr_v, el_v])
                ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
                basic_block_append_inst(ctx.ctx_curr_bb, p_inst)
                aei = aei + 1
            end
        end
        return arr_v
    end

    // 2a3. Map / Dict Literal: {} or {"k": v, ...} (unquoted record literals { f: v } stay in x86_synth)
    if ekind == "MapLit"
        all_str_keys = 1
        if expr.elements != 0 and len(expr.elements) > 0
            mki = 0
            while mki < len(expr.elements)
                mel = get(expr.elements, mki)
                if mel == 0 or mel.op != "str_key" or mel.name == "__computed__"
                    all_str_keys = 0
                    break
                end
                mki = mki + 1
            end
        end
        if all_str_keys == 0
            ctx.ctx_has_unsupported = 1
            return ssa_value_new_const(0, "i64")
        end
        fn_obj = ctx.ctx_curr_fn
        d_v = fn_obj.new_val("i64")
        dn_inst = ir_build_call(ctx.ctx_inst_counter, d_v, "_lipi_dict_new", [ssa_value_new_const(16, "i64_int")])
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, dn_inst)
        if expr.elements != 0
            mei = 0
            mec = len(expr.elements)
            while mei < mec
                mel2 = get(expr.elements, mei)
                k_val = fn_obj.new_val("str")
                ks_inst = ir_build_str_lit(ctx.ctx_inst_counter, k_val, mel2.name)
                ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
                basic_block_append_inst(ctx.ctx_curr_bb, ks_inst)
                mv_val = ast_to_ssa_lower_expr(ctx, mel2.value)
                dt_tmp = fn_obj.new_val("i64")
                if mv_val.vtype == "f64"
                    ctx.ctx_has_float_dict = 1
                    ds_inst = ir_build_call(ctx.ctx_inst_counter, dt_tmp, "_lipi_list_set_typed", [d_v, k_val, mv_val, ssa_value_new_const(1, "i64_int")])
                elif mv_val.vtype == "str"
                    ds_inst = ir_build_call(ctx.ctx_inst_counter, dt_tmp, "_lipi_list_set_typed", [d_v, k_val, mv_val, ssa_value_new_const(2, "i64_int")])
                else
                    ds_inst = ir_build_call(ctx.ctx_inst_counter, dt_tmp, "_lipi_list_set", [d_v, k_val, mv_val])
                end
                ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
                basic_block_append_inst(ctx.ctx_curr_bb, ds_inst)
                mei = mei + 1
            end
        end
        return d_v
    end

    // 2b. Struct Member Access: obj.field
    if ekind == "MemberAccess"
        obj_node = expr.left
        if obj_node == 0
            obj_node = expr.target
        end
        prev_mb = ctx.ctx_in_member_base
        ctx.ctx_in_member_base = 1
        obj_val = ast_to_ssa_lower_expr(ctx, obj_node)
        ctx.ctx_in_member_base = prev_mb
        fname = ""
        if expr.name != 0
            fname = expr.name
        end
        byte_off = ast_to_ssa_resolve_field_offset(ctx, obj_val.vtype, fname)
        if byte_off < 0
            ctx.ctx_has_unsupported = 1
            return ssa_value_new_const(0, "i64")
        end
        fn_obj = ctx.ctx_curr_fn
        fld_t = ast_to_ssa_resolve_field_type(ctx, obj_val.vtype, fname)
        fres = fn_obj.new_val(fld_t)
        fl_inst = ir_build_field_load(ctx.ctx_inst_counter, fres, obj_val, byte_off)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, fl_inst)
        return fres

    // 3. Binary Operation (Short-Circuit Logical &&/||, i64, & IEEE-754 f64)
    if ekind == "BinaryOp"
        fn_obj = ctx.ctx_curr_fn
        op_str = expr.op

        // 3a. Short-circuit logical AND (`&&`, `and`, `এবং`)
        if op_str == "&&" or op_str == "and" or op_str == "এবং"
            sc_slot = ast_to_ssa_alloc_var(ctx, "__ssa_and_" + str(ctx.ctx_inst_counter), "i64_int")
            lhs_sc = ast_to_ssa_lower_expr(ctx, expr.left)
            zero_c = ssa_value_new_const(0, "i64_int")
            st0 = ir_build_store(ctx.ctx_inst_counter, zero_c, sc_slot)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, st0)
            rhs_bb = fn_obj.create_block("and_rhs")
            merge_bb = fn_obj.create_block("and_merge")
            br_sc = ir_build_br(ctx.ctx_inst_counter, lhs_sc, rhs_bb.label, merge_bb.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, br_sc)
            ctx.ctx_curr_bb = rhs_bb
            rhs_sc = ast_to_ssa_lower_expr(ctx, expr.right)
            rhs_bool = fn_obj.new_val("bool")
            cmp_nz = ir_build_cmp(ctx.ctx_inst_counter, CMP_NE, rhs_bool, rhs_sc, zero_c)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, cmp_nz)
            st1 = ir_build_store(ctx.ctx_inst_counter, rhs_bool, sc_slot)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, st1)
            jmp_m = ir_build_jmp(ctx.ctx_inst_counter, merge_bb.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, jmp_m)
            ctx.ctx_curr_bb = merge_bb
            return ast_to_ssa_emit_load_typed(ctx, sc_slot, "bool")
        end

        // 3b. Short-circuit logical OR (`||`, `or`, `অথবা`)
        if op_str == "||" or op_str == "or" or op_str == "অথবা"
            sc_slot = ast_to_ssa_alloc_var(ctx, "__ssa_or_" + str(ctx.ctx_inst_counter), "i64_int")
            lhs_sc = ast_to_ssa_lower_expr(ctx, expr.left)
            one_c = ssa_value_new_const(1, "i64_int")
            zero_c = ssa_value_new_const(0, "i64_int")
            st1 = ir_build_store(ctx.ctx_inst_counter, one_c, sc_slot)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, st1)
            rhs_bb = fn_obj.create_block("or_rhs")
            merge_bb = fn_obj.create_block("or_merge")
            br_sc = ir_build_br(ctx.ctx_inst_counter, lhs_sc, merge_bb.label, rhs_bb.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, br_sc)
            ctx.ctx_curr_bb = rhs_bb
            rhs_sc = ast_to_ssa_lower_expr(ctx, expr.right)
            rhs_bool = fn_obj.new_val("bool")
            cmp_nz = ir_build_cmp(ctx.ctx_inst_counter, CMP_NE, rhs_bool, rhs_sc, zero_c)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, cmp_nz)
            st2 = ir_build_store(ctx.ctx_inst_counter, rhs_bool, sc_slot)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, st2)
            jmp_m = ir_build_jmp(ctx.ctx_inst_counter, merge_bb.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, jmp_m)
            ctx.ctx_curr_bb = merge_bb
            return ast_to_ssa_emit_load_typed(ctx, sc_slot, "bool")
        end

        lhs_val = ast_to_ssa_lower_expr(ctx, expr.left)
        rhs_val = ast_to_ssa_lower_expr(ctx, expr.right)

        if op_str == "@"
            ctx.ctx_has_unsupported = 1
        end
        is_str_op = 0
        if lhs_val.vtype == "str" or rhs_val.vtype == "str"
            is_str_op = 1
        end
        is_flt = 0
        if lhs_val.vtype == "f64" or rhs_val.vtype == "f64"
            is_flt = 1
        end
        if is_flt == 1
            if is_str_op == 1
                ctx.ctx_has_unsupported = 1
            end
            fl = ast_to_ssa_ensure_f64(ctx, lhs_val)
            fr = ast_to_ssa_ensure_f64(ctx, rhs_val)
            if ast_to_ssa_is_cmp_op(op_str) == 1
                pred = ast_to_ssa_map_cmp(op_str)
                res_val = fn_obj.new_val("bool")
                fcmp_inst = ir_build_fcmp(ctx.ctx_inst_counter, pred, res_val, fl, fr)
                ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
                basic_block_append_inst(ctx.ctx_curr_bb, fcmp_inst)
                return res_val
            else
                fop = 0
                if op_str == "+" or op_str == "+=" or op_str == "যোগ" fop = OP_FADD
                elif op_str == "-" or op_str == "-=" or op_str == "বিয়োগ" fop = OP_FSUB
                elif op_str == "*" or op_str == "*=" or op_str == "গুণ" fop = OP_FMUL
                elif op_str == "/" or op_str == "/=" or op_str == "ভাগ" fop = OP_FDIV
                else
                    ctx.ctx_has_unsupported = 1
                    return fl
                end
                res_val = fn_obj.new_val("f64")
                fbin_inst = ir_build_binop(ctx.ctx_inst_counter, fop, res_val, fl, fr)
                ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
                basic_block_append_inst(ctx.ctx_curr_bb, fbin_inst)
                return res_val
            end
        end
        both_int = 0
        if ast_to_ssa_is_pure_int(lhs_val) == 1 and ast_to_ssa_is_pure_int(rhs_val) == 1
            both_int = 1
        end
        any_int = 0
        if ast_to_ssa_is_pure_int(lhs_val) == 1 or ast_to_ssa_is_pure_int(rhs_val) == 1
            any_int = 1
        end
        if ast_to_ssa_is_cmp_op(op_str) == 1
            pred = ast_to_ssa_map_cmp(op_str)
            res_val = fn_obj.new_val("bool")
            // WHY: Non-x86_64 targets (WASM/ARM64/RV64) do not have x86_64 STR0 polymorphic
            // _lipi_cmp_dynamic runtime tagging; non-string compares are direct integer OP_CMP.
            if both_int == 1 or (is_str_op == 0 and ctx.ctx_target_name != "x86_64")
                cmp_inst = ir_build_cmp(ctx.ctx_inst_counter, pred, res_val, lhs_val, rhs_val)
            else
                cmp_inst = ir_build_cmp_dyn(ctx.ctx_inst_counter, pred, res_val, lhs_val, rhs_val)
            end
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, cmp_inst)
            return res_val
        else
            op_code = ast_to_ssa_map_binop(op_str)
            // WHY: Match canonical x86_64/codegen_operators.lp:951 semantics:
            // (left_is_int OR right_is_int) AND neither side is statically "str" => raw integer/pointer
            // addition; on non-x86_64 targets (WASM/ARM64/RV64), non-string `+` is direct integer OP_ADD.
            if op_code == OP_ADD and (is_str_op == 1 or (any_int == 0 and ctx.ctx_target_name == "x86_64"))
                res_t = "i64"
                if is_str_op == 1
                    res_t = "str"
                end
                res_val = fn_obj.new_val(res_t)
                bin_inst = ir_build_binop(ctx.ctx_inst_counter, OP_ADD_DYN, res_val, lhs_val, rhs_val)
                ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
                basic_block_append_inst(ctx.ctx_curr_bb, bin_inst)
                return res_val
            end
            if is_str_op == 1
                ctx.ctx_has_unsupported = 1
            end
            res_val = fn_obj.new_val("i64_int")
            bin_inst = ir_build_binop(ctx.ctx_inst_counter, op_code, res_val, lhs_val, rhs_val)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, bin_inst)
            return res_val
        end

    // 4. Unary Operation
    if ekind == "UnaryOp"
        sub_val = ast_to_ssa_lower_expr(ctx, expr.expr)
        fn_obj = ctx.ctx_curr_fn
        if expr.op == "-" or expr.op == "নেগেটিভ"
            if sub_val.vtype == "f64"
                res_val = fn_obj.new_val("f64")
                fneg_inst = ir_build_unary(ctx.ctx_inst_counter, OP_FNEG, res_val, sub_val)
                ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
                basic_block_append_inst(ctx.ctx_curr_bb, fneg_inst)
                return res_val
            end
            res_val = fn_obj.new_val("i64_int")
            neg_inst = ir_build_neg(ctx.ctx_inst_counter, res_val, sub_val)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, neg_inst)
            return res_val
        elif expr.op == "!" or expr.op == "not" or expr.op == "না"
            // Logical NOT: compare sub_val == 0
            res_val = fn_obj.new_val("bool")
            zero_const = ssa_value_new_const(0, "i64")
            cmp_inst = ir_build_cmp(ctx.ctx_inst_counter, CMP_EQ, res_val, sub_val, zero_const)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, cmp_inst)
            return res_val
        elif expr.op == "~"
            // Bitwise NOT: sub_val ^ -1
            res_val = fn_obj.new_val("i64_int")
            neg1_const = ssa_value_new_const(0 - 1, "i64_int")
            xor_inst = ir_build_binop(ctx.ctx_inst_counter, OP_XOR, res_val, sub_val, neg1_const)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, xor_inst)
            return res_val
        end
        ctx.ctx_has_unsupported = 1
        return sub_val

    // 5. Function Call, Method Call, OR Struct Constructor
    if ekind == "Call"
        fn_obj = ctx.ctx_curr_fn
        callee_name = expr.name
        arg_values = list()

        // 5-pre. Method Call: obj.method(args...)
        if expr.func != 0 and expr.func.kind == "MemberAccess"
            recv_node = expr.func.left
            if recv_node == 0 recv_node = expr.func.target end
            recv_val = ast_to_ssa_lower_expr(ctx, recv_node)
            arg_nodes_m = expr.params
            if arg_nodes_m == 0 arg_nodes_m = expr.args end
            if arg_nodes_m != 0
                mai = 0
                mac = len(arg_nodes_m)
                while mai < mac
                    push(arg_values, ast_to_ssa_lower_expr(ctx, get(arg_nodes_m, mai)))
                    mai = mai + 1
                end
            end
            mc = arg_values.len()
            m_callee = ""
            m_ret_t = "i64"
            m_args = list()
            push(m_args, recv_val)
            mbi = 0
            while mbi < mc
                push(m_args, arg_values[mbi])
                mbi = mbi + 1
            end
            if (callee_name == "len" or callee_name == "length" or callee_name == "দৈর্ঘ্য") and mc == 0
                m_callee = "_lipi_len"
                m_ret_t = "i64_int"
            elif (callee_name == "push" or callee_name == "append" or callee_name == "ঠেলো") and mc == 1
                m_callee = "_lipi_list_push"
                m_ret_t = "i64"
            elif (callee_name == "pop" or callee_name == "বাদ_দাও") and mc == 0
                m_callee = "_lipi_list_pop"
                m_ret_t = "i64"
            elif callee_name == "get" and mc == 1
                m_callee = "_lipi_list_get"
                m_ret_t = "i64"
            elif callee_name == "has" and mc == 1
                m_callee = "_lipi_dict_has"
                m_ret_t = "i64_int"
            elif callee_name == "keys" and mc == 0
                m_callee = "_lipi_dict_keys"
                m_ret_t = "i64"
            elif callee_name == "values" and mc == 0
                m_callee = "_lipi_dict_values"
                m_ret_t = "i64"
            else
                // Direct struct impl method resolution (`Type_method`, matching pipeline.lp mangling!)
                m_uf = 0 - 1
                m_full = ""
                if ast_to_ssa_find_struct_idx(ctx, recv_val.vtype) >= 0
                    m_full = recv_val.vtype + "_" + callee_name
                    m_uf = ast_to_ssa_find_user_fn_idx(ctx, m_full)
                end
                if m_uf >= 0 and m_args.len() <= 16 and m_args.len() == ctx.ctx_fn_param_cnts[m_uf]
                    m_callee = m_full
                    m_ret_t = ctx.ctx_fn_ret_types[m_uf]
                    if m_uf < ctx.ctx_fn_param_types.len()
                        m_ptypes = ctx.ctx_fn_param_types[m_uf]
                        mpi_c = 0
                        while mpi_c < m_args.len() and mpi_c < m_ptypes.len()
                            if m_args[mpi_c].vtype == "f64" and m_ptypes[mpi_c] != "f64"
                                ctx.ctx_has_unsupported = 1
                                break
                            end
                            mpi_c = mpi_c + 1
                        end
                    end
                else
                    ctx.ctx_has_unsupported = 1
                    return ssa_value_new_const(0, "i64")
                end
            end
            m_res = fn_obj.new_val(m_ret_t)
            m_inst = ir_build_call(ctx.ctx_inst_counter, m_res, m_callee, m_args)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, m_inst)
            return m_res
        end

        // Lower all arguments monotonically
        arg_nodes = expr.params
        if arg_nodes == 0
            arg_nodes = expr.args
        if arg_nodes != 0
            ai = 0
            acnt = len(arg_nodes)
            while ai < acnt
                anode = get(arg_nodes, ai)
                aval = ast_to_ssa_lower_expr(ctx, anode)
                push(arg_values, aval)
                ai = ai + 1

        // 5a. Struct Constructor: Point(x, y)
        s_idx = ast_to_ssa_find_struct_idx(ctx, callee_name)
        if s_idx >= 0
            s_fields = ctx.ctx_struct_fields[s_idx]
            alloc_sz = (s_fields.len() + 1) * 8
            if alloc_sz < 32
                alloc_sz = 32
            end
            s_res = fn_obj.new_val(callee_name)
            sn_inst = ir_build_struct_new(ctx.ctx_inst_counter, s_res, callee_name, alloc_sz, arg_values)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, sn_inst)
            return s_res
        end

        // 5b. Inter-Function Call to known user function (up to 16 args) OR verified SysV ABI runtime builtin
        ac = arg_values.len()

        // Hardware syscall intrinsics must always be lowered by the target backend, never as a regular user fn call
        if callee_name == "syscall" or callee_name == "সিসকল" or callee_name == "sys_syscall"
            ctx.ctx_has_unsupported = 1
            return ssa_value_new_const(0, "i64")
        end

        // 5b-pre. Direct IEEE-754 bitcast & raw f64 memory intrinsics (zero cvtsi2sd conversion!)
        if callee_name == "f64_from_bits" and ac == 1
            bc_slot = fn_obj.new_val("ptr")
            bc_al = ir_build_alloca(ctx.ctx_inst_counter, bc_slot, "i64", 0)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_prepend_inst(fn_obj.entry_block, bc_al)
            ir_function_register_alloca(fn_obj, bc_al)
            bc_st = ir_build_store(ctx.ctx_inst_counter, arg_values[0], bc_slot)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, bc_st)
            return ast_to_ssa_emit_load_typed(ctx, bc_slot, "f64")
        elif callee_name == "f64_to_bits" and ac == 1
            bc_slot2 = fn_obj.new_val("ptr")
            bc_al2 = ir_build_alloca(ctx.ctx_inst_counter, bc_slot2, "i64", 0)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_prepend_inst(fn_obj.entry_block, bc_al2)
            ir_function_register_alloca(fn_obj, bc_al2)
            bc_st2 = ir_build_store(ctx.ctx_inst_counter, arg_values[0], bc_slot2)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, bc_st2)
            return ast_to_ssa_emit_load_typed(ctx, bc_slot2, "i64_int")
        elif (callee_name == "mem_read_f64" or callee_name == "মেমরি_দশমিক_পড়ো") and ac == 2
            f_rd = fn_obj.new_val("f64")
            f_rdi = ir_build_call(ctx.ctx_inst_counter, f_rd, "_lipi_mem_word_read", arg_values)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, f_rdi)
            return f_rd
        elif (callee_name == "mem_write_f64" or callee_name == "মেমরি_দশমিক_লেখো") and ac == 3
            f_wr = fn_obj.new_val("f64")
            f_wri = ir_build_call(ctx.ctx_inst_counter, f_wr, "_lipi_mem_word_write", arg_values)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, f_wri)
            return arg_values[2]
        elif callee_name == "mem_read_f32" or callee_name == "mem_write_f32"
            ctx.ctx_has_unsupported = 1
            return ssa_value_new_const(0, "f64")
        end

        uf_idx = ast_to_ssa_find_user_fn_idx(ctx, callee_name)
        call_ret_t = "i64"
        emit_callee = callee_name
        if uf_idx >= 0 and ac <= 16 and ac == ctx.ctx_fn_param_cnts[uf_idx]
            call_ret_t = ctx.ctx_fn_ret_types[uf_idx]
            // WHY: Untyped functions invoked with f64 arguments (e.g. add_untyped(1.25, 2.75)) rely on
            // x86_synth's float call-site monomorphization; fall back cleanly instead of calling the int body.
            if uf_idx < ctx.ctx_fn_param_types.len()
                uf_ptypes = ctx.ctx_fn_param_types[uf_idx]
                pti_c = 0
                while pti_c < ac and pti_c < uf_ptypes.len()
                    if arg_values[pti_c].vtype == "f64" and uf_ptypes[pti_c] != "f64"
                        ctx.ctx_has_unsupported = 1
                        break
                    end
                    pti_c = pti_c + 1
                end
            end
        elif (callee_name == "len" or callee_name == "দৈর্ঘ্য" or callee_name == "length" or callee_name == "str_len" or callee_name == "list_len") and ac == 1
            emit_callee = "_lipi_len"
            call_ret_t = "i64_int"
        elif (callee_name == "list" or callee_name == "তালিকা" or callee_name == "list_create") and ac == 0
            emit_callee = "lipi_fn_list"
            call_ret_t = "i64"
        elif (callee_name == "get" or callee_name == "নাও" or callee_name == "list_get") and ac == 2
            emit_callee = "_lipi_list_get"
            call_ret_t = "i64"
        elif (callee_name == "list_set" or callee_name == "সেট") and ac == 3
            if arg_values[2].vtype == "f64"
                ctx.ctx_has_float_dict = 1
                emit_callee = "_lipi_list_set_typed"
                push(arg_values, ssa_value_new_const(1, "i64_int"))
            elif arg_values[2].vtype == "str"
                emit_callee = "_lipi_list_set_typed"
                push(arg_values, ssa_value_new_const(2, "i64_int"))
            else
                emit_callee = "_lipi_list_set"
            end
            call_ret_t = "i64"
        elif (callee_name == "push" or callee_name == "list_push" or callee_name == "ঠেলো" or callee_name == "যোগ_করো") and ac == 2
            emit_callee = "_lipi_list_push"
            call_ret_t = "i64"
        elif (callee_name == "pop" or callee_name == "list_pop" or callee_name == "বাদ_দাও") and ac == 1
            emit_callee = "_lipi_list_pop"
            call_ret_t = "i64"
        elif (callee_name == "dict" or callee_name == "map_new") and (ac == 0 or ac == 1)
            emit_callee = "_lipi_dict_new"
            if ac == 0
                push(arg_values, ssa_value_new_const(0, "i64_int"))
            end
            call_ret_t = "i64"
        elif (callee_name == "has_key" or callee_name == "map_has") and ac == 2
            emit_callee = "_lipi_dict_has"
            call_ret_t = "i64_int"
        elif (callee_name == "del_key" or callee_name == "map_del") and ac == 2
            emit_callee = "_lipi_dict_del"
            call_ret_t = "i64_int"
        elif (callee_name == "keys" or callee_name == "map_keys") and ac == 1
            emit_callee = "_lipi_dict_keys"
            call_ret_t = "i64"
        elif (callee_name == "values" or callee_name == "map_values") and ac == 1
            emit_callee = "_lipi_dict_values"
            call_ret_t = "i64"
        elif (callee_name == "str" or callee_name == "to_str" or callee_name == "স্ট্রিং") and ac == 1
            if arg_values[0].vtype == "f64"
                emit_callee = "_lipi_float_to_str"
                call_ret_t = "str"
            elif ctx.ctx_has_float_dict == 1 and arg_values[0].vtype == "i64"
                ctx.ctx_has_unsupported = 1
            else
                emit_callee = "_lipi_ensure_str"
                call_ret_t = "str"
            end
        elif callee_name == "float_to_str" and ac == 1
            emit_callee = "_lipi_float_to_str"
            call_ret_t = "str"
        elif callee_name == "str_sub" and ac == 3
            emit_callee = "_lipi_str_sub"
            call_ret_t = "str"
        elif (callee_name == "char_at" or callee_name == "অক্ষর") and ac == 2
            emit_callee = "_lipi_char_at"
            call_ret_t = "str"
        elif (callee_name == "str_char_at" or callee_name == "mem_byte_read" or callee_name == "mem_read_byte" or callee_name == "মেমরি_বাইট_পড়ো" or callee_name == "sys_peek8") and ac == 2
            emit_callee = "_lipi_mem_byte_read"
            call_ret_t = "i64_int"
        elif (callee_name == "mem_byte_write" or callee_name == "mem_write_byte" or callee_name == "মেমরি_বাইট_লেখো" or callee_name == "sys_poke8") and ac == 3
            emit_callee = "_lipi_mem_byte_write"
            call_ret_t = "i64_int"
        elif (callee_name == "mem_word_read" or callee_name == "mem_read_word" or callee_name == "mem_read" or callee_name == "মেমরি_পড়ো" or callee_name == "মেমরি_শব্দ_পড়ো") and ac == 2
            emit_callee = "_lipi_mem_word_read"
            call_ret_t = "i64"
        elif (callee_name == "mem_word_write" or callee_name == "mem_write_word" or callee_name == "mem_write" or callee_name == "মেমরি_লেখো" or callee_name == "মেমরি_শব্দ_লেখো") and ac == 3
            emit_callee = "_lipi_mem_word_write"
            call_ret_t = "i64_int"
        elif (callee_name == "ord" or callee_name == "কোড" or callee_name == "ascii") and ac == 1
            emit_callee = "_lipi_ord"
            call_ret_t = "i64_int"
        elif (callee_name == "chr" or callee_name == "অক্ষর_চিহ্ন") and ac == 1
            emit_callee = "_lipi_chr"
            call_ret_t = "str"
        elif (callee_name == "is_str" or callee_name == "is_string") and ac == 1
            emit_callee = "_lipi_is_str"
            call_ret_t = "i64_int"
        elif (callee_name == "buf_new" or callee_name == "byte_buf_new" or callee_name == "বাফার_তৈরি") and ac == 1
            emit_callee = "_lipi_buf_new"
            call_ret_t = "i64"
        elif (callee_name == "buf_write_byte" or callee_name == "buf_append_byte" or callee_name == "buf_push" or callee_name == "বাফার_বাইট") and ac == 2
            emit_callee = "_lipi_buf_write_byte"
            call_ret_t = "i64_int"
        elif (callee_name == "buf_write_str" or callee_name == "buf_append" or callee_name == "buf_append_str" or callee_name == "বাফার_স্ট্রিং") and ac == 2
            emit_callee = "_lipi_buf_write_str"
            call_ret_t = "i64_int"
        elif (callee_name == "buf_write_mem" or callee_name == "buf_append_mem" or callee_name == "বাফার_লেখো_মেম") and ac == 3
            emit_callee = "_lipi_buf_write_mem"
            call_ret_t = "i64_int"
        elif (callee_name == "buf_to_str" or callee_name == "বাফার_স্ট্রিংয়ে") and ac == 1
            emit_callee = "_lipi_buf_to_str"
            call_ret_t = "str"
        elif (callee_name == "bytes_to_str" or callee_name == "mem_to_str" or callee_name == "বাইট_থেকে_স্ট্রিং") and ac == 2
            emit_callee = "_lipi_bytes_to_str"
            call_ret_t = "str"
        elif (callee_name == "buf_len" or callee_name == "বাফার_দৈর্ঘ্য") and ac == 1
            emit_callee = "_lipi_buf_len"
            call_ret_t = "i64_int"
        elif (callee_name == "buf_ptr" or callee_name == "বাফার_পয়েন্টার") and ac == 1
            emit_callee = "_lipi_buf_ptr"
            call_ret_t = "i64_int"
        elif (callee_name == "buf_clear" or callee_name == "বাফার_মুছো") and ac == 1
            emit_callee = "_lipi_buf_clear"
            call_ret_t = "i64_int"
        elif (callee_name == "buf_get_byte" or callee_name == "বাইট_পড়ো") and ac == 2
            emit_callee = "_lipi_buf_get_byte"
            call_ret_t = "i64_int"
        elif (callee_name == "buf_free" or callee_name == "বাফার_মুক্তি") and ac == 1
            emit_callee = "_lipi_buf_free"
            call_ret_t = "i64_int"
        elif (callee_name == "buf_slice" or callee_name == "bytes_slice" or callee_name == "বাইট_স্লাইস") and ac == 3
            emit_callee = "_lipi_buf_slice"
            call_ret_t = "i64"
        elif (callee_name == "alloc" or callee_name == "mem_alloc" or callee_name == "sys_alloc" or callee_name == "মেমরি_বরাদ্দ") and ac == 1
            emit_callee = "_lipi_user_alloc"
            call_ret_t = "i64"
        elif callee_name == "malloc" and ac == 1
            emit_callee = "_lipi_malloc"
            call_ret_t = "i64"
        elif (callee_name == "free" or callee_name == "mem_free" or callee_name == "sys_free" or callee_name == "মুক্ত" or callee_name == "মেমরি_মুক্তি" or callee_name == "drop") and (ac == 1 or ac == 2)
            emit_callee = "_lipi_user_free"
            arg_values = [arg_values[0]]
            call_ret_t = "i64_int"
        elif callee_name == "file_exists" and ac == 1
            emit_callee = "_lipi_file_exists"
            call_ret_t = "i64_int"
        elif callee_name == "file_read" and ac == 1
            emit_callee = "_lipi_file_read"
            call_ret_t = "str"
        elif callee_name == "file_write" and ac == 2
            emit_callee = "_lipi_file_write"
            call_ret_t = "i64_int"
        elif callee_name == "file_write_bytes" and ac == 2
            emit_callee = "_lipi_file_write_bytes"
            call_ret_t = "i64_int"
        elif (callee_name == "clock_ms" or callee_name == "time_now_ms" or callee_name == "time_now" or callee_name == "সময়_মিলি") and ac == 0
            emit_callee = "_lipi_clock_ms"
            call_ret_t = "i64_int"
        elif (callee_name == "exit" or callee_name == "sys_exit" or callee_name == "sys_exit_group" or callee_name == "প্রস্থান") and ac == 1
            emit_callee = "_lipi_sys_exit"
            call_ret_t = "i64_int"
        elif (callee_name == "gc_collect" or callee_name == "lipi_gc_collect" or callee_name == "আবর্জনা_পরিষ্কার") and ac == 0
            emit_callee = "_lipi_gc_collect"
            call_ret_t = "i64_int"
        elif (callee_name == "argv" or callee_name == "আর্গস") and ac == 0
            emit_callee = "lipi_fn_argv"
            call_ret_t = "i64"
        elif (callee_name == "arena_mark" or callee_name == "অ্যারেনা_চিহ্ন") and ac == 0
            emit_callee = "_lipi_arena_mark"
            call_ret_t = "i64_int"
        elif (callee_name == "arena_reset" or callee_name == "arena_rollback" or callee_name == "অ্যারেনা_রিসেট") and ac == 1
            emit_callee = "_lipi_arena_reset"
            call_ret_t = "i64_int"
        elif (callee_name == "say" or callee_name == "বলো" or callee_name == "print" or callee_name == "println") and ac == 1
            if arg_values[0].vtype == "f64"
                emit_callee = "_lipi_print_float"
                call_ret_t = "i64_int"
            elif ctx.ctx_has_float_dict == 1 and arg_values[0].vtype == "i64"
                ctx.ctx_has_unsupported = 1
            else
                emit_callee = "_lipi_print_dynamic"
                call_ret_t = "i64_int"
            end
        elif callee_name != fn_obj.name or ac > 16
            ctx.ctx_has_unsupported = 1
        end

        call_res = fn_obj.new_val(call_ret_t)
        call_inst = ir_build_call(ctx.ctx_inst_counter, call_res, emit_callee, arg_values)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, call_inst)
        return call_res

    // Default fallback
    ctx.ctx_has_unsupported = 1
    return ssa_value_new_const(0, "i64")

// ── 5. Statement Lowering ─────────────────────────────────────────────────────

fn ast_to_ssa_lower_stmt ctx stmt
    // WHY: Transforms statement constructs into basic blocks and instructions
    if stmt == 0 return 0
    if basic_block_get_terminator(ctx.ctx_curr_bb) != 0
        // Dead code elimination at lower level: block already concluded
        return 0

    skind = ""
    if stmt.kind != 0
        skind = stmt.kind

    // 1. Return Statement
    if skind == "Return"
        ret_expr = stmt.value
        if ret_expr != 0
            ret_val = ast_to_ssa_lower_expr(ctx, ret_expr)
            fn_rt = ctx.ctx_curr_fn.return_type
            if fn_rt == "f64" and ret_val.vtype != "f64"
                ret_val = ast_to_ssa_ensure_f64(ctx, ret_val)
            end
            rv_t = ret_val.vtype
            if rv_t == "bool" or rv_t == "i64_int"
                rv_t = "i64"
            end
            if ctx.ctx_inferred_ret == ""
                ctx.ctx_inferred_ret = rv_t
            elif ctx.ctx_inferred_ret != rv_t
                // Mixed return types across branches (e.g. int and float without explicit : f64)
                ctx.ctx_has_unsupported = 1
            end
            ret_inst = ir_build_ret(ctx.ctx_inst_counter, ret_val)
        else
            ret_inst = ir_build_ret_void(ctx.ctx_inst_counter)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, ret_inst)
        return 1

    // 2. Simple Variable Assignment, Indexed Assignment (a[i]=v), OR Chained Struct Field Assignment (a.b.c=v)
    if skind == "Assign"
        target_name = stmt.target
        if stmt.index != 0
            cont_v = 0
            if str_contains(target_name, "[") == 1
                ctx.ctx_has_unsupported = 1
                return 0
            elif str_contains(target_name, ".") == 1
                // Struct field array element store: a.items[i] = val
                fsegs = list()
                ftlen = len(target_name)
                fseg_st = 0
                fsi = 0
                while fsi <= ftlen
                    if fsi == ftlen or mem_byte_read(target_name, fsi) == 46
                        push(fsegs, str_slice(target_name, fseg_st, fsi))
                        fseg_st = fsi + 1
                    end
                    fsi = fsi + 1
                end
                if fsegs.len() < 2
                    ctx.ctx_has_unsupported = 1
                    return 0
                end
                fobj_slot = ast_to_ssa_find_var(ctx, fsegs[0])
                if fobj_slot == 0
                    ctx.ctx_has_unsupported = 1
                    return 0
                end
                fcur_t = ast_to_ssa_get_var_type(ctx, fsegs[0])
                fcur_v = ast_to_ssa_emit_load_typed(ctx, fobj_slot, fcur_t)
                fn_obj = ctx.ctx_curr_fn
                fsg = 1
                while fsg < fsegs.len()
                    foff_a = ast_to_ssa_resolve_field_offset(ctx, fcur_t, fsegs[fsg])
                    if foff_a < 0
                        ctx.ctx_has_unsupported = 1
                        return 0
                    end
                    ft_a = ast_to_ssa_resolve_field_type(ctx, fcur_t, fsegs[fsg])
                    fnxt_v = fn_obj.new_val(ft_a)
                    fl_a = ir_build_field_load(ctx.ctx_inst_counter, fnxt_v, fcur_v, foff_a)
                    ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
                    basic_block_append_inst(ctx.ctx_curr_bb, fl_a)
                    fcur_v = fnxt_v
                    fcur_t = ft_a
                    fsg = fsg + 1
                end
                cont_v = fcur_v
            else
                cont_slot = ast_to_ssa_find_var(ctx, target_name)
                if cont_slot == 0
                    ctx.ctx_has_unsupported = 1
                    return 0
                end
                cont_v = ast_to_ssa_emit_load_typed(ctx, cont_slot, ast_to_ssa_get_var_type(ctx, target_name))
            end
            idx_v = ast_to_ssa_lower_expr(ctx, stmt.index)
            rhs_v = ast_to_ssa_lower_expr(ctx, stmt.value)
            fn_obj = ctx.ctx_curr_fn
            s_tmp = fn_obj.new_val("i64")
            if rhs_v.vtype == "f64"
                ctx.ctx_has_float_dict = 1
                s_inst = ir_build_call(ctx.ctx_inst_counter, s_tmp, "_lipi_list_set_typed", [cont_v, idx_v, rhs_v, ssa_value_new_const(1, "i64_int")])
            elif rhs_v.vtype == "str"
                s_inst = ir_build_call(ctx.ctx_inst_counter, s_tmp, "_lipi_list_set_typed", [cont_v, idx_v, rhs_v, ssa_value_new_const(2, "i64_int")])
            else
                s_inst = ir_build_call(ctx.ctx_inst_counter, s_tmp, "_lipi_list_set", [cont_v, idx_v, rhs_v])
            end
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, s_inst)
            return 1
        elif str_contains(target_name, "[") == 1
            ctx.ctx_has_unsupported = 1
        elif str_contains(target_name, ".") == 1
            // Single or chained struct field store: a.b = v or a.b.c = v
            segs = list()
            tlen_s = len(target_name)
            seg_st = 0
            si_d = 0
            while si_d <= tlen_s
                if si_d == tlen_s or mem_byte_read(target_name, si_d) == 46
                    push(segs, str_slice(target_name, seg_st, si_d))
                    seg_st = si_d + 1
                end
                si_d = si_d + 1
            end
            if segs.len() < 2
                ctx.ctx_has_unsupported = 1
                return 0
            end
            obj_nm = segs[0]
            obj_slot = ast_to_ssa_find_var(ctx, obj_nm)
            if obj_slot == 0
                ctx.ctx_has_unsupported = 1
                return 0
            end
            cur_t = ast_to_ssa_get_var_type(ctx, obj_nm)
            cur_v = ast_to_ssa_emit_load_typed(ctx, obj_slot, cur_t)
            fn_obj = ctx.ctx_curr_fn
            sg_i = 1
            while sg_i < segs.len() - 1
                mid_off = ast_to_ssa_resolve_field_offset(ctx, cur_t, segs[sg_i])
                if mid_off < 0
                    ctx.ctx_has_unsupported = 1
                    return 0
                end
                mid_t = ast_to_ssa_resolve_field_type(ctx, cur_t, segs[sg_i])
                next_v = fn_obj.new_val(mid_t)
                fl_mid = ir_build_field_load(ctx.ctx_inst_counter, next_v, cur_v, mid_off)
                ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
                basic_block_append_inst(ctx.ctx_curr_bb, fl_mid)
                cur_v = next_v
                cur_t = mid_t
                sg_i = sg_i + 1
            end
            last_fld = segs[segs.len() - 1]
            byte_off = ast_to_ssa_resolve_field_offset(ctx, cur_t, last_fld)
            if byte_off < 0
                ctx.ctx_has_unsupported = 1
                return 0
            end
            rhs_v = ast_to_ssa_lower_expr(ctx, stmt.value)
            last_ft = ast_to_ssa_resolve_field_type(ctx, cur_t, last_fld)
            if last_ft == "f64" and rhs_v.vtype != "f64"
                rhs_v = ast_to_ssa_ensure_f64(ctx, rhs_v)
            end
            fs_inst = ir_build_field_store(ctx.ctx_inst_counter, cur_v, rhs_v, byte_off)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, fs_inst)
            return 1
        end
        slot_chk = ast_to_ssa_find_var(ctx, target_name)
        if slot_chk == 0 and ast_to_ssa_is_mut_global(ctx, target_name) == 1
            ctx.ctx_has_unsupported = 1
            return 0
        end
        raw_decl_t = ""
        decl_t = ""
        if stmt.op != 0 and stmt.op != ""
            raw_decl_t = stmt.op
            decl_t = ssa_normalize_type(raw_decl_t)
            if decl_t != "i64" and decl_t != "f64" and decl_t != "str" and ast_to_ssa_find_struct_idx(ctx, decl_t) < 0
                ctx.ctx_has_unsupported = 1
            end
        end
        rhs_val = ast_to_ssa_lower_expr(ctx, stmt.value)
        if ctx.ctx_local_nonfloat_conts != 0 and stmt.value != 0 and ctx.ctx_fn_has_float_cont == 0
            rk_v = stmt.value.kind
            if rk_v == "ArrayLit" or rk_v == "MapLit"
                ctx.ctx_local_nonfloat_conts[target_name] = 1
            elif rk_v == "Call" and (stmt.value.name == "list" or stmt.value.name == "dict" or stmt.value.name == "তালিকা" or stmt.value.name == "list_create" or stmt.value.name == "map_new")
                ctx.ctx_local_nonfloat_conts[target_name] = 1
            end
        end
        if decl_t == "f64" and rhs_val.vtype != "f64"
            rhs_val = ast_to_ssa_ensure_f64(ctx, rhs_val)
        end
        eff_itype = ""
        if ssa_is_narrow_int_type(raw_decl_t) == 1
            eff_itype = raw_decl_t
        elif raw_decl_t == "" and slot_chk != 0
            eff_itype = ast_to_ssa_get_var_int_type(ctx, target_name)
        end
        if eff_itype != ""
            rhs_val = ast_to_ssa_emit_truncate_int_width(ctx, rhs_val, eff_itype)
        end
        var_t = rhs_val.vtype
        if decl_t != ""
            var_t = decl_t
            if decl_t == "i64"
                var_t = "i64_int"
            end
        end
        if var_t == "bool"
            var_t = "i64_int"
        end
        slot = slot_chk
        if slot == 0
            slot = ast_to_ssa_alloc_var(ctx, target_name, var_t)
        else
            ast_to_ssa_set_var_type(ctx, target_name, var_t)
        end
        if raw_decl_t != ""
            if ssa_is_narrow_int_type(raw_decl_t) == 1
                ast_to_ssa_set_var_int_type(ctx, target_name, raw_decl_t)
            else
                ast_to_ssa_set_var_int_type(ctx, target_name, "")
            end
        end
        store_inst = ir_build_store(ctx.ctx_inst_counter, rhs_val, slot)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, store_inst)
        return 1

    // 3. Compound Assignment: target <op>= value (local, arr[i], or struct field)
    if skind == "AssignOp"
        target_name = stmt.target
        if stmt.index != 0
            if str_contains(target_name, ".") == 1 or str_contains(target_name, "[") == 1 or ctx.ctx_fn_has_float_cont == 1 or ctx.ctx_has_float_dict == 1
                ctx.ctx_has_unsupported = 1
                return 0
            end
            ia_slot = ast_to_ssa_find_var(ctx, target_name)
            if ia_slot == 0
                ctx.ctx_has_unsupported = 1
                return 0
            end
            fn_obj = ctx.ctx_curr_fn
            ia_cont = ast_to_ssa_emit_load_typed(ctx, ia_slot, ast_to_ssa_get_var_type(ctx, target_name))
            ia_idx = ast_to_ssa_lower_expr(ctx, stmt.index)
            ia_cur = fn_obj.new_val("i64")
            ia_get = ir_build_call(ctx.ctx_inst_counter, ia_cur, "_lipi_list_get", [ia_cont, ia_idx])
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, ia_get)
            ia_rhs = ast_to_ssa_lower_expr(ctx, stmt.value)
            if ia_rhs.vtype == "f64"
                ctx.ctx_has_unsupported = 1
                return 0
            end
            ia_op = ast_to_ssa_map_binop(stmt.op)
            if ia_op == OP_ADD
                ia_res = fn_obj.new_val("i64")
                ia_bin = ir_build_binop(ctx.ctx_inst_counter, OP_ADD_DYN, ia_res, ia_cur, ia_rhs)
            else
                ia_res = fn_obj.new_val("i64_int")
                ia_bin = ir_build_binop(ctx.ctx_inst_counter, ia_op, ia_res, ia_cur, ia_rhs)
            end
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, ia_bin)
            ia_tmp = fn_obj.new_val("i64")
            ia_set = ir_build_call(ctx.ctx_inst_counter, ia_tmp, "_lipi_list_set", [ia_cont, ia_idx, ia_res])
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, ia_set)
            return 1
        end
        if str_contains(target_name, "[") == 1
            ctx.ctx_has_unsupported = 1
            return 0
        end
        if str_contains(target_name, ".") == 1
            // Struct field compound assignment: obj.field += val
            dot_ao = str_index_of(target_name, ".")
            ao_obj_nm = str_slice(target_name, 0, dot_ao)
            ao_fld_nm = str_slice(target_name, dot_ao + 1, len(target_name))
            if str_contains(ao_fld_nm, ".") == 1
                ctx.ctx_has_unsupported = 1
                return 0
            end
            ao_slot = ast_to_ssa_find_var(ctx, ao_obj_nm)
            if ao_slot == 0
                ctx.ctx_has_unsupported = 1
                return 0
            end
            ao_obj_t = ast_to_ssa_get_var_type(ctx, ao_obj_nm)
            ao_off = ast_to_ssa_resolve_field_offset(ctx, ao_obj_t, ao_fld_nm)
            if ao_off < 0
                ctx.ctx_has_unsupported = 1
                return 0
            end
            fn_obj = ctx.ctx_curr_fn
            ao_obj_v = ast_to_ssa_emit_load_typed(ctx, ao_slot, ao_obj_t)
            ao_cur_v = fn_obj.new_val("i64")
            fl_ao = ir_build_field_load(ctx.ctx_inst_counter, ao_cur_v, ao_obj_v, ao_off)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, fl_ao)
            ao_rhs_v = ast_to_ssa_lower_expr(ctx, stmt.value)
            if ao_rhs_v.vtype == "f64"
                ctx.ctx_has_unsupported = 1
                return 0
            end
            ao_op = ast_to_ssa_map_binop(stmt.op)
            if ao_op == OP_ADD
                ao_res_v = fn_obj.new_val("i64")
                ao_bin = ir_build_binop(ctx.ctx_inst_counter, OP_ADD_DYN, ao_res_v, ao_cur_v, ao_rhs_v)
            else
                ao_res_v = fn_obj.new_val("i64_int")
                ao_bin = ir_build_binop(ctx.ctx_inst_counter, ao_op, ao_res_v, ao_cur_v, ao_rhs_v)
            end
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, ao_bin)
            fs_ao = ir_build_field_store(ctx.ctx_inst_counter, ao_obj_v, ao_res_v, ao_off)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, fs_ao)
            return 1
        end
        ao_chk = ast_to_ssa_find_var(ctx, target_name)
        if ao_chk == 0 and ast_to_ssa_is_mut_global(ctx, target_name) == 1
            ctx.ctx_has_unsupported = 1
            return 0
        end
        slot = ast_to_ssa_get_or_alloc_var(ctx, target_name)
        vt = ast_to_ssa_get_var_type(ctx, target_name)
        ao_itype = ast_to_ssa_get_var_int_type(ctx, target_name)
        curr_val = ast_to_ssa_emit_load_typed(ctx, slot, vt)
        rhs_val = ast_to_ssa_lower_expr(ctx, stmt.value)
        fn_obj = ctx.ctx_curr_fn
        if curr_val.vtype == "f64" or rhs_val.vtype == "f64"
            fl = ast_to_ssa_ensure_f64(ctx, curr_val)
            fr = ast_to_ssa_ensure_f64(ctx, rhs_val)
            fop = 0
            if stmt.op == "+=" or stmt.op == "+" fop = OP_FADD
            elif stmt.op == "-=" or stmt.op == "-" fop = OP_FSUB
            elif stmt.op == "*=" or stmt.op == "*" fop = OP_FMUL
            elif stmt.op == "/=" or stmt.op == "/" fop = OP_FDIV
            else
                ctx.ctx_has_unsupported = 1
            end
            if fop != 0
                res_val = fn_obj.new_val("f64")
                bin_inst = ir_build_binop(ctx.ctx_inst_counter, fop, res_val, fl, fr)
                ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
                basic_block_append_inst(ctx.ctx_curr_bb, bin_inst)
                ast_to_ssa_set_var_type(ctx, target_name, "f64")
                store_inst = ir_build_store(ctx.ctx_inst_counter, res_val, slot)
                ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
                basic_block_append_inst(ctx.ctx_curr_bb, store_inst)
            end
            return 1
        end
        op_code = ast_to_ssa_map_binop(stmt.op)
        is_str_ao = 0
        if curr_val.vtype == "str" or rhs_val.vtype == "str"
            is_str_ao = 1
        end
        both_int_ao = 0
        if ast_to_ssa_is_pure_int(curr_val) == 1 and ast_to_ssa_is_pure_int(rhs_val) == 1
            both_int_ao = 1
        end
        if op_code == OP_ADD and both_int_ao == 0
            ao_t = "i64"
            if is_str_ao == 1
                ao_t = "str"
            end
            res_val = fn_obj.new_val(ao_t)
            bin_inst = ir_build_binop(ctx.ctx_inst_counter, OP_ADD_DYN, res_val, curr_val, rhs_val)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, bin_inst)
            ast_to_ssa_set_var_type(ctx, target_name, ao_t)
            store_inst = ir_build_store(ctx.ctx_inst_counter, res_val, slot)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, store_inst)
            return 1
        end
        if is_str_ao == 1
            ctx.ctx_has_unsupported = 1
        end
        res_val = fn_obj.new_val("i64_int")
        bin_inst = ir_build_binop(ctx.ctx_inst_counter, op_code, res_val, curr_val, rhs_val)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, bin_inst)
        if ao_itype != ""
            res_val = ast_to_ssa_emit_truncate_int_width(ctx, res_val, ao_itype)
        end

        store_inst = ir_build_store(ctx.ctx_inst_counter, res_val, slot)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, store_inst)
        return 1

    // 4. Conditional Statement: if / elif / else (and scoped memory `region`)
    if skind == "IfStmt"
        if stmt.op == "region"
            if ast_to_ssa_stmts_have_return(stmt.then_body) == 1
                ctx.ctx_has_unsupported = 1
                return 0
            end
            fn_obj = ctx.ctx_curr_fn
            rg_mk = fn_obj.new_val("i64_int")
            rg_mi = ir_build_call(ctx.ctx_inst_counter, rg_mk, "_lipi_arena_mark", list())
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, rg_mi)
            if stmt.then_body != 0
                rbi = 0
                while rbi < len(stmt.then_body)
                    ast_to_ssa_lower_stmt(ctx, get(stmt.then_body, rbi))
                    rbi = rbi + 1
                end
            end
            if basic_block_get_terminator(ctx.ctx_curr_bb) == 0
                rg_rst = fn_obj.new_val("i64_int")
                rg_ri = ir_build_call(ctx.ctx_inst_counter, rg_rst, "_lipi_arena_reset", [rg_mk])
                ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
                basic_block_append_inst(ctx.ctx_curr_bb, rg_ri)
            end
            return 1
        end
        if stmt.op == "match" or stmt.op == "try"
            ctx.ctx_has_unsupported = 1
        end
        cond_node = stmt.condition
        if cond_node == 0
            cond_node = stmt.cond
        cond_val = ast_to_ssa_lower_expr(ctx, cond_node)

        fn_obj = ctx.ctx_curr_fn
        then_bb = fn_obj.create_block("if_then")
        else_bb = fn_obj.create_block("if_else")
        merge_bb = fn_obj.create_block("if_merge")

        // Branch condition in current block
        br_inst = ir_build_br(ctx.ctx_inst_counter, cond_val, then_bb.label, else_bb.label)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, br_inst)

        // Lower Then Body
        ctx.ctx_curr_bb = then_bb
        t_stmts = stmt.then_body
        if t_stmts != 0
            ti = 0
            tcnt = len(t_stmts)
            while ti < tcnt
                ast_to_ssa_lower_stmt(ctx, get(t_stmts, ti))
                ti = ti + 1
        if basic_block_get_terminator(ctx.ctx_curr_bb) == 0
            jmp_merge = ir_build_jmp(ctx.ctx_inst_counter, merge_bb.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, jmp_merge)

        // Lower Else Body
        ctx.ctx_curr_bb = else_bb
        e_stmts = stmt.else_body
        if e_stmts != 0
            ei = 0
            ecnt = len(e_stmts)
            while ei < ecnt
                ast_to_ssa_lower_stmt(ctx, get(e_stmts, ei))
                ei = ei + 1
        if basic_block_get_terminator(ctx.ctx_curr_bb) == 0
            jmp_merge2 = ir_build_jmp(ctx.ctx_inst_counter, merge_bb.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, jmp_merge2)

        // Resume at Merge Block
        ctx.ctx_curr_bb = merge_bb
        return 1

    // 5. While Loop Statement
    if skind == "WhileLoop" or skind == "While"
        fn_obj = ctx.ctx_curr_fn
        hdr_bb = fn_obj.create_block("while_hdr")
        body_bb = fn_obj.create_block("while_body")
        exit_bb = fn_obj.create_block("while_exit")

        // Jump from current block into loop header
        jmp_hdr = ir_build_jmp(ctx.ctx_inst_counter, hdr_bb.label)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, jmp_hdr)

        // Evaluate Loop Condition in header block
        ctx.ctx_curr_bb = hdr_bb
        cond_node = stmt.condition
        if cond_node == 0
            cond_node = stmt.cond
        cond_val = ast_to_ssa_lower_expr(ctx, cond_node)
        br_loop = ir_build_br(ctx.ctx_inst_counter, cond_val, body_bb.label, exit_bb.label)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, br_loop)

        // Lower Body with Break / Continue Stack
        push(ctx.ctx_loop_headers, hdr_bb)
        push(ctx.ctx_loop_exits, exit_bb)
        ctx.ctx_curr_bb = body_bb

        b_stmts = stmt.body
        if b_stmts != 0
            bi = 0
            bcnt = len(b_stmts)
            while bi < bcnt
                ast_to_ssa_lower_stmt(ctx, get(b_stmts, bi))
                bi = bi + 1

        if basic_block_get_terminator(ctx.ctx_curr_bb) == 0
            // Loop back-edge to header
            jmp_back = ir_build_jmp(ctx.ctx_inst_counter, hdr_bb.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, jmp_back)

        // Pop loop stacks
        pop(ctx.ctx_loop_headers)
        pop(ctx.ctx_loop_exits)

        // Resume execution after loop exit
        ctx.ctx_curr_bb = exit_bb
        return 1

    // 5b. For Loop Statement: inclusive range `for i in a..b` OR collection `for x in arr`
    if skind == "For" or skind == "ForLoop"
        fn_obj = ctx.ctx_curr_fn
        iter_n = stmt.iterable
        var_nm = stmt.variable
        if iter_n == 0 or var_nm == 0 or var_nm == ""
            ctx.ctx_has_unsupported = 1
            return 0
        end
        if iter_n.kind == "BinaryOp" and (iter_n.op == ".." or iter_n.op == "..=")
            st_v = ast_to_ssa_lower_expr(ctx, iter_n.left)
            en_v = ast_to_ssa_lower_expr(ctx, iter_n.right)
            en_slot = ast_to_ssa_alloc_var(ctx, "__for_end_" + str(ctx.ctx_inst_counter), "i64_int")
            st_en = ir_build_store(ctx.ctx_inst_counter, en_v, en_slot)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, st_en)
            v_slot = ast_to_ssa_find_var(ctx, var_nm)
            if v_slot == 0
                v_slot = ast_to_ssa_alloc_var(ctx, var_nm, "i64_int")
            else
                ast_to_ssa_set_var_type(ctx, var_nm, "i64_int")
            end
            st_iv = ir_build_store(ctx.ctx_inst_counter, st_v, v_slot)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, st_iv)
            hdr_bb = fn_obj.create_block("for_hdr")
            body_bb = fn_obj.create_block("for_body")
            step_bb = fn_obj.create_block("for_step")
            exit_bb = fn_obj.create_block("for_exit")
            j_fh = ir_build_jmp(ctx.ctx_inst_counter, hdr_bb.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, j_fh)
            ctx.ctx_curr_bb = hdr_bb
            cur_iv = ast_to_ssa_emit_load_typed(ctx, v_slot, "i64_int")
            lim_iv = ast_to_ssa_emit_load_typed(ctx, en_slot, "i64_int")
            cmp_r = fn_obj.new_val("bool")
            cmp_i = ir_build_cmp(ctx.ctx_inst_counter, ast_to_ssa_map_cmp("<="), cmp_r, cur_iv, lim_iv)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, cmp_i)
            br_f = ir_build_br(ctx.ctx_inst_counter, cmp_r, body_bb.label, exit_bb.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, br_f)
            push(ctx.ctx_loop_headers, step_bb)
            push(ctx.ctx_loop_exits, exit_bb)
            ctx.ctx_curr_bb = body_bb
            if stmt.body != 0
                fbi = 0
                while fbi < len(stmt.body)
                    ast_to_ssa_lower_stmt(ctx, get(stmt.body, fbi))
                    fbi = fbi + 1
                end
            end
            if basic_block_get_terminator(ctx.ctx_curr_bb) == 0
                j_st = ir_build_jmp(ctx.ctx_inst_counter, step_bb.label)
                ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
                basic_block_append_inst(ctx.ctx_curr_bb, j_st)
            end
            pop(ctx.ctx_loop_headers)
            pop(ctx.ctx_loop_exits)
            ctx.ctx_curr_bb = step_bb
            cur_iv2 = ast_to_ssa_emit_load_typed(ctx, v_slot, "i64_int")
            nxt_iv = fn_obj.new_val("i64_int")
            inc_i = ir_build_binop(ctx.ctx_inst_counter, OP_ADD, nxt_iv, cur_iv2, ssa_value_new_const(1, "i64_int"))
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, inc_i)
            st_nxt = ir_build_store(ctx.ctx_inst_counter, nxt_iv, v_slot)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, st_nxt)
            j_bk = ir_build_jmp(ctx.ctx_inst_counter, hdr_bb.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, j_bk)
            ctx.ctx_curr_bb = exit_bb
            return 1
        else
            // Collection iteration: for x in arr (uses x86_64 runtime _lipi_len/_lipi_list_get)
            if ctx.ctx_target_name != "x86_64"
                ctx.ctx_has_unsupported = 1
                return 0
            end
            is_f_nf = 0
            if iter_n.kind == "Variable" or iter_n.kind == "Ident"
                if ctx.ctx_local_nonfloat_conts != 0 and has_key(ctx.ctx_local_nonfloat_conts, iter_n.name) == 1
                    is_f_nf = 1
                end
            end
            if ctx.ctx_fn_has_float_cont == 1 or ctx.ctx_has_float_dict == 1 or (ctx.ctx_mod_has_float_cont == 1 and is_f_nf == 0)
                ctx.ctx_has_unsupported = 1
                return 0
            end
            coll_v = ast_to_ssa_lower_expr(ctx, iter_n)
            c_slot = ast_to_ssa_alloc_var(ctx, "__for_col_" + str(ctx.ctx_inst_counter), "i64")
            st_c = ir_build_store(ctx.ctx_inst_counter, coll_v, c_slot)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, st_c)
            len_v = fn_obj.new_val("i64_int")
            li_i = ir_build_call(ctx.ctx_inst_counter, len_v, "_lipi_len", [coll_v])
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, li_i)
            l_slot = ast_to_ssa_alloc_var(ctx, "__for_len_" + str(ctx.ctx_inst_counter), "i64_int")
            st_l = ir_build_store(ctx.ctx_inst_counter, len_v, l_slot)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, st_l)
            idx_slot = ast_to_ssa_alloc_var(ctx, "__for_idx_" + str(ctx.ctx_inst_counter), "i64_int")
            st_idx0 = ir_build_store(ctx.ctx_inst_counter, ssa_value_new_const(0, "i64_int"), idx_slot)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, st_idx0)
            v_slot2 = ast_to_ssa_find_var(ctx, var_nm)
            if v_slot2 == 0
                v_slot2 = ast_to_ssa_alloc_var(ctx, var_nm, "i64")
            else
                ast_to_ssa_set_var_type(ctx, var_nm, "i64")
            end
            hdr_bb2 = fn_obj.create_block("for_hdr")
            body_bb2 = fn_obj.create_block("for_body")
            step_bb2 = fn_obj.create_block("for_step")
            exit_bb2 = fn_obj.create_block("for_exit")
            j_fh2 = ir_build_jmp(ctx.ctx_inst_counter, hdr_bb2.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, j_fh2)
            ctx.ctx_curr_bb = hdr_bb2
            ci_v = ast_to_ssa_emit_load_typed(ctx, idx_slot, "i64_int")
            cl_v = ast_to_ssa_emit_load_typed(ctx, l_slot, "i64_int")
            cmp_r2 = fn_obj.new_val("bool")
            cmp_i2 = ir_build_cmp(ctx.ctx_inst_counter, ast_to_ssa_map_cmp("<"), cmp_r2, ci_v, cl_v)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, cmp_i2)
            br_f2 = ir_build_br(ctx.ctx_inst_counter, cmp_r2, body_bb2.label, exit_bb2.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, br_f2)
            push(ctx.ctx_loop_headers, step_bb2)
            push(ctx.ctx_loop_exits, exit_bb2)
            ctx.ctx_curr_bb = body_bb2
            cc_v = ast_to_ssa_emit_load_typed(ctx, c_slot, "i64")
            ci_v2 = ast_to_ssa_emit_load_typed(ctx, idx_slot, "i64_int")
            el_gv = fn_obj.new_val("i64")
            ge_i = ir_build_call(ctx.ctx_inst_counter, el_gv, "_lipi_list_get", [cc_v, ci_v2])
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, ge_i)
            st_el = ir_build_store(ctx.ctx_inst_counter, el_gv, v_slot2)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, st_el)
            if stmt.body != 0
                fbi2 = 0
                while fbi2 < len(stmt.body)
                    ast_to_ssa_lower_stmt(ctx, get(stmt.body, fbi2))
                    fbi2 = fbi2 + 1
                end
            end
            if basic_block_get_terminator(ctx.ctx_curr_bb) == 0
                j_st2 = ir_build_jmp(ctx.ctx_inst_counter, step_bb2.label)
                ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
                basic_block_append_inst(ctx.ctx_curr_bb, j_st2)
            end
            pop(ctx.ctx_loop_headers)
            pop(ctx.ctx_loop_exits)
            ctx.ctx_curr_bb = step_bb2
            ci_v3 = ast_to_ssa_emit_load_typed(ctx, idx_slot, "i64_int")
            nxt_i2 = fn_obj.new_val("i64_int")
            inc_i2 = ir_build_binop(ctx.ctx_inst_counter, OP_ADD, nxt_i2, ci_v3, ssa_value_new_const(1, "i64_int"))
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, inc_i2)
            st_n2 = ir_build_store(ctx.ctx_inst_counter, nxt_i2, idx_slot)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, st_n2)
            j_bk2 = ir_build_jmp(ctx.ctx_inst_counter, hdr_bb2.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, j_bk2)
            ctx.ctx_curr_bb = exit_bb2
            return 1
        end
    end

    // 6. Break Statement
    if skind == "Break"
        if len(ctx.ctx_loop_exits) > 0
            target_exit = get(ctx.ctx_loop_exits, len(ctx.ctx_loop_exits) - 1)
            jmp_brk = ir_build_jmp(ctx.ctx_inst_counter, target_exit.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, jmp_brk)
        return 1

    // 7. Continue Statement
    if skind == "Continue"
        if len(ctx.ctx_loop_headers) > 0
            target_hdr = get(ctx.ctx_loop_headers, len(ctx.ctx_loop_headers) - 1)
            jmp_cont = ir_build_jmp(ctx.ctx_inst_counter, target_hdr.label)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, jmp_cont)
        return 1

    // 8. Expression Statement (e.g. standalone function call; reject throw / @asm)
    if skind == "ExprStmt" or skind == "ExpressionStmt"
        if stmt.op == "throw" or stmt.op == "asm"
            ctx.ctx_has_unsupported = 1
            return 0
        end
        ast_to_ssa_lower_expr(ctx, stmt.expr)
        return 1

    ctx.ctx_has_unsupported = 1
    return 0

// ── 6. Function & Module Lowering ─────────────────────────────────────────────

fn ast_to_ssa_stmts_have_return stmts
    if stmts == 0 return 0 end
    si = 0
    sn = len(stmts)
    while si < sn
        st = get(stmts, si)
        if st != 0
            sk = st.kind
            if sk == "Return" return 1 end
            if sk == "IfStmt"
                if ast_to_ssa_stmts_have_return(st.then_body) == 1 return 1 end
                if ast_to_ssa_stmts_have_return(st.else_body) == 1 return 1 end
            elif sk == "While" or sk == "WhileLoop" or sk == "For" or sk == "ForLoop" or sk == "Block"
                if ast_to_ssa_stmts_have_return(st.body) == 1 return 1 end
            end
        end
        si = si + 1
    end
    return 0
end

fn ast_to_ssa_prescan_ret_hint stmts
    if stmts == 0 return "i64" end
    i = 0
    n = len(stmts)
    while i < n
        st = get(stmts, i)
        if st != 0
            if st.kind == "Return" and st.value != 0
                vk = st.value.kind
                if vk == "LiteralFloat" or vk == "FloatLiteral"
                    return "f64"
                elif vk == "LiteralStr" or vk == "StrLiteral"
                    return "str"
                elif vk == "Call"
                    cn_r = st.value.name
                    if cn_r == "stack_trace" or cn_r == "backtrace" or cn_r == "স্ট্যাক_ট্রেস" or cn_r == "str" or cn_r == "to_str" or cn_r == "স্ট্রিং" or cn_r == "file_read" or cn_r == "uint_to_str"
                        return "str"
                    end
                end
            elif st.kind == "IfStmt"
                h1 = ast_to_ssa_prescan_ret_hint(st.then_body)
                if h1 != "i64" return h1 end
                h2 = ast_to_ssa_prescan_ret_hint(st.else_body)
                if h2 != "i64" return h2 end
            elif st.kind == "WhileLoop" or st.kind == "While"
                h3 = ast_to_ssa_prescan_ret_hint(st.body)
                if h3 != "i64" return h3 end
            end
        end
        i = i + 1
    end
    return "i64"

fn ast_to_ssa_expr_is_float node
    if node == 0 return 0 end
    k = node.kind
    if k == "LiteralFloat" or k == "FloatLiteral"
        return 1
    elif k == "UnaryOp"
        return ast_to_ssa_expr_is_float(node.expr)
    elif k == "BinaryOp" or k == "BinOp"
        if ast_to_ssa_expr_is_float(node.left) == 1 return 1 end
        return ast_to_ssa_expr_is_float(node.right)
    end
    return 0

fn ast_to_ssa_node_has_float_cont node
    // WHY: Detects whether any MapLit/ArrayLit or dict/list mutation in a module stores IEEE-754
    // float values so SSA Index lowering conservatively yields to x86_synth's dyn_tagged flow engine.
    if node == 0 return 0 end
    k = node.kind
    if k == "MapLit" or k == "ArrayLit"
        if node.elements != 0
            ei = 0
            en = len(node.elements)
            while ei < en
                el = get(node.elements, ei)
                if k == "ArrayLit" and ast_to_ssa_expr_is_float(el) == 1 return 1 end
                if k == "MapLit" and el != 0 and el.op == "str_key" and el.value != 0 and ast_to_ssa_expr_is_float(el.value) == 1 return 1 end
                if ast_to_ssa_node_has_float_cont(el) == 1 return 1 end
                ei = ei + 1
            end
        end
        return 0
    elif k == "Call"
        cn = node.name
        cargs = node.params
        if cargs == 0 cargs = node.args end
        if cargs != 0
            ci = 0
            cn_len = len(cargs)
            while ci < cn_len
                ca = get(cargs, ci)
                if (cn == "dict_set" or cn == "list_set" or cn == "push" or cn == "set") and ast_to_ssa_expr_is_float(ca) == 1
                    return 1
                end
                if ast_to_ssa_node_has_float_cont(ca) == 1 return 1 end
                ci = ci + 1
            end
        end
        return 0
    elif k == "IndexAssign" or k == "Assign" or k == "Let" or k == "VarDecl"
        if node.value != 0
            if (k == "IndexAssign" or (node.target != 0 and str_contains(node.target, "[") == 1)) and ast_to_ssa_expr_is_float(node.value) == 1
                return 1
            end
            if ast_to_ssa_node_has_float_cont(node.value) == 1 return 1 end
        end
        return 0
    elif k == "FnDef" or k == "Function" or k == "কাজ" or k == "WhileLoop" or k == "While" or k == "ForLoop" or k == "For" or k == "Block"
        if node.body != 0
            bi = 0
            bn = len(node.body)
            while bi < bn
                if ast_to_ssa_node_has_float_cont(get(node.body, bi)) == 1 return 1 end
                bi = bi + 1
            end
        end
        return 0
    elif k == "IfStmt"
        if node.then_body != 0
            ti = 0
            while ti < len(node.then_body)
                if ast_to_ssa_node_has_float_cont(get(node.then_body, ti)) == 1 return 1 end
                ti = ti + 1
            end
        end
        if node.else_body != 0
            eli = 0
            while eli < len(node.else_body)
                if ast_to_ssa_node_has_float_cont(get(node.else_body, eli)) == 1 return 1 end
                eli = eli + 1
            end
        end
        return 0
    elif k == "Return" or k == "ExprStmt" or k == "ExpressionStmt"
        if node.value != 0 and ast_to_ssa_node_has_float_cont(node.value) == 1 return 1 end
        if node.expr != 0 and ast_to_ssa_node_has_float_cont(node.expr) == 1 return 1 end
        return 0
    elif k == "BinaryOp" or k == "BinOp"
        if ast_to_ssa_node_has_float_cont(node.left) == 1 return 1 end
        return ast_to_ssa_node_has_float_cont(node.right)
    end
    return 0

fn ast_to_ssa_lower_fn_full mod_obj fn_decl struct_names struct_fields struct_idx_map field_uniq_off fn_names fn_ret_types fn_param_cnts fn_param_types fn_idx_map mod_const_map mod_mut_globals mod_has_float_cont target_name
    return ast_to_ssa_lower_fn_impl(mod_obj, fn_decl, struct_names, struct_fields, struct_idx_map, field_uniq_off, 0, fn_names, fn_ret_types, fn_param_cnts, fn_param_types, fn_idx_map, mod_const_map, mod_mut_globals, mod_has_float_cont, target_name)

fn ast_to_ssa_lower_fn_impl mod_obj fn_decl struct_names struct_fields struct_idx_map field_uniq_off field_type_map fn_names fn_ret_types fn_param_cnts fn_param_types fn_idx_map mod_const_map mod_mut_globals mod_has_float_cont target_name
    // WHY: Transforms an AST function declaration into an isolated typed IRFunction
    // with full module struct schemas, field types, O(1) lookup indices, and constant folding.
    if mod_obj == 0 or fn_decl == 0 return 0

    fn_name = fn_decl.name
    has_explicit_ret = 0
    ret_type = "i64"
    if fn_decl.ret_type != 0 and len(fn_decl.ret_type) > 0
        has_explicit_ret = 1
        ret_type = ssa_normalize_type(fn_decl.ret_type)
    end

    fn_obj = ir_function_new(fn_name, ret_type)
    ctx = ast_to_ssa_context_new(mod_obj, fn_obj)
    ctx.ctx_struct_names = struct_names
    ctx.ctx_struct_fields = struct_fields
    ctx.ctx_struct_idx_map = struct_idx_map
    ctx.ctx_field_uniq_off = field_uniq_off
    ctx.ctx_field_type_map = field_type_map
    ctx.ctx_fn_names = fn_names
    ctx.ctx_fn_ret_types = fn_ret_types
    ctx.ctx_fn_param_cnts = fn_param_cnts
    ctx.ctx_fn_param_types = fn_param_types
    ctx.ctx_fn_idx_map = fn_idx_map
    ctx.ctx_mod_const_map = mod_const_map
    ctx.ctx_mod_mut_globals = mod_mut_globals
    ctx.ctx_mod_has_float_cont = mod_has_float_cont
    ctx.ctx_fn_has_float_cont = ast_to_ssa_node_has_float_cont(fn_decl)
    ctx.ctx_target_name = target_name

    if fn_name == "f64_from_bits" or fn_name == "f64_to_bits" or fn_name == "syscall" or fn_name == "সিসকল" or fn_name == "sys_syscall"
        // WHY: Bitcast & hardware syscall wrappers must stay in target backend synthesis.
        ctx.ctx_has_unsupported = 1
    end

    if ret_type != "i64" and ret_type != "f64" and ret_type != "str" and ast_to_ssa_find_struct_idx(ctx, ret_type) < 0
        ctx.ctx_has_unsupported = 1
    end

    // Bind formal parameters (up to 16 args) with normalized types & narrow-width wrapping
    params = fn_decl.params
    if params != 0
        pi = 0
        pcnt = len(params)
        if pcnt > 16
            ctx.ctx_has_unsupported = 1
        end
        while pi < pcnt
            pnode = get(params, pi)
            if pnode != 0 and (pnode.param_is_variadic == 1 or pnode.param_default != 0)
                ctx.ctx_has_unsupported = 1
            end
            p_name = pnode.param_name
            raw_pt = ""
            p_type = "i64"
            if pnode.param_type != 0 and pnode.param_type != ""
                raw_pt = pnode.param_type
                p_type = ssa_normalize_type(raw_pt)
                if p_type != "i64" and p_type != "f64" and p_type != "str" and ast_to_ssa_find_struct_idx(ctx, p_type) < 0
                    ctx.ctx_has_unsupported = 1
                end
                if p_type == "i64"
                    p_type = "i64_int"
                end
            end

            // Create SSA parameter register (prefixed with %arg_ to prevent collision with monotonic %vN temporaries)
            arg_str = "%arg_" + p_name
            p_val = ssa_value_new_arg(arg_str, p_type)
            ir_function_add_param(fn_obj, p_val)

            // Allocate local entry stack slot, truncate if narrow int type, and store initial parameter value
            slot = ast_to_ssa_alloc_var(ctx, p_name, p_type)
            store_v = p_val
            if ssa_is_narrow_int_type(raw_pt) == 1
                ast_to_ssa_set_var_int_type(ctx, p_name, raw_pt)
                store_v = ast_to_ssa_emit_truncate_int_width(ctx, p_val, raw_pt)
            end
            st_inst = ir_build_store(ctx.ctx_inst_counter, store_v, slot)
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(fn_obj.entry_block, st_inst)

            pi = pi + 1

    // Lower body statements
    stmts = fn_decl.body
    if stmts != 0
        si = 0
        scnt = len(stmts)
        if scnt == 0
            ctx.ctx_has_unsupported = 1
        end
        while si < scnt
            ast_to_ssa_lower_stmt(ctx, get(stmts, si))
            si = si + 1
    else
        ctx.ctx_has_unsupported = 1
    end

    // Propagate inferred return type when not explicitly annotated (so callers know float/str/struct!)
    if has_explicit_ret == 0 and ctx.ctx_inferred_ret != ""
        fn_obj.return_type = ctx.ctx_inferred_ret
    end

    // Guarantee basic block termination
    if basic_block_get_terminator(ctx.ctx_curr_bb) == 0
        def_zero = ssa_value_new_const(0, "i64")
        ret_zero = ir_build_ret(ctx.ctx_inst_counter, def_zero)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, ret_zero)

    // Reconstruct Control Flow Graph edges for mathematical consistency
    cfg_rebuild_edges(fn_obj)

    if ctx.ctx_has_unsupported == 0 and ((fn_name != "main" and fn_name != "_start") or target_name == "wasm")
        fn_obj.is_ssa_native_ready = 1
    else
        fn_obj.is_ssa_native_ready = 0
    end

    // Register function into module
    ir_module_add_function(mod_obj, fn_obj)
    return fn_obj

fn ast_to_ssa_lower_fn_with_meta mod_obj fn_decl struct_names struct_fields fn_names fn_ret_types fn_param_cnts
    return ast_to_ssa_lower_fn_full(mod_obj, fn_decl, struct_names, struct_fields, 0, 0, fn_names, fn_ret_types, fn_param_cnts, list(), 0, 0, 0, 0, "x86_64")

fn ast_to_ssa_lower_fn mod_obj fn_decl
    return ast_to_ssa_lower_fn_with_meta(mod_obj, fn_decl, list(), list(), list(), list(), list())

struct AstToSsaSchemas
    sch_struct_names
    sch_struct_fields
    sch_struct_idx_map
    sch_field_uniq_off
    sch_field_type_map
    sch_fn_names
    sch_fn_ret_types
    sch_fn_param_cnts
    sch_fn_param_types
    sch_fn_idx_map
    sch_mod_fn_set
    sch_mod_has_float_cont

fn ast_to_ssa_lower_fn_sch mod_obj fn_decl sch mod_const_map mod_mut_globals target_name
    // WHY: Defined AFTER `struct AstToSsaSchemas` so single-pass legacy `--no-ssa-codegen`
    // resolves every `sch.sch_*` field offset identically to two-pass SSA CFG codegen!
    return ast_to_ssa_lower_fn_impl(mod_obj, fn_decl, sch.sch_struct_names, sch.sch_struct_fields, sch.sch_struct_idx_map, sch.sch_field_uniq_off, sch.sch_field_type_map, sch.sch_fn_names, sch.sch_fn_ret_types, sch.sch_fn_param_cnts, sch.sch_fn_param_types, sch.sch_fn_idx_map, mod_const_map, mod_mut_globals, sch.sch_mod_has_float_cont, target_name)

fn ast_to_ssa_collect_schemas ast_nodes
    // WHY: Pass 1 schema & signature collector shared by whole-module (-O3) and
    // per-function streaming (-O0/-O1/-O2) lowering pipelines.
    sch = AstToSsaSchemas()
    sch.sch_struct_names = list()
    sch.sch_struct_fields = list()
    sch.sch_struct_idx_map = dict()
    sch.sch_field_uniq_off = dict()
    sch.sch_field_type_map = dict()
    sch.sch_fn_names = list()
    sch.sch_fn_ret_types = list()
    sch.sch_fn_param_cnts = list()
    sch.sch_fn_param_types = list()
    sch.sch_fn_idx_map = dict()
    sch.sch_mod_fn_set = dict()
    sch.sch_mod_has_float_cont = 0
    if ast_nodes == 0
        return sch
    end

    cnt = len(ast_nodes)
    pi = 0
    while pi < cnt
        decl = get(ast_nodes, pi)
        dkind = decl.kind
        if sch.sch_mod_has_float_cont == 0 and ast_to_ssa_node_has_float_cont(decl) == 1
            sch.sch_mod_has_float_cont = 1
        end
        if dkind == "StructDef"
            sname = decl.name
            flist = list()
            f_nodes = decl.params
            if f_nodes == 0
                f_nodes = decl.elements
            end
            if f_nodes != 0
                fi = 0
                while fi < len(f_nodes)
                    fn_i = get(f_nodes, fi)
                    if fn_i != 0 and fn_i.field_name != 0
                        fnm = fn_i.field_name
                        push(flist, fnm)
                        off_p1 = (fi * 8) + 1
                        if has_key(sch.sch_field_uniq_off, fnm) == 0
                            sch.sch_field_uniq_off[fnm] = off_p1
                        elif sch.sch_field_uniq_off[fnm] != off_p1
                            sch.sch_field_uniq_off[fnm] = 0
                        end
                        if fn_i.field_type != 0 and fn_i.field_type != ""
                            ft_n = ssa_normalize_type(fn_i.field_type)
                            if ft_n != "i64"
                                sch.sch_field_type_map[sname + "::" + fnm] = ft_n
                                ku = "::" + fnm
                                if has_key(sch.sch_field_type_map, ku) == 0
                                    sch.sch_field_type_map[ku] = ft_n
                                elif sch.sch_field_type_map[ku] != ft_n
                                    sch.sch_field_type_map[ku] = ""
                                end
                            end
                        end
                    end
                    fi = fi + 1
                end
            end
            push(sch.sch_struct_names, sname)
            push(sch.sch_struct_fields, flist)
            sch.sch_struct_idx_map[sname] = sch.sch_struct_names.len()
        elif dkind == "FnDef" or dkind == "Function" or dkind == "কাজ"
            if decl.name == "syscall" or decl.name == "সিসকল" or decl.name == "sys_syscall"
                push(sch.sch_fn_names, "")
            else
                push(sch.sch_fn_names, decl.name)
                sch.sch_fn_idx_map[decl.name] = sch.sch_fn_names.len()
                sch.sch_mod_fn_set[decl.name] = 1
            end
            rt = "i64"
            if decl.ret_type != 0 and len(decl.ret_type) > 0
                rt = ssa_normalize_type(decl.ret_type)
                if rt == "i64"
                    rt = "i64_int"
                end
            else
                rt = ast_to_ssa_prescan_ret_hint(decl.body)
            end
            push(sch.sch_fn_ret_types, rt)
            pc = 0
            has_var_or_def = 0
            pt_list = list()
            if decl.params != 0
                pc = len(decl.params)
                pti_p = 0
                while pti_p < pc
                    pnd = get(decl.params, pti_p)
                    pt_s = ""
                    if pnd != 0
                        if pnd.param_is_variadic == 1
                            has_var_or_def = 1
                        end
                        if pnd.param_type != 0 and pnd.param_type != ""
                            pt_s = ssa_normalize_type(pnd.param_type)
                        end
                    end
                    push(pt_list, pt_s)
                    pti_p = pti_p + 1
                end
            end
            if has_var_or_def == 1
                pc = 0 - 1
            end
            push(sch.sch_fn_param_cnts, pc)
            push(sch.sch_fn_param_types, pt_list)
        end
        pi = pi + 1
    end
    return sch
end

fn ast_to_ssa_intern_ret_type sch raw_rt
    // WHY: Maps any inferred return type string strictly to a static literal or pre-arena
    // schema string so streaming arena_reset(m_fn) can never dangle sch_fn_ret_types entries.
    if raw_rt == 0 or raw_rt == "" or raw_rt == "i64" or raw_rt == "int"
        return "i64"
    end
    if raw_rt == "i64_int"
        return "i64_int"
    end
    if raw_rt == "f64" or raw_rt == "float"
        return "f64"
    end
    if raw_rt == "str" or raw_rt == "string"
        return "str"
    end
    if sch != 0 and sch.sch_struct_idx_map != 0 and has_key(sch.sch_struct_idx_map, raw_rt) == 1
        sidx = sch.sch_struct_idx_map[raw_rt] - 1
        if sidx >= 0 and sidx < sch.sch_struct_names.len()
            return sch.sch_struct_names[sidx]
        end
    end
    return "i64"
end

fn ast_to_ssa_lower_module_with_consts ast_nodes target_name mod_const_map mod_mut_globals
    // WHY: Master entry point translating AST collection into complete IRModule with O(1)
    // struct/field/function indices and immutable module-level constant folding.
    mod_obj = ir_module_new("lipi_translation_unit")
    ir_module_set_metadata(mod_obj, "target", target_name)
    ir_module_set_metadata(mod_obj, "producer", "LiPi First 1.0.0 (প্রথম ১.০.০)")

    if ast_nodes == 0 return mod_obj

    node_list = ast_nodes
    cnt = len(node_list)

    // Pass 1: Collect StructDef field tables, O(1) lookup dicts, FnDef signatures, and float-container flag
    sch = ast_to_ssa_collect_schemas(node_list)
    struct_names = sch.sch_struct_names
    struct_fields = sch.sch_struct_fields
    struct_idx_map = sch.sch_struct_idx_map
    field_uniq_off = sch.sch_field_uniq_off
    fn_names = sch.sch_fn_names
    fn_ret_types = sch.sch_fn_ret_types
    fn_param_cnts = sch.sch_fn_param_cnts
    fn_param_types = sch.sch_fn_param_types
    fn_idx_map = sch.sch_fn_idx_map
    mod_has_float_cont = sch.sch_mod_has_float_cont

    // Pass 2: Lower all functions & globals using collected schemas
    fn_ord = 0
    i = 0
    while i < cnt
        decl = get(node_list, i)
        dkind = decl.kind

        if dkind == "FnDef" or dkind == "Function" or dkind == "কাজ"
            low_f = ast_to_ssa_lower_fn_sch(mod_obj, decl, sch, mod_const_map, mod_mut_globals, target_name)
            if low_f != 0 and low_f.is_ssa_native_ready == 1 and fn_ord < fn_ret_types.len() and low_f.return_type != ""
                if fn_ret_types[fn_ord] != "i64_int" or low_f.return_type != "i64"
                    list_set(fn_ret_types, fn_ord, low_f.return_type)
                end
            end
            fn_ord = fn_ord + 1
        elif dkind == "GlobalVar" or dkind == "Constant"
            g_name = "@" + decl.name
            ir_module_add_global(mod_obj, g_name, "i64", decl.val, 1)
        i = i + 1

    return mod_obj

fn ast_to_ssa_lower_module ast_nodes target_name
    return ast_to_ssa_lower_module_with_consts(ast_nodes, target_name, 0, 0)

// WHY: Standard adapter converting AST statement collection into an IRModule result wrapper
// Handles module options, passes target name, and packages status code with zero memory leaks.
fn ir_module_from_ast ast_nodes ir_opts
    target_name = "x86_64"
    if ir_opts != 0 and ir_opts.module_name != 0
        target_name = ir_opts.module_name
    mod_obj = ast_to_ssa_lower_module(ast_nodes, target_name)
    return {
        error: 0,
        module: mod_obj,
        message: ""
    }
