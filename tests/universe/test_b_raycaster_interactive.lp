import "universe/b_core/io"
import "universe/b_core/string"
import "universe/b_core/math_audio"

@fn fcos(x)
  pi_half = float(1, 57079, 100000)
  return fsin(fadd(x, pi_half))
@end

@fn main()
  map_ptr = sys_mmap(0, 64, 3, 34, 0 - 1, 0)
  sys_poke8(map_ptr + 0, 1) sys_poke8(map_ptr + 1, 1) sys_poke8(map_ptr + 2, 1) sys_poke8(map_ptr + 3, 1) sys_poke8(map_ptr + 4, 1) sys_poke8(map_ptr + 5, 1) sys_poke8(map_ptr + 6, 1) sys_poke8(map_ptr + 7, 1)
  sys_poke8(map_ptr + 8, 1) sys_poke8(map_ptr + 9, 0) sys_poke8(map_ptr + 10,0) sys_poke8(map_ptr + 11,0) sys_poke8(map_ptr + 12,0) sys_poke8(map_ptr + 13,0) sys_poke8(map_ptr + 14,0) sys_poke8(map_ptr + 15,1)
  sys_poke8(map_ptr + 16,1) sys_poke8(map_ptr + 17,0) sys_poke8(map_ptr + 18,1) sys_poke8(map_ptr + 19,1) sys_poke8(map_ptr + 20,0) sys_poke8(map_ptr + 21,1) sys_poke8(map_ptr + 22,0) sys_poke8(map_ptr + 23,1)
  sys_poke8(map_ptr + 24,1) sys_poke8(map_ptr + 25,0) sys_poke8(map_ptr + 26,1) sys_poke8(map_ptr + 27,0) sys_poke8(map_ptr + 28,0) sys_poke8(map_ptr + 29,1) sys_poke8(map_ptr + 30,0) sys_poke8(map_ptr + 31,1)
  sys_poke8(map_ptr + 32,1) sys_poke8(map_ptr + 33,0) sys_poke8(map_ptr + 34,0) sys_poke8(map_ptr + 35,0) sys_poke8(map_ptr + 36,0) sys_poke8(map_ptr + 37,0) sys_poke8(map_ptr + 38,0) sys_poke8(map_ptr + 39,1)
  sys_poke8(map_ptr + 40,1) sys_poke8(map_ptr + 41,0) sys_poke8(map_ptr + 42,1) sys_poke8(map_ptr + 43,1) sys_poke8(map_ptr + 44,1) sys_poke8(map_ptr + 45,1) sys_poke8(map_ptr + 46,0) sys_poke8(map_ptr + 47,1)
  sys_poke8(map_ptr + 48,1) sys_poke8(map_ptr + 49,0) sys_poke8(map_ptr + 50,0) sys_poke8(map_ptr + 51,0) sys_poke8(map_ptr + 52,0) sys_poke8(map_ptr + 53,0) sys_poke8(map_ptr + 54,0) sys_poke8(map_ptr + 55,1)
  sys_poke8(map_ptr + 56,1) sys_poke8(map_ptr + 57,1) sys_poke8(map_ptr + 58,1) sys_poke8(map_ptr + 59,1) sys_poke8(map_ptr + 60,1) sys_poke8(map_ptr + 61,1) sys_poke8(map_ptr + 62,1) sys_poke8(map_ptr + 63,1)
  
  WIDTH = 80
  HEIGHT = 20
  buf = sys_mmap(0, WIDTH * HEIGHT + HEIGHT, 3, 34, 0 - 1, 0)
  input_buf = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  
  px = float(2, 5, 10)
  py = float(2, 5, 10)
  pa = float(0, 0, 10) @! Facing right
  
  FOV = float(1, 047, 1000) @! ~60 degrees
  speed = float(0, 5, 10)
  rot_speed = float(0, 2, 10)
  
  sys_syscall(1, 1, "\033[2J\033[H", 7, 0, 0, 0) @! Clear screen
  
  running = 1
  @while running == 1
    
    @! 1. Clear frame buffer
    i = 0
    @while i < HEIGHT
      j = 0
      @while j < WIDTH
        sys_poke8(buf + i * (WIDTH + 1) + j, 32) @! space
        j = j + 1
      @end
      sys_poke8(buf + i * (WIDTH + 1) + WIDTH, 10) @! newline
      i = i + 1
    @end
    
    @! 2. Raycast
    col = 0
    @while col < WIDTH
      half_fov = fdiv(FOV, int_to_float(2))
      start_a = fsub(pa, half_fov)
      pct = fdiv(int_to_float(col), int_to_float(WIDTH))
      ray_a = fadd(start_a, fmul(pct, FOV))
      
      eye_x = fcos(ray_a)
      eye_y = fsin(ray_a)
      
      distance = int_to_float(0)
      hit = 0
      
      @while hit == 0 && flt(distance, int_to_float(12)) == 1
        distance = fadd(distance, float(0, 1, 10))
        
        test_x = fadd(px, fmul(eye_x, distance))
        test_y = fadd(py, fmul(eye_y, distance))
        
        t_x = float_to_int(test_x)
        t_y = float_to_int(test_y)
        
        @if t_x < 0 || t_x >= 8 || t_y < 0 || t_y >= 8
          hit = 1
          distance = int_to_float(12)
        @else
          cell = sys_peek8(map_ptr + t_y * 8 + t_x)
          @if cell == 1
            hit = 1
          @end
        @end
      @end
      
      f_height = int_to_float(HEIGHT)
      f_two = int_to_float(2)
      
      ceiling = fdiv(f_height, f_two)
      wall_h = fdiv(f_height, distance)
      ceiling = fsub(ceiling, wall_h)
      floor_y = fadd(fdiv(f_height, f_two), wall_h)
      
      c_int = float_to_int(ceiling)
      f_int = float_to_int(floor_y)
      
      @if c_int < 0 c_int = 0 @end
      @if f_int >= HEIGHT f_int = HEIGHT - 1 @end
      
      row = 0
      @while row < HEIGHT
        @if row < c_int
          @! ceiling (sky)
          sys_poke8(buf + row * (WIDTH + 1) + col, 32)
        @elif row > f_int
          @! floor
          sys_poke8(buf + row * (WIDTH + 1) + col, 46) @! '.'
        @else
          @! wall shading
          char = 35 @! '#'
          @if fgt(distance, int_to_float(2)) == 1 char = 37 @end @! '%'
          @if fgt(distance, int_to_float(4)) == 1 char = 61 @end @! '='
          @if fgt(distance, int_to_float(6)) == 1 char = 45 @end @! '-'
          sys_poke8(buf + row * (WIDTH + 1) + col, char)
        @end
        row = row + 1
      @end
      
      col = col + 1
    @end
    
    @! Move cursor to top-left (ANSI) and print frame
    sys_syscall(1, 1, "\033[H", 3, 0, 0, 0)
    sys_syscall(1, 1, buf, HEIGHT * (WIDTH + 1), 0, 0, 0)
    string_println("NATIVE MAYA DOOM | W/S: Move | A/D: Rotate | Q: Quit")
    
    @! 3. Input Handling
    read_len = sys_read(0, input_buf, 1)
    @if read_len > 0
      key = sys_peek8(input_buf)
      
      @if key == 113 @! 'q'
        running = 0
      @elif key == 97 @! 'a'
        pa = fsub(pa, rot_speed)
      @elif key == 100 @! 'd'
        pa = fadd(pa, rot_speed)
      @elif key == 119 @! 'w'
        dx = fmul(fcos(pa), speed)
        dy = fmul(fsin(pa), speed)
        px = fadd(px, dx)
        py = fadd(py, dy)
      @elif key == 115 @! 's'
        dx = fmul(fcos(pa), speed)
        dy = fmul(fsin(pa), speed)
        px = fsub(px, dx)
        py = fsub(py, dy)
      @end
      
      @! Keep pa within 0 to 2PI bounds to avoid float drift
      pi2 = float(6, 28318, 100000)
      @if fgt(pa, pi2) == 1 pa = fsub(pa, pi2) @end
      @if flt(pa, int_to_float(0)) == 1 pa = fadd(pa, pi2) @end
    @end
    
  @end
  
  sys_syscall(1, 1, "\033[2J\033[H", 7, 0, 0, 0)
  sys_exit(0)
@end

@fn sys_read(fd, buf, count)
  return sys_syscall(0, fd, buf, count, 0, 0, 0)
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end
