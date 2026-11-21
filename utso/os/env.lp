// ============================================================================
// 📜 LIPI OS ENV MODULE — utso/os/env.lp
// ⚡ 100% Pure Lipi Sovereign Operating System Environment Interface
// ============================================================================

import "utso/os/syscalls"
import "utso/os/fs"
import "utso/core/string"

@fn env_getcwd()
  buf = lipi_alloc(4097)
  @if buf <= 0 return "" @end
  res = sys_getcwd(buf, 4096)
  @if res <= 0
    lipi_free(buf)
    return ""
  @end
  sys_poke8(buf + 4096, 0)
  out = str_sub(lipi_str_new(buf), 0, 4096)
  lipi_free(buf)
  return out
@end

@fn env_chdir(path)
  return sys_chdir(path)
@end

@fn env_all()
  fd = sys_open("/proc/self/environ", 0, 0)
  arr = []
  @if fd < 0 return arr @end
  buf_len = 65536
  buf = lipi_alloc(buf_len + 1)
  @if buf <= 0
    sys_close(fd)
    return arr
  @end
  bytes = sys_read(fd, buf, buf_len)
  sys_close(fd)
  @if bytes <= 0
    lipi_free(buf)
    return arr
  @end
  sys_poke8(buf + bytes, 0)
  offset = 0
  @while offset < bytes
    s = str_sub(lipi_str_new(buf + offset), 0, bytes - offset)
    s_l = str_len(s)
    @if s_l > 0
      arr = arr.push(s)
    @end
    offset = offset + s_l + 1
  @end
  lipi_free(buf)
  return arr
@end

@fn env_get(key)
  fd = sys_open("/proc/self/environ", 0, 0)
  @if fd < 0 return "" @end
  buf_len = 65536
  buf = lipi_alloc(buf_len + 1)
  @if buf <= 0
    sys_close(fd)
    return ""
  @end
  bytes = sys_read(fd, buf, buf_len)
  sys_close(fd)
  @if bytes <= 0
    lipi_free(buf)
    return ""
  @end
  sys_poke8(buf + bytes, 0)
  search = string_concat(key, "=")
  search_len = str_len(search)
  offset = 0
  res = ""
  found = 0
  @while offset < bytes && found == 0
    s = str_sub(lipi_str_new(buf + offset), 0, bytes - offset)
    s_l = str_len(s)
    @if s_l > 0
      @if starts_with(s, search)
        res = str_substr(s, search_len, s_l)
        found = 1
      @end
    @end
    offset = offset + s_l + 1
  @end
  lipi_free(buf)
  return res
@end

@fn env_get_or(key, default_val)
  val = env_get(key)
  @if str_len(val) == 0 return default_val @end
  return val
@end

@fn env_has(key)
  val = env_get(key)
  return str_len(val) > 0
@end

@fn env_set(key, val)
  return 0
@end
