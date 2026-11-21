# aws-sdk-cpp — the AWS SDK for C++, built whole from its own CMake project
#
# ⛔ WRITTEN FROM AWS-SDK-CPP'S OWN FILES at 1.11.935 (go-zpkg/packages#440 step 1). This
# recipe used to be a fragment that only added three dependencies to a recipe that did not
# exist here. It is whole now because the C++ wrapper and every C library of the AWS Common
# Runtime beneath it are recipes of their own in this tree (aws-crt-cpp, aws-c-*, aws-checksums,
# s2n-tls), so the SDK is built with BUILD_DEPS=OFF and finds them in config mode instead of
# compiling the git submodules under crt/.
#
# ⭐ WHY ONE VERSION. 1.11.935 is the newest tag (GitHub tags API). Its crt/aws-crt-cpp submodule
# is pinned to 07b1d9a9 = aws-crt-cpp v0.44.4, and every C library recipe here is pinned to what
# THAT tag records. A newer SDK carries a newer CRT chain, so the versions block resolves only
# 1.11.935; a bump is a bump of the whole chain.
#
# ⭐ WHAT IS BUILT. BUILD_ONLY (CMakeLists.txt:23, :82) names the service clients: core is always
# built; s3, sts, sso and identity-management (which pulls in cognito-identity, sdksCommon.cmake:145)
# are the ones most dependants call. The other ~400 generated clients take hours and gigabytes and
# are not built; changing the list is a change of this recipe, not a hidden default.

dependencies = {
  "curl.se"     = "*"
  "openssl.org" = "^3"
  "zlib.net"    = 1
}

summary = "AWS SDK for C++: core, s3, sts, sso and identity-management over the AWS Common Runtime"

# LICENSE opens with "Apache License Version 2.0, January 2004".
license = "Apache-2.0"

versions {
  github = "aws/aws-sdk-cpp/tags"

  # Only 1.11.935; see the header. Negative lookahead, as mysql.com does.
  ignore = ["/^(?!1\\.11\\.935$)/"]
}

distributable {
  # No stored release asset, so the generated tag archive. The crt/ submodules are not needed:
  # BUILD_DEPS=OFF never reads them.
  url              = "https://github.com/aws/aws-sdk-cpp/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 1.11.935: 96068510 bytes, fetched with `zpkb sourcepin`. The project publishes neither a
  # signature nor a checksum file, so the second witness is a second independent fetch from
  # https://codeload.github.com/aws/aws-sdk-cpp/tar.gz/refs/tags/1.11.935: same bytes, same digest.
  sha256 = {
    "1.11.935" = "dac4a116685289fb6101c6cd4fd821ae1ea261149bfa822c133567f5e6e5dbc6"
  }
}

