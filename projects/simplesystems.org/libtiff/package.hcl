# simplesystems.org/libtiff — the TIFF library and its command-line tools
# (tiffinfo, tiffcp, tiff2pdf, ...). Pillow's `tiff` feature (setup.py:793-801)
# and openjpeg's opj_compress/opj_decompress use it, and
# python-pillow.org (go-zpkg/recipes#122 step 5) is why this recipe exists.
#
# ⛔ WRITTEN FROM LIBTIFF'S OWN FILES (go-zpkg/packages#431), at 4.7.2.
#
# ⭐⭐ WHAT WRITING IT FOUND: EVERY COMPRESSION CODEC THAT NEEDS ANOTHER LIBRARY
# IS DECIDED BY THE BUILD MACHINE, AND SILENTLY. cmake/DeflateCodec.cmake:30,
# JPEGCodec.cmake:82, LZMACodec.cmake:31, WebPCodec.cmake:31, ZSTDCodec.cmake:60,
# JBIGCodec.cmake:42 and LERCCodec.cmake:30 are each
# `option(<codec> "…" ${<CODEC>_FOUND})`: the default is whatever
# find_package found, and ON cannot force it — `if(zlib AND ZLIB_FOUND)`. A
# TIFF written with a codec the reader lacks is unreadable, so which codecs a
# libtiff has is a property of the file format a user can hit. Every codec is
# named below, and the test asks TIFFIsCODECConfigured() for all of them and
# writes and reads back eight.

summary = "libtiff: the TIFF library and tools, with every compression codec named"

# LICENSE.md:1-22 is the libtiff licence (SPDX `libtiff`); :24-47 licenses
# tif_lzw.c separately, as the Berkeley "compress" notice with its
# advertising-acknowledgement clause (no SPDX identifier). port/getopt.c is
# compiled only where the C library has no getopt, which none of our targets
# lack.
license = "libtiff AND LicenseRef-libtiff-lzw-berkeley"

versions {
  url   = "https://download.osgeo.org/libtiff/"
  match = "/tiff-\\d+\\.\\d+\\.\\d+\\.tar\\.gz/"
  strip = ["/tiff-/", "/\\.tar\\.gz/"]
}

dependencies = {
  # Named per codec below; each is found by find_package and none can be made
  # fatal, so the test is what refuses a build that lost one.
  "zlib.net"          = "^1"
  "libjpeg-turbo.org" = "^3"
  "google.com/webp"   = "^1"
  "tukaani.org/xz"    = "^5"
  "facebook.com/zstd" = "^1"
}

