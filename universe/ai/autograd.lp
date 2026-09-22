@! ============================================================================
@! LIPI UNIVERSE AI — REVERSE-MODE AUTOMATIC DIFFERENTIATION ENGINE (universe/ai/autograd.lp)
@! 100% Pure Lipi Implementation — Zero External Python/C++/CUDA Dependencies
@! Features: Computation DAG, Topological Sorting, Gradient Accumulation,
@! Backward Propagators for all Ops, Gradient Unbroadcasting, Activations,
@! Reductions, GEMM, Views, and Finite-Difference Numerical Gradient Checking.
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"
import "universe/ai/tensor"

@! ----------------------------------------------------------------------------
@! 1. Gradient Buffer & Leaf Node Helpers
@! ----------------------------------------------------------------------------

@fn tensor_ensure_grad(t)
  @if t.grad.len() < t.size
    new_grad = []
    i = 0
    @while i < t.size
      new_grad = new_grad.push(0.0)
      i = i + 1
    @end
    t.grad = new_grad
  @end
  return t
@end

@fn tensor_zero_grad(t)
  new_grad = []
  i = 0
  @while i < t.size
    new_grad = new_grad.push(0.0)
    i = i + 1
  @end
  t.grad = new_grad
  return t
@end

@fn tensor_requires_grad(t, req)
  t.requires_grad = req
  @if req == 1
    tensor_ensure_grad(t)
  @end
  return t
@end

@fn leaf_tensor(data, shape)
  t = tensor_new(data, shape)
  t.requires_grad = 1
  t.creator_op = "leaf"
  tensor_ensure_grad(t)
  return t
@end

@fn constant_tensor(data, shape)
  t = tensor_new(data, shape)
  t.requires_grad = 0
  t.creator_op = "constant"
  return t
@end

@fn tensor_accumulate_grad(p, d_grad)
  @if p.requires_grad == 0
    return 0
  @end
  @if p.grad.len() < p.size
    tensor_ensure_grad(p)
  @end
  i = 0
  sz = p.size
  @if d_grad.len() < sz
    sz = d_grad.len()
  @end
  @while i < sz
    p.grad[i] = p.grad[i] + d_grad[i]
    i = i + 1
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 2. Gradient Unbroadcasting Engine
@! ----------------------------------------------------------------------------

@fn tensor_unbroadcast_grad(grad_c, shape_c, shape_a)
  len_c = shape_c.len()
  len_a = shape_a.len()

  @! If shapes and ranks match, gradient is identical
  @if len_c == len_a
    same = 1
    i = 0
    @while i < len_c
      @if shape_c[i] != shape_a[i]
        same = 0
      @end
      i = i + 1
    @end
    @if same == 1
      return grad_c
    @end
  @end

  sz_a = tensor_compute_size(shape_a)
  strides_a = compute_contiguous_strides(shape_a)
  res_grad = []
  i = 0
  @while i < sz_a
    res_grad = res_grad.push(0.0)
    i = i + 1
  @end

  sz_c = grad_c.len()
  c_idx = 0
  lead = len_c - len_a
  @while c_idx < sz_c
    c_coords = tensor_flat_to_coords(shape_c, c_idx)
    a_flat = 0
    j = 0
    @while j < len_a
      c_dim_idx = lead + j
      c_val = c_coords[c_dim_idx]
      a_dim_sz = shape_a[j]
      coord_in_a = 0
      @if a_dim_sz > 1
        coord_in_a = c_val
      @end
      a_flat = a_flat + (coord_in_a * strides_a[j])
      j = j + 1
    @end
    res_grad[a_flat] = res_grad[a_flat] + grad_c[c_idx]
    c_idx = c_idx + 1
  @end
  return res_grad
@end

@! ----------------------------------------------------------------------------
@! 3. Computation Graph Topological Sorting (DFS Post-Order)
@! ----------------------------------------------------------------------------

