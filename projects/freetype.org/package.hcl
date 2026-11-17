# freetype — the FreeType font engine: libfreetype and its headers.
#
# ⛔ WRITTEN FROM FREETYPE'S OWN FILES at 2.15.0, eleventh of the campaign and
# the first CMake project among them (go-zpkg/packages#440). The fragment it
# replaces was already the best of the eleven — PR #31 had added
# `github.com/google/brotli` and the four `-DFT_REQUIRE_*=TRUE` flags, which is
# the "nothing implicit" discipline applied to CMake before the rule was
# stated. This recipe keeps all of it and closes the two it did not reach.
#
# ⛔⛔ THE OWNER'S RULE OF 2026-11-15 — « il faut eviter les trucs implicites »
# — reads differently here than in an autotools recipe. There is no
# `AC_ARG_WITH` to census; the surface is `option()` and
# `cmake_dependent_option()` in CMakeLists.txt, and the dangerous default is
# not "auto-detect" but **OFF on a `FT_DISABLE_*` switch**, which is the same
# thing spelled backwards: `if (NOT FT_DISABLE_X)` then probe for X.

summary = "FreeType: a freely available software library to render fonts"

# ⛔ DUAL AND MUTUALLY EXCLUSIVE, which the SPDX expression says and a list
# would not. `LICENSE.TXT` is explicit: "we distribute it under two mutually
# exclusive open-source licenses. This means that *you* must choose *one* of
# the two" — the FreeType License (`docs/FTL.TXT`, BSD-style WITH an
# advertising clause, GPLv3-compatible and GPLv2-INcompatible) or the GNU GPL
# version 2 (`docs/GPLv2.TXT`, "any later version can be used also").
#
# ⚠ `LICENSE.TXT` also notes that the contributed BDF and PCF drivers carry an
# X11-like licence of their own, compatible with both. Not expressed here
# because the choice above governs the artifact; stated so the next reader
# knows it was read and not missed.
license = "FTL OR GPL-2.0-or-later"

versions {
  # ⛔⛔ UPSTREAM'S EXACT STRINGS, UNIMPROVED, AND THAT IS DELIBERATE. The
  # anchored, dot-escaped form this recipe wants —
  #
  #   match = "/freetype-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.gz/"
  #   strip = ["/^freetype-/", "/\\.tar\\.gz$/"]
  #
  # — could NOT be verified: `download.savannah.gnu.org` answered the listing at
  # 08:12 CET and then timed out for every request from 08:26 onward, including
  # two `zpkb versions` runs against this file at 08:43 and 08:45. The strings
  # below ARE the ones that were run against the live listing, at 08:12, and
  # they returned 24 versions with 2.15.0 newest.
  #
  # So the choice was between a cosmetic improvement nobody has executed and a
  # sloppy expression that has. The unescaped dots match any character, which
  # on this listing is harmless; shipping a regex I could not run is not. The
  # escaping is a separate, testable change for when the host answers.
  url   = "https://download.savannah.gnu.org/releases/freetype/"
  match = "/freetype-(\\d+\\.\\d+(\\.\\d+)?)\\.tar\\.gz/"
  strip = [
    "/freetype-/",
    "/.tar.gz/",
  ]
}

