# github.com/google/brotli — the compression library freetype.org links, and
# the third CMake project in this tree.
#
# ⛔ WRITTEN FROM BROTLI'S OWN FILES (go-zpkg/packages#431), at 1.2.1.
#
# ⭐ IT IS WRITABLE AT ALL BECAUSE cmake.org LANDED (go-zpkg/recipes#160):
# CMakeLists.txt:4 requires CMake >= 3.15 and there is no autotools path. The
# consumer half has been in the tree since go-zpkg/recipes#31 — freetype's
# `FT_REQUIRE_BROTLI` — so this closes a declaration that had nothing behind
# it.

summary = "Brotli: a general-purpose lossless compression library and its CLI"

# LICENSE is the MIT text over "Copyright (c) 2009, 2010, 2013-2016 by the
# Brotli Authors."
license = "MIT"

# `project(brotli C)` (CMakeLists.txt:11) — pure C, no C++, and nothing in the
# tree is platform-specific beyond the Emscripten arm named below.
platforms = ["linux", "darwin", "windows", "freebsd", "openbsd", "netbsd"]

versions {
  github = "google/brotli/tags"
  strip  = ["/^v/"]
}

distributable {
  # ⛔ THE AUTO-GENERATED TAG ARCHIVE, because the project publishes no source
  # tarball. Measured 2026-11-18: the v1.2.1 release carries SEVEN assets and
  # six are prebuilt Windows binaries (brotli-{arm64,x64,x86}-windows-{dynamic,
  # static}.zip); the seventh is `testdata.txz`. No source archive, no checksum
  # file, no `.asc`.
  url              = "https://github.com/google/brotli/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 646598 bytes, recorded with the builder's own fetcher and confirmed by an
  # independent `curl --fail` + `shasum -a 256`: two paths, one answer. That is
  # ALL the assurance available — see provenance for the four things absent.
  sha256 = {
    "1.2.1" = "98d35d11a78dc453aebb7d10c3748f3f73ff78c8267c0dc697b8631f67bf7e8f"
  }
}

