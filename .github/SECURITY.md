# Security Policy

## Supported Versions

Security fixes are applied to the `main` branch and latest `1.0.x` release.

## Security Architecture

- **Static-PIE & W^X (`0 RWE`)**: Compiled Linux ELF64 executables contain zero `RWE` segments and do not dynamically link external shared libraries.
- **Static Safety (`--kavach`)**: Optional compile-time ownership/leak checking and `silicon_*` / `সিলিকন_*` hardware boundary enforcement for raw `syscall`/`mem_write` primitives.
- **W^X Code Loading**: `utso/core/kavach_capsule.lp` enforces Ed25519 signature checks and `RW` → `RX` `mprotect` transitions; `utso/core/ffi_sovereign.lp` maps `PT_LOAD` segments strictly without `RWX`.
- **TLS 1.3 & X.509 PKI**: `utso/net/tls/tls13.lp` and `utso/crypto/x509.lp` enforce RFC 5280 chain validation, RFC 6125 hostname matching (with TLD wildcard rejection), and cryptographic `CertificateVerify` across Ed25519, ECDSA P-256/P-384, and RSA-PSS.
- **Package Integrity**: `aati` signs package manifests with Ed25519 and verifies `aati.lock` digests across all 31 packages in `aati/`.

## Reporting a Vulnerability

Please do not open public issues for unpatched security vulnerabilities. Instead, use GitHub Private Vulnerability Reporting (Security Advisories) on the repository with:

- Affected file path(s) and commit hash
- Minimal reproduction steps or `.lp` test case
- Impact description and suggested fix (if known)
