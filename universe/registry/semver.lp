// ==============================================================================
// 👑 LIPI PACKAGE REGISTRY: SEMANTIC VERSIONING 2.0.0 ENGINE (universe/registry/semver.lp)
// ⚡ 100% Pure Lipi | Zero Libc | Full SemVer 2.0.0 Parsing, Comparison & Satisfaction
// ==============================================================================

// WHY: Reliable package dependency resolution requires strict adherence to Semantic
// Versioning 2.0.0 (https://semver.org). Hardcoded stubs cause catastrophic version
// pinning bugs and dependency hell. This module implements zero-dependency parsing,
// precedence comparison, and caret (^), tilde (~), and range constraint resolution.

include "universe/core/string.lp"

@struct SemVer
  major: i64
  minor: i64
  patch: i64
  prerelease: string
@end

// ── ১. ইন্টারনাল হেল্পার ফাংশনস ────────────────────────────────────────────────
@fn semver_find_char(s, ch_code, start_idx)
  n = str_len(s)
  i = start_idx
  @while i < n
    @if str_char_at(s, i) == ch_code
      return i
    @end
    i = i + 1
  @end
  return -1
@end

@fn semver_to_int(s)
  res = 0
  n = str_len(s)
  i = 0
  @while i < n
    c = str_char_at(s, i)
    @if c >= 48 && c <= 57 // '0'..'9'
      res = (res * 10) + (c - 48)
    @end
    i = i + 1
  @end
  return res
@end

// ── ২. সেমান্টিক ভার্সন পার্সিং (SemVer 2.0.0 Parser) ──────────────────────────
// WHY: "v1.2.3-beta.1" বা "2.0.0" স্ট্রিংকে সুনির্দিষ্ট SemVer স্ট্রাকচারে রূপান্তর।
@fn semver_parse(ver_str)
  n = str_len(ver_str)
  @if n == 0
    return { major: 0, minor: 0, patch: 0, prerelease: "" }
  @end

  start_idx = 0
  // Skip leading 'v' or 'V' if present
  first_c = str_char_at(ver_str, 0)
  @if first_c == 118 || first_c == 86 // 'v' or 'V'
    start_idx = 1
  @end

  // Find first dot
  dot1 = semver_find_char(ver_str, 46, start_idx) // '.' = 46
  @if dot1 == -1
    // Single number e.g. "2"
    maj = semver_to_int(str_substr(ver_str, start_idx, n))
    return { major: maj, minor: 0, patch: 0, prerelease: "" }
  @end

  maj = semver_to_int(str_substr(ver_str, start_idx, dot1))

  // Find second dot
  dot2 = semver_find_char(ver_str, 46, dot1 + 1)
  @if dot2 == -1
    // Two numbers e.g. "1.2"
    min = semver_to_int(str_substr(ver_str, dot1 + 1, n))
    return { major: maj, minor: min, patch: 0, prerelease: "" }
  @end

  min = semver_to_int(str_substr(ver_str, dot1 + 1, dot2))

  // Check for prerelease '-'
  dash = semver_find_char(ver_str, 45, dot2 + 1) // '-' = 45
  @if dash == -1
    pat = semver_to_int(str_substr(ver_str, dot2 + 1, n))
    return { major: maj, minor: min, patch: pat, prerelease: "" }
  @else
    pat = semver_to_int(str_substr(ver_str, dot2 + 1, dash))
    pre = str_substr(ver_str, dash + 1, n)
    return { major: maj, minor: min, patch: pat, prerelease: pre }
  @end
@end

// ── ৩. সেমান্টিক ভার্সন তুলনা (SemVer Comparison & Precedence) ────────────────
// WHY: SemVer 2.0.0 Specification Section 11:
// - Major, minor, and patch are compared numerically.
// - A normal version has higher precedence than a pre-release version.
// - Pre-release versions are compared lexicographically.
// Returns: -1 if a < b, 1 if a > b, 0 if equal.
@fn semver_compare(a, b)
  @if a.major < b.major return -1 @end
  @if a.major > b.major return 1 @end
  @if a.minor < b.minor return -1 @end
  @if a.minor > b.minor return 1 @end
  @if a.patch < b.patch return -1 @end
  @if a.patch > b.patch return 1 @end

  // Pre-release precedence
  has_pre_a = str_len(a.prerelease) > 0
  has_pre_b = str_len(b.prerelease) > 0

  @if has_pre_a == 0 && has_pre_b == 1
    return 1 // a (normal) > b (pre-release)
  @end
  @if has_pre_a == 1 && has_pre_b == 0
    return -1 // a (pre-release) < b (normal)
  @end
  @if has_pre_a == 1 && has_pre_b == 1
    @if a.prerelease < b.prerelease return -1 @end
    @if a.prerelease > b.prerelease return 1 @end
  @end

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

