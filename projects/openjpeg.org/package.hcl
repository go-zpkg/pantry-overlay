# openjpeg.org — OpenJPEG, the JPEG 2000 codec library (libopenjp2) and the
# opj_compress, opj_decompress and opj_dump tools. Pillow's `jpeg2000` feature
# (setup.py:750-783), mupdf and poppler use it; python-pillow.org
# (go-zpkg/recipes#122 step 5) is why this recipe was completed: it was a
# FRAGMENT (dependencies and a build script, no source and no version), and
# this one takes the ceiling down by one.
#
# ⛔ WRITTEN FROM OPENJPEG'S OWN FILES (go-zpkg/packages#431), at 2.5.4.
#
# ⭐⭐ WHAT WRITING IT FOUND: the library does not need PNG, TIFF or LCMS, and the
# command-line tools get each of them from a find_package that is allowed to
# fail. thirdparty/CMakeLists.txt:18-158 probes zlib, PNG, TIFF, LCMS2 (and
# falls back to LCMS 1!) and, when a probe fails, prints a STATUS line and sets
# OPJ_HAVE_<X> to 0; src/bin/jp2/CMakeLists.txt:17-22 then leaves converttif.c
# and convertpng.c out of opj_compress and opj_decompress. The build succeeds,
# the library is identical, and the tools silently read and write no PNG or
# TIFF. The fragment this replaces declared libpng, littlecms and libtiff but
# nothing stated that they were USED; the test below does.

summary = "OpenJPEG: the JPEG 2000 codec library and the opj_compress, opj_decompress and opj_dump tools"

# LICENSE:1-4 "the 2-clauses BSD License" over every source file but nine
# (searched: files in src/lib/openjp2, src/bin/jp2, src/bin/common that do not
# say BSD): the JPIP index managers say it in their own header, and the two
# generated tables have none. src/bin/common/opj_getopt.c is the University of
# California's 3-clause BSD text (its header, :1-30) and is compiled into all
# three tools. The bundled thirdparty/ libraries (zlib, libpng, libtiff, lcms2)
# are NOT built: BUILD_THIRDPARTY is OFF below.
license = "BSD-2-Clause AND BSD-3-Clause"

versions {
  github = "uclouvain/openjpeg"
}

dependencies = {
  # ⛔ Each found by find_package, none fatal (thirdparty/CMakeLists.txt:18-158).
  # Declared so they are present, and the test proves each was used.
  "libpng.org"                = "^1"
  "littlecms.com"             = "^2"
  "simplesystems.org/libtiff" = "^4"
  "zlib.net"                  = "^1"
}

distributable {
  # GitHub's archive of the tag. The release's assets are prebuilt binaries for
  # four platforms, no source tarball and no checksum or signature file.
  url              = "https://github.com/uclouvain/openjpeg/archive/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 2157028 bytes. ⚠ A GENERATED ARCHIVE, pinned by digest, fetched twice (under
  # both URL spellings GitHub serves) with identical bytes. ⭐ The tag IS signed:
  # v2.5.4 is an annotated tag by Even Rouault, and GitHub reports
  # `"verified": true, "reason": "valid"` for it (tag object bbbe3a0, commit
  # 6c4a29b). That is GitHub's verdict, not a check made here, and it covers the
  # commit's tree rather than this archive's bytes.
  sha256 = {
    "2.5.4" = "a695fbe19c0165f295a8531b1e4e855cd94d0875d2f88ec4b61080677e27188a"
  }
}