build {
  dependencies = {
    "cmake.org"    = "*"
    "gnu.org/make" = "*"
    "curl.se"      = "*"
    "openssl.org"  = "^3"
    "zlib.net"     = "*"
    "github.com/awslabs/aws-crt-cpp"         = "*"
    "github.com/awslabs/aws-c-auth"          = "*"
    "github.com/awslabs/aws-c-cal"           = "*"
    "github.com/awslabs/aws-c-common"        = "*"
    "github.com/awslabs/aws-c-compression"   = "*"
    "github.com/awslabs/aws-c-event-stream"  = "*"
    "github.com/awslabs/aws-c-http"          = "*"
    "github.com/awslabs/aws-c-io"            = "*"
    "github.com/awslabs/aws-c-mqtt"          = "*"
    "github.com/awslabs/aws-c-s3"            = "*"
    "github.com/awslabs/aws-c-sdkutils"      = "*"
    "github.com/awslabs/aws-checksums"       = "*"
    "github.com/aws/s2n-tls"                 = "*"
  }

  env = {
    ARGS = [
      "-DCMAKE_INSTALL_PREFIX={{prefix}}",
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_LIBDIR=lib",

      # CMakeLists.txt:254 find_package(aws-c-common REQUIRED) and :258-265 aws_use_package() of
      # aws-crt-cpp and the C libraries; external_dependencies.cmake:70 find_package(CURL) and
      # CMakeLists.txt:185 find_package(ZLIB). Every prefix goes on CMAKE_PREFIX_PATH and nothing
      # is left to the host.
      "-DCMAKE_PREFIX_PATH={{deps.github.com/awslabs/aws-crt-cpp.prefix}};{{deps.github.com/awslabs/aws-c-auth.prefix}};{{deps.github.com/awslabs/aws-c-cal.prefix}};{{deps.github.com/awslabs/aws-c-common.prefix}};{{deps.github.com/awslabs/aws-c-compression.prefix}};{{deps.github.com/awslabs/aws-c-event-stream.prefix}};{{deps.github.com/awslabs/aws-c-http.prefix}};{{deps.github.com/awslabs/aws-c-io.prefix}};{{deps.github.com/awslabs/aws-c-mqtt.prefix}};{{deps.github.com/awslabs/aws-c-s3.prefix}};{{deps.github.com/awslabs/aws-c-sdkutils.prefix}};{{deps.github.com/awslabs/aws-checksums.prefix}};{{deps.github.com/aws/s2n-tls.prefix}};{{deps.curl.se.prefix}};{{deps.openssl.org.prefix}};{{deps.zlib.net.prefix}}",

      # CMakeLists.txt:82 and sdksCommon.cmake:37, :145: the service clients. core is always built.
      "-DBUILD_ONLY=s3;sts;sso;identity-management",

      # CMakeLists.txt:51: the point of this recipe. The CRT is the recipes beside it. (With ON the
      # SDK builds the CRT static, :243-246, against its own libcrypto.)
      "-DBUILD_DEPS=OFF",

      # CMakeLists.txt:7: the 1.11 CMake files, upstream's default.
      "-DLEGACY_BUILD=ON",

      # CMakeLists.txt:33: shared libraries, upstream's default; the CRT beneath is shared too.
      "-DBUILD_SHARED_LIBS=ON",
      "-DFORCE_SHARED_CRT=ON",
      "-DSIMPLE_INSTALL=ON",

      # CMakeLists.txt:43-44, :416: unit and integration tests are not built or run.
      "-DENABLE_TESTING=OFF",
      "-DAUTORUN_UNIT_TESTS=OFF",
      "-DBUILD_TESTING=OFF",
      "-DENABLE_HTTP_CLIENT_TESTING=OFF",
      "-DENABLE_SMOKE_TESTS=OFF",
      "-DENABLE_PROTOCOL_TESTS=OFF",
      "-DDISABLE_DNS_REQUIRED_TESTS=OFF",
      "-DAWS_ENABLE_CORE_INTEGRATION_TEST=OFF",
      "-DBUILD_BENCHMARKS=OFF",
      "-DBUILD_PERFORMANCE_TESTS=OFF",
      "-DBUILD_OPTEL=OFF",
      "-DBUILD_OPTEL_OTLP_BENCHMARKS=OFF",

      # CMakeLists.txt:36-38, :48, external_dependencies.cmake:41-50: the http client is libcurl (the
      # tree's curl.se) on Linux and darwin; the CRT http client is not used, and NO_HTTP_CLIENT is off.
      "-DUSE_CRT_HTTP_CLIENT=OFF",
      "-DUSE_CRT_HTTP_CLIENT_ASYNC_IO=OFF",
      "-DNO_HTTP_CLIENT=OFF",
      "-DFORCE_CURL=ON",
      "-DENABLE_CURL_LOGGING=ON",
      "-DUSE_IXML_HTTP_REQUEST_2=OFF",
      "-DBYPASS_DEFAULT_PROXY=ON",

      # CMakeLists.txt:39: ON is a FATAL_ERROR (external_dependencies.cmake:25-26).
      "-DNO_ENCRYPTION=OFF",
      # CMakeLists.txt:52: the tree's openssl.org as libcrypto.
      "-DUSE_OPENSSL=ON",
      "-DUSE_TLS_V1_2=ON",
      "-DUSE_TLS_V1_3=OFF",

      # CMakeLists.txt:63, :185-195: request compression with the tree's zlib.net.
      "-DENABLE_ZLIB_REQUEST_COMPRESSION=ON",

      # CMakeLists.txt:31-32, :41-42, :55, :57-62, :64: build and code-generation switches. The
      # generated clients are the ones in the tarball; nothing is regenerated.
      "-DENABLE_UNITY_BUILD=ON",
      "-DMINIMIZE_SIZE=OFF",
      "-DENABLE_RTTI=ON",
      "-DNO_CPPSTD_IN_PKG_CONFIG=OFF",
      "-DCUSTOM_MEMORY_MANAGEMENT=OFF",
      "-DREGENERATE_CLIENTS=OFF",
      "-DENABLE_VIRTUAL_OPERATIONS=ON",
      "-DREGENERATE_DEFAULTS=OFF",
      "-DDISABLE_INTERNAL_IMDSV1_CALLS=OFF",
      "-DCPP_STANDARD=11",

      # CMakeLists.txt:68: default ON; a different compiler than upstream's CI must not fail on a warning.
      "-DAWS_SDK_WARNINGS_ARE_ERRORS=OFF",
      "-DENABLE_ADDRESS_SANITIZER=OFF",

      # CMakeLists.txt:45-47, :75: Android and Apple App Store switches; inert elsewhere, stated OFF so
      # nothing is built in and no private Apple API is referenced differently from upstream's default.
      "-DANDROID_BUILD_CURL=OFF",
      "-DANDROID_BUILD_OPENSSL=OFF",
      "-DANDROID_BUILD_ZLIB=OFF",
      "-DAWS_APPSTORE_SAFE=OFF",

      # CMakeLists.txt:79-81 are cache strings, left at their empty or upstream defaults on purpose:
      # AWS_USER_AGENT_CUSTOMIZATION (empty), AWS_TEST_REGION (US_EAST_1, tests only),
      # AWS_AUTORUN_LD_LIBRARY_PATH (unset, tests only).
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
    "test -f {{prefix}}/include/aws/core/Aws.h",
    # The package file dependants find_package(AWSSDK) (cmake/AWSSDKConfig.cmake).
    "test -f {{prefix}}/lib/cmake/AWSSDK/AWSSDKConfig.cmake",
  ]
}

provenance {
  read = [
    "CMakeLists.txt # :7 LEGACY_BUILD; :23 BUILD_ONLY; :31-83 options; :180-196 ZLIB; :218-219 external_dependencies; :234-265 BUILD_DEPS block, its else branch and aws_use_package; :416 BUILD_TESTING",
    "cmake/external_dependencies.cmake # :25-26 NO_ENCRYPTION is fatal; :41-50 http client choice; :60-75 find_package(CURL)",
    "cmake/setup_cmake_find_module.cmake # :53-62 where the package files are installed",
    "cmake/sdksCommon.cmake # :37 core is every client's dependency; :144-150 BUILD_ONLY dependency expansion",
    "generated/src/aws-cpp-sdk-s3, aws-cpp-sdk-sts, aws-cpp-sdk-sso, aws-cpp-sdk-cognito-identity and src/aws-cpp-sdk-identity-management # each has a CMakeLists.txt",
    "LICENSE",
  ]

  consulted = [
    "https://github.com/aws/aws-sdk-cpp/tree/1.11.935/crt",
  ]

  note = <<EOT
Written, not converted. This recipe replaces a fragment that listed three dependencies and nothing else.
Not read: cmake/platform/*.cmake, which picks the TLS backend of the SDK core per platform. The test block's package file
path comes from cmake/setup_cmake_find_module.cmake:53-62, which installs the cmake/ directory (AWSSDKConfig.cmake included)
under LIBRARY_DIRECTORY/cmake/PROJECT_NAME; that PROJECT_NAME is AWSSDK and LIBRARY_DIRECTORY is lib was not confirmed.
The CRT beneath is shared (CMakeLists.txt:243-246 builds it static only when BUILD_DEPS is ON), and libcurl and the SDK core
use the one openssl.org of this tree, which is the situation the TODO at :241-242 warns about when they differ.

⛔ NOT BUILT. The build and test blocks were not run in this session; the recipe is
checked by `zpkb lint` only.
EOT
}
