@fn mpm_err_json(msg)
  t1 = string_concat("{\"error\": \"", msg)
  return string_concat(t1, "\"}")
@end

@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — DECENTRALIZED LIPIPKG PACKAGE SERVER & REGISTRY
@! Module: universe/p2p/mpm_server.lp
@! Milestone 3 (Requirement R2)
@! 100% Pure Lipi Implementation — Zero External / C Dependencies
@! Features: Full HTTP REST Server, P2P CAS Storage, Merkle DAG Sync,
@! SemVer 2.0.0 Constraint Resolution, Cryptographic Verification, Client API
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/json"
import "universe/crypto/sha256"
import "universe/net/http"
import "universe/net/tcp"
import "universe/web/app"
import "universe/web/router"
import "universe/web/context"
import "universe/web/server"
import "universe/p2p/registry"

@! ============================================================================
@! 1. DATA STRUCTURE DEFINITIONS
@! ============================================================================

@struct MPMServerConfig
  host: string
  port: i64
  p2p_peer_id: string
  p2p_port: i64
  p2p_enabled: i64
  data_dir: string
  max_body_bytes: i64
@end

@struct PackageManifest
  name: string
  version: string
  description: string
  author: string
  license: string
  tags: array
@end

@struct PackageMeta
  name: string
  version: string
  description: string
  author: string
  license: string
  tags: array
  dependencies: array
  cid: string
  sha256: string
  size_bytes: i64
  published_at: i64
  publisher_id: string
  signature: string
  merkle_leaf: string
  downloads: i64
@end

@struct PackageIndexEntry
  name: string
  latest_version: string
  description: string
  author: string
  license: string
  tags: array
  versions: array
  cid: string
  sha256: string
  total_downloads: i64
@end

@struct MPMClientPublishResult
  status_code: i64
  body: string
  sha256: string
  verified: i64
@end

@struct MPMClientFetchResult
  status_code: i64
  payload: string
  sha256: string
  expected_sha: string
  verified: i64
@end

@struct MPMClientIndexResult
  status_code: i64
  body: string
@end

@struct MPMClientSearchResult
  status_code: i64
  body: string
@end

@struct MPMServer
  config: MPMServerConfig
  web_app: WebApp
  web_server: WebServer
  p2p_registry: P2PRegistry
  p2p_swarm: P2PSwarmNetwork
  merkle_root: string
  packages: array
  is_running: i64
  total_requests: i64
  total_publishes: i64
  total_downloads: i64
@end

@! ============================================================================
@! 2. STRING & JSON UTILITIES
@! ============================================================================

@fn mpm_escape_json(s)
  @! WHY: Escapes special characters for JSON encoding safely in chunked spans without excess allocations.
  res = ""
  i = 0
  n = str_len(s)
  span_start = 0
  @while i < n
    ch = str_char_at(s, i)
    @if ch == 34 || ch == 92 || ch == 10 || ch == 13 || ch == 9
      @if i > span_start
        res = string_concat(res, str_substr(s, span_start, i))
      @end
      @if ch == 34
        res = string_concat(res, "\\\"")
      @elif ch == 92
        res = string_concat(res, "\\\\")
      @elif ch == 10
        res = string_concat(res, "\\n")
      @elif ch == 13
        res = string_concat(res, "\\r")
      @elif ch == 9
        res = string_concat(res, "\\t")
      @end
      span_start = i + 1
    @end
    i = i + 1
  @end
  @if span_start < n
    res = string_concat(res, str_substr(s, span_start, n))
  @end
  return res
@end

@fn mpm_json_field(key, val)
  @! WHY: Constructs JSON key-value string safely with zero pointer additions.
  k = mpm_escape_json(key)
  v = mpm_escape_json(val)
  res = string_concat("\"", k)
  res = string_concat(res, "\":\"")
  res = string_concat(res, v)
  res = string_concat(res, "\"")
  return res
@end

@fn mpm_json_field_num(key, num_val)
  @! WHY: Constructs JSON numeric field safely with to_str conversion.
  k = mpm_escape_json(key)
  res = string_concat("\"", k)
  res = string_concat(res, "\":")
  res = string_concat(res, to_str(num_val))
  return res
@end