distributable {
  # ⚠ THIS HOST WAS MEASURABLY UNWELL WHILE THIS RECIPE WAS WRITTEN, and the
  # fact is recorded rather than smoothed over: on 2026-11-16 between 08:13 and
  # 08:36 CET, `download.savannah.gnu.org` served a 504 Gateway Time-out
  # (nginx/1.24.0, Trisquel GNU/Linux) for this very URL, then served the
  # tarball correctly on a retry, then timed out for three more requests and
  # for the builder's own fetcher. Upstream's recipe carries a FIXME in the
  # other direction ("our linux docker image TLS doesn't like this URL").
  #
  # It is KEPT as the canonical URL anyway, because the digest below pins the
  # bytes: a mirror cannot substitute anything, so the only cost of a flaky
  # host is a retry. The mirror upstream's FIXME names is used in `provenance`
  # as the corroborating host instead, which is worth more there than here.
  url              = "https://download.savannah.gnu.org/releases/freetype/freetype-{{version.raw}}.tar.gz"
  strip-components = 1

  # 4 262 480 bytes.
  #
  # ⭐ THE BYTES ARE CORROBORATED ACROSS TWO INDEPENDENT HOSTS, which is a
  # stronger control than any recipe in this campaign has had for a digest
  # alone — gnu.org/wget's two readings were both from ftp.gnu.org, so they
  # measured transport and not much else. Here:
  #
  #   download.savannah.gnu.org   9186627467a616d9a9e3e574748ac0c45fa77398e6364edef3041a8ba8d92f64
  #   downloads.sourceforge.net   9186627467a616d9a9e3e574748ac0c45fa77398e6364edef3041a8ba8d92f64
  #
  # same 4 262 480 bytes, different organisations serving them. That rules out
  # one mirror serving something else; it does NOT establish authenticity,
  # since both would carry the same file if upstream itself were compromised.
  # Authenticity is what the paragraph below cannot claim.
  #
  # ⛔⛔ AND THE SIGNATURE IS UNVERIFIED, BECAUSE THE KEY IS NOT PUBLISHED
  # ANYWHERE THIS SESSION COULD REACH. A NEW trust-chain shape for the
  # campaign, and the weakest so far — stated in full rather than left as a
  # silence.
  #
  #   signature    …/releases/freetype/freetype-2.15.0.tar.gz.sig, 833 bytes
  #   algorithm    RSA, SHA-512
  #   created      2026-10-12 (freetype.org's news page dates 2.15.0 the same day)
  #   issuer fpr   E30674707856409FF1948010BE6C3AAC63AD8E3F
  #
  # Where the key was looked for, and what each answered:
  #
  #   ftp.gnu.org/gnu/gnu-keyring.gpg   ABSENT — and expected to be: FreeType
  #                                     is a nongnu Savannah project, not a GNU
  #                                     package, so GNU's keyring has no reason
  #                                     to carry its signer
  #   keys.openpgp.org by-fingerprint   404
  #   freetype.org/download.html        publishes no fingerprint, no key file,
  #                                     and says nothing about verifying a
  #                                     download at all
  #   freetype.org (home)               the same; its only contact is a mailto
  #   savannah.nongnu.org/projects/…    NOT READ (connection refused), and
  #                                     download.savannah.gnu.org's own
  #                                     directory listing timed out three
  #                                     times, so "there is no KEYS file
  #                                     there" is NOT established
  #
  # ⛔ AND THE OBVIOUS SHORTCUT IS CIRCULAR, which is why it was not taken.
  # The fingerprint above comes from the signature's OWN issuer subpacket.
  # Fetching a key by that fingerprint from any keyserver would produce a key
  # that verifies the signature BY CONSTRUCTION and would establish nothing
  # about who holds it — the opposite of gnu.org/wget, where the fingerprint
  # was independently listed in GNU's keyring before any lookup. A chain whose
  # only witness is the thing being checked is not a chain.
  sha256 = {
    "2.15.0" = "9186627467a616d9a9e3e574748ac0c45fa77398e6364edef3041a8ba8d92f64"
  }
}

# WHAT THE ARTIFACT LINKS, measured with `otool -L` on a real install from this
# tree rather than inferred:
#
#   @rpath/libfreetype.6.dylib
#   /usr/lib/libbz2.1.0.dylib                     ← sourceware.org/bzip2
#   /opt/homebrew/opt/libpng/…/libpng16.16.dylib  ← libpng.org
#   /opt/homebrew/opt/brotli/…/libbrotlidec.1.dylib ← github.com/google/brotli
#   /usr/lib/libz.1.dylib                         ← zlib.net
#   /usr/lib/libSystem.B.dylib
#
# ⚠ On darwin bz2 and z came from `/usr/lib` (the SDK's .tbd won), not from the
# staged packages. The declarations are still right: linux has no system copy
# to fall back on. Same shape as gnu.org/wget's libz.
#
# The four constraints are the fragment's, unchanged. `1` rather than `^1` is
# upstream's spelling for three of them and means the same major line; brotli's
# `*` is the fragment's, and brotli states no version requirement that
# `FindBrotliDec` checks, so tightening it would assert a bound the project
# does not have.
dependencies = {
  "github.com/google/brotli" = "*"
  "libpng.org"               = 1
  "sourceware.org/bzip2"     = 1
  "zlib.net"                 = 1
}

