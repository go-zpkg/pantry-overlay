# rust-lang.org — the Rust compiler (rustc), rustdoc and the standard library
# for the host, built against OUR llvm.org. A new recipe: it had none, and the
# upstream pantry's cannot be merged underneath any more (zpkb v0.90.0,
# go-zpkg/packages#431), written from Rust 1.100.0's own files
# (go-zpkg/recipes#143, go-zpkg/packages#440 step 1; llvm.org landed first, as
# go-zpkg/recipes#201).
#
# ⭐⭐ HOW THIS RELATES TO ITS NEIGHBOURS.
#
#   - rust-lang.org/cargo is a SEPARATE recipe and is not built here
#     (build.extended = false, install.rs:176 and :222: `Cargo` installs only
#     when `extended` is on). cargo BUILDS WITH this (its build dependency is
#     `rust-lang.org ^1.98`) and RUNS the `rustc` on its PATH, so neither can
#     depend on the other at run time: it is a COMPANION, below.
#   - rust-lang.org/rustup is the version manager. It manages toolchains it
#     downloads and has nothing to do with this build; it does not use this
#     artifact and this does not use it.
#   - llvm.org is the LLVM rustc links, and the C/C++ toolchain it builds with.
#
# ⭐⭐ ONE DECISION CARRIES THE RECIPE: LLVM IS EXTERNAL.
# Rust 1.100.0 BUNDLES LLVM 23.1 (src/llvm-project) and by default does not even
# build it: `llvm.download-ci-llvm` defaults to TRUE (bootstrap.example.toml:75),
# i.e. x.py would fetch a prebuilt LLVM from ci-artifacts.rust-lang.org. That is
# an auto-detected, network-fetching default, so it is NAMED false. Then
# `target.<triple>.llvm-config` (bootstrap.example.toml:1104-1107, "if this is
# specified we don't compile LLVM at all for this target") points at llvm.org,
# and src/bootstrap/src/core/build_steps/llvm.rs:152-172 takes that branch
# before any download or build, after check_llvm_version (:799-812) has insisted
# on LLVM >= 21. This is the whole reason llvm.org had to be a recipe first.
#
# ⛔ NOT BUILT HERE. No session on this machine can run this build, and what
# would run it first is a downloaded bootstrap compiler this session declined to
# execute. What WAS checked is stated in provenance.note, and so is what was
# not. The first factory run is the test of this file.

summary = "The Rust compiler, rustdoc and the standard library"

# COPYRIGHT: "Rust is primarily distributed under the terms of both the MIT
# license and the Apache License (Version 2.0)", with the bundled third-party
# components under their own licences (LICENSES/, COPYRIGHT). ⚠ the expression
# is the project's own statement for itself, not an enumeration of this artifact:
# the vendored crates (vendor/) and the compiler-rt sources compiled for
# compiler_builtins carry others.
license = "MIT OR Apache-2.0"

versions {
  # Releases are named "Rust 1.100.0" (the upstream pantry strips the same
  # prefix); the repository tags more than versions.
  github = "rust-lang/rust"
  strip  = "/^Rust /"
}

# rustc links LLVM STATICALLY here (`llvm.link-shared` false, below), so no
# libLLVM at run time; what its static LLVM libraries need does come with it:
# zlib and zstd (llvm.org's FORCE_ON dependencies) and libxml2 (its other one),
# with the s390x soname scope llvm.org carries for the same reason.
dependencies = {
  "facebook.com/zstd" = "*"
  "gnome.org/libxml2" = "^2"
  "linux/s390x" = {
    "gnome.org/libxml2" = "^2.15"
  }
  "zlib.net" = 1

  # rustc_llvm links the C++ runtime LLVM was built against. ⚠ On linux that is
  # libstdc++ UNLESS the builder's wrapper compiled both halves with libc++,
  # which was not measured: the test below reads which one the driver NEEDS and
  # fails on libc++, rather than shipping an undeclared dependency.
  linux = {
    "gnu.org/gcc/libstdcxx" = "*"
  }
}

