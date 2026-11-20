# libjpeg-turbo.org — a SIMD-accelerated JPEG codec: the libjpeg API library
# (libjpeg), the TurboJPEG API library (libturbojpeg) and the cjpeg, djpeg,
# jpegtran, rdjpgcom, wrjpgcom and tjbench tools. Pillow's `jpeg` feature is the
# one library its setup.py will not build without (setup.py:327), and
# python-pillow.org (go-zpkg/recipes#122 step 5) is why this recipe exists.
#
# ⛔ WRITTEN FROM LIBJPEG-TURBO'S OWN FILES (go-zpkg/packages#431), at 3.2.1.
#
# ⭐⭐ WHAT WRITING IT FOUND: the SIMD code, which is the reason to use this
# library at all, is OPTIONAL BY DEFAULT AND DROPPED WITH A WARNING.
# simd/CMakeLists.txt:53-60 on x86 looks for NASM and, when it finds none,
# calls simd_fail() (:1-10), which prints a CMake WARNING ("Performance will
# suffer"), sets WITH_SIMD to 0 and carries on. The build succeeds, every test
# of "does it decode a JPEG" passes, and the library is several times slower.
# REQUIRE_SIMD turns that into a FATAL_ERROR, and the test below reads the
# outcome off the installed static library.

summary = "libjpeg-turbo: SIMD-accelerated JPEG codec with the libjpeg and TurboJPEG APIs"

# LICENSE.md:5-29, read from the file: the libjpeg API library is the IJG
# License (README.ijg), the TurboJPEG library and the build system the Modified
# (3-clause) BSD License, and cjpeg/djpeg carry BOTH because they use libspng.
# LICENSE.md:31-50 adds what is compiled in and is "subsumed" but is still
# named by the file: the SIMD source (zlib License, :39-41), and libspng, partly
# libpng-2.0 (:44-46) and mostly BSD-2-Clause (:48-51). zlib's own source is
# NOT compiled here (WITH_SYSTEM_ZLIB below), so it adds nothing beyond the SIMD
# source's Zlib.
license = "IJG AND BSD-3-Clause AND BSD-2-Clause AND Zlib AND libpng-2.0"

versions {
  github = "libjpeg-turbo/libjpeg-turbo"
}

dependencies = {
  # ⛔ NAMED, so it is FATAL when missing: find_package(ZLIB REQUIRED) at
  # CMakeLists.txt:763 runs only under WITH_SYSTEM_ZLIB. Without the flag the
  # in-tree zlib is compiled (:767) and zlib.net would be an unused dependency.
  "zlib.net" = "^1"
}

distributable {
  # The release asset, not GitHub's archive of the tag: the project signs this
  # file (libjpeg-turbo-3.2.1.tar.gz.sig sits beside it in the release).
  url              = "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/{{version.raw}}/libjpeg-turbo-{{version.raw}}.tar.gz"
  strip-components = 1

  # 2549854 bytes. ⭐ VERIFIED SIGNATURE, with the fingerprint from the
  # project's own site:
  #
  #   signed by    0338C8D8D9FDA62CF9C421BD7EC2DBB6F4DBF434, 2026-10-27
  #                The libjpeg-turbo Project (Signing key for official binaries)
  #   fingerprint  https://libjpeg-turbo.org/Downloads/DigitalSignatures, the
  #                "Source tarball, libjpeg-turbo 2.0.6 and later" entry
  #   key bytes    https://raw.githubusercontent.com/libjpeg-turbo/repo/main/LJT-GPG-KEY
  #   tarball+sig  github.com/libjpeg-turbo release 3.2.1
  #
  # Checked with `zpkb sourcepin --sig auto --key … --fingerprint …` (v0.90.0;
  # no keyserver asked) and confirmed by a second, independent fetch-and-hash.
  sha256 = {
    "3.2.1" = "c27ad72a68da151177929aa969ae773a2da5ac2af9ce946079314fdac8cece7f"
  }
}

