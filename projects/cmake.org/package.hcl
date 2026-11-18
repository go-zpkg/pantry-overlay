# cmake.org — and it comes FIRST of the three remaining build tools, which is
# the opposite of what their sizes suggest.
#
# ⛔ WRITTEN FROM CMAKE'S OWN FILES (go-zpkg/packages#431), at 4.5.0, read out
# of the published source tarball.
#
# ⭐⭐ WHY THIS ONE AND NOT ninja-build.org, WHICH LOOKED CHEAPER.
# go-zpkg/recipes#143 lists both, and `llvm.org`'s closure skips only
# `gnome.org/libxml2` (written in #150) and `ninja-build.org` — so one small
# recipe appeared to close that branch. Read from ninja 1.13.2's own files,
# ninja has exactly two build paths and BOTH need a tool this tree does not
# have: `CMakeLists.txt:1` requires CMake >= 3.15, and `configure.py:1` is
# `#!/usr/bin/env python3`. A ninja recipe written first would have resolved
# only because another unwritten recipe exists — the fragment shape #143 is
# about, one level up.
#
# CMake's own README states the bootstrap prerequisites: "You need to have a
# C++ compiler (supporting C++14) and a `make` installed." Nothing else. No
# existing CMake, no Python. Both are already members of
# go-zpkg/base-toolchain, so this recipe is buildable from the toolchain AS IT
# STANDS — and it is the only one of the three that is.

summary = "CMake: a cross-platform build system generator, with ctest and cpack"

# ⛔ BSD-3-Clause FOR CMAKE ITSELF, and that is what LICENSE.rst and README.rst
# both say ("CMake is distributed under the OSI-approved BSD 3-clause
# License"), over "Copyright 2000-2026 Kitware, Inc. and Contributors".
#
# ⚠ THE SOURCE TREE ALSO CARRIES Licenses/LGPLv2.1.txt AND Licenses/LGPLv3.txt,
# with Licenses/README.rst explaining them: "This directory contains other
# license files that need to be packaged with binary distributions when certain
# third-party libraries are included." They are conditional on the bundled
# libraries — see the census below, which settles which ones this artifact
# contains. The LGPL halves are kept in the expression rather than claiming a
# BSD-only artifact, because the bundled set is not empty and this recipe has
# not opened each bundled library to establish which of the two LGPL files
# applies to which.
license = "BSD-3-Clause AND LGPL-2.1-or-later AND LGPL-3.0-or-later"

# README.rst's "Supported Platforms" names Windows, macOS, Linux, FreeBSD,
# OpenBSD and Solaris. Ours are the first three plus the BSDs we have machines
# for; Solaris is not a platform in this fleet.
platforms = ["linux", "darwin", "windows", "freebsd", "openbsd", "netbsd"]

versions {
  # ⛔ THE TAGS, BECAUSE cmake.org/files IS TWO LEVELS DEEP. The index at
  # https://cmake.org/files/ lists MINOR directories (v4.0, v4.1, …) and the
  # tarballs live one level inside them, so a single `match` cannot reach a
  # version — it would match the directory names and strip them to nothing.
  # Measured 2026-11-18: /files/ answers 200 with `v4.N` entries, /files/v4.5/
  # answers 200 with `cmake-4.5.0.tar.gz`.
  github = "Kitware/CMake/tags"
  strip  = ["/^v/"]

  # ⚠ CMake tags its release candidates in the same namespace (`v4.5.0-rc1`),
  # so they are excluded here rather than left for the resolver to pick as the
  # newest. `-rc` is CMake's own spelling.
  #
  # ⛔ WHAT WAS MEASURED, AND WHAT WAS NOT. `zpkb versions` resolves 271
  # versions against the live tag list, newest first (4.5.0, 4.4.5, 4.4.4 …),
  # and NONE of them carries `rc`. That proves the resolved list is clean; it
  # does NOT prove this rule fired, because a list that never contained a
  # candidate looks identical. Distinguishing the two needs a raw tag listing,
  # which is a GitHub call this run deliberately did not spend — `ghrelease`
  # refused to tag at 609 REST calls remaining against a 1000 margin the same
  # afternoon, and the budget is shared with Renovate across ~25 sessions.
  # The rule stays as a guard either way; the claim is kept to what was read.
  ignore = [
    "/-rc\\d*$/",
  ]
}

