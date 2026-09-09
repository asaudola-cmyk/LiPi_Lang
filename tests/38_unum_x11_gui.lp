// Test 38: X11 GUI — Lipi 2.0 Global Standard

fn x11_connect display
    say "X11: connecting to " + display
    return 5

fn x11_window fd w h title
    say "Window: " + w + "x" + h + " \"" + title + "\""
    return 1

fn x11_draw_rect fd x y w h color
    say "Rect: " + x + "," + y + " " + w + "x" + h + " color=" + color
    return 1

fn x11_draw_text fd x y text
    say "Text: [" + x + "," + y + "] " + text
    return 1

fn x11_flush fd
    say "X11: flush"
    return 1

say "=== X11 GUI ==="
fd = x11_connect(":0")
if fd > 0
    say "Connected"

x11_window(fd, 800, 600, "Lipi GUI")
x11_draw_rect(fd, 0, 0, 800, 600, 0)
x11_draw_rect(fd, 10, 10, 200, 50, 16711680)
x11_draw_text(fd, 20, 35, "Hello Lipi!")
x11_flush(fd)

// Event loop
for event in 1..4
    say "Event: " + event

say "PASS: Test 38 X11 GUI"
