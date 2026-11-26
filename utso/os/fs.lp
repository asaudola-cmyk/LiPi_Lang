@! ============================================================================
@! LIPI UNIVERSE OS — FILE SYSTEM & PATH MANAGEMENT (utso/os/fs)
@! 100% Written in Pure Lipi Language — Native Linux x86-64 Syscalls
@! Complete Independence from libc.so / stdio
@! ============================================================================

import "utso/os/syscalls"
import "utso/core/string"

@! ----------------------------------------------------------------------------
@! 1. POSIX File Access Flag Helpers
@! ----------------------------------------------------------------------------
@fn O_RDONLY() return 0 @end
@fn O_WRONLY() return 1 @end
@fn O_RDWR() return 2 @end
@fn O_CREAT() return 64 @end
@fn O_TRUNC() return 512 @end
@fn O_APPEND() return 1024 @end

@! ----------------------------------------------------------------------------
@! 2. File Data Structures
@! ----------------------------------------------------------------------------
@struct FileStat
  size: i64
  mode: i64
  is_file: i64
  is_dir: i64
@end

@struct RawStat
  dev: i64
  ino: i64
  nlink: i64
  mode_uid: i64
  rdev: i64
  pad: i64
  size: i64
  blksize: i64
  blocks: i64
  atime_sec: i64
  atime_nsec: i64
  mtime_sec: i64
  mtime_nsec: i64
  ctime_sec: i64
  ctime_nsec: i64
  res1: i64
  res2: i64
  res3: i64
@end

@struct DirentHeader
  d_ino: i64
  d_off: i64
  d_reclen_type: i64
@end

@! ----------------------------------------------------------------------------
@! 3. Core File Descriptor Operations
@! ----------------------------------------------------------------------------

@! Opens a file with given flags and mode; returns file descriptor integer
@fn fs_open(path, flags, mode)
  f_creat = flags & 64
  @if mode == 0 && f_creat != 0
    mode = 420  @! 0644 default permission
  @end
  return sys_open(path, flags, mode)
@end

@! Reads up to max_len bytes from fd in O(N) via native ERMS bytes_to_str (zero O(N^2) concat!)
@fn fs_read(fd, max_len)
  @if max_len <= 0
    return ""
  @end
  buf = lipi_alloc(max_len + 1)
  @if buf <= 0
    return ""
  @end
  bytes_read = sys_read(fd, buf, max_len)
  @if bytes_read <= 0
    lipi_free_sized(buf, max_len + 1)
    return ""
  @end
  out = bytes_to_str(buf, bytes_read)
  lipi_free_sized(buf, max_len + 1)
  return out
@end

@! Writes string data to fd, returning number of bytes written
@fn fs_write(fd, data)
  x_len = data.len()
  @if x_len == 0
    return 0
  @end
  return sys_write(fd, data, x_len)
@end

@! Closes open file descriptor
@fn fs_close(fd)
  return sys_close(fd)
@end

@! ----------------------------------------------------------------------------
@! 4. File Metadata & Existence
@! ----------------------------------------------------------------------------

@! Checks whether a path exists on the filesystem
@fn fs_exists(path)
  res = sys_access(path, 0)
  @if res == 0
    return 1
  @end
  stat_buf = lipi_alloc(144)
  st_res = -1
  @if stat_buf > 0
    st_res = sys_stat(path, stat_buf)
    lipi_free_sized(stat_buf, 144)
  @end
  @if st_res == 0
    return 1
  @end
  return file_exists(path)
@end

@! Queries file metadata (size, mode, is_file, is_dir) via Linux x86_64 struct stat ABI
@fn fs_stat(path)
  stat_buf = lipi_alloc(144)
  @if stat_buf <= 0
    return { size: 0, mode: 0, is_file: 0, is_dir: 0 }
  @end
  res = sys_stat(path, stat_buf)
  @if res != 0
    lipi_free_sized(stat_buf, 144)
    return { size: 0, mode: 0, is_file: 0, is_dir: 0 }
  @end

  // Linux x86_64 struct stat offsets: st_mode (u32) at +24, st_size (i64) at +48.
  mode32 = sys_peek32(stat_buf + 24)
  fsize = sys_peek64(stat_buf + 48)
  lipi_free_sized(stat_buf, 144)

  raw_mode = mode32 & 65535
  fmt = raw_mode & 61440  @! S_IFMT (0170000)
  is_d = 0
  @if fmt == 16384  @! S_IFDIR (0040000)
    is_d = 1
  @end
  is_f = 0
  @if fmt == 32768  @! S_IFREG (0100000)
    is_f = 1
  @end

  return {
    size: fsize,
    mode: raw_mode,
    is_file: is_f,
    is_dir: is_d
  }
@end