@fn mpm_extract_json_string(body, field_name)
  tmp_f = string_concat(field_name, "\"")
  target = string_concat("\"", tmp_f)
  pos = str_index_of(body, target)
  @if pos < 0
    return ""
  @end

  colon_pos = -1
  i = pos + str_len(target)
  blen = str_len(body)
  @while i < blen && colon_pos < 0
    ch = str_char_at(body, i)
    @if ch == 58 @! ':'
      colon_pos = i
    @end
    i = i + 1
  @end

  @if colon_pos < 0
    return ""
  @end

  @! Find opening quote or start of token
  quote_start = -1
  i = colon_pos + 1
  done_find_quote = 0
  @while i < blen && done_find_quote == 0
    ch = str_char_at(body, i)
    @if ch == 34 @! '"'
      quote_start = i
      done_find_quote = 1
    @elif ch != 32 && ch != 9 && ch != 10 && ch != 13
      done_find_quote = 1
    @else
      i = i + 1
    @end
  @end

  @if quote_start >= 0
    @! String literal
    j = quote_start + 1
    val = ""
    span_start = j
    done_str = 0
    @while j < blen && done_str == 0
      sc = str_char_at(body, j)
      @if sc == 92 && j + 1 < blen @! '\'
        @if j > span_start
          val = string_concat(val, str_substr(body, span_start, j))
        @end
        next_c = str_char_at(body, j + 1)
        @if next_c == 34 val = string_concat(val, "\"")
        @elif next_c == 110 val = string_concat(val, "\n")
        @elif next_c == 116 val = string_concat(val, "\t")
        @elif next_c == 114 val = string_concat(val, "\r")
        @elif next_c == 92 val = string_concat(val, "\\")
        @else val = string_concat(val, str_substr(body, j + 1, j + 2))
        @end
        j = j + 2
        span_start = j
      @elif sc == 34 @! '"'
        @if j > span_start
          val = string_concat(val, str_substr(body, span_start, j))
        @end
        done_str = 1
      @else
        j = j + 1
      @end
    @end
    return val
  @end

  @! Unquoted token (e.g. number, boolean, null)
  token_start = colon_pos + 1
  @while token_start < blen && (str_char_at(body, token_start) == 32 || str_char_at(body, token_start) == 9 || str_char_at(body, token_start) == 10 || str_char_at(body, token_start) == 13)
    token_start = token_start + 1
  @end

  token_end = token_start
  done_tok = 0
  @while token_end < blen && done_tok == 0
    tc = str_char_at(body, token_end)
    @if tc == 44 || tc == 125 || tc == 93 || tc == 32 || tc == 10 || tc == 13 || tc == 9
      done_tok = 1
    @else
      token_end = token_end + 1
    @end
  @end

  @if token_end > token_start
    return str_substr(body, token_start, token_end)
  @end

  return ""
@end

@fn mpm_extract_json_tags(body)
  target = "\"tags\""
  pos = str_index_of(body, target)
  @if pos < 0
    return []
  @end

  bracket_open = -1
  i = pos + str_len(target)
  blen = str_len(body)
  @while i < blen && bracket_open < 0
    @if str_char_at(body, i) == 91 @! '['
      bracket_open = i
    @end
    i = i + 1
  @end

  @if bracket_open < 0
    return []
  @end

  tags = []
  i = bracket_open + 1
  reading_tags = 1
  @while i < blen && reading_tags == 1
    ch = str_char_at(body, i)
    @if ch == 93 @! ']'
      reading_tags = 0
    @elif ch == 34 @! '"'
      tag_start = i + 1
      j = tag_start
      @while j < blen && str_char_at(body, j) != 34
        j = j + 1
      @end
      tag_val = str_substr(body, tag_start, j)
      tags = tags.push(tag_val)
      i = j + 1
    @else
      i = i + 1
    @end
  @end

  return tags
@end

@fn mpm_is_valid_identifier(name)
  n = str_len(name)
  @if n == 0
    return 0
  @end
  i = 0
  @while i < n
    ch = str_char_at(name, i)
    is_upper = (ch >= 65 && ch <= 90)
    is_lower = (ch >= 97 && ch <= 122)
    is_digit = (ch >= 48 && ch <= 57)
    is_special = (ch == 95 || ch == 45 || ch == 46 || ch == 64 || ch == 47) @! _, -, ., @, /
    @if is_upper == 0 && is_lower == 0 && is_digit == 0 && is_special == 0
      return 0
    @end
    i = i + 1
  @end
  return 1
@end

@fn mpm_is_valid_semver(ver_str)
  @if str_len(ver_str) == 0
    return 0
  @end
  v = p2p_semver_parse(ver_str)
  clean_v = ver_str
  plus_idx = str_index_of(clean_v, "+")
  @if plus_idx >= 0
    clean_v = str_substr(clean_v, 0, plus_idx)
  @end
  dash_idx = str_index_of(clean_v, "-")
  @if dash_idx >= 0
    clean_v = str_substr(clean_v, 0, dash_idx)
  @end

  parts = string_split(clean_v, ".")
  @if parts.len() < 3
    return 0
  @end

  @! Validate each numeric core segment
  p_idx = 0
  @while p_idx < 3
    p = parts[p_idx]
    @if str_len(p) == 0
      return 0
    @end
    c_idx = 0
    c_len = str_len(p)
    @while c_idx < c_len
      ch = str_char_at(p, c_idx)
      @if ch < 48 || ch > 57
        return 0
      @end
      c_idx = c_idx + 1
    @end
    p_idx = p_idx + 1
  @end

  return 1
@end

@! ============================================================================
@! 3. SERVER CONSTRUCTOR & CONFIGURATION
@! ============================================================================

