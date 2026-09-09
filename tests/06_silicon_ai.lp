// Test 06: AI Inference — Lipi 2.0
// Demonstrates: activation functions, neural net simulation, loops

// ReLU activation: clamp negative values to zero
fn relu x
    if x < 0
        return 0
    return x

// Classify based on threshold
fn classify score threshold
    if score >= threshold
        return 1
    return 0

// Tiny neural network layer simulation
// Weights and inputs
w1 = 3
w2 = 2
input1 = 5
input2 = 3

// Compute weighted sum at top level
network_output = w1 * input1 + w2 * input2
say "Network output:"
say network_output

// Apply ReLU activation
activated = relu network_output
say "After ReLU:"
say activated

// Simulate 5 neurons with shifted inputs
say "Neuron outputs (relu(i - 3)):"
for i in 1..5
    shifted = i - 3
    neuron_out = relu shifted
    say neuron_out

// Binary classification using paren syntax for 2-arg call
label = classify(network_output, 10)
say "Classified as:"
say label

say "PASS: Test 06 AI Inference"
