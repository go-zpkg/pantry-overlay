# crates.io/rucola-notes — a terminal-based markdown note manager (the binary
# `rucola`, from Linus-Mussmaecher/rucola). A FRAGMENT until now: it said what
# the binary needs and took its source, versions, build and test from the
# upstream pantry merged underneath. That merge ended with zpkb v0.90.0
# (go-zpkg/zpkb#514), so this is the WHOLE recipe, written from rucola's own
# files (go-zpkg/packages#431, #440 step 1), at 0.10.0.
#
# ⭐⭐ WHAT WRITING IT FOUND.
#
#   - The fragment declared only `openssl.org ^3`. Cargo.toml:29 takes git2
#     0.20 with its default features (https, ssh): libgit2-sys 0.18.3+1.9.2
#     (Cargo.lock:1389), libssh2-sys 0.3.1 (:1415), libz-sys 1.1.28 (:1429),
#     openssl-sys 0.9.113 (:1723). Without LIBGIT2_NO_VENDOR a missing system
#     libgit2 compiled its own copy in, silently. Named now, with libgit2 ~1.9
#     (build.rs:10 accepts "1.9.2".."1.10.0").
#   - build.rs:6-54 WRITES into the builder's configuration directory (confy:
#     config.toml and the default styles of rucola). A build side effect on the
#     user's home, not on the artifact; contained on linux below.
#   - The package is `rucola-notes` and the binary `rucola` ([[bin]] name,
#     Cargo.toml:54-57).

summary = "rucola: a terminal-based markdown note manager"

# Cargo.toml:12 license = "GPL-3.0-only"; LICENSE is the GNU GPL text. The
# crates of Cargo.lock compiled in carry their own licences, which this
# expression does not enumerate.
license = "GPL-3.0-only"

versions {
  github = "Linus-Mussmaecher/rucola"
  strip  = "/^v/"
}

distributable {
  # GitHub's archive of the tag v0.10.0.
  url              = "https://github.com/Linus-Mussmaecher/rucola/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 247381 bytes. Recorded with `zpkb sourcepin` (v0.92.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.10.0" = "afe89fbd51832fa69851b3f0a775f470326f3d583224c2b229a2e0ee49accbf8"
  }
}

# Cargo.toml:54-57: the one [[bin]], named `rucola` (the package is rucola-notes).
provides = [
  "bin/rucola",
]

dependencies = {
  "libgit2.org" = "~1.9"
  "libssh2.org" = "^1"
  "openssl.org" = "^3"
  "zlib.net"    = "^1"
}

build {
  dependencies = {
    "gnu.org/tar"                = "*"
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Edition 2021 (Cargo.toml:5); rucola declares no rust-version and none is
    # derivable without reading every crate of the lockfile (ratatui 0.30,
    # comrak 0.39 are recent), so the compiler this tree carries is named.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # ⛔ 1. libgit2: libgit2-sys 0.18.3 build.rs:36-48. LIBGIT2_NO_VENDOR makes a
    # missing or out-of-range system libgit2 a PANIC; without it a miss compiles
    # the vendored copy and says nothing.
    LIBGIT2_NO_VENDOR = 1

    # ⛔ 2. libssh2: libssh2-sys 0.3.1 build.rs:22-39. The system copy is used
    # ONLY when this variable is set, and if pkg-config then finds none the
    # script FALLS THROUGH to compiling its own — not fatal, so the test reads
    # the link off the binary.
    LIBSSH2_SYS_USE_PKG_CONFIG = 1

    # 3. zlib: libz-sys 1.1.28 prefers pkg-config, then a link probe, then its
    # own build (as in rust-lang.org/cargo). LIBZ_SYS_STATIC is NOT set.
    #
    # 4. VENDORED, STATED: onig_sys 69.9.1 (Cargo.lock:1696), syntect's regex
    # engine through comrak, compiles its bundled Oniguruma unless
    # RUSTONIG_SYSTEM_LIBONIG is set (onig_sys build.rs:224-255, fatal on a miss
    # then). This tree has no oniguruma recipe, so it is compiled in; the
    # switch belongs here the day one exists.
    #
    # 5. No openssl-src in Cargo.lock: OpenSSL is not compiled in.
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

  # build.rs:6-54 writes rucola's default configuration into the config
  # directory of whoever builds: point it at a throwaway one (linux honours
  # XDG_CONFIG_HOME; macOS's directory is under $HOME and is not redirected).
  export XDG_CONFIG_HOME="$PWD/.build-config"
  mkdir -p "$XDG_CONFIG_HOME"
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
R="{{prefix}}/bin/rucola"
test -x "$R"
# The TUI needs a terminal, so only what clap answers is run. src/main.rs:28
# #[command(version, about)]: the command is named after the PACKAGE.
OUT="$("$R" --version)"
if [ "$OUT" != "rucola-notes 0.10.0" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi
"$R" --help > help.txt
grep -q "Terminal-based markdown note manager" help.txt
grep -q -- "--style" help.txt

# What it links: libgit2, libssh2 and zlib are the system ones, none compiled in.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$R")"; else LIBS="$(ldd "$R")"; fi
for l in libgit2 libssh2 libz; do
  case "$LIBS" in
    *"$l"*) ;;
    *) echo "rucola does not link $l:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
done
if [ "$(uname -s)" = Linux ]; then
  case "$LIBS" in
    *libssl*) ;;
    *) echo "rucola does not link libssl on linux:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
fi
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",    # :5 edition, :12 licence, :20-50 dependencies, :29 git2 ^0.20, :54-57 [[bin]] rucola
    "Cargo.lock",    # :1389 libgit2-sys 0.18.3+1.9.2, :1415 libssh2-sys 0.3.1, :1429 libz-sys, :1684 onig, :1696 onig_sys 69.9.1, :1723 openssl-sys 0.9.113, :2539 syntect; no openssl-src
    "build.rs",      # :6-54 writes the default configuration into the config directory
    "src/main.rs",   # :28 clap version and about, :30-37 the arguments, :41-139 the TUI loop
    "libgit2-sys-0.18.3+1.9.2/build.rs",  # :10 "1.9.2".."1.10.0", :36-48 LIBGIT2_NO_VENDOR
    "libssh2-sys-0.3.1/build.rs",         # :22-39 LIBSSH2_SYS_USE_PKG_CONFIG
    "onig_sys-69.9.1/build.rs",           # :224-255 RUSTONIG_SYSTEM_LIBONIG
    "LICENSE",       # GNU General Public License
  ]

  consulted = [
    # Read for facts only: the tag URL, the binary name `rucola`, and the
    # version string `rucola-notes <version>`. NOT taken: openssl ^1.1, rust
    # >=1.56.
    "pkgxdev/pantry projects/crates.io/rucola-notes/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only, on a loaded
machine. Whether onig_sys is compiled for the default feature set is read from
Cargo.lock (syntect lists it), not from a build; the Cargo.toml line numbers of
the dependency table are counted, not grepped. The first factory run is this
file's test.
EOT
}
