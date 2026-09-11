import "universe/core/string"
import "universe/core/collections"
import "universe/core/math"
import "universe/core/time"
import "universe/os/syscalls"
import "universe/net/udp"
import "universe/net/tcp"
import "compiler/backend/jit/jit_memory"
import "compiler/backend/jit/jit_executor"
import "compiler/backend/jit/jit_engine"
import "compiler/backend/jit/repl"
import "compiler/backend/jit/mod"
import "universe/swarm/types"
import "universe/swarm/protocol"
import "universe/swarm/serializer"
import "universe/swarm/discovery"
import "universe/swarm/task_registry"
import "universe/swarm/router"
import "universe/swarm/actor"
import "universe/swarm/node"
import "universe/swarm/swarm"
import "universe/gui/canvas"
import "universe/gui/font"
import "universe/gui/event"
import "universe/gui/widget"
import "universe/ide/syntax"
import "universe/ide/lsp_client"
import "universe/ide/ui_popup"
import "universe/ide/console"
import "universe/ide/runner"
import "universe/ide/toolbar"
import "universe/ide/editor"
import "universe/ide/studio"

@fn assert_eq(actual, expected, test_name)
  @if actual == expected
    println("  [PASS] " + test_name + " -> got " + actual.to_str())
  @else
    println("  [FAIL] " + test_name + " -> expected " + expected.to_str() + ", got " + actual.to_str())
    sys_exit(1)
  @end
@end

@fn assert_str_eq(actual, expected, test_name)
  @if actual == expected
    println("  [PASS] " + test_name + " -> got \"" + actual + "\"")
  @else
    println("  [FAIL] " + test_name + " -> expected \"" + expected + "\", got \"" + actual + "\"")
    sys_exit(1)
  @end
@end

@fn assert_true(cond, test_name)
  @if cond != 0
    println("  [PASS] " + test_name)
  @else
    println("  [FAIL] " + test_name)
    sys_exit(1)
  @end
@end

@! Swarm Compute Task Handlers
@fn remote_task_fib(n)
  @if n <= 0 return 0 @end
  @if n == 1 return 1 @end
  a = 0
  b = 1
  i = 2
  @while i <= n
    c = a + b
    a = b
    b = c
    i = i + 1
  @end
  return b
@end

@fn remote_task_collatz(n)
  steps = 0
  val = n
  @while val > 1
    @if val % 2 == 0
      val = val / 2
    @else
      val = val * 3 + 1
    @end
    steps = steps + 1
  @end
  return steps
@end

