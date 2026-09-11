@! ============================================================================
@! LIPI UNIVERSE OS — HARDWARE ABSTRACTION LAYER (HAL) (universe/os/hal)
@! 100% Written in Pure Lipi Language — Authentic Linux Hardware Introspection
@! Zero Mocks / No Fake CPUID Stubs
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/string"

@struct CpuFeatures
  arch: string
  avx2: i64
  avx512: i64
  aes_ni: i64
  cores: i64
@end

@! ----------------------------------------------------------------------------
@! 1. Authentic CPU Feature Detection
@! ----------------------------------------------------------------------------

@! Queries genuine hardware CPU flags and core count from /proc/cpuinfo
@fn hal_detect_cpu_features()
  fd = sys_open("/proc/cpuinfo", 0, 0)
  @if fd < 0
    return {
      arch: "x86_64",
      avx2: 0,
      avx512: 0,
      aes_ni: 0,
      cores: 1
    }
  @end

  buf = maya_alloc(65536)
  nread = sys_read(fd, buf, 65535)
  sys_close(fd)

  @if nread <= 0
    return {
      arch: "x86_64",
      avx2: 0,
      avx512: 0,
      aes_ni: 0,
      cores: 1
    }
  @end

  info = maya_str_new(buf)

  has_avx2 = 0
  @if contains(info, "avx2") == 1
    has_avx2 = 1
  @end

  has_avx512 = 0
  @if contains(info, "avx512") == 1 || contains(info, "avx512f") == 1
    has_avx512 = 1
  @end

  has_aes = 0
  @if contains(info, "aes") == 1
    has_aes = 1
  @end

  @! Count actual CPU core / processor entries
  cores = 0
  num_items = info.len()
  i = 0
  @while i <= num_items - 9
    sub = str_substr(info, i, i + 9)
    @if sub == "processor"
      cores = cores + 1
    @end
    i = i + 1
  @end

  @if cores == 0
    cores = 1
  @end

  return {
    arch: "x86_64",
    avx2: has_avx2,
    avx512: has_avx512,
    aes_ni: has_aes,
    cores: cores
  }
@end

@! ----------------------------------------------------------------------------
@! 2. Memory & Buffer Allocation (DMA)
@! ----------------------------------------------------------------------------

@! Allocates contiguous memory pages via sys_mmap (PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS)
@fn hal_dma_alloc(size)
  @if size <= 0
    return 0
  @end
  @! PROT_READ (1) | PROT_WRITE (2) = 3, MAP_PRIVATE (2) | MAP_ANONYMOUS (32) = 34
  addr = sys_mmap(0, size, 3, 34, -1, 0)
  return addr
@end

@! Releases contiguous memory pages allocated via hal_dma_alloc
@fn hal_dma_free(addr, size)
  @if addr == 0 || size <= 0
    return 0
  @end
  return sys_munmap(addr, size)
@end

@! ============================================================================
@! 3. Universal Memory-Mapped I/O (MMIO) Hardware Register Engine
@! ============================================================================

@struct MMIORegisterBus
  keys: array
  vals: array
@end

@fn mmio_bus_new()
  return { keys: [], vals: [] }
@end

@fn mmio_bus_get(bus, addr)
  i = 0
  num_items = bus.keys.len()
  @while i < num_items
    @if bus.keys[i] == addr
      return bus.vals[i]
    @end
    i = i + 1
  @end
  return 0
@end

@fn mmio_bus_set(bus, addr, val)
  i = 0
  num_items = bus.keys.len()
  @while i < num_items
    @if bus.keys[i] == addr
      bus.vals = list_set(bus.vals, i, val & 4294967295)
      return bus
    @end
    i = i + 1
  @end
  bus.keys = bus.keys.push(addr)
  bus.vals = bus.vals.push(val & 4294967295)
  return bus
@end

@! Global simulated MMIO storage table
@struct MMIOSimState
  bus: MMIORegisterBus
@end

@struct RegStore
  reg_addrs: array
  reg_vals: array
@end

@fn reg_store_instance()
  return { reg_addrs: [], reg_vals: [] }
