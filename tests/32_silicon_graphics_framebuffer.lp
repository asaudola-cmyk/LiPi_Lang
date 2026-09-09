// Test 32: Graphics Framebuffer — Lipi 2.0 Global Standard
// Pixel operations on a virtual framebuffer

fn rgb_pack r g b
    return r * 65536 + g * 256 + b

fn rgb_red packed   = packed / 65536
fn rgb_green packed = packed / 256 % 256
fn rgb_blue packed  = packed % 256

fn blend_alpha fg bg alpha
    // Simple linear blend: out = fg*a + bg*(1-a) / 255
    return fg * alpha / 255 + bg * (255 - alpha) / 255

fn plot_pixel x y color width
    offset = y * width + x
    return offset

fn fill_rect x y w h color
    pixels = w * h
    say "Filling " + pixels + " pixels with color " + color
    return pixels

// Framebuffer 320x240
WIDTH  = 320
HEIGHT = 240

say "=== Framebuffer ==="
red   = rgb_pack 255 0 0
green = rgb_pack 0 255 0
blue  = rgb_pack 0 0 255
white = rgb_pack 255 255 255

say red
say green
say blue

// Verify RGB extraction
say rgb_red red
say rgb_green green
say rgb_blue blue

// Draw rectangles
fill_rect 0 0 320 240 blue
fill_rect 10 10 100 50 red
fill_rect 50 50 200 100 white

// Blend test
blended = blend_alpha 255 0 128
say blended

say "PASS: Test 32 Graphics Framebuffer"