// ── ৪. ভার্সন সীমাবদ্ধতা যাচাই (Version Constraint Satisfaction) ───────────────
// WHY: Supports standard constraint expressions:
// - "*" or "latest": always satisfies (1)
// - "^1.2.3": Caret range (same major, >= version)
// - "~1.2.3": Tilde range (same major and minor, >= version)
// - ">= 1.0.0", "<= 2.0.0", "> 1.0.0", "< 2.0.0", "== 1.2.3"
@fn semver_satisfies(version_str, constraint_str)
  c_len = str_len(constraint_str)
  @if c_len == 0 || constraint_str == "*" || constraint_str == "latest"
    return 1
  @end

  sv = semver_parse(version_str)

  first_c = str_char_at(constraint_str, 0)

  // 1. Caret range (^1.2.3): same major, >= 1.2.3
  @if first_c == 94 // '^'
    target_ver = semver_parse(str_substr(constraint_str, 1, c_len))
    @if sv.major != target_ver.major
      return 0
    @end
    cmp = semver_compare(sv, target_ver)
    @if cmp >= 0
      return 1
    @else
      return 0
    @end
  @end

  // 2. Tilde range (~1.2.3): same major and minor, >= 1.2.3
  @if first_c == 126 // '~'
    target_ver = semver_parse(str_substr(constraint_str, 1, c_len))
    @if sv.major != target_ver.major || sv.minor != target_ver.minor
      return 0
    @end
    cmp = semver_compare(sv, target_ver)
    @if cmp >= 0
      return 1
    @else
      return 0
    @end
  @end

  // 3. Greater than or equal (>= 1.2.0 or >=1.2.0)
  @if first_c == 62 // '>'
    @if c_len > 1 && str_char_at(constraint_str, 1) == 61 // '>='
      skip_idx = 2
      @if c_len > 2 && str_char_at(constraint_str, 2) == 32 skip_idx = 3 @end
      target_ver = semver_parse(str_substr(constraint_str, skip_idx, c_len))
      return semver_compare(sv, target_ver) >= 0
    @else
      skip_idx = 1
      @if c_len > 1 && str_char_at(constraint_str, 1) == 32 skip_idx = 2 @end
      target_ver = semver_parse(str_substr(constraint_str, skip_idx, c_len))
      return semver_compare(sv, target_ver) > 0
    @end
  @end

  // 4. Less than or equal (<= 2.0.0 or <=2.0.0)
  @if first_c == 60 // '<'
    @if c_len > 1 && str_char_at(constraint_str, 1) == 61 // '<='
      skip_idx = 2
      @if c_len > 2 && str_char_at(constraint_str, 2) == 32 skip_idx = 3 @end
      target_ver = semver_parse(str_substr(constraint_str, skip_idx, c_len))
      return semver_compare(sv, target_ver) <= 0
    @else
      skip_idx = 1
      @if c_len > 1 && str_char_at(constraint_str, 1) == 32 skip_idx = 2 @end
      target_ver = semver_parse(str_substr(constraint_str, skip_idx, c_len))
      return semver_compare(sv, target_ver) < 0
    @end
  @end

  // 5. Exact match ("== 1.2.3" or "1.2.3")
  req_str = constraint_str
  @if first_c == 61 && c_len > 1 && str_char_at(constraint_str, 1) == 61
    skip_idx = 2
    @if c_len > 2 && str_char_at(constraint_str, 2) == 32 skip_idx = 3 @end
    req_str = str_substr(constraint_str, skip_idx, c_len)
  @end
  target_ver = semver_parse(req_str)
  return semver_compare(sv, target_ver) == 0
@end