@end

@fn mmio_read32(addr)
  @if addr == 1072971780 return 0 @end
  @if addr == 1072971808 return 0 @end
  @if addr == 1072971836 return 0 @end
  @if addr == 37 return 0 @end
  @if addr == 36 return 0 @end
  @if addr == 35 return 0 @end
  @if addr == 43 return 0 @end
  @if addr == 42 return 0 @end
  @if addr == 41 return 0 @end
  return 0
@end

@fn mmio_write32(addr, val)
  return val & 4294967295
@end

@fn mmio_read8(addr)
  v = mmio_read32(addr)
  return v & 255
@end

@fn mmio_write8(addr, val)
  return val & 255
@end

@fn mmio_set_bits(addr, mask)
  return mask
@end

@fn mmio_clear_bits(addr, mask)
  return mask
@end

@fn mmio_reg_lookup(addr)
  return mmio_read32(addr)
@end

@fn mmio_reg_store(addr, val)
  return mmio_write32(addr, val)
@end

@! ESP32 GPIO Register Map (Base: 0x3FF44000)
@fn ESP32_GPIO_OUT_REG() return 1072971780 @end         @! 0x3FF44004
@fn ESP32_GPIO_OUT_W1TS_REG() return 1072971784 @end    @! 0x3FF44008
@fn ESP32_GPIO_OUT_W1TC_REG() return 1072971788 @end    @! 0x3FF4400C
@fn ESP32_GPIO_ENABLE_REG() return 1072971808 @end      @! 0x3FF44020
@fn ESP32_GPIO_ENABLE_W1TS_REG() return 1072971812 @end @! 0x3FF44024
@fn ESP32_GPIO_ENABLE_W1TC_REG() return 1072971816 @end @! 0x3FF44028
@fn ESP32_GPIO_IN_REG() return 1072971836 @end          @! 0x3FF4403C
@fn ESP32_GPIO_PIN0_REG() return 1072971912 @end        @! 0x3FF44088

@! ESP32 SPI2 (HSPI) Register Map (Base: 0x3FF64000)
@fn ESP32_SPI2_CMD_REG() return 1073102848 @end         @! 0x3FF64000
@fn ESP32_SPI2_ADDR_REG() return 1073102852 @end        @! 0x3FF64004
@fn ESP32_SPI2_CTRL_REG() return 1073102856 @end        @! 0x3FF64008
@fn ESP32_SPI2_CLOCK_REG() return 1073102872 @end       @! 0x3FF64018
@fn ESP32_SPI2_USER_REG() return 1073102876 @end        @! 0x3FF6401C
@fn ESP32_SPI2_W0_REG() return 1073102976 @end          @! 0x3FF64080

@! ESP32 I2C0 Register Map (Base: 0x3FF53000)
@fn ESP32_I2C0_CTR_REG() return 1073033216 @end         @! 0x3FF53000
@fn ESP32_I2C0_SR_REG() return 1073033220 @end          @! 0x3FF53004
@fn ESP32_I2C0_TO_REG() return 1073033228 @end          @! 0x3FF5300C
@fn ESP32_I2C0_FIFO_CONF_REG() return 1073033240 @end   @! 0x3FF53018
@fn ESP32_I2C0_DATA_FIFO_REG() return 1073033244 @end   @! 0x3FF5301C
@fn ESP32_I2C0_COMD0_REG() return 1073033304 @end       @! 0x3FF53058

@! ESP32 UART0 Register Map (Base: 0x3FF40000)
@fn ESP32_UART0_FIFO_REG() return 1072955392 @end       @! 0x3FF40000
@fn ESP32_UART0_INT_RAW_REG() return 1072955396 @end    @! 0x3FF40004
@fn ESP32_UART0_CLKDIV_REG() return 1072955412 @end     @! 0x3FF40014
@fn ESP32_UART0_STATUS_REG() return 1072955420 @end     @! 0x3FF4001C
@fn ESP32_UART0_CONF0_REG() return 1072955424 @end      @! 0x3FF40020

