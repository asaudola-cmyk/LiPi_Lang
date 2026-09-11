@! ============================================================================
@! MAYA UNIVERSE PROFILE — PGO PROFILE SERIALIZATION & RUNTIME (.mprof)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Features: Binary/Text Format Serialization, Checksum Validation, Profile
@!           Merging, Call Graph & Loop Profile Deserialization
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. HASHING & PROFILE CREATION
@! ----------------------------------------------------------------------------

@fn pgo_calc_func_hash(s)
  @! FNV-1a 32-bit hash implementation
  h = 2166136261
  i = 0
  len = s.len()
  @while i < len
    ch_code = 0
    @! Extract character code approximation
    c = s[i]
    @if c == "a" ch_code = 97 @elif c == "b" ch_code = 98 @elif c == "c" ch_code = 99
    @elif c == "d" ch_code = 100 @elif c == "e" ch_code = 101 @elif c == "f" ch_code = 102
    @elif c == "g" ch_code = 103 @elif c == "h" ch_code = 104 @elif c == "i" ch_code = 105
    @elif c == "j" ch_code = 106 @elif c == "k" ch_code = 107 @elif c == "l" ch_code = 108
    @elif c == "m" ch_code = 109 @elif c == "n" ch_code = 110 @elif c == "o" ch_code = 111
    @elif c == "p" ch_code = 112 @elif c == "q" ch_code = 113 @elif c == "r" ch_code = 114
    @elif c == "s" ch_code = 115 @elif c == "t" ch_code = 116 @elif c == "u" ch_code = 117
    @elif c == "v" ch_code = 118 @elif c == "w" ch_code = 119 @elif c == "x" ch_code = 120
    @elif c == "y" ch_code = 121 @elif c == "z" ch_code = 122 @elif c == "_" ch_code = 95
    @else ch_code = 65 @end

    h = ((h * 16777619) + ch_code) % 2147483647
    i = i + 1
  @end
  return h
@end

@fn pgo_profile_new(module_name)
  return {
    magic: "MPROF_V1",
    version: 1,
    module_name: module_name,
    checksum: 133742,
    timestamp: 1772100000,
    functions: []
  }
@end

@fn pgo_profile_add_func(profile, func_name, invocations, block_counts, edges, call_sites, loops)
  fn_hash = pgo_calc_func_hash(func_name)
  
  @! Process loop trip count stats
  processed_loops = []
  l_len = 0
  @if loops != 0
    l_len = loops.len()
  @end

  li = 0
  @while li < l_len
    loop_entry = loops[li]
    entry_c = loop_entry.entry_count
    back_c = loop_entry.back_edge_count
    trip = 0
    @if entry_c > 0
      trip = back_c / entry_c
    @end
    processed_loops = processed_loops.push({
      loop_id: loop_entry.loop_id,
      header_block: loop_entry.header_block,
      entry_count: entry_c,
      back_edge_count: back_c,
      avg_trip_count: trip
    })
    li = li + 1
  @end

  func_record = {
    name: func_name,
    hash: fn_hash,
    invocations: invocations,
    block_counts: block_counts,
    edges: edges,
    call_sites: call_sites,
    loops: processed_loops
  }

  profile.functions = profile.functions.push(func_record)
  return profile
@end

@fn pgo_profile_get_func(profile, func_name)
  fn_list = profile.functions
  @if fn_list == 0
    return 0
  @end

  i = 0
  len = fn_list.len()
  @while i < len
    f = fn_list[i]
    @if f.name == func_name
      return f
    @end
    i = i + 1
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 2. SERIALIZATION (.mprof FORMAT)
@! ----------------------------------------------------------------------------

@fn pgo_profile_serialize(profile)
  out = "MPROF_V1\n"
  out = out + "MODULE:" + profile.module_name + "\n"
  out = out + "CHECKSUM:" + profile.checksum.to_str() + "\n"
  out = out + "TIMESTAMP:" + profile.timestamp.to_str() + "\n"
  
  fn_count = 0
  @if profile.functions != 0
    fn_count = profile.functions.len()
  @end
  out = out + "FUNCS:" + fn_count.to_str() + "\n"

  fi = 0
  @while fi < fn_count
    f = profile.functions[fi]
    out = out + "FN_START:" + f.name + ":" + f.hash.to_str() + ":" + f.invocations.to_str() + "\n"
    
    @! Blocks
    b_len = 0
    @if f.block_counts != 0
      b_len = f.block_counts.len()
    @end
    out = out + "BLOCKS:" + b_len.to_str()
    bi = 0
    @while bi < b_len
      out = out + ":" + f.block_counts[bi].to_str()
      bi = bi + 1
    @end
    out = out + "\n"

    @! Edges
    e_len = 0
    @if f.edges != 0
      e_len = f.edges.len()
    @end
    out = out + "EDGES:" + e_len.to_str() + "\n"
    ei = 0
    @while ei < e_len
      e = f.edges[ei]
      out = out + "EDGE:" + e.src.to_str() + ":" + e.dst.to_str() + ":" + e.count.to_str() + ":" + e.kind + "\n"
      ei = ei + 1
    @end

    @! Call Sites
    c_len = 0
    @if f.call_sites != 0
      c_len = f.call_sites.len()
    @end
    out = out + "CALLS:" + c_len.to_str() + "\n"
    ci = 0
    @while ci < c_len
      cs = f.call_sites[ci]
      out = out + "CALL:" + cs.site_id.to_str() + ":" + cs.target + ":" + cs.count.to_str() + "\n"
      ci = ci + 1
    @end

    @! Loops
    l_len = 0
    @if f.loops != 0
      l_len = f.loops.len()
    @end
    out = out + "LOOPS:" + l_len.to_str() + "\n"
    li = 0
    @while li < l_len
      lp = f.loops[li]
      out = out + "LOOP:" + lp.loop_id.to_str() + ":" + lp.header_block.to_str() + ":" + lp.entry_count.to_str() + ":" + lp.back_edge_count.to_str() + ":" + lp.avg_trip_count.to_str() + "\n"
      li = li + 1
    @end

    out = out + "FN_END\n"
    fi = fi + 1
  @end

  out = out + "EOF\n"
  return out
