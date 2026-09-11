import "universe/core/string"
import "universe/core/collections"
import "universe/core/time"
import "universe/os/syscalls"
import "universe/gui/canvas"
import "universe/gui/font"
import "universe/ide/syntax"
import "universe/ide/studio"
import "universe/swarm/types"
import "universe/swarm/protocol"
import "compiler/backend/jit/mod"

@fn main()
  println("=================================================================")
  println("⏱️ MAYA TOOLCHAIN EXPANSION PERFORMANCE BENCHMARK HARNESS ⏱️")
  println("=================================================================")

  @! 1. JIT Compiler In-Memory Expression Latency
  eng = jit_engine_new()
  t0 = clock_ms()
  iters = 10
  i = 0
  @while i < iters
    expr = "(" + i.to_str() + " * 100 + 42) / 2"
    r = jit_eval_expression(eng, expr)
    i = i + 1
  @end
  t1 = clock_ms()
  jit_time = t1 - t0
  println("1. JIT Evaluated " + iters.to_str() + " distinct expressions in " + jit_time.to_str() + " ms (avg: " + (jit_time / iters).to_str() + " ms/eval)")
  jit_engine_free(eng)

  @! 2. Swarm Packet Framing & CRC32 Throughput
  t2 = clock_ms()
  pkt_iters = 1000
  p_i = 0
  test_p = "{\"task\":\"worker_matrix_multiply\",\"matrix_a\":[1,2,3,4],\"matrix_b\":[5,6,7,8]}"
  @while p_i < pkt_iters
    enc = protocol_encode_bytes(MSG_TASK_SUBMIT(), test_p)
    dec = protocol_decode_bytes(enc)
    p_i = p_i + 1
  @end
  t3 = clock_ms()
  swarm_time = t3 - t2
  println("2. Swarm Framed & Decoded " + pkt_iters.to_str() + " binary packets with CRC32 in " + swarm_time.to_str() + " ms")

  @! 3. Studio IDE Tokenizer & Frame Rasterization Latency
  app = studio_app_create(800, 600, "src/bench.maya")
  code_buf = "@fn process(data: array) -> i64\n  let sum = 0\n  for x in data {\n    sum = sum + x * 2\n  }\n  return sum\n@end"
  app.editor = studio_editor_set_text(app.editor, code_buf)
  
  t4 = clock_ms()
  render_iters = 50
  r_i = 0
  @while r_i < render_iters
    frame = studio_app_render_frame(app)
    r_i = r_i + 1
  @end
  t5 = clock_ms()
  ide_time = t5 - t4
  println("3. Studio IDE Rasterized " + render_iters.to_str() + " full 800x600 frames in " + ide_time.to_str() + " ms (avg: " + (ide_time / render_iters).to_str() + " ms/frame)")

  println("\n=================================================================")
  println("🏁 ALL PERFORMANCE BENCHMARKS EXECUTED SUCCESSFULLY 🏁")
  println("=================================================================")
  return 0
@end
