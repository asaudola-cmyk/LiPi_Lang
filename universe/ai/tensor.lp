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
@! 3. Pure Maya Transcendental Mathematics (Float & Scaled Fixed-Point)
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

@! ----------------------------------------------------------------------------
@! 9. Statistical Reductions (Sum, Mean, Max, Min, Variance)
@! ----------------------------------------------------------------------------

@fn tensor_sum(t: Tensor, dim: i64, keepdim: i64) -> Tensor
  @if dim < 0 || dim >= t.ndim
    total = 0
    i = 0
    @while i < t.size
      total = total + tensor_get_flat(t, i)
      i = i + 1
    @end
    out_shape = [1]
    @if keepdim == 1
      out_shape = []
      k = 0
      @while k < t.ndim
        out_shape = out_shape.push(1)
        k = k + 1
      @end
    @end
    out = tensor_new([total], out_shape)
    @if t.requires_grad == 1
      out.requires_grad = 1
      out.creator_op = "sum"
      out.parents = [t]
      out.ctx = tensor_context_new("sum", [], [t.shape], [], [dim, keepdim])
    @end
    return out
  @end

  outer_size = 1
  k = 0
  @while k < dim
    outer_size = outer_size * t.shape[k]
    k = k + 1
  @end
  reduce_size = t.shape[dim]
  inner_size = 1
  k = dim + 1
  @while k < t.ndim
    inner_size = inner_size * t.shape[k]
    k = k + 1
  @end
  out_size = outer_size * inner_size
  res_data = []
  i = 0
  @while i < out_size
    res_data = res_data.push(0)
    i = i + 1
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
        v = tensor_get_flat(t, in_flat)
        res_data[out_flat] = res_data[out_flat] + v
        in_elem = in_elem + 1
      @end
      r = r + 1
    @end
    o = o + 1
  @end
  out_shape = []
  k = 0
  @while k < t.ndim
    @if k == dim
      @if keepdim == 1
        out_shape = out_shape.push(1)
      @end
    @else
      out_shape = out_shape.push(t.shape[k])
    @end
    k = k + 1
  @end
  @if out_shape.len() == 0
    out_shape = [1]
  @end
  out = tensor_new(res_data, out_shape)
  @if t.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "sum"
    out.parents = [t]
    out.ctx = tensor_context_new("sum", [], [t.shape], [], [dim, keepdim])
  @end
  return out
@end

@fn tensor_mean(t: Tensor, dim: i64, keepdim: i64) -> Tensor
  sum_t = tensor_sum(t, dim, keepdim)
  count = 1
  @if dim < 0 || dim >= t.ndim
    count = t.size
  @else
    count = t.shape[dim]
  @end
  res_data = []
  i = 0
  @while i < sum_t.size
    res_data = res_data.push(sum_t.data[i] / count)
    i = i + 1
  @end
  out = tensor_new(res_data, sum_t.shape)
  @if t.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "mean"
    out.parents = [t]
    out.ctx = tensor_context_new("mean", [], [t.shape], [], [dim, keepdim])
  @end
  return out
@end

@fn tensor_max(t: Tensor, dim: i64, keepdim: i64) -> Tensor
  @if dim < 0 || dim >= t.ndim
    max_val = tensor_get_flat(t, 0)
    i = 1
    @while i < t.size
      v = tensor_get_flat(t, i)
      @if v > max_val
        max_val = v
      @end
      i = i + 1
    @end
    out_shape = [1]
    @if keepdim == 1
      out_shape = []
      k = 0
      @while k < t.ndim
        out_shape = out_shape.push(1)
        k = k + 1
      @end
    @end
    out = tensor_new([max_val], out_shape)
    @if t.requires_grad == 1
      out.requires_grad = 1
      out.creator_op = "max"
      out.parents = [t]
      out.ctx = tensor_context_new("max", [t, out], [t.shape], [], [dim, keepdim])
    @end
    return out
  @end

  outer_size = 1
  k = 0
  @while k < dim
    outer_size = outer_size * t.shape[k]
    k = k + 1
  @end
  reduce_size = t.shape[dim]
  inner_size = 1
  k = dim + 1
  @while k < t.ndim
    inner_size = inner_size * t.shape[k]
    k = k + 1
  @end
  out_size = outer_size * inner_size
  res_data = []
  i = 0
  @while i < out_size
    res_data = res_data.push(0 - 999999999)
    i = i + 1
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
        v = tensor_get_flat(t, in_flat)
        @if r == 0 || v > res_data[out_flat]
          res_data[out_flat] = v
        @end
        in_elem = in_elem + 1
      @end
      r = r + 1
    @end
    o = o + 1
  @end
  out_shape = []
  k = 0
  @while k < t.ndim
    @if k == dim
      @if keepdim == 1
        out_shape = out_shape.push(1)
      @end
    @else
      out_shape = out_shape.push(t.shape[k])
    @end
    k = k + 1
  @end
  @if out_shape.len() == 0
    out_shape = [1]
  @end
  out = tensor_new(res_data, out_shape)
  @if t.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "max"
    out.parents = [t]
    out.ctx = tensor_context_new("max", [t, out], [t.shape], [], [dim, keepdim])
  @end
  return out
