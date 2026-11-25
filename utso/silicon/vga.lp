// ==============================================================================
// 👑 LIPI UTSO — REAL RING-0 VGA TEXT MODE DRIVER (utso/silicon/vga.lp)
// ⚡ 100% Pure Lipi | Real 0xB8000 Single-Instruction 16-bit MMIO | 0% Simulation
// ==============================================================================

fn VGA_TEXT_BASE() return 753664 end // 0xB8000 physical VGA framebuffer
fn VGA_WIDTH()     return 80     end
fn VGA_HEIGHT()    return 25     end

fn silicon_vga_cell ch fg bg
    attr = ((bg & 15) << 4) | (fg & 15)
    return (attr << 8) | (ch & 255)

fn silicon_vga_put_at row col ch fg bg
    if row < 0 or row >= 25 or col < 0 or col >= 80
        return 0
    end
    addr = 753664 + ((row * 80 + col) * 2)
    mmio_w16(addr, silicon_vga_cell(ch, fg, bg))
    return 1

fn silicon_vga_clear fg bg
    blank = silicon_vga_cell(32, fg, bg)
    i = 0
    while i < 2000
        mmio_w16(753664 + (i * 2), blank)
        i = i + 1
    end
    return 2000

fn silicon_vga_write_cstr row col str_ptr fg bg
    c = col
    r = row
    i = 0
    while 1 == 1
        ch = mem_byte_read(str_ptr, i)
        if ch == 0 break end
        if ch == 10
            r = r + 1
            c = 0
        else
            silicon_vga_put_at(r, c, ch, fg, bg)
            c = c + 1
            if c >= 80
                c = 0
                r = r + 1
            end
        end
        if r >= 25 break end
        i = i + 1
    end
    return i

fn silicon_vga_set_cursor row col
    pos = row * 80 + col
    port_out8(980, 15)            // 0x3D4: cursor low byte index
    port_out8(981, pos & 255)     // 0x3D5: low byte
    port_out8(980, 14)            // 0x3D4: cursor high byte index
    port_out8(981, (pos >> 8) & 255)
    return 1
