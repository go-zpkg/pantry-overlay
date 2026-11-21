# unicode.org — ICU (icu4c): the International Components for Unicode C/C++
# libraries (libicuuc, libicui18n, libicuio, libicudata) and their tools.
#
# ⛔ WRITTEN FROM THE RELEASE SOURCE TARBALL'S OWN FILES (go-zpkg/packages#440), at
# 79.1, as a dependency of harfbuzz.org (its `icu` feature) and of
# tectonic-typesetting.github.io. The repository is unicode-org/icu; the build
# is source/configure (autotools) from the stored `icu4c-79.1-sources.tgz`.
#
# ⛔ ONLY 78.x AND 79.x ARE LISTED. From 77.1 back the tags are `release-77-1`
# with hyphens, and the stored tarball is named `icu4c-77_1-src.tgz`: the URL
# template below is the 78+ one (`icu4c-X.Y-sources.tgz`), so the older tags are
# ignored rather than left to resolve to a 404. 77.1 and older are NOT written.

summary = "ICU: the International Components for Unicode C/C++ libraries and tools"

# LICENSE:1 "UNICODE LICENSE V3" (SPDX Unicode-3.0). The tarball's as_is/ and
# source/ hold a few files under other licences that are not listed here.
license = "Unicode-3.0"

versions {
  github = "unicode-org/icu"
  strip  = ["/^release-/"]
  ignore = [
    "/rc/",
    "/^(release-)?([0-9]|[1-6][0-9]|7[0-7])[.-]/",
  ]
}

distributable {
  # The STORED release asset; the release also holds SHASUM512.txt and a
  # detached .asc for every file.
  url              = "https://github.com/unicode-org/icu/releases/download/release-{{version.raw}}/icu4c-{{version.raw}}-sources.tgz"
  strip-components = 1

  # 28162455 bytes, fetched with `zpkb sourcepin`. The second witness is the
  # release's own SHASUM512.txt, fetched separately: its line for
  # icu4c-79.1-sources.tgz is the SHA-512 of the same bytes
  # (9098adf9...a973, checked with shasum -a 512). ⛔ The .asc signatures were
  # NOT verified (no key was fetched, and a keyserver is never asked).
  sha256 = {
    "79.1" = "06fa63ecb521048f8082f12ad988f6b678d90cbd88aafce24cbc94902b191d99"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
    "gnu.org/gcc"  = "*"
  }

  # source/configure.ac, EVERY option, stated (defaults checked in the file):
  #   --enable-shared       :272 default (libraries are .so / .dylib).
  #   --disable-static      :287 default off, stated.
  #   --enable-release      :118 default; --disable-debug :104 default.
  #   --enable-icu-config   :91 default true: icu-config is installed.
  #   --disable-auto-cleanup :334 default off.
  #   --enable-draft        :351 default.
  #   --enable-renaming     :378 default: symbols carry the version suffix.
  #   --disable-tracing     :394 default off.
  #   --disable-plugins     :414 default off (plugins=false); --enable-dyload
  #                         :432 default, ignored with plugins off.
  #   --disable-rpath       :468 default is "only if necessary"; none is added.
  #   --disable-weak-threads :579 default off.
  #   --enable-extras, --enable-icuio, --enable-tools :914, :923, :956 default
  #                         true: the extras (uconv), libicuio and the data tools
  #                         are built and installed.
  #   --disable-layoutex    :934 default off (needs icu-le-hb, which is gone);
  #                         --enable-layout is an error (:949), so it is not
  #                         passed.
  #   --disable-fuzzer      :967 default off.
  #   --with-data-packaging=library  :979-1020 `auto` resolves to library when
  #                         shared libraries are built, stated.
  #   --disable-tests, --disable-samples  :1084, :1095 default ON: they are NOT
  #                         built (they would double the build time).
  env = {
    ARGS = [
      "--prefix={{prefix}}",
      "--enable-shared",
      "--disable-static",
      "--enable-release",
      "--disable-debug",
      "--enable-icu-config",
      "--disable-auto-cleanup",
      "--enable-draft",
      "--enable-renaming",
      "--disable-tracing",
      "--disable-plugins",
      "--disable-rpath",
      "--disable-weak-threads",
      "--enable-extras",
      "--enable-icuio",
      "--enable-tools",
      "--disable-layoutex",
      "--disable-fuzzer",
      "--with-data-packaging=library",
      "--disable-tests",
      "--disable-samples",
    ]
  }

  script = [
    # The tarball's top directory holds `source/`; the build is in there.
    "cd source && ./configure $ARGS",
    "cd source && make --jobs {{hw.concurrency}}",
    "cd source && make install",
  ]
}

