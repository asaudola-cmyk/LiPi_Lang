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
    ctx_loop_headers    // list of BasicBlock references for 'continue' targets
    ctx_loop_exits      // list of BasicBlock references for 'break' targets
    ctx_has_unsupported // 1 if any non-SSA-lowerable construct was encountered
    ctx_struct_names    // module-wide registered StructDef names
    ctx_struct_fields   // parallel list of field-name lists per struct
    ctx_fn_names        // module-wide registered user FnDef names
    ctx_fn_ret_types    // parallel list of user FnDef normalized return types
    ctx_fn_param_cnts   // parallel list of user FnDef parameter counts
    ctx_inferred_ret    // inferred return type from OP_RET statements ("", "i64", "f64", "str", struct)

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
    ctx.ctx_loop_headers = list()
    ctx.ctx_loop_exits = list()
    ctx.ctx_has_unsupported = 0
    ctx.ctx_struct_names = list()
    ctx.ctx_struct_fields = list()
    ctx.ctx_fn_names = list()
    ctx.ctx_fn_ret_types = list()
    ctx.ctx_fn_param_cnts = list()
    ctx.ctx_inferred_ret = ""
    return ctx

fn ssa_normalize_type tname
    if tname == 0 or tname == "" or tname == "int" or tname == "i64" or tname == "bool"
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
    i = 0
    while i < ctx.ctx_struct_names.len()
        if ctx.ctx_struct_names[i] == sname
            return i
        end
        i = i + 1
    end
    return 0 - 1

fn ast_to_ssa_resolve_field_offset ctx sname fname
    // WHY: Resolves exact 8-byte struct field offset; returns -1 if missing or ambiguous across structs.
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