build {
  dependencies = {
    "cmake.org"    = "^3"
    "gnu.org/make" = "*"

    # ⛔ x86 ONLY, BUT DECLARED UNCONDITIONALLY: simd/CMakeLists.txt:61 runs
    # enable_language(ASM_NASM) once REQUIRE_SIMD is set, and that fails
    # without NASM. On aarch64 the SIMD code is C intrinsics and nasm is not
    # run. nasm.us is not a recipe of this tree yet.
    "nasm.us" = "*"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",

      # ⚠ GNUInstallDirs picks lib64 on some distributions; every consumer in
      # this tree looks in lib.
      "-DCMAKE_INSTALL_LIBDIR=lib",

      # ⛔⛔ 1. SIMD, REQUIRED. CMakeLists.txt:248-251 (default FALSE) and
      # simd/CMakeLists.txt:1-10, :53-60. Refused to build without it.
      "-DREQUIRE_SIMD=1",

      # ⛔⛔ 2. zlib, NAMED: the default compiles the in-tree one (:753-769).
      "-DWITH_SYSTEM_ZLIB=1",

      # 3. libspng for cjpeg/djpeg PNG I/O. :724-729 says that only the in-tree
      # copy "is thoroughly tested by our project"; no libspng recipe exists
      # here, so the default is kept and named.
      "-DWITH_SYSTEM_SPNG=0",

      # 4. The libjpeg ABI. Defaults (:269-276) are v6b (JPEG_LIB_VERSION 62),
      # the one every distribution ships and Pillow's setup.py links
      # (`-ljpeg`); 7 and 8 are backward-incompatible with it. Named so a
      # changed default is visible.
      "-DWITH_JPEG7=0",
      "-DWITH_JPEG8=0",

      # 5. Static libraries stay on (:246): the test reads the SIMD outcome out
      # of libjpeg.a, and statically linking consumers need it.
      "-DENABLE_STATIC=1",
      "-DENABLE_SHARED=1",
      "-DWITH_TURBOJPEG=1",
      "-DWITH_TOOLS=1",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# The installed tools, read off a build: cjpeg, djpeg, jpegtran, rdjpgcom,
# wrjpgcom and tjbench (CMakeLists.txt:888-890 WITH_TOOLS).
provides = [
  "bin/cjpeg",
  "bin/djpeg",
  "bin/jpegtran",
  "bin/rdjpgcom",
  "bin/tjbench",
  "bin/wrjpgcom",
]

test {
  fixture = <<EOT
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <jpeglib.h>
#include <turbojpeg.h>

int main(void)
{
	/* The libjpeg ABI this build emulates: WITH_JPEG7 and WITH_JPEG8 are 0. */
	if (JPEG_LIB_VERSION != 62) {
		fprintf(stderr, "JPEG_LIB_VERSION is %d, want 62\n", JPEG_LIB_VERSION);
		return 1;
	}

	/* A 16x16 grey ramp through the libjpeg API, to memory and back. */
	unsigned char pix[16 * 16 * 3];
	for (int i = 0; i < 16 * 16; i++)
		pix[3 * i] = pix[3 * i + 1] = pix[3 * i + 2] = (unsigned char)(i);

	struct jpeg_compress_struct c;
	struct jpeg_error_mgr e1;
	unsigned char *jpg = NULL;
	unsigned long jlen = 0;
	c.err = jpeg_std_error(&e1);
	jpeg_create_compress(&c);
	jpeg_mem_dest(&c, &jpg, &jlen);
	c.image_width = 16;
	c.image_height = 16;
	c.input_components = 3;
	c.in_color_space = JCS_RGB;
	jpeg_set_defaults(&c);
	jpeg_set_quality(&c, 90, TRUE);
	jpeg_start_compress(&c, TRUE);
	while (c.next_scanline < c.image_height) {
		JSAMPROW row = &pix[c.next_scanline * 16 * 3];
		jpeg_write_scanlines(&c, &row, 1);
	}
	jpeg_finish_compress(&c);
	jpeg_destroy_compress(&c);
	if (jlen < 100 || jpg[0] != 0xff || jpg[1] != 0xd8) {
		fprintf(stderr, "no JPEG came out (%lu bytes)\n", jlen);
		return 1;
	}

	struct jpeg_decompress_struct d;
	struct jpeg_error_mgr e2;
	d.err = jpeg_std_error(&e2);
	jpeg_create_decompress(&d);
	jpeg_mem_src(&d, jpg, jlen);
	jpeg_read_header(&d, TRUE);
	jpeg_start_decompress(&d);
	if (d.output_width != 16 || d.output_height != 16 || d.output_components != 3) {
		fprintf(stderr, "decoded %ux%ux%d\n", d.output_width, d.output_height,
		    d.output_components);
		return 1;
	}
	jpeg_abort_decompress(&d);
	jpeg_destroy_decompress(&d);
	free(jpg);

	/* The TurboJPEG API, which cjpeg and tjbench sit on. */
	tjhandle h = tj3Init(TJINIT_COMPRESS);
	if (!h) {
		fprintf(stderr, "tj3Init failed\n");
		return 1;
	}
	tj3Destroy(h);
	return 0;
}
EOT

  script = [
    "cc -x c $FIXTURE -x none -o jpegcheck -I{{prefix}}/include -L{{prefix}}/lib -ljpeg -lturbojpeg",
    {
      run = <<EOT
set -eu
LD_LIBRARY_PATH="{{prefix}}/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="{{prefix}}/lib:$${DYLD_LIBRARY_PATH:-}" ./jpegcheck
EOT
    },

    # ⛔ THE SIMD OUTCOME, READ OFF THE INSTALLED ARCHIVE. A build that dropped
    # SIMD (simd/CMakeLists.txt:57) still decodes every JPEG; it just has no
    # jsimd_rgb_ycc_convert_<isa> function, which the SIMD build defines for
    # each target: neon on aarch64, sse2 and avx2 on x86 (simd/arm, simd/x86_64).
    {
      run = <<EOT
set -eu
nm "{{prefix}}/lib/libjpeg.a" > symbols.txt 2>&1
grep -E 'jsimd_rgb_ycc_convert_(neon|sse2|avx2|altivec|mmi)' symbols.txt > /dev/null \
  || { echo "libjpeg was built WITHOUT its SIMD routines" >&2; exit 1; }
EOT
    },

    # The command-line tools run, and read what they wrote: djpeg of a
    # cjpeg-made file must give back a PPM header.
    {
      run = <<EOT
set -eu
echo P6 > in.ppm
echo "2 2" >> in.ppm
echo 255 >> in.ppm
head -c 12 /dev/zero >> in.ppm
"{{prefix}}/bin/cjpeg" -quality 90 in.ppm > out.jpg
"{{prefix}}/bin/djpeg" -ppm out.jpg > back.ppm
head -c 2 back.ppm | grep -q P6
EOT
    },

    # zlib has to be the one we declared (WITH_SYSTEM_ZLIB), not an in-tree copy.
    {
      run = <<EOT
set -eu
ldd "{{prefix}}/bin/cjpeg" > linkage.txt
grep -q 'libz' linkage.txt || { echo "cjpeg does not link a system zlib" >&2; cat linkage.txt >&2; exit 1; }
EOT
      if  = "linux"
    },
  ]
}

provenance {
  read = [
    "CMakeLists.txt",      # :91 Release default; :244-295 every option and its default; :698-703 SIMD; :722-770 libspng and zlib, bundled by default; :888 WITH_TOOLS
    "simd/CMakeLists.txt", # :1-10 simd_fail is a WARNING, :53-60 the x86 NASM probe that falls back, :61 enable_language(ASM_NASM)
    "LICENSE.md",          # :5-51 the licences, and which programs carry which
  ]

  consulted = [
    # Read for facts only: the release asset URL and that cmake is the build.
    "pkgxdev/pantry projects/libjpeg-turbo.org/package.yml",
    "https://libjpeg-turbo.org/Downloads/DigitalSignatures",
  ]

  note = <<EOT
⛔⛔ THE SIMD CODE IS DROPPED SILENTLY WHEN NASM IS ABSENT. simd/CMakeLists.txt
:53-60 turns "no NASM" into a CMake WARNING and a non-SIMD library; the
library still decodes, still passes any functional test, and is several times
slower. REQUIRE_SIMD=1 makes it a configuration error, and the test reads the
outcome from the installed libjpeg.a instead of trusting the flag.

⭐ THE TARBALL IS SIGNED AND THE FINGERPRINT IS THE PROJECT'S OWN. The key
0338C8D8D9FDA62CF9C421BD7EC2DBB6F4DBF434 is the one libjpeg-turbo.org's
DigitalSignatures page names for source tarballs of 2.0.6 and later; the key
bytes come from the project's `repo` repository. Verified with zpkb sourcepin,
no keyserver consulted, plus a second independent hash of the same file.

⚠ nasm.us IS A BUILD DEPENDENCY THIS TREE DOES NOT CARRY YET; it is needed on
x86 only. ⛔ NOT BUILT BY THE FACTORY. Configured, built and installed once on
darwin/arm64 (SIMD: ARM64, zlib from the SDK); the C fixture and the nm check
were run against that install. Nothing was built on linux or x86.
EOT
}
