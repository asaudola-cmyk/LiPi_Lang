// ==============================================================================
// Wave N Regression Suite: Unsigned u64 Math/Compare/Print, Exhaustive Match,
// Virtual Sovereign libm.so.6 (16+ IEEE-754 funcs), Closure Indexing fns[0](10),
// Mixed Float/Int Return, Braced try/defer/finally, Null Index NPE & Div-by-Zero
// in Try, Recursive Closure Capture, Negative Indexing, Forward Anon Struct Return
// ==============================================================================

import "utso/core/ffi_sovereign.lp"

enum OptN { SomeN(int), NoneN }

fn check_opt(x: OptN)
    match x {
        SomeN(v) => return v
        NoneN => return 0 - 1
    }
    return 0
end

fn mixed_ret(flag)
    if flag == 1
        return 3.5
    end
    return 42
end

fn mixed_ret_param(x)
    if x == 1
        return 1.5
    end
    return x
end

fn make_anon_box(x)
    return { val: x + 1 }
end

fn test_defer_order(log)
    try {
        defer { push(log, 20) }
        push(log, 10)
        throw "boom"
    } catch e {
        push(log, 30)
    } finally {
        push(log, 40)
    }
    return 0
end

fn main()
    // 1. Unsigned u64 comparisons, logical >>, unsigned /, %, and str()
    a: u64 = 18446744071562067968
    b: u64 = 4096
    if (a > b) == 0
        say "FAIL N1a u64 compare"
        exit(1)
    end
    c: u64 = 0 - 1
    if (c >> 1) != 9223372036854775807
        say "FAIL N1b u64 logical shr"
        exit(1)
    end
    x: u64 = 18446744073709551614
    y: u64 = 2
    if (x / y) != 9223372036854775807
        say "FAIL N1c u64 div"
        exit(1)
    end
    if str(a) != "18446744071562067968"
        say "FAIL N1d u64 str: " + str(a)
        exit(1)
    end
    cu: u64 = 0 - 1
    cu >>= 1
    xu: u64 = 18446744073709551614
    xu /= 2
    yu: u64 = 18446744073709551615
    yu %= 10
    if cu != 9223372036854775807 or xu != 9223372036854775807 or yu != 5
        say "FAIL N1e u64 compound >>=, /=, %="
        exit(1)
    end

    // 2. Exhaustive ADT match
    if check_opt(SomeN(77)) != 77 or check_opt(NoneN) != (0 - 1)
        say "FAIL N2 exhaustive match"
        exit(1)
    end

    // 3. Bug 1: fns[0](10) indexed closure call
    fns = [fn(v) { return v + 1 }]
    if fns[0](10) != 11
        say "FAIL N3 fns[0](10)"
        exit(1)
    end

    // 4. Bug 2: Sovereign virtual libm.so.6 FFI math (sin, cos, sqrt, exp, log, floor, ceil, fabs)
    h = ffi_load_so("/lib/x86_64-linux-gnu/libm.so.6")
    if h == 0
        say "FAIL N4 ffi_load_so libm"
        exit(1)
    end
    p_sqrt = ffi_find_symbol(h, "sqrt")
    p_sin  = ffi_find_symbol(h, "sin")
    p_cos  = ffi_find_symbol(h, "cos")
    p_exp  = ffi_find_symbol(h, "exp")
    if p_sqrt == 0 or p_sin == 0 or p_cos == 0 or p_exp == 0
        say "FAIL N4b libm symbols"
        exit(1)
    end
    if c_abi_call(p_sqrt, [], [0x4022000000000000])[1] != 0x4008000000000000
        say "FAIL N4c sqrt(9.0)"
        exit(1)
    end
    if c_abi_call(p_cos, [], [0])[1] != 0x3FF0000000000000 or c_abi_call(p_exp, [], [0])[1] != 0x3FF0000000000000 or c_abi_call(p_sin, [], [0])[1] != 0
        say "FAIL N4d sin/cos/exp(0.0)"
        exit(1)
    end
    ffi_close_so(h)

    // 5. Bug 4: Mixed float/int return (literal AND untyped param branch)
    if mixed_ret(1) != 3.5 or mixed_ret(0) != 42 or mixed_ret_param(1) != 1.5 or mixed_ret_param(2) != 2
        say "FAIL N5 mixed_ret"
        exit(1)
    end

    // 6. Bug 5: Braced try { defer { ... } } catch e { ... } finally { ... } ordering
    // (defer runs at function return after catch & finally)
    log = list()
    test_defer_order(log)
    if log.len() != 4 or log[0] != 10 or log[1] != 30 or log[2] != 40 or log[3] != 20
        say "FAIL N6 try/defer/catch/finally"
        exit(1)
    end

    // 7. Bug 6: Null index NPE & div-by-zero throw inside try
    caught_npe = 0
    try
        np = 0
        nv = np[0]
    catch e
        caught_npe = 1
    end
    caught_div = 0
    try
        dz = 0
        dv = 10 / dz
    catch e
        caught_div = 1
    end
    if caught_npe != 1 or caught_div != 1
        say "FAIL N7 NPE/DivZero in try"
        exit(1)
    end

    // 8. Bug 7: Recursive closure capture
    fact = 0
    fact = fn(n) {
        if n <= 1
            return 1
        end
        return n * fact(n - 1)
    }
    if fact(5) != 120
        say "FAIL N8 recursive closure"
        exit(1)
    end

    // 9. Bug 8: Negative indexing + forward anon struct return
    arr = [10, 20, 30]
    if arr[-1] != 30
        say "FAIL N9a neg list read"
        exit(1)
    end
    arr[-1] = 99
    if arr[2] != 99
        say "FAIL N9b neg list write"
        exit(1)
    end
    s = "hello"
    if s[-1] != 111
        say "FAIL N9c neg str read"
        exit(1)
    end
    bx = make_anon_box(41)
    if bx.val != 42
        say "FAIL N9d anon struct return"
        exit(1)
    end

    say "PASS_WAVE_N_CORE_UNSIGNED_STRICT_FFI"
    return 0
end
