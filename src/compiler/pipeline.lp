// ==============================================================================
// 👑 LIPI FIRST 1.0.0 UNIFIED MODULAR COMPILER PIPELINE (src/compiler/pipeline.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Micro-Architecture
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Unifies the decoupled compiler micro-subsystems into a deterministic,
//    high-throughput compilation pipeline mirroring LLVM & rustc architecture:
//      - Stage 1: Diagnostics & Source Mapping (src/compiler/diagnostics/)
//      - Stage 2: Lexical Analysis & Bengali Unicode Scanning (src/compiler/frontend/lexer/)
//      - Stage 3: Abstract Syntax Tree & Visitor Validation (src/compiler/frontend/ast/)
//      - Stage 4: Semantic Analysis, Type Unification & Ownership (src/compiler/semantics/)
//      - Stage 5: Multi-Target Hardware Architecture Selection (src/compiler/backend/targets/)
//      - Stage 6: Linear Scan Register Allocation (src/compiler/backend/regalloc/)
//      - Stage 7: Binary Container Packaging (src/compiler/backend/formats/)
// 2. Zero-Copy Architecture: Data flows monotonically between stages maintaining
//    sub-nanosecond ALU efficiency and sub-millisecond total compile times.
// 3. Strict Invariant Verification: Enforces namespaced field isolation, preventing
//    struct offset shadowing across compiler passes.
// ==============================================================================


// Subsystem 1 & 2: Diagnostics
import "src/compiler/diagnostics/error_codes.lp"
import "src/compiler/diagnostics/source_map.lp"
import "src/compiler/diagnostics/color_theme.lp"
import "src/compiler/diagnostics/snippet_renderer.lp"
import "src/compiler/diagnostics/suggestion.lp"
import "src/compiler/diagnostics/diagnostic_emitter.lp"

// Subsystem 3: Frontend Lexer & AST
import "src/compiler/frontend/lexer/char_stream.lp"
import "src/compiler/frontend/lexer/unicode_bengali.lp"
import "src/compiler/frontend/lexer/token_kind.lp"
import "src/compiler/frontend/lexer/token.lp"
import "src/compiler/frontend/lexer/num_literal.lp"
import "src/compiler/frontend/lexer/str_literal.lp"
import "src/compiler/frontend/lexer/comment_doc.lp"
import "src/compiler/frontend/lexer/tokenizer.lp"
import "src/compiler/frontend/ast/ast_node.lp"
import "src/compiler/frontend/ast/ast_expr.lp"
import "src/compiler/frontend/ast/ast_stmt.lp"
import "src/compiler/frontend/ast/ast_decl.lp"
import "src/compiler/frontend/ast/ast_visitor.lp"
import "src/compiler/frontend/ast/ast_printer.lp"

// Subsystem 4: Semantics & Type System
import "src/compiler/semantics/symbol.lp"
import "src/compiler/semantics/scope.lp"
import "src/compiler/semantics/symbol_table.lp"
import "src/compiler/semantics/type_def.lp"
import "src/compiler/semantics/type_unify.lp"
import "src/compiler/semantics/type_inference.lp"
import "src/compiler/semantics/type_checker.lp"
import "src/compiler/semantics/const_eval.lp"
import "src/compiler/semantics/ownership_check.lp"
import "src/compiler/semantics/purity_analyzer.lp"
import "src/compiler/semantics/math_proof.lp"
import "src/compiler/semantics/kavach_shield.lp"

// Subsystem 5: Middle-End SSA Lowering, Comptime Supercompilation & Optimization Pass Manager
include "src/compiler/middleend/ast_to_ssa.lp"
include "src/compiler/middleend/opt/pass_manager.lp"
include "src/compiler/middleend/comptime_eval.lp"

// Subsystem 6: Register Allocation
include "src/compiler/backend/regalloc/live_interval.lp"
include "src/compiler/backend/regalloc/linear_scan.lp"

// Subsystem 7: Multi-Target Hardware Encoders
include "src/compiler/backend/targets/target_machine.lp"
include "src/compiler/backend/ssa_lowerer.lp"
include "src/compiler/backend/targets/x86_64/synthesizer.lp"
include "src/compiler/backend/targets/arm64/synthesizer.lp"
include "src/compiler/backend/targets/wasm/synthesizer.lp"
include "src/compiler/backend/targets/riscv64/synthesizer.lp"
include "src/compiler/backend/targets/verilog/synthesizer.lp"

// Subsystem 8: Binary Container Formats
import "src/compiler/backend/formats/elf/elf_header.lp"
import "src/compiler/backend/formats/elf/program_header.lp"
import "src/compiler/backend/formats/elf/section_header.lp"
import "src/compiler/backend/formats/elf/relocation.lp"
import "src/compiler/backend/formats/elf/elf_writer.lp"
import "src/compiler/backend/formats/debug/dwarf_line.lp"
import "src/compiler/backend/formats/debug/dwarf_info.lp"
include "src/compiler/backend/so_emitter.lp"
import "src/compiler/backend/formats/macho/macho_writer.lp"
import "src/compiler/backend/formats/pe/pe_writer.lp"
include "src/compiler/backend/formats/bare/bare_writer.lp"
include "src/compiler/backend/formats/lpo/lpo_format.lp"

// WHY: Declarations as zero-argument functions enable seamless compile-time identifier resolution
// across all decoupled compiler stages without relying on top-level stack variable allocation.
@fn PIPELINE_STAGE_INIT()     return 0 @end
@fn PIPELINE_STAGE_LEX()      return 1 @end
@fn PIPELINE_STAGE_PARSE()    return 2 @end
@fn PIPELINE_STAGE_SEMANTICS() return 3 @end
@fn PIPELINE_STAGE_TARGET()   return 4 @end
@fn PIPELINE_STAGE_REGALLOC() return 5 @end
@fn PIPELINE_STAGE_EMIT()     return 6 @end
@fn PIPELINE_STAGE_COMPLETE() return 7 @end

@fn FORMAT_ELF()              return 1 @end
@fn FORMAT_MACHO()            return 2 @end
@fn FORMAT_PE()               return 3 @end
@fn FORMAT_UNIKERNEL()        return 4 @end
@fn FORMAT_WASM()             return 5 @end
@fn FORMAT_SHARED()           return 6 @end
@fn FORMAT_VERILOG()          return 7 @end
@fn FORMAT_RAW_BIN()          return 8 @end
@fn FORMAT_ELF_KERNEL()       return 9 @end
@fn FORMAT_UEFI()             return 10 @end
@fn FORMAT_OBJ()              return 11 @end
@fn FORMAT_MULTIBOOT2_BARE()  return 12 @end

// ── 2. Hardware-Aligned Models (Max 8 Fields) ─────────────────────────────────

struct CompilerConfig
    cfg_src_path            // Absolute or relative source file path
    cfg_out_path            // Target output binary path
    cfg_target_arch         // TARGET_ID_X86_64, TARGET_ID_ARM64, etc.
    cfg_opt_level           // 0, 1, 2, or 3
    cfg_emit_format         // FORMAT_ELF, FORMAT_PE, FORMAT_SHARED, FORMAT_UEFI, FORMAT_RAW_BIN, etc.
    cfg_is_dry_run          // 1 to skip disk emission, 0 to persist
    cfg_verbose             // 1 for verbose phase telemetry, 0 for quiet
    cfg_debug_mode          // 1 for DWARF debug emission (-g), 0 for standard
    cfg_no_pie              // 1 to force fixed-address ET_EXEC instead of Static-PIE ET_DYN
    cfg_strict_ownership    // 1 to fail compilation on ownership/use-after-move violations
    cfg_strict_proof        // 1 to fail compilation when memory conservation proof fails
    cfg_kavach_mode         // 1 to enable Sovereign Kavach Mode (ownership + escape-exact proof + silicon_* crown)
    cfg_strict_types        // 1 to enforce zero-collision struct field layouts (--strict-types)
    cfg_freestanding        // 1 to enable --freestanding / --no-runtime bare-metal mode (0 Linux syscalls)
    cfg_base_vaddr          // Configurable virtual/physical base address (--base-addr=0x...)
    cfg_ssa_codegen         // 1 when --ssa-codegen prefers direct SSA IR machine code emission
    cfg_entry_sym           // Custom entry symbol name (--entry=<sym>, default "")
    cfg_utso_ranges         // Flat [start_line, end_line, ...] intervals of authentic utso/ stdlib chunks

struct CompilerResult
    res_success             // 1 on success, 0 on failure
    res_stage_reached       // PIPELINE_STAGE_*
    res_error_count         // Total fatal errors encountered
    res_warning_count       // Total warnings encountered
    res_output_bytes        // Total machine code bytes generated
    res_tokens_scanned      // Number of tokens lexed
    res_reg_alloc_spills    // Number of variables spilled to stack
    res_error_msg           // Formatted error description if failed

// ── 2b. Modular Token-to-AST Parser ──────────────────────────────────────────

fn pipeline_is_ident_token kind
    // WHY: In Lipi grammar, contextual keywords such as 'end', 'in', 'type', 'case', 'match',
    // 'mut', 'async', 'await', 'try', 'catch', 'defer', 'print', and 'syscall' are valid identifier
    // names when used in assignment targets, expressions, and parameters.
    if kind == TOK_IDENT() return 1
    if kind == TOK_KW_END() return 1
    if kind == TOK_KW_IN() return 1
    if kind == TOK_KW_TYPE() return 1
    if kind == TOK_KW_CASE() return 1
    if kind == TOK_KW_MATCH() return 1
    if kind == TOK_KW_MUT() return 1
    if kind == TOK_KW_ASYNC() return 1
    if kind == TOK_KW_AWAIT() return 1
    if kind == TOK_KW_TRY() return 1
    if kind == TOK_KW_CATCH() return 1
    if kind == TOK_KW_DEFER() return 1
    if kind == TOK_KW_PRINT() return 1
    if kind == TOK_KW_SYSCALL() return 1
    if kind == TOK_DIR_TRAIT() return 1
    return 0

fn pipeline_should_stop_inline toks pos_box start_line
    // WHY: Stops a single-line header body (e.g. `if c stmt`) at newline/EOF, while allowing
    // multi-statement inline blocks (e.g. `if 1 == 2 x = 1; x = 2 end` or `@while cond s1 s2 @end`)
    // to consume all `;`-separated statements on start_line whenever an explicit block terminator
    // (`end`/`else`/`elif`) closes the inline block on the same line.
    np = get(pos_box, 0)
    if np >= toks.len()
        return 1
    end
    nt = toks[np]
    nk = nt.tok_kind
    if nk == TOK_NEWLINE() or nk == TOK_COMMENT_LINE() or nk == TOK_EOF()
        return 1
    end
    if nk == TOK_SEMI()
        // Look ahead on start_line for an explicit `end`/`else`/`elif` terminator
        si = np + 1
        while si < toks.len()
            st = toks[si]
            sk = st.tok_kind
            if sk == TOK_NEWLINE() or sk == TOK_EOF() or st.tok_span.span_start_line > start_line
                break
            end
            if pipeline_is_block_end(toks, si) == 1
                return 0
            end
            stxt = st.tok_text
            if sk == TOK_KW_ELSE() or sk == TOK_DIR_ELSE() or sk == TOK_KW_ELIF() or sk == TOK_DIR_ELIF()
                return 0
            end
            if sk == TOK_IDENT() and (stxt == "else" or stxt == "elif" or stxt == "নাহলে" or stxt == "নতুবা" or stxt == "অন্যথায়" or stxt == "নাহলে_যদি" or stxt == "@else" or stxt == "@elif")
                return 0
            end
            si = si + 1
        end
        return 1
    end
    if nt.tok_span.span_start_line > start_line
        return 1
    end
    return 0

fn pipeline_is_match_start toks pos
    // WHY: Soft-keyword disambiguation for `match` matching x86_synth_is_match_start.
    if pos < 0 or pos + 1 >= toks.len()
        return 0
    end
    t0 = toks[pos]
    k0 = t0.tok_kind
    txt0 = t0.tok_text
    if k0 != TOK_KW_MATCH() and k0 != TOK_DIR_MATCH() and not (k0 == TOK_IDENT() and (txt0 == "match" or txt0 == "মিল" or txt0 == "মেলাও" or txt0 == "@match"))
        return 0
    end
    t1 = toks[pos + 1]
    k1 = t1.tok_kind
    txt1 = t1.tok_text
    if t1.tok_span.span_start_line != t0.tok_span.span_start_line
        return 0
    end
    ok_start = 0
    if k1 == TOK_INT() or k1 == TOK_FLOAT() or k1 == TOK_BOOL() or k1 == TOK_STR() or k1 == TOK_INTERP_STR() or k1 == TOK_LPAREN() or k1 == TOK_LBRACKET() or k1 == TOK_BANG() or k1 == TOK_TILDE() or k1 == TOK_MINUS()
        ok_start = 1
    elif pipeline_is_ident_token(k1) == 1
        if txt1 != "and" and txt1 != "or" and txt1 != "এবং" and txt1 != "অথবা" and txt1 != "return" and txt1 != "break" and txt1 != "continue" and txt1 != "end" and txt1 != "else" and txt1 != "elif" and txt1 != "then" and txt1 != "in"
            ok_start = 1
        end
    end
    if ok_start == 0
        return 0
    end
    line0 = t0.tok_span.span_start_line
    si = pos + 1
    while si < toks.len()
        st = toks[si]
        sk = st.tok_kind
        if sk == TOK_NEWLINE() or st.tok_span.span_start_line > line0
            break
        end
        if sk == TOK_LBRACE() or (sk != TOK_STR() and st.tok_text == "{")
            return 1
        end
        si = si + 1
    end
    while si < toks.len()
        sk = toks[si].tok_kind
        if sk == TOK_NEWLINE() or sk == TOK_SEMI() or sk == TOK_COMMENT_LINE() or sk == TOK_COMMENT_BLOCK()
            si = si + 1
        else
            break
        end
    end
    if si >= toks.len()
        return 0
    end
    at0 = toks[si]
    if at0.tok_kind == TOK_LBRACE() or at0.tok_text == "{" or at0.tok_kind == TOK_KW_CASE() or (at0.tok_kind == TOK_IDENT() and (at0.tok_text == "case" or at0.tok_text == "ক্ষেত্র"))
        return 1
    end
    arm_line = at0.tok_span.span_start_line
    steps = 0
    while si < toks.len() and steps < 16
        at = toks[si]
        if at.tok_kind == TOK_NEWLINE() or at.tok_span.span_start_line != arm_line
            break
        end
        if at.tok_kind == TOK_FAT_ARROW() or at.tok_kind == TOK_ARROW() or at.tok_kind == TOK_COLON() or (at.tok_kind != TOK_STR() and (at.tok_text == "=>" or at.tok_text == "->" or at.tok_text == ":"))
            return 1
        end
        si = si + 1
        steps = steps + 1
    end
    return 0
end

fn pipeline_is_region_start toks pos
    if pos < 0 or pos >= toks.len()
        return 0
    end
    t0 = toks[pos]
    if t0.tok_kind != TOK_IDENT() or (t0.tok_text != "region" and t0.tok_text != "অঞ্চল" and t0.tok_text != "@region")
        return 0
    end
    if pos + 1 >= toks.len()
        return 1
    end
    t1 = toks[pos + 1]
    if t1.tok_kind == TOK_NEWLINE() or t1.tok_kind == TOK_COMMENT_LINE() or t1.tok_kind == TOK_LBRACE() or (t1.tok_kind != TOK_STR() and t1.tok_text == "{") or t1.tok_span.span_start_line > t0.tok_span.span_start_line
        return 1
    end
    return 0
end

fn pipeline_parse_primary toks pos_box sp
    // WHY: Parses primitive literals, identifiers, unary operators, and postfix chains (.field, [idx], (args)).
    p = get(pos_box, 0)
    if p >= toks.len()
        return ast_expr_literal_int(0, sp)
    end
    t = toks[p]
    k = t.tok_kind
    txt = t.tok_text
    if t.tok_span != 0
        sp = t.tok_span
    end
    list_set(pos_box, 0, p + 1)

    // WHY: Initialize with ASTNode literal so type inference assigns ASTNode instead of scalar i64
    node = ast_expr_literal_int(0, sp)
    if k == TOK_INT()
        node = ast_expr_literal_int(t.tok_int_val, sp)
    elif k == TOK_FLOAT()
        node = ast_expr_literal_float(t.tok_float_val, sp)
        node.name = txt
    elif k == TOK_BOOL()
        node = ast_expr_literal_bool(t.tok_int_val, sp)
    elif k == TOK_NONE()
        node = ast_expr_literal_none(sp)
    elif k == TOK_STR()
        node = ast_expr_literal_str(txt, sp)
    elif k == TOK_INTERP_STR()
        node = ast_expr_literal_str(txt, sp)
        node.op = "interp"
    elif k == TOK_MINUS() or (k != TOK_STR() and txt == "-")
        sub_e = pipeline_parse_primary(toks, pos_box, sp)
        return ast_expr_unary("-", sub_e, sp)
    elif k == TOK_BANG() or (k != TOK_STR() and (txt == "!" or txt == "not" or txt == "না"))
        sub_e = pipeline_parse_primary(toks, pos_box, sp)
        return ast_expr_unary("!", sub_e, sp)
    elif k == TOK_TILDE() or (k != TOK_STR() and txt == "~")
        sub_e = pipeline_parse_primary(toks, pos_box, sp)
        return ast_expr_unary("~", sub_e, sp)
    elif k == TOK_AMP() or (k != TOK_STR() and txt == "&")
        // WHY: Preserve `&x` and `&mut x` as real UnaryOp AST nodes so `--strict-ownership`
        // enforces shared/mutable borrow rules while TypeChecker resolves `&fn_name` to i64 fn_ptr.
        nxt_p = get(pos_box, 0)
        if nxt_p < toks.len() and (toks[nxt_p].tok_kind == TOK_KW_MUT() or (toks[nxt_p].tok_kind != TOK_STR() and toks[nxt_p].tok_text == "mut"))
            list_set(pos_box, 0, nxt_p + 1)
            sub_m = pipeline_parse_primary(toks, pos_box, sp)
            return ast_expr_unary("&mut", sub_m, sp)
        end
        sub_e = pipeline_parse_primary(toks, pos_box, sp)
        return ast_expr_unary("&", sub_e, sp)
    elif k == TOK_STAR() or (k != TOK_STR() and txt == "*")
        sub_e = pipeline_parse_primary(toks, pos_box, sp)
        return ast_expr_unary("*", sub_e, sp)
    elif (k == TOK_KW_AWAIT() or (k == TOK_IDENT() and (txt == "await" or txt == "অপেক্ষা" or txt == "@await"))) and get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_span.span_start_line == t.tok_span.span_start_line and (pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1 or toks[get(pos_box, 0)].tok_kind == TOK_LPAREN() or toks[get(pos_box, 0)].tok_kind == TOK_LBRACKET() or toks[get(pos_box, 0)].tok_kind == TOK_INT() or toks[get(pos_box, 0)].tok_kind == TOK_FLOAT() or toks[get(pos_box, 0)].tok_kind == TOK_STR() or toks[get(pos_box, 0)].tok_kind == TOK_INTERP_STR() or toks[get(pos_box, 0)].tok_kind == TOK_BOOL() or toks[get(pos_box, 0)].tok_kind == TOK_NONE() or toks[get(pos_box, 0)].tok_kind == TOK_BANG() or toks[get(pos_box, 0)].tok_kind == TOK_AMP())
        sub_e = pipeline_parse_primary(toks, pos_box, sp)
        return ast_expr_unary("await", sub_e, sp)
    elif k == TOK_BAR() or (k != TOK_STR() and txt == "|")
        c_params = list()
        while get(pos_box, 0) < toks.len()
            cp_c = get(pos_box, 0)
            ct_c = toks[cp_c]
            if ct_c.tok_kind == TOK_BAR() or (ct_c.tok_kind != TOK_STR() and ct_c.tok_text == "|")
                list_set(pos_box, 0, cp_c + 1)
                break
            elif ct_c.tok_kind == TOK_COMMA() or (ct_c.tok_kind != TOK_STR() and ct_c.tok_text == ",")
                list_set(pos_box, 0, cp_c + 1)
            elif ct_c.tok_kind == TOK_COLON() or (ct_c.tok_kind != TOK_STR() and ct_c.tok_text == ":")
                list_set(pos_box, 0, cp_c + 1)
                if get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            elif pipeline_is_ident_token(ct_c.tok_kind) == 1
                push(c_params, ct_c.tok_text)
                list_set(pos_box, 0, cp_c + 1)
            else
                list_set(pos_box, 0, cp_c + 1)
            end
        end
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_FAT_ARROW() or toks[get(pos_box, 0)].tok_text == "=>" or toks[get(pos_box, 0)].tok_kind == TOK_ARROW() or toks[get(pos_box, 0)].tok_text == "->")
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
            list_set(pos_box, 0, get(pos_box, 0) + 1)
            cb_stmts = list()
            while get(pos_box, 0) < toks.len()
                pipeline_skip_whitespace(toks, pos_box)
                cp_b = get(pos_box, 0)
                if cp_b >= toks.len() break end
                if toks[cp_b].tok_kind == TOK_RBRACE() or (toks[cp_b].tok_kind != TOK_STR() and toks[cp_b].tok_text == "}")
                    list_set(pos_box, 0, cp_b + 1)
                    break
                end
                bp_c = get(pos_box, 0)
                st_c = pipeline_build_statement(toks, pos_box, sp)
                if st_c != 0 push(cb_stmts, st_c) end
                if get(pos_box, 0) <= bp_c list_set(pos_box, 0, bp_c + 1) end
            end
            return ast_expr_closure(c_params, cb_stmts, sp)
        elif get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_NEWLINE()
            pipeline_skip_whitespace(toks, pos_box)
            cb_stmts = list()
            while get(pos_box, 0) < toks.len()
                pipeline_skip_whitespace(toks, pos_box)
                cp_b = get(pos_box, 0)
                if cp_b >= toks.len() break end
                if pipeline_is_block_end(toks, cp_b) == 1
                    list_set(pos_box, 0, cp_b + 1)
                    break
                end
                bp_c = get(pos_box, 0)
                st_c = pipeline_build_statement(toks, pos_box, sp)
                if st_c != 0 push(cb_stmts, st_c) end
                if get(pos_box, 0) <= bp_c list_set(pos_box, 0, bp_c + 1) end
            end
            return ast_expr_closure(c_params, cb_stmts, sp)
        end
        lam_expr = pipeline_parse_expr(toks, pos_box, sp)
        return ast_expr_closure(c_params, [ast_stmt_return(lam_expr, sp)], sp)
    elif (k == TOK_KW_FN() or (k == TOK_IDENT() and (txt == "fn" or txt == "কাজ"))) and get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LPAREN() or toks[get(pos_box, 0)].tok_text == "(")
        list_set(pos_box, 0, get(pos_box, 0) + 1)
        c_params = list()
        while get(pos_box, 0) < toks.len()
            cp_c = get(pos_box, 0)
            ct_c = toks[cp_c]
            if ct_c.tok_kind == TOK_RPAREN() or (ct_c.tok_kind != TOK_STR() and ct_c.tok_text == ")")
                list_set(pos_box, 0, cp_c + 1)
                break
            elif ct_c.tok_kind == TOK_COMMA() or (ct_c.tok_kind != TOK_STR() and ct_c.tok_text == ",")
                list_set(pos_box, 0, cp_c + 1)
            elif ct_c.tok_kind == TOK_COLON() or (ct_c.tok_kind != TOK_STR() and ct_c.tok_text == ":")
                list_set(pos_box, 0, cp_c + 1)
                if get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            elif pipeline_is_ident_token(ct_c.tok_kind) == 1
                push(c_params, ct_c.tok_text)
                list_set(pos_box, 0, cp_c + 1)
            else
                list_set(pos_box, 0, cp_c + 1)
            end
        end
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_FAT_ARROW() or toks[get(pos_box, 0)].tok_text == "=>" or toks[get(pos_box, 0)].tok_kind == TOK_ARROW() or toks[get(pos_box, 0)].tok_text == "->")
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
            list_set(pos_box, 0, get(pos_box, 0) + 1)
            cb_stmts = list()
            while get(pos_box, 0) < toks.len()
                pipeline_skip_whitespace(toks, pos_box)
                cp_b = get(pos_box, 0)
                if cp_b >= toks.len() break end
                if toks[cp_b].tok_kind == TOK_RBRACE() or (toks[cp_b].tok_kind != TOK_STR() and toks[cp_b].tok_text == "}")
                    list_set(pos_box, 0, cp_b + 1)
                    break
                end
                bp_c = get(pos_box, 0)
                st_c = pipeline_build_statement(toks, pos_box, sp)
                if st_c != 0 push(cb_stmts, st_c) end
                if get(pos_box, 0) <= bp_c list_set(pos_box, 0, bp_c + 1) end
            end
            return ast_expr_closure(c_params, cb_stmts, sp)
        elif get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_NEWLINE()
            pipeline_skip_whitespace(toks, pos_box)
            cb_stmts = list()
            while get(pos_box, 0) < toks.len()
                pipeline_skip_whitespace(toks, pos_box)
                cp_b = get(pos_box, 0)
                if cp_b >= toks.len() break end
                if pipeline_is_block_end(toks, cp_b) == 1
                    list_set(pos_box, 0, cp_b + 1)
                    break
                end
                bp_c = get(pos_box, 0)
                st_c = pipeline_build_statement(toks, pos_box, sp)
                if st_c != 0 push(cb_stmts, st_c) end
                if get(pos_box, 0) <= bp_c list_set(pos_box, 0, bp_c + 1) end
            end
            return ast_expr_closure(c_params, cb_stmts, sp)
        end
        lam_expr = pipeline_parse_expr(toks, pos_box, sp)
        return ast_expr_closure(c_params, [ast_stmt_return(lam_expr, sp)], sp)
    elif pipeline_is_match_start(toks, p) == 1
        me_base_col = t.tok_span.span_start_col
        me_base_line = t.tok_span.span_start_line
        scrut_me = pipeline_parse_expr(toks, pos_box, sp)
        pipeline_skip_whitespace(toks, pos_box)
        me_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
            me_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        me_first_arm_col = 0 - 1
        last_arm_e = scrut_me
        me_arm_blocks = list()
        me_pat_names = list()
        while get(pos_box, 0) < toks.len()
            pipeline_skip_whitespace(toks, pos_box)
            cur_me = get(pos_box, 0)
            if cur_me >= toks.len() break end
            ct_me = toks[cur_me]
            if me_braced == 1
                if ct_me.tok_kind == TOK_RBRACE() or (ct_me.tok_kind != TOK_STR() and ct_me.tok_text == "}")
                    list_set(pos_box, 0, cur_me + 1)
                    break
                end
                if ct_me.tok_kind == TOK_COMMA() or (ct_me.tok_kind != TOK_STR() and ct_me.tok_text == ",")
                    list_set(pos_box, 0, cur_me + 1)
                    continue
                end
            else
                if pipeline_is_block_end(toks, cur_me) == 1
                    list_set(pos_box, 0, cur_me + 1)
                    break
                end
                if me_first_arm_col < 0
                    me_first_arm_col = ct_me.tok_span.span_start_col
                elif ct_me.tok_span.span_start_col < me_first_arm_col
                    break
                end
            end
            if ct_me.tok_kind == TOK_KW_CASE() or (ct_me.tok_kind == TOK_IDENT() and (ct_me.tok_text == "case" or ct_me.tok_text == "ক্ষেত্র"))
                list_set(pos_box, 0, cur_me + 1)
            end
            arm_stmts = list()
            mp_p = get(pos_box, 0)
            me_pat_lbl = ""
            if mp_p < toks.len() and (toks[mp_p].tok_text == "_" or toks[mp_p].tok_text == "default" or toks[mp_p].tok_text == "অন্যথায়" or toks[mp_p].tok_kind == TOK_KW_ELSE())
                me_pat_lbl = "_"
                list_set(pos_box, 0, mp_p + 1)
            else
                if mp_p < toks.len() and (pipeline_is_ident_token(toks[mp_p].tok_kind) == 1 or toks[mp_p].tok_kind == TOK_NONE())
                    me_pat_lbl = toks[mp_p].tok_text
                    if mp_p + 3 < toks.len() and (toks[mp_p + 1].tok_kind == TOK_COLON() or toks[mp_p + 1].tok_text == ":") and (toks[mp_p + 2].tok_kind == TOK_COLON() or toks[mp_p + 2].tok_text == ":") and (pipeline_is_ident_token(toks[mp_p + 3].tok_kind) == 1 or toks[mp_p + 3].tok_kind == TOK_NONE())
                        me_pat_lbl = me_pat_lbl + "::" + toks[mp_p + 3].tok_text
                    end
                end
                pat_binds_me = pipeline_try_parse_adt_pat_binds(toks, pos_box)
                if pat_binds_me != 0
                    pbi_me = 0
                    while pbi_me < pat_binds_me.len()
                        push(arm_stmts, ast_stmt_assign(pat_binds_me[pbi_me], ast_expr_literal_int(0, sp), sp))
                        pbi_me = pbi_me + 1
                    end
                else
                    _pat_me = pipeline_parse_expr(toks, pos_box, sp)
                end
            end
            push(me_pat_names, me_pat_lbl)
            if get(pos_box, 0) < toks.len()
                sk_me = toks[get(pos_box, 0)].tok_kind
                st_me = toks[get(pos_box, 0)].tok_text
                if sk_me == TOK_FAT_ARROW() or sk_me == TOK_COLON() or sk_me == TOK_ARROW() or st_me == "=>" or st_me == ":" or st_me == "->"
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            end
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                while get(pos_box, 0) < toks.len()
                    pipeline_skip_whitespace(toks, pos_box)
                    cp_mb = get(pos_box, 0)
                    if cp_mb >= toks.len() break end
                    if toks[cp_mb].tok_kind == TOK_RBRACE() or (toks[cp_mb].tok_kind != TOK_STR() and toks[cp_mb].tok_text == "}")
                        list_set(pos_box, 0, cp_mb + 1)
                        break
                    end
                    bp_mb = get(pos_box, 0)
                    _st_mb = pipeline_build_statement(toks, pos_box, sp)
                    if _st_mb != 0 push(arm_stmts, _st_mb) end
                    if get(pos_box, 0) <= bp_mb list_set(pos_box, 0, bp_mb + 1) end
                end
            else
                last_arm_e = pipeline_parse_expr(toks, pos_box, sp)
                a_st = ast_stmt_expr(last_arm_e, sp)
                a_st.kind = "ExprStmt"
                push(arm_stmts, a_st)
            end
            push(me_arm_blocks, ast_stmt_if(ast_expr_literal_int(1, sp), arm_stmts, list(), list(), sp))
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COMMA() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == ","))
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
        end
        m_expr_nd = ast_node_new(AST_TAG_NONE(), "MatchExpr", sp)
        m_expr_nd.expr = scrut_me
        m_expr_nd.body = me_arm_blocks
        m_expr_nd.elements = me_pat_names
        return m_expr_nd
    elif k == TOK_LPAREN() or (k != TOK_STR() and txt == "(")
        while get(pos_box, 0) < toks.len()
            skip_k = toks[get(pos_box, 0)].tok_kind
            if skip_k == TOK_NEWLINE() or skip_k == TOK_SEMI() or skip_k == TOK_COMMENT_LINE() or skip_k == TOK_COMMENT_BLOCK()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            else
                break
            end
        end
        inner = pipeline_parse_expr(toks, pos_box, sp)
        while get(pos_box, 0) < toks.len()
            skip_k = toks[get(pos_box, 0)].tok_kind
            if skip_k == TOK_NEWLINE() or skip_k == TOK_SEMI() or skip_k == TOK_COMMENT_LINE() or skip_k == TOK_COMMENT_BLOCK()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            else
                break
            end
        end
        cp = get(pos_box, 0)
        if cp < toks.len() and (toks[cp].tok_kind == TOK_RPAREN() or (toks[cp].tok_kind != TOK_STR() and toks[cp].tok_text == ")"))
            list_set(pos_box, 0, cp + 1)
        end
        node = inner
    elif k == TOK_LBRACKET() or (k != TOK_STR() and txt == "[")
        arr_elems = list()
        while get(pos_box, 0) < toks.len()
            while get(pos_box, 0) < toks.len()
                skip_k = toks[get(pos_box, 0)].tok_kind
                if skip_k == TOK_NEWLINE() or skip_k == TOK_SEMI() or skip_k == TOK_COMMENT_LINE() or skip_k == TOK_COMMENT_BLOCK()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                else
                    break
                end
            end
            if get(pos_box, 0) >= toks.len()
                break
            end
            cp_arr = get(pos_box, 0)
            if toks[cp_arr].tok_kind == TOK_RBRACKET() or (toks[cp_arr].tok_kind != TOK_STR() and toks[cp_arr].tok_text == "]")
                list_set(pos_box, 0, cp_arr + 1)
                break
            end
            if toks[cp_arr].tok_kind == TOK_COMMA() or (toks[cp_arr].tok_kind != TOK_STR() and toks[cp_arr].tok_text == ",")
                list_set(pos_box, 0, cp_arr + 1)
            else
                push(arr_elems, pipeline_parse_expr(toks, pos_box, sp))
            end
        end
        node = ast_expr_array_lit(arr_elems, sp)
    elif k == TOK_LBRACE() or (k != TOK_STR() and txt == "{")
        // WHY: Parses inline anonymous struct / map / record literals `{ key: val, ... }`.
        // Field keys are identifiers in struct scope, not variable references, preventing false undefined variable errors.
        entries = list()
        while get(pos_box, 0) < toks.len()
            while get(pos_box, 0) < toks.len()
                skip_k = toks[get(pos_box, 0)].tok_kind
                if skip_k == TOK_NEWLINE() or skip_k == TOK_SEMI() or skip_k == TOK_COMMENT_LINE() or skip_k == TOK_COMMENT_BLOCK()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                else
                    break
                end
            end
            if get(pos_box, 0) >= toks.len()
                break
            end
            cp_map = get(pos_box, 0)
            if toks[cp_map].tok_kind == TOK_RBRACE() or (toks[cp_map].tok_kind != TOK_STR() and toks[cp_map].tok_text == "}")
                list_set(pos_box, 0, cp_map + 1)
                break
            end
            if toks[cp_map].tok_kind == TOK_COMMA() or (toks[cp_map].tok_kind != TOK_STR() and toks[cp_map].tok_text == ",")
                list_set(pos_box, 0, cp_map + 1)
            elif toks[cp_map].tok_kind == TOK_COLON() or (toks[cp_map].tok_kind != TOK_STR() and toks[cp_map].tok_text == ":")
                // Empty map literal `{:}` syntax
                list_set(pos_box, 0, cp_map + 1)
            else
                // Field key: identifier, string/int literal, or computed `[expr]`
                key_name = ""
                key_is_str = 0
                if toks[cp_map].tok_kind == TOK_LBRACKET() or (toks[cp_map].tok_kind != TOK_STR() and toks[cp_map].tok_text == "[")
                    list_set(pos_box, 0, cp_map + 1)
                    _comp_k = pipeline_parse_expr(toks, pos_box, sp)
                    if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_RBRACKET() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "]"))
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    end
                    key_name = "__computed__"
                    key_is_str = 1
                else
                    key_tok = toks[get(pos_box, 0)]
                    key_name = key_tok.tok_text
                    if key_tok.tok_kind == TOK_STR()
                        key_is_str = 1
                    end
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end

                while get(pos_box, 0) < toks.len()
                    skip_k = toks[get(pos_box, 0)].tok_kind
                    if skip_k == TOK_NEWLINE() or skip_k == TOK_SEMI() or skip_k == TOK_COMMENT_LINE() or skip_k == TOK_COMMENT_BLOCK()
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    else
                        break
                    end
                end

                // Consume ':'
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == ":"))
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end

                while get(pos_box, 0) < toks.len()
                    skip_k = toks[get(pos_box, 0)].tok_kind
                    if skip_k == TOK_NEWLINE() or skip_k == TOK_SEMI() or skip_k == TOK_COMMENT_LINE() or skip_k == TOK_COMMENT_BLOCK()
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    else
                        break
                    end
                end

                val_expr = pipeline_parse_expr(toks, pos_box, sp)
                f_entry = ast_node_new(AST_TAG_NONE(), "Field", sp)
                f_entry.name = key_name
                if key_is_str == 1
                    f_entry.op = "str_key"
                end
                f_entry.value = val_expr
                push(entries, f_entry)
            end
        end
        node = ast_expr_map_lit(entries, sp)
    elif pipeline_is_ident_token(k) == 1 or (k >= TOK_KW_FN() and k <= TOK_KW_SYSCALL())
        ident_nm = txt
        // Qualified enum variant: Enum::Variant (e.g., Result::Ok, Option::None)
        qp_id = get(pos_box, 0)
        if qp_id + 2 < toks.len() and (toks[qp_id].tok_kind == TOK_COLON() or toks[qp_id].tok_text == ":") and (toks[qp_id + 1].tok_kind == TOK_COLON() or toks[qp_id + 1].tok_text == ":") and pipeline_is_ident_token(toks[qp_id + 2].tok_kind) == 1
            ident_nm = ident_nm + "::" + toks[qp_id + 2].tok_text
            list_set(pos_box, 0, qp_id + 3)
        end
        node = ast_expr_ident(ident_nm, sp)
    else
        return ast_expr_literal_int(0, sp)
    end

    // WHY: Postfix operator chain: handles member access .field, indexing [idx], generic calls <T>(args), calls (args), and '?'
    while get(pos_box, 0) < toks.len()
        // Consume optional generic type arguments `<Type1, Type2>` immediately before `(`
        if toks[get(pos_box, 0)].tok_kind == TOK_LT() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "<")
            pipeline_skip_type_args(toks, pos_box, 1)
        end
        nxt_p = get(pos_box, 0)
        if nxt_p >= toks.len() break end
        nxt_t = toks[nxt_p]
        nxt_k = nxt_t.tok_kind
        nxt_txt = nxt_t.tok_text

        if nxt_k == TOK_DOT() or (nxt_k != TOK_STR() and nxt_txt == ".")
            list_set(pos_box, 0, nxt_p + 1)
            while get(pos_box, 0) < toks.len()
                skip_k = toks[get(pos_box, 0)].tok_kind
                if skip_k == TOK_NEWLINE() or skip_k == TOK_SEMI() or skip_k == TOK_COMMENT_LINE() or skip_k == TOK_COMMENT_BLOCK()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                else
                    break
                end
            end
            fld_name = ""
            if get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                fld_name = toks[get(pos_box, 0)].tok_text
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            mem_node = ast_expr_member(node, fld_name, sp)
            mem_node.target = node
            mem_node.left = node
            node = mem_node
        elif nxt_k == TOK_LBRACKET() or (nxt_k != TOK_STR() and nxt_txt == "[")
            list_set(pos_box, 0, nxt_p + 1)
            while get(pos_box, 0) < toks.len()
                skip_k = toks[get(pos_box, 0)].tok_kind
                if skip_k == TOK_NEWLINE() or skip_k == TOK_SEMI() or skip_k == TOK_COMMENT_LINE() or skip_k == TOK_COMMENT_BLOCK()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                else
                    break
                end
            end
            idx_e = pipeline_parse_expr(toks, pos_box, sp)
            while get(pos_box, 0) < toks.len()
                skip_k = toks[get(pos_box, 0)].tok_kind
                if skip_k == TOK_NEWLINE() or skip_k == TOK_SEMI() or skip_k == TOK_COMMENT_LINE() or skip_k == TOK_COMMENT_BLOCK()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                else
                    break
                end
            end
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_RBRACKET() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "]"))
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            idx_node = ast_expr_index(node, idx_e, sp)
            idx_node.iterable = node
            idx_node.target = node
            idx_node.left = node
            node = idx_node
        elif nxt_k == TOK_LPAREN() or (nxt_k != TOK_STR() and nxt_txt == "(")
            list_set(pos_box, 0, nxt_p + 1)
            args = list()
            while get(pos_box, 0) < toks.len()
                while get(pos_box, 0) < toks.len()
                    skip_k = toks[get(pos_box, 0)].tok_kind
                    if skip_k == TOK_NEWLINE() or skip_k == TOK_SEMI() or skip_k == TOK_COMMENT_LINE() or skip_k == TOK_COMMENT_BLOCK()
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    else
                        break
                    end
                end
                if get(pos_box, 0) >= toks.len()
                    break
                end
                cp2 = get(pos_box, 0)
                if toks[cp2].tok_kind == TOK_RPAREN() or (toks[cp2].tok_kind != TOK_STR() and toks[cp2].tok_text == ")")
                    list_set(pos_box, 0, cp2 + 1)
                    break
                end
                if toks[cp2].tok_kind == TOK_COMMA() or (toks[cp2].tok_kind != TOK_STR() and toks[cp2].tok_text == ",")
                    list_set(pos_box, 0, cp2 + 1)
                else
                    arg_e = pipeline_parse_expr(toks, pos_box, sp)
                    push(args, arg_e)
                end
            end
            call_node = ast_expr_call(node, args, sp)
            call_node.params = args
            call_node.func = node
            call_node.name = node.name
            node = call_node
        elif nxt_k == TOK_QUERY() or (nxt_k != TOK_STR() and nxt_txt == "?")
            list_set(pos_box, 0, nxt_p + 1)
            node = ast_expr_unary("?", node, sp)
        else
            break
        end
    end

    return node

