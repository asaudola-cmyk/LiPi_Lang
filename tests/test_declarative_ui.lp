// ==============================================================================
// 🧪 LIPI TEST: Declarative Reactive UI Engine & 2D Framebuffer Rasterizer
// ⚡ Tests declarative component hierarchy, reactive state signal mutations,
//    flexbox layout resolution, 32-bit RGBA pixel buffer rasterization, and hit-testing.
// ==============================================================================

include "universe/gui/ui_declarative.lp"

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ " + test_name

say "========================================================"
say "👑 Testing Lipi Declarative Reactive UI Engine (No HTML/CSS/JS)"
say "========================================================"

// ── Test 1: Reactive State Signal Updates ─────────────────────────────────────
say "[1/5] Testing Reactive State Signal Engine..."
counter_state = ui_state_new(0)
assert_eq(ui_state_get(counter_state), 0, "Initial state value is 0")
assert_eq(ui_state_is_dirty(counter_state), 0, "Initial state is clean")

ui_state_set(counter_state, 42)
assert_eq(ui_state_get(counter_state), 42, "Updated state value is 42")
assert_eq(ui_state_is_dirty(counter_state), 1, "Modified state marked dirty")

ui_state_clean(counter_state)
assert_eq(ui_state_is_dirty(counter_state), 0, "Cleaned state is not dirty")

// ── Test 2: Declarative Component Tree Construction ───────────────────────────
say "[2/5] Testing Declarative Component Tree Construction..."
btn1 = ui_button("btn_inc", "Increment", 255, 16777215, 101)
list_set(btn1, 15, counter_state) // bind counter state to button

txt1 = ui_text("txt_val", "Count: 42", 16777215)
inp1 = ui_input("inp_name", "Enter your name...", 0)

col_children = list()
push(col_children, txt1)
push(col_children, btn1)
push(col_children, inp1)

main_col = ui_column("main_column", 10, col_children)

root_children = list()
push(root_children, main_col)
app_root = ui_container("app_window", 1118481, 16, 0, root_children) // 0x111111 dark bg

assert_eq(get(app_root, 0), UI_CONTAINER, "Root widget is UI_CONTAINER")
assert_eq(len(get(app_root, 11)), 1, "Root has 1 child (Column)")
assert_eq(len(get(main_col, 11)), 3, "Column has 3 children (Text, Button, Input)")

// ── Test 3: Flexbox Geometry & Layout Resolution ──────────────────────────────
say "[3/5] Testing Geometry & Flexbox Layout Solver..."
// Window size: 800x600, origin: (0, 0)
ui_layout_resolve(app_root, 0, 0, 800, 600)

assert_eq(get(app_root, 2), 0, "Root X position is 0")
assert_eq(get(app_root, 3), 0, "Root Y position is 0")
assert_eq(get(app_root, 4), 800, "Root resolved width is 800")
assert_eq(get(app_root, 5), 600, "Root resolved height is 600")

// Column inside Container (padding 16)
col_x = get(main_col, 2)
col_y = get(main_col, 3)
assert_eq(col_x, 16, "Main column X matches container padding (16)")
assert_eq(col_y, 16, "Main column Y matches container padding (16)")

// Check child vertical stacking
b_y = get(btn1, 3)
t_y = get(txt1, 3)
t_h = get(txt1, 5)
pad = get(main_col, 6) // gap = 10
expected_b_y = t_y + t_h + pad
assert_eq(b_y, expected_b_y, "Button Y stacked below Text with gap (" + str(b_y) + ")")

// ── Test 4: 2D Framebuffer Memory Rasterization ────────────────────────────────
say "[4/5] Testing 2D Framebuffer Rasterization (32-bit RGBA)..."
buf_w = 400
buf_h = 300
buf_size = buf_w * buf_h * 4
framebuffer = malloc(buf_size)
mem_fill(framebuffer, 0, buf_size)

// Render resolved tree into framebuffer
ui_render_to_buffer(app_root, framebuffer, buf_w, buf_h)

// Check background pixel at (5, 5) -> should be 0x111111 (R=17, G=17, B=17, A=255)
bg_off = ((5 * buf_w) + 5) * 4
r0 = mem_byte_read(framebuffer, bg_off)
g0 = mem_byte_read(framebuffer, bg_off + 1)
b0 = mem_byte_read(framebuffer, bg_off + 2)
a0 = mem_byte_read(framebuffer, bg_off + 3)
assert_eq(r0, 17, "Framebuffer Pixel (5, 5) R channel matches bg_color (17)")
assert_eq(g0, 17, "Framebuffer Pixel (5, 5) G channel matches bg_color (17)")
assert_eq(b0, 17, "Framebuffer Pixel (5, 5) B channel matches bg_color (17)")
assert_eq(a0, 255, "Framebuffer Pixel (5, 5) Alpha channel is opaque (255)")

free(framebuffer, buf_size)

// ── Test 5: Hit-Testing & Event Dispatching ───────────────────────────────────
say "[5/5] Testing Hit-Testing & Event Dispatching..."
btn_x = get(btn1, 2)
btn_y = get(btn1, 3)
click_x = btn_x + 5
click_y = btn_y + 5

// Simulate mouse down inside button
act = ui_dispatch_event(app_root, UI_EVENT_MOUSE_DOWN, click_x, click_y, 0)
assert_eq(act, 101, "Event dispatch triggered button action 101")
assert_eq(ui_state_get(counter_state), 43, "Button click mutated bound counter state to 43")

// Simulate mouse click outside
miss_act = ui_dispatch_event(app_root, UI_EVENT_MOUSE_DOWN, 700, 500, 0)
assert_eq(miss_act, 0, "Click outside triggered no action")

say "========================================================"
say "PASS: Lipi Declarative Reactive UI Engine Verified 100%!"
say "========================================================"
