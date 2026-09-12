// ============================================================================
// 📜 LIPI OS ENV MODULE — universe/os/env.lp
// ⚡ 100% Pure Lipi Sovereign Operating System Environment Interface
// ============================================================================

import "universe/os/syscalls"
import "universe/os/fs"
import "universe/core/string"

@fn env_getcwd()
  buf = lipi_alloc(4096)
  res = sys_getcwd(buf, 4096)
  @if res < 0
    return ""
  @end
  return lipi_str_new(buf)
@end

@fn env_chdir(path)
  return sys_chdir(path)
@end

@fn env_all()
  fd = sys_open("/proc/self/environ", 0, 0)
  arr = []
  @if fd < 0 return arr @end
  
  buf_len = 65536
  buf = lipi_alloc(buf_len)
  bytes = sys_read(fd, buf, buf_len)
  sys_close(fd)
  
  @if bytes <= 0 return arr @end
  
  offset = 0
  @while offset < bytes
    s = lipi_str_new(buf + offset)
    s_l = str_len(s)
    @if s_l > 0
      arr = arr.push(s)
    @end
    offset = offset + s_l + 1
  @end
  return arr
@end

@fn env_get(key)
  fd = sys_open("/proc/self/environ", 0, 0)
  @if fd < 0 return "" @end
  buf_len = 65536
  buf = lipi_alloc(buf_len)
  bytes = sys_read(fd, buf, buf_len)
  sys_close(fd)
  @if bytes <= 0 return "" @end
  search = string_concat(key, "=")
  search_len = str_len(search)
  offset = 0
  res = ""
  found = 0
  @while offset < bytes && found == 0
    s = lipi_str_new(buf + offset)
    s_l = str_len(s)
    @if s_l > 0
      @if starts_with(s, search)
        res = str_substr(s, search_len, s_l)
        found = 1
      @end
    @end
    offset = offset + s_l + 1
  @end
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
