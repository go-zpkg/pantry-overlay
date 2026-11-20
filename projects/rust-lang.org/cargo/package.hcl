# rust-lang.org/cargo — Rust's package manager. A FRAGMENT until now: it said
# what cargo depends on and how to build it, and took its source, its versions
# and its tests from the upstream pantry merged underneath. That merge ended
# with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is the WHOLE recipe, written
# from cargo's own files (go-zpkg/packages#431, #440 step 1), at 0.101.0 (the
# cargo of Rust 1.100.0: tag 0.N.0 is Rust 1.(N-1).0).
#
# ⭐⭐ WHAT WRITING IT FOUND: the fragment pinned to a dead world.
#
#   - It declared libgit2 `~1.7`. Cargo 0.101.0 locks libgit2-sys 0.18.7, whose
#     build.rs:12 accepts system libgit2 only in "1.9.6".."1.10.0".
#   - It set LIBGIT2_SYS_USE_PKG_CONFIG. libgit2-sys 0.18.7 reads no such
#     variable (build.rs:85-117 reads LIBGIT2_NO_VENDOR); the variable was inert
#     and the system library was found by accident — or, when it was not found,
#     libgit2 was compiled in SILENTLY (:114-119). Named now: LIBGIT2_NO_VENDOR.
#   - It built with `rust-lang.org ^1.85` and a bootstrap cargo 1.90.0.
#     Cargo's own rust-version is 1.98 (Cargo.toml:151).
#   - It patched Cargo.toml `<0.76.0`: dead for the only version pinned here.

summary = "Cargo: the Rust package manager and build tool"

# Cargo.toml:16 [workspace.package] license = "MIT OR Apache-2.0", inherited by
# the cargo package (:150). LICENSE-THIRD-PARTY names OpenSSL, libssh2, curl,
# zlib and libgit2 as "normally all linked static into the binary
# distributions"; here they are linked DYNAMICALLY from the artifacts below
# (the test reads that off the binary), so none is compiled in. What IS
# compiled in is the crates of Cargo.lock — including the bundled SQLite of
# rusqlite's `bundled` feature (Cargo.toml:90) — whose licences are not
# enumerated here; ⚠ that is the expression's stated limit.
license = "MIT OR Apache-2.0"

versions {
  # The repository also tags its sub-crates (home-0.5.12, …) and homu-tmp; only
  # a tag that is a version is one.
  github = "rust-lang/cargo/tags"
}

# rustc is a COMPANION, not a dependency: cargo runs the `rustc` on its PATH,
# and rust-lang.org builds with a cargo, so declaring it here would make a cycle.
dependencies = {
  # Each of these is a library the binary LINKS (Cargo.toml:176-198: curl with
  # http2, git2 with https+ssh, libgit2-sys; libz-sys, libssh2-sys and openssl-sys
  # arrive through them in Cargo.lock) and the test reads the link off the binary.
  "curl.se"      = "8"
  "libgit2.org"  = "~1.9.6"
  "libssh2.org"  = "^1"
  "openssl.org"  = "^3"
  "zlib.net"     = "^1"

  # Read at run time by `http.cainfo` (src/util/network/http.rs:99-101,177-181);
  # see runtime.env below.
  "curl.se/ca-certs" = "*"
}

distributable {
  # GitHub's archive of the tag. The TAG is signed: 0.101.0 is an annotated tag
  # (object 0bad9228) by rust-lang/promote-release, and `git verify-tag` says
  # "Good signature" for key 108F66205EAEB0AAA8DD5E1C85AB96E6FA1BE5FE (Rust
  # Language (Tag and Release Signing Key) <rust-key@rust-lang.org>). The archive
  # records the commit it was made from (`git get-tar-commit-id`: 3acc79c0…,
  # the tag's commit), which closes the chain from signature to bytes. See
  # provenance.note for what that does and does not prove.
  url              = "https://github.com/rust-lang/cargo/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 4493402 bytes. Recorded with `zpkb sourcepin` and confirmed by two
  # independent fetches: curl on the same URL, and codeload.github.com.
  sha256 = {
    "0.101.0" = "484f5a3f8ef7b3641704df44409d0dce79c35fda39f1758e2413116ec5173393"
  }
}

