// ==============================================================================
// 👑 LIPI SOVEREIGN HYPERVISOR SUITE: tests/test_hypervisor_kvm.lp
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Hardware Virtualization & VCPU Test
// ==============================================================================

import "universe/hypervisor/kvm"

@fn main()
    println("==================================================================")
    println("👑 Testing Lipi Sovereign Linux KVM Virtualization Engine")
    println("==================================================================")

    // ── Test 1: Virtual Machine Creation & RAM Allocation ─────────────────────
    println("[1/5] Testing KVM Virtual Machine Construction...")
    vm = kvm_create_vm(4096)
    if vm.guest_ram_size != 4096
        println("❌ VM guest RAM size mismatch!")
        return 1
    end
    if vm.is_running != 1
        println("❌ VM should be in running state upon creation!")
        return 1
    end
    println("  ✔ VM created with 4096 bytes RAM (Hardware/Fallback Mode: " + vm.is_hardware + ")")

    // ── Test 2: Machine Code Loading into Guest RAM ───────────────────────────
    println("[2/5] Testing Guest Machine Code Loading...")
    // Payload:
    //   MOV EAX, 100    (0xB8, 100, 0, 0, 0)
    //   MOV EBX, 250    (0xBB, 250, 0, 0, 0)
    //   ADD EAX, EBX    (0x01, 0xD8)  -> EAX becomes 350
    //   OUT 0x3F8, EAX  (0xE7, 0x3F8) -> Intercept I/O serial write
    //   HLT             (0xF4)
    code = [184, 100, 0, 0, 0, 187, 250, 0, 0, 0, 1, 216, 231, 248, 244]
    vm = kvm_load_guest_code(vm, code, 0)
    if vm.regs.rip != 0
        println("❌ VM RIP not initialized to entrypoint!")
        return 1
    end
    println("  ✔ 15 bytes of guest machine code loaded at address 0x0000")

    // ── Test 3: VCPU Step Execution & Arithmetic Verification ────────────────
    println("[3/5] Testing VCPU Arithmetic Execution (ADD EAX, EBX)...")
    // Step 1: MOV EAX, 100
    vm = kvm_step_vcpu(vm)
    if vm.regs.rax != 100
        println("❌ MOV EAX failed, RAX=" + vm.regs.rax)
        return 1
    end
    // Step 2: MOV EBX, 250
    vm = kvm_step_vcpu(vm)
    if vm.regs.rbx != 250
        println("❌ MOV EBX failed, RBX=" + vm.regs.rbx)
        return 1
    end
    // Step 3: ADD EAX, EBX -> 350
    vm = kvm_step_vcpu(vm)
    if vm.regs.rax != 350
        println("❌ ADD EAX, EBX failed, RAX=" + vm.regs.rax)
        return 1
    end
    println("  ✔ Arithmetic verified: EAX=" + vm.regs.rax + " (100 + 250 = 350)")

    // ── Test 4: Hypervisor I/O Interception Exit (KVM_EXIT_IO) ─────────────────
    println("[4/5] Testing Hypervisor I/O Interception Exit (KVM_EXIT_IO)...")
    // Step 4: OUT 0xF8, EAX -> Exit reason 2
    vm = kvm_step_vcpu(vm)
    if vm.last_exit.exit_reason != 2
        println("❌ Expected KVM_EXIT_IO (2), got " + vm.last_exit.exit_reason)
        return 1
    end
    if vm.last_exit.io_port != 248 || vm.last_exit.io_data != 350
        println("❌ I/O port or data mismatch! Port=" + vm.last_exit.io_port + " Data=" + vm.last_exit.io_data)
        return 1
    end
    println("  ✔ Intercepted OUT instruction: Port=0x" + vm.last_exit.io_port + ", Data=" + vm.last_exit.io_data)

    // ── Test 5: VCPU Halt Exit (KVM_EXIT_HLT) ──────────────────────────────────
    println("[5/5] Testing VCPU Clean Halt Exit (KVM_EXIT_HLT)...")
    // Step 5: HLT -> Exit reason 5
    vm = kvm_step_vcpu(vm)
    if vm.last_exit.exit_reason != 5 || vm.is_running != 0
        println("❌ Expected clean KVM_EXIT_HLT (5), got " + vm.last_exit.exit_reason)
        return 1
    end
    println("  ✔ Clean VCPU HLT intercepted; VM execution gracefully terminated")

    println("==================================================================")
    println("PASS: Lipi Sovereign Hypervisor & Virtualization Verified 100%!")
    println("==================================================================")
    return 0
@end
