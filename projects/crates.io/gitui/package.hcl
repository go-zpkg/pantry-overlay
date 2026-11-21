# crates.io/gitui — a blazing fast terminal UI for git (extrawurst/gitui). A
# FRAGMENT until now: it said what the binary needs and took its source,
# versions, build and test from the upstream pantry merged underneath. That
# merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is the WHOLE recipe,
# written from gitui's own files (go-zpkg/packages#431, #440 step 1), at 0.28.1.
#
# ⭐⭐ WHAT WRITING IT FOUND.
#
#   - OPENSSL IS COMPILED IN BY DEFAULT. Cargo.toml:89 default features include
#     `vendor-openssl` -> asyncgit's optional openssl-sys with
#     features = ["vendored"] (asyncgit/Cargo.toml:17,37): openssl-src
#     300.4.1+3.4.0 (Cargo.lock:2684) is built UNLESS OPENSSL_NO_VENDOR is set
#     (openssl-sys 0.9.111). The fragment's `openssl.org ^3` and `perl.org`
#     (openssl-src's build tool) described a build that compiled its own.
#     Named now: OPENSSL_NO_VENDOR=1, so a missing system OpenSSL is a panic.
#   - The fragment pinned libgit2 `~1.7`; libgit2-sys 0.18.3+1.9.2 (Cargo.lock:
#     2391) accepts "1.9.2".."1.10.0" only (build.rs:10). Now `~1.9`, with
#     LIBGIT2_NO_VENDOR (build.rs:36-48).
#   - build.rs:36-45 names the build "<version>-nightly <date> (<sha>)" and asks
#     `git rev-parse` for the sha (:3-25), unless GITUI_RELEASE is set: then it is the
#     version alone. A GitHub archive has no repository; GITUI_RELEASE=1 is set.
#   - rust-version = "1.88" (Cargo.toml:7), read from the file.

summary = "gitui: a blazing fast terminal UI for git"

# Cargo.toml:12 license = "MIT"; LICENSE.md is the MIT text. The crates of
# Cargo.lock compiled in carry their own licences, which this expression does
# not enumerate.
license = "MIT"

versions {
  github = "extrawurst/gitui/tags"
  strip  = "/^v/"
}

distributable {
  # GitHub's archive of the tag v0.28.1 (the repository also tags -rc and
  # nightly builds; only a tag that is a version is one).
  url              = "https://github.com/extrawurst/gitui/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 35109734 bytes. Recorded with `zpkb sourcepin` (v0.92.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.28.1" = "0400cbf59605490b5fb8779f9af41fa4d7a1bb748093ca0e13156a5dff31c7aa"
  }
}

# Cargo.toml:2: the package `gitui`; src/main.rs is its only binary.
provides = [
  "bin/gitui",
]

dependencies = {
  # git2 0.20 with its default features (asyncgit/Cargo.toml:25): https and ssh,
  # so libgit2-sys 0.18.3 -> libssh2-sys 0.3.1 (Cargo.lock:2422), libz-sys
  # 1.1.21 (:2436) and openssl-sys 0.9.111 (:2693).
  "libgit2.org" = "~1.9"
  "libssh2.org" = "^1"
  "openssl.org" = "^3"
  "zlib.net"    = "^1"
}

