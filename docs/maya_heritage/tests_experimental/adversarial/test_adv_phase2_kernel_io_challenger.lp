@! ============================================================================
@! MAYA ADVERSARIAL CHALLENGER TEST SUITE: PHASE 2 KERNEL IO & SYSCALLS
@! File: tests/adversarial/test_adv_phase2_kernel_io_challenger.maya
@! Target: Linux Syscall 16 (sys_ioctl), KVM ioctl wiring & software fallback,
@!         io_uring ring memory mapping & SQPOLL zero-syscall engine
@! ============================================================================

import "universe/core/collections"
import "universe/os/syscalls"
import "universe/hypervisor/kvm"
import "universe/hypervisor/kvm_advanced"
import "universe/io/uring"
import "universe/io/uring_sqpoll"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🔱 ADVERSARIAL CHALLENGER: PHASE 2 KERNEL IO & SYSCALLS 🔱")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! --------------------------------------------------------------------------
  @! SECTION 1: Syscall 16 (sys_ioctl) Direct Invocation & Error Translation
  @! --------------------------------------------------------------------------
  println("▶ [1/7] Stress-testing Linux Syscall 16 (sys_ioctl) & Errno Handling...")
  
  @! 1.1 Invalid file descriptors -> EBADF (errno 9, negative -9)
  total_tests = total_tests + 1
  res_bad_fd1 = sys_ioctl(0 - 1, 0, 0)
  ok1 = assert_eq_int(res_bad_fd1, 0 - 9, "sys_ioctl(-1, 0, 0) returns -EBADF (-9)")
  ok2 = assert_true(is_error(res_bad_fd1), "is_error(-9) returns true")
  ok3 = assert_eq_int(get_errno(res_bad_fd1), 9, "get_errno(-9) returns 9")
  ok4 = assert_true(errno_name(9) == "EBADF", "errno_name(9) is EBADF")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Syscall 16 on invalid negative fd returns -EBADF cleanly")
  @end

  total_tests = total_tests + 1
  res_bad_fd2 = sys_ioctl(999999, 44544, 0)
  ok1 = assert_eq_int(res_bad_fd2, 0 - 9, "sys_ioctl(999999, 44544, 0) returns -EBADF (-9)")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Syscall 16 on high out-of-range fd returns -EBADF cleanly")
  @end

  @! 1.2 Invalid ioctl command on valid fd (stdout fd 1) -> ENOTTY (25) or EINVAL (22)
  total_tests = total_tests + 1
  res_bad_cmd = sys_ioctl(1, 3735928559, 0) @! 0xDEADBEEF
  ok1 = assert_true(res_bad_cmd < 0, "sys_ioctl(stdout, 0xDEADBEEF) returns negative error")
  err_cmd = get_errno(res_bad_cmd)
  ok2 = assert_true(err_cmd == 25 || err_cmd == 22, "Error is ENOTTY (25) or EINVAL (22)")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Syscall 16 with invalid command on stdout returns expected error (" + err_cmd.to_str() + ")")
  @end

  @! 1.3 Verify KVM and io_uring Constants
  total_tests = total_tests + 1
  ok1 = assert_eq_int(KVM_GET_API_VERSION(), 44544, "KVM_GET_API_VERSION == 44544 (0xAE00)")
  ok2 = assert_eq_int(KVM_CREATE_VM(), 44545, "KVM_CREATE_VM == 44545 (0xAE01)")
  ok3 = assert_eq_int(KVM_GET_VCPU_MMAP_SIZE(), 44548, "KVM_GET_VCPU_MMAP_SIZE == 44548 (0xAE04)")
  ok4 = assert_eq_int(KVM_SET_USER_MEMORY_REGION(), 1075883590, "KVM_SET_USER_MEMORY_REGION == 1075883590 (0x4020AE46)")
  ok5 = assert_eq_int(KVM_CREATE_VCPU(), 44609, "KVM_CREATE_VCPU == 44609 (0xAE41)")
  ok6 = assert_eq_int(KVM_RUN(), 44672, "KVM_RUN == 44672 (0xAE80)")
  ok7 = assert_eq_int(IORING_OFF_SQ_RING(), 0, "IORING_OFF_SQ_RING == 0")
  ok8 = assert_eq_int(IORING_OFF_CQ_RING(), 134217728, "IORING_OFF_CQ_RING == 134217728 (0x8000000)")
  ok9 = assert_eq_int(IORING_OFF_SQES(), 268435456, "IORING_OFF_SQES == 268435456 (0x10000000)")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] KVM and io_uring syscall & ioctl opcode constants verified")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 2: KVM Hypervisor Engine Initialization & Boundary Conditions
  @! --------------------------------------------------------------------------
  println("▶ [2/7] Stress-testing KVM Hypervisor VM Creation & Hardware/Software Fallback...")
  
  @! 2.1 Boundary RAM sizing: 0 bytes, 16 bytes, 64KB, 1MB
  total_tests = total_tests + 1
  vm_0 = kvm_create_vm(0)
  ok1 = assert_eq_int(vm_0.guest_ram_size, 0, "0-byte VM creation succeeds")
  ok2 = assert_eq_int(vm_0.is_running, 1, "0-byte VM state is RUNNING")

  vm_small = kvm_create_vm(16)
  ok3 = assert_eq_int(vm_small.guest_ram_size, 16, "16-byte VM creation succeeds")
  ok4 = assert_eq_int(vm_small.regs.rsp, 0, "16-byte VM RSP initialized to 16 - 16 = 0")

  vm_64k = kvm_create_vm(65536)
  ok5 = assert_eq_int(vm_64k.guest_ram_size, 65536, "64KB VM creation succeeds")
  ok6 = assert_eq_int(vm_64k.regs.rsp, 65520, "64KB VM RSP initialized to 65536 - 16 = 65520")
  ok7 = assert_eq_int(vm_64k.regs.rflags, 2, "rflags initialized with bit 1 set (2)")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] KVM VM memory boundary initialization verified")
  @end

  @! 2.2 Hardware probe vs Software Fallback verification
  total_tests = total_tests + 1
  @if vm_64k.is_hardware == 1
    println("  [INFO] Host environment supports hardware KVM acceleration")
    ok1 = assert_true(vm_64k.kvm_fd >= 0, "Hardware kvm_fd is valid")
    ok2 = assert_true(vm_64k.vm_fd >= 0, "Hardware vm_fd is valid")
    ok3 = assert_true(vm_64k.vcpu_fd >= 0, "Hardware vcpu_fd is valid")
  @else
    println("  [INFO] Host environment engaged automated software interpreter fallback")
    ok1 = assert_eq_int(vm_64k.is_hardware, 0, "Software fallback is_hardware == 0")
    ok2 = assert_eq_int(vm_64k.kvm_fd, 3, "Software fallback mock kvm_fd == 3")
    ok3 = assert_eq_int(vm_64k.vm_fd, 4, "Software fallback mock vm_fd == 4")
  @end
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] KVM hardware virtualization / software fallback validated")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 3: KVM Software Interpreter Instruction Stepper & Adversarial Opcodes
  @! --------------------------------------------------------------------------
  println("▶ [3/7] Stress-testing KVM vCPU Instruction Stepping & Interceptions...")

  @! 3.1 32-bit Little-Endian Immediate Decoding for MOV EAX (0xB8)
  total_tests = total_tests + 1
  vm_stepper = kvm_create_vm(4096)
  
  @! Code sequence:
  @! 1) MOV EAX, 0x12345678 (305419896): [184, 0x78, 0x56, 0x34, 0x12]
  @! 2) MOV EAX, 0x7FFFFFFF (2147483647): [184, 0xFF, 0xFF, 0xFF, 0x7F]
  @! 3) MOV EAX, 0: [184, 0, 0, 0, 0]
  @! 4) OUT 0x40, EAX: [231, 64]
  @! 5) HLT: [244]
  code_imm = [
    184, 120, 86, 52, 18,
    184, 255, 255, 255, 127,
    184, 0, 0, 0, 0,
    231, 64,
    244
  ]
  vm_stepper = kvm_load_guest_code(vm_stepper, code_imm, 0)
  
  @! Step 1: MOV EAX, 0x12345678
  vm_stepper = kvm_step_vcpu(vm_stepper)
  ok1 = assert_eq_int(vm_stepper.regs.rax, 305419896, "MOV EAX decoded 0x12345678 (305419896)")
  ok2 = assert_eq_int(vm_stepper.regs.rip, 5, "RIP advanced to 5")

  @! Step 2: MOV EAX, 0x7FFFFFFF (i32 max)
  vm_stepper = kvm_step_vcpu(vm_stepper)
  ok3 = assert_eq_int(vm_stepper.regs.rax, 2147483647, "MOV EAX decoded 0x7FFFFFFF (2147483647)")
  ok4 = assert_eq_int(vm_stepper.regs.rip, 10, "RIP advanced to 10")

  @! Step 3: MOV EAX, 0
  vm_stepper = kvm_step_vcpu(vm_stepper)
  ok5 = assert_eq_int(vm_stepper.regs.rax, 0, "MOV EAX decoded 0")
  ok6 = assert_eq_int(vm_stepper.regs.rip, 15, "RIP advanced to 15")

  @! Step 4: OUT 0x40, EAX -> Exit Reason 2
  vm_stepper = kvm_step_vcpu(vm_stepper)
  ok7 = assert_eq_int(vm_stepper.last_exit.exit_reason, 2, "OUT port triggered KVM_EXIT_IO (2)")
  ok8 = assert_eq_int(vm_stepper.last_exit.io_port, 64, "I/O port is 64 (0x40)")
  ok9 = assert_eq_int(vm_stepper.last_exit.io_data, 0, "I/O data sent EAX (0)")

  @! Step 5: HLT -> Exit Reason 5
  vm_stepper = kvm_step_vcpu(vm_stepper)
  ok10 = assert_eq_int(vm_stepper.last_exit.exit_reason, 5, "HLT triggered KVM_EXIT_HLT (5)")
  ok11 = assert_eq_int(vm_stepper.is_running, 0, "is_running is 0 after HLT")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1 && ok10 == 1 && ok11 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] 32-bit immediate decoding & hypervisor interception verified")
  @end

  @! 3.2 OOB Instruction Pointer (RIP >= RAM size) -> Shutdown Exit 8
  total_tests = total_tests + 1
  vm_oob = kvm_create_vm(256)
  vm_oob.regs.rip = 300 @! Beyond 256 bytes
  vm_oob = kvm_step_vcpu(vm_oob)
  ok1 = assert_eq_int(vm_oob.last_exit.exit_reason, 8, "Out of bounds RIP triggers shutdown exit (8)")
  ok2 = assert_eq_int(vm_oob.is_running, 0, "VM execution stopped on OOB RIP")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Out of bounds instruction pointer protection verified")
  @end

  @! 3.3 Execution at high offset within RAM vs outside RAM
  total_tests = total_tests + 1
  @! Subtest A: High offset WITHIN guest RAM size (offset 500 in 4096-byte VM)
  vm_within = kvm_create_vm(4096)
  code_high = [144, 144, 244] @! NOP, NOP, HLT at offset 500
  vm_within = kvm_load_guest_code(vm_within, code_high, 500)
  ok1 = assert_eq_int(vm_within.regs.rip, 500, "RIP points to load address 500")
  vm_within = kvm_run_vcpu(vm_within, 10)
  ok2 = assert_eq_int(vm_within.last_exit.exit_reason, 5, "Code executed from high offset within RAM to HLT (exit_reason 5)")

  @! Subtest B: High offset OUTSIDE initial guest RAM size (offset 500 in 128-byte VM)
  vm_outside = kvm_create_vm(128)
  vm_outside = kvm_load_guest_code(vm_outside, code_high, 500)
  vm_outside = kvm_run_vcpu(vm_outside, 10)
  ok3 = assert_eq_int(vm_outside.last_exit.exit_reason, 8, "Code at offset outside RAM triggers shutdown exit 8")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] KVM guest RAM boundary checks (within vs outside RAM) verified")
  @end

  @! 3.4 Register inspection & mutation (KVMRegs, kvm_get_regs, kvm_set_regs, kvm_get_sregs)
  total_tests = total_tests + 1
  vm_regs = kvm_create_vm(1024)
  custom_regs = {
    rax: 111,
    rbx: 222,
    rcx: 333,
    rdx: 444,
    rsi: 555,
    rdi: 666,
    rsp: 777,
    rbp: 888,
    rip: 999,
    rflags: 514
  }
  vm_regs = kvm_set_regs(vm_regs, custom_regs)
  r_back = kvm_get_regs(vm_regs)
  ok1 = assert_eq_int(r_back.rax, 111, "rax preserved")
  ok2 = assert_eq_int(r_back.rbx, 222, "rbx preserved")
  ok3 = assert_eq_int(r_back.rcx, 333, "rcx preserved")
  ok4 = assert_eq_int(r_back.rdx, 444, "rdx preserved")
  ok5 = assert_eq_int(r_back.rsi, 555, "rsi preserved")
  ok6 = assert_eq_int(r_back.rdi, 666, "rdi preserved")
  ok7 = assert_eq_int(r_back.rsp, 777, "rsp preserved")
  ok8 = assert_eq_int(r_back.rbp, 888, "rbp preserved")
  ok9 = assert_eq_int(r_back.rip, 999, "rip preserved")
  ok10 = assert_eq_int(r_back.rflags, 514, "rflags preserved")
  sreg = kvm_get_sregs(vm_regs)
  ok11 = assert_eq_int(sreg.seg_limit, 65535, "sregs limit == 65535")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1 && ok10 == 1 && ok11 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Full vCPU 64-bit general purpose and segment register state manipulation verified")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 4: AWS Firecracker-Style MicroVM & VirtIO Shared Queues
  @! --------------------------------------------------------------------------
  println("▶ [4/7] Stress-testing Firecracker MicroVM Bootloader & VirtIO Queues...")
  
  total_tests = total_tests + 1
  fvm = firecracker_create_microvm(1024) @! 1024MB (1GB) MicroVM
  ok1 = assert_eq_int(fvm.guest_ram_size, 1073741824, "MicroVM RAM size is 1GB (1073741824 bytes)")
  ok2 = assert_eq_int(fvm.zero_page.hdr_type_of_loader, 255, "Zero-page loader type is 255")
  ok3 = assert_eq_int(fvm.zero_page.hdr_loadflags, 1, "Zero-page loadflags is 1 (LOADED_HIGH)")
  ok4 = assert_eq_int(fvm.zero_page.hdr_code32_start, 1048576, "32/64-bit entry point at 0x100000 (1MB)")
  ok5 = assert_eq_int(fvm.zero_page.hdr_cmd_line_ptr, 131072, "cmdline ptr is 0x20000")
  ok6 = assert_eq_int(fvm.zero_page.e820_entries_count, 2, "E820 table entries count is 2")
  
  e820_low = fvm.zero_page.e820_table[0]
  ok7 = assert_eq_int(e820_low.base_addr, 0, "E820 low RAM base is 0")
  ok8 = assert_eq_int(e820_low.mem_length, 655360, "E820 low RAM length is 640KB")
  ok9 = assert_eq_int(e820_low.entry_type, 1, "E820 low RAM type is E820_RAM (1)")

  e820_high = fvm.zero_page.e820_table[1]
  ok10 = assert_eq_int(e820_high.base_addr, 1048576, "E820 high RAM base is 1MB (1048576)")
  ok11 = assert_eq_int(e820_high.mem_length, 1073741824 - 1048576, "E820 high RAM length exact top")
  
  ok12 = assert_eq_int(fvm.virtio_blk.descriptors.len(), 64, "VirtIO Block has 64 descriptors")
  ok13 = assert_eq_int(fvm.virtio_net.descriptors.len(), 64, "VirtIO Net has 64 descriptors")

  fvm = firecracker_boot_kernel(fvm, "console=ttyS0 root=/dev/vda rw init=/init")
  ok14 = assert_eq_int(fvm.is_booted, 1, "MicroVM booted status is 1")
  ok15 = assert_eq_int(fvm.kernel_entry_rip, 1048576, "vCPU RIP points to kernel entry")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1 && ok10 == 1 && ok11 == 1 && ok12 == 1 && ok13 == 1 && ok14 == 1 && ok15 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Firecracker zero-page, E820 memory map, VirtIO queues and direct boot verified")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 5: Linux io_uring Ring Memory Mapping & SQE/CQE Lifecycle
  @! --------------------------------------------------------------------------
  println("▶ [5/7] Stress-testing Linux io_uring Ring Initialization & SQE/CQE Lifecycle...")

  @! 5.1 Direct io_uring_setup syscall with invalid memory pointer -> EFAULT (-14)
  total_tests = total_tests + 1
  res_setup_null = sys_io_uring_setup(64, 0)
  ok1 = assert_eq_int(res_setup_null, 0 - 14, "sys_io_uring_setup with null params returns -EFAULT (-14)")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] sys_io_uring_setup (Syscall 425) rejects null params with -EFAULT")
  @end

  @! 5.2 Ring buffer power-of-2 masks & queue builder
  total_tests = total_tests + 1
  ring16 = io_uring_init(16)
  ok1 = assert_eq_int(ring16.entries, 16, "Ring entries == 16")
  ok2 = assert_eq_int(ring16.sq_mask, 15, "Ring sq_mask == 15 (entries - 1)")
  ok3 = assert_eq_int(ring16.sqes.len(), 16, "Ring pre-allocated 16 SQEs")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] io_uring ring sizing and power-of-2 mask verified")
  @end

  @! 5.3 SQE preparation & Multi-Batch Submission Stress
  total_tests = total_tests + 1
  ring_batch = io_uring_init(16) @! 16-entry ring
  
  @! Batch 1: Push 3 operations (Read, Write, Accept)
  ring_batch = io_uring_prep_read(ring_batch, 10, 4096, 512, 0, 1000)
  ring_batch = io_uring_prep_write(ring_batch, 11, 8192, 1024, 512, 1001)
  ring_batch = io_uring_prep_accept(ring_batch, 12, 1002)
  ok1 = assert_eq_int(ring_batch.sq_tail, 3, "sq_tail is 3 after 3 preps")
  ok2 = assert_eq_int(ring_batch.sq_head, 0, "sq_head remains 0 before submit")

  @! Batch 1 Submit & Reap
  sub1 = io_uring_submit_and_reap(ring_batch)
  ok3 = assert_eq_int(sub1, 3, "Submitted 3 entries in Batch 1")
  ok4 = assert_eq_int(ring_batch.sq_head, 3, "sq_head advanced to 3")
  ok5 = assert_eq_int(ring_batch.cqes.len(), 3, "3 CQEs in completion ring")

  @! Batch 2: Push 2 more operations without popping yet (testing cumulative CQEs)
  ring_batch = io_uring_prep_read(ring_batch, 10, 12288, 2048, 1536, 1003)
  ring_batch = io_uring_prep_write(ring_batch, 11, 16384, 4096, 3584, 1004)
  sub2 = io_uring_submit_and_reap(ring_batch)
  ok6 = assert_eq_int(sub2, 2, "Submitted 2 entries in Batch 2")
  ok7 = assert_eq_int(ring_batch.sq_head, 5, "sq_head advanced to 5")
  ok8 = assert_eq_int(ring_batch.cqes.len(), 5, "Total 5 CQEs in completion ring")

  @! Pop and verify all 5 CQEs in exact FIFO order
  cqe1 = io_uring_pop_cqe(ring_batch)
  ok9 = assert_eq_int(cqe1.cqe_tag, 1000, "CQE 1 tag is 1000")
  ok10 = assert_eq_int(cqe1.res, 512, "CQE 1 res is 512")

  cqe2 = io_uring_pop_cqe(ring_batch)
  ok11 = assert_eq_int(cqe2.cqe_tag, 1001, "CQE 2 tag is 1001")
  ok12 = assert_eq_int(cqe2.res, 1024, "CQE 2 res is 1024")

  cqe3 = io_uring_pop_cqe(ring_batch)
  ok13 = assert_eq_int(cqe3.cqe_tag, 1002, "CQE 3 tag is 1002 (accept)")
  ok14 = assert_eq_int(cqe3.res, 100, "CQE 3 res is 100 (accept)")

  cqe4 = io_uring_pop_cqe(ring_batch)
  ok15 = assert_eq_int(cqe4.cqe_tag, 1003, "CQE 4 tag is 1003")
  ok16 = assert_eq_int(cqe4.res, 2048, "CQE 4 res is 2048")

  cqe5 = io_uring_pop_cqe(ring_batch)
  ok17 = assert_eq_int(cqe5.cqe_tag, 1004, "CQE 5 tag is 1004")
  ok18 = assert_eq_int(cqe5.res, 4096, "CQE 5 res is 4096")

  ok19 = assert_eq_int(io_uring_pop_cqe(ring_batch), 0, "Popping empty ring returns 0 safely")
  ok20 = assert_eq_int(io_uring_peek_cqe(ring_batch), 0, "Peeking empty ring returns 0 safely")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1 && ok10 == 1 && ok11 == 1 && ok12 == 1 && ok13 == 1 && ok14 == 1 && ok15 == 1 && ok16 == 1 && ok17 == 1 && ok18 == 1 && ok19 == 1 && ok20 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] io_uring multi-batch submission and FIFO CQE drain verified")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 6: io_uring SQPOLL Dedicated Kernel Thread & Zero-Syscall I/O
  @! --------------------------------------------------------------------------
  println("▶ [6/7] Stress-testing io_uring SQPOLL Zero-Syscall Submissions...")

  total_tests = total_tests + 1
  sqp = io_uring_sqpoll_init(32, 2, 5000) @! 32 entries, CPU 2, 5000ms idle
  ok1 = assert_eq_int(sqp.sq_capacity, 32, "SQPOLL capacity is 32")
  ok2 = assert_eq_int(sqp.is_kthread_active, 1, "SQPOLL kthread is active")
  ok3 = assert_eq_int(sqp.sq_thread_cpu, 2, "SQPOLL kthread affinity is CPU 2")

  @! Push 50 SQEs in 5 bursts of 10
  burst = 0
  total_pushed = 0
  @while burst < 5
    j = 0
    @while j < 10
      tag = (burst * 100) + j
      sqp = io_uring_sqpoll_push_sqe(sqp, 22, 5, 65536 + tag, 4096, tag)
      total_pushed = total_pushed + 1
      j = j + 1
    @end
    @! Harvest after each burst
    harvested = io_uring_sqpoll_poll_kthread(sqp)
    burst = burst + 1
  @end

  ok4 = assert_eq_int(sqp.total_zero_syscall_ops, 50, "total_zero_syscall_ops recorded 50 operations")
  ok5 = assert_eq_int(sqp.cq_queue.len(), 50, "50 completion events waiting in CQ queue")

  @! Drain and verify all tags
  drain_ok = 1
  d_idx = 0
  @while d_idx < 50
    cqe = io_uring_sqpoll_pop_cqe(sqp)
    expected_tag = ((d_idx / 10) * 100) + (d_idx % 10)
    @if cqe == 0 || cqe.cqe_tag != expected_tag || cqe.res != 4096
      drain_ok = 0
    @end
    d_idx = d_idx + 1
  @end
  ok6 = assert_eq_int(drain_ok, 1, "All 50 CQEs correctly popped in FIFO order with matching tags")
  ok7 = assert_eq_int(io_uring_sqpoll_pop_cqe(sqp), 0, "Popping empty SQPOLL CQ queue returns 0 safely")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] io_uring SQPOLL burst submissions, kthread polling & tag preservation verified")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 7: Multi-Cycle Memory Stress & Stability Verification
  @! --------------------------------------------------------------------------
  println("▶ [7/7] Multi-Cycle Memory Stress & Stability (100 Cycles)...")

  total_tests = total_tests + 1
  cycle = 0
  cycle_ok = 1
  @while cycle < 100
    @! Cycle A: VM creation and execution
    stress_vm = kvm_create_vm(2048)
    stress_code = [184, 10, 0, 0, 0, 144, 244]
    stress_vm = kvm_load_guest_code(stress_vm, stress_code, 0)
    stress_vm = kvm_run_vcpu(stress_vm, 10)
    @if stress_vm.regs.rax != 10 || stress_vm.last_exit.exit_reason != 5
      cycle_ok = 0
    @end

    @! Cycle B: io_uring init and submit
    stress_ring = io_uring_init(16)
    stress_ring = io_uring_prep_read(stress_ring, 3, 1000, 256, 0, cycle)
    sub = io_uring_submit_and_reap(stress_ring)
    c_cqe = io_uring_pop_cqe(stress_ring)
    @if sub != 1 || c_cqe == 0 || c_cqe.cqe_tag != cycle
      cycle_ok = 0
    @end

    cycle = cycle + 1
  @end

  ok1 = assert_eq_int(cycle_ok, 1, "100 consecutive KVM + io_uring lifecycle cycles completed cleanly")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] 100-cycle KVM + io_uring memory lifecycle stress completed with zero errors")
  @end

  println("=================================================================")
  println("📊 ADVERSARIAL CHALLENGER RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 7 PHASE 2 KERNEL IO ADVERSARIAL CHALLENGES PASSED! 🎉")
    return 0
  @else
    println("❌ SOME ADVERSARIAL CHALLENGES FAILED")
    return 1
  @end
@end
