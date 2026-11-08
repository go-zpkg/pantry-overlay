# lz4 — extremely fast lossless compression: the `lz4` tool and liblz4.
#
# ⛔ WRITTEN FROM LZ4'S OWN BUILD SYSTEM, NOT CONVERTED (go-zpkg/packages#431).
# Third whole recipe of the sovereign pantry, after zlib.net (#79) and
# tukaani.org/xz (#81).

summary = "Extremely fast lossless compression: the lz4 tool and liblz4"

# ⛔ TWO LICENCES, AND homebrew-core RECORDS ONE. Its formula says
# `license "BSD-2-Clause"`, which is the LIBRARY's. The command line tools are
# separately licensed: programs/COPYING opens with "Full name: GNU General
# Public License v2.0 or later", and lib/LICENSE is the BSD for liblz4. Read
# from the two files rather than taken from a formula — the point of writing
# these recipes is that the licence field is checked, and this is a case where
# the usual source under-reports it.
license = "BSD-2-Clause AND GPL-2.0-or-later"

versions {
  github = "lz4/lz4"
  ignore = ["/beta|alpha|rc/"]
}

distributable {
  # ⛔⛔ THE STORED RELEASE ASSET, NOT THE GENERATED TAG ARCHIVE, AND THAT
  # DISTINCTION IS THE WHOLE REASON THIS LINE LOOKS LIKE THIS. GitHub serves
  # two different things from a release:
  #
  #   releases/download/…   an asset the maintainer UPLOADED. Byte-stable, so
  #                         a digest pins it for good.
  #   archive/refs/tags/…   a tarball GitHub GENERATES on request. Its bytes
  #                         have changed before, when the gzip implementation
  #                         changed, so a pinned digest there is fragile BY
  #                         CONSTRUCTION rather than merely unlucky.
  #
  # Measured over 1932 upstream recipes: 1111 of them (57.7%) build from a
  # generated archive and therefore cannot be pinned reliably at all
  # (go-zpkg/packages#420). homebrew-core's lz4 formula is one of them — it
  # uses `archive/refs/tags/v1.11.0.tar.gz` — even though this release also
  # publishes `lz4-1.11.0.tar.gz` AND its own `.sha256` beside it. The better
  # source was there.
  url              = "https://github.com/lz4/lz4/releases/download/v{{version.raw}}/lz4-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched here with `zbk sourcepin` — the builder's own fetcher, which checks
  # the status, resumes a truncated body and refuses one whose magic bytes are
  # not the archive's — giving 545646 bytes and the digest below.
  #
  # Corroborated: it is byte-identical to the sha256 homebrew-core records.
  # ⛔ AND THE AGREEMENT IS INFORMATIVE RATHER THAN TRIVIAL, because their
  # digest is of the GENERATED archive and mine is of the STORED asset. The two
  # artefacts hold the same bytes today. That is worth stating precisely: their
  # pin is correct now, and the defect in using a generated archive is LATENT —
  # a GitHub-side change invalidates it without anybody touching the project.
  #
  # Upstream also publishes lz4-1.11.0.tar.gz.sha256; it could not be fetched
  # while this was written (GitHub's release CDN answering 503/504 all
  # morning), so the corroboration here is the third party's record rather than
  # the author's own file. The schema's `sha` field is the place for that file
  # once it is reachable, and it would be the stronger warrant.
  sha256 = {
    "1.11.0" = "247e5fa64da5f7b75ee3dd3bed484076396c9ebe8254d9ccf693eb62800c5e26"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  # Plain make, NOT autotools: there is no ./configure in this project. The
  # top-level Makefile's `default: lib-release lz4-release` builds the library
  # and the tool, and the README says only "make install". The prefix is a
  # MAKE variable, read from lib/Makefile:268-269 rather than guessed:
  #
  #     PREFIX      ?= /usr/local
  #     prefix      ?= $(PREFIX)
  #
  # so both spellings work and PREFIX is the one the project names first. A
  # command-line variable propagates to the sub-makes the top level delegates
  # to, which is why it does not need exporting.
  script = [
    "make --jobs {{hw.concurrency}}",
    "make install PREFIX={{prefix}}",
  ]
}

# Read from programs/Makefile:222-228: `install` installs lz4 and then links
# lz4c, lz4cat and unlz4 beside it. Four names, from the install target rather
# than from guesswork.
provides = [
  "bin/lz4",
  "bin/lz4c",
  "bin/lz4cat",
  "bin/unlz4",
]

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "lz4 --version",
    "test -f {{prefix}}/include/lz4.h",
    "test -f {{prefix}}/lib/pkgconfig/liblz4.pc",
    "pkg-config --exists liblz4",
    # The links the install target makes are part of what this package
    # provides, so they are checked as such and not assumed.
    "test -x {{prefix}}/bin/lz4cat",
    "test -x {{prefix}}/bin/unlz4",
    # A round trip through the TOOL. `lz4 -t` is the integrity check lz4 itself
    # offers, so the frame is verified and not merely decompressed.
    {
      run = "printf 'the quick brown fox jumps over the lazy dog\\n' > sample && lz4 -q sample sample.lz4 && lz4 -t sample.lz4 && unlz4 -c sample.lz4 > back && cmp sample back"
    },
    # And through the LIBRARY, which is what dependents link. The version pair
    # is asserted first for the same reason zlib.net's and xz's tests do it: a
    # disagreement between the header and the library is how a build picks up a
    # system liblz4 instead of the one it just made.
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <string.h>
#include <lz4.h>

int main(void) {
  if (LZ4_VERSION_NUMBER != LZ4_versionNumber()) {
    printf("header %d but library %d\n", LZ4_VERSION_NUMBER, LZ4_versionNumber());
    return 1;
  }

  const char text[] = "the quick brown fox jumps over the lazy dog";
  char packed[256];
  int n = LZ4_compress_default(text, packed, (int)sizeof text, (int)sizeof packed);
  if (n <= 0) {
    puts("compress failed");
    return 1;
  }

  char back[256];
  int m = LZ4_decompress_safe(packed, back, n, (int)sizeof back);
  if (m != (int)sizeof text || memcmp(text, back, sizeof text) != 0) {
    puts("round trip did not return the input");
    return 1;
  }

  printf("liblz4 %s round-tripped %d bytes\n", LZ4_versionString(), m);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o roundtrip $(pkg-config --cflags --libs liblz4)"
    },
    "./roundtrip",
  ]
}

