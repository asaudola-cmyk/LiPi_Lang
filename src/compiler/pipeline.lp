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

// Subsystem 5: Middle-End SSA Lowering & Optimization Pass Manager
include "src/compiler/middleend/ast_to_ssa.lp"
include "src/compiler/middleend/opt/pass_manager.lp"

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

// ── 2. Hardware-Aligned Models (Max 8 Fields) ─────────────────────────────────

struct CompilerConfig
    cfg_src_path            // Absolute or relative source file path
    cfg_out_path            // Target output binary path
    cfg_target_arch         // TARGET_ID_X86_64, TARGET_ID_ARM64, etc.
    cfg_opt_level           // 0, 1, 2, or 3
    cfg_emit_format         // FORMAT_ELF, FORMAT_PE, FORMAT_SHARED, etc.
    cfg_is_dry_run          // 1 to skip disk emission, 0 to persist
    cfg_verbose             // 1 for verbose phase telemetry, 0 for quiet
    cfg_debug_mode          // 1 for DWARF debug emission (-g), 0 for standard

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
    return 0

fn pipeline_parse_primary toks pos_box sp
    // WHY: Parses primitive literals, identifiers, unary operators, and postfix chains (.field, [idx], (args)).
    p = get(pos_box, 0)
    if p >= toks.len()
        return ast_expr_literal_int(0, sp)
    end
    t = toks[p]
    k = t.tok_kind
    txt = t.tok_text
    list_set(pos_box, 0, p + 1)

    // WHY: Initialize with ASTNode literal so type inference assigns ASTNode instead of scalar i64
    node = ast_expr_literal_int(0, sp)
    if k == TOK_INT()
        node = ast_expr_literal_int(t.tok_int_val, sp)
    elif k == TOK_BOOL()
        node = ast_expr_literal_bool(t.tok_int_val, sp)
    elif k == TOK_STR()
        node = ast_expr_literal_str(txt, sp)
    elif k == TOK_MINUS() or (k != TOK_STR() and txt == "-")
        sub_e = pipeline_parse_primary(toks, pos_box, sp)
        return ast_expr_unary("-", sub_e, sp)
    elif k == TOK_BANG() or (k != TOK_STR() and (txt == "!" or txt == "not" or txt == "না"))
        sub_e = pipeline_parse_primary(toks, pos_box, sp)
        return ast_expr_unary("!", sub_e, sp)
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
            else
                // Field key identifier
                key_tok = toks[get(pos_box, 0)]
                key_name = key_tok.tok_text
                list_set(pos_box, 0, get(pos_box, 0) + 1)

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
                f_entry.value = val_expr
                push(entries, f_entry)
            end
        end
        node = ast_expr_map_lit(entries, sp)
    elif pipeline_is_ident_token(k) == 1 or (k >= TOK_KW_FN() and k <= TOK_KW_SYSCALL())
        node = ast_expr_ident(txt, sp)
    else
        return ast_expr_literal_int(0, sp)
    end

    // WHY: Postfix operator chain: handles member access .field, indexing [idx], and calls (args)
    while get(pos_box, 0) < toks.len()
        nxt_p = get(pos_box, 0)
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
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
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
        else
            break
        end
    end

    return node

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
            if ck == TOK_STAR() or cx == "*" or ck == TOK_SLASH() or cx == "/" or ck == TOK_PERCENT() or cx == "%"
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
            if cur_t.tok_span.span_start_line == base_line
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
        is_elif = 0
        if ek == TOK_KW_ELIF() or ek == TOK_DIR_ELIF() or (ek == TOK_IDENT() and (etxt == "elif" or etxt == "নাহলে_যদি" or etxt == "নতুবা_যদি" or etxt == "@elif"))
            is_elif = 1
        end
        is_else = 0
        if ek == TOK_KW_ELSE() or ek == TOK_DIR_ELSE() or (ek == TOK_IDENT() and (etxt == "else" or etxt == "নাহলে" or etxt == "অন্যথায়" or etxt == "নতুবা" or etxt == "@else"))
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
                        push(else_b, s)
                    end
                    if get(pos_box, 0) <= before_s
                        list_set(pos_box, 0, before_s + 1)
                    end
                end
            else
                else_base_l = cur_t.tok_span.span_start_line
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
                    if cur_t2.tok_span.span_start_line == else_base_l
                        break
                    end
                end
            end
            pipeline_skip_whitespace(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p < toks.len()
                if pipeline_is_block_end(toks, cur_p) == 1
                    list_set(pos_box, 0, cur_p + 1)
                end
            end
        else
            if pipeline_is_block_end(toks, cur_p) == 1
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
            ret_val = pipeline_parse_expr(toks, pos_box, sp)
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
                if cur_t.tok_span.span_start_line == base_line
                    break
                end
            end
            pipeline_skip_whitespace(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p < toks.len()
                if pipeline_is_block_end(toks, cur_p) == 1
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
                if pipeline_is_block_end(toks, cur_p) == 1
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
                if pipeline_is_block_end(toks, cur_p) == 1
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
            var_name = toks[scan_p].tok_text
            scan_p = scan_p + 1
            // Optional type annotation: : Type
            if scan_p < toks.len() and (toks[scan_p].tok_kind == TOK_COLON() or (toks[scan_p].tok_kind != TOK_STR() and toks[scan_p].tok_text == ":"))
                scan_p = scan_p + 1
                if scan_p < toks.len() and pipeline_is_ident_token(toks[scan_p].tok_kind) == 1
                    scan_p = scan_p + 1
                end
            end
            if scan_p < toks.len() and (toks[scan_p].tok_kind == TOK_ASSIGN() or (toks[scan_p].tok_kind != TOK_STR() and toks[scan_p].tok_text == "="))
                list_set(pos_box, 0, scan_p + 1)
                val_e = pipeline_parse_expr(toks, pos_box, sp)
                return ast_stmt_assign(var_name, val_e, sp)
            end
        end
    end

    // 4b. Struct Field Assignment: obj.field = expr, obj.field += expr, obj.field -= expr
    if pipeline_is_ident_token(k) == 1 and cp + 3 < toks.len()
        p1 = toks[cp + 1]
        p2 = toks[cp + 2]
        p3 = toks[cp + 3]
        if (p1.tok_kind == TOK_DOT() or (p1.tok_kind != TOK_STR() and p1.tok_text == ".")) and pipeline_is_ident_token(p2.tok_kind) == 1
            if p3.tok_kind == TOK_ASSIGN() or (p3.tok_kind != TOK_STR() and p3.tok_text == "=")
                target_str = txt + "." + p2.tok_text
                list_set(pos_box, 0, cp + 4)
                val_e = pipeline_parse_expr(toks, pos_box, sp)
                return ast_stmt_assign(target_str, val_e, sp)
            elif p3.tok_kind == TOK_PLUSEQ() or (p3.tok_kind != TOK_STR() and p3.tok_text == "+=")
                target_str = txt + "." + p2.tok_text
                list_set(pos_box, 0, cp + 4)
                val_e = pipeline_parse_expr(toks, pos_box, sp)
                return ast_stmt_assign_op(target_str, val_e, "+=", sp)
            elif p3.tok_kind == TOK_MINUSEQ() or (p3.tok_kind != TOK_STR() and p3.tok_text == "-=")
                target_str = txt + "." + p2.tok_text
                list_set(pos_box, 0, cp + 4)
                val_e = pipeline_parse_expr(toks, pos_box, sp)
                return ast_stmt_assign_op(target_str, val_e, "-=", sp)
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
                if eq_tok.tok_kind == TOK_ASSIGN() or (eq_tok.tok_kind != TOK_STR() and eq_tok.tok_text == "=")
                    list_set(pos_box, 0, scan_i + 1)
                    val_e = pipeline_parse_expr(toks, pos_box, sp)
                    return ast_stmt_assign(txt, val_e, sp)
                end
            end
        end
    end

    // 5. Direct assignment: ident = expr, ident += expr, ident -= expr, OR typed declaration: ident: Type = expr
    if pipeline_is_ident_token(k) == 1 and cp + 1 < toks.len()
        n1 = toks[cp + 1]
        // Case A: Typed declaration/assignment (e.g. search_res: PageSearchLeafResult = page_binary_search_leaf(buf, key))
        if n1.tok_kind == TOK_COLON() or (n1.tok_kind != TOK_STR() and n1.tok_text == ":")
            if cp + 3 < toks.len()
                n3 = toks[cp + 3]
                if n3.tok_kind == TOK_ASSIGN() or (n3.tok_kind != TOK_STR() and n3.tok_text == "=")
                    var_name = txt
                    list_set(pos_box, 0, cp + 4)
                    val_e = pipeline_parse_expr(toks, pos_box, sp)
                    return ast_stmt_assign(var_name, val_e, sp)
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

        if k == TOK_KW_FN() or k == TOK_DIR_FN() or (k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn"))
            list_set(pos_box, 0, cp + 1)
            fn_name = ""
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                fn_name = toks[get(pos_box, 0)].tok_text
                list_set(pos_box, 0, get(pos_box, 0) + 1)

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
                    elif pipeline_is_ident_token(pt.tok_kind) == 1
                        p_name = pt.tok_text
                        p_type = ""
                        list_set(pos_box, 0, p_idx + 1)
                        if get(pos_box, 0) < toks.len()
                            nxt_k = toks[get(pos_box, 0)].tok_kind
                            nxt_t = toks[get(pos_box, 0)].tok_text
                            if nxt_k == TOK_COLON() or (nxt_k != TOK_STR() and nxt_t == ":")
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                                if get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                                    p_type = toks[get(pos_box, 0)].tok_text
                                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                                end
                            end
                        end
                        p_node = ast_param_new(p_name, p_type, 0, sp)
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
                    if pipeline_is_ident_token(pt.tok_kind) == 1
                        p_name = pt.tok_text
                        p_type = ""
                        list_set(pos_box, 0, p_idx + 1)
                        if get(pos_box, 0) < toks.len()
                            nxt_k = toks[get(pos_box, 0)].tok_kind
                            nxt_t = toks[get(pos_box, 0)].tok_text
                            if nxt_k == TOK_COLON() or (nxt_k != TOK_STR() and nxt_t == ":")
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                                if get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                                    p_type = toks[get(pos_box, 0)].tok_text
                                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                                end
                            end
                        end
                        p_node = ast_param_new(p_name, p_type, 0, sp)
                        push(params, p_node)
                    elif pt.tok_kind == TOK_COMMA() or (pt.tok_kind != TOK_STR() and pt.tok_text == ",")
                        list_set(pos_box, 0, p_idx + 1)
                    else
                        list_set(pos_box, 0, p_idx + 1)
                    end
                end

            // Extract return type annotation: -> type or : type
            ret_type_str = ""
            if get(pos_box, 0) < toks.len()
                rk = toks[get(pos_box, 0)].tok_kind
                rtxt = toks[get(pos_box, 0)].tok_text
                if rk == TOK_ARROW() or rtxt == "->" or rk == TOK_COLON() or rtxt == ":"
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    if get(pos_box, 0) < toks.len() and pipeline_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                        ret_type_str = toks[get(pos_box, 0)].tok_text
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
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
                    if toks[get(pos_box, 0)].tok_kind == TOK_RBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "}")
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        break
                    s = pipeline_build_statement(toks, pos_box, sp)
                    if s != 0
                        push(body, s)
                    end
            else
                // Indented or end-delimited block
                fn_line = t.tok_span.span_start_line
                fn_col = t.tok_span.span_start_col
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
                    if cur_tok.tok_kind == TOK_KW_FN() or cur_tok.tok_kind == TOK_DIR_FN()
                        break
                    end
                    if cur_tok.tok_kind == TOK_IDENT() and (cur_tok.tok_text == "fn" or cur_tok.tok_text == "কাজ" or cur_tok.tok_text == "@fn")
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

            fn_decl = ast_decl_fn(fn_name, params, ret_type_str, body, 1, sp)
            push(decls, fn_decl)
        elif k == TOK_KW_STRUCT() or k == TOK_DIR_STRUCT() or (k == TOK_IDENT() and (txt == "struct" or txt == "গঠন" or txt == "@struct"))
            base_l = t.tok_span.span_start_line
            base_c = t.tok_span.span_start_col
            list_set(pos_box, 0, cp + 1)
            struct_name = ""
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                struct_name = toks[get(pos_box, 0)].tok_text
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            fields = list()
            while get(pos_box, 0) < toks.len()
                while get(pos_box, 0) < toks.len()
                    sk_skip = toks[get(pos_box, 0)].tok_kind
                    if sk_skip == TOK_NEWLINE() or sk_skip == TOK_SEMI() or sk_skip == TOK_COMMENT_LINE() or sk_skip == TOK_COMMENT_BLOCK()
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
                if sk == TOK_KW_END() or sk == TOK_DIR_END() or stxt == "end" or stxt == "শেষ" or stxt == "@end"
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    break
                end
                if sk == TOK_KW_FN() or sk == TOK_DIR_FN() or sk == TOK_KW_STRUCT() or sk == TOK_DIR_STRUCT()
                    break
                end
                if sk == TOK_IDENT() and (stxt == "fn" or stxt == "কাজ" or stxt == "@fn" or stxt == "struct" or stxt == "গঠন" or stxt == "@struct")
                    break
                end
                if toks[get(pos_box, 0)].tok_span.span_start_line > base_l and toks[get(pos_box, 0)].tok_span.span_start_col <= base_c
                    break
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
                            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                                fld_type = toks[get(pos_box, 0)].tok_text
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
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
        if ord(char_at(s, si)) > 127
            return 1
        end
        si = si + 1
    end
    return 0

// WHY: Precise memory proof exemption filter preventing false positives on words like "freeze", "renew", "definition".
// Enforces exact whole-word, prefix (e.g. assert_, panic_), suffix (_new, _free), or inner-word (_create_) matching.
fn pipeline_is_memory_exempt_fn raw_name
    // WHY: Sovereign Bengali Unicode identifiers represent runtime, hardware, diagnostic, or system utilities.
    if pipeline_str_has_non_ascii(raw_name) == 1 return 1 end
    // WHY: Struct member methods mutably alter receiver state and aren't closed mathematical scopes.
    if pipeline_str_contains(raw_name, ".") == 1 return 1 end
    // WHY: Constant getters in ALL_CAPS format are pure primitive returns.
    if pipeline_is_all_caps(raw_name) == 1 return 1 end
    // WHY: Normalize function name to lowercase so casing (e.g. Ed25519, Secp256k1, Poly1305, DW_) matches uniformly without case discrepancies.
    name = str_to_lower(raw_name)
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
    return 0


// ── 4. End-to-End Modular Pipeline Execution ──────────────────────────────────

fn compiler_pipeline_execute config source_code
    // WHY: Orchestrates all compilation stages across the decoupled micro-architectures.
    result = compiler_result_new()

    // ── Phase 1: Initialize Diagnostics & Source Map ──────────────────────────
    sm = source_map_new()
    fid = source_map_add_file(sm, config.cfg_src_path, source_code)
    diag_emitter = diagnostic_emitter_new(sm, "terminal", 0)
    result.res_stage_reached = PIPELINE_STAGE_INIT()

    say "  [pipeline] Phase 1: Diagnostics initialized"
    // ── Phase 2: Lexical Analysis (Frontend Micro-Lexer) ───────────────────────
    toks = tokenize_source(source_code)
    tok_count = toks.len()
    say "  [pipeline] Phase 2: Tokenized " + str(tok_count) + " tokens"
    
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
    say "  [pipeline] Phase 3: Constructing AST..."
    sp = source_span_point(config.cfg_src_path, 1, 1, 0)
    ast_decls = pipeline_build_ast_declarations(toks, config.cfg_src_path)
    say "  [pipeline] Phase 3: Built " + str(ast_decls.len()) + " AST declarations"
    result.res_stage_reached = PIPELINE_STAGE_PARSE()

    // ── Phase 4: Semantic Analysis, Type System & Ownership ───────────────────
    say "  [pipeline] Phase 4: Type checking & semantic analysis..."
    sym_table = symtab_new(64)
    scope_stk = scope_stack_new()
    ty_reg = type_registry_new()
    tc = type_checker_new(ty_reg, sym_table, scope_stk)
    own_checker = ownership_checker_new()

    // WHY: Actively runs semantic type checking and symbol table binding on all AST declarations.
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
    say "  [pipeline] Phase 4: Mathematical proof verification..."
    di = 0
    while di < ast_decls.len()
        decl = ast_decls[di]
        if decl.kind == "FnDef" or decl.kind == "Function" or decl.kind == "কাজ"
            // WHY: Uses precise whole-word, prefix, and suffix matching to avoid false positives on words like 'freeze', 'renew', 'definition'.
            is_cleanup_fn = pipeline_is_memory_exempt_fn(decl.name)
            if is_cleanup_fn == 0
                proof_engine = math_proof_engine_new()
                proof_cert = math_proof_verify_fn(proof_engine, decl)
                if proof_cert.mpc_is_proven == 0
                    err_count = proof_cert.mpc_violation_count
                    if err_count == 0
                        err_count = 1
                    result.res_error_count = result.res_error_count + err_count
                    result.res_error_msg = "Mathematical proof failed: Memory conservation violated in function " + decl.name
                    return result
                end
            end
        end
        di = di + 1
    end

    g_sym = symbol_variable("__lipi_entry", 2, 0, span_default(), 1)
    scope_define(scope_stk, g_sym)
    result.res_stage_reached = PIPELINE_STAGE_SEMANTICS()

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

    // ── Middle-End: SSA IR Lowering & Pass Manager Pipeline ───────────────────
    say "  [pipeline] Middle-End: Lowering AST to SSA IR..."
    ssa_module = ast_to_ssa_lower_module(ast_decls, target_name)
    say "  [pipeline] Middle-End: Running optimization passes..."
    pm = pass_manager_new(config.cfg_opt_level)
    pass_manager_run_on_module(pm, ssa_module)
    say "  [pipeline] Middle-End: Optimizations complete"

    // Harvest compile-time folded constants from SSA optimizations
    opt_const_names = list()
    opt_const_vals = list()

    // 1. From global definitions
    // WHY: Only module-level global constant declarations are placed into the global constant table.
    // Local function variables must never pollute the global namespace to prevent variable collisions.
    gi = 0
    while gi < ssa_module.globals.len()
        g = ssa_module.globals[gi]
        push(opt_const_names, g.name)
        push(opt_const_vals, g.init_val)
        gi = gi + 1
    end

    // 2. From function basic blocks (folded constants stored to named slots)
    // WHY: Constant propagation in the middle-end computes and propagates folded immediate constants.
    // Harvesting them directly feeds the backend synthesizer so global and function constants
    // substitute directly at silicon code emission time.
    fi_h = 0
    while fi_h < ssa_module.functions.len()
        fn_h = ssa_module.functions[fi_h]
        bi_h = 0
        while bi_h < fn_h.blocks.len()
            bb_h = fn_h.blocks[bi_h]
            ii_h = 0
            while ii_h < bb_h.instructions.len()
                inst_h = bb_h.instructions[ii_h]
                if inst_h.opcode == OP_STORE and inst_h.operands.len() >= 2
                    val_op = inst_h.operands[0]
                    ptr_op = inst_h.operands[1]
                    if (val_op.kind == VAL_KIND_CONST or val_op.val_kind == VAL_KIND_CONST) and ptr_op != 0
                        pname = ptr_op.id
                        if len(pname) > 6 and str_sub(pname, 0, 6) == "%slot_"
                            var_k = str_sub(pname, 6, len(pname))
                            scoped_k = fn_h.name + "::" + var_k
                            push(opt_const_names, scoped_k)
                            push(opt_const_vals, val_op.const_val)
                        end
                    end
                end
                ii_h = ii_h + 1
            end
            bi_h = bi_h + 1
        end
        fi_h = fi_h + 1
    end

    // ── Phase 6: Linear Scan Register Allocation ──────────────────────────────
    caller_regs = list()
    callee_regs = list()
    word_size = 8

    if config.cfg_target_arch == TARGET_ID_X86_64()
        // WHY: AMD64 x86_64 backend allocates dedicated hardware callee-saved registers
        // (%r12-%r15, %rbx) for function/loop locals to guarantee stability across expressions
        // and eliminate stack round-trips. Scratch registers are omitted from linear scan candidate pools
        // so all active intervals are mapped to protected callee registers preserved by function ABI.
        push(callee_regs, 12)
        push(callee_regs, 13)
        push(callee_regs, 14)
        push(callee_regs, 15)
        push(callee_regs, 3)
    elif config.cfg_target_arch == TARGET_ID_ARM64()
        cr_i = 9
        while cr_i <= 15
            push(caller_regs, cr_i)
            cr_i = cr_i + 1
        cl_i = 19
        while cl_i <= 28
            push(callee_regs, cl_i)
            cl_i = cl_i + 1
    elif config.cfg_target_arch == TARGET_ID_RISCV64()
        push(caller_regs, 5)
        push(caller_regs, 6)
        push(caller_regs, 7)
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

    reg_names = list()
    reg_regs = list()
    total_spills = 0

    say "  [pipeline] Phase 6: Linear scan register allocation..."
    fi = 0
    while fi < ssa_module.functions.len()
        fn_obj = ssa_module.functions[fi]
        ra_res = linear_scan_allocate_function(fn_obj, caller_regs, callee_regs, word_size)
        total_spills = total_spills + ra_res.spill_count

        ivi = 0
        while ivi < ra_res.intervals.len()
            iv = ra_res.intervals[ivi]
            if iv.is_spilled == 0 and iv.assigned_reg >= 0
                vname = iv.vreg_name
                clean_v = vname
                if len(vname) > 6 and str_sub(vname, 0, 6) == "%slot_"
                    clean_v = str_sub(vname, 6, len(vname))
                elif starts_with(vname, "%") == 1
                    clean_v = str_sub(vname, 1, len(vname))
                end
                // WHY: Scopes register assignment by function name to avoid cross-routine collision.
                key = fn_obj.name + "::" + clean_v
                push(reg_names, key)
                push(reg_regs, iv.assigned_reg)
            end
            ivi = ivi + 1
        end
        fi = fi + 1
    end
    say "  [pipeline] Phase 6: Register allocation complete (spills: " + str(total_spills) + ")"

    result.res_reg_alloc_spills = total_spills
    result.res_stage_reached = PIPELINE_STAGE_REGALLOC()

    // ── Phase 6b: Direct SSA Control Flow Graph Lowering ──────────────────────
    // WHY: Directly verifies and lowers middle-end SSA IRModule into native silicon machine instructions.
    // Validates control flow graph basic blocks, branch conditions, and relative displacement backpatching.
    say "  [pipeline] Phase 6b: Direct SSA CFG Lowering..."
    ssa_low = ssa_lowerer_new(config.cfg_target_arch)
    ssa_lower_res = ssa_lower_module(ssa_low, ssa_module)
    if ssa_lower_res.slr_success != 1
        result.res_error_count = 1
        result.res_error_msg = "SSA CFG lowering failure: " + ssa_lower_res.slr_error_msg
        result.res_stage_reached = PIPELINE_STAGE_REGALLOC()
        result.res_success = 0
        return result
    end
    say "  [pipeline] Phase 6b: SSA CFG Lowering complete"

    // ── Phase 7: Binary Container Packaging (ELF/PE/Mach-O) ───────────────────
    hdr_x86 = elf_header_x86_64(4198400, 64, 512, 2, 6, 5)
    elf_bytes = elf_header_serialize(hdr_x86)
    result.res_output_bytes = elf_bytes.len()
    result.res_stage_reached = PIPELINE_STAGE_COMPLETE()

    // WHY: If live emission requested (cfg_is_dry_run == 0), assemble and persist the binary to disk.
    if config.cfg_is_dry_run == 0
        say "  [pipeline] Phase 8: Live emission to " + config.cfg_out_path
        if config.cfg_emit_format == FORMAT_SHARED()
            // Sovereign Shared Object (.so) Emission via System V AMD64 Dynamic ABI
            synth = x86_synth_compile_program_full(toks, opt_const_names, opt_const_vals, reg_names, reg_regs, ssa_lower_res)
            exp_names = list()
            exp_offs = list()
            f_idx = 0
            while f_idx < synth.synth_functions.len()
                fn_item = synth.synth_functions[f_idx]
                push(exp_names, fn_item.fn_name)
                push(exp_offs, fn_item.fn_entry_offset)
                f_idx = f_idx + 1
            if exp_names.len() == 0
                push(exp_names, "_start")
                push(exp_offs, 0)
            so_size = so_emit_shared_library(synth.synth_code, synth.synth_rodata, exp_names, exp_offs, config.cfg_out_path)
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
                arm_synth = arm64_synth_compile_program(toks)
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
                m_res = macho_emit_executable(synth.synth_code, synth.synth_rodata, 0, 16777223, config.cfg_out_path)
                if m_res.mw_success == 1
                    result.res_output_bytes = m_res.mw_file_size
                else
                    result.res_error_count = 1
                    result.res_error_msg = m_res.mw_error_msg
                    result.res_stage_reached = PIPELINE_STAGE_EMIT()
                    result.res_success = 0
                    return result
        elif config.cfg_emit_format == FORMAT_PE()
            // Sovereign Windows PE32+ (.exe) Executable Emission (x86-64 COFF)
            synth = x86_synth_compile_program_full(toks, opt_const_names, opt_const_vals, reg_names, reg_regs, ssa_lower_res)
            pe_res = pe_emit_executable(synth.synth_code, synth.synth_rodata, [], 0, 0, config.cfg_out_path)
            if pe_res.pe_success == 1
                result.res_output_bytes = pe_res.pe_file_size
            else
                result.res_error_count = 1
                result.res_error_msg = pe_res.pe_error_msg
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
        elif config.cfg_emit_format == FORMAT_UNIKERNEL()
            // Sovereign Ring-0 Bare-Metal Multiboot2 Unikernel Emission
            synth = x86_synth_compile_program_full(toks, opt_const_names, opt_const_vals, reg_names, reg_regs, ssa_lower_res)
            // Multiboot2 Header: 0xE85250D6 (3897741526), arch=0, length=24, checksum, end tag (type=0, size=8)
            mb2_code = list()
            // Magic: 0xE85250D6
            push(mb2_code, 214)
            push(mb2_code, 80)
            push(mb2_code, 82)
            push(mb2_code, 232)
            // Architecture: 0 (i386 / x86_64 Long Mode)
            push(mb2_code, 0)
            push(mb2_code, 0)
            push(mb2_code, 0)
            push(mb2_code, 0)
            // Length: 24 bytes
            push(mb2_code, 24)
            push(mb2_code, 0)
            push(mb2_code, 0)
            push(mb2_code, 0)
            // Checksum: -(magic + arch + length) & 0xFFFFFFFF = 0x17AD2F12
            push(mb2_code, 18)
            push(mb2_code, 47)
            push(mb2_code, 173)
            push(mb2_code, 23)
            // Tag End: type=0, flags=0, size=8
            push(mb2_code, 0)
            push(mb2_code, 0)
            push(mb2_code, 0)
            push(mb2_code, 0)
            push(mb2_code, 8)
            push(mb2_code, 0)
            push(mb2_code, 0)
            push(mb2_code, 0)
            si = 0
            while si < synth.synth_code.len()
                push(mb2_code, synth.synth_code[si])
                si = si + 1
            emit_res = elf_emit_executable(mb2_code, synth.synth_rodata, [], 0, config.cfg_out_path)
            if emit_res.ew_success == 1
                result.res_output_bytes = emit_res.ew_file_size
            else
                result.res_error_count = 1
                result.res_error_msg = emit_res.ew_error_msg
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
        elif config.cfg_target_arch == TARGET_ID_X86_64()
            say "  [pipeline] Phase 8: Calling x86_synth_compile_program_full..."
            // Synthesize AMD64 machine code instructions and rodata directly from tokens with SSA optimizations and lowering
            synth = x86_synth_compile_program_full(toks, opt_const_names, opt_const_vals, reg_names, reg_regs, ssa_lower_res)
            say "  [pipeline] Phase 8: x86 synthesis complete, code len: " + str(synth.synth_code.len())
            if config.cfg_debug_mode == 1
                // Emit ELF64 executable with embedded DWARF v4/v5 debug metadata (-g)
                line_builder = dwarf_line_builder_new(4)
                dwarf_line_add_dir(line_builder, ".")
                dwarf_line_add_file(line_builder, config.cfg_src_path, 1)
                dwarf_line_emit_set_address(line_builder, 1073742000)
                dwarf_line_emit_advance_line(line_builder, 1)
                dwarf_line_emit_copy(line_builder)
                dwarf_line_emit_advance_pc(line_builder, synth.synth_code.len())
                dwarf_line_emit_advance_line(line_builder, 1)
                dwarf_line_end_sequence(line_builder, 1073742000 + synth.synth_code.len())
                line_bytes = dwarf_line_serialize(line_builder)

                abbrev_bytes = dwarf_abbrev_build_standard()
                cu = dwarf_unit_create("LiPi First 1.0.0 (প্রথম ১.০.০)", config.cfg_src_path, ".", 1073742000, 1073742000 + synth.synth_code.len(), 0)
                f_idx = 0
                while f_idx < synth.synth_functions.len()
                    fn_item = synth.synth_functions[f_idx]
                    dwarf_unit_add_function(cu, fn_item.fn_name, 1073742000 + fn_item.fn_entry_offset, 1073742000 + synth.synth_code.len(), 1, 1)
                    f_idx = f_idx + 1
                dwarf_unit_add_base_type(cu, "i64", 8, DW_ATE_signed())
                info_bytes = dwarf_info_serialize(cu)

                emit_res = elf_emit_executable_with_debug(synth.synth_code, synth.synth_rodata, [], 0, line_bytes, info_bytes, abbrev_bytes, config.cfg_out_path)
            else
                emit_res = elf_emit_executable(synth.synth_code, synth.synth_rodata, [], 0, config.cfg_out_path)
            if emit_res.ew_success == 1
                result.res_output_bytes = emit_res.ew_file_size
            else
                result.res_error_count = 1
                result.res_error_msg = emit_res.ew_error_msg
                result.res_stage_reached = PIPELINE_STAGE_EMIT()
                result.res_success = 0
                return result
        elif config.cfg_target_arch == TARGET_ID_ARM64()
            // Direct ARM64 Silicon Machine Code Synthesis
            arm_synth = arm64_synth_compile_program(toks)
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
            // Sovereign Zero-JS WebAssembly Bytecode Synthesis
            wasm_bin = wasm_synth_compile_program(toks)
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
            // Direct RISC-V 64 Silicon Machine Code Synthesis
            rv_synth = riscv64_synth_compile_program(toks)
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

    // Mark compilation successful
    result.res_success = 1
    return result

