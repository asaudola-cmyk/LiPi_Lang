// ==============================================================================
// 👑 LIPI SOVEREIGN MONADIC RESULT (universe/core/result.lp)
// ⚡ 100% Pure Direct Silicon Machine Code | 0% C | 0% Libc | 0% External Helpers
//    Zero-overhead monadic Result container for typed failure handling without
//    stack unwinding or runtime penalty. 100% Safe for Bare-Metal Ring-0.
// ==============================================================================

import "universe/core/error"
import "universe/core/option"

@fn result_map(r, f_result)
  // WHY: Transforms the inner value if Ok; propagates error unmodified
  @if is_ok(r) == 1
    return ok(f_result)
  @end
  return r
@end

@fn result_and_then(r1, r2)
  // WHY: Monadic bind: if r1 is Ok, evaluates and returns r2; else propagates r1 error
  @if is_ok(r1) == 1
    return r2
  @end
  return r1
@end

@fn result_or(r, default_val)
  // WHY: Extracts value if Ok; otherwise returns fallback default_val
  @if is_ok(r) == 1
    return unwrap(r)
  @end
  return default_val
@end

@fn result_or_else(r, fallback_val)
  // WHY: If Err, recovers by returning alternative Ok container holding fallback_val
  @if is_ok(r) == 1
    return r
  @end
  return ok(fallback_val)
@end

@fn result_to_option(r)
  // WHY: Converts Result to Option: Ok(val) -> option_some(val), Err(_) -> option_none()
  @if is_ok(r) == 1
    return option_some(r.value)
  @end
  return option_none()
@end

@fn result_to_str(r)
  // WHY: Formats Result into canonical diagnostic string
  @if is_ok(r) == 1
    return "Ok(" + to_str(unwrap(r)) + ")"
  @end
  return "Err(" + err_msg(r) + ")"
@end

@fn try_parse_int(s)
  // WHY: Parses string to integer returning Result instead of throwing
  @if str_len(s) == 0
    return err("empty string")
  @end
  i = 0
  neg = 0
  res = 0
  @if char_at(s, 0) == "-"
    neg = 1
    i = 1
    @if str_len(s) == 1
      return err("invalid minus-only string")
    @end
  @end
  @while i < str_len(s)
    c = ord(char_at(s, i))
    @if c < 48 || c > 57
      return err("invalid non-digit character")
    @end
    res = res * 10 + (c - 48)
    i = i + 1
  @end
  @if neg == 1
    res = 0 - res
  @end
  return ok(res)
@end

@fn try_divide(a, b)
  // WHY: Panic-free integer division returning typed Result
  @if b == 0
    return err("division by zero")
  @end
  return ok(a / b)
@end

// ==============================================================================
// 🇧🇩 লিপির নিজস্ব খাঁটি দ্বিভাষিক ইন্টারফেস (Bengali Sovereign Native Aliases)
// ==============================================================================

@fn সফল(মান)
  // WHY: সফল(মান) দিয়ে Ok Result তৈরি করা হয়
  return ok(মান)
@end

@fn ব্যর্থ(বার্তা)
  // WHY: ব্যর্থ(বার্তা) দিয়ে Err Result তৈরি করা হয়
  return err(বার্তা)
@end

@fn সফল_কি(রেজাল্ট)
  // WHY: রেজাল্ট সফল কিনা পরীক্ষা করে
  return is_ok(রেজাল্ট)
@end

@fn ব্যর্থ_কি(রেজাল্ট)
  // WHY: রেজাল্ট ব্যর্থ কিনা পরীক্ষা করে
  return is_err(রেজাল্ট)
@end

@fn রেজাল্ট_খোল(রেজাল্ট)
  // WHY: রেজাল্ট থেকে সফল মান বের করে
  return unwrap(রেজাল্ট)
@end

@fn রেজাল্ট_খোল_বা_ফেরত(রেজাল্ট, ডিফল্ট_মান)
  // WHY: রেজাল্ট থেকে মান বের করে, ব্যর্থ হলে ডিফল্ট_মান দেয়
  return unwrap_or(রেজাল্ট, ডিফল্ট_মান)
@end

@fn ভাগ_করো_নিরাপদে(লব, হর)
  // WHY: শূন্য দ্বারা ভাগ হওয়া রোধ করে নিরাপদ রেজাল্ট প্রদান করে
  return try_divide(লব, হর)
@end