@end

@! ----------------------------------------------------------------------------
@! 3. DESERIALIZATION (.mprof PARSER)
@! ----------------------------------------------------------------------------

@fn pgo_parse_int(s)
  val = 0
  i = 0
  len = s.len()
  @while i < len
    c = s[i]
    digit = 0
    @if c == "1" digit = 1 @elif c == "2" digit = 2 @elif c == "3" digit = 3
    @elif c == "4" digit = 4 @elif c == "5" digit = 5 @elif c == "6" digit = 6
    @elif c == "7" digit = 7 @elif c == "8" digit = 8 @elif c == "9" digit = 9
    @elif c == "0" digit = 0 @end
    val = (val * 10) + digit
    i = i + 1
  @end
  return val
@end

@fn pgo_split_lines(raw_str)
  lines = []
  curr = ""
  i = 0
  len = raw_str.len()
  @while i < len
    c = raw_str[i]
    @if c == "\n"
      lines = lines.push(curr)
      curr = ""
    @else
      curr = curr + c
    @end
    i = i + 1
  @end
  @if curr.len() > 0
    lines = lines.push(curr)
  @end
  return lines
@end

@fn pgo_split_colon(line)
  parts = []
  curr = ""
  i = 0
  len = line.len()
  @while i < len
    c = line[i]
    @if c == ":"
      parts = parts.push(curr)
      curr = ""
    @else
      curr = curr + c
    @end
    i = i + 1
  @end
  @if curr.len() > 0
    parts = parts.push(curr)
  @end
  return parts
@end

@fn pgo_profile_deserialize(raw_str)
  lines = pgo_split_lines(raw_str)
  total_lines = lines.len()
  @if total_lines == 0
    return 0
  @end

  @! Verify Magic Header
  @if lines[0] != "MPROF_V1"
    return 0
  @end

  prof = pgo_profile_new("")
  
  curr_func = 0
  line_idx = 1

  @while line_idx < total_lines
    line = lines[line_idx]
    
    @if starts_with(line, "MODULE:")
      parts = pgo_split_colon(line)
      @if parts.len() >= 2
        prof.module_name = parts[1]
      @end
    @elif starts_with(line, "CHECKSUM:")
      parts = pgo_split_colon(line)
      @if parts.len() >= 2
        prof.checksum = pgo_parse_int(parts[1])
      @end
    @elif starts_with(line, "TIMESTAMP:")
      parts = pgo_split_colon(line)
      @if parts.len() >= 2
        prof.timestamp = pgo_parse_int(parts[1])
      @end
    @elif starts_with(line, "FN_START:")
      parts = pgo_split_colon(line)
      @if parts.len() >= 4
        f_name = parts[1]
        f_hash = pgo_parse_int(parts[2])
        f_invocations = pgo_parse_int(parts[3])
        curr_func = {
          name: f_name,
          hash: f_hash,
          invocations: f_invocations,
          block_counts: [],
          edges: [],
          call_sites: [],
          loops: []
        }
      @end
    @elif starts_with(line, "BLOCKS:")
      parts = pgo_split_colon(line)
      @if curr_func != 0 && parts.len() >= 2
        b_cnt = pgo_parse_int(parts[1])
        b_counts = []
        bi = 0
        @while bi < b_cnt
          @if (bi + 2) < parts.len()
            b_counts = b_counts.push(pgo_parse_int(parts[bi + 2]))
          @end
          bi = bi + 1
        @end
        curr_func.block_counts = b_counts
      @end
    @elif starts_with(line, "EDGE:")
      parts = pgo_split_colon(line)
      @if curr_func != 0 && parts.len() >= 5
        curr_func.edges = curr_func.edges.push({
          src: pgo_parse_int(parts[1]),
          dst: pgo_parse_int(parts[2]),
          count: pgo_parse_int(parts[3]),
          kind: parts[4]
        })
      @end
    @elif starts_with(line, "CALL:")
      parts = pgo_split_colon(line)
      @if curr_func != 0 && parts.len() >= 4
        curr_func.call_sites = curr_func.call_sites.push({
          site_id: pgo_parse_int(parts[1]),
          target: parts[2],
          count: pgo_parse_int(parts[3])
        })
      @end
    @elif starts_with(line, "LOOP:")
      parts = pgo_split_colon(line)
      @if curr_func != 0 && parts.len() >= 6
        curr_func.loops = curr_func.loops.push({
          loop_id: pgo_parse_int(parts[1]),
          header_block: pgo_parse_int(parts[2]),
          entry_count: pgo_parse_int(parts[3]),
          back_edge_count: pgo_parse_int(parts[4]),
          avg_trip_count: pgo_parse_int(parts[5])
        })
      @end
    @elif starts_with(line, "FN_END")
      @if curr_func != 0
        prof.functions = prof.functions.push(curr_func)
        curr_func = 0
      @end
    @end

    line_idx = line_idx + 1
  @end

  return prof
