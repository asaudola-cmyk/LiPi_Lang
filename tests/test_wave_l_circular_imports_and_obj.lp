// ==============================================================================
// Wave L Test: 3-Color DFS Circular Import Resolution & VirtIO Packed Layout
// ==============================================================================

import "tests/mod_cycle_a.lp"
import "utso/silicon/virtio.lp"

fn main()
    // 1. Mutual recursion across circularly importing modules A <-> B
    if cycle_even(10) != 1 or cycle_even(7) != 0 or cycle_odd(9) != 1 or cycle_odd(8) != 0
        say "FAIL circular import mutual recursion"
        exit(1)
    end

    // 2. Real VirtIO Ring Descriptor packed hardware struct layout (16B spec exact!)
    if sizeof(VirtqDesc) != 16
        say "FAIL VirtqDesc sizeof=" + str(sizeof(VirtqDesc))
        exit(1)
    end
    if offsetof(VirtqDesc, vq_addr) != 0 or offsetof(VirtqDesc, vq_len) != 8 or offsetof(VirtqDesc, vq_flags) != 12 or offsetof(VirtqDesc, vq_next) != 14
        say "FAIL VirtqDesc offsetof"
        exit(1)
    end

    say "PASS_WAVE_L_CIRCULAR_IMPORTS_AND_VIRTIO_LAYOUT"
    return 0
end
