# rust-lang.org/rustup — the Rust toolchain installer (rust-lang/rustup). A
# FRAGMENT until now: it said what the binary needs and took its source,
# versions, build and test from the upstream pantry merged underneath. That
# merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is the WHOLE recipe,
# written from rustup's own files (go-zpkg/packages#431, #440 step 1), at 1.29.3.
#
# ⭐⭐ WHAT WRITING IT FOUND: the fragment named two libraries and left out a
# third, and the features were never named.
#
#   - Cargo.toml:15 default = ["curl-backend", "reqwest-native-tls",
#     "reqwest-rustls-tls"]; ci/run.bash:23-45 is how the project builds its
#     release: --no-default-features, then curl-backend and reqwest-native-tls,
#     vendored-openssl (not on Windows), and reqwest-rustls-tls. This recipe
#     does the same MINUS vendored-openssl (a system OpenSSL is the point) and
#     PLUS no-self-update (Cargo.toml:28-29): a package manager owns the
#     binary, so `rustup self update` and `self uninstall` are compiled out.
#     Every feature is named; none is left to a default.
#   - Cargo.lock has FIVE -sys crates that look for a system library:
#       curl-sys 0.4.91+curl-8.22.0 (:526)  pkg-config "libcurl", and on a MISS
#                                           it compiles its bundled curl
#                                           (build.rs:73-82, 590-603). On Apple
#                                           it links the system libcurl
#                                           (build.rs:64-66), which is why the
#                                           fragment declared curl.se on linux
#                                           only. Not refusable by a switch.
#       openssl-sys 0.9.118 (:1582)         no `vendored` feature is on, so a
#                                           missing OpenSSL is a build error.
#       zstd-sys 2.1.2+zstd.1.5.7 (:3495)   build.rs:488-490: the system
#                                           library only when
#                                           ZSTD_SYS_USE_PKG_CONFIG is set.
#       lzma-sys 0.1.20 (:1388)             build.rs:12-23: pkg-config
#                                           "liblzma", bundled xz on a miss
#                                           (LZMA_API_STATIC would force it).
#       libz-sys 1.1.24 (:1358)             pkg-config first, own build on a
#                                           miss; LIBZ_SYS_STATIC is NOT set.
#   - aws-lc-sys 0.47.0 (:162, through rustls feature aws_lc_rs, Cargo.toml:85)
#     compiles its own AWS-LC with the cc builder (builder/main.rs:766-794) from
#     the crate's bundled C: there is no system aws-lc to take and no switch.
#     VENDORED, STATED. It needs a C compiler, not cmake, on a target with
#     prebuilt bindings.

summary = "rustup: the Rust toolchain installer and version manager"

# Cargo.toml:5 license = "MIT OR Apache-2.0"; LICENSE-MIT and LICENSE-APACHE
# are the two texts. The crates of Cargo.lock compiled in carry their own
# licences, which this expression does not enumerate.
license = "MIT OR Apache-2.0"

versions {
  # rust-lang/rustup publishes no GitHub release for 1.29.3 (the releases API
  # answers none for `latest`); its versions are tags, 1.29.3 newest.
  github = "rust-lang/rustup/tags"
}

distributable {
  # GitHub's archive of the tag 1.29.3 (rustup's tags carry no `v`).
  url              = "https://github.com/rust-lang/rustup/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 1070038 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "1.29.3" = "e830fb32300e2bb69068321e701a328a5ebbfe86ec468dbda82f4fc3f6d3f276"
  }
}

# The package builds ONE binary, rustup-init (src/bin/rustup-init.rs; no [[bin]]
# in Cargo.toml). It acts as `rustup` when argv[0] is "rustup" (:95-96), as the
# installer when it starts with "rustup-init" (:97-103), and as a proxy for any
# other name (:114-119). The proxies for cargo, rustc… are NOT provided: those
# names belong to rust-lang.org/cargo and rust-lang.org, and a second owner of
# bin/cargo would conflict. `rustup` is installed as a copy of rustup-init.
provides = [
  "bin/rustup",
  "bin/rustup-init",
]

dependencies = {
  "openssl.org" = "^3"
  "zlib.net"    = "^1"
  # zstd-sys 2.1.2+zstd.1.5.7, headers of zstd 1.5.7.
  "facebook.com/zstd" = "^1.5"
  "tukaani.org"       = "*"
  linux = {
    # curl-sys: pkg-config "libcurl" (an Apple host uses the system one).
    "curl.se" = "*"
  }
}