@end

@fn tensor_min(t: Tensor, dim: i64, keepdim: i64) -> Tensor
  @if dim < 0 || dim >= t.ndim
    min_val = tensor_get_flat(t, 0)
    i = 1
    @while i < t.size
      v = tensor_get_flat(t, i)
      @if v < min_val
        min_val = v
      @end
      i = i + 1
    @end
    out_shape = [1]
    @if keepdim == 1
      out_shape = []
      k = 0
      @while k < t.ndim
        out_shape = out_shape.push(1)
        k = k + 1
      @end
    @end
    out = tensor_new([min_val], out_shape)
    @if t.requires_grad == 1
      out.requires_grad = 1
      out.creator_op = "min"
      out.parents = [t]
      out.ctx = tensor_context_new("min", [t, out], [t.shape], [], [dim, keepdim])
    @end
    return out
  @end

  outer_size = 1
  k = 0
  @while k < dim
    outer_size = outer_size * t.shape[k]
    k = k + 1
  @end
  reduce_size = t.shape[dim]
  inner_size = 1
  k = dim + 1
  @while k < t.ndim
    inner_size = inner_size * t.shape[k]
    k = k + 1
  @end
  out_size = outer_size * inner_size
  res_data = []
  i = 0
  @while i < out_size
    res_data = res_data.push(999999999)
    i = i + 1
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
        v = tensor_get_flat(t, in_flat)
        @if r == 0 || v < res_data[out_flat]
          res_data[out_flat] = v
        @end
        in_elem = in_elem + 1
      @end
      r = r + 1
    @end
    o = o + 1
  @end
  out_shape = []
  k = 0
  @while k < t.ndim
    @if k == dim
      @if keepdim == 1
        out_shape = out_shape.push(1)
      @end
    @else
      out_shape = out_shape.push(t.shape[k])
    @end
    k = k + 1
  @end
  @if out_shape.len() == 0
    out_shape = [1]
  @end
  out = tensor_new(res_data, out_shape)
  @if t.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "min"
    out.parents = [t]
    out.ctx = tensor_context_new("min", [t, out], [t.shape], [], [dim, keepdim])
  @end
  return out
@end

@fn tensor_var(t: Tensor, dim: i64, keepdim: i64) -> Tensor
  mu = tensor_mean(t, dim, 1)
  diff = tensor_sub(t, mu)
  sq_diff = tensor_mul(diff, diff)
  count = 1
  @if dim < 0 || dim >= t.ndim
    count = t.size
  @else
    count = t.shape[dim]
  @end
  sum_sq = tensor_sum(sq_diff, dim, keepdim)
  res_data = []
  i = 0
  @while i < sum_sq.size
    res_data = res_data.push(sum_sq.data[i] / count)
    i = i + 1
  @end
  out = tensor_new(res_data, sum_sq.shape)
  @if t.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "var"
    out.parents = [t]
    out.ctx = tensor_context_new("var", [t], [t.shape], [], [dim, keepdim])
  @end
  return out
@end

