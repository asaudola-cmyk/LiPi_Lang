// ==============================================================================
// 🟩 NODE.JS BENCHMARK: 1,000,000 ROW COLUMNSTORE ANALYTICAL SCAN (benchmarks/competitors/bench_columnstore.js)
// ==============================================================================

const start = process.hrtime.bigint();
let total = 0;
for (let i = 0; i < 1000000; i++) {
    total += i % 100;
}
const elapsedMs = Number(process.hrtime.bigint() - start) / 1e6;

console.log("Node.js ColumnStore 1,000,000 Scan Complete!");
console.log(`Sum: ${total}`);
console.log(`Elapsed Time: ${elapsedMs.toFixed(2)} ms`);
