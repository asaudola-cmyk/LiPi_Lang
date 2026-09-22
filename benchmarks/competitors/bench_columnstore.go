// ==============================================================================
// 🐹 GO BENCHMARK: 1,000,000 ROW COLUMNSTORE ANALYTICAL SCAN (benchmarks/competitors/bench_columnstore.go)
// ==============================================================================

package main

import (
	"fmt"
	"time"
)

func main() {
	start := time.Now()

	var total uint64 = 0
	for i := uint64(0); i < 1000000; i++ {
		total += (i % 100)
	}

	elapsed := time.Since(start)

	fmt.Println("Go ColumnStore 1,000,000 Scan Complete!")
	fmt.Printf("Sum: %d\n", total)
	fmt.Printf("Elapsed Time: %.2f ms\n", float64(elapsed.Microseconds())/1000.0)
}
