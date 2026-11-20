# crates.io/gitopolis — manage multiple git repositories from one folder
# (rustworkshop/gitopolis). A FRAGMENT until now: it said what the binary needs
# and took its source, versions, build and test from the upstream pantry merged
# underneath. That merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is
# the WHOLE recipe, written from gitopolis's own files (go-zpkg/packages#431,
# #440 step 1), at 1.17.2.
#
# ⭐⭐ WHAT WRITING IT FOUND.
#
#   - OPENSSL WAS COMPILED IN. Cargo.toml:24 asks for the `openssl` crate with
#     features = ["vendored"], so openssl-sys builds openssl-src 300.6.0+3.6.2
#     (Cargo.lock:667) UNLESS OPENSSL_NO_VENDOR is set (openssl-sys 0.9.114
#     build/main.rs:49-54). The fragment's `openssl.org ^3` dependency was never
#     what the binary used. Named now: OPENSSL_NO_VENDOR=1 plus OPENSSL_DIR, and
#     a missing system OpenSSL is then a panic, not a silent compile.
#   - The fragment pinned libgit2 `~1.7`; libgit2-sys 0.18.3+1.9.2 (Cargo.lock:
#     544) accepts "1.9.2".."1.10.0" only (build.rs:10). Now `~1.9`, with
#     LIBGIT2_NO_VENDOR (build.rs:36-48).
#   - Cargo.toml:3 says version = "0.0.0-git": upstream stamps the version at
#     release time (.github/workflows/_release.yml:37). Unstamped, the binary
#     reports 0.0.0-git. The script stamps Cargo.toml AND Cargo.lock (:321), or
#     --locked refuses the build.
#   - The binary RUNS `git` (src/git.rs:59,80,110; src/exec.rs): declared.

summary = "gitopolis: manage multiple git repositories with tags, clone and exec"

# Cargo.toml:10 license = "AGPL-3.0-only"; LICENSE is the GNU AGPL text. The
# crates of Cargo.lock compiled in carry their own licences, which this
# expression does not enumerate.
license = "AGPL-3.0-only"

versions {
  github = "rustworkshop/gitopolis"
  strip  = "/^v/"
}

distributable {
  # GitHub's archive of the tag v1.17.2.
  url              = "https://github.com/rustworkshop/gitopolis/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 154015 bytes. Recorded with `zpkb sourcepin` (v0.92.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "1.17.2" = "6fac7b69de953f0407d5cfc7f6f6cea1aa0c021767c0b08f6f2e9c256695a869"
  }
}

# Cargo.toml:2: the package `gitopolis`; src/main.rs is its only target.
provides = [
  "bin/gitopolis",
]

dependencies = {
  # Run as a subprocess: src/git.rs:59,80,110, and every `gitopolis exec` line.
  "git-scm.org" = "^2"

  # git2 0.20.4 with its default features (Cargo.toml:19): https and ssh, so
  # libgit2-sys 0.18.3 -> libssh2-sys 0.3.1 (Cargo.lock:558), libz-sys 1.1.28
  # (:572) and openssl-sys 0.9.114 (:676).
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

    # gitopolis's own CI pins rust 1.95.0 (.tool-versions) and declares no
    # rust-version; the compiler this tree carries is named, not an invented
    # floor.
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

    # ⛔ 3. OpenSSL: the `vendored` feature is ON (Cargo.toml:24), so this is
    # what turns it off: openssl-sys 0.9.114 build/main.rs:49-54 skips
    # find_vendored when OPENSSL_NO_VENDOR exists and is not 0.
    OPENSSL_NO_VENDOR = 1

    # 4. zlib: libz-sys 1.1.28 prefers pkg-config, then a link probe, then its
    # own build (as in rust-lang.org/cargo). LIBZ_SYS_STATIC is NOT set. Not
    # fatal on a miss; the test reads the link off the binary.
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

# The version stamp upstream's release workflow applies (_release.yml:37 does
# Cargo.toml only and builds without --locked). Here BOTH files carry the
# placeholder, once each, and --locked needs them to agree.
grep -c '^version = "0.0.0-git"$' Cargo.toml Cargo.lock
sed -i.bak 's/^version = "0\.0\.0-git"$/version = "{{version}}"/' Cargo.toml Cargo.lock
rm -f Cargo.toml.bak Cargo.lock.bak
if grep -q '0\.0\.0-git' Cargo.toml Cargo.lock; then echo "the version placeholder is still there" >&2; exit 1; fi

# ⛔ --locked: Cargo.lock is the dependency pin, and cargo verifies its checksums.
cargo install --locked --path . --root {{prefix}}
EOT
    },
  ]
}

