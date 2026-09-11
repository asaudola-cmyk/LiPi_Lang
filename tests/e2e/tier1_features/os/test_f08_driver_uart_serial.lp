@! ============================================================================
@! MAYA E2E TIER 1 — F08.5: UART 16550 Serial Driver (COM1 0x3F8)
@! File: tests/e2e/tier1_features/os/test_f08_driver_uart_serial.maya
@! ============================================================================

import "universe/os/drivers/serial"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F08.5: UART Serial COM1")

  port = serial_com1_init()
  assert_eq(port.base_port, 1016, "Base port is 1016 (0x3F8)")
  assert_eq(port.baud_rate, 115200, "Baud rate is 115200")
  assert_eq(port.divisor, 1, "Divisor is 1")

  port = serial_write_str(port, "OK")
  assert_eq(port.tx_log.len(), 2, "2 bytes transmitted")

  println("✓ PASS: F08.5 UART Serial COM1")
  return 0
@end
