// ==============================================================================
// 🧪 WAVE G: TAGGED ADTs + COMPILE-TIME GENERICS + SCOPED MODULES TEST SUITE
// 🏛️ File: tests/test_wave_g_adts_generics_modules.lp
// Verifies (100% Pure Lipi | 0% boxing | 0% external deps):
//   G1: Tagged Enums / ADTs (`enum Result<T, E>`, `enum Option<T>`, `enum Shape`)
//       with GC-traced ADT0 cells, `match` destructuring (stmt & expr), qualified
//       `Enum::Variant`, float/int/str tagged payloads, and `?` auto-unwrapping!
//   G2: Compile-Time Monomorphized Generics (`fn pair_sum<T>`, `struct Box<T>`)
//       with both explicit `<float>`/`<int>`/`<str>` AND inferred type arguments!
//   G3: Scoped Modules (`pub fn`/`pub struct`, `import "..." as mod` with BOTH
//       `mod.sym` and `mod::sym`, and `from "..." import sym [as alias]`)!
// ==============================================================================

import "tests/fixtures/wave_g_mod.lp" as wg
from "tests/fixtures/wave_g_mod.lp" import public_greet, public_scale as scaled

fn wg_assert(cond, msg)
    if cond == 0
        print("FAIL: " + msg)
        exit(1)
    end
    return 0
end

// ── G1: Tagged Enums / Algebraic Data Types ───────────────────────────────────
enum Result<T, E> {
    Ok(T),
    Err(E)
}

enum Option<T> {
    Some(T),
    None
}

enum Shape {
    Circle(float),
    Rect(float, float),
    Origin
}

fn safe_div_int(a: int, b: int) -> Result<int, str>
    if b == 0
        return Err("divide_by_zero")
    end
    return Ok(a / b)
end

fn safe_div_float(a: float, b: float) -> Result<float, str>
    if b == 0.0
        return Result::Err("float_zero")
    end
    return Result::Ok(a / b)
end

fn chain_div_int(a: int, b: int, c: int) -> Result<int, str>
    q1 = safe_div_int(a, b)?
    q2 = safe_div_int(q1, c)?
    return Ok(q2 + 1)
end

fn chain_div_float(a: float, b: float) -> Result<float, str>
    q = safe_div_float(a, b)?
    return Ok(q + 0.5)
end

fn find_positive(x: int) -> Option<int>
    if x > 0
        return Some(x * 10)
    end
    return Option::None
end

fn use_option_q(x: int) -> Option<int>
    v = find_positive(x)?
    return Some(v + 3)
end

fn shape_area(sh: Shape) -> float
    res = match sh {
        Circle(r) => 3.0 * r * r,
        Rect(w, h) => w * h,
        Origin => 0.0
    }
    return res
end

// ── G2: Compile-Time Monomorphized Generics ───────────────────────────────────
fn pair_sum<T>(a: T, b: T) -> T
    return a + b
end

struct Box<T> {
    val: T
}

fn unbox_add<T>(bx: Box<T>, delta: T) -> T
    return bx.val + delta
end

