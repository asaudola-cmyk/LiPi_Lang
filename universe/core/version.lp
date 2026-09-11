// std/version.lp — Lipi 2.0 Version Information
// LOCKED: Lipi First 1.0 Sovereign

VERSION_NAME     = "First 1.0"
VERSION_CODE     = "1.0.0"
CODENAME         = "Sovereign"
RUNTIME_VERSION  = "1.0.0"
RUNTIME_ENGINE   = "lipc"
LANGUAGE         = "Lipi"
AUTHOR           = "Lipi Language Project"
LICENSE          = "MIT"
UNICODE_SUPPORT  = 1
GLOBAL_STANDARD  = 1

fn version_string = "Lipi " + VERSION_NAME + " (\" + CODENAME + "\")"
fn runtime_string = "lipc " + RUNTIME_VERSION + " (Native Sovereign Toolchain)"

say "Lipi First 1.0 - Sovereign"
say "Runtime: lipc 1.0.0 (Native Sovereign Toolchain)"
say "Global Standard: enabled"
say "Unicode: enabled"