fn ast_to_ssa_find_user_fn_idx ctx fname
    i = 0
    while i < ctx.ctx_fn_names.len()
        if ctx.ctx_fn_names[i] == fname
            return i
        end
        i = i + 1
    end
    return 0 - 1

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

    if ekind == "LiteralStr" or ekind == "StrLiteral"
        stext = ""
        if expr.name != 0
            stext = expr.name
        end
        if str_contains(stext, "{") == 1
            ctx.ctx_has_unsupported = 1
            return ssa_value_new_const(0, "str")
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

    // 2. Variable Reference
    if ekind == "Variable" or ekind == "Ident"
        var_name = expr.name
        slot = ast_to_ssa_find_var(ctx, var_name)
        if slot != 0
            vt = ast_to_ssa_get_var_type(ctx, var_name)
            return ast_to_ssa_emit_load_typed(ctx, slot, vt)
        // Fallback for unbound / global symbols
        ctx.ctx_has_unsupported = 1
        return ssa_value_new_const(0, "i64")

    // 2b. Struct Member Access: obj.field
    if ekind == "MemberAccess"
        obj_node = expr.left
        if obj_node == 0
            obj_node = expr.target
        end
        obj_val = ast_to_ssa_lower_expr(ctx, obj_node)
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
        fres = fn_obj.new_val("i64")
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
        if ast_to_ssa_is_cmp_op(op_str) == 1
            pred = ast_to_ssa_map_cmp(op_str)
            res_val = fn_obj.new_val("bool")
            if both_int == 1
                cmp_inst = ir_build_cmp(ctx.ctx_inst_counter, pred, res_val, lhs_val, rhs_val)
            else
                cmp_inst = ir_build_cmp_dyn(ctx.ctx_inst_counter, pred, res_val, lhs_val, rhs_val)
            end
            ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
            basic_block_append_inst(ctx.ctx_curr_bb, cmp_inst)
            return res_val
        else
            op_code = ast_to_ssa_map_binop(op_str)
            if op_code == OP_ADD and both_int == 0
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

    // 5. Function Call OR Struct Constructor
    if ekind == "Call"
        fn_obj = ctx.ctx_curr_fn
        callee_name = expr.name
        arg_values = list()

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

        // 5b. Inter-Function Call to known user function OR verified SysV ABI runtime builtin (<= 6 args)
        uf_idx = ast_to_ssa_find_user_fn_idx(ctx, callee_name)
        call_ret_t = "i64"
        emit_callee = callee_name
        ac = arg_values.len()
        if uf_idx >= 0 and ac <= 6 and ac == ctx.ctx_fn_param_cnts[uf_idx]
            call_ret_t = ctx.ctx_fn_ret_types[uf_idx]
        elif (callee_name == "len" or callee_name == "দৈর্ঘ্য") and ac == 1
            emit_callee = "_lipi_len"
            call_ret_t = "i64_int"
        elif (callee_name == "list" or callee_name == "তালিকা") and ac == 0
            emit_callee = "lipi_fn_list"
            call_ret_t = "i64"
        elif (callee_name == "get" or callee_name == "নাও") and ac == 2
            emit_callee = "_lipi_list_get"
            call_ret_t = "i64"
        elif (callee_name == "list_set" or callee_name == "সেট") and ac == 3 and arg_values[2].vtype != "f64" and arg_values[2].vtype != "str"
            emit_callee = "_lipi_list_set"
            call_ret_t = "i64"
        elif (callee_name == "push" or callee_name == "list_push" or callee_name == "ঠেলো") and ac == 2
            emit_callee = "_lipi_list_push"
            call_ret_t = "i64"
        elif (callee_name == "has_key" or callee_name == "map_has") and ac == 2
            emit_callee = "_lipi_dict_has"
            call_ret_t = "i64_int"
        elif (callee_name == "del_key" or callee_name == "map_del") and ac == 2
            emit_callee = "_lipi_dict_del"
            call_ret_t = "i64_int"
        elif (callee_name == "str" or callee_name == "to_str") and ac == 1 and arg_values[0].vtype != "f64"
            emit_callee = "_lipi_ensure_str"
            call_ret_t = "str"
        elif callee_name != fn_obj.name or ac > 6
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

    // 2. Simple Variable Assignment OR Struct Field Assignment: target = value / obj.field = value
    if skind == "Assign"
        target_name = stmt.target
        if stmt.index != 0 or str_contains(target_name, "[") == 1
            ctx.ctx_has_unsupported = 1
        elif str_contains(target_name, ".") == 1
            // Single-level struct field store: obj.field = value
            dot_idx = str_index_of(target_name, ".")
            obj_nm = str_slice(target_name, 0, dot_idx)
            fld_nm = str_slice(target_name, dot_idx + 1, len(target_name))
            if str_contains(fld_nm, ".") == 1
                ctx.ctx_has_unsupported = 1
            else
                obj_slot = ast_to_ssa_find_var(ctx, obj_nm)
                if obj_slot == 0
                    ctx.ctx_has_unsupported = 1
                else
                    obj_t = ast_to_ssa_get_var_type(ctx, obj_nm)
                    byte_off = ast_to_ssa_resolve_field_offset(ctx, obj_t, fld_nm)
                    if byte_off < 0
                        ctx.ctx_has_unsupported = 1
                    else
                        obj_v = ast_to_ssa_emit_load_typed(ctx, obj_slot, obj_t)
                        rhs_v = ast_to_ssa_lower_expr(ctx, stmt.value)
                        fs_inst = ir_build_field_store(ctx.ctx_inst_counter, obj_v, rhs_v, byte_off)
                        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
                        basic_block_append_inst(ctx.ctx_curr_bb, fs_inst)
                        return 1
                    end
                end
            end
        end
        decl_t = ""
        if stmt.op != 0 and stmt.op != ""
            decl_t = ssa_normalize_type(stmt.op)
            if decl_t != "i64" and decl_t != "f64" and decl_t != "str" and ast_to_ssa_find_struct_idx(ctx, decl_t) < 0
                ctx.ctx_has_unsupported = 1
            end
        end
        rhs_val = ast_to_ssa_lower_expr(ctx, stmt.value)
        if decl_t == "f64" and rhs_val.vtype != "f64"
            rhs_val = ast_to_ssa_ensure_f64(ctx, rhs_val)
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
        slot = ast_to_ssa_find_var(ctx, target_name)
        if slot == 0
            slot = ast_to_ssa_alloc_var(ctx, target_name, var_t)
        else
            ast_to_ssa_set_var_type(ctx, target_name, var_t)
        end
        store_inst = ir_build_store(ctx.ctx_inst_counter, rhs_val, slot)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, store_inst)
        return 1

    // 3. Compound Assignment: target <op>= value
    if skind == "AssignOp"
        target_name = stmt.target
        if stmt.index != 0 or str_contains(target_name, ".") == 1 or str_contains(target_name, "[") == 1
            ctx.ctx_has_unsupported = 1
        end
        slot = ast_to_ssa_get_or_alloc_var(ctx, target_name)
        vt = ast_to_ssa_get_var_type(ctx, target_name)
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

        store_inst = ir_build_store(ctx.ctx_inst_counter, res_val, slot)
        ctx.ctx_inst_counter = ctx.ctx_inst_counter + 1
        basic_block_append_inst(ctx.ctx_curr_bb, store_inst)
        return 1

    // 4. Conditional Statement: if / elif / else
    if skind == "IfStmt"
        if stmt.op == "match"
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

    // 8. Expression Statement (e.g. standalone function call)
    if skind == "ExprStmt" or skind == "ExpressionStmt"
        ast_to_ssa_lower_expr(ctx, stmt.expr)
        return 1

    ctx.ctx_has_unsupported = 1
    return 0

