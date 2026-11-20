# serf — Apache Serf, a high-performance asynchronous HTTP client library.
#
# ⛔ WRITTEN FROM SERF'S OWN FILES at 1.3.10, continuing go-zpkg/packages#440
# step 1. It was a seven-line fragment naming six dependencies and nothing
# else: no source, no build, no version. Subversion's recipe needs it.

summary = "Apache Serf: high-performance asynchronous HTTP client library"

# LICENSE is the Apache License 2.0 text ("Apache License / Version 2.0,
# January 2004", :1-2) and the SConstruct header (:4-19) is the ASF's standard
# "Licensed to the Apache Software Foundation … Apache License, Version 2.0".
license = "Apache-2.0"

versions {
  # ⛔ archive.apache.org, NOT downloads.apache.org. The mirror host keeps only
  # the current release (an index read on 2026-11-20 lists 1.3.10 alone, plus
  # KEYS), while the archive lists all 29 tarballs back to 0.1.0 — and an
  # archive URL is the one that still resolves after the next release moves
  # the current one out.
  url   = "https://archive.apache.org/dist/serf/"
  match = "/serf-\\d+\\.\\d+\\.\\d+\\.tar\\.bz2/"
  strip = [
    "/^serf-/",
    "/\\.tar\\.bz2$/",
  ]
}

distributable {
  url              = "https://archive.apache.org/dist/serf/serf-{{version.raw}}.tar.bz2"
  strip-components = 1

  # Fetched with `zpkb sourcepin`: 147744 bytes, and the digest below.
  #
  # TWO WITNESSES, AND THEY ARE INDEPENDENT:
  #
  #   1. The detached signature serf-1.3.10.tar.bz2.asc verifies against
  #      key E7B2A7F4EC28BE9FF8B38BA4B64FFF1209F9FA74, Evgeny Kotkov
  #      <evgeny.kotkov@visualsvn.com>, signed 2023-05-26T08:23:54Z. The key
  #      was taken from https://downloads.apache.org/serf/KEYS (Apache's own
  #      published keys file, 835 KB, 1 key of it used) — no keyserver was
  #      asked.
  #
  #   2. The release's own published checksum, serf-1.3.10.tar.bz2.sha512, is
  #      19165274d35c694935cda33f99ef92a7663a5d9c540fb7fd6792aa0efe39941b2fa87ff8b61afd060c6676baec634fd33dc2e9d34ecbee45ed99dfaed077802c
  #      and `shasum -a 512` of the bytes fetched here gives the same value.
  #
  # ⛔ 1.3.10 IS THE NEWEST `versions` RESOLVES (2023-05-31); older releases
  # resolve too and carry no digest here. Nothing newer exists to pin.
  #
  # ⛔ NO `sha` FIELD: it means "where the expected SHA-256 is PUBLISHED", and
  # Apache publishes SHA-512, not SHA-256. The signature URL lives in
  # `provenance`, since `sig` is read by nothing (go-zpkg/zpkb#282).
  sha256 = {
    "1.3.10" = "be81ef08baa2516ecda76a77adf7def7bc3227eeb578b9a33b45f7b41dc064e6"
  }
}

# What the library links, from the project's own build file rather than from
# the fragment this replaces. SConstruct:273 appends `ssl crypto z`; :382-390
# runs apr-1-config and apu-1-config for APR and APR-util; :400-406 links
# GSSAPI through `krb5-config` when GSSAPI= is given.
#
# libexpat is kept from the fragment but is NOT named by SConstruct: it is
# reached only through apu-1-config's `--libs`/`--link-ld` output (:384), which
# serf-1.pc then republishes in Libs.private (:425), so a consumer that links
# serf statically needs it on the line.
dependencies = {
  "apache.org/apr"      = "^1"
  "apache.org/apr-util" = "^1"
  "kerberos.org"        = "^1.20"
  "libexpat.github.io"  = "^2"

  # ⛔ `^3`, NOT WIDENED: CHANGES:2 is "Support for OpenSSL 3" and nothing in
  # this project says OpenSSL 4 was ever tried (see curl.se's recipe for the
  # reason an unmeasured TLS-major widening is refused).
  "openssl.org" = "^3"
  "zlib.net"    = "^1.2"
}

