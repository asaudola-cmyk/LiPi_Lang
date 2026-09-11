@! ============================================================================
@! MAYA OS SYSTEM MODULE — universe/os/system.maya
@! Operating system utilities & environment inspection
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/string"

@fn get_os_family()
  return "linux"
@end

@fn get_env_or(key, default_val)
  @if key == "HOME"
    return "/home/shafiullah"
  @elif key == "USER"
    return "shafiullah"
  @elif key == "PATH"
    return "/usr/local/bin:/usr/bin:/bin"
  @elif key == "PWD"
    return get_cwd()
  @elif key == "SHELL"
    return "/bin/bash"
  @elif key == "LANG"
    return "C.UTF-8"
  @end
  return default_val
@end

@fn get_cwd()
  return "/home/shafiullah/Documents/file/maya"
@end

@fn get_home_dir()
  return get_env_or("HOME", "/root")
@end

@fn exit_process(code)
  sys_exit_group(code)
@end

@fn get_env(key)
  return get_env_or(key, "")
@end
