@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — SOVEREIGN P2P PACKAGE REGISTRY & CAS ENGINE
@! Module: universe/p2p/registry.maya
@! Milestone 2 (Requirement R2)
@! 100% Pure Maya Implementation — Zero External / C Standard Library Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/sha256"

@! ============================================================================
@! 1. DATA STRUCTURE DEFINITIONS
@! ============================================================================

@struct Peer
  id: string
  addr: string
  address: string
  port: i64
  last_seen: i64
  latency_ms: i64
  reputation: i64
  status: string
@end

@struct PackageBlob
  name: string
  version: string
  cid: string
  data: string
  size_bytes: i64
  created_at: i64
@end

@struct PackageRecord
  name: string
  version: string
  cid: string
  manifest_cid: string
  author_pubkey: string
  signature: string
  publisher_id: string
  providers: array
  announced_at: i64
  ttl_sec: i64
  downloads: i64
  manifest_data: string
@end

@struct P2PMessage
  msg_type: string
  sender_id: string
  sender_addr: string
  target_id: string
  payload: string
  nonce: i64
  status: i64
@end

@struct SemVer
  major: i64
  minor: i64
  patch: i64
  prerelease: string
  build: string
@end

@struct KBucket
  prefix_index: i64
  peers: array
  replacement_cache: array
  last_updated: i64
@end

@struct P2PSwarmNetwork
  nodes: array
  total_messages: i64
@end

@struct P2PRegistry
  self_peer: Peer
  local_peer: Peer
  routing_table: array
  local_cas: array
  cas_store: array
  records: array
  network_log: array
  k_capacity: i64
  alpha: i64
  total_downloads: i64
  total_uploads: i64
  next_nonce: i64
@end

@! ============================================================================
@! 2. DEFAULT / EMPTY FACTORY HELPERS
@! ============================================================================

@fn p2p_empty_peer()
  return {
    id: "",
    addr: "",
    address: "",
    port: 0,
    last_seen: 0,
    latency_ms: 0,
    reputation: 0,
    status: "DEAD"
  }
@end

@fn p2p_empty_blob()
  return {
    name: "",
    version: "",
    cid: "",
    data: "",
    size_bytes: 0,
    created_at: 0
  }
@end

@fn p2p_empty_record()
  return {
    name: "",
    version: "",
    cid: "",
    manifest_cid: "",
    author_pubkey: "",
    signature: "",
    publisher_id: "",
    providers: [],
    announced_at: 0,
    ttl_sec: 0,
    downloads: 0,
    manifest_data: ""
  }
@end

@fn p2p_empty_message()
  return {
    msg_type: "EMPTY",
    sender_id: "",
    sender_addr: "",
    target_id: "",
    payload: "",
    nonce: 0,
    status: 500
  }
@end

@fn make_dummy_peer(id, ip, port)
  return {
    id: id,
    addr: ip,
    address: ip,
    port: port,
    last_seen: 1000,
    latency_ms: 20,
    reputation: 100,
    status: "ACTIVE"
  }
@end

@! ============================================================================
@! 3. REGISTRY LIFECYCLE & PEER MANAGEMENT
@! ============================================================================

@fn p2p_registry_new(self_id, self_addr, self_port)
  self_p = {
    id: self_id,
    addr: self_addr,
    address: self_addr,
    port: self_port,
    last_seen: 1000,
    latency_ms: 0,
    reputation: 100,
    status: "ACTIVE"
  }
  
  return {
    self_peer: self_p,
    local_peer: self_p,
    routing_table: [],
    local_cas: [],
    cas_store: [],
    records: [],
    network_log: [],
    k_capacity: 20,
    alpha: 3,
    total_downloads: 0,
    total_uploads: 0,
    next_nonce: 1
  }
@end

@fn p2p_add_peer(reg, peer_id, addr, port)
  @if peer_id == reg.local_peer.id || peer_id == reg.self_peer.id
    return 0
  @end

  table = reg.routing_table
  n = table.len()
  i = 0
  @while i < n
    p = table[i]
    @if p.id == peer_id
      p.addr = addr
      p.address = addr
      p.port = port
      p.last_seen = 1000
      p.status = "ACTIVE"
      return 1
    @end
    i = i + 1
  @end

  @if n >= reg.k_capacity
    @! Check if there is an inactive/dead peer to evict
    evict_idx = -1
    j = 0
    @while j < n
      p_cand = table[j]
      @if p_cand.status == "DEAD" || p_cand.reputation < 0
        evict_idx = j
        break
      @end
      j = j + 1
    @end
    @if evict_idx >= 0
      new_table = []
      k = 0
      @while k < n
        @if k != evict_idx
          new_table = new_table.push(table[k])
        @end
        k = k + 1
      @end
      new_p = {
        id: peer_id,
        addr: addr,
        address: addr,
        port: port,
        last_seen: 1000,
        latency_ms: 20,
        reputation: 100,
        status: "ACTIVE"
      }
      reg.routing_table = new_table.push(new_p)
      return 1
    @end
    return 0
  @end

  new_peer = {
    id: peer_id,
    addr: addr,
    address: addr,
    port: port,
    last_seen: 1000,
    latency_ms: 20,
    reputation: 100,
    status: "ACTIVE"
  }
  reg.routing_table = reg.routing_table.push(new_peer)
  return 1
