# libssh.org — a C library implementing the SSH protocol, client and server
# side, with SFTP.
#
# ⛔ WRITTEN FROM LIBSSH'S OWN FILES (go-zpkg/packages#440 step 1), at 0.12.2.
#
# ⭐⭐ WHAT WRITING IT FOUND: three of libssh's backends are probed and silently
# dropped. NaCl is ON by default but `find_package(NaCl)` failing only turns it
# OFF (CMakeLists.txt:74-79); GSSAPI is ON by default and `find_package(GSSAPI)`
# is not REQUIRED (:69-72); symbol versioning needs the optional ABIMap
# (:91-96, :152). A builder that happens to have krb5 or libnacl would produce
# a different library from one that has not. Each is named below.

summary = "libssh: a C library implementing the SSH protocol (client, server, SFTP)"

# COPYING:1-2 is the GNU Lesser General Public License, version 2.1; the BSD
# file (:1 "Some parts are under the BSDv2 License", :4 Markus Friedl) covers
# parts of the code under a BSD licence.
license = "LGPL-2.1-only"

versions {
  # The GitHub mirror is stale (its tags stop at release-0-5-0); the project's
  # own tags live on its GitLab mirror.
  gitlab = "libssh/libssh-mirror"
  strip  = "/^libssh-/"
}

dependencies = {
  # CMakeLists.txt:51-58: with libgcrypt and mbedTLS both OFF, OpenSSL >= 1.1.1
  # is REQUIRED.
  "openssl.org" = "^3"
  # :47-49: WITH_ZLIB is ON by default and find_package(ZLIB REQUIRED).
  "zlib.net"    = "^1"
}

distributable {
  # The release tarball the project publishes (libssh.org/get-it), not a
  # generated archive of a tag.
  url              = "https://www.libssh.org/files/{{version.major}}.{{version.minor}}/libssh-{{version.raw}}.tar.xz"
  strip-components = 1

  # 759680 bytes, fetched with `zpkb sourcepin --sig auto`. The signature
  # (.tar.xz.asc, keyid 03D5DF8CFDD3E8E7) verifies against the key published at
  # https://www.libssh.org/files/0x03D5DF8CFDD3E8E7_libssh_libssh_org_gpgkey.asc,
  # whose fingerprint 88A228D89B07C2C77D0C780903D5DF8CFDD3E8E7 is the one
  # https://www.libssh.org/get-it/ states for releases 0.11.0 and later. No
  # keyserver was asked. The page publishes no checksum.
  sha256 = {
    "0.12.2" = "49560f677d96e3706a904ac2de1116e25f3680937d51e5c92198fcba4a1c1e9f"
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

      # CMakeLists.txt:51-58: the crypto backend is OpenSSL; the two others,
      # either of which would replace it, are named OFF.
      "-DWITH_GCRYPT=OFF",
      "-DWITH_MBEDTLS=OFF",
      "-DWITH_ZLIB=ON",

      # DefineOptions.cmake:3-4 and :32: protocol features, all ON.
      "-DWITH_SFTP=ON",
      "-DWITH_SERVER=ON",
      "-DWITH_GEX=ON",
      "-DWITH_PCAP=ON",

      # The optional libraries that would be picked up from the host
      # (CMakeLists.txt:69-79, :81-89, :91-96): named OFF so the result does not
      # move with the builder.
      "-DWITH_GSSAPI=OFF",
      "-DWITH_NACL=OFF",
      "-DWITH_FIDO2=OFF",
      "-DWITH_PKCS11_URI=OFF",
      "-DWITH_PKCS11_PROVIDER=OFF",
      "-DWITH_SYMBOL_VERSIONING=OFF",

      # Insecure or legacy options stay at their OFF defaults, stated.
      "-DWITH_INSECURE_NONE=OFF",
      "-DWITH_BLOWFISH_CIPHER=OFF",
      "-DWITH_ABI_BREAK=OFF",

      # Examples, tests, benchmarks and internal documentation are not part of
      # the installed library.
      "-DWITH_EXAMPLES=OFF",
      "-DWITH_BENCHMARKS=OFF",
      "-DWITH_INTERNAL_DOC=OFF",
      "-DUNIT_TESTING=OFF",
      "-DCLIENT_TESTING=OFF",
      "-DSERVER_TESTING=OFF",
      "-DGSSAPI_TESTING=OFF",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

test {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
    "gnu.org/gcc"                = "*"
  }

  # ssh_version(0) (src/misc.c:769-772) answers with the version of the library
  # actually linked, followed by "/openssl" and "/zlib" when built with them
  # (the backend and compression strings of src/misc.c:772). LIBSSH_VERSION is
  # the header's. Comparing both guards against a system libssh being linked
  # instead of the one just built.
  fixture = <<EOT
#include <stdio.h>
#include <string.h>
#include <libssh/libssh.h>
#include <libssh/sftp.h>
#include <libssh/server.h>

int main(void)
{
	const char *want = SSH_STRINGIFY(LIBSSH_VERSION);
	const char *got = ssh_version(0);
	if (got == NULL || strncmp(got, want, strlen(want)) != 0) {
		fprintf(stderr, "header %s but library %s\n", want, got ? got : "(null)");
		return 1;
	}
	if (strstr(got, "openssl") == NULL) {
		fprintf(stderr, "libssh was built without OpenSSL: %s\n", got);
		return 1;
	}
	if (strstr(got, "zlib") == NULL) {
		fprintf(stderr, "libssh was built without zlib: %s\n", got);
		return 1;
	}
	ssh_session s = ssh_new();
	ssh_bind b = ssh_bind_new();
	if (s == NULL || b == NULL) {
		fprintf(stderr, "ssh_new or ssh_bind_new failed\n");
		return 1;
	}
	ssh_bind_free(b);
	ssh_free(s);
	printf("libssh %s\n", got);
	return 0;
}
EOT

  script = [
    "pkg-config --exists libssh",
    "cc -x c $FIXTURE -x none -o features $(pkg-config --cflags --libs libssh)",
    "./features",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",          # :12 project version; :47-58 zlib and crypto backend; :69-79 GSSAPI, NaCl optional; :81-96 FIDO2, ABIMap; :99-107 config checks, subdirectories
    "DefineOptions.cmake",     # :1-46 every option and its default
    "include/libssh/libssh_version.h.cmake", # :30-39 LIBSSH_VERSION built from the three components
    "include/libssh/libssh.h", # :71 SSH_STRINGIFY; :859 ssh_version
    "src/misc.c",              # :769-772 ssh_version() returns the version plus backend strings
    "libssh.pc.cmake",         # the pkg-config file the test queries (Name: libssh)
    "COPYING",                 # :1-2 LGPL-2.1
    "BSD",                     # the separate BSD licence shipped beside it
  ]

  consulted = []

  note = <<EOT
Prior recipe: a fragment holding only dependencies (openssl.org, zlib.net). The
signing key is not in this repository; the signature was checked when the
digest was recorded (see distributable).

⛔ NOT BUILT. No session here can run the factory.
EOT
}
