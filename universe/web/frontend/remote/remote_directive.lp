@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — DOM-BYPASS WEB FRONTEND ENGINE
@! Module: universe/web/frontend/remote/remote_directive.maya
@! Milestone: M5 — Adaptive WebRTC Hybrid Rendering
@! 100% Pure Maya Architecture — Zero External Dependencies
@! Features: AST Parser & Metadata Tagging for @remote Directive
@! Component Partitioning (Local WASM UI vs Remote Streaming Components)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ============================================================================
@! 1. DATA STRUCTURES & AST METADATA
@! ============================================================================

@struct RemoteComponentMeta
  name: string
  kind: string                 @! "struct", "fn", "component", "canvas_viewport"
  is_remote: bool
  fps: i64                     @! Target framerate (default: 60)
  width: i64                   @! Render buffer width (default: 1280)
  height: i64                  @! Render buffer height (default: 720)
  codec: string                @! "H264", "VP8", "VP9", "AV1"
  bitrate_kbps: i64            @! Target streaming bitrate in kbps
  input_channel_enabled: bool  @! Bidirectional DataChannel for user events
  transport: string            @! "webrtc", "webtransport"
  render_pipeline: string      @! "raytracer", "compute_3d", "rasterizer"
  priority: i64                @! Scheduling priority (1 to 10)
  session_affinity: string     @! "sticky", "round_robin", "gpu_exclusive"
  raw_directive: string
@end

@struct LocalComponentMeta
  name: string
  kind: string
  is_remote: bool
  layout_type: string          @! "flexbox", "canvas_subrect", "grid"
  wasm_export: bool
@end

@struct ComponentPartitionResult
  total_components: i64
  remote_count: i64
  local_count: i64
  remote_components: array
  local_components: array
  proxy_stubs: array
  remote_ratio_pct: i64
  summary: string
@end

@! ============================================================================
@! 2. DIRECTIVE PARAMETER PARSER
@! ============================================================================

@fn remote_extract_directive_params(param_str)
  @! Default values
  fps = 60
  width = 1280
  height = 720
  codec = "H264"
  bitrate = 4000
  input_channel = true
  transport = "webrtc"
  pipeline = "raytracer"
  priority = 5
  affinity = "sticky"

  @if str_len(param_str) == 0
    return {
      fps: fps,
      width: width,
      height: height,
      codec: codec,
      bitrate: bitrate,
      input_channel: input_channel,
      transport: transport,
      pipeline: pipeline,
      priority: priority,
      affinity: affinity
    }
  @end

  @! Split parameters by comma
  parts = string_split(param_str, ",")
  i = 0
  @while i < parts.len()
    part = str_trim(parts[i])
    @if contains(part, "=") == 1
      kv = string_split(part, "=")
      @if kv.len() >= 2
        key = str_trim(kv[0])
        val = str_trim(kv[1])
        
        @! Strip quotes if present
        @if starts_with(val, "\"") == 1 && ends_with(val, "\"") == 1
          val = str_substr(val, 1, str_len(val) - 1)
        @end

        @if key == "fps"
          fps = str_to_int(val)
        @elif key == "width" || key == "w"
          width = str_to_int(val)
        @elif key == "height" || key == "h"
          height = str_to_int(val)
        @elif key == "codec"
          codec = str_to_upper(val)
        @elif key == "bitrate" || key == "bitrate_kbps"
          bitrate = str_to_int(val)
        @elif key == "input" || key == "input_channel"
          @if val == "false" || val == "0"
            input_channel = false
          @else
            input_channel = true
          @end
        @elif key == "transport"
          transport = str_to_lower(val)
        @elif key == "pipeline"
          pipeline = str_to_lower(val)
        @elif key == "priority"
          priority = str_to_int(val)
        @elif key == "affinity"
          affinity = str_to_lower(val)
        @end
      @end
    @end
    i = i + 1
  @end

  return {
    fps: fps,
    width: width,
    height: height,
    codec: codec,
    bitrate: bitrate,
    input_channel: input_channel,
    transport: transport,
    pipeline: pipeline,
    priority: priority,
    affinity: affinity
  }
@end

@! ============================================================================
@! 3. AST PARSER & SOURCE CLASSIFIER
@! ============================================================================