build {
  # cmake because autoconf failed to produce the .so files on Linux — that note
  # is upstream's and is kept because it explains a choice the script makes.
  # pkg-config because `CMakeLists.txt:262` includes FindPkgConfig and `:327`
  # calls `pkg_check_modules(PC_BZIP2 bzip2)`.
  dependencies = {
    "cmake.org"                  = "*"
    "freedesktop.org/pkg-config" = "^0.29"
  }

  working-directory = "build"

  # ⛔⛔⛔ THE NINE OPTIONS, AND WHY SIX OF THEM ARE STATED.
  #
  # `grep -n "^option(\|cmake_dependent_option"` over CMakeLists.txt returns
  # nine switches (`:192`-`:232`), every one defaulting OFF:
  #
  #   FT_DISABLE_ZLIB     FT_REQUIRE_ZLIB        FT_DISABLE_BZIP2
  #   FT_REQUIRE_BZIP2    FT_DISABLE_PNG         FT_REQUIRE_PNG
  #   FT_DISABLE_HARFBUZZ FT_DYNAMIC_HARFBUZZ    FT_REQUIRE_HARFBUZZ
  #   FT_DISABLE_BROTLI   FT_REQUIRE_BROTLI      FT_DISABLE_HVF
  #   FT_ENABLE_ERROR_STRINGS                    FT_DISABLE_STREAM_SUPPORT
  #
  # ⛔ A `FT_DISABLE_X` defaulting OFF is auto-detection spelled backwards:
  # `:299`, `:309`, `:317`, `:330` and `:338` all read
  # `if (NOT FT_DISABLE_X)` and then probe for X. So the default is "use it if
  # you find it", which is the thing the owner's rule forbids.
  #
  # Two of the nine are NOT stated, and that is a decision rather than an
  # omission: `FT_ENABLE_ERROR_STRINGS` (`:228`) and
  # `FT_DISABLE_STREAM_SUPPORT` (`:231`) touch no external library, so their
  # defaults are the same on every builder. A deterministic default is a
  # default; what the rule is about is a value the BUILDER picks.
  #
  # ⭐ THE CENSUS WAS CHECKED AGAINST A SECOND BUILD SYSTEM, because "I listed
  # all the options" is exactly the claim that needs an independent side.
  # `meson_options.txt` names nine too — brotli, bzip2, harfbuzz, mmap, png,
  # tests, zlib, hvf, error_strings — and the comparison is useful twice:
  #
  #   - `hvf: auto` corroborates from meson what CMakeLists.txt:338 says, so
  #     the HVF finding below is not an artefact of reading one file;
  #   - meson has an `mmap` option and CMake has NOTHING of the kind. Grepped:
  #     `mmap` appears nowhere in CMakeLists.txt, neither as an option nor as a
  #     probe. So there is no builder decision to make explicit on this path —
  #     the switch simply does not exist in the build we use. Said precisely
  #     rather than as "freetype does not use mmap", which is a claim about the
  #     C sources that was not checked.
  env {
    ARGS = [
      "-DBUILD_SHARED_LIBS=true",
      "-DCMAKE_INSTALL_PREFIX=\"{{ prefix }}\"",
      "-DCMAKE_BUILD_TYPE=Release",

      # The fragment's four, kept verbatim. `FT_REQUIRE_X` turns
      # `find_package(X)` into `find_package(X REQUIRED)` (`:300-304`,
      # `:310-316`, `:322-326`, `:331-335`), so a missing library stops cmake
      # instead of silently producing a freetype that cannot read that format.
      # Their witness is in the test block: `freetype2.pc` comes out with
      # `Requires.private: zlib, bzip2, libpng, libbrotlidec`, which is only
      # written when all four were found.
      #
      # ⭐ AND THE ZLIB ONE DOES MORE THAN REQUIRE — IT UN-VENDORS. `:193`'s own
      # description is "Disable use of system zlib and use **internal zlib
      # library** instead", and `src/gzip/` really does ship one (19 files). So
      # without this flag freetype can carry its own zlib, which is the same
      # defect gnu.org/binutils needed `--with-system-zlib` for: a second copy
      # of a library the registry already provides, and a zlib CVE that would
      # then have to be fixed here too. The fragment's flag already prevented
      # it; nothing said so.
      "-DFT_REQUIRE_ZLIB=TRUE",
      "-DFT_REQUIRE_BZIP2=TRUE",
      "-DFT_REQUIRE_PNG=TRUE",
      "-DFT_REQUIRE_BROTLI=TRUE",

      # ⭐ THE FIFTH DEPENDENCY, AND READING IT IN ORDER REFUTED WHAT I WAS
      # ABOUT TO WRITE. The fragment states nothing about HarfBuzz and
      # `FT_DISABLE_HARFBUZZ` defaults OFF, so my first conclusion was
      # "HarfBuzz is auto-detected and undeclared". `CMakeLists.txt:266-297`
      # says otherwise: `FT_DYNAMIC_HARFBUZZ` defaults **ON** (`:212-214`), and
      # when it is on and `dlopen` exists — libc has it on both our platforms —
      # `:290` takes the `FT_DYNAMIC_HARFBUZZ_ENABLED` branch and
      # `find_package(HarfBuzz)` is **never called**. Confirmed by cmake's own
      # output on a real run:
      #
      #   -- Looking for dlopen - found
      #   -- Enabled dynamic loading of HarfBuzz library at runtime.
      #
      # So the build is already deterministic here, and the artifact links no
      # harfbuzz — `otool -L` above has none. The flag below states the default
      # instead of relying on it.
      #
      # ⛔ AND NO `harfbuzz.org` DEPENDENCY IS DECLARED, for two reasons, the
      # second decisive: freetype dlopen()s it rather than linking it, so it is
      # an optional runtime enhancement and not part of the closure; and
      # harfbuzz DEPENDS ON FREETYPE — `pkgxdev/pantry
      # projects/harfbuzz.org/package.yml:10` is `freetype.org: 2` and `:34`
      # passes `-Dfreetype=enabled`. Declaring it here would be a cycle.
      # Checked, not assumed.
      "-DFT_DYNAMIC_HARFBUZZ=TRUE",

      # ⛔⛔ THE ONE THE FRAGMENT COULD NOT HAVE KNOWN ABOUT, AND THE ONLY REAL
      # DEFECT THIS RECIPE FIXES: `FT_DISABLE_HVF` is new in this line, it
      # defaults OFF, and `:338-348` is
      #
      #     if (NOT FT_DISABLE_HVF)
      #       if (APPLE)
      #         check_include_file("hvf/Scaler.h" HAVE_HVF_HEADER)
      #         find_library(HVF_LIBRARY NAMES hvf)
      #
      # — an auto-detection of an APPLE SDK LIBRARY, with no `FT_REQUIRE_HVF`
      # to make it deterministic the other way. Measured on this machine
      # (macOS 27.2, Xcode SDK): `hvf/Scaler.h` is present, cmake reports
      #
      #   -- Found HVF: Apple platform with clang and HVF SDK
      #
      # and the built library carries it:
      #
      #   /usr/lib/libhvf.dylib (compatibility version 0.0.0)
      #
      # A/B with this flag as the only change: `libhvf.dylib` is GONE from
      # `otool -L`, everything else identical. So without it, the darwin
      # artifact hard-links a system library whose presence depends on the
      # SDK that happened to build it, cannot be declared as a pantry
      # dependency, and would fail to load on a macOS that lacks it.
      # Disabling is the only choice that is both explicit and deliverable.
      "-DFT_DISABLE_HVF=TRUE",
    ]
  }

  script = [
    "cmake .. $ARGS",
    "make --jobs {{ hw.concurrency }} install",
  ]
}

