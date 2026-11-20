# llvm.org — clang, lld, lldb, clang-tools-extra and compiler-rt, with the LLVM
# libraries and llvm-config. A FRAGMENT until now: it said how to build and
# took its source, its versions, its `provides` and its `receipt` from the
# upstream pantry merged underneath. That merge ended with zpkb v0.90.0
# (go-zpkg/zpkb#514), so the fragment alone resolved to "states no versions, no
# distributable". This is the WHOLE recipe, written against LLVM's own CMake
# files (go-zpkg/packages#431, go-zpkg/recipes#143, go-zpkg/packages#440), at
# 22.1.8.
#
# ⭐⭐ DOES WRITING THIS SWITCH THE FACTORY FROM MIRRORING TO BUILDING? NO.
# Mirroring is a MODE OF A RUN, not a property of a recipe. `zpkb factory
# --mirror-from <dist>` (cmd/zpkb/factory.go:175,372-376,439-449) never loads a
# recipe: the versions come from the upstream dist and the bytes are copied.
# go-zpkg/packages' build.yml and darwin.yml pass it only when MIRROR_FROM is
# set. Without the flag the factory BUILDS, and llvm.org was already built that
# way: seed/order.txt puts it at line 102 and the s390x seed ("cargo: resolve
# deps: GET dist.pkgx.dev/llvm.org/linux/s390x/versions.txt: Not Found") has no
# upstream artifact to mirror. What changes is what a BUILD run finds:
#
#   - before: this fragment + the pantry, built every version the pantry lists;
#     since v0.90.0 it resolves to nothing, i.e. a build run SKIPS or fails;
#   - now: ONE pinned, signed version (22.1.8), built from this file alone.
#
# Merging this file changes no installed byte: nothing publishes until an
# operator dispatches a build run, and the artifacts already in the registry
# (mirrored, every version up to 23.1.6 at the time of writing) are untouched.
# ⚠ What a build run WILL do differently, stated here so it is not discovered
# later: it can build only 22.1.8 (the sha256 table below), not the 23.x the
# resolver reports as newest today; and a built 22.1.8 and the mirrored 22.1.8
# are different artifacts under the same version.
#
# ⛔ NOT BUILT HERE. No session on this machine can run an LLVM build (hours,
# tens of GB, per platform). What WAS run: `cmake` (4.4.4) CONFIGURED this
# source with the projects and flags below on macOS arm64 and wrote an
# LLVMConfig.cmake — see provenance.note for what that proves and what it does
# not. The test below reads outcomes off the installed artifact and has never
# run.

summary = "The LLVM compiler infrastructure: clang, lld, lldb, clangd, compiler-rt and the LLVM libraries"

# LICENSE.TXT:2: "The LLVM Project is under the Apache License v2.0 with LLVM
# Exceptions". ⚠ LICENSE.TXT:224-257 adds "third party software which is under
# different license terms" (each in its own directory with its own LICENSE) and
# the "Legacy LLVM License" (the University of Illinois/NCSA licence) for older
# files; this recipe has not opened each such directory, and the expression is
# the one the project states for itself, not an enumeration of the artifact.
license = "Apache-2.0 WITH LLVM-exception"

versions {
  # llvm-project tags more than versions: `llvmorg-23.1.0-rc3`, and
  # `llvmorg-23-init`. A stable release has no hyphen after the number.
  github = "llvm/llvm-project/tags"
  strip  = "/^llvmorg-/"
  ignore = [
    "/-/",
  ]
}

# ⛔ THE LIBRARIES THE ARTIFACT LINKS, and the reason each is named in ARGS
# below (config-ix.cmake:165-231 turns each of them on if it FINDS one, and
# silently off if not — FORCE_ON makes a miss fatal). Unchanged from the
# fragment: this is what a consumer installs next to llvm.org.
dependencies = {
  "facebook.com/zstd" = "*"
  "gnome.org/libxml2" = "^2"

  # On s390x the caret is not an ABI bound. ld.lld NEEDs libxml2.so.16, which
  # gnome.org/libxml2 2.15 provides and 2.13 does not (2.13's soname is
  # libxml2.so.2), so "^2" can install a library whose soname the LINKER cannot
  # use ("ld.lld: error while loading shared libraries: libxml2.so.16", seen by
  # `zpkb factory --test-only`, whose lean environment is the first one llvm's
  # linker ever ran in). Scoped, because an artifact links the soname that was
  # in the store when it was built: tightening it for an architecture whose
  # artifact links .so.2 would break it. The soname moved INSIDE a major, which
  # is go-zpkg/packages#233's class.
  "linux/s390x" = {
    "gnome.org/libxml2" = "^2.15"
  }
  "zlib.net" = 1
}

