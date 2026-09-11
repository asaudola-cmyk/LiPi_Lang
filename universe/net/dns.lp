@fn maya_pow2(n)
  @if n <= 0 return 1 @end
  res = 1
  i = 0
  @while i < n
    res = res * 2
    i = i + 1
  @end
  return res
@end

@! ============================================================================
@! LIPI UNIVERSE NETWORKING: DNS PROTOCOL & WIRE RESOLVER
@! Module: universe/net/dns
@! 100% Pure Lipi Implementation — Zero External / C Dependencies
@! Features: DNS Wire Format, Label Compression/Decompression, Record Parser
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@enum DnsRecordType
  A
  NS
  CNAME
  SOA
  PTR
  MX
  TXT
  AAAA
@end

@struct DnsHeader
  id: i64
  flags: i64
  qd_count: i64
  an_count: i64
  ns_count: i64
  ar_count: i64
@end

@struct DnsQuestion
  name: string
  qtype: i64
  qclass: i64
@end

@struct DnsResourceRecord
  name: string
  rtype: i64
  rclass: i64
  ttl: i64
  rd_length: i64
  rdata: array
  rdata_text: string
@end

@struct DnsPacket
  header: DnsHeader
  questions: array
  answers: array
  authorities: array
  additionals: array
@end

@! ----------------------------------------------------------------------------
@! 1. Label Compression & Encoding (RFC 1035 Section 4.1.4)
@! ----------------------------------------------------------------------------

@fn dns_compress_label(domain: string) -> array
  bytes = []
  parts = str_split(domain, ".")
  i = 0
  num_parts = parts.len()
  @while i < num_parts
    p = parts[i]
    p_len = str_len(p)
    @if p_len > 0
      bytes = bytes.push(p_len & 255)
      j = 0
      @while j < p_len
        bytes = bytes.push(str_char_at(p, j) & 255)
        j = j + 1
      @end
    @end
    i = i + 1
  @end
  bytes = bytes.push(0) @! Zero terminator
  return bytes
@end

@fn dns_decompress_label(data: array, offset: i64) -> string
  domain = ""
  curr = offset
  num_items = data.len()
  first = 1

  @while curr < num_items
    len_byte = data[curr] & 255
    @if len_byte == 0
      curr = curr + 1
      break
    @end

    @! Pointer indicator (0xC0 = 192)
    p_ind = len_byte & 192
    @if p_ind == 192
      @if curr + 1 < num_items
        m_len = len_byte & 63
        b_off = m_len * 256
        b1 = data[curr + 1] & 255
        ptr_offset = b_off | b1
        sub = dns_decompress_label(data, ptr_offset)
        @if first == 0
          domain = string_concat(domain, string_concat(".", sub))
        @else
          domain = sub
        @end
      @end
      break
    @else
      @if first == 0
        domain = string_concat(domain, ".")
      @end
      first = 0
      k = 0
      curr = curr + 1
      @while k < len_byte && curr < num_items
        domain = string_concat(domain, str_from_char_code(data[curr] & 255))
        curr = curr + 1
        k = k + 1
      @end
    @end
  @end

  return domain
@end

@! ----------------------------------------------------------------------------
@! 2. DNS Query Construction
@! ----------------------------------------------------------------------------

@fn dns_build_query(tx_id: i64, domain: string, qtype: i64) -> array
  packet = []

  @! Header: ID (2), Flags: 0x0100 (Standard Query, Recursion Desired), QDCOUNT=1, ANCOUNT=0, NSCOUNT=0, ARCOUNT=0
  packet = packet.push((tx_id / 256) & 255).push(tx_id & 255)
  packet = packet.push(1)
  packet = packet.push(0) @! Flags = 0x0100
  packet = packet.push(0)
  packet = packet.push(1) @! QDCOUNT = 1
  packet = packet.push(0)
  packet = packet.push(0) @! ANCOUNT = 0
  packet = packet.push(0)
  packet = packet.push(0) @! NSCOUNT = 0
  packet = packet.push(0)
  packet = packet.push(0) @! ARCOUNT = 0

  @! Question Name
  q_name_bytes = dns_compress_label(domain)
  i = 0
  num_items = q_name_bytes.len()
  @while i < num_items
    packet = packet.push(q_name_bytes[i])
    i = i + 1
  @end

  @! QTYPE (2 bytes)
  packet = packet.push((qtype / 256) & 255).push(qtype & 255)

  @! QCLASS = IN (1) (2 bytes)
  packet = packet.push(0)
  packet = packet.push(1)

  return packet
@end

@struct DnsWireCursor
  data: array
  offset: i64
@end

@fn dns_cursor_read_u8(c: DnsWireCursor) -> i64
  @if c.offset >= c.data.len()
    return 0
  @end
  val = c.data[c.offset] & 255
  c.offset = c.offset + 1
  return val
