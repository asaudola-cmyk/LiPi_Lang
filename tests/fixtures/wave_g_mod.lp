// ==============================================================================
// 🧪 WAVE G SCOPED MODULE FIXTURE (tests/fixtures/wave_g_mod.lp)
// Demonstrates `pub` visibility encapsulation: only `pub` items are exported!
// ==============================================================================

fn secret_multiplier()
    return 7
end

pub fn public_scale(x)
    return x * secret_multiplier()
end

pub fn public_greet(who)
    return "Hello, " + who + "!"
end

pub struct VaultPoint {
    x: int,
    y: int
}
