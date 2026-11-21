# surrealdb.com — SurrealDB, a multi-model database (surrealdb/surrealdb). A
# FRAGMENT until now: it said `openssl.org ^3` and took its source, versions,
# build and test from the upstream pantry merged underneath. That merge ended
# with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is the WHOLE recipe, written from
# SurrealDB's own files (go-zpkg/packages#440 step 1), at 4.0.1.
#
# ⭐⭐ WHAT WRITING IT FOUND:
#
#   1. THE FRAGMENT'S OPENSSL IS NOT LINKED. `cargo tree --locked -p surreal-db`
#      for x86_64-unknown-linux-gnu and aarch64-apple-darwin finds NO openssl-sys
#      (it is in Cargo.lock, not in this graph): TLS is rustls over aws-lc-rs.
#      The dependency is dropped; on linux openssl-probe looks for a CA bundle.
#   2. THE DEFAULT FEATURES CARRY NO ROCKSDB AND NO TIKV. `default`
#      (surrealdb/server/Cargo.toml:24-39) is mem + SurrealKV (pure Rust) plus
#      protocol and scripting features. The 3.x fragment's `--cfg
#      surrealdb_unstable` and `recursion_limit` patch are gone from this tree.
#   3. THE BUILD COMPILES C: aws-lc-sys (cc builder), tikv-jemalloc-sys and
#      libmimalloc-sys (`allocator`), lz4-sys, zstd-sys, and rquickjs-sys
#      (QuickJS, `scripting`) with BINDGEN ON (rquickjs `bindgen` feature in the
#      graph), so the build needs a libclang: llvm.org on linux, the Xcode tools
#      on darwin (see leo-lang.org, which found the same).
#
# ⛔ NOT BUILT by the factory; see the note.

summary = "surrealdb: a multi-model database"

# LICENSE: Business Source License 1.1 (Licensor SurrealDB Ltd.; Additional Use
# Grant forbids a Database Service; Change Date 2030-11-03, Change License
# Apache-2.0). Cargo.toml:65 license-file = "LICENSE".
license = "BUSL-1.1"

versions {
  github = "surrealdb/surrealdb/tags"
  strip  = "/^v/"
}

distributable {
  url              = "https://github.com/surrealdb/surrealdb/archive/refs/tags/v{{version}}.tar.gz"
  strip-components = 1

  # 23487854 bytes. Recorded with `zpkb sourcepin` (v0.96.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "4.0.1" = "3f599d253f20ebc5df217c69d52cc6b9b00cc04b7772b2518c230db9bd7d50f3"
  }
}

# Cargo.toml:385 package `surreal-db`, :397-399 [[bin]] name = "surreal".
provides = [
  "bin/surreal",
]

dependencies = {
  linux = {
    # openssl-probe 0.2.1 <- rustls-native-certs looks for the CA bundle at run
    # time; darwin uses Security.framework.
    "curl.se/ca-certs" = "*"
  }
}

runtime {
  env = {
    linux = {
      SSL_CERT_FILE = "{{deps.curl.se/ca-certs.prefix}}/ssl/cert.pem"
    }
  }
}

