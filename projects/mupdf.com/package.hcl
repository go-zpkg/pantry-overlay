# mupdf.com — MuPDF, a lightweight PDF, XPS and e-book library with the `mutool`
# command-line tools. This tree carried only a dependency list for it (a fragment,
# go-zpkg/packages#440 step 1); this is the whole recipe.
#
# ⛔ WRITTEN FROM MUPDF'S OWN FILES, at 1.28.6.
#
# ⭐⭐ WHAT WRITING IT FOUND: MuPDF's Makefile PROBES for everything, and on macOS it
# does not probe at all.
#   Makerules:223-243  on Darwin the branch sets no SYS_*_CFLAGS/SYS_*_LIBS for any
#                      library, only HAVE_GLUT := yes (:224) and libcrypto.
#   Makerules:255-351  elsewhere, a silent `pkg-config --exists` for each library
#                      decides HAVE_SYS_*, and a miss falls back to the copy in
#                      thirdparty/ without a word.
#   Makethird:3-20     USE_SYSTEM_<LIB> picks system or bundled per library.
# So the same recipe would link different libraries on two platforms, depending on
# what pkg-config happened to find. This recipe states EVERY choice on the make
# command line (a command-line variable beats the Makefile's assignments, so the
# probes cannot overrule it) and gives each system library its flags by directory.
#
# Every optional library, named:
#   SYSTEM (this tree's recipes, Makethird sections in brackets):
#     freetype.org        USE_SYSTEM_FREETYPE  [:129-136]
#     libjpeg-turbo.org   USE_SYSTEM_LIBJPEG   [:188-195]  (-DSHARE_JPEG, :189)
#     openjpeg.org        USE_SYSTEM_OPENJPEG  [:255-262]
#     zlib.net            USE_SYSTEM_ZLIB      [:229-236]
#     github.com/google/brotli  USE_SYSTEM_BROTLI [:93-101]
#     openssl.org         libcrypto, for the PDF signature (PKCS#7) code
#                         (Makerules:238-240, :346-349; Makefile:113, :332)
#   BUNDLED (thirdparty/, no recipe in this tree; version read from the source):
#     harfbuzz     13.0.1  thirdparty/harfbuzz/src/hb-version.h:63
#     jbig2dec     0.20    thirdparty/jbig2dec/jbig2.h:28-29
#     mujs         1.3.8   thirdparty/mujs/mujs.h:10-12
#     lcms2 (lcms2mt, MuPDF's thread-safe fork)  2.19  thirdparty/lcms2/configure.ac:10
#     gumbo-parser 0.10.1  thirdparty/gumbo-parser/configure.ac:5
#     cmark-gfm    0.29.0.gfm.13  thirdparty/cmark-gfm/CMakeLists.txt:4-8
#     extract      (Artifex's, no version in its files)  thirdparty/extract
#   OFF:
#     tesseract=no, barcode=no (zxing-cpp, zint), archive=no (libarchive; Makerules:93-95
#     makes it fatal when asked for and absent), commercial=no (SmartOffice),
#     X11 and GLUT viewers (HAVE_X11=no, HAVE_GLUT=no: Makefile:388, :397, :407),
#     curl (USE_SYSTEM_CURL=no: only a viewer uses it, Makefile:408), shared=no.
# The fragment's dependencies on harfbuzz.org, jbig2dec.com, mujs.com, info-zip.org/unzip,
# darwin libarchive and the linux X11/GL/glib set are dropped: harfbuzz, jbig2dec and
# mujs are bundled (no recipe provides harfbuzz or jbig2dec here, and MuPDF's own
# comment says a system mujs is "not available", Makethird:11), nothing in the build
# unpacks a zip, and the viewers that needed X11 and GL are off.

summary = "MuPDF: lightweight PDF, XPS and e-book library with the mutool command-line tools"

# COPYING is the GNU Affero General Public License version 3; the source headers
# (include/mupdf/fitz.h:8, source/fitz/context.c:8) say "any later version".
license = "AGPL-3.0-or-later"

versions {
  github = "ArtifexSoftware/mupdf"
}

dependencies = {
  "freetype.org"             = "^2"
  "github.com/google/brotli" = "^1"
  "libjpeg-turbo.org"        = "*"
  "openjpeg.org"             = "^2"
  "openssl.org"              = "^3"
  "zlib.net"                 = "^1"
}