build {
  dependencies = {
    # CMakeLists.txt:4, the project's own floor.
    "cmake.org" = ">=3.15"

    # The generator pinned below is the Unix Makefiles one.
    "gnu.org/make" = "*"
  }

  # ⛔ THE SWITCH CENSUS. CMakeLists.txt states four knobs and one of them is
  # derived rather than declared:
  #
  #   BUILD_SHARED_LIBS         ON    (:39)  option()
  #   BROTLI_BUILD_TOOLS        ON    (:40)  CACHE BOOL
  #   BROTLI_BUILD_FOR_PACKAGE  OFF   (:41)  CACHE BOOL
  #   BROTLI_BUNDLED_MODE       DERIVED (:52-60) — see below
  #   BROTLI_DISABLE_TESTS      never declared, so falsy and tests are built
  #
  # All four of the declared ones are deterministic constants, so by this
  # campaign's standard none is a defect. They are restated anyway where the
  # value decides what is installed.
  #
  # ⚠ BROTLI_BUILD_FOR_PACKAGE IS NAMED FOR WHAT WE ARE AND IS LEFT AT ITS
  # DEFAULT, which is a judgement stated rather than made silently. Its own
  # description is "Build/install both shared and static libraries", so
  # upstream wrote it for packagers; with it OFF only the shared libraries are
  # installed. It stays OFF because the one consumer in this tree —
  # freetype.org (go-zpkg/recipes#31) — links the shared library, and adding
  # static archives would change what the artifact contains for no measured
  # need. A consumer that needs `libbrotlidec.a` is the reason to flip it, and
  # then it should be flipped deliberately.
  #
  # ⛔ BROTLI_BUNDLED_MODE IS DERIVED FROM HOW THE PROJECT WAS INCLUDED, and
  # while it is deterministic for us it decides EVERYTHING about installation.
  # CMakeLists.txt:51-60:
  #
  #     get_directory_property(BROTLI_PARENT_DIRECTORY PARENT_DIRECTORY)
  #     if (BROTLI_PARENT_DIRECTORY) set(BROTLI_BUNDLED_MODE ON)
  #     else() set(BROTLI_BUNDLED_MODE OFF) endif()
  #
  # and :186 wraps EVERY install rule in `if (NOT BROTLI_BUNDLED_MODE)`. A
  # build driven by `add_subdirectory` installs nothing at all — no binary, no
  # libraries, no headers. This recipe configures the project at top level, so
  # the arm is OFF; written down because "the install rules did nothing" is a
  # silent outcome with a cause two hundred lines away.
  env = {
    ARGS = [
      "-S", ".",
      "-B", "build",
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",

      # ⛔⛔ THE GENERATOR, AND THIS IS NO LONGER A HYPOTHETICAL. Given no
      # `-G`, CMake picks its default generator, and on unix that is Ninja
      # WHEN A NINJA IS ON PATH and Unix Makefiles otherwise. ninja-build.org
      # landed in go-zpkg/recipes#161, so a machine that has staged it would
      # now silently build this package with a different driver from one that
      # has not. Pinned, for the same reason the ninja recipe pins its own.
      "-G", "Unix Makefiles",

      # The two that decide what is installed, restated at their defaults.
      "-DBUILD_SHARED_LIBS=ON",
      "-DBROTLI_BUILD_TOOLS=ON",
    ]
  }

  script = [
    "cmake $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# ⛔ READ FROM THE INSTALL RULES, CMakeLists.txt:186-205 — one executable, the
# libraries, and the headers:
#
#   :188-191  TARGETS brotli → CMAKE_INSTALL_BINDIR
#   :194-199  the shared (and, with FOR_PACKAGE, static) libraries
#   :201-204  c/include/brotli → CMAKE_INSTALL_INCLUDEDIR
#
# plus three .pc files (:377-381) and the man pages (:386, :390). Only the
# executable is a command, so `provides` has one entry.
provides = [
  "bin/brotli",
]

test {
  script = [
    "\"{{prefix}}/bin/brotli\" --version",

    # ⭐ A ROUND TRIP, because --version does not establish that either half of
    # the codec works. Compress and decompress, and require the bytes back —
    # a library that builds and produces garbage would otherwise be found by
    # freetype, which is the wrong place to learn it.
    {
      run = <<EOT
set -e
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT
# Something compressible enough that the encoder has to do real work, and
# generated rather than copied so the test does not depend on a file.
i=0
while [ $i -lt 200 ]; do
  echo "the quick brown fox jumps over the lazy dog $i" >> "$d/in.txt"
  i=$((i + 1))
done
"{{prefix}}/bin/brotli" --input "$d/in.txt" --output "$d/in.txt.br"
test -s "$d/in.txt.br"
"{{prefix}}/bin/brotli" --decompress --input "$d/in.txt.br" --output "$d/out.txt"
cmp "$d/in.txt" "$d/out.txt"
EOT
    },

    # ⛔ AND THE HEADERS AND LIBRARY MUST BE THERE, because freetype.org links
    # them and a brotli that installs only its CLI would satisfy every check
    # above while breaking its one consumer in this tree.
    {
      run = <<EOT
set -e
test -f "{{prefix}}/include/brotli/decode.h"
test -f "{{prefix}}/include/brotli/encode.h"
if ! ls "{{prefix}}"/lib/libbrotlidec.* >/dev/null 2>&1; then
  echo "brotli: no libbrotlidec in {{prefix}}/lib." >&2
  echo "  Every install rule is wrapped in 'if (NOT BROTLI_BUNDLED_MODE)'" >&2
  echo "  (CMakeLists.txt:186), and that variable is DERIVED from whether the" >&2
  echo "  project had a PARENT_DIRECTORY (:51-60) — so a build driven by" >&2
  echo "  add_subdirectory installs nothing at all, silently." >&2
  exit 1
fi
EOT
    },
  ]
}

provenance {
  read = [
    "CMakeLists.txt",  # :4 cmake_minimum_required 3.15; :11 project(brotli C); :25-35 the Emscripten arm; :39-41 the three declared options; :51-60 BROTLI_BUNDLED_MODE derived from PARENT_DIRECTORY; :73-84 version and ABI read out of c/common/version.h; :180-183 the CLI target; :186-205 every install rule, all inside the bundled-mode guard; :210/:231 the test arms; :377-381 the .pc files; :386/:390 the man pages
    "LICENSE",         # the MIT text, "Copyright (c) 2009, 2010, 2013-2016 by the Brotli Authors"
    "README.md",       # the project's own description
    "c/common/version.h", # where CMakeLists reads BROTLI_VERSION_* and the ABI numbers from
  ]

  note = <<EOT
⛔⛔ THE PROVENANCE FLOOR IS *NOTHING*, measured the same four ways as
ninja-build.org (go-zpkg/recipes#161) and with the same answer:

  1. NO SOURCE TARBALL. The v1.2.1 release carries seven assets: six prebuilt
     Windows binaries and `testdata.txz`.
  2. NO SIGNATURE ON ANY ASSET.
  3. NO SIGNED TAG. `git/ref/tags/v1.2.1` answers `object.type: "commit"` — a
     LIGHTWEIGHT tag, so there is no annotated object and nothing to sign.
     (`v1.1.0` is the same, so this is the project's practice and not a slip
     on one release.)
  4. THE TAGGED COMMIT IS UNSIGNED: `verification.reason: "unsigned"`.

So the source is GitHub's auto-generated tag archive — the weakest rung on
this campaign's ladder, the `sourceware.org/libffi` tier. What this recipe has
is a digest recorded twice by independent paths, which establishes that two
fetches agreed and nothing about WHO produced the bytes. A pin, not a
provenance, and it is written plainly rather than dressed up.

⚠ THAT IS NOW THE THIRD RECIPE IN A ROW AT THIS RUNG — libffi, ninja, brotli —
and the pattern is worth naming: the projects in this tree that publish NO
signature are the ones whose releases are produced by CI from a git tag, where
the tag is the artefact and nobody signs it. The ones with real chains
(gnu.org/glibc, musl.libc.org, cmake.org, python.org) all publish a tarball
built by a release manager. It is a difference in release PROCESS, not in
care, and no amount of reading the recipe will improve it.

⛔ NOT BUILT. No session here can run the factory, so what is established is
this recipe's INPUTS: every option, dependency, installed path and licence
traced to a line in brotli's own files and cited in `read` above.
EOT
}
