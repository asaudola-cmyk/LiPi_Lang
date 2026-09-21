// ==============================================================================
// 👑 LIPI SOVEREIGN ALGEBRAIC OPTION TYPE (universe/core/option.lp)
// ⚡ 100% Pure Direct Silicon Machine Code | 0% C | 0% Libc | 0% External Helpers
//    Zero-overhead, panic-safe monadic container for nullable state representation.
//    Null-guarded: passing raw 0/none literal is safely recognized as empty None.
//    Fully safe for Bare-Metal Ring-0 Unikernel and high-throughput systems.
// ==============================================================================

import "universe/core/error"

@struct Option
  is_some: i64
  value: i64
@end

@fn option_some(val)
  // WHY: Constructs an Option representing the presence of a value
  opt = { is_some: 1, value: val }
  return opt
@end

@fn some(val)
  // WHY: Canonical shorthand for option_some
  return option_some(val)
@end

@fn option_none()
  // WHY: Constructs an Option representing the absence of a value
  opt = { is_some: 0, value: 0 }
  return opt
@end

@fn none_option()
  // WHY: Shorthand alias avoiding collision with built-in 'none' literal (0)
  return option_none()
@end

@fn is_some(opt)
  // WHY: Returns 1 if Option is non-null and is_some == 1, 0 otherwise
  @if opt == 0
    return 0
  @end
  @if opt.is_some == 1
    return 1
  @end
  return 0
@end

@fn is_none(opt)
  // WHY: Returns 1 if Option is null (0) or has is_some == 0, 0 otherwise
  @if opt == 0
    return 1
  @end
  @if opt.is_some == 0
    return 1
  @end
  return 0
@end

@fn unwrap_option(opt)
  // WHY: Extracts the encapsulated value from Option; aborts if empty or null
  @if is_none(opt) == 1
    panic("unwrap_option called on None Option")
  @end
  return opt.value
@end

@fn unwrap_option_or(opt, default_val)
  // WHY: Extracts value if present; safely falls back to default_val without panicking
  @if is_some(opt) == 1
    return opt.value
  @end
  return default_val
@end

@fn option_map(opt, mapped_val)
  // WHY: If Option has a value, encapsulates mapped_val into a new Option; propagates None
  @if is_some(opt) == 1
    return option_some(mapped_val)
  @end
  return option_none()
@end

@fn option_and_then(opt1, opt2)
  // WHY: Monadic flat_map: returns opt2 if opt1 is Some; propagates None
  @if is_some(opt1) == 1
    return opt2
  @end
  return option_none()
@end

@fn option_or(opt1, opt2)
  // WHY: Returns opt1 if it is Some; otherwise returns opt2
  @if is_some(opt1) == 1
    return opt1
  @end
  return opt2
@end

@fn option_to_result(opt, err_msg_str)
  // WHY: Converts Option to Result: Some(v) -> ok(v), None -> err(err_msg_str)
  @if is_some(opt) == 1
    return ok(opt.value)
  @end
  return err(err_msg_str)
@end

@fn option_to_str(opt)
  // WHY: Canonical string representation for diagnostics and debugging
  @if is_some(opt) == 1
    return "Some(" + to_str(opt.value) + ")"
  @end
  return "None"
@end

// ==============================================================================
// 🇧🇩 লিপির নিজস্ব খাঁটি দ্বিভাষিক ইন্টারফেস (Bengali Sovereign Native Aliases)
// ==============================================================================

@fn কিছু(মান)
  // WHY: কিছু(মান) দিয়ে Option এর মান ধারণ করা হয়
  return option_some(মান)
@end

@fn নাই()
  // WHY: নাই() দিয়ে শূন্য মান নির্দেশ করা হয় (Option container)
  return option_none()
@end

@fn আছে_কি(অপশন)
  // WHY: অপশনে মান আছে কিনা তা পরীক্ষা করে
  return is_some(অপশন)
@end

@fn নাই_কি(অপশন)
  // WHY: অপশনে মান অনুপস্থিত কিনা তা পরীক্ষা করে
  return is_none(অপশন)
@end

@fn খোল_বা_ফেরত(অপশন, ডিফল্ট_মান)
  // WHY: অপশনের ভেতর থেকে মান বের করে, না থাকলে ডিফল্ট_মান ফেরত দেয়
  return unwrap_option_or(অপশন, ডিফল্ট_মান)
@end
