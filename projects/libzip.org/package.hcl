# libzip.org — a C library for reading, creating and modifying zip archives,
# with the zipcmp, zipmerge and ziptool programs.
#
# ⛔ WRITTEN FROM LIBZIP'S OWN FILES (go-zpkg/packages#440 step 1), at 1.12.1.
#
# ⭐⭐ WHAT WRITING IT FOUND: libzip degrades SILENTLY. bzip2, lzma, zstd and
# every AES backend are probed with find_package and, when not found, only a
# WARNING is printed and the feature is compiled out (CMakeLists.txt:234,
# :257, :271, :289-291). A builder missing one produces a working libzip
# that cannot read half of the archives it is given. Every one is named here,
# and the test reads each back from the installed library.

summary = "libzip: a C library for reading, creating and modifying zip archives"

# LICENSE:1-6 and :17 are the three-clause BSD text ("3. The names of the
# authors may not be used to endorse or promote products"): BSD-3-Clause.
license = "BSD-3-Clause"

versions {
  github = "nih-at/libzip"
  strip  = "/^v/"
}

dependencies = {
  # One crypto backend on every platform, so the artifact does not depend on
  # the OS: OpenSSL (CMakeLists.txt:55-57), with CommonCrypto switched OFF below
  # (:48-50 would otherwise win on macOS, :275-277).
  "openssl.org"           = "^3"
  "facebook.com/zstd"     = ">=1.5.0"
  "sourceware.org/bzip2"  = ">=1.0.8"
  "tukaani.org/xz"        = ">=5.2.7"
  "zlib.net"              = ">=1.2.13"
}

distributable {
  # The stored release asset (the release uploads .tar.gz and .tar.xz), not the
  # generated archive of the tag. The .xz is chosen because it is the one
  # homebrew-core records.
  url              = "https://github.com/nih-at/libzip/releases/download/v{{version.raw}}/libzip-{{version.raw}}.tar.xz"
  strip-components = 1

  # 813384 bytes, fetched with `zpkb sourcepin`. The release publishes no
  # signature and no checksum file, and libzip.org's download page none either.
  #
  # Corroborated by a THIRD PARTY's record: homebrew-core's API
  # (formulae.brew.sh/api/formula/libzip.json, stable 1.12.1) records the same
  # digest for this same .tar.xz. That is the second witness, and it is a
  # third party's, not the author's.
  sha256 = {
    "1.12.1" = "c40062022a1963c80573d48f6070792297cecd7c6bffe3aefcac0d8b9bee8913"
  }
}

build {
  dependencies = {
    "cmake.org"                  = "^3"
    "freedesktop.org/pkg-config" = "^0.29"
    "gnu.org/make"               = "*"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DBUILD_SHARED_LIBS=ON",

      # :16-19 and :289-291. Exactly one backend, named; the others OFF so the
      # choice cannot move with the builder. GnuTLS and CommonCrypto are probed
      # by default, and CommonCrypto would beat OpenSSL on macOS (:275-277).
      "-DENABLE_OPENSSL=ON",
      "-DENABLE_COMMONCRYPTO=OFF",
      "-DENABLE_GNUTLS=OFF",
      "-DENABLE_WINDOWS_CRYPTO=OFF",

      # :21-23, :229-273: each is a find_package whose failure is only a warning.
      "-DENABLE_BZIP2=ON",
      "-DENABLE_LZMA=ON",
      "-DENABLE_ZSTD=ON",

      # :31 the three programs are installed (src/CMakeLists.txt:2-7).
      "-DBUILD_TOOLS=ON",
      # :32-35 the regression suite, the OSS-Fuzz harnesses, the examples and
      # the documentation (:324 `if(BUILD_DOC)`, format chosen at :71-77): none
      # is needed by the installed library or tools.
      "-DBUILD_REGRESS=OFF",
      "-DBUILD_OSSFUZZ=OFF",
      "-DBUILD_EXAMPLES=OFF",
      "-DBUILD_DOC=OFF",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# src/CMakeLists.txt:2-7: foreach(PROGRAM zipcmp zipmerge ziptool), installed to bin.
provides = [
  "bin/zipcmp",
  "bin/zipmerge",
  "bin/ziptool",
]

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
    "gnu.org/gcc"                = "*"
  }

  # zip_compression_method_supported and zip_encryption_method_supported
  # (lib/zip.h:524-525) answer for what THIS library was built with, so every
  # choice above is read back. The version pair guards against a system libzip
  # being linked instead of the one just built.
  fixture = <<EOT
#include <stdio.h>
#include <string.h>
#include <zip.h>

static int need(const char *what, int ok)
{
	if (!ok) {
		fprintf(stderr, "libzip was built without %s\n", what);
		return 1;
	}
	return 0;
}

int main(void)
{
	int bad = 0;
	if (strcmp(zip_libzip_version(), LIBZIP_VERSION) != 0) {
		fprintf(stderr, "header %s but library %s\n", LIBZIP_VERSION, zip_libzip_version());
		return 1;
	}
	bad |= need("bzip2", zip_compression_method_supported(ZIP_CM_BZIP2, 1));
	bad |= need("xz", zip_compression_method_supported(ZIP_CM_XZ, 1));
	bad |= need("zstd", zip_compression_method_supported(ZIP_CM_ZSTD, 1));
	bad |= need("deflate", zip_compression_method_supported(ZIP_CM_DEFLATE, 1));
	bad |= need("AES-256", zip_encryption_method_supported(ZIP_EM_AES_256, 1));
	if (!bad)
		printf("libzip %s\n", zip_libzip_version());
	return bad;
}
EOT

  script = [
    "pkg-config --exists libzip",
    "cc -x c $FIXTURE -x none -o features $(pkg-config --cflags --libs libzip)",
    "./features",
    # The tools, through a real archive.
    {
      run = "printf 'hello\\n' > a.txt && ziptool -n t.zip add_file a.txt a.txt 0 -1 && ziptool t.zip cat 0 > back.txt && cmp a.txt back.txt && zipcmp t.zip t.zip"
    },
  ]
}

provenance {
  read = [
    "CMakeLists.txt",         # :16-35 the options; :48-62 crypto probes; :199 zlib REQUIRED; :229-273 bzip2/lzma/zstd warn-and-drop; :275-291 backend precedence and the AES warning; :64 BUILD_SHARED_LIBS
    "cmake/Findzstd.cmake",   # :75-76 zstd is found through pkg-config
    "src/ziptool.c",          # :834-836 add_file and cat; :923 -n creates the archive
    "src/CMakeLists.txt",     # :2-7 zipcmp, zipmerge, ziptool installed to bin
    "lib/zip.h",              # :191-222 method constants; :461 zip_libzip_version; :524-525 the *_supported probes
    "libzip.pc.in",           # the pkg-config file the test queries
    "LICENSE",                # :1-17 BSD-3-Clause
    "INSTALL.md",             # the cmake build
  ]

  consulted = [
    "formulae.brew.sh/api/formula/libzip.json (checksum only)",
  ]

  note = <<EOT
⚠ THE RUNG IS A THIRD PARTY'S DIGEST. The release has no signature or checksum
file of its own. The digest was fetched with zpkb sourcepin and equals
homebrew-core's recorded sha256 for the same .tar.xz.

Prior recipe: a fragment listing darwin-only bzip2/xz/zlib and linux-only
openssl. That left OpenSSL absent on macOS (where CommonCrypto is used by
default) and, on linux, bzip2, xz and zstd unnamed, which find_package would
have picked up from the host or dropped with a warning. This recipe uses the
same libraries on every platform.

⛔ NOT BUILT. No session here can run the factory.
EOT
}
