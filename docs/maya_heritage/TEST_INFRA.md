# Maya Sovereign Test Infrastructure (TEST_INFRA.md)
**Authoritative Architectural Specification for Maya Ecosystem Expansion E2E Testing**  
**Version**: 2.0.0 — Benchmark Integrity Mode  
**Scope**: 4-Tier Opaque-Box Testing across Native OS Kernel, DOM-Bypassing Web Engine, Native AI Neural Swarm, and Repository Purity  

---

## 1. Executive Overview & Architecture

The Maya Sovereign Test Infrastructure provides an opaque-box, requirement-driven, process-isolated testing ecosystem written entirely in 100% pure Maya syntax (`.maya`). It operates directly on bare metal or Linux x86-64 using raw syscalls (`0x0F 0x05`), completely eliminating foreign test frameworks (PyTest, Cargo, CTest, Jest), external build systems (Make, CMake), intermediate compilers (GCC, Clang), and foreign scripting languages (.py, .sh, .c, .cpp, .h).

```
                               ┌───────────────────────────────────────────────┐
                               │           Maya Sovereign Universe             │
                               │        `ORIGINAL_REQUEST.md` / `PROJECT.md`   │
                               └───────────────────────┬───────────────────────┘
                                                       │
               ┌───────────────────────────────────────┼───────────────────────────────────────┐
               ▼                                       ▼                                       ▼
    ┌─────────────────────┐                 ┌─────────────────────┐                 ┌─────────────────────┐
    │   Native OS Kernel  │                 │ DOM-Bypassing Web   │                 │   Native AI Swarm   │
    │   `universe/os/`    │                 │   `universe/web/`   │                 │   `universe/ai/`    │
    │     (F01 - F08)     │                 │     (F09 - F13)     │                 │     (F14 - F19)     │
    └──────────┬──────────┘                 └──────────┬──────────┘                 └──────────┬──────────┘
               │                                       │                                       │
               └───────────────────────────────────────┼───────────────────────────────────────┘
                                                       ▼
                       ┌───────────────────────────────────────────────────────────────┐
                       │               Sovereign 4-Tier Test Matrix                    │
                       │                        (242 Tests)                            │
                       ├───────────────────────────────────────────────────────────────┤
                       │  Tier 1: Feature Coverage (105 tests, ≥5 per F01-F21)         │
                       │  Tier 2: Boundary & Corner Cases (105 tests, ≥5 per F01-F21)  │
                       │  Tier 3: Cross-Feature Combinations (21 pairwise tests)       │
                       │  Tier 4: Real-World Scenarios (11 full application workloads) │
                       └───────────────────────────────┬───────────────────────────────┘
                                                       │
                                                       ▼
                       ┌───────────────────────────────────────────────────────────────┐
                       │          Sovereign Test Engine & Crash Guard          │
                       │              `universe/tools/maya_test.maya`                  │
                       │   - Linux x86-64 `sys_fork`(57) & `sys_wait4`(61) Isolation   │
                       │   - Multi-Tier Assertions (Eq, True, Near, Str, Panic)       │
                       │   - JUnit XML (`junit.xml`) & JSON (`test_results.json`)      │
                       └───────────────────────────────────────────────────────────────┘
```

---

## 2. Feature Inventory Matrix (F01 – F21)

Every feature defined in `PROJECT.md` is assigned dedicated test suites across all 4 tiers:

| ID | Feature Name | Domain | Primary Implementation Module | Tier 1 Tests | Tier 2 Tests | Tier 3 Pairwise | Tier 4 Scenario |
|---|---|---|---|:---:|:---:|:---:|:---:|
| **F01** | Raw Syscall Layer | OS Kernel | `universe/os/syscalls.maya` | 5 | 5 | OS↔Web, OS↔AI | Desktop, Unikernel |
| **F02** | Process Management | OS Kernel | `universe/os/process.maya` | 5 | 5 | OS↔AI | Self-Hosting Compiler |
| **F03** | Native Command Dispatcher | OS Kernel | `universe/os/dispatcher.maya` | 5 | 5 | OS↔Web | Headless Browser |
| **F04** | Coroutine / Task Scheduler | OS Kernel | `universe/os/scheduler.maya` | 5 | 5 | OS↔AI | Autonomous Agent |
| **F05** | Heap Memory Allocator | OS Kernel | `universe/os/memory.maya` | 5 | 5 | OS↔AI | KV Database |
| **F06** | Virtual Filesystem (VFS) | OS Kernel | `universe/os/vfs.maya` | 5 | 5 | OS↔Web, OS↔AI | KV Database |
| **F07** | Inter-Process Comm (IPC) | OS Kernel | `universe/os/ipc.maya` | 5 | 5 | OS↔AI | Swarm Inference Server |
| **F08** | Bare-Metal Boot & Drivers | OS Kernel | `universe/os/boot/`, `drivers/` | 5 | 5 | OS↔Web | Bare-Metal Boot Sim |
| **F09** | Sovereign Markup Parser | Web Engine | `universe/web/markup_parser.maya` | 5 | 5 | OS↔Web, Web↔AI | Headless Browser |
| **F10** | Flexbox Layout Engine | Web Engine | `universe/web/frontend/layout/` | 5 | 5 | Web↔AI | Desktop Environment |
| **F11** | Pure Maya Canvas2D | Web Engine | `universe/web/frontend/renderer/` | 5 | 5 | Web↔AI | Canvas Document Editor |
| **F12** | Dirty Rect Damage Compositor | Web Engine | `universe/web/frontend/dom_bypass/` | 5 | 5 | Web↔AI | Desktop Environment |
| **F13** | ANSI Terminal TrueColor Raster | Web Engine | `universe/web/frontend/renderer/` | 5 | 5 | OS↔Web, Web↔AI | Terminal Browser |
| **F14** | N-D Tensor Engine | AI Swarm | `universe/ai/tensor.maya` | 5 | 5 | Web↔AI | NN Training Pipeline |
| **F15** | Autograd Engine | AI Swarm | `universe/ai/autograd.maya` | 5 | 5 | AI↔OS | NN Training Pipeline |
| **F16** | Neural Network Architecture | AI Swarm | `universe/ai/nn.maya` | 5 | 5 | Web↔AI | LLM Inference Server |
| **F17** | Transformer & LLM Engine | AI Swarm | `universe/ai/transformer/gpt.maya` | 5 | 5 | Web↔AI | LLM Inference Server |
| **F18** | Autonomous Multi-Agent Swarm | AI Swarm | `universe/ai/swarm.maya` | 5 | 5 | OS↔AI, Web↔AI | Swarm Code Engineer |
| **F19** | Autonomous Task Routing | AI Swarm | `universe/ai/swarm.maya` | 5 | 5 | OS↔AI | Swarm Code Review |
| **F20** | Sovereign Test Framework | Test Infra | `universe/tools/maya_test.maya` | 5 | 5 | All Domains | All Scenarios |
| **F21** | Zero Foreign Code Purity | Sovereign | Repository-Wide Scan | 5 | 5 | All Domains | Sovereign OS App |
| **Total** | **21 Features** | **4 Domains** | | **105** | **105** | **21** | **11** |