# ⛔ NO `provides`, AND THAT IS A MEASUREMENT. A real `make install` from this
# tree wrote 64 files and NOT ONE of them is under `bin/`: the library, the
# headers under `include/freetype2/`, `lib/pkgconfig/freetype2.pc` and the
# cmake package files. `provides` is the commands a consumer types, and this
# package gives none.
#
# ⭐ Which also retires upstream's other FIXME: "the freetype-config script
# contains fullpaths to libpng / not sure of a portable way to fix that". The
# CMake build — the one this recipe actually uses, and upstream's too — does
# not install `freetype-config` at all, so the defect it worries about cannot
# occur. Checked for the real thing while there: the only installed file
# holding an absolute path is `freetype2.pc`, and the path in it is the install
# prefix, which `{{prefix}}` renders. No build directory leaks into the
# artifact.

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
  }

  script = [
    # ⛔⛔ THE VERSION ASSERTION DOES NOT GO THROUGH pkg-config, AND THAT IS
    # THE TRAP WORTH NAMING. `pkg-config --modversion freetype2` answers
    # **26.7.20** for this release — FreeType's `.pc` carries its libtool
    # interface version, not its release number — so the obvious
    # `pkg-config --modversion freetype2 | grep {{version}}` FAILS on a
    # perfectly good build. Measured, not guessed.
    #
    # `FT_Library_Version` returns the real major/minor/patch, so the fixture
    # below prints `2.15.0` and the next line compares it. That also exercises
    # the library rather than a text file.
    "test \"$(pkg-config --modversion freetype2)\" != \"{{version.raw}}\"",

    # The four REQUIREs, witnessed by what cmake wrote: `Requires.private` is
    # only filled with a library that was actually found.
    "grep -q 'Requires.private:.*zlib' {{prefix}}/lib/pkgconfig/freetype2.pc",
    "grep -q 'Requires.private:.*bzip2' {{prefix}}/lib/pkgconfig/freetype2.pc",
    "grep -q 'Requires.private:.*libpng' {{prefix}}/lib/pkgconfig/freetype2.pc",
    "grep -q 'Requires.private:.*libbrotlidec' {{prefix}}/lib/pkgconfig/freetype2.pc",

    "test -f {{prefix}}/include/freetype2/ft2build.h",

    # ⛔⛔ THE HVF FLAG'S WITNESS, in both directions and on the platform where
    # it can fire. Without `-DFT_DISABLE_HVF=TRUE` the darwin library names
    # `/usr/lib/libhvf.dylib`; with it, it does not. On linux the block is
    # inside `if (APPLE)` so there is nothing to see, and the test says so
    # rather than asserting a vacuous truth.
    "if test \"$(uname)\" = Darwin; then otool -L {{prefix}}/lib/libfreetype.dylib > /tmp/ft-linkage.txt && ! grep -q libhvf /tmp/ft-linkage.txt; else test -f {{prefix}}/lib/libfreetype.so; fi",

    # ⭐ THE ONLY TEST THAT RUNS THE LIBRARY: initialise it, ask it its own
    # version, compare. Upstream's fixture stopped at `FT_Init_FreeType`'s
    # return value; this one also prints the version, which is what makes the
    # pkg-config trap above checkable rather than merely avoided.
    #
    # ⛔ `-Wl,-rpath` IS EXPLICIT, and it is here because I could not run the
    # test without it. Upstream's test line is
    # `cc -o test test.c $(pkg-config --cflags --libs freetype2)`, and on
    # darwin the resulting binary dies with
    #
    #   dyld: Library not loaded: @rpath/libfreetype.6.dylib
    #   Reason: no LC_RPATH's found
    #
    # because the installed dylib's install name is `@rpath/…`. The sandbox's
    # own fixup pass may supply the rpath, but a test that depends on that is a
    # test whose subject is the sandbox. Stating the rpath makes what was run
    # here identical to what ships.
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <ft2build.h>
#include FT_FREETYPE_H

int main(void) {
  FT_Library library;
  if (FT_Init_FreeType(&library) != 0) {
    puts("FT_Init_FreeType failed");
    return 1;
  }

  FT_Int major = 0, minor = 0, patch = 0;
  FT_Library_Version(library, &major, &minor, &patch);
  printf("%d.%d.%d\n", major, minor, patch);

  FT_Done_FreeType(library);
  return 0;
}
EOT
        extname = "c"
      }
      run = "cc -o ftprobe $FIXTURE $(pkg-config --cflags --libs freetype2) -Wl,-rpath,{{prefix}}/lib"
    },
    "test \"$(./ftprobe)\" = {{version.raw}}",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",   # :78-111 the FT_REQUIRE_*/FT_DISABLE_* contract in upstream's own words; :192-232 all nine options, every default OFF; :262 FindPkgConfig; :266-297 harfbuzz — FT_DYNAMIC_HARFBUZZ defaults ON and find_package is never reached; :299-307 PNG, and the ZLIB_FOUND unset that keeps FT_DISABLE_ZLIB honest; :309-316 zlib; :317-328 bzip2 and pkg_check_modules; :330-336 brotli; :338-348 HVF, APPLE-only, check_include_file + find_library with no FT_REQUIRE_HVF; :405,:512 FT_DISABLE_STREAM_SUPPORT
    "LICENSE.TXT",      # "two mutually exclusive open-source licenses … you must choose *one*"; FTL is GPLv3-compatible and GPLv2-incompatible; the BDF/PCF drivers' X11-like licence
    "meson_options.txt", # the meson build's nine options, read as the INDEPENDENT side of the census: `hvf: auto` corroborates CMakeLists.txt:338, and `mmap` exists here while appearing NOWHERE in CMakeLists.txt
    "src/gzip",          # 19 files — the bundled zlib that FT_REQUIRE_ZLIB=TRUE keeps out of the artifact
  ]

  consulted = [
    "https://freetype.org/download.html",                 # publishes NO fingerprint, no key, and nothing about verification
    "https://freetype.org/",                              # news dates 2.15.0 to 2026-10-12, matching the signature
    "https://downloads.sourceforge.net/project/freetype/freetype2/2.15.0/freetype-2.15.0.tar.gz", # the second host, same bytes
    "https://keys.openpgp.org/vks/v1/by-fingerprint/E30674707856409FF1948010BE6C3AAC63AD8E3F",    # 404
    "pkgxdev/pantry projects/freetype.org/package.yml",    # the recipe this replaces, and its two FIXMEs
    "pkgxdev/pantry projects/harfbuzz.org/package.yml",    # :10 freetype.org: 2 — the cycle that forbids declaring harfbuzz here
    "go-zpkg/recipes#31",                           # the fragment's own history: the consumer half of the brotli declaration
    "gnu.org/wget/package.hcl",                            # the switch-census discipline, applied here to CMake options
  ]

  note = <<EOT