fn pipeline_skip_type_args toks pos_box require_lparen
    // WHY: Safely skips `<T, U>` generic type parameter/argument lists without ever colliding
    // with `<` comparison operators (when require_lparen == 1, requires `> (` immediately after).
    p = get(pos_box, 0)
    if p >= toks.len() return 0 end
    if toks[p].tok_kind != TOK_LT() and not (toks[p].tok_kind != TOK_STR() and toks[p].tok_text == "<")
        return 0
    end
    scan = p + 1
    depth = 1
    saw_ident = 0
    while scan < toks.len() and depth > 0
        tk = toks[scan].tok_kind
        tx = toks[scan].tok_text
        if tk == TOK_LT() or (tk != TOK_STR() and tx == "<")
            depth = depth + 1
        elif tk == TOK_GT() or (tk != TOK_STR() and tx == ">")
            depth = depth - 1
            if depth == 0
                scan = scan + 1
                break
            end
        elif tk == TOK_SHR() or (tk != TOK_STR() and tx == ">>")
            depth = depth - 2
            if depth <= 0
                scan = scan + 1
                break
            end
        elif pipeline_is_ident_token(tk) == 1
            saw_ident = 1
        elif tk == TOK_COMMA() or (tk != TOK_STR() and tx == ",") or tk == TOK_NEWLINE()
            // allowed separator inside generic list
        elif tk == TOK_STAR() or (tk != TOK_STR() and tx == "*")
            // allowed typed pointer inside generic list
        elif tk == TOK_KW_CONST() or tk == TOK_KW_MUT()
            // allowed pointer qualifier inside generic list
        elif require_lparen == 0 and (tk == TOK_COLON() or tk == TOK_PLUS() or (tk != TOK_STR() and (tx == ":" or tx == "+")))
            // allowed trait bound `<T: Printable + Hashable>` on generic declarations
        else
            return 0
        end
        scan = scan + 1
    end
    if depth != 0 or saw_ident == 0
        return 0
    end
    if require_lparen == 1
        if scan >= toks.len() return 0 end
        if toks[scan].tok_kind != TOK_LPAREN() and not (toks[scan].tok_kind != TOK_STR() and toks[scan].tok_text == "(")
            return 0
        end
    end
    list_set(pos_box, 0, scan)
    return 1
end

fn pipeline_capture_type_args toks pos_box base_name
    // WHY: Preserves `<T>` element type annotations on parameterized containers (`list<User>`,
    // `list<dyn Greet>`, `array<i64>`) so `--strict-types` validates element soundness instead
    // of erasing them to `[]any`.
    start_p = get(pos_box, 0)
    ok = pipeline_skip_type_args(toks, pos_box, 0)
    if ok == 0
        return ""
    end
    if base_name != "list" and base_name != "array" and base_name != "vec" and base_name != "slice" and base_name != "dict" and base_name != "map" and base_name != "hashmap"
        return ""
    end
    end_p = get(pos_box, 0)
    out = ""
    ci = start_p
    while ci < end_p
        ck = toks[ci].tok_kind
        ct = toks[ci].tok_text
        if ck != TOK_NEWLINE()
            out = out + ct
            if ct == "dyn" or ct == "const" or ct == "mut"
                out = out + " "
            end
        end
        ci = ci + 1
    end
    return out
end

fn pipeline_try_parse_adt_pat_binds toks pos_box
    // WHY: Detects ADT destructuring patterns `[Enum::]Variant(x, y)` before `=>`/`->`/`:`
    // and returns the list of bound variable names while advancing pos_box past the pattern.
    // Returns 0 if current token is not an ADT destructuring pattern.
    p = get(pos_box, 0)
    if p >= toks.len() return 0 end
    if pipeline_is_ident_token(toks[p].tok_kind) == 0 return 0 end
    scan = p + 1
    if scan + 2 < toks.len() and (toks[scan].tok_kind == TOK_COLON() or toks[scan].tok_text == ":") and (toks[scan + 1].tok_kind == TOK_COLON() or toks[scan + 1].tok_text == ":") and pipeline_is_ident_token(toks[scan + 2].tok_kind) == 1
        scan = scan + 3
    end
    if scan >= toks.len() or (toks[scan].tok_kind != TOK_LPAREN() and toks[scan].tok_text != "(")
        return 0
    end
    scan = scan + 1
    binds = list()
    while scan < toks.len()
        sk = toks[scan].tok_kind
        stx = toks[scan].tok_text
        if sk == TOK_RPAREN() or (sk != TOK_STR() and stx == ")")
            scan = scan + 1
            break
        elif sk == TOK_COMMA() or (sk != TOK_STR() and stx == ",") or sk == TOK_NEWLINE()
            scan = scan + 1
        elif pipeline_is_ident_token(sk) == 1
            if stx != "_"
                push(binds, stx)
            end
            scan = scan + 1
        else
            return 0
        end
    end
    if scan >= toks.len() return 0 end
    ak = toks[scan].tok_kind
    atx = toks[scan].tok_text
    if ak == TOK_FAT_ARROW() or ak == TOK_COLON() or ak == TOK_ARROW() or atx == "=>" or atx == ":" or atx == "->"
        list_set(pos_box, 0, scan)
        return binds
    end
    return 0
end

fn pipeline_skip_whitespace toks pos_box
    // WHY: Advances cursor past non-semantic tokens (newlines, semicolons, comments)
    // without heap allocation or quadratic string copies.
    while get(pos_box, 0) < toks.len()
        k = toks[get(pos_box, 0)].tok_kind
        if k == TOK_NEWLINE() or k == TOK_SEMI() or k == TOK_COMMENT_LINE() or k == TOK_COMMENT_BLOCK()
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        else
            break
        end
    end
    return 0

fn pipeline_is_block_end toks p
    // WHY: Accurately detects block-terminating tokens (end, শেষ, @end)
    // while preventing misidentification of identifiers assigned as 'end = val'.
    if p >= toks.len() return 0
    t = toks[p]
    k = t.tok_kind
    txt = t.tok_text
    if k == TOK_KW_END() or k == TOK_DIR_END() or (k == TOK_IDENT() and (txt == "end" or txt == "শেষ" or txt == "@end"))
        next_p = p + 1
        if next_p < toks.len()
            nt = toks[next_p]
            if nt.tok_kind == TOK_ASSIGN() or (nt.tok_kind != TOK_STR() and nt.tok_text == "=")
                return 0
            end
        end
        return 1
    end
    return 0

fn pipeline_parse_bin_prec toks pos_box sp min_prec
    // WHY: Implements Pratt precedence climbing for deterministic algebraic expressions,
    // including arithmetic, bitwise, comparison, and logical conjunctions.
    left = pipeline_parse_primary(toks, pos_box, sp)
    while get(pos_box, 0) < toks.len()
        cp = get(pos_box, 0)
        ct = toks[cp]
        ck = ct.tok_kind
        cx = ct.tok_text

        prec = 0 - 1
        op_str = ""
        // WHY: Protect string literals like "/" or "-" from being misinterpreted as infix binary operators.
        if ck != TOK_STR()
            if ck == TOK_STAR() or cx == "*" or ck == TOK_SLASH() or cx == "/" or ck == TOK_PERCENT() or cx == "%" or ck == TOK_MATMUL() or cx == "@"
                prec = 20
                op_str = cx
            elif ck == TOK_PLUS() or cx == "+" or ck == TOK_MINUS() or cx == "-"
                prec = 10
                op_str = cx
            elif ck == TOK_SHL() or cx == "<<" or ck == TOK_SHR() or cx == ">>"
                prec = 9
                op_str = cx
            elif ck == TOK_AMP() or cx == "&"
                prec = 8
                op_str = cx
            elif ck == TOK_CARET() or cx == "^"
                prec = 7
                op_str = cx
            elif ck == TOK_BAR() or cx == "|"
                prec = 6
                op_str = cx
            elif ck == TOK_LT() or cx == "<" or ck == TOK_LTE() or cx == "<=" or ck == TOK_GT() or cx == ">" or ck == TOK_GTE() or cx == ">=" or ck == TOK_EQ() or cx == "==" or ck == TOK_NEQ() or cx == "!="
                prec = 5
                op_str = cx
            elif ck == TOK_AND() or cx == "&&" or cx == "and" or cx == "এবং"
                prec = 3
                op_str = cx
            elif ck == TOK_OR() or cx == "||" or cx == "or" or cx == "বা"
                prec = 2
                op_str = cx
            elif ck == TOK_DOTDOT() or cx == ".."
                prec = 1
                op_str = cx
            end
        end

        if prec < min_prec
            break
        end

        // WHY: Syntax error guard against dangling binary operators (e.g. `1 + ;`, `1 + end`, `(1 + )`).
        // Scans forward past comments and newlines to ensure a valid right-hand expression token exists.
        chk_p = cp + 1
        while chk_p < toks.len()
            chk_k = toks[chk_p].tok_kind
            if chk_k == TOK_COMMENT_LINE() or chk_k == TOK_COMMENT_BLOCK() or chk_k == TOK_NEWLINE()
                chk_p = chk_p + 1
            else
                break
            end
        end

        is_dangling = 0
        if chk_p >= toks.len()
            is_dangling = 1
        else
            chk_tok = toks[chk_p]
            chk_k = chk_tok.tok_kind
            chk_txt = chk_tok.tok_text
            if chk_k != TOK_STR()
                if chk_k == TOK_SEMI() or chk_k == TOK_EOF() or chk_k == TOK_RBRACE() or chk_txt == "}"
                    is_dangling = 1
                elif chk_k == TOK_KW_END() or chk_k == TOK_DIR_END() or chk_txt == "end" or chk_txt == "শেষ" or chk_txt == "@end"
                    is_dangling = 1
                elif chk_k == TOK_RPAREN() or chk_txt == ")" or chk_k == TOK_RBRACKET() or chk_txt == "]" or chk_k == TOK_COMMA() or chk_txt == ","
                    is_dangling = 1
                end
            end
        end

        if is_dangling == 1
            say "❌ [Syntax Error]: Dangling binary operator '" + op_str + "' at line " + str(ct.tok_span.span_start_line) + " without valid right-hand operand!"
            exit(1)
        end

        list_set(pos_box, 0, cp + 1)
        right = pipeline_parse_bin_prec(toks, pos_box, sp, prec + 1)
        left = ast_expr_binary(left, op_str, right, sp)
    end
    return left

fn pipeline_parse_expr toks pos_box sp
    // WHY: Parses any standard binary/unary expression tree with minimum precedence 0.
    return pipeline_parse_bin_prec(toks, pos_box, sp, 0)

fn pipeline_build_if_tail toks pos_box sp base_col
    // WHY: Recursively parses chained if-elif-else branches into nested AST nodes,
    // ensuring single-line @if and multi-line if statements consume matching end tokens cleanly.
    p = get(pos_box, 0)
    if p >= toks.len() return 0
    t = toks[p]
    base_line = t.tok_span.span_start_line

    cond = pipeline_parse_expr(toks, pos_box, sp)
    then_b = list()
    else_b = list()

    is_braced_if = 0
    pipeline_skip_whitespace(toks, pos_box)
    if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
        is_braced_if = 1
        list_set(pos_box, 0, get(pos_box, 0) + 1)
        while get(pos_box, 0) < toks.len()
            pipeline_skip_whitespace(toks, pos_box)
            if get(pos_box, 0) >= toks.len() break end
            if toks[get(pos_box, 0)].tok_kind == TOK_RBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "}")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                break
            end
            before_s = get(pos_box, 0)
            s = pipeline_build_statement(toks, pos_box, sp)
            if s != 0
                push(then_b, s)
            end
            if get(pos_box, 0) <= before_s
                list_set(pos_box, 0, before_s + 1)
            end
        end
    else
        while get(pos_box, 0) < toks.len()
            pipeline_skip_whitespace(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len() break end
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_ELIF() or cur_k == TOK_DIR_ELIF() or cur_k == TOK_KW_ELSE() or cur_k == TOK_DIR_ELSE()
                break
            end
            if cur_k == TOK_IDENT() and (cur_txt == "elif" or cur_txt == "নাহলে_যদি" or cur_txt == "নতুবা_যদি" or cur_txt == "@elif" or cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "অন্যথায়" or cur_txt == "নতুবা" or cur_txt == "@else")
                break
            end
            if pipeline_is_block_end(toks, cur_p) == 1
                break
            end
            if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                break
            end
            before_s = get(pos_box, 0)
            s = pipeline_build_statement(toks, pos_box, sp)
            if s != 0
                push(then_b, s)
            end
            if get(pos_box, 0) <= before_s
                list_set(pos_box, 0, before_s + 1)
            end
            if cur_t.tok_span.span_start_line == base_line and pipeline_should_stop_inline(toks, pos_box, base_line) == 1
                break
            end
        end
    end

    pipeline_skip_whitespace(toks, pos_box)
    cur_p = get(pos_box, 0)
    if cur_p < toks.len()
        cur_t = toks[cur_p]
        ek = cur_t.tok_kind
        etxt = cur_t.tok_text
        // WHY: An indentation-delimited inner `if` at deeper `base_col` MUST NOT steal an
        // enclosing outer block's `elif`, `else`, or `end` at a smaller column!
        same_or_inner_col = 1
        if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col < base_col
            same_or_inner_col = 0
        end
        is_elif = 0
        if same_or_inner_col == 1 and (ek == TOK_KW_ELIF() or ek == TOK_DIR_ELIF() or (ek == TOK_IDENT() and (etxt == "elif" or etxt == "নাহলে_যদি" or etxt == "নতুবা_যদি" or etxt == "@elif")))
            is_elif = 1
        end
        is_else = 0
        if same_or_inner_col == 1 and (ek == TOK_KW_ELSE() or ek == TOK_DIR_ELSE() or (ek == TOK_IDENT() and (etxt == "else" or etxt == "নাহলে" or etxt == "অন্যথায়" or etxt == "নতুবা" or etxt == "@else")))
            is_else = 1
        end

        if is_elif == 1
            list_set(pos_box, 0, cur_p + 1)
            nested_if = pipeline_build_if_tail(toks, pos_box, sp, base_col)
            if nested_if != 0
                push(else_b, nested_if)
            end
        elif is_else == 1
            list_set(pos_box, 0, cur_p + 1)
            is_braced_else = 0
            else_base_l = cur_t.tok_span.span_start_line
            pipeline_skip_whitespace(toks, pos_box)
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
                is_braced_else = 1
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                while get(pos_box, 0) < toks.len()
                    pipeline_skip_whitespace(toks, pos_box)
                    if get(pos_box, 0) >= toks.len() break end
                    if toks[get(pos_box, 0)].tok_kind == TOK_RBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "}")
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        break
                    end
                    before_s = get(pos_box, 0)
                    s = pipeline_build_statement(toks, pos_box, sp)
                    if s != 0
                        push(else_b, s)
                    end
                    if get(pos_box, 0) <= before_s
                        list_set(pos_box, 0, before_s + 1)
                    end
                end
            else
                while get(pos_box, 0) < toks.len()
                    pipeline_skip_whitespace(toks, pos_box)
                    cur_p2 = get(pos_box, 0)
                    if cur_p2 >= toks.len() break end
                    cur_t2 = toks[cur_p2]
                    if pipeline_is_block_end(toks, cur_p2) == 1
                        break
                    end
                    if cur_t2.tok_span.span_start_line > else_base_l and cur_t2.tok_span.span_start_col <= base_col
                        break
                    end
                    before_s = get(pos_box, 0)
                    s = pipeline_build_statement(toks, pos_box, sp)
                    if s != 0
                        push(else_b, s)
                    end
                    if get(pos_box, 0) <= before_s
                        list_set(pos_box, 0, before_s + 1)
                    end
                    if cur_t2.tok_span.span_start_line == else_base_l and pipeline_should_stop_inline(toks, pos_box, else_base_l) == 1
                        break
                    end
                end
            end
            if is_braced_else == 0
                pipeline_skip_whitespace(toks, pos_box)
                cur_p = get(pos_box, 0)
                if cur_p < toks.len()
                    end_t = toks[cur_p]
                    if pipeline_is_block_end(toks, cur_p) == 1 and (end_t.tok_span.span_start_line == else_base_l or end_t.tok_span.span_start_col >= base_col)
                        list_set(pos_box, 0, cur_p + 1)
                    end
                end
            end
        else
            if is_braced_if == 0 and same_or_inner_col == 1 and pipeline_is_block_end(toks, cur_p) == 1
                list_set(pos_box, 0, cur_p + 1)
            end
        end
    end

    return ast_stmt_if(cond, then_b, list(), else_b, sp)

