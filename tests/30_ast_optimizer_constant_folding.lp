// Test 30: AST Optimizer — Lipi 2.0 Global Standard

fn fold_add a b = a + b
fn fold_mul a b = a * b
fn fold_sub a b = a - b

fn constant_fold op a b
    if op == 1
        return fold_add(a, b)
    elif op == 2
        return fold_mul(a, b)
    elif op == 3
        return fold_sub(a, b)
    return a

say "=== Constant Folding ==="
say constant_fold(1, 2, 3)
say constant_fold(2, 4, 5)
say constant_fold(3, 10, 3)
say constant_fold(1, 100, 200)

fn dead_code cond
    if cond == 0
        return 1
    return 0

say dead_code(0)
say dead_code(1)

fn strength_reduce val
    // x*2 -> x+x
    say "Optimize: x*2 -> x+x"
    return val + val

say strength_reduce(7)

say "PASS: Test 30 AST Optimizer"
