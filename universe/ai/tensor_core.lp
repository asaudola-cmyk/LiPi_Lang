@! ============================================================================
@! LIPI UNIVERSE AI — HIGH-PERFORMANCE N-DIMENSIONAL TENSOR ENGINE (universe/ai/tensor.lp)
@! 100% Pure Lipi Implementation — Zero External Python/C++/CUDA Dependencies
@! Features: Strided Memory Views, Reshaping, Transposition, Permutation,
@! Slicing, Multidirectional Broadcasting, 2D/Batched GEMM, Reductions,
@! Transcendental Mathematics, and Numerically Stable Activations.
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"
import "universe/core/string"
import "universe/sys/syscalls"
import "universe/ai/simd_gemm"

@! ----------------------------------------------------------------------------
@! 1. Core Struct Definitions
@! ----------------------------------------------------------------------------

@struct TensorContext
  saved_tensors: array
  saved_shapes: array
  saved_floats: array
  saved_ints: array
  op_name: string
@end

@struct Tensor
  data: array
  shape: array
  strides: array
  offset: i64
  ndim: i64
  size: i64
  is_contiguous: i64
  requires_grad: i64
  grad: array
  creator_op: string
  parents: array
  ctx: TensorContext
@end

@! ----------------------------------------------------------------------------
@! 2. Context Constructors
@! ----------------------------------------------------------------------------

@fn tensor_context_new(op_name: string, saved_tensors: array, saved_shapes: array, saved_floats: array, saved_ints: array) -> TensorContext
  return {
    saved_tensors: saved_tensors,
    saved_shapes: saved_shapes,
    saved_floats: saved_floats,
    saved_ints: saved_ints,
    op_name: op_name
  }
@end

@fn tensor_context_empty() -> TensorContext
  return {
    saved_tensors: [],
    saved_shapes: [],
    saved_floats: [],
    saved_ints: [],
    op_name: "none"
  }
@end

@! ----------------------------------------------------------------------------
@! 3. Pure LiPi Transcendental Mathematics (Float & Scaled Fixed-Point)
@! ----------------------------------------------------------------------------

@fn math_abs(x: f64) -> f64
  @if x < 0.0
    return 0.0 - x
  @end
  return x
@end

@fn tensor_math_sqrt(x: f64) -> f64
  @if x <= 0.0
    return 0.0
  @end
  y = x
  @if x < 1.0
    y = 1.0
  @end
  i = 0
  @while i < 20
    y = 0.5 * (y + (x / y))
    i = i + 1
  @end
  return y
@end

@fn math_exp(x: f64) -> f64
  @if x < 0.0 - 700.0
    return 0.0
  @end
  @if x > 700.0
    x = 700.0
  @end
  u = x / 1024.0
  term = 1.0
  sum = 1.0
  i = 1
  @while i <= 14
    term = term * (u / (i * 1.0))
    sum = sum + term
    i = i + 1
  @end
  j = 0
  @while j < 10
    sum = sum * sum
    j = j + 1
  @end
  return sum
@end

@fn math_ln(x: f64) -> f64
  @if x <= 0.0
    return 0.0 - 1000000.0
  @end
  ln2 = 0.6931471805599453
  k = 0
  @while x > 1.4142135623730951
    x = x * 0.5
    k = k + 1
  @end
  @while x < 0.7071067811865475
    x = x * 2.0
    k = k - 1
  @end
  z = (x - 1.0) / (x + 1.0)
  z2 = z * z
  term = z
  sum = z
  n = 3
  @while n <= 17
    term = term * z2
    sum = sum + (term / (n * 1.0))
    n = n + 2
  @end
  return (2.0 * sum) + (k * 1.0 * ln2)
@end

@fn math_tanh(x: f64) -> f64
  @if x > 20.0
    return 1.0
  @end
  @if x < 0.0 - 20.0
    return 0.0 - 1.0
  @end
  @if x >= 0.0
    e2x = math_exp(2.0 * x)
    return (e2x - 1.0) / (e2x + 1.0)
  @else
    e_neg2x = math_exp(0.0 - (2.0 * x))
    return (1.0 - e_neg2x) / (1.0 + e_neg2x)
  @end
