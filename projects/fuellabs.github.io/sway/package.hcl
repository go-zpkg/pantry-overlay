# fuellabs.github.io/sway — Sway, the language for the Fuel VM, and its
# toolchain `forc` (FuelLabs/sway). A FRAGMENT until now: it said `openssl.org
# ^3` and `zlib.net ^1` and took its source, versions, build and test from the
# upstream pantry merged underneath. That merge ended with zpkb v0.90.0
# (go-zpkg/zpkb#514), so this is the WHOLE recipe, written from Sway's own files
# (go-zpkg/packages#440 step 1), at 0.72.1.
#
# ⭐⭐ WHAT WRITING IT FOUND:
#
#   1. forc-pkg HARD-CODES VENDORED LIBGIT2 AND VENDORED OPENSSL
#      (forc-pkg/Cargo.toml:24: git2 features `vendored-libgit2`,
#      `vendored-openssl`), and no feature of this workspace turns them off.
#      What `cargo tree --locked` shows for x86_64-unknown-linux-gnu:
#      openssl-src 300.6.0 (OpenSSL 3.6.2 built from source, needs perl),
#      libgit2-sys 0.17.0+1.8.1, libssh2-sys 0.3.1, libz-sys 1.1.28, and
#      reqwest 0.12 on native-tls plus reqwest 0.13 on rustls/aws-lc-sys.
#   2. OPENSSL_NO_VENDOR=1 is the only switch (openssl-sys honours it over a
#      dependency's feature), so OpenSSL is the system one of this tree.
#      libgit2 is NOT switchable here: libgit2-sys 0.17.0 accepts a system
#      libgit2 only in 1.8.1..1.9.0, and this tree's libgit2.org is 1.9.x, so
#      LIBGIT2_NO_VENDOR is left unset and the bundled libgit2 1.8.1 compiles in.
#      Same for libssh2 (bundled, cc).
#   3. The workspace is a set of packages; `cargo install --path forc` installs
#      only `forc`. The plugins are separate packages, installed here one by one.
#
# ⛔ NOT BUILT by the factory; see the note.

summary = "sway: the language for the Fuel VM, and its toolchain forc"

# Cargo.toml:30 license = "Apache-2.0" (workspace.package); LICENSE is the
# Apache 2.0 text. The crates of Cargo.lock carry their own licences, which this
# expression does not enumerate.
license = "Apache-2.0"

versions {
  github = "FuelLabs/sway/tags"
  strip  = "/^v/"
}

distributable {
  url              = "https://github.com/FuelLabs/sway/archive/refs/tags/v{{version}}.tar.gz"
  strip-components = 1

  # 4116294 bytes. Recorded with `zpkb sourcepin` (v0.96.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.72.1" = "f8c6da794c520cbc76e39bb6d8d7397ee605ea39d982b3f440ed32aee254b07b"
  }
}

# forc/Cargo.toml:15-17 [[bin]] forc; the plugin packages forc-fmt, forc-lsp,
# forc-doc and forc-tx each build the binary of their name. NOT installed:
# forc-debug, forc-migrate, forc-publish (see the note).
provides = [
  "bin/forc",
  "bin/forc-doc",
  "bin/forc-fmt",
  "bin/forc-lsp",
  "bin/forc-tx",
]