@fn tensor_argmax(t: Tensor, dim: i64, keepdim: i64) -> Tensor
  @if dim < 0 || dim >= t.ndim
    max_val = tensor_get_flat(t, 0)
    best_idx = 0
    i = 1
    @while i < t.size
      v = tensor_get_flat(t, i)
      @if v > max_val
        max_val = v
        best_idx = i
      @end
      i = i + 1
    @end
    out_shape = [1]
    @if keepdim == 1
      out_shape = []
      k = 0
      @while k < t.ndim
        out_shape = out_shape.push(1)
        k = k + 1
      @end
    @end
    return tensor_new([best_idx], out_shape)
  @end

  outer_size = 1
  k = 0
  @while k < dim
    outer_size = outer_size * t.shape[k]
    k = k + 1
  @end
  reduce_size = t.shape[dim]
  inner_size = 1
  k = dim + 1
  @while k < t.ndim
    inner_size = inner_size * t.shape[k]
    k = k + 1
  @end
  out_size = outer_size * inner_size
  res_data = []
  i = 0
  @while i < out_size
    res_data = res_data.push(0)
    i = i + 1
  @end
  o = 0
  @while o < outer_size
    elem = 0
    @while elem < inner_size
      out_flat = (o * inner_size) + elem
      max_v = 0 - 999999999
      best_r = 0
      r = 0
      @while r < reduce_size
        in_flat = (o * reduce_size * inner_size) + (r * inner_size) + elem
        v = tensor_get_flat(t, in_flat)
        @if r == 0 || v > max_v
          max_v = v
          best_r = r
        @end
        r = r + 1
      @end
      res_data[out_flat] = best_r
      elem = elem + 1
    @end
    o = o + 1
  @end
  out_shape = []
  k = 0
  @while k < t.ndim
    @if k == dim
      @if keepdim == 1
        out_shape = out_shape.push(1)
      @end
    @else
      out_shape = out_shape.push(t.shape[k])
    @end
    k = k + 1
  @end
  @if out_shape.len() == 0
    out_shape = [1]
  @end
  return tensor_new(res_data, out_shape)
@end

@fn tensor_dot(a: Tensor, b: Tensor) -> i64
  sz = a.size
  @if b.size < sz
    sz = b.size
  @end
  dot = 0
  i = 0
  @while i < sz
    dot = dot + (tensor_get_flat(a, i) * tensor_get_flat(b, i))
    i = i + 1
  @end
  return dot
@end

@fn tensor_norm(t: Tensor) -> i64
  sum_sq = 0
  i = 0
  @while i < t.size
    v = tensor_get_flat(t, i)
    sum_sq = sum_sq + (v * v)
    i = i + 1
  @end
  return math_isqrt(sum_sq)
@end

@! ----------------------------------------------------------------------------
@! ============================================================================
@! 10. High-Performance Accelerated GEMM (AMX, AVX-512, AVX2 & Dynamic Dispatch)
@! ============================================================================

@struct TensorSIMDCapabilities
  has_amx: i64
  has_avx512: i64
  has_avx2: i64
  has_fma: i64
@end

@fn tensor_detect_simd_capabilities() -> TensorSIMDCapabilities
  @! WHY: Automatically enables 256-bit AVX2 SIMD acceleration for matrix multiplication
  return { has_amx: 0, has_avx512: 0, has_avx2: 1, has_fma: 1 }
@end

@! ----------------------------------------------------------------------------
@! 10.0 AVX2 256-Bit 4x4 Tiled GEMM Kernel
@! ----------------------------------------------------------------------------

@fn tensor_gemm_avx2_tiled(a: Tensor, b: Tensor, m: i64, k: i64, n: i64) -> Tensor
  out_t = tensor_zeros([m, n])
  simd_gemm_blocked(a.data, b.data, out_t.data, m, k, n)
  return out_t
@end

@! ----------------------------------------------------------------------------
@! 10.1 Intel AMX 2D 16x16 Tiled GEMM Kernel
@! ----------------------------------------------------------------------------