@end

@fn math_isqrt(n: i64) -> i64
  @if n <= 0 return 0 @end
  @if n == 1 return 1 @end
  x = n
  y = (x + 1) / 2
  @while y < x
    x = y
    y = (x + n / x) / 2
  @end
  return x
@end

@fn math_exp_scaled(x_scaled: i64) -> i64
  sum = 1000
  term = 1000
  k = 1
  @while k <= 12
    term = (term * x_scaled) / (k * 1000)
    sum = sum + term
    k = k + 1
  @end
  return sum
@end

@fn math_ln_scaled(x_scaled: i64) -> i64
  @if x_scaled <= 0 return 0 - 999999 @end
  num = (x_scaled - 1000) * 1000
  den = x_scaled + 1000
  u = num / den
  u_sq = (u * u) / 1000
  term = u
  sum = 0
  k = 0
  @while k <= 10
    sum = sum + (term / (2 * k + 1))
    term = (term * u_sq) / 1000
    k = k + 1
  @end
  return 2 * sum
@end

@fn math_tanh_scaled(x_scaled: i64) -> i64
  @if x_scaled > 4000 return 999 @end
  @if x_scaled < 0 - 4000 return 0 - 999 @end
  e2x = math_exp_scaled(2 * x_scaled)
  return ((e2x - 1000) * 1000) / (e2x + 1000)
@end

@! ----------------------------------------------------------------------------
@! 4. Shape, Strides & Creation Helpers
@! ----------------------------------------------------------------------------

@fn tensor_compute_size(shape: array) -> i64
  ndim = shape.len()
  @if ndim == 0
    return 1
  @end
  sz = 1
  i = 0
  @while i < ndim
    sz = sz * shape[i]
    i = i + 1
  @end
  return sz
@end

@fn compute_contiguous_strides(shape: array) -> array
  ndim = shape.len()
  @if ndim == 0
    return []
  @end
  strides = []
  i = 0
  @while i < ndim
    strides = strides.push(0)
    i = i + 1
  @end
  stride = 1
  i = ndim - 1
  @while i >= 0
    strides[i] = stride
    stride = stride * shape[i]
    i = i - 1
  @end
  return strides
@end

@fn tensor_compute_strides(shape: array) -> array
  return compute_contiguous_strides(shape)
@end

@fn compute_row_major_strides(shape: array) -> array
  return compute_contiguous_strides(shape)
@end

@fn tensor_check_contiguous(shape: array, strides: array) -> i64
  ndim = shape.len()
  @if ndim == 0
    return 1
  @end
  @if ndim == 1
    @if shape[0] > 1 && strides[0] != 1
      return 0
    @end
    return 1
  @end
  expected = 1
  i = ndim - 1
  @while i >= 0
    d = shape[i]
    @if d > 1
      @if strides[i] != expected
        return 0
      @end
      expected = expected * d
    @end
    i = i - 1
  @end
  return 1
@end

@fn tensor_new(data: array, shape: array) -> Tensor
  ndim = shape.len()
  sz = tensor_compute_size(shape)
  strides = compute_contiguous_strides(shape)
  return {
    data: data,
    shape: shape,
    strides: strides,
    offset: 0,
    ndim: ndim,
    size: sz,
    is_contiguous: 1,
    requires_grad: 0,
    grad: [],
    creator_op: "none",
    parents: [],
    ctx: tensor_context_empty()
  }
@end

@fn tensor_from_array(data: array, shape: array) -> Tensor
  return tensor_new(data, shape)
@end

@fn tensor_create(data: array, shape: array) -> Tensor
  return tensor_new(data, shape)
@end

@fn tensor_zeros(shape: array) -> Tensor
  sz = tensor_compute_size(shape)
  data = []
  i = 0
  @while i < sz
    data = data.push(0)
    i = i + 1
  @end
  return tensor_new(data, shape)
