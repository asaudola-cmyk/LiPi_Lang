@! ============================================================================
@! LIPI SOVEREIGN OS MICROKERNEL — universe/os/kernel.lp
@! 100% Written in Pure Lipi Language — Complete Zero libc / Zero C Dependencies
@! Master Kernel Entry Point, Subsystem Orchestration, and Event Loop
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/hal"
import "universe/os/memory"
import "universe/os/vfs"
import "universe/os/ipc"
import "universe/os/scheduler"
import "universe/os/boot/gdt"
import "universe/os/boot/paging"
import "universe/os/drivers/vga"
import "universe/os/drivers/serial"
import "universe/os/drivers/idt"
import "universe/os/drivers/ps2"

@! ----------------------------------------------------------------------------
@! 1. Kernel State Structure
@! ----------------------------------------------------------------------------

@fn kernel_init()
  @! 1. Initialize Hardware Abstraction Layer & Interrupts
  hal_cli()
  
  @! 2. Initialize 64-Bit Global Descriptor Table (GDT)
  gdt = gdt_table_new(2097152, 104) @! TSS at 2MB, limit 104
  
  @! 3. Initialize 4-Level MMU Paging (1GB Identity Mapped with 2MB Huge Pages)
  page_tables = paging_create_identity_map_1gb(2097152, 2101248, 2105344)
  
  @! 4. Initialize Hardware Drivers
  vga = vga_text_buffer_new()
  vga = vga_clear(vga, 15, 0)
  vga = vga_print_str(vga, "Maya Sovereign OS Kernel booting...\n")
  
  com1 = serial_com1_init()
  com1 = serial_write_line(com1, "[KERNEL] Boot sequence initiated.")
  
  idt = idt_table_new()
  ps2_kb = ps2_keyboard_new()
  
  @! 5. Initialize Dynamic Segregated Free-List Heap Allocator
  heap = heap_new()
  
  @! 6. Initialize Virtual Filesystem (RamFS & DevFS)
  vfs_root = vfs_init()
  
  @! 7. Initialize IPC Subsystem
  kernel_fifo = ipc_fifo_create("klog", 4096)
  kernel_mutex = ipc_mutex_init()
  
  @! 8. Initialize Multitasking Task Scheduler (MLFQ Mode)
  sched = scheduler_init(1) @! 1 = MLFQ Mode
  
  @! Spawn Kernel Idle Task (Priority 2 / Low)
  idle_tid = scheduler_create_task(sched, "idle", 1048576, 16384, 2)
  
  @! Spawn Init Userland Task (Priority 0 / High)
  init_tid = scheduler_create_task(sched, "init", 2097152, 65536, 0)
  
  @! Enable Hardware Interrupts
  hal_sti()
  
  return {
    state: "RUNNING",
    uptime_ticks: 0,
    gdt: gdt,
    page_tables: page_tables,
    vga: vga,
    serial: com1,
    idt: idt,
    ps2: ps2_kb,
    heap: heap,
    vfs: vfs_root,
    fifo: kernel_fifo,
    mutex: kernel_mutex,
    scheduler: sched,
    idle_task_id: idle_tid,
    init_task_id: init_tid
  }
@end

@! ----------------------------------------------------------------------------
@! 2. Kernel Step & Main Event Loop
@! ----------------------------------------------------------------------------

@fn kernel_step(kernel)
  kernel.uptime_ticks = kernel.uptime_ticks + 1
  
  @! 1. Advance Scheduler Clock & Trigger Time Slice Expiry / Preemption
  scheduler_tick(kernel.scheduler)
  
  @! 2. Schedule Next Ready Task
  cur_tid = kernel.scheduler.current_task_id
  @if cur_tid < 0
    scheduler_schedule_next(kernel.scheduler)
  @end
  
  return kernel.uptime_ticks
@end

@fn kernel_run(kernel, max_steps)
  step = 0
  @while step < max_steps
    kernel_step(kernel)
    step = step + 1
  @end
  return kernel
@end

@fn kernel_status(kernel)
  metrics = scheduler_metrics(kernel.scheduler)
  h_stats = heap_stats(kernel.heap)
  
  return {
    state: kernel.state,
    uptime_ticks: kernel.uptime_ticks,
    total_tasks: metrics.total_tasks,
    running_task: kernel.scheduler.current_task_id,
    context_switches: metrics.context_switches,
    heap_mmap_bytes: h_stats.total_mmap_bytes,
    heap_allocated_bytes: h_stats.allocated_bytes,
    vfs_inodes_count: kernel.vfs.inodes.len(),
    interrupts_enabled: hal_are_interrupts_enabled()
  }
@end

@! ----------------------------------------------------------------------------
@! 3. Kernel Master Entry Point
@! ----------------------------------------------------------------------------

@fn kmain()
  kernel = kernel_init()
  kernel = kernel_run(kernel, 100)
  return kernel_status(kernel)
@end