@fn main()
  println("=================================================================")
  println("⚡ GRAND TRINITY ADVERSARIAL CROSS-PILLAR WORKFLOW HARNESS ⚡")
  println("=================================================================")

  @! ---------------------------------------------------------------------------
  @! STAGE 1: Studio IDE Master Initialization & Code Authoring
  @! ---------------------------------------------------------------------------
  println("\n▶ Stage 1: Studio IDE Buffer Setup & LSP Diagnostics...")

  app = studio_app_create(800, 600, "src/cluster_trinity.maya")
  assert_true(app != 0, "ADV-TRINITY-01: Studio IDE application initialized (800x600)")

  trinity_script = "@fn cluster_main()\n  fib_res = worker_fib(25)\n  col_res = worker_collatz(27)\n  return aggregator(fib_res, col_res)\n@end"
  app.editor = studio_editor_set_text(app.editor, trinity_script)
  assert_eq(studio_editor_get_line_count(app.editor), 5, "ADV-TRINITY-02: Trinity script loaded into Editor buffer (5 lines)")

  @! LSP Diagnostics on Editor buffer
  lsp = lsp_client_new()
  lsp = lsp_client_open(lsp, "file:///cluster_trinity.maya", trinity_script)
  assert_eq(lsp.diagnostics.len(), 0, "ADV-TRINITY-03: LSP verifies 0 syntax errors in Trinity script")

  @! ---------------------------------------------------------------------------
  @! STAGE 2: Swarm P2P Cluster Initialization & Remote Task Execution
  @! ---------------------------------------------------------------------------
  println("\n▶ Stage 2: Swarm P2P Cluster Task Execution...")

  base_port = 41000
  master_node = swarm_init("trinity-master", "127.0.0.1", base_port + 1, base_port)
  worker_node = swarm_init("trinity-worker", "127.0.0.1", base_port + 2, base_port)

  assert_true(master_node.is_running != 0, "ADV-TRINITY-04: Master node active")
  assert_true(worker_node.is_running != 0, "ADV-TRINITY-05: Worker node active")

  swarm_register_task(worker_node, "worker_fib", remote_task_fib)
  swarm_register_task(worker_node, "worker_collatz", remote_task_collatz)
  peer_table_upsert(master_node.peer_table, worker_node.info)

  @! Remote dispatch: fib(25) == 75025
  stream1 = tcp_stream_connect(worker_node.info.host, worker_node.info.tcp_port)
  desc1 = task_descriptor_new(101, "worker_fib", [25], master_node.info.node_id, 3001)
  protocol_send_tcp(stream1.fd, MSG_TASK_SUBMIT(), serialize_task_descriptor(desc1))
  swarm_node_step(worker_node)
  resp1 = protocol_recv_tcp(stream1.fd)
  tcp_stream_close(stream1)
  h1 = deserialize_join_handle(resp1.payload)
  assert_eq(h1.result, 75025, "ADV-TRINITY-06: Remote worker computed fib(25) == 75025")

  @! Remote dispatch: collatz(27) == 111
  stream2 = tcp_stream_connect(worker_node.info.host, worker_node.info.tcp_port)
  desc2 = task_descriptor_new(102, "worker_collatz", [27], master_node.info.node_id, 3002)
  protocol_send_tcp(stream2.fd, MSG_TASK_SUBMIT(), serialize_task_descriptor(desc2))
  swarm_node_step(worker_node)
  resp2 = protocol_recv_tcp(stream2.fd)
  tcp_stream_close(stream2)
  h2 = deserialize_join_handle(resp2.payload)
  assert_eq(h2.result, 111, "ADV-TRINITY-07: Remote worker computed Collatz(27) == 111")

  @! ---------------------------------------------------------------------------
  @! STAGE 3: In-Memory JIT Compilation & Native Execution in RAM
  @! ---------------------------------------------------------------------------
  println("\n▶ Stage 3: In-Memory JIT Compilation & Native Execution...")

  jit_eng = jit_engine_new()
  
  @! Dynamic calculation in RAM without disk I/O
  jit_expr = "(" + h1.result.to_str() + " + " + h2.result.to_str() + " * 100) * 2"
  eval_res = jit_eval_expression(jit_eng, jit_expr)
  assert_eq(eval_res.success, 1, "ADV-TRINITY-08: JIT expression compiled into RAM")

  @! (75025 + 111 * 100) * 2 = (75025 + 11100) * 2 = 86125 * 2 = 172250
  final_trinity_val = eval_res.value
  assert_eq(final_trinity_val, 172250, "ADV-TRINITY-09: JIT executed in RAM == 172250")

  free_res = jit_engine_free(jit_eng)
  assert_eq(free_res, 1, "ADV-TRINITY-10: JIT RAM memory released via sys_munmap")

  @! ---------------------------------------------------------------------------
  @! STAGE 4: Studio Console Output Streaming & Toolbar State
  @! ---------------------------------------------------------------------------
  println("\n▶ Stage 4: Studio Console Streaming & Toolbar State...")

  app.console = console_set_tab(app.console, "OUTPUT")
  app.console = console_append(app.console, "🚀 [TRINITY] Master dispatched tasks to Swarm worker", "INFO")
  app.console = console_append(app.console, "  ↳ Swarm fib(25) = 75025, Collatz(27) = 111", "STDOUT")
  app.console = console_append(app.console, "  ↳ JIT RAM Aggregated Result: " + final_trinity_val.to_str(), "SUCCESS")
  app.console = console_append(app.console, "✔ [TRINITY] Cross-pillar workflow completed successfully", "SUCCESS")

  out_lines = console_get_lines_for_tab(app.console, "OUTPUT")
  assert_true(out_lines.len() >= 4, "ADV-TRINITY-11: Console OUTPUT tab contains 4 Trinity log lines")

  app.toolbar = toolbar_set_status(app.toolbar, "Trinity Completed", 0xFF4EC9B0)
  assert_str_eq(app.toolbar.status_message, "Trinity Completed", "ADV-TRINITY-12: Toolbar status updated to 'Trinity Completed'")

  @! ---------------------------------------------------------------------------
  @! STAGE 5: Master UI Framebuffer Rasterization & Verification
  @! ---------------------------------------------------------------------------
  println("\n▶ Stage 5: Master UI Framebuffer Rasterization & Integrity...")

  frame = studio_app_render_frame(app)
  assert_true(frame != 0, "ADV-TRINITY-13: Master UI frame rendered")

  px_title = canvas_get_pixel(frame, 10, 10)
  assert_eq(px_title, 4278221516, "ADV-TRINITY-14: Framebuffer title bar pixel matches 0xFF007ACC")

  px_status = canvas_get_pixel(frame, 10, 590)
  assert_eq(px_status, 4278221516, "ADV-TRINITY-15: Framebuffer status bar pixel matches 0xFF007ACC")

  s1 = swarm_shutdown(master_node)
  s2 = swarm_shutdown(worker_node)
  assert_true(s1 == 1 && s2 == 1, "ADV-TRINITY-16: Swarm cluster gracefully stopped")

  println("\n=================================================================")
  println("🏆 ALL 16 GRAND TRINITY WORKFLOW TESTS PASSED SUCCESSFULLY! 🏆")
  println("=================================================================")
  return 0
@end