# source/tools holds icuinfo, genrb, icupkg and makeconv; source/extra holds
# uconv; Makefile.in:69 and :194 install icu-config when INSTALL_ICU_CONFIG.
provides = [
  "bin/genrb",
  "bin/icu-config",
  "bin/icuinfo",
  "bin/icupkg",
  "bin/makeconv",
  "bin/uconv",
]

test {
  dependencies = {
    "gnu.org/gcc"                = "*"
    "freedesktop.org/pkg-config" = "*"
  }

  script = [
    "test -f {{prefix}}/include/unicode/utypes.h",
    "pkg-config --exists icu-uc icu-i18n icu-io",
    "test \"$(pkg-config --modversion icu-uc)\" = \"{{version.raw}}\"",
    "icuinfo >/dev/null",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <unicode/uchar.h>
#include <unicode/ustring.h>
#include <unicode/uversion.h>

int main(void) {
  UVersionInfo version;
  char text[U_MAX_VERSION_STRING_LENGTH];
  UChar in[] = {0x00e9, 0};  /* e with an acute accent */
  UChar out[4];
  UErrorCode status = U_ZERO_ERROR;

  u_getVersion(version);
  u_versionToString(version, text);
  printf("ICU %s\n", text);

  u_strToUpper(out, 4, in, -1, "", &status);
  if (U_FAILURE(status) || out[0] != 0x00c9) {
    puts("u_strToUpper failed");
    return 1;
  }
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o icucheck $(pkg-config --cflags --libs icu-uc)"
    },
    "./icucheck",
  ]
}

provenance {
  read = [
    "source/configure.ac",         # :91-126 icu-config, debug, release; :270-296 shared, static; :330-448 auto-cleanup, draft, renaming, tracing, plugins, dyload; :468-477 rpath; :579 weak-threads; :913-975 extras, icuio, layoutex, layout, tools, fuzzer; :979-1057 data packaging; :1084-1105 tests, samples
    "source/common/unicode/uvernum.h", # :135 U_ICU_VERSION "79.1"
    "LICENSE",                     # :1 UNICODE LICENSE V3
    "source/Makefile.in",          # :51, :69, :194 INSTALL_ICU_CONFIG
  ]

  consulted = [
    "SHASUM512.txt from the release page",
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the test
block has been run, on either platform.

The tarball is NOT signed-checked: SHASUM512.txt matches the pinned bytes (as a
SHA-512), and the .asc files were not verified.

The `provides` list names the programs whose source directories were seen
(source/tools/{icuinfo,genrb,icupkg,makeconv}, source/extra/uconv) and
icu-config; ICU installs more (gencnval, gendict, genbrk, ...), not listed. The
pkg-config file names (icu-uc, icu-i18n, icu-io) are the ones ICU's own
documentation uses; source/config/icu.pc.in was seen but the generation rule
that names them was not read, so those test lines are the first to check on a
run.

The `strip`/`ignore` pair was run through `zpkb versions` on a draft: it lists
79.1, 78.3, 78.2, 78.1 (and, before the ignore was added, 77.1 and older with
hyphenated tags).
EOT
}