# ⚠ SUGGESTED, NOT DEPENDED ON: rustc runs the linker `cc` on its PATH, which on
# linux is llvm.org's (clang + lld), and cargo is the other half of a toolchain.
# What the upstream pantry's recipe said, kept.
companions = {
  "rust-lang.org/cargo" = "*"
  linux = {
    "llvm.org" = "*"
  }
}

distributable {
  # The project's own source tarball (it carries vendor/ and .cargo/config.toml,
  # which replaces crates.io with vendor/ — read, below — so a build fetches no
  # crate), on static.rust-lang.org, signed by the Rust release key.
  url              = "https://static.rust-lang.org/dist/rustc-{{ version }}-src.tar.xz"
  strip-components = 1

  # 263313328 bytes. SIGNED, AND VERIFIED: rustc-1.100.0-src.tar.xz.asc is a
  # detached signature (made 2026-11-12) by RSA key
  # 108F66205EAEB0AAA8DD5E1C85AB96E6FA1BE5FE, Rust Language (Tag and Release
  # Signing Key) <rust-key@rust-lang.org> — the key the cargo recipe (#198)
  # verified; `gpg --verify` against a fresh keyring holding only
  # https://static.rust-lang.org/rust-key.gpg.ascii: "Good signature", VALIDSIG
  # on that fingerprint. See provenance.note for the anchor and its limits.
  #
  # Confirmed by a second path that is not a second download of the same
  # file: the project's own rustc-1.100.0-src.tar.xz.sha256 says
  # 90dab90b8084eb57c35ae2b1d0b70c8e5138ace6023b22c60a5a400f586f63b2, byte
  # for byte what shasum computed.
  sha256 = {
    "1.100.0" = "90dab90b8084eb57c35ae2b1d0b70c8e5138ace6023b22c60a5a400f586f63b2"
  }
}

# What the artifact puts in bin/ (dist.rs:556-567 copies the sysroot's rustc and,
# with `tools` unset, rustdoc; :765-784 add the three debugger wrappers). Not
# here: cargo, clippy, rustfmt, rust-analyzer — see build.extended below.
provides = [
  "bin/rustc",
  "bin/rustdoc",
  "bin/rust-gdb",
  "bin/rust-gdbgui",
  "bin/rust-lldb",
]

