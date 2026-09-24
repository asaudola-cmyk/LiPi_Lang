@! ============================================================================
@! LIPI FREESTANDING RUNTIME & STANDARD ENGINE (src/runtime/runtime.lp)
@! 100% Written in Pure Lipi Language — Zero libc.so Dependencies
@! Architecture: x86_64 Linux Direct Kernel Gateway
@! ============================================================================

import "runtime/lipi_syscall"
import "runtime/lipi_gc"

@! ----------------------------------------------------------------------------
@! 1. Type Identifiers & Tags
@! ----------------------------------------------------------------------------
@fn TYPE_RAW_BYTES() return 0 @end
@fn TYPE_LIPI_STRING() return 1 @end
@fn TYPE_LIPI_ARRAY() return 2 @end
@fn TYPE_LIPI_MAP() return 3 @end
@fn TYPE_LIPI_STRUCT() return 4 @end
@fn TYPE_LIPI_CLOSURE() return 5 @end
@fn TYPE_LIPI_BOXED_FLOAT() return 6 @end

@! ----------------------------------------------------------------------------
@! 2. Memory Structures
@! ----------------------------------------------------------------------------
@struct LipiArray
  length: 0,
  capacity: 0,
  element_size: 8,
  data: 0
@end

@struct LipiString
  length: 0,
  buffer: 0
@end

@struct LipiMapEntry
  key: "",
  value: 0,
  occupied: 0
@end

@struct LipiMap
  capacity: 16,
  size: 0,
  entries: 0
@end

@! ----------------------------------------------------------------------------
@! 3. Core Memory Allocation & GC Bridge
@! ----------------------------------------------------------------------------
@fn lipi_runtime_init()
  // WHY: Initializes the sovereign slab/bump GC runtime arena on startup.
  lipi_init_gc()
@end

@fn lipi_alloc_typed(size, type_id)
  // WHY: Allocates memory tagged with a runtime type identifier for type safety.
  @if size <= 0
    size = 1
  @end
  return gc_alloc_typed(size, type_id)
@end

@fn is_lipi_string_ptr(val)
  // WHY: Verifies whether a 64-bit integer pointer is a valid LipiString object.
  @if val == 0 return 0 @end
  @if (val & 7) != 0 return 0 @end
  @if val < 65536 return 0 @end
  base = gc_base(val)
  @if base == 0 || base != val return 0 @end
  return gc_get_type_id(val) == TYPE_LIPI_STRING()
@end

@fn is_lipi_array_ptr(val)
  // WHY: Verifies whether a pointer references an allocated LipiArray object.
  @if val == 0 return 0 @end
  @if (val & 7) != 0 return 0 @end
  @if val < 65536 return 0 @end
  base = gc_base(val)
  @if base == 0 || base != val return 0 @end
  return gc_get_type_id(val) == TYPE_LIPI_ARRAY()
@end

@fn is_lipi_map_ptr(val)
  // WHY: Verifies whether a pointer references an allocated LipiMap object.
  @if val == 0 return 0 @end
  @if (val & 7) != 0 return 0 @end
  @if val < 65536 return 0 @end
  base = gc_base(val)
  @if base == 0 || base != val return 0 @end
  return gc_get_type_id(val) == TYPE_LIPI_MAP()
@end

@! ----------------------------------------------------------------------------
@! 4. Dynamic Array Operations (0% Libc, Direct Freestanding Heap)
@! ----------------------------------------------------------------------------
@fn lipi_array_new(initial_cap, elem_size)
  // WHY: Allocates a dynamically resizable contiguous buffer backed by the
  // sovereign slab/chunk allocator with zero external runtime dependencies.
  @if initial_cap <= 0
    initial_cap = 4
  @end
  @if elem_size <= 0
    elem_size = 8
  @end
  arr = LipiArray {
    length: 0,
    capacity: initial_cap,
    element_size: elem_size,
    data: lipi_alloc_typed(initial_cap * elem_size, TYPE_RAW_BYTES())
  }
  return arr
@end

@fn lipi_array_len(arr)
  // WHY: Fast O(1) query of current populated array element count.
  @if arr == 0 return 0 @end
  return arr.length
@end

@fn lipi_array_push(arr, val)
  // WHY: Geometric growth factor 2x amortization guarantees O(1) append time.
  @if arr == 0 return 0 @end
  @if arr.length >= arr.capacity
    new_cap = arr.capacity * 2
    @if new_cap < 4 new_cap = 4 @end
    new_data = lipi_alloc_typed(new_cap * arr.element_size, TYPE_RAW_BYTES())
    i = 0
    @while i < arr.length * arr.element_size
      b = sys_mem_read_u8(arr.data + i)
      sys_mem_write_u8(new_data + i, b)
      i = i + 1
    @end
    arr.data = new_data
    arr.capacity = new_cap
  @end
  sys_mem_write_u64(arr.data + (arr.length * arr.element_size), val)
  arr.length = arr.length + 1
  return arr
@end

@fn lipi_array_get(arr, idx)
  // WHY: Direct bounds-checked memory read at offset [base + idx * elem_size].
  @if arr == 0 return 0 @end
  @if idx < 0 || idx >= arr.length return 0 @end
  return sys_mem_read_u64(arr.data + (idx * arr.element_size))
