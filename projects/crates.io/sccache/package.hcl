# crates.io/sccache — a ccache-like compiler caching tool (mozilla/sccache). A
# FRAGMENT until now: it said what the binary needs and took its source,
# versions, build and test from the upstream pantry merged underneath. That
# merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is the WHOLE recipe,
# written from sccache's own files (go-zpkg/packages#440 step 1), at 0.19.0.
#
# ⭐⭐ WHAT WRITING IT FOUND: the fragment declared `openssl.org ^3` and the
# upstream recipe `^1.1`. The default build of 0.19.0 links neither. `cargo tree
# --locked` for x86_64-unknown-linux-gnu and aarch64-apple-darwin finds NO
# openssl-sys in the graph: reqwest 0.13 is built with its `rustls` feature
# (Cargo.toml:89-95), and the only crates that ask for OpenSSL are behind
# features the default does not enable (`dist-server`: openssl, rouille/ssl,
# Cargo.toml:251-261; `vendored-openssl`: Cargo.toml:237). The dependency is
# dropped; the CA bundle that rustls-platform-verifier reads on linux is named.

summary = "sccache: a ccache-like compiler caching tool"

# Cargo.toml:11 license = "Apache-2.0"; LICENSE is the Apache 2.0 text. The
# crates of Cargo.lock compiled in (AWS-LC, zstd among them) carry their own
# licences, which this expression does not enumerate.
license = "Apache-2.0"

versions {
  github = "mozilla/sccache"
  strip  = "/^v/"
}

distributable {
  # GitHub's archive of the tag v0.19.0.
  url              = "https://github.com/mozilla/sccache/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 554322 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.19.0" = "2da079033cd19fd8e2a09f56f9a7d9d1a72d591ff3acdc47d95b920145cf2671"
  }
}

# Cargo.toml:27-31: the binaries `sccache` and `sccache-dist`; the second is
# built only with the `dist-server` feature, which `default` does not enable.
provides = [
  "bin/sccache",
]

dependencies = {
  # cargo tree --target x86_64-unknown-linux-gnu: openssl-probe 0.1.6 <-
  # rustls-native-certs 0.8.1 <- rustls-platform-verifier 0.7.0 <- reqwest 0.13
  # looks for the system CA bundle at run time. On darwin the platform verifier
  # uses Security.framework (no openssl-probe in that graph).
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
    "gnu.org/tar" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.toml:3 edition 2024, :5 rust-version = "1.91.0": the floor the
    # manifest declares; the compiler this tree carries is named.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # ⛔ AWS-LC IS COMPILED IN, NOT LINKED: aws-lc-sys 0.41.0 (reqwest -> rustls
    # -> aws-lc-rs) vendors the AWS-LC sources; there is no system AWS-LC to use
    # in this tree. Its builder picks between a `cc` build and a CMake build on
    # its own; 0 forces the cc builder so a missing cmake is not what decides.
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
# ⛔ Default features, named: `default = ["all"]` (Cargo.toml:198) is
# dist-client + redis, s3, memcached, gcs, azure, gha, webdav, oss, cos. None of
# them links a system C library: AWS-LC and zstd (zstd-sys 2.0.10, the `zstd`
# crate of Cargo.toml:124, compiles its bundled libzstd 1.5.6) are compiled in.
# ⛔ --locked: Cargo.lock is the dependency pin, and cargo verifies its checksums.
cargo install --locked --path . --root {{prefix}}
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
S="{{prefix}}/bin/sccache"
test -x "$S"
# clap's crate version: the binary name and Cargo.toml:6.
OUT="$("$S" --version)"
if [ "$OUT" != "sccache 0.19.0" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi
"$S" --help > help.txt
grep -q -- "--show-stats" help.txt

# rustls, not OpenSSL: the binary must NOT link libssl, and `sccache-dist`
# (dist-server) must not have been installed.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$S")"; else LIBS="$(ldd "$S")"; fi
case "$LIBS" in
  *libssl*) echo "sccache links libssl, which the default features do not ask for:" >&2; echo "$LIBS" >&2; exit 1 ;;
esac
if [ -e "{{prefix}}/bin/sccache-dist" ]; then echo "sccache-dist was installed" >&2; exit 1; fi
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",   # :3-6 edition, name, rust-version 1.91.0, version; :11 licence; :27-31 binaries; :86 openssl optional; :89-95 reqwest 0.13 rustls; :124 zstd; :173-263 features
    "Cargo.lock",   # resolved with `cargo tree --locked --target <t> -e normal,build -i <crate>` for linux-gnu and apple-darwin: openssl-sys absent, aws-lc-sys 0.41.0 + cmake 0.1.58 present, openssl-probe 0.1.6 linux only, zstd-sys 2.0.10 present
    "LICENSE",      # Apache License 2.0
    "AGENTS.md",    # §4: Cargo.lock is committed and CI builds --locked; the storage backends are cargo features
  ]

  consulted = [
    # Read for facts only: the tag URL (with `v`), the binary name and
    # `--version` form. NOT taken: openssl ^1.1, rust >=1.70, the test.
    "pkgxdev/pantry projects/crates.io/sccache/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

C LIBRARIES, NAMED: AWS-LC (aws-lc-sys, compiled in, cc builder forced) and
libzstd 1.5.6 (zstd-sys, compiled in; ZSTD_SYS_USE_PKG_CONFIG would use
facebook.com/zstd instead and is NOT set, the bundled copy being the one
Cargo.lock pins). No openssl, libgit2 or libssh2 anywhere in the default graph.

⛔ NOT BUILT by the factory. The same `cargo install --locked --path .` was run
by hand on aarch64-apple-darwin outside the tree (system toolchain): it
printed `sccache 0.19.0` and otool -L shows no libssl. Linux was not run; the
first factory run is this file's test.
EOT
}
