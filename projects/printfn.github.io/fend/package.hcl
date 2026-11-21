# printfn.github.io/fend — an arbitrary-precision unit-aware calculator
# (printfn/fend). A FRAGMENT until now: it said what the binary needs and took
# its source, versions, build and test from the upstream pantry merged
# underneath. That merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is
# the WHOLE recipe, written from fend's own files (go-zpkg/packages#440 step
# 1), at 1.5.9.
#
# ⭐⭐ WHAT WRITING IT FOUND: the fragment declared `openssl.org ^3`; the default
# build links no OpenSSL. cli/Cargo.toml:28 makes `rustls` the default
# feature, and the OTHER one, `native-tls` (:26, reqwest/native-tls), is the only
# thing that would pull openssl-sys. `cargo tree --locked` for linux-gnu and
# apple-darwin finds no openssl-sys and no native-tls in the default graph;
# reqwest 0.13.5 -> rustls -> aws-lc-rs -> aws-lc-sys 0.46.0 (compiled in) is
# there instead. The dependency is dropped and the CA bundle that
# rustls-platform-verifier reads on linux is named.

summary = "fend: an arbitrary-precision unit-aware calculator"

# Cargo.toml:13 license = "MIT"; LICENSE.md is the MIT text. The crates of
# Cargo.lock compiled in (AWS-LC among them) carry their own licences, which
# this expression does not enumerate.
license = "MIT"

versions {
  github = "printfn/fend"
  strip  = "/^v/"
}

distributable {
  # GitHub's archive of the tag v1.5.9.
  url              = "https://github.com/printfn/fend/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 234936 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "1.5.9" = "3622b09d197d4be374880f3f97256633d0481e7a3c7da2f69f2cb5141aac1721"
  }
}

# cli/Cargo.toml:2 the package `fend`; cli/src/main.rs is its only binary.
provides = [
  "bin/fend",
]

dependencies = {
  # cargo tree --target x86_64-unknown-linux-gnu: openssl-probe 0.2.1 <-
  # rustls-native-certs 0.8.5 <- rustls-platform-verifier 0.7.1 <- reqwest 0.13.5
  # reads the system CA bundle at run time (the exchange-rate download). On
  # darwin the platform verifier uses Security.framework.
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

    # Cargo.toml:8 edition 2024 (stable from 1.85); no rust-version is declared.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # ⛔ AWS-LC IS COMPILED IN, NOT LINKED: aws-lc-sys vendors the AWS-LC sources
    # and there is no system AWS-LC in this tree. 0 forces its `cc` builder, so a
    # missing cmake is not what decides (cmake 0.1.58 is a build-dependency).
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
# Features, named: the default is `rustls` (cli/Cargo.toml:28). `native-tls`
# (OpenSSL on linux) is NOT enabled.
# ⛔ --locked: Cargo.lock is the dependency pin, and cargo verifies its checksums.
cargo install --locked --path cli --root {{prefix}}
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
F="{{prefix}}/bin/fend"
test -x "$F"
# cli/src/main.rs:212 prints fend_core::get_version(), the workspace version.
OUT="$("$F" --version)"
if [ "$OUT" != "1.5.9" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi
# An argument is evaluated (cli/src/args.rs:93): units and exact arithmetic.
OUT="$("$F" "2 + 3 * 4")"
if [ "$OUT" != "14" ]; then echo "2 + 3 * 4 printed '$OUT'" >&2; exit 1; fi
OUT="$("$F" "1 km to m")"
if [ "$OUT" != "1000 m" ]; then echo "1 km to m printed '$OUT'" >&2; exit 1; fi

# rustls, not OpenSSL: the binary must NOT link libssl.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$F")"; else LIBS="$(ldd "$F")"; fi
case "$LIBS" in
  *libssl*) echo "fend links libssl, which the default features do not ask for:" >&2; echo "$LIBS" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",         # :2 members, :6 version, :8 edition 2024, :13 licence
    "cli/Cargo.toml",     # :2 package fend, :19 reqwest 0.13.5, :25-28 features native-tls / rustls / default = rustls
    "cli/src/args.rs",    # :37 --version, :85-93 version vs evaluate
    "cli/src/main.rs",    # :212 prints fend_core::get_version()
    "Cargo.lock",         # resolved with `cargo tree --locked --target <t> -e normal,build -i <crate>` for linux-gnu and apple-darwin: openssl-sys and native-tls absent, aws-lc-sys 0.46.0 + cmake 0.1.58 present, openssl-probe 0.2.1 linux only
    "LICENSE.md",         # MIT
  ]

  consulted = [
    # Read for facts only: the tag URL (with `v`) and `--path cli`. NOT taken:
    # openssl ^1.1, rust ^1.65, the dice-roll test.
    "pkgxdev/pantry projects/printfn.github.io/fend/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

C LIBRARIES, NAMED: AWS-LC only (aws-lc-sys, compiled in, cc builder forced).
The cargo feature `native-tls` would add OpenSSL and is not enabled. No
libgit2 or libssh2 in the graph.

⛔ NOT BUILT by the factory. The same `cargo install --locked --path cli` was
run by hand on aarch64-apple-darwin outside the tree (system toolchain): the
three outputs asserted below (1.5.9, 14, 1000 m) were observed, and otool -L
shows no libssl. Linux was not run; the first factory run is this file's test.
EOT
}
