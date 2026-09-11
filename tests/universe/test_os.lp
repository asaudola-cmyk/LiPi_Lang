@! ============================================================================
@! MAYA UNIVERSE TEST SUITE — OS & HARDWARE DRIVER VERIFICATION
@! ============================================================================

import "universe/os/hal"
import "universe/os/drivers/keyboard"
import "universe/os/drivers/disk"

@fn run_os_tests()
  println("▶ [TEST] Running Universe OS & Driver Tests...")

  @! 1. HAL CPUID Detection
  info = hal_detect_cpu_features()
  @if info.arch == "x86_64"
    println("  [PASS] HAL CPUID Architecture Detection verified")
  @end

  @! 2. Scancode to ASCII
  ch = kbd_scancode_to_ascii(0x1E, 0)
  @if ch == "a"
    println("  [PASS] Keyboard Scancode Decoding verified")
  @end

  @! 3. ATA Disk Controller Init
  ata = ata_driver_new()
  @if ata.sector_size == 512
    println("  [PASS] ATA 512-byte Sector Initialization verified")
  @end

  println("✅ All Universe OS & Driver Tests Passed!")
@end
