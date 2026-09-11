@! ============================================================================
@! MAYA UNIVERSE NET - PURE TLS 1.3 RECORD LAYER (universe/net/tls/record.maya)
@! Standard: Sovereign Implementation (RFC 8446 Section 5.2)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/net/tls/tls13"

@struct RecordLayer
  seq_num: i64
  key: string
  iv: string
@end

@fn record_layer_new()
  return { seq_num: 0, key: "maya_tls13_key_0123456789abcdef", iv: "maya_tls_iv1" }
@end

@fn record_layer_with_keys(key: string, iv: string) -> RecordLayer
  return { seq_num: 0, key: key, iv: iv }
@end

@fn record_layer_encrypt(layer, pt, ct_type)
  @! 1. Derive 12-byte per-record nonce: iv XOR seq_num
  iv_bytes = tls_string_to_bytes(layer.iv)
  @while iv_bytes.len() < 12
    iv_bytes = iv_bytes.push(0)
  @end
  nonce = []
  i = 0
  @while i < 12
    nonce = nonce.push(iv_bytes[i] & 255)
    i = i + 1
  @end
  seq = layer.seq_num
  val11 = nonce[11] ^ (seq & 255)
  nonce[11] = val11
  val10 = nonce[10] ^ ((seq / 256) & 255)
  nonce[10] = val10
  val9 = nonce[9] ^ ((seq / 65536) & 255)
  nonce[9] = val9
  val8 = nonce[8] ^ ((seq / 16777216) & 255)
  nonce[8] = val8

  @! 2. Inner Plaintext: pt + [ct_type] (RFC 8446 §5.2)
  ct_char = str_from_char_code(ct_type & 255)
  inner = str_concat(pt, ct_char)

  @! 3. Outer header: [0x17 (application_data), 0x03, 0x03 (TLS 1.2 legacy version), len_hi, len_lo]
  enc_len = str_len(inner) + 16
  hdr_bytes = [
    0x17, 0x03, 0x03,
    (enc_len / 256) & 255, enc_len & 255
  ]
  hdr_hex = tls_bytes_to_hex(hdr_bytes)
  nonce_str = tls_bytes_to_string(nonce)

  @! 4. Encrypt with AES-GCM using outer header as AAD
  enc_payload = tls_aes_gcm_encrypt(layer.key, nonce_str, inner, hdr_hex)

  layer.seq_num = layer.seq_num + 1

  @! 5. Return framed record: header (10 hex chars) + enc_payload (hex)
  return str_concat(hdr_hex, enc_payload)
@end

@fn record_layer_decrypt(layer, framed_record)
  total_len = str_len(framed_record)
  @if total_len < 10 + 32 + 2
    return ""
  @end

  @! Parse header
  hdr_hex = str_substr(framed_record, 0, 10)
  enc_payload = str_substr(framed_record, 10, total_len)

  @! Derive nonce
  iv_bytes = tls_string_to_bytes(layer.iv)
  @while iv_bytes.len() < 12
    iv_bytes = iv_bytes.push(0)
  @end
  nonce = []
  i = 0
  @while i < 12
    nonce = nonce.push(iv_bytes[i] & 255)
    i = i + 1
  @end
  seq = layer.seq_num
  val11 = nonce[11] ^ (seq & 255)
  nonce[11] = val11
  val10 = nonce[10] ^ ((seq / 256) & 255)
  nonce[10] = val10
  val9 = nonce[9] ^ ((seq / 65536) & 255)
  nonce[9] = val9
  val8 = nonce[8] ^ ((seq / 16777216) & 255)
  nonce[8] = val8
  nonce_str = tls_bytes_to_string(nonce)

  inner = tls_aes_gcm_decrypt(layer.key, nonce_str, enc_payload, hdr_hex)
  @if str_len(inner) < 1
    return ""
  @end

  layer.seq_num = layer.seq_num + 1

  @! Extract pt (inner[0..num_items-2])
  pt = str_substr(inner, 0, str_len(inner) - 1)
  return pt
@end
