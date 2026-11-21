# github.com/kaspanet/rusty-kaspa — Rusty Kaspa, the Rust implementation of the
# Kaspa full node (`kaspad`). A FRAGMENT until now: it said `openssl.org ^3` on
# linux and took its source, versions, build and test from the upstream pantry
# merged underneath. That merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so
# this is the WHOLE recipe, written from the project's own files
# (go-zpkg/packages#440 step 1), at 2.1.0.
#
# ⭐⭐ WHAT WRITING IT FOUND:
#
#   1. THE FRAGMENT'S OPENSSL IS NOT LINKED. `cargo tree --locked -p kaspad` for
#      x86_64-unknown-linux-gnu finds no openssl-sys: the graph is ring (rustls,
#      tonic `tls-webpki-roots`), so there is no system CA lookup either.
#   2. WHAT THE GRAPH DOES COMPILE IS ROCKSDB. rocksdb 0.24.0 ->
#      librocksdb-sys 0.17.3+10.4.2 carries RocksDB 10.4.2's C++ source in the
#      crate (crates.io, no git submodule is fetched), with bzip2-sys, libz-sys,
#      lz4-sys and zstd-sys; it runs bindgen (clang-sys 1.8.1), so the build
#      needs a C++ compiler and libclang. libmimalloc-sys (kaspa-alloc) and
#      secp256k1-sys are C as well.
#   3. protoc IS A BUILD DEPENDENCY: protocol/p2p/build.rs calls
#      tonic_prost_build (tonic-prost-build 0.14.5), which needs `protoc` on PATH
#      (see tlr.dev, same case). protobuf.dev builds one.
#   4. ONE GIT DEPENDENCY: Cargo.lock:8853 workflow-perf-monitor 0.0.3 from
#      github.com/kaspanet/workflow-perf-monitor-rs at a pinned commit; cargo
#      fetches it itself, like a registry crate.
#
# ⛔ NOT BUILT by the factory; see the note.

summary = "rusty-kaspa: the Rust implementation of the Kaspa full node"

# Cargo.toml:78 license = "ISC" (workspace.package); LICENSE is the ISC text.
# The crates of Cargo.lock carry their own licences, which this expression does
# not enumerate.
license = "ISC"

versions {
  github = "kaspanet/rusty-kaspa/tags"
  strip  = "/^v/"
}

distributable {
  url              = "https://github.com/kaspanet/rusty-kaspa/archive/refs/tags/v{{version}}.tar.gz"
  strip-components = 1

  # 5864032 bytes. Recorded with `zpkb sourcepin` (v0.96.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "2.1.0" = "70d7cfa7c205827b181cb0c275a655f963ecac6a5c626b81fbc1a35fb638e6d1"
  }
}

# kaspad/src/main.rs: package `kaspad` builds the binary `kaspad` (its lib is
# kaspad_lib, kaspad/Cargo.toml:13-15). The other binaries of the workspace
# (cli, rothschild, simpa) are separate packages and are not installed.
provides = [
  "bin/kaspad",
]

# No runtime dependency: every C library in the graph is compiled from bundled
# source, and TLS is rustls with built-in roots.
dependencies = {}

build {
  dependencies = {
    "gnu.org/tar"                = "*"
    "gnu.org/make"               = "*"
    "freedesktop.org/pkg-config" = "*"
    # ⛔ protoc for protocol/p2p/build.rs; found by prost-build on PATH.
    "protobuf.dev" = "*"
    # bindgen's libclang, for librocksdb-sys (and clang-sys 1.8.1).
    "llvm.org" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.toml:75 rust-version = "1.91.0"; edition 2024.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
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
# ⛔ Features, named: package kaspad declares `heap` (dhat profiling),
# `devnet-prealloc` and `semaphore-trace` (kaspad/Cargo.toml:69-72) and no
# default; all three are OFF, so no feature flag is passed.
# ⛔ --locked: Cargo.lock is the dependency pin, and cargo verifies its checksums.
cargo install --locked --path kaspad --root {{prefix}}
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
K="{{prefix}}/bin/kaspad"
test -x "$K"
OUT="$("$K" --version)"
case "$OUT" in
  *2.1.0*) ;;
  *) echo "--version printed '$OUT'" >&2; exit 1 ;;
esac

# Rustls, not OpenSSL.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$K")"; else LIBS="$(ldd "$K")"; fi
case "$LIBS" in
  *libssl*) echo "kaspad links libssl, which the graph does not ask for:" >&2; echo "$LIBS" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",                  # :75 rust-version 1.91.0, :76 version 2.1.0, :78 license ISC, :80 edition 2024; :244 rocksdb 0.24.0; :276-278 tonic 0.14.5 / tonic-prost-build
    "Cargo.lock",                  # resolved with `cargo tree --locked -p kaspad --target x86_64-unknown-linux-gnu -e normal,build`: librocksdb-sys 0.17.3+10.4.2, bzip2-sys 0.1.11, libz-sys 1.1.20, lz4-sys 1.11.1, zstd-sys 2.0.13, bindgen 0.72.1, clang-sys 1.8.1, libmimalloc-sys 0.1.44, secp256k1-sys 0.10.1, ring 0.17.14, prost-build 0.14.3, tonic-build 0.14.5; openssl-sys absent; :8853 the one git source
    "LICENSE",                     # ISC
    "kaspad/Cargo.toml",           # :1-2 package kaspad; :13-15 lib kaspad_lib; :69-72 features
    "protocol/p2p/build.rs",       # tonic_prost_build::configure().compile_protos
    "protocol/p2p/Cargo.toml",     # :50-51 build-dependencies tonic-prost-build
    "utils/alloc/Cargo.toml",      # :12-19 mimalloc, `override` off on macOS
  ]

  consulted = [
    # Read for facts only: `cargo install --path kaspad --locked`. NOT taken:
    # openssl ^3, the test.
    "pkgxdev/pantry projects/github.com/kaspanet/rusty-kaspa/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked; the one git dependency is pinned by commit.

C AND C++ LIBRARIES, NAMED: none from the system. RocksDB 10.4.2, bzip2, zlib,
lz4, zstd, mimalloc and secp256k1 are compiled from bundled source by their
-sys crates, not switchable. Build tools: a C++ compiler, libclang (bindgen),
protoc.

⚠ LIBCLANG IS UNVERIFIED on linux: the script points LIBCLANG_PATH at llvm.org's
lib directory only when a libclang sits there (same caveat as leo-lang.org).

⛔ NOT BUILT by the factory, and NOT BUILT by hand (a RocksDB compile was not run
for this recipe). What was run: `cargo tree --locked` for linux-gnu. The test's
`--version` match (clap `.version(CARGO_PKG_VERSION)`, kaspad/src/args.rs:223) is
unverified.
EOT
}
