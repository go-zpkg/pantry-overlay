# crates.io/mdcat — cat for markdown: show markdown documents in terminals
# (swsnr/mdcat). A FRAGMENT until now: it said what the binary needs and took
# its source, versions, build and test from the upstream pantry merged
# underneath. That merge ended with zpkb v0.90.0 (go-zpkg/zpkb#514), so this is
# the WHOLE recipe, written from mdcat's own files (go-zpkg/packages#431, #440
# step 1), at 2.7.1.
#
# ⭐⭐ WHAT WRITING IT FOUND: the TLS library is libcurl's, and libcurl may be
# compiled in without a word. Cargo.toml:20 takes the `curl` crate 0.4.47, whose
# default feature `ssl` (curl-0.4.47 Cargo.toml:114) pulls openssl-sys 0.9.104,
# and curl-sys 0.4.78+curl-8.11.0 (Cargo.lock:357) probes pkg-config for a
# system libcurl and, when that fails, COMPILES curl 8.11.0 (build.rs:30-60).
# There is no environment switch that makes the miss fatal in this version:
# the test reads the link off the binary.

summary = "mdcat: show markdown documents in terminals"

# Cargo.toml:56 [workspace.package] license = "MPL-2.0 AND Apache-2.0",
# inherited by both members; LICENSE is the MPL 2.0 text, and README.md:124-125
# says "some files are subject to the terms of the Apache 2.0 license". The
# crates of Cargo.lock compiled in carry their own licences, which this
# expression does not enumerate.
license = "MPL-2.0 AND Apache-2.0"

versions {
  # The repository tags `mdcat-2.7.1` (tag-prefix, Cargo.toml:77) and others.
  github = "swsnr/mdcat/tags"
  strip  = "/^mdcat-/"
}

distributable {
  # GitHub's archive of the tag mdcat-2.7.1. The tag is annotated and signed
  # (Cargo.toml:80 sign-tag = true): tag object bf021698, tagger Sebastian
  # Wiesner, 2024-12-14, an SSH signature (ssh-ed25519) that GitHub reports as
  # "valid". See provenance.note for what that does and does not prove.
  url              = "https://github.com/swsnr/mdcat/archive/refs/tags/mdcat-{{version.raw}}.tar.gz"
  strip-components = 1

  # 422537 bytes. Recorded with `zpkb sourcepin` (v0.92.0) and confirmed by a
  # second, independent fetch: curl on the same URL, shasum -a 256.
  sha256 = {
    "2.7.1" = "460024d9795eb578be09ec2284af243627721151aa001aae6ffb5589380b2ba1"
  }
}

# Cargo.toml:1-2: the package `mdcat`, one binary of that name (src/main.rs).
# REFUSED: `mdless`. src/args.rs:32 is a multicall command that takes its mode
# from argv[0], and README.md:74,86 says mdless is a link or copy of mdcat that
# the packager makes; `cargo install` installs one file, mdcat.
provides = [
  "bin/mdcat",
]

dependencies = {
  # libcurl through curl-sys 0.4.78 (Cargo.lock:357), with openssl-sys 0.9.104
  # (:1111) and libz-sys 1.1.20 (:880) behind it. No libnghttp2-sys in the
  # lockfile: the `http2` feature is off.
  "curl.se"     = "^8"
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

    # Cargo.toml:59 rust-version = "1.83" (workspace), read from the file. The
    # compiler this tree carries is named: the locked crates may ask for more.
    "rust-lang.org"       = "^1.100"
    "rust-lang.org/cargo" = "*"
  }

  script = [
    {
      run = <<EOT
set -eu
# openssl-sys refuses to guess without OPENSSL_DIR when no pkg-config answers.
# The MAJOR symlink v3, not a concrete version (see rust-lang.org/cargo). No
# `vendored` feature is on: openssl-src is not in Cargo.lock.
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
# The root is a package AND a workspace (Cargo.toml:48-49), so `--path .`
# installs mdcat, not pulldown-cmark-mdcat (a library).
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
M="{{prefix}}/bin/mdcat"
test -x "$M"
# src/args.rs:40: the Mdcat subcommand carries `version`.
OUT="$("$M" --version)"
case "$OUT" in
  *"2.7.1"*) ;;
  *) echo "--version printed '$OUT'" >&2; exit 1 ;;