distributable {
  url              = "https://download.osgeo.org/libtiff/tiff-{{version.raw}}.tar.gz"
  strip-components = 1

  # 4083368 bytes. ⚠ SIGNED, AND THE KEY IS NOT ANCHORED BY ANYTHING THE PROJECT
  # PUBLISHES. tiff-4.7.2.tar.gz.sig is made by
  # B1FA7D81EEB8E66399178B9733EBBFC47B3DD87D (2026-07-03) — the same key
  # (Even Rouault) that GitHub reports as valid on OpenJPEG's signed v2.5.4 tag
  # — but the repository (searched: gpg, pgp, both key ids), libtiff.gitlab.io
  # and the download area name no fingerprint, so there is nothing the project
  # controls to verify the key against. The rung is the digest, fetched twice
  # from download.osgeo.org with identical results (the same host: it is the
  # only one that serves 4.7.2).
  sha256 = {
    "4.7.2" = "672bd7d10aee4606171afb864f3570b83340f6a33e2c186dc0512f7145ffdf6a"
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
      "-DBUILD_SHARED_LIBS=ON",

      # ⛔⛔ 1. EVERY CODEC, NAMED. Each can only be turned OFF by its option; ON
      # means "use it if found". The declared dependencies make "found" true,
      # and the test proves it.
      "-Dzlib=ON", # DeflateCodec.cmake:30; ZIP, and PixarLog below, need it
      "-Dpixarlog=ON", # PixarLogCodec.cmake:30
      "-Djpeg=ON", # JPEGCodec.cmake:82
      "-Dold-jpeg=ON", # JPEGCodec.cmake:89, read-only
      "-Dlzma=ON", # LZMACodec.cmake:31
      "-Dzstd=ON", # ZSTDCodec.cmake:60
      "-Dwebp=ON", # WebPCodec.cmake:31 — libwebp is built FIRST (see google.com/webp)

      # ⛔⛔ 2. REFUSED, with the reason each. No recipe of this tree provides them,
      # and a builder that has them must not leak them in.
      "-Dlibdeflate=OFF", # DeflateCodec.cmake:39: only a faster path to the same Deflate, still needs zlib
      "-Djbig=OFF", # JBIGCodec.cmake:42: ISO JBIG needs jbigkit
      "-Dlerc=OFF", # LERCCodec.cmake:30: needs the LERC library

      # ⛔⛔ 3. 12-BIT JPEG is NOT an option here: JPEGCodec.cmake:94-127 detects
      # libjpeg-turbo >= 3.0's dual 8/12 mode on its own. It is on because
      # libjpeg-turbo.org is 3.x, and the test writes a 12-bit JPEG TIFF.

      # 4. What the artifact must not depend on the builder for. Documentation
      # (cmake/Sphinx.cmake:37 probes for Python and Sphinx), the test suite and
      # contrib programs are not installed contents; tiffgt (tools/, needs
      # OpenGL and GLUT, cmake/OpenGLChecks.cmake:29-30) would appear only on a
      # builder that has them.
      "-Dtiff-docs=OFF",
      "-Dtiff-tests=OFF",
      "-Dtiff-contrib=OFF",
      "-DCMAKE_DISABLE_FIND_PACKAGE_OpenGL=ON",
      "-DCMAKE_DISABLE_FIND_PACKAGE_GLUT=ON",

      # 5. Kept at their defaults and named: the tools (CMakeLists.txt:65), and
      # the C++ stream API libtiffxx (cmake/CXXLibrary.cmake:27).
      "-Dtiff-tools=ON",
      "-Dtiff-cxx=ON",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# tools/CMakeLists.txt, read off an install: eighteen programs. rgb2ycbcr and
# thumbnail are in tools/ but are test programs and are not installed; tiffgt
# needs OpenGL and is refused above.
provides = [
  "bin/fax2ps",
  "bin/fax2tiff",
  "bin/pal2rgb",
  "bin/ppm2tiff",
  "bin/raw2tiff",
  "bin/tiff2bw",
  "bin/tiff2pdf",
  "bin/tiff2ps",
  "bin/tiff2rgba",
  "bin/tiffcmp",
  "bin/tiffcp",
  "bin/tiffcrop",
  "bin/tiffdither",
  "bin/tiffdump",
  "bin/tiffinfo",
  "bin/tiffmedian",
  "bin/tiffset",
  "bin/tiffsplit",
]

test {
  fixture = <<EOT
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <tiffio.h>

#define W 32
#define H 32

struct codec {
	const char *name;
	uint16_t id;
	int want; /* 1: configured here, 0: refused by the recipe */
	int lossless;
};

static const struct codec codecs[] = {
	{"none", COMPRESSION_NONE, 1, 1},
	{"ccitt-g4", COMPRESSION_CCITTFAX4, 1, 0},
	{"lzw", COMPRESSION_LZW, 1, 1},
	{"packbits", COMPRESSION_PACKBITS, 1, 1},
	{"thunderscan", COMPRESSION_THUNDERSCAN, 1, 0},
	{"next", COMPRESSION_NEXT, 1, 0},
	{"sgilog", COMPRESSION_SGILOG, 1, 0},
	{"old-jpeg", COMPRESSION_OJPEG, 1, 0},
	{"jpeg", COMPRESSION_JPEG, 1, 0},
	{"deflate", COMPRESSION_ADOBE_DEFLATE, 1, 1},
	{"pixarlog", COMPRESSION_PIXARLOG, 1, 0},
	{"lzma", COMPRESSION_LZMA, 1, 1},
	{"zstd", COMPRESSION_ZSTD, 1, 1},
	{"webp", COMPRESSION_WEBP, 1, 1},
	/* refused: no jbigkit / no LERC recipe in this tree */
	{"jbig", COMPRESSION_JBIG, 0, 0},
	{"lerc", COMPRESSION_LERC, 0, 0},
};

static int roundtrip(const struct codec *c)
{
	uint8_t row[W * 3], back[W * 3];
	char path[64];
	snprintf(path, sizeof path, "rt-%s.tif", c->name);
	TIFF *t = TIFFOpen(path, "w");
	if (!t)
		return 1;
	TIFFSetField(t, TIFFTAG_IMAGEWIDTH, W);
	TIFFSetField(t, TIFFTAG_IMAGELENGTH, H);
	TIFFSetField(t, TIFFTAG_SAMPLESPERPIXEL, 3);
	TIFFSetField(t, TIFFTAG_BITSPERSAMPLE, 8);
	TIFFSetField(t, TIFFTAG_PLANARCONFIG, PLANARCONFIG_CONTIG);
	TIFFSetField(t, TIFFTAG_PHOTOMETRIC, PHOTOMETRIC_RGB);
	TIFFSetField(t, TIFFTAG_COMPRESSION, c->id);
	if (c->id == COMPRESSION_WEBP)
		TIFFSetField(t, TIFFTAG_WEBP_LOSSLESS, 1);
	TIFFSetField(t, TIFFTAG_ROWSPERSTRIP, H);
	for (int y = 0; y < H; y++) {
		for (int x = 0; x < W; x++) {
			row[3 * x] = (uint8_t)(x * 8);
			row[3 * x + 1] = (uint8_t)(y * 8);
			row[3 * x + 2] = 77;
		}
		if (TIFFWriteScanline(t, row, y, 0) < 0) {
			fprintf(stderr, "%s: write failed\n", c->name);
			return 1;
		}
	}
	TIFFClose(t);

	t = TIFFOpen(path, "r");
	if (!t)
		return 1;
	uint16_t comp = 0;
	TIFFGetField(t, TIFFTAG_COMPRESSION, &comp);
	if (comp != c->id) {
		fprintf(stderr, "%s: stored as %u\n", c->name, comp);
		return 1;
	}
	for (int y = 0; y < H; y++) {
		if (TIFFReadScanline(t, back, y, 0) < 0) {
			fprintf(stderr, "%s: read failed at row %d\n", c->name, y);
			return 1;
		}
		if (c->lossless) {
			for (int x = 0; x < W; x++)
				if (back[3 * x] != (uint8_t)(x * 8) ||
				    back[3 * x + 1] != (uint8_t)(y * 8) || back[3 * x + 2] != 77) {
					fprintf(stderr, "%s: pixels differ\n", c->name);
					return 1;
				}
		}
	}
	TIFFClose(t);
	return 0;
}

/* 12-bit JPEG in a TIFF: needs libjpeg-turbo's 8/12 dual mode, which the
 * build probes for (cmake/JPEGCodec.cmake:94-127) and silently does without. */
static int jpeg12(void)
{
	uint16_t row[W], back[W];
	TIFF *t = TIFFOpen("rt-jpeg12.tif", "w");
	if (!t)
		return 1;
	TIFFSetField(t, TIFFTAG_IMAGEWIDTH, W);
	TIFFSetField(t, TIFFTAG_IMAGELENGTH, H);
	TIFFSetField(t, TIFFTAG_SAMPLESPERPIXEL, 1);
	TIFFSetField(t, TIFFTAG_BITSPERSAMPLE, 12);
	TIFFSetField(t, TIFFTAG_PLANARCONFIG, PLANARCONFIG_CONTIG);
	TIFFSetField(t, TIFFTAG_PHOTOMETRIC, PHOTOMETRIC_MINISBLACK);
	TIFFSetField(t, TIFFTAG_COMPRESSION, COMPRESSION_JPEG);
	TIFFSetField(t, TIFFTAG_ROWSPERSTRIP, H);
	for (int y = 0; y < H; y++) {
		for (int x = 0; x < W; x++)
			row[x] = (uint16_t)(x * 100);
		if (TIFFWriteScanline(t, row, y, 0) < 0) {
			fprintf(stderr, "12-bit JPEG: write failed\n");
			return 1;
		}
	}
	TIFFClose(t);
	t = TIFFOpen("rt-jpeg12.tif", "r");
	if (!t)
		return 1;
	for (int y = 0; y < H; y++)
		if (TIFFReadScanline(t, back, y, 0) < 0) {
			fprintf(stderr, "12-bit JPEG: read failed\n");
			return 1;
		}
	TIFFClose(t);
	return 0;
}

int main(void)
{
	int bad = 0;
	if (jpeg12())
		bad = 1;
	for (size_t i = 0; i < sizeof codecs / sizeof codecs[0]; i++) {
		const struct codec *c = &codecs[i];
		int have = TIFFIsCODECConfigured(c->id) ? 1 : 0;
		if (have != c->want) {
			fprintf(stderr, "%s: configured=%d, want %d\n", c->name, have, c->want);
			bad = 1;
		}
	}
	/* The codecs that write need a real round trip; old-jpeg is read-only,
	 * ccitt-g4 and the 1-bit/log codecs need other pixel layouts. */
	static const uint16_t rt[] = {
		COMPRESSION_NONE, COMPRESSION_LZW, COMPRESSION_PACKBITS, COMPRESSION_JPEG,
		COMPRESSION_ADOBE_DEFLATE, COMPRESSION_LZMA, COMPRESSION_ZSTD, COMPRESSION_WEBP,
	};
	for (size_t i = 0; i < sizeof rt / sizeof rt[0]; i++)
		for (size_t j = 0; j < sizeof codecs / sizeof codecs[0]; j++)
			if (codecs[j].id == rt[i] && roundtrip(&codecs[j]))
				bad = 1;
	return bad;
}
EOT

  script = [
    "cc -x c $FIXTURE -x none -o tiffcheck -I{{prefix}}/include -L{{prefix}}/lib -ltiff",
    {
      run = <<EOT
set -eu
LD_LIBRARY_PATH="{{prefix}}/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="{{prefix}}/lib:$${DYLD_LIBRARY_PATH:-}" ./tiffcheck
EOT
    },

    # The tools read what the library wrote: tiffinfo names the compression.
    {
      run = <<EOT
set -eu
"{{prefix}}/bin/tiffinfo" rt-deflate.tif > info.txt
grep -q 'Compression Scheme: AdobeDeflate' info.txt
"{{prefix}}/bin/tiffinfo" rt-webp.tif > info-webp.txt
grep -q 'Compression Scheme: WEBP' info-webp.txt
EOT
    },
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                  # :55-80 the shared/static, tools, tests, contrib, docs options; :126-147 the codec modules in order
    "cmake/DeflateCodec.cmake",        # :28-45 zlib and libdeflate, `option(… ${FOUND})`
    "cmake/JPEGCodec.cmake",           # :26-127 libjpeg-turbo found by CONFIG first, old-jpeg, and the 8/12 dual-mode probe
    "cmake/LZMACodec.cmake",           # :28-33
    "cmake/ZSTDCodec.cmake",           # :28-63
    "cmake/WebPCodec.cmake",           # :27-34
    "cmake/JBIGCodec.cmake",           # :28-45
    "cmake/LERCCodec.cmake",           # :27-32, which also requires ZIP support
    "cmake/PixarLogCodec.cmake",       # :29-32
    "cmake/InternalCodecs.cmake",      # :27-46 the seven built-in codecs, all ON
    "cmake/OpenGLChecks.cmake",        # :29-49 the tiffgt probe
    "cmake/Sphinx.cmake",              # :37 the documentation probe
    "LICENSE.md",                      # the libtiff licence and the tif_lzw.c notice
  ]

  consulted = [
    # Read for facts only: the download area and that the build is cmake.
    "pkgxdev/pantry projects/simplesystems.org/libtiff/package.yml",
  ]

  note = <<EOT
⛔⛔ SEVEN CODECS ARE DECIDED BY THE BUILD MACHINE. Each is
`option(<codec> "…" $${<CODEC>_FOUND})`, which turns a codec OFF but cannot turn
it ON: a missing zlib, libjpeg, liblzma, libzstd or libwebp drops that
compression from the library with no error. Declared dependencies make them
present; the test asks TIFFIsCODECConfigured() for sixteen codecs, writes and
reads back eight, and reads a 12-bit JPEG — which only libjpeg-turbo >= 3.0's
dual mode (JPEGCodec.cmake:94-127, an auto-detection) can do.

⭐ REFUSED, WITH REASONS: libdeflate (only a faster route to the same Deflate),
JBIG (needs jbigkit) and LERC (needs libLerc); none has a recipe here, and the
test asserts each is NOT configured, so a builder that has them cannot widen
the artifact. tiffgt, the documentation and the contrib programs are kept out
for the same reason.

⭐ WebP IS ON, which is why google.com/webp refuses TIFF: the pair is a cycle
and one direction had to be built first.

⚠ THE SIGNATURE IS NOT ANCHORED. See distributable: the key signs, nothing the
project controls publishes its fingerprint, so the digest (two fetches, one
host) is the warrant.

⛔ NOT BUILT BY THE FACTORY. Configured, built and installed once on
darwin/arm64, with liblzma and libzstd from Homebrew (our tukaani.org/xz and
facebook.com/zstd were not built for it); the fixture ran against that install.
EOT
}