build {
  # SCons is the project's only build system (README:18-28 "Apache Serf uses
  # SCons 2.3 for its build system"), and it is a Python program.
  dependencies = {
    "python.org" = "*"
    "scons.org"  = "*"
  }

  env {
    ARGS = [
      "PREFIX={{prefix}}",

      # apr-1-config and apu-1-config are looked up as $APR/bin/apr-1-config
      # (SConstruct:371-376, README:44-46), so the install ROOT is what is
      # passed, not the script.
      "APR={{deps.apache.org/apr.prefix}}",
      "APU={{deps.apache.org/apr-util.prefix}}",
      "OPENSSL={{deps.openssl.org.prefix}}",

      # ⛔ ZLIB= IS A NO-OP ON UNIX AND IS PASSED ANYWAY FOR THE DECLARATION'S
      # SAKE: SConstruct:199 reads it, and :343-350 are the only lines that use
      # it, inside `if sys.platform == 'win32'`. On a unix the library comes in
      # as a bare `-lz` (:273, :425) with no search path of its own, so the
      # prefix has to be handed to the compiler and linker explicitly:
      "ZLIB={{deps.zlib.net.prefix}}",
      "CPPFLAGS=-I{{deps.zlib.net.prefix}}/include",
      "LINKFLAGS=-L{{deps.zlib.net.prefix}}/lib",

      # GSSAPI is a path whose bin/krb5-config the build runs (:202-206,
      # :400-406); it defines SERF_HAVE_GSSAPI. With no value (default None,
      # :103) serf is built WITHOUT Kerberos/SPNEGO authentication, so the
      # dependency above would be declared and unused.
      "GSSAPI={{deps.kerberos.org.prefix}}",

      # ⛔ `-std=c89` IS APPENDED UNCONDITIONALLY for a GNU-compatible compiler
      # (:259-260), and a current compiler makes a pointer-type mismatch in a
      # C89 build an error where it was a warning. This demotes that one
      # diagnostic to a warning; nothing else is relaxed.
      "CFLAGS=-Wno-incompatible-pointer-types",
    ]
  }

  # ⛔ THE ONE EDIT TO THE SOURCE, AND WITHOUT IT SCONS CANNOT FIND A COMPILER.
  # SConstruct:164 is `env = Environment(variables=opts,` with no ENV
  # argument, so SCons runs every compile with its own minimal default PATH and
  # discards the builder's — the staged toolchain is invisible to it. Passing
  # `ENV=os.environ` is SCons's documented way to hand the real one through.
  # The grep is the guard: if a later release rewords that line the sed would
  # silently change nothing, so the build is made to fail there instead.
  script = <<EOT
sed -i.bak -e 's/env = Environment(variables=opts,/env = Environment(ENV=os.environ, variables=opts,/' SConstruct
grep -q 'ENV=os.environ' SConstruct
scons -j {{ hw.concurrency }} $ARGS
scons install
EOT
}

# serf installs no program: SConstruct:441-464 installs the static and shared
# libraries, the three headers (:29-32, HEADER_FILES) under include/serf-1, and
# serf-1.pc under lib/pkgconfig. The test block asserts those instead.

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    # The .pc file is generated by the build (SConstruct:417-427, from
    # build/serf.pc.in) and carries @VERSION@ = MAJOR.MINOR.PATCH read out of
    # serf.h (:175-183), so this is the build's own statement of what it made.
    "test \"$(pkg-config --modversion serf-1)\" = \"{{version.raw}}\"",
    "test -f {{prefix}}/include/serf-1/serf.h",
    "test -f {{prefix}}/include/serf-1/serf_bucket_types.h",
    "test -f {{prefix}}/include/serf-1/serf_bucket_util.h",
    "test -f {{prefix}}/lib/libserf-1.a",

    # THROUGH THE LIBRARY, which is what subversion links. serf_lib_version
    # (serf.h:1102-1105) reports what the compiled library says, and the
    # header's SERF_*_VERSION macros (:1068-1070) say what it was built
    # against — a disagreement is how a build picks up another serf.
    # serf.h includes APR's headers, so apr-1 is asked of pkg-config as well.
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <serf.h>