@! ----------------------------------------------------------------------------
@! 5. Whole-File I/O Helpers
@! ----------------------------------------------------------------------------

@fn fs_read_file(path)
  // WHY: Returns file content string using native compiler intrinsic file_read
  // which deterministically calculates length, allocates on Lipi runtime heap with STR0 header,
  // reads contents, and properly closes descriptor.
  return file_read(path)
@end

@! Writes complete content string to target path (loops over partial sys_write safely)
@fn fs_write_file(path, content)
  @! O_WRONLY (1) | O_CREAT (64) | O_TRUNC (512) = 577, 0644 mode = 420
  fd = sys_open(path, 577, 420)
  @if fd < 0
    return file_write(path, content)
  @end
  x_len = content.len()
  @if x_len == 0
    sys_close(fd)
    return 1
  @end
  total = 0
  @while total < x_len
    w = sys_write(fd, content + total, x_len - total)
    @if w <= 0
      sys_close(fd)
      return 0
    @end
    total = total + w
  @end
  sys_close(fd)
  return 1
@end

@! Atomic crash-safe file write: write temp file -> SYS_fsync -> close -> SYS_rename
@fn fs_write_atomic(path, content)
  tmp_path = path + ".tmp." + str(sys_getpid())
  fd = sys_open(tmp_path, 577, 420)
  @if fd < 0 return 0 @end
  x_len = content.len()
  total = 0
  @while total < x_len
    w = sys_write(fd, content + total, x_len - total)
    @if w <= 0
      sys_close(fd)
      sys_unlink(tmp_path)
      return 0
    @end
    total = total + w
  @end
  syscall(74, fd, 0, 0, 0, 0, 0) @! SYS_fsync (74)
  sys_close(fd)
  @if sys_rename(tmp_path, path) < 0
    sys_unlink(tmp_path)
    return 0
  @end
  return 1
@end

@! Advisory file locking via Linux SYS_flock (syscall 73: LOCK_SH=1, LOCK_EX=2, LOCK_UN=8)
@fn fs_lock(fd, exclusive)
  op = 1
  @if exclusive != 0 op = 2 @end
  return syscall(73, fd, op, 0, 0, 0, 0)
@end

@fn fs_unlock(fd)
  return syscall(73, fd, 8, 0, 0, 0, 0)
@end

@! Appends content string to file at target path (partial-write safe)
@fn fs_append_file(path, content)
  @! O_WRONLY (1) | O_CREAT (64) | O_APPEND (1024) = 1089, 0644 mode = 420
  fd = sys_open(path, 1089, 420)
  @if fd < 0
    return file_append(path, content)
  @end
  x_len = content.len()
  @if x_len == 0
    sys_close(fd)
    return 1
  @end
  total = 0
  @while total < x_len
    w = sys_write(fd, content + total, x_len - total)
    @if w <= 0
      sys_close(fd)
      return 0
    @end
    total = total + w
  @end
  sys_close(fd)
  return 1
@end

@! Reads whole file and splits into an array of string lines in O(N) via bytes_to_str
@fn _fs_raw_ptr(x) return x @end

@fn fs_read_lines(path)
  content = fs_read_file(path)
  c_ptr = _fs_raw_ptr(content)
  lines = []
  x_len = content.len()
  line_start = 0
  i = 0
  @while i < x_len
    ch_code = mem_read_byte(c_ptr, i)
    @if ch_code == 10  @! '\n'
      line_end = i
      @if line_end > line_start && mem_read_byte(c_ptr, line_end - 1) == 13
        line_end = line_end - 1
      @end
      lines.push(bytes_to_str(c_ptr + line_start, line_end - line_start))
      line_start = i + 1
    @end
    i = i + 1
  @end
  @if line_start < x_len
    line_end = x_len
    @if line_end > line_start && mem_read_byte(c_ptr, line_end - 1) == 13
      line_end = line_end - 1
    @end
    lines.push(bytes_to_str(c_ptr + line_start, line_end - line_start))
  @end
  return lines
@end

@! ----------------------------------------------------------------------------
@! 6. Directory Operations & File Management
@! ----------------------------------------------------------------------------

@! Creates directory at path with specified mode
@fn fs_mkdir(path, mode)
  @if mode == 0
    mode = 493  @! 0755
  @end
  return sys_mkdir(path, mode)
@end

