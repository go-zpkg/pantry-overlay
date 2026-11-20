# tlr.dev — Teller, a developer-first multi-provider secret manager (the
# `teller` command). This tree carried only an OpenSSL dependency for it (a
# fragment, go-zpkg/packages#440 step 1); this is the whole recipe. (The project
# is tellerops/teller, formerly SpectralOps/teller; GitHub redirects the old name.)
#
# ⛔ WRITTEN FROM TELLER'S OWN FILES (go-zpkg/packages#431), at 2.0.7.
#
# ⭐⭐ WHAT WRITING IT FOUND:
#  1. OpenSSL is linked on LINUX ONLY. Cargo.lock locks native-tls 0.2 and
#     openssl-sys; on darwin native-tls is the Security framework, and the binary
#     built here links no libssl at all (`otool -L`: SystemConfiguration, Security,
#     CoreFoundation, libiconv, libSystem). The fragment's unconditional
#     openssl.org dependency is a linux one.
#  2. A build dependency the fragment omitted: protoc. teller-providers' default
#     feature `etcd` (teller-providers/Cargo.toml:16-24) pulls etcd-client 0.12.4,
#     whose build.rs:5-17 compiles .proto files through tonic-build; prost-build
#     0.12.4 refuses without a `protoc` (src/lib.rs:1507-1513, the PROTOC variable).
#  3. rust-toolchain.toml says `channel = "nightly"`. It binds rustup only; the
#     toolchain here is rust-lang.org's, which ignores the file, and the build
#     succeeded on a STABLE rustc 1.99.0.
#  4. ring (locked, Cargo.lock) compiles C and assembly with the system C
#     compiler, so linux needs gnu.org/gcc, as rust-lang.org/cargo records.

summary = "Teller: a developer-first multi-provider secret manager"

# Cargo.toml:[workspace.package] license = "Apache-2.0"; LICENSE.txt is the Apache
# License 2.0 text. The crates it compiles in are not part of this expression.
license = "Apache-2.0"

versions {
  github = "tellerops/teller"
}

dependencies = {
  # linux only: see the header (native-tls is the Security framework on darwin).
  linux = {
    "openssl.org" = "^3"
  }
}

distributable {
  # GitHub's archive of the tag: the release publishes binary archives only, the
  # tag v2.0.7 is an annotated tag whose verification is "unsigned" (GitHub), and
  # its commit is 04f099a5. See provenance.note.
  url              = "https://github.com/tellerops/teller/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 123248 bytes. Recorded with `zpkb sourcepin` and confirmed by two independent
  # fetches: the same URL with curl, and codeload.github.com's tar.gz/refs/tags.
  sha256 = {
    "2.0.7" = "1d4275ede4366a31efc94039c58da4cec87466d09cc01444c3c18e9432716d23"
  }
}

# teller-cli/Cargo.toml:[[bin]] name = "teller".
provides = [
  "bin/teller",
]

build {
  dependencies = {
    "gnu.org/tar" = "*"

    # ⛔ protoc, for etcd-client's build.rs (see the header). Found by prost-build
    # on PATH, which a build dependency puts there.
    "protobuf.dev" = "*"

    # Floor: NOT MEASURED. Built here with rustc 1.99.0; the upstream pantry's
    # figure (^1.78) is the only evidence of a lower one and is not verified.
    "rust-lang.org"       = "^1.78"
    "rust-lang.org/cargo" = "*"

    linux = {
      "gnu.org/gcc" = "*"
    }
  }

  script = [
    {
      if  = "linux"
      run = <<EOT
set -eu
# Same workaround rust-lang.org/cargo records, measured by its author: this tree's
# gcc keeps libgcc.a outside rustc's link search path.
L=""
for c in "$${ZPKG_DIR:-$HOME/.zpkg}"/gnu.org/gcc/*/lib/gcc/*/*/libgcc.a; do
  if [ -e "$c" ]; then L="$(dirname "$c")"; fi
done
if [ -z "$L" ]; then
  echo "no libgcc.a under $${ZPKG_DIR:-$HOME/.zpkg}/gnu.org/gcc — is gnu.org/gcc a build dep?" >&2
  exit 1
fi
export RUSTFLAGS="$${RUSTFLAGS:-} -L$L"

# openssl-sys refuses to guess without OPENSSL_DIR. The MAJOR symlink v3, not a
# concrete version (see rust-lang.org/cargo: a v3.x path is baked into the binary).
O="$${ZPKG_DIR:-$HOME/.zpkg}/openssl.org/v3"
if [ ! -e "$O/include/openssl/ssl.h" ]; then
  echo "no openssl 3 at $O — is openssl.org ^3 a dependency?" >&2
  exit 1
fi
export OPENSSL_DIR="$O"

# ⛔ --locked: Cargo.lock exactly. --path teller-cli, not `.`: the root is a virtual
# workspace (Cargo.toml:[workspace], default-members = ["teller-cli"]).
cargo install --locked --path teller-cli --root {{prefix}}
EOT
    },
    {
      if  = "darwin"
      run = <<EOT
set -eu
cargo install --locked --path teller-cli --root {{prefix}}
EOT
    },
  ]
}

