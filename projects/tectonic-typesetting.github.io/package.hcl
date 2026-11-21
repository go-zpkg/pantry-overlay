# tectonic-typesetting.github.io — Tectonic: a self-contained, modernized TeX/LaTeX
# engine (XeTeX + xdvipdfmx + bibtex, bundle fetching), as the Rust program
# `tectonic`.
#
# ⛔ WRITTEN FROM TECTONIC 0.17.0'S OWN FILES (go-zpkg/packages#440 step 1).
# Cargo, from the GitHub tag archive `tectonic@0.17.0`.
#
#   1. THE ARCHIVE HAS A Cargo.lock AND NO GIT DEPENDENCY. Cargo.lock is in the
#      tag archive (it is committed); `grep 'source = "git'` finds nothing in it,
#      and `cargo tree --locked` resolves for x86_64-unknown-linux-gnu and
#      aarch64-apple-darwin with the features below. Every crate is a crates.io
#      crate pinned by its Cargo.lock checksum, which `cargo --locked` verifies.
#   2. THE HARFBUZZ SUBMODULE IS NOT IN THE ARCHIVE. .gitmodules lists
#      crates/bridge_harfbuzz/harfbuzz (and reference_sources); a tag archive
#      carries empty directories there, and bridge_harfbuzz/build.rs:83-93
#      refuses to build without harfbuzz/src/harfbuzz.cc. The `external-harfbuzz`
#      feature (Cargo.toml:127) takes HarfBuzz from pkg-config instead
#      (bridge_harfbuzz/build.rs:6-62), which is the harfbuzz.org recipe.
#   3. THE C++ STANDARD IS FORCED TO C++14 and the system ICU is C++17 (see the
#      note): CXXFLAGS is read last by the cc crate and overrides it.
#
# ⛔ NOT BUILT; see the note.

summary = "Tectonic: a self-contained, modernized TeX/LaTeX engine"

# LICENSE is the MIT text; Cargo.toml:28 license = "MIT". The crates of
# Cargo.lock carry their own licences, which this expression does not enumerate.
license = "MIT"

versions {
  github = "tectonic-typesetting/tectonic/tags"

  # The repository tags every workspace crate: tectonic@0.17.0, but also
  # tectonic_engine_xetex@0.5.3 and so on, and a rolling `continuous` tag. Only
  # the `tectonic@X.Y.Z` tags are releases of this program.
  match = "/^tectonic@\\d+\\.\\d+\\.\\d+$/"
  strip = ["/^tectonic@/"]
}

distributable {
  # The release assets are prebuilt binaries only (tectonic-0.17.0-<target>.tar.gz,
  # .zip, .AppImage): no source asset, so the generated tag archive. 3289981
  # bytes, `zpkb sourcepin`; an independent curl fetch hashed with shasum -a 256
  # gave the same digest (same GitHub generator: a check on the transfer, not a
  # signature; the project publishes none).
  url              = "https://github.com/tectonic-typesetting/tectonic/archive/refs/tags/tectonic@{{version.raw}}.tar.gz"
  strip-components = 1

  sha256 = {
    "0.17.0" = "30adda98f67dd5389844f6023adeeb54b5475c17a54b777900644468fbc9765d"
  }
}

# Cargo.toml:71 [[bin]] name = "tectonic".
provides = [
  "bin/tectonic",
]

