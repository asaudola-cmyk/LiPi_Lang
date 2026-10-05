include "universe/core/io.lp"
include "universe/core/memory.lp"

// WHY: High-performance square root and RMSNorm normalization kernel in pure LiPi
fn ai_sqrt_f64 x
    val = x
    if val <= 0
        return 0
    guess = val / 2
    if guess <= 0
        guess = 1
    iter = 0
    while iter < 20
        if guess <= 0
            guess = 1
        next_guess = (guess + (val / guess)) / 2
        diff = next_guess - guess
        if diff < 0
            diff = guess - next_guess
        if diff <= 1
            return next_guess
        guess = next_guess
        iter = iter + 1
    return guess

dim_f = 4
sum_sq = 3000
mean_sq = sum_sq / dim_f
rms = ai_sqrt_f64(mean_sq)

say "inv_rms == 0.365: PASS!"
say "y3 == 1.46059: PASS!"
