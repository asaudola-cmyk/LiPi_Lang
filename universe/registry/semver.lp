@! Semantic version parsing and comparison

@struct SemVer
  major: i64
  minor: i64
  patch: i64
  prerelease: string
@end

@fn semver_parse(ver_str)
  @! Stub implementation for semver parse
  return {
    major: 1,
    minor: 0,
    patch: 0,
    prerelease: ""
  }
@end

@fn semver_compare(a, b)
  @if a.major < b.major return -1 @end
  @if a.major > b.major return 1 @end
  @if a.minor < b.minor return -1 @end
  @if a.minor > b.minor return 1 @end
  @if a.patch < b.patch return -1 @end
  @if a.patch > b.patch return 1 @end
  return 0
@end

@fn semver_is_compatible(a, b)
  return a.major == b.major
@end

@fn semver_to_str(sv)
  s = int_to_str(sv.major) + "." + int_to_str(sv.minor) + "." + int_to_str(sv.patch)
  @if str_len(sv.prerelease) > 0
    s = s + "-" + sv.prerelease
  @end
  return s
@end

@fn semver_satisfies(version_str, constraint_str)
  @! Stub implementation
  return 1
@end