build {
  dependencies = {
    # llvm-config and the C/C++ compiler. llvm.rs:807 insists on >= 21, and 22.1.8
    # (llvm.org, go-zpkg/recipes#201) and the 23.x the registry also holds both
    # satisfy it; 1.100.0 itself bundles 23.1 (src/llvm-project/cmake/Modules/
    # LLVMVersion.cmake:4-7).
    "llvm.org" = ">=21"

    # bootstrap.py is python (sanity.rs:171-175 looks for python3) and shells
    # out to `curl` to fetch the stage0 (bootstrap.py:100-176).
    "curl.se"    = "*"
    "python.org" = ">=3"

    # bootstrap.py unpacks the stage0's .tar.xz.
    "tukaani.org/xz" = "*"

    # ⛔ DELIBERATELY ABSENT: cmake and ninja (sanity.rs:140-153: cmake is needed
    # only to build LLVM, which is external, or sanitizers, refused below), git
    # (:105: only inside a git checkout; this is a tarball), openssl (it is
    # cargo's, which is not built here), and the old pantry's semverator (it
    # picked a build step by version; one version is pinned).
    linux = {
      "gnu.org/gcc" = "*"
    }
  }

  script = [
    {
      if  = "linux"
      run = <<EOT
set -eu
# Inherited from the cargo recipe, which measured it: this tree's gcc keeps
# libgcc.a outside rustc's link search path, so the link fails without it.
# bootstrap carries RUSTFLAGS from the environment into the cargo it drives
# (src/bootstrap/src/core/builder/cargo.rs:90-91, folded in and re-exported at
# :564-577), so the same variable the cargo recipe uses reaches every stage.
L=""
for c in "$${ZPKG_DIR:-$HOME/.zpkg}"/gnu.org/gcc/*/lib/gcc/*/*/libgcc.a; do
  if [ -e "$c" ]; then L="$(dirname "$c")"; fi
done
if [ -z "$L" ]; then
  echo "no libgcc.a under $${ZPKG_DIR:-$HOME/.zpkg}/gnu.org/gcc — is gnu.org/gcc a build dep?" >&2
  exit 1
fi
echo "export RUSTFLAGS=\"$${RUSTFLAGS:-} -L$L\"" > .zpkg-rustflags
echo "libgcc: $L"
EOT
    },
    {
      run = <<EOT
set -eu
# The external LLVM: the artifact llvm.org resolved to.
LC="{{deps.llvm.org.prefix}}/bin/llvm-config"
if [ ! -x "$LC" ]; then echo "no llvm-config at $LC" >&2; exit 1; fi
echo "llvm-config: $LC $("$LC" --version)"
# llvm.link-shared = false needs the STATIC libraries: llvm-config --link-static
# names them, and the first of them has to be there.
F="$("$LC" --link-static --libfiles core)"
if [ -z "$F" ]; then echo "llvm-config --link-static lists no core library" >&2; exit 1; fi
for f in $F; do
  if [ ! -f "$f" ]; then echo "static LLVM library missing: $f" >&2; exit 1; fi
done

BT="{{hw.target}}"
cat > bootstrap.toml <<TOML
# Written by the recipe. Every key below is read by src/bootstrap/src/core/
# config/toml/*.rs at 1.100.0 (an unknown key is an error there).
change-id = "ignore"

[build]
build = "$BT"

# ⛔ docs: default true, and install.rs:210 would build and install the docs.
docs = false
# ⛔ extended: default false; named so a later edit cannot turn on cargo,
# clippy, rustfmt and rust-analyzer without reading this recipe.
extended = false
# ⛔ vendor: the tarball carries vendor/ and .cargo/config.toml (source
# replacement to vendor/): no crate is fetched. locked-deps makes a drift in
# Cargo.lock an error.
vendor = true
locked-deps = true
# ⛔ refused: sanitizers and the profiler runtime need cmake and compiler-rt's
# CMake build (sanity.rs:153, compile.rs:494-516). Not installed here.
sanitizers = false
profiler = false

[install]
prefix = "{{prefix}}"

[llvm]
# ⛔ THE decision, see the header: no CI-built LLVM from the network.
download-ci-llvm = false
# Static: rustc then needs no libLLVM at run time. true would make rustc NEED
# llvm.org's libLLVM and its version (llvm.rs:168 passes it to the build).
link-shared = false

[rust]
# The stable channel the tarball declares (src/ci/channel): auto-detected, so
# named. ⛔ rpath stays true: it is the RELATIVE \$ORIGIN/../lib or
# @loader_path/../lib (cargo.rs:347-363) rustc needs to find librustc_driver.
channel = "auto-detect"
rpath = true
# ⛔ refused: LLD in the sysroot (rust.lld, default false) and LLVM's tools in it
# (rust.llvm-tools, default true) — llvm.org installs both, and a second copy
# inside the sysroot is one more thing to keep in step with it.
lld = false
llvm-tools = false
codegen-backends = ["llvm"]

[target.$BT]
llvm-config = "$LC"
TOML
cat bootstrap.toml
EOT
    },
    {
      run = <<EOT
set -eu
# The stage0 compiler is NOT fetched by this recipe: x.py downloads the one
# src/stage0 pins (compiler_version=1.99.0, compiler_date=2026-10-01) and checks
# each archive against the sha256 listed there before unpacking
# (bootstrap.py:66-81, :181-186).
if [ -f .zpkg-rustflags ]; then . ./.zpkg-rustflags; fi
python3 x.py install
EOT
    },
  ]
}