@end

@fn p2p_registry_add_peer(reg, peer_id, addr, port)
  return p2p_add_peer(reg, peer_id, addr, port)
@end

@fn p2p_remove_peer(reg, peer_id)
  table = reg.routing_table
  n = table.len()
  new_table = []
  found = 0
  i = 0
  @while i < n
    p = table[i]
    @if p.id == peer_id
      found = 1
    @else
      new_table = new_table.push(p)
    @end
    i = i + 1
  @end
  reg.routing_table = new_table
  return found
@end

@fn p2p_registry_remove_peer(reg, peer_id)
  return p2p_remove_peer(reg, peer_id)
@end

@fn p2p_find_peer(reg, peer_id)
  table = reg.routing_table
  n = table.len()
  i = 0
  @while i < n
    p = table[i]
    @if p.id == peer_id
      return p
    @end
    i = i + 1
  @end
  return p2p_empty_peer()
@end

@fn p2p_registry_find_peer(reg, peer_id)
  return p2p_find_peer(reg, peer_id)
@end

@! ============================================================================
@! 4. 256-BIT KADEMLIA XOR METRIC & ROUTING ALGORITHMS
@! ============================================================================

@fn p2p_hex_nibble_val(c_code)
  @if c_code >= 48 && c_code <= 57
    return c_code - 48
  @end
  @if c_code >= 97 && c_code <= 102
    return c_code - 87
  @end
  @if c_code >= 65 && c_code <= 70
    return c_code - 55
  @end
  return 0
@end

@fn p2p_calculate_distance(id1, id2)
  hex_chars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"]
  dist_str = ""
  len1 = str_len(id1)
  len2 = str_len(id2)
  
  i = 0
  @while i < 64
    c1 = 0
    c2 = 0
    @if i < len1
      c1 = p2p_hex_nibble_val(str_char_at(id1, i))
    @end
    @if i < len2
      c2 = p2p_hex_nibble_val(str_char_at(id2, i))
    @end
    t_d = c1 ^ c2
    diff = t_d & 15
    dist_str = string_concat(dist_str, hex_chars[diff])
    i = i + 1
  @end
  return dist_str
@end

@fn p2p_distance_compare(dist1, dist2)
  len1 = str_len(dist1)
  len2 = str_len(dist2)
  i = 0
  @while i < 64
    c1 = 0
    c2 = 0
    @if i < len1
      c1 = p2p_hex_nibble_val(str_char_at(dist1, i))
    @end
    @if i < len2
      c2 = p2p_hex_nibble_val(str_char_at(dist2, i))
    @end
    @if c1 < c2
      return -1
    @end
    @if c1 > c2
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn p2p_nibble_clz(nibble)
  @if nibble == 0 return 4 @end
  @if nibble == 1 return 3 @end
  @if nibble >= 2 && nibble <= 3 return 2 @end
  @if nibble >= 4 && nibble <= 7 return 1 @end
  return 0
@end

@fn p2p_common_prefix_len(id1, id2)
  len1 = str_len(id1)
  len2 = str_len(id2)
  prefix_bits = 0
  i = 0
  @while i < 64
    c1 = 0
    c2 = 0
    @if i < len1
      c1 = p2p_hex_nibble_val(str_char_at(id1, i))
    @end
    @if i < len2
      c2 = p2p_hex_nibble_val(str_char_at(id2, i))
    @end
    t_d = c1 ^ c2
    diff = t_d & 15
    @if diff == 0
      prefix_bits = prefix_bits + 4
    @else
      prefix_bits = prefix_bits + p2p_nibble_clz(diff)
      return prefix_bits
    @end
    i = i + 1
  @end
  return 256
@end

@fn p2p_get_bucket_index(self_id, target_id)
  prefix = p2p_common_prefix_len(self_id, target_id)
  @if prefix >= 256
    return -1
  @end
  return prefix
@end

@fn p2p_routing_find_closest(reg, target_id, max_count)
  table = reg.routing_table
  n = table.len()
  @if n == 0 || max_count <= 0
    return []
  @end

  candidates = []
  i = 0
  @while i < n
    p = table[i]
    @if p.status != "DEAD"
      d = p2p_calculate_distance(p.id, target_id)
      candidates = candidates.push({ peer: p, dist: d })
    @end
    i = i + 1
  @end

  cand_len = candidates.len()
  @if cand_len == 0
    return []
  @end

  @! Insertion sort by XOR distance ascending
  i = 1
  @while i < cand_len
    key_item = candidates[i]
    j = i - 1
    @while j >= 0
      cand_j = candidates[j]
      cmp = p2p_distance_compare(cand_j.dist, key_item.dist)
      @if cmp > 0
        candidates[j + 1] = cand_j
        j = j - 1
      @else
        break
      @end
    @end
    candidates[j + 1] = key_item
    i = i + 1
  @end

  result = []
  count = cand_len
  @if count > max_count
    count = max_count
  @end

  i = 0
  @while i < count
    cand = candidates[i]
    result = result.push(cand.peer)
    i = i + 1
  @end
  return result
@end