build {
  dependencies = {
    "gnu.org/tar"                = "*"
    "gnu.org/make"               = "*"
    "freedesktop.org/pkg-config" = "*"
    # rquickjs-sys 0.14.0 runs bindgen (clang-sys): libclang.
    "llvm.org" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # rust-toolchain.toml channel "1.95"; edition 2024.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # build.rs:7,58-64: without this it runs git for the version suffix, and a
    # source tarball has no git.
    SURREAL_BUILD_METADATA = "zpkg"

    # ⛔ aws-lc-sys 0.46.0 (aws-lc-rs 1.18.2, via rustls) otherwise drives CMake
    # (cmake 0.1.58 is in the graph); the cc builder needs no cmake.
    # builder/main.rs:851 reads AWS_LC_SYS_CMAKE_BUILDER.
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
# bindgen (clang-sys) looks for libclang through LIBCLANG_PATH. When this
# tree's llvm.org carries one, point at it; otherwise leave the variable unset
# and let bindgen search the system (the Xcode tools on darwin).
for d in "$${ZPKG_DIR:-$HOME/.zpkg}"/llvm.org/*/lib; do
  if [ -e "$d/libclang.so" ] || [ -e "$d/libclang.dylib" ]; then export LIBCLANG_PATH="$d"; fi
done
# ⛔ Features, named: surrealdb/server/Cargo.toml:24-39 `default` is allocator,
# allocation-tracking, storage-mem, storage-surrealkv, jwks, scripting, http,
# surrealism, graphql, gql, mcp, postgres, mysql, cli. All are kept, listed so
# nothing depends on the default set. OFF: `fips` (aws-lc-fips-sys), `cjk`,
# `tokio-console`. No RocksDB, no TiKV: this version has no such feature.
# ⛔ --locked: Cargo.lock is the dependency pin, and cargo verifies its checksums.
cargo install --locked --path . --no-default-features \
  --features allocator,allocation-tracking,storage-mem,storage-surrealkv,jwks,scripting,http,surrealism,graphql,gql,mcp,postgres,mysql,cli \
  --root {{prefix}}
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
S="{{prefix}}/bin/surreal"
test -x "$S"
OUT="$("$S" --version)"
case "$OUT" in
  *4.0.1*) ;;
  *) echo "--version printed '$OUT'" >&2; exit 1 ;;
esac

# Rustls, not OpenSSL.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$S")"; else LIBS="$(ldd "$S")"; fi
case "$LIBS" in
  *libssl*) echo "surreal links libssl, which the default graph does not ask for:" >&2; echo "$LIBS" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",                     # :64 edition 2024, :65 license-file, :67 version 4.0.1; :385 package surreal-db; :397-399 [[bin]] surreal; :401-429 features, default :405
    "Cargo.lock",                     # resolved with `cargo tree --locked -p surreal-db --target <t> -e normal,build` for linux-gnu and apple-darwin: aws-lc-sys 0.46.0 + cmake 0.1.58, rquickjs-sys 0.14.0 + bindgen 0.72.1 + clang-sys 1.9.1, tikv-jemalloc-sys 0.7.1, libmimalloc-sys, lz4-sys 1.11.1, zstd-sys 2.1.2; openssl-sys NOT in the graph; no rocksdb
    "LICENSE",                        # Business Source License 1.1, Change Date 2030-11-03 -> Apache-2.0
    "build.rs",                       # :7,58-64 SURREAL_BUILD_METADATA, else git
    "rust-toolchain.toml",            # channel 1.95; rustup only
    "surrealdb/server/Cargo.toml",    # :15-67 features; default :24-39; fips :45
    "surrealdb/core/Cargo.toml",      # :61 scripting = dep:js; :161 allocator = jemallocator, mimalloc
    "surrealdb/ext/src/version.rs",   # option_env SURREAL_BUILD_METADATA
  ]

  consulted = [
    # Read for facts only: `cargo install --path . --locked`, the metadata
    # variable. NOT taken: openssl ^3, the 3.x recursion_limit patch, the test.
    "pkgxdev/pantry projects/surrealdb.com/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

C LIBRARIES, NAMED: none from the system. aws-lc (aws-lc-sys, cc builder),
jemalloc and mimalloc (`allocator`), QuickJS (rquickjs-sys, `scripting`),
lz4 and zstd are compiled from bundled source, not switchable. Build tools: a C
compiler and libclang (bindgen).

⚠ LIBCLANG IS UNVERIFIED on linux: the script points LIBCLANG_PATH at llvm.org's
lib directory only when a libclang sits there (same caveat as leo-lang.org).

⛔ NOT BUILT by the factory, and NOT BUILT by hand either (a full SurrealDB
build was not run for this recipe). What was run: `cargo tree --locked` on
aarch64-apple-darwin and x86_64-unknown-linux-gnu to read the graph above. The
test's `--version` match is unverified.
EOT
}
