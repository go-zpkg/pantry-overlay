# aws-c-common — core C99 data structures, platform shims and allocators that
# every other AWS Common Runtime (CRT) library is built on.
#
# ⛔ WRITTEN FROM AWS-C-COMMON'S OWN FILES at 1.0.5 (go-zpkg/packages#440 step 1).
# It is the first of a chain: aws-sdk-cpp links aws-crt-cpp, which links the
# thirteen C libraries below. aws-sdk-cpp had been skipped because that chain
# was only ever reached through git submodules; each link is now its own recipe.
#
# ⭐ WHY ONE VERSION. aws-sdk-cpp 1.11.935 pins crt/aws-crt-cpp to commit
# 07b1d9a9 = tag v0.44.4 (`gh api repos/aws/aws-sdk-cpp/contents/crt`), and
# aws-crt-cpp v0.44.4's own crt/ directory pins aws-c-common to commit
# 45e93073 = tag v1.0.5 (`gh api repos/awslabs/aws-crt-cpp/contents/crt`, with
# .gitmodules naming the repository). The CRT libraries are released together
# and their C ABI is not stable across tags, so this recipe resolves ONLY that
# tag: a newer aws-c-common would be a version the other recipes were never
# read against, and `--check-newest-pinned` would otherwise demand it.

summary = "AWS Common Runtime: core C data structures, allocators and platform shims"

# CMakeLists.txt:1-2: "SPDX-License-Identifier: Apache-2.0."
license = "Apache-2.0"

versions {
  github = "awslabs/aws-c-common/tags"
  strip  = ["/^v/"]

  # Only 1.0.5; see the header. Negative lookahead, as mysql.com does.
  ignore = ["/^(?!1\\.0\\.5$)/"]
}

distributable {
  # The repository has no stored release asset (the GitHub release lists none:
  # `gh api repos/awslabs/aws-c-common/releases/tags/v1.0.5` returns an empty
  # asset list), so this is the generated tag archive.
  url              = "https://github.com/awslabs/aws-c-common/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 1.0.5: 679093 bytes, fetched with `zpkb sourcepin`. The project publishes
  # neither a signature nor a checksum file, so the second witness is a second
  # independent fetch from a different host,
  # https://codeload.github.com/awslabs/aws-c-common/tar.gz/refs/tags/v1.0.5,
  # which gave the same 679093 bytes and the same digest.
  sha256 = {
    "1.0.5" = "d00f08b4e2eb173c2d2ce25993b64c3263b906581bd0315845b9b31b0b7799dc"
  }
}

build {
  dependencies = {
    "cmake.org"    = "*"
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",

      # GNUInstallDirs (CMakeLists.txt:34) may choose lib64; the install of the
      # targets and of the cmake package (:306-313) follows it. Pinned to lib.
      "-DCMAKE_INSTALL_LIBDIR=lib",

      # add_library(${PROJECT_NAME} ...) at :203 names no type, so the standard
      # BUILD_SHARED_LIBS decides. Shared, as the SDK links the libraries
      # dynamically by default.
      "-DBUILD_SHARED_LIBS=ON",

      # CMakeLists.txt:33 includes CTest, which defines BUILD_TESTING; :338-343
      # add tests/ and bin/system_info only when it is ON.
      "-DBUILD_TESTING=OFF",
      "-DALLOW_CROSS_COMPILED_TESTS=OFF",

      # cmake/AwsFeatureTests.cmake:7, default ON: SSE/AVX/ARM CRC code paths
      # are chosen by compile checks, so this follows the build host. Stated.
      "-DUSE_CPU_EXTENSIONS=ON",

      # cmake/AwsCheckHeaders.cmake:10: needs a C++ compiler; header hygiene
      # for the maintainers, not for a consumer.
      "-DPERFORM_HEADER_CHECK=OFF",

      # cmake/AwsSanitizers.cmake:6-8: debug-build sanitizers.
      "-DENABLE_SANITIZERS=OFF",
      "-DENABLE_SANITIZER_RECOVERY=OFF",

      # cmake/AwsCFlags.cmake:8-14, all OFF upstream and stated OFF here.
      # AWS_ENABLE_LTO would make every consumer link with LTO or fail.
      "-DAWS_ENABLE_LTO=OFF",
      "-DLEGACY_COMPILER_SUPPORT=OFF",
      "-DAWS_SUPPORT_WIN7=OFF",
      "-DAWS_WARNINGS_ARE_ERRORS=OFF",
      "-DAWS_ENABLE_TRACING=OFF",
      "-DAWS_STATIC_MSVC_RUNTIME_LIBRARY=OFF",
      "-DSTATIC_CRT=OFF",

      # CMakeLists.txt:70-71: 0 means detect at configure time; only meant for
      # cross-compiling.
      "-DAWS_NUM_CPU_CORES=0",
      "-DAWS_PAGE_SIZE=0",
    ]
  }

  script = [
    "cmake -S . -B build $ARGS",
    "cmake --build build --parallel {{ hw.concurrency }}",
    "cmake --install build",
  ]
}

# A library: no executables. (bin/system_info is built only under BUILD_TESTING.)
provides = []

test {
  dependencies = {
    "gnu.org/gcc" = "*"
  }

  script = [
    "test -f {{prefix}}/include/aws/common/common.h",
    # CMakeLists.txt:264-292: the generated config.h is installed with them.
    "test -f {{prefix}}/include/aws/common/config.h",
    # CMakeLists.txt:296-313: the package file other CRT recipes find_package().
    "test -f {{prefix}}/lib/cmake/aws-c-common/aws-c-common-config.cmake",
    {
      fixture = {
        content  = <<EOT
#include <stdio.h>
#include <aws/common/common.h>

int main(void) {
  struct aws_allocator *alloc = aws_default_allocator();
  if (alloc == NULL) {
    puts("no default allocator");
    return 1;
  }
  puts("aws-c-common linked");
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o linked -I{{prefix}}/include -L{{prefix}}/lib -Wl,-rpath,{{prefix}}/lib -laws-c-common"
    },
    "./linked",
  ]
}

provenance {
  read = [
    "CMakeLists.txt",                 # :1-2 licence; :33-34 CTest, GNUInstallDirs; :70-71 cpu/page options; :203 the library; :264-313 headers and cmake package; :338 tests
    "cmake/AwsFeatureTests.cmake",    # :7 USE_CPU_EXTENSIONS
    "cmake/AwsCheckHeaders.cmake",    # :10 PERFORM_HEADER_CHECK
    "cmake/AwsSanitizers.cmake",      # :6-8 sanitizer options
    "cmake/AwsCFlags.cmake",          # :8-14 LTO, legacy compiler, tracing, MSVC options
  ]

  consulted = [
    "https://github.com/aws/aws-sdk-cpp/tree/1.11.935/crt",
    "https://github.com/awslabs/aws-crt-cpp/tree/v0.44.4/crt",
  ]

  note = <<EOT
Written, not converted: the aws-sdk-cpp fragment stated no versions, no source
and no build.

Version chain, read with the GitHub contents API: aws-sdk-cpp 1.11.935 ->
aws-crt-cpp 07b1d9a9 (v0.44.4) -> aws-c-common 45e93073 (v1.0.5). The versions
block resolves that one tag so that --check-newest-pinned cannot ask for one the
other CRT recipes were not read against.

⛔ NOT BUILT. The build and test blocks were not run in this session; the
recipe is checked by `zpkb lint` only.
EOT
}