@fn mpm_server_config_default()
  return {
    host: "127.0.0.1",
    port: 8080,
    p2p_peer_id: "mpm-primary-node",
    p2p_port: 9090,
    p2p_enabled: 1,
    data_dir: ".maya/mpm_registry",
    max_body_bytes: 10485760
  }
@end

@fn mpm_server_new(config)
  @if config == 0
    config = mpm_server_config_default()
  @end

  app = web_new()
  p2p_reg = p2p_registry_new(config.p2p_peer_id, config.host, config.p2p_port)
  p2p_sw = p2p_swarm_new()
  p2p_swarm_add_node(p2p_sw, p2p_reg)

  empty_root = "0000000000000000000000000000000000000000000000000000000000000000"

  srv = {
    config: config,
    web_app: app,
    web_server: 0,
    p2p_registry: p2p_reg,
    p2p_swarm: p2p_sw,
    merkle_root: empty_root,
    packages: [],
    is_running: 0,
    total_requests: 0,
    total_publishes: 0,
    total_downloads: 0
  }

  srv.web_server = web_server_new(app)
  return srv
@end

@! ============================================================================
@! 4. REST ROUTE HANDLERS
@! ============================================================================

@fn mpm_server_handle_publish(server, req, res)
  body = req.req_body
  @if str_len(body) == 0
    res_status(res, 400)
    res_json(res, mpm_err_json("Request body cannot be empty"))
    return res
  @end

  name = mpm_extract_json_string(body, "name")
  version = mpm_extract_json_string(body, "version")
  desc = mpm_extract_json_string(body, "description")
  author = mpm_extract_json_string(body, "author")
  license = mpm_extract_json_string(body, "license")
  payload = mpm_extract_json_string(body, "payload")
  client_sha = mpm_extract_json_string(body, "sha256")
  sig = mpm_extract_json_string(body, "signature")
  tags = mpm_extract_json_tags(body)

  @! Validation 1: Package Name
  @if str_len(name) == 0 || mpm_is_valid_identifier(name) == 0
    res_status(res, 400)
    res_json(res, mpm_err_json("Invalid or missing package name"))
    return res
  @end

  @! Validation 2: SemVer 2.0.0
  @if str_len(version) == 0 || mpm_is_valid_semver(version) == 0
    res_status(res, 400)
    err_v = string_concat("Invalid SemVer 2.0.0 version string: ", version)
    res_json(res, mpm_err_json(err_v))
    return res
  @end

  @! Validation 3: Payload
  @if str_len(payload) == 0
    res_status(res, 400)
    res_json(res, mpm_err_json("Package payload is required"))
    return res
  @end

  @! Validation 4: SHA-256 Checksum Integrity
  actual_sha = sha256_hex_string(payload)
  clean_client_sha = client_sha
  @if str_starts_with(clean_client_sha, "sha256:")
    clean_client_sha = str_substr(clean_client_sha, 7, str_len(clean_client_sha))
  @end

  @if str_len(clean_client_sha) > 0 && str_eq(str_to_lower(clean_client_sha), str_to_lower(actual_sha)) == 0
    res_status(res, 400)
    res_json(res, mpm_err_json("SHA-256 integrity checksum verification failed"))
    return res
  @end

  @! Validation 5: Immutability / Duplicate Check
  i = 0
  n_pkgs = server.packages.len()
  @while i < n_pkgs
    p = server.packages[i]
    @if str_eq(p.name, name) == 1 && str_eq(p.version, version) == 1
      res_status(res, 409)
      err_m = string_concat("Package version already exists: ", name)
      res_json(res, mpm_err_json(err_m))
      return res
    @end
    i = i + 1
  @end

  @! Execution: Store in CAS
  cid = p2p_cas_store_blob(server.p2p_registry, payload, name, version)
  ml1 = string_concat(name, ":")
  ml2 = string_concat(ml1, version)
  ml3 = string_concat(ml2, ":")
  ml4 = string_concat(ml3, cid)
  ml5 = string_concat(ml4, ":")
  merkle_leaf = sha256_hex_string(string_concat(ml5, actual_sha))

  @! Create and record metadata
  meta = {
    name: name,
    version: version,
    description: desc,
    author: author,
    license: license,
    tags: tags,
    dependencies: [],
    cid: cid,
    sha256: actual_sha,
    size_bytes: str_len(payload),
    published_at: 1756584000,
    publisher_id: server.config.p2p_peer_id,
    signature: sig,
    merkle_leaf: merkle_leaf,
    downloads: 0
  }
  server.packages = server.packages.push(meta)

  rec = {
    name: name,
    version: version,
    cid: cid,
    manifest_cid: cid,
    author_pubkey: "",
    signature: sig,
    publisher_id: server.config.p2p_peer_id,
    providers: [server.config.p2p_peer_id],
    announced_at: 1756584000,
    ttl_sec: 86400,
    downloads: 0,
    manifest_data: desc
  }
  server.p2p_registry.records = server.p2p_registry.records.push(rec)

  @! Recalculate deterministic Merkle Root
  server.merkle_root = p2p_compute_merkle_root(server.p2p_registry)
  server.total_publishes = server.total_publishes + 1

  @! P2P Network Announcement
  @if server.config.p2p_enabled == 1
    p2p_announce_provider(server.p2p_registry, name, version, server.config.p2p_peer_id)
  @end

  resp_json = "{"
  resp_json = string_concat(resp_json, string_concat(mpm_json_field("status", "ok"), ","))
  resp_json = string_concat(resp_json, string_concat(mpm_json_field("message", "Package published successfully"), ","))
  resp_json = string_concat(resp_json, string_concat(mpm_json_field("name", name), ","))
  resp_json = string_concat(resp_json, string_concat(mpm_json_field("version", version), ","))
  resp_json = string_concat(resp_json, string_concat(mpm_json_field("cid", cid), ","))
  resp_json = string_concat(resp_json, string_concat(mpm_json_field("sha256", actual_sha), ","))
  resp_json = string_concat(resp_json, string_concat(mpm_json_field("merkle_root", server.merkle_root), ","))
  resp_json = string_concat(resp_json, mpm_json_field_num("published_at", 1756584000))
  resp_json = string_concat(resp_json, "}")

  res_status(res, 201)
  res_json(res, resp_json)
  return res