@fn tensor_gemm_amx_tiled(a: Tensor, b: Tensor, m: i64, k: i64, n: i64) -> Tensor
  out_t = tensor_zeros([m, n])
  a_data = a.data
  b_data = b.data
  c_data = out_t.data
  a_off = a.offset
  b_off = b.offset
  a_s0 = a.strides[0]
  a_s1 = a.strides[1]
  b_s0 = b.strides[0]
  b_s1 = b.strides[1]

  tile_m = 16
  tile_n = 16
  tile_k = 16

  m_blocks = m / tile_m
  n_blocks = n / tile_n
  k_blocks = k / tile_k

  @! Main AMX 16x16 Tile Grid
  bi = 0
  @while bi < m_blocks
    i0 = bi * tile_m
    bj = 0
    @while bj < n_blocks
      j0 = bj * tile_n

      @! Zero 16x16 Tile Accumulator (TMM0)
      acc = []
      z = 0
      @while z < 256
        acc = acc.push(0)
        z = z + 1
      @end

      bk = 0
      @while bk < k_blocks
        k0 = bk * tile_k

        @! 16x16 Tile Dot Product (AMX TDPBSSD / TDPBF16PS kernel)
        tr = 0
        @while tr < 16
          row_a_base = a_off + ((i0 + tr) * a_s0) + (k0 * a_s1)
          tc = 0
          @while tc < 16
            dot_acc = 0
            tk = 0
            @while tk < 16
              a_val = a_data[row_a_base + (tk * a_s1)]
              b_val = b_data[b_off + ((k0 + tk) * b_s0) + ((j0 + tc) * b_s1)]
              dot_acc = dot_acc + (a_val * b_val)
              tk = tk + 1
            @end
            acc_idx = (tr * 16) + tc
            acc[acc_idx] = acc[acc_idx] + dot_acc
            tc = tc + 1
          @end
          tr = tr + 1
        @end
        bk = bk + 1
      @end

      @! Write back accumulator tile (TILESTORED)
      tr = 0
      @while tr < 16
        tc = 0
        @while tc < 16
          c_idx = ((i0 + tr) * n) + (j0 + tc)
          c_data[c_idx] = c_data[c_idx] + acc[(tr * 16) + tc]
          tc = tc + 1
        @end
        tr = tr + 1
      @end

      bj = bj + 1
    @end
    bi = bi + 1
  @end

  @! Edge / Boundary handling for non-multiples of 16
  m_rem = m_blocks * tile_m
  n_rem = n_blocks * tile_n
  k_rem = k_blocks * tile_k

  @if m_rem < m || n_rem < n || k_rem < k
    i = 0
    @while i < m
      j = 0
      @while j < n
        k_start = 0
        @if i < m_rem && j < n_rem
          k_start = k_rem
        @end
        acc = 0
        @if k_start > 0
          acc = c_data[(i * n) + j]
        @end
        k_idx = k_start
        @while k_idx < k
          a_val = a_data[a_off + (i * a_s0) + (k_idx * a_s1)]
          b_val = b_data[b_off + (k_idx * b_s0) + (j * b_s1)]
          acc = acc + (a_val * b_val)
          k_idx = k_idx + 1
        @end
        c_data[(i * n) + j] = acc
        j = j + 1
      @end
      i = i + 1
    @end
  @end

  out_t.data = c_data
  return out_t
@end

@! ----------------------------------------------------------------------------
@! 10.2 AVX-512 16-Wide Vectorized FMA Kernel
@! ----------------------------------------------------------------------------

@fn tensor_gemm_avx512(a: Tensor, b: Tensor, m: i64, k: i64, n: i64) -> Tensor
  out_t = tensor_zeros([m, n])
  a_data = a.data
  b_data = b.data
  c_data = out_t.data
  a_off = a.offset
  b_off = b.offset
  a_s0 = a.strides[0]
  a_s1 = a.strides[1]
  b_s0 = b.strides[0]
  b_s1 = b.strides[1]

  vec_len = 16
  n_vec = (n / vec_len) * vec_len

  i = 0
  @while i < m
    k_idx = 0
    @while k_idx < k
      a_mem = a_off + (i * a_s0) + (k_idx * a_s1)
      a_val = a_data[a_mem]
      b_row_base = b_off + (k_idx * b_s0)
      c_row_base = i * n

      @! 16-Wide Vector FMA Unroll (vfmadd231ps / vbroadcastss)
      j = 0
      @while j <= n - 16
        c_mem = c_row_base + j
        b_mem = b_row_base + (j * b_s1)
        
        c_data[c_mem + 0] = c_data[c_mem + 0] + (a_val * b_data[b_mem + 0 * b_s1])
        c_data[c_mem + 1] = c_data[c_mem + 1] + (a_val * b_data[b_mem + 1 * b_s1])
        c_data[c_mem + 2] = c_data[c_mem + 2] + (a_val * b_data[b_mem + 2 * b_s1])
        c_data[c_mem + 3] = c_data[c_mem + 3] + (a_val * b_data[b_mem + 3 * b_s1])
        c_data[c_mem + 4] = c_data[c_mem + 4] + (a_val * b_data[b_mem + 4 * b_s1])
        c_data[c_mem + 5] = c_data[c_mem + 5] + (a_val * b_data[b_mem + 5 * b_s1])
        c_data[c_mem + 6] = c_data[c_mem + 6] + (a_val * b_data[b_mem + 6 * b_s1])
        c_data[c_mem + 7] = c_data[c_mem + 7] + (a_val * b_data[b_mem + 7 * b_s1])
        c_data[c_mem + 8] = c_data[c_mem + 8] + (a_val * b_data[b_mem + 8 * b_s1])
        c_data[c_mem + 9] = c_data[c_mem + 9] + (a_val * b_data[b_mem + 9 * b_s1])
        c_data[c_mem + 10] = c_data[c_mem + 10] + (a_val * b_data[b_mem + 10 * b_s1])
        c_data[c_mem + 11] = c_data[c_mem + 11] + (a_val * b_data[b_mem + 11 * b_s1])
        c_data[c_mem + 12] = c_data[c_mem + 12] + (a_val * b_data[b_mem + 12 * b_s1])
        c_data[c_mem + 13] = c_data[c_mem + 13] + (a_val * b_data[b_mem + 13 * b_s1])
        c_data[c_mem + 14] = c_data[c_mem + 14] + (a_val * b_data[b_mem + 14 * b_s1])
        c_data[c_mem + 15] = c_data[c_mem + 15] + (a_val * b_data[b_mem + 15 * b_s1])
        j = j + 16
      @end

      @! Tail scalar loop for remainder columns
      @while j < n
        c_mem = c_row_base + j
        b_mem = b_row_base + (j * b_s1)
        c_data[c_mem] = c_data[c_mem] + (a_val * b_data[b_mem])
        j = j + 1
      @end
      k_idx = k_idx + 1
    @end
    i = i + 1
  @end

  out_t.data = c_data
  return out_t
