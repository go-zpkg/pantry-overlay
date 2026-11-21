# aws-c-cal — AWS Common Runtime: cryptographic primitives (hashes, HMAC, AES, RSA, ECC) over the platform's own library
#
# ⛔ WRITTEN FROM AWS-C-CAL'S OWN FILES at 1.0.0 (go-zpkg/packages#440 step 1), one link of the
# AWS Common Runtime chain that aws-sdk-cpp needs (aws-sdk-cpp -> aws-crt-cpp -> the C
# libraries). Their recipes were missing, which is why aws-sdk-cpp stayed a fragment.
#
# ⭐ WHY ONE VERSION. aws-sdk-cpp 1.11.935 pins crt/aws-crt-cpp to 07b1d9a9 = tag
# v0.44.4, and that tag's crt/ directory pins this library to commit 2441187f = tag
# v1.0.0 (GitHub contents API on both, with .gitmodules naming the repository). The CRT
# libraries are released together and their ABI is not stable across tags, so the
# versions block resolves ONLY that tag; otherwise --check-newest-pinned would demand
# a newer one that no other recipe here was read against.

summary = "AWS Common Runtime: cryptographic primitives (hashes, HMAC, AES, RSA, ECC) over the platform's own library"

# LICENSE opens with "Apache License Version 2.0, January 2004".
license = "Apache-2.0"

versions {
  github = "awslabs/aws-c-cal/tags"
  strip  = ["/^v/"]

  # Only 1.0.0; see the header. Negative lookahead, as mysql.com does.
  ignore = ["/^(?!1\\.0\\.0$)/"]
}

distributable {
  # No stored release asset (the GitHub release lists none), so the generated tag archive.
  url              = "https://github.com/awslabs/aws-c-cal/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 1.0.0: 1703164 bytes, fetched with `zpkb sourcepin`. The project publishes neither a
  # signature nor a checksum file, so the second witness is a second independent fetch from
  # https://codeload.github.com/awslabs/aws-c-cal/tar.gz/refs/tags/v1.0.0: same bytes, same digest.
  sha256 = {
    "1.0.0" = "9c6d424d206dd7822aa44fa39ce31575dcbaa83133620abdac8e56e4cea9667c"
  }
}

build {
  dependencies = {
    "cmake.org"    = "*"
    "gnu.org/make" = "*"
    "github.com/awslabs/aws-c-common" = "*"
    "openssl.org"  = "^3"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_LIBDIR=lib",

      # CMakeLists.txt:33 find_package(aws-c-common REQUIRED); cmake/aws-c-cal-config.cmake find_dependency(aws-c-common); :147 find_package(OpenSSL REQUIRED).
      # The installed aws-c-common (and whatever it pulls in) is found in config mode, so every
      # prefix of the closure goes on CMAKE_PREFIX_PATH and nothing is left to the host.
      "-DCMAKE_PREFIX_PATH={{deps.github.com/awslabs/aws-c-common.prefix}};{{deps.openssl.org.prefix}}",

      # No type given to add_library, so BUILD_SHARED_LIBS decides: shared, like aws-sdk-cpp's default.
      "-DBUILD_SHARED_LIBS=ON",

      # include(CTest) defines BUILD_TESTING; tests and benchmark binaries are not installed.
      "-DBUILD_TESTING=OFF",

      # CMakeLists.txt:26: not providing one's own crypto. OFF, so the default backend is compiled.
      "-DBYO_CRYPTO=OFF",

      # CMakeLists.txt:27 and :145-150: on Linux the libcrypto comes from find_package(OpenSSL) when this is ON,
      # otherwise from an AWS-LC target (:151-171) that this tree does not carry. ON, with the tree's openssl.org.
      # On darwin and Windows the block at :145 is skipped and the platform library is used (Security framework / CNG),
      # so the option is inert there.
      "-DUSE_OPENSSL=ON",

      # CMakeLists.txt:28: prefer shared libcrypto in Findcrypto (the AWS-LC path); stated OFF.
      "-DAWS_USE_CRYPTO_SHARED_LIBS=OFF",

      # CMakeLists.txt:29, :60-65, :196-198: ED25519 through libcrypto on platforms whose own library lacks it. OFF upstream; stated OFF.
      "-DAWS_USE_LIBCRYPTO_TO_SUPPORT_ED25519_EVERYWHERE=OFF",

      # Options of aws-c-common's cmake modules, which this CMakeLists includes from the
      # installed aws-c-common (AwsCFlags, AwsSanitizers, AwsFeatureTests, AwsCheckHeaders;
      # read at v1.0.5: AwsCFlags.cmake:8-14, AwsSanitizers.cmake:6-8, AwsFeatureTests.cmake:7,
      # AwsCheckHeaders.cmake:10). All stated, none left to a default.
      "-DUSE_CPU_EXTENSIONS=ON",
      "-DPERFORM_HEADER_CHECK=OFF",
      "-DENABLE_SANITIZERS=OFF",
      "-DENABLE_SANITIZER_RECOVERY=OFF",
      "-DAWS_ENABLE_LTO=OFF",
      "-DLEGACY_COMPILER_SUPPORT=OFF",
      "-DAWS_SUPPORT_WIN7=OFF",
      "-DAWS_WARNINGS_ARE_ERRORS=OFF",
      "-DAWS_ENABLE_TRACING=OFF",
      "-DAWS_STATIC_MSVC_RUNTIME_LIBRARY=OFF",
      "-DSTATIC_CRT=OFF",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# A library: no executables are installed.
provides = []

test {
  script = [
    "test -f {{prefix}}/include/aws/cal/cal.h",
    # The package file the dependants find_package() (CMakeLists.txt installs it under lib/cmake/aws-c-cal).
    "test -f {{prefix}}/lib/cmake/aws-c-cal/aws-c-cal-config.cmake",
  ]
}

provenance {
  read = [
    "CMakeLists.txt # :2 SPDX Apache-2.0; :26-29 options; :33 find_package(aws-c-common); :145-173 libcrypto selection; :244-249 tests and bin/ only under BUILD_TESTING",
    "cmake/aws-c-cal-config.cmake # find_dependency(aws-c-common)",
    "LICENSE",
  ]

  consulted = [
    "https://github.com/aws/aws-sdk-cpp/tree/1.11.935/crt",
    "https://github.com/awslabs/aws-crt-cpp/tree/v0.44.4/crt",
  ]

  note = <<EOT
Written, not converted. Version chain read with the GitHub contents API: aws-sdk-cpp 1.11.935
-> aws-crt-cpp 07b1d9a9 (v0.44.4) -> aws-c-cal 2441187f (v1.0.0).
OpenSSL, not AWS-LC: CMakeLists.txt:27 describes USE_OPENSSL as using "your system's OpenSSL 1.0.2/1.1.1 compatible libcrypto"; the tree's openssl.org is 3.x, whose API is a superset for what c-cal calls, but that was not exercised here.
⛔ NOT BUILT. The build and test blocks were not run in this session; the recipe is
checked by `zpkb lint` only.
EOT
}
