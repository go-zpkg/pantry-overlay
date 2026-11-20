# crates.io/git-trim — trims tracking branches whose upstream is merged or gone
# (foriequal0/git-trim). A FRAGMENT until now: it said what the binary needs
# and took its source, versions, build and test from the upstream pantry merged
# underneath. That merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is
# the WHOLE recipe, written from git-trim's own files (go-zpkg/packages#431,
# #440 step 1), at 0.4.3.
#
# ⭐⭐ WHAT WRITING IT FOUND.
#
#   - The binary RUNS `git` (src/subprocess.rs:17,32: Command::new("git"), for
#     fetch, branch listing, worktrees, checkout, deletion). The fragment did
#     not depend on it. Declared now.
#   - libgit2 is COMPILED IN, whatever the tree carries: Cargo.lock locks
#     libgit2-sys 0.13.4+1.4.2 (:419), whose build.rs:18 accepts a system libgit2
#     only in "1.4.0".."1.5.0"; this tree has 1.9.7. There is no switch that
#     makes a miss fatal in 0.13.4 (no LIBGIT2_NO_VENDOR), so libgit2 1.4.2 is
#     built from the crate's own copy, and said so. (The fragment pinned
#     `libgit2.org ~1.7`, which that crate could not use either.)
#   - build.rs runs vergen 7.4.3, which opens the git repository around the
#     source (vergen src/feature/git.rs:247, Repository::discover, `?`): a
#     GitHub archive has none, and the build fails. Upstream's pantry recipe
#     cloned the repository for this reason. The script makes a throwaway
#     repository of the unpacked tree instead; see the build script for what
#     that changes.

summary = "git-trim: trim tracking branches whose upstream is merged or gone"

# Cargo.toml:4 license = "MIT"; LICENSE is the MIT text. The crates of
# Cargo.lock compiled in (libgit2, libssh2-sys's sources) carry their own
# licences, which this expression does not enumerate.
license = "MIT"

versions {
  github = "foriequal0/git-trim"
  strip  = "/^v/"
}

distributable {
  # GitHub's archive of the tag v0.4.3.
  url              = "https://github.com/foriequal0/git-trim/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 2699243 bytes. Recorded with `zpkb sourcepin` (v0.92.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.4.3" = "1dc891463c31eaa3b9d836eb922448c8f550ae5436f2a5e47ab42c857b5f5cd1"
  }
}

# Cargo.toml:2 package `git-trim`; default-run (:14) is `git-trim`, and the other
# [[bin]], build-man (:16-18), needs the `build-man` feature, which is not
# enabled: `cargo install` installs src/main.rs's binary only.
provides = [
  "bin/git-trim",
]

dependencies = {
  # Run as a subprocess (src/subprocess.rs): branch listing, fetch, checkout,
  # branch deletion. The fragment had no dependency on it.
  "git-scm.org" = "^2"

  # git2 0.14.4 default features (Cargo.toml:31): https + ssh. libgit2-sys
  # 0.13.4 builds its own libgit2 (see the header) against openssl-sys 0.9.78
  # (Cargo.lock:529) and zlib (libz-sys 1.1.8, :447), and libssh2 below.
  "openssl.org" = "^3"
  "zlib.net"    = "^1"

  # libssh2-sys 0.2.23 (Cargo.lock:433), build.rs:22-39: the system libssh2 is
  # used ONLY when LIBSSH2_SYS_USE_PKG_CONFIG is set; if pkg-config then finds
  # none the script FALLS THROUGH to compiling its own (not fatal). Set below,
  # and the test reads the link off the binary.
  "libssh2.org" = "^1"
}