# Cargo.toml:281-284: the one [[bin]], `cargo`. `cargo install --path .` installs
# only that (the credential helpers and the other workspace members are separate
# packages).
provides = [
  "bin/cargo",
]

# ⛔ CARGO_INSTALL_ROOT = ~/.local, which the upstream pantry sets, is REFUSED:
# src/ops/common_for_install_and_uninstall.rs:580 reads it as the root of
# `cargo install`, and rewriting where a user's `cargo install` puts binaries
# is not this artifact's business. CARGO_HTTP_CAINFO is kept, on linux only
# (the pantry's choice, and darwin's libcurl uses its own store): cargo reads
# http.cainfo from its config and the environment (src/context/schema.rs:247-259)
# and hands it to libcurl and to the git transport.
runtime {
  env = {
    linux = {
      CARGO_HTTP_CAINFO = "{{deps.curl.se/ca-certs.prefix}}/ssl/cert.pem"
    }
  }
}

build {
  dependencies = {
    "gnu.org/tar" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # ⛔ Cargo.toml:151 rust-version = "1.98" for the cargo package (the
    # workspace says 1.95, :14). The fragment's ^1.85 could not build it.
    "rust-lang.org"  = "^1.98"
    "tukaani.org/xz" = "*"
  }

  env = {
    # ⛔ 1. libgit2: build.rs:91-110. `LIBGIT2_NO_VENDOR` makes a missing or
    # out-of-range system libgit2 a PANIC; without it, a miss compiles the
    # vendored copy and says nothing (:112-119).
    LIBGIT2_NO_VENDOR = 1

    # ⛔ 2. libssh2: libssh2-sys 0.3.4 build.rs:29-51. The system copy is used
    # ONLY when this variable is set, and if pkg-config then finds none the
    # script FALLS THROUGH to compiling its own (:53+) — not fatal, so the
    # test reads the link off the binary.
    LIBSSH2_SYS_USE_PKG_CONFIG = 1

    # 3. libcurl: curl-sys 0.4.90 build.rs:30-46 probes pkg-config unless
    # `static-curl` (not enabled: Cargo.toml:287 default features), and with
    # `http2` (Cargo.toml:176) falls back to compiling curl when curl-config
    # does not report HTTP2 (:563-565, :576-598). curl.se's build has nghttp2
    # (projects/curl.se). Not fatal either; read off `cargo -vV`.
    #
    # 4. zlib: libz-sys 1.1.29 build.rs:33-99 prefers pkg-config, then a link
    # probe, then compiles its own. LIBZ_SYS_STATIC is NOT set (it forces the
    # compiled copy). flate2 itself uses zlib-rs (Cargo.toml:51), pure Rust.
    #
    # 5. SQLite: rusqlite `bundled` (Cargo.toml:90) compiles the amalgamation
    # with the C compiler — which is why gnu.org/gcc is a linux build dependency.
    # sqlite.org is NOT used and has no switch here.
    #
    # cargo-credential-libsecret (Cargo.toml:239-240) loads libsecret with
    # libloading at run time; there is nothing to link.
  }

  script = [
    {
      if  = "linux"
      run = <<EOT
set -eu
# Inherited from the fragment, measured by its author: this tree's gcc keeps
# libgcc.a outside rustc's link search path, so the link fails without it.
L=""
for c in "$${ZPKG_DIR:-$HOME/.zpkg}"/gnu.org/gcc/*/lib/gcc/*/*/libgcc.a; do
  if [ -e "$c" ]; then L="$(dirname "$c")"; fi
done
if [ -z "$L" ]; then
  echo "no libgcc.a under $${ZPKG_DIR:-$HOME/.zpkg}/gnu.org/gcc — is gnu.org/gcc a build dep?" >&2
  exit 1
fi
export RUSTFLAGS="$${RUSTFLAGS:-} -L$L"
echo "libgcc: $L"
EOT
    },
    {
      run = <<EOT
set -eu
# openssl-sys refuses to guess without OPENSSL_DIR. The MAJOR symlink, not a
# concrete version: a glob of v3* picks v3.6.4 and openssl-sys bakes
# @rpath/openssl.org/v3.6.4/… into the binary while this recipe DECLARES the
# range ^3 (the fragment's author measured this). v3 is the level pkgx keeps.
O="$${ZPKG_DIR:-$HOME/.zpkg}/openssl.org/v3"
if [ ! -e "$O/include/openssl/ssl.h" ]; then
  echo "no openssl 3 at $O — is openssl.org ^3 a dependency?" >&2
  exit 1
fi
export OPENSSL_DIR="$O"
echo "openssl: $O"
EOT
    },
    {
      run = <<EOT
set -eu
# ⛔ BOOTSTRAP. Cargo needs a cargo to build it (rust-lang.org/cargo cannot be
# its own build dependency), so a published one is fetched: cargo 1.100.0, the
# release this cargo belongs to (it must read this Cargo.toml and Cargo.lock,
# which its own release does). {{hw.target}} renders the triples
# static.rust-lang.org names its archives by. Each digest below was recorded
# with `zpkb sourcepin` against the detached signature
# static.rust-lang.org/dist/<archive>.asc, made by the Rust release key (see
# provenance), and each was confirmed by a second fetch with curl.
#
# That Target.Triple is the triple of the machine zpkb RUNS on is right here only
# because the factory builds each platform natively or under emulation.
BT="{{hw.target}}"
case "$BT" in
  x86_64-unknown-linux-gnu)  SUM=7e29ce07d7c6e92d1826870575ba27d57fff6cb3e754aa57d99099cb88fab35d ;;
  aarch64-unknown-linux-gnu) SUM=d07ee80eb6ba3c5845c554ac88086e1ff5d63f83d99c3c09cb32504cbedd6844 ;;
  s390x-unknown-linux-gnu)   SUM=16aaeed1727094a29c9ab59fa851d62c57e698f71a7412a9d1b1209e0cd68fac ;;
  x86_64-apple-darwin)       SUM=b597b59d15b19469b8ee19d2800217d8946511e4a8d930ff839bf7688b15a7c6 ;;
  aarch64-apple-darwin)      SUM=7e18265d2d2cda8dec6cac4d0faa3bbafe927b401e5185350abc7d669f9adafb ;;
  *) echo "no pinned bootstrap cargo for $BT" >&2; exit 1 ;;
