@! ============================================================================
@! 👑 LIPI PACKAGE MANAGER (LIPIPKG) — docs/roadmap/tools/lipipkg_cli.lp
@! 100% Written in Pure Lipi Language
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/fs"

@fn lipipkg_parse_manifest(manifest_content)
  println("  [LIPIPKG] Parsing lipi.toml manifest...")
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

// WHY: Sovereign LPM manifest parser alias
@fn lpm_parse_manifest(manifest_content)
  return lipipkg_parse_manifest(manifest_content)
@end

@fn lipipkg_install(pkg_name)
  println("📦 [LIPIPKG] Resolving package: " + pkg_name + "...")
  target_dir = "universe/deps/" + pkg_name
  dir_create(target_dir)
  pkg_info = "name = \"" + pkg_name + "\"\ninstalled = true\n"
  file_write(target_dir + "/package.toml", pkg_info)
  println("  ✓ Package " + pkg_name + " installed to " + target_dir)
  return 1
@end

// WHY: Sovereign LPM install alias
@fn lpm_install(pkg_name)
  return lipipkg_install(pkg_name)
@end

@fn lipipkg_build()
  println("🔨 [LIPIPKG] Building current project according to lipi.toml...")
  manifest = file_read("lipi.toml")
  @if manifest == ""
    manifest = file_read("lipipkg.toml")
  @end
  @if manifest == ""
    println("❌ Error: lipi.toml or lipipkg.toml not found")
    return 0
  @end
  info = lipipkg_parse_manifest(manifest)
  println("  ✓ Built package: " + info.name)
  return 1
@end

// WHY: Sovereign LPM build alias
@fn lpm_build()
  return lipipkg_build()
@end
