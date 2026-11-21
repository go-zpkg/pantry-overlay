# wezfurlong.org/wezterm — WezTerm, a GPU-accelerated cross-platform terminal
# emulator and multiplexer (github.com/wezterm/wezterm). Written whole from
# WezTerm's own files at 20240203-110809-5046fc22 (go-zpkg/packages#440 step 1);
# the previous file was a fragment with dependencies only.
#
# ⭐⭐ WHAT WRITING IT FOUND:
#
#   1. THE RELEASE PUBLISHES THE SOURCE WITH ITS SUBMODULES, AND ASKS FOR IT.
#      The repository's freetype, harfbuzz, cairo, pixman, libpng and zlib are
#      git submodules (.gitmodules), which a GitHub-generated tag archive does
#      NOT contain. README-DISTRO-MAINTAINER.md says: "Please package using the
#      `wezterm-YYYYMMDD-HHMMSS-HASH-src.tar.gz` release asset from the release,
#      rather than the automatic GitHub source tarball. Not only is it a smaller
#      download, but it already contains an appropriate `.tag` file". That asset
#      is what this recipe fetches (41444064 bytes), and it carries deps/*/ with
#      their sources and `.tag` = 20240203-110809-5046fc22.
#   2. THE TAG IS A DATE, NOT A SEMVER, AND `versions` HAS TWO STEPS FOR IT.
#      Tags look like `20240203-110809-5046fc22`. `strip` removes the trailing
#      `-<8 hex>` commit abbreviation, leaving the all-numeric `20240203-110809`,
#      which zpkb's CalVer step (versions/versions.go calverToDotted) turns into
#      `20240203.110809`: a version that sorts by date and time. The full tag is
#      `{{version.tag}}`, and it is what the asset URL needs; the hash cannot be
#      derived from the version.
#   3. `wezterm --version` PRINTS THE TAG, NOT A VERSION NUMBER. wezterm-version/
#      build.rs reads `../.tag` when it exists (else it runs git, which a
#      tarball has no repository for), so the shipped `.tag` file is what makes
#      the binary report itself correctly. The test asserts it.
#   4. LINUX IS NOT WRITTEN. window/Cargo.toml:70-82 pulls xcb, xcb-imdkit,
#      xkbcommon (x11 + wayland), x11 and wayland-* on unix-not-macos, and
#      get-deps names xcb-util, xcb-util-image, xcb-util-keysyms, xcb-util-wm,
#      libxkbcommon(-x11), wayland and an EGL provider. This tree has x.org/xcb,
#      x.org/x11 and freedesktop.org/fontconfig but none of xkbcommon, wayland,
#      xcb-util-* or a Mesa/EGL, so `platforms` says darwin only rather than
#      declaring dependencies that do not exist.
#
# ⛔ NOT BUILT by the factory; see the note.

summary = "WezTerm: GPU-accelerated terminal emulator and multiplexer, in Rust"

# LICENSE.md is the MIT licence text ("Copyright (c) 2018-Present Wez Furlong").
# The vendored fonts carry their own (JetBrains Mono OFL, Roboto Apache-2.0,
# Noto Emoji OFL, Nerd Font Symbols), as do the crates in Cargo.lock.
license = "MIT"

platforms = ["darwin"]

versions {
  github = "wezterm/wezterm/tags"
  strip  = ["/-[0-9a-f]{8}$/"]
}

distributable {
  # The stored release asset, not archive/refs/tags (see point 1).
  url              = "https://github.com/wezterm/wezterm/releases/download/{{version.tag}}/wezterm-{{version.tag}}-src.tar.gz"
  strip-components = 1

  # 41444064 bytes. Recorded with `zpkb sourcepin` (v0.97.0), and equal to the
  # digest in the release's own checksum file, wezterm-20240203-110809-5046fc22-
  # src.tar.gz.sha256 ("df60b1081d40…  wezterm-…-src.tar.gz"), fetched separately.
  # Both come from the same GitHub release host: the project publishes no
  # signature, so the second witness is the author's own file, not an
  # independent origin.
  sha256 = {
    "20240203.110809" = "df60b1081d402b5a9239cc4cef16fc699eab68bbbeac9c669cb5d991a6010b2c"
  }
}

provides = [
  "bin/wezterm",
  "bin/wezterm-gui",
  "bin/wezterm-mux-server",
  "bin/strip-ansi-escapes",
]

dependencies = {
  # libz-sys 1.1.15 (Cargo.lock) uses the system zlib it finds through
  # pkg-config, as do libssh-rs-sys and libssh2-sys.
  "zlib.net" = "^1"

  # openssl-sys 0.9.99 <- libssh2-sys 0.3.0 and libssh-rs-sys 0.2.2, both on by
  # wezterm-ssh's defaults (wezterm-ssh/Cargo.toml:14). The `vendored-openssl`
  # features (:15-17) are off, so it is the system OpenSSL; Cargo.lock also
  # lists openssl-src 300.2.1, which only the `vendored` feature of openssl-sys
  # would compile (async_ossl/Cargo.toml:14, a target-specific table).
  "openssl.org" = "^3"
}