@end

@fn mpm_server_handle_get_package(server, req, res, name, version_constraint)
  @! Find matching packages for name
  matching_meta = []
  i = 0
  n_pkgs = server.packages.len()
  @while i < n_pkgs
    p = server.packages[i]
    @if p.name == name
      matching_meta = matching_meta.push(p)
    @end
    i = i + 1
  @end

  @if matching_meta.len() == 0
    res_status(res, 404)
    err_nf = string_concat("Package not found: ", name)
    res_json(res, mpm_err_json(err_nf))
    return res
  @end

  @! Resolve Version (SemVer constraint resolution)
  target_meta = 0
  @if version_constraint == "latest" || version_constraint == "*" || version_constraint == ""
    @! Pick highest version
    best_meta = matching_meta[0]
    best_v = p2p_semver_parse(best_meta.version)
    i = 1
    m_len = matching_meta.len()
    @while i < m_len
      cand = matching_meta[i]
      cand_v = p2p_semver_parse(cand.version)
      @if p2p_semver_compare(cand_v, best_v) > 0
        best_meta = cand
        best_v = cand_v
      @end
      i = i + 1
    @end
    target_meta = best_meta
  @elif str_starts_with(version_constraint, "^") || str_starts_with(version_constraint, "~") || str_starts_with(version_constraint, ">=") || str_starts_with(version_constraint, ">") || str_starts_with(version_constraint, "<=") || str_starts_with(version_constraint, "<")
    @! Range resolution
    satisfying = []
    i = 0
    m_len = matching_meta.len()
    @while i < m_len
      cand = matching_meta[i]
      @if p2p_semver_satisfies(cand.version, version_constraint) == 1
        satisfying = satisfying.push(cand)
      @end
      i = i + 1
    @end

    @if satisfying.len() == 0
      res_status(res, 404)
      err_nv = string_concat("No matching version for: ", name)
      res_json(res, mpm_err_json(err_nv))
      return res
    @end

    best_meta = satisfying[0]
    best_v = p2p_semver_parse(best_meta.version)
    i = 1
    s_len = satisfying.len()
    @while i < s_len
      cand = satisfying[i]
      cand_v = p2p_semver_parse(cand.version)
      @if p2p_semver_compare(cand_v, best_v) > 0
        best_meta = cand
        best_v = cand_v
      @end
      i = i + 1
    @end
    target_meta = best_meta
  @else
    @! Exact version match
    i = 0
    m_len = matching_meta.len()
    @while i < m_len
      cand = matching_meta[i]
      @if cand.version == version_constraint
        target_meta = cand
        break
      @end
      i = i + 1
    @end
  @end

  @if target_meta == 0
    res_status(res, 404)
    err_vnf = string_concat("Package version not found: ", name)
    res_json(res, mpm_err_json(err_vnf))
    return res
  @end

  @! Retrieve Blob from Local CAS or P2P Swarm
  blob_data = p2p_cas_get_blob(server.p2p_registry, target_meta.cid)
  @if str_len(blob_data) == 0 && server.config.p2p_enabled == 1
    blob_pkg = p2p_iterative_find_value(server.p2p_registry, server.p2p_swarm, target_meta.cid, 3, 20)
    blob_data = blob_pkg.data
  @end

  @if str_len(blob_data) == 0
    res_status(res, 404)
    err_bnf = string_concat("Package blob not found for CID: ", target_meta.cid)
    res_json(res, mpm_err_json(err_bnf))
    return res
  @end

  @! Update download metrics
  server.total_downloads = server.total_downloads + 1
  target_meta.downloads = target_meta.downloads + 1

  res_status(res, 200)
  res_header(res, "Content-Type", "application/octet-stream")
  res_header(res, "X-Maya-Package-Name", target_meta.name)
  res_header(res, "X-Maya-Package-Version", target_meta.version)
  res_header(res, "X-Maya-Package-CID", target_meta.cid)
  res_header(res, "X-Maya-Package-SHA256", target_meta.sha256)
  res_send(res, blob_data)
  return res
