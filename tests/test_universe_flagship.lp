// ==============================================================================
// 🧪 LIPI TEST: UNIVERSE GRAND FLAGSHIP INTEGRATION SUITE
// File: tests/test_universe_flagship.lp
// ⚡ 100% Pure Lipi Machine Code | Zero Libc | Zero Python | Direct Silicon
// ==============================================================================
//
// WHY: Validates the seamless inter-domain operability of Lipi's Universe
// standard library across Memory, SIMD, Database, Crypto, JSON, and Framebuffer.
// ==============================================================================

import "universe/lipi_universe"
import "universe/core/memory"
import "universe/core/arena"
import "universe/core/collections"
import "universe/core/string"
import "universe/core/json_fast"
import "universe/core/simd"
import "universe/db"
import "universe/crypto"
import "universe/gui"

fn assert_eq_int actual expected test_name
    if actual == expected
        say "  ✔ " + test_name + " verified: " + to_str(actual)
        return 1
    say "  ❌ FAILED: " + test_name + " expected " + to_str(expected) + " but got " + to_str(actual)
    exit(1)

fn assert_eq_str actual expected test_name
    if str_eq(actual, expected) == 1
        say "  ✔ " + test_name + " verified: '" + actual + "'"
        return 1
    say "  ❌ FAILED: " + test_name + " expected '" + expected + "' but got '" + actual + "'"
    exit(1)

fn assert_true cond test_name
    if cond == 1
        say "  ✔ " + test_name + " verified (true)"
        return 1
    say "  ❌ FAILED: " + test_name + " expected true but got false"
    exit(1)

say "=================================================================="
say "👑 LIPI UNIVERSE FLAGSHIP REGRESSION TEST 👑"
say "=================================================================="

// ── Phase 1: Arena & 64-Byte Cacheline Alignment ─────────────────────────────
say "[Phase 1] Sovereign Memory Arena & Cacheline Alignment..."
arena = lipi_arena_new(131072)
assert_true(arena != 0, "Arena Allocation != 0")
raw_buf = arena_alloc_aligned(arena, 256, 64)
assert_true(raw_buf != 0, "Aligned Buffer Allocation != 0")
assert_eq_int(raw_buf % 64, 0, "64-Byte Cacheline Alignment")

// ── Phase 2: Hardware SIMD Vector Acceleration ───────────────────────────────
say "[Phase 2] Hardware SIMD Vector Math..."
i = 0
while i < 32
    mem_write_u64(raw_buf, i * 8, i + 1)
    i = i + 1
end
vec_sum = vector_sum_hardware(raw_buf, 32)
assert_eq_int(vec_sum, 528, "32-element SIMD Vector Sum (sum 1..32)")

// ── Phase 3: Embedded LipiKV Database & ACID Storage ─────────────────────────
say "[Phase 3] Embedded LipiKV Database..."
db_path = "/tmp/flagship_test_store.db"
sys_unlink(db_path)
sys_unlink(str_concat(db_path, ".wal"))
db = lipi_db_open(db_path, 64)
assert_true(db.is_open, "LipiKV Database is_open")

db_put(db, "cluster:name", "Lipi-Dhaka-01")
db_put(db, "cluster:status", "ACTIVE_HEALTHY")
db_put(db, "engine:arch", "Sovereign-AMD64")
db_checkpoint(db)

val_status = db_get(db, "cluster:status")
val_arch = db_get(db, "engine:arch")
assert_eq_str(val_status, "ACTIVE_HEALTHY", "LipiKV Get cluster:status")
assert_eq_str(val_arch, "Sovereign-AMD64", "LipiKV Get engine:arch")
db_close(db)

// ── Phase 4: FIPS Cryptography SHA-256 ───────────────────────────────────────
say "[Phase 4] FIPS SHA-256 Cryptography..."
payload = "Lipi-Dhaka-01:ACTIVE_HEALTHY:Sovereign-AMD64"
digest = lipi_sha256(payload)
assert_eq_str(digest, "4242dee7e1acb704fa29c5dad5c1c6e712e1e78f5aee58b5cd63d418d24ef641", "SHA-256 Payload Hash")

// ── Phase 5: Zero-Copy Fast JSON API Packaging ───────────────────────────────
say "[Phase 5] Fast Zero-Copy JSON API Engine..."
json_str = str_concat("{\"status\":\"", str_concat(val_status, str_concat("\",\"digest\":\"", str_concat(digest, str_concat("\",\"simd_sum\":", str_concat(to_str(vec_sum), "}"))))))
doc = fast_json_parse(json_str)
assert_true(doc != 0, "JSON Parsing != 0")
root_node = fast_json_root(doc)
status_node = fast_json_get(doc, root_node, "status")
parsed_status = fast_json_get_str(doc, status_node)
assert_eq_str(parsed_status, "ACTIVE_HEALTHY", "JSON Extracted status == ACTIVE_HEALTHY")

// ── Phase 6: Direct Hardware Framebuffer Window & Logo ───────────────────────
say "[Phase 6] Direct Framebuffer GUI Title Bar & Brand Icon..."
fb = lipi_gui_open(320, 240)
assert_true(fb != 0, "GUI Framebuffer Opened != 0")
fb_fill_rect(fb, 0, 0, 320, 240, 16843009)
fb_window_create(fb, 10, 10, 300, 220, "Lipi Universe Sovereign Node")
fb_draw_lipi_icon(fb, 20, 20)

// Official Lipi Brand Mark stem cyan color is 49919 (#00C2FF)
p_color = fb_read_pixel(fb, 22, 22)
assert_eq_int(p_color, 49919, "Lipi Official Brand Cyan Pixel (#00C2FF)")
lipi_fb_close(fb)

say "=================================================================="
say "PASS: Test Universe Flagship"
say "=================================================================="
