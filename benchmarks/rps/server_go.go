// ==============================================================================
// 👑 GO HIGH-THROUGHPUT HTTP BENCHMARK SERVER
// Architecture: Standard Library net/http with 4 GOMAXPROCS and Keep-Alive
// ==============================================================================

package main

import (
	"fmt"
	"net/http"
	"runtime"
)

const port = ":8004"

// WHY: Idiomatic Go HTTP handler serving standard benchmark payload
func handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain")
	w.Header().Set("Content-Length", "13")
	w.Header().Set("Connection", "keep-alive")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("Hello, World!"))
}

func main() {
	runtime.GOMAXPROCS(4)
	http.HandleFunc("/", handler)
	fmt.Printf("[Go] Server listening on 0.0.0.0%s with %d GOMAXPROCS\n", port, 4)
	if err := http.ListenAndServe(port, nil); err != nil {
		panic(err)
	}
}
