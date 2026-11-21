# pkgx.sh — "Run anything" (pkgxdev/pkgx). A FRAGMENT until now: it named xz on
# darwin and took its source, versions, build and test from the upstream pantry
# merged underneath. That merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so
# this is the WHOLE recipe, written from pkgx's own files (go-zpkg/packages#431,
# #440 step 1), at 2.11.1. virtualenv.pypa.io depends on it.
#
# ⭐ WHAT WRITING IT FOUND, measured with `cargo tree --locked -p pkgx -i <crate>
# --target <triple>` on the 2.11.1 tag:
#   - LINUX COMPILES OPENSSL IN. crates/cli/Cargo.toml:28 asks native-tls with
#     `vendored` on every non-macOS target, so openssl-src 300.4.1+3.4.0 (OpenSSL
#     3.4.0) is built by the crate's own script: it needs perl and make, and it
#     leaves no libssl dependency. No openssl.org dependency is declared.
#   - DARWIN HAS NO openssl-sys AT ALL (the same query prints "nothing to print"
#     for aarch64-apple-darwin); TLS is rustls with AWS-LC (aws-lc-sys 0.39.0,
#     compiled in) on both platforms, through reqwest 0.13.
#   - SQLite: bundled on non-macOS (crates/cli/Cargo.toml:27, lib:36); on darwin
#     libsqlite3-sys 0.37.0 links the system sqlite3, which the SDK provides.
#   - liblzma: lzma-sys 0.1.20 (via xz2, async-compression) probes pkg-config
#     for liblzma and compiles its own copy only when that fails
#     (build.rs:12-21). xz is declared on BOTH platforms, so the probe finds it;
#     the fragment named it on darwin only.

summary = "pkgx: run anything"

# crates/cli/Cargo.toml:5 license = "Apache-2.0"; LICENSE.txt is the Apache
# License 2.0 text. The crates of Cargo.lock compiled in carry their own
# licences, which this expression does not enumerate.
license = "Apache-2.0"

versions {
  github = "pkgxdev/pkgx"
  strip  = "/^v/"
}

distributable {
  # GitHub's archive of the tag v2.11.1. (The repository also carries the
  # alias tags v2.11 and v2; `zpkb versions` lists them as 2.11 and 2, and
  # 2.11.1 sorts first.)
  url              = "https://github.com/pkgxdev/pkgx/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 78022 bytes. Recorded with the builder's fetcher through `zpkb sourcepin` and
  # confirmed by a second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "2.11.1" = "553019a0f9e67111568a6a193bcd63281e6252982d9a1d3835f1f0bc65313a0b"
  }
}

# crates/cli/Cargo.toml:2: the package `pkgx`, whose only target is
# crates/cli/src/main.rs. crates/lib (libpkgx, a cdylib + rlib) is not installed.
provides = [
  "bin/pkgx",
]

dependencies = {
  "tukaani.org/xz" = "^5"

  # rustls-platform-verifier 0.6.2 and rustls-native-certs read the system CA
  # bundle at run time on linux; on darwin Security.framework answers.
  linux = {
    "curl.se/ca-certs" = "*"
  }
}

runtime {
  env = {
    linux = {
      # openssl-probe honours SSL_CERT_FILE before probing the usual places.
      SSL_CERT_FILE = "{{deps.curl.se/ca-certs.prefix}}/ssl/cert.pem"
    }
  }
}

build {
  dependencies = {
    "gnu.org/tar"                = "*"
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc"  = "*"
      # openssl-src runs OpenSSL's ./Configure (perl) and then make.
      "perl.org"     = "*"
      "gnu.org/make" = "*"
    }

    # Edition 2021 (crates/cli/Cargo.toml:7); neither crate declares a
    # rust-version, and the dependency set (reqwest 0.13, rusqlite 0.39, nix
    # 0.31) is recent, so the compiler this tree carries is named.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # AWS-LC is COMPILED IN, NOT LINKED (aws-lc-sys vendors its sources); see
    # crates.io/drill for the choice of the cc builder over the CMake builder.
    AWS_LC_SYS_CMAKE_BUILDER = 0
  }

  script = [
    {
      run = <<EOT
set -eu
if [ "$(uname -s)" = Linux ]; then
  # Inherited from rust-lang.org/cargo, which measured it: this tree's gcc keeps
  # libgcc.a outside rustc's link search path, so the link fails without it.
  L=""
  for c in "$${ZPKG_DIR:-$HOME/.zpkg}"/gnu.org/gcc/*/lib/gcc/*/*/libgcc.a; do
    if [ -e "$c" ]; then L="$(dirname "$c")"; fi
  done
  if [ -z "$L" ]; then echo "no libgcc.a under gnu.org/gcc" >&2; exit 1; fi
  export RUSTFLAGS="$${RUSTFLAGS:-} -L$L"
fi
# ⛔ --locked: Cargo.lock is the dependency pin, and cargo verifies its checksums.
# The workspace root has no package, so the binary crate is named by its path.
cargo install --locked --path crates/cli --root {{prefix}}
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
P="{{prefix}}/bin/pkgx"
test -x "$P"
# crates/cli/src/main.rs:106: format!("pkgx {}", CARGO_PKG_VERSION).
OUT="$("$P" --version)"
if [ "$OUT" != "pkgx 2.11.1" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi
"$P" --help > help.txt
test -s help.txt

# No openssl dependency is declared: on linux OpenSSL is compiled in, so the
# binary must NOT link libssl or libcrypto dynamically.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$P")"; else LIBS="$(ldd "$P")"; fi
case "$LIBS" in
  *libssl*|*libcrypto*) echo "pkgx links OpenSSL dynamically:" >&2; echo "$LIBS" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",                 # :1-2 workspace members, :4-5 release profile (lto fat), :7-12 workspace dependencies
    "Cargo.lock",                 # reqwest 0.13.2, rustls 0.23.28, aws-lc-sys 0.39.0, native-tls 0.2.12, openssl-sys 0.9.116, openssl-src 300.4.1+3.4.0, libsqlite3-sys 0.37.0, lzma-sys 0.1.20
    "crates/cli/Cargo.toml",      # :2 name, :5 licence, :6 version, :26-30 the non-macOS bundled sqlite and vendored native-tls
    "crates/lib/Cargo.toml",      # :26 reqwest 0.13, :27 async-compression xz, :35-36 bundled sqlite off macOS
    "crates/cli/src/main.rs",     # :40-43 --version, :106 the version string
    "crates/cli/src/args.rs",     # :70-71 --help, --version
    "lzma-sys-0.1.20/build.rs",   # :11-21 pkg-config first, own build only on a miss or LZMA_API_STATIC
    "LICENSE.txt",                # Apache License 2.0
  ]

  consulted = [
    # Read for facts only: the project name. NOT taken: its dependency lines.
    "pkgxdev/pantry projects/pkgx.sh/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice with one answer. The crates it compiles are
pinned by Cargo.lock's checksums, which cargo verifies under --locked.

⛔ NOT BUILT, NOT TESTED. The dependency facts above come from `cargo tree`
on the tag (darwin and linux targets); the build itself, and in particular the
perl-and-make build of the vendored OpenSSL on a linux factory, was not run.
The first factory run is this file's test.
EOT
}
