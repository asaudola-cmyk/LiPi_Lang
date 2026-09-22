// ==============================================================================
// 🟩 NODE.JS BENCHMARK: 10,000,000 ARITHMETIC LOOP ITERATIONS (benchmarks/bench_loop.js)
// ==============================================================================

const start = process.hrtime.bigint();
let total = 0;
for (let i = 1; i <= 10000000; i++) {
    total += i % 7;
}
const elapsedMs = Number(process.hrtime.bigint() - start) / 1e6;

console.log("Node.js Loop 10,000,000 Iterations Complete!");
console.log(`Sum: ${total}`);
console.log(`Elapsed Time: ${elapsedMs.toFixed(2)} ms`);