provenance {
  read = [
    "README.md",         # "make install", and "supports standard Makefile conventions"
    "Makefile",          # default: lib-release lz4-release — plain make, no configure
    "lib/Makefile",      # PREFIX/prefix at :268-269; the .pc substitution at :239
    "programs/Makefile", # which names `install` actually installs, at :222-228
    "lib/LICENSE",       # the library's BSD
    "programs/COPYING",  # "GNU General Public License v2.0 or later"
  ]

  consulted = [
    "homebrew-core Formula/l/lz4.rb",
  ]

  note = <<EOT
make then `make install PREFIX=`, as the README documents and lib/Makefile
defines. No ./configure exists in this project, which is the one structural
difference from zlib.net and tukaani.org/xz.

Two facts recorded from lib/Makefile and deliberately NOT worked around here,
because the factory's fix-up stage already owns them and a recipe that also
tried would be a second opinion about one thing:

  - :129 on darwin passes `-install_name $(libdir)/liblz4.…`, so the dylib
    carries an ABSOLUTE install_name. fix-machos is what turns that into an
    @rpath reference.
  - :239-241 generates liblz4.pc by substituting @PREFIX@, @LIBDIR@ and
    @INCLUDEDIR@, so the pkg-config file carries absolute paths.
    fix_pc_files rewrites those to $${pcfiledir}.

⛔ THE $$ ABOVE IS NOT A TYPO, AND IT COST TWO REFUSALS TO GET RIGHT. A single
dollar followed by a brace is INTERPOLATION in an HCL heredoc, not text, so
this file was refused with "package.hcl:188: Variables not allowed". The fix
is to double the dollar — and the sentence written to explain that was itself
refused, at "package.hcl:189: Invalid expression", because it quoted the
unescaped form while describing it. Any recipe note mentioning a pkg-config
pcfiledir, an autotools prefix or a CMake list dir in that notation meets the
same thing, and roughly 1700 recipes are still to be written.

Both are named here so the next reader knows they were seen rather than
missed.

The licence field is two licences because the project has two: homebrew-core
records only the library's BSD-2-Clause, and programs/COPYING is GPL-2.0-or-later.
EOT
}