@end

@fn lipi_array_set(arr, idx, val)
  // WHY: Direct bounds-checked memory write at indexed element slot.
  @if arr == 0 return 0 @end
  @if idx < 0 || idx >= arr.length return 0 @end
  sys_mem_write_u64(arr.data + (idx * arr.element_size), val)
  return val
@end

@! ----------------------------------------------------------------------------
@! 5. Standard I/O via Linux Raw Syscalls (Zero libc)
@! ----------------------------------------------------------------------------
@fn lipi_print_str(s)
  // WHY: Emits UTF-8 string bytes to file descriptor 1 (stdout) via sys_write.
  @if s == 0 return 0 @end
  len = str_len(s)
  @if len > 0
    sys_write(1, s, len)
  @end
  return 0
@end

@fn lipi_println_str(s)
  // WHY: Emits string followed by newline char (0x0A) to stdout.
  lipi_print_str(s)
  newline = "\n"
  sys_write(1, newline, 1)
  return 0
@end

@fn lipi_print_i64(val)
  // WHY: Converts 64-bit integer to ASCII decimal representation and prints to stdout.
  s = lipi_int_to_str(val)
  lipi_print_str(s)
  return 0
@end

@fn lipi_println_i64(val)
  // WHY: Prints integer with newline to stdout.
  lipi_print_i64(val)
  newline = "\n"
  sys_write(1, newline, 1)
  return 0
@end

@fn lipi_print_bool(val)
  // WHY: Prints boolean string representation 'true' or 'false'.
  @if val != 0
    lipi_print_str("true")
  @else
    lipi_print_str("false")
  @end
  return 0
@end

@fn lipi_println_bool(val)
  // WHY: Prints boolean string with newline to stdout.
  lipi_print_bool(val)
  newline = "\n"
  sys_write(1, newline, 1)
  return 0
@end

@fn lipi_print_err(s)
  // WHY: Emits diagnostic error message directly to file descriptor 2 (stderr).
  @if s == 0 return 0 @end
  len = str_len(s)
  @if len > 0
    sys_write(2, s, len)
  @end
  return 0
@end

@fn lipi_println_err(s)
  // WHY: Emits diagnostic error message followed by newline to stderr.
  lipi_print_err(s)
  newline = "\n"
  sys_write(2, newline, 1)
  return 0
@end

@! ----------------------------------------------------------------------------
@! 6. File I/O via Direct Linux Kernel Syscalls
@! ----------------------------------------------------------------------------
@fn lipi_file_read(path)
  // WHY: Reads complete file contents into a memory buffer without libc.
  fd = sys_open(path, O_RDONLY(), 0)
  @if fd < 0 return "" @end
  
  // Determine file size via lseek
  size = sys_lseek(fd, 0, SEEK_END())
  sys_lseek(fd, 0, SEEK_SET())
  
  @if size <= 0
    sys_close(fd)
    return ""
  @end
  
  buf = lipi_alloc_typed(size + 1, TYPE_RAW_BYTES())
  read_bytes = sys_read(fd, buf, size)
  sys_close(fd)
  
  @if read_bytes <= 0 return "" @end
  sys_mem_write_u8(buf + read_bytes, 0)
  return buf
@end

@fn lipi_file_write(path, content)
  // WHY: Writes string payload to file, creating or truncating as needed.
  flags = O_WRONLY() | O_CREAT() | O_TRUNC()
  mode = MODE_DEFAULT_FILE()
  fd = sys_open(path, flags, mode)
  @if fd < 0 return 0 @end
  
  len = str_len(content)
  written = 0
  @if len > 0
    written = sys_write(fd, content, len)
  @end
  sys_close(fd)
  @if written == len return 1 @end
  return 0
@end

@fn lipi_file_append(path, content)
  // WHY: Appends string payload to end of file without truncating existing content.
  flags = O_WRONLY() | O_CREAT() | O_APPEND()
  mode = MODE_DEFAULT_FILE()
  fd = sys_open(path, flags, mode)
  @if fd < 0 return 0 @end
  
  len = str_len(content)
  written = 0
  @if len > 0
    written = sys_write(fd, content, len)
  @end
  sys_close(fd)
  @if written == len return 1 @end
  return 0
@end

@fn lipi_file_exists(path)
  // WHY: Tests file accessibility (F_OK) via Linux sys_access (syscall 21).
  res = sys_access(path, 0)
  @if res == 0 return 1 @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 7. System Clock & Lifecycle
@! ----------------------------------------------------------------------------
@fn lipi_clock_ms()
  // WHY: High-resolution monotonic millisecond timer via sys_clock_gettime.
  ts_buf = lipi_alloc_typed(16, TYPE_RAW_BYTES())
  res = sys_clock_gettime(CLOCK_REALTIME(), ts_buf)
  @if res != 0 return 0 @end
  sec = sys_mem_read_u64(ts_buf)
  nsec = sys_mem_read_u64(ts_buf + 8)
  return (sec * 1000) + (nsec / 1000000)
@end

@fn lipi_exit(code)
  // WHY: Direct exit termination via sys_exit (syscall 60).
  sys_exit(code)
@end

