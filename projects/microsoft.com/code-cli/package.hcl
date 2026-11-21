# microsoft.com/code-cli — the command-line launcher and tunnel of VS Code
# (microsoft/vscode, directory cli/). A FRAGMENT until now: it named openssl ^3
# and zlib and took its source, versions, build and test from the upstream
# pantry merged underneath. That merge ended with zpkb v0.90.0
# (go-zpkg/zpkb#514), so this is the WHOLE recipe, written from the project's own
# files (go-zpkg/packages#431, #440 step 1), at 1.147.0.
#
# ⭐⭐ WHAT WRITING IT FOUND, measured with `cargo tree --locked -e normal,build
# [-i <crate>] --target <triple>` on the 1.147.0 tag:
#
#   - OPENSSL IS LINKED ON BOTH PLATFORMS. reqwest 0.13 and tokio-tungstenite
#     take native-tls (cli/Cargo.toml:18, :42), which is OpenSSL on linux; and
#     on darwin openssl-sys 0.9.116 is still in the tree, through
#     russh 0.37.1 and russh-keys (Microsoft's vscode-russh fork), which the
#     `tunnels` crate pulls. No openssl-src is in the tree: OpenSSL is never
#     compiled in, so a missing system OpenSSL fails the build.
#   - zlib: libz-sys 1.1.23 (flate2 and zip, `zlib` features, :21-22) probes
#     pkg-config first and compiles its own copy on a miss; LIBZ_SYS_STATIC is
#     not set (as in rust-lang.org/cargo).
#   - No libdbus: the linux keyring and secret-service code goes through zbus
#     (cli/Cargo.toml:76), which is pure Rust.
#   - THE SOURCE IS THE WHOLE EDITOR REPOSITORY (an 89.8 MB archive) because
#     cli/build.rs:139-166 reads ../package.json (the version) and
#     ../product.json (the product name, quality, endpoints). The result is
#     therefore the Code - OSS build, not Microsoft's branded product: product.json
#     names the application "code-oss" (:4), and that name is the command name
#     clap prints (cli/src/commands/args.rs:59).
#   - Two GIT dependencies are fetched by cargo, both pinned by Cargo.lock:
#     tunnels (microsoft/dev-tunnels at rev b73b0eb7, cli/Cargo.toml:36) and the
#     russh forks (microsoft/vscode-russh, branch main, :79-81, locked to
#     fd4f608a). That is cargo's own fetch, not a fetch of the recipe.

summary = "code-cli: the VS Code command-line launcher and tunnel"

# product.json:8 licenseName "MIT"; LICENSE.txt is the MIT text. The crates of
# cli/Cargo.lock compiled in carry their own licences, which this expression
# does not enumerate.
license = "MIT"

versions {
  github = "microsoft/vscode"

  # The repository carries a stray tag "v14" (read as version 14), which would
  # sort above every release; the releases are all MAJOR.MINOR.PATCH, tagged
  # without a `v`.
  ignore = ["/^v\\d+$/"]
}

distributable {
  # GitHub's archive of the tag 1.147.0 (the repository's tags carry no `v`).
  url              = "https://github.com/microsoft/vscode/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 89789176 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "1.147.0" = "b3b7d5f314a963eba0dc430bf3ca88212a029e9c373a517a8a4d5e1872f9f292"
  }
}

# cli/Cargo.toml:11-12: the binary `code`; the package is code-cli and
# default-run is `code`.
provides = [
  "bin/code",
]

dependencies = {
  # native-tls -> openssl-sys on linux, and russh -> openssl-sys on darwin.
  "openssl.org" = "^3"

  # libz-sys: pkg-config first (see the header).
  "zlib.net" = "^1"
}

build {
  dependencies = {
    "gnu.org/tar"                = "*"
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Edition 2021 (cli/Cargo.toml:4); the manifest declares no rust-version, and
    # tokio 1.52 and reqwest 0.13 are recent, so the compiler this tree carries
    # is named.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  script = [
    {
      run = <<EOT
set -eu
# openssl-sys refuses to guess without OPENSSL_DIR when no pkg-config answers.
# The MAJOR symlink v3, not a concrete version (see rust-lang.org/cargo).
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

# cli/build.rs reads ../package.json and ../product.json, so the build runs from
# the repository's cli directory and the whole archive stays in place.
# ⛔ --locked: cli/Cargo.lock is the dependency pin, and cargo verifies its checksums.
cd cli
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
C="{{prefix}}/bin/code"
test -x "$C"
# cli/src/commands/args.rs:53-61: clap prints the command name (applicationName
# of product.json, "code-oss"), then "<package.json version> (commit
# <VSCODE_CLI_COMMIT or unknown>)". Only the name and the version are asserted.
OUT="$("$C" --version)"
case "$OUT" in
  "code-oss 1.147.0 "*) ;;
  *) echo "--version printed '$OUT'" >&2; exit 1 ;;
esac
"$C" --help > help.txt
test -s help.txt

# OpenSSL is system-linked (linux through native-tls, darwin through russh).
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$C")"; else LIBS="$(ldd "$C")"; fi
case "$LIBS" in
  *libssl*) ;;
  *) echo "code does not link libssl:" >&2; echo "$LIBS" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "cli/Cargo.toml",             # :2 name, :11-12 bin code, :18 reqwest native-tls, :21-22 zlib features, :36 tunnels git rev, :37 keyring, :42 tokio-tungstenite native-tls, :76 zbus, :79-81 russh forks
    "cli/Cargo.lock",             # openssl 0.10.80, openssl-sys 0.9.116 (no openssl-src), native-tls 0.2.15, libz-sys 1.1.23
    "cli/build.rs",               # :139-166 package.json version and product.json read from ..
    "cli/src/commands/args.rs",   # :45-61 the version string and the command name
    "cli/src/constants.rs",       # :37 VSCODE_CLI_VERSION, :42 VSCODE_CLI_COMMIT, :57 APPLICATION_NAME
    "package.json",               # :3 version 1.147.0
    "product.json",               # :4 applicationName code-oss, :8 licenseName MIT
    "LICENSE.txt",                # MIT
  ]

  consulted = [
    # Read for facts only: the project name and that it builds the cli
    # directory. NOT taken: its dependency lines.
    "pkgxdev/pantry projects/microsoft.com/code-cli/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by cli/Cargo.lock's checksums, which cargo
verifies under --locked; the two git dependencies are pinned by rev and by
lock.

The OpenSSL split was measured with `cargo tree --locked -i openssl-sys
--target <triple>` on the 1.147.0 source for a linux and a darwin target.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only; in particular
the `--version` text (clap's name and the version) is read from the sources,
not run. The first factory run is this file's test.
EOT
}