build {
  dependencies = {
    "gnu.org/tar"                = "*"
    "freedesktop.org/pkg-config" = "*"

    # libssh-rs has `vendored` on (wezterm-ssh/Cargo.toml:34): libssh-rs-sys then
    # configures a bundled libssh, and get-deps lists `cmake` for every distro.
    "cmake.org" = "*"

    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
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

# ⛔ Features, named (README-DISTRO-MAINTAINER.md "Building wezterm" and
# "Building without wayland support"): `--no-default-features` drops `wayland`
# (wezterm-gui/Cargo.toml:12, a no-op on darwin where window/Cargo.toml:70 does
# not apply) and keeps nothing implicit; `distro-defaults` makes
# check_for_updates default to false; `vendored-fonts` compiles in JetBrains
# Mono, Roboto, Noto Color Emoji and Symbols Nerd Font Mono (:19-24), the two
# the README says the default config needs to start.
# ⛔ --locked: Cargo.lock is the dependency pin. One crate is a GIT dependency,
# xcb-imdkit (window/Cargo.toml:82, Cargo.lock:7211), and it is under the
# unix-not-macos table; cargo resolves the lockfile for every target, so cargo
# itself fetches that repository at the pinned rev. That is a fetch by cargo,
# not by this script, and an offline build would need `cargo vendor` first.
cargo build --release --locked \
  -p wezterm -p wezterm-mux-server -p strip-ansi-escapes \
  -p wezterm-gui --no-default-features --features wezterm-gui/distro-defaults,wezterm-gui/vendored-fonts

mkdir -p "{{prefix}}/bin" "{{prefix}}/share/wezterm"
for b in wezterm wezterm-gui wezterm-mux-server strip-ansi-escapes; do
  cp "target/release/$b" "{{prefix}}/bin/$b"
done
# README-DISTRO-MAINTAINER.md "Additional Resources": shell integration and
# completion are deployed with the `wezterm` executable.
cp -R assets/shell-integration assets/shell-completion "{{prefix}}/share/wezterm/"
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
W="{{prefix}}/bin/wezterm"
for b in wezterm wezterm-gui wezterm-mux-server strip-ansi-escapes; do
  test -x "{{prefix}}/bin/$b"
done
# The shipped `.tag` is what the binary reports (wezterm-version/build.rs).
OUT="$("$W" --version)"
case "$OUT" in
  *20240203-110809-5046fc22*) ;;
  *) echo "--version printed '$OUT', not the release tag" >&2; exit 1 ;;
esac
test -f "{{prefix}}/share/wezterm/shell-integration/wezterm.sh"
# strip-ansi-escapes removes the escape and keeps the text.
OUT="$(printf '\033[1mbold\033[0m\n' | "{{prefix}}/bin/strip-ansi-escapes")"
if [ "$OUT" != "bold" ]; then echo "strip-ansi-escapes printed '$OUT'" >&2; exit 1; fi
EOT
    },
  ]
}

provenance {
  read = [
    "README-DISTRO-MAINTAINER.md",  # versioning (.tag), the src asset recommendation, the four binaries, the features to build with, un-bundling fonts, building without wayland
    "Cargo.toml",                   # :1-15 workspace members; :30-33 [patch.crates-io] cairo-sys-rs = deps/cairo
    "Cargo.lock",                   # :7211 xcb-imdkit is the only git source; libssh-rs-sys 0.2.2, libssh2-sys 0.3.0, libz-sys 1.1.15, openssl-sys 0.9.99 (+ openssl-src 300.2.1), mlua 0.9.5 + lua-src 546.0.2, no cmake crate
    "LICENSE.md",                   # MIT
    ".tag",                         # 20240203-110809-5046fc22
    "wezterm-version/build.rs",     # reads ../.tag, else git
    "wezterm-gui/Cargo.toml",       # :11-26 features default = vendored-fonts + wayland; distro-defaults; the vendor-*-font features
    "wezterm-font/Cargo.toml",      # :9-13 the vendor-* features are empty flags
    "wezterm-ssh/Cargo.toml",       # :13-17 default = libssh-rs + ssh2; vendored-openssl features; :34 libssh-rs vendored
    "window/Cargo.toml",            # :17-18 wayland feature; :70-82 unix-not-macos table incl. the xcb-imdkit git dependency
    "config/Cargo.toml",            # :26 mlua vendored lua54
    "deps/fontconfig/build.rs",     # pkg-config probe, deliberately not an error when absent
    "deps/freetype/build.rs",       # compiles bundled zlib, libpng, freetype with cc
    "deps/harfbuzz/build.rs",       # compiles bundled harfbuzz with cc
    "deps/cairo/build.rs",          # compiles bundled pixman and cairo with cc
    "get-deps",                     # the per-distro build dependency list (cmake, fontconfig, openssl, xcb-util*, xkbcommon, wayland, EGL)
  ]

  consulted = []

  note = <<EOT
⚠ THE SOURCE RUNG: the digest of the stored release asset, recorded with
`zpkb sourcepin` and equal to the release's own .sha256 file. Same host, so
the project's published checksum is the second witness; no signature exists.

⚠ DARWIN ONLY, AND WHY: see point 4 of the header. The Linux build needs
xkbcommon, wayland, xcb-util-* and EGL libraries that are not recipes in this
tree; it can be added by writing them.

⚠ SELECTED BY READING, NOT TRIED: that `cmake` is what libssh-rs-sys's bundled
libssh needs (the crate source was not available here, only get-deps and the
Cargo.lock without a cmake crate suggest it); that `-p ... --features
wezterm-gui/...` resolves the way README-DISTRO-MAINTAINER.md's single-package
command does when four packages are named; that the darwin binaries need no
extra framework-linking flags beyond what the crates' build scripts emit.

⛔ NOT BUILT by the factory, and not built by hand either: the compile of the
whole crate graph plus freetype, harfbuzz, cairo, pixman, libpng, Lua and libssh was not
run. Lint only. The first factory run is this file's test.
EOT
}