// ── 6. Function & Module Lowering ─────────────────────────────────────────────

fn ast_to_ssa_lower_fn_with_meta mod_obj fn_decl struct_names struct_fields fn_names fn_ret_types fn_param_cnts
    // WHY: Transforms an AST function declaration into an isolated typed IRFunction
    // with full module struct schemas and user-function signatures for direct SSA lowering.
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
    ctx.ctx_fn_names = fn_names
    ctx.ctx_fn_ret_types = fn_ret_types
    ctx.ctx_fn_param_cnts = fn_param_cnts

    if ret_type != "i64" and ret_type != "f64" and ret_type != "str" and ast_to_ssa_find_struct_idx(ctx, ret_type) < 0
        ctx.ctx_has_unsupported = 1
    end

    // Bind formal parameters with normalized types (i64, f64, str, or struct name)
    params = fn_decl.params
    if params != 0
        pi = 0
        pcnt = len(params)
        if pcnt > 6
            ctx.ctx_has_unsupported = 1
        end
        while pi < pcnt
            pnode = get(params, pi)
            p_name = pnode.param_name
            p_type = "i64"
            if pnode.param_type != 0 and pnode.param_type != ""
                p_type = ssa_normalize_type(pnode.param_type)
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

            // Allocate local entry stack slot and store initial parameter value
            slot = ast_to_ssa_alloc_var(ctx, p_name, p_type)
            st_inst = ir_build_store(ctx.ctx_inst_counter, p_val, slot)
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

    if ctx.ctx_has_unsupported == 0 and fn_name != "main" and fn_name != "_start"
        fn_obj.is_ssa_native_ready = 1
    else
        fn_obj.is_ssa_native_ready = 0
    end

    // Register function into module
    ir_module_add_function(mod_obj, fn_obj)
    return fn_obj

fn ast_to_ssa_lower_fn mod_obj fn_decl
    return ast_to_ssa_lower_fn_with_meta(mod_obj, fn_decl, list(), list(), list(), list(), list())

fn ast_to_ssa_lower_module ast_nodes target_name
    // WHY: Master entry point translating AST collection into complete IRModule.
    // Prescans all StructDef layouts and user FnDef signatures so functions with floats,
    // strings, structs, and cross-function calls lower cleanly directly from SSA IR.
    mod_obj = ir_module_new("lipi_translation_unit")
    ir_module_set_metadata(mod_obj, "target", target_name)
    ir_module_set_metadata(mod_obj, "producer", "LiPi First 1.0.0 (প্রথম ১.০.০)")

    if ast_nodes == 0 return mod_obj

    node_list = ast_nodes
    cnt = len(node_list)

    // Pass 1: Collect StructDef field tables and FnDef signatures
    struct_names = list()
    struct_fields = list()
    fn_names = list()
    fn_ret_types = list()
    fn_param_cnts = list()
    pi = 0
    while pi < cnt
        decl = get(node_list, pi)
        dkind = decl.kind
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
                        push(flist, fn_i.field_name)
                    end
                    fi = fi + 1
                end
            end
            push(struct_names, sname)
            push(struct_fields, flist)
        elif dkind == "FnDef" or dkind == "Function" or dkind == "কাজ"
            push(fn_names, decl.name)
            rt = "i64"
            if decl.ret_type != 0 and len(decl.ret_type) > 0
                rt = ssa_normalize_type(decl.ret_type)
            end
            push(fn_ret_types, rt)
            pc = 0
            if decl.params != 0
                pc = len(decl.params)
            end
            push(fn_param_cnts, pc)
        end
        pi = pi + 1
    end

    // Pass 2: Lower all functions & globals using collected schemas
    fn_ord = 0
    i = 0
    while i < cnt
        decl = get(node_list, i)
        dkind = decl.kind

        if dkind == "FnDef" or dkind == "Function" or dkind == "কাজ"
            low_f = ast_to_ssa_lower_fn_with_meta(mod_obj, decl, struct_names, struct_fields, fn_names, fn_ret_types, fn_param_cnts)
            if low_f != 0 and fn_ord < fn_ret_types.len() and low_f.return_type != ""
                list_set(fn_ret_types, fn_ord, low_f.return_type)
            end
            fn_ord = fn_ord + 1
        elif dkind == "GlobalVar" or dkind == "Constant"
            g_name = "@" + decl.name
            ir_module_add_global(mod_obj, g_name, "i64", decl.val, 1)
        i = i + 1

    return mod_obj

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
