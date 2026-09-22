import "universe/gpu/compute"
import "universe/core/io"

@fn main()
  say("Testing GPU Compute & SPIR-V Pipeline...")

  emitter = spirv_emitter_new()
  spirv_emit_header(emitter, 100)
  spirv_emit_capability(emitter, 1)
  spirv_emit_memory_model(emitter, 0, 1)

  if emitter.words.len() >= 5
    magic = emitter.words[0]
    if magic == 119734787
      say("PASS: SPIR-V Magic Header 0x07230203 verified")
    else
      say("FAIL: SPIR-V Magic mismatch")
    end
  else
    say("FAIL: Words len check")
  end

  should_small = gpu_should_dispatch_compute(1000)
  should_large = gpu_should_dispatch_compute(100000)
  if should_small == 0 && should_large == 1
    say("PASS: PCIe Latency Threshold (Small stays CPU, Large dispatches GPU)")
  else
    say("FAIL: PCIe Latency Threshold")
  end

  a = [1, 2, 3, 4]
  b = [1, 0, 0, 1]
  c = gpu_adaptive_matrix_multiply(a, b, 2, 2, 2)
  if c[0] == 1 && c[1] == 2 && c[2] == 3 && c[3] == 4
    say("PASS: Adaptive GEMM 2x2 Identity verified")
  else
    say("FAIL: Adaptive GEMM")
  end

  say("ALL GPU COMPUTE TESTS PASSED")
  return 0
@end

main()
