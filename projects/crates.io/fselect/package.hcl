# crates.io/fselect — find files with SQL-like queries (jhspetersson/fselect). A
# FRAGMENT until now: it said what the binary needs and took its source,
# versions, build and test from the upstream pantry merged underneath. That
# merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is the WHOLE recipe,
# written from fselect's own files (go-zpkg/packages#431, #440 step 1), at
# 0.10.4.
#
# ⭐⭐ WHAT WRITING IT FOUND: the fragment named the wrong library.
#
#   - It declared `openssl.org ^3`. Cargo.lock of 0.10.4 has no openssl-sys:
#     git2 is taken with default-features = false (Cargo.toml:30), so
#     libgit2-sys is built with neither `https` nor `ssh`, and update-informer
#     speaks TLS through ureq 3.5.0 -> rustls 0.23 -> ring 0.17.14 (Cargo.lock:
#     2235, 1678, 1645) with webpki-roots compiled in (:2410). Dropped.
#   - What the binary DOES link is libgit2 (the default feature `git`,
#     Cargo.toml:16-17), zlib (libz-sys, a dependency of libgit2-sys) and zstd
#     (zstd-sys, through zip). Named below, each fatal on a miss.

summary = "fselect: find files with SQL-like queries"

# Cargo.toml:12 license = "MIT OR Apache-2.0"; LICENSE-MIT and LICENSE-APACHE
# are the two texts. The crates of Cargo.lock compiled in (ring among them)
# carry their own licences, which this expression does not enumerate.
license = "MIT OR Apache-2.0"

versions {
  github = "jhspetersson/fselect"
}

distributable {
  # GitHub's archive of the tag 0.10.4 (the repository's tags carry no `v`).
  url              = "https://github.com/jhspetersson/fselect/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 411823 bytes. Recorded with `zpkb sourcepin` (v0.92.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.10.4" = "cbcfba22855b92363fe39722559d649f803bf7acb9a433f54d92f290df006fec"
  }
}

# Cargo.toml:2: the package `fselect`; src/main.rs is its only target.
provides = [
  "bin/fselect",
]

dependencies = {
  # libgit2-sys 0.18.8+1.9.7 (Cargo.lock:1038): its build.rs:12 accepts a system
  # libgit2 only in "1.9.7".."1.10.0".
  "libgit2.org"       = "~1.9.7"
  "zlib.net"          = "^1"
  # zstd-sys 2.1.2+zstd.1.5.7 (Cargo.lock:2764), headers of zstd 1.5.7.
  "facebook.com/zstd" = "^1.5"
}

build {
  dependencies = {
    "gnu.org/tar"                 = "*"
    "freedesktop.org/pkg-config"  = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.toml:13 edition 2024, stable from 1.85. fselect declares no
    # rust-version and none is derivable without reading every crate of the
    # lockfile, so the compiler this tree carries is named, not an invented floor.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # ⛔ 1. libgit2: libgit2-sys-0.18.8 build.rs:91-105. LIBGIT2_NO_VENDOR makes a
    # missing or out-of-range system libgit2 a PANIC; without it a miss compiles
    # the vendored copy and says nothing.
    LIBGIT2_NO_VENDOR = 1

    # ⛔ 2. zstd: zstd-sys-2.1.2 build.rs:488-492 takes the system library when
    # ZSTD_SYS_USE_PKG_CONFIG is set (or its `pkg-config` feature is on, which
    # Cargo.lock does not say), and compiles its own bundled copy otherwise.
    ZSTD_SYS_USE_PKG_CONFIG = 1

    # 3. zlib: libz-sys 1.1.30 prefers pkg-config, then a link probe, then its
    # own build (as in rust-lang.org/cargo). LIBZ_SYS_STATIC is NOT set. Not
    # fatal on a miss either; the test reads the link off the binary.
    #
    # 4. ring 0.17.14 compiles its own C and assembly (BoringSSL-derived): there
    # is no system ring and no switch. VENDORED, STATED. bzip2 is
    # libbz2-rs-sys (Cargo.lock:1026) and lzma is lzma-rust2: pure Rust.
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
# The default features (Cargo.toml:16: git, users, update-notifications,
# interactive) are kept: they are what the binary the project ships has.
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
F="{{prefix}}/bin/fselect"
test -x "$F"
# NO_COLOR: src/main.rs:60-61; a throwaway HOME: the binary saves its config
# (:261) and keeps its history under the user's config directory.
export NO_COLOR=1
export HOME="$(mktemp -d)"
export XDG_CONFIG_HOME="$HOME/.config"

# src/main.rs:89-91, :333-336: "fselect <CARGO_PKG_VERSION>" first.
OUT="$("$F" --version)"
case "$OUT" in
  "fselect 0.10.4"*) ;;
  *) echo "--version printed '$OUT'" >&2; exit 1 ;;
esac

# A query reads the file system: two files, the sizes known.
D="$(mktemp -d)"
printf 'hello\n' > "$D/a.txt"
printf 'hello world\n' > "$D/b.log"
OUT="$("$F" name from "$D" where name = a.txt)"
if [ "$OUT" != "a.txt" ]; then echo "name query printed '$OUT'" >&2; exit 1; fi
OUT="$("$F" size from "$D" where name = b.log)"
if [ "$OUT" != "12" ]; then echo "size query printed '$OUT', want 12" >&2; exit 1; fi
OUT="$("$F" name from "$D" where name = nothere)"
if [ -n "$OUT" ]; then echo "a query matching nothing printed '$OUT'" >&2; exit 1; fi

# What the binary links is what the recipe declares: a copy compiled in would
# leave one of these out.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$F")"; else LIBS="$(ldd "$F")"; fi
for l in libgit2 libz libzstd; do
  case "$LIBS" in
    *"$l"*) ;;
    *) echo "fselect does not link $l:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
done
case "$LIBS" in
  *libssl*) echo "fselect links libssl, which Cargo.lock does not ask for" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",   # :12 licence, :13 edition 2024, :15-21 features, :30 git2 default-features = false, :53 update-informer, :54 zip
    "Cargo.lock",   # :1038 libgit2-sys 0.18.8+1.9.7, :1074 libz-sys 1.1.30, :2764 zstd-sys, :1645 ring, :2235 ureq, :1026 libbz2-rs-sys; no openssl-sys
    "src/main.rs",  # :60-61 NO_COLOR, :89-91 --version, :261-273 config save and the update check, :333-336 the version line
    "libgit2-sys-0.18.8+1.9.7/build.rs",  # :12 the version range, :85-105 features and LIBGIT2_NO_VENDOR
    "zstd-sys-2.1.2+zstd.1.5.7/build.rs", # :488-492 ZSTD_SYS_USE_PKG_CONFIG, :226-232 the pkg-config path
    "LICENSE-MIT", "LICENSE-APACHE",
  ]

  consulted = [
    # Read for facts only: the tag URL (no `v`) and the binary name. NOT taken:
    # openssl ^1.1, rust ^1.65, the cmake build dependency (nothing in
    # Cargo.lock's crates asks for it), the test `fselect size, path from ~` that
    # reads the builder's home directory.
    "pkgxdev/pantry projects/crates.io/fselect/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only, on a loaded
machine. The query syntax in the test (`name from DIR where name = X`) is the
README's, not run; the exact `size` output format (a bare byte count) is read
from the README, not observed. The first factory run is this file's test.
EOT
}
