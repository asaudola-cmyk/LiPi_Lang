// Module isolation test fixture A (same symbol names as mod_ns_b.lp)
struct Box
    val
end

fn compute x
    b = Box(x * 3)
    return b.val + 1
end
