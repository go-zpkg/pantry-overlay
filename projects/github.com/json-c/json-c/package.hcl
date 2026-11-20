# json-c — a C library for building and parsing JSON.
#
# ⛔ WRITTEN FROM JSON-C'S OWN FILES at 0.19 (go-zpkg/packages#440 step 1).
# isc.org/bind9 names `github.com/json-c/json-c` as a dependency and no recipe
# existed.

summary = "C library to build and parse JSON"

# COPYING is the MIT text, twice: "Copyright (c) 2009-2012 Eric Haszlakiewicz"
# and "Copyright (c) 2004, 2005 Metaparadigm Pte Ltd".
license = "MIT"

versions {
  # Tags are `json-c-0.19-20260627`: the version, a dash and the release date.
  github = "json-c/json-c"
  strip = [
    "/^json-c-/",
    "/-\\d{8}$/",
  ]
}

distributable {
  # A stored release asset of the GitHub release json-c-0.19-20260627 (the
  # plain archive, with its docs, beside a -nodoc one).
  url              = "https://github.com/json-c/json-c/releases/download/{{version.tag}}/json-c-{{version.raw}}.tar.gz"
  strip-components = 1

  # 0.19: 462232 bytes. The project publishes NO signature, so the second
  # witnesses are the digest GitHub computed at upload and a second copy of the
  # same file on the project's own bucket:
  #
  #   - the release API says the asset's digest is sha256:37ad0249…26de, which
  #     is the digest below;
  #   - https://s3.amazonaws.com/json-c_releases/releases/json-c-0.19.tar.gz
  #     (the project's historical download location, the one its README
  #     points at) serves the byte-identical file, and its S3 ETag is the MD5
  #     5678f1373ba51e0041b574c0411c696b, which is the MD5 of the file fetched.
  sha256 = {
    "0.19" = "37ad0249902e301bd9052bf712e511fcc6acff4ecaad4b5900aad9ce564e26de"
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
      "-DCMAKE_BUILD_TYPE=Release",

      # CMakeLists.txt:595-599 install into ${CMAKE_INSTALL_LIBDIR}, which
      # GNUInstallDirs makes lib64 on some Linux builders; pinned to lib.
      "-DCMAKE_INSTALL_LIBDIR=lib",

      # CMakeLists.txt:45-46: both default ON; named so it is stated. The
      # shared library is what bind9 links.
      "-DBUILD_SHARED_LIBS=ON",
      "-DBUILD_STATIC_LIBS=ON",

      # CMakeLists.txt:70 and :656: the apps are a test program set, and
      # apps/CMakeLists.txt:122 says "it is intentional that there are no
      # install instructions here". OFF only saves the build time.
      "-DBUILD_APPS=OFF",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# ⚠ NO `provides`: the installs are CMakeLists.txt:595 (the library),
# :603-617 (cmake package files), :646 (json-c.pc) and :648 (the headers into
# include/json-c); there is no program.

test {
  script = [
    "test -f {{prefix}}/include/json-c/json.h",
    "test -f {{prefix}}/lib/pkgconfig/json-c.pc",
    "pkg-config --exists json-c",
    "test \"$(pkg-config --modversion json-c)\" = {{version.raw}}",
    "ls {{prefix}}/lib/libjson-c.* > /dev/null",
  ]
}

provenance {
  read = [
    "CMakeLists.txt", # :10 project json-c VERSION 0.19; :45-46 BUILD_SHARED_LIBS/BUILD_STATIC_LIBS; :70 BUILD_APPS; :595-648 what is installed
    "json-c.pc.in",   # :6 Name: json-c; :11 Libs: -ljson-c
    "apps/CMakeLists.txt", # :122 the apps are not installed
    "COPYING",        # :2 and :24 the two MIT copyright notices
  ]

  consulted = [
    "https://github.com/json-c/json-c/releases/tag/json-c-0.19-20260627",
    "https://s3.amazonaws.com/json-c_releases/releases/",
  ]

  note = <<EOT
Written, not converted: no recipe existed.

No upstream signature exists for this archive; the pin rests on two things
that did not come from this recipe's fetch: GitHub's recorded asset digest
(sha256:37ad0249902e301bd9052bf712e511fcc6acff4ecaad4b5900aad9ce564e26de,
read from the release API) and the project's own bucket, which serves the same
bytes under an ETag equal to the file's MD5.

⛔ THE TEST BLOCK WAS NOT RUN ON A BUILT json-c IN THIS SESSION. Stated rather
than implied.
EOT
}
