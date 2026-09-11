import "universe/core/string"

@fn path_join(base, part)
  @if base.len() == 0 return part @end
  @if part.len() == 0 return base @end
  base_has_slash = ends_with(base, "/")
  part_has_slash = starts_with(part, "/")
  @if base_has_slash == 1 && part_has_slash == 1
    return base + str_substr(part, 1, part.len())
  @end
  @if base_has_slash == 1 || part_has_slash == 1
    return base + part
  @end
  return base + "/" + part
@end

@fn path_dirname(path)
  @if path.len() == 0 return "." @end
  cur = path
  @while cur.len() > 1 && str_char_at(cur, cur.len() - 1) == 47
    cur = str_substr(cur, 0, cur.len() - 1)
  @end
  @if cur == "/" return "/" @end
  num_items = cur.len()
  i = num_items - 1
  last_slash = -1
  @while i >= 0
    @if str_char_at(cur, i) == 47
      last_slash = i
      break
    @end
    i = i - 1
  @end
  @if last_slash < 0 return "." @end
  @if last_slash == 0 return "/" @end
  return str_substr(cur, 0, last_slash)
@end

@fn path_basename(path)
  @if path.len() == 0 return "" @end
  cur = path
  @while cur.len() > 1 && str_char_at(cur, cur.len() - 1) == 47
    cur = str_substr(cur, 0, cur.len() - 1)
  @end
  @if cur == "/" return "/" @end
  num_items = cur.len()
  i = num_items - 1
  last_slash = -1
  @while i >= 0
    @if str_char_at(cur, i) == 47
      last_slash = i
      break
    @end
    i = i - 1
  @end
  @if last_slash < 0 return cur @end
  return str_substr(cur, last_slash + 1, num_items)
@end

@fn path_ext(path)
  base = path_basename(path)
  num_items = base.len()
  @if num_items == 0 return "" @end
  i = num_items - 1
  last_dot = -1
  @while i >= 0
    @if str_char_at(base, i) == 46
      last_dot = i
      break
    @end
    i = i - 1
  @end
  @if last_dot <= 0 return "" @end
  return str_substr(base, last_dot, num_items)
@end

@fn path_extension(path)
  return path_ext(path)
@end

@fn path_is_abs(path)
  @if path.len() == 0 return 0 @end
  @if str_char_at(path, 0) == 47 return 1 @end
  return 0
@end

@fn path_is_absolute(path)
  return path_is_abs(path)
@end

@fn path_normalize(path)
  @if path.len() == 0 return "." @end
  is_abs = path_is_abs(path)
  tokens = string_split(path, "/")
  stack = []
  stack_len = 0
  
  i = 0
  t_len = tokens.len()
  @while i < t_len
    seg = tokens[i]
    @if seg == "" || seg == "."
      @! skip
    @else
      @if seg == ".."
        @if stack_len > 0 && stack[stack_len - 1] != ".."
          stack_len = stack_len - 1
          new_stk = []
          j = 0
          @while j < stack_len
            new_stk = new_stk.push(stack[j])
            j = j + 1
          @end
          stack = new_stk
        @else
          @if is_abs == 0
            stack = stack.push("..")
            stack_len = stack_len + 1
          @end
        @end
      @else
        stack = stack.push(seg)
        stack_len = stack_len + 1
      @end
    @end
    i = i + 1
  @end

  @if is_abs == 1
    @if stack_len == 0 return "/" @end
    res = ""
    k = 0
    @while k < stack_len
      res = res + "/" + stack[k]
      k = k + 1
    @end
    return res
  @else
    @if stack_len == 0 return "." @end
    res = ""
    k = 0
    @while k < stack_len
      @if k > 0
        res = res + "/" + stack[k]
      @else
        res = stack[k]
      @end
      k = k + 1
    @end
    return res
  @end
@end
