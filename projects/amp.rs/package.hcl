# amp.rs — Amp, a text editor for the terminal (jmacdonald/amp). A FRAGMENT
# until now: it said what the binary needs and took its source, versions, build
# and test from the upstream pantry merged underneath. That merge ended with
# zpkb v0.90.0 (go-zpkg/zpkb#514), so this is the WHOLE recipe, written from
# Amp's own files (go-zpkg/packages#431, #440 step 1), at 0.7.1.
#
# ⭐⭐ WHAT WRITING IT FOUND: the fragment named libgit2 and, on linux, OpenSSL;
# neither is what the binary uses.
#
#   - OpenSSL: Cargo.toml:32-35 takes git2 with default-features = false "to
#     sidestep its openssl dependency" (CHANGELOG.md:37), and Cargo.lock has no
#     openssl-sys. Dropped.
#   - libgit2: libgit2-sys 0.16.1+1.7.1 (Cargo.lock:693) takes a system libgit2
#     only in 1.7.1 up to 1.8.0 (its build.rs:10), and the libgit2.org recipe
#     here pins 1.9.7 alone, which is out of that range. LIBGIT2_NO_VENDOR would
#     therefore make every build a panic, so it is NOT set: libgit2-sys compiles
#     the libgit2 1.7.1 it ships. VENDORED, STATED, and libgit2.org is dropped
#     from the dependencies for that reason. Without the `https` and `ssh`
#     features (none is on) that copy needs no TLS library.
#   - zlib: libz-sys 1.1.12 (Cargo.lock:705), pkg-config first and its own build
#     on a miss; LIBZ_SYS_STATIC is not set. Kept as a dependency.
#   - Oniguruma: onig_sys 69.8.1 (Cargo.lock:955), through syntect. The lock
#     gives it no bindgen (so no libclang), and its build compiles the bundled
#     oniguruma unless RUSTONIG_SYSTEM_LIBONIG is set (build.rs:222). No
#     oniguruma recipe exists in this tree, so it is VENDORED, STATED.
#   - There is no feature to name: Amp's Cargo.toml has no [features], and the
#     one dependency feature it changes (git2) is the one above.

summary = "Amp: a complete text editor for your terminal"

# Cargo.toml:11 license-file = "LICENSE", the GNU General Public License,
# version 3 or (at your option) any later version (LICENSE, lines 3-7). The
# crates of Cargo.lock compiled in carry their own licences.
license = "GPL-3.0-or-later"

versions {
  github = "jmacdonald/amp/tags"
}

distributable {
  # GitHub's archive of the tag 0.7.1 (Amp's tags carry no `v`).
  url              = "https://github.com/jmacdonald/amp/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 415699 bytes. Recorded with `zpkb sourcepin` (v0.94.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "0.7.1" = "59a65c2c4592eed188433fe7c4bf2ba84206f217bdafc5a2c7f97623f5607c12"
  }
}

# Cargo.toml:3 the package `amp`; src/main.rs is its only binary.
provides = [
  "bin/amp",
]

dependencies = {
  # libz-sys 1.1.12 through libgit2-sys.
  "zlib.net" = "^1"
}

build {
  dependencies = {
    "gnu.org/tar"                = "*"
    "freedesktop.org/pkg-config" = "*"
    linux = {
      "gnu.org/gcc" = "*"
    }

    # Cargo.toml:13 edition 2021. Amp declares no rust-version; the compiler
    # this tree carries is named, not an invented floor.
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
# Amp has no features of its own, so none is named here and none is left to a
# default: --no-default-features changes nothing for it (Cargo.toml has no
# [features]) and is not passed.
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
F="{{prefix}}/bin/amp"
test -x "$F"

# Amp is a full-screen terminal editor with no --version and no batch mode
# (src/main.rs hands every argument to Application::new as a path), so running
# it needs a terminal and the test cannot. What it CAN check is what the binary
# links: libgit2 and an SSL library are NOT in it, because libgit2 is the copy
# compiled in and git2 is built without https.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$F")"; else LIBS="$(ldd "$F")"; fi
case "$LIBS" in
  *libgit2*) echo "amp links a system libgit2, which no libgit2 here satisfies:" >&2; echo "$LIBS" >&2; exit 1 ;;
  *libssl*) echo "amp links libssl, which Cargo.lock does not ask for:" >&2; echo "$LIBS" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",    # :3 name, :11 license-file, :13 edition, :32-35 git2 default-features = false
    "Cargo.lock",    # :693 libgit2-sys 0.16.1+1.7.1, :705 libz-sys 1.1.12, :943-962 onig and onig_sys (no bindgen); no openssl-sys
    "CHANGELOG.md",  # :36-37 git2 features disabled, openssl dropped
    "src/main.rs",   # :5-9 every argument goes to Application::new
    "libgit2-sys-0.16.1+1.7.1/build.rs",  # :10 the 1.7.1..1.8.0 range, :30-42 LIBGIT2_NO_VENDOR
    "onig_sys-69.8.1/build.rs",           # :222 RUSTONIG_SYSTEM_LIBONIG
    "LICENSE",
  ]

  consulted = [
    # Read for facts only: the tag URL (no `v`). NOT taken: the libgit2 and
    # openssl dependencies, which Cargo.toml and Cargo.lock contradict.
    "pkgxdev/pantry projects/amp.rs/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG IS A SINGLE HOST, STATED. The repository publishes no
checksum file and no signature for the tag; the digest records GitHub's
generated archive, fetched twice (the builder's fetcher, curl) with one answer.
The crates it compiles are pinned by Cargo.lock's checksums, which cargo
verifies under --locked.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only, on a loaded
machine. The test is a link check only, because Amp cannot be driven without a
terminal. Whether the bundled libgit2 1.7.1 builds without cmake was not
checked (libgit2-sys compiles it with the cc crate; its build.rs was read only
for the system probe). The first factory run is this file's test.
EOT
}
