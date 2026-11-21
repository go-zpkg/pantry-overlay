# cargo-c — cargo subcommands to build and install C-ABI libraries from Rust
# crates (cargo cbuild, cinstall, ctest, capi).
#
# A WHOLE recipe, written from the project's own Cargo.toml and the Cargo.lock
# it publishes with each release (go-zpkg/packages#440, step 1). It was a
# fragment: five dependencies and nothing else.

summary = "Cargo subcommands to build and install C-ABI libraries from Rust crates"

# Cargo.toml:5 `license = "MIT"`.
license = "MIT"

versions {
  github = "lu-zero/cargo-c"
  strip  = "/^v/"
}

dependencies = {
  # Libraries the binaries LINK, through the cargo crate (Cargo.toml:31
  # `cargo = "0.100.0"`): curl-sys, libgit2-sys, libssh2-sys, libz-sys and
  # openssl-sys all appear in the release's Cargo.lock. The set is the one
  # rust-lang.org/cargo declares, for the same reason; the ranges follow it.
  "curl.se"     = "8"
  "libgit2.org" = "~1.9.6"
  "libssh2.org" = "^1"
  "openssl.org" = "^3"
  "zlib.net"    = "^1"
}

distributable {
  # GitHub's archive of the tag. NOT the stored asset, because upstream stores
  # none that is source: the release assets are prebuilt binaries and one file,
  # Cargo.lock (pinned below). A generated archive is the fragile kind of pin,
  # recorded here rather than hidden.
  url              = "https://github.com/lu-zero/cargo-c/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 41528 bytes, from `zpkb sourcepin` and a second independent fetch-and-hash
  # (`curl -L` + `shasum -a 256`): the same digest. Nothing is signed.
  sha256 = {
    "0.10.26" = "57700786539a322a50f1848332e3465bf15efa5af2fd8b6113f36cbfce46c830"
  }
}

# ⛔ THE TAG HAS NO Cargo.lock; THE RELEASE DOES. The repository tree at v0.10.26
# holds no lock file (contents listing: .github .gitignore Cargo.toml LICENSE
# README.md codecov.yml coverage.sh docs example-project example-workspace src),
# and the release lists `Cargo.lock` beside the binaries. Without it `--locked`
# is a refusal and an unlocked build resolves whatever crates.io serves today.
# It is fetched here as a pinned `sources` file rather than inside the build.
sources = [
  {
    url       = "https://github.com/lu-zero/cargo-c/releases/download/v{{version.raw}}/Cargo.lock"
    extract   = false
    sha256    = { "0.10.26" = "d3cb865d40625de197b71fa591f1f24c0593b5a24b46b7c126eae7fecf7be315" }
  },
]

# Cargo.toml:14-28: four [[bin]], and `cargo install --path .` installs exactly
# those.
provides = [
  "bin/cargo-capi",
  "bin/cargo-cbuild",
  "bin/cargo-cinstall",
  "bin/cargo-ctest",
]

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.toml:12 rust-version = "1.97", edition 2021. The compiler this tree
    # carries is named, as the other cargo recipes here do.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # ⛔ libgit2: libgit2-sys 0.18.8+1.9.7 (Cargo.lock) reads LIBGIT2_NO_VENDOR;
    # set, a missing or out-of-range system libgit2 is a panic, unset it is
    # silently compiled in. Read from rust-lang.org/cargo's recipe, which read it
    # in the crate's build.rs.
    LIBGIT2_NO_VENDOR = 1

    # libssh2-sys 0.3.3 uses the system copy ONLY when this is set (same source);
    # a miss falls through to compiling its own, so the test below reads the link
    # off the binaries.
    LIBSSH2_SYS_USE_PKG_CONFIG = 1

    # curl-sys 0.4.91 and libz-sys 1.1.29 probe pkg-config first. cargo-c enables
    # none of the `static-curl` / `vendored-openssl` options: Cargo.toml:52-54
    # `default = []`, and `vendored-openssl` is the only feature, left off.
  }

  script = [
    {
      run = <<EOT
set -eu
# ⛔ The release's Cargo.lock (a `sources` file) must sit beside Cargo.toml.
test -f Cargo.lock

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

# openssl-sys 0.9.117 refuses to guess without OPENSSL_DIR. The MAJOR symlink v3,
# not a concrete version (see rust-lang.org/cargo).
O="$${ZPKG_DIR:-$HOME/.zpkg}/openssl.org/v3"
if [ ! -e "$O/include/openssl/ssl.h" ]; then
  echo "no openssl 3 at $O — is openssl.org ^3 a dependency?" >&2
  exit 1
fi
export OPENSSL_DIR="$O"

cargo install --locked --path . --root {{prefix}}
EOT
    },
  ]
}

test {
  script = [
    "test -x {{prefix}}/bin/cargo-capi",
    "test -x {{prefix}}/bin/cargo-cbuild",
    "test -x {{prefix}}/bin/cargo-cinstall",
    "test -x {{prefix}}/bin/cargo-ctest",
    "{{prefix}}/bin/cargo-cbuild --version",
    "{{prefix}}/bin/cargo-cinstall --help",
  ]
}

provenance {
  read = [
    "Cargo.toml",   # :3 version 0.10.26+cargo-0.100.0; :5 MIT; :12 rust-version 1.97; :14-28 four bins; :31 cargo 0.100.0; :52-54 features
    "https://github.com/lu-zero/cargo-c/releases/download/v0.10.26/Cargo.lock",  # :826 curl-sys, :2596 libgit2-sys 0.18.8+1.9.7, :2641 libssh2-sys 0.3.3, :2655 libz-sys, :3063 openssl-sys
    "the repository tree listing at v0.10.26 (no Cargo.lock) and the release asset listing (Cargo.lock beside binaries)",
  ]

  consulted = [
    "pkgxdev/pantry projects/github.com/lu-zero/cargo-c/package.yml",
    "projects/rust-lang.org/cargo/package.hcl (this tree): LIBGIT2_NO_VENDOR, LIBSSH2_SYS_USE_PKG_CONFIG, the libgcc and OPENSSL_DIR handling",
  ]

  note = <<EOT
⛔ NOT BUILT. No session here can run the factory. The README was not read; the
inputs come from Cargo.toml, the release's Cargo.lock and the sibling
rust-lang.org/cargo recipe, whose dependency set this one mirrors.

⚠ HOW THE LOCK FILE REACHES THE BUILD IS READ, NOT RUN. zpkb's schema says a
`sources` entry with `extract: false` is copied into the build directory (the
default `dest`) under the last segment of its URL's path, i.e. as `Cargo.lock`,
which is where cargo reads it. No other recipe here uses `sources` yet; the
script asserts the file is there.
EOT
}