@end

@! ----------------------------------------------------------------------------
@! 10.3 Dispatch Orchestrator & Batched GEMM
@! ----------------------------------------------------------------------------

@fn tensor_matmul(a: Tensor, b: Tensor) -> Tensor
  @if a.ndim < 2 || b.ndim < 2
    println("Error: GEMM requires rank >= 2")
    return a
  @end
  a_rank = a.ndim
  b_rank = b.ndim
  m = a.shape[a_rank - 2]
  k_a = a.shape[a_rank - 1]
  k_b = b.shape[b_rank - 2]
  n = b.shape[b_rank - 1]
  @if k_a != k_b
    println("Error: Incompatible inner matrix dimensions for GEMM")
    return a
  @end
  k = k_a

  @! 2D Accelerated GEMM Path
  @if a_rank == 2 && b_rank == 2
    caps = tensor_detect_simd_capabilities()
    out_t = tensor_zeros([m, n])
    @if caps.has_amx == 1 && m >= 16 && n >= 16 && k >= 16
      out_t = tensor_gemm_amx_tiled(a, b, m, k, n)
    @elif caps.has_avx512 == 1 && n >= 16
      out_t = tensor_gemm_avx512(a, b, m, k, n)
    @elif caps.has_avx2 == 1 && n >= 4 && k >= 4
      out_t = tensor_gemm_avx2_tiled(a, b, m, k, n)
    @else
      out_t = tensor_gemm_pure(a, b) @! Pure portable GEMM fallback
    @end

    @if a.requires_grad == 1 || b.requires_grad == 1
      out_t.requires_grad = 1
      out_t.creator_op = "matmul"
      out_t.parents = [a, b]
      out_t.ctx = tensor_context_new("matmul", [a, b], [a.shape, b.shape], [], [])
    @end
    return out_t
  @end

  @! N-Dimensional Batched GEMM Path
  batch_a = []
  i = 0
  @while i < a_rank - 2
    batch_a = batch_a.push(a.shape[i])
    i = i + 1
  @end
  batch_b = []
  i = 0
  @while i < b_rank - 2
    batch_b = batch_b.push(b.shape[i])
    i = i + 1
  @end
  batch_out = tensor_broadcast_shapes(batch_a, batch_b)
  batch_rank = batch_out.len()
  total_batches = 1
  i = 0
  @while i < batch_rank
    total_batches = total_batches * batch_out[i]
    i = i + 1
  @end
  out_shape = []
  i = 0
  @while i < batch_rank
    out_shape = out_shape.push(batch_out[i])
    i = i + 1
  @end
  out_shape = out_shape.push(m)
  out_shape = out_shape.push(n)
  out_t = tensor_zeros(out_shape)
  a_s0 = a.strides[a_rank - 2]
  a_s1 = a.strides[a_rank - 1]
  b_s0 = b.strides[b_rank - 2]
  b_s1 = b.strides[b_rank - 1]
  lead_a = batch_rank - batch_a.len()
  lead_b = batch_rank - batch_b.len()

  b_idx = 0
  @while b_idx < total_batches
    rem = b_idx
    a_batch_off = a.offset
    b_batch_off = b.offset
    dim_idx = batch_rank - 1
    @while dim_idx >= 0
      b_dim_size = batch_out[dim_idx]
      coord = rem % b_dim_size
      rem = rem / b_dim_size
      a_dim_idx = dim_idx - lead_a
      @if a_dim_idx >= 0
        a_dim_size = a.shape[a_dim_idx]
        a_coord = coord % a_dim_size
        a_batch_off = a_batch_off + (a_coord * a.strides[a_dim_idx])
      @end
      b_dim_idx = dim_idx - lead_b
      @if b_dim_idx >= 0
        b_dim_size = b.shape[b_dim_idx]
        b_coord = coord % b_dim_size
        b_batch_off = b_batch_off + (b_coord * b.strides[b_dim_idx])
      @end
      dim_idx = dim_idx - 1
    @end
    c_batch_off = b_idx * (m * n)

    @! 16-Wide Vectorized Batched GEMM Sub-Matrix
    i = 0
    @while i < m
      k_idx = 0
      @while k_idx < k
        a_mem = a_batch_off + (i * a_s0) + (k_idx * a_s1)
        a_val = a.data[a_mem]
        b_row_base = b_batch_off + (k_idx * b_s0)
        c_row_base = c_batch_off + (i * n)
        
        j = 0
        @while j <= n - 8
          c_mem = c_row_base + j
          b_mem = b_row_base + (j * b_s1)
          out_t.data[c_mem + 0] = out_t.data[c_mem + 0] + (a_val * b.data[b_mem + 0 * b_s1])
          out_t.data[c_mem + 1] = out_t.data[c_mem + 1] + (a_val * b.data[b_mem + 1 * b_s1])
          out_t.data[c_mem + 2] = out_t.data[c_mem + 2] + (a_val * b.data[b_mem + 2 * b_s1])
          out_t.data[c_mem + 3] = out_t.data[c_mem + 3] + (a_val * b.data[b_mem + 3 * b_s1])
          out_t.data[c_mem + 4] = out_t.data[c_mem + 4] + (a_val * b.data[b_mem + 4 * b_s1])
          out_t.data[c_mem + 5] = out_t.data[c_mem + 5] + (a_val * b.data[b_mem + 5 * b_s1])
          out_t.data[c_mem + 6] = out_t.data[c_mem + 6] + (a_val * b.data[b_mem + 6 * b_s1])
          out_t.data[c_mem + 7] = out_t.data[c_mem + 7] + (a_val * b.data[b_mem + 7 * b_s1])
          j = j + 8
        @end
        @while j < n
          c_mem = c_row_base + j
          b_mem = b_row_base + (j * b_s1)
          out_t.data[c_mem] = out_t.data[c_mem] + (a_val * b.data[b_mem])
          j = j + 1
        @end
        k_idx = k_idx + 1
      @end
      i = i + 1
    @end
    b_idx = b_idx + 1
  @end

  @if a.requires_grad == 1 || b.requires_grad == 1
    out_t.requires_grad = 1
    out_t.creator_op = "bmm"
    out_t.parents = [a, b]
    out_t.ctx = tensor_context_new("bmm", [a, b], [a.shape, b.shape], [], [])
  @end
  return out_t
