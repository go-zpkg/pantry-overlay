# crates.io/tiny — an IRC client for the terminal (osa1/tiny). A FRAGMENT until
# now: it said what the binary needs and took its source, versions, build and
# test from the upstream pantry merged underneath. That merge ended with zpkb
# v0.90.0 (go-zpkg/zpkb#514), so this is the WHOLE recipe, written from tiny's
# own files (go-zpkg/packages#431, #440 step 1), at 0.13.0.
#
# ⭐⭐ WHAT WRITING IT FOUND.
#
#   - THE FRAGMENT DECLARED A LIBRARY THE DEFAULT BUILD DOES NOT USE. It said
#     `openssl.org ^3`. crates/tiny/Cargo.toml:12 makes `tls-rustls` the default
#     feature and OpenSSL's `tls-native` an alternative (:13). Measured with
#     `cargo tree --locked -p tiny -i openssl-sys`: "did not match any packages"
#     for x86_64-unknown-linux-gnu and aarch64-apple-darwin alike. TLS is
#     rustls 0.21.12 (Cargo.lock:717) over ring 0.17.8 (:677), with the
#     platform's certificate store read at run time by rustls-native-certs
#     (crates/libtiny_client/src/stream.rs:45). The dependency is dropped and
#     the CA bundle that rustls-native-certs / openssl-probe read on linux is
#     named, as in crates.io/drill.
#   - ⛔ THE TAG'S Cargo.lock IS STALE, AND `cargo install --locked` REFUSES IT.
#     v0.13.0's Cargo.lock:1002-1003 says `tiny` 0.12.0 while
#     crates/tiny/Cargo.toml:3 says 0.13.0: "cannot update the lock file ...
#     because --locked was passed" (cargo 1.99, measured). `cargo update
#     --workspace` rewrites ONLY the workspace members' entries; measured on
#     this source it changes exactly that one line (diff of Cargo.lock) and
#     leaves every registry package and checksum alone, so the dependency pin is
#     intact and `--locked` is applied after it.
#   - build.rs asks `git rev-parse --short HEAD` (rustc_tools_util 0.2.1,
#     lib.rs:85-91). A GitHub archive is not a repository, so the commit hash in
#     `tiny --version` is EMPTY, not a hash: the test does not assert one.
#   - desktop-notifications (dbus, libdbus-sys: Cargo.lock:109, :309) is an
#     optional feature, off by default and off here.

summary = "tiny: an IRC client"

# crates/tiny/Cargo.toml:7 license = "MIT"; LICENSE is the MIT text. The crates
# of Cargo.lock compiled in carry their own licences, which this expression does
# not enumerate.
license = "MIT"

versions {
  github = "osa1/tiny"
  strip  = "/^v/"
}

distributable {
  # GitHub's archive of the tag v0.13.0 (the repository's tags also include
  # v0.5.2-test and bare 0.x tags, and a moving `nightly`; only a tag that is a
  # version resolves).
  url              = "https://github.com/osa1/tiny/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 397429 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.13.0" = "599697fa736d7500b093566a32204691093bd16abd76f43a76b761487a7c584c"
  }
}

# crates/tiny/Cargo.toml:2: the package `tiny`; crates/tiny/src/main.rs is the
# only binary of the workspace.
provides = [
  "bin/tiny",
]

dependencies = {
  # rustls-native-certs 0.6 (Cargo.lock:729) and openssl-probe (:576) look for
  # the system CA bundle at run time on linux; see runtime.env. On darwin it
  # reads Security.framework.
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
    "gnu.org/tar" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Edition 2021 (stable from 1.56); no crate of the workspace declares a
    # rust-version, and rust-toolchain says `stable`, read by rustup, which this
    # recipe does not use. The compiler this tree carries is named.
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

# The tag's Cargo.lock names `tiny` 0.12.0 beside a 0.13.0 manifest (see the
# header): bring the WORKSPACE members' entries up to date, nothing else.
cargo update --workspace

# ⛔ --locked: Cargo.lock is the dependency pin, and cargo verifies its checksums.
# The workspace's one binary package is crates/tiny; default features
# (tls-rustls) are kept.
cargo install --locked --path crates/tiny --root {{prefix}}
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
T="{{prefix}}/bin/tiny"
test -x "$T"
# crates/tiny/src/cli.rs:65-69 prints "tiny <version> (<commit hash>)"; the hash
# is empty in a build from a source archive (see the header), so only the
# prefix is asserted.
OUT="$("$T" --version)"
case "$OUT" in
  "tiny 0.13.0 ("*")") ;;
  *) echo "--version printed '$OUT'" >&2; exit 1 ;;
esac
# cli.rs:71-92: the help text prints the package description and the options.
"$T" --help > help.txt
grep -q "An IRC client" help.txt
grep -q -- "--config" help.txt

# rustls, not OpenSSL: the binary must NOT link libssl.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$T")"; else LIBS="$(ldd "$T")"; fi
case "$LIBS" in
  *libssl*) echo "tiny links libssl, which the default features do not ask for:" >&2; echo "$LIBS" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",                         # :1-13 workspace members, :15-17 release profile
    "Cargo.lock",                         # :677 ring 0.17.8, :717 rustls 0.21.12, :729 rustls-native-certs, :576 openssl-probe, :1002-1003 tiny 0.12.0 (stale), :109 dbus, :309 libdbus-sys
    "crates/tiny/Cargo.toml",             # :2 package, :3 version, :7 licence, :11-16 features (default tls-rustls)
    "crates/tiny/build.rs",               # GIT_HASH from rustc_tools_util
    "crates/tiny/src/cli.rs",             # :65-69 version line, :71-92 help text
    "crates/libtiny_client/Cargo.toml",   # :8-11 tls features, default tls-rustls
    "crates/libtiny_client/src/stream.rs", # :45 rustls_native_certs::load_native_certs
    "rustc_tools_util-0.2.1/src/lib.rs",  # :85-91 get_commit_hash runs `git rev-parse --short HEAD`
    "rust-toolchain",                     # `stable`
    "LICENSE",                            # MIT
  ]

  consulted = [
    # Read for facts only: the tag URL, the binary name `tiny`. NOT taken:
    # openssl ^1.1 (the default build is rustls), rust >=1.56.
    "pkgxdev/pantry projects/crates.io/tiny/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

The TLS stack and the stale lockfile were MEASURED with cargo 1.99 on the
0.13.0 source (`cargo tree --locked -p tiny -i openssl-sys`, `cargo update
--workspace` and the diff of Cargo.lock), not only read.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only, on a loaded
machine. The first factory run is this file's test.
EOT
}