distributable {
  # The project's own host, not the tag archive: cmake.org publishes a real
  # source tarball whose digest it also signs (see provenance).
  #
  # ⭐ `version.marketing` IS THE TOKEN NAMED FOR THIS, and it is used rather
  # than `{{version.major}}.{{version.minor}}` spelled out: moustache's own
  # test fixes the contract as 1.2.3 → "1.2", so the directory `v4.5` for
  # 4.5.0 comes from one token instead of two joined by a dot this recipe
  # would be responsible for. Verified end to end for 4.5.0: the expansion
  # https://cmake.org/files/v4.5/cmake-4.5.0.tar.gz answers 200 and its bytes
  # hash to the digest below.
  url              = "https://cmake.org/files/v{{version.marketing}}/cmake-{{version.raw}}.tar.gz"
  strip-components = 1

  # 13893781 bytes, recorded with the builder's own fetcher:
  #
  #   zpkb sourcepin --version 4.5.0 \
  #     https://cmake.org/files/v4.5/cmake-4.5.0.tar.gz
  #
  # ⭐ AND CONFIRMED AGAINST THE PROJECT'S OWN SIGNED CHECKSUM FILE, which is
  # a stronger second path than a second download: cmake-4.5.0-SHA-256.txt says
  #
  #   424352d6133e8455e020da787008e8dc67abb18820af3532572ab35657e49213  cmake-4.5.0.tar.gz
  #
  # byte for byte what the fetcher computed, and that file is itself signed
  # (cmake-4.5.0-SHA-256.txt.asc). Two paths, one answer, and the second
  # answer carries a signature — see provenance for why the signature could
  # not be VERIFIED here.
  sha256 = {
    "4.5.0" = "424352d6133e8455e020da787008e8dc67abb18820af3532572ab35657e49213"
  }
}

