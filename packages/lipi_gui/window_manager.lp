// ==============================================================================
// 🖥️ LIPI SOVEREIGN TILING WINDOW MANAGER & COMPOSITOR (universe/gui/window_manager.lp)
// Standard: Direct Linear Framebuffer (1024x768) Auto-Tiling & Damage Compositor
// 100% Pure Lipi Implementation — Zero X11 | Zero Wayland | Zero libmwm
// ==============================================================================
//
// WHY: A true operating system desktop requires managing multiple applications
// concurrently without manual window overlapping chaos. The Lipi Tiling Window
// Manager provides automatic i3/bspwm-style screen splitting, z-order focus
// management, and damage-tracked (dirty rect) composition on bare-metal silicon.
// ==============================================================================

import "universe/gui/framebuffer"
import "universe/core/collections"
import "universe/core/string"

// ── 1. Window & Window Manager Data Structures ────────────────────────────────
@struct TilingWindow
  id: i64
  title: string
  x: i64
  y: i64
  w: i64
  h: i64
  is_focused: i64
  is_visible: i64
  dirty: i64
@end

@struct TilingWindowManager
  fb: LipiFramebuffer
  windows: array
  active_focus_id: i64
  layout_mode: i64       // 1 = Horizontal Split, 2 = Vertical Split, 3 = Floating
  screen_w: i64
  screen_h: i64
  status_bar_h: i64
  damage_count: i64
@end

// ── 2. Window Manager Initialization ──────────────────────────────────────────
@fn wm_init(fb, screen_w: i64, screen_h: i64)
  return {
    fb: fb,
    windows: [],
    active_focus_id: 0 - 1,
    layout_mode: 1, // Default Horizontal Split
    screen_w: screen_w,
    screen_h: screen_h,
    status_bar_h: 24,
    damage_count: 0
  }
@end

// ── 3. Window Creation & Registration ─────────────────────────────────────────
@fn wm_create_window(wm, id: i64, title: string)
  win = {
    id: id,
    title: title,
    x: 0,
    y: wm.status_bar_h,
    w: wm.screen_w,
    h: wm.screen_h - wm.status_bar_h,
    is_focused: 0,
    is_visible: 1,
    dirty: 1
  }

  wm.windows = wm.windows.push(win)
  wm.active_focus_id = id
  wm = wm_recalculate_tiling(wm)
  return wm
@end

// ── 4. Automatic Screen Splitting & Tiling Calculations ───────────────────────
// WHY: Divides usable screen area equally among visible windows.
@fn wm_recalculate_tiling(wm)
  num_wins = wm.windows.len()
  @if num_wins <= 0 return wm @end

  avail_y = wm.status_bar_h
  avail_h = wm.screen_h - wm.status_bar_h

  @if wm.layout_mode == 1
    // Horizontal Split: Divide width across windows
    col_w = wm.screen_w / num_wins
    i = 0
    @while i < num_wins
      win = wm.windows[i]
      win.x = i * col_w
      win.y = avail_y
      win.w = col_w
      win.h = avail_h
      win.dirty = 1
      wm.windows = list_set(wm.windows, i, win)
      i = i + 1
    @end
  @elif wm.layout_mode == 2
    // Vertical Split: Divide height across windows
    row_h = avail_h / num_wins
    i = 0
    @while i < num_wins
      win = wm.windows[i]
      win.x = 0
      win.y = avail_y + (i * row_h)
      win.w = wm.screen_w
      win.h = row_h
      win.dirty = 1
      wm.windows = list_set(wm.windows, i, win)
      i = i + 1
    @end
  @end

  return wm
@end

// ── 5. Focus Switching & Damage Marking ───────────────────────────────────────
@fn wm_focus_window(wm, target_id: i64)
  wm.active_focus_id = target_id
  i = 0
  n = wm.windows.len()
  @while i < n
    win = wm.windows[i]
    @if win.id == target_id
      win.is_focused = 1
      win.dirty = 1
    @else
      win.is_focused = 0
      win.dirty = 1
    @end
    wm.windows = list_set(wm.windows, i, win)
    i = i + 1
  @end
  return wm
@end

// ── 6. Damage-Tracked Multi-Window Composition ────────────────────────────────
// WHY: Only redraws windows marked dirty == 1, saving thousands of frame memory blits.
@fn wm_composite_frame(wm)
  rendered_count = 0
  i = 0
  n = wm.windows.len()
  @while i < n
    win = wm.windows[i]
    @if win.dirty == 1 && win.is_visible == 1
      // Draw window border and chrome on framebuffer
      fb_window_create(wm.fb, win.x, win.y, win.w, win.h, win.title)

      // Reset damage status
      win.dirty = 0
      wm.windows = list_set(wm.windows, i, win)
      rendered_count = rendered_count + 1
      wm.damage_count = wm.damage_count + 1
    @end
    i = i + 1
  @end

  // Tear-free page flip to scanout
  fb_flip(wm.fb)
  return rendered_count
@end
