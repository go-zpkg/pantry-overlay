# prefix.dev — pixi, "a package management and workflow tool"
# (prefix-dev/pixi). A FRAGMENT until now: it named libgit2 ~1.7 and openssl ^3
# and took its source, versions, build and test from the upstream pantry merged
# underneath. That merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is
# the WHOLE recipe, written from pixi's own files (go-zpkg/packages#431, #440
# step 1), at 0.84.2.
#
# ⭐⭐ WHAT WRITING IT FOUND, measured with `cargo tree --locked -p pixi
# [-i <crate>] --target <triple>` on the v0.84.2 tag:
#
#   - NEITHER libgit2 NOR OPENSSL IS NEEDED. crates/pixi/Cargo.toml:79 makes
#     `rustls` the default feature (native-tls is opt-in, :80), and the tree
#     holds no openssl-sys and no libgit2-sys on x86_64-unknown-linux-gnu or
#     aarch64-apple-darwin ("nothing to print" for openssl-sys on both; no
#     package named libgit2-sys). Both dependencies of the fragment are
#     dropped. (pixi does its git work through uv-git and pixi_git.)
#   - TLS is rustls 0.23.46 with AWS-LC (aws-lc-sys 0.45.0, compiled in) and
#     ring 0.17.14, on both platforms. The certificate store is read at run
#     time: rustls-platform-verifier on linux reads the system bundle
#     (hence curl.se/ca-certs), Security.framework answers on darwin.
#   - C code is COMPILED IN, not linked: zstd-sys, bzip2-sys, aws-lc-sys, ring.
#   - LINUX COMPILES D-BUS IN. rattler_networking's keyring store reaches
#     libdbus-sys 0.2.7 with its `vendored` feature on (cargo tree -e features
#     -i libdbus-sys), so build_vendored.rs builds and statically links
#     libdbus (rustc-link-lib=static=dbus, :395): no dbus dependency is
#     declared, and the binary leaves no libdbus dependency.
#   - cargo fetches one GIT dependency: [patch.crates-io] version-ranges from
#     astral-sh/pubgrub at a pinned rev (Cargo.toml:283-284), checked by
#     Cargo.lock. That is cargo's own fetch, not a fetch of the recipe.

summary = "pixi: a package management and workflow tool"

# Cargo.toml:24 license = "BSD-3-Clause" (workspace.package); LICENSE is the
# BSD 3-Clause text. The crates of Cargo.lock compiled in carry their own
# licences, which this expression does not enumerate.
license = "BSD-3-Clause"

versions {
  github = "prefix-dev/pixi"
  strip  = "/^v/"
}

distributable {
  # GitHub's archive of the tag v0.84.2, the newest release.
  url              = "https://github.com/prefix-dev/pixi/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 20384713 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.84.2" = "45bb2eb57c8b499962c2ed9a1683b3f120624318bcda4c4511fbd07a887a6ee6"
  }
}

# crates/pixi/Cargo.toml:2: the package `pixi`, whose only target is
# crates/pixi/src/main.rs (workspace default-members, Cargo.toml:16).
provides = [
  "bin/pixi",
]

dependencies = {
  # rustls-platform-verifier reads the system CA bundle at run time on linux.
  linux = {
    "curl.se/ca-certs" = "*"
  }
}

runtime {
  env = {
    linux = {
      # openssl-probe (in the tree, rustls-native-certs) honours SSL_CERT_FILE
      # before probing the usual places.
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

    # Edition 2024 (Cargo.toml:20); the rust-toolchain file pins 1.98.1, which
    # no rustup reads here, so the compiler this tree carries is named.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # AWS-LC is COMPILED IN, NOT LINKED (aws-lc-sys vendors its sources); see
    # crates.io/drill for the choice of the cc builder over the CMake builder.
    AWS_LC_SYS_CMAKE_BUILDER = 0
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
# The workspace root has no package, so the binary crate is named by its path.
cargo install --locked --path crates/pixi --root {{prefix}}
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
P="{{prefix}}/bin/pixi"
test -x "$P"
# crates/pixi_cli/src/lib.rs:64-65: name = "pixi", version(PIXI_VERSION), and
# crates/pixi_consts/src/consts.rs:17-20 falls back to "0.84.2" when the
# PIXI_VERSION variable is unset at build time. (The help flag is disabled at
# lib.rs:90, so only --version is asserted.)
OUT="$("$P" --version)"
if [ "$OUT" != "pixi 0.84.2" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi

# Neither OpenSSL, libgit2 nor D-Bus is a dependency: all C code is compiled in.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$P")"; else LIBS="$(ldd "$P")"; fi
case "$LIBS" in
  *libssl*|*libcrypto*|*libgit2*|*libdbus*) echo "pixi links a library no dependency declares:" >&2; echo "$LIBS" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",                           # :16 default-members, :20 edition, :24 licence, :283-284 patch version-ranges (git), :291 reqwest-middleware shim
    "Cargo.lock",                           # rustls 0.23.46, aws-lc-sys 0.45.0, ring 0.17.14, zstd-sys 2.1.2, bzip2-sys 0.1.13, libdbus-sys 0.2.7
    "crates/pixi/Cargo.toml",               # :2 name, :3 version, :79-83 features (default rustls, opt-in native-tls)
    "crates/pixi/src/main.rs",              # the only target
    "crates/pixi_cli/src/lib.rs",           # :64-65 command name and version, :90 disable_help_flag
    "crates/pixi_consts/src/consts.rs",     # :17-20 PIXI_VERSION
    "rust-toolchain",                       # 1.98.1
    "libdbus-sys-0.2.7/build.rs",           # :14-29 pkg-config probe unless `vendored`
    "libdbus-sys-0.2.7/build_vendored.rs",  # :394-395 static link of the compiled copy
    "LICENSE",                              # BSD 3-Clause
  ]

  consulted = [
    # Read for facts only: the project name. NOT taken: libgit2 ~1.7 and
    # openssl ^3, which the tree measured above does not use.
    "pkgxdev/pantry projects/prefix.dev/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked; the one git dependency is pinned by its rev.

The dependency facts above were measured with `cargo tree --locked` on the
0.84.2 source, for a linux and a darwin target.

⛔ NOT BUILT, NOT TESTED. The build itself (a very large workspace, compiling
AWS-LC, zstd, bzip2 and libdbus in) was not run. The first factory run is this
file's test.
EOT
}
