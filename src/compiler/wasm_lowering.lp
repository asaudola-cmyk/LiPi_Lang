// ==============================================================================
// 🌐 লিপি এএসটি → ওয়েবঅ্যাসেম্বলি লোয়ারিং ইঞ্জিন (Lipi AST → WASM Lowering Engine)
// Module: src/compiler/wasm_lowering.lp
// Architecture: Direct AST/IR Lowering to W3C WebAssembly Standard Binary
// 0% C, 0% LLVM, 0% Emscripten — 100% Sovereign Lipi
// ==============================================================================
//
// WHY: আধুনিক ব্রাউজার এবং ক্লাউড এজ স্যান্ডবক্সে লিপি কোড সরাসরি চালানোর জন্য
// লিপির সিনট্যাক্স ট্রি (AST) কে ডিরেক্ট WASM স্ট্যাক-বেসড বাইটকোড নির্দেশনায় রূপান্তর করা।

include "universe/core/memory.lp"
include "universe/core/string.lp"

// ── ১. লোকাল ভেরিয়েবল টেবিল ম্যানেজমেন্ট (Local Variable Scope Management) ─────
// WHY: WASM ফাংশনে প্যারামিটারগুলো প্রথম N টি লোকাল ইনডেক্স দখল করে (0 .. N-1),
// এবং লোকাল ভেরিয়েবলগুলো N, N+1, ... ক্রমানুসারে সাজাতে হয়।
fn wasm_locals_new
    names = list()
    return names

fn wasm_locals_add_param locals name
    push(locals, name)
    return len(locals) - 1

fn wasm_locals_find locals name
    i = 0
    num = len(locals)
    while i < num
        if str_eq(get(locals, i), name) == 1
            return i
        i = i + 1
    return 0 - 1

fn wasm_locals_get_or_add locals name
    idx = wasm_locals_find(locals, name)
    if idx >= 0
        return idx
    push(locals, name)
    return len(locals) - 1

// ── ২. এক্সপ্রেশন লোয়ারিং (Expression Lowering to WASM Stack Machine) ───────────
fn wasm_lower_expr_binary op code
    if str_eq(op, "+") == 1
        wasm_emit_i32_add(code)
    elif str_eq(op, "-") == 1
        wasm_emit_i32_sub(code)
    elif str_eq(op, "*") == 1
        wasm_emit_i32_mul(code)
    elif str_eq(op, "/") == 1
        wasm_emit_i32_div_s(code)
    elif str_eq(op, "==") == 1
        wasm_emit_i32_eq(code)
    elif str_eq(op, "!=") == 1
        wasm_emit_i32_ne(code)
    elif str_eq(op, "<") == 1
        wasm_emit_i32_lt_s(code)
    elif str_eq(op, "<=") == 1
        wasm_emit_i32_le_s(code)
    elif str_eq(op, ">") == 1
        wasm_emit_i32_gt_s(code)
    elif str_eq(op, ">=") == 1
        wasm_emit_i32_ge_s(code)
    return 0

// ── ৩. স্টেটমেন্ট লোয়ারিং হেল্পার (Statement Lowering) ─────────────────────────
// WHY: if, while, return, এবং অ্যাসাইনমেন্টকে বৈধ WASM ব্লকে রূপান্তর করা
fn wasm_lower_return_val code
    wasm_emit_return(code)
    return 0

fn wasm_lower_branch_if code depth
    wasm_emit_br_if(code, depth)
    return 0
