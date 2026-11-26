// ==============================================================================
// Wave O Regression Suite: Hardware union, Signed/Unsigned Bitfields, Typed
// Pointers (*T / *mut T / &x / pointer arithmetic / sizeof), Structural
// trait / impl + <T: Trait> Generic Bounds, and Real Hardware Stackful Fibers
// ==============================================================================

include "src/runtime/async/coroutine.lp"

union Reg32
    raw: u32
    lo: u16
    b0: u8
end

struct PciCfg
    bus: u32 : 8
    dev: u32 : 5
    func: u32 : 3
    enable: u32 : 1
    sdelta: i32 : 5
end

trait Showable
    fn show(self) -> str
end

struct Wolf
    w_name: str
end

impl Showable for Wolf
    fn show(self) -> str
        return "Wolf:" + self.w_name
    end
end

fn render_show<T: Showable>(item: T) -> str
    return item.show()
end

fn fiber_worker_fn(arg)
    coro_yield_value(arg + 10)
    coro_yield_value(arg + 20)
    return arg + 990
end

fn main()
    // 1. Hardware union (overlapping offset 0, sizeof == max field size)
    if sizeof(Reg32) != 4
        say "FAIL O1a sizeof(Reg32)=" + str(sizeof(Reg32))
        exit(1)
    end
    r = Reg32()
    r.raw = 305419896 // 0x12345678
    if r.lo != 22136 or r.b0 != 120
        say "FAIL O1b union overlay"
        exit(1)
    end

    // 2. Signed & unsigned bitfields
    if sizeof(PciCfg) != 4
        say "FAIL O2a sizeof(PciCfg)=" + str(sizeof(PciCfg))
        exit(1)
    end
    pc = PciCfg()
    pc.bus = 42
    pc.dev = 19
    pc.func = 5
    pc.enable = 1
    pc.sdelta = 0 - 3
    if pc.bus != 42 or pc.dev != 19 or pc.func != 5 or pc.enable != 1 or pc.sdelta != (0 - 3)
        say "FAIL O2b bitfield pack/sign-extend"
        exit(1)
    end

    // 3. Typed pointers (*mut T), &x, scaled pointer arithmetic, deref, sizeof(*T)
    x: i64 = 42
    px: *mut i64 = &x
    *px = 99
    buf = malloc(32)
    p: *mut u32 = buf
    p[0] = 100
    p[1] = 200
    *(p + 2) = 300
    q: *mut u32 = p + 3
    if x != 99 or p[0] != 100 or p[1] != 200 or *(p + 2) != 300 or (q - p) != 3 or sizeof(*u32) != 8
        say "FAIL O3 typed pointers"
        exit(1)
    end

    // 4. Structural trait / impl + compile-time <T: Showable> generic dispatch
    w = Wolf("Rex")
    if render_show<Wolf>(w) != "Wolf:Rex" or render_show(w) != "Wolf:Rex"
        say "FAIL O4 trait/impl generic"
        exit(1)
    end

    // 5. Real hardware x86-64 stackful coroutine fiber (yield -> resume -> complete)
    fb = coro_spawn_fiber(fn_ptr(fiber_worker_fn), 5, 65536)
    v1 = coro_resume_fiber(fb)
    v2 = coro_resume_fiber(fb)
    v3 = coro_resume_fiber(fb)
    st = coro_fiber_state(fb)
    coro_destroy_fiber(fb)
    if v1 != 15 or v2 != 25 or v3 != 995 or st != 3
        say "FAIL O5 real stackful fiber"
        exit(1)
    end

    say "PASS_WAVE_O_UNION_BITFIELD_PTR_TRAIT_CORO"
    return 0
end
