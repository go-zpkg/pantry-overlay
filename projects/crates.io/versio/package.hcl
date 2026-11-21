# crates.io/versio — a tool to manage and publish project versions (chaaz/versio).
# A FRAGMENT until now: it said what the binary needs and took its source,
# versions, build and test from the upstream pantry merged underneath. That
# merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is the WHOLE recipe,
# written from versio's own files (go-zpkg/packages#431, #440 step 1), at 0.8.5.
#
# ⭐⭐ WHAT WRITING IT FOUND.
#
#   - THE FRAGMENT NAMED THREE GPG LIBRARIES THE BUILD DOES NOT USE. It declared
#     gnupg.org/gpgme, libassuan and libgpg-error. versio's OpenPGP is
#     sequoia-openpgp 2.0.0 (Cargo.toml:38-41) with `default-features = false`
#     and the `crypto-rust` backend: pure Rust, no nettle, no gpgme. No gpgme
#     crate is in Cargo.lock. They are dropped.
#   - LIBGIT2, LIBSSH2, ZLIB AND OPENSSL ARE WHAT IT DOES USE. git2 0.20.2
#     (Cargo.toml:18; Cargo.lock:1036) with its default features (https, ssh):
#     libgit2-sys 0.18.1+1.9.0 (:1591), libssh2-sys 0.3.1 (:1621), libz-sys
#     (:1635), openssl-sys 0.9.109 (:1999). Without LIBGIT2_NO_VENDOR a missing
#     system libgit2 compiled its own copy in, silently; named now, with libgit2
#     ~1.9 (libgit2-sys build.rs:10 accepts "1.9.0".."1.10.0"). Measured with
#     `cargo tree --locked -i openssl-sys`: on linux it is reached through git2,
#     libgit2-sys, libssh2-sys and native-tls; on aarch64-apple-darwin through
#     libgit2-sys and libssh2-sys only (reqwest uses Security.framework there).
#   - NO openssl-src IN Cargo.lock: OpenSSL is never compiled in, so a missing
#     system OpenSSL fails the build.
#   - THE HTTPS CLIENTS ARE TWO: reqwest 0.12.20 with native-tls (OpenSSL on
#     linux, Security.framework on darwin), and octocrab 0.44.1 (:1909), whose
#     TLS is rustls 0.23.28 over ring 0.17.14 with the certificate store read at
#     run time by rustls-native-certs 0.8.1 (measured with `cargo tree -i
#     rustls` and `-i rustls-native-certs`). On linux that store is the system
#     CA bundle (openssl-probe, :1993), so curl.se/ca-certs is a run-time
#     dependency and SSL_CERT_FILE names it, as in crates.io/drill.
#   - build.rs runs `git describe` and `date` (:6-17) for GIT_SHORT_HASH and
#     DATE_DASH. In a GitHub archive `git describe` prints nothing, so the
#     hash is empty; neither is printed by `versio --version`, which is clap's.
#   - THE LICENSE IS NOT AN SPDX ONE. Cargo.toml:9 says license-file =
#     "LICENSE.txt", whose text is an "AS IS" disclaimer plus permission to copy
#     the document verbatim; it grants no right to use or modify the code in so
#     many words. Recorded as a LicenseRef, quoted rather than interpreted.

summary = "versio: a tool to manage and publish project versions"

# LICENSE.txt:3-11 (see the header). The crates of Cargo.lock compiled in carry
# their own licences, which this expression does not enumerate.
license = "LicenseRef-Versio"

versions {
  github = "chaaz/versio"
  strip  = "/^v/"
}

distributable {
  # GitHub's archive of the tag v0.8.5 (the repository also tags versio-prev and
  # versio-prev-hotfix-test, which are not versions).
  url              = "https://github.com/chaaz/versio/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 145195 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.8.5" = "be32c595b3d34c6f5659a3353e419e5fdd1878ac7a75537b0612ce9f74cf4896"
  }
}

# Cargo.toml:47-50: the one [[bin]], named `versio` (src/main.rs).
provides = [
  "bin/versio",
]