esac

# It renders markdown: no colours (src/args.rs:92-94), so the words are plain.
printf '# Title here\n\nHello *world* and a [link](https://example.com).\n\n* one\n* two\n' > t.md
"$M" --no-colour t.md > out.txt
grep -q "Title here" out.txt
grep -q "Hello world and a" out.txt
grep -q "one" out.txt
# Markdown syntax is consumed, not echoed.
if grep -q '^# Title here' out.txt; then echo "the heading marker was echoed" >&2; exit 1; fi
if grep -q '\*world\*' out.txt; then echo "the emphasis markers were echoed" >&2; exit 1; fi
# Standard input is the default file (src/args.rs:90).
OUT="$(printf 'plain text\n' | "$M" --no-colour)"
case "$OUT" in
  *"plain text"*) ;;
  *) echo "stdin rendering printed '$OUT'" >&2; exit 1 ;;
esac

# What it links: libcurl is the system one, or curl-sys compiled its own.
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$M")"; else LIBS="$(ldd "$M")"; fi
case "$LIBS" in
  *libcurl*) ;;
  *) echo "mdcat does not link libcurl: curl-sys compiled its own:" >&2; echo "$LIBS" >&2; exit 1 ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "Cargo.toml",    # :11 licence, :14 rust-version, :20 curl 0.4.47, :48-49 workspace, :56 licence, :59 rust-version 1.83, :77, :80 tag-prefix and sign-tag
    "Cargo.lock",    # :342 curl 0.4.47, :357 curl-sys 0.4.78+curl-8.11.0, :880 libz-sys 1.1.20, :1111 openssl-sys 0.9.104; no libnghttp2-sys, no openssl-src
    "src/args.rs",   # :32 multicall, :40-61 the Mdcat and Mdless commands, :90-94 files and --no-colour
    "LICENSE",       # Mozilla Public License 2.0
    "README.md",     # :74, :86 mdless as a link, :124-125 the Apache 2.0 files
    "curl-0.4.47/Cargo.toml",                     # :114 default = ["ssl"]
    "curl-sys-0.4.78+curl-8.11.0/build.rs",       # :30-60 the pkg-config probe and the compiled fallback, :267 http2
  ]

  consulted = [
    # Read for facts only: the tag URL (`mdcat-` prefix), the binary name,
    # `cargo install --locked --path .`. NOT taken: openssl ^1.1, rust >=1.56
    # (the file says 1.83), a test that is only `mdcat --version`.
    "pkgxdev/pantry projects/crates.io/mdcat/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG, STATED. The tag mdcat-2.7.1 is an annotated tag with an SSH
signature (ssh-ed25519) by the project's author, and GitHub's API reports it
"verified: true, reason: valid". That is GitHub's judgement against the SSH key
registered on the author's GitHub account: a surface of GitHub, not one the
project publishes. No page of the project that prints the signing key's
fingerprint was found (README.md, CHANGELOG.md, scripts/, deny.toml and
supply-chain/ were searched), so the signature was NOT verified here against a
project-anchored key. The sha256 pins GitHub's generated archive of the tag,
fetched twice (the builder's fetcher, curl) with one answer, and is the durable
pin; nothing verifies a signature at build time. The crates it compiles are
pinned by Cargo.lock's checksums, which cargo verifies under --locked.

⛔ NOT BUILT, NOT TESTED. Written from the source's files only, on a loaded
machine. The rendered words the test expects are from the markdown it feeds,
not from a run; whether the heading keeps a visible marker was not traced
(the test only refuses the literal `# `). The first factory run is this
file's test.
EOT
}
