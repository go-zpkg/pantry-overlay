# aws-c-event-stream — AWS Common Runtime: the vnd.amazon.eventstream binary message framing
#
# ⛔ WRITTEN FROM AWS-C-EVENT-STREAM'S OWN FILES at 1.0.0 (go-zpkg/packages#440 step 1), one link of the
# AWS Common Runtime chain that aws-sdk-cpp needs (aws-sdk-cpp -> aws-crt-cpp -> the C
# libraries). Their recipes were missing, which is why aws-sdk-cpp stayed a fragment.
#
# ⭐ WHY ONE VERSION. aws-sdk-cpp 1.11.935 pins crt/aws-crt-cpp to 07b1d9a9 = tag
# v0.44.4, and that tag's crt/ directory pins this library to commit d32600bf = tag
# v1.0.0 (GitHub contents API on both, with .gitmodules naming the repository). The CRT
# libraries are released together and their ABI is not stable across tags, so the
# versions block resolves ONLY that tag; otherwise --check-newest-pinned would demand
# a newer one that no other recipe here was read against.

summary = "AWS Common Runtime: the vnd.amazon.eventstream binary message framing"

# LICENSE opens with "Apache License Version 2.0, January 2004".
license = "Apache-2.0"

versions {
  github = "awslabs/aws-c-event-stream/tags"
  strip  = ["/^v/"]

  # Only 1.0.0; see the header. Negative lookahead, as mysql.com does.
  ignore = ["/^(?!1\\.0\\.0$)/"]
}

distributable {
  # No stored release asset (the GitHub release lists none), so the generated tag archive.
  url              = "https://github.com/awslabs/aws-c-event-stream/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 1.0.0: 106810 bytes, fetched with `zpkb sourcepin`. The project publishes neither a
  # signature nor a checksum file, so the second witness is a second independent fetch from
  # https://codeload.github.com/awslabs/aws-c-event-stream/tar.gz/refs/tags/v1.0.0: same bytes, same digest.
  sha256 = {
    "1.0.0" = "c3817ab04bf9c70fa3582a31243666a9a643ebe45f121f58d5fef5ff4787f8e0"
  }
}

build {
  dependencies = {
    "cmake.org"    = "*"
    "gnu.org/make" = "*"
    "github.com/awslabs/aws-c-cal" = "*"
    "github.com/awslabs/aws-c-common" = "*"
    "github.com/awslabs/aws-c-io" = "*"
    "github.com/awslabs/aws-checksums" = "*"
    "github.com/aws/s2n-tls" = "*"
    "openssl.org" = "^3"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_LIBDIR=lib",

      # CMakeLists.txt:23 find_package(aws-c-common), :72-74 aws_use_package(aws-c-io, aws-c-common, aws-checksums).
      # The installed aws-c-common (and whatever it pulls in) is found in config mode, so every
      # prefix of the closure goes on CMAKE_PREFIX_PATH and nothing is left to the host.
      "-DCMAKE_PREFIX_PATH={{deps.github.com/awslabs/aws-c-cal.prefix}};{{deps.github.com/awslabs/aws-c-common.prefix}};{{deps.github.com/awslabs/aws-c-io.prefix}};{{deps.github.com/awslabs/aws-checksums.prefix}};{{deps.github.com/aws/s2n-tls.prefix}};{{deps.openssl.org.prefix}}",

      # No type given to add_library, so BUILD_SHARED_LIBS decides: shared, like aws-sdk-cpp's default.
      "-DBUILD_SHARED_LIBS=ON",

      # include(CTest) defines BUILD_TESTING; tests and benchmark binaries are not installed.
      "-DBUILD_TESTING=OFF",

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
    "test -f {{prefix}}/include/aws/event-stream/event_stream.h",
    # The package file the dependants find_package() (CMakeLists.txt installs it under lib/cmake/aws-c-event-stream).
    "test -f {{prefix}}/lib/cmake/aws-c-event-stream/aws-c-event-stream-config.cmake",
  ]
}

provenance {
  read = [
    "CMakeLists.txt # :2 SPDX Apache-2.0; :23 find_package(aws-c-common); :72-74 aws_use_package; :80 header install; :90-99 export and cmake package; :106-108 tests and bin/ under BUILD_TESTING",
    "cmake/aws-c-event-stream-config.cmake # the installed package file",
    "LICENSE",
  ]

  consulted = [
    "https://github.com/aws/aws-sdk-cpp/tree/1.11.935/crt",
    "https://github.com/awslabs/aws-crt-cpp/tree/v0.44.4/crt",
  ]

  note = <<EOT
Written, not converted. Version chain read with the GitHub contents API: aws-sdk-cpp 1.11.935
-> aws-crt-cpp 07b1d9a9 (v0.44.4) -> aws-c-event-stream d32600bf (v1.0.0).
No option of its own; BUILD_TESTING (CMakeLists.txt:106) is the only switch, and it also gates bin/.
⛔ NOT BUILT. The build and test blocks were not run in this session; the recipe is
checked by `zpkb lint` only.
EOT
}