dependencies = {
  "libgit2.org" = "~1.9"
  "libssh2.org" = "^1"
  "openssl.org" = "^3"
  "zlib.net"    = "^1"

  # rustls-native-certs 0.8.1 and openssl-probe look for the system CA bundle at
  # run time on linux (see the header and runtime.env). On darwin
  # Security.framework answers.
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
      "gnu.org/gcc" = "*"
    }

    # Edition 2021 (Cargo.toml:5); versio declares no rust-version, and its
    # dependency set (octocrab 0.44, sequoia-openpgp 2) is recent, so the
    # compiler this tree carries is named.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # ⛔ 1. libgit2: libgit2-sys 0.18.1 build.rs:36-48. LIBGIT2_NO_VENDOR makes a
    # missing or out-of-range system libgit2 a PANIC; without it a miss compiles
    # the vendored copy and says nothing.
    LIBGIT2_NO_VENDOR = 1

    # ⛔ 2. libssh2: libssh2-sys 0.3.1 build.rs:22-27. The system copy is used
    # ONLY when this variable is set, and if pkg-config then finds none the
    # script FALLS THROUGH to compiling its own — not fatal, so the test reads
    # the link off the binary.
    LIBSSH2_SYS_USE_PKG_CONFIG = 1

    # 3. zlib: libz-sys prefers pkg-config, then a link probe, then its own
    # build (as in rust-lang.org/cargo). LIBZ_SYS_STATIC is NOT set.
    #
    # 4. No openssl-src in Cargo.lock: OpenSSL is not compiled in, so no
    # OPENSSL_NO_VENDOR is needed.
  }

  script = [
    {
      run = <<EOT
set -eu
# openssl-sys refuses to guess without OPENSSL_DIR when no pkg-config answers.
# The MAJOR symlink v3, not a concrete version (see rust-lang.org/cargo).
O="$${ZPKG_DIR:-$HOME/.zpkg}/openssl.org/v3"
if [ ! -e "$O/include/openssl/ssl.h" ]; then
  echo "no openssl 3 at $O — is openssl.org ^3 a dependency?" >&2
  exit 1
fi
export OPENSSL_DIR="$O"

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
V="{{prefix}}/bin/versio"
test -x "$V"
# src/cli.rs:11 #[clap(author, version, about)]: the command is named after the
# package, the version is Cargo.toml:3 and the about is Cargo.toml:6.
OUT="$("$V" --version)"
if [ "$OUT" != "versio 0.8.5" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi
"$V" --help > help.txt
grep -q "manage and publish project versions" help.txt

# What it links: libgit2, libssh2 and zlib are the system ones, none compiled in.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$V")"; else LIBS="$(ldd "$V")"; fi
for l in libgit2 libssh2 libz; do
  case "$LIBS" in
    *"$l"*) ;;
    *) echo "versio does not link $l:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
done
if [ "$(uname -s)" = Linux ]; then
  case "$LIBS" in
    *libssl*) ;;
    *) echo "versio does not link libssl on linux:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
fi
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",   # :3 version, :5 edition, :6 description, :9 license-file, :18 git2 0.20.2, :23 octocrab, :26 reqwest, :38-41 sequoia-openpgp crypto-rust, :47-50 [[bin]]
    "Cargo.lock",   # :1036 git2, :1591 libgit2-sys 0.18.1+1.9.0, :1621 libssh2-sys 0.3.1, :1635 libz-sys, :1909 octocrab 0.44.1, :1993 openssl-probe, :1999 openssl-sys 0.9.109, :2583 rustls-native-certs; no openssl-src, no gpgme
    "build.rs",     # :6-17 git describe, date
    "src/cli.rs",   # :10-11 clap version and about
    "src/main.rs",  # :10-18 the entry point
    "libgit2-sys-0.18.1+1.9.0/build.rs",  # :10 "1.9.0".."1.10.0", :36-48 LIBGIT2_NO_VENDOR
    "libssh2-sys-0.3.1/build.rs",         # :22-27 LIBSSH2_SYS_USE_PKG_CONFIG
    "LICENSE.txt",  # :3-11 the disclaimer and the verbatim-copy permission
  ]

  consulted = [
    # Read for facts only: the tag URL, the binary name `versio`. NOT taken:
    # gpgme, libassuan and libgpg-error (the OpenPGP backend is pure Rust),
    # openssl ^1.1, rust >=1.56.
    "pkgxdev/pantry projects/crates.io/versio/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

The TLS and library graph was MEASURED with cargo 1.99 on the 0.8.5 source
(`cargo tree --locked -i openssl-sys | rustls | ring | rustls-native-certs`,
for linux and darwin targets), not only read off the lockfile.

⚠ THE LICENSE FIELD IS A JUDGEMENT, STATED: LicenseRef-Versio points at the
LICENSE.txt of the source; it is not an assertion that the text grants more than
it says.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only, on a loaded
machine. The first factory run is this file's test.
EOT
}
