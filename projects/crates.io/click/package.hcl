# crates.io/click — a command line REPL for Kubernetes (databricks/click).
# A FRAGMENT until now: it said what click links and took its source, versions,
# build and test from the upstream pantry merged underneath. That merge ended
# with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is the WHOLE recipe, written
# from click's own files (go-zpkg/packages#431, #440 step 1), at 0.6.3.

summary = "click: a command line REPL for Kubernetes"

# Cargo.toml:8 license = "Apache-2.0"; LICENSE is the Apache License 2.0 text.
# The crates of Cargo.lock compiled into the binary carry their own licences,
# which this expression does not enumerate.
license = "Apache-2.0"

versions {
  github = "databricks/click"
  strip  = "/^v/"
}

distributable {
  # GitHub's archive of the tag v0.6.3 (release of 2023-09-26).
  url              = "https://github.com/databricks/click/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 117463 bytes. Recorded with `zpkb sourcepin` (v0.92.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.6.3" = "da64d1d205b6136f318dea967eec4e9d67569be8f332875afcc6b31c9a0ef1b7"
  }
}

# Cargo.toml:2 package `click`, one binary of that name (src/main.rs is the only
# target; no [[bin]]).
provides = [
  "bin/click",
]

# Cargo.toml:49 reqwest with "native-tls" and "default-tls": native-tls links
# OpenSSL through openssl-sys 0.9.93 (Cargo.lock:1168) on linux, and
# Security.framework on darwin (security-framework, Cargo.lock:1607). Declared
# on every platform, as the fragment did. ⚠ the darwin side was not measured.
dependencies = {
  "openssl.org" = "^3"
}

build {
  dependencies = {
    "gnu.org/tar" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.toml:12 edition 2021 (stable from 1.56); no rust-version is declared
    # and none is derivable without reading every crate of the lockfile, so the
    # compiler this tree carries is named, not an invented floor.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  script = [
    {
      run = <<EOT
set -eu
# ⛔ openssl-sys 0.9.93 refuses to guess without OPENSSL_DIR when no pkg-config
# answers. The MAJOR symlink v3, not a concrete version (see
# rust-lang.org/cargo: a glob bakes @rpath/openssl.org/v3.x.y into the binary
# while the recipe declares the range ^3). No `vendored` feature is enabled in
# Cargo.toml and openssl-src is not in Cargo.lock, so no OpenSSL is compiled in.
O="$${ZPKG_DIR:-$HOME/.zpkg}/openssl.org/v3"
if [ ! -e "$O/include/openssl/ssl.h" ]; then
  echo "no openssl 3 at $O — is openssl.org ^3 a dependency?" >&2
  exit 1
fi
export OPENSSL_DIR="$O"

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
C="{{prefix}}/bin/click"
test -x "$C"
# src/main.rs:90-91: ClapCommand::new("Click").version(crate_version!()).
OUT="$("$C" --version)"
if [ "$OUT" != "Click 0.6.3" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi
# src/main.rs:93: the about line is in --help.
"$C" --help > help.txt
grep -q "Command Line Interactive Contoller for Kubernetes" help.txt
# The TLS library is the one declared, not a copy compiled in.
if [ "$(uname -s)" = Linux ]; then
  LIBS="$(ldd "$C")"
  case "$LIBS" in
    *libssl*) ;;
    *) echo "click does not link libssl on linux:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
fi
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",   # :8 licence, :12 edition, :17-18 the one feature, :49 reqwest native-tls, the whole dependency list
    "Cargo.lock",   # :1168 openssl-sys 0.9.93, :1607 security-framework, no openssl-src
    "src/main.rs",  # :90-93 the command name, version and about line
    "LICENSE",      # Apache License 2.0
  ]

  consulted = [
    # Read for facts only: the tag URL and `cargo install --locked --path .`.
    # NOT taken: openssl ^1.1 and rust >=1.56 (a floor nothing in the files
    # states), the pkg-config build dependency.
    "pkgxdev/pantry projects/crates.io/click/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

⛔ NOT BUILT, NOT TESTED. No build was run: this recipe was written from the
source's files only, on a loaded machine. The first factory run is its test.
EOT
}