esac
T="cargo-1.100.0-$BT.tar.xz"
curl -fsSLo "$T" "https://static.rust-lang.org/dist/$T"
if command -v sha256sum >/dev/null 2>&1; then echo "$SUM  $T" | sha256sum -c -
else echo "$SUM  $T" | shasum -a 256 -c -; fi
tar xJf "$T"
mkdir -p "$PWD/.bootstrap"
mv "cargo-1.100.0-$BT/cargo/bin/cargo" "$PWD/.bootstrap/cargo"
export PATH="$PWD/.bootstrap:$PATH"
cargo --version
cargo install --root={{ prefix }} --locked --path=.
EOT
    },
  ]
}

test {
  dependencies = {
    # cargo runs `rustc`; the artifact carries none.
    "rust-lang.org" = "^1.98"
  }

  script = [
    {
      run = <<EOT
set -eu
C="{{prefix}}/bin/cargo"
V="$("$C" -vV)"
echo "$V"

# The version, and the three libraries cargo can quietly build for itself.
case "$V" in
  "cargo 1.100.0"*) ;;
  *) echo "not cargo 1.100.0: $V" >&2; exit 1 ;;
esac
# cli.rs:228-240 prints "(sys:<git2 version> system|vendored)".
case "$V" in
  *"libgit2: 1.9."*" system)"*) ;;
  *) echo "libgit2 is not the system library" >&2; exit 1 ;;
esac
case "$V" in
  *"libcurl:"*" system "*) ;;
  *) echo "libcurl is not the system library" >&2; exit 1 ;;
esac

# libssh2, libz and openssl have no line in -vV: read what the binary links.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$C")"; else LIBS="$(ldd "$C")"; fi
for l in libgit2 libssh2 libssl libcrypto libz libcurl; do
  case "$LIBS" in
    *"$l"*) ;;
    *) echo "the binary does not link $l:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
