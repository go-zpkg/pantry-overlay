# utf8proc — a clean C library for processing UTF-8 Unicode data (NFC/NFD/
# NFKC/NFKD normalisation, case folding, grapheme breaks, character
# properties).
#
# ⛔ WRITTEN FROM UTF8PROC'S OWN FILES at 2.12.0, continuing
# go-zpkg/packages#440 step 1. Subversion depends on
# "github.com/JuliaStrings/utf8proc" (^2) and no recipe for it existed here.

summary = "utf8proc: C library for processing UTF-8 Unicode data (normalisation, case folding, grapheme breaks)"

# LICENSE.md: the MIT "expat" license for the Julia maintainers' work (:7-8),
# the same text again for the original Public Software Group code (:30-34), and
# a third section, "Unicode data license" (:52-55), for the data tables. The
# first two are MIT; the third is Unicode, Inc.'s own terms and is not named
# here because no SPDX identifier was checked against its 1991-2007 text.
license = "MIT"

versions {
  # ⚠ The `releases` form reads the release NAME, not the tag. Here they are
  # the same string ("v2.12.0"), so the strip is the leading `v`.
  github = "JuliaStrings/utf8proc/releases"
  strip  = "/^v/"
}

distributable {
  # The STORED release asset (utf8proc-2.12.0.tar.gz, 204791 bytes), not the
  # tag archive: GitHub regenerates the latter on demand, the former is a file
  # uploaded once.
  url              = "https://github.com/JuliaStrings/utf8proc/releases/download/{{version.raw}}/utf8proc-{{version}}.tar.gz"
  strip-components = 1

  # NO SIGNATURE AND NO CHECKSUM FILE IS PUBLISHED with the asset, so the
  # second witness is an independent one, in two steps measured on 2026-11-21:
  #
  #   1. The tag archive https://github.com/JuliaStrings/utf8proc/archive/
  #      refs/tags/v2.12.0.tar.gz hashes to
  #      f564011d38b2888d583d510b08e69ffa15aa117155db1b9b49ef1dfe1fa25111,
  #      the very digest Homebrew's formula API publishes for it
  #      (formulae.brew.sh/api/formula/utf8proc.json, urls.stable.checksum).
  #   2. The two tarballs extract to IDENTICAL trees (`diff -rq` of the
  #      extracted directories exits 0, no differing and no extra file).
  #
  # So the stored asset below holds exactly the files Homebrew's independently
  # recorded digest covers.
  sha256 = {
    "2.12.0" = "a393fbef160835fb315bc3e91ba8d86f7a73a7cec9e6198b6c60b848b498bfeb"
  }
}

# Plain C, no library: the Makefile links nothing but libc, and utf8proc.c
# includes no third-party header.
dependencies = {}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env {
    ARGS = [
      # Makefile:42-45 are `prefix=/usr/local` and the lib, include and
      # pkgconfig directories derived from it, so the one variable moves all
      # four. It is passed on the command line, which beats the assignment.
      "prefix={{prefix}}",
    ]
  }

  # `all` (Makefile:54) builds the static and the shared library; `install`
  # (:108-118) puts utf8proc.h, both libraries, libutf8proc.pc and the
  # soname symlinks in place. PERL is named at :8 but only the data-regeneration
  # targets use it, so it is not a dependency.
  script = <<EOT
make -j {{ hw.concurrency }} $ARGS
make install $ARGS
EOT
}

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test -f {{prefix}}/include/utf8proc.h",
    "test -f {{prefix}}/lib/libutf8proc.a",

    # ⛔ libutf8proc.pc's `Version:` IS THE ABI VERSION, NOT THE RELEASE: the
    # Makefile substitutes $(MAJOR).$(MINOR).$(PATCH) (:105), which is 3.3.0 for
    # release 2.12.0 (:19-30 say so in a comment). `pkg-config --modversion`
    # would therefore never equal {{version.raw}}; it is read for what it is.
    "pkg-config --exists libutf8proc",

    # THROUGH THE LIBRARY: utf8proc_version() (utf8proc.h) is what the compiled
    # library says, the UTF8PROC_VERSION_* macros (:72-76) what the header says,
    # and NFC of "e" + U+0301 must be the single code point U+00E9.
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <utf8proc.h>

int main(void) {
  char want[32];
  const char *got = utf8proc_version();
  utf8proc_uint8_t *out;
  snprintf(want, sizeof want, "%d.%d.%d", UTF8PROC_VERSION_MAJOR,
           UTF8PROC_VERSION_MINOR, UTF8PROC_VERSION_PATCH);
  if (strcmp(got, want) != 0) {
    printf("library %s but header %s\n", got, want);
    return 1;
  }
  out = utf8proc_NFC((const utf8proc_uint8_t *)"e\xcc\x81");
  if (out == NULL || strcmp((const char *)out, "\xc3\xa9") != 0) {
    return 2;
  }
  free(out);
  printf("utf8proc %s\n", got);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o libcheck $(pkg-config --cflags --libs libutf8proc)"
    },
    "./libcheck",
  ]
}

provenance {
  read = [
    "Makefile",       # :4-8 programs; :19-30 ABI MAJOR.MINOR.PATCH is not the release; :42-45 prefix and dirs; :54 all; :100-106 libutf8proc.pc sed with the ABI version; :108-118 install
    "utf8proc.h",     # :72-76 UTF8PROC_VERSION_MAJOR/MINOR/PATCH
    "libutf8proc.pc.in", # `Version: VERSION`, replaced at Makefile:105
    "LICENSE.md",     # :7-8 MIT expat; :30-34 original MIT; :52-55 Unicode data license
    "MANIFEST",
  ]

  consulted = [
    "https://github.com/JuliaStrings/utf8proc/releases",
    "https://github.com/JuliaStrings/utf8proc/archive/refs/tags/v2.12.0.tar.gz", # the independent fetch of the witness
    "https://formulae.brew.sh/api/formula/utf8proc.json", # the independently published digest of that archive
  ]

  note = <<EOT
Makefile build, written from the Makefile. Nothing was converted and no
third-party recipe was used.

⛔ The soname is libutf8proc.so.3 (MAJOR=3) while the release is 2.12.0:
Subversion's `^2` constraint is about the API version, which is the release.

⛔ NOT RUN: the build script is read-checked, not executed.
EOT
}