**Grand Total Test Cases**: 105 (Tier 1) + 105 (Tier 2) + 21 (Tier 3) + 11 (Tier 4) = **242 Test Cases**

---

## 3. Detailed 4-Tier Test Suite Specification

### 3.1 Tier 1: Feature Coverage (105 Test Cases)

Tier 1 validates the baseline functional happy paths for all 21 features under standard operational inputs.

#### OS Kernel Domain (F01 – F08)
- **F01 (Raw Syscalls)**:
  1. `test_f01_syscall_read_write`: Direct `sys_read(0)` and `sys_write(1)` stream I/O.
  2. `test_f01_syscall_mmap_munmap`: Anonymous virtual memory allocation via `sys_mmap(9)` and `sys_munmap(11)`.
  3. `test_f01_syscall_getpid_getppid`: Query process ID (`sys_getpid`, 39) and parent PID (`sys_getppid`, 110).
  4. `test_f01_syscall_clock_nanosleep`: Monotonic clock sleep verification (`sys_clock_nanosleep`, 230).
  5. `test_f01_syscall_uname_sysinfo`: Inspect Linux kernel architecture and version via `sys_uname(63)`.
- **F02 (Process Management)**:
  1. `test_f02_process_fork_wait`: Child process creation via `sys_fork(57)` and parent synchronization with `sys_wait4(61)`.
  2. `test_f02_process_execve`: Replace process image with native ELF binary via `sys_execve(59)`.
  3. `test_f02_process_wait4_rusage`: Retrieve child execution statistics and resource usage.
  4. `test_f02_process_kill_signal`: Dispatch `SIGTERM`/`SIGKILL` to child process via `sys_kill(62)`.
  5. `test_f02_process_exit_codes`: Verify standard exit code propagation (0, 1, 42, 127) via `sys_exit(60)`.
- **F03 (Command Dispatcher)**:
  1. `test_f03_dispatcher_tokenize`: Tokenize space-separated, quoted command strings in pure Maya.
  2. `test_f03_dispatcher_path_lookup`: Locate executable binaries across colon-separated `$PATH`.
  3. `test_f03_dispatcher_pipe_redirection`: Unidirectional pipeline redirection between two processes (`A | B`).
  4. `test_f03_dispatcher_file_redirection`: Standard I/O redirection (`< input.txt`, `> output.txt`).
  5. `test_f03_dispatcher_no_shell_exec`: Execute commands without invoking `/bin/sh` or `/bin/bash`.
- **F04 (Task Scheduler)**:
  1. `test_f04_scheduler_tcb_init`: Initialize Task Control Blocks with priority, stack pointer, and state.
  2. `test_f04_scheduler_round_robin`: Cooperative coroutine context switching among 4 tasks.
  3. `test_f04_scheduler_mlfq_priority`: Multi-Level Feedback Queue priority decay on CPU usage.
  4. `test_f04_scheduler_task_yield`: Task voluntary yield and subsequent execution resumption.
  5. `test_f04_scheduler_task_cancellation`: Graceful termination and cleanup of pending tasks.
- **F05 (Heap Allocator)**:
  1. `test_f05_alloc_basic_malloc_free`: Basic dynamic allocation, byte read/write, and deallocation.
  2. `test_f05_alloc_segregated_freelist`: Sized bin allocation matching powers of two (32B to 4KB).
  3. `test_f05_alloc_block_split`: Split large memory chunk to satisfy smaller allocation request.
  4. `test_f05_alloc_block_coalesce`: Merge contiguous adjacent free blocks on deallocation.
  5. `test_f05_alloc_mmap_expansion`: Automatically grow heap arena via `sys_mmap` when free list exhausted.
- **F06 (Virtual Filesystem - VFS)**:
  1. `test_f06_vfs_ramfs_create_write_read`: In-memory inode file creation, write, read, and content verification.
  2. `test_f06_vfs_directory_hierarchy`: Create nested directory paths and traverse directory tree.
  3. `test_f06_vfs_dev_null`: Writes to `/dev/null` succeed; reads return EOF (0 bytes).
  4. `test_f06_vfs_dev_zero`: Reads from `/dev/zero` fill buffer with zero bytes.
  5. `test_f06_vfs_dev_random`: Reads from `/dev/random` produce non-zero pseudo-random entropy.
- **F07 (Inter-Process Communication - IPC)**:
  1. `test_f07_ipc_named_pipe_fifo`: Create FIFO via `sys_mknod`, write in child, read in parent.
  2. `test_f07_ipc_shared_memory`: `sys_mmap` with `MAP_SHARED` to exchange structured data across processes.
  3. `test_f07_ipc_unix_domain_socket`: AF_UNIX stream socket bind, listen, connect, accept, echo roundtrip.
  4. `test_f07_ipc_message_queue`: Enqueue structured messages and dequeue by priority.
  5. `test_f07_ipc_semaphore_sync`: Binary semaphore synchronization across forked worker tasks.
- **F08 (Bare-Metal Boot & Drivers)**:
  1. `test_f08_boot_multiboot2_header`: Validate Multiboot2 magic `0xE85250D6` and header checksum.
  2. `test_f08_boot_gdt_descriptors`: Validate Long Mode 64-bit Null, Code, and Data segment descriptors.
  3. `test_f08_boot_paging_pml4`: Construct 4-level MMU PML4 identity-mapped page tables.
  4. `test_f08_driver_vga_text_buffer`: Write colored characters directly to simulated VGA memory `0xB8000`.
  5. `test_f08_driver_uart_serial`: Format and emit ASCII characters to simulated UART 16550 port `0x3F8`.

#### Web Engine Domain (F09 – F13)
- **F09 (Sovereign Markup Parser)**:
  1. `test_f09_markup_tag_tokenization`: Tokenize standard opening, closing, and self-closing markup tags.
  2. `test_f09_markup_attribute_parsing`: Parse `id`, `class`, and inline `style="..."` attributes.
  3. `test_f09_markup_tree_hierarchy`: Construct nested AST node hierarchy with bidirectional links.
  4. `test_f09_markup_style_rule_matching`: Parse CSS selectors (`.class`, `#id`, `tag`) and compute computed styles.
  5. `test_f09_markup_text_node_extraction`: Extract, normalize, and preserve raw text node contents.
