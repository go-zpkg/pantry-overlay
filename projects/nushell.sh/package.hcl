# nushell.sh — Nushell, a shell that pipes structured data (nushell/nushell). A
# FRAGMENT until now: it said `openssl.org ^3` and took its source, versions,
# build and test from the upstream pantry merged underneath. That merge ended
# with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is the WHOLE recipe, written from
# Nushell's own files (go-zpkg/packages#440 step 1), at 0.117.0.
#
# ⭐⭐ WHAT WRITING IT FOUND: the fragment's OpenSSL is not linked. `cargo tree
# --locked` for x86_64-unknown-linux-gnu and aarch64-apple-darwin finds NO
# openssl-sys, curl-sys, libssh2-sys, aws-lc-sys or zstd-sys in the default
# graph: `rustls-tls` (Cargo.toml:450, in `default` :452-461) is the TLS stack,
# and OpenSSL would come only from `static-link-openssl` (:467) or
# `native-tls` (:449), neither default. What the graph DOES link is libgit2
# (git2 0.21.0 <- fff-search 0.11.0, with `vendored-libgit2`) and zlib. The
# dependency becomes libgit2.org, which this tree builds, and zlib.net.

summary = "nushell: a shell that pipes structured data"

# Cargo.toml:5 license = "MIT"; LICENSE is the MIT text. The crates of
# Cargo.lock compiled in carry their own licences, which this expression does
# not enumerate.
license = "MIT"

versions {
  github = "nushell/nushell/tags"
}

distributable {
  # GitHub's archive of the tag 0.117.0 (this project's tags carry no `v`).
  url              = "https://github.com/nushell/nushell/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 5114588 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.117.0" = "ccb5640f8f88b48787c946daf87a349972b939c2edbc5a3b4ca6fc0921bddd6b"
  }
}

# Cargo.toml:15 default-run = "nu", :20 [[bin]] name = "nu". The plugins
# (nu_plugin_*) are separate packages of the workspace and are not installed by
# `--path .`.
provides = [
  "bin/nu",
]

dependencies = {
  # libgit2-sys 0.18.7+1.9.6 (Cargo.lock) asks for a system libgit2 in
  # "1.9.6".."1.10.0" (build.rs:12) and links libz-sys 1.1.31. libgit2.org is
  # built with libssh2 and OpenSSL, and its .pc names them, so pkg-config needs
  # them to resolve.
  "libgit2.org" = "~1.9.6"
  "libssh2.org" = "^1"
  "openssl.org" = "^3"
  "zlib.net"    = "^1"

  # openssl-probe 0.2.1 <- rustls-native-certs 0.8.4 (nu-command) looks for the
  # system CA bundle at run time. On darwin it is Security.framework.
  linux = {
    "curl.se/ca-certs" = "*"
  }
}

runtime {
  env = {
    linux = {
      # openssl-probe honours SSL_CERT_FILE before probing the usual places.
      SSL_CERT_FILE = "{{deps.curl.se/ca-certs.prefix}}/ssl/cert.pem"
    }
  }
}

