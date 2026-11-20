# crates.io/semverator — a command line tool for semantic versions and ranges,
# the Rust port of libpkgx's utils/semver.ts. One of the four projects the
# base-toolchain closure named and this tree did not carry at all (`zpkb closure
# -build -require-standalone go-zpkg/base-toolchain`, zpkb v0.90.0, 2026-11-20):
# python.org, llvm.org and rust-lang.org run `semverator gt|satisfies` in their
# build scripts to pick a flag by version.
#
# ⛔ WRITTEN FROM SEMVERATOR'S OWN FILES (go-zpkg/packages#431), at 0.11.0.

summary = "semverator: validate, compare and intersect semantic versions and ranges"

# Cargo.toml:6-7 [workspace.package] license = "Apache-2.0", inherited by both
# members (cli/Cargo.toml:5, lib/Cargo.toml:5); LICENSE.md is the Apache
# License 2.0 text. Nothing else is compiled in that is not a crate of the
# lockfile, and those are not part of this licence expression's subject.
license = "Apache-2.0"

versions {
  github = "jhheider/semverator"
}

distributable {
  # GitHub's archive of the tag: the release v0.11.0 (2026-08-06) is what the
  # tag names, the tag v0.11.0 is lightweight and its commit 41a00acb is
  # unsigned (GitHub's own verification: "unsigned"). See provenance.note.
  url              = "https://github.com/jhheider/semverator/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 23744 bytes. Recorded with `zpkb sourcepin` (v0.90.0) and confirmed by two
  # independent fetches: the same URL with curl, and codeload.github.com's
  # tar.gz/refs/tags/v0.11.0.
  sha256 = {
    "0.11.0" = "d0a9bbfd5a50b2c36bf66b3f51192f9ea4c5d3c4b965f24d833e388785ce9417"
  }
}

# cli/Cargo.toml:2: the package `semverator`, binary of the same name (its
# only target, cli/src/main.rs).
provides = [
  "bin/semverator",
]

# A static Rust executable: its crates are compiled in (Cargo.lock), and std
# links the C library only. There is no runtime dependency.
build {
  dependencies = {
    "gnu.org/tar" = "*"

    # ⛔ MINIMUM RUSTC, FROM THE FILES: Cargo.toml:5 and cli/Cargo.toml:3 use
    # edition 2024, stable from 1.85; Cargo.lock locks clap 4.6.6, whose
    # Cargo.toml says rust-version = "1.85" (clap_builder 4.6.6 likewise). The
    # upstream recipe said >=1.56, which the edition alone refutes.
    "rust-lang.org"       = "^1.85"
    "rust-lang.org/cargo" = "*"
  }

  script = [
    # ⛔ --locked: the build uses Cargo.lock exactly (and fails if it would
    # change), so the compiled crates are the ones the lockfile's checksums
    # name. --path cli, not `.`: the root is a virtual workspace
    # (Cargo.toml:1-2), and `cargo install --path .` refuses one.
    #
    # REFUSED: libsemverator is not installed. Upstream's pantry recipe copied
    # target/release/liblibsemverator.* to lib/, which (a) also matches the
    # .rlib and .d files and (b) installs a cdylib (lib/Cargo.toml:15-16) with
    # NO exported C symbol — `grep -rn "no_mangle\|extern \"C\"" lib/src`
    # finds nothing at 0.11.0 — so no program could link or dlopen anything
    # from it. The Rust API is consumed as the `libsemverator` crate from
    # crates.io, not from this artifact.
    "cargo install --locked --path cli --root {{prefix}}",
  ]
}

test {
  # Every outcome is read off the installed binary: the words it prints on
  # stdout (cli/src/main.rs) AND its exit status — a failed comparison is an
  # anyhow error out of main (:14-18), so exit 1 with nothing on stdout, while
  # `diff --enforce` exits 127 on its own (:119). A comparison that wrongly
  # succeeded, or wrongly failed, changes one of the two.
  script = [
    {
      run = <<EOT
set -u
S="{{prefix}}/bin/semverator"
test -x "$S"

# ok CMD... : must exit 0 and print exactly $WANT on stdout.
# no CMD... : must exit 1 and print nothing on stdout.
ok() {
  out="$("$S" "$@")" || { echo "FAILED (exit $?): $*" >&2; exit 1; }
  if [ "$out" != "$WANT" ]; then echo "$*: printed '$out', want '$WANT'" >&2; exit 1; fi
}
no() {
  out="$("$S" "$@" 2>/dev/null)" && { echo "SUCCEEDED but must fail: $*" >&2; exit 1; }
  if [ -n "$out" ]; then echo "$*: printed '$out' on a failure" >&2; exit 1; fi
}

# validate, eq, neq, gt, lt (main.rs:28-84)
WANT="1.2.3 is valid";                     ok validate 1.2.3
WANT="versions are equal";                 ok eq 1.2.3 1.2.3
WANT="versions are not equal";             ok neq 1.2.3 1.2.4
WANT="1.2.3 is greater than 1.2.2";        ok gt 1.2.3 1.2.2
WANT="1.2.3 is less than 1.2.4";           ok lt 1.2.3 1.2.4
no validate 1.2.three
no eq 1.2.3 1.2.4
no neq 1.2.3 1.2.3
no gt 1.2.3 1.2.4
no lt 1.2.3 1.2.2

# bump (:87-95)
WANT="1.3.0"; ok bump 1.2.3 minor

# ranges (:126-165): validate-range, satisfies, max, intersect
WANT="^1.2 is valid";                      ok validate-range "^1.2"
WANT="1.2.5 satisifes ^1.2";               ok satisfies "^1.2" 1.2.5
no satisfies "^1.2" 2.0.0
WANT="1.9.0"; ok max "^1" 1.2.3 1.9.0 2.0.0
no max "^3" 1.2.3 1.9.0

# --version is clap's own, from the package version (cli/Cargo.toml:3)
WANT="semverator 0.11.0"; ok --version
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",                # :1-2 virtual workspace, :6-7 licence, :16-23 dependency pins
    "cli/Cargo.toml",            # :2-3 package name and version, edition 2024, the single bin
    "lib/Cargo.toml",            # :15-16 crate-type cdylib + rlib
    "cli/src/main.rs",           # :14-18 main, :28-165 each command's output and failure, :119 exit 127
    "lib/src",                   # no no_mangle / extern "C": the cdylib exports nothing
    "Cargo.lock",                # clap 4.6.6 (rust-version 1.85 in its Cargo.toml)
    "LICENSE.md",                # Apache License 2.0
    "README.md",                 # :11-18 how it is installed: `cargo install --path cli`
  ]

  consulted = [
    # Read for facts only: the tag URL, `--path cli --root`, and the test list.
    # The version floor (>=1.56) and the library copy were NOT taken, for the
    # reasons in the build script.
    "pkgxdev/pantry projects/crates.io/semverator/package.yml",
  ]

  note = <<EOT
⚠ THE RUNG IS A SINGLE HOST, STATED. The repository publishes no checksum
file and no signature, and the tag v0.11.0 is lightweight on an unsigned
commit (41a00acb). The digest records GitHub's generated archive of that
tag, fetched three ways (builder fetcher, curl on the archive URL, curl on
codeload.github.com) with one answer. The crates it compiles are pinned by
the lockfile's checksums, which cargo verifies under --locked.

Built and tested ON A MACHINE, not by the factory: `cargo install --locked
--path cli --root <dir>` on this source with cargo 1.99.0 (darwin/arm64)
produced bin/semverator, and the test script above ran against it.

⛔ NOT BUILT BY THE FACTORY. No session here can run it.
EOT
}