test {
  dependencies = {
    # `rustc -vV` names the LLVM it was built with; llvm-config is what to
    # compare it to. cargo is the other half of a toolchain, and builds a real
    # package with this rustc.
    "llvm.org"               = ">=21"
    "rust-lang.org/cargo"    = "*"
  }

  script = [
    {
      run = <<EOT
set -eu
R="{{prefix}}/bin/rustc"
# cargo runs the `rustc` on PATH: this one.
export PATH="{{prefix}}/bin:$PATH"
for b in rustc rustdoc rust-gdb rust-gdbgui rust-lldb; do
  if [ ! -e "{{prefix}}/bin/$b" ]; then echo "missing bin/$b" >&2; exit 1; fi
done
V="$("$R" -vV)"
echo "$V"
case "$V" in
  *"rustc 1.100.0"*) ;;
  *) echo "not rustc 1.100.0" >&2; exit 1 ;;
esac
case "$V" in
  *"release: 1.100.0"*) ;;
  *) echo "release is not 1.100.0 (a dev or beta channel?)" >&2; exit 1 ;;
esac

# The LLVM it reports is the external one's.
LV="$(llvm-config --version)"
case "$V" in
  *"LLVM version: $LV"*) ;;
  *) echo "rustc was not built with the llvm-config on PATH ($LV)" >&2; exit 1 ;;
esac

# Its sysroot is a real one, and every LLVM backend llvm.org built is behind it:
# --print target-cpus asks LLVM itself, for targets whose std is NOT installed.
S="$("$R" --print sysroot)"
if [ ! -d "$S/lib/rustlib" ]; then echo "no lib/rustlib under sysroot $S" >&2; exit 1; fi
for t in aarch64-unknown-linux-gnu x86_64-unknown-linux-gnu s390x-unknown-linux-gnu wasm32-wasip1; do
  C="$("$R" --target "$t" --print target-cpus 2>&1)"
  case "$C" in
    *"Available CPUs for this target"*) ;;
    *) echo "no LLVM backend for $t: $C" >&2; exit 1 ;;
  esac
done

# What the driver links: zlib and zstd at least, and not libc++ on linux.
D="$(find "{{prefix}}/lib" -maxdepth 1 -name 'librustc_driver*' | head -n 1)"
if [ -z "$D" ]; then echo "no librustc_driver in {{prefix}}/lib" >&2; exit 1; fi
if [ "$(uname -s)" = Darwin ]; then LIBS="$(otool -L "$D")"; else LIBS="$(ldd "$D")"; fi
echo "$LIBS"
for l in libz libzstd; do
  case "$LIBS" in
    *"$l"*) ;;
    *) echo "librustc_driver does not link $l" >&2; exit 1 ;;
  esac
done
if [ "$(uname -s)" = Linux ]; then
  case "$LIBS" in
    *"libc++.so"*) echo "librustc_driver links libc++: declare libcxx.llvm.org, not libstdcxx" >&2; exit 1 ;;
  esac
fi

# It compiles and runs an optimised program.
D="$(mktemp -d)"
cd "$D"
printf 'fn main() { println!("Hello, world!"); }\n' > hello.rs
"$R" -O hello.rs -o hello
OUT="$(./hello)"
if [ "$OUT" != "Hello, world!" ]; then echo "hello printed '$OUT'" >&2; exit 1; fi

# rustdoc and cargo (go-zpkg/recipes#198) work with it.
"{{prefix}}/bin/rustdoc" --version
cargo new --vcs none pkg
cd pkg
OUT="$(cargo run --offline --release)"
if [ "$OUT" != "Hello, world!" ]; then echo "cargo built '$OUT'" >&2; exit 1; fi
EOT
    },
  ]
}

