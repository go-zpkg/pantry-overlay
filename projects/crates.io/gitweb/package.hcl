# crates.io/gitweb — open the current repository's remote in a browser
# (yoannfleurydev/gitweb). A FRAGMENT until now: it said what the binary needs
# and took its source, versions, build and test from the upstream pantry merged
# underneath. That merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is
# the WHOLE recipe, written from gitweb's own files (go-zpkg/packages#431, #440
# step 1), at 0.6.0.
#
# ⭐⭐ WHAT WRITING IT FOUND.
#
#   - OPENSSL IS COMPILED IN. Cargo.toml:21 asks for git2 with the
#     `vendored-openssl` feature, so openssl-src 300.6.1+3.6.3 (Cargo.lock:627)
#     is built UNLESS OPENSSL_NO_VENDOR is set (openssl-sys 0.9.117). The
#     fragment's `openssl.org ^3` described a build that compiled its own.
#     Named now: OPENSSL_NO_VENDOR=1, so a missing system OpenSSL is a panic.
#   - The fragment pinned libgit2 to nothing (it had zlib and openssl only), so
#     libgit2-sys 0.18.8+1.9.7 (Cargo.lock:529) compiled its own copy silently.
#     Its build.rs:12 accepts system libgit2 "1.9.7".."1.10.0"; this tree has
#     1.9.7. LIBGIT2_NO_VENDOR now makes a miss fatal (build.rs:91-105).
#   - No `ssh` in the lockfile (no libssh2-sys): git2 0.21's default features
#     here are https only.

summary = "gitweb: open the current repository's remote in the browser"

# Cargo.toml:9 license = "Apache-2.0"; LICENSE is the Apache License 2.0 text.
# The crates of Cargo.lock compiled in carry their own licences, which this
# expression does not enumerate.
license = "Apache-2.0"

versions {
  github = "yoannfleurydev/gitweb"
  strip  = "/^v/"
}

distributable {
  # GitHub's archive of the tag v0.6.0.
  url              = "https://github.com/yoannfleurydev/gitweb/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 5919086 bytes. Recorded with `zpkb sourcepin` (v0.92.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.6.0" = "13e080897926746a18695aefb4ee6b4678f4908bb141249046df212d4249b44e"
  }
}

# Cargo.toml:10: the package `gitweb`; src/main.rs is its only binary.
provides = [
  "bin/gitweb",
]

dependencies = {
  # libgit2-sys 0.18.8+1.9.7 (Cargo.lock:529), libz-sys 1.1.29 (:542) and
  # openssl-sys 0.9.117 (:636) through git2 0.21 (Cargo.toml:21).
  "libgit2.org" = "~1.9.7"
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

    # Edition 2021 (Cargo.toml:5); gitweb declares no rust-version and none is
    # derivable without reading every crate of the lockfile, so the compiler this
    # tree carries is named, not an invented floor.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    # ⛔ 1. libgit2: libgit2-sys-0.18.8 build.rs:91-105. LIBGIT2_NO_VENDOR makes a
    # missing or out-of-range system libgit2 a PANIC; without it a miss compiles
    # the vendored copy and says nothing.
    LIBGIT2_NO_VENDOR = 1

    # ⛔ 2. OpenSSL: Cargo.toml:21 turns `vendored-openssl` ON; this turns it off
    # (openssl-sys build/main.rs:49-54: find_vendored is skipped when
    # OPENSSL_NO_VENDOR exists and is not 0).
    OPENSSL_NO_VENDOR = 1

    # 3. zlib: libz-sys 1.1.29 prefers pkg-config, then a link probe, then its
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
G="{{prefix}}/bin/gitweb"
test -x "$G"
# src/options.rs:8: #[command(version, about)] -> "<package> <version>".
OUT="$("$G" --version)"
if [ "$OUT" != "gitweb 0.6.0" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi

# An empty --browser makes it print the URL instead of opening one
# (src/options.rs:42-52); the URL shapes are src/lib.rs:87-90 for GitHub.
export HOME="$(mktemp -d)"
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@localhost GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@localhost
unset BROWSER
R="$(mktemp -d)"
cd "$R"
git init -q -b main .
git remote add origin git@github.com:acme/widget.git
echo x > x
git add x
git commit -q -m x

OUT="$("$G" --browser "")"
if [ "$OUT" != "https://github.com/acme/widget/tree/main" ]; then echo "branch URL was '$OUT'" >&2; exit 1; fi
OUT="$("$G" --browser "" --merge-request)"
if [ "$OUT" != "https://github.com/acme/widget/pulls" ]; then echo "merge request URL was '$OUT'" >&2; exit 1; fi
SHA="$(git rev-parse HEAD)"
OUT="$("$G" --browser "" --commit "$SHA")"
if [ "$OUT" != "https://github.com/acme/widget/commit/$SHA" ]; then echo "commit URL was '$OUT'" >&2; exit 1; fi

# What it links: libgit2 and zlib are the system ones, none compiled in.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$G")"; else LIBS="$(ldd "$G")"; fi
for l in libgit2 libz; do
  case "$LIBS" in
    *"$l"*) ;;
    *) echo "gitweb does not link $l:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
done
if [ "$(uname -s)" = Linux ]; then
  case "$LIBS" in
    *libssl*) ;;
    *) echo "gitweb does not link libssl on linux:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
fi
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",        # :5 edition, :9 licence, :10-13 name and version, :21 git2 0.21 + vendored-openssl
    "Cargo.lock",        # :529 libgit2-sys 0.18.8+1.9.7, :542 libz-sys 1.1.29, :627 openssl-src 300.6.1+3.6.3, :636 openssl-sys 0.9.117; no libssh2-sys
    "src/options.rs",    # :8 clap version, :42-52 --browser "" prints the URL, :32 --merge-request
    "src/main.rs",       # :11-33 the entry point
    "src/lib.rs",        # :87-90 the GitHub URL shapes, :345-363 their tests
    "libgit2-sys-0.18.8+1.9.7/build.rs",  # :12 "1.9.7".."1.10.0", :91-105 LIBGIT2_NO_VENDOR
    "openssl-sys-0.9.114/build/main.rs",  # :49-54 OPENSSL_NO_VENDOR under the vendored feature (read at 0.9.111 and 0.9.114, the same rule; 0.9.117 not opened)
    "LICENSE",           # Apache License 2.0
  ]

  consulted = [
    # Read for facts only: the tag URL, the binary name, `--version`. NOT taken:
    # openssl ^1.1, rust >=1.65, pkg-config as a build dependency without a
    # reason, and an unlocked build.
    "pkgxdev/pantry projects/crates.io/gitweb/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only, on a loaded
machine. The test's URLs come from src/lib.rs's own unit tests, not from a
run; whether `--merge-request` and `--commit` need more than a commit in the
work tree was not traced. The first factory run is this file's test.
EOT
}