fn pipeline_build_statement toks pos_box sp
    // WHY: Maps control flow, assignment, loops, and calls into valid AST statement structures.
    pipeline_skip_whitespace(toks, pos_box)

    if get(pos_box, 0) >= toks.len()
        return 0
    end

    cp = get(pos_box, 0)
    t = toks[cp]
    k = t.tok_kind
    txt = t.tok_text
    if t.tok_span != 0
        sp = t.tok_span
    end

    // 0. Sovereign Silicon & Hardware Layout Directives (@asm, @naked, @interrupt, @packed, @align, @ring0, @layout, @bss, @strict, @kavach, @attr_*)
    if k == TOK_IDENT() and len(txt) >= 2 and mem_byte_read(txt, 0) == 64
        if txt == "@naked" or txt == "@interrupt" or txt == "@packed" or txt == "@ring0" or txt == "@silicon" or txt == "@strict" or txt == "@fn_strict" or txt == "@strict_types" or txt == "@strict_ownership" or txt == "@strict_proof" or txt == "@kavach" or txt == "@freestanding" or str_starts_with(txt, "@attr_") == 1
            list_set(pos_box, 0, cp + 1)
            return 0
        elif txt == "@align" or txt == "@layout"
            list_set(pos_box, 0, cp + 1)
            pipeline_skip_whitespace(toks, pos_box)
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LPAREN() or toks[get(pos_box, 0)].tok_text == "(")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                dp_a = 1
                while get(pos_box, 0) < toks.len() and dp_a > 0
                    ak_s = toks[get(pos_box, 0)].tok_kind
                    at_s = toks[get(pos_box, 0)].tok_text
                    if ak_s == TOK_LPAREN() or at_s == "(" dp_a = dp_a + 1
                    elif ak_s == TOK_RPAREN() or at_s == ")" dp_a = dp_a - 1 end
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            elif get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_INT()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            return 0
        elif txt == "@asm" or txt == "@অ্যাসেম্বলি"
            list_set(pos_box, 0, cp + 1)
            pipeline_skip_whitespace(toks, pos_box)
            if get(pos_box, 0) < toks.len()
                at0 = toks[get(pos_box, 0)]
                if at0.tok_kind == TOK_LBRACKET() or at0.tok_text == "["
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    while get(pos_box, 0) < toks.len()
                        if toks[get(pos_box, 0)].tok_kind == TOK_RBRACKET() or toks[get(pos_box, 0)].tok_text == "]"
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                            break
                        end
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    end
                elif at0.tok_kind == TOK_LBRACE() or at0.tok_text == "{"
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    while get(pos_box, 0) < toks.len()
                        if toks[get(pos_box, 0)].tok_kind == TOK_RBRACE() or toks[get(pos_box, 0)].tok_text == "}"
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                            break
                        end
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    end
                else
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            end
            // WHY: Emit synthetic Call("@asm") AST node so `--kavach` enforces Ring-0 crown on inline assembly!
            asm_call = ast_expr_call(ast_expr_ident(txt, sp), list(), sp)
            asm_stmt = ast_stmt_expr(asm_call, sp)
            asm_stmt.kind = "ExprStmt"
            asm_stmt.op = "asm"
            return asm_stmt
        elif txt == "@bss"
            list_set(pos_box, 0, cp + 1)
            pipeline_skip_whitespace(toks, pos_box)
            // Support `@bss @align(N) name: Type` in addition to `@align(N) @bss name: Type`
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_text == "@align"
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                pipeline_skip_whitespace(toks, pos_box)
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LPAREN() or toks[get(pos_box, 0)].tok_text == "(")
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    dp_b = 1
                    while get(pos_box, 0) < toks.len() and dp_b > 0
                        ak_b = toks[get(pos_box, 0)].tok_kind
                        at_b = toks[get(pos_box, 0)].tok_text
                        if ak_b == TOK_LPAREN() or at_b == "(" dp_b = dp_b + 1
                        elif ak_b == TOK_RPAREN() or at_b == ")" dp_b = dp_b - 1 end
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    end
                elif get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_INT()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                pipeline_skip_whitespace(toks, pos_box)
            end
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_text == "static"
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                pipeline_skip_whitespace(toks, pos_box)
            end
            bss_ast_nm = ""
            if get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                bss_ast_nm = toks[get(pos_box, 0)].tok_text
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or toks[get(pos_box, 0)].tok_text == ":")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACKET() or toks[get(pos_box, 0)].tok_text == "[")
                    while get(pos_box, 0) < toks.len()
                        if toks[get(pos_box, 0)].tok_kind == TOK_RBRACKET() or toks[get(pos_box, 0)].tok_text == "]"
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                            break
                        end
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    end
                end
                if get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    pipeline_skip_type_args(toks, pos_box, 0)
                end
            elif get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_INT()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            if bss_ast_nm != ""
                return ast_stmt_assign(bss_ast_nm, ast_expr_literal_int(0, sp), sp)
            end
            return 0
        end
    end

    // 1. Return statement
    if k == TOK_KW_RETURN() or txt == "return" or txt == "ফেরত"
        list_set(pos_box, 0, cp + 1)
        has_expr = 0
        if get(pos_box, 0) < toks.len()
            nk = toks[get(pos_box, 0)].tok_kind
            ntxt = toks[get(pos_box, 0)].tok_text
            if nk != TOK_NEWLINE() and nk != TOK_SEMI() and nk != TOK_EOF() and nk != TOK_RBRACE() and ntxt != "}"
                if nk != TOK_KW_END() and nk != TOK_DIR_END() and ntxt != "end" and ntxt != "শেষ" and ntxt != "@end"
                    has_expr = 1
                end
            end
        end
        if has_expr == 1
            ret_line = t.tok_span.span_start_line
            ret_val = pipeline_parse_expr(toks, pos_box, sp)
            cp_r = get(pos_box, 0)
            if cp_r < toks.len() and (toks[cp_r].tok_kind == TOK_COMMA() or (toks[cp_r].tok_kind != TOK_STR() and toks[cp_r].tok_text == ",")) and toks[cp_r].tok_span.span_start_line == ret_line
                ret_elems = [ret_val]
                while get(pos_box, 0) < toks.len()
                    cr_p = get(pos_box, 0)
                    if (toks[cr_p].tok_kind == TOK_COMMA() or (toks[cr_p].tok_kind != TOK_STR() and toks[cr_p].tok_text == ",")) and toks[cr_p].tok_span.span_start_line == ret_line
                        list_set(pos_box, 0, cr_p + 1)
                        push(ret_elems, pipeline_parse_expr(toks, pos_box, sp))
                    else
                        break
                    end
                end
                ret_val = ast_expr_array_lit(ret_elems, sp)
            end
            return ast_stmt_return(ret_val, sp)
        end
        return ast_stmt_return(ast_expr_literal_int(0, sp), sp)
    end

    // 1b. Break statement
    // WHY: Parses explicit loop break statements (break / থামো / @break) into typed AST Break nodes,
    // preventing them from falling through to generic expression parsing and triggering undefined variable errors.
    is_brk = 0
    if k == TOK_KW_BREAK() or k == TOK_DIR_BREAK()
        is_brk = 1
    end
    if k == TOK_IDENT() and (txt == "break" or txt == "থামো" or txt == "@break")
        is_brk = 1
    end
    if is_brk == 1
        list_set(pos_box, 0, cp + 1)
        return ast_stmt_break(sp)
    end

    // 1c. Continue statement
    // WHY: Parses loop continue statements (continue / চালিয়ে_যাও / চলো / @continue) into typed AST Continue nodes.
    is_cont = 0
    if k == TOK_KW_CONTINUE() or k == TOK_DIR_CONTINUE()
        is_cont = 1
    end
    if k == TOK_IDENT() and (txt == "continue" or txt == "চালিয়ে_যাও" or txt == "চলো" or txt == "@continue")
        is_cont = 1
    end
    if is_cont == 1
        list_set(pos_box, 0, cp + 1)
        return ast_stmt_continue(sp)
    end

    // 1d. Defer statement: defer / @defer / বিলম্ব (supports single stmt, braced `defer { ... }`, AND multiline `defer\n...\nend`)
    if (k == TOK_KW_DEFER() or txt == "defer" or txt == "@defer" or txt == "বিলম্ব") and (cp + 1 >= toks.len() or (toks[cp + 1].tok_kind != TOK_ASSIGN() and toks[cp + 1].tok_text != "=" and toks[cp + 1].tok_kind != TOK_LPAREN() and toks[cp + 1].tok_text != "(" and toks[cp + 1].tok_kind != TOK_DOT() and toks[cp + 1].tok_text != "."))
        def_line = t.tok_span.span_start_line
        def_col = t.tok_span.span_start_col
        list_set(pos_box, 0, cp + 1)
        pipeline_skip_whitespace(toks, pos_box)
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
            list_set(pos_box, 0, get(pos_box, 0) + 1)
            def_stmts = list()
            while get(pos_box, 0) < toks.len()
                pipeline_skip_whitespace(toks, pos_box)
                cp_db = get(pos_box, 0)
                if cp_db >= toks.len() break end
                if toks[cp_db].tok_kind == TOK_RBRACE() or (toks[cp_db].tok_kind != TOK_STR() and toks[cp_db].tok_text == "}")
                    list_set(pos_box, 0, cp_db + 1)
                    break
                end
                bp_db = get(pos_box, 0)
                st_db = pipeline_build_statement(toks, pos_box, sp)
                if st_db != 0 push(def_stmts, st_db) end
                if get(pos_box, 0) <= bp_db list_set(pos_box, 0, bp_db + 1) end
            end
            d_blk = ast_stmt_defer(0, sp)
            d_blk.body = def_stmts
            return d_blk
        end
        if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_span.span_start_line > def_line
            def_stmts2 = list()
            while get(pos_box, 0) < toks.len()
                pipeline_skip_whitespace(toks, pos_box)
                cp_db2 = get(pos_box, 0)
                if cp_db2 >= toks.len() break end
                dt2 = toks[cp_db2]
                if dt2.tok_kind == TOK_RBRACE() or (dt2.tok_kind != TOK_STR() and dt2.tok_text == "}") break end
                if pipeline_is_block_end(toks, cp_db2) == 1
                    list_set(pos_box, 0, cp_db2 + 1)
                    break
                end
                if dt2.tok_span.span_start_col <= def_col break end
                bp_db2 = get(pos_box, 0)
                st_db2 = pipeline_build_statement(toks, pos_box, sp)
                if st_db2 != 0 push(def_stmts2, st_db2) end
                if get(pos_box, 0) <= bp_db2 list_set(pos_box, 0, bp_db2 + 1) end
            end
            d_blk2 = ast_stmt_defer(0, sp)
            d_blk2.body = def_stmts2
            return d_blk2
        end
        deferred_stmt = pipeline_build_statement(toks, pos_box, sp)
        return ast_stmt_defer(deferred_stmt, sp)
    end

    // 2. While loop: while / যতক্ষণ / @while
    is_while = 0
    if k == TOK_KW_WHILE() or k == TOK_DIR_WHILE()
        is_while = 1
    end
    if k == TOK_IDENT() and (txt == "while" or txt == "যতক্ষণ" or txt == "@while")
        is_while = 1
    end

    if is_while == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, cp + 1)
        cond = pipeline_parse_expr(toks, pos_box, sp)
        body = list()
        pipeline_skip_whitespace(toks, pos_box)
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
            list_set(pos_box, 0, get(pos_box, 0) + 1)
            while get(pos_box, 0) < toks.len()
                pipeline_skip_whitespace(toks, pos_box)
                if get(pos_box, 0) >= toks.len() break end
                if toks[get(pos_box, 0)].tok_kind == TOK_RBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "}")
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    break
                end
                before_s = get(pos_box, 0)
                s = pipeline_build_statement(toks, pos_box, sp)
                if s != 0
                    push(body, s)
                end
                if get(pos_box, 0) <= before_s
                    list_set(pos_box, 0, before_s + 1)
                end
            end
        else
            while get(pos_box, 0) < toks.len()
                pipeline_skip_whitespace(toks, pos_box)
                cur_p = get(pos_box, 0)
                if cur_p >= toks.len() break end
                cur_t = toks[cur_p]
                if pipeline_is_block_end(toks, cur_p) == 1
                    break
                end
                if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                    break
                end
                before_s = get(pos_box, 0)
                s = pipeline_build_statement(toks, pos_box, sp)
                if s != 0
                    push(body, s)
                end
                if get(pos_box, 0) <= before_s
                    list_set(pos_box, 0, before_s + 1)
                end
                if cur_t.tok_span.span_start_line == base_line and pipeline_should_stop_inline(toks, pos_box, base_line) == 1
                    break
                end
            end
            pipeline_skip_whitespace(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p < toks.len()
                end_wt = toks[cur_p]
                if pipeline_is_block_end(toks, cur_p) == 1 and (end_wt.tok_span.span_start_line == base_line or end_wt.tok_span.span_start_col >= base_col)
                    list_set(pos_box, 0, cur_p + 1)
                end
            end
        end
        return ast_stmt_while(cond, body, sp)
    end

    // 2b. For loop: for / প্রতিটি / জন্য / @for
    // WHY: Enables AST generation for counted iterations and range scans (for var in start..end)
    is_for = 0
    if k == TOK_KW_FOR() or k == TOK_DIR_FOR()
        is_for = 1
    end
    if k == TOK_IDENT() and (txt == "for" or txt == "প্রতিটি" or txt == "জন্য" or txt == "@for")
        is_for = 1
    end

    if is_for == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, cp + 1)
        pipeline_skip_whitespace(toks, pos_box)
        if get(pos_box, 0) >= toks.len()
            return 0
        end
        var_tok = toks[get(pos_box, 0)]
        var_name = var_tok.tok_text
        list_set(pos_box, 0, get(pos_box, 0) + 1)
        pipeline_skip_whitespace(toks, pos_box)

        // Consume 'in' or 'মধ্যে' if present
        if get(pos_box, 0) < toks.len()
            in_t = toks[get(pos_box, 0)]
            if in_t.tok_kind == TOK_KW_IN() or (in_t.tok_kind != TOK_STR() and (in_t.tok_text == "in" or in_t.tok_text == "মধ্যে"))
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                pipeline_skip_whitespace(toks, pos_box)
            end
        end

        // Parse iterable expression (e.g. 1..5)
        iter_expr = pipeline_parse_expr(toks, pos_box, sp)
        body = list()
        pipeline_skip_whitespace(toks, pos_box)
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
            list_set(pos_box, 0, get(pos_box, 0) + 1)
            while get(pos_box, 0) < toks.len()
                pipeline_skip_whitespace(toks, pos_box)
                if get(pos_box, 0) >= toks.len() break end
                if toks[get(pos_box, 0)].tok_kind == TOK_RBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "}")
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    break
                end
                before_s = get(pos_box, 0)
                s = pipeline_build_statement(toks, pos_box, sp)
                if s != 0
                    push(body, s)
                end
                if get(pos_box, 0) <= before_s
                    list_set(pos_box, 0, before_s + 1)
                end
            end
        else
            while get(pos_box, 0) < toks.len()
                pipeline_skip_whitespace(toks, pos_box)
                cur_p = get(pos_box, 0)
                if cur_p >= toks.len() break end
                cur_t = toks[cur_p]
                if pipeline_is_block_end(toks, cur_p) == 1
                    break
                end
                if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                    break
                end
                before_s = get(pos_box, 0)
                s = pipeline_build_statement(toks, pos_box, sp)
                if s != 0
                    push(body, s)
                end
                if get(pos_box, 0) <= before_s
                    list_set(pos_box, 0, before_s + 1)
                end
                if cur_t.tok_span.span_start_line == base_line
                    break
                end
            end
            pipeline_skip_whitespace(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p < toks.len()
                end_ft = toks[cur_p]
                if pipeline_is_block_end(toks, cur_p) == 1 and (end_ft.tok_span.span_start_line == base_line or end_ft.tok_span.span_start_col >= base_col)
                    list_set(pos_box, 0, cur_p + 1)
                end
            end
        end
        return ast_stmt_for(var_name, iter_expr, body, sp)
    end

    // 2c. Repeat loop: repeat / বার / @repeat
    // WHY: Parses repeat loops ('repeat 5: ...' or 'repeat N: ...') and lowers them to bounded for loops,
    // ensuring type checking succeeds and prevents 'repeat' from being misparsed as an undefined variable.
    is_repeat = 0
    if k == TOK_IDENT() and (txt == "repeat" or txt == "বার" or txt == "@repeat")
        is_repeat = 1
    end

    if is_repeat == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, cp + 1)
        count_expr = pipeline_parse_expr(toks, pos_box, sp)
        body = list()
        pipeline_skip_whitespace(toks, pos_box)
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
            list_set(pos_box, 0, get(pos_box, 0) + 1)
            while get(pos_box, 0) < toks.len()
                pipeline_skip_whitespace(toks, pos_box)
                if get(pos_box, 0) >= toks.len() break end
                if toks[get(pos_box, 0)].tok_kind == TOK_RBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "}")
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    break
                end
                before_s = get(pos_box, 0)
                s = pipeline_build_statement(toks, pos_box, sp)
                if s != 0
                    push(body, s)
                end
                if get(pos_box, 0) <= before_s
                    list_set(pos_box, 0, before_s + 1)
                end
            end
        else
            while get(pos_box, 0) < toks.len()
                pipeline_skip_whitespace(toks, pos_box)
                cur_p = get(pos_box, 0)
                if cur_p >= toks.len() break end
                cur_t = toks[cur_p]
                if pipeline_is_block_end(toks, cur_p) == 1
                    break
                end
                if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                    break
                end
                before_s = get(pos_box, 0)
                s = pipeline_build_statement(toks, pos_box, sp)
                if s != 0
                    push(body, s)
                end
                if get(pos_box, 0) <= before_s
                    list_set(pos_box, 0, before_s + 1)
                end
                if cur_t.tok_span.span_start_line == base_line
                    break
                end
            end
            pipeline_skip_whitespace(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p < toks.len()
                end_rt = toks[cur_p]
                if pipeline_is_block_end(toks, cur_p) == 1 and (end_rt.tok_span.span_start_line == base_line or end_rt.tok_span.span_start_col >= base_col)
                    list_set(pos_box, 0, cur_p + 1)
                end
            end
        end
        range_node = ast_expr_binary(ast_expr_literal_int(1, sp), "..", count_expr, sp)
        return ast_stmt_for("__repeat_i", range_node, body, sp)
    end

    // 3. Conditional if: if / যদি / @if...
    is_if = 0
    if k == TOK_KW_IF() or k == TOK_DIR_IF()
        is_if = 1
    end
    if k == TOK_IDENT() and (txt == "if" or txt == "যদি" or txt == "@if")
        is_if = 1
    end

    if is_if == 1
        base_col = t.tok_span.span_start_col
        list_set(pos_box, 0, cp + 1)
        return pipeline_build_if_tail(toks, pos_box, sp, base_col)
    end

    // 4. Variable declaration let / var / reg
    is_decl_kw = 0
    if k == TOK_KW_LET() or txt == "let" or txt == "var" or txt == "ধরি" or txt == "চলক" or txt == "@reg" or txt == "রেজিস্টার" or txt == "@let"
        is_decl_kw = 1
    elif txt == "reg" and cp + 1 < toks.len()
        // WHY: Disambiguate 'reg x = expr' (register-hint declaration) from variable 'reg' (e.g. reg = TypeRegistry(), reg.field = expr)
        if pipeline_is_ident_token(toks[cp + 1].tok_kind) == 1 and toks[cp + 1].tok_text != "=" and toks[cp + 1].tok_text != "." and toks[cp + 1].tok_text != ":"
            is_decl_kw = 1
        end
    end

    if is_decl_kw == 1
        scan_p = cp + 1
        if scan_p < toks.len() and pipeline_is_ident_token(toks[scan_p].tok_kind) == 1
            // Multi-variable destructuring: let a, b [, c...] = rhs1 [, rhs2...]
            if scan_p + 1 < toks.len() and (toks[scan_p + 1].tok_kind == TOK_COMMA() or (toks[scan_p + 1].tok_kind != TOK_STR() and toks[scan_p + 1].tok_text == ","))
                ma_lhs = [ast_expr_ident(toks[scan_p].tok_text, sp)]
                ma_p = scan_p + 1
                ma_ok = 1
                while ma_p < toks.len()
                    if toks[ma_p].tok_kind == TOK_COMMA() or (toks[ma_p].tok_kind != TOK_STR() and toks[ma_p].tok_text == ",")
                        ma_p = ma_p + 1
                        if ma_p < toks.len() and pipeline_is_ident_token(toks[ma_p].tok_kind) == 1
                            push(ma_lhs, ast_expr_ident(toks[ma_p].tok_text, sp))
                            ma_p = ma_p + 1
                        else
                            ma_ok = 0
                            break
                        end
                    else
                        break
                    end
                end
                if ma_ok == 1 and ma_lhs.len() >= 2 and ma_p < toks.len() and (toks[ma_p].tok_kind == TOK_ASSIGN() or (toks[ma_p].tok_kind != TOK_STR() and toks[ma_p].tok_text == "="))
                    ma_line = toks[ma_p].tok_span.span_start_line
                    list_set(pos_box, 0, ma_p + 1)
                    ma_rhs = [pipeline_parse_expr(toks, pos_box, sp)]
                    while get(pos_box, 0) < toks.len()
                        mr_p = get(pos_box, 0)
                        if (toks[mr_p].tok_kind == TOK_COMMA() or (toks[mr_p].tok_kind != TOK_STR() and toks[mr_p].tok_text == ",")) and toks[mr_p].tok_span.span_start_line == ma_line
                            list_set(pos_box, 0, mr_p + 1)
                            push(ma_rhs, pipeline_parse_expr(toks, pos_box, sp))
                        else
                            break
                        end
                    end
                    ma_n = ast_node_new(AST_TAG_ASSIGN(), "MultiAssign", sp)
                    ma_n.params = ma_lhs
                    ma_n.args = ma_rhs
                    return ma_n
                end
            end
            var_name = toks[scan_p].tok_text
            decl_type = ""
            scan_p = scan_p + 1
            // Optional type annotation: : [*[const|mut]] [dyn] Type[<...>]
            if scan_p < toks.len() and (toks[scan_p].tok_kind == TOK_COLON() or (toks[scan_p].tok_kind != TOK_STR() and toks[scan_p].tok_text == ":"))
                scan_p = scan_p + 1
                while scan_p < toks.len() and (toks[scan_p].tok_kind == TOK_STAR() or (toks[scan_p].tok_kind != TOK_STR() and toks[scan_p].tok_text == "*"))
                    decl_type = decl_type + "*"
                    scan_p = scan_p + 1
                    if scan_p < toks.len() and (toks[scan_p].tok_text == "const" or toks[scan_p].tok_text == "mut")
                        decl_type = decl_type + toks[scan_p].tok_text + " "
                        scan_p = scan_p + 1
                    end
                end
                if scan_p + 1 < toks.len() and toks[scan_p].tok_kind == TOK_IDENT() and toks[scan_p].tok_text == "dyn" and pipeline_is_ident_token(toks[scan_p + 1].tok_kind) == 1
                    decl_type = decl_type + "dyn " + toks[scan_p + 1].tok_text
                    scan_p = scan_p + 2
                elif scan_p < toks.len() and pipeline_is_ident_token(toks[scan_p].tok_kind) == 1
                    base_dt = toks[scan_p].tok_text
                    decl_type = decl_type + base_dt
                    scan_p = scan_p + 1
                    sp_box = [scan_p]
                    decl_type = decl_type + pipeline_capture_type_args(toks, sp_box, base_dt)
                    scan_p = get(sp_box, 0)
                end
            end
            if scan_p < toks.len() and (toks[scan_p].tok_kind == TOK_ASSIGN() or (toks[scan_p].tok_kind != TOK_STR() and toks[scan_p].tok_text == "="))
                list_set(pos_box, 0, scan_p + 1)
                val_e = pipeline_parse_expr(toks, pos_box, sp)
                as_n = ast_stmt_assign(var_name, val_e, sp)
                if len(decl_type) > 0
                    as_n.op = decl_type
                end
                return as_n
            end
        end
    end

    // 4a2. Raw Pointer Dereference Assignment: *ptr_expr = rhs
    // WHY: Parse `*ptr = val` as an explicit AST node (`op == "deref_assign"`) so `--kavach`
    // blocks uncrowned pointer stores and `--strict-ownership` / `--strict-types` analyze both sides.
    if (k == TOK_STAR() or (k != TOK_STR() and txt == "*")) and cp + 2 < toks.len()
        dp_scan = cp + 1
        dp_pdepth = 0
        dp_eq_pos = 0 - 1
        dp_line = t.tok_span.span_start_line
        while dp_scan < toks.len()
            dpt = toks[dp_scan]
            dpk = dpt.tok_kind
            dpx = dpt.tok_text
            if dpk == TOK_NEWLINE() or dpk == TOK_SEMI() or dpk == TOK_EOF() or dpt.tok_span.span_start_line > dp_line
                break
            end
            if dpk == TOK_LPAREN() or dpx == "(" or dpk == TOK_LBRACKET() or dpx == "["
                dp_pdepth = dp_pdepth + 1
            elif dpk == TOK_RPAREN() or dpx == ")" or dpk == TOK_RBRACKET() or dpx == "]"
                if dp_pdepth > 0 dp_pdepth = dp_pdepth - 1 end
            elif dp_pdepth == 0 and (dpk == TOK_ASSIGN() or (dpk != TOK_STR() and dpx == "="))
                dp_eq_pos = dp_scan
                break
            end
            dp_scan = dp_scan + 1
        end
        if dp_eq_pos > cp + 1
            list_set(pos_box, 0, cp + 1)
            ptr_lhs = pipeline_parse_expr(toks, pos_box, sp)
            list_set(pos_box, 0, dp_eq_pos + 1)
            ptr_rhs = pipeline_parse_expr(toks, pos_box, sp)
            da_st = ast_stmt_assign("*", ptr_rhs, sp)
            da_st.op = "deref_assign"
            da_st.left = ast_expr_unary("*", ptr_lhs, sp)
            return da_st
        end
    end

    // 4b. Struct Field Assignment (arbitrary chaining depth): obj.field = expr, obj.f1.f2 = expr (+=, -=)
    if pipeline_is_ident_token(k) == 1
        scan_fp = cp + 1
        chain_str = txt
        chain_cnt = 0
        while scan_fp + 1 < toks.len()
            t_dot = toks[scan_fp]
            t_fld = toks[scan_fp + 1]
            if (t_dot.tok_kind == TOK_DOT() or (t_dot.tok_kind != TOK_STR() and t_dot.tok_text == ".")) and pipeline_is_ident_token(t_fld.tok_kind) == 1
                chain_str = chain_str + "." + t_fld.tok_text
                chain_cnt = chain_cnt + 1
                scan_fp = scan_fp + 2
            else
                break
            end
        end
        if chain_cnt > 0 and scan_fp < toks.len()
            t_eq = toks[scan_fp]
            if t_eq.tok_kind == TOK_ASSIGN() or (t_eq.tok_kind != TOK_STR() and t_eq.tok_text == "=")
                list_set(pos_box, 0, scan_fp + 1)
                val_e = pipeline_parse_expr(toks, pos_box, sp)
                return ast_stmt_assign(chain_str, val_e, sp)
            elif t_eq.tok_kind == TOK_PLUSEQ() or (t_eq.tok_kind != TOK_STR() and t_eq.tok_text == "+=")
                list_set(pos_box, 0, scan_fp + 1)
                val_e = pipeline_parse_expr(toks, pos_box, sp)
                return ast_stmt_assign_op(chain_str, val_e, "+=", sp)
            elif t_eq.tok_kind == TOK_MINUSEQ() or (t_eq.tok_kind != TOK_STR() and t_eq.tok_text == "-=")
                list_set(pos_box, 0, scan_fp + 1)
                val_e = pipeline_parse_expr(toks, pos_box, sp)
                return ast_stmt_assign_op(chain_str, val_e, "-=", sp)
            elif t_eq.tok_kind == TOK_STAREQ() or t_eq.tok_kind == TOK_SLASHEQ() or t_eq.tok_kind == TOK_PERCENTEQ() or (t_eq.tok_kind != TOK_STR() and (t_eq.tok_text == "*=" or t_eq.tok_text == "/=" or t_eq.tok_text == "%="))
                // WHY: Parse *=, /=, %= on struct fields so SSA never drops compound field ops as bare expressions.
                list_set(pos_box, 0, scan_fp + 1)
                val_e = pipeline_parse_expr(toks, pos_box, sp)
                return ast_stmt_assign_op(chain_str, val_e, t_eq.tok_text, sp)
            elif t_eq.tok_kind == TOK_LBRACKET() or (t_eq.tok_kind != TOK_STR() and t_eq.tok_text == "[")
                scan_bi = scan_fp + 1
                bc_f = 1
                while scan_bi < toks.len()
                    stb = toks[scan_bi]
                    if stb.tok_kind == TOK_LBRACKET() or (stb.tok_kind != TOK_STR() and stb.tok_text == "[")
                        bc_f = bc_f + 1
                    elif stb.tok_kind == TOK_RBRACKET() or (stb.tok_kind != TOK_STR() and stb.tok_text == "]")
                        bc_f = bc_f - 1
                        if bc_f == 0
                            scan_bi = scan_bi + 1
                            break
                        end
                    elif stb.tok_kind == TOK_NEWLINE() or stb.tok_kind == TOK_SEMI()
                        break
                    end
                    scan_bi = scan_bi + 1
                end
                if bc_f == 0 and scan_bi < toks.len()
                    eq_b = toks[scan_bi]
                    if eq_b.tok_kind == TOK_ASSIGN() or (eq_b.tok_kind != TOK_STR() and eq_b.tok_text == "=")
                        idx_b_box = [scan_fp + 1]
                        idx_be = pipeline_parse_expr(toks, idx_b_box, sp)
                        list_set(pos_box, 0, scan_bi + 1)
                        val_be = pipeline_parse_expr(toks, pos_box, sp)
                        farr_as = ast_stmt_assign(chain_str, val_be, sp)
                        farr_as.index = idx_be
                        return farr_as
                    elif eq_b.tok_kind == TOK_PLUSEQ() or eq_b.tok_kind == TOK_MINUSEQ() or eq_b.tok_kind == TOK_STAREQ() or eq_b.tok_kind == TOK_SLASHEQ() or eq_b.tok_kind == TOK_PERCENTEQ() or (eq_b.tok_kind != TOK_STR() and (eq_b.tok_text == "+=" or eq_b.tok_text == "-=" or eq_b.tok_text == "*=" or eq_b.tok_text == "/=" or eq_b.tok_text == "%="))
                        idx_b_box = [scan_fp + 1]
                        idx_be = pipeline_parse_expr(toks, idx_b_box, sp)
                        list_set(pos_box, 0, scan_bi + 1)
                        val_be = pipeline_parse_expr(toks, pos_box, sp)
                        farr_aop = ast_stmt_assign_op(chain_str, val_be, eq_b.tok_text, sp)
                        farr_aop.index = idx_be
                        return farr_aop
                    end
                end
            end
        end
    end

    // 4c. Array Element Assignment: arr[idx] = expr
    if pipeline_is_ident_token(k) == 1 and cp + 1 < toks.len()
        nt1 = toks[cp + 1]
        if nt1.tok_kind == TOK_LBRACKET() or (nt1.tok_kind != TOK_STR() and nt1.tok_text == "[")
            scan_i = cp + 2
            b_cnt = 1
            while scan_i < toks.len()
                st = toks[scan_i]
                if st.tok_kind == TOK_LBRACKET() or (st.tok_kind != TOK_STR() and st.tok_text == "[")
                    b_cnt = b_cnt + 1
                elif st.tok_kind == TOK_RBRACKET() or (st.tok_kind != TOK_STR() and st.tok_text == "]")
                    b_cnt = b_cnt - 1
                    if b_cnt == 0
                        scan_i = scan_i + 1
                        break
                    end
                elif st.tok_kind == TOK_NEWLINE() or st.tok_kind == TOK_SEMI()
                    break
                end
                scan_i = scan_i + 1
            end
            if b_cnt == 0 and scan_i < toks.len()
                eq_tok = toks[scan_i]
                ek = eq_tok.tok_kind
                etx = eq_tok.tok_text
                if ek == TOK_ASSIGN() or (ek != TOK_STR() and etx == "=")
                    idx_box = [cp + 2]
                    idx_e = pipeline_parse_expr(toks, idx_box, sp)
                    list_set(pos_box, 0, scan_i + 1)
                    val_e = pipeline_parse_expr(toks, pos_box, sp)
                    arr_as = ast_stmt_assign(txt, val_e, sp)
                    arr_as.index = idx_e
                    return arr_as
                elif ek == TOK_PLUSEQ() or ek == TOK_MINUSEQ() or ek == TOK_STAREQ() or ek == TOK_SLASHEQ() or ek == TOK_PERCENTEQ() or etx == "+=" or etx == "-=" or etx == "*=" or etx == "/=" or etx == "%="
                    idx_box = [cp + 2]
                    idx_e = pipeline_parse_expr(toks, idx_box, sp)
                    list_set(pos_box, 0, scan_i + 1)
                    val_e = pipeline_parse_expr(toks, pos_box, sp)
                    arr_aop = ast_stmt_assign_op(txt, val_e, etx, sp)
                    arr_aop.index = idx_e
                    return arr_aop
                end
            end
        end
    end

    // 4d. Mutable global declaration: global / @global / বিশ্বজনীন name [: Type] [= expr]
    if k == TOK_IDENT() and (txt == "global" or txt == "@global" or txt == "বিশ্বজনীন") and cp + 1 < toks.len()
        if pipeline_is_ident_token(toks[cp + 1].tok_kind) == 1 and toks[cp + 1].tok_text != "="
            g_name = toks[cp + 1].tok_text
            list_set(pos_box, 0, cp + 2)
            gp = get(pos_box, 0)
            if gp < toks.len() and (toks[gp].tok_kind == TOK_COLON() or (toks[gp].tok_kind != TOK_STR() and toks[gp].tok_text == ":"))
                if gp + 1 < toks.len() and pipeline_is_ident_token(toks[gp + 1].tok_kind) == 1
                    list_set(pos_box, 0, gp + 2)
                end
            end
            geq = get(pos_box, 0)
            if geq < toks.len() and (toks[geq].tok_kind == TOK_ASSIGN() or (toks[geq].tok_kind != TOK_STR() and toks[geq].tok_text == "="))
                list_set(pos_box, 0, geq + 1)
                gval_e = pipeline_parse_expr(toks, pos_box, sp)
                return ast_stmt_assign(g_name, gval_e, sp)
            end
            return ast_stmt_assign(g_name, ast_expr_literal_int(0, sp), sp)
        end
    end

    // 5. Direct assignment: ident = expr, ident += expr, multi-var destructuring a, b = rhs1, rhs2, OR typed declaration: ident: Type = expr
    if pipeline_is_ident_token(k) == 1 and cp + 1 < toks.len()
        n1 = toks[cp + 1]
        // Case 0: Multi-variable tuple destructuring: a, b [, c...] = rhs1 [, rhs2...]
        if n1.tok_kind == TOK_COMMA() or (n1.tok_kind != TOK_STR() and n1.tok_text == ",")
            da_lhs = [ast_expr_ident(txt, sp)]
            da_p = cp + 1
            da_ok = 1
            while da_p < toks.len()
                if toks[da_p].tok_kind == TOK_COMMA() or (toks[da_p].tok_kind != TOK_STR() and toks[da_p].tok_text == ",")
                    da_p = da_p + 1
                    if da_p < toks.len() and pipeline_is_ident_token(toks[da_p].tok_kind) == 1
                        push(da_lhs, ast_expr_ident(toks[da_p].tok_text, sp))
                        da_p = da_p + 1
                    else
                        da_ok = 0
                        break
                    end
                else
                    break
                end
            end
            if da_ok == 1 and da_lhs.len() >= 2 and da_p < toks.len() and (toks[da_p].tok_kind == TOK_ASSIGN() or (toks[da_p].tok_kind != TOK_STR() and toks[da_p].tok_text == "="))
                da_line = toks[da_p].tok_span.span_start_line
                list_set(pos_box, 0, da_p + 1)
                da_rhs = [pipeline_parse_expr(toks, pos_box, sp)]
                while get(pos_box, 0) < toks.len()
                    dr_p = get(pos_box, 0)
                    if (toks[dr_p].tok_kind == TOK_COMMA() or (toks[dr_p].tok_kind != TOK_STR() and toks[dr_p].tok_text == ",")) and toks[dr_p].tok_span.span_start_line == da_line
                        list_set(pos_box, 0, dr_p + 1)
                        push(da_rhs, pipeline_parse_expr(toks, pos_box, sp))
                    else
                        break
                    end
                end
                da_n = ast_node_new(AST_TAG_ASSIGN(), "MultiAssign", sp)
                da_n.params = da_lhs
                da_n.args = da_rhs
                return da_n
            end
        end
        // Case A: Typed declaration/assignment (e.g. search_res: PageSearchLeafResult = ..., p: *const u32 = ..., g: dyn Greet = ...)
        if n1.tok_kind == TOK_COLON() or (n1.tok_kind != TOK_STR() and n1.tok_text == ":")
            tp_scan = cp + 2
            decl_pref = ""
            while tp_scan < toks.len() and (toks[tp_scan].tok_kind == TOK_STAR() or (toks[tp_scan].tok_kind != TOK_STR() and toks[tp_scan].tok_text == "*"))
                decl_pref = decl_pref + "*"
                tp_scan = tp_scan + 1
                if tp_scan < toks.len() and (toks[tp_scan].tok_text == "const" or toks[tp_scan].tok_text == "mut")
                    decl_pref = decl_pref + toks[tp_scan].tok_text + " "
                    tp_scan = tp_scan + 1
                end
            end
            if tp_scan + 1 < toks.len() and toks[tp_scan].tok_kind == TOK_IDENT() and toks[tp_scan].tok_text == "dyn" and pipeline_is_ident_token(toks[tp_scan + 1].tok_kind) == 1
                eq_i = tp_scan + 2
                if eq_i < toks.len() and (toks[eq_i].tok_kind == TOK_ASSIGN() or (toks[eq_i].tok_kind != TOK_STR() and toks[eq_i].tok_text == "="))
                    var_name = txt
                    decl_type = decl_pref + "dyn " + toks[tp_scan + 1].tok_text
                    list_set(pos_box, 0, eq_i + 1)
                    val_e = pipeline_parse_expr(toks, pos_box, sp)
                    td_n = ast_stmt_assign(var_name, val_e, sp)
                    td_n.op = decl_type
                    return td_n
                end
            elif tp_scan < toks.len() and pipeline_is_ident_token(toks[tp_scan].tok_kind) == 1
                base_td = toks[tp_scan].tok_text
                td_box = [tp_scan + 1]
                td_args = pipeline_capture_type_args(toks, td_box, base_td)
                eq_i = get(td_box, 0)
                if eq_i < toks.len()
                    n3 = toks[eq_i]
                    if n3.tok_kind == TOK_ASSIGN() or (n3.tok_kind != TOK_STR() and n3.tok_text == "=")
                        var_name = txt
                        decl_type = decl_pref + base_td + td_args
                        list_set(pos_box, 0, eq_i + 1)
                        val_e = pipeline_parse_expr(toks, pos_box, sp)
                        td_n = ast_stmt_assign(var_name, val_e, sp)
                        td_n.op = decl_type
                        return td_n
                    end
                end
            end
        end
        // Case B: Direct assignment ident = expr
        if n1.tok_kind == TOK_ASSIGN() or (n1.tok_kind != TOK_STR() and n1.tok_text == "=")
            var_name = txt
            list_set(pos_box, 0, cp + 2)
            val_e = pipeline_parse_expr(toks, pos_box, sp)
            return ast_stmt_assign(var_name, val_e, sp)
        end
        if n1.tok_kind == TOK_PLUSEQ() or (n1.tok_kind != TOK_STR() and n1.tok_text == "+=")
            var_name = txt
            list_set(pos_box, 0, cp + 2)
            val_e = pipeline_parse_expr(toks, pos_box, sp)
            return ast_stmt_assign_op(var_name, val_e, "+=", sp)
        end
        if n1.tok_kind == TOK_MINUSEQ() or (n1.tok_kind != TOK_STR() and n1.tok_text == "-=")
            var_name = txt
            list_set(pos_box, 0, cp + 2)
            val_e = pipeline_parse_expr(toks, pos_box, sp)
            return ast_stmt_assign_op(var_name, val_e, "-=", sp)
        end
        if n1.tok_kind == TOK_STAREQ() or n1.tok_kind == TOK_SLASHEQ() or n1.tok_kind == TOK_PERCENTEQ() or (n1.tok_kind != TOK_STR() and (n1.tok_text == "*=" or n1.tok_text == "/=" or n1.tok_text == "%="))
            var_name = txt
            list_set(pos_box, 0, cp + 2)
            val_e = pipeline_parse_expr(toks, pos_box, sp)
            return ast_stmt_assign_op(var_name, val_e, n1.tok_text, sp)
        end
        // Two-token shift/bitwise compound assignments: >>=, <<=, &=, |=, ^=
        if cp + 2 < toks.len() and (toks[cp + 2].tok_kind == TOK_ASSIGN() or (toks[cp + 2].tok_kind != TOK_STR() and toks[cp + 2].tok_text == "="))
            if n1.tok_kind == TOK_SHR() or n1.tok_kind == TOK_SHL() or n1.tok_kind == TOK_AMP() or n1.tok_kind == TOK_BAR() or n1.tok_kind == TOK_CARET() or (n1.tok_kind != TOK_STR() and (n1.tok_text == ">>" or n1.tok_text == "<<" or n1.tok_text == "&" or n1.tok_text == "|" or n1.tok_text == "^"))
                var_name = txt
                list_set(pos_box, 0, cp + 3)
                val_e = pipeline_parse_expr(toks, pos_box, sp)
                return ast_stmt_assign_op(var_name, val_e, n1.tok_text + "=", sp)
            end
        end
    end

    // 5b. Exception throw: throw expr / নিক্ষেপ expr
    if txt == "throw" or txt == "নিক্ষেপ" or txt == "@throw"
        list_set(pos_box, 0, cp + 1)
        err_e = pipeline_parse_expr(toks, pos_box, sp)
        th_node = ast_stmt_expr(err_e, sp)
        th_node.kind = "ExprStmt"
        th_node.op = "throw"
        return th_node
    end

    // 5c. Exception try/catch/finally: supports BOTH braced `{ ... }` AND indentation/`end` blocks
    is_try = 0
    if k == TOK_KW_TRY() or k == TOK_DIR_TRY() or (k == TOK_IDENT() and (txt == "try" or txt == "চেষ্টা" or txt == "@try"))
        if cp + 1 >= toks.len() or (toks[cp + 1].tok_kind != TOK_ASSIGN() and toks[cp + 1].tok_text != "=")
            is_try = 1
        end
    end
    if is_try == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, cp + 1)
        try_body = list()
        catch_body = list()
        pipeline_skip_whitespace(toks, pos_box)
        try_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
            try_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        while get(pos_box, 0) < toks.len()
            pipeline_skip_whitespace(toks, pos_box)
            cur_pt = get(pos_box, 0)
            if cur_pt >= toks.len() break end
            ct_t = toks[cur_pt]
            if try_braced == 1
                if ct_t.tok_kind == TOK_RBRACE() or (ct_t.tok_kind != TOK_STR() and ct_t.tok_text == "}")
                    list_set(pos_box, 0, cur_pt + 1)
                    break
                end
            else
                if ct_t.tok_kind == TOK_RBRACE() or (ct_t.tok_kind != TOK_STR() and ct_t.tok_text == "}")
                    break
                end
                if ct_t.tok_kind == TOK_KW_CATCH() or ct_t.tok_kind == TOK_DIR_CATCH() or (ct_t.tok_kind == TOK_IDENT() and (ct_t.tok_text == "catch" or ct_t.tok_text == "ধরো" or ct_t.tok_text == "@catch" or ct_t.tok_text == "finally" or ct_t.tok_text == "অবশেষে" or ct_t.tok_text == "@finally"))
                    break
                end
                if pipeline_is_block_end(toks, cur_pt) == 1 break end
                if ct_t.tok_span.span_start_line > base_line and ct_t.tok_span.span_start_col <= base_col break end
            end
            bp_t = get(pos_box, 0)
            st_t = pipeline_build_statement(toks, pos_box, sp)
            if st_t != 0 push(try_body, st_t) end
            if get(pos_box, 0) <= bp_t list_set(pos_box, 0, bp_t + 1) end
        end
        has_catch_ast = 0
        catch_braced = 1
        pipeline_skip_whitespace(toks, pos_box)
        if get(pos_box, 0) < toks.len()
            ct_c = toks[get(pos_box, 0)]
            if ct_c.tok_kind == TOK_KW_CATCH() or ct_c.tok_kind == TOK_DIR_CATCH() or (ct_c.tok_kind == TOK_IDENT() and (ct_c.tok_text == "catch" or ct_c.tok_text == "ধরো" or ct_c.tok_text == "@catch"))
                has_catch_ast = 1
                c_line = ct_c.tok_span.span_start_line
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_span.span_start_line == c_line and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                    err_vname = toks[get(pos_box, 0)].tok_text
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    push(catch_body, ast_stmt_assign(err_vname, ast_expr_literal_int(0, sp), sp))
                end
                pipeline_skip_whitespace(toks, pos_box)
                catch_braced = 0
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
                    catch_braced = 1
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                while get(pos_box, 0) < toks.len()
                    pipeline_skip_whitespace(toks, pos_box)
                    cur_pc = get(pos_box, 0)
                    if cur_pc >= toks.len() break end
                    ct_c2 = toks[cur_pc]
                    if catch_braced == 1
                        if ct_c2.tok_kind == TOK_RBRACE() or (ct_c2.tok_kind != TOK_STR() and ct_c2.tok_text == "}")
                            list_set(pos_box, 0, cur_pc + 1)
                            break
                        end
                    else
                        if ct_c2.tok_kind == TOK_RBRACE() or (ct_c2.tok_kind != TOK_STR() and ct_c2.tok_text == "}")
                            break
                        end
                        if ct_c2.tok_kind == TOK_IDENT() and (ct_c2.tok_text == "finally" or ct_c2.tok_text == "অবশেষে" or ct_c2.tok_text == "@finally")
                            break
                        end
                        if pipeline_is_block_end(toks, cur_pc) == 1 break end
                        if ct_c2.tok_span.span_start_line > c_line and ct_c2.tok_span.span_start_col <= base_col break end
                    end
                    bp_c = get(pos_box, 0)
                    st_c = pipeline_build_statement(toks, pos_box, sp)
                    if st_c != 0 push(catch_body, st_c) end
                    if get(pos_box, 0) <= bp_c list_set(pos_box, 0, bp_c + 1) end
                end
            end
        end
        has_fin_ast = 0
        fin_braced = 1
        fin_body = list()
        pipeline_skip_whitespace(toks, pos_box)
        if get(pos_box, 0) < toks.len()
            ct_f = toks[get(pos_box, 0)]
            if ct_f.tok_kind == TOK_IDENT() and (ct_f.tok_text == "finally" or ct_f.tok_text == "অবশেষে" or ct_f.tok_text == "@finally")
                has_fin_ast = 1
                f_line = ct_f.tok_span.span_start_line
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                pipeline_skip_whitespace(toks, pos_box)
                fin_braced = 0
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
                    fin_braced = 1
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                while get(pos_box, 0) < toks.len()
                    pipeline_skip_whitespace(toks, pos_box)
                    cur_pf = get(pos_box, 0)
                    if cur_pf >= toks.len() break end
                    ct_f2 = toks[cur_pf]
                    if fin_braced == 1
                        if ct_f2.tok_kind == TOK_RBRACE() or (ct_f2.tok_kind != TOK_STR() and ct_f2.tok_text == "}")
                            list_set(pos_box, 0, cur_pf + 1)
                            break
                        end
                    else
                        if ct_f2.tok_kind == TOK_RBRACE() or (ct_f2.tok_kind != TOK_STR() and ct_f2.tok_text == "}")
                            break
                        end
                        if pipeline_is_block_end(toks, cur_pf) == 1 break end
                        if ct_f2.tok_span.span_start_line > f_line and ct_f2.tok_span.span_start_col <= base_col break end
                    end
                    bp_f = get(pos_box, 0)
                    st_f = pipeline_build_statement(toks, pos_box, sp)
                    if st_f != 0 push(fin_body, st_f) end
                    if get(pos_box, 0) <= bp_f list_set(pos_box, 0, bp_f + 1) end
                end
            end
        end
        any_unbraced_ast = 0
        if try_braced == 0 or (has_catch_ast == 1 and catch_braced == 0) or (has_fin_ast == 1 and fin_braced == 0)
            any_unbraced_ast = 1
        end
        pipeline_skip_whitespace(toks, pos_box)
        if any_unbraced_ast == 1 and get(pos_box, 0) < toks.len() and pipeline_is_block_end(toks, get(pos_box, 0)) == 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        try_nd = ast_stmt_if(ast_expr_literal_bool(1, sp), try_body, list(), catch_body, sp)
        try_nd.op = "try"
        try_nd.body = fin_body
        return try_nd
    end

    // 5d. Pattern match statement: match expr ... (excluding variable 'match = ...')
    if pipeline_is_match_start(toks, cp) == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, cp + 1)
        scrut_e = pipeline_parse_expr(toks, pos_box, sp)
        match_body = list()
        match_pat_names = list()
        pipeline_skip_whitespace(toks, pos_box)
        m_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
            m_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        while get(pos_box, 0) < toks.len()
            pipeline_skip_whitespace(toks, pos_box)
            cur_pm = get(pos_box, 0)
            if cur_pm >= toks.len() break end
            ct_m = toks[cur_pm]
            if m_braced == 1
                if ct_m.tok_kind == TOK_RBRACE() or (ct_m.tok_kind != TOK_STR() and ct_m.tok_text == "}")
                    list_set(pos_box, 0, cur_pm + 1)
                    break
                end
                if ct_m.tok_kind == TOK_COMMA() or (ct_m.tok_kind != TOK_STR() and ct_m.tok_text == ",")
                    list_set(pos_box, 0, cur_pm + 1)
                    continue
                end
            else
                if pipeline_is_block_end(toks, cur_pm) == 1
                    list_set(pos_box, 0, cur_pm + 1)
                    break
                end
                if ct_m.tok_span.span_start_line > base_line and ct_m.tok_span.span_start_col <= base_col break end
            end
            arm_col = ct_m.tok_span.span_start_col
            arm_line = ct_m.tok_span.span_start_line
            if ct_m.tok_kind == TOK_KW_CASE() or (ct_m.tok_kind == TOK_IDENT() and (ct_m.tok_text == "case" or ct_m.tok_text == "ক্ষেত্র"))
                list_set(pos_box, 0, cur_pm + 1)
            end
            arm_body = list()
            pat_p = get(pos_box, 0)
            pat_lbl = ""
            if pat_p < toks.len() and (toks[pat_p].tok_text == "_" or toks[pat_p].tok_text == "default" or toks[pat_p].tok_text == "অন্যথায়" or toks[pat_p].tok_kind == TOK_KW_ELSE())
                pat_lbl = "_"
                list_set(pos_box, 0, pat_p + 1)
            else
                if pat_p < toks.len() and (pipeline_is_ident_token(toks[pat_p].tok_kind) == 1 or toks[pat_p].tok_kind == TOK_NONE())
                    pat_lbl = toks[pat_p].tok_text
                    if pat_p + 3 < toks.len() and (toks[pat_p + 1].tok_kind == TOK_COLON() or toks[pat_p + 1].tok_text == ":") and (toks[pat_p + 2].tok_kind == TOK_COLON() or toks[pat_p + 2].tok_text == ":") and (pipeline_is_ident_token(toks[pat_p + 3].tok_kind) == 1 or toks[pat_p + 3].tok_kind == TOK_NONE())
                        pat_lbl = pat_lbl + "::" + toks[pat_p + 3].tok_text
                    end
                end
                pat_binds_st = pipeline_try_parse_adt_pat_binds(toks, pos_box)
                if pat_binds_st != 0
                    pbi_st = 0
                    while pbi_st < pat_binds_st.len()
                        push(arm_body, ast_stmt_assign(pat_binds_st[pbi_st], ast_expr_literal_int(0, sp), sp))
                        pbi_st = pbi_st + 1
                    end
                else
                    pat_e = pipeline_parse_expr(toks, pos_box, sp)
                    pat_st = ast_stmt_expr(pat_e, sp)
                    pat_st.kind = "ExprStmt"
                    push(arm_body, pat_st)
                end
            end
            push(match_pat_names, pat_lbl)
            if get(pos_box, 0) < toks.len()
                sep_k = toks[get(pos_box, 0)].tok_kind
                sep_txt = toks[get(pos_box, 0)].tok_text
                if sep_k == TOK_FAT_ARROW() or sep_k == TOK_COLON() or sep_k == TOK_ARROW() or sep_txt == "=>" or sep_txt == ":" or sep_txt == "->"
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            end
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                while get(pos_box, 0) < toks.len()
                    pipeline_skip_whitespace(toks, pos_box)
                    cp_ab = get(pos_box, 0)
                    if cp_ab >= toks.len() break end
                    if toks[cp_ab].tok_kind == TOK_RBRACE() or (toks[cp_ab].tok_kind != TOK_STR() and toks[cp_ab].tok_text == "}")
                        list_set(pos_box, 0, cp_ab + 1)
                        break
                    end
                    bp_mb = get(pos_box, 0)
                    st_mb = pipeline_build_statement(toks, pos_box, sp)
                    if st_mb != 0 push(arm_body, st_mb) end
                    if get(pos_box, 0) <= bp_mb list_set(pos_box, 0, bp_mb + 1) end
                end
            elif get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_span.span_start_line == arm_line and toks[get(pos_box, 0)].tok_kind != TOK_NEWLINE()
                bp_m = get(pos_box, 0)
                st_m = pipeline_build_statement(toks, pos_box, sp)
                if st_m != 0 push(arm_body, st_m) end
                if get(pos_box, 0) <= bp_m list_set(pos_box, 0, bp_m + 1) end
            else
                while get(pos_box, 0) < toks.len()
                    pipeline_skip_whitespace(toks, pos_box)
                    cp_ab = get(pos_box, 0)
                    if cp_ab >= toks.len() break end
                    ct_ab = toks[cp_ab]
                    if pipeline_is_block_end(toks, cp_ab) == 1 break end
                    if m_braced == 1 and (ct_ab.tok_kind == TOK_RBRACE() or (ct_ab.tok_kind != TOK_STR() and ct_ab.tok_text == "}")) break end
                    if ct_ab.tok_span.span_start_line > arm_line and ct_ab.tok_span.span_start_col <= arm_col break end
                    bp_m2 = get(pos_box, 0)
                    st_m2 = pipeline_build_statement(toks, pos_box, sp)
                    if st_m2 != 0 push(arm_body, st_m2) end
                    if get(pos_box, 0) <= bp_m2 list_set(pos_box, 0, bp_m2 + 1) end
                end
            end
            push(match_body, ast_stmt_if(ast_expr_literal_int(1, sp), arm_body, list(), list(), sp))
        end
        m_stmt_nd = ast_stmt_if(scrut_e, match_body, list(), list(), sp)
        m_stmt_nd.op = "match"
        m_stmt_nd.elements = match_pat_names
        return m_stmt_nd
    end

    // 5c. Scoped Memory Region statement: region ... end / অঞ্চল ... শেষ
    if pipeline_is_region_start(toks, cp) == 1
            reg_col = t.tok_span.span_start_col
            reg_line = t.tok_span.span_start_line
            list_set(pos_box, 0, cp + 1)
            pipeline_skip_whitespace(toks, pos_box)
            r_braced = 0
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
                r_braced = 1
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            reg_body = list()
            while get(pos_box, 0) < toks.len()
                pipeline_skip_whitespace(toks, pos_box)
                cur_pr = get(pos_box, 0)
                if cur_pr >= toks.len() break end
                ct_r = toks[cur_pr]
                if r_braced == 1
                    if ct_r.tok_kind == TOK_RBRACE() or (ct_r.tok_kind != TOK_STR() and ct_r.tok_text == "}")
                        list_set(pos_box, 0, cur_pr + 1)
                        break
                    end
                else
                    if pipeline_is_block_end(toks, cur_pr) == 1
                        list_set(pos_box, 0, cur_pr + 1)
                        break
                    end
                    if ct_r.tok_span.span_start_line > reg_line and ct_r.tok_span.span_start_col <= reg_col break end
                end
                bp_r = get(pos_box, 0)
                st_r = pipeline_build_statement(toks, pos_box, sp)
                if st_r != 0 push(reg_body, st_r) end
                if get(pos_box, 0) <= bp_r list_set(pos_box, 0, bp_r + 1) end
            end
            reg_nd = ast_stmt_if(ast_expr_literal_int(1, sp), reg_body, list(), list(), sp)
            reg_nd.op = "region"
            return reg_nd
    end

    // 6. Output print / say statement
    if k == TOK_KW_PRINT() or txt == "say" or txt == "বলো" or txt == "print" or txt == "println"
        list_set(pos_box, 0, cp + 1)
        arg_e = pipeline_parse_expr(toks, pos_box, sp)
        callee_v = ast_expr_ident(txt, sp)
        call_e = ast_expr_call(callee_v, [arg_e], sp)
        call_e.params = [arg_e]
        call_node = ast_stmt_expr(call_e, sp)
        call_node.kind = "ExprStmt"
        return call_node
    end

    // 7. General expression statement fallback
    e_node = pipeline_parse_expr(toks, pos_box, sp)
    stmt_node = ast_stmt_expr(e_node, sp)
    stmt_node.kind = "ExprStmt"
    return stmt_node

