// ==============================================================================
// 👑 LIPI UTSO — REAL ARM64 PRIMECELL PL011 UART DRIVER (utso/silicon/pl011.lp)
// ⚡ 100% Pure Lipi | Real AArch64 MMIO | 0% Linux SVC | 0% Heap | 0% Simulation
// ==============================================================================
//
// WHY THIS MODULE:
// Drives ARM PrimeCell PL011 UART hardware directly via 32-bit MMIO registers on
// QEMU `virt` (0x09000000), Raspberry Pi 4 (0xFE201000), and bare-metal AArch64 SoCs.
// Zero heap allocations, zero Linux syscalls — safe in EL1/EL2/EL3 Ring-0 kernels.
// ==============================================================================

// Canonical physical MMIO base addresses
fn PL011_QEMU_VIRT_BASE() return 150994944 end   // 0x09000000
fn PL011_RPI4_BASE()      return 4263514112 end  // 0xFE201000

// PL011 register byte offsets
//   +0x00 (0)  = UARTDR   (Data Register)
//   +0x04 (4)  = UARTRSR  (Receive Status / Error Clear)
//   +0x18 (24) = UARTFR   (Flag Register: bit 3=BUSY, bit 4=RXFE, bit 5=TXFF)
//   +0x24 (36) = UARTIBRD (Integer Baud Rate Divisor)
//   +0x28 (40) = UARTFBRD (Fractional Baud Rate Divisor)
//   +0x2C (44) = UARTLCR_H (Line Control: bit 4=FEN, bits 6:5=WLEN 8N1=0x60 -> 0x70)
//   +0x30 (48) = UARTCR   (Control: bit 0=UARTEN, bit 8=TXE, bit 9=RXE -> 0x301)
//   +0x38 (56) = UARTIMSC (Interrupt Mask Set/Clear)
//   +0x44 (68) = UARTICR  (Interrupt Clear Register)

fn silicon_pl011_init base uartclk_hz baud
    // Disable UART while configuring divisors and FIFO
    mmio_w32(base + 48, 0)
    cpu_dsb()
    // Clear all pending interrupts (0x7FF)
    mmio_w32(base + 68, 2047)
    // Compute 16x oversampled baud divisor: div64 = (uartclk_hz * 4) / baud
    if baud > 0 and uartclk_hz > 0
        div64 = (uartclk_hz * 4) / baud
        ibrd = div64 >> 6
        fbrd = div64 & 63
        if ibrd == 0
            ibrd = 1
        end
        mmio_w32(base + 36, ibrd & 65535)
        mmio_w32(base + 40, fbrd & 63)
    end
    // 8N1 + FIFO enabled (WLEN=11b [bits 6:5] | FEN [bit 4] = 0x70 = 112)
    mmio_w32(base + 44, 112)
    // Mask all UART interrupts until kernel IRQ dispatcher enables them
    mmio_w32(base + 56, 0)
    // Enable UART, TX, and RX (0x301 = 769)
    mmio_w32(base + 48, 769)
    cpu_dsb()
    return 1
end

fn silicon_pl011_tx_ready base
    // UARTFR bit 5 (0x20 = 32) = TXFF (Transmit FIFO Full); ready when 0
    if (mmio_r32(base + 24) & 32) == 0
        return 1
    end
    return 0
end

fn silicon_pl011_rx_ready base
    // UARTFR bit 4 (0x10 = 16) = RXFE (Receive FIFO Empty); ready when 0
    if (mmio_r32(base + 24) & 16) == 0
        return 1
    end
    return 0
end

fn silicon_pl011_flush base
    // Wait while UARTFR bit 3 (0x08 = 8, BUSY) is set
    while (mmio_r32(base + 24) & 8) != 0
        cpu_nop()
    end
    return 1
end

fn silicon_pl011_write_byte base ch
    while (mmio_r32(base + 24) & 32) != 0
        cpu_nop()
    end
    mmio_w32(base + 0, ch & 255)
    return 1
end

fn silicon_pl011_read_byte base
    while (mmio_r32(base + 24) & 16) != 0
        cpu_nop()
    end
    return mmio_r32(base + 0) & 255
end

fn silicon_pl011_set_irq_mask base mask
    mmio_w32(base + 56, mask & 2047)
    cpu_dsb()
    return 1
end

fn silicon_pl011_clear_irqs base mask
    mmio_w32(base + 68, mask & 2047)
    cpu_dsb()
    return 1
end

fn silicon_pl011_write_cstr base str_ptr
    i = 0
    while 1 == 1
        ch = mem_byte_read(str_ptr, i)
        if ch == 0
            break
        end
        if ch == 10
            silicon_pl011_write_byte(base, 13)
        end
        silicon_pl011_write_byte(base, ch)
        i = i + 1
    end
    return i
end

fn silicon_pl011_write_u64 base val
    if val == 0
        silicon_pl011_write_byte(base, 48)
        return 1
    end
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
        silicon_pl011_write_byte(base, 48 + d)
        v = v % div
        div = div / 10
        cnt = cnt + 1
    end
    return cnt
end