@fn remote_classify_source(source_text)
  lines = string_split(source_text, "\n")
  remote_list = []
  local_list = []
  proxy_stubs = []
  
  pending_remote = false
  pending_directive_str = ""
  
  i = 0
  @while i < lines.len()
    raw_line = lines[i]
    line = str_trim(raw_line)
    
    @! Check for @remote annotation
    @if starts_with(line, "@remote") == 1
      pending_remote = true
      pending_directive_str = line
    @else
      @! Check for declaration keywords
      kind = ""
      name = ""
      
      @if starts_with(line, "@struct") == 1
        kind = "struct"
        tokens = string_split(line, " ")
        @if tokens.len() >= 2
          name = str_trim(tokens[1])
        @end
      @elif starts_with(line, "@fn") == 1
        kind = "fn"
        tokens = string_split(line, " ")
        @if tokens.len() >= 2
          fn_sig = str_trim(tokens[1])
          @if contains(fn_sig, "(") == 1
            sig_parts = string_split(fn_sig, "(")
            name = str_trim(sig_parts[0])
          @else
            name = fn_sig
          @end
        @end
      @elif starts_with(line, "@component") == 1
        kind = "component"
        tokens = string_split(line, " ")
        @if tokens.len() >= 2
          name = str_trim(tokens[1])
        @end
      @end

      @if str_len(name) > 0
        @if pending_remote == true
          @! Parse parameters from @remote(...)
          param_str = ""
          @if contains(pending_directive_str, "(") == 1 && contains(pending_directive_str, ")") == 1
            p_start = str_index_of(pending_directive_str, "(") + 1
            p_end = str_index_of(pending_directive_str, ")")
            @if p_end > p_start
              param_str = str_substr(pending_directive_str, p_start, p_end)
            @end
          @end

          parsed_params = remote_extract_directive_params(param_str)

          meta = {
            name: name,
            kind: kind,
            is_remote: true,
            fps: parsed_params.fps,
            width: parsed_params.width,
            height: parsed_params.height,
            codec: parsed_params.codec,
            bitrate_kbps: parsed_params.bitrate,
            input_channel_enabled: parsed_params.input_channel,
            transport: parsed_params.transport,
            render_pipeline: parsed_params.pipeline,
            priority: parsed_params.priority,
            session_affinity: parsed_params.affinity,
            raw_directive: pending_directive_str
          }
          remote_list = remote_list.push(meta)
          
          @! Generate WASM proxy stub
          stub = remote_generate_wasm_proxy_stub(meta)
          proxy_stubs = proxy_stubs.push(stub)
          
          pending_remote = false
          pending_directive_str = ""
        @else
          local_meta = {
            name: name,
            kind: kind,
            is_remote: false,
            layout_type: "flexbox",
            wasm_export: true
          }
          local_list = local_list.push(local_meta)
        @end
      @end
    @end

    i = i + 1
  @end

  total = remote_list.len() + local_list.len()
  ratio = 0
  @if total > 0
    ratio = (remote_list.len() * 100) / total
  @end

  summary_str = "Total: " + total.to_str() + " (Local: " + local_list.len().to_str() + ", Remote: " + remote_list.len().to_str() + ", " + ratio.to_str() + "% remote)"

  return {
    total_components: total,
    remote_count: remote_list.len(),
    local_count: local_list.len(),
    remote_components: remote_list,
    local_components: local_list,
    proxy_stubs: proxy_stubs,
    remote_ratio_pct: ratio,
    summary: summary_str
  }
@end

@! ============================================================================
@! 4. QUERY HELPERS
@! ============================================================================

@fn remote_is_component_remote(partition_res, component_name)
  i = 0
  @while i < partition_res.remote_components.len()
    meta = partition_res.remote_components[i]
    @if meta.name == component_name
      return true
    @end
    i = i + 1
  @end
  return false
@end

@fn remote_get_component_meta(partition_res, component_name)
  i = 0
  @while i < partition_res.remote_components.len()
    meta = partition_res.remote_components[i]
    @if meta.name == component_name
      return meta
    @end
    i = i + 1
  @end
  
  @! Return empty meta
  return {
    name: component_name,
    kind: "none",
    is_remote: false,
    fps: 0,
    width: 0,
    height: 0,
    codec: "NONE",
    bitrate_kbps: 0,
    input_channel_enabled: false,
    transport: "none",
    render_pipeline: "none",
    priority: 0,
    session_affinity: "none",
    raw_directive: ""
  }
@end

@! ============================================================================
@! 5. WASM PROXY STUB GENERATOR
@! ============================================================================

@fn remote_generate_wasm_proxy_stub(meta)
  stub = "// WASM WebRTC Proxy Stub for @" + meta.name + "\n"
  stub = stub + "@struct " + meta.name + "WasmProxy\n"
  stub : stub + "  component_id: string,\n"
  stub : stub + "  session_id: string,\n"
  stub : stub + "  canvas_x: i64,\n"
  stub : stub + "  canvas_y: i64,\n"
  stub : stub + "  canvas_w: i64,\n"
  stub : stub + "  canvas_h: i64,\n"
  stub : stub + "  is_streaming: bool,\n"
  stub : stub + "  webrtc_client_ptr: i64,\n"
  stub : stub + "  video_blitter_ptr: i64\n"
  stub : stub + "
@end\n"
  
  stub = stub + "@fn " + meta.name + "_init_proxy(comp_id, x, y, w, h)\n"
  stub = stub + "  return " + meta.name + "{\n"
  stub = stub + "    component_id: comp_id,\n"
  stub = stub + "    session_id: \"\",\n"
  stub = stub + "    canvas_x: x,\n"
  stub = stub + "    canvas_y: y,\n"
  stub = stub + "    canvas_w: w,\n"
  stub = stub + "    canvas_h: h,\n"
  stub = stub + "    is_streaming: false,\n"
  stub = stub + "    webrtc_client_ptr: 0,\n"
  stub = stub + "    video_blitter_ptr: 0\n"
  stub = stub + "  }\n"
  stub = stub + "@end\n"
  
  return stub
@end