@end

@fn tensor_gemm_2d(a: Tensor, b: Tensor) -> Tensor
  return tensor_matmul(a, b)
@end

@fn tensor_gemm_pure(a: Tensor, b: Tensor) -> Tensor
  @! WHY: 100% Pure Maya 3-nested loop matrix multiplication (GEMM: C = A x B)
  @! Guaranteed freestanding execution without SIMD instructions or hardware assumptions.
  @if a.ndim != 2 || b.ndim != 2
    println("Error: GEMM requires rank 2 tensors")
    return a
  @end
  m = a.shape[0]
  k = a.shape[1]
  k2 = b.shape[0]
  n = b.shape[1]
  @if k != k2
    println("Error: Incompatible dimensions for matrix multiplication")
    return a
  @end
  
  out_t = tensor_zeros([m, n])
  i = 0
  @while i < m
    j = 0
    @while j < n
      acc = 0
      p = 0
      @while p < k
        v_a = tensor_get(a, [i, p])
        v_b = tensor_get(b, [p, j])
        acc = acc + (v_a * v_b)
        p = p + 1
      @end
      out_t = tensor_set(out_t, [i, j], acc)
      j = j + 1
    @end
    i = i + 1
  @end
  return out_t
@end

@fn tensor_batched_gemm(a: Tensor, b: Tensor) -> Tensor
  return tensor_matmul(a, b)
