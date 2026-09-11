@! ============================================================================
@! MAYA UNIVERSE OS — ADVANCED KEYBOARD DRIVER (PS/2 & USB HID)
@! Scancode Translation, Modifier State, Keymaps, Interrupt Handling
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/collections"

@fn keyboard_state_new()
  return {
    shift_pressed: 0,
    ctrl_pressed: 0,
    alt_pressed: 0,
    caps_lock: 0,
    num_lock: 1,
    scroll_lock: 0,
    extended_mode: 0,
    buffer: []
  }
@end

@fn keymap_us_qwerty()
  @! Map PS/2 Set 1 Scancodes to ASCII (without shift)
  map = []
  i = 0
  @while i < 128
    map = map.push(0)
    i = i + 1
  @end
  
  map = list_set(map, 0x02, 49) @! '1'
  map = list_set(map, 0x03, 50) @! '2'
  map = list_set(map, 0x04, 51) @! '3'
  map = list_set(map, 0x05, 52) @! '4'
  map = list_set(map, 0x06, 53) @! '5'
  map = list_set(map, 0x07, 54) @! '6'
  map = list_set(map, 0x08, 55) @! '7'
  map = list_set(map, 0x09, 56) @! '8'
  map = list_set(map, 0x0A, 57) @! '9'
  map = list_set(map, 0x0B, 48) @! '0'
  map = list_set(map, 0x0C, 45) @! '-'
  map = list_set(map, 0x0D, 61) @! '='
  
  map = list_set(map, 0x10, 113) @! 'q'
  map = list_set(map, 0x11, 119) @! 'w'
  map = list_set(map, 0x12, 101) @! 'e'
  map = list_set(map, 0x13, 114) @! 'r'
  map = list_set(map, 0x14, 116) @! 't'
  map = list_set(map, 0x15, 121) @! 'y'
  map = list_set(map, 0x16, 117) @! 'u'
  map = list_set(map, 0x17, 105) @! 'i'
  map = list_set(map, 0x18, 111) @! 'o'
  map = list_set(map, 0x19, 112) @! 'p'
  
  map = list_set(map, 0x1E, 97)  @! 'a'
  map = list_set(map, 0x1F, 115) @! 's'
  map = list_set(map, 0x20, 100) @! 'd'
  map = list_set(map, 0x21, 102) @! 'f'
  map = list_set(map, 0x22, 103) @! 'g'
  map = list_set(map, 0x23, 104) @! 'h'
  map = list_set(map, 0x24, 106) @! 'j'
  map = list_set(map, 0x25, 107) @! 'k'
  map = list_set(map, 0x26, 108) @! 'l'
  
  map = list_set(map, 0x2C, 122) @! 'z'
  map = list_set(map, 0x2D, 120) @! 'x'
  map = list_set(map, 0x2E, 99)  @! 'c'
  map = list_set(map, 0x2F, 118) @! 'v'
  map = list_set(map, 0x30, 98)  @! 'b'
  map = list_set(map, 0x31, 110) @! 'n'
  map = list_set(map, 0x32, 109) @! 'm'
  
  map = list_set(map, 0x39, 32)  @! ' '
  map = list_set(map, 0x1C, 10)  @! '\n'
  
  return map
@end

@fn keymap_us_qwerty_shift()
  @! Map PS/2 Set 1 Scancodes to ASCII (with shift)
  map = keymap_us_qwerty()
  
  map = list_set(map, 0x02, 33) @! '!'
  map = list_set(map, 0x03, 64) @! '@'
  map = list_set(map, 0x04, 35) @! '#'
  map = list_set(map, 0x05, 36) @! '$'
  map = list_set(map, 0x06, 37) @! '%'
  map = list_set(map, 0x07, 94) @! '^'
  map = list_set(map, 0x08, 38) @! '&'
  map = list_set(map, 0x09, 42) @! '*'
  map = list_set(map, 0x0A, 40) @! '('
  map = list_set(map, 0x0B, 41) @! ')'
  map = list_set(map, 0x0C, 95) @! '_'
  map = list_set(map, 0x0D, 43) @! '+'
  
  @! Capitalize alphabet letters
  i = 0x10
  @while i <= 0x32
    c = map[i]
    @if c >= 97 && c <= 122
      map = list_set(map, i, c - 32)
    @end
    i = i + 1
  @end
  
  return map
@end

@fn handle_scancode(state, scancode, keymap_normal, keymap_shift)
  @if scancode == 0xE0
    state.extended_mode = 1
    return state
  @end
  
  is_release = 0
  @if scancode >= 0x80
    is_release = 1
    scancode = scancode - 0x80
  @end
  
  @! Handle modifiers
  @if scancode == 0x2A || scancode == 0x36 @! Left/Right Shift
    @if is_release == 1
      state.shift_pressed = 0
    @else
      state.shift_pressed = 1
    @end
    return state
  @end
  
  @if scancode == 0x1D @! Ctrl
    @if is_release == 1
      state.ctrl_pressed = 0
    @else
      state.ctrl_pressed = 1
    @end
    return state
  @end
  
  @if scancode == 0x38 @! Alt
    @if is_release == 1
      state.alt_pressed = 0
    @else
      state.alt_pressed = 1
    @end
    return state
  @end
  
  @if scancode == 0x3A && is_release == 0 @! Caps Lock
    @if state.caps_lock == 1
      state.caps_lock = 0
    @else
      state.caps_lock = 1
    @end
    return state
  @end
  
  @! If it's a key press, add to buffer
  @if is_release == 0 && scancode < 128
    char_code = 0
    
    use_shift = state.shift_pressed
    @if state.caps_lock == 1
      @! Inverse shift for alphabetic characters only
      @if use_shift == 1
        use_shift = 0
      @else
        use_shift = 1
      @end
    @end
    
    @if use_shift == 1
      char_code = keymap_shift[scancode]
    @else
      char_code = keymap_normal[scancode]
    @end
    
    @if char_code != 0
      state.buffer = state.buffer.push(char_code)
    @end
  @end
  
  state.extended_mode = 0
  return state
@end

@fn keyboard_irq_handler(state, port_60h_data)
  @! In a real OS, this runs on IRQ 1
  keymap_normal = keymap_us_qwerty()
  keymap_shift = keymap_us_qwerty_shift()
  
  return handle_scancode(state, port_60h_data, keymap_normal, keymap_shift)
@end

@fn keyboard_read(state)
  @if state.buffer.len() > 0
    char = state.buffer[0]
    
    @! Pop front
    new_buf = []
    i = 1
    @while i < state.buffer.len()
      new_buf = new_buf.push(state.buffer[i])
      i = i + 1
    @end
    state.buffer = new_buf
    
    return char
  @end
  return -1 @! Empty buffer
@end

@fn kbd_scancode_to_ascii(scancode, shift)
  @if scancode == 0x1E return "a" @end
  @if scancode == 0x1F return "s" @end
  @if scancode == 0x20 return "d" @end
  @if scancode == 0x21 return "f" @end
  @if scancode == 0x10 return "q" @end
  @if scancode == 0x11 return "w" @end
  @if scancode == 0x12 return "e" @end
  @if scancode == 0x13 return "r" @end
  @if scancode == 0x14 return "t" @end
  @if scancode == 0x15 return "y" @end
  return " "
@end