dependencies = {
  # The -sys bridges find these through pkg-config (dep_support/src/lib.rs:41-46
  # picks pkg-config unless TECTONIC_DEP_BACKEND says vcpkg):
  #   bridge_freetype2 "freetype2", bridge_graphite2 "graphite2",
  #   bridge_harfbuzz "harfbuzz", bridge_icu "icu-uc", bridge_png "libpng".
  "freetype.org"     = "*"
  "graphite.sil.org" = "*"
  "harfbuzz.org"     = "*"
  "libpng.org"       = "*"
  "unicode.org"      = "*"

  # libz-sys 1.1.29 (bridge_flate): pkg-config "zlib", else it compiles its own.
  "zlib.net" = "^1"

  # freetype2.pc lists bzip2, libpng, zlib and brotli in Requires.private, which
  # pkg-config resolves even for --cflags, so their .pc files must be reachable.
  "github.com/google/brotli" = "*"
  "sourceware.org/bzip2"     = "^1"

  linux = {
    # tectonic_xetex_layout depends on tectonic_bridge_fontconfig off macOS
    # (xetex_layout/Cargo.toml:37-38; macOS uses CoreText through mac_core).
    # fontconfig.pc lists expat in Requires.private.
    "freedesktop.org/fontconfig" = "*"
    "libexpat.github.io"         = "^2"

    # rustls-native-certs 0.8.4 / openssl-probe 0.2.1 are in the linux graph
    # only (cargo tree --locked): they look for the CA bundle at run time.
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
    "freedesktop.org/pkg-config" = "*"
    "gnu.org/tar"                = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # ⛔ The pkg-config crate, not a vendored copy: TECTONIC_DEP_BACKEND is read
    # at dep_support/src/lib.rs:41; "pkg-config" is also its default, stated.
    TECTONIC_DEP_BACKEND = "pkg-config"

    # ⛔ ICU 75+ headers need C++17; engine_xetex/build.rs:218 passes -std=c++14
    # and the cc crate applies CXXFLAGS after the build script's own flags
    # (cc 1.2.67 src/lib.rs:2079-2084 "do this last, to allow these to override
    # everything else").
    CXXFLAGS = "-std=c++17"

    # ⛔ aws-lc-sys 0.42.0 (aws-lc-rs 1.17.1, via rustls, reqwest's default TLS)
    # otherwise drives CMake (cmake 0.1.58 is in the graph); the cc builder
    # needs none (builder/main.rs:797 reads AWS_LC_SYS_CMAKE_BUILDER).
    AWS_LC_SYS_CMAKE_BUILDER = 0

    PKG_CONFIG_PATH = "{{deps.freetype.org.prefix}}/lib/pkgconfig:{{deps.graphite.sil.org.prefix}}/lib/pkgconfig:{{deps.harfbuzz.org.prefix}}/lib/pkgconfig:{{deps.libpng.org.prefix}}/lib/pkgconfig:{{deps.unicode.org.prefix}}/lib/pkgconfig:{{deps.zlib.net.prefix}}/lib/pkgconfig:{{deps.github.com/google/brotli.prefix}}/lib/pkgconfig:{{deps.sourceware.org/bzip2.prefix}}/lib/pkgconfig"
  }

  script = [
    {
      run = <<EOT
set -eu
if [ "$(uname -s)" = Linux ]; then
  # fontconfig is linux only; its .pc and expat's go on the path here, where the
  # dependency table above is conditional on the same platform.
  export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:{{deps.freedesktop.org/fontconfig.prefix}}/lib/pkgconfig:{{deps.libexpat.github.io.prefix}}/lib/pkgconfig"

  # Inherited from rust-lang.org/cargo, which measured it: this tree's gcc keeps
  # libgcc.a outside rustc's link search path, so the link fails without it.
  L=""
  for c in "$${ZPKG_DIR:-$HOME/.zpkg}"/gnu.org/gcc/*/lib/gcc/*/*/libgcc.a; do
    if [ -e "$c" ]; then L="$(dirname "$c")"; fi
  done
  if [ -z "$L" ]; then echo "no libgcc.a under gnu.org/gcc" >&2; exit 1; fi
  export RUSTFLAGS="$${RUSTFLAGS:-} -L$L"
fi
# ⛔ Features, named (Cargo.toml:116-138): `default` is geturl-reqwest +
# serialization. Both are kept, stated, and external-harfbuzz is added (see the
# header). OFF: geturl-curl (the other HTTP client; would pull curl-sys and
# libz-sys' own features), native-tls-vendored (compiles an OpenSSL; reqwest
# 0.13's TLS here is rustls, so no openssl-sys is in the graph: cargo tree
# --locked -i openssl-sys finds none), profile (a developer switch).
# ⛔ --locked: Cargo.lock is the dependency pin, and cargo verifies its checksums.
cargo install --locked --path . --no-default-features \
  --features geturl-reqwest,serialization,external-harfbuzz \
  --root {{prefix}}
EOT
    },
  ]
}

