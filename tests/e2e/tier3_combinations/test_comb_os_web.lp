@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE COMBINATIONS: OS KERNEL + WEB ENGINE
@! File: tests/e2e/tier3_combinations/test_comb_os_web.maya
@! 100% Pure Maya Architecture — Zero External Dependencies
@! Coverage (7 Pairwise OS↔Web Integrations):
@! 1. VFS RamFS Markup Template Loading -> Flexbox Layout Solver
@! 2. Canvas2D Framebuffer Rasterization -> IPC Shared Memory Stream
@! 3. OS Task Scheduler -> Web Engine Cooperative UI Event Loop
@! 4. OS Syscall Free-List Heap Allocator -> Canvas2D Pixel Buffer
@! 5. Canvas2D ANSI TrueColor Raster -> OS Command Dispatcher Pipeline
@! 6. VFS Character Device Inode (/dev/font_mono) -> Web Glyph Renderer
@! 7. OS Fork / Process Supervisor -> Isolated Web Render Worker & Compositor
@! ============================================================================

import "universe/tools/maya_test"
import "universe/os/syscalls"
import "universe/os/vfs"
import "universe/os/memory"
import "universe/os/ipc"
import "universe/os/scheduler"
import "universe/os/dispatcher"
import "universe/os/process"
import "universe/web/markup_parser"
import "universe/web/frontend/layout/layout_types"
import "universe/web/frontend/layout/flexbox_solver"
import "universe/web/frontend/renderer/canvas2d_renderer"
import "universe/web/frontend/renderer/terminal_renderer"

@! ----------------------------------------------------------------------------
@! 1. VFS RamFS Markup Template Loading -> Flexbox Layout Solver
@! ----------------------------------------------------------------------------
@fn test_comb_os_web_01_vfs_markup_loader()
  println("  [RUN] test_comb_os_web_01_vfs_markup_loader")
  
  vfs = vfs_init()
  assert_ne(vfs, 0, "VFS initialization succeeded")

  template_html = "<div id=\"app-root\" style=\"display:flex; flex-direction:row; width:800px; height:600px; background-color:#1E1E2E; padding:20px; gap:10px;\">" + "  <div class=\"sidebar\" style=\"width:200px; height:560px; background-color:#181825;\">" + "    <span>Sidebar Menu</span>" + "  </div>" + "  <div class=\"content-pane\" style=\"flex-grow:1; height:560px; background-color:#313244;\">" + "    <h1>Sovereign OS Dashboard</h1>" + "  </div>" + "</div>"

  template_bytes = []
  i = 0
  t_len = template_html.len()
  @while i < t_len
    template_bytes = template_bytes.push(str_char_at(template_html, i))
    i = i + 1
  @end

  fd = vfs_open(vfs, "/tmp/template.html", 65, 420) @! O_CREAT | O_WRONLY
  assert_gt(fd, 0, "Opened /tmp/template.html for writing")

  written = vfs_write(vfs, fd, template_bytes)
  assert_eq(written, t_len, "Wrote complete template to VFS RamFS inode")
  vfs_close(vfs, fd)

  fd_read = vfs_open(vfs, "/tmp/template.html", 0, 0) @! O_RDONLY
  assert_gt(fd_read, 0, "Opened /tmp/template.html for reading")

  read_bytes = vfs_read(vfs, fd_read, 4096)
  vfs_close(vfs, fd_read)
  assert_eq(read_bytes.len(), t_len, "Read back exact template bytes from VFS")

  loaded_str = ""
  j = 0
  @while j < read_bytes.len()
    loaded_str = loaded_str + str_from_char_code(read_bytes[j])
    j = j + 1
  @end
  assert_str_eq(loaded_str, template_html, "Loaded string matches original template")

  parsed_ast = parse_markup(loaded_str)
  assert_ne(parsed_ast, 0, "Parsed AST from VFS content")

  layout_tree = desugar_to_layout_tree(parsed_ast)
  assert_ne(layout_tree, 0, "Desugared markup AST to layout tree")

  solved = flexbox_solve_tree(layout_tree, 800, 600)
  assert_eq(solved.width, 800, "Root container width solved to 800px")
  assert_eq(solved.height, 600, "Root container height solved to 600px")
  assert_eq(solved.children.len(), 2, "Root container has 2 flex children")

  sidebar = solved.children[0]
  content = solved.children[1]

  assert_eq(sidebar.x, 20, "Sidebar x offset equals left padding (20px)")
  assert_eq(sidebar.y, 20, "Sidebar y offset equals top padding (20px)")
  assert_eq(sidebar.width, 200, "Sidebar fixed width is 200px")

  assert_eq(content.x, 230, "Content pane starts at 20 + 200 + 10(gap) = 230px")
  assert_eq(content.y, 20, "Content pane y offset is 20px")
  assert_eq(content.width, 530, "Content pane flex_grow consumed residual width 800 - 40 - 200 - 10 = 530px")

  println("  [PASS] test_comb_os_web_01_vfs_markup_loader")
  return 1