- **F10 (Flexbox Layout Engine)**:
  1. `test_f10_flex_row_direction`: Position child nodes horizontally with fixed widths.
  2. `test_f10_flex_col_direction`: Position child nodes vertically with fixed heights.
  3. `test_f10_flex_grow_shrink`: Proportional residual space distribution using integer conservation.
  4. `test_f10_flex_justify_align`: Solve `justify-content` (flex-start, center, space-between) and `align-items`.
  5. `test_f10_flex_margin_padding_gap`: Compute exact bounding boxes with box-model margin, padding, and gap.
- **F11 (Pure Maya Canvas2D)**:
  1. `test_f11_canvas_clear_rect`: Fill ARGB 32-bit pixel buffer with solid background color.
  2. `test_f11_canvas_draw_line_shape`: Rasterize lines and stroked rectangles into framebuffer.
  3. `test_f11_canvas_text_rendering`: Draw monospace bitmap glyphs onto pixel buffer.
  4. `test_f11_canvas_alpha_blending`: Porter-Duff source-over alpha blending onto background pixels.
  5. `test_f11_canvas_clip_stack`: Push and pop rectangular clipping regions restricting draw calls.
- **F12 (Dirty Rect Damage Compositor)**:
  1. `test_f12_damage_rect_union`: Merge overlapping damage rects into minimal bounding union.
  2. `test_f12_damage_incremental_repaint`: Re-render only modified dirty regions into backbuffer.
  3. `test_f12_damage_hidpi_scaling`: Scale logical drawing coordinates by integer scale factor (2x).
  4. `test_f12_damage_clipping_bounds`: Clamp damaged rects to physical screen boundaries.
  5. `test_f12_damage_buffer_swap`: Swap front and back pixel buffers after compositing dirty areas.
- **F13 (ANSI Terminal TrueColor Raster)**:
  1. `test_f13_ansi_color_escape_codes`: Format 24-bit RGB values to `\x1b[38;2;R;G;Bm` foreground codes.
  2. `test_f13_ansi_halfblock_compression`: Compress 2 vertical pixels into 1 character cell with `▀` (U+2580).
  3. `test_f13_ansi_cursor_positioning`: Generate ANSI cursor jump escape sequences `\x1b[row;colH`.
  4. `test_f13_ansi_clear_screen`: Generate screen reset and cursor hide/show sequences.
  5. `test_f13_ansi_frame_serialization`: Serialize 80x25 ARGB framebuffer into valid terminal string.

#### AI Neural Swarm Domain (F14 – F19)
- **F14 (N-D Tensor Engine)**:
  1. `test_f14_tensor_creation_strides`: Initialize 1D to 4D tensors with accurate contiguous strides.
  2. `test_f14_tensor_gemm_matmul`: Multiply 2D matrices (MxK * KxN) and assert numeric precision.
  3. `test_f14_tensor_broadcasting`: Add 1D bias vector to 2D matrix via implicit dimension expansion.
  4. `test_f14_tensor_transcendental_math`: Calculate sqrt, exp, log, tanh via polynomial series.
  5. `test_f14_tensor_activations`: Evaluate ReLU, Sigmoid, Softmax, GELU over tensor elements.
- **F15 (Autograd Engine)**:
  1. `test_f15_autograd_scalar_dag`: Construct computational graph and backprop scalar polynomial gradients.
  2. `test_f15_autograd_tensor_add_mul`: Compute input gradients for tensor addition and Hadamard multiplication.
  3. `test_f15_autograd_matmul_backward`: Compute input gradients dL/dA and dL/dB for matrix product.
  4. `test_f15_autograd_relu_grad`: Compute subgradient of ReLU (1.0 for x > 0, 0.0 for x <= 0).
  5. `test_f15_autograd_graph_reset`: Clear and re-accumulate gradients across training iterations.
- **F16 (Neural Network Architecture)**:
  1. `test_f16_nn_linear_layer`: Initialize Linear layer weights/bias, forward pass, assert output shape.
  2. `test_f16_nn_layer_norm`: Normalize feature dimension to zero mean and unit variance.
  3. `test_f16_nn_multihead_attention`: Compute scaled dot-product multihead self-attention.
  4. `test_f16_nn_loss_functions`: Compute MSELoss and CrossEntropyLoss with softmax targets.
  5. `test_f16_nn_optimizer_step`: Update parameters using AdamW and SGD with momentum.
- **F17 (Transformer & LLM Engine)**:
  1. `test_f17_transformer_block`: Forward pass through Transformer block (Attention + MLP + ResConn).
  2. `test_f17_transformer_kv_cache`: Append tokens to ring-buffered Key-Value cache.
  3. `test_f17_transformer_safetensors_load`: Ingest mock SafeTensors header and parse tensor byte offsets.
  4. `test_f17_transformer_token_sampling`: Sample next token with temperature, Top-K, and Top-P filtering.
  5. `test_f17_transformer_autoregressive_gen`: Generate 5-token completion sequence autoregressively.
- **F18 (Autonomous Multi-Agent Swarm)**:
  1. `test_f18_swarm_agent_init`: Instantiate Planner, Coder, Critic, Synthesizer agents with role state.
  2. `test_f18_swarm_state_machine`: Verify transitions (IDLE -> PLANNING -> CODING -> REVIEW -> DONE).
  3. `test_f18_swarm_mailbox_dispatch`: Post and dequeue structured messages across agent mailboxes.
  4. `test_f18_swarm_peer_consensus`: Reconcile conflicting findings across Critic and Coder agents.
  5. `test_f18_swarm_cluster_lifecycle`: Spin up swarm cluster, dispatch mission, await shutdown.
- **F19 (Autonomous Task Routing)**:
  1. `test_f19_router_capability_match`: Route code generation tasks to Coder and architecture to Planner.
  2. `test_f19_router_load_balancing`: Distribute workload evenly among multiple worker agents.
  3. `test_f19_router_task_retry`: Re-dispatch task on agent execution timeout or assertion failure.
  4. `test_f19_router_priority_queue`: Dequeue high-priority tasks ahead of background tasks.
  5. `test_f19_router_dependency_graph`: Execute tasks respecting DAG prerequisite completion.

#### Sovereign Test Infra & Purity (F20 – F21)
- **F20 (Sovereign Test Framework)**:
  1. `test_f20_test_assert_primitives`: Validate `assert_eq`, `assert_true`, `assert_ne`, `assert_near`.
  2. `test_f20_test_process_isolation`: Confirm test failure in child process does not abort runner.
  3. `test_f20_test_crash_recovery`: Capture SIGSEGV/panic in child and mark test as FAILED.
  4. `test_f20_test_timing_measurement`: Measure execution duration per test in milliseconds.
  5. `test_f20_test_report_serialization`: Serialize test suite results into JUnit XML and JSON.