distributable {
  # The release tarball of the llvm-project: one archive holding llvm/, clang/,
  # lld/, lldb/, clang-tools-extra/, compiler-rt/ and runtimes/ (the same URL
  # the compiler-rt.llvm.org/wasi and libcxx.llvm.org/wasi recipes use).
  url              = "https://github.com/llvm/llvm-project/releases/download/llvmorg-{{ version }}/llvm-project-{{ version }}.src.tar.xz"
  strip-components = 1

  # 167061596 bytes. SIGNED, AND VERIFIED: llvm-project-22.1.8.src.tar.xz.sig is
  # a detached OpenPGP signature (created 2026-06-16) by ed25519 key
  # FFB3368980F3E6BB5737145A316C56D064CACBA5, Douglas Yung <douglas.yung@sony.com>,
  # one of the release managers' keys in https://releases.llvm.org/release-keys.asc
  # — the file the release notes name ("Download the keys from the LLVM
  # website"). `gpg --verify` against a fresh keyring holding only that file:
  # "Good signature", VALIDSIG on that fingerprint. See provenance.note for the
  # anchor and its limits.
  #
  # The digest was confirmed by a second path that is not a second download of
  # the same bytes: the GitHub release API's own `digest` for the asset says
  # sha256:922f1817a0df7b1489272d18134ee0087a8b068828f87ac63b9861b1a9965888
  # and `size` 167061596, byte for byte what `shasum -a 256` computed here.
  sha256 = {
    "22.1.8" = "922f1817a0df7b1489272d18134ee0087a8b068828f87ac63b9861b1a9965888"
  }
}

# What the artifact installs in bin/, each asserted by the test below. The first
# sixteen are the fragment's/pantry's list; llvm-config (Rust's bootstrap reads
# it, go-zpkg/recipes#143) and wasm-ld (the wasi lane: compiler-rt.llvm.org/wasi,
# wasi-libc and libcxx.llvm.org/wasi link with it) are named because consumers
# in this tree depend on them.
provides = [
  "bin/lld",
  "bin/lldb",
  "bin/clang",
  "bin/clang++",
  "bin/clangd",
  "bin/cc",
  "bin/c++",
  "bin/cpp",
  "bin/nm",
  "bin/objcopy",
  "bin/ranlib",
  "bin/readelf",
  "bin/strings",
  "bin/strip",
  "bin/llvm-profdata",
  "bin/llvm-cov",
  "bin/llvm-config",
  "bin/wasm-ld",
]