@! Recursively creates directory hierarchy and all missing parent directories
@fn fs_mkdir_p(path, mode)
  @if path.len() == 0 return 0 @end
  @if fs_exists(path) == 1 return 0 @end
  @if mode == 0 mode = 511 @end  @! 0777 default for mkdir_p

  x_len = path.len()
  accum = ""
  i = 0
  @while i < x_len
    ch_code = str_char_at(path, i)
    @if ch_code == 47  @! '/'
      @if accum.len() > 0 && accum != "/"
        @if fs_exists(accum) == 0
          sys_mkdir(accum, mode)
        @end
      @end
      @if accum.len() == 0
        accum = "/"
      @elif accum != "/"
        accum = accum + "/"
      @end
    @else
      ch = str_substr(path, i, i + 1)
      @if accum == "/"
        accum = "/" + ch
      @else
        accum = accum + ch
      @end
    @end
    i = i + 1
  @end

  @if accum.len() > 0 && accum != "/"
    @if fs_exists(accum) == 0
      sys_mkdir(accum, mode)
    @end
  @end

  @if fs_exists(path) == 1
    return 0
  @end
  return -1
@end

@! Removes empty directory at path
@fn fs_rmdir(path)
  return sys_rmdir(path)
@end

@! Removes file or unlinks directory entry at path
@fn fs_remove(path)
  res = sys_unlink(path)
  @if res != 0
    res = sys_rmdir(path)
  @end
  @if res == 0
    return 1
  @end
  return 0
@end

@! Renames or moves file from oldpath to newpath
@fn fs_rename(oldpath, newpath)
  return sys_rename(oldpath, newpath)
@end

@! Reads directory contents returning array of entry filenames
@fn fs_read_dir(path)
  fd = sys_open(path, 0 | 65536, 0)  @! O_RDONLY | O_DIRECTORY
  @if fd < 0
    fd = sys_open(path, 0, 0)
  @end
  @if fd < 0
    return []
  @end

  entries = []
  buf_size = 4096
  buf = lipi_alloc(buf_size)
  @if buf <= 0
    sys_close(fd)
    return entries
  @end

  @while 1
    nread = sys_getdents64(fd, buf, buf_size)
    @if nread <= 0
      break
    @end

    pos = 0
    @while pos < nread
      entry_ptr = buf + pos
      reclen = sys_peek16(entry_ptr + 16)
      @if reclen <= 0
        break
      @end

      // Copy NUL-terminated d_name at offset +19 in O(N) via native ERMS bytes_to_str
      name_ptr = entry_ptr + 19
      nk = 0
      max_name = reclen - 19
      @while nk < max_name
        @if sys_peek8(name_ptr + nk) == 0 break @end
        nk = nk + 1
      @end
      name = bytes_to_str(name_ptr, nk)

      @if name != "" && name != "." && name != ".."
        entries.push(name)
      @end

      pos = pos + reclen
    @end
  @end

  lipi_free_sized(buf, buf_size)
  sys_close(fd)
  return entries
@end

@! ----------------------------------------------------------------------------
@! 7. Path Utilities
@! ----------------------------------------------------------------------------

@! Joins two path components with a single path delimiter '/'
@fn path_join(base, part)
  @if base.len() == 0 return part @end
  @if part.len() == 0 return base @end
  base_has_slash = ends_with(base, "/")
  part_has_slash = starts_with(part, "/")
  @if base_has_slash == 1 && part_has_slash == 1
    return base + str_substr(part, 1, part.len())
  @end
  @if base_has_slash == 1 || part_has_slash == 1
    return base + part
  @end
  return base + "/" + part
@end

@! Extracts the directory portion of a filesystem path
@fn path_dirname(path)
  @if path.len() == 0 return "." @end
  x_len = path.len()
  i = x_len - 1
  last_slash = -1
  @while i >= 0
    @if str_char_at(path, i) == 47  @! '/' is ASCII 47
      last_slash = i
      break
    @end
    i = i - 1
  @end
  @if last_slash < 0 return "." @end
  @if last_slash == 0 return "/" @end
  return str_substr(path, 0, last_slash)
@end

@! Extracts the filename / basename portion of a filesystem path
@fn path_basename(path)
  @if path.len() == 0 return "" @end
  x_len = path.len()
  i = x_len - 1
  last_slash = -1
  @while i >= 0
    @if str_char_at(path, i) == 47  @! '/' is ASCII 47
      last_slash = i
      break
    @end
    i = i - 1
  @end
  @if last_slash < 0 return path @end
  return str_substr(path, last_slash + 1, x_len)
@end

@! Extracts the file extension (including leading dot) from path
@fn path_extension(path)
  base = path_basename(path)
  x_len = base.len()
  i = x_len - 1
  last_dot = -1
  @while i >= 0
    @if str_char_at(base, i) == 46  @! '.' is ASCII 46
      last_dot = i
      break
    @end
    i = i - 1
  @end
  @if last_dot < 0 return "" @end
  return str_substr(base, last_dot, x_len)
@end

@! Checks whether a given path is an absolute path (starts with '/')
@fn path_is_absolute(path)
  @if path.len() == 0 return 0 @end
  return starts_with(path, "/")
