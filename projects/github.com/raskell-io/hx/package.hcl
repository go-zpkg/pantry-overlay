# github.com/raskell-io/hx — hx, a Haskell toolchain in one binary (GHC and Cabal
# install, build, test, format, lock). The repository now answers at
# arcanist-sh/hx; the old slug redirects and is the one this tree keeps. A
# FRAGMENT until now: it named openssl and took its source, versions, build and
# test from the upstream pantry merged underneath. That merge ended with zpkb
# v0.90.0 (go-zpkg/zpkb#514), so this is the WHOLE recipe, written from hx's own
# files (go-zpkg/packages#431, #440 step 1), at 0.11.0. Built as crates.io/fselect
# is (cargo install --locked).

summary = "Haskell toolchain CLI: install GHC and Cabal, build, test, format, lock"

# Cargo.toml:27 `license = "MIT"` (workspace) and LICENSE:1-3 "MIT License,
# Copyright (c) 2026 Raffael Schneider". The crates of Cargo.lock compiled in
# carry their own licences, which this expression does not enumerate.
license = "MIT"

versions {
  github = "raskell-io/hx"
}

distributable {
  # GitHub's archive of the tag v0.11.0.
  url              = "https://github.com/raskell-io/hx/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 885830 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent host: codeload.github.com served the same 885830 bytes
  # with the same digest. The tag is unsigned.
  sha256 = {
    "0.11.0" = "10b5be622a5e17c2cec5ec19e26fbdfd4d9c2e64fd290c8648fe5583cc74d99d"
  }
}

# crates/hx-cli/Cargo.toml:14-16: the one [[bin]], `hx`, from src/main.rs (the
# PACKAGE is named `hx-cli`).
provides = [
  "bin/hx",
]

# No runtime dependency is declared: Cargo.toml:79 builds reqwest with
# rustls-no-provider and :94 self_update with rustls, and Cargo.lock has no
# openssl-sys. The former fragment's openssl.org was a guess and is dropped.

build {
  dependencies = {
    "gnu.org/tar" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.lock:216 aws-lc-sys 0.46.0 (through rustls) compiles C with cmake
    # (Cargo.lock:507 cmake); zstd-sys (Cargo.lock:4975) needs only a C compiler.
    "cmake.org"    = "^3"
    "gnu.org/make" = "*"

    # Cargo.toml:25 edition 2024 and :26 rust-version 1.96. The `rust-toolchain.toml`
    # is rustup's pin and this tree has no rustup; the compiler this tree
    # carries is named, and it is above that floor.
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
cargo install --locked --path crates/hx-cli --root {{prefix}}
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
F="{{prefix}}/bin/hx"
test -x "$F"
# A throwaway HOME: hx keeps caches and config under the user's directories.
export HOME="$(mktemp -d)"

# clap `#[command(version)]` (.claude/rules/cli.md): "hx <CARGO_PKG_VERSION>".
OUT="$("$F" --version)"
case "$OUT" in
  "hx 0.11.0"*) ;;
  *) echo "--version printed '$OUT'" >&2; exit 1 ;;
esac
"$F" --help > help.txt
grep -q 'toolchain' help.txt
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",                # :23-28 workspace.package (0.11.0, edition 2024, rust-version 1.96, MIT), :79 reqwest rustls-no-provider, :94 self_update rustls
    "crates/hx-cli/Cargo.toml",  # :2 package hx-cli, :14-16 the [[bin]] hx
    "Cargo.lock",                # :216 aws-lc-sys, :507 cmake, :4975 zstd-sys; no openssl-sys
    "LICENSE",
  ]

  consulted = [
    # Read for facts only: the repository slug and the binary name. NOT taken:
    # its build and test.
    "pkgxdev/pantry projects/github.com/raskell-io/hx/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS TWO HOSTS OF ONE ORIGIN, STATED. The repository publishes
no checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched from github.com and from codeload.github.com with one
answer. The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

BUILT BY HAND, NOT BY ZPKB. `cargo build --locked --release -p hx-cli` on the
tag, with cargo 1.99.0 (Homebrew, macOS), finished in 2m14s and produced `hx`,
whose `--version` printed "hx 0.11.0" (the test pins that). The recipe's own
script (cargo install --root, the libgcc.a flag on linux) and its test have not
run under a factory, and the cmake need was read from Cargo.lock, not observed
on linux.
EOT
}
