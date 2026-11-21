# sniffnet — comfortably monitor your network traffic (GyulyVGC/sniffnet).
# A FRAGMENT until now: it said what the binary needs and took its source,
# versions, build and test from the upstream pantry merged underneath. That
# merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is the WHOLE recipe,
# written from sniffnet's own files (go-zpkg/packages#431, #440 step 1), at
# 1.6.0. The homepage in Cargo.toml:187 is sniffnet.app; the recipe keeps the
# name the fragment had.
#
# ⭐⭐ WHAT WRITING IT FOUND:
#
#   - The package declares NO [features] (Cargo.toml has no such table), so
#     there is nothing to name: the feature selection that exists is on the
#     dependencies and fixed in Cargo.toml:46-78 (iced 0.14 with tokio, svg,
#     advanced, lazy, image; rodio with mp3 and playback; reqwest with json).
#   - Two system libraries are linked, both through pkg-config:
#       pcap 2.5.0 (Cargo.toml:195, Cargo.lock:3745) -> libpcap. Its build.rs
#       honours LIBPCAP_LIBDIR and otherwise asks pkg-config (build.rs:182-189).
#       alsa-sys 0.4.0 (Cargo.lock:86, only reached on Linux through rodio) ->
#       alsa-lib. Its build.rs panics when pkg-config does not find "alsa"
#       (build.rs:7-13).
#     Both are whole recipes now (tcpdump.org/libpcap, alsa-project.org/alsa-lib).
#   - THE FRAGMENT'S OTHER TWO DEPENDENCIES ARE NOT LINKED. There is no
#     openssl-sys in Cargo.lock: reqwest 0.13 brings rustls on aws-lc-rs
#     (aws-lc-sys 0.47.0, Cargo.lock:450), which compiles its own C. And the
#     only fontconfig in the lock is fontconfig-parser, pure Rust. openssl.org
#     and freedesktop.org/fontconfig are therefore dropped, and that is a
#     CLAIM FROM THE LOCK FILE, not from a link-time check: the build was not run.
#   - aws-lc-sys uses its cc builder when that builder's own dependency check
#     passes and falls back to cmake otherwise (builder/main.rs:766-795), so
#     cmake is a build dependency.
#   - The window system and Vulkan are reached at run time (x11-dl and
#     wayland-sys dlopen), so no recipe is linked for them.

summary = "Sniffnet: monitor your network traffic from a desktop application"

# Cargo.toml:189 license = "MIT OR Apache-2.0"; LICENSE-MIT and LICENSE-APACHE
# are the texts. The crates compiled in carry their own licences, which this
# does not enumerate.
license = "MIT OR Apache-2.0"

versions {
  github = "GyulyVGC/sniffnet"
}

distributable {
  # GitHub's archive of the tag v1.6.0.
  url              = "https://github.com/GyulyVGC/sniffnet/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 74220982 bytes (the archive holds the repository's resources). Recorded
  # with `zpkb sourcepin` (v0.94.0) and confirmed by a second, independent
  # fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "1.6.0" = "11774fc726862325e025b0e6c6b337671eacc1305783e8da41adc9e3ea895638"
  }
}

# Cargo.toml:2 the package `sniffnet`; src/main.rs is its only binary.
provides = [
  "bin/sniffnet",
]

dependencies = {
  "tcpdump.org/libpcap" = "^1"
  linux = {
    "alsa-project.org/alsa-lib" = "^1"
  }
}

build {
  dependencies = {
    "gnu.org/tar"                = "*"
    "gnu.org/make"               = "*"
    "cmake.org"                  = "*"
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # The package's edition is 2024 (Cargo.toml:186), which needs Rust 1.85 or
    # newer; the compiler this tree carries is newer.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  script = [
    {
      run = <<EOT
set -eu
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
# No feature switch exists to pass: the package declares none (see above).
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
F="{{prefix}}/bin/sniffnet"
test -x "$F"
# clap's `version = APP_VERSION` (src/cli/mod.rs:13) answers --version without
# opening a window or a capture device.
OUT="$("$F" --version </dev/null)"
case "$OUT" in
  *{{version.raw}}*) ;;
  *) echo "sniffnet --version printed '$OUT', want it to name {{version.raw}}" >&2; exit 1 ;;
esac
# Capture goes through libpcap and sound through libasound on Linux.
if [ "$(uname -s)" = Linux ]; then
  case "$(ldd "$F")" in
    *libpcap*) ;;
    *) echo "sniffnet does not link libpcap" >&2; exit 1 ;;
  esac
  case "$(ldd "$F")" in
    *libasound*) ;;
    *) echo "sniffnet does not link libasound" >&2; exit 1 ;;
  esac
fi
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",    # :46-78 dependencies and their features, :186 edition, :189 licence, :195 pcap
    "Cargo.lock",    # :86 alsa-sys 0.4.0, :450 aws-lc-sys 0.47.0, :3745 pcap 2.5.0; no openssl-sys, only fontconfig-parser
    "src/cli/mod.rs",  # :9-15 clap Parser, version = APP_VERSION
    "pcap-2.5.0/build.rs",     # :182-189 LIBPCAP_LIBDIR else pkg-config
    "alsa-sys-0.4.0/build.rs", # :7-13 pkg-config probe "alsa", panics on a miss
    "aws-lc-sys-0.47.0/builder/main.rs",  # :766-795 cc builder or cmake
    "LICENSE-MIT",
    "LICENSE-APACHE",
  ]

  consulted = [
    # This recipe's own previous fragment (its dependency list), which the
    # lock file contradicted for openssl.org and fontconfig.
    "projects/sniffnet.net/package.hcl before this change",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

⚠ The Cargo.lock and crate readings above were made on the 1.6.0 source and on
the crates.io crates at the versions the lock names; the checks that
openssl.org and fontconfig are NOT linked come from the lock file's contents.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only. The test's
--version and ldd checks were not run; the first factory run is this file's test.
EOT
}
