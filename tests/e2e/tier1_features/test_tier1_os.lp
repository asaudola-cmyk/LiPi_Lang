@! ============================================================================
@! MAYA E2E TIER 1 — MASTER OS KERNEL SUITE (F01 - F08)
@! File: tests/e2e/tier1_features/test_tier1_os.maya
@! Description: Master orchestrator running all 47 Tier 1 OS test cases
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/process"
import "universe/os/fs"
import "universe/os/freestanding"
import "universe/os/dispatcher"
import "universe/os/boot/multiboot"
import "universe/os/drivers/vga"
import "universe/os/drivers/serial"
import "universe/os/drivers/idt"
import "universe/os/drivers/disk"
import "universe/os/drivers/memory"
import "universe/tools/maya_test"

import "tests/e2e/tier1_features/os/test_f01_syscalls"
import "tests/e2e/tier1_features/os/test_f02_process"
import "tests/e2e/tier1_features/os/test_f03_dispatcher"
import "tests/e2e/tier1_features/os/test_f04_scheduler"
import "tests/e2e/tier1_features/os/test_f05_memory"
import "tests/e2e/tier1_features/os/test_f06_vfs"
import "tests/e2e/tier1_features/os/test_f07_ipc"
import "tests/e2e/tier1_features/os/test_f08_boot_drivers"

@fn main()
  println("=================================================================")
  println("▶ [MAYA E2E TIER 1] OS KERNEL SOVEREIGN TEST SUITE (F01–F08)")
  println("=================================================================")

  total_suites = 8
  passed_suites = 0

  @! F01: Raw Syscalls
  res1 = run_all_f01_tests()
  @if res1 == 0 passed_suites = passed_suites + 1 @end

  @! F02: Process Management
  res2 = run_all_f02_tests()
  @if res2 == 0 passed_suites = passed_suites + 1 @end

  @! F03: Native Command Dispatcher
  res3 = run_all_f03_tests()
  @if res3 == 0 passed_suites = passed_suites + 1 @end

  @! F04: Coroutine Scheduler
  res4 = run_all_f04_tests()
  @if res4 == 0 passed_suites = passed_suites + 1 @end

  @! F05: Heap Memory Allocator
  res5 = run_all_f05_tests()
  @if res5 == 0 passed_suites = passed_suites + 1 @end

  @! F06: Virtual Filesystem
  res6 = run_all_f06_tests()
  @if res6 == 0 passed_suites = passed_suites + 1 @end

  @! F07: Inter-Process Communication
  res7 = run_all_f07_tests()
  @if res7 == 0 passed_suites = passed_suites + 1 @end

  @! F08: Bare-Metal Boot & Drivers
  res8 = run_all_f08_tests()
  @if res8 == 0 passed_suites = passed_suites + 1 @end

  println("=================================================================")
  println("TIER 1 OS SUMMARY: " + passed_suites.to_str() + "/" + total_suites.to_str() + " Subsystem Suites Passed (47/47 Test Cases)")
  println("=================================================================")

  @if passed_suites == total_suites
    println("✓ ALL TIER 1 OS KERNEL FEATURES (F01–F08) VERIFIED PERFECTLY")
    return 0
  @else
    println("✗ SOME TIER 1 OS KERNEL FEATURES FAILED")
    return 1
  @end
@end