@end

@! ----------------------------------------------------------------------------
@! 8. Recursive Dir Walk, Wildcard Glob, Temp Files & Linux Inotify Watcher
@! ----------------------------------------------------------------------------

@fn _fs_walk_rec(dir_path, out_list, depth)
  @if depth > 64 return 0 @end
  items = fs_read_dir(dir_path)
  i = 0
  @while i < items.len()
    full = path_join(dir_path, items[i])
    st = fs_stat(full)
    out_list.push(full)
    @if st.is_dir == 1
      _fs_walk_rec(full, out_list, depth + 1)
    @end
    i = i + 1
  @end
  return out_list.len()
@end

@! Recursively walks directory tree via SYS_getdents64 and returns all paths
@fn fs_dir_walk(root_dir)
  res = []
  _fs_walk_rec(root_dir, res, 0)
  return res
@end

@! Wildcard glob pattern matcher supporting '*' (any sequence) and '?' (any single char)
@fn fs_glob_match(pattern, text)
  pi = 0
  ti = 0
  plen = pattern.len()
  tlen = text.len()
  star_p = 0 - 1
  star_t = 0
  @while ti < tlen
    @if pi < plen && (str_char_at(pattern, pi) == 63 || str_char_at(pattern, pi) == str_char_at(text, ti))
      pi = pi + 1
      ti = ti + 1
    @elif pi < plen && str_char_at(pattern, pi) == 42
      star_p = pi
      star_t = ti
      pi = pi + 1
    @elif star_p >= 0
      pi = star_p + 1
      star_t = star_t + 1
      ti = star_t
    @else
      return 0
    @end
  @end
  @while pi < plen && str_char_at(pattern, pi) == 42
    pi = pi + 1
  @end
  @if pi == plen return 1 @end
  return 0
@end

@! Lists all files inside dir_path whose basename matches wildcard pattern (e.g. "*.lp")
@fn fs_glob(dir_path, pattern)
  all_e = fs_read_dir(dir_path)
  matched = []
  i = 0
  @while i < all_e.len()
    @if fs_glob_match(pattern, all_e[i]) == 1
      matched.push(path_join(dir_path, all_e[i]))
    @end
    i = i + 1
  @end
  return matched
@end

global g_fs_tmp_seq = 0

@! Creates a unique temporary file under /tmp using O_CREAT|O_EXCL (192) + PID + sequence
@fn fs_temp_file(prefix)
  pid = sys_getpid()
  tries = 0
  @while tries < 64
    g_fs_tmp_seq = g_fs_tmp_seq + 1
    cand = "/tmp/" + prefix + "_" + str(pid) + "_" + str(g_fs_tmp_seq) + ".tmp"
    @! O_RDWR (2) | O_CREAT (64) | O_EXCL (128) = 194, mode 0600 (384)
    fd = sys_open(cand, 194, 384)
    @if fd >= 0
      sys_close(fd)
      return cand
    @end
    tries = tries + 1
  @end
  return ""
@end

@! Creates a unique temporary directory under /tmp via SYS_mkdir (83)
@fn fs_temp_dir(prefix)
  pid = sys_getpid()
  tries = 0
  @while tries < 64
    g_fs_tmp_seq = g_fs_tmp_seq + 1
    cand = "/tmp/" + prefix + "_" + str(pid) + "_" + str(g_fs_tmp_seq)
    @if syscall(83, cand, 448, 0, 0, 0, 0) == 0
      return cand
    @end
    tries = tries + 1
  @end
  return ""
@end

@! Real Linux inotify watcher via SYS_inotify_init1 (294) and SYS_inotify_add_watch (254)
@! IN_NONBLOCK = 2048 (0x800), IN_MODIFY = 2, IN_CREATE = 256, IN_DELETE = 512, IN_CLOSE_WRITE = 8
@fn fs_inotify_init()
  return syscall(294, 2048, 0, 0, 0, 0, 0)
@end

@fn fs_inotify_add_watch(ifd, path, mask)
  return syscall(254, ifd, path, mask, 0, 0, 0)
@end

@fn fs_inotify_rm_watch(ifd, wd)
  return syscall(255, ifd, wd, 0, 0, 0, 0)
@end

@! Reads next pending inotify event mask (returns event mask > 0, or 0 if no event / EAGAIN)
@fn fs_inotify_read_event(ifd)
  buf = lipi_alloc(256)
  @if buf <= 0 return 0 @end
  n = sys_read(ifd, buf, 256)
  mask = 0
  @if n >= 16
    @! struct inotify_event: +0 wd(i32), +4 mask(u32), +8 cookie(u32), +12 len(u32)
    mask = sys_peek32(buf + 4)
  @end
  lipi_free_sized(buf, 256)
  return mask
@end
