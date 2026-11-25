// ==============================================================================
// 👑 LIPI UTSO — REAL RING-0 VIRTIO MMIO HARDWARE DRIVER (utso/silicon/virtio.lp)
// ⚡ 100% Pure Lipi | Single-Instruction 32-bit MMIO & VirtQueue Rings | 0% Sim
// ==============================================================================

fn VIRTIO_MMIO_MAGIC()         return 0   end // 0x74726976 ("virt")
fn VIRTIO_MMIO_VERSION()       return 4   end
fn VIRTIO_MMIO_DEVICE_ID()     return 8   end
fn VIRTIO_MMIO_VENDOR_ID()     return 12  end
fn VIRTIO_MMIO_QUEUE_SEL()     return 48  end
fn VIRTIO_MMIO_QUEUE_NUM_MAX() return 52  end
fn VIRTIO_MMIO_QUEUE_NUM()     return 56  end
fn VIRTIO_MMIO_QUEUE_READY()   return 68  end
fn VIRTIO_MMIO_QUEUE_NOTIFY()  return 80  end
fn VIRTIO_MMIO_INT_STATUS()    return 96  end
fn VIRTIO_MMIO_INT_ACK()       return 100 end
fn VIRTIO_MMIO_STATUS()        return 112 end
fn VIRTIO_MMIO_DESC_LOW()      return 128 end
fn VIRTIO_MMIO_DESC_HIGH()     return 132 end
fn VIRTIO_MMIO_AVAIL_LOW()     return 144 end
fn VIRTIO_MMIO_AVAIL_HIGH()    return 148 end
fn VIRTIO_MMIO_USED_LOW()      return 160 end
fn VIRTIO_MMIO_USED_HIGH()     return 164 end

@packed
struct VirtqDesc
    vq_addr: u64
    vq_len: u32
    vq_flags: u16
    vq_next: u16
end

fn silicon_virtio_probe mmio_base
    // Returns Device ID if valid VirtIO MMIO device (magic == 0x74726976), else 0
    magic = mmio_r32(mmio_base + 0)
    if magic != 1953655158
        return 0
    end
    return mmio_r32(mmio_base + 8)

fn silicon_virtio_reset mmio_base
    mmio_w32(mmio_base + 112, 0)
    fence_full()
    return 1

fn silicon_virtio_set_status mmio_base bits
    cur = mmio_r32(mmio_base + 112)
    mmio_w32(mmio_base + 112, cur | bits)
    fence_full()
    return 1

fn silicon_virtio_setup_queue mmio_base q_idx q_size desc_phys avail_phys used_phys
    mmio_w32(mmio_base + 48, q_idx)
    max_q = mmio_r32(mmio_base + 52)
    if max_q == 0 or q_size > max_q
        return 0
    end
    mmio_w32(mmio_base + 56, q_size)
    mmio_w32(mmio_base + 128, desc_phys & 4294967295)
    mmio_w32(mmio_base + 132, (desc_phys >> 32) & 4294967295)
    mmio_w32(mmio_base + 144, avail_phys & 4294967295)
    mmio_w32(mmio_base + 148, (avail_phys >> 32) & 4294967295)
    mmio_w32(mmio_base + 160, used_phys & 4294967295)
    mmio_w32(mmio_base + 164, (used_phys >> 32) & 4294967295)
    fence_store()
    mmio_w32(mmio_base + 68, 1)
    return 1

fn silicon_virtio_notify mmio_base q_idx
    fence_store()
    mmio_w32(mmio_base + 80, q_idx)
    return 1
