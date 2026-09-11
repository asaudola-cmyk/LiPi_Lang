@! ============================================================================
@! MAYA RESULT — Enhanced Result<T> and Option<T> types
@! ============================================================================

import "universe/core/error"

@fn result_map(r, f_result)
  @! Apply function to ok value, propagate error
  @if is_ok(r)
    return ok(f_result)
  @end
  return r
@end

@fn result_and_then(r1, r2)
  @! Chain results: if r1 is ok, return r2; else propagate error
  @if is_ok(r1)
    return r2
  @end
  return r1
@end

@fn result_or(r, default_val)
  @if is_ok(r)
    return unwrap(r)
  @end
  return default_val
@end

@fn result_to_str(r)
  @if is_ok(r)
    return "Ok(" + int_to_str(unwrap(r)) + ")"
  @end
  return "Err(" + err_msg(r) + ")"
@end

@fn try_parse_int(s)
  @! Try to parse string as int, return Result
  @if str_len(s) == 0
    return err("empty string")
  @end
  i = 0
  @while i < str_len(s)
    c = char_at(s, i)
    @if c < "0" || c > "9"
      @if i == 0 && c == "-"
        @! negative number ok
      @else
        return err("invalid character at pos " + int_to_str(i))
      @end
    @end
    i = i + 1
  @end
  return ok(int_from_str(s))
@end

@fn try_divide(a, b)
  @if b == 0
    return err("division by zero")
  @end
  return ok(a / b)
@end
