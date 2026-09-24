@! ============================================================================
@! 👑 LIPI UNIVERSAL ARCHITECTURE — DECENTRALIZED LIPIPKG PACKAGE SERVER & REGISTRY
@! Module: universe/p2p/lipipkg_server.lp
@! Milestone: 100% Sovereign Lipi Package Ecosystem
@! 100% Pure Lipi Implementation — Zero External / C Dependencies
@! Features: Full HTTP REST Server, P2P CAS Storage, Merkle DAG Sync,
@! SemVer 2.0.0 Constraint Resolution, Cryptographic Verification, Client API
@! ============================================================================

import "universe/p2p/lipipkg_server_engine"
import "universe/p2p/lipipkg_client"

// WHY: Provides canonical Lipi-branded naming for package server configurations
@fn lipipkg_server_config_default()
  return lipipkg_server_config_default()
@end

// WHY: Allocates and initializes sovereign LipiPkg server state
@fn lipipkg_server_new(config)
  return lipipkg_server_new(config)
@end

// WHY: Handles package publishing endpoint with cryptographic checksum verification
@fn lipipkg_server_handle_publish(server, req, res)
  return lipipkg_server_handle_publish(server, req, res)
@end

// WHY: Handles package resolution and retrieval by SemVer constraint
@fn lipipkg_server_handle_get_package(server, req, res, name, version_constraint)
  return lipipkg_server_handle_get_package(server, req, res, name, version_constraint)
@end

// WHY: Exposes package index catalog
@fn lipipkg_server_handle_get_index(server, req, res)
  return lipipkg_server_handle_get_index(server, req, res)
@end

// WHY: Search query handling across package index
@fn lipipkg_server_handle_search(server, req, res)
  return lipipkg_server_handle_search(server, req, res)
@end

// WHY: Master request router handling all HTTP routes
@fn lipipkg_server_handle_request(server, req)
  return lipipkg_server_handle_request(server, req)
@end

// WHY: Direct in-memory request dispatcher
@fn lipipkg_server_dispatch(server, req)
  return lipipkg_server_dispatch(server, req)
@end

// WHY: Binds TCP socket listener for live HTTP serving
@fn lipipkg_server_listen(server, host, port)
  return lipipkg_server_listen(server, host, port)
@end

// WHY: Binds limited request listener for tests and microservices
@fn lipipkg_server_listen_limited(server, host, port, max_requests)
  return lipipkg_server_listen_limited(server, host, port, max_requests)
@end

// WHY: Gracefully stops running server instance
@fn lipipkg_server_stop(server)
  return lipipkg_server_stop(server)
@end

// WHY: Client API: Publishes package manifest and payload
@fn lipipkg_client_publish(target, manifest_data, payload)
  return lipipkg_client_publish(target, manifest_data, payload)
@end

// WHY: Client API: Fetches package by name and SemVer constraint
@fn lipipkg_client_fetch(target, name, version_constraint)
  return lipipkg_client_fetch(target, name, version_constraint)
@end

// WHY: Client API: Retrieves full registry index
@fn lipipkg_client_get_index(target)
  return lipipkg_client_get_index(target)
@end

// WHY: Client API: Searches registry packages by keyword query
@fn lipipkg_client_search(target, query)
  return lipipkg_client_search(target, query)
@end
