@fn simple_hash(val: i64) -> i64 {
    // 64-bit integer mixing hash
    let h: i64 = val ^ (val >> 30);
    h = h * 137;
    h = h ^ (h / 65536);
    return h;
}