- **F21 (Zero Foreign Code Purity)**:
  1. `test_f21_purity_no_c_cpp_files`: Audit repository for `.c`, `.cpp`, `.h`, `.hpp` files (0 allowed).
  2. `test_f21_purity_no_python_files`: Audit repository for `.py`, `.pyc` files (0 allowed).
  3. `test_f21_purity_no_shell_scripts`: Audit repository for `.sh`, `.bash`, `.zsh` files (0 allowed).
  4. `test_f21_purity_freestanding_elf`: Verify compiled binaries have 0 dynamic dependencies (`ldd`).
  5. `test_f21_purity_pure_maya_compiler`: Verify all universe source files compile via `bin/mayac_v2`.

---

### 3.2 Tier 2: Boundary & Corner Cases (105 Test Cases)

Tier 2 exercises edge conditions, empty/zero/null states, buffer limits, integer boundaries, and recovery from invalid input.

#### OS Kernel Domain Boundaries (F01 – F08)
- **F01**: `test_f01_boundary_syscall_invalid_nr` (sys nr -1, 99999 -> -ENOSYS), `test_f01_boundary_syscall_null_pointer` (NULL buf -> -EFAULT), `test_f01_boundary_syscall_zero_length` (0-byte read/write -> 0), `test_f01_boundary_syscall_max_int_args` (0x7FFFFFFFFFFFFFFF args -> no crash), `test_f01_boundary_syscall_bad_fd` (fd -1, 999 -> -EBADF).
- **F02**: `test_f02_boundary_wait_nonexistent_pid` (wait unowned PID -> -ECHILD), `test_f02_boundary_execve_nonexistent_file` (invalid bin -> -ENOENT), `test_f02_boundary_kill_zero_pid` (PID 0 boundary handling), `test_f02_boundary_process_tree_orphan` (parent dies before child -> safe orphan handling), `test_f02_boundary_zombie_reap` (rapid fork/exit loop with immediate reap).
- **F03**: `test_f03_boundary_dispatcher_empty_cmd` (empty string `""` -> error), `test_f03_boundary_dispatcher_unclosed_quotes` (unterminated quote -> handled), `test_f03_boundary_dispatcher_giant_arg_list` (1,000 args -> no buffer overflow), `test_f03_boundary_dispatcher_broken_pipe` (closed pipe target -> SIGPIPE/EPIPE handled), `test_f03_boundary_dispatcher_missing_path` (empty `$PATH` -> ENOENT handled).
- **F04**: `test_f04_boundary_scheduler_zero_tasks` (0 tasks -> clean exit), `test_f04_boundary_scheduler_single_task` (1 task -> runs to completion), `test_f04_boundary_scheduler_max_tasks` (1,024 TCB limit handling), `test_f04_boundary_scheduler_infinite_yield` (tight yield loop fair scheduling), `test_f04_boundary_scheduler_deep_recursion_task` (deep stack task yields safely).
- **F05**: `test_f05_boundary_alloc_zero_bytes` (alloc 0 bytes -> valid null token), `test_f05_boundary_alloc_giant_block` (alloc 1GB -> mmap or ENOMEM), `test_f05_boundary_alloc_double_free` (double free detected safely), `test_f05_boundary_alloc_unaligned_size` (odd byte allocs 1,3,7 -> 8-byte aligned), `test_f05_boundary_alloc_fragmentation_stress` (1,000 alloc/free iterations).
- **F06**: `test_f06_boundary_vfs_path_overflow` (path > 4096 bytes -> ENAMETOOLONG), `test_f06_boundary_vfs_nested_dir_depth` (64-level deep directory nesting), `test_f06_boundary_vfs_read_past_eof` (read past EOF -> 0 bytes), `test_f06_boundary_vfs_duplicate_create` (O_EXCL create on existing -> EEXIST), `test_f06_boundary_vfs_delete_open_file` (unlink open file -> inode persists until closed).
- **F07**: `test_f07_boundary_ipc_pipe_buffer_full` (64KB into unread pipe -> EAGAIN), `test_f07_boundary_ipc_shm_concurrent_write` (adjacent cache line writes across processes), `test_f07_boundary_ipc_uds_long_socket_path` (socket path > 108 bytes boundary), `test_f07_boundary_ipc_empty_queue_dequeue` (dequeue empty queue -> ENOMSG), `test_f07_boundary_ipc_sem_negative_val` (decrement semaphore below 0).
- **F08**: `test_f08_boundary_vga_cursor_out_of_bounds` (cursor at 999,999 -> clamped to 79,24), `test_f08_boundary_vga_newline_scroll` (100 newlines scroll without corruption), `test_f08_boundary_idt_vector_255` (interrupt handler at vector 255), `test_f08_boundary_paging_4gb_boundary` (map page at 0xFFFFFFFF and 0x100000000), `test_f08_boundary_uart_baud_zero` (invalid baud 0 -> fallback to 115200).

#### Web Engine Domain Boundaries (F09 – F13)
- **F09**: `test_f09_boundary_markup_empty_doc` (empty string `""` -> root container node), `test_f09_boundary_markup_deep_nesting` (100 nested `<div>`s -> no stack overflow), `test_f09_boundary_markup_malformed_tags` (unclosed tags -> auto-closing recovery), `test_f09_boundary_markup_giant_text_node` (1MB text node parsed cleanly), `test_f09_boundary_markup_special_chars` (HTML entities and UTF-8 multi-byte characters).
- **F10**: `test_f10_boundary_flex_zero_container` (container 0x0 -> children clamped to 0), `test_f10_boundary_flex_negative_margin` (negative margin overlap calculations), `test_f10_boundary_flex_infinite_grow` (100 items grow -> integer rounding exact match), `test_f10_boundary_flex_deep_hierarchy` (30 nested containers coordinate accumulation), `test_f10_boundary_flex_max_int_size` (width=2^30 -> no integer overflow).
- **F11**: `test_f11_boundary_canvas_offscreen_draw` (draw at -500, -500 -> fully clipped, no fault), `test_f11_boundary_canvas_zero_size_draw` (width=0, height=0 -> no-op), `test_f11_boundary_canvas_empty_clip` (clip rect 0,0,0,0 -> all draws clipped), `test_f11_boundary_canvas_max_clip_stack` (64 clip pushes -> depth limit enforced), `test_f11_boundary_canvas_alpha_limits` (alpha=0 no change, alpha=255 full overwrite).
- **F12**: `test_f12_boundary_damage_empty_rect` (damage 0,0,0,0 -> ignored), `test_f12_boundary_damage_full_screen` (full screen damage -> single repaint), `test_f12_boundary_damage_disjoint_rects` (50 disjoint 1x1 pixels -> bounding union), `test_f12_boundary_damage_negative_coords` (negative coordinates clamped to 0,0), `test_f12_boundary_damage_hidpi_fractional` (fractional scale factor rounding).
- **F13**: `test_f13_boundary_ansi_zero_size` (render 0x0 canvas -> empty string), `test_f13_boundary_ansi_odd_height` (odd height e.g. 25 rows -> bottom half-block handled), `test_f13_boundary_ansi_identical_pixels` (solid color screen -> escape code deduplication), `test_f13_boundary_ansi_color_extremes` (RGB 0,0,0 and 255,255,255 formatting), `test_f13_boundary_ansi_buffer_wrap` (width > terminal columns -> wrap handling).

