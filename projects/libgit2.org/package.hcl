# libgit2.org — a portable, pure C implementation of the Git core methods,
# with the `git2` command-line tool. One of the projects the base-toolchain
# closure needed and this tree did not carry at all (`zpkb closure -build
# -require-standalone go-zpkg/base-toolchain`, 2026-11-20); cargo links it.
#
# ⛔ WRITTEN FROM LIBGIT2'S OWN FILES (go-zpkg/packages#431), at 1.9.7.
#
# ⭐⭐ WHAT WRITING IT FOUND: libgit2 picks three of its backends by looking at
# the build machine, and the upstream recipe pinned only the fourth (SSH).
# Every backend is named here, and the test reads each choice back from the
# installed library with git_libgit2_feature_backend().

summary = "libgit2: a portable, pure C implementation of the Git core methods"

# COPYING:1-19: GPL version 2 only ("the only valid version of the GPL as far
# as this project is concerned is _this_ particular version") with a LINKING
# EXCEPTION, "unlimited permission to link the compiled version of this library
# into combinations with other programs" — the text SPDX lists as
# GCC-exception-2.0. COPYING also licenses code this build COMPILES IN; only
# those are added, each read from its section:
#
#   MIT           SHA-1 collision detection (:1039, always), ntlmclient (:1292,
#                 USE_NTLMCLIENT is ON off macOS), llhttp (:1461, the builtin
#                 HTTP parser)
#   BSD-3-Clause  the bundled PCRE2 (:409-505), compiled because REGEX_BACKEND
#                 is pinned to builtin below
#   BSD-2-Clause  git_fs_path_basename_r, from Android (:1261-1288)
#   CC0-1.0       xoroshiro256** (:1209-1217)
#   LicenseRef-libgit2-wildmatch  Rich Salz's wildmatch notice (:1074-1098):
#                 a bespoke licence with an acknowledgement clause and no SPDX
#                 identifier
#
# NOT added, because this build does not compile them: deps/winhttp (LGPL-2.1,
# :513-531, Windows only), the bundled zlib (:366, zlib.net is used), the
# RFC 6234 SHA-256 (:1221, SHA-256 comes from OpenSSL here) and the OpenSSL
# header portions (:1102, the OpenSSL-Dynamic backend only).
license = "GPL-2.0-only WITH GCC-exception-2.0 AND MIT AND BSD-3-Clause AND BSD-2-Clause AND CC0-1.0 AND LicenseRef-libgit2-wildmatch"

versions {
  github = "libgit2/libgit2"
}

dependencies = {
  # Each named as the backend below, so each is FATAL when missing.
  "libssh2.org" = "^1"
  "openssl.org" = "*"
  "zlib.net"    = "*"
}

