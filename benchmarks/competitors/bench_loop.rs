// ==============================================================================
// 🦀 RUST BENCHMARK: 10,000,000 ARITHMETIC LOOP ITERATIONS (benchmarks/bench_loop.rs)
// ==============================================================================

use std::time::Instant;

fn main() {
    let start = Instant::now();

    let mut total: u64 = 0;
    for i in 1..=10_000_000u64 {
        total += i % 7;
    }

    let elapsed = start.elapsed();
    println!("Rust Loop 10,000,000 Iterations Complete!");
    println!("Sum: {}", total);
    println!("Elapsed Time: {:.2} ms", elapsed.as_secs_f64() * 1000.0);
}
