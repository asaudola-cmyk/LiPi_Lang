import "universe/b_core/io"
import "universe/b_core/string"
import "universe/b_core/fs"
import "universe/b_core/math_3d"

@! Ray-Sphere Intersection
@! Returns t (distance along ray). Returns -1.0 if no hit.
@fn hit_sphere(center, radius, ray_origin, ray_dir)
  oc = vec3_sub(ray_origin, center)
  
  a = vec3_dot(ray_dir, ray_dir)
  b = fmul(int_to_float(2), vec3_dot(oc, ray_dir))
  c = fsub(vec3_dot(oc, oc), fmul(radius, radius))
  
  discriminant = fsub(fmul(b, b), fmul(fmul(int_to_float(4), a), c))
  
  @if flt(discriminant, int_to_float(0)) == 1
    return fsub(int_to_float(0), int_to_float(1))
  @end
  
  @! t = (-b - sqrt(discriminant)) / (2a)
  num = fsub(int_to_float(0), b)
  num = fsub(num, fsqrt(discriminant))
  den = fmul(int_to_float(2), a)
  
  return fdiv(num, den)
@end

@fn float(int_part, frac_part, divisor)
  f_int = int_to_float(int_part)
  f_frac = int_to_float(frac_part)
  f_div = int_to_float(divisor)
  return fadd(f_int, fdiv(f_frac, f_div))
@end

@fn float_neg(int_part, frac_part, divisor)
  f_int = int_to_float(int_part)
  f_frac = int_to_float(frac_part)
  f_div = int_to_float(divisor)
  f_val = fadd(f_int, fdiv(f_frac, f_div))
  return fsub(int_to_float(0), f_val)
@end

@! Quick helper to write a string to fd
@fn write_str(fd, str)
  fs_write(fd, str, string_len(str))
  return 0
@end

@! Quick helper to write an integer to fd (as string)
@fn write_int_to_fd(fd, val)
  @! Simple itoa for up to 3 digits (since we write 0-255 colors)
  @if val < 0 val = 0 @end
  @if val > 255 val = 255 @end
  
  buf = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  
  @if val == 0
    sys_poke8(buf, 48)
    sys_poke8(buf+1, 0)
    fs_write(fd, buf, 1)
    return 0
  @end
  
  idx = 0
  temp = val
  @while temp > 0
    temp = temp / 10
    idx = idx + 1
  @end
  
  sys_poke8(buf + idx, 0)
  temp = val
  i = idx - 1
  @while temp > 0
    digit = temp - ((temp / 10) * 10)
    sys_poke8(buf + i, 48 + digit)
    temp = temp / 10
    i = i - 1
  @end
  
  fs_write(fd, buf, idx)
  return 0
@end

@fn main()
  string_println("=== Native Maya 3D Raytracer ===")
  
  width = 256
  height = 256
  
  fd = fs_open_write("render.ppm")
  write_str(fd, "P3\n256 256\n255\n")
  
  sphere_center = vec3_new(int_to_float(0), int_to_float(0), float_neg(5, 0, 1))
  sphere_radius = int_to_float(2)
  
  light_pos = vec3_new(int_to_float(5), int_to_float(5), int_to_float(0))
  
  ray_origin = vec3_new(int_to_float(0), int_to_float(0), int_to_float(0))
  
  y = 0
  @while y < height
    x = 0
    @while x < width
      @! map x,y to -1.0 to 1.0
      @! u = (x / width) * 2 - 1
      f_x = int_to_float(x)
      f_w = int_to_float(width)
      u = fsub(fmul(fdiv(f_x, f_w), int_to_float(2)), int_to_float(1))
      
      @! v = -((y / height) * 2 - 1)  (invert Y)
      f_y = int_to_float(y)
      f_h = int_to_float(height)
      v = fsub(int_to_float(0), fsub(fmul(fdiv(f_y, f_h), int_to_float(2)), int_to_float(1)))
      
      ray_dir = vec3_normalize(vec3_new(u, v, float_neg(1, 0, 1)))
      
      t = hit_sphere(sphere_center, sphere_radius, ray_origin, ray_dir)
      
      r = 0 g = 0 b = 0
      
      @if fgt(t, int_to_float(0)) == 1
        @! Hit! Calculate lighting.
        hit_point = vec3_add(ray_origin, vec3_scale(ray_dir, t))
        normal = vec3_normalize(vec3_sub(hit_point, sphere_center))
        light_dir = vec3_normalize(vec3_sub(light_pos, hit_point))
        
        diffuse = vec3_dot(normal, light_dir)
        @if flt(diffuse, int_to_float(0)) == 1 diffuse = int_to_float(0) @end
        
        @! Base color Red (255, 50, 50) scaled by diffuse
        r = float_to_int(fmul(int_to_float(255), diffuse))
        g = float_to_int(fmul(int_to_float(50), diffuse))
        b = float_to_int(fmul(int_to_float(50), diffuse))
        
        @! Ambient light
        r = r + 20
        g = g + 10
        b = b + 10
      @else
        @! Background color (gradient)
        b = 100 + (y / 2)
      @end
      
      write_int_to_fd(fd, r) write_str(fd, " ")
      write_int_to_fd(fd, g) write_str(fd, " ")
      write_int_to_fd(fd, b) write_str(fd, "\n")
      
      x = x + 1
    @end
    y = y + 1
  @end
  
  fs_close(fd)
  string_println("Render saved to render.ppm!")
  sys_exit(0)
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end