build {
  # ⛔ THE WHOLE DEPENDENCY LIST IS THE BOOTSTRAP'S, AND IT IS SHORT BY DESIGN.
  # README.rst: "You need to have a C++ compiler (supporting C++14) and a
  # `make` installed." The compiler arrives through go-zpkg/base-toolchain
  # (llvm.org); `make` is named because the bootstrap's default generator is
  # the Unix Makefiles one — a CONSTANT, `bootstrap:173`, not a probe, which is
  # what makes this recipe free of a chicken-and-egg with ninja.
  dependencies = {
    "gnu.org/make" = "*"

    # ⛔⛔ THE SEVEN BUNDLED LIBRARIES THIS TREE ALREADY PROVIDES. See the
    # census in the ARGS block: CMake vendors TWELVE third-party libraries and
    # uses its own copies by default. Each of these is a library the store
    # already carries, so vendoring it would ship a second, unpatched copy that
    # `zpkb sonames`, the advisory machinery and the SBOM cannot see.
    "curl.se"                    = "*"
    "libexpat.github.io"         = "*"
    "zlib.net"                   = "*"
    "sourceware.org/bzip2"       = "*"
    "tukaani.org/xz"             = "*"
    "nghttp2.org"                = "*"
    "facebook.com/zstd"          = "*"
  }

  # ⛔⛔ THE SWITCH CENSUS. Every option in `bootstrap`'s own usage block
  # (:693-770) was read. What follows states every one whose default is NOT a
  # deterministic constant — every one where something outside this recipe
  # decides what lands in the artifact.
  #
  # ⛔⛔ CMAKE BUNDLES TWELVE THIRD-PARTY LIBRARIES AND USES ITS OWN COPIES BY
  # DEFAULT (`--no-system-*`, bootstrap:706-733):
  #
  #   cppdap  curl  expat  jsoncpp  zlib  bzip2
  #   liblzma  nghttp2  zstd  libarchive  librhash  libuv
  #
  # That is the vendored-copy defect in its purest form: seven of those twelve
  # are projects this tree ALREADY BUILDS, so the default artifact would carry
  # a second copy of each — older than the store's, invisible to `zpkb
  # sonames`, absent from the SBOM, and unreachable by an advisory that names
  # the project.
  #
  # ⚠ AND `--system-libs` IS NOT AVAILABLE, which is why this is done one flag
  # at a time rather than with the blanket switch its usage line offers to
  # "package maintainers". Measured over this tree's 248 recipes on
  # 2026-11-18: 7 of the 12 have a recipe here —
  #
  #   curl     → curl.se                  cppdap     → ⛔ none
  #   expat    → libexpat.github.io       jsoncpp    → ⛔ none
  #   zlib     → zlib.net                 libarchive → ⛔ none
  #   bzip2    → sourceware.org/bzip2     librhash   → ⛔ none
  #   liblzma  → tukaani.org/xz           libuv      → ⛔ none
  #   nghttp2  → nghttp2.org
  #   zstd     → facebook.com/zstd
  #
  # `--system-libs` would demand all twelve and fail on the five. The five that
  # stay vendored are NAMED here rather than left implicit, so the next reader
  # knows exactly what this artifact carries a private copy of, and so that
  # writing any of those five recipes has an obvious next step attached.
  #
  # ⛔ ONE OF THE DEFAULTS IS PLATFORM-DEPENDENT, which is worse than a plain
  # default and is the reason curl is passed explicitly even where it is
  # already the default: bootstrap:712 documents `--system-curl` as "default on
  # macOS" and `--no-system-curl` as "default elsewhere". So the same recipe,
  # unchanged, would link the system curl on darwin and a vendored one on
  # linux — a difference in what the artifact CONTAINS, decided by the host.
  env = {
    ARGS = [
      # bootstrap:756-757 defaults the prefix to `${cmake_default_prefix}`,
      # which on unix is the constant "/usr/local" (bootstrap:222).
      "--prefix={{prefix}}",

      # The seven the store provides.
      "--system-curl",
      "--system-expat",
      "--system-zlib",
      "--system-bzip2",
      "--system-liblzma",
      "--system-nghttp2",
      "--system-zstd",

      # ⚠ THE FIVE THAT STAY VENDORED, RESTATED AS EXPLICIT `--no-system-*`
      # RATHER THAN LEFT TO THE DEFAULT. They are the default today; stating
      # them means a future CMake that flips one of these defaults cannot
      # silently change what this artifact links, and it keeps the list of
      # vendored copies readable in one place instead of inferable by
      # subtraction.
      "--no-system-cppdap",
      "--no-system-jsoncpp",
      "--no-system-libarchive",
      "--no-system-librhash",
      "--no-system-libuv",

      # ⛔ THE DEBUGGER IS AUTO-DETECTED, and it is settled here.
      # bootstrap:743 documents `--debugger` as "(default if supported)", and
      # bootstrap:84 leaves `cmake_bootstrap_debugger` EMPTY, so
      # bootstrap:2025-2027 writes no cache entry at all and CMake's own
      # CMakeLists decides from what it finds. The feature needs cppdap, which
      # is one of the five vendored above, so "supported" here means "the
      # vendored copy built" — a property of the build machine's compiler
      # rather than of this recipe. Off: a build-system generator in a
      # package tree has no debugger client to serve.
      "--no-debugger",

      # ⚠ Upstream's default, RESTATED: bootstrap:739-740, `--no-qt-gui` is
      # the default. Named because the `--qt-gui` arm exists and would pull a
      # Qt this tree does not have.
      "--no-qt-gui",

      # The build driver's own parallelism (bootstrap:700-701, default 1).
      # Build-time only; it does not reach the artifact.
      "--parallel={{ hw.concurrency }}",
    ]
  }

  # ⛔ `ccmake` IS AN AUTO-DETECTION AND IT IS TURNED OFF, which is what makes
  # `provides` below a function of this recipe rather than of the build host.
  # Source/Modules/CMakeBuildUtilities.cmake:360-367:
  #
  #     if(NOT DEFINED BUILD_CursesDialog)
  #       … set(BUILD_CursesDialog_DEFAULT "${CMakeCheckCurses_COMPILED}")
  #       option(BUILD_CursesDialog "Build the CMake Curses Dialog ccmake" …)
  #
  # It COMPILES A TEST PROGRAM against curses and installs `bin/ccmake` — plus
  # a dependency on ncurses — if that happened to succeed. This tree does carry
  # invisible-island.net/ncurses, so the choice is real rather than forced; it
  # is off because `ccmake` is an interactive terminal dialog and every
  # consumer of this package is a recipe.
  #
  # Passed after `--` because it is a CMake cache variable rather than a
  # bootstrap option (bootstrap:694, "[-- <cmake-options>...]").
  script = [
    "./bootstrap $ARGS -- -DBUILD_CursesDialog=OFF",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# ⛔ THREE, AND THE FOURTH IS DELIBERATELY ABSENT. `bin/ccmake` would be the
# fourth and only appears when the curses probe above succeeds — listing a name
# that depends on what was staged is worse than omitting it, because it passes
# on the machine that had ncurses and fails everywhere else.
provides = [
  "bin/cmake",
  "bin/ctest",
  "bin/cpack",
]

test {
  script = [
    # It runs and knows its own version — the cheapest end-to-end witness that
    # the bootstrap produced a working binary rather than one that links.
    "\"{{prefix}}/bin/cmake\" --version",
    "\"{{prefix}}/bin/ctest\" --version",
    "\"{{prefix}}/bin/cpack\" --version",

    # ⛔ AND THE ASSERTION THAT CATCHES THE CURSES PROBE COMING BACK. If a
    # future edit drops -DBUILD_CursesDialog=OFF, ccmake reappears and the
    # artifact gains an ncurses dependency nothing declared. Asserted as an
    # ABSENCE, because that is the direction the defect travels.
    {
      run = <<EOT
if test -e "{{prefix}}/bin/ccmake"; then
  echo "cmake: bin/ccmake was installed, so the curses probe is deciding again" >&2
  echo "  Source/Modules/CMakeBuildUtilities.cmake:360-367 defaults" >&2
  echo "  BUILD_CursesDialog to whether a curses test program COMPILED, so the" >&2
  echo "  artifact's contents would depend on the build machine." >&2
  exit 1
fi
EOT
    },

    # ⭐ AND THE ONE THAT PROVES THE BOOTSTRAP ACTUALLY WORKS AS A GENERATOR,
    # which --version does not: configure and build a one-file project with
    # the cmake we just installed. A cmake that starts but cannot generate is
    # a cmake that fails on the first recipe that uses it, far from here.
    {
      run = <<EOT
set -e
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT
cat > "$d/CMakeLists.txt" <<'CM'
cmake_minimum_required(VERSION 3.15)
project(smoke C)
add_executable(smoke smoke.c)
CM
printf 'int main(void){return 0;}\n' > "$d/smoke.c"
"{{prefix}}/bin/cmake" -S "$d" -B "$d/build" -G "Unix Makefiles"
"{{prefix}}/bin/cmake" --build "$d/build"
test -x "$d/build/smoke"
EOT
    },
  ]
}

provenance {
  read = [
    "README.rst",                                  # the BSD-3-Clause statement; "Supported Platforms"; the bootstrap prerequisites — a C++14 compiler and make, and nothing else
    "LICENSE.rst",                                 # :1 "Copyright 2000-2026 Kitware, Inc. and Contributors", then the BSD 3-clause text
    "Licenses/README.rst",                         # why LGPLv2.1.txt and LGPLv3.txt ship: "packaged with binary distributions when certain third-party libraries are included"
    "configure",                                   # three lines: it is `exec bootstrap "$@"`, so ./configure IS the bootstrap
    "bootstrap",                                   # the option census :693-770; :84 the empty debugger default; :170-173 the generator is a CONSTANT (Unix Makefiles on unix); :222 prefix /usr/local; :706-733 the twelve bundled libraries and the macOS-only curl default; :996-1003 how --system-* reach CMAKE_USE_SYSTEM_LIBRARY_*; :2025-2027 the debugger cache entry written only when the flag was given
    "Source/Modules/CMakeBuildUtilities.cmake",    # :360-367 BUILD_CursesDialog defaults to whether a curses test program COMPILED
    "Source/CMakeLists.txt",                       # :1449 the ccmake arm; :1454 BUILD_QtDialog defaults FALSE
  ]

  consulted = [
    # Read for the SIGNING KEY's fingerprint only, never for the build.
    "gentoo sec-keys/openpgp-keys-bradking-20260908.ebuild (DESCRIPTION, HOMEPAGE, fingerprint entry)",
  ]

  note = <<EOT
⭐ THE FINGERPRINT IS CORROBORATED BY TWO INDEPENDENT SOURCES, which is a
better chain than musl.libc.org's and worth saying so:

  cmake.org/download   the "PGP sig by" link for 4.5.0 carries
                       0xcba23971357c2e6590d9efd3ec8fef3a7bfb4eda
  gentoo               sec-keys/openpgp-keys-bradking declares
                       'CBA23971357C2E6590D9EFD3EC8FEF3A7BFB4EDA:bradking:openpgp,ubuntu'
                       with DESCRIPTION "OpenPGP keys used by Brad King"

Same primary key, from the project and from a third party that is not the
project. musl's chain is single-host (tarball, .asc, fingerprint and key all
from musl.libc.org — continuity, not independence); this one is not.

⛔⛔ AND THE SIGNATURE WAS NOT VERIFIED HERE, for a reason that is a fleet rule
rather than an obstacle. The key's BYTES are reachable only from a KEYSERVER:
cmake.org's own page links one, Gentoo's labels are `openpgp,ubuntu` (both
keyservers), and there is no Web Key Directory — measured 2026-11-18,
`https://kitware.com/.well-known/openpgpkey/policy` redirects to www and then
404s, `openpgpkey.kitware.com` does not resolve, `cmake.org/.well-known/…`
404s, and the fingerprint appears nowhere in Kitware/CMake's own repository.

This fleet never asks a keyserver, because Guix's `--key-download` default
(`auto`, documented as `interactive` on a TTY and "else always") means an
unknown key is fetched and accepted in CI, and the check degrades to "somebody
signed it". So the digest is pinned at the "published checksum" rung rather
than the "verified signature" one — the libxml2 / mpdecimal / nghttp2 tier.

⚠ WHAT WOULD COMPLETE THE CHAIN, stated so it is one step and not a
rediscovery: obtain Brad King's key from a non-keyserver source and re-run
`sourcepin --sig auto --key <file> --fingerprint "CBA2 3971 357C 2E65 90D9
EFD3 EC8F EF3A 7BFB 4EDA"`. The fingerprint is already established by the two
sources above; only the bytes are missing.

⚠ AND NOTE WHICH OBJECT IS SIGNED. The `.asc` is over
`cmake-4.5.0-SHA-256.txt`, the CHECKSUM FILE, not over the tarball. That is
Guix's own division — verify the hash file, then the hash is the durable pin —
and it is why the digest recorded above is the same string the signed file
carries, confirmed byte for byte against an independent fetch with the
builder's fetcher.

⚠ A NOTE FOR CONSUMERS, not for this build: CMake 4.x removes compatibility
with `cmake_minimum_required(VERSION <3.5)`. Recipes in this tree whose
upstreams still declare an old minimum will fail against this package in a way
that reads as a CMake defect. It is named here because `versions` resolves to
the newest, and the constraint belongs on the consumers that need an older
line, not on this recipe.

⛔ NOT BUILT. No session here can run the factory, so what is established is
this recipe's INPUTS: every switch, dependency, installed path and licence
traced to a line in CMake's own files and cited in `read` above. The build is
unproven and should be read as such.

⭐ The test block goes past "it starts": it configures and builds a one-file
project with the cmake just installed. A generator that runs but cannot
generate would otherwise be found by the first recipe that uses it, a long way
from here.
EOT
}
