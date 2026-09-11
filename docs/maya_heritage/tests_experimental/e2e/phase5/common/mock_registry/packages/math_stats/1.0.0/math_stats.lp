@import "core_math/core_math"

@fn variance_2(a: i64, b: i64) -> i64 {
    let mean: i64 = (a + b) / 2;
    let d1: i64 = square(a - mean);
    let d2: i64 = square(b - mean);
    return (d1 + d2) / 2;
}