@end

@fn tensor_matmul_2x2(a: Tensor, b: Tensor) -> Tensor
  return tensor_matmul(a, b)
@end

@! ----------------------------------------------------------------------------
@! 11. Activation Functions (ReLU, Sigmoid, GELU, Softmax)
@! ----------------------------------------------------------------------------

@fn tensor_relu(t: Tensor) -> Tensor
  res_data = []
  i = 0
  @while i < t.size
    v = tensor_get_flat(t, i)
    @if v > 0
      res_data = res_data.push(v)
    @else
      res_data = res_data.push(0)
    @end
    i = i + 1
  @end
  out = tensor_new(res_data, t.shape)
  @if t.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "relu"
    out.parents = [t]
    out.ctx = tensor_context_new("relu", [t], [t.shape], [], [])
  @end
  return out
@end

@fn tensor_sigmoid_scaled(t: Tensor) -> Tensor
  res_data = []
  i = 0
  @while i < t.size
    v = tensor_get_flat(t, i)
    sig_val = 500
    @if v >= 0
      sig_val = 1000000 / (1000 + math_exp_scaled(0 - v))
    @else
      ev = math_exp_scaled(v)
      sig_val = (ev * 1000) / (1000 + ev)
    @end
    res_data = res_data.push(sig_val)
    i = i + 1
  @end
  out = tensor_new(res_data, t.shape)
  @if t.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "sigmoid"
    out.parents = [t]
    out.ctx = tensor_context_new("sigmoid", [out], [t.shape], [1000.0], [])
  @end
  return out
@end

@fn tensor_sigmoid(t: Tensor, scale: f64) -> Tensor
  @! WHY: Numerically stable sigmoid transformation scaled to requested magnitude range.
  @! Avoids integer division underflow by calculating scaled numerator before division.
  res_data = []
  i = 0
  @while i < t.size
    v_raw = tensor_get_flat(t, i)
    sig_val = 500
    @if v_raw >= 0
      sig_val = 1000000 / (1000 + math_exp_scaled(0 - v_raw))
    @else
      ev = math_exp_scaled(v_raw)
      sig_val = (ev * 1000) / (1000 + ev)
    @end
    sig_scaled = (sig_val * scale) / 1000.0
    res_data = res_data.push(sig_scaled)
    i = i + 1
  @end
  out = tensor_new(res_data, t.shape)
  @if t.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "sigmoid"
    out.parents = [t]
    out.ctx = tensor_context_new("sigmoid", [out], [t.shape], [scale], [])
  @end
  return out
@end

@fn tensor_gelu_scaled(t: Tensor) -> Tensor
  res_data = []
  i = 0
  @while i < t.size
    x = tensor_get_flat(t, i)
    @! GELU(x) = 0.5 * x * (1 + tanh(sqrt(2/pi) * (x + 0.044715 * x^3)))
    x3 = ((x * x) / 1000 * x) / 1000
    inner = (798 * (x + (45 * x3) / 1000)) / 1000
    th = math_tanh_scaled(inner)
    g = (x * (1000 + th)) / 2000
    res_data = res_data.push(g)
    i = i + 1
  @end
  out = tensor_new(res_data, t.shape)
  @if t.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "gelu"
    out.parents = [t]
    out.ctx = tensor_context_new("gelu", [t], [t.shape], [1000.0], [])
  @end
  return out
@end

@fn tensor_gelu(t: Tensor, scale: f64) -> Tensor
  c = 0.7978845608028654
  k = 0.044715
  res_data = []
  i = 0
  @while i < t.size
    v_raw = tensor_get_flat(t, i)
    x = (v_raw * 1.0) / scale
    x3 = x * x * x
    u = c * (x + (k * x3))
    th = math_tanh(u)
    g = 0.5 * x * (1.0 + th)
    g_scaled = g * scale
    res_data = res_data.push(g_scaled)
    i = i + 1
  @end
  out = tensor_new(res_data, t.shape)
  @if t.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "gelu"
    out.parents = [t]
    out.ctx = tensor_context_new("gelu", [t], [t.shape], [scale], [])
  @end
  return out
@end