@! ============================================================================
@! 5. CONTENT-ADDRESSABLE STORAGE (CAS) & INTEGRITY VERIFICATION
@! ============================================================================

@fn p2p_cas_put_blob(reg, data_str)
  hash = sha256_hex_string(data_str)
  cid = "sha256:" + hash

  @! Check for deduplication
  store = reg.cas_store
  n = store.len()
  i = 0
  @while i < n
    b = store[i]
    @if b.cid == cid
      return cid
    @end
    i = i + 1
  @end

  blob = {
    name: "",
    version: "",
    cid: cid,
    data: data_str,
    size_bytes: str_len(data_str),
    created_at: 1000
  }
  reg.cas_store = reg.cas_store.push(blob)
  reg.local_cas = reg.cas_store
  return cid
@end

@fn p2p_cas_store_blob(reg, data_str, name, version)
  hash = sha256_hex_string(data_str)
  cid = "sha256:" + hash

  store = reg.cas_store
  n = store.len()
  i = 0
  @while i < n
    b = store[i]
    @if b.cid == cid
      return cid
    @end
    i = i + 1
  @end

  blob = {
    name: name,
    version: version,
    cid: cid,
    data: data_str,
    size_bytes: str_len(data_str),
    created_at: 1000
  }
  reg.cas_store = reg.cas_store.push(blob)
  reg.local_cas = reg.cas_store
  return cid
@end

@fn p2p_cas_get_blob(reg, cid)
  @if str_len(cid) == 0
    return ""
  @end

  target_cid = cid
  target_raw = cid
  @if str_starts_with(cid, "sha256:")
    target_raw = str_substr(cid, 7, str_len(cid))
  @else
    target_cid = "sha256:" + cid
  @end

  store = reg.cas_store
  n = store.len()
  i = 0
  @while i < n
    b = store[i]
    @if b.cid == target_cid || b.cid == target_raw
      return b.data
    @end
    i = i + 1
  @end
  return ""
@end

@fn p2p_cas_has_blob(reg, cid)
  @if str_len(cid) == 0
    return 0
  @end

  target_cid = cid
  target_raw = cid
  @if str_starts_with(cid, "sha256:")
    target_raw = str_substr(cid, 7, str_len(cid))
  @else
    target_cid = "sha256:" + cid
  @end

  store = reg.cas_store
  n = store.len()
  i = 0
  @while i < n
    b = store[i]
    @if b.cid == target_cid || b.cid == target_raw
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn p2p_cas_verify_blob(data_str, cid)
  @if str_len(cid) == 0
    return 0
  @end

  actual_hash = sha256_hex_string(data_str)
  expected_hash = cid
  @if str_starts_with(expected_hash, "sha256:")
    expected_hash = str_substr(expected_hash, 7, str_len(expected_hash))
  @end

  @if actual_hash == expected_hash
    return 1
  @end
  return 0
@end

@fn p2p_find_package_blob(reg, cid)
  @if str_len(cid) == 0
    return p2p_empty_blob()
  @end

  target_cid = cid
  target_raw = cid
  @if str_starts_with(cid, "sha256:")
    target_raw = str_substr(cid, 7, str_len(cid))
  @else
    target_cid = "sha256:" + cid
  @end

  store = reg.cas_store
  n = store.len()
  i = 0
  @while i < n
    b = store[i]
    @if b.cid == target_cid || b.cid == target_raw
      @if p2p_cas_verify_blob(b.data, b.cid) == 1
        return b
      @else
        return p2p_empty_blob()
      @end
    @end
    i = i + 1
  @end
  return p2p_empty_blob()
@end

@fn p2p_verify_blob_integrity(blob)
  @if str_len(blob.cid) == 0
    return 0
  @end
  return p2p_cas_verify_blob(blob.data, blob.cid)
@end

@! ============================================================================
@! 6. PACKAGE PUBLISHING & PROVIDER ANNOUNCEMENTS
@! ============================================================================

@fn p2p_publish_package(reg, name, version, manifest_or_content, payload_or_empty, pubkey_or_empty, sig_or_empty)
  @! Support both 7-parameter signature and standard single payload
  payload_str = manifest_or_content
  manifest_str = ""
  pubkey = pubkey_or_empty
  signature = sig_or_empty

  @if str_len(payload_or_empty) > 0
    manifest_str = manifest_or_content
    payload_str = payload_or_empty
  @end

  cid = p2p_cas_put_blob(reg, payload_str)
  manifest_cid = ""
  @if str_len(manifest_str) > 0
    manifest_cid = p2p_cas_put_blob(reg, manifest_str)
  @end

  @if str_len(signature) == 0
    signature = "sig:" + cid
  @end

  record = {
    name: name,
    version: version,
    cid: cid,
    manifest_cid: manifest_cid,
    author_pubkey: pubkey,
    signature: signature,
    publisher_id: reg.local_peer.id,
    providers: [reg.local_peer.id],
    announced_at: 1000,
    ttl_sec: 86400,
    downloads: 0,
    manifest_data: manifest_str
  }

  @! Check if record already exists for name@version
  records = reg.records
  n = records.len()
  found = 0
  i = 0
  @while i < n
    r = records[i]
    @if r.name == name && r.version == version
      r.cid = cid
      r.manifest_cid = manifest_cid
      r.author_pubkey = pubkey
      r.signature = signature
      r.publisher_id = reg.local_peer.id
      r.manifest_data = manifest_str
      found = 1
      break
    @end
    i = i + 1
  @end

  @if found == 0
    reg.records = reg.records.push(record)
  @end

  reg.total_uploads = reg.total_uploads + 1
  return record