Eleventh of the campaign (go-zpkg/packages#440) and the FIRST CMake project
among them. `zpkb closure -build` puts freetype.org in the 70-project build
closure of go-zpkg/base-toolchain.

⭐ THE FRAGMENT WAS ALREADY THE BEST OF THE ELEVEN. go-zpkg/recipes#31
had added `github.com/google/brotli` and all four `-DFT_REQUIRE_*=TRUE` flags
— the owner's « rien d'implicite » applied to CMake months before the rule was
spoken. Everything it did is kept verbatim. What follows is what it did not
reach, which is two switches out of nine.

⭐⭐ WHAT WRITING IT FOUND:

  1. `FT_DISABLE_HVF` — THE ONE REAL DEFECT. New in this line, defaults OFF,
     and `CMakeLists.txt:338-348` then auto-detects an APPLE SDK LIBRARY with
     no `FT_REQUIRE_HVF` available to pin it the other way. Measured: cmake
     says "Found HVF: Apple platform with clang and HVF SDK" and the built
     dylib carries `/usr/lib/libhvf.dylib`. A/B with the flag as the only
     change removes it and changes nothing else. So the darwin artifact has
     been hard-linking a system library chosen by whichever SDK built it,
     undeclarable as a pantry dependency, and unloadable on a macOS without it.

  2. `FT_DYNAMIC_HARFBUZZ` — stated, and the reading that produced it was
     WRONG FIRST. `FT_DISABLE_HARFBUZZ` defaults OFF, so "HarfBuzz is
     auto-detected and undeclared" is what the option list suggests and what I
     was about to write. `:266-297` read in order refutes it:
     `FT_DYNAMIC_HARFBUZZ` defaults ON, and when dlopen exists the
     `find_package(HarfBuzz)` call is never reached. cmake's own output
     confirms it. The flag now states the default rather than depending on it,
     and no harfbuzz dependency is declared because harfbuzz depends on
     freetype (`harfbuzz.org/package.yml:10`) — a cycle, checked rather than
     assumed.

  3. BOTH OF UPSTREAM'S FIXMEs ARE STALE, in opposite ways. The
     `freetype-config` one ("contains fullpaths to libpng") cannot occur in the
     CMake build: no `bin/` is installed at all, which the 64-file manifest
     shows. The URL one ("our linux docker image TLS doesn't like this URL")
     is about a different failure than the one measured today, and the digest
     makes the host's identity irrelevant to correctness.

  4. `pkg-config --modversion freetype2` IS NOT THE VERSION. It answers
     **26.7.20** for 2.15.0 — the libtool interface number. The obvious test
     line fails on a good build, so the version assertion goes through
     `FT_Library_Version` instead.

  5. THE UPSTREAM TEST CANNOT RUN AS WRITTEN on darwin. Its binary dies with
     "no LC_RPATH's found" because the dylib's install name is `@rpath/…`. The
     recipe states `-Wl,-rpath` so that what was executed here is what ships,
     rather than leaning on a sandbox behaviour the test would then be
     measuring.

⛔⛔ AND THE TRUST CHAIN IS A NEW SHAPE, THE WEAKEST OF THE CAMPAIGN. The
tarball is signed (RSA/SHA-512, 2026-10-12, issuer
E30674707856409FF1948010BE6C3AAC63AD8E3F) and the key is not published anywhere
this session could reach: absent from GNU's keyring (correctly — FreeType is a
nongnu project), 404 on keys.openpgp.org, and freetype.org publishes neither a
fingerprint nor a key nor any instruction about verifying a download.
savannah.nongnu.org refused the connection and the release directory listing
timed out three times, so "no KEYS file exists there" is NOT established and is
not claimed.