build {
  dependencies = {
    # llvm/CMakeLists.txt:2 (and runtimes/ and compiler-rt/) require CMake 3.20.
    # ⛔ THE FRAGMENT SAID ">=3<3.29", the pantry's "doesn't seem to install a bunch
    # of the libs with cmake 3.29" — a remark about LLVM ~16, and the only cmake
    # this tree builds is 4.5.0, so the range could not resolve. Measured the
    # other way: cmake 4.4.4 configured THIS source with the projects below.
    # That the install still lacks nothing is asserted by the test.
    "cmake.org"       = ">=3.20"
    "ninja-build.org" = 1

    # find_package(Python3 … Interpreter) is the only use at build time (the
    # configure log found 3.15.2 "minimum required is 3.0"). The fragment's
    # "<3.12" was the distutils era (LLVM <= 17); python.org here is 3.15.2.
    "python.org" = ">=3"
  }

  env = {
    # Every LLVM_ENABLE_*/LLDB_ENABLE_* below is an AUTO-DETECTION in the
    # source, named or refused (CMakeLists.txt line numbers are llvm/'s, at
    # 22.1.8; the configure of this exact set is in provenance.note):
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX=\"{{ prefix }}\"",
      "-DCMAKE_BUILD_TYPE=Release",

      # PROJECTS. clang and lld are the compiler and linker of the sovereign
      # build environment (zpkb buildscript/wrapper.go:846 `--rtlib=compiler-rt
      # -fuse-ld=lld`). lldb and clang-tools-extra (clangd) are kept because the
      # artifact the registry holds has always carried them and `provides` says
      # so; dropping them would be a change of CONTENT, not of configuration.
      "-DLLVM_ENABLE_PROJECTS='lld;lldb;clang;clang-tools-extra'",

      # RUNTIMES: compiler-rt only (builtins and crt for --rtlib=compiler-rt,
      # the sanitizers and profile runtime the test and llvm-cov/llvm-profdata
      # need). NOT libcxx, libcxxabi or libunwind: libcxx.llvm.org is a separate
      # artifact, and wrapper.go:883-896 picks it up from the store. CMakeLists:
      # 658-661 would add compiler-rt by itself when AArch64 is built; it is
      # named so the choice is written down.
      "-DLLVM_ENABLE_RUNTIMES='compiler-rt'",

      # TARGETS: left at "all" (CMakeLists.txt:552), on purpose: wasm-ld and the
      # WebAssembly backend are what the wasi lane builds with, and rustc's
      # bootstrap wants every backend rustc can target.
      "-DLLVM_INCLUDE_DOCS=OFF",
      "-DLLVM_INCLUDE_TESTS=OFF",

      # Not installed, only built (849-861, 1378, 1506); the fragment built them.
      "-DLLVM_INCLUDE_EXAMPLES=OFF",
      "-DLLVM_INCLUDE_BENCHMARKS=OFF",
      "-DLLVM_ENABLE_RTTI=ON",
      "-DLLVM_BUILD_LLVM_DYLIB=ON",

      # ⛔ zlib, zstd, libxml2 (594, 611, 613): dependencies above, so a miss is
      # a failed build, not a quietly smaller compiler (config-ix.cmake:179-183,
      # 190-193, 227-231). The test reads all three off LLVMConfig.cmake.
      "-DLLVM_ENABLE_ZLIB=FORCE_ON",
      "-DLLVM_ENABLE_ZSTD=FORCE_ON",
      "-DLLVM_ENABLE_LIBXML2=FORCE_ON",
      "-DLLDB_ENABLE_LIBXML2=ON",

      # ⛔ REFUSED: not in this tree, so each would be found or not by chance.
      #   libpfm (598), Z3 for the static analyzer (625-646: its default is
      #   "whatever is FOUND"), OCaml/Go bindings (867-868), curl and httplib
      #   (617-621: already OFF), libffi for the interpreter (587: already OFF).
      "-DLLVM_ENABLE_LIBPFM=OFF",
      "-DLLVM_ENABLE_Z3_SOLVER=OFF",
      "-DLLVM_ENABLE_BINDINGS=OFF",
      "-DLLVM_ENABLE_CURL=OFF",
      "-DLLVM_ENABLE_HTTPLIB=OFF",
      "-DLLVM_ENABLE_FFI=OFF",

      # ⛔ REFUSED: lldb's scripting. LLDBConfig.cmake:59-64 make Python and Lua
      # need SWIG 4, which nothing here provides; the build dependency on
      # python.org is for the build, not for an embedded interpreter. FreeBSD's
      # vmcore reader (:66) is for FreeBSD.
      "-DLLDB_ENABLE_PYTHON=OFF",
      "-DLLDB_ENABLE_SWIG=OFF",
      "-DLLDB_ENABLE_LUA=OFF",
      "-DLLDB_ENABLE_FBSDVMCORE=OFF",
    ]
    darwin = {
      ARGS = [
        # The Command Line Tools SDK, as the fragment had it. It is also why the
        # next three are named ON rather than refused: the SDK carries libedit,
        # curses and liblzma (found by the configure on macOS: "Enable editline
        # support in LLDB: TRUE", curses, LZMA), they are system libraries every
        # Mac has, and ON makes a missing one fatal (LLDBConfig.cmake:34-36).
        "-DDEFAULT_SYSROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk",
        "-DLLDB_ENABLE_LIBEDIT=ON",
        "-DLLDB_ENABLE_CURSES=ON",
        "-DLLDB_ENABLE_LZMA=ON",
        "-DLLVM_BUILD_LLVM_C_DYLIB=ON",

        # LLVM_ENABLE_LIBCXX (679) links the TOOLS against the libc++ the SDK
        # has. ⛔ DROPPED: the fragment's LIBCXX_HAS_ATOMIC_LIB=ON, a libcxx
        # variable this build never reads (no libcxx runtime is built; cmake
        # reported "Manually-specified variables were not used").
        "-DLLVM_ENABLE_LIBCXX=ON",
      ]
    }
    linux = {
      ARGS = [
        "-DCLANG_DEFAULT_LINKER=lld",
        "-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON",

        # ⛔ REFUSED on linux: libedit (CMakeLists.txt:596; lldb's own at
        # LLDBConfig.cmake:60), curses (:61) and lzma (:62) are not in the base
        # toolchain nor in this recipe's closure, so Auto would link whatever the
        # builder image happens to hold. lldb loses line editing, curses UI and
        # compressed-section reading on linux.
        "-DLLVM_ENABLE_LIBEDIT=OFF",
        "-DLLDB_ENABLE_LIBEDIT=OFF",
        "-DLLDB_ENABLE_CURSES=OFF",
        "-DLLDB_ENABLE_LZMA=OFF",
      ]
    }
    "linux/aarch64" = {
      ARGS = [
        "-DCMAKE_C_COMPILER_TARGET=\"aarch64-unknown-linux-gnu\"",
      ]
    }
    "linux/x86-64" = {
      ARGS = [
        "-DCLANG_DEFAULT_CXX_STDLIB=libstdc++",
        "-DCLANG_DEFAULT_RTLIB=libgcc",
        "-DCOMPILER_RT_INCLUDE_TESTS=OFF",
        "-DCOMPILER_RT_USE_LIBCXX=OFF",
        "-DCMAKE_C_COMPILER_TARGET=\"x86_64-unknown-linux-gnu\"",
      ]
    }
  }

  # ⛔ THE FRAGMENT PICKED compiler-rt BY VERSION (`semverator satisfies '>=14'`)
  # on darwin, and brought in rust-lang.org and cargo to run it — whose own build
  # needs llvm.org, a cycle with no entry point. One version is pinned, 22.1.8,
  # which is >= 14 everywhere, so the question has one answer and the tool is
  # gone from the build and the test.
  script = [
    "cmake ../llvm -G Ninja $ARGS",
    "ninja",
    "ninja install",
    {
      run = [
        "ln -sf clang cc",
        "ln -sf clang++ c++",
        "ln -sf clang-cpp cpp",
        <<EOT
for x in nm objcopy ranlib readelf strings strip; do
  ln -sf llvm-$x $x
done
EOT
        ,
      ]
      working-directory = "$${{prefix}}/bin"
    },
    {
      if                = "linux"
      run               = <<EOT
TARGET="$(find . -maxdepth 1 -type d -name \*-unknown-linux-gnu)"
if test -n "$TARGET"; then
  mv "$TARGET"/* .
  rmdir "$TARGET"
  ln -s . "$TARGET"
fi
EOT
      working-directory = "$${{prefix}}/lib"
    },
  ]
  working-directory = "build"
}

test {
  fixture = <<EOT
#include <stdio.h>
int main() {
  printf("Hello World!\n");
  return 0;
}
EOT
  script = [
    {
      run = <<EOT
set -eu
P="{{prefix}}"

# 1. Every binary `provides` names is there, and the two compilers say 22.1.8.
for b in lld lldb clang clang++ clangd cc c++ cpp nm objcopy ranlib readelf strings strip llvm-profdata llvm-cov llvm-config wasm-ld ld.lld; do
  if [ ! -x "$P/bin/$b" ]; then echo "missing bin/$b" >&2; exit 1; fi
done
case "$("$P/bin/clang" --version)" in
  *"clang version 22.1.8"*) ;;
  *) echo "clang is not 22.1.8" >&2; exit 1 ;;
esac
for t in ld.lld wasm-ld lldb clangd; do
  case "$("$P/bin/$t" --version 2>&1)" in
    *22.1.8*) ;;
    *) echo "$t does not report 22.1.8" >&2; exit 1 ;;
  esac
done

# 2. llvm-config is what Rust's bootstrap reads (it wants >= 21): the version,
# the build mode, and that every backend the wasi lane and rustc need is built.
C="$P/bin/llvm-config"
[ "$("$C" --version)" = "22.1.8" ] || { echo "llvm-config version: $("$C" --version)" >&2; exit 1; }
[ "$("$C" --build-mode)" = "Release" ] || { echo "not a Release build" >&2; exit 1; }
[ "$("$C" --assertion-mode)" = "OFF" ] || { echo "assertions are on" >&2; exit 1; }
[ "$("$C" --has-rtti)" = "YES" ] || { echo "no RTTI" >&2; exit 1; }
T="$("$C" --targets-built)"
for t in X86 AArch64 SystemZ WebAssembly; do
  case " $T " in
    *" $t "*) ;;
    *) echo "target $t is not built: $T" >&2; exit 1 ;;
  esac
done

# 3. The auto-detections, read off the installed LLVMConfig.cmake: the three
# named FORCE_ON are on, the refused ones are off.
M="$P/lib/cmake/llvm/LLVMConfig.cmake"
test -f "$M"
for s in 'set(LLVM_ENABLE_ZLIB 1)' 'set(LLVM_ENABLE_ZSTD TRUE)' 'set(LLVM_ENABLE_LIBXML2 1)' 'set(LLVM_ENABLE_FFI OFF)' 'set(LLVM_ENABLE_CURL OFF)'; do
  if ! grep -qF "$s" "$M"; then echo "LLVMConfig.cmake lacks: $s" >&2; exit 1; fi
done
if grep -qF 'set(LLVM_ENABLE_Z3_SOLVER TRUE)' "$M"; then echo "Z3 was linked" >&2; exit 1; fi
if [ "$(uname -s)" = Linux ] && grep -qF 'set(LLVM_ENABLE_LIBEDIT TRUE)' "$M"; then echo "libedit was linked on linux" >&2; exit 1; fi

# 4. The library, compiler-rt, and the links.
if [ "$(uname -s)" = Darwin ]; then
  test -n "$(find "$P/lib" -maxdepth 1 -name 'libLLVM*.dylib')"
  LIBS="$(otool -L "$P/bin/clang") $(otool -L "$P/bin/ld.lld")"
else
  test -n "$(find "$P/lib" -maxdepth 1 -name 'libLLVM*.so*')"
  LIBS="$(ldd "$P/bin/clang") $(ldd "$P/bin/ld.lld")"
fi
test -n "$(find "$P/lib/clang" -name 'libclang_rt.builtins*' -o -name 'libclang_rt.osx.a')"
for l in libz libzstd libxml2; do
  case "$LIBS" in
    *"$l"*) ;;
    *) echo "clang/ld.lld do not link $l:" >&2; echo "$LIBS" >&2; exit 1 ;;
  esac
done
EOT
    },
    "mv $FIXTURE $FIXTURE.c",
    "clang $ARGS $FIXTURE.c",
    "./a.out",
  ]

  # ⛔ `$PKGX_DIR` HERE EXPANDED TO NOTHING. The store variable is `ZPKG_DIR`
  # since the rename and nothing in zpkb or artifact sets the old spelling
  # (build/build.go:749, cmd/zpkb/builder.go:626, artifact/pkgx.go:381), so what
  # reached the linker was the empty `-Wl,-rpath,`. What that then did to the
  # test binary is NOT asserted here — it was not measured; what is measured is
  # that the flag named a variable nobody defines.
  env {
    # The sanitizers are the compiler-rt runtimes built above, on both
    # platforms (the fragment's version tests were all true for 22.1.8).
    ARGS = [
      "-fsanitize=address,undefined",
      "-Wl,-rpath,$ZPKG_DIR",
    ]
  }
}

provenance {
  read = [
    "LICENSE.TXT",                         # :2 the licence, :224-257 third-party and legacy licences
    "llvm/CMakeLists.txt",                 # :2 CMake 3.20; :141-146, :658-661 runtimes; :552 targets; :587-646 FFI, LIBXML2, LIBEDIT, LIBPFM, ZLIB, ZSTD, CURL, HTTPLIB, Z3; :849-868 examples, benchmarks, bindings
    "llvm/cmake/config-ix.cmake",          # :165-231 ZLIB, ZSTD, LIBXML2 and what FORCE_ON does; :280 libedit; :470-477 FFI
    "lldb/cmake/modules/LLDBConfig.cmake", # :21-52 add_optional_dependency (ON = REQUIRED), :59-66 the lldb switches
    "clang/CMakeLists.txt",                # :223 DEFAULT_SYSROOT, :245 CLANG_DEFAULT_LINKER
    "compiler-rt/cmake/base-config-ix.cmake", # :171, :213 COMPILER_RT_DEFAULT_TARGET_ONLY
  ]

  consulted = [
    # Read for facts only: the URL, the version source, the `provides` list, the
    # flag set and the compiler-rt/symlink/lib-move steps. NOT taken: the cmake
    # `<3.29` and python `<3.12` ranges (unresolvable here and written for LLVM
    # 16), `receipt` (go-zpkg/zpkb never read it), the version-keyed runtimes and
    # the semverator build dependency.
    "pkgxdev/pantry projects/llvm.org/package.yml",
  ]

  note = <<EOT
⚠ THE SOURCE RUNG, STATED. The tarball is signed and the signature VERIFIED here
(gpg, fresh keyring from release-keys.asc only: Good signature, VALIDSIG
FFB3368980F3E6BB5737145A316C56D064CACBA5, Douglas Yung). The sha256 pins that
tarball and is the durable pin: nothing verifies the signature at build time.
`zpkb sourcepin` refused to start in this session's sandbox (its command line
named a github.com URL and the session's guard rejected it), so the digest was
computed with shasum and the signature checked with gpg by hand; the numbers are
the same ones sourcepin would record.

⚠ THE KEY ANCHOR, STATED. The key file is https://releases.llvm.org/
release-keys.asc, project-controlled, and the release notes name it. Its six
keys' fingerprints are that file's own (gpg --show-keys); no page published by
the project that PRINTS the signer's fingerprint was found, so the chain is one
host deep for the key. Third parties print the same fingerprint (Arch Linux
llvm22's validpgpkeys, Gentoo's openpgp-keys-llvm) — corroboration, not an
anchor.

⚠ WHAT THE CONFIGURE PROVED, AND DID NOT. cmake 4.4.4 on macOS arm64 configured
this source with the full ARGS set above for darwin (Unix Makefiles instead of
Ninja, which was not installed; CMAKE_PREFIX_PATH=/opt/homebrew for zstd), exit
0, every switch accepted, and LLVMConfig.cmake recorded ZLIB 1, ZSTD TRUE,
LIBXML2 1, FFI OFF, CURL OFF; the log says lldb: libedit, curses, LZMA and
libxml2 TRUE, Python, Lua, SWIG, FBSDVMCore FALSE. A first configure WITHOUT the
named switches had found the same on that host, which is the point: the SDK
supplied zlib, libxml2 2.9.13, libedit, curses and liblzma and homebrew supplied
zstd, so the detections were SEEN, and are not what this recipe's closure
provides. NOT run: the linux arms (zstd and libxml2 from our artifacts, the
refused libedit/curses/lzma), and compiler-rt, which configures inside the
build. Nothing was compiled.

⛔ NOT BUILT BY THE FACTORY. No session here can run it. The first factory run
is the test of the build script, the test script, the s390x arm (which sets no
COMPILER_RT target triple and has never been shown to build), and the claim that
cmake 4.x installs every library.
EOT
}
