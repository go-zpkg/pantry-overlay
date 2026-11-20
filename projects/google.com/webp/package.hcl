# google.com/webp — the WebP image codec: libwebp (encode and decode),
# libwebpmux and libwebpdemux (the RIFF container, animation, metadata),
# libsharpyuv, and the cwebp, dwebp, img2webp, webpinfo and webpmux tools.
# Pillow's `webp` feature needs libwebp, libwebpmux AND libwebpdemux together
# (setup.py:868-881), and python-pillow.org (go-zpkg/recipes#122 step 5) is
# why this recipe exists. php.net names it too.
#
# ⛔ WRITTEN FROM LIBWEBP'S OWN FILES (go-zpkg/packages#431), at 1.6.0.
#
# ⭐⭐ WHAT WRITING IT FOUND: the tools' input formats are chosen by what the
# build machine has. cmake/deps.cmake:84-117 runs find_package(PNG), JPEG,
# TIFF and GIF and records whichever answer; CMakeLists.txt:477-483 then turns
# gif2webp and the animation utilities OFF with no message when GIF is absent.
# So the same recipe gives cwebp that reads PNG and JPEG on one builder and
# neither on another. Every one is named below, and the test reads each back
# from a tool that used it.

summary = "WebP image codec: libwebp, libwebpmux, libwebpdemux, libsharpyuv and the cwebp/dwebp tools"

# COPYING:1-30 is the 3-clause BSD text ("Copyright (c) 2010, Google Inc."),
# and PATENTS is a patent grant, not a licence term; nothing else is compiled:
# no file under src/, imageio/, examples/ or sharpyuv/ names another licence
# (searched: Apache, MIT, public domain).
license = "BSD-3-Clause"

versions {
  github = "webmproject/libwebp/tags"
  strip  = ["/^v/"]

  # The tag list carries `webp-rfc9649` and release candidates beside the
  # releases; none of them is a version of the library.
  ignore = [
    "/^webp-/",
    "/rc\\d*$/",
  ]
}

dependencies = {
  # Each is found by find_package with no way to make it fatal: a missing one
  # silently removes cwebp's and dwebp's PNG or JPEG support. They are declared
  # so they are present, and the test proves they were used.
  "libpng.org"        = "^1"
  "libjpeg-turbo.org" = "^3"
}