@end

@fn tensor_zeros_nd(shape: array) -> Tensor
  return tensor_zeros(shape)
@end

@fn tensor_ones(shape: array) -> Tensor
  sz = tensor_compute_size(shape)
  data = []
  i = 0
  @while i < sz
    data = data.push(1)
    i = i + 1
  @end
  return tensor_new(data, shape)
@end

@fn tensor_ones_nd(shape: array) -> Tensor
  return tensor_ones(shape)
@end

@fn tensor_full(shape: array, fill_val: i64) -> Tensor
  sz = tensor_compute_size(shape)
  data = []
  i = 0
  @while i < sz
    data = data.push(fill_val)
    i = i + 1
  @end
  return tensor_new(data, shape)
@end

@fn tensor_arange(start: i64, stop_idx: i64, step: i64) -> Tensor
  data = []
  val = start
  @if step > 0
    @while val < stop_idx
      data = data.push(val)
      val = val + step
    @end
  @elif step < 0
    @while val > stop_idx
      data = data.push(val)
      val = val + step
    @end
  @end
  return tensor_new(data, [data.len()])
@end

@fn tensor_zeros_2d(r: i64, c: i64) -> Tensor
  return tensor_zeros([r, c])
@end

@fn tensor_ones_2d(r: i64, c: i64) -> Tensor
  return tensor_ones([r, c])
@end

@! ----------------------------------------------------------------------------
@! 5. Strided Memory Indexing & Offset Calculations
@! ----------------------------------------------------------------------------

@fn tensor_flat_to_offset(t: Tensor, flat_idx: i64) -> i64
  @if t.is_contiguous == 1 && t.offset == 0
    return flat_idx
  @end
  rem = flat_idx
  phys_offset = t.offset
  i = t.ndim - 1
  @while i >= 0
    dim_size = t.shape[i]
    coord = rem % dim_size
    rem = rem / dim_size
    phys_offset = phys_offset + (coord * t.strides[i])
    i = i - 1
  @end
  return phys_offset
@end

@fn tensor_get_flat(t: Tensor, flat_idx: i64) -> i64
  off = tensor_flat_to_offset(t, flat_idx)
  return t.data[off]
@end

@fn tensor_set_flat(t: Tensor, flat_idx: i64, val: i64) -> i64
  off = tensor_flat_to_offset(t, flat_idx)
  t.data[off] = val
  return 0
@end

@fn tensor_get_elem(t: Tensor, flat_idx: i64) -> i64
  return tensor_get_flat(t, flat_idx)
@end

@fn tensor_flat_to_coords(shape: array, flat_idx: i64) -> array
  ndim = shape.len()
  coords = []
  i = 0
  @while i < ndim
    coords = coords.push(0)
    i = i + 1
  @end
  rem = flat_idx
  i = ndim - 1
  @while i >= 0
    d = shape[i]
    coords[i] = rem % d
    rem = rem / d
    i = i - 1
  @end
  return coords
@end

@fn tensor_get_offset(t: Tensor, coords: array) -> i64
  phys_idx = t.offset
  i = 0
  num_items = coords.len()
  @while i < num_items
    c = coords[i]
    @if c < 0
      c = c + t.shape[i]
    @end
    phys_idx = phys_idx + (c * t.strides[i])
    i = i + 1
  @end
  return phys_idx
@end

@fn tensor_get(t: Tensor, coords: array) -> i64
  phys_idx = tensor_get_offset(t, coords)
  return t.data[phys_idx]
@end

@fn tensor_set(t: Tensor, coords: array, val: i64) -> Tensor
  phys_idx = tensor_get_offset(t, coords)
  t.data[phys_idx] = val
  return t
@end

@! ----------------------------------------------------------------------------
@! 6. Zero-Copy Views: Reshape, Transpose, Permute & Multi-Dimensional Slicing
@! ----------------------------------------------------------------------------