distributable {
  # GitHub's archive of the tag: the release publishes no assets at all, the
  # tag v1.9.7 is lightweight, and its commit 49e408b3 is unsigned. See
  # provenance.note.
  url              = "https://github.com/libgit2/libgit2/archive/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 7769162 bytes. Recorded with `zpkb sourcepin` and confirmed by a second,
  # independent fetch-and-hash.
  sha256 = {
    "1.9.7" = "1a4fbe7589e814777ae76b64734ad80f4ecad22cd33a22682a2aaea4ae5375e7"
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

      # ⛔ CMakeLists.txt:94 forces CMAKE_BUILD_TYPE to "Debug" when none is given.
      "-DCMAKE_BUILD_TYPE=Release",
      "-DBUILD_SHARED_LIBS=ON",
      # :23 builds the Clar suite by default; it is not installed.
      "-DBUILD_TESTS=OFF",
      # :24 the `git2` command-line tool, which upstream's pantry also ships.
      "-DBUILD_CLI=ON",

      # ⛔⛔ 1. HTTPS, NAMED. cmake/SelectHTTPSBackend.cmake:11-36: the default ""
      # becomes ON, and ON takes SecureTransport on macOS, otherwise OpenSSL IF
      # FOUND, otherwise mbedTLS if found — so the TLS library in the artifact
      # is whichever one the builder has. Named, :55-58 makes a missing OpenSSL
      # fatal. SHA-256 then follows it (cmake/SelectHashes.cmake:48-70); SHA-1
      # stays the bundled collision-detecting one (:10-11).
      "-DUSE_HTTPS=OpenSSL",

      # ⛔⛔ 2. REGEX, NAMED. cmake/SelectRegex.cmake:4-19: the default "" tries
      # regcomp_l (absent from glibc), then ANY PCRE the build machine has
      # (find_package(PCRE) on line 2 runs regardless), then the bundled PCRE2.
      # So on glibc the artifact links a builder's libpcre or none. `builtin` is
      # the bundled copy, the same on every builder.
      "-DREGEX_BACKEND=builtin",

      # ⛔⛔ 3. zlib: cmake/SelectZlib.cmake:12-27 with USE_BUNDLED_ZLIB OFF (the
      # default) looks for a system zlib and, if it finds none, prints a STATUS
      # line and compiles the bundled one. That fallback cannot be made fatal by
      # a flag, so zlib.net is declared and the test reads which one won.
      "-DUSE_BUNDLED_ZLIB=OFF",

      # 4. SSH: cmake/SelectSSH.cmake:6-28. `libssh2` is fatal when not found.
      # The default "" means NO SSH at all (:52-53).
      "-DUSE_SSH=libssh2",

      # The HTTP parser: `builtin` is already the default (CMakeLists.txt:38) and
      # never probes; named so a future default change is visible here.
      "-DUSE_HTTP_PARSER=builtin",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# src/cli/CMakeLists.txt:36-55: the git2_cli target, OUTPUT_NAME ${LIBGIT2_FILENAME}
# ("git2", CMakeLists.txt:52), installed to the bin directory.
provides = [
  "bin/git2",
]

test {
  # git_libgit2_feature_backend() (include/git2/common.h:205,
  # src/libgit2/libgit2.c:126-220) names the backend libgit2 was BUILT with,
  # so every pin above is read off the installed library, not inferred.
  fixture = <<EOT
#include <git2.h>
#include <stdio.h>
#include <string.h>

static int want(git_feature_t f, const char *name, const char *expected)
{
	const char *got = git_libgit2_feature_backend(f);
	if (got == NULL || strcmp(got, expected) != 0) {
		fprintf(stderr, "%s backend is %s, want %s\n", name, got ? got : "(none)", expected);
		return 1;
	}
	return 0;
}

int main(void)
{
	int bad = 0;
	git_libgit2_init();
	bad |= want(GIT_FEATURE_HTTPS, "HTTPS", "openssl");
	bad |= want(GIT_FEATURE_SSH, "SSH", "libssh2");
	bad |= want(GIT_FEATURE_REGEX, "regex", "builtin");
	bad |= want(GIT_FEATURE_COMPRESSION, "compression", "zlib");
	git_libgit2_shutdown();
	return bad;
}
EOT

  script = [
    "cc -x c $FIXTURE -x none -o features -I{{prefix}}/include -L{{prefix}}/lib -lgit2",
    {
      run = <<EOT
set -eu
LD_LIBRARY_PATH="{{prefix}}/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="{{prefix}}/lib:$${DYLD_LIBRARY_PATH:-}" ./features
EOT
    },
    "git2 --help > /dev/null",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                 # :19-94 every option and its default; :94 the Debug default
    "cmake/SelectHTTPSBackend.cmake", # :4-36 the auto-pick, :55-58 OpenSSL fatal
    "cmake/SelectRegex.cmake",        # :2-19 the auto-pick, PCRE from the builder
    "cmake/SelectZlib.cmake",         # :12-27 the silent fallback to the bundled zlib
    "cmake/SelectSSH.cmake",          # :6-28 libssh2 fatal, :52-53 "" means no SSH
    "cmake/SelectHashes.cmake",       # :10-11 SHA-1 builtin, :48-70 SHA-256 follows HTTPS
    "cmake/DefaultCFlags.cmake",      # :92-96 ENABLE_REPRODUCIBLE_BUILDS only changes static archives; shared here
    "include/git2/common.h",          # :146-170 the feature bits, :205 git_libgit2_feature_backend
    "src/libgit2/libgit2.c",          # :126-220 the backend names the test compares against
    "src/cli/CMakeLists.txt",         # :36-55 the git2 tool
    "COPYING",                        # every section cited in the licence comment
  ]

  consulted = [
    # Read for facts only: URL shape, libssh2 as the SSH provider, and that its
    # test asserted SSH alone. Nothing copied.
    "pkgxdev/pantry projects/libgit2.org/package.yml",
  ]

  note = <<EOT
⛔⛔ THE UPSTREAM RECIPE PINNED ONE BACKEND OF FOUR. It passed -DUSE_SSH=ON and
asserted GIT_FEATURE_SSH; HTTPS, regex and zlib were left to the build
machine. On a builder with mbedTLS and no OpenSSL, libgit2 links mbedTLS; on
one with libpcre, its regex engine is that libpcre; on one without zlib
headers, it compiles its own zlib and the .pc stops naming zlib. None of that
fails a build or a test that checks SSH only.

⚠ THE RUNG IS A SINGLE HOST, STATED. The v1.9.7 release has no assets, so
there is no maintainer-built tarball, no checksum file and no signature; the
tag is lightweight and the commit it names (49e408b3, "v1.9.7: update version
numbers", Edward Thomson) is unsigned. The digest records GitHub's generated
archive of that tag, fetched twice independently.

⛔ NOT BUILT. No session here can run the factory.
EOT
}