int main(void) {
  int major = 0, minor = 0, patch = 0;
  serf_lib_version(&major, &minor, &patch);
  if (major != SERF_MAJOR_VERSION || minor != SERF_MINOR_VERSION ||
      patch != SERF_PATCH_VERSION) {
    printf("header %s but library %d.%d.%d\n", SERF_VERSION_STRING,
           major, minor, patch);
    return 1;
  }
  printf("libserf %d.%d.%d\n", major, minor, patch);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o libcheck $(pkg-config --cflags --libs serf-1 apr-1 apr-util-1)"
    },
    "./libcheck",
  ]
}

provenance {
  read = [
    "README",          # :18-28 SCons is the build system; :34 the scons command line with APR/APU/OPENSSL/PREFIX; :44-49 apr-1-config is looked up under $APR/bin and OPENSSL's include/lib; :74 `scons install`
    "SConstruct",      # :164 Environment() without ENV; :259-260 -std=c89 under GCC; :273 LIBS ssl crypto z; :199 ZLIB read but used only :343-350 (win32); :371-390 apr/apu-config; :400-406 GSSAPI; :417-427 serf-1.pc; :441-464 install targets; :454-457 darwin install_name_tool -id
    "serf.h",          # :1068-1075 version macros; :1102 serf_lib_version
    "build/serf.pc.in", # Requires.private libssl libcrypto; Libs.private @LIBS@; Cflags -I${includedir}
    "CHANGES",         # :2 "Support for OpenSSL 3"
    "LICENSE",         # Apache License 2.0, :1-2
    "NOTICE",
  ]

  consulted = [
    "https://downloads.apache.org/serf/",
    "https://downloads.apache.org/serf/KEYS",
    "https://downloads.apache.org/serf/serf-1.3.10.tar.bz2.asc",
    "https://downloads.apache.org/serf/serf-1.3.10.tar.bz2.sha512",
    "https://archive.apache.org/dist/serf/",
    "pkgxdev/pantry projects/apache.org/serf/package.yml", # the ENV=os.environ edit and the -Wno-incompatible-pointer-types flag were first met there; both re-derived above from SConstruct
  ]

  note = <<EOT
SCons build, written from SConstruct and the README. Nothing was converted.

Signature, for the record:

  https://downloads.apache.org/serf/serf-1.3.10.tar.bz2.asc
  key         https://downloads.apache.org/serf/KEYS (Apache's published keys)
  identity    Evgeny Kotkov <evgeny.kotkov@visualsvn.com>
  fingerprint E7B2A7F4EC28BE9FF8B38BA4B64FFF1209F9FA74
  checked     when the digest was recorded, not at every build

The fingerprint was read off the key in KEYS whose id (B64FFF1209F9FA74) the
signature names; the first attempt passed the whole 835 KB KEYS file to
`zpkb sourcepin --key` and was refused with "unknown entity" although the key
is in it, so the one key was exported (gpg --export <fpr>) and passed alone.
That refusal is worth knowing about before the next Apache recipe.

⛔ DARWIN: SConstruct:239-241 links with `-install_name <build dir>/libserf-1.dylib`
and :444-457 corrects it to the final location with install_name_tool at
install time. fix-machos owns turning that into an @rpath reference, so the
recipe does not touch it.

⛔ NOT RUN: the build was written without a local build of the dependency
closure (apr, apr-util and kerberos.org are upstream recipes this tree does not
hold), so the build script is read-checked, not executed.
EOT
}
