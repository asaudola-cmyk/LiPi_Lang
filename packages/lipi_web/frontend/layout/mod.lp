@! ============================================================================
@! LIPI WEB FRONTEND ENGINE — LAYOUT SUBSYSTEM ROOT AGGREGATOR
@! Module: universe/web/frontend/layout/mod.lp
@! 100% Pure Lipi Architecture — Zero External Dependencies
@! Features:
@! - High-level layout engine coordinator
@! - Unified GPU compute & CPU Flexbox layout dispatch API
@! - Aggregates layout_types, gpu_layout, and flexbox_solver
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/web/frontend/layout/layout_types"
import "universe/web/frontend/layout/flexbox_solver"
import "universe/web/frontend/layout/gpu_layout"

@! ============================================================================
@! 1. UNIFIED FRONTEND LAYOUT API
@! ============================================================================

@fn frontend_layout_engine_new(is_gpu_active, viewport_w, viewport_h, scale_factor)
  return gpu_layout_engine_new(is_gpu_active, viewport_w, viewport_h, scale_factor)
@end

@fn frontend_layout_solve_tree(root_node, viewport_w, viewport_h)
  return flexbox_solve_tree(root_node, viewport_w, viewport_h)
@end

@fn frontend_layout_compute_dispatch(engine, root_node)
  return gpu_layout_compute_tree(engine, root_node)
@end

@fn frontend_layout_get_results(engine)
  return gpu_layout_readback_results(engine)
@end

@fn frontend_layout_get_dirty_bounds(engine)
  return gpu_layout_get_dirty_bounds(engine)
@end

@fn frontend_layout_mark_dirty(engine, node_id)
  return gpu_layout_mark_dirty(engine, node_id)
@end

@fn frontend_layout_mark_all_clean(engine)
  return gpu_layout_mark_all_clean(engine)
@end

@fn frontend_layout_update_node_size(engine, node_id, new_w, new_h)
  return gpu_layout_update_node_size(engine, node_id, new_w, new_h)
@end

@fn frontend_layout_set_gpu_active(engine, active_bool)
  return gpu_layout_set_gpu_active(engine, active_bool)
@end
