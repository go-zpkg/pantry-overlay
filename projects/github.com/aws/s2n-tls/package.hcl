# s2n-tls — AWS's TLS implementation, the TLS backend of aws-c-io
#
# ⛔ WRITTEN FROM S2N-TLS'S OWN FILES at v1.7.13 (go-zpkg/packages#440 step 1), one link of the
# AWS Common Runtime chain that aws-sdk-cpp needs (aws-sdk-cpp -> aws-crt-cpp -> aws-c-io -> s2n).
#
# ⭐ WHY ONE VERSION. aws-sdk-cpp 1.11.935 pins crt/aws-crt-cpp to 07b1d9a9 = tag v0.44.4, and
# that tag's crt/ directory pins s2n to commit e7ce83a2 = tag v1.7.13 (GitHub contents API on
# both). aws-crt-cpp's .gitmodules names awslabs/s2n.git, which GitHub redirects to aws/s2n-tls,
# so the owner here is aws. The versions block resolves ONLY that tag, so
# --check-newest-pinned cannot demand a newer one that no other recipe was read against.
#
# ⭐ libcrypto: the tree's openssl.org, found by cmake/modules/Findcrypto.cmake (find_library with
# CMAKE_PREFIX_PATH hints, CMakeLists.txt:276 find_package(crypto REQUIRED)). AWS-LC (v5.12.0 is
# what aws-crt-cpp pins) is not in this tree and is NOT used.

summary = "AWS's TLS implementation (s2n-tls), the TLS backend of aws-c-io"

# LICENSE opens with "Apache License Version 2.0, January 2004".
license = "Apache-2.0"

versions {
  github = "aws/s2n-tls/tags"
  strip  = ["/^v/"]

  # Only 1.7.13; see the header. Negative lookahead, as mysql.com does.
  ignore = ["/^(?!1\\.7\\.13$)/"]
}

distributable {
  # No stored release asset, so the generated tag archive.
  url              = "https://github.com/aws/s2n-tls/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 1.7.13: 4975331 bytes, fetched with `zpkb sourcepin`. The project publishes neither a
  # signature nor a checksum file, so the second witness is a second independent fetch from
  # https://codeload.github.com/aws/s2n-tls/tar.gz/refs/tags/v1.7.13: same bytes, same digest.
  sha256 = {
    "1.7.13" = "bf60fe631eebb79ed9a0b9b553460a4017dd2547269292ce3e9e2ac61c97dea2"
  }
}

build {
  dependencies = {
    "cmake.org"    = "*"
    "gnu.org/make" = "*"
    "openssl.org"  = "^3"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_LIBDIR=lib",

      # CMakeLists.txt:276 find_package(crypto REQUIRED): Findcrypto.cmake looks under CMAKE_PREFIX_PATH.
      "-DCMAKE_PREFIX_PATH={{deps.openssl.org.prefix}}",

      # No type given to add_library (CMakeLists.txt:131), so BUILD_SHARED_LIBS decides: shared.
      "-DBUILD_SHARED_LIBS=ON",

      # CMakeLists.txt:42: default ON (unit tests); not installed, so OFF.
      "-DBUILD_TESTING=OFF",

      # CMakeLists.txt:22: let Findcrypto search for the libcrypto, which is how the openssl prefix is found.
      "-DSEARCH_LIBCRYPTO=ON",

      # CMakeLists.txt:24: default ON; a different compiler than upstream's CI must not fail on a warning.
      "-DUNSAFE_TREAT_WARNINGS_AS_ERRORS=OFF",

      # CMakeLists.txt:27, :29, :32, :33, :35.
      "-DS2N_WERROR_ALL=OFF",
      "-DS2N_INTERN_LIBCRYPTO=OFF",
      "-DS2N_LTO=OFF",
      "-DS2N_STACKTRACE=ON",
      "-DS2N_OVERRIDE_LIBCRYPTO_RAND_ENGINE=OFF",

      # CMakeLists.txt:37: default OFF. ON on purpose: a libcrypto that the feature probes cannot link
      # to is an error instead of a silently reduced s2n-tls.
      "-DS2N_ENFORCE_PROPER_LIBCRYPTO_FEATURE_PROBE=ON",

      # CMakeLists.txt:41, :43-47: coverage and integration tests, the s2nc/s2nd tools, a shared
      # libcrypto in Findcrypto (the AWS-LC path) and a distribution-packaged AWS-LC. All OFF.
      "-DCOVERAGE=OFF",
      "-DS2N_INTEG_TESTS=OFF",
      "-DS2N_FAST_INTEG_TESTS=OFF",
      "-DS2N_INSTALL_S2NC_S2ND=OFF",
      "-DS2N_USE_CRYPTO_SHARED_LIBS=OFF",
      "-DS2N_AWSLC_DIST_PKG=OFF",

      # CMakeLists.txt:48-50: sanitizers and seccomp.
      "-DTSAN=OFF",
      "-DASAN=OFF",
      "-DSECCOMP=OFF",

      # CMakeLists.txt:173 and :196 read these but do not declare them with option(); stated OFF.
      "-DS2N_FUZZ_TEST=OFF",
      "-DS2N_BLOCK_NONPORTABLE_OPTIMIZATIONS=OFF",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# A library: s2nc and s2nd are not installed (S2N_INSTALL_S2NC_S2ND=OFF).
provides = []

test {
  script = [
    # api/s2n.h is installed to include/ (CMakeLists.txt:833).
    "test -f {{prefix}}/include/s2n.h",
    # The package file the dependants find_package() (CMakeLists.txt:866-872).
    "test -f {{prefix}}/lib/s2n/cmake/s2n-config.cmake",
  ]
}

provenance {
  read = [
    "CMakeLists.txt # :22-50 options; :131 add_library; :173-196 S2N_FUZZ_TEST and S2N_BLOCK_NONPORTABLE_OPTIMIZATIONS; :241 CMAKE_MODULE_PATH; :276 find_package(crypto); :398 feature-probe check; :524 BUILD_TESTING; :833 header install; :866-875 cmake package install",
    "cmake/modules/Findcrypto.cmake # find_library with CMAKE_PREFIX_PATH hints",
    "LICENSE",
  ]

  consulted = [
    "https://github.com/aws/aws-sdk-cpp/tree/1.11.935/crt",
    "https://github.com/awslabs/aws-crt-cpp/tree/v0.44.4/crt",
  ]

  note = <<EOT
Written, not converted. Version chain read with the GitHub contents API: aws-sdk-cpp 1.11.935
-> aws-crt-cpp 07b1d9a9 (v0.44.4) -> s2n e7ce83a2 (v1.7.13).
The libcrypto is OpenSSL 3, not AWS-LC: s2n-tls supports it, but that pairing was not exercised here.

⛔ NOT BUILT. The build and test blocks were not run in this session; the recipe is
checked by `zpkb lint` only.
EOT
}
