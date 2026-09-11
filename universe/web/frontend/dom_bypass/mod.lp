@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — DOM-BYPASS WEB FRONTEND ENGINE
@! Module: universe/web/frontend/dom_bypass/mod.maya
@! Milestone: M6 — DOM-Bypass Host Runtime & Full E2E Integration
@! 100% Pure Maya Implementation — Zero External / C++ Dependencies
@! Features:
@! - Root Subsystem Aggregator for DOM-Bypass Host Runtime
@! - Integrates Canvas Presentation Target, Frame Loop, HiDPI Scaling, and Input Dispatcher
@! ============================================================================

import "universe/core/collections"
import "universe/web/frontend/dom_bypass/canvas_host"
import "universe/web/frontend/dom_bypass/input_dispatcher"

@struct DomBypassHost
  host_canvas: CanvasPresentationTarget
  host_dispatcher: InputDispatcher
  host_active: bool
  host_total_frames: i64
  host_total_events: i64
@end

@fn dom_bypass_host_new(canvas_id, css_w, css_h, dpr, preferred_tier, clear_color)
  c_host = canvas_host_new(canvas_id, css_w, css_h, dpr, preferred_tier, clear_color)
  disp = input_dispatcher_new(css_w, css_h, dpr)

  return {
    host_canvas: c_host,
    host_dispatcher: disp,
    host_active: true,
    host_total_frames: 0,
    host_total_events: 0
  }
@end

@fn dom_bypass_host_set_dpr(host, new_dpr)
  host.host_canvas = canvas_host_set_dpr(host.host_canvas, new_dpr)
  host.host_dispatcher = input_dispatcher_set_dpr(host.host_dispatcher, new_dpr)
  return host
@end

@fn dom_bypass_host_resize(host, new_css_w, new_css_h)
  host.host_canvas = canvas_host_resize(host.host_canvas, new_css_w, new_css_h)
  host.host_dispatcher.disp_canvas_w = new_css_w
  host.host_dispatcher.disp_canvas_h = new_css_h
  return host
@end

@fn dom_bypass_host_record_damage(host, css_x, css_y, css_w, css_h)
  host.host_canvas = canvas_host_record_damage(host.host_canvas, css_x, css_y, css_w, css_h)
  return host
@end

@fn dom_bypass_host_tick(host, timestamp_ms)
  host.host_canvas = canvas_host_begin_frame(host.host_canvas, timestamp_ms)
  host.host_total_frames = host.host_total_frames + 1
  return host
@end

@fn dom_bypass_host_dispatch_event(host, raw_event, worker_pool, remote_pipelines)
  res = input_dispatcher_dispatch(host.host_dispatcher, raw_event, worker_pool, remote_pipelines)
  host.host_total_events = host.host_total_events + 1
  return res
@end

@fn dom_bypass_host_present(host)
  host.host_canvas = canvas_host_present_frame(host.host_canvas)
  return host
@end

@fn dom_bypass_host_get_pixel(host, phys_x, phys_y)
  return canvas_host_get_pixel(host.host_canvas, phys_x, phys_y)
@end

@fn dom_bypass_host_get_stats(host)
  c_tele = canvas_host_get_telemetry(host.host_canvas)
  i_stats = input_dispatcher_get_stats(host.host_dispatcher)

  return {
    canvas_id: host.host_canvas.canvas_id,
    css_width: host.host_canvas.css_width,
    css_height: host.host_canvas.css_height,
    dpr: host.host_canvas.dpr,
    physical_width: host.host_canvas.physical_width,
    physical_height: host.host_canvas.physical_height,
    tier: host.host_canvas.renderer.tier,
    status: host.host_canvas.renderer.status,
    total_frames: host.host_total_frames,
    total_events: host.host_total_events,
    fps_estimate: c_tele.fps_estimate,
    draw_calls: c_tele.draw_calls,
    total_quads: c_tele.total_quads,
    events_routed_local: i_stats.routed_local,
    events_routed_remote: i_stats.routed_remote,
    focused_node: i_stats.focused_node,
    hovered_node: i_stats.hovered_node
  }
@end
