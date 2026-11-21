# dns.lookup.dog — dog, a command-line DNS client (ogham/dog, site
# https://dns.lookup.dog/). Written whole from dog's own files at 0.1.0
# (go-zpkg/packages#440 step 1), replacing a dependencies-only fragment.
#
# ⭐⭐ WHAT WRITING IT FOUND:
#
#   1. THE PROJECT IS STALE AND ITS ONE TAG IS 0.1.0 (2021): `git ls-remote --tags`
#      lists v0.1.0 only. The tag ships Cargo.lock. It DOES build on current
#      stable Rust (rustc/cargo 1.99.0, 2026-08-27) from that lock: `cargo build
#      --locked --release` and `--no-default-features` both finished, by hand,
#      on aarch64-apple-darwin (see the note).
#   2. ON LINUX THE DEFAULT FEATURES CANNOT BUILD AGAINST THIS TREE'S OPENSSL.
#      `default = ["tls", "https"]` (Cargo.toml:64) means native-tls, which is
#      OpenSSL on linux, and Cargo.lock pins openssl-sys 0.9.58, whose build
#      script refuses anything but "OpenSSL 1.0.1 through 1.1.1, or LibreSSL 2.5"
#      (openssl-sys-0.9.58/build/main.rs:263). openssl.org here is 3.x. So on
#      linux this recipe builds with `--no-default-features`: DNS over UDP and
#      TCP work, and `--tls` (-S) and `--https` (-H) are compiled out. On darwin
#      the same crate uses Security.framework (otool -L shows no libssl) and the
#      default features are kept. This recipe does NOT run `cargo update`:
#      --locked is the pin.
#   3. THE VERSION BANNER NEEDS NO GIT. build.rs:33-38 shows the git hash and
#      build date only when the version ends in `-pre` or PROFILE is debug; a
#      release build runs no `git`.
#
# ⛔ NOT BUILT by the factory; see the note.

summary = "dog: a command-line DNS client"

# Cargo.toml:13 license = "EUPL-1.2"; LICENCE is the EUPL v. 1.2 text.
license = "EUPL-1.2"

versions {
  github = "ogham/dog/tags"
}

distributable {
  url              = "https://github.com/ogham/dog/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 449366 bytes. Recorded with `zpkb sourcepin` (v0.96.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.1.0" = "82387d38727bac7fcdb080970e84b36de80bfe7923ce83f993a77d9ac7847858"
  }
}

# Cargo.toml:16-17 [[bin]] name = "dog".
provides = [
  "bin/dog",
]

build {
  dependencies = {
    "gnu.org/tar" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.toml:7 edition 2018; no rust-version. Built by hand with 1.99.0.
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
  # ⛔ Features, named (Cargo.toml:63-66): none on linux. `tls` and `https` need
  # openssl-sys 0.9.58, which refuses OpenSSL 3 (see the header).
  cargo build --locked --release --no-default-features
else
  # ⛔ Features, named: tls and https = native-tls = Security.framework here.
  cargo build --locked --release --no-default-features --features tls,https
fi
mkdir -p "{{prefix}}/bin"
cp target/release/dog "{{prefix}}/bin/dog"
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
D="{{prefix}}/bin/dog"
test -x "$D"
OUT="$("$D" --version)"
case "$OUT" in
  *"v0.1.0"*) ;;
  *) echo "--version printed '$OUT'" >&2; exit 1 ;;
esac
"$D" --help > help.txt
grep -q "command-line DNS client" help.txt
grep -q -e "--tcp" help.txt
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",    # :2 name dog; :7 edition 2018; :13 licence EUPL-1.2; :14 version 0.1.0; :16-17 [[bin]]; :63-66 [features] default = [tls, https]
    "Cargo.lock",    # :346 native-tls, :370 openssl, :390-393 openssl-sys 0.9.58; `cargo tree --locked --no-default-features -e normal,build` lists no openssl and no native-tls
    "build.rs",      # :33-38 version banner, :82-84 development-version test, :71-74 git only in that case
    "LICENCE",       # EUPL v. 1.2
    "~/.cargo/registry openssl-sys-0.9.58/build/main.rs",  # :263 OpenSSL 1.0.1 through 1.1.1 only
  ]

  consulted = []

  note = <<EOT
⛔ NOT BUILT by the factory; the linux path was never run. By hand, on
aarch64-apple-darwin with cargo 1.99.0 (Homebrew): `cargo build --locked
--release` (default features) finished in 6 s and `dog --version` printed
"dog ● command-line DNS client / v0.1.0 / https://dns.lookup.dog/"; otool -L
listed Security.framework, CoreFoundation and libSystem only.
`cargo build --locked --release --no-default-features` also finished, and its
`--help` lists --tcp, --tls and --https (the flags exist and fail at run time
without the features). The `--features tls,https` spelling used on darwin is the
same as the default and was not run separately.

⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no checksum
file or signature for the tag; the digest records GitHub's generated archive,
fetched twice (the builder's fetcher, curl) with one answer. The crates it
compiles are pinned by Cargo.lock's checksums, which cargo verifies under
--locked.

C LIBRARIES, NAMED: none on linux (no openssl, no zlib); Security.framework on
darwin.
EOT
}
