@! ============================================================================
@! LIPI UNIVERSE WEB — URL DECODER & QUERY PARSER (universe/web/url.lp)
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! RFC 3986 URL Percent-Decoding, Component Encoding, and Query String Parser
@! ============================================================================

import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. Data Structures
@! ----------------------------------------------------------------------------

@struct QueryPair
  key: ""
  value: ""
@end

@struct ParsedUrl
  protocol: "http"
  host: "localhost"
  port: 80
  path: "/"
  raw_query: ""
  query: 0
  fragment: ""
@end

@! ----------------------------------------------------------------------------
@! 2. Hexadecimal Helpers
@! ----------------------------------------------------------------------------

@fn hex_char_to_int(ch)
  @if ch >= 48 && ch <= 57 return ch - 48 @end
  @if ch >= 97 && ch <= 102 return ch - 97 + 10 @end
  @if ch >= 65 && ch <= 70 return ch - 65 + 10 @end
  return -1
@end

@fn int_to_hex_char(val)
  @if val >= 0 && val <= 9 return str_from_char_code(val + 48) @end
  @if val >= 10 && val <= 15 return str_from_char_code(val - 10 + 65) @end
  return "0"
@end

@! ----------------------------------------------------------------------------
@! 3. RFC 3986 URL Percent-Decoding & Component Encoding
@! ----------------------------------------------------------------------------

@! Decodes %XX hexadecimal escape sequences to ASCII/UTF-8 bytes and '+' to space
@fn url_decode(s)
  res = ""
  i = 0
  slen = s.len()
  @while i < slen
    ch = str_char_at(s, i)
    @if ch == 37 @! '%'
      @if i + 2 < slen
        h1 = hex_char_to_int(str_char_at(s, i + 1))
        h2 = hex_char_to_int(str_char_at(s, i + 2))
        @if h1 >= 0 && h2 >= 0
          code = (h1 * 16) + h2
          res = res + str_from_char_code(code)
          i = i + 3
        @else
          res = res + "%"
          i = i + 1
        @end
      @else
        res = res + "%"
        i = i + 1
      @end
    @elif ch == 43 @! '+'
      res = res + " "
      i = i + 1
    @else
      res = res + str_from_char_code(ch)
      i = i + 1
    @end
  @end
  return res
@end

@! URL Percent-Encoding for reserved and special characters
@fn url_encode_component(s)
  res = ""
  i = 0
  slen = s.len()
  @while i < slen
    ch = str_char_at(s, i)
    @if (ch >= 48 && ch <= 57) || (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122) || ch == 45 || ch == 95 || ch == 46 || ch == 126
      @! Unreserved RFC 3986 characters: A-Z, a-z, 0-9, '-', '_', '.', '~'
      res = res + str_from_char_code(ch)
    @elif ch == 32 @! space
      res = res + "%20"
    @else
      h1 = (ch / 16) & 15
      h2 = ch & 15
      res = res + "%" + int_to_hex_char(h1) + int_to_hex_char(h2)
    @end
    i = i + 1
  @end
  return res
@end

@! ----------------------------------------------------------------------------
@! 4. Query String Parser
@! ----------------------------------------------------------------------------

@! Parses query string (e.g. "?a=1&b=2" or "a=1&b=2") into list of { key, value }
@fn url_parse_query(query_str)
  pairs = []
  raw = query_str
  @if starts_with(raw, "?") == 1
    raw = str_substr(raw, 1, raw.len())
  @end

  qlen = raw.len()
  @if qlen == 0
    return pairs
  @end

  pos = 0
  @while pos < qlen
    amp_pos = pos
    @while amp_pos < qlen && str_char_at(raw, amp_pos) != 38 @! '&'
      amp_pos = amp_pos + 1
    @end

    part = str_substr(raw, pos, amp_pos)
    @if part.len() > 0
      eq_pos = str_index_of(part, "=")
      @if eq_pos >= 0
        k = str_substr(part, 0, eq_pos)
        v = str_substr(part, eq_pos + 1, part.len())
        pairs = pairs.push({ key: url_decode(k), value: url_decode(v) })
      @else
        pairs = pairs.push({ key: url_decode(part), value: "" })
      @end
    @end

    pos = amp_pos + 1
  @end

  return pairs
@end

@! Gets first matching value for key in query pairs
@fn url_query_get(pairs, key_name, default_val)
  i = 0
  plen = pairs.len()
  @while i < plen
    p = pairs[i]
    @if p.key == key_name
      return p.value
    @end
    i = i + 1
  @end
  return default_val
@end

@! Gets all matching values for key in query pairs (multi-value query keys)
@fn url_query_get_all(pairs, key_name)
  res = []
  i = 0
  plen = pairs.len()
  @while i < plen
    p = pairs[i]
    @if p.key == key_name
      res = res.push(p.value)
    @end
    i = i + 1
  @end
  return res
@end

@! Checks if key exists in query pairs
@fn url_query_has(pairs, key_name)
  i = 0
  plen = pairs.len()
  @while i < plen
    p = pairs[i]
    @if p.key == key_name
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 5. Full URL Parser
@! ----------------------------------------------------------------------------

@! Parses complete URL into protocol, host, port, path, query, raw_query, fragment
@fn url_parse(full_url)
  proto = "http"
  host = "localhost"
  port = 80
  path = "/"
  raw_query = ""
  fragment = ""

  rem = full_url
  @if starts_with(rem, "http://") == 1
    rem = str_substr(rem, 7, rem.len())
    proto = "http"
    port = 80
  @elif starts_with(rem, "https://") == 1
    rem = str_substr(rem, 8, rem.len())
    proto = "https"
    port = 443
  @end

  hash_pos = str_index_of(rem, "#")
  @if hash_pos >= 0
    fragment = str_substr(rem, hash_pos + 1, rem.len())
    rem = str_substr(rem, 0, hash_pos)
  @end

  q_pos = str_index_of(rem, "?")
  @if q_pos >= 0
    raw_query = str_substr(rem, q_pos + 1, rem.len())
    rem = str_substr(rem, 0, q_pos)
  @end

  slash_pos = str_index_of(rem, "/")
  host_port = ""
  @if slash_pos >= 0
    host_port = str_substr(rem, 0, slash_pos)
    path = str_substr(rem, slash_pos, rem.len())
  @else
    host_port = rem
    path = "/"
  @end

  colon_pos = str_index_of(host_port, ":")
  @if colon_pos >= 0
    host = str_substr(host_port, 0, colon_pos)
    port_str = str_substr(host_port, colon_pos + 1, host_port.len())
    p_num = 0
    p_i = 0
    @while p_i < port_str.len()
      ch_p = str_char_at(port_str, p_i)
      @if ch_p >= 48 && ch_p <= 57
        p_num = (p_num * 10) + (ch_p - 48)
      @end
      p_i = p_i + 1
    @end
    @if p_num > 0 port = p_num @end
  @else
    host = host_port
  @end

  @if host == "" host = "localhost" @end
  @if path == "" path = "/" @end

  query_pairs = url_parse_query(raw_query)

  return {
    protocol: proto,
    host: host,
    port: port,
    path: path,
    raw_query: raw_query,
    query: query_pairs,
    fragment: fragment
  }
@end