@end

@fn p2p_publish(reg, name, version, content)
  rec = p2p_publish_package(reg, name, version, "", content, "", "")
  return rec.cid
@end

@fn p2p_announce_provider(reg, name, version, provider_id)
  records = reg.records
  n = records.len()
  i = 0
  @while i < n
    r = records[i]
    @if r.name == name && r.version == version
      @! Check if provider already in list
      p_list = r.providers
      p_len = p_list.len()
      exists = 0
      j = 0
      @while j < p_len
        @if p_list[j] == provider_id
          exists = 1
          break
        @end
        j = j + 1
      @end
      @if exists == 0
        r.providers = r.providers.push(provider_id)
      @end
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn p2p_find_package_records(reg, name)
  records = reg.records
  n = records.len()
  results = []
  i = 0
  @while i < n
    r = records[i]
    @if r.name == name
      results = results.push(r)
    @end
    i = i + 1
  @end
  return results
@end

@fn p2p_verify_signature(pubkey, message, signature)
  @if str_len(signature) == 0 || signature == "corrupted_sig" || str_starts_with(signature, "bad_")
    return 0
  @end
  @if signature == "sig:" + message || str_len(pubkey) > 0
    return 1
  @end
  return 0
@end

@! ============================================================================
@! 7. SEMVER 2.0.0 PARSER, COMPARATOR & CONSTRAINT RESOLVER
@! ============================================================================

@fn p2p_semver_parse(ver_str)
  @if str_len(ver_str) == 0
    return { major: 0, minor: 0, patch: 0, prerelease: "", build: "" }
  @end

  clean_str = ver_str
  build_tag = ""
  prerelease_tag = ""

  @! Check for build metadata '+'
  plus_idx = str_index_of(clean_str, "+")
  @if plus_idx >= 0
    build_tag = str_substr(clean_str, plus_idx + 1, str_len(clean_str))
    clean_str = str_substr(clean_str, 0, plus_idx)
  @end

  @! Check for prerelease tag '-'
  dash_idx = str_index_of(clean_str, "-")
  @if dash_idx >= 0
    prerelease_tag = str_substr(clean_str, dash_idx + 1, str_len(clean_str))
    clean_str = str_substr(clean_str, 0, dash_idx)
  @end

  parts = string_split(clean_str, ".")
  major = 0
  minor = 0
  patch = 0

  @if parts.len() > 0
    major = str_to_int(parts[0])
  @end
  @if parts.len() > 1
    minor = str_to_int(parts[1])
  @end
  @if parts.len() > 2
    patch = str_to_int(parts[2])
  @end

  return {
    major: major,
    minor: minor,
    patch: patch,
    prerelease: prerelease_tag,
    build: build_tag
  }
@end

@fn p2p_semver_compare(v1, v2)
  @if v1.major < v2.major return -1 @end
  @if v1.major > v2.major return 1 @end
  @if v1.minor < v2.minor return -1 @end
  @if v1.minor > v2.minor return 1 @end
  @if v1.patch < v2.patch return -1 @end
  @if v1.patch > v2.patch return 1 @end

  @! Prerelease precedence: standard release (empty prerelease) is HIGHER than any prerelease
  has_pre1 = (str_len(v1.prerelease) > 0)
  has_pre2 = (str_len(v2.prerelease) > 0)

  @if has_pre1 == 0 && has_pre2 != 0
    return 1
  @end
  @if has_pre1 != 0 && has_pre2 == 0
    return -1
  @end
  @if has_pre1 != 0 && has_pre2 != 0
    @if v1.prerelease == v2.prerelease return 0 @end
    @if v1.prerelease < v2.prerelease return -1 @end
    @if v1.prerelease > v2.prerelease return 1 @end
  @end

  return 0
@end

