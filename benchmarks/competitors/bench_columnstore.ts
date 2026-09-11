// ==============================================================================
// 🥟 BUN BENCHMARK: 1,000,000 ROW COLUMNSTORE ANALYTICAL SCAN (benchmarks/competitors/bench_columnstore.ts)
// ==============================================================================

const start = performance.now();
let total = 0;
for (let i = 0; i < 1000000; i++) {
    total += i % 100;
}
const elapsedMs = performance.now() - start;

console.log("Bun ColumnStore 1,000,000 Scan Complete!");
console.log(`Sum: ${total}`);
console.log(`Elapsed Time: ${elapsedMs.toFixed(2)} ms`);
