# crates.io/didyoumean — a command line spelling corrector (hisbaan/didyoumean,
# binary `dym`). A FRAGMENT until now: it said what the binary links and took
# its source, versions, build and test from the upstream pantry merged
# underneath. That merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is
# the WHOLE recipe, written from didyoumean's own files (go-zpkg/packages#431,
# #440 step 1), at 1.1.4.

summary = "didyoumean (dym): a command line spelling corrector"

# Cargo.toml:6 license = "GPL-3.0"; LICENSE is the GNU GPL text. The crates of
# Cargo.lock compiled in carry their own licences, which this expression does
# not enumerate.
license = "GPL-3.0"

versions {
  github = "hisbaan/didyoumean"
  strip  = "/^v/"
}

distributable {
  # GitHub's archive of the tag v1.1.4.
  url              = "https://github.com/hisbaan/didyoumean/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 128035 bytes. Recorded with `zpkb sourcepin` (v0.92.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "1.1.4" = "367e33bd6a14800bd27164e6e1133b883ff67762a6de6c1040f15d73d83b3e3a"
  }
}

# Cargo.toml:15-17: the one [[bin]], named `dym` (the package is `didyoumean`).
provides = [
  "bin/dym",
]

dependencies = {
  # reqwest 0.11 with default features (Cargo.toml:27): native-tls, which is
  # OpenSSL through openssl-sys on linux (Cargo.lock:1161) and
  # Security.framework on darwin. Declared on every platform, as the fragment
  # did. ⚠ the darwin side was not measured.
  "openssl.org" = "^3"

  # cli-clipboard 0.2 -> x11-clipboard -> xcb 0.10.1 (Cargo.lock:2379). That
  # crate has no `links` key and no pkg-config probe: it carries
  # #[link(name = "xcb")] (src/ffi/base.rs:174, src/ffi/ext.rs:62) and the linker
  # must find libxcb itself. Linux only, as the fragment had it.
  linux = {
    "x.org/xcb" = "*"
  }
}

build {
  dependencies = {
    "gnu.org/tar" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Edition 2021 (Cargo.toml:5); no rust-version is declared and none is
    # derivable without reading every crate of the lockfile, so the compiler this
    # tree carries is named, not an invented floor.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  script = [
    {
      run = <<EOT
set -eu
# ⛔ openssl-sys refuses to guess without OPENSSL_DIR when no pkg-config
# answers. The MAJOR symlink v3, not a concrete version (see
# rust-lang.org/cargo: a glob bakes @rpath/openssl.org/v3.x.y into the binary
# while the recipe declares the range ^3). `vendored` is not enabled by any
# crate and openssl-src is not in Cargo.lock: no OpenSSL is compiled in.
O="$${ZPKG_DIR:-$HOME/.zpkg}/openssl.org/v3"
if [ ! -e "$O/include/openssl/ssl.h" ]; then
  echo "no openssl 3 at $O — is openssl.org ^3 a dependency?" >&2
  exit 1
fi
export OPENSSL_DIR="$O"

if [ "$(uname -s)" = Linux ]; then
  # xcb finds nothing by itself (see dependencies): give the linker libxcb's
  # directory, and fail now if it is not there.
  X="{{deps.x.org/xcb.prefix}}/lib"
  if ! ls "$X"/libxcb.so* >/dev/null 2>&1; then echo "no libxcb.so in $X" >&2; exit 1; fi
  # Inherited from rust-lang.org/cargo, which measured it: this tree's gcc keeps
  # libgcc.a outside rustc's link search path, so the link fails without it.
  L=""
  for c in "$${ZPKG_DIR:-$HOME/.zpkg}"/gnu.org/gcc/*/lib/gcc/*/*/libgcc.a; do
    if [ -e "$c" ]; then L="$(dirname "$c")"; fi
  done
  if [ -z "$L" ]; then echo "no libgcc.a under gnu.org/gcc" >&2; exit 1; fi
  export RUSTFLAGS="$${RUSTFLAGS:-} -L$L -L$X"
fi

# ⛔ --locked: Cargo.lock is the dependency pin, and cargo verifies its checksums.
# build.rs:14-33 also writes man/dym.1 and the shell completions into the source
# tree; they are not installed (cargo install installs the binary only).
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
D="{{prefix}}/bin/dym"
test -x "$D"
# src/cli.rs:5: #[clap(author, version = "1.1.4", about = "Did You Mean: A cli
# spelling corrector"); the command is named after the package.
OUT="$("$D" --version)"
if [ "$OUT" != "didyoumean 1.1.4" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi
"$D" --help > help.txt
grep -q "Did You Mean: A cli spelling corrector" help.txt
# The binary links what the recipe declares.
if [ "$(uname -s)" = Linux ]; then
  LIBS="$(ldd "$D")"
  for l in libssl libxcb; do
    case "$LIBS" in
      *"$l"*) ;;
      *) echo "dym does not link $l:" >&2; echo "$LIBS" >&2; exit 1 ;;
    esac
  done
fi
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",   # :6 licence, :15-17 the [[bin]] dym, :19-30 dependencies, :27 reqwest with default features
    "Cargo.lock",   # :1161 openssl-sys, :2379 xcb 0.10.1; no openssl-src
    "src/cli.rs",   # :5 the clap command: version and about
    "build.rs",     # :14-33 man page and completions written into the source tree
    "xcb-0.10.1/Cargo.toml",  # no `links`, no pkg-config
    "xcb-0.10.1/src/ffi/base.rs", # :174 #[link(name = "xcb")]
    "LICENSE",      # GNU General Public License
  ]

  consulted = [
    # Read for facts only: the tag URL, the bin name and the version string. NOT
    # taken: openssl ^1.1, rust >=1.56, and an install without --locked.
    "pkgxdev/pantry projects/crates.io/didyoumean/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only, on a loaded
machine; the linux arm (libxcb search path, libgcc step, ldd) and darwin were
not run. The first factory run is this file's test.
EOT
}
