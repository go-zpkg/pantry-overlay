# littlecms.com — Little CMS 2 (lcms2): an ICC colour-management engine, with
# the jpgicc, tificc, transicc, linkicc and psicc tools. Pillow's `lcms`
# feature (setup.py:859-866) and three other recipes of this tree
# (openjpeg.org, freedesktop.org/poppler-qt5, mupdf's closure) use it, and
# python-pillow.org (go-zpkg/recipes#122 step 5) is why this recipe exists.
#
# ⛔ WRITTEN FROM LITTLE CMS'S OWN FILES (go-zpkg/packages#431), at 2.20.
#
# ⭐⭐ WHAT WRITING IT FOUND, THREE THINGS:
#
# 1. configure.ac:176-180 reads `--with-threads`, and the help text on :177
#    advertises `--without-pthreads` — a flag no code reads, which configure
#    accepts with a warning and ignores. Naming the one that is read is what
#    makes the thread-safe build a stated choice.
# 2. JPEG and TIFF support in the tools are probed (configure.ac:255-312,
#    :365-392) and a failed probe sets `have_jpeg='no (failed tests)'` with no
#    error: jpgicc and tificc are simply not built. `provides` below lists them,
#    so a build that lost either fails there.
# 3. Two plugins, fast_float and threaded, are "use only if GPL 3.0 is
#    acceptable" (configure.ac:145, :160). They are off by default and are
#    named off, because turning one on changes the licence of the artifact.

summary = "Little CMS 2: an ICC colour-management engine with the jpgicc, tificc and transicc tools"

# LICENSE:1-5, "MIT License", Copyright (c) 2023 Marti Maria Saguer, and every
# source file carries the same notice. utils/jpgicc/iccjpeg.c is compiled into
# jpgicc (utils/jpgicc/Makefile.am:19) and is NOT MIT: LICENSE_iccjpeg says "THIS
# LICENSE APPLIES ONLY TO iccjpeg.c" and is the IJG licence. The GPL-3.0
# plugins are not built (see 3 above).
license = "MIT AND IJG"

versions {
  github = "mm2/Little-CMS/tags"
  strip  = ["/^lcms/"]
  ignore = ["/rc\\d*$/"]
}

dependencies = {
  # ⛔ Found by configure's own header-and-library probes (configure.ac:255-312,
  # :316-354, :360-392), where a failure is silent. The paths are handed to
  # configure below so a builder's copy cannot answer instead.
  "libjpeg-turbo.org"         = "^3"
  "simplesystems.org/libtiff" = "^4"
  "zlib.net"                  = "^1"
}

