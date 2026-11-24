# Lipi Examples

Runnable programs written in Lipi. Compile and run any example using `bin/lipc` or `bin/lipi`:

```bash
./bin/lipc examples/<file>.lp -o /tmp/app && /tmp/app

# Or run directly:
./bin/lipi run examples/<file>.lp
```

## Fundamentals

| Path | Description |
|---|---|
| [`01_hello_world/`](01_hello_world/) | Hello World in Bengali, English, and `@`-directive syntax |
| [`02_calculator/`](02_calculator/) | CLI expression calculator |
| [`03_sorting/`](03_sorting/) | Sorting algorithms (Quicksort, Mergesort, Bubblesort) |
| [`04_string_tools/`](04_string_tools/) | String manipulation and UTF-8 Bengali runes |
| [`05_data_structures/`](05_data_structures/) | Core data structures |
| [`fibonacci.lp`](fibonacci.lp) | Recursive and iterative Fibonacci |
| [`args_demo.lp`](args_demo.lp) | Command-line argument parsing |
| [`word_count.lp`](word_count.lp) | UTF-8 word and line counter |

## Systems & Networking

| Path | Description |
|---|---|
| [`06_http_server/`](06_http_server/) | Multi-client HTTP server over raw sockets |
| [`http_server.lp`](http_server.lp) | Standalone HTTP server |
| [`epoll_async_server.lp`](epoll_async_server.lp) | Linux `epoll` async event loop server |
| [`distributed_raft_demo.lp`](distributed_raft_demo.lp) | Raft consensus election and log replication demo |
| [`lipidb_server.lp`](lipidb_server.lp) | In-memory database server |
| [`haat_registry.lp`](haat_registry.lp) | Local package registry server with SHA-256 verification |
| [`sovereign_showcase/`](sovereign_showcase/) | Integrated example using `web_router`, `crypto_vault`, `lipi_jwt`, and `lipi_sql` |

## Hardware, Graphics & Bare-Metal

| Path | Description |
|---|---|
| [`08_baremetal_os/`](08_baremetal_os/) | Multiboot x86 kernel image builder |
| [`silicon_tui_dashboard.lp`](silicon_tui_dashboard.lp) | ANSI terminal status dashboard |
| [`gui_desktop_shell.lp`](gui_desktop_shell.lp) | Linux framebuffer GUI shell |

## Compute, AI & WebAssembly

| Path | Description |
|---|---|
| [`07_llm_inference/`](07_llm_inference/) | Local GGUF tensor inference and terminal chat REPL |
| [`neural_network.lp`](neural_network.lp) | Feed-forward neural network in Lipi |
| [`matrix_math.lp`](matrix_math.lp) | Matrix multiplication |
| [`wasm_interactive_demo.html`](wasm_interactive_demo.html) | Browser WebAssembly demo |

## Verification & Multi-Target Demos (`flagship/`)

| File | Description |
|---|---|
| [`flagship/01_sovereign_kavach_vault.lp`](flagship/01_sovereign_kavach_vault.lp) | `--kavach` ownership proof and `silicon_*` boundary demo |
| [`flagship/02_sovereign_silicon_brain.lp`](flagship/02_sovereign_silicon_brain.lp) | `f64` 2-3-1 MLP learning XOR via backpropagation |
| [`flagship/03_omni_six_target_harmony.lp`](flagship/03_omni_six_target_harmony.lp) | Portable bilingual program targeting x86_64, ARM64, macOS, RISC-V 64, Windows, and WASM |