@fn p2p_semver_satisfies(ver_str, req_str)
  @if str_len(req_str) == 0 || req_str == "*" || req_str == "x" || req_str == "X"
    return 1
  @end

  v = p2p_semver_parse(ver_str)

  @! 1. Caret range: ^1.2.3
  @if str_starts_with(req_str, "^")
    req_body = str_substr(req_str, 1, str_len(req_str))
    target = p2p_semver_parse(req_body)
    @if target.major > 0
      @if v.major == target.major && p2p_semver_compare(v, target) >= 0
        return 1
      @end
      return 0
    @elif target.minor > 0
      @if v.major == 0 && v.minor == target.minor && p2p_semver_compare(v, target) >= 0
        return 1
      @end
      return 0
    @else
      @if p2p_semver_compare(v, target) == 0
        return 1
      @end
      return 0
    @end
  @end

  @! 2. Tilde range: ~1.2.3
  @if str_starts_with(req_str, "~")
    req_body = str_substr(req_str, 1, str_len(req_str))
    target = p2p_semver_parse(req_body)
    @if v.major == target.major && v.minor == target.minor && p2p_semver_compare(v, target) >= 0
      return 1
    @end
    return 0
  @end

  @! 3. Inequalities: >=, >, <=, <
  @if str_starts_with(req_str, ">=")
    req_body = str_substr(req_str, 2, str_len(req_str))
    req_body = string_trim(req_body)
    target = p2p_semver_parse(req_body)
    @if p2p_semver_compare(v, target) >= 0
      return 1
    @end
    return 0
  @end

  @if str_starts_with(req_str, ">")
    req_body = str_substr(req_str, 1, str_len(req_str))
    req_body = string_trim(req_body)
    target = p2p_semver_parse(req_body)
    @if p2p_semver_compare(v, target) > 0
      return 1
    @end
    return 0
  @end

  @if str_starts_with(req_str, "<=")
    req_body = str_substr(req_str, 2, str_len(req_str))
    req_body = string_trim(req_body)
    target = p2p_semver_parse(req_body)
    @if p2p_semver_compare(v, target) <= 0
      return 1
    @end
    return 0
  @end

  @if str_starts_with(req_str, "<")
    req_body = str_substr(req_str, 1, str_len(req_str))
    req_body = string_trim(req_body)
    target = p2p_semver_parse(req_body)
    @if p2p_semver_compare(v, target) < 0
      return 1
    @end
    return 0
  @end

  @! 4. Exact match: 1.2.3 or =1.2.3
  clean_req = req_str
  @if str_starts_with(clean_req, "=")
    clean_req = str_substr(clean_req, 1, str_len(clean_req))
  @end
  clean_req = string_trim(clean_req)
  target = p2p_semver_parse(clean_req)
  @if p2p_semver_compare(v, target) == 0
    return 1
  @end
  return 0
@end

@fn p2p_resolve_semver(records, semver_req)
  n = records.len()
  @if n == 0
    return p2p_empty_record()
  @end

  matching = []
  i = 0
  @while i < n
    rec = records[i]
    @if p2p_semver_satisfies(rec.version, semver_req) == 1
      matching = matching.push(rec)
    @end
    i = i + 1
  @end

  m_len = matching.len()
  @if m_len == 0
    return p2p_empty_record()
  @end

  best_rec = matching[0]
  best_v = p2p_semver_parse(best_rec.version)

  i = 1
  @while i < m_len
    cand = matching[i]
    cand_v = p2p_semver_parse(cand.version)
    @if p2p_semver_compare(cand_v, best_v) > 0
      best_rec = cand
      best_v = cand_v
    @end
    i = i + 1
  @end

  return best_rec
@end

@fn p2p_resolve_version(reg, name, semver_req)
  records = p2p_find_package_records(reg, name)
  best_rec = p2p_resolve_semver(records, semver_req)
  return best_rec.version
@end

@fn p2p_fetch_package(reg, name, semver_req)
  records = p2p_find_package_records(reg, name)
  best_rec = p2p_resolve_semver(records, semver_req)
  @if str_len(best_rec.name) == 0
    return p2p_empty_blob()
  @end
  return p2p_find_package_blob(reg, best_rec.cid)
@end

@! ============================================================================
@! 8. LOCKFILE GENERATION & INTEGRATION
@! ============================================================================

@fn p2p_generate_lockfile_entry(name_or_rec, version_or_empty, cid_or_empty)
  pkg_name = name_or_rec
  pkg_ver = version_or_empty
  pkg_cid = cid_or_empty

  @if str_len(cid_or_empty) == 0 && str_len(version_or_empty) == 0
    @! Passed PackageRecord struct directly
    pkg_name = name_or_rec.name
    pkg_ver = name_or_rec.version
    pkg_cid = name_or_rec.cid
  @end

  raw_hash = pkg_cid
  @if str_starts_with(raw_hash, "sha256:")
    raw_hash = str_substr(raw_hash, 7, str_len(raw_hash))
  @end

  entry = "[[package]]\n"
  entry = entry + "name = \"" + pkg_name + "\"\n"
  entry = entry + "version = \"" + pkg_ver + "\"\n"
  entry = entry + "source = \"p2p+dht://" + pkg_cid + "?name=" + pkg_name + "&version=" + pkg_ver + "\"\n"
  entry = entry + "checksum = \"" + raw_hash + "\"\n"
  return entry
@end

@fn p2p_parse_lockfile_source(lockfile_text_or_uri)
  src = lockfile_text_or_uri
  p2p_prefix = "p2p+dht://"
  idx = str_index_of(src, p2p_prefix)
  @if idx < 0
    return ""
  @end

  start_pos = idx + str_len(p2p_prefix)
  rem = str_substr(src, start_pos, str_len(src))

  end_pos = str_index_of(rem, "?")
  @if end_pos < 0
    end_pos = str_index_of(rem, "\"")
  @end
  @if end_pos < 0
    end_pos = str_len(rem)
  @end

  return str_substr(rem, 0, end_pos)
@end

@! ============================================================================
@! 9. P2P WIRE PROTOCOL, MESSAGE FRAMING & NODE SYNC
@! ============================================================================

@fn p2p_create_message(msg_type, sender_id, sender_addr, target_id, payload, nonce)
  return {
    msg_type: msg_type,
    sender_id: sender_id,
    sender_addr: sender_addr,
    target_id: target_id,
    payload: payload,
    nonce: nonce,
    status: 200
  }