@end

@fn dns_cursor_read_u16(c: DnsWireCursor) -> i64
  b0 = dns_cursor_read_u8(c)
  b1 = dns_cursor_read_u8(c)
  v0 = b0 & 255
  t0 = v0 * 256
  v1 = b1 & 255
  res = t0 | v1
  return res & 65535
@end

@fn dns_cursor_read_u32(c: DnsWireCursor) -> i64
  b0 = dns_cursor_read_u8(c)
  b1 = dns_cursor_read_u8(c)
  b2 = dns_cursor_read_u8(c)
  b3 = dns_cursor_read_u8(c)
  v0 = b0 & 255
  w0 = v0 * 16777216
  v1 = b1 & 255
  w1 = v1 * 65536
  v2 = b2 & 255
  w2 = v2 * 256
  w3 = b3 & 255
  r01 = w0 | w1
  r23 = w2 | w3
  res = r01 | r23
  return res & 4294967295
@end

@fn dns_cursor_read_name(c: DnsWireCursor) -> string
  data = c.data
  dlen = data.len()
  domain = ""
  curr = c.offset
  first = 1
  jumped = 0
  max_jumps = 50
  jumps = 0

  @while curr < dlen && jumps < max_jumps
    len_byte = data[curr] & 255
    @if len_byte == 0
      @if jumped == 0
        c.offset = curr + 1
      @end
      break
    @end

    p_ind = len_byte & 192
    @if p_ind == 192
      @if curr + 1 >= dlen
        break
      @end
      m_len = len_byte & 63
        b_off = m_len * 256
        b1 = data[curr + 1] & 255
        ptr_offset = b_off | b1
      @if jumped == 0
        c.offset = curr + 2
        jumped = 1
      @end
      curr = ptr_offset
      jumps = jumps + 1
    @else
      @if first == 0
        domain = string_concat(domain, ".")
      @end
      first = 0
      curr = curr + 1
      k = 0
      @while k < len_byte && curr < dlen
        domain = string_concat(domain, str_from_char_code(data[curr] & 255))
        curr = curr + 1
        k = k + 1
      @end
      @if jumped == 0
        c.offset = curr
      @end
    @end
  @end

  return domain
@end

@fn dns_format_ipv4(rdata: array) -> string
  @if rdata.len() < 4
    return ""
  @end
  s0 = int_to_str(rdata[0] & 255)
  s1 = int_to_str(rdata[1] & 255)
  s2 = int_to_str(rdata[2] & 255)
  s3 = int_to_str(rdata[3] & 255)
  return string_concat(s0, string_concat(".", string_concat(s1, string_concat(".", string_concat(s2, string_concat(".", s3))))))
@end

@fn dns_nibble_to_hex(v: i64) -> string
  v = v & 15
  @if v < 10
    return str_from_char_code(48 + v)
  @end
  return str_from_char_code(97 + (v - 10))
@end

@fn dns_u16_to_hex(val: i64) -> string
  @if val == 0
    return "0"
  @end
  res = ""
  started = 0
  shift = 12
  @while shift >= 0
    p = maya_pow2(shift)
    d = val / p
    nibble = d & 15
    @if nibble > 0 || started == 1 || shift == 0
      res = string_concat(res, dns_nibble_to_hex(nibble))
      started = 1
    @end
    shift = shift - 4
  @end
  return res
@end

@fn dns_format_ipv6(rdata: array) -> string
  @if rdata.len() < 16
    return ""
  @end
  res = ""
  i = 0
  @while i < 16
    b0 = rdata[i] & 255
    t0 = b0 * 256
    b1 = rdata[i + 1] & 255
    chunk = t0 | b1
    chunk_hex = dns_u16_to_hex(chunk)
    @if i == 0
      res = chunk_hex
    @else
      res = string_concat(res, string_concat(":", chunk_hex))
    @end
    i = i + 2
  @end
  return res
@end

@fn dns_format_txt(rdata: array) -> string
  res = ""
  i = 0
  rlen = rdata.len()
  @while i < rlen
    txt_len = rdata[i] & 255
    i = i + 1
    j = 0
    @while j < txt_len && i < rlen
      res = string_concat(res, str_from_char_code(rdata[i] & 255))
      i = i + 1
      j = j + 1
    @end
  @end
  return res
@end

