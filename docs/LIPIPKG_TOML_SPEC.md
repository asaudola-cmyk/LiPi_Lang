# ==============================================================================
# 📋 lipipkg.toml — লিপি প্যাকেজ ম্যানিফেস্ট স্পেসিফিকেশন
# লিপি প্রথম ১.০.০ | First 1.0.0 Sovereign
# File: docs/LIPIPKG_TOML_SPEC.md
#
# এই ডকুমেন্ট lipipkg.toml ফরম্যাটের সম্পূর্ণ স্পেসিফিকেশন।
# Cargo.toml (Rust) এবং package.json (Node.js) থেকে অনুপ্রাণিত।
# ==============================================================================

# লিপি প্যাকেজ ম্যানিফেস্ট স্পেসিফিকেশন (lipipkg.toml)

> **সংস্করণ:** প্রথম ১.০.০ (First 1.0.0)  
> **সংকেতনাম:** সোভেরিন  
> **ফরম্যাট:** TOML (Tom's Obvious, Minimal Language)

---

## সম্পূর্ণ উদাহরণ

```toml
# ==============================================================
# lipipkg.toml — লিপি প্যাকেজ ম্যানিফেস্ট
# ==============================================================

# ─── [প্যাকেজ] section — প্রয়োজনীয় ──────────────────────────
[প্যাকেজ]
নাম        = "my-awesome-app"          # প্যাকেজ নাম (lowercase, hyphens only)
সংস্করণ    = "১.০.০"                   # Semantic versioning (বাংলা সংখ্যা OK)
লেখক       = "রফিক আহমেদ"             # লেখকের নাম
ইমেইল      = "rafiq@example.com"       # যোগাযোগ
বিবরণ      = "আমার সার্বভৌম অ্যাপ"    # সংক্ষিপ্ত বিবরণ
লাইসেন্স   = "MIT"                     # SPDX license identifier
প্রধান      = "src/main.lp"            # entry point file
বিভাগ      = ["cli", "network"]        # package categories
কীওয়ার্ড   = ["লিপি", "সার্বভৌম"]     # search keywords

# ─── [নির্ভরতা] section — নির্ভরতাসমূহ ─────────────────────────
[নির্ভরতা]
std         = "প্রথম ১.০"              # built-in stdlib (always available)
std/http    = "২.০"                    # HTTP framework
std/cli     = "১.০"                    # CLI argument parser
std/fmt     = "১.০"                    # String formatting
std/crypto  = "১.৫"                    # Cryptography (SHA-256, ChaCha20)
std/db      = "১.০"                    # Sovereign DB engine
std/ai      = "১.০"                    # GGUF AI inference

# ─── [dev-নির্ভরতা] section — শুধু development এ ───────────────
[dev-নির্ভরতা]
std/test    = "১.০"                    # Testing framework
std/bench   = "১.০"                    # Benchmarking

# ─── [বৈশিষ্ট্য] section — conditional compilation ──────────────
[বৈশিষ্ট্য]
default     = ["http", "cli"]          # enabled by default
http        = ["std/http"]             # optional HTTP support
ai          = ["std/ai"]               # optional AI support
full        = ["http", "ai", "db"]     # full feature set

# ─── [প্রোফাইল.release] section — build optimization ───────────
[প্রোফাইল.release]
অপ্টিমাইজেশন = "সর্বোচ্চ"            # optimization level
ডিবাগ_তথ্য   = মিথ্যা                # strip debug info
strip        = সত্য                   # strip symbols from binary

[প্রোফাইল.debug]
অপ্টিমাইজেশন = "শূন্য"               # no optimization for fast compile
ডিবাগ_তথ্য   = সত্য                  # include debug info

# ─── [লক্ষ্য] section — cross-compilation ──────────────────────
[লক্ষ্য]
linux-x86_64   = সত্য                 # Default: Linux x86_64 (ELF64)
windows-x86_64 = মিথ্যা               # Future: Windows PE
macos-arm64    = মিথ্যা               # Future: macOS ARM64
android-arm64  = মিথ্যা               # Future: Android

# ─── [workspace] section — mono-repo support ────────────────────
[workspace]
সদস্য = [
    "crates/core",
    "crates/http",
    "crates/cli",
    "apps/website"
]

# ─── [স্ক্রিপ্ট] section — custom commands ──────────────────────
[স্ক্রিপ্ট]
build        = "scripts/build.sh"
test         = "scripts/run_tests.sh"
release      = "scripts/package_release.sh"
install      = "scripts/install.sh"

# ─── [রেজিস্ট্রি] section — registry configuration ────────────
[রেজিস্ট্রি]
url          = "https://pkg.lipi.dev"  # Default registry
timeout      = ৩০                      # Request timeout in seconds
```

---

## ক্ষেত্র বিবরণ

### [প্যাকেজ] section (প্রয়োজনীয়)

| ক্ষেত্র | ধরন | প্রয়োজনীয় | বিবরণ |
|--------|------|------------|-------|
| `নাম` | String | ✅ | প্যাকেজের unique নাম (lowercase, hyphens allowed) |
| `সংস্করণ` | SemVer | ✅ | Semantic version (`১.০.০` বা `1.0.0`) |
| `লেখক` | String | ✅ | লেখকের নাম |
| `বিবরণ` | String | ✅ | সংক্ষিপ্ত বিবরণ (≤ 256 chars) |
| `প্রধান` | Path | ✅ | Entry point `.lp` file |
| `লাইসেন্স` | SPDX | ❌ | License identifier (`MIT`, `Apache-2.0`) |
| `ইমেইল` | Email | ❌ | লেখকের ইমেইল |
| `বিভাগ` | List | ❌ | Package categories |
| `কীওয়ার্ড` | List | ❌ | Search keywords (≤ 5) |

### [নির্ভরতা] section

```toml
[নির্ভরতা]
# Built-in std packages (always available, no download needed)
std         = "প্রথম ১.০"

# Registry packages (downloaded from pkg.lipi.dev)
http-client = "২.১.০"

# Local path packages (for development)
my-lib      = { path = "../my-lib" }

# Git packages
utils       = { git = "https://github.com/user/lipi-utils" }

# With specific features enabled
crypto      = { version = "১.৫", বৈশিষ্ট্য = ["sha256", "aes"] }
```

### Version Specifiers

| Specifier | মানে |
|-----------|------|
| `"১.০.০"` | Exact version |
| `"^১.০.০"` | Compatible: ≥1.0.0 <2.0.0 |
| `"~১.০.০"` | Patch: ≥1.0.0 <1.1.0 |
| `">= ১.০"` | Minimum version |
| `"*"` | Any version |
| `"প্রথম ১.০"` | Bengali version (Lipi native) |

---

## lipipkg কমান্ড রেফারেন্স

```bash
# নতুন প্রজেক্ট
lipipkg init my-app          # স্ক্যাফোল্ড create করে
lipipkg new --lib my-lib     # library প্রজেক্ট

# Build
lipipkg build                # debug build
lipipkg build --release      # optimized release build
lipipkg build --target linux-x86_64

# Run
lipipkg run                  # build + run
lipipkg run -- --port 8080   # pass args to program

# Test
lipipkg test                 # all tests
lipipkg test 43              # specific test number
lipipkg test --verbose       # verbose output

# Dependency management
lipipkg add std/http         # latest version
lipipkg add crypto@1.5       # specific version
lipipkg remove crypto        # remove dependency
lipipkg update               # update all deps
lipipkg tree                 # show dependency tree

# Publishing
lipipkg login                # authenticate to pkg.lipi.dev
lipipkg publish              # publish to registry
lipipkg yank 1.0.0           # un-publish a version

# Info
lipipkg search http          # search registry
lipipkg info std/http        # package details
lipipkg version              # toolchain version
lipipkg doctor               # check environment
```

---

## ফাইল কাঠামো

```
my-app/
├── lipipkg.toml            # ম্যানিফেস্ট (required)
├── lipipkg.lock            # lock file (auto-generated)
├── src/
│   └── main.lp             # entry point
├── tests/
│   ├── 01_basic.lp
│   └── 02_advanced.lp
├── examples/
│   └── hello.lp
├── build/                  # compiled artifacts
├── docs/
│   └── README.md
└── .lipi-ignore            # files to exclude from publish
```

---

## lipipkg.lock ফরম্যাট

```toml
# lipipkg.lock — auto-generated, do NOT edit manually
# WHY: Lockfile ensures reproducible builds across machines

[metadata]
লিপি_সংস্করণ = "প্রথম ১.০"
উৎপন্ন_তারিখ = "২০২৬-০৯-০৯"

[[package]]
নাম         = "std/http"
সংস্করণ     = "২.০.১"
checksum    = "sha256:abc123def456..."
উৎস         = "https://pkg.lipi.dev/std/http/2.0.1"

[[package]]
নাম         = "std/crypto"
সংস্করণ     = "১.৫.৩"
checksum    = "sha256:xyz789..."
উৎস         = "https://pkg.lipi.dev/std/crypto/1.5.3"
```

---

## সামঞ্জস্যতা

| lipipkg সংস্করণ | লিপি সংস্করণ | অবস্থা |
|----------------|-------------|--------|
| প্রথম ১.০.০    | প্রথম ১.০.০ | ✅ বর্তমান (Current) |

---

> **🔖 সংস্করণ:** প্রথম ১.০.০ (First 1.0.0) — সোভেরিন  
> **📅 তারিখ:** ২০২৬-০৯-১৩  
> **🔒 Lock:** সংস্করণ পরিবর্তন হবে না যতক্ষণ ব্যবহারকারী অনুমতি না দেয়
