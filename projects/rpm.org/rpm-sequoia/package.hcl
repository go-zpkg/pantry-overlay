# rpm-sequoia — an implementation of rpm's OpenPGP interface (rpmpgp.h) on the
# Sequoia OpenPGP library, as one shared library, librpm_sequoia.
#
# A WHOLE recipe, written from the project's own Cargo.toml, build.rs and
# README (go-zpkg/packages#440, step 1). It was a fragment: dependencies, a
# build and a test, with no versions and no distributable.

summary = "rpm's OpenPGP interface implemented on Sequoia, as a shared library"

# Cargo.toml:11 `license = "LGPL-2.0-or-later"`; LICENSE.txt opens "GNU Library
# General Public License ... either version 2 of the License, or (at your
# option) any later version". The crates it links carry their own licences and
# are not summarised here.
license = "LGPL-2.0-or-later"

versions {
  github = "rpm-software-management/rpm-sequoia"
  strip  = "/^v/"
}

dependencies = {
  # Cargo.toml:49 `crypto-openssl` is the backend this recipe selects, which
  # links libssl/libcrypto. Cargo.lock:1449-1450 pins openssl-sys 0.9.117, which
  # accepts any 3.x.
  "openssl.org" = "^3"
}

distributable {
  # ⚠ A GENERATED TAG ARCHIVE, because upstream publishes none other: the
  # GitHub releases list is empty (tags only, v1.10.3 newest). That is the
  # fragile kind of pin (an archive GitHub regenerates can change its bytes),
  # recorded here rather than hidden. The `--locked` build below is what makes
  # the CONTENT reproducible: Cargo.lock pins every crate and cargo verifies
  # their checksums.
  url              = "https://github.com/rpm-software-management/rpm-sequoia/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 107091 bytes, from `zpkb sourcepin`, and confirmed by a second independent
  # fetch-and-hash (`curl -L` + `shasum -a 256`): the same digest. No signature
  # or checksum file is published beside the tag.
  sha256 = {
    "1.10.3" = "64de2578534e2d46079050ba79d4c1a462d7aa2cde01e619ecf99b7084e58044"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.toml:13 rust-version = "1.85", edition 2021. The compiler this tree
    # carries is named, as the other cargo recipes here do.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  # ⛔ THE crypto BACKEND IS NAMED, AND THE DEFAULT IS NOT TAKEN. Cargo.toml:45
  # `default = ["crypto-nettle"]`, which needs libnettle (README.md:38-46). The
  # README gives the OpenSSL spelling at :62-66, and it is what the fragment
  # used: `--no-default-features --features crypto-openssl`.
  #
  # PREFIX and LIBDIR are read by build.rs:107-123 to fill rpm-sequoia.pc.in
  # (`prefix=@PREFIX@`, `libdir=@LIBDIR@`) and to set the soname and rpath
  # (:168-176). So the .pc file is GENERATED CORRECTLY by the build, and the
  # fragment's `sed s|/usr/local|…|` is not needed. LIBDIR keeps the literal
  # ${prefix} the README documents (:83-85) so the file stays relocatable.
  script = [
    {
      run = <<EOT
set -eu
export OPENSSL_DIR="{{deps.openssl.org.prefix}}"
export PREFIX="{{prefix}}"
export LIBDIR='$${prefix}/lib'

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

# ⛔ --locked: Cargo.lock is the dependency pin.
cargo build --release --locked --no-default-features --features crypto-openssl

# `cargo install` cannot be used: the crate is a cdylib with no binary.
mkdir -p "{{prefix}}/lib/pkgconfig"
if [ "$(uname -s)" = Darwin ]; then
  install -m 0755 target/release/librpm_sequoia.dylib "{{prefix}}/lib/"
else
  install -m 0755 target/release/librpm_sequoia.so "{{prefix}}/lib/"
  # build.rs:182-203 makes this symlink beside the library, and the soname it
  # sets is librpm_sequoia.so.<major> (cdylib_link_lines, :172-176).
  ln -sf librpm_sequoia.so "{{prefix}}/lib/librpm_sequoia.so.1"
fi
install -m 0644 target/release/rpm-sequoia.pc "{{prefix}}/lib/pkgconfig/rpm-sequoia.pc"
EOT
    },
  ]
}

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test -f {{prefix}}/lib/pkgconfig/rpm-sequoia.pc",
    "pkg-config --exists rpm-sequoia",
    # A reference to a symbol the library must export (src/symbols.txt lists
    # pgpParsePkts, which rpm calls). It is an address-of, so it resolves at LINK
    # time: a library that exported nothing would fail here, where the
    # fragment's `puts` program linked against nothing at all.
    {
      fixture = {
        content = <<EOT
extern char pgpParsePkts;

int main(void) {
  return &pgpParsePkts == 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o test_link $(pkg-config --cflags --libs rpm-sequoia)"
    },
    "./test_link",
  ]
}

provenance {
  read = [
    "Cargo.toml",          # :4 version; :11 licence; :13 rust-version; :36 cdylib; :38-51 crypto features, default nettle
    "Cargo.lock",          # :1449-1450 openssl-sys 0.9.117
    "build.rs",            # :107-123 PREFIX and LIBDIR fill the .pc; :158-203 soname and the .so.<major> symlink
    "README.md",           # :36-66 build, the OpenSSL backend; :78-85 PREFIX and LIBDIR
    "rpm-sequoia.pc.in",   # prefix, libdir, -lrpm_sequoia
    "src/symbols.txt",     # the exported pgp* names
    "LICENSE.txt",         # LGPL 2 or later
  ]

  consulted = [
    "pkgxdev/pantry projects/rpm.org/rpm-sequoia/package.yml",
    "projects/crates.io/git-trim/package.hcl (this tree): the rust-lang.org and libgcc handling",
  ]

  note = <<EOT
⛔ NOT BUILT. No session here can run the factory; the inputs are traced to
lines in the project's own files. The darwin branch of `build` is unproven:
upstream builds it for rpm, which is a Linux package.

The tag archive pin has one witness beyond sourcepin (an independent
fetch-and-hash), not a signature: upstream signs nothing here.
EOT
}
