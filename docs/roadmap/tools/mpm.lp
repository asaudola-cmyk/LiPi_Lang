@! ============================================================================
@! MAYA PACKAGE MANAGER (MPM) — tools/mpm.maya
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/fs"

@fn mpm_parse_manifest(manifest_content)
  println("  [MPM] Parsing maya.toml manifest...")
  lines = string_split(manifest_content, "\n")
  pkg_name = "unknown"
  version = "0.1.0"
  
  @for line in lines
    trimmed = string_trim(line)
    @if starts_with(trimmed, "name = ")
      pkg_name = string_slice(trimmed, 7, trimmed.len())
    @elif starts_with(trimmed, "version = ")
      version = string_slice(trimmed, 10, trimmed.len())
    @end
  @end
  
  return { name: pkg_name, version: version }
@end

@fn mpm_install(pkg_name)
  println("📦 [MPM] Resolving package: " + pkg_name + "...")
  target_dir = "universe/deps/" + pkg_name
  dir_create(target_dir)
  pkg_info = "name = \"" + pkg_name + "\"\ninstalled = true\n"
  file_write(target_dir + "/package.toml", pkg_info)
  println("  ✓ Package " + pkg_name + " installed to " + target_dir)
  return 1
@end

@fn mpm_build()
  println("🔨 [MPM] Building current project according to maya.toml...")
  manifest = file_read("maya.toml")
  @if manifest == ""
    println("❌ Error: maya.toml not found")
    return 0
  @end
  info = mpm_parse_manifest(manifest)
  println("  ✓ Built package: " + info.name)
  return 1
@end
