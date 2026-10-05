// Test fbdev direct
include "universe/gui/fbdev.lp"

fn main
    say "Testing fbdev..."
    fb = fbdev_open("/dev/fb0")
    if fb == 0
        say "FAIL: fbdev_open returned 0"
        exit(1)
    say "fbdev opened successfully"
    w = get(fb, 1)
    h = get(fb, 2)
    say "Width: " + str(w) + ", Height: " + str(h)
    
    // Draw pixel
    col = 16711680 // Red (0x00FF0000)
    fbdev_draw_pixel(fb, 10, 10, col)
    r_col = fbdev_read_pixel(fb, 10, 10)
    if r_col != col
        say "FAIL: Pixel readback mismatch! Got " + str(r_col)
        exit(1)
    say "Pixel draw/read passed!"
    
    // Fill rect
    rect_count = fbdev_fill_rect(fb, 20, 20, 100, 50, col)
    if rect_count != 5000
        say "FAIL: Fill rect count mismatch! Got " + str(rect_count)
        exit(1)
    say "Fill rect passed: " + str(rect_count) + " pixels"
    
    // Flip
    ok_flip = fbdev_flip(fb)
    if ok_flip != 1
        say "FAIL: fbdev_flip returned " + str(ok_flip)
        exit(1)
    say "Page flip passed!"
    
    // Close
    fbdev_close(fb)
    say "fbdev closed cleanly!"
    say "ALL FBDEV TESTS PASSED"

main()