distributable {
  # The project's own download area, which publishes the tarball and a detached
  # signature beside it for every release.
  url              = "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-{{version.raw}}.tar.gz"
  strip-components = 1

  # 4296070 bytes. ⚠ SIGNED, AND THE SIGNATURE'S KEY IS NOT ANCHORED BY ANYTHING
  # THE PROJECT PUBLISHES: libwebp-1.6.0.tar.gz.asc is made by
  # 6B0E6B70976DE303EDF2F601F9C3D6BDB8232B5D (2025-07-09), but the repository
  # (searched: gpg, pgp, the key id), the download page
  # developers.google.com/speed/webp/download and the release area name no
  # fingerprint, so there is nothing to verify the key against that is not the
  # signature itself. The rung is therefore the digest below, fetched twice from
  # the project's host with identical results.
  sha256 = {
    "1.6.0" = "e4ab7009bf0629fd11982d4c2aa83964cf244cffba7347ecd39019a9e38c4564"
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

      # Shared libraries, which Pillow's `-lwebp -lwebpmux -lwebpdemux` links.
      # CMakeLists.txt:17-23: with this OFF the default is WEBP_LINK_STATIC.
      "-DBUILD_SHARED_LIBS=ON",

      # ⛔⛔ 1. SIMD AND THREADS, NAMED. cmake/cpu.cmake:12-38 compile-tests each
      # instruction set (AVX2, SSE4.1, SSE2, NEON, ...) and records 0 on a
      # failed probe with no error; cmake/deps.cmake:34-44 does the same for
      # pthreads. ON is the default (CMakeLists.txt:31, :45), named so it is
      # stated; the test reads the instruction-set code out of libwebp.
      "-DWEBP_ENABLE_SIMD=ON",
      "-DWEBP_USE_THREAD=ON",

      # ⛔⛔ 2. TIFF REFUSED. cmake/deps.cmake:84-95 find_package(TIFF) would link
      # the builder's libtiff into cwebp. Cycle: libtiff's WebP-compressed TIFF
      # (cmake/WebPCodec.cmake) needs THIS library built first, and that is the
      # one a Pillow user can observe (Pillow reads TIFF through libtiff).
      # cwebp's TIFF INPUT is what is given up, stated here and tested absent.
      "-DCMAKE_DISABLE_FIND_PACKAGE_TIFF=ON",

      # ⛔⛔ 3. GIF REFUSED. giflib is not a recipe of this tree; deps.cmake:97-124
      # would use a builder's. gif2webp and the animation utilities are switched
      # off by name (CMakeLists.txt:477-483 would do it silently) and the
      # find is disabled so nothing links.
      "-DCMAKE_DISABLE_FIND_PACKAGE_GIF=ON",
      "-DWEBP_BUILD_GIF2WEBP=OFF",
      "-DWEBP_BUILD_ANIM_UTILS=OFF",

      # 4. vwebp needs GLUT and OpenGL (CMakeLists.txt:593-611, probed silently);
      # the SDK of a mac has them, a linux builder usually does not. A viewer
      # is not part of the codec: refused. The extras (:643, not installed) are
      # not built either.
      "-DWEBP_BUILD_VWEBP=OFF",
      "-DWEBP_BUILD_EXTRAS=OFF",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# CMakeLists.txt:537, :547, :590, :630, :640: the five installed tools. dwebp
# and cwebp take PNG/JPEG through the libraries declared above.
provides = [
  "bin/cwebp",
  "bin/dwebp",
  "bin/img2webp",
  "bin/webpinfo",
  "bin/webpmux",
]

test {
  fixture = <<EOT
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <webp/encode.h>
#include <webp/decode.h>
#include <webp/mux.h>
#include <webp/demux.h>
#include <webp/sharpyuv/sharpyuv.h>

int main(void)
{
	enum { W = 16, H = 16 };
	uint8_t rgb[W * H * 3];
	for (int i = 0; i < W * H; i++) {
		rgb[3 * i] = (uint8_t)i;
		rgb[3 * i + 1] = (uint8_t)(255 - i);
		rgb[3 * i + 2] = 128;
	}

	/* libwebp: lossless encode and decode must give the pixels back. */
	uint8_t *out = NULL;
	size_t n = WebPEncodeLosslessRGB(rgb, W, H, W * 3, &out);
	if (n == 0) {
		fprintf(stderr, "WebPEncodeLosslessRGB failed\n");
		return 1;
	}
	int w = 0, h = 0;
	uint8_t *back = WebPDecodeRGB(out, n, &w, &h);
	if (!back || w != W || h != H || memcmp(back, rgb, sizeof rgb) != 0) {
		fprintf(stderr, "lossless round trip differs\n");
		return 1;
	}
	WebPFree(back);

	/* libwebpdemux: the container's own view of the file. */
	WebPData data = { out, n };
	WebPDemuxer *dmux = WebPDemux(&data);
	if (!dmux || WebPDemuxGetI(dmux, WEBP_FF_CANVAS_WIDTH) != W ||
	    WebPDemuxGetI(dmux, WEBP_FF_FRAME_COUNT) != 1) {
		fprintf(stderr, "WebPDemux disagrees\n");
		return 1;
	}
	WebPDemuxDelete(dmux);

	/* libwebpmux: attach an ICC chunk and read it back. */
	WebPMux *mux = WebPMuxCreate(&data, 1);
	if (!mux) {
		fprintf(stderr, "WebPMuxCreate failed\n");
		return 1;
	}
	WebPData icc = { (const uint8_t *)"icc!", 4 };
	if (WebPMuxSetChunk(mux, "ICCP", &icc, 1) != WEBP_MUX_OK) {
		fprintf(stderr, "WebPMuxSetChunk failed\n");
		return 1;
	}
	WebPData got;
	if (WebPMuxGetChunk(mux, "ICCP", &got) != WEBP_MUX_OK || got.size != 4) {
		fprintf(stderr, "WebPMuxGetChunk failed\n");
		return 1;
	}
	WebPMuxDelete(mux);
	WebPFree(out);

	/* libsharpyuv, which libwebp's encoder needs. */
	if (SharpYuvGetVersion() <= 0) {
		fprintf(stderr, "no sharpyuv version\n");
		return 1;
	}
	return 0;
}
EOT

  script = [
    "cc -x c $FIXTURE -x none -o webpcheck -I{{prefix}}/include -L{{prefix}}/lib -lwebp -lwebpmux -lwebpdemux -lsharpyuv",
    {
      run = <<EOT
set -eu
LD_LIBRARY_PATH="{{prefix}}/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="{{prefix}}/lib:$${DYLD_LIBRARY_PATH:-}" ./webpcheck
EOT
    },

    # ⛔ THE INPUT FORMATS, READ OFF THE TOOLS THAT USE THEM. A cwebp built with
    # no PNG library still encodes a PPM and passes any test that starts from
    # one, so the PNG and the JPEG are made here and fed back in.
    {
      run = <<EOT
set -eu
echo P6 > in.ppm
echo "2 2" >> in.ppm
echo 255 >> in.ppm
head -c 12 /dev/zero >> in.ppm
"{{prefix}}/bin/cwebp" -quiet in.ppm -o a.webp
"{{prefix}}/bin/webpinfo" a.webp > /dev/null

# PNG out (dwebp's default) and PNG in.
"{{prefix}}/bin/dwebp" -quiet a.webp -o a.png
head -c 4 a.png | grep -q PNG || { echo "dwebp wrote no PNG" >&2; exit 1; }
"{{prefix}}/bin/cwebp" -quiet a.png -o from-png.webp \
  || { echo "cwebp cannot read a PNG" >&2; exit 1; }

# JPEG in, from the libjpeg-turbo this recipe declares.
cjpeg in.ppm > a.jpg
"{{prefix}}/bin/cwebp" -quiet a.jpg -o from-jpg.webp \
  || { echo "cwebp cannot read a JPEG" >&2; exit 1; }

# TIFF in is REFUSED above (a cycle with libtiff): it must fail, loudly.
"{{prefix}}/bin/dwebp" -quiet -tiff a.webp -o a.tif
if "{{prefix}}/bin/cwebp" -quiet a.tif -o from-tif.webp > /dev/null 2>&1; then
  echo "cwebp read a TIFF: a builder's libtiff leaked in" >&2
  exit 1
fi
EOT
    },

    # ⛔ THE SIMD OUTCOME. Every instruction set has a VP8DspInit<ISA> function
    # whether or not it was compiled, so those names prove nothing; the real
    # transforms exist only when the ISA's source file was built (static
    # functions, which a non-stripped library still lists).
    {
      run = <<EOT
set -eu
lib=$(ls "{{prefix}}"/lib/libwebp.so "{{prefix}}"/lib/libwebp.dylib 2>/dev/null | head -n 1)
nm "$lib" > symbols.txt 2>&1
grep -E 'FTransform_(NEON|SSE2)$' symbols.txt > /dev/null \
  || { echo "libwebp was built WITHOUT its SIMD transforms" >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "CMakeLists.txt",   # :17-23 shared/static; :31-47 every option and its default; :103-107 Release default; :110-120 which tools need the image libraries; :477-483 gif2webp and the anim utilities silently OFF without GIF; :537-640 the installed tools; :593-611 vwebp needs GLUT; :643 extras
    "cmake/deps.cmake", # :34-44 pthreads probe; :84-95 PNG, JPEG and TIFF found by find_package; :97-124 GIF
    "cmake/cpu.cmake",  # :12-38 a failed compile probe records the ISA as absent, silently; :41-58 the instruction sets and their flags
    "COPYING",          # the BSD-3-Clause text
    "PATENTS",          # the patent grant, which is not a licence term
  ]

  consulted = [
    # Read for facts only: the project's download area and the five tools.
    "pkgxdev/pantry projects/google.com/webp/package.yml",
    "https://developers.google.com/speed/webp/download",
  ]

  note = <<EOT
⛔⛔ WHICH IMAGE FORMATS THE TOOLS READ DEPENDS ON THE BUILD MACHINE.
cmake/deps.cmake:84-124 probes PNG, JPEG, TIFF and GIF; none can be made
fatal, and CMakeLists.txt:477-483 drops gif2webp and the animation utilities
with no message. PNG and JPEG are declared and the test reads each from cwebp;
TIFF and GIF are refused (find_package disabled by name) and the test checks
that TIFF input fails.

⭐ THE TIFF REFUSAL BREAKS A CYCLE. libtiff reads and writes WebP-compressed
TIFF through libwebp (cmake/WebPCodec.cmake), and libwebp's cwebp reads TIFF
through libtiff. Only one direction can be built first. libwebp goes first,
because the libtiff direction is the one Pillow's TIFF plugin can observe.

⚠ THE SIGNATURE IS NOT ANCHORED. The tarball is signed
(6B0E6B70976DE303EDF2F601F9C3D6BDB8232B5D) but no source the project controls
publishes that fingerprint: not the repository, not the download page, not the
release area. The digest was fetched twice from the same host with identical
results; that is the whole warrant.

⛔ NOT BUILT BY THE FACTORY. Configured, built and installed on darwin/arm64
only, with libpng from Homebrew; the C fixture and the tool checks ran against
that install. The SIMD check reads the NEON transform there; the x86 names
(FTransform_SSE2, src/dsp/enc_sse2.c:436) is read from the source, not observed.
EOT
}
