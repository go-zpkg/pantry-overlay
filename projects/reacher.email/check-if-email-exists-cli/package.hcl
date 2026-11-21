# reacher.email/check-if-email-exists-cli — check-if-email-exists, the CLI of
# Reacher: tells whether an address exists without sending a mail (the binary is
# `check_if_email_exists`). A FRAGMENT until now: it only named openssl and took
# its source, versions, build and test from the upstream pantry merged
# underneath. That merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is
# the WHOLE recipe, written from the repository's own files (go-zpkg/packages#431,
# #440 step 1), at 0.11.11. Built as crates.io/fselect is (cargo install --locked).

summary = "Check if an email address exists without sending any email"

# cli/Cargo.toml:8 `license = "MIT"` and LICENSE.md:1-3 "The MIT License (MIT),
# Copyright (c) 2026 Reacher". The crates of Cargo.lock compiled in carry their
# own licences, which this expression does not enumerate.
license = "MIT"

versions {
  github = "reacherhq/check-if-email-exists"

  # The repository tags betas (v0.11.12-beta.0, v0.11.11-beta.0) beside the
  # releases and the `backend/v*` series of another component; only the plain
  # vMAJOR.MINOR.PATCH tags of the CLI are versions of this package.
  ignore = [
    "/beta/",
    "/^backend\\//",
  ]
}

distributable {
  # GitHub's archive of the tag v0.11.11.
  url              = "https://github.com/reacherhq/check-if-email-exists/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 1299395 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent host: codeload.github.com served the same 1299395 bytes
  # with the same digest. The tag is unsigned.
  sha256 = {
    "0.11.11" = "40008e5b9e8b13b4dfe765816a7f10d88b26a1ea0804e07d377aa2e5b6547d1c"
  }
}

# cli/Cargo.toml:11-12: the one [[bin]], `check_if_email_exists` (the PACKAGE is
# named `check-if-email-exists-cli`).
provides = [
  "bin/check_if_email_exists",
]

# No runtime dependency: cli/Cargo.toml:20 builds openssl with `vendored`, so
# libssl is compiled in (Cargo.lock:2564 openssl-src). The former fragment's
# openssl.org is dropped; a build with `OPENSSL_NO_VENDOR` would need it.

build {
  dependencies = {
    "gnu.org/tar" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # The vendored OpenSSL is built by its own Configure (perl, make);
    # aws-lc-sys 0.x (Cargo.lock:419) uses cmake.
    "perl.org"     = "*"
    "gnu.org/make" = "*"
    "cmake.org"    = "^3"

    # The workspace declares no rust-version; the compiler this tree carries is
    # named, not an invented floor.
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
# The CLI is a member of a workspace; cargo install --path takes the member.
# ⛔ --locked: Cargo.lock is the dependency pin, and cargo verifies its checksums.
cargo install --locked --path cli --root {{prefix}}
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
F="{{prefix}}/bin/check_if_email_exists"
test -x "$F"

# clap prints the PACKAGE name: "check-if-email-exists-cli <version>".
OUT="$("$F" --version)"
case "$OUT" in
  "check-if-email-exists-cli 0.11.11"*) ;;
  *) echo "--version printed '$OUT'" >&2; exit 1 ;;
esac
"$F" --help > help.txt
grep -q 'TO_EMAIL' help.txt
EOT
    },
  ]
}

provenance {
  read = [
    "cli/Cargo.toml",   # :2 package, :3 0.11.11, :8 MIT, :11-12 the [[bin]], :20 openssl vendored
    "Cargo.lock",       # :419 aws-lc-sys, :690 cmake, :2564 openssl-src
    "LICENSE.md",
  ]

  consulted = [
    # Read for facts only: the repository slug and the binary name. NOT taken:
    # its build and test.
    "pkgxdev/pantry projects/reacher.email/check-if-email-exists-cli/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS TWO HOSTS OF ONE ORIGIN, STATED. The repository publishes
no checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched from github.com and from codeload.github.com with one
answer. The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

BUILT BY HAND, NOT BY ZPKB. `cargo build --locked --release -p
check-if-email-exists-cli` on the tag, with cargo 1.99.0 (Homebrew, macOS),
finished in 1m54s and produced `check_if_email_exists`, whose `--version` printed
"check-if-email-exists-cli 0.11.11" (the test pins that). The recipe's own script
(cargo install --path cli --root, the libgcc.a flag on linux) and its test have
not run under a factory; the perl and cmake needs were read from Cargo.lock, not
observed on linux.
EOT
}
