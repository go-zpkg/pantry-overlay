# chompbuild.com — Chomp, a make-like parallel task runner with a JS extension
# system (guybedford/chomp). A FRAGMENT until now: it named openssl and took its
# source, versions, build and test from the upstream pantry merged underneath.
# That merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is the WHOLE
# recipe, written from Chomp's own files (go-zpkg/packages#431, #440 step 1), at
# 0.3.1. Built as crates.io/fselect is (cargo install --locked).

summary = "Make-like parallel task runner with a JS extension system"

# ⚠ THE PROJECT CONTRADICTS ITSELF, AND BOTH ARE STATED. Cargo.toml:6 says
# `license = "Apache-2.0"` and LICENSE:2-3 is the Apache License 2.0 text, but
# EVERY source file under src/ (twelve of twelve; src/main.rs:1-7 for one) opens
# "Copyright (C) 2022 Guy Bedford ... GNU General Public License ... either
# version 3 of the License, or (at your option) any later version". A consumer
# is told both. The crates of Cargo.lock compiled in carry their own licences,
# which this expression does not enumerate.
license = "Apache-2.0 AND GPL-3.0-or-later"

versions {
  github = "guybedford/chomp"
}

distributable {
  # GitHub's archive of the tag 0.3.1 (the repository's tags carry no `v`).
  url              = "https://github.com/guybedford/chomp/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 99786 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent host: codeload.github.com served the same 99786 bytes
  # with the same digest. The tag is unsigned.
  sha256 = {
    "0.3.1" = "103468467f5f8d9462c9b773c1dd67294ad0debde89203218eb14c7540369abf"
  }
}

# Cargo.toml:14-16: the one [[bin]], `chomp`, from src/main.rs (the PACKAGE is
# named `chompbuild`).
provides = [
  "bin/chomp",
]

dependencies = {
  # hyper-tls 0.6 -> native-tls 0.2.18 -> openssl 0.10.78 -> openssl-sys
  # (Cargo.lock:998, :1106, :1138). Cargo.lock has no openssl-src, so there is no
  # vendored copy to fall back on: the system library is the only one.
  "openssl.org" = "^3"
}

build {
  dependencies = {
    "gnu.org/tar"                = "*"
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.toml:5 edition 2021. Chomp declares no rust-version; the compiler
    # this tree carries is named, not an invented floor.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # openssl-sys prefers pkg-config, then OPENSSL_DIR. This keeps a stray
    # vendored feature from compiling its own copy.
    OPENSSL_NO_VENDOR = 1
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
F="{{prefix}}/bin/chomp"
test -x "$F"
export HOME="$(mktemp -d)"

# ⚠ src/main.rs:70-73 HARD-CODES the version: a release build prints "0.3.0"
# (and a debug build "0.3.0-debug"), even at the tag 0.3.1, so the test pins the
# prefix of what clap prints, not the package version.
OUT="$("$F" --version)"
case "$OUT" in
  "Chomp 0.3"*) ;;
  *) echo "--version printed '$OUT'" >&2; exit 1 ;;
esac

# A chompfile (src/main.rs:53-60: `version = 0.1`) with one task runs it.
D="$(mktemp -d)"
cd "$D"
cat > chompfile.toml <<'TOML'
version = 0.1

[[task]]
name = "hello"
run = "echo chomp-ran"
TOML
OUT="$("$F" hello 2>&1)"
case "$OUT" in
  *chomp-ran*) ;;
  *) echo "task output was '$OUT'" >&2; exit 1 ;;
esac

# What the binary links is what the recipe declares.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$F")"; else LIBS="$(ldd "$F")"; fi
case "$LIBS" in
  *libssl*) ;;
  *) echo "chomp does not link libssl:" >&2; echo "$LIBS" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",   # :2 package chompbuild, :5 edition 2021, :6 Apache-2.0, :14-16 the [[bin]] chomp, :33 hyper-tls, :46 serde_v8, :53 v8
    "Cargo.lock",   # :998 native-tls 0.2.18, :1106 openssl 0.10.78, :1138 openssl-sys; no openssl-src
    "LICENSE",      # :2-3 Apache License 2.0
    "src/main.rs",  # :1-7 GPL-3.0-or-later header, :53-60 the chompfile template, :70-75 the hard-coded version
  ]

  consulted = [
    # Read for facts only: the repository slug and the binary name. NOT taken:
    # its build and test.
    "pkgxdev/pantry projects/chompbuild.com/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS TWO HOSTS OF ONE ORIGIN, STATED. The repository publishes
no checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched from github.com and from codeload.github.com with one
answer. The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

⚠ THE v8 CRATE FETCHES AT BUILD TIME. Cargo.toml:53 depends on v8 0.89 (with
serde_v8), whose build script downloads a prebuilt librusty_v8 static library
unless RUSTY_V8_ARCHIVE names one. That download is NOT pinned by this recipe
(it is not in `distributable`, and no script of ours fetches it); a build with
no network fails there. Making it hermetic needs the archive as a second
resource and is not done here.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only. The test's
chompfile is the README's task syntax, not run; the first factory run is this
file's test.
EOT
}