distributable {
  # 68924915 bytes: the release tarball, which carries thirdparty/. No signature is
  # published. Three agreeing witnesses of the digest: the project's releases page
  # (mupdf.com/releases), Homebrew's formula API (formulae.brew.sh, stable 1.28.6),
  # and the SHA-256 computed on two fetches of the URL below.
  url              = "https://mupdf.com/downloads/archive/mupdf-{{version.raw}}-source.tar.gz"
  strip-components = 1

  sha256 = {
    "1.28.6" = "dc85000640a45d90ca9b77b061f6ca67cce0c4d4fbecf8819647baf573eef101"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  script = [
    <<EOT
set -eu
FT="{{deps.freetype.org.prefix}}"
JP="{{deps.libjpeg-turbo.org.prefix}}"
OJ="{{deps.openjpeg.org.prefix}}"
ZL="{{deps.zlib.net.prefix}}"
BR="{{deps.github.com/google/brotli.prefix}}"
SSL="{{deps.openssl.org.prefix}}"
OJINC="$(ls -d "$OJ"/include/openjpeg-*)"
# One argument list for BOTH make runs: install-libs depends on `libs`, so an install
# run with fewer variables would silently rebuild with the Makefile's probing defaults.
set -- prefix="{{prefix}}" build=release shared=no \
  USE_SYSTEM_LIBS=no \
  USE_SYSTEM_FREETYPE=yes USE_SYSTEM_LIBJPEG=yes USE_SYSTEM_OPENJPEG=yes \
  USE_SYSTEM_ZLIB=yes USE_SYSTEM_BROTLI=yes \
  USE_SYSTEM_HARFBUZZ=no USE_SYSTEM_JBIG2DEC=no USE_SYSTEM_MUJS=no \
  USE_SYSTEM_LCMS2=no USE_SYSTEM_GUMBO=no USE_SYSTEM_CMARK_GFM=no \
  USE_SYSTEM_CURL=no USE_SYSTEM_GLUT=no USE_SYSTEM_LEPTONICA=no \
  USE_SYSTEM_TESSERACT=no USE_SYSTEM_ZXINGCPP=no \
  tesseract=no barcode=no archive=no commercial=no \
  HAVE_X11=no HAVE_GLUT=no \
  "SYS_FREETYPE_CFLAGS=-I$FT/include/freetype2" \
  "SYS_FREETYPE_LIBS=-L$FT/lib -Wl,-rpath,$FT/lib -lfreetype" \
  "SYS_LIBJPEG_CFLAGS=-I$JP/include" \
  "SYS_LIBJPEG_LIBS=-L$JP/lib -Wl,-rpath,$JP/lib -ljpeg" \
  "SYS_OPENJPEG_CFLAGS=-I$OJINC" \
  "SYS_OPENJPEG_LIBS=-L$OJ/lib -Wl,-rpath,$OJ/lib -lopenjp2" \
  "SYS_ZLIB_CFLAGS=-I$ZL/include" \
  "SYS_ZLIB_LIBS=-L$ZL/lib -Wl,-rpath,$ZL/lib -lz" \
  "SYS_BROTLI_CFLAGS=-I$BR/include" \
  "SYS_BROTLI_LIBS=-L$BR/lib -Wl,-rpath,$BR/lib -lbrotlidec -lbrotlienc -lbrotlicommon" \
  HAVE_LIBCRYPTO=yes \
  "LIBCRYPTO_CFLAGS=-I$SSL/include -DHAVE_LIBCRYPTO" \
  "LIBCRYPTO_LIBS=-L$SSL/lib -Wl,-rpath,$SSL/lib -lcrypto"
make -j {{ hw.concurrency }} "$@" libs tools
make "$@" install-libs install-tools install-docs
EOT
    ,
  ]
}

provides = [
  "bin/mutool",
]

test {
  script = [
    {
      run = <<EOT
set -eu
"{{prefix}}/bin/mutool" -v > version.txt 2>&1 || true
grep -q '{{version.raw}}' version.txt
printf '%%%%MediaBox 0 0 200 200\n%%%%Page\n1 0 0 rg 20 20 100 100 re f\n' > page.txt
"{{prefix}}/bin/mutool" create -o t.pdf page.txt
"{{prefix}}/bin/mutool" info t.pdf > info.txt 2>&1
grep -q 'Pages: 1' info.txt
"{{prefix}}/bin/mutool" draw -o t.png t.pdf
test -s t.png
"{{prefix}}/bin/mutool" draw -F txt -o t.txt t.pdf
test -f t.txt
EOT
    },
  ]
}

provenance {
  read = [
    "Makefile",   # :113 :332 LIBCRYPTO, :365-375 the tools, :388 :397 :407 :408 the viewers, :463-523 prefix and install targets
    "Makerules",  # :14-101 the feature switches, :223-243 Darwin, :255-351 the probes, :238-240 :346-349 libcrypto
    "Makethird",  # :3-20 USE_SYSTEM_*, :93-262 each library's system/bundled branch, :281-285 curl, :354-358 extract
    "COPYING",    # :1-2 GNU Affero General Public License version 3
    "include/mupdf/fitz.h",  # :8 "any later version"
    "thirdparty/harfbuzz/src/hb-version.h",  # :63
    "thirdparty/jbig2dec/jbig2.h",           # :28-29
    "thirdparty/mujs/mujs.h",                # :10-12
    "thirdparty/lcms2/configure.ac",         # :10
    "thirdparty/gumbo-parser/configure.ac",  # :5
    "thirdparty/cmark-gfm/CMakeLists.txt",   # :4-8
  ]

  consulted = []

  note = <<EOT
NO SIGNATURE: none is published. The pin dc850006... is the digest on the project's
releases page, on Homebrew's formula API, and computed on two fetches.

The bundled libraries (harfbuzz 13.0.1, jbig2dec 0.20, mujs 1.3.8, lcms2mt 2.19,
gumbo-parser 0.10.1, cmark-gfm 0.29.0.gfm.13, Artifex's extract) are the copies
inside the release tarball; none has a recipe in this tree to depend on.

BUILT AND TESTED ON A MACHINE, NOT BY THE FACTORY: this make command, darwin/arm64,
with Homebrew's freetype, jpeg-turbo, openjpeg, brotli and openssl 3 by directory
and the macOS SDK's zlib. `mutool -v` printed 1.28.6; otool -L shows libbrotli*,
libfreetype, libjpeg, libz, libopenjp2 and libcrypto; `mutool create`, `info` and
`draw` (png and txt) ran on a one-page file. The first link failed for want of
-lbrotlienc, which is why SYS_BROTLI_LIBS names it.

⛔ NOT BUILT BY THE FACTORY, NOT BUILT ON LINUX.
EOT
}