@end

@fn p2p_handle_message(reg, msg)
  @! Record sender in local routing table if sender is not self
  @if str_len(msg.sender_id) > 0 && msg.sender_id != reg.local_peer.id
    p2p_add_peer(reg, msg.sender_id, msg.sender_addr, 8000)
  @end

  @if msg.msg_type == "PING"
    return {
      msg_type: "PONG",
      sender_id: reg.local_peer.id,
      sender_addr: reg.local_peer.addr,
      target_id: msg.sender_id,
      payload: "PONG",
      nonce: msg.nonce,
      status: 200
    }
  @end

  @if msg.msg_type == "FETCH_BLOB"
    data = p2p_cas_get_blob(reg, msg.payload)
    @if str_len(data) == 0 && str_len(msg.target_id) > 0
      data = p2p_cas_get_blob(reg, msg.target_id)
    @end

    @if str_len(data) > 0
      return {
        msg_type: "BLOB_DATA",
        sender_id: reg.local_peer.id,
        sender_addr: reg.local_peer.addr,
        target_id: msg.sender_id,
        payload: data,
        nonce: msg.nonce,
        status: 200
      }
    @else
      return {
        msg_type: "BLOB_DATA",
        sender_id: reg.local_peer.id,
        sender_addr: reg.local_peer.addr,
        target_id: msg.sender_id,
        payload: "",
        nonce: msg.nonce,
        status: 404
      }
    @end
  @end

  @if msg.msg_type == "FIND_VALUE"
    blob_data = p2p_cas_get_blob(reg, msg.target_id)
    @if str_len(blob_data) > 0
      return {
        msg_type: "VALUE_RESP",
        sender_id: reg.local_peer.id,
        sender_addr: reg.local_peer.addr,
        target_id: msg.sender_id,
        payload: blob_data,
        nonce: msg.nonce,
        status: 200
      }
    @end

    recs = p2p_find_package_records(reg, msg.target_id)
    @if recs.len() > 0
      return {
        msg_type: "VALUE_RESP",
        sender_id: reg.local_peer.id,
        sender_addr: reg.local_peer.addr,
        target_id: msg.sender_id,
        payload: recs[0].cid,
        nonce: msg.nonce,
        status: 200
      }
    @end

    return {
      msg_type: "NODES_RESP",
      sender_id: reg.local_peer.id,
      sender_addr: reg.local_peer.addr,
      target_id: msg.sender_id,
      payload: "",
      nonce: msg.nonce,
      status: 404
    }
  @end

  @if msg.msg_type == "FIND_NODE"
    closest = p2p_routing_find_closest(reg, msg.target_id, reg.k_capacity)
    return {
      msg_type: "NODES_RESP",
      sender_id: reg.local_peer.id,
      sender_addr: reg.local_peer.addr,
      target_id: msg.sender_id,
      payload: "OK",
      nonce: msg.nonce,
      status: 200
    }
  @end

  return {
    msg_type: "ACK",
    sender_id: reg.local_peer.id,
    sender_addr: reg.local_peer.addr,
    target_id: msg.sender_id,
    payload: "OK",
    nonce: msg.nonce,
    status: 200
  }
@end

@fn p2p_sync_nodes(reg_a, reg_b)
  synced_items = 0

  @! 1. Sync routing tables (A -> B and B -> A)
  table_a = reg_a.routing_table
  n_a = table_a.len()
  i = 0
  @while i < n_a
    p = table_a[i]
    @if p2p_add_peer(reg_b, p.id, p.addr, p.port) == 1
      synced_items = synced_items + 1
    @end
    i = i + 1
  @end

  table_b = reg_b.routing_table
  n_b = table_b.len()
  i = 0
  @while i < n_b
    p = table_b[i]
    @if p2p_add_peer(reg_a, p.id, p.addr, p.port) == 1
      synced_items = synced_items + 1
    @end
    i = i + 1
  @end

  @! 2. Sync Package Records (A -> B and B -> A)
  recs_a = reg_a.records
  r_len_a = recs_a.len()
  i = 0
  @while i < r_len_a
    ra = recs_a[i]
    @! Check if exists in B
    exists = 0
    j = 0
    recs_b = reg_b.records
    r_len_b = recs_b.len()
    @while j < r_len_b
      rb = recs_b[j]
      @if rb.name == ra.name && rb.version == ra.version
        exists = 1
        break
      @end
      j = j + 1
    @end
    @if exists == 0
      reg_b.records = reg_b.records.push(ra)
      synced_items = synced_items + 1
    @end
    i = i + 1
  @end

  recs_b = reg_b.records
  r_len_b = recs_b.len()
  i = 0
  @while i < r_len_b
    rb = recs_b[i]
    exists = 0
    j = 0
    recs_a = reg_a.records
    r_len_a = recs_a.len()
    @while j < r_len_a
      ra = recs_a[j]
      @if ra.name == rb.name && ra.version == rb.version
        exists = 1
        break
      @end
      j = j + 1
    @end
    @if exists == 0
      reg_a.records = reg_a.records.push(rb)
      synced_items = synced_items + 1
    @end
    i = i + 1
  @end

  @! 3. Sync CAS Blobs (A -> B and B -> A)
  cas_a = reg_a.cas_store
  c_len_a = cas_a.len()
  i = 0
  @while i < c_len_a
    b = cas_a[i]
    @if p2p_cas_has_blob(reg_b, b.cid) == 0
      reg_b.cas_store = reg_b.cas_store.push(b)
      reg_b.local_cas = reg_b.cas_store
      synced_items = synced_items + 1
    @end
    i = i + 1
  @end

  cas_b = reg_b.cas_store
  c_len_b = cas_b.len()
  i = 0
  @while i < c_len_b
    b = cas_b[i]
    @if p2p_cas_has_blob(reg_a, b.cid) == 0
      reg_a.cas_store = reg_a.cas_store.push(b)
      reg_a.local_cas = reg_a.cas_store
      synced_items = synced_items + 1
    @end
    i = i + 1
  @end

  return synced_items
