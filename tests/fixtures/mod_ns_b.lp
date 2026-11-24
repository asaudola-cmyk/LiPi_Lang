// Module isolation test fixture B (colliding symbol names with mod_ns_a.lp)
struct Box
    val
end

fn compute x
    b = Box(x * 7)
    return b.val + 2
end
