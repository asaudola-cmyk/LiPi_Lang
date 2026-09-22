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
@fn TYPE_MAYA_STRING() return 1 @end
@fn TYPE_LIPI_ARRAY() return 2 @end
@fn TYPE_MAYA_ARRAY() return 2 @end
@fn TYPE_LIPI_MAP() return 3 @end
@fn TYPE_MAYA_MAP() return 3 @end
@fn TYPE_LIPI_STRUCT() return 4 @end
@fn TYPE_MAYA_STRUCT() return 4 @end
@fn TYPE_LIPI_CLOSURE() return 5 @end
@fn TYPE_MAYA_CLOSURE() return 5 @end
@fn TYPE_LIPI_BOXED_FLOAT() return 6 @end
@fn TYPE_MAYA_BOXED_FLOAT() return 6 @end

@! ----------------------------------------------------------------------------
@! 2. Memory Structures
@! ----------------------------------------------------------------------------
@struct LipiArray
  length: 0,
  capacity: 0,
  element_size: 8,
  data: 0
@end

@struct MayaArray
  length: 0,
  capacity: 0,
  element_size: 8,
  data: 0
@end

@struct LipiString
  length: 0,
  buffer: 0
@end

@struct MayaString
  length: 0,
  buffer: 0
@end

@struct LipiMapEntry
  key: "",
  value: 0,
  occupied: 0
@end

@struct MayaMapEntry
  key: "",
  value: 0,
  occupied: 0
@end

@struct LipiMap
  capacity: 16,
  size: 0,
  entries: 0
@end

@struct MayaMap
  capacity: 16,
  size: 0,
  entries: 0
@end

@! ----------------------------------------------------------------------------
@! 3. Core Memory Allocation & GC Bridge
@! ----------------------------------------------------------------------------
@fn lipi_runtime_init()
  lipi_init_gc()
@end

@fn maya_runtime_init()
  lipi_runtime_init()
@end

@fn lipi_alloc_typed(size, type_id)
  @if size <= 0
    size = 1
  @end
  return gc_alloc_typed(size, type_id)
@end

@fn maya_alloc_typed(size, type_id)
  return lipi_alloc_typed(size, type_id)
@end

@fn is_lipi_string_ptr(val)
  @if val == 0 return 0 @end
  @if (val & 7) != 0 return 0 @end
  @if val < 65536 return 0 @end
  base = gc_base(val)
  @if base == 0 || base != val return 0 @end
  return gc_get_type_id(val) == TYPE_LIPI_STRING()
@end

// WHY: Retains is_maya_string_ptr as backward-compatible alias for legacy callers
@fn is_maya_string_ptr(val)
  return is_lipi_string_ptr(val)
@end

@fn is_lipi_array_ptr(val)
  @if val == 0 return 0 @end
  @if (val & 7) != 0 return 0 @end
  @if val < 65536 return 0 @end
  base = gc_base(val)
  @if base == 0 || base != val return 0 @end
  return gc_get_type_id(val) == TYPE_LIPI_ARRAY()
@end

// WHY: Retains is_maya_array_ptr as backward-compatible alias for legacy callers
@fn is_maya_array_ptr(val)
  return is_lipi_array_ptr(val)
@end

@fn is_lipi_map_ptr(val)
  @if val == 0 return 0 @end
  @if (val & 7) != 0 return 0 @end
  @if val < 65536 return 0 @end
  base = gc_base(val)
  @if base == 0 || base != val return 0 @end
  return gc_get_type_id(val) == TYPE_LIPI_MAP()
@end

// WHY: Retains is_maya_map_ptr as backward-compatible alias for legacy callers
@fn is_maya_map_ptr(val)
  return is_lipi_map_ptr(val)
@end

@! ----------------------------------------------------------------------------
@! 4. Dynamic Array Operations
@! ----------------------------------------------------------------------------
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

@fn maya_array_new(initial_cap, elem_size)
  return lipi_array_new(initial_cap, elem_size)
@end

@fn lipi_array_len(arr)
  @if arr == 0 return 0 @end
  return arr.length
@end

@fn maya_array_len(arr)
  return lipi_array_len(arr)
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

@fn maya_array_push(arr, val)
  return lipi_array_push(arr, val)
@end

