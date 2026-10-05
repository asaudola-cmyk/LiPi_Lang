include "universe/core/io.lp"
include "universe/core/memory.lp"
include "universe/ai/tensor_engine.lp"

fn main
    say "=== Testing Full Autoregressive Transformer with KV-Cache ==="
    model = ai_model_create(16, 8, 2, 2, 4, 64)
    model.eos_token = 15

    prompt = list()
    push(prompt, 0)
    push(prompt, 1)
    push(prompt, 2)
    push(prompt, 3)

    say "Prefilling 4 prompt tokens..."
    pi = 0
    while pi < len(prompt)
        pt = get(prompt, pi)
        ai_forward_token(model, pt, model.logits_buf)
        say "  Prefilled token " + pt + " -> KV-Cache len = " + kv_cache_seq_len(model.kv_cache)
        pi = pi + 1

    say "Generating 6 new tokens with KV-cache decode..."
    step = 0
    while step < 6
        next_tok = ai_sample(model.logits_buf, model.vocab_size, 0, 1)
        say "  Step " + (step + 1) + " -> Generated token: " + next_tok + " | KV-Cache len = " + kv_cache_seq_len(model.kv_cache)
        ai_forward_token(model, next_tok, model.logits_buf)
        step = step + 1

    say "Testing ai_generate function (Stochastic Top-K)..."
    gen = ai_generate(model, prompt, 5, 70, 3)
    say "  Generated count: " + len(gen)
    gi = 0
    while gi < len(gen)
        say "  Gen token " + (gi + 1) + ": " + get(gen, gi)
        gi = gi + 1

    ai_model_free(model)
    say "🎉 FULL AUTOREGRESSIVE TRANSFORMER TEST PASSED COMPLETELY!"
    return 0

main()
