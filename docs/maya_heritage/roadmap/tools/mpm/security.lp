@! ============================================================================
@! MAYA PACKAGE MANAGER (MPM) — SECURITY & CRYPTOGRAPHIC VERIFICATION
@! Module: tools/mpm/security.maya
@! 100% Pure Maya Architecture — Zero External Dependencies
@! Features:
@! - FIPS 180-4 SHA-256 Integrity Hash Verification
@! - Ed25519 Edwards-Curve Digital Signature Verification & Signing
@! - Cryptographic Keypair Generation
@! - Deterministic Checksum Assertion for Package Supply Chain Safety
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/crypto"

@! ----------------------------------------------------------------------------
@! 1. BYTE & STRING UTILITIES
@! ----------------------------------------------------------------------------

@fn mpm_to_byte_array(data)
  @if data == 0 || data == none
    return []
  @end
  
  @! If data is already an array of integers (bytes)
  @if data.len() > 0 && char_to_ascii(data[0].to_str()[0]) == 0
    return data
  @end
  
  str_val = data.to_str()
  bytes = []
  i = 0
  len = str_val.len()
  @while i < len
    bytes = bytes.push(char_to_ascii(str_val[i]))
    i = i + 1
  @end
  return bytes
@end

@! ----------------------------------------------------------------------------
@! 2. FIPS SHA-256 INTEGRITY HASHING
@! ----------------------------------------------------------------------------

@fn mpm_calc_sha256(data)
  data_bytes = mpm_to_byte_array(data)
  hash_hex = sha256_hex(data_bytes)
  return hash_hex
@end

@fn mpm_verify_checksum(data, expected_checksum)
  exp = string_trim(expected_checksum)
  @if starts_with(exp, "sha256:")
    exp = string_slice(exp, 7, exp.len())
  @end
  
  actual_hash = mpm_calc_sha256(data)
  
  @if actual_hash == exp
    return 1
  @end
  
  return 0
@end

@! ----------------------------------------------------------------------------
@! 3. ED25519 DIGITAL SIGNATURES & KEY MANAGEMENT
@! ----------------------------------------------------------------------------

@fn mpm_generate_keypair(seed_bytes)
  s_bytes = mpm_to_byte_array(seed_bytes)
  kp = ed25519_keypair_from_seed(s_bytes)
  return kp
@end

@fn mpm_sign_package(secret_key, package_data)
  data_bytes = mpm_to_byte_array(package_data)
  sig = ed25519_sign(secret_key, data_bytes)
  return sig
@end

@fn mpm_verify_signature(public_key, package_data, signature)
  @if signature == "" || signature == 0 || signature == none
    return 0
  @end
  
  data_bytes = mpm_to_byte_array(package_data)
  valid = ed25519_verify(public_key, data_bytes, signature)
  @if valid == 1
    return 1
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 4. FULL PACKAGE INTEGRITY VERIFICATION (CHECKSUM + SIGNATURE)
@! ----------------------------------------------------------------------------

@fn mpm_verify_package_integrity(package_bytes, expected_sha256, publisher_pubkey, signature)
  @! 1. Verify FIPS 180-4 SHA-256 Checksum
  @if expected_sha256 != "" && expected_sha256 != none
    chk_ok = mpm_verify_checksum(package_bytes, expected_sha256)
    @if chk_ok != 1
      return {
        valid: 0,
        error: "SHA-256 Checksum mismatch",
        checksum_verified: 0,
        signature_verified: 0
      }
    @end
  @end
  
  @! 2. Verify Ed25519 Digital Signature (if provided)
  sig_ok = 1
  @if signature != "" && signature != 0 && signature != none
    sig_ok = mpm_verify_signature(publisher_pubkey, package_bytes, signature)
    @if sig_ok != 1
      return {
        valid: 0,
        error: "Ed25519 Signature verification failed",
        checksum_verified: 1,
        signature_verified: 0
      }
    @end
  @end
  
  return {
    valid: 1,
    error: "none",
    checksum_verified: 1,
    signature_verified: sig_ok
  }
@end
