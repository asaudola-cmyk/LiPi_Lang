@! ============================================================================
@! MAYA OS ENV MODULE — universe/os/env.maya (Phase 6)
@! Process, environment variable, path helpers
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/string"
import "universe/core/collections"

@! ----------------------------------------------------------------------------
@! SECTION 1 — PROCESS INFO
@! ----------------------------------------------------------------------------

@fn env_getpid()
  return sys_getpid()
@end

@fn env_getppid()
  return sys_getppid()
@end

@fn env_exit(code)
  sys_exit_group(code)
@end

@! ----------------------------------------------------------------------------
@! SECTION 2 — ARGV HELPERS
@! ----------------------------------------------------------------------------

@fn env_args()
  @! Returns all command-line arguments as an array
  return argv()
@end

@fn env_arg(index)
  @! Get argument by index (0 = program name)
  args = argv()
  @if index >= args.len() return "" @end
  return args[index]
@end

@fn env_argc()
  return argv().len()
@end

@fn env_has_flag(flag)
  args = argv()
  @for arg in args
    @if arg == flag return 1 @end
  @end
  return 0
@end

@fn env_flag_value(flag, default_val)
  args = argv()
  i = 0
  @while i < args.len()
    @if args[i] == flag && i + 1 < args.len()
      return args[i + 1]
    @end
    i = i + 1
  @end
  return default_val
@end

@fn env_program_name()
  return env_arg(0)
@end

@! ----------------------------------------------------------------------------
@! SECTION 3 — PATH HELPERS
@! ----------------------------------------------------------------------------

@fn path_join(base, part)
  @! Join two path segments
  @if string_is_empty(base) return part @end
  @if string_is_empty(part) return base @end
  @if ends_with(base, "/")
    return base + part
  @end
  return base + "/" + part
@end

@fn path_dirname(path)
  @! Returns the directory portion of a path
  last_slash = 0 - 1
  i = 0
  @while i < path.len()
    @if path[i] == "/" last_slash = i @end
    i = i + 1
  @end
  @if last_slash == -1 return "." @end
  @if last_slash == 0 return "/" @end
  return string_slice(path, 0, last_slash)
@end

@fn path_basename(path)
  @! Returns the filename portion of a path
  last_slash = 0 - 1
  i = 0
  @while i < path.len()
    @if path[i] == "/" last_slash = i @end
    i = i + 1
  @end
  @if last_slash == -1 return path @end
  return string_slice(path, last_slash + 1, path.len())
@end

@fn path_extension(path)
  @! Returns the file extension including the dot, e.g. ".maya"
  base = path_basename(path)
  last_dot = 0 - 1
  i = 0
  @while i < base.len()
    @if base[i] == "." last_dot = i @end
    i = i + 1
  @end
  @if last_dot == -1 return "" @end
  return string_slice(base, last_dot, base.len())
@end

@fn path_stem(path)
  @! Returns filename without extension
  base = path_basename(path)
  ext = path_extension(path)
  @if ext == "" return base @end
  return string_slice(base, 0, base.len() - ext.len())
@end

@fn path_is_absolute(path)
  @if path.len() == 0 return 0 @end
  @if path[0] == "/" return 1 @end
  return 0
@end

@fn path_normalize(path)
  @! Simplify . and remove double slashes
  @! Simple version: just replace // with /
  return string_replace(path, "//", "/")
@end

@! ----------------------------------------------------------------------------
@! SECTION 4 — FILESYSTEM OPERATIONS
@! ----------------------------------------------------------------------------

@fn fs_mkdir(path, mode)
  @! mode = 0755 = 493 in decimal
  return sys_mkdir(path, mode)
@end

@fn fs_mkdir_p(path)
  @! Create directory and all parents (simple approximation)
  @! Split path by / and create each component
  parts = string_split(path, "/")
  current = ""
  @for part in parts
    @if string_is_empty(part) current = "/" @else
      current = path_join(current, part)
      sys_mkdir(current, 493)  @! ignore errors (may already exist)
    @end
  @end
  return 1
@end

@fn fs_remove(path)
  return sys_unlink(path)
@end

@fn fs_remove_dir(path)
  return sys_rmdir(path)
@end

@fn fs_rename(old_path, new_path)
  return sys_rename(old_path, new_path)
@end

@fn fs_exists(path)
  @! Try to open file read-only, close if successful
  fd = syscall(2, path, 0, 0, 0, 0, 0)
  @if fd < 0 return 0 @end
  sys_close(fd)
  return 1
@end

@fn fs_is_dir(path)
  @! Open with O_RDONLY | O_DIRECTORY (0 | 0x10000 = 65536)
  fd = syscall(2, path, 65536, 0, 0, 0, 0)
  @if fd < 0 return 0 @end
  sys_close(fd)
  return 1
@end

@! ----------------------------------------------------------------------------
@! SECTION 5 — TEMP FILES
@! ----------------------------------------------------------------------------

@fn temp_file_path(prefix)
  @! Generate a temp file path using PID for uniqueness
  pid = env_getpid()
  return "/tmp/" + prefix + "_" + pid.to_str() + ".tmp"
@end

@fn temp_dir_path(prefix)
  pid = env_getpid()
  return "/tmp/" + prefix + "_dir_" + pid.to_str()
@end
