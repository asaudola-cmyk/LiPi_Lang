# 👑 07_llm_inference

A 100% Python-free, PyTorch-free GGUF quantized LLM tensor inference engine written in pure Lipi. Demonstrates GGUF v3 binary header parsing, Q4_0 quantized dequantization, GEMV matrix-vector multiplication, and greedy ArgMax token sampling.

## How to Build & Run:
```bash
# Compile to standalone native ELF binary
./bin/lipi examples/07_llm_inference/main.lp -o bin/ai_inference

# Run native CPU inference
./bin/ai_inference
```
