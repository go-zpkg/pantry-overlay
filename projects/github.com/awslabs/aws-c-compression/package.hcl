# aws-c-compression — AWS Common Runtime: Huffman compression (the HPACK coder used by aws-c-http)
#
# ⛔ WRITTEN FROM AWS-C-COMPRESSION'S OWN FILES at 1.0.0 (go-zpkg/packages#440 step 1), one link of the
# AWS Common Runtime chain that aws-sdk-cpp needs (aws-sdk-cpp -> aws-crt-cpp -> the C
# libraries). Their recipes were missing, which is why aws-sdk-cpp stayed a fragment.
#
# ⭐ WHY ONE VERSION. aws-sdk-cpp 1.11.935 pins crt/aws-crt-cpp to 07b1d9a9 = tag
# v0.44.4, and that tag's crt/ directory pins this library to commit 891312c0 = tag
# v1.0.0 (GitHub contents API on both, with .gitmodules naming the repository). The CRT
# libraries are released together and their ABI is not stable across tags, so the
# versions block resolves ONLY that tag; otherwise --check-newest-pinned would demand
# a newer one that no other recipe here was read against.

summary = "AWS Common Runtime: Huffman compression (the HPACK coder used by aws-c-http)"

# LICENSE opens with "Apache License Version 2.0, January 2004".
license = "Apache-2.0"

versions {
  github = "awslabs/aws-c-compression/tags"
  strip  = ["/^v/"]

  # Only 1.0.0; see the header. Negative lookahead, as mysql.com does.
  ignore = ["/^(?!1\\.0\\.0$)/"]
}

distributable {
  # No stored release asset (the GitHub release lists none), so the generated tag archive.
  url              = "https://github.com/awslabs/aws-c-compression/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 1.0.0: 39698 bytes, fetched with `zpkb sourcepin`. The project publishes neither a
  # signature nor a checksum file, so the second witness is a second independent fetch from
  # https://codeload.github.com/awslabs/aws-c-compression/tar.gz/refs/tags/v1.0.0: same bytes, same digest.
  sha256 = {
    "1.0.0" = "d8e934da2086bfec41f97a0cff749d926f66ccb90f2052f1d70841916c1bf4d7"
  }
}

build {
  dependencies = {
    "cmake.org"    = "*"
    "gnu.org/make" = "*"
    "github.com/awslabs/aws-c-common" = "*"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_LIBDIR=lib",

      # CMakeLists.txt:5-13 finds the installed AwsGetVersion.cmake under CMAKE_PREFIX_PATH; :21 find_package(aws-c-common REQUIRED).
      # The installed aws-c-common (and whatever it pulls in) is found in config mode, so every
      # prefix of the closure goes on CMAKE_PREFIX_PATH and nothing is left to the host.
      "-DCMAKE_PREFIX_PATH={{deps.github.com/awslabs/aws-c-common.prefix}}",

      # No type given to add_library, so BUILD_SHARED_LIBS decides: shared, like aws-sdk-cpp's default.
      "-DBUILD_SHARED_LIBS=ON",

      # include(CTest) defines BUILD_TESTING; tests and benchmark binaries are not installed.
      "-DBUILD_TESTING=OFF",

      # CMakeLists.txt:100: the code generator for Huffman tables, a maintainer tool.
      "-DBUILD_HUFFMAN_GENERATOR=OFF",

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
    "test -f {{prefix}}/include/aws/compression/compression.h",
    # The package file the dependants find_package() (CMakeLists.txt installs it under lib/cmake/aws-c-compression).
    "test -f {{prefix}}/lib/cmake/aws-c-compression/aws-c-compression-config.cmake",
  ]
}

provenance {
  read = [
    "CMakeLists.txt # :5-13 module lookup in an installed aws-c-common; :21 find_package; :72 aws_use_package; :78-79 headers; :87-96 export and cmake package; :100 BUILD_HUFFMAN_GENERATOR; :105-107 BUILD_TESTING",
    "cmake/aws-c-compression-config.cmake # find_dependency(aws-c-common)",
    "LICENSE",
  ]

  consulted = [
    "https://github.com/aws/aws-sdk-cpp/tree/1.11.935/crt",
    "https://github.com/awslabs/aws-crt-cpp/tree/v0.44.4/crt",
  ]

  note = <<EOT
Written, not converted. Version chain read with the GitHub contents API: aws-sdk-cpp 1.11.935
-> aws-crt-cpp 07b1d9a9 (v0.44.4) -> aws-c-compression 891312c0 (v1.0.0).
The only option of its own is BUILD_HUFFMAN_GENERATOR (CMakeLists.txt:100).
⛔ NOT BUILT. The build and test blocks were not run in this session; the recipe is
checked by `zpkb lint` only.
EOT
}