build {
  dependencies = {
    "gnu.org/tar"                = "*"
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.toml:4 edition 2024; src/bin/rustup-init.rs:107 uses cfg_select!,
    # stable from 1.95. rustup declares no rust-version, so the compiler this
    # tree carries is named, not an invented floor.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # ⛔ zstd-sys-2.1.2 build.rs:488-490 takes the system library when
    # ZSTD_SYS_USE_PKG_CONFIG is set, and compiles its bundled copy otherwise.
    ZSTD_SYS_USE_PKG_CONFIG = 1

    # curl-sys, lzma-sys and libz-sys fall back to a bundled build on a
    # pkg-config miss and cannot be told to refuse; the test reads the link
    # off the binary instead. openssl-sys has no `vendored` feature on, so a
    # miss stops the build.
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
# ⛔ --no-default-features and every feature NAMED (Cargo.toml:14-29): curl-backend,
# reqwest-native-tls and reqwest-rustls-tls as ci/run.bash:27,44 builds them,
# no-self-update for a package-managed binary. vendored-openssl and otel are off.
cargo install --locked --path . --root {{prefix}} \
  --no-default-features \
  --features curl-backend,reqwest-native-tls,reqwest-rustls-tls,no-self-update
# rustup-init is the one binary; `rustup` is it under another argv[0].
cp {{prefix}}/bin/rustup-init {{prefix}}/bin/rustup
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
B="{{prefix}}/bin"
test -x "$B/rustup"
test -x "$B/rustup-init"
# A throwaway home: rustup keeps toolchains and settings under RUSTUP_HOME and
# CARGO_HOME, and a test must not read or write the builder's.
H="$(mktemp -d)"
export RUSTUP_HOME="$H/rustup"
export CARGO_HOME="$H/cargo"
export NO_COLOR=1

# Both names answer with the package version (Cargo.toml:3).
OUT="$("$B/rustup" --version 2>/dev/null)"
case "$OUT" in
  "rustup 1.29.3"*) ;;
  *) echo "rustup --version printed '$OUT'" >&2; exit 1 ;;
esac
OUT="$("$B/rustup-init" --version 2>/dev/null)"
case "$OUT" in
  "rustup-init 1.29.3"*) ;;
  *) echo "rustup-init --version printed '$OUT'" >&2; exit 1 ;;
esac

# no-self-update: `rustup self uninstall` refuses (src/cli/self_update.rs:925-928)
# and must not remove anything. It exits non-zero and says why.
if "$B/rustup" self uninstall -y >"$H/uninstall.out" 2>&1; then
  echo "rustup self uninstall succeeded on a no-self-update build" >&2; exit 1
fi
case "$(cat "$H/uninstall.out")" in
  *"self-uninstall is disabled for this build of rustup"*) ;;
  *) echo "self uninstall printed:" >&2; cat "$H/uninstall.out" >&2; exit 1 ;;
esac

# An empty home has no toolchain, and the command must say so without a network.
OUT="$("$B/rustup" toolchain list 2>&1 || true)"
case "$OUT" in
  *"no installed toolchains"*) ;;
  *) echo "toolchain list on an empty home printed '$OUT'" >&2; exit 1 ;;
esac

# What the binary links is what the recipe declares: a bundled copy would leave
# one of these out.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$B/rustup-init")"; else LIBS="$(ldd "$B/rustup-init")"; fi
for l in libcurl libssl libzstd; do
  case "$LIBS" in
    *"$l"*) ;;
    *) echo "rustup-init does not link $l:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
done
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",   # :3 version, :4 edition 2024, :5 licence, :14-29 features, :53 curl, :72 openssl, :82 reqwest, :85 rustls aws_lc_rs, :108 zstd
    "Cargo.lock",   # :162 aws-lc-sys 0.47.0, :526 curl-sys, :1358 libz-sys 1.1.24, :1388 lzma-sys, :1582 openssl-sys, :3495 zstd-sys
    "src/cli/common.rs", "src/cli/self_update.rs",  # :297 the empty-home message; :925-928 the disabled uninstall
    "ci/run.bash",  # :23-45 the project's own feature set, :55 --locked
    "src/bin/rustup-init.rs",  # :95-119 behaviour by argv[0]
    "curl-sys-0.4.91+curl-8.22.0/build.rs",  # :56-82 system probe and fallback, :590-613 pkg-config
    "lzma-sys-0.1.20/build.rs",  # :12-23
    "libz-sys-1.1.24/build.rs",  # :33-46, :246-257
    "zstd-sys-2.1.2+zstd.1.5.7/build.rs",  # :488-490
    "openssl-sys-0.9.118/build/main.rs",   # :49-54 vendored is a feature
    "aws-lc-sys-0.47.0/builder/main.rs",   # :709-794 builder choice
    "LICENSE-MIT", "LICENSE-APACHE",
  ]

  consulted = [
    # Read for facts only: the tag URL. NOT taken: any feature set, since the
    # project's own ci/run.bash is the source of that.
    "pkgxdev/pantry projects/rust-lang.org/rustup/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only, on a loaded
machine. The test's two messages are read from the source (src/cli/common.rs:297
"no installed toolchains", src/cli/self_update.rs:926) but not run, and the
`--version` line shapes ("rustup 1.29.3 (hash date)") are the version.md
convention, not observed. The CHOICE of no-self-update is mine, from
Cargo.toml:28-29, not the project's release configuration.
EOT
}