provenance {
  read = [
    "bootstrap.example.toml",      # :56-75 download-ci-llvm and what "true" does, :104-148 llvm.*, :386-425 locked-deps, vendor, extended, tools, :453-468 sanitizers, profiler, optimized-compiler-builtins, :547-551 allocator (default "system": no jemalloc), :763-767 rpath, :826-847 codegen-backends, lld, llvm-tools, :1104-1111 target llvm-config
    "src/stage0",                  # compiler_version=1.99.0, compiler_date=2026-10-01: the pinned, checked bootstrap
    "src/ci/channel",              # "stable"
    "src/bootstrap/bootstrap.py",  # :66-81, :100-176, :181-186 the stage0 download and its sha256 check; :1346-1358 reads ./bootstrap.toml
    "src/bootstrap/src/core/sanity.rs",                    # :105 git, :140-154 cmake, :171-175 python, :303-313 cc/ar/cxx
    "src/bootstrap/src/core/build_steps/llvm.rs",          # :152-172 external llvm-config, :774-812 version check >= 21
    "src/bootstrap/src/core/build_steps/install.rs",       # :209-343 which components install by default
    "src/bootstrap/src/core/build_steps/dist.rs",          # :551-611 what the rustc component carries, :765-784 debugger wrappers
    "src/bootstrap/src/core/build_steps/compile.rs",       # :494-516, :596-628 compiler-rt sources for the profiler and compiler_builtins
    "src/bootstrap/src/core/builder/cargo.rs",             # :90-98, :321-368, :564-577 RUSTFLAGS and rpath
    "src/bootstrap/src/core/config/toml/",                 # every key written in bootstrap.toml
    ".cargo/config.toml",          # source replacement to vendor/
    "src/llvm-project/cmake/Modules/LLVMVersion.cmake",    # :4-7 the bundled LLVM, 23.1
  ]

  consulted = [
    # Read for facts only: the URL shape, the provides list, the companions, the
    # darwin headerpad flag. NOT taken: `./configure` and `make install`, the
    # clippy/rustfmt/rust-analyzer tools, the old build-time sed patches for
    # <1.70, the semverator build dependency, and the dependencies on cmake,
    # ninja, openssl and rsync.
    "pkgxdev/pantry projects/rust-lang.org/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG, STATED. The tarball is signed and the signature VERIFIED here
(gpg, fresh keyring from rust-key.gpg.ascii only: Good signature, VALIDSIG
108F66205EAEB0AAA8DD5E1C85AB96E6FA1BE5FE). The sha256 pins that tarball and is
the durable pin: nothing verifies the signature at build time. `zpkb sourcepin`
refused to start in this session's sandbox (its command line named a URL the
session's guard rejects), so the digest was computed with shasum and the
signature checked with gpg by hand, as in llvm.org's recipe.

⚠ THE KEY ANCHOR, STATED, as in the cargo recipe: the key file is
https://static.rust-lang.org/rust-key.gpg.ascii, project-controlled, its
fingerprint is that file's own and matches the signature's issuer. No page the
project publishes that PRINTS the fingerprint was found; the chain is one host
deep for the key.

⚠ WHAT WAS CHECKED. The tarball was unpacked and read at 1.100.0; every
bootstrap.toml key written above was found in src/bootstrap/src/core/config/
toml/ (an unknown key is an error); the vendor directory and .cargo/config.toml
exist. NOT RUN: x.py (it first downloads and executes the stage0, which this
session did not do), any build, the linux arm (libgcc step, ldd, the C++
runtime), and the test script.

⛔ OPEN, AND ON PURPOSE NOT GUESSED: (1) the C++ runtime. llvm.org's linux build
asks for libstdc++ (CLANG_DEFAULT_CXX_STDLIB) but the sovereign builder's
wrapper may pass -stdlib=libc++ to everything it compiles; rustc_llvm must link
the one llvm.org's static libraries were built with. The test fails on a libc++
driver instead of guessing. (2) `rustc -vV` does not tell an external LLVM from
the bundled one when the versions agree, so the test compares with llvm-config
and cannot distinguish a registry llvm.org of the same version as the bundled
23.1.x. (3) cc/cxx/ar are left to PATH (target.<triple>.cc, cxx, ar unset).

⛔ NOT BUILT BY THE FACTORY. No session here can run it.
EOT
}