@end

@fn mpm_server_handle_get_index(server, req, res)
  pkg_map = []
  i = 0
  n_pkgs = server.packages.len()

  @! Aggregate by package name
  @while i < n_pkgs
    meta = server.packages[i]
    found = 0
    j = 0
    m_len = pkg_map.len()
    @while j < m_len
      entry = pkg_map[j]
      @if entry.name == meta.name
        entry.versions = entry.versions.push(meta.version)
        entry.total_downloads = entry.total_downloads + meta.downloads
        cand_v = p2p_semver_parse(meta.version)
        best_v = p2p_semver_parse(entry.latest_version)
        @if p2p_semver_compare(cand_v, best_v) > 0
          entry.latest_version = meta.version
          entry.cid = meta.cid
          entry.sha256 = meta.sha256
          entry.description = meta.description
        @end
        found = 1
        break
      @end
      j = j + 1
    @end

    @if found == 0
      new_entry = {
        name: meta.name,
        latest_version: meta.version,
        description: meta.description,
        author: meta.author,
        license: meta.license,
        tags: meta.tags,
        versions: [meta.version],
        cid: meta.cid,
        sha256: meta.sha256,
        total_downloads: meta.downloads
      }
      pkg_map = pkg_map.push(new_entry)
    @end
    i = i + 1
  @end

  @! Build JSON Output
  json_res = "{"
  json_res = string_concat(json_res, string_concat(mpm_json_field("merkle_root", server.merkle_root), ","))
  json_res = string_concat(json_res, string_concat(mpm_json_field_num("total_packages", pkg_map.len()), ","))
  json_res = string_concat(json_res, string_concat(mpm_json_field_num("total_versions", server.packages.len()), ","))
  json_res = string_concat(json_res, string_concat(mpm_json_field_num("updated_at", 1756584000), ","))
  json_res = string_concat(json_res, "\"packages\":[")

  i = 0
  p_len = pkg_map.len()
  @while i < p_len
    p = pkg_map[i]
    @if i > 0 json_res = string_concat(json_res, ",") @end
    json_res = string_concat(json_res, "{")
    json_res = string_concat(json_res, string_concat(mpm_json_field("name", p.name), ","))
    json_res = string_concat(json_res, string_concat(mpm_json_field("latest_version", p.latest_version), ","))
    json_res = string_concat(json_res, string_concat(mpm_json_field("description", p.description), ","))
    json_res = string_concat(json_res, string_concat(mpm_json_field("author", p.author), ","))
    json_res = string_concat(json_res, string_concat(mpm_json_field("license", p.license), ","))
    json_res = string_concat(json_res, string_concat(mpm_json_field("cid", p.cid), ","))
    json_res = string_concat(json_res, string_concat(mpm_json_field("sha256", p.sha256), ","))
    json_res = string_concat(json_res, string_concat(mpm_json_field_num("downloads", p.total_downloads), ","))
    json_res = string_concat(json_res, "\"versions\":[")
    v_idx = 0
    v_len = p.versions.len()
    @while v_idx < v_len
      @if v_idx > 0 json_res = string_concat(json_res, ",") @end
      json_res = string_concat(json_res, "\"")
      json_res = string_concat(json_res, mpm_escape_json(p.versions[v_idx]))
      json_res = string_concat(json_res, "\"")
      v_idx = v_idx + 1
    @end
    json_res = string_concat(json_res, "]}")
    i = i + 1
  @end

  json_res = string_concat(json_res, "]}")

  res_status(res, 200)
  res_json(res, json_res)
  return res
@end