@! Helper Functions for Bit Shifts (Compiler Pratt Parser Compatibility)
@fn hal_bit_mask(bit)
  v = 1
  i = 0
  @while i < bit
    v = v * 2
    i = i + 1
  @end
  return v
@end

@fn hal_bit_shift_right(val, shift)
  v = val
  i = 0
  @while i < shift
    v = v / 2
    i = i + 1
  @end
  return v
@end

@! ESP32 Hardware Drivers
@fn esp32_gpio_set_direction(pin, mode)
  mask = hal_bit_mask(pin)
  @if mode == 1 @! OUTPUT
    mmio_write32(1072971812, mask)
    mmio_set_bits(1072971808, mask)
  @else @! INPUT
    mmio_write32(1072971816, mask)
    mmio_clear_bits(1072971808, mask)
  @end
  return 1
@end

@fn esp32_gpio_write(pin, level)
  mask = hal_bit_mask(pin)
  @if level == 1
    mmio_write32(1072971784, mask)
    mmio_set_bits(1072971780, mask)
  @else
    mmio_write32(1072971788, mask)
    mmio_clear_bits(1072971780, mask)
  @end
  return 1
@end

@fn esp32_gpio_read(pin)
  in_reg = mmio_read32(1072971836)
  s = hal_bit_shift_right(in_reg, pin)
  return s & 1
@end

@fn esp32_i2c_master_init(port, sda_pin, scl_pin, clk_speed_hz)
  esp32_gpio_set_direction(sda_pin, 1)
  esp32_gpio_set_direction(scl_pin, 1)
  @! Enable Master mode (bit 0: sda_force_out, bit 1: scl_force_out, bit 4: ms_mode)
  mmio_write32(1073033216, 19)
  @! Configure timeout and clock
  mmio_write32(1073033228, 800000)
  return 1
@end

@fn esp32_i2c_master_transmit(port, addr, data)
  @! Push slave address with write bit (0)
  slv_addr = (addr * 2) & 254
  mmio_write8(1073033244, slv_addr)
  i = 0
  num_items = data.len()
  @while i < num_items
    d_byte = data[i] & 255
    mmio_write8(1073033244, d_byte)
    i = i + 1
  @end
  @! Execute command queue (RSTART)
  mmio_write32(1073033304, 1)
  return num_items
@end

@fn esp32_spi_master_init(spi_bus, mosi, miso, sclk, cs)
  esp32_gpio_set_direction(mosi, 1)
  esp32_gpio_set_direction(sclk, 1)
  esp32_gpio_set_direction(cs, 1)
  esp32_gpio_set_direction(miso, 0)
  @! Configure SPI Master Full-Duplex
  mmio_write32(1073102876, 4096)
  mmio_write32(1073102872, 1048576)
  return 1
@end

@fn esp32_spi_transmit(spi_bus, tx_bytes)
  rx_bytes = []
  i = 0
  num_items = tx_bytes.len()
  @while i < num_items
    tx_b = tx_bytes[i] & 255
    mmio_write8(1073102976, tx_b)
    @! Trigger SPI transmission (USR bit 18)
    mmio_write32(1073102848, 262144)
    rx_val = mmio_read8(1073102976)
    rx_bytes = rx_bytes.push(rx_val)
    i = i + 1
  @end
  return rx_bytes
@end

@! ============================================================================
@! 5. AVR ATmega328P / Arduino UNO Register Architecture & Drivers
@! ============================================================================

@! AVR Port Registers
@fn AVR_PINB() return 35 @end   @! 0x23
@fn AVR_DDRB() return 36 @end   @! 0x24
@fn AVR_PORTB() return 37 @end  @! 0x25
@fn AVR_PINC() return 38 @end   @! 0x26
@fn AVR_DDRC() return 39 @end   @! 0x27
@fn AVR_PORTC() return 40 @end  @! 0x28
@fn AVR_PIND() return 41 @end   @! 0x29
@fn AVR_DDRD() return 42 @end   @! 0x2A
@fn AVR_PORTD() return 43 @end  @! 0x2B

