# apollographql.com/rover — Rover, the Apollo GraphQL Registry CLI
# (apollographql/rover). Written whole from Rover's own files at 1.1.0
# (go-zpkg/packages#440 step 1), replacing a dependencies-only fragment.
#
# ⭐⭐ WHAT WRITING IT FOUND:
#
#   1. THE SIZE-BIG DEPENDENCIES ARE ALL IN-TREE RUST. Cargo.lock has no v8, no
#      deno_core, no openssl-sys and no native-tls: TLS is rustls 0.23.46 over
#      aws-lc-rs/aws-lc-sys 0.39.0, with certificates from rustls-native-certs
#      and rustls-platform-verifier (Cargo.lock :767-777, :6318-6370). Composition
#      is not a compiled-in JS engine: the `composition-js` feature is an EMPTY
#      marker (Cargo.toml:89) and the supergraph plugin is fetched at run time by
#      the program, not by this build.
#   2. libgit2 IS A REAL DEPENDENCY OF THE BINARY, NOT A TEST ONE. git2 0.21 with
#      default features off (Cargo.toml:169) is a regular dependency of
#      crates/rover-client (crates/rover-client/Cargo.toml:28, used in
#      src/shared/git_context.rs) and also a dev-dependency of the root
#      (Cargo.toml:352). Without the `https` and `ssh` features libgit2-sys
#      0.18.8+1.9.7 pulls only cc, libc, libz-sys and pkg-config (Cargo.lock
#      :3913-3923): no OpenSSL, no libssh2. The fragment this replaces declared
#      libgit2 ~1.7, which that crate cannot use (it asks for 1.9). The crate
#      carries libgit2 1.9.7's source and builds it with cc when no system copy
#      answers (libgit2-sys build.rs:91-109); this recipe makes "no system copy"
#      certain with PKG_CONFIG=false, so zlib (libz-sys) is also the bundled one.
#      Neither libgit2 nor zlib nor openssl is therefore a dependency here.
#   3. rust-toolchain.toml pins 1.99.1 for rustup; this tree builds with the
#      cargo recipe's rustc. Cargo.toml has no rust-version and edition is 2024.
#
# ⛔ NOT BUILT by the factory; see the note (built by hand on darwin only).

summary = "rover: the Apollo GraphQL Registry command-line tool"

# Cargo.toml:33 license = "MIT"; the repository's only LICENSE file is MIT (its
# line 3 says some files may name another licence in a header; no licensing
# file exists in a subdirectory). Dependencies carry their own licences.
license = "MIT"

versions {
  github = "apollographql/rover/tags"
}

distributable {
  url              = "https://github.com/apollographql/rover/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 1911274 bytes. Recorded with `zpkb sourcepin` (v0.96.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "1.1.0" = "e95d6a8923f1fe3aff402156c12d037db46c2f99aa9c95099ec23c0c7ebeca1b"
  }
}

# Cargo.toml:10,14 package `rover`, default-run `rover`; no other [[bin]].
provides = [
  "bin/rover",
]

dependencies = {
  linux = {
    # rustls-native-certs / openssl-probe look for the CA bundle at run time.
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

    # edition 2024 needs rustc >= 1.85; rust-toolchain.toml pins 1.99.1.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # ⛔ No pkg-config: libgit2-sys and libz-sys probe it, and a host's libgit2
    # or zlib would otherwise be linked silently. `false` makes every probe fail,
    # so the bundled sources are built.
    PKG_CONFIG = "false"

    # ⛔ aws-lc-sys 0.39.0 otherwise drives CMake (cmake is in Cargo.lock :1325);
    # the cc builder needs none (aws-lc-sys builder/main.rs:566-584).
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
# ⛔ Features, named (Cargo.toml:83-89): `default` is [composition-js], an empty
# marker; it is left on, and no other feature of the root package exists.
# ⛔ --locked: Cargo.lock is the dependency pin, and cargo verifies its checksums.
cargo build --locked --release --bin rover --features composition-js
mkdir -p "{{prefix}}/bin"
cp target/release/rover "{{prefix}}/bin/rover"
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
R="{{prefix}}/bin/rover"
test -x "$R"
OUT="$("$R" --version)"
case "$OUT" in
  *"1.1.0"*) ;;
  *) echo "--version printed '$OUT'" >&2; exit 1 ;;
esac
"$R" --help > help.txt
grep -q "supergraph" help.txt
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",                       # :10-14 name rover, version 1.1.0, default-run; :33 licence MIT; :83-89 features, default = [composition-js] (empty); :169 git2 default-features off; :203 reqwest default-features off; :363 reqwest `rustls`
    "Cargo.lock",                       # :767-777 aws-lc-rs, aws-lc-sys 0.39.0; :1325 cmake; :3913-3923 libgit2-sys 0.18.8+1.9.7 (cc, libc, libz-sys, pkg-config); :4782 openssl-probe; :6318-6370 rustls 0.23.46, rustls-native-certs, rustls-platform-verifier; grep finds no v8, deno_core, openssl-sys, native-tls
    "crates/rover-client/Cargo.toml",   # :28 git2 is a regular dependency
    "crates/rover-client/src/shared/git_context.rs",  # the git2 use
    "LICENSE",                          # MIT
    "rust-toolchain.toml",              # channel 1.99.1; rustup only
    "~/.cargo/registry libgit2-sys-0.18.8+1.9.7/build.rs",  # :85-109 vendored/system selection, LIBGIT2_NO_VENDOR
    "~/.cargo/registry aws-lc-sys-0.39.0/builder/main.rs",  # :566-584 CMAKE_BUILDER switch
  ]

  consulted = [
    "projects/crates.io/zellij/package.hcl",  # this repository: the cargo/gcc/CA-bundle pattern, used for its shape only
  ]

  note = <<EOT
⛔ NOT BUILT by the factory; the linux path was never run. By hand, on
aarch64-apple-darwin with cargo 1.99.0 (Homebrew), the same command with
PKG_CONFIG=false and AWS_LC_SYS_CMAKE_BUILDER=0 in the environment finished in
2 min 1 s; `rover --version` printed "Rover 1.1.0" and `rover --help` mentions
`supergraph`. otool -L showed system frameworks, libiconv and the system
libz.1.dylib (libz-sys uses the macOS zlib there rather than building one);
on linux libz-sys is expected to compile its bundled copy, which was not run.

⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no checksum
file or signature for the tag, and its release assets are prebuilt binaries; the
digest records GitHub's generated archive, fetched twice (the builder's fetcher,
curl) with one answer. The crates it compiles are pinned by Cargo.lock's
checksums, which cargo verifies under --locked.

C LIBRARIES, NAMED: libgit2 1.9.7 (bundled by libgit2-sys, built with cc;
PKG_CONFIG=false forbids a system copy) and zlib (libz-sys: bundled on linux,
the macOS system zlib on darwin); aws-lc (aws-lc-sys
0.39.0, cc builder). No OpenSSL, libssh2, libcurl, V8 or SQLite.
EOT
}