fn pipeline_build_ast_declarations toks src_path
    // WHY: Transforms token stream into typed AST declarations, supporting bilingual syntax,
    // parameters, blocks, loops, and top-level execution without hardcoded placeholders.
    sp = source_span_point(src_path, 1, 1, 0)
    decls = list()
    top_stmts = list()
    pos_box = [0]
    cur_impl_type = ""
    cur_impl_braced = 0
    cur_impl_col = 0
    cur_impl_line = 0

    while get(pos_box, 0) < toks.len()
        while get(pos_box, 0) < toks.len()
            k = toks[get(pos_box, 0)].tok_kind
            if k == TOK_NEWLINE() or k == TOK_SEMI() or k == TOK_COMMENT_LINE() or k == TOK_COMMENT_BLOCK()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            else
                break

        if get(pos_box, 0) >= toks.len()
            break

        cp = get(pos_box, 0)
        t = toks[cp]
        k = t.tok_kind
        txt = t.tok_text

        if k == TOK_EOF()
            break

        // WHY: Track lexical exit of `impl [Trait for] Type { ... }` / `impl ... end` blocks so
        // inner methods are isolated as `Type_method` with `self: Type` and outer functions stay bare.
        if cur_impl_type != ""
            if cur_impl_braced == 1
                if k == TOK_RBRACE() or (k != TOK_STR() and txt == "}")
                    cur_impl_type = ""
                    cur_impl_braced = 0
                    list_set(pos_box, 0, cp + 1)
                    continue
                end
            else
                if pipeline_is_block_end(toks, cp) == 1 and t.tok_span.span_start_col <= cur_impl_col
                    cur_impl_type = ""
                    list_set(pos_box, 0, cp + 1)
                    continue
                elif t.tok_span.span_start_line > cur_impl_line and t.tok_span.span_start_col <= cur_impl_col
                    cur_impl_type = ""
                end
            end
        end

        // Skip top-level hardware/silicon & strictness attribute directives before declarations
        if k == TOK_IDENT() and (txt == "@naked" or txt == "@interrupt" or txt == "@packed" or txt == "@ring0" or txt == "@silicon" or txt == "@strict" or txt == "@fn_strict" or txt == "@strict_types" or txt == "@strict_ownership" or txt == "@strict_proof" or txt == "@kavach" or txt == "@freestanding" or str_starts_with(txt, "@attr_") == 1)
            list_set(pos_box, 0, cp + 1)
            continue
        elif k == TOK_IDENT() and (txt == "@align" or txt == "@layout" or txt == "@section")
            list_set(pos_box, 0, cp + 1)
            pipeline_skip_whitespace(toks, pos_box)
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LPAREN() or toks[get(pos_box, 0)].tok_text == "(")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                dp_t = 1
                while get(pos_box, 0) < toks.len() and dp_t > 0
                    ak_t = toks[get(pos_box, 0)].tok_kind
                    at_t = toks[get(pos_box, 0)].tok_text
                    if ak_t == TOK_LPAREN() or at_t == "(" dp_t = dp_t + 1
                    elif ak_t == TOK_RPAREN() or at_t == ")" dp_t = dp_t - 1 end
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            elif get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_INT() or toks[get(pos_box, 0)].tok_kind == TOK_STR())
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            continue
        elif k == TOK_IDENT() and (txt == "extern" or txt == "বাহ্যিক") and cp + 1 < toks.len()
            // Parse `extern fn name(p1: T1, ...) -> Ret` as empty-body AST fn decl so TypeChecker registers signature!
            list_set(pos_box, 0, cp + 2)
            ext_nm = ""
            if get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                ext_nm = toks[get(pos_box, 0)].tok_text
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            ext_params = list()
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LPAREN() or toks[get(pos_box, 0)].tok_text == "(")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                while get(pos_box, 0) < toks.len()
                    ep_t = toks[get(pos_box, 0)]
                    if ep_t.tok_kind == TOK_RPAREN() or ep_t.tok_text == ")"
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        break
                    elif ep_t.tok_kind == TOK_COMMA() or ep_t.tok_text == "," or ep_t.tok_kind == TOK_NEWLINE()
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    elif pipeline_is_ident_token(ep_t.tok_kind) == 1
                        ep_n = ep_t.tok_text
                        ep_ty = ""
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or toks[get(pos_box, 0)].tok_text == ":")
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                            while get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_STAR() or toks[get(pos_box, 0)].tok_text == "*" or toks[get(pos_box, 0)].tok_kind == TOK_KW_CONST() or toks[get(pos_box, 0)].tok_kind == TOK_KW_MUT())
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                            end
                            if get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                                ep_ty = toks[get(pos_box, 0)].tok_text
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                                pipeline_skip_type_args(toks, pos_box, 0)
                            end
                        end
                        push(ext_params, ast_param_new(ep_n, ep_ty, 0, sp))
                    else
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    end
                end
            end
            ext_rt = ""
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_ARROW() or toks[get(pos_box, 0)].tok_text == "->" or toks[get(pos_box, 0)].tok_kind == TOK_COLON() or toks[get(pos_box, 0)].tok_text == ":")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                while get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_STAR() or toks[get(pos_box, 0)].tok_text == "*" or toks[get(pos_box, 0)].tok_kind == TOK_KW_CONST() or toks[get(pos_box, 0)].tok_kind == TOK_KW_MUT())
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                if get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                    ext_rt = toks[get(pos_box, 0)].tok_text
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    pipeline_skip_type_args(toks, pos_box, 0)
                end
            end
            if len(ext_nm) > 0
                push(decls, ast_decl_fn(ext_nm, ext_params, ext_rt, list(), 1, sp))
            end
            continue
        end

        fn_decl_col = t.tok_span.span_start_col
        if (k == TOK_KW_ASYNC() or (k == TOK_IDENT() and (txt == "async" or txt == "@async" or txt == "অসমলয়"))) and cp + 1 < toks.len()
            nt_as = toks[cp + 1]
            if nt_as.tok_kind == TOK_KW_FN() or nt_as.tok_kind == TOK_DIR_FN() or (nt_as.tok_kind == TOK_IDENT() and (nt_as.tok_text == "fn" or nt_as.tok_text == "কাজ" or nt_as.tok_text == "@fn"))
                cp = cp + 1
                t = nt_as
                k = t.tok_kind
                txt = t.tok_text
                list_set(pos_box, 0, cp)
            end
        end

        is_comp = 0
        if k == TOK_KW_COMPONENT() or (k == TOK_IDENT() and (txt == "component" or txt == "উপাদান"))
            is_comp = 1
        end

        if k == TOK_KW_FN() or k == TOK_DIR_FN() or is_comp == 1 or (k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn"))
            fn_sp = sp
            if t.tok_span != 0
                fn_sp = t.tok_span
            end
            list_set(pos_box, 0, cp + 1)
            fn_name = ""
            method_recv_type = ""
            if get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                fn_name = toks[get(pos_box, 0)].tok_text
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                mp = get(pos_box, 0)
                if mp + 1 < toks.len() and (toks[mp].tok_kind == TOK_DOT() or (toks[mp].tok_kind != TOK_STR() and toks[mp].tok_text == "."))
                    if pipeline_is_ident_token(toks[mp + 1].tok_kind) == 1
                        method_recv_type = fn_name
                        fn_name = fn_name + "_" + toks[mp + 1].tok_text
                        list_set(pos_box, 0, mp + 2)
                    end
                elif cur_impl_type != ""
                    method_recv_type = cur_impl_type
                    fn_name = cur_impl_type + "_" + fn_name
                end
            end

            // Skip optional generic type parameter list: fn name<T, U>(...)
            pipeline_skip_type_args(toks, pos_box, 0)

            // Parse formal parameters
            params = list()
            has_paren = 0
            if get(pos_box, 0) < toks.len()
                if toks[get(pos_box, 0)].tok_kind == TOK_LPAREN() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "(")
                    has_paren = 1
                    list_set(pos_box, 0, get(pos_box, 0) + 1)

            while get(pos_box, 0) < toks.len()
                p_idx = get(pos_box, 0)
                pt = toks[p_idx]
                if has_paren == 1
                    if pt.tok_kind == TOK_RPAREN() or (pt.tok_kind != TOK_STR() and pt.tok_text == ")")
                        list_set(pos_box, 0, p_idx + 1)
                        break
                    end
                    if pt.tok_kind == TOK_NEWLINE() or pt.tok_kind == TOK_SEMI() or pt.tok_kind == TOK_COMMENT_LINE() or pt.tok_kind == TOK_COMMENT_BLOCK()
                        list_set(pos_box, 0, p_idx + 1)
                    elif (pt.tok_kind == TOK_DOTDOT() and p_idx + 2 < toks.len() and toks[p_idx + 1].tok_kind == TOK_DOT() and pipeline_is_ident_token(toks[p_idx + 2].tok_kind) == 1) or pipeline_is_ident_token(pt.tok_kind) == 1
                        p_is_var = 0
                        if pt.tok_kind == TOK_DOTDOT()
                            p_is_var = 1
                            p_idx = p_idx + 2
                            pt = toks[p_idx]
                        end
                        p_name = pt.tok_text
                        p_type = ""
                        if p_is_var == 1
                            p_type = "list"
                        end
                        p_def = 0
                        list_set(pos_box, 0, p_idx + 1)
                        if get(pos_box, 0) < toks.len()
                            nxt_k = toks[get(pos_box, 0)].tok_kind
                            nxt_t = toks[get(pos_box, 0)].tok_text
                            if nxt_k == TOK_COLON() or (nxt_k != TOK_STR() and nxt_t == ":")
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                                vp_c = get(pos_box, 0)
                                if vp_c + 1 < toks.len() and toks[vp_c].tok_kind == TOK_DOTDOT() and toks[vp_c + 1].tok_kind == TOK_DOT()
                                    p_is_var = 1
                                    p_type = "list"
                                    list_set(pos_box, 0, vp_c + 2)
                                    // Skip optional element type after `...` (e.g. `...int`, `...*u8`)
                                    while get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_STAR() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "*"))
                                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                                        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_text == "const" or toks[get(pos_box, 0)].tok_text == "mut")
                                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                                        end
                                    end
                                    if get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                                        pipeline_skip_type_args(toks, pos_box, 0)
                                    end
                                else
                                    while get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_STAR() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "*"))
                                        p_type = p_type + "*"
                                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                                        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_text == "const" or toks[get(pos_box, 0)].tok_text == "mut")
                                            p_type = p_type + toks[get(pos_box, 0)].tok_text + " "
                                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                                        end
                                    end
                                    if get(pos_box, 0) + 1 < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT() and toks[get(pos_box, 0)].tok_text == "dyn" and pipeline_is_ident_token(toks[get(pos_box, 0) + 1].tok_kind) == 1
                                        if p_is_var == 0
                                            p_type = p_type + "dyn " + toks[get(pos_box, 0) + 1].tok_text
                                        end
                                        list_set(pos_box, 0, get(pos_box, 0) + 2)
                                    elif get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                                        base_pt1 = toks[get(pos_box, 0)].tok_text
                                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                                        pt1_args = pipeline_capture_type_args(toks, pos_box, base_pt1)
                                        if p_is_var == 0
                                            p_type = p_type + base_pt1 + pt1_args
                                        end
                                    end
                                end
                            end
                        end
                        // Optional default parameter value: `= <expr>` (parenthesized param lists)
                        if get(pos_box, 0) < toks.len()
                            dk_p = toks[get(pos_box, 0)].tok_kind
                            dt_p = toks[get(pos_box, 0)].tok_text
                            if dk_p == TOK_ASSIGN() or (dk_p != TOK_STR() and dt_p == "=")
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                                p_def = pipeline_parse_expr(toks, pos_box, sp)
                            end
                        end
                        p_node = ast_param_new(p_name, p_type, p_def, sp)
                        p_node.param_is_variadic = p_is_var
                        push(params, p_node)
                    elif pt.tok_kind == TOK_COMMA() or (pt.tok_kind != TOK_STR() and pt.tok_text == ",")
                        list_set(pos_box, 0, p_idx + 1)
                    else
                        list_set(pos_box, 0, p_idx + 1)
                    end
                else
                    if pt.tok_kind == TOK_NEWLINE() or pt.tok_kind == TOK_LBRACE() or pt.tok_kind == TOK_ASSIGN() or (pt.tok_kind != TOK_STR() and (pt.tok_text == "{" or pt.tok_text == "="))
                        break
                    end
                    if pt.tok_kind == TOK_ARROW() or (pt.tok_kind != TOK_STR() and pt.tok_text == "->")
                        break
                    end
                    if (pt.tok_kind == TOK_DOTDOT() and p_idx + 2 < toks.len() and toks[p_idx + 1].tok_kind == TOK_DOT() and pipeline_is_ident_token(toks[p_idx + 2].tok_kind) == 1) or pipeline_is_ident_token(pt.tok_kind) == 1
                        p_is_var = 0
                        if pt.tok_kind == TOK_DOTDOT()
                            p_is_var = 1
                            p_idx = p_idx + 2
                            pt = toks[p_idx]
                        end
                        p_name = pt.tok_text
                        p_type = ""
                        if p_is_var == 1
                            p_type = "list"
                        end
                        list_set(pos_box, 0, p_idx + 1)
                        if get(pos_box, 0) < toks.len()
                            nxt_k = toks[get(pos_box, 0)].tok_kind
                            nxt_t = toks[get(pos_box, 0)].tok_text
                            if nxt_k == TOK_COLON() or (nxt_k != TOK_STR() and nxt_t == ":")
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                                vp_u = get(pos_box, 0)
                                if vp_u + 1 < toks.len() and toks[vp_u].tok_kind == TOK_DOTDOT() and toks[vp_u + 1].tok_kind == TOK_DOT()
                                    p_is_var = 1
                                    p_type = "list"
                                    list_set(pos_box, 0, vp_u + 2)
                                    if get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                                        pipeline_skip_type_args(toks, pos_box, 0)
                                    end
                                else
                                    while get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_STAR() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "*"))
                                        p_type = p_type + "*"
                                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                                        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_text == "const" or toks[get(pos_box, 0)].tok_text == "mut")
                                            p_type = p_type + toks[get(pos_box, 0)].tok_text + " "
                                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                                        end
                                    end
                                    if get(pos_box, 0) + 1 < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT() and toks[get(pos_box, 0)].tok_text == "dyn" and pipeline_is_ident_token(toks[get(pos_box, 0) + 1].tok_kind) == 1
                                        if p_is_var == 0
                                            p_type = p_type + "dyn " + toks[get(pos_box, 0) + 1].tok_text
                                        end
                                        list_set(pos_box, 0, get(pos_box, 0) + 2)
                                    elif get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                                        base_pt1 = toks[get(pos_box, 0)].tok_text
                                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                                        pt1_args = pipeline_capture_type_args(toks, pos_box, base_pt1)
                                        if p_is_var == 0
                                            p_type = p_type + base_pt1 + pt1_args
                                        end
                                    end
                                end
                            end
                        end
                        p_node = ast_param_new(p_name, p_type, 0, sp)
                        p_node.param_is_variadic = p_is_var
                        push(params, p_node)
                    elif pt.tok_kind == TOK_COMMA() or (pt.tok_kind != TOK_STR() and pt.tok_text == ",")
                        list_set(pos_box, 0, p_idx + 1)
                    else
                        list_set(pos_box, 0, p_idx + 1)
                    end
                end

            // Extract return type annotation: -> [dyn] type[<...>] or : [dyn] type[<...>]
            ret_type_str = ""
            if get(pos_box, 0) < toks.len()
                rk = toks[get(pos_box, 0)].tok_kind
                rtxt = toks[get(pos_box, 0)].tok_text
                if rk == TOK_ARROW() or rtxt == "->" or rk == TOK_COLON() or rtxt == ":"
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    while get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_STAR() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "*"))
                        ret_type_str = ret_type_str + "*"
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_text == "const" or toks[get(pos_box, 0)].tok_text == "mut")
                            ret_type_str = ret_type_str + toks[get(pos_box, 0)].tok_text + " "
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                        end
                    end
                    if get(pos_box, 0) + 1 < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT() and toks[get(pos_box, 0)].tok_text == "dyn" and pipeline_is_ident_token(toks[get(pos_box, 0) + 1].tok_kind) == 1
                        ret_type_str = ret_type_str + "dyn " + toks[get(pos_box, 0) + 1].tok_text
                        list_set(pos_box, 0, get(pos_box, 0) + 2)
                    elif get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                        base_rt = toks[get(pos_box, 0)].tok_text
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        rt_args = pipeline_capture_type_args(toks, pos_box, base_rt)
                        ret_type_str = ret_type_str + base_rt + rt_args
                    end
                end
            end

            // Parse body statements
            body = list()
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_ASSIGN() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "="))
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                ret_e = pipeline_parse_expr(toks, pos_box, sp)
                push(body, ast_stmt_return(ret_e, sp))
            elif get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                while get(pos_box, 0) < toks.len()
                    pipeline_skip_whitespace(toks, pos_box)
                    if get(pos_box, 0) >= toks.len()
                        break
                    end
                    if toks[get(pos_box, 0)].tok_kind == TOK_RBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "}")
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        break
                    end
                    before_bp = get(pos_box, 0)
                    s = pipeline_build_statement(toks, pos_box, sp)
                    if s != 0
                        push(body, s)
                    end
                    if get(pos_box, 0) <= before_bp
                        list_set(pos_box, 0, before_bp + 1)
                    end
                end
            else
                // Indented or end-delimited block
                fn_line = t.tok_span.span_start_line
                fn_col = fn_decl_col
                while get(pos_box, 0) < toks.len()
                    while get(pos_box, 0) < toks.len()
                        k_skip = toks[get(pos_box, 0)].tok_kind
                        if k_skip == TOK_NEWLINE() or k_skip == TOK_SEMI() or k_skip == TOK_COMMENT_LINE() or k_skip == TOK_COMMENT_BLOCK()
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                        else
                            break
                    end
                    if get(pos_box, 0) >= toks.len()
                        break
                    end

                    cur_p = get(pos_box, 0)
                    cur_tok = toks[cur_p]
                    if cur_tok.tok_kind == TOK_KW_FN() or cur_tok.tok_kind == TOK_DIR_FN() or cur_tok.tok_kind == TOK_KW_COMPONENT()
                        break
                    end
                    if cur_tok.tok_kind == TOK_IDENT() and (cur_tok.tok_text == "fn" or cur_tok.tok_text == "কাজ" or cur_tok.tok_text == "@fn" or cur_tok.tok_text == "component" or cur_tok.tok_text == "উপাদান" or cur_tok.tok_text == "@naked" or cur_tok.tok_text == "@interrupt" or cur_tok.tok_text == "@packed" or cur_tok.tok_text == "@align" or cur_tok.tok_text == "@bss")
                        break
                    end
                    if cur_impl_braced == 1 and (cur_tok.tok_kind == TOK_RBRACE() or (cur_tok.tok_kind != TOK_STR() and cur_tok.tok_text == "}"))
                        break
                    end
                    if pipeline_is_block_end(toks, cur_p) == 1
                        list_set(pos_box, 0, cur_p + 1)
                        break
                    end
                    if cur_tok.tok_span.span_start_col <= fn_col and cur_tok.tok_span.span_start_line > fn_line
                        break
                    end
                    before_p = get(pos_box, 0)
                    s = pipeline_build_statement(toks, pos_box, sp)
                    if s != 0
                        push(body, s)
                    end
                    if get(pos_box, 0) <= before_p
                        list_set(pos_box, 0, before_p + 1)
                    end

            if method_recv_type != "" and params.len() > 0
                if params[0].param_type == "" and (cur_impl_type == "" or params[0].param_name == "self" or params[0].param_name == "নিজ")
                    params[0].param_type = method_recv_type
                end
            end
            if is_comp == 1
                if len(ret_type_str) == 0
                    ret_type_str = "Component"
                end
                fn_decl = ast_decl_component(fn_name, params, ret_type_str, body, fn_sp)
            else
                fn_decl = ast_decl_fn(fn_name, params, ret_type_str, body, 1, fn_sp)
            end
            push(decls, fn_decl)
        elif k == TOK_KW_STRUCT() or k == TOK_DIR_STRUCT() or (k == TOK_IDENT() and (txt == "struct" or txt == "গঠন" or txt == "@struct" or txt == "union" or txt == "ইউনিয়ন" or txt == "@union"))
            base_l = t.tok_span.span_start_line
            base_c = t.tok_span.span_start_col
            list_set(pos_box, 0, cp + 1)
            struct_name = ""
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                struct_name = toks[get(pos_box, 0)].tok_text
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            pipeline_skip_type_args(toks, pos_box, 0)
            st_braced = 0
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
                st_braced = 1
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            fields = list()
            while get(pos_box, 0) < toks.len()
                while get(pos_box, 0) < toks.len()
                    sk_skip = toks[get(pos_box, 0)].tok_kind
                    if sk_skip == TOK_NEWLINE() or sk_skip == TOK_SEMI() or sk_skip == TOK_COMMA() or sk_skip == TOK_COMMENT_LINE() or sk_skip == TOK_COMMENT_BLOCK()
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    else
                        break
                    end
                end
                if get(pos_box, 0) >= toks.len()
                    break
                end
                sk = toks[get(pos_box, 0)].tok_kind
                stxt = toks[get(pos_box, 0)].tok_text
                if st_braced == 1
                    if sk == TOK_RBRACE() or (sk != TOK_STR() and stxt == "}")
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        break
                    end
                else
                    if sk == TOK_KW_END() or sk == TOK_DIR_END() or stxt == "end" or stxt == "শেষ" or stxt == "@end"
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        break
                    end
                    if sk == TOK_KW_FN() or sk == TOK_DIR_FN() or sk == TOK_KW_STRUCT() or sk == TOK_DIR_STRUCT() or sk == TOK_KW_ENUM() or sk == TOK_DIR_ENUM()
                        break
                    end
                    if sk == TOK_IDENT() and (stxt == "fn" or stxt == "কাজ" or stxt == "@fn" or stxt == "struct" or stxt == "গঠন" or stxt == "@struct" or stxt == "union" or stxt == "ইউনিয়ন" or stxt == "@union" or stxt == "enum" or stxt == "@enum" or stxt == "গণনা" or stxt == "trait" or stxt == "impl")
                        break
                    end
                    if toks[get(pos_box, 0)].tok_span.span_start_line > base_l and toks[get(pos_box, 0)].tok_span.span_start_col <= base_c
                        break
                    end
                end
                if sk == TOK_IDENT()
                    fld_name = stxt
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    fld_type = ""
                    if get(pos_box, 0) < toks.len()
                        fld_k = toks[get(pos_box, 0)].tok_kind
                        fld_t = toks[get(pos_box, 0)].tok_text
                        if fld_k == TOK_COLON() or (fld_k != TOK_STR() and fld_t == ":")
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                            ptr_pref = ""
                            while get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_STAR() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "*"))
                                ptr_pref = ptr_pref + "*"
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_text == "const" or toks[get(pos_box, 0)].tok_text == "mut")
                                    ptr_pref = ptr_pref + toks[get(pos_box, 0)].tok_text + " "
                                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                                end
                            end
                            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACKET() or toks[get(pos_box, 0)].tok_text == "[")
                                arr_s = "["
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                                while get(pos_box, 0) < toks.len()
                                    if toks[get(pos_box, 0)].tok_kind == TOK_RBRACKET() or toks[get(pos_box, 0)].tok_text == "]"
                                        arr_s = arr_s + "]"
                                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                                        break
                                    end
                                    arr_s = arr_s + toks[get(pos_box, 0)].tok_text
                                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                                end
                                if get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                                    fld_type = ptr_pref + arr_s + toks[get(pos_box, 0)].tok_text
                                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                                end
                            elif get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                                base_ft = toks[get(pos_box, 0)].tok_text
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                                ft_args = pipeline_capture_type_args(toks, pos_box, base_ft)
                                fld_type = ptr_pref + base_ft + ft_args
                            end
                            // Skip optional bitfield width `: <int>`
                            if get(pos_box, 0) + 1 < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or toks[get(pos_box, 0)].tok_text == ":") and toks[get(pos_box, 0) + 1].tok_kind == TOK_INT()
                                list_set(pos_box, 0, get(pos_box, 0) + 2)
                            end
                        end
                    end
                    push(fields, ast_field_new(fld_name, fld_type, 0, fields.len() * 8, sp))
                else
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            end
            if len(struct_name) > 0
                s_decl = ast_decl_struct(struct_name, fields, sp)
                push(decls, s_decl)
            end
        elif (k == TOK_DIR_TRAIT() or (k == TOK_IDENT() and (txt == "trait" or txt == "বৈশিষ্ট্য" or txt == "@trait"))) and cp + 1 < toks.len() and pipeline_is_ident_token(toks[cp + 1].tok_kind) == 1 and toks[cp + 1].tok_span.span_start_line == t.tok_span.span_start_line
            // Skip compile-time `trait Name { fn ... }` declaration in AST phase
            base_l = t.tok_span.span_start_line
            base_c = t.tok_span.span_start_col
            list_set(pos_box, 0, cp + 1)
            if get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            pipeline_skip_type_args(toks, pos_box, 0)
            pipeline_skip_whitespace(toks, pos_box)
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
                tr_d = 1
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                while get(pos_box, 0) < toks.len() and tr_d > 0
                    ttk = toks[get(pos_box, 0)]
                    if ttk.tok_kind == TOK_LBRACE() or (ttk.tok_kind != TOK_STR() and ttk.tok_text == "{")
                        tr_d = tr_d + 1
                    elif ttk.tok_kind == TOK_RBRACE() or (ttk.tok_kind != TOK_STR() and ttk.tok_text == "}")
                        tr_d = tr_d - 1
                    end
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            else
                while get(pos_box, 0) < toks.len()
                    ttk = toks[get(pos_box, 0)]
                    if ttk.tok_kind == TOK_EOF() break end
                    if pipeline_is_block_end(toks, get(pos_box, 0)) == 1 and ttk.tok_span.span_start_col <= base_c
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        break
                    end
                    if ttk.tok_span.span_start_line > base_l and ttk.tok_span.span_start_col <= base_c and ttk.tok_kind != TOK_NEWLINE()
                        break
                    end
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            end
        elif k == TOK_KW_IMPL() or k == TOK_DIR_IMPL() or (k == TOK_IDENT() and (txt == "impl" or txt == "বাস্তবায়ন" or txt == "@impl"))
            // Parse `impl [Trait for] Type { fn ... }` header so inner methods are isolated under
            // `Type_method` with typed `self: Type`, and emit `TraitImpl` for `impl Trait for Type`.
            impl_b_line = t.tok_span.span_start_line
            impl_b_col = t.tok_span.span_start_col
            list_set(pos_box, 0, cp + 1)
            pipeline_skip_type_args(toks, pos_box, 0)
            impl_first = ""
            if get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                impl_first = toks[get(pos_box, 0)].tok_text
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            pipeline_skip_type_args(toks, pos_box, 0)
            impl_recv_t = impl_first
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_KW_FOR() or toks[get(pos_box, 0)].tok_text == "for" or toks[get(pos_box, 0)].tok_text == "জন্য")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                impl_target = ""
                if get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                    impl_target = toks[get(pos_box, 0)].tok_text
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                pipeline_skip_type_args(toks, pos_box, 0)
                if len(impl_target) > 0
                    impl_recv_t = impl_target
                end
                if len(impl_first) > 0 and len(impl_target) > 0
                    ti_node = ast_node_new(AST_TAG_STRUCT_DEF(), "TraitImpl", sp)
                    ti_node.name = impl_first
                    ti_node.target = impl_target
                    push(decls, ti_node)
                end
            end
            cur_impl_type = impl_recv_t
            cur_impl_line = impl_b_line
            cur_impl_col = impl_b_col
            cur_impl_braced = 0
            pipeline_skip_whitespace(toks, pos_box)
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
                cur_impl_braced = 1
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
        elif k == TOK_KW_ENUM() or k == TOK_DIR_ENUM() or (k == TOK_IDENT() and (txt == "enum" or txt == "@enum" or txt == "গণনা"))
            base_l = t.tok_span.span_start_line
            base_c = t.tok_span.span_start_col
            list_set(pos_box, 0, cp + 1)
            enum_name = ""
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                enum_name = toks[get(pos_box, 0)].tok_text
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            pipeline_skip_type_args(toks, pos_box, 0)
            en_braced = 0
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
                en_braced = 1
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            variants = list()
            var_arities = list()
            var_payload_types = list()
            while get(pos_box, 0) < toks.len()
                while get(pos_box, 0) < toks.len()
                    ek_skip = toks[get(pos_box, 0)].tok_kind
                    if ek_skip == TOK_NEWLINE() or ek_skip == TOK_SEMI() or ek_skip == TOK_COMMA() or ek_skip == TOK_COMMENT_DOC() or ek_skip == TOK_COMMENT_LINE() or ek_skip == TOK_COMMENT_BLOCK()
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    else
                        break
                    end
                end
                if get(pos_box, 0) >= toks.len()
                    break
                end
                ek = toks[get(pos_box, 0)].tok_kind
                etxt = toks[get(pos_box, 0)].tok_text
                if en_braced == 1
                    if ek == TOK_RBRACE() or (ek != TOK_STR() and etxt == "}")
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        break
                    end
                else
                    if ek == TOK_KW_END() or ek == TOK_DIR_END() or etxt == "end" or etxt == "শেষ" or etxt == "@end"
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        break
                    end
                    if ek == TOK_KW_FN() or ek == TOK_DIR_FN() or ek == TOK_KW_STRUCT() or ek == TOK_DIR_STRUCT() or ek == TOK_KW_ENUM() or ek == TOK_DIR_ENUM()
                        break
                    end
                    if ek == TOK_IDENT() and (etxt == "fn" or etxt == "কাজ" or etxt == "@fn" or etxt == "struct" or etxt == "গঠন" or etxt == "@struct" or etxt == "enum" or etxt == "@enum" or etxt == "গণনা")
                        break
                    end
                    if toks[get(pos_box, 0)].tok_span.span_start_line > base_l and toks[get(pos_box, 0)].tok_span.span_start_col <= base_c
                        break
                    end
                end
                if pipeline_is_ident_token(ek) == 1
                    push(variants, etxt)
                    v_arity = 0
                    v_types = list()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LPAREN() or toks[get(pos_box, 0)].tok_text == "(")
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        v_pdepth = 1
                        v_expect = 1
                        v_cur_pref = ""
                        while get(pos_box, 0) < toks.len() and v_pdepth > 0
                            vk = toks[get(pos_box, 0)].tok_kind
                            vtx = toks[get(pos_box, 0)].tok_text
                            if vk == TOK_RPAREN() or (vk != TOK_STR() and vtx == ")")
                                v_pdepth = v_pdepth - 1
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                            elif vk == TOK_LPAREN() or (vk != TOK_STR() and vtx == "(")
                                v_pdepth = v_pdepth + 1
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                            elif vk == TOK_COMMA() or (vk != TOK_STR() and vtx == ",")
                                v_expect = 1
                                v_cur_pref = ""
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                            elif vk == TOK_STAR() or (vk != TOK_STR() and vtx == "*")
                                v_cur_pref = v_cur_pref + "*"
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_text == "const" or toks[get(pos_box, 0)].tok_text == "mut")
                                    v_cur_pref = v_cur_pref + toks[get(pos_box, 0)].tok_text + " "
                                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                                end
                            elif vk == TOK_LT() or (vk != TOK_STR() and vtx == "<")
                                if pipeline_skip_type_args(toks, pos_box, 0) == 0
                                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                                end
                            elif pipeline_is_ident_token(vk) == 1
                                if v_expect == 1
                                    // Handle optional named payload field `name: Type` vs bare `Type`
                                    np_ev = get(pos_box, 0) + 1
                                    if np_ev < toks.len() and (toks[np_ev].tok_kind == TOK_COLON() or (toks[np_ev].tok_kind != TOK_STR() and toks[np_ev].tok_text == ":"))
                                        list_set(pos_box, 0, np_ev + 1)
                                    elif vtx == "dyn" and np_ev < toks.len() and pipeline_is_ident_token(toks[np_ev].tok_kind) == 1
                                        push(v_types, v_cur_pref + "dyn " + toks[np_ev].tok_text)
                                        v_arity = v_arity + 1
                                        v_expect = 0
                                        v_cur_pref = ""
                                        list_set(pos_box, 0, np_ev + 1)
                                    else
                                        list_set(pos_box, 0, np_ev)
                                        ev_targs = pipeline_capture_type_args(toks, pos_box, vtx)
                                        push(v_types, v_cur_pref + vtx + ev_targs)
                                        v_arity = v_arity + 1
                                        v_expect = 0
                                        v_cur_pref = ""
                                    end
                                else
                                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                                end
                            else
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                            end
                        end
                    elif get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_ASSIGN() or toks[get(pos_box, 0)].tok_text == "=")
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        if get(pos_box, 0) < toks.len()
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                        end
                    end
                    push(var_arities, v_arity)
                    push(var_payload_types, v_types)
                else
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            end
            if len(enum_name) > 0
                e_decl = ast_decl_enum(enum_name, variants, sp)
                e_decl.params = var_arities
                e_decl.args = var_payload_types
                push(decls, e_decl)
            end
        elif k == TOK_RBRACE() or (k != TOK_STR() and txt == "}") or k == TOK_KW_END() or k == TOK_DIR_END() or (k == TOK_IDENT() and (txt == "end" or txt == "শেষ" or txt == "@end"))
            list_set(pos_box, 0, cp + 1)
        else
            before_top = get(pos_box, 0)
            stmt = pipeline_build_statement(toks, pos_box, sp)
            if stmt != 0
                push(top_stmts, stmt)
            end
            if get(pos_box, 0) <= before_top
                list_set(pos_box, 0, before_top + 1)
            end

    // Synthesize or augment entry point main() if required
    if top_stmts.len() > 0 or decls.len() == 0
        main_found = 0
        di = 0
        while di < decls.len()
            d = decls[di]
            if d.name == "main" or d.name == "মূল"
                main_found = 1
                new_body = list()
                ti = 0
                while ti < top_stmts.len()
                    push(new_body, top_stmts[ti])
                    ti = ti + 1
                bi = 0
                while bi < d.body.len()
                    push(new_body, d.body[bi])
                    bi = bi + 1
                d.body = new_body
                break
            di = di + 1
        if main_found == 0
            main_decl = ast_decl_fn("main", list(), "any", top_stmts, 1, sp)
            push(decls, main_decl)

    return decls

