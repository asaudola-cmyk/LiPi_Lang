// ==============================================================================
// 🟦 TYPESCRIPT BENCHMARK: 10,000,000 ARITHMETIC LOOP ITERATIONS (benchmarks/bench_loop.ts)
// ==============================================================================

const start: bigint = process.hrtime.bigint();

let total: number = 0;
for (let i: number = 1; i <= 10000000; i++) {
    total += i % 7;
}

const elapsedMs: number = Number(process.hrtime.bigint() - start) / 1e6;

console.log("TypeScript Loop 10,000,000 Iterations Complete!");
console.log(`Sum: ${total}`);
console.log(`Elapsed Time: ${elapsedMs.toFixed(2)} ms`);
