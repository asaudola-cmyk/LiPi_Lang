import "tests/mod_cycle_b.lp"

fn cycle_even(n)
    if n == 0 return 1 end
    return cycle_odd(n - 1)
end
