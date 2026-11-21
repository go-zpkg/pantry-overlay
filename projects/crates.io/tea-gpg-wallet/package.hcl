# crates.io/tea-gpg-wallet — find the wallet address of a GPG key
# (jhheider/tea-gpg-wallet). A FRAGMENT until now: it named openssl ^3 and took
# its source, versions, build and test from the upstream pantry merged
# underneath. That merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is
# the WHOLE recipe, written from the project's own files (go-zpkg/packages#431,
# #440 step 1), at 0.2.0.
#
# ⭐ WHAT WRITING IT FOUND, measured with `cargo tree --locked -i <crate>
# --target <triple>` on the v0.2.0 tag:
#   - OPENSSL IS LINKED ON LINUX ONLY. reqwest 0.12.23 keeps its default
#     native-tls: openssl-sys 0.9.109 via hyper-tls and native-tls 0.2.14 on
#     x86_64-unknown-linux-gnu, "nothing to print" for aarch64-apple-darwin
#     (Security.framework answers there). The fragment declared openssl ^3
#     everywhere; it is scoped to linux now.
#   - No openssl-src in Cargo.lock: OpenSSL is never compiled in, so a missing
#     system OpenSSL fails the build. rustls and ring sit in Cargo.lock
#     (:3000, :2894) but `cargo tree -i rustls` prints nothing on linux: the
#     lockfile lists optional support the build does not use.
#   - C code is compiled by cc crates (blst, c-kzg, secp256k1-sys,
#     keccak-asm), so linux needs gcc.
#   - The workspace has `cli` (package and binary tea-gpg-wallet) and `lib`;
#     default-members is `cli`, so the binary crate is named by its path.

summary = "tea-gpg-wallet: find the wallet address of a GPG key"

# Cargo.toml workspace.package (line 12) license = "MIT"; the tarball carries no
# LICENSE file, so the manifest is the only statement. The crates of Cargo.lock
# compiled in carry their own licences, which this expression does not
# enumerate.
license = "MIT"

versions {
  github = "jhheider/tea-gpg-wallet"
  strip  = "/^v/"
}

distributable {
  # GitHub's archive of the tag v0.2.0, the newest tag and release.
  url              = "https://github.com/jhheider/tea-gpg-wallet/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 38864 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.2.0" = "df4f289a5d46335c7635fcaa44c9dcffcbc107a319aea6bb3221fd24825386d6"
  }
}

# cli/Cargo.toml: the package `tea-gpg-wallet`, whose binary has the same name.
# lib is a library and is not installed.
provides = [
  "bin/tea-gpg-wallet",
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

    # rust-version 1.89, edition 2024 (root Cargo.toml workspace.package); the
    # compiler this tree carries is named, as the other crates do.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  script = [
    {
      run = <<EOT
set -eu
if [ "$(uname -s)" = Linux ]; then
  # openssl-sys refuses to guess without OPENSSL_DIR when no pkg-config answers.
  # The MAJOR symlink v3, not a concrete version (see rust-lang.org/cargo).
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
# The workspace root has no package, so the binary crate is named by its path.
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
T="{{prefix}}/bin/tea-gpg-wallet"
test -x "$T"
# cli/src/main.rs:33 command!(): clap names the command after the package and
# takes the version from Cargo.toml. (The upstream test queries the network;
# this one does not.)
OUT="$("$T" --version)"
if [ "$OUT" != "tea-gpg-wallet 0.2.0" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi
"$T" --help > help.txt
grep -q "find" help.txt

# OpenSSL is system-linked on linux and absent on darwin (Security.framework).
if [ "$(uname -s)" = Linux ]; then
  LIBS="$(ldd "$T")"
  case "$LIBS" in
    *libssl*) ;;
    *) echo "tea-gpg-wallet does not link libssl on linux:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
else
  LIBS="$(otool -L "$T")"
  case "$LIBS" in
    *libssl*) echo "tea-gpg-wallet links libssl on darwin, which Cargo.lock does not ask for:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
fi
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",         # workspace members, default-members, workspace.package :12 licence MIT, rust-version 1.89, edition 2024
    "Cargo.lock",         # :2453 openssl-sys (no openssl-src), :2894 ring, :3000 rustls, reqwest 0.12.23, native-tls 0.2.14
    "cli/Cargo.toml",     # package tea-gpg-wallet
    "cli/src/main.rs",    # :33-36 command!() with subcommands, :36 config, :38 find
  ]

  consulted = [
    # Read for facts only: the repository name and the tag form. NOT taken:
    # openssl ^1.1 everywhere, its network test.
    "pkgxdev/pantry projects/crates.io/tea-gpg-wallet/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

The linux/darwin split of the TLS stack was measured with `cargo tree --locked
-i openssl-sys --target <triple>` on the 0.2.0 source, not read off the
lockfile alone.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only. The first
factory run is this file's test.
EOT
}