@fn tensor_topo_visit(node, visited_nodes, topo_list)
  visited_nodes = visited_nodes.push(node)
  i = 0
  num_parents = node.parents.len()
  @while i < num_parents
    p = node.parents[i]
    found = 0
    v_idx = 0
    num_visited = visited_nodes.len()
    @while v_idx < num_visited
      @if visited_nodes[v_idx] == p
        found = 1
      @end
      v_idx = v_idx + 1
    @end
    @if found == 0
      res_pair = tensor_topo_visit(p, visited_nodes, topo_list)
      visited_nodes = res_pair[0]
      topo_list = res_pair[1]
    @end
    i = i + 1
  @end
  topo_list = topo_list.push(node)
  return [visited_nodes, topo_list]
@end

@fn tensor_topological_sort(root)
  topo_res = tensor_topo_visit(root, [], [])
  return topo_res[1]
@end

@! ----------------------------------------------------------------------------
@! 4. Backward Pass Entrypoint & Op Propagators
@! ----------------------------------------------------------------------------

@fn tensor_backward(root)
  @! 1. Seed root gradient with 1s
  @if root.grad.len() < root.size
    tensor_ensure_grad(root)
  @end
  i = 0
  @while i < root.size
    @if root.grad[i] == 0
      root.grad[i] = 1
    @end
    i = i + 1
  @end

  @! 2. Topological sort (DFS Post-Order)
  topo_nodes = tensor_topological_sort(root)

  @! 3. Traverse in reverse topological order (root to leaves)
  idx = topo_nodes.len() - 1
  @while idx >= 0
    curr = topo_nodes[idx]
    
    @if curr.requires_grad == 1 && curr.creator_op != "none" && curr.creator_op != "leaf" && curr.creator_op != "constant"
      op = curr.creator_op

      @! --- ADD BACKWARD ---
      @if op == "add"
        pa = curr.parents[0]
        pb = curr.parents[1]
        shape_c = curr.shape
        @if pa.requires_grad == 1
          ga = tensor_unbroadcast_grad(curr.grad, shape_c, pa.shape)
          tensor_accumulate_grad(pa, ga)
        @end
        @if pb.requires_grad == 1
          gb = tensor_unbroadcast_grad(curr.grad, shape_c, pb.shape)
          tensor_accumulate_grad(pb, gb)
        @end
      @end

      @! --- SUB BACKWARD ---
      @if op == "sub"
        pa = curr.parents[0]
        pb = curr.parents[1]
        shape_c = curr.shape
        @if pa.requires_grad == 1
          ga = tensor_unbroadcast_grad(curr.grad, shape_c, pa.shape)
          tensor_accumulate_grad(pa, ga)
        @end
        @if pb.requires_grad == 1
          neg_grad = []
          k = 0
          sz = curr.grad.len()
          @while k < sz
            neg_grad = neg_grad.push(0.0 - curr.grad[k])
            k = k + 1
          @end
          gb = tensor_unbroadcast_grad(neg_grad, shape_c, pb.shape)
          tensor_accumulate_grad(pb, gb)
        @end
      @end

      @! --- MUL BACKWARD ---
      @if op == "mul"
        pa = curr.parents[0]
        pb = curr.parents[1]
        shape_c = curr.shape
        @if pa.requires_grad == 1
          bcast_b = tensor_broadcast_to(pb, shape_c)
          raw_ga = []
          k = 0
          sz = curr.grad.len()
          @while k < sz
            vb = tensor_get_flat(bcast_b, k)
            raw_ga = raw_ga.push(curr.grad[k] * vb)
            k = k + 1
          @end
          ga = tensor_unbroadcast_grad(raw_ga, shape_c, pa.shape)
          tensor_accumulate_grad(pa, ga)
        @end
        @if pb.requires_grad == 1
          bcast_a = tensor_broadcast_to(pa, shape_c)
          raw_gb = []
          k = 0
          sz = curr.grad.len()
          @while k < sz
            va = tensor_get_flat(bcast_a, k)
            raw_gb = raw_gb.push(curr.grad[k] * va)
            k = k + 1
          @end
          gb = tensor_unbroadcast_grad(raw_gb, shape_c, pb.shape)
          tensor_accumulate_grad(pb, gb)
        @end
      @end

      @! --- DIV BACKWARD ---
      @if op == "div"
        pa = curr.parents[0]
        pb = curr.parents[1]
        shape_c = curr.shape
        bcast_a = tensor_broadcast_to(pa, shape_c)
        bcast_b = tensor_broadcast_to(pb, shape_c)
        @if pa.requires_grad == 1
          raw_ga = []
          k = 0
          sz = curr.grad.len()
          @while k < sz
            vb = tensor_get_flat(bcast_b, k)
            @if vb != 0
              raw_ga = raw_ga.push(curr.grad[k] / vb)
            @else
              raw_ga = raw_ga.push(0.0)
            @end
            k = k + 1
          @end
          ga = tensor_unbroadcast_grad(raw_ga, shape_c, pa.shape)
          tensor_accumulate_grad(pa, ga)
        @end
        @if pb.requires_grad == 1
          raw_gb = []
          k = 0
          sz = curr.grad.len()
          @while k < sz
            va = tensor_get_flat(bcast_a, k)
            vb = tensor_get_flat(bcast_b, k)
            @if vb != 0
              val = (0 - curr.grad[k] * va) / (vb * vb)
              raw_gb = raw_gb.push(val)
            @else
              raw_gb = raw_gb.push(0.0)
            @end
            k = k + 1
          @end
          gb = tensor_unbroadcast_grad(raw_gb, shape_c, pb.shape)
          tensor_accumulate_grad(pb, gb)
        @end
      @end

      @! --- NEG BACKWARD ---
      @if op == "neg"
        pa = curr.parents[0]
        @if pa.requires_grad == 1
          ga = []
          k = 0
          sz = curr.grad.len()
          @while k < sz
            ga = ga.push(0.0 - curr.grad[k])
            k = k + 1
          @end
          tensor_accumulate_grad(pa, ga)
        @end
      @end

      @! --- SCALE BACKWARD ---
      @if op == "scale"
        pa = curr.parents[0]
        s = 1
        @if curr.ctx.saved_ints.len() > 0
          s = curr.ctx.saved_ints[0]
        @end
        @if pa.requires_grad == 1
          ga = []
          k = 0
          sz = curr.grad.len()
          @while k < sz
            ga = ga.push(curr.grad[k] * s)
            k = k + 1
          @end
          tensor_accumulate_grad(pa, ga)
        @end
      @end

      @! --- POW BACKWARD ---
      @if op == "pow"
        pa = curr.parents[0]
        p = 1
        @if curr.ctx.saved_ints.len() > 0
          p = curr.ctx.saved_ints[0]
        @end
        @if pa.requires_grad == 1
          ga = []
          k = 0
          sz = pa.size
          @while k < sz
            va = tensor_get_flat(pa, k)
            p_term = int_pow(va, p - 1)
            g_val = curr.grad[k] * p * p_term
            ga = ga.push(g_val)
            k = k + 1
          @end
          tensor_accumulate_grad(pa, ga)
        @end
      @end

      @! --- MATMUL & BATCHED GEMM BACKWARD ---
      @! grad_A = grad_C @ B^T, grad_B = A^T @ grad_C
      @if op == "matmul" || op == "bmm"
        pa = curr.parents[0]
        pb = curr.parents[1]
        grad_c_t = tensor_new(curr.grad, curr.shape)

        @if pa.requires_grad == 1
          pb_t = tensor_transpose(pb, pb.ndim - 2, pb.ndim - 1)
          d_a_t = tensor_matmul(grad_c_t, pb_t)
          d_a_contig = tensor_contiguous(d_a_t)
          ga = tensor_unbroadcast_grad(d_a_contig.data, d_a_contig.shape, pa.shape)
          tensor_accumulate_grad(pa, ga)
        @end

        @if pb.requires_grad == 1
          pa_t = tensor_transpose(pa, pa.ndim - 2, pa.ndim - 1)
          d_b_t = tensor_matmul(pa_t, grad_c_t)
          d_b_contig = tensor_contiguous(d_b_t)
          gb = tensor_unbroadcast_grad(d_b_contig.data, d_b_contig.shape, pb.shape)
          tensor_accumulate_grad(pb, gb)
        @end
      @end

      @! --- RESHAPE BACKWARD ---
      @if op == "reshape"
        pa = curr.parents[0]
        @if pa.requires_grad == 1
          tensor_accumulate_grad(pa, curr.grad)
        @end
      @end

      @! --- TRANSPOSE BACKWARD ---
      @if op == "transpose"
        pa = curr.parents[0]
        dim0 = 0
        dim1 = 1
        @if curr.ctx.saved_ints.len() >= 2
          dim0 = curr.ctx.saved_ints[0]
          dim1 = curr.ctx.saved_ints[1]
        @end
        @if pa.requires_grad == 1
          grad_c_t = tensor_new(curr.grad, curr.shape)
          grad_a_t = tensor_transpose(grad_c_t, dim0, dim1)
          grad_a_contig = tensor_contiguous(grad_a_t)
          tensor_accumulate_grad(pa, grad_a_contig.data)
        @end
      @end

      @! --- PERMUTE BACKWARD ---
      @if op == "permute"
        pa = curr.parents[0]
        order = curr.ctx.saved_ints
        @if pa.requires_grad == 1
          n_dims = order.len()
          inv_order = []
          k = 0
          @while k < n_dims
            inv_order = inv_order.push(0)
            k = k + 1
          @end
          k = 0
          @while k < n_dims
            inv_order[order[k]] = k
            k = k + 1
          @end
          grad_c_t = tensor_new(curr.grad, curr.shape)
          grad_a_t = tensor_permute(grad_c_t, inv_order)
          grad_a_contig = tensor_contiguous(grad_a_t)
          tensor_accumulate_grad(pa, grad_a_contig.data)
        @end
      @end

      @! --- SLICE BACKWARD ---
      @if op == "slice"
        pa = curr.parents[0]
        @if pa.requires_grad == 1
          k = 0
          sz = curr.size
          @while k < sz
            phys_off = tensor_flat_to_offset(curr, k)
            idx_in_pa = phys_off - pa.offset
            @if idx_in_pa >= 0 && idx_in_pa < pa.size
              @if pa.grad.len() < pa.size
                tensor_ensure_grad(pa)
              @end
              pa.grad[idx_in_pa] = pa.grad[idx_in_pa] + curr.grad[k]
            @end
            k = k + 1
          @end
        @end
      @end

      @! --- SQUEEZE BACKWARD ---
      @if op == "squeeze"
        pa = curr.parents[0]
        dim = 0
        @if curr.ctx.saved_ints.len() > 0
          dim = curr.ctx.saved_ints[0]
        @end
        @if pa.requires_grad == 1
          grad_c_t = tensor_new(curr.grad, curr.shape)
          grad_a_t = tensor_unsqueeze(grad_c_t, dim)
          grad_a_contig = tensor_contiguous(grad_a_t)
          tensor_accumulate_grad(pa, grad_a_contig.data)
        @end
      @end

      @! --- UNSQUEEZE BACKWARD ---
      @if op == "unsqueeze"
        pa = curr.parents[0]
        dim = 0
        @if curr.ctx.saved_ints.len() > 0
          dim = curr.ctx.saved_ints[0]
        @end
        @if pa.requires_grad == 1
          grad_c_t = tensor_new(curr.grad, curr.shape)
          grad_a_t = tensor_squeeze(grad_c_t, dim)
          grad_a_contig = tensor_contiguous(grad_a_t)
          tensor_accumulate_grad(pa, grad_a_contig.data)
        @end
      @end

      @! --- CONTIGUOUS VIEW BACKWARD ---
      @if op == "contiguous"
        pa = curr.parents[0]
        @if pa.requires_grad == 1
          k = 0
          sz = curr.size
          @while k < sz
            phys_off = tensor_flat_to_offset(pa, k)
            idx_in_pa = phys_off - pa.offset
            @if idx_in_pa >= 0 && idx_in_pa < pa.size
              @if pa.grad.len() < pa.size
                tensor_ensure_grad(pa)
              @end
              pa.grad[idx_in_pa] = pa.grad[idx_in_pa] + curr.grad[k]
            @end
            k = k + 1
          @end
        @end
      @end

      @! --- BROADCAST_TO BACKWARD ---
      @if op == "broadcast_to"
        pa = curr.parents[0]
        @if pa.requires_grad == 1
          ga = tensor_unbroadcast_grad(curr.grad, curr.shape, pa.shape)
          tensor_accumulate_grad(pa, ga)
        @end
      @end

      @! --- RELU BACKWARD ---
      @if op == "relu"
        pa = curr.parents[0]
        @if pa.requires_grad == 1
          ga = []
          k = 0
          sz = pa.size
          @while k < sz
            va = tensor_get_flat(pa, k)
            @if va > 0
              ga = ga.push(curr.grad[k])
            @else
              ga = ga.push(0.0)
            @end
            k = k + 1
          @end
          tensor_accumulate_grad(pa, ga)
        @end
      @end

      @! --- SIGMOID BACKWARD ---
      @if op == "sigmoid"
        pa = curr.parents[0]
        scale_val = 1000
        @if curr.ctx.saved_floats.len() > 0
          scale_val = curr.ctx.saved_floats[0]
        @end
        @if pa.requires_grad == 1
          ga = []
          k = 0
          sz = pa.size
          @while k < sz
            y = tensor_get_flat(curr, k)
            g = curr.grad[k]
            g_val = 0
            @if scale_val > 0
              term = (y * (scale_val - y))
              g_val = (g * term) / (scale_val * scale_val)
            @end
            ga = ga.push(g_val)
            k = k + 1
          @end
          tensor_accumulate_grad(pa, ga)
        @end
      @end

      @! --- GELU BACKWARD ---
      @if op == "gelu"
        pa = curr.parents[0]
        scale_val = 1000.0
        @if curr.ctx.saved_floats.len() > 0
          scale_val = curr.ctx.saved_floats[0]
        @end
        c_const = 0.7978845608028654
        k_const = 0.044715
        @if pa.requires_grad == 1
          ga = []
          k = 0
          sz = pa.size
          @while k < sz
            raw_x = tensor_get_flat(pa, k)
            x = (raw_x * 1.0) / scale_val
            x2 = x * x
            x3 = x2 * x
            u = c_const * (x + (k_const * x3))
            th = math_tanh(u)
            sech2 = 1.0 - (th * th)
            du_dx = c_const * (1.0 + (3.0 * k_const * x2))
            d_gelu = 0.5 * (1.0 + th) + (0.5 * x * sech2 * du_dx)
            g_val = (curr.grad[k] * 1.0) * d_gelu
            ga = ga.push(g_val)
            k = k + 1
          @end
          tensor_accumulate_grad(pa, ga)
        @end
      @end

      @! --- SOFTMAX BACKWARD ---
      @if op == "softmax"
        pa = curr.parents[0]
        scale_val = 1000
        @if curr.ctx.saved_floats.len() > 0
          scale_val = curr.ctx.saved_floats[0]
        @end
        @if pa.requires_grad == 1
          last_dim_size = pa.shape[pa.ndim - 1]
          num_slices = pa.size / last_dim_size
          ga = []
          k = 0
          @while k < pa.size
            ga = ga.push(0.0)
            k = k + 1
          @end
          s = 0
          @while s < num_slices
            base_idx = s * last_dim_size
            sum_gy = 0
            j = 0
            @while j < last_dim_size
              y_j = tensor_get_flat(curr, base_idx + j)
              g_j = curr.grad[base_idx + j]
              sum_gy = sum_gy + ((g_j * y_j) / scale_val)
              j = j + 1
            @end
            j = 0
            @while j < last_dim_size
              y_j = tensor_get_flat(curr, base_idx + j)
              g_j = curr.grad[base_idx + j]
              diff_g = g_j - sum_gy
              ga[base_idx + j] = (y_j * diff_g) / scale_val
              j = j + 1
            @end
            s = s + 1
          @end
          tensor_accumulate_grad(pa, ga)
        @end
      @end

      @! --- SUM REDUCTION BACKWARD ---
      @if op == "sum"
        pa = curr.parents[0]
        dim = 0 - 1
        keepdim = 0
        @if curr.ctx.saved_ints.len() >= 2
          dim = curr.ctx.saved_ints[0]
          keepdim = curr.ctx.saved_ints[1]
        @end
        @if pa.requires_grad == 1
          ga = []
          @if dim < 0 || dim >= pa.ndim
            g_val = curr.grad[0]
            k = 0
            @while k < pa.size
              ga = ga.push(g_val)
              k = k + 1
            @end
          @else
            outer_size = 1
            k = 0
            @while k < dim
              outer_size = outer_size * pa.shape[k]
              k = k + 1
            @end
            reduce_size = pa.shape[dim]
            inner_size = 1
            k = dim + 1
            @while k < pa.ndim
              inner_size = inner_size * pa.shape[k]
              k = k + 1
            @end
            k = 0
            @while k < pa.size
              ga = ga.push(0.0)
              k = k + 1
            @end
            o = 0
            @while o < outer_size
              r = 0
              @while r < reduce_size
                in_idx_base = (o * reduce_size * inner_size) + (r * inner_size)
                in_elem = 0
                @while in_elem < inner_size
                  in_flat = in_idx_base + in_elem
                  out_flat = (o * inner_size) + in_elem
                  ga[in_flat] = curr.grad[out_flat]
                  in_elem = in_elem + 1
                @end
                r = r + 1
              @end
              o = o + 1
            @end
          @end
          tensor_accumulate_grad(pa, ga)
        @end
      @end

      @! --- MEAN REDUCTION BACKWARD ---
      @if op == "mean"
        pa = curr.parents[0]
        dim = 0 - 1
        keepdim = 0
        @if curr.ctx.saved_ints.len() >= 2
          dim = curr.ctx.saved_ints[0]
          keepdim = curr.ctx.saved_ints[1]
        @end
        @if pa.requires_grad == 1
          count = 1
          @if dim < 0 || dim >= pa.ndim
            count = pa.size
          @else
            count = pa.shape[dim]
          @end
          @if count == 0
            count = 1
          @end
          ga = []
          @if dim < 0 || dim >= pa.ndim
            g_val = curr.grad[0] / count
            k = 0
            @while k < pa.size
              ga = ga.push(g_val)
              k = k + 1
            @end
          @else
            outer_size = 1
            k = 0
            @while k < dim
              outer_size = outer_size * pa.shape[k]
              k = k + 1
            @end
            reduce_size = pa.shape[dim]
            inner_size = 1
            k = dim + 1
            @while k < pa.ndim
              inner_size = inner_size * pa.shape[k]
              k = k + 1
            @end
            k = 0
            @while k < pa.size
              ga = ga.push(0.0)
              k = k + 1
            @end
            o = 0
            @while o < outer_size
              r = 0
              @while r < reduce_size
                in_idx_base = (o * reduce_size * inner_size) + (r * inner_size)
                in_elem = 0
                @while in_elem < inner_size
                  in_flat = in_idx_base + in_elem
                  out_flat = (o * inner_size) + in_elem
                  ga[in_flat] = curr.grad[out_flat] / count
                  in_elem = in_elem + 1
                @end
                r = r + 1
              @end
              o = o + 1
            @end
          @end
          tensor_accumulate_grad(pa, ga)
        @end
      @end

      @! --- MAX / MIN REDUCTION BACKWARD ---
      @if op == "max" || op == "min"
        pa = curr.parents[0]
        dim = 0 - 1
        keepdim = 0
        @if curr.ctx.saved_ints.len() >= 2
          dim = curr.ctx.saved_ints[0]
          keepdim = curr.ctx.saved_ints[1]
        @end
        @if pa.requires_grad == 1
          ga = []
          k = 0
          @while k < pa.size
            ga = ga.push(0.0)
            k = k + 1
          @end
          @if dim < 0 || dim >= pa.ndim
            target_val = curr.data[0]
            g_val = curr.grad[0]
            found = 0
            k = 0
            @while k < pa.size
              va = tensor_get_flat(pa, k)
              @if va == target_val && found == 0
                ga[k] = g_val
                found = 1
              @end
              k = k + 1
            @end
          @else
            outer_size = 1
            k = 0
            @while k < dim
              outer_size = outer_size * pa.shape[k]
              k = k + 1
            @end
            reduce_size = pa.shape[dim]
            inner_size = 1
            k = dim + 1
            @while k < pa.ndim
              inner_size = inner_size * pa.shape[k]
              k = k + 1
            @end
            o = 0
            @while o < outer_size
              elem = 0
              @while elem < inner_size
                out_flat = (o * inner_size) + elem
                target_val = curr.data[out_flat]
                g = curr.grad[out_flat]
                found = 0
                r = 0
                @while r < reduce_size
                  in_flat = (o * reduce_size * inner_size) + (r * inner_size) + elem
                  va = tensor_get_flat(pa, in_flat)
                  @if va == target_val && found == 0
                    ga[in_flat] = g
                    found = 1
                  @end
                  r = r + 1
                @end
                elem = elem + 1
              @end
              o = o + 1
            @end
          @end
          tensor_accumulate_grad(pa, ga)
        @end
      @end

      @! --- MSE LOSS BACKWARD ---
      @if op == "mse_loss"
        pa = curr.parents[0]
        pb = curr.parents[1]
        n_elem = pa.size
        g_loss = curr.grad[0]
        @if pa.requires_grad == 1
          ga = []
          k = 0
          @while k < n_elem
            va = tensor_get_flat(pa, k)
            vb = tensor_get_flat(pb, k)
            diff = va - vb
            grad_val = (2 * diff * g_loss) / n_elem
            ga = ga.push(grad_val)
            k = k + 1
          @end
          tensor_accumulate_grad(pa, ga)
        @end
        @if pb.requires_grad == 1
          gb = []
          k = 0
          @while k < n_elem
            va = tensor_get_flat(pa, k)
            vb = tensor_get_flat(pb, k)
            diff = va - vb
            grad_val = (0 - (2 * diff * g_loss)) / n_elem
            gb = gb.push(grad_val)
            k = k + 1
          @end
          tensor_accumulate_grad(pb, gb)
        @end
      @end

      @! --- BROADCAST ROW ADD BACKWARD ---
      @if op == "add_bcast"
        pa = curr.parents[0]
        pb = curr.parents[1]
        m = pa.shape[0]
        n = pa.shape[1]
        @if pa.requires_grad == 1
          tensor_accumulate_grad(pa, curr.grad)
        @end
        @if pb.requires_grad == 1
          gb = []
          j = 0
          @while j < n
            col_sum = 0
            k = 0
            @while k < m
              col_sum = col_sum + curr.grad[k * n + j]
              k = k + 1
            @end
            gb = gb.push(col_sum)
            j = j + 1
          @end
          tensor_accumulate_grad(pb, gb)
        @end
      @end

    @end
    idx = idx - 1
  @end

  return root