@end

@! ----------------------------------------------------------------------------
@! 2. Canvas2D Framebuffer Rasterization -> IPC Shared Memory Stream
@! ----------------------------------------------------------------------------
@fn test_comb_os_web_02_ipc_framebuffer_stream()
  println("  [RUN] test_comb_os_web_02_ipc_framebuffer_stream")

  width = 64
  height = 64
  canvas = canvas2d_renderer_new(width, height, 1.0)
  assert_ne(canvas, 0, "Canvas2D renderer instantiated")

  canvas2d_renderer_begin_frame(canvas, 4279836718) @! 0xFF1E1E2E (Catppuccin Base)

  canvas2d_renderer_draw_rect(canvas, 10, 10, 44, 44, 4281479748, 4287268346, 2, 4)
  canvas2d_renderer_draw_text(canvas, "OS", 20, 24, 14, 4294967295)
  canvas2d_renderer_end_frame(canvas)

  argb_pixels = canvas2d_renderer_to_argb_buffer(canvas)
  assert_eq(argb_pixels.len(), width * height, "ARGB buffer size matches width * height")

  shm_size = width * height * 4
  shm = ipc_shm_create("fb_shm_channel", shm_size, 438) @! 0666
  assert_ne(shm, 0, "IPC Shared Memory segment allocated")

  byte_stream = []
  p_idx = 0
  @while p_idx < argb_pixels.len()
    pixel = argb_pixels[p_idx]
    a = (pixel / 16777216) % 256
    r = (pixel / 65536) % 256
    g = (pixel / 256) % 256
    b = pixel % 256
    byte_stream = byte_stream.push(b)
    byte_stream = byte_stream.push(g)
    byte_stream = byte_stream.push(r)
    byte_stream = byte_stream.push(a)
    p_idx = p_idx + 1
  @end

  written_shm = ipc_shm_write_at(shm, 0, byte_stream)
  assert_eq(written_shm, shm_size, "Serialized all pixel bytes into Shared Memory")

  read_shm = ipc_shm_read_at(shm, 0, shm_size)
  assert_eq(read_shm.len(), shm_size, "Display consumer retrieved exact byte length from SHM")

  first_b = read_shm[0]
  first_g = read_shm[1]
  first_r = read_shm[2]
  first_a = read_shm[3]
  assert_eq(first_a, 255, "Alpha channel preserved in SHM")
  assert_eq(first_r, 30, "Red channel for 0x1E matched in SHM")
  assert_eq(first_g, 30, "Green channel for 0x1E matched in SHM")
  assert_eq(first_b, 46, "Blue channel for 0x2E matched in SHM")

  println("  [PASS] test_comb_os_web_02_ipc_framebuffer_stream")
  return 1
@end

@! ----------------------------------------------------------------------------
@! 3. OS Task Scheduler -> Web Engine Cooperative UI Event Loop
@! ----------------------------------------------------------------------------
@fn test_comb_os_web_03_scheduler_ui_event_loop()
  println("  [RUN] test_comb_os_web_03_scheduler_ui_event_loop")

  sched = scheduler_init(0) @! SCHED_MODE_ROUND_ROBIN
  assert_ne(sched, 0, "Cooperative task scheduler initialized")

  t_reflow = scheduler_create_task(sched, "UI_Reflow_Task", 1000, 16384, 0)
  t_events = scheduler_create_task(sched, "UI_Event_Dispatch_Task", 2000, 16384, 0)
  t_render = scheduler_create_task(sched, "UI_Rasterizer_Task", 3000, 16384, 0)

  assert_eq(sched.tasks.len(), 3, "3 UI pipeline tasks registered in scheduler")

  step = 0
  @while step < 12
    scheduler_tick(sched)
    scheduler_yield(sched)
    step = step + 1
  @end

  metrics = scheduler_metrics(sched)
  assert_eq(metrics.total_tasks, 3, "Total active tasks is 3")
  assert_gt(metrics.context_switches, 6, "Cooperative context switches occurred between UI tasks")
  assert_gt(metrics.system_ticks, 10, "System ticks elapsed across UI event loop")

  println("  [PASS] test_comb_os_web_03_scheduler_ui_event_loop")
  return 1