test {
  dependencies = {
    "git-scm.org" = "^2"
  }

  script = [
    {
      run = <<EOT
set -eu
G="{{prefix}}/bin/gitopolis"
test -x "$G"
# src/main.rs:16: clap `version`, so "<package> <version>", the stamped one.
OUT="$("$G" --version)"
if [ "$OUT" != "gitopolis 1.17.2" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi

# Real repositories, outcomes read off the files and the work tree.
export HOME="$(mktemp -d)"
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@localhost GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@localhost
T="$(mktemp -d)"
cd "$T"
git init -q --bare -b main origin.git
git clone -q origin.git seed 2>/dev/null
( cd seed && echo hello > README.md && git add README.md && git commit -q -m init && git push -q origin main )

mkdir w1
cd w1
git clone -q "$T/origin.git" r1
"$G" add r1
grep -q 'path = "r1"' .gitopolis.toml
grep -q "origin.git" .gitopolis.toml
OUT="$("$G" list)"
case "$OUT" in
  *r1*) ;;
  *) echo "list does not name r1: '$OUT'" >&2; exit 1 ;;
esac
OUT="$("$G" exec -- git rev-parse --is-inside-work-tree)"
case "$OUT" in
  *true*) ;;
  *) echo "exec did not run git in r1: '$OUT'" >&2; exit 1 ;;
esac

# And the other direction: the file alone recreates the working copy.
cd "$T"
mkdir w2
cp w1/.gitopolis.toml w2/
cd w2
"$G" clone
test -f r1/README.md
if [ "$(cat r1/README.md)" != "hello" ]; then echo "cloned README.md differs" >&2; exit 1; fi

# What it links: the declared libraries, none of them compiled in.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$G")"; else LIBS="$(ldd "$G")"; fi
for l in libgit2 libssh2 libz; do
  case "$LIBS" in
    *"$l"*) ;;
    *) echo "gitopolis does not link $l:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
done
if [ "$(uname -s)" = Linux ]; then
  case "$LIBS" in
    *libssl*) ;;
    *) echo "gitopolis does not link libssl on linux:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
fi
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",   # :3 version 0.0.0-git, :10 licence, :16-25 dependencies, :19 git2 0.20.4, :24 openssl vendored
    "Cargo.lock",   # :321 the root package's version, :544 libgit2-sys 0.18.3+1.9.2, :558 libssh2-sys 0.3.1, :572 libz-sys, :667 openssl-src 300.6.0+3.6.2, :676 openssl-sys 0.9.114
    ".github/workflows/_release.yml",  # :37 the version stamp; _ci.yml:121,130 the same
    ".tool-versions",                  # rust 1.95.0
    "src/main.rs",  # :16 clap version, :24-70 the subcommands, :151-175 add, list, exec
    "src/git.rs",   # :59, :80, :110 Command::new("git")
    "libgit2-sys-0.18.3+1.9.2/build.rs",  # :10 "1.9.2".."1.10.0", :36-48 LIBGIT2_NO_VENDOR
    "libssh2-sys-0.3.1/build.rs",         # :22-39 LIBSSH2_SYS_USE_PKG_CONFIG
    "openssl-sys-0.9.114/build/main.rs",  # :49-54 OPENSSL_NO_VENDOR under the vendored feature
    "LICENSE",      # GNU Affero General Public License
  ]

  consulted = [
    # Read for facts only: the tag URL, `cargo install --locked --path .`, and
    # the clone-based test idea. NOT taken: openssl ^1.1, libgit2 ~1.7, rust
    # ^1.70 as a floor, the test that clones from github.com over the network.
    "pkgxdev/pantry projects/crates.io/gitopolis/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only, on a loaded
machine. Unverified: that cargo accepts the stamped root-package version under
--locked (it should: the lockfile entry is stamped identically), the exact
output of `list` and `exec` (the test greps for a word, not a format), and
that libssh2-sys finds libssh2.pc. The first factory run is this file's test.
EOT
}
