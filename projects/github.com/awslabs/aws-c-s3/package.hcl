# aws-c-s3 — AWS Common Runtime: S3 client (multipart upload and download, checksums)
#
# ⛔ WRITTEN FROM AWS-C-S3'S OWN FILES at 1.5.2 (go-zpkg/packages#440 step 1), one link of the
# AWS Common Runtime chain that aws-sdk-cpp needs (aws-sdk-cpp -> aws-crt-cpp -> the C
# libraries). Their recipes were missing, which is why aws-sdk-cpp stayed a fragment.
#
# ⭐ WHY ONE VERSION. aws-sdk-cpp 1.11.935 pins crt/aws-crt-cpp to 07b1d9a9 = tag
# v0.44.4, and that tag's crt/ directory pins this library to commit bc923d67 = tag
# v1.5.2 (GitHub contents API on both, with .gitmodules naming the repository). The CRT
# libraries are released together and their ABI is not stable across tags, so the
# versions block resolves ONLY that tag; otherwise --check-newest-pinned would demand
# a newer one that no other recipe here was read against.

summary = "AWS Common Runtime: S3 client (multipart upload and download, checksums)"

# LICENSE opens with "Apache License Version 2.0, January 2004".
license = "Apache-2.0"

versions {
  github = "awslabs/aws-c-s3/tags"
  strip  = ["/^v/"]

  # Only 1.5.2; see the header. Negative lookahead, as mysql.com does.
  ignore = ["/^(?!1\\.5\\.2$)/"]
}

distributable {
  # No stored release asset (the GitHub release lists none), so the generated tag archive.
  url              = "https://github.com/awslabs/aws-c-s3/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 1.5.2: 606873 bytes, fetched with `zpkb sourcepin`. The project publishes neither a
  # signature nor a checksum file, so the second witness is a second independent fetch from
  # https://codeload.github.com/awslabs/aws-c-s3/tar.gz/refs/tags/v1.5.2: same bytes, same digest.
  sha256 = {
    "1.5.2" = "26bac413daa8b4146abd1fceb55a282a5d3869524c24aca64a00ec1a4e0449bd"
  }
}

build {
  dependencies = {
    "cmake.org"    = "*"
    "gnu.org/make" = "*"
    "github.com/awslabs/aws-c-auth" = "*"
    "github.com/awslabs/aws-c-cal" = "*"
    "github.com/awslabs/aws-c-common" = "*"
    "github.com/awslabs/aws-c-compression" = "*"
    "github.com/awslabs/aws-c-http" = "*"
    "github.com/awslabs/aws-c-io" = "*"
    "github.com/awslabs/aws-c-sdkutils" = "*"
    "github.com/awslabs/aws-checksums" = "*"
    "github.com/aws/s2n-tls" = "*"
    "openssl.org" = "^3"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_LIBDIR=lib",

      # CMakeLists.txt:31 find_package(aws-c-common), :100-101 aws_use_package(aws-c-auth, aws-checksums).
      # The installed aws-c-common (and whatever it pulls in) is found in config mode, so every
      # prefix of the closure goes on CMAKE_PREFIX_PATH and nothing is left to the host.
      "-DCMAKE_PREFIX_PATH={{deps.github.com/awslabs/aws-c-auth.prefix}};{{deps.github.com/awslabs/aws-c-cal.prefix}};{{deps.github.com/awslabs/aws-c-common.prefix}};{{deps.github.com/awslabs/aws-c-compression.prefix}};{{deps.github.com/awslabs/aws-c-http.prefix}};{{deps.github.com/awslabs/aws-c-io.prefix}};{{deps.github.com/awslabs/aws-c-sdkutils.prefix}};{{deps.github.com/awslabs/aws-checksums.prefix}};{{deps.github.com/aws/s2n-tls.prefix}};{{deps.openssl.org.prefix}}",

      # No type given to add_library, so BUILD_SHARED_LIBS decides: shared, like aws-sdk-cpp's default.
      "-DBUILD_SHARED_LIBS=ON",

      # include(CTest) defines BUILD_TESTING; tests and benchmark binaries are not installed.
      "-DBUILD_TESTING=OFF",

      # CMakeLists.txt:20: ASSERT_SYNCED_DATA_LOCK_HELD, a thread-debugging aid; OFF.
      "-DASSERT_LOCK_HELD=OFF",

      # CMakeLists.txt:21: integration tests against a mock server; OFF.
      "-DENABLE_MOCK_SERVER_TESTS=OFF",

      # CMakeLists.txt:22: integration tests against a multi-region access point; OFF.
      "-DENABLE_MRAP_TESTS=OFF",

      # CMakeLists.txt:23: the s3 endpoint resolver and its config files. OFF, the upstream default:
      # the SDK resolves endpoints itself, and nothing here read what this switch adds beyond its description.
      "-DAWS_ENABLE_S3_ENDPOINT_RESOLVER=OFF",

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
    "test -f {{prefix}}/include/aws/s3/s3.h",
    # The package file the dependants find_package() (CMakeLists.txt installs it under lib/cmake/aws-c-s3).
    "test -f {{prefix}}/lib/cmake/aws-c-s3/aws-c-s3-config.cmake",
  ]
}

provenance {
  read = [
    "CMakeLists.txt # :20-23 options; :31 find_package(aws-c-common); :100-101 aws_use_package; :107 header install; :115-124 export and cmake package; :128-135 tests and samples under BUILD_TESTING",
    "cmake/aws-c-s3-config.cmake # the installed package file",
    "LICENSE",
  ]

  consulted = [
    "https://github.com/aws/aws-sdk-cpp/tree/1.11.935/crt",
    "https://github.com/awslabs/aws-crt-cpp/tree/v0.44.4/crt",
  ]

  note = <<EOT
Written, not converted. Version chain read with the GitHub contents API: aws-sdk-cpp 1.11.935
-> aws-crt-cpp 07b1d9a9 (v0.44.4) -> aws-c-s3 bc923d67 (v1.5.2).
AWS_ENABLE_S3_ENDPOINT_RESOLVER stays at its upstream default OFF; only its option description was read.
⛔ NOT BUILT. The build and test blocks were not run in this session; the recipe is
checked by `zpkb lint` only.
EOT
}