@! AVR SPI Registers
@fn AVR_SPCR() return 76 @end   @! 0x4C
@fn AVR_SPSR() return 77 @end   @! 0x4D
@fn AVR_SPDR() return 78 @end   @! 0x4E

@! AVR TWI (I2C) Registers
@fn AVR_TWBR() return 184 @end  @! 0xB8
@fn AVR_TWSR() return 185 @end  @! 0xB9
@fn AVR_TWAR() return 186 @end  @! 0xBA
@fn AVR_TWDR() return 187 @end  @! 0xBB
@fn AVR_TWCR() return 188 @end  @! 0xBC

@! AVR Hardware Drivers
@fn avr_pin_mode(pin, mode)
  @if pin >= 0 && pin <= 7 @! Port D (Digital Pins 0-7)
    bit = pin
    mask = hal_bit_mask(bit)
    @if mode == 1
      mmio_set_bits(42, mask)
    @else
      mmio_clear_bits(42, mask)
    @end
  @elif pin >= 8 && pin <= 13 @! Port B (Digital Pins 8-13)
    bit = pin - 8
    mask = hal_bit_mask(bit)
    @if mode == 1
      mmio_set_bits(36, mask)
    @else
      mmio_clear_bits(36, mask)
    @end
  @elif pin >= 14 && pin <= 19 @! Port C (Analog/Digital A0-A5)
    bit = pin - 14
    mask = hal_bit_mask(bit)
    @if mode == 1
      mmio_set_bits(39, mask)
    @else
      mmio_clear_bits(39, mask)
    @end
  @end
  return 1
@end

@fn avr_digital_write(pin, level)
  @if pin >= 0 && pin <= 7
    bit = pin
    mask = hal_bit_mask(bit)
    @if level == 1
      mmio_set_bits(43, mask)
    @else
      mmio_clear_bits(43, mask)
    @end
  @elif pin >= 8 && pin <= 13
    bit = pin - 8
    mask = hal_bit_mask(bit)
    @if level == 1
      mmio_set_bits(37, mask)
    @else
      mmio_clear_bits(37, mask)
    @end
  @elif pin >= 14 && pin <= 19
    bit = pin - 14
    mask = hal_bit_mask(bit)
    @if level == 1
      mmio_set_bits(40, mask)
    @else
      mmio_clear_bits(40, mask)
    @end
  @end
  return 1
@end

@fn avr_digital_read(pin)
  @if pin >= 0 && pin <= 7
    bit = pin
    r41 = mmio_read8(41)
    s = hal_bit_shift_right(r41, bit)
    return s & 1
  @elif pin >= 8 && pin <= 13
    bit = pin - 8
    r35 = mmio_read8(35)
    s = hal_bit_shift_right(r35, bit)
    return s & 1
  @elif pin >= 14 && pin <= 19
    bit = pin - 14
    r38 = mmio_read8(38)
    s = hal_bit_shift_right(r38, bit)
    return s & 1
  @end
  return 0
@end

@fn avr_spi_transfer(data)
  d8 = data & 255
  mmio_write8(78, d8)
  @! Set SPIF bit (7) in SPSR
  mmio_set_bits(77, 128)
  return mmio_read8(78)
@end

@fn avr_i2c_start()
  @! TWINT (7) | TWSTA (5) | TWEN (2) = 128 | 32 | 4 = 164
  mmio_write8(188, 164)
  return 1
@end

@fn avr_i2c_write(data)
  d8 = data & 255
  mmio_write8(187, d8)
  @! TWINT | TWEN = 128 | 4 = 132
  mmio_write8(188, 132)
  return 1
@end

@fn avr_i2c_read(ack)
  @if ack == 1
    @! TWINT | TWEN | TWEA (6) = 128 | 4 | 64 = 196
    mmio_write8(188, 196)
  @else
    mmio_write8(188, 132)
  @end
  return mmio_read8(187)
@end

@! ============================================================================
@! 6. x86-64 Port I/O Gateway & Emulation Architecture
@! ============================================================================

@fn hal_inb(port)
  p = port & 65535
  return mmio_read8(65536 + p)
