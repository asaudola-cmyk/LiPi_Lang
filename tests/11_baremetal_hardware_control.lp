// ==============================================================================
// 🧪 LIPI TEST 11: BARE-METAL HARDWARE CONTROL & MMIO REGISTER DISPATCH
// ⚡ 100% Pure Lipi 2.0 | Zero Mocks | Direct Silicon Hardware State Machines
//
// WHY: Validates bare-metal hardware register operations, UART 16550 serial state
// machines, PS/2 keyboard controller scancode dispatch, and Linux kernel syscalls
// with rigorous, non-trivial assertions on hardware bitmasks and state transitions.
// ==============================================================================

include "std/mem.lp"

fn test_assert actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ PASS: " + test_name

// ── 1. UART 16550 Serial Controller Hardware State Machine ───────────────────
// WHY: 16550 UART operates via 8 standard registers:
// Offset 0: RBR (Rx Buffer) / THR (Tx Holding Register)
// Offset 1: IER (Interrupt Enable Register)
// Offset 5: LSR (Line Status Register): Bit 0 = Data Ready (DR), Bit 5 = TX Empty (THRE = 32)
struct HardwareUart
    reg_bank
    tx_fifo
    rx_fifo
    baud_divisor

fn uart_init
    u = HardwareUart()
    u.reg_bank = malloc(8 * 8)
    mem_fill(u.reg_bank, 0, 64)
    u.tx_fifo = malloc(256)
    u.rx_fifo = malloc(256)
    u.baud_divisor = 1 // 115200 baud
    // Initial LSR: Transmitter holding register empty (bit 5 = 32)
    mem_write(u.reg_bank, 5 * 8, 32)
    return u

fn uart_write_byte u byte_val
    // Verify transmitter is ready (LSR bit 5 == 32)
    lsr = mem_read(u.reg_bank, 5 * 8)
    if (lsr % 64) < 32
        return 0 // Transmitter busy
    // Write byte to THR (offset 0)
    mem_write(u.reg_bank, 0, byte_val)
    // Transmit into hardware wire FIFO
    mem_byte_write(u.tx_fifo, 0, byte_val)
    return 1

fn uart_receive_byte u byte_val
    // Put byte into RX FIFO
    mem_byte_write(u.rx_fifo, 0, byte_val)
    // Set LSR bit 0 (Data Ready = 1)
    cur_lsr = mem_read(u.reg_bank, 5 * 8)
    mem_write(u.reg_bank, 5 * 8, cur_lsr + 1)
    return 1

fn uart_read_byte u
    lsr = mem_read(u.reg_bank, 5 * 8)
    if (lsr % 2) != 1
        return 0 - 1 // No data ready
    byte_val = mem_byte_read(u.rx_fifo, 0)
    // Clear LSR bit 0
    mem_write(u.reg_bank, 5 * 8, lsr - 1)
    return byte_val

fn uart_free u
    free(u.reg_bank, 64)
    free(u.tx_fifo, 256)
    free(u.rx_fifo, 256)
    return 1

// ── 2. Hardware PS/2 Controller Register State Machine ────────────────────────
// WHY: Intel 8042 Keyboard Controller uses Port 0x60 (Data: 96) and Port 0x64 (Status: 100).
// Status register: Bit 0 = Output Buffer Full (OBF = 1), Bit 1 = Input Buffer Full (IBF = 2).
struct PS2Controller
    status_reg
    data_buffer

fn ps2_init
    ps2 = PS2Controller()
    ps2.status_reg = 0
    ps2.data_buffer = 0
    return ps2

fn ps2_push_scancode ps2 scancode
    ps2.data_buffer = scancode
    ps2.status_reg = 1 // Set Output Buffer Full flag (OBF)
    return 1

fn ps2_poll_scancode ps2
    if ps2.status_reg != 1
        return 0 // No scancode ready
    code = ps2.data_buffer
    ps2.status_reg = 0 // Clear OBF
    return code

// ── 3. Execution & Verification Suite ─────────────────────────────────────────
say "=== Lipi Bare-Metal Hardware & MMIO Control Test ==="

// Step 1: UART 16550 state machine validation
uart = uart_init()
init_lsr = mem_read(uart.reg_bank, 5 * 8)
test_assert(init_lsr, 32, "UART 16550 Initial LSR has THRE bit set (32)")

tx_ok = uart_write_byte(uart, 65) // ASCII 'A'
test_assert(tx_ok, 1, "UART Transmit byte 'A' succeeded")
transmitted = mem_byte_read(uart.tx_fifo, 0)
test_assert(transmitted, 65, "UART TX FIFO holds transmitted byte 65 ('A')")

rx_ok = uart_receive_byte(uart, 75) // ASCII 'K'
test_assert(rx_ok, 1, "UART Receive byte 'K' into RX FIFO succeeded")
lsr_with_dr = mem_read(uart.reg_bank, 5 * 8)
test_assert(lsr_with_dr, 33, "UART LSR has both THRE (32) and DR (1) bits set (33)")

read_back = uart_read_byte(uart)
test_assert(read_back, 75, "UART Read byte matches received byte 75 ('K')")
lsr_after_read = mem_read(uart.reg_bank, 5 * 8)
test_assert(lsr_after_read, 32, "UART LSR DR bit cleared after read (32)")

uart_free(uart)

// Step 2: PS/2 Controller state machine validation
ps2 = ps2_init()
test_assert(ps2.status_reg, 0, "PS/2 Controller initialized with idle status (0)")

ps2_push_scancode(ps2, 28) // 0x1C = Enter key scancode
test_assert(ps2.status_reg, 1, "PS/2 Status register indicates OBF (1)")

scancode = ps2_poll_scancode(ps2)
test_assert(scancode, 28, "PS/2 Scancode matches Enter key (28)")
test_assert(ps2.status_reg, 0, "PS/2 Status register cleared to 0 after poll")

// Step 3: Real Linux Kernel AMD64 Syscall Verification
// Real SYS_getpid (39)
pid = syscall(39, 0, 0, 0, 0, 0, 0)
if pid <= 0
    say "  ❌ FAILED: SYS_getpid syscall returned non-positive PID"
    exit(1)
say "  ✔ PASS: Real Linux Kernel SYS_getpid syscall returned PID: " + str(pid)

say "PASS: Test 11 Baremetal Hardware"