⛔ The shortcut was available and refused: fetching a key by the fingerprint
taken from the signature's own issuer subpacket would verify BY CONSTRUCTION
and prove nothing about who holds it. gnu.org/wget could do that lookup
honestly because GNU's keyring listed the fingerprint independently first.
Here there is no independent listing, so there is no verification — and saying
so is the only honest option.

⭐ WHAT THE CHAIN DOES HAVE, and it is better than every other recipe's digest
leg: the bytes agree across TWO ORGANISATIONS, Savannah and SourceForge, same
4 262 480 bytes and the same sha256. gnu.org/wget's two readings were both
from ftp.gnu.org. That rules out a single mirror serving something different;
it cannot rule out a compromise upstream of both.

⚠ Recorded because it will matter to the next person who touches this recipe:
`download.savannah.gnu.org` served a 504 for this URL at 08:13 CET, the correct
tarball at 08:18, and then timed out for every request between 08:26 and 08:36,
including for the builder's own fetcher. A `curl -sSLO` without `--fail` wrote
the 504 body to disk under the tarball's name — 188 bytes of nginx HTML that
`tar` then rejected as "Unrecognized archive format". The builder's own fetcher
refuses a body whose magic bytes are wrong, which is why the recipe is safe
where an ad-hoc download was not.
EOT
}
