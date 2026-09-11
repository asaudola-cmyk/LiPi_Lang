@! ============================================================================
@! UNIVERSE B NATIVE TENSOR ENGINE
@! 100% Pure Raw Pointer Math (Float64)
@! ============================================================================

@! Tensor struct memory layout (32 bytes):
@! offset 0: data_ptr (pointer to F64 data)
@! offset 8: shape_ptr (pointer to i64 shape array)
@! offset 16: ndim (i64)
@! offset 24: size (i64)

@fn tensor_new(shape_ptr, ndim)
  @! 1. Calculate total size
  i = 0
  size = 1
  @while i < ndim
    dim = sys_peek(shape_ptr + (i * 8))
    size = size * dim
    i = i + 1
  @end
  
  @! 2. Allocate Tensor struct (32 bytes)
  t_ptr = sys_mmap(0, 32, 3, 34, 0 - 1, 0)
  
  @! 3. Allocate Data buffer (size * 8 bytes)
  @if size > 0
    data_size = size * 8
    @! Round up to page size (4096)
    pages = (data_size / 4096) + 1
    data_ptr = sys_mmap(0, pages * 4096, 3, 34, 0 - 1, 0)
  @else
    data_ptr = 0
  @end
  
  @! 4. Store fields
  sys_poke(t_ptr + 0, data_ptr)
  sys_poke(t_ptr + 8, shape_ptr)
  sys_poke(t_ptr + 16, ndim)
  sys_poke(t_ptr + 24, size)
  
  return t_ptr
@end

@fn tensor_set_data(t_ptr, idx, f_val)
  data_ptr = sys_peek(t_ptr + 0)
  @! Since data is raw 64-bit float, we just sys_poke it!
  sys_poke(data_ptr + (idx * 8), f_val)
  return 0
@end

@fn tensor_get_data(t_ptr, idx)
  data_ptr = sys_peek(t_ptr + 0)
  return sys_peek(data_ptr + (idx * 8))
@end

@fn tensor_add(t1, t2)
  size1 = sys_peek(t1 + 24)
  size2 = sys_peek(t2 + 24)
  @if size1 != size2
    @! Broadcasting not implemented yet in Native B
    return 0
  @end
  
  @! Create result tensor
  shape_ptr = sys_peek(t1 + 8)
  ndim = sys_peek(t1 + 16)
  out_t = tensor_new(shape_ptr, ndim)
  
  out_data = sys_peek(out_t + 0)
  d1 = sys_peek(t1 + 0)
  d2 = sys_peek(t2 + 0)
  
  i = 0
  @while i < size1
    v1 = sys_peek(d1 + (i * 8))
    v2 = sys_peek(d2 + (i * 8))
    v_out = fadd(v1, v2)
    sys_poke(out_data + (i * 8), v_out)
    i = i + 1
  @end
  
  return out_t
@end

@fn tensor_dot_2d(t1, t2)
  @! Matrix multiplication for 2D tensors
  ndim1 = sys_peek(t1 + 16)
  ndim2 = sys_peek(t2 + 16)
  @if ndim1 != 2 return 0 @end
  @if ndim2 != 2 return 0 @end
  
  s1 = sys_peek(t1 + 8)
  s2 = sys_peek(t2 + 8)
  
  m = sys_peek(s1 + 0)
  k1 = sys_peek(s1 + 8)
  k2 = sys_peek(s2 + 0)
  n = sys_peek(s2 + 8)
  
  @if k1 != k2 return 0 @end
  
  @! Create output shape [m, n]
  out_shape = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  sys_poke(out_shape + 0, m)
  sys_poke(out_shape + 8, n)
  out_t = tensor_new(out_shape, 2)
  
  d1 = sys_peek(t1 + 0)
  d2 = sys_peek(t2 + 0)
  out_data = sys_peek(out_t + 0)
  
  i = 0
  @while i < m
    j = 0
    @while j < n
      @! Dot product of row i (t1) and col j (t2)
      sum = int_to_float(0)
      k = 0
      @while k < k1
        idx1 = (i * k1) + k
        idx2 = (k * n) + j
        v1 = sys_peek(d1 + (idx1 * 8))
        v2 = sys_peek(d2 + (idx2 * 8))
        prod = fmul(v1, v2)
        sum = fadd(sum, prod)
        k = k + 1
      @end
      out_idx = (i * n) + j
      sys_poke(out_data + (out_idx * 8), sum)
      j = j + 1
    @end
    i = i + 1
  @end
  
  return out_t
@end


@fn tensor_relu(t)
  size = sys_peek(t + 24)
  shape_ptr = sys_peek(t + 8)
  ndim = sys_peek(t + 16)
  
  out_t = tensor_new(shape_ptr, ndim)
  out_data = sys_peek(out_t + 0)
  in_data = sys_peek(t + 0)
  
  f_zero = int_to_float(0)
  
  i = 0
  @while i < size
    v = sys_peek(in_data + (i * 8))
    @if fgt(v, f_zero) == 1
      sys_poke(out_data + (i * 8), v)
    @else
      sys_poke(out_data + (i * 8), f_zero)
    @end
    i = i + 1
  @end
  
  return out_t
@end

@fn tensor_add_bias_2d(t_in, t_bias)
  s1 = sys_peek(t_in + 8)
  s2 = sys_peek(t_bias + 8)
  
  m = sys_peek(s1 + 0)
  n = sys_peek(s1 + 8)
  
  bias_n = sys_peek(s2 + 0)
  @if n != bias_n
    return 0
  @end
  
  out_t = tensor_new(s1, 2)
  out_data = sys_peek(out_t + 0)
  in_data = sys_peek(t_in + 0)
  bias_data = sys_peek(t_bias + 0)
  
  i = 0
  @while i < m
    j = 0
    @while j < n
      idx = (i * n) + j
      v_in = sys_peek(in_data + (idx * 8))
      v_bias = sys_peek(bias_data + (j * 8))
      v_out = fadd(v_in, v_bias)
      sys_poke(out_data + (idx * 8), v_out)
      j = j + 1
    @end
    i = i + 1
  @end
  
  return out_t
@end