#### AI Neural Swarm Domain Boundaries (F14 – F19)
- **F14**: `test_f14_boundary_tensor_zero_dim` (0-D scalar tensor operations), `test_f14_boundary_tensor_empty_shape` (shape `[0, 10]` -> 0 elements, no fault), `test_f14_boundary_tensor_incompatible_matmul` (shape `[2,3]` * `[4,5]` -> mismatch error), `test_f14_boundary_tensor_extreme_values` (INF, -INF, 0.0, subnormals), `test_f14_boundary_tensor_large_broadcast` (broadcast `[1,1,1]` to `[10,20,30]`).
- **F15**: `test_f15_boundary_autograd_detached_leaf` (`requires_grad=false` -> no gradient computed), `test_f15_boundary_autograd_cyclic_reference` (cyclic graph detection/rejection), `test_f15_boundary_autograd_zero_grad_division` (gradient of `x / y` where `y == 0`), `test_f15_boundary_autograd_deep_chain` (100 additions backprop without recursion overflow), `test_f15_boundary_autograd_branch_reconvergence` (`y = x*x + x` -> `dy/dx = 2x + 1`).
- **F16**: `test_f16_boundary_nn_linear_dim1` (in_features=1, out_features=1), `test_f16_boundary_nn_layernorm_zero_var` (constant input vector -> eps prevents division by zero), `test_f16_boundary_nn_attention_mask_all_zeros` (full masking -> softmax -INF tokens), `test_f16_boundary_nn_loss_identical_preds` (identical predictions and targets -> loss=0.0), `test_f16_boundary_nn_optimizer_zero_lr` (lr=0.0 -> weights unchanged).
- **F17**: `test_f17_boundary_transformer_seq_len_1` (single-token forward pass), `test_f17_boundary_transformer_kv_cache_full` (KV cache overflow -> ring buffer eviction), `test_f17_boundary_transformer_temp_zero` (temperature=0.0 -> greedy argmax), `test_f17_boundary_transformer_top_k_1` (Top-K=1 -> deterministic top token), `test_f17_boundary_transformer_empty_safetensors` (0-byte safetensors file -> parse error).
- **F18**: `test_f18_boundary_swarm_empty_cluster` (0 agents -> error), `test_f18_boundary_swarm_unhandled_msg_type` (unknown message payload -> dead-letter queue), `test_f18_boundary_swarm_max_agent_limit` (spawn beyond cluster capacity -> backpressure), `test_f18_boundary_swarm_deadlock_detection` (circular message wait -> timeout detection), `test_f18_boundary_swarm_agent_crash_recovery` (agent panic -> supervisor restart).
- **F19**: `test_f19_boundary_router_cyclic_dep` (circular task DAG -> cycle rejection), `test_f19_boundary_router_no_capable_agent` (missing capability -> UnrouteableError), `test_f19_boundary_router_burst_queue` (10,000 tasks burst -> bounded memory), `test_f19_boundary_router_all_workers_busy` (busy workers -> priority queue wait), `test_f19_boundary_router_zero_timeout` (0ms timeout -> immediate expiry).

#### Sovereign Test Infra & Purity Boundaries (F20 – F21)
- **F20**: `test_f20_boundary_test_empty_suite` (0 test files -> reports 0 tests, exit 0), `test_f20_boundary_test_all_failing` (100% test failure -> exit code 1, full logs), `test_f20_boundary_test_infinite_loop_timeout` (infinite loop test killed by watchdog), `test_f20_boundary_test_large_output_capture` (10MB stdout capture without buffer overflow), `test_f20_boundary_test_nested_fork` (test that forks child processes -> wait4 cleans all).
- **F21**: `test_f21_boundary_purity_hidden_dot_c` (scan for hidden `.temp.c`, `.cache.py` -> 0 found), `test_f21_boundary_purity_symlink_traversal` (symlink check ensuring no foreign runtime linkage), `test_f21_boundary_purity_binary_strings` (scan binary for libc symbols `printf`, `malloc` -> 0 found), `test_f21_boundary_purity_shebang_scan` (verify no files begin with `#!/bin/bash` or `#!/usr/bin/python`), `test_f21_boundary_purity_compiler_no_fork_gcc` (compiler execution does not invoke `execve("gcc")`).

---

### 3.3 Tier 3: Cross-Feature Combinations (21 Test Cases)

Tier 3 exercises pairwise subsystem interactions across the three computing pillars (OS, Web, AI) and the full sovereign triad:

| # | Test File Name | Primary Subsystems | Description & Interaction Verified |
|---|---|---|---|
| 1 | `test_tier3_os_web_vfs_markup_loader.maya` | OS (F06) + Web (F09) | VFS RamFS inode loads markup document directly into Markup Parser without intermediate files. |
| 2 | `test_tier3_os_web_ipc_framebuffer_stream.maya` | OS (F07) + Web (F11) | Web Canvas2D rasterizes ARGB pixels into OS Shared Memory, consumed by child display process. |
| 3 | `test_tier3_os_web_scheduler_ui_event_loop.maya` | OS (F04) + Web (F10) | Task Scheduler cooperatively dispatches Web Engine UI reflow, event handling, and rendering tasks. |
| 4 | `test_tier3_os_web_mmap_canvas_allocation.maya` | OS (F01/05) + Web (F11) | Canvas2D allocates backing pixel buffer directly via OS `sys_mmap` anonymous virtual memory. |
| 5 | `test_tier3_os_web_dispatcher_terminal_pipe.maya` | OS (F03) + Web (F13) | Terminal TrueColor rasterizer streams ANSI frame buffer through OS Dispatcher pipeline. |
| 6 | `test_tier3_os_web_devfs_font_loader.maya` | OS (F06) + Web (F11) | Web Engine reads bitmap font glyphs from DevFS virtual character device (`/dev/font_mono`). |
| 7 | `test_tier3_os_web_process_isolated_render_worker.maya` | OS (F02) + Web (F12) | OS forks isolated worker process for heavy Flexbox layout; parent composites dirty rects. |
| 8 | `test_tier3_os_ai_mmap_tensor_arena.maya` | OS (F01/05) + AI (F14) | AI Tensor Engine allocates 10M parameter buffer directly via OS `sys_mmap` heap arena. |
| 9 | `test_tier3_os_ai_vfs_safetensors_loader.maya` | OS (F06) + AI (F17) | Transformer LLM reads SafeTensors weight tensors directly from OS Inode VFS. |
| 10 | `test_tier3_os_ai_ipc_swarm_messaging.maya` | OS (F07) + AI (F18) | Multi-Agent Swarm exchanges task messages between Planner and Coder via Unix Domain Sockets. |
| 11 | `test_tier3_os_ai_scheduler_parallel_gemm.maya` | OS (F04) + AI (F14) | OS Task Scheduler dispatches matrix multiplication tile chunks across green coroutines. |
| 12 | `test_tier3_os_ai_dispatcher_model_cli.maya` | OS (F03) + AI (F16) | OS Command Dispatcher executes AI model inference CLI commands without shell invocation. |
| 13 | `test_tier3_os_ai_process_isolated_agent_sandbox.maya` | OS (F02) + AI (F18) | OS Kernel forks sandboxed child process with restricted VFS for AI Coder agent code execution. |
| 14 | `test_tier3_os_ai_shm_gradient_sync.maya` | OS (F07) + AI (F15) | Distributed worker processes compute autograd gradients and synchronize via Shared Memory. |
| 15 | `test_tier3_web_ai_tensor_visualizer_canvas.maya` | Web (F11) + AI (F14) | AI Tensor activation map is rasterized directly as heat-map into Canvas2D ARGB buffer. |
| 16 | `test_tier3_web_ai_swarm_dashboard_flexbox.maya` | Web (F10) + AI (F18) | AI Swarm agent status (Planner, Coder, Critic) is rendered with Web Flexbox Engine. |
| 17 | `test_tier3_web_ai_terminal_attention_matrix.maya` | Web (F13) + AI (F16) | MultiHeadAttention weight matrix rendered into ANSI TrueColor terminal string. |
| 18 | `test_tier3_web_ai_canvas_bounding_box_detection.maya` | Web (F11) + AI (F14) | AI Vision tensor bounding boxes drawn onto Canvas2D pixel buffer with alpha highlights. |
| 19 | `test_tier3_web_ai_ui_prompt_llm_stream.maya` | Web (F09/10) + AI (F17) | UI text input events stream tokens incrementally generated by LLM Transformer engine. |
| 20 | `test_tier3_web_ai_dirty_rect_token_stream.maya` | Web (F12) + AI (F17) | LLM token stream updates only specific dirty rect region in UI canvas, minimizing repaint. |
| 21 | `test_tier3_os_web_ai_triad_autonomous_node.maya` | OS + Web + AI | Sovereign Triad: OS boots, AI Swarm generates UI markup, Web renders to terminal. |

---

### 3.4 Tier 4: Real-World Application Scenarios (11 Full Scenarios)

Tier 4 validates complete end-to-end applications demonstrating the sovereignty, integration, and performance of the entire Maya Universe:

1. **`test_app_sovereign_desktop_environment.maya`**:
   - Complete OS microkernel + VFS + Canvas2D window manager + dirty rect compositing rendering a multi-window desktop interface with movable widgets and status bar.
2. **`test_app_autonomous_software_engineer_agent.maya`**:
   - Autonomous AI Swarm (Planner + Coder + Critic + Synthesizer) receives a specification, writes pure Maya code, executes `bin/mayac_v2`, and verifies tests.
3. **`test_app_terminal_browser_headless_renderer.maya`**:
   - Headless web browser pipeline: loads markup document from VFS, parses AST, solves Flexbox layout, renders 80x25 ANSI TrueColor string, and navigates links.
4. **`test_app_baremetal_kernel_boot_sequence.maya`**:
   - Bare-metal simulation: boots Multiboot2 header, configures 64-bit IDT/GDT, initializes 4-level MMU paging, prints OS banner to VGA buffer (0xB8000), and starts task scheduler.
5. **`test_app_end_to_end_transformer_inference_server.maya`**:
   - Sovereign LLM server: loads SafeTensors weights from VFS, accepts token generation requests over IPC socket, executes FlashAttention with KV-cache, and returns sampled completions.
6. **`test_app_self_hosting_compiler_build_pipeline.maya`**:
   - Pure Maya compiler compiles its own AST parser, lexer, and emitter into a standalone binary, then runs a verification test without intermediate `.c` or GCC.
7. **`test_app_multi_agent_adversarial_code_review.maya`**:
   - Coder agent writes an algorithm; Critic agent injects edge-case fuzzing inputs; Test Runner executes in an isolated process; Synthesizer resolves detected defects.
8. **`test_app_distributed_actor_kv_database.maya`**:
   - In-memory key-value database running over OS IPC sockets and VFS RamFS with Raft consensus and transaction write-ahead logging.
9. **`test_app_rich_document_editor_canvas.maya`**:
   - Interactive document editor: handles text entry, reflows Flexbox paragraph blocks, renders formatting styles, and tracks dirty damage rects.
10. **`test_app_neural_network_training_pipeline.maya`**:
    - Full training loop: synthetic data generator, forward pass (Linear+LayerNorm), CrossEntropyLoss computation, autograd backward pass, and AdamW weight update converging to <0.01 loss.
11. **`test_app_zero_dependency_sovereign_os_app.maya`**:
    - Complete freestanding application binary: uses raw syscalls (zero libc), manages heap via free-list, renders UI via terminal raster, and executes AI inference locally.

---

## 4. Test Suite Directory Structure & Layout

The directory layout under `tests/e2e/` organizes tests hierarchically by Tier and Domain:

```
tests/e2e/
├── tier1_features/
│   ├── os/
│   │   ├── test_f01_syscall_read_write.maya
│   │   ├── test_f01_syscall_mmap_munmap.maya
│   │   ├── test_f01_syscall_getpid_getppid.maya
│   │   ├── test_f01_syscall_clock_nanosleep.maya
│   │   ├── test_f01_syscall_uname_sysinfo.maya
│   │   ├── test_f02_process_fork_wait.maya
│   │   ├── test_f02_process_execve.maya
│   │   ├── test_f02_process_wait4_rusage.maya
│   │   ├── test_f02_process_kill_signal.maya
│   │   ├── test_f02_process_exit_codes.maya
│   │   ├── test_f03_dispatcher_tokenize.maya
│   │   ├── test_f03_dispatcher_path_lookup.maya
│   │   ├── test_f03_dispatcher_pipe_redirection.maya
│   │   ├── test_f03_dispatcher_file_redirection.maya
│   │   ├── test_f03_dispatcher_no_shell_exec.maya
│   │   ├── test_f04_scheduler_tcb_init.maya
│   │   ├── test_f04_scheduler_round_robin.maya
│   │   ├── test_f04_scheduler_mlfq_priority.maya
│   │   ├── test_f04_scheduler_task_yield.maya
│   │   ├── test_f04_scheduler_task_cancellation.maya
│   │   ├── test_f05_alloc_basic_malloc_free.maya
│   │   ├── test_f05_alloc_segregated_freelist.maya
│   │   ├── test_f05_alloc_block_split.maya
│   │   ├── test_f05_alloc_block_coalesce.maya
│   │   ├── test_f05_alloc_mmap_expansion.maya
│   │   ├── test_f06_vfs_ramfs_create_write_read.maya
│   │   ├── test_f06_vfs_directory_hierarchy.maya
│   │   ├── test_f06_vfs_dev_null.maya
│   │   ├── test_f06_vfs_dev_zero.maya
│   │   ├── test_f06_vfs_dev_random.maya
│   │   ├── test_f07_ipc_named_pipe_fifo.maya
│   │   ├── test_f07_ipc_shared_memory.maya
│   │   ├── test_f07_ipc_unix_domain_socket.maya
│   │   ├── test_f07_ipc_message_queue.maya
│   │   ├── test_f07_ipc_semaphore_sync.maya
│   │   ├── test_f08_boot_multiboot2_header.maya
│   │   ├── test_f08_boot_gdt_descriptors.maya
│   │   ├── test_f08_boot_paging_pml4.maya
│   │   ├── test_f08_driver_vga_text_buffer.maya
│   │   └── test_f08_driver_uart_serial.maya
│   ├── web/
│   │   ├── test_f09_markup_tag_tokenization.maya
│   │   ├── test_f09_markup_attribute_parsing.maya
│   │   ├── test_f09_markup_tree_hierarchy.maya
│   │   ├── test_f09_markup_style_rule_matching.maya
│   │   ├── test_f09_markup_text_node_extraction.maya
│   │   ├── test_f10_flex_row_direction.maya
│   │   ├── test_f10_flex_col_direction.maya
│   │   ├── test_f10_flex_grow_shrink.maya
│   │   ├── test_f10_flex_justify_align.maya
│   │   ├── test_f10_flex_margin_padding_gap.maya
│   │   ├── test_f11_canvas_clear_rect.maya
│   │   ├── test_f11_canvas_draw_line_shape.maya
│   │   ├── test_f11_canvas_text_rendering.maya
│   │   ├── test_f11_canvas_alpha_blending.maya
│   │   ├── test_f11_canvas_clip_stack.maya
│   │   ├── test_f12_damage_rect_union.maya
│   │   ├── test_f12_damage_incremental_repaint.maya
│   │   ├── test_f12_damage_hidpi_scaling.maya
│   │   ├── test_f12_damage_clipping_bounds.maya
│   │   ├── test_f12_damage_buffer_swap.maya
│   │   ├── test_f13_ansi_color_escape_codes.maya
│   │   ├── test_f13_ansi_halfblock_compression.maya
│   │   ├── test_f13_ansi_cursor_positioning.maya
│   │   ├── test_f13_ansi_clear_screen.maya
│   │   └── test_f13_ansi_frame_serialization.maya
│   ├── ai/
│   │   ├── test_f14_tensor_creation_strides.maya
│   │   ├── test_f14_tensor_gemm_matmul.maya
│   │   ├── test_f14_tensor_broadcasting.maya
│   │   ├── test_f14_tensor_transcendental_math.maya
│   │   ├── test_f14_tensor_activations.maya
│   │   ├── test_f15_autograd_scalar_dag.maya
│   │   ├── test_f15_autograd_tensor_add_mul.maya
│   │   ├── test_f15_autograd_matmul_backward.maya
│   │   ├── test_f15_autograd_relu_grad.maya
│   │   ├── test_f15_autograd_graph_reset.maya
│   │   ├── test_f16_nn_linear_layer.maya
│   │   ├── test_f16_nn_layer_norm.maya
│   │   ├── test_f16_nn_multihead_attention.maya
│   │   ├── test_f16_nn_loss_functions.maya
│   │   ├── test_f16_nn_optimizer_step.maya
│   │   ├── test_f17_transformer_block.maya
│   │   ├── test_f17_transformer_kv_cache.maya
│   │   ├── test_f17_transformer_safetensors_load.maya
│   │   ├── test_f17_transformer_token_sampling.maya
│   │   ├── test_f17_transformer_autoregressive_gen.maya
│   │   ├── test_f18_swarm_agent_init.maya
│   │   ├── test_f18_swarm_state_machine.maya
│   │   ├── test_f18_swarm_mailbox_dispatch.maya
│   │   ├── test_f18_swarm_peer_consensus.maya
│   │   ├── test_f18_swarm_cluster_lifecycle.maya
│   │   ├── test_f19_router_capability_match.maya
│   │   ├── test_f19_router_load_balancing.maya
│   │   ├── test_f19_router_task_retry.maya
│   │   ├── test_f19_router_priority_queue.maya
│   │   └── test_f19_router_dependency_graph.maya
│   ├── infra/
│   │   ├── test_f20_test_assert_primitives.maya
│   │   ├── test_f20_test_process_isolation.maya
│   │   ├── test_f20_test_crash_recovery.maya
│   │   ├── test_f20_test_timing_measurement.maya
│   │   └── test_f20_test_report_serialization.maya
│   └── purity/
│       ├── test_f21_purity_no_c_cpp_files.maya
│       ├── test_f21_purity_no_python_files.maya
│       ├── test_f21_purity_no_shell_scripts.maya
│       ├── test_f21_purity_freestanding_elf.maya
│       └── test_f21_purity_pure_maya_compiler.maya
├── tier2_boundaries/
│   ├── os/ (25 test files: test_f01_boundary_* .. test_f08_boundary_*)
│   ├── web/ (25 test files: test_f09_boundary_* .. test_f13_boundary_*)
│   ├── ai/ (30 test files: test_f14_boundary_* .. test_f19_boundary_*)
│   ├── infra/ (5 test files: test_f20_boundary_*)
│   └── purity/ (5 test files: test_f21_boundary_*)
├── tier3_combinations/
│   ├── test_tier3_os_web_vfs_markup_loader.maya
│   ├── test_tier3_os_web_ipc_framebuffer_stream.maya
│   ├── test_tier3_os_web_scheduler_ui_event_loop.maya
│   ├── test_tier3_os_web_mmap_canvas_allocation.maya
│   ├── test_tier3_os_web_dispatcher_terminal_pipe.maya
│   ├── test_tier3_os_web_devfs_font_loader.maya
│   ├── test_tier3_os_web_process_isolated_render_worker.maya
│   ├── test_tier3_os_ai_mmap_tensor_arena.maya
│   ├── test_tier3_os_ai_vfs_safetensors_loader.maya
│   ├── test_tier3_os_ai_ipc_swarm_messaging.maya
│   ├── test_tier3_os_ai_scheduler_parallel_gemm.maya
│   ├── test_tier3_os_ai_dispatcher_model_cli.maya
│   ├── test_tier3_os_ai_process_isolated_agent_sandbox.maya
│   ├── test_tier3_os_ai_shm_gradient_sync.maya
│   ├── test_tier3_web_ai_tensor_visualizer_canvas.maya
│   ├── test_tier3_web_ai_swarm_dashboard_flexbox.maya
│   ├── test_tier3_web_ai_terminal_attention_matrix.maya
│   ├── test_tier3_web_ai_canvas_bounding_box_detection.maya
│   ├── test_tier3_web_ai_ui_prompt_llm_stream.maya
│   ├── test_tier3_web_ai_dirty_rect_token_stream.maya
│   └── test_tier3_os_web_ai_triad_autonomous_node.maya
├── tier4_applications/
│   ├── test_app_sovereign_desktop_environment.maya
│   ├── test_app_autonomous_software_engineer_agent.maya
│   ├── test_app_terminal_browser_headless_renderer.maya
│   ├── test_app_baremetal_kernel_boot_sequence.maya
│   ├── test_app_end_to_end_transformer_inference_server.maya
│   ├── test_app_self_hosting_compiler_build_pipeline.maya
│   ├── test_app_multi_agent_adversarial_code_review.maya
│   ├── test_app_distributed_actor_kv_database.maya
│   ├── test_app_rich_document_editor_canvas.maya
│   ├── test_app_neural_network_training_pipeline.maya
│   └── test_app_zero_dependency_sovereign_os_app.maya
├── test_e2e_master.maya           # Master Test Suite Runner
├── run_tier1.maya                 # Dedicated Tier 1 Runner
├── run_tier2.maya                 # Dedicated Tier 2 Runner
├── run_tier3.maya                 # Dedicated Tier 3 Runner
└── run_tier4.maya                 # Dedicated Tier 4 Runner
```