dependencies = {
  # openssl-sys 0.9.116 (native-tls <- reqwest 0.12; git2 https; libssh2-sys)
  # through OPENSSL_DIR; libz-sys 1.1.28 asks pkg-config for zlib.
  "openssl.org" = "^3"
  "zlib.net"    = "^1"

  linux = {
    # openssl-probe 0.1.6 / 0.2.1 look for the CA bundle at run time.
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
    "gnu.org/make"               = "*"
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # ⛔ OpenSSL: forc-pkg turns openssl-sys `vendored` on; this makes it use
    # OPENSSL_DIR (set in the script) instead of compiling openssl-src.
    OPENSSL_NO_VENDOR = 1

    # ⛔ aws-lc-sys 0.41.0 (aws-lc-rs 1.17.0, via rustls in reqwest 0.13)
    # otherwise drives CMake (cmake 0.1.58 is in the graph); the cc builder
    # needs no cmake.
    AWS_LC_SYS_CMAKE_BUILDER = 0
  }

  script = [
    {
      run = <<EOT
set -eu
# openssl-sys refuses to guess without OPENSSL_DIR when no pkg-config answers.
# The MAJOR symlink v3, not a concrete version (see crates.io/zellij).
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
# ⛔ Features, named: forc `default = []` (forc/Cargo.toml:20), so there is
# nothing to switch; the plugin packages declare none of their own either.
# ⛔ --locked: Cargo.lock is the dependency pin, and cargo verifies its checksums.
cargo install --locked --path forc --root {{prefix}}
cargo install --locked --path forc-plugins/forc-doc --root {{prefix}}
cargo install --locked --path forc-plugins/forc-fmt --root {{prefix}}
cargo install --locked --path forc-plugins/forc-lsp --root {{prefix}}
cargo install --locked --path forc-plugins/forc-tx --root {{prefix}}
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
F="{{prefix}}/bin/forc"
test -x "$F"
for b in forc-doc forc-fmt forc-lsp forc-tx; do test -x "{{prefix}}/bin/$b"; done
OUT="$("$F" --version)"
if [ "$OUT" != "forc 0.72.1" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi

# A project is created and its template checked by the formatter.
"$F" init --path demo --name demo
test -s demo/src/main.sw
"{{prefix}}/bin/forc-fmt" --path demo --check
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",                       # :26 edition 2021, :27 version 0.72.1, :30 license Apache-2.0; :152 git2 0.19, :195 reqwest 0.12
    "Cargo.lock",                       # resolved with `cargo tree --locked -p forc --target <t> -e normal,build` for linux-gnu and apple-darwin, and `-e features -i openssl-src / -i libgit2-sys`: openssl-src 300.6.0+3.6.2, libgit2-sys 0.17.0+1.8.1, libssh2-sys 0.3.1, libz-sys 1.1.28, aws-lc-sys 0.41.0 + cmake 0.1.58, secp256k1-sys 0.10.1
    "LICENSE",                          # Apache 2.0
    "forc/Cargo.toml",                  # :15-17 [[bin]] forc; :19-23 features, default = []
    "forc-pkg/Cargo.toml",              # :24 git2 with vendored-libgit2 and vendored-openssl
    "forc-plugins/forc-doc/Cargo.toml", # package forc-doc
    "forc-plugins/forc-fmt/Cargo.toml", # package forc-fmt
    "forc-plugins/forc-lsp/Cargo.toml", # package forc-lsp
    "forc-plugins/forc-tx/Cargo.toml",  # :14-15 [[bin]] forc-tx
  ]

  consulted = [
    # Read for facts only: `cargo install --path forc` and the bin names. NOT
    # taken: the openssl pin, the test.
    "pkgxdev/pantry projects/fuellabs.github.io/sway/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

C LIBRARIES, NAMED: OpenSSL 3 (system, openssl-sys through OPENSSL_DIR with
OPENSSL_NO_VENDOR=1); zlib (libz-sys); libgit2 1.8.1 and libssh2 (bundled,
compiled by their -sys crates, NOT switchable here, see the header); aws-lc
(aws-lc-sys, cc builder); secp256k1 (bundled).

Not installed: forc-debug, forc-migrate and forc-publish, which this recipe did
not read the dependency graphs of. Add them when someone does.

⛔ NOT BUILT by the factory, and NOT BUILT by hand (the build was not run for
this recipe). What was run: `cargo tree --locked` for both targets. The test's
`forc init` / `forc-fmt --check` behaviour and `--version` text are unverified.
EOT
}