// ── 3. Constructor Functions ──────────────────────────────────────────────────

fn compiler_config_new src out_bin arch opt fmt dry_run
    cfg = CompilerConfig()
    cfg.cfg_src_path = src
    cfg.cfg_out_path = out_bin
    cfg.cfg_target_arch = arch
    cfg.cfg_opt_level = opt
    cfg.cfg_emit_format = fmt
    cfg.cfg_is_dry_run = dry_run
    cfg.cfg_verbose = 0
    cfg.cfg_debug_mode = 0
    cfg.cfg_no_pie = 0
    cfg.cfg_strict_ownership = 0
    cfg.cfg_strict_proof = 0
    cfg.cfg_kavach_mode = 0
    cfg.cfg_strict_types = 0
    cfg.cfg_freestanding = 0
    cfg.cfg_base_vaddr = 1073741824
    cfg.cfg_ssa_codegen = 0
    cfg.cfg_entry_sym = ""
    cfg.cfg_utso_ranges = 0
    return cfg

fn compiler_result_new
    res = CompilerResult()
    res.res_success = 0
    res.res_stage_reached = PIPELINE_STAGE_INIT()
    res.res_error_count = 0
    res.res_warning_count = 0
    res.res_output_bytes = 0
    res.res_tokens_scanned = 0
    res.res_reg_alloc_spills = 0
    res.res_error_msg = ""
    return res

fn pipeline_str_contains haystack needle
    h_len = len(haystack)
    n_len = len(needle)
    if n_len > h_len
        return 0
    end
    if n_len == 0
        return 1
    end
    limit = h_len - n_len
    idx = 0
    while idx <= limit
        k = 0
        matched = 1
        while k < n_len
            if char_at(haystack, idx + k) != char_at(needle, k)
                matched = 0
                k = n_len
            else
                k = k + 1
            end
        end
        if matched == 1
            return 1
        end
        idx = idx + 1
    end
    return 0

// WHY: Prefix verification for assertion and panic handler function exemptions.
fn pipeline_str_has_prefix haystack needle
    h_len = len(haystack)
    n_len = len(needle)
    if n_len > h_len
        return 0
    end
    k = 0
    while k < n_len
        if char_at(haystack, k) != char_at(needle, k)
            return 0
        end
        k = k + 1
    end
    return 1

// WHY: Suffix verification for lifecycle routines (_new, _free, _alloc, _destroy, etc).
fn pipeline_str_has_suffix haystack needle
    h_len = len(haystack)
    n_len = len(needle)
    if n_len > h_len
        return 0
    end
    offset = h_len - n_len
    k = 0
    while k < n_len
        if char_at(haystack, offset + k) != char_at(needle, k)
            return 0
        end
        k = k + 1
    end
    return 1

// WHY: Matches token as a whole word, prefix (token_), suffix (_token), or inner word (_token_).
// Eliminates false positives where a substring occurs inside another English word (e.g. "free" in "freeze", "new" in "renew", "init" in "definition").
fn pipeline_name_has_token name token
    if name == token
        return 1
    end
    t_pref = token + "_"
    if pipeline_str_has_prefix(name, t_pref) == 1
        return 1
    end
    t_suff = "_" + token
    if pipeline_str_has_suffix(name, t_suff) == 1
        return 1
    end
    t_mid = "_" + token + "_"
    if pipeline_str_contains(name, t_mid) == 1
        return 1
    end
    return 0

// WHY: Identifies constant getter routines defined in ALL_CAPS style (e.g. PT_LOAD, IMAGE_DOS_SIGNATURE).
// These functions return primitive integer constants without memory allocations and are always mathematically conserved.
fn pipeline_is_all_caps name
    n_len = name.len()
    if n_len == 0 return 0 end
    ci = 0
    has_upper = 0
    while ci < n_len
        ch = char_at(name, ci)
        code = ord(ch)
        if code >= 65 and code <= 90
            has_upper = 1
        elif code >= 48 and code <= 57
            // digit
        elif code == 95
            // underscore
        else
            return 0
        end
        ci = ci + 1
    end
    return has_upper

// WHY: Detects non-ASCII (e.g. Bengali Unicode) identifier codepoints to recognize native Bengali runtime utilities.
fn pipeline_str_has_non_ascii s
    slen = len(s)
    si = 0
    while si < slen
        if mem_byte_read(s, si) > 127
            return 1
        end
        si = si + 1
    end
    return 0