---

## 5. Sovereign Test Engine Architecture (`universe/tools/maya_test.maya`)

The testing engine is self-hosted and implements full process isolation and reporting:

### 5.1 Process Isolation via Linux Syscalls
Each individual test case executes inside a child process spawned via `sys_fork(57)`. The master runner waits via `sys_wait4(61)`. If the child terminates normally with exit code 0, the test is marked `PASS`. If the child exits with non-zero or crashes due to a signal (e.g. SIGSEGV, SIGFPE), the parent records `FAIL`, captures the diagnostic failure, and continues to the next test without aborting the suite.

```maya
@struct ProcessStatus
  val: 0
@end

@fn execute_isolated_test(test_path)
  pid = syscall(57, 0, 0, 0, 0, 0, 0) @! sys_fork
  @if pid == 0
    @! Child process
    syscall(59, "./bin/mayac_v2", test_path, 0, 0, 0, 0) @! sys_execve
    syscall(60, 1, 0, 0, 0, 0, 0) @! sys_exit on exec failure
  @end

  @if pid > 0
    @! Parent process
    ps = ProcessStatus { val: 0 }
    syscall(61, pid, ps, 0, 0, 0, 0) @! sys_wait4
    status = ps.val
    @if (status % 256) == 0
      exit_code = (status / 256) % 256
      @if exit_code == 0
        return 0 @! PASS
      @else
        return 1 @! FAIL
      @end
    @else
      return 2 @! CRASH (Signal termination)
    @end
  @end
  return 3 @! FORK_ERROR
@end
```

### 5.2 Assertion Macro Library
```maya
@fn assert_true(condition, msg)
  @if condition != 1
    error.panic("Assertion Failed (assert_true): " + msg)
  @end
@end

@fn assert_eq(actual, expected, msg)
  @if actual != expected
    error.panic("Assertion Failed (assert_eq): " + msg + " | Expected: " + expected + ", Got: " + actual)
  @end
@end

@fn assert_str_eq(actual, expected, msg)
  @if actual != expected
    error.panic("Assertion Failed (assert_str_eq): " + msg + " | Expected: \"" + expected + "\", Got: \"" + actual + "\"")
  @end
@end

@fn assert_near(actual, expected, tolerance, msg)
  diff = actual - expected
  @if diff < 0
    diff = 0 - diff
  @end
  @if diff > tolerance
    error.panic("Assertion Failed (assert_near): " + msg + " | Diff: " + diff + " > Tol: " + tolerance)
  @end
@end
```

### 5.3 Automated Report Generation
The engine formats results into standard:
1. **JUnit XML (`junit.xml`)**: Compatible with CI/CD visualization engines.
2. **JSON Summary (`test_results.json`)**: Machine-readable breakdown with pass/fail counts, durations, and tier distributions.

---

## 6. Test Runners & Execution Protocols

### 6.1 Master Suite Execution
To compile and execute the complete master suite across all 4 tiers (242 tests):
```bash
# 1. Compile the master runner
./bin/mayac_v2 tests/e2e/test_e2e_master.maya -o bin/test_e2e_master

# 2. Execute master suite
./bin/test_e2e_master
```

### 6.2 Modular Tier Execution
Each tier can be compiled and run individually:
```bash
# Run Tier 1: Feature Coverage (105 tests)
./bin/mayac_v2 tests/e2e/run_tier1.maya -o bin/run_tier1 && ./bin/run_tier1

# Run Tier 2: Boundary Cases (105 tests)
./bin/mayac_v2 tests/e2e/run_tier2.maya -o bin/run_tier2 && ./bin/run_tier2

# Run Tier 3: Cross-Feature Combinations (21 tests)
./bin/mayac_v2 tests/e2e/run_tier3.maya -o bin/run_tier3 && ./bin/run_tier3

# Run Tier 4: Real-World Scenarios (11 tests)
./bin/mayac_v2 tests/e2e/run_tier4.maya -o bin/run_tier4 && ./bin/run_tier4
```

### 6.3 Single-Test Compilation & Execution
Any individual test file is fully self-contained:
```bash
./bin/mayac_v2 tests/e2e/tier1_features/os/test_f01_syscall_read_write.maya -o /tmp/test_f01 && /tmp/test_f01
```

---

## 7. Zero-Trust Verification & Acceptance Gates

To certify readiness for final release (`TEST_READY.md`), all 5 acceptance gates must be satisfied:

1. **Compilation Gate**: 100% of the 242 test files compile cleanly via `bin/mayac_v2` with zero errors.
2. **Execution Gate**: 100% of the 242 tests execute and exit with code 0 (`Status: UNIVERSAL HARMONY`).
3. **Purity Gate**: Forensic scan confirms 0 foreign source/script files (`.c`, `.cpp`, `.py`, `.sh`, `.h`) across the workspace.
4. **Freestanding Binary Gate**: `ldd` on compiled test binaries confirms 0 dynamic library dependencies (`not a dynamic executable` / statically freestanding).
5. **Syscall Verification Gate**: `strace` confirms direct invocation of raw Linux x86-64 syscalls (`sys_write`, `sys_mmap`, `sys_fork`, `sys_wait4`) without libc wrappers.
