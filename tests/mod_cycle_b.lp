import "tests/mod_cycle_a.lp"

fn cycle_odd(n)
    if n == 0 return 0 end
    return cycle_even(n - 1)
end