build {
  dependencies = {
    "gnu.org/tar"                = "*"
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.toml:12 rust-version = "1.65" is git-trim's own, :11 edition 2021. The
    # compiler this tree carries is named: the locked crates are of 2022-2023
    # and the floor of the NEWEST of them is not derivable without reading each.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  env = {
    LIBSSH2_SYS_USE_PKG_CONFIG = 1
  }

  script = [
    {
      run = <<EOT
set -eu
# ⛔ openssl-sys 0.9.78 refuses to guess without OPENSSL_DIR when no pkg-config
# answers (build/find_normal.rs:15); every 3.x is ossl300 to it
# (build/main.rs:298). The MAJOR symlink v3, not a concrete version (see
# rust-lang.org/cargo). No `vendored` feature is on (openssl-src is not in
# Cargo.lock).
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

# ⛔ vergen (build.rs:3-6) needs a git repository around the source. Make one
# of the unpacked tree, with the tag's name. WHAT THAT CHANGES: vergen writes
# the commit SHA and date of THIS commit into the binary, and src/main.rs:25-28
# prints them only as `info!` log lines under RUST_LOG; `--version` is clap's,
# from the package version (src/args.rs:14), so it is unaffected. The SHA in
# that log line is not upstream's.
git init -q .
git add -A
git -c user.name=zpkg -c user.email=zpkg@localhost commit -q -m "v{{version}}"
git -c user.name=zpkg -c user.email=zpkg@localhost tag "v{{version}}"

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
G="{{prefix}}/bin/git-trim"
test -x "$G"
OUT="$("$G" --version)"
if [ "$OUT" != "git-trim 0.4.3" ]; then echo "--version printed '$OUT'" >&2; exit 1; fi

# A real trim, read off the repositories: a feature branch is pushed, merged
# into main and pushed; git-trim must delete it locally AND on the remote, and
# --dry-run must delete neither.
export HOME="$(mktemp -d)"
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@localhost GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@localhost
T="$(mktemp -d)"
cd "$T"
git init -q --bare -b main remote.git
git clone -q remote.git work 2>/dev/null
cd work
echo a > a
git add a
git commit -q -m a
git push -q -u origin main
git remote set-head origin main
git checkout -q -b feat
echo b > b
git add b
git commit -q -m b
git push -q -u origin feat
git checkout -q main
git merge -q --no-ff feat -m "merge feat"
git push -q origin main

"$G" --no-confirm --dry-run
if [ -z "$(git branch --list feat)" ]; then echo "--dry-run deleted the local branch" >&2; exit 1; fi
if [ -z "$(git ls-remote --heads origin feat)" ]; then echo "--dry-run deleted the remote branch" >&2; exit 1; fi

"$G" --no-confirm
if [ -n "$(git branch --list feat)" ]; then echo "merged local branch feat was not deleted" >&2; exit 1; fi
if [ -n "$(git ls-remote --heads origin feat)" ]; then echo "merged remote branch feat was not deleted" >&2; exit 1; fi
if [ -z "$(git branch --list main)" ]; then echo "main was deleted" >&2; exit 1; fi

# What it links: libgit2 is compiled in (so NOT a libgit2.so), libssh2 and
# OpenSSL and zlib are the system ones.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$G")"; else LIBS="$(ldd "$G")"; fi
for l in libssh2 libssl libz; do
  case "$LIBS" in
    *"$l"*) ;;
    *) echo "git-trim does not link $l:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
done
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",    # :4 licence, :11-12 edition and rust-version 1.65, :14 default-run, :16-18 build-man, :28-40 dependencies, :31 git2 0.14.4
    "Cargo.lock",    # :419 libgit2-sys 0.13.4+1.4.2, :433 libssh2-sys 0.2.23, :447 libz-sys 1.1.8, :529 openssl-sys 0.9.78
    "build.rs",      # :3-6 vergen(Config::default()) .expect(...)
    "src/main.rs",   # :25-28 the vergen values as info! lines
    "src/args.rs",   # :14 clap `version`, :36-82 --no-update, --no-confirm, --dry-run, --delete (default merged:origin)
    "src/subprocess.rs", # :17, :32 Command::new("git")
    "libgit2-sys-0.13.4+1.4.2/build.rs", # :14-29 system libgit2 only 1.4.0..1.5.0, else vendored
    "libssh2-sys-0.2.23/build.rs",       # :22-39 LIBSSH2_SYS_USE_PKG_CONFIG and its fall-through
    "openssl-sys-0.9.78/build/main.rs",  # :298 >= 3.0 is ossl300
    "vergen-7.4.3/src/feature/git.rs",   # :247 Repository::discover(repo_path)?
    "LICENSE",       # MIT
  ]

  consulted = [
    # Read for facts only: the repository name, the binary, the need for a git
    # repository for vergen (it cloned; the script makes one), `--version`.
    # NOT taken: openssl ^1.1, libgit2 ~1.7, rust >=1.65 as a floor, an install
    # without --locked.
    "pkgxdev/pantry projects/crates.io/git-trim/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

⚠ VENDORING, STATED. libgit2 1.4.2 is compiled in from libgit2-sys's own copy
(no system library of the range 1.4 exists here, and the crate has no
no-vendor switch). Whenever git-trim moves to a libgit2-sys that accepts
1.9.x, LIBGIT2_NO_VENDOR=1 and a libgit2.org dependency belong in this file.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only, on a loaded
machine. Unverified: that `git init` in the build directory is permitted by
the builder (it needs git on the build path: it is a runtime dependency, hence
there), that vergen 7.4.3 accepts a repository with one commit and one
lightweight tag, and that libssh2-sys finds libssh2.pc. The first factory run
is this file's test.
EOT
}
