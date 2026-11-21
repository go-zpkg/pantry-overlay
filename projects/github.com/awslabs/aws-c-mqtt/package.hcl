# aws-c-mqtt — AWS Common Runtime: MQTT 3.1.1 and MQTT 5 client
#
# ⛔ WRITTEN FROM AWS-C-MQTT'S OWN FILES at 1.1.2 (go-zpkg/packages#440 step 1), one link of the
# AWS Common Runtime chain that aws-sdk-cpp needs (aws-sdk-cpp -> aws-crt-cpp -> the C
# libraries). Their recipes were missing, which is why aws-sdk-cpp stayed a fragment.
#
# ⭐ WHY ONE VERSION. aws-sdk-cpp 1.11.935 pins crt/aws-crt-cpp to 07b1d9a9 = tag
# v0.44.4, and that tag's crt/ directory pins this library to commit 96af751f = tag
# v1.1.2 (GitHub contents API on both, with .gitmodules naming the repository). The CRT
# libraries are released together and their ABI is not stable across tags, so the
# versions block resolves ONLY that tag; otherwise --check-newest-pinned would demand
# a newer one that no other recipe here was read against.

summary = "AWS Common Runtime: MQTT 3.1.1 and MQTT 5 client"

# LICENSE opens with "Apache License Version 2.0, January 2004".
license = "Apache-2.0"

versions {
  github = "awslabs/aws-c-mqtt/tags"
  strip  = ["/^v/"]

  # Only 1.1.2; see the header. Negative lookahead, as mysql.com does.
  ignore = ["/^(?!1\\.1\\.2$)/"]
}

distributable {
  # No stored release asset (the GitHub release lists none), so the generated tag archive.
  url              = "https://github.com/awslabs/aws-c-mqtt/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 1.1.2: 474762 bytes, fetched with `zpkb sourcepin`. The project publishes neither a
  # signature nor a checksum file, so the second witness is a second independent fetch from
  # https://codeload.github.com/awslabs/aws-c-mqtt/tar.gz/refs/tags/v1.1.2: same bytes, same digest.
  sha256 = {
    "1.1.2" = "7ef8f2a031992cc42564bba4e3f937fec925247051da6e0c730aa964639d284f"
  }
}

build {
  dependencies = {
    "cmake.org"    = "*"
    "gnu.org/make" = "*"
    "github.com/awslabs/aws-c-cal" = "*"
    "github.com/awslabs/aws-c-common" = "*"
    "github.com/awslabs/aws-c-compression" = "*"
    "github.com/awslabs/aws-c-http" = "*"
    "github.com/awslabs/aws-c-io" = "*"
    "github.com/aws/s2n-tls" = "*"
    "openssl.org" = "^3"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_LIBDIR=lib",

      # CMakeLists.txt:26 find_package(aws-c-common), :92 aws_use_package(aws-c-http).
      # The installed aws-c-common (and whatever it pulls in) is found in config mode, so every
      # prefix of the closure goes on CMAKE_PREFIX_PATH and nothing is left to the host.
      "-DCMAKE_PREFIX_PATH={{deps.github.com/awslabs/aws-c-cal.prefix}};{{deps.github.com/awslabs/aws-c-common.prefix}};{{deps.github.com/awslabs/aws-c-compression.prefix}};{{deps.github.com/awslabs/aws-c-http.prefix}};{{deps.github.com/awslabs/aws-c-io.prefix}};{{deps.github.com/aws/s2n-tls.prefix}};{{deps.openssl.org.prefix}}",

      # No type given to add_library, so BUILD_SHARED_LIBS decides: shared, like aws-sdk-cpp's default.
      "-DBUILD_SHARED_LIBS=ON",

      # include(CTest) defines BUILD_TESTING; tests and benchmark binaries are not installed.
      "-DBUILD_TESTING=OFF",

      # CMakeLists.txt:19: ASSERT_SYNCED_DATA_LOCK_HELD, a thread-debugging aid; OFF.
      "-DASSERT_LOCK_HELD=OFF",

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
    "test -f {{prefix}}/include/aws/mqtt/mqtt.h",
    # The package file the dependants find_package() (CMakeLists.txt installs it under lib/cmake/aws-c-mqtt).
    "test -f {{prefix}}/lib/cmake/aws-c-mqtt/aws-c-mqtt-config.cmake",
  ]
}

provenance {
  read = [
    "CMakeLists.txt # :19 ASSERT_LOCK_HELD; :26 find_package(aws-c-common); :92 aws_use_package(aws-c-http); :97-101 header installs; :109-118 export and cmake package; :123-131 tests and bin/ only under BUILD_TESTING",
    "cmake/aws-c-mqtt-config.cmake # the installed package file",
    "LICENSE",
  ]

  consulted = [
    "https://github.com/aws/aws-sdk-cpp/tree/1.11.935/crt",
    "https://github.com/awslabs/aws-crt-cpp/tree/v0.44.4/crt",
  ]

  note = <<EOT
Written, not converted. Version chain read with the GitHub contents API: aws-sdk-cpp 1.11.935
-> aws-crt-cpp 07b1d9a9 (v0.44.4) -> aws-c-mqtt 96af751f (v1.1.2).
ASSERT_LOCK_HELD (CMakeLists.txt:19) is the only option of its own; the elastipubsub, elastishadow and mqtt5canary binaries are built only under BUILD_TESTING (:123-130).
⛔ NOT BUILT. The build and test blocks were not run in this session; the recipe is
checked by `zpkb lint` only.
EOT
}
