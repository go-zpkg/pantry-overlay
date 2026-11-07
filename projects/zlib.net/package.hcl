# zlib — the reference implementation of DEFLATE (RFC 1951), the zlib wrapper
# (RFC 1950) and gzip (RFC 1952).
#
# ⛔ WRITTEN FROM ZLIB'S OWN BUILD SYSTEM, NOT CONVERTED. pkgxdev/pantry
# carries no licence, so it cannot seed this tree (go-zpkg/packages#431); the
# `provenance` block at the end of this file names the project's files this
# build was derived from, and the other distributions whose packaging was read
# for FACTS about the build. Upstream pkgx's own recipe for this project was
# deliberately NOT read — see the note.
#
# This is the first recipe of the sovereign pantry, so it is also the worked
# example: every non-obvious line below carries the reason, and the reason
# comes from a file somebody opened.

summary = "Lossless data-compression library: DEFLATE, zlib and gzip"
license = "Zlib"

versions {
  github = "madler/zlib"

  # v1.3.1.2 is a FOUR-component tag. It is a real upstream tag, and a version
  # with four parts is not a semver this resolver can order against the rest.
  ignore = ["/^v?\\d+\\.\\d+\\.\\d+\\.\\d+$/"]
}

distributable {
  # ⛔⛔ THE GITHUB RELEASE, NOT zlib.net, AND THIS IS THE ONE FACT NO READING
  # OF ZLIB ITSELF WOULD HAVE GIVEN. Two things are wrong with the obvious
  # https://zlib.net/zlib-{{version}}.tar.gz:
  #
  #   1. it is not stable per version — zlib.net serves only the CURRENT
  #      release at that path and rotates older ones into fossils/, so a
  #      recipe pinned there stops resolving the day 1.5 ships;
  #   2. nixpkgs records that the zlib.net path "can encounter a captcha,
  #      causing hash mismatch" — i.e. the host sometimes serves an HTML
  #      page with a 200, which a checksum catches and a careless build does
  #      not.
  #
  # Homebrew uses zlib.net as its primary and the GitHub release as its
  # mirror; nixpkgs uses the GitHub release FIRST and fossils second. The
  # tag-addressed release is the only one of the three that is stable for an
  # arbitrary version, so it is the one here.
  url            = "https://github.com/madler/zlib/releases/download/v{{version.raw}}/zlib-{{version.raw}}.tar.gz"
  strip-components = 1

  # Verified here by downloading the release and hashing it, not taken from
  # another distribution's recipe. It agrees with the digest homebrew-core
  # records for the same file, which is a second opinion rather than the
  # source of this one.
  #
  # ⛔ PINNING MAKES THIS RECIPE FAIL-CLOSED: a version absent from this map is
  # REFUSED, not fetched unverified. That is intended as a security floor and
  # not merely as bookkeeping. zlib's own ChangeLog for 1.4 (4 Nov 2026) lists
  # "Fix gzwrite() buffer overflow (CVE-2026-85091)" and "Avoid out-of-bounds
  # pointer arithmetic in infback9() (CVE-2026-4738)", plus unnumbered fixes
  # for a write past the buffer in inflateGetDictionary(), a window write
  # overrun after inflateSync(), reads of uninitialised memory in
  # inflateBack(), and several vulnerabilities in contrib/minizip. At the time
  # of writing nixpkgs ships 1.3.2 with an out-of-tree patch for the first CVE
  # only, Spack's newest is 1.3.2, and pkgsrc is on 1.3.1. Adding an older
  # version here means deciding to ship those bugs, which should take an edit.
  sha256 = {
    "1.4" = "02dd159783677a749c04adbdd02b55b8a2bcc7e054f51b76b549199a916ad584"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  # ⛔ NO --static, AND NOT BECAUSE STATIC IS UNWANTED. zlib's configure is
  # hand-written and not autotools (Spack says so in its first comment, and
  # the script's own option parser shows it): `--static` is an ALIAS for
  # `--disable-shared`, so it SUBTRACTS the shared library rather than adding
  # the static one — and used after `--shared` it turns the shared build off
  # again. The static library is built unconditionally either way. So plain
  # --prefix yields libz.a AND the shared library, which is what a consumer of
  # this pantry expects; the wasip1 recipe passes --static precisely because
  # there it wants only the archive.
  #
  # Nothing else is passed. configure's defaults already put libdir at
  # ${prefix}/lib, includedir at ${prefix}/include and mandir at
  # ${prefix}/share/man, which are the paths this pantry wants, and
  # --sysconfdir / --localstatedir are accepted and then IGNORED with a notice,
  # so passing autotools habits here would read as configuration and do
  # nothing.
  script = [
    "./configure --prefix={{prefix}}",
    "make --jobs {{hw.concurrency}}",
    "make install",
  ]
}

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  # The installed surface first, from Makefile.in's install targets: the
  # archive, the headers, the man page and the pkg-config file. `make test` is
  # not available here — it runs in the BUILD tree against example and
  # minigzip, which `make install` does not install — so the acceptance check
  # is a consumer's: compile against the headers and round-trip real bytes.
  script = [
    "test -f {{prefix}}/lib/libz.a",
    "test -f {{prefix}}/include/zlib.h",
    "test -f {{prefix}}/lib/pkgconfig/zlib.pc",
    "pkg-config --exists zlib",
    {
      fixture = {
        # compress() and uncompress() with those signatures, and
        # ZLIB_VERSION, are declared in the zlib.h this build installs
        # (zlib.h:224, :1275, :1319 and the #define at :44).
        #
        # It asserts the HEADER and the LIBRARY agree on the version: a
        # mismatch there is how a build picks up a system zlib instead of the
        # one it just made, and macOS ships one, which is why Homebrew marks
        # this formula keg_only :provided_by_macos.
        content  = <<EOT
#include <stdio.h>
#include <string.h>
#include <zlib.h>

int main(void) {
  if (strcmp(ZLIB_VERSION, zlibVersion()) != 0) {
    printf("header %s but library %s\n", ZLIB_VERSION, zlibVersion());
    return 1;
  }

  const char text[] = "the quick brown fox jumps over the lazy dog";
  Bytef packed[256];
  uLongf packed_len = sizeof packed;
  if (compress(packed, &packed_len, (const Bytef *)text, sizeof text) != Z_OK) {
    puts("compress failed");
    return 1;
  }

  Bytef back[256];
  uLongf back_len = sizeof back;
  if (uncompress(back, &back_len, packed, packed_len) != Z_OK) {
    puts("uncompress failed");
    return 1;
  }

  if (back_len != sizeof text || memcmp(text, back, sizeof text) != 0) {
    puts("round trip did not return the input");
    return 1;
  }

  printf("zlib %s round-tripped %lu bytes\n", zlibVersion(), (unsigned long)sizeof text);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o roundtrip $(pkg-config --cflags --libs zlib)"
    },
    "./roundtrip",
  ]
}

provenance {
  # The project's OWN files this build was derived from.
  read = [
    "README",      # "./configure; make test", then "make install"
    "configure",   # the option list, the defaults, and which options are ignored
    "Makefile.in", # what install actually installs; LDCONFIG is wrapped in `|| true`
    "zlib.h",      # ZLIB_VERSION, zlibVersion(), compress(), uncompress()
    "ChangeLog",   # which release fixes which CVE
  ]

  # Other distributions' packaging of zlib, read for FACTS about the build.
  # A fact about the software has no author; their expression is not taken.
  consulted = [
    "homebrew-core Formula/z/zlib.rb",
    "nixpkgs pkgs/development/libraries/zlib/default.nix",
    "spack repos/spack_repo/builtin/packages/zlib/package.py",
    "pkgsrc devel/zlib/Makefile",
    "freebsd-ports and openbsd ports: measured to have NO zlib port",
  ]

  note = <<EOT
./configure --prefix then make install, as the README documents. Three things
came from the bibliography rather than from zlib: the GitHub release is the
only source path stable per version (and zlib.net can answer with a captcha
page under a 200); --static SUBTRACTS the shared library because the
hand-written configure aliases it to --disable-shared; and 1.4 is the release
that fixes CVE-2026-85091 and CVE-2026-4738, which every distribution read
here still predates.

Two facts recorded and deliberately NOT acted on, because neither has been
tested in this builder and an untested fix is worse than a noted one:
configure refers to /usr/bin/libtool on darwin, which nixpkgs substitutes with
ar; and nixpkgs notes the library sometimes installs as .so rather than .dylib
on darwin.

pkgxdev/pantry's own recipe for this project was NOT read. Its facts would be
as licit to use as anyone's, but this is the first recipe of a tree whose
reason to exist is that it owes that one nothing, and independence that can be
stated is worth more here than one more data point.
EOT
}
