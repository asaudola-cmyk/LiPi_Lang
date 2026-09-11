@! ============================================================================
@! MAYA REGISTRY — Public Package Hosting System
@! The Maya package registry: where Maya packages live
@! Maya's own npm/crates.io/PyPI
@! ============================================================================

@struct Package
  pkg_name: string
  pkg_version: string
  pkg_author: string
  pkg_description: string
  pkg_license: string
  pkg_tags: array
  pkg_deps: array
  pkg_downloads: i64
  pkg_verified: i64
@end

@struct Registry
  reg_url: string
  reg_packages: array
  reg_total: i64
@end

@fn package_new(name, version, author, description)
  return {
    pkg_name: name,
    pkg_version: version,
    pkg_author: author,
    pkg_description: description,
    pkg_license: "MIT",
    pkg_tags: [],
    pkg_deps: [],
    pkg_downloads: 0,
    pkg_verified: 0
  }
@end

@fn package_add_tag(pkg, tag)
  pkg.pkg_tags = pkg.pkg_tags.push(tag)
  return pkg
@end

@fn package_add_dep(pkg, dep_name, dep_version)
  dep = { dep_n: dep_name, dep_v: dep_version }
  pkg.pkg_deps = pkg.pkg_deps.push(dep)
  return pkg
@end

@fn registry_new(url)
  return {
    reg_url: url,
    reg_packages: [],
    reg_total: 0
  }
@end

@fn registry_publish(reg, pkg)
  reg.reg_packages = reg.reg_packages.push(pkg)
  reg.reg_total = reg.reg_total + 1
  return reg
@end

@fn registry_search(reg, query)
  results = []
  i = 0
  @while i < reg.reg_packages.len()
    pkg = reg.reg_packages[i]
    @if str_contains(pkg.pkg_name, query)
      results = results.push(pkg)
    @elif str_contains(pkg.pkg_description, query)
      results = results.push(pkg)
    @end
    i = i + 1
  @end
  return results
@end

@fn registry_find(reg, name, version)
  i = 0
  @while i < reg.reg_packages.len()
    pkg = reg.reg_packages[i]
    @if pkg.pkg_name == name && pkg.pkg_version == version
      return pkg
    @end
    i = i + 1
  @end
  return package_new("", "", "", "")
@end

@fn registry_list_all(reg)
  i = 0
  @while i < reg.reg_packages.len()
    pkg = reg.reg_packages[i]
    println(pkg.pkg_name + " v" + pkg.pkg_version + " by " + pkg.pkg_author)
    i = i + 1
  @end
@end

@fn registry_stats(reg)
  println("Maya Registry: " + reg.reg_url)
  println("Total packages: " + int_to_str(reg.reg_total))
@end

@fn registry_install(reg, name, version, install_path)
  pkg = registry_find(reg, name, version)
  @if str_len(pkg.pkg_name) == 0
    println("Error: package not found: " + name + "@" + version)
    return 0
  @end
  println("Installing " + name + "@" + version + " to " + install_path)
  return 1
@end

@fn registry_verify(reg, pkg_name)
  i = 0
  @while i < reg.reg_packages.len()
    pkg = reg.reg_packages[i]
    @if pkg.pkg_name == pkg_name
      pkg.pkg_verified = 1
      println("Verified: " + pkg_name)
      return 1
    @end
    i = i + 1
  @end
  return 0
@end
