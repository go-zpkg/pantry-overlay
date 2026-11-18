# ninja-build.org — and it is written SECOND, after cmake.org, because it could
# not be written first.
#
# ⛔ WRITTEN FROM NINJA'S OWN FILES (go-zpkg/packages#431), at 1.13.2.
#
# ⛔⛔ IT HAS TWO BUILD PATHS AND BOTH NEEDED A TOOL THIS TREE DID NOT HAVE:
# `CMakeLists.txt:1` requires CMake >= 3.15, and `configure.py:1` is
# `#!/usr/bin/env python3`. go-zpkg/recipes#143 lists ninja as one of the two
# projects `llvm.org`'s closure skips, and it LOOKED like the cheap one — a
# ~200 KB source tree against CMake's tens of megabytes. Written first it would
# have resolved only because another unwritten recipe existed, which is the
# fragment shape that issue is about. cmake.org landed in go-zpkg/recipes#160;
# this takes the CMake path, and `llvm.org`'s pair is now complete
# (gnome.org/libxml2 was go-zpkg/recipes#150).

summary = "Ninja: a small build system with a focus on speed"

# COPYING is the Apache License 2.0 text. The source files carry its header.
license = "Apache-2.0"

# INSTALL has no platform list; the project builds on unix, macOS and Windows,
# and this fleet's targets are covered. wasip1 is excluded by omission — ninja
# spawns subprocesses and polls them, which a wasip1 module cannot do.
platforms = ["linux", "darwin", "windows", "freebsd", "openbsd", "netbsd"]

versions {
  github = "ninja-build/ninja/tags"
  strip  = ["/^v/"]
}

distributable {
  # ⛔⛔ THE AUTO-GENERATED TAG ARCHIVE, BECAUSE THE PROJECT PUBLISHES NO
  # SOURCE TARBALL AT ALL. Measured 2026-11-18: the v1.13.2 release carries
  # five assets and every one is a PREBUILT BINARY — ninja-linux.zip,
  # ninja-linux-aarch64.zip, ninja-mac.zip, ninja-win.zip, ninja-winarm64.zip.
  # No source archive, no checksum file, no `.asc`.
  #
  # ⚠ AND A TAG ARCHIVE IS THE WEAKEST SOURCE ON THIS CAMPAIGN'S LADDER, said
  # here rather than left implicit: GitHub generates it on demand, and its
  # byte-for-byte stability is a convention rather than a contract. The digest
  # below is what it served on 2026-11-18; a future re-tar that changes it
  # would read as a tampered source rather than as a platform change.
  url              = "https://github.com/ninja-build/ninja/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # Recorded with the builder's own fetcher and confirmed by an independent
  # `curl --fail` + `shasum -a 256`: two paths, one answer. That is ALL the
  # assurance available here — see provenance for the four things that are
  # absent.
  sha256 = {
    "1.13.2" = "974d6b2f4eeefa25625d34da3cb36bdcebe7fbce40f4c16ac0835fd1c0cbae17"
  }
}

