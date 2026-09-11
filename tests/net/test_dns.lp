@! Maya DNS Resolver Unit Tests
import "universe/core/string"
import "universe/core/collections"
import "universe/net/dns"

@fn assert_eq(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg + " -> Expected: '" + expected.to_str() + "', Got: '" + actual.to_str() + "'")
    return 0
  @end
@end

@fn assert_eq_str(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg + " -> Expected: '" + expected + "', Got: '" + actual + "'")
    return 0
  @end
@end

@fn main()
  println("==================================================")
  println("   MAYA DNS RESOLVER UNIT TEST SUITE              ")
  println("==================================================")
  
  passed = 0
  total = 0

  @! 1. Query Construction
  total = total + 1
  q_bytes = dns_build_query(0x1234, "maya.lang", 1)
  passed = passed + assert_eq(q_bytes[0], 0x12, "Query TX ID byte 0")
  total = total + 1
  passed = passed + assert_eq(q_bytes[1], 0x34, "Query TX ID byte 1")
  total = total + 1
  passed = passed + assert_eq(q_bytes[2], 1, "Query flags RD bit set")
  total = total + 1
  passed = passed + assert_eq(q_bytes[4] * 256 + q_bytes[5], 1, "Query QDCOUNT is 1")

  @! 2. Label Compression & Decompression
  total = total + 1
  comp = dns_compress_label("code.maya.lang")
  decomp = dns_decompress_label(comp, 0)
  passed = passed + assert_eq_str(decomp, "code.maya.lang", "Label compress & decompress roundtrip")

  @! 3. Response Wire Packet Parsing with Real Resource Records
  raw_resp = [
    @! Header (12 bytes)
    0x12, 0x34, @! ID
    0x81, 0x80, @! Flags (Response, Standard, NoError)
    0x00, 0x01, @! QDCOUNT = 1
    0x00, 0x04, @! ANCOUNT = 4 (A, CNAME, AAAA, TXT)
    0x00, 0x01, @! NSCOUNT = 1 (NS)
    0x00, 0x01, @! ARCOUNT = 1 (Additional A)

    @! Question 0: "maya.lang" Type A (1), Class IN (1) (offsets 12..26)
    4, 109, 97, 121, 97, 4, 108, 97, 110, 103, 0,
    0x00, 0x01, @! QTYPE = 1 (A)
    0x00, 0x01, @! QCLASS = 1 (IN)

    @! Answer 0: Name = pointer to offset 12 ("maya.lang"), Type A (1), TTL 300, 93.184.216.34
    0xc0, 0x0c,
    0x00, 0x01, @! Type A
    0x00, 0x01, @! Class IN
    0x00, 0x00, 0x01, 0x2c, @! TTL = 300
    0x00, 0x04, @! RDLength = 4
    93, 184, 216, 34,

    @! Answer 1: Name = "cname" + pointer to 12 ("cname.maya.lang"), Type CNAME (5), TTL 600, target pointer 12 ("maya.lang")
    5, 99, 110, 97, 109, 101, 0xc0, 0x0c,
    0x00, 0x05, @! Type CNAME
    0x00, 0x01, @! Class IN
    0x00, 0x00, 0x02, 0x58, @! TTL = 600
    0x00, 0x02, @! RDLength = 2
    0xc0, 0x0c, @! target = "maya.lang"

    @! Answer 2: Name = pointer 12 ("maya.lang"), Type AAAA (28), TTL 300
    0xc0, 0x0c,
    0x00, 0x1c, @! Type AAAA = 28
    0x00, 0x01, @! Class IN
    0x00, 0x00, 0x01, 0x2c, @! TTL = 300
    0x00, 0x10, @! RDLength = 16
    0x26, 0x06, 0x28, 0x00, 0x02, 0x20, 0x00, 0x01, 0x02, 0x48, 0x18, 0x93, 0x25, 0xc8, 0x19, 0x46,

    @! Answer 3: Name = pointer 12 ("maya.lang"), Type TXT (16), TTL 300, "v=spf1 ~all"
    0xc0, 0x0c,
    0x00, 0x10, @! Type TXT = 16
    0x00, 0x01, @! Class IN
    0x00, 0x00, 0x01, 0x2c, @! TTL = 300
    0x00, 0x0c, @! RDLength = 12
    11, 118, 61, 115, 112, 102, 49, 32, 126, 97, 108, 108,

    @! Authority 0: Name = pointer 12 ("maya.lang"), Type NS (2), TTL 86400, target pointer 12 ("maya.lang")
    0xc0, 0x0c,
    0x00, 0x02, @! Type NS = 2
    0x00, 0x01, @! Class IN
    0x00, 0x01, 0x51, 0x80, @! TTL = 86400
    0x00, 0x02, @! RDLength = 2
    0xc0, 0x0c,

    @! Additional 0: Name = pointer 12 ("maya.lang"), Type A (1), TTL 300, 1.1.1.1
    0xc0, 0x0c,
    0x00, 0x01, @! Type A = 1
    0x00, 0x01, @! Class IN
    0x00, 0x00, 0x01, 0x2c, @! TTL = 300
    0x00, 0x04, @! RDLength = 4
    1, 1, 1, 1
  ]

  pkt = dns_parse_response(raw_resp)

  @! Verify Header
  total = total + 1
  passed = passed + assert_eq(pkt.header.id, 0x1234, "Parsed header ID")
  total = total + 1
  passed = passed + assert_eq(pkt.header.qd_count, 1, "Parsed QDCOUNT == 1")
  total = total + 1
  passed = passed + assert_eq(pkt.header.an_count, 4, "Parsed ANCOUNT == 4")
  total = total + 1
  passed = passed + assert_eq(pkt.header.ns_count, 1, "Parsed NSCOUNT == 1")
  total = total + 1
  passed = passed + assert_eq(pkt.header.ar_count, 1, "Parsed ARCOUNT == 1")

  @! Verify Questions
  total = total + 1
  passed = passed + assert_eq(pkt.questions.len(), 1, "Questions array length == 1")
  q0 = pkt.questions[0]
  total = total + 1
  passed = passed + assert_eq_str(q0.name, "maya.lang", "Question name is 'maya.lang'")
  total = total + 1
  passed = passed + assert_eq(q0.qtype, 1, "Question qtype is 1 (A)")

  @! Verify Answers
  total = total + 1
  passed = passed + assert_eq(pkt.answers.len(), 4, "Answers array length == 4")

  a0 = pkt.answers[0]
  total = total + 1
  passed = passed + assert_eq_str(a0.name, "maya.lang", "Answer 0 name is 'maya.lang'")
  total = total + 1
  passed = passed + assert_eq(a0.rtype, 1, "Answer 0 type is 1 (A)")
  total = total + 1
  passed = passed + assert_eq(a0.ttl, 300, "Answer 0 TTL is 300")
  total = total + 1
  passed = passed + assert_eq_str(a0.rdata_text, "93.184.216.34", "Answer 0 IPv4 is '93.184.216.34'")

  a1 = pkt.answers[1]
  total = total + 1
  passed = passed + assert_eq_str(a1.name, "cname.maya.lang", "Answer 1 name is 'cname.maya.lang'")
  total = total + 1
  passed = passed + assert_eq(a1.rtype, 5, "Answer 1 type is 5 (CNAME)")
  total = total + 1
  passed = passed + assert_eq_str(a1.rdata_text, "maya.lang", "Answer 1 CNAME target is 'maya.lang'")

  a2 = pkt.answers[2]
  total = total + 1
  passed = passed + assert_eq(a2.rtype, 28, "Answer 2 type is 28 (AAAA)")
  total = total + 1
  passed = passed + assert_eq_str(a2.rdata_text, "2606:2800:220:1:248:1893:25c8:1946", "Answer 2 IPv6 is '2606:2800:220:1:248:1893:25c8:1946'")

  a3 = pkt.answers[3]
  total = total + 1
  passed = passed + assert_eq(a3.rtype, 16, "Answer 3 type is 16 (TXT)")
  total = total + 1
  passed = passed + assert_eq_str(a3.rdata_text, "v=spf1 ~all", "Answer 3 TXT is 'v=spf1 ~all'")

  @! Verify Authority & Additional
  total = total + 1
  passed = passed + assert_eq(pkt.authorities.len(), 1, "Authorities array length == 1")
  ns0 = pkt.authorities[0]
  total = total + 1
  passed = passed + assert_eq(ns0.rtype, 2, "Authority 0 type is 2 (NS)")
  total = total + 1
  passed = passed + assert_eq_str(ns0.rdata_text, "maya.lang", "Authority 0 NS target is 'maya.lang'")

  total = total + 1
  passed = passed + assert_eq(pkt.additionals.len(), 1, "Additionals array length == 1")
  ar0 = pkt.additionals[0]
  total = total + 1
  passed = passed + assert_eq_str(ar0.rdata_text, "1.1.1.1", "Additional 0 IPv4 is '1.1.1.1'")

  println("--------------------------------------------------")
  println("DNS Resolver Test Summary: " + passed.to_str() + " / " + total.to_str() + " passed")
  @if passed == total
    println("🎉 ALL DNS RESOLVER TESTS PASSED!")
    return 0
  @else
    println("❌ SOME DNS RESOLVER TESTS FAILED")
    return 1
  @end
@end