build {
  dependencies = {
    "gnu.org/tar"                = "*"
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.toml:7 rust-version = "1.88". (rust-toolchain.toml says only
    # `channel = "stable"` and is read by rustup, which this recipe does not use.)
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # ⛔ 1. libgit2: libgit2-sys 0.18.3 build.rs:36-48. LIBGIT2_NO_VENDOR makes a
    # missing or out-of-range system libgit2 a PANIC; without it a miss compiles
    # the vendored copy and says nothing.
    LIBGIT2_NO_VENDOR = 1

    # ⛔ 2. libssh2: libssh2-sys 0.3.1 build.rs:22-39. The system copy is used
    # ONLY when this variable is set, and if pkg-config then finds none the
    # script FALLS THROUGH to compiling its own — not fatal, so the test reads
    # the link off the binary.
    LIBSSH2_SYS_USE_PKG_CONFIG = 1

    # ⛔ 3. OpenSSL: the default feature `vendor-openssl` turns `vendored` ON;
    # this turns it off (openssl-sys 0.9.111 build/main.rs:49-54: find_vendored
    # is skipped when OPENSSL_NO_VENDOR exists and is not 0).
    OPENSSL_NO_VENDOR = 1

    # 4. zlib: libz-sys prefers pkg-config, then a link probe, then its own
    # build (as in rust-lang.org/cargo). LIBZ_SYS_STATIC is NOT set.
    #
    # 5. REFUSED, not compiled: oniguruma. `onig` (Cargo.lock:2650) is the
    # `regex-onig` feature, which is off; the default is `regex-fancy`
    # (Cargo.toml:89-93), pure Rust.

    # The version string: build.rs:36-45, see the header.
    GITUI_RELEASE = 1
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
# Default features are kept (ghemoji, regex-fancy, trace-libgit, vendor-openssl:
# the last one made harmless by OPENSSL_NO_VENDOR).
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
G="{{prefix}}/bin/gitui"
test -x "$G"
# src/args.rs:108: .version(GITUI_BUILD_NAME) — the bare version under
# GITUI_RELEASE, "<version>-nightly <date> (<sha>)" without it.
OUT="$("$G" --version)"
if [ "$OUT" != "gitui 0.28.1" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi
"$G" --help > help.txt
grep -q "blazing fast terminal-ui for git" help.txt

# What it links: libgit2, libssh2, OpenSSL and zlib are the system ones, none
# compiled in (the build-time switches fail loudly except libssh2 and zlib).
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$G")"; else LIBS="$(ldd "$G")"; fi
for l in libgit2 libssh2 libz; do
  case "$LIBS" in
    *"$l"*) ;;
    *) echo "gitui does not link $l:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
done
if [ "$(uname -s)" = Linux ]; then
  case "$LIBS" in
    *libssl*) ;;
    *) echo "gitui does not link libssl on linux:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
fi
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",          # :2 package, :7 rust-version 1.88, :12 licence, :15 build.rs, :89-96 features
    "Cargo.lock",          # :2391 libgit2-sys 0.18.3+1.9.2, :2422 libssh2-sys 0.3.1, :2436 libz-sys 1.1.21, :2650 onig, :2684 openssl-src 300.4.1+3.4.0, :2693 openssl-sys 0.9.111
    "asyncgit/Cargo.toml", # :17 vendor-openssl, :25 git2 0.20, :37 openssl-sys vendored
    "build.rs",            # :1-45 GITUI_RELEASE, BUILD_GIT_COMMIT_ID, the git rev-parse
    "src/args.rs",         # :108 .version(GITUI_BUILD_NAME), :112 help template
    "rust-toolchain.toml", # channel = "stable"
    "libgit2-sys-0.18.3+1.9.2/build.rs",  # :10 "1.9.2".."1.10.0", :36-48 LIBGIT2_NO_VENDOR (same crate version as gitopolis's)
    "libssh2-sys-0.3.1/build.rs",         # :22-39 LIBSSH2_SYS_USE_PKG_CONFIG
    "openssl-sys-0.9.111/build/main.rs",  # :49-54 OPENSSL_NO_VENDOR under the vendored feature
    "LICENSE.md",          # MIT
  ]

  consulted = [
    # Read for facts only: the tag URL (the repository tags `v0.28.1`), the
    # binary name, OPENSSL_NO_VENDOR and OPENSSL_DIR as the way to use a system
    # OpenSSL. NOT taken: openssl ^1.1, libgit2 ~1.7, perl, cmake, rust ^1.78
    # as a floor (the file says 1.88), `AR: llvm-ar` and `-C linker=cc`, which
    # were this recipe's linux workarounds for another toolchain.
    "pkgxdev/pantry projects/crates.io/gitui/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only, on a loaded
machine. The first factory run is this file's test.
EOT
}
