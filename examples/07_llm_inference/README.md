# 👑 07_llm_inference: Sovereign Silicon AI & LLM Inference Engine

A 100% Python-free, PyTorch-free, CUDA-free local LLM tensor inference engine and interactive terminal chat application written in pure LiPi. Demonstrates direct silicon machine code execution, GGUF v3 parsing, quantized dequantization (Q4_0, Q8_0), hardware-accelerated GEMV matrix-vector multiplication via native `%xmm` SSE2 / AVX2 / AVX-512 vector pipelines, KV-cache decoding, and stochastic token sampling.

---

## 📁 Included Applications

| Application | File | Description |
|---|---|---|
| **Core LLM Engine & Demo** | [`main.lp`](file:///home/shafiullah/Documents/file/work/lipi/examples/07_llm_inference/main.lp) | End-to-end benchmark demonstrating GGUF binary header verification, hardware GEMV, KV-cache allocation, and multi-step autoregressive generation. |
| **Interactive Terminal Chat App** | [`chat_app.lp`](file:///home/shafiullah/Documents/file/work/lipi/examples/07_llm_inference/chat_app.lp) | Standalone interactive REPL chat engine with bilingual vocabulary (English/Bengali), dynamic context window management, sliding history pruning, and live token streaming. |

---

## 🚀 How to Build & Run

### 1. In-Memory Execution (Direct JIT / Fast Run)
```bash
# Run core inference verification
./bin/lipi run examples/07_llm_inference/main.lp

# Launch interactive terminal chat engine
./bin/lipi run examples/07_llm_inference/chat_app.lp
```

### 2. Compile to Standalone Native ELF64 Binary
```bash
# Build standalone native machine code binary
./bin/lipi build examples/07_llm_inference/chat_app.lp -o bin/chat_app

# Execute directly on bare-metal silicon (Zero dependencies!)
./bin/chat_app
```

---

## ⚡ Terminal REPL Slash-Commands

When running [`chat_app.lp`](file:///home/shafiullah/Documents/file/work/lipi/examples/07_llm_inference/chat_app.lp), interact directly using natural language or slash-commands:

| Command | Description |
|---|---|
| `/help` | Display the interactive command directory |
| `/stats` | View silicon hardware vector telemetry, KV-cache depth & context metrics |
| `/reset` | Flush conversation history and resynchronize the KV-cache to system prompt |
| `/mode greedy` | Set deterministic Greedy ArgMax decoding (Temperature = 0.0) |
| `/mode topk` | Switch to Top-K stochastic candidate sampling |
| `/mode topp` | Switch to Top-P (nucleus) cumulative probability mass sampling |
| `/mode hybrid` | Engage the full unified pipeline (Temperature + Top-K + Top-P) |
| `/temp <val>` | Update temperature scaling (e.g. `70` for 0.70, `0` for deterministic) |
| `/topk <val>` | Set candidate pool truncation limit (e.g. `5`, `10`) |
| `/topp <val>` | Set nucleus cumulative mass threshold percentage (e.g. `85`, `90`) |
| `/exit` or `/quit` | Cleanly shutdown chat engine session and release allocated buffers |

---

## 🧠 Architectural Features

1. **Hardware Silicon GEMV**: Matrix-vector operations execute directly on AMD64 vector registers using `%xmm` SSE2 and AVX2/AVX-512 extensions (`simd_avx512_dot_u64`), delivering high-throughput inference at silicon line rate.
2. **Rolling KV-Cache**: Reusable Key/Value activation cache reduces autoregressive generation complexity from $\mathcal{O}(N^2)$ to $\mathcal{O}(N)$.
3. **Sliding Context Window**: Automatically prunes older conversational turns when approaching the sequence limit while permanently preserving invariant system prompts.
4. **Autonomous Self-Test**: Includes a self-contained verification suite that runs all tests, verifies multi-turn dialogue, exercises context pruning, and validates memory hygiene on launch.