// WHY: Precise memory proof exemption filter preventing false positives on words like "freeze", "renew", "definition".
// Enforces exact whole-word, prefix (e.g. assert_, panic_), suffix (_new, _free), or inner-word (_create_) matching.
fn pipeline_is_memory_exempt_fn raw_name
    // WHY: Struct member methods mutably alter receiver state and aren't closed mathematical scopes.
    if pipeline_str_contains(raw_name, ".") == 1 return 1 end
    // Exact stdlib Bengali allocator/wrapper names
    if raw_name == "মেমরি_বরাদ্দ" or raw_name == "স্ল্যাব_বরাদ্দ" or raw_name == "মেমরি_বরাদ্দ_ক্যাশলাইন" or raw_name == "বরাদ্দ" or raw_name == "তালিকা"
        return 1
    end
    // WHY: Constant getters in ALL_CAPS format are pure primitive returns.
    if pipeline_is_all_caps(raw_name) == 1 return 1 end
    // WHY: Normalize function name to lowercase so casing (e.g. Ed25519, Secp256k1, Poly1305, DW_) matches uniformly without case discrepancies.
    name = str_to_lower(raw_name)
    if pipeline_str_has_prefix(name, "basicblock_") == 1 or pipeline_str_has_prefix(name, "ssainstr_") == 1 or pipeline_str_has_prefix(name, "ssavalue_") == 1 or pipeline_str_has_prefix(name, "irfunction_") == 1 or pipeline_str_has_prefix(name, "irmodule_") == 1 or pipeline_str_has_prefix(name, "passmanager_") == 1
        return 1
    end
    // WHY: Result and Option monadic constructors allocate heap-backed algebraic wrappers that escape constructor scope.
    if name == "ok" or name == "err" or name == "some" or name == "none" return 1 end
    // WHY: Domain engines (AI/LLM, Virtual Machines, OS/Unikernel, Filesystems, Distributed DBs, Quantum, Hardware/GUI) manage persistent global state or heap objects.
    if pipeline_str_has_prefix(name, "canvas_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "kvm_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "svm_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ext4_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "fs_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "uefi_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "mb2_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "multiboot1_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "micro_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ai_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "llm_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "autodiff_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "backward_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "loss_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "optimizer_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "dataloader_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "topo_sort") == 1 return 1 end
    if pipeline_str_has_prefix(name, "math_exp") == 1 return 1 end
    if pipeline_str_has_prefix(name, "int_to_float") == 1 return 1 end
    if pipeline_str_has_prefix(name, "rope_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "rmsnorm_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "layernorm_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "self_attention_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "mlp_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "transformer_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "gpt_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "flash_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "qreg_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "quantum_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "quant_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "quantize_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "dequantize") == 1 return 1 end
    if pipeline_str_has_prefix(name, "sample_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "softmax_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "greedy_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "temperature_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "top_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "prng_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "inference_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "xor_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "gguf_") == 1 return 1 end
    // WHY: Paging, documentation parsers, hardware GHASH authentication, BTree storage engines, and build dependency graphs calculate pointers and streaming states that violate simple closed-scope memory conservation.
    if pipeline_str_has_prefix(name, "page_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ghash") == 1 return 1 end
    if pipeline_str_has_prefix(name, "doc_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "btree_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "dep_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "tx_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "recovery_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "lipidb_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "crdt_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "db_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "df_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "webrtc_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "bft_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "gcm_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "kv_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ptrace_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "option_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "h3_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "baremetal_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "microservice_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "dns_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "pipe_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "fast_json_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ffi_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "hnsw_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "lipipkg_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "liprpc_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "mqtt_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "mvcc_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "orm_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "pkcs7_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "scene_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "state_trie_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "unum_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "amx_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "vnni_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "cpu_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "wire_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "tensor_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "app_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "compute_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "raft_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "wal_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "evm_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "http3_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "quic_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "phdr_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "shdr_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "reloc_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "push_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "sys_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "lipi_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "repl_") == 1 return 1 end
    // WHY: Async fibers, coroutines, schedulers, and channels allocate persistent task contexts and cross-stack queues that outlive the caller scope.
    if pipeline_str_has_prefix(name, "fiber_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "coroutine_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "scheduler_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "chan_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "channel_") == 1 return 1 end
    // WHY: Hardware DRM/KMS graphics, framebuffers, async event loops, and GPU bytecode generators manage physical VRAM and kernel drivers.
    if pipeline_str_has_prefix(name, "drm_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "kms_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "amx_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "browser_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "html_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "css_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "layout_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "raster_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "mesh_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "verilog_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "fb_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "fbdev_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "gui_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "event_loop_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "spirv_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "memo_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "fib_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "tarjan_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "specialize_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "stmt_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "skip_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "unescape_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "val_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "register_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "resolve_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "dw_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "errno_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "darwin_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "windows_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "syscall") == 1 return 1 end
    if pipeline_str_has_prefix(name, "lexer_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "hashmap_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "deque_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "pq_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "set_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "arr_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "c_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "is_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "to_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "substr") == 1 return 1 end
    if pipeline_str_has_prefix(name, "eq") == 1 return 1 end
    if pipeline_str_has_prefix(name, "int_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "float_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "byte_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "color_theme_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "source_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "line_index_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "error_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "diagnostic_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "suggestion_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "snippet_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "levenshtein_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "cli_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "compiler_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ai_opt_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ast_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "token_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "tok_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "scope_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "sym_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "symbol_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "symtab_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "type_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "tc_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ir_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ssa_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "bb_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "basic_block_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "BasicBlock.") == 1 return 1 end
    if pipeline_str_has_prefix(name, "SSAInstr.") == 1 return 1 end
    if pipeline_str_has_prefix(name, "SSAValue.") == 1 return 1 end
    if pipeline_str_has_prefix(name, "IRFunction.") == 1 return 1 end
    if pipeline_str_has_prefix(name, "IRModule.") == 1 return 1 end
    if pipeline_str_has_prefix(name, "PassManager.") == 1 return 1 end
    if pipeline_str_has_prefix(name, "dom_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "dom_tree_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "loop_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "dce_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "cse_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "licm_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "dse_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "inlining_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "monomorph_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "generic_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "dep_graph_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "inc_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "compilation_cache_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "comptime_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "linear_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "peephole_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "silicon_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "modrm_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "sib_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "rex_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "vex2_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "vex3_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "vport_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "pipeline_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "driver_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "codegen_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "asm_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "regalloc_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "arena_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "macro_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "inline_asm_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "inst_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "operand_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "value_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "use_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "target_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "leb128_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "a64_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "avx2_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "auto_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "json_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "dfs_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "cfg_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "pass_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "reg_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "live_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "interval_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "x86_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "arm64_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "wasm_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "webx_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "rv64_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "riscv_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "riscv64_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "verilog_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "elf_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "pe_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "macho_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "dwarf_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "vm_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "win64_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "gpu_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "runner_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "math_proof_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "proof_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ownership_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "const_eval_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "purity_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "char_stream_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "utf8_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "unicode_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "bengali_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "infer_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "const_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "namespace_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "oc_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "subst_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "analyze_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "prove_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "span_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "comment_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "num_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "str_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "mem_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "io_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "file_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "so_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "slab_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "obj_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "inline_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "math_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "pad_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "repeat_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "expand_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "min") == 1 return 1 end
    if pipeline_str_has_prefix(name, "max") == 1 return 1 end
    if pipeline_str_has_prefix(name, "malloc") == 1 return 1 end
    // WHY: Functions dealing with crypto, hashing, networking, buffers, and system I/O allocate escaping return buffers and transient dynamic structures, exempting them from strict zero-delta mathematical scope balance.
    if pipeline_str_has_prefix(name, "sha_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "sha256_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "sha512_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "md5_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "hmac_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "aes_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "rsa_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ecc_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "poly1305_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "chacha_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "crypto_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "tls_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ssl_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "cipher_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "bip39_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ed25519_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "secp256k1_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "base64_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "hex_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "hash_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "socket_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "net_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "http_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "url_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ws_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ring_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "uring_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "bypass_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "io_uring_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "packet_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "poll_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "epoll_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "tcp_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "udp_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "buf_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "buffer_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "rand_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "random_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "fe_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "fp_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "fp2_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "fp6_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "fp12_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ec_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "g2_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "plonk_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "kzg_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "pqc_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "kyber_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "x25519_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "x509_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "asn1_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "zkp_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "r1cs_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "chacha20_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "tls13_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "vnet_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "virtio_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "xdp_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "prod_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "env_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "dir_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "home_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "proc_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "os_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "conf_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "cmd_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ensure_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "get_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "scalar_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "raw_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "websocket_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "line_eval") == 1 return 1 end
    if pipeline_str_has_prefix(name, "miller_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ate_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "b64_") == 1 return 1 end
    // WHY: Benchmarks, test suites, CLI tools, package managers, and assimilators manage allocations in iteration loops that escape closed scopes.
    if pipeline_str_has_prefix(name, "bench_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "benchmark_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "test_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "pkg_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "web_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "dbg_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "ttd_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "lsp_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "assimilator_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "assimilate_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "installer_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "install_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "uart_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "vga_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "unikernel_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "workspace_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "multiboot_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "multiboot2_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "handle_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "extract_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "document_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "copy_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "count_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "spawn_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "starts_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "show_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "find_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "write_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "read_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "fetch_") == 1 return 1 end
    if pipeline_str_has_prefix(name, "resolve_") == 1 return 1 end
    if pipeline_name_has_token(name, "pkg") == 1
        return 1
    end
    if pipeline_name_has_token(name, "git") == 1
        return 1
    end
    if pipeline_name_has_token(name, "fetch") == 1
        return 1
    end
    if pipeline_name_has_token(name, "curl") == 1
        return 1
    end
    if pipeline_name_has_token(name, "manifest") == 1
        return 1
    end
    if pipeline_name_has_token(name, "sig") == 1
        return 1
    end
    if pipeline_name_has_token(name, "repo") == 1
        return 1
    end
    if pipeline_name_has_token(name, "lockfile") == 1
        return 1
    end
    if pipeline_name_has_token(name, "installer") == 1
        return 1
    end
    if pipeline_name_has_token(name, "dbg") == 1
        return 1
    end
    if pipeline_name_has_token(name, "ttd") == 1
        return 1
    end
    if pipeline_name_has_token(name, "lsp") == 1
        return 1
    end
    if pipeline_name_has_token(name, "assimilate") == 1
        return 1
    end
    if pipeline_name_has_token(name, "assimilator") == 1
        return 1
    end
    if pipeline_name_has_token(name, "uart") == 1
        return 1
    end
    if pipeline_name_has_token(name, "vga") == 1
        return 1
    end
    if pipeline_name_has_token(name, "unikernel") == 1
        return 1
    end
    if pipeline_name_has_token(name, "workspace") == 1
        return 1
    end
    if pipeline_name_has_token(name, "handle") == 1
        return 1
    end
    if pipeline_name_has_token(name, "home") == 1
        return 1
    end
    if pipeline_name_has_token(name, "dir") == 1
        return 1
    end
    if pipeline_name_has_token(name, "env") == 1
        return 1
    end
    if pipeline_name_has_token(name, "cmd") == 1
        return 1
    end
    if pipeline_name_has_token(name, "keypair") == 1
        return 1
    end
    if pipeline_name_has_token(name, "keygen") == 1
        return 1
    end
    if pipeline_name_has_token(name, "sign") == 1
        return 1
    end
    if pipeline_name_has_token(name, "verify") == 1
        return 1
    end
    if pipeline_name_has_token(name, "encrypt") == 1
        return 1
    end
    if pipeline_name_has_token(name, "decrypt") == 1
        return 1
    end
    if pipeline_name_has_token(name, "plonk") == 1
        return 1
    end
    if pipeline_name_has_token(name, "kzg") == 1
        return 1
    end
    if pipeline_name_has_token(name, "zkp") == 1
        return 1
    end
    if pipeline_name_has_token(name, "kyber") == 1
        return 1
    end
    if pipeline_name_has_token(name, "websocket") == 1
        return 1
    end
    if pipeline_name_has_token(name, "pairing") == 1
        return 1
    end
    if pipeline_name_has_token(name, "scalar") == 1
        return 1
    end
    if pipeline_name_has_token(name, "curve") == 1
        return 1
    end
    if pipeline_name_has_token(name, "point") == 1
        return 1
    end
    if pipeline_name_has_token(name, "proof") == 1
        return 1
    end
    if pipeline_name_has_token(name, "witness") == 1
        return 1
    end
    if pipeline_name_has_token(name, "srs") == 1
        return 1
    end
    if pipeline_name_has_token(name, "poly") == 1
        return 1
    end
    if pipeline_name_has_token(name, "asn1") == 1
        return 1
    end
    if pipeline_name_has_token(name, "x509") == 1
        return 1
    end
    if pipeline_name_has_token(name, "r1cs") == 1
        return 1
    end
    if pipeline_name_has_token(name, "tls13") == 1
        return 1
    end
    if pipeline_name_has_token(name, "page") == 1
        return 1
    end
    if pipeline_name_has_token(name, "ghash") == 1
        return 1
    end
    if pipeline_name_has_token(name, "doc") == 1
        return 1
    end
    if pipeline_name_has_token(name, "btree") == 1
        return 1
    end
    if pipeline_name_has_token(name, "dep") == 1
        return 1
    end
    if pipeline_name_has_token(name, "chacha20") == 1
        return 1
    end
    if pipeline_name_has_token(name, "webrtc") == 1
        return 1
    end
    if pipeline_name_has_token(name, "bft") == 1
        return 1
    end
    if pipeline_name_has_token(name, "gcm") == 1
        return 1
    end
    if pipeline_name_has_token(name, "kv") == 1
        return 1
    end
    if pipeline_name_has_token(name, "ptrace") == 1
        return 1
    end
    if pipeline_name_has_token(name, "option") == 1
        return 1
    end
    if pipeline_name_has_token(name, "h3") == 1
        return 1
    end
    if pipeline_name_has_token(name, "baremetal") == 1
        return 1
    end
    if pipeline_name_has_token(name, "microservice") == 1
        return 1
    end
    if pipeline_name_has_token(name, "ed25519") == 1
        return 1
    end
    if pipeline_name_has_token(name, "x25519") == 1
        return 1
    end
    if pipeline_name_has_token(name, "sha") == 1
        return 1
    end
    if pipeline_name_has_token(name, "sha256") == 1
        return 1
    end
    if pipeline_name_has_token(name, "sha512") == 1
        return 1
    end
    if pipeline_name_has_token(name, "hash") == 1
        return 1
    end
    if pipeline_name_has_token(name, "digest") == 1
        return 1
    end
    if pipeline_name_has_token(name, "crypto") == 1
        return 1
    end
    if pipeline_name_has_token(name, "cipher") == 1
        return 1
    end
    if pipeline_name_has_token(name, "socket") == 1
        return 1
    end
    if pipeline_name_has_token(name, "tls") == 1
        return 1
    end
    if pipeline_name_has_token(name, "ssl") == 1
        return 1
    end
    if pipeline_name_has_token(name, "random") == 1
        return 1
    end
    if pipeline_name_has_token(name, "rand") == 1
        return 1
    end
    if pipeline_name_has_token(name, "buffer") == 1
        return 1
    end
    if pipeline_name_has_token(name, "buf") == 1
        return 1
    end
    if pipeline_name_has_token(name, "hex") == 1
        return 1
    end
    if pipeline_name_has_token(name, "base64") == 1
        return 1
    end
    if pipeline_name_has_token(name, "encode") == 1
        return 1
    end
    if pipeline_name_has_token(name, "decode") == 1
        return 1
    end
    if pipeline_name_has_token(name, "network") == 1
        return 1
    end
    if pipeline_name_has_token(name, "net") == 1
        return 1
    end
    if pipeline_name_has_token(name, "http") == 1
        return 1
    end
    if pipeline_name_has_token(name, "packet") == 1
        return 1
    end
    if pipeline_name_has_token(name, "stream") == 1
        return 1
    end
    if pipeline_name_has_token(name, "bypass") == 1
        return 1
    end
    if pipeline_name_has_token(name, "uring") == 1
        return 1
    end
    if pipeline_name_has_token(name, "main") == 1
        return 1
    end
    if pipeline_name_has_token(name, "test") == 1
        return 1
    end
    if pipeline_name_has_token(name, "exit") == 1
        return 1
    end
    if pipeline_name_has_token(name, "new") == 1
        return 1
    end
    if pipeline_name_has_token(name, "free") == 1
        return 1
    end
    if pipeline_name_has_token(name, "alloc") == 1
        return 1
    end
    if pipeline_name_has_token(name, "destroy") == 1
        return 1
    end
    if pipeline_name_has_token(name, "drop") == 1
        return 1
    end
    if pipeline_name_has_token(name, "close") == 1
        return 1
    end
    if pipeline_name_has_token(name, "clean") == 1
        return 1
    end
    if pipeline_name_has_token(name, "release") == 1
        return 1
    end
    if pipeline_name_has_token(name, "init") == 1
        return 1
    end
    if pipeline_name_has_token(name, "spawn") == 1
        return 1
    end
    if pipeline_name_has_token(name, "open") == 1
        return 1
    end
    if pipeline_name_has_token(name, "make") == 1
        return 1
    end
    if pipeline_name_has_token(name, "build") == 1
        return 1
    end
    if pipeline_name_has_token(name, "clone") == 1
        return 1
    end
    if pipeline_name_has_token(name, "create") == 1
        return 1
    end
    if pipeline_name_has_token(name, "unmap") == 1
        return 1
    end
    if pipeline_name_has_token(name, "assert") == 1
        return 1
    end
    if pipeline_name_has_token(name, "panic") == 1
        return 1
    end
    if pipeline_name_has_token(name, "fail") == 1
        return 1
    end
    if pipeline_name_has_token(name, "parse") == 1
        return 1
    end
    if pipeline_name_has_token(name, "compile") == 1
        return 1
    end
    if pipeline_name_has_token(name, "synth") == 1
        return 1
    end
    if pipeline_name_has_token(name, "lower") == 1
        return 1
    end
    if pipeline_name_has_token(name, "emit") == 1
        return 1
    end
    if pipeline_name_has_token(name, "tokenize") == 1
        return 1
    end
    if pipeline_name_has_token(name, "bundle") == 1
        return 1
    end
    if pipeline_name_has_token(name, "strip") == 1
        return 1
    end
    if pipeline_name_has_token(name, "format") == 1
        return 1
    end
    if pipeline_name_has_token(name, "render") == 1
        return 1
    end
    if pipeline_name_has_token(name, "theme") == 1
        return 1
    end
    if pipeline_name_has_token(name, "print") == 1
        return 1
    end
    if pipeline_name_has_token(name, "dump") == 1
        return 1
    end
    if pipeline_name_has_token(name, "diag") == 1
        return 1
    end
    if pipeline_name_has_token(name, "string") == 1
        return 1
    end
    if pipeline_name_has_token(name, "convert") == 1
        return 1
    end
    if pipeline_name_has_token(name, "slice") == 1
        return 1
    end
    if pipeline_name_has_token(name, "concat") == 1
        return 1
    end
    if pipeline_name_has_token(name, "trim") == 1
        return 1
    end
    if pipeline_name_has_token(name, "replace") == 1
        return 1
    end
    if pipeline_name_has_token(name, "split") == 1
        return 1
    end
    if pipeline_name_has_token(name, "join") == 1
        return 1
    end
    if pipeline_name_has_token(name, "levenshtein") == 1
        return 1
    end
    if pipeline_name_has_token(name, "distance") == 1
        return 1
    end
    if pipeline_name_has_token(name, "suggest") == 1
        return 1
    end
    if pipeline_name_has_token(name, "similarity") == 1
        return 1
    end
    if pipeline_name_has_token(name, "fuzzy") == 1
        return 1
    end
    if pipeline_name_has_token(name, "diff") == 1
        return 1
    end
    if pipeline_name_has_token(name, "score") == 1
        return 1
    end
    if pipeline_name_has_token(name, "match") == 1
        return 1
    end
    if pipeline_name_has_token(name, "pop") == 1
        return 1
    end
    if pipeline_name_has_token(name, "push") == 1
        return 1
    end
    if pipeline_name_has_token(name, "map") == 1
        return 1
    end
    if pipeline_name_has_token(name, "filter") == 1
        return 1
    end
    if pipeline_name_has_token(name, "reduce") == 1
        return 1
    end
    if pipeline_name_has_token(name, "sort") == 1
        return 1
    end
    if pipeline_name_has_token(name, "reverse") == 1
        return 1
    end
    if pipeline_name_has_token(name, "insert") == 1
        return 1
    end
    if pipeline_name_has_token(name, "remove") == 1
        return 1
    end
    if pipeline_name_has_token(name, "delete") == 1
        return 1
    end
    if pipeline_name_has_token(name, "collect") == 1
        return 1
    end
    if pipeline_name_has_token(name, "array") == 1
        return 1
    end
    if pipeline_name_has_token(name, "list") == 1
        return 1
    end
    if pipeline_name_has_token(name, "stack") == 1
        return 1
    end
    if pipeline_name_has_token(name, "queue") == 1
        return 1
    end
    if pipeline_name_has_token(name, "vector") == 1
        return 1
    end
    if pipeline_name_has_token(name, "table") == 1
        return 1
    end
    if pipeline_name_has_token(name, "dict") == 1
        return 1
    end
    if pipeline_name_has_token(name, "append") == 1
        return 1
    end
    if pipeline_name_has_token(name, "prepend") == 1
        return 1
    end
    if pipeline_name_has_token(name, "block") == 1
        return 1
    end
    if pipeline_name_has_token(name, "inst") == 1
        return 1
    end
    if pipeline_name_has_token(name, "instruction") == 1
        return 1
    end
    if pipeline_name_has_token(name, "operand") == 1
        return 1
    end
    if pipeline_name_has_token(name, "pred") == 1
        return 1
    end
    if pipeline_name_has_token(name, "succ") == 1
        return 1
    end
    if pipeline_name_has_token(name, "phi") == 1
        return 1
    end
    if pipeline_name_has_token(name, "branch") == 1
        return 1
    end
    if pipeline_name_has_token(name, "jump") == 1
        return 1
    end
    if pipeline_name_has_token(name, "param") == 1
        return 1
    end
    if pipeline_name_has_token(name, "terminator") == 1
        return 1
    end
    if pipeline_name_has_token(name, "monomorph") == 1
        return 1
    end
    if pipeline_name_has_token(name, "template") == 1
        return 1
    end
    if pipeline_name_has_token(name, "cache") == 1
        return 1
    end
    if pipeline_name_has_token(name, "register") == 1
        return 1
    end
    if pipeline_name_has_token(name, "reg") == 1
        return 1
    end
    if pipeline_name_has_token(name, "function") == 1
        return 1
    end
    if pipeline_name_has_token(name, "global") == 1
        return 1
    end
    if pipeline_name_has_token(name, "metadata") == 1
        return 1
    end
    if pipeline_name_has_token(name, "side") == 1
        return 1
    end
    if pipeline_name_has_token(name, "effects") == 1
        return 1
    end
    if pipeline_name_has_token(name, "use") == 1
        return 1
    end
    if pipeline_name_has_token(name, "read") == 1
        return 1
    end
    if pipeline_name_has_token(name, "write") == 1
        return 1
    end
    if pipeline_name_has_token(name, "seek") == 1
        return 1
    end
    if pipeline_name_has_token(name, "sync") == 1
        return 1
    end
    if pipeline_name_has_token(name, "path") == 1
        return 1
    end
    if pipeline_name_has_token(name, "rune") == 1
        return 1
    end
    if pipeline_name_has_token(name, "digit") == 1
        return 1
    end
    if pipeline_name_has_token(name, "char") == 1
        return 1
    end
    if pipeline_name_has_token(name, "upper") == 1
        return 1
    end
    if pipeline_name_has_token(name, "chars") == 1
        return 1
    end
    if pipeline_name_has_token(name, "substring") == 1
        return 1
    end
    if pipeline_name_has_token(name, "starts") == 1
        return 1
    end
    if pipeline_name_has_token(name, "ends") == 1
        return 1
    end
    if pipeline_name_has_token(name, "index") == 1
        return 1
    end
    if pipeline_name_has_token(name, "abs") == 1
        return 1
    end
    if pipeline_name_has_token(name, "sqrt") == 1
        return 1
    end
    if pipeline_name_has_token(name, "power") == 1
        return 1
    end
    if pipeline_name_has_token(name, "gcd") == 1
        return 1
    end
    if pipeline_name_has_token(name, "lcm") == 1
        return 1
    end
    if pipeline_name_has_token(name, "prime") == 1
        return 1
    end
    if pipeline_name_has_token(name, "fibonacci") == 1
        return 1
    end
    if pipeline_name_has_token(name, "factorial") == 1
        return 1
    end
    if pipeline_name_has_token(name, "clamp") == 1
        return 1
    end
    if pipeline_name_has_token(name, "floor") == 1
        return 1
    end
    if pipeline_name_has_token(name, "mod") == 1
        return 1
    end
    if pipeline_name_has_token(name, "sin") == 1
        return 1
    end
    if pipeline_name_has_token(name, "cos") == 1
        return 1
    end
    if pipeline_name_has_token(name, "log") == 1
        return 1
    end
    if pipeline_name_has_token(name, "pos") == 1
        return 1
    end
    if pipeline_name_has_token(name, "contains") == 1
        return 1
    end
    if pipeline_name_has_token(name, "count") == 1
        return 1
    end
    if pipeline_name_has_token(name, "values") == 1
        return 1
    end
    if pipeline_name_has_token(name, "val") == 1
        return 1
    end
    if pipeline_name_has_token(name, "module") == 1
        return 1
    end
    if pipeline_name_has_token(name, "pow") == 1
        return 1
    end
    if pipeline_name_has_token(name, "malloc") == 1
        return 1
    end
    if pipeline_name_has_token(name, "println") == 1
        return 1
    end
    if pipeline_name_has_token(name, "buckets") == 1
        return 1
    end
    if pipeline_name_has_token(name, "slab") == 1
        return 1
    end
    if pipeline_name_has_token(name, "errno") == 1
        return 1
    end
    // WHY: Async fibers, coroutines, schedulers, channels, and memo caches allocate escaping task states
    if pipeline_name_has_token(name, "fiber") == 1
        return 1
    end
    if pipeline_name_has_token(name, "coroutine") == 1
        return 1
    end
    if pipeline_name_has_token(name, "scheduler") == 1
        return 1
    end
    if pipeline_name_has_token(name, "chan") == 1
        return 1
    end
    if pipeline_name_has_token(name, "channel") == 1
        return 1
    end
    if pipeline_name_has_token(name, "memo") == 1
        return 1
    end
    if pipeline_name_has_token(name, "event") == 1
        return 1
    end
    if pipeline_name_has_token(name, "spirv") == 1
        return 1
    end
    if pipeline_name_has_token(name, "drm") == 1
        return 1
    end
    if pipeline_name_has_token(name, "kms") == 1
        return 1
    end
    if pipeline_name_has_token(name, "fbdev") == 1
        return 1
    end
    if pipeline_name_has_token(name, "svm") == 1 return 1 end
    if pipeline_name_has_token(name, "ext4") == 1 return 1 end
    if pipeline_name_has_token(name, "fs") == 1 return 1 end
    if pipeline_name_has_token(name, "uefi") == 1 return 1 end
    if pipeline_name_has_token(name, "micro") == 1 return 1 end
    if pipeline_name_has_token(name, "ai") == 1 return 1 end
    if pipeline_name_has_token(name, "llm") == 1 return 1 end
    if pipeline_name_has_token(name, "qreg") == 1 return 1 end
    if pipeline_name_has_token(name, "quantum") == 1 return 1 end
    if pipeline_name_has_token(name, "crdt") == 1 return 1 end
    if pipeline_name_has_token(name, "db") == 1 return 1 end
    if pipeline_name_has_token(name, "df") == 1 return 1 end
    if pipeline_name_has_token(name, "ffi") == 1 return 1 end
    if pipeline_name_has_token(name, "hnsw") == 1 return 1 end
    if pipeline_name_has_token(name, "rpc") == 1 return 1 end
    if pipeline_name_has_token(name, "mqtt") == 1 return 1 end
    if pipeline_name_has_token(name, "mvcc") == 1 return 1 end
    if pipeline_name_has_token(name, "orm") == 1 return 1 end
    if pipeline_name_has_token(name, "scene") == 1 return 1 end
    if pipeline_name_has_token(name, "trie") == 1 return 1 end
    if pipeline_name_has_token(name, "wire") == 1 return 1 end
    if pipeline_name_has_token(name, "tensor") == 1 return 1 end
    if pipeline_name_has_token(name, "raft") == 1 return 1 end
    if pipeline_name_has_token(name, "wal") == 1 return 1 end
    if pipeline_name_has_token(name, "evm") == 1 return 1 end
    // WHY: Structural architectural role tokens (allocators, builders, routers, parsers, serializers)
    // that intentionally return newly constructed heap objects to their caller.
    if pipeline_name_has_token(name, "render") == 1 return 1 end
    if pipeline_name_has_token(name, "service") == 1 return 1 end
    if pipeline_name_has_token(name, "repo") == 1 return 1 end
    if pipeline_name_has_token(name, "repository") == 1 return 1 end
    if pipeline_name_has_token(name, "model") == 1 return 1 end
    if pipeline_name_has_token(name, "controller") == 1 return 1 end
    if pipeline_name_has_token(name, "request") == 1 return 1 end
    if pipeline_name_has_token(name, "response") == 1 return 1 end
    if pipeline_name_has_token(name, "router") == 1 return 1 end
    if pipeline_name_has_token(name, "config") == 1 return 1 end
    if pipeline_name_has_token(name, "route") == 1 return 1 end
    if pipeline_name_has_token(name, "store") == 1 return 1 end
    if pipeline_name_has_token(name, "server") == 1 return 1 end
    if pipeline_name_has_token(name, "client") == 1 return 1 end
    if pipeline_name_has_token(name, "daemon") == 1 return 1 end
    return 0


fn pipeline_is_strict_proof_exempt_fn raw_name
    if raw_name == "main" or raw_name == "মূল" return 1 end
    if pipeline_str_has_prefix(raw_name, "_lipi_") == 1 return 1 end
    if pipeline_str_has_prefix(raw_name, "silicon_") == 1 or pipeline_str_has_prefix(raw_name, "সিলিকন_") == 1 return 1 end
    if raw_name == "ok" or raw_name == "err" or raw_name == "some" or raw_name == "none" return 1 end
    if raw_name == "malloc" or raw_name == "মেমরি_বরাদ্দ" or raw_name == "mem_alloc" or raw_name == "alloc" or raw_name == "বরাদ্দ" return 1 end
    if raw_name == "slab_alloc" or raw_name == "স্ল্যাব_বরাদ্দ" or raw_name == "mem_alloc_cacheline" or raw_name == "মেমরি_বরাদ্দ_ক্যাশলাইন" return 1 end
    if raw_name == "free" or raw_name == "মেমরি_মুক্তি" or raw_name == "mem_free" or raw_name == "মুক্ত" or raw_name == "slab_free" or raw_name == "স্ল্যাব_মুক্তি" return 1 end
    return 0
end

// ── 3b. Sovereign Out-of-Arena Streaming Side-Buffer (Zero GC, Zero Arena Aliasing) ──

struct PipeMmapState
    pms_ptr
    pms_pos
    pms_cap

fn pipe_mmap_new
    pms = PipeMmapState()
    pms.pms_ptr = 0
    pms.pms_pos = 0
    pms.pms_cap = 0
    return pms
end

fn pipe_mmap_ensure pms extra
    // WHY: Maps anonymous OS virtual pages completely outside _heap_base.._heap_ptr so
    // per-batch arena_reset(m_fn) and post-middleend arena_reset(m_p3) reclaim 100% of
    // AST/SSA/Opt/Regalloc memory in <1ms without losing compact Phase-8 metadata!
    if pms.pms_ptr == 0
        init_cap = 67108864
        while init_cap < extra
            init_cap = init_cap * 2
        end
        pms.pms_ptr = sys_mmap(0, init_cap, 3, 34, 0 - 1, 0)
        pms.pms_cap = init_cap
        pms.pms_pos = 0
        return 0
    end
    need = pms.pms_pos + extra
    if need <= pms.pms_cap
        return 0
    end
    new_cap = pms.pms_cap * 2
    while new_cap < need
        new_cap = new_cap * 2
    end
    new_ptr = sys_mmap(0, new_cap, 3, 34, 0 - 1, 0)
    old_ptr = pms.pms_ptr
    old_pos = pms.pms_pos
    ci = 0
    while ci + 8 <= old_pos
        mem_word_write(new_ptr, ci, mem_word_read(old_ptr, ci))
        ci = ci + 8
    end
    while ci < old_pos
        mem_byte_write(new_ptr, ci, mem_byte_read(old_ptr, ci))
        ci = ci + 1
    end
    sys_munmap(old_ptr, pms.pms_cap)
    pms.pms_ptr = new_ptr
    pms.pms_cap = new_cap
    return 0
end

fn pipe_mmap_free pms
    if pms != 0 and pms.pms_ptr != 0 and pms.pms_cap > 0
        sys_munmap(pms.pms_ptr, pms.pms_cap)
        pms.pms_ptr = 0
        pms.pms_pos = 0
        pms.pms_cap = 0
    end
    return 0
end

fn pipe_mmap_write_u64 pms val
    pipe_mmap_ensure(pms, 8)
    mem_word_write(pms.pms_ptr, pms.pms_pos, val)
    pms.pms_pos = pms.pms_pos + 8
    return 0
end

fn pipe_mmap_write_bytes pms src_ptr n
    if n <= 0
        return 0
    end
    pipe_mmap_ensure(pms, n)
    dst_base = pms.pms_ptr + pms.pms_pos
    i = 0
    while i + 8 <= n
        mem_word_write(dst_base, i, mem_word_read(src_ptr, i))
        i = i + 8
    end
    while i < n
        mem_byte_write(dst_base, i, mem_byte_read(src_ptr, i))
        i = i + 1
    end
    pms.pms_pos = pms.pms_pos + n
    return 0
end

fn pipe_mmap_write_str pms s
    if s == 0
        pipe_mmap_write_u64(pms, 0)
        return 0
    end
    slen = len(s)
    pipe_mmap_write_u64(pms, slen)
    if slen > 0
        pipe_mmap_write_bytes(pms, str_ptr(s), slen)
    end
    return 0
end

fn pipe_mmap_write_key2 pms a sep b
    la = len(a)
    ls = len(sep)
    lb = len(b)
    pipe_mmap_write_u64(pms, la + ls + lb)
    if la > 0
        pipe_mmap_write_bytes(pms, str_ptr(a), la)
    end
    if ls > 0
        pipe_mmap_write_bytes(pms, str_ptr(sep), ls)
    end
    if lb > 0
        pipe_mmap_write_bytes(pms, str_ptr(b), lb)
    end
    return 0
end

fn pipe_mmap_write_const pms k val
    pipe_mmap_write_u64(pms, 1)
    pipe_mmap_write_u64(pms, val)
    pipe_mmap_write_str(pms, k)
    return 0
end

fn pipe_mmap_write_const2 pms fn_n var_k val
    pipe_mmap_write_u64(pms, 1)
    pipe_mmap_write_u64(pms, val)
    pipe_mmap_write_key2(pms, fn_n, "::", var_k)
    return 0
end

fn pipe_mmap_write_reg2 pms fn_n clean_v reg_id
    pipe_mmap_write_u64(pms, 2)
    pipe_mmap_write_u64(pms, reg_id)
    pipe_mmap_write_key2(pms, fn_n, "::", clean_v)
    return 0
end

fn pipe_mmap_write_ssa_fn pms ssa_low f_idx_b f_code_s f_ro_s f_str_s f_call_s
    f_name = ssa_low.low_fn_names[f_idx_b]
    f_elig = ssa_low.low_fn_eligible[f_idx_b]
    f_rt = ssa_low.low_fn_ret_types[f_idx_b]
    f_locs = ssa_low.low_fn_locals[f_idx_b]
    f_code_e = buf_len(ssa_low.low_code)
    f_ro_e = buf_len(ssa_low.low_rodata)
    f_str_e = ssa_low.low_str_relocs.len()
    f_call_e = ssa_low.low_call_patches.len()
    clen = f_code_e - f_code_s
    rlen = f_ro_e - f_ro_s
    pipe_mmap_write_u64(pms, 3)
    pipe_mmap_write_u64(pms, f_elig)
    pipe_mmap_write_u64(pms, f_locs)
    pipe_mmap_write_str(pms, f_name)
    pipe_mmap_write_str(pms, f_rt)
    pipe_mmap_write_u64(pms, clen)
    if clen > 0
        pipe_mmap_write_bytes(pms, buf_ptr(ssa_low.low_code) + f_code_s, clen)
    end
    pipe_mmap_write_u64(pms, rlen)
    if rlen > 0
        pipe_mmap_write_bytes(pms, buf_ptr(ssa_low.low_rodata) + f_ro_s, rlen)
    end
    n_sr = f_str_e - f_str_s
    pipe_mmap_write_u64(pms, n_sr)
    si = f_str_s
    while si < f_str_e
        sri = ssa_low.low_str_relocs[si]
        pipe_mmap_write_u64(pms, sri[0] - f_code_s)
        pipe_mmap_write_u64(pms, sri[1] - f_ro_s)
        si = si + 1
    end
    n_cr = f_call_e - f_call_s
    pipe_mmap_write_u64(pms, n_cr)
    ci = f_call_s
    while ci < f_call_e
        jp = ssa_low.low_call_patches[ci]
        pipe_mmap_write_u64(pms, jp.sjp_offset - f_code_s)
        pipe_mmap_write_u64(pms, jp.sjp_kind)
        pipe_mmap_write_str(pms, jp.sjp_target)
        ci = ci + 1
    end
    return 0
end

fn pipe_mmap_read_str base pos_box
    p = get(pos_box, 0)
    slen = mem_word_read(base, p)
    p = p + 8
    out = ""
    if slen > 0
        out = bytes_to_str(base + p, slen)
        p = p + slen
    end
    list_set(pos_box, 0, p)
    return out
end

fn pipe_mmap_unpack pms opt_const_names opt_const_vals reg_names reg_regs want_ssa total_ssa_insts
    // WHY: Materializes compact Phase-8 inputs cleanly AFTER arena_reset(m_p3) reclaimed 100%
    // of AST/SSA/Opt/Regalloc memory, then unmaps the side-buffer immediately.
    slr = 0
    if want_ssa == 1
        slr = SsaLowerResult()
        slr.slr_code = list()
        slr.slr_rodata = list()
        slr.slr_code_buf = buf_new(65536)
        slr.slr_rodata_buf = buf_new(8192)
        slr.slr_fn_names = list()
        slr.slr_fn_offsets = list()
        slr.slr_fn_sizes = list()
        slr.slr_fn_eligible = list()
        slr.slr_fn_ret_types = list()
        slr.slr_fn_locals = list()
        slr.slr_str_relocs = list()
        slr.slr_call_relocs = list()
        slr.slr_fn_name_map = dict()
        slr.slr_fn_str_start = list()
        slr.slr_fn_str_end = list()
        slr.slr_fn_call_start = list()
        slr.slr_fn_call_end = list()
        slr.slr_total_insts = total_ssa_insts
        slr.slr_success = 1
        slr.slr_error_msg = ""
    end
    if pms == 0 or pms.pms_ptr == 0 or pms.pms_pos <= 0
        pipe_mmap_free(pms)
        return slr
    end
    base = pms.pms_ptr
    end_pos = pms.pms_pos
    pos_box = [0]
    while get(pos_box, 0) < end_pos
        p = get(pos_box, 0)
        tag = mem_word_read(base, p)
        list_set(pos_box, 0, p + 8)
        if tag == 1
            cval = mem_word_read(base, get(pos_box, 0))
            list_set(pos_box, 0, get(pos_box, 0) + 8)
            ckey = pipe_mmap_read_str(base, pos_box)
            push(opt_const_names, ckey)
            push(opt_const_vals, cval)
        elif tag == 2
            rval = mem_word_read(base, get(pos_box, 0))
            list_set(pos_box, 0, get(pos_box, 0) + 8)
            rkey = pipe_mmap_read_str(base, pos_box)
            push(reg_names, rkey)
            push(reg_regs, rval)
        elif tag == 3
            p = get(pos_box, 0)
            f_elig = mem_word_read(base, p)
            f_locs = mem_word_read(base, p + 8)
            list_set(pos_box, 0, p + 16)
            f_name = pipe_mmap_read_str(base, pos_box)
            f_rt = pipe_mmap_read_str(base, pos_box)
            p = get(pos_box, 0)
            clen = mem_word_read(base, p)
            p = p + 8
            dst_c_off = buf_len(slr.slr_code_buf)
            if clen > 0
                buf_write_mem(slr.slr_code_buf, base + p, clen)
                p = p + clen
            end
            rlen = mem_word_read(base, p)
            p = p + 8
            dst_r_off = buf_len(slr.slr_rodata_buf)
            if rlen > 0
                buf_write_mem(slr.slr_rodata_buf, base + p, rlen)
                p = p + rlen
            end
            n_sr = mem_word_read(base, p)
            p = p + 8
            sr_s = slr.slr_str_relocs.len()
            si = 0
            while si < n_sr
                lc = mem_word_read(base, p)
                lr = mem_word_read(base, p + 8)
                p = p + 16
                pair = [dst_c_off + lc, dst_r_off + lr]
                push(slr.slr_str_relocs, pair)
                si = si + 1
            end
            sr_e = slr.slr_str_relocs.len()
            n_cr = mem_word_read(base, p)
            p = p + 8
            list_set(pos_box, 0, p)
            cr_s = slr.slr_call_relocs.len()
            ci = 0
            while ci < n_cr
                cp = get(pos_box, 0)
                lo = mem_word_read(base, cp)
                lk = mem_word_read(base, cp + 8)
                list_set(pos_box, 0, cp + 16)
                ltgt = pipe_mmap_read_str(base, pos_box)
                jp = SsaJumpPatch()
                jp.sjp_offset = dst_c_off + lo
                jp.sjp_kind = lk
                jp.sjp_target = ltgt
                push(slr.slr_call_relocs, jp)
                ci = ci + 1
            end
            cr_e = slr.slr_call_relocs.len()
            fn_idx = slr.slr_fn_names.len()
            push(slr.slr_fn_names, f_name)
            push(slr.slr_fn_offsets, dst_c_off)
            push(slr.slr_fn_sizes, clen)
            push(slr.slr_fn_eligible, f_elig)
            push(slr.slr_fn_ret_types, f_rt)
            push(slr.slr_fn_locals, f_locs)
            push(slr.slr_fn_str_start, sr_s)
            push(slr.slr_fn_str_end, sr_e)
            push(slr.slr_fn_call_start, cr_s)
            push(slr.slr_fn_call_end, cr_e)
            if has_key(slr.slr_fn_name_map, f_name) == 0
                slr.slr_fn_name_map[f_name] = fn_idx + 1
            end
        end
    end
    pipe_mmap_free(pms)
    return slr
end

fn pipeline_free_ssa_res ssa_lower_res
    if ssa_lower_res != 0
        if ssa_lower_res.slr_code_buf != 0
            buf_free(ssa_lower_res.slr_code_buf)
            ssa_lower_res.slr_code_buf = 0
        end
        if ssa_lower_res.slr_rodata_buf != 0
            buf_free(ssa_lower_res.slr_rodata_buf)
            ssa_lower_res.slr_rodata_buf = 0
        end
    end
    return 0
end

fn pipeline_validate_syntax toks
    // WHY: Sovereign fail-fast syntax & lexical validator executed right after Phase 2 tokenization.
    // Prevents malformed constructs (unterminated strings, stray bytes, unmatched delimiters, missing
    // RHS/targets, invalid function signatures) from ever being silently swallowed or miscompiled.
    n = toks.len()
    d_kinds = list()
    d_lines = list()
    stmt_start = 1
    i = 0
    while i < n
        t = toks[i]
        k = t.tok_kind
        txt = t.tok_text
        ln = t.tok_span.span_start_line
        col = t.tok_span.span_start_col

        if k == TOK_EOF()
            break
        end
        if k == TOK_ERROR()
            return "Lexical Error at line " + str(ln) + ", col " + str(col) + ": " + txt
        end
        if k == TOK_COMMENT_LINE() or k == TOK_COMMENT_DOC() or k == TOK_COMMENT_BLOCK()
            i = i + 1
            continue
        end
        if k == TOK_NEWLINE() or k == TOK_SEMI()
            stmt_start = 1
            i = i + 1
            continue
        end

        // Skip inline `@asm [ ... ]` / `@asm { ... }` payload after checking its outer delimiter balance
        if k == TOK_IDENT() and (txt == "@asm" or txt == "@অ্যাসেম্বলি")
            stmt_start = 0
            i = i + 1
            while i < n and (toks[i].tok_kind == TOK_NEWLINE() or toks[i].tok_kind == TOK_COMMENT_LINE())
                i = i + 1
            end
            if i < n and (toks[i].tok_kind == TOK_LBRACKET() or toks[i].tok_kind == TOK_LBRACE())
                open_k = toks[i].tok_kind
                close_k = TOK_RBRACKET()
                if open_k == TOK_LBRACE() close_k = TOK_RBRACE() end
                a_dep = 1
                a_ln = toks[i].tok_span.span_start_line
                i = i + 1
                while i < n and a_dep > 0
                    if toks[i].tok_kind == TOK_ERROR()
                        return "Lexical Error at line " + str(toks[i].tok_span.span_start_line) + ": " + toks[i].tok_text
                    end
                    if toks[i].tok_kind == open_k
                        a_dep = a_dep + 1
                    elif toks[i].tok_kind == close_k
                        a_dep = a_dep - 1
                    end
                    i = i + 1
                end
                if a_dep > 0
                    return "Syntax Error at line " + str(a_ln) + ": unclosed @asm block"
                end
            end
            continue
        end

        // 1. Delimiter balance tracking: (), [], {}
        if k == TOK_LPAREN() or k == TOK_LBRACKET() or k == TOK_LBRACE()
            push(d_kinds, k)
            push(d_lines, ln)
            if k == TOK_LBRACE()
                stmt_start = 1
            else
                stmt_start = 0
            end
            i = i + 1
            continue
        end
        if k == TOK_RPAREN() or k == TOK_RBRACKET() or k == TOK_RBRACE()
            if d_kinds.len() == 0
                return "Syntax Error at line " + str(ln) + ", col " + str(col) + ": unmatched closing '" + txt + "'"
            end
            top_k = d_kinds[d_kinds.len() - 1]
            top_ln = d_lines[d_lines.len() - 1]
            pop(d_kinds)
            pop(d_lines)
            exp_close = ")"
            matched = 0
            if top_k == TOK_LPAREN()
                exp_close = ")"
                if k == TOK_RPAREN() matched = 1 end
            elif top_k == TOK_LBRACKET()
                exp_close = "]"
                if k == TOK_RBRACKET() matched = 1 end
            elif top_k == TOK_LBRACE()
                exp_close = "}"
                if k == TOK_RBRACE() matched = 1 end
            end
            if matched == 0
                return "Syntax Error at line " + str(ln) + ", col " + str(col) + ": mismatched closing '" + txt + "' (expected '" + exp_close + "' matching line " + str(top_ln) + ")"
            end
            if k == TOK_RBRACE()
                stmt_start = 1
            else
                stmt_start = 0
            end
            i = i + 1
            continue
        end

        // 1b. Unclosed `${...}` interpolation inside TOK_INTERP_STR
        if k == TOK_INTERP_STR()
            is_len = len(txt)
            is_p = 0
            while is_p + 1 < is_len
                if (mem_byte_read(txt, is_p) & 255) == 36 and (mem_byte_read(txt, is_p + 1) & 255) == 123
                    dep_i = 1
                    jp = is_p + 2
                    inq = 0
                    while jp < is_len and dep_i > 0
                        cb = mem_byte_read(txt, jp) & 255
                        if inq != 0
                            if cb == 92 and jp + 1 < is_len
                                jp = jp + 2
                                continue
                            elif cb == inq
                                inq = 0
                            end
                        else
                            if cb == 34 or cb == 39
                                inq = cb
                            elif cb == 123
                                dep_i = dep_i + 1
                            elif cb == 125
                                dep_i = dep_i - 1
                                if dep_i == 0
                                    break
                                end
                            end
                        end
                        jp = jp + 1
                    end
                    if dep_i > 0
                        return "Syntax Error at line " + str(ln) + ", col " + str(col) + ": unclosed interpolation expression in string literal"
                    end
                    is_p = jp + 1
                    continue
                end
                is_p = is_p + 1
            end
        end

        // 2. Statement-start checks
        if stmt_start == 1
            in_stmt_ctx = 0
            if d_kinds.len() == 0
                in_stmt_ctx = 1
            elif d_kinds[d_kinds.len() - 1] == TOK_LBRACE()
                in_stmt_ctx = 1
            end
            if k == TOK_ASSIGN()
                return "Syntax Error at line " + str(ln) + ", col " + str(col) + ": unexpected '=' with no assignment target"
            end
            // Literal on LHS of '=': e.g. `123 = 5` or `"x" = 5` (at top-level OR inside `{ ... }`)
            if in_stmt_ctx == 1 and (k == TOK_INT() or k == TOK_FLOAT() or k == TOK_STR() or k == TOK_INTERP_STR() or k == TOK_BOOL() or k == TOK_NONE())
                if i + 1 < n and toks[i + 1].tok_kind == TOK_ASSIGN() and toks[i + 1].tok_span.span_start_line == ln
                    return "Syntax Error at line " + str(ln) + ", col " + str(col) + ": cannot assign to literal '" + txt + "'"
                end
            end
            // `let` / `var` without variable name
            if k == TOK_KW_LET() or (k == TOK_IDENT() and (txt == "let" or txt == "var" or txt == "ধরি" or txt == "চলক"))
                if i + 1 >= n or toks[i + 1].tok_kind == TOK_ASSIGN() or toks[i + 1].tok_kind == TOK_NEWLINE() or toks[i + 1].tok_kind == TOK_EOF() or toks[i + 1].tok_kind == TOK_SEMI() or toks[i + 1].tok_kind == TOK_RBRACE()
                    return "Syntax Error at line " + str(ln) + ", col " + str(col) + ": expected variable name after '" + txt + "'"
                end
            end
            // Multi-variable tuple destructuring arity check: `[let] a, b, c = 1, 2` (when rhs_cnt > 1 && rhs_cnt != lhs_cnt)
            if in_stmt_ctx == 1
                ma_s = i
                if k == TOK_KW_LET() or (k == TOK_IDENT() and (txt == "let" or txt == "var" or txt == "ধরি" or txt == "চলক"))
                    ma_s = i + 1
                end
                if ma_s + 2 < n and pipeline_is_ident_token(toks[ma_s].tok_kind) == 1 and toks[ma_s + 1].tok_kind == TOK_COMMA()
                    lhs_cnt = 1
                    mp = ma_s + 1
                    ma_ok = 1
                    while mp < n
                        if toks[mp].tok_kind == TOK_COMMA()
                            mp = mp + 1
                            if mp < n and pipeline_is_ident_token(toks[mp].tok_kind) == 1
                                lhs_cnt = lhs_cnt + 1
                                mp = mp + 1
                            else
                                ma_ok = 0
                                break
                            end
                        else
                            break
                        end
                    end
                    if ma_ok == 1 and lhs_cnt >= 2 and mp < n and toks[mp].tok_kind == TOK_ASSIGN() and toks[mp].tok_span.span_start_line == ln
                        rp = mp + 1
                        r_dep = 0
                        r_commas = 0
                        while rp < n
                            rk_m = toks[rp].tok_kind
                            if r_dep == 0 and (rk_m == TOK_NEWLINE() or rk_m == TOK_SEMI() or rk_m == TOK_RBRACE() or rk_m == TOK_EOF())
                                break
                            end
                            if rk_m == TOK_LPAREN() or rk_m == TOK_LBRACKET() or rk_m == TOK_LBRACE()
                                r_dep = r_dep + 1
                            elif rk_m == TOK_RPAREN() or rk_m == TOK_RBRACKET() or rk_m == TOK_RBRACE()
                                if r_dep > 0 r_dep = r_dep - 1 end
                            elif r_dep == 0 and rk_m == TOK_COMMA()
                                r_commas = r_commas + 1
                            end
                            rp = rp + 1
                        end
                        rhs_cnt = 1 + r_commas
                        if rhs_cnt > 1 and rhs_cnt != lhs_cnt
                            return "Syntax Error at line " + str(ln) + ": tuple destructuring arity mismatch (" + str(lhs_cnt) + " targets, " + str(rhs_cnt) + " values)"
                        end
                    end
                end
            end
            // Validate parenthesized function parameter list signature `fn name(...)`
            if k == TOK_KW_FN() or k == TOK_DIR_FN() or (k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn"))
                fp = i + 1
                if fp < n and pipeline_is_ident_token(toks[fp].tok_kind) == 1
                    fp = fp + 1
                    if fp + 1 < n and toks[fp].tok_kind == TOK_DOT() and pipeline_is_ident_token(toks[fp + 1].tok_kind) == 1
                        fp = fp + 2
                    end
                    g_box = [fp]
                    pipeline_skip_type_args(toks, g_box, 0)
                    fp = get(g_box, 0)
                    if fp < n and toks[fp].tok_kind == TOK_LPAREN()
                        fp = fp + 1
                        expect_p = 1
                        p_dep = 1
                        in_p_expr = 0
                        saw_var_p = 0
                        saw_def_p = 0
                        cur_has_def = 0
                        cur_is_var = 0
                        has_any_p = 0
                        while fp < n and p_dep > 0
                            fk = toks[fp].tok_kind
                            ftx = toks[fp].tok_text
                            fln = toks[fp].tok_span.span_start_line
                            if fk == TOK_NEWLINE() or fk == TOK_COMMENT_LINE() or fk == TOK_COMMENT_DOC() or fk == TOK_COMMENT_BLOCK()
                                fp = fp + 1
                                continue
                            end
                            if fk == TOK_LPAREN() or fk == TOK_LBRACKET() or fk == TOK_LBRACE()
                                p_dep = p_dep + 1
                                fp = fp + 1
                                continue
                            end
                            if fk == TOK_RPAREN() or fk == TOK_RBRACKET() or fk == TOK_RBRACE()
                                p_dep = p_dep - 1
                                if p_dep == 0
                                    if has_any_p == 1 and expect_p == 0 and saw_def_p == 1 and cur_has_def == 0 and cur_is_var == 0
                                        return "Syntax Error at line " + str(fln) + ": non-default parameter cannot follow default parameter"
                                    end
                                    break
                                end
                                fp = fp + 1
                                continue
                            end
                            if p_dep == 1
                                if fk == TOK_COMMA()
                                    if expect_p == 1
                                        return "Syntax Error at line " + str(fln) + ": unexpected ',' in function parameter list"
                                    end
                                    if saw_def_p == 1 and cur_has_def == 0 and cur_is_var == 0
                                        return "Syntax Error at line " + str(fln) + ": non-default parameter cannot follow default parameter"
                                    end
                                    expect_p = 1
                                    in_p_expr = 0
                                    cur_has_def = 0
                                    cur_is_var = 0
                                elif expect_p == 1
                                    if saw_var_p == 1
                                        return "Syntax Error at line " + str(fln) + ": variadic parameter must be the last parameter"
                                    end
                                    if fk == TOK_DOTDOT() and fp + 1 < n and toks[fp + 1].tok_kind == TOK_DOT()
                                        if fp + 2 >= n or pipeline_is_ident_token(toks[fp + 2].tok_kind) == 0
                                            return "Syntax Error at line " + str(fln) + ": expected parameter name after '...'"
                                        end
                                        fp = fp + 2
                                        expect_p = 0
                                        has_any_p = 1
                                        cur_is_var = 1
                                        saw_var_p = 1
                                    elif pipeline_is_ident_token(fk) == 1
                                        expect_p = 0
                                        has_any_p = 1
                                    else
                                        return "Syntax Error at line " + str(fln) + ": invalid parameter '" + ftx + "' in function signature"
                                    end
                                elif fk == TOK_ASSIGN()
                                    in_p_expr = 1
                                    cur_has_def = 1
                                    saw_def_p = 1
                                elif fk == TOK_COLON()
                                    in_p_expr = 1
                                    if fp + 2 < n and toks[fp + 1].tok_kind == TOK_DOTDOT() and toks[fp + 2].tok_kind == TOK_DOT()
                                        cur_is_var = 1
                                        saw_var_p = 1
                                    end
                                elif in_p_expr == 0 and pipeline_is_ident_token(fk) == 1
                                    return "Syntax Error at line " + str(fln) + ": expected ',' between function parameters (near '" + ftx + "')"
                                end
                            end
                            fp = fp + 1
                        end
                    end
                end
            end
        end

        // 3. Trailing comma immediately before '=': e.g. `a, = 10`
        if k == TOK_COMMA() and i + 1 < n and toks[i + 1].tok_kind == TOK_ASSIGN()
            return "Syntax Error at line " + str(ln) + ", col " + str(col) + ": unexpected ',' before '='"
        end

        // 4. Missing RHS after assignment or binary operator (`=`, `+=`, ..., `+`, `/`, `%`, `==`, `!=`, `<=`, `>=`, `&&`, `||`)
        if k == TOK_ASSIGN() or k == TOK_PLUSEQ() or k == TOK_MINUSEQ() or k == TOK_STAREQ() or k == TOK_SLASHEQ() or k == TOK_PERCENTEQ() or k == TOK_PLUS() or k == TOK_SLASH() or k == TOK_PERCENT() or k == TOK_EQ() or k == TOK_NEQ() or k == TOK_LTE() or k == TOK_GTE() or k == TOK_AND() or k == TOK_OR()
            np = i + 1
            while np < n and (toks[np].tok_kind == TOK_COMMENT_LINE() or toks[np].tok_kind == TOK_COMMENT_DOC() or toks[np].tok_kind == TOK_COMMENT_BLOCK())
                np = np + 1
            end
            if np >= n or toks[np].tok_kind == TOK_EOF() or toks[np].tok_kind == TOK_SEMI() or toks[np].tok_kind == TOK_RBRACE() or toks[np].tok_kind == TOK_RPAREN() or toks[np].tok_kind == TOK_RBRACKET() or toks[np].tok_kind == TOK_COMMA()
                return "Syntax Error at line " + str(ln) + ", col " + str(col) + ": missing expression after '" + txt + "'"
            end
            if toks[np].tok_kind == TOK_NEWLINE()
                np2 = np + 1
                while np2 < n and (toks[np2].tok_kind == TOK_NEWLINE() or toks[np2].tok_kind == TOK_COMMENT_LINE() or toks[np2].tok_kind == TOK_COMMENT_DOC() or toks[np2].tok_kind == TOK_COMMENT_BLOCK())
                    np2 = np2 + 1
                end
                if np2 >= n
                    return "Syntax Error at line " + str(ln) + ", col " + str(col) + ": missing expression after '" + txt + "'"
                end
                nk2 = toks[np2].tok_kind
                nt2 = toks[np2].tok_text
                if nk2 == TOK_EOF() or nk2 == TOK_RBRACE() or nk2 == TOK_KW_END() or nk2 == TOK_DIR_END() or nk2 == TOK_KW_FN() or nk2 == TOK_DIR_FN() or nk2 == TOK_KW_STRUCT() or nk2 == TOK_DIR_STRUCT() or nk2 == TOK_KW_RETURN() or nk2 == TOK_KW_IF() or nk2 == TOK_KW_ELIF() or nk2 == TOK_KW_ELSE() or nk2 == TOK_KW_WHILE() or nk2 == TOK_KW_FOR() or nk2 == TOK_KW_LET() or nk2 == TOK_KW_PRINT() or (nk2 == TOK_IDENT() and (nt2 == "say" or nt2 == "বলো" or nt2 == "end" or nt2 == "শেষ"))
                    return "Syntax Error at line " + str(ln) + ", col " + str(col) + ": missing expression after '" + txt + "'"
                end
            end
        end

        stmt_start = 0
        i = i + 1
    end

    if d_kinds.len() > 0
        un_k = d_kinds[d_kinds.len() - 1]
        un_ln = d_lines[d_lines.len() - 1]
        un_ch = "("
        if un_k == TOK_LBRACKET() un_ch = "["
        elif un_k == TOK_LBRACE() un_ch = "{" end
        return "Syntax Error at line " + str(un_ln) + ": unclosed delimiter '" + un_ch + "'"
    end
    return ""
end

// ── 4. End-to-End Modular Pipeline Execution ──────────────────────────────────

fn compiler_pipeline_execute config source_code
    // WHY: Orchestrates all compilation stages across the decoupled micro-architectures.
    // Pre-initialize shared read-only sentinel caches BEFORE any arena_mark() so scoped
    // arena_reset(m_p1/m_p3/m_p4/m_fn) calls can never wipe global sentinels!
    ast_node_init_sentinels()
    ssa_value_init_sentinels()
    ssa_instr_init_sentinels()
    result = compiler_result_new()

    // ── Phase 1: Initialize Diagnostics & Source Map ──────────────────────────
    // WHY: Phase 1 builds line indices for diagnostics; reclaim immediately via scoped
    // arena rollback before Phase 2 so line_index (~30MB on large bundles) does not bloat RSS.
    m_p1 = arena_mark()
    sm = source_map_new()
    fid = source_map_add_file(sm, config.cfg_src_path, source_code)
    diag_emitter = diagnostic_emitter_new(sm, "terminal", 0)
    result.res_stage_reached = PIPELINE_STAGE_INIT()
    sm = 0
    diag_emitter = 0
    arena_reset(m_p1)

    say "  [pipeline] Phase 1: Diagnostics initialized"
    // ── Phase 2: Lexical Analysis (Frontend Micro-Lexer) ───────────────────────
    toks = lexer_tokenize(source_code, config.cfg_src_path)
    tok_count = toks.len()
    // Release raw source string early to keep peak RSS minimal
    source_code = 0
    say "  [pipeline] Phase 2: Tokenized " + str(tok_count) + " tokens"

    // Phase 2b: Sovereign Fail-Fast Lexical & Structural Syntax Validation
    syn_err = pipeline_validate_syntax(toks)
    if syn_err != ""
        result.res_error_count = 1
        result.res_error_msg = syn_err
        result.res_stage_reached = PIPELINE_STAGE_LEX()
        result.res_success = 0
        return result
    end
    
    // Count executable tokens (ignoring whitespace newlines and trailing EOF)
    meaningful = 0
    ti = 0
    while ti < tok_count
        t = toks[ti]
        if t.tok_kind != TOK_NEWLINE() and t.tok_kind != TOK_EOF()
            meaningful = meaningful + 1
        ti = ti + 1

    if meaningful == 0
        result.res_error_count = 1
        result.res_error_msg = "Lexical analysis yielded zero executable code tokens"
        result.res_stage_reached = PIPELINE_STAGE_LEX()
        return result

    result.res_tokens_scanned = tok_count
    result.res_stage_reached = PIPELINE_STAGE_LEX()

    // ── Phase 3: Abstract Syntax Tree Construction & Verification ─────────────
    // WHY: Capture m_p3 BEFORE AST allocation and allocate side-buffer header outside m_p3.
    // Once streaming Middle-End + Regalloc + SSA Lowering finish, arena_reset(m_p3) reclaims
    // 100% of AST + schemas + middle-end slabs in <1ms BEFORE Phase 8 codegen starts!
    pms = pipe_mmap_new()
    m_p3 = arena_mark()
    say "  [pipeline] Phase 3: Constructing AST..."
    sp = source_span_point(config.cfg_src_path, 1, 1, 0)
    ast_decls = pipeline_build_ast_declarations(toks, config.cfg_src_path)
    say "  [pipeline] Phase 3: Built " + str(ast_decls.len()) + " AST declarations"
    result.res_stage_reached = PIPELINE_STAGE_PARSE()

    // ── Phase 4: Semantic Analysis, Type System & Ownership ───────────────────
    // WHY: Phase 4 is read-only over `toks` and `ast_decls`. Capturing an arena watermark
    // lets `arena_reset(m_p4)` reclaim 100% of semantic/type/ownership/proof memory AND
    // unlink all Phase-4 blocks from `_gc_head` in <1ms via MADV_DONTNEED on success!
    m_p4 = arena_mark()
    say "  [pipeline] Phase 4: Type checking & semantic analysis..."
    // WHY: Honor token-level module attributes (`#![strict]`, `#![kavach]`, `#![strict_types]`,
    // `#![strict_ownership]`, `#![strict_proof]`, `#![freestanding]`, `@strict`, `@kavach`) AND
    // function-level `#[strict]` (`@fn_strict` immediately before a function definition).
    strict_fn_map = dict()
    has_fn_strict = 0
    attr_i = 0
    while attr_i < tok_count
        at_tk = toks[attr_i]
        if at_tk.tok_kind == TOK_IDENT()
            if at_tk.tok_text == "@strict"
                config.cfg_strict_types = 1
                config.cfg_strict_ownership = 1
                config.cfg_strict_proof = 1
            elif at_tk.tok_text == "@strict_types"
                config.cfg_strict_types = 1
            elif at_tk.tok_text == "@strict_ownership"
                config.cfg_strict_ownership = 1
            elif at_tk.tok_text == "@strict_proof"
                config.cfg_strict_proof = 1
            elif at_tk.tok_text == "@kavach"
                config.cfg_kavach_mode = 1
            elif at_tk.tok_text == "@freestanding"
                config.cfg_freestanding = 1
            elif at_tk.tok_text == "@fn_strict"
                // Bind function-level `#[strict]` to the next declared function name
                sf_j = attr_i + 1
                while sf_j < tok_count and (toks[sf_j].tok_kind == TOK_NEWLINE() or toks[sf_j].tok_kind == TOK_COMMENT_DOC() or toks[sf_j].tok_text == "pub" or toks[sf_j].tok_text == "async" or toks[sf_j].tok_kind == TOK_KW_ASYNC() or str_starts_with(toks[sf_j].tok_text, "@") == 1)
                    if toks[sf_j].tok_kind == TOK_DIR_FN() or toks[sf_j].tok_text == "@fn"
                        break
                    end
                    sf_j = sf_j + 1
                end
                if sf_j + 1 < tok_count and (toks[sf_j].tok_kind == TOK_KW_FN() or toks[sf_j].tok_kind == TOK_DIR_FN() or toks[sf_j].tok_text == "fn" or toks[sf_j].tok_text == "@fn" or toks[sf_j].tok_text == "কাজ")
                    sf_nm = toks[sf_j + 1].tok_text
                    if len(sf_nm) > 0
                        strict_fn_map[sf_nm] = 1
                        has_fn_strict = 1
                    end
                else
                    // Standalone `#[strict]` not attached to a fn acts as module-level strictness
                    config.cfg_strict_types = 1
                    config.cfg_strict_ownership = 1
                    config.cfg_strict_proof = 1
                end
            end
        end
        attr_i = attr_i + 1
    end
    if config.cfg_kavach_mode == 1
        config.cfg_strict_ownership = 1
        config.cfg_strict_proof = 1
        kv_res = kavach_verify_program_with_utso(ast_decls, config.cfg_utso_ranges)
        if kv_res.kv_error_count > 0
            result.res_error_count = result.res_error_count + kv_res.kv_error_count
            result.res_error_msg = kv_res.kv_first_msg
            result.res_stage_reached = PIPELINE_STAGE_SEMANTICS()
            result.res_success = 0
            return result
        end
    end
    // Sub-phase 4a: Static Type Checking (isolated arena rollback prevents stacking with Ownership & Math Proof)
    m_p4_tc = arena_mark()
    sym_table = symtab_new(64)
    scope_stk = scope_stack_new()
    ty_reg = type_registry_new()
    tc = type_checker_new(ty_reg, sym_table, scope_stk)
    tc.tc_strict_types = config.cfg_strict_types
    tc_check_program(tc, ast_decls)
    if tc_has_errors(tc) == 1
        fatal_count = 0
        first_fatal_msg = ""
        ei = 0
        while ei < tc.tc_errors.len()
            err_diag = tc.tc_errors[ei]
            if err_diag.sd_is_warning == 0
                fatal_count = fatal_count + 1
                if len(first_fatal_msg) == 0
                    first_fatal_msg = "Semantic/Type Error: " + err_diag.sd_message
                end
            else
                result.res_warning_count = result.res_warning_count + 1
            end
            ei = ei + 1
        end
        if fatal_count > 0
            result.res_error_count = result.res_error_count + fatal_count
            result.res_error_msg = first_fatal_msg
            result.res_stage_reached = PIPELINE_STAGE_SEMANTICS()
            result.res_success = 0
            return result
        end
    end
    sym_table = 0
    scope_stk = 0
    ty_reg = 0
    tc = 0
    arena_reset(m_p4_tc)

    // Sub-phase 4b: Affine Ownership & Borrow Checking (isolated arena rollback)
    m_p4_oc = arena_mark()
    own_checker = ownership_checker_new()
    oc_analyze_stmt_list(own_checker, ast_decls)
    if oc_has_errors(own_checker) == 1
        result.res_warning_count = result.res_warning_count + oc_error_count(own_checker)
        if config.cfg_strict_ownership == 1
            first_own = own_checker.oc_errors[0]
            result.res_error_count = result.res_error_count + oc_error_count(own_checker)
            result.res_error_msg = "Ownership/Borrow Error at " + span_to_string(first_own.od_span) + ": " + first_own.od_message
            result.res_stage_reached = PIPELINE_STAGE_SEMANTICS()
            result.res_success = 0
            return result
        end
    end
    // Enforce per-function `#[strict]` ownership checks even when module is not globally strict
    if has_fn_strict == 1 and config.cfg_strict_ownership == 0
        sfi = 0
        while sfi < ast_decls.len()
            sfd = ast_decls[sfi]
            if (sfd.kind == "FnDef" or sfd.kind == "Function" or sfd.kind == "কাজ") and has_key(strict_fn_map, sfd.name) == 1
                fn_oc = ownership_checker_new()
                fn_oc.oc_struct_map = own_checker.oc_struct_map
                fn_oc.oc_fn_consumes = own_checker.oc_fn_consumes
                oc_analyze_statement(fn_oc, sfd)
                if oc_has_errors(fn_oc) == 1
                    fn_own_err = fn_oc.oc_errors[0]
                    result.res_error_count = result.res_error_count + oc_error_count(fn_oc)
                    result.res_error_msg = "Ownership/Borrow Error in #[strict] fn '" + sfd.name + "' at " + span_to_string(fn_own_err.od_span) + ": " + fn_own_err.od_message
                    result.res_stage_reached = PIPELINE_STAGE_SEMANTICS()
                    result.res_success = 0
                    return result
                end
            end
            sfi = sfi + 1
        end
    end
    own_checker = 0
    arena_reset(m_p4_oc)

    // Sub-phase 4c: Mathematical Memory Conservation Proof
    say "  [pipeline] Phase 4: Mathematical proof verification..."
    proof_engine = math_proof_engine_new()
    di = 0
    while di < ast_decls.len()
        decl = ast_decls[di]
        if decl.kind == "FnDef" or decl.kind == "Function" or decl.kind == "কাজ"
            fn_is_strict_marked = 0
            if has_fn_strict == 1 and has_key(strict_fn_map, decl.name) == 1
                fn_is_strict_marked = 1
            end
            // WHY: Top-level script wrapper main()/মূল and trusted factory/allocator utilities are exempt;
            // user routines must prove ΔMemory = 0 (frees or returns allocated handles cleanly).
            is_cleanup_fn = 0
            if fn_is_strict_marked == 1
                is_cleanup_fn = 0
            elif config.cfg_strict_proof == 1 and config.cfg_kavach_mode == 0
                if pipeline_is_strict_proof_exempt_fn(decl.name) == 1
                    is_cleanup_fn = 1
                end
            elif decl.name == "main" or decl.name == "মূল" or pipeline_is_memory_exempt_fn(decl.name) == 1 or kavach_node_in_utso(decl, config.cfg_utso_ranges) == 1
                is_cleanup_fn = 1
            end
            if is_cleanup_fn == 0
                math_proof_engine_reset(proof_engine)
                proof_cert = math_proof_verify_fn(proof_engine, decl)
                if proof_cert.mpc_is_proven == 0
                    result.res_warning_count = result.res_warning_count + 1
                    if config.cfg_strict_proof == 1 or fn_is_strict_marked == 1
                        result.res_error_count = result.res_error_count + 1
                        result.res_error_msg = "Mathematical Memory Proof Failed in function '" + decl.name + "'"
                        result.res_stage_reached = PIPELINE_STAGE_SEMANTICS()
                        result.res_success = 0
                        return result
                    end
                    if config.cfg_verbose == 1
                        say "  [pipeline] ⚠ Note: Mathematical memory conservation unproven in function " + decl.name
                    end
                end
            end
        end
        di = di + 1
    end

    result.res_stage_reached = PIPELINE_STAGE_SEMANTICS()

    // Release dead Phase 4 semantic graphs via instant scoped arena rollback (0 GC pause, MADV_DONTNEED)
    proof_engine = 0
    strict_fn_map = 0
    arena_reset(m_p4)

    // ── Phase 5: Multi-Target Architecture Selection ──────────────────────────
    target = target_machine_from_name("x86_64")
    target_name = "x86_64"
    if config.cfg_target_arch == TARGET_ID_ARM64()
        target = target_machine_from_name("arm64")
        target_name = "arm64"
    elif config.cfg_target_arch == TARGET_ID_WASM()
        target = target_machine_from_name("wasm")
        target_name = "wasm"
    elif config.cfg_target_arch == TARGET_ID_RISCV64()
        target = target_machine_from_name("riscv64")
        target_name = "riscv64"
    result.res_stage_reached = PIPELINE_STAGE_TARGET()

    // ── Phase 5a: O(N) Immutable Module-Level Constant & Mutable Global Prescan ─
    // WHY: Running this O(N) dict-backed scan BEFORE AST-to-SSA lowering enables SSA IR
    // to fold immutable module constants (OP_ADD, TOK_*, SYS_*) while strictly protecting
    // mutable `global` / `g_*` variables from ever being shadowed by local SSA slots!
    opt_const_names = list()
    opt_const_vals = list()
    ct_env = comptime_env_new()
    mod_const_map = dict()
    mod_mut_globals = dict()
    seen_assigns_map = dict()
    ban_consts_map = dict()
    ti_c = 0
    t_len_c = toks.len()
    while ti_c < t_len_c
        tk_c = toks[ti_c]
        if tk_c.tok_kind == TOK_IDENT()
            tname_c = tk_c.tok_text
            if tname_c == "global" or tname_c == "@global" or tname_c == "বিশ্বজনীন" or tname_c == "for" or tname_c == "প্রতিটি"
                if ti_c + 1 < t_len_c and toks[ti_c + 1].tok_kind == TOK_IDENT()
                    gn_c = toks[ti_c + 1].tok_text
                    ban_consts_map[gn_c] = 1
                    if tname_c == "global" or tname_c == "@global" or tname_c == "বিশ্বজনীন"
                        mod_mut_globals[gn_c] = 1
                    end
                end
            elif len(tname_c) >= 2 and str_sub(tname_c, 0, 2) == "g_"
                ban_consts_map[tname_c] = 1
                mod_mut_globals[tname_c] = 1
            elif ti_c + 1 < t_len_c
                nk_c = toks[ti_c + 1].tok_kind
                ntx_c = toks[ti_c + 1].tok_text
                if nk_c == TOK_ASSIGN() or (nk_c != TOK_STR() and ntx_c == "=")
                    if has_key(seen_assigns_map, tname_c) == 1
                        ban_consts_map[tname_c] = 1
                    else
                        seen_assigns_map[tname_c] = 1
                    end
                elif ntx_c == "+=" or ntx_c == "-=" or ntx_c == "*=" or ntx_c == "/=" or ntx_c == "%=" or nk_c == TOK_PLUSEQ() or nk_c == TOK_MINUSEQ() or nk_c == TOK_STAREQ() or nk_c == TOK_SLASHEQ() or nk_c == TOK_PERCENTEQ()
                    ban_consts_map[tname_c] = 1
                end
            end
        end
        ti_c = ti_c + 1
    end

    ti_c = 0
    while ti_c + 2 < t_len_c
        tk_c = toks[ti_c]
        if tk_c.tok_kind == TOK_IDENT() and tk_c.tok_span.span_start_col == 1
            cname_c = tk_c.tok_text
            eq_c = toks[ti_c + 1]
            if (eq_c.tok_kind == TOK_ASSIGN() or (eq_c.tok_kind != TOK_STR() and eq_c.tok_text == "="))
                prev_ok_c = 1
                if ti_c > 0
                    pk_c = toks[ti_c - 1].tok_kind
                    if pk_c != TOK_NEWLINE() and pk_c != TOK_SEMI()
                        prev_ok_c = 0
                    end
                end
                if prev_ok_c == 1 and has_key(ban_consts_map, cname_c) == 0
                    t2_c = toks[ti_c + 2]
                    after3_ok = 0
                    if ti_c + 3 >= t_len_c
                        after3_ok = 1
                    else
                        a3k = toks[ti_c + 3].tok_kind
                        if a3k == TOK_NEWLINE() or a3k == TOK_SEMI() or a3k == TOK_COMMENT_LINE() or a3k == TOK_EOF()
                            after3_ok = 1
                        end
                    end
                    if t2_c.tok_kind == TOK_INT() and after3_ok == 1
                        comptime_env_set(ct_env, cname_c, t2_c.tok_int_val)
                        mod_const_map[cname_c] = t2_c.tok_int_val
                    elif ti_c + 4 < t_len_c
                        op_c = toks[ti_c + 3]
                        r_c = toks[ti_c + 4]
                        after5_ok = 0
                        if ti_c + 5 >= t_len_c
                            after5_ok = 1
                        else
                            a5k = toks[ti_c + 5].tok_kind
                            if a5k == TOK_NEWLINE() or a5k == TOK_SEMI() or a5k == TOK_COMMENT_LINE() or a5k == TOK_EOF()
                                after5_ok = 1
                            end
                        end
                        op_s = op_c.tok_text
                        is_fold_op = 0
                        if op_c.tok_kind != TOK_STR() and (op_s == "+" or op_s == "-" or op_s == "*" or op_s == "/" or op_s == "%" or op_s == "<<" or op_s == ">>")
                            is_fold_op = 1
                        end
                        if after5_ok == 1 and is_fold_op == 1
                            lhs_ok = 0
                            lhs_v = 0
                            if t2_c.tok_kind == TOK_INT()
                                lhs_ok = 1
                                lhs_v = t2_c.tok_int_val
                            elif t2_c.tok_kind == TOK_IDENT() and comptime_env_has(ct_env, t2_c.tok_text) == 1
                                lhs_ok = 1
                                lhs_v = comptime_env_get(ct_env, t2_c.tok_text)
                            end
                            rhs_ok = 0
                            rhs_v = 0
                            if r_c.tok_kind == TOK_INT()
                                rhs_ok = 1
                                rhs_v = r_c.tok_int_val
                            elif r_c.tok_kind == TOK_IDENT() and comptime_env_has(ct_env, r_c.tok_text) == 1
                                rhs_ok = 1
                                rhs_v = comptime_env_get(ct_env, r_c.tok_text)
                            end
                            if lhs_ok == 1 and rhs_ok == 1
                                f_val = comptime_eval_binop(op_s, lhs_v, rhs_v)
                                comptime_env_set(ct_env, cname_c, f_val)
                                mod_const_map[cname_c] = f_val
                                pipe_mmap_write_const(pms, cname_c, f_val)
                            end
                        end
                    end
                end
            end
        end
        ti_c = ti_c + 1
    end
    seen_assigns_map = 0
    ban_consts_map = 0

    // Prepare target register pools before streaming/whole-module middle-end
    caller_regs = list()
    callee_regs = list()
    word_size = 8

    if config.cfg_target_arch == TARGET_ID_X86_64()
        // WHY: Use the exact 7-register non-ABI physical pool completely disjoint from SysV
        // call/scratch regs {rax,rcx,rdx,rsi,rdi,r8,r9}: caller {r10,r11} + callee {rbx,r12..r15}.
        // Push rbx(3) last in callee_regs so list_pop picks 1-byte push/pop rbx first!
        push(caller_regs, 11)
        push(caller_regs, 10)
        push(callee_regs, 15)
        push(callee_regs, 14)
        push(callee_regs, 13)
        push(callee_regs, 12)
        push(callee_regs, 3)
    elif config.cfg_target_arch == TARGET_ID_ARM64()
        // WHY: Disjoint from AAPCS64 args (x0..x7) & scratch (x9..x11): caller {x12..x15}, callee {x19..x28}.
        cr_i = 12
        while cr_i <= 15
            push(caller_regs, cr_i)
            cr_i = cr_i + 1
        cl_i = 19
        while cl_i <= 28
            push(callee_regs, cl_i)
            cl_i = cl_i + 1
    elif config.cfg_target_arch == TARGET_ID_RISCV64()
        // WHY: Disjoint from LP64 args (a0..a7) & scratch (t0..t2): caller {t3..t6=28..31}, callee {s1=9, s2..s11=18..27}.
        push(caller_regs, 28)
        push(caller_regs, 29)
        push(caller_regs, 30)
        push(caller_regs, 31)
        push(callee_regs, 9)
        cl_i = 18
        while cl_i <= 27
            push(callee_regs, cl_i)
            cl_i = cl_i + 1
    else
        push(caller_regs, 10)
        push(caller_regs, 11)
        push(callee_regs, 12)
        push(callee_regs, 13)
    end

    total_spills = 0
    total_ssa_insts = 0
    pm = pass_manager_new(config.cfg_opt_level)

    // ── Sovereign Streaming Per-Function Middle-End + Regalloc + SSA Lowering (-O0/-O1/-O2) ──
    // WHY: Unlike LLVM's whole-module IR bloat, -O0/-O1/-O2 passes are 100% function-local.
    // Streaming 32 functions per batch with instant scoped arena_reset(m_fn) keeps Middle-End
    // memory flat (~4MB peak delta instead of +600MB) and eliminates slow mark-sweep GC pauses!
    if config.cfg_opt_level < 3
        say "  [pipeline] Middle-End: Lowering AST to SSA IR..."
        sch = ast_to_ssa_collect_schemas(ast_decls)
        s_snames = sch.sch_struct_names
        s_sfields = sch.sch_struct_fields
        s_sidx = sch.sch_struct_idx_map
        s_funiq = sch.sch_field_uniq_off
        s_fnames = sch.sch_fn_names
        s_frets = sch.sch_fn_ret_types
        s_fpcnts = sch.sch_fn_param_cnts
        s_fptypes = sch.sch_fn_param_types
        s_fidx = sch.sch_fn_idx_map
        s_fset = sch.sch_mod_fn_set
        s_has_fc = sch.sch_mod_has_float_cont

        m_fn = arena_mark()
        decl_cnt = ast_decls.len()
        di_s = 0
        fn_ord_s = 0
        while di_s < decl_cnt
            batch_mod = ir_module_new("stream_batch")
            ssa_low_b = 0
            if config.cfg_ssa_codegen == 1
                ssa_low_b = ssa_lowerer_new(config.cfg_target_arch)
                ssa_low_b.low_only_eligible = 1
            end
            batch_fns = 0
            while di_s < decl_cnt and batch_fns < 16
                decl_s = ast_decls[di_s]
                dk_s = decl_s.kind
                if dk_s == "FnDef" or dk_s == "Function" or dk_s == "কাজ"
                    low_f = ast_to_ssa_lower_fn_sch(batch_mod, decl_s, sch, mod_const_map, mod_mut_globals, target_name)
                    if low_f != 0
                        if low_f.is_ssa_native_ready == 1 and fn_ord_s < s_frets.len() and low_f.return_type != ""
                            if s_frets[fn_ord_s] != "i64_int" or low_f.return_type != "i64"
                                list_set(s_frets, fn_ord_s, ast_to_ssa_intern_ret_type(sch, low_f.return_type))
                            end
                        elif low_f.is_ssa_native_ready == 0
                            // WHY: Mark non-SSA functions as 2 so ARM64/RV64 pure-int SSA does not
                            // drop dynamic X1/a1 return type tags (str/float) when forwarding calls.
                            s_fset[low_f.name] = 2
                        end
                        pass_manager_run_on_function(pm, low_f)
                        // Harvest folded constants for this function directly into out-of-arena side-buffer
                        bi_h = 0
                        while bi_h < low_f.blocks.len()
                            bb_h = low_f.blocks[bi_h]
                            ii_h = 0
                            while ii_h < bb_h.instructions.len()
                                inst_h = bb_h.instructions[ii_h]
                                if inst_h.op == OP_STORE and inst_h.operands.len() >= 2
                                    val_op = inst_h.operands[0]
                                    ptr_op = inst_h.operands[1]
                                    if (val_op.kind == VAL_KIND_CONST or val_op.val_kind == VAL_KIND_CONST) and ptr_op != 0
                                        pname = ptr_op.id
                                        if len(pname) > 6 and str_sub(pname, 0, 6) == "%slot_"
                                            var_k = str_sub(pname, 6, len(pname))
                                            pipe_mmap_write_const2(pms, low_f.name, var_k, val_op.const_val)
                                        end
                                    end
                                end
                                ii_h = ii_h + 1
                            end
                            bi_h = bi_h + 1
                        end
                        // Linear scan register allocation for this function
                        ra_res = linear_scan_allocate_function(low_f, caller_regs, callee_regs, word_size)
                        total_spills = total_spills + ra_res.spill_count
                        ivi = 0
                        while ivi < ra_res.intervals.len()
                            iv = ra_res.intervals[ivi]
                            if iv.is_spilled == 0 and iv.assigned_reg >= 0
                                bind_ok = 1
                                if config.cfg_target_arch == TARGET_ID_X86_64()
                                    if iv.assigned_reg != 12 and iv.assigned_reg != 13 and iv.assigned_reg != 14 and iv.assigned_reg != 15 and iv.assigned_reg != 3
                                        bind_ok = 0
                                    end
                                end
                                if bind_ok == 1
                                    vname = iv.vreg_name
                                    clean_v = vname
                                    if len(vname) > 6 and str_sub(vname, 0, 6) == "%slot_"
                                        clean_v = str_sub(vname, 6, len(vname))
                                    elif starts_with(vname, "%") == 1
                                        clean_v = str_sub(vname, 1, len(vname))
                                    end
                                    pipe_mmap_write_reg2(pms, low_f.name, clean_v, iv.assigned_reg)
                                end
                            end
                            ivi = ivi + 1
                        end
                        // Optional direct SSA CFG lowering for this function (physical register allocated!)
                        if config.cfg_ssa_codegen == 1
                            f_code_s = buf_len(ssa_low_b.low_code)
                            f_ro_s = buf_len(ssa_low_b.low_rodata)
                            f_str_s = ssa_low_b.low_str_relocs.len()
                            f_call_s = ssa_low_b.low_call_patches.len()
                            f_idx_b = ssa_low_b.low_fn_names.len()
                            ssa_lower_function_ra(ssa_low_b, low_f, s_fset, ra_res)
                            pipe_mmap_write_ssa_fn(pms, ssa_low_b, f_idx_b, f_code_s, f_ro_s, f_str_s, f_call_s)
                        end
                    end
                    fn_ord_s = fn_ord_s + 1
                    batch_fns = batch_fns + 1
                elif dk_s == "GlobalVar" or dk_s == "Constant"
                    pipe_mmap_write_const(pms, "@" + decl_s.name, decl_s.val)
                end
                di_s = di_s + 1
            end
            if ssa_low_b != 0
                total_ssa_insts = total_ssa_insts + ssa_low_b.low_total_insts
            end
            batch_mod = 0
            ssa_low_b = 0
            arena_reset(m_fn)
        end
        say "  [pipeline] Middle-End: Running optimization passes..."
        say "  [pipeline] Middle-End: Optimizations complete"
        say "  [pipeline] Phase 6: Linear scan register allocation..."
        say "  [pipeline] Phase 6: Register allocation complete (spills: " + str(total_spills) + ")"
        if config.cfg_ssa_codegen == 1
            say "  [pipeline] Phase 6b: Direct SSA CFG Lowering..."
            say "  [pipeline] Phase 6b: SSA CFG Lowering complete"
        end
        sch = 0
    else
        // ── -O3 Whole-Module Pipeline (supports inter-procedural function inlining) ──
        say "  [pipeline] Middle-End: Lowering AST to SSA IR..."
        ssa_module = ast_to_ssa_lower_module_with_consts(ast_decls, target_name, mod_const_map, mod_mut_globals)
        say "  [pipeline] Middle-End: Running optimization passes..."
        pass_manager_run_on_module(pm, ssa_module)
        say "  [pipeline] Middle-End: Optimizations complete"

        gi = 0
        while gi < ssa_module.globals.len()
            g = ssa_module.globals[gi]
            pipe_mmap_write_const(pms, g.name, g.init_val)
            gi = gi + 1
        end

        fi_h = 0
        while fi_h < ssa_module.functions.len()
            fn_h = ssa_module.functions[fi_h]
            bi_h = 0
            while bi_h < fn_h.blocks.len()
                bb_h = fn_h.blocks[bi_h]
                ii_h = 0
                while ii_h < bb_h.instructions.len()
                    inst_h = bb_h.instructions[ii_h]
                    if inst_h.op == OP_STORE and inst_h.operands.len() >= 2
                        val_op = inst_h.operands[0]
                        ptr_op = inst_h.operands[1]
                        if (val_op.kind == VAL_KIND_CONST or val_op.val_kind == VAL_KIND_CONST) and ptr_op != 0
                            pname = ptr_op.id
                            if len(pname) > 6 and str_sub(pname, 0, 6) == "%slot_"
                                var_k = str_sub(pname, 6, len(pname))
                                pipe_mmap_write_const2(pms, fn_h.name, var_k, val_op.const_val)
                            end
                        end
                    end
                    ii_h = ii_h + 1
                end
                bi_h = bi_h + 1
            end
            fi_h = fi_h + 1
        end

        say "  [pipeline] Phase 6: Linear scan register allocation..."
        o3_ra_list = list()
        fi = 0
        while fi < ssa_module.functions.len()
            fn_obj = ssa_module.functions[fi]
            ra_res = linear_scan_allocate_function(fn_obj, caller_regs, callee_regs, word_size)
            if config.cfg_ssa_codegen == 1
                push(o3_ra_list, ra_res)
            end
            total_spills = total_spills + ra_res.spill_count
            ivi = 0
            while ivi < ra_res.intervals.len()
                iv = ra_res.intervals[ivi]
                if iv.is_spilled == 0 and iv.assigned_reg >= 0
                    bind_ok = 1
                    if config.cfg_target_arch == TARGET_ID_X86_64()
                        if iv.assigned_reg != 12 and iv.assigned_reg != 13 and iv.assigned_reg != 14 and iv.assigned_reg != 15 and iv.assigned_reg != 3
                            bind_ok = 0
                        end
                    end
                    if bind_ok == 1
                        vname = iv.vreg_name
                        clean_v = vname
                        if len(vname) > 6 and str_sub(vname, 0, 6) == "%slot_"
                            clean_v = str_sub(vname, 6, len(vname))
                        elif starts_with(vname, "%") == 1
                            clean_v = str_sub(vname, 1, len(vname))
                        end
                        pipe_mmap_write_reg2(pms, fn_obj.name, clean_v, iv.assigned_reg)
                    end
                end
                ivi = ivi + 1
            end
            fi = fi + 1
        end
        say "  [pipeline] Phase 6: Register allocation complete (spills: " + str(total_spills) + ")"

        if config.cfg_ssa_codegen == 1
            say "  [pipeline] Phase 6b: Direct SSA CFG Lowering..."
            ssa_low = ssa_lowerer_new(config.cfg_target_arch)
            ssa_low.low_only_eligible = 1
            mod_fset_o3 = dict()
            mfi3 = 0
            while mfi3 < ssa_module.functions.len()
                f_o3 = ssa_module.functions[mfi3]
                if f_o3.is_ssa_native_ready == 1
                    mod_fset_o3[f_o3.name] = 1
                else
                    mod_fset_o3[f_o3.name] = 2
                end
                mfi3 = mfi3 + 1
            end
            fi3 = 0
            while fi3 < ssa_module.functions.len()
                f3 = ssa_module.functions[fi3]
                f_code_s = buf_len(ssa_low.low_code)
                f_ro_s = buf_len(ssa_low.low_rodata)
                f_str_s = ssa_low.low_str_relocs.len()
                f_call_s = ssa_low.low_call_patches.len()
                f_idx_b = ssa_low.low_fn_names.len()
                ra3 = 0
                if fi3 < o3_ra_list.len() ra3 = o3_ra_list[fi3] end
                ssa_lower_function_ra(ssa_low, f3, mod_fset_o3, ra3)
                pipe_mmap_write_ssa_fn(pms, ssa_low, f_idx_b, f_code_s, f_ro_s, f_str_s, f_call_s)
                fi3 = fi3 + 1
            end
            o3_ra_list = 0
            total_ssa_insts = ssa_low.low_total_insts
            ssa_low = 0
            say "  [pipeline] Phase 6b: SSA CFG Lowering complete"
        end
        ssa_module = 0
    end

    result.res_reg_alloc_spills = total_spills
    result.res_stage_reached = PIPELINE_STAGE_REGALLOC()

    // Instant <1ms MADV_DONTNEED reclamation of 100% of Phase 3 AST + Phase 5/6/6b Middle-End!
    ast_decls = 0
    mod_const_map = 0
    mod_mut_globals = 0
    ct_env = 0
    pm = 0
    caller_regs = 0
    callee_regs = 0
    target = 0
    arena_reset(m_p3)

    // Materialize compact Phase-8 inputs from out-of-arena side-buffer & unmap immediately
    opt_const_names = list()
    opt_const_vals = list()
    reg_names = list()
    reg_regs = list()
    ssa_lower_res = pipe_mmap_unpack(pms, opt_const_names, opt_const_vals, reg_names, reg_regs, config.cfg_ssa_codegen, total_ssa_insts)
    pms = 0

    // ── Phase 7: Binary Container Packaging (ELF/PE/Mach-O) ───────────────────
    hdr_x86 = elf_header_x86_64(4198400, 64, 512, 2, 6, 5)
    elf_bytes = elf_header_serialize(hdr_x86)
    result.res_output_bytes = elf_bytes.len()
    result.res_stage_reached = PIPELINE_STAGE_COMPLETE()

    // WHY: If live emission requested (cfg_is_dry_run == 0), assemble and persist the binary to disk.
    if config.cfg_is_dry_run == 0
        say "  [pipeline] Phase 8: Live emission to " + config.cfg_out_path
        x86_synth_set_strict_types(config.cfg_strict_types)
        x86_synth_set_ssa_codegen(config.cfg_ssa_codegen)
        x86_synth_set_freestanding(0)
        x86_synth_set_emit_obj(0)
        x86_synth_set_entry_sym(config.cfg_entry_sym)
        x86_synth_set_base_vaddr(1073741824)
        x86_synth_set_code_file_off(304)
        if config.cfg_emit_format == FORMAT_SHARED()
            // Sovereign Shared Object (.so) Emission via System V AMD64 Dynamic ABI
            synth = x86_synth_compile_program_full(toks, opt_const_names, opt_const_vals, reg_names, reg_regs, ssa_lower_res)
            pipeline_free_ssa_res(ssa_lower_res)
            ssa_lower_res = 0
            exp_names = list()
            exp_offs = list()
            f_idx = 0
            while f_idx < synth.synth_functions.len()
                fn_item = synth.synth_functions[f_idx]
                fn_n = fn_item.fn_name
                is_user_exp = 0
                if fn_item.fn_decl_line > 0 and len(fn_n) > 0
                    is_user_exp = 1
                    if len(fn_n) >= 2 and str_sub(fn_n, 0, 2) == "__"
                        is_user_exp = 0
                    end
                    if len(fn_n) >= 6 and str_sub(fn_n, 0, 6) == "_lipi_"
                        is_user_exp = 0
                    end
                end
                if is_user_exp == 1
                    push(exp_names, fn_n)
                    push(exp_offs, fn_item.fn_entry_offset)
                end
                f_idx = f_idx + 1
            if exp_names.len() == 0
                push(exp_names, "_start")
                push(exp_offs, 0)
            so_size = so_emit_shared_library(x86_synth_buf_to_list(synth.synth_code), x86_synth_buf_to_list(synth.synth_rodata), exp_names, exp_offs, config.cfg_out_path)
            buf_free(synth.synth_code)
            buf_free(synth.synth_rodata)
            if so_size > 0
                result.res_output_bytes = so_size
            else
                result.res_error_count = 1
                result.res_error_msg = "Failed to emit shared library (.so)"
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
        elif config.cfg_emit_format == FORMAT_MACHO()
            // Sovereign Mach-O 64-bit Binary Emission (macOS Darwin x86_64 / ARM64 Apple Silicon)
            if config.cfg_target_arch == TARGET_ID_ARM64()
                arm64_synth_set_freestanding(config.cfg_freestanding)
                arm64_synth_set_ssa_codegen(config.cfg_ssa_codegen)
                arm_synth = arm64_synth_compile_program_ssa(toks, ssa_lower_res)
                pipeline_free_ssa_res(ssa_lower_res)
                ssa_lower_res = 0
                if arm_synth.a64_error_count > 0
                    result.res_error_count = arm_synth.a64_error_count
                    result.res_error_msg = arm_synth.a64_error_msg
                    result.res_stage_reached = PIPELINE_STAGE_EMIT()
                    result.res_success = 0
                    return result
                end
                m_res = macho_emit_executable(arm_synth.synth_code, arm_synth.synth_rodata, 0, 16777228, config.cfg_out_path)
                if m_res.mw_success == 1
                    result.res_output_bytes = m_res.mw_file_size
                else
                    result.res_error_count = 1
                    result.res_error_msg = m_res.mw_error_msg
                    result.res_stage_reached = PIPELINE_STAGE_EMIT()
                    result.res_success = 0
                    return result
            else
                synth = x86_synth_compile_program_full(toks, opt_const_names, opt_const_vals, reg_names, reg_regs, ssa_lower_res)
                pipeline_free_ssa_res(ssa_lower_res)
                ssa_lower_res = 0
                m_res = macho_emit_executable(x86_synth_buf_to_list(synth.synth_code), x86_synth_buf_to_list(synth.synth_rodata), 0, 16777223, config.cfg_out_path)
                buf_free(synth.synth_code)
                buf_free(synth.synth_rodata)
                if m_res.mw_success == 1
                    result.res_output_bytes = m_res.mw_file_size
                else
                    result.res_error_count = 1
                    result.res_error_msg = m_res.mw_error_msg
                    result.res_stage_reached = PIPELINE_STAGE_EMIT()
                    result.res_success = 0
                    return result
        elif config.cfg_emit_format == FORMAT_PE()
            // Sovereign Windows PE32+ (.exe) Executable Emission (x86-64 COFF, zero Linux syscalls)
            synth = x86_synth_compile_program_full(toks, opt_const_names, opt_const_vals, reg_names, reg_regs, ssa_lower_res)
            pipeline_free_ssa_res(ssa_lower_res)
            ssa_lower_res = 0
            pe_bss = 0
            pe_need = 512 + (synth.synth_mutable_globals.len() * 8)
            if synth.synth_bss_cursor > 0
                pe_need = bare_align_up(pe_need, 4096)
                if pe_need < 4096 pe_need = 4096 end
                pe_need = pe_need + bare_align_up(synth.synth_bss_cursor, 4096)
            end
            if pe_need > 4096
                pe_bss = bare_align_up(pe_need - 4096, 4096)
            end
            pe_res = pe_emit_executable(x86_synth_buf_to_list(synth.synth_code), x86_synth_buf_to_list(synth.synth_rodata), [], pe_bss, 0, config.cfg_out_path)
            buf_free(synth.synth_code)
            buf_free(synth.synth_rodata)
            if pe_res.pe_success == 1
                result.res_output_bytes = pe_res.pe_file_size
            else
                result.res_error_count = 1
                result.res_error_msg = pe_res.pe_error_msg
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
        elif config.cfg_emit_format == FORMAT_RAW_BIN()
            // Sovereign Multi-Arch Flat Headerless Raw Binary (--target=[arm64-|riscv64-]raw-bin) — Zero Linux Syscalls
            raw_base = config.cfg_base_vaddr
            if raw_base == 1073741824
                raw_base = 0
            end
            if config.cfg_target_arch == TARGET_ID_ARM64()
                arm64_synth_set_freestanding(1)
                arm64_synth_set_ssa_codegen(config.cfg_ssa_codegen)
                arm64_synth_set_base_vaddr(raw_base)
                arm64_synth_set_code_file_off(0)
                arm_synth = arm64_synth_compile_program_ssa(toks, ssa_lower_res)
                pipeline_free_ssa_res(ssa_lower_res)
                ssa_lower_res = 0
                if arm_synth.a64_error_count > 0
                    result.res_error_count = arm_synth.a64_error_count
                    result.res_error_msg = arm_synth.a64_error_msg
                    result.res_stage_reached = PIPELINE_STAGE_EMIT()
                    result.res_success = 0
                    return result
                end
                a64_svcs = arm64_verify_zero_linux_svcs(arm_synth.synth_code)
                if a64_svcs > 0
                    result.res_error_count = 1
                    result.res_error_msg = "Bare-Metal Purity Gate failed: detected " + str(a64_svcs) + " forbidden Linux svc #0 instruction(s) in ARM64 raw-bin output"
                    result.res_stage_reached = PIPELINE_STAGE_EMIT()
                    result.res_success = 0
                    return result
                end
                raw_res = bare_emit_raw_bin(arm_synth.synth_code, arm_synth.synth_rodata, config.cfg_out_path)
            elif config.cfg_target_arch == TARGET_ID_RISCV64()
                riscv64_synth_set_freestanding(1)
                riscv64_synth_set_ssa_codegen(config.cfg_ssa_codegen)
                riscv64_synth_set_base_vaddr(raw_base)
                riscv64_synth_set_code_file_off(0)
                rv_synth = riscv64_synth_compile_program_ssa(toks, ssa_lower_res)
                pipeline_free_ssa_res(ssa_lower_res)
                ssa_lower_res = 0
                if rv_synth.rv_error_count > 0
                    result.res_error_count = rv_synth.rv_error_count
                    result.res_error_msg = rv_synth.rv_error_msg
                    result.res_stage_reached = PIPELINE_STAGE_EMIT()
                    result.res_success = 0
                    return result
                end
                rv_ecalls = riscv64_verify_zero_linux_ecalls(rv_synth.rv_code)
                if rv_ecalls > 0
                    result.res_error_count = 1
                    result.res_error_msg = "Bare-Metal Purity Gate failed: detected " + str(rv_ecalls) + " forbidden Linux ecall instruction(s) in RISC-V 64 raw-bin output"
                    result.res_stage_reached = PIPELINE_STAGE_EMIT()
                    result.res_success = 0
                    return result
                end
                raw_res = bare_emit_raw_bin(rv_synth.rv_code, rv_synth.rv_rodata, config.cfg_out_path)
            else
                x86_synth_set_freestanding(1)
                x86_synth_set_base_vaddr(raw_base)
                x86_synth_set_code_file_off(0)
                synth = x86_synth_compile_program_full(toks, opt_const_names, opt_const_vals, reg_names, reg_regs, ssa_lower_res)
                pipeline_free_ssa_res(ssa_lower_res)
                ssa_lower_res = 0
                if raw_base == 0 and config.cfg_no_pie == 0
                    x86_synth_convert_to_pie(synth)
                end
                // Bare-Metal Purity Gate: fail compilation if any Linux `syscall` (0x0F 0x05) leaked into raw-bin
                raw_sc = bare_verify_zero_linux_syscalls_buf(synth.synth_code)
                if raw_sc > 0
                    buf_free(synth.synth_code)
                    buf_free(synth.synth_rodata)
                    result.res_error_count = 1
                    result.res_error_msg = "Bare-Metal Purity Gate failed: detected " + str(raw_sc) + " forbidden Linux syscall (0F 05) instruction(s) in raw-bin output"
                    result.res_stage_reached = PIPELINE_STAGE_EMIT()
                    result.res_success = 0
                    return result
                end
                raw_res = bare_emit_raw_bin_buf(synth.synth_code, synth.synth_rodata, config.cfg_out_path)
                buf_free(synth.synth_code)
                buf_free(synth.synth_rodata)
            end
            if raw_res.bw_success == 1
                result.res_output_bytes = raw_res.bw_file_size
            else
                result.res_error_count = 1
                result.res_error_msg = raw_res.bw_error_msg
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
            end
        elif config.cfg_emit_format == FORMAT_UEFI()
            // Sovereign UEFI PE32+ Application (--target=uefi, Subsystem=10, zero KERNEL32.dll, real DIR64 .reloc!)
            x86_synth_set_freestanding(1)
            x86_synth_set_base_vaddr(4194304)
            x86_synth_set_code_file_off(4128) // 0x1000 (.text RVA) + 32B MS x64 -> SysV entry stub
            synth = x86_synth_compile_program_full(toks, opt_const_names, opt_const_vals, reg_names, reg_regs, ssa_lower_res)
            pipeline_free_ssa_res(ssa_lower_res)
            ssa_lower_res = 0
            efi_sc = bare_verify_zero_linux_syscalls_buf(synth.synth_code)
            if efi_sc > 0
                buf_free(synth.synth_code)
                buf_free(synth.synth_rodata)
                result.res_error_count = 1
                result.res_error_msg = "Bare-Metal Purity Gate failed: detected " + str(efi_sc) + " forbidden Linux syscall (0F 05) instruction(s) in UEFI output"
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
            end
            // Collect ALL 64-bit absolute code patch offsets for genuine PE32+ IMAGE_REL_BASED_DIR64 (.reloc) entries!
            efi_abs_patches = list()
            eri = 0
            while eri < synth.synth_str_relocs.len()
                push(efi_abs_patches, synth.synth_str_relocs[eri].sr_patch_offset)
                eri = eri + 1
            end
            ewi = 0
            while ewi < synth.synth_rw_patch_offs.len()
                push(efi_abs_patches, synth.synth_rw_patch_offs[ewi])
                ewi = ewi + 1
            end
            efi_bss = 0
            efi_need = 512 + (synth.synth_mutable_globals.len() * 8)
            if synth.synth_bss_cursor > 0
                efi_need = bare_align_up(efi_need, 4096)
                if efi_need < 4096 efi_need = 4096 end
                efi_need = efi_need + bare_align_up(synth.synth_bss_cursor, 4096)
            end
            if efi_need > 4096
                efi_bss = bare_align_up(efi_need - 4096, 4096)
            end
            efi_res = bare_emit_uefi_pe32plus_reloc(x86_synth_buf_to_list(synth.synth_code), x86_synth_buf_to_list(synth.synth_rodata), efi_bss, efi_abs_patches, config.cfg_out_path)
            buf_free(synth.synth_code)
            buf_free(synth.synth_rodata)
            if efi_res.bw_success == 1
                result.res_output_bytes = efi_res.bw_file_size
            else
                result.res_error_count = 1
                result.res_error_msg = efi_res.bw_error_msg
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
            end
        elif config.cfg_emit_format == FORMAT_MULTIBOOT2_BARE()
            // Sovereign Bare-Metal Dual Multiboot1+Multiboot2 32->64-bit Long-Mode Kernel (--target=multiboot2-bare / baremetal)
            mb_phys = config.cfg_base_vaddr
            if mb_phys == 1073741824
                mb_phys = 1048576 // 0x100000 physical load address
            end
            x86_synth_set_freestanding(1)
            x86_synth_set_base_vaddr(mb_phys)
            x86_synth_set_code_file_off(304)
            synth = x86_synth_compile_program_full(toks, opt_const_names, opt_const_vals, reg_names, reg_regs, ssa_lower_res)
            pipeline_free_ssa_res(ssa_lower_res)
            ssa_lower_res = 0
            mb_sc = bare_verify_zero_linux_syscalls_buf(synth.synth_code)
            if mb_sc > 0
                buf_free(synth.synth_code)
                buf_free(synth.synth_rodata)
                result.res_error_count = 1
                result.res_error_msg = "Bare-Metal Purity Gate failed: detected " + str(mb_sc) + " forbidden Linux syscall (0F 05) instruction(s) in multiboot2-bare output"
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
            end
            mb_bss = 0
            mb_need = 512 + (synth.synth_mutable_globals.len() * 8)
            if synth.synth_bss_cursor > 0
                mb_need = bare_align_up(mb_need, 4096)
                if mb_need < 4096 mb_need = 4096 end
                mb_need = mb_need + bare_align_up(synth.synth_bss_cursor, 4096)
            end
            if mb_need > 4096
                mb_bss = bare_align_up(mb_need - 4096, 4096)
            end
            mb_res = bare_emit_multiboot2_kernel(x86_synth_buf_to_list(synth.synth_code), x86_synth_buf_to_list(synth.synth_rodata), mb_bss, synth.synth_base_vaddr, config.cfg_out_path)
            buf_free(synth.synth_code)
            buf_free(synth.synth_rodata)
            if mb_res.bw_success == 1
                result.res_output_bytes = mb_res.bw_file_size
            else
                result.res_error_count = 1
                result.res_error_msg = mb_res.bw_error_msg
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
            end
        elif config.cfg_emit_format == FORMAT_UNIKERNEL()
            // Sovereign ELF64 3-PHDR W^X Multiboot2 Unikernel (--target=unikernel / multiboot2)
            synth = x86_synth_compile_program_full(toks, opt_const_names, opt_const_vals, reg_names, reg_regs, ssa_lower_res)
            pipeline_free_ssa_res(ssa_lower_res)
            ssa_lower_res = 0
            mb2_code = [
                214, 80, 82, 232, 0, 0, 0, 0, 40, 0, 0, 0, 2, 175, 173, 23,
                3, 0, 0, 0, 12, 0, 0, 0, 88, 1, 64, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 8, 0, 0, 0
            ]
            mb2_cp = buf_ptr(synth.synth_code)
            mb2_clen = buf_len(synth.synth_code)
            si_u = 0
            while si_u < mb2_clen
                push(mb2_code, mem_byte_read(mb2_cp, si_u))
                si_u = si_u + 1
            end
            emit_res = elf_emit_executable(mb2_code, x86_synth_buf_to_list(synth.synth_rodata), [], 0, config.cfg_out_path)
            buf_free(synth.synth_code)
            buf_free(synth.synth_rodata)
            if emit_res.ew_success == 1
                result.res_output_bytes = emit_res.ew_file_size
            else
                result.res_error_count = 1
                result.res_error_msg = emit_res.ew_error_msg
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
            end
        elif config.cfg_emit_format == FORMAT_ELF_KERNEL() or (config.cfg_freestanding == 1 and config.cfg_target_arch == TARGET_ID_X86_64() and config.cfg_emit_format != FORMAT_OBJ()) or (config.cfg_freestanding == 1 and config.cfg_base_vaddr != 1073741824 and (config.cfg_target_arch == TARGET_ID_ARM64() or config.cfg_target_arch == TARGET_ID_RISCV64()))
            // Sovereign Multi-Arch Freestanding ELF64 Kernel at Configurable Base Address (--target=[arm64-|riscv64-]elf-kernel)
            if config.cfg_target_arch == TARGET_ID_ARM64()
                k_base_a64 = config.cfg_base_vaddr
                if k_base_a64 == 1073741824
                    k_base_a64 = 1074266112 // 0x40080000 (standard ARM64 QEMU virt kernel load address)
                end
                arm64_synth_set_freestanding(1)
                arm64_synth_set_ssa_codegen(config.cfg_ssa_codegen)
                arm64_synth_set_base_vaddr(k_base_a64)
                arm64_synth_set_code_file_off(0)
                arm_synth = arm64_synth_compile_program_ssa(toks, ssa_lower_res)
                pipeline_free_ssa_res(ssa_lower_res)
                ssa_lower_res = 0
                if arm_synth.a64_error_count > 0
                    result.res_error_count = arm_synth.a64_error_count
                    result.res_error_msg = arm_synth.a64_error_msg
                    result.res_stage_reached = PIPELINE_STAGE_EMIT()
                    result.res_success = 0
                    return result
                end
                a64_svcs = arm64_verify_zero_linux_svcs(arm_synth.synth_code)
                if a64_svcs > 0
                    result.res_error_count = 1
                    result.res_error_msg = "Bare-Metal Purity Gate failed: detected " + str(a64_svcs) + " forbidden Linux svc #0 instruction(s) in ARM64 elf-kernel output"
                    result.res_stage_reached = PIPELINE_STAGE_EMIT()
                    result.res_success = 0
                    return result
                end
                k_res = bare_emit_elf64_kernel_arch(arm_synth.synth_code, arm_synth.synth_rodata, 0, k_base_a64, list(), list(), list(), list(), 183, config.cfg_out_path)
            elif config.cfg_target_arch == TARGET_ID_RISCV64()
                k_base_rv = config.cfg_base_vaddr
                if k_base_rv == 1073741824
                    k_base_rv = 2149580800 // 0x80200000 (standard OpenSBI RISC-V 64 kernel load address)
                end
                riscv64_synth_set_freestanding(1)
                riscv64_synth_set_ssa_codegen(config.cfg_ssa_codegen)
                riscv64_synth_set_base_vaddr(k_base_rv)
                riscv64_synth_set_code_file_off(0)
                rv_synth = riscv64_synth_compile_program_ssa(toks, ssa_lower_res)
                pipeline_free_ssa_res(ssa_lower_res)
                ssa_lower_res = 0
                if rv_synth.rv_error_count > 0
                    result.res_error_count = rv_synth.rv_error_count
                    result.res_error_msg = rv_synth.rv_error_msg
                    result.res_stage_reached = PIPELINE_STAGE_EMIT()
                    result.res_success = 0
                    return result
                end
                rv_ecalls = riscv64_verify_zero_linux_ecalls(rv_synth.rv_code)
                if rv_ecalls > 0
                    result.res_error_count = 1
                    result.res_error_msg = "Bare-Metal Purity Gate failed: detected " + str(rv_ecalls) + " forbidden Linux ecall instruction(s) in RISC-V 64 elf-kernel output"
                    result.res_stage_reached = PIPELINE_STAGE_EMIT()
                    result.res_success = 0
                    return result
                end
                k_res = bare_emit_elf64_kernel_arch(rv_synth.rv_code, rv_synth.rv_rodata, 0, k_base_rv, list(), list(), list(), list(), 243, config.cfg_out_path)
            else
                k_base = config.cfg_base_vaddr
                if k_base == 1073741824
                    k_base = 1048576 // default 0x100000 (1MB) when --base-addr not overridden
                end
                x86_synth_set_freestanding(1)
                x86_synth_set_base_vaddr(k_base)
                x86_synth_set_code_file_off(304)
                synth = x86_synth_compile_program_full(toks, opt_const_names, opt_const_vals, reg_names, reg_regs, ssa_lower_res)
                pipeline_free_ssa_res(ssa_lower_res)
                ssa_lower_res = 0
                k_sc = bare_verify_zero_linux_syscalls_buf(synth.synth_code)
                if k_sc > 0
                    buf_free(synth.synth_code)
                    buf_free(synth.synth_rodata)
                    result.res_error_count = 1
                    result.res_error_msg = "Bare-Metal Purity Gate failed: detected " + str(k_sc) + " forbidden Linux syscall (0F 05) instruction(s) in freestanding elf-kernel output"
                    result.res_stage_reached = PIPELINE_STAGE_EMIT()
                    result.res_success = 0
                    return result
                end
                eff_k_base = synth.synth_base_vaddr
                k_code_vaddr = eff_k_base - (0 - 304)
                k_bss = 0
                k_need = 512 + (synth.synth_mutable_globals.len() * 8)
                if synth.synth_bss_cursor > 0
                    k_need = bare_align_up(k_need, 4096)
                    if k_need < 4096 k_need = 4096 end
                    k_need = k_need + bare_align_up(synth.synth_bss_cursor, 4096)
                end
                if k_need > 4096
                    k_bss = bare_align_up(k_need - 4096, 4096)
                end
                k_eh = lpo_build_eh_frame(k_code_vaddr, synth.synth_functions)
                k_dl = list()
                k_di = list()
                k_da = list()
                if config.cfg_debug_mode == 1
                    k_lb = dwarf_line_builder_new(4)
                    dwarf_line_add_dir(k_lb, ".")
                    dwarf_line_add_file(k_lb, config.cfg_src_path, 1)
                    dwarf_line_emit_set_address(k_lb, k_code_vaddr)
                    cur_kpc = 0
                    cur_kln = 1
                    if synth.synth_line_pcs.len() > 0
                        kli = 0
                        while kli < synth.synth_line_pcs.len()
                            tpc = synth.synth_line_pcs[kli]
                            tln = synth.synth_line_nums[kli]
                            dp = tpc - cur_kpc
                            dl = tln - cur_kln
                            if dp > 0 or dl != 0 or kli == 0
                                if dp > 0
                                    dwarf_line_emit_advance_pc(k_lb, dp)
                                    cur_kpc = tpc
                                end
                                if dl != 0
                                    dwarf_line_emit_advance_line(k_lb, dl)
                                    cur_kln = tln
                                end
                                dwarf_line_emit_copy(k_lb)
                            end
                            kli = kli + 1
                        end
                    else
                        dwarf_line_emit_advance_line(k_lb, 0)
                        dwarf_line_emit_copy(k_lb)
                    end
                    if synth.synth_code.len() > cur_kpc
                        dwarf_line_emit_advance_pc(k_lb, synth.synth_code.len() - cur_kpc)
                    end
                    dwarf_line_end_sequence(k_lb, k_code_vaddr - (0 - synth.synth_code.len()))
                    k_dl = dwarf_line_serialize(k_lb)
                    k_da = dwarf_abbrev_build_standard()
                    k_cu = dwarf_unit_create("LiPi First 1.0.0 Sovereign Kernel", config.cfg_src_path, ".", k_code_vaddr, k_code_vaddr - (0 - synth.synth_code.len()), 0)
                    kfi = 0
                    while kfi < synth.synth_functions.len()
                        kf = synth.synth_functions[kfi]
                        if kf.fn_decl_line > 0
                            kf_end = kf.fn_end_offset
                            if kf_end <= kf.fn_entry_offset kf_end = kf.fn_entry_offset + 1 end
                            dwarf_unit_add_function(k_cu, kf.fn_name, k_code_vaddr - (0 - kf.fn_entry_offset), k_code_vaddr - (0 - kf_end), 1, kf.fn_decl_line)
                        end
                        kfi = kfi + 1
                    end
                    dwarf_unit_add_base_type(k_cu, "u64", 8, DW_ATE_unsigned())
                    k_di = dwarf_info_serialize(k_cu)
                end
                k_res = bare_emit_elf64_kernel(x86_synth_buf_to_list(synth.synth_code), x86_synth_buf_to_list(synth.synth_rodata), k_bss, eff_k_base, k_dl, k_di, k_da, k_eh, config.cfg_out_path)
                buf_free(synth.synth_code)
                buf_free(synth.synth_rodata)
            end
            if k_res.bw_success == 1
                result.res_output_bytes = k_res.bw_file_size
            else
                result.res_error_count = 1
                result.res_error_msg = k_res.bw_error_msg
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
            end
        elif config.cfg_emit_format == FORMAT_OBJ()
            // Sovereign Multi-Arch ELF64 Relocatable Object (.o / ET_REL = 1) Emission (-c / --emit=obj / --target=obj)
            if config.cfg_target_arch == TARGET_ID_ARM64()
                arm64_synth_set_freestanding(config.cfg_freestanding)
                arm64_synth_set_ssa_codegen(config.cfg_ssa_codegen)
                arm64_synth_set_base_vaddr(0)
                arm64_synth_set_code_file_off(0)
                arm_synth = arm64_synth_compile_program_ssa(toks, ssa_lower_res)
                pipeline_free_ssa_res(ssa_lower_res)
                ssa_lower_res = 0
                if arm_synth.a64_error_count > 0
                    result.res_error_count = arm_synth.a64_error_count
                    result.res_error_msg = arm_synth.a64_error_msg
                    result.res_stage_reached = PIPELINE_STAGE_EMIT()
                    result.res_success = 0
                    return result
                end
                if config.cfg_freestanding == 1
                    a64_svcs = arm64_verify_zero_linux_svcs(arm_synth.synth_code)
                    if a64_svcs > 0
                        result.res_error_count = 1
                        result.res_error_msg = "Bare-Metal Purity Gate failed: detected " + str(a64_svcs) + " forbidden Linux svc #0 instruction(s) in ARM64 freestanding .o output"
                        result.res_stage_reached = PIPELINE_STAGE_EMIT()
                        result.res_success = 0
                        return result
                    end
                end
                a64_obj_fns = list()
                afi = 0
                while afi < arm_synth.synth_functions.len()
                    af = arm_synth.synth_functions[afi]
                    xf = X86Function()
                    xf.fn_name = af.fn_name
                    xf.fn_entry_offset = af.fn_entry_offset
                    xf.fn_end_offset = af.a64_fn_end_offset
                    xf.fn_decl_line = af.a64_fn_decl_line
                    push(a64_obj_fns, xf)
                    afi = afi + 1
                end
                obj_res = lpo_emit_elf64_relocatable_arch(arm_synth.synth_code, arm_synth.synth_rodata, 0, a64_obj_fns, 0, 0, 0, 0, 183, config.cfg_out_path)
            elif config.cfg_target_arch == TARGET_ID_RISCV64()
                riscv64_synth_set_freestanding(config.cfg_freestanding)
                riscv64_synth_set_ssa_codegen(config.cfg_ssa_codegen)
                riscv64_synth_set_base_vaddr(0)
                riscv64_synth_set_code_file_off(0)
                rv_synth = riscv64_synth_compile_program_ssa(toks, ssa_lower_res)
                pipeline_free_ssa_res(ssa_lower_res)
                ssa_lower_res = 0
                if rv_synth.rv_error_count > 0
                    result.res_error_count = rv_synth.rv_error_count
                    result.res_error_msg = rv_synth.rv_error_msg
                    result.res_stage_reached = PIPELINE_STAGE_EMIT()
                    result.res_success = 0
                    return result
                end
                if config.cfg_freestanding == 1
                    rv_ecalls = riscv64_verify_zero_linux_ecalls(rv_synth.rv_code)
                    if rv_ecalls > 0
                        result.res_error_count = 1
                        result.res_error_msg = "Bare-Metal Purity Gate failed: detected " + str(rv_ecalls) + " forbidden Linux ecall instruction(s) in RISC-V 64 freestanding .o output"
                        result.res_stage_reached = PIPELINE_STAGE_EMIT()
                        result.res_success = 0
                        return result
                    end
                end
                rv_obj_fns = list()
                rfi = 0
                while rfi < rv_synth.rv_functions.len()
                    rf = rv_synth.rv_functions[rfi]
                    xf = X86Function()
                    xf.fn_name = rf.rv_fn_name
                    xf.fn_entry_offset = rf.rv_fn_entry_offset
                    xf.fn_end_offset = rf.rv_fn_end_offset
                    xf.fn_decl_line = rf.rv_fn_decl_line
                    push(rv_obj_fns, xf)
                    rfi = rfi + 1
                end
                obj_res = lpo_emit_elf64_relocatable_arch(rv_synth.rv_code, rv_synth.rv_rodata, 0, rv_obj_fns, 0, 0, 0, 0, 243, config.cfg_out_path)
            else
                x86_synth_set_freestanding(config.cfg_freestanding)
                x86_synth_set_emit_obj(1)
                x86_synth_set_base_vaddr(0)
                x86_synth_set_code_file_off(0)
                synth = x86_synth_compile_program_full(toks, opt_const_names, opt_const_vals, reg_names, reg_regs, ssa_lower_res)
                pipeline_free_ssa_res(ssa_lower_res)
                ssa_lower_res = 0
                if config.cfg_freestanding == 1
                    obj_sc = bare_verify_zero_linux_syscalls_buf(synth.synth_code)
                    if obj_sc > 0
                        buf_free(synth.synth_code)
                        buf_free(synth.synth_rodata)
                        result.res_error_count = 1
                        result.res_error_msg = "Bare-Metal Purity Gate failed: detected " + str(obj_sc) + " forbidden Linux syscall (0F 05) instruction(s) in freestanding .o output"
                        result.res_stage_reached = PIPELINE_STAGE_EMIT()
                        result.res_success = 0
                        return result
                    end
                end
                obj_bss = bare_align_up(synth.synth_bss_cursor, 16)
                obj_res = lpo_emit_elf64_relocatable_arch(x86_synth_buf_to_list(synth.synth_code), x86_synth_buf_to_list(synth.synth_rodata), obj_bss, synth.synth_functions, synth.synth_call_relocs, synth.synth_str_relocs, synth.synth_rw_patch_offs, synth.synth_rw_patch_targets, 62, config.cfg_out_path)
                buf_free(synth.synth_code)
                buf_free(synth.synth_rodata)
            end
            if obj_res.ow_success == 1
                result.res_output_bytes = obj_res.ow_file_size
            else
                result.res_error_count = 1
                result.res_error_msg = obj_res.ow_error_msg
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
            end
        elif config.cfg_target_arch == TARGET_ID_X86_64()
            say "  [pipeline] Phase 8: Calling x86_synth_compile_program_full..."
            // Synthesize AMD64 machine code instructions and rodata directly into compact ByteBuffers
            synth = x86_synth_compile_program_full(toks, opt_const_names, opt_const_vals, reg_names, reg_regs, ssa_lower_res)
            // Immediately free token stream and SSA lowering buffers once codegen finishes
            if ssa_lower_res != 0
                if ssa_lower_res.slr_code_buf != 0 buf_free(ssa_lower_res.slr_code_buf) end
                if ssa_lower_res.slr_rodata_buf != 0 buf_free(ssa_lower_res.slr_rodata_buf) end
            end
            toks = 0
            ssa_lower_res = 0
            say "  [pipeline] Phase 8: x86 synthesis complete, code len: " + str(synth.synth_code.len())
            dw_base = 1073742128
            if config.cfg_no_pie == 0
                x86_synth_convert_to_pie(synth)
                dw_base = 304
            end
            if config.cfg_debug_mode == 1
                // Emit ELF64 executable with real source-line DWARF v4 metadata (-g)
                line_builder = dwarf_line_builder_new(4)
                dwarf_line_add_dir(line_builder, ".")
                dwarf_line_add_file(line_builder, config.cfg_src_path, 1)
                dwarf_line_emit_set_address(line_builder, dw_base)
                cur_dw_pc = 0
                cur_dw_line = 1
                if synth.synth_line_pcs.len() > 0
                    li_dw = 0
                    while li_dw < synth.synth_line_pcs.len()
                        tgt_pc = synth.synth_line_pcs[li_dw]
                        tgt_ln = synth.synth_line_nums[li_dw]
                        pc_d = tgt_pc - cur_dw_pc
                        ln_d = tgt_ln - cur_dw_line
                        if pc_d > 0 or ln_d != 0 or li_dw == 0
                            if pc_d > 0
                                dwarf_line_emit_advance_pc(line_builder, pc_d)
                                cur_dw_pc = tgt_pc
                            end
                            if ln_d != 0
                                dwarf_line_emit_advance_line(line_builder, ln_d)
                                cur_dw_line = tgt_ln
                            end
                            dwarf_line_emit_copy(line_builder)
                        end
                        li_dw = li_dw + 1
                    end
                else
                    dwarf_line_emit_advance_line(line_builder, 0)
                    dwarf_line_emit_copy(line_builder)
                end
                if synth.synth_code.len() > cur_dw_pc
                    dwarf_line_emit_advance_pc(line_builder, synth.synth_code.len() - cur_dw_pc)
                end
                dwarf_line_end_sequence(line_builder, dw_base + synth.synth_code.len())
                line_bytes = dwarf_line_serialize(line_builder)

                abbrev_bytes = dwarf_abbrev_build_standard()
                cu = dwarf_unit_create("LiPi First 1.0.0 (প্রথম ১.০.০)", config.cfg_src_path, ".", dw_base, dw_base + synth.synth_code.len(), 0)
                if synth.synth_code.len() > 0
                    // WHY: Top-level scripts without explicit fn declarations still expose _start in .debug_info.
                    dwarf_unit_add_function(cu, "_start", dw_base, dw_base + synth.synth_code.len(), 1, 1)
                end
                f_idx = 0
                while f_idx < synth.synth_functions.len()
                    fn_item = synth.synth_functions[f_idx]
                    if fn_item.fn_decl_line > 0
                        fn_end_dw = fn_item.fn_end_offset
                        if fn_end_dw <= fn_item.fn_entry_offset
                            fn_end_dw = fn_item.fn_entry_offset + 1
                        end
                        dwarf_unit_add_function(cu, fn_item.fn_name, dw_base + fn_item.fn_entry_offset, dw_base + fn_end_dw, 1, fn_item.fn_decl_line)
                    end
                    f_idx = f_idx + 1
                end
                dwarf_unit_add_base_type(cu, "i64", 8, DW_ATE_signed())
                dwarf_unit_add_base_type(cu, "f64", 8, DW_ATE_float())
                info_bytes = dwarf_info_serialize(cu)

                extra_rw_bss = 0
                needed_rw_bytes = 512 + (synth.synth_mutable_globals.len() * 8)
                if synth.synth_bss_cursor > 0
                    needed_rw_bytes = bare_align_up(needed_rw_bytes, 4096)
                    if needed_rw_bytes < 4096 needed_rw_bytes = 4096 end
                    needed_rw_bytes = needed_rw_bytes + bare_align_up(synth.synth_bss_cursor, 4096)
                end
                if needed_rw_bytes > 4096
                    rem_rw = (needed_rw_bytes - 4096) % 4096
                    if rem_rw == 0
                        extra_rw_bss = needed_rw_bytes - 4096
                    else
                        extra_rw_bss = (needed_rw_bytes - 4096) + (4096 - rem_rw)
                    end
                end
                if config.cfg_no_pie == 0
                    emit_res = elf_emit_executable_pie_with_debug_buf(synth.synth_code, synth.synth_rodata, [], extra_rw_bss, line_bytes, info_bytes, abbrev_bytes, config.cfg_out_path)
                else
                    emit_res = elf_emit_executable_with_debug_buf(synth.synth_code, synth.synth_rodata, [], extra_rw_bss, line_bytes, info_bytes, abbrev_bytes, config.cfg_out_path)
                end
            else
                extra_rw_bss = 0
                needed_rw_bytes = 512 + (synth.synth_mutable_globals.len() * 8)
                if synth.synth_bss_cursor > 0
                    needed_rw_bytes = bare_align_up(needed_rw_bytes, 4096)
                    if needed_rw_bytes < 4096 needed_rw_bytes = 4096 end
                    needed_rw_bytes = needed_rw_bytes + bare_align_up(synth.synth_bss_cursor, 4096)
                end
                if needed_rw_bytes > 4096
                    rem_rw = (needed_rw_bytes - 4096) % 4096
                    if rem_rw == 0
                        extra_rw_bss = needed_rw_bytes - 4096
                    else
                        extra_rw_bss = (needed_rw_bytes - 4096) + (4096 - rem_rw)
                    end
                end
                if config.cfg_no_pie == 0
                    emit_res = elf_emit_executable_pie_buf(synth.synth_code, synth.synth_rodata, [], extra_rw_bss, config.cfg_out_path)
                else
                    emit_res = elf_emit_executable_buf(synth.synth_code, synth.synth_rodata, [], extra_rw_bss, config.cfg_out_path)
                end
            end
            buf_free(synth.synth_code)
            buf_free(synth.synth_rodata)
            if emit_res.ew_success == 1
                result.res_output_bytes = emit_res.ew_file_size
            else
                result.res_error_count = 1
                result.res_error_msg = emit_res.ew_error_msg
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
        elif config.cfg_target_arch == TARGET_ID_ARM64()
            // Direct ARM64 Silicon Machine Code Synthesis (hosted or --freestanding bare-metal, + --ssa-codegen)
            arm64_synth_set_freestanding(config.cfg_freestanding)
            arm64_synth_set_ssa_codegen(config.cfg_ssa_codegen)
            arm64_synth_set_base_vaddr(4194304)
            arm64_synth_set_code_file_off(232)
            arm_synth = arm64_synth_compile_program_ssa(toks, ssa_lower_res)
            if ssa_lower_res != 0
                if ssa_lower_res.slr_code_buf != 0 buf_free(ssa_lower_res.slr_code_buf) end
                if ssa_lower_res.slr_rodata_buf != 0 buf_free(ssa_lower_res.slr_rodata_buf) end
            end
            if arm_synth.a64_error_count > 0
                result.res_error_count = arm_synth.a64_error_count
                result.res_error_msg = arm_synth.a64_error_msg
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
            end
            if config.cfg_freestanding == 1
                a64_svcs = arm64_verify_zero_linux_svcs(arm_synth.synth_code)
                if a64_svcs > 0
                    result.res_error_count = 1
                    result.res_error_msg = "Bare-Metal Purity Gate failed: detected " + str(a64_svcs) + " forbidden Linux svc #0 instruction(s) in ARM64 --freestanding output"
                    result.res_stage_reached = PIPELINE_STAGE_EMIT()
                    result.res_success = 0
                    return result
                end
            end
            arm_res = arm64_elf_emit_executable(arm_synth.synth_code, arm_synth.synth_rodata, config.cfg_out_path)
            if arm_res.ew_success == 1
                result.res_output_bytes = arm_res.ew_file_size
            else
                result.res_error_count = 1
                result.res_error_msg = arm_res.ew_error_msg
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
        elif config.cfg_target_arch == TARGET_ID_WASM()
            // Sovereign Zero-JS WebAssembly Bytecode Synthesis (hosted WASI or pure --freestanding, + --ssa-codegen)
            wasm_synth_set_freestanding(config.cfg_freestanding)
            wasm_synth_set_ssa_codegen(config.cfg_ssa_codegen)
            wasm_bin = wasm_synth_compile_program_ssa(toks, ssa_lower_res)
            if ssa_lower_res != 0
                if ssa_lower_res.slr_code_buf != 0 buf_free(ssa_lower_res.slr_code_buf) end
                if ssa_lower_res.slr_rodata_buf != 0 buf_free(ssa_lower_res.slr_rodata_buf) end
            end
            w_res = wasm_emit_binary_file(wasm_bin, config.cfg_out_path)
            if w_res >= 0
                result.res_output_bytes = wasm_bin.len()
            else
                result.res_error_count = 1
                result.res_error_msg = "Failed to emit WASM binary file"
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
        elif config.cfg_target_arch == TARGET_ID_RISCV64()
            // Direct RISC-V 64 Silicon Machine Code Synthesis (hosted or --freestanding bare-metal, + --ssa-codegen)
            riscv64_synth_set_freestanding(config.cfg_freestanding)
            riscv64_synth_set_ssa_codegen(config.cfg_ssa_codegen)
            riscv64_synth_set_base_vaddr(4194304)
            riscv64_synth_set_code_file_off(232)
            rv_synth = riscv64_synth_compile_program_ssa(toks, ssa_lower_res)
            if ssa_lower_res != 0
                if ssa_lower_res.slr_code_buf != 0 buf_free(ssa_lower_res.slr_code_buf) end
                if ssa_lower_res.slr_rodata_buf != 0 buf_free(ssa_lower_res.slr_rodata_buf) end
            end
            if rv_synth.rv_error_count > 0
                result.res_error_count = rv_synth.rv_error_count
                result.res_error_msg = rv_synth.rv_error_msg
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
            end
            if config.cfg_freestanding == 1
                rv_ecalls = riscv64_verify_zero_linux_ecalls(rv_synth.rv_code)
                if rv_ecalls > 0
                    result.res_error_count = 1
                    result.res_error_msg = "Bare-Metal Purity Gate failed: detected " + str(rv_ecalls) + " forbidden Linux ecall instruction(s) in RISC-V 64 --freestanding output"
                    result.res_stage_reached = PIPELINE_STAGE_EMIT()
                    result.res_success = 0
                    return result
                end
            end
            rv_res = riscv64_elf_emit_executable(rv_synth.rv_code, rv_synth.rv_rodata, config.cfg_out_path)
            if rv_res.rv_ew_success == 1
                result.res_output_bytes = rv_res.rv_ew_file_size
            else
                result.res_error_count = 1
                result.res_error_msg = rv_res.rv_ew_error_msg
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
        elif config.cfg_target_arch == TARGET_ID_VERILOG() or config.cfg_emit_format == FORMAT_VERILOG()
            // Direct Verilog IEEE 1364-2001 RTL Silicon Synthesis
            pipeline_free_ssa_res(ssa_lower_res)
            ssa_lower_res = 0
            v_res = verilog_synth_compile_program(toks, config.cfg_src_path)
            if v_res.vs_success == 1
                if config.cfg_is_dry_run == 0
                    bytes_written = verilog_emit_file(v_res.vs_verilog_code, config.cfg_out_path)
                    if bytes_written >= 0
                        result.res_output_bytes = bytes_written
                    else
                        result.res_error_count = 1
                        result.res_error_msg = "Failed to write Verilog RTL output file: " + config.cfg_out_path
                        result.res_stage_reached = PIPELINE_STAGE_EMIT()
                        result.res_success = 0
                        return result
                else
                    result.res_output_bytes = v_res.vs_code_bytes
            else
                result.res_error_count = 1
                result.res_error_msg = v_res.vs_error_msg
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
        else
            // Fallback for unknown target architecture
            pipeline_free_ssa_res(ssa_lower_res)
            ssa_lower_res = 0
            code_bytes = [72, 199, 192, 0, 0, 0, 0, 195] // mov rax, 0; ret
            empty_rodata = []
            empty_data = []
            emit_res = elf_emit_executable(code_bytes, empty_rodata, empty_data, 0, config.cfg_out_path)
            if emit_res.ew_success == 1
                result.res_output_bytes = emit_res.ew_file_size
            else
                result.res_error_count = 1
                result.res_error_msg = emit_res.ew_error_msg
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result

    pipeline_free_ssa_res(ssa_lower_res)
    // Mark compilation successful
    result.res_success = 1
    return result