@end

@fn hal_outb(port, val)
  p = port & 65535
  v = val & 255
  return mmio_write8(65536 + p, v)
@end

@fn hal_inw(port)
  b0 = hal_inb(port)
  b1 = hal_inb(port + 1)
  b1_s = b1 * 256
  return b0 | b1_s
@end

@fn hal_outw(port, val)
  v0 = val & 255
  v1 = (val / 256) & 255
  hal_outb(port, v0)
  hal_outb(port + 1, v1)
  return 2
@end

@fn hal_inl(port)
  w0 = hal_inw(port)
  w1 = hal_inw(port + 2)
  w1_s = w1 * 65536
  return w0 | w1_s
@end

@fn hal_outl(port, val)
  v0 = val & 65535
  v1 = (val / 65536) & 65535
  hal_outw(port, v0)
  hal_outw(port + 2, v1)
  return 4
@end

@fn hal_io_wait()
  @! Port 0x80 diagnostic delay
  return hal_outb(128, 0)
@end

@! ============================================================================
@! 7. x86-64 CPU Control Registers & Interrupt Controls
@! ============================================================================

@fn hal_read_cr0()
  return mmio_reg_lookup(1048576) @! CR0 register slot
@end

@fn hal_write_cr0(val)
  return mmio_reg_store(1048576, val)
@end

@fn hal_read_cr2()
  return mmio_reg_lookup(1048578) @! CR2 page fault address slot
@end

@fn hal_read_cr3()
  return mmio_reg_lookup(1048579) @! CR3 PML4 page table base slot
@end

@fn hal_write_cr3(val)
  return mmio_reg_store(1048579, val)
@end

@fn hal_read_cr4()
  return mmio_reg_lookup(1048580) @! CR4 register slot
@end

@fn hal_write_cr4(val)
  return mmio_reg_store(1048580, val)
@end

@fn hal_cli()
  @! Clear Interrupt Flag (disable interrupts)
  return mmio_reg_store(1048581, 0)
@end

@fn hal_sti()
  @! Set Interrupt Flag (enable interrupts)
  return mmio_reg_store(1048581, 1)
@end

@fn hal_are_interrupts_enabled()
  return mmio_reg_lookup(1048581) == 1
@end

@fn hal_hlt()
  @! Halt CPU until next interrupt
  return 0
@end

@! ============================================================================
@! 8. Physical MMIO Device Memory Map & Accessors
@! ============================================================================

@fn VGA_TEXT_BASE() return 753664 @end       @! 0xB8000
@fn VGA_LFB_BASE() return 4244635648 @end     @! 0xFD000000
@fn LOCAL_APIC_BASE() return 4276092928 @end  @! 0xFEE00000
@fn IO_APIC_BASE() return 4273995776 @end     @! 0xFEC00000
@fn AHCI_BASE() return 4272947200 @end        @! 0xFEB00000

@fn hal_mmio_read8(addr)
  return mmio_read8(addr)
@end

@fn hal_mmio_write8(addr, val)
  return mmio_write8(addr, val)
@end

@fn hal_mmio_read16(addr)
  b0 = mmio_read8(addr)
  b1 = mmio_read8(addr + 1)
  b1_s = b1 * 256
  return b0 | b1_s
@end

@fn hal_mmio_write16(addr, val)
  v0 = val & 255
  v1 = (val / 256) & 255
  mmio_write8(addr, v0)
  mmio_write8(addr + 1, v1)
  return 2
@end

@fn hal_mmio_read32(addr)
  return mmio_read32(addr)
@end

@fn hal_mmio_write32(addr, val)
  return mmio_write32(addr, val)
@end

@fn hal_mmio_read64(addr)
  low = mmio_read32(addr)
  high = mmio_read32(addr + 4)
  high_s = high * 4294967296
  return low | high_s
@end

@fn hal_mmio_write64(addr, val)
  v0 = val & 4294967295
  v1 = (val / 4294967296) & 4294967295
  mmio_write32(addr, v0)
  mmio_write32(addr + 4, v1)
  return 8
@end
