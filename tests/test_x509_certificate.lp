// ==============================================================================
// 👑 LIPI SOVEREIGN CRYPTOGRAPHY: tests/test_x509_certificate.lp
// ⚡ 100% Pure Lipi First 1.0.0 | Zero Libc | ITU-T X.690 ASN.1 DER & X.509 PKI Test
// ==============================================================================

import "universe/crypto/x509"

@fn main()
    println("==================================================================")
    println("👑 Testing Lipi Sovereign ASN.1 DER & X.509 Certificate Engine")
    println("==================================================================")

    // ── Test 1: Primitive ASN.1 TLV Decoding (Short & Long Form Lengths) ──────
    println("[1/4] Testing Primitive ASN.1 DER TLV Parsing...")
    // INTEGER tag (0x02), length 3, value [0x05, 0x10, 0x20]
    sample_tlv = [2, 3, 5, 16, 32]
    tlv = x509_read_tlv(sample_tlv, 0)

    if tlv.is_valid != 1 || tlv.tag != 2 || tlv.length != 3
        println("❌ Primitive TLV parsing failed!")
        return 1
    end
    if tlv.val_start != 2 || tlv.next_offset != 5
        println("❌ TLV offset calculations failed!")
        return 1
    end
    println("  ✔ Primitive TLV tag=2, length=3, val_offset=2, next_offset=5 verified")

    // ── Test 2: Long-Form DER Length Parsing ─────────────────────────────────
    println("[2/4] Testing Long-Form DER Multi-Byte Length Decoding...")
    // OCTET STRING (0x04), long length 2 bytes (0x82, 0x01, 0x00 = 256 bytes)
    long_hdr = [4, 130, 1, 0]
    // append 256 dummy bytes
    i = 0
    while i < 256
        long_hdr = long_hdr.push(99)
        i = i + 1
    end
    long_tlv = x509_read_tlv(long_hdr, 0)
    if long_tlv.length != 256
        println("❌ Long-form length mismatch: expected 256, got " + long_tlv.length)
        return 1
    end
    println("  ✔ Long-form DER length 256 bytes decoded accurately")

    // ── Test 3: Synthetic X.509 v3 Certificate Construction ──────────────────
    println("[3/4] Testing Synthetic X.509 v3 DER Certificate Generation...")
    cert_bytes = x509_build_synthetic_cert("node.sovereign.lipi", "")
    if cert_bytes.len() < 30
        println("❌ Certificate construction produced invalid size: " + cert_bytes.len())
        return 1
    end
    println("  ✔ Synthetic X.509 DER certificate generated (" + cert_bytes.len() + " bytes)")

    // ── Test 4: End-to-End X.509 Structure Parsing & Public Key Extraction ────
    println("[4/4] Testing X.509 Certificate Parsing & Field Extraction...")
    info = x509_parse_certificate(cert_bytes)

    if info.cert_valid != 1
        println("❌ Failed to parse X.509 certificate!")
        return 1
    end
    if info.version != 3
        println("❌ Expected X.509 version 3, got " + info.version)
        return 1
    end
    if info.serial_hex != "01020304"
        println("❌ Serial number mismatch: expected '01020304', got " + info.serial_hex)
        return 1
    end
    if str_len(info.pubkey_hex) != 64
        println("❌ Public key length mismatch: expected 64 hex chars (32 bytes), got " + str_len(info.pubkey_hex))
        return 1
    end
    println("  ✔ X.509 Version: v" + info.version)
    println("  ✔ Serial Number: 0x" + info.serial_hex)
    println("  ✔ Signature OID: " + info.sig_algo_oid)
    println("  ✔ Extracted Public Key: 0x" + info.pubkey_hex)
    println("  ✔ TBSCertificate SHA-256 Digest: " + info.tbs_hash_hex)

    println("==================================================================")
    println("PASS: Lipi Sovereign ASN.1 DER & X.509 PKI Verified 100%!")
    println("==================================================================")
    return 0
@end
