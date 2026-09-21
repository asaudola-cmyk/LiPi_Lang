@! ============================================================================
@! 👑 LIPI UNIVERSAL ARCHITECTURE — DECENTRALIZED LIPIPKG PACKAGE SERVER & REGISTRY
@! Module: universe/p2p/lipipkg_server.lp
@! Milestone: 100% Sovereign Lipi Package Ecosystem
@! 100% Pure Lipi Implementation — Zero External / C Dependencies
@! Features: Full HTTP REST Server, P2P CAS Storage, Merkle DAG Sync,
@! SemVer 2.0.0 Constraint Resolution, Cryptographic Verification, Client API
@! ============================================================================

import "universe/p2p/lipipkg_server_engine"

// WHY: Provides canonical Lipi-branded naming while preserving full interoperability.
@fn lipipkg_server_config_default()
  return mpm_server_config_default()
@end

@fn lipipkg_server_new(config)
  return mpm_server_new(config)
@end

@fn lipipkg_server_handle_publish(server, req, res)
  return mpm_server_handle_publish(server, req, res)
@end

@fn lipipkg_server_handle_get_package(server, req, res, name, version_constraint)
  return mpm_server_handle_get_package(server, req, res, name, version_constraint)
@end

@fn lipipkg_server_handle_get_index(server, req, res)
  return mpm_server_handle_get_index(server, req, res)
@end

@fn lipipkg_server_handle_search(server, req, res)
  return mpm_server_handle_search(server, req, res)
@end

@fn lipipkg_server_handle_request(server, req)
  return mpm_server_handle_request(server, req)
@end

@fn lipipkg_server_dispatch(server, req)
  return mpm_server_dispatch(server, req)
@end

@fn lipipkg_server_listen(server, host, port)
  return mpm_server_listen(server, host, port)
@end

@fn lipipkg_server_listen_limited(server, host, port, max_requests)
  return mpm_server_listen_limited(server, host, port, max_requests)
@end

@fn lipipkg_server_stop(server)
  return mpm_server_stop(server)
@end

@fn lipipkg_client_publish(target, manifest_data, payload)
  return mpm_client_publish(target, manifest_data, payload)
@end

@fn lipipkg_client_fetch(target, name, version_constraint)
  return mpm_client_fetch(target, name, version_constraint)
@end

@fn lipipkg_client_get_index(target)
  return mpm_client_get_index(target)
@end

@fn lipipkg_client_search(target, query)
  return mpm_client_search(target, query)
@end
