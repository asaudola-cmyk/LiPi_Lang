// Test 40: GGUF Tensor Inference — Lipi 2.0 Global Standard

fn tensor_dot a b c d = a * c + b * d

fn relu x
    if x < 0
        return 0
    return x

fn linear x w b = x * w + b

fn mlp_forward x
    h1 = linear(x, 3, 1)
    r1 = relu(h1)
    h2 = linear(r1, 2, 0)
    r2 = relu(h2)
    out = linear(r2, 1, 0)
    return out

say "=== Tensor Inference ==="
say tensor_dot(1, 2, 3, 4)
say tensor_dot(5, 6, 7, 8)
say relu(-5)
say relu(10)

for i in 1..6
    out = mlp_forward(i)
    say out

say "PASS: Test 40 GGUF Tensor Inference"