distributable {
  # The release asset. The project publishes the tarball and a zip and no
  # signature; the same bytes are served by SourceForge.
  url              = "https://github.com/mm2/Little-CMS/releases/download/lcms{{version.raw}}/lcms2-{{version.raw}}.tar.gz"
  strip-components = 1

  # 5477898 bytes. ⚠ NOT SIGNED: the GitHub release for lcms2.20 lists exactly
  # two assets (lcms2-2.20.tar.gz and .zip), neither a signature. The digest
  # was fetched from TWO HOSTS, the GitHub release and SourceForge
  # (downloads.sourceforge.net/project/lcms/lcms/2.20), and the bytes are
  # identical.
  sha256 = {
    "2.20" = "18ff5504fa9cc8a2b1f3591180d90ead16c8a2ea78e530523b46eab70e1ca6b9"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔⛔ 1. JPEG and TIFF, POINTED AT OUR LIBRARIES. configure.ac:101-134:
      # a directory argument adds -I and -L for it, so the probes at :255-312
      # and :360-392 look there first. They still fail silently (see above).
      "--with-jpeg={{deps.libjpeg-turbo.org.prefix}}",
      "--with-tiff={{deps.simplesystems.org/libtiff.prefix}}",
      "--with-zlib",

      # ⛔⛔ 2. THREADS, NAMED WITH THE FLAG THAT IS READ (configure.ac:176-180).
      "--with-threads=yes",

      # ⛔⛔ 3. THE GPL-3.0 PLUGINS, REFUSED (configure.ac:143-170): defaults, named
      # so a changed default is visible.
      "--without-fastfloat",
      "--without-threaded",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# utils/*/Makefile.am, read off an install: the five tools. jpgicc and tificc
# exist only if the JPEG and TIFF probes passed.
provides = [
  "bin/jpgicc",
  "bin/linkicc",
  "bin/psicc",
  "bin/tificc",
  "bin/transicc",
]

test {
  fixture = <<EOT
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <lcms2.h>

int main(void)
{
	/* The version this header and library were built as. */
	if (cmsGetEncodedCMMversion() != LCMS_VERSION) {
		fprintf(stderr, "header %d, library %d\n", LCMS_VERSION, cmsGetEncodedCMMversion());
		return 1;
	}

	cmsHPROFILE srgb = cmsCreate_sRGBProfile();
	cmsHPROFILE lab = cmsCreateLab4Profile(NULL);
	if (!srgb || !lab)
		return 1;

	/* sRGB -> Lab -> sRGB on 8-bit pixels must come back within one step. */
	cmsHTRANSFORM there = cmsCreateTransform(srgb, TYPE_RGB_8, lab, TYPE_Lab_DBL,
	    INTENT_RELATIVE_COLORIMETRIC, 0);
	cmsHTRANSFORM back = cmsCreateTransform(lab, TYPE_Lab_DBL, srgb, TYPE_RGB_8,
	    INTENT_RELATIVE_COLORIMETRIC, 0);
	if (!there || !back) {
		fprintf(stderr, "no transform\n");
		return 1;
	}
	unsigned char in[3 * 64], out[3 * 64];
	cmsCIELab l[64];
	for (int i = 0; i < 64; i++) {
		in[3 * i] = (unsigned char)(i * 4);
		in[3 * i + 1] = (unsigned char)(255 - i * 4);
		in[3 * i + 2] = 99;
	}
	cmsDoTransform(there, in, l, 64);
	cmsDoTransform(back, l, out, 64);
	for (int i = 0; i < 3 * 64; i++) {
		int d = (int)in[i] - (int)out[i];
		if (d < -1 || d > 1) {
			fprintf(stderr, "byte %d: %u -> %u\n", i, in[i], out[i]);
			return 1;
		}
	}

	/* A profile written to memory and read back is the same profile. */
	cmsUInt32Number n = 0;
	cmsSaveProfileToMem(srgb, NULL, &n);
	void *mem = malloc(n);
	if (!mem || !cmsSaveProfileToMem(srgb, mem, &n)) {
		fprintf(stderr, "cannot save a profile\n");
		return 1;
	}
	cmsHPROFILE again = cmsOpenProfileFromMem(mem, n);
	if (!again || cmsGetColorSpace(again) != cmsSigRgbData) {
		fprintf(stderr, "cannot read the profile back\n");
		return 1;
	}
	cmsCloseProfile(again);
	free(mem);
	cmsDeleteTransform(there);
	cmsDeleteTransform(back);
	cmsCloseProfile(srgb);
	cmsCloseProfile(lab);
	return 0;
}
EOT

  script = [
    "cc -x c $FIXTURE -x none -o lcmscheck -I{{prefix}}/include -L{{prefix}}/lib -llcms2",
    {
      run = <<EOT
set -eu
LD_LIBRARY_PATH="{{prefix}}/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="{{prefix}}/lib:$${DYLD_LIBRARY_PATH:-}" ./lcmscheck
EOT
    },

    # ⛔ THE THREAD-SAFE BUILD, READ OFF THE LIBRARY: with HasTHREADS the mutex
    # code calls pthread_mutex_*, which therefore appear as undefined symbols.
    {
      run = <<EOT
set -eu
lib=$(ls "{{prefix}}"/lib/liblcms2.so "{{prefix}}"/lib/liblcms2.dylib 2>/dev/null | head -n 1)
nm -u "$lib" > undefined.txt 2>&1 || nm -D -u "$lib" > undefined.txt 2>&1
grep -q pthread_mutex_lock undefined.txt \
  || { echo "liblcms2 was built without pthreads" >&2; exit 1; }
EOT
    },

    # ⛔ THE TOOLS' IMAGE LIBRARIES, BY USE. jpgicc and tificc are built only when
    # configure's probes passed; each must read and write a file of its format.
    {
      run = <<EOT
set -eu
echo P6 > in.ppm
echo "2 2" >> in.ppm
echo 255 >> in.ppm
head -c 12 /dev/zero >> in.ppm
cjpeg in.ppm > in.jpg
"{{prefix}}/bin/jpgicc" in.jpg out.jpg
test -s out.jpg
ppm2tiff in.ppm in.tif
"{{prefix}}/bin/tificc" in.tif out.tif
tiffinfo out.tif > /dev/null
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",              # :100-140 --with-jpeg/--with-tiff/--with-zlib; :142-170 the GPL-3.0 plugins, default no; :176-180 `--with-threads` (read) and :177 `--without-pthreads` (advertised, not read); :209-219 SSE2 probe; :253-312 JPEG probe and its silent `no (failed tests)`; :360-392 TIFF
    "LICENSE",                   # the MIT text, Copyright (c) 2023 Marti Maria Saguer
    "utils/jpgicc/LICENSE_iccjpeg", # "THIS LICENSE APPLIES ONLY TO iccjpeg.c", the IJG licence
    "utils/jpgicc/Makefile.am",  # :19 iccjpeg.c is compiled into jpgicc
    "utils/common/xgetopt.c",    # the MIT notice
    "meson_options.txt",         # `utils` defaults to false there, which is why autotools is used
  ]

  consulted = [
    # Read for facts only: the release asset URL and that autotools is the build.
    "pkgxdev/pantry projects/littlecms.com/package.yml",
  ]

  note = <<EOT
⛔ A HELP TEXT THAT ADVERTISES A FLAG NOTHING READS. configure.ac:177 says
`--without-pthreads`; the variable is `with_threads` (:176, :180), so the
flag is `--with-threads`. An unknown `--without-…` option is accepted with a
warning, so a recipe written from the help text would believe it had disabled
something. The test reads the outcome off liblcms2 (pthread_mutex_lock among
its undefined symbols).

⛔ THE TOOLS' IMAGE SUPPORT IS A PROBE WITH A SILENT FAILURE: configure.ac:301
`have_jpeg='no (failed tests)'`. jpgicc and tificc are then not built, and
`provides` lists them so that is a failure, and the test runs each on a file
made by libjpeg-turbo's cjpeg and libtiff's ppm2tiff.

⭐ THE GPL-3.0 PLUGINS ARE NAMED OFF. fast_float and threaded change the
licence of what is installed; the licence field above would be wrong with them.

⚠ NOT SIGNED. The release carries no signature; the digest is the same from
GitHub's release and from SourceForge, two hosts.

⛔ NOT BUILT BY THE FACTORY. Configured, built and installed once on
darwin/arm64 against the libjpeg-turbo and libtiff built from our recipes; the
fixture ran against that install. The SSE2 probe (:212-219) answered "no" there
because arm64 has no SSE2, so that arm is untested.
EOT
}
