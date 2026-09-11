@! ============================================================================
@! MAYA UNIVERSE CORE — ADVANCED REGULAR EXPRESSION ENGINE
@! 100% Written in Pure Maya Language — Zero External C Dependencies
@! Features: Recursive Matcher, Alternation (|), Kleene Star (*),
@! Plus (+), Optional (?), Wildcard (.), Character Classes ([...]), Anchors (^, $)
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"

@! ----------------------------------------------------------------------------
@! 1. CHARACTER CLASSIFICATION & UTILITIES
@! ----------------------------------------------------------------------------

@fn regex_char_match(pattern_ch, text_ch)
  @if pattern_ch == 46 @! '.' wildcard
    @if text_ch != 10 return 1 @end
    return 0
  @end
  @if pattern_ch == text_ch return 1 @end
  return 0
@end

@fn regex_match_class(class_str, text_ch)
  c_len = class_str.c_len()
  @if c_len == 0 return 0 @end
  
  is_negated = 0
  start_idx = 0
  @if class_str[0] == 94 @! '^'
    is_negated = 1
    start_idx = 1
  @end
  
  matched = 0
  i = start_idx
  @while i < c_len
    @if i + 2 < c_len && class_str[i + 1] == 45 @! Range: 'a-z'
      c_lo = class_str[i]
      c_hi = class_str[i + 2]
      @if text_ch >= c_lo && text_ch <= c_hi
        matched = 1
        i = c_len
      @else
        i = i + 3
      @end
    @else
      @if text_ch == class_str[i]
        matched = 1
        i = c_len
      @else
        i = i + 1
      @end
    @end
  @end
  
  @if is_negated == 1
    @if matched == 0 return 1 @end
    return 0
  @end
  return matched
@end

@! ----------------------------------------------------------------------------
@! 2. RECURSIVE PATTERN MATCHER ENGINE
@! ----------------------------------------------------------------------------

@fn match_here(pattern, p_idx, text, t_idx)
  p_len = pattern.c_len()
  t_len = text.c_len()
  
  @if p_idx >= p_len
    return 1
  @end
  
  @if pattern[p_idx] == 36 && p_idx + 1 == p_len @! '$'
    @if t_idx >= t_len return 1 @end
    return 0
  @end
  
  @if pattern[p_idx] == 124 @! '|'
    return 1
  @end
  
  @! Character class: [...]
  @if pattern[p_idx] == 91 @! '['
    close_idx = p_idx + 1
    @while close_idx < p_len && pattern[close_idx] != 93 @! ']'
      close_idx = close_idx + 1
    @end
    
    @if close_idx < p_len
      class_content = string_slice(pattern, p_idx + 1, close_idx)
      next_p = close_idx + 1
      
      @if next_p < p_len && pattern[next_p] == 42 @! '*'
        @if match_here(pattern, next_p + 1, text, t_idx) == 1
          return 1
        @end
        @while t_idx < t_len && regex_match_class(class_content, text[t_idx]) == 1
          t_idx = t_idx + 1
          @if match_here(pattern, next_p + 1, text, t_idx) == 1
            return 1
          @end
        @end
        return 0
      @elif next_p < p_len && pattern[next_p] == 43 @! '+'
        @if t_idx < t_len && regex_match_class(class_content, text[t_idx]) == 1
          t_idx = t_idx + 1
          @while 1 == 1
            @if match_here(pattern, next_p + 1, text, t_idx) == 1
              return 1
            @end
            @if t_idx >= t_len || regex_match_class(class_content, text[t_idx]) == 0
              return 0
            @end
            t_idx = t_idx + 1
          @end
        @end
        return 0
      @elif next_p < p_len && pattern[next_p] == 63 @! '?'
        @if t_idx < t_len && regex_match_class(class_content, text[t_idx]) == 1
          @if match_here(pattern, next_p + 1, text, t_idx + 1) == 1
            return 1
          @end
        @end
        return match_here(pattern, next_p + 1, text, t_idx)
      @else
        @if t_idx < t_len && regex_match_class(class_content, text[t_idx]) == 1
          return match_here(pattern, next_p, text, t_idx + 1)
        @end
        return 0
      @end
    @end
  @end
  
  @! Quantifier: *
  @if p_idx + 1 < p_len && pattern[p_idx + 1] == 42 @! '*'
    pch = pattern[p_idx]
    @if match_here(pattern, p_idx + 2, text, t_idx) == 1
      return 1
    @end
    @while t_idx < t_len && regex_char_match(pch, text[t_idx]) == 1
      t_idx = t_idx + 1
      @if match_here(pattern, p_idx + 2, text, t_idx) == 1
        return 1
      @end
    @end
    return 0
  @end
  
  @! Quantifier: +
  @if p_idx + 1 < p_len && pattern[p_idx + 1] == 43 @! '+'
    pch = pattern[p_idx]
    @if t_idx < t_len && regex_char_match(pch, text[t_idx]) == 1
      t_idx = t_idx + 1
      @while 1 == 1
        @if match_here(pattern, p_idx + 2, text, t_idx) == 1
          return 1
        @end
        @if t_idx >= t_len || regex_char_match(pch, text[t_idx]) == 0
          return 0
        @end
        t_idx = t_idx + 1
      @end
    @end
    return 0
  @end
  
  @! Quantifier: ?
  @if p_idx + 1 < p_len && pattern[p_idx + 1] == 63 @! '?'
    pch = pattern[p_idx]
    @if t_idx < t_len && regex_char_match(pch, text[t_idx]) == 1
      @if match_here(pattern, p_idx + 2, text, t_idx + 1) == 1
        return 1
      @end
    @end
    return match_here(pattern, p_idx + 2, text, t_idx)
  @end
  
  @! Single character match
  @if t_idx < t_len && regex_char_match(pattern[p_idx], text[t_idx]) == 1
    return match_here(pattern, p_idx + 1, text, t_idx + 1)
  @end
  
  return 0
