@! ============================================================================
@! MAYA UNIVERSE OS — FILE SYSTEM & PATH MANAGEMENT (universe/os/fs)
@! 100% Written in Pure Maya Language — Native Linux x86-64 Syscalls
@! Complete Independence from libc.so / stdio
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/string"

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

@! Reads up to max_len bytes from fd, returning string
@fn fs_read(fd, max_len)
  @if max_len <= 0
    return ""
  @end
  buf = maya_alloc(max_len + 1)
  bytes_read = sys_read(fd, buf, max_len)
  @if bytes_read <= 0
    return ""
  @end
  return maya_str_new(buf)
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
  st = { dev: 0, ino: 0, nlink: 0, mode_uid: 0, rdev: 0, pad: 0, size: 0, blksize: 0, blocks: 0, atime_sec: 0, atime_nsec: 0, mtime_sec: 0, mtime_nsec: 0, ctime_sec: 0, ctime_nsec: 0, res1: 0, res2: 0, res3: 0 }
  st_res = sys_stat(path, st)
  @if st_res == 0
    return 1
  @end
  return file_exists(path)
@end

@! Queries file metadata (size, mode, is_file, is_dir) via sys_stat
@fn fs_stat(path)
  st = { dev: 0, ino: 0, nlink: 0, mode_uid: 0, rdev: 0, pad: 0, size: 0, blksize: 0, blocks: 0, atime_sec: 0, atime_nsec: 0, mtime_sec: 0, mtime_nsec: 0, ctime_sec: 0, ctime_nsec: 0, res1: 0, res2: 0, res3: 0 }
  res = sys_stat(path, st)
  @if res != 0
    return { size: 0, mode: 0, is_file: 0, is_dir: 0 }
  @end

  raw_mode = st.mode_uid & 65535
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
    size: st.size,
    mode: raw_mode,
    is_file: is_f,
    is_dir: is_d
  }
@end

@! ----------------------------------------------------------------------------
@! 5. Whole-File I/O Helpers
@! ----------------------------------------------------------------------------

@! Reads the entire file content into a string using native syscalls
@fn fs_read_file(path)
  fd = sys_open(path, 0, 0)  @! O_RDONLY
  @if fd < 0
    return file_read(path)
  @end

  st = fs_stat(path)
  @if st.size > 0
    buf = maya_alloc(st.size + 1)
    bytes_read = sys_read(fd, buf, st.size)
    sys_close(fd)
    @if bytes_read <= 0
      return ""
    @end
    return maya_str_new(buf)
  @end

  @! For 0-length stat or special pseudo-files (/proc, /sys), stream in chunks
  chunk_size = 4096
  buf = maya_alloc(chunk_size + 1)
  accum = ""
  @while 1
    bytes_read = sys_read(fd, buf, chunk_size)
    @if bytes_read <= 0
      break
    @end
    chunk_str = maya_str_new(buf)
    accum = accum + chunk_str
    @if bytes_read < chunk_size
      break
    @end
  @end
  sys_close(fd)

  @if accum.len() == 0
    @! Fallback to builtin file_read if needed
    f_res = file_read(path)
    @if f_res.len() > 0
      return f_res
    @end
  @end

  return accum
@end

@! Writes complete content string to target path, overwriting if exists
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
  written = sys_write(fd, content, x_len)
  sys_close(fd)
  @if written >= 0
    return 1
  @end
  return file_write(path, content)
@end

@! Appends content string to file at target path
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
  written = sys_write(fd, content, x_len)
  sys_close(fd)
  @if written >= 0
    return 1
  @end
  return file_append(path, content)
@end

@! Reads whole file and splits into an array of string lines
@fn fs_read_lines(path)
  content = fs_read_file(path)
  lines = []
  x_len = content.len()
  curr_line = ""
  i = 0
  @while i < x_len
    ch_code = str_char_at(content, i)
    @if ch_code == 10  @! '\n'
      lines.push(curr_line)
      curr_line = ""
    @elif ch_code != 13  @! skip '\r'
      ch = str_substr(content, i, i + 1)
      curr_line = curr_line + ch
    @end
    i = i + 1
  @end
  @if curr_line.len() > 0
    lines.push(curr_line)
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
  buf = maya_alloc(buf_size)

  @while 1
    nread = sys_getdents64(fd, buf, buf_size)
    @if nread <= 0
      break
    @end

    pos = 0
    @while pos < nread
      entry_ptr = buf + pos
      name_ptr = entry_ptr + 19
      name = maya_str_new(name_ptr)

      reclen = entry_ptr.d_reclen_type & 65535
      @if reclen <= 0
        break
      @end

      @if name != "." && name != ".."
        entries.push(name)
      @end

      pos = pos + reclen
    @end
  @end

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