test {
  fixture = <<EOT
providers:
  dot_1:
    kind: dotenv
    maps:
      - id: foo
        path: test.env
EOT

  script = [
    {
      run = <<EOT2
set -eu
T="{{prefix}}/bin/teller"
test -x "$T"

# clap's own, from the package version (teller-cli/Cargo.toml:3).
test "$("$T" --version)" = "teller {{version.raw}}"

# The dotenv provider (a default feature) reads a file and `show` prints the key
# with its value masked: "foo = va***".
printf 'foo=var\n' > test.env
cp "$FIXTURE" teller.yml
"$T" -c teller.yml show > show.txt 2>&1
grep -q 'foo = va\*\*\*' show.txt
EOT2
    },
    {
      if  = "linux"
      run = <<EOT3
set -eu
# OpenSSL IS linked on linux (native-tls -> openssl-sys), and it is the declared one.
if command -v ldd >/dev/null 2>&1; then
  ldd "{{prefix}}/bin/teller" > ldd.txt
  grep -q 'libssl' ldd.txt
fi
EOT3
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",                    # :[workspace] members and default-members, :[workspace.package] licence
    "teller-cli/Cargo.toml",         # :2-3 package name and version, [[bin]] teller
    "teller-providers/Cargo.toml",   # :15-24 default features incl. etcd
    "Cargo.lock",                    # etcd-client 0.12.4, prost-build 0.12.4, tonic-build 0.10.2, native-tls, openssl-sys, ring
    "rust-toolchain.toml",           # channel = "nightly": binds rustup only
    "LICENSE.txt",                   # Apache License 2.0
    ".github/workflows/build.yml",   # listed; the CI's own build steps were not studied
    "etcd-client-0.12.4/build.rs",   # :5-17 tonic-build over proto/*.proto (from the crate source, read in the cargo registry)
    "prost-build-0.12.4/src/lib.rs", # :1507-1513 PROTOC
  ]

  consulted = [
    # Read for facts only: URL shape, that protoc is needed, the fixture shape and
    # that the binary prints "teller <version>". The Go build for <2 and the
    # ^1.78 floor are NOT verified here.
    "pkgxdev/pantry projects/tlr.dev/package.yml",
  ]

  note = <<EOT
⚠ THE RUNG IS A SINGLE HOST, STATED. The project publishes no checksum file and no
signature for the source; the release assets are binaries only. The annotated tag
v2.0.7 (tag object a7c4437a, commit 04f099a5) is unsigned. The digest records
GitHub's generated archive of that tag, fetched three ways (builder fetcher, curl
on the archive URL, curl on codeload.github.com) with one answer. The crates it
compiles are pinned by Cargo.lock's checksums, which cargo verifies under --locked.

Built and tested ON A MACHINE, NOT BY THE FACTORY: `cargo install --locked --path
teller-cli --root <dir>` on this source with cargo 1.99.0 / rustc 1.99.0
(darwin/arm64, Homebrew protoc) produced bin/teller; `teller --version` printed
"teller 2.0.7" and `teller -c teller.yml show` on the fixture printed
"[dot_1 (dotenv)]: foo = va***". The linux branches (OPENSSL_DIR, the libgcc
workaround, the ldd check) were NOT run and are carried from rust-lang.org/cargo's
recipe and from reading Cargo.lock.

⛔ NOT BUILT BY THE FACTORY. No session here can run it.
EOT
}