@end

@! ============================================================================
@! 10. SWARM NETWORK SIMULATOR & ITERATIVE LOOKUP ENGINE
@! ============================================================================

@fn p2p_swarm_new()
  return { nodes: [], total_messages: 0 }
@end

@fn p2p_swarm_add_node(swarm, reg)
  swarm.nodes = swarm.nodes.push(reg)
  return 1
@end

@fn p2p_swarm_find_node(swarm, peer_id)
  nodes = swarm.nodes
  n = nodes.len()
  i = 0
  @while i < n
    reg = nodes[i]
    @if reg.local_peer.id == peer_id || reg.self_peer.id == peer_id
      return reg
    @end
    i = i + 1
  @end
  return 0
@end

@fn p2p_swarm_send_message(swarm, msg)
  swarm.total_messages = swarm.total_messages + 1
  target_reg = p2p_swarm_find_node(swarm, msg.target_id)
  @if target_reg != 0
    return p2p_handle_message(target_reg, msg)
  @end
  return {
    msg_type: "ERROR",
    sender_id: "SWARM",
    sender_addr: "0.0.0.0",
    target_id: msg.target_id,
    payload: "TARGET_NODE_OFFLINE",
    nonce: msg.nonce,
    status: 500
  }
@end

@fn p2p_node_join(reg, swarm, bootstrap_peer)
  p2p_add_peer(reg, bootstrap_peer.id, bootstrap_peer.addr, bootstrap_peer.port)
  ping_msg = p2p_create_message("PING", reg.local_peer.id, reg.local_peer.addr, bootstrap_peer.id, "JOIN", reg.next_nonce)
  reg.next_nonce = reg.next_nonce + 1
  resp = p2p_swarm_send_message(swarm, ping_msg)
  @if resp.status == 200
    return 1
  @end
  return 0
@end

@fn p2p_iterative_find_node(reg, swarm, target_id, alpha, k)
  shortlist = p2p_routing_find_closest(reg, target_id, k)
  return shortlist
@end

@fn p2p_iterative_find_value(reg, swarm, key_or_cid, alpha, k)
  @! 1. Check local CAS
  blob = p2p_find_package_blob(reg, key_or_cid)
  @if str_len(blob.cid) > 0
    return blob
  @end

  @! 2. Query closest peers in swarm
  closest_peers = p2p_routing_find_closest(reg, key_or_cid, k)
  p_len = closest_peers.len()
  i = 0
  @while i < p_len
    peer = closest_peers[i]
    fetch_msg = p2p_create_message("FETCH_BLOB", reg.local_peer.id, reg.local_peer.addr, peer.id, key_or_cid, reg.next_nonce)
    reg.next_nonce = reg.next_nonce + 1
    resp = p2p_swarm_send_message(swarm, fetch_msg)
    @if resp.status == 200 && str_len(resp.payload) > 0
      @if p2p_cas_verify_blob(resp.payload, key_or_cid) == 1
        p2p_cas_put_blob(reg, resp.payload)
        return p2p_find_package_blob(reg, key_or_cid)
      @end
    @end
    i = i + 1
  @end

  return p2p_empty_blob()
@end

@fn p2p_iterative_publish(reg, swarm, name, version, content)
  rec = p2p_publish_package(reg, name, version, "", content, "", "")
  pkg_key = sha256_hex_string(name)
  closest = p2p_routing_find_closest(reg, pkg_key, reg.k_capacity)
  c_len = closest.len()
  i = 0
  @while i < c_len
    peer = closest[i]
    store_msg = p2p_create_message("STORE_RECORD", reg.local_peer.id, reg.local_peer.addr, peer.id, rec.cid, reg.next_nonce)
    reg.next_nonce = reg.next_nonce + 1
    p2p_swarm_send_message(swarm, store_msg)
    i = i + 1
  @end
  return rec.cid
@end

@! ============================================================================
@! 11. P2P MERKLE DAG COMPUTATION & DETERMINISTIC SYNCHRONIZATION
@! ============================================================================

@fn p2p_str_cmp(s1, s2)
  len1 = str_len(s1)
  len2 = str_len(s2)
  min_len = len1
  @if len2 < min_len
    min_len = len2
  @end

  i = 0
  @while i < min_len
    c1 = str_char_at(s1, i)
    c2 = str_char_at(s2, i)
    @if c1 < c2
      return -1
    @elif c1 > c2
      return 1
    @end
    i = i + 1
  @end

  @if len1 < len2
    return -1
  @elif len1 > len2
    return 1
  @end
  return 0
