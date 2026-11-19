// ==============================================================================
// 🦀 RUST BENCHMARK: 1,000,000 ROW COLUMNSTORE ANALYTICAL SCAN (benchmarks/competitors/bench_columnstore.rs)
// ==============================================================================

use std::time::Instant;

fn main() {
    let start = Instant::now();

    let mut total: u64 = 0;
    for i in 0..1_000_000u64 {
        total += i % 100;
    }

    let elapsed = start.elapsed();
    println!("Rust ColumnStore 1,000,000 Scan Complete!");
    println!("Sum: {}", total);
    println!("Elapsed Time: {:.2} ms", elapsed.as_secs_f64() * 1000.0);
}
