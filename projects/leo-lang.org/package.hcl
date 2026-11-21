# Leo — a statically typed language for zero-knowledge applications
# (ProvableHQ/leo). A FRAGMENT until now: it said what the binary needs and
# took its source, versions, build and test from the upstream pantry merged
# underneath. That merge ended with zpkb v0.90.0 (go-zpkg/packages#431), so
# this is the WHOLE recipe, written from Leo's own files (go-zpkg/packages#440
# step 1), at 4.4.6.
#
# ⭐⭐ WHAT WRITING IT FOUND:
#
#   - THE TAGS CHANGED SCHEME. Up to 4.0.2 a release is the tag `vX.Y.Z`; from
#     4.1.0 on the repository releases one tag PER CRATE (release-plz), and the
#     compiler's is `leo-lang-vX.Y.Z` (beside leo-passes-v4.4.6, leo-std-v4.4.6
#     and so on at the same number). `zpkb versions` on the bare github source
#     lists both families; the recipe ignores the old `v` family, whose archive
#     URL differs, and strips `leo-lang-v`. Checked against `git ls-remote`
#     (14 leo-lang-v tags, 4.1.0 to 4.4.6).
#   - THE FRAGMENT'S curl.se IS NOT LINKED. Cargo.lock has no curl-sys.
#   - openssl.org IS: reqwest 0.13 (Cargo.toml:72) reaches native-tls, whose
#     openssl-sys (Cargo.lock:4122) links OpenSSL on Linux. zlib comes from
#     libz-sys (Cargo.lock:3685, pkg-config, as librocksdb-sys's dependency).
#   - ROCKSDB IS COMPILED FROM C++ and its build script runs bindgen:
#     crates/leo/Cargo.toml:124-125 takes rocksdb outside musl, and Cargo.toml:71
#     asks for "bindgen-runtime", so the build needs a libclang at build time and
#     a C++ compiler. bzip2-sys and lz4-sys (Cargo.lock:3677,3681) are librocksdb-sys's.
#   - rust-version 1.96.0 (crates/leo/Cargo.toml:25), which the compiler this tree
#     carries (^1.100) exceeds.

summary = "Leo: a statically typed language for zero-knowledge applications"

# crates/leo/Cargo.toml:23 license = "GPL-3.0" (also crates/fmt, crates/lsp).
license = "GPL-3.0"

versions {
  github = "ProvableHQ/leo"
  strip  = ["/^leo-lang-v/"]
  ignore = ["/^v\\d/"]
}

distributable {
  # GitHub's archive of the tag leo-lang-v4.4.6.
  url              = "https://github.com/ProvableHQ/leo/archive/refs/tags/leo-lang-v{{version.raw}}.tar.gz"
  strip-components = 1

  # 2752750 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "4.4.6" = "f5446c81b843c18c45a018c1a2970e4cf049078ce2e8a297232ab999a1e65535"
  }
}

# README.md:95-96, the source install: `leo` (crates/leo, [[bin]] at
# Cargo.toml:36) and the bundled plugin `leo-fmt` (crates/fmt, [[bin]] at
# Cargo.toml:24). The language server leo-lsp, which README.md:104 also names
# for the released install, is NOT built here.
provides = [
  "bin/leo",
  "bin/leo-fmt",
]

dependencies = {
  "openssl.org" = "^3"
  "zlib.net"    = "^1"
}

build {
  dependencies = {
    "gnu.org/tar"                = "*"
    "gnu.org/make"               = "*"
    "freedesktop.org/pkg-config" = "*"
    # bindgen's libclang, for librocksdb-sys.
    "llvm.org" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

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
# ⛔ --locked: Cargo.lock is the dependency pin, and cargo verifies its checksums.
# Neither package has a feature to name: crates/leo declares `default = [ ]`
# (Cargo.toml:45) and crates/fmt `default = []` (Cargo.toml:29).
cargo install --locked --path crates/leo --root {{prefix}}
cargo install --locked --path crates/fmt --root {{prefix}}
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
test -x "{{prefix}}/bin/leo-fmt"
F="{{prefix}}/bin/leo"
test -x "$F"
OUT="$("$F" --version </dev/null)"
case "$OUT" in
  *{{version.raw}}*) ;;
  *) echo "leo --version printed '$OUT', want it to name {{version.raw}}" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",                # :71 rocksdb bindgen-runtime, :72 reqwest
    "Cargo.lock",                # :3671 librocksdb-sys, :3685 libz-sys, :4122 openssl-sys; no curl-sys
    "crates/leo/Cargo.toml",     # :23 licence, :25 rust-version, :36 bin leo, :44-45 features, :124-125 rocksdb
    "crates/fmt/Cargo.toml",     # :24 bin leo-fmt, :28-29 features
    "crates/lsp/Cargo.toml",     # :22 bin leo-lsp (not built)
    "README.md",                 # :95-96 the source install
  ]

  consulted = [
    "projects/leo-lang.org/package.hcl before this change",
    "projects/nushell.sh/package.hcl (the bindgen-needs-libclang precedent)",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates are pinned by Cargo.lock's checksums, which cargo verifies under
--locked.

⚠ LIBCLANG IS UNVERIFIED. The build script points LIBCLANG_PATH at llvm.org's
lib directory only when a libclang sits there; whether this tree's llvm.org
installs one was NOT checked (its recipe builds the clang project, which does
build libclang by default). nushell.sh's recipe found the same need and relied on
the system's.

⚠ openssl.org is kept on the lock file's evidence (native-tls -> openssl-sys);
curl.se dropped because Cargo.lock has no curl-sys. Neither is a link-time check.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only. The first
factory run is this file's test.
EOT
}
