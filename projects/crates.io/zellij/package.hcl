# crates.io/zellij — Zellij, a terminal workspace with batteries included
# (zellij-org/zellij). Written whole from Zellij's own files at 0.46.0
# (go-zpkg/packages#440 step 1); there was no recipe for it.
#
# ⭐⭐ WHAT WRITING IT FOUND:
#
#   1. THE DEFAULT FEATURES COMPILE A CURL. `default` (Cargo.toml:195) includes
#      `vendored_curl`, which is `isahc/static-curl` + openssl-sys with its own
#      `vendored` feature + curl-sys (zellij-utils/Cargo.toml:52-54, :92): a
#      libcurl 8.4.0 and an OpenSSL built from source inside the binary. This
#      recipe turns `vendored_curl` OFF and keeps the other three defaults, so
#      curl-sys finds the system libcurl through pkg-config and openssl-sys finds
#      the system OpenSSL; both are declared below, from this tree.
#   2. THE BUNDLED PLUGINS ARE BINARY BLOBS IN THE SOURCE, NOT BUILT FROM IT.
#      zellij-utils/assets/plugins/*.wasm are committed prebuilt WebAssembly
#      modules that a release build embeds (zellij-utils/src/distribution.rs:236-
#      255: `plugins_from_target` only changes a DEBUG build). Building the
#      plugins from default-plugins/ needs the wasm32-wasip1 target, which this
#      tree's rustc does not carry. They are used as shipped, and that is stated
#      here so nobody reads this recipe as a build-from-source of every byte.
#   3. rust-toolchain.toml pins 1.95.0 with wasm32-wasip1 and linux-musl targets;
#      it matters only under rustup, which this tree does not use.
#
# ⛔ NOT BUILT by the factory; see the note.

summary = "zellij: a terminal workspace with batteries included"

# Cargo.toml:78 license = "MIT" (workspace.package); LICENSE.md is the MIT text.
# The crates of Cargo.lock and the committed wasm plugins carry their own
# licences, which this expression does not enumerate.
license = "MIT"

versions {
  github = "zellij-org/zellij/tags"
}

distributable {
  url              = "https://github.com/zellij-org/zellij/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 33448017 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.46.0" = "2dfa237fea447f3cc98954e81b0097b9d25841010036720e11f67880fe7861f0"
  }
}

# Cargo.toml:3 default-run = "zellij"; the package's own binary is `zellij` and
# the `terminal` feature adds [[bin]] zellij-terminal (:18-21).
provides = [
  "bin/zellij",
  "bin/zellij-terminal",
]

