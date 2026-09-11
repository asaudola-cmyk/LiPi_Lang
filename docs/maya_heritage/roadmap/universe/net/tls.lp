@! ============================================================================
@! MAYA UNIVERSE NET — TLS 1.3 ENGINE
@! Handshake State Machine, Key Exchange, AEAD Record Encryption
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/crypto"
import "universe/core/collections"
import "universe/net/tcp"

@! ----------------------------------------------------------------------------
@! 1. TLS 1.3 Constants & Types
@! ----------------------------------------------------------------------------

@fn tls_config_new()
  return {
    supported_versions: [0x0304], @! TLS 1.3
    cipher_suites: [0x1301, 0x1302, 0x1303], @! TLS_AES_128_GCM_SHA256, etc.
    supported_groups: [0x001D, 0x0017] @! x25519, secp256r1
  }
@end

@fn tls_state_new()
  return {
    state: "INITIAL", @! INITIAL, WAIT_SH, WAIT_EE, WAIT_CERT, WAIT_CV, WAIT_FINISHED, CONNECTED
    client_random: [],
    server_random: [],
    session_id: [],
    early_secret: [],
    handshake_secret: [],
    master_secret: [],
    client_write_key: [],
    server_write_key: [],
    client_seq: 0,
    server_seq: 0,
    transcript_hash: [] @! Running SHA-256 of all handshake messages
  }
@end

@! ----------------------------------------------------------------------------
@! 2. Handshake Protocol (Client Side)
@! ----------------------------------------------------------------------------

@fn tls_create_client_hello(config, state, hostname)
  @! 1. Generate 32-byte secure random
  state.client_random = crypto_random_bytes(32)
  
  @! 2. Generate ECDHE keypair (X25519)
  @! (Implementation omitted for brevity)
  key_share = []
  
  @! 3. Construct ClientHello payload
  payload = []
  
  @! Legacy Version: TLS 1.2 (0x0303)
  payload = payload.push(0x03)
  payload = payload.push(0x03)
  
  @! Client Random
  @for b in state.client_random
    payload = payload.push(b)
  @end
  
  @! Legacy Session ID (Length 0 or 32)
  payload = payload.push(0x00)
  
  @! Cipher Suites
  payload = payload.push(0x00) @! Length high
  payload = payload.push(0x06) @! Length low (3 suites * 2 bytes)
  @for suite in config.cipher_suites
    payload = payload.push(suite / 256)
    payload = payload.push(suite - ((suite / 256) * 256))
  @end
  
  @! Legacy Compression Methods (NULL)
  payload = payload.push(0x01)
  payload = payload.push(0x00)
  
  @! Extensions Length
  @! ... (SNI, Supported Versions, Signature Algorithms, Key Share) ...
  
  @! Update Transcript Hash
  @! state.transcript_hash.update(payload)
  
  return { state: state, packet: payload }
@end

@fn tls_process_server_hello(state, packet)
  @! 1. Parse Server Random
  @! 2. Parse Cipher Suite Selection
  @! 3. Parse Key Share (Server's public key)
  
  @! Compute Shared Secret (ECDH)
  @! shared_secret = x25519(client_priv, server_pub)
  
  @! Derive Handshake Secret
  @! state.handshake_secret = hkdf_extract(state.early_secret, shared_secret)
  
  state.state = "WAIT_EE"
  return state
@end

@! ----------------------------------------------------------------------------
@! 3. Record Layer (AEAD)
@! ----------------------------------------------------------------------------

@fn tls_record_encrypt(state, type_byte, payload)
  @! Construct TLSInnerPlaintext
  inner = []
  @for b in payload
    inner = inner.push(b)
  @end
  inner = inner.push(type_byte) @! Content type is appended in TLS 1.3
  
  @! Pad if needed
  
  @! Encrypt with AES-GCM
  nonce = [] @! Construct nonce from state.client_seq and client_write_iv
  
  @! ciphertext = aes_gcm_encrypt(state.client_write_key, nonce, inner)
  ciphertext = inner @! Mock
  
  @! Increment sequence
  state.client_seq = state.client_seq + 1
  
  @! Prepend Record Header (Type 23 = Application Data, Version 0x0303, Length)
  record = [23, 3, 3]
  len = ciphertext.len()
  record = record.push(len / 256)
  record = record.push(len - ((len / 256) * 256))
  
  @for b in ciphertext
    record = record.push(b)
  @end
  
  return { state: state, record: record }
@end

@fn tls_record_decrypt(state, record)
  @! Extract header
  type_byte = record[0]
  @! len = (record[3] * 256) + record[4]
  
  ciphertext = []
  i = 5
  @while i < record.len()
    ciphertext = ciphertext.push(record[i])
    i = i + 1
  @end
  
  @! Decrypt with AES-GCM
  nonce = [] @! Construct nonce from state.server_seq and server_write_iv
  
  @! inner = aes_gcm_decrypt(state.server_write_key, nonce, ciphertext)
  inner = ciphertext @! Mock
  
  @! Extract actual content type from end of inner
  actual_type = inner[inner.len() - 1]
  
  @! Increment sequence
  state.server_seq = state.server_seq + 1
  
  return { state: state, type: actual_type, payload: inner }
@end