@fn tensor_contiguous(t: Tensor) -> Tensor
  @if t.is_contiguous == 1 && t.offset == 0 && t.data.len() == t.size
    return t
  @end
  packed_data = []
  i = 0
  sz = t.size
  @while i < sz
    v = tensor_get_flat(t, i)
    packed_data = packed_data.push(v)
    i = i + 1
  @end
  out = tensor_new(packed_data, t.shape)
  @if t.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "contiguous"
    out.parents = [t]
    out.ctx = tensor_context_new("contiguous", [], [t.shape], [], [])
  @end
  return out
@end

@fn tensor_reshape(t: Tensor, new_shape: array) -> Tensor
  src_t = t
  @if t.is_contiguous == 0
    src_t = tensor_contiguous(t)
  @end
  new_ndim = new_shape.len()
  new_size = tensor_compute_size(new_shape)
  @if new_size != t.size
    println("Error: Total element count mismatch in tensor_reshape")
    return t
  @end
  new_strides = compute_contiguous_strides(new_shape)
  ctx = tensor_context_new("reshape", [], [t.shape], [], [])
  req_grad = 0
  op_str = "none"
  parents_arr = []
  @if t.requires_grad == 1
    req_grad = 1
    op_str = "reshape"
    parents_arr = [t]
  @end
  return {
    data: src_t.data,
    shape: new_shape,
    strides: new_strides,
    offset: src_t.offset,
    ndim: new_ndim,
    size: new_size,
    is_contiguous: 1,
    requires_grad: req_grad,
    grad: [],
    creator_op: op_str,
    parents: parents_arr,
    ctx: ctx
  }
@end

@fn tensor_transpose(t: Tensor, dim0: i64, dim1: i64) -> Tensor
  new_shape = []
  new_strides = []
  i = 0
  @while i < t.ndim
    new_shape = new_shape.push(t.shape[i])
    new_strides = new_strides.push(t.strides[i])
    i = i + 1
  @end
  new_shape[dim0] = t.shape[dim1]
  new_shape[dim1] = t.shape[dim0]
  new_strides[dim0] = t.strides[dim1]
  new_strides[dim1] = t.strides[dim0]
  is_contig = tensor_check_contiguous(new_shape, new_strides)
  ctx = tensor_context_new("transpose", [], [], [], [dim0, dim1])
  req_grad = 0
  op_str = "none"
  parents_arr = []
  @if t.requires_grad == 1
    req_grad = 1
    op_str = "transpose"
    parents_arr = [t]
  @end
  return {
    data: t.data,
    shape: new_shape,
    strides: new_strides,
    offset: t.offset,
    ndim: t.ndim,
    size: t.size,
    is_contiguous: is_contig,
    requires_grad: req_grad,
    grad: [],
    creator_op: op_str,
    parents: parents_arr,
    ctx: ctx
  }
@end

@fn tensor_transpose_2d(t: Tensor) -> Tensor
  return tensor_transpose(t, 0, 1)
@end

@fn tensor_permute(t: Tensor, order: array) -> Tensor
  new_shape = []
  new_strides = []
  i = 0
  @while i < order.len()
    src_dim = order[i]
    new_shape = new_shape.push(t.shape[src_dim])
    new_strides = new_strides.push(t.strides[src_dim])
    i = i + 1
  @end
  is_contig = tensor_check_contiguous(new_shape, new_strides)
  ctx = tensor_context_new("permute", [], [], [], order)
  req_grad = 0
  op_str = "none"
  parents_arr = []
  @if t.requires_grad == 1
    req_grad = 1
    op_str = "permute"
    parents_arr = [t]
  @end
  return {
    data: t.data,
    shape: new_shape,
    strides: new_strides,
    offset: t.offset,
    ndim: order.len(),
    size: t.size,
    is_contiguous: is_contig,
    requires_grad: req_grad,
    grad: [],
    creator_op: op_str,
    parents: parents_arr,
    ctx: ctx
  }
@end