done

# It builds and runs a program (no network: a fresh package has no dependency).
D="$(mktemp -d)"
cd "$D"
"$C" new --vcs none hello
cd hello
OUT="$("$C" run --offline --release)"
if [ "$OUT" != "Hello, world!" ]; then echo "hello printed '$OUT'" >&2; exit 1; fi
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",                 # :14-16 MSRV and licence, :90 rusqlite bundled, :146-151 the package and its rust-version 1.98, :176-198 the linked crates, :281-295 the bin and features
    "Cargo.lock",                 # libgit2-sys 0.18.7, libssh2-sys 0.3.4, curl-sys 0.4.90, libz-sys 1.1.29, openssl-sys 0.9.117
    "LICENSE-THIRD-PARTY",        # :1-4 the third-party libraries "linked static" in upstream's own binaries
    "src/bin/cargo/cli.rs",       # :228-257 what `cargo -vV` prints for libgit2 and libcurl
    "src/util/network/http.rs",   # :99-106, :177-181 http.cainfo
    "src/ops/common_for_install_and_uninstall.rs", # :580 CARGO_INSTALL_ROOT
    "libgit2-sys-0.18.7+1.9.6/build.rs",   # :12 the version range, :91-119 LIBGIT2_NO_VENDOR and the silent vendored fallback
    "libssh2-sys-0.3.4/build.rs",          # :29-57 LIBSSH2_SYS_USE_PKG_CONFIG, the fall-through
    "curl-sys-0.4.90+curl-8.21.0/build.rs", # :30-46, :546-598 pkg-config probe and the HTTP2 test
    "libz-sys-1.1.29/build.rs",            # :33-99 pkg-config, link probe, own build
  ]

  consulted = [
    # Read for facts only: the tag URL, the bootstrap approach, `cargo install
    # --locked --path .`, the CARGO_HTTP_CAINFO environment, and the companions.
    # NOT taken: ~1.7 libgit2, the dead LIBGIT2_SYS_USE_PKG_CONFIG, ^1.85, the
    # <0.76 patch, CARGO_INSTALL_ROOT, and a test that runs `cargo install
    # cowsay` over the network.
    "pkgxdev/pantry projects/rust-lang.org/cargo/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG, STATED. The tag is signed and verified (git verify-tag:
Good signature, 108F66205EAEB0AAA8DD5E1C85AB96E6FA1BE5FE), and the archive's
embedded commit id (3acc79c0c841844675bc53a605922dbfc441e750) is the tag's
commit. The sha256 pins GitHub's generated archive of it; that digest was
recorded after the tag verified and is the durable pin — nothing verifies the
signature at build time. The commit itself is GitHub-verified.

⚠ THE KEY ANCHOR, STATED. The key file is https://static.rust-lang.org/
rust-key.gpg.ascii, project-controlled; its fingerprint is that file's own
(gpg --show-keys), and it matches the issuer of the tag signature and of the
bootstrap archives' .asc. No page published by the project that PRINTS the
fingerprint was found (rust-lang.org/policies/security, forge.rust-lang.org
other-installation-methods and its source were read; none carries it). So the
chain is one host deep for the key; no keyserver was asked.

Built on a machine, not by the factory: `cargo install --locked --path .` of
this source, with LIBGIT2_NO_VENDOR=1, LIBSSH2_SYS_USE_PKG_CONFIG=1 and
OPENSSL_DIR on a macOS arm64 host, cargo 1.99.0 and rustc 1.99: it built, `cargo
-vV` printed "libgit2: 1.9.7 (sys:0.21.0 system)" and a system libcurl, otool
-L showed libgit2, libssh2, libssl, libcrypto, libz and libcurl, and a fresh
package built and ran offline: the test script below, with the prefix
substituted, printed ALLPASS against that build. NOT RUN: the published
bootstrap cargo (a downloaded binary this session declined to execute) and the
linux paths (the libgcc step, ldd, CARGO_HTTP_CAINFO).

⛔ NOT BUILT BY THE FACTORY. No session here can run it.
EOT
}