dependencies = {
  # curl-sys 0.4.68 (Cargo.lock) with `vendored_curl` off asks pkg-config for a
  # system libcurl. libnghttp2-sys 0.1.8 and libz-sys 1.1.8 compile their own
  # copies when no system one answers (isahc, curl 0.4.44 `http2`).
  "curl.se"  = "*"
  "zlib.net" = "^1"

  linux = {
    # openssl-sys 0.9.111 <- curl-sys `ssl` on linux (cargo tree --locked for
    # x86_64-unknown-linux-gnu); absent on darwin, which uses Security.framework.
    "openssl.org" = "^3"

    # openssl-probe 0.1.5 / 0.2.1 and rustls-native-certs 0.8.3 look for the CA
    # bundle at run time.
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

    # Cargo.toml:82 rust-version = "1.95"; edition 2021.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # ⛔ OpenSSL: openssl-sys's `vendored` feature is only on through
    # `vendored_curl`, which is off here; this makes a stray vendoring a refusal
    # instead of a silent compile (openssl-sys build/main.rs honours it).
    OPENSSL_NO_VENDOR = 1

    # ⛔ aws-lc-sys 0.39.0 (aws-lc-rs 1.16.2, via rustls) otherwise drives CMake
    # (cmake 0.1.54 is in the graph); the cc builder needs no cmake.
    AWS_LC_SYS_CMAKE_BUILDER = 0
  }

  script = [
    {
      run = <<EOT
set -eu
if [ "$(uname -s)" = Linux ]; then
  # openssl-sys refuses to guess without OPENSSL_DIR when no pkg-config answers.
  # The MAJOR symlink v3, not a concrete version (see crates.io/gitopolis).
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
# ⛔ Features, named (Cargo.toml:195): `default` is plugins_from_target,
# vendored_curl, web_server_capability, terminal. `vendored_curl` is OFF (see the
# header); the other three are kept. `unstable` and
# `disable_automatic_asset_installation` (:198-200) are off.
# ⛔ Compiled in, not switchable: libsqlite3-sys 0.27.0 (rusqlite 0.30 with
# `bundled` hard-coded, zellij-utils/Cargo.toml:58).
# ⛔ --locked: Cargo.lock is the dependency pin, and cargo verifies its checksums.
cargo install --locked --path . --no-default-features \
  --features plugins_from_target,web_server_capability,terminal \
  --root {{prefix}}
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
Z="{{prefix}}/bin/zellij"
test -x "$Z"
test -x "{{prefix}}/bin/zellij-terminal"
OUT="$("$Z" --version)"
if [ "$OUT" != "zellij 0.46.0" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi

# The configuration the binary falls back to, dumped with no terminal and no
# config file (it embeds assets/config/default.kdl).
HOME="$PWD" "$Z" setup --dump-config > config.kdl
grep -q "keybinds" config.kdl

# The system libcurl, not a compiled-in copy (`vendored_curl` is off).
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$Z")"; else LIBS="$(ldd "$Z")"; fi
case "$LIBS" in
  *libcurl*) ;;
  *) echo "zellij does not link libcurl:" >&2; echo "$LIBS" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",                  # :3-4 default-run, build; :18-25 [[bin]] zellij-terminal; :76-82 workspace.package (licence MIT, version 0.46.0, rust-version 1.95); :193-201 features; default :195
    "Cargo.lock",                  # resolved with `cargo tree --locked --target <t> -e normal,build -i <crate>` for linux-gnu and apple-darwin, with the features above: isahc 1.7.2, curl-sys 0.4.68+curl-8.4.0, libnghttp2-sys 0.1.8, libz-sys 1.1.8, aws-lc-sys 0.39.0 + cmake 0.1.54, libsqlite3-sys 0.27.0; linux only openssl-sys 0.9.111, wayland-sys 0.31.11; ssh2 is a dev-dependency only (Cargo.toml:45)
    "LICENSE.md",                  # MIT
    "rust-toolchain.toml",         # pins 1.95.0, wasm32-wasip1 and linux-musl targets; rustup only
    "src/build.rs",                # windows stack size and icon only; nothing on unix
    "zellij-terminal/build.rs",    # cfg flags only (freedesktop, bundled_emoji)
    "zellij-utils/Cargo.toml",     # :52 openssl-sys vendored, :54 curl-sys force-system-lib-on-osx, :58 rusqlite bundled, :90 plugins_from_target, :92 vendored_curl
    "zellij-utils/src/distribution.rs",  # :236-255 plugins_from_target changes only debug builds
  ]

  consulted = []

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

C LIBRARIES, NAMED: libcurl (system, curl-sys through pkg-config; `vendored_curl`
OFF); OpenSSL 3 on linux (openssl-sys, system, OPENSSL_DIR); zlib (libz-sys);
nghttp2 (libnghttp2-sys, compiled from its bundled source, not switchable);
SQLite (bundled, libsqlite3-sys 0.27.0, not switchable); aws-lc (aws-lc-sys
0.39.0, compiled from source with the cc builder). No libgit2, libssh2.

⚠ THE EMBEDDED WASM PLUGINS ARE PREBUILT BLOBS committed in the source
(zellij-utils/assets/plugins), not compiled by this recipe.

⛔ NOT BUILT by the factory. The same `cargo install` command was tried by hand
on aarch64-apple-darwin with the system toolchain. Observed: it installed
bin/zellij and bin/zellij-terminal; `zellij --version` printed `zellij 0.46.0`;
`zellij setup --dump-config` exited 0 with keybinds in the output; otool -L
showed /usr/lib/libcurl.4.dylib. Linux and the OpenSSL path were not run; the
first factory run is this file's test.
EOT
}