@fn tensor_slice(t: Tensor, slice_specs: array) -> Tensor
  new_shape = []
  new_strides = []
  new_offset = t.offset
  i = 0
  @while i < t.ndim
    start = 0
    stop_idx = t.shape[i]
    step = 1
    @if i < slice_specs.len()
      spec = slice_specs[i]
      start = spec[0]
      stop_idx = spec[1]
      step = spec[2]
    @end
    @if start < 0
      start = start + t.shape[i]
    @end
    @if stop_idx < 0
      stop_idx = stop_idx + t.shape[i]
    @end
    @if start < 0
      start = 0
    @end
    @if start > t.shape[i]
      start = t.shape[i]
    @end
    @if stop_idx < 0
      stop_idx = 0
    @end
    @if stop_idx > t.shape[i]
      stop_idx = t.shape[i]
    @end
    dim_len = 0
    @if stop_idx > start
      dim_len = (stop_idx - start + step - 1) / step
    @end
    new_shape = new_shape.push(dim_len)
    new_strides = new_strides.push(t.strides[i] * step)
    new_offset = new_offset + (start * t.strides[i])
    i = i + 1
  @end
  new_size = tensor_compute_size(new_shape)
  is_contig = tensor_check_contiguous(new_shape, new_strides)
  ctx = tensor_context_new("slice", [], [t.shape], [], [])
  req_grad = 0
  op_str = "none"
  parents_arr = []
  @if t.requires_grad == 1
    req_grad = 1
    op_str = "slice"
    parents_arr = [t]
  @end
  return {
    data: t.data,
    shape: new_shape,
    strides: new_strides,
    offset: new_offset,
    ndim: new_shape.len(),
    size: new_size,
    is_contiguous: is_contig,
    requires_grad: req_grad,
    grad: [],
    creator_op: op_str,
    parents: parents_arr,
    ctx: ctx
  }
@end

@fn tensor_squeeze(t: Tensor, dim: i64) -> Tensor
  @if dim < 0
    dim = dim + t.ndim
  @end
  @if dim < 0 || dim >= t.ndim || t.shape[dim] != 1
    return t
  @end
  new_shape = []
  new_strides = []
  i = 0
  @while i < t.ndim
    @if i != dim
      new_shape = new_shape.push(t.shape[i])
      new_strides = new_strides.push(t.strides[i])
    @end
    i = i + 1
  @end
  ctx = tensor_context_new("squeeze", [], [t.shape], [], [dim])
  req_grad = 0
  op_str = "none"
  parents_arr = []
  @if t.requires_grad == 1
    req_grad = 1
    op_str = "squeeze"
    parents_arr = [t]
  @end
  return {
    data: t.data,
    shape: new_shape,
    strides: new_strides,
    offset: t.offset,
    ndim: new_shape.len(),
    size: t.size,
    is_contiguous: t.is_contiguous,
    requires_grad: req_grad,
    grad: [],
    creator_op: op_str,
    parents: parents_arr,
    ctx: ctx
  }
@end

@fn tensor_unsqueeze(t: Tensor, dim: i64) -> Tensor
  @if dim < 0
    dim = dim + t.ndim + 1
  @end
  @if dim < 0 || dim > t.ndim
    return t
  @end
  new_shape = []
  new_strides = []
  i = 0
  inserted = 0
  @while i <= t.ndim
    @if i == dim
      new_shape = new_shape.push(1)
      stride_val = 1
      @if i < t.ndim
        stride_val = t.shape[i] * t.strides[i]
      @end
      new_strides = new_strides.push(stride_val)
      inserted = 1
    @end
    @if i < t.ndim
      new_shape = new_shape.push(t.shape[i])
      new_strides = new_strides.push(t.strides[i])
    @end
    i = i + 1
  @end
  ctx = tensor_context_new("unsqueeze", [], [t.shape], [], [dim])
  req_grad = 0
  op_str = "none"
  parents_arr = []
  @if t.requires_grad == 1
    req_grad = 1
    op_str = "unsqueeze"
    parents_arr = [t]
  @end
  return {
    data: t.data,
    shape: new_shape,
    strides: new_strides,
    offset: t.offset,
    ndim: new_shape.len(),
    size: t.size,
    is_contiguous: t.is_contiguous,
    requires_grad: req_grad,
    grad: [],
    creator_op: op_str,
    parents: parents_arr,
    ctx: ctx
  }
