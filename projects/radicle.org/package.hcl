# Radicle — peer-to-peer code collaboration on top of Git (heartwood).
# A FRAGMENT until now: it said what the binary needs and took its source,
# versions, build and test from the upstream pantry merged underneath. That
# merge ended with zpkb v0.90.0 (go-zpkg/packages#431), so this is the WHOLE
# recipe, written from heartwood's own files (go-zpkg/packages#440 step 1), at
# 1.10.3.
#
# ⭐⭐ WHAT WRITING IT FOUND:
#
#   - There is no GitHub repository. radicle.xyz redirects to radicle.dev, and
#     the source is published as a release tarball at files.radicle.dev.
#   - THE FRAGMENT'S openssl.org IS NOT LINKED. Cargo.lock has no openssl-sys.
#     git2 is taken with default-features = false and "vendored-libgit2"
#     (Cargo.toml:30), so libgit2-sys 0.18.4 compiles its own libgit2 without
#     TLS or ssh; sqlite is "bundled" (crates/radicle/Cargo.toml:56), so
#     sqlite3-src compiles SQLite. The one -sys crate that asks pkg-config for a
#     library is libz-sys 1.1.25 (Cargo.lock:2146): zlib is a dependency.
#     This is a CLAIM FROM THE LOCK FILE; the build was not run.
#   - THREE packages make the install, as README.md:46-48 says: radicle-cli
#     (binary `rad`), radicle-node (`radicle-node`) and radicle-remote-helper
#     (`git-remote-rad`, which git runs for rad:// remotes). The features are
#     named, not defaulted: radicle-cli and radicle-node default to backtrace,
#     i2p and tor (radicle-node also systemd, structured-logger, socket2).
#     The recipe keeps those defaults, spelled out, because they are what the
#     project ships and tests; radicle-systemd (Cargo.lock:3154) is pure Rust
#     (systemd-journal-logger) and links no libsystemd.

summary = "Radicle: peer-to-peer code collaboration stack built on Git"

# Cargo.toml:7 license = "MIT OR Apache-2.0" (workspace).
license = "MIT OR Apache-2.0"

versions {
  url = "https://files.radicle.dev/releases/"
  match = "/href=\"\\d+\\.\\d+\\.\\d+\\/\"/"
  strip = ["/href=\"/", "/\\/\"/"]
}

distributable {
  # The tarball has NO top-level directory: its files sit at the root.
  url = "https://files.radicle.dev/releases/{{version.raw}}/heartwood-{{version.raw}}.tar.gz"

  # 1781927 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "1.10.3" = "011bd76d05328438f6c53a06f8952f1ef03fb4dc9ad47adb00190361cd1fd364"
  }
}

# [[bin]] names: crates/radicle-cli/Cargo.toml:13-15 `rad`,
# crates/radicle-remote-helper/Cargo.toml:13-15 `git-remote-rad`; the
# radicle-node package's binary is src/main.rs, named after the package.
provides = [
  "bin/rad",
  "bin/radicle-node",
  "bin/git-remote-rad",
]

dependencies = {
  "zlib.net" = "^1"
}

build {
  dependencies = {
    "gnu.org/tar"                = "*"
    "gnu.org/make"               = "*"
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # rust-version = "1.88.0" (Cargo.toml:17), edition 2024.
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
# The three installs README.md:46-48 gives, with the default features of each
# package written out (radicle-cli/Cargo.toml:18, radicle-node/Cargo.toml:14).
cargo install --locked --force --root {{prefix}} --path crates/radicle-cli \
  --no-default-features --features backtrace,i2p,tor
cargo install --locked --force --root {{prefix}} --path crates/radicle-node \
  --no-default-features --features backtrace,i2p,systemd,structured-logger,socket2,tor
cargo install --locked --force --root {{prefix}} --path crates/radicle-remote-helper
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
for b in rad radicle-node git-remote-rad; do
  test -x "{{prefix}}/bin/$b"
done
OUT="$("{{prefix}}/bin/rad" --version </dev/null)"
case "$OUT" in
  *{{version.raw}}*) ;;
  *) echo "rad --version printed '$OUT', want it to name {{version.raw}}" >&2; exit 1 ;;
esac
"{{prefix}}/bin/radicle-node" --version </dev/null >/dev/null
EOT
    },
  ]
}

provenance {
  read = [
    "README.md",                            # :46-48 the three installs
    "Cargo.toml",                           # :7 licence, :17 rust-version, :30 git2 vendored-libgit2
    "Cargo.lock",                           # :2128 libgit2-sys, :2146 libz-sys, :3154 radicle-systemd, :3833 sqlite3-src; no openssl-sys
    "crates/radicle-cli/Cargo.toml",        # :13-15 bin rad, :18 default features
    "crates/radicle-node/Cargo.toml",       # :14 default features
    "crates/radicle-remote-helper/Cargo.toml", # :13-15 bin git-remote-rad
    "crates/radicle/Cargo.toml",            # :56 sqlite bundled
  ]

  consulted = [
    "projects/radicle.org/package.hcl before this change",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. files.radicle.dev publishes .sig
files for the binary archives only, none for the source tarball; the digest
records that tarball, fetched twice (the builder's fetcher, curl) with one
answer. The crates are pinned by Cargo.lock's checksums, which cargo verifies
under --locked.

⚠ The versions index lists release candidates (1.10.0-rc.1/); the match takes
only plain MAJOR.MINOR.PATCH directories.

⚠ openssl.org was dropped on the lock file's evidence (no openssl-sys), not on
a link-time check.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only. The first
factory run is this file's test.
EOT
}