@fn mpm_server_handle_search(server, req, res)
  query = req_query(req, "q", "")
  @if str_len(query) == 0
    q_src = req.req_query_string
    @if str_len(q_src) == 0
      q_src = req.req_path
    @end
    q_pos = str_index_of(q_src, "q=")
    @if q_pos >= 0
      query = str_substr(q_src, q_pos + 2, str_len(q_src))
      amp_pos = str_index_of(query, "&")
      @if amp_pos >= 0
        query = str_substr(query, 0, amp_pos)
      @end
    @end
  @end

  q_lower = str_to_lower(query)
  results_json = ""
  match_count = 0
  i = 0
  n_pkgs = server.packages.len()
  @while i < n_pkgs
    p = server.packages[i]
    is_match = 0
    @if str_len(q_lower) == 0
      is_match = 1
    @else
      @if str_contains(str_to_lower(p.name), q_lower) == 1
        is_match = 1
      @elif str_contains(str_to_lower(p.description), q_lower) == 1
        is_match = 1
      @elif str_contains(str_to_lower(p.author), q_lower) == 1
        is_match = 1
      @else
        @! Tag search
        t_idx = 0
        t_len = p.tags.len()
        @while t_idx < t_len
          tag_str = p.tags[t_idx]
          @if str_contains(str_to_lower(tag_str), q_lower) == 1
            is_match = 1
            break
          @end
          t_idx = t_idx + 1
        @end
      @end
    @end

    @if is_match == 1
      @if match_count > 0 results_json = string_concat(results_json, ",") @end
      results_json = string_concat(results_json, "{")
      results_json = string_concat(results_json, string_concat(mpm_json_field("name", p.name), ","))
      results_json = string_concat(results_json, string_concat(mpm_json_field("version", p.version), ","))
      results_json = string_concat(results_json, string_concat(mpm_json_field("description", p.description), ","))
      results_json = string_concat(results_json, string_concat(mpm_json_field("author", p.author), ","))
      results_json = string_concat(results_json, string_concat(mpm_json_field("license", p.license), ","))
      results_json = string_concat(results_json, string_concat(mpm_json_field("cid", p.cid), ","))
      results_json = string_concat(results_json, string_concat(mpm_json_field("sha256", p.sha256), ","))
      results_json = string_concat(results_json, string_concat(mpm_json_field_num("downloads", p.downloads), ","))
      results_json = string_concat(results_json, "\"tags\":[")
      t_idx = 0
      t_len = p.tags.len()
      @while t_idx < t_len
        @if t_idx > 0 results_json = string_concat(results_json, ",") @end
        results_json = string_concat(results_json, "\"")
        results_json = string_concat(results_json, mpm_escape_json(p.tags[t_idx]))
        results_json = string_concat(results_json, "\"")
        t_idx = t_idx + 1
      @end
      results_json = string_concat(results_json, "]}")
      match_count = match_count + 1
    @end
    i = i + 1
  @end

  json_res = "{"
  json_res = string_concat(json_res, string_concat(mpm_json_field("query", query), ","))
  json_res = string_concat(json_res, string_concat(mpm_json_field_num("count", match_count), ","))
  json_res = string_concat(json_res, "\"results\":[")
  json_res = string_concat(json_res, results_json)
  json_res = string_concat(json_res, "]}")

  res_status(res, 200)
  res_json(res, json_res)
  return res
@end

@! ============================================================================
@! 5. REQUEST ROUTER & DISPATCH PIPELINE
@! ============================================================================

@fn mpm_server_handle_request(server, req)
  res = res_new()
  server.total_requests = server.total_requests + 1

  path = req.req_path
  method = req.req_method

  @! Normalize clean path (strip trailing slash and query params)
  q_idx = str_index_of(path, "?")
  @if q_idx >= 0
    path = str_substr(path, 0, q_idx)
  @end

  @! Route 1: POST /api/v1/publish
  @if str_eq(path, "/api/v1/publish") == 1
    @if str_eq(method, "POST") == 1
      return mpm_server_handle_publish(server, req, res)
    @else
      res_status(res, 405)
      res_header(res, "Allow", "POST")
      res_text(res, "405 Method Not Allowed")
      return res
    @end
  @end

  @! Route 2: GET /api/v1/index
  @if str_eq(path, "/api/v1/index") == 1
    @if str_eq(method, "GET") == 1
      return mpm_server_handle_get_index(server, req, res)
    @else
      res_status(res, 405)
      res_header(res, "Allow", "GET")
      res_text(res, "405 Method Not Allowed")
      return res
    @end
  @end

  @! Route 3: GET /api/v1/search
  @if str_eq(path, "/api/v1/search") == 1
    @if str_eq(method, "GET") == 1
      return mpm_server_handle_search(server, req, res)
    @else
      res_status(res, 405)
      res_header(res, "Allow", "GET")
      res_text(res, "405 Method Not Allowed")
      return res
    @end
  @end

  @! Route 4: GET /api/v1/packages/{name}/{version}
  @if str_starts_with(path, "/api/v1/packages/") == 1
    rest = str_substr(path, 17, str_len(path))
    slash_pos = str_index_of(rest, "/")
    @if slash_pos >= 0
      name = str_substr(rest, 0, slash_pos)
      version = str_substr(rest, slash_pos + 1, str_len(rest))
      @if str_eq(method, "GET") == 1
        return mpm_server_handle_get_package(server, req, res, name, version)
      @else
        res_status(res, 405)
        res_header(res, "Allow", "GET")
        res_text(res, "405 Method Not Allowed")
        return res
      @end
    @end
  @end

  res_status(res, 404)
  res_text(res, "404 Not Found")
  return res
@end

@fn mpm_server_dispatch(server, req)
  return mpm_server_handle_request(server, req)
@end

