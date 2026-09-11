import "universe/b_core/io"
import "universe/b_core/string"
import "universe/b_core/fs"
import "universe/b_core/thread"
import "universe/b_core/math_3d"

@! Reusing some float helpers
@fn float(int_part, frac_part, divisor)
  return fadd(int_to_float(int_part), fdiv(int_to_float(frac_part), int_to_float(divisor)))
@end

@fn float_neg(int_part, frac_part, divisor)
  f_val = fadd(int_to_float(int_part), fdiv(int_to_float(frac_part), int_to_float(divisor)))
  return fsub(int_to_float(0), f_val)
@end

@! Physics Engine Constants
@fn main()
  @! Ball 1
  x1 = float(10, 0, 1)
  y1 = float(5, 0, 1)
  vx1 = float(15, 0, 1)
  vy1 = float(0, 0, 1)
  
  @! Ball 2
  x2 = float(30, 0, 1)
  y2 = float(8, 0, 1)
  vx2 = float_neg(12, 0, 1)
  vy2 = float(0, 0, 1)
  
  g = float(30, 0, 1)   @! Gravity
  dt = float(0, 5, 100) @! 0.05 seconds per frame
  e = float(0, 85, 100) @! Elasticity 0.85
  
  width = 60
  height = 20
  
  f_width = int_to_float(width - 1)
  f_height = int_to_float(height - 1)
  f_zero = int_to_float(0)
  
  frame = 0
  @while frame < 100
    @! Clear screen and move cursor to home
    sys_syscall(1, 1, "\033[2J\033[H", 7, 0, 0, 0)
    
    @! Physics Update Ball 1
    vy1 = fadd(vy1, fmul(g, dt))
    x1 = fadd(x1, fmul(vx1, dt))
    y1 = fadd(y1, fmul(vy1, dt))
    
    @! Floor collision 1
    @if fgt(y1, f_height) == 1
      y1 = f_height
      vy1 = fmul(fsub(f_zero, vy1), e)
    @end
    @! Wall collision 1
    @if flt(x1, f_zero) == 1
      x1 = f_zero
      vx1 = fmul(fsub(f_zero, vx1), e)
    @end
    @if fgt(x1, f_width) == 1
      x1 = f_width
      vx1 = fmul(fsub(f_zero, vx1), e)
    @end
    
    @! Physics Update Ball 2
    vy2 = fadd(vy2, fmul(g, dt))
    x2 = fadd(x2, fmul(vx2, dt))
    y2 = fadd(y2, fmul(vy2, dt))
    
    @! Floor collision 2
    @if fgt(y2, f_height) == 1
      y2 = f_height
      vy2 = fmul(fsub(f_zero, vy2), e)
    @end
    @! Wall collision 2
    @if flt(x2, f_zero) == 1
      x2 = f_zero
      vx2 = fmul(fsub(f_zero, vx2), e)
    @end
    @if fgt(x2, f_width) == 1
      x2 = f_width
      vx2 = fmul(fsub(f_zero, vx2), e)
    @end
    
    @! Render Grid
    grid = sys_mmap(0, (width + 1) * height, 3, 34, 0 - 1, 0)
    
    i = 0
    @while i < height
      j = 0
      @while j < width
        sys_poke8(grid + (i * (width + 1)) + j, 46) @! '.' character
        j = j + 1
      @end
      sys_poke8(grid + (i * (width + 1)) + width, 10) @! '\n'
      i = i + 1
    @end
    
    @! Place balls
    ix1 = float_to_int(x1)
    iy1 = float_to_int(y1)
    ix2 = float_to_int(x2)
    iy2 = float_to_int(y2)
    
    @if ix1 >= 0 && ix1 < width && iy1 >= 0 && iy1 < height
      sys_poke8(grid + (iy1 * (width + 1)) + ix1, 79) @! 'O'
    @end
    
    @if ix2 >= 0 && ix2 < width && iy2 >= 0 && iy2 < height
      sys_poke8(grid + (iy2 * (width + 1)) + ix2, 64) @! '@'
    @end
    
    @! Draw to screen
    sys_syscall(1, 1, grid, (width + 1) * height, 0, 0, 0)
    
    thread_sleep_ms(50) @! 20 FPS
    frame = frame + 1
  @end
  
  sys_exit(0)
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end
