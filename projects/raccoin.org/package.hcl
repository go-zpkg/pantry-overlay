# Raccoin — a crypto portfolio and tax reporting tool (bjorn/raccoin).
# A FRAGMENT until now: it said what the binary needs and took its source,
# versions, build and test from the upstream pantry merged underneath. That
# merge ended with zpkb v0.90.0 (go-zpkg/packages#431), so this is the WHOLE
# recipe, written from raccoin's own files (go-zpkg/packages#440 step 1), at
# 0.2.0. Cargo.toml:5 gives the homepage raccoin.org and :6 the repository.
#
# ⭐⭐ WHAT WRITING IT FOUND:
#
#   - It is a desktop GUI (Slint 1.3.2 with the winit backend, the femtovg and
#     software renderers: Cargo.toml:37). The linuxkms backend, which would link
#     libudev and libseat, is in Cargo.lock only as an optional dependency of
#     the backend selector; no feature here selects it. The window system and
#     OpenGL are reached at run time (wayland-sys, x11 and GL are dlopen'd).
#   - openssl.org IS LINKED on Linux: reqwest 0.11 (Cargo.toml:30) keeps its
#     default TLS, native-tls, whose openssl-sys is Cargo.lock:3750.
#   - THE FRAGMENT'S gnu.org/libiconv IS DROPPED: nothing in Cargo.lock names an
#     iconv crate. It is a CLAIM FROM THE LOCK FILE; where rustc's own link of
#     the standard library asks for libiconv (darwin), that is the SDK's.
#   - The package declares no [features] (Cargo.toml has no such table), so
#     there is nothing to name. build.rs does something only on Windows.
#   - THE BINARY HAS NO --version OR --help: src/main.rs:1543 takes the first
#     argument as a portfolio file and opens the window. The test therefore
#     checks the file and its linkage, and runs nothing.

summary = "Raccoin: crypto portfolio and tax reporting tool"

# Cargo.toml:7 license = "GPL-3.0-or-later"; LICENSE is the text.
license = "GPL-3.0-or-later"

versions {
  github = "bjorn/raccoin"
  strip  = ["/^v/"]
}

distributable {
  # GitHub's archive of the tag v0.2.0.
  url              = "https://github.com/bjorn/raccoin/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 529677 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.2.0" = "e69579407588509b738ae72294d3c6d6329338438948ac76166dbb89664c2717"
  }
}

# Cargo.toml:2 the package `raccoin`; src/main.rs is its only binary.
provides = [
  "bin/raccoin",
]

dependencies = {
  "openssl.org" = "^3"
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
F="{{prefix}}/bin/raccoin"
test -x "$F"
# Not run: it opens a window (see the head of this file). Linkage only.
if [ "$(uname -s)" = Linux ]; then
  case "$(ldd "$F")" in
    *libssl*) ;;
    *) echo "raccoin does not link libssl" >&2; exit 1 ;;
  esac
fi
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",         # :5-7 homepage, repository, licence; :30 reqwest; :37 slint features
    "Cargo.lock",         # :3750 openssl-sys, :2589 backend selector with linuxkms optional; no iconv crate
    "build.rs",           # windows-only
    "src/main.rs",        # :1539-1543 takes a portfolio file as argv[1], no --version
    "LICENSE",
  ]

  consulted = [
    "projects/raccoin.org/package.hcl before this change",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates are pinned by Cargo.lock's checksums, which cargo verifies under
--locked.

⚠ libiconv was dropped, and linuxkms's libraries judged not built, both on the
lock file and the feature list, not on a link-time check.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only. The test's ldd
check was not run; the first factory run is this file's test.
EOT
}