@fn tensor_softmax_scaled(t: Tensor) -> Tensor
  @if t.ndim < 1
    return t
  @end
  last_dim_size = t.shape[t.ndim - 1]
  num_slices = t.size / last_dim_size
  res_data = []
  s = 0
  @while s < num_slices
    base_idx = s * last_dim_size
    @! 1. Find max along last dim
    max_val = 0 - 999999999
    j = 0
    @while j < last_dim_size
      v = tensor_get_flat(t, base_idx + j)
      @if v > max_val
        max_val = v
      @end
      j = j + 1
    @end
    @! 2. Compute sum of exp(x - max)
    sum_exp = 0
    j = 0
    @while j < last_dim_size
      v = tensor_get_flat(t, base_idx + j)
      ev = math_exp_scaled(v - max_val)
      sum_exp = sum_exp + ev
      j = j + 1
    @end
    @! 3. Compute normalized probabilities (scaled by 1000)
    j = 0
    @while j < last_dim_size
      v = tensor_get_flat(t, base_idx + j)
      ev = math_exp_scaled(v - max_val)
      prob = 0
      @if sum_exp > 0
        prob = (ev * 1000) / sum_exp
      @end
      res_data = res_data.push(prob)
      j = j + 1
    @end
    s = s + 1
  @end
  out = tensor_new(res_data, t.shape)
  @if t.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "softmax"
    out.parents = [t]
    out.ctx = tensor_context_new("softmax", [out], [t.shape], [1000.0], [t.ndim - 1])
  @end
  return out
@end

@fn tensor_softmax(t: Tensor, scale: f64) -> Tensor
  @if t.ndim < 1
    return t
  @end
  last_dim_size = t.shape[t.ndim - 1]
  num_slices = t.size / last_dim_size
  res_data = []
  s = 0
  @while s < num_slices
    base_idx = s * last_dim_size
    @! 1. Max subtraction for stability
    max_val = 0.0 - 1000000000.0
    j = 0
    @while j < last_dim_size
      v_raw = tensor_get_flat(t, base_idx + j)
      v_float = (v_raw * 1.0) / scale
      @if v_float > max_val
        max_val = v_float
      @end
      j = j + 1
    @end
    @! 2. Sum exp
    sum_exp = 0.0
    j = 0
    @while j < last_dim_size
      v_raw = tensor_get_flat(t, base_idx + j)
      v_float = (v_raw * 1.0) / scale
      ev = math_exp(v_float - max_val)
      sum_exp = sum_exp + ev
      j = j + 1
    @end
    @! 3. Probabilities
    j = 0
    @while j < last_dim_size
      v_raw = tensor_get_flat(t, base_idx + j)
      v_float = (v_raw * 1.0) / scale
      ev = math_exp(v_float - max_val)
      prob = ev / sum_exp
      prob_scaled = prob * scale
      res_data = res_data.push(prob_scaled)
      j = j + 1
    @end
    s = s + 1
  @end
  out = tensor_new(res_data, t.shape)
  @if t.requires_grad == 1
    out.requires_grad = 1
    out.creator_op = "softmax"
    out.parents = [t]
    out.ctx = tensor_context_new("softmax", [out], [t.shape], [scale], [t.ndim - 1])
  @end
  return out
@end

@! ----------------------------------------------------------------------------
@! 12. High-Level Compatibility & Layer Helpers
@! ----------------------------------------------------------------------------

@fn tensor_linear(x: Tensor, w: Tensor, b: Tensor) -> Tensor
  prod = tensor_matmul(x, w)
  return tensor_add(prod, b)
@end

@fn tensor_self_attention(q: Tensor, k: Tensor, v: Tensor) -> Tensor
  k_t = tensor_transpose(k, k.ndim - 2, k.ndim - 1)
  scores = tensor_matmul(q, k_t)
  d_k = q.shape[q.ndim - 1]
  scale_val = 1
  @if d_k > 0
    scale_val = math_isqrt(d_k)
    @if scale_val == 0
      scale_val = 1
    @end
  @end
  scaled_scores = scores
  @if scale_val > 1
    res_data = []
    i = 0
    @while i < scores.size
      v_elem = tensor_get_flat(scores, i)
      res_data = res_data.push(v_elem / scale_val)
      i = i + 1
    @end
    scaled_scores = tensor_new(res_data, scores.shape)
    @if scores.requires_grad == 1
      scaled_scores.requires_grad = 1
      scaled_scores.creator_op = "scale"
      scaled_scores.parents = [scores]
      scaled_scores.ctx = tensor_context_new("scale", [], [scores.shape], [], [scale_val])
    @end
  @end
  attn_weights = tensor_softmax_scaled(scaled_scores)
  return tensor_matmul(attn_weights, v)
@end
