// ==============================================================================
// 👑 LIPI UTSO — REAL RING-0 16550 UART SERIAL DRIVER (utso/silicon/serial.lp)
// ⚡ 100% Pure Lipi | Real x86 Port I/O (inb/outb) | 0% Linux | 0% Simulation
// ==============================================================================
//
// WHY THIS MODULE:
// Drives physical 16550A UART hardware (COM1 = 0x3F8, COM2 = 0x2F8) directly via
// Lipi's native `port_in8` / `port_out8` silicon instructions. Works live on bare
// x86-64 hardware and QEMU `-serial stdio` with zero heap allocation.
// ==============================================================================

fn COM1_BASE() return 1016 end // 0x3F8
fn COM2_BASE() return 760  end // 0x2F8

fn silicon_serial_init port
    port_out8(port + 1, 0)    // Disable all UART interrupts
    port_out8(port + 3, 128)  // Enable DLAB (set baud rate divisor)
    port_out8(port + 0, 3)    // Divisor low byte = 3 (38400 baud)
    port_out8(port + 1, 0)    // Divisor high byte = 0
    port_out8(port + 3, 3)    // 8 bits, no parity, 1 stop bit (8N1)
    port_out8(port + 2, 199)  // Enable FIFO, clear TX/RX, 14-byte threshold
    port_out8(port + 4, 11)   // IRQs enabled, RTS/DSR set
    return 1

fn silicon_serial_tx_ready port
    return port_in8(port + 5) & 32

fn silicon_serial_rx_ready port
    return port_in8(port + 5) & 1

fn silicon_serial_write_byte port ch
    while (port_in8(port + 5) & 32) == 0
        cpu_pause()
    end
    port_out8(port, ch & 255)
    return 1

fn silicon_serial_read_byte port
    while (port_in8(port + 5) & 1) == 0
        cpu_pause()
    end
    return port_in8(port)

fn silicon_serial_write_cstr port str_ptr
    i = 0
    while 1 == 1
        ch = mem_byte_read(str_ptr, i)
        if ch == 0
            break
        end
        if ch == 10
            silicon_serial_write_byte(port, 13)
        end
        silicon_serial_write_byte(port, ch)
        i = i + 1
    end
    return i

fn silicon_serial_write_u64 port val
    if val == 0
        silicon_serial_write_byte(port, 48)
        return 1
    end
    // Compute highest power of 10 <= val (zero stack/heap buffer needed!)
    div = 1
    tmp = val
    while tmp >= 10
        tmp = tmp / 10
        div = div * 10
    end
    v = val
    cnt = 0
    while div > 0
        d = v / div
        silicon_serial_write_byte(port, 48 + d)
        v = v % div
        div = div / 10
        cnt = cnt + 1
    end
    return cnt