@fn mpm_server_handle_raw_request(server, raw_req_str)
  parsed = http_parse_request(raw_req_str)
  req = req_new(parsed.method, parsed.path, parsed.headers, parsed.body, "127.0.0.1")
  res = mpm_server_dispatch(server, req)
  return res_format_http(res)
@end

@! ============================================================================
@! 6. SERVER LIFECYCLE & TCP CONTAINER
@! ============================================================================

@fn mpm_server_handle_connection(server, stream)
  raw_req = tcp_stream_read(stream, 65536)
  @if str_len(raw_req) > 0
    parsed = http_parse_request(raw_req)
    req = req_new(parsed.method, parsed.path, parsed.headers, parsed.body, stream.peer_host)
    res = mpm_server_dispatch(server, req)
    wire_resp = res_format_http(res)
    tcp_stream_write(stream, wire_resp)
  @end
  tcp_stream_close(stream)
@end

@fn mpm_server_listen(server, host, port)
  listener = tcp_listener_bind(host, port)
  @if listener.fd < 0
    err_bind = string_concat("Failed to bind MPM Server on ", host)
    err_bind = string_concat(err_bind, ":")
    err_bind = string_concat(err_bind, to_str(port))
    println(err_bind)
    return -1
  @end

  server.is_running = 1
  @while server.is_running == 1
    stream = tcp_listener_accept(listener)
    @if stream.fd >= 0
      mpm_server_handle_connection(server, stream)
    @end
  @end

  tcp_close(listener.fd)
  return 0
@end

@fn mpm_server_listen_limited(server, host, port, max_requests)
  listener = tcp_listener_bind(host, port)
  @if listener.fd < 0
    println("Failed to bind MPM Server on " + host + ":" + port.to_str())
    return -1
  @end

  server.is_running = 1
  count = 0
  @while server.is_running == 1
    stream = tcp_listener_accept(listener)
    @if stream.fd >= 0
      mpm_server_handle_connection(server, stream)
      count = count + 1
      @if max_requests > 0 && count >= max_requests
        server.is_running = 0
      @end
    @end
  @end

  tcp_close(listener.fd)
  return 0
@end

@fn mpm_server_stop(server)
  server.is_running = 0
  @if server.web_server != 0
    web_server_stop(server.web_server)
  @end
@end

@! ============================================================================
@! 7. P2P MERKLE DAG MULTI-NODE SYNCHRONIZATION
@! ============================================================================

@fn mpm_server_sync_p2p(server_a, server_b)
  @! 1. Synchronize P2P registries and CAS stores
  synced = p2p_sync_merkle_dag(server_a.p2p_registry, server_b.p2p_registry)

  @! 2. Sync PackageMeta collections (A -> B)
  pkgs_a = server_a.packages
  n_a = pkgs_a.len()
  i = 0
  @while i < n_a
    pa = pkgs_a[i]
    exists_in_b = 0
    j = 0
    pkgs_b = server_b.packages
    n_b = pkgs_b.len()
    @while j < n_b
      pb = pkgs_b[j]
      @if pb.name == pa.name && pb.version == pa.version
        exists_in_b = 1
        break
      @end
      j = j + 1
    @end

    @if exists_in_b == 0
      server_b.packages = server_b.packages.push(pa)
    @end
    i = i + 1
  @end

  @! 3. Sync PackageMeta collections (B -> A)
  pkgs_b = server_b.packages
  n_b = pkgs_b.len()
  i = 0
  @while i < n_b
    pb = pkgs_b[i]
    exists_in_a = 0
    j = 0
    pkgs_a = server_a.packages
    n_a = pkgs_a.len()
    @while j < n_a
      pa = pkgs_a[j]
      @if pa.name == pb.name && pa.version == pb.version
        exists_in_a = 1
        break
      @end
      j = j + 1
    @end

    @if exists_in_a == 0
      server_a.packages = server_a.packages.push(pb)
    @end
    i = i + 1
  @end

  @! 4. Recompute Merkle DAG root hashes
  server_a.merkle_root = p2p_compute_merkle_root(server_a.p2p_registry)
  server_b.merkle_root = p2p_compute_merkle_root(server_b.p2p_registry)

  return synced
@end

@! ============================================================================
@! 8. PURE MAYA SCRIPTABLE CLIENT API
@! ============================================================================

