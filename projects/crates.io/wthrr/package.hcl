# crates.io/wthrr — a weather companion for the terminal
# (ttytm/wthrr-the-weathercrab). A FRAGMENT until now: it said what the binary
# needs and took its source, versions, build and test from the upstream pantry
# merged underneath. That merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so
# this is the WHOLE recipe, written from wthrr's own files (go-zpkg/packages#431,
# #440 step 1), at 1.2.1.
#
# ⭐⭐ WHAT WRITING IT FOUND.
#
#   - OPENSSL IS LINKED ON LINUX ONLY. reqwest 0.12.8 (Cargo.toml:34) keeps its
#     default `default-tls`: native-tls 0.2.12 (Cargo.lock:698), which is
#     OpenSSL on linux (openssl-sys 0.9.103, :774) and Security.framework on
#     darwin. Measured with `cargo tree --locked -i openssl-sys`: present for
#     x86_64-unknown-linux-gnu, "nothing to print" for aarch64-apple-darwin. The
#     fragment declared `openssl.org ^3` everywhere; it is scoped to linux now.
#   - No openssl-src in Cargo.lock: OpenSSL is never compiled in, so a missing
#     system OpenSSL fails the build. (ring and rustls sit in Cargo.lock, :950
#     and :996, but `cargo tree -i rustls` prints nothing for linux: the
#     lockfile lists reqwest's optional rustls support, the build does not use
#     it.)
#   - The repository is `wthrr-the-weathercrab`, the package and the binary are
#     `wthrr` (Cargo.toml:2, :47-49). Its tags are `vX.Y.Z`, plus a moving
#     `nightly` that is not a version.
#   - rust-version = "1.74.0" (Cargo.toml:13), read from the file.

summary = "wthrr: a weather companion for the terminal"

# Cargo.toml:6 license = "MIT"; LICENSE is the MIT text. The crates of
# Cargo.lock compiled in carry their own licences, which this expression does
# not enumerate.
license = "MIT"

versions {
  github = "ttytm/wthrr-the-weathercrab"
  strip  = "/^v/"
}

distributable {
  # GitHub's archive of the tag v1.2.1.
  url              = "https://github.com/ttytm/wthrr-the-weathercrab/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 46025 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "1.2.1" = "ff5b47f2046ebefa9ff28cb52ece49a06f7b89230578801c338c77802aa721e0"
  }
}

# Cargo.toml:47-49: the one [[bin]], named `wthrr` (src/main.rs).
provides = [
  "bin/wthrr",
]

dependencies = {
  # native-tls -> openssl-sys, linux only (see the header).
  linux = {
    "openssl.org" = "^3"
  }
}

build {
  dependencies = {
    "gnu.org/tar" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.toml:13 rust-version = "1.74.0"; edition 2021 (:5). The compiler
    # this tree carries is named.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  script = [
    {
      run = <<EOT
set -eu
if [ "$(uname -s)" = Linux ]; then
  # openssl-sys 0.9.103 refuses to guess without OPENSSL_DIR when no pkg-config
  # answers. The MAJOR symlink v3, not a concrete version (see
  # rust-lang.org/cargo).
  O="$${ZPKG_DIR:-$HOME/.zpkg}/openssl.org/v3"
  if [ ! -e "$O/include/openssl/ssl.h" ]; then
    echo "no openssl 3 at $O — is openssl.org ^3 a dependency?" >&2
    exit 1
  fi
  export OPENSSL_DIR="$O"

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
W="{{prefix}}/bin/wthrr"
test -x "$W"
# src/modules/args.rs:8 #[command(author, version, about)]: clap names the
# command after the package, takes the version from Cargo.toml:3 and the about
# from Cargo.toml:7. main.rs:27 parses the arguments before reading any
# configuration or touching the network.
OUT="$("$W" --version)"
if [ "$OUT" != "wthrr 1.2.1" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi
"$W" --help > help.txt
grep -q "Weather companion for the terminal" help.txt
grep -q -- "--forecast" help.txt

# OpenSSL is system-linked on linux and absent on darwin (Security.framework).
if [ "$(uname -s)" = Linux ]; then
  LIBS="$(ldd "$W")"
  case "$LIBS" in
    *libssl*) ;;
    *) echo "wthrr does not link libssl on linux:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
else
  LIBS="$(otool -L "$W")"
  case "$LIBS" in
    *libssl*) echo "wthrr links libssl on darwin, which Cargo.lock does not ask for:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
fi
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",              # :2 package, :3 version, :5 edition, :6 licence, :7 description, :13 rust-version, :34 reqwest default features, :47-49 [[bin]]
    "Cargo.lock",              # :698 native-tls 0.2.12, :774 openssl-sys 0.9.103 (cc, pkg-config, vcpkg; no openssl-src), :950 ring, :996 rustls
    "src/main.rs",             # :25-35 parse, then configuration, then the network
    "src/modules/args.rs",     # :8 command(author, version, about), :14 --forecast
    "LICENSE",                 # MIT
  ]

  consulted = [
    # Read for facts only: the repository name and the tag form. NOT taken:
    # openssl ^1.1 everywhere, rust >=1.56.
    "pkgxdev/pantry projects/crates.io/wthrr/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

The linux/darwin split of the TLS stack was measured with `cargo tree --locked
-i openssl-sys --target <triple>` on the 1.2.1 source, not read off the
lockfile alone.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only, on a loaded
machine. The first factory run is this file's test.
EOT
}
