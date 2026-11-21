# typst.app — Typst, a markup-based typesetting system (typst/typst). A FRAGMENT
# until now: it said `openssl.org ^3` and took its source, versions, build and
# test from the upstream pantry merged underneath. That merge ended with zpkb
# v0.90.0 (go-zpkg/zpkb#514), so this is the WHOLE recipe, written from Typst's
# own files (go-zpkg/packages#440 step 1), at 0.15.1.
#
# WHAT WRITING IT FOUND: the OpenSSL dependency is real, but only on linux.
# `cargo tree --locked` shows openssl-sys 0.9.116 (native-tls 0.2.13, openssl
# 0.10.80) for x86_64-unknown-linux-gnu and none for aarch64-apple-darwin, where
# native-tls is Security.framework. The package manifest of typst-kit has it
# behind `system-downloader` (typst-kit/Cargo.toml:79), which typst-cli turns on
# (typst-cli/Cargo.toml:68) for the package downloader. The dependency is
# therefore declared for linux only, and the `vendor-openssl` feature
# (typst-cli/Cargo.toml:101, which builds a private OpenSSL) is NOT enabled.

summary = "typst: a markup-based typesetting system"

# Cargo.toml:13 license = "Apache-2.0"; LICENSE is the Apache 2.0 text. The
# crates of Cargo.lock compiled in carry their own licences, which this
# expression does not enumerate.
license = "Apache-2.0"

versions {
  github = "typst/typst/releases/tags"
  strip  = "/^v/"

  # Before 0.1 the project tagged by date (v23-03-28, v23-03-21-2): not
  # versions. The pattern is matched AFTER zpkb turns a date into 23.03.28
  # (versions/versions.go:404-405), and a typst version never has two digits
  # in its major.
  ignore = "/^\\d\\d\\.\\d\\d\\.\\d\\d/"
}

distributable {
  # GitHub's archive of the tag v0.15.1.
  url              = "https://github.com/typst/typst/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 4873084 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.15.1" = "c07909e01a2a6941e52c9b616e48c209c755eed416d62bcf5583c37a4aca01a3"
  }
}

# typst-cli/Cargo.toml:15-17: the one binary, `typst`.
provides = [
  "bin/typst",
]

dependencies = {
  # openssl-sys 0.9.116 is linked on linux only (see the header). Every 3.x is
  # ossl300 to it.
  linux = {
    "openssl.org"      = "^3"
    # openssl-probe 0.1.6 <- native-tls 0.2.13 looks for the CA bundle at run
    # time (package downloads).
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
      "gnu.org/gcc"                 = "*"
      "freedesktop.org/pkg-config" = "*"
    }

    # Cargo.toml:8 rust-version = "1.92", edition 2024: the floor the manifest
    # declares; the compiler this tree carries is named.
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

  # ⛔ openssl-sys 0.9.116 refuses to guess without OPENSSL_DIR when no
  # pkg-config answers. The MAJOR symlink v3, not a concrete version (see
  # rust-lang.org/cargo). The `vendored` feature is off, and OPENSSL_NO_VENDOR
  # (openssl-sys build/main.rs:52-53) makes sure a stray one cannot build a
  # private copy.
  O="$${ZPKG_DIR:-$HOME/.zpkg}/openssl.org/v3"
  if [ ! -e "$O/include/openssl/ssl.h" ]; then
    echo "no openssl 3 at $O — is openssl.org ^3 a dependency?" >&2
    exit 1
  fi
  export OPENSSL_DIR="$O"
  export OPENSSL_NO_VENDOR=1
fi
# ⛔ Features, named. `default = ["embedded-fonts", "http-server"]`
# (typst-cli/Cargo.toml:89): neither links a system C library. `vendor-openssl`
# (:101) is OFF, and so is `self-update` (:98).
# ⛔ --locked: Cargo.lock is the dependency pin, and cargo verifies its checksums.
cargo install --locked --path crates/typst-cli --root {{prefix}}
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
T="{{prefix}}/bin/typst"
test -x "$T"
OUT="$("$T" --version)"
case "$OUT" in
  "typst 0.15.1 "*) ;;
  *) echo "--version printed '$OUT'" >&2; exit 1 ;;
esac

# A document to a PDF: the whole pipeline (parse, layout with the embedded
# fonts, export) in one command.
cat > hello.typ <<'DOC'
= Hello

A *typeset* line with math $a^2 + b^2 = c^2$.
DOC
"$T" compile hello.typ hello.pdf
test -s hello.pdf
case "$(head -c 5 hello.pdf)" in
  "%PDF-") ;;
  *) echo "hello.pdf is not a PDF" >&2; exit 1 ;;
esac

# On linux the downloader links the OpenSSL this recipe names, not a private one.
if [ "$(uname -s)" = Linux ]; then
  LIBS="$(ldd "$T")"
  case "$LIBS" in
    *libssl.so.3*) ;;
    *) echo "typst does not link libssl.so.3:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
fi
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",                    # :7 version, :8 rust-version 1.92, :13 licence; workspace default-members = crates/typst-cli
    "crates/typst-cli/Cargo.toml",   # :15-17 [[bin]] typst; :58-71 typst-kit features; :68 system-downloader; :89 default = embedded-fonts, http-server; :98 self-update; :101 vendor-openssl
    "crates/typst-kit/Cargo.toml",   # :44-46 openssl optional; :79 system-downloader; :92 vendor-openssl = openssl/vendored
    "Cargo.lock",                    # resolved with `cargo tree --locked --target <t> -e normal,build -i <crate>` for linux-gnu and apple-darwin: openssl-sys 0.9.116 + openssl 0.10.80 + openssl-probe 0.1.6 linux only, native-tls present on both; aws-lc-sys, cmake, libz-sys, zstd-sys absent
    "LICENSE",                       # Apache License 2.0
  ]

  consulted = [
    # Read for facts only: the tag URL (with `v`), the release-tags version
    # source and its strip pattern, the binary name. NOT taken: the test, the
    # install without --locked.
    "pkgxdev/pantry projects/typst.app/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

C LIBRARIES, NAMED: OpenSSL 3 on linux only (openssl-sys, system copy through
OPENSSL_DIR). None on darwin (Security.framework). No libgit2, libssh2, zlib or
zstd crate with a C library in the graph, and no AWS-LC.

⛔ NOT BUILT, NOT TESTED. Written from the source's files and `cargo tree`
only. The first factory run is this file's test.
EOT
}