@fn mpm_client_publish(target, manifest_data, payload)
  actual_sha = sha256_hex_string(payload)
  
  name = manifest_data.name
  version = manifest_data.version
  desc = manifest_data.description
  author = manifest_data.author
  license = manifest_data.license
  tags = manifest_data.tags

  req_body = "{"
  f1 = mpm_json_field("name", name)
  req_body = string_concat(req_body, f1)
  req_body = string_concat(req_body, ",")
  f2 = mpm_json_field("version", version)
  req_body = string_concat(req_body, f2)
  req_body = string_concat(req_body, ",")
  f3 = mpm_json_field("description", desc)
  req_body = string_concat(req_body, f3)
  req_body = string_concat(req_body, ",")
  f4 = mpm_json_field("author", author)
  req_body = string_concat(req_body, f4)
  req_body = string_concat(req_body, ",")
  f5 = mpm_json_field("license", license)
  req_body = string_concat(req_body, f5)
  req_body = string_concat(req_body, ",")
  f6 = mpm_json_field("payload", payload)
  req_body = string_concat(req_body, f6)
  req_body = string_concat(req_body, ",")
  f7 = mpm_json_field("sha256", actual_sha)
  req_body = string_concat(req_body, f7)
  req_body = string_concat(req_body, ",")
  req_body = string_concat(req_body, "\"tags\":[")
  t_i = 0
  t_len = tags.len()
  @while t_i < t_len
    @if t_i > 0 req_body = string_concat(req_body, ",") @end
    esc_tag = mpm_escape_json(tags[t_i])
    req_body = string_concat(req_body, "\"")
    req_body = string_concat(req_body, esc_tag)
    req_body = string_concat(req_body, "\"")
    t_i = t_i + 1
  @end
  req_body = string_concat(req_body, "]}")

  @! If target is string URL
  @if str_starts_with(target, "http://") || str_starts_with(target, "https://")
    hdrs = [{ name: "Content-Type", value: "application/json" }]
    pub_url = string_concat(target, "/api/v1/publish")
    resp = http_post(pub_url, hdrs, req_body)
    is_ver = 0
    @if resp.status_code == 201 is_ver = 1 @end
    return {
      status_code: resp.status_code,
      body: resp.body,
      sha256: actual_sha,
      verified: is_ver
    }
  @end

  @! Direct in-memory server dispatch
  req = req_new("POST", "/api/v1/publish", [{ name: "Content-Type", value: "application/json" }], req_body, "127.0.0.1")
  res = mpm_server_dispatch(target, req)
  is_ver = 0
  @if res.res_status_code == 201 is_ver = 1 @end
  return {
    status_code: res.res_status_code,
    body: res.res_body,
    sha256: actual_sha,
    verified: is_ver
  }
@end

@fn mpm_client_fetch(target, name, version_constraint)
  t1 = string_concat("/api/v1/packages/", name)
  t2 = string_concat(t1, "/")
  subpath = string_concat(t2, version_constraint)

  @! Network HTTP Fetch
  @if str_starts_with(target, "http://") || str_starts_with(target, "https://")
    fetch_url = string_concat(target, subpath)
    resp = http_get(fetch_url)
    expected_sha = ""
    i = 0
    h_len = resp.headers.len()
    @while i < h_len
      h = resp.headers[i]
      @if str_to_lower(h.name) == "x-maya-package-sha256"
        expected_sha = h.value
        break
      @end
      i = i + 1
    @end

    actual_sha = sha256_hex_string(resp.body)
    is_valid = 0
    @if resp.status_code == 200 is_valid = 1 @end
    @if str_len(expected_sha) > 0 && str_to_lower(expected_sha) != str_to_lower(actual_sha)
      is_valid = 0
    @end

    return {
      status_code: resp.status_code,
      payload: resp.body,
      sha256: actual_sha,
      expected_sha: expected_sha,
      verified: is_valid
    }
  @end

  @! Direct in-memory server dispatch
  req = req_new("GET", subpath, [], "", "127.0.0.1")
  res = mpm_server_dispatch(target, req)
  expected_sha = res_get_header(res, "X-Maya-Package-SHA256", "")
  actual_sha = sha256_hex_string(res.res_body)

  is_valid = 0
  @if res.res_status_code == 200 is_valid = 1 @end
  @if str_len(expected_sha) > 0 && str_to_lower(expected_sha) != str_to_lower(actual_sha)
    is_valid = 0
  @end

  return {
    status_code: res.res_status_code,
    payload: res.res_body,
    sha256: actual_sha,
    expected_sha: expected_sha,
    verified: is_valid
  }
@end

@fn mpm_client_get_index(target)
  subpath = "/api/v1/index"
  @if str_starts_with(target, "http://") || str_starts_with(target, "https://")
    idx_url = string_concat(target, subpath)
    resp = http_get(idx_url)
    return { status_code: resp.status_code, body: resp.body }
  @end

  req = req_new("GET", subpath, [], "", "127.0.0.1")
  res = mpm_server_dispatch(target, req)
  return { status_code: res.res_status_code, body: res.res_body }
@end

@fn mpm_client_search(target, query)
  subpath = string_concat("/api/v1/search?q=", query)
  @if str_starts_with(target, "http://") || str_starts_with(target, "https://")
    srch_url = string_concat(target, subpath)
    resp = http_get(srch_url)
    return { status_code: resp.status_code, body: resp.body }
  @end

  req = req_new("GET", subpath, [], "", "127.0.0.1")
  res = mpm_server_dispatch(target, req)
  return { status_code: res.res_status_code, body: res.res_body }
@end