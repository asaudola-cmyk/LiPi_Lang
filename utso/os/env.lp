// ============================================================================
// 📜 LIPI OS ENV MODULE — utso/os/env.lp
// ⚡ 100% Pure Lipi Sovereign Operating System Environment Interface
//    In-Process Dynamic Environment Map (StrDict) + Arbitrary-Size /proc/self/environ
// ============================================================================

import "utso/os/syscalls"
import "utso/os/fs"
import "utso/core/string"
import "utso/core/hashmap"

global g_env_map = 0
global g_env_inited = 0

@fn _env_ensure_init()
  @if g_env_inited == 1 && g_env_map != 0
    return g_env_map
  @end
  m = dict_new(64)
  g_env_map = m
  g_env_inited = 1
  fd = sys_open("/proc/self/environ", 0, 0)
  @if fd < 0 return m @end

  // WHY: Read full /proc/self/environ with ByteBuffer (no 64KB truncation limit!).
  raw = buf_new(8192)
  tmp = lipi_alloc(4096)
  @if tmp > 0
    @while 1 == 1
      nr = sys_read(fd, tmp, 4096)
      @if nr <= 0 break @end
      buf_write_mem(raw, tmp, nr)
    @end
    lipi_free_sized(tmp, 4096)
  @end
  sys_close(fd)

  total = buf_len(raw)
  base = buf_ptr(raw)
  pos = 0
  @while pos < total
    start = pos
    eq_pos = 0 - 1
    @while pos < total
      b = mem_read_byte(base, pos)
      @if b == 0 break @end
      @if b == 61 && eq_pos < 0
        eq_pos = pos
      @end
      pos = pos + 1
    @end
    @if eq_pos > start
      k = bytes_to_str(base + start, eq_pos - start)
      v = bytes_to_str(base + eq_pos + 1, pos - (eq_pos + 1))
      dict_set(m, k, v)
    @end
    pos = pos + 1
  @end
  buf_free(raw)
  return m
@end

@fn env_getcwd()
  buf = lipi_alloc(4097)
  @if buf <= 0 return "" @end
  res = sys_getcwd(buf, 4096)
  @if res <= 0
    lipi_free_sized(buf, 4097)
    return ""
  @end
  sys_poke8(buf + 4096, 0)
  // Compute exact length via NUL scan
  n = 0
  @while n < 4096 && sys_peek8(buf + n) != 0
    n = n + 1
  @end
  out = bytes_to_str(buf, n)
  lipi_free_sized(buf, 4097)
  return out
@end

@fn env_chdir(path)
  return sys_chdir(path)
@end

@fn env_all()
  m = _env_ensure_init()
  ks = dict_keys(m)
  arr = []
  i = 0
  n = ks.len()
  @while i < n
    k = ks[i]
    v = dict_get_or(m, k, "")
    arr = arr.push(k + "=" + v)
    i = i + 1
  @end
  return arr
@end

@fn env_get(key)
  m = _env_ensure_init()
  return dict_get_or(m, key, "")
@end

@fn env_get_or(key, default_val)
  m = _env_ensure_init()
  @if dict_has(m, key) == 0 return default_val @end
  val = dict_get_or(m, key, "")
  @if str_len(val) == 0 return default_val @end
  return val
@end

@fn env_has(key)
  m = _env_ensure_init()
  return dict_has(m, key)
@end

@fn env_set(key, val)
  // WHY: Maintains real mutable in-process environment table inherited by child processes via process_spawn/capture.
  @if str_len(key) == 0 return 0 - 1 @end
  m = _env_ensure_init()
  dict_set(m, key, str(val))
  return 0
@end

@fn env_unset(key)
  m = _env_ensure_init()
  return dict_delete(m, key)
@end