test {
  script = [
    "test -x {{prefix}}/bin/tectonic",
    {
      run = <<EOT
set -eu
OUT="$(tectonic --version)"
case "$OUT" in
  *"{{version.raw}}"*) ;;
  *) echo "--version printed '$OUT'" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",                          # :8-9 name, version; :28 licence; :71 [[bin]]; :116-138 features; :127 external-harfbuzz
    "Cargo.lock",                          # no `source = "git`; cargo tree --locked, -e normal,build, x86_64-unknown-linux-gnu and aarch64-apple-darwin, with the features above: reqwest 0.13.4 + rustls 0.23.41 + aws-lc-sys 0.42.0 (+ cmake 0.1.58), libz-sys 1.1.29, rustls-platform-verifier 0.7.0 (macOS: security-framework-sys), linux only rustls-native-certs 0.8.4 / openssl-probe 0.2.1; no openssl-sys, no curl-sys
    "build.rs",                            # sets TARGET only
    ".gitmodules",                         # reference_sources and crates/bridge_harfbuzz/harfbuzz are submodules, absent from the archive
    "crates/bridge_harfbuzz/build.rs",     # :6-62 external-harfbuzz probes pkg-config "harfbuzz"; :65-159 the bundled path needs the submodule
    "crates/bridge_graphite2/build.rs",    # pkg-config "graphite2"
    "crates/bridge_icu/build.rs",          # pkg-config "icu-uc"
    "crates/bridge_freetype2/build.rs",    # pkg-config "freetype2"
    "crates/bridge_png/build.rs",          # pkg-config "libpng"
    "crates/bridge_fontconfig/build.rs",   # pkg-config "fontconfig"
    "crates/xetex_layout/Cargo.toml",      # :37-41 fontconfig off macOS, mac_core on macOS; :43-44 external-harfbuzz
    "crates/engine_xetex/Cargo.toml",      # :39-43 external-harfbuzz forwards to bridge_harfbuzz and xetex_layout
    "crates/engine_xetex/build.rs",        # :218 -std=c++14 on unix (/std:c++17 on MSVC, :128)
    "crates/dep_support/src/lib.rs",       # :41-46 TECTONIC_DEP_BACKEND
    "crates/geturl/Cargo.toml",            # :22-29 curl, reqwest 0.13 (blocking), default reqwest
    "LICENSE",                             # MIT
  ]

  consulted = []

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the test
block has been run, on either platform. `cargo tree --locked` was run for both
targets (that is where the graph above comes from); a build was not, because the
libraries it links were not installed where this was written.

⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.

⚠ THE C++17 OVERRIDE IS UNVERIFIED AT BUILD TIME. engine_xetex compiles its C++
files with -std=c++14 (build.rs:218) against the ICU headers. This tree's ICU
is 79.1, whose headers need C++17 (the harfbuzz recipe notes the same threshold,
meson.build:125). CXXFLAGS=-std=c++17 is applied last by the cc crate (its
source, quoted in the recipe), so it should win; whether the xetex C++ compiles
as C++17 with -fno-exceptions -fno-rtti is what the first run tells. MSVC builds
already use /std:c++17 (build.rs:128), which is evidence for it, not proof. If it
fails, the fallback is an older ICU, as the previous fragment's ^71 asked.

⚠ HARFBUZZ 15.2.0 is far newer than anything Tectonic's own CI names; the bridge
asks pkg-config for "harfbuzz" with no version (build.rs:24), and the C++ in
xetex_layout uses the long-stable hb-ft, hb-ot and hb-icu entry points.

The fragment's openssl.org dependency is dropped: reqwest 0.13 here uses rustls
(aws-lc-rs), so no openssl-sys is in the dependency graph of either platform.
aws-lc-sys is compiled from source by the cc builder. The CA bundle is read at
run time on linux (curl.se/ca-certs, SSL_CERT_FILE) and from the Security
framework on macOS.

The first `tectonic` run downloads its TeX bundle over the network; that is the
program's job and is not part of the build, and the test does not run it.
EOT
}
