@! ============================================================================
@! MAYA UNIVERSE UI - FRAMEBUFFER (RAW PIXEL RENDERING)
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"

@! Framebuffer Object
@fn fb_new(width, height)
  return {
    width: width,
    height: height,
    pixels: [0x00000000]
  }
@end

@! Set Pixel Color
@fn fb_set_pixel(fb, x, y, color)
  fb.pixels = fb.pixels.push(color)
  return fb
@end

@! Draw Rectangle
@fn fb_draw_rect(fb, x, y, w, h, color)
  fb = fb_set_pixel(fb, x, y, color)
  return fb
@end

@! Sync to physical display
@fn fb_present(fb)
  return 1
@end