@end

@! ----------------------------------------------------------------------------
@! 7. Multidirectional Broadcasting Engine
@! ----------------------------------------------------------------------------

@fn tensor_broadcast_shapes(shape_a: array, shape_b: array) -> array
  len_a = shape_a.len()
  len_b = shape_b.len()
  max_len = len_a
  @if len_b > len_a
    max_len = len_b
  @end
  out_shape = []
  i = 0
  @while i < max_len
    out_shape = out_shape.push(1)
    i = i + 1
  @end
  idx = max_len - 1
  idx_a = len_a - 1
  idx_b = len_b - 1
  @while idx >= 0
    da = 1
    @if idx_a >= 0
      da = shape_a[idx_a]
    @end
    db = 1
    @if idx_b >= 0
      db = shape_b[idx_b]
    @end
    @if da == db
      out_shape[idx] = da
    @elif da == 1
      out_shape[idx] = db
    @elif db == 1
      out_shape[idx] = da
    @else
      return []
    @end
    idx = idx - 1
    idx_a = idx_a - 1
    idx_b = idx_b - 1
  @end
  return out_shape
@end

@fn tensor_broadcast_to(t: Tensor, target_shape: array) -> Tensor
  t_ndim = t.ndim
  tgt_ndim = target_shape.len()
  @if tgt_ndim < t_ndim
    return t
  @end
  new_strides = []
  i = 0
  @while i < tgt_ndim
    new_strides = new_strides.push(0)
    i = i + 1
  @end
  lead_dims = tgt_ndim - t_ndim
  k = 0
  @while k < lead_dims
    new_strides[k] = 0
    k = k + 1
  @end
  j = 0
  @while j < t_ndim
    tgt_idx = lead_dims + j
    tgt_dim = target_shape[tgt_idx]
    src_dim = t.shape[j]
    @if src_dim == tgt_dim
      new_strides[tgt_idx] = t.strides[j]
    @elif src_dim == 1
      new_strides[tgt_idx] = 0
    @else
      return t
    @end
    j = j + 1
  @end
  sz = tensor_compute_size(target_shape)
  ctx = tensor_context_new("broadcast_to", [], [t.shape], [], [])
  req_grad = 0
  op_str = "none"
  parents_arr = []
  @if t.requires_grad == 1
    req_grad = 1
    op_str = "broadcast_to"
    parents_arr = [t]
  @end
  return {
    data: t.data,
    shape: target_shape,
    strides: new_strides,
    offset: t.offset,
    ndim: tgt_ndim,
    size: sz,
    is_contiguous: 0,
    requires_grad: req_grad,
    grad: [],
    creator_op: op_str,
    parents: parents_arr,
    ctx: ctx
  }
@end

@! ----------------------------------------------------------------------------
@! 8. Elementwise Binary & Unary Arithmetic
@! ----------------------------------------------------------------------------

@fn tensor_add(a: Tensor, b: Tensor) -> Tensor
  out_shape = tensor_broadcast_shapes(a.shape, b.shape)
  bcast_a = tensor_broadcast_to(a, out_shape)
  bcast_b = tensor_broadcast_to(b, out_shape)
  sz = bcast_a.size
  res_data = []
  i = 0
  @while i < sz
    va = tensor_get_flat(bcast_a, i)
    vb = tensor_get_flat(bcast_b, i)
    res_data = res_data.push(va + vb)
    i = i + 1
  @end
  out = tensor_new(res_data, out_shape)
  @if a.requires_grad == 1 || b.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "add"
    out.parents = [a, b]
    out.ctx = tensor_context_new("add", [], [a.shape, b.shape], [], [])
  @end
  return out
@end

