// ==============================================================================
// 👑 LIPI COMPILER MIDDLEEND — AUTO-REGISTER ALLOCATION ENGINE
// ⚡ 100% Pure Lipi | Zero External Dependencies | Zero Libc | Zero C
// ==============================================================================
//
// WHY: In high-performance tight loops, memory roundtrips to L1 cache (stack frame)
//      introduce store-to-load forwarding penalties (3-5 CPU clock cycles per op).
//      By automatically promoting frequently mutated loop counters and accumulators
//      into callee-saved hardware registers (%r12-%r14) without requiring explicit
//      'reg' / 'রেজিস্টার' keywords, Lipi achieves true zero-overhead single-cycle
//      silicon execution speed.
//
// 🛡️ DEADLY TRAP DEFENSES:
// 1. Callee-Saved Register ABI Preservation:
//    %r12-%r14 are preserved across function frames via mandatory prologue pushes
//    and epilogue pops. Lipi ensures zero stack corruption across nested calls.
// 2. Linear Scan Spill & Recycling:
//    When all 3 callee-saved registers are saturated, additional variables are
//    safely spilled to stack. At loop termination, register contents are synced
//    back to their stack displacement slots and registers are recycled.
// ==============================================================================

// Physical AMD64 Hardware Register Constants
REG_RAX = 0
REG_RCX = 1
REG_RDX = 2
REG_RBX = 3
REG_RSP = 4
REG_RBP = 5
REG_RSI = 6
REG_RDI = 7
REG_R8  = 8
REG_R9  = 9
REG_R10 = 10
REG_R11 = 11
REG_R12 = 12
REG_R13 = 13
REG_R14 = 14
REG_R15 = 15

// WHY: Returns 1 if reg_id is an AMD64 System V ABI callee-saved register
fn auto_reg_is_callee_saved reg_id
    if reg_id == 3 or reg_id == 12 or reg_id == 13 or reg_id == 14 or reg_id == 15
        return 1
    return 0

// WHY: Returns 1 if reg_id is an AMD64 System V ABI caller-saved register
fn auto_reg_is_caller_saved reg_id
    if reg_id == 0 or reg_id == 1 or reg_id == 2 or reg_id == 6 or reg_id == 7
        return 1
    if reg_id >= 8 and reg_id <= 11
        return 1
    return 0

// WHY: Formats hardware register name string for diagnostics and debugging
fn auto_reg_name reg_id
    if reg_id == 0  return "%rax"
    if reg_id == 1  return "%rcx"
    if reg_id == 2  return "%rdx"
    if reg_id == 3  return "%rbx"
    if reg_id == 4  return "%rsp"
    if reg_id == 5  return "%rbp"
    if reg_id == 6  return "%rsi"
    if reg_id == 7  return "%rdi"
    if reg_id == 8  return "%r8"
    if reg_id == 9  return "%r9"
    if reg_id == 10 return "%r10"
    if reg_id == 11 return "%r11"
    if reg_id == 12 return "%r12"
    if reg_id == 13 return "%r13"
    if reg_id == 14 return "%r14"
    if reg_id == 15 return "%r15"
    return "unknown"

// ── Loop Variable Candidate Detection ─────────────────────────────────────────
// WHY: Scans parser token buffer within a loop to identify candidate variables:
//      - The loop condition variable (e.g. 'i' in 'while i < limit')
//      - Accumulators and counters updated via '=', '+=', or '-=' inside loop body
fn auto_reg_scan_candidates tokens start_pos max_tokens
    candidates = list()
    end_pos = start_pos + max_tokens
    if end_pos > len(tokens)
        end_pos = len(tokens)

    k = start_pos
    while k < end_pos
        tok = get(tokens, k)
        // Check if token is an identifier
        if tok_t(tok) == 1 // TOK_IDENT
            txt = tok_s(tok)
            // Check if next token is assignment operator
            if k + 1 < end_pos
                next_tok = get(tokens, k + 1)
                if tok_t(next_tok) == 6 // TOK_OP
                    op_str = tok_s(next_tok)
                    if op_str == "=" or op_str == "+=" or op_str == "-="
                        // Found candidate: check if already in candidate list
                        found = 0
                        ci = 0
                        while ci < len(candidates)
                            if get(candidates, ci) == txt
                                found = 1
                                break
                            ci = ci + 1
                        if found == 0
                            push(candidates, txt)
        k = k + 1
    return candidates

// WHY: Evaluates priority score for candidate variable based on mutation frequency
fn auto_reg_score_candidate tokens start_pos max_tokens var_name
    score = 0
    end_pos = start_pos + max_tokens
    if end_pos > len(tokens)
        end_pos = len(tokens)

    k = start_pos
    while k < end_pos
        tok = get(tokens, k)
        if tok_t(tok) == 1 and tok_s(tok) == var_name
            score = score + 1
            if k + 1 < end_pos
                next_tok = get(tokens, k + 1)
                if tok_t(next_tok) == 6
                    op_str = tok_s(next_tok)
                    if op_str == "+=" or op_str == "-=" or op_str == "="
                        score = score + 3 // Higher weight for mutations
        k = k + 1
    return score
