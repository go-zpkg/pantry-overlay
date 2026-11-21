# crates.io/spotify_player — a Spotify player in the terminal
# (aome510/spotify-player). Written whole from the project's own files at
# 0.25.2 (go-zpkg/packages#440 step 1); the earlier recipe was a fragment that
# stated only dependencies.
#
# ⭐ WHAT WRITING IT FOUND:
#
#   1. THERE IS NO libsixel. The fragment depended on github.com/libsixel/libsixel,
#      and nothing in the project links it. The `sixel` feature (Cargo.toml:104)
#      is `sixel = ["image"]`, and the sixel encoder it reaches is the Rust crate
#      `icy_sixel` (Cargo.lock:2458, pulled by ratatui-image). The feature is OFF
#      here anyway (see the build), and libsixel is NOT a dependency.
#   2. THE DEFAULT FEATURES (Cargo.toml:118) are rodio-backend, media-control and
#      rustls-tls. On Linux they reach three C libraries through pkg-config —
#      alsa (alsa-sys, via cpal, via rodio), dbus (libdbus-sys, via souvlaki) and
#      OpenSSL (openssl-sys, via native-tls, which librespot-playback asks for
#      at Cargo.toml:20 whatever the `rustls-tls` feature says). On macOS none.
#
# ⛔ NOT BUILT by the factory; see the note.

summary = "spotify_player: a terminal Spotify player (TUI)"

# Cargo.toml:6 license = "MIT"; the LICENSE file is the MIT text. The crates of
# Cargo.lock carry their own licences, which this expression does not enumerate.
license = "MIT"

versions {
  github = "aome510/spotify-player"
}

distributable {
  # The GENERATED tag archive: the release's stored assets are prebuilt
  # binaries per target, not a source tarball, so there is no stored source to
  # prefer.
  url              = "https://github.com/aome510/spotify-player/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 0.25.2: 216095 bytes. Recorded with `zpkb sourcepin` and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256. The project
  # publishes no signature for the source; its .sha256 files cover the prebuilt
  # binaries only.
  sha256 = {
    "0.25.2" = "60cc7cd60f66729039c0a48b134d8032c14817c88210d420722ad08340ad15cc"
  }
}

# spotify_player/Cargo.toml:2 is the only package of the workspace
# (Cargo.toml:2 members), and it has no [[bin]] section, so the binary is named
# after the package.
provides = [
  "bin/spotify_player",
]

dependencies = {
  linux = {
    # alsa-sys 0.3.1 (Cargo.lock; cargo tree --locked, x86_64-unknown-linux-gnu,
    # features below, reached from cpal 0.16.0 <- rodio 0.21.1).
    "alsa-project.org/alsa-lib" = "^1"

    # libdbus-sys 0.2.7 <- dbus 0.9.12 <- souvlaki 0.8.3 (`media-control`).
    "freedesktop.org/dbus" = "^1"

    # openssl-sys 0.9.117 <- native-tls 0.2.18 <- librespot-core 0.8.0 and
    # reqwest. Absent on darwin (cargo tree --target aarch64-apple-darwin
    # finds no openssl-sys), which uses Security.framework.
    "openssl.org" = "^3"
  }
}

build {
  dependencies = {
    "gnu.org/tar"                = "*"
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Edition 2021; Cargo.lock resolves crates that need a current rustc.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # aws-lc-sys is not in this graph (rustls is built with `ring`,
    # Cargo.toml:65), so no cmake is needed.
    OPENSSL_NO_VENDOR = 1
  }

  script = [
    {
      run = <<EOT
set -eu
if [ "$(uname -s)" = Linux ]; then
  # openssl-sys refuses to guess without OPENSSL_DIR when no pkg-config answers.
  # The MAJOR symlink v3, not a concrete version (see crates.io/zellij).
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
# ⛔ Features, named (spotify_player/Cargo.toml:92-118). ON: rodio-backend (the
# audio sink; implies streaming, :101), media-control (OS media keys, souvlaki),
# rustls-tls (:115). OFF: the seven other audio backends (alsa-backend,
# pulseaudio-backend, portaudio-backend, jackaudio-backend, rodiojack-backend,
# sdl-backend, gstreamer-backend), image / sixel / pixelate (album art),
# notify (desktop notifications), daemon, fzf, native-tls (:116; librespot
# links native-tls on its own, see the header).
# ⛔ --locked: Cargo.lock is the dependency pin, and cargo verifies its checksums.
cargo install --locked --path spotify_player --no-default-features \
  --features rodio-backend,media-control,rustls-tls \
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
S="{{prefix}}/bin/spotify_player"
test -x "$S"
OUT="$("$S" --version)"
case "$OUT" in
  *{{version.raw}}*) ;;
  *) echo "--version printed '$OUT'" >&2; exit 1 ;;
esac
"$S" --help > help.txt
grep -q "playback" help.txt
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",                    # :1-2 workspace with the one member spotify_player
    "spotify_player/Cargo.toml",     # :3 version 0.25.2; :6 licence MIT; :20 librespot-playback native-tls; :65 rustls ring; :70 ratatui-image; :92-118 features, default :118
    "Cargo.lock",                    # `cargo tree --locked --offline -e normal,build -i <crate>` with the features above, for x86_64-unknown-linux-gnu and aarch64-apple-darwin: alsa-sys 0.3.1, libdbus-sys 0.2.7, openssl-sys 0.9.117 (linux only); no libpulse-sys, no aws-lc-sys; icy_sixel at :2458
    "LICENSE",                       # MIT
    "AGENTS.md",                     # the feature table and the CI feature list
  ]

  consulted = []

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
signature for the source, only .sha256 files beside the prebuilt binaries; the
digest records GitHub's generated archive, fetched twice (the builder's
fetcher, curl) with one answer. The crates it compiles are pinned by
Cargo.lock's checksums, which cargo verifies under --locked.

libsixel is NOT used (see the header): the earlier fragment named it, and the
project's lockfile contains only the Rust crate icy_sixel.

⛔ NOT BUILT. Nothing was compiled in this session. The dependency graph was
read with `cargo tree --locked --offline` for both target triples; the test
block assumes `--version` prints the version number somewhere and that
`--help` mentions "playback" (the subcommand is declared at
spotify_player/src/cli/commands.rs:98).
EOT
}
