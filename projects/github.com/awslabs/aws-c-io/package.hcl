# aws-c-io — AWS Common Runtime: event loops, sockets, channels and TLS (s2n-tls on Linux and, here, on darwin too)
#
# ⛔ WRITTEN FROM AWS-C-IO'S OWN FILES at 1.1.2 (go-zpkg/packages#440 step 1), one link of the
# AWS Common Runtime chain that aws-sdk-cpp needs (aws-sdk-cpp -> aws-crt-cpp -> the C
# libraries). Their recipes were missing, which is why aws-sdk-cpp stayed a fragment.
#
# ⭐ WHY ONE VERSION. aws-sdk-cpp 1.11.935 pins crt/aws-crt-cpp to 07b1d9a9 = tag
# v0.44.4, and that tag's crt/ directory pins this library to commit eac37256 = tag
# v1.1.2 (GitHub contents API on both, with .gitmodules naming the repository). The CRT
# libraries are released together and their ABI is not stable across tags, so the
# versions block resolves ONLY that tag; otherwise --check-newest-pinned would demand
# a newer one that no other recipe here was read against.

summary = "AWS Common Runtime: event loops, sockets, channels and TLS (s2n-tls on Linux and, here, on darwin too)"

# LICENSE opens with "Apache License Version 2.0, January 2004".
license = "Apache-2.0"

versions {
  github = "awslabs/aws-c-io/tags"
  strip  = ["/^v/"]

  # Only 1.1.2; see the header. Negative lookahead, as mysql.com does.
  ignore = ["/^(?!1\\.1\\.2$)/"]
}

distributable {
  # No stored release asset (the GitHub release lists none), so the generated tag archive.
  url              = "https://github.com/awslabs/aws-c-io/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 1.1.2: 845341 bytes, fetched with `zpkb sourcepin`. The project publishes neither a
  # signature nor a checksum file, so the second witness is a second independent fetch from
  # https://codeload.github.com/awslabs/aws-c-io/tar.gz/refs/tags/v1.1.2: same bytes, same digest.
  sha256 = {
    "1.1.2" = "5da5bbfb97a2e52cea58ed1f76fb94a877df11763dcbd1373c14d699ed1efd18"
  }
}

build {
  dependencies = {
    "cmake.org"    = "*"
    "gnu.org/make" = "*"
    "github.com/awslabs/aws-c-cal" = "*"
    "github.com/awslabs/aws-c-common" = "*"
    "github.com/aws/s2n-tls" = "*"
    "openssl.org" = "^3"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_LIBDIR=lib",

      # CMakeLists.txt:22 find_package(aws-c-common), :261-262 aws_use_package(aws-c-common, aws-c-cal), :183 find_package(s2n REQUIRED).
      # The installed aws-c-common (and whatever it pulls in) is found in config mode, so every
      # prefix of the closure goes on CMAKE_PREFIX_PATH and nothing is left to the host.
      "-DCMAKE_PREFIX_PATH={{deps.github.com/awslabs/aws-c-cal.prefix}};{{deps.github.com/awslabs/aws-c-common.prefix}};{{deps.github.com/aws/s2n-tls.prefix}};{{deps.openssl.org.prefix}}",

      # No type given to add_library, so BUILD_SHARED_LIBS decides: shared, like aws-sdk-cpp's default.
      "-DBUILD_SHARED_LIBS=ON",

      # include(CTest) defines BUILD_TESTING; tests and benchmark binaries are not installed.
      "-DBUILD_TESTING=OFF",

      # CMakeLists.txt:33: relocatable binaries are a packaging mode of the upstream CI; OFF.
      "-DBUILD_RELOCATABLE_BINARIES=OFF",

      # CMakeLists.txt:36: bring-your-own TLS. OFF, so the s2n-tls backend is compiled.
      "-DBYO_CRYPTO=OFF",

      # CMakeLists.txt:90: AF_VSOCK sockets (Linux only); OFF.
      "-DUSE_VSOCK=OFF",

      # CMakeLists.txt:104, :155 force USE_S2N ON on Linux and the BSDs; on darwin the default is ON only while
      # AWS_USE_SECITEM is NOT DEFINED (:133-137). ON on every platform: the tree carries s2n-tls and not a
      # build against Security.framework. DO NOT pass -DAWS_USE_SECITEM=OFF: the test is NOT DEFINED
      # (:127, :133, :140), so merely defining it selects the SecItem / dispatch-queue path and turns s2n off.
      "-DUSE_S2N=ON",

      # CMakeLists.txt:249, :253: the Apple Network.framework and dispatch-queue event loops; stated OFF.
      "-DAWS_USE_APPLE_NETWORK_FRAMEWORK=OFF",

      # CMakeLists.txt:253: same, for the dispatch-queue event loop.
      "-DAWS_USE_APPLE_DISPATCH_QUEUE=OFF",

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
    "test -f {{prefix}}/include/aws/io/io.h",
    # The package file the dependants find_package() (CMakeLists.txt installs it under lib/cmake/aws-c-io).
    "test -f {{prefix}}/lib/cmake/aws-c-io/aws-c-io-config.cmake",
  ]
}

provenance {
  read = [
    "CMakeLists.txt # :22 find_package(aws-c-common); :33 BUILD_RELOCATABLE_BINARIES; :36 BYO_CRYPTO; :90 USE_VSOCK; :104-155 USE_S2N selection; :127-140 AWS_USE_SECITEM; :183 find_package(s2n); :249-262 Apple options and aws_use_package; :301 BUILD_TESTING",
    "cmake/aws-c-io-config.cmake # the installed package file",
    "LICENSE",
  ]

  consulted = [
    "https://github.com/aws/aws-sdk-cpp/tree/1.11.935/crt",
    "https://github.com/awslabs/aws-crt-cpp/tree/v0.44.4/crt",
  ]

  note = <<EOT
Written, not converted. Version chain read with the GitHub contents API: aws-sdk-cpp 1.11.935
-> aws-crt-cpp 07b1d9a9 (v0.44.4) -> aws-c-io eac37256 (v1.1.2).
Deviation: on darwin USE_S2N=ON, not the platform TLS. s2n-tls needs a libcrypto, so the prefix closure includes openssl.org and s2n-tls.
⛔ NOT BUILT. The build and test blocks were not run in this session; the recipe is
checked by `zpkb lint` only.
EOT
}
