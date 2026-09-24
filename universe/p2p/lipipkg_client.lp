@! ============================================================================
@! 👑 LIPI UNIVERSAL ARCHITECTURE — LIPIPKG SCRIPTABLE CLIENT API
@! Module: universe/p2p/lipipkg_client.lp
@! Milestone: 100% Sovereign Lipi Package Ecosystem
@! 100% Pure Lipi Implementation — Zero External / C Dependencies
@! Features: Publish, Fetch, Index, and Search against HTTP & In-Memory Registry
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/sha256"
import "universe/net/http"
import "universe/web/context"
import "universe/p2p/lipipkg_server_engine"

// WHY: Publishes package payload to network HTTP server or in-memory registry instance
@fn lipipkg_client_publish(target, manifest_data, payload)
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
  res = lipipkg_server_dispatch(target, req)
  is_ver = 0
  @if res.res_status_code == 201 is_ver = 1 @end
  return {
    status_code: res.res_status_code,
    body: res.res_body,
    sha256: actual_sha,
    verified: is_ver
  }
@end

// WHY: Fetches package payload by name and SemVer constraint, verifying cryptographic SHA-256 integrity
@fn lipipkg_client_fetch(target, name, version_constraint)
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
      // WHY: Checks official X-Lipi-Package-SHA256 and falls back to legacy X-Maya-Package-SHA256
      @if str_to_lower(h.name) == "x-lipi-package-sha256" || str_to_lower(h.name) == "x-maya-package-sha256"
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
  res = lipipkg_server_dispatch(target, req)
  // WHY: Retrieves sovereign X-Lipi-Package-SHA256 with legacy fallback
  expected_sha = res_get_header(res, "X-Lipi-Package-SHA256", "")
  @if str_len(expected_sha) == 0
    expected_sha = res_get_header(res, "X-Maya-Package-SHA256", "")
  @end
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

// WHY: Fetches package index catalog from remote registry endpoint or in-memory server
@fn lipipkg_client_get_index(target)
  subpath = "/api/v1/index"
  @if str_starts_with(target, "http://") || str_starts_with(target, "https://")
    idx_url = string_concat(target, subpath)
    resp = http_get(idx_url)
    return { status_code: resp.status_code, body: resp.body }
  @end

  req = req_new("GET", subpath, [], "", "127.0.0.1")
  res = lipipkg_server_dispatch(target, req)
  return { status_code: res.res_status_code, body: res.res_body }
@end

// WHY: Queries package registry index using substring search
@fn lipipkg_client_search(target, query)
  subpath = string_concat("/api/v1/search?q=", query)
  @if str_starts_with(target, "http://") || str_starts_with(target, "https://")
    srch_url = string_concat(target, subpath)
    resp = http_get(srch_url)
    return { status_code: resp.status_code, body: resp.body }
  @end

  req = req_new("GET", subpath, [], "", "127.0.0.1")
  res = lipipkg_server_dispatch(target, req)
  return { status_code: res.res_status_code, body: res.res_body }
@end

// ── Backward-Compatibility Aliases ──────────────────────────────────────────
@fn mpm_client_publish(target, manifest_data, payload)
  return lipipkg_client_publish(target, manifest_data, payload)
@end

@fn mpm_client_fetch(target, name, version_constraint)
  return lipipkg_client_fetch(target, name, version_constraint)
@end

@fn mpm_client_get_index(target)
  return lipipkg_client_get_index(target)
@end

@fn mpm_client_search(target, query)
  return lipipkg_client_search(target, query)
@end
