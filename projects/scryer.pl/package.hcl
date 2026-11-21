# scryer.pl — Scryer Prolog (mthom/scryer-prolog). A FRAGMENT until now: it said
# what the binary needs and took its source, versions, build and test from the
# upstream pantry merged underneath. That merge ended with zpkb v0.90.0
# (go-zpkg/zpkb#514), so this is the WHOLE recipe, written from Scryer's own
# files (go-zpkg/packages#431, #440 step 1), at 0.10.0.
#
# ⭐⭐ WHAT WRITING IT FOUND:
#
#   - The features were never named. Cargo.toml:20 default = ["ffi", "repl",
#     "hostname", "tls", "http", "crypto-full"]; each is named below.
#   - Only ONE system library is linked: OpenSSL, through native-tls 0.2.12
#     (feature `tls`, Cargo.toml:24, :97) and openssl-sys 0.9 (Cargo.lock:1983,
#     no `vendored` feature on, so a missing OpenSSL stops the build; native-tls
#     on Apple uses Security.framework, not OpenSSL).
#   - `ffi` pulls libffi-sys 3.3.1 (Cargo.lock:1643). Its `system` feature
#     (libffi-sys build/build.rs:13) is OFF through libffi 4.1.0 as Scryer
#     declares it (Cargo.toml:96), so libffi-sys BUILDS ITS BUNDLED libffi with
#     ./configure and make (build/not_msvc.rs:37-47). VENDORED, STATED: no
#     system libffi is taken, and make is a build dependency.
#   - ring 0.17 (Cargo.toml:74, Cargo.lock:2481) compiles its own C and
#     assembly: there is no system ring and no switch. VENDORED, STATED.
#   - rustls (Cargo.lock:2551) is in the lock through reqwest/warp but is not
#     what `tls` uses; the recipe does not claim it either way.

summary = "Scryer Prolog: a modern Prolog implementation written mostly in Rust"

# Cargo.toml:9 license = "BSD-3-Clause"; LICENSE is the text. The crates of
# Cargo.lock compiled in carry their own licences, which this does not enumerate.
license = "BSD-3-Clause"

versions {
  github = "mthom/scryer-prolog/tags"
}

distributable {
  # GitHub's archive of the tag v0.10.0.
  url              = "https://github.com/mthom/scryer-prolog/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 2236439 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.10.0" = "353eca4eea539e0a0eedb1572736bfcc64c5fb6fd2da3b8737c513ad62f60f3b"
  }
}

# Cargo.toml:2 the package `scryer-prolog`; src/bin/scryer-prolog.rs is its only
# binary (the library is also a cdylib, Cargo.toml:17, which `cargo install`
# does not install).
provides = [
  "bin/scryer-prolog",
]

dependencies = {
  "openssl.org" = "^3"
}

build {
  dependencies = {
    "gnu.org/tar"                = "*"
    "gnu.org/make"               = "*"
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.toml:14 rust-version = "1.85" (edition 2021), the project's own
    # floor; the compiler this tree carries is newer.
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
# ⛔ --locked: Cargo.lock is the dependency pin, and cargo verifies its checksums.
# ⛔ --no-default-features and every feature NAMED (Cargo.toml:20-26): ffi (the
# bundled libffi), repl, hostname, tls (OpenSSL), http (warp, reqwest) and
# crypto-full, which is what the project ships by default.
cargo install --locked --path . --root {{prefix}} \
  --no-default-features \
  --features ffi,repl,hostname,tls,http,crypto-full
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
F="{{prefix}}/bin/scryer-prolog"
test -x "$F"
# A throwaway HOME: -f skips ~/.scryerrc and --no-add-history keeps ~/.scryer_history
# unwritten (src/toplevel.pl:80-81, :99-102).
export HOME="$(mktemp -d)"

# -v prints the version and halts (src/toplevel.pl:78, :106-109). The text comes
# from git-version, which a tarball without .git may render as a hash or
# nothing, so only its success is asserted.
"$F" -f --no-add-history --version >"$HOME/version.out"

# -g runs a goal (:79, :111-118); the goal does arithmetic, prints, halts.
OUT="$("$F" -f --no-add-history -g 'X is 6*7, write(X), nl, halt' </dev/null)"
if [ "$OUT" != "42" ]; then echo "goal printed '$OUT', want 42" >&2; exit 1; fi

# A library module loads: lists:reverse/2 through use_module.
OUT="$("$F" -f --no-add-history -g 'use_module(library(lists)), reverse([1,2,3], R), write(R), nl, halt' </dev/null)"
if [ "$OUT" != "[3,2,1]" ]; then echo "reverse printed '$OUT', want [3,2,1]" >&2; exit 1; fi

# TLS is OpenSSL's: the binary links libssl (Apple uses Security.framework).
if [ "$(uname -s)" = Linux ]; then
  case "$(ldd "$F")" in
    *libssl*) ;;
    *) echo "scryer-prolog does not link libssl" >&2; exit 1 ;;
  esac
fi
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",    # :9 licence, :12 build.rs, :14 rust-version, :17 cdylib, :20-26 features, :74 ring, :96 libffi, :97 native-tls
    "Cargo.lock",    # :1643 libffi-sys 3.3.1, :1983 openssl-sys, :2481 ring, :2551 rustls
    "src/bin/scryer-prolog.rs",  # the one binary
    "src/toplevel.pl",           # :76-118 the command line: -h -v -g -f --no-add-history
    "README.md",     # :148-169 `cargo install --locked`
    "libffi-sys-3.3.1/Cargo.toml",          # :45-47 features complex, system
    "libffi-sys-3.3.1/build/build.rs",      # :13 the `system` feature
    "libffi-sys-3.3.1/build/not_msvc.rs",   # :37-47 configure and make
    "LICENSE",
  ]

  consulted = [
    # Read for facts only: the tag URL. NOT taken: the feature set.
    "pkgxdev/pantry projects/scryer.pl/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only, on a loaded
machine. The flags in the test are read from src/toplevel.pl; the two goals
and their output ("42", "[3,2,1]") are standard Prolog but were not run, and
library(lists) availability under -f was not read. The first factory run is
this file's test.
EOT
}
