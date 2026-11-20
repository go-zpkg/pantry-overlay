# github.com/upa/mscp — mscp: copy files over multiple SSH connections in
# parallel (an scp that uses several libssh sessions at once).
#
# ⛔ WRITTEN FROM MSCP'S OWN FILES (go-zpkg/packages#431), at 0.2.4, from the
# release tarball's CMakeLists.txt and the libssh it VENDORS under libssh/
# (CMakeLists.txt:74 `add_subdirectory(libssh)`, built static, never the
# system's libssh).
#
# ⭐⭐ WHAT WRITING IT FOUND: mscp is two CMake projects in one, and the second
# one is the vendored libssh, whose own options decide, on the build machine:
#
#   GSSAPI  libssh/CMakeLists.txt:67-69 `find_package(GSSAPI)` is not REQUIRED:
#           Kerberos login exists only if the builder has krb5 headers.
#   NaCl    :71-76 `find_package(NaCl)` and, when absent, `WITH_NACL` quietly
#           goes OFF (curve25519 then comes from OpenSSL / the internal code).
#   Git     mscp's own CMakeLists.txt:10-26 runs `git describe` and bakes the
#           result into `mscp -h`; inside any enclosing git checkout that is
#           the CHECKOUT's tag, not the release's.
#
# Everything libssh makes optional is named below. OpenSSL and zlib are
# REQUIRED by libssh (libssh/CMakeLists.txt:45-56), so a missing one is fatal.

summary = "mscp: transfer files over multiple SSH connections (scp, faster)"

# LICENSE:1-2 is the GNU GPL version 3 text. The vendored libssh/COPYING is the
# LGPL version 2.1, and libssh is compiled in (static). The per-file "or any
# later version" grants were not read, so "-only" is the claim COPYING's own
# text supports.
license = "GPL-3.0-only AND LGPL-2.1-only"

versions {
  github = "upa/mscp"
}

dependencies = {
  # libssh/CMakeLists.txt:45-56: find_package(ZLIB REQUIRED) and
  # find_package(OpenSSL 1.1.1 REQUIRED), both fatal when missing.
  "openssl.org" = "^3"
  "zlib.net"    = "^1.2.11"
}

distributable {
  # The maintainer-built release asset (it carries the libssh sources inside),
  # not GitHub's archive of the tag, which would not.
  url              = "https://github.com/upa/mscp/releases/download/v{{version.raw}}/mscp-{{version.raw}}.tar.gz"
  strip-components = 1

  # 1007441 bytes. Recorded with `zpkb sourcepin` and confirmed by a second,
  # independent fetch-and-hash (curl + shasum).
  sha256 = {
    "0.2.4" = "d3b756e96b21e6bfced63d296c0fe1a92a42c13aec6fcd74c897598cdc4a8e5d"
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
      # CMakeLists.txt sets no default build type: an unset one compiles with
      # no optimisation flags at all.
      "-DCMAKE_BUILD_TYPE=Release",

      # ⛔⛔ 1. GSSAPI (libssh/CMakeLists.txt:67-69, DefineOptions.cmake:1).
      # Refused: no Kerberos library is in this recipe's closure, so whether
      # `mscp` can do GSSAPI would be the builder's choice. (mscp itself turns
      # it off only for its conan build, CMakeLists.txt:69-73.)
      "-DWITH_GSSAPI=OFF",

      # ⛔⛔ 2. libnacl (libssh/CMakeLists.txt:71-76, DefineOptions.cmake:22):
      # refused, same reason; curve25519 comes from the bundled code.
      "-DWITH_NACL=OFF",

      # ⛔⛔ 3. The build version string (CMakeLists.txt:10-26): refuse the Git
      # lookup so `mscp -h` says the release, wherever the build runs.
      "-DCMAKE_DISABLE_FIND_PACKAGE_Git=ON",

      # libssh's other defaults that change the artifact, named so a change of
      # default is visible: TLS stack is OpenSSL (DefineOptions.cmake:8-9
      # GCRYPT and MBEDTLS OFF), no PKCS#11 (:14-15), no unit tests (:16-19).
      "-DWITH_GCRYPT=OFF",
      "-DWITH_MBEDTLS=OFF",
      "-DWITH_PKCS11_URI=OFF",
      "-DWITH_PKCS11_PROVIDER=OFF",
      "-DUNIT_TESTING=OFF",

      # mscp's own switches (CMakeLists.txt:40-60), all OFF by default:
      # -static link, conan, podman.
      "-DBUILD_STATIC=OFF",
      "-DBUILD_CONAN=OFF",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }} --target mscp",
    "cmake --install build",
  ]
}

# CMakeLists.txt:136 install(TARGETS mscp RUNTIME DESTINATION bin).
provides = [
  "bin/mscp",
]

test {
  # src/main.c:24-26 prints "mscp " MSCP_BUILD_VERSION; with the Git lookup
  # refused, CMakeLists.txt:23-26 makes that "v" + VERSION.
  script = [
    {
      run = <<EOT
set -eu
mscp -h > help.txt 2>&1 || true
grep -q 'mscp v{{version.raw}}' help.txt
EOT
    },
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                # :10-26 Git version, :40-60 switches, :63-74 vendored libssh, :136 install
    "libssh/CMakeLists.txt",         # :45-56 zlib/openssl required, :67-76 GSSAPI and NaCl optional
    "libssh/DefineOptions.cmake",    # :1-28 every libssh option and its default
    "src/main.c",                    # :24-26 the version line the test reads
    "LICENSE",
    "libssh/COPYING",
  ]

  consulted = [
    # Read for facts only: that the release tarball is the right source and
    # that openssl and zlib are the dependencies.
    "pkgxdev/pantry projects/github.com/upa/mscp/package.yml",
  ]

  note = <<EOT
⚠ THE RUNG IS A SINGLE HOST, STATED. The tarball is a GitHub release asset
with no signature and no checksum file; the digest agreed between the
builder's fetcher and curl + shasum.

⚠ The tarball ships patch/libssh-*.patch files next to the vendored libssh;
whether the vendored tree has them applied, and which libssh release it is,
was not determined here, and the recipe does not depend on the libssh.org
recipe.

⛔ NOT BUILT. No session here can run the factory.
EOT
}