build {
  dependencies = {
    "gnu.org/tar"                = "*"
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.toml:3-4 edition 2024, rust-version = "1.97.1": the floor the
    # manifest declares; the compiler this tree carries is named.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # ⛔ libgit2: libgit2-sys 0.18.7 build.rs:91-119. fff-search turns on
    # `vendored-libgit2`, and the build script says that nothing can revert a
    # feature a dependency enabled EXCEPT this variable (:91-94). It makes a
    # missing or out-of-range system libgit2 a PANIC; without it the vendored
    # copy is compiled in and nothing is said.
    LIBGIT2_NO_VENDOR = 1
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
# ⛔ Features, named: `default` (Cargo.toml:452-461) is dap, lsp, mcp, network,
# plugin, rustls-tls, sqlite, trash-support. `native-tls` (:449) and
# `static-link-openssl` (:467) are OFF, and so is `system-clipboard` (:471).
# ⛔ Compiled in, not switchable: libsqlite3-sys 0.39.1 (rusqlite 0.41.1, from
# nu-command and reedline) has its `bundled` feature on, and its build script
# refuses LIBSQLITE3_SYS_USE_PKG_CONFIG then; lmdb-master-sys 0.2.6 (heed 0.22.1)
# compiles its own LMDB.
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
N="{{prefix}}/bin/nu"
test -x "$N"
OUT="$("$N" --version)"
if [ "$OUT" != "0.117.0" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi

# Structured data through a pipeline, with no config and no history file.
OUT="$("$N" --no-config-file -c '[[name size]; [a 1] [b 200] [c 3]] | where size < 100 | length')"
if [ "$OUT" != "2" ]; then echo "where | length printed '$OUT'" >&2; exit 1; fi

# SQLite (bundled, `sqlite` feature): write a table, read it back.
"$N" --no-config-file -c '[[a b]; [1 2] [3 4]] | into sqlite t.db --table-name x'
test -s t.db
OUT="$("$N" --no-config-file -c 'open t.db | get x | length')"
if [ "$OUT" != "2" ]; then echo "sqlite round trip printed '$OUT'" >&2; exit 1; fi

# libgit2 is the system library, not a compiled-in copy; rustls, not OpenSSL.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$N")"; else LIBS="$(ldd "$N")"; fi
case "$LIBS" in
  *libgit2*) ;;
  *) echo "nu does not link libgit2:" >&2; echo "$LIBS" >&2; exit 1 ;;
esac
case "$LIBS" in
  *libssl*) echo "nu links libssl, which the default features do not ask for:" >&2; echo "$LIBS" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",   # :3-6 edition, rust-version 1.97.1, licence, version; :15 default-run; :20 [[bin]] nu; :409-486 features; :449-450 native-tls / rustls-tls; :452-461 default; :467 static-link-openssl
    "Cargo.lock",   # resolved with `cargo tree --locked --target <t> -e normal,build -i <crate>` for linux-gnu and apple-darwin: libgit2-sys 0.18.7+1.9.6 + libz-sys 1.1.31 (git2 0.21.0 <- fff-search 0.11.0), libsqlite3-sys 0.39.1, lmdb-master-sys 0.2.6, openssl-probe 0.2.1 linux only; openssl-sys, curl-sys, libssh2-sys, aws-lc-sys, zstd-sys, lz4-sys absent
    "LICENSE",      # MIT
    "libgit2-sys-0.18.7+1.9.6/build.rs",  # :12 "1.9.6".."1.10.0", :87-119 the vendored feature and LIBGIT2_NO_VENDOR
    "fff-search-0.11.0/Cargo.toml",       # :202-205 git2 with vendored-libgit2, default-features off
  ]

  consulted = [
    # Read for facts only: the tag URL (without `v`) and `cargo install --locked
    # --path .`. NOT taken: openssl ^1.1, libgit2 ~1.7 or any pin, the test.
    "pkgxdev/pantry projects/nushell.sh/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

C LIBRARIES, NAMED: libgit2 1.9.x (system, through pkg-config; its libssh2,
OpenSSL and zlib are what its .pc names); zlib (libz-sys); SQLite (bundled,
libsqlite3-sys, not switchable) and LMDB (bundled, lmdb-master-sys). No OpenSSL
in nu itself. On darwin the build script of libproc 0.14.11 runs bindgen, which
needs a libclang the tree does not supply: the system Xcode command line tools.

⛔ NOT BUILT by the factory. The same `cargo install --locked --path .` was
tried by hand on aarch64-apple-darwin with the system toolchain, the vendored
libgit2 (no system libgit2 there, so LIBGIT2_NO_VENDOR was NOT set). Observed:
`nu --version` printed 0.117.0; the where/length pipeline printed 2; the sqlite
round trip (into sqlite, then open | get x | length) printed 2. The
LIBGIT2_NO_VENDOR path and linux were not run; the first factory run is this
file's test.
EOT
}
