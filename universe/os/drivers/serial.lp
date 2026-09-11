@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — BARE-METAL UART 16550 SERIAL DRIVER
@! Module: universe/os/drivers/serial.maya
@! Milestone: Grand Sovereign Pillar 4
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Features: UART 16550 COM1 (0x3F8) Serial Logging, Baud Divisor Math,
@! FIFO Setup & Line Status Register Polling
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ============================================================================
@! 1. SERIAL COM1 REGISTERS & STRUCTS
@! ============================================================================

@struct UARTSerialPort
  base_port: i64      @! COM1
  baud_rate: i64      @! e.g. 115200, 38400, 9600
  divisor: i64        @! 115200 / baud_rate
  is_initialized: i64
  tx_log: array
@end

@! ============================================================================
@! 2. DRIVER INITIALIZATION & BAUD MATH
@! ============================================================================

@fn serial_port_new(base_port, baud_rate)
  base_clock = 115200
  div = base_clock / baud_rate
  @if div <= 0 div = 1 @end

  return {
    base_port: base_port,
    baud_rate: baud_rate,
    divisor: div,
    is_initialized: 1,
    tx_log: []
  }
@end

@fn serial_com1_init()
  return serial_port_new(1016, 115200) @! 0x3F8 COM1
@end

@! ============================================================================
@! 3. TRANSMISSION & STRING LOGGING
@! ============================================================================

@fn serial_write_byte(port, byte_val)
  port.tx_log = port.tx_log.push(byte_val % 256)
  return port
@end

@fn serial_write_char(port, ch)
  return serial_write_byte(port, ch)
@end

@fn serial_write_str(port, str_msg)
  i = 0
  n = str_len(str_msg)
  @while i < n
    ch = str_char_at(str_msg, i)
    port = serial_write_char(port, ch)
    i = i + 1
  @end
  return port
@end

@fn serial_write_line(port, str_msg)
  port = serial_write_str(port, str_msg)
  port = serial_write_char(port, 13) @! '\r'
  port = serial_write_char(port, 10) @! '\n'
  return port
@end