fn main()
    // ── Verify G1: Tagged ADTs, match destructuring, and `?` operator ─────────
    r_ok = safe_div_int(42, 6)
    v_ok = match r_ok {
        Ok(v) => v,
        Err(e) => 0 - 1
    }
    wg_assert(v_ok == 7, "G1: Result Ok(7) destructured via match expr")

    r_err = safe_div_int(10, 0)
    err_msg = ""
    match r_err
        case Ok(v) => err_msg = "unexpected"
        case Err(msg) => err_msg = msg
    end
    wg_assert(err_msg == "divide_by_zero", "G1: Result Err(msg) destructured via match stmt")

    // Chained `?` propagation on Result<int, str>
    c_ok = chain_div_int(100, 5, 2)
    c_ok_v = match c_ok {
        Ok(v) => v,
        Err(e) => 0
    }
    wg_assert(c_ok_v == 11, "G1: chained ? Ok path (100/5/2 + 1 == 11)")

    c_err = chain_div_int(100, 0, 2)
    c_err_s = match c_err {
        Ok(v) => "nope",
        Err(e) => e
    }
    wg_assert(c_err_s == "divide_by_zero", "G1: chained ? early-returns Err cell")

    // Float payload inside generic Result<float, str> + `?` unwrap preserving float tag!
    cf_ok = chain_div_float(7.0, 2.0)
    cf_str = match cf_ok {
        Ok(v) => str(v),
        Err(e) => e
    }
    wg_assert(cf_str == "4.0", "G1: Result<float, str> + ? preserved IEEE-754 float (7.0/2.0+0.5 == 4.0)")

    // Option<T> Some/None + `?`
    o1 = use_option_q(5)
    o1_v = match o1 {
        Some(v) => v,
        None => 0 - 99
    }
    wg_assert(o1_v == 53, "G1: Option Some(53) via ?")

    o2 = use_option_q(0 - 3)
    o2_v = match o2 {
        Some(v) => v,
        None => 0 - 99
    }
    wg_assert(o2_v == (0 - 99), "G1: Option None propagated via ?")

    // Multi-payload ADT Shape (Circle, Rect, Origin)
    a_c = shape_area(Circle(2.0))
    a_r = shape_area(Rect(3.5, 4.0))
    a_o = shape_area(Origin)
    wg_assert(str(a_c) == "12.0" and str(a_r) == "14.0" and str(a_o) == "0.0", "G1: multi-payload Shape ADT match")
    print("PASS G1: Tagged Enums/ADTs (Result, Option, Shape, match destructuring, ? unwrap) verified")

    // ── Verify G2: Compile-Time Monomorphized Generics ────────────────────────
    gi = pair_sum<int>(17, 25)
    gf = pair_sum<float>(1.25, 2.75)
    gs = pair_sum<str>("Lipi ", "Generics")
    gf_inf = pair_sum(3.5, 1.5)
    wg_assert(gi == 42, "G2: pair_sum<int>(17, 25) == 42")
    wg_assert(str(gf) == "4.0", "G2: pair_sum<float>(1.25, 2.75) == 4.0 (native SSE2)")
    wg_assert(gs == "Lipi Generics", "G2: pair_sum<str> == 'Lipi Generics'")
    wg_assert(str(gf_inf) == "5.0", "G2: inferred pair_sum(3.5, 1.5) == 5.0")

    bf = Box<float>(3.25)
    bi = Box<int>(100)
    bs = Box<str>("sovereign")
    bf_inf = Box(2.5)
    wg_assert(str(bf.val + 0.75) == "4.0", "G2: Box<float>.val native SSE2 arithmetic")
    wg_assert(bi.val + 23 == 123, "G2: Box<int>.val native int arithmetic")
    wg_assert(bs.val + "!" == "sovereign!", "G2: Box<str>.val string concat")
    wg_assert(str(bf_inf.val + 1.5) == "4.0", "G2: inferred Box(2.5).val == 4.0")

    ub_f = unbox_add<float>(bf, 1.75)
    ub_i = unbox_add<int>(bi, 5)
    wg_assert(str(ub_f) == "5.0" and ub_i == 105, "G2: generic fn taking Box<T> monomorphized cleanly")
    print("PASS G2: Compile-time monomorphized generic functions & structs (0% boxing) verified")

    // ── Verify G3: Scoped Modules (`pub`, `alias.sym`, `alias::sym`, `from ... import`) ──
    s_dot = wg.public_scale(6)
    s_col = wg::public_scale(8)
    s_sel = scaled(5)
    g_sel = public_greet("Lipi")
    pt = wg::VaultPoint(10, 20)
    wg_assert(s_dot == 42 and s_col == 56 and s_sel == 35, "G3: pub fn via alias.sym, alias::sym, and from...import as")
    wg_assert(g_sel == "Hello, Lipi!", "G3: from...import direct binding")
    wg_assert(pt.x == 10 and pt.y == 20, "G3: pub struct via alias::Struct")
    print("PASS G3: Scoped modules (pub visibility, alias.sym, alias::sym, from...import) verified")

    print("ALL WAVE G TESTS PASSED!")
    return 0
end
