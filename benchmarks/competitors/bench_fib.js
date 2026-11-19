function fib(n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}

const start = performance.now();
const res = fib(35);
const end = performance.now();

console.log("JavaScript Fibonacci (35) Complete!");
console.log(`Sum: ${res}`);
console.log(`Elapsed Time: ${(end - start).toFixed(2)} ms`);
