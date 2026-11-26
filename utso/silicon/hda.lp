// ==============================================================================
// 👑 LIPI UTSO — REAL INTEL HDA AUDIO CONTROLLER DRIVER (utso/silicon/hda.lp)
// ⚡ 100% Pure Lipi | Zero Heap | Zero Linux Syscalls | Intel HDA 1.0a MMIO
// ==============================================================================

// Intel HDA Controller Register Offsets (BAR0):
//   +0x00 GCAP(u16), +0x08 GCTL(u32: bit0=CRST), +0x0E STATESTS(u16)
//   +0x40 CORBLBASE(u32), +0x44 CORBUBASE(u32), +0x48 CORBWP(u16), +0x4A CORBRP(u16), +0x4C CORBCTL(u8)
//   +0x50 RIRBLBASE(u32), +0x54 RIRBUBASE(u32), +0x58 RIRBWP(u16), +0x5C RIRBCTL(u8)
//   +0x60 ICW(u32), +0x64 IRR(u32), +0x68 ICS(u16: Immediate Command Status)

fn silicon_hda_reset bar0 max_spins
    // Enter reset (GCTL.CRST = 0), wait, then exit reset (GCTL.CRST = 1)
    mmio_w32(bar0 + 8, 0)
    sp = 0
    while sp < max_spins
        if (mmio_r32(bar0 + 8) & 1) == 0 break end
        sp = sp + 1
    end
    mmio_w32(bar0 + 8, 1)
    sp = 0
    while sp < max_spins
        if (mmio_r32(bar0 + 8) & 1) != 0 return 1 end
        sp = sp + 1
    end
    return 0

fn silicon_hda_codec_mask bar0
    // Bitmask of attached HDA codecs discovered in STATESTS (+0x0E)
    return mmio_r16(bar0 + 14) & 32767

fn silicon_hda_build_verb codec_addr nid verb_id payload
    // WHY: Intel HDA 32-bit Codec Command Verb format:
    //   [31:28] CAd | [27:20] NID | [19:8] VerbID (12-bit) | [7:0] Payload (8-bit)
    return ((codec_addr & 15) << 28) | ((nid & 255) << 20) | ((verb_id & 4095) << 8) | (payload & 255)

fn silicon_hda_init_corb_rirb bar0 corb_phys rirb_phys
    // Stop CORB & RIRB DMA before programming ring bases
    mmio_w8(bar0 + 76, 0)  // CORBCTL = 0
    mmio_w8(bar0 + 92, 0)  // RIRBCTL = 0
    mmio_w32(bar0 + 64, corb_phys & 4294967295)
    mmio_w32(bar0 + 68, (corb_phys >> 32) & 4294967295)
    mmio_w16(bar0 + 72, 0) // CORBWP = 0
    mmio_w32(bar0 + 80, rirb_phys & 4294967295)
    mmio_w32(bar0 + 84, (rirb_phys >> 32) & 4294967295)
    mmio_w16(bar0 + 88, 32768) // RIRBWP reset (bit 15)
    // Start CORB & RIRB DMA engines (bit 1 = RUN)
    mmio_w8(bar0 + 76, 2)
    mmio_w8(bar0 + 92, 2)
    return 0

fn silicon_hda_immediate_verb bar0 verb32 max_spins
    // Sends a single HDA verb via Immediate Command interface (ICW/ICS/IRR) and returns 32-bit codec response.
    mmio_w16(bar0 + 104, 2)     // Clear IRV (bit 1)
    mmio_w32(bar0 + 96, verb32) // ICW (+0x60)
    mmio_w16(bar0 + 104, 1)     // Set ICB (bit 0) to dispatch
    sp = 0
    while sp < max_spins
        ics = mmio_r16(bar0 + 104)
        if (ics & 1) == 0 and (ics & 2) != 0
            return mmio_r32(bar0 + 100) // IRR (+0x64)
        end
        sp = sp + 1
    end
    return 0 - 1
