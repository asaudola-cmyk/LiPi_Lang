@struct Complex
  real: i64
  imag: i64
@end

// WHY: Adds two complex numbers using standard anonymous struct literal syntax
@fn complex_add(a, b)
  return { real: a.real + b.real, imag: a.imag + b.imag }
@end

@fn area_circle(radius)
  return 3 * radius * radius
@end

@fn clamp(val, min_val, max_val)
  @if val < min_val
    return min_val
  @elif val > max_val
    return max_val
  @else
    return val
  @end
@end
