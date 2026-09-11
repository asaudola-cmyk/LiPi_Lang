@struct Result
  is_ok: i64
  value: i64
  err_msg: string
@end

@fn panic(msg)
  // WHY: Terminates execution immediately with an error message and exit code 1
  println(msg)
  sys_exit(1)
  return 0
@end

@fn ok(val)
  // WHY: Constructs a successful Result value container with is_ok=1
  r = { is_ok: 1, value: val, err_msg: "" }
  return r
@end

@fn err(msg)
  // WHY: Constructs a failed Result error container with is_ok=0 and descriptive message
  r = { is_ok: 0, value: 0, err_msg: msg }
  return r
@end

@fn is_ok(r)
  // WHY: Returns 1 if Result represents success, 0 otherwise
  @if r.is_ok == 1
    return 1
  @end
  return 0
@end

@fn is_err(r)
  // WHY: Returns 1 if Result represents failure, 0 otherwise
  @if r.is_ok == 0
    return 1
  @end
  return 0
@end

@fn unwrap(r)
  // WHY: Extracts the success value from Result container, panic if error
  @if r.is_ok == 0
    panic("unwrap called on err Result: " + r.err_msg)
  @end
  return r.value
@end

@fn err_msg(r)
  // WHY: Extracts the error message from Result container
  return r.err_msg
@end

@fn unwrap_or(r, default_val)
  // WHY: Extracts success value if ok, otherwise returns provided fallback value
  @if r.is_ok == 1
    return r.value
  @end
  return default_val
@end