build {
  dependencies = {
    # CMakeLists.txt:1, `cmake_minimum_required(VERSION 3.15)`. The version is
    # the project's own floor, not one invented here.
    "cmake.org" = ">=3.15"

    # The generator this recipe pins below is the Unix Makefiles one, so make
    # is a real build-time need rather than an inherited habit.
    "gnu.org/make" = "*"
  }

  # ⛔ THE SWITCH CENSUS. CMakeLists.txt declares exactly TWO options, and both
  # are deterministic constants:
  #
  #   NINJA_BUILD_BINARY    ON   (:6)
  #   NINJA_FORCE_PSELECT   OFF  (:7)
  #
  # What follows is everything that is NOT an option and still lets something
  # outside this recipe decide.
  env = {
    ARGS = [
      "-S", ".",
      "-B", "build",
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",

      # ⛔⛔ THE GENERATOR, AND THE REASON IS RECURSIVE: given no `-G`, CMake
      # picks its default generator, and on unix that is Ninja WHEN A NINJA IS
      # ON PATH and Unix Makefiles otherwise. So building ninja would be built
      # by whatever ninja the machine happened to have — the artifact's build
      # driver decided by the host, for the one package where that is also the
      # thing being built. Pinned.
      "-G", "Unix Makefiles",

      # ⛔ LINK-TIME OPTIMISATION IS AUTO-DETECTED AND IS TURNED OFF HERE.
      # CMakeLists.txt:13-21 calls `check_ipo_supported(RESULT lto_supported)`
      # and, if it says yes, sets CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE
      # TRUE. So the SHAPE OF THE BINARY depends on what the compiler answered
      # on the build machine — two runs of this recipe on two machines produce
      # differently optimised artifacts with nothing recording which. Off, so
      # the artifact is a function of the recipe.
      #
      # ⚠ This is a deliberate trade and it is stated: upstream wants LTO when
      # it can have it, and this gives it up for determinism. The thing being
      # built is a build driver whose cost is dominated by process spawning
      # and file stats, not by the optimiser.
      "-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF",
      "-DCMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE=OFF",

      # ⚠ CMakeLists.txt:252 does `include(CTest)`, whose module defaults
      # BUILD_TESTING to ON — so `ninja_test` (:274) is built by default. It is
      # NOT installed (the only install rule is `install(TARGETS ninja)` at
      # :334), so it never reaches the artifact; what it costs is build time.
      # Kept ON deliberately: it is what the test block below runs, and a
      # package that ships a build tool without ever executing its own suite
      # would be taking upstream's word for it.
      "-DBUILD_TESTING=ON",
    ]
  }

  # ⚠⚠ ONE AUTO-DETECTION IS NAMED AND NOT SETTLED, because it cannot honestly
  # be settled from here. CMakeLists.txt:64-85:
  #
  #     find_program(RE2C re2c)
  #     if(RE2C) … re2c(src/depfile_parser.in.cc …) ; re2c(src/lexer.in.cc …)
  #     else() message(WARNING "re2c 2 or later was not found; …")
  #             add_library(libninja-re2c OBJECT src/depfile_parser.cc src/lexer.cc)
  #
  # With re2c present the depfile parser and the lexer are REGENERATED from
  # `src/*.in.cc`; without it the pre-generated `.cc` files that ship in the
  # tarball are compiled. So the SOURCE of two translation units depends on
  # what was staged.
  #
  # ⛔ AND IT CANNOT BE PINNED THE OBVIOUS WAY: `find_program` re-runs its
  # search whenever the cache variable holds `<VAR>-NOTFOUND`, so
  # `-DRE2C=RE2C-NOTFOUND` does not stop it, and there is no option() guarding
  # the branch. The only deterministic settlements are "re2c is always there"
  # — which needs a re2c recipe this tree does not have — or a patch, which
  # would be this recipe inventing a switch upstream did not write.
  #
  # ⚠ The blast radius is bounded and that is why it is accepted rather than
  # blocked on: both arms produce a lexer for the same grammar, and the
  # pre-generated files are the ones upstream ships and tests. Today re2c is
  # absent from this tree, so the else-arm is taken — by ACCIDENT of staging
  # rather than by decision, which is exactly why it is written down.
  script = [
    "cmake $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# `install(TARGETS ninja)` at CMakeLists.txt:334 is the only install rule in
# the file: one binary, no manual, no data. `ninja_test` is built and not
# installed, so it is deliberately absent here.
provides = [
  "bin/ninja",
]

test {
  script = [
    # It runs and knows its version.
    "\"{{prefix}}/bin/ninja\" --version",

    # ⭐ AND IT ACTUALLY BUILDS SOMETHING, which --version does not establish.
    # A build driver that starts but cannot execute an edge is a defect the
    # first recipe using it would find, a long way from here.
    {
      run = <<EOT
set -e
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT
cat > "$d/build.ninja" <<'NJ'
rule copy
  command = cp $in $out
build out.txt: copy in.txt
NJ
printf 'hello\n' > "$d/in.txt"
"{{prefix}}/bin/ninja" -C "$d" out.txt
test -f "$d/out.txt"
grep -q hello "$d/out.txt"
EOT
    },
  ]
}

provenance {
  read = [
    "CMakeLists.txt",   # :1 cmake_minimum_required 3.15; :6-7 the only two options; :13-21 check_ipo_supported decides LTO; :64-85 the re2c branch; :195 cxx_std_11; :252-253 include(CTest) and BUILD_TESTING; :274 ninja_test; :334 install(TARGETS ninja) — the sole install rule
    "configure.py",     # :1 `#!/usr/bin/env python3` — the other build path, and why ninja could not be written before cmake.org
    "COPYING",          # the Apache License 2.0 text
    "README.md",        # the project's own description
  ]

  note = <<EOT
⛔⛔ THE PROVENANCE FLOOR HERE IS *NOTHING*, and that is a measurement rather
than an omission. Four separate things were checked on 2026-11-18 and all four
are absent:

  1. NO SOURCE TARBALL. The v1.13.2 release carries five assets and every one
     is a prebuilt binary (ninja-linux.zip, ninja-linux-aarch64.zip,
     ninja-mac.zip, ninja-win.zip, ninja-winarm64.zip).
  2. NO SIGNATURE ON ANY ASSET. No `.asc`, no `.sig`.
  3. NO SIGNED TAG. `git/ref/tags/v1.13.2` answers `object.type: "commit"` —
     a LIGHTWEIGHT tag, so there is no annotated tag object and therefore
     nothing to sign.
  4. THE TAGGED COMMIT IS UNSIGNED. Its verification reads
     `verified: false, reason: "unsigned"`.

And ninja-build.org itself publishes no tarball, no checksums and no
signatures: it points at the GitHub releases page, which carries the binaries
above.

⚠ So this sits at the bottom rung of this campaign's ladder — the
`sourceware.org/libffi` tier. What the recipe HAS is a digest recorded twice by
independent paths (the builder's own fetcher, and `curl --fail` +
`shasum -a 256`), which establishes that two fetches agreed, and nothing about
WHO produced the bytes. Stated plainly rather than dressed up: a digest over an
unsigned, auto-generated archive is a pin, not a provenance.

⭐ WHAT WOULD RAISE IT, so the next reader does not re-derive it: the project
would have to sign something. Until then the strongest available improvement is
on our side rather than theirs — a second, independent fetch from a mirror that
is not GitHub, which would at least make a single-point substitution visible.
No such mirror was found.

⛔ NOT BUILT. No session here can run the factory, so what is established is
this recipe's INPUTS: every option, dependency, installed path and licence
traced to a line in ninja's own files and cited in `read` above.
EOT
}
