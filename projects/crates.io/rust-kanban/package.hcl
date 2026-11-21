# crates.io/rust-kanban — a kanban board for the terminal (yashs662/rust_kanban).
# A FRAGMENT until now: it said what the binary needs and took its source,
# versions, build and test from the upstream pantry merged underneath. That
# merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is the WHOLE recipe,
# written from rust_kanban's own files (go-zpkg/packages#431, #440 step 1), at
# 0.10.5.
#
# ⭐⭐ WHAT WRITING IT FOUND.
#
#   - OPENSSL IS LINKED ON LINUX ONLY. reqwest 0.12.9 (Cargo.toml:30) keeps its
#     default `default-tls`: native-tls 0.2.12 (Cargo.lock:938), which is
#     OpenSSL on linux (openssl-sys 0.9.103, :1017) and Security.framework on
#     darwin. Measured with `cargo tree --locked -i openssl-sys`: present for
#     x86_64-unknown-linux-gnu, "nothing to print" for aarch64-apple-darwin. The
#     fragment declared `openssl.org ^3` everywhere; it is scoped to linux now.
#   - No openssl-src in Cargo.lock: OpenSSL is never compiled in, so a missing
#     system OpenSSL fails the build rather than silently building one. (hyper-
#     rustls and rustls sit in Cargo.lock, :683 and :1316, but `cargo tree -i
#     rustls` prints nothing: the lockfile lists reqwest's optional rustls
#     support, the build does not use it.)
#   - The package is `rust-kanban` and the repository `rust_kanban`; the one
#     binary is src/main.rs, named after the package.

summary = "rust-kanban: a kanban board for the terminal"

# Cargo.toml:6 license = "MIT"; LICENSE.md is the MIT text. The crates of
# Cargo.lock compiled in carry their own licences, which this expression does
# not enumerate.
license = "MIT"

versions {
  github = "yashs662/rust_kanban"
  strip  = "/^v/"
}

distributable {
  # GitHub's archive of the tag v0.10.5 (the repository also publishes a
  # pre-release named "Development Build" on each release, with binaries; this
  # source archive is what the recipe builds).
  url              = "https://github.com/yashs662/rust_kanban/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 171678 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.10.5" = "0593503c15d60b69f6ca3810607b762735e95a62b45006b1862086cb7cc9f815"
  }
}

# Cargo.toml:2: the package `rust-kanban`; src/main.rs is its only binary.
provides = [
  "bin/rust-kanban",
]

dependencies = {
  # native-tls -> openssl-sys, linux only (see the header).
  linux = {
    "openssl.org" = "^3"
  }
}

build {
  dependencies = {
    "gnu.org/tar" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Edition 2021 (Cargo.toml:5); rust-kanban declares no rust-version, and
    # ratatui 0.29 and tokio 1.41 are well below the compiler this tree
    # carries, which is therefore named.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  script = [
    {
      run = <<EOT
set -eu
if [ "$(uname -s)" = Linux ]; then
  # openssl-sys 0.9.103 refuses to guess without OPENSSL_DIR when no pkg-config
  # answers. The MAJOR symlink v3, not a concrete version (see
  # rust-lang.org/cargo).
  O="$${ZPKG_DIR:-$HOME/.zpkg}/openssl.org/v3"
  if [ ! -e "$O/include/openssl/ssl.h" ]; then
    echo "no openssl 3 at $O — is openssl.org ^3 a dependency?" >&2
    exit 1
  fi
  export OPENSSL_DIR="$O"

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
K="{{prefix}}/bin/rust-kanban"
test -x "$K"
# src/main.rs:15 #[command(author, version, about)]: clap names the command
# after the package, takes the version from Cargo.toml:3 and the about from
# Cargo.toml:8. Arguments are parsed before any configuration is touched.
OUT="$("$K" --version)"
if [ "$OUT" != "rust-kanban 0.10.5" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi
"$K" --help > help.txt
grep -q "A kanban board for the terminal" help.txt
grep -q -- "--generate-new-encryption-key" help.txt

# OpenSSL is system-linked on linux and absent on darwin (Security.framework).
if [ "$(uname -s)" = Linux ]; then
  LIBS="$(ldd "$K")"
  case "$LIBS" in
    *libssl*) ;;
    *) echo "rust-kanban does not link libssl on linux:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
else
  LIBS="$(otool -L "$K")"
  case "$LIBS" in
    *libssl*) echo "rust-kanban links libssl on darwin, which Cargo.lock does not ask for:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
fi
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",   # :2 package, :3 version, :6 licence, :14 ratatui, :30 reqwest 0.12.9 default features, :43 lto
    "Cargo.lock",   # :683 hyper-rustls, :938 native-tls 0.2.12, :1017 openssl-sys 0.9.103 (cc, pkg-config, vcpkg; no openssl-src), :1207 reqwest, :1316 rustls
    "src/main.rs",  # :14-29 CliArgs, :15 command(version, about), :33 parse before App::new
    "LICENSE.md",   # MIT
  ]

  consulted = [
    # Read for facts only: the repository name (rust_kanban, not rust-kanban)
    # and the tag form. NOT taken: openssl ^1.1 everywhere, rust >=1.56.
    "pkgxdev/pantry projects/crates.io/rust-kanban/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

The linux/darwin split of the TLS stack was measured with `cargo tree --locked
-i openssl-sys --target <triple>` on the 0.10.5 source, not read off the
lockfile alone.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only, on a loaded
machine. The first factory run is this file's test.
EOT
}