@fn dns_parse_resource_record(c: DnsWireCursor) -> DnsResourceRecord
  name = dns_cursor_read_name(c)
  rtype = dns_cursor_read_u16(c)
  rclass = dns_cursor_read_u16(c)
  ttl = dns_cursor_read_u32(c)
  rd_len = dns_cursor_read_u16(c)

  rdata = []
  rdata_start = c.offset
  i = 0
  @while i < rd_len && c.offset < c.data.len()
    rdata = rdata.push(dns_cursor_read_u8(c))
    i = i + 1
  @end

  rdata_text = ""
  @if rtype == 1 @! Type 1 (A)
    rdata_text = dns_format_ipv4(rdata)
  @elif rtype == 28 @! Type 28 (AAAA)
    rdata_text = dns_format_ipv6(rdata)
  @elif rtype == 5 || rtype == 2 || rtype == 12 @! CNAME (5), NS (2), PTR (12)
    temp_cursor = { data: c.data, offset: rdata_start }
    rdata_text = dns_cursor_read_name(temp_cursor)
  @elif rtype == 15 @! MX (15)
    @if rdata.len() >= 2
      b0 = rdata[0] & 255
      t0 = b0 * 256
      b1 = rdata[1] & 255
      pref = t0 | b1
      temp_cursor = { data: c.data, offset: rdata_start + 2 }
      ex = dns_cursor_read_name(temp_cursor)
      rdata_text = string_concat(int_to_str(pref), string_concat(" ", ex))
    @end
  @elif rtype == 16 @! TXT (16)
    rdata_text = dns_format_txt(rdata)
  @elif rtype == 6 @! SOA (6)
    temp_cursor = { data: c.data, offset: rdata_start }
    mname = dns_cursor_read_name(temp_cursor)
    rname = dns_cursor_read_name(temp_cursor)
    serial = dns_cursor_read_u32(temp_cursor)
    refresh = dns_cursor_read_u32(temp_cursor)
    retry = dns_cursor_read_u32(temp_cursor)
    expire = dns_cursor_read_u32(temp_cursor)
    minimum = dns_cursor_read_u32(temp_cursor)
    rdata_text = string_concat(mname, string_concat(" ", string_concat(rname, string_concat(" ", string_concat(int_to_str(serial), string_concat(" ", string_concat(int_to_str(refresh), string_concat(" ", string_concat(int_to_str(retry), string_concat(" ", string_concat(int_to_str(expire), string_concat(" ", int_to_str(minimum)))))))))))))
  @else
    rdata_text = ""
  @end

  return {
    name: name,
    rtype: rtype,
    rclass: rclass,
    ttl: ttl,
    rd_length: rd_len,
    rdata: rdata,
    rdata_text: rdata_text
  }
@end

@! ----------------------------------------------------------------------------
@! 3. DNS Response Parsing
@! ----------------------------------------------------------------------------

@fn dns_parse_response(data: array) -> DnsPacket
  @if data.len() < 12
    return {
      header: { id: 0, flags: 0, qd_count: 0, an_count: 0, ns_count: 0, ar_count: 0 },
      questions: [],
      answers: [],
      authorities: [],
      additionals: []
    }
  @end

  c = { data: data, offset: 0 }

  id = dns_cursor_read_u16(c)
  flags = dns_cursor_read_u16(c)
  qd_count = dns_cursor_read_u16(c)
  an_count = dns_cursor_read_u16(c)
  ns_count = dns_cursor_read_u16(c)
  ar_count = dns_cursor_read_u16(c)

  header = {
    id: id,
    flags: flags,
    qd_count: qd_count,
    an_count: an_count,
    ns_count: ns_count,
    ar_count: ar_count
  }

  questions = []
  q_idx = 0
  @while q_idx < qd_count && c.offset < c.data.len()
    qname = dns_cursor_read_name(c)
    qtype = dns_cursor_read_u16(c)
    qclass = dns_cursor_read_u16(c)
    questions = questions.push({
      name: qname,
      qtype: qtype,
      qclass: qclass
    })
    q_idx = q_idx + 1
  @end

  answers = []
  an_idx = 0
  @while an_idx < an_count && c.offset < c.data.len()
    rr = dns_parse_resource_record(c)
    answers = answers.push(rr)
    an_idx = an_idx + 1
  @end

  authorities = []
  ns_idx = 0
  @while ns_idx < ns_count && c.offset < c.data.len()
    rr = dns_parse_resource_record(c)
    authorities = authorities.push(rr)
    ns_idx = ns_idx + 1
  @end

  additionals = []
  ar_idx = 0
  @while ar_idx < ar_count && c.offset < c.data.len()
    rr = dns_parse_resource_record(c)
    additionals = additionals.push(rr)
    ar_idx = ar_idx + 1
  @end

  return {
    header: header,
    questions: questions,
    answers: answers,
    authorities: authorities,
    additionals: additionals
  }
@end

@fn dns_query_new(domain, tx_id)
  @! Alias for dns_build_query — backward compatibility
  return dns_build_query(tx_id, domain, 1)
@end
