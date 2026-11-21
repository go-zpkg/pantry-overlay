# github.com/awslabs/dynein — dynein, a DynamoDB command line interface (the
# binary is `dy`). A FRAGMENT until now: it named openssl on linux and took its
# source, versions, build and test from the upstream pantry merged underneath.
# That merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is the WHOLE
# recipe, written from dynein's own files (go-zpkg/packages#431, #440 step 1), at
# 0.3.0. Built as crates.io/fselect is (cargo install --locked).

summary = "DynamoDB command line interface"

# Cargo.toml:21 license = "Apache-2.0"; LICENSE is the Apache License 2.0 text
# and NOTICE:2 "Copyright Amazon.com, Inc. or its affiliates". The crates of
# Cargo.lock compiled in carry their own licences, which this expression does
# not enumerate.
license = "Apache-2.0"

versions {
  github = "awslabs/dynein"
}

distributable {
  # GitHub's archive of the tag v0.3.0.
  url              = "https://github.com/awslabs/dynein/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 678870 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent host: codeload.github.com served the same 678870 bytes
  # with the same digest. The tag is unsigned.
  sha256 = {
    "0.3.0" = "40be5866288f565ac00494910d5dbb266ca0c34d56d50d839bc2c2aad34dc470"
  }
}

# Cargo.toml:28-30: the one [[bin]], `dy`, from src/main.rs (the PACKAGE is
# named `dynein`).
provides = [
  "bin/dy",
]

dependencies = {
  # reqwest 0.12.4 -> native-tls -> openssl 0.10 -> openssl-sys 0.9.102
  # (Cargo.lock:1784). Cargo.lock has no openssl-src, so there is no vendored
  # copy to fall back on: the system library is the only one. On macOS cargo
  # links Security.framework instead; the declaration is for the platforms that
  # take openssl.
  "openssl.org" = "^3"
}

build {
  dependencies = {
    "gnu.org/tar"                = "*"
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.toml:20 edition 2018. The `rust-toolchain` file (1.77.2) is rustup's
    # pin and this tree has no rustup; the compiler this tree carries is named,
    # not that floor.
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
F="{{prefix}}/bin/dy"
test -x "$F"
# A throwaway HOME: dy keeps its context under ~/.dynein.
export HOME="$(mktemp -d)"

# src/cmd.rs:33 `#[clap(name = "dynein", ..., version)]`: "dynein <CARGO_PKG_VERSION>".
OUT="$("$F" --version)"
case "$OUT" in
  "dynein 0.3.0"*) ;;
  *) echo "--version printed '$OUT'" >&2; exit 1 ;;
esac
"$F" --help > help.txt
grep -q 'batch' help.txt
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",   # :16 package dynein, :20 edition 2018, :21 Apache-2.0, :28-30 the [[bin]] dy, :45 reqwest 0.12.4
    "Cargo.lock",   # :1784 openssl-sys 0.9.102, :2139 ring; no openssl-src
    "LICENSE", "NOTICE",
    "rust-toolchain", # 1.77.2, rustup's pin, not applied here
    "src/cmd.rs",   # :32-33 the clap derive with `version`
  ]

  consulted = [
    # Read for facts only: the repository slug and the binary name. NOT taken:
    # its build and test.
    "pkgxdev/pantry projects/github.com/awslabs/dynein/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS TWO HOSTS OF ONE ORIGIN, STATED. The repository publishes
no checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched from github.com and from codeload.github.com with one
answer. The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

BUILT BY HAND, NOT BY ZPKB. `cargo build --locked --release` on the tag, with
cargo 1.99.0 (Homebrew, macOS), finished in 3m43s and produced `dy`, whose
`--version` printed "dynein 0.3.0" (the test pins that). The recipe's own script
(cargo install --root, the libgcc.a flag on linux) and its test have not run
under a factory.
EOT
}