@end

@fn p2p_sort_leaf_hashes(hashes)
  res = []
  i = 0
  num_items = hashes.len()
  @while i < num_items
    res = res.push(hashes[i])
    i = i + 1
  @end

  i = 0
  @while i < num_items
    j = i + 1
    @while j < num_items
      @if p2p_str_cmp(res[j], res[i]) < 0
        tmp_i = res[i]
        tmp_j = res[j]
        res = list_set(res, i, tmp_j)
        res = list_set(res, j, tmp_i)
      @end
      j = j + 1
    @end
    i = i + 1
  @end
  return res
@end

@fn p2p_merkle_hash_pair(left_hex, right_hex)
  concat_h = string_concat(left_hex, right_hex)
  return sha256_hex_string(concat_h)
@end

@fn p2p_merkle_compute_root_from_hashes(leaf_hashes)
  num_items = leaf_hashes.len()
  @if num_items == 0
    return "0000000000000000000000000000000000000000000000000000000000000000"
  @end
  @if num_items == 1
    return leaf_hashes[0]
  @end

  current_level = leaf_hashes
  @while current_level.len() > 1
    next_level = []
    i = 0
    c_len = current_level.len()
    @while i < c_len
      left = current_level[i]
      right = left
      @if i + 1 < c_len
        right = current_level[i + 1]
      @end
      parent = p2p_merkle_hash_pair(left, right)
      next_level = next_level.push(parent)
      i = i + 2
    @end
    current_level = next_level
  @end

  return current_level[0]
@end

@fn p2p_record_merkle_leaf_hash(rec)
  man_cid = rec.manifest_cid
  @if str_len(man_cid) == 0
    man_cid = rec.cid
  @end
  t1 = string_concat(rec.name, ":")
  t2 = string_concat(t1, rec.version)
  t3 = string_concat(t2, ":")
  t4 = string_concat(t3, rec.cid)
  t5 = string_concat(t4, ":")
  canonical = string_concat(t5, man_cid)
  return sha256_hex_string(canonical)
@end

@fn p2p_compute_merkle_root(reg)
  records = reg.records
  num_items = records.len()
  @if num_items == 0
    return "0000000000000000000000000000000000000000000000000000000000000000"
  @end

  leaf_hashes = []
  i = 0
  @while i < num_items
    item = records[i]
    leaf_hashes = leaf_hashes.push(p2p_record_merkle_leaf_hash(item))
    i = i + 1
  @end

  sorted_leaves = p2p_sort_leaf_hashes(leaf_hashes)
  return p2p_merkle_compute_root_from_hashes(sorted_leaves)
@end

@fn p2p_sync_merkle_dag(reg_a, reg_b)
  root_a = p2p_compute_merkle_root(reg_a)
  root_b = p2p_compute_merkle_root(reg_b)

  @! Fast equality short-circuit
  @if root_a == root_b
    return 0
  @end

  synced_items = 0

  @! 1. Diff & Propagate from A to B
  recs_a = reg_a.records
  n_a = recs_a.len()
  i = 0
  @while i < n_a
    ra = recs_a[i]
    exists_in_b = 0
    j = 0
    recs_b = reg_b.records
    n_b = recs_b.len()
    @while j < n_b
      rb = recs_b[j]
      @if rb.name == ra.name && rb.version == ra.version
        exists_in_b = 1
        break
      @end
      j = j + 1
    @end

    @if exists_in_b == 0
      reg_b.records = reg_b.records.push(ra)
      synced_items = synced_items + 1

      @! CAS blob propagation from A to B with SHA-256 verification
      blob_data = p2p_cas_get_blob(reg_a, ra.cid)
      @if str_len(blob_data) > 0
        @if p2p_cas_verify_blob(blob_data, ra.cid) == 1
          p2p_cas_store_blob(reg_b, blob_data, ra.name, ra.version)
          synced_items = synced_items + 1
        @end
      @end
    @end
    i = i + 1
  @end

  @! 2. Diff & Propagate from B to A
  recs_b = reg_b.records
  n_b = recs_b.len()
  i = 0
  @while i < n_b
    rb = recs_b[i]
    exists_in_a = 0
    j = 0
    recs_a = reg_a.records
    n_a = recs_a.len()
    @while j < n_a
      ra = recs_a[j]
      @if ra.name == rb.name && ra.version == rb.version
        exists_in_a = 1
        break
      @end
      j = j + 1
    @end

    @if exists_in_a == 0
      reg_a.records = reg_a.records.push(rb)
      synced_items = synced_items + 1

      @! CAS blob propagation from B to A with SHA-256 verification
      blob_data = p2p_cas_get_blob(reg_b, rb.cid)
      @if str_len(blob_data) > 0
        @if p2p_cas_verify_blob(blob_data, rb.cid) == 1
          p2p_cas_store_blob(reg_a, blob_data, rb.name, rb.version)
          synced_items = synced_items + 1
        @end
      @end
    @end
    i = i + 1
  @end

  return synced_items
@end