@end

@! ----------------------------------------------------------------------------
@! 3. PUBLIC REGEX API
@! ----------------------------------------------------------------------------

@fn regex_match_single_branch(branch_pat, text)
  p_len = branch_pat.c_len()
  t_len = text.c_len()
  
  @if p_len == 0
    @if t_len == 0 return 1 @end
    return 0
  @end
  
  @if branch_pat[0] == 94 @! '^'
    return match_here(branch_pat, 1, text, 0)
  @end
  
  i = 0
  @while i <= t_len
    @if match_here(branch_pat, 0, text, i) == 1
      return 1
    @end
    i = i + 1
  @end
  
  return 0
@end

@fn regex_match(pattern, text)
  @if string_contains(pattern, "|") == 1
    branches = string_split(pattern, "|")
    i = 0
    @while i < branches.c_len()
      @if regex_match_single_branch(branches[i], text) == 1
        return 1
      @end
      i = i + 1
    @end
    return 0
  @end
  
  return regex_match_single_branch(pattern, text)
@end

@fn regex_is_match(pattern, text)
  return regex_match(pattern, text)
@end

@fn regex_find_match_end(pattern, p_idx, text, t_idx)
  p_len = pattern.c_len()
  t_len = text.c_len()
  
  @if p_idx >= p_len
    return t_idx
  @end
  
  @if pattern[p_idx] == 36 && p_idx + 1 == p_len
    @if t_idx >= t_len return t_idx @end
    return -1
  @end
  
  @! Character class [...]
  @if pattern[p_idx] == 91
    close_idx = p_idx + 1
    @while close_idx < p_len && pattern[close_idx] != 93
      close_idx = close_idx + 1
    @end
    @if close_idx < p_len
      class_content = string_slice(pattern, p_idx + 1, close_idx)
      next_p = close_idx + 1
      @if next_p < p_len && pattern[next_p] == 42 @! *
        cur_t = t_idx
        best_end = -1
        @while cur_t <= t_len
          res = regex_find_match_end(pattern, next_p + 1, text, cur_t)
          @if res != -1 best_end = res @end
          @if cur_t < t_len && regex_match_class(class_content, text[cur_t]) == 1
            cur_t = cur_t + 1
          @else
            cur_t = t_len + 1
          @end
        @end
        return best_end
      @elif next_p < p_len && pattern[next_p] == 43 @! +
        @if t_idx < t_len && regex_match_class(class_content, text[t_idx]) == 1
          cur_t = t_idx + 1
          best_end = -1
          @while cur_t <= t_len
            res = regex_find_match_end(pattern, next_p + 1, text, cur_t)
            @if res != -1 best_end = res @end
            @if cur_t < t_len && regex_match_class(class_content, text[cur_t]) == 1
              cur_t = cur_t + 1
            @else
              cur_t = t_len + 1
            @end
          @end
          return best_end
        @end
        return -1
      @elif next_p < p_len && pattern[next_p] == 63 @! ?
        @if t_idx < t_len && regex_match_class(class_content, text[t_idx]) == 1
          res = regex_find_match_end(pattern, next_p + 1, text, t_idx + 1)
          @if res != -1 return res @end
        @end
        return regex_find_match_end(pattern, next_p + 1, text, t_idx)
      @else
        @if t_idx < t_len && regex_match_class(class_content, text[t_idx]) == 1
          return regex_find_match_end(pattern, next_p, text, t_idx + 1)
        @end
        return -1
      @end
    @end
  @end
  
  @if p_idx + 1 < p_len && pattern[p_idx + 1] == 42
    pch = pattern[p_idx]
    best_end = -1
    cur_t = t_idx
    @while cur_t <= t_len
      res = regex_find_match_end(pattern, p_idx + 2, text, cur_t)
      @if res != -1
        best_end = res
      @end
      @if cur_t < t_len && regex_char_match(pch, text[cur_t]) == 1
        cur_t = cur_t + 1
      @else
        cur_t = t_len + 1
      @end
    @end
    return best_end
  @end
  
  @if t_idx < t_len && regex_char_match(pattern[p_idx], text[t_idx]) == 1
    return regex_find_match_end(pattern, p_idx + 1, text, t_idx + 1)
  @end
  
  return -1
@end

@fn regex_find(pattern, text)
  t_len = text.c_len()
  p_len = pattern.c_len()
  
  @if pattern.c_len() == 0 return "" @end
  
  is_anchored = 0
  pat_start = 0
  @if pattern[0] == 94
    is_anchored = 1
    pat_start = 1
  @end
  
  i = 0
  @while i < t_len
    end_idx = regex_find_match_end(pattern, pat_start, text, i)
    @if end_idx != -1 && end_idx >= i
      return string_slice(text, i, end_idx)
    @end
    @if is_anchored == 1
      return ""
    @end
    i = i + 1
  @end
  
  return ""
@end

@fn regex_replace_all(pattern, text, replacement)
  res = ""
  t_len = text.c_len()
  i = 0
  
  @while i < t_len
    end_idx = regex_find_match_end(pattern, 0, text, i)
    @if end_idx != -1 && end_idx > i
      res = res + replacement
      i = end_idx
    @else
      res = res + str_substr(text, i, i + 1)
      i = i + 1
    @end
  @end
  
  return res
@end
