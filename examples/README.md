# 🌟 LiPi Examples & Application Showcase Catalog

> **⚡ 100% Pure Direct Silicon Machine Code | 0% C | 0% Libc | 0% LLVM**  
> **Explore real-world sovereign applications from basic scripts to distributed systems.**

---

## 🏛️ Example Directory Navigation

All examples in this directory can be compiled and executed directly using the sovereign compiler (`bin/lipc`) or run in-memory with the unified runner (`bin/lipi`).

```bash
# General execution syntax:
bin/lipc examples/<example_file>.lp /tmp/app && /tmp/app

# Or via in-memory runner:
bin/lipi run examples/<example_file>.lp
```

---

## 🗺️ Thematic Categories & Showcase Tiers

### 🟢 Tier 1: Fundamentals & Language Syntax
Introductory programs demonstrating LiPi's syntax (Bengali, English, and `@`-directives), variables, functions, and control flow:

| Directory / File | Description | Execution Command |
| :--- | :--- | :--- |
| [`01_hello_world/`](01_hello_world/) | Hello World in Bengali, English, and Directives | `bin/lipc examples/01_hello_world/main.lp /tmp/ex && /tmp/ex` |
| [`02_calculator/`](02_calculator/) | Interactive CLI expression calculator | `bin/lipc examples/02_calculator/main.lp /tmp/ex && /tmp/ex` |
| [`03_sorting/`](03_sorting/) | Quicksort, Mergesort, and Bubblesort algorithms | `bin/lipc examples/03_sorting/main.lp /tmp/ex && /tmp/ex` |
| [`04_string_tools/`](04_string_tools/) | String manipulation and UTF-8 Bengali runes | `bin/lipc examples/04_string_tools/main.lp /tmp/ex && /tmp/ex` |
| [`fibonacci.lp`](fibonacci.lp) | Fast recursive and iterative Fibonacci sequence | `bin/lipc examples/fibonacci.lp /tmp/ex && /tmp/ex` |
| [`args_demo.lp`](args_demo.lp) | Command-line argument parsing and flags | `bin/lipc examples/args_demo.lp /tmp/ex && /tmp/ex --name Sovereign` |
| [`word_count.lp`](word_count.lp) | High-speed UTF-8 text token and line counter | `bin/lipc examples/word_count.lp /tmp/ex && /tmp/ex` |

---

### 🔵 Tier 2: Systems, Concurrency & Networking
High-throughput I/O, epoll event loops, HTTP web servers, and distributed consensus:

| Directory / File | Description | Execution Command |
| :--- | :--- | :--- |
| [`06_http_server/`](06_http_server/) | Multi-client HTTP REST server | `bin/lipc examples/06_http_server/main.lp /tmp/ex && /tmp/ex` |
| [`epoll_async_server.lp`](epoll_async_server.lp) | Linux `sys_epoll` async event loop handling 100K+ RPS | `bin/lipc examples/epoll_async_server.lp /tmp/ex && /tmp/ex` |
| [`distributed_raft_demo.lp`](distributed_raft_demo.lp) | Distributed Raft consensus leader election and log replication | `bin/lipc examples/distributed_raft_demo.lp /tmp/ex && /tmp/ex` |
| [`http_server.lp`](http_server.lp) | Standalone zero-dependency HTTP server | `bin/lipc examples/http_server.lp /tmp/ex && /tmp/ex` |

---

### 🟣 Tier 3: Enterprise Full-Stack Applications
Production-grade applications integrating multiple ecosystem packages:

| Directory / File | Description | Execution Command |
| :--- | :--- | :--- |
| [`sovereign_showcase/`](sovereign_showcase/) | **Unified Full-Stack Showcase**: `web_router` + `crypto_vault` + `lipi_jwt` + `lipi_sql` + CPU Telemetry | `bin/lipc examples/sovereign_showcase/main.lp /tmp/ex && /tmp/ex` |
| [`sovereign_commerce.lp`](sovereign_commerce.lp) | E-commerce engine with inventory, cart, and transactions | `bin/lipc examples/sovereign_commerce.lp /tmp/ex && /tmp/ex` |
| [`lipidb_server.lp`](lipidb_server.lp) | Standalone In-Memory Database server with Redis protocol | `bin/lipc examples/lipidb_server.lp /tmp/ex && /tmp/ex` |
| [`lipipkg_registry.lp`](lipipkg_registry.lp) | P2P Package Registry server with SHA-256 manifest verification | `bin/lipc examples/lipipkg_registry.lp /tmp/ex && /tmp/ex` |

---

### 🟡 Tier 4: Hardware, Graphics & Bare-Metal
Direct silicon graphics, Linux framebuffer, TUI dashboards, and Ring-0 kernels:

| Directory / File | Description | Execution Command |
| :--- | :--- | :--- |
| [`08_baremetal_os/`](08_baremetal_os/) | Ring-0 Multiboot2 x86_64 kernel booted on bare metal | `bin/lipc examples/08_baremetal_os/kernel.lp /tmp/kernel.bin` |
| [`silicon_tui_dashboard.lp`](silicon_tui_dashboard.lp) | ANSI terminal dashboard with live CPU/RAM gauges | `bin/lipc examples/silicon_tui_dashboard.lp /tmp/ex && /tmp/ex` |
| [`gui_desktop_shell.lp`](gui_desktop_shell.lp) | Zero-X11 Linux framebuffer GUI desktop shell | `bin/lipc examples/gui_desktop_shell.lp /tmp/ex && /tmp/ex` |

---

### 🔴 Tier 5: Artificial Intelligence & WebAssembly
Hardware SIMD acceleration, neural networks, GGUF local LLM inference, and WebAssembly:

| Directory / File | Description | Execution Command |
| :--- | :--- | :--- |
| [`wasm_interactive_demo.html`](wasm_interactive_demo.html) | Standalone Browser WebAssembly Interactive UI | `xdg-open examples/wasm_interactive_demo.html` |
| [`07_llm_inference/`](07_llm_inference/) | Local GGUF transformer LLM execution via AVX2 | `bin/lipc examples/07_llm_inference/main.lp /tmp/ex && /tmp/ex` |
| [`neural_network.lp`](neural_network.lp) | 3-layer neural network trained directly in pure LiPi | `bin/lipc examples/neural_network.lp /tmp/ex && /tmp/ex` |
| [`matrix_math.lp`](matrix_math.lp) | High-performance AVX2 SIMD matrix multiplication | `bin/lipc examples/matrix_math.lp /tmp/ex && /tmp/ex` |
