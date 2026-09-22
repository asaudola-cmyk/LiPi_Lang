// ==============================================================================
// 🕊️ SWIFT BENCHMARK: 10,000,000 ARITHMETIC LOOP ITERATIONS (benchmarks/bench_loop.swift)
// ==============================================================================

import Foundation
import Dispatch

let start = DispatchTime.now().uptimeNanoseconds

var total: UInt64 = 0
for i: UInt64 in 1...10_000_000 {
    total &+= (i % 7)
}

let end = DispatchTime.now().uptimeNanoseconds
let elapsed_ms = Double(end - start) / 1_000_000.0

print("Swift Loop 10,000,000 Iterations Complete!")
print("Sum: \(total)")
print(String(format: "Elapsed Time: %.2f ms", elapsed_ms))