@end

@fn autograd_backward(loss)
  return tensor_backward(loss)
@end

@! ----------------------------------------------------------------------------
@! 5. High-Level Loss Functions (Graph Integrated)
@! ----------------------------------------------------------------------------

@fn tensor_mse_loss(pred, target)
  req = pred.requires_grad || target.requires_grad
  n = pred.size
  sum_sq = 0.0
  i = 0
  @while i < n
    va = tensor_get_flat(pred, i)
    vb = tensor_get_flat(target, i)
    diff = va - vb
    sum_sq = sum_sq + (diff * diff)
    i = i + 1
  @end
  mean_loss = sum_sq / n
  out = tensor_new([mean_loss], [1])
  @if req == 1
    out.requires_grad = 1
    out.creator_op = "mse_loss"
    out.parents = [pred, target]
    out.ctx = tensor_context_new("mse_loss", [pred, target], [pred.shape, target.shape], [], [])
  @end
  return out
@end

@! ----------------------------------------------------------------------------
@! 6. Finite-Difference Numerical Gradient Checker
@! ----------------------------------------------------------------------------

@fn autograd_relative_error(g_ana, g_num)
  diff = math_abs(g_ana - g_num)
  a_abs = math_abs(g_ana)
  n_abs = math_abs(g_num)
  max_val = a_abs
  @if n_abs > max_val
    max_val = n_abs
  @end
  den = max_val + 0.00001
  return diff / den
@end

@fn autograd_grad_check(ana_grad, num_grad, tol)
  @if ana_grad.len() != num_grad.len()
    return 0
  @end
  i = 0
  sz = ana_grad.len()
  @while i < sz
    diff = math_abs(ana_grad[i] - num_grad[i])
    @if diff > tol
      return 0
    @end
    i = i + 1
  @end
  return 1
@end