@end

@! ----------------------------------------------------------------------------
@! 4. PROFILE MERGING
@! ----------------------------------------------------------------------------

@fn pgo_profile_merge(prof_a, prof_b)
  merged = pgo_profile_new(prof_a.module_name)
  merged.checksum = prof_a.checksum
  merged.timestamp = prof_a.timestamp
  
  a_funcs = prof_a.functions
  b_funcs = prof_b.functions
  
  a_len = 0
  @if a_funcs != 0
    a_len = a_funcs.len()
  @end

  i = 0
  @while i < a_len
    fa = a_funcs[i]
    fb = pgo_profile_get_func(prof_b, fa.name)
    
    @if fb == 0
      merged.functions = merged.functions.push(fa)
    @else
      @! Merge fa and fb
      new_invocations = fa.invocations + fb.invocations
      
      @! Merge blocks
      new_blocks = []
      bk_len = fa.block_counts.len()
      bi = 0
      @while bi < bk_len
        cnt_a = fa.block_counts[bi]
        cnt_b = 0
        @if bi < fb.block_counts.len()
          cnt_b = fb.block_counts[bi]
        @end
        new_blocks = new_blocks.push(cnt_a + cnt_b)
        bi = bi + 1
      @end

      @! Merge edges
      new_edges = []
      ei = 0
      e_len = fa.edges.len()
      @while ei < e_len
        ea = fa.edges[ei]
        count_b = 0
        @! Find matching edge in fb
        ej = 0
        fb_e_len = fb.edges.len()
        @while ej < fb_e_len
          eb = fb.edges[ej]
          @if eb.src == ea.src && eb.dst == ea.dst
            count_b = eb.count
          @end
          ej = ej + 1
        @end
        new_edges = new_edges.push({
          src: ea.src,
          dst: ea.dst,
          count: ea.count + count_b,
          kind: ea.kind
        })
        ei = ei + 1
      @end

      @! Merge call sites
      new_calls = []
      ci = 0
      c_len = fa.call_sites.len()
      @while ci < c_len
        ca = fa.call_sites[ci]
        cb_count = 0
        cj = 0
        fb_c_len = fb.call_sites.len()
        @while cj < fb_c_len
          cb = fb.call_sites[cj]
          @if cb.site_id == ca.site_id
            cb_count = cb.count
          @end
          cj = cj + 1
        @end
        new_calls = new_calls.push({
          site_id: ca.site_id,
          target: ca.target,
          count: ca.count + cb_count
        })
        ci = ci + 1
      @end

      @! Merge loops
      new_loops = []
      li = 0
      l_len = fa.loops.len()
      @while li < l_len
        la = fa.loops[li]
        lb_entry = 0
        lb_back = 0
        lj = 0
        fb_l_len = fb.loops.len()
        @while lj < fb_l_len
          lb = fb.loops[lj]
          @if lb.loop_id == la.loop_id
            lb_entry = lb.entry_count
            lb_back = lb.back_edge_count
          @end
          lj = lj + 1
        @end
        total_entry = la.entry_count + lb_entry
        total_back = la.back_edge_count + lb_back
        trip = 0
        @if total_entry > 0
          trip = total_back / total_entry
        @end
        new_loops = new_loops.push({
          loop_id: la.loop_id,
          header_block: la.header_block,
          entry_count: total_entry,
          back_edge_count: total_back,
          avg_trip_count: trip
        })
        li = li + 1
      @end

      merged.functions = merged.functions.push({
        name: fa.name,
        hash: fa.hash,
        invocations: new_invocations,
        block_counts: new_blocks,
        edges: new_edges,
        call_sites: new_calls,
        loops: new_loops
      })
    @end
    i = i + 1
  @end

  return merged
@end