@fn lipi_array_get(arr, idx)
  @if arr == 0 return 0 @end
  @if idx < 0 || idx >= arr.length return 0 @end
  return sys_mem_read_u64(arr.data + (idx * arr.element_size))
@end

@fn maya_array_get(arr, idx)
  return lipi_array_get(arr, idx)
@end

@fn lipi_array_set(arr, idx, val)
  @if arr == 0 return 0 @end
  @if idx < 0 || idx >= arr.length return 0 @end
  sys_mem_write_u64(arr.data + (idx * arr.element_size), val)
  return val
@end

@fn maya_array_set(arr, idx, val)
  return lipi_array_set(arr, idx, val)
@end

@! ----------------------------------------------------------------------------
@! 5. Standard I/O via Linux Raw Syscalls (Zero libc)
@! ----------------------------------------------------------------------------
@fn lipi_print_str(s)
  @if s == 0 return 0 @end
  len = str_len(s)
  @if len > 0
    sys_write(1, s, len)
  @end
  return 0
@end

@fn maya_print_str(s)
  return lipi_print_str(s)
@end

@fn lipi_println_str(s)
  lipi_print_str(s)
  newline = "\n"
  sys_write(1, newline, 1)
  return 0
@end

@fn maya_println_str(s)
  return lipi_println_str(s)
@end

@fn lipi_print_i64(val)
  s = lipi_int_to_str(val)
  lipi_print_str(s)
  return 0
@end

@fn maya_print_i64(val)
  return lipi_print_i64(val)
@end

@fn lipi_println_i64(val)
  lipi_print_i64(val)
  newline = "\n"
  sys_write(1, newline, 1)
  return 0
@end

@fn maya_println_i64(val)
  return lipi_println_i64(val)
@end

@fn lipi_print_bool(val)
  @if val != 0
    lipi_print_str("true")
  @else
    lipi_print_str("false")
  @end
  return 0
@end

@fn maya_print_bool(val)
  return lipi_print_bool(val)
@end

@fn lipi_println_bool(val)
  lipi_print_bool(val)
  newline = "\n"
  sys_write(1, newline, 1)
  return 0
@end

@fn maya_println_bool(val)
  return lipi_println_bool(val)
@end

@fn lipi_print_err(s)
  @if s == 0 return 0 @end
  len = str_len(s)
  @if len > 0
    sys_write(2, s, len)
  @end
  return 0
@end

@fn maya_print_err(s)
  return lipi_print_err(s)
@end

@fn lipi_println_err(s)
  lipi_print_err(s)
  newline = "\n"
  sys_write(2, newline, 1)
  return 0
@end

@fn maya_println_err(s)
  return lipi_println_err(s)
@end

@! ----------------------------------------------------------------------------
@! 6. File I/O via Direct Linux Kernel Syscalls
@! ----------------------------------------------------------------------------
@fn lipi_file_read(path)
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

@fn maya_file_read(path)
  return lipi_file_read(path)
@end

@fn lipi_file_write(path, content)
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
  return written == len ? 1 : 0
@end

@fn maya_file_write(path, content)
  return lipi_file_write(path, content)
@end

@fn lipi_file_append(path, content)
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
  return written == len ? 1 : 0
@end

@fn maya_file_append(path, content)
  return lipi_file_append(path, content)
@end

@fn lipi_file_exists(path)
  res = sys_access(path, 0)
  return res == 0 ? 1 : 0
@end

@fn maya_file_exists(path)
  return lipi_file_exists(path)
@end

@! ----------------------------------------------------------------------------
@! 7. System Clock & Lifecycle
@! ----------------------------------------------------------------------------
@fn lipi_clock_ms()
  // Allocate 16 bytes for struct timespec { sec: i64, nsec: i64 }
  ts_buf = lipi_alloc_typed(16, TYPE_RAW_BYTES())
  res = sys_clock_gettime(CLOCK_REALTIME(), ts_buf)
  @if res != 0 return 0 @end
  sec = sys_mem_read_u64(ts_buf)
  nsec = sys_mem_read_u64(ts_buf + 8)
  return (sec * 1000) + (nsec / 1000000)
@end

@fn maya_clock_ms()
  return lipi_clock_ms()
@end

@fn lipi_exit(code)
  sys_exit(code)
@end

@fn maya_exit(code)
  lipi_exit(code)
@end

