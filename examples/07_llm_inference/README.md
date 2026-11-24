# 07_llm_inference

Local tensor inference engine and interactive terminal chat example written in Lipi. Demonstrates GGUF header parsing, quantized dequantization (`Q4_0`, `Q8_0`), GEMV matrix-vector multiplication, rolling KV-cache decoding, and token sampling.

## Files

| File | Description |
|---|---|
| [`main.lp`](main.lp) | End-to-end GGUF header check, GEMV, KV-cache allocation, and autoregressive generation demo |
| [`chat_app.lp`](chat_app.lp) | Interactive terminal REPL chat engine with bilingual vocabulary and sliding context window |

## Build & Run

```bash
# Run directly
./bin/lipi run examples/07_llm_inference/main.lp
./bin/lipi run examples/07_llm_inference/chat_app.lp

# Or build standalone native binary
./bin/lipc examples/07_llm_inference/chat_app.lp -o /tmp/chat_app
/tmp/chat_app
```

## REPL Commands (`chat_app.lp`)

| Command | Description |
|---|---|
| `/help` | Show available commands |
| `/stats` | Show vector telemetry and KV-cache metrics |
| `/reset` | Clear conversation history and reset KV-cache |
| `/mode greedy\|topk\|topp\|hybrid` | Select token sampling strategy |
| `/temp <val>` | Update temperature (e.g. `70` for `0.70`, `0` for deterministic) |
| `/topk <val>` | Set Top-K candidate limit |
| `/topp <val>` | Set Top-P nucleus threshold percentage |
| `/exit` or `/quit` | Exit the REPL |