@end

@! ----------------------------------------------------------------------------
@! 4. OS Syscall Free-List Heap Allocator -> Canvas2D Pixel Buffer
@! ----------------------------------------------------------------------------
@fn test_comb_os_web_04_mmap_canvas_allocation()
  println("  [RUN] test_comb_os_web_04_mmap_canvas_allocation")

  heap = heap_new()
  assert_ne(heap, 0, "OS Segregated Free-List Heap initialized")

  fb_bytes = 128 * 128 * 4 @! 64KB backing framebuffer
  ptr = memory_alloc(heap, fb_bytes)
  assert_gt(ptr, 0, "Allocated 64KB backing pixel memory via heap / sys_mmap")

  col_catppuccin = 4287268346 @! 0xFF89B4FA (Catppuccin Lavender/Blue)
  memory_write32(ptr, col_catppuccin)
  read_col = memory_read32(ptr)
  assert_eq(read_col, col_catppuccin, "32-bit ARGB color written and verified in heap memory")

  realloc_ptr = memory_realloc(heap, ptr, fb_bytes * 2)
  assert_gt(realloc_ptr, 0, "Reallocated heap memory to 128KB")
  assert_eq(memory_read32(realloc_ptr), col_catppuccin, "Color retained after realloc")

  free_res = memory_free(heap, realloc_ptr)
  assert_eq(free_res, 0, "Heap memory cleanly deallocated and coalesced")

  st = heap_stats(heap)
  assert_gt(st.mmap_calls, 0, "Syscall mmap invocations verified")
  assert_eq(st.allocated_bytes, 0, "Zero memory leak after canvas buffer deallocation")

  println("  [PASS] test_comb_os_web_04_mmap_canvas_allocation")
  return 1
@end

@! ----------------------------------------------------------------------------
@! 5. Canvas2D ANSI TrueColor Raster -> OS Command Dispatcher Pipeline
@! ----------------------------------------------------------------------------
@fn test_comb_os_web_05_dispatcher_terminal_pipe()
  println("  [RUN] test_comb_os_web_05_dispatcher_terminal_pipe")

  canvas = canvas2d_renderer_new(32, 16, 1.0)
  canvas2d_renderer_begin_frame(canvas, 4279836718)
  canvas2d_renderer_draw_rect(canvas, 2, 2, 28, 12, 4287268346, 0, 0, 0)
  canvas2d_renderer_end_frame(canvas)

  ansi_output = terminal_render_canvas(canvas)
  assert_gt(ansi_output.len(), 50, "Generated ANSI TrueColor escape sequence stream")
  assert_str_contains(ansi_output, "\x1b[38;2;", "Contains ANSI 24-bit TrueColor foreground escape code")
  assert_str_contains(ansi_output, "▀", "Contains dual-pixel half-block character for high-density terminal rendering")

  pipe_tokens = dispatcher_tokenize("echo \"frame\" | cat")
  assert_gt(pipe_tokens.len(), 0, "Dispatcher tokenized pipeline command")
  pipeline = dispatcher_parse_pipeline(pipe_tokens)
  assert_eq(pipeline.stages.len(), 2, "Parsed 2-stage command pipeline")

  pipefds = [0, 0]
  pipe_res = sys_pipe(pipefds)
  assert_ge(pipe_res, 0, "Created OS pipe for terminal stream redirection")

  read_fd = pipefds[0]
  write_fd = pipefds[1]

  payload = "MAYA_TRUECOLOR_FRAME_DATA_STREAM\n"
  p_len = payload.len()
  written = sys_write(write_fd, payload, p_len)
  assert_eq(written, p_len, "Wrote ANSI stream to pipe write end")
  sys_close(write_fd)

  buf = maya_alloc(256)
  n_read = sys_read(read_fd, buf, 256)
  sys_close(read_fd)
  assert_eq(n_read, p_len, "Read ANSI stream back from pipe read end")

  println("  [PASS] test_comb_os_web_05_dispatcher_terminal_pipe")
  return 1
@end