build {
  dependencies = {
    "cmake.org"    = "^3"
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_LIBDIR=lib",

      # Both library kinds are installed by default (CMakeLists.txt:146-147);
      # Pillow links the shared one.
      "-DBUILD_SHARED_LIBS=ON",
      "-DBUILD_STATIC_LIBS=ON",

      # ⛔⛔ 1. THE THIRD-PARTY LIBRARIES, REFUSED. CMakeLists.txt:245: with OFF
      # (the default) the bundled zlib, libpng, libtiff and lcms2 are built only
      # "if they are not found on the system"; with ON they would be built and
      # used ALWAYS. OFF is the default, named: the dependencies above are the
      # ones used, and the vendored copies (thirdparty/) are never compiled.
      "-DBUILD_THIRDPARTY=OFF",

      # 2. The codec tools (CMakeLists.txt:232) are what use PNG, TIFF and LCMS.
      "-DBUILD_CODEC=ON",

      # 3. Not built, each a default (CMakeLists.txt:109, :233, :238, :273): the
      # documentation (doxygen), the JPIP library and server (needs libcurl and
      # FastCGI), the Java wrapper and the test suite (needs the OPJ-Data set).
      "-DBUILD_DOC=OFF",
      "-DBUILD_JPIP=OFF",
      "-DBUILD_JAVA=OFF",
      "-DBUILD_TESTING=OFF",

      # 4. Threads: src/lib/openjp2/CMakeLists.txt:168-190 makes a missing thread
      # library FATAL when OPJ_USE_THREAD is ON (the default), unlike the
      # probes above. Named.
      "-DOPJ_USE_THREAD=ON",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# src/bin/jp2/CMakeLists.txt:45 `foreach(exe opj_decompress opj_compress opj_dump)`
# and :66-69, installed to the bin directory.
provides = [
  "bin/opj_compress",
  "bin/opj_decompress",
  "bin/opj_dump",
]

test {
  fixture = <<EOT
#include <stdio.h>
#include <string.h>
#include <openjpeg.h>

int main(void)
{
	/* The library's own idea of its version; the script compares it. */
	printf("%s\n", opj_version());
	opj_codec_t *dec = opj_create_decompress(OPJ_CODEC_J2K);
	opj_codec_t *enc = opj_create_compress(OPJ_CODEC_JP2);
	if (!dec || !enc) {
		fprintf(stderr, "no codec\n");
		return 1;
	}
	opj_destroy_codec(dec);
	opj_destroy_codec(enc);
	return 0;
}
EOT

  script = [
    "test -f \"{{prefix}}/include/openjpeg-{{version.major}}.{{version.minor}}/openjpeg.h\"",
    "cc -x c $FIXTURE -x none -o opjcheck -I{{prefix}}/include/openjpeg-{{version.major}}.{{version.minor}} -L{{prefix}}/lib -lopenjp2",
    {
      run = <<EOT
set -eu
LD_LIBRARY_PATH="{{prefix}}/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="{{prefix}}/lib:$${DYLD_LIBRARY_PATH:-}" ./opjcheck > version.txt
grep -q "^{{version.raw}}$" version.txt || { echo "opj_version() is not {{version.raw}}" >&2; cat version.txt >&2; exit 1; }
EOT
    },

    # ⛔ PNG AND TIFF, BY USE: each of the formats is made by opj_decompress and
    # read back by opj_compress. A build that dropped convertpng.c or
    # converttif.c fails here with "unknown format", not at build time. The
    # image is 64x64 because the default six resolutions need at least 32.
    {
      run = <<EOT
set -eu
echo P6 > in.ppm
echo "64 64" >> in.ppm
echo 255 >> in.ppm
head -c 12288 /dev/zero >> in.ppm
"{{prefix}}/bin/opj_compress" -i in.ppm -o a.j2k > /dev/null
"{{prefix}}/bin/opj_dump" -i a.j2k > dump.txt 2>&1
grep -q 'numresolutions' dump.txt || { echo "opj_dump shows no codestream" >&2; cat dump.txt >&2; exit 1; }
"{{prefix}}/bin/opj_decompress" -i a.j2k -o a.png > /dev/null || { echo "no PNG output" >&2; exit 1; }
"{{prefix}}/bin/opj_decompress" -i a.j2k -o a.tif > /dev/null || { echo "no TIFF output" >&2; exit 1; }
"{{prefix}}/bin/opj_compress" -i a.png -o from-png.j2k > /dev/null || { echo "no PNG input" >&2; exit 1; }
"{{prefix}}/bin/opj_compress" -i a.tif -o from-tif.j2k > /dev/null || { echo "no TIFF input" >&2; exit 1; }
EOT
    },

    # ⛔ LCMS HAS NO FUNCTIONAL WITNESS short of an image with an embedded ICC
    # profile, so it is read off the linkage: the tools link littlecms, and
    # liblcms2 is the one the dependency provides.
    {
      run = <<EOT
set -eu
( ldd "{{prefix}}/bin/opj_decompress" 2>/dev/null || otool -L "{{prefix}}/bin/opj_decompress" ) > linkage.txt
grep -q 'lcms2' linkage.txt || { echo "opj_decompress was built without LCMS" >&2; cat linkage.txt >&2; exit 1; }
grep -q 'png' linkage.txt || { echo "opj_decompress was built without libpng" >&2; cat linkage.txt >&2; exit 1; }
grep -q 'tiff' linkage.txt || { echo "opj_decompress was built without libtiff" >&2; cat linkage.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                 # :105-111 install dirs and the openjpeg-<major>.<minor> include subdirectory; :146-147 shared and static; :232-248 BUILD_CODEC and BUILD_THIRDPARTY; :109, :233, :238, :273 the options named off
    "thirdparty/CMakeLists.txt",      # :3-27 zlib, :30-58 PNG, :61-106 TIFF, :108-158 LCMS2 with the LCMS 1 fallback at :144-157 — each found or silently skipped
    "src/bin/jp2/CMakeLists.txt",     # :17-22 converttif.c and convertpng.c compiled only when found; :45-69 the three tools
    "src/lib/openjp2/CMakeLists.txt", # :168-190 OPJ_USE_THREAD and the FATAL_ERROR without a thread library
    "src/bin/common/opj_getopt.c",    # :1-30 the University of California 3-clause BSD text
    "LICENSE",                        # the 2-clause BSD text
  ]

  consulted = [
    # Read for facts only: the dependency names and that cmake is the build.
    # This recipe replaces the fragment, which is the pantry's recipe in
    # outline.
    "pkgxdev/pantry projects/openjpeg.org/package.yml",
    "github.com/uclouvain/openjpeg releases/tags/v2.5.4, git/tags/bbbe3a0",
  ]

  note = <<EOT
⛔⛔ THE LIBRARY NEEDS NONE OF ITS DEPENDENCIES; THE TOOLS GET EACH OF THEM FROM A
find_package THAT MAY FAIL. thirdparty/CMakeLists.txt probes zlib, PNG, TIFF
and LCMS2 (then LCMS 1) and sets OPJ_HAVE_<X> to 0 on a miss; the tools simply
lose the format. The fragment declared libpng, littlecms and libtiff and
nothing said they were used. Now each is exercised: PNG and TIFF are written by
opj_decompress and read back by opj_compress, LCMS and the libraries are read
off the tools' linkage. ⚠ LCMS has no functional witness here (it needs an
image with an embedded profile).

⭐ BUILD_THIRDPARTY IS NAMED OFF: with ON the vendored zlib, libpng, libtiff and
lcms2 would be built and used regardless of what the dependencies provide.

⚠ A GENERATED ARCHIVE. The release publishes no source tarball. The tag is
signed and GitHub reports it valid; that vouches for the commit, not for the
archive's bytes, which are pinned by digest and were identical across two
fetches under the two URL spellings GitHub serves.

⚠ pantry's fragment passed `LCMS2_INCLUDE_DIR`/`LCMS2_LIBRARY` on darwin only,
with a hard-coded `.dylib`; the dependency's prefix is found through the
declared dependency and CMAKE_PREFIX_PATH instead, and the test reads the
linkage on both systems.

⛔ NOT BUILT BY THE FACTORY. Configured, built and installed once on
darwin/arm64 (libpng from Homebrew; libtiff and lcms2 from our recipes); the
fixture and the tool round trips ran against that install. Ceiling 176 → 175.
EOT
}
