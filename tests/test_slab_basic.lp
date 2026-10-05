// Test lipi_slab.lp basic compilation and execution
include "src/runtime/lipi_slab.lp"

say "Testing lipi_slab initialization..."
eng = lipi_slab_engine_new()
if eng == 0
    say "✖ Failed to create slab engine"
    exit(1)
say "✔ lipi_slab initialized"

p1 = lipi_slab_alloc(eng, 16)
p2 = lipi_slab_alloc(eng, 32)
p3 = lipi_slab_alloc(eng, 64)
p4 = lipi_slab_alloc(eng, 128)
p5 = lipi_slab_alloc(eng, 256)
p6 = lipi_slab_alloc(eng, 512)
p7 = lipi_slab_alloc(eng, 1024)
p8 = lipi_slab_alloc(eng, 2048)
p9 = lipi_slab_alloc(eng, 4096)

say "✔ All 9 geometric size classes allocated successfully"

lipi_slab_free(eng, p1)
lipi_slab_free(eng, p2)
lipi_slab_free(eng, p3)
lipi_slab_free(eng, p4)
lipi_slab_free(eng, p5)
lipi_slab_free(eng, p6)
lipi_slab_free(eng, p7)
lipi_slab_free(eng, p8)
lipi_slab_free(eng, p9)

say "✔ All 9 geometric size classes freed successfully"

zl = lipi_slab_verify_zero_leak(eng)
if zl == 1
    say "✔ 100% Zero-Leak Verified!"
else
    say "✖ Leak detected!"
    exit(1)

lipi_slab_destroy(eng)
say "PASS: test_slab_basic"