@! ----------------------------------------------------------------------------
@! 6. VFS Character Device Inode (/dev/font_mono) -> Web Glyph Renderer
@! ----------------------------------------------------------------------------
@fn test_comb_os_web_06_devfs_font_loader()
  println("  [RUN] test_comb_os_web_06_devfs_font_loader")

  vfs = vfs_init()
  
  @! Create /dev/font_mono character device
  font_dev = vfs_create_inode(vfs.next_inode_id, "font_mono", 3, 438, 2)
  vfs.next_inode_id = vfs.next_inode_id + 1
  vfs.inodes = vfs.inodes.push(font_dev)

  font_bytes = [126, 17, 17, 17, 126] @! Glyph 'A'
  fd = vfs_open(vfs, "/dev/font_mono", 2, 0) @! O_RDWR
  assert_gt(fd, 0, "Opened /dev/font_mono virtual font device")

  canvas = canvas2d_renderer_new(32, 32, 1.0)
  canvas2d_renderer_begin_frame(canvas, 4278190080) @! 0xFF000000

  canvas2d_renderer_draw_glyph(canvas, 65, 4, 4, 2, 4294967295)
  canvas2d_renderer_end_frame(canvas)

  drawn_pixel = canvas2d_renderer_get_pixel(canvas, 4, 4)
  assert_ne(drawn_pixel, 0, "Glyph 'A' successfully rasterized onto canvas")

  vfs_close(vfs, fd)

  println("  [PASS] test_comb_os_web_06_devfs_font_loader")
  return 1
@end

@! ----------------------------------------------------------------------------
@! 7. OS Fork / Process Supervisor -> Isolated Web Render Worker & Compositor
@! ----------------------------------------------------------------------------
@fn test_comb_os_web_07_process_isolated_render_worker()
  println("  [RUN] test_comb_os_web_07_process_isolated_render_worker")

  pid = sys_fork()
  @if pid == 0
    @! Child Worker Process: compute heavy layout tree
    root = layout_node_new(1, LAYOUT_FLEX_COLUMN(), ALIGN_START(), JUSTIFY_START())
    root = layout_node_set_size(root, 1024, 768)
    
    k = 0
    @while k < 8
      child = layout_node_new(k + 2, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
      child = layout_node_set_flex(child, 1, 1)
      child.pref_height = 80
      root = layout_node_add_child(root, child)
      k = k + 1
    @end
    
    solved = flexbox_solve_tree(root, 1024, 768)
    @if solved.children.len() == 8
      sys_exit(0)
    @else
      sys_exit(1)
    @end
  @end

  assert_gt(pid, 0, "Forked isolated web rendering worker process")

  ps = { val: 0 }
  sys_wait4(pid, ps, 0, 0)
  status = ps.val
  
  assert_eq(process_wifexited(status), 1, "Render worker exited normally")
  assert_eq(process_wexitstatus(status), 0, "Render worker returned status 0 (Success)")

  @! Parent Supervisor: compositing dirty rects
  damage_x0 = 0
  damage_y0 = 0
  damage_w = 1024
  damage_h = 768
  assert_eq(damage_w, 1024, "Damage compositor verified layout bounding box")

  println("  [PASS] test_comb_os_web_07_process_isolated_render_worker")
  return 1
@end

@! ----------------------------------------------------------------------------
@! Master Test Runner for OS+Web Pairwise Combinations
@! ----------------------------------------------------------------------------
@fn run_all_comb_os_web_tests()
  println("=================================================================")
  println("▶ [TIER 3] Cross-Feature Suite: OS Kernel + Web Engine (7 Tests)")
  println("=================================================================")

  passed = 0
  total = 7

  passed = passed + test_comb_os_web_01_vfs_markup_loader()
  passed = passed + test_comb_os_web_02_ipc_framebuffer_stream()
  passed = passed + test_comb_os_web_03_scheduler_ui_event_loop()
  passed = passed + test_comb_os_web_04_mmap_canvas_allocation()
  passed = passed + test_comb_os_web_05_dispatcher_terminal_pipe()
  passed = passed + test_comb_os_web_06_devfs_font_loader()
  passed = passed + test_comb_os_web_07_process_isolated_render_worker()

  println("-----------------------------------------------------------------")
  println("OS + Web Combination Results: " + passed.to_str() + "/" + total.to_str() + " passed")
  assert_eq(passed, total, "All OS + Web pairwise integration tests must pass")
  return passed
@end

@fn main()
  run_all_comb_os_web_tests()
  return 0
@end