@fn tensor_sub(a: Tensor, b: Tensor) -> Tensor
  out_shape = tensor_broadcast_shapes(a.shape, b.shape)
  bcast_a = tensor_broadcast_to(a, out_shape)
  bcast_b = tensor_broadcast_to(b, out_shape)
  sz = bcast_a.size
  res_data = []
  i = 0
  @while i < sz
    va = tensor_get_flat(bcast_a, i)
    vb = tensor_get_flat(bcast_b, i)
    res_data = res_data.push(va - vb)
    i = i + 1
  @end
  out = tensor_new(res_data, out_shape)
  @if a.requires_grad == 1 || b.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "sub"
    out.parents = [a, b]
    out.ctx = tensor_context_new("sub", [], [a.shape, b.shape], [], [])
  @end
  return out
@end

@fn tensor_mul(a: Tensor, b: Tensor) -> Tensor
  out_shape = tensor_broadcast_shapes(a.shape, b.shape)
  bcast_a = tensor_broadcast_to(a, out_shape)
  bcast_b = tensor_broadcast_to(b, out_shape)
  sz = bcast_a.size
  res_data = []
  i = 0
  @while i < sz
    va = tensor_get_flat(bcast_a, i)
    vb = tensor_get_flat(bcast_b, i)
    res_data = res_data.push(va * vb)
    i = i + 1
  @end
  out = tensor_new(res_data, out_shape)
  @if a.requires_grad == 1 || b.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "mul"
    out.parents = [a, b]
    out.ctx = tensor_context_new("mul", [a, b], [a.shape, b.shape], [], [])
  @end
  return out
@end

@fn tensor_div(a: Tensor, b: Tensor) -> Tensor
  out_shape = tensor_broadcast_shapes(a.shape, b.shape)
  bcast_a = tensor_broadcast_to(a, out_shape)
  bcast_b = tensor_broadcast_to(b, out_shape)
  sz = bcast_a.size
  res_data = []
  i = 0
  @while i < sz
    va = tensor_get_flat(bcast_a, i)
    vb = tensor_get_flat(bcast_b, i)
    @if vb == 0
      res_data = res_data.push(0)
    @else
      res_data = res_data.push(va / vb)
    @end
    i = i + 1
  @end
  out = tensor_new(res_data, out_shape)
  @if a.requires_grad == 1 || b.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "div"
    out.parents = [a, b]
    out.ctx = tensor_context_new("div", [a, b], [a.shape, b.shape], [], [])
  @end
  return out
@end

@fn tensor_neg(a: Tensor) -> Tensor
  res_data = []
  i = 0
  @while i < a.size
    v = tensor_get_flat(a, i)
    res_data = res_data.push(0 - v)
    i = i + 1
  @end
  out = tensor_new(res_data, a.shape)
  @if a.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "neg"
    out.parents = [a]
    out.ctx = tensor_context_new("neg", [], [a.shape], [], [])
  @end
  return out
@end

@fn tensor_scale(a: Tensor, scalar: i64) -> Tensor
  res_data = []
  i = 0
  @while i < a.size
    v = tensor_get_flat(a, i)
    res_data = res_data.push(v * scalar)
    i = i + 1
  @end
  out = tensor_new(res_data, a.shape)
  @if a.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "scale"
    out.parents = [a]
    out.ctx = tensor_context_new("scale", [], [a.shape], [], [scalar])
  @end
  return out
@end

@fn int_pow(base: i64, exp: i64) -> i64
  @if exp == 0 return 1 @end
  @if exp == 1 return base @end
  res = 1
  b = base
  e = exp
  @while e > 0
    @if e % 2 == 1
      res = res * b
    @end
    b = b * b
    e = e / 2
  @end
  return res
@end

@fn tensor_pow(a: Tensor, exp: i64) -> Tensor
  res_data = []
  i = 0
  @while i < a.size
    v = tensor_get_flat(a, i)
    res_data = res_data.push(int_pow(v, exp))
    i = i + 1
  @end
  out = tensor_new(res_data, a.shape)
  @if a.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "pow"
    out.parents = [a]
    out.ctx = tensor_context_new("pow", [a], [a.shape], [], [exp])
  @end
  return out
@end

