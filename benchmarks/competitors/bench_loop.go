// ==============================================================================
// 🐹 GO BENCHMARK: 10,000,000 ARITHMETIC LOOP ITERATIONS (benchmarks/bench_loop.go)
// ==============================================================================

package main

import (
	"fmt"
	"time"
)

func main() {
	start := time.Now()

	var total uint64 = 0
	for i := uint64(1); i <= 10000000; i++ {
		total += (i % 7)
	}

	elapsed := time.Since(start)

	fmt.Println("Go Loop 10,000,000 Iterations Complete!")
	fmt.Printf("Sum: %d\n", total)
	fmt.Printf("Elapsed Time: %.2f ms\n", float64(elapsed.Microseconds())/1000.0)
}
